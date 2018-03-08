# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# options.tcl --
#
#	Default options used in the debugger
#
# Copyright (c) 2001-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: guiUtil.tcl,v 1.3 2000/10/31 23:30:58 welch Exp $

package provide uiDefOpt 1.0
namespace eval  uiDefOpt {}

#-----------------------------------------------------------------------------
# Declare default values for a number of options
#-----------------------------------------------------------------------------

# uiDefOpt::init --
#
#	Setup the default values.
#
# Arguments:
#	None.
#
# Results: 
#	None.

proc uiDefOpt::init {} {
    #puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if {[tk windowingsystem] eq "aqua"} {
	set ::tk::mac::useThemedToplevel 1
    }

    package require tile
    if {[package vsatisfies [package present Tk] 8.5]} {
	# Tk 8.5+ (incl. tile)
	ttk::style configure Slim.Toolbutton -padding 2
    } else {
	# Tk 8.4, tile is separate
	style default Slim.Toolbutton -padding 2
    }

    # we have to require this after other packages to make sure that
    # the modified bindings are done after other packages are loaded.
    package require style::as
    style::as::init
    style::as::enable control-mousewheel global

    # make tree widgets use theming on non-x11 platforms
    if {[tk windowingsystem] ne "x11"} {
	option add *TreeCtrl.useTheme 1
    }
    option add *Scrollbar.highlightThickness 0

    # Improved themed notebook look
    if {[tk windowingsystem] eq "aqua"} {
	# Aqua has a too much padding by default
	option add *TNotebook.padding 0
    } elseif {0} {
	# This would show the gradient background on Windows, but it
	# doesn't work layer right, so don't use this for now
	style layout NotebookPane {
	    NotebookPane.background -sticky news -expand 1
	}
	option add *TNotebook.TFrame.style NotebookPane
	option add *TNotebook.TFrame.padding 4
    }

    return
}
