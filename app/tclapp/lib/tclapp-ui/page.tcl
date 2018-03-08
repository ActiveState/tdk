# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################

## Multicolumn list based on treectrl widget (3 columns).
## -with-arch 1 => 4 columns.

# ### ######### ###########################

# ### ######### ###########################
## Prerequisites

package require treectrl ; # The foundation for our display.
package require snit     ; # Object system
package require syscolor ; # System colors
package require image ; image::file::here ; # Predefined images
package require widget::scrolledwindow

# ### ######### ###########################
## Implementation

snit::widgetadaptor page {
    # ### ######### ###########################
    component tree

    delegate method * to tree
    delegate option * to tree
    delegate option -borderwidth to hull
    delegate option -relief      to hull
    # FUTURE: Exclude ...

    option -labelv -default Requirements

    option -with-arch -default 0 ;# Default to show no arch data.

    option -show {} ; # Callback. Executed whenever the active item
    # ............. ; # changes. Three arguments: path id of active
    # ............. ; # item, view containing it, and rowid of for the
    # ............. ; # active entry in the view. In this order.

    option -onaction {} ; # Callback. Same arguments as -show. Executed
    # ................. ; # when an item in the tree is double-clicked.

    option -ondel -default {} -readonly 1
    option -onsel -default {} -readonly 1

    # color to use on details view sorted column
    variable sortcolor "#fff7ff"

    # ### ######### ###########################
    ## Public API. (De)Construction.

    constructor {args} {
	set items          {}
	array set entry    {}
	array set pathmap  {}

	set wa [from args -with-arch 0]
	if {$wa} {
	    set w 560
	} else {
	    set w 310
	}
	# Regenerate for later.
	lappend args -with-arch $wa

	installhull using widget::scrolledwindow \
	    -borderwidth 1 -relief sunken

	install tree using treectrl $win.tree \
	    -borderwidth 0 -showheader 1 -xscrollincrement 20 \
	    -highlightthickness 0 -width $w -height 400

	$hull setwidget $tree

	$tree debug configure -enable no -display no \
		-erasecolor pink -displaydelay 30

	## Explorer pane ....

	$tree notify install <Header>
	$tree notify install <Header-invoke>

	###

	# Disable "scan" bindings on windows.
	if {$::tcl_platform(platform) eq "windows"} {
	    bind $tree <Control-ButtonPress-3> { }
	}

	bindtags $tree [list $tree TreeCtrl [winfo toplevel $tree] all]

	$tree notify bind $tree <ActiveItem> \
	    [mymethod ChangeActiveItem %p %c]

	$tree notify bind $tree <Header-invoke> \
	    [mymethod HeaderInvoke %C]

	bind $tree <Double-1> \
	    [mymethod Action %x %y]

	# User-defined states to control the icon shown for an item.
	# See all other [x].

	$tree state define teapot
	$tree state define profile
	$tree state define flash
	$tree state define flashb

	$self configurelist $args

	$self ConfigureStyle-details

	if {[llength $options(-ondel)]} {
	    bind $tree <Delete> \
		[mymethod DeleteSelection]
	}
	if {[llength $options(-onsel)]} {
	    $tree notify bind $tree <Selection> \
		[mymethod OnSelection]
	}
	return
    }

    # ### ######### ###########################
    ## Public API. 

    method sortby {tag} {
	$self HeaderInvoke $tag
	return
    }

    # ### ######### ###########################
    ## Internal. Data structures.

    # ### ######### ###########################
    ## Internal. Access to the view from the inner table widget.

    # ### ######### ###########################
    ## Internal. Event binding. Respond to changes in the active item.

    method ChangeActiveItem {p c} {
	# We don't really care about changes if there is nothing we
	# should tell them to.

	if {$options(-show) == {}} return
	if {$p != $c} {$self Show $c}
	return
    }

    # ### ######### ###########################
    ## Internal. Execute the show callback for an item.

    method Show {theitem} {
	# Call only if $options(-show) is not empty

	# We convert the item into a tuple containing its rowid and
	# the view containing its entry. The rowid is determined by
	# searching for the item's id in the view.

	if {$theitem != 0} {
	    foreach {rowid id} $entry($theitem) break
	} else {
	    set rowid -1
	    set id    {}
	}

	uplevel #0 [linsert $options(-show) end $id $options(-view) $rowid]

	$tree see $theitem
	return
    }

    method DeleteSelection {} {
	if {$options(-ondel) == {}} {return}
	uplevel #0 $options(-ondel)
	return
    }

    method OnSelection {} {
	if {$options(-onsel) == {}} {return}
	uplevel #0 $options(-onsel)
	return
    }

    # ### ######### ###########################
    ## Execute the double-click callback for a click at some
    ## coordinates. Ignored if no callback specified.

    method Action {x y} {
	# Execute a callback for the double-clicked row.
	if {$options(-onaction) == {}} {return}

	# Translations:
	# 1. x/y coordinates to item id
	# 2. item id to rowid in view
	# We ignore all clicks happening in the header line.

	set identity [$tree identify $x $y]
	if {$identity == {}} return
	foreach {type theitem} $identity break

	if {$type eq "header"} {return}

	foreach {rowid id} $entry($theitem) break

	uplevel #0 [linsert $options(-onaction) end $id $options(-view) $rowid]
	return
    }

    # ### ######### ###########################
    ## Internal. Debugging helpers.

    if 0 {
	# Debug methods to looks at tag and clear operations.
	method tag {args} {
	    # Intercept and print tag operations ...
	    puts "$self tag $args"
	    return [eval [linsert $args 0 $hull tag]]
	}

	method clear {args} {
	    # Intercept and print clear operations ...
	    puts "$self clear $args"
	    return [eval [linsert $args 0 $hull clear]]
	}
    }

    # ### ######### ###########################
    ## Block the options we use internally ...
    ## They are effectively nulled out.

    foreach o {-command -cache -usecommand -titlerow -titlecols} {
	option $o {}
	onconfigure $o {args} "#return -code error \"Unknown option $o\""
	oncget      $o        "#return -code error \"Unknown option $o\""
    }
    unset o

    # ### ######### ###########################

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


    method ConfigureStyle-details {} {
	set height [Height $tree]

	$tree configure -showroot no -showbuttons no -showlines no \
		-itemheight $height -selectmode extended \
		-xscrollincrement 20 -scrollmargin 16 \
		-xscrolldelay {500 50} \
		-yscrolldelay {500 50}

	Column $tree 0 Name name  -width 200 -arrow up -arrowpadx 6 -itembackground $sortcolor

	if {$options(-with-arch)} {
	    Column $tree 1 $options(-labelv) req  -width 100 -justify left -arrowside left -arrowgravity right
	    Column $tree 2 Architecture      arc  -width 150 -justify left -arrowside left -arrowgravity right
	    Column $tree 3 Note              note -expand 1  -justify left -arrowside left -arrowgravity right
	} else {
	    Column $tree 1 $options(-labelv) req   -width 100  -justify left -arrowside left -arrowgravity right
	    Column $tree 2 Note              note  -expand 1   -justify left -arrowside left -arrowgravity right
	}

	# Elements -> Styles -> Columns

	$tree element create e_img image -image [list \
		[image::get pkg_tap_regular]     {!selected !teapot !profile} \
		[image::get pkg_pot_regular]     {!selected  teapot !profile} \
		[image::get pkg_tap_profile]     {!selected !teapot  profile} \
		[image::get pkg_pot_profile]     {!selected  teapot  profile} \
		[image::get pkg_tap_regular_sel] {selected !teapot !profile} \
		[image::get pkg_pot_regular_sel] {selected  teapot !profile} \
		[image::get pkg_tap_profile_sel] {selected !teapot  profile} \
		[image::get pkg_pot_profile_sel] {selected  teapot  profile} \
	      ]

	# Note about the image element. The icon shown is controlled
	# by the states of the item the element is part of. Two
	# user-defined states (teapot, profile) control statically the
	# general appearance, dependent on the type (regular, profile)
	# and general origin (teapot, tap) of package. These are
	# configured at the time an item is created. One dynamic state
	# (selected) is then used to choose between normal and
	# highlighted icon variants. See all other [x].

	$tree element create e_txt text -lines 1 \
	    -fill [list $::syscolor::highlightText {selected focus}]
	 
	$tree element create e_sel rect -showfocus yes \
	    -fill [list \
		       $::syscolor::highlight {selected  focus} \
		       gray                   {selected !focus} \
		       \#add8e6 {flash} \
		       \#ffff00 {flashb}]

	# Styles -> Columns
	# column 0 = Name: text
	set S [$tree style create s_name]
	$tree style elements $S {e_sel e_img e_txt}
	$tree style layout   $S e_img -expand ns
	$tree style layout   $S e_txt -padx {2 0} -squeeze x -expand ns
	$tree style layout   $S e_sel -union [list e_img e_txt] -iexpand nsew -ipadx 2

	# column 1 = Requirements: text
	set S [$tree style create s_req]
	$tree style elements $S {e_sel e_txt}
	$tree style layout   $S e_txt -padx 6 -squeeze x -expand ns
	$tree style layout   $S e_sel -union [list e_txt] -iexpand nsew -ipadx 2

	if {$options(-with-arch)} {
	    # column 2 = Architecture: text
	    set S [$tree style create s_arc]
	    $tree style elements $S {e_sel e_txt}
	    $tree style layout   $S e_txt -padx 6 -squeeze x -expand ns
	    $tree style layout   $S e_sel -union [list e_txt] -iexpand nsew -ipadx 2
	}

	# column 2/3 = Note: text
	set S [$tree style create s_note]
	$tree style elements $S {e_sel e_txt}
	$tree style layout   $S e_txt -padx {2 0} -squeeze x -expand ns
	$tree style layout   $S e_sel -union [list e_txt] -iexpand nsew -ipadx 2

	return
    }

    # ### ######### ###########################
    ## Internal. Create a new item for an entry in a view.

    # Global map to convert the incoming boolean flags into the
    # correct set of states, controlling the icon shown/used. See all
    # other [x].

    typevariable statemap -array {
	00 {teapot}
	01 {teapot profile}
	10 {}
	11 {profile}
    }

    method NewItem {pref} {
	#               pref = list (name version isprofile istap UKEY note)
	# with-arch ==> pref = list (name version arch isprofile istap UKEY note)

	if {$options(-with-arch)} {
	    foreach {name ver arch isprofile istap __ note} $pref break
	} else {
	    foreach {name ver isprofile istap __ note} $pref break
	}

	set newitem [$tree item create]

	# %TODO% squirrel REF away somewhere for retrieval when
	# handling the selection.

	$tree item lastchild 0 $newitem
	$tree collapse         $newitem
	$tree item configure   $newitem -button 0 -visible 1
	if {$options(-with-arch)} {
	    $tree item style set   $newitem 0 s_name 1 s_req 2 s_arc 3 s_note
	} else {
	    $tree item style set   $newitem 0 s_name 1 s_req 2 s_note
	}

	if {$options(-with-arch)} {
	    $tree item element configure $newitem \
		0 e_txt -text $name , \
		1 e_txt -text $ver  , \
		2 e_txt -text $arch , \
		3 e_txt -text $note
	} else {
	    $tree item element configure $newitem \
		0 e_txt -text $name , \
		1 e_txt -text $ver  , \
		2 e_txt -text $note
	}

	$tree item state set   $newitem $statemap($istap$isprofile)

	set data($newitem) $pref

	# Flash newly added item.
	after 1 [mymethod Flash $newitem 1]

	$self Resort
	return $newitem
    }

    method Flash {item on {state flash}} {
	if {$on} {after 1000 [mymethod Flash $item 0 $state]}
	if {!$on} {set state !$state}

	# We catch the action as the item can be deleted while we are
	# waiting for the flash to switch off.

	catch {$tree item state set $item $state}
	return
    }

    method FlashStatic {item on {state flash}} {
	if {!$on} {set state !$state}

	# We catch the action as the item can be deleted while we are
	# waiting for the flash to switch off.

	catch {$tree item state set $item $state}
	return
    }

    variable data -array {}

    # ### ######### ###########################

    method Selection {} {
	# struct::list map <mymethod i2ref>
	set selection {}
	foreach i [$tree selection get] {
	    lappend selection $data($i)
	}
	return $selection
    }

    method RemoveSelection {} {
	foreach i [$tree selection get] {
	    $tree item delete $i
	}
	return
    }

    method Clear {} {
	array unset data *
	$tree item delete all
	return
    }

    # ### ######### ###########################

    variable sortcol 0
    method HeaderInvoke {C} {
	if {$C != $sortcol} {
	    # Release old sort column
	    $tree column configure $sortcol -arrow none -itembackground white
	    set sortcol $C
	}

	# Get current order
	set order [$self SortOrder]

	# Flip sort order
	set order $orderflip($order)
	set arrow $arrowoforder($order)

	# Claim new sort column
	$tree column configure $C -arrow $arrow -itembackground $sortcolor

	# Perform the sorting

	$self SortTable $order $C
	return
    }

    method Resort {} {
	# Resort the items after changes (new entries) ...
	set order [$self SortOrder]
	if {$order == {}} return
	$self SortTable $order $sortcol
    }

    method SortTable {order C} {
	# Sort the table per the instructions (which column, and what order).
	switch -exact [$tree column cget $C -tag] {
	    name {
		$tree item sort root $order -column $C -dictionary
	    }
	    req {
		$tree item sort root $order -column $C -dictionary -column name -dictionary
	    }
	    arc {
		$tree item sort root $order -column $C -dictionary -column name -dictionary
	    }
	}
	return
    }

    method SortOrder {} {
	return $orderofarrow([$tree column cget $sortcol -arrow])
    }

    typevariable orderofarrow -array {
	down -decreasing
	up   -increasing
	none -decreasing
    }
    typevariable arrowoforder -array {
	-decreasing down
	-increasing up
    }
    typevariable orderflip -array {
	-decreasing -increasing
	-increasing -decreasing
    }

    # ### ######### ###########################

    method filter {words args} {
	array set opts {
	    fields {name}
	    type {all}
	}
	array set opts $args
	set count 0
	if {[catch {string match $words $opts(fields)} err]} {
	    tk_messageBox -icon error -title "Invalid Search Pattern" \
		-message "Invalid search pattern: $words\n$err" -type ok
	    return -1
	}
	set id [$tree selection get]
	$tree selection clear
	if {$words eq "" || $words eq "*"} {
	    # make everything visible
	    foreach {item} [$tree item children root] {
		set vis 1
		$tree item configure $item -visible $vis
		incr count $vis
	    }
	} else {
	    # Fields-based searches
	    set ptns [list]
	    # Use split on words to ensure list-ification
	    foreach word [split $words] {
		if {[string first "*" $word] == -1} {
		    # no wildcard in pattern - add to each end
		    lappend ptns *$word*
		} else {
		    lappend ptns $word
		}
	    }
	    foreach {item} [$tree item children root] {
		set str {}
		foreach field $opts(fields) {
		    set itext [$tree item text $item $field]
		    if {$itext ne ""} { lappend str $itext }
		}
		foreach ptn $ptns {
		    set vis [string match -nocase $ptn $str]
		    # AND match on words, so break on first !visible
		    # OR would be to break on first visible
		    if {!$vis} { break }
		}

		$tree item configure $item -visible $vis
		incr count $vis
	    }
	}
	if {$id eq "" || ![$tree item cget $id -visible]} {
	    # no visible items may exist
	    set id "first visible"
	}
	catch {
	    $tree activate $id
	    $tree selection modify active all
	}
	$tree see active
	set visible $count
	return $count
    }

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use

package provide page 1.0
