# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# system.tcl --
#
#	This file defines all system specific data.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2009 ActiveState Software Inc.

# 
# RCS: @(#) $Id: system.tcl,v 1.22 2000/10/31 23:31:01 welch Exp $

##
## DANGER, dragons
##

# The groups created here are in conflict with groups used by the
# package pref::devkit. This is currently not a problem, because the
# debugger has no need of the data from that package. Should this
# happen then the __debugger__ will have to change, i.e. rename its
# groups to get out of the conflict. The other package provides the
# main shared preferences.

##
## DANGER, dragons
##

package require Tclx ; # for 'kill' command

package require fmttext

if {$::projectInfo::hasUI} {
    package require tile ; # themed widgets
    package require BWidget ; # BWidgets | Use its mega widgets.
    Widget::theme 1 ; # use themes widgets in BWidgets
}
if {$::tcl_platform(platform) eq "windows"} {
    package require registry
}

package require pref
package require pref::stdsr

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

    if {$::tcl_platform(platform) eq "windows"} {
	update
#	chgClass .
    }

    # Reset the environment so we don't perturb things too much.
    # The global env variable is modified.

    system::resetEnv

    # Restore any global preferences.  The group name returned by the
    # call is the default group to set user preferences into.

    set group [system::initGroups]

    if {$::projectInfo::hasUI} {
	# Set widget attributes that depend on the platform.

	system::setWidgetAttributes
    }

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
#	None.  The global env variable is altered.

proc system::resetEnv {} {
    if {0} {
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

    # Initialize the configuration for the standard s/r commands for
    # preferences.

    pref::stdsr::rootSet           $projectInfo::prefsRoot
    pref::stdsr::versionHistorySet [linsert $projectInfo::prefsLocationHistory 0 $projectInfo::prefsLocation]

    # Set the group search order used when attempting to resolve
    # the location of a preference within multiple groups.
    
    pref::setGroupOrder {
	TempProj TempPref Project ProjectDefault GlobalDefault 
	ProjectFactory GlobalFactory
    }

    pref::groupInit GlobalFactory [list \
	    comboListSize	10			{} \
	    exitPrompt		ask			{} \
	    fileOpenDir		[pwd]		{}			\
	    fontSize		10		fmttext::updateDbgText       \
	    fontType		courier 	fmttext::updateDbgText       \
	    highlight		  lightblue 	fmttext::updateDbgHighlights \
	    highlight_chk_error	  pink		{maingui updateChkHighlights} \
            highlight_chk_warning yellow	{maingui updateChkHighlights} \
	    highlight_cmdresult	  #46acff	fmttext::updateDbgHighlights \
	    highlight_error	  red		fmttext::updateDbgHighlights \
	    highlight_profiled    #f9ab21       {maingui updateProfHighlights} \
	    highlight_uncovered   #59c611       {maingui updateCovHighlights} \
	    historySize		64		system::historyResize     \
	    paneGeom		{}		{} \
	    projectList		{}		{} \
	    projectPrev		{}		{} \
	    projectLast		{}		{} \
	    projectReload	1		{} \
	    screenSize		300		system::screenResize        \
	    tabSize		8		{maingui codeUpdateTabStops} \
	    showCodeLines	1			{} \
	    showResult		1			{} \
	    showStatusBar	1			{} \
	    showToolbar		1			{} \
	    warnOnKill		1			{} \
	    warnOnClose		1			{} \
	    warnInvalidBp	1		{maingui warnInvalidBp} \
	    enableCoverage	0			{} \
	    winGeoms		{}			{} \
	    useTooltips         1               {maingui useTooltips} \
    ]

    if {$::projectInfo::hasUI} {
	set autoLoad 0
    } else {
	set autoLoad 1
    }
    pref::groupInit ProjectFactory [list \
	    appScript		{}		{maingui prwUpdateScriptList} \
	    appArg		{}		{maingui prwUpdateArgList}   \
	    appDir		{}		{maingui prwUpdateDirList}   \
	    appInterp	[lindex [system::getInterps] 0]	{maingui prwUpdateInterpList} \
	    appInterpArg	{}		{maingui prwUpdateInterpArgList}   \
	    appScriptList	{}			{} \
	    appArgList		{}			{} \
	    appDirList		{}			{} \
	    appInterpList	[system::getInterps]	{} \
	    appInterpArgList	{}			{} \
	    appType		$debugger::parameters(appType) {} \
	    breakList		{}			{} \
	    spawnList		{}			{} \
	    errorAction		1		{maingui initInstrument}	\
	    dontInstrument	{}		{maingui initInstrument}	\
	    doInstrument	{*}		{maingui initInstrument}	\
	    instrumentRoot      0               {maingui initInstrument}	\
	    instrumentDynamic	1		{maingui initInstrument}	\
	    instrumentIncrTcl	0		{maingui prwUpdateIncrTcl} \
	    instrumentExpect	1		{maingui prwUpdateExpect}  \
	    instrumentTclx	1		{maingui prwUpdateTclX}    \
	    autoLoad		$autoLoad	{maingui initInstrument}  \
	    portRemote		2576		{maingui prwUpdatePort}  \
	    projVersion		2.0		  {}			 \
	    prevViewFile 	{} 		  {}			\
	    watchList		{}		  {}			\
	    varTransformList    {}                {}                      \
	    coverage            none              {maingui chgCoverage}   \
	    autoAddSpawn        0                 {} \
	    autoKillSub         0                 {} \
					\
	    staticSyntaxCheck    1                 {} \
	    staticSyntaxCore     [info tclversion] {maingui codeCheckCore} \
	    staticSyntaxSuppress {}                {maingui codeCheckCore} \
    ]
    # Bugzilla 19719 ... New key "varTransformList" to hold global
    # information associating var names with transformations.

    # Create the GlobalDefault group.  Specify the save and restore commands
    # based on which platform we're running on.

    if {$::tcl_platform(platform) eq "windows"} {
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

    if {$::tcl_platform(platform) eq "windows"} {
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
	set how [maingui prCloseProjDialog]
	if {$how eq "CANCEL"} {
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

    set projPath [maingui prGetProjectPath]
    if {$close && ($how eq "SAVE")} {
	pref::prefSet GlobalDefault projectPrev $projPath
	pref::prefSet GlobalDefault projectLast $projPath
	if {[maingui prSaveProjCmd $projPath]} {
	    return 1
	}
    } elseif {$close && ($how eq "CLOSE")} {
	if {[maingui prProjectNeverSaved]} {
	    pref::prefSet GlobalDefault projectPrev {}
	} else {
	    pref::prefSet GlobalDefault projectPrev $projPath
	    pref::prefSet GlobalDefault projectLast $projPath
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
	maingui prCloseProj CLOSE
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
    if {!$::projectInfo::hasUI} {return 1}

    pref::stdsr::winRestoreCmd $group $debugger::parameters(productName)/$group
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
    if {!$::projectInfo::hasUI} {return 1}

    pref::stdsr::winSaveCmd $group $debugger::parameters(productName)/$group
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
    if {!$::projectInfo::hasUI} {return 1}
    pref::stdsr::unixRestoreCmd $group Debugger/$group
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
    if {!$::projectInfo::hasUI} {return 1}

    pref::stdsr::unixSaveCmd $group Debugger/$group
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
    foreach x [maingui preservables] {
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
    if {$::tcl_platform(platform) eq "windows"} {
	set ext ".exe"
    } else {
	set ext ""
    }

    # First find wish & tclsh exe files relative to the debugger executable.

    set exePath [file join [pwd] [info nameofexecutable]]
    set path [file dirname $exePath]

    if {$::projectInfo::hasUI} {
	foreach y [list $::projectInfo::executable(tclsh) \
		$::projectInfo::executable(wish)] {
	    set exe [file join $path $y]$ext
	    if {[file exists $exe]} {
		lappend result [file nativename $exe]
	    }
	}
    }

    # Look for other Tcl shells on user's path, if present.
    if {[info exists ::env(PATH)]} {
	if {$::tcl_platform(platform) eq "windows"} {
	    set sep \;
	} else {
	    set sep :
	}
	foreach path [split $::env(PATH) $sep] {
	    foreach y [glob -nocomplain -directory $path wish* tclsh*] {
		lappend result [file nativename $y]
	    }
	}
    }

    # Bugzilla 19618 ... collapse the list to contain only unique paths
    set result [uniquePaths $result]
    return $result
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
    if {$::tcl_platform(platform) eq "windows"} {
	# enforce case insensitivity on windows
	return [lsort -command {string compare -nocase} -unique $paths]
    } else {
	return [lsort -dictionary -unique $paths]
    }
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
    variable families

    # In the Prefs Window, we want to display as many fixed fonts as possible.
    # Searching through all of the font families in X is too slow and may crash
    # the X Server.  For UNIX, use only a small set of fonts.  For Windows and
    # OS X, allow all of the fonts.

    if {![info exists families]} {
	if {[tk windowingsystem] eq "x11"} {
	    set families {fixed courier {lucida typewriter} serif terminal screen}
	} else {
	    set families [font families]
	}
    }
    return $families
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
	<<Cut>>		<Control-x>
	<<Copy>>		<Control-c>
	<<Paste>>		<Control-v>
	<<Delete>>		<Delete>
	<<Dbg_Find>>	<Control-f>
	<<Dbg_FindNext>>	<Key-F3>
	<<Dbg_Goto>>	<Control-g>
	<<Dbg_Komodo>>	<Control-e>
	<<Dbg_Help>>	<Key-F1>
	<<Dbg_Run>>		<Key-F5>
	<<Dbg_In>>		<Key-F6>
	<<Dbg_Over>>	<Key-F7>
	<<Dbg_Out>>		<Key-F8>
	<<Dbg_To>>		<Shift-F5>
	<<Dbg_CmdResult>>	<Shift-F7>
	<<Dbg_Pause>>	<Key-F9>
	<<Dbg_Stop>>	<Control-F9>
	<<Dbg_CloseDebugger>>	<Control-F1>
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

	<<Dbg_Exit>>	<Control-Key-w>
	<<Dbg_Exit>>	<Alt-Key-F4>
    }

    ## Bugzilla 27994 - Eliminated these virtual bindings, in conflict
    ## with Dbg_Exit, s.a.
    ##	<<Dbg_Close>>	<Control-w>
    ##	<<Dbg_Close>>	<Alt-Key-F4>

    if {$::tcl_platform(platform) eq "windows"} {
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
    # 'arrayName(virtualKey) = accKeyword'  Where the accKeyword
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
    if {[tk windowingsystem] eq "aqua"} {
	event add <<PopupMenu>> <Button-2> <Control-Button-1>
	event add <<PopupMenuRelease>> <ButtonRelease-2> \
	    <Control-ButtonRelease-1>
    } else {
	event add <<PopupMenu>> <Button-3>
	event add <<PopupMenuRelease>> <ButtonRelease-3>
    }

    if {$::tcl_platform(platform) eq "windows"} {
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
    if {[info exists ::env(COMSPEC)]} {
	return $::env(COMSPEC)
    }
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

## Duplicate of code in 'dbg_engine/file.tcl aka snit::type 'filedb'.
## Remove this and replace usages with the filedb typemethod.

proc system::formatFilename {filename} {
    if {$::tcl_platform(platform) eq "windows"} {
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
    variable ::debugger::parameters

    # Use platform specific default if nothing was defined by the application.

    if {$parameters(iconImage) eq {}} {
	set parameters(iconImage) $image::image(f,iconImage)
    }

    if {$::tcl_platform(platform) eq "windows"} {
	# this would set the toplevel icon, but currently we just
	# use the feather icon -- hobbs 2004/02
	#wm iconbitmap $toplevel -default $parameters(iconImage)
    } elseif {[tk windowingsystem] eq "x11"} {
    	set iconImage [image create photo -file $parameters(iconImage)]
	set iconTop   [toplevel ${toplevel}_iconWindow]

	pack [label $iconTop.l -image $iconImage]
	wm iconwindow $toplevel $iconTop
    }
    return
}

proc ::start {url arguments startdir} {
    # executable == url, no args, no startdir

    # The windows NT shell treats '&' as a special character. Using
    # a '^' will escape it. See http://wiki.tcl.tk/557 for more info. 
    if {[string equal $tcl_platform(os) "Windows NT"]} {
	set url [string map {& ^&} $url]
    }
    if {[catch {eval exec [auto_execok start] [list $url] &} emsg]} {
	return -code error "Error displaying $url in browser\n$emsg"
    }
}

proc system::historyResize {} {
    maingui tkConUpdate
}
proc system::screenResize {} {
    maingui tkConUpdate
}

package provide system 1.0
