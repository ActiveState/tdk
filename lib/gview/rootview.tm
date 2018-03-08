# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package rootview 1.0
# Meta platform    tcl
# Meta require     image
# Meta require     snit
# Meta require     view
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ######### ###########################

# Tools. Presentation of a list of directories as a tabular view. The
# directories are explicitly added to the view. The icon to show for
# each entry is specified through an option. Another option can be
# used to specify the command for the creation of the subviews.

# ### ######### ###########################
## Prerequisites

package require snit; # Object-system.
package require view; # Basic view management
package require image ; image::file::here ; # Predefined images

snit::type rootview {
    # ### ######### ###########################

    delegate method * to view

    # -icon    is the name of the icon to show for each entry in the view.
    # -opencmd is the command prefix for the creation of subviews. It also
    #          allows inspection if a subview is suitable.

    option -icon    {}
    option -opencmd {}

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

    variable after {}

    # ### ######### ###########################
    ## Public API. Extending the view with a root direcotry to
    ## display.

    method add {dir {dostat 0}} {
	if {[info exists roots($dir)]} return
	set roots($dir) $dostat
	set rootlist [lsort -dictionary [array names roots]]

	if {$after == {}} {
	    set after [after idle [mymethod change __]]
	}
	return
    }

    method remove {dir} {
	if {![info exists roots($dir)]} return
	unset roots($dir)
	unset -nocomplain a($dir)
	set rootlist [lsort -dictionary [array names roots]]

	if {$after == {}} {
	    set after [after idle [mymethod change __]]
	}
	return
    }

    method has {dir} {
	return [info exists roots($dir)]
    }


    # ### ######### ###########################
    ## Public API. Used by the internal generic
    ## view to query and change data.

    method names {} {
	return {icon icon-open id label nchildren children}
    }

    method size {} {
	return [array size roots]
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
	if {$row eq "end"} {
	    set  row [array size roots]
	    incr row -1
	} elseif {
	    ![string is integer -strict $row] ||
	    ($row < 0) ||
	    ($row >= [array size roots])
	} {
	    return -code error "$self get: row index \"$row\" out of bounds"
	}
	if {($attr eq "label") || ($attr eq "id")} {
	    return [lindex $rootlist $row]
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

	if {$row eq "end"} {
	    set  row [array size roots]
	    incr row -1
	} elseif {
	    ![string is integer -strict $row] ||
	    ($row < 0) ||
	    ($row >= [array size roots])
	} {
	    return -code error "$self open: row index \"$row\" out of bounds"
	}

	if {$options(-opencmd) == {}} {return {}}

	set path [lindex $rootlist $row]
	return [eval [linsert $options(-opencmd) end create $path]]
    }

    method reset {} {$self Clear ; return}

    # ### ######### ###########################
    ## Public API. Change propagation

    method change {o} {
	set after {} ;# Unlock idle callbacks.
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

    variable view     {} ; # Handle to internal generic view
    variable rootlist {} ; # List of the roots.
    variable roots       ; # Array of roots known.
    variable stat        ; # Stat cache for contents
    variable cvalid    0 ; # Cache validity flag.

    # ### ######### ###########################
    ## Internal. Handling of changes to options.

    onconfigure -icon {value} {
	if {$value eq $options(-icon)} return
	set options(-icon) $value
	$self Clear
	$view trigger
	return
    }

    # ### ######### ###########################
    ## Internal.

    method ListContents {dir} {
	if {$options(-opencmd) == {}} {return {}}
	return [eval [linsert $options(-opencmd) end glob $dir]]
    }

    method Stat {row avar} {
	upvar $avar a
	if {[info exists stat($row)]} {
	    array set a $stat($row)
	    return
	}

	set path [lindex $rootlist $row]

	# roots($path) - boolean - control whether to stat item or not.

	if {$roots($path)} {
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
	} else {
	    # Not allowed to stat. Assume directory. Assume children.

	    array set a {
		nchildren 10 mtime 0 ctime 0
		atime 0 dev 0 gid 0 ino 0 mode 0
		nlink 0 size 0 type directory uid 0
	    }
	}

	if {$options(-icon) == {}} {
	    set a(icon)      folder-closed
	    set a(icon-open) folder-open
	} else {
	    set a(icon)      $options(-icon)
	    set a(icon-open) $options(-icon)
	}

	set stat($row) [array get a]
	return
    }

    method Clear {} {
	array unset stat
	array set   stat {}
	return
    }

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use
return
