# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# menus.tcl --
#
#	This file defines menus for Inspector
#
# Copyright (c) 2003-2007 ActiveState Software Inc.
#
#

package require projectInfo

proc ::inspector::menus {self selfns menu} {

    # Special .apple menu must be FIRST.
    if {[tk windowingsystem] eq "aqua"} {
	# Aqua About help in system menu. for non-aqua see bottom of body.
	set apple [menu $menu.apple -tearoff 0]
	$menu add cascade -label "&TDK" -underline 0 -menu $apple
	$apple add command -label "About $::projectInfo::productName" -underline 0 \
	    -command [list ::splash::showAbout]
    }

    # File
    set m [menu $menu.file -tearoff 0]
    $menu add cascade -label "File" -underline 0 -menu $m

    $m add command -label "Launch Script" -state disabled

    if {[tk windowingsystem] eq "aqua"} {
	set acc "Command-"
	set evt "Command-"
    } else {
	set acc "Ctrl+"
	set evt "Control-"
    }

    # Attach
    #set ma [menu $menu.attach -tearoff 0]
    set ma $menu.file
    #$menu add cascade -label "Attach" -underline 0 -menu $m
    $m add cascade -label "Attach to Interp (send)" -underline 0 \
	-menu $ma.send
    if {[package provide comm] != {}} {
	$m add cascade -label "Attach to Interp (comm)" -underline 10 \
	    -menu $ma.comm
	$m add command -label "Connect to comm port" -underline 16 \
	    -command [list $self connect_dialog] -accel "${acc}N"
    }
    bind $self <${evt}n> [list $self connect_dialog]
    bind $self <${evt}N> [bind $self <${evt}n>]

    if {0} {
	# no connect to socket yet
	$m add separator
	$m add cascade -label "Socket (raw)" -underline 1 \
	    -menu $ma.sock
	$m add command -label "Connect to socket (raw)" -underline 19 \
	    -command [list $self connect_dialog] -state disabled
    }

    # Attach -> (send)
    menu $ma.send -tearoff 0 \
	-postcommand [list $self fill_interp_menu $ma.send]
    if {[package provide comm] != {}} {
	# Attach -> (comm)
	menu $ma.comm -tearoff 0 -postcommand \
	    [list $self fill_comminterp_menu $ma.comm]
    }
    # Attach -> Socket
    menu $ma.sock -tearoff 0 -postcommand \
	[list $self fill_socket_menu $ma.sock]

    # File -> Window ops
    $m add separator
    $m add command -label "New Window" -underline 0 \
	-command ::inspector::create_main_window
    $m add separator
    $m add command -label "Close Window" -underline 0 \
	-command [list destroy $self]
    if {[tk windowingsystem] eq "aqua"} {
	interp alias "" ::tk::mac::Quit "" ::inspector::exit
	bind all <Command-q> ::tk::mac::Quit
    } else {
	$m add command -label "Exit" -underline 1 \
	    -accelerator "${acc}q" \
	    -command ::inspector::exit
	bind $self <${evt}q> { ::inspector::exit }
    }

    # Edit
    set m [menu $menu.edit -tearoff 0]
    $menu add cascade -label "Edit" -underline 0 -menu $m
    $m add command -label "Cut"   -underline 2 -accelerator "${acc}x" \
	-command { event generate [focus] <<Cut>> }
    $m add command -label "Copy"  -underline 0 -accelerator "${acc}c" \
	-command { event generate [focus] <<Copy>> }
    $m add command -label "Paste" -underline 0 -accelerator "${acc}v" \
	-command { event generate [focus] <<Paste>> }
    if {[tk windowingsystem] eq "x11"} {
	$m entryconfigure "Paste" -accelerator "${acc}y"
    }
    $m add separator
    $m add command -label "Select All" -underline 0 -accelerator "Ctrl-/" \
	-command { event generate [focus] <Control-slash> }

    # View
    set m [menu $menu.view -tearoff 0]
    $menu add cascade -label "View" -underline 0 -menu $m
    $m add command -label "Refresh All" -underline 0 \
	-command [list $self update_lists]
    $m add separator
    foreach class [lsort [array names ::inspector::LISTS]] {
	foreach {plural singular ptrns} $::inspector::LISTS($class) break
	$m add checkbutton -label $plural \
	    -variable ${selfns}::showlists($class) \
	    -command [list $self toggle_list $class]
	if {[lsearch -exact [image names] $plural.gif] != -1
	    && [tk windowingsystem] ne "aqua"} {
	    $m entryconfigure $plural -image $plural.gif -compound left
	}
    }

    # Windows
    set m [menu $menu.windows -tearoff 0]
    $menu add cascade -label "Windows" -underline 0 -menu $m

    # Help
    set m [menu $menu.help -tearoff 0]
    $menu add cascade -label "Help" -underline 0 -menu $m
    $m add command -label "Help" -underline 0 -command [list ::help::open] \
	-accelerator F1
    bind $self <Key-F1> [list $m invoke Help]

    if {[tk windowingsystem] ne "aqua"} {
	$m entryconfigure "Help" -compound left -image help.gif
    }

    $m add checkbutton -label "Show Tooltips" -underline 5 \
	-variable ::tooltip::G(enabled)

    if {[tk windowingsystem] ne "aqua"} {
	# Regular About help. For aqua see top of the proc body.
	$m add separator
	$m add command -label "About $::projectInfo::productName" -underline 0 \
	    -command [list ::splash::showAbout]
    }
}
