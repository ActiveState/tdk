# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pdx.tcl --
#
#	This file contains functions that handle PDX searching and loafing.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2003-2006 ActiveState Software Inc.
#

# 
# SCCS: @(#) location.tcl 1.4 98/04/14 15:48:29

namespace eval pdx {
    # Reference to the directory this package is in.
    variable libdir [file dirname [::info script]]

    # List of loaded pdx files.
    variable pdx_loaded {}
}
# end namespace pdx

# pdx::load_predefined --
#
#	Loads a number of predefined PDX files coming with the
#	package itself. Note that all these files will be found
#	and loaded by the general 'load' command too. Use this
#	command if and only if the internal pdx files are needed,
#	but none of the user specified ones.
#
# Arguments:
#	None.
#
# Results:
#	None.
#
# Sideffects:
#	Arbitrary, as defined in the loaded .pdx files.

proc pdx::load_predefined {} {
    variable libdir

    # Additional instrumentation handlers.
    # Predefined, and part of the starkit/application
    #
    # DANGER / TRUSTED CODE
    # Extensions are loaded under 'instrument' to shield
    # the application from them at least a bit.

    foreach f {
	uplevel.pdx	tcltest.pdx	snit.pdx
	blend.pdx	oratcl.pdx
	tclCom.pdx	xmlGen.pdx
    } {
	set f [file join $libdir $f]
	namespace eval ::instrument [list source $f]
    }
    return
}

# pdx::load --
#
#	Locate all user PDX files for the debugger and load them. This
#	also locates and loads all internal/predefined pdx files.
#
# Arguments:
#	None.
#
# Results:
#	None.
#
# Sideffects:
#	Arbitrary, as defined in the loaded .pdx files.

proc pdx::load {} {
    variable libdir
    variable pdx_loaded

    # Load any external extensions from `here`, <ProRoot>/lib,
    # env(TCLPRO_LOCAL), and env(TCLDEVKIT_LOCAL).

    set pattern [file join $libdir *.pdx]
    #puts "Pattern: $pattern"

    set files [glob -nocomplain $pattern]

    set pattern [file join [file dirname [file dirname [::info nameofexecutable]]] lib *.pdx]
    #puts "Pattern: $pattern"

    set fext [glob -nocomplain $pattern]

    if {[llength $fext] > 0} {set files [concat $files $fext]}

    if {[::info exists ::env(TCLPRO_LOCAL)]} {
	set files [concat \
		$files \
		[glob -nocomplain [file join $::env(TCLPRO_LOCAL) *.pdx]]]
    }

    if {[::info exists ::env(TCLDEVKIT_LOCAL)]} {
	set files [concat \
		$files \
		[glob -nocomplain [file join $::env(TCLDEVKIT_LOCAL) *.pdx]]]
    }

    #puts "[::info level 0]: Scanning ([join $files ") ("])"
    #
    # DANGER / TRUSTED CODE
    # Extensions are loaded under 'instrument' to shield
    # the application from them at least a bit.
    #

    foreach file $files {
	if {[catch {
	    namespace eval ::instrument [list source $file]
	} err]} {
	    bgerror "Error loading $file:\n$err"
	    continue
	}
	lappend pdx_loaded $file
    }
    return
}

# pdx::info --
#
#	Returns information about the pdx files which were loaded.
#
# Arguments:
#	None.
#
# Results:
#	A list containing the absolute path names of all pdx files
#	read and executed by 'pdx::load'.
#
# Sideffects:
#	None.

proc pdx::info {} {
    variable pdx_loaded
    return  $pdx_loaded
}

# The package is ready to go.

package provide pdx 1.0
