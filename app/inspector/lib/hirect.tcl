# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# hirect.tcl -
#
#	Highlight rectangle using toplevels
#
# RCS: @(#) $Id:  hobbs Exp $
#

# Creation and Options - hirect $path ...
#    -background -default black
#    -coords -default {0 0 0 0}
#
# Methods
#  $path display
#  $path withdraw
#
# Bindings
#  Escape            => invokes [$dlg close cancel]
#  WM_DELETE_WINDOW  => invokes [$dlg close cancel]
#

if 0 {
    # Samples
    package require hirect
    set r [hirect .hi -coords]
    puts [$r display]
}

package require snit    ; # object system

# ### ######### ###########################
## Implementation

snit::widget hirect {
    hulltype toplevel

    # We'll capture all options and methods as this is a special 4-toplevel
    # construction
    #delegate option * to hull
    #delegate method * to hull

    option -borderwidth -default 0 -configuremethod C-option
    option -relief	-default flat -configuremethod C-option
    option -background	-default black -configuremethod C-option
    option -width	-default 2 -configuremethod C-update \
	-type {snit::fpixels -min 0}
    option -modal	-default none \
	-type {snit::enum -values {none local global}}
    option -anchor	-default "nw" -configuremethod C-update \
	-type {snit::enum -values {"" n s e w nw wn ne en sw ws se es}}
    option -timeout	-default 0

    variable top -array {}
    variable lastFocusGrab {}
    variable lastcoords {}
    variable timeout {}

    constructor {args} {
	wm withdraw $win
	wm overrideredirect $win 1
	set class [winfo class $win]

	set top(top) $win
	foreach side {left right bottom} {
	    set top($side) [toplevel $win.$side -class $class]
	    wm withdraw $top($side)
	    wm overrideredirect $top($side) 1
	}

	# Default to invoking no/cancel/withdraw
	foreach side {top left bottom right} {
	    set w $top($side)
	    wm protocol $w WM_DELETE_WINDOW [mymethod withdraw close]
	    bind $w <Key-Escape> [mymethod withdraw close]
	    bind $w <ButtonRelease-1> [mymethod withdraw close]
	    if {[tk windowingsystem] eq "aqua"} {
		tk::unsupported::MacWindowStyle style $w help noShadow
	    }
	}

	$self configurelist $args
    }

    destructor {
	after cancel $timeout
    }

    method C-option {option value} {
	# Propagate these options to all toplevels
	# hull requires special configure handling
	$hull configure $option $value
	foreach side {left right bottom} {
	    $top($side) configure $option $value
	}
	set options($option) $value
    }

    method C-update {option value} {
	# Propagate these options to all toplevels
	# hull requires special configure handling
	set options($option) $value
	if {[winfo ismapped $win]} { $self place $lastcoords }
    }

    # ### ######### ###########################
    ## Public API. Extend container by application specific content.

    method display {args} {
	set lastFocusGrab [focus]
	set last [grab current $win]
	lappend lastFocusGrab $last
	if {[winfo exists $last]} {
	    lappend lastFocusGrab [grab status $last]
	}

	eval [linsert $args 0 $self place]
	if {$options(-modal) ne "none"} {
	    if {$options(-modal) eq "global"} {
		catch {grab -global $win}
	    } else {
		catch {grab $win}
	    }
	}
	if {$options(-timeout) > 0} {
	    set timeout [after $options(-timeout) [mymethod withdraw timeout]]
	}
    }

    method withdraw {{reason "withdraw"}} {
	set result $reason
	catch {grab release $win}
	# Let's avoid focus/grab restore if we don't think we were showing
	if {![winfo ismapped $win]} { return $reason }
	foreach side {top left bottom right} { wm withdraw $top($side) }
	foreach {oldFocus oldGrab oldStatus} $lastFocusGrab { break }
	# Ensure last focus/grab wasn't a child of this window
	if {[winfo exists $oldFocus] && ![string match $win* $oldFocus]} {
	    # XXX needs to handle focus moved to some other window
	    # XXX while the window was showing
	    catch {focus $oldFocus}
	}
	if {[winfo exists $oldGrab] && ![string match $win* $oldGrab]} {
	    if {$oldStatus eq "global"} {
		catch {grab -global $oldGrab}
	    } elseif {$oldStatus eq "local"} {
		catch {grab $oldGrab}
	    }
	}
	return $result
    }

    method place {args} {
	after cancel $timeout
	if {[llength $args] == 1 && [llength [lindex $args 0]] == 4} {
	    foreach {x y w h} [lindex $args 0] { break }
	} elseif {[llength $args] == 4} {
	    foreach {x y w h} $args { break }
	} else {
	    return -code error "expected {x y w h}, got $args"
	}
	set lastcoords [list $x $y $w $h]
	set anchor $options(-anchor)
	# adjust x and y from default center anchor
	if {[string match *n* $anchor]} {
	    # no adjustment necessary
	} elseif {[string match *s* $anchor]} {
	    set y [expr {$y + $h}]
	} else {
	    set y [expr {$y + ($h / 2)}]
	}
	if {[string match *w* $anchor]} {
	    # no adjustment necessary
	} elseif {[string match *e* $anchor]} {
	    set x [expr {$x + $w}]
	} else {
	    set x [expr {$x + ($w / 2)}]
	}

	foreach side {top left bottom right} { wm withdraw $top($side) }

	set tw $options(-width)
	set g(top)    [expr {$w + 2*$tw}]x${tw}+[expr {$x - $tw}]+[expr {$y - $tw}]
	set g(left)   ${tw}x${h}+[expr {$x - $tw}]+$y
	set g(right)  ${tw}x${h}+[expr {$x + $w}]+$y
	set g(bottom) [expr {$w + 2*$tw}]x${tw}+[expr {$x - $tw}]+[expr {$y + $h}]

	foreach side {top left bottom right} {
	    wm geometry $top($side) $g($side)
	    wm deiconify $top($side)
	    raise $top($side)
	}
    }
}

# ### ######### ###########################
## Ready for use

package provide hirect 1.0
