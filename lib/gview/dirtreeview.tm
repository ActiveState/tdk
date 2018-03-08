# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package dirtreeview 1.0
# Meta platform    tcl
# Meta require     image
# Meta require     snit
# Meta require     view
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ######### ###########################

# Tools. Presentation of a directory as a tabular view.  Based on the
# generic view class. Descended from the 'dirtreeview' code
# base. Restricted to list only directories, and no files at all.

# ### ######### ###########################
## Prerequisites

package require snit; # Object-system.
package require view; # Basic view management
package require image ; image::file::here ; # Predefined images

snit::type dirtreeview {
    # ### ######### ###########################

    delegate method * to view

    # -path is the path to show through the view. Changing it will
    #       trigger notifications to all registered observers.

    option -path     {}

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
	return {icon icon-open id label nchildren children atime ctime mtime mode size type gid uid dev ino}
    }

    method size {} {
	$self Setup
	return [llength $index]
    }

    method isview   {attr} {
	if {$attr eq "children"} {return 1}
	return 0
    }

    method isstring {attr} {
	if {$attr eq "children"}  {return 0}
	if {$attr eq "nchildren"} {return 0}
	return 1
    }

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
	if {($attr eq "label") || ($attr eq "id")} {
	    return [file tail [lindex $index $row]]
	}
	if {$attr eq "children"} {
	    return {}
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
	if {$attr ne "children"} {
	    return -code error "$self open: Attribute \"$attr\" is not a subview"
	}

	$self Setup
	if {$row eq "end"} {
	    set  row [llength $index]
	    incr row -1
	} elseif {
	    ![string is integer -strict $row] ||
	    ($row < 0) ||
	    ($row >= [llength $index])
	} {
	    return -code error "$self open: row index \"$row\" out of bounds"
	}

	$self Stat $row a
	if {$a(type) ne "directory"} {return {}}

	set path [lindex $index $row]
	return [$type create %AUTO% -path $path]
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

    # ### ######### ###########################
    ## Internal.

    method Setup {} {
	if {$cvalid} return
	set cvalid 1

	set dir $options(-path)
	if {$dir == {}}               return
	if {![file isdirectory $dir]} return
	if {![file readable    $dir]} return

	set index [lsort -dictionary [$self ListContents $dir]]
	return
    }

    typemethod glob {dir} {
	set directories {}
	catch {
	    # NOTE: catch still required, permissions may hit us here
	    # with errors still. 8.4/8.5 difference: 8.4 swallowed
	    # permissions problems due -nocomplain, 8.5 doesn't,
	    # considers it true error. We simply default to an empty
	    # list for that case, that is sensible.

	    foreach f [glob -nocomplain -dir $dir *] {
		if {[file isdirectory $f]} {
		    lappend directories $f
		}
	    }

	    # XXX: We aren't getting hidden dirs
	    # This should work - but VFS dirs aren't responding to the
	    # -type parameter correctly
	    #set directories [glob -nocomplain -type d -dir $dir *]
	    if {0 && [lindex [file system $dir] 0] eq "native"} {
		set directories [concat $directories \
				     [glob -nocomplain -type {d hidden} -dir $dir *]]
	    }
	}
	return $directories
    }

    method ListContents {dir} {
	return [$type glob $dir]
    }

    method Stat {row avar} {
	upvar $avar a
	if {[info exists stat($row)]} {
	    array set a $stat($row)
	} else {
	    set path [lindex $index $row]

	    set fail [catch {file stat $path a}]
	    if {$fail} {
		catch {
		    # Try again for a link by not following it.
		    if {[file type $path] eq "link"} {
			set fail [catch {file lstat $path a}]
		    }
		}
	    }
	    if {$fail} {
		# Full failure. Most likely no permissions.
		array set a {
		    nchildren 0 mtime 0 ctime 0
		    atime 0 dev 0 gid 0 ino 0 mode 0
		    nlink 0 size 0 type unknown uid 0
		}
	    } else {
		# Enter the data of the special rows: nchildren, icon,
		# and icon-open

		set a(nchildren) [llength [$self ListContents $path]]
	    }
	    set a(icon)      folder-closed
	    set a(icon-open) folder-open

	    set stat($row) [array get a]
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

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use
return
