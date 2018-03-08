# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# checker.tcl --
#
#	This file implements the integration of the checker into the debugger.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# SCCS: @(#) checker.tcl 1.16 98/05/02 14:01:16

# ### ### ### ######### ######### #########
## Requisites

package require snit     ; # Tcllib | OO system
package require fileutil ; # Tcllib | temp. file
package require parser
package require tlocate

# ### ### ### ######### ######### #########
## Implementation

# Handling of checker information ...

# The checker returns line information (= number of line) and the text
# of the command which was found as bogus. It provides column
# information (sort of), but only relative to the command itself, not
# relative to the start of the line it is part of. But as it also
# provides the full text of the bogus command we can look for this
# text in the selected line and determine the column information in
# that way ([string first], [string length]).

snit::type ::checker {

    # State objects of the currently active checker processes.
    # Empty if none is active. Maps from block ids to the process.
    variable state -array {}

    # Global checker state (#errors, #warnings)

    variable error   0
    variable warning 0

    # Cache of syntax error information across files, for the syntax
    # error dialog.

    # Information contained in the cache
    # Per file
    # - per line
    #   - per column
    #     - type of message
    #     - message itself
    #
    # Key = file,line,col

    variable blkcache
    variable msgcache
    variable msgup 0

    # Where to find the checker application.
    # NOTE: This is a list (auto_execok).
    variable checker

    # ### ### ### ######### ######### #########

    variable             code
    variable             chkwin
    variable             blkmgr
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set code    [$gui code]
	set chkwin  [$gui chkwin]
	set engine_ [$gui cget -engine]
	set blkmgr  [$engine_ blk]
	return
    }

    # ### ### ### ######### ######### #########

    method LocateChecker {} {
	#puts stderr "LocateChecker >>>"

	set checker [tlocate::find tclchecker]

	#puts stderr "LocateChecker >>> ($checker) \n<<<"
	return
    }

    constructor {args} {
	array set msgcache {}
	array set blkcache {}
	$self LocateChecker
	$self configurelist $args
	return
    }

    method cmd {} {
	return $checker
    }

    # method kill --
    #
    #	Kill the checker process, if running.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method kill {} {
	set theblock [$gui getCurrentBlock]

	#puts stderr "$self kill >>> ($theblock)"

	if {![info exists state($theblock)]} {
	    #puts stderr "$self kill <<< nothing to kill"
	    return
	}

	$state($theblock) destroy

	#puts stderr "$self kill <<< $theblock"
	return
    }

    # Method invoked by a subprocess when it is done and gone.
    method done {theblock thestate} {
	#puts stderr "$self done >>> $theblock $thestate"

	if {![info exists state($theblock)] ||
	    ($state($theblock) ne $thestate)} {
	    # Ignore outdated callback
	    #puts stderr "$self done <<< mismatch, ignored"
	    return
	}

	unset state($theblock)
	#puts stderr "$self done <<< match, done"
	return
    }

    # method start --
    #
    #	Start the checker process. Must not run.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method start {} {
	#puts stderr "$self start >>>"

	if {![pref::prefGet staticSyntaxCheck]} {
	    #puts stderr "$self start <<< no start, disabled for this project"
	    return
	}

	set theblock [$gui getCurrentBlock]
	#puts stderr "$self start >>> block $theblock"

	if {$theblock eq {}} {
	    #puts stderr "$self start <<< undefined, ignored"
	}

	if {[info exists state($theblock)]} {
	    # We have an active process for the block.
	    # -- Maybe allow us to kill it ?
	    #puts stderr "$self start <<< still running"
	    return -code error "Checker still running"
	}

	if {[info exists blkcache($theblock)]} {
	    #puts stderr "$self start <<< aborted, block $theblock already done"
	    #SHOWFRAMES 0
	    return
	}

	# Write the code to the checker.

	if {[catch {
	    $code checkClear
	    set error   0
	    set warning 0

	    set thestate [cstate %AUTO% $self $theblock [$blkmgr getSource $theblock]]
	} err]} {
	    #puts stderr "$self start <<< trouble: $err"
	    return -code error "checker, analyze problem: $err"
	}

	set state($theblock) $thestate

	#puts stderr "$self start <<< done"
	return
    }

    # Method invoked by a subprocess when it completed processing the
    # named block.
    method mark {theblock thestate} {
	#puts stderr "$self mark >>> $thestate ($theblock)"

	set blkcache($theblock) .

	#puts stderr "$self mark <<< done"
	return
    }

    # method report --
    #
    #	Handle an error or warning reported by a sub-process.
    #
    # Arguments:
    #	line	- line of defective command
    #	col	- start column ...
    #	mtype	- type of message
    #	msgtext	- text of message
    #
    # Results:
    #	None.

    method report {theblock thestate lno col cole msgtype msg mid} {
	#puts stderr "$self report >>> $theblock $thestate $lno $col $cole $msgtype $msg $mid"

	$code checkNew $lno $col $cole $msgtype $msg

	if {![$blkmgr exists $theblock]} {
	    # With the block gone the subprocess has become irrelevant.
	    # Forcibly kill it. This cleans up our state as well.
	    $thestate destroy
	    return
	}

	# Note that we allow the subprocess to run to completion even
	# if it does not refer to the current block anymore. We are not
	# counting the messages for the statistics anymore however, and
	# it will not cause a window refresh either.

	set current [$gui getCurrentBlock]
	if {$current == $theblock} {
	    incr $msgtype ; # Accumulate error statistics 
	}

	# We are convinced that the block is fine, so we go forward
	# and remember its information.

	set file           [$blkmgr getFile $theblock]
	set key            [list $file $lno $col]
	set msgcache($key) [list $theblock $msgtype $mid $msg]

	if {$current == $theblock} {
	    #puts stderr "$self report >>> rq'refresh"
	    $self RequestWindowRefresh
	}

	#puts stderr "$self report <<< $theblock $thestate"
	return
    }

    # method color --
    #
    #	Returns the color to use for a type of message
    #
    # Arguments:
    #	mtype	- Type of message to colorize
    #
    # Results:
    #	A color specification

    method color {mtype} {
	switch -exact -- $mtype {
	    error   {return [pref::prefGet highlight_chk_error]}
	    warning {return [pref::prefGet highlight_chk_warning]}
	}
	return -code error "Illegal type \"$mtype\""
    }

    # method cacheClear --
    #
    #	Clear out cache information for a particular file (block actually).
    #
    # Arguments:
    #	blk	- block of file
    #
    # Results:
    #	None.

    method cacheClear {blk} {
	#puts stderr "$self clear >>> $blk"

	set file [$blkmgr getFile $blk]
	foreach k [array names msgcache [list ${file} *]] {
	    unset msgcache($k)
	}
	unset -nocomplain blkcache($blk)

	$self RequestWindowRefresh
	#puts stderr "$self clear <<<"
	return
    }

    method cacheClearAll {} {
	#puts stderr "$self clear-all >>>"
	foreach blk [array names blkcache] {
            $self cacheClear $blk
        }
	#puts stderr "$self clear-all <<<"
        return
    }

    method RequestWindowRefresh {} {
	if {!$msgup} {
	    set msgup 1
	    after idle [mymethod RefreshDisplay]
	}
	return
    }
    method RefreshDisplay {} {
	set msgup 0
	$chkwin updateWindow
	return
    }

    # method cacheAdd --
    #
    #	Add a syntax error to the cache.
    #
    # Arguments:
    #	line	- line of defective command
    #	col	- start column ...
    #	mtype	- type of message
    #	msgtext	- text of message
    #
    # Results:
    #	None.

    method cacheAdd {line col mtype msgtext} {
	return
    }

    # method get --
    #
    #	Retrieve ordered list of knnown syntax errors.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Ordered list of known syntax errors

    method get {} {
	set res [list]

	foreach k \
		[lsort -index 0 \
		[lsort -index 1 -integer \
		[lsort -index 2 -integer \
		[array names msgcache]]]] {
	    foreach {file line col} $k break
	    foreach {blk mtype mid msg} $msgcache($k) break
	    lappend res $blk $file $line $col $mtype $mid $msg
	}
	return $res
    }

    method errorvar {} {return [varname error]}
    method warnvar  {} {return [varname warning]}
}

snit::type cstate {
    # Context for a single checker process.
    # Input file, origin block id, pipe handle, ...

    # Channel handle for the anon pipe used to talk to a checker process.
    variable pipe ""

    # The name of the tmp file the script is stored in for usage by
    # the checker.
    variable tmpnam  ""

    # Internal state of result parser / handler ...
    variable mybuffer ""

    variable checker ""

    variable block  ""
    #variable source ""

    # construction does NOT start the pipe.
    constructor {thechecker theblock thesource} {
	set checker   $thechecker
	set block     $theblock
	$self tmpsave $thesource

	$thechecker cacheClear $theblock

	set core [pref::prefGet staticSyntaxCore]
	set supp [pref::prefGet staticSyntaxSuppress]

	set     cmd [$checker cmd]
	lappend cmd -onepass
	lappend cmd -as script
	lappend cmd -use Tcl$core

	foreach msg $supp {
	    lappend cmd -suppress $msg
	}

	lappend cmd $tmpnam

	#puts stderr "$self constructor >>> pipe $cmd ..."

	set mybuffer ""

	# Limitation of Tcl when using pipes! checker will return
	# information only after encountering eof. But we are unable
	# to close only half of the pipe. ... We are now using a tmp
	# file to be read by checker and only read from the pipe.

	set        pipe [open "|$cmd" r]
	fileevent $pipe readable [mymethod result]
	return
    }

    destructor {
	# Kill process, if existing.
	#puts stderr "$self destructor >>>"

	if {[catch {
	    file delete $tmpnam
	} msg]} {
	    #puts stderr "$self destructor >>> err: $msg"
	    after idle [list bgerror "Error deleting tmp file $tmpnam:\n$msg"]
	}

	#puts stderr "$self destructor >>> deleted tmp file: $tmpnam"

	if {$pipe != {}} {
	    #puts stderr "$self destructor >>> close $pipe"
	    if {[catch {
		close $pipe
	    } msg]} {
		#puts stderr "    close error: $msg"
	    }
	    set pipe ""
	}

	$checker done $block $self
	#puts stderr "<<<"
	return
    }

    method tmpsave {src} {
	set tmpnam [fileutil::tempfile tcldebugger[pid]_check_]

	#puts stderr "$self tmpsave >>> $tmpnam"

	set              tmp    [open $tmpnam w]
	puts -nonewline $tmp $src
	close           $tmp

	#puts stderr "$self tmpsave <<<"
	return
    }

    # method result --
    #
    #	Handle incoming checker results.
    #	(Error/Warn, Update of UI, ...)
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method result {} {
	# Handle special cases: Incomplete line, EOF reached.

	if {[eof $pipe]} {
	    #puts stderr "$self result >>> EOF"

	    # Mark the block as done.
	    $checker mark $block $self
	    # Clean up local and other state
	    $self destroy

	    #puts stderr "$self result <<< done"
	    return
	}
	if {[gets $pipe line] < 0} {return}

	# Handle the line ...
	#puts stderr "$self result >>> $line"

	# The old code, scraping the human-readable output of the
	# checker is obsolete with the use of -as script. The lines we
	# are getting are now complete commands, and the totality of
	# the result is a script. We buffer up until we have a
	# complete command and then run it, provided that it is a
	# message and not something else. For incomplete commands we
	# wait for more input.

	append mybuffer $line\n
	if {![info complete $mybuffer]} return

	# Trim eol from the command. Now the command is a Tcl list,
	# and we can treat it as such. We handle only the 'message'
	# commands now, nothing else the checker may provide us (like
	# progress, statistics, etc.).
	set mybuffer [string trim $mybuffer]
	if {[lindex $mybuffer 0] eq "message"} {
	    # Defered handling of the message ...
	    after 0 [linsert $mybuffer 0 $self]
	}

	set mybuffer ""
	# New error or warning, dissected and stored.
	return
    }

    # Callback invoked for each message received from the checker.
    method message {dict} {
	#puts stderr "$self message >>> "
	# Unpack the message
	array set m $dict

	#parray m
	# (1) Get the full line in the src (Note counting from 0 !)
	# (2) Find command in line (=> columns)
	# (3) Propagate collected information to code window

	set msgtype $m(messageID)
	set msgid   $m(messageID)
	set lno     $m(line)
	set msg     $m(messageText)
	set col     [lindex $m(commandStart,portable) 1]
	set cole    [expr {$col + [string length $m(badCommandLine)]}]

	#puts stderr "$self message >>> $lno, $msgtype, $msg"

	switch -glob $msgtype {
	    warn* - nonPort* {set msgtype warning}
	    default          {set msgtype error}
	}

	#puts stderr "$self result >>> cmd = $m(badCommandLine)"
	#puts stderr "$self result >>> $col ... $cole"
	#puts stderr "$self result >>> $msgtype"

	$checker report $block $self $lno $col $cole $msgtype $msg $msgid

	#puts stderr "$self message <<< done"
	return
    }
}

# ### ### ### ######### ######### #########

proc SHOWFRAMES {level {all 1}} {
    set n [info frame]
    set i 0
    set id 1
    while {$n} {
	puts "[expr {$level == $id ? "**" : "  "}] frame [format %3d $id]: [info frame $i]"
	::incr i -1
	::incr id -1
	::incr n -1
	if {($level > $id) && !$all} break
    }
    return
}

# ### ### ### ######### ######### #########
## Ready to go

package provide checker_bridge 1.0

