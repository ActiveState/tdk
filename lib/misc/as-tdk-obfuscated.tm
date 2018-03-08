# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package as::tdk::obfuscated 0.1
# Meta platform        tcl
# Meta require         fileutil
# Meta description     This package checks files if they contain Tcl bytecode
# Meta description     usable by tbcload. If yes, and asked for, it provides
# Meta description     the version of tbcload, and of the Tcl core the bytecode
# Meta description     is for.
# @@ Meta End

# -*- tcl -*-
# Copyright (c) 2009 ActiveState Software Inc.
#               Tools & Languages
# $Id$
# --------------------------------------------------------------

# Check a file if it is obfuscated (tcl bytecoded, usable by tbcload),
# and if yes, for which version of the Tcl core.

package require fileutil

# --------------------------------------------------------------

namespace eval ::as::tdk::obfuscated {}

# --------------------------------------------------------------

proc ::as::tdk::obfuscated::is {path {cv {}}} {
    set state wait-bceval
    foreach line [split [fileutil::cat $path] \n] {
	switch -exact -- $state {
	    wait-bceval {
		if {![string match {*tbcload::bceval*} $line]} continue
		set state expect-tclpro
	    }
	    expect-tclpro {
		if {![string match {*TclPro ByteCode*} $line]} {
		    set state wait-bceval
		    continue
		}

		# We have now found the combination of
		# tbcload::bceval <
		# TclPro ByteCode x y version tcl-version

		# The file is obfuscated for use by tbcload, for a
		# specific tcl core.

		if {$cv ne {}} {
		    upvar 1 $cv versions
		    foreach {_ _ _ _ v tclv} [split $line { }] break
		    set versions [list $v $tclv]
		}
		return 1
	    }
	}
    }

    # Nothing was found relating to tbcload ...
    return 0
}

# --------------------------------------------------------------
return
