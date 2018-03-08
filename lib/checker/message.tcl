# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# message.tcl -- -*- tcl -*-
#
#	This file defines the messaging system for the analyzer.
#
# Copyright (c) 2002-2015 ActiveState Software Inc.
# Copyright (c) 1998-2000 Ajuba Solutions
#


# 
# SCCS: %Z% %M% %I% %E% %U%

# ### ######### ###########################
## Requisites

package require Tcl 8.5
#package require analyzer  ; # Circular
package require configure
package require pcx
package require struct::list

# ### ######### ###########################
## Implementation

namespace eval ::message {

    # ### ######### ###########################
    ## API -- Generic message types and their human-readable
    ## translations.

    variable  messages
    array set messages {
	badRegexp       {"Bad regexp pattern: %1$s" err}
	warnEscapeChar  {"\"\\%1$s\" is a valid escape sequence in later versions of Tcl." upgrade}
	warnNotSpecial  {"\"\\%1\$s\" has no meaning.  Did you mean \"\\\\%1\$s\" or \"%1\$s\"?" upgrade}
	warnQuoteChar   {"\"\\\" in bracket expressions are treated as quotes" upgrade}
	errBadBrktExp   {"the bracket expression is missing a close bracket" err}
	argAfterArgs	{"argument specified after \"args\"" err}
	argsNotDefault	{"\"args\" cannot be defaulted" err}
	badBoolean	{"invalid Boolean value" err}
	badByteNum	{"invalid number, should be between 0 and 255" err}
	badColorFormat	{"invalid color name" err}
	badContinuation {"bad continuation line, whitespace after backslash" err}
	badCursor	{"invalid cursor spec" err}
	badFloat	{"invalid floating-point value" err}
	badIndex	{"invalid index: should be integer or \"end\"" err}
	badIndexExpr	{"invalid index: should be integer or \"end\" or \"end-integer\"" err}
	badExtendedIndexExpr	{"invalid index: should be integer or \"end\" or \"end-integer\" or \"end+integer\" or integer-integer or integer+integer" err}
	badInt		{"invalid integer" err}
	badKey		{"invalid keyword \"%2$s\" must be: %1$s" err}
	badList		{"invalid list: %1$s" err}
	badLevel	{"invalid level" err}
	badMode		{"access mode must include either RDONLY, WRONLY, or RDWR" err}
	badOption	{"invalid option \"%2$s\" must be: %1$s" err}
	badPixel	{"invalid pixel value" err}
	badResource	{"invalid resource name" err}
	badSwitch	{"invalid switch: \"%1$s\"" err}
	maybeBadSwitch  {"possibly invalid switch: \"%1$s\"" warn}
	badVersion	{"invalid version number" err}
	badValidateSubst {"validate script contains unknown %%-placeholders" err}
	badRequirement	{"invalid requirement" err}
	badWholeNum	{"invalid value \"%1$s\": must be a positive integer" err}
	badNatNum	{"invalid value \"%1$s\": must be an integer > 0" err}
	badArrayIndex   {"invalid array index \"%1$s\"" err}
	mismatchOptions {"the specified options cannot be used in tandem" err}
	noExpr		{"missing an expression" err}
	noScript	{"missing a script after \"%1$s\"" err}
	noSwitchArg	{"missing argument for %1$s switch" err}
	nonDefAfterDef	{"non-default arg specified after default" err}
	nonPortChannel	{"use of non-portable file descriptor, use \"%1$s\" instead" nonPortable}
	nonPortCmd	{"use of non-portable command" nonPortable}
	nonPortCmdR	{"replace use of non-portable command with %1$s" nonPortable}
	nonPortColor	{"non-portable color name" nonPortable}
	nonPortCursor	{"non-portable cursor usage" nonPortable}
	nonPortFile	{"use of non-portable file name, use \"file join\"" nonPortable}
	nonPortOption	{"use of non-portable option" nonPortable}
	nonPortVar	{"use of non-portable variable" nonPortable}
	numArgs		{"wrong # args" err}
	numListElts	{"wrong # of list elements" err}
	obsoleteCmd	{"Obsolete usage, use \"%1$s\" instead" err}
	parse 		{"parse error: %1$s" err}
	procNumArgs	{"wrong # args for user-defined proc: \"%1$s\"" err}
	tooManyFieldArg	{"too many fields in argument specifier" err}
	warnDeprecated	{"deprecated usage, use \"%1$s\" instead" upgrade}
	warnExportPat	{"export patterns should not be qualified" warn}
	warnExpr	{"use curly braces to avoid double substitution and/or performance degradation" performance}
	warnNestedExpr	{"avoid nesting of expr in expression" performance}
	warnExtraClose	{"unmatched closing character" usage}
	warnIfKeyword	{"deprecated usage, use else or elseif" warn}
	warnNamespacePat {"glob chars in wrong portion of pattern" warn}
	warnPattern	{"possible unexpected substitution in pattern"	warn}
	warnReserved	{"keyword is reserved for use in %1$s" upgrade}
	warnRedefine	{"%1$s %2$s redefines %3$s %2$s in file %4$s on line %5$s" usage}
	warnUndefProc	{"undefined procedure: %1$s" warn}
	warnUnsupported	{"unsupported command, option or variable: use %1$s" upgrade}
	warnVarRef	{"variable reference used where variable name expected" warn}
	winAlpha	{"window name cannot begin with a capital letter" err}
	winBeginDot	{"window name must begin with \".\"" err}
	winNotNull	{"window name cannot be an empty string" err}
	warnInternalCmd {"usage of internal command, may change without notice" warn}
	invalidUsage    {"invalid usage, use \"%1$s\" instead" err upgrade}
	warnBehaviourCmd {"behaviour of command has changed, %1$s" upgrade}
	warnBehaviour   {"behaviour has changed, %1$s" upgrade}
	internalError   {"internal error: %1$s" err}
	warnReadonlyVar {"Variable \"%1$s\" is considered read-only" warn}
	arrayReadAsScalar {"Array variable \"%1$s\" read as if a scalar" err}
	warnUndefFunc   {"unknown math function: \"%1$s\"" warn}
	badMathOp       {"invalid expr operator: \"%1$s\"" err}
	nonPublicVar	{"use of private variable" nonPublic}
	warnUndefinedVar {"use of undefined variable \"%1$s\"" warn}
	warnGlobalVarColl    {"namespace variable \"%1$s\" may collide with global variable of same name" warn}
	warnShadowVar        {"Shadowing a previous definition" warn}
	warnUpvarNsNonsense  {"Non-global upvar into a namespace is undefined" warn}
	warnGlobalNsNonsense {"global into a namespace is undefined" warn}
	warnUndefinedUpvar   {"upvar'd variable \"%1$s\" missing in caller scope \"%2$s\"" warn}
	badListLength	{"invalid list length: Expected %% %1$s == %2$s" err}
	warnArgWrite    {"Overwriting procedure argument \"%1$s\"" warn}
	pragmaBad         {{Bad pragma "%1$s" before command: %2$s} warn} 
	pragmaNotComplete {{Incomplete pragma "%1$s" before command} warn} 
	warnDoubleDash {{Use -- before this computed word to prevent its possible misinterpretation as switch} warn}
	warnContinuation      {{possibly bad continuation line, blank line after backslash} warn}
	warnStyleCodeBlock    {{use curly braces to avoid double substitution in code blocks} style}
	warnStyleArgumentList {{use curly braces to avoid double substitution in argument list} style}
	warnStylePlainWord    {{use double quotes for simple words} style}
	warnStylePlainVar     {{do not use double quotes for plain variable references} style}
	warnStyleExit         {{avoid the exit command} style}
	warnStyleError        {{avoid the error command} style}
	warnStyleOneCommandPerLine {{Multiple commands on a single line} style}
	warnStyleCodeblockTooFar   {{Code blocks separated by more than one empty line} style}
	warnStyleNesting           {{Refactor code blocks > %1$s levels deep} style}
	warnNoDefault {{The %1$s command has no default branch} warn}
	warnMisplacedDefault {{The %1$s command might have a misplaced default branch} warn}
	warnStyleCodeBlockShort {{Start and end code block on a new line} style}
	warnStyleNameProcedure  {{Procedure name "%1$s" does not match style "%2$s"} style}
	warnStyleNamePackage    {{Package name "%1$s" does not match style "%2$s"} style}
	warnStyleNameVariable   {{Variable name "%1$s" does not match style "%2$s"} style}
	warnStyleNameNamespace  {{Namespace name "%1$s" does not match style "%2$s"} style}
	warnStyleNameVariableTooShort {{Variable name "%1$s" too short, need at least %2$s characters} style}
	warnStyleNameVariableTooLong  {{Variable name "%1$s" too long, want at most %2$s characters} style}
	warnStyleLineTooLong {{Line exceeds %1$s characters in length} style}
	warnStyleIndentCommand   {{Indent of command is %1$s, expected %2$s.} style}
	warnStyleIndentBlock     {{Indent for end of block is %1$s, expected %2$s.} style}
	warnStyleExprBoolEquality {{Exclude %1$s from boolean expression} style}
	warnStyleExprOperatorWhitespace {{Separate operators and expression terms with spaces} style}
	warnStyleExprOperatorParens     {{Wrap sub-expression in parens to avoid logic errors} style}
	warnBadSequence      {{The command "%1$s" is not allowed after command "%2$s" (see line %3$s), expected it after '%4$s'} warn}
	warnBadSequenceFirst {{The command "%1$s" is not allowed as first command, expected it after '%2$s'} warn}
	warnDollar {{Single dollar character might be separated from following variable name} warn}
	pcxError {{Bad PCX definition for "%1$s": "%2$s"} err}
    }

    # ### ######### ###########################

    # This var is the name of the proc to execute when a message
    # is being displayed--the default is collectMsg, which keeps messages silent,
    # but you can change it to displayTTY.

    variable displayProc message::collectMsg

    # Write to <outChannel> instead of the default stdout so 
    # we can have control over re-directing the output without
    # messing around with stdout.

    variable outChannel stdout

    # ### ######### ###########################

    # List of character offsets, one per line, declaring where in the
    # script each line begins. Note that the first line always begins
    # at character 0. And EOL, aka \n is counted as one
    # character. Data is only for the current file.

    variable loffset

    # ### ######### ###########################
}

# ### ######### ###########################
## Code to manage lines and offsets in a file.
## Computes them once per file, and conversion
## is done via bin search.

## XXX AK. Consider to remove the 'parse countnewline'
## stuff. Use offsets wherever possible, convert to
## lines only where needed.

proc ::message::initLines {script} {
    variable loffset 0

    set total 0
    foreach line [split $script \n] {
	set  len [string length $line]
	incr len ; # Count EOL too.
	incr total $len
	lappend loffset $total
    }
    return
}

proc ::message::lineOff {pos} {
    # Convert character offset pos into line number and
    # offset in that line.
    variable loffset
    set line   [FindLine $pos]
    set column [expr {$pos - [lindex $loffset $line]}]
    incr line
    return [list $line $column]
}

proc ::message::FindLine {pos} {
    variable loffset

    # Check if we have lsearch -binary in 8.5
    # for even quicker access.

    set start 0
    set end   [llength $loffset]

    while {1} {
	set len [expr {$end - $start}]
	if {$len == 1} {
	    return $start
	}
	if {$len == 2} {
	    # Check the top half first.

	    incr end -1
	    set c [lindex $loffset $end]
	    if {$c <= $pos} {
		return $end
	    }

	    # Has to be bottom half
	    return $start
	}

	set middle [expr {($start + $end) / 2}]
	set result [lindex $loffset $middle]

	if {$result == $pos} {
	    return $middle
	}

	if {$result < $pos} {
	    set start $middle
	} else {
	    set end $middle
	}
    }
}

# ### ######### ###########################

# ::message::show --
#
#	Create the message to display and call the command
#	that will dump the error message.
#
# Arguments:
#	mid		The message id for the message.
#	errRange	The range of the error relative to the start
#			of the current analyzer script.
#	clientData	Extra data used when generation the message.
#	extend		Dictionary of even more data associated with the message.
#
# Results:
#	None.

proc ::message::show {mid errRange line cmdRange clientData {extend {}}} {
    variable displayProc
    #puts MS|$mid|$errRange|L$line|$cmdRange|$clientData|
    $displayProc $mid $errRange $line $cmdRange $clientData [analyzer::getQuiet] $extend
    return
}

# ::message::showSummary --
#
#	Show summary information.
#
# Arguments:
#	None.
#
# Results:
#	None.  Summary info is printed to stdout.

proc ::message::showSummary {} {
    # Handle the pkgUnchecked warning specially. The user cannot do
    # anything to fix it, it is however deployed the checker's
    # responsibility to provide the relevant .pcx files.
    set ecount [analyzer::getErrorCount]
    set wcount [analyzer::getWarningCount]

    # Bug 81277
    array set cc [analyzer::getCodeCount]
    if {[info exists cc(coreTcl::pkgUnchecked)] && $cc(coreTcl::pkgUnchecked) > 0} {
	incr wcount -$cc(coreTcl::pkgUnchecked)
    }

    if {$::configure::machine == 2} {
	# Machine readable summary, Script Mode.

	array set pkgs [pcx::used]
	foreach name [lsort -dictionary [array names pkgs]] {
	    foreach v [lsort -dictionary [pcx::usedversions $name]] {
		PutsAlways [list summary package $pkgs($name) $v]
	    }
	}

	PutsAlways [list summary numerrors   $ecount]
	PutsAlways [list summary numwarnings $wcount]

	# Bug 81172, disabled if there are no messages at all.
	if {$ecount || $wcount} {
	    set ccs {}
	    foreach {k v} [analyzer::getCodeCount] {
		if {$k eq "coreTcl::pkgUnchecked"} continue
		lappend ccs [list $k $v]
	    }
	    foreach item [lsort -dict -decreasing -index 1 [lsort -dict -index 0 $ccs]] {
		foreach {k v} $item break
		PutsAlways [list summary message $k $v]
	    }
	}

	if {
	    $analyzer::unknownCmdsLogged &&
	    [array size analyzer::unknownCmds]
	} {
	    foreach cmd [lsort -dict [array names analyzer::unknownCmds]] {
		PutsAlways [list summary unknown $cmd]
	    }
	}

	# Bug 81277
	if {[info exists cc(coreTcl::pkgUnchecked)] && $cc(coreTcl::pkgUnchecked) > 0} {
	    # Show number of packages which were used, but for which
	    # no rule definitions were found. Use -v to see
	    # names. Talk to deployer for additional rules.

	    PutsAlways [list summary pkgUnchecked $cc(coreTcl::pkgUnchecked)]
	}
    } elseif {$::configure::machine} {
	# Machine readable summary. Dict Mode.

	array set pkgs [pcx::used]
	foreach name [lsort -dictionary [array names pkgs]] {
	    foreach v [lsort -dictionary [pcx::usedversions $name]] {
		PutsAlways [list summary [list package [list $pkgs($name) $v]]]
	    }
	}

	PutsAlways [list summary [list numerrors   $ecount]]
	PutsAlways [list summary [list numwarnings $wcount]]

	# Bug 81172, disabled if there are no messages at all.
	if {$ecount || $wcount} {
	    set ccs {}
	    foreach {k v} [analyzer::getCodeCount] {
		if {$k eq "coreTcl::pkgUnchecked"} continue
		lappend ccs [list $k $v]
	    }
	    foreach item [lsort -dict -decreasing -index 1 [lsort -dict -index 0 $ccs]] {
		foreach {k v} $item break
		PutsAlways [list summary [list message [list $k $v]]]
	    }
	}

	if {
	    $analyzer::unknownCmdsLogged &&
	    [array size analyzer::unknownCmds]
	} {
	    foreach cmd [lsort -dict [array names analyzer::unknownCmds]] {
		PutsAlways [list summary [list unknown $cmd]]
	    }
	}

	# Bug 81277
	if {[info exists cc(coreTcl::pkgUnchecked)] && $cc(coreTcl::pkgUnchecked) > 0} {
	    # Show number of packages which were used, but for which
	    # no rule definitions were found. Use -v to see
	    # names. Talk to deployer for additional rules.

	    PutsAlways [list summary [list pkgUnchecked $cc(coreTcl::pkgUnchecked)]]
	}
    } else {
	# Human-based summary

	# Show the packages loaded and checked.

	Puts ""
	Puts "Packages Checked | Version"
	Puts "-----------------|--------"
	array set pkgs [pcx::used]
	foreach name [lsort -dictionary [array names pkgs]] {
	    set pkg     $pkgs($name)
	    set verlist [lsort -dictionary [pcx::usedversions $name]]

	    Puts [format "%-17.16s  %-s" $pkg [lindex $verlist 0]]
	    if {[llength $verlist] > 1} {
		foreach v [lrange $verlist 1 end] {
		    Puts [format "%-17.16s  %-s" "" $v]
		}
	    }
	}
    
	# Show Number of errors and warnings.

	Puts ""
	Puts "Number of Errors:   $ecount"
	Puts "Number of Warnings: $wcount"

	# Bug 81172, disabled if there are no messages at all.
	# Show number of messages per message code.
	if {$ecount || $wcount} {
	    Puts ""
	    Puts "Number of messages per id:"
	    Puts "--------------------------"
	    set mlk 0
	    set mlv 0
	    set ccs {}
	    foreach {k v} [analyzer::getCodeCount] {
		if {$k eq "coreTcl::pkgUnchecked"} continue
		set l [string length $k]
		if {$l > $mlk} {set mlk $l}
		set l [string length $v]
		if {$l > $mlv} {set mlv $l}
		lappend ccs [list $k $v]
	    }
	    foreach item [lsort -dict -decreasing -index 1 [lsort -dict -index 0 $ccs]] {
		foreach {k v} $item break
		Puts [format "  %-${mlk}s  %${mlv}s" $k $v]
	    }
	}
	Puts ""

	# Show names of commands that were called but never defined.
	# Currently, Tk is not defininig widget names as procs.
	# Ignore all unknown commands that start with period.

	if {
	    $analyzer::unknownCmdsLogged &&
	    [array size analyzer::unknownCmds]
	} {
	    Puts "Commands that were called but never defined:"
	    Puts "--------------------------------------------"
	    foreach cmd [lsort -dict [array names analyzer::unknownCmds]] {
		Puts "  $cmd"
	    }
	    Puts ""
	}

	# Bug 81277
	if {[info exists cc(coreTcl::pkgUnchecked)] && $cc(coreTcl::pkgUnchecked) > 0} {
	    # Show number of packages which were used, but for which
	    # no rule definitions were found. Use -v to see
	    # names. Talk to deployer for additional rules.

	    Puts "Additional diagnostics."
	    Puts "--------------------------------------------------------------"
	    Puts "Number of package uses without PCX definitions: $cc(coreTcl::pkgUnchecked)"
	    Puts ""
	    Puts "  Note: Use option -v or -check pkgUnchecked to see package names."
	    Puts "        This issue cannot be fixed in the Tcl code which was checked."
	    Puts "        Talk to the administrator for your Tcl Dev Kit installation"
	    Puts "        about installing additional PCX files."
	    Puts ""
	}
    }
    return
}

# ::message::setDisplayProc --
#
#	Set the display proc to use when printing out messages.
#
# Arguments:
#	procName	The name of a fully qualified proc name.
#			The proc must take three args: mid, errRange
#			and clientData.  See the header for 
#			message::show for details on these args.
#
# Results:
#	None.

proc ::message::setDisplayProc {procName} {
    set analyzer::displayProc $procName
    return
}

# ::message::getMessage --
#
#	Convert the messageID into a human-readable message.
#
# Arguments:
#	mid	The messageID.  If the mid is not qualified,
#		it is defined in the analyzer's generic message
#		list.  Otherwise, it is defined in the namespace
#		of the qualified mid.
#
# Results:
#	The human readable message.

proc ::message::getMessage {mid} {
    variable messages

    set ns   [namespace qualifiers $mid]
    set tail [namespace tail $mid]
    set result {}
    if {$ns == {}} {
	if {[info exists messages($tail)]} {
	    set result [lindex $messages($tail) 0]
	} else {
	    set result $tail
	}
    } else {
	upvar ${ns}::messages nm

	if {[info exists nm($mid)]} {
	    set result [lindex $nm($mid) 0]
	} else {
	    set result $mid
	}
    }
    return $result
}

# ::message::getTypes --
#
#	Convert the messageID into a list of message types that 
#	apply to this message.
#
# Arguments:
#	mid	The messageID.  If the mid is not qualified,
#		it is defined in the analyzer's generic message
#		list.  Otherwise, it is defined in the namespace
#		of the qualified mid.
#
# Results:
#	A list of message type keywords.  If none are defined, the message is of type "err".

proc ::message::getTypes {mid} {
    variable messages

    set ns   [namespace qualifiers $mid]
    set tail [namespace tail $mid]
    set result {}
    if {$ns == {}} {
	if {[info exists messages($tail)]} {
	    set result [lrange $messages($tail) 1 end]
	} else {
	    set result err
	}
    } else {
	upvar ${ns}::messages nm

	if {[info exists nm($mid)]} {
	    set result [lrange $nm($mid) 1 end]
	} else {
	    set result err
	}
    }
    return $result
}

# ::message::displayTTY --
#
#	Display the output to a standard tty display.
#
# Arguments:
#	mid		The message id for the message.
#	errRange	The range of the error relative to the start
#			of the current analyzer script.
#	clientData	Extra data used when generation the message.
#
# Results:
#	None.

proc ::message::displayTTY {mid errRange line cmdRange clientData quiet extend} {
    set pwd      [pwd]
    set file     [analyzer::getFile]
    set script   [analyzer::getScript]

    # Pwd was automatically appended to relative paths to avoid conflicts
    # with wrapped files.  However this makes the strings very verbose.
    # If the file's path begins with [pwd] then strip off that string.

    if {[string match $pwd/* $file]} {
	# The length of PWD plus one for the file separator.

	set len [expr {[string length $pwd] + 1}]
	set file [string range $file $len end]
    }

    # NOTE: The 'extend' dictionary is ignored for human readable output.
    #       Its information will be shown only in -as-dict/script mode,
    #       see displayDict and displayScript below.

    array set dict [GetDict $mid $errRange $line $cmdRange $clientData $extend]

    # Let special error ranges override the file information, and
    # quiescense the extended command info
    if {$dict(file) eq "BEFORE_FILES"} {
	set file $dict(file)
	set quiet 1
    }

    set logMsg "$file:$dict(line) ([namespace tail $mid]) $dict(messageText)"
    if {[catch {
	Puts $logMsg
	if {!$quiet} {
	    Puts $dict(badCommandLine) ;# cmdStr
	    Puts $dict(badCommandMark) ;# carrot
	}
    }]} {
	puts "INTERNAL ERROR: [join [split $::errorInfo \n] "\nINTERNAL ERROR: "]"
	exit
    }
}

# ::message::collectMsg --
#
#	This is the routine that collects the results from
#       the checker runs. The final results are stored in 
#       the variable ::message::collectedResults, which has
#       to be cleared and retrieved by the calling 
#       application.
#
# Arguments:
#	mid		The message id for the message.
#	errRange	The range of the error relative to the start
#			of the current analyzer script.
#	clientData	Extra data used when generation the message.
#
# Results:
#       none

proc ::message::collectMsg {mid errRange line cmdRange clientData quiet} {
    if {$errRange == {}} {
        set errRange $cmdRange
    }

    set msg    [format [message::getMessage $mid] {*}$clientData]
    set logMsg "([namespace tail $mid]) $msg"

    lappend ::message::collectedResults [list $mid $logMsg $errRange]
    return $::message::collectedResults
}

proc ::message::CmdStrByRange {script cmdRange} {
    set cmdStr [parse getstring $script $cmdRange]
    set index  [string first \n $cmdStr]
    # <= to handle not only 0, but -1 (== no \n found), see Bug 87845.
    if {$index <= 0} { return $cmdStr }
    incr index -1
    return [string range $cmdStr 0 $index]
}

proc ::message::ScanForError {script cmdRange errRange lv} {
    upvar 1 $lv line

    set cmdStr   [parse getstring $script $cmdRange]
    set cmdIndex [parse charindex $script $cmdRange]
    set tokIndex [parse charindex $script $errRange]

    # Scan through the command string looking for the exact line the
    # error occured on.  When the loop is done, prevIndex and
    # nextIndex point to the start and end of the error line.

    set errIndex  [expr {$tokIndex - $cmdIndex}]
    set prevIndex -1
    set nextIndex 0
    set subStr    $cmdStr

    while {1} {
	set prevIndex $nextIndex
	set charIndex [string first \n $subStr]

	if {$charIndex >= 0} {
	    incr nextIndex [expr {$charIndex + 1}]
	    set subStr [string range $cmdStr $nextIndex end]
	} else {
	    set nextIndex [expr {[string length $cmdStr] + 2}]
	    break
	}

	if {$nextIndex >= $errIndex} {
	    break
	}
	incr line
    }

    return [list $cmdStr $prevIndex $nextIndex $errIndex]
}

proc ::message::displayNull {mid errRange line cmdRange clientData quiet extend} {
    # Suppress any and all regular output. For summary-only mode.
    return
}

proc ::message::displayDict {mid errRange line cmdRange clientData quiet extend} {
    PutsAlways [GetDict $mid $errRange $line $cmdRange $clientData $extend]
    return
}

proc ::message::displayScript {mid errRange line cmdRange clientData quiet extend} {
    array set dict [GetDict $mid $errRange $line $cmdRange $clientData $extend]

    # ########################################################

    PutsAlways "message \{"
    set maxl 0
    foreach name [array names dict] {
        if {[string length $name] > $maxl} {
            set maxl [string length $name]
        }
    }
    incr maxl 2
    foreach k [lsort -dict [array names dict]] {
	if {$k eq "suggestedCorrections"} {
	    # Explicit multi-line formatting of the output
	    PutsAlways "    [format %-*s $maxl $k] \{"
	    foreach v $dict($k) {
		PutsAlways "        [list $v]"
	    }
	    PutsAlways "    \}"
	} else {
	    PutsAlways "    [format %-*s $maxl $k] [list $dict($k)]"
	}
    }
    PutsAlways "\}"
    #PutsAlways $dict
    return
}

proc ::message::GetDict {mid errRange line cmdRange clientData extend} {
    set script  [analyzer::getScript]
    set thefile [file nativename [file normalize [analyzer::getFile]]]

    if {$errRange eq "@"} {
	set cmdRange {0 0}
	set errRange {0 0}
	set line 0
	set thefile BEFORE_FILES
	set cmdStr ""
	set carrot ""

    } elseif {$errRange == {}} {
        set errRange $cmdRange

	set cmdStr [CmdStrByRange $script $cmdRange]
	set carrot "^"
    } else {
	#ScanForError $script $cmdRange $errRange line
	# Returned results are irrelevant, we just want the exact line.

	lassign [ScanForError $script $cmdRange $errRange line] \
	    cmdStr prevIndex nextIndex errIndex

	# Scan the error line adding spaces and tabs to the carrot
	# string foreach letter or tab in the error string.
	# When this is complete, the "carrot" string will be
	# a string with a "^" just under the word that caused
	# the error.

	set errStr   [string range $cmdStr $prevIndex $errIndex]
	set cmdStr   [string range $cmdStr $prevIndex [expr {$nextIndex - 2}]]
	set numTabs  [regsub -all \t $errStr \t errStr]
	set numChar  [expr {$errIndex - $prevIndex - $numTabs}]
	for {set i 0} {$i < $numTabs} {incr i} {
	    append carrot "\t"
	}
	for {set i 0} {$i < $numChar} {incr i} {
	    append carrot " "
	}
	append carrot "^"
    }

    set midmsg     [message::getMessage $mid]
    set clientData [struct::list map $clientData [list string map [list \n { }]]]

    set dict {}
    lappend dict file            $thefile
    lappend dict line            $line
    lappend dict messageID       $mid
    lappend dict messageTemplate $midmsg
    lappend dict messageText     [format $midmsg {*}$clientData]
    lappend dict clientData      $clientData

    lappend dict badCommandLine $cmdStr
    lappend dict badCommandMark $carrot

    # Bug 81756. Shrink the shown command range to exclude the command
    # terminator character, should it be present (either semicolon or
    # end-of-line).
    set c [analyzer::getChar $script [analyzer::endofrange $cmdRange]]
    if {($c eq "\n") || ($c eq ";")} {
	lassign $cmdRange s l
	incr l -1
	set cmdRange [list $s $l]
    }

    lassign $cmdRange s l
    lappend dict commandRange  $cmdRange
    lappend dict commandStart  $s
    lappend dict commandLength $l

    lappend dict commandStart,portable [lineOff $s]
    lappend dict commandEnd,portable   [lineOff [expr {$s+$l-1}]]

    lassign $errRange s l
    lappend dict errorRange  $errRange
    lappend dict errorStart  $s
    lappend dict errorLength $l

    lappend dict errorStart,portable [lineOff $s]
    lappend dict errorEnd,portable   [lineOff [expr {$s+$l-1}]]

    # Add the extended information. Like fixes, well suggestions for
    # corrections.
    lappend dict {*}$extend

    return $dict
}

# Puts --
#
#	Wrapper function for "puts" that allows us to easily redirect
#	output and catches write errors so we can exit cleanly.
#
# Arguments:
#	args	Passes arguments directoy to "puts".
#
# Results:
#	None.

proc Puts {args} {
    # No standard output at all when in cross-reference or package
    # listing mode.

    if {$::configure::machine}  {return}
    if {$::configure::xref}     {return}
    if {$::configure::packages} {return}

    ::PutsAlways {*}$args
    return
}

proc PutsAlways {args} {
    variable message::outChannel
    if {[lindex $args 0] == "-nonewline"} {
	set args [linsert $args 1 $outChannel]
    } else {
	set args [linsert $args 0 $outChannel]
    }
    if {[catch {
	puts {*}$args
    } msg]} {
	exit 1
    }
    return
}

# ### ######### ###########################
## Ready to use

package provide message 1.0
