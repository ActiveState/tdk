# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# parseerror.tcl --
#
#	Display of parse (instrumentation) errors.
#	Factored out of 'gui.tcl'
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

snit::widgetadaptor parseerror {
    variable gui

    option -resultvar {}

    constructor {gui_ args} {
	installhull [toplevel $win]
	wm title $win "Parse Error - [$gui_ cget -title]"

	set gui $gui_
	$self BuildUI
	$self configurelist $args
	return
    }

    variable parseInfoText

    # method createParseErrorWindow --
    #
    #	Create the Parse Error Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method BuildUI {} {
	wm minsize   $win 100 100
	wm transient $win $gui
	wm resizable $win 1 1
	wm protocol  $win WM_DELETE_WINDOW { }

	set pad  6
	set pad2 [expr {$pad / 2}]

	set mainFrm  [ttk::frame $win.mainFrm -padding $pad]
	set titleFrm [ttk::frame $mainFrm.titleFrm]
	set imageLbl [ttk::label $titleFrm.imageLbl \
			  -image $image::image(syntax_error)]
	set msgLbl   [ttk::label $titleFrm.msgLbl -text \
		"The following error occured while instrumenting the script:"]
	pack $imageLbl -side left
	pack $msgLbl   -side left

	set infoFrm       [ttk::frame $mainFrm.infoFrm]
	set parseInfoText [text $infoFrm.parseInfoText -width 1 -height 3]
	set sb            [scrollbar $mainFrm.sb \
			       -command [list $parseInfoText yview]]

	pack $parseInfoText -side left -fill both -expand true
	pack $titleFrm                 -fill x                 -padx $pad -pady $pad
	pack $infoFrm                  -fill both -expand true -padx $pad -pady $pad

	set butFrm  [ttk::frame $win.butFrm]

	set contBut [ttk::button $butFrm.contBut \
			 -text "Continue Instrumenting" \
			 -command [mymethod handleParseError cont]]

	set dontBut [ttk::button $butFrm.dontBut -text "Do Not Instrument" \
			 -command [mymethod handleParseError dont]]

	set killBut [ttk::button $butFrm.killBut -text "Kill The Application" \
			 -command [mymethod handleParseError kill]]

	pack $killBut $dontBut $contBut -side right -padx $pad
	pack $butFrm  -side bottom -fill x                 -pady $pad2
	pack $mainFrm -side bottom -fill both -expand true -padx $pad -pady $pad

	fmttext::setDbgTextBindings $parseInfoText $sb
	bind::addBindTags $parseInfoText noEdit
	$parseInfoText configure -wrap word
	focus $butFrm.killBut
	grab  $win
	return
    }

    # method updateParseErrorWindow --
    #
    #	Update the display of the Parse Error Window to show
    #	the parse error message and provide options.
    #
    # Arguments:
    #	msg	The error msg.
    #
    # Results:
    #	None.

    # Bugzilla 19824 ... New argument: title.

    method updateParseErrorWindow {msg title} {
	$parseInfoText delete 0.0 end
	$parseInfoText insert 0.0 $msg

	wm title $win "Parse Error in $title - [$gui cget -title]"
	return
    }

    # method handleParseError --
    #
    #	Notify the engine of the user choice in handling the
    #	parse error.
    #
    # Arguments:
    #	option		One of three options for handling
    #			parse errors.
    #
    # Results:
    #	No return value, but the parseErrorVar is set to the
    #	user's option.

    method handleParseError {option} {
	grab release $win

	if {$options(-resultvar) ne ""} {
	    upvar \#0 $options(-resultvar) result
	    set result $option
	}
	destroy $win
	return
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide parseerror 1.0
