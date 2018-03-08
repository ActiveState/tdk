# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# mklabel - "label" /snit::widgetadaptor
#           Modifies label to talk to a metakit cursor
#           for the data to show in it.
#           Knows the property to watch.
#           Traces the # element to notice changes.

package require Tk
package require snit

snit::widgetadaptor ::mklabel {

    delegate method * to hull
    delegate option * to hull except {-text -textvariable}

    constructor {args} {
	if {$::TILE} {
	    installhull using ttk::label
	} else {
	    installhull using label
	}
	$self configurelist $args
    }

    # ### ######### ###########################
    # mklabel - NEW API

    ## I. Our data source is a metakit cursor variable ...

    option -cursor {}
    option -property {}

    onconfigure -cursor {varname} {
	# Ignore changes which are not.
	if {$varname eq $options(-cursor)} {return}

	$self DetachCursor
	set options(-cursor) $varname
	$self AttachCursor
	return
    }

    onconfigure -property {p} {
	# Ignore changes which are not.
	if {$p eq $options(-property)} {return}

	$self DetachProperty
	set options(-property) $p
	$self AttachProperty
	return
    }

    method DetachCursor {} {
	# Detach only if defined.
	if {$options(-cursor) == {}} {return}

	$self DetachProperty

	upvar #0 $options(-cursor) cursor
	trace remove variable      cursor(\#) {write} [mymethod RowChanged]
	return
    }

    method AttachCursor {} {
	# Attach only if defined.
	if {$options(-cursor) == {}} {return}

	$self AttachProperty

	upvar #0 $options(-cursor) cursor
	trace add variable         cursor(\#) {write} [mymethod RowChanged]
	return
    }

    method DetachProperty {} {
	# Detach only if defined.
	if {$options(-property) == {}} {return}

	$hull configure -text {}
	trace remove variable cursor($options(-property)) {write} [mymethod DataChanged]
	return
    }

    method AttachProperty {} {
	# Attach only if defined.
	if {$options(-property) == {}} {return}

	if {$options(-cursor) != {}} {
	    upvar #0 $options(-cursor) cursor
	    trace add variable cursor($options(-property)) {write} [mymethod DataChanged]

	    if {[info exists cursor(\#)]} {
		$hull configure -text $cursor($options(-property))
	    }
	}
	return
    }

    method RowChanged {var op index} {
	# The cursor was repositioned, refresh display
	# We do this by breaking and reattaching the
	# property to the hull, if defined.

	$self DetachProperty
	$self AttachProperty
	return
    }

    method DataChanged {var op index} {
	upvar #0 $options(-cursor) cursor
	$hull configure -text $cursor($options(-property))
	return
    }
}

package provide mklabel 0.1
