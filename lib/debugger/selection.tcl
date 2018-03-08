# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# selection.tcl --
#
# Copyright (c) 2002-2007 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: prefWin.tcl,v 1.4 2000/10/31 23:31:00 welch Exp $
#
#	This file defines the APIs for selecting lines in
#	a text widget.  They imitate the Windows style 
#	selection of:
#		
#		<B1-Leave> 
#		<B1-Enter> 
#		<ButtonRelease-1> Scrolls the viewable text region.
#		
#		<FocusIn>	
#		<FocusOut>	Updates the "focus" feedback.
#
#		<Button-1>  	Select current line and remove
#			    	all previous selections.
#		<Control-1> 	Select current line and keeps
#			    	all previous selections.
#		<Shift-1>   	Select current all lines between
#			    	anchor and the cursor.
#
#		<Up>		Select previous line.
#		<Down>		Select next line.
#		<Shift-Up>	Select range up.
#		<Shift-Down>	Select range down.
#		<Control-Up>	Move cursor up.
#		<Control-Down>	Move Cursor down
#
#		<Space>		Select the line at cursor.
#		<Shift-Space>	Select the range from anchor to cursor.
#		<Control-Space>	Toggle the line at cursor.
#
#		<Ctrl-a>    	Select all lines.
#
#		<Page-Up>	
#		<Page-Down>	
#		<Home>		
#		<End>		What they say...
#
#		<<Copy>>	Copies the highlighted text to the
#				Clipboard.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: selection.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

if {[package vcompare 8.3 [package present Tk]] < 0} {
    # Added to allow usage of code by an 8.4 core.
    ::tk::unsupported::ExposePrivateVariable tkPriv
    ::tk::unsupported::ExposePrivateCommand  tkCancelRepeat
}

namespace eval sel {
    # When selecting a range of lines, the range is computed to be 
    # between the anchor and the selectCursor.  Any selection 
    # (other than selectLineRange) will set the anchor at the 
    # current position.  When selectLineRange is called, if there
    # is no value for anchor, the selectCursor becomes the anchor.
    #
    # The variable selectAnchor is an array that stores the anchor
    # based on the name of the text item.

    variable selectAnchor

    # The selectCursor is a cursor the can move around the text 
    # widget without selecting or unselecting lines.  It is used
    # to do selection with key strokes.
    #
    # The variable selectAnchor is an array that stores the anchor
    # based on the name of the text item.

    variable selectCursor

    # The selectStart array indicates where the <1> was pressed.
    # This is used when <ButtonRelease-1> is fired to verify
    # that the line is actually supposed top be selected.

    variable selectStart

    # The selectPreserve stores selection data; lines selected,
    # cursor position and anchor position, so it can be 
    # restored at a later date.
    
    variable selectPreserve

    # After every selection event has fired, a check is done
    # to see if a command has been defined for the text widget.
    # If a command exists, then it is run immediately after
    # the selection event.  This array is the table that stores
    # the command for each text widget.

    variable widgetCmd

    # scrollText --
    #	Add this tag to a text widget so the widget will scroll 
    #	on B1-Leave events and stop scrolling when B1 is released
    # 	or re-enters the text widget.

    bind scrollText <B1-Leave> {
	set tkPriv(x) %x
	set tkPriv(y) %y
	sel::tkTextAutoScan %W
    }
    bind scrollText <B1-Enter> {
	tkCancelRepeat
    }
    bind scrollText <ButtonRelease-1> {
	tkCancelRepeat
    }

    # selectFocus --
    # Add this tag to a text widget so the highlighted region
    # will become raised when the text widget is in focus and
    # flattens when the text widget looses focus.

    bind selectFocus <FocusIn> {
	sel::changeFocus %W in
    }
    bind selectFocus <FocusOut> {
	sel::changeFocus %W out
    }

    # selectCopy --
    # Add this tag to any window that where you would like 
    # to copy the highlighted text to the Clipboard.

    bind selectCopy <<Copy>> {
	sel::copy %W
    }

    # selectLine --
    #	Add this tag to a text widget so the widget will allow
    # 	one line at a time to be selected.  All of the mouse
    # 	and keyboard events are defined according to Windows
    #	default operations.

    bind selectLine <1> {
	sel::setAnchor %W [lindex [split [%W index current] .] 0]
	set sel::selectStart(%W) @0,%y
	break
    }
    bind selectLine <ButtonRelease-1> {
	if {[info exists sel::selectStart(%W)]} {
	    if {[%W index @0,%y] == [%W index $sel::selectStart(%W)]} {
		sel::selectLine %W current
	    }
	    unset sel::selectStart(%W)
	}
	break
    }
    bind selectLine <Key-Up> {
	sel::moveSelection %W -1
	break
    }
    bind selectLine <Key-Down> {
	sel::moveSelection %W  1
	break
    }
    bind selectLine <Prior> {
	sel::selectLine %W [sel::scrollPages %W -1]
	break
    }
    bind selectLine <Next> {
	sel::selectLine %W [sel::scrollPages %W 1]
	break
    }
    bind selectLine <Home> {
	sel::selectLine %W 1.0
	break
    }
    bind selectLine <End> {
	sel::selectLine %W "end - 1 lines"
	break
    }

    # Create these bindings as no-ops, so the event can propagate
    # to other bindtags.  Otherwise the developer will have to order
    # the bindtags correctly so that modified events propagate 
    # correctly.

    bind selectLine <B1-Motion> {
    }
    bind selectLine <Double-1> {
    }
    bind selectLine <Shift-1> {
    }
    bind selectLine <Shift-Key-Up> {
    }
    bind selectLine <Shift-Key-Down> {
    }
    bind selectLine <Shift-Prior> {
    }
    bind selectLine <Shift-Next> {
    }
    bind selectLine <Shift-Home> {
    }
    bind selectLine <Shift-End> {
    }
    bind selectLine <Key-space> {
    }
    bind selectLine <Control-ButtonRelease-1> {
    }
    bind selectLine <Control-Key-space> {
    }
    bind selectLine <Shift-Key-space> {
    }    
    bind selectLine <Control-Key-Up> {
    }
    bind selectLine <Control-Key-Down> {
    }
    bind selectLine <Control-Prior> {
    }
    bind selectLine <Control-Next> {
    }
    bind selectLine <Control-Home> {
    }
    bind selectLine <Control-End> {
    }
    
    # selectRange --
    #	Add this tag to a text widget so the widget will allow
    # 	a region of text to be at one time.  All of the mouse
    # 	and keyboard events are defined according to Windows
    #	default opreations.

    bind selectRange <B1-Motion> {
	sel::selectLineRange %W @0,%y
	break
    }
    bind selectRange <Shift-1> {
	sel::selectLineRange %W current
	break
    }
    bind selectRange <Shift-Key-Up> {
	sel::moveSelectionRange %W -1
	break
    }
    bind selectRange <Shift-Key-Down> {
	sel::moveSelectionRange %W  1
	break
    }
    bind selectRange <Shift-Prior> {
	sel::selectLineRange %W [sel::scrollPages %W -1]
	break
    }
    bind selectRange <Shift-Next> {
	sel::selectLineRange %W [sel::scrollPages %W 1]
	break
    }
    bind selectRange <Shift-Home> {
	sel::selectLineRange %W 1.0
	break
    }
    bind selectRange <Shift-End> {
	sel::selectLineRange %W "end - 1 lines"
	break
    }
    bind selectRange <Shift-Double-1> {
	break
    }
    bind selectRange <Shift-B1-Motion> {
	break
    }

    # moveCursor --
    #	Add this tag to a text widget so the widget will allow
    # 	the selection cursor to move apart from the current 
    # 	selection.  This is usually used in conjunction with
    # 	selecting ranges.  All  of the mouse and keyboard events
    #	are defined according to Windows default opreations.

    bind moveCursor <Control-ButtonRelease-1> {
	sel::selectMultiLine %W current
	break
    }
    bind moveCursor <Control-Key-Up> {
	sel::moveCursor %W -1
	break
    }
    bind moveCursor <Control-Key-Down> {
	sel::moveCursor %W  1
	break
    }
    bind moveCursor <Control-Prior> {
	sel::moveCursorToIndex %W [sel::scrollPages %W -1]
	break
    }
    bind moveCursor <Control-Next> {
	sel::moveCursorToIndex %W [sel::scrollPages %W 1]
	break
    }
    bind moveCursor <Control-Home> {
	sel::moveCursorToIndex %W 1.0
	break
    }
    bind moveCursor <Control-End> {
	sel::moveCursorToIndex %W "end - 1 lines"
	break
    }
    bind moveCursor <Control-Key-space> {
	sel::toggleCursor %W
	break
    }
    bind moveCursor <Shift-Key-space> {
	sel::selectCursorRange %W
	break
    }    
    bind moveCursor <Key-space> {
	sel::selectCursor %W
	break
    }
    if 0 {
    bind watchBind <Control-Double-1> {
	break
    }
    bind watchBind <Control-B1-Motion> {
	break
    }
    }
}

# sel::setWidgetCmd --
#
#	Define the widget command for this widget.  The
#	command can be defined to fire on any selection
#	event or on specific events. (see below)
#
# Arguments:
#	w	The widget recieving the selection event.
#	type	The type of event that occured. 
#		  line   A line was selected
#		  multi  Multiple lines were selected.
#		  range  A discontinous range of text was selected.
#		  all    Any of the above events.
#	cmd	The command to fire when a selection event occurs.
#	seeCmd	The command to fire whenever "see" is called.
#
# Results:
#	None.

proc sel::setWidgetCmd {w type cmd {seeCmd {}}} {
    variable widgetCmd

    set widgetCmd($w,$type) $cmd
    if {$seeCmd != {}} {
	set widgetCmd($w,see) $seeCmd
    }
}

# sel::widgetCmd --
#
#	Execute the command, if it exists, that is bound
#	to the widget.  This command is executed after
#	any selection event.  
#
# Arguments:
#	w	The widget recieving the selection event.
#	type	The type of event that occured. 
#		  line   A line was selected
#		  multi  Multiple lines were selected.
#		  range  A discontinous range of text was selected.
#		  all    Any of the above events.
#
# Results:
#	The value of the evaled command.

proc sel::widgetCmd {w type} {
    variable widgetCmd

    if {[info exists widgetCmd($w,all)]} {
	uplevel #0 $widgetCmd($w,all)
    } elseif {[info exists widgetCmd($w,$type)]} {
	uplevel #0 $widgetCmd($w,$type)
    }
}

# sel::widgetSeeCmd --
#
#	Execute the command, if it exists, that is bound
#	to the widget.  This command is executed after
#	any "see" event.  
#	
#
# Arguments:
#	w	The widget recieving the selection event.
#	i	Theindex to see.
#
# Results:
#	None.

proc sel::widgetSeeCmd {w i} {
    variable widgetCmd

    if {[info exists widgetCmd($w,see)]} {
	uplevel #0 [eval [concat $widgetCmd($w,see) $i]]
    } else {
	$w see $i
    }
    return
}

# sel::changeFocus --
#
#	Change the graphical feedback when focus changes.
#
# Arguments:
# 	text	The text widget getting or loosing focus.
#	focus	The type of focus change (in or out.)
#
# Results:
#	None.

proc sel::changeFocus {text focus} {
    $text tag remove focusIn 1.0 end
    if {$focus == "in"} {
	sel::updateCursor $text
    }
}

# sel::selectAllLines --
#
#	Select all of the lines in the text window.
#
# Arguments:
#	text 	The text widget to select.
#
# Results:
#	None.

proc sel::selectAllLines {text} {
    $text tag add highlight 0.0 "end - 1 lines"
    set sel::selectAnchor($text) 1
    set sel::selectCursor($text) 1
    sel::updateCursor $text
}

# sel::selectLine --
#
#	Select a new line in the text widget, and  
#	remove all of the previously highlights.
#
# Arguments:
#	text	The text widget where the select request occured.
#	index	The index to select.
#
# Results:
#	None.

proc sel::selectLine {text index} {
    if {![sel::indexPastEnd $text $index]} {
	set newLine [lindex [split [$text index $index] .] 0]
	sel::line $text $newLine
	sel::updateCursor $text
    }
}

# sel::selectMultiLine --
#
#	Select or deselect a new line in the text window,
#	without removing existing highlights.
#
# Arguments:
#	text	The text widget where the select request occured.
#	index	The index to select.
#
# Results:
#	None.

proc sel::selectMultiLine {text index} {
    if {![sel::indexPastEnd $text $index]} {
	set newLine [lindex [split [$text index $index] .] 0]
	sel::multiLine $text $newLine
	sel::updateCursor $text
    }
}

# sel::selectLineRange --
#
#	Select a range of lines in the text widget.
#
# Arguments:
#	text		The text widget recieving the event.
#	index		The location of the event.
#
# Results:
#	None.

proc sel::selectLineRange {text index} {
    if {![sel::indexPastEnd $text $index]} {
	set newLine [lindex [split [$text index $index] .] 0]
	sel::lineRange $text $newLine
	sel::updateCursor $text
    }
}

# sel::moveSelection --
#
#	Move the selection of the text widget up or 
#	down, removing any previous selection.
#
# Arguments:
#	text		The text widget recieving the selection.
#	amount		The number of lines to move from the current
#			selectCursor position.
#
# Results:
#	None.

proc sel::moveSelection {text amount} {
    if {[info exists sel::selectCursor($text)]} {
	set newLine [expr {$sel::selectCursor($text) + $amount}]
    } else {
	set newLine $amount
    }

    # Adjust the newLine so the line numbers are 
    # between the ranges of the text window.
    if {$newLine < 1} {
	set newLine 1
    }
    set end [expr {[lindex [split [$text index end] .] 0] - 1}]
    if {$newLine > $end} {
	set newLine $end
    }

    sel::line $text $newLine
    sel::updateCursor $text
}

# sel::moveSelectionRange --
#
#	Move the range of the current selection.
#
# Arguments:
#	text		The text widget recieving the selection.
#	amount		The number of lines to select from the current
#			selectCursor position.
#
# Results:
#	None.

proc sel::moveSelectionRange {text amount} {
    if {[info exists sel::selectCursor($text)]} {
	set newLine [expr {$sel::selectCursor($text) + $amount}]
    } else {
	set newLine $amount
    }    

    # Adjust the newLine so the line numbers are 
    # between the ranges of the text window.
    if {$newLine < 1} {
	set newLine 1
    }
    set end [expr {[lindex [split [$text index end] .] 0] - 1}]
    if {$newLine > $end} {
	set newLine $end
    }

    sel::lineRange $text $newLine
    sel::updateCursor $text
}

# sel::moveCursor --
#
#	Move the selectCursor without selecting new lines.
#
# Arguments:
#	text		The text widget containing the selectCursor.
#	amount		The number of lines to move from the current
#			selectCursor position.
#
# Results:
#	None.

proc sel::moveCursor {text amount} {
    if {[info exists sel::selectCursor($text)]} {
	set newCursor [expr {$sel::selectCursor($text) + $amount}]
    } else {
	set newCursor $amount
    }
    
    sel::setCursor $text $newCursor
    sel::updateCursor $text
}

# sel::moveCursorToIndex --
#
#	Move the selectCursor without selecting new lines.
#
# Arguments:
#	text		The text widget containing the selectCursor.
#	index		The index of the new selectCursor.
#
# Results:
#	None.

proc sel::moveCursorToIndex {text index} {
    set line [expr {[lindex [split [$text index $index] .] 0] - 1}]
    sel::setCursor $text $line
    sel::updateCursor $text
}

# sel::selectCursorRange --
#
#	Select all of the lines between the selectAnchor and
#	selectCursor.
#
# Arguments:
#	text		The text widget recieving the selection.
#
# Results:
#	None.

proc sel::selectCursorRange {text} {
    if {[info exists sel::selectCursor($text)]} {
	set newLine $sel::selectCursor($text)
    } else {
	set newLine 0
    }    
    sel::lineRange $text $newLine
    sel::updateCursor $text
}

# sel::selectCursor --
#
#	Select the line indicated by the selectCursor without
#	deleting the previous selection.
#
# Arguments:
#	text		The text widget recieving the selection.
#
# Results:
#	None.

proc sel::selectCursor {text} {
    if {[info exists sel::selectCursor($text)]} {
	set newLine $sel::selectCursor($text)
    } else {
	set newLine 1
    }

    # If the line isn't selected, then select it.  Otherwise
    # do nothing.
    if {![sel::isSelected $text $newLine]} {
	sel::multiLine $text $newLine
    }
}

# sel::toggleCursor --
#
#	Toggle the selection of the line indicated by the 
#	selectCursor without deleting the previous selection.
#
# Arguments:
#	text		The text widget recieving the selection.
#
# Results:
#	None.

proc sel::toggleCursor {text} {
    if {[info exists sel::selectCursor($text)]} {
	set newLine $sel::selectCursor($text)
    } else {
	set newLine 0
    }    
    sel::multiLine $text $newLine
}

# sel::updateCursor --
#
#	Display the new cursor position, removing the previous
#	cursor.
#
# Arguments:
#	text		The text widget recieving the selection.
#
# Results:
#	None.

proc sel::updateCursor {text} {
    if {![info exists sel::selectCursor($text)]} {
	set sel::selectCursor($text) 1
    }
    set start "$sel::selectCursor($text).0"
    set end   "$start lineend + 1c"

    $text tag remove focusIn 0.0 end
    $text tag add focusIn $start $end
    sel::widgetSeeCmd $text $start
}

# sel::line --
#
#	Select a new line in the text  Window, and  
#	remove all of the previously highlights.
#
# Arguments:
#	text	The text widget where the select request occured.
#	index	The index to select.
#
# Results:
#	None.

proc sel::line {text line} {
    sel::setAnchor $text $line
    sel::setCursor $text $line

    $text tag remove highlight 0.0 end
    $text tag add highlight $line.0 "$line.0 lineend + 1 chars"
    sel::widgetCmd $text line
}

# sel::multiLine --
#
#	Select or deselect a new line in the text window,
#	without removing existing highlights.
#
# Arguments:
#	text	The text widget where the select request occured.
#	index	The index to select.
#
# Results:
#	None.

proc sel::multiLine {text line} {
    sel::setAnchor $text $line
    sel::setCursor $text $line

    set start [$text index "$line.0"]
    set end   [$text index "$line.0 lineend + 1 chars"]
    if {[sel::isSelected $text $line]} {
	$text tag remove highlight $start $end
    } else { 
	$text tag add highlight $start $end
    }
    sel::widgetCmd $text multi
}

# sel::lineRange --
#
#	Select a range of lines.
#
# Arguments:
#	text		The text widget recieving the event.
#	index		The location of the event.
#
# Results:
#	None.

proc sel::lineRange {text line} {
    set lineList  [sel::getSelectedLines $text]
    if {$lineList == {}} {
	sel::line $text $line
	return
    }

    sel::setCursor $text $line
    set anchor [sel::getAnchor $text]
    if {$line < $anchor} {
	set start "$line.0"
	set end   "$anchor.0 lineend + 1 chars"
    } else {
	set start "$anchor.0"
	set end   "$line.0 lineend + 1 chars"
    }
    $text tag remove highlight 0.0 end
    $text tag add highlight $start $end
    sel::widgetCmd $text range
}

# sel::preserve --
#
#	Preserve the line selection data; lines selected,
#	cursor postion, and anchor position.  This proc
#	is useful when a text widget is updated by 
#	deleting all text and restoring it.
#
# Arguments:
#	text	The text widget to preserve.
#
# Results:
#	None.

proc sel::preserve {text} {
    variable selectPreserve

    set anchor [sel::getAnchor $text]
    set cursor [sel::getCursor $text]
    set lines  [sel::getSelectedLines $text]

    set selectPreserve($text) [list $anchor $cursor $lines]
}

# sel::restore --
#
#	Restore the previously preserved selection state
#	of a text widget.
#
# Arguments:
#	text	The text widget to restore.
#
# Results:
#	None.

proc sel::restore {text} {
    variable selectPreserve
    
    if {[info exists selectPreserve($text)]} {
	foreach line [lindex $selectPreserve($text) 2] {
	    sel::selectMultiLine $text $line.0
	}
	sel::setAnchor $text [lindex $selectPreserve($text) 0]
	sel::setCursor $text [lindex $selectPreserve($text) 1]
	unset selectPreserve($text)
    }
}

# sel::getSelectedLines --
#
#	Get a list of highlighted lines in the text window.
#
# Arguments:
#	None.
#
# Results:
#	A list of line number that specify which lines in the 
#	text window are highlighted.

proc sel::getSelectedLines {text} {
    set result {}
    set ranges [$text tag ranges highlight]
    foreach {start end} $ranges {
	for {set i [expr {int($start)}]} {$i < $end} {incr i} {
	    lappend result $i
	}
    }
    return $result
}

# sel::isSelected --
#
#	Determine if the current line is selected.
#
# Arguments:
#	text		The text widget recieving the event.
#	line		The line to check for selection.
#
# Results:
#	Boolean, true if the line is selected.

proc sel::isSelected {text line} {
    # We have to check the entire line because there can
    # be spacial cases where a specific index does not
    # have the highlight tag, but the line is selected.
    # (e.g., the Break Window's first few chars.)

    return [sel::isTagInLine $text $line.0 highlight]
}

# sel::getCursor --
#
#	Get the line number of the selectCursor for the text widget.
#
# Arguments:
#	text	The text widget to look for the selectCursor.
#
# Results:
#	The line number of the selectCursor.  If one doesn't exist
#	create one and set it to line# 1.

proc sel::getCursor {text} {
    if {![info exists sel::selectCursor($text)]} {
	set sel::selectCursor($text) 1
    }
	
    return $sel::selectCursor($text)
}

# sel::setCursor --
#
#	Set the line number of the current cursor.
#
# Arguments:
#	text	The text widget assoc. with the cursor.
#	line	The line number of the new cursor.
#
# Results:
#	None.

proc sel::setCursor {text line} {
    if {$line < 1} {
	set line 1
    } elseif {$line > [lindex [split [$text index end] .] 0]} {
	set line $end
    }
    set sel::selectCursor($text) $line
}

# sel::getAnchor --
#
#	Get the line number of the anchor for the text widget.
#
# Arguments:
#	text	The text widget to look for the anchor.
#
# Results:
#	The line number of the anchor.  If one dosen't exist
#	create on and set it to line #1.

proc sel::getAnchor {text} {
    if {![info exists sel::selectAnchor($text)]} {
	set sel::selectAnchor($text) 1
    }
    return $sel::selectAnchor($text)
}

# sel::setAnchor --
#
#	Set the line number of the current anchor.
#
# Arguments:
#	text	The text widget assoc. with the anchor.
#	line	The line number of the new anchor.
#
# Results:
#	None.

proc sel::setAnchor {text line} {
    if {$line < 1} {
	set line 1
    } elseif {$line > [lindex [split [$text index end] .] 0]} {
	set line $end
    }
    set sel::selectAnchor($text) $line
}

# sel::isTagInLine --
#
#	Determine if a tag exists anywhere in the line.
#
# Arguments:
#	text 	The text widget to search.
#	index	The location of the line number.
#	tag 	The tag to look for,
#
# Results:
#	Boolean, true if the tag exists in the current line.

proc sel::isTagInLine {text index tag} {
    set index [$text index $index]
    set start "$index linestart"
    set end   "$index lineend + 1 chars"

    set result 0
    set range [lindex [$text tag nextrange $tag $start $end] 0]
    if {$range != {}} {
	# We did get a range for the tag in between the index.  See
	# if the line number of the range is identical to the line 
	# number of the index.

	set thisLine [lindex [split $index .] 0]
	set nextLine [lindex [split $range .] 0]
	if {$thisLine == $nextLine} {
	    set result 1
	}
    } else {
	# We did not get a range value.  It may be that the tag spans
	# several lines.  Find all of the ranges with tag before start.
	# If start is in the middle of any of these ranges, then it 
	# is selected.

	set range [$text tag prevrange $tag $start]
	foreach {s e} $range {
	    if {($index >= $s) && ($index < $e)} {
		set result 1
		break
	    }
	}
    }
    return $result
}

# sel::indexPastEnd --
#
#	Test top see if the index is past the end of the text.
#
# Arguments:
#	text	The text widget.
#	index 	The index to check.
#
# Results:
#	Boolean, true if the index is past the end of the text.

proc sel::indexPastEnd {text index} {
    return [$text compare [$text index $index] >= "end"]
}

# sel::copy --
#
#	Copy the highlighted text to the Clipboard.
#
# Arguments:
#	text	The text widget getting the copy request.
#
# Results:
#	Returns a list of the lines of text copied to 
#	the clipboard.

proc sel::copy {text} {
    set result {}
    foreach {start end} [$text tag ranges highlight] {
	# Test to see if the range spans multiple lines.
	# If it does, lappend each line to the list, one
	# at a time.

	set startLine [$text index "$start linestart"]
	set endLine   [$text index "$end   linestart"]
	if {[$text compare $startLine != $endLine]} {
	    for {set i $startLine} {$i < $endLine} {set i [expr {$i + 1}]} {
		lappend result [$text get $i "$i lineend + 1c"]
	    }
	} else {
	    lappend result [$text get $start $end]
	}
    }
    if {$result != {}} {
    	clipboard clear -displayof $text
	clipboard append -displayof $text [join $result {}]
    }
    return $result
}

# sel::scrollPages --
# 	This is a utility procedure used in bindings for moving up 
#	and down pages and possibly extending the selection along 
#	the way.  It scrolls the view in the widget by the number 
#	of pages, and it returns the index of the character that 
#	is at the same position in the new view as the insertion 
#	cursor used to be in the old view.
#
# Arguments:
# 	w 	The text window in which the cursor is to move.
# 	count 	Number of pages forward to scroll;  may be negative
#		to scroll backwards.
#
# Results:
#	The index on the next "page"

proc sel::scrollPages {w count} {
    set bbox [$w bbox [sel::getCursor $w].0]
    $w yview scroll $count pages
    if {$bbox == ""} {
	return [$w index @[expr {[winfo height $w]/2}],0]
    }
    return [$w index @[lindex $bbox 0],[lindex $bbox 1]]
}


# sel::tkTextAutoScan --
#	This procedure is invoked when the mouse leaves a text window
# 	with button 1 down.  It scrolls the window up, down, left, or right,
# 	depending on where the mouse is (this information was saved in
# 	tkPriv(x) and tkPriv(y)), and reschedules itself as an "after"
# 	command so that the window continues to scroll until the mouse
# 	moves back into the window or the mouse button is released.
#
# Arguments:
# 	w 	The text window.
#
# Results:
#	None.

proc sel::tkTextAutoScan {w} {
    global tkPriv
    if {![winfo exists $w]} return
    if {$tkPriv(y) >= [winfo height $w]} {
	$w yview scroll 2 units
    } elseif {$tkPriv(y) < 0} {
	$w yview scroll -2 units
    } elseif {$tkPriv(x) >= [winfo width $w]} {
	$w xview scroll 2 units
    } elseif {$tkPriv(x) < 0} {
	$w xview scroll -2 units
    } else {
	return
    }
    set tkPriv(afterId) [after 50 sel::tkTextAutoScan $w]
}

