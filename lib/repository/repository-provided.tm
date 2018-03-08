# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::provided 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     fileutil::traverse
# Meta require     iter
# Meta require     logger
# Meta require     teapot::version
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Standard code to determine the set of packages provided by a
# directory hierarchy. This code provides only a basic set of
# information, based on what is found in pkgIndex.tcl files. There is
# no architecture data for example.

# ### ### ### ######### ######### #########
## Requirements

package require logger             ; # Tracing setup
package require fileutil           ; # Directory traversal (sync)
package require fileutil::traverse ; # Directory traversal
package require iter               ; # Generic event-driven iterator
package require teapot::version

logger::initNamespace ::repository::provided
namespace eval        ::repository::provided {}

# ### ### ### ######### ######### #########
## Implementation - Async scanning

proc ::repository::provided::scan/async {dir troublecmd initcmd pkgcmd donecmd} {
    set base [file normalize $dir]
    iter %AUTO% [fileutil::traverse %AUTO% $base \
		     -filter ::repository::provided::scan/async/filter] \
	-init $initcmd \
	-done $donecmd \
	-per  [list ::repository::provided::scan/async/per \
		   $pkgcmd $troublecmd $dir $base]
    return
}

proc ::repository::provided::scan/async/filter {path} {
    # Only package indices are valid
    return [string match *pkgIndex.tcl $path]
}

proc ::repository::provided::scan/async/per {pkgcmd troublecmd dir base statevar indexFile} {
    upvar 1 $statevar state

    # Process the found index, and determine which packages it
    # provides. We use a heuristic parser for the extraction. It
    # attacks the Tcl code via regular expressions and other string
    # operations.

    set indexScript [fileutil::cat $indexFile]

    set packages      {}
    set foundproblems 0

    RecordProblems \
	$dir [fileutil::stripPath $base $indexFile] \
	foundproblems problemreport \
	[ParseIndexScript $indexScript packages]

    if {$foundproblems} {
	foreach l $problemreport {
	    eval [linsert $troublecmd end $l]
	}
    }

    foreach {name version} $packages {
	# eval, not uplevel, to allow access to the state.
	eval [linsert $pkgcmd end state $name $version]
    }

    return
}

# ### ### ### ######### ######### #########
## Implementation - Sync scanning

proc ::repository::provided::scan {dir rv} {
    upvar 1 $rv problemreport

    log::debug "repository::provided::scan ($dir)"

    # Scan the specified directory for "pkgIndex.tcl" files, i.e.
    # package indices. After that we will scan their contents to
    # determine which packages they provide.

    set indices {}
    set base  [file normalize $dir]
    foreach f [fileutil::findByPattern $base *pkgIndex.tcl] {
	lappend indices $f [fileutil::cat $f]
    }

    # Process the found indices, and determine which packages they
    # provide. We use a heuristic parser for the extraction. It
    # attacks the Tcl code via regular expressions and other string
    # operations.

    set packages      {}
    set foundproblems 0

    foreach {indexFile indexScript} $indices {
	RecordProblems \
	    $dir [fileutil::stripPath $base $indexFile] \
	    foundproblems problemreport \
	    [ParseIndexScript $indexScript packages]
    }

    if {$foundproblems} {
	lappend problemreport " "
    }

    # problemreport = list (textline ...)
    # result        = dict (package_name -> package_version)
    return $packages
}

proc ::repository::provided::RecordProblems {dir indexFile fv rv problems} {
    upvar 1 $fv foundproblems $rv problemreport

    if {[llength $problems]} {
	if {!$foundproblems} {
	    lappend problemreport " "
	    lappend problemreport "Problems found while looking for packages provided by the"
	    lappend problemreport "directory \"$dir\"."
	    set foundproblems 1
	}

	lappend problemreport " "
	lappend problemreport "* In file \"$indexFile\":"

	foreach e $problems {
	    lappend problemreport "  $e"
	}
    }

    return
}

proc ::repository::provided::ParseIndexScript {indexScript pvar} {
    upvar 1 $pvar packages

    # Heuristic parsing of the index script.

    # FUTURE ? Use something tclchecker based for proper parsing and
    # scanning of the code ? Not sure if this would be truly required
    # because although hackish the code below handles all the indices
    # I found in ActiveTcl without problems.

    # Ignore comment lines, and lines without the 'ifneeded' keyword
    # (from 'package ifneeded'). Remove everything before the
    # 'ifneeded' keyword, and the keyword from the line. Then cut
    # everything after a digit followed by an opening bracket, brace
    # or double apostroph. That is the last digit of the version
    # number, followed by the provide command. Now treat the line as
    # list, and its two elements are package name and version.

    set found 0
    set problems {}

    foreach line [split $indexScript \n] {
	if { [regexp "#"        $line]} {continue}
	if {![regexp {ifneeded} $line]} {continue}

	set xline $line
	regsub {^.*ifneeded }             $line {}   line
	regsub -all {[ 	]+}               $line { }  line
	regsub "(\[0-9\]) \[\{\[\"\].*\$" $line {\1} line

	if {[catch {
	    foreach {p v} $line break
	} msg]} {
	    lappend problems "General parser failure in line"
	    lappend problems "'$xline'"
	    lappend problems "Error message: $msg"
	    lappend problems "for string '$line'"
	    continue
	} elseif {![teapot::version::valid $v msg]} {
	    lappend problems "Bad version number \"$v\" in line"
	    lappend problems "'$xline'"
	    continue
	}

	lappend packages $p $v
	incr found
    }

    if {!$found} {
	lappend problems "No packages found"
    }

    return $problems
}

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::repository::provided {
    logger::init                              repository::provided
    logger::import -force -all -namespace log repository::provided
}

# ### ### ### ######### ######### #########
## Ready
return
