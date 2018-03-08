# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package pref::stdsr::oo 1.0
# Meta platform    tcl
# Meta require     pref
# Meta require     {registry -platform windows}
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# sroo.tcl --
#
#	This module implements cross platform standard commands to
#	save and restore user preferences, for use with the
#	preferences core module.
#
#	In contrast to pref::stdsr this module uses an OO approach to
#	encapsulate information like root path and version history in
#	the save/restore commands. Actually it generates save/restore
#	objects, and the preferences module is given proper command
#	prefixes for save and restore

#
# Copyright (c) 2006 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: pref.tcl,v 1.3 2000/10/31 23:31:00 welch Exp $
#

# ### ### ### ######### ######### #########
## Requirements

package require snit ; # OO core
package require pref ; # Preferences core.

namespace eval ::pref::stdsr::oo {}

#
# ### ### ### ######### ######### #########
## API

proc ::pref::stdsr::oo {name vh path registrykey} {
    global tcl_platform
    if {$tcl_platform(platform) eq "windows"} {
	package require registry
	return [::pref::stdsr::oo::windows $name $vh $registrykey]
    } else {
	return [::pref::stdsr::oo::unix    $name $vh $path]
    }
}

# ### ### ### ######### ######### #########
## API. Unix.

snit::type ::pref::stdsr::oo::unix {
    constructor {vh path} {
	set _versions $vh
	set _root     $path
	return
    }

    method save {group {groupkey {}}} {
	::pref::stdsr::oo::unixSave $_versions $_root $group $groupkey
    }

    method restore {group {groupkey {}}} {
	::pref::stdsr::oo::unixRestore $_versions $_root $group $groupkey
    }

    # ### ### ### ######### ######### #########
    ## Data structures.

    variable _root
    variable _versions

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## API. Windows.

snit::type ::pref::stdsr::oo::windows {
    constructor {vh registrykey} {
	set _versions $vh
	set _root     $registrykey
	return
    }

    method save {group} {
	::pref::stdsr::oo::winSave $_versions $_root $group
    }

    method restore {group {groupkey {}}} {
	::pref::stdsr::oo::winRestore $_versions $_root $group $groupkey
    }

    # ### ### ### ######### ######### #########
    ## Data structures.

    variable _root
    variable _versions

    ##
    # ### ### ### ######### ######### #########
}

#
# ### ### ### ######### ######### #########
## Internals. Horses doing the actual work.
#
# Derived from pref::stdsr::{unix,win}{Save,Restore}Cmd, having
# version/root information as arguments instead of namespaced
# variables.

# pref::stdsr::oo::unixSave --
#
#	Save the global preferences for a UNIX session.
#
# Arguments:
#	group	The name of the group to Save preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::oo::unixSave {versions root group {groupfile {}}} {
    if {$groupfile == {}} {set groupfile $group}

    set ver  [lindex $versions 0]
    set file [file join $root $ver $groupfile]

    set result [catch {
	file mkdir [file dirname $file]
	set id [open $file w]

        foreach pref [pref::GroupGetPrefs $group] {
	    puts $id "$pref [list [pref::prefGet $pref $group]]"
	}
	close $id
    } msg]

    pref::SetSaveMsg $msg
    return $result
}

# pref::stdsr::oo::unixRestore --
#
#	Restore the global preferences for a UNIX session.
#
# Arguments:
#	group	The name of the group to restore preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::oo::unixRestore {versions root group {groupfile {}}} {
    if {$groupfile == {}} {set groupfile $group}

    set result [catch {
	foreach ver $versions {
	    set file [file join $root $ver $groupfile]

	    set noFile [catch {set id [open $file r]}]
	    if {$noFile} continue

	    # Note: This uses the fact that \n is a valid separator
	    # for list elements.

	    pref::GroupSetPrefs $group [read $id]
	    close $id
	    break
	}
    } msg]

    pref::SetRestoreMsg $msg
    return $result
}

#
# ### ### ### ######### ######### #########

# pref::stdsr::oo::winSave --
#
#	Save the global preferences for a Windows session.
#
# Arguments:
#	group	The name of the group to Save preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::oo::winSave {versions root group {groupfile {}}} {
    if {$groupfile == {}} {set groupfile $group}

    # Conversion of standard separator to registry separator.
    set groupfile [string map [list / \\] $groupfile]

    set ver [lindex $versions 0]
    set key "$root\\$ver\\$groupfile"

    set result [catch {
	registry delete $key
	foreach pref [pref::GroupGetPrefs $group] {
	    registry set $key $pref [pref::prefGet $pref $group]
	}
    } msg]

    pref::SetSaveMsg $msg
    return $result
}

# pref::stdsr::oo::winRestore --
#
#	Restore the global preferences for a Windows session.
#
# Arguments:
#	group	The name of the group to restore preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::oo::winRestore {versions root group {groupfile {}}} {
    if {$groupfile == {}} {set groupfile $group}

    # Conversion of standard separator to registry separator.
    set groupfile [string map [list / \\] $groupfile]

    set result [catch {
	foreach ver $versions {
	    set key "$root\\$ver\\$groupfile"
	    set noKey [catch {
		set prefList {}
		foreach {valueName} [registry values $key] {
		    lappend prefList $valueName [registry get $key $valueName]
		}
	    }]

	    if {$noKey} continue
	    pref::GroupSetPrefs $group $prefList
	    break
	}
    } msg]

    pref::SetRestoreMsg $msg
    return $result
}

#
# ### ### ### ######### ######### #########
## Ready
return
