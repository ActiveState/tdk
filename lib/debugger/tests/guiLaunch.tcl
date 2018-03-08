# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tests/debugger/guiLaunch.tcl
#
#	This file contains functions that that enable test scripts to
#	excercise the debugger GUI.
#
# Copyright (c) 1998-2000 by Ajuba Solutions

#
# RCS: @(#) $Id: guiLaunch.tcl,v 1.13 2000/10/31 23:31:03 welch Exp $

set odir [pwd]
cd [file dirname [info script]]
cd $::protest::sourceDirectory

# Load the minimum set of files needed to get the debugger engine working.

package require projectInfo
package require cmdline

namespace eval debugger {
    variable libdir [pwd]
    variable parameters
    array set parameters [list \
	    aboutImage [file join $libdir images/about.gif] \
	    aboutCopyright "testing" \
	    appType local \
	    iconImage [expr {($::tcl_platform(platform) == "windows") \
	        ? "foo" : [file join $libdir images/debugUnixIcon.gif]}]\
	    productName "$::projectInfo::productName Debugger"]
    
}

foreach file {
    pref.tcl image.tcl system.tcl font.tcl dbg.tcl
    break.tcl block.tcl instrument.tcl gui.tcl guiUtil.tcl
    bindings.tcl icon.tcl selection.tcl tkcon.tcl
    breakWin.tcl codeWin.tcl coverage.tcl evalWin.tcl file.tcl find.tcl
    inspectorWin.tcl menu.tcl prefWin.tcl procWin.tcl
    stackWin.tcl toolbar.tcl varWin.tcl watchWin.tcl proj.tcl projWin.tcl
    result.tcl portWin.tcl location.tcl util.tcl
} {
    source $file
}

if {[info procs initProject] == {}} {
    source [file join [pwd] [file dirname [info script]] initProject.tcl]
}

cd $odir

# testGui --
#
#	Test the Debugger's GUI by passing a script to
#	be executed in the appliaction, and another script
#	to extract the result.
#
# Arguments:
#	appScript	Script to debug.
#	testScript	Script to run in debugger's interp.
#
# Results:
#	The result of the testScript.

proc testGui {appScript testScript {setupScript ""}} {
    set result {}
    set oldpwd [pwd]

    set code [catch {
	cd $::protest::sourceDirectory
	initGui

	# Launch a project that uses the appScript

	makeFile $appScript \
		[file join $::tcltest::temporaryDirectory dummy.tcl]
	initProject "Ray's Breath Smells Like Cat Food.tpj" \
		[file join $::tcltest::temporaryDirectory dummy.tcl] {} . \
		[info nameofexecutable]

	# Run the setupScript to set up special project or debugger state,
	# such as adding bpts.

	if {$setupScript != ""} {
	    set result [uplevel 1 $setupScript]
	}

	# Stop at the first command in appScript

	gui::run dbg::step
	waitForApp
	waitForApp

	# Run the testScript to simulate user actions and introspect on the
	# debugger's state.

	set result [uplevel 1 $testScript]
    } msg]

    # delete the appScript file, and cleanup the debugger's state.

    quitGui
    catch {file delete -force \
	    [file join $::tcltest::temporaryDirectory dummy.tcl]}
    cleanProjectFiles
    cd $oldpwd

    # throw and error or return the result of the testScript.

    if {$code} {
	error $msg $::errorInfo $::errorCode
    }
    return $result
}

# initGui --
#
#	Initialize the GUI and the nub.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc initGui {} {
    wm geometry . +0+0

    dbg::register linebreak  {eventProc linebreak gui::linebreakHandler}
    dbg::register varbreak   {eventProc varbreak gui::varbreakHandler}
    dbg::register error      {eventProc error gui::errorHandler}
    dbg::register result     {eventProc result gui::resultHandler}
    dbg::register attach     {eventProc attach gui::attachHandler}
    dbg::register exit       {eventProc exit {}}
    dbg::register cmdresult  {eventProc cmdresult gui::cmdresultHandler}

    system::init
    font::configure [pref::prefGet fontType] [pref::prefGet fontSize]

    dbg::initialize

    gui::showMainWindow
    wm geometry $::gui::gui(mainDbgWin) +0+0
    wm deiconify $::gui::gui(mainDbgWin)
    return
}

# quitGui --
#
#	Remove the registered commands.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc quitGui {} {
    foreach a [after info] {
	after cancel $a
    }
    catch {dbg::quit}
    catch {eval destroy [winfo children .]}
    file::update 1
    catch {unset gui::format}
    gui::setCurrentState new

    after 100

    dbg::unregister linebreak  {eventProc linebreak gui::linebreakHandler}
    dbg::unregister varbreak   {eventProc varbreak gui::varbreakHandler}
    dbg::unregister error      {eventProc error gui::errorHandler}
    dbg::unregister result     {eventProc result gui::resultHandler}
    dbg::unregister attach     {eventProc attach gui::attachHandler}
    dbg::unregister exit       {eventProc exit {}}
    dbg::unregister cmdresult  {eventProc cmdresult gui::cmdresultHandler}
    return
}

# eventProc --
#
#	The proc that is registered to execute when an event is triggered.
#	Sets the global variable Gui_AppStopped to the event to trigger the
#	vwait called by the waitForAppp proc.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc eventProc {event cmd args} {
    global Gui_AppStopped
#    puts "EVENT - $event"
    if {$cmd != {}} {
	if {[catch {eval $cmd $args} msg]} {
	    puts "Error $::errorInfo"
	}
    }
    set Gui_AppStopped $event
    return
}

# waitForApp --
#
#	Call this proc after dbg::step, dbg::run, dbg::evaluate. Returns
#	when the global variable Gui_AppStopped is set by the breakProc
#	or exitProc procedures.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc waitForApp {} {
    global Gui_AppStopped
    vwait Gui_AppStopped
    return
}

