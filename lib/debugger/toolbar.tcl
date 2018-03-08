# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# toolbar.tcl --
#
#	This file implements the Tcl Debugger toolbar.
#
# Copyright (c) 1998-2000 Ajuba Solutions

# 
# RCS: @(#) $Id: toolbar.tcl,v 1.4 2000/10/31 23:31:01 welch Exp $

package require tooltip


namespace eval tool {
    # Array used to store handles to all of the toolbar buttons.

    variable tool

    # Store the top frame of the toolbar.

    variable toolbarFrm

    # Handle of active debugger object ...

    variable active {}

    # Array storing the toolbar state for all debugger objects.
    # Whenever the active object is switched this cache is the
    # source of the current state of all the toolbar buttons.

    variable  statecache
    array set statecache {}

    # Map from button names as used by the ui engines to the
    # index in the tool array (s.a.).

    variable  bmap
    array set bmap {
	refreshFile refreshFile  stepIn     into
	restart     restart      stepOut    out
	run         run          stepOver   over
	pause       pause        stepTo     to
	stop        stop         stepResult cmdresult
	inspector   inspector    showStack  stack
	closec      closec
    }
}

# tool::createWindow --
#
#	Load the button images, create the buttons and add the callbacks.
#
# Arguments:
#	mainDbgWin	The toplevel window for the main debugger.
#
# Results:
#	The handle to the frame that contains all of the toolbar buttons. 

proc tool::createWindow {mainDbgWin} {
    variable tool
    variable toolbarFrm

    set toolbarFrm [ttk::frame $mainDbgWin.tool]

    # Pack bottom separator first to stay on bottom
    pack [ttk::separator $toolbarFrm.sepBtm -orient horizontal] \
	-fill x -side bottom

    set tool(run) [tool::createButton $toolbarFrm.runButt $image::image(run)  \
	    {Run until break or EOF.} \
	    {maingui dbgrun}]
    set tool(into) [tool::createButton $toolbarFrm.intoButt $image::image(into) \
	    {Step into the next procedure.} \
	    {maingui dbgstep}]
    set tool(over) [tool::createButton $toolbarFrm.overButt $image::image(over) \
	    {Step over the next procedure.} \
	    {maingui dbgstepover}]
    set tool(out) [tool::createButton $toolbarFrm.outButt $image::image(out)  \
	    {Step out of the current procedure.} \
	    {maingui dbgstepout}]
    set tool(to) [tool::createButton $toolbarFrm.toButt $image::image(to)  \
	    {Run to cursor.} \
	    {maingui runTo}]
    set tool(cmdresult) [tool::createButton $toolbarFrm.cmdresultButt \
	    $image::image(cmdresult)  \
	    {Step to result of current command.} \
	    {maingui dbgstepcmdresult}]

    pack [ttk::separator $toolbarFrm.sep0 -orient vertical] \
	    -pady 2 -padx 2 -fill y -side left
    set tool(closec) [tool::createButton $toolbarFrm.closecButt \
	    $image::image(closec) \
	    {Close active debugger connection.} \
            {maingui closeDebugger}]

    pack [ttk::separator $toolbarFrm.sep1 -orient vertical] \
	    -pady 2 -padx 2 -fill y -side left
    set tool(pause) [tool::createButton $toolbarFrm.pauseButt $image::image(pause) \
	    {Pause at the next instrumented statement.} \
	    {maingui interrupt}]
    set tool(stop) [tool::createButton $toolbarFrm.stopButt $image::image(stop) \
	    {Stop the current application.} \
	    {maingui kill}]
    set tool(restart) [tool::createButton $toolbarFrm.restartButt \
	    $image::image(restart) \
	    {Restart the application.} \
            {maingui prRestartProj}]

    pack [ttk::separator $toolbarFrm.sep2 -orient vertical] \
	    -pady 2 -padx 2 -fill y -side left
    set tool(refreshFile) [tool::createButton $toolbarFrm.refreshFileButt \
	    $image::image(refreshFile) \
	    {Refresh the current file.} \
            {maingui refreshFile}]

    pack [ttk::separator $toolbarFrm.sep3 -orient vertical] \
	    -pady 2 -padx 2 -fill y -side left
    set tool(win_break) [tool::createButton $toolbarFrm.win_breakButt \
	    $image::image(win_break) \
	    {Display the Breakpoint Window.} \
	    {maingui bpShowWindow}]
    set tool(win_eval) [tool::createButton $toolbarFrm.win_evalButt \
	    $image::image(win_eval) \
	    {Display the Eval Console Window.} \
	    {maingui evalShowWindow}]
    set tool(win_proc) [tool::createButton $toolbarFrm.win_procButt \
	    $image::image(win_proc) \
	    {Display the Procedure Window.} \
	    {maingui procShowWindow}]
    set tool(win_watch) [tool::createButton $toolbarFrm.win_watchButt \
	    $image::image(win_watch) \
	    {Display the Watch Variables Window.} \
	    {maingui watchShowWindow}]

    return $toolbarFrm
}

# tool::addButton --
#
#	Append a new button at the end of the toolbar.
#
# Arguments:
#	name	The name of the button to create.
#	img	An image that has already beeen created.
#	txt 	Text to display in the help window.
#	cmd 	Command to execute when pressed.
#
# Results:
#	Returns the widget name for the button.

proc tool::addButton {name img txt cmd} {
    variable tool
    variable toolbarFrm
    
    set tool($name) [tool::createButton $toolbarFrm.$name $img $txt $cmd]
    return $tool($name)
}

# tool::createButton --
#
#	Create uniform toolbar buttons and add bindings.
#
# Arguments:
#	but	The name of the button to create.
#	img	An image that has already beeen created.
#	txt 	Text to display in the help window.
#	cmd 	Command to execute when pressed.
#	side 	The default is to add the on the left side of the
#		toolbar - you may pass right to pack from the other
#		side.
#
# Results:
#	The name of the button being created.

proc tool::createButton {but img txt cmd {side left}} {
    variable gui

    set but [ttk::button $but -style Slim.Toolbutton -image $img -command $cmd]
    pack $but -side $side -pady 2

    maingui registerStatusMessage $but $txt 5
    tooltip::tooltip $but $txt

    return $but
}

# tool::updateMessage --
#
#	Update the status message displayed based
#	on the state of the debugger.
#
# Arguments:
#	state	The new state of the debugger.
#
# Results:
#	None.

proc tool::updateMessage {o state} {
    variable tool
    variable active
    variable statecache

    # Remember the state for when this object becomes active.
    set statecache($o) $state

    # Influence the ui only if the calling object is active.
    if {$active ne $o} return

    # Override all of the <Enter> and <Leave> bindings and add the new
    # message to display for the help message.
    # XXX override with what code?  - JH

    switch -exact -- $state {
	new -
	parseError -
	stopped -
    	running {
	    maingui registerStatusMessage $tool(run) \
		    {Run until break or EOF.} 5
	    maingui registerStatusMessage $tool(into) \
		    {Step into the next procedure.} 5
	}
	dead {
	    maingui registerStatusMessage $tool(run) \
		    {Start app and run until break or EOF.} 5
	    maingui registerStatusMessage $tool(into) \
		    {Start app and step to first command.} 5
	}
	default {
	    error "Unknown state \"$state\": in tool::updateMessage"
	}
    }

    return
}

# tool::changeState --
#
#	Update the state of the Toolbar buttons.
#
# Arguments:
#	buttonList	Names of the buttons to re-configure.
#	state 		The state all buttons in buttonList
#			will be configure to.
#
# Results:
#	None.

proc tool::changeState {o buttonList state} {
    variable bmap

    foreach button $buttonList {
	if {[info exists bmap($button)]} {
	    tool::changeButtonState $o $bmap($button) $state
	} else {
	    error "Unknown toolbar item \"$button\": in tool::changeState"
	}
    }
}

# tool::changeButtonState --
#
#	Change the state of the button.
#
# Arguments:
#	but	Name of the button.
#	state	New state.
#
# Results:
#	None.

proc tool::changeButtonState {o but state} {
    variable tool
    variable active
    variable statecache

    # Remember the button state for when this object becomes active.
    set statecache($o,$but) $state

    ##puts "TOOL/CBS\t$o $but $state"

    # Influence the ui only if the calling object is active.
    if {$o ne $active} return

    ##puts "TOOL/CBS\tapply"

    $tool($but) configure -state $state
    if {$state eq "disabled"} {
	$tool($but) configure -image $image::image(${but}_disable)
    } else {
	$tool($but) configure -image $image::image($but)
    }
    return
}


proc tool::setActive {o} {
    variable active
    variable statecache

    set active $o

    foreach key [array names statecache $o,*] {
	foreach {_ button} [split $key ,] break
	set newstate $statecache($key)

	changeButtonState $o $button $newstate
    }

    if {[info exists statecache($o)]} {
	updateMessage $o $statecache($o)
    }
    return
}
