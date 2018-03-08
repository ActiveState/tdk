# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package syscolor 0.1
# Meta platform    tcl
# Meta description Mini database of system colors. Enables users to 
# Meta description visually match widgets with the system defaults.
# Meta require     Tk
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
#
# System colors

package require Tk

namespace eval ::syscolor {
    set w [listbox ._________w_]
    variable buttonFace    [$w cget -highlightbackground]
    variable highlight     [$w cget -selectbackground]
    variable highlightText [$w cget -selectforeground]
    destroy $w
}

#proc ::syscolor {} {}

# Create accessor procedures for the colors.

foreach c {
    buttonFace
    highlight
    highlightText
} {
    proc ::syscolor::$c {} [list return [set ::syscolor::$c]]
}

# ### ######### ###########################
## Ready for use
return
