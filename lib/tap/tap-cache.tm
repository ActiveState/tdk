# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tap::cache 0.1
# Meta platform    tcl
# Meta require     snit
# Meta require     tap::db::files
# Meta require     tap::db::loader
# Meta require     tcldevkit::config
# Meta require     tie
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type handling a .tapcache directory. Cache of informaiton
# about the existing .tap based packages found in the current
# installation.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require tie

# NOTE : This package does not care about preferences setup.
# .... : That has to be done by the application.

package require tcldevkit::config

package require tap::db::files
package require tap::db::loader


# ### ### ### ######### ######### #########
## Implementation

snit::type ::tap::cache {

    constructor {installdir} {
	# Setup of package mapping, zip files, etc.

	log::debug "$self new ($installdir)"

	set tapcache [file join $installdir .tapcache]
	if {![file exists $tapcache]} {
	    set usecache [expr {![catch {file mkdir $tapcache}]}]

	    log::debug "Create cache $tapcache ..."
	    log::debug [expr {$usecache ?
			      "Ok.     Using." :
			      "Failed. Not using."}]

	} else {
	    set usecache [expr {
		[file isdirectory $tapcache] &&
		[file readable $tapcache] &&
		[file writable $tapcache]
	    }]

	    log::debug [expr {$usecache ?
			      "Using good cache $tapcache." :
			      "Not using bad cache $tapcache."}]
	}
	return
    }

    method ok {} {return $usecache}

    method put {instance file} {
	log::debug "$self put ($instance) : $file"

	if {!$usecache} return

	set fname Z.[join $instance -]

	file copy -force $file [file join $tapcache $fname]
	return
    }

    method get {instance file} {
	log::debug "$self get ($instance) : $file"

	if {!$usecache} {
	    return -code error "Cache is not usable"
	}

	set fname Z.[join $instance -]
	file copy -force [file join $tapcache $fname] $file
	return
    }

    method has {instance} {
	if {!$usecache} {return 0}
	set fname Z.[join $instance -]
	return [file exists [file join $tapcache $fname]]
    }

    method path {instance} {
	set fname Z.[join $instance -]
	return [file join $tapcache $fname]
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable tapcache
    variable usecache

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::tap::cache {
    logger::init                              tap::cache
    logger::import -force -all -namespace log tap::cache
}

# ### ### ### ######### ######### #########
## Ready
return
