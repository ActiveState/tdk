# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package pref::teapot 1.0
# Meta platform    tcl
# Meta require     pref
# Meta require     pref::stdsr::oo
# Meta require     repository::sys
# @@ Meta End

# -*- tcl -*-
# preftp.tcl --
#
#	This module implements the global TEAPOT preferences.
#	IOW the preferences which are shared across all
#	applications in the TEAPOT. This can also be used by
#	TDK applications.
#
# Copyright (c) 2006 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: pref.tcl,v 1.3 2000/10/31 23:31:00 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require pref            ; # Preference core
package require pref::stdsr::oo ; # Standard save/restore commands.
package require repository::sys ; # Preference location and version information.

namespace eval ::pref::teapot {}

# ### ### ### ######### ######### #########
## Implementation

# ::pref::teapot::init --
#
#	Set up the preferences shared by the tools for the management
#	of TEAPOT repositories. The code expects that root and version
#	information come from the outside. This package only knows
#	which groups there are, and what keys they support.
#
# Arguments:
#	list of versions, root path of the preference store.
#
# Results:
#	List of groups, in search order.

proc ::pref::teapot::init {} {
    global tcl_platform

    # We create two groups for the global TEAPOT preferences. One, a
    # factory to hold the hardwired defaults, also serving as final
    # fallback. And two, the group holding the actual values, saved /
    # restored from the environment.

    # 1. defaultInstallation
    #    Path to the installation repository the client will install
    #    packages into by default.
    #
    #    Factory default is the result of the command 'repository::sys::userdir'.
    #    See the package 'repository::sys'.

    # 2. archivesList
    #    List of locations referencing the archives requested packages are
    #    searched in and retrieved from.
    #
    #    Factory default is a list containing one element, the
    #    location of the ActiveState repository. This information
    #    comes from 'repository::sys::activestate'.

    # 3. localCache
    #    A path. If set the proxy repository class will cache index
    #    databases in the local filesystem for quicker access (find,
    #    etc. become local db operations, not a round-trip over the
    #    network). An empty path is the same as not being set.

    # 4. lc,<url>
    #    Per url the cached status.

    # 5. ignorePatternList
    #    A list of glob patterns for the package generator. Applied when
    #    recursing the directory tree, skip all directories with names
    #    matching at least one of the patterns.

    # 6. httpProxy
    #    HOST:PORT to specify a proxy to go through when talking to
    #    repositories over the network.

    # 7. timeout
    #    SECONDS to specify the timeout after which to abort an operation
    #    when talking to repositories over the network.

    # 8. watchWorkspace
    #    Path to the directory to hold the persistent data (between
    #    checks) of the watch module. Default is
    #    repository::sys::watchworkspacedir.

    # 9. watchDestination
    #    Path to the repository holding the watch definitions to
    #    use. Also the destination for the generated source packages.
    #    Default is value of defaultInstallation (computed).

    # 10. watchLimit
    #    Maximum number of historical revisions to keep in the
    #    repository (watchDestination). Default is 4. A value of 0 means
    #	 'keep only current'. Any value < 0 means 'keep all'.

    if 0 {
	::pref::groupInit \
	    TeapotFactory \
	    [list \
		 defaultInstallation [repository::sys::userdir]            {} \
		 archivesList        [list [repository::sys::activestate]] {} \
		 localCache          {}                                    {} \
		 ignorePatternList   {CVS}                                 {} \
		]
    }

    ::pref::groupInit \
	TeapotFactory \
	[list \
	     defaultInstallation [repository::sys::userdir]            {} \
	     archivesList        [list [repository::sys::activestate]] {} \
	     localCache          [repository::sys::cachedir]           {} \
	     watchWorkspace      [repository::sys::watchworkspacedir]  {} \
	     watchDestination    {}                                    {} \
	     watchLimit          4                                     {} \
	     ignorePatternList   {CVS}                                 {} \
	     httpProxy           {}                                    {} \
	     timeout             -1                                    {} \
	    ]

    set versions [repository::sys::configHistory]
    set root     [repository::sys::configRoot]

    #puts D=|[repository::sys::userdir]|
    #puts V=|$versions|
    #puts R=|$root|

    # Automatic migration of preferences from old to new base.
    if {$tcl_platform(platform) eq "windows"} {
	#puts ==windows
	# Check registry for config key. If not present look for older
	# key and if present copy the registry tree.

	set new "$root\\[lindex $versions 0]\\TeapotConfiguration"
	#puts N=|$new|
	if {[catch {registry keys $new}]} {
	    #puts no-configuration-in-new-spot
	    set old [join [linsert [lrange [split $root \\] 0 end-1] end [lindex $versions 0] TeapotConfiguration] \\]
	    #puts O=|$old|
	    if {![catch {registry keys $old}]} {
		#puts has-configuration-in-old-spot\tcopy...([registry values $old])
		# Copy registry tree ...
		foreach v [registry values $old] {
		    #puts "registry set $new $v [registry get $old $v] [registry type $old $v]"
		    registry set $new $v [registry get $old $v] [registry type $old $v]
		}
	    }
	}
    } else {
	# Config directory missing? ... Look for old config directory
	# and if present copy its contents. If even the old directory
	# is missing nothing can be migrated, so we don't.
	if {![file exists $root]} {
	    set old [file join [file dirname [file dirname $root]] config]
	    if {[file exists $old]} {
		#puts "file copy -force $old $root"
		file mkdir [file dirname $root]
		file copy -force $old $root
	    }
	}
    }

    set sr       [pref::stdsr::oo %AUTO% $versions $root $root]

    ::pref::groupNew TeapotConfiguration \
	[list $sr save] \
	[list $sr restore]

    # Copy the factory values into the regular preferences. This
    # ensures that every preference in the Factory will also appear in
    # the Configuration. Then restore the project, clobbering the
    # existing values with the data from the environment.

    ::pref::groupCopy    TeapotFactory TeapotConfiguration
    ::pref::groupRestore               TeapotConfiguration

    return {TeapotConfiguration TeapotFactory}
}

# ### ### ### ######### ######### #########
## Accessors for TDK preferences

proc ::pref::teapot::defaultInstallation {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration defaultInstallation [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet defaultInstallation]
}

proc ::pref::teapot::archivesList {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration archivesList [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet archivesList]
}

proc ::pref::teapot::ignorePatternList {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration ignorePatternList [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet ignorePatternList]
}

proc ::pref::teapot::httpProxy {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration httpProxy [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet httpProxy]
}

proc ::pref::teapot::timeout {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration timeout [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet timeout]
}

proc ::pref::teapot::localCache {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration localCache [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet localCache]
}

proc ::pref::teapot::lc {url args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration lc,$url [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet lc,$url]
}

proc ::pref::teapot::lc {url args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefNew   TeapotConfiguration lc,$url [lindex $args 0] {}
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet lc,$url]
}

proc ::pref::teapot::lc/clear {} {
    foreach k [pref::prefList lc,* TeapotConfiguration] {
	pref::prefSet TeapotConfiguration $k {}
    }
    pref::groupSave TeapotConfiguration
    return
}

proc ::pref::teapot::lc/list {} {
    set res {}
    foreach k [pref::prefList lc,* TeapotConfiguration] {
	lappend res [lindex [split $k ,] 1]
    }
    return $res
}

proc ::pref::teapot::watchWorkspace {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration watchWorkspace [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }
    return [pref::prefGet watchWorkspace]
}

proc ::pref::teapot::watchDestination {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration watchDestination [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }

    set path [pref::prefGet watchDestination]
    if {$path ne ""} { return $path }
    return [pref::prefGet defaultInstallation]
}

proc ::pref::teapot::watchLimit {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   TeapotConfiguration watchLimit [lindex $args 0]
	pref::groupSave TeapotConfiguration
    }

    set value [pref::prefGet watchLimit]
    if {$value ne ""} { return $value }
    return 4
}

# ### ### ### ######### ######### #########
## Ready
return
