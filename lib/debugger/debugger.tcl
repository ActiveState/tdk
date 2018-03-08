# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# debugger.tcl --
#
#	This file is the first file loaded by the Tcl debugger.  It
#	is responsible for loacating and loading the rest of the Tcl
#	source.  It will also set other global platform or localization
#	state that the rest of the application will use.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: debugger.tcl.in,v 1.25 2001/02/09 07:52:48 welch Exp $

# Source in other Tcl files.  These files should only define procs.
# No other Tcl code should run during the load process.  There should be no
# implied loading order here.

package require projectInfo
if {![info exists ::projectInfo::hasUI]} {set ::projectInfo::hasUI 1}

if {$::projectInfo::hasUI} {
    catch {package require Tk}
}

package require cmdline
if {$::tcl_platform(platform) == "windows"} {
    package require registry
}

package provide debugger 1.5

namespace eval debugger {
    variable libdir [file dirname [info script]]

    # Debugger settable parameters --
    #
    # The parameters array contains values that are needed by various procs
    # in the debugger, but that must be supplied by the application that uses
    # the debugger library.  The list below defines the available parameters
    # and their default values.  The application can override these values when
    # it calls debugger::init.
    #
    # Parameters:
    #	aboutImage	The image to display in the splash screen and about
    #			box.
    #	aboutCopyright	The copyright string to display in the splash screen
    #			and about box.
    #	appType		Either "local" or "remote" to indicate the initial
    #			value of the app type default for new projects.
    #   iconImage	The image file (Unix) or winico image handle (Windows)
    #			to use for the window manager application icon.
    #	productName	The name of the debugger product.


    variable parameters
    array set parameters [list \
	    aboutImage images/about.gif \
	    aboutCopyright "$::projectInfo::copyright\nVersion $::projectInfo::patchLevel" \
	    appType local \
	    iconImage {} \
	    productName "$::projectInfo::productName Debugger" \
	    ]
}

if {$::projectInfo::hasUI} {
    wm withdraw .

    package require tile

    # Handle Tk 8.5 (ttk) or 8.4 (tile) usage of style
    namespace eval ::ttk {
	style map TEntry -fieldbackground {invalid \#FFFFE0} \
	    -foreground {invalid \#FF0000}
	style map TCombobox -fieldbackground {invalid \#FFFFE0} \
	    -foreground {invalid \#FF0000}
    }
}

# ### ### ### ######### ######### #########
## Set up main engine and UI ...

### Tracing of all command executions ...
##source [file join $::debugger::libdir log.tcl]
###

package require engine     ;# backend
package require pref       ;# preferences
package require system     ;# system data
package require instrument ;# instrumentation engine
package require loc        ;# handling of locations
package require pdx        ;# locating and loading .pdx files.
package require util       ;# misc utility commands

engine main ;# backend for main debuggee

# ### ### ### ######### ######### #########

if {$::projectInfo::hasUI} {
    package require gui

    topgui maingui

    source [file join $::debugger::libdir options.tcl]
    source [file join $::debugger::libdir image.tcl]
    source [file join $::debugger::libdir font.tcl]
    source [file join $::debugger::libdir guiUtil.tcl]
    source [file join $::debugger::libdir selection.tcl]
    source [file join $::debugger::libdir bindings.tcl]
    source [file join $::debugger::libdir prefWin.tcl]

    source [file join $::debugger::libdir result.tcl]
    source [file join $::debugger::libdir menu.tcl]
    source [file join $::debugger::libdir toolbar.tcl]
}

# debugger::init --
#
#	Start the debugger and show the main GUI.
#
# Arguments:
#	argv		The command line arguments.
#	newParameters	Additional debugger parameters specified as a
#			list of keys and values.  These parameters are
#			saved for later use by other modules in the
#			debugger.  See above for a list of the possible
#			values. Optional. Defaults to empty.
#
# Results:
#	None.

proc debugger::init {argv {newParameters {}}} {
    variable parameters

    if {$::projectInfo::hasUI} {uiDefOpt::init}
    # Merge in application specific parameters.

    array set parameters $newParameters

    # Note: the wrapper target for this application must contain a -code
    # fragment that moves the -display switch to the beginning and
    # then inserts a -- switch to bypass the normal wish argument
    # parsing.  If we don't do this, then switches like -help will be
    # intercepted by wish before we get to handle them.

    append usageStr "Usage: [cmdline::getArgv0] ?options? projectFile\n" \
	    "  -help                   print this help message\n" \
	    "  -version                display version information\n"
    if {$::tcl_platform(platform) == "unix"} {
	append usageStr "  -display <displayname>  X display for interface\n"
    }
    set optionList {? h help v version}

    # Parse the command lines:
    while {[set err [cmdline::getopt argv $optionList opt arg]]} {
	if { $err < 0 } {
	    append badArgMsg "error: [cmdline::getArgv0]: " \
		    "$arg (use \"-help\" for legal options)"
	    set errorBadArg 1
	    break
	} else {
	    switch -exact -- $opt {
		? -
		h -
		prohelp -
		help {
		    set projectInfo::printCopyright 0
		    set showHelp 1
		    set dontStart 1
		}
		v -
		version {
		    set projectInfo::printCopyright 1
		    set dontStart 1
		}
	    }
	}
    }

    # If showing help information - do so then exit.  However, on windows
    # there is not stdout so we display the message to a message box.

    if {[info exists showHelp]} {
	if {$::tcl_platform(platform) == "windows"} {
	    tk_messageBox -message $usageStr -title Help
	} else {
	    puts $usageStr
	}
    }
    if {$projectInfo::printCopyright} {
	projectInfo::printCopyrightOnly {TDK Debugger}
    }
    if {[info exists dontStart]} {
	exit 0
    }
    if {[info exists errorBadArg]} {
	puts $badArgMsg
	if {$::tcl_platform(platform) == "windows"} {
	    tk_messageBox -message $badArgMsg -title Help
	}
	exit 9
    }
    
    # WARNING. These routines need to be called in this order!

    TestForSockets
    system::init

    # Normally the checker will not believe the next line to be in
    # error, because 'main' is an 'engine' object, and has no
    # definition to check. If however the total body of the devkit
    # sources is checked in one run we we have at least one definition
    # of a procedure 'main' floating around, which takes no
    # arguments. Causing the checker to mark this as bogus. This is
    # prevent by the pragma specified in the next line.
    #-
    #checker exclude procNumArgs
    main configure \
	    -warninvalidbp     [pref::prefGet warnInvalidBp] \
	    -instrumentdynamic [pref::prefGet instrumentDynamic] \
	    -doinstrument      [pref::prefGet doInstrument] \
	    -dontinstrument    [pref::prefGet dontInstrument] \
	    -autoload          [pref::prefGet autoLoad] \
	    -erroraction       [pref::prefGet errorAction]

    if {$::projectInfo::hasUI} {
	# Display the splash screen and set a timer to remove it.

	package require splash
	splash::start

	# Remove the send command.  This will keep other applications
	# from being able to poke into our interp via the send command.
	if {[info commands send] == "send"} {
	    rename send ""
	}
    
	# Calculate the font data for the current font.

	font::configure [pref::prefGet fontType] [pref::prefGet fontSize]

	# Restore the settings for any paned or tabled window.

	guiUtil::restorePaneGeometry
    }

    # Restore instrumentation preferences.

    instrument::extension incrTcl [pref::prefGet instrumentIncrTcl]
    instrument::extension tclx   [pref::prefGet instrumentTclx]
    instrument::extension expect [pref::prefGet instrumentExpect]

    if {$::projectInfo::hasUI} {
	# Draw the GUI.  We need to ensure that the gui is created before loading
	# any extensions in case they need to modify the gui.

	maingui engine: main
	maingui showMainWindow

	# Load any external extensions

	pdx::load

	# Hide the main window until the splash screen is gone.

	splash::complete

	wm deiconify [maingui mainDbgWin]

	# Defer the update until after we've sourced any extensions to avoid
	# annoying refreshes.

	update
    }

    # If there are more than one arguments left on the command line
    # dump the usage string and exit.  However, on windows
    # there is not stdout so we display the message to a message box.

    if {[llength $argv] > 1} {
	if {$::tcl_platform(platform) == "windows"} {
	    tk_messageBox -message $usageStr -title "Wrong Number of Arguments"
	} else {
	    puts $usageStr
	}
	exit 10
    }

    if {$::projectInfo::hasUI} {
	# Now try to figure out which project to load.

	if {[llength $argv] == 1} {
	    set projPath [file join [pwd] [lindex $argv 0]]
	} elseif {[pref::prefGet projectReload]} {
	    set projPath [pref::prefGet projectPrev]

	    # Get the last good project if the current one
	    # is non-recoverable.
	    if {$projPath == {}} {
		set projPath [pref::prefGet projectLast]
	    }
	} else {
	    set projPath {}
	}

	if {$projPath != {}} {
	    maingui prOpenProjCmd $projPath
	}
    }
    return
}


proc PDXInfo {} {
    catch {destroy  .pdxinfo}
    set t [toplevel .pdxinfo]
    text $t.t

    # Insert text about PDX files and their contents ...

    $t.t insert end "PDX files:\n\t[join [pdx::info] "\n\t"]\n"
    $t.t insert end "Spawn commands:\n\t[join [lsort $instrument::spawnCmds] "\n\t"]\n"
    $t.t insert end "Cmd wrappers:\n\t[join [lsort [array names instrument::extraNubCmds]] "\n\t"]\n"

    pack $t.t -expand 1 -fill both
    return
}


# ExitDebugger --
#
#	Call this function to gracefully exit the debugger.  It will
#	save preferences and do other important cleanup.
#
# Arguments:
#	None.
#
# Results:
#	This function will not return.  The debugger will die.

proc ExitDebugger {} {
    # Save the implicit prefs to the registry, or UNIX resource.  Implicit
    # prefs are prefs that are set by the debugger and do not belong in a
    # project file (i.e., window sizes.)

    if {$::projectInfo::hasUI} {
	if {![system::saveDefaultPrefs 1]} {
	    exit
	}
    }
    return
}

# CleanExit --
#
#	Before exiting the debugger, clear all of the
#	pref data so the next session starts fresh.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc CleanExit {} {
    global tcl_platform

    proc ExitDebugger {} {}
    if {$tcl_platform(platform) == "windows"} {
	registry delete [pref::prefGet key]
    } else {
	file delete [pref::prefGet fileName]
    }
    exit
}

# TestForSockets --
#
#	The debugger requires sockets to work.  This routine
#	tests to ensure we have sockets.  If we don't have 
#	sockets we gen an error message and exit.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc TestForSockets {} {
    proc dummy {args} {error dummy}
    if {[catch {set socket [socket -server dummy 0]} msg]} {
	tk_messageBox -parent . -title "Fatal error" \
	    -message "$::debugger::parameters(productName) requires sockets to work." \
	    -icon error -type ok
	exit
    }
    close $socket
    rename dummy ""
}

