# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# mktable - "tktable" /snit::widgetadaptor
#           modifies tktable to use mk view as data source.
#           auto-configures #row / #col to match view
#           external configuration for mapping from column
#           number to property names.
#           titling of widget is different ...
#           external configuration
#           external configuration for titling ...

# NOTE: does no transformation of column data, nor 
# hiding of columns, combination of columns, etc.
# For this 'virtual views' can be used performing the
# desired operations ...

package require Tktable
package require snit
namespace eval ::mktable {}

snit::widgetadaptor ::mktable::mktable {

    delegate method * to hull
    delegate option * to hull except {-command -cache -usecommand}

    constructor {args} {
	installhull using table -cache 1 -multiline 1

	$self configurelist $args
    }

    # ### ######### ###########################
    # mktable - NEW API

    ## I. Our data source is a metakit view ...

    # Option to hold the reference to the view we
    # are connected to.
    #
    # Note: We are __not__ responsible for the destruction
    #       of the data view. We do not take ownership !

    option -data {}

    # Option hold a list of property names. These properties
    # are expected to exist in -data, and are shown in the
    # table in the same order as in the value of the option.

    option -columns {}

    # Metakit cursor we use to access the elements of the
    # view.

    variable dcursor {}

    # Mapping from column indices to property names.
    # This mapping can be set automatically or via the
    # option -columns. If the latter is done the system
    # will check the data against all views given to it
    # as data source.

    variable columns


    # Title information ... If empty no titling is used.
    # If not empty the first n elements are used for titling,
    # where n = number of columns. If there are less the
    # name of the mapped property is used. If there are more
    # the overshot is ignored.

    option -titles {}

    # A callback to call whenever the number of columns has changed.

    option -ncolcommand {}

    variable ncols 0

    # Handle changes to the data source ...

    onconfigure -data {view} {
	# Ignore changes which are not.
	if {[string equal $view $options(-data)]} {return}

	#puts " ($view) <-- ($options(-data))"

	set oldncols $ncols

	if {$view != {}} {
	    set pnames [$self GetProperties $view pnew]

	    # Check that all properties which are already mapped
	    # are known to the new view.
	    # A column mapping exists. Check that the new view
	    # has at least these columns. If not, fail.

	    $self ValidateProps [array names columns] $view pnew

	    # Map all properties which were not yet known to
	    # columns, i.e. indices ...

	    $self MapColumns $pnames
	    set ncols [array size columns]
	} else {
	    # The new view is {} = This widget has nothing to
	    # display.
	    set ncols 0
	}

	# Close cursor of previous view, if any
	if {$options(-data) != {}} {
	    unset dcursor ; array set dcursor {}
	}
	set options(-data) $view
	if {($oldncols != $ncols) && ($options(-ncolcommand) != {})} {
	    uplevel #0 [linsert $options(-ncolcommand) end $oldncols $ncols]
	}

	$self RequestRefresh
	return
    }

    # Handle changes to the column mapping

    onconfigure -columns {columnlist} {
	# Ignore changes which are not.
	if {[string equal $columnlist $options(-columnlist)]} {return}

	# We have a -data view ?
	# If so we also have an automatic mapping.
	# Check that all columns listed here are present.
	# If yes, use the order here to reorder the display.
	#
	# We have no -data (empty). Just set the column
	# mapping. The check will happen when -data changes.

	if {$options(-data) != {}} {
	    set                              view $options(-data)
	    $self GetProperties             $view pnew
	    $self ValidateProps $columnlist $view pnew
	}

	set options(-columns) {}
	unset columns ; array set columns {}
	$self MapColumns $columnlist
	$self RequestRefresh
	return
    }

    # Handle changes to the titles

    onconfigure -titles {value} {
	# Ignore changes which are not.
	if {[string equal $value $options(-titles)]} {return}

	set options(-titles) $value
	$self RequestRefresh
	return
    }


    # ### ######### ###########################
    # Internals ...

    # Refresh handling ...

    # Boolean flag. Set if refresh was requested, but not yet
    # handled. Used to collapse multiple requests coming in a
    # series into a single true refresh

    variable tick 0

    method RequestRefresh {} {
	if {$tick} {return}
	set tick 1
	after idle [mymethod Refresh]
	return
    }
    method Refresh {} {
	# Reconfigure table to match the view ...

	set view $options(-data)
	set rows 0
	if {[llength $options(-titles)]} {
	    $hull configure -titlerows 1
	    incr rows
	} else {
	    $hull configure -titlerows 0
	}
	if {$view == {}} {
	    $hull configure -rows $rows -cols 0
	} else {
	    incr rows [$view size]

	    # Create  cursor to use in "GetData" ...
	    # Do this before the reconfigure of the
	    # table, as this will already ask for it.
	    $options(-data) cursor dcursor

	    $hull configure \
		    -rows $rows \
		    -cols [llength [$view properties]]
	}
	if {!$rows} {
	    $hull configure -usecommand 0 -command {}
	} else {
	    $hull configure \
		    -usecommand 1 \
		    -command [mymethod GetData %r %c]
	}

	set tick 0

	# Invalidating the cache causes a display refresh.
	$win clear cache
	return
    }

    # Tktable access to the data is routed through here and
    # converted into a metakit access.

    method GetData {r c} {
	#puts "- $r / $c - [lindex $options(-columns) $c]"

	# Title handling
	if {[llength $options(-titles)]} {
	    if {$r == 0} {
		set v [lindex $options(-titles) $c]
		if {$v == {}} {
		    set v [lindex $options(-columns) $c]
		}
		#puts "title $v"
		return $v
	    }
	    # Not the title row, adjust index for access into metakit
	    incr r -1
	}

	#puts "- $r / $c - [lindex $options(-columns) $c]"

	# Move cursor to the row we are asked for,
	# if not already loaded
	if {[info exists dcursor(#)] && ($dcursor(#) != $r)} {
	    set dcursor(#) $r
	}

	# Map column index to property name and return its value
	# from the cursor ...

	#puts @@@@@@@@@@@@@@@@@@@@@@@@@@
	#parray dcursor
	#puts @@@@@@@@@@@@@@@@@@@@@@@@@@

	set value $dcursor([lindex $options(-columns) $c])

	#puts "\t$value"

	return $value
    }

    # Column mapping ...

    method MapColumns {clist} {
	set n [array size columns]
	foreach p $clist {
	    if {![info exists columns($p)]} {
		set columns($p) $n
		incr n

		# Make changes to the mapping available to the
		# users of the widget.

		lappend options(-columns) $p
	    }
	}
	return
    }

    method ValidateProps {plist view pvar} {
	upvar $pvar properties
	foreach p $plist {
	    if {![info exists properties($p)]} {
		return -code error \
			"$self column error: Mapped property\
			\"$p\" is not known to the view \"$view\" ([$view properties])"
	    }
	}
	return
    }

    method GetProperties {view {pvar {}}} {
	set pnames [list]
	foreach p [$view properties] {
	    foreach {pname ptype} [split $p :] break
	    lappend pnames $pname
	}
	if {$pvar != {}} {
	    upvar $pvar properties
	    array set   properties {}
	    foreach p $pnames {
		set properties($p) .
	    }
	}
	return $pnames
    }


    # Delegate the remainder to the original tktable ...

    if 0 {
	# Debug methods to looks at tag and clear operations.
	method tag {args} {
	    # Intercept and print tag operations ...
	    puts "$self tag $args"
	    return [eval [linsert $args 0 $hull tag]]
	}

	method clear {args} {
	    # Intercept and print clear operations ...
	    puts "$self clear $args"
	    return [eval [linsert $args 0 $hull clear]]
	}
    }
}

package provide mktable 0.1
