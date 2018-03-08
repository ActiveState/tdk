# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# prefWin.tcl --
#
#	This file implements the Preferences Window that manages
#	Tcl Pro Debugger preferences.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: prefWin.tcl,v 1.4 2000/10/31 23:31:00 welch Exp $

package require tile
package require widget::dialog

namespace eval prefWin {
    # The focusOrder variable is an array with one entry for
    # each tabbed window.  The value is a list of widget handles,
    # which is the order for the tab focus traversial of the 
    # window. 

    variable focusOrder

    # Widget handles and data for the Font selection window.
    # 
    # typeBox	 The combobox that lists available fixed fonts.
    # sizeBox	 The combobox that lists sizes for available fixed fonts.
    # fontSizes	 The default font sizes to choose from.

    variable typeBox
    variable sizeBox
    variable fontSizes [list 8 9 10 12 14 16 18 20 22 24 26 28]

    variable padx 6
    variable pady 4
}

# prefWin::showWindow --
#
#	Show the Prefs Window.  If the window exists then just
#	raise it to the foreground.  Otherwise, create the window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc prefWin::showWindow {} {
    # If the window already exists, show it, otherwise
    # create it from scratch.

    set prefDbgWin [maingui prefDbgWin]
    if {![winfo exists $prefDbgWin]} {
	prefWin::createWindow $prefDbgWin
    }
    set res [$prefDbgWin display]
}

proc prefWin::closeCmd {w reason} {
    if {$reason eq "ok"} {
	prefWin::Apply
    } elseif {$reason eq "apply"} {
	prefWin::Apply
	# break code means don't withdraw
	return -code break apply
    } else { # cancel
	# To just withdraw it, we need to make sure we clear changes
	after idle [list destroy $w]
	return -code break cancel
    }
}

# prefWin::createWindow --
#
#	Create the Prefs Window and all of the sub elements.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc prefWin::createWindow {root} {
    variable focusOrder
    variable padx
    variable pady

    if {[info exists focusOrder]} {
	unset focusOrder
    }

    widget::dialog $root -title "Preferences" -parent [maingui mainDbgWin] \
	-type "okcancelapply" -place over -command [list prefWin::closeCmd] \
	-synchronous 0
    wm minsize $root 100 100
    set top [$root getframe]

    pref::groupNew  TempPref
    pref::groupCopy GlobalDefault TempPref

    set tabWin [ttk::notebook $top.tabWin]

    foreach {key text var} {
	Appearance  {Appearance}     appFrm
	Windows     {Windows}        winFrm
	Startup     {Startup & Exit} errFrm
	Other       {Other}          otherFrm
    } {
	set $var [set w [ttk::frame $tabWin.f$key -padding 4]]
	$tabWin insert end $w -text $text
    }
    # XXX should have <<NotebookTabChanged>> binding that sets focus
    # XXX as we move windows

    # Appearance
    set fontWin  [prefWin::createFontWindow  $appFrm]
    set colorWin [prefWin::createColorWindow $appFrm]

    grid $fontWin  -sticky ew -padx $padx -pady $pady
    grid $colorWin -sticky ew -padx $padx -pady [list 0 $pady]
    grid columnconfigure $appFrm 0 -weight 1
    grid rowconfigure    $appFrm 2 -weight 1

    # Window
    set evalWin  [prefWin::createEvalWindow $winFrm]
    set codeWin  [prefWin::createCodeWindow $winFrm]
    set ttipWin  [prefWin::createTTipWindow $winFrm]

    grid $evalWin -sticky ew -padx $padx -pady $pady
    grid $codeWin -sticky ew -padx $padx
    grid $ttipWin -sticky ew -padx $padx -pady $pady
    grid columnconfigure $winFrm 0 -weight 1
    grid rowconfigure    $winFrm 3 -weight 1

    # Startup & Exit
    set startWin [prefWin::createStartWindow  $errFrm]
    set exitWin  [prefWin::createExitWindow  $errFrm]

    grid $startWin -sticky ew -padx $padx -pady $pady
    grid $exitWin  -sticky ew -padx $padx -pady [list 0 $pady]
    grid columnconfigure $errFrm 0 -weight 1
    grid rowconfigure    $errFrm 2 -weight 1

    # Other
    set warnWin    [prefWin::createWarnWindow $otherFrm]

    grid $warnWin    -sticky ew -padx $padx -pady $pady
    grid columnconfigure $otherFrm 0 -weight 1
    grid rowconfigure    $otherFrm 2 -weight 1

    bind $top <Return> "[list $root close ok] ; break"
    bind $top <Escape> "[list $root close cancel]; break"

    grid $tabWin -sticky news -padx $padx -pady $pady

    grid columnconfigure $top 0 -weight 1
    grid rowconfigure    $top 0 -weight 1

    $tabWin select $appFrm

    return
}

# prefWin::createSubFrm --
#
#	Create a new sub-frame.  Any preference that needs
#	an outline and title should call this routine, so
#	all sub-frames look the same.  Used by other callers.
#
# Arguments:
#	mainFrm		The containing frame.
#	winName		The name of the new sub-frame.
#	title		The title to place in the frame.
#
# Results:
#	A nested frame in the win-frame to place the widgets.

proc prefWin::createSubFrm {mainFrm winName title} {
    # make more spacing on non-aqua labelframes
    if {[tk windowingsystem] ne "aqua"} { set title " $title " }
    return [ttk::labelframe $mainFrm.$winName -text $title]
}

# prefWin::Apply --
#
#	Map the local data to the persistent data.
#
# Arguments:
#	destroy	  Boolean, if true then destroy the
#		  toplevel window.
#
# Results:
#	None.

proc prefWin::Apply {} {
    pref::groupApply TempPref GlobalDefault

    # Save the implicit prefs to the registry, or UNIX resource.  This is
    # done now to prevent preferences from being lost if the debugger
    # crashes or is terminated.

    system::saveDefaultPrefs 0

    return
}

# prefWin::createFontWindow --
#
#	Create the interface for setting fonts.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Font interface.

proc prefWin::createFontWindow {mainFrm} {
    variable focusOrder
    variable typeBox
    variable sizeBox
    variable fontSizes
    variable padx
    variable pady

    set subFrm [createSubFrm $mainFrm fontFrm "Font"]
    set typeBox [ttk::combobox $subFrm.typeBox -width 8 \
		     -textvariable [pref::prefVar fontType TempPref] \
		     -values [font::getFonts]]
    set sizeBox [ttk::combobox $subFrm.sizeBox -width 4 \
		     -textvariable [pref::prefVar fontSize TempPref] \
		     -values $fontSizes]
    grid $typeBox $sizeBox -sticky ew -padx $padx -pady $pady
    grid columnconfigure $subFrm [list 0 2] -weight 1

    $typeBox set [font::get -family]
    $sizeBox set [font::get -size]

    lappend focusOrder($mainFrm) $typeBox $sizeBox
    return $subFrm
}
#	Create the interface for setting colors.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Color interface.

proc prefWin::createColorWindow {mainFrm} {
    variable focusOrder
    variable padx
    variable pady

    set subFrm [createSubFrm $mainFrm colorFrm "Highlight Colors"]
    set blank  [image create photo [namespace current]::blank \
		    -width 25 -height 15]

    ## Highlight Colors
    foreach {pclr row col lbl} {
	highlight             0 0 "Highlight"
	highlight_error       0 2 "On Error"
	highlight_cmdresult   0 4 "On Result"
	highlight_chk_error   1 0 "Syntax Error"
	highlight_chk_warning 1 2 "Syntax warning"
	highlight_uncovered   2 0 "Uncovered Code"
	highlight_profiled    2 2 "Profiled Code"
    } {
	set clr [pref::prefGet $pclr]
	set lbl [ttk::label  $subFrm.l$pclr -text $lbl]
	set but [button $subFrm.b$pclr -borderwidth 1 -image $blank \
		     -background $clr -activebackground $clr \
		     -highlightbackground $clr \
		     -command [list prefWin::chooseColor $subFrm.b$pclr $pclr]]
	grid $lbl -row $row -column $col -sticky w -pady $pady -padx {6 0}
	grid $but -row $row -column [incr col] -sticky w -pady $pady
    }

    grid columnconfigure $subFrm 6 -weight 1

    return $subFrm
}

# prefWin::chooseColor --
#
#	Popup a color picker, and set the button's bg to the
#	result.
#
# Arguments:
#	but	The button to set.
#	pref	The preference to request the new color to.
#
# Results:
#	None.

proc prefWin::chooseColor {but pref} {
    set w [maingui prefDbgWin]
    grab $w

    set initialColor [$but cget -background]

    set color [SelectColor::menu $but.color [list below $but] \
		   -color $initialColor -parent $w]

    # If the color is not an empty string, then set the preference value 
    # to the newly selected color. We also ignore the selection if no
    # actual change was made.

    if {($color != "") && ($color ne $initialColor)} {
	$but configure -background $color -activebackground $color \
	    -highlightbackground $color
	pref::prefSet TempPref $pref $color
    }

    grab release $w
}

# prefWin::createEvalWindow --
#
#	Create the interface for setting Eval Console options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Eval Console interface.

proc prefWin::createEvalWindow {mainFrm} {
    variable focusOrder
    variable padx
    variable pady

    set subFrm    [createSubFrm $mainFrm evalFrm "Eval Console"]
    set screenLbl [ttk::label $subFrm.screenLbl -text "Screen Buffer Size"]
    set screenEnt [spinbox $subFrm.screenEnt -justify right -width 6 \
		       -textvariable [pref::prefVar screenSize TempPref] \
		       -from 25 -to 999 -increment 1]

    set histryLbl [ttk::label $subFrm.histryLbl -text "History Buffer Size"]
    set histryEnt [spinbox $subFrm.histryEnt -justify right -width 6 \
		       -textvariable [pref::prefVar historySize TempPref] \
		       -from 10 -to 999 -increment 1]

    grid $screenLbl $screenEnt x $histryLbl $histryEnt \
	-sticky w -pady $pady -padx [list $padx 0]
    grid columnconfigure $subFrm 2 -minsize [expr {2*$padx}]
    grid columnconfigure $subFrm 5 -weight 1

    lappend focusOrder($mainFrm) $screenEnt $histryEnt
    return $subFrm
}

# prefWin::createCodeWindow --
#
#	Create the interface for setting Eval Console options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Eval Console interface.

proc prefWin::createCodeWindow {mainFrm} {
    variable focusOrder
    variable padx
    variable pady

    set subFrm [createSubFrm $mainFrm codeFrm "Code Window"]
    set tabLbl [ttk::label $subFrm.screenLbl -text "Tab Size"]
    set tabEnt [spinbox $subFrm.screenEnt -justify right -width 6 \
		    -textvariable [pref::prefVar tabSize TempPref] \
		    -from 1 -to 20 -increment 4]

    grid $tabLbl $tabEnt -sticky w -pady $pady -padx [list $padx 0]
    grid columnconfigure $subFrm 3 -weight 1

    lappend focusOrder($mainFrm) $tabEnt
    return $subFrm
}

# prefWin::createTTipWindow --
#
#	Create the interface for setting Tooltip options.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Tooltip interface.

proc prefWin::createTTipWindow {mainFrm} {
    variable focusOrder
    variable padx
    variable pady

    set subFrm [createSubFrm $mainFrm ttFrm "Tooltips"]
    set chkbox [ttk::checkbutton $subFrm.ckTooltips -text "Use tooltips" \
		    -variable [pref::prefVar useTooltips TempPref]]

    grid $chkbox -sticky w -pady $pady -padx $padx
    grid columnconfigure $subFrm 1 -weight 1

    lappend focusOrder($mainFrm) $chkbox
    return $subFrm
}


proc prefWin::createStartWindow {mainFrm} {
    variable focusOrder
    variable padx
    variable pady

    set subFrm [createSubFrm $mainFrm startFrm "Startup"]
    set reloadChk [ttk::checkbutton $subFrm.reloadChk \
		     -text "Reload the previous project on startup." \
		     -variable [pref::prefVar projectReload TempPref]]
    grid $reloadChk -sticky w -pady $pady -padx $padx
    grid columnconfigure $subFrm 1 -weight 1

    lappend focusOrder($mainFrm) $reloadChk
    return $subFrm
}

proc prefWin::createExitWindow {mainFrm} {
    variable focusOrder
    variable padx
    variable pady

    set subFrm [createSubFrm $mainFrm exitFrm "On Exit"]
    set askRad [ttk::radiobutton $subFrm.askRad \
		    -text "Ask if the application should be killed." \
		    -variable [pref::prefVar exitPrompt TempPref] \
		    -value ask]
    set killRad [ttk::radiobutton $subFrm.killRad \
		     -text "Always kill the application." \
		     -variable [pref::prefVar exitPrompt TempPref] \
		     -value kill]
    set runRad [ttk::radiobutton $subFrm.runRad \
		    -text "Always leave the application running." \
		    -variable [pref::prefVar exitPrompt TempPref] \
		    -value run]
    set warnChk [ttk::checkbutton $subFrm.warnChk \
		     -text "Warn before killing the application." \
		     -variable [pref::prefVar warnOnKill TempPref]]

    grid $askRad  x $warnChk -sticky w -pady $pady -padx $padx
    grid $killRad x x        -sticky w -padx $padx
    grid $runRad  x x        -sticky w -pady $pady -padx $padx
    grid columnconfigure $subFrm 1 -minsize $padx
    grid columnconfigure $subFrm 3 -weight 1

    lappend focusOrder($mainFrm) $askRad $killRad $runRad $warnChk
    return $subFrm
}

proc prefWin::createWarnWindow {mainFrm} {
    variable focusOrder
    variable padx
    variable pady

    set subFrm [createSubFrm $mainFrm otherFrm "Warnings"]
    set mvBpChk [ttk::checkbutton $subFrm.mvBpChk \
		     -text "Warn when moving invalid breakpoints." \
		     -variable [pref::prefVar warnInvalidBp TempPref]]
    grid $mvBpChk -sticky w -pady $pady -padx $padx
    grid columnconfigure $subFrm 1 -weight 1

    lappend focusOrder($mainFrm) $mvBpChk
    return $subFrm
}

