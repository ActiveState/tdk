# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# cgui.tcl --
#
#	Umbrella. Contains all UI objects related to a single
#	engine and the connection it handles.
#
# Copyright (c) 2003-2009 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: debugger.tcl.in,v 1.25 2001/02/09 07:52:48 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require stack      ;# Stack display
package require codeWin    ;# Code block display
package require connstatus ;# Connection status display
package require deferror   ;# Display for defered errors
package require parseerror ;# Display for parse errors (-> instrumentation)
package require rterror    ;# Display for runtime errors
package require icon       ;# Handling of icons in sidebars
package require bp         ;# Display of breakpoints
package require checker_bridge ;# Connectivity to bg linting.
package require checkWin   ;# Linter dialog
package require coverage   ;# Coverage data + dialog
package require evalWin    ;# Console
package require inspector  ;# Inspection of variables
package require procWin    ;# Procedure list
package require proj       ;# Project settings
package require projWin    ;# Project settings, dialog.
package require goto       ;# Jumping to code locations.
package require find       ;# Searching code
package require var        ;# Main variable display.
package require watch      ;# Variable watching
package require varCache   ;# Cache of var names & values; users: var, watch, stack
package require as::tdk::komodo

# ### ### ### ######### ######### #########
## Implementation

snit::widget ui_engine {

    # When the GUI state goes to running, clear out the Stack, Var,
    # Watch, and PC icon.  To reduce flickering, only do this after
    # <after Time>.  The afterID is the handle to the after event
    # so it can be canceled if the GUIs state changes before it fires.

    variable afterID
    variable msgAfterID

    # ### ### ### ######### ######### #########
    ## Connectivity to our engine ...

    variable     dbg
    variable     blk
    variable     filedb

    variable     engine {}
    option      -engine {}
    onconfigure -engine {value} {
	if {$value eq $engine} return
	$self ESetup $value
	return
    }
    oncget -engine {return $engine}

    method ESetup {value } {
	set engine $value
	if {$engine eq {}} {
	    set dbg    {}
	    set blk    {}
	    set filedb {}
	    return
	}
	set dbg    [$engine dbg]
	set blk    [$engine blk]
	set filedb [$engine fdb]
	$self Connect
	return
    }

    option      -coverage {}
    onconfigure -coverage {value} {
	switch -exact -- $value {
	    {} - none - coverage - profile {}
	    default {
		return -code error "Illegal value for -coverage: \"$value\""
	    }
	}

	# If value == {} use the project preferences to get the chosen
	# settings.

	if {$value == {}} {
	    set value [pref::prefGet coverage]
	    if {$value == {}} {set value none}
	}

	if {$value eq $options(-coverage)} return
	set options(-coverage) $value

	# Reconfigure components according to chosen settings.

	$dbg configure -coverage $value
	if {$value eq "none"} {
	    $codeDisplay configure -coverage 0
	} else {
	    $codeDisplay configure -coverage 1
	}
	return
    }
    method chgCoverage {} {
	$self configure -coverage {}
	return
    }

    option -onspawn {}

    option -title {}
    oncget -title {
	if {$options(-title) == {}} {
	    return [file tail [$proj getProjectPath]]
	} else {
	    return $options(-title)
	}
    }

    # Boolean flag. If set the ui_engine will not allow restarting
    # execution after it is dead. This is for sub-debugger where the
    # engine does not know how to actually launch the debugged
    # process. The flag is automatically set by 'spawnstart'.

    variable staydead 0


    # ### ### ### ######### ######### #########
    ## Connection to outer window

    delegate method * to gui
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	set gui $value
	return
    }
    method GSetup {value} {
	set gui $value
	return
    }

    # ### ### ### ######### ######### #########
    ## Initialization

    constructor {args} {
	set mykomodo [as::tdk::komodo ${selfns}::koedit]

	$self ESetup [from args -engine]
	$self GSetup [from args -gui]

	set icon      [icon      ${selfns}::icon]
	set bp        [bp        ${selfns}::bp]
	set checker   [checker   ${selfns}::checker]
	set chkwin    [checkWin  ${selfns}::checkWin]
	set evalwin   [evalWin   ${selfns}::evalWin -gui $win]
	set inspector [inspector ${selfns}::inspector]
	set procwin   [procWin   ${selfns}::procWin]
	set proj      [proj      ${selfns}::proj]
	set projwin   [projWin   ${selfns}::projWin]
	set gotowin   [goto      ${selfns}::goto]
	set findwin   [find      ${selfns}::find]
	set watch     [watch     ${selfns}::watch]
	set coverage  [coverage  ${selfns}::coverage]
	set vcache    [varCache  ${selfns}::vcache $dbg]

	$self initState
	$self BuildUI
	$self configurelist $args

	$icon      configure -gui  $win
	$bp        configure -gui  $win
	$checker   configure -gui  $win
	$chkwin    configure -gui  $win
	#$evalwin  configure
	$inspector configure -gui $win
	$procwin   configure -gui $win
	$proj      configure -gui $win
	$projwin   configure -gui $win
	$gotowin   configure -gui $win
	$findwin   configure -gui $win
	$watch     configure -gui $win
	$coverage  configure -gui $win

	$dbg       configure -eval $evalwin

	if {$options(-coverage) == {}} {
	    # We can't be sure if this the initial default, or was
	    # set during 'configurelist'. to be sure that the
	    # components are initialized correctly we reconfigure to
	    # none and then back to {} to get the correct project
	    # settings.

	    $self configure -coverage none -coverage {}
	}
	return
    }
    destructor {
	# Delete all the non-widget components.

	catch {rename $mykomodo  {}}
	catch {rename $icon      {}}
	catch {rename $bp        {}}
	catch {rename $checker   {}}
	catch {rename $chkwin    {}}
	catch {rename $evalwin   {}}
	catch {rename $inspector {}}
	catch {rename $procwin   {}}
	catch {rename $proj      {}}
	catch {rename $projwin   {}}
	catch {rename $gotowin   {}}
	catch {rename $findwin   {}}
	catch {rename $watch     {}}
	return
    }

    # ### ### ### ######### ######### #########
    # Stores the command to execute when the debugger attaches.

    variable attachCmd {}

    # Components

    variable mykomodo     {}
    variable stackDisplay {}
    variable codeDisplay  {}
    variable varDisplay   {}
    variable icon         {}
    variable bp           {}
    variable checker      {}
    variable chkwin       {}
    variable coverage     {}
    variable evalwin      {}
    variable inspector    {}
    variable procwin      {}
    variable proj         {}
    variable projwin      {}
    variable gotowin      {}
    variable watch        {}
    variable vcache       {}
    variable findwin      {}

    method mainFocus {} {$stackDisplay ourFocus}
    method stack     {} {return $stackDisplay}
    method code      {} {return $codeDisplay}
    method var       {} {return $varDisplay}
    method icon      {} {return $icon}
    method bp        {} {return $bp}
    method checker   {} {return $checker}
    method chkwin    {} {return $chkwin}
    method evalwin   {} {return $evalwin}
    method procwin   {} {return $procwin}
    method proj      {} {return $proj}
    method projwin   {} {return $projwin}
    method inspector {} {return $inspector}
    method watch     {} {return $watch}
    method vcache    {} {return $vcache}

    # ### ### ### ######### ######### #########

    method BuildUI {} {
	set maintags [list mainDbgWin$self mainDbgWin]

	ttk::panedwindow $win.vert -orient vertical
	ttk::panedwindow $win.data -orient horizontal

	# Create the Var Window.  The return of this call is the
	# handle to the frame of the Var Window.

	set stackDisplay $win.data.stack ; # Define for linkage
	set varDisplay   [var $win.data.var -gui $self]

	# Create the Stack Window.  The return of this call is the
	# handle to the frame of the Stack Window.

	set stackDisplay [stackWin $win.data.stack -gui $self]

	# Create the CodeView Window.  The return of this call is the
	# handle to the frame of the CodeView Window.

	set codeDisplay [codeWin $win.code -gui $self]

	$win.data add $stackDisplay -weight 1
	$win.data add $varDisplay -weight 2
	$win.vert add $win.data -weight 1
	$win.vert add $codeDisplay -weight 3

	pack $win.vert -side top -expand 1 -fill both

	# FIXME 
	#
	# The next command sets up the chain of events which restore
	# the panels of .vert and .data to their saved sizes, and also
	# the traces which save any changes in the panel sizes.
	#
	# - Wait for the megawidget frame to be mapped, call Watch...
	# - Defer a bit longer, call DoGeom.
	# - DoGeom reads the preferences (relative! locations),
	#   converts to absolute sash position based on actual widget
	#   geometry (winfo width/height). All the waiting is done to
	#   ensure that the width/height information is valid
	# - Tried to compute sash positions immediately, based on the
	#   req* data. This moves the sashs to left and up instead of the
	#   true positions they were at at the time of the save.

	bind $win <Map> [mymethod WatchGeometries]

	bind::addBindTags [$codeDisplay text] $maintags

	$stackDisplay configure -tags $maintags
	$varDisplay   configure -tags $maintags

	bind::commonBindings mainDbgWin$self [list \
		[$stackDisplay ourFocus] \
		[$varDisplay   ourFocus] \
		[$codeDisplay  text] \
		]
	return
    }

    method WatchGeometries {} {
	#puts watch
	bind $win <Map> {}
	after 10 [mymethod DoGeom]
    }
    method DoGeom {} {
	#puts do
	guiUtil::pwRestore $win.vert .33
	guiUtil::pwRestore $win.data .4

	bind $win.data.var   <Configure> [list guiUtil::pwSave $win.data]
	bind $win.data.stack <Configure> [list guiUtil::pwSave $win.vert]
	return
    }

    # ### ### ### ######### ######### #########

    method Connect {} {
	# Register events sent from the engine to the GUI.

	$dbg gui: $self

	$dbg register linebreak  [mymethod linebreakHandler]
	$dbg register varbreak   [mymethod varbreakHandler]
	$dbg register userbreak  [mymethod userbreakHandler]
	$dbg register cmdresult  [mymethod cmdresultHandler]
	$dbg register exit       [mymethod exitHandler]
	$dbg register error      [mymethod errorHandler]
	$dbg register result     [mymethod resultHandler]
	$dbg register attach     [mymethod attachHandler]
	$dbg register instrument [mymethod instrumentHandler]
	$dbg register stdin      [mymethod stdinHandler]

	# Bugzilla 37458. Handle time out of connect back. Non-attachment
	# of a started application.

	$dbg register attach-timeout [mymethod attachTimeoutHandler]

	# Bugzilla 19825 ... Register a handler to display errors
	# which are delivered after the fact (generated by the application
	# during the processing of a request made by the UI).

	$dbg register defered_error  [mymethod deferedErrorHandler]

	# Register the error handler for errors during instrumentation.

	$blk iErrorHandler [mymethod instrumentErrorHandler]

	$dbg configure -onspawn [mymethod HandleSpawn]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals ...

    method HandleSpawn {cmd detail} {
	# cmd in {request, error}
	# No handler, and request, deny sub-debugger.
	# No handler, and error, ignore.
	# Otherwise pass to handler

	if {$options(-onspawn) == {}} {return {}}
	return [eval [linsert $options(-onspawn) end $cmd $detail $self]]
    }

    # ### ### ### ######### ######### #########
    ## Handlers attached to the engine. S.a. 'setup'.

    # method linebreakHandler --
    #
    #	Update the debugger when a LBP is fired.  Store in the
    #	GUI that the break occured because of a LBP so the
    #	codeBar will draw the correct icon.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method linebreakHandler {args} {
	$self stoppedHandler line
	$self setStatusCurrent
	$codeDisplay focusCodeWin
	return
    }

    # method varbreakHandler --
    #
    #	Update the debugger when a VBP is fired.  Store in the
    #	GUI that the break occured because of a VBP so the
    #	codeBar will draw the correct icon.
    #
    # Arguments:
    #	var	The var that cused the break.
    #	type	The type of operation performed in the var (w,u,r)
    #	value	The current value of the variable.
    #	handle	The id of the breakpoint which triggered.
    #
    # Results:
    #	None.

    method varbreakHandler {var vtype value handle} {
	$self stoppedHandler var
	$gui setStatusMsg "variable breakpoint"
	$codeDisplay focusCodeWin
	return
    }

    # method userbreakHandler --
    #
    #	This handles a users call to "debugger_break" it is
    #	handled just like a line breakpoint - except that we
    #	also post a dialog box that denotes this type of break.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method userbreakHandler {args} {
	eval [linsert $args 0 $self linebreakHandler]

	set str [lindex $args 0]
	if {$str == ""} {
	    set msg "Script called debugger_break"
	} else {
	    set msg $str
	}

	tk_messageBox -type ok -title "User Break" \
		-message $msg -icon warning \
		-parent $win
	return
    }

    # method cmdresultHandler --
    #
    #	Update the display when the debugger stops at the end of a
    #	command with the result.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method cmdresultHandler {args} {
	$self stoppedHandler cmdresult
	$self setStatusCurrent
	$codeDisplay focusCodeWin
	return
    }

    # method exitHandler --
    #
    #	Callback executed when the nub sends an exit message.
    #	Re-initialize the state of the Debugger and clear all
    #	sub-windows.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method exitHandler {} {
	$self cancelAfterAll

	# Remote projects stay alive for further connections.
	if {[$proj isRemoteProj]} {
	    $projwin updatePort

	    # HACK:  This is a big hairy work around due to the fact that
	    # Windows does not recycle it's ports immediately.  If this
	    # is not done, it will appear as though another app is using 
	    # our port.

	    if {$::tcl_platform(platform) == "windows"} {
		after 300
	    }
	    $proj initPort
	}
	$self changeState dead
	$codeDisplay updateCodeBar

	# Update the highlight ranges upon exit too, to be as current
	# as possible. Note however that we may have no block to
	# update, as the selection in the stack display can be on a
	# frame without code (uplevel, or global, or ...). Therefore
	# check this too before trying to access the block information.

	# And when we do remote debugging the block reference may not
	# be empty, but refer to a dynamic block, and these blocks are
	# gone when we come here. So check for that as well.

	if {
	    [$codeDisplay cget -coverage] &&
	    ([$self getCurrentBlock] ne "") &&
	    [$blk exists [$self getCurrentBlock]]
	} {
	    [$codeDisplay cget -coverobj] highlightRanges \
		[$self getCurrentBlock]
	}

	$self resetWindow  "end of script..."
	$gui  setStatusMsg "end of script..."
	$self updateStatusFile
	$gui  showMainWindow ;# May need tweaking if there is more than one connection.

	# If an auto-kill is set for the project, then
	# invoke it now, with a bit of an delay.

	if {$staydead && [pref::prefGet autoKillSub]} {
	    $gui Activate $self
	    $gui closeDebugger
	}
	return
    }

    # method errorHandler --
    #
    #	Show the error message in the error window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method errorHandler {errMsg errStk errCode uncaught} {
	$self stoppedHandler error
	$gui setStatusMsg   "error"

	$self showErrorWindow [$dbg getLevel] [$dbg getPC] \
		$errMsg $errStk $errCode $uncaught
	return
    }

    # method resultHandler --
    #
    #	Callback executed when the nub sends a result message.
    #	Notify the Eval Window of the result and update the
    #	variable windows in case the eval changed the var frames.
    #
    # Arguments:
    #	code		A standard Tcl result code for the evaled cmd.
    #	result		A value od the result for the evaled cmd.
    #	errCode		A standard Tcl errorCode for the evaled cmd.
    #	errInfo		A standard Tcl errorInfo for the evaled cmd.
    #
    # Results:
    #	None.

    method resultHandler {id code result errCode errInfo} {
	$self    cancelAfter
	$evalwin evalResult $id $code $result $errCode $errInfo

	$filedb update
	$self setCurrentBreak result
	$self changeState stopped

	$gui  setStatusMsg "eval result"
	$self afterMsg [mymethod setStatusCurrent]
	return
    }

    # method attachHandler --
    #
    #	An application has attached itself to the debugger.
    #	This event occurs if the application was started
    #	from the GUI or attached remotely.
    #
    # Arguments:
    #	projName	The name of the project.
    #
    # Results:
    #	None.

    method attachHandler {projName} {
	# Update the state in an after event, because there
	# may be events that will "immediately" cancel this
	# event.

	$self changeState running

	$self after    [mymethod attachHandlerAfter]
	$self afterMsg [mymethod attachHandlerMsgAfter $projName]
	return
    }
    method attachHandlerMsgAfter {projName} {
	$self setStatusMsg "[list $projName] application attached"
	return
    }
    method attachHandlerAfter {} {
	if {[$proj isRemoteProj]} {
	    $self run [list $dbg step any]
	} else {
	    $self run $attachCmd
	}
	set attachCmd {}
	return
    }


    # method attachTimeoutHandler --
    #

    #	An application has not attached itself to the debugger within
    #	n Seconds. The event occurs when the application was started
    #	from the GUI and fails somehow. Like a firewall blocking this
    #   local connection.
    #
    # Arguments:
    #	projName	The name of the project.
    #
    # Results:
    #	None.

    method attachTimeoutHandler {projName} {

	$self changeState dead
	$self setStatusMsg "[list $projName] application failed to attach"

	# Pop up a dialog notifying the user of the problem, with
	# suggestions about the cause.

	tk_messageBox -icon error -type ok \
	    -title {Connection error} \
	    -parent [$self getParent] \
	    -message "The application launched for project \
                      \"$projName\" failed to connect back to \
                      the debugger.\n\nDebugging is not \
                      possible.\n\nOne possible cause for this \
                      to happen are overly restrictive firewall \
                      settings on the current host preventing \
                      the launched process from making the \
                      connection."
	return
    }


    # method instrumentHandler --
    #
    #	Update Status Bar and Code Window before and after
    #	a file is instrumented.
    #
    # Arguments:
    #	status		Specifies if the file is starting to be instrumented
    #			or finshed being instrumented ("start" or "end".)
    #	blk		The block being instrumented.
    #
    # Results:
    #	None.

    method instrumentHandler {status block} {
	# Cancel any after events relating to message updates.
	# This is to prevent flicker or clobbering of more
	# current messages.

	$self cancelAfterMsg

	if {$status == "start"} {
	    $gui setStatusMsg "instrumenting [$blk getFile $block]"
	} else {
	    # We run the following code in an after event to avoid
	    # unnecessary updates in the case of queued events.  The
	    # following script will update the status bar and the
	    # code window if the file being instrument was the one
	    # we are currently displaying.

	    $self afterMsg [mymethod setStatusCurrent]
	    if {[$self getCurrentBlock] == $block} {
		$codeDisplay updateCodeBar
	    }
	}
	return
    }

    # method stdinHandler --
    #
    #	Update the debugger when the application request input
    #	on stdin.  Store in the GUI that the break occured
    #	because of a LBP so the codeBar will draw the correct
    #	icon.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method stdinHandler {args} {
	# Have the frontend show where the command requesting
	# user input is in the code. Like for breakpoints.

	$self stoppedHandler line

	# The application is actually not stopped as stoppedHandler above
	# sets it to be, but we had to pretend this for a while up here in
	# the frontend. Now we set the true state back into the UI.

	$self changeState running
	$self setStatusCurrent
	$codeDisplay focusCodeWin
	return
    }

    # Bugzilla 19825 ...
    # method deferedErrorHandler --
    #
    #	Show the error message in the error window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method deferedErrorHandler {errordata} {
	$gui setStatusMsg "defered error"
	$self showDeferedErrorWindow $errordata
	return
    }

    # method instrumentErrorHandler --
    #
    #	An error occured during Instrumentation.  Show the error
    #	and display the error message.  The user can choose from
    #	one of three options:
    #	  1) Instrument as much of the file as possible.
    #	  2) Do not instrument the file
    #	  3) Kill the running application.
    #
    # Arguments:
    #	loc	The location of the error.
    #
    # Results:
    #	Return 1 if the file should be instrumented as much as
    #	possible, or 0 if the file should not be instrumented.

    method instrumentErrorHandler {loc ec} {

	# Bugzilla 19824 ...
	set blktitle [$blk title [loc::getBlock $loc]]

	set errorMsg [lindex $ec end]
	$self cancelAfter
	$self resetWindow

	set oldState [$self getCurrentState]
	$self setCurrentBreak error
	$self changeState parseError
	$self showCode $loc
	$gui  setStatusMsg "parse error"

	$self showParseErrorWindow $errorMsg $blktitle
	vwait [varname parseErrorVar]
	$self changeState $oldState
	switch $parseErrorVar {
	    cont {
		return 1
	    }
	    dont {
		return 0
	    }
	    kill {
		after 1 [list catch [list $dbg kill]]
		return 0
	    }
	}
    }

    # method stoppedHandler --
    #
    #	Update the debugger when the app stops.
    #
    # Arguments:
    #	breakType	Store the reason for the break (result, line, var...)
    #
    # Results:
    #	None.

    method stoppedHandler {breakType} {
	$self cancelAfterAll
	$filedb update
	$self setCurrentBreak $breakType
	$self changeState stopped
	$self showCode [$dbg getPC]
	result::updateWindow $dbg
	$bp updateWindow
	$self showMainWindow
	$dbg Log timing {$self stoppedHandler $breakType}
	return
    }

    # ### ### ### ######### ######### #########
    ## ...

    # method showCode --
    #
    #	Update the Code Window, CodeBar and Status message
    #	without affecting the other windows.
    #
    # Arguments:
    #	loc	The location opaque type that contains the
    #		block of code to view and the line number
    #		within the body to see.
    #
    # Results:
    #	None.

    method showCode {loc} {
	$codeDisplay updateWindow $loc
	$codeDisplay updateCodeBar
	$self updateStatusFile
	$filedb pushBlock [loc::getBlock $loc]
	return
    }

    # ### ### ### ######### ######### #########
    ## Actions: Stepping the debugee.

    # method quit --
    #
    #	Wrapper around the $dbg quit command that removes the file caching
    #	since the $dbg quit command destroys all blocks.
    #
    # Arguments:
    #	how	Possible values are ask, kill, run
    #		Determines if the debugged application
    #		is killed with the frontend, or detached
    #		from it. -- Bugzilla 42273.
    #
    # Results:
    #	None.

    method quit {how} {
	if {
	    ([$self getCurrentState] ne "dead") &&
	    ([$self getCurrentState] ne "new")
	} {
	    # Bugzilla 42273. Query user for the choice between kill
	    # and detach, if so commanded by the
	    # preferences. Afterward the value of how is in {kill,
	    # run}.

	    if {$how eq "ask"} {
		set but [tk_messageBox -icon question -type yesno \
			     -title "Question" -parent [$self getParent] \
			     -message "Do you wish to kill the running application ?"]

		set how [expr {($but eq "yes") ? "kill" : "run"}]
	    }
	} else {
	    set how kill
	}

	# Releases all blocks.
	if {$how eq "kill"} {
	    $dbg quit
	} else {
	    $dbg detach
	}
	$filedb update 1

	# Bugzilla 40594.
	# The quit call into the low-level engine above releases all
	# blocks we have known. This forces us to reset our knowledge
	# of the current block as well, otherwise other subsystems may
	# be faked into trying to access a block which does not exist
	# anymore.

	$self   setCurrentBlock {}
	$self   setCurrentFile  {}
	$self   setCurrentLine  {}
	$self   updateStatusFile

	# Bugzilla 19619 ... clear out cached coverage information too, as
	# it contains now outdated block references.

	if {$coverage != {}} {
	    $coverage clearCoverageArray
	}
	return
    }

    # method start --
    #
    #	This routine verifies the project arguments, initializes the port,
    #	starts the application, and then sets the command to call when the
    #	nub attaches to the debugger.
    #
    #
    # Arguments:
    #	cmd	The actual command that will cause the engine
    #		to start running again.
    #
    # Results:
    #	Return a boolean, 1 means that the start was successful, 0 means
    #	the application could not be started.

    method start {cmd} {
	if {[$proj isRemoteProj]} {
	    set attachCmd [list $dbg step any]
	    set result 1
	} else {
	    if {![$proj checkProj]} {
		return 0
	    }

	    # Bugzilla 19617 ... Use the appInterp preference, and not the
	    # contents of the list of all interp's. The Bwidget comboxes
	    # do not update this list to have the selected value as first
	    # item in the list.

	    set interp   [pref::prefGet appInterp] ;#[lindex [pref::prefGet appInterpList] 0]
	    set projfile [file tail [$proj getProjectPath]]

	    # Bugzilla 19700 ... Different symptom, same root cause, see
	    # explanation regarding 19617 above.

	    set script [pref::prefGet appScript] ;#[lindex [pref::prefGet appScriptList] 0]
	    set dir    [pref::prefGet appDir]    ;#[lindex [pref::prefGet appDirList]    0]
	    set arg    [pref::prefGet appArg]    ;#[lindex [pref::prefGet appArgList]    0]
	    set iparg  [pref::prefGet appInterpArg]

	    # Make the starting directory relative to the path of the project
	    # file. If the script path is absolute, then the join does nothing.
	    # Otherwise, the starting dir is relative from the project directory.
	    
	    if {![$proj projectNeverSaved]} {
		set dir [file join [file dirname [$proj getProjectPath]] $dir]
	    }

	    # Make sure the script path is absolute so we can source 
	    # relative paths.  File joining the dir with the script 
	    # will give us an abs path.

	    set script [file join $dir $script]

	    if {![$dbg setServerPort random]} {
		# The following error should never occur.  It would mean that
		# the "random" option of setServerPort was somehow broken or
		# there were real network problems (like no socket support?).

		tk_messageBox -icon error -type ok \
			-title "Network error" \
			-parent [$self getParent] -message \
			"Could not find valid port."
		return 0
	    }

	    if {$coverage != {} && [$coverage hasCoverage]} {
		# In a coverage enabled debugger we have to ask if
		# the user wishes us to clear the existing coverage
		# data (if any).

		set res [tk_messageBox -icon question -type yesno \
			-title "Code Coverage & Profiling" \
			-parent [$self getParent] -message \
			"Do you wish to clear the coverage and\
			profiling information retained from the\
			last session ?"]
		if {[string equal $res yes]} {
		    $coverage clearAllCoverage
		}
	    }

	    # If there is an error loading the script, display the
	    # error message in a tk_message box and return.

	    if {[catch {$dbg start $interp $iparg $dir $script $arg $projfile} msg]} {
		tk_messageBox -icon error -type ok \
			-title "Application Initialization Error" \
			-parent [$self getParent] -message $msg
		set result 0
	    } else {
		# Set the attach command that gets called when the nub signals
		# that it has attached.  Convert the "run" or "step" requests
		# to commands that do not require a location.

		if {$cmd eq [list $dbg run]} {
		    set cmd [list $dbg step run]
		} elseif {$cmd eq [list $dbg step]} {
		    set cmd [list $dbg step any]
		}
		set attachCmd $cmd

		set result 1
	    }
	}
	return $result
    }

    # method spawnstart --
    #
    #	This is similar to 'start', i.e. setting up the engine for
    #	a process to debug. In constrast to start however this
    #	routine does not launch the process by itself, but assumes
    #	that the process is launched at some other place. For
    #   example in a process already under debug, or a child
    #   thereof. As this launch is not completely under the control
    #	of the frontend we hardwire the command which is called when
    #   the new nub attaches to the debugger.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #   Returns the port the new debugger is listening on.

    method spawnstart {} {
	set staydead 1
	if {![$dbg setServerPort random]} {
	    # The following error should never occur.  It would mean that
	    # the "random" option of setServerPort was somehow broken or
	    # there were real network problems (like no socket support?).

	    tk_messageBox -icon error -type ok \
		    -title "Network error" \
		    -parent [$self getParent] -message \
		    "Could not find valid port."
	    return {}
	}

	set attachCmd [list $dbg step any]
	return [$dbg getServerPort]
    }

    # method run --
    #
    #	Wrapper function around any command that changes the engine
    #	to "running", (e.g. $dbg run and $dbg step).  The GUI needs
    #	to update itself so it is in sync with the engine.
    #
    # Arguments:
    #	cmd	The actual command that will cause the engine
    #		to start running again.
    #
    # Results:
    #	The result of evaluating the cmd.

    method run {cmd} {
	$dbg Log timing {$self run $cmd}

	# Dismiss the error dialog and take the default action

	if {[winfo exists [$self errorDbgWin]]} {
	    [$self errorDbgWin] handleError
	}

	# If the current state is dead, we need to verify the app arguments
	# are valid, and start the application.  If any of these steps fail,
	# simply return.  If all steps succeed, set the gui state to running
	# and return.  When the nub connects, the step will be evaluated.

	if {[$self getCurrentState] == "dead"} {
	    $self start $cmd
	    return
	}

	$self setCurrentBreak {}
	$self changeState running

	## This code blanks the session window if the backend does not
	## report back within 500 milliseconds, i.e. half a
	## second. This means that the location marker vanishes and
	## both stack and variable windows become empty.

	$self after    [mymethod runAfter]
	$self afterMsg [list $gui setStatusMsg "running"]
	return [eval $cmd]
    }
    method runAfter {} {
	## Blanking out the interface if the backend runs longer than
	## [$gui afterTime]
	##
	##$stackDisplay resetWindow {}
	##$varDisplay   resetWindow {}
	##$codeDisplay  resetWindow {}
	##$evalwin      resetWindow {}

	## Keeping as much in the display as possible now.
	##
	##$stackDisplay resetWindow {}
	##$varDisplay   resetWindow {}
	$codeDisplay  changeFocus out ; # Highlighting etc. are kepty.
	$evalwin      resetWindow {}  ; # Disable.
	return
    }

    # method runTo --
    #
    #	Instruct the debugger to run to the current insert point.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method runTo {} {
	set loc [$codeDisplay makeCodeLocation \
		[$codeDisplay text] [$codeDisplay getInsertLine].0]
	$self run [list $dbg run $loc]
	return
    }

    # method kill --
    #
    #	Update the Debugger when the debugged app is killed.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns 0 if we actually killed the application,
    #	returns 1 if the user canceled this action.

    method kill {} {
	$self cancelAfter
	set appstate [$self getCurrentState]

	# We don't need to kill it if it isn't running.  Also, we
	# need to check with the user to see if we want to kill.

	if {($appstate == "dead") || ($appstate == "new")} {
	    return 0
	}
	if {[$self askToKill]} {
	    return 1
	}

	# Kill the debugger engine and update various GUI state
	# to reflect the change.

	$dbg kill

	# Due to the auto-kill feature the window may be gone by
	# now. If so no further interaction is possible.

	if {![winfo exists $win]} {return 0}

	$self setCurrentBreak {}
	$filedb update 1
	if {[$proj isRemoteProj]} {
	    $proj initPort
	}
	$self changeState dead
	$self resetWindow "script killed..."
	$gui setStatusMsg "script killed"
	return 0
    }

    # method interrupt --
    #
    #	Update the Debugger when an interrupt is requested.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method interrupt {} {
	if {[$self getCurrentState] == "running"} {
	    $gui setStatusMsg "interrupt pending"
	    $dbg interrupt
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## State information

    #     currentArgs 		The cached value of the args, updated on
    #				every call to --> var/updateWindow.
    #     currentBlock  	The current block being displayed in the
    #				code window.  Updated on calls to
    #				code -> updateWindow.
    #     currentBreak  	The current type break (LBP vs. VBP)
    #				Updated on breakpoint event handlers.
    #     currentFile 	 	The current file being displayed in the
    #				code window.  Updated on calls to
    #				code -> updateWindow.
    #     currentLevel 		The cached value of the level, updated on
    #				every call to  --> var/updateWindow and
    #				-> changeState.
    #     currentLine 	 	The current line being displayed in the
    #				code window.  Updated on calls to
    #				code -> updateWindow.
    #     currentProc 		The cached value of the proc name, updated
    #				on every call to stack -> updateWindow.
    #     currentScope 		The cached value of the proc name, or type
    #				on every call to stack -> updateWindow.
    #     currentState 		The cached value of the GUI state.
    #				Either new, running, stopped or dead. Updated
    #				on every call to -> changeState.
    #     currentType 		The cached value of the stack type, updated
    #				on every call to var -> updateWindow.
    #     currentVer 		The cached value of the block version, updated
    #				on every call to code -> updateWindow.

    # Initialize all of the state variables to null.

    variable state

    method initState {} {
	# Initialize all of the state variables to null.
	set state(currentArgs)    {}
	set state(currentBlock)   {}
	set state(currentBreak)   {}
	set state(currentFile)    {}
	set state(currentLevel)   {}
	set state(currentLine)    {}
	set state(currentPC)      {}
	set state(currentProc)    {}
	set state(currentScope)   {}
	set state(currentState)   {}
	set state(currentType)    {}
	set state(currentVer)     {}
	set state(evalLevelVar)   {}
	return
    }

    #-----------------------------------------------------------------------------
    # APIs for manipulating GUI state data.
    #-----------------------------------------------------------------------------

    # method getCurrentBreak --
    #
    #	Set or return the break type.
    #
    # Arguments:
    #	type	The type of break that just occured.
    #
    # Results:
    # 	Either line, var, error or cmdresult.

    method getCurrentBreak {} {
	return $state(currentBreak)
    }

    method setCurrentBreak {btype} {
	set state(currentBreak) $btype
    }

    # method getCurrentArgs --
    #
    #	Set or return any args passed to the proc at
    #	the current stack.
    #
    # Arguments:
    #	argList		The list of args passed to the proc.
    #
    # Results:
    #	The current args or empty string if none exists.

    method getCurrentArgs {} {
	return $state(currentArgs)
    }

    method setCurrentArgs {argList} {
	set state(currentArgs) $argList
    }

    # method getCurrentBlock --
    #
    #	Set or return any args passed to the proc at
    #	the current stack.
    #
    # Arguments:
    #	blk	The new block being displayed.
    #
    # Results:
    #	The current args or empty string if none exists.

    method getCurrentBlock {} {
	return $state(currentBlock)
    }

    method setCurrentBlock {block} {
	set state(currentBlock) $block
    }

    # method getCurrentFile --
    #
    #	Set or return any args passed to the proc
    #	at the current stack.
    #
    # Arguments:
    #	file 	The name of the file being displayed.
    #
    # Results:
    #	The current args or empty string if none exists.

    method getCurrentFile {} {
	return $state(currentFile)
    }

    method setCurrentFile {file} {
	set state(currentFile) $file
    }

    # method getCurrentLevel --
    #
    #	Set or return the currently displayed stack level.
    #
    # Arguments:
    #	level	The new stack level.
    #
    # Results:
    #	The current stack level or empty string if none exists.

    method getCurrentLevel {} {
	return $state(currentLevel)
    }

    method setCurrentLevel {level} {
	set state(currentLevel) $level
    }

    # method getCurrentLine --
    #
    #	Set or return the current line in the displayed body of code
    #
    # Arguments:
    #	line	The new line number in the block being displayed.
    #
    # Results:
    #	The current line or empty string if none exists.

    method getCurrentLine {} {
	return $state(currentLine)
    }

    method setCurrentLine {line} {
	set state(currentLine) $line
    }

    # method getCurrentPC --
    #
    #	Set or return the current PC of the engine.
    #
    # Arguments:
    #	pc	The new engine PC.
    #
    # Results:
    #	The current PC location.

    method getCurrentPC {} {
	return $state(currentPC)
    }

    method setCurrentPC {pc} {
	set state(currentPC) $pc
    }

    # method getCurrentProc --
    #
    #	Set or return the current proc name.  If the current
    #	type is "proc" then this will contain the proc name
    #	of the currently displayed stack.
    #
    # Arguments:
    #	procName 	The new proc name.
    #
    # Results:
    #	The current proc name or empty string if none exists.

    method getCurrentProc {} {
	return $state(currentProc)
    }

    method setCurrentProc {procName} {
	set state(currentProc) $procName
    }

    # method getCurrentScope --
    #
    #	Set or return the current scope of the level.  If we
    #	are in a proc this will return the proc name, otherwise
    #	it returns the type (e.g.. global, source etc.)
    #
    # Arguments:
    #	scope	The new GUI scope.
    #
    # Results:
    #	The current scope.

    method getCurrentScope {} {
	return $state(currentScope)
    }

    method setCurrentScope {scope} {
	set state(currentScope) $scope
    }

    # method getCurrentState --
    #
    #	Set or return the current state of the GUI.
    #
    # Arguments:
    #	state	The new GUI state.
    #
    # Results:
    #	The current state.

    method getCurrentState {} {
	return $state(currentState)
    }

    method setCurrentState {newstate} {
	set state(currentState) $newstate
    }

    # method getCurrentType --
    #
    # 	Set or return the currently displayed stack type;
    #	either the string "global" if the scope is global
    #	or the the string "proc" if the stack is in a procedure.
    #
    # Arguments:
    #	type	The new Stack type (proc, global, etc.)
    #
    # Results:
    #	The current stack type or empty string if none exists.

    method getCurrentType {} {
	return $state(currentType)
    }

    method setCurrentType {stype} {
	set state(currentType) $stype
    }

    # method getCurrentVer --
    #
    #	Set or return the current version of the
    #	block being displayed.
    #
    # Arguments:
    #	None
    #
    # Results:
    #	The current block version.

    method getCurrentVer {} {
	return $state(currentVer)
    }

    method setCurrentVer {ver} {
	set state(currentVer) $ver
    }

    # ### ### ### ######### ######### #########

    # method resetWindow --
    #
    #	Reset the Debugger to it's start-up state.  Clear all of
    #	the sub-windows and unset the local cache of the current
    #	debugger state.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method resetWindow {{msg {}}} {
	$self setCurrentArgs  {}
	$self setCurrentBreak {}
	$self setCurrentLevel {}
	$self setCurrentPC    {}
	$self setCurrentProc  {}
	$self setCurrentScope {}
	$self setCurrentType  {}

	# If the error window is present, remove it.

	if {[winfo exists [$self errorDbgWin]]} {
	    destroy [$self errorDbgWin]
	}

	$stackDisplay resetWindow $msg
	$varDisplay   resetWindow $msg
	result::resetWindow

	# Check to see if the current block has been deleted
	# (i.e. a dynamic block)

	if {![$blk exists [$self getCurrentBlock]]} {
	    $codeDisplay resetWindow " "
	    $self setCurrentBlock {}
	    $self setCurrentFile  {}
	    $self setCurrentLine  {}
	    $self updateStatusFile
	} else {
	    $codeDisplay resetWindow {}
	}
	# Remove cached blocks
	$filedb update 1

	focus [$stackDisplay ourFocus]
	return
    }

    # method changeState --
    #
    #	This is the state management routine.  Whenever there is
    # 	a change of state (new, running, stopped or dead) this
    #	routine updates the menu , toolbar and any bindings.
    #
    # Arguments:
    #	newstate	The new state of the GUI.
    #
    # Results:
    #	None.

    method changeState {newstate} {
	$self setCurrentState $newstate

	switch -exact -- $newstate {
	    new {
		tool::changeState $self {
		    run stepIn stepOut stepOver stepTo stepResult pause stop restart
		    closec
		} disabled ;# ---- {}

		# Bugzilla 27994 - When disabling most of the Keyboard
		# we have to keep the keyboard shortcuts active, hence
		# we add a mainDbgWin before disableKeys. Note that we
		# are going through the menu items when activating
		# stuff by keyboard shortcut. This means that the
		# state of the menu ensures that unuseable functions
		# are off. IOW allowing these keyboard events is
		# safe. And not allowing them will deactivate a number
		# of general shortcuts like Help, which makes not
		# really sense.

		if {![bind::tagExists [$stackDisplay ourFocus] disableButtons]} {
		    set xtags [list mainDbgWin$self mainDbgWin disableKeys disableButtons]

		    $stackDisplay configure -tags $xtags
		    $varDisplay   configure -tags $xtags
		}

		$gui setState $self stopped
	    }
	    parseError {
		tool::changeState $self {
		    run stepIn stepOut stepOver stepTo stepResult pause stop restart
		} disabled ;# ---- {}

		if {![bind::tagExists [$stackDisplay ourFocus] disableButtons]} {
		    set xtags [list mainDbgWin$self mainDbgWin disableKeys disableButtons]

		    $stackDisplay configure -tags $xtags
		    $varDisplay   configure -tags $xtags
		}

		$gui setState $self error
	    }
	    stopped {
		tool::changeState $self {pause} disabled
		tool::changeState $self {
		    run stepIn stepOut stepOver stepTo stepResult stop restart
		} normal ;# ---- {}

		$self setCurrentPC    [$dbg getPC]
		$self setCurrentLevel [$dbg getLevel]

		# If the app is connected remotely, disable the restart
		# button because it will restart the wrong project.

		if {[$proj isRemoteProj] || $staydead} {
                    # Bugzilla 30651. For an engine activated via
		    # 'spawnstart' we are not able to restart the
		    # process in any way, so we disable that operation.
		    tool::changeState $self restart disabled
		}

		if {[bind::tagExists [$stackDisplay ourFocus] disableButtons]} {
		    $stackDisplay configure -tags {}
		    $varDisplay   configure -tags {}
		}

		$vcache       reset
		$stackDisplay updateWindow [$dbg getLevel]
		$varDisplay   updateWindow

		$gui setState $self stopped/[$self getCurrentBreak]
	    }
	    running {
		$self setCurrentPC {}

		tool::changeState $self {
		    run stepIn stepOut stepOver stepTo stepResult
		} disabled ;# ---- {}
		tool::changeState $self {pause stop restart} normal

		# If the app is connected remotely, disable the restart
		# button because it will restart the wrong project.

		if {[$proj isRemoteProj] || $staydead} {
                    # Bugzilla 30651. For an engine activated via
		    # 'spawnstart' we are not able to restart the
		    # process in any way, so we disable that operation.
		    tool::changeState $self restart disabled
		}

		if {![bind::tagExists [$stackDisplay ourFocus] disableButtons]} {
		    set xtags [list mainDbgWin$self mainDbgWin disableKeys disableButtons]

		    $stackDisplay configure -tags $xtags
		    $varDisplay   configure -tags $xtags
		}

		$gui setState $self running
	    }
	    dead {
		$self setCurrentPC {}
		$bp   updateWindow

		if {[$proj isRemoteProj]} {
		    tool::changeState $self {run stepIn} disabled
		} else {
		    tool::changeState $self {run stepIn} normal
		}
		tool::changeState $self {
		    stepOut stepOver stepTo stepResult pause stop restart
		} disabled ;# ---- {}

		if {$staydead} {
		    # For an engine activated via 'spawnstart' we are
		    # not able to restart the process in any way, so we
		    # disable these operations too. This also allows
		    # the destruction of ourselves.

		    tool::changeState $self {
			run stepIn 
		    } disabled ;# ---- {}

		    tool::changeState $self {
			closec
		    } normal ;# ---- {}
		}

		if {![bind::tagExists [$stackDisplay ourFocus] disableButtons]} {
		    set xtags [list mainDbgWin$self mainDbgWin disableKeys disableButtons]

		    $stackDisplay configure -tags $xtags
		    $varDisplay   configure -tags $xtags
		}

		$gui setState $self dead
	    }
	    default {
		error "Unknown state \"$newstate\": in $self changeState proc"
	    }
	}

	# Enable the refresh button if the current block is associated
	# with a file that is currently not instrumented, or if the
	# session is dead. Bug 71629.

	if {
	    ([$self getCurrentFile] == {}) ||
	    (($newstate ne "dead") &&
	     ([$blk isInstrumented [$self getCurrentBlock]]))
	} {
	    tool::changeState $self {refreshFile} disabled
	} else {
	    # We have a file, it is either not instrumented, or the
	    # system is 'dead' = no session active.
	    tool::changeState $self {refreshFile} normal
	}

	tool::updateMessage $self $newstate
	$watch   updateWindow
	$evalwin updateWindow
	$procwin updateWindow

	# If coverage is on, update the coverage window

	if {$coverage != {}} {
	    $coverage updateWindow
	}

	$inspector updateWindow
	$projwin   updateWindow
	$self      showConnectStatus update
    }

    # Bugzilla 42273. Clarification.
    #
    # The method 'askToKill' below is the dialog associated with the
    # preference key 'warnOnKill'. It warns the user when he is about
    # to kill the debugged application.

    # method askToKill --
    #
    #	Popup a dialog box that warns the user that their requested
    #	action is destructive.  If the current GUI state is "running"
    #	or "stopped", then certain actions will terminate the debugged
    #	application (e.g. kill, restart, etc.)
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns 0 if it is OK to continue or 1 if the action
    #	should be terminated.

    method askToKill {} {
	if {[pref::prefGet warnOnKill] == 0} {
	    return 0
	}

	set appstate [$self getCurrentState]
	if {($appstate == "stopped") || ($appstate == "running")} {
	    set but [tk_messageBox -icon warning -type okcancel \
		    -title "Warning" -parent [$self getParent] \
		    -message "This command will kill the running application."]
	    if {$but == "cancel"} {
		return 1
	    }
	}
	return 0
    }

    # method updateStatusFile --
    #
    #	Set file and line info in the Status window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateStatusFile {} {
	# Remove the existing text and any data stored
	# in the format database.

	$gui clearStatusFile

	if {[$self getCurrentState] == "new"} return

	set   block [$self getCurrentBlock]
	if {($block != {}) && ([$blk exists $block])} {
	    set inst [$blk isInstrumented $block]
	} else {
	    set inst 0
	}

	$gui updateStatusInstrumentFlag $inst

	set  file [$self getCurrentFile]
	if {$file == {}} {set file "<Dynamic Block>"}
	set line [$codeDisplay getInsertLine]

	# Enable the refresh button if the current block is associated
	# with a file that is currently not instrumented, or if the
	# session is dead. Bug 71629.

	set dead [expr {[$self getCurrentState] eq "dead"}]

	if {($file == {}) || (!$dead && $inst)} {
	    tool::changeState $self {refreshFile} disabled
	} else {
	    tool::changeState $self {refreshFile} normal
	}

	$gui updateStatusFile $file $line
	return
    }

    # ### ### ### ######### ######### #########

    #-----------------------------------------------------------------------------
    # Sub dialog for the display of connection status information ...
    #-----------------------------------------------------------------------------

    # method showConnectStatus --
    #
    #	This command creates a new window that shows the status of
    #	connection to the debugged application.
    #
    # Arguments:
    #	update	(Optional) Use this when you want to update values
    #		(it will only update the window if the window has
    #		been created).  If the update argument is not given
    #		then we create the connection status window.
    #
    # Results:
    #	None.  A new window will be created (or updated).

    method showConnectStatus {{update {}}} {
	set w $win.connectStatus

	set createWindow 1
	if {[winfo exists $w]} {set createWindow 0}

	if {$update != ""} {
	    # Update case: Don't update values if window doesn't exist

	    if {$createWindow} return
	} else {
	    # Create case: if window exists raise it to the top

	    if {! $createWindow} {raise $w}
	}

	if {$createWindow} {
	    connstatus $w $self
	}

	$w update
	return
    }

    # ### ### ### ######### ######### #########

    #-----------------------------------------------------------------------------
    # Sub dialog for the display of defered error information ...
    #-----------------------------------------------------------------------------

    # Bugzilla 19825 ...
    # method showDeferedErrorWindow --
    #
    #	Popup a dialog box that shows defered errors.
    #
    # Arguments:
    #       errordata	As delivred by the 'defered_error' event.
    #
    # Results:
    #	The name of the toplevel window.

    method showDeferedErrorWindow {errordata} {
	set de [$self errorDbgDefWin]

	if {![winfo exists $de]} {deferror $de $self}

	$de updateDeferedErrorWindow $errordata

	wm deiconify $de
	focus -force $de
	return       $de
    }

    #-----------------------------------------------------------------------------
    # Sub dialog for the display of parse error information ...
    #-----------------------------------------------------------------------------

    # method showParseErrorWindow --
    #
    #	Display a dialog reporting the parse error that
    #	occured during instrumentation.  Provide the
    #	user with three choices:
    #	  1) Attempt the instrument as much as possible.
    #	  2) Don't instrument this file.
    #	  3) Kill the application.
    #
    # Arguments:
    #	msg	The error message.
    #
    # Results:
    #	The name of the top level window.

    # Bugzilla 19824 ... New argument: title.

    variable parseErrorVar

    method showParseErrorWindow {msg title} {
	set pe [$self parseDbgWin]

	if {![winfo exists $pe]} {
	    parseerror $pe $self -resultvar [varname parseErrorVar]
	}

	$pe updateParseErrorWindow $msg $title

	wm deiconify $pe
	focus -force $pe
	return       $pe
    }

    #-----------------------------------------------------------------------------
    # Error Window Functions
    #-----------------------------------------------------------------------------

    # method showErrorWindow --
    #
    #	Popup a dialog box that shows the error and asks how
    #	to handle the error.
    #
    # Arguments:
    #	level		The level the error occured in.
    #	loc 		The <loc> opaque type where the error occured.
    #	errMsg		The message from errorInfo.
    #	errStack	The stack trace.
    #	errCode		The errorCode of the error.
    #
    # Results:
    #	The name of the toplevel window.

    method showErrorWindow {level loc errMsg errStack errCode uncaught} {
	set ee [$self errorDbgWin]

	if {![winfo exists $ee]} {
	    rterror $ee $self
	}

	$ee updateErrorWindow $level $loc $errMsg $errStack $errCode $uncaught

	wm deiconify $ee
	focus -force $ee
	return       $ee
    }

    # ### ### ### ######### ######### #########

    method breakDbgWin    {} {return $win.breakDbgWin}
    method coverWin       {} {return $win.coverWin}
    method dataDbgWin     {} {return $win.dataDbgWin}
    method errorDbgDefWin {} {return $win.errorDbgDefWin}
    method errorDbgWin    {} {return $win.errorDbgWin}
    method errorPortWin   {} {return $win.errorPortWin}
    method evalDbgWin     {} {return $win.evalDbgWin}
    method findDbgWin     {} {return $win.findDbgWin}
    method gotoDbgWin     {} {return $win.gotoDbgWin}
    method parseDbgWin    {} {return $win.parseDbgWin}
    method procDbgWin     {} {return $win.procDbgWin}
    method projMissingWin {} {return $win.projMisWin}
    method projSettingWin {} {return $win.projSetWin}
    method synDbgWin      {} {return $win.synDbgWin}
    method watchDbgWin    {} {return $win.watchDbgWin}

    # ### ### ### ######### ######### #########

    method setStatusCurrent {} {
	$gui setStatusMsg [$self getCurrentState]
	return
    }

    # ### ### ### ######### ######### #########

    delegate method blkIsInstrumented to blk as isInstrumented
    delegate method blkGetFile        to blk as getFile
    delegate method getUniqueFiles    to filedb

    delegate method bpShowWindow    to bp       as showWindow
    delegate method bpUpdateWindow  to bp       as updateWindow
    delegate method cwShowWindow    to chkwin   as showWindow
    delegate method covShowWindow   to coverage as showWindow
    delegate method evalShowWindow  to evalwin  as showWindow
    delegate method procShowWindow  to procwin  as showWindow
    delegate method gotoShowWindow  to gotowin  as showWindow
    delegate method watchShowWindow to watch    as showWindow

    delegate method tkConUpdate    to evalwin
    delegate method showResult     to inspector

    delegate method prShowNewProjWindow  to proj as showNewProjWindow
    delegate method prOpenProjCmd        to proj as openProjCmd
    delegate method prCloseProjCmd       to proj as closeProjCmd
    delegate method prSaveProjCmd        to proj as saveProjCmd        
    delegate method prSaveAsProjCmd      to proj as saveAsProjCmd
    delegate method prShowThisProjWindow to proj as showThisProjWindow
    delegate method prRestartProj        to proj as restartProj
    delegate method prIsProjectOpen      to proj as isProjectOpen
    delegate method prProjectNeverSaved  to proj as projectNeverSaved
    delegate method prGetProjectPath     to proj as getProjectPath
    delegate method prIsRemoteProj       to proj as isRemoteProj
    delegate method prOpenFileWindow     to proj as openFileWindow
    delegate method prCloseProjDialog    to proj as closeProjDialog
    delegate method prCloseProj          to proj as closeProj

    delegate method prwUpdateScriptList    to projwin as updateScriptList
    delegate method prwUpdateArgList       to projwin as updateArgList
    delegate method prwUpdateDirList       to projwin as updateDirList
    delegate method prwUpdateInterpList    to projwin as updateInterpList
    delegate method prwUpdateInterpArgList to projwin as updateInterpArgList
    delegate method prwUpdateIncrTcl       to projwin as updateIncrTcl
    delegate method prwUpdateExpect        to projwin as updateExpect
    delegate method prwUpdateTclX          to projwin as updateTclX
    delegate method prwUpdatePort          to projwin as updatePort

    delegate method findShowWindow to findwin as showWindow
    delegate method findNext       to findwin as next
    delegate method findNextOK     to findwin as nextOK

    delegate method varShowInspector to varDisplay as showInspector
    delegate method varAddToWatch    to varDisplay as addToWatch
    delegate method varToggleVBP     to varDisplay as toggleVBP
    delegate method varBreakState    to varDisplay as breakState

    delegate method codeBreakState     to codeDisplay as breakState
    delegate method codeUpdateTabStops to codeDisplay as updateTabStops
    delegate method codeCheckInit      to codeDisplay as checkInit
    delegate method codeCheckCore      to codeDisplay as checkCore

    delegate method updateCovHighlights  to coverage
    delegate method updateProfHighlights to coverage

    # ### ### ### ######### ######### #########

    method useKomodoOK {} {
	#puts "$mykomodo usable = [$mykomodo usable]"
	#puts "current file = ([$self getCurrentFile])"

	# Can't use this action if either komodo was not found, or the
	# currently shown block is dynamic.
	return [expr {
		      [$mykomodo usable] &&
		      ([$self getCurrentFile] ne "")
		  }]
    }

    method editInKomodo {} {
	set file [$self getCurrentFile]
	$mykomodo open $file

	# TODO? :: Start watching the file for changes and auto-invoke
	# TODO? :: 'self refreshFile'.
    }

    # ### ### ### ######### ######### #########

    method evalLevelVar {} {
	return [varname state](evalLevelVar)
    }
    method evalLevel {n} {
	set state(evalLevelVar) $n
	return
    }

    # ### ### ### ######### ######### #########

    # method openDialog --
    #
    #	Displays the open file dialog so the user can select a
    #	a Tcl file to view and set break points on.  If the task
    #	succeds a block is retrieved for the file and it is displayed.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method openFile {} {
	set types {
	    {"Tcl Scripts"		{.tcl .tk}}
	    {"All files"		*}
	}

	set file [$proj openFileWindow $win \
		[pref::prefGet fileOpenDir] $types]

	if {[string compare $file ""]} {
	    set oldwd [pwd]
	    set dir   [file dirname $file]
	    cd  $dir
	    set absfile [file join [pwd] [file tail $file]]
	    cd  $oldwd

	    pref::prefSet GlobalDefault fileOpenDir $dir

	    set block [$blk makeBlock $absfile]
	    set loc [loc::makeLocation $block {}]
	    $self showCode $loc
	}
	return
    }

    # method refreshFile --
    #
    #	Rereads the contents of the currently shown file.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method refreshFile {} {
	set file [$self getCurrentFile]
	if {$file == {}} {
	    return
	}

	set oldwd [pwd]
	set dir   [file dirname $file]
	cd  $dir
	set absfile [file join [pwd] [file tail $file]]
	cd  $oldwd
    
	pref::prefSet GlobalDefault fileOpenDir $dir
    
	set block [$blk makeBlock $absfile]

	# Bugzilla 26382 ... Refresh the script cache ...
	$blk clearSourceCache $block
	$blk getSource        $block
	$checker cacheClear   $block

	# Bug 71629 ... Clear instrumentation and coverage information
	# for this file, as it is now not instrumented any longer.

	$blk unmarkInstrumentedBlock $block
	if {$coverage != {}} {
	    $coverage clearCoverageArray $block
	}

	$self showCode [loc::makeLocation $block {}]
    	return
    }

    method cutcopy {} {
	tk_textCopy [$codeDisplay text]
    }

    delegate method toggleLBP      to codeDisplay as toggleLBPAtIndexInsert
    delegate method toggleSP       to codeDisplay as toggleSPAtIndexInsert
    delegate method allSPOn        to codeDisplay

    delegate method debugvar       to dbg

    method initInstrument {} {
	# Get the current values and propagate them to the
	# low-level debugger engine.

	$engine configure \
	    -instrumentdynamic [pref::prefGet instrumentDynamic] \
	    -doinstrument      [pref::prefGet doInstrument] \
	    -dontinstrument    [pref::prefGet dontInstrument] \
	    -autoload          [pref::prefGet autoLoad] \
	    -erroraction       [pref::prefGet errorAction]

	$engine initInstrument
	return
    }

    method warnInvalidBp {} {
	# Get the current values and propagate them to the
	# low-level debugger engine.

	$engine configure -warninvalidbp [pref::prefGet warnInvalidBp]
	return
    }

    method showInstrumented {} {
	global errorInfo
	catch {destroy  $win.instrumented}
	set t [toplevel $win.instrumented]
	text $t.t
	set b [$self getCurrentBlock]
	set r [catch {
	    set icode [$blk Instrument $b [$blk getSource $b]]
	}] ;# {}
	if {$r} {
	    $t.t insert 0.0 $errorInfo
	} else {
	    $t.t insert 0.0 $icode
	}
	pack $t.t -expand 1 -fill both
	return
    }

    method toggleLogOutput {} {
	$dbg debugtoggle
	return
	if {[$dbg debug]} {
	    $dbg logFilter: message
	} else {
	    $dbg logFilter: {}
	}
	return
    }

    method focusArea {} {
	set focusWin [focus]
	if {$focusWin == [$codeDisplay text]} {
	    if {[$focusWin tag ranges sel] != {}} {
		return 1
	    }
	} elseif {[$varDisplay hasFocus]} {
	    return [$varDisplay hasHighlight]
	} elseif {[$stackDisplay hasFocus]} {
	    return [$stackDisplay hasHighlight]
	}
	return 0
    }

    method focusHighlight {} {
	if {[$varDisplay hasFocus]} {
	    return [$varDisplay hasHighlight]
	}
	return 0
    }

    method focusVarWin {args} {
	if {[llength $args]} {
	    set oldfocus [lindex $args 0]
	    return [$varDisplay hadFocus $oldfocus]
	} else {
	    return [$varDisplay hasFocus]
	}
    }

    method focusStackWin {args} {
	if {[llength $args]} {
	    set oldfocus [lindex $args 0]
	    return [$stackDisplay hadFocus $oldfocus]
	} else {
	    return [$stackDisplay hasFocus]
	}
    }

    method focusCodeWin {args} {
	if {[llength $args]} {
	    set focus [lindex $args 0]
	} else {
	    set focus [focus]
	}
	expr {$focus == [$codeDisplay text]}
    }

    method codeLineBar {} {
	return [$codeDisplay lineBar]
    }

    method stayingdead {} {return $staydead}

    # ### ### ### ######### ######### #########

    method cancelAfter {} {
	if {[info exists afterID]} {
	    after cancel $afterID
	}
	return
    }
    method cancelAfterMsg {} {
	if {[info exists msgAfterID]} {after cancel $msgAfterID}
	return
    }
    method cancelAfterAll {} {
	if {[info exists afterID]}    {
	    after cancel $afterID
	}
	if {[info exists msgAfterID]} {after cancel $msgAfterID}
	return
    }

    method afterMsg {script} {
	set msgAfterID [after [$gui afterTime] $script]
	return
    }
    method after {script} {
	set afterID [after [$gui afterTime] $script]
	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide ui_engine 0.1
