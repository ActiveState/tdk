# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-

# -------------------------------------------------------
# Standard actions taken on startup. For TDK applications which moved
# to AT. I.e. while keeping the general API and control flow the TDK
# specific actions, checking the license and loading the compiler
# package are dropped, compared to the startup within TDK.

# Note that checking for unwrapped needs a sensible result from
# starkit::startup, this is true iff it is run from main.tcl,
# therefore it cannot be done here.
# -------------------------------------------------------

proc ::go {file {lp {}} {pfx {}}} {

    # ### ### ### ######### ######### #########
    ## Extend auto_path with the P-* directories in the
    ## starkit. Others have that automatically done for them by
    ## TclApp, not for the tools based on this file.

    global auto_path
    foreach d $auto_path {
	foreach pd [glob -nocomplain -directory $d P-*] {
	    lappend auto_path $pd
	}
    }

    # ### ### ### #########

    ::splash_hook
    uplevel \#0 [list source $file]
    return
}

# Ditto a fake projectInfo package
package provide  projectInfo 1000
namespace eval ::projectInfo {
    variable productName {ActiveTcl VFSE}
}

#########################################################
proc ::splash_hook {} {}

# XREF: The code of build setup package 'as::tcl::setup::pushmodules'
# XREF: generates variants of this code with the splash_hook filled
# XREF: to refer to proper build number and splash image.
