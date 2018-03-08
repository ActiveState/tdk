# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" "$@"

if {0} {
    puts $::env(PATH)
    puts [info nameofexecutable]
    catch {package require foo}
    puts [lsort [package names]]
    puts [info library]
}

##########################################################
# komodo_tcl_lint --
#
#	This file is the primary entry point for the 
#       Komodo Tcl Linter, derived from TclPro Checker.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.
# Copyright (c) 2001-2006 ActiveState Software Inc.
# Copyright (c) 1999 by Scriptics Corporation.
# 
# RCS: @(#) $Id: startup.tcl,v 1.5 2000/10/31 23:31:04 welch Exp $

# Initialize the checker library

package require parser
package require cmdline

## package require projectInfo                         ##
## FAKE the data the checker requires from projectInfo ##

namespace eval ::projectInfo {
    variable baseTclVers 8.3
    variable pcxPkgs        [list \
	    blend oratcl sybtcl tclCom tclDomPro \
	    xmlAct xmlGen xmlServer \
	    ]
    variable pcxPdxDir      [file dirname [info script]]
    variable pcxPdxVar      TCLDEVKIT_LOCAL
    variable usersGuide     "the user manual"
    variable printCopyright 0
    variable productName    "Komodo/Tcl Linter"
}
# empty procedure for now.
proc projectInfo::printCopyright {name {extra {}}} {}

###############################################################
## Load the main checker file directly, bypassing package mgmt
## Determine the true location of the application.

set is [info script]

if {![info exists tcl_platform(isWrapped)]} {
    while {[string match link [file type $is]]} {
	set link [file readlink $is]
	if {[string match relative [file pathtype $link]]} {
	    set is [file join [file dirname $is] $link]
	} else {
	    set is $link
	}
    }
    catch {unset link}
    if {[string match relative [file pathtype $is]]} {
	set is [file join [pwd] $is]
    }
}

set base [file join [file dirname $is] ckengine checker]

if {[file exists $base.tbc]} {
    source $base.tbc
} else {
    source $base.tcl
}

###############################################################
# Initialize the system

package require checker
auto_load checker::check

# Process the commandline args.

set filesToCheck [checkerCmdline::init]

# load the pcx extension files

if {[configure::packageSetup] == 0} {
    exit 1
}

###############################################################
# Register our information gathering procedure. This replaces
# the usual silent mode with a "print to stdout" procedure.

set ::message::displayProc ::message::displayTTY

###############################################################
# Call the main routine that checks all the files.

analyzer::check $filesToCheck

# Return an error code if any of the messages generated were 
# error messages.

if {[analyzer::getErrorCount] > 0} {
    exit 1
} else {
    exit
}

