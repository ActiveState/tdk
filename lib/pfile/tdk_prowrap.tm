# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tdk_prowrap 0.1
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

snit::type tdk_prowrap {
    variable tpf
    constructor {v} {
	set tpf [tdk_pf tpf {TclDevKit Wrapper} $v {
	    App/Code            1
	    App/Args            1
	    Files               1
	    System/Verbose      1
	    System/TempDir      1
	    Wrap/BaseExecutable 1
	    Wrap/Output         1
	    Wrap/TclLibraryDir  1
	    Wrap/Specification  1
	    Wrap/Compile/Tcl    1
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
