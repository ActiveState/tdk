# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::query 0.1
# Meta category    teapot
# Meta description Teapot support functionality. Queries, searching. Data
# Meta description structures for various concepts, like references, entity
# Meta description instances and the like.
# Meta platform    tcl
# Meta require     logger
# Meta require     teapot::entity
# Meta subject     teapot {instance query information}
# Meta subject     {instance search information} {transfer data structures}
# Meta summary     Teapot support functionality. Queries, searching. Data
# Meta summary     structures.
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Operations on and for meta data queries

# ### ### ### ######### ######### #########
## Requirements

package require logger
package require teapot::entity

logger::initNamespace ::teapot::query
namespace eval        ::teapot::query {}

# ### ### ### ######### ######### #########
## Implementation

proc ::teapot::query::valid {query {mv {}}} {
    # Was "repository::api::queryok"

    if {$mv ne ""} {upvar 1 $mv message}

    if {[catch {llength $query} msg]} {
	set message $msg
	return 0
    }

    # Examine the top operator, then recurse down into its component
    # queries, until the non-composite layer is reached.

    set op [lindex $query 0]
    switch -exact -- $op {
	and - or {
	    if {[llength $query] < 3} {
		set message "Wrong\#args, expected \"$op sub1 sub2 ...\""
		return 0
	    }
	    foreach sub [lrange $query 1 end] {
		if {![valid $sub message]} {
		    return 0
		}
	    }
	    return 1
	}
	haskey {
	    set ok [expr {[llength $query] == 2}]
	    if {!$ok} {
		set message "Wrong\#args, expected \"haskey key\""
	    }
	    return $ok
	}
	nhaskey {
	    set ok [expr {[llength $query] == 2}]
	    if {!$ok} {
		set message "Wrong\#args, expected \"nhaskey key\""
	    }
	    return $ok
	}
	is {
	    set ok [expr {[llength $query] == 2}]
	    if {!$ok} {
		set message "Wrong\#args, expected \"is entity-type\""
	    }
	    if {![teapot::entity::valid [lindex $query 1] message]} {
		return 0
	    }
	    return 1
	}
	nis {
	    set ok [expr {[llength $query] == 2}]
	    if {!$ok} {
		set message "Wrong\#args, expected \"nis entity-type\""
	    }
	    if {![teapot::entity::valid [lindex $query 1] message]} {
		return 0
	    }
	    return 1
	}
	key {
	    if {[llength $query] != 4} {
		set message "Wrong\#args, expected \"key thekey relation value\""
		return 0
	    }
	    foreach {__ key xop val} $query break
	    if {[lsearch -exact {eq rex glob ne !rex !glob < > <= >= in ni} $xop] < 0} {
		set message "Unknown relation \"$xop\""
		return 0
	    }
	    if {[string match *rex $xop] && [catch {regexp -about $val}]} {
		set message "Bad regular expression \"$val\""
		return 0
	    }
	    return 1
	}
	default {
	    set message "Unknown operator \"$op\""
	    return 0
	}
    }
}

# ### ### ### ######### ######### #########
## Ready
return
