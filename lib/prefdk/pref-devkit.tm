# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package pref::devkit 1.0
# Meta platform    tcl
# Meta require     platform
# Meta require     pref
# Meta require     pref::stdsr::oo
# Meta require     projectInfo
# @@ Meta End

# -*- tcl -*-
# prefdk.tcl --
#
#	This module implements the global TDK preferences.
#	IOW the preferences which are shared across all
#	applications in the TDK.
#
# Copyright (c) 2005-2008 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: pref.tcl,v 1.3 2000/10/31 23:31:00 welch Exp $

##
## DANGER, dragons
##

# The groups created here are in conflict with groups used by the
# debugger. This is currently not a problem, because the debugger has
# no need of the data in here. Should this happen then the debugger
# will have to change, i.e. rename its groups to get out of the
# conflict.

##
## DANGER, dragons
##

# ### ### ### ######### ######### #########
## Requisites

package require pref            ; # Preference core
package require pref::stdsr::oo ; # Standard save/restore commands.
package require projectInfo     ; # Preference location and version information.
package require platform        ; # Platform identification.
package require repository::sys ; # Standard repository locations.

namespace eval ::pref::devkit {}

# ### ### ### ######### ######### #########
## Implementation

# ::pref::devkit::init --
#
#	Set up the preferences shared by the tools in the Tcl Dev
#	Kit. Both the groups needed, and their location.
#
# Arguments:
#	None.
#
# Results:
#	List of groups, in search order.

proc ::pref::devkit::init {} {
    # We create two group for the global TDK preferences. One, a
    # factory to hold the hardwired defaults, also serving as final
    # fallback. And two, the group holding the actual values, saved /
    # restored from the environment.

    # 1. pkgSearchPathList
    #    List of paths used as base paths when searching for .tap files.
    #    Also used when searching for .pcx files.
    #    Overall: Where we can find Tcl packages.
    #
    #    Hardwired to empty. No update callback. Use a direct trace in
    #    the app for this. /Otherwise I would have to write a callback
    #    here which can then be configured by the user of this package
    #    with an application callback to go where the applications
    #    actually wants it/.
    #

    # 1a. pkgRepositoryList

    # 2. prefixPath
    #    The path where to start looking for basekits, to be used as
    #    the initial directory when browsing for a -prefix file.
    #    Always contains the last path the user was at.
    #
    #    The installer defaults it to the 'bin' path of the first
    #    'lib' path put into the pkgSearchPathList
    #
    # 3. prefixList
    #    List of basekits used as -prefix files in the past. Instead
    #    of browsing for them we can do a quick selection from the
    #    dropdown list associated with the entry widget for -prefix
    #    files (Which is actually a dropdown-entry combobox).
    #
    #    Defaults to empty.
    #
    # 4. *MRUlist
    #    The values are used to initialize the combo-entries for the
    #    selection of archives and architectures in a project with
    #    previously made choices. The last value used is shown first.
    #
    # 6. defaultArchitectures
    #    Default values for archive and architecture selection in new
    #    projects.

    if {$::tcl_platform(os) == "Darwin"} {
	set tap   [list /Library/Tcl]
	set repos [list \
		       [::repository::sys::taphelpdir] \
		       [file join [file dirname [::repository::sys::taphelpdir]] teapot] \
		      ]
    } else {
	# Set by installer.
	set tap   {}
	set repos {}
    }

    ::pref::groupInit GlobalFactory [list \
	 pkgRepositoryList    $repos {} \
	 pkgRepositoryMRUList [list \
				   [::repository::sys::activestate] \
				  ] {} \
	 pkgSearchPathList    $tap {} \
	 pkgSearchPathMRUList {} {} \
	 prefixPath           {} {} \
	 prefixList           {} {} \
	 interpPath           {} {} \
	 interpList           {} {} \
	 iconPath             {} {} \
	 iconList             {} {} \
	 architecturesMRUList {
	     tcl
	     aix-powerpc
	     hpux-parisc
	     linux-glibc2.2-ix86
	     solaris2.10-ix86
	     solaris2.6-sparc
	     macosx-universal
	     win32-ix86
	 } {} \
	 defaultArchitectures [platform::identify] {} \
	 checkerDefaults {} \
	]

    # linux-glibc2.3-ia64
    # linux-glibc2.3-x86_64
    # hpux-ia64
    # solaris2.8-sparc
    # win32-x64

    set versions [linsert $projectInfo::prefsLocationHistory 0 $projectInfo::prefsLocation]
    set root     $projectInfo::prefsRoot
    set sr       [pref::stdsr::oo %AUTO% $versions $root $root]

    ::pref::groupNew GlobalDefault \
	[list $sr save] \
	[list $sr restore]

    # Copy the factory preferences into the default preferences. This
    # is to ensure that every preference in the GlobalFactory will
    # also appear in the GlobalDefault. Then restore the project,
    # clobbering the existing value with the data from the
    # environment.

    ::pref::groupCopy    GlobalFactory GlobalDefault
    ::pref::groupRestore GlobalDefault

    return {GlobalDefault GlobalFactory}
}

# ### ### ### ######### ######### #########
## Accessors for TDK preferences

proc ::pref::devkit::pkgSearchPathList {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   GlobalDefault pkgSearchPathList [lindex $args 0]
	Save pkgSearchPathList
    }
    return [pref::prefGet pkgSearchPathList]
}

proc ::pref::devkit::pkgSearchPathMRUList {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   GlobalDefault pkgSearchPathMRUList [lindex $args 0]
	Save pkgSearchPathMRUList
    }
    return [pref::prefGet pkgSearchPathMRUList]
}

# ### ### ### ######### ######### #########

proc ::pref::devkit::pkgRepositoryList {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   GlobalDefault pkgRepositoryList [lindex $args 0]
	Save pkgRepositoryList
    }
    return [pref::prefGet pkgRepositoryList]
}

proc ::pref::devkit::pkgRepositoryMRUList {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   GlobalDefault pkgRepositoryMRUList [lindex $args 0]
	Save pkgRepositoryMRUList
    }
    return [pref::prefGet pkgRepositoryMRUList]
}

# ### ### ### ######### ######### #########

proc ::pref::devkit::ArchivesMRUList {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   GlobalDefault archivesMRUList [lindex $args 0]
	Save archivesMRUList
    }
    return [pref::prefGet archivesMRUList]
}

proc ::pref::devkit::ArchitecturesMRUList {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   GlobalDefault architecturesMRUList [lindex $args 0]
	Save architecturesMRUList
    }
    return [pref::prefGet architecturesMRUList]
}

# ### ### ### ######### ######### #########

proc ::pref::devkit::defaultArchitectures {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   GlobalDefault defaultArchitectures [lindex $args 0]
	Save defaultArchitectures
    }
    return [pref::prefGet defaultArchitectures]
}

# ### ### ### ######### ######### #########

proc ::pref::devkit::defaultCheckerOptions {args} {
    if {[llength $args] > 1} {
	return -code error "wrong\#args, expected [lindex [info level 0] 0] ?value?"
    } elseif {[llength $args] == 1} {
	pref::prefSet   GlobalDefault checkerDefaults [lindex $args 0]
	Save checkerDefaults
    }
    return [pref::prefGet checkerDefaults]
}

# ### ### ### ######### ######### #########

proc ::pref::devkit::Save {key} {
    pref::groupSave GlobalDefault
    set m [pref::GetSaveMsg]
    if {$m eq ""} return
    variable saveerrorcmd
    if {$saveerrorcmd eq ""} return
    uplevel \#0 [linsert $saveerrorcmd end $key $m]
    return
}

proc ::pref::devkit::onSaveError {cmdprefix} {
    variable saveerrorcmd
    set      saveerrorcmd $cmdprefix
    return
}

namespace eval ::pref::devkit {
    variable saveerrorcmd {}
}

# ### ### ### ######### ######### #########
## Ready
return
