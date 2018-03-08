# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# banner.tcl --
#
#	Print a banner message. Or not.
#
# Copyright (c) 2006-2009 ActiveState Software Inc.

#
# RCS: @(#) $Id: tclapp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

package require compiler

namespace eval ::tclapp::banner {}

# ### ### ### ######### ######### #########

proc ::tclapp::banner::no {} {
    variable print
    set      print 0
    return
}

proc ::tclapp::banner::print {} {
    variable print
    variable printed

    if {$printed} return
    set printed 1

    if {!$print && ($expire eq "")} return

    set endyear [clock format [clock seconds] -format %Y]

    ::log::log info "| Tcl Dev Kit TclApp"
    ::log::log info "| Copyright (C) 2001-$endyear ActiveState Software Inc. All rights reserved."
    ::log::log info "|"

    return
}

proc ::tclapp::banner::print/tail {} {
    variable print

    if {!$print && ($expire eq "")} return

    set endyear [clock format [clock seconds] -format %Y]

    ::log::log notice " "
    ::log::log info   " "

    return
}

proc ::tclapp::banner::reset {} {
    variable print   1
    variable printed 0
    return
}

#
# ### ### ### ######### ######### #########

namespace eval ::tclapp::banner {

    # Boolean flag. Controls printing of a banner message.  (Only
    # partially. A temporary license forces the printing of a banner,
    # whatever this flag said). Defaults to true, print a banner.

    variable print 1

    # Boolean flag. Indicates if the banner has been printed
    # already. If yes it will not be printed again should the system
    # try to do so.

    variable printed 0
}

#
# ### ### ### ######### ######### #########

package provide tclapp::banner 1.0
