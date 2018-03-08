# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::link 0.1
# Meta description Management of links between localma repositories and Tcl
# Meta description installations (identified by the path of their Tcl shell)
# Meta entrysource link.tcl
# Meta included    boot.txt package.txt
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     platform::shell
# Meta require     repository::localma
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# Copyright (c) 2007 ActiveState Software Inc
# ### ### ### ######### ######### #########
## Overview

# Management of links between localma repositories and Tcl
# installations (identified by the path of their Tcl shell)

# ### ### ### ######### ######### #########
## Requirements

package require fileutil
package require logger
package require platform::shell
package require repository::localma

logger::initNamespace ::teapot::link
namespace eval        ::teapot::link {}

# ### ### ### ######### ######### #########
## Implementation - shell manipulation

proc ::teapot::link::shellValid {s} {
    # Check if the given shell 's' truly is a shell
    if {[catch {InfoLibraryPath $s}]} {
	return 0
    }
    return 1
}

proc ::teapot::link::shellHasCode {s} {
    # Check if the given shell 's' has the teapot linkage code.
    return [shellHasCodeAt [InfoLibraryPath $s]]
}

proc ::teapot::link::shellHasCodeAt {initlibdir} {
    # Check if the given shell 's' has the teapot linkage code.
    set lines [split [fileutil::cat [file join $initlibdir init.tcl]] \n]
    set pos   [lsearch -glob $lines {*TEAPOT LINK BOOT BEGIN*}]
    return [expr {$pos < 0 ? 0 : 1}]
}

proc ::teapot::link::shellAddCode {s} {
    # Add the teapot linkage code to the given 's', if not already
    # present.

    if {[shellHasCode $s]} {
	return -code error "Link code is already present"
    }

    # Two steps
    # -1- Extend "init.tcl" with the link boot code.
    # -2- Install the actual link package as a Tcl Module
    #     under [info library]/../tcl8/8.4

    shellAddCodeAt [InfoLibraryPath $s]
    return
}

proc ::teapot::link::shellAddCodeAt {initlibdir} {
    # Add the teapot linkage code to the given 's', if not already
    # present.

    # Two steps
    # -1- Extend "init.tcl" with the link boot code.
    # -2- Install the actual link package as a Tcl Module
    #     under [info library]/../tcl8/8.4

    variable boot_code
    variable pkg_code

    # Extend existing file
    set it [file join $initlibdir init.tcl]
    fileutil::appendToFile $it "\n[Code $boot_code]"

    # Create new file
    set sc  [Code $pkg_code]

    # Might pull version info out of the meta data instead.
    set sl  [split $sc \n]
    set pos [lsearch -glob  $sl {*package provide*}]
    set ver [lindex [lindex $sl $pos] 3]

    set dst [file join [TmPathAt $initlibdir 8.4] \
		 activestate teapot link-${ver}.tm]
    file mkdir [file dirname $dst]
    fileutil::writeFile $dst $sc
    return
}

proc ::teapot::link::shellInfo {s} {
    set f [TeapotPath $s]
    if {![file exists $f]} {
	set f [TeapotPathOld $s]
    }
    if {![file exists $f]} {return {}}

    set res {}
    # FUTURE: struct::list map NORM
    foreach f [split [string trim [fileutil::cat $f]] \n] {
	lappend res [NORM $f]
    }
    return [lsort -unique $res]
}

if {$tcl_platform(platform) eq "windows"} {
    proc ::teapot::link::NORM {f} {
	return [string tolower [file nativename [file normalize $f]]]
    }
} else {
    proc ::teapot::link::NORM {f} {
	return [file nativename [file normalize $f]]
    }
}

# ### ### ### ######### ######### #########
## Implementation - link manipulation

proc ::teapot::link::connect {r s {direction both}} {
    # Link repository R and shell S to each other. Assumes that R is
    # of type localma.

    set r [NORM $r]
    set s [NORM $s]

    if {($direction eq "2shell") || ($direction eq "both")} {
	set ro [repository::localma %AUTO% -location $r]
    }

    if {($direction eq "2repo") || ($direction eq "both")} {
	set so [TeapotPath    $s]
	set sb [TeapotPathOld $s]

	# Check that we are looking at a file, and that it is writable.
	if {[file exists $sb]} {
	    if {[file isdirectory $sb]} {
		return -code error -errorcode LINK "The link management file \"$sb\" is a directory."
	    }
	    if {![file writable $sb]} {
		return -code error -errorcode LINK "The link management file \"$sb\" cannot be written."
	    }
	} elseif {[file exists $so]} {
	    if {[file isdirectory $so]} {
		return -code error -errorcode LINK "The link management file \"$so\" is a directory."
	    }
	    if {![file writable $so]} {
		return -code error -errorcode LINK "The link management file \"$so\" cannot be written."
	    }
	}
    }

    # Add references R -> S, and S -> R. Ignore the parts where the
    # connection is already present.

    if {($direction eq "2shell") || ($direction eq "both")} {
	if {![$ro has-shell $s]} {
	    $ro add-shell $s
	}
	$ro destroy
    }

    if {($direction eq "2repo") || ($direction eq "both")} {
	if {[file exists $sb]} {
	    # old-style setup. Keep it up to date.
	    if {[LoadAndSearch $sb $r sx] < 0} {
		fileutil::appendToFile $sb $r\n
	    }
	    return
	}

	# new-style setup

	if {![file exists $so] || ([LoadAndSearch $so $r sx] < 0)} {
	    fileutil::appendToFile $so $r\n
	}
    }
    return
}

proc ::teapot::link::disconnect {r s} {
    # Remove the link between repository R and shell S.
    # Cleans up any partial information too.

    set r [NORM $r]
    set s [NORM $s]

    # Bogus repository is fine, we can still remove it from the shell.
    catch {
	set ro [repository::localma %AUTO% -location $r]
	$ro remove-shell $s
	$ro destroy
    }

    # Ignore bogus shell 
    if {[catch {
	set so [TeapotPath $s]
	set sb [TeapotPathOld $s]
    }]} return

    # Ignore missing backlink, the shell has no links at all
    if {
	![file exists $so] &&
	![file exists $sb]
    } return

    if {[file exists $sb]} {
	# old-style setup. NOTE! Keep the file, even if empty, to
	# trigger the old-style code path in connect, s.a.

	set pos [LoadAndSearch $sb $r sx]

	# Ignore missing backlink, shell does not link to repository
	if {$pos < 0} return

	set sx [lreplace $sx $pos $pos]
	if {[llength $sx]} {
	    set data [join $sx \n]\n
	} else {
	    set data {}
	}
	fileutil::writeFile $sb $data
	return
    }

    # new-style setup

    set pos [LoadAndSearch $so $r sx]

    # Ignore missing backlink, shell does not link to repository
    if {$pos < 0} return

    set sx [lreplace $sx $pos $pos]

    if {[llength $sx]} {
	fileutil::writeFile $so [join $sx \n]\n
    } else {
	file delete -force $so
    }
    return
}

proc ::teapot::link::LoadAndSearch {so r sv} {
    upvar 1 $sv sx
    set sx  [split [string trim [fileutil::cat $so]] \n]
    return [lsearch -exact $sx $r]
}

# ### ### ### ######### ######### #########
## Helper commands - Shell inspection

proc ::teapot::link::TmPath {s v} {
    return [file join [file dirname [InfoLibraryPath $s]] tcl8 $v]
}

proc ::teapot::link::TmPathAt {initlibdir v} {
    return [file join [file dirname $initlibdir] tcl8 $v]
}

proc ::teapot::link::TeapotPath {s} {
    return [file join [InfoLibraryPath $s] teapot-link.txt]
}

proc ::teapot::link::TeapotPathOld {s} {
    return [file join [InfoLibraryPath $s] teapot.txt]
}

proc ::teapot::link::InitTclPath {s} {
    return [file join [InfoLibraryPath $s] init.tcl]
}

proc ::teapot::link::InfoLibraryPath {s} {
    variable ilc
    set s [NORM $s]
    if {![info exists ilc($s)]} {
	# DANGER/NOTE: We are using internal commands of
	# package platform::shell here (CHECK, RUN).
	platform::shell::CHECK $s

	# NOTE: Take the last line of the output. Only this can be the
	# NOTE: path we are looking for. Any output before that has to
	# NOTE: come from init.tcl or .tclshrc and belongs to the
	# NOTE: user, not us.

	# NOTE II: This scheme breaks if someone manages to create a
	# NOTE II: path containing one or more newline characters.
	# NOTE II: Ignoring that for now as way to weird to occur.

	set ilc($s) [NORM [lindex [split [string trim \
	       [platform::shell::RUN $s {puts [info library];exit 0}] \
        \n] \n] end]]
    }
    return $ilc($s)
}

proc ::teapot::link::Code {s} {
    return "[string map "\n\t \n" [string trimright $s]]\n"
}

namespace eval ::teapot::link {
    # Cache of shell -> info library mappings.

    # Ensure that while the package is in memory we run the expensive
    # query of each unique shell (identified by its absolute and
    # normalized path) only once.

    variable  ilc
    array set ilc {}

    variable boot_code {
	# TEAPOT LINK BOOT BEGIN -*- tcl -*-
	# Copyright (C) 2006-2007 ActiveState Software Inc.
	if {![interp issafe] && ![catch {package require platform}]} {
	    package require activestate::teapot::link
	    ::activestate::teapot::link::setup
	}
	# TEAPOT LINK BOOT END
    }

    variable pkg_code {
	# -*- tcl -*-
	# Copyright (C) 2006-2007 ActiveState Software Inc.
	# ### ### ### ######### ######### #########

	# @@ Meta Begin
	# Package ::activestate::teapot::link 1.2
	# Meta platform    tcl
	# Meta summary     Linking Tcl shells with local transparent Teapot repositories
	# Meta description Teapot support functionality.
	# Meta description Standard package to register a set of local transparent teapot
	# Meta description repositories with a Tcl shell. The information used by this
	# Meta description package is stored in teapot.txt under 'info library' and
	# Meta description accessible by teacup and other tools.
	# Meta category    Teapot shell linkage
	# Meta subject     teapot shell link
	# Meta require     platform
	# Meta require     {Tcl -require 8.4}
	# @@ Meta End

	# ### ### ### ######### ######### #########
	## Requisites

	package require platform
	namespace eval ::activestate::teapot::link {}

	# ### ### ### ######### ######### #########
	## Implementation

	proc ::activestate::teapot::link::setup {} {
	    # The database "teapot.txt" is a text file, containing one
	    # repository path per line. It is allowed to be absent, if no
	    # repositories are linked to the shell at all.

	    set rl [file join [info library] teapot-link.txt]
	    set fb 0

	    # Fall back to old link data file if the modern one is not present.
	    if {![file exists $rl]} {
		set rl [file join [info library] teapot.txt]
		set fb 1
	    }

	    # Not a failure, quick exit if there are no linked repositories.
	    if {![file exists  $rl]} return

	    # Try to move the shell from old to modern link file. Its ok to
	    # fail, just inconvenient.
	    if {$fb} {
		catch {
		    file copy $rl [file join [info library] teapot-link.txt]
		}
	    }

	    # Want to fail hard on these, indicators of major corruption.
	    #if {![file isfile   $rl]} return
	    #if {![file readable $rl]} return

	    # We trim to remove the trailing newlines which would otherwise
	    # translate into empty list elements = empty repodir paths.
	    set repositories \
		[split [string trim [read [set chan [open $rl r]]][close $chan] \n] \n]

	    usel $repositories
	}

	proc ::activestate::teapot::link::use {args} {usel $args}
	proc ::activestate::teapot::link::usel {repositories} {

	    # Make all repository subdirectories available which can contain
	    # packages for the architecture currently executing this Tcl
	    # script. This code assumes a directory structure as created by
	    # 'repository::localma', for all specified directories.

	    foreach arch [platform::patterns [platform::identify]] {
		foreach repodir $repositories {
		    set base [file join $repodir package $arch]
		    # Optimize a bit, missing directories are left out
		    # of searches.
		    if {![file exists $base]} continue

		    # The lib subdirectory on the other hand contains regular
		    # packages and can be used by all Tcl shells. There is no
		    # need to catch this.

		    lappend ::auto_path [file join $base lib]

		    # The teapot subdirectory contains Tcl Modules. This is
		    # relevant only to a tcl shell which is able to handle
		    # such. Like ActiveTcl. We catch our action, just in case
		    # a shell is used which is not able to handle Tcl Modules.

		    catch {::tcl::tm::roots [list [file join $base teapot]]}
		}
	    }

	    # Disabled, counterproductive. platform is installed as a TM, be
	    # it in AT, or by injected by 'teacup setup'. And this package is
	    # a TM as well. Which means that regular Pkg Mgmt has nothing
	    # loaded which has to be forgotten or reloaded. Poking it will
	    # cause a crawl which is not needed and just takes time.
	    #catch {package require __teapot__}
	    set ::errorInfo {}
	    return
	}

	# ### ### ### ######### ######### #########
	## Ready

	package provide activestate::teapot::link 1.1
    }
}

# ### ### ### ######### ######### #########
## Ready
