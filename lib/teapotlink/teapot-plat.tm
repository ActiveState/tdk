# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::plat 0.1
# Meta description Injection of the platform packages into Tcl 8.4 installations
# Meta description (identified by the path of their Tcl shell). Assumes that it
# Meta description can install them as Tcl Modules.
# Meta entrysource plat.tcl
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     platform::shell
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# Copyright (c) 2007-2009 ActiveState Software Inc
# ### ### ### ######### ######### #########
## Overview

# Injection of the platform packages into Tcl installations
# (identified by the path of their Tcl shell). Assumes that the
# installation is able to handle Tcl Modules.

# ### ### ### ######### ######### #########
## Requirements

package require fileutil
package require logger
package require platform::shell

logger::initNamespace ::teapot::plat
namespace eval        ::teapot::plat {}

# ### ### ### ######### ######### #########
## Implementation - shell manipulation

proc ::teapot::plat::setPkgBase {path} {
    variable base $path
    return
}

proc ::teapot::plat::shellValid {s} {
    # Check if the given shell 's' truly is a shell
    if {[catch {InfoLibraryPath $s}]} {
	return 0
    }
    return 1
}

proc ::teapot::plat::shellHasCode {s} {
    # Check if the given shell 's' has the platform packages.
    variable ipc
    if {![info exists ipc($s)]} {
	platform::shell::CHECK $s
	set ipc($s) [expr {![platform::shell::RUN $s {
	    puts [catch {package require platform}]
	}]}]
    }
    return $ipc($s)
}

proc ::teapot::plat::shellAddCode {s} {
    # Add the platform packages to the given 's', if not already
    # present.

    if {[shellHasCode $s]} {
	return -code error "Platform packages are already present"
    }

    shellAddCodeAt [InfoLibraryPath $s]
    return
}

proc ::teapot::plat::shellAddCodeAt {initlibdir} {
    # Add the platform packages to the given 's', if not already
    # present.

    # - Install the packages as Tcl Modules
    #   under [info library]/../tcl8/8.4

    ADD $initlibdir platform        platform
    ADD $initlibdir platform::shell platform/shell
    return
}

proc ::teapot::plat::ADD {initlibdir p pf} {
    set src [PkgPath $p]

    set sl  [split [fileutil::cat $src] \n]
    set pos [lsearch -glob $sl {package provide*}]
    set ver [lindex [lindex $sl $pos] 3]

    set dst [file join [TmPathAt $initlibdir 8.4] ${pf}-${ver}.tm]
    file mkdir [file dirname $dst]
    file copy -force $src $dst
    return
}

# ### ### ### ######### ######### #########
## Helper commands - Shell inspection

proc ::teapot::plat::PkgPath {p} {
    variable base
    if {$base eq ""} {
	# No base, use pkg mgmt to locate the package file
	# Note: This code has to track how tm.tcl creates the ifneeded
	# script for modules.
	return [lindex [package ifneeded $p [package require $p]] end]
    }
    if {$p eq "platform::shell"} {
	set p shell.tcl
    } else {
	append p .tcl
    }
    return [file join $base platform $p]
}

proc ::teapot::plat::TmPathAt {initlibdir v} {
    return [file join [file dirname $initlibdir] tcl8 $v]
}

proc ::teapot::plat::InfoLibraryPath {s} {
    variable ilc
    set s [file normalize $s]
    if {![info exists ilc($s)]} {
	# DANGER/NOTE: We are using internal commands of
	# package platform::shell here (CHECK, RUN).
	platform::shell::CHECK $s
	set ilc($s) [platform::shell::RUN $s {puts [info library]}]
    }
    return $ilc($s)
}

namespace eval ::teapot::plat {
    # Cache of shell -> info library mappings.

    # Ensure that while the package is in memory we run the expensive
    # query of each unique shell (identified by its absolute and
    # normalized path) only once.

    variable  ilc
    array set ilc {}

    variable  ipc
    array set ipc {}

    variable base {}
}

# ### ### ### ######### ######### #########
## Ready
