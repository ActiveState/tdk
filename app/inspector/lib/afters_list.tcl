# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# afters_list.tcl - Originally written by Paul Healy <ei9gl@indigo.ie>
#
# $Id:  Exp $

namespace eval after {}
proc after::init {w args} {
    eval [list inspect_box $w \
	      -updatecmd after::update \
	      -retrievecmd after::retrieve \
	      -filtercmd {}] $args
    return $w
}
proc after::update {path target} {
    return [lsort -dictionary [send $target [list ::after info]]]
}
proc after::retrieve {path target after} {
    set cmd [list ::after info $after]
    set retcode [catch [list send $target $cmd] msg]
    if {$retcode != 0} {
	set result "Error: $msg\n"
    } elseif {$msg != ""} {
	set script [lindex $msg 0]
	set type [lindex $msg 1]
	set result "# after type=$type\n"
	# there is no way to get even an indication of when a timer will
	# expire. tcl should be patched to optionally return this.
	switch $type {
	    idle  {append result "after idle $script\n"}
	    timer {append result "after ms $script\n"}
	    default {append result "after $type $script\n"}
	}
    } else {
	set result "Error: empty after $after?\n"
    }
    return $result
}
