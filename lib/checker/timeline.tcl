# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# timeline.tcl --
#
#	This file implements the analyzer's timeline facilities for
#	checking of command ordering.
#
# Copyright (c) 2008 ActiveState Software Inc.
#


# 
# SCCS: @(#) timeline.tcl 1.5 98/07/24 13:56:33

package require Tcl 8.5
package require struct::stack
package require struct::graph

namespace eval timeline {}

# ### ######### ###########################
## Essence of this module.

# The scoping requirements (only toplevel commands and proc bodies)
# are solved here using a stack of timelines, with each timeline
# handling one scope.
#
# For each separate order definition the timeline holds one graph
# where nodes represent commands, and arcs represent the control flow
# between them. One special node is the initial node of a
# timeline. Some nodes are epsilon nodes to make handling of complex
# control flow easier, giving us a proper anchor for our arcs, always.
# The graph trivially models complex control flow like branches and
# loops.
#
# For validation, done when a scope is closed, i.e. at its end, all
# epsilons are removed, with the exception of the initial node. The
# arcs going through the epsilons are properly replicated to keep
# modeling the actual control flow. After that step each arc
# represents a pair of commands (A, B), with B possibly executing
# after A. Using the order definition we have we can weed out all
# acceptable pairs, leaving those which represent bad control
# flow. For these we generate messages. To make these messages nice we
# store command range and line information in the nodes of the graph.

# ### ######### ###########################
## API. timeline definitions

proc timeline::def {name def} {
    variable orders
    if {[info exists orders($name)]} {
	return -code error "Internal error, illegal redefinition of ordering specification \"$name\""
    }

    # def = list (actions pairs pre)
    # actions = list (string)
    # pairs = list (pair), pair = list (string/before string/after)
    # pre = dict (string/after -> list (string/before))

    if 0 {
	    lassign $def actions pairs pre
	    puts TL/DEF\t'$name'
	    puts \t([join $actions {) (}])
	    foreach p $pairs {
		lassign $p f l
		puts "\tP\t($f) --> ($l)"
	    }
	    # pre not dumped.
    }

    set orders($name) $def ;# list(actions, pairs, pre)
    return
}

# ### ######### ###########################
## API. timeline management

proc timeline::open {} {
    variable timelines
    variable current
    variable orders
    #puts TL/Open______________________________\n\t[info level -1]

    $timelines push [array get current]
    array unset current *

    foreach name [array names orders] {
	set current($name) [Open $name {*}$orders($name)]
    }
    return
}

proc timeline::close {} {
    variable timelines
    variable current
    #puts TL/Close______________________________\n\t[info level -1]

    foreach spec [array names current] {
	Close $spec
    }

    array unset current *
    array set   current [$timelines pop]

    #puts TL/Close/complete_______________________
    return
}

# ### ######### ###########################
## API. actions

proc timeline::epsilon {} {
    variable current
    foreach spec [array names current] {
	extend $spec {} {} {}
    }
    return
}

proc timeline::extend {spec name range line} {
    variable current
    #puts "\t+++ $spec/$name/@/$range/$line"
    #puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #parray current
    #puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if {![info exists current($spec)]} {
	return -code error "Internal error in ordering module: Specification \"$spec\" is not known. Please check your PXC file"
    }

    set g $current($spec)
    array set config [$g getall]

    #puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #parray config
    #puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if {($name ne "") && ($name ni $config(actions))} {
	return -code error "Internal error in ordering module: Specification \"$config(spec)\" does not support action \"$name\". Please check your PCX file"
    }

    set n [$g node insert]
    $g node set $n action   $name
    $g node set $n cmdrange $range
    $g node set $n cmdline  $line

    foreach p $config(wave) {
	$g arc insert $p $n
    }

    $g set wave [list $n]
    return
}

# ### ######### ###########################
## API. complex ordering, branches.

proc timeline::branchesfork {} {
    #puts stderr TB-fork
    variable current
    variable mc
    incr     mc

    foreach spec [array names current] {
	set g $current($spec)
	#puts stderr \t(B$mc)=[$g get wave],push-on-marks
	$g set B$mc [$g get wave]
	$g set R$mc {}
	$g lappend Marks $mc
    }
    return M$mc
}

proc timeline::branchopen {} {
    #puts stderr TB-open
    variable current
    foreach spec [array names current] {
	set g $current($spec)
	set mc [lindex [$g get Marks] end]
	#puts stderr \t@mark=B$mc,\tusing-wave:[$g get B$mc]
	$g set wave [$g get B$mc]
    }
    return
}

proc timeline::branchclose {} {
    #puts stderr TB-close
    variable current
    foreach spec [array names current] {
	set g $current($spec)
	set mc [lindex [$g get Marks] end]
	#puts stderr \t@mark=R$mc,\tsaving-wave:[$g get wave]

	# struct::graph lappend does not allow multiple nodes in a
	# single call!  multiple calls of lappend required. optimize,
	# new: reduce to set of unique nodes in the wave-front.
	foreach n [lsort -unique [$g get wave]] {
	    $g lappend R$mc $n
	}
	#$g lappend R$mc {*}[$g get wave]
    }
    return
}

proc timeline::branchesjoin {} {
    #puts stderr TB-join
    variable current
    foreach spec [array names current] {
	set g $current($spec)

	set br [$g get Marks]
	set mc [lindex $br end]
	#puts stderr \t@mark=R$mc,\tpulling-wave:[$g get R$mc],pop
	$g set Marks [lrange $br 0 end-1]

	$g set wave [lsort -unique [$g get R$mc]]
	$g unset R$mc
	$g unset B$mc
    }
    return 0
}

# ### ######### ###########################
## API. complex ordering, loops

proc timeline::loopbegin {} {
    variable current
    variable mc
    incr     mc

    epsilon
    foreach spec [array names current] {
	set g $current($spec)

	$g set L$mc [$g get wave]
	$g lappend Marks $mc
    }
    return
}

proc timeline::loopclose {} {
    variable current
    foreach spec [array names current] {
	set g $current($spec)

	set br [$g get Marks]
	set mc [lindex $br end]
	$g set Marks [lrange $br 0 end-1]

	set start [lindex [$g get L$mc] 0]
	epsilon
	set close [$g get wave]
	epsilon

	$g arc insert $start $close ; # jump over loop
	$g arc insert $close $start ; # loop iteration

	$g unset L$mc
    }
    return
}

# ### ######### ###########################
## Internals

proc timeline::Open {name actions pairs pre} {
    variable gc
    incr gc
    set g [struct::graph G$gc]

    # Copy of the spec
    $g set spec    $name
    $g set actions $actions
    $g set pairs   $pairs
    $g set pre     $pre

    # Initial timeline node (epsilon), single node in wavefront.
    set s [$g node insert]
    $g node set $s action {}
    $g node set $s initial 1
    $g node set $s cmdrange {}
    $g node set $s cmdline 0

    $g set wave [list $s]

    return $g
}

proc timeline::Close {name} {
    variable current
    set g $current($name)

    # Validation...

    # Remove epsilon nodes, duplicate arcs as needed,
    # except for initial nodes.
    foreach n [$g nodes] {
	if {[$g node get $n action] ne ""} continue
	if {[$g node keyexists $n initial]} continue
	set i [$g nodes -in $n]
	set o [$g nodes -out $n]
	foreach in $i {
	    foreach out $o {
		$g arc insert $in $out
	    }
	}
	$g node delete $n
    }

    # Extract the pairs
    array set pairs {}
    foreach a [$g arcs] {
	set i [$g node get [$g arc source $a] action]
	set o [$g node get [$g arc target $a] action]
	set l [$g node get [$g arc source $a] cmdline]
	set r [$g node get [$g arc target $a] cmdrange]

	lappend pairs([list $i $o]) [list $r $l]
    }

    # Remove all valid pairs.
    foreach p [$g get pairs] {
	unset -nocomplain pairs($p)
    }

    # Check for leftover pairs, these have to be invalid.
    if {[array size pairs]} {
	set c [analyzer::getCmdRange]

	# Retrieve predecessor information for use in the messages.
	array set pre [$g get pre]

	foreach p [array names pairs] {
	    lassign $p before after

	    if {[llength $pre($after)] > 1} {
		set expected [linsert [join $pre($after) "', '"] end-1 or]
	    } else {
		set expected [lindex $pre($after) 0]
	    }

	    foreach item [lsort -unique $pairs($p)] {
		lassign $item arange bline
		#puts \[$arange\]
		analyzer::setCmdRange $arange

		#puts "\tERROR ($before) --> ($after)"

		if {$before eq ""} {
		    logError warnBadSequenceFirst $arange $after $expected
		} else {
		    logError warnBadSequence      $arange $after $before $bline \
			$expected
		}
	    }
	}

	analyzer::setCmdRange $c
    }

    $g destroy
    return
}

# ### ######### ###########################
## State

namespace eval timeline {
    # Stack of previous timeline scopes

    variable timelines [struct::stack Tstack]

    # Array of ordering specs to timeline DAG currently in use.
    variable  current
    array set current {}

    # Counter for graph objects used
    variable gc 0

    # Counter for marks (handling of nested loops and branching).
    variable mc 0
}

# ### ######### ###########################
## Ready

package provide timeline 1.0
