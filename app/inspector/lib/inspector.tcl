# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#!/bin/sh
#\
exec wish "$0" ${1+"$@"}
#
# $Id: //depot/main/Apps/ActiveTcl/devkit/app/inspector/lib/inspector.tcl#36 $
#

if {[string match -psn* [lindex $::argv 0]]} {
    # Strip Apple's option providing the Processor Serial Number to bundles.
    incr ::argc -1
    set  ::argv [lrange $::argv 1 end]
}

package require Tk 8.4

wm withdraw .

package require splash

package require style::as
style::as::init
style::as::enable control-mousewheel global

::splash::start

package require tile
package require tooltip
package require snit
package require widget::dialog
package require widget::statusbar
package require widget::scrolledwindow
package require help
package require img::png
package require treectrl

set ::AQUA [expr {[tk windowingsystem] eq "aqua"}]

if {$::AQUA} {
    set ::tk::mac::useThemedToplevel 1
}

option add *Scrolledwindow.borderWidth 1
option add *Scrolledwindow.relief sunken

bind Listbox <1> "+ ; focus %W" ; # make sure listbox gets focus on click

# The command name depends on integration with Tk (8.5+) or not (8.4).
if {[package vsatisfies [package present Tk] 8.5]} {
    # Tk 8.5+ (incl. tile)
    ttk::style configure Slim.Toolbutton -padding 1
} else {
    # Tk 8.4, tile is separate
    style default Slim.Toolbutton -padding 1
}

# Handle Tk 8.5 (ttk) or 8.4 (tile) usage of style
namespace eval ::ttk {
    style map TEntry -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
    style map TCombobox -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
}

namespace import -force ::tooltip::tooltip

namespace eval ::inspector {
    variable TITLE       "Inspector"
    variable VERSION     2.0
    variable RELEASEDATE 20050901
    variable SCRIPT      [file normalize [info script]]
    variable DIR
    set DIR(SCRIPT)      [file dirname $SCRIPT]
    set DIR(EXE)         [file dirname [info nameofexecutable]]
    set DIR(IMAGES)      [file join [file dirname $DIR(SCRIPT)] images]

    variable COUNTER     -1 ; # uniq id counter for windows
    variable NUM_WINDOWS  0 ; # number of open main windows

    # Missing: aliases
    variable LISTS
    set LISTS(names)	[list Namespaces namespace]
    set LISTS(procs)	[list Procs procedure {
	^tk[A-Z].*
	^tk::.*
	^auto_.*
    }]
    set LISTS(vars)	[list Variables variable {
	^tkPriv.*
	^auto_.*
	^tk_.*
	^tk::.*
    }]
    set LISTS(class)	[list Classes class]
    set LISTS(objects)	[list Objects object]
    set LISTS(windows)	[list Windows window [list "\\.#.*"]]
    set LISTS(images)	[list Images image]
    set LISTS(menus)	[list Menus menu]
    set LISTS(canvas)	[list Canvases canvas]
    set LISTS(after)	[list Afters after]
    variable DEFAULTS [list names procs vars]

    variable icon {
	iVBORw0KGgoAAAANSUhEUgAAACAAAAAfCAYAAACGVs+MAAAABmJLR0QA/wD/
	AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAB3RJTUUH1gwGAA8P/w/m
	EQAABClJREFUSMetVy+IOlsUPvu4YcIEw8AaJhgMBmEnTDAYDG7bti4oGCYY
	DAYXDAZhBFksD1wwGJZlg8EFg2GCwWD4BVlcUDC4PxRmwWBQmDCC8Eb4Xlh0
	ndX13+6BU4Y793z33HO+79wzWjMAWfoFe35+Vu/u7uj9/Z0kSaLr62uKRCL5
	8/Pz/4iIzs7ONuMAyOIXrNFogDEGIrK5KIp4eHiAZVnYOKjX6/3r8/mgadqP
	Afj9/o3g6x4Oh2Ga5ieI5cmdTid4nkcoFIKu6ycFr1arO4MvXZIkTCaTDxDB
	YBCKokCSJBiGAcMwkE6nkUwmMRgMjkq9IAgHASAiuFwumKaJs3a7jcfHR+p2
	u/Tnzx9ijBER0e3tLd3f35MsyxQIBOji4oJEUSSn00mLxYKm0ynNZjN6eXmh
	t7c3mk6n9Pr6SrPZ7OBiTSQSRMsTuN1uJBKJ5f0gk8nsPQVjDOVyGZZlwTAM
	DIdDFItFuFyug7LAcRxoPB6jXq+D53kEg0H4fD5IkrS1kr+6qqoAgEKhAI7j
	wBhDpVKBZVnQNA3hcBiiKO7eZ/nj+n2rqnrQCUzThK7rYIyB47hvu2gymUDX
	dTSbTTSbTfT7fTSbzY+O0TQNsixv/ORwOHYG93q9AIBWq7WqbFmWIQgCSqXS
	zoLtdDoQRRGapoEAIBAILNsCADCfz8Hz/E4AgUBga+87HI6d3aNpGnieRyqV
	+mjDZDIJxhh8Ph8ajQYajcZeMlkSytIMw4CqqkgkEuj3+1sDm6aJeDwOxhgy
	mczyc5YO7duvrijKUQTldrshCMLXOsn+c6rgLBaLvWuGwyHd3NxQJBKhUChE
	g8GArq6u7IsOabdt7vF4lsKyYYPBAIqigOM4KIqCTqfzXXKypCgKTr2GWCy2
	Kjhd11EqlRAMBuFwOBCPx9Hr9fbdTpZ6vd6/x3D4LhdFEZlM5hgxyxKAbLlc
	/lHgYDCIWq2G+Xx+rIBmV3JcKBSOCsoYQzQaRbPZtLXjd3WxF8CyeNLp9E4W
	FAQB6XT62zTX63W02+3TAKxT5VcmFEURxWJxpZa7LJfLIRaLwTCM4wF0Oh3b
	YMHzPPL5/EGB1y0ajUIQBFQqlcMB9Ho9W3CPx4PRaHTSeKbruo01v8nGJwDL
	suD1em1qty5Qp5jT6Vzt53a7t+nEJ4BGo2G789+YkGVZtu3J8zxardZhWuB2
	u3/8QBFFkYiIFEWhRCJBs9mMLi8vqdvtbn+QhMPhjXHrJ5ZKpUBEK65IJpMg
	Ivj9/u1FaFkWfD7famCs1Wp7ZXbX8LFk2PVOiMfjcDgctnnABmI8Hq+mWsYY
	VFXdym75fH7vXDAajcAYw9PTk+37eDzefJ6tg+j3+7bRWpKkjaKUJAlEhFwu
	tzNL5XJ5G2tufwSvg+h0OhuULMsy8vm87c1QrVaPF6A1+x8x+Wv0OUgU9wAA
	AABJRU5ErkJggg==
    }
    if {[tk windowingsystem] ne "aqua"} {
	wm iconphoto . -default [image create photo -data $icon]
    } else {
	# On OS X put the name into the Menubar as well. Otherwise
	# the name of the interpreter executing the application is
	# used.
	package require tclCarbonProcesses 1.1
	carbon::setProcessName [carbon::getCurrentProcess] TclInspector
    }

    ::help::page "Inspector"
}

proc ::inspector::load_files {} {
    variable DIR
    lappend files menus.tcl \
	find.tcl \
	names.tcl \
	value.tcl \
	\
	hirect.tcl \
	lists.tcl \
	afters_list.tcl \
	canvas_list.tcl \
	classes_list.tcl \
	globals_list.tcl \
	images_list.tcl \
	menus_list.tcl \
	namespaces_list.tcl \
	objects_list.tcl \
	procs_list.tcl \
	windows_list.tcl \
	windows_info.tcl
    foreach file $files {
	uplevel \#0 [list source [file join $DIR(SCRIPT) $file]]
    }
    set images [glob -directory $DIR(IMAGES) *.gif]
    foreach img $images {
	image create photo [file tail $img] -format GIF -file $img
    }
}
::inspector::load_files

# Emulate the 'send' command using the dde package if available.
proc init_send {} {
    if {![llength [info command send]] && ![catch {package require dde}]} {
	array set dde [list count 0 topic $::inspector::TITLE]
	while {[dde services TclEval $dde(topic)] != {}} {
	    incr dde(count)
	    set dde(topic) "$::inspector::TITLE #$dde(count)"
	}
	dde servername $dde(topic)
	set ::inspector::TITLE $dde(topic)
	unset dde
	proc send {app args} { eval [list dde eval $app] $args }
    }

    # Provide non-send based support using tklib's comm package.
    if {![catch {package require comm}]} {
	# defer the cleanup for 2 seconds to allow other events to process
	comm::comm hook lost {after 2000 set x 1; vwait x}

	#
	# replace send with version that does both send and comm
	#
	if {[llength [info command send]]} {
	    catch {rename send tk_send}
	} else {
	    proc tk_send args {}
	}
	proc send {app args} {
	    if {[string is integer -strict $app]} {
		eval [list comm::comm send $app] $args
	    } else {
		eval [list tk_send $app] $args
	    }
	}
    }
}
init_send

interp alias {} center_window {} ::tk::PlaceWindow

proc ::inspector::exit {} {
    destroy .
    ::exit 0
}

snit::widget inspector {
    hulltype toplevel

    option -target ""

    component status

    variable last_list {}
    variable windows_info {}
    variable commands {}
    variable showlists -array {}
    variable TARGET -array {}

    constructor {args} {
	set menu [menu $win.menu]
	$hull configure -menu $menu
	::inspector::menus $self $selfns $menu
	set TARGET(target) ""

	# Menu separator
	if {$::tcl_platform(platform) eq "windows"} {
	    ttk::separator $win.menusep -orient horizontal
	}

	# Toolbar
	set tbar [ttk::frame $win.tbar]

	# Toolbar separator
	ttk::separator $win.tbarsep -orient horizontal

	# Command: line
	set f [ttk::frame $win.buttons]
	ttk::label $f.cmdlbl -text "Command:"
	# XXX no -expand tab option yet, need autocompletion
	ttk::combobox $f.command -validate key \
	    -validatecommand [mymethod send_ok? $f.send %P] \
	    -values $commands
	bind $f.command <Return> [list $f.send invoke]
	ttk::button $f.send -text "Send" -state disabled \
	    -command [mymethod send_command]

	grid $f.cmdlbl $f.command $f.send -sticky ew -padx 2
	grid columnconfigure $f 1 -weight 1

	# Pane for Lists and Value
	set pw [ttk::panedwindow $win.pw -orient vertical]

	# Lists pane
	ttk::panedwindow $win.lists -orient horizontal

	set col 0
	foreach class [lsort [array names ::inspector::LISTS]] {
	    # Add class item into toolbar
	    foreach {label sing patterns} $::inspector::LISTS($class) break
	    set showlists($class) 0
	    set cb $tbar.cb$class
	    ttk::checkbutton $cb -style Toolbutton -takefocus 0 \
		-variable [myvar showlists($class)] \
		-command [mymethod toggle_list $class]
	    if {[lsearch -exact [image names] $label.gif] == -1} {
		$cb configure -text [string index $label 0] -width 2
	    } else {
		$cb configure -image $label.gif
	    }
	    grid $cb -row 0 -column [incr col] -sticky news
	    tooltip $cb "View $label"

	    # Add all then delete just the non-default classes to get all
	    # the initialization done.
	    set w [$self add_list $class]
	    if {[lsearch -exact $::inspector::DEFAULTS $class] == -1} {
		$self delete_list $w
	    }
	}

	# Value window
	value $win.value -main $self

	# Status window
	set sbar [widget::statusbar $win.sbar]
	install status using ttk::label $sbar.status -anchor w
	$sbar add $status -sticky ew -weight 1

	set windows_info [windows_info %AUTO%]

	# Do an idle update so that the windows will have the correct
	# reqsize for the panedwindow
	update idle
	foreach wn [list $win.lists $win.value] {
	    $pw add $wn -weight 1
	}

	if {[winfo exists $win.menusep]} {
	    grid $win.menusep -row 0 -sticky ew
	}
	grid $win.tbar    -row 1 -sticky w -padx 2
	grid $win.tbarsep -row 2 -sticky ew
	grid $win.buttons -row 3 -sticky ew -pady 2
	grid $win.pw      -row 4 -sticky news -padx 2 -pady 2
	grid $win.sbar    -row 5 -sticky ew
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 4 -weight 1

	set title $::inspector::TITLE
	wm iconname $win $title
	wm title $win "Not Connected - $title"
	$win status "Ready."

	$self configurelist $args
    }

    destructor {
	catch {$windows_info destroy}
	if {[incr ::inspector::NUM_WINDOWS -1] == 0} ::inspector::exit
    }

    onconfigure -target {value} {
	set options(-target) $value
	foreach {target type} $value break
	if {$type eq ""} { set type "send" }
	set TARGET(target) $target
	set TARGET(type)   $type
	if {$type eq "comm"} {
	    set TARGET(name) [comm::comm self]
	} else {
	    set TARGET(name) [winfo name .]
	}
	$self update_lists
	if {$target eq ""} {
	    wm title $win "Not Connected - $::inspector::TITLE"
	} else {
	    set cmd [send $target \
			 {list [catch {::set argv0} __inspector] $__inspector}]
	    if {[lindex $cmd 0]} {
		# no ::argv0 ...
		send $target [list ::set argv0 $target]
		set name $target
	    } else {
		set name [file tail [lindex $cmd 1]]
	    }
	    $self status "Remote interpreter is \"$target\" ($name)"
	    wm title $win "$target ($name) - $::inspector::TITLE"
	}
    }

    method update_lists {} {
	if {$TARGET(target) eq ""} return
	# Enable Send button
	$self send_ok? $win.buttons.send [$win.buttons.command get]
	foreach list [array names showlists] {
	    if {$showlists($list)} {
		$win.lists.$list update $TARGET(target)
	    }
	}
    }
    method select_list_item {list item} {
	set last_list $list
	$win.value set_value [list [$list cget -name] $item] \
	    [$list retrieve $TARGET(target) $item] \
	    [mymethod select_list_item $list $item]
	$win.value set_send_filter [list $list send_filter]
	$self status "Showing \"$item\""
    }
    method connect_dialog {} {
	set w $win.connect
	if {![winfo exists $w]} {
	    connect_comm $w -attach $self -place pointer
	}
	$w display
    }
    method fill_socket_menu {m} {
	$m delete 0 end
	foreach sock [file channels sock*] {
	    $m add command -label $sock -state disabled
	}
    }
    method fill_interp_menu {m} {
	$m delete 0 end
	foreach interp [winfo interps] {
	    $m add command -label $interp \
		-command [list $self configure -target [list $interp send]]
	}
	if {[package provide dde] != {}} {
	    foreach service [dde services TclEval {}] {
		set app [lindex $service 1]
		$m add command -label $app \
		    -command [list $self configure -target [list $app dde]]
	    }
	}
    }
    method fill_comminterp_menu {m} {
	$m delete 0 end
	foreach interp [lsort -unique [comm::comm interps]] {
	    if {[comm::comm self] eq $interp} {
		set label "$interp (self)"
	    } else {
		set label "$interp ([file tail [send $interp ::set argv0]])"
	    }
	    $m add command -label $label \
		-command [list $self configure -target [list $interp comm]]
	}
    }
    method status {msg} {
	$status configure -text $msg
    }
    method target {{what target}} {
	if {$TARGET(target) eq ""} {
	    tk_messageBox -title "No Interpreter" -type ok -icon warning \
		-message "No interpreter has been selected yet.\
		    Please select one first."
	    return ""
	}
	if {![info exists TARGET($what)]} {
	    return -code error "invalid target request type \"$what\""
	}
	return $TARGET($what)
    }
    method last_list {} { return $last_list }
    method send_ok? {btn {cmd {}}} {
	if {[string length $cmd] && $TARGET(target) ne ""} {
	    $btn configure -state "normal"
	} else {
	    $btn configure -state "disabled"
	}
	return 1
    }
    method send_command {{cmd {}}} {
	set last_list ""
	set e   $win.buttons.command
	set level [info level 0]
	if {[llength $level] == [llength [info args [lindex $level 0]]]} {
	    # cmd not specified
	    set cmd [$e get]
	}
	if {[string length $cmd] && $TARGET(target) ne ""} {
	    set retval [send $TARGET(target) \
			    "list \[catch [list $cmd] __inspector\]\
				\$__inspector \[unset __inspector\]"]
	    set code   [lindex $retval 0]
	    set result [lindex $retval 1]
	    if {$code == 1} {
		if {[catch {send $TARGET(target) {set errorInfo}} errInfo]} {
		    append result "Error getting errorInfo:\n$errInfo"
		} else {
		    # errorInfo always has error line first
		    set result $errInfo
		}
	    }
	    $win.value set_value [list command $cmd] \
		$result [mymethod send_command $cmd]
	    $win.value set_send_filter ""
	    $self status "Command sent."
	    set idx [lsearch -exact $commands $cmd]
	    if {$idx >= 0} {
		set commands [lreplace $commands $idx $idx]
	    }
	    set commands [linsert $commands 0 $cmd]
	    $e configure -values $commands -text ""
	} else {
	    $self status "Empty command or target - nothing sent."
	}
    }
    method toggle_list {class} {
	set list $win.lists.$class
	# logic reversed to handle toolbutton sync
	if {$showlists($class)} {
	    $self add_list $class
	    if {$TARGET(target) ne ""} {
		$list update $TARGET(target)
	    }
	} else {
	    $list remove
	}
    }
    method add_list {class} {
	set list $win.lists.$class
	if {![winfo exists $list]} {
	    foreach {plural singular ptrns} $::inspector::LISTS($class) break
	    set menu [$self add_menu $plural]
	    ${class}::init $list -main $self -title $plural -name $singular \
		-command [mymethod select_list_item $list] \
		-patterns $ptrns -menu $menu
	}
	$win.lists add $list -weight 1
	set showlists($class) 1
	return $list
    }
    method delete_list {list} {
	$win.lists forget $list
	set class [lindex [split $list .] 3]
	set showlists($class) 0
    }
    method add_menu {name} {
	set menu $win.menu.windows
	set m [menu $menu.[string tolower $name] -tearoff 0]
	$menu add cascade -label $name -underline 0 -menu $m
	if {0 && [lsearch -exact [image names] $name.gif] != -1} {
	    $menu entryconfigure $name -image $name.gif -compound left
	}
	return $m
    }
    method delete_menu {name} {
	set menu $win.menu.windows
	catch {$menu delete $name}
	destroy $menu.[string tolower $name]
    }
    method windows_info {args} {
	eval $windows_info $args
    }
}

proc ::inspector::create_main_window {args} {
    set w [eval [list inspector .main[incr ::inspector::COUNTER]] $args]
    incr ::inspector::NUM_WINDOWS
    focus -force $w
    return $w
}

snit::widgetadaptor connect_comm {
    delegate method * to hull
    delegate option * to hull

    option -attach ""
    component entry

    constructor {args} {
	installhull using widget::dialog -title "Connect to Interp..." \
	    -type okcancel -modal none -synchronous 0 -padding 4 \
	    -command [mymethod callback]

	wm resizable $win 1 0

	set frame [$win getframe]

	ttk::label $frame.l -text "Connect to port:"
	set entry [ttk::entry $frame.e -validate key \
		       -validatecommand {string is integer %P} \
		       -invalidcommand bell]
	bind $entry <Return> [list $win close ok]

	grid $frame.l $frame.e -sticky ew
	grid columnconfigure $frame 1 -weight 1

	$self configurelist $args
    }

    method display {} {
	$hull display
	focus $entry
	$entry selection range 0 end
    }

    method callback {w result} {
	if {$result eq "ok"} {
	    set text [$entry get]
	    if {$text ne ""} {
		comm::comm connect $text
		$options(-attach) configure -target [list $text comm]
	    }
	}
    }
}

::inspector::create_main_window

::splash::complete
