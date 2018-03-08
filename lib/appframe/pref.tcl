# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pref.tcl --
#
#	This module implements a cross platform mechanism to store
#	user preferences.
#
# Copyright (c) 1998-2000 Ajuba Solutions

# 
# RCS: @(#) $Id: pref.tcl,v 1.3 2000/10/31 23:31:00 welch Exp $

# The preference module is a generic system used to store preferences for an 
# application.  Each preference is contained in a group.  A group contains one
# or more preferences and knows how to save and restore the preferences.  A
# group knows when one of its preferences has been changed and the user can
# query the group for this information.
# 
# Groups are created using the groupNew or groupInit APIs.  The groupNew
# routine creates a dynamic group that can save and restore the set of groups.
# Groups created using the groupInit routine are considered "primordial"
# groups, that is, they are hard coded defaults meant to initalize groups
# created with the groupNew routine.  Therefore, groups created by the
# groupInit routine do not need to save and restore preferences.  
#
# In any application one or more groups of preferences can exist at the same
# time, and the groups can contain identical preferences.  To retrieve the
# value of a preference you can specify exactly which group the preference
# belongs to or you can register the lookup order for the prefernces using the
# setGroupOrder API.  Using this method, the first group to contain the
# preference is the group that is used to return the value.

package provide pref 1.0
namespace eval pref {
    # The list of groups in order with the first element being the 
    # first group to be searched for a preference.

    variable groupOrder {}

    # The groups array stores all of the group objects.  Group objects
    # are responsible for saving and restoring preferences.  Preferences
    # are stored in groups according to how the data should be saved and
    # restored.

    variable groups

    # The dirty array stores which groups have preferences 
    # that have been changed.

    variable dirty

    # The following variables store the error message reported when 
    # groups are saved or restored and an error occurs.

    variable groupSaveMsg    {}
    variable groupRestoreMsg {}
}

# pref::groupNew
#
#	Create a new group and register how to restore and save 
#	the group preferences.  The save and restore commands 
#	need to return a boolean value.  1 means that the command 
#	had an error while executing, 0 means it succeeded.
#
# Arguments:
#	group		The name of the group to create.  Use this name 
#			when saving or restoring this group.
#	saveCmd		The command to call to save the group preferences.
#	restoreCmd	The command to call to restore the group preferences.
#
# Results: 
#	None.

proc pref::groupNew {group {saveCmd {}} {restoreCmd {}}} {
    # Delete this group in order to assure that all information
    # is current.

    if {[pref::groupExists $group]} {
	pref::groupDelete $group
    }

    # Initialize entries for the save command, the restore command 
    # and the arrays for preferences in this group.

    set ::pref::groups($group,saveCmd)    $saveCmd
    set ::pref::groups($group,restoreCmd) $restoreCmd

    # Set the groug dirty bit to false indicating that no
    # preferences have been changed and need saving.

    pref::groupSetDirty $group 0

    array set ::pref::value$group  {}
    array set ::pref::update$group {}
    return
}

# pref::groupSave
#
#	Call the saveCmd registered for this group.
#
# Arguments:
#	group	The name of the group to save.
#
# Results: 
#	Returns 0 if the groups preferences were preserved, or
#	1 if all of the state could not be stored.

proc pref::groupSave {group} {
    variable groups

    if {([pref::groupExists $group]) && ($groups($group,saveCmd) != {})} {
	# Save the group preferences using the registered save command.  
	# If the save succeeded then unset the group dirty bit since the 
	# preferences have been saved.

	set result [eval $groups($group,saveCmd) $group]
	if {!$result} {
	    pref::groupSetDirty $group 0
	}
	return $result
    } else {
	return 1
    }
}

# pref::groupRestore
#
#	Call the restoreCmd registered for this group.  All of the 
#	preferences in this group will be reinitialized, but the 
#	update commands for each prefernece will not be called.  Call
#	the groupApply to set all of the values and call approrpriate
#	update commands.
#
# Arguments:
#	group	The name of the group to restore.
#
# Results: 
#	Returns 0 if the groups preferences were restored, or
#	1 if all of the state could not be restored.

proc pref::groupRestore {group} {
    variable groups

    # The restore command should register all preference groups
    # inside of group and initialize all preference values.  The 
    # preferences should be registered as a requested value, (using 
    # the pref::prefSet API) so the values can be set with or without 
    # calling the update commands (see the pref::groupApply command.)

    if {([pref::groupExists $group]) && ($groups($group,restoreCmd) != {})} {
	return [eval $groups($group,restoreCmd) $group]
    } else {
	return 1
    }
}

# pref::groupUpdate --
#
#	Call the update command foreach pref in group.
#
# Arguments:
#	group	The name of the group to update.
#
# Results:
#	Returns 1 if the preferences were updated OK, or
#	0 if any update command generated an error.

proc pref::groupUpdate {group} {
    if {![pref::groupExists $group]} {
	error "\"$group\" does not exist."
    }

    # Get the update commands for each preference in this group.
    # Cache the values so update commands, which may be mapped to 
    # multiple preferences, are called only once.

    set updateCmds {}
    foreach pref [pref::GroupGetPrefs $group] {
	set uCmd [pref::PrefGetUpdateCmd $group $pref]
	if {($uCmd != {}) && ([lsearch $updateCmds $uCmd] < 0)} {
	    lappend updateCmds $uCmd
	}
    }

    # Now call each update command.  Make sure to catch any errors
    # generated by the update calls.
    
    set result 1
    foreach uCmd $updateCmds {
	if {[catch {eval $uCmd}]} {
	    set result 0
	}
    }
    return $result    
}

# pref::groupInit --
#
#	Initialize a group with hardcoded prefences.  If the group
#	does not exist, then create one with no save and restore values.
#
# Arguments:
#	group		The name of the group being initialized.
#	prefSettings	An ordered list of preference settings:
#			 pref	The name of the preference.
#			 value	The default value for the preference.
#			 update	The command too call when the pref 
#				is changed.	
#
# Results:
#	None.

proc pref::groupInit {group prefSettings} {
    if {![pref::groupExists $group]} {
	pref::groupNew $group
    } else {
	# Delete any existing information about this group.

	pref::groupDelete $group

	# Set the group dirty bit to false indicating that no
	# preferences have been changed and need saving.
	
	pref::groupSetDirty $group 0

	# Initialize the arrays to be empty.

	array set ::pref::value$group  {}
	array set ::pref::update$group {}
    }

    foreach {pref value update} $prefSettings {
	set ::pref::value${group}($pref)  $value
	set ::pref::update${group}($pref) $update
    }
    return
}

# pref::groupCopy --
#
#	Copy the preferences from group1 into group2.  The update commands
#	are not called.
#
# Arguments:
#	group1		The name of the group to copy from.
#	group2		The name of the group to copy to.
#
# Results:
#	None.

proc pref::groupCopy {group1 group2} {
    if {![pref::groupExists $group1]} {
	error "cannot copy groups, \"$group1\" does not exist."
    }
    if {![pref::groupExists $group2]} {
	error "cannot copy groups, \"$group2\" does not exist."
    }

    array set ::pref::value$group2  [array get ::pref::value$group1]
    array set ::pref::update$group2 [array get ::pref::update$group1]
    return
}

# pref::groupApply
#
#	Move all of the requested values from group1 into group2, then 
#	call the update commands for each preference whose state has
#	changed.  The preferences in group1 must be a subset of group2.
#
# Arguments:
#	group1		The name of the group to move from.
#	group2		The name of the group to move into.
#
# Results: 
#	Returns 1 if the the prefs were copied and all the update commands
#	passed, or 0 if any of the update commands failed.

proc pref::groupApply {group1 group2} {
    if {![pref::groupExists $group1]} {
	error "cannot apply groups, \"$group1\" does not exist."
    }
    if {![pref::groupExists $group2]} {
	error "cannot apply groups, \"$group2\" does not exist."
    }

    set updateCmds {}
    foreach pref [pref::GroupGetPrefs $group1] {
	set p1 [pref::prefGet $pref $group1]
	set p2 [pref::prefGet $pref $group2]

	if {$p1 != $p2} {
	    # Move the requested value into the actual value.

	    set ::pref::value${group2}($pref) \
		    [set ::pref::value${group1}($pref)]

	    # Set the groug dirty bit to true indicating that a
	    # preference has changed and need saving.

	    pref::groupSetDirty $group2 1

	    # Add this update command to the update list.  Only add the
	    # command if it is not already in the list, so duplicate 
	    # commands are not called multiple times.

	    set uCmd [pref::PrefGetUpdateCmd $group1 $pref]
	    if {($uCmd != {}) && ([lsearch $updateCmds $uCmd] < 0)} {
		lappend updateCmds $uCmd
	    }
	}
    }

    # Now call each update command.  Make sure to catch any errors
    # generated by the update calls.
    
    set result 1
    foreach uCmd $updateCmds {
	if {[catch {eval $uCmd}]} {
	    set result 0
	}
    }
    return $result
}

# pref::groupDelete --
#
#	Delete the group and remove its preferences so that the lookup
#	mechanism doesn't find the preferences in this group by mistake.
#
# Arguments:
#	group	The name of the group to delete.
#
# Results:
#	None

proc pref::groupDelete {group} {
    if {[info exists ::pref::groups($group,saveCmd)]} {
	unset ::pref::groups($group,saveCmd)
    }
    if {[info exists ::pref::groups($group,restoreCmd)]} {
	unset ::pref::groups($group,restoreCmd)
    }
    if {[info exists ::pref::value$group]} {
	unset ::pref::value$group
    }
    if {[info exists ::pref::update$group]} {
	unset ::pref::update$group
    }
    if {[info exists ::pref::dirty($group)]} {
	unset ::pref::dirty($group)
    }
    return
}

# pref::groupIsDirty --
#
#	Get the group dirty bit that indicates if any of the preference
#	in the group have been changed.
#
# Arguments:
#	group	The name of the group to check.
#
# Results:
#	Return a boolean, 1 means that one or more preferences has changed.

proc pref::groupIsDirty {group} {
    if {![pref::groupExists $group]} {
	error "group \"$group\" does not exist."
    }
    return $::pref::dirty($group)
}

# pref::groupSetDirty --
#
#	Set the group dirty bit that indicates if any of the preferences
#	in the group have been changed.
#
# Arguments:
#	group	The name of the group to check.
#	dirty	The boolean indicating if prefences have been changed in
#		this group.
#
# Results:
#	None.

proc pref::groupSetDirty {group dirty} {
    set ::pref::dirty($group) $dirty
    return
}

# pref::groupExist
#
#	Determine if the group exists.
#
# Arguments:
#	group	The name of the group.
#
# Results: 
#	Returns 1 if the group exists.

proc pref::groupExists {group} {
    return [info exists ::pref::value$group]
}

# pref::groupPrint --
#
#	Print the group contents and current state.
#
# Arguments:
#	group	The name of the group to print.
#
# Results:
#	None.

proc pref::groupPrint {group} {
    if {![pref::groupExists $group]} {
	puts "Group Doesn't Exist"
	return
    }
    foreach pref [lsort [array names ::pref::value${group}]] {
	set v [set ::pref::value${group}($pref)]
	puts "$pref \t=  $v"
    }
    puts "Dirty? [pref::groupIsDirty $group]"
    return
}

# pref::prefNew
#
#	Add a new preference to a group.  The update command is not called.
#
# Arguments:
#	group	The name of the group to store this pref.
#	pref	The name of the preference.
#	value	The new value for the preference.
#	update	The new value for the update command.
#
# Results: 
#	None.

proc pref::prefNew {group pref value update} {
    if {![pref::groupExists $group]} {
	error "group \"$group\" does not exist."
    }

    # Replace the old value with the new value.
    
    set ::pref::value${group}($pref)  $value
    set ::pref::update${group}($pref) $update

    return
}

# pref::prefGet
#
#	Retrieve the preference value.
#
# Arguments:
#	pref	The name of the preference.
#	group	Explicitly specify which group to get from.
#
# Results: 
#	Return the actual value for the preference.  If the preference
#	does not exist, then an error is generated.

proc pref::prefGet {pref {group {}}} {
    set group [pref::PrefLocateGroup $pref $group]
    if {$group == {}} {
	error "pref \"$pref\" does not exist."
    }
    return [set ::pref::value${group}($pref)]
}

# pref::prefSet --
#
#	Set the preference value.  Do not call the update command.  The
#	preference must exist
#
# Arguments:
#	group		The name of the group to store this pref.
#	pref		The name of the preference.
#	value		The new value for the preference.
#
# Results: 
#	None.

proc pref::prefSet {group pref value} {
    if {![pref::groupExists $group]} {
	error "group \"$group\" does not exist."
    }
    if {![pref::prefExists $pref $group]} {
	error "pref \"$pref\" does not exist."
    }

    # Replace the old value with the new value.
    
    set ::pref::value${group}($pref) $value
    pref::groupSetDirty $group 1
    return
}

# pref::prefExists
#
#	Determine is a preference exists.
#
# Arguments:
#	pref	The name of the preference.
#	group	Explicitly specify which group(s) to look at.
#
# Results: 
#	Return 1 if the preference exists.

proc pref::prefExists {pref {group {}}} {
    # If the preferences cannot be located in any groups, then it does
    # not exist.  The list of groups is set by the pref::setGroupOrder 
    # API.

    return [expr {[pref::PrefLocateGroup $pref $group] != {}}]
}

# pref::prefVar
#
#	Get a trace var name for the preference.  This should be used
#	when setting widget trace var commands.
#
# Arguments:
#	pref	The name of the preference.
#	group	Specify which group to get from.
#
# Results: 
#	Return the name of the variable to trace on for setting
# 	requested values in a preference.  An error is generated 
# 	if the preference does not exist.

proc pref::prefVar {pref {group {}}} {
    set group [pref::PrefLocateGroup $pref $group]
    if {$group == {}} {
	error "pref \"$pref\" does not exist."
    }
    return "::pref::value${group}($pref)"
}

# pref::setGroupOrder
#
#	Set the group lookup hierarchy for searching across multiple
#	groups, looking for a preference.  No errors are generated
#	if the group does not exist.
#
# Arguments:
#	groups		The list of groups with the first element being
#			the first group to be searched.
#
# Results: 
#	None.

proc pref::setGroupOrder {groups} {
    set ::pref::groupOrder $groups
    return
}

# pref::getGroupOrder
#
#	Get the current group order.
#
# Arguments:
#	None.
#
# Results: 
#	The group order list.

proc pref::getGroupOrder {} {
    return $::pref::groupOrder
}

# pref::GroupSetPrefs --
#
#	Set a list of the preferences for an existing group.
#
# Arguments:
#	group	The group to get the list from.
#	prefs	An ordered list of preference settings:
#			 pref	The name of the preference.
#			 value	The default value for the preference.
#
# Results:
#	None

proc pref::GroupSetPrefs {group prefs} {
    array set ::pref::value$group $prefs
    return
}

# pref::GroupGetPrefs --
#
#	Get a list of the preferences for the group.
#
# Arguments:
#	group	The group to get the list from.
#
# Results:
#	A list of preference names.

proc pref::GroupGetPrefs {group} {
    return [array names ::pref::value$group]
}

# pref::PrefLocateGroup
#
#	Locate the group for a preference.  The list returned
#	by pref::getGroupOrder is used as the searching order.
#
# Arguments:
#	pref		The name of the preference.
#	groupOrder	Explicitly specify which groups to look into.  If 
#			an empty string is passed, then all the registered
#			groups are looked at.
#
# Results: 
#	Returns the group name, or {} if one does not exist.

proc pref::PrefLocateGroup {pref {groupOrder {}}} {
    if {$groupOrder == {}} {
	set groupOrder [pref::getGroupOrder]
    }
    foreach group $groupOrder {
	if {[info exists ::pref::value${group}($pref)]} {
	    return $group
	}
    }
    return {}
}

# pref::PrefGetUpdateCmd
#
#	Get the update command fot the preference.
#
# Arguments:
#	group	The name of the group containing the preference.
#	pref	The name of the preference.
#
# Results: 
#	Returns the update command.

proc pref::PrefGetUpdateCmd {group pref} {
    if {[info exists ::pref::update${group}($pref)]} {
	return [set ::pref::update${group}($pref)]
    } else {
	return {}
    }
}

# pref::SetSaveMsg --
#
#	Set the error message when a groups save command is executed.
#
# Arguments:
#	msg	The message to store.
#
# Results:
#	None.

proc pref::SetSaveMsg {msg} {
    set pref::groupSaveMsg $msg
    return
}

# pref::GetSaveMsg --
#
#	Get the error message set after a groups save command is executed.
#
# Arguments:
#	None.
#
# Results:
#	The cached message.

proc pref::GetSaveMsg {} {
    return $pref::groupSaveMsg
}

# pref::SetRestoreMsg --
#
#	Set the error message when a groups restore command is executed.
#
# Arguments:
#	msg	The message to store.
#
# Results:
#	None.

proc pref::SetRestoreMsg {msg} {
    set pref::groupRestoreMsg $msg
    return
}

# pref::GetRestoreMsg --
#
#	Get the error message after a groups restore command is executed.
#
# Arguments:
#	None
#
# Results:
#	The cached message.

proc pref::GetRestoreMsg {} {
    return $pref::groupRestoreMsg
}

