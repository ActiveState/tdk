# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the package index for the Tcl Debugger.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

# We need to load two files.  debugger.tcl has the main code,
# but system.tcl has some support routines needed very early
# in the case that we need to launch the license manager.

# ### ### ### ######### ######### #########
## Main package

package ifneeded debugger 1.5 [list source [file join $dir debugger.tcl]]

# ### ### ### ######### ######### #########
## Sort of backend packages

# preferences - moved outside into separate package
package ifneeded system     1.0 [list source [file join $dir system.tcl]]

# ### ### ### ######### ######### #########
## UI packages.

package ifneeded fmttext    1.0 [list source [file join $dir fmttext.tcl]]
package ifneeded gui        1.0 [list source [file join $dir gui.tcl]]
package ifneeded ui_engine  0.1 [list source [file join $dir ui_engine.tcl]]
package ifneeded stack      1.0 [list source [file join $dir stackWin.tcl]]
package ifneeded connstatus 1.0 [list source [file join $dir connstatus.tcl]]
package ifneeded deferror   1.0 [list source [file join $dir deferror.tcl]]
package ifneeded parseerror 1.0 [list source [file join $dir parseerror.tcl]]
package ifneeded rterror    1.0 [list source [file join $dir rterror.tcl]]
package ifneeded codeWin    1.0 [list source [file join $dir codeWin.tcl]]
package ifneeded icon       1.0 [list source [file join $dir icon.tcl]]
package ifneeded bp         1.0 [list source [file join $dir breakWin.tcl]]
package ifneeded checker_bridge 1.0 [list source [file join $dir checker.tcl]]
package ifneeded checkWin   1.0 [list source [file join $dir checkWin.tcl]]
package ifneeded coverage   1.0 [list source [file join $dir coverage.tcl]]
package ifneeded tkCon      1.0 [list source [file join $dir tkcon.tcl]]
package ifneeded evalWin    1.0 [list source [file join $dir evalWin.tcl]]
package ifneeded inspector  1.0 [list source [file join $dir inspectorWin.tcl]]
package ifneeded procWin    1.0 [list source [file join $dir procWin.tcl]]
package ifneeded portWin    1.0 [list source [file join $dir portWin.tcl]]
package ifneeded proj       1.0 [list source [file join $dir proj.tcl]]
package ifneeded projWin    1.0 [list source [file join $dir projWin.tcl]]
package ifneeded goto       1.0 [list source [file join $dir goto.tcl]]
package ifneeded find       1.0 [list source [file join $dir find.tcl]]
package ifneeded var        1.0 [list source [file join $dir varWin.tcl]]
package ifneeded watch      1.0 [list source [file join $dir watchWin.tcl]]
package ifneeded transform  0.1 [list source [file join $dir transform.tcl]]
package ifneeded varCache   0.1 [list source [file join $dir varCache.tcl]]
package ifneeded varAttr    0.1 [list source [file join $dir varAttr.tcl]]
package ifneeded transMenu  0.1 [list source [file join $dir transMenu.tcl]]
package ifneeded varDisplay 0.1 [list source [file join $dir varDisplay.tcl]]
package ifneeded icolist    0.1 [list source [file join $dir icolist.tcl]]
