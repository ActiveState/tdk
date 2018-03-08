# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tap::db::paths 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     pref::devkit
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Helper type for the tap cache. Management of search paths in memory.

# ### ### ### ######### ######### #########
## Requirements

package require logger       ; # Tracing
package require snit         ; # OO core
package require pref::devkit ; # TDK preferences

# NOTE : This package does not care about preferences setup.
# .... : That has to be done by the application.

# ### ### ### ######### ######### #########
## Implementation

snit::type ::tap::db::paths {

    # Determine the list of paths to search for package definitions in
    # .tap files.

    constructor {theinstalldir} {
	set installdir $theinstalldir
	return
    }

    # result = dict (search path -> base directory)

    method get {} {
	# Compute path list on first call, and whenever the
	# preferences changed. Otherwise we can use the list we have
	# cached in memory.

	if {!$initialized} {
	    set prefs [getPrefs]
	    set paths [Compose $installdir $prefs]
	    set initialized 1
	    return $paths
	}

	set newprefs [getPrefs]

	if {$prefs ne $newprefs} {
	    set prefs $newprefs
	    set paths [Compose $installdir $prefs]
	}

	return $paths
    }

    proc Compose {installdir prefs} {
	global env auto_path tcl_pkgPath tcl_platform

	# Initial set of paths ...  First the TDK installation itself,
	# then preferences, at last the environment.

	set     paths [list]
	lappend paths [file join $installdir lib]

	foreach p $prefs {
	    lappend paths $p
	}

	if {[info exists env(TCLAPP_PKGPATH)]} {
	    if {$tcl_platform(platform) eq "windows"} {
		eval lappend paths [split $env(TCLAPP_PKGPATH) ;]
	    } else {
		eval lappend paths [split $env(TCLAPP_PKGPATH) :]
	    }
	}

	# Remove duplicates, do not disturb the order of paths.
	# Normalize the paths on the way

	set res [list]
	array set _ {}
	foreach p $paths {
	    set p [file normalize $p]
	    if {[info exists _($p)]} {continue}
	    lappend res $p
	    set _($p) .
	}
	set paths $res
	unset _

	# Add subdirectories of the search paths to the search to.
	# (Only one level).

	# We also associate each directory with the base directory
	# from the original list of search paths. These base paths are
	# now the anchors for TDK_LIBDIR expansion. The data added
	# here is passed through to the code loading and parsing
	# package definitions. There it is used for the mentioned
	# substitution.

	foreach p $paths {
	    log::debug "Master: $p"
	}

	set res [list]
	foreach p $paths {
	    lappend res $p $p
	    set sub [glob -nocomplain -types d -directory $p *]
	    if {[llength $sub] > 0} {
		foreach s $sub {
		    lappend res $s $p
		}
	    }
	}

	# Expansion complete.

	foreach {p master} $res {
	    log::debug "Search: $p"
	}

	# result = dict (search path -> base directory)
	return $res
    }

    proc getPrefs {} {
	if {[catch {
	    set prefs [pref::devkit::pkgSearchPathList]
	}]} {
	    return {}
	}
	return $prefs
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    # installdir  = path
    # initialized = boolean
    # paths       = dict (path 'search path' -> path 'base directory')
    # prefs       = list (path ...)

    variable installdir {}
    variable initialized 0 ; # Flag if stored data is initialized.
    variable paths      {} ; # Stored list of search paths
    variable prefs      {} ; # Copy of preferences to allow detection of changes.

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::tap::db::paths {
    logger::init                              tap::db::paths
    logger::import -force -all -namespace log tap::db::paths
}

# ### ### ### ######### ######### #########
## Ready
return
