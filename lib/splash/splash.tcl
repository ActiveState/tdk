# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# splash.tcl --
#
#	Handle a splash screen ...
#
# Copyright (c) 2003-2010 ActiveState Software Inc.
#
#
# RCS: @(#) $Id:  $
#

# ### ######### ###########################
# Requisites

package require help           ; # For openUrl
# Defer package require Tk until needed to delay Tk loading

namespace eval ::splash {
    variable splashdone 0
    variable splashup   0
    variable about      {}
    variable options
    array set options {
	-url "http://www.activestate.com/tcl"
	-title {}
	-message {}
	-imagefile {}
	-license {}
    }
}

# ### ######### ###########################
# Public API

proc splash::theimage {} {
    variable options
    variable image
    if {![info exists image]} {
	package require Tk
	package require img::png ; # For the png splash image

	# work around recent issue in tk/tkimg (8.5.16) by loading
	# ourselves and having tk/timg use the data block directly.
	set chan [open $options(-imagefile)]
	fconfigure $chan -translation binary -encoding binary
	set data [read $chan]
	close $chan

	set image [image create photo about_img -data $data]
    }
    return $image
}

proc ::splash::showAbout {{splash 0}} {
    return [AboutBox [theimage] $splash]
}

proc ::splash::start {{delay 1500}} {
    variable splashup
    variable splashdone
    variable about

    if {![catch {package present Tk}]} {
	set splashdone 0
	set about [showAbout 1]
	after $delay [list set ::splash::splashdone 1]
	set splashup 1
    } ;# else: No Tk, no splash screen {}
    return
}

proc ::splash::complete {} {
    variable splashup
    variable splashdone
    variable about

    if {$splashup} {
	update idle
	if {!$splashdone} {
	    vwait ::splash::splashdone
	}
	destroy $about
    }
    return
}

proc ::splash::configure {args} {
    variable options
    set len [llength $args]
    if {$len == 0} {
	return [array get options]
    } elseif {$len == 1} {
	set key [lindex $args 0]
	if {![info exists options($key)]} {
	    set msg "unknown option \"$key\": must be one of "
	    append msg [join [lsort [array names options]] {, }]
	    return -code error $msg
	}
	return $options($key)
    } elseif {[llength $args] & 1} {
	return -code error "specify zero, one or pairs of options"
    } else {
	foreach {key val} $args {
	    if {![info exists options($key)]} {
		set msg "unknown option \"$key\": must be one of "
		append msg [join [lsort [array names options]] {, }]
		return -code error $msg
	    }
	    set options($key) $val
	}
	return
    }
}

# ### ######### ###########################
# Internal commands

proc ::splash::AboutBox {img splash} {
    package require Tk

    variable options

    set w .about
    destroy $w

    # Create an undecorated toplevel

    toplevel $w
    wm withdraw $w
    wm overrideredirect $w 1

    set title $options(-title)
    if {$title ne ""} {
	wm title $w $title
    } else {
	wm title $w "About [tk appname]"
    }

    # Determine image size and place it.

    set height [image height $img]
    set width  [image width $img]

    label $w.l -width $width -height $height -image $img \
	-highlightthickness 0 -padx 0 -pady 0 -bd 0
    pack $w.l

    if {!$splash} {
	set url $options(-url)
	if {$url ne ""} {
	    label $w.url -bd 1 -bg white -padx 10 -pady 0 -highlightthickness 0 \
		    -text $url -fg blue -cursor hand2 -relief raised
	    place $w.url -x 10 -y 265
	    bind  $w.url <ButtonRelease-1> [list help::openUrl $url]
	}

	set message $options(-message)
	if {$message ne ""} {
	    label $w.msg -bd 1 -bg white -padx 8 -pady 0 -highlightthickness 0 \
		    -text $message -relief flat
	    place $w.msg -x 280 -y 265
	}

	set license $options(-license)
	if {$license ne ""} {
	    label $w.lic -bd 1 -bg white -padx 8 -pady 0 -highlightthickness 0 \
		-text $license -relief flat
	    place $w.lic -x 10 -y 250
	}
    }

    # Establish dialog bindings

    event add <<AboutDismiss>> <Return> \
	<ButtonRelease-1> <ButtonRelease-2> <ButtonRelease-3>
    if {$splash} {
	bind $w <<AboutDismiss>> {}
    } else {
	bind $w <<AboutDismiss>> [list destroy $w]
    }

    # Add the Windows-only console hack

    if {$::tcl_platform(platform) eq "windows"} {
	bind $w <F12> "console show ; destroy [list $w]; break"
    }

    ::tk::PlaceWindow $w center
    wm resizable $w 0 0

    # Force the window to the top.

    if {$::tcl_platform(platform) eq "windows"} {
	wm attributes $w -topmost 1
    }

    wm deiconify $w
    raise        $w
    focus        $w
    update

    # Return the about window so we can destroy it from external bindings
    # if necessary.
    return $w
}

# ### ######### ###########################
# Ready

package provide splash 1.3
