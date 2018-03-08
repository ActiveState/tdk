# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_startup.tcl --
#
#	The main file for the "TclDevKit Wrapper Utility Command-Line Interface"
#
# Copyright (c) 2002-2008 ActiveState Software Inc.
#


# 
# RCS: @(#) $Id: startup.tcl,v 1.5 2001/01/24 19:41:24 welch Exp $

package provide app-tclapp 1.0

###############################################################################
# Basic log settings ... Logging to stdout or a file.
# The GUI will override this with logging to a window.

package require log

log::lvSuppress debug
log::lvSuppress warning 0 ; # Activate
log::lvSuppress info    0 ; # Activate
log::lvSuppress notice  0 ; # Activate

# ### ### ### ######### ######### #########
## Prevent misinterpretation by Tk

set ::pargc $::argc ; set ::argc 0
set ::pargv $::argv ; set ::argv {}

if {[string match -psn* [lindex $::pargv 0]]} {
    # Strip Apple's option providing the Processor Serial Number to bundles.
    incr ::pargc -1
    set  ::pargv [lrange $::pargv 1 end]
}

set repodebug 0
if {[string match -debug* [lindex $::pargv 0]]} {
    # Handle the -debug crank as early as possible.
    incr ::pargc -1
    set  ::pargv [lrange $::pargv 1 end]
    log::lvSuppress debug 0
    set repodebug 1 
}

# ### ### ### ######### ######### #########

package require pref::devkit ; # TDK    preferences
package require pref::teapot ; # TEAPOT preferences

# ### ### ### ######### ######### #########

package require  tclapp
package require  tclapp::pkg

# ### ### ### ######### ######### #########
## Initialize preferences

pref::setGroupOrder  [pref::devkit::init]
pref::setGroupOrder+ [pref::teapot::init]

#puts <<[pref::getGroupOrder]>>

# ### ### ### ######### ######### #########

#package require pkgman
package require tclapp::tappkg ; # Backward compat code.

# ### ### ### ######### ######### #########
## Tracing configuration
## (1) Disabled information stuff, allow only errors and above
## (2) Change logging for better alignment, display of services,
##     setting ...

package require logger

if 0 {
    set max 0
    foreach s [logger::services] {
	if {[set l [string length $s]] > $max} {set max $l}
	proc logger::tree::${s}::stdoutcmd {level text} {
	    global sx
	    variable service
	    puts stdout "$sx($service) \[$level\] \'$text\'"
	}
    }
    incr max 2
    foreach s [logger::services] {
	set ::sx($s) [format %-*s $max \[$s\]]
    }

    puts *\ [join [logger::services] "\n* "]

    #logger::setlevel error
    [logger::servicecmd event::merger       ]::setlevel error
    [logger::servicecmd jobs                ]::setlevel error
    [logger::servicecmd jobs::async         ]::setlevel error
    [logger::servicecmd pkg::mem            ]::setlevel error
    [logger::servicecmd pkgman              ]::setlevel error
    [logger::servicecmd repository::api     ]::setlevel error
    [logger::servicecmd teapot::metadata    ]::setlevel error
    [logger::servicecmd repository::mem     ]::setlevel error
    [logger::servicecmd teapot::metadata::index::sqlite]::setlevel error
    [logger::servicecmd repository::pool    ]::setlevel error
    [logger::servicecmd repository::prefix  ]::setlevel error
    [logger::servicecmd repository::provided]::setlevel error
    [logger::servicecmd repository::resolve ]::setlevel error
    [logger::servicecmd repository::tap     ]::setlevel error
    [logger::servicecmd repository::union   ]::setlevel error
    [logger::servicecmd tap::cache          ]::setlevel error
    [logger::servicecmd tap::db             ]::setlevel error
    [logger::servicecmd tap::db::files      ]::setlevel error
    [logger::servicecmd tap::db::loader     ]::setlevel error
    [logger::servicecmd tap::db::paths      ]::setlevel error
    #[logger::servicecmd tcldevkit::wrapper  ]::setlevel error

} else {
    logger::setlevel error
}

if {$repodebug} {
    logger::setlevel debug
}

# ### ### ### ######### ######### #########
## Package scanner ...
##
# If the first argument is a -scan the remainder is a list of
# directories to scan for packages. The system will scan these
# directories and spit out appropriate basic package definitions in
# the subdirectory 'tapscan' of the current working directory, one
# file per found package.

if {[string equal -scan [lindex $::pargv 0]]} {

    # Give something to the Tk check.
    set ::argc $::pargc
    set ::argv $::pargv

    package require tcldevkit::tk

    # And remove everything again.
    set ::argc 0
    set ::argv {}

    package require tcldevkit::appframe
    ::tcldevkit::appframe::setName TclApp

    package require tclapp::pkg::scan
    tclapp::pkg::scan::run [lrange $::pargv 1 end]
    exit 0
}

# ### ### ### ######### ######### #########
## Starkit to -pack conversion ...
##
# If the first argument is -genpak then the remaining arguments
# specify a base kit, and a starkit. The starkit is converted into a
# starpack, using the given basekit. This is a special mode of
# wrapping, where the input file come directly out of a starkit.
#
# Syntax: -genpak basekit starkit result
# Alt.:   genpak  basekit starkit result

# Additional functionality:
# -- splitpak (complement to genpak)
# -- vacuum   (remove free space from the filesystem in the starkit|pack)
#
# Syntax: splitpak starpack basekit-result starkit-result
# Alt.:   splitpak starpack basekit-result starkit-result
#
# Syntax: -vacuum starkit|starpack
# Alt.:   vacuum  starkit|starpack

foreach {option cmd} {
    -genpak   run
    genpak    run
    -splitpak split
    splitpak  split
    -vacuum   vacuum
    vacuum    vacuum
} {
    if {[lindex $::pargv 0] eq $option} {
	package require tclapp::genpak
	set ok [tclapp::genpak::$cmd [lrange $::pargv 1 end]]
	exit [expr {!$ok}]
    }
}

# ### ### ### ######### ######### #########
## Regular wrap functionality ...
##

###############################################################################
###############################################################################
##
# New code, TclDevKit graphical user interface ...

# Invoked automatically if the application is called without arguments
# and a DISPLAY is present. If either there is no DISPLAY or we are
# unable to load Tk we do not follow this branch further but fall
# through to the default command line mode (which will print a help
# message).

# If the first argument is a -gui the UI is forced, and
# a second argument will be interpreted as a configuration
# to load. Any other arguments will be ignored in that mode.

set config {}
if {[string equal -gui [lindex $::pargv 0]]} {
    set config [lindex $pargv 1]
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
    package require tcldevkit::appframe
    package require help

    # ### ### ### ######### ######### #########
    # Editing preferences ...
    # Insert a menu for dong this into the
    # standard menu

    package require tclapp::pref

    if {[tk windowingsystem] eq "aqua"} {
	interp alias "" ::tk::mac::ShowPreferences "" ::tclapp::pref::edit
	bind all <Command-comma> ::tk::mac::ShowPreferences
    } else {
	set ::tcldevkit::appframe::menu \
	    [linsert $::tcldevkit::appframe::menu 5 \
		 &Edit {} hmenu 0 {
		     {command &Preferences... {pref} {Edit preferences} {} -command ::tclapp::pref::edit}
		 }]
    }

    # ### ### ### ######### ######### #########

    package require style::as
    style::as::init
    style::as::enable control-mousewheel global

    set ::AQUA [expr {[tk windowingsystem] eq "aqua"}]
    if {$::AQUA} {
	set ::tk::mac::useThemedToplevel 1
    }

    set ::tk::AlwaysShowSelection 1

    ##### ::port::pad should move to a library
    #####
    namespace eval ::port {
	namespace export -clear pad
	variable PAD
	switch -exact [tk windowingsystem] {
	    win32 {
		set PAD(x) 4
		set PAD(y) 4
		set PAD(corner) 4
		set PAD(labelframe) 4
		set PAD(notebook) 8
		set PAD(default) 4
	    }
	    aqua {
		# http://developer.apple.com/documentation/UserExperience/Conceptual/OSXHIGuidelines/index.html
		set PAD(x) 8
		set PAD(y) 8
		set PAD(corner) 14
		set PAD(labelframe) 8
		set PAD(notebook) 8
		set PAD(default) 4
	    }
	    x11 -
	    default {
		set PAD(x) 4
		set PAD(y) 4
		set PAD(corner) 4
		set PAD(labelframe) 2
		set PAD(notebook) 4
		set PAD(default) 2
	    }
	}
    }

    # ::port::pad --
    #
    #   Return various padding widths based on widget element
    #
    # Arguments:
    #   args	comments
    # Results:
    #   Returns ...
    #
    proc ::port::pad {elem} {
	variable PAD
	if {[info exists PAD($elem)]} {
	    return $PAD($elem)
	}
	return $PAD(default)
    }
    namespace eval :: { namespace import -force ::port::pad }
    #####
    #####

    #package require comm
    #puts [comm::comm self]

    ::help::page                   TclApp
    ::tcldevkit::appframe::setName TclApp
    ::tcldevkit::appframe::initConfig $config
    ::tcldevkit::appframe::markclean
    ::tcldevkit::appframe::run       tcldevkit::wrapper

    # The 'run' will not return.
}

# Need this information when loading a configuration file (-config)
# Future: Separate the application framework into Tk and non-Tk parts.

package require tcldevkit::appframe
::tcldevkit::appframe::setName TclApp

###############################################################################
###############################################################################
# Run the application from the command line.

proc ::tclapp::cmdlineTapError {text} {
    ## Catch required for windows. Command line operation on windows
    ## does not have the std channels.

    catch {puts stderr "TAP load error: [join [split $text \n] "\n              : "]"}
}
::tclapp::tappkg::setLogError ::tclapp::cmdlineTapError
::tclapp::tappkg::Initialize
::tclapp::tappkg::dumpErrors

set ok [tclapp::wrap_safe $::pargv]
exit [expr {!$ok}]
