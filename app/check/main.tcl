# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Checker * Entry
# - Initialization of wrap support (VFS, Mk4FS foundation, ...)
# - License check
# - Invokation of the actual application.
# - (Inactive code for the debugging of the package management, and file sourcery.)


# Trace exactly which packages are required during execution
#source [file join [pwd] [file dirname [file dirname [info script]]] debug_require.tcl]

# Trace exactly which files are read via source.
#source [file join [pwd] [file dirname [file dirname [info script]]] debug_source.tcl]

set self [file dirname [file dirname [file dirname [file normalize [info script]]]]]

package require starkit
if {"unwrapped" eq [starkit::startup]} {
    # Unwrapped calls are during development from within the local
    # perforce depot area. Debug output is allowed, actually sort of
    # wanted to be sure of package locations.
    
    lappend auto_path [file join $self lib]

    puts stderr unwrapped\n[join $auto_path \n\t]

    # External standard actions
    source [file join $self app main_std.tcl]
} else {
    # Wrapped standard actions.
    source [file join $starkit::topdir ms.tcl]
}

go [file join $self lib app-check check_startup.tcl]
