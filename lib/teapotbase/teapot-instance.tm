# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::instance 0.1
# Meta category    teapot
# Meta description Teapot support functionality. Entity instances. Data
# Meta description structures for various concepts, like references, entity
# Meta description instances and the like.
# Meta platform    tcl
# Meta require     logger
# Meta require     teapot::entity
# Meta require     teapot::version
# Meta subject     teapot {entity instance information}
# Meta subject     {transfer data structures}
# Meta summary     Entity instances. Data structures.
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Operations on and for entity instances

# ### ### ### ######### ######### #########
## Requirements

package require teapot::version
package require teapot::entity
package require logger

logger::initNamespace ::teapot::instance
namespace eval        ::teapot::instance {}

# ### ### ### ######### ######### #########
## Implementation

proc ::teapot::instance::valid {instance {mv {}}} {
    # Was pkg::mem::bogus, extended

    if {$mv ne ""} {upvar 1 $mv message}

    if {[catch {set len [llength $instance]} msg]} {
	set message $msg
	return 0
    }

    if {$len != 4} {
	set message "wrong\#elements, expected 'entity name version architecture'"
	return 0
    }

    foreach {e n v a} $instance break

    foreach {var label} {
	n name
	v version
	a architecture
    } {
	if {[set var] eq ""} {
	    set message "Empty $label"
	    return 0
	}
    }

    if {![teapot::entity::valid $e message]} {
	return 0
    }

    if {![teapot::version::valid $v message]} {
	return 0
    }

    return 1
}

proc ::teapot::instance::cons {e n v a} {
    # See also "::teapot::reference::pseudoinstance"
    # That command creates invalid package instances
    # from references. We forbid such.

    set instance [list [string tolower $e] $n $v $a]
    if {![valid $instance message]} {
	return -code error $message
    }
    return $instance
}

proc ::teapot::instance::split {instance ev nv vv av} {
    upvar 1 $ev e $vv v $nv n $av a
    foreach {e n v a} $instance break
    return
}

proc ::teapot::instance::norm {instancevar} {
    upvar 1 $instancevar instance
    set instance [lrange $instance 0 3]
    return
}

proc ::teapot::instance::2spec {instance} {
    return [linsert $instance 0 1]
}

proc ::teapot::instance::2redirect {instance} {
    # instance to instance, anything to a redirection for it.
    return [lreplace $instance 0 0 redirect]
}

# ### ### ### ######### ######### #########
## Ready
return
