# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# projWin.tcl --
#
#	This file implements the Project Windows for the file based 
#	projects system.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: projWin.tcl,v 1.5 2000/10/31 23:31:00 welch Exp $

# ### ### ### ######### ######### #########

package require BWidget ; # BWidgets | Use its mega widgets.
NoteBook::use           ; # BWidgets / Widget used here.
package require instrument
package require snit
package require listentryb
package require img::png
package require image ; image::file::here

# ### ### ### ######### ######### #########

snit::type projWin {
    # The focusOrder variable is an array with one entry for each tabbed
    # window.  The value is a list of widget handles, which is the order for
    # the tab focus traversal of the window.

    variable focusOrder

    # The command to eval when the Project Settings window is applied or
    # destroyed.

    variable applyCmd   {}
    variable destroyCmd {}

    # Modal buttons for the Prefs Window.

    variable okBut
    variable canBut
    variable appBut

    # Widget handles for the Font selection window.
    # 
    # noInstText	The text widget that lists the glob patterns for
    #			files that are not to be instrumented.
    # doInstText	The text widget that lists the glob patterns for
    #			files that are to be instrumented.
    # addNoBut		Button used to add a glob pattern to noInst list.
    # addDoBut		Button used to add a glob pattern to doInst list.
    # remNoBut		Button used to remove a pattern from noInst list.
    # remDoBut		Button used to remove a pattern from doInst list.
    # globList		The internal list of glob patterns.

    variable noInstText
    variable doInstText
    variable addNoBut
    variable addDoBut
    variable remNoBut
    variable remDoBut

    # Widget handles for the Application Arguments window.
    #
    # scriptCombo  The combobox for the script arg.
    # argCombo     The combobox for the argument arg.
    # dirCombo     The combobox for the dir arg.
    # interpCombo  The combobox for the interp arg.
    # ipargCombo   The combobox for the interp arguments arg.

    variable localFrm    {}
    variable scriptCombo {}
    variable argCombo    {}
    variable dirCombo    {}
    variable interpCombo {}
    variable ipargCombo  {}

    variable remoteFrm   {}
    variable portEnt     {}
    variable portLbl     {}
    variable localRad    {}
    variable remoteRad   {}

    variable padx 6
    variable pady 4

    # ### ### ### ######### ######### #########

    variable             proj
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set proj    [$gui proj]
	return
    }

    # ### ### ### ######### ######### #########


    # method showWindow --
    #
    #	Show the Project Prefs Window.  If the window exists then just
    #	raise it to the foreground.  Otherwise, create the window.
    #
    # Arguments:
    #	title	The title of the window.
    #	aCmd	Callback to eval when the window is applied.  Can be null
    #	dCmd	Callback to eval when the window is destroyed.  Can be null
    #
    #
    # Results:
    #	None.

    method showWindow {title {aCmd {}} {dCmd {}}} {
	set top [$gui projSettingWin]
	if {![winfo exists $top]} {
	    $self createWindow
	    focus $top
	} else {
	    $self DestroyWindow
	    $self createWindow
	    focus $top
	}

	set applyCmd   $aCmd
	set destroyCmd $dCmd

	$self updateWindow $title
	return
    }

    # method createWindow --
    #
    #	Create the Prefs Window and all of the sub elements.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method createWindow {} {
	if {[info exists focusOrder]} {
	    unset focusOrder
	}

	set                        top [toplevel [$gui projSettingWin]]
	wm minsize                $top 100 100
	wm transient              $top $gui
	::guiUtil::positionWindow $top

	pref::groupNew  TempProj
	pref::groupCopy Project TempProj

	set tabWin [ttk::notebook $top.tabWin]

	foreach {key text var} {
	    Application     {Application}          scptFrm
	    Instrumentation {Instrumentation}      instFrm
	    Startup         {Startup & Exit}       seFrm
	    Errors          {Errors}               errFrm
	    Coverage        {Coverage & Profiling} covFrm
	    Other           Other                  otherFrm
	} {
	    set $var [set w [ttk::frame $tabWin.f$key -padding 4]]
	    $tabWin insert end $w -text $text
	}
	bind $tabWin <<NotebookTabChanged>> [mymethod NewFocus $tabWin]

	# Application Info
	set scriptWin [$self CreateScriptWindow $scptFrm]

	grid $scriptWin -sticky new; # padding done in CreateScriptWindow
	grid columnconfigure $scptFrm 0 -weight 1
	grid rowconfigure    $scptFrm 1 -weight 1

	# Instrumentation
	set instFileWin [$self CreateInstruFilesWindow   $instFrm]
	set instOptsWin [$self CreateInstruOptionsWindow $instFrm]

	grid $instFileWin -sticky nsew -padx $padx -pady $pady
	grid $instOptsWin -sticky ew -padx $padx -pady [list 0 $pady]
	grid columnconfigure $instFrm 0 -weight 1
	grid rowconfigure    $instFrm 0 -weight 1; # instFileWin resizes
	grid rowconfigure    $instFrm 1 -weight 0

	# Startup & Exit
	set startWin [$self CreateStartWindow $seFrm]
	set exitWin  [$self CreateExitWindow  $seFrm]

	grid $startWin -sticky ew -padx $padx -pady $pady
	grid $exitWin  -sticky ew -padx $padx -pady [list 0 $pady]
	grid columnconfigure $seFrm 0 -weight 1
	grid rowconfigure    $seFrm 2 -weight 1

	# Errors
	set errorWin [$self CreateErrorWindow $errFrm]

	grid $errorWin -sticky ew -padx $padx -pady $pady
	grid columnconfigure $errFrm 0 -weight 1
	grid rowconfigure    $errFrm 1 -weight 1

	# Coverage & Profiling
	set covWin [$self CreateCoverageWindow $covFrm]

	grid $covWin -sticky ew -padx $padx -pady $pady
	grid columnconfigure $covFrm 0 -weight 1
	grid rowconfigure    $covFrm 1 -weight 1

	#Other
	set otherWin [$self CreateOtherWindow $otherFrm]

	grid $otherWin -sticky ew -padx $padx -pady $pady
	grid columnconfigure $otherFrm 0 -weight 1
	grid rowconfigure    $otherFrm 1 -weight 1

	# ### ### ### ######### ######### #########

	# Create the modal buttons.
	set butFrm [ttk::frame $top.butFrm]
	set okBut [ttk::button $butFrm.okBut -text "OK" -width 10 \
		-default active -command [mymethod ApplyProjSettings 1]]
	set canBut [ttk::button $butFrm.canBut -text "Cancel" -width 10 \
		-default normal -command [mymethod CancelProjSettings]]
	set appBut [ttk::button $butFrm.appBut -text "Apply" -width 10 \
		-default normal -command [mymethod ApplyProjSettings 0]]

	#bind $top <Return> [list $okBut invoke]
	bind $top <Escape> [list $canBut invoke]

	pack $appBut -side right -padx $padx -pady $pady
	pack $canBut -side right -pady $pady
	pack $okBut  -side right -padx $padx -pady $pady

	grid $tabWin -sticky news -padx $padx -pady $pady
	grid $butFrm -sticky ew

	grid columnconfigure $top 0 -weight 1
	grid rowconfigure    $top 0 -weight 1

	# Add default bindings.
	$self SetBindings $scptFrm Application
	$self SetBindings $instFrm Instrumentation
	$self SetBindings $errFrm  Error

	$tabWin select 0
	$self NewFocus $tabWin
	return
    }

    # method updateWindow --
    #
    #	Update the project settings window when the state changes.
    #
    # Arguments:
    #	title	The title of the window.  If this is an empty string, then
    #		the title is not modified.
    #
    # Results:
    #	None.

    method updateWindow {{title {}}} {
	if {![winfo exists [$gui projSettingWin]]} {
	    return
	}

	if {$title != {}} {
	    wm title [$gui projSettingWin] "$title - [$gui cget -title]"
	}

	set state [$gui getCurrentState]
	array set color [system::getColor]

	if {[winfo exists $localRad]} {
	    if {$state == "dead" || $state == "new"} {
		$localRad configure -state normal
	    } else {
		$localRad configure -state disabled
	    }
	}
	if {[winfo exists $remoteRad]} {
	    if {$state == "dead" || $state == "new"} {
		$remoteRad configure -state normal
	    } else {
		$remoteRad configure -state disabled
	    }
	}
	if {[winfo exists $portEnt]} {
	    if {$state == "dead" || $state == "new"} {
		$portLbl configure -state normal
		$portEnt configure -state normal
	    } else {
		$portLbl configure -state disabled
		$portEnt configure -state disabled
	    }
	}
	return
    }

    # method isOpen --
    #
    #	Determine if the Project Settings Window is currently opened.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return a boolean, 1 if the window is open.

    method isOpen {} {
	return [winfo exists [$gui projSettingWin]]
    }

    # method ApplyProjSettings --
    #
    #	Map the local data to the persistent data.
    #
    # Arguments:
    #	destroy	  Boolean, if true then destroy the toplevel window.
    #
    # Results:
    #	None.  The project setting vwait variable is set to 0
    #	indicating the window was canceled.

    method ApplyProjSettings {destroy} {
	# Save the implicit prefs to the registry, or UNIX resource.  This is
	# done now to prevent preferences from being lost if the debugger
	# crashes or is terminated.

	system::saveDefaultPrefs 0

	# Apply the project preferences.  If the applyCmd pointer is not 
	# empty, evaluate the command at the global scope. Delete the 
	# window if the destroy bit is true.

	pref::groupApply TempProj Project

	if {$applyCmd != {}} {
	    uplevel #0 $applyCmd $destroy
	}
	if {$destroy} {
	    $self CancelProjSettings
	}

	return
    }

    # method CancelProjSettings --
    #
    #	Destroy the Project Settings Window, do not set any
    #	preferences, and set the project setting vwait var.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.  The project setting vwait variable is set to 0
    #	indicating the window was canceled.

    method CancelProjSettings {} {
	if {$destroyCmd != {}} {
	    uplevel #0 $destroyCmd 1
	}
	$self DestroyWindow
	focus -force $gui
	return
    }

    # method DestroyWindow --
    #
    #	Destroy the window and remove the TempProj group.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method DestroyWindow {} {
	trace vdelete [myvar doInstrument]   w [mymethod InstrPatternSave doInstrument]
	trace vdelete [myvar dontInstrument] w [mymethod InstrPatternSave dontInstrument]
	trace vdelete [myvar instrRoot]      w [mymethod InstrRootSave]

	trace vdelete [pref::prefVar appScript TempProj] w [mymethod InstrRootPath]

	if {[pref::groupExists TempProj]} {
	    pref::groupDelete TempProj
	}
	if {[info command [$gui projSettingWin]] != {}} {
	    destroy [$gui projSettingWin]
	}
	return
    }

    # method SetBindings --
    #
    #	Set the tab order and default bindings on the 
    #	active children of all sub windows.
    #
    # Arguments:
    #	mainFrm 	The name of the containing frame.
    #	name		The name to use for the bindtag.
    #
    # Results:
    #	None.

    method SetBindings {mainFrm name} {
	# Add the modal buttons to the list of active widgets
	# when specifing tab order.  When the tab window is
	# raised, the $self NewFocus proc is called and
	# that will add the appropriate bindtags so the tab
	# order is maintained.

	foreach win $focusOrder($mainFrm) {
	    bind::addBindTags $win pref${name}Tab$self
	}
	lappend focusOrder($mainFrm) $okBut $canBut $appBut
	bind::commonBindings pref${name}Tab$self $focusOrder($mainFrm)

	return
    }

    # method NewFocus --
    #
    #	Re-bind the modal buttons so the correct tab order
    #	is maintained.
    #
    # Arguments:
    #	old	The name of the window loosing focus.
    #	new	The name of the window gaining focus.
    #
    # Results:
    #	None.

    variable lastPane {}
    method NewFocus {tabWin} {
	# Make the newly raised pane the old pane for the next call of
	# raise/NewFocus. This modification of bindings avoids the usage
	# of global variable to store this state.
	if {$lastPane ne ""} {
	    set old [$tabWin tab $lastPane -text]
	    set tag pref${old}Tab$self
	    bind::removeBindTag $okBut  $tag
	    bind::removeBindTag $canBut $tag
	    bind::removeBindTag $appBut $tag
	}
	set newPane [$tabWin index current]
	set lastPane $newPane
	set new [$tabWin tab $newPane -text]
	set tag pref${new}Tab$self
	bind::addBindTags $okBut  $tag
	bind::addBindTags $canBut $tag
	bind::addBindTags $appBut $tag

	return
    }

    # method AddToCombo --
    #
    #	Preserve the entry of the combobox so it can be reloaded
    #	each new session.
    #
    # Arguments:
    #	combo		The handle to the combo box.
    #	value		The contents of the entry box.
    #
    # Results:
    #	Return the list of elements in the combobox's drop down list.

    method AddDirectory {value} {
	set dlist [$self AddToCombo $dirCombo $value]
	$dirCombo set $value
	return $dlist
    }

    method AddToCombo {combo value} {
	# Store the contents of the listbox in the prefs::data array.
	# This will be used to restore the listbox between sessions.

	set size [pref::prefGet comboListSize]

	if {$value == {}} {
	    set  result [$combo cget -values]
	    set  result [linsert $result 0 {}]
	    incr size
	} else {
	    set     result [$combo cget -values]
	    lappend result $value

	    # Bugzilla 19698 ... Remove duplicate entries ...
	    $combo configure -values [lsort -unique $result]
	}

	# Only store the most recent <historySize> entries.
	# Store refers here to the persistent preferences,
	# which are updated by the caller

	if {[llength $result] > $size} {
	    set end [expr {$size - 1}]
	    set result [lrange $result 0 $end]
	}
	return $result
    }

    # method CreateScriptWindow --
    #
    #	Create the interface for setting script options.
    #
    # Arguments:
    #	mainFrm		The containing frame.
    #
    # Results:
    #	A handle to the frame containing the Error interface.

    method CreateScriptWindow {mainFrm} {
	# Toggle frame that switches between the local and remote 
	# preference windows.

	set cntrFrm [ttk::frame $mainFrm.cntrFrm]
	set appFrm  [prefWin::createSubFrm $cntrFrm appFrm "Debugging Type"]
	set localRad [ttk::radiobutton $appFrm.localRad \
		-text "Local Debugging" \
		-command [mymethod ShowDebuggingType $mainFrm local] \
		-variable [pref::prefVar appType TempProj] \
		-value local]
	set remoteRad [ttk::radiobutton $appFrm.remoteRad \
		-text "Remote Debugging" \
		-command [mymethod ShowDebuggingType $mainFrm remote] \
		-variable [pref::prefVar appType TempProj] \
		-value remote]

	# Local Debugging Window -
	# Create the interface for entering basic info about the
	# script to be debugged; script name, arguments, working
	# directory and interpreter.

	set localFrm [prefWin::createSubFrm $cntrFrm localFrm "Local Debugging"]
	set scriptLbl [ttk::label $localFrm.scriptLbl -text "Script:" \
		-width 40 -anchor w]

	set scriptCombo [ttk::combobox $localFrm.scriptCombo \
		-textvariable [pref::prefVar appScript TempProj]]

	# Update the base default include pattern when the script
	# changes, the other influence is 'instrumentRoot'.
	trace variable [pref::prefVar appScript TempProj] w [mymethod InstrRootPath]

	set scriptBut [ttk::button $localFrm.scriptBut -text "Browse..." \
		-command [list $proj openComboFileWindow $scriptCombo \
		[list {{Tcl Scripts} {.tcl .tk}} {{Test Scripts} .test} \
		{{All files} *}]]]

	set argLbl [ttk::label $localFrm.argLbl -text "Script Arguments:"]
	set argCombo [ttk::combobox $localFrm.argCombo \
		-textvariable [pref::prefVar appArg TempProj]]

	set dirLbl [ttk::label $localFrm.dirLbl -text "Working Directory:"]
	set dirCombo [ttk::combobox $localFrm.dirCombo \
		-textvariable [pref::prefVar appDir TempProj]]

	set dirBut [ttk::button $localFrm.dirBut -text "Browse..." \
		-command [list $proj openComboDirWindow $dirCombo]]

	set interpLbl [ttk::label $localFrm.interpLbl -text "Interpreter:"]
	set interpCombo [ttk::combobox $localFrm.interpCombo \
		-textvariable [pref::prefVar appInterp TempProj]]
	set interpBut [ttk::button $localFrm.interpBut -text "Browse..." \
		-command [list $proj openComboFileWindow $interpCombo \
		[system::getExeFiles]]]

	set interpALbl [ttk::label $localFrm.interpALbl -text "Interpreter Arguments:"]
	set ipargCombo [ttk::combobox $localFrm.interpACombo \
		-textvariable [pref::prefVar appInterpArg TempProj]]

	# Load the combo boxes with the Project's history.

	# Bugzilla 19618 ... collapse lists to contain only unique paths

	set s  [system::uniquePaths [pref::prefGet appScriptList TempProj]]
	set a  [pref::prefGet appArgList    TempProj]
	set d  [system::uniquePaths [pref::prefGet appDirList    TempProj]]
	set i  [system::uniquePaths [pref::prefGet appInterpList TempProj]]
	set ia [pref::prefGet appInterpArgList    TempProj]

	# If the interp list is empty, or just contains white space, fill it
	# with the default values.  This code was added to make up for prior
	# releases that left the interp list empty on Windows.

	if {[llength $i] < 2} {
	    if {[string length [string trim [lindex $i 0]]] == 0} {
		set i {}
	    }
	    foreach interp [system::getInterps] {
		lappend i $interp
	    }
	    pref::prefSet Project appInterpList $i
	    pref::prefSet TempProj appInterpList $i

	    # Give the interp the value of the 1st elt of the interp list.
	    # This causes users never to have to add the interp themselves.

	    set firstInterp [lindex $i 0]
	    pref::prefSet Project appInterp $firstInterp
	    pref::prefSet TempProj appInterp $firstInterp
	}

	$scriptCombo  configure -values $s
	$argCombo     configure -values $a
	$dirCombo     configure -values $d
	$interpCombo  configure -values $i
	$ipargCombo   configure -values $ia

	# Bugzilla 19617 ... This explicit setting of the value to display
	# interferes with the implicit selection done through
	# => -textvariable

	# Remote Debugging Window -
	# Create the window for setting preferences on remote applications.
	# Simply ask for the port they want to connect on.

	set remoteFrm [prefWin::createSubFrm $cntrFrm remoteFrm "Port"]
	set portLbl [ttk::label $remoteFrm.screenLbl \
		-text "Listen for remote connection on port number"]
	set portEnt [ttk::entry $remoteFrm.screenEnt -justify right -width 6 \
		-textvariable [pref::prefVar portRemote TempProj]]

	grid $localRad $remoteRad -sticky w -padx $padx
	grid columnconfigure $appFrm 1 -weight 1 -minsize 20
	grid columnconfigure $appFrm 2 -weight 1 -minsize 20

	grid $scriptLbl   -sticky nw -padx $padx
	grid $scriptCombo $scriptBut -sticky ew -padx $padx
	grid $argLbl      -sticky nw -padx $padx -columnspan 2
	grid $argCombo    -sticky we -padx $padx
	grid [ttk::frame $localFrm.frmSep1 -height 5]

	grid $dirLbl      -sticky nw -padx $padx -columnspan 2
	grid $dirCombo $dirBut -padx $padx -sticky we
	grid [ttk::frame $localFrm.frmSep2 -height 5]

	grid $interpLbl   -sticky nw -padx $padx -columnspan 2
	grid $interpCombo $interpBut -padx $padx -sticky ew
	grid $interpALbl   -sticky nw -padx $padx -columnspan 2
	grid $ipargCombo $interpBut -padx $padx -sticky ew
	grid [ttk::frame $localFrm.frmSep3 -height $padx] -sticky we

	grid configure $scriptCombo -sticky we
	grid configure $interpCombo -sticky we
	grid columnconfigure $localFrm 0 -weight 1

	grid $portLbl $portEnt -sticky w -padx [list $padx 0] -pady $pady
	grid columnconfigure $remoteFrm 3 -weight 1

	grid $appFrm    -row 0 -column 0 -sticky new -padx $padx -pady $pady
	grid $localFrm  -row 1 -column 0 -sticky new -padx $padx
	grid $remoteFrm -row 1 -column 0 -sticky new -padx $padx -pady $pady
	grid columnconfigure $cntrFrm 0 -weight 1
	grid rowconfigure    $cntrFrm 3 -weight 1

	lappend focusOrder($mainFrm) $localRad $remoteRad
	# display correct frame for current debugging type
	if {[$proj isRemoteProj]} {
	    grid remove $localFrm
	    lappend focusOrder($mainFrm) $portEnt
	} else {
	    grid remove $remoteFrm
	    lappend focusOrder($mainFrm) $scriptCombo $argCombo \
		    $dirCombo $interpCombo
	}

	return $cntrFrm
    }

    # method ShowDebuggingType --
    #
    #	Used by the Application window, toggle between the Remote
    #	interface and the loacl interface.
    #
    # Arguments:
    #	type	Indicates which type is being toggled to. (local or remote)
    #
    # Results:
    #	None.

    method ShowDebuggingType {mainFrm ptype} {
	wm geometry [$gui projSettingWin] \
		[winfo geometry [$gui projSettingWin]]

	if {$ptype == "local"} {
	    grid remove $remoteFrm
	    grid $localFrm

	    set focusOrder($mainFrm) [lreplace $focusOrder($mainFrm) 2 2 \
		    $scriptCombo $argCombo $dirCombo $interpCombo]
	    bind::commonBindings prefApplicationTab$self $focusOrder($mainFrm)
	} else {
	    grid remove $localFrm
	    grid $remoteFrm

	    set focusOrder($mainFrm) [lreplace $focusOrder($mainFrm) 2 5 \
		    $portEnt]
	    bind::commonBindings prefApplicationTab$self $focusOrder($mainFrm)
	}

	$self updateWindow
	return
    }

    # method CreateErrorWindow --
    #
    #	Create the interface for setting Error options.
    #
    # Arguments:
    #	mainFrm		The containing frame.
    #
    # Results:
    #	A handle to the frame containing the Error interface.

    method CreateErrorWindow {mainFrm} {
	set subFrm [prefWin::createSubFrm $mainFrm errorFrm "Errors"]
	set errRad1 [ttk::radiobutton $subFrm.errRad1 \
		-text "Always stop on errors" \
		-variable [pref::prefVar errorAction TempProj] \
		-value 2]
	set errRad2 [ttk::radiobutton $subFrm.errRad2 \
		-text "Only stop on uncaught errors" \
		-variable [pref::prefVar errorAction TempProj] \
		-value 1]
	set errRad3 [ttk::radiobutton $subFrm.errRad3 \
		-text "Never stop on errors" \
		-variable [pref::prefVar errorAction TempProj] \
		-value 0]

	grid $errRad1 -sticky w -padx $padx
	grid $errRad2 -sticky w -padx $padx
	grid $errRad3 -sticky w -padx $padx
	grid columnconfigure $subFrm 0 -weight 1

	lappend focusOrder($mainFrm) $errRad1 $errRad2 $errRad3
	return $mainFrm.errorFrm
    }

    # method CreateCoverageWindow --
    #
    #	Create the interface for setting Coverage options.
    #
    # Arguments:
    #	mainFrm		The containing frame.
    #
    # Results:
    #	A handle to the frame containing the Coverage interface.

    method CreateCoverageWindow {mainFrm} {
	set subFrm [prefWin::createSubFrm $mainFrm covFrm "Coverage"]
	set covRad1 [ttk::radiobutton $subFrm.covRad1 \
		-text "Neither coverage nor profiling" \
		-variable [pref::prefVar coverage TempProj] \
		-value none]
	set covRad2 [ttk::radiobutton $subFrm.covRad2 \
		-text "Plain coverage" \
		-variable [pref::prefVar coverage TempProj] \
		-value coverage]
	set covRad3 [ttk::radiobutton $subFrm.covRad3 \
		-text "Profiling" \
		-variable [pref::prefVar coverage TempProj] \
		-value profile]

	grid $covRad1 -sticky w -padx $padx
	grid $covRad2 -sticky w -padx $padx
	grid $covRad3 -sticky w -padx $padx
	grid columnconfigure $subFrm 0 -weight 1

	lappend focusOrder($mainFrm) $covRad1 $covRad2 $covRad3
	return $mainFrm.covFrm
    }


    method CreateStartWindow {mainFrm} {
	set subFrm [prefWin::createSubFrm $mainFrm startFrm "Startup"]

	set aaChk [ttk::checkbutton $subFrm.aaChk \
		-text "Automatically add all spawnpoints to any newly loaded script." \
		-variable [pref::prefVar autoAddSpawn TempProj]]

	grid $aaChk -sticky w -padx $padx
	grid columnconfigure $subFrm 0 -weight 1

	lappend focusOrder($mainFrm) $aaChk
	return $mainFrm.startFrm
    }

    method CreateExitWindow {mainFrm} {
	set subFrm [prefWin::createSubFrm $mainFrm exitFrm "Exit"]

	set akChk [ttk::checkbutton $subFrm.akChk \
		-text "Automatically kill a spawned sub-session when its application completes." \
		-variable [pref::prefVar autoKillSub TempProj]]

	grid $akChk -sticky w -padx $padx
	grid columnconfigure $subFrm 0 -weight 1

	lappend focusOrder($mainFrm) $akChk
	return $mainFrm.exitFrm
    }


    # method CreateOtherWindow --
    #
    #	Create the interface for setting Other options.
    #
    # Arguments:
    #	mainFrm		The containing frame.
    #
    # Results:
    #	A handle to the frame containing the Other interface.

    method CreateOtherWindow {mainFrm} {
	set subFrm [prefWin::createSubFrm $mainFrm otherFrm "Other"]

	set ssc [ttk::checkbutton $subFrm.ic \
		    -variable  [pref::prefVar staticSyntaxCheck TempProj] \
		    -text {Run static syntax checker}]

	set coreLbl   [ttk::label    $subFrm.coreLbl -text "Tcl Version:"]
	set coreCombo [ttk::combobox $subFrm.coreCombo \
		-textvariable [pref::prefVar staticSyntaxCore TempProj]]

	$coreCombo configure -values {8.4 8.5 8.6}

	set msgLbl  [ttk::label $subFrm.msgLbl -text "Suppress:"]
	set msgList [listentryb $subFrm.msgList \
		    -height 5 \
		    -listvariable [pref::prefVar staticSyntaxSuppress TempProj] \
		    -labels  {message id}  \
		    -labelp  {message ids} \
		    -ordered 0 \
		    -browse  0]

	grid $ssc -sticky w -padx $padx -row 0 -column 0 ;#-columnspan 2
	grid columnconfigure $subFrm 0 -weight 1

	grid $coreLbl   -sticky w -padx $padx -row 1 -column 0
	grid $coreCombo -sticky w -padx $padx -row 2 -column 0

	grid $msgLbl  -sticky w -padx $padx -row 3 -column 0
	grid $msgList -sticky w -padx $padx -row 4 -column 0

	lappend focusOrder($mainFrm) $ssc $coreCombo
	return $mainFrm.otherFrm
    }

    # method CreateInstruFilesWindow --
    #
    #	Create the interface for specifying which files
    #	(not) to instrument.
    #
    # Arguments:
    #	mainFrm		The containing frame.
    #
    # Results:
    #	A handle to the frame containing the Instrumentation interface.

    variable doInstrument   {}
    variable dontInstrument {}
    variable instrRoot     0
    variable instrRootPath {*}

    method CreateInstruFilesWindow {mainFrm} {
	set subFrm [prefWin::createSubFrm $mainFrm instFrm \
		"Choose which files to instrument"]

	set doInstrument   [pref::prefGet doInstrument   TempProj]
	set dontInstrument [pref::prefGet dontInstrument TempProj]
	set instrRoot      [pref::prefGet instrumentRoot TempProj]
	$self InstrRootPath

	set instr {Instrument all files with paths matching these patterns:}
	set exstr {Except for files with paths matching these patterns:}
	set root  {Instrument all files under the startup script's root directory}

	set il [ttk::label $subFrm.il -text $instr]

	set ic [ttk::checkbutton $subFrm.ic -variable [myvar instrRoot] \
		    -text $root]

	set in [listentryb $subFrm.in \
		    -height 5 \
		    -listvariable [myvar doInstrument] \
		    -labels  {pattern}  \
		    -labelp  {patterns} \
		    -valid   [mymethod InstrPatternValid doInstrument] \
		    -ordered 0 \
		    -browse  0]

	set el [ttk::label $subFrm.el -text $exstr]

	set ex [listentryb $subFrm.ex \
		    -height 5 \
		    -listvariable [myvar dontInstrument] \
		    -labels  {pattern}  \
		    -labelp  {patterns} \
		    -valid   [mymethod InstrPatternValid dontInstrument] \
		    -ordered 0 \
		    -browse  0]

	grid $il -column 0 -row 0 -sticky nw
	grid $ic -column 0 -row 1 -sticky nw
	grid $in -column 0 -row 2 -sticky swen
	grid $el -column 0 -row 3 -sticky nw
	grid $ex -column 0 -row 4 -sticky swen

	grid columnconfigure $subFrm 0     -weight 1 -minsize 20
	grid rowconfigure    $subFrm {2 4} -weight 1 -minsize 20

	# Actions ...

	trace variable [myvar doInstrument]   w [mymethod InstrPatternSave doInstrument]
	trace variable [myvar dontInstrument] w [mymethod InstrPatternSave dontInstrument]
	trace variable [myvar instrRoot]      w [mymethod InstrRootSave]

	return $subFrm
    }

    method InstrPatternValid {key content} {
	upvar 0 $key current
	if {$content eq ""} {
	    return {* Empty}
	} elseif {[lsearch -exact $current $content] >= 0} {
	    return {* Duplicate of a known pattern}
	}
	return {}
    }

    method InstrPatternSave {key args} {
	upvar 0 $key current
	pref::prefSet TempProj $key $current
	return
    }

    method InstrRootSave {args} {
	pref::prefSet TempProj instrumentRoot $instrRoot
	$self InstrRootPath
	return
    }

    method InstrRootPath {args} {
	if {$instrRoot} {
	    # Root instrumentation, derive pattern for the default
	    # from the startup script (its directory).

	    set dir [file dirname [pref::prefGet appScript TempProj]]

	    if {$dir eq "."} {
		# Relative, and no directory present at all. Keep instrumenting
		# everything.
		set new *
	    } elseif {[file pathtype $dir] eq "relative"} {
		# Relative path, put * in front, to match everything
		# independent of absolute location.
		set new */${dir}/*
	    } else {
		# Absolute path, match everything below it.
		set new ${dir}/*
	    }
	} else {
	    # No root instrumentation, basic default is to include everything.
	    set new *
	}

	# Do nothing if no change was required.
	if {$new eq $instrRootPath} return

	# Replace old against new.
	set pos [lsearch -exact $doInstrument $instrRootPath]
	if {$pos < 0} {
	    lappend doInstrument $new
	} else {
	    set doInstrument [lreplace $doInstrument $pos $pos $new]
	}
	set instrRootPath $new
	return
    }

    # proc::CreateInstruOptionsWindow --
    #
    #	Create the interface for setting Instrumentation options.
    #
    # Arguments:
    #	mainFrm		The containing frame.
    #
    # Results:
    #	A handle to the frame containing the Instrumentation interface.

    method CreateInstruOptionsWindow {mainFrm} {
	set subFrm [prefWin::createSubFrm $mainFrm optFrm "Options"]
	set dynChk [ttk::checkbutton $subFrm.dynChk \
		-text "Instrument dynamic procs" \
		-variable [pref::prefVar instrumentDynamic TempProj]]
	set autoChk [ttk::checkbutton $subFrm.autoChk \
		-text "Instrument auto loaded scripts" \
		-variable [pref::prefVar autoLoad TempProj]]
	set incrChk [ttk::checkbutton $subFrm.incrChk \
		-text "Instrument Incr Tcl" \
		-variable [pref::prefVar instrumentIncrTcl TempProj]]
	set tclxChk [ttk::checkbutton $subFrm.tclxChk \
		-text "Instrument TclX" \
		-variable [pref::prefVar instrumentTclx]]
	set expectChk [ttk::checkbutton $subFrm.expectChk \
		-text "Instrument Expect" \
		-variable [pref::prefVar instrumentExpect]]

	grid $dynChk  $incrChk   -sticky w -padx $padx
	grid $autoChk $tclxChk   -sticky w -padx $padx
	grid x        $expectChk -sticky w -padx $padx
	grid columnconfigure $subFrm 1 -minsize 20
	grid columnconfigure $subFrm 3 -weight 1

	lappend focusOrder($mainFrm) $dynChk $autoChk $incrChk $tclxChk $expectChk
	return $mainFrm.optFrm
    }

    # method nonEmptyInstruText --
    #
    #	If the doInstrument list is empty, then add the "*" pattern to it.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method nonEmptyInstruText {} {
	if {[llength [pref::prefGet doInstrument TempProj]] == 0} {
	    pref::prefSet Project  doInstrument {*}
	    pref::prefSet TempProj doInstrument {*}
	}
    }

    # method updateScriptList --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateScriptList {} {
	if {[pref::groupExists TempProj] && \
		[pref::prefGet appType TempProj] eq "local"} {
	    # Add the current combo entry to the combo's drop down 
	    # list.  The result of the command is the ordered list
	    # of elements in the combo's drop down list.

	    set script [pref::prefGet appScript TempProj]
	    set sList  [$self AddToCombo $scriptCombo $script]

	    if {$sList != [pref::prefGet appScriptList Project]} {
		pref::prefSet Project  appScriptList $sList
		pref::prefSet TempProj appScriptList $sList
	    }
	}
	return
    }

    # method updateInterpList --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateInterpList {} {
	if {[pref::groupExists TempProj] && \
		[pref::prefGet appType TempProj] eq "local"} {
	    # Add the current combo entry to the combo's drop down 
	    # list.  The result of the command is the ordered list
	    # of elements in the combo's drop down list.

	    set interp [pref::prefGet appInterp TempProj]
	    set iList  [$self AddToCombo $interpCombo $interp]

	    if {$iList != [pref::prefGet appInterpList Project]} {
		pref::prefSet Project  appInterpList $iList
		pref::prefSet TempProj appInterpList $iList
	    }
	}
	return
    }

    # method updateArgList --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateArgList {} {
	if {[pref::groupExists TempProj] && \
		[pref::prefGet appType TempProj] == "local"} {
	    # Add the current combo entry to the combo's drop down 
	    # list.  The result of the command is the ordered list
	    # of elements in the combo's drop down list.

	    set arg   [pref::prefGet appArg TempProj]
	    set aList [$self AddToCombo $argCombo $arg]

	    if {$aList != [pref::prefGet appArgList Project]} {
		pref::prefSet Project  appArgList $aList
		pref::prefSet TempProj appArgList $aList
	    }
	}
	return
    }

    # method updateInterpArgList --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateInterpArgList {} {
	if {[pref::groupExists TempProj] && \
		[pref::prefGet appType TempProj] == "local"} {
	    # Add the current combo entry to the combo's drop down 
	    # list.  The result of the command is the ordered list
	    # of elements in the combo's drop down list.

	    set arg   [pref::prefGet appInterpArg TempProj]
	    set aList [$self AddToCombo $argCombo $arg]

	    if {$aList != [pref::prefGet apInterppArgList Project]} {
		pref::prefSet Project  appInterpArgList $aList
		pref::prefSet TempProj appInterpArgList $aList
	    }
	}
	return
    }

    # method updateDirList --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateDirList {} {
	if {[pref::groupExists TempProj] && \
		[pref::prefGet appType TempProj] == "local"} {
	    # Add the current combo entry to the combo's drop down 
	    # list.  The result of the command is the ordered list
	    # of elements in the combo's drop down list.

	    set dir   [pref::prefGet appDir TempProj]
	    set dList [$self AddToCombo $dirCombo $dir]

	    if {$dList != [pref::prefGet appDirList Project]} {
		pref::prefSet Project  appDirList $dList
		pref::prefSet TempProj appDirList $dList
	    }
	}
	return
    }

    # method updateIncrTcl --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateIncrTcl {} {
	instrument::extension incrTcl [pref::prefGet instrumentIncrTcl]
	return
    }

    # method updateExpect --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateExpect {} {
	instrument::extension expect [pref::prefGet instrumentExpect]
	return
    }

    # method updateTclX --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateTclX {} {
	instrument::extension tclx [pref::prefGet instrumentTclx]
	return
    }

    # method updatePort --
    #
    #	Update command for the project script preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updatePort {} {
	return
    }


    method clearDestroyCmd {} {
	set destroyCmd {}
	return
    }
}

# ### ### ### ######### ######### #########

package provide projWin 1.0
