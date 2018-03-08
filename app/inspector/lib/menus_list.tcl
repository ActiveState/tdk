# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: menus_list.tcl,v Exp $
#
# Handles browsing menus.
#

namespace eval menus {}
proc menus::init {w args} {
    eval [list inspect_box $w \
	      -separator . \
	      -updatecmd menus::update \
	      -retrievecmd menus::retrieve \
	      -filtercmd {}] $args
    return $w
}

proc menus::update {path target} {
    # force update of windows
    $path windows_info update $target
    set output {}
    foreach w [$path windows_info get_windows] {
	if {[$path windows_info get_class $target $w] eq "Menu"} {
	    # skip the tear-off specials
	    if {![string match *.#* $w]} {
		lappend output $w
	    }
	}
    }
    return $output
}
proc menus::retrieve {path target menu} {
    set end [send $target $menu index end]
    if {$end == "none"} { set end 0 } else { incr end }
    set result "# menu $menu has $end entries\n"
    for {set i 0} {$i < $end} {incr i} {
	append result "$menu entryconfigure $i"
	foreach spec [send $target [list $menu entryconfigure $i]] {
	    append result " \\\n\t[lindex $spec 0] [list [lindex $spec 4]]"
	}
	append result "\n"
    }
    return $result
}
