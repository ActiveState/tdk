# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the package index for the TclApp application
#	Assumes that all files, even shared code is in the same directory.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

#puts ....................................................................................

# Main / UI / Application package
package ifneeded app-tclapp 1.0 [list source [file join $dir tclapp_startup.tcl]]

package ifneeded tclapp::pkg::scan 1.0 [list source [file join $dir pscan.tcl]]

# Starkit 2 Starpack converter, splitter, vacuum (genpak)
package ifneeded tclapp::genpak 1.1 [list source [file join $dir genpak.tcl]]
