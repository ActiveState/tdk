# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# nubloader.tcl
#
#	This file provides an API to get contents of the debugger nub.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.
#

#
# RCS: @(#) $Id: dbg.tcl,v 1.8 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites: No packages, just a namespace.

namespace eval ::nub {}

# ### ### ### ######### ######### #########
## Public API

proc ::nub::script {} {
    variable nubFile

    set                  fd [open $nubFile r]
    set nubScript [read $fd]
    close               $fd
    return $nubScript
}


# ### ### ### ######### ######### #########
## Global data structures.

namespace eval ::nub {

    # ### ### ### ######### ######### #########
    ## Instance data

    # startup options --
    #
    # Fields:
    #   libDir		The directory that contains this package.
    #   nubFile		Absolute path of the file containing the nub sources.

    variable libDir     {}
    variable nubFile    {}

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Helper for initialization.

proc ::nub::initialize {} {
    # Find the directory of this package. If one is not specified
    # look in the directory containing the startup script.

    variable libDir

    set oldcwd [pwd]
    cd  [file dirname [info script]]
    set libDir [pwd]
    cd $oldcwd

    # Based on the package directory, find and remember the nub file.
    # We prefer '.tcl' as extension, but also search for a variant
    # with extension '.tclnc'. The latter is present when the package
    # is wrapped. '.tclnc' is the chosen extension to prevent
    # compilation of tcl code during wrapping.

    foreach {f v} {
	nub nubFile
    } {
	::variable $v ; upvar 0 $v fname
	set fname {}
	foreach e {.tcl .tclnc} {
	    set fn [file join $libDir $f$e]
	    if {[file exists $fn]} {
		set fname $fn
		break
	    }
	}
	if {$fname == {}} {
	    return -code error "Unable to locate $f.tcl(nc), \
		    searched in directory \"$libDir\""
	}	
    }

    return
}

::nub::initialize


# ### ### ### ######### ######### #########
## Ready to go

package provide nub 1.0
