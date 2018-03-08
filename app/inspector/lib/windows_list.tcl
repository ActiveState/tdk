# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: windows_list.tcl,v 1.13 2002/10/21 22:43:15 patthoyts Exp $
#

namespace eval windows {
    variable highlight_color "#ff69b4"
    variable get_window_info  1
    variable filter
    array set filter {
	empty_window_configs 1
	window_class_config  1
	window_pack_in       1
    }
    variable mode config
    variable last_target ""
    variable HI
    array set HI { rect "" after "" delay 750 }
}

proc windows::init {w args} {
    eval [list inspect_box $w \
	      -separator . \
	      -updatecmd windows::update \
	      -retrievecmd windows::retrieve \
	      -filtercmd windows::send_filter] $args
    $w add menu separator
    $w add add radiobutton -variable ::windows::mode \
	-value config -label "Window Configuration" -underline 7 \
	-command [list ::windows::mode_changed $w]
    $w add add radiobutton -variable ::windows::mode \
	-value geometry -label "Window Geometry" -underline 7 \
	-command [list ::windows::mode_changed $w]
    $w add add radiobutton -variable ::windows::mode \
	-value slavegeometry -label "Slave Window Geometry" -underline 1 \
	-command [list ::windows::mode_changed $w]
    $w add add radiobutton -variable ::windows::mode \
	-value bindtagsplus -label "Window Bindtags & Bindings" \
	-command [list ::windows::mode_changed $w] -underline 16
    $w add add radiobutton -variable ::windows::mode \
	-value bindtags -label "Window Bindtags" \
	-command [list ::windows::mode_changed $w] -underline 11
    $w add add radiobutton -variable ::windows::mode \
	-value bindings -label "Window Bindings" -underline 7 \
	-command [list ::windows::mode_changed $w]
    $w add add radiobutton -variable ::windows::mode \
	-value classbindings -label "Window Class Bindings" -underline 8 \
	-command [list ::windows::mode_changed $w]
    $w add add separator
    $w add add checkbutton \
	-variable ::windows::filter(empty_window_configs) \
	-label "Filter Setting of Empty Window Options"
    $w add add checkbutton \
	-variable ::windows::filter(window_class_config) \
	-label "Filter Setting of Window -class Options"
    $w add add checkbutton \
	-variable ::windows::filter(window_pack_in) \
	-label "Filter Setting of Pack -in Options"
    $w add add separator
    $w add add checkbutton \
	-variable ::windows::get_window_info \
	-label "Refresh Window Information" -underline 0
    variable HI
    set HI(rect) [hirect $w.hirect -width 4 -anchor nw -timeout $HI(delay) \
		    -background $::windows::highlight_color]
    return $w
}

proc windows::update {path target} {
    $path windows_info update $target
    return [lsort -dictionary [$path windows_info get_windows]]
}
proc windows::mode_changed {path} {
    if {[$path main last_list] eq $path} {
	$path main select_list_item $path [$path curselection]
    }
}
proc windows::highlight {path target window} {
    set bits [send $target [format {
	list [winfo rootx %1$s] [winfo rooty %1$s] \
	    [winfo width %1$s] [winfo height %1$s] \
	    [winfo ismapped %1$s] [winfo viewable %1$s]
    } [list $window]]]
    foreach {x y w h mapped viewable} $bits { break }
    if {$mapped && $viewable} {
	variable HI
	$HI(rect) display $x $y $w $h
	return 1
    } else {
	return 0
    }
}
proc windows::retrieve {path target window} {
    set class [$path windows_info get_class $target $window]
    set result "# [list $class] window [list $window]"
    if {[windows::highlight $path $target $window]} {
	append result "\n"
    } else {
	append result " (not currently mapped)\n"
    }
    append result [windows::retrieve_$::windows::mode $path $target $window]
    return $result
}
proc windows::retrieve_config {path target window} {
    set result "# basic widget configuration\n"
    append result "[list $window] configure"
    foreach spec [send $target [list $window configure]] {
	if {[llength $spec] == 2} continue
	append result " \\\n\t[lindex $spec 0] [list [lindex $spec 4]]"
    }
    append result "\n"
    return $result
}
proc windows::format_geometry_info {path target window mgr {info {}}} {
    if {![llength $info]} {
	if {[catch {send $target [list $mgr info $window]} info]} {
	    return "# $info\n"
	}
    }
    set result "[list $mgr configure $window]"
    foreach {key val} $info {
	append result " \\\n\t[list $key $val]"
    }
    append result "\n"
    if {$mgr eq "::grid"} {
	set parent [send $target [list winfo parent $window]]
	foreach {cols rows} [send $target [list $mgr size $parent]] {}
	for {set i 0} {$i < $rows} {incr i} {
	    set ginfo [send $target [list $mgr rowconfigure $parent $i]]
	    append result "grid rowconfigure [list $parent] $i $ginfo\n"
	}
	for {set i 0} {$i < $cols} {incr i} {
	    set ginfo [send $target [list $mgr columnconfigure $parent $i]]
	    append result "grid columnconfigure [list $parent] $i $ginfo\n"
	}
    }
    return $result
}
proc windows::retrieve_geometry {path target window} {
    set result "# geometry information"
    if {[catch {send $target [list ::winfo manager $window]} mgr]} {
	append result "\n# $mgr\n"
    } else {
	append result " (manager: $mgr)\n"
	switch -exact $mgr {
	    pack -
	    grid {
		set mgr ::$mgr
		append result [format_geometry_info $path $target $window $mgr]
	    }
	    wm   {
		append result "# no info for wm managed window\n"
	    }
	    default {
		append result "# '$mgr' type retrieval not supported\n"
	    }
	}
    }
    return $result
}
proc windows::retrieve_slavegeometry {path target window} {
    set result "# slave geometry information\n"
    foreach slavemgr {::pack ::grid} {
	foreach slave [send $target [list $slavemgr slaves $window]] {
	    append result [format_geometry_info $path \
			       $target $slave $slavemgr \
			       [send $target [list $slavemgr info $slave]]]
	}
    }
    return $result
}
proc windows::retrieve_bindtags {path target window} {
    set result "# window bindtags\n"
    set tags [send $target [list ::bindtags $window]]
    append result "[list bindtags $window $tags]\n"
    return $result
}

proc windows::retrieve_bindtagsplus {path target window} {
    set result "# window bindtags\n"
    set tags [send $target [list ::bindtags $window]]
    append result "[list bindtags $window $tags]\n"
    append result "# window bindings (in bindtag order) ...\n"
    foreach tag $tags {
	foreach sequence [send $target [list ::bind $tag]] {
	    append result [list bind $tag $sequence \
			       [send $target [list ::bind $tag $sequence]]]
	    append result "\n"
	}
    }
    return $result
}
proc windows::retrieve_bindings {path target window} {
    set result "# window bindings\n"
    foreach sequence [send $target [list ::bind $window]] {
	append result [list bind $window $sequence \
			   [send $target [list ::bind $window $sequence]]]
	append result "\n"
    }
    return $result
}
proc windows::retrieve_classbindings {path target window} {
    set class [$path windows_info get_class $target $window]
    set result "# $class class bindings for $window\n"
    foreach sequence [send $target [list ::bind $class]] {
	append result [list bind $class $sequence \
			   [send $target [list ::bind $class $sequence]]]
	append result "\n"
    }
    return $result
}
proc windows::send_filter {path str} {
    regsub -all -lineanchor {^\s*-container\s[^\n]*$\n} $str {} str
    if {$::windows::filter(empty_window_configs)} {
	regsub -all -lineanchor {^\s*-\S+\s+\{\}(\s*\\)?$\n} $str {} str
    }
    if {$::windows::filter(window_class_config)} {
	regsub -all -lineanchor {^\s*-class\s[^\n]*$\n} $str {} str
    }
    if {$::windows::filter(window_pack_in)} {
	regsub -all -lineanchor {^\s*-in\s[^\n]*$\n} $str {} str
    }
    return $str
}
