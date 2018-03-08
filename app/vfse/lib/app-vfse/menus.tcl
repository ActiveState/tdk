# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# menus.tcl --
#

package require projectInfo

proc MakeMenuBar {top} {
    global menu

    set m [menu [string trimright $top .].mbar -tearoff 0]

    # Special .apple menu must be FIRST.
    if {[tk windowingsystem] eq "aqua"} {
	# Apple Menu - Help
	set ma [menu $m.apple -tearoff 0]
	$m add cascade -label "&TDK" -menu $ma -underline 0
	$ma add command -label "About $::projectInfo::productName" \
	    -command action::about -underline 0
    }

    ## FILE menu
    ##
    set m2 [menu $m.file -tearoff 0]
    $m add cascade -label "File" -menu $m2 -underline 0

    ## set m3 [menu $m2.new -tearoff 0]
    ## $m2 add cascade -label "New" -menu $m3 -underline 2
    ## $m2 add separator
    ## $m2 add command -label "Create Shortcut" -state disabled                         -underline 7
    ## $m2 add command -label "Delete"          -state disabled -command action::delete -underline 0
    ## $m2 add command -label "Rename"          -state disabled -command action::rename -underline 5
    $m2 add command -label "Properties" -state disabled -command action::showproperties -underline 1

    if 0 {
	# Disabled Easter Egg / Debug helper
	if {$::tcl_platform(platform) ne "unix"} {
	    $m2 add separator
	    $m2 add command -label "Console" -underline 1 -command {
		if {[console eval {winfo ismapped .}]} {
		    console hide
		} else {
		    console show
		}
	    }
	}
    }

    if {[tk windowingsystem] ne "aqua"} {
	# Regular exit menu button, for non-aqua environments.

	$m2 add separator
	$m2 add command -label "Close" -command exit -underline 0
    } else {
	# Aqua - No exit, link ourselves into the system quit
	# entry.

	interp alias ""      ::tk::mac::Quit "" exit
	bind all <Command-q> ::tk::mac::Quit
    }

    set menu(file) $m2

    ## EDIT menu
    ##
    if 1 {
	set m2 [menu $m.edit -tearoff 0]
	$m add cascade -label "Edit" -menu $m2 -underline 0
	## $m2 add command -label "Cut"   -accel "Ctrl+X" -state disabled -underline 2
	$m2 add command -label "Copy"  -accel "Ctrl+C" -command action::copysel  -state disabled -underline 0
	$m2 add command -label "Paste" -accel "Ctrl+V" -command action::pastesel -state disabled -underline 0

	$m2 add separator
	$m2 add command -label "Copy to Folder..." -command action::copytofolder -state disabled -underline 8
	## $m2 add command -label "Move to Folder..." -state disabled -underline 2

	## $m2 add separator
	## $m2 add command -label "Select All"       -state disabled -underline 7
	## $m2 add command -label "Invert Selection" -state disabled -underline 0

	set menu(edit) $m2
    }

    ## VIEW menu
    ##
    set m2 [menu $m.view -tearoff 0]
    $m add cascade -label "View" -menu $m2 -underline 0

    set menu(view) $m2

    set ::STYLE details

    $m2 add radiobutton -variable ::STYLE -label "Large Icons" -value large \
	    -command {action::chgStyle large} -underline 3

    $m2 add radiobutton -variable ::STYLE -label "Small Icons" -value small \
	    -command {action::chgStyle small} -underline 1

    $m2 add radiobutton -variable ::STYLE -label "List"        -value list \
	    -command {action::chgStyle list} -underline 0

    $m2 add radiobutton -variable ::STYLE -label "Details"    -value details \
	    -command {action::chgStyle details} -underline 0
    ##
    ##    $m2 add radiobutton -variable ::STYLE -label "Thumbnails"
    ##	    -state disabled -underline 1

    $m2 add separator

    set m3 [menu $m2.arrange -tearoff 0]
    $m2 add cascade -label "Arrange Icons" -menu $m3 -underline 8
    $m3 add command -label "by Name" -command {.fsb sortby name} -underline 3
    $m3 add command -label "by Type" -command {.fsb sortby type} -underline 3
    $m3 add command -label "by Size" -command {.fsb sortby size} -underline 5
    $m3 add command -label "by Date" -command {.fsb sortby modified} -underline 3

    $m2 add separator

    set m3 [menu $m2.goto -tearoff 0]
    $m2 add cascade -label "Go To" -menu $m3 -underline 1
    set menu(view,goto) $m3

    $m3 add command -label "Back"         -command {action::back}    -underline 0
    $m3 add command -label "Forward"      -command {action::forward} -underline 0
    $m3 add command -label "Up One Level" -command {action::upward}  -underline 0

    $m2 add command -label "Refresh" -command action::refresh -underline 0

    if 0 {
	## FAVS menu
	##
	set m2 [menu $m.fav -tearoff 0]
	$m add cascade -label "Favorites" -menu $m2 -underline 1

	$m2 add command -label "Add to Favorites..."   -state disabled -underline 0
	$m2 add command -label "Organize Favorites..." -state disabled -underline 0
	$m2 add separator
    }

    ## TOOLS menu
    ##
    set m2 [menu $m.tools -tearoff 0]
    $m add cascade -label "Tools" -menu $m2 -underline 0

    $m2 add command -label "Mount Volumes"     -command action::mountvol -underline 6
    $m2 add command -label "Mount Selection"   -command action::mountsel -underline 6 -state disabled
    $m2 add command -label "Mount Archive ..." -command action::mountarchive -underline 7
    $m2 add separator
    $m2 add command -label "Unmount Selection" -command action::unmount -underline 0

    set menu(tools) $m2

    if 0 {
	$m2 add command -label "Map Network Drive..."        -state disabled -underline 4
	$m2 add command -label "Disconnect Network Drive..." -state disabled -underline 0
	$m2 add command -label "Synchronize..."              -state disabled -underline 0
	$m2 add separator
	$m2 add command -label "Folder Options..."           -state disabled -underline 7
    }

    ## HELP menu
    ##
    set m2 [menu $m.help -tearoff 0]
    $m add cascade -label "Help" -menu $m2 -underline 0

    if {[tk windowingsystem] ne "aqua"} {
	# Non-aqua, regular help setup

	$m2 add command -label "Help"  -command action::help -underline 0 \
	    -compound left -image [image::get help] -accelerator F1
	$m2 add separator			
	$m2 add command -label "About $::projectInfo::productName" \
	    -command action::about -underline 0

    } else {
	# Aqua. Split help in two. Regular help in the menu, splash in
	# the system menu. (The latter see top of the procedure body)

	# Link ourselves into the system Help menu entry.

	interp alias {} ::tk::mac::ShowHelp {} action::help
	bind all   <F1> ::tk::mac::ShowHelp

	#$m2 add command -label "Help" -command action::help -underline 0 -accelerator F1
    }

    bind $top <Key-F1> [list $m2 invoke Help]

    ## DEBUG menu
    ##
    #set m2 [menu $m.debug -tearoff 0]
    #$m add command -label "Comm: [comm::comm self]" -state disabled

    $top configure -menu $m
    return
}

