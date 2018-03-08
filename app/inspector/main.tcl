# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Inspector
# -- Specialized main.tcl. Performs license check.

set self [file dirname [file dirname [file dirname [file normalize [info script]]]]]

package require starkit
if {"unwrapped" eq [starkit::startup]} {
    # Unwrapped call is during build - tap scan/generate.  Other
    # unwrapped calls are during development from within the local
    # perforce depot area. Slightly different location of lib dir.
    # Hence we use two stanza's to define an externa lib directory.
    # Debug output is allowed, actually sort of wanted to be sure of
    # package locations.
    
    lappend auto_path [file join $self lib]

    puts stderr unwrapped\n[join $auto_path \n\t]

    # External standard actions
    source [file join $self app main_std.tcl]

    package require splash
    splash::configure -message DEVEL
    splash::configure -imagefile [file join $self artwork/splash.png]
} else {
    # Wrapped standard actions.
    source [file join $starkit::topdir ms.tcl]
}

go [file join $self lib inspector.tcl]
