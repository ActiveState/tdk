# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the package index for the Tcl Compiler UI.
#	Assumes that all files, even shared code is in the same directory.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

foreach {pkg version file} {
    tcldevkit::compiler::optionWidget 2.0  optionWidget
    tcldevkit::compiler::fileWidget   2.0  fileWidget
    tcldevkit::compiler               2.0  compiler
} {
    package ifneeded $pkg $version [list source [file join $dir $file.tcl]]
}
