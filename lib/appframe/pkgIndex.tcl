# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

package ifneeded tcldevkit::tk       1.0 [list source [file join $dir check_tk.tcl]]
package ifneeded tcldevkit::appframe 1.0 [list source [file join $dir appframe.tcl]]
package ifneeded tcldevkit::config   2.0 [list source [file join $dir config.tcl]]
