# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_main.tcl,v 1.124 2007/04/28 05:18:50 danielk1977 Exp $)} 1 }

catch {memory init on}

set ::DEBUG [expr {[info exists ::env(HV3_DEBUG)]
		   && [string is true $::env(HV3_DEBUG)]}]

package require Tk
package require Tkhtml 3.0

# Before doing anything else, set up profiling if it is requested.
# Profiling is only used if the "-profile" option was passed on
# the command line.
# - Disabled for ashv -
#source [sourcefile hv3_profile.tcl]
#::hv3::profile::init $argv

if {[catch {package require Tk 8.5a6}]} {
    package require tile
}

package require style::as
style::as::init
style::as::enable mousewheel ; # use globally bound mousewheel handler

# Img is required for PNG (icons) and optionally JPG in URLs
package require Img

package require snit

# Use tooltips
package require tooltip
namespace import -force ::tooltip::tooltip

# This is for scrolledwindow, statusbar, toolbar
package require widget::all

if {[tk windowingsystem] eq "aqua"} {
    set ::tk::mac::useThemedToplevel 1
}

# Try to load sqlite3. If sqlite3 is present cookies, auto-completion and
# coloring of visited URIs work.
if {[catch { package require sqlite3 } errmsg]} {
    puts stderr "WARNING: $errmsg"
}

proc htmlize {zIn} {
    string map [list "<" "&lt;" ">" "&gt;" "&" "&amp;" "\"" "&quote;"] $zIn
}

# Source the other script files that are part of this application.
#

set ::DIR [file dirname [info script]]
set ::LIBDIR [file dirname $::DIR]/lib

if {[file exists $::LIBDIR]} { lappend auto_path $::LIBDIR }

# probably a better way to do images, but this works for now
set ::IMGDIR [file dirname $::DIR]/lib/images
proc load_images {dir} {
    namespace eval ::hv3::img {} ; # namespace for images
    foreach img [glob -nocomplain -directory $dir *.{png,jpg,gif}] {
	set name [file root [file tail $img]]
	image create photo ::hv3::img::$name -file $img
    }
}
load_images $::IMGDIR

proc load_sources {dir} {
    foreach file {
	hv3_encodings.tcl
	hv3_db.tcl
	hv3_home.tcl
	hv3.tcl
	hv3_prop.tcl
	hv3_log.tcl
	hv3_http.tcl
	hv3_file.tcl
	hv3_frameset.tcl
	hv3_polipo.tcl
	hv3_history.tcl
	hv3_string.tcl
	hv3_search.tcl
    } {
	uplevel \#0 [list source [file join $dir $file]]
    }
}
load_sources $::DIR

#--------------------------------------------------------------------------
# Widget ::hv3::browser_frame
#
#     This mega widget is instantiated for each browser frame (a regular
#     html document has one frame, a <frameset> document may have more
#     than one). This widget is not considered reusable - it is designed
#     for the web browser only. The following application-specific
#     functionality is added to ::hv3::hv3:
#
#         * The -statusvar option
#         * The right-click menu
#         * Overrides the default -targetcmd supplied by ::hv3::hv3
#           to respect the "target" attribute of <a> and <form> elements.
#
#     For more detail on handling the "target" attribute, see HTML 4.01. 
#     In particular the following from appendix B.8:
# 
#         1. If the target name is a reserved word as described in the
#            normative text, apply it as described.
#         2. Otherwise, perform a depth-first search of the frame hierarchy 
#            in the window that contained the link. Use the first frame whose 
#            name is an exact match.
#         3. If no such frame was found in (2), apply step 2 to each window,
#            in a front-to-back ordering. Stop as soon as you encounter a frame
#            with exactly the same name.
#         4. If no such frame was found in (3), create a new window and 
#            assign it the target name.
#
#     Hv3 currently only implements steps 1 and 2.
#
snit::widget ::hv3::browser_frame {

    component myHv3

    variable myNodeList ""                  ;# Current nodes under the pointer
    variable myX 0                          ;# Current location of pointer
    variable myY 0                          ;# Current location of pointer

    variable myBrowser ""                   ;# ::hv3::browser_toplevel widget
    variable myPositionId ""                ;# See sub-command [positionid]

    # If "Copy Link Location" has been selected, store the selected text
    # (a URI) in variable $myCopiedLinkLocation.
    variable myCopiedLinkLocation ""

    constructor {browser args} {
	set myBrowser $browser
	$self configurelist $args

	set myHv3 [::hv3::hv3 $win.hv3]
	pack $myHv3 -expand true -fill both

	::hv3::the_visited_db init $myHv3

	catch {$myHv3 configure -fonttable $::hv3::fontsize_table}
	# $myHv3 configure -downloadcmd [list $myBrowser savehandle]
	$myHv3 configure -downloadcmd [list ::hv3::the_download_manager savehandle]

	# Create bindings for motion, right-click and middle-click.
	bind $myHv3 <Motion> +[mymethod motion %x %y]
	bind $myHv3 <3>       [mymethod rightclick %x %y %X %Y]
	bind $myHv3 <2>       [mymethod goto_selection]

	# When the hyperlink menu "owns" the selection (happens after
	# "Copy Link Location" is selected), invoke method
	# [GetCopiedLinkLocation] with no arguments to retrieve it.

	# Register a handler command to handle <frameset>.
	set html [$myHv3 html]
	$html handler node frameset [list ::hv3::frameset_handler $self]
	$html handler node iframe [list ::hv3::iframe_handler $self]

	# Add this object to the browsers frames list. It will be removed by
	# the destructor proc. Also override the default -targetcmd
	# option of the ::hv3::hv3 widget with our own version.
	$myBrowser add_frame $self
	$myHv3 configure -targetcmd [mymethod Targetcmd]

	::hv3::menu $win.hyperlinkmenu
	selection handle $win.hyperlinkmenu [mymethod GetCopiedLinkLocation]
    }

    # The name of this frame (as specified by the "name" attribute of
    # the <frame> element).
    option -name -default ""

    # If this [::hv3::browser_frame] is used as a replacement object
    # for an <iframe> element, then this option is set to the Tkhtml3
    # node-handle for that <iframe> element.
    #
    option -iframe -default ""

    method Targetcmd {node} {
	set target [$node attr -default "" target]
	if {$target eq ""} {
	    # If there is no target frame specified, see if a default
	    # target was specified in a <base> tag i.e. <base target="_top">.
	    set n [lindex [[$myHv3 html] search base] 0]
	    if {$n ne ""} { set target [$n attr -default "" target] }
	}

	set theTopFrame [[lindex [$myBrowser get_frames] 0] hv3]

	# Find the target frame widget.
	set widget $myHv3
	switch -- $target {
	    ""        { set widget $myHv3 }
	    "_self"   { set widget $myHv3 }
	    "_top"    { set widget $theTopFrame }

	    "_parent" {
		set w [winfo parent $myHv3]
		while {$w ne ""
		       && [lsearch -exact [$myBrowser get_frames] $w] < 0} {
		    set w [winfo parent $w]
		}
		if {$w ne ""} {
		    set widget [$w hv3]
		} else {
		    set widget $theTopFrame
		}
	    }

	    # This is incorrect. The correct behaviour is to open a new
	    # top-level window. But hv3 doesn't support this (and because
	    # reasonable people don't like new top-level windows) we load
	    # the resource into the "_top" frame instead.
	    "_blank"  { set widget $theTopFrame }

	    default {
		# In html 4.01, an unknown frame should be handled the same
		# way as "_blank". So this next line of code implements the
		# same bug as described for "_blank" above.
		set widget $theTopFrame

		# TODO: The following should be a depth first search through
		# the frames in the list returned by [get_frames].
		foreach f [$myBrowser get_frames] {
		    set n [$f cget -name]
		    if {$n eq $target} {
			set widget [$f hv3]
			break
		    }
		}
	    }
	}

	return $widget
    }

    method parent_frame {} {
	set frames [$myBrowser get_frames]
	set w [winfo parent $self]
	while {$w ne "" && [lsearch $frames $w] < 0} {
	    set w [winfo parent $w]
	}
	return $w
    }

    method top_frame {} {
	lindex [$myBrowser get_frames] 0
    }

    method child_frames {} {
	set ret [list]
	foreach c [$myBrowser frames_tree $self] {
	    lappend ret [lindex $c 0]
	}
	set ret
    }

    # This method returns the "position-id" of a frame, an id that is
    # used by the history sub-system when loading a historical state of
    # a frameset document.
    #
    method positionid {} {
	if {$myPositionId eq ""} {
	    set w $win
	    while {[set p [winfo parent $w]] ne ""} {
		set class [winfo class $p]
		if {$class eq "Panedwindow"} {
		    set myPositionId [linsert $myPositionId 0 \
					  [lsearch -exact [$p panes] $w]]
		}
		set w $p
	    }
	    set myPositionId [linsert $myPositionId 0 0 0]
	}
	return $myPositionId
    }

    destructor {
	# Remove this object from the $theFrames list.
	catch {$myBrowser del_frame $self}
	catch {destroy ${win}.hyperlinkmenu}
    }

    # This callback is invoked when the user right-clicks on this
    # widget. If the mouse cursor is currently hovering over a hyperlink,
    # popup the hyperlink menu. Otherwise launch the tree browser.
    #
    # Arguments $x and $y are the the current cursor position relative to
    # this widget's window. $X and $Y are the same position relative to
    # the root window.
    #
    method rightclick {x y X Y} {
	if {!$::DEBUG} {
	    return
	}

	set m ${win}.hyperlinkmenu
	$m delete 0 end

	set nodelist [$myHv3 node $x $y]

	set a_href ""
	set img_src ""
	set select [$myHv3 selected]
	set leaf ""

	foreach leaf $nodelist {
	    for {set N $leaf} {$N ne ""} {set N [$N parent]} {
		set tag [$N tag]

		if {$a_href eq "" && $tag eq "a"} {
		    set a_href [$N attr -default "" href]
		}
		if {$img_src eq "" && $tag eq "img"} {
		    set img_src [$N attr -default "" src]
		}

	    }
	}

	if {$a_href ne ""}  {set a_href [$myHv3 resolve_uri $a_href]}
	if {$img_src ne ""} {set img_src [$myHv3 resolve_uri $img_src]}

	set MENU [list]
	lappend MENU \
	    a_href "Open Link"             [mymethod menu_select open $a_href]      \
	    a_href "Open Link in Bg Tab"   [mymethod menu_select opentab $a_href]   \
	    a_href "Download Link"         [mymethod menu_select download $a_href]  \
	    a_href "Copy Link Location"    [mymethod menu_select copy $a_href]      \
	    a_href --                      ""                                       \
	    img_src "View Image"           [mymethod menu_select open $img_src]     \
	    img_src "View Image in Bg Tab" [mymethod menu_select opentab $img_src]  \
	    img_src "Download Image"       [mymethod menu_select download $img_src] \
	    img_src "Copy Image Location"  [mymethod menu_select copy $img_src]     \
	    img_src --                     ""                                       \
	    select  "Copy Selected Text"   [mymethod menu_select copy $select]      \
	    select  --                     ""                                       \
	    leaf    "Open Tree browser..." [list ::HtmlDebug::browse $myHv3 $leaf]

	foreach {var label cmd} $MENU {
	    if {$var eq "" || [set $var] ne ""} {
		if {$label eq "--"} {
		    $m add separator
		} else {
		    $m add command -label $label -command $cmd
		}
	    }
	}

	if {$::DEBUG} {
	    $::hv3::G(config) populate_hidegui_entry $m
	    $m add separator
	}

	# Add the "File", "Search", "View" and "Debug" menus.
	set menus [list File Search Options History]
	if {$::DEBUG} {
	    set menus [linsert $menus end-1 Debug]
	}
	foreach sub $menus {
	    catch {
		set menu_widget $m.[string tolower $sub]
		gui_populate_menu $sub [::hv3::menu $menu_widget]
	    }
	    $m add cascade -label $sub -menu $menu_widget -underline 0
	}

	tk_popup $m $X $Y
    }

    # Called when an option has been selected on the hyper-link menu. The
    # argument identifies the specific option. May be one of:
    #
    #     open
    #     opentab
    #     download
    #     copy
    #
    method menu_select {option uri} {
	switch -- $option {
	    open {
		set top_frame [lindex [$myBrowser get_frames] 0]
		$top_frame goto $uri
	    }
	    opentab { set new [$::hv3::G(notebook) addbg $uri] }
	    download { $myBrowser saveuri $uri }
	    copy {
		set myCopiedLinkLocation $uri
		selection own ${win}.hyperlinkmenu
		clipboard clear
		clipboard append $uri
	    }

	    default {
		error "Internal error"
	    }
	}
    }

    method GetCopiedLinkLocation {args} {
	return $myCopiedLinkLocation
    }

    # Called when the user middle-clicks on the widget
    method goto_selection {} {
	set theTopFrame [lindex [$myBrowser get_frames] 0]
	if {![catch {::tk::GetSelection $win} sel]} {
	    $theTopFrame goto $sel
	}
    }

    method motion {x y} {
	set myX $x
	set myY $y
	set myNodeList [$myHv3 node $x $y]
	$self update_statusvar
    }

    method node_to_string {node {hyperlink 1}} {
	set value ""
	for {set n $node} {$n ne ""} {set n [$n parent]} {
	    if {[info commands $n] eq ""} break
	    set tag [$n tag]
	    if {$tag eq ""} {
		set value [$n text]
	    } elseif {$hyperlink && $tag eq "a" && [$n attr -default "" href] ne ""} {
		set value "hyper-link: [string trim [$n attr href]]"
		break
	    } elseif {[set nid [$n attr -default "" id]] ne ""} {
		set value "<$tag id=$nid>$value"
	    } else {
		set value "<$tag>$value"
	    }
	}
	return $value
    }

    method update_statusvar {} {
	if {$options(-statusvar) ne ""} {
	    set value [$self node_to_string [lindex $myNodeList end]]
	    set str "($myX $myY) $value"
	    uplevel #0 [list set $options(-statusvar) $str]
	}
    }
    
    #--------------------------------------------------------------------------
    # PUBLIC INTERFACE
    #--------------------------------------------------------------------------

    method goto {args} {
	eval [concat $myHv3 goto $args]
	$self update_statusvar
    }

    # Launch the tree browser
    method browse {} {
	::HtmlDebug::browse $myHv3 [$myHv3 node]
    }

    method hv3     {} { return $myHv3 }
    method browser {} { return $myBrowser }

    # The [isframeset] method returns true if this widget instance has
    # been used to parse a frameset document (widget instances may parse
    # either frameset or regular HTML documents).
    #
    method isframeset {} {
	# When a <FRAMESET> tag is parsed, a node-handler in hv3_frameset.tcl
	# creates a widget to manage the frames and then uses [place] to 
	# map it on top of the html widget created by this ::hv3::browser_frame
	# widget. Todo: It would be better if this code was in the same file
	# as the node-handler, otherwise this test is a bit obscure.
	#
	set html [[$self hv3] html]
	set slaves [place slaves $html]
	set isFrameset [expr {[llength $slaves] > 0}]
	return $isFrameset
    }

    option -statusvar        -default ""

    delegate option -doublebuffer     to myHv3
    delegate option -forcefontmetrics to myHv3
    delegate option -fonttable        to myHv3
    delegate option -fontscale        to myHv3
    delegate option -zoom             to myHv3
    delegate option -enableimages     to myHv3
    delegate option -dom              to myHv3

    delegate method dumpforms         to myHv3

    delegate option -width         to myHv3
    delegate option -height        to myHv3

    delegate option -requestcmd         to myHv3
    delegate option -resetcmd           to myHv3
    delegate option -pendingvar         to myHv3

    delegate method stop to myHv3
    delegate method titlevar to myHv3
    delegate method javascriptlog to myHv3
}

# An instance of this widget represents a top-level browser frame (not
# a toplevel window - an html frame not contained in any frameset 
# document).These are the things managed by the notebook widget.
#
snit::widget ::hv3::browser_toplevel {
    hulltype ttk::frame

    component myHistory                ;# The back/forward system
    component myProtocol               ;# The ::hv3::protocol
    component myMainFrame              ;# The browser_frame widget
    component myDom                    ;# The ::hv3::dom object

    # Variables passed to [$myProtocol configure -statusvar] and
    # the same option of $myMainFrame. Used to create the value for 
    # $myStatusVar.
    variable myProtocolStatus ""
    variable myFrameStatus ""

    variable myStatusVar ""
    variable myLocationVar ""

    # List of all ::hv3::browser_frame objects using this object as
    # their toplevel browser. 
    variable myFrames [list]
    variable myFindbar ""

    # Variable passed to the -pendingvar option of the ::hv3::hv3 widget
    # associated with the $myMainFrame frame. Set to true when the 
    # "Stop" button should be enabled, else false.
    #
    # TODO: Frames bug?
    variable myPendingVar 0

    delegate method populate_history_menu to myHistory as populate_menu

    option -stopbutton -default "" -configuremethod Configurestopbutton

    delegate option -backbutton    to myHistory
    delegate option -forwardbutton to myHistory
    delegate option -addressbar    to myHistory

    delegate option -enablejavascript to myDom as -enable

    delegate method locationvar to myHistory
    delegate method populatehistorymenu to myHistory

    delegate method debug_cookies  to myProtocol

    delegate option * to myMainFrame
    delegate method * to myMainFrame

    method statusvar {} {return [myvar myStatusVar]}

    constructor {args} {
	# Create the main browser frame (always present)
	set myMainFrame [::hv3::browser_frame $win.browser_frame $self]
	pack $myMainFrame -expand true -fill both -side top

	set myFindbar $win.findwidget

	# Create the protocol
	set myProtocol [::hv3::protocol %AUTO%]
	$myMainFrame configure -requestcmd [list $myProtocol requestcmd]
	$myMainFrame configure -pendingvar [myvar myPendingVar]

	trace add variable [myvar myPendingVar] write [mymethod Setstopbutton]

	$myProtocol configure -statusvar [myvar myProtocolStatus]
	$myMainFrame configure -statusvar [myvar myFrameStatus]
	trace add variable [myvar myProtocolStatus] write [mymethod Writestatus]
	trace add variable [myvar myFrameStatus] write    [mymethod Writestatus]

	# Link in the "home:" and "about:" scheme handlers (from hv3_home.tcl)
	::hv3::home_scheme_init [$myMainFrame hv3] $myProtocol
	::hv3::cookies_scheme_init $myProtocol
	::hv3::download_scheme_init [$myMainFrame hv3] $myProtocol

	# Create the history sub-system
	set myHistory [::hv3::history %AUTO% [$myMainFrame hv3] $myProtocol $self]
	$myHistory configure -gotocmd [mymethod goto]

	set myDom [::hv3::dom %AUTO% $self]
	$myMainFrame configure -dom $myDom

	$self configurelist $args
    }

    destructor {
	if {$myProtocol ne ""} { $myProtocol destroy }
	if {$myHistory ne ""}  { $myHistory destroy }
	if {$myDom ne ""}      { $myDom destroy }
    }

    method goto {args} {
	eval [linsert $args 0 $myMainFrame goto]
	if {[winfo exists $myFindbar]} {
	    $self Find ; # redo the quick find
	}
    }

    # This method is called to activate the download-manager to download
    # the specified URI ($uri) to the local file-system.
    #
    method saveuri {uri} {
	set handle [::hv3::download %AUTO% \
			-uri         $uri \
			-mimetype    application/gzip \
		       ]
	$handle configure \
	    -incrscript [list ::hv3::the_download_manager savehandle $handle] \
	    -finscript  [list ::hv3::the_download_manager savehandle $handle]

	$myProtocol requestcmd $handle
    }

    # Interface used by code in class ::hv3::browser_frame for frame management
    #
    method add_frame {frame} {
	lappend myFrames $frame
	if {$myHistory ne ""} {
	    $myHistory add_hv3 [$frame hv3]
	}

	set HTML [[$frame hv3] html]
	bind $HTML <1>               [list focus %W]
	bind $HTML <KeyPress-slash>  [mymethod Find]
	bindtags $HTML [concat Hv3HotKeys $self [bindtags $HTML]]
	$frame configure -dom $myDom
	$::hv3::G(config) configurebrowser $frame
    }
    method del_frame {frame} {
	set idx [lsearch -exact $myFrames $frame]
	if {$idx >= 0} {
	    set myFrames [lreplace $myFrames $idx $idx]
	}
    }
    method get_frames {} {return $myFrames}

    # Return a list describing the current structure of the frameset 
    # displayed by this browser.
    #
    method frames_tree {{head {}}} {
	set ret ""

	array set A {}
	foreach f [lsort $myFrames] {
	    set p [$f parent_frame]
	    lappend A($p) $f
	    if {![info exists A($f)]} {set A($f) [list]}
	}

	foreach f [concat [lsort -decreasing $myFrames] [list {}]] {
	    set new [list]
	    foreach child $A($f) {
		lappend new [list $child $A($child)]
	    }
	    set A($f) $new
	}
	
	set A($head)
    }

    # This method is called by a [trace variable ... write] hook attached
    # to the myProtocolStatus variable. Set myStatusVar.
    method Writestatus {args} {
	set myStatusVar "$myProtocolStatus    $myFrameStatus"
    }

    method Setstopbutton {args} {
	if {$options(-stopbutton) ne ""} {
	    if {$myPendingVar} {
		$options(-stopbutton) configure -state normal
		$hull configure -cursor watch
	    } else {
		$options(-stopbutton) configure -state disabled
		$hull configure -cursor ""
	    }
	    $options(-stopbutton) configure -command [list $myMainFrame stop]
	}
    }
    method Configurestopbutton {option value} {
	set options(-stopbutton) $value
	$self Setstopbutton
    }

    # Escape --
    #
    #     This method is called when the <Escape> key sequence is seen.
    #     Get rid of the "find-text" widget, if it is currently visible.
    #
    method escape {} {
	destroy $myFindbar
    }

    method packwidget {w} {
	pack $w -before $myMainFrame -side bottom -fill x -expand false
	bind $w <Destroy> [list catch [list focus [[$myMainFrame hv3] html]]]
    }

    # Find --
    #
    #     This method is called when the "find-text" widget is summoned.
    #     Currently this can happen when the users:
    #
    #         * Presses "control-f",
    #         * Presses "/", or
    #         * Selects the "Edit->Find Text" pull-down menu command.
    #
    method Find {{initval ""}} {
	if {[winfo exists $myFindbar]} {
	    if {$initval eq ""} {
		set initval [$myFindbar value]
	    }
	    destroy $myFindbar
	}

	::hv3::findwidget $myFindbar $self

	$self packwidget $myFindbar

	# Bind up, down, next and prior key-press events to scroll the
	# main hv3 widget. This means you can use the keyboard to scroll
	# window (vertically) without shifting focus from the
	# find-as-you-type box.
	#
	set hv3 [$self hv3]
	bind $myFindbar <KeyPress-Up>    [list $hv3 yview scroll -1 units]
	bind $myFindbar <KeyPress-Down>  [list $hv3 yview scroll  1 units]
	bind $myFindbar <KeyPress-Next>  [list $hv3 yview scroll  1 pages]
	bind $myFindbar <KeyPress-Prior> [list $hv3 yview scroll -1 pages]

	# When the findwidget is destroyed, return focus to the html widget.
	bind $myFindbar <KeyPress-Escape> gui_escape

	$myFindbar value $initval
	focus $myFindbar.entry
    }

    # ProtocolGui --
    #
    #     This method is called when the "toggle-protocol-gui" control
    #     (implemented externally) is manipulated. The argument must
    #     be one of the following strings:
    #
    #       "show"            (display gui)
    #       "hide"            (hide gui)
    #       "toggle"          (display if hidden, hide if displayed)
    #
    method ProtocolGui {cmd} {
	set name ${win}.protocolgui
	set exists [winfo exists $name]

	switch -- $cmd {
	    show   {if {$exists} return}
	    hide   {if {!$exists} return}
	    toggle {
		set cmd "show"
		if {$exists} {set cmd "hide"}
	    }

	    default { error "Bad arg" }
	}

	if {$cmd eq "hide"} {
	    destroy $name
	} else {
	    $myProtocol gui $name
	    $self packwidget $name
	}
    }

    method history {} {
	return $myHistory
    }

    method reload {} {
	$myHistory reload
    }
}

# ::hv3::config
#
#     An instance of this class manages the application "View" menu, 
#     which contains all the runtime configuration options (font size, 
#     image loading etc.).
#
snit::type ::hv3::config {

    # The SQLite database containing the configuration used
    # by this application instance. 
    #
    variable myDb ""
    variable myPollActive 0

    foreach {opt def type} {
	-doublebuffer	  0			Boolean
	-enableimages	  1			Boolean
	-enablejavascript 0			Boolean
	-forcefontmetrics 1			Boolean
	-hidegui	  0			Boolean
	-zoom		  1.0			Double
	-fontscale	  1.0			Double
	-guifont	  11			Integer
	-fonttable	  {8 9 10 11 13 15 17}	SevenIntegers
    } {
	option $opt -default $def -validatemethod $type -configuremethod SetOption
    }

    constructor {db args} {
	set myDb $db
	if {$::tcl_platform(platform) eq "windows"} {
	    set options(-doublebuffer) 1
	}

	$myDb transaction {
	    set rc [catch {
		$myDb eval {
		    CREATE TABLE cfg_options1(name TEXT PRIMARY KEY, value);
		}
	    }]
	    if {$rc == 0} {
		foreach {n v} [array get options] {
		    $myDb eval {INSERT INTO cfg_options1 VALUES($n, $v)}
		} 
	    } else {
		$myDb eval {SELECT name, value FROM cfg_options1} {
		    set options($name) $value
		}
	    }
	}

	$self configurelist $args
	after 2000 [mymethod PollConfiguration]
    }

    # New code reloads the options from the external database every
    # two seconds and applies all changes.
    method PollConfiguration {} {
	set myPollActive 1
	$myDb transaction {
	    foreach n [array names options] {
		set v [$myDb one { SELECT value FROM cfg_options1 WHERE name = $n }]
		if {$options($n) ne $v} {
		    $self configure $n $v
		}
	    }
	}
	set myPollActive 0
	after 2000 [mymethod PollConfiguration]
    }

    method populate_menu {path} {
	# Add the 'Gui Font (size)' menu
	::hv3::menu ${path}.guifont
	$self PopulateRadioMenu ${path}.guifont -guifont {
	    8      "8 pts"
	    9      "9 pts"
	    10    "10 pts"
	    11    "11 pts"
	    12    "12 pts"
	    14    "14 pts"
	    16    "16 pts"
	}
	$path add cascade -label {Gui Font} -menu ${path}.guifont

	if {$::DEBUG} {
	    $self populate_hidegui_entry $path
	    $path add separator
	}

	# Add the 'Zoom' menu
	::hv3::menu ${path}.zoom
	$self PopulateRadioMenu ${path}.zoom -zoom {
	    0.25    25%
	    0.5     50%
	    0.75    75%
	    0.87    87%
	    1.0    100%
	    1.131  113%
	    1.25   125%
	    1.5    150%
	    2.0    200%
	}
	$path add cascade -label {Browser Zoom} -menu ${path}.zoom

	# Add the 'Font Scale' menu
	::hv3::menu ${path}.fontscale
	$self PopulateRadioMenu ${path}.fontscale -fontscale {
	    0.8     80%
	    0.9     90%
	    1.0    100%
	    1.2    120%
	    1.4    140%
	    2.0    200%
	}
	$path add cascade -label {Browser Font Scale} -menu ${path}.fontscale

	# Add the 'Font Size Table' menu
	set fonttable [::hv3::menu ${path}.fonttable]
	$self PopulateRadioMenu $fonttable -fonttable {
	    {7 8 9 10 12 14 16}    "Normal"
	    {8 9 10 11 13 15 17}   "Medium"
	    {9 10 11 12 14 16 18}  "Large"
	    {11 12 13 14 16 18 20} "Very Large"
	    {13 14 15 16 18 20 22} "Extra Large"
	    {15 16 17 18 20 22 24} "Recklessly Large"
	}
	$path add cascade -label {Browser Font Size Table} -menu $fonttable

	foreach {option label} {
	    -forcefontmetrics "Force CSS Font Metrics"
	    -enableimages     "Enable Images"
	    -doublebuffer     "Double-buffer"
	    --                --
	    -enablejavascript "Enable ECMAscript"
	} {
	    if {$option eq "--"} {
		$path add separator
	    } else {
		set var [myvar options($option)]
		set cmd [mymethod Reconfigure $option]
		$path add checkbutton -label $label -variable $var -command $cmd
	    }
	}
	if {[info commands ::see::interp] eq ""} {
	    $path entryconfigure end -state disabled
	}
    }

    method populate_hidegui_entry {path} {
	$path add checkbutton -label "Hide Gui" -variable [myvar options(-hidegui)]
	$path entryconfigure end -command [mymethod Reconfigure -hidegui]
    }

    method PopulateRadioMenu {path option config} {
	foreach {val label} $config {
	    $path add radiobutton \
		-variable [myvar options($option)] \
		-value $val \
		-command [mymethod Reconfigure $option] \
		-label $label
	}
    }

    method Reconfigure {option} {
	$self configure $option $options($option)
    }

    method Boolean {option value} {
	if {![string is boolean $value]} { error "Bad boolean value: $value" }
    }
    method Double {option value} {
	if {![string is double $value]} { error "Bad double value: $value" }
    }
    method Integer {option value} {
	if {![string is integer $value]} { error "Bad integer value: $value" }
    }
    method SevenIntegers {option value} {
	set len [llength $value]
	if {$len != 7} { error "Bad seven-integers value: $value" }
	foreach elem $value {
	    if {![string is integer $elem]} {
		error "Bad seven-integers value: $value"
	    }
	}
    }

    method SetOption {option value} {
	set options($option) $value
	if {$myPollActive == 0} {
	    $myDb eval {REPLACE INTO cfg_options1 VALUES($option, $value)}
	}

	variable ::hv3::G
	switch -- $option {
	    -hidegui {
		if {$value} {
		    $G(root) configure -menu ""
		    grid remove $G(statusbar)
		    grid remove $G(toolbar)
		} else {
		    $G(root) configure -menu $G(menu)
		    grid $G(statusbar)
		    grid $G(toolbar)
		}
	    }
	    -guifont {
		::hv3::SetFont [list -size $options(-guifont)]
	    }
	    default {
		$self configurebrowser [$G(notebook) current]
	    }
	}
    }

    method StoreOptions {} {
    }
    method RetrieveOptions {} {
    }

    method configurebrowser {b} {
	foreach {option var} {
	    -fonttable        options(-fonttable)
	    -fontscale        options(-fontscale)
	    -zoom             options(-zoom)
	    -forcefontmetrics options(-forcefontmetrics)
	    -enableimages     options(-enableimages)
	    -enablejavascript options(-enablejavascript)
	    -doublebuffer     options(-doublebuffer)
	} {
	    # Only browser_toplevel's know about the option -enablejavascript.
	    # This procedure may however have been called for a browser_frame
	    # widget as well. Skip the unknown option for them.

	    if {
		($option eq "-enablejavascript") &&
		([$b info type] ne "::hv3::browser_toplevel")
	    } continue

	    if {[$b cget $option] ne [set $var]} {
		$b configure $option [set $var]
	    }
	}
    }

    method configureframe {b} {
	foreach option {
	    -fonttable
	    -fontscale
	    -zoom
	    -forcefontmetrics
	    -enableimages
	    -doublebuffer
	} {
	    if {[$b cget $option] ne $options($option)} {
		$b configure $option $options($option)
	    }
	}
    }

    destructor {
	after cancel [mymethod PollConfiguration]
    }
}

snit::type ::hv3::file_menu {
    variable MENU

    constructor {} {
	variable ::hv3::G
	set MENU [list]
	lappend MENU \
	    "Open File..."  [list gui_openfile $G(notebook) $G(help)] o
	if {$::DEBUG} {
	    lappend MENU \
		"Open Tab"      [list $G(notebook) add]                 t  \
		"Open Location" [list gui_openlocation $G(addressbar)]  l  \
		"-----"         ""                                      "" \
		"Bookmark Page" [list ::hv3::gui_bookmark]              b  \
		"-----"         ""                                      "" \
		"Downloads"     [list ::hv3::the_download_manager show] "" \
		"-----"         ""                                      "" \
		"Close Tab"     [list $G(notebook) close]               ""
	}
	lappend MENU \
	    "-----"         ""                                        "" \
	    "Exit"          exit                                      q
    }

    method populate_menu {path} {
	$path delete 0 end

	foreach {label command key} $MENU {
	    if {[string match ---* $label]} {
		$path add separator
		continue
	    }
	    $path add command -label $label -command $command 
	    if {$key ne ""} {
		set acc "(Ctrl-[string toupper $key])"
		$path entryconfigure end -accelerator $acc
	    }
	}
	if {$::DEBUG} {
	    if {[llength [$::hv3::G(notebook) tabs]] < 2} {
		$path entryconfigure "Close Tab" -state disabled
	    }
	}
    }

    method setup_hotkeys {} {
	foreach {label command key} $MENU {
	    if {$key ne ""} {
		set uc [string toupper $key]
		bind Hv3HotKeys <Control-$key> $command
		bind Hv3HotKeys <Control-$uc> $command
	    }
	}
    }
}

proc ::hv3::gui_bookmark {} {
    set uri  [[gui_current hv3] uri get]
    set name [[gui_current hv3] title]
    if {$name eq ""} {set name $uri}
    ::hv3::the_bookmark_manager add $name $uri

    set msg "Bookmarked Page"
    set i [tk_dialog .alert "Bookmarked!" $msg "" 0 Continue {Go to Bookmarks}]
    if {$i} {
	[gui_current hv3] goto home://bookmarks/
    }
}

snit::type ::hv3::debug_menu {

    variable MENU

    constructor {} {
	set MENU [list]
	lappend MENU \
	    "Cookies"       [list $::hv3::G(notebook) add cookies:]   "" \
	    "About"         [list $::hv3::G(notebook) add home://about]     "" \
	    "Polipo..."     ::hv3::polipo::popup                      "" \
	    "Events..."     [list gui_log_window $::hv3::G(notebook)] "" \
	    "-----"         ""                                        "" \
	    "Tree Browser..." [list gui_current browse]               "" \
	    "Javascript Debugger..." [list gui_current javascriptlog]           j  \
	    "DOM Reference..."     [list $::hv3::G(notebook) add home://domref] "" \
	    "-----"         ""                                        "" \
	    "Exec firefox -remote" gui_firefox_remote                      ""

	#No profiling in ashv
	#      "-----"                   ""                                 ""
	#      "Reset Profiling Data..." ::hv3::profile::zero               ""
	#      "Save Profiling Data..."  ::hv3::profile::report_to_file     ""
    }

    method populate_menu {path} {
	$path delete 0 end
	foreach {label command key} $MENU {
	    if {[string match ---* $label]} {
		$path add separator
		continue
	    }
	    $path add command -label $label -command $command 
	    if {$key ne ""} {
		set acc "(Ctrl-[string toupper $key])"
		$path entryconfigure end -accelerator $acc
	    }
	}
	# No profiling (menu entries) in ashv
	if {0 && (0 == [hv3::profile::enabled])} {
	    $path entryconfigure end -state disabled
	    $path entryconfigure [expr [$path index end] - 1] -state disabled
	}
    }

    method setup_hotkeys {} {
	foreach {label command key} $MENU {
	    if {$key ne ""} {
		set uc [string toupper $key]
		bind Hv3HotKeys <Control-$key> $command
		bind Hv3HotKeys <Control-$uc> $command
	    }
	}
    }
}


#--------------------------------------------------------------------------
# The following functions are all called during startup to construct the
# static components of the web browser gui:
#
#     gui_build
#     gui_menu
#       gui_load_tkcon
#       create_fontsize_menu
#       create_fontscale_menu
#

# gui_build --
#
#     This procedure is called once at the start of the script to build
#     the GUI used by the application. It creates all the widgets for
#     the main window. 
#
#     The argument is the name of an array variable in the parent context
#     into which widget names are written, according to the following 
#     table:
#
#         Array Key            Widget
#     ------------------------------------------------------------
#         stop_button          The "stop" button
#         back_button          The "back" button
#         forward_button       The "forward" button
#         addressbar           The location bar
#         notebook             The ::hv3::notebook instance
#         status_label         The label used for a status bar
#         history_menu         The pulldown menu used for history
#
proc gui_build {root widget_array} {
    upvar $widget_array G
    global HTML
    set base [string trimright $root .]
    set G(root) $root
    set G(base) $base

    # Create the top bit of the GUI - the URI entry and buttons.
    set tbar [widget::toolbar $base.toolbar -separator bottom]
    set tf [$tbar getframe]

    foreach {btn label img tip} {
	back_button    "Back"    left    "Go Back"
	forward_button "Forward" right   "Go Forward"
	home_button    "Home"    home    "Go Home"
    } {
	set G($btn) [ttk::button $tf.$btn -style Toolbutton \
			 -text $label -image ::hv3::img::$img]
	tooltip $G($btn) $tip
	$tbar add $G($btn)
    }
    #stop_button    "Stop"    stop    "Stop"
    #reload_button  "Reload"  refresh "Refresh Page"

    # No tabbing in the help browser
    #new "New Tab" "Open New Tab" "new" {-command [list $G(notebook) add]}
    #$G(reload_button) configure -command {gui_current reload}

    $G(home_button) configure -command [list gui_current goto $::hv3::homeuri]

    # Changed from Url Entry to Search Entry
    # Defined in hv3_history.tcl
    set G(addressbar) [hv3::addressbar [$tbar getframe].address]
    if {$::DEBUG} {
	$tbar add $G(addressbar) -sticky ew -weight 1
    } else {
	$tbar add space
    }
    # for now it is read-only
    #$G(addressbar) configure -state readonly

    set e [::hv3::searchentry [$tbar getframe].search -width 16 \
	       -command { search_location [$::hv3::G(notebook) current] }]
    set G(searchentry) $e
    $tbar add $G(searchentry) -sticky ew -separator 1 -pad [list 4 0]

    # NEW: Table of Contents (tree) and Search Results (list).
    package require hv3::astoc

    set pw [ttk::panedwindow $base.pw -orient horizontal]

    # Left-side tabbed notebook
    set nb [ttk::notebook $pw.help]

    # Search Results
    set sw [widget::scrolledwindow $nb.sw -relief sunken -borderwidth 1]
    set lb [listbox $sw.res -selectmode single -highlightthickness 0 \
	       -borderwidth 0]
    $sw setwidget $lb
    bind $sw.res <<ListboxSelect>> [list ShowFTSLink $lb]
    set G(search_box) $lb

    # Table of Contents
    set toc [hv3::astoc $nb.toc -width 200]

    $nb add $toc -sticky nswe -text "Contents"
    $nb add $sw  -sticky nswe -text "Search Results"

    # Create the middle bit - the browser window
    #
    set browsernb [::hv3::notebook $pw.notebook \
		       -newcommand    gui_new \
		       -switchcommand gui_switch]

    $pw add $nb
    $pw add $browsernb -weight 1

    # And the bottom bit - the status bar
    set sbar [widget::statusbar $base.sbar]
    set sf   [$sbar getframe]
    set status [ttk::label $sf.status -anchor w -width 1]
    $sbar add $status -weight 1
    bind $status <1> [list gui_current ProtocolGui toggle]
    bind $status <3> [list gui_toggle_status $widget_array]

    # Set the widget-array variables
    set G(statusbar)	$sbar
    set G(toolbar)	$tbar
    set G(help)		$nb
    set G(notebook)	$browsernb
    set G(status_label)	$status
    set G(status_mode)	"browser"

    # Pack the top, bottom and middle, in that order. The middle must be 
    # packed last, as it is the bit we want to shrink if the size of the 
    # main window is reduced.
    grid $tbar -sticky ew
    grid $pw -sticky news
    grid $sbar -sticky ew
    grid columnconfigure $root 0 -weight 1
    grid rowconfigure $root 1 -weight 1 -minsize 50
}

proc search_location {browser {location {}}} {
    # Search the loaded help files for the phrase and fill the listbox
    # with the resulting set of links.
    if {$location eq ""} {
	set location [$::hv3::G(searchentry) get]
    }

    if {[catch {set results [hv3::ashelp_search $location]}]} {
	$browser ghelp.sw.resoto {ashelp:///sys/error}
	return
    }

    # Put search results into display data structures
    # Currently global, just a hack
    global SR SL
    array unset SR *
    array set   SR {}
    set SL {}

    $::hv3::G(search_box) configure -listvariable SL
    foreach {link title} $results {
	set SR([llength $SL]) $link
	lappend SL $title
    }

    # Bring list of search result to front.
    $::hv3::G(help) select [winfo parent $::hv3::G(search_box)]
    return
}

proc goto_gui_location {browser} {
    set location [$::hv3::G(addressbar) get]

    if {[string match *:/* $location] || [string match *: $location]} {
	# A fully qualified URI. Have the browser load & display it.
	$browser goto $location
	return
    }

    search_location $browser $location
}

proc ShowFTSLink {help} {

    set sel [$help curselection]
    if {![llength $sel]} return
    set id [lindex $sel 0]
    global SL SR
    set link $SR($id)

    gui_current goto $link
    return
}

# A helper function for gui_menu.
#
# This procedure attempts to load the tkcon package. An error is raised
# if the package cannot be loaded. On success, an empty string is returned.
#
proc gui_load_tkcon {} {
    foreach f [list \
		   [file join $::tcl_library .. .. bin tkcon] \
		   [file join $::tcl_library .. .. bin tkcon.tcl]
	      ] {
	if {[file exists $f]} {
	    uplevel #0 "source $f"
	    package require tkcon
	    return
	}
    }
    error "Failed to load Tkcon"
    return ""
}

proc gui_openlocation {addressbar} {
    $addressbar selection range 0 end
    focus $addressbar
}

proc gui_populate_menu {eMenu menu_widget} {
    switch -- [string tolower $eMenu] {
	file {
	    set cmd [list $::hv3::G(file_menu) populate_menu $menu_widget]
	    $menu_widget configure -postcommand $cmd
	}

	search {
	    $::hv3::G(search) populate_menu $menu_widget
	}

	options {
	    $::hv3::G(config) populate_menu $menu_widget
	}

	debug {
	    $::hv3::G(debug_menu) populate_menu $menu_widget
	}

	history {
	    set cmd [list gui_current populate_history_menu $menu_widget]
	    $menu_widget configure -postcommand $cmd
	}

	default {
	    error "gui_populate_menu: No such menu: $eMenu"
	}
    }
}

proc gui_menu {root widget_array} {
    upvar $widget_array G
    set base [string trimright $root .]

    # Attach a menu widget to the toplevel application window.
    set menu [::hv3::menu $base.m]
    $root config -menu $menu
    set G(menu) $menu

    set G(file_menu)  [::hv3::file_menu %AUTO%]
    set G(debug_menu) [::hv3::debug_menu %AUTO%]
    set G(search)     [::hv3::search %AUTO%]
    set G(config)     [::hv3::config %AUTO% ::hv3::sqlitedb]

    # Add the "File", "Search" and "View" menus.
    set menus [list File Options History]
    if {$::DEBUG} {
	set menus [list File Search Options Debug History]
    }
    foreach m $menus {
	set submenu $menu.[string tolower $m]
	gui_populate_menu $m [::hv3::menu $submenu]
	$menu add cascade -label $m -menu $submenu -underline 0
    }

    $G(file_menu) setup_hotkeys
    $G(debug_menu) setup_hotkeys
}
#--------------------------------------------------------------------------

proc gui_current {args} {
    eval [linsert $args 0 [$::hv3::G(notebook) current]]
}

proc gui_firefox_remote {} {
    set url [$::hv3::G(addressbar) get]
    exec firefox -remote "openurl($url,new-tab)" &
}

proc gui_switch {new} {
    upvar #0 ::hv3::G G

    # Loop through *all* tabs and detach them from the history
    # related controls. This is so that when the state of a background
    # tab is updated, the history menu is not updated (only the data
    # structures in the corresponding ::hv3::history object).
    #
    foreach browser [$G(notebook) tabs] {
	$browser configure -backbutton    ""
	$browser configure -stopbutton    ""
	$browser configure -forwardbutton ""
	$browser configure -addressbar    ""
    }

    # Configure the new current tab to control the history controls.
    #
    set new [$G(notebook) current]
    $new configure -backbutton    $G(back_button)
    #$new configure -stopbutton    $G(stop_button)
    $new configure -forwardbutton $G(forward_button)
    $new configure -addressbar    $G(addressbar)

    # Attach some other GUI elements to the new current tab.
    #
    set gotocmd [list goto_gui_location $new]
    $G(addressbar) configure -command $gotocmd
    if {$G(status_mode) eq "browser"} {
	$G(status_label) configure -textvar [$new statusvar]
    }

    # Configure the new current tab with the contents of the drop-down
    # config menu (i.e. font-size, are images enabled etc.).
    #
    $G(config) configurebrowser $new

    # Set the top-level window title to the title of the new current tab.
    #
    wm title $G(root) [$G(notebook) title $new]

    # Focus on the root HTML widget of the new tab.
    #
    focus [[$new hv3] html]
}

proc gui_new {path args} {
    set new [::hv3::browser_toplevel $path]
    $::hv3::G(config) configurebrowser $new

    set var [$new titlevar]
    trace add variable $var write [list gui_settitle $new $var]

    set var [$new locationvar]
    trace add variable $var write [list gui_settitle $new $var]

    if {[llength $args] == 0} {
	$new goto $::hv3::homeuri
    } else {
	$new goto [lindex $args 0]
    }

    # This black magic is required to initialise the history system.
    # A <<Location>> event will be generated from within the [$new goto]
    # command above, but the history system won't see it, because 
    # events are not generated until the window is mapped. So generate
    # an extra <<Location>> when the window is mapped.
    #
    bind [$new hv3] <Map>  [list event generate [$new hv3] <<Location>>]
    bind [$new hv3] <Map> +[list bind <Map> [$new hv3] ""]

    # [[$new hv3] html] configure -logcmd print

    return $new
}

proc gui_settitle {browser varname args} {
    variable ::hv3::G
    if {[$G(notebook) current] eq $browser} {
	wm title $G(root) [set $varname]
    }
    $G(notebook) title $browser [set $varname]
}

# This procedure is invoked when the user selects the File->Open menu
# option. It launches the standard Tcl file-selector GUI. If the user
# selects a file, then the corresponding URI is passed to [.hv3 goto]
#
proc gui_openfile {notebook help} {
    set browser [$notebook current]
    set f [tk_getOpenFile -filetypes {
	{{ASHELP Files} {.ash}}
	{{All Files} *}
    }]
    if {$f != ""} {
	if {$::tcl_platform(platform) eq "windows"} {
	    set f [string map {: {}} $f]
	}

	# Replace current session.
	# - Kill history

	hv3::ashelp_drop
	set ::hv3::homeuri [hv3::ashelp [list $f]]

	$help.toc Fill

	# FUTURE: Allow merge.

	$browser goto $::hv3::homeuri
    }
}

proc gui_log_window {notebook} {
    set browser [$notebook current]
    ::hv3::log_window [[$browser hv3] html]
}

proc gui_escape {} {
    upvar ::hv3::G G
    gui_current escape
    $G(addressbar) escape
    focus [[gui_current hv3] html]
}
bind Hv3HotKeys <KeyPress-Escape> gui_escape

proc gui_toggle_status {widget_array} {
    upvar $widget_array G
    if {$G(status_mode) eq "browser"} {
	set G(status_mode) "memory"
	$G(status_label) configure -textvar ""
	gui_set_memstatus $widget_array
    } else {
	set G(status_mode) "browser"
	$G(status_label) configure -textvar [gui_current statusvar]
    }
}

proc gui_set_memstatus {widget_array} {
    upvar $widget_array G
    if {$G(status_mode) eq "memory"} {
	set status "Script:   "
	append status "[::count_vars] vars, [::count_commands] commands,"
	append status "[::count_namespaces] namespaces"

	catch {
	    array set v [::see::alloc]
	    set nHeap [expr {int($v(GC_get_heap_size) / 1000)}]
	    set nFree [expr {int($v(GC_get_free_bytes) / 1000)}]
	    set nDom $v(SeeTclObject)
	    append status "          GC Heap: ${nHeap}K (${nFree}K free) ($v(SeeTclObject) DOM objects)"
	}
	catch {
	    foreach line [split [memory info] "\n"] {
		if {[string match {current packets allocated*} $line]} {
		    set nAllocs [lindex $line end]
		}
		if {[string match {current bytes allocated*} $line]} {
		    set nBytes [lindex $line end]
		}
	    }
	    set nBytes "[expr {int($nBytes / 1000)}]K"
	    append status "          Tcl Heap: ${nBytes} in $nAllocs allocs"
	}

	$G(status_label) configure -text $status
	after 2000 [list gui_set_memstatus $widget_array]
    }
}

# Override the [exit] command to check if the widget code leaked memory
# or not before exiting.
#
rename exit tcl_exit
proc exit {args} {
    destroy $::hv3::G(notebook)
    catch {destroy .prop.hv3}
    catch {::tkhtml::htmlalloc}
    eval [concat tcl_exit $args]
}

proc JS {args} {
    set script [join $args " "]
    [[gui_current hv3] dom] javascript $script
}

#--------------------------------------------------------------------------
# main URI
#
#     The main() program for the application. This proc handles
#     parsing of command line arguments.
#
proc main {args} {

    set docs [list]

    for {set ii 0} {$ii < [llength $args]} {incr ii} {
	set val [lindex $args $ii]
	switch -glob -- $val {
	    -d* {
		set ::env(HV3_DEBUG) 1
	    }
	    -s* {                  # -statefile <file-name>
		if {$ii == [llength $args] - 1} ::hv3::usage
		incr ii
		set ::hv3::statefile [lindex $args $ii]
	    }
	    -profile { 
		# Ignore this here. If the -profile option is present it will 
		# have been handled already.
	    }
	    default {
		lappend docs $val
	    }
	}
    }
    if {[info exists ::env(HV3_DEBUG)]
	&& [string is true $::env(HV3_DEBUG)]} {
	set ::DEBUG 1
    }

    if {![llength $docs]} {
	puts stderr "No help file specified, required"
	exit 1
    }

    ::hv3::dbinit

    package require hv3::ashelp
    set ::hv3::homeuri [hv3::ashelp $docs]
    set docs $::hv3::homeuri

    # Build the GUI
    set root .
    gui_build $root ::hv3::G
    gui_menu  $root ::hv3::G

    ::hv3::downloadmanager ::hv3::the_download_manager

    # After the event loop has run to create the GUI, run [main2]
    # to load the startup document. It's better if the GUI is created first,
    # because otherwise if an error occurs Tcl deems it to be fatal.
    after idle [list main2 $docs]
}
proc main2 {docs} {
    if {![llength $docs]} return
    foreach doc $docs {
	set tab [$::hv3::G(notebook) add $doc]
    }
    focus $tab
}
proc ::hv3::usage {} {
    puts stderr "Usage:"
    puts stderr "    $::argv0 ?-statefile <file-name>? <helpfile>..."
    puts stderr ""
    tcl_exit
}

set ::hv3::statefile ":memory:"

# Remote scaling interface:
proc hv3_zoom      {newval} { $::hv3::G(config) set_zoom $newval }
proc hv3_fontscale {newval} { $::hv3::G(config) set_fontscale $newval }
proc hv3_forcewidth {forcewidth width} {
    [[gui_current hv3] html] configure -forcewidth $forcewidth -width $width
}

proc hv3_guifont {newval} { $::hv3::G(config) set_guifont $newval }

proc hv3_html {args} {
    set html [[gui_current hv3] html]
    eval [concat $html $args]
}

# Set variable $::hv3::maindir to the directory containing the
# application files. Then run the [main] command with the command line
# arguments passed to the application.
set ::hv3::maindir $::DIR
eval [concat main $::argv]

proc print {args} { puts [join $args] }

#--------------------------------------------------------------------------
