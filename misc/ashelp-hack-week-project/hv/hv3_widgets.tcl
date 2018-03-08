# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_widgets.tcl,v 1.41 2007/04/11 17:37:53 danielk1977 Exp $)} 1 }

package require snit
package require Tk

if {[package vsatisfies [package present Tk] 8.5]} {
    # Ttk 8.5+
    interp alias {} style {} ttk::style
    ttk::style configure Slim.Toolbutton -padding 1
} else {
    # Tk 8.4, tile is separate
    style default Slim.Toolbutton -padding 1
}

#-------------------------------------------------------------------
# Font control:
#
#     Most of the ::hv3::** widgets use the named font 
#     "Hv3DefaultFont". The following two procs, [::hv3::UseHv3Font]
#     and [::hv3::SetFont] deal with configuring the widgets and
#     dynamically modifying the font when required.
#
proc ::hv3::UseHv3Font {widget} {
    $widget configure -font Hv3DefaultFont
}
proc ::hv3::SetFont {font} {
    catch {font delete Hv3DefaultFont}
    eval [linsert $font 0 font create Hv3DefaultFont]

    # WARNING: Horrible, horrible action at a distance...
    catch {.notebook.notebook Redraw}
}
::hv3::SetFont {-size 10}

# Basic wrapper widget-names used to abstract Tk and Tile:

if {[tk windowingsystem] ne "aqua"} {
    interp alias {} ::scrollbar {} ::ttk::scrollbar
}
interp alias {} ::hv3::button {} ::ttk::button

proc ::hv3::text {w args} {
    set w [eval [linsert $args 0 ::text $w -highlightthickness 0]]
    return $w
}

# List of menu widgets used by ::hv3::menu and ::hv3::menu_color
#
set ::hv3::menu_list  [list]
set ::hv3::menu_style [list]

proc ::hv3::menu {w args} {
    set w [eval [linsert $args 0 ::menu $w \
		    -borderwidth 1 -tearoff 0 -font TkDefaultFont]]
    lappend ::hv3::menu_list $w
    return $w
}

proc ::hv3::menu_color {} {
    set fg  [style lookup Toolbutton -foreground]
    set afg [style lookup Toolbutton -foreground active]
    set bg  [style lookup Toolbutton -background]
    set abg [style lookup Toolbutton -background active]

    foreach w $::hv3::menu_list {
	catch {
	    $w configure -fg $fg -bg $bg -activebackground $abg -activeforeground $afg
	}
    }
}

#---------------------------------------------------------------------------
# ::hv3::scrolledwidget
#
#     Widget to add automatic scrollbars to a widget supporting the
#     [xview], [yview], -xscrollcommand and -yscrollcommand interface (e.g.
#     html, canvas or text).
#
snit::widget ::hv3::scrolledwidget {
    hulltype ttk::frame

    component myWidget
    variable  myVsb
    variable  myHsb

    option -propagate -default 0 -configuremethod set_propagate
    option -scrollbarpolicy -default auto
    option -takefocus -default 0

    method set_propagate {option value} {
	grid propagate $win $value
	set options(-propagate) $value
    }

    constructor {widget args} {
	# Create the three widgets - one user widget and two scrollbars.
	set myWidget [eval [linsert $widget 1 ${win}.widget]]

	set myVsb [scrollbar ${win}.vsb -orient vertical]
	set myHsb [scrollbar ${win}.hsb -orient horizontal]

	$myVsb configure -cursor "top_left_arrow"
	$myHsb configure -cursor "top_left_arrow"

	grid configure $myWidget -column 0 -row 0 -sticky nsew
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1
	grid propagate       $win $options(-propagate)

	# First, set the values of -width and -height to the defaults for
	# the scrolled widget class. Then configure this widget with the
	# arguments provided.
	$self configure -width  [$myWidget cget -width]
	$self configure -height [$myWidget cget -height]
	$self configurelist $args

	# Wire up the scrollbars using the standard Tk idiom.
	$myWidget configure -yscrollcommand [mymethod scrollcallback $myVsb]
	$myWidget configure -xscrollcommand [mymethod scrollcallback $myHsb]
	$myVsb    configure -command        [mymethod yview]
	$myHsb    configure -command        [mymethod xview]

	# Propagate events from the scrolled widget to this one.
	bindtags $myWidget [concat [bindtags $myWidget] $win]
    }

    method scrollcallback {scrollbar first last} {
	$scrollbar set $first $last
	set ismapped   [expr [winfo ismapped $scrollbar] ? 1 : 0]

	if {$options(-scrollbarpolicy) eq "auto"} {
	    set isrequired [expr ($first == 0.0 && $last == 1.0) ? 0 : 1]
	} else {
	    set isrequired $options(-scrollbarpolicy)
	}

	if {$isrequired && !$ismapped} {
	    switch [$scrollbar cget -orient] {
		vertical   {grid configure $scrollbar  -column 1 -row 0 -sticky ns}
		horizontal {grid configure $scrollbar  -column 0 -row 1 -sticky ew}
	    }
	} elseif {$ismapped && !$isrequired} {
	    grid forget $scrollbar
	}
    }

    method widget {} {return $myWidget}

    delegate option -width  to hull
    delegate option -height to hull
    delegate option *       to myWidget
    delegate method *       to myWidget
}

# Wrapper around the ::hv3::scrolledwidget constructor. 
#
# Example usage to create a 400x400 canvas widget named ".c" with 
# automatic scrollbars:
#
#     ::hv3::scrolled canvas .c -width 400 -height 400
#
proc ::hv3::scrolled {widget name args} {
    uplevel 1 [linsert $args 0 ::hv3::scrolledwidget $name $widget]
}
#
# End of "scrolled" implementation
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
# ::hv3::notebook
#
#     Tabbed notebook widget for hv3 based on ttk::notebook.
#
# OPTIONS
#
#     -newcommand
#     -switchcommand
#
# WIDGET COMMAND
#
#     $notebook add ARGS
#     $notebook addbg ARGS
#     $notebook close
#     $notebook current
#     $notebook title WIDGET ?TITLE?
#     $notebook tabs
#
snit::widgetadaptor ::hv3::notebook {
    variable myNextId 0
    variable myPendingTitle ""

    variable myOnlyTab ""
    variable myOnlyTitle ""

    component closebox

    delegate option * to hull
    delegate method * to hull

    option -newcommand    -default ""
    option -switchcommand -default ""

    constructor {args} {
	installhull using ttk::notebook -width 600 -height 500

	install closebox using ttk::button $win.close -style Slim.Toolbutton \
	    -image ::hv3::img::delete -command [mymethod close]

	bind $win <<NotebookTabChanged>> [mymethod Switchcmd]

	$self configurelist $args
    }

    method Switchcmd {} {
	if {[llength $options(-switchcommand)]} {
	    eval [linsert $options(-switchcommand) end [$self current]]
	    $self WorldChanged
	}
    }

    method WorldChanged {} {
	set dummy $win.dummy

	set nTab [llength [$hull tabs]]
	if {$myOnlyTab ne ""} { incr nTab }

	if {[lsearch -exact [$hull tabs] $dummy] >= 0} {
	    incr nTab -1
	}

	if {$nTab > 1} {
	    if {$myOnlyTab ne ""} {
		place forget $myOnlyTab
		$hull add $myOnlyTab -sticky ewns -text $myOnlyTitle
		catch { $hull forget $dummy }
		set myOnlyTab ""
		set myOnlyTitle ""

		set tab1 [lindex [$hull tabs] 0]
		set text1 [$hull tab $tab1 -text]
		$hull forget $tab1
		$hull add $tab1 -text $text1
		place $closebox -anchor ne -relx 1 -rely 0
		raise $closebox
	    }
	} else {
	    if {$myOnlyTab eq ""} {
		set myOnlyTab [$self current]

		catch {
		    canvas $dummy -width 0 -height 0 -bg blue
		    $hull add $dummy -state hidden
		}

		catch {place forget $closebox}
		set myOnlyTitle [$hull tab $myOnlyTab -text]
		$hull forget $myOnlyTab
		raise $myOnlyTab
		place $myOnlyTab -relheight 1.0 -relwidth 1.0
	    }
	}
    }

    method close {} {
	if {$myOnlyTab eq ""} {
	    destroy [$self current]
	}
    }

    method Addcommon {switchto args} {
	set widget $win.tab_[incr myNextId]

	set myPendingTitle ""
	uplevel 1 [linsert $args 0 $options(-newcommand) $widget]
	$hull add $widget -sticky ewns -text "Blank" \
	    -image ::hv3::img::close -compound right
	if {$myPendingTitle ne ""} {$self title $widget $myPendingTitle}

	if {$switchto} {
	    $hull select $widget
	    $self Switchcmd
	    catch {$hull select $widget}
	} else {
	    $self WorldChanged
	}

	return $widget
    }

    method addbg {args} {
	uplevel 1 [linsert $args 0 $self Addcommon 0]
    }

    method add {args} {
	uplevel 1 [linsert $args 0 $self Addcommon 1]
    }

    method title {widget {title {_DEFAULT_}}} {
	if {$title ne "_DEFAULT_"} {
	    # set new title
	    if {$widget eq $myOnlyTab} {
		set myOnlyTitle $title
	    } elseif {[catch {$hull tab $widget -text $title}]} {
		set myPendingTitle $title
	    }
	}
	if {$widget eq $myOnlyTab} {
	    set title $myOnlyTitle
	} elseif {[catch {set title [$hull tab $widget -text]}]} {
	    set title $myPendingTitle
	}
	return $title
    }

    method current {} {
	if {$myOnlyTab ne ""} {return $myOnlyTab}

	if {![catch {$hull select} current]} {
	    return $current
	}
	return [lindex [$hull tabs] [$hull index current]]
    }

    method tabs {} {
	if {$myOnlyTab ne ""} {return $myOnlyTab}
	return [$hull tabs]
    }
}
# End of notebook implementation.
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# ::hv3::walkTree
# 
#     This proc is used for depth first traversal of the document tree 
#     headed by the argument node. 
#
#     Example:
#
#         ::hv3::walkTree [.html node] N {
#           puts "Type of node: [$N tag]"
#         }
#
#     If the body of the loop executes a [continue], then the current iteration
#     is terminated and the body is not executed for any of the current nodes
#     children. i.e. [continue] prevents descent of the tree.
#
proc ::hv3::walkTree {N varname body} {
    set level "#[expr [info level] - 1]"
    ::hv3::walkTree2 $N $body $varname $level
}
proc ::hv3::walkTree2 {N body varname level} {
    uplevel $level [list set $varname $N]
    set rc [catch {uplevel $level $body} msg] 
    switch $rc {
	0 {           ;# OK
	    foreach n [$N children] {
		::hv3::walkTree2 $n $body $varname $level
	    }
	}
	1 {           ;# ERROR
	    error $msg
	}
	2 {           ;# RETURN
	    return $msg
	}
	3 {           ;# BREAK
	    error "break from within ::hv3::walkTree"
	}
	4 {           ;# CONTINUE
	    # Do nothing. Do not descend the tree.
	}
    }
}
#---------------------------------------------------------------------------

#---------------------------------------------------------------------------
# ::hv3::resolve_uri
#
proc ::hv3::resolve_uri {base relative} {
    set obj [::hv3::uri %AUTO% $base]
    $obj load $relative
    set ret [$obj get]
    $obj destroy
    return $ret
}
#---------------------------------------------------------------------------

proc ::hv3::ComparePositionId {frame1 frame2} {
    return [string compare [$frame1 positionid] [$frame2 positionid]]
}

#-------------------------------------------------------------------------
# ::hv3::findwidget
#
#     This snit widget encapsulates the "Find in page..." functionality.
#
#     Two tags may be added to the html widget(s):
#
#         findwidget                      (all search hits)
#         findwidgetcurrent               (the current search hit)
#
#
snit::widget ::hv3::findwidget {
    hulltype ttk::frame

    component entry

    variable myBrowser          ;# The ::hv3::browser_toplevel widget

    variable myNocaseVar 1      ;# Variable for the "Case insensitive" checkbox
    variable myCaptionVar ""    ;# Variable for the label widget

    variable myCurrentHit -1
    variable myCurrentList ""

    delegate option -borderwidth to hull
    delegate option -relief      to hull

    constructor {browser args} {
	set myBrowser $browser

	ttk::label $win.label -text "Quick find:"
	install entry using ttk::entry $win.entry -width 30 -validate key \
	    -validatecommand "[mymethod EventuallyUpdate]; return 1"
	ttk::label $win.num_results -textvariable [myvar myCaptionVar] \
	    -anchor e

	ttk::checkbutton $win.case -variable [myvar myNocaseVar] \
	    -text "Case Insensitive" -command [mymethod DynamicUpdate]

	ttk::button $win.close -text "Dismiss" -command [list destroy $win] \
	    -image ::hv3::img::delete -style Slim.Toolbutton

	bind $entry <Return>       [mymethod Return 1]
	bind $entry <Shift-Return> [mymethod Return -1]
	focus $entry

	# Propagate events that occur in the entry widget to the
	# ::hv3::findwidget widget itself. This allows the calling script
	# to bind events without knowing the internal mega-widget structure.
	# For example, the hv3 app binds the <Escape> key to delete the
	# findwidget widget.
	#
	bindtags $entry [concat [bindtags $entry] $win]

	grid $win.label $win.entry $win.case $win.num_results $win.close \
	    -sticky ew
	grid columnconfigure $win 3 -weight 1 ; # $win.num_results

	$self configurelist $args
    }

    method Hv3List {} {
	if {[catch {$myBrowser get_frames} msg]} {
	    return $myBrowser
	} else {
	    set frames [$myBrowser get_frames]
	}

	# Filter the $frames list to exclude frameset documents.
	set frames2 ""
	foreach f $frames {
	    if {![$f isframeset]} {
		lappend frames2 $f
	    }
	}

	# Sort the frames list in [positionid] order
	set frames3 [lsort -command ::hv3::ComparePositionId $frames2]

	set ret [list]
	foreach f $frames3 {
	    lappend ret [$f hv3]
	}
	return $ret
    }

    method lazymoveto {hv3 n1 i1 n2 i2} {
	set nodebbox [$hv3 text bbox $n1 $i1 $n2 $i2]
	set docbbox  [$hv3 bbox]

	set docheight [expr {double([lindex $docbbox 3])}]

	set ntop    [expr {([lindex $nodebbox 1] - 30.0) / $docheight}]
	set nbottom [expr {([lindex $nodebbox 3] + 30.0) / $docheight}]

	set sheight [expr {[winfo height $hv3] / $docheight}]
	set stop    [lindex [$hv3 yview] 0]
	set sbottom [expr {$stop + $sheight}]

	if {$ntop < $stop} {
	    $hv3 yview moveto $ntop
	} elseif {$nbottom > $sbottom} {
	    $hv3 yview moveto [expr {$nbottom - $sheight}]
	}
    }

    method value {{newval {__DEFAULT__}}} {
	if {$newval ne "__DEFAULT__"} {
	    $entry delete 0 end ; $entry insert 0 $newval
	}
	return [$entry get]
    }

    # Dynamic update proc.
    method UpdateDisplay {nMaxHighlight} {

	set nMatch 0      ;# Total number of matches
	set nHighlight 0  ;# Total number of highlighted matches
	set matches [list]

	# Get the list of hv3 widgets that (currently) make up this browser
	# display. There is usually only 1, but may be more in the case of
	# frameset documents.
	#
	set hv3list [$self Hv3List]

	# Delete any instances of our two tags - "findwidget" and
	# "findwidgetcurrent". Clear the caption.
	#
	foreach hv3 $hv3list {
	    $hv3 tag delete findwidget
	    $hv3 tag delete findwidgetcurrent
	}
	set myCaptionVar ""

	# Figure out what we're looking for. If there is nothing entered 
	# in the entry field, return early.
	set searchtext [$entry get]
	if {$myNocaseVar} {
	    set searchtext [string tolower $searchtext]
	}
	if {[string length $searchtext] == 0} return

	foreach hv3 $hv3list {
	    set doctext [$hv3 text text]
	    if {$myNocaseVar} {
		set doctext [string tolower $doctext]
	    }

	    set iFin 0
	    set lMatch [list]
	    set stlen [string length $searchtext]

	    while {[set iStart [string first $searchtext $doctext $iFin]] >= 0} {
		set iFin [expr {$iStart + $stlen}]
		lappend lMatch $iStart $iFin
		incr nMatch
		if {$nMatch == $nMaxHighlight} { set nMatch "many" ; break }
	    }

	    set lMatch [lrange $lMatch 0 [expr {($nMaxHighlight - $nHighlight)*2 - 1}]]
	    incr nHighlight [expr {[llength $lMatch] / 2}]
	    if {[llength $lMatch]} {
		lappend matches $hv3 [eval [concat $hv3 text index $lMatch]]
	    }
	}

	set myCaptionVar "(highlighted $nHighlight of $nMatch hits)"

	foreach {hv3 matchlist} $matches {
	    foreach {n1 i1 n2 i2} $matchlist {
		$hv3 tag add findwidget $n1 $i1 $n2 $i2
	    }
	    $hv3 tag configure findwidget -bg purple -fg white
	    $self lazymoveto $hv3 \
		[lindex $matchlist 0] [lindex $matchlist 1] \
		[lindex $matchlist 2] [lindex $matchlist 3]
	}

	set myCurrentList $matches
    }

    variable pending -array {update {} delay 350}
    method EventuallyUpdate {} {
	after cancel $pending(update)
	set $pending(update) [after $pending(delay) [mymethod DynamicUpdate]]
    }

    method DynamicUpdate {{maxhits 42}} {
	after cancel $pending(update)
	set myCurrentHit -1
	$self UpdateDisplay $maxhits
    }

    method Escape {} {
	# destroy $win
    }
    method Return {dir} {
	set previousHit $myCurrentHit
	if {$myCurrentHit < 0} {
	    $self UpdateDisplay 100000
	}
	incr myCurrentHit $dir

	set nTotalHit 0
	foreach {hv3 matchlist} $myCurrentList {
	    incr nTotalHit [expr {[llength $matchlist] / 4}]
	}

	if {$nTotalHit == 0} {
	    set myCaptionVar "Text not found"
	    bell
	    return
	}

	if {$myCurrentHit < 0 || $nTotalHit <= $myCurrentHit} {
	    set reset 1
	    if {$myCurrentHit < 0} {
		set myCurrentHit [expr {$nTotalHit - 1}]
	    } else {
		set myCurrentHit 0
	    }
	    set myCaptionVar "(wrapped) Hit [expr {$myCurrentHit + 1}] / $nTotalHit"
	} else {
	    set reset 0
	    set myCaptionVar "Hit [expr {$myCurrentHit + 1}] / $nTotalHit"
	}

	set hv3 ""
	foreach {hv3 n1 i1 n2 i2} [$self GetHit $previousHit] { }
	catch {$hv3 tag delete findwidgetcurrent}

	set hv3 ""
	foreach {hv3 n1 i1 n2 i2} [$self GetHit $myCurrentHit] { }
	$self lazymoveto $hv3 $n1 $i1 $n2 $i2
	$hv3 tag add findwidgetcurrent $n1 $i1 $n2 $i2
	$hv3 tag configure findwidgetcurrent -bg black -fg yellow
    }

    method GetHit {iIdx} {
	set nSofar 0
	foreach {hv3 matchlist} $myCurrentList {
	    set nThis [expr {[llength $matchlist] / 4}]
	    if {($nThis + $nSofar) > $iIdx} {
		return [concat $hv3 [lrange $matchlist \
					 [expr {($iIdx-$nSofar)*4}] \
					 [expr {($iIdx-$nSofar)*4+3}]]]
	    }
	    incr nSofar $nThis
	}
	return ""
    }

    destructor {
	# Delete any tags added to the hv3 widget. Do this inside a [catch]
	# block, as it may be that the hv3 widget has itself already been
	# destroyed.
	foreach hv3 [$self Hv3List] {
	    catch {
		$hv3 tag delete findwidget
		$hv3 tag delete findwidgetcurrent
	    }
	}
    }
}

snit::widget ::hv3::stylereport {
    hulltype toplevel

    variable myHtml ""

    constructor {html} {
	set myHtml $html
	set hv3 $win.hv3

	::hv3::hv3 $hv3
	$hv3 configure -requestcmd [mymethod Requestcmd] -width 600 -height 400

	# Create an ::hv3::findwidget so that the report is searchable.
	# In this case the findwidget should always be visible, so remove
	# the <Escape> binding that normally destroys the widget.
	::hv3::findwidget $win.find $hv3
	bind $win <Escape> [list destroy $win]

	pack $win.find -side bottom -fill x
	pack $hv3 -fill both -expand true
    }

    method update {} {
	set hv3 ${win}.hv3
	$hv3 reset
	$hv3 goto report:
    }

    method Requestcmd {downloadHandle} {
	$downloadHandle append "<html><body>[$myHtml stylereport]"
	$downloadHandle finish
    }
}

