# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# launch.tcl --
#
#  Launch script. Windows-only. Associated with the .tpj extension.
#  Peeks into the file given to it, determines the tool it belongs to
#  and runs that tool with the given file.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.
#


# 
# RCS: @(#) $Id: launch.tcl,v 1.4 2000/10/31 23:31:05 welch Exp $

package provide launch 1.0

package require Tk
catch {wm withdraw .}

package require tcldevkit::config

set projectfile [lindex $argv 0]

if {$projectfile == {}} {
    tk_dialog .bogus "Launcher Error" \
	    "The launcher has to be called with a file as its argument" \
	    error 0 Ok
    exit 1
}

foreach {pro tool} \
	[::tcldevkit::config::Peek/2.0 $projectfile] \
	{ break }

proc IsDebugger {fname} {
    set res 0
    if {[catch {
	set fh [open $fname]
	set stop 0
	while {![eof $fh]} {
	    if {[gets $fh line] < 0} continue
	    if {[regexp {projVersion[ 	]+1\.0} $line]} {
		set res 1
		break
	    }
	}
	close $fh
    }]} {
	catch {close $fh}
    }
    return $res
}

## PackageDefinitions are routed to TclApp, despite the fact that
## TclApp is currently unable to handle such an invocation. In the
## future TclApp may contain an editor for package definitions.

set dbg 0
if {!$pro} {
    # File is not in "TclDevKit Project File Format Specification,
    # 2.0" format.
    # There are now two formats possible:
    # a The TclDevKit 1.0 format used by the debugger.
    # b The plain text format recognized TclApp
    #   (TclApp_FileFormats.txt [iii]). 
    #
    # To differentiate we now peek into the file again and look for
    # 'projVersion 1.0' on a single line. If we find such a line we
    # assume format a), else (b).

    if {[IsDebugger $projectfile]} {
	set toolapp tcldebugger
	set dbg 1
    } else {
	set toolapp tclapp
    }
} else {
    switch -exact -- $tool {
	{TclDevKit Debugger}                 {set toolapp tcldebugger ; set dbg 1}
	{TclDevKit Wrapper}                  {set toolapp tclapp}
	{TclDevKit Compiler}                 {set toolapp tclcompiler}
	{TclDevKit TclApp}                   {set toolapp tclapp}
	{TclDevKit TclApp PackageDefinition} {set toolapp tclpe}
	default {
	    tk_dialog .bogus "Unknown tool" \
		    "The chosen TclDevKit Project File \"$projectfile\" contains data for the application \"$tool\".\n\nThis application is unfortunately not known to this launcher application, therefore the launch operation is aborted." \
		    error 0 Ok
	    exit 1
	}
    }
}

if {[string equal $tcl_platform(platform) windows]} {
    # Starpacks on windows, i.e. regular executables.
    append toolapp .exe
}

set toolapp     [file join [file dirname $starkit::topdir] $toolapp]
set projectfile [file nativename $projectfile]

if {$dbg} {
    # The debugger has no special option to invoke its GUI mode.
    if {[catch {eval exec [list $toolapp $projectfile] &} msg]} {
	tk_dialog .bogus "Launcher Error" \
		"$toolapp $projectfile\n\n$msg" \
		error 0 Ok
	exit 1
    }
} else {
    if {[catch {eval exec [list $toolapp -gui $projectfile] &} msg]} {
	tk_dialog .bogus "Launcher Error" \
		"$toolapp -gui $projectfile\n\n$msg" \
		error 0 Ok
	exit 1
    }
}
exit 0
