# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Comp * Entry
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

    package require splash
    splash::configure -message DEVEL
    splash::configure -imagefile [file join $self artwork/splash.png]
} else {
    # Wrapped standard actions.
    source [file join $starkit::topdir ms.tcl]
}

# ### ### ### ######### ######### #########
## We load Tclx so that the compiler code will have access to the new
## math functions of this package. Without this we cannot compile code
## using Tclx math functions, they would be syntax errors.

## This is a bit of a hack. A generic solution would allow the user to
## preload packages for compiling, but this can become a security
## nightmare. For now only Tclx is known to define new math functions,
## and is safe, so we go for the hack.

# This is done by 'go' as well, but comes to late for Tclx.
global auto_path
foreach d $auto_path {
    foreach pd [glob -nocomplain -directory $d P-*] {
	lappend auto_path $pd
    }
}

package require Tclx

##
# ### ### ### ######### ######### #########

# Hand over to the actual application.

go [file join $self lib app-comp comp_startup.tcl]
