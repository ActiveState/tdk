# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# break.tcl --
#
#	This file implements the breakpoint object API as SNIT class.
#	Origin is 'break.tcl', a singleton object in a namespace.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2001-2006 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: break.tcl,v 1.3 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type breakdb {

    # ### ### ### ######### ######### #########
    ## Instance data

    # debugging options --
    #
    # Fields:
    #   debug		Set to 1 to enable debugging output.
    #	logFile		File handle where logging messages should be written.

    variable debug   0
    variable logFile stderr

    # breakpoint data type --
    #
    #   A breakpoint object encapsulates the state associated with a
    #	breakpoint.  Each breakpoint is represented by a Tcl array
    #   whose name is of the form break<type><num> where <type> is
    #	L for line-based breakpoints and V for variable breakpoints.
    #	Each array contains the following elements:
    #		state		Either enabled or disabled.
    #		test		The script in conditional breakpoints.
    #		location	The location or trace handle for the
    #				breakpoint.
    #		data		This field holds arbitrary data associated
    #				with the breakpoint for use by the GUI.
    #
    # Fields:
    #	counter		This counter is used to generate breakpoint names.

    variable counter 0

    # ### ### ### ######### ######### #########

    variable blkmgr
    method blk: {blkmgr_} {
	set blkmgr $blkmgr_
	return
    }

    # ### ### ### ######### ######### #########
    ## Public methods ...

    # method MakeBreakpoint --
    #
    #	Create a new breakpoint.
    #
    # Arguments:
    #	type		One of "line" or "var"
    #	where		Location for line breakpoints; trace handle for
    #			variable breakpoints.
    #	test		Optional.  Script to use for conditional breakpoint.
    #
    # Results:
    #	Returns a breakpoint identifier.

    method MakeBreakpoint {bpType location {test {}}} {
	$self Log {MakeBreakpoint (($bpType) ($location) ($test))}
	
	if {$bpType eq "line"} {
	    set bpType L
	} elseif {$bpType eq "spawn"} {
	    set bpType S
	} elseif {$bpType eq "skip"} {
	    set bpType C ; # for /C/ontinue
	} else {
	    set bpType V
	}

	# find an unallocated breakpointer number and create the array

	incr counter
	while {[info exists ${selfns}::break$bpType$counter]} {
	    incr counter
	}
	set name $bpType$counter
	array set ${selfns}::break$name [list \
		data {} location $location \
		state enabled test $test \
		]

	$self Log {	$name}
	return $name
    }

    # method Release --
    #
    #	Release the storage associated with one or more breakpoints.
    #
    # Arguments:
    #	breakList	The breakpoints to release, or "all".
    #
    # Results:
    #	None.

    method Release {breakList} {
	$self Log {Release ($breakList)}

	if {$breakList eq "all"} {
	    # Release all breakpoints
	    set all [info vars ${selfns}::break*]
	    if {$all != ""} {
		eval unset $all
	    }
	} else {
	    foreach breakpoint $breakList {
		if {[info exist ${selfns}::break$breakpoint]} {
		    unset ${selfns}::break$breakpoint
		}
	    }
	}
	return
    }

    # method setTest --
    #
    #	Change the breakpoint test.
    #
    # Arguments:
    #	breakpoint	The breakpoint identifier.
    #
    # Results:
    #	None.

    method setTest {breakpoint test} {
	set ${selfns}::break${breakpoint}(test) $test
	$self Log {setTest ($breakpoint) = $test}
	return
    }

    # method getState --
    #
    #	Return the breakpoint state.
    #
    # Arguments:
    #	breakpoint	The breakpoint identifier.
    #
    # Results:
    #	Returns one of enabled or disabled.

    method getState {breakpoint} {
	set state [set ${selfns}::break${breakpoint}(state)]
	$self Log {getState ($breakpoint) = $state}
	return $state
    }

    # method getLocation --
    #
    #	Return the breakpoint location.
    #
    # Arguments:
    #	breakpoint	The breakpoint identifier.
    #
    # Results:
    #	Returns the breakpoint location.

    method getLocation {breakpoint} {
	set loc [set ${selfns}::break${breakpoint}(location)]
	$self Log {getLocation ($breakpoint) = $loc}
	return $loc
    }


    # method getTest --
    #
    #	Return the breakpoint test.
    #
    # Arguments:
    #	breakpoint	The breakpoint identifier.
    #
    # Results:
    #	Returns the breakpoint test.

    method getTest {breakpoint} {
	set test [set ${selfns}::break${breakpoint}(test)]
	$self Log {getTest ($breakpoint) = $test}
	return $test
    }

    # method getType --
    #
    #	Return the type of the breakpoint.
    #
    # Arguments:
    #	breakpoint	The breakpoint identifier.
    #
    # Results:
    #	Returns the breakpoint type; one of "line" or "var".

    method getType {breakpoint} {
	switch [string index $breakpoint 0] {
	    V {
		$self Log {getType ($breakpoint) = var}
		return "var"
	    }
	    L {
		$self Log {getType ($breakpoint) = line}
		return "line"
	    }
	    S {
		$self Log {getType ($breakpoint) = spawn}
		return "spawn"
	    }
	    C {
		$self Log {getType ($breakpoint) = skip}
		return "skip"
	    }
	}
	error "Invalid breakpoint type"
    }


    # method SetState --
    #
    #	Change the breakpoint state.
    #
    # Arguments:
    #	breakpoint	The breakpoint identifier.
    #	state		One of enabled or disabled.
    #
    # Results:
    #	None.

    method SetState {breakpoint state} {
	$self Log {SetState ($breakpoint) := $state}
	set ${selfns}::break${breakpoint}(state) $state
	return
    }

    # method getData --
    #
    #	Retrieve the client data field.
    #
    # Arguments:
    #	breakpoint	The breakpoint identifier.
    #
    # Results:
    #	Returns the data field.

    method getData {breakpoint} {
	set data [set ${selfns}::break${breakpoint}(data)]
	$self Log {getTest ($breakpoint) = $data}
	return $data
    }

    # method setData --
    #
    #	Set the client data field.
    #
    # Arguments:
    #	breakpoint	The breakpoint identifier.
    #
    # Results:
    #	None.

    method setData {breakpoint data} {
	$self Log {Setdata ($breakpoint) := $data}
	set ${selfns}::break${breakpoint}(data) $data
	return
    }

    # method GetLineBreakpoints --
    #
    #	Returns a list of all line-based breakpoint identifiers.  If the
    #	optional location is specified, only breakpoints set at that
    #	location are returned.
    #
    # Arguments:
    #	location	Optional. The location of the breakpoint to get.
    #
    # Results:
    #	Returns a list of all line-based breakpoint identifiers.

    method GetLineBreakpoints {{location {}}} {
	$self Log {GetLineBreakpoints ($location)}

	set result {}
	foreach breakpoint [info vars ${selfns}::breakL*] {
	    if {
		($location == "") ||
		[loc::match $location [set ${breakpoint}(location)]]
	    } {
		lappend result $breakpoint
	    }
	}

	regsub -all "${selfns}::break" $result {} result

	$self Log {	$result}
	return $result
    }

    # method GetVarBreakpoints --
    #
    #	Returns a list of all variable-based breakpoint identifiers
    #	for a specified variable trace.
    #
    # Arguments:
    #	handle		The trace handle.
    #
    # Results:
    #	A list of breakpoint identifiers.

    method GetVarBreakpoints {{handle {}}} {
	$self Log {GetVarBreakpoints ($handle)}

	set result {}
	foreach breakpoint [info vars ${selfns}::breakV*] {
	    if {
		($handle == "") ||
		([set ${breakpoint}(location)] == $handle)
	    } {
		lappend result $breakpoint
	    }
	}
	regsub -all "${selfns}::break" $result {} result

	$self Log {	$result}
	return $result
    }

    # method GetSpawnpoints --
    #
    #	Returns a list of all line-based spawnpoint identifiers.  If the
    #	optional location is specified, only spawnpoints set at that
    #	location are returned.
    #
    # Arguments:
    #	location	Optional. The location of the breakpoint to get.
    #
    # Results:
    #	Returns a list of all line-based spawnpoint identifiers.

    method GetSpawnpoints {{location {}}} {
	$self Log {GetSpawnpoints ($location)}

	set result {}
	foreach spawnpoint [info vars ${selfns}::breakS*] {
	    if {
		($location == "") ||
		[loc::match $location [set ${spawnpoint}(location)]]
	    } {
		lappend result $spawnpoint
	    }
	}

	regsub -all "${selfns}::break" $result {} result

	$self Log {	$result}
	return $result
    }

    # method GetSkipmarkers --
    #
    #	Returns a list of all line-based skipmarker identifiers.  If the
    #	optional location is specified, only skipmarkers set at that
    #	location are returned.
    #
    # Arguments:
    #	location	Optional. The location of the breakpoint to get.
    #
    # Results:
    #	Returns a list of all line-based skip marker identifiers.

    method GetSkipmarkers {{location {}}} {
	$self Log {GetSkipmarkers ($location)}

	set result {}
	foreach skipmarker [info vars ${selfns}::breakC*] {
	    if {
		($location == "") ||
		[loc::match $location [set ${skipmarker}(location)]]
	    } {
		lappend result $skipmarker
	    }
	}

	regsub -all "${selfns}::break" $result {} result

	$self Log {	$result}
	return $result
    }

    # method preserveBreakpoints --
    #
    #	Generate a persistent representation for all line-based
    #	breakpoints so they can be stored in the user preferences.
    #
    # Arguments:
    #	varName		Name of variable where breakpoint info should
    #			be stored.
    #
    # Results:
    #	None.

    method preserveBreakpoints {varName} {
	$self Log {preserveBreakpoints ($varName)}

	upvar $varName data
	set data {}
	foreach bp [$self GetLineBreakpoints] {
	    set location [$self getLocation $bp]
	    set file [$blkmgr getFile [loc::getBlock $location]]
	    set line                  [loc::getLine  $location]
	    if {$file != ""} {
		lappend data [list $file $line \
			[$self getState $bp] \
			[$self getTest $bp]]
	    }
	}		
	return
    }

    # method restoreBreakpoints --
    #
    #	Recreate a set of breakpoints from a previously preserved list.
    #
    # Arguments:
    #	data		The data generated by a previous call to
    #			preserveBreakpoints.
    #
    # Results:
    #	None.

    method restoreBreakpoints {data} {
	$self Log {restoreBreakpoints ($data)}

	foreach bp $data {
	    set block    [$blkmgr makeBlock [lindex $bp 0]]
	    set location [loc::makeLocation $block [lindex $bp 1]]
	    $self SetState [$self MakeBreakpoint line $location [lindex $bp 3]] \
		    [lindex $bp 2]
	}
	return
    }

    # method preserveSpawnpoints --
    #
    #	Generate a persistent representation for all spawnpoints
    #	so they can be stored in the user preferences.
    #
    # Arguments:
    #	varName		Name of variable where spawnpoint info should
    #			be stored.
    #
    # Results:
    #	None.

    method preserveSpawnpoints {varName} {
	$self Log {preserveSpawnpoints ($varName)}

	upvar $varName data
	set data {}
	foreach sp [$self GetSpawnpoints] {
	    set location [$self getLocation $sp]
	    set file [$blkmgr getFile [loc::getBlock $location]]
	    set line                  [loc::getLine  $location]
	    if {$file != ""} {
		lappend data [list $file $line \
			[$self getState $sp] \
			[$self getTest $sp]]
	    }
	}		
	return
    }

    # method restoreSpawnpoints --
    #
    #	Recreate a set of spawnpoints from a previously preserved list.
    #
    # Arguments:
    #	data		The data generated by a previous call to
    #			preserveSpawnpoints.
    #
    # Results:
    #	None.

    method restoreSpawnpoints {data} {
	$self Log {restoreSpawnpoints ($data)}

	foreach sp $data {
	    set block    [$blkmgr makeBlock [lindex $sp 0]]
	    set location [loc::makeLocation $block [lindex $sp 1]]
	    $self SetState [$self MakeBreakpoint spawn $location [lindex $sp 3]] \
		    [lindex $sp 2]
	}
	return
    }

    # method Log --
    #
    #	Log a debugging message.
    #
    # Arguments:
    #	message		Message string.  This string is substituted in
    #			the calling context.
    #
    # Results:
    #	None.

    method Log {message} {
	if {!$debug} return

	puts $logFile "LOG(break,[clock clicks]): [uplevel 1 [list subst $message]]"
	return
    }
}

# ### ### ### ######### ######### #########
## Ready to go

package provide breakdb 1.0
