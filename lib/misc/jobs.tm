# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package jobs 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Managing a list of jobs which had to be defered for some reason or
# other.

# ### ### ### ######### ######### #########
## Requirements

package require snit                 ; # OO core
package require logger

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::jobs
snit::type ::jobs {
    method defer-us {} {
	# Capture the exact command asking for deferal, and
	# force it to return as well.
	set task [info level -1]
	log::debug "job/defer ($task)"
	lappend jobs $task
	return -code return
    }

    method do {} {
	# Execute the defered jobs. In such a way that they can defer
	# themselves again without trouble.

	set defered $jobs
	set jobs    {}
	foreach job $defered {
	    log::debug "job/do ($job)"
	    uplevel \#0 $job
	}
	return
    }

    method clear {} {
	set jobs {}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable jobs {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
