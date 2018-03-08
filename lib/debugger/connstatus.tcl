# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# connstatus.tcl --
#
#	Connection status display. Factored out of 'gui.tcl'
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: debugger.tcl.in,v 1.25 2001/02/09 07:52:48 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor connstatus {

    variable proj
    variable gui
    variable dbg

    constructor {gui_ args} {
	installhull [toplevel $win]
	wm title $win "Connection Status - [$gui_ cget -title]"

	set gui $gui_
	set dbg  [[$gui cget -engine] dbg]
	set proj [$gui proj]

	## FUTURE: 'proj' ...

	$self BuildUI
	#$self configurelist $args
	return
    }

    method BuildUI {} {
	# Registering for "any" may be too aggressive.  However,
	# it ensures that we don't miss any state changes.

	$dbg register any [mymethod connectStatusHandler]

	::guiUtil::positionWindow $win
	wm minsize                $win 100 100
	wm transient              $win $gui

	set   m [frame $win.mainFrm] ; #-bd 2 -relief raised]
	pack $m -fill both -expand true ; # -padx 6 -pady 6

	label $m.title -text "Status of connection to debugged application."
	text  $m.t
	label $m.l1 -text "Project type:"
	label $m.r1
	label $m.l2 -text "Connect status:"
	label $m.r2
	label $m.l3 -text "Listening port:"
	label $m.r3
	label $m.l4 -text "Local socket info:"
	label $m.r4
	label $m.l5 -text "Peer socket info:"
	label $m.r5
	button $m.b -text "Close" -command "destroy $win" -default active

	bind $win <Return> "$m.b invoke; break"
	bind $win <Escape> "$m.b invoke; break"

	grid $m.title -columnspan 2 -pady 10
	#grid $m.t -columnspan 2
	grid $m.l1 -row 1 -column 0 -sticky e
	grid $m.r1 -row 1 -column 1 -sticky w
	grid $m.l2 -row 2 -column 0 -sticky e
	grid $m.r2 -row 2 -column 1 -sticky w
	grid $m.l3 -row 3 -column 0 -sticky e
	grid $m.r3 -row 3 -column 1 -sticky w
	grid $m.l4 -row 4 -column 0 -sticky e
	grid $m.r4 -row 4 -column 1 -sticky w
	grid $m.l5 -row 5 -column 0 -sticky e
	grid $m.r5 -row 5 -column 1 -sticky w
	grid $m.b -columnspan 2 -pady 10
	return
    }

    method update {} {
	# Update window with current values.

	set m $win.mainFrm

	set msg "Project type:\t"
	if {! [$proj isProjectOpen]} {
	    append msg "No project open"
	    $m.r1 configure -text "No project open"
	} elseif {[$proj isRemoteProj]} {
	    $m.r1 configure -text "Remote"
	    append msg "Remote"
	} else {
	    $m.r1 configure -text "Local"
	    append msg "Local"
	}
	append msg "\n"
	set statusList [$dbg getServerPortStatus]

	$m.r2 configure -text [lindex $statusList 0]
	$m.r3 configure -text [lindex $statusList 1]
	$m.r4 configure -text [lindex $statusList 2]
	$m.r5 configure -text [lindex $statusList 3]

	append msg "Connect status:\t[lindex $statusList 0]\n"
	append msg "Listening port:\t[lindex $statusList 1]\n"
	append msg "Sockname:\t[lindex $statusList 2]\n"
	append msg "Peername:\t[lindex $statusList 3]\n"

	$m.t delete 0.0 end
	$m.t insert 0.0 $msg

	update
	focus -force $m.b
	return
    }

    # method connectStatusHandler --
    #
    #	This command is registered with the nub so we get
    #	feedback on debugger state and can update the
    #	connection status window if it is open.
    #
    # Arguments:
    #	The first arg is type, the rest depend on the type.
    #
    # Results:
    #	None.  May cause connection window to update.

    method connectStatusHandler {args} {
	$self update
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide connstatus 1.0
