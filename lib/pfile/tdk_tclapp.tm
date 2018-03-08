# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tdk_tclapp 0.1
# Meta platform    tcl
# Meta require     snit
# Meta require     tdk_pf
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# Generic reading and writing files in {Tcl Dev Kit Project File} format.
# (c) 2003-2007 ActiveState Software Inc.

# ----------------------------------------------------
# Prerequisites

package require snit
package require tdk_pf

# ----------------------------------------------------
# Interface & Implementation

snit::type tdk_tclapp {
    variable tpf
    constructor {v} {
	set tpf [tdk_pf tpf {TclDevKit TclApp} $v {
	    App/Argument           1
	    App/Code               1
	    App/PostCode           1
	    App/Package            1
	    Encoding               1
	    Metadata               1
	    OSX/Info.plist         1
	    Package                1
	    Path                   1
	    Pkg/Architecture       1
	    Pkg/Archive            1
	    Pkg/Instance           1
	    Pkg/Path               1
	    Pkg/Reference          1
	    StringInfo             1
	    System/Nocompress      1
	    System/TempDir         1
	    System/Verbose         1
	    Wrap/Compile/NoTbcload 1
	    Wrap/Compile/Tcl       1
	    Wrap/Compile/Version   1
	    Wrap/FSMode            1
	    Wrap/Icon              1
	    Wrap/InputPrefix       1
	    Wrap/Interpreter       1
	    Wrap/Merge             1
	    Wrap/NoProvided        1
	    Wrap/NoSpecials        1
	    Wrap/Output            1
	    Wrap/Output/OSXApp     1
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
