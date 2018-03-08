# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::sys 0.1
# Meta platform    tcl
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# System configuration, global constants hardwired into the whole
# TEAPOT system.

# ### ### ### ######### ######### #########
## Requirements

package require platform

namespace eval ::repository::sys {}

# ### ### ### ######### ######### #########
## Implementation

proc ::repository::sys::basedir {} {
    variable basedir
    return  $basedir
}

proc ::repository::sys::oldbasedir {} {
    variable oldbasedir
    return  $oldbasedir
}

proc ::repository::sys::userdir {} {
    variable userdir
    return  $userdir
}

proc ::repository::sys::taphelpdir {} {
    variable taphelpdir
    return  $taphelpdir
}

proc ::repository::sys::cachedir {} {
    variable cachedir
    return  $cachedir
}

proc ::repository::sys::configRoot {} {
    variable configRoot
    return  $configRoot
}

proc ::repository::sys::configHistory {} {
    variable configHistory
    return  $configHistory
}

proc ::repository::sys::watchworkspacedir {} {
    variable watchworkdir
    return  $watchworkdir
}

# ### ### ### ######### ######### #########

proc ::repository::sys::WinUserprofile {} {
    package require registry
    global env

    set key "HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders"
    set idx  USERPROFILE

    foreach pathkey {
	Personal
	AppData
	Recent
	SendTo
	Cookies
	Desktop
	Favorites
	NetHood
	PrintHood
	Templates
	{Local Settings}
	{Start Menu}
    } {
	if {![catch {set path [registry get $key $pathkey]}]} {
	    return [file dirname $path]
	}
    }

    # Registry failed, try the environment.

    if {[info exists env($idx)]} {
	return $env($idx)
    }

    # Nothing found at all, giving up.

    return -code error "Unable to determine home directory of user"
}

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::repository::sys {
    proc .. {p} { file dirname $p } ; # Shorten a number of upcoming commands.

    variable basedir
    variable oldbasedir
    variable userdir
    variable watchworkdir
    variable cachedir
    variable configHistory {1.0}
    variable configRoot    {}
    variable taphelpdir    {}

    # Darwin == OS X has a special location for configuration
    # files. Ditto Windows has its special location. For all others,
    # i.e. unixoids, we use a hidden subdirectory of Home directory.

    if {$::tcl_platform(os) == "Darwin"} {
	set _Base_ [file join ~ Library {Application Support} Teapot Teapot]
	# While the install/osx/postflight shell script cannot ask us
	# directly for this value it can find out using 'teacup
	# default', assuming that this value here is the default. See
	# devkit/lib/preftp/preftp.tcl to ensure that.
	#
	# install/osx/postflight has the path hardcoded now, for reliability.

    } elseif {$::tcl_platform(platform) == "windows"} {
	set _Base_ [file join  [WinUserprofile] Teapot]
    } else {
	set _Base_ [file join  ~ .teapot]
    }

    # installation + platform dependent path segment.
    # installation identified by its top directory (2x .. up from the executable)
    # INSTALL/bin/{teacup,tclapp} ...

    set    ipcode [string map {/ %2f : %3a} [.. [.. [file normalize [info nameofexecutable]]]]]
    append ipcode . [platform::identify]

    set oldbasedir $_Base_
    set basedir    [file join $_Base_ $ipcode]
    unset _Base_

    set userdir      [file join [.. [.. [info nameofexecutable]]] lib teapot]
    set cachedir     [file join $basedir indexcache]
    set watchworkdir [file join $basedir watchspace]

    if {$::tcl_platform(os) == "Darwin"} {
	set userdir    [file join / Library Tcl teapot]
	set taphelpdir [file join / Library Tcl tap_help_repository]
    } elseif {$::tcl_platform(platform) == "windows"} {

	# INSTALL/bin/*.kit/tdkbase.mkf/lib/repository/sys.tcl
	# INSTALL/tap_help_repository
	# ../../../../../../tap_help_repository

	# Cross-reference with file 'build/pack_pro.tcl', command
	# 'mode_put_repositories'. Any change in 'taphelpdir' here has
	# to be reflected there and vice versa.

	set taphelpdir [file join \
			    [.. [.. [.. [.. [.. [.. [file normalize \
							 [info script]]]]]]]] \
			    tap_help_repository]

    } else {
	# INSTALL/bin/*.kit/lib/repository/sys.tcl
	# INSTALL/tap_help_repository
	# ../../../../../tap_help_repository

	# Cross-reference with file 'build/pack_pro.tcl', command
	# 'mode_put_repositories'. Any change in 'taphelpdir' here has
	# to be reflected there and vice versa.

	set taphelpdir [file join \
			    [.. [.. [.. [.. [.. [file normalize \
						     [info script]]]]]]] \
			    tap_help_repository]
    }

    # On windows the preferences are in the registry.

    if {$::tcl_platform(platform) == "windows"} {
        set configRoot "HKEY_CURRENT_USER\\SOFTWARE\\TEApot\\TEAPOT\\$ipcode"
    } else {
	set configRoot [file join $basedir config]
    }

    # Get rid of the helper
    rename .. {}
}

# ### ### ### ######### ######### #########
## Ready
return
