# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# varDisplay.tcl --
#
#	This file implements the variable display widget used by both
#	main display and watch variable dialog.
#
# Copyright (c) 2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: varWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########

package require varAttr
package require transform
package require snit
package require struct::set
package require syscolor
package require BWidget
ScrolledWindow::use

# ### ### ### ######### ######### #########

snit::widget varDisplay {

    # ### ### ### ######### ######### #########

    option -onselect  {} ; # Callback for actions on selection changes.
    option -inspector {} ; # Associated inspector dialog, callback.
    option -ontoggle  {} ; # Callback for actions on varbreak changes.
    option -exaccess  {} ; # Callback to change expanded information.
    option -findtrans {} ; # Callback to locate the transform of a variable.

    # Additional tags for special bindings.
    option -tags -default {} -configuremethod C-tags

    # UI engine to query about system state.
    option -gui -default {} -configuremethod C-gui

    # ### ### ### ######### ######### #########

    constructor {args} {
	set vattr [varAttr ${selfns}::vattr]

	$self configurelist $args
	$self MakeWidgets
	$self PresentWidgets
	$self ActivateWidgets
	return
    }

    # ### ### ### ######### ######### #########

    method MakeWidgets {} {
	set sw [ScrolledWindow $win.l \
		    -managed 0 -ipad 0 -scrollbar vertical -relief sunken -bd 1]
	set t  [treectrl $win.l.t \
		    -borderwidth 0 -showheader 1 -xscrollincrement 20 \
		    -highlightthickness 0 -width 310 -height 400]
	$sw setwidget $t

	# Further setup of the tree ...

	$t debug configure -enable no -display no \
		-erasecolor pink -displaydelay 30

	# Details ____________________________

	$t state define var_watch     ; # Watchpoint y/n
	$t state define var_wdisabled ; # Watchpoint enable/disable

	set height [Height $t]

	$t configure -showroot no -showbuttons yes -showlines no \
		-itemheight $height -selectmode extended \
		-xscrollincrement 20 -scrollmargin 16 \
		-xscrolldelay {500 50} \
		-yscrolldelay {500 50}

	# Columns

	array set bar [system::getBar]

	Column $t 0 {  }     bps -width $bar(width) -itembackground $bar(color)
	Column $t 1 Variable var -width 100
	Column $t 2 Value    val -expand 1

	$t configure -treecolumn 1

	# Elements -> Styles -> Columns

	$t element create e_img image -image [list \
	     [image::get var_e] { var_watch !var_wdisabled} \
	     [image::get var_d] { var_watch  var_wdisabled} \
	     {}                 {!var_watch !var_wdisabled} \
	     {}                 {!var_watch  var_wdisabled} \
	    ]

	$t element create e_txt text -lines 1 \
	    -fill [list $::syscolor::highlightText {selected focus}]
	 
	$t element create e_sel rect -showfocus yes \
	    -fill [list \
		       $::syscolor::highlight {selected focus} \
		       gray                   {selected !focus}]

	# Styles -> Columns

	# column 0 = BPS: icon for state
	set S [$t style create s_bps]
	$t style elements $S e_img
	$t style layout   $S e_img -expand ns

	# column 1 = Variable: text
	# column 2 = Value:    text
	set S [$t style create s_text]
	$t style elements $S {e_sel e_txt}
	$t style layout   $S e_txt -padx 6 -squeeze x -expand ns
	$t style layout   $S e_sel -union {e_txt} -iexpand nsew -ipadx 2

	return
    }

    method PresentWidgets {} {
	grid $sw -sticky wnse -row 0 -column 0
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1
	return
    }

    method ActivateWidgets {} {
	# Scrapped for now - TODO recreation of the needed parts.

	set tags [list watchBind$self watchBind]
	bind::addBindTags $t $tags

	# C-tags, reduced to adding
	if {[llength $options(-tags)]} {
	    bind::addBindTags $t $options(-tags)
	}

	# TreeControl Bindings

	$t notify bind $t <Expand-before>  [mymethod ExpandArray  %I]
	$t notify bind $t <Collapse-after> [mymethod FlattenArray %I]
	$t notify bind $t <Selection>      [mymethod OnSelection]

	# Defaults ...
	# Event        Action
	# -----        ------
	# <1>          item -> set active, set focus, set as selection
	# <Control-1>  item -> set active, set focus?, add to selection
	# <Left>       |Free
	# <Right>      |Free
	# <+>          item -> expand
	# <->          item -> collapse (flatten in our speak here)
	# <Return>     item -> toggle expand/flatten
	# -----        ------

	# Modifications here

	# <1>         | If on icon of item -> Special [1]
	# <Control-1> | Otherwise regular handling

	# [1] toggle on/off         | For var breakpoint to item
	#     toggle enable/disable | (Control here)

	# The regular handling we chain to comes from the TreeCtrl
	# bindings, and we break before we invoke them a second time.

	bind $t <1>         "[mymethod Click     %x %y [bind TreeCtrl <1>        ]];break"
	bind $t <Control-1> "[mymethod CtrlClick %x %y [bind TreeCtrl <Control-1>]];break"

	# Keypad equivalents and cursor override ...
	bind TreeCtrl <KP_Enter>       [bind TreeCtrl <Return>]
	bind TreeCtrl <KP_Subtract>    [bind TreeCtrl <Key-minus>]
	bind TreeCtrl <KP_Add>         [bind TreeCtrl <Key-plus>]
	bind TreeCtrl <KeyPress-Left>  {%W item collapse [%W item id active]}
	bind TreeCtrl <KeyPress-Right> {%W item expand   [%W item id active]}

	$self watchBindSetup watchBind$self
	return
    }

    # ### ### ### ######### ######### #########

    method watchBindSetup {tag} {

	bind $tag <<Dbg_DataDisp>> {menu::accKeyPress <<Dbg_DataDisp>>}
	# Control-D => showInspector @active

	bind $tag <<Copy>>         [mymethod copy]
	bind $tag <<Cut>>          [mymethod copy]

	bind $tag <Double-1>       \
	    "[bind TreeCtrl <Double-1>];[mymethod showInspectorAt %x %y];break"

	bind $tag <Shift-Return>         "[mymethod toggleVBPAtCursor onoff];break"
	bind $tag <Control-Shift-Return> "[mymethod toggleVBPAtCursor enabledisable];break"
	return
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


    # ### ### ### ######### ######### #########

    # method update --
    #
    #	Fill window with variable information ...
    #
    # Arguments:
    #	varList		The list of vars to add to the window.  The 
    #			insertion is done in order, so this list needs
    #			to have been pre-sorted.  Any variables that
    #			do not exist in this scope are assumed to have
    #			been detected and replaced with <No Value>.
    #			varList is an ordered list with the following
    #			structure: {mname oname type exist}
    #	level		The level of the variables being displayed.  Used
    #			to determine which arrays are expanded or compressed.
    #
    # Results:
    #	None.

    # Global map to convert the incoming var bp information into the
    # correct set of states, controlling the icon shown/used. See all
    # other [x].

    typevariable statemap -array {
	noBreak       {!var_watch  var_wdisabled}
	enabledBreak  { var_watch !var_wdisabled}
	disabledBreak { var_watch  var_wdisabled}
    }

    variable itemof  -array {}

    method update {varList level} {
	# Cleanup the previous state and start fresh.
	#$dbg Log timing {updateInternal $nameText}

	$vattr reset

	# Cache the scroll-position so it can be restored.
	set yview [lindex [$t yview] 0]

	$t item delete first last
	array unset itemof *

	foreach var $varList {
	    foreach {mname oname vtype exist trans} $var break

	    # Insert the variable name and value.  If the variable is
	    # an array, display "..." as its value to indicate this
	    # can be expanded, and is some more structured.

	    set vstate [$icon getVBPState     $level $oname]
	    set tstate $statemap($vstate)

	    set v      [$self GetValue $vtype $level $oname $trans]
	    set b      [expr {$vtype eq "a"}]

	    set newitem [$t item create]

	    $t item lastchild 0 $newitem
	    $t collapse         $newitem
	    $t item configure   $newitem -button $b -visible 1
	    $t item style set   $newitem 0 s_bps 1 s_text 2 s_text
	    $t item element configure $newitem \
		1 e_txt -text $mname , \
		2 e_txt -text $v

	    $t item state set $newitem $tstate

	    # Remember the added information as attributes of the item

	    $vattr setmany $newitem \
		oname $oname type $vtype exist $exist transform $trans \
		vstate $vstate

	    set itemof([code::mangle $oname]) $newitem ; # key -> item mapping.
	    # Reverse for selection is handled through the attributes.

	    # Expand the array after the keys have been inserted because
	    # the expand array APIs rely on these keys.

	    if {$vtype eq "a" && ($level != {})} {
		# Bugzilla 19719 ... 
		set  isExpanded [$self ExA $oname $level $trans]
		if {$isExpanded} {
		    $t item expand $newitem ; # -> Implies ExpandArray via event
		}
	    }
	}

	# Restore the previous yview before everything was deleted.
	$t yview moveto $yview
	return
    }

    method GetValue {vtype level oname trans} {
	switch -- $vtype {
	    "s" {
		# Bugzilla 19719 ... Apply chosen transformation.
		return [code::mangle \
			    [lindex \
				 [transform::transform \
				      [$vcache get $oname $level $vtype] \
				      $trans] \
				 end]]
	    }
	    "a" {
		return {}
	    }
	    "n" {
		 return [$vcache noValue]
	    }
	}
    }

    method clear {} {
	$t item delete first last
	array unset itemof *
	return
    }

    method message {m} {
	$self clear

	# TODO maybe - Use a different style, text across both columns ?

	set newitem [$t item create]
	$t item lastchild 0 $newitem
	$t collapse         $newitem
	$t item configure   $newitem -button 0 -visible 1
	$t item style set   $newitem 0 s_bps 1 s_text 2 s_text
	$t item element configure $newitem \
	    1 e_txt -text $m , \
	    2 e_txt -text {}

	return
    }

    # TODO remove - update users
    method refocus {} {}

    method ourFocus {}  {return $t}
    method hasFocus {}  {return [expr {[focus] eq $t}]}
    method hadFocus {w} {return [expr {$w eq $t}]}

    method hasHighlight {} {return [llength [$t selection get]]}
    method getSelection {} {return [$t selection get]}

    method select {item movefocus} {
	$t selection clear
	$t selection add $item
	$t activate $item

	if {!$movefocus} return
	focus $t
	return
    }

    method seeVarInWindow {varName moveFocus} {
	# Search the list of var names to see if the var exists in the
	# Var Window.  If so select it and possibly force the focus to
	# the Var Window.

	if {![info exists itemof($varName)]} return

	set item $itemof($varName)
	$self select $item $moveFocus
	return
    }

    method shown {} {
	return [array names itemof]
    }

    method varOf {item} {
	return [$vattr get $item oname]
    }

    method baseOf {item} {
	if {[$vattr exists $item arrayName]} {
	    return [$vattr get $item arrayName]
	}
	return [$vattr get $item oname]
    }

    method varExists {item} {
	return [$vattr get $item exist]
    }

    method transformOf {item} {
	return [$vattr get $item transform]
    }

    method getActive {} {
	return [$t item id active]
    }

    method menuLocation {item} {
        # bbox = upper left and bottom right, both x,y coordinates.
	foreach {x __ __ y} [$t item bbox $item val] break
	incr x [winfo rootx $t]
	incr y [winfo rooty $t]
	return [list $x $y]
    }

    # ### ### ### ######### ######### #########

    method breakState {} {
	set active [$t item id active]
	if {$active == 0} {
	    # No item is active, i.e. the menu is about to be posted
	    # while varWindow has focus, but user has not activated
	    # any item (can happen by right-click for transform menu
	    # without discarding it and going directly to the top menu
	    # (bug 88591)). Signal to disable both menu entries for
	    # var breakpoints.
	    return noActive
	}
	# map item state back into the equivalent var break state
	# we stored this in the item attributes to make this easy
	return [$vattr get $active vstate]
    }

    # ### ### ### ######### ######### #########

    # method scrollWindow --
    #
    #	Scroll all of the var window's text widgets in parallel.
    #
    # Arguments:
    #	args	Args passed from the scroll callback.
    #
    # Results:
    #	None.

    method scrollIsAt {} {
	return [lindex [$t yview] 0]
    }

    method scrollTo {yview} {
	$t yview moveto $yview 
	return
    }

    # ### ### ### ######### ######### #########

    # method showInspector --
    #
    #	Show the Inspector Window for the selected variable.
    #
    # Arguments:
    #	ns	The namespace of the calling proc (watch or var).
    #
    # Results:
    #	None.

    method showInspectorAt {x y} {
	set theitem {}
	if {[InImage $t $x $y theitem]} return
	if {$theitem eq ""} return
	$t activate $theitem
	$self showInspector
	return
    }

    method showInspector {} {
	# Bugzilla 19719 ... Propagate transformation info to inspector
	# dialog.

	set item  [$t item id active]
	set oname [$vattr get $item oname]     ; # varOf
	set trans [$vattr get $item transform] ; # transformOf

	$options(-inspector) showVariable $oname [$gui getCurrentLevel] $trans    
	return
    }

    method Click {x y chain} {
	if {![InImage $t $x $y theitem]} {uplevel \#0 $chain ; return}
	$self toggleVBP $theitem onoff
	return
    }

    method CtrlClick {x y chain} {
	if {![InImage $t $x $y theitem]} {uplevel \#0 $chain ; return}
	$self toggleVBP $theitem enabledisable
	return
    }

    proc InImage {w x y iv} {
	upvar 1 $iv theitem
	set id [$w identify $x $y]
	#puts <$id>
	# Ignore outside
	if {$id eq ""}         {return 0}

	foreach {a item} $id break
	set theitem $item

	if {[llength $id] < 4} {return 0}

	# id = item ITEM column COL elem ELEM
	#      0    1    2      3   4    5

	foreach {_ _ b column c element} $id break

	if {$a ne "item"}   {return 0}
	if {$b ne "column"} {return 0}
	#if {$c ne "elem"}   {return 0}

	if {![$w column compare $column == "bps"]} {return 0}
	#if {$element ne "e_img"} {return 0}

	#puts OK
	return 1
    }

    # method toggleVBP --
    #
    #	Toggle a VBP between on/off enabled/disabled.
    #
    # Arguments:
    #	item		Where to draw the VBP.
    #	toggleType	How to toggle ("onoff" or "enabledisable")
    #
    # Results:
    #	None.

    method toggleVBPAtCursor {mode} {
	$self toggleVBP [$t item id active] $mode
    }

    method toggleVBP {item toggleType} {
	# Dont allow user to toggle VBP state when the GUI's
	# state is not stopped.

	if {[$gui getCurrentState] ne "stopped"} return
	
	# Don't allow user to toggle in the Var/Watch Window
	# if the var frame is hidden.

	if {[$stack isVarFrameHidden]} return

	# If the current item is not selected, only toggle the VBP at
	# the current line. Otherwise, toggle all of the selected
	# variables to the new state of the current line.

	if {![$t selection includes $item]} {
	    $self TV $item $toggleType
	} else {
	    # Get the list of selected variables, and toggle each
	    # to the new state of the selected line.

	    foreach item [$t selection get] {
		$self TV $item $toggleType
	    }
	}

	# Tell related windows to update themselves, so all windows
	# have identical state.

	if {![llength $options(-ontoggle)]} return
	eval [linsert $options(-ontoggle) end $self]
	return
    }

    method TV {item toggleType} {
	if {![$vattr get $item exist]} return

	set level [$gui getCurrentLevel]
	set oname [$vattr get $item oname]

	set vstate [$vattr get $item vstate]
	if {$toggleType eq "onoff"} {
	    set nstate [$icon toggleVBPOnOff         $level $oname $vstate]
	} else {
	    set nstate [$icon toggleVBPEnableDisable $level $oname $vstate]
	}

	$t item state set $item $statemap($nstate)
	$vattr set        $item vstate $nstate
	return
    }

    # method copy --
    #
    #	Copy the highlighted text to the Clipboard.
    #
    # Arguments:
    #	text	The text widget receiving the copy request.
    #
    # Results:
    #	None.

    method copy {} {
	# Create a list that collates the highlighted name text with
	# the highlighted value text.  Be careful to trim the newline
	# off of the name text so each name-value pair appears on the
	# same line.

	set result {}
	foreach item [$t selection get] {
	    set name [$t item element cget $item var e_txt]
	    set valu [$t item element cget $item val e_txt]
	    lappend result [list $name $valu]
	}

	if {[llength $result]} {
	    clipboard clear  -displayof $t
	    clipboard append -displayof $t [join $result \n]
	}
    }

    # ### ### ### ######### ######### #########

    method OnSelection {} {
	if {![llength $options(-onselect)]} return
	eval [linsert $options(-onselect) end $self]
	return
    }

    # ### ### ### ######### ######### #########

    method ExpandArrayAtCursor {} {
	$self ExpandArray [$t item id active]
    }

    method FlattenArrayAtCursor {} {
	$self FlattenArray [$t item id active]
    }

    # method ExpandArray --
    #
    #	Expand the array entry to show all of the elements 
    #	in the array.  Re-bind the array indicator to 
    #	flatten the array if selected again.
    #
    # Arguments:
    #	item	The index into the text widget where the array
    #		handle (i.e.  "(...)" ) is located.
    #
    # Results:
    #	The number of items added.

    method ExpandArray {item} {
	if {[$vattr get $item type] ne "a"} return

	set vx        {}
	set trans     [$vattr get $item transform]
	set arrayName [$vattr get $item oname]
	set level     [$gui getCurrentLevel]

	array set unsorted [$vcache get $arrayName $level "a"]

	foreach element [lsort -dictionary [array names unsorted]] {

	    set scalarName ${arrayName}($element)
	    if {$vx eq ""} {set vx $scalarName}

	    # Bugzilla 19719 ... 
	    if {$trans != {}} {
		set tid $trans
	    } else {
		set tid [eval [linsert $options(-findtrans) end $scalarName $level]]
	    }
	    set vstate [$icon getVBPState $level $scalarName]
	    set v      [code::mangle [lindex [transform::transform $unsorted($element) $tid] end]]

	    set newitem [$t item create]

	    $t item lastchild $item $newitem
	    $t collapse             $newitem
	    $t item configure       $newitem -button 0 -visible 1
	    $t item style set       $newitem 0 s_bps 1 s_text 2 s_text
	    $t item element configure $newitem \
		1 e_txt -text [code::mangle $element] , \
		2 e_txt -text $v

	    $t item state set $newitem $statemap($vstate)

	    # Remember the attributes and add the array values to the
	    # database as scalar entries.
	    
	    $vattr setmany $newitem \
		oname     $scalarName type "s" exist 1 \
		arrayName $arrayName element $element \
		transform $tid vstate $vstate

	    $vcache set $scalarName $level s $unsorted($element)
	}

	# Set the expanded flag so the array will remain expanded
	# after window updates.

	$self ExA $arrayName $level $trans 1

	# Bugzilla 29696. Ensure that first element of expanded array
	# is visible. This ensures that the users sees a change if the
	# expanded array was at the bottom of the display. It moves
	# one line up. Otherwise the use may be fooled into the belief
	# that the expansion did not happen, as there is not other
	# visual feedback, as the expansion result was placed outside
	# of the visible area.

	if {$vx ne ""} {
	    $self seeVarInWindow $vx 0
	}

	return [llength [array names unsorted]]
    }

    # method FlattenArray --
    #
    #	Flatten the array entry to hide all of the elements 
    #	in the array.  Re-bind the array indicator to 
    #	expand the array is selected again.
    #
    # Arguments:
    #	item	The index into the text widget where the array
    #		handle (i.e.  "(...)" ) is located.
    #
    # Results:
    #	The number of lines removed.

    method FlattenArray {item} {
	set children [$t item children $item]
	set len      [llength $children]

	# Ignore items which have no children we can remove.
	if {!$len} return

	if {[$vattr get $item type] ne "a"} return

	set trans     [$vattr get $item transform]
	set arrayName [$vattr get $item oname]
	set level     [$gui getCurrentLevel]

	# For every index/entry pair there is an item displayed in the
	# tree widgets that needs to be removed. These are the children
	# of the item just collapsed.

	foreach child $children {
	    $t item delete $child
	    $vattr unset $child
	}

	# Remove the expanded flag so the array will not be expanded
	# on the next window update.

	$self ExA $arrayName $level $trans 0

	return $len
    }

    method ExA {args} {
	set cmd $options(-exaccess)
	foreach a $args {lappend cmd $a}
	return [eval $cmd]
    }

    # ### ### ### ######### ######### #########

    method C-gui {option newvalue} {
	if {$newvalue eq $gui} return

	set gui    $newvalue
	set stack  [$gui stack]
	set vcache [$gui vcache]
	set icon   [$gui icon]
	return
    }

    method C-tags {option newval} {
	# Ignore non-changes
	if {$newval eq $options(-tags)} return

	set oldval $options(-tags)
	set options(-tags) $newval

	if {![winfo exists $t]} return

	# Ignore changes during construction (configurelist before MakeWidgets)
	foreach {unchanged removed added} \
	    [struct::set intersect3 $oldval $newval] break

	$self RemoveTags $removed
	$self AddTags    $added
	return
    }

    method AddTags {added} {
	if {![llength $added]} return
	bind::addBindTags $t $added
	return
    }

    method RemoveTags {removed} {
	if {![llength $removed]} return
	bind::removeBindTags $t $removed
	return
    }

    # ### ### ### ######### ######### #########

    # Handles to the internal widgets, like the text windows that
    # display variable names and values, and their scroll bar.

    variable t  {}
    variable sw {}

    variable vattr  {} ; # Attributes of the currently shown variables.
    variable gui    {} ; # The Ui engine to query about system state.
    variable stack  {} ; # The stack display to query about system state.
    variable vcache {} ; # The var database/cache to query.
    variable icon   {} ; # Icon handling - provides vbp state information.

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

package provide varDisplay 0.1

