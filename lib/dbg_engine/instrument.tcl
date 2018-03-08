# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# instrument.tcl --
#
#	Procedures used to instrument the Tcl script.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: instrument.tcl,v 1.7 2001/10/17 18:08:33 andreas_kupries Exp $


package require parser

package provide instrument 1.0
namespace eval instrument {

    namespace export addExtension addCommand nubCommand

    # Stores the array of extensions that the instrumentor is using.
    
    variable  extensions
    array set extensions {
	incrTcl 0
	tclx 0
	expect 0
    }

    # Stores the block currently being instrumented.
    
    variable block {}

    # Stores the script currently being instrumented.

    variable script {}
    
    # List of line numbers in current script that contain the
    # start of an instrumented line of code.

    variable lines {}

    # List of character offsets, one per line, declaring where in the
    # script each line begins. Note that the first line always begins
    # at character 0. And EOL, aka \n is counted as one character.

    variable loffset {}

    # List of line numbers in current script that contain the
    # start of an instrumented line of code containing a command
    # capable of spawning new debugger sessions. See 'spawnCmds'
    # below.

    variable spawnlines {}

    # List of command ranges for the script being instrumented.
    # This is used in the coverage system of the TDK debugger.

    variable ranges {}

    # Command map. An array mapping from lines to the command
    # ranges beginning on that line. This can be used to determine
    # the range of influence for a line based marker.

    variable cmdmap


    # List of commands which define spawnpoints.

    variable spawnCmds {}

    # Stores the instrumented code while it is being generated.  The
    # resultStack contains a list of partially completed result strings.

    variable result {}
    variable cmdInfoStack {}
    variable suppress 0

    # The anchor records the range within the script being instrumented that
    # should be included in the next string that is appended to the result.
    # The anchorStart indicates the byte offset of the first character in the
    # range.  The anchorEnd is a range whose last character is the end of
    # the anchor range.
    
    variable anchorStart 0
    variable anchorEnd [list 0 0]

    # Stores the location associated with the current command being
    # instrumented. 

    variable location {}

    # This flag acts as a lock for this file because the instrumenter is
    # not reentrant. It is set to 1 whenever the instrumentor is in use.

    variable busy 0

    # This variable can be sent to an error handling procedure that
    # gets passed the script and the current range whenever an error
    # occurs.  The errorCode global variable will contain information
    # about the error - This has been changed, the information is now
    # transfered as additional argument.  If this procedure returns 1,
    # the instrumenter will attempt to continue.  Otherwise the
    # instrumenter will generate an error.  -- The handler is a
    # command prefix (command + possible arguments)

    variable errorHandler {}

    # Records if the current statement is part of a command substitution.

    variable isSubcommand 0

    # Records if the current statement contains literal expansions. If
    # yes, then all of its words, except for true dynamic expansion
    # (token type 'expand') have to be considered non-literal and
    # not be parsed further.
    # User:   'parseWord'.
    # Setter: 'parseScript', based on data from 'hasExpansion'.

    variable hasLitexp 0

    # Record if the current file has expansions at all. If not we can
    # shortcut in hasExpansion.

    variable hasAnyExp 0

    # The contextStack is a list used to keep track of incrTcl state.

    variable contextStack {global}

    # This table describes the instrumentation actions that need to be
    # take for each of the core Tcl commands.  The first column is that
    # name of the command to instrument.  The second column is the earliest
    # Tcl version that the rule should be applied to.  The third column
    # is a command prefix that should be invoked to handle the command.
    # The list of tokens and the current token index will be appended to
    # the command.

    variable coreTclCmds {
        after 	7.5	{parseOption {
			    {cancel	    {parseCommand}}
			    {idle	    {parseSimpleArgs 1 1 {parseBody}}}
			    {info	    {parseCommand}}
			} {parseSimpleArgs 2 2 {parseWord parseBody}}}
	catch	7.3	{parseSimpleArgs 1 2 {parseBody parseWord}}
	eval	7.3	{parseSimpleArgs 1 1 {parseBody}}
	expr	7.3	{parseSimpleArgs 1 1 {parseExpr}}
	for	7.3	{parseSimpleArgs 4 4 {parseBody parseExpr parseBody \
						parseBody}}
	foreach	7.3	{parseTail 3 {parseWord parseBody}}
	if 	7.3	{parseIfCmd}
	fcopy	8.0	{parseSimpleArgs 2 6 {
				parseWord parseWord
				{parseSwitches 0 {
				    {-command parseBody}
				    {-size parseWord}
				} {parseWord}}
			    }
			}
	fileevent 7.5	{parseSimpleArgs 3 3 {parseWord parseWord parseBody}}
	namespace 8.0	{parseOption {
			    {eval	{wrapCommand DbgNub_NamespaceEval 2 \
					    {parseWord parseBody}}}
			} {parseCommand}}
	package	7.5	{parseOption {
			    {ifneeded 	{parseSimpleArgs 3 3 \
				    {parseWord parseWord parseBody}}}
			} {parseCommand}}
	proc	7.3	{parseSimpleArgs 3 3 {parseWord parseWord parseBody}}
	return	7.3	{parseReturnCmd}
	switch	7.3	{parseSwitchCmd}
	time	7.3	{parseSimpleArgs 1 2 {parseBody parseWord}}
	while	7.3	{parseSimpleArgs 2 2 {parseExpr parseBody}}

	dict    8.5     {parseOption {
	    {filter {parseSimpleArgs 3 4 {
		parseWord
		{parseOption {
		    {script {parseSimpleArgs 2 2 {parseWord parseBody}}}
		} {parseCommand}}
	    }}}
	    {for    {parseSimpleArgs 3 3 {parseWord parseWord parseBody}}}
	    {with   {parseTail 2 {parseWord parseBody}}}
	} {parseCommand}}

	try 8.6 {parseTryCmd}
    }

    variable incrTclCmds {
	body	2.0	{wrapCommand DbgNub_WrapItclBody 3 \
		{parseWord parseWord parseItclBody}}
	class	2.0	{parseSimpleArgs 2 2 \
				{parseWord {parseBody parseIncr22Class}}}
	class	3.0	{parseItclClass}
	configbody 2.0	{parseSimpleArgs 2 2 {parseWord parseItclBody}}
	namespace 2.1	{parseOption {
	    {all	parseCommand}
	    {children	parseCommand}
	    {parent	parseCommand}
	    {qualifiers	parseCommand}
	    {tail	parseCommand}
	} {parseTail 2 {parseWord parseIncr22NSBody}}}
	namespace 3.0	{parseOption {
			    {eval	{wrapCommand DbgNub_NamespaceEval 2 \
					    {parseWord parseBody}}}
			} {parseCommand}}
	constructor 3.0	{parseCommand}
	destructor 3.0	{parseCommand}
	method	3.0	{parseCommand}
	private	3.0	{parseCommand}
	protected 3.0	{parseCommand}
	public	3.0	{parseCommand}
	variable 3.0	{parseCommand}

	itcl::body       3.0	{wrapCommand DbgNub_WrapItclBody 3 \
		{parseWord parseWord parseItclBody}}
	itcl::class      3.0	{parseItclClass}
	itcl::configbody 3.0	{wrapCommand DbgNub_WrapItclConfig 2 \
		{parseWord parseItclBody}}
    }

    variable tclxCmds {
	commandloop 8.0		{parseSwitches 1 {
	    -async
	    {-interactive parseWord}
	    {-prompt1 parseBody}
	    {-prompt2 parseBody}
	    {-endcommand parseBody}
	} {}}
	for_array_keys 8.0	{parseSimpleArgs 3 3 \
				    {parseWord parseWord parseBody}}
	for_file 8.0		{parseSimpleArgs 3 3 \
				    {parseWord parseWord parseBody}}
	for_recursive_glob 8.0	{parseSimpleArgs 4 4 \
				    {parseWord parseWord parseWord parseBody}}
	loop 8.0		{parseSimpleArgs 4 5 {parseWord parseExpr \
					parseExpr {parseTail 1 \
					{parseExpr parseBody}}}}
	try_eval 8.0		{parseSimpleArgs 2 3 {parseBody}}
	signal 8.0		{parseSwitches 1 {-restart} {
				 parseSimpleArgs 2 3 \
					{parseWord parseWord parseBody}}
	}
    }

    variable expectCmds {
	exp_exit 5.28		{parseOption {
	    {-onexit	{parseSimpleArgs 1 1 {parseBody}}}
	} parseCommand}
	exp_interact 5.28	{parseExpect parseInteractTokens}
	exp_trap 5.28		{parseExpTrapCmd}
	expect 5.28		{parseExpect parseExpectTokens}
	expect_after 5.28	{parseOption {{-info parseCommand}} \
		{parseExpect parseExpectTokens}
	}
	expect_background 5.28	{parseOption {{-info parseCommand}} \
		{parseExpect parseExpectTokens}
	}
	expect_before 5.28	{parseOption {{-info parseCommand}} \
		{parseExpect parseExpectTokens}
	}
	expect_tty 5.28		{parseExpect parseExpectTokens}
	expect_user 5.28	{parseExpect parseExpectTokens}
	interact 5.28		{parseExpect parseInteractTokens}
	trap 5.28		{parseExpTrapCmd}
    }

    variable extraCmds {}
    # TODO: command prefixes - lsort -command, trace

    variable  extraNubCmds
    array set extraNubCmds {}
}

# instrument::loadHandlers --
#
#	Load the command handlers for a given version of an extension.
#
# Arguments:
#	extname		The extension name.
#	version		The version to load.
#
# Results:
#	None.

proc instrument::loadHandlers {extname version} {
    variable handler

    foreach {name cmdVersion cmd} [set ::instrument::${extname}Cmds] {
	if {$cmdVersion <= $version} {
	    set handler($name) $cmd
	}
    }
    return
}

# instrument::initialize --
#
#	This function is called when we start debugging a new
#	application.  We pass in the Tcl version number to
#	if certain behavior should change.  (Like instrumenting
#	the namespace command.)
#
# Arguments:
#	version		The Tcl Version of the debugged application.
#
# Results:
#	None.

proc instrument::initialize {tclVersion} {
    variable handler
    variable extensions
    variable extraCmds

    if {[info exists handler]} {
	unset handler
    }

    # Expect should be initialized first in case we need to override any
    # handlers in other extensions.  Expect is always lowest priority
    # when installing handlers.

    if {$extensions(expect)} {
	# We only support one version for now.
	loadHandlers expect 5.28
    }

    # Initialize the Tcl core.

    loadHandlers coreTcl $tclVersion

    if {$extensions(incrTcl)} {
	if {$tclVersion >= 8.0} {
	    set incrVersion 3.0
	} else {
	    set incrVersion 2.2
	}
	loadHandlers incrTcl $incrVersion
    }

    if {$extensions(tclx)} {
	# Tclx uses the same version numbers as Tcl.
	loadHandlers tclx $tclVersion
    }

    if {[info exists extraCmds]} {
	foreach {extra} $extraCmds {
	    set handler([lindex $extra 0]) [lindex $extra 1]
	}
    }
    return
}

# instrument::extension --
#
#	This command turns on or off the instrumentation of the
#	built-in packages.
#
# Arguments:
#	package		One of the following pre-defined packages that
#			the instrumentor knows about.  These include:
#				incr - incr Tcl (not done yet)
#	op		If true add it to the list of packages we
#			instrument, else remove it.
#
# Results:
#	None.

proc instrument::extension {package op} {
    variable extensions

    set extensions($package) $op
    return
}

# instrument::addExtension --
#
#	This routine must be the first command in an extension file.
#	It registers an extension and specifies the API version.
#
# Arguments:
#	ver	The API version requested.  Must be 2.0.
#	desc	Description of the extension.
#
# Results:
#	None.

proc instrument::addExtension {ver desc} {
    if {$ver ne "2.0"} {
	error "Error in $desc: Extension requested unsupported version $ver"
    }
    return
}



# instrument::addCommand --
#
#	Allow an extension to add a new command handler.
#
# Arguments:
#	command		Command to register handler for.
#	action		The action to invoke in the slave interpreter
#			when this command is being instrumented.
#
# Results:
#	None.

proc instrument::addCommand {command action} {
    variable extraCmds
    lappend  extraCmds [list $command $action]
    return
}


# instrument::spawnCommand --
#
#	Allow an extension to declare a command as spawning
#
# Arguments:
#	command		Command to register as spawning
#
# Results:
#	None.

proc instrument::spawnCommand {command} {
    variable spawnCmds
    if {[lsearch -exact $spawnCmds $command] < 0} {
	lappend spawnCmds $command
    }
    return
}


# instrument::nubCmdWrapper --
#
#	Allow an extension to define code used in the 'nub'.
#
# Arguments:
#	command		Command to register handler for.
#	action		The action to invoke in the slave interpreter
#			when this command is being instrumented.
#
# Results:
#	None.

proc instrument::nubCmdWrapper {name arguments body} {
    variable extraNubCmds
    set      extraNubCmds($name) [list $arguments $body]
    return
}

proc instrument::nubScript {} {
    variable extraNubCmds

    if {![array size extraNubCmds]} {return {}}

    set result [list]
    foreach n [array names extraNubCmds] {
	foreach {a b} $extraNubCmds($n) break
	lappend result [list lappend DbgNub(externalWrappedCommandList) $n]

	# HACK: Use a name for the wrapper command which will work
	# even if the command is namespaced, and the destination
	# interpreter is not. The nub will decide whether it can make
	# use of it or not, but it has to accept the wrapper anyway.

	regsub -all {::} $n {__} n
	lappend result [list proc DbgNub_${n}Wrapper $a $b]
    }

    return [join $result \n]
}

# instrument::Init --
#
#	Initialize the instrumentation state for a new block.
#
# Arguments:
#	block		The block being instrumented.
#
# Results:
#	None.

proc instrument::Init {blkmgr theblock} {
    variable block       $theblock
    variable ranges      {}
    variable cmdmap
    variable script      [$blkmgr getSource $theblock]

    #puts stderr "Init: [string length $script] for blk $theblock"

    variable lines       {}
    variable loffset     {}
    variable spawnlines  {}
    variable result      {}
    variable anchorStart 0
    variable anchorEnd   [list 0 0]
    variable location    [loc::makeLocation $theblock 1 \
	    [parse getrange $script]]
    variable locStack    {}
    variable hasAnyExp   [expr {
				([string first {{*}} $script] >= 0) ||
				([string first {{expand}} $script] >= 0)
			    }]
    array unset cmdmap *

    # Immediately compute the character offsets for the lines,
    # i.e. where in the block each line begins.

    lappend loffset 0
    set     total   0
    foreach line [split $script \n] {
	set  len [string length $line]
	incr len ; # Count EOL too.
	incr total $len
	lappend loffset $total
    }
    # We have one offset more than number of lines. The last
    # offset is the number of characters in the whole block,
    # and also points to the first character after the last line.
    # We can ignore it. It actually might be useful as sentinel
    # for searches.
    return
}

# instrument::getLineOffset --
#
#	Determine the offset of the line the character offset falls
#	into. This uses a binary search over a list of offsets for
#	the largest value which is still smaller than (or equal to)
#	the character offset itself.
#
# Arguments:
#	loffset		List of offsets
#	charpos		Character offset
#
# Results:
#	A list containinng the number of the line, and its offset
#	in the block, in this order.

proc instrument::getLineOffset {loffset charpos} {

    set start 0
    set end   [llength $loffset]

    while {1} {
	set len [expr {$end - $start}]
	if {$len == 1} {
	    return [list $start [lindex $loffset $start]]
	}
	if {$len == 2} {
	    # Check the top half first.

	    incr end -1
	    set c [lindex $loffset $end]
	    if {$c <= $charpos} {
		return [list $end $c]
	    }

	    # Has to be bottom half

	    return [list $start [lindex $loffset $start]]
	}

	set middle [expr {($start + $end) / 2}]
	set result [lindex $loffset $middle]

	if {$result == $charpos} {
	    return [list $middle $result]
	}

	if {$result < $charpos} {
	    set start $middle
	} else {
	    set end $middle
	}
    }
}


# instrument::getLocation --
#
#	Retrieve the location for the current command.
#
# Arguments:
#	None.
#
# Results:
#	Returns the location.

proc instrument::getLocation {} {
    variable location
    return  $location
}

# instrument::setLocation --
#
#	Updates the current location information to refer to the
#	specified range.  Recomputes the current line number.
#
# Arguments:
#	range		The new location range.
#
# Results:
#	None.

proc instrument::setLocation {range} {
    variable location
    variable script
    variable block

    set oldRange [loc::getRange $location]
    set line     [loc::getLine  $location]
    if {[lindex $range 0] < [lindex $oldRange 0]} {
	incr line -[parse countnewline $script $range $oldRange]
    } else {
	incr line [parse countnewline $script $oldRange $range]
    }
    set location [loc::makeLocation $block $line $range]
    return
}

# instrument::pushContext --
#
#	Save the current command information on a stack.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc instrument::pushContext {} {
    set ::instrument::locStack [linsert $::instrument::locStack 0 \
	    $::instrument::location]
}

# instrument::popContext --
#
#	Restore a previously saved command context.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc instrument::popContext {} {
    set ::instrument::location [lindex $::instrument::locStack 0]
    set ::instrument::locStack [lrange $::instrument::locStack 1 end]
}

# instrument::setAnchor --
#
#	Sets the anchor position emitting any pending ranges.
#
# Arguments:
#	range		The anchor is set to the beginning of this range.
#
# Results:
#	None.

proc instrument::setAnchor {range} {
    Flush
    set ::instrument::anchorStart [lindex $range 0]
    set ::instrument::anchorEnd [list $::instrument::anchorStart 0]
    return
}

# instrument::resetAnchor --
#
#	This function moves the cursor back to the current anchor point
#	without emitting any text.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc instrument::resetAnchor {} {
    set ::instrument::anchorEnd [list $::instrument::anchorStart 0]
}

# instrument::setCursor --
#
#	Sets the cursor to the end of the specified range.
#
# Arguments:
#	range		The range that indentifies the cursor location.
#
# Results:
#	None.

proc instrument::setCursor {range} {
    set ::instrument::anchorEnd $range
    return
}

# instrument::Flush --
#
#	Emit any pending text and advance the anchor.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc instrument::Flush {} {
    # Emit any pending text and advance the anchor

    set end [expr {[lindex $::instrument::anchorEnd 0] \
	    + [lindex $::instrument::anchorEnd 1]}]
    append ::instrument::result [parse getstring $::instrument::script \
	    [list $::instrument::anchorStart \
	    [expr {$end - $::instrument::anchorStart}]]]
    set ::instrument::anchorStart $end
    set ::instrument::anchorEnd [list $end 0]
    return
}

# instrument::appendString --
#
#	Emit everything between the anchor and the cursor and append
#	the specified string.
#
# Arguments:
#	string		The string to append.
#
# Results:
#	None.

proc instrument::appendString {string} {
    Flush
    append ::instrument::result $string
    return
}

# instrument::beginCommand --
#
#	Begin instrumentation of a new command.  This routine takes
#	care of various bookkeeping functions like updating the anchor
#	and the location.  It also pushes a new result accumulator.
#
# Arguments:
#	cmdRange	The range of the current command.
#
# Results:
#	None.

proc instrument::beginCommand {cmdRange} {
    variable cmdInfoStack
    variable result
    variable suppress

    # Update the line number and set the anchor at the beginning of the
    # command, skipping over any comments or whitespace.

    setLocation $cmdRange
    setAnchor   $cmdRange

    # Save the information about the current command and then set up
    # for the nested command.
    lappend cmdInfoStack [list [getLocation] $suppress $result]
    set result {}
    set suppress 0

    return
}

# instrument::endCommand --
#
#	Emit the transformed command string and restore the command info.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc instrument::endCommand {cmdRange} {
    variable cmdInfoStack
    variable result
    variable suppress
    variable isSubcommand
    variable lines
    variable ranges
    variable cmdmap

    # Ensure that everything up to the end of the range has been emitted.
    setCursor $cmdRange
    Flush

    # Save values that were computed for this command
    set cmdString $result
    set cmdSuppress $suppress

    # Restore the command info
    lassign [lindex $cmdInfoStack end] cmdLocation suppress result isSubCommand
    set cmdInfoStack [lreplace $cmdInfoStack end end]
    
    if {!$cmdSuppress} {
	lappend lines  [set l [loc::getLine  $cmdLocation]]
	lappend ranges [set r [loc::getRange $cmdLocation]]
	appendString [list DbgNub_Do $isSubcommand $cmdLocation $cmdString]
	lappend cmdmap($l) $r
    } else {
	appendString $cmdString
    }
    return
}

# instrument::isLiteral --
#
#	Check to see if a word only contains text that doesn't need to
#	be substituted.
#
# Arguments:
#	word		The token for the word to check.
#
# Results:
#	Returns 1 if the word contains no variable or command substitutions,
#	otherwise returns 0.

proc instrument::isLiteral {word} {
    variable script 

    if {[lindex $word 0] ne "simple"} {
	foreach token [lindex $word 2] {
	    set type [lindex $token 0]
	    if {$type ne "text" && $type ne "backslash"} {
		return 0
	    }
	}

	# The text contains backslash sequences.  Bail if the text is
	# not in braces because this would require complicated substitutions.
	# Braces are a special case because only \newline is interesting and
	# this won't interfere with recursive parsing.

	if {[string index $script [parse charindex $script [lindex $word 1]]] \
		eq "\{"} {
	    return 1
	} else {
	    return 0
	}
    }
    return 1
}

# instrument::getLiteral --
#
#	Retrieve the literal string value of a word.
#
# Arguments:
#	word		The token for the word to fetch.
#	resultVar	The name of a variable where the text should be
#			stored.
#
# Results:
#	Returns 1 if the text contained no variable or command substitutions,
#	otherwise returns 0.

proc instrument::getLiteral {word resultVar} {
    variable script

    upvar 1 $resultVar result
    set result ""
    foreach token [lindex $word 2] {
	set type [lindex $token 0]
	if {$type eq "text"} {
	    append result [parse getstring $script [lindex $token 1]]
	} elseif {$type eq "backslash"} {
	    append result [subst [parse getstring $script [lindex $token 1]]]
	} else {
	    set result [parse getstring $script [lindex $word 1]]
	    return 0
	}
    }
    return 1
}

# instrument::Instrument --
#
#	Instrument a block of code.
#
# Arguments:
#	block		The block to instrument.
#
# Results:
#	Returns the instrumented string, or "" if the
#	script failed to be instrumented.

proc instrument::Instrument {blkmgr block} {
    # Instrumenting a new script. 
    if {$::instrument::busy} {
	error "The instrumenter is being called while in use!"
    }
    set ::instrument::busy 1

    Init $blkmgr $block
    if {[catch {parseScript} msg]} {
	global errorCode

	# If the error is generated by the instrumenter because the
	# script failed to parse, we should restore the original errorCode
	# before returning, otherwise we need to report the error.

	if {[lindex $errorCode 0] ne "CAUGHT"} {
	    bgerror $msg
	} else {
	    set errorCode [lindex $errorCode 1]
	}

	# Instrumentation failed, so return an empty script.

	set ::instrument::busy 0
	return {}
    } else {
	Flush
	set ::instrument::busy 0
	return $::instrument::result
    }
    
}

# instrument::parseScript --
#
#	Instrument a script.  This procedure may be called directly
#	to instrument a new script, or recursively to instrument
#	subcommands and control function arguments.  If called with
#	only a block arg, it is assumed to be a new script and line
#	number information is initialized.
#
# Arguments:
#	scriptRange	The range in the script to instrument. A
#			default of {} indicates the whole script.
#
# Results:
#       None.

proc instrument::runHandler {loc ec} {
    variable errorHandler
    return [eval [linsert $errorHandler end $loc $ec]]
}

proc instrument::parseScript {{scriptRange {}}} {
    # Iterate over all of the commands in the script range, advancing the
    # range at the end of each command.

    variable script
    variable handler
    variable errorHandler
    variable spawnCmds
    variable spawnlines

    pushContext
    set first 1
    if {$scriptRange eq ""} {
	set scriptRange [parse getrange $script]
    }
    for {} {[parse charlength $script $scriptRange] > 0} \
	    {set scriptRange $tail} {
	# Parse the next command

	if {[catch {lassign [parse command $script $scriptRange] \
		comment cmdRange tail tree}]} {
	    # An error occurred during parsing.

	    if {$errorHandler ne ""} {
		set ec $::errorCode
		pushContext
		setLocation [list [lindex $ec 2] 1]
		set location [getLocation]
		popContext

		if {[runHandler $location $ec]} {
		    # Ignore the error and wrap the rest of the script
		    # as a single statement.

		    if {!$first} {
			appendString \n
		    }
		    beginCommand $scriptRange
		    # Do nothing so the text is emitted verbatim
		    endCommand $scriptRange
		    break
		}
	    }
	    # Note we are bailing all the way out here, so we don't need
	    # to pop the context or do any other cleanup.

	    error "Unable to parse" $::errorInfo [list CAUGHT $::errorCode]
	}

	if {([llength $tree] == 0) \
		|| ([parse charlength $script $cmdRange] <= 0)} {
	    continue
	}

	if {!$first} {
	    appendString \n
	} else {
	    set first 0
	}

	set index 0
	beginCommand $cmdRange
	set argc [llength $tree]


	# Look for expansions. Invoke the generic command checker on
	# all of the words in the statement if such is found.

	# Note that in contrast to tclchecker we do not have to handle
	# the case of 'before 8.5', not really. We can instrument
	# normally, generic, and will get a runtime error if the
	# executing tclsh does not understand the construct. Perfectly
	# fine.
	set forcegeneric [hasExpansion $tree lit litatend]
	#puts /generic/exp$forcegeneric/lit$lit/atend$litatend

	while {$index < $argc} {
	    set cmdToken [lindex $tree $index]

	    if {!$forcegeneric && [getLiteral $cmdToken cmdName]} {
		incr index
		set cmdName [string trimleft $cmdName :]

		if {[lsearch -exact $spawnCmds $cmdName] >= 0} {
		    lappend spawnlines [loc::getLine [getLocation]]
		}

		if {[info exists handler($cmdName)]} {
		    set index [eval [linsert $handler($cmdName) end $tree $index]]
		} else {
		    set index [parseCommand $tree $index]
		}
	    } else {
		variable hasLitexp
		set oldHasLitexp $hasLitexp
		set hasLitExp $lit

		set index [parseCommand $tree $index]

		set hasLitExp $oldHasLitexp
	    }
	}
	set endoff [lindex [lindex $tree end] 1]
	# Correct where to expect the end of the command if a litexp
	# closed the command. Without that correction the actual
	# closing brace would not be counted, causing the generation
	# of broken code, with a missing closing brace.
	#
	# Note: litatend not only flags the correction, but also
	#       conveys how far we have to correct.
	if {$litatend} {
	    foreach {s len} $endoff break
	    incr len $litatend
	    set endoff [list $s $len]
	}
	endCommand $endoff
    }
    popContext
    return
}

proc instrument::hasExpansion {tree lv lev} {
    variable script
    variable hasAnyExp
    upvar 1 $lv lit $lev lend

    #puts anyexp=$hasAnyExp
    #puts tree/$tree/

    # The check is more complex than would be thought at first
    # sight. This is due to the fact that literal expansions (litexp),
    # i.e. expansion of the form '{ * } { ... }' are hidden from us by
    # the parser. It has already found the proper literal constituent
    # words and returns them to us.

    # At runtime this ensures that the runtime has nothing dynamic to
    # do as the expansion is gone by the time it goes to work. Here
    # however this is a pain, as we have to reconstruct if there had
    # been litexps.

    # Because if there are, its words have to ignored completely.
    # Parsing into them is overly complex and so we bail on that (x).
    # And if the last word in the last litexp is also the last word of
    # the command we further have to correct the length of the command
    # as well, as we would not count the actual closing brace
    # otherwise.

    # (x) To make things a bit more spicy, the words describing
    # dynamic command expansions are an exception to this no-parse
    # rule, they can still be parsed deeper.

    # The check as done below is essentially a state machine. It
    # returns three results:
    #
    # (1) If we have any type of expansion in the command.
    # (2) If we have at least one litexp in the command.
    # (3) If we have a litexp closing with the end of the command, and
    #     how much to correct.
    #
    # (3) implies (2), and (2) implies (1).

    set exp  0 ; # Flag for (1)
    set lit  0 ; # Flag for (2)
    set lend 0 ; # Flag for (3)

    # Shortcut. The whole file did not contain
    # { * } nor { expand }. There cannot be an expansion.

    if {!$hasAnyExp} { return 0 }

    set leb  1 ; # State code.
    #            # 1 - search for litexp start
    #            # 0 - search for litexp end

    set index 0
    set idxstop -1 ; # Index where last litexp ended.
    set corr 0     ; # How far to correct.

    set cmdoff [lindex $tree 0 1 0]
    #set cmdlen [expr {[lindex $tree end 1 0] + [lindex $tree end 1 1]}]
    #puts "AA\t$cmdoff $cmdlen <<[parse getstring $script [list $cmdoff $cmdlen]]>>"

    foreach word $tree {
	#puts \tword/$word/\t\"[parse getstring $script [lindex $word 1]]\"

	if {[lindex $word 0] eq "expand"} {
	    # Note that this cannot occur within a litexp, as words
	    # inside of such are always simple.
	    set exp 1
	    incr index
	    continue
	    # No need to check for a litexp start prefix or stop
	    # suffix of this word, this cannot occur.
	}

	set range [lindex $word 1]
	if {$leb} {
	    # Searching for the start of a litexp.
	    set off [lindex $range 0]

	    if {[regexp {\{\*\}\{\s*$} \
		     [parse getstring $script [list $cmdoff [expr {$off - $cmdoff}]]]]} {
		set leb 0
		set lit 1
		set exp 1
	    }
	} else {
	    # Searching for the end of the last opened litexp.
	    set off [expr [lindex $range 0] + [lindex $range 1]]
	    if {[regexp -indices {^\s*\}} \
		     [parse getstring $script [list $off [expr {[string length $script] - $off}]]] \
		     match]} {
		foreach {s e} $match break
		set corr [expr {$e - $s + 1}]
		set leb 1
		set idxstop $index
	    }
	}

	incr index
    }

    # Compute (3) from the remembered index information
    set lend [expr {($index - 1) == $idxstop ? $corr : 0}]
    return $exp
}

# instrument::parseCommand --
#
#	This is the generic command wrapper.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseCommand {tokens index} {
    set argc [llength $tokens]
    while {$index < $argc} {
	set index [parseWord $tokens $index]
    }
    setCursor [lindex [lindex $tokens end] 1]
    return $argc
}

# instrument::parseWord --
#
#	Examine a token for subcommands. 
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.
#	Emits the instrumented text of the token, leaving the
#	cursor pointing just after the token.

proc instrument::parseWord {tokens index} {
    variable hasLitexp
    set word [lindex $tokens $index]
    set type [lindex $word 0]
    switch -- $type {
	subexpr -
	variable -
	word {
	    if {$hasLitexp} return
	    foreach subword [lindex $word 2] {
		parseWord [list $subword] 0
	    }
	}
	command {
	    if {$hasLitexp} return
	    variable isSubcommand
	    set oldState $isSubcommand
	    set isSubcommand 1

	    set range [lindex $word 1]
	    set range [list [expr {[lindex $range 0] + 1}] \
		    [expr {[lindex $range 1] - 2}]]
	    setCursor [list [lindex $range 0] 0]
	    parseScript $range

	    set isSubcommand $oldState
	}
	expand {
	    # One child, which can be either a sub-command or a
	    # variable reference. A command we parse into.

	    set range    [lindex $word 1]
	    set children [lindex $word 2]
	    set child    [lindex $children 0]
	    if {[lindex $child 0] eq "command"} {
		variable isSubcommand
		set oldState $isSubcommand
		set isSubcommand 1

		set range [lindex $child 1]
		set range [list \
			       [expr {[lindex $range 0] + 1}] \
			       [expr {[lindex $range 1] - 2}]]
		setCursor [list [lindex $range 0] 0]
		parseScript $range

		set isSubcommand $oldState
	    }
	}
    }
    setCursor [lindex $word 1]
    return [incr index]
}

# instrument::parseBody --
#
#	Attempt to parse a word like it is the body of a control
#	structure.  If the word is a simple string, it emits tags to
#	indicate that the body is instrumented and passes it to
#	parseScript, otherwise it just treats it like a normal word
#	and looks for subcommands.
#
# Arguments:
#	bodyProc	Optional. The procedure to invoke to handle
#			parsing the body script.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed..

proc instrument::parseBody {args} {
    variable isSubcommand
    variable script

    if {[llength $args] == 2} {
	lassign $args tokens index
	set bodyProc parseScript
    } else {
	lassign $args bodyProc tokens index
    }

    set word [lindex $tokens $index]

    set oldState $isSubcommand
    set isSubcommand 0

    if {[isLiteral $word]} {
	set quote [string index $script \
		[parse charindex $script [lindex $word 1]]]
	set range [lindex $word 1]
	set addBrace 0
	if {$quote eq "\""} {
	    set range [list [expr {[lindex $range 0] + 1}] \
		    [expr {[lindex $range 1] - 2}]]
	    set closeChar "\""
	} elseif {$quote eq "\{"} {
	    set range [list [expr {[lindex $range 0] + 1}] \
		    [expr {[lindex $range 1] - 2}]]
	    set closeChar "\}"
	} else {
	    set closeChar "\}"
	    set addBrace 1
	}

	setCursor [list [lindex $range 0] 0]
	if {$addBrace} {
	    appendString \{
	}

	# At this point the location should point to the command being
	# instrumented (e.g. the whole "proc" statement).

	appendString "\n# DBGNUB START: [list [getLocation]]\n"
	$bodyProc $range
	appendString "\n# DBGNUB END\n$closeChar"
	setAnchor [list [expr {[lindex [lindex $word 1] 0] \
		+ [lindex [lindex $word 1] 1]}] 0]
	incr index
    } else {
	set index [parseWord $tokens $index]
    }
    set isSubcommand $oldState
    return $index
}

# instrument::parseOption --
#
#	This function handles parsing of subcommand options.
#
# Arguments:
#	optionTable	A list of pairs describing the valid options.  Each
#			pair is an option name followed by a command prefix.
#	default		The action to take if no matching options are present.
#	tokens		The list of tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the next token to be parsed.

proc instrument::parseOption {optionTable default tokens index} {
    if {($index == [llength $tokens]) && ($default eq "")} {
	return $index
    }
    
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [parseCommand $tokens $index]
    }
    
    set keywords {}
    foreach keyword $optionTable {
	lappend keywords [lindex $keyword 0]
    }

    if {![matchKeyword $optionTable $value 0 script]} {
	if {$default ne ""} {
	    set script $default
	} else {
	    set script parseCommand
	}
    } else {
	incr index
    }
    return [eval $script {$tokens $index}]

}

# instrument::parseSimpleArgs --
#
#	This function applies a sequence of actions to each argument
#	in the command until there are no more arguments.  If there are
#	more arguments than actions, then the last action is repeated
#	for each trailing argument.  If the number of arguments falls
#	outside of the min/max bounds, then the command is just passed
#	to parseCommand.
#
# Arguments:
#	min		The minimum number of arguments allowed.
#	max		The maximum number of arguments allowed.
#	argList		A list of scripts that should be called for
#			the corresponding argument.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseSimpleArgs {min max argList tokens index} {
    set argc [llength $tokens]

    if {$argc < ($min + $index) \
	    || (($max > -1) && ($argc > ($max + $index)))} {
	return [parseCommand $tokens $index]
    }

    while {$index < $argc} {
	set index [eval [lindex $argList 0] {$tokens $index}]
	if {[llength $argList] > 1} {
	    set argList [lrange $argList 1 end]
	}
    }
    return $argc
}

# instrument::parseTail --
#
#	This function is similar to parseSimpleArgs, except it matches
#	arguments with scripts starting from the end.  If there are more
#	arguments than scripts, the first one listed is used for all of
#	the leading arguments.  If there are fewer arguments than scripts
#	scripts will be dropped from the beginning of the list until the
#	correct number is reached.
#
# Arguments:
#	min		The minimum number of arguments required to use the
#			argCmds instead of parseCommand.
#	argCmds		A list of scripts that should be called for
#			the corresponding argument.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseTail {min argCmds tokens index} {
    set argc [llength $tokens]
    set cmdc [llength $argCmds]
    set count [expr {$argc - $index}]

    if {$count < $min} {
	return [parseCommand $tokens $index]
    }
    if {$count < $cmdc} {
	set argCmds [lrange $argCmds [expr {$cmdc - $count}] end]
    }
    while {$index < $argc} {
	set index [eval [lindex $argCmds 0] {$tokens $index}]
	if {($argc - $index) < $cmdc} {
	    set argCmds [lrange $argCmds 1 end]
	}
    }
    return $argc
}


# instrument::parseSwitches --
#
#	This function parses optional switch arguments.
#
# Arguments:
#	exact		Boolean value.  If true, then switches have to match
#			exactly. 
#	switches	A list of switch/action pairs.  The action may be
#			omitted if the switch does not take an argument.
#			If "--" is included, it acts as a terminator.
#	chainCmd	The command to use to check the remainder of the
#			command line arguments.  May be null for trailing
#			switches.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseSwitches {exact switches chainCmd tokens index} {
    set argc [llength $tokens]
    while {$index < $argc} {
	set word [lindex $tokens $index]
	if {![getLiteral $word value]} {
	    break
	}
	if {[string index $value 0] ne "-"} {
	    break
	}

	set script ""
	if {![matchKeyword $switches $value $exact script]} {
	    return [parseCommand $tokens $index]
	} else {
	    incr index
	    if {$value eq "--"} {
		break
	    }
	    if {$script ne ""} {
		if {$index >= $argc} {
		    return $argc
		}
		
		set index [eval $script {$tokens $index}]
	    }
	}
    }
    if {$chainCmd ne ""} {
	return [eval $chainCmd {$tokens $index}]
    }
    return $index
}

# instrument::wrapCommand --
#
#	This function backs up to the command token and inserts a command
#	string.
#
# Arguments:
#	newName		The new command string.
#	numArgs		Only wrap the command if the number of arguments
#			matches the specified number (or range of numbers). 
#	argList		A list of scripts that should be called for
#			the corresponding argument.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::wrapCommand {newName numArgs argList tokens index} {
    variable result

    set argc [llength $tokens]

    if {[llength $numArgs] == 1} {
	set min $numArgs
	set max $numArgs
    } else {
	set min [lindex $numArgs 0]
	set max [lindex $numArgs 1]
    }
    set rest [expr {[llength $tokens] - $index}]
    if {$rest < $min || $rest > $max} {
	return [parseCommand $tokens $index]
    }
    set result "$newName $result"
    while {$index < $argc} {
	set index [eval [lindex $argList 0] {$tokens $index}]
	if {[llength $argList] > 1} {
	    set argList [lrange $argList 1 end]
	}
    }
    return $argc
}

# instrument::parseExpr --
#
#	Attempt to parse a word like it is an expression.
#	If the word is a simple string, it is examined for subcommands
#	within the expression, otherwise it is handled like a normal word.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	None.

proc instrument::parseExpr {tokens index} {
    variable script
    variable errorHandler

    set word [lindex $tokens $index]

    #  Don't attempt to parse as an expression if the text contains
    #  substitutions.
    
    if {![isLiteral $word]} {
	return [parseWord $tokens $index]
    }

    # Compute the range of the expression from the first and last token in
    # the word.

    set start [lindex [lindex [lindex [lindex $word 2] 0] 1] 0]
    set end [lindex [lindex [lindex $word 2] end] 1]
    set range [list $start [expr {[lindex $end 0] + [lindex $end 1] - $start}]]


    # Parse the word as an expression looking for subcommands.

    setCursor [list $start 0]
    if {[catch {parse expr $script $range} tree]} {
	# An error occurred during parsing.

	if {$errorHandler ne ""} {
	    set ec $::errorCode
	    pushContext
	    setLocation [list [lindex $ec 2] 1]
	    set location [getLocation]
	    popContext
	    if {[runHandler $location $ec]} {
		# Ignore the error and just parse the expression as
		# a normal word.
		return [parseWord $tokens $index]
	    }
	}

	error "Unable to parse" $::errorInfo [list CAUGHT $::errorCode]
    }
    parseWord [list $tree] 0
    setCursor [lindex $word 1]
    return    [incr index]
}

#
# Incr Tcl specific procedures
#


# instrument::parseIncr22Class --
#
#	This is a very special script parser for the incr Tcl
#	class command (version 2.2 only).  This will only
#	instrument the bodies of special functions and will
#	not instrument anything at the toplevel.
#
# Arguments:
#	range		The range of the body being parsed.
#
# Results:
#       Returns the instrumented code.

proc instrument::parseIncr22Class {range} {
    # Iterate over all of the commands in the script range, advancing the
    # range at the end of each command.

    variable script
    variable errorHandler
    variable suppress

    pushContext
    set first 1
    for {} {[parse charlength $script $range] > 0} \
	    {set range $tail} {
	# Parse the next command

	if {[catch {
	    lassign [parse command $script $range] \
		    comment cmdRange tail tree
	}]} {
	    # An error occurred during parsing.

	    if {$errorHandler ne ""} {
		set ec $::errorCode
		pushContext
		setLocation [list [lindex $ec 2] 1]
		set location [getLocation]
		popContext
		if {[runHandler $location $ec]} {
		    # Ignore the error and skip to the end of the statement.
		    
		    if {!$first} {
			appendString \n
		    }

		    # Emit everything else as a single command with no
		    # instrumentation.

		    beginCommand $range
		    set suppress 1
		    endCommand $range
		    break
		}
	    }
	    # Note we are bailing all the way out here, so we don't need
	    # to pop the context or do any other cleanup.

	    error "Unable to parse" $::errorInfo [list CAUGHT $::errorCode]
	}

	if {([llength $tree] == 0) \
		|| ([parse charlength $script $cmdRange] <= 0)} {
	    continue
	}

	if {!$first} {
	    appendString "\n"
	} else {
	    set first 0
	}

	# Update the line number and set the anchor at the beginning of the
	# command, skipping over any comments or whitespace.

	beginCommand $cmdRange

	set ::instrument::suppress 1

	set argc [llength $tree]
	set index 0
	while {$index < $argc} {
	    set cmdToken [lindex $tree $index]
	    if {[getLiteral $cmdToken cmdName]} {
		incr index
		set cmdName [string trimleft $cmdName :]
		switch -- $cmdName {
		    private -
		    protected -
		    public {
			# Skip over the protection keyword and continue
			# with the next word unless there is only one more
			# token in which case a body will follow
			if {($argc - $index) != 1} {
			    continue
			}
			set index [parseBody parseIncr22Class $tree $index]
		    }
		    variable {
			if {($argc - $index) != 3} {
			    break
			}
			set index [parseItclBody parseConfigure $tree \
				[expr {$argc - 1}]]
		    }
		    proc -
		    method {
			if {($argc - $index) != 3} {
			    break
			}
			set index [parseItclBody parseMethod $tree \
				[expr {$argc - 1}]]
		    }
		    constructor {
			set len [expr {($argc - $index)}]
			if {($len != 2) && ($len != 3)} {
			    break
			}
			set index [parseItclBody parseMethod $tree \
				[expr {$argc - 1}]]
		    }
		    destructor {
			if {($argc - $index) != 1} {
			    break
			}
			set index [parseItclBody parseMethod $tree $index]
		    }
		    default {
			# Skip to the end of the command since we can't
			# instrument anything at the top level of the class
			# declaration.
			break
		    }
		}
	    } else {
		set index [parseCommand $tree $index]
	    }
	}
	endCommand [lindex [lindex $tree end] 1]
    }
    popContext
    return
}

# instrument::parseIncr22NSBody --
#
#	This function parses the last argument to "namespace" for
#	[incr Tcl] 2.2 to handle the special case where it begins with a
#	dash and so isn't a valid body.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseIncr22NSBody {tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word string] && ([string index $string 0] eq "-")} {
	return [parseWord $tokens $index]
    } else {
	return [wrapCommand DbgNub_NamespaceEval 1 {parseBody} $tokens $index]
    }
}

# instrument::parseItclBody --
#
#	This is a generic wrapper function that handles the special
#	syntax of an [incr Tcl] body.
#
# Arguments:
#	script		The script to invoke on the body.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseItclBody {args} {
    if {[llength $args] == 3} {
	lassign $args script tokens index
    } else {
	lassign $args tokens index
	set script ""
    }
    set word [lindex $tokens $index]
    if {[getLiteral $word string] && ([string index $string 0] eq "@")} {
	parseWord $tokens $index
    } else {
	if {$script ne ""} {
	    parseBody $script $tokens $index
	} else {
	    parseBody $tokens $index
	}
    }
    return [incr index]
}

# instrument::parseMethod --
#
#	Parse an [incr Tcl] 2.2 method body and emit code to transfer the value
#	cached by DbgNub_Return into a proper result.  This is equivalent to
#	DbgNub_WrapItclBody, but since we can't uplevel into a class context
#	in version 2.2, we have to emit the code inline.  Be sure to keep
#	these two functions in sync.
#
# Arguments:
#	range		The range of the body being parsed.
#
# Results:
#	None.

proc instrument::parseMethod {range} {
    appendString "#DBG INSTRUMENTED PROC TAG
    upvar #0 errorInfo DbgNub_errorInfo errorCode DbgNub_errorCode
    set DbgNub_level \[DbgNub_infoCmd level\]
    eval \[list DbgNub_PushContext \$DbgNub_level\] \[info function \[lindex \[info level 0\] 0\] -type -name -args\]
    set DbgNub_catchCode \[DbgNub_UpdateReturnInfo \[DbgNub_catchCmd {\n"
    parseScript $range
    appendString "\n} DbgNub_result\]\]
    foreach DbgNub_index \[info locals\] {
	if {\[trace vinfo \$DbgNub_index\] != \"\"} {
	    if {[catch {upvar 0 DbgNub_dummy \$DbgNub_index}]} {
		catch {unset \$DbgNub_index}
	    }
	}
	catch {unset \$DbgNub_index}
    }
    DbgNub_PopContext
    return -code \$DbgNub_catchCode -errorinfo \$DbgNub_errorInfo -errorcode \$DbgNub_errorCode \$DbgNub_result"
    return
}

# instrument::parseConfigure --
#
#	Parse an [incr Tcl] 2.2 configure body. This is equivalent to
#	DbgNub_WrapItclConfig, but since we can't uplevel into a class context
#	in version 2.2, we have to emit the code inline.  Be sure to keep
#	these two functions in sync.
#
# Arguments:
#	range		The range of the body being parsed.
#
# Results:
#	None.

proc instrument::parseConfigure {range} {
    appendString "DbgNub_ItclConfig \{\n"
    parseScript $range
    appendString "\n\}"
    return
}

# instrument::simpleControl --
#
#	This is a generic wrapper function that handles simple control
#	constructs where one or more arguments are scripts.
#
# Arguments:
#	bodies		A list of integers specifying the argument positions
#			that contain scripts.
#	tokens		The parse tokens for the command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::simpleControl {bodies tokens index} {
    set argc [llength $tokens]
    set offset $index

    while {$index < $argc} {
	if {[lsearch -exact $bodies [expr {$index - $offset}]] >= 0} {
	    parseBody $tokens $index
	} else {
	    parseWord $tokens $index
	}
	incr index
    }
    return $index
}

# instrument::itclProtection --
#
#	This is the generic handler for any of the Itcl protection
#	commands (public, private, protected).
#
# Arguments:
#	tokens		The parse tokens for the command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::itclProtection {tokens index} {
    variable suppress
    set argc [llength $tokens]

    if {$argc == $index} {
	return [parseCommand $tokens $index]
    } elseif {($argc - $index) == 1} {
	set word [lindex $tokens $index]
	set suppress 1
	return [parseBody $tokens $index]
    } else {
	# Restart command lookup on the current token
	return $index
    }
}

# instrument::pushHandlers --
#
#	Pushes a set of handlers, returning the old set in a list.
#
# Arguments:
#	newList		A list of handler/action pairs to be set into the
#			handlers array.
#
# Results:
#	Returns a list of handler/action pairs corresponding to the old
#	values.

proc instrument::pushHandlers {newList} {
    variable handler

    set oldWrappers {}
    foreach pair $newList {
	set cmd [lindex $pair 0]
	lappend oldWrappers [list $cmd $handler($cmd)]
	set handler($cmd) [lindex $pair 1]
    }
    return $oldWrappers
}

# instrument::popHandlers --
#
#	Restore a set of handlers saved by a previous call to pushHandlers.
#
# Arguments:
#	saveList	The list of handler/action pairs to restore.
#
# Results:
#	None.

proc instrument::popHandlers {saveList} {
    variable handler

    foreach pair $saveList {
	set handler([lindex $pair 0]) [lindex $pair 1]
    }
    return
}

# instrument::leaveClass --
#
#	Push a non-class context.
#
# Arguments:
#	args	The remainder of the command to invoke.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::leaveClass {args} {
    set save [pushHandlers {
	{constructor	parseCommand}
	{destructor	parseCommand}
	{method		parseCommand}
	{proc		{parseSimpleArgs 3 3 {parseWord parseWord parseBody}}}
	{variable	parseCommand}
	{private	parseCommand}
	{protected	parseCommand}
	{public		parseCommand}
    }]

    set index [eval $args]
    popHandlers $save
    return $index
}

# instrument::parseItclClass --
#
#	This routine wraps a Itcl 3.0 or later class.
#
# Arguments:
#	tokens		The parse tokens for the command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseItclClass {tokens index} {
    variable handler

    # Set up the class context

    set save [pushHandlers {
	{constructor	{leaveClass wrapCommand DbgNub_Constructor {2 3} \
				{parseWord parseItclBody}}}
	{destructor	{leaveClass wrapCommand DbgNub_WrapItclBody 1 \
				{parseItclBody}}}
	{method		{leaveClass wrapCommand DbgNub_WrapItclBody 3 \
				{parseWord parseWord parseItclBody}}}
	{proc		{leaveClass wrapCommand DbgNub_WrapItclBody 3 \
				{parseWord parseWord parseItclBody}}}
	{variable	{leaveClass wrapCommand DbgNub_WrapItclConfig 3 \
				{parseWord parseWord parseItclBody}}}
	{private	itclProtection}
	{protected	itclProtection}
	{public		itclProtection}
    }]
	
    # Now parse the body of the class

    if {[llength $tokens] == 3} {
	set index [wrapCommand DbgNub_Class 2 {parseWord parseBody} \
		$tokens $index]
    } else {
	set index [parseCommand $tokens $index]
    }

    # Restore the previous command wrappers

    popHandlers $save
    return $index
}

# instrument::parseReturnCmd --
#
#	This routine wraps the return command.
#
# Arguments:
#	tokens		The parse tokens for the command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseReturnCmd {tokens index} {
    set argc [llength $tokens]

    # We only need to wrap the return command if it uses the -code
    # option.  If we have 2 or fewer arguments then they couldn't
    # be using the -code option and we don't need to treat this 
    # command specially.

    if {($argc - $index) < 2} {
	return [parseCommand $tokens $index]
    }
    
    # We replace the call to "return" with a call to "DbgNub_Return" 
    # so we can handle the weird case of -code being used.

    appendString "DbgNub_Return "
    setAnchor [lindex [lindex $tokens 1] 1]
    while {$index < $argc} {
	set index [parseWord $tokens $index]
    }
    return $index
}

# instrument::parseTryCmd --
#
#	This routine wraps the try/on/trap/finally command.
#
# Arguments:
#	tokens		The parse tokens for the command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseTryCmd {tokens index} {
    set argc [llength $tokens]
    set     commands {}
    set i 1
    append commands "parseBody \$tokens $i\n"
    incr i

    # Look ahead to determine if this is a well formed try statement
    # The control flow is a little complicated here so we use a catch to 
    # implement a nonlocal jump to the end.  If the body of the catch
    # calls "error", the command didn't parse correctly, so we just call the
    # generic parseCommand routine.  Otherwise if the body of the catch calls
    # "return" or completes normally, we execute the accumulated commands to
    # emit the instrumented statement.

    if {[catch {
	while {1} {
	    # At this point in the loop, lindex i refers to the start
	    # of one of the possible clauses, i.e.
	    # on   x () body,
	    # trap x () body,
	    # finally body.

	    if {$i > $argc} {
		error OVER-SHOT
	    }

	    if {($i < $argc) \
		    && [getLiteral [lindex $tokens $i] text] \
		    && ($text eq "on")} {
		# on
		# code
		# var list
		incr i 3
		append commands "parseBody \$tokens $i\n"
		incr i

		if {$i >= $argc} {
		    # We completed successfully so bail out to the catch
		    break
		}
		# check the next clause
		continue
	    }

	    if {($i < $argc) \
		    && [getLiteral [lindex $tokens $i] text] \
		    && ($text eq "trap")} {
		# trap
		# pattern
		# var list
		incr i 3
		append commands "parseBody \$tokens $i\n"
		incr i
		if {$i >= $argc} {
		    # We completed successfully so bail out to the catch
		    break
		}
		# check the next clause
		continue
	    }

	    if {($i < $argc) \
		    && [getLiteral [lindex $tokens $i] text] \
		    && ($text eq "finally")} {
		# finally
		incr i
		append commands "parseBody \$tokens $i\n"
		incr i
		if {$i >= $argc} {
		    # We completed successfully so bail out to the catch
		    break
		}
		# finally must be last clause.
		error NOT-LAST
	    }
	    error NONE
	}
    } msg]} {
	parseCommand $tokens $index
    } else {
	eval $commands
    }
    return $argc
}

# instrument::parseIfCmd --
#
#	This routine wraps the if command.
#
# Arguments:
#	tokens		The parse tokens for the command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseIfCmd {tokens index} {
    set i $index
    set argc [llength $tokens]
    set commands  ""
    set failed 0
    set text {}

    # Look ahead to determine if this is a well formed if statement
    # The control flow is a little complicated here so we use a catch to 
    # implement a nonlocal jump to the end.  If the body of the catch
    # calls "error", the command didn't parse correctly, so we just call the
    # generic parseCommand routine.  Otherwise if the body of the catch calls
    # "return" or completes normally, we execute the accumulated commands to
    # emit the instrumented statement.

    if {[catch {
	while {1} {
	    # At this point in the loop, lindex i refers to an expression
	    # to test, either for the main expression or an expression
	    # following an "elseif".  The arguments after the expression must
	    # be "then" (optional) and a script to execute.

	    append commands "parseExpr \$tokens $i\n"
	    if {$i >= $argc} {
		error {}
	    }
	    incr i
	    if {($i < $argc) \
		    && [getLiteral [lindex $tokens $i] text] \
		    && ($text eq "then")} {
		incr i
	    }

	    if {$i >= $argc} {
		error {}
	    }
	    append commands "parseBody \$tokens $i\n"
	    incr i
	    if {$i >= $argc} {
		# We completed successfully so bail out to the catch
		return
	    }

	    if {[getLiteral [lindex $tokens $i] text] && ($text eq "elseif")} {
		incr i
		continue
	    }
	    break
	}

	# Now we check for an else clause
	if {[getLiteral [lindex $tokens $i] text] && ($text eq "else")} {
	    incr i

	    if {$i >= $argc} {
		error {}
	    }
	}
	if {($i+1) != $argc} {
	    error {}
	}
	append commands "parseBody \$tokens $i\n"
    }] == 1} {
	parseCommand $tokens $index
    } else {
	eval $commands
    }
    return $argc
}


# instrument::parseSwitchCmd --
#
#	This routine wraps the switch command.
#
# Arguments:
#	tokens		The parse tokens for the command.
#	index		The index of the next word to be parsed.
#
# Results:
#	Returns the index of the next token to be parsed.

proc instrument::parseSwitchCmd {tokens index} {
    set argc  [llength $tokens]
    set i $index

    if {$argc < 3} {
	return [parseCommand $tokens $index]
    }

    set argc [llength $tokens]
    set i 1

    set commands  ""
    set failed 0

    # Look ahead to determine if this is an instrumentable switch statement.
    # The control flow is a little complicated here so we use a catch to 
    # implement a nonlocal jump to the end.  If the body of the catch
    # calls "error", the command didn't parse correctly, so we just call the
    # generic parseCommand routine.  Otherwise if the body of the catch calls
    # "return" or completes normally, we execute the accumulated commands to
    # emit the instrumented statement.

    if {[catch {
	# Skip past the switch arguments
	while {$i < $argc} {
	    if {![getLiteral [lindex $tokens $i] string]} {
		break
	    }
	    switch -exact -- $string {
		-nocase -
		-exact -
		-glob -
		-regexp {
		    # nocase is 8.5+
		    incr i
		}
		-indexvar -
		-matchvar {
		    # This option is 8.5+.
		    incr i 2 ;# The -*var option is not alone, but has an
		    #         # argument we have to skip too.
		}
		-- {
		    incr i
		    break
		}
		default {
		    break
		}
	    }
	}

	append commands "setCursor [list [lindex [lindex $tokens [expr {$i - 1}]] 1]]\n"

	# The next argument should be the string to switch on.

	append commands "parseWord  \$tokens $i\n"
	incr i

	# We are then left with two cases: 1. one argument which
	# need to split into words.  Or 2. a bunch of pattern body
	# pairs.

	if {($i + 1) == $argc} {
	    # Check to be sure the body doesn't contain substitutions

	    set bodyToken [lindex $tokens $i]
	    if {![isLiteral $bodyToken]} {
		append commands "parseWord \$tokens $i\n"
		incr i
		# We can't descend here so we jump to the end
		return
	    }
	    
	    # If the body token contains backslash sequences, there will
	    # be more than one subtoken, so we take the range for the whole
	    # body and subtract the braces.  Otherwise it's a "simple" word
	    # with only one part and we can get the range from the text
	    # subtoken. 

	    if {[llength [lindex $bodyToken 2]] > 1} {
		set range [lindex $bodyToken 1]
		set range [list [expr {[lindex $range 0] + 1}] \
			[expr {[lindex $range 1] - 2}]]
	    } else {
		set range [lindex [lindex [lindex $bodyToken 2] 0] 1]
	    }

	    append commands "setCursor [list [list [lindex $range 0] 0]]\n"

	    # Bug 88396. Hide continuation lines in the p/b list from 'parse list'.
	    lassign $range s l ; set e [expr {$s + $l - 1}]
	    incr s -1 ; set pre  [string range $::instrument::script 0 $s]
	    incr s    ; set mid  [string range $::instrument::script $s $e]
	    incr e    ; set post [string range $::instrument::script $e end]

	    foreach {pattern body} [parse list \
					$pre[string map [list \\\n {  }] $mid]$post \
					$range] {

		append commands "setCursor [list $pattern]\n"

		# If the body is not "-", parse it as a command word and pass
		# the result to parseBody.  This isn't quite right, but it
		# should handle the common cases.

		if {$body ne "" && [parse getstring $::instrument::script $body] ne "-"} {
		    append commands "parseBody \[lindex \
		    \[parse command \$::instrument::script [list $body]\] \
		    3\] 0\n"
		}
	    }
	    append commands "setCursor [list [lindex $bodyToken 1]]\n"
	} else {
	    while {$i < $argc} {
		append commands "parseWord \$tokens $i\n"
		incr i
		if {$i < $argc} {
		    if {(![getLiteral [lindex $tokens $i] string] \
			    || $string eq "-")} {
			append commands "parseWord \$tokens $i\n"
		    } else {
			append commands "parseBody \$tokens $i\n"
		    }
		    incr i
		}
	    }
	}
    }] == 1} {
	parseCommand $tokens $index
    } else {
	eval $commands
    }
    return $i
}

# instrument::parseExpect --
#
#	Handler for "expect" style commands.
#
# Arguments:
#	chainCmd	The command to call once the tokens have
#			been parsed correctly.
#	tokens		The list of word tokens after the initial
#			command and subcommand names
#	index		The index into the token tree where the 
#			parser should start.
#
# Results:
#	Returns the index of the next to parse.

proc instrument::parseExpect {chainCmd tokens index} {
    set end  [llength $tokens]
    set argc [expr {$end - $index}]

    # The command was called with no arguments, so just return.

    if {$argc < 1} {
	return $end
    }

    # Determine which command to execute.  We have four possible cases: 
    # 1. One argument which should be split into words.
    # 2. One argument which should NOT be split into words.
    # 3. Two arguments where the first is "-brace" and the second  
    #    is the body that needs to be split into words.
    # 4. A bunch of pattern/action pairs.

    if {$argc == 1} {	
	set word [lindex $tokens $index]
	if {![getLiteral $word body]} {
	    return [parseWord $tokens $index]
	}

	# Check to see if the body looks like a single pattern or a
	# set of pattern/action pairs.  Whitespace followed by a newline
	# indicates that it is a pattern/action pair.

	if {[regexp "(\[ \t\r\])?\n.*" $body]} {
	    set tokens [parseExpRange $tokens $index]
	    set index  0
	}
    } elseif {$argc == 2} {
	# Get the switch and the body.  If either are non-literal
	# then punt and check nothing specific.

	set word [lindex $tokens $index]
	if {![getLiteral $word switch]} {
	    return [parseCommand $tokens $index]
	}
	set word [lindex $tokens [expr {$index + 1}]]
	if {![getLiteral $word body]} {
	    return [parseCommand $tokens $index]
	}

	# If the switch is "-brace" increment the index so the rangeCmd
	# is called with the index pointing to the body.

	if {$switch eq "-brace"} {
	    incr index
	    set tokens [parseExpRange $tokens $index]
	    set index  0
	}
    }

    return [$chainCmd $tokens $index]
}

# instrument::parseExpRange --
#
#	This function reparses the current token as a list of additional
#	arguments to the expect command.
#	
#	tokens		The list of word tokens after the initial
#			command and subcommand names
#	index		The index into the token tree where the 
#			parser should start.
#
# Results:
#	Returns the new list of tokens to parse.

proc instrument::parseExpRange {tokens index} {
    variable script
    variable errorHandler

    set word   [lindex $tokens $index]
    set range  [lindex $word 1]
    set quote  [string index $script [parse charindex $script $range]]
    if {$quote eq "\"" || $quote eq "\{"} {
	set range [list [expr {[lindex $range 0] + 1}] \
		[expr {[lindex $range 1] - 2}]]
    }
    
    set result {}

    for {} {[parse charlength $script $range] > 0} \
	    {set range $tail} {
	# Parse the next command

	if {[catch {foreach {comment cmdRange tail tree} \
		[parse command $script $range] {}}]} {
	    # An error occurred during parsing so generate the error.

	    if {$errorHandler ne ""} {
		set ec $::errorCode
		pushContext
		setLocation [list [lindex $ec 2] 1]
		set location [getLocation]
		popContext
		if {[runHandler $location $ec]} {
		    # Ignore the error and treat the rest of the range
		    # as a single token
		    return [list [list simple $range \
			    [list [list text $range {}]]]]
		}
	    }
	    # Note we are bailing all the way out here, so we don't need
	    # to pop the context or do any other cleanup.

	    error "Unable to parse" $::errorInfo [list CAUGHT $::errorCode]
	}

	if {[parse charlength $script $cmdRange] <= 0} {
	    continue
	}
	eval [linsert $tree 0 lappend result]
    }

    return $result
}

# instrument::expMatch --
#
#	Using the Expect style of matching, determine if the string
#	matches one of the keywords.
#
# Arguments:
#	keywords	A list of keywords to match.
#	str		The word to match.
#	minlen		Minimum number of chars required to match.
#
# Results:
#	Return 1 if this matches or 0 if it does not.

proc instrument::expMatch {keywords str minlen} {
    set end [string length $str]
    foreach key $keywords {
	set m $minlen
	for {set i 0} {$i < $end} {incr i; incr m -1} {
	    if {[string index $str $i] ne [string index $key $i]} {
		break
	    }
	}
	if {($i == $end) && ($m <= 0)} {
	    return 1
	}
    }
    return 0
}

# instrument::parseExpectTokens --
#
#	Parse the contents of an expect pattern/action list.
#
# Arguments:
#	tokens		The list of word tokens after the initial
#			command and subcommand names
#	index		The index into the token tree where the 
#			parser should start.
#
# Results:
#	Returns the index of the next to parse.

proc instrument::parseExpectTokens {tokens index} {
    set argc [llength $tokens]
    while {$index < $argc} {
	if {![getLiteral [lindex $tokens $index] arg]} {
	    # If we have a substitution we can't tell which of the remaining
	    # arguments are patterns, switches or actions.

	    return [parseCommand $tokens $index]
	}

	# Check for switches.

	switch -glob -- $arg {
	    "eof" -
	    "null" -
	    "default" -
	    "timeout" -
	    "full_buffer" {
		# No-Op.  This keyword is considered to be the "pattern"
		# in the pattern/action pair.  The next word is the action.
		incr index
	    }
	    -* {
		set arg [string range $arg 1 end]
		if {($arg eq "-") || [expMatch {glob regexp exact} $arg 2]} {
		    # The next word is a pattern followed by a command.
		    
		    incr index
		    set index [parseWord $tokens $index]
		} elseif {[expMatch {timestamp iread iwrite indices} $arg 2]} {
		    incr index
		    continue
		} elseif {[expMatch "notransfer" $arg 1]} {
		    incr index
		    continue
		} elseif {[expMatch "nocase" $arg 3]} {
		    incr index
		    continue
		} elseif {$arg eq "nobrace"} {
		    incr index
		    continue
		} elseif {$arg eq "i" || [expMatch "timeout" $arg 2]} {
		    # The next token is a switch argument.
		    
		    incr index
		    set index [parseWord $tokens $index]
		    continue
		} else {
		    # This is an unexpected parameter, so bail on the
		    # rest of the tokens.
		    return [parseCommand $tokens $index]
		}
	    }
	    default {
		# This is a pattern.  Check the pattern for subcommands.
		
		set index [parseWord $tokens $index]
	    }
	}

	# The next argument is a body.
	
	if {$index < $argc} {
	    set index [parseBody $tokens $index]
	}
    }
    return $index
}

# instrument::parseInteractTokens --
#
#	Parse the contents of an exp_interact pattern/action list.
#
# Arguments:
#	tokens		The list of word tokens after the initial
#			command and subcommand names
#	index		The index into the token tree where the 
#			parser should start.
#
# Results:
#	Returns the index of the next to parse.

proc instrument::parseInteractTokens {tokens index} {
    set argc [llength $tokens]
    while {$index < $argc} {
	if {![getLiteral [lindex $tokens $index] arg]} {
	    # If we have a substitution we can't tell which of the remaining
	    # arguments are patterns, switches or actions.

	    return [parseCommand $tokens $index]
	}

	# Check for switches.

	switch -glob -- $arg {
	    "eof" -
	    "null" {
		# This keyword is considered to be the "pattern"
		# in the pattern/action pair.  The next word is the action.
		incr index
	    }
	    "timeout" {
		# The next token is a switch argument then a body.
		incr index
		set index [parseWord $tokens $index]
	    }
	    -* {
		set arg [string range $arg 1 end]
		if {($arg eq "-") \
			|| [expMatch {regexp exact} $arg 2] \
			|| ($arg eq "timeout")} {
		    # The next word is a pattern or argument followed by
		    # a command.
		    incr index
		    set index [parseWord $tokens $index]
		} elseif {$arg eq "i" \
			|| [expMatch "input" $arg 2] \
			|| [expMatch "output" $arg 3] \
			|| ($arg eq "u")} {
		    # The next word is the switch argument.

		    incr index
		    set index [parseWord $tokens $index]
		    continue
		} elseif {[expMatch {nobuffer indices} $arg 3] \
			|| [expMatch {iread iwrite timestamp} $arg 2] \
			|| ($arg eq "echo") \
			|| ($arg eq "f") \
			|| ($arg eq "F") \
			|| ($arg eq "reset") \
			|| ($arg eq "nobrace") \
			|| ($arg eq "o")} {
		    # These switches take no args.

		    incr index
		    continue
		} else {
		    # The next word is the command.

		    incr index
		}
	    }
	    default {
		# This is a pattern.  Check the pattern for subcommands.
		
		set index [parseWord $tokens $index]
	    }	
	}

	# The next argument is a body.
	
	if {$index < $argc} {
	    set index [parseBody $tokens $index]
	}
    }
    return $index
}

# instrument::parseExpTrapCmd --
#
#	This function parses the expect "exp_trap" and "trap" commands.
#
# Arguments:
#	tokens		The list of word tokens.
#	index		The index into the token tree where the 
#			parser should start.
#
# Results:
#	Returns the index of the next to parse.

proc instrument::parseExpTrapCmd {tokens index} {
    set show 0
    set argc [llength $tokens]
    for {set i $index} {$i < $argc} {incr i} {
	if {![getLiteral [lindex $tokens $i] arg]} {
	    break
	}
	switch -- $arg {	    
	    -code {
		# No-Op
	    }
	    -max -
	    -name -
	    -number {
		set show 1
	    } 
	    default {
		break
	    }
	}
    }
    
    set remaining [expr {$argc - $i}]
    if {!$show && ($remaining == 2)} {
	return [parseSimpleArgs 2 2 {parseBody parseWord} $tokens $i]
    }
    return [parseCommand $tokens $i]
}
