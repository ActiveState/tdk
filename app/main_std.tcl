# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-

# -------------------------------------------------------
# Standard actions taken by a TDK application on startup.

# Note that checking for unwrapped needs a sensible result from
# starkit::startup, this is true iff it is run from main.tcl,
# therefore it cannot be done here.
# -------------------------------------------------------

proc go {file} {
    # ### ### ### ######### ######### #########
    ## Extend auto_path with the P-* directories in the
    ## tdkbase. Starpacks have that automatically done for them by
    ## TclApp, but the TDK tools are starkits and TclApp doesn't set
    ## them up for the stuff in their starpack interpreter.

    global auto_path
    foreach d $auto_path {
	foreach pd [glob -nocomplain -directory $d P-*] {
	    lappend auto_path $pd
	}
    }

    # ### ### ### #########

    uplevel \#0 [list source $file]
    return
}
