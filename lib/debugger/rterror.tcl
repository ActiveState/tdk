# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# rterror.tcl --
#
#	Display of runtime errors. Factored out of 'gui.tcl'
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

snit::widgetadaptor rterror {

    variable gui
    variable dbg

    constructor {gui_ args} {
	installhull [toplevel $win]
	wm title $win "Tcl Error - [$gui_ cget -title]"

	set gui $gui_
	set dbg [[$gui cget -engine] dbg]

	$self BuildUI
	#$self configurelist $args
	return
    }

    # method createErrorWindow --
    #
    #	Create the Error Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    variable errorInfoText
    variable errorInfoLabel
    variable errorInfoSuppress
    variable errorInfoDeliver
    variable uncaught

    method BuildUI {} {
	wm minsize   $win 100 100
	wm transient $win $gui
	wm resizable $win 1 1

	set pad  6
	set pad2 [expr {$pad / 2}]

	set mainFrm  [ttk::frame $win.mainFrm]
	set titleFrm [ttk::frame $mainFrm.titleFrm]
	set imageLbl [ttk::label $titleFrm.imageLbl \
			  -image $image::image(syntax_error)]

	set errorInfoLabel \
	    [ttk::label $titleFrm.msgLbl -wraplength 500 -justify left \
		 -text "An error occured while executing the script:"]

	pack $imageLbl       -side left
	pack $errorInfoLabel -side left

	set infoFrm       [ttk::frame $mainFrm.infoFrm]
	set errorInfoText [text $infoFrm.errorInfoText -width 40 -height 10 \
			       -takefocus 0]
	set sb [scrollbar $mainFrm.sb -command [list $errorInfoText yview]]

	pack $errorInfoText -side left -fill both -expand true
	pack $titleFrm -fill x                 -padx $pad -pady $pad
	pack $infoFrm  -fill both -expand true -padx $pad -pady $pad

	set butFrm   [ttk::frame $win.butFrm]

	set errorInfoSuppress [ttk::button $butFrm.suppressBut \
				   -text "Suppress Error" -default normal \
				   -command [mymethod handleError suppress]]
	set errorInfoDeliver [ttk::button $butFrm.deliverBut \
				  -text "Deliver Error" -default normal \
				  -command [mymethod handleError deliver]]

	pack $errorInfoSuppress $errorInfoDeliver -side right -padx $pad
	pack $butFrm  -side bottom -fill x                 -pady $pad2
	pack $mainFrm -side bottom -fill both -expand true -padx $pad -pady $pad

	bind $win <Return> [mymethod handleError]

	fmttext::setDbgTextBindings $errorInfoText $sb
	bind::addBindTags $errorInfoText noEdit
	$errorInfoText configure -wrap word
    }

    # method updateErrorWindow --
    #
    #	Update the message in the Error Window.
    #
    # Arguments:
    #	level		The level the error occured in.
    #	loc 		The <loc> opaque type where the error occured.
    #	errMsg		The message from errorInfo.
    #	errStack	The stack trace.
    #	errCode		The errorCode of the error.
    #
    # Results:
    #	None.

    method updateErrorWindow {level loc errMsg errStack errCode uncaughtIn} {
	set  uncaught $uncaughtIn
	if {$uncaught} {
	    $errorInfoLabel configure -text "An error occurred while \
		    running the script.\nThis error may not be caught by the application \
		    and will probably terminate the script unless it is suppressed."
	    $errorInfoSuppress configure -default active
	    $errorInfoDeliver configure -default normal
	    focus $errorInfoSuppress
	} else {
	    $errorInfoLabel configure -text "An error occurred while \
		    running the script.\nThis error will be caught by the application."
	    $errorInfoSuppress configure -default normal
	    $errorInfoDeliver  configure -default active
	    focus $errorInfoDeliver
	}
	$errorInfoText insert 0.0 "$errStack"
	return
    }

    # method handleError --
    #
    #	Determine whether the error should be suppressed, then destroy
    #	the error window.
    #
    # Arguments:
    #	option		"suppress" or "deliver", or "" to get default action
    #
    # Results:
    #	None.

    method handleError {{option {}}} {
	switch $option {
	    deliver {
		# Let the error propagate
	    }
	    suppress {
		$dbg ignoreError
	    }
	    default {
		# Take the default action for the dialog.

		if {$uncaught} {
		    $dbg ignoreError
		}
	    }
	}
	destroy $win
	return
    }


}

# ### ### ### ######### ######### #########
## Ready

package provide rterror 1.0
