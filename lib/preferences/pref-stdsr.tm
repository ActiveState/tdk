# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package pref::stdsr 1.0
# Meta platform    tcl
# @@ Meta End

# -*- tcl -*-
# sr.tcl --
#
#	This module implements cross platform standard commands to
#	save and restore user preferences, for use with the
#	preferences core module.
#
# Copyright (c) 2005-2006 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: pref.tcl,v 1.3 2000/10/31 23:31:00 welch Exp $

#
# The package is configured with the following information:
#
# - A base path to the things holding preference groups.
#   Content is specific to the architecture:
#   * Unix:    file path
#   * Windows: registry key
#
# - A list of versions to look at when restoring. First item
#   is the version to save to.
#

#
# The package provides _NO_ hooks at all. Neither for vetoing
# save/restore, nor for updating preference values changed implicitly
# during execution and not the user (Example: Window locations). This
# type of processing is application-specific and can be done there, by
# wrapping commands around the standard commands of this package and
# registered these with the relevant groups.
#
# This pattern can and has to be used to manipulate group names as
# well, for example prefixing all with a common string. Like the
# application name.
#

namespace eval pref::stdsr {
    # The root path for the preference groups saved/restored through
    # this package.

    variable theRoot {}

    # The list of versions to query when restoring a preference group.

    variable versions {}
}

# pref::stdsr::rootSet --
#
#	Set root path for preference groups.
#
# Arguments:
#	root	The path to set.
#
# Results:
#	None.

proc pref::stdsr::rootSet {root} {
    variable theRoot $root
    return
}

# pref::stdsr::versionHistorySet --
#
#	Set list of versions to query, in query order.
#	First element is version to save to.
#
# Arguments:
#	v	The versions to query.
#
# Results:
#	None.

proc pref::stdsr::versionHistorySet {v} {
    variable versions $v
    return
}

# ### ### ### ######### ######### #########
## Cross platform save/restore, switches at runtime between the
## architecture specific commands.

# pref::stdsr::restoreCmd --
#
#	Restore preferences for a session.
#
# Arguments:
#	group	The name of the group to restore preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::restoreCmd {group} {
    if {$::tcl_platform(platform) eq "windows"} {
	winRestoreCmd $group
    } else {
	unixRestoreCmd $group
    }
}

# pref::stdsr::saveCmd --
#
#	Save preferences for a session.
#
# Arguments:
#	group	The name of the group to Save preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::saveCmd {group} {
    if {$::tcl_platform(platform) eq "windows"} {
	winSaveCmd $group
    } else {
	unixSaveCmd $group
    }
}

# ### ### ### ######### ######### #########

# pref::stdsr::winRestoreCmd --
#
#	Restore the global preferences for a Windows session.
#
# Arguments:
#	group	The name of the group to restore preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::winRestoreCmd {group {groupfile {}}} {
    variable versions
    variable theRoot

    if {$groupfile == {}} {set groupfile $group}

    # Conversion of standard separator to registry separator.
    set groupfile [string map [list / \\] $groupfile]

    set result [catch {
	foreach ver $versions {
	    set key "$theRoot\\$ver\\$groupfile"
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

# pref::stdsr::winSaveCmd --
#
#	Save the global preferences for a Windows session.
#
# Arguments:
#	group	The name of the group to Save preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::winSaveCmd {group {groupfile {}}} {
    variable versions
    variable theRoot

    if {$groupfile == {}} {set groupfile $group}

    # Conversion of standard separator to registry separator.
    set groupfile [string map [list / \\] $groupfile]

    set ver [lindex $versions 0]
    set key "$theRoot\\$ver\\$groupfile"

    set result [catch {
	registry delete $key
	foreach pref [pref::GroupGetPrefs $group] {
	    registry set $key $pref [pref::prefGet $pref $group]
	}
    } msg]

    pref::SetSaveMsg $msg
    return $result
}

# pref::stdsr::unixRestoreCmd --
#
#	Restore the global preferences for a UNIX session.
#
# Arguments:
#	group	The name of the group to restore preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::unixRestoreCmd {group {groupfile {}}} {
    variable versions
    variable theRoot

    if {$groupfile == {}} {set groupfile $group}

    set result [catch {
	foreach ver $versions {
	    set file [file join $theRoot $ver $groupfile]

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

# pref::stdsr::unixSaveCmd --
#
#	Save the global preferences for a UNIX session.
#
# Arguments:
#	group	The name of the group to Save preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc pref::stdsr::unixSaveCmd {group {groupfile {}}} {
    variable versions
    variable theRoot

    if {$groupfile == {}} {set groupfile $group}

    set ver  [lindex $versions 0]
    set file [file join $theRoot $ver $groupfile]

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

# ### ### ### ######### ######### #########
return

