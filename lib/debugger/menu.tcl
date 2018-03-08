# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# menu.tcl --
#
#	This file implements the menus for the Debugger.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2009 ActiveState Software Inc.

# 
# RCS: @(#) $Id: menu.tcl,v 1.15 2000/10/31 23:30:59 welch Exp $

package require treectrl

namespace eval menu {

    variable  active {}
    variable  statecache
    array set statecache {}

    variable selFileWin

    variable showCmd
    variable maxMenuSize 10

    variable postCmd
    variable invokeCmd

    array set postCmd {
	<<Proj_New>>		menu::filePostCmd
	<<Proj_Open>>		menu::filePostCmd
	<<Proj_Close>>		menu::filePostCmd
	<<Proj_Save>>		menu::filePostCmd
	<<Proj_Settings>>	menu::filePostCmd
	<<Dbg_Open>>		menu::filePostCmd
	<<Dbg_Refresh>>		menu::filePostCmd
	<<Dbg_Komodo>>		menu::filePostCmd
	<<Dbg_Exit>>		{}
	<<Cut>>			menu::editPostCmd
	<<Copy>>		menu::editPostCmd
	<<Paste>>		{}
	<<Delete>>		{}
	<<Dbg_Find>>		{}
	<<Dbg_FindNext>>	menu::editPostCmd	
	<<Dbg_Goto>>		{}
	<<Dbg_Break>>		{}
	<<Dbg_Eval>>		{}
	<<Dbg_Proc>>		{}
	<<Dbg_Watch>>		{}
	<<Dbg_Syntax>>		{}
	<<Dbg_DataDisp>>	menu::viewPostCmd
	<<Dbg_Run>>		menu::dbgPostCmd
	<<Dbg_Pause>>		menu::dbgPostCmd
	<<Dbg_Stop>>		menu::dbgPostCmd
	<<Dbg_Restart>>		menu::dbgPostCmd
	<<Dbg_CloseDebugger>>	menu::dbgPostCmd
	<<Dbg_In>>		menu::dbgPostCmd
	<<Dbg_Over>>		menu::dbgPostCmd
	<<Dbg_Out>>		menu::dbgPostCmd
	<<Dbg_To>>		menu::dbgPostCmd
	<<Dbg_CmdResult>>	menu::dbgPostCmd
	<<Dbg_AddWatch>>	menu::dbgPostCmd
	<<Dbg_Help>>		{}
    }

    array set invokeCmd {
	<<Proj_New>>		{$menu(file) invoke {New Project*}}
	<<Proj_Open>>		{$menu(file) invoke {Open Project*}}
	<<Proj_Close>>		{$menu(file) invoke {Close Project*}}
	<<Proj_Save>>		{$menu(file) invoke {Save Project}}
	<<Proj_Settings>>	{$menu(file) invoke {*Project Settings*}}
	<<Dbg_Open>>		{$menu(file) invoke {Open File*}}
	<<Dbg_Refresh>>		{$menu(file) invoke {Refresh File*}}
	<<Dbg_Komodo>>		{$menu(file) invoke {Edit In Komodo*}}
	<<Dbg_Exit>>		{$menu(file) invoke {Exit}}
	<<Cut>>			{$menu(edit) invoke {Cut}}
	<<Copy>>		{$menu(edit) invoke {Copy}}
	<<Paste>>		{$menu(edit) invoke {Paste}}
	<<Delete>>		{$menu(edit) invoke {Delete}}
	<<Dbg_Find>>		{$menu(edit) invoke {Find...}}
	<<Dbg_FindNext>>	{$menu(edit) invoke {Find Next}}
	<<Dbg_Goto>>		{$menu(edit) invoke {Goto Line*}}
	<<Dbg_Break>>		{$menu(view) invoke {Breakpoints*}}
	<<Dbg_Eval>>		{$menu(view) invoke {Eval Console*}}
	<<Dbg_Proc>>		{$menu(view) invoke {Procedures*}}
	<<Dbg_Watch>>		{$menu(view) invoke {Watch Variables*}}
	<<Dbg_Syntax>>		{$menu(view) invoke {Syntax errors*}}
	<<Dbg_DataDisp>>	{$menu(view) invoke {Data Display*}}
	<<Dbg_Run>>		{$menu(dbg)  invoke {Run}}
	<<Dbg_Pause>>		{$menu(dbg)  invoke {Pause}}
	<<Dbg_Stop>>		{$menu(dbg)  invoke {Stop}}
	<<Dbg_Restart>>		{$menu(dbg) invoke {Restart}}
	<<Dbg_CloseDebugger>>	{$menu(dbg) invoke {Close Debugger}}
	<<Dbg_In>>		{$menu(dbg)  invoke {Step In}}
	<<Dbg_Over>>		{$menu(dbg)  invoke {Step Over}}
	<<Dbg_Out>>		{$menu(dbg)  invoke {Step Out}}
	<<Dbg_To>>		{$menu(dbg)  invoke {Run To Cursor}}
	<<Dbg_CmdResult>>	{$menu(dbg)  invoke {Step To Result}}
	<<Dbg_AddWatch>>	{$menu(dbg)  invoke {Add Var To Watch*}}
    }
    if {[string equal $::tcl_platform(platform) "windows"]} {
	# On non-windows, remove the Tcl/Tk help menu item
	set postCmd(<<Dbg_TclHelp>>) {}
	set invokeCmd(<<Dbg_TclHelp>>) {$menu(help) invoke {Help}}
    }
    set invokeCmd(<<Dbg_Help>>) \
	{$menu(help) invoke {Help}}

    variable focusWin ;# Remember focus for cascades ...

}



# menu::create --
#
#	Create all of the menus for the main debugger window.
#
# Arguments:
#	mainDbgWin	The toplevel window for the main debugger.
#
# Results:
#	The namespace variables gui(showToolbar) and gui(showStatus)
#	are set to true, indicating that the toolbar and status window
#	should be displayed.

proc menu::create {mainDbgWin} {
    variable show
    variable menu

    set menubar [menu $mainDbgWin.menubar -tearoff 0 -bd 1]

    # Special .apple menu must be FIRST.
    if {[tk windowingsystem] eq "aqua"} {
	# Apple Menu - Help. Non-aqua and other see (*).
	set apple [menu $menubar.apple -tearoff 0]
	$menubar add cascade -label "&TDK" -menu $apple -underline 0
	$apple add command -label "About $::projectInfo::productName"  \
	    -command splash::showAbout -underline 0
    }

    array set menuKeys [system::getKeyBindings]

    # New File menu.
    set file [menu $menubar.file -tearoff 0 \
	    -postcommand menu::filePostCmd]
    $menubar add cascade -label "File" -menu $file -underline 0
    $file add command -label "Open File..." \
	    -command {maingui openFile} -underline 5 \
	    -acc $menuKeys(Dbg_Open)
    $file add command -label "Refresh File..." \
	    -command {maingui refreshFile} -underline 6 \
	    -acc $menuKeys(Dbg_Refresh)
    $file add command -label "Open In Komodo..." -acc $menuKeys(Dbg_Komodo) \
	    -command {maingui editInKomodo} -underline 5
    $file add separator
    $file add command -label "New Project..." \
	    -command {maingui prShowNewProjWindow} -underline 0 \
	    -acc $menuKeys(Proj_New)
    $file add command -label "Open Project..." \
	    -command {maingui prOpenProjCmd} -underline 0 \
	    -acc $menuKeys(Proj_Open)
    $file add command -label "Close Project..." \
	    -command {maingui prCloseProjCmd} -underline 0 \
	    -acc $menuKeys(Proj_Close)
    $file add separator
    $file add command -label "Save Project" \
	    -command {maingui prSaveProjCmd} -underline 0 \
	    -acc $menuKeys(Proj_Save)
    $file add command -label "Save Project As..."  -underline 13 \
	-command {maingui prSaveAsProjCmd}
    $file add separator
    $file add command -label "Project Settings..." \
	    -command {maingui prShowThisProjWindow} -underline 0 \
	    -acc $menuKeys(Proj_Settings)
    $file add cascade -label "Recent Projects" \
	    -menu $file.runPrj -underline 0
    if {[tk windowingsystem] eq "aqua"} {
	interp alias "" ::tk::mac::Quit "" ExitDebugger
	bind all <Command-q> ::tk::mac::Quit
    } else {
	$file add separator
	$file add command -label "Exit" \
	    -command {ExitDebugger} -underline 1 \
	    -acc $menuKeys(Dbg_Exit)
    }

    # New/Edit Project Cascade
    set recent [menu $file.runPrj -tearoff 0 \
	    -postcommand "menu::recentProjPostCmd"]

    # Edit menu.
    set edit [menu $menubar.edit -tearoff 0 \
	    -postcommand "menu::editPostCmd"]
    $menubar add cascade -label "Edit" -menu $edit -underline 0

    $edit add command -label "Cut"  -underline 2 \
	    -command {maingui cutcopy} -state disabled \
	    -acc $menuKeys(Cut)
    $edit add command -label "Copy"  -underline 0 \
	    -command {maingui cutcopy} -state disabled \
	    -acc $menuKeys(Copy)
    $edit add command -label "Paste"  -underline 0 \
	    -state disabled -acc $menuKeys(Paste)
    $edit add command -label "Delete"  -underline 0 \
	    -state disabled -acc $menuKeys(Delete)
    $edit add separator
    $edit add command -label "Find..." -acc $menuKeys(Dbg_Find) \
	    -command {maingui findShowWindow} -underline 0
    $edit add command -label "Find Next" -acc $menuKeys(Dbg_FindNext) \
	    -command {maingui findNext} -underline 5
    $edit add command -label "Goto Line..." -acc $menuKeys(Dbg_Goto) \
	    -command {maingui gotoShowWindow} -underline 0
    if {[tk windowingsystem] eq "aqua"} {
	interp alias "" ::tk::mac::ShowPreferences "" prefWin::showWindow
	bind all <Command-comma> ::tk::mac::ShowPreferences
    } else {
	$edit add separator
	$edit add command -label "Preferences..." -underline 0 \
	    -command prefWin::showWindow
    }
    # View menu.
    set view [menu $menubar.view -tearoff 0 \
	    -postcommand "menu::viewPostCmd"]
    $menubar add cascade -label "View" -menu $view -underline 0

    $view add command -label "Breakpoints..." \
	    -command {maingui bpShowWindow} \
	    -acc $menuKeys(Dbg_Break) -underline 0
    $view add command -label "Eval Console..."  \
	    -command {maingui evalShowWindow} \
	    -acc $menuKeys(Dbg_Eval) -underline 0
    $view add command -label "Procedures..." -command {maingui procShowWindow} \
	    -acc $menuKeys(Dbg_Proc) -underline 0
    $view add command -label "Watch Variables..." \
	    -command {maingui watchShowWindow} \
	    -acc $menuKeys(Dbg_Watch) -underline 0

    # Checker integration ...
    $view add command -label "Syntax errors..." \
	    -command {maingui cwShowWindow} \
	    -acc $menuKeys(Dbg_Syntax) -underline 0

    $view add command -label "Connection status..." \
	    -command {maingui showConnectStatus} -underline 0
    $view add command -label "Data Display..." \
	    -command {maingui varShowInspector} -state disabled \
	    -acc $menuKeys(Dbg_DataDisp) -underline 0
    $view add separator
    $view add checkbutton -label "Toolbar"  -underline 0 \
	    -variable [pref::prefVar showToolbar] \
	    -command {menu::showOrHideDbgWindow \
	        [pref::prefGet showToolbar] \
		[list grid [maingui toolbarFrm] -row 0 -sticky we]}
    $view add checkbutton -label "Result"  -underline 0 \
	    -variable [pref::prefVar showResult] \
	    -command {menu::showOrHideDbgWindow \
	    [pref::prefGet showResult] \
	    [list grid [maingui resultFrm] -row 2 -sticky we]}
    $view add checkbutton -label "Status"  -underline 0 \
	    -variable [pref::prefVar showStatusBar] \
	    -command {menu::showOrHideDbgWindow \
	    [pref::prefGet showStatusBar] \
	    [list grid [maingui statusFrm] -row 3 -sticky we]}
    $view add checkbutton -label "Line Numbers"  -underline 0 \
	    -variable [pref::prefVar showCodeLines] \
	    -command {menu::showOrHideDbgWindow \
	    [pref::prefGet showCodeLines] \
	    [list grid [maingui codeLineBar] -row 0 -column 1 -sticky ns]}

    # Debug menu.
    set dbg [menu $menubar.dbg -tearoff 0 \
	    -postcommand "menu::dbgPostCmd"]
    $menubar add cascade -label "Debug" -menu $dbg -underline 0
    $dbg add command -label "Run" -command {maingui dbgrun} \
	    -acc $menuKeys(Dbg_Run) -underline 0
    $dbg add command -label "Pause" -command {maingui interrupt} \
	    -acc $menuKeys(Dbg_Pause) -underline 0
    $dbg add command -label "Stop" -command {maingui kill} \
	    -acc $menuKeys(Dbg_Stop) -underline 0
    $dbg add command -label "Restart" \
	    -command {maingui prRestartProj} -underline 1 \
	    -acc $menuKeys(Dbg_Restart)
    $dbg add separator

    $dbg add command -label "Close Debugger" \
	    -command {maingui closeDebugger} -underline 1 \
	    -acc $menuKeys(Dbg_CloseDebugger)

    $dbg add separator
    $dbg add command -label "Step In" -command {maingui dbgstep} \
	    -acc $menuKeys(Dbg_In) -underline 5
    $dbg add command -label "Step Over" -command {maingui dbgstepover} \
	    -acc $menuKeys(Dbg_Over) -underline 5
    $dbg add command -label "Step Out" -command {maingui dbgstepout} \
	    -acc $menuKeys(Dbg_Out) -underline 7
    $dbg add command -label "Run To Cursor" -command {maingui runTo} \
	    -acc $menuKeys(Dbg_To) -underline 7
    $dbg add command -label "Step To Result" -underline 11\
	    -command {maingui dbgstepcmdresult} \
	    -acc $menuKeys(Dbg_CmdResult)
    $dbg add separator
    $dbg add command -label "Add Var To Watch" \
	    -command {maingui varAddToWatch} -state disabled \
	    -acc $menuKeys(Dbg_AddWatch) -underline 11
    $dbg add separator
    $dbg add cascade -label Breakpoints -menu $dbg.bps -underline 0

    # Breakpoint Cascade.
    set bps [menu $dbg.bps -tearoff 0 \
	    -postcommand "menu::bpsPostCmd"]
    $bps add command -label "Add Line Breakpoint" -underline 0 \
	    -acc "Return" -state disabled \
	    -command {maingui toggleLBP onoff}
    $bps add command -label "Disable Line Breakpoint" -underline 0 \
	    -acc "Ctrl-Return" -state disabled \
	    -command {maingui toggleLBP enabledisable}
    $bps add separator
    $bps add command -label "Add Variable Breakpoint" -underline 4 \
	    -acc "Return" -state disabled \
	    -command {maingui varToggleVBP onoff}
    $bps add command -label "Disable Variable Breakpoint" -underline 1 \
	    -acc "Ctrl-Return" -state disabled \
	    -command {maingui varToggleVBP enabledisable}

    $bps add separator
    $bps add command -label "Add all Spawnpoints" -underline 4 \
	    -acc "A" -state disabled \
	    -command {maingui allSPOn}
    $bps add command -label "Add Spawnpoint" -underline 0 \
	    -acc "S" -state disabled \
	    -command {maingui toggleSP onoff}
    $bps add command -label "Disable Spawnpoint" -underline 0 \
	    -acc "Ctrl-S" -state disabled \
	    -command {maingui toggleSP enabledisable}


    # Windows menu.
    set win [menu $menubar.window -tearoff 0 \
	    -postcommand "menu::winPostCmd"]
    $menubar add cascade -label "Window" -menu $win -underline 0

    # Help menu.
    package require help

    set help [menu $menubar.help -tearoff 0]
    $menubar add cascade -label "Help" -menu $help -underline 0

    # (*) For aqua special see top of procedure.
    if {[tk windowingsystem] ne "aqua"} {
	# Non-aqua, regular help setup

	$help add command -label "Help" \
	    -command help::open -compound left -image $image::image(help) \
	    -acc $menuKeys(Dbg_Help) -underline 0

	$help add separator
	$help add command -label "About $::projectInfo::productName" \
	    -command {splash::showAbout} -underline 0

    } else {
	# Aqua. Split help in two. Regular help in the menu, splash in
	# the system menu.

	$help add command -label "Help" \
	    -command help::open \
	    -acc $menuKeys(Dbg_Help) -underline 0
    }

    # Enable the debug menu.  This is controlled by the debugMenu
    # preference.  This code is for internal use only.
    # To cause the menu to appear menually add a prefence called 
    # debugMenu and set the value to "1".

    if {[pref::prefExists debugMenu] && [pref::prefGet debugMenu]} {
	set debug [menu $menubar.debug -tearoff 0]
	$menubar add cascade -label "SuperBurrito" -menu $debug -underline 0
	$debug add command -label "Console show"  -underline 8 \
		-command {console show; console eval {raise .}}
	$debug add command -label "Console hide"  -underline 8 \
		-command {console hide}
	$debug add command -label "Show instrumented"  -underline 0 \
		-command {maingui showInstrumented}
	$debug add checkbutton -label "Logging output" \
		-command {maingui toggleLogOutput}

	$debug add command -label "Remove All Prefs & Exit"  \
		-command {CleanExit}

	$debug add command -label "PDX status"  \
		-command {PDXInfo}

	set menu(idebug)  $debug
    }

    set menu(file)    $file
    set menu(recent)  $recent
    set menu(edit)    $edit
    set menu(view)    $view
    set menu(dbg)     $dbg
    set menu(bps)     $bps
    set menu(win)     $win
    set menu(help)    $help


    $mainDbgWin configure -menu $menubar
    return
}

# menu::filePostCmd --
#
#	Post command for the File menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::filePostCmd {} {
    variable menu
    variable active

    menu::changeState $active {newProj openProj projSettings} normal
    
    if {[llength [pref::prefGet projectList]] == 0} {
	menu::changeState $active recentProj disabled
    } else {
	menu::changeState $active recentProj normal
    }
    
    if {[maingui prIsProjectOpen]} {
	menu::changeState $active {closeProj saveProj saveAsProj openFile} normal
	
	# If  (1) the project has been previously saved
	# And (2) the project file exists 
	# And (3) the project preferences are all up to date
	# Set the "Save Project" menu entry to be disabled.

	if {![maingui prProjectNeverSaved] \
		&& [file exists [maingui prGetProjectPath]] \
		&& (![pref::groupIsDirty Project])} {
	    menu::changeState $active {saveProj} disabled
	}
    } else {
	menu::changeState $active {closeProj saveProj saveAsProj openFile} disabled
    }
    
    # Enable the refresh button if the current block is associated
    # with a file that is currently not instrumented, or if the
    # session is dead. Bug 71629.

    if {
	([maingui getCurrentFile] == {}) ||
	(([maingui getCurrentState] ne "dead") &&
	([maingui blkIsInstrumented [maingui getCurrentBlock]]))
    } {
	menu::changeState $active {refreshFile} disabled
    } else {
	menu::changeState $active {refreshFile} normal
    }

    set state [maingui getCurrentState]
    if {$state == "new"} {
	$menu(file) entryconfigure {*Project Settings*} \
		-label "Default Project Settings..."
    } else {
	$menu(file) entryconfigure {*Project Settings*} \
		-label "Project Settings..."
	menu::changeState $active openFile normal
    }

    menu::changeState $active editInKomodo disabled
    if {[maingui useKomodoOK]} {
	menu::changeState $active editInKomodo normal
    }
    return
}

# menu::recentProjPostCmd --
#
#	Post command for the "Recent Projects" cascade.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::recentProjPostCmd {} {
    set m $menu::menu(recent)
    $m delete 0 end
    
    set i   1
    set end [pref::prefGet comboListSize]

    foreach path [pref::prefGet projectList] {
	if {$i >= $end} {
	    break
	}
	$m add command -label "$i $path" \
		-underline 0 \
		-command [list maingui prOpenProjCmd $path]
	incr i
    }
    return
}

# menu::editPostCmd --
#
#	Post command for the Edit menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::editPostCmd {} {
    variable active
    menu::changeState $active {cut copy findNext} disabled

    if {[maingui focusArea]} {
	menu::changeState $active {cut copy} normal
    }
    if {[maingui findNextOK]} {
	menu::changeState $active {findNext} normal
    }
    return
}

# menu::viewPostCmd --
#
#	Post command for the View menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::viewPostCmd {} {
    variable active
    menu::changeState $active {inspector} disabled

    if {[maingui focusHighlight]} {
	menu::changeState $active {inspector} normal
    }
    return
}

# menu::dbgPostCmd --
#
#	Post command for the Debug menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::dbgPostCmd {} {
    variable active
    variable focusWin [focus]

    # Copy the current state into a more easily tested array form.
    array set state {
	new 0
	dead 0
	stopped 0
	running 0
    }
    set state([maingui getCurrentState]) 1
    set remote [maingui prIsRemoteProj]
    
    # The following expressions determine the conditions under which
    # the given menu item will be enabled.

    # Bugzilla 30651: restart: Added "![maingui stayingdead]" <=> 'Is primary session'.

    set conditions {
	close       {$state(dead) && [maingui stayingdead]}
	breakpoints {![maingui focusStackWin $focusWin] && [maingui prIsProjectOpen]}
	addToWatch  {[maingui focusVarWin $focusWin]}
	restart     {!$remote && ![maingui stayingdead] && ($state(stopped) || $state(running))}
	run         {(!$remote && $state(dead) && ![maingui stayingdead]) || $state(stopped)}
	stepIn      {(!$remote && $state(dead) && ![maingui stayingdead]) || $state(stopped)}
	stepOut     {$state(stopped)}
	stepOver    {$state(stopped)}
	stepTo      {$state(stopped)}
	stepResult  {$state(stopped)}
	pause       {$state(running)}
	stop        {$state(running) || $state(stopped)}
    }

    foreach {item cond} $conditions {
	if $cond {
	    menu::changeState $active $item normal
	} else {
	    menu::changeState $active $item disabled
	}
    }

    return
}

# menu::bpsPostCmd --
#
#	Post command for the Breakpoints cascade menu.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::bpsPostCmd {} {
    variable menu
    variable active
    variable focusWin

    menu::changeState $active {allSPOn}  normal

    if {[maingui focusVarWin $focusWin]} {
	menu::changeState $active {addVBP disableVBP} normal
	menu::changeState $active {addLBP disableLBP} disabled
	menu::changeState $active {addSP  disableSP}  disabled

	set breakState [maingui varBreakState]

	switch $breakState {
	    noActive {
		$menu(bps) entryconfigure 3 -label "Add Var Breakpoint"
		$menu(bps) entryconfigure 4 -label "Disable Var Breakpoint"
		menu::changeState $active {addVBP disableVBP} disabled
	    }
	    noBreak {
		$menu(bps) entryconfigure 3 -label "Add Var Breakpoint"
		$menu(bps) entryconfigure 4 -label "Disable Var Breakpoint"
		menu::changeState $active {disableVBP} disabled
	    }
	    mixedBreak -
	    enabledBreak {
		$menu(bps) entryconfigure 3 -label "Remove Var Breakpoint"
		$menu(bps) entryconfigure 4 -label "Disable Var Breakpoint"
	    }
	    disabledBreak {
		$menu(bps) entryconfigure 3 -label "Add Var Breakpoint"
		$menu(bps) entryconfigure 4 -label "Enable Var Breakpoint"
	    }
	}
    } elseif {[maingui focusCodeWin $focusWin]} {
	menu::changeState $active {addVBP disableVBP} disabled

	set breakState [maingui codeBreakState]

	switch $breakState {
	    noBreak {
		menu::changeState $active {addLBP disableLBP} normal
		menu::changeState $active {addSP  disableSP}  normal

		$menu(bps) entryconfigure 0 -label "Add Line Breakpoint"
		$menu(bps) entryconfigure 1 -label "Disable Line Breakpoint"
		menu::changeState $active {disableLBP} disabled

		$menu(bps) entryconfigure 7 -label "Add Spawnpoint"
		$menu(bps) entryconfigure 8 -label "Disable Spawnpoint"
		menu::changeState $active {disableSP} disabled
	    }
	    mixedBreak -
	    enabledBreak {
		menu::changeState $active {addLBP disableLBP} normal
		$menu(bps) entryconfigure 0 -label "Remove Line Breakpoint"
		$menu(bps) entryconfigure 1 -label "Disable Line Breakpoint"
	    }
	    disabledBreak {
		menu::changeState $active {addLBP disableLBP} normal
		$menu(bps) entryconfigure 0 -label "Add Line Breakpoint"
		$menu(bps) entryconfigure 1 -label "Enable Line Breakpoint"
	    }
	    enabledSpawn {
		menu::changeState $active {addSP  disableSP}  normal
		$menu(bps) entryconfigure 7 -label "Remove Spawnpoint"
		$menu(bps) entryconfigure 8 -label "Disable Spawnpoint"
	    }
	    disabledSpawn {
		menu::changeState $active {addSP  disableSP}  normal
		$menu(bps) entryconfigure 7 -label "Add Spawnpoint"
		$menu(bps) entryconfigure 8 -label "Enable Spawnpoint"
	    }
	}
    } else {
	menu::changeState $active {addVBP disableVBP addLBP disableLBP} disabled
    }
}

# menu::winPostCmd --
#
#	This command is a "post command" for the Windows menu item.
#	We use this command to see if we need to update our list of 
#	files in the menu list.  We also do all the work of adding them
#	if the files need to be updated.
#
# Arguments:
#	m		This is the menu the post command is called for.
#
# Results:
#	None.

proc menu::winPostCmd {} {
    variable menu

    # Update all the menus.  We give a different value
    # for the check based on if it is instrumented.  The command
    # will view the file when selected.

    $menu(win) delete 0 end
    set showList {}

    set font [$menu(win) cget -font]
    set family [font actual $font -family]
    set size   [font actual $font -size]
    set italic [list $family $size italic]

    set line 0
    foreach {file block} [maingui getUniqueFiles] {
	set code  [list maingui showCode [loc::makeLocation $block {}]]
	set inst  [maingui blkIsInstrumented $block]

	if {$line < $menu::maxMenuSize} {
	    if {[tk windowingsystem] eq "aqua"} {
		if {$inst} {
		    $menu(win) add command -label "* $file" -command $code
		} else {
		    $menu(win) add command -label "  $file" -command $code
		}
	    } else {
		set img $image::image(instrumented[expr {$inst ? "" : "_disable"}])
		$menu(win) add command -compound left -label $file \
		    -image $img -command $code
	    }
	}
	incr line
	lappend showList $block $code $inst
    }
    $menu(win) add separator
    $menu(win) add command -label "Windows..." -underline 0 \
	    -command [list menu::showFileWindow $showList]
}



# menu::showOrHideDbgWindow --
#
#	Display or remove the current frame from the window. It is
#	assumed that the window has already been created and just 
#	needs additional management by the packer.
#
# Arguments:
#	showFrm	  Boolean that indicates if the window should
#		  be shown or hidden.
#	frm 	  The name of the frame to show or hide.
#	args	  Extra args passed to pack.
#
# Results:
#	None.

proc menu::showOrHideDbgWindow {showFrm geomCmd} {
    if {$showFrm} {
	eval $geomCmd
    } else {
	set manager [lindex $geomCmd 0]
	set window  [lindex $geomCmd 1]
	$manager forget $window
    }
}

# menu::changeState --
#
#	Change the state of menu items.  There is a limited number
#	of menu items whose state will change over the course of the 
#	debug session.  Given the name of the menu item, this routine
#	locates the handle to the menu item and updates the state.
#
# Arguments:
#	menuList	List of menu item names that should be updated.
#	state		The new state of all items in menuList.
#
# Results:
#	None.

proc menu::changeState {o menuList state} {
    variable menu
    variable active
    variable statecache

    foreach entry $menuList {
	set statecache($o,$entry) $state
	if {$active ne $o} continue

	switch -exact $entry {
	    openFile {
		$menu(file) entryconfigure {Open File*} -state $state
	    }
	    refreshFile {
		$menu(file) entryconfigure {Refresh File*} -state $state
	    }
	    newProj {
		$menu(file) entryconfigure {New Project*} -state $state
	    }
	    openProj {
		$menu(file) entryconfigure {Open Project*} -state $state
	    }
	    closeProj {
		$menu(file) entryconfigure {Close Project*} -state $state
	    }
	    saveProj {
		$menu(file) entryconfigure {Save Project} -state $state
	    }
	    saveAsProj {
		$menu(file) entryconfigure {Save Project As*} -state $state
	    }
	    recentProj {
		$menu(file) entryconfigure {Recent Projects*} -state $state
	    }
	    projSettings {
		$menu(file) entryconfigure {*Project Settings*} -state $state
	    }
	    editProj {
		$menu(file) entryconfigure {Edit Project*} -state $state
	    }
	    runProj {
		$menu(file) entryconfigure {Run Project*} -state $state
	    }
	    editInKomodo {
		$menu(file) entryconfigure {Open In Komodo...} -state $state
	    }
	    cut {
		$menu(edit) entryconfigure Cut -state $state
	    }
	    copy {
		$menu(edit) entryconfigure Copy -state $state
	    }
	    paste {
		$menu(edit) entryconfigure Paste -state $state
	    }
	    delete {
		$menu(edit) entryconfigure Delete -state $state
	    }
	    findNext {
		$menu(edit) entryconfigure {Find Next} -state $state
	    }
	    restart {
		$menu(dbg) entryconfigure Restart -state $state
	    }
	    run {
		$menu(dbg) entryconfigure Run -state $state
	    }
	    pause {
		$menu(dbg) entryconfigure Pause -state $state
	    }
	    stop {
		$menu(dbg) entryconfigure Stop -state $state
	    }
	    close {
		$menu(dbg) entryconfigure {Close Debugger} -state $state
	    }
	    stepIn {
		$menu(dbg) entryconfigure {Step In} -state $state
	    }
	    stepOut {
		$menu(dbg) entryconfigure {Step Out} -state $state
	    }
	    stepOver {
		$menu(dbg) entryconfigure {Step Over} -state $state
	    }
	    stepTo {
		$menu(dbg) entryconfigure {Run To Cursor} -state $state
	    }
	    stepResult {
		$menu(dbg) entryconfigure {Step To Result} -state $state
	    }
	    addToWatch {
		$menu(dbg) entryconfigure {Add Var To Watch*} -state $state
	    }
	    breakpoints {
		$menu(dbg) entryconfigure {Breakpoints*} -state $state
	    }
	    addLBP {
		$menu(bps) entryconfigure 0 -state $state
	    }
	    disableLBP {
		$menu(bps) entryconfigure 1 -state $state
	    }
	    addVBP {
		$menu(bps) entryconfigure 3 -state $state
	    }
	    disableVBP {
		$menu(bps) entryconfigure 4 -state $state
	    }
	    allSPOn {
		$menu(bps) entryconfigure 6 -state $state
	    }
	    addSP {
		$menu(bps) entryconfigure 7 -state $state
	    }
	    disableSP {
		$menu(bps) entryconfigure 8 -state $state
	    }
	    inspector {
		$menu(view) entryconfigure {Data Display*} -state $state
	    }
	    default {
		error "Unknown menu item \"$entry\": in menu::changeState"
	    }
	}
    }
}

# menu::showFileWindow --
#
#	Display all of the open files in a list inside
# 	a new toplevel window.
#
# Arguments:
#	showList 	A list of open files.
#
# Results:
#	The toplevel window name of the File Window.

proc menu::showFileWindow {showList} {
    set mainw [maingui mainDbgWin]
    set filew [maingui fileDbgWin]

    grab $mainw

    if {[winfo exists $filew]} {
	wm deiconify $filew
	raise $filew
    } else {
	menu::createFileWindow $filew
    }
    menu::updateFileWindow $showList

    grab release $mainw
    return $filew
}

# menu::createFileWindow --
#
#	Create the File Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::createFileWindow {filew} {
    variable selFileWin
    variable showCodeBut

    set pad 6

    set                        top [toplevel $filew]
    ::guiUtil::positionWindow $top 400x250
    wm transient              $top [maingui mainDbgWin]
    wm title                  $top "File Windows"
    wm resizable              $top 1 1

    set mainFrm    [ttk::frame $top.mainFrm]
    set sw         [widget::scrolledwindow $mainFrm.sw \
		       -relief sunken -borderwidth 1]
    set selFileWin [treectrl $sw.tree -selectmode browse -usetheme 1 \
		       -highlightthickness 0 -borderwidth 0 \
		       -showroot 0 -showlines 0]
    set instLbl    [ttk::label $mainFrm.instLbl -compound left \
			-image $image::image(instrumented) \
			-text "instrumented file"]
    set uninstLbl  [ttk::label $mainFrm.uninstLbl -compound left \
			-image $image::image(instrumented_disable) \
			-text "uninstrumented file"]
    $sw setwidget $selFileWin

    set tree $selFileWin

    set selbg $::style::as::highlightbg
    set selfg $::style::as::highlightfg

    # Create elements
    $tree element create elemImg image
    $tree element create elemText text -lines 1 \
	-fill [list $selfg {selected focus}]
    $tree element create selRect rect \
	-fill [list $selbg {selected focus} gray {selected !focus}]

    # image + text style (Icon + Package)
    set S [$tree style create styName -orient horizontal]
    $tree style elements $S {selRect elemImg elemText}
    $tree style layout $S selRect -union {elemImg elemText} -iexpand news
    $tree style layout $S elemImg -expand ns -padx 2
    $tree style layout $S elemText -squeeze x -expand ns -padx 2

    $tree column create -text "Available Files" -tag file \
	-borderwidth 1 -expand 1 -minwidth 80
    $tree configure -defaultstyle [list styName]

    set butFrm [ttk::frame $mainFrm.butFrm]
    set showCodeBut [ttk::button $butFrm.showCodeBut -text "Show Code" \
			 -default active \
			 -command [list menu::showFile $selFileWin]]
    set canBut [ttk::button $butFrm.canBut -text "Cancel" -default normal \
		    -command menu::removeFileWindow]

    pack $showCodeBut $canBut -pady [list 0 $pad] -fill x

    grid $sw - $butFrm -sticky news -padx $pad
    grid $instLbl $uninstLbl -sticky w -padx $pad

    grid columnconfigure $mainFrm 1 -weight 1
    grid rowconfigure    $mainFrm 0 -weight 1

    pack $mainFrm -fill both -expand true -padx $pad -pady $pad

    bind::addBindTags $selFileWin  breakDbgWin
    bind::addBindTags $showCodeBut breakDbgWin
    bind::addBindTags $canBut      breakDbgWin
    bind::commonBindings breakDbgWin [list $selFileWin $showCodeBut $canBut]

    bind $selFileWin <Double-1> \
	"if {\[lindex \[%W identify %x %y\] 0\] eq {item}} \
		{ menu::showFile $selFileWin } ; break"
    bind $selFileWin <<Dbg_ShowCode>> "menu::showFile $selFileWin ; break"
    bind $top <Escape> "$canBut invoke; break"
    bind $top <Return> "$showCodeBut invoke; break"
}

# menu::updateFileWindow --
#
#	Update the contents of the File Window.
#
# Arguments:
#	showList	A list of files to show.  The list is ordered
#			to contain:
#		          block		The block of the file.
#			  code		The code to run to show the file.
#			  instrumented	Boolean, true if the file is 
#					instrumented.
#
# Results:
#	None

proc menu::updateFileWindow {showList} {
    variable showCmd
    variable selFileWin
    variable showCodeBut

    $selFileWin item delete root
    unset -nocomplain showCmd

    foreach {block code inst} $showList {
	set file [maingui blkGetFile $block]
	if {$::tcl_platform(platform) eq "windows"} {
	    set file [string map [list "\\" "/"] $file]
	}
	set id [$selFileWin item create -button 0 -parent root]
	$selFileWin item text $id file $file
	$selFileWin item image $id file \
	    $image::image(instrumented[expr {$inst ? "" : "_disable"}])
	set showCmd($id) $code
    }

    # if there are no files, disable the Show Code button
    if {[llength $showList]} {
	$selFileWin item sort root -column file -dictionary
	$selFileWin selection add "first visible"
	$showCodeBut configure -state "normal"
    } else {
	$showCodeBut configure -state "disabled"
    }
    focus $selFileWin
}

# menu::showFile --
#
#	Show the selected file.
#
# Arguments:
#	text	The text widget containign a list of file names.
#
# Results:
#	None.

proc menu::showFile {w} {
    variable showCmd

    set id [$w selection get]
    if {[info exists showCmd($id)]} {
	eval $showCmd($id)
    }
    menu::removeFileWindow
}

# menu::removeFileWindow --
#
#	Destroy the "Windows" Window.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc menu::removeFileWindow {} {
    destroy [maingui fileDbgWin]
}

# menu::accKeyPress --
#
#	All key bindings are routed through this routine.  If a 
#	"post command" exists for the event, then it is run to 
#	update the state and determine if the event should be
#	trapped or executed.
#
# Arguments:
#	virtual		The virtual event bound to a key binding.
#
# Results:
#	None.

proc menu::accKeyPress {virtual} {
    variable menu
    variable postCmd
    variable invokeCmd
    
    if {$postCmd($virtual) != {}} {
	eval $postCmd($virtual)
    }
    eval $invokeCmd($virtual)
    return
}



proc menu::insert {sym args} {
    variable               menu
    eval [linsert $args 0 $menu($sym) insert]
}


# ### ### ### ######### ######### #########

proc menu::setActive {o} {
    variable active
    variable statecache

    set      active $o

    foreach key [array names statecache $o,*] {
	foreach {_ entry} [split $key ,] break
	set newstate $statecache($key)

	changeState $o $entry $newstate
    }

    return
}
