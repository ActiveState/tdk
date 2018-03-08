# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#

# Copyright (c) 2001-2006 ActiveState Software Inc.
#
# 
# RCS: @(#) $Id: startup.tcl,v 1.5 2001/01/24 19:41:24 welch Exp $

# Assumes that Tk is present. If not, then assumes that all calls to
# these commands are caught.

namespace eval ::cursor {}

proc ::cursor::propagate {w cursor} {
    catch {
	Propagate $w $cursor
	update idle
	update
    }
    return
}

proc ::cursor::Propagate {w cursor} {
    variable CURSOR
    # Ignores {} cursors

    if {![catch {set c [$w cget -cursor]}]} {
	if {[string compare {} [set CURSOR($w) $c]]} {
	    $w config -cursor $cursor
	} else {
	    unset CURSOR($w)
	}
    } else {
	catch {unset CURSOR($w)}
    }
    foreach child [winfo children $w] { Propagate $child $cursor }
    return
}

proc ::cursor::restore {w {cursor {}}} {
    catch {
	Restore $w $cursor
	update idle
	update
    }
    return
}

proc ::cursor::Restore {w {cursor {}}} {
    variable CURSOR
    catch {
	if {[info exists CURSOR($w)]} {
	    $w config -cursor $CURSOR($w)
	} else {
	    $w config -cursor $cursor
	}
    }
    foreach child [winfo children $w] { Restore $child $cursor }
    return
}

package provide tclapp::cursor 1.0
