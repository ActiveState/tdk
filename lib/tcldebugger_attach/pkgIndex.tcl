# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	Package index for remote attachment to prodebug.
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

# ### ######### ###########################

package ifneeded tcldebugger_attach 1.4 [list source [file join $dir attach.tcl]]

# ### ######### ###########################
