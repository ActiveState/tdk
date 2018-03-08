# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tap::db::files 0.1
# Meta platform    tcl
# Meta require     jobs::async
# Meta require     logger
# Meta require     snit
# Meta require     tap::db::paths
# Meta require     tcldevkit::config
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Helper type for the tap cache. Management of package definition
# files aka .tap files.

# ### ### ### ######### ######### #########
## Requirements

package require logger
package require snit
package require tap::db::paths
package require tcldevkit::config
package require jobs::async

# ### ### ### ######### ######### #########
## Implementation

snit::type ::tap::db::files {

    constructor {installdir} {
	set sp [::tap::db::paths ${selfns}::paths $installdir]
	return
    }

    method master {f} {
	return [lindex $fd($f) 1]
    }

    method get/all {} {
	log::debug get/all

	set initialized 1
	$self ScanForAll
	return [array names fd]
    }

    method get/new {} {
	log::debug get/new

	if {!$initialized} {
	    set initialized 1
	    $self ScanForAll
	    return [array names fd]
	}

	set initialized 1
	$self ScanForChanged new
	return              $new
    }

    method get/all/async {initcmd filecmd donecmd} {
	log::debug get/all/async

	$self ScanForAll/Async $initcmd $filecmd \
	    [mymethod ScanDone $donecmd]
	return
    }

    method get/new/async {initcmd filecmd donecmd} {
	log::debug get/new

	if {!$initialized} {
	    $self ScanForAll/Async $initcmd $filecmd \
		[mymethod ScanDone $donecmd]
	    return
	}

	$self ScanForChanged/Async \
	    $initcmd $filecmd \
	    [mymethod ScanDone $donecmd]
	return
    }

    method ScanDone {donecmd} {
	log::debug ScanDone\ ($donecmd)

	set initialized 1
	eval $donecmd
	return
    }

    # ### ### ### ######### ######### #########
    ## Implementation

    method ScanForAll {} {
	foreach {path master} [$sp get] {
	    foreach f [FindPackageDefinitions $path] {
		set fd($f) [list [file mtime $f] $master]
	    }
	}
	return
    }

    method ScanForAll/Async {initcmd filecmd donecmd} {
	log::debug ScanForAll/Async

	eval $initcmd

	# Retrieval of the paths to search is done sync, this is
	# quick. The loop over Find will start the jobs in parallel.

	set j [jobs::async %AUTO% [mymethod Find/Async $filecmd]]

	foreach {path master} [$sp get] {
	    $j add [list check $path $master]
	}
	$j add [list done $j $donecmd]
	return
    }

    method Find/Async {filecmd task} {
	log::debug "Find/Async $task"

	foreach {what a b} $task break
	if {$what eq "done"} {
	    after idle [list $a destroy] ; # the job queue
	    eval $b    ; # Run the callers donecmd
	    return
	}
	# a = path, b = master
	set path   $a
	set master $b

	log::debug "Check/Async: $path"

	# !FUTURE! This can be done in terms of a event-driven
	# !FUTURE! traversal as well, with proper filter and
	# !FUTURE! prefilter commands.

	foreach ext {tap tpj tdk} {
	    set files [::glob -nocomplain -types {f l} -directory $path *.$ext]
	    foreach f $files {
		if {![IsTapFile $f]} continue

		log::debug "TAP $f"

		set fd($f) [list [file mtime $f] $master]

		eval [linsert $filecmd end $f]
	    }
	}
	return
    }

    method ScanForChanged {{nv {}}} {
	if {$nv ne ""} {upvar 1 $nv new}

	set new {}
	foreach {path master} [$sp get] {
	    foreach f [FindPackageDefinitions $path] {
		if {
		    ![info exists fd($f)] ||
		    ([file mtime $f] > [lindex $fd($f) 0])
		} {
		    set fd($f) [list [file mtime $f] $master]
		    lappend new $f
		}
	    }
	}
	return
    }

    method ScanForChanged/Async {initcmd filecmd donecmd} {

	log::debug ScanForChanged/Async

	eval $initcmd

	# Retrieval of the paths to search is done sync, this is
	# quick. The loop over Find will start the jobs in parallel.

	set j [jobs::async %AUTO% [mymethod Find/Changed/Async $filecmd]]

	foreach {path master} [$sp get] {
	    $j add [list check $path $master]
	}
	$j add [list done $j $donecmd]
	return
    }

    method Find/Changed/Async {filecmd task} {
	log::debug "Find/Changed/Async $task"

	foreach {what a b} $task break
	if {$what eq "done"} {
	    after idle [list $a destroy] ; # the job queue
	    eval $b    ; # Run the callers donecmd
	    return
	}
	# a = path, b = master
	set path   $a
	set master $b

	log::debug "Check/Async: $path"

	foreach ext {tap tpj tdk} {
	    set files [::glob -nocomplain -types {f l} -directory $path *.$ext]
	    foreach f $files {
		if {![IsTapFile $f]} continue

		log::debug "TAP $f"

		if {
		    ![info exists fd($f)] ||
		    ([file mtime $f] > [lindex $fd($f) 0])
		} {
		    set fd($f) [list [file mtime $f] $master]

		    eval [linsert $filecmd end $f]
		}
	    }
	}
	return
    }

    proc FindPackageDefinitions {path} {
	# This commands finds files which may contain package
	# definitions.

	log::debug "Check: $path"

	set res [list]
	foreach ext {tap tpj tdk} {
	    set files [::glob -nocomplain -types {f l} -directory $path *.$ext]
	    foreach f $files {
		if {![IsTapFile $f]} continue

		log::debug "TAP $f"

		lappend res $f
	    }
	}
	return $res
    }

    proc IsTapFile {f} {
	# Check that the type is correct. We ignore all files which
	# are not package definitions.

	if {![file isfile $f]} {
	    return 0
	}
	foreach {ok tool} [tcldevkit::config::Peek/2.0 $f] break
	return [expr {
		      $ok &&
		      ($tool eq "TclDevKit TclApp PackageDefinition")
		  }]
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable initialized 0
    variable fd
    variable sp

    # initialized = boolean
    # fd          = array (path -> list(mtime path 'master'))
    # sp          = object (search paths)

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::tap::db::files {
    logger::init                              tap::db::files
    logger::import -force -all -namespace log tap::db::files
}

# ### ### ### ######### ######### #########
## Ready
return
