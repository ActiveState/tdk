# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::entity 0.1
# Meta category    teapot
# Meta description Teapot support functionality. Validation, enumeration of
# Meta description entity types. Data structures for various concepts, like
# Meta description references, entity instances and the like.
# Meta platform    tcl
# Meta require     logger
# Meta subject     teapot {entity type} {entity name}
# Meta subject     {transfer data structures}
# Meta summary     Teapot support functionality. Validating entity types
# Meta summary     Data structures.
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Operations on and for entity types.

# ### ### ### ######### ######### #########
## Requirements

package require logger

logger::initNamespace ::teapot::entity
namespace eval        ::teapot::entity {}

# ### ### ### ######### ######### #########
## Implementation

proc ::teapot::entity::check {v} {
    if {![valid $v message]} {return -code error $message}
}

proc ::teapot::entity::valid {e {mv {}}} {
    variable name
    if {$mv ne ""} {upvar 1 $mv message}

    set ex [string tolower $e]
    set ok [info exists name($ex)]

    if {!$ok} {
	set message "Unknown entity type \"$e\", expected [linsert [join [names] ", "] end-1 "or"]"
    }

    return $ok
}

proc ::teapot::entity::norm {e} {
    return [string tolower $e]
}

proc ::teapot::entity::display {e} {
    variable canon
    return  $canon([string tolower $e])
}

proc ::teapot::entity::rank {e} {
    variable name
    return  $name([string tolower $e])
}

proc ::teapot::entity::primary {e} {
    return [expr {[rank $e] == 1}]
}

proc ::teapot::entity::secondary {e} {
    return [expr {[rank $e] == 2}]
}

proc ::teapot::entity::names {} {
    variable names
    return  $names
}

# ### ### ### ######### ######### #########
## Data structures and constants

namespace eval ::teapot::entity {
    variable  name
    array set name {
	package       1
	application   1
	documentation 2
	profile       1
	redirect      1
    }
    variable  canon
    array set canon {
	package       Package
	application   Application
	documentation Documentation
	profile       Profile
	redirect      Redirect
    }
    variable names [lsort -dict [array names name]]
}

# ### ### ### ######### ######### #########
## Ready
return
