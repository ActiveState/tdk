# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# dbgLaunch.tcl
#
#	This file contains functions that that enable test scripts to
#	excercise the debugger engine and nub without using the GUI.
#
# Copyright (c) 1998-2000 by Ajuba Solutions

#
# RCS: @(#) $Id: dbgLaunch.tcl,v 1.9 2000/10/31 23:31:02 welch Exp $

# Load the minimum set of files needed to get the debugger engine working.

set odir [pwd]

cd [file dirname [info script]]
set ::tcltest::testsDirectory [file dirname [pwd]]

cd $::protest::sourceDirectory

package require projectInfo

namespace eval debugger {
    variable libdir [pwd]
    variable parameters
    array set parameters [list \
	    aboutImage [file join $libdir images/about.gif] \
	    aboutCopyright "testing" \
	    appType local \
	    iconImage "foo" \
	    productName "$::projectInfo::productName Debugger"]
}

foreach file {
    dbg.tcl block.tcl break.tcl coverage.tcl system.tcl
    instrument.tcl image.tcl pref.tcl proj.tcl location.tcl util.tcl
} {
    source $file
}

if {[info procs initProject] == {}} {
    source [file join [pwd] [file dirname [info script]] initProject.tcl]
}

cd $odir

# proj::InitNewProj --
#
#	Override the init routine for projects since it assumes the existence
#	of GUI APIs and Windows.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc proj::InitNewProj {} {
    variable projectOpen
    set projectOpen 1

    if {[proj::isRemoteProj]} {
	set port [pref::prefGet portRemote]
	while {![dbg::setServerPort $port]} {
	    error "The port you selected is invalid or taken: $port"
	}
    }

    pref::groupUpdate Project
    return
}

# initDbg --
#
#	Initialize the debugger without launching an application.
#	This routine must be called from within the srcs directory.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc initDbg {} {
    wm geometry . +0+0

    set blk::blockCounter 0
    dbg::initialize
    
    dbg::register linebreak {eventProc linebreak}
    dbg::register error     {eventProc error}
    dbg::register attach    {eventProc attach}
    dbg::register exit      {eventProc exit}
    dbg::register cmdresult {eventProc cmdresult}
    system::init
    return
}

# quitDbg --
#
#	Stop debugging the application and unregister the eventProcs	
#
# Arguments:
#	None.
#
# Results:
#	None.

proc quitDbg {} {
    catch {dbg::quit; after 100}
    dbg::unregister linebreak {eventProc linebreak}
    dbg::unregister error     {eventProc error}
    dbg::unregister attach    {eventProc attach}
    dbg::unregister exit      {eventProc exit}
    dbg::unregister cmdresult {eventProc cmdresult}
    return
}

# testDbg --
#
#	Launch the nub on the given script and execute a sequence of
#	debugger operations.
#
# Arguments:
#	nubScript	The script to run in the nub.
#	testScript	The script to execute in the debugger.
#
# Results:
#	Returns the result of the testScript.

proc testDbg {nubScript testScript {setupScript {}} {exename tclsh}} {
    set result {}
    set dummy [file join $::tcltest::temporaryDirectory dummy.tcl]
    set pwd [pwd]
    cd $::protest::sourceDirectory

    set code [catch {
	initDbg
	makeFile $nubScript $dummy

	# Load the fake project file, extract the app arguments from the
	# preferences and set the server listening on some random port.

	if {$::tcl_platform(platform) == "windows"} {
	    set exeFile ${exename}$::protest::currentVersion(Tcl-short)
	} else {
	    set exeFile ${exename}$::protest::currentVersion(Tcl)
	}
	initProject MyProject.tpj $dummy {} $::tcltest::temporaryDirectory \
		[findExeFile $exeFile]
	set interp [lindex [pref::prefGet appInterpList] 0]
	set dir    [lindex [pref::prefGet appDirList]    0]
	set script [lindex [pref::prefGet appScriptList] 0]
	set arg    [lindex [pref::prefGet appArgList]    0]
	set proj   [file tail [proj::getProjectPath]]
	dbg::setServerPort random

	# Now run the test script.
	set result [uplevel 1 $setupScript]
	
	# Start the application and wait for the "attach" event.
	dbg::start $interp $dir dummy.tcl $arg $proj
	waitForApp

	# Step to the first command of the script.
	dbg::step any
	waitForApp
	
	# Now run the test script.
	set result [uplevel 1 $testScript]
    } msg]

    quitDbg
    catch {file delete -force $dummy}
    cd $pwd
    if {$code} {
	error $msg $::errorInfo $::errorCode
    }
    return $result
}

# launchDbg --
#
#	Start the both the debugger and the application to debug.
#	Set up initial communication.
#
# Arguments:
#	app		Interpreter in which to run scriptFile.
#	port		Number of port on which to communicate.
#	scriptFile	File to debug.
#	verbose		Boolean that decides whether to log activity.
#
# Results:
#	Returns the PID of the application.

proc launchDbg {app scriptFile} {
    initDbg
    dbg::start $app $::tcltest::temporaryDirectory $scriptFile {} REMOTE
    waitForApp
    return
}

# eventProc --
#
#	The proc that is registered to execute when an event is triggered.
#	Sets the global variable Dbg_AppStopped to the event to trigger the
#	vwait called by the waitForAppp proc.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc eventProc {event args} {
    global Dbg_AppStopped
#    puts "EVENT - $event"
    set Dbg_AppStopped $event
    return
}

# waitForApp --
#
#	Call this proc after dbg::step, dbg::run, dbg::evaluate. Returns
#	when the global variable Dbg_AppStopped is set by the breakProc
#	or exitProc procedures.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc waitForApp {} {
    global Dbg_AppStopped
    vwait Dbg_AppStopped
    set ret $Dbg_AppStopped
    set Dbg_AppStopped "run"
    return $ret
}

