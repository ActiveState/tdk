# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# image.tcl --
#
#	This file is loaded by startup.tcl to populate the image::image
#	array with platform dependent pre-loaded image types to be used
#	throughout the gui.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: image.tcl,v 1.6 2000/10/31 23:30:58 welch Exp $

# First integration of image package. Load everything here. Later we
# can distribute the loading code throughout the debugger application.

package require img::png
package require treectrl ; # for imagetint

namespace eval image {
    variable image
    variable imgdir [file join [file dirname [info script]] images]
}

proc image::init {} {
    variable image
    variable imgdir

    foreach {key dis img} {
	break_disable		0 break_d.gif
	break_enable		0 break_e.gif
	var_disable		0 var_d.gif
	var_enable		0 var_e.gif
	comboArrow		0 combo_arrow.gif
	current			0 current.gif
	current_disable		0 current_d.gif
	current_enable		0 current_e.gif
	current_var		0 current_v.gif
	run			1 go.png
	stop			1 cancel.png
	restart			1 restart.png
	refreshFile		1 page_refresh.png
	into			1 stepin.gif
	out			1 stepout.gif
	over			1 stepover.gif
	pause			1 debug_break.png
	history_disable		0 history_disable.gif
	history_enable		0 history_enable.gif
	history			0 history.gif
	to			1 stepto.gif
	cmdresult		1 stepresult.gif
	win_break		0 win_break.gif
	win_eval		0 win_eval.gif
	win_proc		0 win_proc.gif
	win_watch		0 win_watch.gif
	win_cover		0 win_cover.gif

	syntax_error		0 cancel.png
	syntax_warning		0 warning.png

	sort_increasing		0 sort_increasing.gif
	sort_decreasing		0 sort_decreasing.gif

	spawn_disable		0 spawn_d.gif
	spawn_enable		0 spawn_e.gif

	closec			1 link_break.png

	break_enable_s		0 break_s.gif
	var_enable_s		0 var_s.gif
	syntax_error_s		0 syn_error_s.gif

	break_enable_sx		0 break_sx.png
	var_enable_sx		0 var_sx.png
	syntax_error_sx		0 syn_error_sx.png

	current_sp_disable	0 current_spd.gif
	current_sp_enable	0 current_spe.gif
	history_sp_disable	0 history_spd.gif
	history_sp_enable	0 history_spe.gif

	breakspawn_enable		0 breakspawn_ee.gif
	breakspawn_enabledisable	0 breakspawn_ed.gif
	breakspawn_disableenable	0 breakspawn_de.gif
	breakspawn_disable		0 breakspawn_dd.gif

	current_bs_ee		0 current_bs_ee.gif
	current_bs_ed		0 current_bs_ed.gif
	current_bs_de		0 current_bs_de.gif
	current_bs_dd		0 current_bs_dd.gif

	history_bs_ee		0 history_bs_ee.gif
	history_bs_ed		0 history_bs_ed.gif
	history_bs_de		0 history_bs_de.gif
	history_bs_dd		0 history_bs_dd.gif

	instrumented		1 bug.png
	help                    0 help.gif
    } {
	set image($key) [image create photo -file [file join $imgdir $img]]
	if {$dis} {
	    append key _disable
	    # make a _disable gray-tinted variant
	    set image($key) [image create photo -file [file join $imgdir $img]]
	    imagetint $image($key) \#cccccc 160
	}
    }

    # File for icon in iconwindow
    set image(f,iconImage) [file join $imgdir debugUnixIcon.gif]

    # Images for overlapped bp/sp display.

    ## breakspawn_mixeddisable ???
    ## breakspawn_mixedenable  ???

    return
}
image::init
