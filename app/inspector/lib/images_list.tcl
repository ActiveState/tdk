# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: images_list.tcl,v Exp $
#

namespace eval images {}
proc images::init {w args} {
    eval [list inspect_box $w \
	      -updatecmd images::update \
	      -retrievecmd images::retrieve \
	      -filtercmd {}] $args
    $w add menu separator
    $w add menu command -label "Display Image" -underline 0 \
	-command [list images::display_image $w]
    return $w
}

proc images::update {path target} {
    return [lsort -dictionary [send $target {::image names}]]
}
proc images::retrieve {path target image} {
    set result "# image configuration for [list $image]\n"
    append result "# ([send $target ::image width $image]x[send $target ::image height $image] [send $target ::image type $image] image)\n"
    append result "$image configure"
    foreach spec [send $target [list $image configure]] {
	if {[llength $spec] == 2} continue
	append result " \\\n\t[lindex $spec 0] [list [lindex $spec 4]]"
    }
    append result "\n"
    return $result
}
proc images::display_image {path} {
    set target [$path target]
    set item   [$path curselection]
    if {$item eq ""} {
	tk_messageBox -title "No Selection" -type ok -icon warning \
	    -message "No image has been selected.\
			Please select one first."
	return
    }
    set tmpVar __inspector_image_counter__
    set cmd [format {if {![info exists %1$s]} {set %1$s 0}} $tmpVar]
    send $target $cmd
    set pre ".__inspector__image"
    while {[send $target [list winfo exists $pre\$$tmpVar]]} {
	send $target [list incr $tmpVar]
    }
    set w $pre[send $target [list set $tmpVar]]
    send $target [::subst -nocommand {
	::toplevel $w
	::button $w.close -text "Close $item" \
	    -command [list destroy $w]
	::label $w.img -image $item
	::pack $w.close $w.img -side top
	::wm title $w "Inspect $item"
    }]
}
