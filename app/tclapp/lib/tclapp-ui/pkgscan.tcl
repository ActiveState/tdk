# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgscan.tcl --
# -*- tcl -*-
#

#	Handle external application scanning a set of
#	files for 'package require' statements.

#	Future: Put the core of this into a package
#	directly accessible to us.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.
#               [Coming out of the fileWidget]
#
# RCS: @(#) $Id:$

# ### ### ### ######### ######### #########
## Docs

# ### ### ### ######### ######### #########
## Requisites

package require snit            ; # Tcllib, OO core.
package require logger          ; # Standard tracing
package require fileutil
package require tlocate

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::pkgman::scanfiles
snit::type ::pkgman::scanfiles {
    # ### ### ### ######### ######### #########
    ## API. Definition

    # ### ### ### ######### ######### #########
    ## API. Implementation

    constructor {files pkgcmd donecmd} {
	set _donecmd $donecmd
	set _pkgcmd  $pkgcmd

	after idle [mymethod Start $files]
	return
    }

    destructor {
	return
    }

    # ### ### ### ######### ######### #########

    method Start {files} {
	set application [$type LocateChecker]

	if {$application eq ""} {
	    $self Done 1 "Tclchecker not found"
	    return
	}

	# Note: files is a list of glob patterns.  Expand into a list
	# of files here, the checker will not do it for us.

	# Also, use the -@ syntax of the checker to prevent the
	# creation of an overly long command line for the pipe. Like
	# xref does already.

	set f {}
	foreach p $files {
	    foreach path [glob -nocomplain $p] {
		lappend f $path
	    }
	}

	if {![llength $f]} {
	    $self Done 1 {No files found to scan}
	    return
	}

	set tmp [fileutil::tempfile]
	fileutil::writeFile $tmp [join $f \n]\n

	set cmd [linsert $application end -packages -ping -@ $tmp]

	set         pipe [open |$cmd r+]
	fconfigure $pipe -blocking 0
	fileevent  $pipe readable \
	    [mymethod Next $pipe $tmp]

	return
    }

    method Next {pipe tmp} {
	if {[eof $pipe]} {
	    close $pipe
	    file delete -force $tmp
	    $self Done 0 {}
	    return
	}

	if {[gets $pipe line] < 0} return
	set line [string trim $line]

	if {$line eq ""} return

	if {$line eq "ping"} {
	    incr _pings
	    if {$_pings < 10} return
	    set _pings 0
	    ::tcldevkit::appframe::feednext
	    return
	}

	foreach {__ __ name version} $line break
	set ref [list $name]
	if {$version ne ""} {lappend ref -version $version}

	$self Package $ref
	return
    }

    method Done {code msg} {
	eval [linsert $_donecmd end $code $msg]

	# auto-destruction
	$self destroy
	return
    }

    method Package {ref} {
	eval [linsert $_pkgcmd end $ref]
	return
    }

    # ### ### ### ######### ######### #########

    typevariable checker {}

    typemethod LocateChecker {} {

	if {$checker ne ""} {return $checker}

	set checker [tlocate::find tclchecker]

	return $checker
    }

    # ### ### ### ######### ######### #########
    ## 

    variable _donecmd
    variable _pkgcmd
    variable _pings 0

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide pkgman::scanfiles 1.0
