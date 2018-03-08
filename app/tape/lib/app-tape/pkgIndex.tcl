# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the package index for the Tape application
#	Assumes that all files, even shared code is in the same directory.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

#puts ....................................................................................

# Main / UI / Application package
package ifneeded app-tape     1.0 [list source [file join $dir tape_startup.tcl]]

# UI state - TAP information
package ifneeded tape::state  1.0 [list source [file join $dir tape_state.tcl]]

# UI state - TEAPOT information
package ifneeded tape::teapot 1.0 [list source [file join $dir tape_pot.tcl]]
