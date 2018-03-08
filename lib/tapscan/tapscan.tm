# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tapscan 0.1
# Meta platform    tcl
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ######### ###########################
## Scanning directories for packages,
## generation of tap files.

# ### ######### ###########################

namespace eval ::tapscan {}

# ### ######### ###########################

proc ::tapscan::isPkgDir {path} {
    set pi [file join $path pkgIndex.tcl]
    expr {
	[file isdirectory $path] &&
	[file exists $pi] &&
	[file isfile $pi]
    }
}

proc ::tapscan::listPackages {pkgdir} {
    # Assumes that 'isPkgDir(pkgdir)' was already checked. Returns a
    # dictionary of packages found, maps from package name to
    # version.
    #
    # LIMIT: Does not handle the possibility that one package is
    # listed multiple times in the index file, with different
    # versions. Whatever is listed last is taken.

    array set p {}

    set f [open [file join $pkgdir pkgIndex.tcl] r]
    foreach line [split [read $f] \n] {
	if { [regexp {#}        $line]} {continue}
	if {![regexp {ifneeded} $line]} {continue}

	regsub {^.*ifneeded }       $line {}   line
	regsub {([0-9]) \[.*$}      $line {\1} line
	regsub -all {[ 	][ 	]*} $line { }  line

	if {[catch {
	    foreach {n v} $line break
	}]} {
	    foreach {n v} [split $line] break
	}

	log::log debug "\t(($line))"
	log::log info  "| - Found $n ($v)"
	set p($n) $v
    }
    close $f
    return [array get p]
}

proc ::tapscan::listFiles {pkgdir} {
    # Assumes that 'isPkgDir(path)' was already checked. Returns a
    # list, containing a list of files, and a boolean flag, in this
    # order. The flag is set if binary files have been found.

    set paths {}
    set binary 0

    set leading [llength [file split $pkgdir]]

    foreach f [lsort [fileutil::find $pkgdir]] {
	# Ignore certain paths
	# - Directories
	# - Static libraries
	# - .tap files !

	if {[file isdirectory $f]} {continue}
	if {[regexp {\.a$} $f]}    {continue}
	if {[regexp {\.lib$} $f]}  {continue}
	if {[regexp {\.tap} $f]}   {continue}

	set f [fileutil::stripN $f $leading]

	# Modify other files, also determines platform

	if {
	    [regexp {\.so$}  $f] ||
	    [regexp {\.dll$} $f] ||
	    [regexp {\.sl$}  $f]
	} {
	    set binary 1
	}
	lappend paths $f
    }

    list $paths $binary
}

# ### ######### ###########################
## Ready for use
return
