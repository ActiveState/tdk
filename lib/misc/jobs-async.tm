# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package jobs::async 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Managing a list of jobs scheduled for event-driven execution
# (serialized).

# ### ### ### ######### ######### #########
## Requirements

package require snit                 ; # OO core
package require logger

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::jobs::async
snit::type ::jobs::async {

    constructor {cmd} {
	set _cmd $cmd
	return
    }

    destructor {
	catch {after cancel $timer}
    }

    method add {task} {
	lappend new $task
	$self Start
	return
    }

    method Start {} {
	if {$timer ne ""} return
	log::debug START
	set timer [after 1 [mymethod Do]]
	return
    }

    method Flip {} {
	log::debug FLIP
	set exec $new
	set new  {}
	set at   0
	return
    }

    method Do {} {
	log::debug DO
	set timer {}

	if {$at >= [llength $exec]} {$self Flip}
	if {![llength $exec]} return

	uplevel \#0 [linsert $_cmd end [lindex $exec $at]]

	# Catch it if the executad task has killed the job object.
	if {![info exists at]} return

	incr at
	set timer [after 1 [mymethod Do]]
	return
    }

    method clear {} {
	set exec {}
	set new  {}
	catch {after cancel $timer}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable _cmd  {}
    variable exec  {}
    variable new   {}
    variable at    0
    variable timer {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
