# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package action 1.0
# Meta platform    tcl
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ######### ###########################

# Tools. Action management

# ### ######### ###########################
## Prerequisites

package require snit ; # Object system

# ### ######### ###########################
## Implementation

snit::type action {

    # ### ######### ###########################
    ## Public API. Construction

    constructor {} {
	array set def   {}
	array set watch {}
	array set state {}
	return
    }

    method define {action cmd} {
	if {[info exists def($action)]} {
	    return -code error "$self define \"$action\": Action is already defined."
	}
	set def($action)   $cmd
	set watch($action) {}
	set state($action) disabled
	return
    }

    method invoke {action} {
	if {![info exists def($action)]} {
	    return -code error "$self invoke \"$action\": Action is unknown."
	}
	uplevel #0 [linsert $def($action) end $action]
	return
    }

    method register {action cmd} {
	if {![info exists def($action)]} {
	    return -code error "$self register \"$action\": Action is unknown."
	}
	set pos [lsearch -exact $watch($action) $cmd]
	if {$pos >= 0} return
	lappend watch($action) $cmd
	uplevel #0 [linsert $cmd end $action $state($action)]
	return
    }

    method unregister {action cmd} {
	if {![info exists def($action)]} {
	    return -code error "$self unregister \"$action\": Action is unknown."
	}
	set pos [lsearch -exact $watch($action) $cmd]
	if {$pos < 0} return
	set watch($action) [lreplace $watch($action) $pos $pos]
	return
    }

    method enable {action} {
	if {![info exists def($action)]} {
	    return -code error "$self enable \"$action\": Action is unknown."
	}
	set state($action) normal
	foreach cmd $watch($action) {
	    uplevel #0 [linsert $cmd end $action normal]
	}
	return
    }

    method disable {action} {
	if {![info exists def($action)]} {
	    return -code error "$self disable \"$action\": Action is unknown."
	}
	set state($action) disabled
	foreach cmd $watch($action) {
	    uplevel #0 [linsert $cmd end $action disabled]
	}
	return
    }

    # ### ######### ###########################
    ## Internal. Data structures. Actions have two types of commands
    ## associated with them: A single invocation command, and many
    ## notification callbacks for state changes.

    variable def   ; # Array keyed by action name, maps to the
    # ............ ; # invocation command.
    variable watch ; # Array keyed by action name, maps to list of
    # ............ ; # notification commands.
    variable state ; # Array keyed by action name, maps to state of
    # ............ ; # the action.

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use
return
