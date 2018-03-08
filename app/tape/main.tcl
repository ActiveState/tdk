# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# TAPE - .tap Editor
#
# -- Specialized main.tcl. Performs the license check.


# Trace exactly which packages are required during execution
#source [file join [pwd] [file dirname [file dirname [info script]]] debug_require.tcl]

# Trace exactly which files are read via source.
#source [file join [pwd] [file dirname [file dirname [info script]]] debug_source.tcl]

# Dump loaded packages when exiting the application
#source [file join [pwd] [file dirname [file dirname [info script]]] dump_packages.tcl]

set self [file dirname [file dirname [file dirname [file normalize [info script]]]]]

package require starkit
if {"unwrapped" eq [starkit::startup]} {
    # Unwrapped calls are during development from within the local
    # perforce depot area. Slightly different location of lib dir.
    
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

set startup [file join $self lib app-tape tape_startup.tcl]
set ::argv0 $startup
go          $startup
