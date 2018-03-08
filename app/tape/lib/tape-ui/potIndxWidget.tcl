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

snit::widget tcldevkit::teapot::indxWidget {
    hulltype ttk::frame

    option -connect -default {}

    constructor {args} {
	# Handle initial options.
	$self configurelist $args

	$self MakeWidgets
	$self PresentWidgets

	trace variable [myvar phrases]  w [mymethod Export]
	trace variable [myvar category] w [mymethod ChangeCat]
	return
    }

    onconfigure -connect {new} {
	if {$options(-connect) eq $new} return
	set options(-connect) $new
	$self Export
	return
    }

    destructor {
	trace vdelete [myvar phrases]  w [mymethod Export]
	trace vdelete [myvar category] w [mymethod ChangeCat]
    }

    variable phrases  {}
    variable category {}

    method MakeWidgets {} {
	ttk::labelframe $win.catg -text "Category"
	ttk::labelframe $win.subj -text "Subject / Key phrases"

	ttk::entry $win.catg.e -textvariable [myvar category]

	listentryb $win.subj.l \
	    -ordered 0 \
	    -labels "key phrase" \
	    -labelp "key phrases" \
	    -listvariable [myvar phrases] \
	    -browse 0
	return
    }

    method PresentWidgets {} {
	foreach {slave col row stick padx pady span colspan} {
	    .catg    0 0 swen 1m 1m 1 1
	    .subj    0 1 swen 1m 1m 1 1
	    .catg.e  0 0 swen 1m 1m 1 1
	    .subj.l  0 0 swen 1m 1m 1 1
	} {
	    grid $win$slave -columnspan $colspan -column $col -row $row \
		-sticky $stick -padx $padx -pady $pady -rowspan $span
	}

	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 0
	grid rowconfigure    $win 1 -weight 1

	grid columnconfigure $win.catg 0 -weight 1
	grid rowconfigure    $win.catg 0 -weight 1

	grid columnconfigure $win.subj 0 -weight 1
	grid rowconfigure    $win.subj 0 -weight 1

	tipstack::defsub $win {
	    .catg   {Category}
	    .catg.e {Category}
	    .subj   {Subject}
	    .subj.l {Subject}
	}
	return
    }

    method ChangeCat {args} {
	$self State changeCategory $category
	return
    }

    method Export {args} {
	if {![llength $phrases]} {
	    # Empty reference lists are removed from the meta data.
	    $self State unset  subject
	} else {
	    $self State change subject $phrases
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

	$win.catg.e configure -state normal
	$win.subj.l configure -state normal

	set phrases  [$self State get subject]
	set category [$self State getCategory]
	return
    }

    method {do no-current} {} {
	# Clear display, and disable
	set phrases  {}
	set category {}

	$win.catg.e configure -state disabled
	$win.subj.l configure -state disabled
	return
    }
}

# ------------------------------------------------------------------------------
package provide tcldevkit::teapot::indxWidget 1.0
