# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# fmttext.tcl --
#
#	Text widget manipulations independent of gui objects.
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: debugger.tcl.in,v 1.25 2001/02/09 07:52:48 welch Exp $

namespace eval ::fmttext {
    # textwidgets		A list of registered text widgets.  When
    #				the a dbg text is updated via the prefs
    #				window, we need to get a list of widgets
    #				that are using the same bindings.

    variable textwidgets {}

    # Array that holds the text that has been stripped for each
    # window.

    variable  format
    array set format {}
}


#-----------------------------------------------------------------------------
# Default setting and helper routines.
#-----------------------------------------------------------------------------

# proc fmttext::setDbgTextBindings --
#
#	There are common bindings in debugger text windows that
# 	should shared between the code window, stack window, var
#	window etc.  These are:
#		1) Set the state to disabled -- readonly.
#		2) Specify the font to override any global settings
#		3) Set the wrap option to none.
#
# Arguments:
#	w	A text widget.
#	sb	If not null, then this is a scrollbar that needs
#		to be attached to the text widget.
#
# Results:
#	None.

proc fmttext::setDbgTextBindings {w {sb {}}} {
    variable textwidgets

    # Add to the list of registered text widgets.
    lappend textwidgets $w

    #
    # Configure the text widget to have common default settings.
    #

    # All text widgets share the same configuration for wrapping,
    # font displayed and padding .

    $w configure -wrap none -padx 4 -pady 1 \
	    -font dbgFixedFont  -highlightthickness 0 \
	    -insertwidth 0 -cursor [system::getArrow]

    # If there is a value for a scrollbar, set the yscroll callback
    # to display the scrollbar only when needed.

    if {$sb != {}} {
	$w configure -yscrollcommand [list fmttext::scrollDbgText $w $sb \
		[list place $sb -in $w -anchor ne -relx 1.0 -rely 0.0 \
		-relheight 1.0]]
	$sb configure -cursor [system::getArrow]
    }
    bind::removeBindTag $w Text

    #
    # Tag Attributes.
    #

    # Define the look for a region of disabled text.
    # Set off array names in the var window.
    # Define what highlighted lext looks like (e.g. indicating the
    # current stack level)

    $w tag configure disable -bg gray12 -borderwidth 0 -bgstipple gray12
    $w tag configure handle -foreground blue
    $w tag configure message -font $font::metrics(-fontItalic)
    $w tag configure left -justify right
    $w tag configure center -justify center
    $w tag configure right -justify right
    $w tag configure leftIndent -lmargin1 4 -lmargin2 4
    $w tag configure underline -underline on
    $w tag configure focusIn -relief solid -borderwidth 1
    $w tag configure highlight -background grey ; # [pref::prefGet highlight]
    $w tag configure highlight_error -background \
	    [pref::prefGet highlight_error]
    $w tag configure highlight_cmdresult -background \
	    [pref::prefGet highlight_cmdresult]

    # Define the status window messages.

    $w tag bind stackLevel <Enter> {maingui setStatusMsg "Stack level as used by upvar."}
    $w tag bind stackType  <Enter> {maingui setStatusMsg "Scope of the stack frame."}
    $w tag bind stackProc  <Enter> {maingui setStatusMsg "Name of the procedure called."}
    $w tag bind stackArg   <Enter> {maingui setStatusMsg "Argument passed to the procedure of this stack."}
    $w tag bind varName    <Enter> {maingui setStatusMsg "The name of the variable"}
    $w tag bind varValu    <Enter> {maingui setStatusMsg "The value of the variable."}
    return
}

# proc fmttext::scrollDbgText --
#
#	Scrollbar command that displays the vertical scrollbar if it
#	is needed and removes it if there is nothing to to scroll.
#
# Arguments:
#	scrollbar	The scrollbar widget.
#	geoCmd		The command used to re-manage the scrollbar.
#	offset		Beginning location of scrollbar slider.
#	size		Size of the scrollbar slider.
#
# Results:
#	None.

proc fmttext::scrollDbgText {text scrollbar geoCmd offset size} {
    if {$offset == 0.0 && $size == 1.0} {
	set manager [lindex $geoCmd 0]
	$manager forget $scrollbar
    } else {
	# HACK: Try to minimize the occurance of an infinite
	# loop by counting the number of lines in the text
	# widget.  I am assuming that a scrollbar need at least
	# three lines of text in the text window otherwise it is
	# too big.  This will NOT work on all systems.

	# TODO: This hack needs to be cleaned up!!! - ray

	set line [expr {[lindex [split [$text index end] .] 0] - 1}]
	if {$line == 1} {
	    return
	} elseif {($line > 1) && ($line < 4)} {
	    set script [$text cget -yscrollcommand]
	    $text configure -yscrollcommand {}
	    $text configure -height $line
	    after 100 "catch {$text configure -yscrollcommand \[list $script\]}"
	    return
	}
	if {![winfo ismapped $scrollbar]} {
	    eval $geoCmd
	}
	$scrollbar set $offset $size
    }
    return
}

# proc fmttext::scrollDbgTextX --
#
#	Scrollbar command that displays the horizontal scrollbar if
#	it is needed.
#
# Arguments:
#	scrollbar	The scrollbar widget.
#	geoCmd		The command used to re-manage the scrollbar.
#	offset		Beginning location of scrollbar slider.
#	size		Size of the scrollbar slider.
#
# Results:
#	None.

proc fmttext::scrollDbgTextX {scrollbar geoCmd offset size} {

    if {$offset != 0.0 || $size != 1.0} {
	eval $geoCmd
    }
    $scrollbar set $offset $size
    return
}

#-----------------------------------------------------------------------------
# APIs for formatting text and adding elipses.
#-----------------------------------------------------------------------------

# proc fmttext::getDbgText --
#
#	Get a list of registered text widgets.  Whenever a text
#	widget uses the setDbgTextBindings proc, that
#	widget becomes registered.  Whenever the prefs updates
#	the configuration, all registered text widgets are
#	updated.
#
# Arguments:
#	None.
#
# Results:
#	Return a list of registered text widgets.  When windows
#	are destroied they are not removed from this list, so it
#	is still necessary to check for window existence.

proc fmttext::getDbgText {} {
    variable textwidgets
    return  $textwidgets
}

# proc fmttext::updateDbgText --
#
#	Update all of the registered Dbg text widgets to
#	a current preferences.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc fmttext::updateDbgText {} {

    # Update the font family used by all dbg text widgets.

    font::configure [pref::prefGet fontType] [pref::prefGet fontSize]

    # Foreach formatted text widget, redo the formatting so it
    # is consistent with any new preferences.

    foreach {win side} [getFormattedTextWidgets] {
	if {[winfo exists $win]} {
	    formatText $win $side
	}
    }
    return
}

# proc fmttext::updateTextHighlights --
#
#	Update all of the registered Dbg text widgets to
#	a current highlight preferences.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc fmttext::updateDbgHighlights {} {
    # Reset the tag configurations for all dbg text widgets.

    foreach win [getDbgText] {
	if {[winfo exists $win]} {
	    $win tag configure highlight \
		    -background [pref::prefGet highlight]
	    $win tag configure highlight_error \
		    -background [pref::prefGet highlight_error]
	    $win tag configure highlight_cmdresult \
		    -background [pref::prefGet highlight_cmdresult]
	}
    }
    return
}

# proc fmttext::formatText --
#
#	This command will trim, if nexessary, the display of every
#	viewable line in the text widget and append an elipse to
#	provide feedback that the line was trimmed.
#
#	Any highlighting on strings that are formatted will be
#	destroyed.  The caller of this function must maintain
#	their own highlighting.
#
# Arguments:
#	text	The text widget to format.
#	side	The side to place the elipse if necessary (left or right.)
#
# Results:
#	None.

proc fmttext::formatText {text side} {
    variable format

    # Restore the text to it previous glory.  The tear it apart
    # all over again.  Do this because it makes it easier to
    # restore text that might have previously been formatted.

    unformatText $text

    if {$side == "left"} {
	$text xview moveto 1
    }

    # Get a list of all the viewable lines and cache the
    # index as well as the result of calling dlineinfo.

    set end [$text index end]
    set viewable {}
    for {set i 1} {$i < $end} {incr i} {
	if {[set info [$text dlineinfo $i.0]] != {}} {
	    lappend viewable [list $i.0 $info]
	}
    }

    foreach view $viewable {
	set index [lindex $view 0]
	set info  [lindex $view 1]
	set delta 0
	switch $side {
	    right {
		set textWidth [winfo width $text]
		set lineWidth [expr {[lindex $info 2] + \
			(2 * [$text cget -padx]) + 4}]
		if {$lineWidth > $textWidth} {
		    # If the trimStart is < the linestart then the
		    # viewable region is less then three chars.  Set
		    # the trimStart to the beginning of the line.

		    set y [expr {[lindex $info 1] + 4}]
		    set trimStart [$text index "@$textWidth,$y - 3c"]
		    if {[$text compare $trimStart < "$index linestart"]} {
			set trimStart "$index linestart"
		    }
		    set trimEnd     [$text index "$index lineend"]
		    set trimIndex   $trimStart
		    set elipseStart $trimStart
		    set elipseEnd   [$text index "$trimStart + 3c"]

		    set delta 1
		}
	    }
	    left {
		if {[lindex $info 0] < 0} {
		    set x [lindex $info 0]
		    set y [expr {[lindex $info 1] + 4}]
		    set trimStart   [$text index "$index linestart"]
		    set trimEnd     [$text index "@$x,$y + 3c"]
		    set trimIndex   $trimEnd
		    set elipseStart [$text index "$index linestart"]
		    set elipseEnd   [$text index "$elipseStart + 3c"]

		    set delta 1
		}
	    }
	    default {
		error "unknown format side \"$side\""
	    }
	}
	if {$delta} {
	    # Extract the text that we are about to delete and
	    # cache it so it can be restored later.

	    set str  [$text get $trimStart $trimEnd]
	    set tags [$text tag names $trimIndex]

	    $text delete $trimStart $trimEnd
	    $text insert $elipseStart "..." $tags
	    set format($text,$index) [list $trimStart $trimEnd \
		    $elipseStart $elipseEnd $trimIndex $side $str]
	    unset str tags
	}
    }
}

# proc fmttext::unformatText --
#
# 	Restore any previously trimmed strings to their
# 	original value.  This is necessary when the
# 	viewable region changes (scrolling) and we do not
# 	have line info for lines out of the viewavle region.
#
# Arguments:
#	text	The text widget to format.
#
# Results:
#	None.

proc fmttext::unformatText {text} {
    variable format

    foreach name [array names format $text,*] {
	set trimStart   [lindex $format($name) 0]
	set trimEnd     [lindex $format($name) 1]
	set elipseStart [lindex $format($name) 2]
	set elipseEnd   [lindex $format($name) 3]
	set trimIndex   [lindex $format($name) 4]
	set side        [lindex $format($name) 5]
	set str         [lindex $format($name) 6]

	set tags [$text tag names $trimIndex]
	$text delete $elipseStart $elipseEnd
	$text insert $elipseStart $str $tags
	unset format($name)
    }
}

# proc fmttext::unsetFormatData --
#
#	Delete all format data.  This proc should be called
#	prior to the contents of a text widget being deleted.
#
# Arguments:
#	text	The formatted text widget.
#
# Results:
#	None.

proc fmttext::unsetFormatData {text} {
    variable format

    foreach name [array names format $text,*] {
	unset format($name)
    }
}

# proc fmttext::getUnformatted --
#
#	Return the unformatted line at index.
#
# Arguments:
#	text	The formatted text widget.
#	index	The line to unformat and return.
#
# Results:
#	A string representing the unformatted line.

proc fmttext::getUnformatted {text index} {
    variable format

    if {[info exists format($text,$index)]} {
	set side      [lindex $format($text,$index) 5]
	set str       [lindex $format($text,$index) 6]
	switch $side {
	    right {
		set trimStart [lindex $format($text,$index) 0]
		set prefix [$text get "$index linestart" $trimStart]
		set result $prefix$str
	    }
	    left {
		set elipseEnd [lindex $format($text,$index) 3]
		set suffix [$text get $elipseEnd "$index lineend"]
		set result $str$suffix
	    }
	    default {
		error "unknown side \"$side\""
	    }
	}
    } else {
	set result [$text get "$index linestart" "$index lineend"]
    }
    return $result
}

# proc fmttext::getFormattedTextWidgets --
#
#	Get a list of the current text widgets that have formatting.
#
# Arguments:
#	None.
#
# Results:
#	Returns a list of formatetd text widgets and the side
#	they are formatted on.

proc fmttext::getFormattedTextWidgets {} {
    variable format

    # The array name is composed of <windowName>,<index>.
    # Strip off the index and use only the window name.
    # Set the value of the entry to the side the text
    # widget was formatted on.

    foreach name [array names format] {
	set win([lindex [split $name ","] 0]) [lindex $format($name) 5]
    }
    return [array get win]
}

package provide fmttext 1.0
