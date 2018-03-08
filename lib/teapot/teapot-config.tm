# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::config 0.1
# Meta platform    tcl
# Meta require     pref::teapot
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Instances are mini-databases holding the information about the
## configuration of a local teapot application. Which archives
## to look at, the default installation repository.

## Configured with the path to the configuration area. That is chosen
## by the application.

# ### ### ### ######### ######### #########
## Requirements

package require snit            ; # OO core.
package require pref::teapot    ; # TEAPOT preferences.
package require repository::sys ; # TEAPOT system defaults

# ### ### ### ######### ######### #########
## Implementation

snit::type ::teapot::config {
    # ### ### ### ######### ######### #########
    ## API - Construction, get/set location of default installation
    ##       Add/remove archive locations.

    constructor {} {
	set defaulti   [pref::teapot::defaultInstallation]
	set archives   [pref::teapot::archivesList]
	set localcache [pref::teapot::localCache]
	set httpproxy  [pref::teapot::httpProxy]
	set timeout    [pref::teapot::timeout]
	set watchspace [pref::teapot::watchWorkspace]
	set watchdst   [pref::teapot::watchDestination]
	set watchlimit [pref::teapot::watchLimit]
	return
    }

    # ### ### ### ######### ######### #########
    ## API - Implementation.

    method {cache is active} {} {
	return [string length $localcache]
    }

    method {cache at} {dir} {
	set localcache           $dir
	pref::teapot::localCache $dir
	return
    }

    method {cache on} {} {
	# Standard location
	$self cache at [repository::sys::cachedir]
	return
    }

    method {cache off} {} {
	set localcache           {}
	pref::teapot::localCache {}
	# This does not clear existing files, nor stati
	return
    }

    method {cache clear} {} {
	# Delete all cached indices, and associated stati.

	if {$localcache eq ""} {
	    return -code error \
		"Unable to clear cache, location is unknown"
	}

	pref::teapot::lc/clear

	foreach f [glob -nocomplain -directory $localcache *] {
	    # Delete the directories and their contents.
	    file delete -force $f
	}

	return
    }

    method {cache list} {} {
	return [pref::teapot::lc/list]
    }

    method {cache is at} {} {
	return $localcache
    }

    method {cache path} {url} {
	if {$localcache eq ""} {return {}}
	array set u [uri::split $url]
	return [file join $localcache $u(host) $u(port)]
    }

    method {cache status?} {url} {
	return [pref::teapot::lc $url]
    }

    method {cache status} {url data} {
	pref::teapot::lc $url $data
	return
    }

    # ### ### ### ######### ######### #########

    method {default get} {} {
	return $defaulti
    }

    method {default set} {dir} {
	set defaulti    $dir
	pref::teapot::defaultInstallation $defaulti
	return
    }

    method {default setl} {dir} {
	set defaulti $dir
	return
    }

    method {default valid} {mode mv} {
	upvar 1 $mv message

	if {$defaulti eq ""} {
	    set message "Not defined. Please run 'setup'"
	    return 0
	}
	return [::repository::localma valid $defaulti $mode message]
    }

    # ### ### ### ######### ######### #########

    method archives {} {
	return $archives
    }

    method {archive clear} {{mode persistent}} {
	set archives {}
	if {$mode eq "persistent"} {
	    pref::teapot::archivesList $archives
	}
	return
    }

    method {archive has} {url} {
	set pos [lsearch -exact $archives $url]
	if {$pos >= 0} { return 1 }
	return 0
    }

    method {archive add} {url {mode persistent}} {
	set pos [lsearch -exact $archives $url]
	if {$pos >= 0} {
	    $self abortp "This repository is already known."
	}

	lappend archives $url
	if {$mode eq "persistent"} {
	    pref::teapot::archivesList $archives
	}
	return
    }

    method {archive remove} {url} {
	set pos [lsearch -exact $archives $url]
	if {$pos < 0} return

	set archives [lreplace $archives $pos $pos]
	pref::teapot::archivesList $archives
	return
    }

    # ### ### ### ######### ######### #########

    method {proxy get} {} {
	return [split $httpproxy :]
    }

    method {proxy set} {host port} {
	set httpproxy           ${host}:$port
	pref::teapot::httpProxy $httpproxy
    }

    method {proxy user set} {host port} {
	set httpproxy           ${host}:$port
	return
    }

    # ### ### ### ######### ######### #########

    method {timeout get} {} {
	return $timeout
    }

    method {timeout set} {seconds} {
	set timeout           $seconds
	pref::teapot::timeout $seconds
    }

    method {timeout user set} {seconds} {
	set timeout           $seconds
	return
    }

    # ### ### ### ######### ######### #########

    method {watch workspace get} {}  { return $watchspace }

    method {watch workspace set} {d} {
	set watchspace               $d
	pref::teapot::watchWorkspace $d
	return
    }

    method {watch workspace user set} {d} {
	set watchspace $d
	return
    }

    method {watch destination get} {}  { return $watchdst }

    method {watch destination set} {d} {
	set watchdst                   $d
	pref::teapot::watchDestination $d
	return
    }

    method {watch destination user set} {d} {
	set watchdst $d
	return
    }

    method {watch limit get} {}  { return $watchlimit }

    method {watch limit set} {d} {
	set watchlimit           $d
	pref::teapot::watchLimit $d
	return
    }

    # ### ### ### ######### ######### #########
    ## Reporting of user errors.

    variable onabort {}

    method onAbort {cmd} {
	set     onabort $cmd
	return
    }

    method abortp {text} {
	$self abort [textutil::indent \
			 [textutil::adjust \
			      $text \
			      -length 64] \
			 \t]
    }

    method abort {text} {
	uplevel \#0 [linsert $onabort end $text]
	return -code error "Abort handler does not exit!"
    }

    # ### ### ### ######### ######### #########
    ## Data structures

    variable defaulti   {}
    variable archives   {}
    variable localcache {}
    variable httpproxy  {}
    variable timeout    {}
    variable watchspace {}
    variable watchdst   {}
    variable watchlimit {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
