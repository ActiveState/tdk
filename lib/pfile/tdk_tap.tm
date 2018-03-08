# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tdk_tap 0.1
# Meta platform    tcl
# Meta require     snit
# Meta require     tdk_pf
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# Generic reading and writing files in {Tcl Dev Kit Project File} format.
# (c) 2003-2006 ActiveState Software Inc.

# ----------------------------------------------------
# Prerequisites

package require snit
package require tdk_pf

# ----------------------------------------------------
# Interface & Implementation

snit::type tdk_tap {
    variable tpf
    constructor {v} {
	set tpf [tdk_pf tpf {TclDevKit TclApp PackageDefinition} $v {
	    See         1
	    Desc        1
	    Package     1
	    Base        1
	    Alias       1
	    Platform    1
	    Path        1
	    Hidden       0
	    Hidden       1
	    ExcludePath 1
	}] ;# {}
    }
    destructor {
	$tpf destroy
    }

    # ------------------------------------------------

    delegate method * to tpf
}

# ----------------------------------------------------
# Ready to go ...
return
