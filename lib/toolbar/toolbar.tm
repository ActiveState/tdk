# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package toolbar 0.2
# Meta platform    tcl
# Meta description Simple toolbar widget, allows buttons and separators.
# Meta as::notes   Might be able to replace its use with tklib's widget::toolbar.
# Meta require     image
# Meta require     snit
# Meta require     tile
# Meta require     Tk
# Meta require     tooltip
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
#
# toolbar - /snit::widget
#	Add multiple buttons, each with icon and
#	possibly a text for tooltips, + command
#	for callback when invoked, and ability
#	change appearance (enabled/disabled/relief).

package require Tk
package require snit
package require image
package require tooltip
package require tile

snit::widget ::toolbar {
    hulltype ttk::frame ; # XXX Forcing tile usage
    delegate option * to hull
    delegate method * to hull

    constructor {args} {
	grid rowconfigure $win 0 -weight 0
	#$self configurelist $args
	return
    }

    # ### ######### ###########################
    # mklabel - NEW API

    variable tools
    variable col   0

    method add {symbol image text args} {
	set     w [set tools($symbol) $win.t$col]
	if {[info exists ::TILE] && $::TILE} {
	    ttk::button $w -style Toolbutton ; #Slim.Toolbutton
	    lappend args -takefocus 0 -state disabled
	} else {
	    button $w
	    lappend args \
		-takefocus 0 -state disabled \
		-bd 1 -width 16 -height 16 \
		-relief flat -overrelief raised
	}
	if {$image eq {}} {
	    lappend args -text $text -height 1 -width 0
	} else {
	    lappend args -image [image::get $image]
	}
	eval [linsert $args 0 $w configure]

	grid columnconfigure $win $col -weight 0
	grid $w -in $win -row 0 -column [incr col] -sticky s -pady 2 -padx 1
	grid columnconfigure $win $col -weight 10

	tooltip::tooltip $w $text
	return $symbol
    }

    method addseparator {} {
	if {[info exists ::TILE] && $::TILE} {
	    set w [ttk::separator $win.sep$col -orient vertical]
	} else {
	    set w [frame $win.sep$col -width 2 -relief sunken -bd 2]
	}

	grid columnconfigure $win $col -weight 0
	grid $w -in $win -row 0 -column [incr col] -sticky ns -pady 1 -padx 1
	grid columnconfigure $win $col -weight 10
	return
    }

    method itemconfigure {symbol args} {
	return [eval [linsert $args 0 $tools($symbol) configure]]
    }

    method itemcget {symbol option} {
	return [$tools($symbol) cget $option]
    }
}

return
