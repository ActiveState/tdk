# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# breakWin.tcl --
#
#	This file implements the Breakpoint Window.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# SCCS: @(#) breakWin.tcl 1.13 98/05/02 14:01:01

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require icolist

# ### ### ### ######### ######### #########
## Implementation

snit::type bp {
    variable icoList {}

    # An array that caches the handle to each breakpoint
    # in the nub.

    variable breakpoint -array {}

    # If the name of the file is empty, then it is assumed
    # to be a dynamic block.  Use this string to tell
    # the user.

    variable dynamicBlock {<Dynamic Block>}

    # ### ### ### ######### ######### #########

    variable             code
    variable             icon
    variable             var
    variable             watch
    variable             dbg
    variable             brk
    variable             blkmgr
    variable             fdb
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set code    [$gui code]
	set icon    [$gui icon]
	set var     [$gui var]
	set watch   [$gui watch]
	set engine_ [$gui cget -engine]
	set dbg     [$engine_ dbg]
	set brk     [$engine_ brk]
	set blkmgr  [$engine_ blk]
	set fdb     [$engine_ fdb]
	return
    }

    # ### ### ### ######### ######### #########

    # method showWindow --
    #
    #	Show the window to displays and set breakpoints.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The handle top the toplevel window created.

    method showWindow {} {

	# If the window already exists, show it, otherwise create it
	# from scratch.

	set top [$gui breakDbgWin]

	if {[winfo exists $top]} {
	    $self updateWindow
	    wm deiconify $top
	} else {
	    $self createWindow
	    $self updateWindow
	}    

	focus $icoList
	return $top
    }

    # method createWindow --
    #
    #	Create the window that displays and manipulates breakpoints.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    variable showBut
    variable remBut
    variable allBut

    method createWindow {} {
	set breakDbgWin [toplevel [$gui breakDbgWin]]
	::guiUtil::positionWindow $breakDbgWin 400x250
	wm minsize                $breakDbgWin 100 100
	wm title                  $breakDbgWin "Breakpoints - [$gui cget -title]"
	wm transient              $breakDbgWin $gui

	set pad 3

	# Create the table that lists the existing breakpoints.  This
	# is a live, editable list that shows the current breakpoints
	# and the state of each breakpoint. Add buttons to the right
	# for editing the table.

	set icoList [icolist $breakDbgWin.icoList \
			 -height 100 \
			 -headers {{Definition}} \
			 -tags     [list breakDbgWin$self breakDbgWin] \
			 -onselect [mymethod checkState] \
			 -ontoggle [mymethod ToggleBreak] \
			 -statemap {
			     enabledLBPBreak  break_e
			     enabledVBPBreak  var_e
			     disabledLBPBreak break_d
			     disabledVBPBreak var_d
			 }]

	set butFrm  [ttk::frame $breakDbgWin.butFrm]
	set showBut [ttk::button $butFrm.showBut -text "Show Code"  \
		-command [mymethod showCode] -state disabled]
	set remBut  [ttk::button $butFrm.remBut -text "Remove" \
		-command [mymethod removeSelected] -state disabled]
	set allBut  [ttk::button $butFrm.allBut -text "Remove All" \
		-command [mymethod removeAll] -state disabled]
	set closeBut  [ttk::button $butFrm.closeBut -text "Close" \
		-command [list destroy $breakDbgWin]]

	pack $showBut $remBut $allBut $closeBut -fill x -padx $pad -pady 3

	grid $icoList -row 0 -column 0 -sticky nswe -padx $pad -pady $pad
	grid $butFrm  -row 0 -column 1 -sticky ns

	grid columnconfigure $breakDbgWin 0 -weight 1
	grid rowconfigure    $breakDbgWin 0 -weight 1

	bind::addBindTags $showBut breakDbgWin$self
	bind::addBindTags $remBut  breakDbgWin$self
	bind::addBindTags $allBut  breakDbgWin$self

	bind::commonBindings breakDbgWin$self \
	    [list [$icoList ourFocus] $showBut $remBut $allBut $closeBut]

	# Set-up the default and window specific bindings.

	bind breakDbgWin$self <Double-1> "\
		[mymethod showCode] ; \
		break ; \
		"
	bind breakDbgWin$self <<Dbg_RemSel>> "\
		[mymethod removeSelected] ; \
		break ; \
		"
	bind breakDbgWin$self <<Dbg_RemAll>> "\
		[mymethod removeAll] ; \
		break ; \
		"
	bind breakDbgWin$self <<Dbg_ShowCode>> "\
		[mymethod showCode] ; \
		break ; \
		"
	bind breakDbgWin$self <Return> "\
		[mymethod ToggleBreakAt] ; \
		break ; \
		"
	bind $breakDbgWin <Escape> "$closeBut invoke; break"
	return
    }

    # method updateWindow --
    #
    #	Update the list of breakpoints so it shows the most
    # 	current representation of all breakpoints.  This proc
    #	should be called after the -> showWindow, after
    #	any LBP events in the CodeBar, or any VBP events in 
    #	the Var/Watch Windows.
    #
    # Arguments:
    #	None.
    #
    # Results:

    method updateWindow {} {
	# If the window is not current mapped, then there is no need to 
	# update the display.

	if {![winfo exists [$gui breakDbgWin]]} return

	# Clear out the display and remove any breakpoint locs 
	# that may have been cached in previous displays.

	set act [$icoList getActive]

	$icoList clear

	array unset breakpoint *

	# This is used when inserting LBPs and VBPs.  The breakpoint
	# handles are stored in the -> "breakpoint" array and are
	# accessed according to the line number of the bp in the text
	# widget.

	set currentLine 1

	# The breakpoints are in an unordered list.  Create an array
	# so the breakpoints can be sorted in order of file name, line
	# number and the test.

	set bps [$dbg getLineBreakpoints]
	set ildata {}

	if {[llength $bps]} {
	    foreach bp $bps {
		set state [$brk getState $bp]
		set test  [$brk getTest $bp]
		set loc   [$brk getLocation $bp]
		set line  [loc::getLine $loc]
		set blk   [loc::getBlock $loc]
		set file  [$fdb getUniqueFile $blk]

		set unsorted($file,$line,$test) [list $bp $file $line $state $test]
	    }

	    foreach name [lsort -dictionary [array names unsorted]] {
		set bp    [lindex $unsorted($name) 0]
		set file  [lindex $unsorted($name) 1]
		set line  [lindex $unsorted($name) 2]
		set state [lindex $unsorted($name) 3]
		set test  [lindex $unsorted($name) 4]

		set file [file tail $file]
		if {$file == {}} {
		    set file $dynamicBlock
		}

		# The tab stop of the icoList text widget is large enough
		# for the breakpoint icons.  Insert the breakpoint description
		# after a tab so all of the descriptions remained lined-up
		# even if the icon is removed.

		if {$state eq "enabled"} {
		    lappend ildata [list enabledLBPBreak  "$file: $line"]
		} else {
		    lappend ildata [list disabledLBPBreak "$file: $line"]
		}

		# Cache the <loc> object based on the line number of
		# the description in the icoList widget.

		set breakpoint($currentLine) $bp
		incr currentLine
	    }
	    unset unsorted
	}

	# The breakpoints are in an unordered list.  Create an array
	# so the breakpoints can be sorted in order of the contents in
	# the VBP client data ({orig name & level} {new name & level})
	
	if {[$gui getCurrentState] eq "stopped"} {
	    set bps [$dbg getVarBreakpoints]
	} else {
	    set bps {}
	}

	if {[llength $bps]} {
	    foreach bp $bps {
		set state [$brk getState $bp]
		set test  [$brk getTest $bp]
		set data  [$brk getData $bp]
		set index [join $data { }]
		set unsorted($index) [list $bp $state $test $data]
	    }

	    foreach name [lsort -dictionary [array names unsorted]] {
		set bp    [lindex $unsorted($name) 0]
		set state [lindex $unsorted($name) 1]
		set test  [lindex $unsorted($name) 2]
		set data  [lindex $unsorted($name) 3]

		set oLevel [$icon getVBPOrigLevel $bp]
		set oName  [code::mangle [$icon getVBPOrigName  $bp]]
		set nLevel [$icon getVBPNextLevel $bp]
		set nName  [code::mangle [$icon getVBPNextName  $bp]]

		set def "\{$oName: $oLevel\}"
		if {($nName != "") || ($nLevel != "")} {
		    append def { } "\{$nName: $nLevel\}"
		}

		if {$state eq "enabled"} {
		    lappend ildata [list enabledVBPBreak  $def]
		} else {
		    lappend ildata [list disabledVBPBreak $def]
		}

		set breakpoint($currentLine) $bp
		incr currentLine
	    }    
	    unset unsorted
	}

	$icoList update $ildata

	catch {$icoList select $act}
	$self checkState
	return
    }

    # method showCode --
    #
    #	Show the block of code where the breakpoint is set.
    #	At this point the Stack and Var Windows will be out
    #	of synch with the Code Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method showCode {} {
	# Bugzilla 21424 ... Break out if there is nothing we could
	# display code for. A double-click can bypass the 'Show Code'
	# button and its protection against invokation.

	if {![array size breakpoint]} return

	# There may be more then one line highlighted.  Just
	# get the active line that's highlighted, and show
	# it's code.

	set item [$icoList getActive]
	if {$item eq ""} return
	if {$item == 0} return

	if {[$brk getType $breakpoint($item)] eq "line"} {
	    set loc  [$brk getLocation $breakpoint($item)]
	    
	    # The BPs are preserved between sessions. The file
	    # associated with the breakpoint may or may not still
	    # exist. To verify this, get the Block source. If there is
	    # an error, set the loc to {}. This way the BP doesn't
	    # cause an error, but gives feedback that the file cannot
	    # be found.
	    
	    if {[catch {$blkmgr getSource [loc::getBlock $loc]}]} {
		set loc {}
	    }
	    $gui showCode $loc
	}

	return
    }

    # method removeAll --
    #
    #	Remove all of the breakpoints.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method removeAll {} {
	# Remove all of the BPs from the nub.
	set updateCodeBar  0
	set updateVarWatch 0

	foreach {line bp} [array get breakpoint] {
	    if {[$brk getType $bp] eq "line"} {
		set updateCodeBar  1
	    } else {
		set updateVarWatch 1
	    }
	    $dbg removeBreakpoint $bp
	}

	# Based on the type of breakpoints we removed, update 
	# related windows.

	if {$updateCodeBar} {
	    pref::groupSetDirty Project 1
	    $code updateCodeBar
	}
	if {$updateVarWatch} {
	    $var   updateWindow
	    $watch updateWindow
	}

	$self updateWindow
	return
    }

    # method removeSelected --
    #
    #	Remove all of the highlighted breakpoints.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method removeSelected {} {
	# Remove the selected BPs from the nub.  Set flags based
	# on what types of BPs were removed of related windows
	# can be updated.

	set updateCodeBar  0
	set updateVarWatch 0

	set cursor         [$icoList getActive]
	set selectedLines  [$icoList getSelection] 

	foreach line $selectedLines {
	    if {[$brk getType $breakpoint($line)] eq "line"} {
		set updateCodeBar  1
	    } else {
		set updateVarWatch 1
	    }
	    $dbg removeBreakpoint $breakpoint($line)
	}

	if {$selectedLines != {}} {
	    $self updateWindow
	}
	if {$updateCodeBar} {
	    pref::groupSetDirty Project 1
	    $code updateCodeBar
	}
	if {$updateVarWatch} {
	    $var   updateWindow
	    $watch updateWindow
	}
    }

    # method checkState --
    #
    #	Check the state of the Breakpoint Window.  Enable the
    #	"Remove All" button if there are entries in the window.
    #	Enable the "Show Code" and "Remove" buttons if there 
    #	are one or more selected lines.  Remove the first two
    #	chars where the BP icons are located.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method checkState {args} {
	# If the window is not current mapped, then there is no need to 
	# update the display.

	if {![winfo exists [$gui breakDbgWin]]} return

	set lines [$icoList getSelection]

	# Check to see if the selection contains line breakpoints.

	set state disabled
	if {[llength $lines]} {
	    foreach item $lines {
		if {[$brk getType $breakpoint($item)] eq "line"} {
		    set state normal
		    break
		}
	    }
	}

	$showBut configure -state $state

	# Bugzilla 21424 ...
	# If the breakpoints array exists, then there are BPs displayed
	# in the window; Enable the "Remove" button if there is at least
	# one selected line too.

	# Note that it is possible to have no breakpoints and a selected
	# line (with nothing in it). THe "Remove" button has to be disabled
	# in that case.

	if {($lines == {}) || ![info exist breakpoint]} {
	    $remBut configure -state disabled
	} else {
	    $remBut configure -state normal
	}

	# If the breakpoints array exists, then there are BPs displayed
	# in the window; Enable the "Remove All" button.  Otherwise
	# disable this button.

	if {[info exist breakpoint]} {
	    $allBut configure -state normal
	} else {
	    $allBut configure -state disabled
	}  
	return
    }

    # method ToggleBreak --
    #
    #	Toggle the state of the breakpoint between enabled and
    #	disabled.  If there are multiple breakpoints highlighted,
    #	then set all of them to the new state of the selected
    #	breakpoint.
    #
    # Arguments:
    #	index	The location of the selected icon.
    #
    # Results:
    #	None.

    method ToggleBreakAt {args} {
	$self ToggleBreak [$icoList getActive]
	return
    }

    method ToggleBreak {_ sel} {
	# If there is no info for the selected line, then the user has
	# selected a line in the text widget that does not contain a
	# BP. Return w/o doing anything.

	if {![info exists breakpoint($sel)]} return

	set selType [$brk getType $breakpoint($sel)]

	# Get the state of breakpoint at index in the text widget.
	# Use this state to determine the new state of one or more
	# selected breakpoints.

	if {$selType eq "line"} {
	    set loc  [$brk getLocation $breakpoint($sel)]
	    set breakState [$icon getLBPState $loc]
	} else {
	    set level [$icon getVBPOrigLevel $breakpoint($sel)]
	    set name  [$icon getVBPOrigName  $breakpoint($sel)]
	    set breakState [$icon getVBPState $level $name]
	}

	# If the BP is not highlighted, only toggle the selected BP.
	# Otherwise, get a list of selected BPs, determine each type
	# and call the correct procedure to toggle the BPs

	set updateCodeBar  0
	set updateVarWatch 0

	if {![$icoList inSelection $sel]} {
	    $self TB $sel $breakState
	} else {
	    foreach line [$icoList getSelection] {
		$self TB $line $breakState
	    }
	} 
	
	# If one or more VBPs were toggled we need to update the Var
	# and Watch Windows.

	if {$updateVarWatch} {
	    $var   updateWindow
	    $watch updateWindow
	}

	# If one or more LBPs were toggled we need to update the 
	# CodeBar to display the current LBPs.

	$code updateCodeBar

	# Update all local icons
	$self updateWindow
	return
    }

    method TB {item breakState} {
	upvar 1 updateCodeBar updateCodeBar updateVarWatch updateVarWatch
	set type [$brk getType $breakpoint($item)]
	if {$type eq "line"} {
	    $self toggleLBP $item $breakState
	    set updateCodeBar 1
	} else {
	    $self toggleVBP $item $breakState
	    set updateVarWatch 1
	}
    }

    # method toggleLBP --
    #
    #	Toggle a line breakpoint in the Break Window.
    #
    # Arguments:
    #	text		The Break Window's text widget.
    #	line		The line number of the BP in the text widget.
    #	breakState	The new state of the BP
    #
    # Results:
    #	None.

    method toggleLBP {line breakState} {
	set loc [$brk getLocation $breakpoint($line)]
	$icon toggleLBPEnableDisable {} {} $loc $breakState
    }

    # method toggleVBP --
    #
    #	Toggle a line breakpoint in the Break Window.
    #
    # Arguments:
    #	text		The Break Window's text widget.
    #	line		The line number of the BP in the text widget.
    #	breakState	The new state of the BP
    #
    # Results:
    #	None.

    method toggleVBP {line breakState} {
	set level [$icon getVBPOrigLevel $breakpoint($line)]
	set name  [$icon getVBPOrigName  $breakpoint($line)]
	return [$icon toggleVBPEnableDisable $level $name $breakState]
    }

    # method setProjectBreakpoints --
    #
    #	Remove any existing breakpoints and restore 
    #	the projects LBP from the bps list.
    #
    # Arguments:
    #	bps	The list of breakpoints to restore
    #
    # Results:
    #	None.

    method setProjectBreakpoints {bps} {
	foreach lbp [$dbg getLineBreakpoints] {
	    $dbg removeBreakpoint $lbp
	}
	$brk restoreBreakpoints $bps
	$fdb update 1
	$self updateWindow
	return
    }

    # method setProjectSpawnpoints --
    #
    #	Remove any existing spawnpoints and restore 
    #	the projects SP from the bps list.
    #
    # Arguments:
    #	bps	The list of spawnpoints to restore
    #
    # Results:
    #	None.

    method setProjectSpawnpoints {bps} {
	foreach sp [$dbg getSpawnpoints] {
	    $dbg removeBreakpoint $sp
	}
	$brk restoreSpawnpoints $bps
	$fdb update 1
	$self updateWindow
	return
    }
}

# ### ### ### ######### ######### #########
## Ready to go

package provide bp 1.0
