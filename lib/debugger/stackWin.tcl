# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# stackWin.tcl --
#
#	This file implements the Stack Window as snit class.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: stackWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require icolist

# ### ### ### ######### ######### #########
## Implementation

snit::widget stackWin {

    delegate method ourFocus     to icoList
    delegate method hasFocus     to icoList
    delegate method hadFocus     to icoList
    delegate method hasHighlight to icoList

    option -tags -default {} -configuremethod C-tags

    method C-tags {option value} {
	if {$value eq $options(-tags)} return
	set options(-tags) $value

	if {![winfo exists $icoList]} return
	$icoList configure -tags \
	    [linsert $options(-tags) 0 stackDbgWin$self stackDbgWin]
	return
    }

    # Handle to the stack text widget.

    variable icoList {}

    # The 'stack' array stores opaque <location> types for each
    # stack displayed in the stack window.  Each time the stack is
    # updated (i.e., calls to 'updateStackWindow') this array
    # is re-initalized.  The <location> types are indexed using the 
    # line number of the text widget.
    
    variable stack  -array {}
    variable xhide  -array {}
    variable xlevel -array {}
    variable send   {}

    # For every stack level displayed in the Stack Window, store
    # the current PC for that block.  This information is used
    # to show where the last statement was executed in this block
    # when the user moves up and down the stack.

    variable blockPC -array {}

    variable selectedArg
    
    # If this variable is set, selecting a line in the stack window will
    # update the rest of the gui.

    variable needsUpdate 1

    # ### ### ### ######### ######### #########
    ## Connection to outer window and other parts of the system.

    variable dbg ;# From the engine of the gui ...
    variable blk ;# From the engine of the gui ...
    variable fdb ;# From the engine of the gui ...
    variable procwin
    variable varwin
    variable watch

    delegate method * to gui
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui $value

	set procwin [$gui procwin]
	set varwin  [$gui var]
	set watch   [$gui watch]
	set vcache  [$gui vcache]
	set engine_ [$gui cget -engine]
	set dbg [$engine_ dbg]
	set blk [$engine_ blk]
	set fdb [$engine_ fdb]
	return
    }

    variable vcache

    # ### ### ### ######### ######### #########

    constructor {args} {
	$self GSetup [from args -gui]
	$self createWindow
	$self configurelist $args
	return
    }

    # ### ### ### ######### ######### #########

    # method createWindow --
    #
    #	Create the Stack Window and all of the sub elements.
    #
    # Arguments:
    #	masterFrm	The frame that contains the stack frame.
    #
    # Results:
    #	The frame that contains the Stack Window.

    typevariable smap -array {
	-             {}
	configure     cog
	debugger_eval script
	proc          proc
	class         class
	global        star
	event         flag_blue
	uplevel       arrow_up
	method        proc
	source        file
	namespace     namespace
	package       package
    }

    method createWindow {} {
	set icoList [icolist $win.icoList \
			 -columns  4 \
			 -headers {Level Type Name Args} \
			 -tags     [linsert $options(-tags) 0 stackDbgWin$self stackDbgWin] \
			 -onselect [mymethod checkState] \
			 -statemap [array get smap]]

	grid $icoList -sticky wnse -row 0 -column 0

	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1

	$self SetBindings
	return
    }

    method SetBindings {} {
	# Click on argument name of a proc and the arg is selected in the var display!
	#$stackText tag bind stackArg <1> [mymethod selectArg %W current]
	return
    }

    # method updateWindow --
    #
    #	Update the Stack Window after (1) a file is loaded 
    #	(2) a breakpoint is reached or (3) a new stack level 
    #	was selected from the stack window.
    #
    # Arguments:
    #	currentLevel	The current level being displayed by
    #			debugger.
    #
    # Results: 
    #	None.

    method updateWindow {currentLevel} {
	# The stack array caches <location> types based on the current
	# line number.  Unset any existing data and delete the contents 
	# of the stack text widget.

	$self resetWindow

	# Insert the stack information backwards so we can detect
	# hidden frames.  If the next level is > the previous,
	# then we know that the next level is hidden by a previous
	# level.

	set stkList [$dbg getStack]
	set line    1
	set ildata  {}
	set first   1
	set prevLevel {}

	foreach stk $stkList {
	    foreach {level loc type name args} $stk break

	    # Convert all of the newlines to \n's so the values
	    # span only one line in the text widget.

	    set name [code::mangle $name]
	    set args [code::mangle $args]

	    # Determine if the level is a hidden level and 
	    # insert the newline now so the last line in the 
	    # text is not an empty line after a newline.

	    set hiddenLevel 0

	    if {!$first} {
		if {($level < $prevLevel) && ($level > 0)} {
		    set hiddenLevel 1
		}
	    }
	    if {!$hiddenLevel} {
		set prevLevel $level
	    }
	    set first 0

	    # Trim the "name" argument if the type is "proc" or
	    # "source".  If the type is "proc", then trim leading
	    # namespace colons (if >= 8.0),   If the type is 
	    # "source", then convert the name into a unique, short
	    # file name.  

	    set shortName $name
	    switch $type {
		proc {
		    set shortName [$procwin trimProcName $shortName]
		}
		source {
		    set block [loc::getBlock $loc]
		    if {($block != {}) && (![$blk isDynamic $block])} { 
			set shortName [$fdb getUniqueFile $block]
		    }
		}
	    }

	    # Add spaces separately so they do not inherit
	    # the tags put on the the other text items. Add
	    # the hiddenTag to the vars, since they are the
	    # only elements affected by hidden levels.

	    set xtype $type
	    if {![info exists smap($type)]} {set xtype -}

	    lappend ildata [list $xtype $level $type $shortName $args]
	    # FUTURE: icon via type - need list of all types.

	    # If the current level is identical to this level, cache
	    # all of the stack data for easy access by other windows
	    # Ee.g., the Inspector window wants to know which proc the
	    # var is located in.

	    if {$currentLevel == $level && !$hiddenLevel} {
		$gui setCurrentLevel $level
		$gui setCurrentType  $type
		$gui setCurrentProc  $name
		$gui setCurrentArgs  $args
		if {$type eq "name"} {
		    $gui setCurrentScope $name
		} else {
		    $gui setCurrentScope $type
		}
	    }

	    # Cache each opaque location type based on line number.

	    set stack($line)  $loc
	    set xhide($line)  $hiddenLevel
	    set xlevel($line) $level
	    set param($line)  $args

	    incr line
	}

	# Make sure the last line entered is visible in the text 
	# window, and that the lines are formatted correctly.

	incr line -1
	set send $line

	$icoList update $ildata

	set needsUpdate 0
	$icoList select $send 1
	set needsUpdate 1
	return
    }

    # method updateDbgWindow --
    #
    #	Update the debugger window to display the stack frame
    #	selected in the Stack window.  The line number of the text
    #	widget is an index into the stack() array that stores
    #	the <location> opaque type.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateDbgWindow {} {
	set line      [$icoList getSelection]
	set loc       [$self getLocation        $line]
	set hidden    [$self isVarFrameHiddenAt $line]
	set level     [$self getLevelAt         $line]

	# Update the Stack, Var, Watch and Code window to the
	# current stack level.  If the var frame is hidden,
	# then give feedback in the Var Window and set all
	# values in the Watch Window to <No Value>..

	$gui setCurrentLevel $level
	$gui showCode $loc

	if {$hidden} {
	    $watch  resetWindow {}
	    $varwin resetWindow "No variable info for this stack."
	} elseif {$needsUpdate} {
	    # Display the var selected from the stack window.  This 
	    # function must be called after maingui showCode. 
	    
	    $vcache reset
	    $varwin updateWindow
	    $watch  updateWindow

	    if {$selectedArg != ""} {
		$varwin seeVarInWindow $selectedArg 0
		set selectedArg {}
	    }
	}
    }

    # method resetWindow --
    #
    #	Clear the Stack Window and insert the message in it's
    #	place.
    #
    # Arguments:
    #	msg	If not null, then insert this message in the
    #		Stack window after clearing it.
    #
    # Results:
    #	None.

    method resetWindow {{msg {}}} {
	array unset stack   *
	array unset xhide   *
	array unset xlevel  *
	array unset param   *
	array unset blockPC *

	set selectedArg {}

	if {$msg eq ""} {
	    $icoList clear
	} else {
	    $icoList message $msg
	}
    }

    # method checkState --
    #
    #	This proc is executed whenever the selection 
    #	in the Stack Window changes.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method checkState {args} {
	$self updateDbgWindow 
    }

    # method selectArg --
    #
    #	If the user clicks on a procedure's argument in the
    #	Stack Window, cache the argument so it will become
    #	visible in the Var Window on the next update.
    #
    # Arguments:
    #	index	The index of the button press.
    #
    # Results:
    #	None.

    method selectArg {index} {
	set selectedArg $param($index)
	return
    }

    # method isVarFrameHidden --
    #
    #	Determine of the stack level located at <index> is
    #	a hidden stack frame.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Boolean, true if the selected stack is hidden.

    method isVarFrameHidden {} {
	$self isVarFrameHiddenAt [$icoList getSelection]
    }

    method isVarFrameHiddenAt {line} {
	# Is this a stack entry with conflicting variable frames.
	if {$line eq ""} {return 1}
	if {$line == 0} {return 1}
	if {$line > $send} {return 1}
	return $xhide($line)
    }

    # method getSelectedLevel --
    #
    #	Get the level of the Stack inside the Stack text
    #	widget at index.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The level of the Stack entry at <index>.

    method getSelectedLevel {} {
	$self getLevelAt [$icoList getActive]
    }
    method getLevelAt {line} {
	if {$line eq ""} {return 0}
	if {$line == 0}  {return 0}
	return $xlevel($line)
    }

    # method getLocation --
    #
    #	Get the opaque <location> type for a stack displayed in the
    #	Stack Window.  The location is cached in the stack
    #	array, and the key is the line number of the text widget.
    #
    # Arguments:
    #	line	Line number of a stack being displayed in the 
    #		Stack Window.
    #
    # Results:
    #	A location opaque type for a stack.

    method getLocation {line} {
	if {$line eq ""} {return {}}
	if {$line == 0}  {return {}}
	return $stack($line)
    }

    # method getPC --
    #
    #	Return the <location> opaque type of the currently 
    #	selected stack frame.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return the <location> opaque type of the currently 
    #	selected stack frame, or empty string if there is 
    #	no stack data.

    method getPC {} {
	if {[$gui getCurrentState] != "stopped"} {
	    return {}
	}
	return [$self getLocation [$icoList getActive]]
    }

    # method getPCType --
    #
    #	Return the type of PC to display.  If the currently
    #	selected stack frame is the top-most frame, then the
    # 	type is "current", otherwise it is "history".
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return the type of PC to display, or empty string if there
    #	is no stack data. 

    method getPCType {} {
	# If the selection cursor is on the last line, then 
	# the PC type is "current".

	if {[$gui getCurrentState] != "stopped"} {
	    return {}
	}
	set cursor [$icoList getActive]
	if {$cursor == $send} {
	    return current
	}
	return history
    }
}

# ### ### ### ######### ######### #########
## Ready to go.

package provide stack 1.0

