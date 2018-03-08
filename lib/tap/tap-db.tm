# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tap::db 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     pkg::mem
# Meta require     platform
# Meta require     pref
# Meta require     snit
# Meta require     tap::db::loader
# Meta require     tcldevkit::config
# Meta require     teapot::instance
# Meta require     teapot::version
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type handling a .tapcache directory. Cache of information
# about the existing .tap based packages found in the current
# installation.

# ### ### ### ######### ######### #########
## Requirements

package require log
package require logger            ; # Tracing
package require pkg::mem          ; # In-memory instance database
package require platform          ; # Identify system
package require pref              ; # Preference core package.
package require snit              ; # OO core
package require teapot::version   ; # Version handling
package require teapot::instance  ; # Instance handling
package require teapot::reference ; # Reference handling

# NOTE : This package does not care about preferences setup.
# .... : That has to be done by the application.

package require tcldevkit::config
package require tap::db::loader

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::tap::db
snit::type ::tap::db {
    # ### ### ### ######### ######### #########
    ## Validate a directory, see if it can be viewed as a TAP
    ## repository.

    typemethod valid {location mode message} {
	if {$mode ne "ro"} {
	    return -code error "Bad mode \"$mode\""
	}
	# Read-only mode for sure.
	if {![fileutil::test $location edr message "TAP Repository"]} {
	    return 0
	} elseif {![llength [TapsIn $location]]} {
	    set message "No .tap files present"
	    return 0
	}
	return 1
    }

    proc TapsIn {location} {
	return [glob -nocomplain -directory $location \
		    *.tap */*.tap]
    }

    # ### ### ### ######### ######### #########

    constructor {location} {
	set _location $location
	set loader [::tap::db::loader ${selfns}::loader $location]
	set db     [::pkg::mem        ${selfns}::db]
	return
    }

    # ### ### ### ######### ######### #########
    ## API needed by a repository wrapped around this database.

    delegate method get     to db
    delegate method findref to db
    delegate method list    to db

    method initialize {donecmd} {
	log::debug initialize
	::log::log debug initialize

	$self Init
	$self Scan [TapsIn $_location] $donecmd
	return
    }

    # ### ### ### ######### ######### #########

    method Init {} {
	log::debug Scan/Init
	::log::log debug Scan/Init
	$db clear
	return
    }

    method Scan {files donecmd} {
	if {![llength $files]} {
	    $self Done $donecmd
	    return
	}

	set file  [lindex $files 0]
	set files [lrange $files 1 end]
	after 0 [mymethod Scan $files $donecmd]

	if {![IsTapFile $file]}   {
	    log::debug "not-TAP $file (ignored)"
	    ::log::log debug "not-TAP $file (ignored)"
	    return
	}
	log::debug "TAP $file"
	::log::log debug "TAP $file"

	$self Process $file
	return
    }

    method Process {file} {
	log::debug "Scan/File $file"
	::log::log debug "Scan/File $file"

	# Note. As we clear the internal in-memory database at the
	# start of a scan this automatically takes care of .tap files
	# which were modified or deleted.

	if {[$loader process $file $_location results]} {
	    $self Store $results
	}
	return
    }

    method Done {donecmd} {
	log::debug Scan/Done
	::log::log debug Scan/Done
	eval $donecmd
	return
    }

    proc IsTapFile {f} {
	# Check that the type is correct. We ignore all files which
	# are not package definitions.

	if {![file isfile $f]} {
	    ::log::log debug "\tnot a file ($f)"
	    return 0
	}
	foreach {ok tool} [tcldevkit::config::Peek/2.0 $f] break
	::log::log debug "\tpeek = ($ok ($tool))"
	return [expr {
		      $ok &&
		      ($tool eq "TclDevKit TclApp PackageDefinition")
		  }]
    }

    # ### ### ### ######### ######### #########
    ## Storage backend for the loader.

    method Store {packages} {
	set counter 0
	array set map {}

	# Iteration 1, generate the package instances.

	foreach p $packages {

	    ::log::log debug "Package ($p)"

	    array set  d $p
	    set basename [Basename d]
	    FixVersion d

	    set isaprofile [expr {$d(see) ne ""}]
	    set etype [expr {$isaprofile ? "profile" : "package"}]

	    set map($counter) [teapot::instance::cons \
				   $etype $basename $d(version) \
				   [Arch $d(platform)]]
	    set name($basename) .
	    unset d

	    ::log::log debug "$counter ==> ($map($counter))"

	    incr counter
	}

	# Iteration 2, fill the database ...

	set counter 0
	foreach p $packages {
	    array set d $p

	    set instance   $map($counter)
	    set pname      [lindex $instance 1]

	    # Ignore really bad stuff in a .tap file
	    if {$pname eq ""} continue

	    set isaprofile [expr {$d(see) ne ""}]
	    if {$isaprofile} {
		foreach {re rn rv ra} $map($d(see)) break
		set require [::teapot::reference::cons $rn -version $rv -is $re]
	    } else {
		set require {}
	    }

	    set data [list \
			  $isaprofile \
			  $require \
			  [string trim $d(desc)] \
			  $d(filesList) \
			  $d(base)
		     ]

	    ::log::log debug "Enter $counter ==> ($instance) :: ($data)"

	    $db enter $instance
	    $db set $instance $data
	    unset d
	    incr counter
	}
	return
    }

    proc Basename {pv} {
	upvar 1 $pv data name name

	if {!$data(hidden)} {
	    return $data(name)
	} else {
	    # For hidden packages we generate a unique name from
	    # actual name, the file it comes from, and a serial
	    # number.

	    set basename [file rootname [file tail $data(source)]]$data(name)

	    if {[info exists name($basename)]} {
		set serial 0
		while {[info exists name($basename$serial)]} {
		    incr serial
		}
		append basename $serial
	    }
	    return $basename
	}
    }

    proc FixVersion {pv} {
	upvar 1 $pv data

	if {![teapot::version::valid $data(version)]} {
	    # Tap files can come with weird version numbers.
	    # Extract something sensible.

	    set data(version) [teapot::version::grok \
				   $data(version)]
	}
    }

    # The detail information in the destination codes is based on the
    # machine used to generate the old packages.
    typevariable carch -array {
	aix-rs6000		aix-powerpc
	aix-rs6000_64		aix-powerpc64
	hpux-ia64		hpux-ia64
	hpux-ia64_32		hpux-ia64_32
	hpux-parisc		hpux-parisc
	hpux-parisc64		hpux-parisc64
	linux-ia64		linux-glibc2.3-ia64
	linux-ix86		linux-glibc2.2-ix86
	linux-x86_64		linux-glibc2.3-x86_64
	macosx-ix86		macosx-ix86
	macosx-powerpc		macosx-powerpc
	macosx-universal	macosx-universal
	solaris-ix86		solaris2.10-ix86
	solaris-sparc		solaris2.6-sparc
	solaris-sparc-2.8	solaris2.8-sparc
	solaris-sparc64-2.8	solaris2.8-sparc64
	win32-ix86		win32-ix86
	win32-x86		win32-x86_64
	*			tcl
    }

    proc Arch {arch} {
	::variable carch

	# Convert the tap style platform identifier (* for tcl, os-cpu
	# identifier, old AS names) into a new-style identifier.

	if {[info exists carch($arch)]} {
	    return $carch($arch)
	}

	# Keep unchanged.
	return $arch
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable loader {} ; # object (tap::loader)
    variable db     {} ; # object (pkg::mem)

    variable _location {}

    ## Package database (generated from the processed definition
    ## files)

    variable name

    # name = array (name -> '.') - help when generating names.

    # //instance = list(name x version platform)

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
