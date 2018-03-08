# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# system.tcl --
#
#	This file defines all system specific data.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: system.tcl,v 1.22 2000/10/31 23:31:01 welch Exp $

package require BWidget ; # BWidgets | Use its mega widgets.
ComboBox::use           ; # BWidgets / Widget used here.

if {$::tcl_platform(platform) == "windows"} {
    ## package require dbgext
    catch {package require Winico}
    package require registry
}

namespace eval system {
    # Widget attributes --
    # arrow	Specifies the arrow to use.  Unix is "left_ptr"
    #  		while Windows is "arrow".
    # bar	Configuration variables for the code bars.  These are
    #  		the color, width and height of the bar.
    # color	Colors for the tabs, labels and various widgets.
    # exeFiles	List of executable file types to use for Tk file
    #  		dialogs.
    # exeString	Specifies the string to use for executable files.
    #  		Empty string for unix, ".exe" for Windows.
    # dbgSuffix Suffix to use when loading an executable that is 
    #		built with symbols.
    # fontList	Specifies list of fonts to display in the font
    #  		combobox in the Preferences window.

    variable arrow
    variable bar
    variable color
    variable exeFiles
    variable exeString
    variable dbgSuffix

    # The browser array is used by the system specific browser windows 
    # used in the BrowserWindow functions.

    variable browser
    set browser(start)     "::start" 
    set browser(iexplorer) "iexplorer -nohome"
    set browser(netscape)  "netscape -no-about-splash -dont-save-geometry-prefs"
}

# system::init --
#
#	Initialize all of the system specific data.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc system::init {} {

    # Change the "class icon" for our application.  This gives us the
    # debugger icon for the minimize state.  (C code)
    # Note the window must be mapped before this call can be made.

    if {$::tcl_platform(platform) == "windows"} {
	update
#	chgClass .
    }

    # Reset the environment so we don't perturb things too much.
    # The global env variable is modified.

    system::resetEnv

    # Restore any global preferences.  The group name returned by the
    # call is the default group to set user preferences into.

    set group [system::initGroups]

    # Set widget attributes that depend on the platform.

    system::setWidgetAttributes

    # Source an rc file if one is defined before we continue with the
    # intialization process.
    
#    if {[pref::prefExists rcfile]} {
#	if {[catch {source [pref::prefGet rcfile]} {} msg]} {
#	    puts stderr $msg
#	}
#    }
    return
}    

# system::resetEnv --
#
# 	Reset the environment so we don't perturb things too much.
#
# Arguments:
#	None.
#
# Results:
#	None.  The global env varible is altered.

proc system::resetEnv {} {
    global env
    
    if {[info exists env(TCLPRO_SHLIB_PATH)]} {
	set env(SHLIB_PATH) $env(TCLPRO_SHLIB_PATH)
	unset env(TCLPRO_SHLIB_PATH)
    } elseif {[info exists env(SHLIB_PATH)]} {
	unset env(SHLIB_PATH)
    }
    if {[info exists env(TCLPRO_LD_LIBRARY_PATH)]} {
	set env(LD_LIBRARY_PATH) $env(TCLPRO_LD_LIBRARY_PATH)
	unset env(TCLPRO_LD_LIBRARY_PATH)
    } elseif {[info exists env(LD_LIBRARY_PATH)]} {
	unset env(LD_LIBRARY_PATH)
    }   
    return
}

# system::initGroups --
#
#	Initialize the group search order, set factory preferences and 
#	load the users preferences for the debugger.
#
# Arguments:
#	None.
#
# Results:
#	Return the group that contains the default user setting.  This
#	group should be used to insert new preferences after the 
#	Factory has been initialized.

proc system::initGroups {} {
    # Set the group search order used when attempting to resolve
    # the location of a preference within multiple groups.
    
    pref::setGroupOrder {
	TempProj TempPref Project ProjectDefault GlobalDefault 
	ProjectFactory GlobalFactory
    }

    pref::groupInit GlobalFactory [list \
	    browserCmd		[system::getBrowserCmd]	{} \
	    browserDefault	[system::getDefBrowser] {} \
	    comboListSize	10			{} \
	    exitPrompt		ask			{} \
	    fileOpenDir		[pwd]		{}			\
	    fontSize		10		gui::updateDbgText       \
	    fontType		courier 	gui::updateDbgText       \
	    highlight		lightblue 	gui::updateDbgHighlights \
	    highlight_error	red		gui::updateDbgHighlights \
	    highlight_cmdresult	#ffff80		gui::updateDbgHighlights \
	    highlight_chk_error	  pink		code::updateChkHighlights \
            highlight_chk_warning yellow	code::updateChkHighlights \
	    historySize		64		tkCon::update            \
	    paneGeom		{}		{} \
	    projectList		{}		{} \
	    projectPrev		{}		{} \
	    projectReload	1		{} \
	    screenSize		300		tkCon::update        \
	    tabSize		8		code::updateTabStops \
	    showCodeLines	1			{} \
	    showResult		1			{} \
	    showStatusBar	1			{} \
	    showToolbar		1			{} \
	    warnOnKill		1			{} \
	    warnOnClose		1			{} \
	    warnInvalidBp	1			{} \
	    enableCoverage	0			{} \
	    winGeoms		{}			{} \
    ]

    pref::groupInit ProjectFactory [list \
	    appScript		{}		projWin::updateScriptList \
	    appArg		{}		projWin::updateArgList    \
	    appDir		{}		projWin::updateDirList    \
	    appInterp	[lindex [system::getInterps] 0]	projWin::updateInterpList \
	    appScriptList	{}			{} \
	    appArgList		{}			{} \
	    appDirList		{}			{} \
	    appInterpList	[system::getInterps]	{} \
	    appType		$debugger::parameters(appType) {} \
	    breakList		{}			{} \
	    errorAction		1		dbg::initInstrument	\
	    dontInstrument	{}		dbg::initInstrument	\
	    doInstrument	{*}		dbg::initInstrument	\
	    instrumentDynamic	1		dbg::initInstrument	\
	    instrumentIncrTcl	1		projWin::updateIncrTcl  \
	    instrumentExpect	1		projWin::updateExpect   \
	    instrumentTclx	1		projWin::updateTclX     \
	    autoLoad		0		dbg::initInstrument	\
	    portRemote		2576		projWin::updatePort     \
	    projVersion		2.0		{}			\
	    prevViewFile 	{} 		{}			\
	    watchList		{}		{}			\
	    varTransformList    {}              {}                      \
    ]
    # Bugzilla 19719 ... New key "varTransformList" to hold global
    # information associating var names with transformations.

    # Create the GlobalDefault group.  Specify the save and restore commands
    # based on which platform we're running on.

    if {$::tcl_platform(platform) == "windows"} {
	pref::groupNew GlobalDefault system::winSaveCmd system::winRestoreCmd
    } else {
	pref::groupNew GlobalDefault system::unixSaveCmd system::unixRestoreCmd
    }

    # Copy the factory preferences into the default preferences.  This is 
    # to verify that every preference in the GlobalFactory preferences 
    # also appear in the GlobalDefault preferences.  Then restore the project,
    # clobbering the existing value with the user preference.

    pref::groupCopy    GlobalFactory GlobalDefault
    pref::groupRestore GlobalDefault

    # Create the ProjectDefault group.  Specify the save and restore commands
    # based on which platform we're running on.

    if {$::tcl_platform(platform) == "windows"} {
	pref::groupNew ProjectDefault system::winSaveCmd system::winRestoreCmd
    } else {
	pref::groupNew ProjectDefault system::unixSaveCmd \
		system::unixRestoreCmd
    }

    # Copy the factory preferences into the default preferences.  This is 
    # to verify that every preference in the ProjectFactory preferences 
    # also appear in the ProjectDefault preferences.  Then restore the project,
    # clobbering the existing value with the user preference.

    pref::groupCopy    ProjectFactory ProjectDefault
    pref::groupRestore ProjectDefault

    # TODO: Versioning?

    return GlobalDefault
}    

# system::saveDefaultPrefs --
#
#	Save the implicit prefs to the registry, or UNIX resource.  Implicit
#	prefs are prefs that are set by the debugger and do not belong in a
#	project file (i.e., window sizes.)
#
# Arguments:
#	close	Boolean indicating if the project should be closed first.
#
# Results:
#	Return 1 if there was an error saving the project file.

proc system::saveDefaultPrefs {close} {
    # Determine if the user wants to save the project.  If the user 
    # cancels the interaction, then return immediately.

    if {$close} {
	set how [proj::closeProjDialog]
	if {$how == "CANCEL"} {
	    return 1
	}
    }

    # Set the projectPrev variable to indicate if a project file should
    # be reloaded when the next session is started.  Set the pref if the
    # user indicates the project should be saved or if the user decided
    # not to save the changes, but the file currently exists.  Otherwise
    # a project is not currently loaded, or the user decided not to save
    # a newly created project, therefore do not try to reload a project
    # on the next session.

    set projPath [proj::getProjectPath]
    if {$close && ($how == "SAVE")} {
	pref::prefSet GlobalDefault projectPrev $projPath
	if {[proj::saveProjCmd $projPath]} {
	    return 1
	}
    } elseif {$close && ($how == "CLOSE")} {
	if {[proj::projectNeverSaved]} {
	    pref::prefSet GlobalDefault projectPrev {}
	} else {
	    pref::prefSet GlobalDefault projectPrev $projPath
	}
    } else {
	pref::prefSet GlobalDefault projectPrev {}
    }
    
    # Save implicit preference before closing the project because the 
    # act of closing the project changes the implicit prefs to an 
    # undesirable state before closing.

    pref::groupSave GlobalDefault
    pref::groupSave ProjectDefault

    if {$close} {
	proj::closeProj CLOSE
    }
    return 0
}

# system::winRestoreCmd --
#
#	Restore the global preferences for a Windows session.
#
# Arguments:
#	group	The name of the group to restore preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc system::winRestoreCmd {group} {
    set result [catch {
	set key "$projectInfo::prefsRoot\\$projectInfo::prefsLocation\\$debugger::parameters(productName)\\$group"

	set noKey [catch {
	    set prefList {}
	    foreach {valueName} [registry values $key] {
		lappend prefList $valueName [registry get $key $valueName]
	    }
	}]
	    
	if {$noKey} {
	    # See if an older version of preferences are available on disk.

	    set curPrefsLocation \
		    [projectInfo::getPreviousPrefslocation]

	    while {[string length $curPrefsLocation] != 0 && $noKey} {
		set key "$projectInfo::prefsRoot\\$projectInfo::prefsLocation\\$debugger::parameters(productName)\\$group"
		set noKey [catch {
		    set prefList {}
		    foreach {valueName} [registry values $key] {
			lappend prefList $valueName [registry get $key $valueName]
		    }
		}]

		set curPrefsLocation \
			[projectInfo::getPreviousPrefslocation $curPrefsLocation]
	    }
	}

	if {!$noKey} {
	    pref::GroupSetPrefs $group $prefList
	}
    } msg]

    pref::SetRestoreMsg $msg
    return $result
}

# system::winSaveCmd --
#
#	Save the global preferences for a Windows session.
#
# Arguments:
#	group	The name of the group to Save preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc system::winSaveCmd {group} {
    system::updatePreferences


    set key "$projectInfo::prefsRoot\\$projectInfo::prefsLocation\\$debugger::parameters(productName)\\$group"

    set result [catch {
	registry delete $key
	foreach pref [pref::GroupGetPrefs $group] {
	    registry set $key $pref [pref::prefGet $pref $group]
	}
    } msg]

    pref::SetSaveMsg $msg
    return $result
}

# system::unixRestoreCmd --
#
#	Restore the global preferences for a UNIX session.
#
# Arguments:
#	group	The name of the group to restore preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc system::unixRestoreCmd {group} {
    set result [catch {
	set file [file join $projectInfo::prefsRoot \
		$projectInfo::prefsLocation Debugger $group]
	set noFile [catch {set id [open $file r]}]
	if {$noFile} {
	    # See if an older version of preferences are available on disk.

	    set curPrefsLocation \
		    [projectInfo::getPreviousPrefslocation]

	    while {[string length $curPrefsLocation] != 0 && $noFile} {
		set file [file join $projectInfo::prefsRoot \
			$curPrefsLocation Debugger $group]
		set noFile [catch {set id [open $file r]}]

		set curPrefsLocation \
			[projectInfo::getPreviousPrefslocation $curPrefsLocation]
	    }
	}

	if {!$noFile} {
	    set prefs [read $id]
	    pref::GroupSetPrefs $group $prefs
	    close $id
	}
    } msg]
	
    pref::SetRestoreMsg $msg
    return $result
}

# system::unixSaveCmd --
#
#	Save the global preferences for a UNIX session.
#
# Arguments:
#	group	The name of the group to Save preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc system::unixSaveCmd {group} {
    system::updatePreferences
    set result [catch {
	set file [file join $projectInfo::prefsRoot \
		$projectInfo::prefsLocation Debugger $group]
	file mkdir [file dirname $file]
	set id [open $file w]

        foreach pref [pref::GroupGetPrefs $group] {
	    puts $id "$pref [list [pref::prefGet $pref $group]]"
	}
	close $id
    } msg]

    pref::SetSaveMsg $msg
    return $result
}

# system::updatePreferences --
#
#	Update the implicit preferences.  There are many preferences
#	about the current running environment that are used between 
#	sessions (e.g., window geometry.)  Update all implicit 
#	preferences here, before a save, so the latest information 
#	is preserved.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc system::updatePreferences {} {
    guiUtil::preservePaneGeometry
    set windowList [list \
	    $gui::gui(breakDbgWin) $gui::gui(dataDbgWin)  \
	    $gui::gui(errorDbgWin) $gui::gui(evalDbgWin)  \
	    $gui::gui(fileDbgWin)  $gui::gui(findDbgWin)  \
	    $gui::gui(gotoDbgWin)  $gui::gui(loadDbgWin)  \
	    $gui::gui(mainDbgWin)  $gui::gui(procDbgWin)  \
	    $gui::gui(watchDbgWin) \
    ]
    foreach x $windowList {
	guiUtil::saveGeometry $x
    }
    return
}    

# system::getInterps --
#
#	Get a list of the interps that exist on this system.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc system::getInterps {} {
    set result {}
    if {$::tcl_platform(platform) == "windows"} {
	set ext ".exe"
    } else {
	set ext ""
    }

    # First find wish & tclsh exe files relative to the debugger executable.

    set exePath [file join [pwd] [info nameofexecutable]]
    set path [file dirname $exePath]
    foreach y [list $::projectInfo::executable(tclsh) \
	    $::projectInfo::executable(wish)] {
	set exe [file join $path $y]$ext
	if {[file exists $exe]} {
	    lappend result $exe
	}
    }
	
    # Look for other Tcl shells on user's path (not available on Windows)
    
    if {$::tcl_platform(platform) != "windows"} {
    
	foreach path [split $::env(PATH) :] {
	    foreach y [glob -nocomplain [file join $path wish*]] {
		lappend result $y
	    }
	    foreach y [glob -nocomplain [file join $path tclsh*]] {
		lappend result $y
	    }
	}
    }

    # Bugzilla 19618 ... collapse the list to contain only unique paths

    return [uniquePaths $result]
}

# system::uniquePaths --
#
# Given a list of path duplicates are stripped from the list.
#
# Arguments:
#       paths	List containing paths
#
# Result:
#       See description

proc system::uniquePaths {paths} {
    # Bugzilla 19618 ... collapse the list to contain only unique
    # names. IOW remove duplicates from the list.

    set res [list]
    array set hold {}
    if {$::tcl_platform(platform) != "windows"} {
	foreach interp $paths {
	    if {[info exists hold($interp)]} {continue}
	    lappend res $interp
	    set hold($interp) .
	}
    } else {
	# enforce case insensitivity for windows
	foreach interp $paths {
	    set interp [string tolower $interp]
	    if {[info exists hold($interp)]} {continue}
	    lappend res $interp
	    set hold($interp) .
	}
    }
    return $res
}

# system::getFontList --
#
#	Get the list of default fonts to be displayed in the option
#	box of the preference window.  This is done to reduce the 
#	amount of work done on UNIX.
#
# Arguments:
#	None.
#
# Results:
#	The list of fonts to use.

proc system::getFontList {} {
    # In the Prefs Window, we want to display as many fixed 
    # fonts as possible.  Searching through all of the font 
    # families in X is too slow and may crash the X Server.  
    # For UNIX, use only a small set of fonts.  For Windows, 
    # search all of the fonts.

    if {$::tcl_platform(platform) == "windows"} {
	return [font families]
    } else {
	return {fixed courier {lucida typewriter} serif terminal screen}
    }
}

# system::getBrowserCmd --
#
#	Return the browser command to use, based on the platform.
#
# Arguments:
#	None.
#
# Results:
#	The command to use that will launch a browser.

proc system::getBrowserCmd {} {
    if {$::tcl_platform(platform) == "windows"} {
	return {}
    } else {
	return $system::browser(netscape)
    }
}

# system::getDefBrowser --
#
#	Get the default setting for the default browser flag.
#
# Arguments:
#	None.
#
# Results:
#	Return a boolean, indicating if the default browser command
#	is to be used.

proc system::getDefBrowser {} {
    if {$::tcl_platform(platform) == "windows"} {
	return 1
    } else {
	return 0
    }
}

# system::getKeyBindings --
#
#	Define the virtual key bindings, then convert the Tcl
# 	format for the bindings to one that will be seen in
# 	the menus.
#
# Arguments:
#	None.
#
# Results:
#	Virtual key bindings are added to the system.  Return a list
#	in "array get" order that maps the virtual key bindings to 
#	the system specific key mapping.

proc system::getKeyBindings {} {
    set keyList {
	<<Dbg_Open>>	<Control-o>
	<<Proj_New>>	<Control-N>
	<<Proj_Open>>	<Control-O>
	<<Proj_Close>>	<Control-C>
	<<Proj_Save>>	<Control-S>
	<<Proj_Settings>>	<Control-n>
	<<Dbg_Launch>>	<Control-n>
	<<Dbg_Exit>>	<Control-w>
	<<Dbg_Exit>>	<Alt-Key-F4>
	<<Cut>>		<Control-x>
	<<Copy>>		<Control-c>
	<<Paste>>		<Control-v>
	<<Delete>>		<Delete>
	<<Dbg_Find>>	<Control-f>
	<<Dbg_FindNext>>	<Key-F3>
	<<Dbg_Goto>>	<Control-g>
	<<Dbg_Help>>	<Key-F1>
	<<Dbg_Run>>		<Key-F5>
	<<Dbg_In>>		<Key-F6>
	<<Dbg_Over>>	<Key-F7>
	<<Dbg_Out>>		<Key-F8>
	<<Dbg_To>>		<Shift-F5>
	<<Dbg_CmdResult>>	<Shift-F7>
	<<Dbg_Stop>>	<Key-F9>
	<<Dbg_Kill>>	<Control-F9>
	<<Dbg_Restart>>	<Control-F5>
	<<Dbg_Refresh>>	<Control-F6>
	<<Dbg_Break>>	<Alt-Key-1>
	<<Dbg_Eval>>	<Alt-Key-2>
	<<Dbg_Proc>>	<Alt-Key-3>
	<<Dbg_Watch>>	<Alt-Key-4>
	<<Dbg_Syntax>>	<Alt-Key-5>
	<<Dbg_DataDisp>>	<Control-D>
	<<Dbg_AddWatch>>	<Control-A>
	<<Dbg_ShowCode>>	<Control-s>
	<<Dbg_SelAll>>	<Control-a>
	<<Dbg_RemSel>>	<Control-r>
	<<Dbg_RemAll>>	<Control-R>
	<<Dbg_Close>>	<Control-w>
	<<Dbg_Close>>	<Alt-Key-F4>
    }
    if {$::tcl_platform(platform) == "windows"} {
	lappend keyList "<<Dbg_TclHelp>>" "<Key-F2>"
    }

    # Map each virtual event to the key binding.

    foreach {ev key} $keyList {
	event add $ev $key
    }

    # Now, modify the keyList turning the key bindings into strings 
    # used in the menus display.

    regsub -all {[Cc]ontrol} $keyList Ctrl keyList
    regsub -all {[Kk]ey-}    $keyList {}   keyList
    regsub -all {<}          $keyList {}   keyList
    regsub -all {>}          $keyList {}   keyList
    
    set newList {}
    foreach {ev key} $keyList {
	if {[regexp -- {-([A-Z])} $key dummy letter]} {
	    regsub -- {-[A-Z]$} $key "-Shift-$letter" key
	} elseif {[regexp -- {-([a-z])$} $key dummy letter]} {
	    set letter [string toupper $letter]
	    regsub -- {-[a-z]$} $key "-$letter" key
	}
	lappend newList $ev $key
    }

    # This list is in "array set" order and creates the  array:
    # 'arranName(virtualKey) = accKeyword'  Where the accKeyword
    # is the actual keys used based on the systems key mapping.

    return $newList
}

# system::setWidgetAttributes --
#
#	Set the system specific widget attributes for the arrow, bar, color,
#	exeFiles and exeString variables.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc system::setWidgetAttributes {} {
    variable arrow
    variable bar
    variable color
    variable exeFiles
    variable exeString
    variable dbgSuffix

    # Set various data used by the system.  
    
    if {$::tcl_platform(platform) == "windows"} {
	array set color {
	    lightOutside systemButtonHighlight
	    lightInside system3Dlight
	    darkOutside system3DDarkShadow
	    darkInside  systemButtonShadow
	}
	set bar [list \
	    color  system3Dlight \
	    width  [expr {[image width  $image::image(var_enable)] + 4}] \
    	    height [expr {[image height $image::image(var_enable)]}]]

	set exeFiles  [list {{Executable files} .exe} {{All Files} *}]
	set exeString   ".exe"
	set dbgSuffix d
	set arrow       arrow
    } else {
	set rgb [winfo rgb . white]
	# Make sure the color format is 12 digits long, with 0 left-padding
	set formatSpec "#%04X%04X%04X"
	# break up rgb list into components
	foreach {r_base g_base b_base} $rgb {}

	set c [format $formatSpec $r_base $g_base $b_base]
	set color(lightInside) $c

	set r [expr {int($r_base * 0.8)}]
	set g [expr {int($g_base * 0.8)}]
	set b [expr {int($b_base * 0.8)}]
	set c [format $formatSpec $r $g $b]
	set color(lightOutside) $c

	set rgb [winfo rgb . [. cget -bg]]
	# break up rgb list into components
	foreach {r_base g_base b_base} $rgb {}

	set r [expr {int($r_base * 0.05)}]
	set g [expr {int($g_base * 0.05)}]
	set b [expr {int($b_base * 0.05)}]
	set c [format $formatSpec $r $g $b]
	set color(darkInside) $c

	set r [expr {int($r_base * 0.3)}]
	set g [expr {int($g_base * 0.3)}]
	set b [expr {int($b_base * 0.3)}]
	set c [format $formatSpec $r $g $b]
	set color(darkOutside) $c

	set bar [list \
	    color  $color(lightOutside) \
	    width  [expr {[image width $image::image(var_enable)] + 4}] \
	    height [expr {[image height $image::image(var_enable)]}]]

	set arrow left_ptr
	set exeFiles  [list {{All Files} *}]	
	set exeString ""
	set dbgSuffix g
    }
    return
}

# system::getArrow --
#
#	Return the cursor name for the system specific arrow cursor.
#
# Arguments:
#	None.
#
# Results:
#	A cursor name.

proc system::getArrow {} {
    return $system::arrow
}

# system::getBar --
#
#	Return the attributes for the code bars.
#
# Arguments:
#	None.
#
# Results:
#	An array set order list of attributes.

proc system::getBar {} {
    return $system::bar
}

# system::getColor --
#
#	Return the system specific colors for widgets.
#
# Arguments:
#	None.
#
# Results:
#	An array set order list of attributes.

proc system::getColor {} {
    return [array get system::color]
}

# system::getExeFiles --
#
#	Return the list of system specific file types.
#
# Arguments:
#	None.
#
# Results:
#	An ordered list that can be used for the "-types" option of Tk
#	file dialog boxes.

proc system::getExeFiles {} {
    return $system::exeFiles
}

# system::getExeString --
#
#	Return the system specific file suffix for executable files.
#	If this is an executable with symbols, then return the string 
#	with the debug suffix included.
#
# Arguments:
#	None.
#
# Results:
#	A string.

proc system::getExeString {} {
    if {[info exists ::tcl_platform(debug)]} {
	return "[system::getDbgSuffix]$system::exeString"
    } else {
	return "$system::exeString"
    }
}


# system::getDbgSuffix --
#
#	Return the system specific file suffix for executable files.
#
# Arguments:
#	None.
#
# Results:
#	A string.

proc system::getDbgSuffix {} {
    return $system::dbgSuffix
}

# system::getComSpec --
#
#	Get the execuatable name to call for invoking Windows
#	executables.
#
# Arguments:
#	None.
#
# Results:
#	The command to use in exec.

proc system::getComSpec {} {
    global env

    foreach x [array names env] {
	if {[string tolower $x] == "comspec"} {
	    return $env($x)
	}
    }
    return
}

# system::formatFile --
#
#	For Windows apps, we need to do a case insensitive filename
#	comparison.  Convert the filename to lower case.  For UNIX
#	this command is a no-op and just returns the original name.
#
# Arguments:
#	filename
#
# Results:
#	The system dependent fileName used for comparisons.

proc system::formatFilename {filename} {
    if {$::tcl_platform(platform) == "windows"} {
	return [string tolower $filename]
    } else {
	# Bugzilla 19824 ...
	# On some operating systems (i.e. Linux) the [pwd] system call
	# will return a path where symbolic links are resolved, making
	# it possible that the filename used by the backend is not the
	# same as the name used here in the frontend, because the
	# backend switches into the directory of a file to determine
	# its absolute path, and the frontend doesn't. Yet. Now we use
	# the commands below, the same sequence as used by the
	# backend, to get the canonical absolute path to the
	# file. Thus assuring that front- and backend use the same
	# path when dealing with files and blocks. The catch makes
	# sure that we are able to continue working even if the
	# directory or file is not present. This is no problem later
	# on because the checks we perform before launching the
	# application will then fail too.

	if {![catch {
	    set here [pwd]
	    cd [file dirname $filename]
	    set fnew [file join [pwd] [file tail $filename]]
	    cd $here
	}]} {
	    set filename $fnew
	}
	return $filename
    }
}

# system::bindToAppIcon --
#
#	This function sets the icon for a toplevel window.  On Windows,
#	we use the winico extension to set the icon.  On Unix, we create
#	an iconwindow containing a label displaying the icon image.
#
# Arguments:
#	toplevel	The toplevel for which an icon should be set.
#
# Results:
#	None.

proc system::bindToAppIcon {toplevel} {
    if {$::tcl_platform(platform) == "windows"} {
	if {[catch {
	    wm iconbitmap $toplevel $::debugger::parameters(iconImage)
	}]} {
	catch {winico setwindow $toplevel $::debugger::parameters(iconImage)}
	}
    } elseif {$::tcl_platform(platform) == "unix"} {
    	set iconImage [image create photo \
		-file $::debugger::parameters(iconImage)]
	set iconTop   [toplevel ${toplevel}_iconWindow]

	pack [label $iconTop.l -image $iconImage]
	wm iconwindow $toplevel $iconTop
    }
    return
}

# system::getBrowser --
#
#	Get the browser value.
#
# Arguments:
#	None.
#
# Results:
#	The browserCmd.

proc system::getBrowser {} {
    if {($::tcl_platform(platform) == "windows") \
	    && ([pref::prefGet browserDefault])} {
	return $system::browser(start)
    }
    if {[pref::prefExists browserCmd]} {
	return [pref::prefGet browserCmd]
    } else {
	return {}
    }
}


# system::openURL --
#
#	Open a new browser to the specified URL.
#
# Arguments:
#	url	The URL to send to the browser.
#
# Results:
#	The result of evaluating the exec-ed command.

proc system::openURL {url} {
    if {[catch {
	set browserCmd [system::getBrowser]
	if {$browserCmd == {}} {
	    set msg1 "No command defined for launching a browser."  
	    set msg2 "Please set this option in the Preferences."
	    tk_messageBox -icon error -type ok \
		    -title "Error" -parent [gui::getParent] \
		    -message "$msg1\n$msg2"
	    return
	}
	
	if {$::tcl_platform(platform) == "windows"} {
	    # If the URL is not an http reference, convert it to a native
	    # file name to make browsers happy.

	    if {! [regexp {^http:} $url]} {
		set url [file nativename $url]
	    }

	    # If the default browser is being used, just call the 
	    # start command and exit, Windows will do the rest.
	    # Otherwise generate the appropriate browserCmd to be
	    # execed.
	    
	    if {[pref::prefGet browserDefault]} {
		$browserCmd $url {} {}
		return
	    }
	    regsub -all {\\} $browserCmd {\\\\} browserCmd
	    if {![regsub -all {\"%1\"} $browserCmd "\"$url\"" browserCmd]} {
		lappend browserCmd $url
	    }
	    
	} else {
	    # If the browserCmd is "netscape" then try two possible 
	    # methods to exec Netscape on Unix.  Otherwise append
	    # the URL and exec the browser command.
	    
	    if {$system::browser(netscape) == $browserCmd} {
		set browserCmdCopy $browserCmd
		lappend browserCmd -remote openURL($url)
		if {[catch {set result [eval exec $browserCmd]}]} {
		    lappend browserCmdCopy $url
		    
		    set result [eval exec $browserCmdCopy &]
		}
		return $result
	    } else {
		lappend browserCmd $url
	    }
	}
	
	# The Windows default or Unix Netscape are not the current browser
	# commands.  Attempt to exec the command the user entered.

	return [eval exec $browserCmd &]
    } msg] == 1} {
	# Error occured (usually because it was entered incorrectly in the
	# preferences panel).  We just show the user the error and ignore
	# the error.

	tk_messageBox -icon warning -type ok \
		-title "Warning" -parent [gui::getParent] \
		-message "Could not launch browser: \n\nCmd: $browserCmd\n\n$msg"
	return 1
    } else {
	return 0
    }
}
    
# system::createBrowserWindow --
#
#	Create the Browser Window for the Preferences Window.
#	This code is located here because the interface for
#	specifying depends on the platform.
#
# Arguments:
#	mainFrm		The containing frame.
#
# Results:
#	A handle to the frame containing the Browser interface.

proc system::createBrowserWindow {mainFrm} {
    set pad  6
    set pad2 10

    if {$::tcl_platform(platform) == "windows"} {
	set subFrm  [prefWin::createSubFrm $mainFrm browserFrm "Browser"]
	set otherLbl [label $subFrm.otherLbl -text "Command Line:"]
	set otherEnt [entry $subFrm.otherEnt \
		-textvariable [pref::prefVar browserCmd TempPref]]
	set defaultRad [radiobutton $subFrm.defaultRad -value 1 \
		-text "Use default browser." \
		-variable [pref::prefVar browserDefault TempPref] \
		-command "system::checkBrowserWindowState $otherLbl $otherEnt"]
	set otherRad [radiobutton $subFrm.otherRad -value 0 \
		-text "Choose an alternative browser." \
		-variable [pref::prefVar browserDefault] \
		-command "system::checkBrowserWindowState $otherLbl $otherEnt"]
	
	grid $defaultRad -row 0 -column 0 -sticky w  -padx $pad -columnspan 2
	grid $otherRad   -row 1 -column 0 -sticky w  -padx $pad -columnspan 2
	grid $otherLbl   -row 2 -column 1 -sticky w  -padx $pad  
	grid $otherEnt   -row 3 -column 1 -sticky we -padx $pad 
	grid columnconfigure $subFrm 0 -minsize 40
	grid columnconfigure $subFrm 1 -weight 1
	pack $subFrm -fill both -expand true -padx $pad -pady $pad2

	set system::browser(fg) [$otherLbl cget -fg]
	system::checkBrowserWindowState $otherLbl $otherEnt

	lappend prefWin::focusOrder($mainFrm) $defaultRad $otherRad $otherEnt
    } else {
	set subFrm  [prefWin::createSubFrm $mainFrm browserFrm "Browser"]
	set browserLbl [label $subFrm.browserLbl \
		-text "Specify the command line for launching a browser:"]
	set browserBox [ComboBox $subFrm.browserBox \
		-textvariable [pref::prefVar browserCmd TempPref]]

	grid $browserLbl -row 0 -column 0 -sticky w  -padx $pad
	grid $browserBox -row 1 -column 0 -sticky we -padx $pad
	grid columnconfigure $subFrm 0 -weight 1
	pack $subFrm -fill both -expand true -padx $pad -pady $pad2

##	$browserBox add $system::browser(iexplorer)
##	$browserBox add $system::browser(netscape)
##	$browserBox add [system::getBrowser]
##	$browserBox set [system::getBrowser]

	$browserBox configure -values [list \
		$system::browser(iexplorer) \
		$system::browser(netscape) \
		[system::getBrowser]]

	$browserBox configure -text [system::getBrowser]

	lappend prefWin::focusOrder($mainFrm) $browserBox.e
    }
    return $mainFrm.browserFrm
}

# system::checkBrowserWindowState --
#
#	Update the UI based on the state of the interface.
#
# Arguments:
#	args	Args depend on platform.
#		  Windows: 
#			lbl	The label to enable or disable.
#			ent	The entry to enable or disable.
#		  UNIX: 
#			???	
#
# Results:
#	None

proc system::checkBrowserWindowState {args} {
    if {$::tcl_platform(platform) == "windows"} {
	set lbl [lindex $args 0]
	set ent [lindex $args 1]
	if {[pref::prefGet browserDefault TempPref]} {
	    array set color [system::getColor]
	    $lbl configure -fg $color(darkInside)
	    $ent configure -state disabled
	    pref::prefSet TempPref browserCmd {}
	} else {
	    $lbl configure -fg $system::browser(fg)
	    $ent configure -state normal
	}
    }
    return
}

# kill --
#
#	Unix only:  Define "kill" to exec "kill -9".
#	Windows version of "kill" is written in c.    -- Tclx
#
# Arguments:
#	pid	Id of application to kill.
#
# Results:
#	The application with with process id "pid" is killed.

if {[catch {package require Tclx}]} {
if {$tcl_platform(platform) == "unix"} {
    proc kill {pid} {
	exec kill -9 $pid
	}
    }
}

proc ::start {url arguments startdir} {
    # executable == url, no args, no startdir

    if {$::tcl_platform(os) == "Windows NT"} {
	set rc [catch {exec $::env(COMSPEC) /c start $url &} emsg]
    } else {
	# Windows 95/98
	set rc [catch {exec start $url &} emsg]
    }
    if {$rc} {
	error "Error displaying $url in browser\n$emsg"
    }
}
