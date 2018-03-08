# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: canvas_list.tcl,v  Exp $
#
# Handles browsing canvas items.
#

namespace eval canvas {}
proc canvas::init {w args} {
    eval [list inspect_box $w \
	      -updatecmd canvas::update \
	      -retrievecmd canvas::retrieve \
	      -filtercmd {}] $args
    return $w
}

proc canvas::update {path target} {
    set output {}
    foreach w [$path windows_info get_windows] {
	if {[$path windows_info get_class $target $w] eq "Canvas"} {
	    lappend output $w
	}
    }
    return $output
}
proc canvas::retrieve {path target canvas} {
    set items [send $target [list $canvas find all]]
    set result "# canvas $canvas has [llength $items] items\n"
    foreach item $items {
	append result "# item $item is tagged [list [send $target $canvas gettags $item]]\n"
	append result "$canvas itemconfigure $item"
	foreach spec [send $target [list $canvas itemconfigure $item]] {
	    append result " \\\n\t[lindex $spec 0] [list [lindex $spec 4]]"
	}
	append result "\n"
    }
    return $result
}
