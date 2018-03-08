# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
# Helper index. For a debugger started directly out of the local
# repository we use the standard nub. If a magical variable exists
# this file routes to the mobius nub instead. This allows the mobius
# debugger to be tested from inside the repository as well.
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
# All rights reserved.
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

set maindir $dir

if {[info exists ::mobius_magic_routing]} {
    set dir [file join $maindir mobius]
} else {
    set dir [file join $maindir standard]
}

source [file join $dir pkgIndex.tcl]
