# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tape_startup.tcl --
#
#	The main file for the "TclDevKit Package Editor"
#
# Copyright (c) 2002-2007 ActiveState Software Inc.
#


# 
# RCS: @(#) $Id: startup.tcl,v 1.5 2001/01/24 19:41:24 welch Exp $


# Prevent misinterpretation by Tk
set ::pargc $::argc ; set ::argc 0
set ::pargv $::argv ; set ::argv {}

if {[string match -psn* [lindex $::pargv 0]]} {
    # Strip Apple's option providing the Processor Serial Number to bundles.
    incr ::pargc -1
    set  ::pargv [lrange $::pargv 1 end]
}

package require projectInfo
package require cmdline
package require log
log::lvSuppressLE notice
#log::lvSuppress debug

package require  tape::state  ; # Editor State (.tap packages)
package require  tape::teapot ; # Editor State (TEApot packages)

###############################################################################
###############################################################################

# Always invoke the GUI. Failures causes printout of a help message to stderr.
# There is no command line.

# If the first argument is a -gui the second argument will be
# interpreted as a configuration (= .tap, teapot, etc. file) to load.

set config {}

# Command line syntax:
# tclpe ?-gui? ?--? ?file?

proc Usage {} {
    global argv0
    puts stderr "wrong\#args, expected: $argv0 ?-gui? ?--? ?file?"
    exit 1
    return
}

while {[string match -* [set opt [lindex $::pargv 0]]]} {
    if {[string equal -gui $opt]} {
	set ::pargv [lrange $::pargv 1 end]
	continue
    }
    if {[string equal -- $opt]} {
	set ::pargv [lrange $::pargv 1 end]
	break
    }
    Usage
}

if {[llength $::pargv] > 1} {
    Usage
} elseif {[llength $::pargv] == 1} {
    set config [lindex $::pargv 0]
    set ::pargv [list]
}

# Give something to the Tk check.
set ::argc $::pargc
set ::argv $::pargv

package require tcldevkit::tk

# And remove everything again.
set ::argc 0
set ::argv {}

if {[::tcldevkit::tk::present]} {
    #package require comm
    #log::log debug "COMM DEBUG PORT = [comm::comm self]" ; ## DEBUG FEATURE ###

    package require tcldevkit::appframe
    package require help

    # ### ### ### ######### ######### #########

    package require style::as
    style::as::init
    style::as::enable control-mousewheel global

    set ::tk::AlwaysShowSelection 1

    package require pref::teapot
    ::pref::teapot::init
    pref::setGroupOrder [pref::teapot::init]

    ::help::page Package
    ::tcldevkit::appframe::setName {Package Editor}
    ::tcldevkit::appframe::initConfig $config

    ::tape::state  Initialize
    ::tape::teapot Initialize

    ::tcldevkit::appframe::NeedReadOrdered
    ::tcldevkit::appframe::NeedWriteOrdered

    ::tcldevkit::appframe::clearProjExt
    ::tcldevkit::appframe::appendProjExt POT .txt
    ::tcldevkit::appframe::appendProjExt TM  .tm
    ::tcldevkit::appframe::appendProjExt EXE .exe
    ::tcldevkit::appframe::appendProjExt KIT .kit
    ::tcldevkit::appframe::appendProjExt ZIP .zip
    ::tcldevkit::appframe::appendProjExt TAP .tap
    ::tcldevkit::appframe::appendProjExt All *

    # Redirect/Hook into the Loading and Saving of project files to
    # handle not only tap files, but teapot as well.

    ::tcldevkit::appframe::LoadChainAppend      ::tape::teapot::LoadTeapot
    ::tcldevkit::appframe::SaveMenuStateHookSet ::tape::teapot::MenuTeapot
    ::tcldevkit::appframe::SaveHookSet          ::tape::teapot::SaveTeapot
    ::tcldevkit::appframe::SaveExtensionHookSet ::tape::teapot::SaveExtTeapot

    # modify the menu a bit, change labeling and insert another action.
    # Consider some way to make this more declarative in appframe.

    set m $::tcldevkit::appframe::menu
    set npp {command {&New Project (Teapot)} {new} {New Teapot Configuration} {} -command ::tcldevkit::appframe::Clear}
    set npt {command {New Project (&Tap)} {newtap} {New Tap Configuration}    {} -command ::tape::teapot::NewTap}
    set m [lreplace $m 4 4 [lreplace [lindex $m 4] 0 0 $npp $npt]]

    set ::tcldevkit::appframe::menu $m


    ::tcldevkit::appframe::markclean
    ::tcldevkit::appframe::run       tcldevkit::tape
    exit 0
}

###############################################################################
###############################################################################
# Write error message to stderr and exit.

puts stderr "Unable to load and use Tk, aborting ..."
exit 1
