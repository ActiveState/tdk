# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# namespaces_list.tcl
#
# $Id: namespaces_list.tcl,v Exp $

namespace eval names {}
proc names::init {w args} {
    eval [list inspect_box $w \
	      -separator :: \
	      -updatecmd names::update \
	      -retrievecmd names::retrieve \
	      -filtercmd {}] $args
    return $w
}

proc names::update {path target} {
    return [lsort -dictionary [names::names $target]]
}
proc names::retrieve {path target namespace} {
    set result "namespace eval [list $namespace] {\n"

    set exports [names::exports $target $namespace]
    if {[llength $exports]} {
	append result "\n    namespace export $exports\n"
    }

    set vars [names::vars $target $namespace]
    if {[llength $vars]} {
	append result "\n    \#\# Variables:\n"
	foreach var [lsort -dictionary $vars] {
	    append result "    [names::value $target $var]\n"
	}
    } else {
	append result "\n    \#\# No Declared Variables\n"
    }

    set procs [lsort -dictionary [names::procs $target $namespace]]
    set internal [list]
    if {[llength $exports]} {
	append result "\n    \#\# Exported Procedures:\n"
	foreach p $procs {
	    set tail [namespace tail $p]
	    set found 0
	    foreach exptn $exports {
		if {[string match $exptn $tail]} {
		    append result "    \#[names::prototype $target $p]\n"
		    set found 1
		    break
		}
	    }
	    if {!$found} {
		lappend internal $p
	    }
	}
    } else {
	append result "\n    \#\# No Exported Procedures\n"
    }
    if {[llength $internal]} {
	append result "\n    \#\# Internal Procedures:\n"
	foreach p $internal {
	    append result "    \#[names::prototype $target $p]\n"
	}
    } else {
	append result "\n    \#\# No Internal Procedures\n"
    }

    append result "}\n\n"

    set children [lsort -dictionary [names::names $target $namespace]]
    foreach child $children {
	if {$child ne $namespace} {
	    append result "namespace eval [list $child] {}\n"
	}
    }

    return $result
}
