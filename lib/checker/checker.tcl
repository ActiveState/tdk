# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# checker.tcl --
#
#       This file imports the checker functionality, and
#       provides an interface to it. 
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: checker.tcl,v 1.12 2000/10/31 23:30:53 welch Exp $

package provide checker 1.4

# Get the required packages...
# This package imports the "parse" command.

package require parser

namespace eval checker {
    variable libdir [file dirname [info script]]
}

# ::checker::check --
#
#	This is the main routine that is used to
#       scan and then analyze a script.
#
# Arguments:
#	script            The Tcl script to check
#
# Results:
#       The found warnings and errors. The format of the return
#       list is as follows:
#           {{{error message} {location}} ...}

proc ::checker::check {script} {

    # Initialize the internal variables

    set ::message::collectedResults ""
    ::analyzer::initns
    
    # Assign the script to scan

    set ::analyzer::script $script

    # First pass analysis

    set ::analyzer::scanning 1
    analyzer::checkScript
    set ::analyzer::scanning 0

    # Second phase analysis

    analyzer::checkScript

    # Return the result
    return $::message::collectedResults
}

source [file join $::checker::libdir location.tcl]
source [file join $::checker::libdir analyzer.tcl]
source [file join $::checker::libdir context.tcl]
source [file join $::checker::libdir userproc.tcl]
source [file join $::checker::libdir configure.tcl]
source [file join $::checker::libdir filter.tcl]
source [file join $::checker::libdir message.tcl]
#source [file join $::checker::libdir pcx.tcl]
source [file join $::checker::libdir checkerCmdline.tcl]
source [file join $::checker::libdir xref.tcl]
source [file join $::checker::libdir timeline.tcl]

# This code must be run after the other checker files have been
# sourced in, in order for the namespace imports to work. It provides
# the public API for checker extensions.

namespace eval checker {
    # import internal functions

    namespace import ::configure::register
    namespace import ::analyzer::*
}

# Configure the checker system
::analyzer::initns
