# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the package index for the Tcl Wrapper UI.
#	Assumes that all files, even shared code is in the same directory.
#
# Copyright (c) 2003-2009 ActiveState Software Inc.
# All rights reserved.
#
# RCS: @(#) $Id: $

package ifneeded splash 1.3 [list source [file join $dir splash.tcl]]
