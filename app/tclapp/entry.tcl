# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# TclApp * Entry
# - Initialization of wrap support (VFS, Mk4FS foundation, ...)
# - License check
# - Invokation of the actual application.
# - (Inactive code for the debugging of the package management, and file sourcery.)


# Trace exactly which packages are required during execution
#source [file join [pwd] [file dirname [file dirname [info script]]] debug_require.tcl]

# Trace exactly which files are read via source.
#source [file join [pwd] [file dirname [file dirname [info script]]] debug_source.tcl]

# Dump loaded packages when exiting the application
#source [file join [pwd] [file dirname [file dirname [info script]]] dump_packages.tcl]

# Dump stack
#source [file join [pwd] [file dirname [file dirname [info script]]] dump_stack.tcl]


package require starkit
if {![info exists ::starkit::mode] || ("unwrapped" eq $::starkit::mode)} {
    # Unwrapped call is during build - tap scan/generate.  Other
    # unwrapped calls are during development from within the local
    # perforce depot area. Slightly different location of lib dir.
    # Hence we use two stanza's to define an externa lib directory.
    # Debug output is allowed, actually sort of wanted to be sure of
    # package locations.

    starkit::startup
    lappend auto_path [file join [file dirname [file dirname $starkit::topdir]] devkit lib]
    lappend auto_path [file join [file dirname [file dirname $starkit::topdir]] lib]
    lappend auto_path ~/TDK/lib
#    tcl::tm::roots ~/TDK/lib

    package require activestate::teapot::link
    activestate::teapot::link::use ~/Abuild/lib/teapot-build
    activestate::teapot::link::use ~/Abuild/lib/teapot-build-save-core

    puts stderr unwrapped\n[join $auto_path \n\t]

    # External standard actions
    source [file join [pwd] [file dirname $starkit::topdir] main_std.tcl]

    package require splash
    splash::configure -message DEVEL
    splash::configure -imagefile ~/Abuild/images/splash.png
} else {
    # Wrapped standard actions.
    source [file join $starkit::topdir ms.tcl]
}

go [file join $starkit::topdir lib app-tclapp tclapp_startup.tcl]
