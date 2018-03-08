# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# codeWin.tcl --
#
#	This file implements the Code Window and the CodeBar APIs.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# SCCS: @(#) codeWin.tcl 1.16 98/05/02 14:01:16

package require parser
package require fmttext

if {[package vcompare 8.3 [package present Tk]] < 0} {
    # Added to allow usage of code by an 8.4 core.
    ::tk::unsupported::ExposePrivateVariable tkPriv
}

snit::widget codeWin {
    # Handles to the CodeBar, LineBar and Code Windows.

    variable lineBar {}
    variable codeBar {}
    variable codeWin {}

    # There is currently a modal interface for settign BPs using
    # keystrokes.  Any key stroke between 0 and 9 is appended to
    # breakLineNum.  When Return is pressed the number stored
    # in this var will tobble the BP on or off.

    variable breakLineNum {}

    # Contains at least one newline for every line in the current block.  This
    # variable grows as needed.

    variable newlines "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"

    variable currentmsg ""
    variable oldmsg     ""
    variable lock 0

    variable codeTitle ; # Bugzilla 19824 ...

    # ### ### ### ######### ######### #########

    variable             icon    {}
    variable             stack   {}
    variable             bpw     {}
    variable             checker {}
    variable             dbg
    variable             blkmgr
    variable             brk
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value

	set stack   [$gui stack]
	set icon    [$gui icon]
	set bpw     [$gui bp]
	set checker [$gui checker]
	set engine_ [$gui cget -engine]
	set dbg     [$engine_ dbg]
	set blkmgr  [$engine_ blk]
	set brk     [$engine_ brk]
	return
    }

    variable     coverobj {}
    option      -coverobj {}
    onconfigure -coverobj {value} {
	set coverobj $value
	set options(-coverobj) $value
	return
    }

    variable     coverage {}
    option      -coverage {}
    onconfigure -coverage {value} {
	set coverage $value
	set options(-coverage) $value
	return
    }

    # ### ### ### ######### ######### #########

    constructor {args} {
	$self GSetup [from args -gui]
	$self createWindow
	$self configurelist $args

	$gui registerStatusMessage $codeBar \
		"Click in the bar to set a line breakpoint."

	$codeWin configure -yscroll [mymethod moveScrollbar  $yScroll]
	$codeWin configure -xscroll [mymethod moveScrollbarX $xScroll]
	return
    }

    # ### ### ### ######### ######### #########

    # method createWindow --
    #
    #	Create the CodeBar, LineBar and the Code Window.
    #
    # Arguments:
    #	masterFrm	The frame that contains the code widgets.
    #
    # Results:
    #	The sub frame that contains the code widgets.

    variable xScroll
    variable yScroll

    method createWindow {} {
	array set bar [system::getBar]

	# Bugzilla 19824 ...
	set codeTitle  [ttk::label $win.title -text <none> -anchor w]

	set codeFrm    [ttk::frame $win.code]
	set codeSubFrm [ttk::frame $codeFrm.subFrm \
			    -borderwidth 1 -relief sunken]
	set codeBarFrm [ttk::frame $codeSubFrm.codeBarFrm -width $bar(width)]
	set codeBar    [text $codeBarFrm.codeBar -width 1 -bd 0 -bg $bar(color)]
	set lineBar    [text $codeSubFrm.lineBar -width 1 -bd 0]
	set codeWin    [text $codeSubFrm.text -width 1 -bd 0]

	set yScroll [scrollbar $codeSubFrm.yScroll \
		-command [mymethod scrollWindow]]

	set xScroll [scrollbar $codeSubFrm.xScroll -orient horizontal \
		-command [list $codeWin xview]]

	pack $codeBar -fill both -expand true

	grid $codeBarFrm -row 0 -column 0 -sticky ns
	grid $lineBar    -row 0 -column 1 -sticky ns
	grid $codeWin    -row 0 -column 2 -sticky news

	grid rowconfigure    $codeSubFrm 0 -weight 1
	grid columnconfigure $codeSubFrm 2 -weight 1

	# Turn off propagation of the CodeBar's containing frame.  This
	# way, we can explicitly set the size of the CodeBar to the size
	# of the largest icon.

	pack propagate $codeBarFrm 0
	pack $codeSubFrm -pady 2 -fill both -expand true

	# Bugzilla 19824 ...
	grid $codeTitle -sticky ew
	grid $codeFrm -sticky news
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 1 -weight 1

	# Set default text bindings and override a few of the default
	# settings.  The CodeBar should have less padding, and the
	# Code Window should manage the adding/removing of the sb by
	# packing it in the containing frame, not inside the text widget.

	fmttext::setDbgTextBindings $codeBar
	fmttext::setDbgTextBindings $lineBar
	fmttext::setDbgTextBindings $codeWin

	$codeBar configure -padx 2
	$codeWin configure -insertwidth 2
	$self updateTabStops

	# Now add the rest of the bindings to the CodeBar, LineBar
	# and Code Window.

	bind::addBindTags $codeBar [list codeDbgWin$self setBreakpoint$self]
	bind::addBindTags $lineBar [list codeDbgWin$self setBreakpoint$self]
	bind::addBindTags $codeWin [list codeDbgWin$self noEdit$self noEdit]
	bind::addBindTags $yScroll codeDbgWin$self

	bind $codeWin <KeyPress>        [mymethod updateStatusLine]
	bind $codeWin <ButtonRelease-1> [mymethod updateStatusLine]
	bind $codeWin <FocusIn>         [mymethod changeFocus in]
	bind $codeWin <FocusOut>        [mymethod changeFocus out]

	bind setBreakpoint$self <Button-1>    "[mymethod toggleLBP @0,%y onoff]         ; break"
	bind setBreakpoint$self <Control-1>   "[mymethod toggleLBP @0,%y enabledisable] ; break"

	bind setBreakpoint$self <Button-3>    "[mymethod toggleSP @0,%y onoff]         ; break"
	bind setBreakpoint$self <Control-3>   "[mymethod toggleSP @0,%y enabledisable] ; break"

	bind codeDbgWin$self <Return>         "[mymethod toggleLBPAtInsert onoff]         ; break"
	bind codeDbgWin$self <Control-Return> "[mymethod toggleLBPAtInsert enabledisable] ; break"

	bind codeDbgWin$self <S>         "[mymethod toggleSPAtInsert onoff]         ; break"
	bind codeDbgWin$self <Control-S> "[mymethod toggleSPAtInsert enabledisable] ; break"
	bind codeDbgWin$self <s>         "[mymethod toggleSPAtInsert onoff]         ; break"
	bind codeDbgWin$self <Control-s> "[mymethod toggleSPAtInsert enabledisable] ; break"

	bind codeDbgWin$self <A>         "[mymethod allSPOn] ; break"
	bind codeDbgWin$self <a>         "[mymethod allSPOn] ; break"


	bind noEdit$self <B1-Leave> "
	    set tkPriv(x) %x
	    set tkPriv(y) %y
	    [mymethod tkTextAutoScan]
	    break;
	"

	$self checkInit
	return
    }

    method textIndex {index} {
	return [$codeWin index $index]
    }
    method text    {args} {
	if {[llength $args]} {
	    return [eval [linsert $args 0 $codeWin]]
	}
	return $codeWin
    }
    method lineBar {} {return $lineBar}
    method codeBar {} {return $codeBar}

    # method updateWindow --
    #
    #	Update the display of the Code Window and CodeBar 
    #	after (1) a file is loaded (2) a breakpoint is hit 
    #	or (3) a new stack frame was selected from the 
    #	stack window.
    #
    # Arguments:
    #	loc	Opaque <loc> type that contains the script.
    #
    # Results:
    #	None.

    method updateWindow {loc} {
	# If the location is empty, then there is no source code
	# available to display.  Clear the Code Window, CodeBar,
	# and LineBar; set the currentBlock to empty; and update
	#  the Status window so no filename is displayed.

	#puts "cw updateWindow ($loc)"

	if {$loc == {}} {
	    $self resetWindow "No Source Code..."
	    $gui setCurrentBlock {}
	    $gui setCurrentFile  {}
	    $gui setCurrentLine  {}
	    return
	}

	set allspon 0

	set blk   [loc::getBlock $loc]
	set line  [loc::getLine  $loc]
	set range [loc::getRange $loc]
	set file  [$blkmgr getFile    $blk]
	set ver   [$blkmgr getVersion $blk]

	#puts "\t$ver = ($file)"

	if {[catch {set src [$blkmgr getSource $blk]} err]} {
	    tk_messageBox -icon error -type ok -title "Error" \
		    -parent [$gui getParent] -message $err
	    return
	}

	# If the next block is different from the current block,
	# delete contents of the Code Window, insert the new
	# data, and update the LineBar.  Otherwise, it's the
	# same block, just remove the highlighting from the Code
	# Window so we don't have multiple lines highlighted. 

	# Bugfix: Refresh of display gone wrong when changing
	# the script in project settings, because the reset of
	# the block counter in lib/dbg_engine/block.tcl
	# (release all) now causes us to see no change here.
	# We fix by now comparing file paths as well.

	if {
	    ($blk  != [$gui getCurrentBlock]) ||
	    ($ver  != [$gui getCurrentVer])   ||
	    ($file ne [$gui getCurrentFile])
	} {
	    #puts	    "$blk != [$gui getCurrentBlock]"
	    #puts 	    "$ver != [$gui getCurrentVer]"

	    # Bugzilla 19824 ...
	    $codeTitle configure -text [$blkmgr title $blk]

	    $codeWin delete 0.0 end
	    $codeWin insert end [code::binaryClean $src]

	    # Foreach line in the Code Window, add a line numer to
	    # the LineBar.  Get the string length of the last line
	    # number entered, and set the width of the LineBar.

	    set numLines [$self getCodeSize]
	    for {set i 1} {$i <= $numLines} {incr i} {
		if {$i == 1} {
		    set str "$i"
		} else {
		    append str "\n$i"
		}
	    }
	    set lineBarWidth [string length $numLines]
	    if {$lineBarWidth < 3} {
		set lineBarWidth 3
	    }
	    $lineBar configure -width $lineBarWidth
	    $lineBar delete 0.0 end
	    $lineBar insert 0.0 $str right

	    # Set the current GUI defaults for this block.

	    $gui setCurrentBlock $blk
	    $gui setCurrentVer   $ver
	    $gui setCurrentFile  $file

	    # Integration of the checker into the debugger .
	    # New file implies that we have to kill an existing checker
	    # process and start a new one using the current contents of
	    # the windows.

	    $checker kill
	    $checker start

	    # New feature: Automatically add all possible spawnpoints
	    # to every new block shown in the display.
	    if {[pref::prefGet autoAddSpawn]} {
		set allspon 1
	    }

	    # Show coverage ranges ...

	    if {$coverage} {
		#puts highlight.....[clock format [clock seconds]]
		$coverobj highlightRanges $blk
		#puts highlight/////[clock format [clock seconds]]
	    }

	} else {
	    $codeWin tag remove highlight 0.0 end
	    $codeWin tag remove highlight_error 0.0 end
	    $codeWin tag remove highlight_cmdresult 0.0 end
	}
	$gui setCurrentLine $line


	# Calculate the beginning and ending indices to be 
	# highlighted for the next statement.  If the line 
	# in the <loc> is empty, highlight nothing.  If the 
	# range in the <loc> is empty, highlight the entire 
	# line.  Otherwise, determine if the range spans 
	# multiple lines.  If it does, only highlight the
	# first line.  If it does not, then highlight the
	# entire range.

	if {$line == {}} {
	    set cmdStart 0.0
	    set cmdEnd [$codeWin index "0.0 - 1 chars"]
	} elseif {$range == {}} {
	    set cmdStart [$codeWin index $line.0]
	    set cmdEnd   [$codeWin index "$cmdStart lineend + 1 chars"]
	} else {
	    set start [parse charindex $src $range]
	    set end   [expr {$start + [parse charlength $src $range]}]
	    set cmdStart [$codeWin index "0.0 + $start chars"]
	    set cmdMid   [$codeWin index "$cmdStart lineend"]
	    set cmdEnd   [$codeWin index "0.0 + $end chars"]
	    
	    # If cmdEnd is > cmdMid, the range spans multiple lines.
	    if {[$codeWin compare $cmdEnd > $cmdMid]} {
		set cmdEnd $cmdMid
	    }
	}
	$codeWin tag add [$self getHighlightTag] $cmdStart $cmdEnd

	# Move the end of the command into view, then move the beginning
	# of the command into view.  Doing it in this order attempts to
	# bring as much of the statement into view as possible.  If the
	# entire statement is greater then the viewable region, then the
	# top of the statement is always in view.
	
	if {[$codeWin dlineinfo "$cmdStart+2 lines"] == ""} {
	    $codeWin see "$cmdStart+2 lines"
	}
	$codeWin see "$cmdEnd linestart"
	$codeWin see $cmdStart

	# Move the insertion cursor to the beginning of the highlighted
	# statement.

	$codeWin mark set insert $cmdStart

	# Move the CodeBar and LineBar to the same viewable region as 
	# the Code Window.

	$codeBar yview moveto [lindex [$codeWin yview] 0]
	$lineBar yview moveto [lindex [$codeWin yview] 0]

	if {$allspon} {
	    after 10 [mymethod allSPOn]
	}

	return
    }

    # method updateCodeBar --
    #
    #	Update the display of the CodeBar.  Get a list of all
    #	the breakpoints for the current file and display one
    #	icon for each line that contains a breakpoint.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateCodeBar {} {
	$dbg Log timing {updateCodeBar}

	# If the current block is empty string, then we are in a hidden
	# frame that has no information on location, block etc.  Just
	# remove all icons from the code bar and return.

	$codeBar delete 0.0 end
	set blk [$gui getCurrentBlock]
	if {$blk == {}} {return}

	# A newline has to be inserted into the CodeBar for every
	# line of text in the Code Window, otherwise the images in 
	# the CodeBar will not line up with the Code Window.

	set validLines [$blkmgr getLines $blk]
	set numLines   [$self getCodeSize]

	# Ensure that we have enough newlines for the whole string.
	while {$numLines > [string length $newlines]} {
	    append newlines $newlines
	}

	# Now add dashes on the lines where we can set breakpoints.

	if {$validLines == "-1"} {
	    # All lines are valid at this point, so insert the dash
	    # on every line.

	    regsub -all \n [string range $newlines 0 [expr {$numLines - 1}]] \
		    --\n str

	    # Remove the last newline char so the ends of long code blocks
	    # will line up with the dashes (fix for bug 2523).

	    set str [string range $str 0 end-1]
	} else {

	    set str {}
	    set lastLine 1
	    foreach codeLine $validLines {
		append str [string range $newlines 0 \
			[expr {$codeLine - $lastLine - 1}]] "--"
		set lastLine $codeLine
	    }
	    # Pad the buffer with enough blank lines at the end so they match up.
	    append str [string range $newlines 0 \
		    [expr {$numLines - $lastLine - 1 }]]
	}

	$codeBar insert 0.0 $str codeBarText
	$codeBar tag configure codeBarText -foreground blue
	
	# Insert icons for each breakpoint.  Since breakpoints can
	# share the same location, only compute the type of icon to
	# draw for each unique location. 

	set bpLoc [loc::makeLocation $blk {}]
	set bpList [$dbg getLineBreakpoints $bpLoc]
	set spList [$dbg getSpawnpoints     $bpLoc]

	foreach bp $bpList {
	    set theLoc [$brk getLocation $bp]
	    set breakLoc($theLoc) 1
	}
	foreach sp $spList {
	    set theLoc [$brk getLocation $sp]
	    set breakLoc($theLoc) 2
	}

	set updateBp 0
	foreach bpLoc [array names breakLoc] {
	    set nextLine   [loc::getLine $bpLoc]

	    set spawnState [$icon getSPState  $bpLoc]
	    set breakState [$icon getLBPState $bpLoc]

	    if {($spawnState ne "noSpawn") && ($breakState ne "noBreak")} {
		set merge ${breakState}_${spawnState}
		set breakState $merge
		set spawnState $merge
	    }

	    if {$breakLoc($bpLoc) == 2} {
		if {$nextLine <= $numLines} {
		    $icon drawSP $codeBar $nextLine.0 $spawnState
		} else {
		    $icon setSP noSpawn $bpLoc
		    set updateBp 1
		}
	    } else {
		if {$nextLine <= $numLines} {
		    $icon drawLBP $codeBar $nextLine.0 $breakState
		} else {
		    $icon setLBP noBreak $bpLoc
		    set updateBp 1
		}
	    }
	}
	if {$updateBp} {
	    $bpw updateWindow
	}

	# Draw the "PC" icon if we have an index for it.  Get the <loc>
	# for the currently selected stack frame.  If the block in the
	# selected stack frame is the same as the currently displayed
	# block, then draw the PC.

	set stackLoc [$stack getPC]
	if {$stackLoc != {}} {
	    if {[loc::getBlock $stackLoc] == $blk} {
		set pc [loc::getLine $stackLoc]
		if {$pc != {}} {
		    $icon setCurrentIcon $codeBar $pc.0 \
			    [$gui getCurrentBreak] \
			    [$stack getPCType]
		}
	    }
	}

	# Move the CodeBar to the same viewable region as the Code Window.
	$codeBar yview moveto [lindex [$codeWin yview] 0]
    }

    # method updateTabStops --
    #
    #	Reset the tab stops to be consistent with current preferences.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateTabStops {} {
	if {[winfo exists $codeWin]} {
	    set tabWidth  [expr {$font::metrics(-width) * [pref::prefGet tabSize]}]
	    $codeWin configure -tabs $tabWidth
	}
	return
    }

    # method updateStatusLine --
    #
    #	Change the status message for the filename/line number
    #	so the line number is always where the current cursor is.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateStatusLine {} {
	$gui updateStatusLine [$self getInsertLine]
    }

    # method resetWindow --
    #
    #	Clear the contents of the CodeBar, LineBar and Code Window.  
    # 	If msg is not null, display this message in the Code window.
    #
    # Arguments:
    #	msg	A message to be placed in the Code Window.
    #
    # Results:
    #	None.

    method resetWindow {{msg {}}} {
	$codeWin tag remove highlight 0.0 end
	$codeWin tag remove highlight_error 0.0 end
	$codeWin tag remove highlight_cmdresult 0.0 end
	$self changeFocus out
	$icon unsetCurrentIcon $codeBar currentImage
	if {$msg != {}} {
	    $codeBar delete 0.0 end
	    $lineBar delete 0.0 end
	    $codeWin delete 0.0 end
	    $codeWin insert 0.0 $msg message
	    $gui setCurrentBlock {}
	    $gui setCurrentFile  {}
	    $gui setCurrentLine  {}
	}
    }

    # method changeFocus --
    #
    #	Change the graphical feedback when focus changes.
    #
    # Arguments:
    #	focus	The type of focus change (in or out.)
    #
    # Results:
    #	None.

    method changeFocus {focus} {
	$codeWin tag remove focusIn 1.0 end
	if {$focus == "in"} {
	    set ranges [$codeWin tag ranges [$self getHighlightTag]]
	    foreach {start end} $ranges {
		$codeWin tag add focusIn $start $end
	    }
	}
    }

    # method focusCodeWin --
    #
    #	If the Code Window already has the focus when
    # 	"focus" is called on it, it will not report the
    #	FocusIn event.   This will leave stale "focus
    #	rings" in the display.  This proc circumvents
    #	this from happening.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method focusCodeWin {} {
	if {[focus] == $codeWin} {
	    $self changeFocus in
	} else {
	    focus -force $codeWin
	}
    }

    # method scrollWindow --
    #
    #	Scroll the Code Window and the CodeBar in parallel.
    #
    # Arguments:
    #	args	Args from the scroll callback.
    #
    # Results:
    #	None.

    method scrollWindow {args} {
	eval [list $codeWin yview] $args
	$lineBar yview moveto [lindex [$codeWin yview] 0]
	$codeBar yview moveto [lindex [$codeWin yview] 0]
	return
    }

    # method moveScrollbar --
    #
    #	Move the elevator of the scrollbar while maintaining
    #	the alignment between the CodeWin, CodeBar and LineBar.
    #
    # Arguments:
    #	sb	The handle to the scrollbar to be updated.
    #	args	Args to pass to the scrollbar that give the
    #		new elevator locations.
    #
    # Results:
    #	None.

    method moveScrollbar {sb args} {
	eval [list fmttext::scrollDbgText $codeWin $sb [list grid $sb -row 0 -column 3 -sticky nse]] $args
	$lineBar yview moveto [lindex [$codeWin yview] 0]
	$codeBar yview moveto [lindex [$codeWin yview] 0]
	return
    }

    # method moveScrollbarX --
    #
    #	Move the elevator of the scrollbar while maintaining
    #	the alignment between the CodeWin, CodeBar and LineBar.
    #
    # Arguments:
    #	sb	The handle to the scrollbar to be updated.
    #	args	Args to pass to the scrollbar that give the
    #		new elevator locations.
    #
    # Results:
    #	None.

    method moveScrollbarX {sb args} {
	eval [list fmttext::scrollDbgTextX $sb \
		[list grid $sb -row 1 -column 1 -columnspan 2 -sticky ews]] $args
    }

    # method tkTextAutoScan --
    #
    #	Override the <B1-Motion> binding on the CodeWin
    #	with one that will scroll the CodeBar, LineBar
    #	and CodeWin synchronously.
    #
    # Arguments:
    #
    # Results:
    #	None.

    method tkTextAutoScan {} {
	set w $codeWin
	global tkPriv
	if {![winfo exists $w]} return
	if {$tkPriv(y) >= [winfo height $w]} {
	    $codeBar yview scroll 2 units
	    $lineBar yview scroll 2 units
	    $codeWin yview scroll 2 units
	} elseif {$tkPriv(y) < 0} {
	    $codeBar yview scroll -2 units
	    $lineBar yview scroll -2 units
	    $codeWin yview scroll -2 units
	} elseif {$tkPriv(x) >= [winfo width $w]} {
	    $codeWin xview scroll 2 units
	} elseif {$tkPriv(x) < 0} {
	    $codeWin xview scroll -2 units
	} else {
	    return
	}
	set tkPriv(afterId) [after 50 [mymethod tkTextAutoScan]]
    }

    # method toggleLBP --
    #
    #	Toggle the breakpoint on/off or enable/disable.
    #
    # Arguments:
    #	index	The position in the CodeBar text widget to toggle
    #		breakpoint state.
    #	bptype	How to toggle ("onoff" or "enabledisable")
    #	
    #
    # Results:
    #	None.

    method toggleLBPAtInsert {bptype} {
	$self toggleLBP [$self getInsertLine].0 $bptype
    }
    method toggleLBPAtIndexInsert {bptype} {
	$self toggleLBP [$codeWin index insert] $bptype
    }
    method toggleLBP {index bptype} {
	set text $codeBar
	# Don't allow users to set a LBP on an empty block.
	# The most common occurence of this is when a new
	# sessions begins and no files are loaded.

	set blk [$gui getCurrentBlock]
	if {$blk == {}} {return}
	if {
	    (![$blkmgr isInstrumented $blk]) &&
	    ([$blkmgr  getFile        $blk] == {})
	} {
	    return
	}
	set end  [$self getCodeSize]
	set line [lindex [split [$text index $index] .] 0]

	# Only let the user toggle a break point on valid locations
	# for break points.

	if {$line > $end} {
	    return
	}
	set validLines [$blkmgr getLines $blk]
	if {
	    ($validLines                 != -1) &&
	    ([lsearch $validLines $line] == -1)
	} {
	    return
	}

	switch $bptype {
	    onoff {
		$self ToggleLBPOnOff $text $index
	    } 
	    enabledisable {
		$self ToggleLBPEnableDisable $text $index
	    }
	}

	# Update the Breakpoint window to display the latest 
	# breakpoint setting.

	$bpw updateWindow
	return
    }

    # method ToggleLBPOnOff --
    #
    #	Toggle the breakpoint at index to On or Off, 
    #	adding or removing the breakpoint in the nub.
    #
    # Arguments:
    #	text	The CodeBar text widget.
    #	index	The position in the CodeBar text widget to toggle
    #		breakpoint state.
    #
    # Results:
    #	None.

    method ToggleLBPOnOff {text index} {
	set start      [$text index "$index linestart"]
	set loc        [$self makeCodeLocation $text $index]
	set breakState [$icon getLBPState $loc]
	if {[$icon isCurrentIconAtLine $text $start]} {
	    set pcType current
	} else {
	    set pcType {}
	}
	$icon toggleLBPOnOff $text $start $loc $breakState $pcType
    }

    # method ToggleLBPEnableDisable --
    #
    #	Toggle the breakpoint at index to Enabled or Disabled, 
    #	enabling or disabling the breakpoint in the nub.
    #
    # Arguments:
    #	text	The CodeBar text widget.
    #	index	The position in the CodeBar text widget to toggle
    #		breakpoint state.
    #
    # Results:
    #	None.

    method ToggleLBPEnableDisable {text index} {
	set start      [$text index "$index linestart"]
	set loc        [$self makeCodeLocation $text $start]
	set breakState [$icon getLBPState $loc]
	if {[$icon isCurrentIconAtLine $text $start]} {
	    set pcType current
	} else {
	    set pcType {}
	}
	$icon toggleLBPEnableDisable $text $start $loc $breakState $pcType
	return
    }

    # method makeCodeLocation --
    #
    #	Helper routine for making <loc> objects based on the 
    #	line number of index, and the currently displayed block.
    #
    # Arguments:
    #	text	Text widget that index referrs to.
    #	index	Index to extract the line number from.
    #
    # Results:
    #	A <loc> object.

    method makeCodeLocation {text index} {
	set line [lindex [split [$text index $index] .] 0]
	return [loc::makeLocation [$gui getCurrentBlock] $line]
    }

    # method see --
    #
    #	Make all of the text widgets "see" the same region.
    #
    # Arguments:
    #	index	An index into the Code Win that needs to be seen.
    #
    # Results:
    #	None

    method see {index} {
	$codeWin see $index
	$codeBar yview moveto [lindex [$codeWin yview] 0]
	$lineBar yview moveto [lindex [$codeWin yview] 0]
    }

    # method yview --
    #
    #	Set the yview of the Code Win while maintaining the
    #	alignment in the text widgets.
    #
    # Arguments:
    #	args	Yview arguments.
    #
    # Results:
    #	None

    method yview {args} {
	eval [list $codeWin yview] $args
	$codeBar yview moveto [lindex [$codeWin yview] 0]
	$lineBar yview moveto [lindex [$codeWin yview] 0]    
	return
    }

    # method getCodeSize --
    #
    #	Return, in line numbers, the length for the body of code.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return, in line numbers, the length for the body of code.

    method getCodeSize {} {
	set num [lindex [split [$codeWin index "end - 1c"] .] 0]
	return $num
    }

    # method getInsertLine --
    #
    #	Return the line number of the insertion cursor or 1 if the 
    #	window does not yet exist.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return the line number of the insertion cursor.

    method getInsertLine {} {
	if {[winfo exists $codeWin]} {
	    return [lindex [split [$codeWin index insert] .] 0]
	} else {
	    return 1
	}
    }

    # method getHighlightTag --
    #
    #	Return the tag to be used for highlighting based on the current
    #	break type.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return the tag to be used for highlighting.

    method getHighlightTag {} {
	switch -- [$gui getCurrentBreak] {
	    error {
		return highlight_error
	    }
	    cmdresult {
		return highlight_cmdresult
	    }
	    default {
		return highlight
	    }
	}
    }

    method checkClear {} {
	# Remove the error and warning tags.
	foreach tag [$codeWin tag names] {
	    if {![string match chk* $tag]} {continue}
	    foreach {b e} [$codeWin tag ranges $tag] {
		$codeWin tag remove $tag $b $e
	    }
	}
	return
    }

    method checkNew {line col cole bptype msg} {
	# Determine nearest statement for this location
	# to determine the range to tag.

	$codeWin tag add  chk_$bptype    $line.$col $line.$cole
	$codeWin tag add  chk_$line.$col $line.$col $line.$cole
	$codeWin tag bind chk_$line.$col <Enter> [mymethod checkEnter $msg]
	$codeWin tag bind chk_$line.$col <Leave> [mymethod checkLeave]
	$codeWin tag bind chk_$line.$col <1>     [mymethod checkPersist]
	return
    }

    method checkInit {} {
	#puts e-tag-c=[$checker color error]  
	#puts w-tag-c=[$checker color warning]

	$codeWin tag configure chk_error   -background [$checker color error]
	$codeWin tag configure chk_warning -background [$checker color warning]
	bind $codeWin <ButtonPress-1> [mymethod checkPersistOff $codeWin]
	return
    }

    method checkCore {} {
	# Restart the checker after changes to the Tcl version.
	$checker kill
	$checker cacheClearAll
	$checker start
	return
    }

    method checkEnter {msg} {
	set currentmsg                $msg
	$gui updateStatusMessage -msg $msg
	return
    }

    method checkLeave {} {
	$gui updateStatusMessage -msg $oldmsg
	return
    }

    method checkPersist {} {
	# Enforce that the message is left in the statusbar after the
	# click. The message persists even if other messages are visited
	# along the line, until the next click.

	set lock 1
	set oldmsg $currentmsg
	return
    }

    method checkPersistOff {path} {
	# The persist binding fired, thus we ignore the widget binding,
	# once.

	if {$lock} {set lock 0 ; return}

	set oldmsg ""
	$self checkLeave
	return
    }

    method breakState {} {
	return [$icon getState $codeBar \
		[lindex [split [$codeWin index insert] .] 0]]
    }

    # ### ### ### ######### ######### #########
    ## Handling of spawn points ...
    ###

    # method toggleSP --
    #
    #	Toggle the spawn-point on/off or enable/disable.
    #
    # Arguments:
    #	index	The position in the CodeBar text widget to toggle
    #		spawn-point state.
    #	bptype	How to toggle ("onoff" or "enabledisable")
    #	
    #
    # Results:
    #	None.

    method toggleSPAtInsert {bptype} {
	$self toggleSP [$self getInsertLine].0 $bptype
    }
    method toggleSPAtIndexInsert {bptype} {
	$self toggleSP [$codeWin index insert] $bptype
    }
    method toggleSP {index bptype} {
	set text $codeBar
	# Don't allow users to set a spawn-point on an empty block.
	# The most common occurence of this is when a new session
	# begins and no files are loaded.

	set blk [$gui getCurrentBlock]
	if {$blk == {}} {return}
	if {
	    (![$blkmgr isInstrumented $blk]) &&
	    ([$blkmgr  getFile        $blk] == {})
	} {
	    return
	}
	set end  [$self getCodeSize]
	set line [lindex [split [$text index $index] .] 0]

	# Only let the user toggle a spawn point on valid locations
	# for break points.

	if {$line > $end} {
	    return
	}
	set validLines [$blkmgr getLines $blk]
	if {
	    ($validLines                 != -1) &&
	    ([lsearch $validLines $line] == -1)
	} {
	    return
	}

	switch $bptype {
	    onoff {
		$self ToggleSPOnOff $text $index
	    } 
	    enabledisable {
		$self ToggleSPEnableDisable $text $index
	    }
	}

	# Spawn points do _not_ have a dialog window to update.
	# This however is the place to change when a window is
	# added. -- FUTURE --

	# Update the Spawnpoint window to display the latest 
	# spawn-point setting.

	### $bpw updateWindow ###
	return
    }
    method allSPOn {} {
	set text $codeBar
	# Don't allow users to set a spawn-point on an empty block.
	# The most common occurence of this is when a new session
	# begins and no files are loaded.
	set undo 0
	set blk [$gui getCurrentBlock]
	if {$blk == {}} {return}
	if {![$blkmgr isInstrumented $blk]} {
	    set undo 1
	    $blkmgr Instrument $blk [$blkmgr getSource $blk]
	}
	set lines [$blkmgr getSpawnLines $blk]

	foreach l $lines {
	    set index ${l}.0
	    switch -exact -- [$icon getSPState [$self makeCodeLocation $text $index]] {
		enabledSpawn {
		    #ignore line which is already active
		}
		disabledSpawn -
		noSpawn {
		    $self ToggleSPOnOff $text $index
		}
	    }
	}

	if {$undo} {
	    # The block was not instrumented before. We now undo our
	    # instrumentation, otherwise the code talking to the
	    # backend will assume that bp/sp information has already
	    # been transfered, and will not do it. This means that the
	    # instrumentation we have done here will cause it to wrongly dismiss
	    # all bp/sp data, and the application will _not_ react to
	    # bp/sp's, as they are not known. If the block was
	    # instrumented before we came here we can assume that it
	    # was a regular instrumentation, so we have nothing to
	    # undo.
	    #
	    # The relevant place affected by the code here is
	    # dbg.tcl, method 'Instrument', around line 1911.

	    $blkmgr unmarkInstrumentedBlock $blk
	}
	return
    }

    # method ToggleSPOnOff --
    #
    #	Toggle the spawn-point at index to On or Off, 
    #	adding or removing the spawn-point in the nub.
    #
    # Arguments:
    #	text	The CodeBar text widget.
    #	index	The position in the CodeBar text widget to toggle
    #		spawn-point state.
    #
    # Results:
    #	None.

    method ToggleSPOnOff {text index} {
	set start      [$text index "$index linestart"]
	set loc        [$self makeCodeLocation $text $index]
	set spawnState [$icon getSPState $loc]
	if {[$icon isCurrentIconAtLine $text $start]} {
	    set pcType current
	} else {
	    set pcType {}
	}
	$icon toggleSPOnOff $text $start $loc $spawnState $pcType
	return
    }

    # method ToggleSPEnableDisable --
    #
    #	Toggle the spawn-point at index to Enabled or Disabled, 
    #	enabling or disabling the spawn-point in the nub.
    #
    # Arguments:
    #	text	The CodeBar text widget.
    #	index	The position in the CodeBar text widget to toggle
    #		spawn-point state.
    #
    # Results:
    #	None.

    method ToggleSPEnableDisable {text index} {
	set start      [$text index "$index linestart"]
	set loc        [$self makeCodeLocation $text $start]
	set spawnState [$icon getSPState $loc]
	if {[$icon isCurrentIconAtLine $text $start]} {
	    set pcType current
	} else {
	    set pcType {}
	}
	$icon toggleSPEnableDisable $text $start $loc $spawnState $pcType
	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Global shared code

namespace eval code {}

# code::binaryClean --
#
#	Clean up strings to remove nulls.
#
# Arguments:
#	str	The string that should be cleaned.
#
# Results:
#	Return a "binary clean" string.

proc code::binaryClean {str} {
    # Old code was for 8.0. Frontend now uses 8.3.4., \0 clean, and
    # also has additional string manipulation routines.

    return [string map [list \0 \\0] $str]
}

# code::mangle --
#
#	Clean up strings to remove nulls and newlines.
#
# Arguments:
#	str	The string that should be mangled.
#
# Results:
#	Return a "binary clean" string.

proc code::mangle {str} {
    # Old code was for 8.0. Frontend now uses 8.3.4., \0 clean, and
    # also has additional string manipulation routines.

    return [string map [list \n \\n \0 \\0] $str]
}

# ### ### ### ######### ######### #########
## Ready to go.

package provide codeWin 1.0
