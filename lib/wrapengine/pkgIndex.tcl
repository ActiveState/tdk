# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the package index for the TclApp support packages
#	Assumes that all files, even shared code is in the same directory.
#
# Copyright (c) 2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

#puts ....................................................................................

# Engine, Highlevel
package ifneeded tclapp 1.0 [list source [file join $dir tclapp.tcl]]

# Message facility
package ifneeded tclapp::msgs 1.0 [list source [file join $dir tclapp_msgs.tcl]]

# Handle temp directory
package ifneeded tclapp::tmp 1.0 [list source [file join $dir tclapp_tmp.tcl]]

# Files to wrap
package ifneeded tclapp::files 1.0 [list source [file join $dir tclapp_files.tcl]]

# File path resolution
package ifneeded tclapp::fres 1.0 [list source [file join $dir tclapp_fres.tcl]]

# Misc. state
package ifneeded tclapp::misc 1.0 [list source [file join $dir tclapp_misc.tcl]]

# Config. support
package ifneeded tclapp::config 1.0 [list source [file join $dir tclapp_config.tcl]]

# Package database
package ifneeded tclapp::pkg 1.0 [list source [file join $dir tclapp_pkg.tcl]]

# Package database (TAP, backward compat)
package ifneeded tclapp::tappkg 1.0 [list source [file join $dir tclapp_tappkg.tcl]]

# Cursor management
package ifneeded tclapp::cursor 1.0 [list source [file join $dir cursor.tcl]]

# Engine, Low-level.
package ifneeded tclapp::wrapengine 1.0 [list source [file join $dir wengine.tcl]]

# Banner printing
package ifneeded tclapp::banner 1.0 [list source [file join $dir banner.tcl]]

# Cmdline processor
package ifneeded tclapp::cmdline 1.0 [list source [file join $dir cmdline.tcl]]

# 
package ifneeded tclapp::pkg::pool 1.0 [list source [file join $dir pkgpool.tcl]]
