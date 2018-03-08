# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the index for the packages which comprise
#	the low-level debugger (ui independent engine (backend of
#	frontend), instrumntation and utilities).
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

# ### ### ### ######### ######### #########
## User visible packages

package ifneeded engine     0.1 [list source [file join $dir engine.tcl]]
package ifneeded instrument 1.0 [list source [file join $dir instrument.tcl]]
package ifneeded loc        1.0 [list source [file join $dir location.tcl]]
package ifneeded pdx        1.0 [list source [file join $dir pdx.tcl]]

# ### ### ### ######### ######### #########
## Internal packages

package ifneeded dbgtalk  0.1 [list source [file join $dir dbg.tcl]]
package ifneeded breakdb  1.0 [list source [file join $dir break.tcl]]
package ifneeded blk      1.0 [list source [file join $dir block.tcl]]
package ifneeded filedb   1.0 [list source [file join $dir file.tcl]]
package ifneeded util     1.0 [list source [file join $dir util.tcl]]

# ### ### ### ######### ######### #########
