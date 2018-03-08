# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# result.tcl --
#
#	This file implements the command result window.
#
# Copyright (c) 1998-2000 Ajuba Solutions

# 
# RCS: @(#) $Id: result.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

package require fmttext

namespace eval result {
    variable text  {}
    variable frame {}
}

# result::createWindow --
#
#	Create the window for displaying command results inside the specified
#	master. 
#
# Arguments:
#	mainDbgWin	The toplevel window for the main debugger.
#
# Results:
#	The handle to the frame that contains the result window.

proc result::createWindow {mainDbgWin} {
    variable text
    variable frame

    set frame [ttk::frame $mainDbgWin.frame]
    set text [text $frame.text -width 1 -height 1 -bd 1]
    grid $text -row 0 -column 1 -sticky we -pady 2
    grid columnconfigure $frame 1 -weight 1

    # Add a little extra space below the text widget so it looks right with the
    # status bar in place.

    bind $text <Configure> {
 	fmttext::formatText $result::text right
    }

    # Set the behavior so we get the standard truncation behavior
    fmttext::setDbgTextBindings $text

    # Add a double-click binding to take us to the data display window
    bind $text <Double-1> {maingui showResult}

    return $frame
}

proc result::updateWindow {dbg} {
    variable text
    if {[winfo exists $result::frame] \
	    && [winfo ismapped $result::frame]} {
	resetWindow

	set result [$dbg getResult [font::get -maxchars]]
	set code [lindex $result 0]

	set codes {OK ERROR RETURN BREAK CONTINUE}

	if {$code < [llength $codes]} {
	    set code [lindex $codes $code]
	}
	set result [code::mangle [lindex $result 1]]

	$text insert 1.0 "Code: $code\tResult: $result"
	fmttext::formatText $text right
    }
    return
}

proc result::resetWindow {} {
    variable text

    fmttext::unsetFormatData $text
    $text delete 0.0 end
    return
}
