# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# deferror.tcl --
#
#	Display of defered errors. Factored out of 'gui.tcl'
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

snit::widgetadaptor deferror {

    variable gui

    constructor {gui_ args} {
	installhull [toplevel $win]
	wm title $win "Tcl Error (Defered) - [$gui_ cget -title]"

	set gui $gui_
	$self BuildUI
	#$self configurelist $args
	return
    }

    variable errorDeferedInfoText
    variable errorDeferedData
    variable errorDeferedSel
    variable errorDeferedInfoOk
    variable errorLBox
    variable errorMsgFrm

    # Bugzilla 19825 ...
    # method createDeferedErrorWindow --
    #
    #	Create the "Defered Error" Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method BuildUI {} {
	#wm minsize  $win 100 100
	wm transient $win $gui

	set pad  6
	set pad2 [expr {$pad / 2}]

	## set mainFrm  [frame $win.mainFrm -bd $bd -relief ridged]

	set mainFrmText "Error information"
	set mainFrm     [ttk::labelframe $win.mainFrm -text $mainFrmText]
	set mainFrmW    $mainFrm

	# Title section _________________________________________

	set titleFrm [ttk::frame $mainFrm.titleFrm]
	set imageLbl [ttk::label $titleFrm.imageLbl \
			  -image $image::image(syntax_error)]
	set textLbl  [ttk::label $titleFrm.msgLbl \
			  -wraplength 500 -justify left \
			  -text \
		"One or more errors occurred in the application\
		while the system processed a debugger request.\
		The system was unable to handle these errors at\
		the time they occured and is now displaying them\
		after the fact."]

	pack $imageLbl -side left
	pack $textLbl  -side left
	pack $titleFrm -fill x -padx $pad -pady $pad

	# Data section _________________________________________

	set infoFrm   [ttk::frame   $mainFrm.infoFrm]
	set errorLBox [ttk::listbox $infoFrm.elb \
			   -selectmode single \
			   -width 2 \
			  ]

	set errorMsgFrm [ttk::frame $infoFrm.msgFrm]

	set errorDeferedInfoText [text $errorMsgFrm.errorInfoText \
				      -width 40 -height 10 -takefocus 0]

	set sb [scrollbar $mainFrm.sb -command [list $errorDeferedInfoText yview]]

	set errorDeferedShowBut [ttk::button $infoFrm.showBut \
		-text "Show Code" \
		-command [mymethod handleDefErrorShowCode]]

	#pack $errorLBox -side left -fill both ;# -expand true
	pack $errorMsgFrm          -side left -fill both -expand true -padx 1 -pady 1
	pack $errorDeferedInfoText -side left -fill both -expand true
	pack $errorDeferedShowBut  -side left -fill x    -anchor n
	pack $infoFrm                         -fill both -expand true -padx $pad -pady $pad

	bind $errorLBox <<ListboxSelect>> [mymethod handleDefErrSelection]

	# Button section _________________________________________

	set butFrm [ttk::frame $win.butFrm]
	set errorDeferedInfoOk [ttk::button $butFrm.okBut \
				    -text "Ok" -default active \
				    -command [mymethod handleDeferedError]]
	pack $errorDeferedInfoOk -side right -padx $pad
	bind $win <Return> [mymethod handleDeferedError]
	pack $butFrm -side bottom -fill x -pady $pad2


	# All together ___________________________________________

	pack $mainFrmW -side bottom -fill both -expand true -padx $pad -pady $pad

	# Activate interaction ___________________________________

	fmttext::setDbgTextBindings $errorDeferedInfoText $sb
	bind::addBindTags           $errorDeferedInfoText noEdit
	$errorDeferedInfoText configure -wrap word
	return
    }

    # Bugzilla 19825 ...
    # method updateDeferedErrorWindow --
    #
    #	Update the data in the "Defered Error" Window.
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

    method updateDeferedErrorWindow {errordata} {
	foreach item $errordata {
	    lappend errorDeferedData $item
	}
	focus $errorDeferedInfoOk

	if {[llength $errorDeferedData] > 1} {
	    # Fill the listbox with entries refering to the caught errors
	    # and initiale the dependent wigdets.

	    pack $errorLBox -side left -fill both -before $errorMsgFrm ;# -expand true
	    $errorLBox delete 0 end
	    set n 1
	    foreach item $errorDeferedData {
		$errorLBox insert end $n
		incr n
	    }
	    $errorLBox selection set 0
	    $self handleDefErrSet 0
	} else {
	    $self handleDefErrSet 0
	}
	return
    }

    # Bugzilla 19825 ...

    method handleDefErrSelection {} {
	set sel [lindex [$errorLBox curselection] 0]
	if {$sel != {}} {
	    $self handleDefErrSet $sel
	}
	return
    }

    # Bugzilla 19825 ...

    method handleDefErrSet {index} {
	set errorDeferedSel $index

	set item [lindex $errorDeferedData $index]
	foreach {stack einfo} $item { break }
	foreach {errMsg errStk errCode uncaught} $einfo { break }

	$errorDeferedInfoText delete 0.0 end
	$errorDeferedInfoText insert 0.0 "$errStk"
	return
    }

    # Bugzilla 19825 ...

    method handleDefErrorShowCode {} {
	set item [lindex $errorDeferedData $errorDeferedSel]
	foreach {stack einfo} $item { break }

	# Go through the stack of the chosen error until we find a
	# location we can display.

	set n [llength $stack] ; incr n -1
	for {set i $n} {$i >= 0} {incr i -1} {
	    set frame        [lindex $stack $i]
	    set currentPC    [lindex $frame 1]
	    if {$currentPC != {}} { break }
	}

	# We temporarily fake 'showCode' into the belief that there is an
	# error before telling it the location to jump to.

	set cb [$gui getCurrentBreak]
	$gui setCurrentBreak error
	$gui showCode $currentPC
	$gui setCurrentBreak $cb
	return
    }

    # Bugzilla 19825 ...

    method handleDeferedError {} {
	destroy $win
	return
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide deferror 1.0
