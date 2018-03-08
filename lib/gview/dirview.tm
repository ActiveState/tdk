# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package dirview 1.0
# Meta platform    tcl
# Meta require     file::open
# Meta require     snit
# Meta require     view
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ######### ###########################

# Tools. Presentation of a directory as a tabular view.
# Based on the generic view class.

# ### ######### ###########################
## Prerequisites

package require snit; # Object-system.
package require view; # Basic view management
package require file::open; # file type info

snit::type dirview {
    # ### ######### ###########################

    delegate method * to view

    # -path is the path to show through the view. Changing it will
    #       trigger notifications to all registered observers.
    #
    # -separate is a boolean flag. If set to true the view will list
    #           directories first, and then the files. The default is
    #           to show all entries in in-order, even if this causes
    #           the type of entries to mix

    option -path       {}
    option -separate   0
    option -icon       {}
    option -iconprefix {}

    # ### ######### ###########################
    ## Public API. (De)Construction.

    constructor {args} {
	set view [view ${selfns}::view -source $self -partof $self]
	array set stat {}
	$self configurelist $args
	return
    }

    destructor {
	$view destroy
	return
    }

    method reset {} {$self Clear ; return}

    # ### ######### ###########################
    ## Public API. Used by the internal generic
    ## view to query and change data.

    method names {} {
	return {icon id label atime ctime mtime mode size type gid uid dev ino ftype}
    }

    method size {} {
	$self Setup
	return [llength $index]
    }

    method isview   {attr} {return 0}
    method isstring {attr} {return 1}

    method get {row attr} {
	$self Setup
	if {$row eq "end"} {
	    set  row [llength $index]
	    incr row -1
	} elseif {
	    ![string is integer -strict $row] ||
	    ($row < 0) ||
	    ($row >= [llength $index])
	} {
	    return -code error "$self get: row index \"$row\" out of bounds"
	}
	if {($attr eq "id") || ($attr eq "label")} {
	    return [file tail [lindex $index $row]]
	}
	$self Stat $row a
	if {![info exists a($attr)]} {
	    return -code error \
		    "$self get: attribute \"$attr\" unknown"
	}
	return $a($attr)
    }

    method set {row attr value} {
	return -code error "$type $self is read-only"
    }

    method open {row attr} {
	return -code error "$self open: Illegal, no subviews present"
    }

    # ### ######### ###########################
    ## Public API. Change propagation

    method change {o} {
	$self Clear
	$view trigger
	return
    }

    method onChangeCall {object} {
	if {$object eq $view} {return}
	$view onChangeCall $object
	return
    }

    method removeOnChangeCall {object} {
	if {$object eq $view} {return}
	$view removeOnChangeCall $object
    }

    # ### ######### ###########################
    ## Internal. Data structures

    variable view  {} ; # Handle to internal generic view
    variable index {} ; # Cache of contents.
    variable stat     ; # Stat cache for contents
    variable cvalid 0 ; # Cache validity flag.

    # ### ######### ###########################
    ## Internal. Handling of changes to options.

    onconfigure -path {value} {
	if {$value eq $options(-path)} return
	set options(-path) $value
	$self Clear
	$view trigger
	return
    }

    onconfigure -separate {value} {
	if {$value eq $options(-separate)} return
	set options(-separate) $value
	$self Clear
	$view trigger
	return
    }

    onconfigure -icon {value} {
	if {$value eq $options(-icon)} return
	set options(-icon) $value
	$self Clear
	$view trigger
	return
    }

    onconfigure -iconprefix {value} {
	if {$value eq $options(-iconprefix)} return
	set options(-iconprefix) $value
	$self Clear
	$view trigger
	return
    }

    # ### ######### ###########################
    ## Internal.

    method Stat {row avar} {
	upvar $avar a

	if {[info exists stat($row)]} {
	    array set a $stat($row)
	} else {
	    # We have nothing cached. This means that we have
	    # to interogate the file system to get all the
	    # information about the file. This is a bit complex
	    # because of special cases introduced by our "beloved"
	    # Windows (NT in this cae).

	    set f [lindex $index $row]

	    #puts $row\t$avar\t$f

	    if {![file exists $f]} {
		# There are two possibilities ...
		# (a) The file was removed between the execution of
		#   the "glob" listing it and the arrival here.
		# (b) And on Windows NT "glob" lists system files,
		#   but most other "file" commands claim that it
		#   does not exist. Example: C:/pagefile.sys
		#
		# The two cases can be distinguished
		# For (b) "file attributes" does not report
		# 'file does not exist' like "file type|stat|.."
		# do, but 'permission denied' ! Only for (a) it
		# also reports 'file does not exist'.
		#
		# For both cases we have to fake the information
		# as the OS will not or cannot give it us. In case
		# (a) we also trigger a 'change' in the immediate
		# future. The last ensures that the higher levels
		# are forced to ask for new data, which then does
		# not list the file/directory anymore when doing
		# the "glob".

		array set a {
		    atime 0 mode 0
		    ctime 0 size 0
		    mtime 0 type file
		    gid   0 ino  0
		    uid   0 dev  0
		}

		global tcl_platform
		if {"$tcl_platform(os)" eq "Windows NT"} {
		    catch {file attributes $f} msg
		    if {![string match -nocase *permission* $msg]} {
			# Case (a) ... Trigger a future change.
			after 0 [mymethod change $self]
		    }
		}
	    } else {
		# File exists ... We may not have permissions.

		set fail [catch {file stat $f a}]
		if {$fail} {
		    catch {
			# Try again for a link by not following it.
			if {[file type $f] eq "link"} {
			    set fail [catch {file lstat $f a}]
			}
		    }
		}
		if {$fail} {
		    # Full failure. Most likely no permissions.
		    # We have to set up fake data.

		    array set a {
			atime 0 mode 0
			ctime 0 size 0
			mtime 0 type file
			gid   0 ino  0
			uid   0 dev  0
		    }
		}
	    }

	    #parray a

	    # Determine icon, and type

	    set a(ftype) [file::type $f]
	    set a(icon)  {}
	    if {$options(-icon) != {}} {
		set a(icon) [$options(-icon) icon \
			$options(-iconprefix) \
			$f]
	    }
	    set stat($row) [array get a]
	}
    }

    method Setup {} {
	if {$cvalid} return
	set cvalid 1

	set dir $options(-path)
	if {$dir == {}}               return
	if {![file isdirectory $dir]} return
	if {![file readable    $dir]} return

	set allfiles [glob -nocomplain -dir $dir *]
	if {0 && [lindex [file system $dir] 0] eq "native"} {
	    # XXX: VFS has problems with hidden files, which causes us
	    # XXX: display issues, but this isn't right across the board.
	    set allfiles [concat $allfiles \
			      [glob -nocomplain -type hidden -dir $dir *]]
	}
	if {$options(-separate)} {
	    set directories {}
	    set files       {}

	    foreach f $allfiles {
		if {[file isdirectory $f]} {
		    lappend directories $f
		} else {
		    lappend files $f
		}
	    }

	    set index {}
	    foreach f [lsort -dictionary $directories] {
		lappend index $f
	    }
	    foreach f [lsort -dictionary $files] {
		lappend index $f
	    }
	} else {
	    set index [lsort -dictionary $allfiles]
	}

	return
    }

    method Clear {} {
	set         index {}
	array unset stat
	array set   stat {}
	set cvalid 0
	return
    }

    method filetype {path} {
	return [file::type $path]
    }

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use
return
