# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# potMD.tcl --
#
#	Display & Edit of teapot meta data (misc. panel).
#
# Copyright (c) 2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: Exp $
#
# -----------------------------------------------------------------------------

package require snit
package require dictentry

# -----------------------------------------------------------------------------

snit::widget tcldevkit::teapot::mdWidget {
    hulltype ttk::frame

    option -connect         -default {}
    option -errorbackground -default lightyellow

    constructor {args} {

	# See also "tclapp/lib/tclapp-ui/mdeditor.tcl". The ref'd
	# widget is a dialog, this here is a panel. The dialog has a
	# specific flow of information, on open and close, the panel
	# OTOH is continously open, with the responsibility to track
	# state changes and to push its own changes to the state. The
	# general UI layout and such however is the same for both.

	dictentry $win.de \
	    -labelks {meta data keyword} -labelkp {meta data keywords} \
	    -labelvs {value}             -labelvp {values} \
	    -titlek Keyword -titlev Value \
	    -validk     [mymethod ValidKey] \
	    -transformk [myproc   TransKey]
		
	grid $win.de -column 0 -row 0 -sticky swen

	grid columnconfigure $win 0 -weight 1 -minsize 30
	grid rowconfigure    $win 0 -weight 1

	# Handle initial options. This implies the initialization of
	# our state too, as part of -variable processing.

	$self configurelist $args

	trace add variable [myvar current] write [mymethod Export]
	return
    }

    destructor {
	trace remove variable [myvar current] write [mymethod Export]
    }

    # ### ### ### ######### ######### #########
    ## Object state

    variable current {} ; # Current MD settings shown, possibly modified by the user

    # ### ### ### ######### ######### #########

    method UpCall {args} {
	# Assume that -connect is set.
	return [uplevel \#0 [linsert $args 0 $options(-connect)]]
    }

    method {do error@} {index field msg} {
	# ignore
	return
    }

    method {do select} {selection} {
	# ignore
	return
    }

    method {do refresh-current} {} {
	$self Import
	$win.de configure -dictvariable [myvar current] -state normal
	return
    }

    method {do no-current} {} {
	$win.de configure -dictvariable {} -state disabled
	return
    }

    # ### ### ### ######### ######### #########

    variable carr -array {}
    variable lock 0

    method Import {} {
	if {$lock} return
	set tr {}
	foreach {k v} [$self UpCall getdict] {
	    lappend tr [TransKey $k] $v
	}
	set lock 1
	set current $tr
	set lock 0
	array set carr $tr
	return
    }

    method Export {args} {
	if {$lock} return
	set lock 1
	$self UpCall setdict $current
	array unset carr *
	array set carr $current
	set lock 0
	return
    }

    # ### ### ### ######### ######### #########

    method ValidKey {key} {
	if {$key eq ""} {
	    return Empty
	}
	if {[$self UpCall isSpecial $key]} {
	    return "Invalid key, use panel \"[$self UpCall panelOf $key]\" instead"
	}
	if {[info exists carr([TransKey $key])]} {
	    return "* The list already contains this item"
	}
	return ""
    }

    proc TransKey {k} {
	return [::textutil::cap [string tolower $k]]
    }

    # ### ### ### ######### ######### #########
}

# -----------------------------------------------------------------------------
package provide tcldevkit::teapot::mdWidget 1.0
