# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tcldevkit::tk 1.0
# Meta platform    tcl
# Meta summary     Checking for Tk
# Meta description Check availability of Tk, for applications having GUI and command line modes of operation.
# Meta category    Tk
# Meta subject     Tk
# @@ Meta End

# -*- tcl -*-
# check_tk.tcl --
#
# This package determines if a TDK tool should invoke the GUI
# mode. For this it checks whether:
#
# - The command line is empty
# - Tk is present, or loadable
# - We are on windows
# - A DISPLAY is present.
#
# The exact interaction of these checks can be found in the code.
#
# Independent of the appframe package to avoid incurring the big
# overhead of sourcing this package and then not using it.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# -----------------------------------------------------------------------------

namespace eval ::tcldevkit::tk {}

# -----------------------------------------------------------------------------
# Public API. Boolean result.
# True if and only if GUI mode should be used.

proc ::tcldevkit::tk::present {} {
    variable present
    return $present
}

# -----------------------------------------------------------------------------
# Internal helper. Determines the result for the public API command.

proc ::tcldevkit::tk::CheckTk {mvar} {
    global argv tcl_platform env

    upvar 1 $mvar msg

    # Note: We have to take the differences between platform into
    # account.  On Windows/OS X it is wrong to look for a DISPLAY.  We
    # can also check to see if Tk is already loaded.

    if {[llength $argv]} {
	# The user has provided command line arguments.
	# Do not use the GUI mode.
	return 0
    }

    # No command line arguments. GUI mode is possible if Tk is already
    # present (i.e. statically linked), or loadable.

    if {[package provide Tk] ne ""} {return 1}

    if {![catch {package require Tk} xmsg]} {
	return 1
    } else {
	set msg $xmsg
    }

    return 0
}

proc ::tcldevkit::tk::Init {} {
    variable present

    set msg ""
    set present [CheckTk msg]
    if {$msg != {}} {
	puts "Error loading Tk: $msg"
	puts ""
    }

    # After loading Tk (or not) we always start with an withdrawn
    # interface. If Tk was loaded this allows for a nice splash screen
    # without interference by the main GUI. This preserves the bugfix
    # for bugzilla entry #19500 too.

    catch {wm withdraw .}
    return
}

# -----------------------------------------------------------------------------
# Data structures and initialization.

namespace eval ::tcldevkit::tk {
    variable present
    if {![info exists present]} { set present 0 }
}

::tcldevkit::tk::Init
return
