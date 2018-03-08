# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xmainframe - ("toplevel" + MainFrame) /snit::widgetadaptor
#
#	Generic parts for a toplevel window in the xref application.


package require BWidget ; Widget::theme 1 ; # MainFrame
package require snit    ; # Widget foundation
package require help    ; # Application online help.
package require splash  ; # Splash screen management
package require projectInfo
package require img::png
package require image;image::file::here

snit::widget xmainframe {
    hulltype toplevel
    component mainframe

    delegate method getframe      to mainframe
    delegate method showstatusbar to mainframe
    delegate method setmenustate  to mainframe

    delegate method * to hull
    delegate option * to hull

    variable status   {} ; # Status text
    variable progress 0  ; # Progress indicator.

    constructor {args} {
	# Have to handle the -menu separately, mainframe requires it
	# at construction time, and no later.

	$self title

	set menu [from args -menu {}]
	$type SetupMenu menu
	set menu [string map [list %SELF% [list $win]] $menu]

	#puts @@@@@@@@@@@@@@\n$menu\n@@@@@@@@@@@@@@@

	install mainframe using MainFrame $win.main \
	    -menu         $menu \
	    -textvariable [varname status] \
	    -progressvar  [varname progress]

	$mainframe showstatusbar status
	pack $mainframe -side top -expand 1 -fill both

	$self configurelist $args
	$type New

	wm protocol $win WM_DELETE_WINDOW [mymethod Close]

	if {[tk windowingsystem] eq "aqua"} {
	    # Aqua - No exit, link ourselves into the system quit
	    # entry. We keep our per-window close menu-entry
	    # however. Help is split in two.

	    interp alias ""      ::tk::mac::Quit "" $self Exit
	    bind all <Command-q> ::tk::mac::Quit
	}
	return
    }

    destructor {
	# Count one window less.
	$type Delete
    }

    # ### ######### ###########################
    # xmainframe - NEW API

    method status {text} {set status $text}


    method title {{text {}}} {
	set thetitle $text

	set top [winfo parent $win]
	if {$top ne "."} {
	    set text "[$top gettitle] - $text"
	}

	wm title $win "Tcl Dev Kit XRef $text"
	return
    }

    variable thetitle {}
    method gettitle {} {
	return $thetitle
    }

    method pinfinite {n} {
	$mainframe configure \
		-progresstype nonincremental_infinite \
		-progressmax $n
	set progress 0
	return
    }
    method pbound {n} {
	$mainframe configure \
		-progresstype normal \
		-progressmax $n
	set progress 0
    }
    method preset {}       {set  progress 0}
    method ptick  {{n 1}}  {incr progress $n}

    # ### ######### ###########################
    # Menu methods.

    method Close {} {
	## Future -- May check if something has to be saved.
	destroy $win
	return
    }
    method Exit {} {
	#puts EXIT/[pid]
	#exit 0
	destroy .
    }
    method ShowAbout {} {splash::showAbout 0}
    method ShowHelp  {} {help::open}

    # ### ######### ###########################
    # Counting instances ...

    typevariable count 0
    typemethod New {} {
	incr count
	return
    }
    typemethod Delete {} {
	incr count -1
	if {$count <= 0} {exit}
	return
    }

    # ### ######### ###########################
    # Handling the menu ...

    typemethod SetupMenu {menuvar} {
	upvar 1 $menuvar menu

	# I.  Look for a File menu. Extend with Close/Exit
	#     If not present create it as first menu.

	# II. Look for Help menu, Extend with about/help
	#     If no present create as last menu

	$type ExtendMenu menu File fmenu 0 {
	    {command &Close {close} {Close this window}    {} -command {%SELF% Close}}
	}

	set hcmd {command {&Help} {help} {Launch help viewer} {F1} -command {%SELF% ShowHelp}}
	set acmd [list command "&About $::projectInfo::productName" {about} {Show copyright information} {} -command {%SELF% ShowAbout}]

	if {[tk windowingsystem] ne "aqua"} {
	    # X11|Win. Standard menu entries for exit, and close this window.
	    # Standard help.

	    $type ExtendMenu menu File fmenu 0 {
		{command E&xit  {exit}  {Exit the application} {} -command {%SELF% Exit}}
	    }

	    lappend hcmd -compound left -image [image::get help]
	    $type ExtendMenu menu Help help end [list $hcmd]
	    $type ExtendMenu menu Help help end [list $acmd]

	} else {
	    # Aqua - No exit, link ourselves into the system quit
	    # entry (Done by caller). We keep our per-window close
	    # menu-entry however. Help is split in two.

	    $type ExtendMenu menu Help help  end [list $hcmd]
	    $type ExtendMenu menu TDK  apple 0   [list $acmd separator]
	}

	return
    }

    typemethod ExtendMenu {menuvar label tag pos entries} {
	upvar 1 $menuvar menu
	set loc [lsearch -glob $menu *${label}]
	if {$loc < 0} {
	    # Not found, insert new menu ...

	    set menu [linsert $menu $pos &$label {} $tag 0 $entries]
	} else {
	    # Found. Go ahead to the entries and extend them ...

	    incr                                             loc 4
	    set                         items [lindex $menu $loc]
	    lappend                     items separator
	    foreach e $entries {lappend items $e}
	    lset menu $loc             $items
	}
	return
    }


    # ### ######### ###########################
    # Reuse of instances ... Foundation

    typevariable cache
    typemethod lookup {key} {
	if {![info exists cache($key)]} {
	    # Nothing in cache.
	    return {}
	}
	set w $cache($key)
	if {![winfo exists $w]} {
	    # Cache is outdated.
	    unset cache($key)
	    return {}
	}
	wm deiconify $w ; # Bug 61178
	raise        $w
	return       $w
    }
    typemethod add {key w} {
	set cache($key) $w
	return $w
    }

    # ### ######### ###########################
    # Reuse of instances ... Detail windows.

    typemethod opendetail {parentwin wtype view row args} {
	# parentwin added to key to distinguish the windows
	# for different databases.

	set key $parentwin,[$wtype key $view $row]
	if {[set w [$type lookup $key]] != {}} {return $w}
	$type add $key [eval [linsert $args 0 $wtype create $parentwin.%AUTO% $view $row]]
    }

    # ### ######### ###########################
    # Helper commands, in the namespace, for mgmt of detail
    # windows.

    proc gridColResize {w collist {maxcol -1}} {

	if {$maxcol < 0} {
	    set maxcol [lindex [lsort -decr -integer $collist] 0]
	}

	for {set i 0} {$i < $maxcol} {incr i} {
	    grid columnconfigure $w $i -weight 0
	}
	foreach c $collist {
	    grid columnconfigure $w $c -weight 1
	}
	return
    }

    proc gridRowResize {w rowlist {maxrow -1}} {

	if {$maxrow < 0} {
	    set maxrow [lindex [lsort -decr -integer $rowlist] 0]
	}

	for {set i 0} {$i < $maxrow} {incr i} {
	    grid rowconfigure $w $i -weight 0
	}
	foreach r $rowlist {
	    grid rowconfigure $w $r -weight 1
	}
	return
    }


    proc gridSet {w cdef} {
	foreach {child row col rspan cspan stick} $cdef {
	    set path $w.$child
	    if {![winfo exists $path]} {continue}
	    grid $path \
		    -row     $row   -column     $col   \
		    -rowspan $rspan -columnspan $cspan \
		    -sticky $stick
	}
	return
    }
}

# ### ######### ###########################
# Ready to go

package provide xmainframe 0.2
