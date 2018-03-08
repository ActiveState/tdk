# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tlocate 0.1
# Meta category        Locating TDK tools
# Meta description     Locate a TDK tool from within another TDK tool.
# Meta platform        tcl
# Meta require         {Tcl -version 8.4}
# Meta subject         locate find where
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# Locate a TDK tool from within another Tool

# ### ### ### ######### ######### #########

package require platform

namespace eval tlocate {}

# ### ### ### ######### ######### #########

proc tlocate::find {tool} {
    global tcl_platform

    # On windows, and most unices the tools and their base interpreter
    # are siblings in the same directory. On OSX the executable is an
    # application bundle we have to walk out of, and then walk into
    # the required tool bundle. If we cannot find the tool in that way
    # we try the PATH as a last resort.

    # In detail.
    #  Windows
    #    installdir/bin/SELF.exe - executable.
    #    installdir/bin/TOOL.exe
    #
    #  Unix
    #    installdir/bin/TDKBASE - executable
    #    installdir/bin/SELF    - starkit
    #    installdir/bin/TOOL
    #
    #  Darwin
    #    Tcl Dev Kit/tdkbase.app/Contents/MacOS/tdkbase  - executable
    #    Tcl Dev Kit/SELF.app   /Contents/MacOS/SELF     - starkit
    #    Tcl Dev Kit/TOOL.app   /Contents/MacOS/TOOL
    #
    # In all cases we can locate the TOOL relative to the executable
    # (info noe), or rather, the directory it is in, SELFDIR = NOE/..
    #
    # Windows: SELFDIR/TOOL.exe
    # Unix:    SELFDIR/TOOL
    # Darwin:  SELFDIR/../../../TOOL.app/Contents/MacOS/TOOL

    set exe $tool
    if {$tcl_platform(platform) eq "windows"} {
	append exe .exe
    }

    set selfdir [file dirname [info nameofexecutable]]

    if {[string match macosx-* [platform::generic]]} {
	set topdir  [file dirname [file dirname [file dirname $selfdir]]]
	set path    [file join $topdir ${tool}.app Contents MacOS $tool]
    } else {
	set path    [file join $selfdir $exe]
    }

    if {[file exists $path]} {
	# Note, auto_execok below returns a list as well, this is our
	# result API.
	return [list $path]
    }

    # Last resort, search the PATH for the requested tool.

    return [auto_execok $exe]
}

# ### ### ### ######### ######### #########
return
