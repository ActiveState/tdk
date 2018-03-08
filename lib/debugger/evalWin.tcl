# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# evalWin.tcl --
#
#	The file implements the Debuger interface to the 
#	TkCon console (or whats left of it...)
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: evalWin.tcl,v 1.3 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require tile
package require snit
package require tkCon

# ### ### ### ######### ######### #########
## Implementation

snit::type evalWin {

    # The handle to the text widget where commands are entered.

    variable evalText

    # The handle to the combo box that contains the list of 
    # valid level to eval commands in.

    variable levelCombo

    # Used to delay UI changes do to state change.
    variable afterID

    # Flag, if console is disabled.
    variable disabled 0

    # Flag if stdin is asked for
    variable stdin 0

    # Continuity flag for std* output
    variable nobreak 0

    variable tkcon {}


    # ### ### ### ######### ######### #########

    variable             dbg
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set engine_ [$gui cget -engine]
	set dbg     [$engine_ dbg]
	return
    }

    # ### ### ### ######### ######### #########

    constructor {args} {
	$self configurelist $args
	set tkcon [tkCon ${selfns}::tkcon $self [$gui evalDbgWin]]
	return
    }
    destructor {
	catch {rename $tkcon {}}
    }

    delegate method tkConUpdate to tkcon as update

    # ### ### ### ######### ######### #########

    # method showWindow --
    #
    #	Show the Eval Window.  If it already exists, just raise
    #	it to the foreground.  Otherwise, create a new eval window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The toplevel window name for the Eval Window.

    method showWindow {} {
	# If the window already exists, show it, otherwise
	# create it from scratch.

	if {[winfo exists [$gui evalDbgWin]]} {
	    # method updateWindow
	    wm deiconify [$gui evalDbgWin]
	    focus $evalText
	    return [$gui evalDbgWin]
	} else {
	    $self createWindow
	    $self updateWindow
	    focus $evalText
	    return [$gui evalDbgWin]
	}    
    }

    # method createWindow --
    #
    #	Create the Eval Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method createWindow {} {
	variable evalText
	variable levelCombo

	set pad 6

	set top [toplevel [$gui evalDbgWin]]
	::guiUtil::positionWindow $top 400x250
	wm protocol               $top WM_DELETE_WINDOW "wm withdraw $top"
	wm minsize                $top 100 100
	wm title                  $top "Eval Console - [$gui cget -title]"
	wm transient              $top $gui
	wm resizable              $top 1 1

	# Create the level indicator and combo box.

	set mainFrm    [ttk::frame $top.mainFrm]
	set levelFrm   [ttk::frame $mainFrm.levelFrm]
	set levelLbl   [ttk::label $levelFrm.levelLbl -text "Stack Level:"]
	set levelCombo [ttk::combobox $levelFrm.levelCombo -width 8 \
			    -textvariable [$gui evalLevelVar] \
			    -state readonly -exportselection 0]
	set closeBut [ttk::button $levelFrm.closeBut -text "Close" \
			  -command [mymethod closeWindow]]
	pack $levelLbl -side left
	pack $levelCombo -side left -padx 3
	pack $closeBut -side right

	# Place a separating line between the var info and the var value.

	set sepFrm [ttk::separator $mainFrm.sep1 -orient horizontal]

	# Create the text widget that will be the eval console.

	set evalFrm  [ttk::frame $mainFrm.evalFrm -relief sunken -borderwidth 1]
	set evalText [$tkcon InitUI $evalFrm Console]

	pack $levelFrm -fill x -padx $pad -pady $pad
	pack $sepFrm -fill x -padx $pad -pady $pad
	pack $evalFrm -fill both -expand true -padx $pad -pady $pad
	pack $mainFrm -fill both -expand true

	bind::addBindTags $evalText   evalDbgWin$self
	bind::addBindTags $levelCombo evalDbgWin$self
	bind::commonBindings evalDbgWin$self {}
	bind $evalText <Control-minus> "\
		[mymethod moveLevel -1]; break \
		"
	bind $evalText <Control-plus> "\
		[mymethod moveLevel 1]; break \
		"
	foreach num [list 0 1 2 3 4 5 6 7 8 9] {
	    bind $evalText <Control-Key-$num> "\
		    [mymethod requestLevel $num]; break \
		    "
	}
	if {[$gui getCurrentState] == "running"} {
	    bind::addBindTags $evalText disableKeys
	    $self resetWindow
	}
	bind $top <Escape> "$closeBut invoke; break"
    }

    method closeWindow {} {
	set nobreak 0
	destroy [$gui evalDbgWin]
	return
    }

    # method updateWindow --
    #
    #	Update the display of the Eval Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateWindow {} {
	variable evalText
	variable levelCombo
	variable afterID
	variable disabled

	if {![winfo exists [$gui evalDbgWin]]} {
	    return
	}

	if {[info exists afterID]} {
	    after cancel $afterID
	    unset afterID
	}

	# Enable typing in the console and remove the disabled
	# look of the console by removing the disabled tags.
	
	$evalText tag remove disable 0.0 "end + 1 lines"
	bind::removeBindTag $evalText disableKeys

	set state [$gui getCurrentState]
	if {$state == "stopped"} {
	    # Add the list of valid levels to the level combo box
	    # and set the display in the combo entry to the top
	    # stack level.

	    set thisLevel [set [$gui evalLevelVar]]

	    set levels [$self getLevels]
	    $levelCombo configure -values $levels

	    $evalText configure -state normal
	    set disabled 0

	    # Set the default level.  If the "stopped" event was generated
	    # by a "result" break type, use the last level as long as it
	    # still exists.  Otherwise use the top-most level.

	    set lastLevel [lindex $levels end]
	    if {([$gui getCurrentBreak] == "result") && $thisLevel < $lastLevel} {
		$gui evalLevel $thisLevel
	    } else {
		$gui evalLevel $lastLevel
	    }
	} elseif {$state == "running"} {
	    # We have to set 'disabled' here, or we can get into a race
	    # condition: keys are set off here, 'gets' is called for
	    # stdin, does not re-enable the keys as disabled is not set,
	    # no input possible.

	    set disabled 1

	    # Append the bindtag that will disable key strokes.
	    bind::addBindTags $evalText disableKeys
	    set afterID [after \
		    [$gui afterTime] \
		    [mymethod resetWindow]]
	} else {
	    $self resetWindow
	}
    }

    # method resetWindow --
    #
    #	Reset the display of the Eval Window.  If the message
    #	passed in is not empty, display the contents of the
    #	message in the evalText window.
    #
    # Arguments:
    #	msg	If this is not an empty string then display this
    #		message in the evatText window.
    #
    # Results:
    #	None.

    method resetWindow {{msg {}}} {
	variable evalText
	variable levelCombo
	variable disabled
	variable stdin

	if {![winfo exists [$gui evalDbgWin]]} {
	    return
	}

	# Keep window active for STDIN prompt.
	if {$stdin} {return}

	##$levelCombo del 0 end
	$levelCombo configure -values {}
	$evalText configure -state disabled
	$evalText tag add disable 0.0 "end + 1 lines"
	set disabled 1
	return
    }

    # method evalCmd --
    #
    #	Evaluate the next command in the evalText window.
    #	This proc is called by the TkCon code defined in
    #	tkcon.tcl.
    #
    # Arguments:
    #	cmd	The command to evaluate.
    #
    # Results:
    #	The "pid" of the command.

    method evalCmd {cmd} {
	return [$gui run [list $dbg evaluate [set [$gui evalLevelVar]] $cmd]]
    }

    # method evalResult --
    #
    #	Handler for the "result" message sent from the nub.
    #	Pass the data to TkCon to display the result.
    #
    # Arguments:
    #	id		The "pid" of the command.
    #	code		Standard Tcl result code.
    #	result		The result of evaluation.
    #	errCode		The errorCode of the eval.
    #	errInfo		The stack trace of the error.
    #
    # Results:
    #	None.

    method evalResult {id code result errCode errInfo} {
	set code    [code::binaryClean $code]
	set result  [code::binaryClean $result]
	set errCode [code::binaryClean $errCode]
	set errInfo [code::binaryClean $errInfo]

	$tkcon EvalResult $id $code $result $errCode $errInfo
    }

    # method moveLevel --
    #
    #	Move the current eval level up or down within range 
    #	of acceptable levels.
    #
    # Arguments:
    #	amount	The amount to increment/decrement to the
    #		current level.
    #
    # Results:
    #	None.

    method moveLevel {amount} {
	variable levelCombo

	##    set level [expr {[$levelCombo get] + $amount}]
	set level [expr {
	    [lindex \
		    [$levelCombo cget -values] \
		    [$levelCombo get]]
	    + $amount
	}] ;# {}
	set last [lindex [$self getLevels] end]

	if {$last == {}} {
	    return
	}
	if {$level < 0} {
	    set level 0
	}
	if {$level > $last} {
	    set level $last
	}
	$levelCombo set $level
	return
    }

    # method requestLevel --
    #
    #	Request a level, between 0 and 9, to evaluate the next 
    #	command in.  If the level is invalid, do nothing.
    #
    # Arguments:
    #	level	A requested eval level between 0 and 9.
    #
    # Results:
    #	None.

    method requestLevel {level} {
	variable levelCombo

	if {[set pos [lsearch -exact [$self getLevels] $level]] >= 0} {
	    $levelCombo set $level
	}
    }

    # method getLevels --
    #
    #	Get a list of valid level to eval the command in.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method getLevels {} {    
	set maxLevel [$dbg getLevel]
	set result {}
	for {set i 0} {$i <= $maxLevel} {incr i} {
	    lappend result $i
	}
	return $result
    }

    method log {chanid text} {
	variable disabled
	variable evalText
	variable nobreak

	$self showWindow

	if {!$nobreak} {
	    set text \n$text
	}

	# We check and modify the internal state of the console to
	# make sure that we can add the output to it, and that
	# all tags are preserved.

	if {$disabled} {$evalText configure -state normal}

	$tkcon Stdout $chanid $text

	if {$disabled} {
	    $evalText configure -state disabled
	    $evalText tag add disable 0.0 "end + 1 lines"
	}

	set nobreak 1
	return
    }

    method gets {cmd blocking num oncomplete} {
	variable disabled
	variable evalText
	variable stdin
	variable nobreak

	$self showWindow

	# We check and modify the internal state of the console to
	# make sure that we can add the output to it, and that
	# all tags are preserved.

	if {$disabled} {
	    $evalText configure -state normal
	    $evalText tag remove disable 0.0 "end + 1 lines"
	    bind::removeBindTag $evalText disableKeys
	}

	set stdin 1
	set data [$tkcon ConGets [string trimright "$cmd $num"]]
	set stdin 0
	set nobreak 0

	if {$disabled} {
	    $evalText configure -state disabled
	    $evalText tag add disable 0.0 "end + 1 lines"
	    bind::addBindTags $evalText disableKeys
	    update
	}

	# Depending on the command (cmd) we have to 
	# chop to the user input to size ...

	if {[string equal $cmd gets]} {
	    # [gets] always returns only one line
	    set data [lindex [split $data \n] 0]
	} elseif {($num != {}) && ([string length $data] > $num)} {
	    # Chop [read] data to requested size.
	    set data [string range $data 0 [incr num -1]]
	}

	# Immediate return of generated data.
	eval [linsert $oncomplete end $data]
	return
    }
}

# ### ### ### ######### ######### #########
## Ready to go

package provide evalWin 1.0
