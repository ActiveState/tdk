# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package log::window 1.0
# Meta platform    tcl
# Meta require     BWidget
# Meta require     log
# Meta require     snit
# Meta require     tooltip
# @@ Meta End

# -*- tcl -*-
# logwindow.tcl --
#
#	-- A window to display log information
#
#	This file implements a widget for the display of log information.
#
# Copyright (c) 2004-2006 ActiveState Software Inc.
#

#
# RCS: @(#) $Id: dbg.tcl,v 1.8 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require log      ; # Tcllib     | Tracing and logging, levels and color information
package require tooltip  ; # AS package | Basic tooltips.
package require snit     ; # OO system of choice.
set ::TILE 1
package require BWidget  ; # BWidgets | ScrolledWindow needed.
Widget::theme 1
ScrolledWindow::use

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor ::log::window {

    delegate option -font to text
    delegate option *     to hull except {-borderwidth -bd -relief -auto -scrollbar}

    option -link  -default 1 -readonly 1

    constructor {args} {
	installhull using ScrolledWindow \
		-borderwidth 1 -relief sunken \
		-auto both -scrollbar vertical

	install text using text $win.t -bd 0 -relief flat \
		-state disabled -width 60

	$hull setwidget $text
	foreach level [::log::levels] {
	    $text tag configure tag_$level \
		    -background [::log::lv2color $level]
	}

	tooltip::tooltip $text {Log of actions}

	$self configurelist $args

	if {$options(-link)} {
	    # Insert the window into the logger system ...
	    foreach l [::log::levels] {
		lappend cmdmap $l [::log::lv2cmd $l]
	    }
	    log::lvCmdForall [mymethod log]
	}
	return
    }

    destructor {
	# Restore previous definitions.
	foreach {l c} $cmdmap {::log::lvCmd $l $c}
	return
    }

    variable text
    variable cmdmap {}

    method log {level thetext} {
	$text configure -state normal
	$text insert end "$thetext\n" tag_$level
	$text see end
	$text configure -state disabled
	update
	return
    }
    method log* {level thetext} {
	$text configure -state normal
	$text insert end "$thetext" tag_$level
	$text see end
	$text configure -state disabled
	update
	return
    }
    method clear {} {
	$text configure -state normal
	$text delete 1.0 end
	$text see end
	$text configure -state disabled
	update
	return
    }

    # ### ### ### ######### ######### #########
}


# ### ### ### ######### ######### #########
## Ready to go
return
