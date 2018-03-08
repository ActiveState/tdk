# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# check_startup.tcl -- -*- tcl -*-
#
#	This file is the primary entry point for the 
#       Tcl Checker in all incarnations (TDK, Komodo, ...).
#
# Copyright (c) 2001-2006 ActiveState Software Inc.
# Copyright (c) 1999      by Scriptics Corporation.
# 
# RCS: @(#) $Id: startup.tcl,v 1.5 2000/10/31 23:31:04 welch Exp $
#
##########################################################
# Initialize the checker library

package provide app-check 1.0

if {0} {
    puts $::env(PATH)
    puts [info nameofexecutable]
    catch {package require foo}
    puts [lsort [package names]]
    puts [info library]
}

if {[string match -psn* [lindex $::argv 0]]} {
    # Strip Apple's option providing the Processor Serial Number to bundles.
    incr ::argc -1
    set  ::argv [lrange $::argv 1 end]
}

package require log
::log::lvSuppress debug

package require parser
package require cmdline
package require starkit

package require projectInfo
## Set some relatively FAKE the data the checker requires from
## projectInfo

namespace eval ::projectInfo {
    variable baseTclVers [info tclversion]

    # The variable pcxPks is not required anymore, we directly glob
    # for the files (see configure.tcl, PcxSetup).

    variable pcxPdxDir      [file join [file dirname [file dirname $starkit::topdir]] lib]
    variable pcxPdxVar      TCLDEVKIT_LOCAL
    variable usersGuide     "the user manual"
    variable printCopyright 0
    variable productName    "TclDevKit Checker"
}
# empty procedure for now.
proc projectInfo::printCopyright {name {extra {}}} {}

###############################################################

package require pref::devkit ; # TDK preferences

pref::setGroupOrder [pref::devkit::init]

###############################################################
## Ask for the checker engine and initialize it.

package require checker
auto_load checker::check

###############################################################
# Register our information gathering procedure. This replaces
# the usual silent mode with a "print to stdout" procedure.

set ::message::displayProc ::message::displayTTY

###############################################################
# Process the commandline args.

set filesToCheck [checkerCmdline::init]

###############################################################
# load the pcx extension files

if {[configure::packageSetup] == 0} {
    exit 1
}

###############################################################
# Call the main routine that checks all the files.

analyzer::check $filesToCheck

# Dump the cross-reference database when x-ref mode was enabled.

if {$::configure::xref} {
    ::analyzer::dumpXref
    exit
} elseif {$::configure::packages} {
    ::analyzer::dumpPkg
}

# Return an error code if any of the messages generated were 
# error messages.

if {[::analyzer::getErrorCount] > 0} {
    exit 1
} else {
    exit
}

###############################################################
