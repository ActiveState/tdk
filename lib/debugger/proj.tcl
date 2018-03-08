# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# proj.tcl --
#
#	This file implements the Project APIs for the file based 
#	projects system.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: proj.tcl,v 1.8 2000/10/31 23:31:00 welch Exp $

package require portWin
package require transform
package require snit
package require widget::dialog

snit::type proj {
    # The path of the currently loaded project file.

    variable projectPath {}

    # The projectOpen var is true if a project is currently open.

    variable projectOpen 0

    # The projectNeverSaved var is true if a project is new and has 
    # never been saved to disk.

    variable projectNeverSaved 0

    # The project file extension string.

    variable projFileExt {}

    # The file types to use for all Project file dialogs.

    variable projFileTypes

    # The vwait variable that is set when BrowseFileWindow locates
    # a file or the user cancels the dialog.  The value set is the
    # new path or empty string if the dialog was canceled.

    variable fileFound

    # The current project file version number.  If the set of preferences
    # stored in a project file changes, then this value should be updated.

    variable version 1.0

    variable portwin

    # ### ### ### ######### ######### #########

    variable             bp
    variable             projwin
    variable             watch
    variable             varwin
    variable             dbg
    variable             fdb
    variable             brk
    variable             blkmgr
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set bp      [$gui bp]
	set projwin [$gui projwin]
	set watch   [$gui watch]
	set varwin  [$gui var]
	set engine_ [$gui cget -engine]
	set dbg     [$engine_ dbg]
	set fdb     [$engine_ fdb]
	set brk     [$engine_ brk]
	set blkmgr  [$engine_ blk]

	$portwin configure -gui $gui
	return
    }

    # ### ### ### ######### ######### #########

    constructor {args} {
	set portwin [portWin ${selfns}::portWin]

	$self configurelist $args

	set projFileExt $projectInfo::debuggerProjFileExt

	# The file types to use for all Project file dialogs.

	set projFileTypes [list \
		[list "$::debugger::parameters(productName) Project Files" *$projFileExt] \
		[list "All files" *]]
    }
    destructor {
	rename $portwin {}
    }

    # ### ### ### ######### ######### #########


    # method openProjCmd --
    #
    #	Use this command for the widget commands.  This displays all of the
    #	necessary GUI windows, performs all of the actions and checks the
    #	error status of the open call.
    #
    # Arguments:
    #	file	The name of the file to open.  If this is an empty string 
    #		the user is prompted to select a project file.
    #
    # Results:
    #	Return 1 if there was an error saving the project file.

    method openProjCmd {{file {}}} {
	if {$file == {}} {
	    set file [$self openProjDialog]
	} else {
	    set file [$self checkOpenProjDialog $file]
	}

	if {[$self openProj $file]} {
	    tk_messageBox -icon error -type ok -title "Load Error" \
		    -parent [$gui getParent] -message \
		    "Error loading project.\n\n[pref::GetRestoreMsg]"
	    return 1
	} else {
	    return 0
	}
    }

    # method openProjDialog --
    #
    #	Display a file dialog window so users can search the disk for a 
    #	saved project file.  
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The name of the file.  If the name is an empty string, then 
    #	the user canceled the opening of the project file.

    method openProjDialog {} {
	set file [$self openFileWindow [$gui getParent] {} $projFileTypes]
	if {$file != {}} {
	    set file [$self checkOpenProjDialog $file]
	}
	return $file
    }

    # method checkOpenProjDialog --
    #
    #	Show all necessary dialogs related to opening a project, determine 
    #	if a project needs to be closed and saved, browse for a file if the
    #	specified file does not exist.  NOTE: This dialog window has side 
    #	effects.  If a project file is open it will be closed.  If the file
    #	does not exist it will be removed from the recently used list of
    #	project files.
    #
    # Arguments:
    #	file	The name of the file to open.
    #
    # Results:
    #	The name of the file.  If the name is an empty string, then 
    #	the user canceled the opening of the project file.

    method checkOpenProjDialog {file} {
	# Close a project if one is opened.  This will display all of the 
	# necessary dialogs, save the file to disk and reset the state.

	if {$projectOpen} {
	    set how [$self closeProjDialog]
	    if {$how == "CANCEL"} {
		return {}
	    } else {
		if {[$self closeProjCmd $how]} {
		    tk_messageBox -icon error -type ok -title "Save Error" \
			    -parent [$gui getParent] -message \
			    "Error saving project:  [pref::GetSaveMsg]"
		}
	    }
	}

	# Verify the file exists.  If it does not, then show the file
	# missing window and prompt the user to browse for what they want.
	# If the return value is an empty string, then no valid file was 
	# located.
	
	if {![file exists $file]} {
	    $self RemoveRecentProj $file
	    set file [$self fileMissingWindow "Project file " \
		    $file $projFileTypes]
	}

	# If the project window is opened, destroy it now, so it does 
	# not perturb the next project that will be opened.

	if {[$projwin isOpen]} {
	    $projwin DestroyWindow
	}

	return $file
    }
    
    # method openProj --
    #
    #	Open the project and initialize the debugger engine and GUI.
    #	No dialog windows will be displayed prompting the user, use 
    #	the openProjDialog or checkOpenProjDialog APIs to prompt the
    #	user.
    #
    # Arguments:
    #	file	The name of the file to open.
    #
    # Results:
    #	Return 1 if there was an error restoring the project file.

    method openProj {file} {
	if {$file == {}} {
	    return 0
	}

	# Create a new Project group and populate it with the preferences
	# from the project file.  If the file is not successfully restored
	# return false, indicating that the open failed.
	
	pref::groupNew Project \
		[mymethod SaveProjCmdOurs] \
		[mymethod RestoreProjCmd $file]
	pref::groupCopy ProjectDefault Project
	if {[pref::groupRestore Project]} {
	    return 1
	}

	# Reset the list of valid breakpoints.  This needs to be done before
	# we show the current file so line breakpoints show up in the codebar.

	$bp setProjectBreakpoints [pref::prefGet breakList]
	$bp setProjectSpawnpoints [pref::prefGet spawnList]
	$bp updateWindow

	# Reset the list of watch variables.

	# Bugzilla 19719 ... We have to be able to deal with v1 and v2
	# project files. v1 project files list only variable names,
	# whereas v2 project files associate a transformation with each
	# variable. Any new project file is v2.

	set vlist [pref::prefGet watchList]

	foreach {pvmaj pvmin} [split [pref::prefGet projVersion] .] break
	if {$pvmaj < 2} {
	    # v1: Extend the watchList with transformation information.
	    #     The chosen transformation is <No transformation>.

	    set tmp [list]
	    foreach v $vlist {lappend tmp [list $v {}]}
	    set vlist $tmp
	} else {
	    # v2: Convert external transformation names to internal id's.
	    #     Unknown names are converted to <No Transformation>.

	    set tmp [list]
	    foreach vv $vlist {
		foreach {v t} $vv break
		if {[catch {set tid [transform::getTransformId $t]}]} {set tid {}}
		lappend tmp [list $v $tid]
	    }
	    set vlist $tmp

	    $varwin mainDeserialize [pref::prefGet varTransformList]
	}

	$watch setVarList $vlist 0
	$watch updateWindow

	$self setProjectPath $file
	pref::prefSet GlobalDefault fileOpenDir [file dirname $file]
	$self AddRecentProj $file
	$self InitNewProj
	set projectNeverSaved 0

	return 0
    }

    # method closeProjCmd --
    #
    #	Use this command for the widget commands.  This displays all of the
    #	necessary GUI windows, performs all of the actions and checks the
    #	error status of the close call.
    #
    # Arguments:
    #	how	How the project should be closed. Can be null.
    #
    # Results:
    #	Return 1 if there was an error saving the project file.

    method closeProjCmd {{how {}}} {
	if {$how == {}} {
	    set how [$self closeProjDialog]
	}
	if {$how == "CANCEL"} {
	    return 0
	}
	# Cancel the project setting window if it is open.
	
	if {[$projwin isOpen]} {
	    $projwin CancelProjSettings
	}

	if {[$self closeProj $how]} {
	    tk_messageBox -icon error -type ok -title "Save Error" \
		    -parent [$gui getParent] -message \
		    "Error saving project:  [pref::GetSaveMsg]"
	    return 1
	} else {
	    # Remove the name of the Project from the main title and remove the
	    # code displayed in the code window.  Change the GUI state to be new,
	    # indicating that a project is not loaded.  Set the current block to
	    # nothing, and reset the gui window to it's default state.

	    $gui setDebuggerTitle ""
	    $gui changeState new
	    $gui setCurrentBlock {}
	    $gui resetWindow
	    return 0
	}
    }

    # method closeProjDialog --
    #
    #	Show all necessary dialogs related to closing a project.  Determine 
    #	if the project needs to be saved and verify that the user wants to 
    #	save the file.  However, do not actually modify any state or save 
    #	the project.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	NONE   if no projects are opened.
    #	SAVE   if the project should be closed and saved.
    #	CLOSE  if the project should be closed w/o saving the file.
    #	CANCEL if the user canceled the action.

    method closeProjDialog {} {
	if {!$projectOpen} {
	    return NONE
	}

	# Bugzilla 42273. Use the value of preference key 'exitPrompt'
	# to determine what will be done with the application (ask
	# wether to kill or not, kill always, kill never), and use
	# that to determine wether to warn the user about killing, or
	# not.
	#
	# ask:  We will later ask the user whether to kill the app or
	#       not. This implicitly serves as a warning, thus we do
	#       not warn the user here.
	#
	# run:  Never kill, thus no warning about killing required.
	#
	# kill: Always kill, thus warn the user about the imminent
	#       termination of the debugged application

	# See closeProj for the location where 'exitPrompt' comes into
	# play.

	if {"kill" eq  [pref::prefGet exitPrompt]} {
	    set stop [$gui askToKill]
	    if {$stop} {
		return CANCEL
	    }
	}

	if {!$projectNeverSaved && ![pref::groupIsDirty Project]} {
	    return CLOSE
	}

	set file [$self getProjectPath]
	switch -- [$self saveOnCloseProjDialog $file] {
	    YES {
		set result SAVE
	    }
	    NO {
		set result CLOSE

		# HACK:  to keep "new" projects from trying to apply when the
		# user doesn't save, empty the destroyCmd

		$projwin clearDestroyCmd
	    }
	    CANCEL {
		set result CANCEL
	    }
	    default {
		error "saveOnCloseProjDialog returned unexpected value."
	    }
	}
	
	if {$result != "CANCEL"} {
	    if {[$projwin isOpen]} {
		$projwin DestroyWindow
	    }
	}
	return $result
    }

    # method closeProj --
    #
    #	Close the project and reset the state of the debugger engine and 
    #	GUI.  If specified, save the project to disk.  No dialog windows
    #	will be displayed prompting the user, use the closeProjDialog 
    #	API to prompt the user.
    #
    # Arguments:
    #	how	Indicates what action to take when closing the project.  
    #		NONE and CANCEL indicate the project should not be closed.
    #		SAVE means to save the project before closing.  CLOSE 
    #		means close the project without saving the project.
    #
    # Results:
    #	Return 1 if there was an error saving the project file.

    method closeProj {how} {
	if {$how == "NONE" || $how == "CANCEL"} {
	    return 0
	}

	set result 0

	if {$how == "SAVE"} {
	    if {[$self saveProj [$self getProjectPath]]} {
		return 1
	    }
	}

	if {!$result} {
	    # Set the variable that indicates Debugger does not have an 
	    # open project and set the projectPath to null.
	    
	    set projectOpen 0
	    set projectNeverSaved 0
	    $self setProjectPath {}
	    pref::groupDelete Project

	    $bp setProjectBreakpoints {}
	    $bp updateWindow

	    $watch setVarList {} 0
	    $watch updateWindow

	    # Close the port the debugger is listening on, and reset
	    # dbg data.

	    # Bugzilla 42273. Use the value of preference key
	    # 'exitPrompt' to control how the lower-level handles the
	    # debugged application (ask kill/detach, always kill,
	    # always detach).

	    $gui quit [pref::prefGet exitPrompt]
	}

	return $result
    }

    method SaveProjCmdOurs {group} {
	$self SaveProjCmd [$self getProjectPath] $group
    }

    # method saveProjCmd --
    #
    #	Use this command for the widget commands.  This displays all of the
    #	necessary GUI windows, performs all of the actions and checks the
    #	error status of the save call.
    #
    # Arguments:
    #	file	The name of the file to save.  If this is an empty string 
    #		the user is prompted to select a project file.
    #
    # Results:
    #	Return 1 if there was an error saving the project file.

    method saveProjCmd {{file {}}} {
	if {$file == {}} {
	    set file [$self saveProjDialog]
	}

	if {[$self saveProj $file]} {
	    tk_messageBox -icon error -type ok -title "Save Error" \
		    -parent [$gui getParent] -message \
		    "Error saving project:  [pref::GetSaveMsg]"
	    return 1
	} else {
	    # Put the new name of the project in the main window.  Trim off
	    # the path and file extension, so only the name of the file is 
	    # displayed.
	    
	    set proj [file rootname [file tail [$self getProjectPath]]]
	    $gui setDebuggerTitle $proj
	    $projwin updateWindow "Project: $proj"
	    return 0
	}
    }

    # method saveAsProjCmd --
    #
    #	Use this command for the widget commands.  This displays all of the
    #	necessary GUI windows, performs all of the actions and checks the
    #	error status of the saveAs call.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return 1 if there was an error saving the project file.

    method saveAsProjCmd {} {
	set file [$self getProjectPath]
	if {[$self saveProj [$self saveAsProjDialog $file]]} {
	    tk_messageBox -icon error -type ok -title "Save Error" \
		    -parent [$gui getParent] -message \
		    "Error saving project:  [pref::GetSaveMsg]"
	    return 1
	} else {
	    # Put the new name of the project in the main window.  Trim off
	    # the path and file extension, so only the name of the file is 
	    # displayed.
	    
	    set proj [file rootname [file tail [$self getProjectPath]]]
	    $gui setDebuggerTitle $proj
	    $projwin updateWindow "Project: $proj"

	    return 0
	}
    }

    # method saveOnCloseProjDialog --
    #
    #	If the file needs to be saved, ask the user if they want 
    #	to save the file.  This does not modify any state or save 
    #	the project.
    #
    # Arguments:
    #	file	The name of the file to save.  Can be empty string.
    #
    # Results:
    #	YES    if the project should be saved
    #	NO     if the project should not be saved
    #	CANCEL if the user canceled the action.

    method saveOnCloseProjDialog {file} {
	# If a project is opened and the project needs to be saved, either 
	# prompt the user to save the file or just set the result to save
	# if there is a preference to always save w/o askling.  Otherwise,
	# nothing needs to be saved, so just return NO.

	if {$projectOpen && ($projectNeverSaved || [pref::groupIsDirty Project])} {
	    if {[pref::prefGet warnOnClose]} {
		append msg "Do you want to save the project information for: "
		append msg "${file}?"
		set result [tk_messageBox -icon question -type yesnocancel \
			-title "Save Project" -parent [$gui getParent] \
			-message $msg]
		set result [string toupper $result]
	    } else {
		set result YES
	    }
	} else {
	    set result NO
	}

	# If the user choose to save the file (by default or activly selecting to
	# save the file) display any necessary save dialogs.  If the result of
	# the save dialogs is a null file name, then the user canceled the action.
	# Change the result to CANCEL and return.  Otherwise, make sure the 
	# projectPath contains the new file name so the saveProj API save the 
	# project to the correct file.

	if {$result == "YES"} {
	    set file [$self saveProjDialog]
	    if {$file == {}} {
		set result CANCEL
	    } else {
		$self setProjectPath $file
	    }
	}
	return $result
    }

    # method saveProjDialog --
    #
    #	Display the saveAs dialog if the file does not exist.
    #	This does not modify any state or save the project.
    #	
    # Arguments:
    #	None.
    #
    # Results:
    #	The name of the file if it exists and needs to be saved.  
    #	Otherwise return an empty string.

    method saveProjDialog {} {
	set file [$self getProjectPath]

	if {$projectNeverSaved} {
	    set file [$self saveAsProjDialog $file]
	} elseif {![pref::groupIsDirty Project]} {
	    set file {}
	}
	return $file
    }

    # method saveAsProjDialog --
    #
    #	Display the saveAs dialog prompting the user to specify a file 
    #	name.  This does not modify any state or save the project.
    #
    # Arguments:
    #	file	The name of the file to save.  Can be empty string.
    #
    # Results:
    #	The name of the file if one was selected or empty string if the 
    #	user canceled the action.

    method saveAsProjDialog {file} {
	set file [$self saveAsFileWindow [$gui getParent] \
		[file dirname $file] [file tail $file] \
		$projFileTypes $projFileExt]
	if {[file extension $file] eq ""} {
	    append file $projFileExt
	}
	return $file
    }

    # method saveProj --
    #
    #	Save the project to disk and update the debugger engine and GUI.
    #	If the name of the file is an empty string this routine is a no-op.
    #	No dialog windows will be displayed prompting the user, use the
    #	saveProjDialog or saveOnCloseProjDialog APIs to prompt the user.
    #	
    # Arguments:
    #	file	The name of the file to save.  Can be empty string.
    #
    # Results:
    #	Return 1 if there was an error saving the project file.

    method saveProj {file} {
	if {$file == {}} {
	    return 0
	}
	if {!$projectOpen} {
	    error "error: saveProj called when no projects are open"
	}

	# Make sure to set the new projectPath , because the project's save command
	# relies on this value.  Then copy the breakpoint list into the project,
	# then save the preferences.

	$self setProjectPath $file

	$brk preserveBreakpoints breakList
	$brk preserveSpawnpoints spawnList

	pref::prefSet Project breakList    $breakList
	pref::prefSet Project spawnList    $spawnList

	# Bugzilla 19719 ... Handle v1 / v2 differences when saving project files.
	# v1: Strip transformation information out of the watchList before saving.
	# v2: Convert the internal transformation id's to their external names.
	#     Also retrieve the global association of variables and transformation
	#     and save that too. New key: "varTransformList".

	set tmp [list]

	foreach {pvmaj pvmin} [split [pref::prefGet projVersion] .] break
	if {$pvmaj < 2} {
	    # v1 : Strip

	    foreach vv [$watch getVarList] {lappend tmp [lindex $vv 0]}
	} else {
	    # v2: Convert

	    foreach vv [$watch getVarList] {
		foreach {v t} $vv break
		lappend tmp [list $v [transform::getTransformName $t]]
	    }
	    pref::prefSet Project varTransformList [$varwin mainSerialize]
	}
	pref::prefSet Project watchList $tmp

	pref::prefSet Project prevViewFile [$gui getCurrentFile]
	set result [pref::groupSave Project]

	# Only update the state if the file was correctly saved.  If the
	# value of 'result' is false, then the file saved w/o errors.
	
	if {!$result} {
	    # Add the project to the list of "recently used projects" 
	    # cascade menu.
	    
	    $self AddRecentProj $file

	    # Set the following bit indicating that the file has been saved.

	    set projectNeverSaved 0
	}

	return $result
    }

    # method restartProj --
    #
    #	Restart the currently loaded project.  If an application is currently
    #	running, it will be killed.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method restartProj {} {
	set state [$gui getCurrentState]
	if {$state == "new"} {
	    error "restartProj called when no project is loaded"
	}
	if {($state == "stopped") || ($state == "running")} {
	    if {[$gui kill]} {
		# User cancelled the kill action
		return
	    }
	}
	# Bugzilla 30651
	$gui run [list [[$gui cget -engine] dbg] run]
	return
    }

    # method getProjectPath --
    #
    #	Get the path to the currently loaded project file.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The project path.
    
    method getProjectPath {} {
	return $projectPath
    }

    # method setProjectPath --
    #
    #	Set the path to the currently loaded project file.
    #
    # Arguments:
    #	path	The project path.
    #
    # Results:
    #	None.

    method setProjectPath {path} {
	set projectPath $path
	return
    }

    # method isProjectOpen --
    #
    #	Accessor function to determine if the system currently has
    #	on open project file.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return 1 if a project file is open, return 0 if no project is open.

    method isProjectOpen {} {
	return $projectOpen
    }

    # method projectNeverSaved --
    #
    #	Accessor function to determine if the current project has never 
    #	been saved (a new, "Untitled", project.)
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return 1 if a the file has never been saved

    method projectNeverSaved {} {
	return $projectNeverSaved
    }

    # method checkProj --
    #
    #	Verify that the project information is valid.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return a boolean, 1 if the project information was valid.
    #	Any errors will display a dialog stating the error.

    method checkProj {} {
	# Bugzilla 19617, 19700 : Addendum. Another place depending on the
	# old combobox semantics.

	set msg    {}
	set script [pref::prefGet appScript] ;#[lindex [pref::prefGet appScriptList] 0]
	set arg    [pref::prefGet appArg]    ;#[lindex [pref::prefGet appArgList]    0]
	set dir    [pref::prefGet appDir]    ;#[lindex [pref::prefGet appDirList]    0]
	set interp [pref::prefGet appInterp] ;#[lindex [pref::prefGet appInterpList] 0]
	set iparg  [pref::prefGet appInterpArg]    ;#[lindex [pref::prefGet appInterpArgList]    0]

	# Make the starting directory relative to the path of the project
	# file. If the script path is absolute, then the join does nothing.
	# Otherwise, the starting dir is relative from the project directory.

	if {!$projectNeverSaved} {
	    set dir [file join [file dirname [$self getProjectPath]] $dir]
	}

	if {$script == {}} {
	    set msg "You must enter a script to Debug."
	} elseif {![file exist [file join $dir $script]]} {
	    set msg "$script : File not found.\n"
	    append msg "Please verify the correct filename was given."
	}
	if {$dir != {}} {
	    if {(![file exist $dir]) || (![file isdirectory $dir])} {
		set msg "$dir : Invalid directory\n"
		append msg "Please verify the correct path was specified."
	    }	    
	}
	if {$interp == {}} {
	    set msg "You must specify an interpreter."
	}

	if {$msg != {}} {
	    tk_messageBox -icon error -type ok -title "Load Error" \
		    -parent [$gui getParent] -message $msg
	    set result 0
	} else {
	    set result 1
	}
	return $result
    }

    # method isRemoteProj --
    #
    #	Determine if the currently loaded project is remote.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Boolean, true if the project is connected remotely.

    method isRemoteProj {} {
	return [expr {[pref::prefGet appType] == "remote"}]
    }

    # method showNewProjWindow --
    #
    #	Display the Project Settings Window for a new project.  Use the
    #	DefaultProject group to initialize the new project.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method showNewProjWindow {} {
	# If there is a project currently open, check to see if it needs
	# to be saved.  If the save was canceled, then do not continue to
	# open this project.

	set how [$self closeProjDialog] 
	if {$how == "CANCEL"} {
	    return
	} else {
	    $self closeProjCmd $how
	}
	
	# Generate the new file name.

	set projPath "Untitled" 
	$self setProjectPath $projPath

	# Create a new Project group.  Make the save command callback such that
	# it copies the preferences from Project into the project file.  Then
	# move the project default preferences into the Project group.

	pref::groupNew Project \
		[mymethod SaveProjCmdOurs] \
		{}
	pref::groupCopy ProjectDefault Project

	# Set the bit that indicates this project has never been saved.

	set projectNeverSaved 1

	# Display the Project Settings Window, and register the callbacks
	# for Ok/Apply and Cancel.  The New Project Settings Window calls
	# the same apply routine regardless if OK, Apply or Cancel is 
	# pressed.  However, if the user doesn't save, we need to set the
	# $projwin destroyCmd var to empty in the $self closeProjDialog proc.

	$projwin showWindow "Project: $projPath"  \
		[mymethod applyThisProjCmd] \
		[mymethod applyThisProjCmd]
	return
    }

    # method showThisProjWindow --
    #
    #	Display the Project Settings Window for the currently opened project.
    #	If no project are loaded, then display the Default Project Settings
    #	window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method showThisProjWindow {} {
	# Verify that a project is currently opened.  If there are no projects
	# open, open the Default Settings window.

	if {!$projectOpen} {
	    $self showDefaultProjWindow
	    return
	}
	
	# Display the Project Settings Window.

	set proj [file rootname [file tail [$self getProjectPath]]]

	set projectNeverSaved 0

	# Show the Project Settings Window.  Register the callback when
	# OK/Apply is pressed.  Do not register a callback for the Cancel
	# button.

	$projwin showWindow "Project: $proj" \
		[mymethod applyThisProjCmd] {}
	return
    }

    # method applyThisProjCmd --
    #
    #	The command to execute when the Project Settings window, 
    #	for a current project, is applied by the user.
    #
    # Arguments:
    #	destroy	  Boolean, if true then destroy the toplevel window.
    #
    # Results:
    #	None.

    method applyThisProjCmd {destroy} {
	# If the doInstrument list is empty, then add the "*" pattern to it.

	$projwin nonEmptyInstruText

	if {![$self isRemoteProj]} {
	    # If the working directory is null, get the directory name from
	    # the script argument, and implicitly set the working  directory.
	    # Add the dir to the combo box, and add the dir to the preference
	    # list.

	    # Bugzilla 19617, 19700 : Addendum. Another place depending on
	    # the old combobox semantics.

	    set dir    [pref::prefGet appDir    TempProj] ;# [lindex [pref::prefGet appDirList    TempProj] 0]
	    set script [pref::prefGet appScript TempProj] ;# [lindex [pref::prefGet appScriptList TempProj] 0]

	    if {($dir == {}) && ($script != {})} {
		set dir   [file dirname $script]
		set dList [$projwin AddDirectory $dir]

		pref::prefSet Project appDirList $dList
	    }
	}

	# If this is a remote project, initialize the port now so the
	# debugger is waiting for the app to connect.  If this is a 
	# local project, make sure the debugger is not listening on a
	# port.

	$self InitNewProj

	return
    }

    # method showDefaultProjWindow --
    #
    #	Display the Project Settings Window for setting default project 
    #	values.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method showDefaultProjWindow {} {
	# Create a new Project group.  Then move the project default preferences 
	# into the Project group.

	pref::groupNew Project
	pref::groupCopy ProjectDefault Project

	# Display the Project Settings Window. Register the callback when
	# OK/Apply is pressed.  Do not register a callback for the Cancel
	# button.

	$projwin showWindow "Default Project Settings" \
		[mymethod applyDefaultProjCmd] {}
	return
    }

    # method applyDefaultProjCmd --
    #
    #	The command to execute when the Project Settings window, 
    #	for the default project, is applied by the user.
    #
    # Arguments:
    #	destroy	  Boolean, if true then destroy the toplevel window.
    #
    # Results:
    #	None.

    method applyDefaultProjCmd {destroy} {
	# If the doInstrument list is empty, then add the "*" pattern to it.

	$projwin nonEmptyInstruText
	if {[$self isRemoteProj]} {
	    # Check if port value is valid (numeric); if it's not, make it valid
	    set port [pref::prefGet portRemote]
	    set newPort $port
	    while {[catch {expr {$newPort + 0}}]} {
		set newPort [$portwin showWindow $newPort]
	    }
	    pref::prefSet Project portRemote $newPort
	}
	pref::groupCopy Project ProjectDefault
	if {$destroy} {
	    pref::groupDelete Project
	}
	return
    }

    # method fileMissingWindow --
    #
    #	Display a dialog box that states the file cannot be found , and ask 
    #	the user if they want to browse for this file.
    #
    # Arguments:
    #	prefix	A string that describes what type of file is missing.  This
    #		is prepend to the error message displayed.
    #	path	The path of the missing file.
    #	types	The file types to use in the dialog.  Can be an empty string.
    #
    # Results:
    #	Returns a new path if one is located, otherwise 

    method fileMissingWindow {prefix path types} {
	$self ShowFileMissingWindow $prefix $path $types
	vwait [varname fileFound]
	return        $fileFound
    }

    # method saveAsFileWindow --
    #
    #	Display a file dialog for browsing for a file to save.  If the dir
    #	name does not exists, then use the current working directory.
    #
    # Arguments:
    #	parent	The parent window of the open dialog.
    #	dir	The directory name of current working directory.  If the value
    #		does not reference a valid path, current working dir is used.
    #	file	Default name for file.  Can be null.
    #	types	File types to put into the fileDialog.  If null a default 
    #		value is set.
    #	ext	The default extension to use.
    #
    # Results:
    #	Return a boolean, 1 means that the save succeeded
    #	and 0 means the user canceled the save.


    method saveAsFileWindow {parent dir file {types {}} {ext {}}} {
	# Do some basic sanity checking here.

	if {![file exist $dir]} {
	    set dir [pref::prefGet fileOpenDir]
	}
	if {$file == {}} {
	    set file [$fdb getUntitledFile $dir Untitled $projFileExt]
	}

	# If types is empty, then use the default values.

	if {$types == {}} {
	    set types {
		{"Tcl Scripts"		{.tcl .tk}	}
		{"Text files"		{.txt .doc}	TEXT}
		{"All files"		*}
	    }
	}

	set file [tk_getSaveFile -filetypes $types -parent $parent \
		-initialdir $dir -initialfile $file -defaultextension $ext]

	if {$file != {}} {
	    pref::prefSet GlobalDefault fileOpenDir [file dirname $file]
	}
	return $file
    }

    # method openFileWindow --
    #
    #	Display a file dialog for browsing for a file to open.  If the dir
    #	name does not exists, then use the current working directory.
    #
    # Arguments:
    #	parent	The parent window of the open dialog.
    #	dir	The directory name of current working directory.  If the value
    #		does not reference a valid path, current working dir is used.
    #	types	File types to put into the fileDialog.  If null a default 
    #		value is set.
    #
    # Results:
    #	The name of the file to open or empty string of nothing was selected.

    method openFileWindow {parent dir {types {}}} {
	# Do some basic sanity checking here.

	if {![file exists $dir]} {
	    set dir [pref::prefGet fileOpenDir]
	}
	if {![file isdirectory $dir]} {
	    set dir [file dirname $dir]
	}

	# If types is empty, then use the default values.

	if {$types == {}} {
	    set types {
		{"Tcl Scripts"		{.tcl .tk}	}
		{"Text files"		{.txt .doc}	TEXT}
		{"All files"		*}
	    }
	}

	set file [tk_getOpenFile -filetypes $types -parent $parent \
		-initialdir $dir]
	if {$file != {}} {
	    pref::prefSet GlobalDefault fileOpenDir [file dirname $file]
	}
	return $file
    }

    # method openComboFileWindow --
    #
    #	Display a fileDialog for browsing.  Extract the dir name
    #	from the combobox.  If the dir name exists, then set this
    #	as the default dir for browsing.  When the dialog exits,
    #	write the value to the combobox.
    #
    # Arguments:
    #	combo	The combobox to extract and place file info.
    #	types	File types to put into the fileDialog.
    #
    # Results:
    #	None.

    method openComboFileWindow {combo types} {
	set file [$combo get]

	if {[file isdirectory $file]} {
	    set dir $file
	} elseif {$file != {}} {
	    set dir [file dirname $file]
	} else {
	    set dir {}
	}
	if {![file exists $dir]} {
	    set dir [pref::prefGet fileOpenDir]
	}

	if {$types == {}} {
	    set types {
		{"Tcl Scripts"		{.tcl .tk}	}
		{"Text files"		{.txt .doc}	TEXT}
		{"All files"		*}
	    }
	}
	set file [tk_getOpenFile -filetypes $types -parent [$gui getParent] \
		      -initialdir $dir]
	if {$file ne ""} {
	    $combo set $file
	}
	return
    }

    # method openComboDirWindow --
    #
    #	Display a dirDialog for browsing.  Extract the dir name
    #	from the combobox.  If the dir name exists, then set this
    #	as the default dir for browsing.  When the dialog exits,
    #	write the value to the combobox.
    #
    # Arguments:
    #	combo	The combobox to extract and place directory info.
    #
    # Results:
    #	None.

    method openComboDirWindow {combo} {
	set file [$combo get]

	if {[file isdirectory $file]} {
	    set dir $file
	} elseif {$file != {}} {
	    set dir [file dirname $file]
	} else {
	    set dir {}
	}
	if {![file exists $dir]} {
	    set dir [pref::prefGet fileOpenDir]
	}

	set file [tk_chooseDirectory -parent [$gui getParent] \
		      -initialdir $dir]
	if {$file ne ""} {
	    $combo set $file
	}
	return
    }

    # method ShowFileMissingWindow --
    #
    #	Show the window that tells the user their file is missing
    #	and ask them if they want to browse for a new path.
    #
    # Arguments:
    #	prefix	A string that describes what type of file is missing.  This
    #		is prepend to the error message displayed.
    #	path	The path of the missing file.
    #	types	The file types to use in the dialog.  Can be an empty string.
    #
    # Results:
    #	None.

    method ShowFileMissingWindow {prefix path types} {
	set top [widget::dialog [$gui projMissingWin] \
		     -title "Project File Not Found" -place over \
		     -modal local -synchronous 1 -parent $gui -padding 4]

	set msg "$prefix\"$path\" not found.\nPress Browse to locate the file."

	set lbl [ttk::label $top.lbl -text $msg \
		     -image $image::image(pause) -compound left]
	$top setwidget $lbl

	set b [$top add button -text "Browse" \
		   -command [list $top close browse]]
	set c [$top add button -text "Cancel" \
		   -command [list $top close cancel]]
	focus -force $b
	bind $top <Escape> [list $top close cancel]

	set btn [$top display] 
	if {$btn eq "browse"} {
	    set dir [file dirname $path]
	    if {![file exists $dir]} {
		set dir [pwd]
	    }
	    set fileFound [$self openFileWindow [$gui getParent] $dir $types]
	} else {
	    set fileFound {}
	}
	destroy $top
	return
    }

    # method InitNewProj --
    #
    #	Update information when a new project or project file is opened.
    #	Note:  this proc should probably be renamed to UpdateProj.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method InitNewProj {} {
	# Set the variable that indicate Debugger has an open project
	# and the global pref to indicate the project path.

	set projectOpen 1
	set projPath [$self getProjectPath]

	# Invoke all of the update routines to ensure we notice any changes
	# since the last project.

	pref::groupUpdate Project

	# Put the name of the project in the main window.  Trim off the 
	# path and file extension, so only the name of the file is 
	# displayed.

	set proj [file rootname [file tail $projPath]]
	$gui setDebuggerTitle $proj
	
	# If the Debugger is not running an application, update the GUI state
	# to reflect the change in project settings.

	set state [$gui getCurrentState]
	if {($state == "new") || ($state == "dead")} { 
	    if {[$self isRemoteProj]} {
		# Update the server port if we are currenly not listening or
		# the listening port is different from the preference.

		$self initPort
	    } else {
		# Quitting the debugger will insure the connection status is
		# current.  This is necessary if the user switched from a 
		# remote project (currently listening on the port) to a local
		# project (when the debugger should not be listening.)
		# Note: We want to preserve the breakpoints.  The quit routine,
		# amoung other tasks, clears them.  So save the bps before, then
		# restore them after. Ditto for spawnpoints.
		
		$brk preserveBreakpoints breakList
		$brk preserveSpawnpoints spawnList
		$gui quit kill
		$bp setProjectBreakpoints $breakList
		$bp setProjectSpawnpoints $spawnList
	    }

	    # Update the GUI to reflect the possible change from a local
	    # to remote, vice versa, or the changing of the remote port.

	    $gui changeState dead

	    # Show the last viewed file.  If this is a new project, use the
	    # script argument for this project.  Verify that the file name
	    # entered is actually valid.
	    
	    set file    [pref::prefGet prevViewFile Project]

	    # Bugzilla 19617, 19700 : Addendum. Another place depending on the
	    # old combobox semantics.

	    set script  [pref::prefGet appScript] ;# [lindex [pref::prefGet appScriptList] 0]
	    set workDir [pref::prefGet appDir]    ;# [lindex [pref::prefGet appDirList] 0]

	    set script  [file join $workDir $script]

	    if {[file exists $file]} {
		set loc [loc::makeLocation [$blkmgr makeBlock $file] {}]
	    } elseif {($script != {}) && [file exists $script]} {
		set loc [loc::makeLocation [$blkmgr makeBlock $script] {}]
	    } else {
		set loc {}
	    }
	    if {$loc != {}} {
		$gui showCode $loc
	    }
	}

	return
    }

    # method initPort --
    #
    #	Update the server port if we are currenly not listening or
    #	the listening port is different from the preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method initPort {} {
	foreach {status server sock peer} [$dbg getServerPortStatus] {}
	set listenPort [lindex $server 0]
	set port       [pref::prefGet portRemote Project]

	if {($status != "Listening") || ($listenPort != $port)} {
	    # Attempt to set the server port with the port preference.  
	    # If an error occurs, display the window that prompts the 
	    # user for a new port.
	    
	    while {![$dbg setServerPort $port]} {
		$self validatePortDialog
		set port [pref::prefGet portRemote Project]
	    }
	}
	return
    }

    # method validatePortDialog --
    #
    #	Verify the remote port preference is valid and available for 
    #	use.  If any errors occur, pormpt the user to enter a new 
    #	remote port preference.  If the preference changes, it will
    #	automatically set the preference.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method validatePortDialog {} {
	set port [pref::prefGet portRemote]
	set newPort $port
	
	while {![$portwin isPortValid $newPort]} {
	    set newPort [$portwin showWindow $newPort]
	}
	
	if {$newPort != $port} {
	    if {[pref::groupExists Project]} {
		pref::prefSet Project portRemote $newPort
	    }
	    if {[pref::groupExists TempProj]} {
		pref::prefSet TempProj portRemote $newPort
	    }
	}
	return
    }

    # method AddRecentProj --
    #
    #	Add the project to the list of recently used projects.
    #
    # Arguments:
    #	projPath	The path to the project file.
    #
    # Results:
    #	None.

    method AddRecentProj {projPath} {
	# Try to ensure that the same file doesn't appear twice in 
	# the recent project list by making it native.

	set projPath [file nativename $projPath]
	set projList [pref::prefGet projectList GlobalDefault]

	# Make sure we do an case insensitive comparison on Windows.

	if {$::tcl_platform(platform) == "windows"} {
	    set list [string toupper $projList]
	    set file [string toupper $projPath]
	} else {
	    set list $projList
	    set file $projPath
	}

	# Remove any duplicate project names if they are anywhere
	# in the list except for the first element.

	set index [lsearch -exact $list $file]
	if {$index > 0} {
	    set projList [lreplace $projList $index $index]
	}
	
	# If the project is not already at the head of the list, 
	# insert the project path.

	if {($index < 0) || ($index > 0)} {
	    set projList [linsert $projList 0 $projPath]
	    pref::prefSet GlobalDefault projectList $projList
	}
	return
    }

    # method RemoveRecentProj --
    #
    #	Remove the project to the list of recently used projects.  If the
    # 	project is not in the list, nothing happens.
    #
    # Arguments:
    #	projPath	The path to the project file.
    #
    # Results:
    #	None.

    method RemoveRecentProj {projPath} {
	# All files in recent project list are native.

	set projPath [file nativename $projPath]

	# Remove any duplicate project names if they are anywhere
	# in the list except for the first element.

	set list [pref::prefGet projectList GlobalDefault]
	set index [lsearch -exact $list $projPath]
	if {$index >= 0} {
	    set list [lreplace $list $index $index]
	    pref::prefSet GlobalDefault projectList $list
	}

	return
    }

    # method SaveProjCmd --
    #
    #	This is the command that is called when the Project group
    #	is asked to save its preferences.  All error checking is 
    #	assumed to have been made, and errors should be caught
    #	in the groupSave routine.
    #
    # Arguments:
    #	projPath	The path to the project file.
    #	group		The group doing the saving.
    #
    # Results:
    #	Return a boolean, 1 means that the save did not succeed, 
    #	0 means it succeeded.

    method SaveProjCmd {projPath group} {

	set v 1.0
	catch {set v [pref::prefGet projVersion $group]}

	set cancel "User canceled the action"

	set result [catch {
	    file mkdir [file dirname $projPath]
	    switch -exact $v {
		1.0 {
		    set id [open $projPath w]
		    foreach pref [pref::GroupGetPrefs $group] {
			puts $id [list $pref [pref::prefGet $pref $group]]
		    }
		    close $id
		}
		2.0 {
		    package require tcldevkit::config
		    package require projectInfo

		    if {[file exists $projPath]} {
			foreach {pro tool} [::tcldevkit::config::Peek/2.0 $projPath] break

			if {$pro && ![string equal $tool {TclDevKit Debugger}]} {
			    # The chosen file exists, is a Tcl Dev Kit Project File in
			    # Format 2.0, and was written by a different tool than the
			    # current one. Ask the user again, if overwriting it is
			    # wanted.

			    set reply [tk_messageBox \
				    -icon warning -type yesno \
				    -default no \
				    -title "Save Tcl Dev Kit Debugger $projectInfo::baseVersion configuration" \
				    -parent . -message "The chosen file \"$projPath\"\
				    contains project information for \"$tool\", whereas\
				    we are the Tcl Dev Kit Debugger.\n\nDo you truly wish to\
				    overwrite the contents of this file ?"]

			    if {[string equal $reply "no"]} {
				# [*] Cancel the action. This error does
				#     not cause the display of an error
				#     dialog. See [x] too.
				error $cancel
			    }
			}
		    }

		    array set temp {}
		    foreach pref [pref::GroupGetPrefs $group] {
			set temp($pref) [pref::prefGet $pref $group]
		    }

		    # Make the breakList look nicer. Same for watchList.
		    foreach k {breakList watchList varTransformList} {
			if {[llength $temp($k)] > 0} {
			    set temp($k) "\n\t\{[join $temp($k) "\}\n\t\{"]\}"
			}
		    }
		    set data [array get temp]

		    ::tcldevkit::config::Write/2.0 $projPath $data \
			    "TclDevKit Debugger" $projectInfo::baseVersion
		}
	    }
	} msg] ; # {}

	if {[string equal $msg $cancel]} {
	    # [x] Do not show an error dialog if the action was canceled
	    #     by the user. See [*] too.
	    set msg ""
	    set result 0
	}

	pref::SetSaveMsg $msg
	return $result
    }

    # method RestoreProjCmd --
    #
    #	This is the command that is called when the Project group
    #	is asked to restore its preferences.  All error checking is 
    #	assumed to have been made, and errors should be caught
    #	in the groupRestore routine.
    #
    # Arguments:
    #	projPath	The path to the project file.
    #	group		The group doing the saving.
    #
    # Results:
    #	Return a boolean, 1 means that the save did not succeed, 
    #	0 means it succeeded.

    method RestoreProjCmd {projPath group} {
	package require tcldevkit::config
	package require projectInfo

	foreach {pro tool} [::tcldevkit::config::Peek/2.0 $projPath] break

	if {!$pro} {
	    # Assume and old-style (1.0) debugger project file.

	    set result [catch {
		set id [open $projPath r]
		set prefs [read $id]
		pref::GroupSetPrefs $group $prefs
		close $id
	    } msg] ; # {}

	    if {$result} {
		set msg "Project file is unreadable or corrupt.\n\n$msg"
	    }

	    pref::SetRestoreMsg $msg
	    return $result
	}

	# TclDevKit 2.0 project file, or higher. Check that the file
	# actually is for the debugger.

	set fmtkey  "Unable to handle the following keys found in the TclDevKit Project file for"
	set fmttool "The chosen TclDevKit Project file does not contain information for TclDevKit Debugger, but"
	set basemsg "Could not load file"

	if {![string equal $tool {TclDevKit Debugger}]} {
	    # Is a project file, but not for this tool.
	    pref::SetRestoreMsg "$basemsg ${projPath}.\n\n$fmttool $tool"
	    return 1
	}

	# The file is tentatively identified as project file for this
	# tool, so read the information in it.

	set result [catch {
	    set cfg [::tcldevkit::config::ReadOrdered/2.0 $projPath \
		    [pref::GroupGetPrefs $group]]

	    pref::GroupSetPrefs $group $cfg
	} msg] ; # {}

	if {$result} {
	    set msg "$basemsg ${projPath}.\n\n$fmtkey ${tool}:\n\n$msg"
	}

	pref::SetRestoreMsg $msg
	return $result
    }
}

# ### ### ### ######### ######### #########

package provide proj 1.0
