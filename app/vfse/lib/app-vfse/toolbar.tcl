# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#

package require tooltip
package require image ; image::file::here

proc MakeToolbar {tbar} {
    set column 0	;# which column

    # -image save.gif -width 16 -height 16

    # back/forward buttons
    set w $tbar.back
    ttk::button $w -style Toolbutton -image [image::get back] \
	-takefocus 0 -state disabled -command action::back
    grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 0 -padx 0
    tooltip::tooltip $w "Back"

    set w $tbar.fore
    ttk::button $w -style Toolbutton -image [image::get forward] \
	-takefocus 0 -state disabled -command action::forward
    grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 0 -padx 0
    tooltip::tooltip $w "Forward"

    # up folder
    set w $tbar.up
    ttk::button $w -style Toolbutton -image [image::get folder-up] \
	-takefocus 0 -state disabled -command action::upward
    grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 0 -padx 0
    tooltip::tooltip $w "Up Folder"

    # separator
    set w [ttk::separator $tbar.sep$column -orient vertical]
    grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 2 -padx 3

    # search / folder / history display
    # normally this is a radiobutton to display one of s/f/h,
    # but we only have a folder view for now - so it's a checkbutton.
    set ::W(disp) folders

    set w $tbar.folders
    ttk::checkbutton $w -style Toolbutton -text "Folders" \
	-compound left -image [image::get directories] \
	-variable W(disp) -onvalue folders -offvalue "" \
	-takefocus 0 -command action::setViewPane
    grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 0
    tooltip::tooltip $w "View Folders"

    if 0 {
	set w $tbar.search
	radiobutton $w -text "Search" -variable W(disp) -value search \
	    -takefocus 0 -bd 1 -highlightthickness 0 \
	    -command action::setViewPane \
	    -offrelief flat -overrelief raised -indicatoron 0 \
	    -state disabled
	grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 0
	tooltip::tooltip $w "Search in Folders"

	set w $tbar.history
	radiobutton $w -text "History" -variable W(disp) -value history \
	    -takefocus 0 -bd 1 -highlightthickness 0  \
	    -command action::setViewPane \
	    -offrelief flat -overrelief raised -indicatoron 0 \
	    -state disabled
	grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 0
	tooltip::tooltip $w "Folder History"
    }

    if 0 {
	# separator
	set w [ttk::separator $tbar.sep$column -orient vertical]
	grid $w -in $tbar -row 0 -column [incr column] \
	    -sticky ns -pady 2 -padx 3

	# move to / copy to folder

	# delete
	set w $tbar.delete
	button $w -image [image::get delete] -width 18 -height 18  \
	    -takefocus 0 -state disabled -bd 1 \
	    -command action::delete -relief flat -overrelief raised
	grid $w -in $tbar -row 0 -column [incr column] \
	    -sticky ns -pady 0 -padx 0
	tooltip::tooltip $w "Delete"
    }

    # refresh
    set w $tbar.refresh
    ttk::button $w -style Toolbutton -image [image::get refresh] \
	-takefocus 0 -command action::refresh
    grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 0 -padx 0
    tooltip::tooltip $w "Refresh"


    # separator
    set w [ttk::separator $tbar.sep$column -orient vertical]
    grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 2 -padx 3

    # list display type
    set w $tbar.type
    ttk::button $w -style Toolbutton -image [image::get folder-type] \
	-takefocus 0 -state disabled -command action::showproperties
    grid $w -in $tbar -row 0 -column [incr column] -sticky ns -pady 0 -padx 0
    tooltip::tooltip $w "File Properties"

    # setup the "divider", the blank space between the property tools, and
    # the command tools that may take user-defined buttons.
    set w [ttk::frame $tbar.hold]
    grid $w -in $tbar -row 0 -column [incr column] -sticky w

    grid columnconfigure $tbar $column -weight 1
}
