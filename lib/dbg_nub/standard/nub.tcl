# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# nub.tcl -- -*- tcl -*-
#
#	This file contains the debugger nub implementation used
#	in the client application.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2008 ActiveState Software Inc.

#
# RCS: @(#) $Id: nub.tcl,v 1.18 2001/06/04 02:13:56 hobbs Exp $

# This file is transmitted to the client application when debugger_init
# connects to the debugger process.  It is evaluated in the debugger_Init
# procedure scope.  The local variable "socket" contains the file handle for
# the debugger socket.

global DbgNub
global tcl_version
set DbgNub(socket) $socket

# Communication mode flag -- Bug 75622

# This flag is a boolean. The default mode, 'false', means that the
# nub, and thus the debugged application continues to run when it
# loses the link to the debugger frontend. The debugging facilities,
# like breakpoints, and the like are simply disabled.

# This is standard behaviour for TDK's tcldebugger.

# The Komodo/Tcl debugger, i.e. 'dbgp_tcldebug' on the other hand sets
# this flag to true to ensure that the debugged application is killed
# then the engine goes away, even if it doesn't manage to shut the
# application down in the regular manner (because it was kill -KILL'ed
# before performing al lthe necessary actions).

if {![info exists DbgNub(exitOnEof)]} {
    set DbgNub(exitOnEof) 0
}

# Before we go any further, make sure the socket is in the right encoding.

if {$tcl_version >= 8.1} {
    fconfigure $socket -encoding utf-8
}

# debug flag --
#
#   The debug flag can be any OR'ed combination of these flags:
#
#	0 - no debug output
#	1 - statement logging
#	2 - socket protocol logging

if {![info exists DbgNub(debug)]} {
    set DbgNub(debug) 0
}
if {![info exists DbgNub(logFile)]} {
    set DbgNub(logFile) stderr
}

# error action flag --
#   
#   This flag controls the action taken when an error result code is detected.
#   If this flag is set to 0, errors will be allowed to propagate normally.  If
#   the flag is 1, errors that would cause the program to exit will be caught
#   at the nearest instrumented statement on the stack and an error break will
#   be generated.  If the flag is 2, then all errors will generate an error
#   break.

set DbgNub(errorAction) 1

# catch flag --
#
#   If this flag is set, then the current error should be caught by the
#   debugger because it is not handled by the application.

set DbgNub(catch) 1

# handled error flag --
#
#   If this flag is set, the current error has already been reported so it
#   should be propagated without generating further breakpoints.

set DbgNub(errorHandled) 0

# exclude commands list --
# 
# This is a list of all commands, used in the nub, that will cause
# the debugger to crash if they are renamed.  In the wrapped rename
# procedure, the command being renamed is compared to this list.  If
# the command is on this list, then an error is generated stating 
# that renaming the command will crash the debugger.

set DbgNub(excludeRename) [list append array break cd close concat continue \
	eof error eval expr fconfigure file fileevent flush for foreach gets \
	global if incr info lappend lindex linsert list llength lrange \
	lreplace lsearch namespace open puts pwd read regexp regsub rename \
	return set string switch trace unset uplevel upvar variable \
	vwait while]

# wrapped commands list --
#
#  This is a list of commands that the nub has wrapped.  The names may
#  change during runtime do to the "rename" command.  However, the nub
#  filters for "info proc" will always treat these as "commands".

set DbgNub(wrappedCommandList) [list catch source update uplevel \
	vwait info package proc exit rename puts gets read load fconfigure]

# external wrapped commands list --

#  Similar to wrappedCommandList above. The difference is that the
#  commands listed here are from extensions and not necessarily
#  built into the core. This requires more watching on part of the
#  nub to ensure that the wrapper is in place.

set DbgNub(externalWrappedCommandList) [list]
set DbgNub(externalWatchOut)           [list]

# instruction nesting count --
#
#   Records the number of nested instrumented instructions on the
#   stack. This count is reset whenever a new event loop frame is pushed.
#   It is used for determining when an error has propagated to the global
#   scope.

set DbgNub(nestCount) 0

# subcommand nesting count --
#
#   Records the number of nested command substitutions in progress.  This count
#   is used to determine where step-over operations should break.  The
#   currentCmdLevel records the nesting level of the currently executing
#   statement.  The stepCmdLevel records the nesting level of the last step
#   command. 

set DbgNub(currentCmdLevel) 0
set DbgNub(stepCmdLevel) 0

# step context level --
#
#   Records the level at which the current "step over" or "step out" operation
#   was initiated.

set DbgNub(stepLevel) 0
set DbgNub(stepOutLevel) {}

# break next flag --
#
#   If this flag is set, the next instrumented statement will trigger a
#   breakpoint.  This flag is set when single-stepping or when an inc interrupt
#   has been received.

set DbgNub(breakNext) 1

# breakpoint check list --
#
#   Contains a list of commands to invoke when testing whether to break on a
#   given statement.  Each command is passed a location and the current level.
#   The breakPreChecks list is invoked before a statement executes.

set DbgNub(breakPreChecks) {}
set DbgNub(breakPostChecks) {}

# breakpoint location tests --
#
#   For each location that contains a breakpoint, there is an entry in the
#   DbgNub array that contains a list of test scripts that will be evaluated at
#   the statement scope.  If the test script returns 1, a break will be
#   triggered.  The format of a breakpoint record is DbgNub(<block>:<line>).
#   The numBreaks field records the number of active breakpoints.
#
#   The nub manages hit counters for all breakpoints as well. The
#   format for the counters is 'DbgNub(hc,<id>)'. The counter is
#   initialized to zero when a breakpoint is added, and squashed when
#   the breakpoint is removed. It is possible to query the counter
#   before the removal. And also possible to initialize it to a
#   different value before the application continues execution after a
#   new breakpoint was set. This allows higher levels to persist hit
#   counter data for disabled breakpoints (Note: At this level there
#   is no difference between a disabled and a removed breakpoint. IOW:
#   When a breakpoint is disabled the higher levels (dbg_engine/dbg)
#   remove it from the nub.

set DbgNub(numBreaks) 0

# variable trace counter --
#
#   Each variable trace is referred to by a unique identifier.  The varHandle
#   counter contains the last trace handle that was allocated.  For each trace
#   there is a list of active variable breakpoints stored as a list in
#   DbgNub(var:<handle>).  For each variable breakpoint created in the
#   debugger, the reference count in dbgNub(varRefs:<handle>) is incremented.

set DbgNub(varHandle) 0

# instruction stack --
#
#   Records the location information associated with each instrumented
#   statement currently being executed.  The current context is a list of
#   the form {level type ?arg1 ... argn?}.  The level indicates
#   the scope in which the statement is executing.  The type is one of
#   "proc", "source", or "global" and indicates where the statement came
#   from.  For "proc" frames, the args contain the name of the
#   procedure and its declared arguments.  For "source" frames, the args
#   contain the name of the file being sourced.   The locations field
#   contains a list of statement locations indicating nested calls to
#   Tcl_Eval at the same scope (e.g. while).  Whenever a new context is
#   created, the previous context and location list are pushed onto the
#   contextStack.  New frames are added to the end of the list.

set DbgNub(contextStack) {}
set DbgNub(context) {0 global}
set DbgNub(locations) {}

# call stack --
#
#   Records the Tcl call stack as reported by info level.  The stack is a
#   list of context records as described for instruction stack entries.

set DbgNub(stack) {{0 global}}

# instrumentation flags --
#
#   The first three flags are set by user preferences:
#	dynProc		- if true, dynamic procs should be instrumented
#	autoLoad	- if false, all files sourced during an auto_load,
#			  auto_import, or package require operation will not
#			  be instrumented. A regular [source] will be used
#			  instead. Note that the latter means that all procs
#			  defined by such a file could be falsely identified
#			  as dynamic. This is checked for and prevented.
#			  Regular dynamic procedures _are_ instrumented.
#	includeFiles	- contains a list of string match patterns that
#			  must be matched in order for sourced files to be
#			  instrumented.  Only the specific file matched
#			  and any procedures it defines will be included, not
#			  files that it sources.  Exclusion (below) takes
#			  precedence over inclusion.
#	excludeFiles	- contains a list of string match patterns that
#			  will be used to exclude some sourced files from
#			  instrumentation.  Only the specific file matched
#			  and any procedures it defines will be excluded, not
#			  files that it sources.  Exclusion takes precedence
#			  over inclusion (above).
#
#   The next three flags are used to keep track of any autoloads, package
#   requires or excluded files that are in progress.

set DbgNub(dynProc)      0
set DbgNub(autoLoad)   1
set DbgNub(excludeFiles) {}
set DbgNub(includeFiles) {*}

set DbgNub(inAutoLoad) 0 ; # True iff a [source] is run from within the autoloading system.
set DbgNub(inExclude)  0 ; # True iff a [source] is run for an excluded fie.
set DbgNub(inRequire)  0 ; # True iff we are in a [package require]
set DbgNub(inLoad)     0 ; # Number of [load]'s in progress.

# code coverage variables --
#
#     DbgNub(cover:*)  - hash table of covered locations
#     DbgNub(cover)    - if true, store coverage info for each call to
#                        DbgNub_Do, and send coverage info to debugger
#                        on each break.
#     DbgNub(covermode) - Relevant iff (cover) is set.
#                         Modes are 'coverage' and 'profile'.
#     DbgNub(profile:*) - hash table of profiled locations.
#                         Per location: min/max/total time.

set DbgNub(cover)     0
set DbgNub(covermode) none

global DbgNub_timer      ; # Tallying timer for profiling.
set    DbgNub_timer 0    ; #
global DbgNub_stmtcnt    ; # #statements executed (DbgNub_Do)
set    DbgNub_stmtcnt 0  ; # for compund detection.

# info script:  We need to keep track of the current script being
# sourced so that "info script" can return the current result.  The
# following variable is a stack of all sourced files.  The initial value must
# be set for the remote debugging case, as the script is not neccessarily
# sourced.  For the local debugging case, the initial value is temporarily
# appLaunch.tcl, which is not correct, but this value will never be accessed
# because the "initial" script will be sourced, thereby pushing the correct
# script name on the stack.

set DbgNub(script) [list [info script]]

# Tcl 8.0 & namespace command
#
#   This variable tells the various Nub functions whether to deal
#   with namespace issues that are part of Tcl 8.0.  The namespace
#   issues may also be present in version less than Tcl 8.0 that
#   have itcl - this is a very different type of namespace, however.
#   We also set a scope prefix that will be used on every command that
#   we invoke in an uplevel context to ensure that we get the global version of
#   the command instead of a namespace local version.

# itcl4 - Has a completely different implementation based on TclOO in
# Tcl8.6 and higher. This changes the locations where to find various
# things due to command prefixes like 'my', and additional
# stackframes.

set DbgNub(itcl4) 0
if {[info tclversion] >= 8.6} {
    set DbgNub(namespace) 1
    set DbgNub(itcl76) 0
    set DbgNub(itcl4) 1
    set DbgNub(scope) ::
} elseif {[info tclversion] >= 8.0} {
    set DbgNub(namespace) 1
    set DbgNub(itcl76) 0
    set DbgNub(scope) ::
} else {
    set DbgNub(namespace) 0
    if {[info commands "namespace"] == "namespace"} {
	set DbgNub(itcl76) 1
    } else {
	set DbgNub(itcl76) 0
    }
    set DbgNub(scope) {}
}

# cached result values --
#
#   After every instrumented statement, the nub stores the current return code
#   and result value.

set DbgNub(lastCode)	0
set DbgNub(lastResult)	{}

# standard channels - input --
#
#   Data read from stdin is stored in this part of the state

set DbgNub(stdin) {}
set DbgNub(stdin,blocking) [fconfigure stdin -blocking]

# spawn acknowledgement information --
#
#   Status of a spawn request. Filled with the payload of an incoming
#   SPAWN_ACK message. An empty port denies the request for debugging
#   into the spawned process.
#
#   - Host:      Host the frontend is on <=> Host of the new server port.
#   - Port:      Server port the frontend will listen on for the new process.
#   - Applaunch: Location of appLaunch.tcl
#   - Attach:    Location of attach.tcl of package 'tcldebugger_attach'.
#   - Clientdata: Project information.

set DbgNub(spawn,port)      {}
set DbgNub(spawn,host)      {}
set DbgNub(spawn,applaunch) {}
set DbgNub(spawn,attach)    {}
set DbgNub(spawn,cdata)     {}

# spawn indicator flag --
#
#   This flag is automatically set when a location marked as spawn
#   point is reached. For every other location the indicator is
#   reset. Only commands able to spawn sub-debuggers should look at
#   this indicator. Doing so is entirely at their discretion.

set DbgNub(spawnPoint) 0

# Standard channel configuration --
#
#   The following variables control how the standard channels
#   are handled. Three modes are possible.
#
#   - 'normal'    Application requests are passed through to the
#                 regular standard channels.
#   - 'copy'      Like 'normal', but the data is also copied over
#                 to the debugging frontend.
#   - 'redirect'  The data is copied over to the debugging frontend,
#                 but not given to the regular standard channels.
#                 This is the default mode.
#
#   For stdin only 'normal' and 'redirect' are allowed, and indicate
#   the source of the data to give to the application upon reading
#   from the channel.

set DbgNub(stdchan,stdout) redirect
set DbgNub(stdchan,stderr) redirect
set DbgNub(stdchan,stdin)  redirect


##############################################################################
# Accessor for the spawnpoint information above.

proc DbgNub_SpawnInfo {what} {
    global DbgNub

    switch -exact -- $what {
	AtSpawnpoint {set result $DbgNub(spawnPoint)}
	Host         {set result $DbgNub(spawn,host)}
	Port         {set result $DbgNub(spawn,port)}
	LaunchFile   {set result $DbgNub(spawn,applaunch)}
	AttachFile   {set result $DbgNub(spawn,attach)}
	CData        {set result $DbgNub(spawn,cdata)}
    }

    if {$DbgNub(debug) & 1} {
	DbgNub_Log "SpawnInfo $what = $result"
    }

    return $result
}

proc DbgNub_SpawnRequest {title} {
    global DbgNub

    # A spawn request is a pseudo-breakpoint, like a STDIN read
    # request. If the spawned process blocks the calling application
    # the user may wish to see where the main session is at present.

    DbgNub_SendMessage SPAWN_RQ \
	    [DbgNub_CollateStacks] [DbgNub_GetCoverage] \
	    $title
    DbgNub_ProcessMessages 1 ; # Wait for a SPAWN_ACK message to come back

    # Squash the spawnpoint indicator, to prevent any command coming
    # later in the wrapper calling this from detecting a spawnpoint
    # and creating another session. Well, actually not any, but most
    # likely only the 'exec' used to launch the new process.

    set DbgNub(spawnPoint) 0
    return
}

##############################################################################


# DbgNub_Startup --
#
#	Initialize the nub state by wrapping commands and creating the
#	socket event handler.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_Startup {} {
    global DbgNub errorInfo errorCode

    DbgNub_WrapCommands

    if {![DbgNub_infoCmd exists errorInfo]} {
	set errorInfo {}
    }
    if {![DbgNub_infoCmd exists errorCode]} {
	set errorCode {}
    }
    fileevent $DbgNub(socket) readable DbgNub_SocketEvent
    DbgNub_ProcessMessages 1
    return
}

# DbgNub_Shutdown --
#
#	Terminate communication with the debugger.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_Shutdown {} {
    global DbgNub

    DbgNub_Log DbgNub_Shutdown

    if {$DbgNub(socket) != -1} {
	DbgNub_Log {Closing Socket}

	close $DbgNub(socket)
	set DbgNub(socket) -1
    }

    set DbgNub(stdchan,stdout) normal
    set DbgNub(stdchan,stderr) normal
    set DbgNub(stdchan,stdin)  normal

    # See description at the top of this file. Bug 75622.
    if {$DbgNub(exitOnEof)} {
	DbgNub_Log {Exiting Process}
	exit 0
    }
    return
}

# DbgNub_SendMessage --
#
#	Send the given script to be evaluated in the server.
#
# Arguments:
#	script	The script to be evaluated.
#
# Results:
#	None.

proc DbgNub_SendMessage {args} {
    global DbgNub
    if {$DbgNub(socket) == -1} {
	return
    }
    DbgNub_putsCmd $DbgNub(socket) [string length $args]
    DbgNub_putsCmd -nonewline $DbgNub(socket) $args
    
    if {$DbgNub(debug) & 2} {
	DbgNub_Log "sending [string length $args] bytes: '$args'"
    }
    if {[DbgNub_catchCmd {flush $DbgNub(socket)}]} {
	if {$DbgNub(debug) & 2} {
	    DbgNub_Log "SendMessage detected closed socket"
	}
	DbgNub_Shutdown
    }
    return
}

# DbgNub_GetMessage --
#
#	Get the next message from the debugger. 
#
# Arguments:
#	blocking	If 1, wait until a message is detected (or eof), 
#			otherwise check without blocking, 
#
# Results:
#	Returns the message that was received, or {} no message was
#	present.

proc DbgNub_GetMessage {blocking} {
    global DbgNub

    if {$DbgNub(socket) == -1} {
	return ""
    }

    # Put the socket into non-blocking mode long enough to poll if
    # we aren't doing a blocking read.

    DbgNub_fconfigureCmd $DbgNub(socket) -blocking $blocking
    set result [DbgNub_getsCmd $DbgNub(socket) bytes]
    DbgNub_fconfigureCmd $DbgNub(socket) -blocking 1
    if {$result == -1} {
	return ""
    }

    set msg [DbgNub_readCmd $DbgNub(socket) $bytes]
    if {$DbgNub(debug) & 2} {
	DbgNub_Log "got: '$msg'"
    }
    return $msg
}

# DbgNub_SocketEvent --
#
#	This function is called when a message arrives from the debugger during
#	an event loop.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_SocketEvent {} {
    global DbgNub
    
    DbgNub_ProcessMessages 0
    if {$DbgNub(breakNext)} {
	DbgNub_Break 0 linebreak
    }
}

# DbgNub_Do --
#
#	Execute an instrumented statement.  This command is used to
#	prefix all instrumented statements.  It will detect any
#	uncaught errors and ask the debugger how to handle them.
#	All other errors will be propagated.
#
# Arguments:
#	subcommand	1 if this statement is part of a command substitution,
#			0 if this statement is a body statement.
#	location	Location in original code block that
#			corresponds to the current statement.
#	args		The script that should be executed.
#
# Results:
#	Returns the result of executing the script.

proc DbgNub_Do {subcommand location cmd} {
    global DbgNub errorInfo errorCode DbgNub_stmtcnt DbgNub_timer

    # Save outer spawnpoint flag. In nested command the inner command
    # may sit on a different line than the outer command, giving them
    # different spawn information, and we must not simply overwrite,
    # i.e. lose the outer. Complementary restore at (:sp:).
    set oldsp $DbgNub(spawnPoint)
    if {$DbgNub(debug) & 1} {
	DbgNub_Log "SpawnInfo AtSpawnpoint Save $oldsp"
    }

    if {$DbgNub(socket) == -1} {
	set code [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $cmd} result]
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }

    set level [expr {[DbgNub_infoCmd level] - 1}]

    # Push a new virtual stack frame so we know where we are
    
    lappend DbgNub(locations) $location
    incr DbgNub(nestCount)

    # If this command is part of a command substitution, increment the
    # subcommand level.

    if {$subcommand} {
	incr DbgNub(currentCmdLevel)
    }

    if {$DbgNub(debug) & 1} {
	DbgNub_Log "[list DbgNub_Do $subcommand $location $cmd]"
    }
    
    # Process any queued messages without blocking

    DbgNub_ProcessMessages 0

    # Check to see if we need to stop on this statement

    if {! $DbgNub(breakNext)} {
	foreach check $DbgNub(breakPreChecks) {
	    if {[$check $location $level]} {
		set DbgNub(breakNext) 1
		break
	    }
	}
    } else {
	# Always check for spawnpoints, even for single-step.
	DbgNub_CheckSpawnpoints $location $level
    }
    if {$DbgNub(breakNext)} {
	# Bugzilla 19825. ... Reset breakNext when in the breakpoint,
	# so that further execution of application code will not
	# inadvertently go into single-step. And yes, the nub may
	# execute application-code while in 'DbgNub_Break'
	# below. Nameley when the frontend queries the variables of
	# the application and at least one of them has a read-trace
	# associated with it.

	set DbgNub(breakNext) 0
	DbgNub_Break $level linebreak

	# Bugzilla 29125. Check if the location we are currently
	# halted at is affected by new or deleted spawnpoints.

	DbgNub_CheckSpawnpoints $location $level
    }

    # Execute the statement and return the result

    if {$DbgNub(cover) && [string match profile $DbgNub(covermode)]} {
	# Full profiling is active, so we [time] the statement.

	# NOTE: If the statement executes nested statements time we
	# get here will be way off, because it will count all the time kept in
	# the nub itself too, and this also includes the handling of
	# breakpoints, which generates arbitrary delays, on the whim
	# of the user. On top of that we can expect that taking 'time'
	# in a 'time' statement will introduce some overhead too.

	# Do statement counting for ourselves, save count of caller.
	# Also provide a compound timer/counter to the subordinates.

	set oldcnt $DbgNub_stmtcnt ; set DbgNub_stmtcnt 0
	set oldtime $DbgNub_timer  ; set DbgNub_timer   0

	# I. Basic measurement ...

	set duration [lindex [time {
	    set DbgNub(lastCode) [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $cmd} \
		    DbgNub(lastResult)]
	} 1] 0] ; # {}

	# We save any compound information gathered during execution
	# and swap in the timer/counter data for our parent for the
	# upcoming post-processing.

	set compound $DbgNub_timer
	set DbgNub_timer $oldtime

	# II. Corrective actions: We discard the measured time if the
	#     statement was a compound and use the tallied timer value
	#     instead. This contains the accumulated time for all the
	#     sub-ordinate statements.

	if {$DbgNub_stmtcnt > 0} {
	    set duration $compound
	}

	# Restore caller's count of executed statements and add
	# ourself to it. We also add the chosen duration to the
	# compound timer/counter of our caller. There is no need to
	# scan and update the whole stack. This is done incrementally,
	# here, as nested invokations are unwound.

	set  DbgNub_stmtcnt $oldcnt
	incr DbgNub_stmtcnt
	incr DbgNub_timer   $duration

        # Now store the timing information for transmission to the
	# frontend, and update our statistics (min/max) too.

	set index "profile:$location"
	if {[DbgNub_infoCmd exists DbgNub($index)]} {
	    foreach {min max total} $DbgNub($index) break
	    incr total $duration
	    if {$duration < $min} {set min $duration}
	    if {$duration > $max} {set max $duration}
	    set DbgNub($index) [list $min $max $total]
	} else {
	    set DbgNub($index) [list $duration $duration $duration]
	    #                        min       max       total
	}
    } else {
	set DbgNub(lastCode) [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $cmd} \
		DbgNub(lastResult)]
    }

    if {($DbgNub(lastCode) == 1) && $DbgNub(spawnPoint) && ($DbgNub(spawn,port) != "")} {
	# Behind active spawn point, command failed, and we have
	# session data. This means that the frontend now has a session
	# waiting for a new, and never-coming process. We have to tell
	# the frontend about this so that it can properly clean up
	# this waiting session.

	DbgNub_SendMessage SPAWN_ERROR $DbgNub(spawn,port)
    }

    # Store the current location in DbgNub array, so we can calculate which
    # locations have not yet been covered.
    
    if {$DbgNub(cover)} {
	set index "cover:$location"
	if {[info exists DbgNub($index)]} {
	    incr DbgNub($index)
	} else {
	    set DbgNub($index) 1
	}
    }

    if {$DbgNub(debug) & 1} {
	DbgNub_Log "[list DbgNub_Do $subcommand $location $cmd completed \
		with code == $DbgNub(lastCode)]"
    }
    if {$DbgNub(lastCode) == 1} {
	# Clean up the errorInfo stack to remove our tracks.
	DbgNub_cleanErrorInfo
	DbgNub_cleanWrappers

	# This error could end the application. Let's check
	# to see if we want to stop and maybe break now.
	if {! $DbgNub(errorHandled) && (($DbgNub(errorAction) == 2) \
		|| (($DbgNub(errorAction) == 1) && $DbgNub(catch)))} {
	    if {[DbgNub_HandleError $DbgNub(lastResult) $level]} {
		set DbgNub(lastCode) 0
		set DbgNub(lastResult) {}
		set errorCode NONE
		set errorInfo {}
		set DbgNub(errorHandled) 0
		if {[DbgNub_infoCmd exists DbgNub(returnState)]} {
		    unset DbgNub(returnState)
		}
	    } else {
		set DbgNub(errorHandled) 1
	    }
	}
    }
    if {$DbgNub(spawnPoint) && [info exists DbgNub(spawn,port)] && ($DbgNub(spawn,port) != "")} {
	# Clean up temp data from a possible spawned session. The session
	# is now safe from automatic deletion by the nub.

	DbgNub_catchCmd {unset DbgNub(spawn,port)}
	DbgNub_catchCmd {unset DbgNub(spawn,host)}
	DbgNub_catchCmd {unset DbgNub(spawn,applaunch)}
	DbgNub_catchCmd {unset DbgNub(spawn,attach)}
	DbgNub_catchCmd {unset DbgNub(spawn,cdata)}
    }

    # Check to see if we need to stop and display the command result.
    set breakAfter 0
    foreach check $DbgNub(breakPostChecks) {
	if {[$check $location $level]} {
	    set breakAfter 1
	    break
	}
    }
    if {$breakAfter} {
	DbgNub_Break $level cmdresult
    }

    # Pop the current location from the location stack
    set DbgNub(locations) [lreplace $DbgNub(locations) end end]

    incr DbgNub(nestCount) -1
    if {$DbgNub(nestCount) == 0} {
	set DbgNub(errorHandled) 0
    }

    # Pop the subcommand frame, if necessary.

    if {$subcommand} {
	incr DbgNub(currentCmdLevel) -1
    }

    # (:sp:) Complementary restore of the spawnpoint flag saved at the
    # beginning of this procedure.
    set DbgNub(spawnPoint) $oldsp
    if {$DbgNub(debug) & 1} {
	DbgNub_Log "SpawnInfo AtSpawnpoint Restore $oldsp"
    }

    return -code $DbgNub(lastCode) -errorcode $errorCode \
	    -errorinfo $errorInfo $DbgNub(lastResult)
}

# DbgNub_Break --
#
#	Generate a breakpoint notification and wait for the debugger
#	to tell us to continue.
#
# Arguments:
#	level	The level of the program counter.
#	type	The type of breakpoint being generated.
#	args	Additonal type specific arguments.
#
# Results:
#	None.

proc DbgNub_Break {level type args} {
    set marker [DbgNub_PushStack $level]
    DbgNub_SendMessage BREAK [DbgNub_CollateStacks] [DbgNub_GetCoverage] \
	    $type $args
    DbgNub_ProcessMessages 1
    DbgNub_PopStack $marker
}

# DbgNub_Run --
#
#	Configure the nub to start running again.  The given operation
#	will determine how far the debugger will run.
#
# Arguments:
#	op	The type of step operation to do.
#
# Results:
#	None.  However, the application will start running again.

proc DbgNub_Run {{op run}} {
    global DbgNub

    # Remove any stale check procedures

    set index [lsearch -exact $DbgNub(breakPreChecks) DbgNub_CheckOver]
    if {$index != -1} {
	set DbgNub(breakPreChecks) \
		[lreplace $DbgNub(breakPreChecks) $index $index]
    }
    set index [lsearch -exact $DbgNub(breakPostChecks) DbgNub_CheckOver]
    if {$index != -1} {
	set DbgNub(breakPostChecks) \
		[lreplace $DbgNub(breakPostChecks) $index $index]
    }
    set DbgNub(stepOutLevel) {}

    switch $op {
	any {
	    set DbgNub(breakNext) 1
	}
	over {
	    lappend DbgNub(breakPreChecks) DbgNub_CheckOver
	    set DbgNub(stepLevel) [llength $DbgNub(contextStack)]
	    set DbgNub(stepCmdLevel) $DbgNub(currentCmdLevel)
	    set DbgNub(breakNext) 0
	}
	out {
	    set DbgNub(stepOutLevel) [llength $DbgNub(contextStack)]
	    set DbgNub(breakNext) 0
	}
	cmdresult {
	    lappend DbgNub(breakPostChecks) DbgNub_CheckOver
	    set DbgNub(stepLevel) [llength $DbgNub(contextStack)]
	    set DbgNub(stepCmdLevel) $DbgNub(currentCmdLevel)
	    set DbgNub(breakNext) 0
	}
	default {
	    set DbgNub(breakNext) 0
	}
    }
    set DbgNub(state) running
}

# DbgNub_CheckOver --
#
#	Checks to see if we should break the debugger based on what
#	level we are located in.
#
# Arguments:
#	location	Current location.
#	level		Stack level of current statement.
#
# Results:
#	Returns 1 if we should break at this statement.

proc DbgNub_CheckOver {location level} {
    global DbgNub

    set curLevel [llength $DbgNub(contextStack)]

    if {($curLevel < $DbgNub(stepLevel)) \
	    || ($DbgNub(currentCmdLevel) < $DbgNub(stepCmdLevel)) \
	    || (($curLevel == $DbgNub(stepLevel)) \
	    && ($DbgNub(currentCmdLevel) == $DbgNub(stepCmdLevel)))} {
	set index [lsearch -exact $DbgNub(breakPreChecks) DbgNub_CheckOver]
	if {$index != -1} {
	    set DbgNub(breakPreChecks) \
		    [lreplace $DbgNub(breakPreChecks) $index $index]
	}
	return 1
    }
    return 0
}

# DbgNub_HandleError --
#
#	Notify the debugger that an uncaught error has occurred and
#	wait for it to tell us what to do.
#
# Arguments:
#	message		Error message reported by statement.
#	level		Level at which the error occurred.
#
# Results:
#	Returns 1 if the error should be ignored, otherwise
#	returns 0.

proc DbgNub_HandleError {message level} {
    global DbgNub errorInfo errorCode
    set DbgNub(ignoreError) 0
    DbgNub_Break $level error $message $errorInfo $errorCode $DbgNub(catch)
    return $DbgNub(ignoreError)
}

# DbgNub_Instrument --
#
#	Pass a block of code to the debugger to be instrumented.
#	Generates an INSTRUMENT message that will eventually be
#	answered with a call to DbgNub_InstrumentReply.
#
# Arguments:
#	file		Absolute path to file being instrumented.
#	script		Script being instrumented.
#
# Results:
#	Returns the instrumented form of the script, or "" if the
#	script was not instrumentable.

proc DbgNub_Instrument {file script} {
    global DbgNub

    # Send the code to the debugger and process events until we are
    # told to continue execution.  The instrumented code should be
    # contained in the global DbgNub array.

    set DbgNub(iscript) ""
    DbgNub_SendMessage INSTRUMENT $file $script
    DbgNub_ProcessMessages 1
    return $DbgNub(iscript)
}

# DbgNub_InstrumentReply --
#
#	Invoked when the debugger completes instrumentation of
#	code sent in a previous INSTRUMENT message.
#
# Arguments:
#	script		The instrumented script.
#
# Results:
#	None.  Stores the instrumented script in DbgNub(iscript) and
#	sets the DbgNub(state) back to running so we break out of the
#	processing loop.

proc DbgNub_InstrumentReply {script} {
    global DbgNub
    set DbgNub(iscript) $script
    set DbgNub(state) running
}

# DbgNub_UninstrumentProc --
#
#	Give a fully qualified procedure name and the orginal proc
#	body (before it was instrumented) this procedure will recreate
#	the procedure to effectively unimplement the procedure.
#
# Arguments:
#	procName	A fully qualified procedure name.
#	body		The uninstrumented version of the body.
#
# Results:
#	None - various global state about the proc is changed.

proc DbgNub_UninstrumentProc {procName body} {
    global DbgNub

    set current [DbgNub_GetProcDef $procName]
    set new [lreplace $current 0 0 DbgNub_procCmd]
    set new [lreplace $new 3 3 $body]
    eval $new
    unset DbgNub(proc=$procName)
}

# DbgNub_InstrumentProc --
#
#	Given a fully qualified procedure name this command will
#	instrument the procedure.  This should not be called on
#	procedures that have already been instrumented.
#
# Arguments:
#	procName	A fully qualified procedure name.
#
# Results:
#	None - various global state about the proc is changed.

proc DbgNub_InstrumentProc {procName script} {
    global DbgNub

    # If the proc given has been compiled with TclPro Compiler
    # the we can't instrument the code so we don't allow it to
    # happen.

    set cmpBody {# Compiled -- no source code available}
    append cmpBody \n
    append cmpBody {error "called a copy of a compiled script"}
    if {[DbgNub_infoCmd body $procName] == $cmpBody} {
	return
    }

    # The code we just received starts with a DbgNub_Do which we
    # don't want to run.  Strip out the actual proc command and eval.
    set cmd [lindex $script end]
    eval $cmd
    return
}

# DbgNub_ProcessMessages --
#
#	Read messages from the debugger and handle them until the
#	debugger indicates that the nub should exit the loop by setting
#	the DbgNub(state) variable to something other than "waiting".
#
# Arguments:
#	blocking		Indicates whether we should wait for
#				messages if none are present.
#
# Results:
#	None.  Processing certain message types may have arbitrary
#	side effects which the caller may expect.

proc DbgNub_ProcessMessages {blocking} {
    global DbgNub

    if {$DbgNub(socket) == -1} {
	return
    }

    set DbgNub(state) waiting

    while {$DbgNub(state) == "waiting"} {
	if {[DbgNub_catchCmd {DbgNub_GetMessage $blocking} msg]} {
	    DbgNub_Log "DbgNub_ProcessMessages: GetMessage error"
	    DbgNub_Shutdown
	    return
	} elseif {$msg == ""} {
	    if {[eof $DbgNub(socket)]} {
		DbgNub_Log "DbgNub_ProcessMessages: No messages due EOF"
		DbgNub_Shutdown
	    }
	    return
	}
	switch [lindex $msg 0] {
	    SEND {
		# Evaluate a Send.  Return any result
		# including error information.

		#DbgNub_Log "SEND // [lindex $msg 2]"
		
		set code [DbgNub_catchCmd {eval [lindex $msg 2]} result]

		#DbgNub_Log "SEND \\\\ $code // $result"

		if {$code != 0} {
		    global errorInfo errorCode
		    DbgNub_SendMessage ERROR $result $code $errorCode \
			    $errorInfo
		} elseif {[lindex $msg 1] == "1"} {
		    DbgNub_SendMessage RESULT $result
		}
	    }
	    STDIN {
		set DbgNub(state) running
		set DbgNub(stdin) [lindex $msg 1]
		return
	    }
	    SPAWN_ACK {
		# May deny or grant the request.
		set DbgNub(state) running
		set DbgNub(spawn,host)      [lindex $msg 1]
		set DbgNub(spawn,port)      [lindex $msg 2]
		set DbgNub(spawn,applaunch) [lindex $msg 3]
		set DbgNub(spawn,attach)    [lindex $msg 4]
		set DbgNub(spawn,cdata)     [lindex $msg 5]
		return
	    }
	}
    }
    return
}

# DbgNub_Log --
#
#	Log a debugging message.
#
# Arguments:
#	args	Debugging message to log
#
# Results:
#	None.

proc DbgNub_Log {args} {
    global DbgNub
    DbgNub_putsCmd $DbgNub(logFile) [concat "LOG: " $args]
    flush $DbgNub(logFile)
}

# DbgNub_GetProcs --
#
#	Returns a list of all procedures in the application, excluding
#	those added by the debugger itself.  The list consists of
#	elements of the form {<procname> <location>}, where the
#	location refers to the entire procedure definition.  If the
#	procedure is uninstrumented, the location is null.
#
# Arguments:
#	namespace:	This variable is only used by the implementation
#			of DbgNub_GetProcs itself.  It is used to recurse
#			through the namespaces to find hidden procs.
#
# Results:
#	Returns a list of all procedures in the application, excluding
#	those added by the debugger itself and imported names.  The list
#	consists of elements of the form {<procname> <location>}.

proc DbgNub_GetProcs {{namespace {}}} {
    global DbgNub

    set procList ""
    if {$namespace != ""} {
	set nameProcs ""
	# Be sure to call the "wrapped" version of info to filter DbgNub procs
	foreach x [namespace eval $namespace "$DbgNub(scope)info procs"] {
	    if {[string compare \
		    [namespace eval $namespace \
			[list $DbgNub(scope)namespace origin $x]] \
		    [namespace eval $namespace \
			[list $DbgNub(scope)namespace which $x]]] \
		    == 0} {
		lappend nameProcs ${namespace}::$x
	    }
	}
	foreach n [namespace children $namespace] {
	    set nameProcs [concat $nameProcs [DbgNub_GetProcs $n]]
	}
	return $nameProcs
    } elseif {$DbgNub(namespace)} {
	foreach n [namespace children ::] {
	    set procList [concat $procList [DbgNub_GetProcs $n]]
	}
	# Be sure to call the "wrapped" version of info to filter DbgNub procs
	foreach name [$DbgNub(scope)info procs] {
	    if {[string compare [namespace origin $name] \
		    [namespace which $name]] == 0} {
		lappend procList "::$name"
	    }
	}
    } else {
	# Be sure to call the "wrapped" version of info to filter DbgNub procs
	set procList [$DbgNub(scope)info procs]
    }

    set result {}
    foreach name $procList {
	if {[DbgNub_infoCmd exists DbgNub(proc=$name)]} {
	    lappend result [list $name $DbgNub(proc=$name)]
	} else {
	    lappend result [list $name {}]
	}
    }
    return $result
}

# DbgNub_GetVariables --
#
#	Retrieve the names of the variables that are visible at the
#	specified level, excluding internal Debugger variables.
#
# Arguments:
#	level	Stack level to get variables from.
#	vars	A list of variables to test for existence.  If this list
#		is null, all local and namespace variables will be returned.
#
# Results:
#	Returns a list of variable names.

proc DbgNub_GetVariables {level vars} {
    global DbgNub

    # We call the "wrapped" version of info vars which will weed
    # out any debugger variables that may exist in the var frame.

    if {$vars == ""} {
	set vars [DbgNub_uplevelCmd #$level "$DbgNub(scope)info vars"]
	if {$DbgNub(itcl76)} {
	    if {[DbgNub_uplevelCmd \#$level {info which info}] \
		    == "::itcl::builtin::info"} {
		# We are in a class or instance context
		set name [DbgNub_uplevelCmd \#$level {lindex [info level 0] 0}]
		set mvars [DbgNub_uplevelCmd \#$level {info variable}]
		if {($name != "") && ([DbgNub_uplevelCmd \#$level \
			[list info function $name -type]] == "proc")} {
		    # We are in a class proc, so we need to filter out
		    # all of the instance variables.  Note that we also
		    # need to filter out duplicates because once they have
		    # been accessed once, member variables show up in the
		    # "info vars" list.

		    foreach var $mvars {
			if {([DbgNub_uplevelCmd \#$level \
				[list info variable $var -type]] == "common") \
				&& ([lsearch $vars $var] == -1)} {
			    lappend vars $var
			}
		    }
		} else {
		    # Filter out duplicates.

		    foreach var $mvars {
			if {[lsearch $vars $var] == -1} {
			    lappend vars $var
			}
		    }
		}
	    }
	} elseif {$DbgNub(namespace)} {
	    # Check to see if we are in an object or class context.  In this
	    # case we need to add in the member variables.  Otherwise, check
	    # to see if we are in a non-global namespace context, in which
	    # case we add the namespace variables.

	    if {[DbgNub_uplevelCmd \#$level \
		    [list $DbgNub(scope)namespace origin info]] \
		    == "::itcl::builtin::info"} {
		# If the function name is null, we're in a configure context,
		# otherwise we need to check the function type to determine
		# whether the function is a proc or a method.

		set name  [DbgNub_uplevelCmd \#$level {lindex [info level 0] 0}]
		set mvars [DbgNub_uplevelCmd \#$level {info variable}]

		if {($name != "")} {
		    # Bugzilla 90179. The script may have regular
		    # namespaced procedures P in the same namespace
		    # which also is an itcl class. In that case the
		    # 'info function' will fail on P and we have to
		    # fall back to the regular processing (replicated
		    # from (Z).

		    if {![DbgNub_catchCmd {
			DbgNub_uplevelCmd \#$level [list info function $name -type]
		    } res]} {
			if {$res == "proc"} {
			    # We are in a class proc, so filter out instance variables

			    foreach var $mvars {
				if {[DbgNub_uplevelCmd \#$level \
					 [list info variable $var -type]] == "common"} {
				    lappend vars $var
				}
			    }
			} else {
			    set vars [concat $mvars $vars]
			}
		    } else {
			# Replicated (Z)
			set current [DbgNub_uplevelCmd #$level \
					 "$DbgNub(scope)namespace current"]
			if {$current != "::"} {
			    set vars [concat $vars \
					  [DbgNub_uplevelCmd #$level \
					       "$DbgNub(scope)info vars" [list ${current}::*]]]
			}
		    }
		} else {
		    set vars [concat $mvars $vars]
		}
	    } else {
		# (Z) regular namespace processing, outside of itcl.
		set current [DbgNub_uplevelCmd #$level \
			"$DbgNub(scope)namespace current"]
		if {$current != "::"} {
		    set vars [concat $vars \
			    [DbgNub_uplevelCmd #$level \
			    "$DbgNub(scope)info vars" [list ${current}::*]]]
		}
	    }
	}
    }

    # Construct a list of name/type pairs.

    set result {}
    foreach var $vars {
	# We have to be careful because we cannot call
	# upvar on a qualified namespace variable.  First
	# verify the var exists, then test to see if
	# it is an array.

	if {[DbgNub_uplevelCmd #$level [list info exists $var]]} {
	    upvar #$level $var local
	    if {[array exists local]} {
		lappend result [list $var a]
	    } else {
		lappend result [list $var s]
	    }
	} else {
	    lappend result [list $var s]
	}
    }
    return $result
}

# DbgNub_GetVar --
#
#	Returns a list containing information about each of the
#	variables specified in varList.  The returned list consists of
#	elements of the form {<name> <type> <value>}.  Type indicates
#	if the variable is scalar or an array and is either "s" or
#	"a".  If the variable is an array, the result of an array get
#	is returned for the value, otherwise it is the scalar value.
#	Any names that were specified in varList but are not valid
#	variables will be omitted from the returned list.
#
# Arguments:
#	level		The stack level of the variables in varList.
#	maxlen		The maximum length of data to return for a single
#			element.  If this value is -1, the entire string
#			is returned.
#	varList		A list of variables whose information is returned.
#
# Results:
#	Returns a list containing information about each of the
#	variables specified in varList.  The returned list consists of
#	elements of the form {<name> <type> <value>}. 

proc DbgNub_GetVar {level maxlen varList} {
    global DbgNub
    set result {}
    # Adjust the maxlen to be the last character position
    if {$maxlen > 0} {
	incr maxlen -1
    }
    foreach var $varList {
	# Bugzilla 23008 ...

	# The upvar _can_ fail. Normally 'upvar' on a non-existent
	# variable does not fail, it creates the reference as usual,
	# and also a variable marked as waiting for creation in the
	# source. However if $var is namespaced variable whose parent
	# namespace does not exist yet the latter can't be done, and
	# the upvar fails. We have to catch this. Just continuing is
	# the right thing, as any variable ignored here is simply
	# considered invalid by the frontend.

	if {[DbgNub_catchCmd {
	    upvar #$level $var local
	}]} {
	    continue
	}

	# Remove all traces before getting the value so we don't enter
	# instrumented code or cause other undesired side effects.  Note
	# that we must do this before calling info exists, since that will
	# also trigger a read trace.  
	#
	# There are two types of traces to look out for: scalar and array.
	# Array elements trigger both scalar and array traces.  The current
	# solution is a hack because we are looking for variables that look
	# like name(element).  This won't catch array elements that have been
	# aliased with upvar to scalar names.  The only way to handle that case
	# is to wrap upvar and track every alias.  This is a lot of work for a
	# very unusual case, so we are punting for now.

	set traces [trace vinfo local]
	foreach trace $traces {
	    eval trace vdelete local $trace
	}
	# We use the odd string range call instead of string index
	# to work on 8.0
	if {[string range $var end end] == ")"} {
	    set avar [lindex [split $var "("] 0]
	    upvar #$level $avar alocal

	    set atraces [trace vinfo alocal]
	    foreach trace $atraces {
		eval trace vdelete alocal $trace
	    }
	} else {
	    set atraces {}
	}

	# Now it is safe to check for existence before we attempt to fetch the
	# value. 
	
	if {[DbgNub_uplevelCmd #$level \
		[list DbgNub_infoCmd exists $var]]} {
	    
	    # Fetch the current value.  Note that we have to be careful
	    # when truncating the value.  If we call string range directly
	    # the object will be converted to a string object, losing any
	    # internal rep.  If we copy it first, we can avoid the problem.
	    # Normally this doesn't matter, but for extensions like TclBlend
	    # that rely on the internal rep to control object lifetime, it
	    # is a critical step.

	    # Also, because of a bug in Windows where null values in the env
	    # array are automatically unset, we need to guard against
	    # non-existent values when iterating over array names. Bug: 4120

	    if {$maxlen == -1} {
		if {[array exists local]} {
		    set value {}
		    foreach name [array names local] {
			if {[DbgNub_infoCmd exists local($name)]} {
			    lappend value $name $local($name)
			} else {
			    lappend value $name {}
			}
		    }
		    lappend result [list $var a $value]
		} else {
		    lappend result [list $var s $local]
		}
	    } else {
		if {[array exists local]} {
		    set value {}
		    foreach name [array names local] {
			set copy {}
			if {[DbgNub_infoCmd exists local($name)]} {
			    append copy $local($name)
			} else {
			    append copy {}
			}
			lappend value $name [string range $copy 0 $maxlen]
		    }
		    lappend result [list $var a $value]
		} else {
		    set copy {}
		    append copy $local
		    lappend result [list $var s [string range $copy 0 $maxlen]]
		}
	    }

	}

	# Restore the traces

	foreach trace $traces {
	    eval trace variable local $trace
	}
	foreach trace $atraces {
	    eval trace variable alocal $trace
	}
    }
    return $result
}

# DbgNub_SetVar --
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
#	Returns an empty string.

proc DbgNub_SetVar {level var value} {
    upvar #$level $var local
    if {![DbgNub_infoCmd exists local]} {
	error "No such variable $var"
    }
    if {[array exists local]} {
	foreach name [array names local] {
	    unset local($name)
	}
	array set local $value
    } else {
	set local $value
    }
    return
}

# DbgNub_GetResult --
#
#	Gets the last reported return code and result value.
#
# Arguments:
#	maxlen		The maximum length of data to return for the 
#			result.  If this value is -1, the entire string
#			is returned, otherwise long values are truncated
#			after maxlen bytes.
#
# Results:
#	Returns a list of the form {code result}.

proc DbgNub_GetResult {maxlen} {
    global DbgNub
    
    if {$maxlen == -1} {
	set maxlen end
    } else {
	incr maxlen -1
    }

    return [list $DbgNub(lastCode) \
	    [string range $DbgNub(lastResult) 0 $maxlen]]
}

# DbgNub_PushContext --
#
#	Push the current context and location stack onto the context
#	stack and set up a new context.
#
# Arguments:
#	level		The new stack level.
#	type		The context type.
#	args		Context type specific state.
#
# Results:
#	None.

proc DbgNub_PushContext {level type args} {
    global DbgNub
    lappend DbgNub(contextStack) [list $DbgNub(context) $DbgNub(locations)]
    set DbgNub(locations) {}
    set DbgNub(context) [concat $level $type $args]
    if {$DbgNub(debug) & 1} {
	DbgNub_Log "PUSH CONTEXT:\ncontext = $DbgNub(context)\n\locations = $DbgNub(locations)\ncontextStack = $DbgNub(contextStack)\nstack=$DbgNub(stack)"
    }
    return
}

# DbgNub_PopContext --
#
#	Restore the previous context from the contextStack.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_PopContext {} {
    global DbgNub
    set last [lindex $DbgNub(contextStack) end]
    set DbgNub(contextStack) [lreplace $DbgNub(contextStack) end end]
    set DbgNub(context) [lindex $last 0]
    set DbgNub(locations) [lindex $last 1]
    if {$DbgNub(debug) & 1} {
	DbgNub_Log "POP CONTEXT:\ncontext = $DbgNub(context)\n\locations = $DbgNub(locations)\ncontextStack = $DbgNub(contextStack)\nstack=$DbgNub(stack)"
    }
    return
}

# DbgNub_PushStack --
#
#	Push info about all of the stack frames that have been
#	added after the last stack checkpoint.
#
# Arguments:
#	current		Stack level of current statement.
#	frame		Optional. New stack frame that will be pushed
#			by current statement.
#
# Results:
#	Returns a marker for the end of the stack before any frames
#	were pushed.

proc DbgNub_PushStack {current {frame {}}} {
    global DbgNub

    set oldTop [lindex [lindex $DbgNub(stack) end] 0]
    set marker [expr {[llength $DbgNub(stack)] - 1}]

    for {set level [expr {$oldTop + 1}]} {$level <= $current} {incr level} {
	set name [lindex [DbgNub_infoCmd level $level] 0]

        # Bugzilla 19759, and SF Tcl Bug #545325.
	#
        # The change in the mentioned bug/patch of the tcl core changed
        # the behaviour of [info level] and thus broke the conditional
        # below. Added a second check for 'namespace' to handle this new
        # case.

	if {($name == "") || ($name == "namespace")} {
	    # This is a "namespace eval" so compute the name and push
	    # it onto the stack.
	    if {$DbgNub(itcl76)} {
		set name [DbgNub_uplevelCmd \#$level \
			[list $DbgNub(scope)DbgNub_infoCmd context]]
	    } else {
		set name [DbgNub_uplevelCmd \#$level \
			[list $DbgNub(scope)namespace current]]
	    }

	    # Handle the special case of the [incr Tcl] parser namespace
	    # so classes appear as expected.

	    if {$name == "::itcl::parser"} {
		lappend DbgNub(stack) [list $level class]
	    } else {
		lappend DbgNub(stack) [list $level namespace eval $name]
	    }
	    continue
	}

	# Bugzilla 91407. Handle TclOO methods and procdures first, by
	# trying to get their name and class. If that fails we assume
	# that we are not in an TclOO context and go forward to try
	# other types of context.

	if {[llength [DbgNub_infoCmd commands self]] && ![DbgNub_catchCmd {
	    DbgNub_uplevelCmd \#$level [list self method]
	} res]} {
	    set class [DbgNub_uplevelCmd \#$level [list self class]]
	    set args  [lindex [DbgNub_uplevelCmd \#$level [list DbgNub_infoCmd class definition $class $res]] 0]

	    lappend DbgNub(stack) [list $level method ${class}::$res $args]
	    continue
	}

	# Then handle [incr Tcl] methods and procedures. We check to see
	# if we are in an object context by testing to see where "info"
	# is coming from.  If we're in an object context, we can get all
	# the info we need from the "info function" command.

	if {$DbgNub(itcl76)} {
	    if {[DbgNub_uplevelCmd \#$level {info which info}] \
		    == "::itcl::builtin::info"} {
		lappend DbgNub(stack) [concat $level \
			[DbgNub_uplevelCmd \#$level \
			[list info function $name -type -name -args]]]
		continue
	    }
	} elseif {$DbgNub(itcl4)} {
	    # In itcl 4 the object context is detected by simply
	    # trying to run 'info function' in the current context.
	    # If it doesn't work its not an object context. The
	    # difference to itcl3 is that the info command is not in a
	    # fixed location, but exists in each object namespace
	    # separately, making the original check unusable.

	    set namex [lindex [DbgNub_infoCmd level $level] 1]
	    if {![DbgNub_catchCmd {
		DbgNub_uplevelCmd \#$level [list info function $namex -type -name -args]
	    } res]} {
		lappend DbgNub(stack) [concat $level $res]
		continue
	    }
	} elseif {$DbgNub(namespace)} {
	    # Bugzilla 90179. The script may have regular namespaced
	    # procedures P in the same namespace which also is an itcl
	    # class. In that case the 'info function' will fail on P
	    # and we have to fall back to the regular processing
	    # coming up below at (Y).

	    if {[DbgNub_uplevelCmd \#$level \
		    [list $DbgNub(scope)namespace origin info]] \
		    == "::itcl::builtin::info"} {
		if {![DbgNub_catchCmd {
		    DbgNub_uplevelCmd \#$level [list info function $name -type -name -args]
		} res]} {
		    lappend DbgNub(stack) [concat $level $res]
		    continue
		}
	    }
	}

	# (Y)
	# If we are using namespaces, transform the name to fully qualified
	# form before trying to get the arglist.  Determine whether the
	# name refers to a proc or a command.

	if {$DbgNub(namespace)} {
	    # Check to see if the name exists in the calling context.  If it
	    # isn't present, it must have been deleted while it was on the
	    # stack.  This check must be done before calling namespace origin
	    # below or an error will be generated (Bug: 3613).

	    set infoLevel \#[expr {$level - 1}]
	    if {[DbgNub_uplevelCmd $infoLevel \
		    [list $DbgNub(scope)info commands $name]] == ""} {
		lappend DbgNub(stack) [list $level proc $name (deleted)]
		continue
	    }		

	    # Now determine the fully qualified name.

	    set name [DbgNub_uplevelCmd $infoLevel \
		    [list $DbgNub(scope)namespace origin $name]]

	    # Because of Tcl's namespace design, "info procs" does not
	    # work on qualified names.  The workaround is to invoke the
	    # "info" command inside the namespace.

	    set qual [namespace qualifiers $name]
	    if {$qual == ""} {
		set qual ::
	    }
	    set tail [namespace tail $name]
	    set isProc [namespace eval $qual \
		    [list DbgNub_infoCmd procs $tail]]
	} else {
	    # Check to make sure the command still exists.

	    if {[DbgNub_uplevelCmd \#[expr {$level - 1}] \
		    [list DbgNub_infoCmd commands $name]] == ""} {
		lappend DbgNub(stack) [list $level proc $name (deleted)]
		continue
	    }

	    # Check to see if the command is a proc.

	    set isProc [DbgNub_infoCmd procs $name]
	}

	# Attempt to determine the argument list.

	if {$isProc != ""} {
	    set argList [DbgNub_uplevelCmd \#$level \
		    [list DbgNub_infoCmd args $name]]
	} else {
	    # The command on the stack is not a procedure.
	    # We have to put a special hack in here to work
	    # around a very poor implementation the tk_get*File and
	    # tk_messageBox dialogs on Unix.

	    if {[regexp \
		    {^(::)?tk_(messageBox|getOpenFile|getSaveFile)$} \
		    $name dummy1 dummy2 match]} {
		if {$match == "messageBox"} {
		    set name "tkMessageBox"
		} else {
		    set name "tkFDialog"
		}
		if {$DbgNub(namespace)} {
		    set name "::$name"
		}
		set argList "args"
	    } else {
		set argList ""
	    }
	}
	lappend DbgNub(stack) [list $level "proc" $name $argList]
    }
    if {$frame != {}} {
	lappend DbgNub(stack) $frame
    }
    return $marker
}

# DbgNub_PopStack --
#
#	Pop frames from the stack that were pushed by DbgNub_PushStack.
#
# Arguments:
#	marker		Marker value returned by DbgNub_PushStack
#
# Results:
#	None.

proc DbgNub_PopStack {marker} {
    global DbgNub
    set DbgNub(stack) [lrange $DbgNub(stack) 0 $marker]
    return
}

# DbgNub_CollateStacks --
#
#	Merge the call stack with the instruction stack.  The istack
#	may have more than one frame for any given call stack frame due to
#	virtual frames pushed by commands like "source", but it may also be
#	missing some uninstrumented frames.  Because of this, we have to
#	collate the two stacks to recover the complete stack description.
#
# Arguments:
#	None.
#
# Results:
#	Returns the merged stack.

proc DbgNub_CollateStacks {} {
    global DbgNub

    set result ""

    # Put the current context and location list onto the stack so
    # we can deal with the whole mess at once

    lappend DbgNub(contextStack) [list $DbgNub(context) $DbgNub(locations)]

    if {$DbgNub(debug) & 1} {
	DbgNub_Log "Collate context: $DbgNub(contextStack)\nstack: $DbgNub(stack)"
    }

    set s [expr {[llength $DbgNub(stack)] - 1}]
    set i [expr {[llength $DbgNub(contextStack)] - 1}]

    if {0} {
	DbgNub_Log "COLLATE ___________________________________"
	foreach f $DbgNub(stack) {
	    DbgNub_Log "FRAME__: $f"
	}
	foreach f $DbgNub(contextStack) {
	    DbgNub_Log "CONTEXT: $f"
	}
    }

    while {$i >= 0} {
	set iframes {}

	#DbgNub_Log @i$i

	# Look for the next instrumented procedure invocation so we can match
	# it against the call stack. Generate stack information for each
	# instrumented instruction location that is in a new block or a new
	# scope.

	while {$i >= 0} {
	    set frame [lindex $DbgNub(contextStack) $i]
	    incr i -1
	    set locations [lindex $frame 1]
	    set context   [lindex $frame 0]
	    set temp {}
	    set block {}
	    for {set l [expr {[llength $locations] - 1}]} {$l >= 0} {incr l -1} {
		set location [lindex $locations $l]
		set newBlock [lindex $location 0]
		if {[string compare $newBlock $block] != 0} {
		    set iframes [linsert $iframes 0 \
			    [linsert $context 1 $location]]
		    set block $newBlock
		}
	    }
	    # Add a dummy frame if we have an empty context.
	    if {$context != "" && $locations == ""} {
		set iframes [linsert $iframes 0 [linsert $context 1 {}]]
	    }
	    set type [lindex $context 1]
	    switch $type {
		configure -
		debugger_eval -
		proc -
		class -
		global -
		event -
		uplevel -
		oomethod -
		method -
		source -
		namespace -
		package {
		    break
		}
	    }
	}

	if 0 {
	    foreach f $iframes {
		DbgNub_Log "\tIF: $f"
	    }
	    DbgNub_Log "\tCO: $context"
	}

	# Find the current instrumented statement on the call stack.  Generate
	# stack information for any uninstrumented frames.

	while {$s >= 0} {
	    #DbgNub_Log @s$s

	    set sframe [lindex $DbgNub(stack) $s]
	    incr s -1

	    #DbgNub_Log "\tSF: $sframe"

	    if {[string compare $context $sframe] == 0} {
		#DbgNub_Log "\t\tMATCH/1"
		break
	    } elseif {[string match *(deleted) $sframe] &&
		      ([string compare [lrange $context 0 1] [lrange $sframe 0 1]] == 0)
		  } {
		#DbgNub_Log "\t\tMATCH/2"
		break
	    } elseif {[lindex $context 1] == "oomethod" &&
		      [lindex $sframe 1] == "proc" &&
		      ([lindex $context 0] == [lindex $sframe 0])
		  } {
		# Merging of TclOO method frames to context, which uses 'proc'.
		#DbgNub_Log "\t\tMATCH/3"
		break
	    }

	    #DbgNub_Log "\t\tNULL INSERT"
	    set result [linsert $result 0 [linsert $sframe 1 {}]]
	}
	set result [concat $iframes $result]
    }

    # Add any uninstrumented frames that appear before the first instrumented
    # statement.

    while {$s >= 0} {
	set result [linsert $result 0 [linsert [lindex $DbgNub(stack) $s] 1 {}]]
	incr s -1
    }
    set DbgNub(contextStack) [lreplace $DbgNub(contextStack) end end]
    if {$DbgNub(debug) & 1} {
	DbgNub_Log "Collate result: $result"
    }
    return $result
}

# DbgNub_Proc --
#
#	Define a new instrumented procedure.
#
# Arguments:
#	location	Location that contains the entire definition.
#	name		Procedure name.
#	argList		Argument list for procedure.
#	body		Instrumented body of procedure.
#
# Results:
#	None.

proc DbgNub_Proc {location name argList body} {
    global DbgNub
    
    set ns $DbgNub(scope)
    if {$DbgNub(namespace)} {
	# Create an empty procedure first so we can determine the correct
	# absolute name.
	DbgNub_uplevelCmd 1 [list DbgNub_procCmd $name {} {}]
	set fullName [DbgNub_uplevelCmd 1 \
		[list $DbgNub(scope)namespace origin $name]]

	set nameCmd "\[DbgNub_uplevelCmd 1 \[${ns}list ${ns}namespace origin \[${ns}lindex \[${ns}info level 0\] 0\]\]\]"
    } else {
	set fullName $name

	set nameCmd "\[lindex \[info level 0\] 0\]"
    }

    set DbgNub(proc=$fullName) $location

    # Two variables are substituted into the following string.  The
    # fullName variable contains the full name of the procedure at
    # the time the procedure was created.  The body variable contains
    # the actual "user-specified" code for the procedure. 
    # NOTE: There is some very tricky code at the end relating to unsetting
    # some local variables.  We need to unset local variables that have
    # traces before the procedure context goes away so things look
    # rational on the stack.  In addition, we have to watch out for upvar
    # variables because of a bug in Tcl where procedure arguments that are
    # unset and then later reused as upvar variables will show up in the
    # locals list.  If we did an unset on these, we'd blow away the variable
    # in the other scope.  Instead we just upvar the variable to a dummy
    # variable that will get cleaned up locally.

    return [DbgNub_uplevelCmd 1 [list DbgNub_procCmd $name $argList \
	    "#DBG INSTRUMENTED PROC TAG
    ${ns}upvar #0 errorInfo DbgNub_errorInfo errorCode DbgNub_errorCode
    ${ns}set DbgNub_level \[DbgNub_infoCmd level\]
    DbgNub_PushProcContext \$DbgNub_level
    ${ns}set DbgNub_catchCode \[DbgNub_UpdateReturnInfo \[
        [list DbgNub_catchCmd $body DbgNub_result]\]\]
    ${ns}foreach DbgNub_index \[${ns}info locals\] {
	${ns}if {\[${ns}trace vinfo \$DbgNub_index\] != \"\"} {
	    ${ns}if {\[${ns}catch {${ns}upvar 0 DbgNub_dummy \$DbgNub_index}\]} {
		${ns}catch {${ns}unset \$DbgNub_index}
	    }
	}
    }
    DbgNub_PopContext
    ${ns}return -code \$DbgNub_catchCode -errorinfo \$DbgNub_errorInfo -errorcode \$DbgNub_errorCode \$DbgNub_result"]]
}

# DbgNub_PushProcContext --
#
#	Determine the current procedure context, then push it on the
#	context stack.  This routine handles some of the weird cases
#	like procedures that are being invoked by way of an alias.
#	NOTE: much of this code is identical to that in DbgNub_PushStack.
#
# Arguments:
#	level	The current stack level.
#
# Results:
#	None.

proc DbgNub_PushProcContext {level} {
    global DbgNub
    
    set name [lindex [DbgNub_infoCmd level $level] 0]

    # Bugzilla 91407. Handle TclOO methods and procdures first, by
    # trying to get their name and class. If that fails we assume that
    # we are not in an TclOO context and go forward to try other types
    # of context.
   
    if {[llength [DbgNub_infoCmd commands self]] && ![DbgNub_catchCmd {
	DbgNub_uplevelCmd \#$level [list self method]
    } res]} {
	set class [DbgNub_uplevelCmd \#$level [list self class]]
	set args  [lindex [DbgNub_uplevelCmd \#$level [list DbgNub_infoCmd class definition $class $res]] 0]

	DbgNub_PushContext $level method ${class}::$res $args
	return
    }

    # Bugzilla 38471
    # Handle [incr Tcl] methods and procedures first. We check to see
    # if we are in an object context by testing to see where "info"
    # is coming from.  If we're in an object context, we can get all
    # the info we need from the "info function" command.

    if {$DbgNub(itcl76)} {
	if {[DbgNub_uplevelCmd \#$level {info which info}] \
		== "::itcl::builtin::info"} {

	    set type [DbgNub_uplevelCmd \#$level [list info function $name -type]]
	    set name [DbgNub_uplevelCmd \#$level [list info function $name -name]]
	    set args [DbgNub_uplevelCmd \#$level [list info function $name -args]]
	    DbgNub_PushContext $level $type $name $args
	    return
	}
    } elseif {$DbgNub(namespace)} {
	if {[DbgNub_uplevelCmd \#$level \
		 [list $DbgNub(scope)namespace origin info]] \
		== "::itcl::builtin::info"} {

	    # Bugzilla 90179. The script may have regular namespaced
	    # procedures P in the same namespace which also is an itcl
	    # class. In that case the 'info function' will fail on P
	    # and we have to fall back to the regular processing
	    # coming up below at (X).
	    if {![DbgNub_catchCmd {
		set type [DbgNub_uplevelCmd \#$level [list info function $name -type]]
		set name [DbgNub_uplevelCmd \#$level [list info function $name -name]]
		set args [DbgNub_uplevelCmd \#$level [list info function $name -args]]
	    }]} {
		DbgNub_PushContext $level $type $name $args
		return
	    }
	}
    }

    # (X).
    # If we are using namespaces, transform the name to fully qualified
    # form before trying to get the arglist.  Determine whether the
    # name refers to a proc or a command.

    if {$DbgNub(namespace)} {
	set qualName [DbgNub_uplevelCmd \#[expr {$level - 1}] \
		[list $DbgNub(scope)namespace origin $name]]

	if {$qualName == ""} {
	    DbgNub_PushContext $level "proc" $name {}

	    # Exiting the proc here, otherwise the code will push the
	    # proc a second time (see at end of proc).
	    return
	} else {
	    set name $qualName
	}

	# Because of Tcl's namespace design, "info procs" does not
	# work on qualified names.  The workaround is to invoke the
	# "info" command inside the namespace.

	set qual [namespace qualifiers $name]
	if {$qual == ""} {
	    set qual ::
	}
	set tail [namespace tail $name]
	set isProc [namespace eval $qual [list DbgNub_infoCmd procs $tail]]
    } else {
	set isProc [DbgNub_infoCmd procs $name]
    }

    if {$isProc != ""} {
	set args [DbgNub_uplevelCmd \#$level [list DbgNub_infoCmd args $name]]
    } else {
	set args ""
    }
    DbgNub_PushContext $level "proc" $name $args
    return
}

# Bugzilla 91407.
# DbgNub_WrapOOBody --
#
#	Define a new instrumented TclOO function, adding the standard
#	prefix/suffix to the body, if possible.  The last argument is
#	expected to be the body of the function.
#
# Arguments:
#	args		The command and all of its args, the last of which
#			must be the body.
#
# Results:
#	None.

proc DbgNub_WrapOOBody {args} {
    global DbgNub
    upvar #0 DbgNub(scope) ns
    set body [lindex $args end]
    set args [lrange $args 0 [expr {[llength $args] - 2}]]
    if {[string index $body 0] != "@"} {
	   
	set body "#DBG INSTRUMENTED PROC TAG
    ${ns}upvar #0 errorInfo DbgNub_errorInfo errorCode DbgNub_errorCode
    ${ns}set DbgNub_level \[DbgNub_infoCmd level\]
    ${ns}eval \[${ns}list DbgNub_PushContext \$DbgNub_level\] oomethod \[self class\]::\[self method\] \[list \[DbgNub_OOMethodArguments\]\]
    ${ns}set DbgNub_catchCode \[DbgNub_UpdateReturnInfo \[
        [list DbgNub_catchCmd $body DbgNub_result]\]\]
    ${ns}foreach DbgNub_index \[${ns}info locals\] {
	${ns}if {\[${ns}trace vinfo \$DbgNub_index\] != \"\"} {
	    ${ns}if {\[${ns}catch {${ns}upvar 0 DbgNub_dummy \$DbgNub_index}\]} {
		${ns}catch {${ns}unset \$DbgNub_index}
	    }
	}
    }
    DbgNub_PopContext
    ${ns}return -code \$DbgNub_catchCode -errorinfo \$DbgNub_errorInfo -errorcode \$DbgNub_errorCode \$DbgNub_result"
    }
    return [DbgNub_uplevelCmd 1 $args [list $body]]
}

proc DbgNub_OOMethodArguments {} {
    set c [uplevel 1 [list self class]]
    set m [uplevel 1 [list self method]]

    #DbgNub_Log "OODefinition ($c, $m)"

    if {$m == "<constructor>"} {
	return [lindex [info class constructor $c] 0]
    } elseif {$m == "<destructor>"} {
	return {}; #[list {} [info class destructor $c]]
    } else {
	return [lindex [info class definition $c $m] 0]
    }
}

# DbgNub_WrapItclBody --
#
#	Define a new instrumented [incr Tcl] function, adding the standard
#	prefix/suffix to the body, if possible.  The last argument is
#	expected to be the body of the function.
#
# Arguments:
#	args		The command and all of its args, the last of which
#			must be the body.
#
# Results:
#	None.

proc DbgNub_WrapItclBody {args} {
    global DbgNub
    upvar #0 DbgNub(scope) ns
    set body [lindex $args end]
    set args [lrange $args 0 [expr {[llength $args] - 2}]]
    if {[string index $body 0] != "@"} {

	if {$DbgNub(itcl4)} {
	    # Bug 106283. Switch frame back from -1.
	    # Apparently a beta required the -1. Not supported.
	    # All itcl4 since at least b7 use frame 0 again.
	    set frame  0
	    set offset 1
	} else {
	    set frame  0
	    set offset 0
	}

	set body "#DBG INSTRUMENTED PROC TAG
    ${ns}upvar #0 errorInfo DbgNub_errorInfo errorCode DbgNub_errorCode
    ${ns}set DbgNub_level \[DbgNub_infoCmd level\]
    ${ns}eval \[${ns}list DbgNub_PushContext \$DbgNub_level\] \[info function \[${ns}lindex \[info level $frame\] $offset\] -type -name -args\]
    ${ns}set DbgNub_catchCode \[DbgNub_UpdateReturnInfo \[
        [list DbgNub_catchCmd $body DbgNub_result]\]\]
    ${ns}foreach DbgNub_index \[${ns}info locals\] {
	${ns}if {\[${ns}trace vinfo \$DbgNub_index\] != \"\"} {
	    ${ns}if {\[${ns}catch {${ns}upvar 0 DbgNub_dummy \$DbgNub_index}\]} {
		${ns}catch {${ns}unset \$DbgNub_index}
	    }
	}
    }
    DbgNub_PopContext
    ${ns}return -code \$DbgNub_catchCode -errorinfo \$DbgNub_errorInfo -errorcode \$DbgNub_errorCode \$DbgNub_result"
    }
    return [DbgNub_uplevelCmd 1 $args [list $body]]
}

# DbgNub_WrapItclConfig --
#
#	Define a new [incr Tcl] config body.  These bodies run in a
#	namespace context instead of a procedure context, so we need to
#	call a function instead of putting the code inline.
#
# Arguments:
#	args	The command that defines the config body, the last argument
#		of which contains the body script.
#
# Results:
#	Returns the result of defining the config body.

proc DbgNub_WrapItclConfig {args} {
    set body [lindex $args end]
    set args [lrange $args 0 [expr {[llength $args] - 2}]]
    if {[string index $body 0] != "@"} {
	set body [list DbgNub_ItclConfig $body]
    }
    return [DbgNub_uplevelCmd 1 $args [list $body]]
}

# DbgNub_ItclConfig --
#
#	Perform an [incr Tcl] variable configure operation.  This is
#	basically just a namespace eval, but we want it to behave like
#	a procedure call in the interface.
#
# Arguments:
#	args	The original body.
#
# Results:
#	Returns the result of evaluating the body.

proc DbgNub_ItclConfig {body} {
    global errorInfo errorCode DbgNub

    set level [expr {[DbgNub_infoCmd level]-1}]
    DbgNub_PushContext $level configure

    # Replace the current stack frame with a "configure" frame so we don't
    # end up with a wierd namespace eval on the stack.

    set marker [DbgNub_PushStack [expr {$level-1}] [list $level configure]]
    set code [DbgNub_catchCmd \
	    {DbgNub_uplevelCmd 1 $body} result]
    DbgNub_PopStack $marker

    # Check to see if we are in the middle of a step-out operation and
    # we are unwinding from the initial context.

    if {$DbgNub(stepOutLevel) == [llength $DbgNub(contextStack)]} {
	set DbgNub(stepOutLevel) {}
	set DbgNub(breakNext) 1
    }
    DbgNub_PopContext

    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# DbgNub_Constructor --
#
#	Define a new instrumented [incr Tcl] constructor.
#
# Arguments:
#	cmd		"constructor"
#	argList		Argument list for method.
#	args		The body arguments
#
# Results:
#	None.

proc DbgNub_Constructor {args} {
    # syntax: ?protection? cmd argList body...

    set prot 0
    if {[lsearch -exact {public private protected} [lindex $args 0]] >= 0} {
	set prot 1
	set protection [lindex $args 0]
	set args [lrange $args 1 end]
    }
    set cmd     [lindex $args 0]
    set argList [lindex $args 1]
    set args    [lrange $args 2 end]

    if {[llength $args] == 2} {
	# The initializer script isn't a procedure context.  It's more
	# like a namespace eval.  In order to get return code handling to
	# work properly, we need to call a procedure that will push/pop
	# the context and clean up the return code properly.

	set body1 [list [list DbgNub_ConstructorInit [lindex $args 0]]]
    } else {
	# Set the first body to null so it gets thrown away by the concat
	# in the uplevel command.

	set body1 {}
    }
    set body2 [list [lindex $args end]]

    if {$prot} {
	return [DbgNub_uplevelCmd 1 [list DbgNub_WrapItclBody $protection $cmd $argList] \
		    $body1 $body2]
    } else {
	return [DbgNub_uplevelCmd 1 [list DbgNub_WrapItclBody $cmd $argList] \
		    $body1 $body2]
    }
}

# DbgNub_ConstructorInit --
#
#	This function pushes a context for the init block of a constructor.
#
# Arguments:
#	body		The body of code to evaluate.
#
# Results:
#	Returns the result of evaluating the body.

proc DbgNub_ConstructorInit {body} {
    global errorInfo errorCode

    # Determine the calling context.

    set level [expr {[DbgNub_infoCmd level] - 1}]
    eval [list DbgNub_PushContext $level] [DbgNub_uplevelCmd 1 \
	    {info function [lindex [info level 0] 0] -type -name -args}]

    set code [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $body} result]

    DbgNub_PopContext
    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# DbgNub_Class --
#
#	Push a new context for a class command.  This is really a
#	namespace eval so, it needs to fiddle with the step level.
#
# Arguments:
#	cmd		Should be "class".
#	name		The name of the class being defined.
#	body		The body of the class being defined.
#
# Results:
#	Returns the result of evaluating the class command.

proc DbgNub_Class {cmd name body} {
    global errorInfo errorCode DbgNub

    DbgNub_PushContext [DbgNub_infoCmd level] class

    incr DbgNub(stepLevel)
    if {$DbgNub(stepOutLevel) != {}} {
	incr DbgNub(stepOutLevel)
    }
    set code [DbgNub_catchCmd \
	    {DbgNub_uplevelCmd 1 [list $cmd $name $body]} result]
    if {$DbgNub(stepOutLevel) != {}} {
	incr DbgNub(stepOutLevel) -1
    }
    incr DbgNub(stepLevel) -1
    DbgNub_PopContext

    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# DbgNub_NamespaceEval --
#
#	Define a new instrumented namespace eval.  Pushes a new context
#	and artificially bumps the step level so step over will treat
#	namespace eval like any other control structure.
#
# Arguments:
#	args	The original namespace command.
#
# Results:
#	None.

proc DbgNub_NamespaceEval {args} {
    global errorInfo errorCode DbgNub
    set level [DbgNub_infoCmd level]

    if {$DbgNub(itcl76)} {
	set name [lindex $args 1]
	set cmd [list $DbgNub(scope)DbgNub_infoCmd context]
    } else {
	set name [lindex $args 2]
	set cmd [list $DbgNub(scope)namespace current]
    }

    if {![string match ::* $name]} {
	set name [DbgNub_uplevelCmd 1 $cmd]::$name
    }
    regsub -all {::+} $name :: name

    # Bugzilla 23352
    # Remove trailing colons to normalize the namespace name even further.
    # Bugzilla 37063
    # But not if the name is '::', i.e. the global namespace.

    if {[string compare $name "::"] != 0} {
	set name [string trimright $name :]
    }

    DbgNub_PushContext $level "namespace eval $name"
    incr DbgNub(stepLevel)
    if {$DbgNub(stepOutLevel) != {}} {
	incr DbgNub(stepOutLevel)
    }
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd 1 $args
    } result]
    if {$DbgNub(stepOutLevel) != {}} {
	incr DbgNub(stepOutLevel) -1
    }
    incr DbgNub(stepLevel) -1
    DbgNub_PopContext

    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# DbgNub_WrapCommands --
#
#	This command is invoked at the beginning of every instrumented
#	procedure.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_WrapCommands {} {
    global DbgNub errorInfo errorCode

    foreach cmd $DbgNub(wrappedCommandList) {
	if {$cmd == "rename"} continue

	rename $cmd DbgNub_${cmd}Cmd
	rename DbgNub_${cmd}Wrapper $cmd
    }

    # Handle additional external commands ...

    foreach cmd $DbgNub(externalWrappedCommandList) {

	# NOTE: We have to check if the external command lives in a
	# namespace. We ignore the command, if the interpreter doesn't
	# know namespaces, but the command needs them.

	if {[regexp {::} $cmd]} {
	    # Namespaced command
	    # Bug 84699.
	    if {[lindex [split [DbgNub_infoCmd tclversion] .] 0] < 8} {
		# Interpreter is pre-8, no namespaces, ignore the
		# command, and its wrapper.
		continue
	    }
	    # Interpreter is ok, can handle namespaces.
	    # We save the original in the same namespace.

	    set nocmd [namespace qualifiers $cmd]::DbgNub_[namespace tail $cmd]Cmd

	    regsub -all {::} $cmd {__} x
	    set nwcmd DbgNub_${x}Wrapper
	    unset x

	} else {
	    # No namespaces, regular naming of original and wrapper
	    # commands.
	    set nocmd DbgNub_${cmd}Cmd
	    set nwcmd DbgNub_${cmd}Wrapper
	}

	if {[DbgNub_catchCmd {
	    rename $cmd $nocmd
	}]} {
	    # Squish the error we caught, to avoid confusing users.
	    set errorInfo {}
	    set errorCode NONE

	    # The command is not statically linked into the core
	    # running the application. Set it on the list of
	    # commands to watch out for (proc, load)

	    lappend DbgNub(externalWatchOut) $cmd
	}
	# NOTE: If namespaced commands managed to come here the rename
	# auto-creates the namespace, if not present already.
	rename $nwcmd $cmd
    }

    # Need to be a little careful when renaming rename itself...
    rename rename DbgNub_renameCmd
    DbgNub_renameCmd DbgNub_renameWrapper rename
    return
}

# DbgNub_exitWrapper --
#
#     Called whenever the application invokes "exit".  Calls the coverage
#     check command before exiting.
#
# Arguments:
#     args    Arguments passed to original exit call.
#
# Results:
#     Returns the same result that the exit call would have.

proc DbgNub_exitWrapper {args} {
    global DbgNub

    # Andreas K. May 8, 2003.

    # Bug fix: Deactivated the condition. Meaning that the code in
    # the condition is always executed. As the frontend knowns about
    # coverage (or not) too this is no problem from that side if
    # coverage is disabled.

    # It has one important benefit however: The immediate exit is
    # turned into a negiotiated delayed shutdown of the application,
    # giving the frontend the time to process any other messages which
    # are still in the queue before this BREAK. This is a platform
    # inconsistency ... On Liunx/Unix the socket does not report eof
    # until the messages are processed, even if the nub is already
    # gone. On windows however closing the application seems to cause
    # the socket system to discard everything which is not yet read by
    # the receiver and report eof immediately. The effect is that
    # STDOUT messages, and thus application output, can get lost if
    # the application just exits during a session (For example 'go'
    # and no break point in sight before the exit).

    # With this change no output is lost.

    ## if {1 || $DbgNub(cover)} {}
	# Note. The 'exit' used for [bgNub_Break]. Causes the
	# frontend to believe that the nub is dead. The
	# frontend actually contains special code in dbg.tcl
	# (HandleNubEvent, arm BREAK) which automatically
	# sends a DbgNub_Run back to us. Without that this
	# piece of code would wait forever on the frontend.

	set level [expr {[DbgNub_infoCmd level] - 1}]
	set cmd "DbgNub_Break $level exit $args"
	eval $cmd
    ## {}

    set exitCmd "DbgNub_exitCmd $args"
    eval $exitCmd
}


# DbgNub_catchWrapper --
#
#	Called whenever the application invokes "catch".  Changes the error
#	handling so we don't report errors that are going to be caught.
#
# Arguments:
#	args	Arguments passed to original catch call.
#
# Results:
#	Returns the result of evaluating the catch statement.

proc DbgNub_catchWrapper {args} {
    global DbgNub errorCode errorInfo
    set oldCatch $DbgNub(catch)
    set DbgNub(catch) 0
    set code [DbgNub_catchCmd {DbgNub_uplevelCmd DbgNub_catchCmd $args} result]
    if {$code == 1} {
	regsub -- DbgNub_catchCmd $errorInfo catch errorInfo
    }
    set DbgNub(errorHandled) 0
    set DbgNub(catch) $oldCatch
    if {[DbgNub_infoCmd exists DbgNub(returnState)]} {
	unset DbgNub(returnState)
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_Return --
#
#	Called whenever the application invokes "return".  We need
#	to manage a little extra state when the user uses the -code
#	option because we can't determine the actual code used at the
#	call site.  All calls to "return" have a result code of 2 and the
#	real value is stored inside the interpreter where we can't get at
#	it.  So we cache the result code in global state and fetch it back
#	at the call site so we can invoke the standard "return" at the
#	proper scope with the proper -code.
#
# Arguments:
#	args	Arguments passed to original return call.
#
# Results:
#	Returns the result of evaluating the return statement.

proc DbgNub_Return {args} {
    global DbgNub errorCode errorInfo

    # Get the value of the -code option if given.  (If it isn't given 
    # then Tcl assumes it is -code OK; we assume the same.

    set realCode "ok"
    set realErrorCode ""
    set realErrorInfo ""
    set argc [llength $args]
    for {set i 0} {$i < $argc} {incr i 2} {
	set arg [lindex $args $i]
	if {$arg == "-code"} {
	    set realCode [lindex $args [expr {$i + 1}]]
	} elseif {$arg == "-errorcode"} {
	    set realErrorCode [lindex $args [expr {$i + 1}]]
	} elseif {$arg == "-errorinfo"} {
	    set realErrorInfo [lindex $args [expr {$i + 1}]]
	}
    }
    

    # Invoke the return command so we can see what the result would have been.
    # We need to check to see if the call to return failed so we can clean up
    # the errorInfo.  If the call succeeds, we store the real return code so we
    # can retrieve it later.

    set code [DbgNub_catchCmd {DbgNub_uplevelCmd $DbgNub(scope)return $args} result]
    if {$code == 1} {
	regsub -- DbgNub_Return $errorInfo catch errorInfo
    } else {
	set DbgNub(returnState) [list $realCode $realErrorCode $realErrorInfo]
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_UpdateReturnInfo --
#
#	Restore the errorCode and errorInfo that was cached by DbgNub_Return.
#	Test to see if a step out is in progress and convert it to an
#	interrupt if necessary. This routine is called in the procedure and
#	method header code inserted by the instrumenter as well as the
#	wrapper for the "source" command.
#
# Arguments:
#	code	The result code of the last command.
#
# Results:
#	Returns the new result code, modifies errorCode/errorInfo as
#	needed and creates upvar'd versions of errorCode/errorInfo in
#	the caller's context.

proc DbgNub_UpdateReturnInfo {code} {
    global errorInfo errorCode DbgNub
    if {$code == 2 || $code == "return"} {
	if {[DbgNub_infoCmd exists DbgNub(returnState)]} {
	    set code [lindex $DbgNub(returnState) 0]
	    set errorCode [lindex $DbgNub(returnState) 1]
	    set errorInfo [lindex $DbgNub(returnState) 2]
	    unset DbgNub(returnState)
	} else {
	    set code 0
	}
    }
    DbgNub_uplevelCmd 1 "
	$DbgNub(scope)upvar #0 errorInfo DbgNub_errorInfo
	$DbgNub(scope)upvar #0 errorCode DbgNub_errorCode
    "

    # Check to see if we are in the middle of a step-out operation and
    # we are unwinding from the initial context.

    if {$DbgNub(stepOutLevel) == [llength $DbgNub(contextStack)]} {
	set DbgNub(stepOutLevel) {}
	set DbgNub(breakNext) 1
    }
	
    return $code
}

# DbgNub_loadWrapper --
#
#	Called whenever the [load] command is invoked and ensures
#	that any wrapper for external commands is kept in place
#	and not overwritten.
#
# Arguments:
#	args	Arguments passed to original load call.
#
# Results:
#	Returns the result of evaluating the load statement.

proc DbgNub_loadWrapper {args} {
    global DbgNub errorInfo errorCode

    # Keep track of load's nested in load's. Only the outermost
    # load is allowed to save/restore externals.

    if {!$DbgNub(inLoad)} {
	if {[llength $DbgNub(externalWatchOut)]} {
	    # We have wrappers to save. We do not try to determine which
	    # of the commands we are looking for are created during the
	    # the actual load. We save them all, and restore all later.

	    foreach cmd $DbgNub(externalWatchOut) {
		# HACK: Handle namespaced commands correctly. They will
		# appear here if and only if the interpreter can handle
		# namespaces. And their namespaces will exist already.
		regsub -all {::} $cmd {__} x
		set nwcmd DbgNub_${x}Wrapper
		unset x
		DbgNub_renameCmd $cmd $nwcmd
	    }
	}

	# Bugzilla 91407. We restore the original info command so that
	# packages which manipulate the ensemble (like TclOO) can do
	# so without running against the debugger's wrapper not being
	# such. Note that in the section of code from here to
	# restoration of the wrapper 'info' is not used.

	DbgNub_renameCmd ::info ::DbgNub_infoWrapper
	DbgNub_renameCmd ::DbgNub_infoCmd ::info

	# Bugzilla 93163. This is not quite true. Inside the loadCmd
	# below the package initialization function may run Tcl
	# code. It may especially define procedures, which are run
	# through the procWrapper, which uses DbgNub_infoCmd. This
	# diverts into 'unknown' at which point 'catch' is used, whose
	# catchWrapper is also active, using the DbgNub_infoCmd,
	# calling into 'unknown' again, for the same command. Infinity
	# beckons. We create an 'alias' using the builtin here.

	DbgNub_procCmd ::DbgNub_infoCmd {args} {
	    return [eval [linsert $args 0 ::info]]
	}
    }

    incr DbgNub(inLoad)

    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd 1 [linsert $args 0 DbgNub_loadCmd]
    } result] ; # {}
    incr DbgNub(inLoad) -1

    # Save error data to prevent the wrap manipulation below from
    # disturbing it.
    set einfo $errorInfo
    set ecode $errorCode

    if {!$DbgNub(inLoad)} {
	if {[llength $DbgNub(externalWatchOut)]} {
	    # Now restore all wrappers. Also save
	    # the commands we watched for, if present.

	    foreach cmd $DbgNub(externalWatchOut) {
		if {[regexp {::} $cmd]} {
		    set nocmd [namespace qualifiers $cmd]::DbgNub_[namespace tail $cmd]Cmd
		    regsub -all {::} $cmd {__} x
		    set nwcmd DbgNub_${x}Wrapper
		    unset x
		} else {
		    set nocmd DbgNub_${cmd}Cmd
		    set nwcmd DbgNub_${cmd}Wrapper
		}

		DbgNub_catchCmd { DbgNub_renameCmd $cmd $nocmd }
		DbgNub_renameCmd $nwcmd $cmd
	    }
	}

	# Bugzilla 91407. And restore our wrapper again.
	# Bugzilla 93163

	DbgNub_renameCmd ::DbgNub_infoCmd {}
	DbgNub_renameCmd ::info ::DbgNub_infoCmd
	DbgNub_renameCmd ::DbgNub_infoWrapper ::info
    }

    # Restore information to show the load results
    set errorInfo $einfo
    set errorCode $ecode

    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_loadCmd load]
	set DbgNub(cleanWrapper) {DbgNub_loadCmd load}
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}


# DbgNub_procWrapper --
#
#	Called whenever the application invokes "proc" on code that has
#	not been instrumented.  This allows for dynamic procedures to
#	be instrumented.  This feature may be turned off by the user.
#	The DbgNub(dynProc) flag can be used to turn this feature on
#	or off.
#
# Arguments:
#	args	Arguments passed to original proc call.
#
# Results:
#	Returns the result of evaluating the proc statement.

proc DbgNub_procWrapper {args} {
    global DbgNub errorInfo errorCode
    set length [llength $args]
    set unset 0

    set wrapName {}

    if {($length == 3) && ($DbgNub(socket) != -1)} {

	# Don't allow redefining of builtin commands that the 
	# debugger relies on.

	set searchName [lindex $args 0]
	set level [expr {[DbgNub_infoCmd level] - 1}]
	if {![DbgNub_okToRename $searchName $level]} {

	    # Bugzilla 39620. It is possible to define such a proc
	    # without crashing, if the original command was renamed
	    # before, and the new procedure uses the original, under
	    # its new name.  I.e.  an application or library wrapping
	    # its own code around the builtin command, like is done by
	    # the debugger as well (See DbgNub_WrapCommands).

	    # We force the warning into the frontend eval console by
	    # sending a message directly to the error channel, instead
	    # of going through either builtin puts (DbgNub_putsCmd),
	    # or whatever redirection the user has chosen.

	    DbgNub_SendMessage STDERR \
		"Warning (issued by the debugger backend).\nOverwriting \
                \"[lindex $args 0]\" with a procedure may crash the debugger.\n"
	}

	# Check if the name is on the list of commands to watch out
	# for. If yes we have to go through a number of contortions
	# to ensure that the wrapper defined by a PDX is kept in
	# place. Here we save it and remember that a wrapper was
	# saved.

	if {[lsearch -exact $DbgNub(externalWatchOut) $searchName] >= 0} {
	    # Save the wrapper ...

	    rename $searchName DbgNub_${searchName}Wrapper
	    set wrapName $searchName
	}

	set body [lindex $args end]
	if {[regexp "\n# DBGNUB START: (\[^\n\]*)\n" $body dummy data]} {
	    # This body is already instrumented, so we should not reinstrument
	    # it, but we do want to define it as an instrumented procedure.

	    set icode [linsert $args 0 DbgNub_Proc [lindex $data 0]]
	} elseif {$DbgNub(dynProc) && !$DbgNub(inExclude) \
		&& ($DbgNub(autoLoad) \
		    || (!$DbgNub(inRequire) && !$DbgNub(inAutoLoad)))} {
	    # This is a dynamic procedure, so we need to instrument it first.
	    # The code we get back starts with a DbgNub_Do which we don't want
	    # to run so we have to strip out the actual proc command.

	    set script [linsert $args 0 "proc"]
	    set icode  [DbgNub_Instrument "" $script]

	    if {$icode == ""} {
		# Bugzilla 19824 ...
		# Instrumenting the procedure failed (parse errors and
		# the user aborted the process). We now have to handle
		# the procedure as if no instrumentation had to be
		# done at all (See below, [x]).

		set icode [linsert $args 0 "DbgNub_procCmd"]
		set unset 1

	    } else {
		set loc [lindex $icode 2]
		set cmd [lindex $icode 3]

		# Now change things so we are calling DbgNub_Proc instead of
		# proc so this routine gets created like a normal instrumented
		# procedure.

		set icode [lreplace $cmd 0 0 "DbgNub_Proc" $loc]
	    }
	} else {
	    # [x]
	    # This is a dynamic procedure, but we are ignoring them
	    # right now per user setting.

	    set icode [linsert $args 0 "DbgNub_procCmd"]
	    set unset 1
	}
	set code [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $icode} result]
    } else {
	# This isn't a well formed call to proc, or we aren't connected
	# to the debugger any longer, so let it execute without interference. 

	set icode [linsert $args 0 DbgNub_procCmd]
	set unset 1
    }
    set code [DbgNub_catchCmd {DbgNub_uplevelCmd 1 $icode} result]
    
    if {$unset} {
	# We need to check if we are replacing an already
	# instrumented procedure with an uninstrumented body.
	# If so, we need to clean up some state.

	set name [lindex $args 0]
	if {$DbgNub(namespace)} {
	    set name [DbgNub_uplevelCmd 1 \
		    [list $DbgNub(scope)namespace which $name]]
	}
	if {[DbgNub_infoCmd exists DbgNub(proc=$name)]} {
	    unset DbgNub(proc=$name)
	}
    }

    if {$wrapName != {}} {
	# A wrapper was saved. Save the original command defined
	# here and reinsert the wrapper.

	rename $wrapName     DbgNub_${wrapName}Cmd
	rename DbgNub_${wrapName}Wrapper $wrapName
    }

    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_procCmd proc]
	set DbgNub(cleanWrapper) {DbgNub_procCmd proc}
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_infoWrapper --
#
#	Called whenever the application invokes "info".  Changes the
#	output of some introspection commands to hide the debugger's
#	changes to the environment.
#
# Arguments:
#	args	Arguments passed to original info call.
#
# Results:
#	Returns the result of evaluating the info statement.

proc DbgNub_infoWrapper {args} {
    global DubNub errorCode errorInfo
    set code [DbgNub_catchCmd {DbgNub_uplevelCmd DbgNub_infoCmd $args} result]
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_infoCmd info]
	set DbgNub(cleanWrapper) {DbgNub_infoCmd info}
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }
    switch -glob -- [lindex $args 0] {
	comm* -
	pr* {
	    set newResult ""
	    foreach x $result {
		if {![string match DbgNub_* $x]} {
		    # Strip out the commands we wrapped.
		    global DbgNub

		    if {[lsearch $DbgNub(wrappedCommandList) $x] != -1} {
			if {[string match p* [lindex $args 0]]} {
			    continue
			}
		    }
		    lappend newResult $x
		}
	    }
	    set result $newResult
	}
	loc* -
	v* -
	g* {
	    # We strip out the DbgNub variable and any variable that
	    # begins with DbgNub_

	    set i [lsearch -exact $result DbgNub]
	    if {$i != -1} {
		set result [lreplace $result $i $i]
	    }
	    set newResult ""
	    foreach x $result {
		if {[string match DbgNub_* $x]} {
		    continue
		}
		lappend newResult $x
	    }
	    set result $newResult
	}
	b* {
	    if {[string compare "#DBG INSTRUMENTED PROC TAG" $result] == -1} {
		global DbgNub

		set name [lindex $args 1]
		if {$DbgNub(namespace)} {
		    set name [DbgNub_uplevelCmd 1 \
			    [list $DbgNub(scope)namespace origin $name]]
		}
		if {! [DbgNub_infoCmd exists DbgNub(proc=$name)]} {
		    error "debugger in inconsistent state"
		    # The procedure asked for has an instrumented
		    # body, but was not registered as such, i.e. we
		    # have no location to given to the
		    # frontend. Meaning that the frontend will be
		    # unable to give us the uninstrumented body of
		    # this procedure.
		}
		DbgNub_SendMessage PROCBODY $DbgNub(proc=$name)
		DbgNub_ProcessMessages 1
		return $DbgNub(body)
	    }
	}
	sc* {
	    global DbgNub
	    if {[llength $args] == 2} {
		set DbgNub(script) [lreplace $DbgNub(script) end end [lindex $args end]]
	    }
	    return [lindex $DbgNub(script) end]
	}
	frame {
	    # Retrieve the current full frame stack. Then remove all frames which belong to the debugger.
	    # Then compute and/or use the level information.

	    # NOTE: When dumping the stack of frames from the
	    # application this means that each call computes the same
	    # thing over and over. Making the operation quadratic,
	    # instead of linear as it normally is.
	    #
	    # It might be useful to try and cache results. But that is
	    # also iffy, as it is difficult detect when we can keep
	    # the cache versus must discard and recalculate. So for
	    # now we do not attempt this, and live with the perf penalty.

	    set n [DbgNub_infoCmd frame]
	    set frames {}
	    for {set k 1} {$k <= $n} {incr k} {
		set theframe [DbgNub_infoCmd frame $k]
		array set deframe $theframe
		set discard [expr {
		   [string match DbgNub_*   $deframe(cmd)] ||
		   [string match *lastCode*lastResult* $deframe(cmd)]
	        }]
		unset deframe
		if {$discard} continue
		lappend frames $theframe
	    }

	    # Note 2: The above hides the debugger specific frames
	    # outright. It still leaks some information that we are in
	    # the debugger, because the 'proc' field can show
	    # ::DbgNub_Do as the command environment. To remove that
	    # leak the loop above will have to keep state between
	    # frames and use it to rewrite the kept frames
	    # (replacement of type and location data). That will be
	    # quite more effort, and is not done. ... Looking at the
	    # full stack it might not even be possible, the data we
	    # need may not exist (anymore).

	    set n [llength $frames]
	    if {[llength $args] == 1} {
		# Call was query for number of frames, return computed
		# value based on the modified (shrunken) stack.
		return $n
	    } elseif {[llength $args] == 2} {
		# Query is for frame data.
		set level [lindex $args 1]
		# Check modified level boundaries.
		if {($level > $n) || ($level <= -$n)} {
		    return -code error "bad level \"$level\""
		}
		# Reindex into the modified stack.
		if {$level > 0} {
		    incr level -1
		} else {
		    set level [expr {1 - $level}]
		}
		# And return chosen frame from the kept/modified stack.
		return [lindex $frames $level]
	    }
	}
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_sourceWrapper --
#
#	Called whenever the application tries to source a file.
#	Loads the file and passes the contents to the debugger to
#	be instrumented.
#
# Arguments:
#	file	File name to source.
#
# Results:
#	Returns the result of evaluating the instrumented code.

proc DbgNub_sourceWrapper {args} {
    global DbgNub errorCode errorInfo

    if {[llength $args] == 1} {
	set file [lindex $args 0]
    } else {
	# Let the real source command generate the error for bad args.

	set code [DbgNub_catchCmd {DbgNub_uplevelCmd DbgNub_sourceCmd $args} \
		result]
	set errorInfo ""
	regsub -- "DbgNub_sourceCmd" $result "source" result
	return -code $code -errorcode $errorCode $result
    }

    # Short circuit the procedure if we aren't connected to the debugger.

    if {$DbgNub(socket) == -1} {
	set code [DbgNub_catchCmd {
	    DbgNub_uplevelCmd [list DbgNub_sourceCmd $file]
	} result]
	return -code $code -errorcode $errorCode -errorinfo $errorInfo \
		$result
    }

    # If the users preferences indicate that autoloaded scripts 
    # are not to be instrumented, then check to see if this file
    # is being autoloaded.  The test is to look up the stack, if
    # the "auto_load" or "auto_import" procs are on the stack, then we are
    # autoloading.

    if {!$DbgNub(autoLoad)} {
	set DbgNub(inAutoLoad) 0
	foreach stack $DbgNub(stack) {
	    if {([lindex $stack 1] == "proc") \
		    && [regexp {^(::)?auto_(load|import)$} \
			[lindex $stack 2]]} {
		set DbgNub(inAutoLoad) 1
		break
	    }
	}
    }

    # Clear the inExclude flag since we are about to source a new file and
    # any previous exclude flag doesn't apply until we are done.

    set oldExclude $DbgNub(inExclude)
    set DbgNub(inExclude) 0

    # We now need to calculate the absolute path so the engine will be
    # able to point to this file.  We later pass the script to the
    # engine to be processed.

    set oldwd [pwd]
    cd [file dir $file]
    set absfile [file join [pwd] [file tail $file]]
    cd $oldwd

    if {!$DbgNub(autoLoad) && ($DbgNub(inAutoLoad) || $DbgNub(inRequire))} {
	set dontInstrument 1
    } else {
	# Check to see if this file matches any of the included file
	# patterns.  If not set the dontInstrument flag to true,
	# so the file is not instrumented.  Otherwise, check to see if
	# it matches one of the excluded file patterns.

	set dontInstrument 1
	foreach pattern $DbgNub(includeFiles) {
	    if {[string match $pattern $absfile]} {
		set dontInstrument 0
		break
	    }
	}	
	if {$dontInstrument} {
	    set DbgNub(inExclude) 1
	} else {
	    # Check to see if this file matches any of the excluded file
	    # patterns.  If it does, set the dontInstrument flag to true,
	    # so the file is not instrumented.

	    foreach pattern $DbgNub(excludeFiles) {
		if {[string match $pattern $absfile]} {
		    set dontInstrument 1
		    set DbgNub(inExclude) 1
		    break
		}
	    }
	}
    }

    # If the "dontInstrument" flag is true, just source the file 
    # normally, taking care to propagate the error result.
    # NOTE: this will not work on the Macintosh because of it's additional
    # arguments.

    if {$dontInstrument} {
	# Set the global value DbgNub(dynProc) to false so procs 
	# defined in the uninstrumented file will not become 
	# instrumented even if the dynProcs flag was true.  
	# Restore the value to the value when done with the
	# read-only copy of the original dynProc variable.
	
	lappend DbgNub(script) $file

	set code [DbgNub_catchCmd {
	    DbgNub_uplevelCmd [list DbgNub_sourceCmd $file]
	} result]
	
	set DbgNub(script) [lreplace $DbgNub(script) end end]
	set DbgNub(inExclude) $oldExclude

	return -code $code -errorcode $errorCode -errorinfo $errorInfo \
		$result
    }

    lappend DbgNub(script) $file

    # Pass the contents of the file to the debugger for
    # instrumentation.
    
    set result [DbgNub_catchCmd {set f [open $file r]} msg]

    if {$result != 0} {
	# We failed to open the file, so let source take care of generating
	# the error.

	set DbgNub(script) [lreplace $DbgNub(script) end end]
	set DbgNub(inExclude) $oldExclude

	set code [DbgNub_catchCmd {
	    DbgNub_uplevelCmd DbgNub_sourceCmd $args
	} result]
	set errorInfo ""
	regsub -- "DbgNub_sourceCmd" $result "source" result
	return -code $code -errorcode $errorCode $result
    }

    set source [DbgNub_readCmd $f]
    close $f

    set icode [DbgNub_Instrument $absfile $source]

    # If the instrumentation failed, we just source the original file

    if {$icode == ""} {
	set icode $source
    }
    
    # Evaluate the instrumented code, propagating
    # errors that might occur during the eval.

    # Bug 93954. Maintain the script file information.
    # Note: Ability to change is an 8.4+ ability.

    DbgNub_catchCmd {
	set oldfile [DbgNub_infoCmd script]
	DbgNub_infoCmd script $file
    }

    set level [expr {[DbgNub_infoCmd level] - 1}]
    DbgNub_PushContext $level "source" $file
    set marker [DbgNub_PushStack $level [list $level "source" $file]]
    set code [DbgNub_UpdateReturnInfo [DbgNub_catchCmd {
	DbgNub_uplevelCmd 1 $icode
    } result]]
    DbgNub_PopStack $marker
    DbgNub_PopContext

    set DbgNub(script) [lreplace $DbgNub(script) end end]
    set DbgNub(inExclude) $oldExclude

    set einfo $errorInfo
    set ecode $errorCode
    DbgNub_catchCmd {
	DbgNub_infoCmd script $oldfile
    }
    set errorInfo $einfo
    set errorCode $ecode

    if {($code == 1)  || ($code == "error")} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_sourceCmd info]
	set DbgNub(cleanWrapper) {DbgNub_sourceCmd source}
	set errorInfo "$result$errorInfo"
	set errorCode NONE
	error $result $errorInfo $errorCode
    }

    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_vwaitWrapper --
#
#	Called whenever the program enters the event loop. Records a
#	discontinuity in the Tcl stack. 
#
# Arguments:
#	args	Arguments passed to original vwait call.
#
# Results:
#	Returns the result of the vwait statement.

proc DbgNub_vwaitWrapper {args} {
    global DbgNub errorCode errorInfo
    DbgNub_PushContext 0 event
    set marker [DbgNub_PushStack [expr {[DbgNub_infoCmd level] - 1}] "0 event"]
    set oldCatch $DbgNub(catch)
    set DbgNub(catch) 1
    set oldCount $DbgNub(nestCount)
    set DbgNub(nestCount) 0
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_vwaitCmd $args
    } result]
    set DbgNub(catch) $oldCatch
    set DbgNub(nestCount) $oldCount
    DbgNub_PopStack $marker
    DbgNub_PopContext
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_vwaitCmd vwait]
	set DbgNub(cleanWrapper) {DbgNub_vwaitCmd vwait}
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_updateWrapper --
#
#	Called whenever the program enters the event loop. Records a
#	discontinuity in the Tcl stack. 
#
# Arguments:
#	args	Arguments passed to original update call.
#
# Results:
#	Returns the result of the update statement.

proc DbgNub_updateWrapper {args} {
    global DbgNub errorCode errorInfo
    DbgNub_PushContext 0 event
    set marker [DbgNub_PushStack [expr {[DbgNub_infoCmd level] - 1}] "0 event"]
    set oldCatch $DbgNub(catch)
    set DbgNub(catch) 1
    set oldCount $DbgNub(nestCount)
    set DbgNub(nestCount) 0
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_updateCmd $args
    } result]
    set DbgNub(catch) $oldCatch
    set DbgNub(nestCount) $oldCount
    DbgNub_PopStack $marker
    DbgNub_PopContext
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_updateCmd update]
	set DbgNub(cleanWrapper) {DbgNub_updateCmd update}
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_uplevelWrapper --
#
#	Called whenever the program calls uplevel. Records a
#	discontinuity in the Tcl stack. 
#
# Arguments:
#	args	Arguments passed to original uplevel call.
#
# Results:
#	Returns the result of the uplevel statement.

proc DbgNub_uplevelWrapper {args} {
    global errorCode errorInfo
    set level [lindex $args 0]
    if {[string index $level 0] == "#"} {
	set level [string range $level 1 end]
	set local 0
    } else {
	set local 1
    }
    if {[DbgNub_catchCmd {incr level 0}]} {
	set level [expr {[DbgNub_infoCmd level] - 2}]
    } elseif {$local} {
	set level [expr {[DbgNub_infoCmd level] - 1 - $level}]
    }
    DbgNub_PushContext $level uplevel
    set marker [DbgNub_PushStack \
	    [expr {[DbgNub_infoCmd level] - 1}] [list $level uplevel]]
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_uplevelCmd $args
    } result]
    DbgNub_PopStack $marker
    DbgNub_PopContext
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_uplevelCmd uplevel]
	set DbgNub(cleanWrapper) {DbgNub_uplevelCmd uplevel}
    }
    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_packageWrapper --
#
#	Called whenever the program calls package. Records a
#	discontinuity in the Tcl stack. 
#
# Arguments:
#	args	Arguments passed to original package call.
#
# Results:
#	Returns the result of the package statement.

proc DbgNub_packageWrapper {args} {
    global errorCode errorInfo DbgNub

    set level [expr {[DbgNub_infoCmd level] - 1}]
    set cmd [lindex $args 0]

    set oldRequire $DbgNub(inRequire)
    set DbgNub(inRequire) 1

    DbgNub_PushContext 0 package $cmd
    set marker [DbgNub_PushStack $level [list 0 "package" $cmd]]
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_packageCmd $args
    } result]
    DbgNub_PopStack $marker
    DbgNub_PopContext

    set DbgNub(inRequire) $oldRequire

    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_packageCmd package]
	set DbgNub(cleanWrapper) {DbgNub_packageCmd package}
    }

    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_putsWrapper --
#
#	A replacement for the standard "puts" command.  We need this
#	to diverts stdout and stderr into the output window handled by
#       the frontend.
#
# Arguments:
#	args	Arguments passed to original puts call.
#
# Results:
#	Returns the result of the puts statement.

proc DbgNub_putsWrapper {args} {
    # Original is now [DbgNub_putsCmd]
    # Synopsis: ?-nonewline? ?channel? text

    global DbgNub

    set len [llength $args]
    foreach {a b c} $args { break }

    if {$len == 1} {
	# args = {text}, channel = stdout
	# May divert to frontend.

	set mode $DbgNub(stdchan,stdout)
	if {$mode == "normal"} {
	    set len 0 ; # Invoke regular 'put'
	} else {
	    set copy 0
	    set chan stdout
	    set data  "$a\n"
	    if {$mode == "copy"} {set copy 1}
	}
    } elseif {$len == 2} {
	# args either {channel text}
	#          or {-nonewline text}
	    
	if {![string compare $a -nonewline]} {
	    # {-nonewline text} =>
	    # channel == stdout
	    # May divert to frontend.

	    set mode $DbgNub(stdchan,stdout)
	    if {$mode == "normal"} {
		set len 0 ; # Invoke regular 'put'
	    } else {
		set chan stdout
		set data $b
		set copy 0
		if {$mode == "copy"} {set copy 1}
	    }
	} elseif {
	    ![string compare $a stdout] ||
	    ![string compare $a stderr]
	} {
	    # {channel text}, channel is stdout/stderr

	    set mode $DbgNub(stdchan,$a)
	    if {$mode == "normal"} {
		set len 0 ; # Invoke regular 'put'
	    } else {
		set chan $a
		set data $b\n
		set copy 0
		if {$mode == "copy"} {set copy 1}
	    }
	} else {
	    # {channel text}, non standard channel
	    # No diversion, hand over to the regular command

	    set len 0
	}
    } elseif {$len == 3} {
	# args = {-nonewline channel text}
	#     or {channel text nonewline}

	if {![string compare $a -nonewline] \
		&& (![string compare $b stdout] \
		|| ![string compare $b stderr])} {

	    set mode $DbgNub(stdchan,$b)
	    if {$mode == "normal"} {
		set len 0 ; # Invoke regular 'put'
	    } else {
		set chan $b
		set data $c
		set copy 0
		if {$mode == "copy"} {set copy 1}
	    }
	} elseif {(![string compare $a stdout] \
		|| ![string compare $a stderr]) \
		&& ![string compare $c nonewline]} {

	    set mode $DbgNub(stdchan,$a)
	    if {$mode == "normal"} {
		set len 0 ; # Invoke regular 'put'
	    } else {
		set chan $a
		set data $b
		set copy 0
		if {$mode == "copy"} {set copy 1}
	    }
	} else {
	    set len 0
	}
    } else {
	set len 0
    }

    ## $len > 0 means that copy or redirection of a standard
    ##          output channel has to occur.

    if {$len > 0} {
	# Information: chan, data, copy

	DbgNub_SendMessage [string toupper $chan] $data
	if {$copy} {
	    # For mode 'copy' we ensure that the regular 'puts' is
	    # also invoked.
	    set len 0
	}
    }

    ## $len == 0 means it wasn't handled by the nub above.

    if {$len == 0} {
	global errorCode errorInfo
	if {[catch "DbgNub_putsCmd $args" msg]} {
	    regsub      DbgNub_putsCmd $msg       puts msg
	    regsub -all DbgNub_putsCmd $errorInfo puts errorInfo
	    return -code error $msg
	}
	return $msg
    }
    return
}

# DbgNub_getsWrapper --
#
#	A replacement for the standard "gets" command.  We need this
#	to diverts stdin into the output window handled by
#       the frontend.
#
# Arguments:
#	args	Arguments passed to original gets call.
#
# Results:
#	Returns the result of the gets statement.

proc DbgNub_getsWrapper {args} {
    # Original is now [DbgNub_getsCmd]
    # Synopsis:

    global DbgNub
    set len [llength $args]

    if {($len != 1) && ($len != 2)} {
	return -code error \
		"wrong # args: should be \"gets channelId ?varName?\""
    }

    set mode $DbgNub(stdchan,stdin)

    if {[string compare stdin [lindex $args 0]] == 0} {
	# Support for Komodo notifications.
	DbgNub_SendMessage NEED_STDIN
    }

    if {
	[string compare stdin [lindex $args 0]] ||
	[string compare $mode redirect]
    } {
	# Channel other than stdin, or no redirection asked for.
	# Delegate the operation to the regular 'gets' command.

	global errorCode errorInfo
	if {[DbgNub_catchCmd {DbgNub_uplevelCmd 1 DbgNub_getsCmd $args} msg]} {
	    regsub      DbgNub_getsCmd $msg       gets msg
	    regsub -all DbgNub_getsCmd $errorInfo gets errorInfo
	    return -code error $msg
	}
	return $msg
    }

    # Diverting stdin to frontend, talk to to it to get the user input
    # ...

    global DbgNub

    DbgNub_SendMessage STDIN \
	    [DbgNub_CollateStacks] [DbgNub_GetCoverage] \
	    gets $DbgNub(stdin,blocking) {}
    DbgNub_ProcessMessages 1 ; # Wait for a STDIN message to come back

    set data $DbgNub(stdin)

    if {$len == 2} {
	upvar 1 [lindex $args 1] var
	set var $data
	return [string length $data]
    }
    return $data
}


# DbgNub_readWrapper --
#
#	A replacement for the standard "read" command.  We need this
#	to diverts stdin into the output window handled by
#       the frontend.
#
# Arguments:
#	args	Arguments passed to original read call.
#
# Results:
#	Returns the result of the read statement.

proc DbgNub_readWrapper {args} {
    # Original is now [DbgNub_readCmd]

    # read ?-nonewline? channelId
    # read channelId ?numChars?
    # read channelId ?nonewline? ** DEPRECATED ** old syntax

    global DbgNub

    set len [llength $args]

    if {($len != 1) && ($len != 2)} {
	return -code error \
		"wrong # args: should be \"read channelId ?numChars?\" or \"read ?-nonewline? channelId\""
    }
    foreach {a b} $args break

    set mode $DbgNub(stdchan,stdin)

    if {
	[string compare $mode redirect] ||
	(($len == 1) && [string compare stdin $a]) ||
	(($len == 2) && ![string compare -nonewline $a] && [string compare stdin $b]) ||
	(($len == 2) && [string compare -nonewline $a] && [string compare stdin $a]) ||
	(($len == 2) && [string compare -nonewline $a] && ![string compare stdin $a] &&
	[string compare nonewline $b] &&
	(![string is integer -strict $b] || ($b <= 0)))
    } {
	# Channel other than stdin, or no redirection asked for.
	# Delegate the operation to the regular 'read' command.

	global errorCode errorInfo
	if {[DbgNub_catchCmd {DbgNub_uplevelCmd 1 DbgNub_readCmd $args} msg]} {
	    regsub      DbgNub_readCmd $msg       read msg
	    regsub -all DbgNub_readCmd $errorInfo read errorInfo
	    return -code error $msg
	}
	return $msg
    }

    # Diverting stdin to frontend, talk to it to get the user input
    # ...

    if {$len == 1} {
	set chop 1
	set num {}
    } elseif {[string compare -nonewline $a]} {
	if {[string compare nonewline $b]} {
	    # channel num
	    set chop 0
	    set num  $b
	} else {
	    # channel nonewline
	    set chop 1
	    set num  {}
	}
    } else {
	# -nonewline channel
	set chop 0
	set num {}
    }

    global    DbgNub

    DbgNub_SendMessage STDIN \
	    [DbgNub_CollateStacks] [DbgNub_GetCoverage] \
	    read $DbgNub(stdin,blocking) $num
    DbgNub_ProcessMessages 1 ; # Wait for a STDIN message to come back

    set data $DbgNub(stdin)

    if {$chop && (![string compare [string index $data end] "\n"])} {
	set data [string range $data 0 end-1]
    }
    return $data
}

# DbgNub_fconfigureWrapper --
#
#	A replacement for the standard "fconfigure" command.  We need this
#	to know whether reading from stdin is blocking or non-blocking.
#
# Arguments:
#	args	Arguments passed to original fconfigure call.
#
# Results:
#	Returns the result of the fconfigure statement.

proc DbgNub_fconfigureWrapper {args} {
    # Original is now [DbgNub_fconfigureCmd]

    # We inspect the arguments for our purposes, and then run the original command.
    # We accept changes to the blocking-mode of stdin iff we get no errors

    # fconfigure channelId ?options?

    set setblock 0
    if {[string compare stdin [lindex $args 0]] == 0} {
	set pos [lsearch -exact [lrange $args 1 end] -blocking]
	if {$pos >= 0} {
	    incr pos
	    set blocking [lindex $args $pos]
	    if {$blocking != {}} {
		set setblock 1
	    }
	}
    }

    global errorCode errorInfo
    if {[DbgNub_catchCmd {DbgNub_uplevelCmd 1 DbgNub_fconfigureCmd $args} msg]} {
	regsub      DbgNub_fconfigureCmd $msg       read msg
	regsub -all DbgNub_fconfigureCmd $errorInfo read errorInfo
	return -code error $msg
    }

    if {$setblock} {
	global DbgNub
	set    DbgNub(stdin,blocking) $blocking		
    }
    return $msg
}

# DbgNub_renameWrapper --
#
#	A replacement for the standard "rename" command.  We need to
#	do a little extra work when renaming instrumented procs.
#
# Arguments:
#	args	Arguments passed to original rename call.
#
# Results:
#	Returns the result of the rename statement.

proc DbgNub_renameWrapper {args} {
    global DbgNub errorCode errorInfo
    
    # Check to see if the name we are about to rename is in a namespace.
    # We need to get the full name for this command before and after
    # it is renamed.

    if {[llength $args] > 0} {
	set level [expr {[DbgNub_infoCmd level] - 1}]

	set name [lindex $args 0]
	if {$DbgNub(namespace)} {
	    set name [DbgNub_uplevelCmd 1 \
		    [list $DbgNub(scope)namespace origin $name]]

	    # Check to see if the command we are about to rename is imported
	    # from a namespace.  If so we need to short circuit out here
	    # because imported procs will choke on the code below.

	    if {$name != [DbgNub_uplevelCmd 1 \
		    [list $DbgNub(scope)namespace which [lindex $args 0]]]} {
		set $name [lindex $args 0]
		set code [DbgNub_catchCmd {
		    DbgNub_uplevelCmd DbgNub_renameCmd $args
		} result]
		if {$code == 1} {
		    set result [DbgNub_cleanErrorInfo $result \
			    DbgNub_renameCmd rename]
		    set DbgNub(cleanWrapper) {DbgNub_renameCmd rename}
		}
		return -code $code -errorcode $errorCode -errorinfo \
			$errorInfo $result
	    }
	}

	# Check to see if the name we are about to rename is in the
	# list of commands that should not be renamed.  If it is
	# generate an warning stating that renaming the command may
	# crash the debugger.

	# Bugzilla 39620.
	# It is possible to do such rename without crashing, by
	# putting a new implementation of the command into place. I.e.
	# an application or library wrapping its own code around the
	# builtin command, like is done by the debugger as well (See
	# DbgNub_WrapCommands).

	if {![DbgNub_okToRename $name $level]} {
	    # We force the warning into the frontend eval console by
	    # sending a message directly to the error channel, instead
	    # of going through either builtin puts (DbgNub_putsCmd),
	    # or whatever redirection the user has chosen.

	    DbgNub_SendMessage STDERR \
		"Warning (issued by the debugger backend).\nRenaming \
                 \"$name\" may crash the debugger.\n"
	}
    }

    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd DbgNub_renameCmd $args
    } result]
    if {$code == 1} {
	set result [DbgNub_cleanErrorInfo $result DbgNub_renameCmd rename]
	set DbgNub(cleanWrapper) {DbgNub_renameCmd rename}
	return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
    }

    # Check to see if the command we just renamed was instrumented.
    # If so, we need to update our info and fix the body of the
    # procedure to add the correct info to the context stack.

    set newName [lindex $args 1]
    if {[info exists DbgNub(proc=$name)]} {
	if {$newName == ""} {
	    unset DbgNub(proc=$name)
	} else {
	    if {$DbgNub(namespace)} {
		if {$DbgNub(namespace)} {
		    set newName [DbgNub_uplevelCmd 1 \
			    [list $DbgNub(scope)namespace origin $newName]]
		}
	    }
	    set DbgNub(proc=$newName) $DbgNub(proc=$name)
	    unset DbgNub(proc=$name)
	}
    }

    # Finally check to see if the command just renamed was one of the
    # builting commands that the nub wrapped.

    set name [string trim $name :]
    set i [lsearch $DbgNub(wrappedCommandList) $name]
    if {$i != -1} {
	set DbgNub(wrappedCommandList) [lreplace $DbgNub(wrappedCommandList) \
		$i $i [string trim $newName :]]
    }

    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# DbgNub_CheckLineBreakpoints --
#
#	Check the current location against the list of breakpoint
#	locations to determine if we need to stop at the current
#	statement.
#
# Arguments:
#	location	Current location.
#	level		Stack level of current statement.
#
# Results:
#	Returns 1 if we should break at this statement.

proc DbgNub_CheckLineBreakpoints {location level} {
    global DbgNub

    set block [lindex $location 0]
    set line  [lindex $location 1]

    if {[DbgNub_infoCmd exists DbgNub($block:$line)]} {

	if {$DbgNub(debug) & 1} {
	    DbgNub_Log tests=[join $DbgNub($block:$line) \ntests=]
	}

	foreach test $DbgNub($block:$line) {
	    if {($test == "") ||
		([DbgNub_uplevelCmd \#$level $test] == "1")} {
		if {$DbgNub(debug) & 1} { DbgNub_Log tests!done/break }
		return 1
	    }
	}

	if {$DbgNub(debug) & 1} { DbgNub_Log tests!done/no-break }
    }
    return 0
}

# DbgNub_CheckSpawnpoints --
#
#	Check the current location against the list of spawmpoint
#	locations. We __do not__ stop at these locations, but set
#	(or reset) a spawn indicator in DbgNub a command interested
#	in spawns can look at.
#
# Arguments:
#	location	Current location.
#	level		Stack level of current statement.
#
# Results:
#	Always 0, never break at this statement.

proc DbgNub_CheckSpawnpoints {location level} {
    global DbgNub

    set block [lindex $location 0]
    set line  [lindex $location 1]

    if {[DbgNub_infoCmd exists DbgNub(spawn:$block:$line)]} {
	set DbgNub(spawnPoint) 1
    } else {
	set DbgNub(spawnPoint) 0
    }

    if {$DbgNub(debug) & 1} {
	DbgNub_Log "SpawnInfo AtSpawnpoint? [expr {$DbgNub(spawnPoint) ? "yes" : "no"}] (@ $location)"
    }

    return 0 ;# _never stop_
}

# DbgNub_GetVarTrace --
#
#	Retrieve the trace handle for the given variable if one exists.
#
# Arguments:
#	level	The scope at which the variable is defined.
#	name	The name of the variable.
#
# Results:
#	Returns the trace handle or {} if none is defined.

proc DbgNub_GetVarTrace {level name} {
    global DbgNub

    if {! [DbgNub_uplevelCmd #$level [list DbgNub_infoCmd exists $name]]} {
	return ""
    }

    upvar #$level $name var
    foreach trace [trace vinfo var] {
	set command [lindex $trace 1]
	if {[string compare [lindex $command 0] "DbgNub_TraceVar"] == 0} {
	    set handle [lindex $command 1]
	    if {[DbgNub_infoCmd exists DbgNub(var:$handle)]} {
		return $handle
	    }
	}
    }

    return ""
}

# DbgNub_AddVarTrace --
#
#	Add a new debugger trace for the given variable.
#
# Arguments:
#	level	The scope at which the variable is defined.
#	name	The name of the variable.
#	handle	The variable handle.
#
# Results:
#	None.  Creates a trace and sets up the state info for the variable.

proc DbgNub_AddVarTrace {level name} {
    global DbgNub
    upvar #$level $name var

    # Check to see if a trace already exists and bump the reference count.

    set handle [DbgNub_GetVarTrace $level $name]
    if {$handle != ""} {
	incr DbgNub(varRefs:$handle)
	return $handle
    }

    if {[array exists var]} {
	set type array
    } else {
	set type scalar
    }

    # Find an unallocated trace handle

    set handle [incr DbgNub(varHandle)]
    while {[DbgNub_infoCmd exists DbgNub(var:$handle)]} {
	set handle [incr DbgNub(varHandle)]
    }

    # Initialize the trace

    set DbgNub(var:$handle) {}
    set DbgNub(varRefs:$handle) 1
    trace variable var wu "DbgNub_TraceVar $handle $type"
    return $handle
}

# DbgNub_RemoveVarTrace --
#
#	Marks a variable trace as being deleted so it will be cleaned up
#	the next time the variable trace fires.
#
# Arguments:
#	handle		The debugger trace handle for this variable.
#
# Results:
#	None.

proc DbgNub_RemoveVarTrace {handle} {
    global DbgNub
    if {[incr DbgNub(varRefs:$handle) -1] == 0} {
	unset DbgNub(var:$handle)
	unset DbgNub(varRefs:$handle)
    }
    return
}

# DbgNub_AddBreakpoint --
#
#	Add a breakpoint.
#
# Arguments:
#	type		One of "line" or "var".
#	where		If the type is "line", then where contains a location.
#			If the type is "var", then where contains a trace
#			handle for the variable break on.
#	test		The test to use to determine whether a breakpoint
#			should be generated when the trace triggers.  This
#			script is evaluated at the scope where the trace
#			triggered.  If the script returns 1, a break is
#			generated. 
#
# Results:
#	None.

proc DbgNub_AddBreakpoint {type where {test {}}} {
    global DbgNub

    switch $type {
	line {
	    # Ensure that we are looking for line breakpoints.

	    if {[lsearch -exact $DbgNub(breakPreChecks) \
		    DbgNub_CheckLineBreakpoints] == -1} {
		lappend DbgNub(breakPreChecks) DbgNub_CheckLineBreakpoints
	    }
	    set block [lindex $where 0]
	    set line  [lindex $where 1]

	    set testkey $block:$line

	    set where [list $block $line {}]
	    incr DbgNub(numBreaks)
	}
	var {
	    # Add to the list of tests for the trace.
	    set testkey var:$where
	}
	spawn {
	    # Remember the information, and ensure to generate
	    # spawn indicators when reaching these locations.

	    if {[lsearch -exact $DbgNub(breakPreChecks) \
		    DbgNub_CheckSpawnpoints] == -1} {
		# Place this at the front, it has to be done
		# first and will never break execution.

		set DbgNub(breakPreChecks) [linsert \
			$DbgNub(breakPreChecks) 0 \
			DbgNub_CheckSpawnpoints]
	    }

	    set block [lindex $where 0]
	    set line  [lindex $where 1]
	    set testkey spawn:$block:$line
	}
    }

    # Prevent duplication of test conditions. Test conditions may have
    # side-effects. Example: DbgNub_HitBreakpoint which not only performs
    # the HC check, but maintains the counter also.
    if {[DbgNub_infoCmd exists DbgNub($testkey)] &&
	([lsearch -exact $DbgNub($testkey) $test] >= 0)} return
    lappend DbgNub($testkey) $test
    return
}

# DbgNub_SetHitcounter --
#
#	Set the hit counter value for the specified breakpoint.
#
# Arguments:
#	where		The location of the breakpoint
#
# Results:
#	None.

proc DbgNub_SetHitcounter {where hitcount} {
    global DbgNub
    set    DbgNub(hc,$where) $hitcount
    return
}

# DbgNub_GetHitcounter --
#
#	Retrieve the hit counter value for the specified breakpoint.
#
# Arguments:
#	where		The location of the breakpoint
#
# Results:
#	The hit counter for the specified breakpoint location.

proc DbgNub_GetHitcounter {where} {
    global DbgNub
    return $DbgNub(hc,$where)
}

# DbgNub_RemoveHitcounter --
#
#	Remove the hit counter for the specified breakpoint.
#
# Arguments:
#	where		The location of the breakpoint
#
# Results:
#	None.

proc DbgNub_RemoveHitcounter {where} {
    global DbgNub
    DbgNub_catchCmd {unset DbgNub(hc,$where)}
    return
}

# DbgNub_HitBreakpoint --
#
#	Test for the specified breakpoint, based on
#	triggering according to the value of its hit counter
#
# Arguments:
#	where		The location of the breakpoint.
#	condition	Trigger condition
#	hitvalue	Parameter for trigger condition
#
# Results:
#	A boolean flag. True implies 'break now', False means
#	that no break occurs.
#
#	'hitvalue == 0' implies 'condition irrelevant', break always
#	condition	Trigger break when	Notes
#	---------	------------------	-----
#	>=		counter >= hitvalue	"After n"
#	==		counter == hitvalue	"On n"
#	%		counter % hitvalue == 0	"Every n"

proc DbgNub_HitBreakpoint {where condition hitvalue} {
    global DbgNub
    upvar #0 DbgNub(hc,$where) count
    incr count

    if {$DbgNub(debug) & 1} { DbgNub_Log "[info level 0] @ $count" }

    switch -exact -- $condition {
	>= {
	    return [expr {$count >= $hitvalue}]
	}
	== {
	    return [expr {$count == $hitvalue}]
	}
	% {
	    return [expr {($count % $hitvalue) == 0}]
	}
    }
}

# DbgNub_CondBreakpoint --
#
#	Test for the specified breakpoint, based on conditional
#	expression.
#
# Arguments:
#	where		The location of the breakpoint.
#	expression	Break trigger.
#	condition	Hit Trigger condition
#	hitvalue	Parameter for trigger condition
#
# Results:
#	A boolean flag. True implies 'break now', False means
#	that no break occurs.

proc DbgNub_CondBreakpoint {where expression {hitcondition {}} {hitvalue {}}} {
    set fail [DbgNub_catchCmd {DbgNub_uplevelCmd 1 [list expr $expression]} result]
    if {$fail || !$result} {
	# No break
	return 0
    }

    if {$hitcondition == {}} {
	# Conditional breakpoint without hit count processing.
	return 1
    }

    # Breakpoint triggers, do hit count processing.

    DbgNub_HitBreakpoint $where $hitcondition $hitvalue
}

# DbgNub_RemoveBreakpoint --
#
#	Remove the specified breakpoint.
#
# Arguments:
#	type		One of "line" or "var".
#	where		If the type is "line", then where contains a location.
#			If the type is "var", then where contains a trace
#			handle for the variable break on.
#	test		The test to remove.
#
# Results:
#	None.

proc DbgNub_RemoveBreakpoint {type where test} {
    global DbgNub
    switch $type {
	line {
	    set block [lindex $where 0]
	    set line  [lindex $where 1]

	    # Remove the breakpoint.

	    if {[DbgNub_infoCmd exists DbgNub($block:$line)]} {
		set index [lsearch -exact $DbgNub($block:$line) $test]
		set tests [lreplace       $DbgNub($block:$line) $index $index]

		if {$tests == ""} {
		    unset DbgNub($block:$line)
		} else {
		    set DbgNub($block:$line) $tests
		}
		incr DbgNub(numBreaks) -1
	    }

	    # If this was the last breakpoint, remove the line breakpoint
	    # check routine from the check list.

	    if {$DbgNub(numBreaks) == 0} {
		set index [lsearch -exact $DbgNub(breakPreChecks) \
			DbgNub_CheckLineBreakpoints]
		set DbgNub(breakPreChecks) [lreplace $DbgNub(breakPreChecks) \
			$index $index]
	    }
	}
	var {
	    # Remove the test from the trace.

	    if {[DbgNub_infoCmd exists DbgNub(var:$where)]} {
		set index [lsearch -exact $DbgNub(var:$where) $test]
		set DbgNub(var:$where) [lreplace $DbgNub(var:$where) \
			$index $index]
	    }
	}
	spawn {
	    set block [lindex $where 0]
	    set line  [lindex $where 1]

	    # Remove the spawnpoint
	    if {[DbgNub_infoCmd exists DbgNub(spawn:$block:$line)]} {
		set index [lsearch -exact $DbgNub(spawn:$block:$line) $test]
		set tests [lreplace $DbgNub(spawn:$block:$line) $index $index]

		if {$tests == ""} {
		    unset DbgNub(spawn:$block:$line)
		} else {
		    set DbgNub(spawn:$block:$line) $tests
		}
	    }
	}
    }
    return
}

# DbgNub_TraceVar --
#
#	This procedure is invoked when a traced variable is written to or
#	unset.  It reports the event to the debugger and waits to see if it
#	should generate a breakpoint event.
#
# Arguments:
#	handle		The debugger trace handle for this variable.
#	type		The type of variable trace, either "array" or "scalar".
#	name1		The first part of the variable name.
#	name2		The second part of the variable name.
#	op		The variable operation being performed.
#
# Results:
#	None.

proc DbgNub_TraceVar {handle type name1 name2 op} {
    global DbgNub
    
    if {$DbgNub(socket) == -1} {
	return
    }

    set level [expr {[DbgNub_infoCmd level] - 1}]

    # Process any queued messages without blocking.  This ensures that
    # we have seen any changes in the tracing state before we process
    # this event.

    DbgNub_ProcessMessages 0

    # Compute the complete name and the correct operation to report

    if {$type == "array"} {
	if {$name2 != "" && $op == "u"} {
	    set op "w"
	}
	set name $name1
    } elseif {$name2 == ""} {
	set name $name1
    } else {
	set name ${name1}($name2)
    }

    # Clean up the trace state if the handle is dead.
    
    if {! [DbgNub_infoCmd exists DbgNub(var:$handle)]} {
	trace vdelete $name wu "DbgNub_TraceVar $handle $type"
	return
    }

    # If the variable is being written, check to see if we should generate a
    # breakpoint.  Note that we execute all of the tests in case they have side
    # effects that are desired.
    
    if {$op != "u"} {
	set varBreak 0
	foreach test $DbgNub(var:$handle) {
	    if {($test == "")} {
		set varBreak 1
	    } elseif {([DbgNub_catchCmd {DbgNub_uplevelCmd #$level $test} result] == 0) \
		    && $result} {
		set varBreak 1
	    }
	}
	if {$varBreak} {
	    if {[string compare $op u] == 0} {
		set value {}
	    } else {
		set value [uplevel 1 [list set $name]]
	    }

	    DbgNub_Break $level varbreak $name $op $value $handle
	}
    } else {
	unset DbgNub(var:$handle)
	unset DbgNub(varRefs:$handle)
	DbgNub_SendMessage UNSET $handle
    }
}

# DbgNub_Evaluate --
#
#	Evaluate a user script at the specified level.  The script is
#	treated like an uninstrumented frame on the stack.
#
# Arguments:
#	id		This id should be returned with the result.
#	level		The scope at which the script should be evaluated.
#	script		The script that should be evaluated.
#
# Results:
#	None.

proc DbgNub_Evaluate {id level script} {
    global DbgNub errorInfo errorCode

    # Save the debugger state so we can restore it after the evaluate
    # completes.  Reset the error handling flags so we don't notify the
    # debugger of errors generated by the script until we complete the
    # evaluation.  

    set saveState {}
    foreach element {state catch errorHandled nestCount breakNext} {
	lappend saveState $element $DbgNub($element)
    }
    array set DbgNub {catch 0 errorHandled 0 nestCount 0 breakNext 0}

    DbgNub_PushContext $level "user eval"

    set code [DbgNub_catchCmd {DbgNub_uplevelCmd #$level $script} result]
    if {$code == 1} {
	# Clean up the errorInfo stack to remove our tracks.
	# We also snip off the last 2 lines, as they contain
	# references to nub internal code (The uplevel above).

	DbgNub_cleanErrorInfo
	DbgNub_cleanWrappers

	set ei        [split $errorInfo \n]
	set end       [expr {[llength $ei]-3}]
	if {[string compare {    ("uplevel" body line 1)} [lindex $ei $end]] == 0} {
	    incr end -1
	}
	set errorInfo [join [lrange $ei 0 $end] \n]
    }

    # Restore the debugger state.

    DbgNub_PopContext
    array set DbgNub $saveState

    DbgNub_SendMessage BREAK [DbgNub_CollateStacks] [DbgNub_GetCoverage] \
	    result [list $id $code $result $errorInfo $errorCode]
}

# DbgNub_BeginCoverage --
#
#	Set global coverage boolean to true.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_BeginCoverage {mode} {
    global DbgNub

    set DbgNub(cover) 1
    set DbgNub(covermode) $mode
    foreach index [array names DbgNub cover:*] {
	unset DbgNub($index)
    }
    foreach index [array names DbgNub profile:*] {
	unset DbgNub($index)
    }

    if {[string compare $DbgNub(covermode) profile] == 0} {
	# Triple limit / profiling only. Best effort, fail silently if
	# action is not supported by the interpreter executing the
	# application.

	DbgNub_catchCmd {
	    interp recursionlimit {} [expr {
			    3 * [interp recursionlimit {}]
			}]
	}
    }
    return
}

# DbgNub_EndCoverage --
#
#	Set global coverage boolean to false, and clear all memory of
#	covered locations.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_EndCoverage {} {
    global DbgNub

    set DbgNub(cover) 0
    set DbgNub(covermode) none
    foreach index [array names DbgNub cover:*] {
	unset DbgNub($index)
    }
    foreach index [array names DbgNub profile:*] {
	unset DbgNub($index)
    }
    return
}

# DbgNub_GetCoverage --
#
#	Find the list of ranges that have been covered
#	since the last time this command was called; then remove
#	all memory of covered locations.
#
# Arguments:
#	None.
#
# Results:
#	Returns the list of ranges that have been covered
#	since the last time this command was called.

proc DbgNub_GetCoverage {} {
    global DbgNub

    if {$DbgNub(cover)} {
	set coverage [array get DbgNub cover:*]

	foreach index [array names DbgNub cover:*] {
	    unset DbgNub($index)
	}

	if {[string compare $DbgNub(covermode) profile] == 0} {
	    set timing [array get DbgNub profile:*]

	    foreach index [array names DbgNub profile:*] {
		unset DbgNub($index)
	    }
	    return [list $coverage $timing]
	}
	return [list $coverage {}]
    }
    return {}
}

# DbgNub_GetProcDef --
#
#	Reconstruct a procedure definition.
#
# Arguments:
#	name	The name of the procedure to reconstruct.
#
# Results:
#	Returns a script that can be used to recreate a procedure.

proc DbgNub_GetProcDef {name} {
    global DbgNub DbgNub_Temp
    set body [DbgNub_uplevelCmd #0 [list DbgNub_infoCmd body $name]]
    set args [DbgNub_uplevelCmd #0 [list DbgNub_infoCmd args $name]]
    set argList {}
    foreach arg $args {
	if {[DbgNub_uplevelCmd #0 [list \
		DbgNub_infoCmd default $name $arg DbgNub_Temp]]} {
	    lappend argList [list $arg $DbgNub_Temp]
	} else {
	    lappend argList $arg
	}
    }
    catch {unset DbgNub_Temp}
    return [list proc $name $argList $body]
}

# DbgNub_Interrupt --
#
#	Interrupt the currently running application by stopping at
#	the next instrumented statement.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_Interrupt {} {
    global DbgNub
    set DbgNub(breakNext) 1
    return 
}

# DbgNub_IgnoreError --
#
#	Ignore the current error.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc DbgNub_IgnoreError {} {
    global DbgNub
    set DbgNub(ignoreError) 1
    return
}

# DbgNub_cleanErrorInfo --
#
#	This attepts to remove our tracks from wrapper functions for
#	the Tcl commands like info, source, rename, etc.
#
# Arguments:
#	result		The dirty result.
#	wrapCmd		The wraped command we want to replace.
#	actualCmd	The actualy command errorInfo & result should have.
#
# Results:
#	Returns the cleaned result string.

proc DbgNub_cleanErrorInfo {{result {}} {wrapCmd {}} {actualCmd {}}} {
    global errorInfo
    if {$wrapCmd != {}} {
	if {[string match "wrong # args:*" $result]} {
	    regsub -- $wrapCmd $result $actualCmd result
	    regsub -- $wrapCmd $errorInfo $actualCmd errorInfo
	}
    }

    # Hide shadow procedure invocations.  This is pretty complicated because
    # Tcl doesn't support non-greedy regular expressions.

    while {[regexp -indices "\n    invoked from within\n\"\[^\n\]*__DbgNub__" \
	    $errorInfo range]} {
	set newInfo [string range $errorInfo 0 [lindex $range 0]]
	set substring [string range $errorInfo \
		[expr {[lindex $range 0] + 1}] end]
	regexp -indices "\n\"DbgNub_catchCmd\[^\n\]*\n" $substring range
	append newInfo [string range $substring [expr {[lindex $range 1]+1}] end]
	set errorInfo $newInfo
    }
    while {[regexp -indices "\n    invoked from within\n\"\DbgNub_Do" \
	    $errorInfo range]} {
	set newInfo [string range $errorInfo 0 [lindex $range 0]]
	set substring [string range $errorInfo [lindex $range 1] end]
	regexp -indices "    invoked from within\n" $substring range
	append newInfo [string range $substring [lindex $range 0] end]
	set errorInfo $newInfo
    }

    set pat "\n    \\(\"uplevel\" body line \[^\n\]*\\)\n    invoked from within\n\"DbgNub_uplevelCmd 1 \[^\n\]*\""
    regsub -all -- $pat $errorInfo {} errorInfo 
    
    return $result
}

# DbgNub_cleanWrappers --
#
#	This procedure will clean up some our tracks in the errorInfo
#	variable by hiding the wrapping of certain core commands.  Each
#	wrapper will note that it needs to be cleaned up by setting
#	variableDbgNub(cleanWrappers).  The DbgNub_Do command is what will
#	actually call this procedure.
#
# Arguments:
#	None.
#
# Results:
#	None.  The global errorInfo variable may be modified.

proc DbgNub_cleanWrappers {} {
    global DbgNub errorInfo

    if {[DbgNub_infoCmd exists DbgNub(cleanWrapper)]} {
	set wrap [lindex $DbgNub(cleanWrapper) 0]
	set actu [lindex $DbgNub(cleanWrapper) 1]
	set dbgMsg "\"$wrap.*"
	append dbgMsg \n {    invoked from within}
	append dbgMsg \n "\"$actu"
	regsub -- $dbgMsg $errorInfo "\"$actu" errorInfo
	unset DbgNub(cleanWrapper)
    }
}

# DbgNub_okToRename --
#
#	This procedure checks that it is safe to rename (or redefine) a
#	given command.
#
# Arguments:
#	name	The command name to check.
#	level	Stack level of current statement.
#
# Results:
#	Returns 1 if it is safe to modify the given command name in the
#	current context, else returns 0.
#
# Side effects:
#	None.

proc DbgNub_okToRename {name level} {
    global DbgNub

    if {$DbgNub(namespace)} {
	if {![string match ::* $name]} {
	    set name [DbgNub_uplevelCmd \#$level \
		    [list $DbgNub(scope)namespace current]]::$name
	}
	if {[string length [namespace qualifiers $name]] == 0} {
	    set name [namespace tail $name]
	} else {
	    set name {}
	}
    }
    return [expr {[lsearch $DbgNub(excludeRename) $name] < 0}]
}

##############################################################################

proc DbgNub_DumpStack {} {
    set n [DbgNub_infoCmd level]
    set i 0
    set id 1
    while {$n} {
	set c [catch {info level $i} m]
	DbgNub_putsCmd stdout "L[format %3d $id]: $c ($m)"
	::incr i -1
	::incr id -1
	::incr n -1
    }
    return
}

proc DbgNub_DumpFrames {} {
    set n [DbgNub_infoCmd frame]
    set i 0
    set id 1
    while {$n} {
	set c [catch {info frame $i} m]
	DbgNub_putsCmd stdout "F[format %3d $id]: $c ($m)"
	::incr i -1
	::incr id -1
	::incr n -1
    }
    return
}

##############################################################################

@__EXTERN__@

##############################################################################
# Initialize the nub library.  Once this completes successfully, we can
# safely replace the debugger_eval and debugger_init routines.

DbgNub_Startup

# debugger_init --
#
#	This is a replacement for the public debugger_init routine
#	that does nothing.  This version of the function is installed
#	once the debugger is successfully initialized.
#
# Arguments:
#	args	Ignored.
#
# Results:
#	Returns 1.

DbgNub_procCmd debugger_init {args} {
    return [debugger_attached]
}

# debugger_eval --
#
#	Instrument and evaluate the specified script.
#
# Arguments:
#	args		One or more arguments, the last of which must
#			be the script to evaluate.
#
# Results:
#	Returns the result of evaluating the script.

DbgNub_procCmd debugger_eval {args} {
    global DbgNub errorInfo errorCode
    set length [llength $args]
    set blockName ""
    for {set i 0} {$i < $length} {incr i} {
	set arg [lindex $args $i]
	switch -glob -- $arg {
	    -name {
		incr i
		if {$i < $length} {
		    set blockName [lindex $args $i]
		} else {
		    return -code error "missing argument for -name switch" 
		}
	    }
	    -- {
		incr i
		break
	    }
	    -* {
		return -code error "bad switch \"$arg\": must be -block, or --"
	    }
	    default {
		break
	    }
	}
    }
    if {$i != $length-1} {
	return -code error "wrong # args: should be \"debugger_eval ?options? script\""
    }
    
    set script [lindex $args $i]
    
    if {$DbgNub(socket) != -1} {
	set icode [DbgNub_Instrument /tcldebugger:/$blockName $script]

	# If the instrumentation failed, we just eval the original script

	if {$icode == ""} {
	    set icode $script
	}
    } else {
	set icode $script
    }

    set level [expr {[DbgNub_infoCmd level] - 1}]
    DbgNub_PushContext $level "debugger_eval"
    set marker [DbgNub_PushStack $level [list $level "debugger_eval"]]
    set code [DbgNub_catchCmd {
	DbgNub_uplevelCmd 1 $icode
    } result]
    DbgNub_cleanErrorInfo
    DbgNub_PopStack $marker
    DbgNub_PopContext

    return -code $code -errorcode $errorCode -errorinfo $errorInfo $result
}

# debugger_break --
#
#	Cause the debugger to break on this command.
#
# Arguments:
#	str	(Optional) String that displays in debugger.
#
# Results:
#	None.  Will send break message to debugger.

DbgNub_procCmd debugger_break {{str ""}} {
    global DbgNub

    set level [expr {[DbgNub_infoCmd level] - 1}]
    if {$DbgNub(socket) != -1} {
	DbgNub_Break $level userbreak $str
    }

    return
}

# debugger_attached --
#
#	Test whether the debugger socket is still connected to the
#	debugger.
#
# Arguments:
#	None.
#
# Results:
#	Returns 1 if the debugger is still connected.

DbgNub_procCmd debugger_attached {} {
    global DbgNub

    # Process queued messages to ensure that we notice a disconnect.
    DbgNub_ProcessMessages 0
    return [expr {$DbgNub(socket) != -1}]
}

# debugger_setCatchFlag --
#
#	Set the catch flag to indicate if errors should be caught by the
#	debugger.  This flag is normally set to 0 by the "catch" command.
#	This command can be used to reset the flag to allow errors to be
#	reported by the debugger even if they would normally be masked by a
#	enclosing catch command.  Note that the catch flag can be overridden by
#	the errorAction flag controlled by the user's project settings.
#
# Arguments:
#	flag	The new value of the flag.  1 indicates thtat errors should
#		be caught by the debugger.  0 indicates that the debugger
#		should allow errors to propagate.
#
# Results:
#	Returns the previous value of the catch flag.
#
# Side effects:
#	None.

DbgNub_procCmd debugger_setCatchFlag {flag} {
    global DbgNub

    set old $DbgNub(catch)
    set DbgNub(catch) $flag
    return $old
}
