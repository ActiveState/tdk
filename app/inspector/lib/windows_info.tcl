# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: windows_info.tcl,v Exp $
#
# Maintains the list of windows, and caches window class information.
# (the list is shared between windows_list and menus_list.)
#

snit::type windows_info {
    variable windows -array {}
    variable classes -array {}

    method clear {} {
	array unset windows *
    }
    method get_windows {} { return [array names windows] }
    method append_windows {target parent} {
        set cmd "if {\[::info command winfo\] != {}}\
		 { ::winfo children [list $parent] }"
	if {![info exists windows($parent)]} {
	    set windows($parent) {}
	}
	foreach w [send $target $cmd] {
	    $self append_windows $target $w
	}
    }
    method update {target} {
	$self clear
	if {![send $target {info exists ::tk_version}]} { return }
        set cmd {if {[::info command winfo] != {}} { ::winfo children . }}
	if {[catch {send $target $cmd} children]} {
	    # No winfo ...
	    return
        }
	set windows(.) [send $target [list ::winfo class .]]
	foreach w $children {
	    $self append_windows $target $w
	    update idletasks
	}
    }
    method get_class {target w} {
	if {![info exists windows($w)]} {
	    if {![send $target [list ::winfo exists $w]]} {
		return ""
	    }
	    set windows($w) {}
	}
	if {$windows($w) eq ""} {
	    set windows($w) [send $target [list ::winfo class $w]]
	}
	return $windows($w)
    }
}
