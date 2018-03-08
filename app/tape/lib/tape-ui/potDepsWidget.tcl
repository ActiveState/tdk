# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# potFileWidget.tcl --
#
#	This file implements a widget which handes the teapot meta data file
#       information as used by 'teapot-pkg gen' (included, recommend).
#
# Copyright (c) 2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: Exp $
#
# -----------------------------------------------------------------------------

package require snit
package require tipstack
package require listentryb
package require image ; image::file::here

# -----------------------------------------------------------------------------

snit::widget tcldevkit::teapot::depsWidget {
    hulltype ttk::frame

    option -connect -default {}
    option -key     -default {}
    option -label   -default {}

    constructor {args} {
	# Handle initial options.
	$self configurelist $args

	$self MakeWidgets
	$self PresentWidgets

	trace variable [myvar deps] w [mymethod Export]
	return
    }

    onconfigure -connect {new} {
	if {$options(-connect) eq $new} return
	set options(-connect) $new
	if {$options(-key) eq ""} return
	$self Export
	return
    }

    onconfigure -key {new} {
	if {$options(-key) eq $new} return
	set mdkey $new
	if {$options(-connect) eq ""} return
	$self Export
	return
    }

    destructor {
	trace vdelete [myvar deps] w [mymethod Export]
    }

    variable deps  {}
    variable mdkey {}

    method MakeWidgets {} {
	listentryb $win.l \
	    -ordered 0 \
	    -labels "$options(-label) dependency" \
	    -labelp "$options(-label) dependencies" \
	    -listvariable [myvar deps] \
	    -valid [mymethod ValidateReference] \
	    -transform [mymethod NormalizeReference] \
	    -browse 0
	return
    }

    method PresentWidgets {} {
	foreach {slave col row stick padx pady span colspan} {
	    .l    0 0 swen 1m 1m 1 1
	} {
	    grid $win$slave -columnspan $colspan -column $col -row $row \
		-sticky $stick -padx $padx -pady $pady -rowspan $span
	}

	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1

	tipstack::defsub $win \
	    [list .l   "[string toupper $options(-label) 0 0] dependencies"]
	return
    }

    method ValidateReference {text} {
	if {![teapot::reference::valid $text msg]} {
	    # Remove reference to doc entity. Unwanted for now.
	    set msg [string map {{, documentation} {}} $msg]
	    return $msg
	}
	return {}
    }

    method NormalizeReference {text} {
	return [teapot::reference::ref2tcl \
		    [teapot::reference::normalize1 $text]]
    }

    method Export {args} {
	if {![llength $deps]} {
	    # Empty reference lists are removed from the meta data.
	    $self State unset  $mdkey
	} else {
	    $self State change $mdkey $deps
	}
	return
    }

    method State {args} {
	# Delegate action to state object connected to this widget.
	if {$options(-connect) eq ""} return
	return [uplevel \#0 [linsert $args 0 $options(-connect)]]
    }

    # These methods are called by the state to influence the GUI. This
    # is filtered by the main pot package display.

    method {do error@} {index key msg} {}
    method {do select} {selection}     {}

    method {do refresh-current} {} {
	# Get the newest file information and refresh the display,
	# re-enable interaction

	$win.l configure -state normal

	set deps [$self State get $mdkey]
	return
    }

    method {do no-current} {} {
	# Clear display, and disable.
	set deps {}
	$win.l configure -state disabled
	return
    }
}

# ------------------------------------------------------------------------------
package provide tcldevkit::teapot::depsWidget 1.0
