# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# dbgtalk.tcl
#
#	This file implements the debugger API as a SNIT class.
#	Origin is 'dbg.tcl', a singleton object in a namespace.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2001-2006 ActiveState Software Inc.
# Copyright (c) 2002-2006 ActiveState Software Inc.
# Copyright (c) 2004-2012 ActiveState Software Inc.
#

#
# RCS: @(#) $Id: dbg.tcl,v 1.8 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require instrument ; # Engine: Instrument tcl code.
package require nub        ; # Engine: Get the nub sources.
package require parser     ; # Parsing Tcl code
package require snit       ; # OO system of choice
package require util       ; # Utilities, 'kill' in particular.
package require log        ; # Logging and Tracing

# ### ### ### ######### ######### #########
## Implementation

snit::type dbgtalk {
    # ### ### ### ######### ######### #########
    ## Options for preferences (project settings)

    option -warninvalidbp     0 ; # Preference warnInvalidBp
    option -instrumentdynamic 0 ; # Preference instrumentDynamic
    option -doinstrument      0 ; # Preference doInstrument
    option -dontinstrument    0 ; # Preference dontInstrument
    option -autoload          0 ; # Preference autoLoad
    option -erroraction       0 ; # Preference errorAction
    option -exit-on-eof       0 ; # How nub should handle frontend eof. Bug 75622.

    # ### ### ### ######### ######### #########
    ## Instance data

    variable stdchan ; # Array containing the redirection modes
    # .............. ; # for the standard channels.

    variable hc      ; # Array to persist hit counters for disabled breakpoints.

    # debugging options --
    #
    # Fields:
    #   debug		Set to 1 to enable debugging output.
    #	logFile		File handle where logging messages should be written.
    #	logFilter	If non-null, contains a regular expression that will
    #			be compared with the message type.  If the message
    #			type does not match, it is not logged.

    variable debug 0
    variable logFile stderr
    variable logFilter {}

    # startup options --
    #
    # Fields:
    #   libDir		The directory that contains the debugger scripts.
    #                   This is global information, shared by all instances
    #                   of this class.

    typevariable libDir     {}
    typevariable launchFile {}
    typevariable attachFile {}

    typemethod launchFile {} {
	return $launchFile
    }


    # nub communication data structure --
    #
    #	Communication with the nub is performed using a socket.  The
    #	debugger creates a server socket that a nub will connect to
    #	when starting.  If the nub is started by the debugger, then 
    #	the process id is also recorded.
    #
    # Fields:
    #	nubSocket	Socket to use to communicate with the
    #			currently connected nub.  Set to -1 if no
    #			nub is currently connected. 
    #	serverSocket	Socket listening for nub connect requests.
    #	serverPort	Port that the server is listening on.
    #	appPid		Process ID for application started by the debugger.
    #	appHost		Name of host that nub is running on.
    #   appVersion 	The tcl_version of the running app.

    variable nubSocket -1
    variable serverSocket -1
    variable serverPort -1
    variable appPid
    variable appHost    {}
    variable appVersion {}

    variable cbtimer {} ; # Timer handle for connect-back timeout.


    # application state data structure --
    #
    #	appState	One of running, stopped, or dead.
    #	currentPC	Location information for statement where the app
    #			last stopped.
    #   currentLevel	Current scope level for use in uplevel and upvar.
    #	stack		Current virtual stack.

    variable appState "dead"
    variable currentPC {}
    variable currentLevel 0
    variable stack {}

    # debugger events --
    #
    #	Asynchronous changes in debugger state will be reported to the GUI
    #	via event callbacks.  The set of event types includes:
    #
    #	any		Any of the following events fire.
    #   attach		A new client application has just attached to the
    #			debugger but has not stopped yet.
    #	linebreak 	The client application hit a line breakpoint.
    #	varbreak	The client application hit a variable breakpoint.
    #			Arguments are: varname, operation, current value,
    #			and the handle of the breakpoint.
    #	userbreak	The client application hit a debugger_break command.
    #	exit		The application has terminated.
    #	result		An async eval completed.  The result string
    #			is appended to the callback script.
    #	error		An error occurred in the script.  The error message,
    #			error info, and error code are appended to the script.
    #   cmdresult	The client application completed the current command
    #			and is stopped waiting to display the result.  The
    #			result string is appended to the callback script.
    #
    #   All of the handlers for an event are stored as a list in the
    #   registeredEvent array indexed by event type.
    #
    # Bugzilla 19825. New event type
    #
    #   defered_error   This event is delivered by dbg::Send when it
    #                   catches errors reported by the nub occuring
    #                   during the processing of a debugger
    #                   request. This can happen if the UI queries
    #                   application variables with a read-trace
    #                   associated to them, as that forces the backend
    #                   to execute application code during debugger
    #                   operation. Breakpoints are forcefully skipped
    #                   when doing this.  Errors too, but their
    #                   information is caught here and delivered to
    #                   the UI after the fact. Hence the 'defered' in
    #                   the name of the event.
    #
    #                   The argument is a list containing the
    #                   information for all errors which were
    #                   caught. Each item is a 2-element list
    #                   containing the stack at the time of the error,
    #                   and the regular error information delivered by
    #                   the nub.
    #
    # More event types.
    #
    #   stdin		This event is delivered when the application
    #			requests input on the channel "stdin" from
    #                   higher layers (redirected mode).
    #
    #   need_stdin	See stdin, but always sent, i.e. even if stdin
    #			was not redirected.
    #
    #   varunset        A variable having a var break was unset.
    #			Argument is the handle of the breakpoint
    #			(not yet destroyed).
    #
    #   int_invalid     The frontend tried to interupt a quiescient
    #                   application.
    #
    # Bugzilla 37458. New event type
    #
    #   attach-timeout  Called when the launch helper does not connect
    #                   back to the frontend within n Seconds.


    variable registeredEvent
    variable validEvents {
	any attach instrument linebreak varbreak userbreak
	error exit result cmdresult
	defered_error stdin need_stdin varunset
	int_invalid attach-timeout
    }

    # evaluate id generation --
    #
    #   evalId		A unique number used as the return ID for
    #			a call to dbg::evaluate.

    variable evalId 0

    # temporary breakpoint --
    #
    #   tempBreakpoint	The current run-to-line breakpoint.

    variable tempBreakpoint {}

    # Clientdata used to start sub processes ...
    # We remember for use in spawns

    variable cdata {}

    # ### ### ### ######### ######### #########
    ## No coverage by default.

    variable     coverage none
    option      -coverage none
    onconfigure -coverage {value} {
	set coverage $value

	# FUTURE ...
	# If the application is running we might
	# we wish to forward the configuration
	# change immediately, isntead of at the
	# next run of the application.
	return
    }

    variable     coverobj {}
    option      -coverobj {}
    onconfigure -coverobj {value} {
	set coverobj $value
	return
    }

    variable     eval {}
    option      -eval {}
    onconfigure -eval {value} {
	set eval $value
	return
    }

    option -onspawn {}

    # ### ### ### ######### ######### #########

    variable break
    method break: {break_} {
	set break $break_
	return
    }

    variable blkmgr
    method blk: {blkmgr_} {
	set blkmgr $blkmgr_
	return
    }

    variable gui
    method gui: {gui_} {
	set gui $gui_
	return
    }

    constructor {} {
	array set stdchan {
	    stdout redirect
	    stderr redirect
	    stdin  redirect
	}
	array set hc {}
    }

    destructor {
	# Ensure release of tcp resources.
	$self closeServerSocket
	return
    }


    # ### ### ### ######### ######### #########
    ## Public methods ...

    method stdchan: {chan newmode} {
	# Validate arguments ...
	if {![info exists stdchan($chan)]} {
	    return -code error "Unknown standard channel \"$chan\""
	}
	if {[lsearch -exact {normal copy redirect} $newmode] < 0} {
	    return -code error "Illegal redirection mode \"$newmode\""
	}
	if {($chan eq "stdin") && ($newmode eq "copy")} {
	    return -code error "Illegal redirection mode \"$newmode\" for stdin"
	}

	# Ignore non-changes ...
	if {$stdchan($chan) eq $newmode} {return}

	# Save, and propagate to nub ...
	set stdchan($chan) $newmode

	if {$appState != "dead"} {
	    $self SendAsync set DbgNub(stdchan,$chan) $newmode
	}
	return
    }


    # method start --
    #
    #	Starts the application.  Generates an error is one is already running.
    #
    # Arguments:
    #	application	The shell in which to run the script.
    #   appArgs         Shell arguments, coming before the script.
    #	startDir	the directory where the client program should be
    #			started. 
    #	script		The script to run in the application.
    #	argList		A list of commandline arguments to pass to the script.
    #	clientData	An opaque piece of data that will be passed through
    #			to the nub and returned on the Attach event.
    #
    # Results:
    #	None.

    method start {application appArgs startDir script argList clientData} {
	if {$appState ne "dead"} {
	    error "$self start called with an app that is already started."
	}
	set cdata $clientData
	set oldDir [pwd]

	# Determine the start directory.  Relative paths are computed from the
	# debugger startup directory.

	if {[catch {
	    # If the start directory is blank, use the debugger startup directory,
	    # otherwise use the specified directory.

	    if { $startDir != "" } {
		cd $startDir
	    }
	    
	    # start up the application

	    set args ""
	    # Ensure that the argument string is a valid Tcl list so we can
	    # safely pass it through eval.

	    if {[catch {
		foreach arg $argList {
		    lappend args $arg
		}
	    }]} {
		# The list wasn't valid so fall back to splitting on
		# spaces and ignoring null values.

		foreach arg [split [string trim $argList]] {
		    if {$arg != ""} {
			lappend args $arg
		    }
		}
	    }


	    # preprocess the appArgs a bit. The -encoding information
	    # can't be provided directly as we are not calling the
	    # script, but appLaunch.tcl, which is in a fixed encoding.

	    set encoding {}
	    set tmp {}
	    foreach {o v} $appArgs {
		if {$o eq "-encoding"} {
		    set encoding $v
		} else {
		    lappend tmp $o $v
		}
	    }
	    set appArgs $tmp

	    $self Log message {Launching $application $appArgs @ 127.0.0.1 $serverPort ($encoding:$script) ($clientData) ($args)}
	    $self Log message {Using launch helper $launchFile}

	    eval exec [list $application] $appArgs [list $launchFile \
		    127.0.0.1 $serverPort $encoding $script $clientData] $args &

	    # From now on the launch helper has n seconds to connect
	    # back. If it doesn't we assume that it failed and deliver
	    # an appropriate non-attach event to tell the frontend
	    # that the run operation failed.

	    set cbtimer [after 50000 [mymethod HandleConnectTimeout $clientData]]

	} msg]} {
	    # Make sure to restore the original directory before throwing 
	    # the error.

	    cd $oldDir
	    error $msg $::errorInfo $::errorCode
	}
	cd $oldDir
	return
    }

    # method kill --
    #
    #	Kills the current application.  Generates an error if the application
    #	is already dead.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method kill {} {
	if {$appState eq "dead"} {
	    error "$self kill called with an app that is already dead."
	}

	# Try to kill the application process.
	if {[$self isLocalhost]} {
	    $self Log timing {::kill $appPid}

	    set fail [catch {::kill $appPid}]
	    if {$fail} {
		global errorInfo
		$self Log timing {Kill failed: $errorInfo}
	    }
	}

	$self HandleClientExit
	return
    }

    # method step --
    #
    #	Runs the currently stopped application to the next instrumented
    #	statement (at the level specified, if one is specified).
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	level	The stack level at which to stop in the next instrumented
    #		statement.
    #
    # Results:
    #	None.

    method step {{level any}} {
	if {$appState ne "stopped"} {
	    error "$self step called with an app that is not stopped."
	}
	set appState "running"		

	## log::log info "DbgNub_Run $level"
	$self Log timing {DbgNub_Run $level}
	$self SendAsync   DbgNub_Run $level
	return
    }

    # method evaluate --
    #
    #	This command causes the application to evaluate the given script
    #	at the specified level.  When the script completes, a result
    #	event is generated.
    #	Generates an error if the application is not currently stopped.
    #
    # Arguments:
    #	level	The stack level at which to evaluate the script.
    #	script	The script to be evaluated by the application.
    #
    # Results:
    #	Returns a unqiue id for this avaluate.  The id can be used
    #	to match up the returned result.

    method evaluate {level script} {
	if {$appState ne "stopped"} {
	    error "$self evaluate called with an app that is not stopped."
	}

	if {$currentLevel < $level} {
	    error "$self evaluate called with invalid level \"$level\""
	}

	incr evalId
	$self SendAsync DbgNub_Evaluate $evalId $level $script
	set appState "running"

	return $evalId
    }

    # method run --
    #
    #	Runs the currently stopped application to either completion or the 
    #	next breakpoint.  Generates an error if an application is not
    #	currently stopped.
    #
    # Arguments:
    #	location	Optional.  Specifies the location for a temporary
    #			breakpoint that will be cleared the next time the
    #			application stops.
    #
    # Results:
    #	None.

    method run {{location {}}} {
	if {$appState ne "stopped"} {
	    error "$self run called with an app that is not stopped."
	}

	# If requested, set a temporary breakpoint at the specified location.
	
	if {$location != ""} {
	    set tempBreakpoint [$self addLineBreakpoint $location]
	}
	
	# Run until the next breakpoint
	set appState "running"	
	$self SendAsync DbgNub_Run
	return
    }

    # method interrupt --
    #
    #	Interrupts the currently running application by stopping at the next
    #	instrumented statement or breaking into the event loop.
    #	Generates an error if no application is currently running.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method interrupt {} {
	if {$appState ne "running"} {
	    error "$self interrupt called with an app that is not running."
	}

	# Stop at the next instrumented statement

	$self SendAsync DbgNub_Interrupt
	return
    }

    # method register --
    #
    #	Adds a callback for the specified event type.  If the event is
    #	not a valid event, an error is generated.
    #
    # Arguments:
    #	event	Type of event on which to make the callback.
    #	script	Code to execute when a callback is made.
    #
    # Results:
    #	None.

    method register {event script} {
	if {[lsearch $validEvents $event] == -1} {
	    error "$self register called with invalid event \"$event\""
	}
	lappend registeredEvent($event) $script
	return
    }

    # method unregister --
    #
    #	Removes the callback specified by the event and script.  If the
    #	specified script is not already registered with the given event,
    #	an error is generated.
    #
    # Arguments:
    #	event	Type of event whose callback to remove.
    #	script	The script that was registered with the given event type.
    #
    # Results:
    #	None.

    method unregister {event script} {
	if {[info exists registeredEvent($event)]} {

	    set i [lsearch $registeredEvent($event) $script]
	    if {$i == -1} {
		error "$self unregister called with non-registered script \"$script\"."
	    }
	    set registeredEvent($event) [lreplace $registeredEvent($event) $i $i]
	    return
	}
	error "$self unregister called with non-registered event \"$event\"."
    }

    # Debugging helper ... List all active event callbacks.

    method ListEvents {} {
	set res {}
	foreach e [lsort [array names registeredEvent]] {
	    foreach s $registeredEvent($e) {
		lappend res [list $e $s]
	    }
	}
	return $res
    }

    # method DeliverEvent --
    #
    #	Deliver an event to any scripts that have registered
    #	interest in the event.
    #
    # Arguments:
    #	event	The event to deliver.
    #	args	Any arguments that should be passed to the script.
    #		Note that we need to be careful here since the data
    #		may be coming from untrusted code and may be dangerous.
    #
    # Results:
    #	None.

    method DeliverEvent {event args} {
	# Break up args and reform it as a valid list so we can safely pass it
	# through uplevel.

	$self Log timing {DeliverEvent $event ($args)}

	set newList {}
	foreach arg $args {
	    lappend newList $arg
	}

	if {[info exists registeredEvent($event)]} {
	    foreach script $registeredEvent($event) {
		uplevel #0 $script $newList
	    }
	}
	if {[info exists registeredEvent(any)]} {
	    foreach script $registeredEvent(any) {
		uplevel #0 $script $event $newList
	    }
	}

	return
    }

    # method getLevel --
    #
    #	Returns the stack level at which the application is currently
    #	running.
    #	Generates an error if the application is not currently stopped.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns the stack level at which the application is currently
    #	running.

    method getLevel {} {
	if {$appState ne "stopped"} {
	    error "$self getLevel called with an app that is not stopped."
	}

	return $currentLevel
    }

    # method getPC --
    #
    #	Returns the location which the application is currently
    #	executing.
    #	Generates an error if the application is not currently stopped.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns the location which the application is currently
    #	executing.

    method getPC {} {
	if {$appState ne "stopped"} {
	    error "$self getPC called with an app that is not stopped."
	}

	return $currentPC
    }

    # method getStack --
    #
    #	Returns information about each frame on the current Tcl stack
    #	up to the most closely nested global scope.  The format of the
    #	stack information is a list of elements that have the
    #	following form:
    #		{level location type args ...}
    # 	The level indicates the Tcl scope level, as used by uplevel.
    #	The location refers to the location of the statement that is
    #	currently executing (or about to be executed in the current
    #	frame).  The type determines how the remainder of the
    #	arguments are to be interpreted and should be one of the
    #	following values:
    #		global	The stack frame is outside of any procedure
    #			scope.  There are no additonal arguments.
    #		proc	The statement is inside a procedure.  The
    #			first argument is the procedure name and the
    #			remaining arguments are the names of the
    #			procedure arguments.
    #		source	This entry in the stack is a virtual frame
    #			that corresponds to a change in block due to a
    #			source command.  There are no arguments.
    #	Eventually we will want to provide support for other virtual
    #	stack frames so we can handle other forms of dynamic code that
    #	are executed in the current stack scope (e.g. eval).  For now
    #	we will only handle "source", since it is a critical case.
    #
    #	Generates an error if the application is not currently stopped.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns a list of stack locations of the following form:
    #		{level location type args ...}

    method getStack {} {
	if {$appState ne "stopped"} {
	    error "$self getStack called with an app that is not stopped."
	}

	return $stack
    }

    # method getProcs --
    #
    #	Returns a list of all procedures in the application, excluding
    #	those added by the debugger itself.  The list consists of
    #	elements of the form {<procname> <location>}, where the
    #	location refers to the entire procedure definition.  If the
    #	procedure is uninstrumented, the location is null.
    #	Generates an error if the application is not currently stopped.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns a list of all procedures in the application, excluding
    #	those added by the debugger itself.  The list consists of
    #	elements of the form {<procname> <location>}.

    method getProcs {} {
	if {$appState ne "stopped"} {
	    error "$self getProcs called with an app that is not stopped."
	}

	return [$self Send DbgNub_GetProcs]
    }

    # method getProcLocation --
    #
    #	Get a location that refers to the specified procedure.  This
    #	function only works on uninstrumented procedures because the
    #	location will refer to an uninstrumented procedure block.
    #
    # Arguments:
    #	name	The name of the procedure.
    #
    # Results:
    #	Returns a location that can be used to get the procedure
    #	definition.

    method getProcLocation {name} {
	if {$appState ne "stopped"} {
	    error "$self getProcLocation called with an app that is not stopped."
	}
	$blkmgr SetSource Temp [$self Send DbgNub_GetProcDef $name]
	return [loc::makeLocation Temp 1]
    }

    # method getProcBody --
    #
    #	Given the location for an instrumented procedure we extract
    #	the body of the procedure from the origional source and return
    #	the uninstrumented body.  This is used, for example, by the
    #	info body command to return the origional body of code.
    #
    # Arguments:
    #	loc	The location of the procedure we want the body for.
    #
    # Results:
    #	The uninstrumented body of the procedure.

    method getProcBody {loc} {
	# This function is more complicated that it would seem at first.  The
	# literal value from the script is an unsubstituted value, but we need the
	# substituted value that the proc command would see.  So, we need to parse
	# the commaand as a list, extract the body argument and then create a new
	# command to evaluate that will compute the resulting substituted body.
	# If we don't do all of this, any backslash continuation characters won't
	# get substituted and we'll end up with a subtly different body.

	set script    [$blkmgr getSource [loc::getBlock $loc]]
	set args      [parse list $script [loc::getRange $loc]]
	eval set body [parse getstring $script [lindex $args 3]]
	return $body
    }

    # method uninstrumentProc --
    #
    #	Given a fully qualified procedure name that is currently 
    #	instrumented this procedure will insteract with the 
    #	application to redefine the procedure as un uninstrumented
    #	procedure.
    #
    # Arguments:
    #	procName	A fully qualified procedure name.
    #	loc		This is the location tag for the procedure
    #			passing this makes the implementation go
    #			much faster.
    #
    # Results:
    #	None.

    method uninstrumentProc {procName loc} {
	set body [$self getProcBody $loc]
	$self SendAsync DbgNub_UninstrumentProc $procName $body
	return
    }

    # method instrumentProc --
    #
    #	Given a fully qualified procedure name this function will
    #	instrument the procedure body and redefine the proc to use
    #	the new procedure body.
    #
    # Arguments:
    #	procName	A fully qualified procedure name.
    #	loc		The tmp loc for this procedure.
    #
    # Results:
    #	None.

    method instrumentProc {procName loc} {
	set block   [loc::getBlock $loc]
	set iscript [$self Instrument {} [$blkmgr getSource $block]]
	$self SendAsync DbgNub_InstrumentProc $procName $iscript
	return
    }

    # method getVariables --
    #
    #	Returns the list of variables that are visible at the specified
    #	level.
    #	Generates an error if the application is not currently stopped.
    #
    # Arguments:
    #	level	The stack level whose variables are returned.
    #	vars	List of variable names to fetch type info for.
    #
    # Results:
    #	Returns the list of variables that are visible at the specified
    #	level.

    method getVariables {level {vars {}}} {
	if {$appState ne "stopped"} {
	    error "$self getVariables called with an app that is not stopped."
	}

	if {$currentLevel < $level} {
	    error "$self getVar called with invalid level \"$level\""
	}

	return [$self Send DbgNub_GetVariables $level $vars]
    }

    # method getVar --
    #
    #	Returns a list containing information about each of the
    #	variables specified in varList.  The returned list consists of
    #	elements of the form {<name> <type> <value>}.  Type indicates
    #	if the variable is scalar or an array and is either "s" or
    #	"a".  If the variable is an array, the result of an array get
    #	is returned for the value, otherwise it is the scalar value.
    #	Any names that were specified in varList but are not valid
    #	variables will be omitted from the returned list.
    #	Generates an error if the application is not currently stopped.
    #
    # Arguments:
    #	level		The stack level of the variables in varList.
    #	maxlen		The maximum length of any data element to fetch, may
    #			be -1 to fetch everything.
    #	varList		A list of variables whose information is returned.
    #
    # Results:
    #	Returns a list containing information about each of the
    #	variables specified in varList.  The returned list consists of
    #	elements of the form {<name> <type> <value>}.

    method getVar {level maxlen varList} {
	if {$appState ne "stopped"} {
	    error "$self getVar called with an app that is not stopped."
	}

	if {$currentLevel < $level} {
	    error "$self getVar called with invalid level \"$level\""
	}

	return [$self Send DbgNub_GetVar $level $maxlen $varList]
    }

    # method setVar --
    #
    #	Sets the value of a variable.  If the variable is an array,
    #	the value must be suitable for array set, or an error is
    #	generated.  If no such variable exists, an error is generated.
    #	Generates an error if the application is not currently stopped.
    #
    # Arguments:
    #	level	The stack level of the variable to set.
    #	var	The name of the variable to set.
    #	value	The new value of var.
    #
    # Results:
    #	None.

    method setVar {level var value} {
	if {$appState ne "stopped"} {
	    error "$self setVar called with an app that is not stopped."
	}

	if {$currentLevel < $level} {
	    error "$self setVar called with invalid level \"$level\""
	}

	$self SendAsync DbgNub_SetVar $level $var $value
	return
    }

    # method getResult --
    #
    #	Fetch the result and return code of the last instrumented statement
    #	that executed.
    #
    # Arguments:
    #	maxlen	Truncate long values after maxlen characters.
    #
    # Results:
    #	Returns the list of {code result}.

    method getResult {maxlen} {
	if {$appState ne "stopped"} {
	    error "$self getVar called with an app that is not stopped."
	}

	return [$self Send DbgNub_GetResult $maxlen]
    }


    # method addLineBreakpoint --
    #
    #	Set a breakpoint at the given location.  If no such location
    #	exists, an error is generated.
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	location	The location of the breakpoint to add.
    #
    # Results:
    #	Returns a breakpoint identifier.

    method addLineBreakpoint {location} {
	#puts "$self addLineBreakpoint {$location}"
	#puts "\tbreak/make"

	set id [$break MakeBreakpoint line $location]
	set hc($id) 0

	if {$appState ne "dead"} {
	    #puts "\tnub"
	    $self SendAsync DbgNub_AddBreakpoint line $location
	    $self SendAsync DbgNub_SetHitcounter $id 0
	}
	#puts "\tbreak $id"
	return $id
    }

    method addLineBreakpointWithHitcount {location condition hitvalue} {
	#puts "$self addLineBreakpointWC {$location $condition $hitvalue}"
	#puts "\tbreak/make"

	set id [$break MakeBreakpoint line $location]
	set hc($id) 0

	set test [list DbgNub_HitBreakpoint $id $condition $hitvalue]
	$break setTest $id $test

	if {$appState ne "dead"} {
	    #puts "\tnub"
	    $self SendAsync DbgNub_AddBreakpoint line $location $test
	    $self SendAsync DbgNub_SetHitcounter $id 0
	}

	#puts "\tbreak $id"
	return $id
    }

    # method addCondBreakpoint --
    #
    #	Set a breakpoint at the given location.  If no such location
    #	exists, an error is generated.
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	location	The location of the breakpoint to add.
    #
    # Results:
    #	Returns a breakpoint identifier.

    method addCondBreakpoint {location expression} {
	#puts "$self addCondBreakpoint {$location expression}"
	#puts "\tbreak/make"

	set id [$break MakeBreakpoint line $location]
	set hc($id) 0

	set test [list DbgNub_CondBreakpoint $id $expression]
	$break setTest $id $test

	if {$appState ne "dead"} {
	    #puts "\tnub"
	    $self SendAsync DbgNub_AddBreakpoint line $location $test
	    $self SendAsync DbgNub_SetHitcounter $id 0
	}

	#puts "\tbreak $id"
	return $id
    }

    method addCondBreakpointWithHitcount {location expression hitcondition hitvalue} {
	#puts "$self addCondBreakpointWC {$location $expression $hitcondition $hitvalue}"
	#puts "\tbreak/make"

	set id [$break MakeBreakpoint line $location]
	set hc($id) 0

	set test [list DbgNub_CondBreakpoint $id $expression $hitcondition $hitvalue]
	$break setTest $id $test

	if {$appState ne "dead"} {
	    #puts "\tnub"
	    $self SendAsync DbgNub_AddBreakpoint line $location $test
	    $self SendAsync DbgNub_SetHitcounter $id 0
	}

	#puts "\tbreak $id"
	return $id
    }

    # method getLineBreakpoints --
    #
    #	Get the breakpoints that are set on a given line, or all
    #	line breakpoints.
    #
    # Arguments:
    #	location	Optional. The location of the breakpoint to get.
    #
    # Results:
    #	Returns a list of line-based breakpoint indentifiers.

    method getLineBreakpoints {{location {}}} {
	set bps [$break GetLineBreakpoints $location]
	if {$tempBreakpoint != ""} {
	    set index [lsearch -exact $bps $tempBreakpoint]
	    if {$index != -1} {
		set bps [lreplace $bps $index $index]
	    }
	}
	return $bps
    }

    # method validateBreakpoints --
    #
    #	Get the list of prior bpts and valid bpts for the block.
    #	Move invalid bpts that to nearest valid location.
    #
    # Arguments:
    #	file	The name of the file for this block.
    #	blk	Block for which to validate bpts.
    #
    # Results:
    #	None.

    method validateBreakpoints {file blk} {
	set validLines [$blkmgr getLines $blk]
	set bpLoc      [loc::makeLocation $blk {}]
	set bpList     [$self getLineBreakpoints $bpLoc]

	set warning 0
	foreach bp $bpList {
	    $self validateBreakpoint $blk $bp line $validLines warning
	}

	set spList [$self getSpawnpoints $bpLoc]
	if {[llength $spList]} {
	    set validLines [$blkmgr getSpawnLines $blk]
	    foreach sp $spList {
		$self validateBreakpoint $blk $sp spawn $validLines warning
	    }
	}

	set skipList [$self getSkipmarkers $bpLoc]
	if {[llength $skipList]} {
	    set validLines [$blkmgr getLines $blk]
	    foreach sp $skipList {
		$self validateBreakpoint $blk $sp skip $validLines warning
	    }
	}

	if {($warning == 1) && $options(-warninvalidbp)} {
	    set msg "invalid breakpoints found in $file have been moved to valid lines."

	    tk_messageBox -icon warning -type ok -title "Warning" \
		    -parent [$gui getParent] -message "Warning:  $msg"
	} elseif {($warning == 2) && $options(-warninvalidbp)} {
	    set msg "invalid breakpoints found in $file have been disabled as there\
		    are no valid lines to move them to."

	    tk_messageBox -icon warning -type ok -title "Warning" \
		    -parent [$gui getParent] -message "Warning:  $msg"
	}
	return
    }


    method validateBreakpoint {blk bp btype validLines warnVar} {
	upvar 1 $warnVar warning

	set line    [loc::getLine [$break getLocation $bp]]
	set newLine [$self binarySearch $validLines $line]

	if {$newLine == -1} {
	    # Bugzilla 19824 ...
	    # There are no valid lines in the given block. This can
	    # happen if the user aborted the process of
	    # instrumentation after a parse error. Instead of moving
	    # or deleting the BP we keep it around, in disabled form.

	    $break SetState $bp disabled
	    set warning 2

	} elseif {$newLine != $line} {
	    set newLoc [loc::makeLocation $blk $newLine]
	    set newBp  [$self moveLineBreakpoint $bp $newLoc $btype]
	    set warning 1

	    ## Bugzilla 19718 ... Set transient state to exclude the
	    # new bp's from transfer to the nub. They are already
	    # transfered. This is undone in '$self Instrument', see
	    # line 1636.

	    if {$newBp != ""} {
		if {[$break getState $newBp] eq "enabled"} {
		    $break SetState $newBp moved-enabled
		} elseif {[$break getState $newBp] eq "disabled"} {
		    $break SetState $newBp moved-disabled
		}
	    }
	}
	return
    }


    # ### ### ### ######### ######### #########
    ## Handling of spawn points ...

    # method getSpawnpoint --
    #
    #	Get the spawnpoint that is set on a given line, or all
    #	spawnpoints.
    #
    # Arguments:
    #	location	Optional. The location of the spawnpoint to get.
    #
    # Results:
    #	Returns a list of line-based spawnpoint identifiers.

    delegate method getSpawnpoints to break as GetSpawnpoints

    # method addSpawnpoint --
    #
    #	Set a spawnpoint at the given location.  If no such location
    #	exists, an error is generated.
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	location	The location of the breakpoint to add.
    #
    # Results:
    #	Returns a spawnpoint identifier.

    method addSpawnpoint {location} {
	#puts "$self addSpawnpoint {$location}"

	if {$appState ne "dead"} {
	    #puts "\tnub"
	    $self SendAsync DbgNub_AddBreakpoint spawn $location
	}
	#puts "\tspawn/make"
	set id [$break MakeBreakpoint spawn $location]
	#puts "\tspawn $id"
	return $id
    }

    ## delegate method removeSpawnpoint  to self as removeBreakpoint
    ## delegate method enableSpawnpoint  to self as enableBreakpoint
    ## delegate method disableSpawnpoint to self as disableBreakpoint


    # ### ### ### ######### ######### #########
    ## Handling of skip markers ...

    # method getSkipmarker --
    #
    #	Get the skip marker that is set on a given line, or all
    #	skip markers.
    #
    # Arguments:
    #	location	Optional. The location of the skip marker to get.
    #
    # Results:
    #	Returns a list of line-based skip marker identifiers.

    delegate method getSkipmarkers to break as GetSkipmarkers

    # method addSkipmarker --
    #
    #	Set a skip marker at the given location.  If no such location
    #	exists, an error is generated.
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	location	The location of the skip marker to add.
    #
    # Results:
    #	Returns a skip marker identifier.

    method addSkipmarker {location} {
	#puts "$self addSkipmarker {$location}"

	if {$appState ne "dead"} {
	    #puts "\tnub"
	    $self SendAsync DbgNub_AddBreakpoint skip $location
	}
	#puts "\tskip/make"
	set id [$break MakeBreakpoint skip $location]
	#puts "\tskip $id"
	return $id
    }

    ## delegate method removeSkipmarker  to self as removeBreakpoint
    ## delegate method enableSkipmarker  to self as enableBreakpoint
    ## delegate method disableSkipmarker to self as disableBreakpoint

    # ### ### ### ######### ######### #########

    # method binarySearch --
    #
    #	Find the nearest matching line on which to move an invalid bpt.
    #	Find the nearest matching value to elt in ls.
    #
    # Arguments:
    #	ls	Sorted list of ints >= 0.
    #	elt	Integer to match.
    #
    # Results:
    #	Returns the closest match or -1 if ls is empty.

    method binarySearch {ls elt} {
	set len [llength $ls]
	if {$len == 0} {
	    return -1
	}
	if {$len == 1} {
	    return [lindex $ls 0]
	}
	if {$len == 2} {
	    set e0 [lindex $ls 0]
	    set e1 [lindex $ls 1]
	    if {$elt <= $e0} {
		return $e0
	    } elseif {$elt < $e1} {
		if {($elt - $e0) <= ($e1 - $elt)} {
		    return $e0
		} else {
		    return $e1
		}
	    } else {
		return $e1
	    }
	}
	set middle [expr {$len / 2}]
	set result [lindex $ls $middle]
	if {$result == $elt} {
	    return $result
	}
	if {$result < $elt} {
	    return [$self binarySearch [lrange $ls $middle $len] $elt]
	} else {
	    return [$self binarySearch [lrange $ls 0 $middle] $elt]
	}
    }

    # method addVarBreakpoint --
    #
    #	Set a breakpoint on the given variable.
    #
    # Arguments:
    #	level		The level at which the variable is accessible.
    #	name		The name of the variable.
    #
    # Results:
    #	Returns a new breakpoint handle.

    method addVarBreakpoint {level name} {
	if {$appState ne "stopped"} {
	    error "$self addVarBreakpoint called with an app that is not stopped."
	}

	set handle [$self Send DbgNub_AddVarTrace $level $name]
	set id     [$break MakeBreakpoint var $handle]
	set hc($id) 0

	$self SendAsync DbgNub_AddBreakpoint var $handle
	$self SendAsync DbgNub_SetHitcounter $id 0

	return $id
    }

    method addVarBreakpointWithHitcount {level name condition hitvalue} {
	if {$appState ne "stopped"} {
	    error "$self addVarBreakpoint called with an app that is not stopped."
	}

	set handle [$self Send DbgNub_AddVarTrace $level $name]
	set id     [$break MakeBreakpoint var $handle]
	set hc($id) 0

	set test [list DbgNub_HitBreakpoint $id $condition $hitvalue]
	$break setTest $id $test

	$self SendAsync DbgNub_AddBreakpoint var $handle $test
	$self SendAsync DbgNub_SetHitcounter $id 0
	return $id
    }

    # method getVarBreakpoints --
    #
    #	Get the variable breakpoints that are set on a given variable.
    #	If both level and name are null, then all variable breakpoints
    #	are returned.
    #
    # Arguments:
    #	level		The level at which the variable is accessible.
    #	name		The name of the variable.
    #
    # Results:
    #	The list of breakpoint handles.

    method getVarBreakpoints {{level {}} {name {}}} {
	if {$appState ne "stopped"} {
	    error "$self getVarBreakpoints called with an app that is not stopped."
	}
	if {$level eq ""} {
	    return [$break GetVarBreakpoints]
	}
	set handle [$self Send DbgNub_GetVarTrace $level $name]
	if {$handle ne ""} {
	    return [$break GetVarBreakpoints $handle]
	}
	return ""
    }

    # method removeBreakpoint --
    #
    #	Remove the specified breakpoint.  If no such breakpoint
    #	exists, an error is generated.
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	breakpoint	The identifier of the breakpoint to remove.
    #
    # Results:
    #	None.

    method removeBreakpoint {breakpoint} {
	#puts "$self removeLineBreakpoint {$breakpoint}"

	if {$appState ne "dead"} {
	    #puts "\tnub"
	    set location [$break getLocation $breakpoint]
	    $self SendAsync DbgNub_RemoveBreakpoint \
		    [$break getType     $breakpoint] \
		    $location \
		    [$break getTest     $breakpoint]

	    if {[$break getType $breakpoint] eq "var"} {
		$self SendAsync DbgNub_RemoveVarTrace \
			[$break getLocation $breakpoint]
	    }

	    # Remove persisted hit counter information now that the
	    # breakpoint is truly gone.
	    $self SendAsync DbgNub_RemoveHitcounter $breakpoint
	    unset -nocomplain hc($breakpoint)
	}

	#puts "\tbreak/release"
	$break Release $breakpoint
	return
    }

    # method moveLineBreakpoint --
    #
    #	Remove the specified breakpoint.  If no such breakpoint
    #	exists, an error is generated.  Add a new breakpoint on the
    #	specified line.
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	breakpoint	The identifier of the breakpoint to move.
    #	newLoc		The new location for the breakpoint.
    #
    # Results:
    #	Returnes the new breakpoint or "" if none was added.

    method moveLineBreakpoint {breakpoint newLoc btype} {
	#puts "$self moveLineBreakpoint {$breakpoint $newLoc}"

	set removedBpState [$break getState $breakpoint]
	$self removeBreakpoint $breakpoint

	# If there's already a bpt on "line"
	#    and it's enabled, then do nothing.
	#    and we removed a disabled one, then do nothing.
	# Otherwise, remove any pre-existing bpts, and add "breakpoint"
	# to its new line.

	if {$btype eq "line"} {
	    set priorBpts [$break GetLineBreakpoints $newLoc]
	} elseif {$btype eq "skip"} {
	    set priorBpts [$break GetSkipmarkers $newLoc]
	} else {
	    set priorBpts [$break GetSpawnpoints $newLoc]
	}
	if {[llength $priorBpts] > 0} {
	    if {
		($removedBpState eq "disabled") ||
		($removedBpState eq "moved-disabled")
	    } {
		return ""
	    }
	    foreach priorBpt $priorBpts {
		if {
		    ([$break getState $priorBpt] ne "disabled") &&
		    ([$break getState $priorBpt] ne "moved-disabled")
		} {
		    return ""
		}
	    }
	    foreach priorBpt $priorBpts {
		$self removeBreakpoint $priorBpt	    
	    }
	}
	if {$btype eq "line"} {
	    set res [$self addLineBreakpoint $newLoc]
	} elseif {$btype eq "skip"} {
	    set res [$self addSkipmarker $newLoc]
	} else {
	    set res [$self addSpawnpoint $newLoc]
	}
	#puts ______________________________
	return $res
    }

    # method disableBreakpoint --
    #
    #	Disable (without removing) the specified breakpoint.  If no such
    #	breakpoint exists or if the breakpoint is already disabled, an
    #	error is generated.
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	breakpoint	The identifier of the breakpoint to disable.
    #
    # Results:
    #	None.

    method disableBreakpoint {breakpoint} {
	if {$appState ne "dead"} {
	    if {[info exists hc($breakpoint)]} {
		set hc($breakpoint) [$self Send DbgNub_GetHitcounter $breakpoint]
		$self SendAsync DbgNub_RemoveHitcounter $breakpoint
	    }
	    $self SendAsync DbgNub_RemoveBreakpoint \
		    [$break getType     $breakpoint] \
		    [$break getLocation $breakpoint] \
		    [$break getTest     $breakpoint]
	}

	$break SetState $breakpoint disabled
	return
    }

    # method enableBreakpoint --
    #
    #	Enable the specified breakpoint.  If no such breakoint exists
    #	or if the breakpoint is already enabled, an error is generated.
    #	Generates an error if an application is currently running.
    #
    # Arguments:
    #	breakpoint	The identifier of the breakpoint to enable.
    #
    # Results:
    #	None.

    method enableBreakpoint {breakpoint} {
	if {$appState ne "dead"} {
	    $self SendAsync DbgNub_AddBreakpoint \
		    [$break getType     $breakpoint] \
		    [$break getLocation $breakpoint] \
		    [$break getTest     $breakpoint]

	    if {[info exists hc($breakpoint)]} {
		$self SendAsync DbgNub_SetHitcounter $breakpoint $hc($breakpoint)
	    }
	}
	
	$break SetState $breakpoint enabled
	return
    }

    method hitsOfBreakpoint {breakpoint} {
	if {[$break getState $breakpoint] eq "disabled"} {
	    # Don't ask the nub, the nub doesn't know this bp.
	    return $hc($breakpoint)
	}
	return [$self Send DbgNub_GetHitcounter $breakpoint]
    }

    # method setServerPort --
    #
    #	This function sets the server port that the debugger listens on.
    #	If another port is opened for listening, it is closed before the
    #	new port is opened.
    #
    # Arguments:
    #	port		The new port number the users wants.  If the
    #			port arg is set to "random" then we find a
    #			suitable port in a standard range.
    #
    # Results:
    #	Return 1 if the new port was available and is now being used, 
    #	returns 0 if we couldn't open the new port for some reason.
    #	The old port will still work if we fail.

    method setServerPort {port} {
	# If the current port and the requested port are identical, just
	# return 1, indicating the port is available.

	# This code moved here from 'HandleClientExit' [*]. The
	# dynamic blocks were kept for use by the coverage and
	# profiling dialog, now they have to be purged and make way
	# for new blocks.

	$blkmgr release dynamic
	$blkmgr unmarkInstrumented

	if {($serverSocket != -1) && ($serverPort == $port)} {
	    return 1
	}
	
	# Close the port if it has been opened.

	$self closeServerSocket

	if {$port eq "random"} {
	    set result 1
	    set port   16999
	    while {$result != 0} {
		incr port
		set result [catch {
		    socket -server [mymethod HandleConnect] $port
		} socket] ;# {}
	    }
	} else {
	    set result [catch {
		socket -server [mymethod HandleConnect] $port
	    } socket] ;# {}
	}

	if {$result == 0} {
	    set serverPort   $port
	    set serverSocket $socket
	}
	return [expr {!$result}]
    }

    # method getServerPortStatus --
    #
    #	This function returns status information about the connection
    #	betwen the debugger and the debugged app.  The return is a
    #	list of appState & serverPort.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	A Tcl list

    method getServerPortStatus {} {
	if {$serverSocket == -1} {
	    set status     "Not connected"
	    set listenPort "n/a"
	} else {
	    set status     "Listening"
	    set listenPort "$serverPort (on [info hostname])"
	}

	if {$nubSocket != -1} {
	    set status   "Connected"
	    set sockname [fconfigure $nubSocket -sockname]
	    set peername [fconfigure $nubSocket -peername]
	} else {
	    set sockname "n/a"
	    set peername "n/a"
	}

	return [list $status $listenPort $sockname $peername]
    }

    method getServerPort {} {
	return $serverPort
    }

    # method closeServerSocket --
    #
    #	Close the server socket so the debugger is no longer listening
    #	on the open port.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method closeServerSocket {} {
	if {$serverSocket != -1} {
	    close $serverSocket
	    set    serverSocket -1
	}
	return
    }

    # method quit --
    #
    #	Clean up the debugger engine.  Kills the background app if it
    #	is still running and shuts down the server socket.  It also
    #	cleans up all of the debugger state.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method quit {} {
	if {$appState ne "dead"} {
	    catch {$self kill}
	}
	$self  closeServerSocket
	$break Release all
	set tempBreakpoint {}
	$blkmgr release all
	return
    }

    method detach {} {
	# Bugzilla 42273.
	#
	# Do not kill the client (debugged application). But we do
	# close the conneciton to it (see HandleClientExit). This puts
	# the client into detached mode where it still runs, but all
	# debugger interaction and instrumentation is
	# short-circuited. It will be still slower than a regular app,
	# but faster as most of the nub management code will not be
	# run anymore.

	if {$appState ne "dead"} {
	    $self HandleClientExit
	}

	$self  closeServerSocket
	$break Release all
	set tempBreakpoint {}
	$blkmgr release all
	return
    }

    # method HandleClientExit --
    #
    #	This function is called when the nub terminates in order to clean up
    #	various aspects of the debugger state.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.  Removes any variable traces, changes the state to dead,
    #	and generates an "exit" event.

    method HandleClientExit {} {
	$self Log timing {$self HandleClientExit ...}

	# Release all of the variable breakpoints.

	$break Release [$break GetVarBreakpoints]


	# Release all of the dynamic blocks and breakpoints.  We
	# also need to mark all instrumented blocks as uninstrumented.

	if {$tempBreakpoint != ""} {
	    $break Release $tempBreakpoint
	    set tempBreakpoint {}
	}
	foreach bp [$break GetLineBreakpoints] {
	    set block [loc::getBlock [$break getLocation $bp]]
	    if {[$blkmgr isDynamic $block]} {
		$break Release $bp
	    }
	}

	foreach bp [$break GetSpawnpoints] {
	    set block [loc::getBlock [$break getLocation $bp]]
	    if {[$blkmgr isDynamic $block]} {
		$break Release $bp
	    }
	}
	
	foreach bp [$break GetSkipmarkers] {
	    set block [loc::getBlock [$break getLocation $bp]]
	    if {[$blkmgr isDynamic $block]} {
		$break Release $bp
	    }
	}
	
	set tempBreakpoint {}

	if 0 {
	    # [*] This code has moved to 'setServerPort'. We have to
	    # keep the dynamic blocks after the application has exited
	    # so that the coverage and profiling dialog is able to use
	    # it. We also have to keep the blocks instrumented, so
	    # that the 'Save CSV' button gets valid results from
	    # 'getRanges'. As a side effect we have to fix the logic
	    # for 'refreshFile', we have to allow 'refreshFile' for
	    # instrumented files, if the session is dead. Bug 71629.

	    $blkmgr release dynamic
	    $blkmgr unmarkInstrumented
	}

	# Close the connection to the client.

	$self Log timing {$self HandleClientExit ... kill socket}

	close $nubSocket
	set    nubSocket -1

	set appState "dead"
	set appPid   -1

	$self Log timing {$self HandleClientExit ... post event}

	$self DeliverEvent exit

	$self Log timing {$self HandleClientExit ... done}
	return
    }

    # method HandleConnect --
    #
    #	Handle incoming connect requests from the nub.  If there is no
    #	other nub currently connected, creates a file event handler
    #	to watch for events generated by the nub.
    #
    # Arguments:
    #	sock	Incoming connection socket.
    #	host	Name of nub host.
    #	port    Incoming connection port.
    #
    # Results:
    #	None.

    method HandleConnect {sock host port} {
	$self Log message {Connection from $sock $host $port}

	## TODO ... Callback into higher levels to determine how to
	##          handle another connnection.

	if {$nubSocket != -1} {
	    close $sock
	} else {
	    set nubSocket $sock
	    set appState  running
	    fconfigure $sock -translation binary -encoding utf-8
	    fileevent  $sock readable [mymethod HandleNubEvent]

	    # Close the server socket
	    $self closeServerSocket 

	    # Prevent the execution of the timeout handler, as we got
	    # our connect-back in time.

	    after cancel $cbtimer
	}
	return
    }

    method HandleConnectTimeout {clientData} {
	# The launch helper did not connect back to the frontend in
	# time. Close the listener and report higher up.

	$self closeServerSocket 
	$self DeliverEvent attach-timeout $clientData
	return
    }

    # method SendMessage --
    #
    #	Transmit a list of strings to the nub.
    #
    # Arguments:
    #	args	Strings that will be turned into a list to send.
    #
    # Results:
    #	None.

    method SendMessage {args} {
	puts $nubSocket [string length $args]
	puts -nonewline $nubSocket $args
	flush $nubSocket

	## log::log debug "sent: len=[string length $args] '$args'"
	$self Log message {sent: len=[string length $args] '$args'}
	return
    }

    # method GetMessage --
    #
    #	Wait until a message is received from the nub.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns the message that was received, or {} if the connection
    #	was closed.

    method GetMessage {} {
	set bytes [gets $nubSocket]
	$self Log message {reading $bytes bytes}
	if {$bytes eq ""} {
	    return ""
	}
	set msg [read $nubSocket $bytes]
	$self Log message {got ([string length $msg]): '$msg'}
	return $msg
    }

    # method SendAsync --
    #
    #	Send the given script to be evaluated in the nub without
    #	waiting for a result.
    #
    # Arguments:
    #	args	The script to be evaluated.
    #
    # Results:
    #	None.

    method SendAsync {args} {
	$self SendMessage "SEND" 0 $args
	return
    }

    # method Send --
    #
    #	Send the given script to be evaluated in the nub.  The 
    #	debugger enters a limited event loop until the result of
    #	the evaluation is received.  This call should only be used
    #	for scripts that are expected to return quickly and cannot
    #	be done in a more asynchronous fashion.
    #
    # Arguments:
    #	args	The script to be evaluated.
    #
    # Results:
    #	Returns the result of evaluating the script in the nub, 
    #	including any errors that may result.

    method Send {args} {
	# Bugzilla 19825 ...
	# Define error cache, initially empty
	set errorsDuringSend [list]

	$self SendMessage "SEND" 1 $args
	while {1} {
	    set msg [$self GetMessage]
	    if {$msg eq ""} {
		return
	    }
	    switch -- [lindex $msg 0] {
		RESULT {		# Result of SEND message
		    # Bugzilla 19825 ... Deliver the errors we encountered to the UI
		    #                    for display, if there were any.

		    if {[llength $errorsDuringSend] > 0} {
			$self DeliverEvent defered_error $errorsDuringSend
		    }
		    return [lindex $msg 1]
		}
		ERROR {		# Error generated by SEND
		    # Bugzilla 19825 ... Deliver the errors we encountered to the UI
		    #                    for display, if there were any.
		    
		    if {[llength $errorsDuringSend] > 0} {
			$self DeliverEvent defered_error $errorsDuringSend
		    }
		    return -code [lindex $msg 2] -errorcode [lindex $msg 3] \
			    -errorinfo [lindex $msg 4] [lindex $msg 1]
		}
		LOG {
		    ## log::log notice "NUB report | [lindex $msg 1]"
		}
		STDERR -
		STDOUT {
		    # Forward application output on the standard channels
		    # to our Eval Console for display.

		    $eval log [lindex $msg 0] [lindex $msg 1]
		}
		NEED_STDIN {
		    # Notification that the application looks for
		    # data on stdin. This will be sent even if stdin
		    # has not been redirected.

		    $self DeliverEvent need_stdin
		}
		STDIN {
		    # The application asks for input on stdin. Forward the
		    # request to our Eval Console and send the generated
		    # result back to the application.

		    $self Log timing {HandleNubEvent STDIN}
		    set appState "stopped"
		    set stack        [lindex $msg 1]
		    set frame        [lindex $stack end]
		    set currentPC    [lindex $frame 1]
		    set currentLevel [lindex $frame 0]

		    # If coverage is on, retrieve and store coverage data

		    if {$coverage ne "none"} {
			$coverobj tabulateCoverage [lindex $msg 2]
		    }

		    # 3 = gets|read
		    # 4 = 0|1 - blocking
		    # 5 = empty or number of chars to read.

		    # During delivery of the event we have to pretend
		    # that the application is truly stopped. Afterward
		    # we can say that it is truly running, just waiting
		    # for user input.

		    $self DeliverEvent stdin
		    set appState "running"

		    $eval gets \
			    [lindex $msg 3] \
			    [lindex $msg 4] \
			    [lindex $msg 5] \
			    [mymethod SendMessage STDIN]
		}
		BREAK {
		    # Bugzilla 19825 ...
		    # Architectural problem. When querying a variable in
		    # the debugged application through this functionality
		    # the backend may have to run application-code to
		    # determine the value of that variable (<==> A
		    # read-trace is associated with it). This code may
		    # throw a script error or run into a user-defined
		    # breakpoint, something the backend will dutifully
		    # report to us here. Unfortunately we did not expect
		    # such messages, causing an error in the frontend
		    # itself. And thus the bugzilla entry. Now we are
		    # going for solution B-1: We simply force the back-end
		    # to skip over the BREAKs, and in the case of an error
		    # we also remember the error information. When we are
		    # done here we display any errors encountered, if any.

		    $self Log timing {HandleNubEvent BREAK/1}
		    set appState "stopped"

		    # Handle coverage data! The backend collects it
		    # incrementally and thus the data here would be lost
		    # if not handled.

		    if {$coverage ne "none"} {
			$coverobj tabulateCoverage [lindex $msg 2]
		    }

		    # Now what to do with the break ...

		    set stack    [lindex $msg 1]
		    set btype    [lindex $msg 3]
		    set bargs    [lindex $msg 4]

		    # Break types:
		    # - linebreak		(break before command)
		    # - cmdresult		(break after command)
		    # - error	message info code catch
		    # - exit	?status?
		    # - varbreak	varname op varvalue handle
		    # - userbreak	message

		    if {$btype eq "error"} {
			# Remember errors and their context, i.e
			# stack et al. (No variable snapshot yet).
			# Also tell the nub to ignore this error
			# and to proceed.

			lappend errorsDuringSend [list $stack $bargs]
			ignoreError
		    }

		    # Now tell the backend to resume execution behind
		    # the breakpoint.

		    $self Log timing {HandleNubEvent BREAK/1 auto-resume}

		    $self SendAsync DbgNub_Run
		}
		default {		# Looks like a bug to me
		    error "Unexpected message waiting for reply: $msg"
		}
	    }
	}

	return
    }

    # method HandleNubEvent --
    #
    #	This function is called whenever the nub generates an event on
    #	the nub socket.  It will invoke HandleEvent to actually 
    #	process the event.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method HandleNubEvent {} {
	$self Log timing {HandleNubEvent ENTER}

	set result [catch {
	    # Get the next message from the nub

	    set msg [$self GetMessage]

	    # If the nub closed the connection, generate an "exit" event.

	    if {[eof $nubSocket]} {
		$self HandleClientExit
		return
	    }

	    switch -- [lindex $msg 0] {
		HELLO {
		    if {[llength $msg] == 3} {
			set project REMOTE
		    } else {
			set project [lindex $msg 3]
		    }
		    $self InitializeNub [lindex $msg 1] [lindex $msg 2] $project
		}
		ERROR {
		    error "Got an ERROR from an asyncronous SEND: $msg"
		}
		RESULT {		# Result of SEND message, should not happen
		    error "Got SEND result outside of call to $self Send; $msg"
		}
		STDERR -
		STDOUT {
		    # Forward application output on the standard channels
		    # to our Eval Console for display.

		    $eval log [lindex $msg 0] [lindex $msg 1]
		}
		NEED_STDIN {
		    # Notification that the application looks for
		    # data on stdin. This will be sent even if stdin
		    # has not been redirected.

		    $self DeliverEvent need_stdin
		}
		STDIN {
		    # The application asks for input on stdin. Forward the
		    # request to our Eval Console and send the generated
		    # result back to the application.

		    $self Log timing {HandleNubEvent STDIN}
		    set appState     "stopped"
		    set stack        [lindex $msg 1]
		    set frame        [lindex $stack end]
		    set currentPC    [lindex $frame 1]
		    set currentLevel [lindex $frame 0]

		    # If coverage is on, retrieve and store coverage data

		    if {$coverage ne "none"} {
			$coverobj tabulateCoverage [lindex $msg 2]
		    }

		    # During delivery of the event we have to pretend
		    # that the application is truly stopped. Afterward
		    # we can say that it is truly running, just waiting
		    # for user input.

		    $self DeliverEvent stdin
		    set appState "running"

		    $eval gets \
			    [lindex $msg 3] \
			    [lindex $msg 4] \
			    [lindex $msg 5] \
			    [mymethod SendMessage STDIN]
		}
		BREAK {
		    $self Log timing {HandleNubEvent BREAK/2}
		    set appState     "stopped"
		    set stack        [lindex $msg 1]
		    set frame        [lindex $stack end]
		    set currentPC    [lindex $frame 1]
		    set currentLevel [lindex $frame 0]

		    # Remove any current temporary breakpoint

		    if {$tempBreakpoint != ""} {
			$self removeBreakpoint $tempBreakpoint
			set tempBreakpoint {}
		    }

		    # If coverage is on, retrieve and store coverage data

		    if {$coverage ne "none"} {
			$coverobj tabulateCoverage [lindex $msg 2]
		    }

		    # Break up args and reform it as a valid list so we can safely
		    # pass it through eval.

		    set newList {}
		    foreach arg [lindex $msg 4] {
			lappend newList $arg
		    }

		    if {[string equal [lindex $msg 3] exit]} {
			# This message was send during exit of the
			# application to transfer the latest in
			# coverage data to the UI. Send a straight
			# 'continue' command back to the nub to
			# prevent it from waiting for the frontend
			# (Which here believes that the nub is dead).
			# The true exit caused by this will cause
			# the exit event to be delivered.

			$self Log timing {HandleNubEvent BREAK/1 auto-resume on exit}

			$self SendAsync DbgNub_Run
		    } else {
			eval [list $self DeliverEvent [lindex $msg 3]] $newList
		    }
		}
		INSTRUMENT {
		    $self SendAsync DbgNub_InstrumentReply [$self Instrument [lindex $msg 1] \
			    [lindex $msg 2]]
		}
		PROCBODY {
		    set body [$self getProcBody [lindex $msg 1]]
		    $self SendAsync array set DbgNub [list body $body state running]
		}
		UNSET {
		    # A variable was unset so clean up the trace
		    set handle [lindex $msg 1]

		    # Deliver an event to allow higher levels to
		    # react to this change ...

		    $self DeliverEvent varunset $handle

		    $break Release [$break GetVarBreakpoints $handle]
		}
		LOG {
		    ## log::log notice "NUB report | [lindex $msg 1]"
		}
		SPAWN_RQ {
		    # 0 - msg
		    # 1 - stack
		    # 2 - coverage information
		    # 3 - command requesting the spawn (also id)

		    $self Log timing {HandleNubEvent SPAWN_RQ}
		    set appState "stopped"

		    foreach {__ stack coverdata title} $msg break

		    set frame        [lindex $stack end]
		    set currentPC    [lindex $frame 1]
		    set currentLevel [lindex $frame 0]

		    # Handling of coverage is unconditional, otherwise
		    # we would loose this chunk of data.

		    if {$coverage ne "none"} {
			$coverobj tabulateCoverage $coverdata
		    }

		    if {$options(-onspawn) == {}} {
			set port {}
		    } else {

			# During delivery of the event we have to pretend
			# that the application is truly stopped. Afterward
			# we can say that it is truly running.

			# The stdin event does what we want, updating
			# the UI with current location, despite being
			# formally the wrong thing. HACK. The event
			# should be renamed to reflect the more
			# general usage.

			$self DeliverEvent stdin

			set port [eval [linsert $options(-onspawn) end request $title]]
		    }
		    if {$port != {}} {
			set lfile   $launchFile
			set afile   $attachFile
			set cdSpawn $cdata
			set host    [info hostname]
		    } else {
			set lfile   {}
			set afile   {}
			set cdSpawn {}
			set host    {}
		    }

		    set appState "running"
		    $self SendMessage SPAWN_ACK $host $port $lfile $afile $cdata
		}
		SPAWN_ERROR {
		    # 0 - msg
		    # 1 - port the bad session is listening on.
		    # No response is expected.

		    if {$options(-onspawn) != {}} {
			eval [linsert $options(-onspawn) end error [lindex $msg 1]]
		    }
		}
		INT_INVALID {
		    # A call of method 'interrupt' got into a quiescent nub. 
		    # The app has to be in state stopped, so force this.

		    set appState stopped
		    $self DeliverEvent int_invalid
		}
		default {		# Looks like a bug to me
		    ## log::mlog critical "Unexpected message: $msg"
		    $self Log error {Unexpected message: $msg}
		}
	    }
	} msg] ; # {}
	if {$result == 1} {
	    ## log::mlog critical "Caught error in $self HandleNubEvent: $msg at \n$::errorInfo" ""

	    $self Log error {Caught error in $self HandleNubEvent: $msg at \n$::errorInfo}
	}
	return
    }

    # method ignoreError --
    #
    #	Indicates that the debugger should suppress the current error
    #	being propagated by the nub.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method ignoreError {} {
	if {$appState ne "stopped"} {
	    error "$self step called with an app that is not stopped."
	}

	$self SendAsync DbgNub_IgnoreError
	return
    }


    # method Instrument --
    #
    #	Instrument a new block of code.  Creates a block to contain the
    #	code and returns the newly instrumented script.
    #
    # Arguments:
    #	file		File that contains script if this is being
    #			called because of "source", otherwise {}.
    #	script		Script to be instrumented.
    #
    # Results:
    #	Returns the instrumented code or "" if the instrumentation failed.

    method Instrument {file script} {

	$self Log instrument {$self Instrument ($file) ...}

	# Get a block for the new code.

	set block [$blkmgr makeBlock $file]

	# Send the debugger a message when the instrumentation
	# begins and ends.

	$self DeliverEvent instrument start $block
	set alreadyInstrumented [$blkmgr isInstrumented $block]

	# Generate the instrumented script.

	$self Log instrument {	run instrumenter ([string length $script] chars)}
	set icode [$blkmgr Instrument $block $script]

	# Ensure that all breakpoints are valid.

	$self Log instrument {	validate BP's}

	$self validateBreakpoints $file $block

	$self Log instrument {	create BP's}

	if {($icode ne "") && !$alreadyInstrumented} {
	    # If the instrumentation succeeded and the block was not previously
	    # instrumented (e.g. re-sourcing), create any enabled breakpoints.

	    foreach breakpoint [$break GetLineBreakpoints \
		    [loc::makeLocation $block {}]] {
		if {[$break getState $breakpoint] eq "enabled"} {
		    $self SendAsync DbgNub_AddBreakpoint "line" \
			    [$break getLocation $breakpoint] \
			    [$break getTest     $breakpoint]
		}
	    }

	    foreach breakpoint [$break GetSpawnpoints \
		    [loc::makeLocation $block {}]] {
		if {[$break getState $breakpoint] eq "enabled"} {
		    $self SendAsync DbgNub_AddBreakpoint "spawn" \
			    [$break getLocation $breakpoint] \
			    [$break getTest     $breakpoint]
		}
	    }

	    foreach breakpoint [$break GetSkipmarkers \
		    [loc::makeLocation $block {}]] {
		if {[$break getState $breakpoint] eq "enabled"} {
		    $self SendAsync DbgNub_AddBreakpoint "skip" \
			    [$break getLocation $breakpoint] \
			    [$break getTest     $breakpoint]
		}
	    }
	}

	$self Log instrument {	BP transient to regular}

	# Bugzilla 19718 ... Convert the transient states into the regular states.
	# See '$self validateBreakpoints', line 849.

	foreach breakpoint [$break GetLineBreakpoints [loc::makeLocation $block {}]] {
	    if {[$break getState $breakpoint] eq "moved-enabled"} {
		$break SetState $breakpoint enabled
	    } elseif {[$break getState $breakpoint] eq "moved-disabled"} {
		$break SetState $breakpoint disabled
	    }
	}

	foreach breakpoint [$break GetSpawnpoints [loc::makeLocation $block {}]] {
	    if {[$break getState $breakpoint] eq "moved-enabled"} {
		$break SetState $breakpoint enabled
	    } elseif {[$break getState $breakpoint] eq "moved-disabled"} {
		$break SetState $breakpoint disabled
	    }
	}

	foreach breakpoint [$break GetSkipmarkers [loc::makeLocation $block {}]] {
	    if {[$break getState $breakpoint] eq "moved-enabled"} {
		$break SetState $breakpoint enabled
	    } elseif {[$break getState $breakpoint] eq "moved-disabled"} {
		$break SetState $breakpoint disabled
	    }
	}

	## set sep ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n
	## log::mlog debug Script..$sep$script\niScript.$sep$icode\n$sep

	$self DeliverEvent instrument end $block
	return $icode
    }

    # method Log --
    # Helper to set filters, and for getting at an internal var.

    method debugvar {} {
	return [varname debug]
    }
    method debug {} {
	return $debug
    }
    method debugtoggle {} {
	set debug [expr {1-$debug}]
	return
    }
    method logFilter: {filter} {
	set logFilter $filter
	return
    }

    method logFile: {chan} {
	set logFile $chan
	return
    }

    # method Log --
    #
    #	Log a debugging message.
    #
    # Arguments:
    #	type		Type of message to log
    #	message		Message string.  This string is substituted in
    #			the calling context.
    #
    # Results:
    #	None.

    method Log {msgtype message} {
    if {!$debug || (($logFilter != {}) && ([lsearch -exact $logFilter $msgtype] == -1))} {
	    return
	}
	puts $logFile "LOG($msgtype,[clock clicks]): [uplevel 1 [list subst $message]]"
	update idletasks
	return
    }

    # method InitializeNub --
    #
    #	Initialize the client process by sending the nub library script
    #	to the client process.
    #
    # Arguments:
    #	nubVersion	The nub loader version.
    #	tclVersion	The tcl library version.
    #	clientData	The clientData passed to debugger_init.
    #
    # Results:
    #	None.

    method InitializeNub {nubVersion tclVersion clientData} {
	# Load the nub into the client application.  Note that we are getting
	# the nub from the current working directory because we assume it is
	# going to be packaged into the debugger executable.

	# Retrieve additional nub code from the instrumentation
	# database.

	set inubscript [instrument::nubScript]

	$self Log message {============================================}
	$self Log message {============================================}
	foreach n [array names instrument::extraNubCmds] {
	    $self Log message {==  Extra nub command: $n}
	}
	$self Log message {============================================}
	$self Log message {== External code for the NUB}
	$self Log message {============================================}
	$self Log message {$inubscript}
	$self Log message {============================================}
	$self Log message {============================================}

	set inubscript "# ############################\n## EXTERN\n\n$inubscript"

	set nubScript [string map [list \
		@__EXTERN__@ \
		$inubscript] \
		[nub::script]]

	# If we are talking to an older version of Tcl, change the channel
	# encoding to iso8859-1 to avoid sending multibyte characters.

	if {$tclVersion < 8.1} {
	    fconfigure $nubSocket -encoding iso8859-1
	}	

	$self SendMessage NUB $nubScript

	# Fetch some information about the client and set up some 
	# initial state.

	set appPid     [$self Send pid]
	set appState   "stopped"
	set appVersion $tclVersion
	set appHost    [$self Send info hostname]

	$self Log message {Pid     $appPid}
	$self Log message {Version $appVersion}
	$self Log message {Host    $appHost}

	$self initInstrument
	$self initStdChannels

	# Begin coverage if it is enabled.

	$self Log message {Coverage & Profiling Mode = $coverage}

	if {$coverage ne "none"} {
	    $self SendAsync DbgNub_BeginCoverage $coverage
	}

	# Configure the instrumentor to know what version of Tcl
	# we are debugging.

	instrument::initialize $appVersion

	$self DeliverEvent attach $clientData
	return
    }

    # method initInstrument --
    #
    #	This command will communicate with the client application to
    #	initialize various preference flags.  The flags being set are:
    #
    #	DbgNub(dynProc)		If true, then instrument dynamic procs.
    #	DbgNub(includeFiles)	A list of files to be instrumented.
    #	DbgNub(excludeFiles)	A list of files not to be instrumented.
    #				Exclusion takes precedence over inclusion.
    #	DbgNub(autoLoad)	If true, instrument scripts sourced
    #				during auto_loading or package requires.
    #	DbgNub(errorAction)	If 0, propagate errors.  If 1, stop on
    #				uncaught errors.  If 2, stop on all errors.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method initInstrument {} {
	if {$appState != "dead"} {
	    $self SendAsync set DbgNub(dynProc)      $options(-instrumentdynamic)
	    $self SendAsync set DbgNub(includeFiles) $options(-doinstrument)
	    $self SendAsync set DbgNub(excludeFiles) $options(-dontinstrument)
	    $self SendAsync set DbgNub(autoLoad)     $options(-autoload)
	    $self SendAsync set DbgNub(errorAction)  $options(-erroraction)

	    # Bug 75622
	    $self SendAsync set DbgNub(exitOnEof)  $options(-exit-on-eof)
	}
	return
    }

    # method initStdChannels --
    #
    #	This command will communicate with the client application to
    #	initialize preference flags related to the redirection of the
    #	standard channels.  The flags being set are:
    #
    #	DbgNub(stdchan,stdout)	One of {normal, copy, redirect}
    #	DbgNub(stdchan,stderr)	One of {normal, copy, redirect}
    #	DbgNub(stdchan,stdin)	One of {normal, redirect}
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method initStdChannels {} {
	if {$appState != "dead"} {
	    $self SendAsync set DbgNub(stdchan,stdout) $stdchan(stdout)
	    $self SendAsync set DbgNub(stdchan,stderr) $stdchan(stderr)
	    $self SendAsync set DbgNub(stdchan,stdin)  $stdchan(stdin)
	}
	return
    }

    # method getAppVersion --
    #
    #	Return the tcl_version of the running app.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return the tcl_version of the running app.

    method getAppVersion {} {
	return $appVersion
    }

    method getAppHost {} {
	return $appHost
    }

    method getAppPid {} {
	return $appPid
    }


    # method isLocalhost --
    #
    #	Determine if the nub is running on the same host as the debugger.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Boolean, true if the nub and debugger are on the same machine.

    method isLocalhost {} {
	if {$appState eq "dead"} {
	    return 1
	}
	return [expr {$appHost eq [info hostname]}]
    }

    # ### ### ### ######### ######### #########
    ## Allow external code to react to changes in the application
    ## state

    method traceAppState {cmdprefix} {
	trace variable [varname appState] w $cmdprefix
	return
    }

    method getAppState {} {
	return $appState
    }

    # Debugging and test method ... Not for regular use.
    method SetAppState {x} {
	set appState $x
    }

    # ### ### ### ######### ######### #########
    ## Direct manipulation of the state regarding
    ## a temp. breakpoint. This is for higher-level
    ## engines which do _not_ use the 'run 2 location'
    ## interface for setting them up. Note that the
    ## interface here and 'run 2 location' interfere
    ## with each other. Use one or the other, but not
    ## both.

    method setTempBreakpoint {id} {
	# This command assumes that the breakpoint has already
	# been created and set through 'addLineBreakpoint'. 

	set tempBreakpoint $id
	return
    }

    method getTempBreakpoint {} {
	return $tempBreakpoint
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Global data structures and references

namespace eval ::dbgtalk {
    ::variable tempDir
    ::variable failApp 0

    # Bug 65524
    # win    = exe
    # unix   = exe, starkit - in the same directory
    # darwin =      starkit

    if {[string equal $::tcl_platform(platform) windows]} {
	set tempDir [file dirname [info nameofexecutable]]
    } else {
	# if argv0 is some *.tcl, then one level more is needed to
	# step out of the wrap. Bug 67632.

	set main    [file dirname [file normalize $::argv0/__dummy__]]
	set tempDir [file dirname $main]
	if {
	    [string match *.tcl $main]
	} {
	    set tempDir [file dirname $tempDir]
	}
    }

    ## No output from here, logging not yet initialized
    ##::log::log debug "Scratch directory (def.): ($tempDir)"
}

proc ::dbgtalk::setScratchDir {temp} {
    ::variable tempDir
    if {$temp ne ""} {set tempDir $temp}

    ##::log::log debug "Scratch directory (set.): ($tempDir)"
    return
}

proc ::dbgtalk::setFailApp {temp} {
    ::variable failApp $temp
    ##::log::log debug "Fail app (set.): ($failApp)"
    return
}

proc ::dbgtalk::initdirs {} {
    # Find the library directory for the debugger.  If one is not specified
    # look in the directory containing the startup script.

    ::variable libDir

    set oldcwd [pwd]
    cd  [file dirname [info script]]
    set libDir [pwd]
    cd $oldcwd
    return
}

proc ::dbgtalk::copyout {launchFile fn} {
    if {[file exists $fn]} {
	# Do our best to overwrite the existing file.

	if {[catch {
	    file copy -force $launchFile $fn
	}]} {
	    # Make the file writable, then try again to write over it.

	    if {[string equal $::tcl_platform(platform) windows]} {
		file attributes $fn -readonly 0
	    } else {
		file attributes $fn -permissions u+w
	    }

	    file copy -force $launchFile $fn
	}
    } else {
	file copy -force $launchFile $fn
    }
    return
}

proc ::dbgtalk::initialize {} {
    ::variable libDir
    ::variable tempDir
    ::variable failApp

    # Based on the library directory, find and remember various
    # special files (appLaunch). We prefer .tcl, but
    # also search for variants marked .tclnc. The latter are
    # present when wrapped, the chosen extension prevented
    # compilation during wrapping.

    foreach {f v} {
	appLaunch launchFile
    } {
	::variable $v ; upvar 0 $v fname
	set fname {}
	foreach e {.tcl .tclnc} {
	    set fn [file join $libDir $f$e]
	    if {[file exists $fn]} {
		set fname $fn
		break
	    }
	}
	if {$fname == {}} {
	    return -code error "Unable to locate $f.tcl(nc), \
		    searched in directory \"$libDir\""
	}	
    }

    # If the launch file is inside of a wrapped application then we
    # also look at at third place. If it is present there we use that,
    # else we copy the internal version to that place.

    if {[lindex [file system $launchFile] 0] ne "native"} {
	set outside $tempDir
	set fn      [file join $outside appLaunch.tcl]

	##::log::log debug "Scratch directory (used): ($tempDir)"
	##::log::log debug "al @ $fn"

	if {$failApp} {
	    # Errors cause the system to bail out.
	    copyout $launchFile $fn
	} else {
	    # Ignore copy errors.
	    catch {copyout $launchFile $fn}
	}

	set launchFile $fn
    }

    # The attach file is in the package 'tcldebugger_attach'. The
    # directory relationship during deployment is:
    #
    #     installdir/bin/tcldebugger/lib/engine/dbg.tcl
    #     installdir/lib/tcldebugger_attach/attach.tcl
    #     => ../../../../../tcldebugger_attach/attach.tcl
    #
    # Deployment for DBGp ...
    #
    #     installdir_komodo/tcl/dbgp_tcldebug.exe/lib/engine/dbg.tcl
    #     installdir_komodo/tcl/tcldebugger_attach/attach.tcl
    #     => ../../../../tcldebugger_attach/attach.tcl
    #
    # And during development
    #
    #     devkit/lib/dbg_engine/dbg.tcl
    #     devkit/lib/tcldebugger_attach/attach.tcl
    #     => ../../tcldebugger_attach/attach.tcl

    ::variable attachFile {}

    foreach libbase [set bases [list \
	    [file join [file dirname [file dirname [file dirname [file dirname $libDir]]]] lib] \
	    [file dirname [file dirname [file dirname $libDir]]] \
	    [file dirname $libDir] \
	    ]] {
	set f [file join $libbase tcldebugger_attach attach.tcl]
	if {[file exists $f]} {
	    set attachFile $f
	    break
	}
    }
    if {$attachFile == {}} {
	# Downgrade of error to log report. We have some environments
	# where this file is not required (-> Mobius) and the debugger
	# has to start even if the file is not present.

	##log::log debug "Unable to locate \"attach.tcl\", searched in directories:\n| [join $bases "\n| "]"
    }

    #log::log debug "dbg::initialize | appLaunch  = $launchFile"
    #log::log debug "dbg::initialize | attachFile = $attachFile"
    return
}

## The main part is now done in the constructor of 'engine'.
## Here we just locate the library directory of the package.
::dbgtalk::initdirs


# ### ### ### ######### ######### #########
## Ready to go

package provide dbgtalk 0.1
