# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package as::cache::sync 0.1
# Meta platform    tcl
# Meta require     snit
# @@ Meta End

# -*- tcl -*-

package require snit

snit::type ::as::cache::sync {

    constructor {cmd} {
	set _cmd $cmd
	return
    }

    method get {key args} {
	if {![info exists _data($key)]} {
	    set command [linsert $_cmd end $key]
	    foreach a $args {lappend command $a}
	    set _data($key) [uplevel \#0 $command]
	}
	return $_data($key)
    }

    method clear {{pattern *}} {
	array unset _data $pattern
	return
    }

    variable _cmd         {}
    variable _data -array {}
}

return
