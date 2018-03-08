# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::cache 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     repository::api
# Meta require     repository::localma
# Meta require     repository::prefix
# Meta require     repository::proxy
# Meta require     repository::sqlitedir
# Meta require     repository::tap
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Cache of repository objects for a set of locations. Avoids us
## having to re-construct them every time the location is chosen.

# ### ### ### ######### ######### #########
## Requirements

package require logger              ; # Tracing
package require repository::api      ; # Repo interface core

# Repository types for the type auto-detection.

package require repository::tap       ; # TAP compatibility repository
package require repository::sqlitedir ; # Standard opaque repository (server)
package require repository::localma   ; # Standard open repository (installation)
package require repository::prefix    ; # Prefix files
package require repository::proxy     ; # Http accessible repositories (network)

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::cache
snit::type            ::repository::cache {

    # ### ### ### ######### ######### #########
    ## API. Typed and auto-typed creation/retrieval.

    typemethod get {rtype location args} {
	set key $location,$args
	if {![info exists _db($key)]} {
	    set _db($key) [eval [linsert [linsert \
			   $args end -location $location] 0 \
		  $rtype %AUTO%]]
	}
	return $_db($key)
    }

    typemethod open {location args} {
	set key $location,$args
	if {![info exists _db($key)]} {
	    set _db($key) [eval [linsert $args 0 \
			     repository::api open %AUTO% $location]]
	}
	return $_db($key)
    }

    typemethod has {location args} {
	info exists _db($location,$args)
    }

    # ### ### ### ######### ######### #########
    ## Data structures. Cache array.

    typevariable _db -array {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
