# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
package require treectrl
package require snit
package require hv3::ashelp

package require widget::scrolledwindow

snit::widgetadaptor hv3::astoc {
    component tree

    delegate option * to tree

    constructor {args} {
	installhull using widget::scrolledwindow \
	    -scrollbar vertical -relief sunken -borderwidth 1
	install tree using treectrl $win.t \
	    -borderwidth 0 -showheader 0 \
	    -highlightthickness 0 -width 250 -height 300
	set t $tree
	$hull setwidget $t

	# Further setup of the tree ...
	$t debug configure -enable no -display no

	# Details ____________________________

	set height [Height $t]

	$t configure -showroot no -showbuttons 1 -showlines 0 \
	    -itemheight $height -selectmode single \
	    -xscrollincrement 20 -scrollmargin 16 \
	    -xscrolldelay {500 50} -yscrolldelay {500 50}

	# Columns
	Column $t 0 { } tree -expand 1 -itembackground [list \#f6f9f4 {}]

	$t configure -treecolumn 0

	# Elements -> Styles -> Columns
	$self setup ; # colors - syscolor snarf/copy

	$t element create e_txt text -lines 1 \
	    -fill [list $highlightText {selected focus}]

	$t element create e_sel rect -showfocus yes \
	    -fill [list \
		       $highlight {selected focus} \
		       gray       {selected !focus}]

	# Styles -> Columns
	# column 0 = text
	set S [$t style create s_text]
	$t style elements $S {e_sel e_txt}
	$t style layout   $S e_txt -padx 6 -squeeze x -expand ns
	$t style layout   $S e_sel -union {e_txt} -iexpand nsew -ipadx 2

	# set up bindings on widgets
	$t notify bind $t <Selection> [mymethod OnSelection]

	$self Fill

	$self configurelist $args
    }

    variable t
    variable sw
    variable highlight
    variable highlightText

    method setup {} {
	set w [listbox $win._________w_]
	set highlight     [$w cget -selectbackground]
	set highlightText [$w cget -selectforeground]
	destroy $w
    }

    # ### ### ### ######### ######### #########

    proc Height {t} {
	set height [font metrics [$t cget -font] -linespace]
	if {$height < 18} {
	    set height 18
	}
	return $height
    }

    proc Column {t id name tag args} {
	$t column create
	eval [linsert $args 0 $t column configure $id -text $name -tag $tag -borderwidth 1]
	return
    }

    method OnSelection {} {
	# Click on a toc entry (= selection) -> goto/show associated page.

	set sel [$t selection get]
	if {![llength $sel]} return
	set sel [lindex $sel 0]
	set link $map($sel)

	# Ignore missing links
	if {$link eq ""} return

	gui_current goto $link
	return
    }

    # ### ### ### ######### ######### #########

    variable map -array {}

    method Fill {} {
	$t item delete first last
	set ids {}
	foreach tocitem [hv3::ashelp_toc] {
	    foreach {parent label link} $tocitem break
	    set newitem [$t item create]

	    $t collapse         $newitem
	    $t item configure   $newitem -visible 1
	    $t item style set   $newitem 0 s_text
	    $t item element configure $newitem \
		0 e_txt -text $label

	    set map($newitem) $link

	    lappend ids $newitem
	    if {$parent >= 0} {
		set parent [lindex $ids $parent]
		$t item lastchild $parent $newitem
		$t item configure $parent -button 1
	    } else {
		$t item lastchild 0 $newitem
	    }
	}
	$t item expand "first visible"
	return
    }
}

package provide hv3::astoc 0.1
