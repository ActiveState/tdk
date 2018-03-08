# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################

# UI tools. Widget. Label connected connected to a cursor as generated
# by 'view' (See tools), or anything following the same interface,
# oomk/metakit for example.

# ### ######### ###########################
## Prerequisites

package require snit    ; # Object system

# ### ######### ###########################
## Implementation

snit::widgetadaptor clabel {
    # ### ######### ###########################

    delegate method * to hull
    delegate option * to hull
    # FUTURE: Exclude -text, -textvariable

    option -cursor {}
    option -attr   {}

    # ### ######### ###########################
    ## Public API. Construction.

    constructor {args} {
	installhull [label $win]
	$self configurelist $args
	return
    }

    # ### ######### ###########################
    ## Internal. State of widget.

    ## Nothing new

    # ### ######### ###########################
    ## Internal. Handle changes to the options.

    onconfigure -cursor {varname} {
	if {$options(-cursor) eq $varname} return

	$self DetachCursor
	set options(-cursor) $varname
	$self AttachCursor
	return
    }

    onconfigure -attr {attr} {
	if {$options(-attr) eq $attr} return

	$self DetachAttr
	set options(-attr) $attr
	$self AttachAttr
	return
    }

    # ### ######### ###########################
    ## Internal. Cursor mgmt.
    ## Operations are ignored if there is no cursor to use.

    method DetachCursor {} {
	if {$options(-cursor) == {}} return

	$self DetachAttr

	upvar #0 $options(-cursor) cursor
	trace remove variable      cursor(#) {write} \
		[mymethod RowChanged]
	return
    }

    method AttachCursor {} {
	if {$options(-cursor) == {}} return

	$self AttachAttr

	upvar #0 $options(-cursor) cursor
	trace add variable         cursor(#) {write} \
		[mymethod RowChanged]
	return
    }

    # ### ######### ###########################
    ## Internal. Attribute mgmt.
    ## Operations are ignored if there is no attribute to use.

    method DetachAttr {} {
	if {$options(-attr) == {}} return

	$hull configure -text {}

	if {$options(-cursor) != {}} {
	    upvar #0 $options(-cursor) cursor
	    trace remove variable      cursor($options(-attr)) {write} \
		    [mymethod DataChanged]
	}
	return
    }

    method AttachAttr {} {
	if {$options(-attr) == {}} return

	if {$options(-cursor) != {}} {
	    upvar #0 $options(-cursor) cursor
	    trace add variable         cursor($options(-attr)) {write} \
		    [mymethod DataChanged]

	    if {[info exists cursor(#)]} {
		if {[catch {
		    $hull configure -text $cursor($options(-attr))
		} msg]} {
		    # This implies that the cursor could not be
		    # read. There are two possible reasons for that
		    # outcome: The attribute is not known, or the row
		    # was out of bounds. We now generate a better
		    # error message than snit does.

		    if {[string match {*out of bounds*} $msg]} {
			return -code error "$win configuration error:\
				cursor at illegal row \"$cursor(#)\""
		    } else {
			return -code error "$win configuration error:\
				cursor attribute \"$options(-attr)\"\
				not known to the underlying view"
		    }
		}
	    }
	}
	return
    }

    # ### ######### ###########################
    ## Internal. Handling changes to the shown information.
    #
    ## RowChanged  <=> 'cursor(#)' was written to.
    ## DataChanged <=> 'cursor(attribute)' was written to.

    method RowChanged {var op index} {
	# The cursor was repositioned, refresh display.
	# We do this by breaking and reattaching the
	# attribute to the hull, if defined.

	# Note: This will be triggered by all writes even if the row
	# id did not change. Not stripping out such no-change events
	# gives us an easy way to trigger a refresh from the outside.

	$self DetachAttr
	$self AttachAttr
	return
    }

    method DataChanged {var op index} {
	upvar #0 $options(-cursor) cursor
	$hull configure -text     $cursor($options(-attr))
	return
    }

    # ### ######### ###########################
    ## Block the options we use internally ...
    ## They are effectively nulled out.

    foreach o {-text -textvariable} {
	option $o {}
	onconfigure $o {args} "#return -code error \"Unknown option $o\""
	oncget      $o        "#return -code error \"Unknown option $o\""
    }
    unset o

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use

package provide clabel 0.1
