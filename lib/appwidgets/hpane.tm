# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package hpane 0.1
# Meta platform    tcl
# Meta summary     Closable labeled frame
# Meta description Megawidget, a close-able labeled frame.
# Meta category    Widget
# Meta subject     frame tk widget label close
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ######### ###########################

# UI tools. Widget: Close-able labeled frame.

# ### ######### ###########################
## Prerequisites

package require image   ; # bitmaps
package require snit    ; # object system

# ### ######### ###########################
## Implementation

snit::widget hpane {
    # ### ######### ###########################

    delegate option * to hull ; # hull <=> frame
    delegate method * to hull

    component label
    component button
    delegate option -text         to label ; # Title to show.
    delegate option -textvariable to label ; # Title to show.
    option          -closecmd {}   ; # Callback when closing the frame

    # ### ######### ###########################
    ## Public API. Construction

    constructor {args} {
	$hull configure -relief sunken -bd 1

	if {[info exists ::TILE] && $::TILE} {
	    set frame [ttk::frame $win.frame]
	    # Text of label through delegated option
	    install label using ttk::label $frame.label -anchor w

	    install button using ttk::button $frame.x \
		-image [image::get delete] -text X \
		-style Slim.Toolbutton -takefocus 0 \
		-command [mymethod ClosePane] \
		-state $cstate
	    pack $frame -fill both -expand 1
	} else {
	    set frame $win
	    # Text of label through delegated option
	    install label using label $frame.label -anchor w

	    install button using button $frame.x \
		-image [image::get delete] -text X -takefocus 0 -bd 1 \
		-relief flat -overrelief raised \
		-command [mymethod ClosePane] \
		-state $cstate
	}
	grid $label  -row 0 -column 0 -sticky news
	grid $button -row 0 -column 1 -sticky news
	grid columnconfigure $frame 0 -weight 1
	grid rowconfigure    $frame 1 -weight 1

	$self configurelist $args
	return
    }

    # ### ######### ###########################
    ## Public API. Extend container by application specific content.

    method setwidget {w} {
	grid $w -in $frame -row 1 -column 0 -sticky news -columnspan 2
    }

    # ### ######### ###########################
    ## Internal. State variable for close-button (X)

    variable frame  {}       ; # frame in which to place setwidget
    variable cstate disabled ; # State for no callback.

    # ### ######### ###########################
    ## Internal. Handle changes to the options.

    onconfigure -closecmd {value} {
	# We ignore calls which do not change anything, remember the
	# command prefix for evreything else, and handle the state of
	# the button. The button is be disabled if there is no
	# callback.

	if {$value eq $options(-closecmd)} return
	set options(-closecmd) $value
	set cstate [expr {($value == {}) ? "disabled" : "normal"}]
	$button configure -state $cstate
	return
    }

    # ### ######### ###########################
    ## Internal. Callback for the close button.

    method ClosePane {} {
	# We know that we can be called if and only if a callback has
	# been set. Otherwise the button is disabled.

	uplevel \#0 [linsert $options(-closecmd) end $win]
	return
    }

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use
return
