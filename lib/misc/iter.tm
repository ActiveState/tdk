# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package iter 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Iterate over a data collection in an object, in an event-driven fashion.


# Managing a list of jobs which had to be defered for some reason or
# other.

# ### ### ### ######### ######### #########
## Requirements

package require snit                 ; # OO core
package require logger

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::iter
snit::type ::iter {

    option -init
    option -done
    option -per

    constructor {collection args} {
	set src $collection
	$self configurelist $args
	after 1 [mymethod Start]
	return
    }

    method Start {} {
	eval [linsert $options(-init) end state]
	after 1 [mymethod Next]
	return
    }

    method Next {} {
	set ok [$src next data]
	if {!$ok} {$self Done ; return}
	eval [linsert $options(-per) end state $data]
	after 1 [mymethod Next]
	return
    }

    method Done {} {
	eval [linsert $options(-done) end state]
	after 1 [list $self destroy]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures.

    variable src
    variable state -array {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
