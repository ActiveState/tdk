# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package clogwindow 1.0
# Meta platform    tcl
# Meta require     log::window
# Meta require     snit
# Meta require     tooltip
# @@ Meta End

# -*- tcl -*-
# clogwindow.tcl --
#
#	-- A window to display log information, clearable.
#
#	This file implements a widget
#	for the display of log information, which can be cleared by the user.
#
# Copyright (c) 2006 ActiveState Software Inc.
#

#
# RCS: @(#) $Id: dbg.tcl,v 1.8 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require log::window ; # AS package | Log window
package require tooltip     ; # AS package | Basic tooltips.
package require snit        ; # OO system of choice.

# ### ### ### ######### ######### #########
## Implementation

snit::widget ::clogwindow {
    hulltype ttk::frame

    option {-errorbackground errorbackground Color}  lightyellow
    option {-labelhelp       labelhelp       String} {Clear Log}

    delegate option -label to clear as -text
    delegate option *      to log
    delegate method *      to log
    delegate option -padding to hull

    component log
    component clear

    constructor {args} {
	install clear using ttk::button $win.clr -command [mymethod clear]
	install log   using log::window $win.log -link 0

	grid $clear -column 0 -row 0 -sticky  w   -padx 1m -pady 1m
	grid $log   -column 0 -row 1 -sticky swen -padx 1m -pady 1m

	grid columnconfigure $win 0 -weight 1

	grid rowconfigure $win 0 -weight 0
	grid rowconfigure $win 1 -weight 1

	$self configurelist $args
	if {[$clear cget -text] eq ""} {
	    $clear configure -text Clear
	}
	tooltip::tooltip $clear $options(-labelhelp)
	return
    }

    destructor {
	return
    }

    onconfigure -labelhelp {value} {
	set options(-labelhelp) $value
	tooltip::tooltip $clear $options(-labelhelp)
	return
    }

    # ### ### ### ######### ######### #########
}


# ### ### ### ######### ######### #########
## Ready to go
return
