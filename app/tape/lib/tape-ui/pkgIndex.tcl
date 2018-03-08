# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the package index for the Tap Editor UI.
#	Assumes that all files, even shared code is in the same directory.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

package ifneeded tcldevkit::tape               2.1 [list source [file join $dir tape.tcl]]
package ifneeded tcldevkit::tape::fileWidget   2.0 [list source [file join $dir fileWidget.tcl]]
package ifneeded tcldevkit::tape::descWidget   2.0 [list source [file join $dir descWidget.tcl]]
package ifneeded tcldevkit::tape::pkgDisplay   2.0 [list source [file join $dir pkgdisplay.tcl]]

package ifneeded tcldevkit::teapot::fileWidget 1.0 [list source [file join $dir potFileWidget.tcl]]
package ifneeded tcldevkit::teapot::descWidget 1.0 [list source [file join $dir potDescWidget.tcl]]
package ifneeded tcldevkit::teapot::indxWidget 1.0 [list source [file join $dir potIndxWidget.tcl]]
package ifneeded tcldevkit::teapot::depsWidget 1.0 [list source [file join $dir potDepsWidget.tcl]]
package ifneeded tcldevkit::teapot::mdWidget   1.0 [list source [file join $dir potMD.tcl]]
package ifneeded tcldevkit::teapot::pkgDisplay 1.0 [list source [file join $dir potPkgdisplay.tcl]]

