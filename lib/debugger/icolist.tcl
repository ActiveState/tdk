# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# icolist.tcl --
#
#	Single-column list with icon bar to the left.
#	Treectrl based.
#
# Copyright (c) 2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: varWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########

package require snit
package require syscolor
package require system
package require BWidget
ScrolledWindow::use

# ### ### ### ######### ######### #########

snit::widget icolist {

    # ### ### ### ######### ######### #########

    option -onselect {} ; # Callback for actions on selection changes.
    option -ontoggle {} ; # Callback for actions on bar changes.
    option -statemap {} ; # dict state -> image for the icon bar.
    option -columns  1
    option -height   400
    option -headers  {}

    # Additional tags for special bindings.
    option -tags -default {} -configuremethod C-tags

    # ### ### ### ######### ######### #########

    constructor {args} {
	$self configurelist $args
	$self MakeWidgets
	$self PresentWidgets
	$self ActivateWidgets
	return
    }

    # ### ### ### ######### ######### #########

    method MakeWidgets {} {
	set sh [expr {!![llength $options(-headers)]}]

	set sw [ScrolledWindow $win.l \
		    -managed 0 -ipad 0 -scrollbar both -relief sunken -bd 1]
	set t  [treectrl $win.l.t \
		    -borderwidth 0 -showheader $sh -xscrollincrement 20 \
		    -highlightthickness 0 \
		    -width 310 -height $options(-height)]
	$sw setwidget $t

	# Further setup of the tree ...

	$t debug configure -enable no -display no \
		-erasecolor pink -displaydelay 30

	# Details ____________________________

	foreach {s i} $options(-statemap) {
	    $t state define $s
	}

	set height [Height $t]

	$t configure -showroot no -showbuttons no -showlines no \
		-itemheight $height -selectmode extended \
		-xscrollincrement 20 -scrollmargin 16 \
		-xscrolldelay {500 50} \
		-yscrolldelay {500 50}

	# Columns

	array set bar [system::getBar]

	Column $t 0 {  } bar -width $bar(width) -itembackground $bar(color)

	for {set j 0 ; set n 1} {$n <= $options(-columns)} {incr n ; incr j} {
	    set title [lindex $options(-headers) $j]
	    Column $t $n $title txt$n -expand 1
	}

	# Elements -> Styles -> Columns

	$t element create e_img image -image \
	    [Icons $options(-statemap) strans]

	$t element create e_txt text -lines 1 \
	    -fill [list $::syscolor::highlightText {selected focus}]
	 
	$t element create e_sel rect -showfocus yes \
	    -fill [list \
		       $::syscolor::highlight {selected focus} \
		       gray                   {selected !focus}]

	# Styles -> Columns

	# column 0 = BAR: icon for state
	set S [$t style create s_bar]
	$t style elements $S e_img
	$t style layout   $S e_img -expand ns

	# column 1+ = Text: text
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

	# C-tags, reduced to adding
	if {[llength $options(-tags)]} {
	    bind::addBindTags $t $options(-tags)
	}

	$t notify bind $t <Selection>  [mymethod OnSelection]
	$t notify bind $t <ActiveItem> [mymethod OnSelection]

	# Defaults ...
	# Event        Action
	# -----        ------
	# <1>          item -> set active, set focus, set as selection
	# <Control-1>  item -> set active, set focus?, add to selection
	# -----        ------

	# Modifications here

	# <1>         | If on icon of item -> Special [1]
	# <Control-1> | Otherwise regular handling

	# [1] toggle on/off         | For var breakpoint to item
	#     toggle enable/disable | (Control here)

	bind $t <1>           [mymethod Click     %x %y [bind $t <1>        ]]
	bind $t <Control-1>   [mymethod CtrlClick %x %y [bind $t <Control-1>]]

	$self BindSetup watchBind$self
	return
    }

    # ### ### ### ######### ######### #########

    method BindSetup {tag} {
	bind $tag <<Copy>>         [mymethod copy]
	bind $tag <<Cut>>          [mymethod copy]

	bind $tag <Shift-Return>         "[mymethod ToggleAtCursor onoff];break"
	bind $tag <Control-Shift-Return> "[mymethod ToggleAtCursor enabledisable];break"
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

    variable itmap -array {}

    method update {data} {
	# Cleanup the previous state and start fresh.
	#$dbg Log timing {updateInternal $nameText}

	# Cache the scroll-position so it can be restored.
	set yview [lindex [$t yview] 0]

	$t item delete first last
	array unset itmap *

	foreach d $data {
	    set state [lindex $d 0]

	    set tstate $strans($state)

	    set newitem [$t item create]

	    $t item lastchild 0 $newitem
	    $t collapse         $newitem
	    $t item configure   $newitem -button 0 -visible 1

	    $t item style set   $newitem 0 s_bar

	    for {set n 1} {$n <= $options(-columns)} {incr n} {
		$t item style set         $newitem $n s_text
		$t item element configure $newitem $n e_txt \
		    -text [lindex $d $n]
	    }

	    $t item state set $newitem $tstate

	    set text [lrange $d 1 end]
	    set itmap(t,$text) $newitem
	    set itmap(s,$newitem) $state
	    set itmap(x,$newitem) $text
	}

	# Restore the previous yview before everything was deleted.
	$t yview moveto $yview
	return
    }

    method clear {} {
	$t item delete first last
	array unset itmap *
	return
    }

    method message {m} {
	$self clear

	# TODO maybe - Use a different style, text across both columns ?

	set newitem [$t item create]
	$t item lastchild 0 $newitem
	$t collapse         $newitem
	$t item configure   $newitem -button 0 -visible 1
	$t item style set   $newitem 0 s_bar 1 s_text
	$t item element configure $newitem \
	    1 e_txt -text $m

	return
    }

    method ourFocus {}  {return $t}
    method hasFocus {}  {return [expr {[focus] eq $t}]}
    method hadFocus {w} {return [expr {$w eq $t}]}

    method hasHighlight {} {return [llength [$t selection get]]}
    method getSelection {} {return [$t selection get]}

    method inSelection {item} {return [$t selection includes $item]}

    method select {item movefocus} {
	$t selection clear
	$t selection add $item
	$t activate $item

	if {!$movefocus} return
	focus $t
	return
    }

    method shown {} {
	return [array names itmap]
    }

    method itemOf {text} {
	return $itmap(t,$text)
    }

    method textOf {item} {
	return $itmap(x,$item)
    }

    method stateOf {item} {
	return $itmap(s,$item)
    }

    method getActive {} {
	return [$t item id active]
    }

    method menuLocation {item} {
	foreach {x y __ sh} [$t item bbox $item val] break
	incr y $sh
	incr x [winfo rootx $t]
	incr y [winfo rooty $t]

	return [list $x $y]
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

    method Click {x y chain} {
	if {![InImage $t $x $y theitem]} {uplevel \#0 $chain ; return}
	$self Toggle $theitem onoff
	return
    }

    method CtrlClick {x y chain} {
	if {![InImage $t $x $y theitem]} {uplevel \#0 $chain ; return}
	$self Toggle $theitem enabledisable
	return
    }

    proc InImage {w x y iv} {
	upvar 1 $iv theitem
	set id [$w identify $x $y]
	#puts <$id>
	# Ignore outside
	if {$id eq ""}         {return 0}
	if {[llength $id] < 4} {return 0}

	# id = item ITEM column COL elem ELEM
	#      0    1    2      3   4    5

	foreach {a item b column c element} $id break
	if {$a ne "item"}   {return 0}
	if {$b ne "column"} {return 0}
	#if {$c ne "elem"}   {return 0}

	if {![$w column compare $column == "bar"]} {return 0}
	#if {$element ne "e_img"} {return 0}

	#puts OK
	set theitem $item
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

    method ToggleAtCursor {mode} {
	$self Toggle [$t item id active] $mode
    }

    method Toggle {item toggleType} {
	# Dont allow user to toggle VBP state when the GUI's
	# state is not stopped.

	if {![llength $options(-ontoggle)]} return
	eval [linsert $options(-ontoggle) end $self $item]
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
	    lappend result [$t item element cget $item txt e_txt]
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

    method C-tags {option newval} {
	# Ignore non-changes
	if {$newval eq $options(-tags)} return

	set oldval $options(-tags)
	set options(-tags) $newval

	# Ignore changes during construction, i.e. the configurelist
	# run before MakeWidgets
	if {![winfo exists $t]} return

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
    variable strans -array {}

    # ### ### ### ######### ######### #########

    proc Icons {map tv} {
	upvar 1 $tv translation
	set res {}
	foreach {s i} $map {
	    set states {}
	    foreach {sx _} $map {
		if {$s eq $sx} {
		    lappend states $sx
		} else {
		    lappend states !$sx
		}
	    }
	    if {$i ne ""} {set i [image::get $i]}
	    lappend res $i $states
	    set translation($s) $states
	}
	return $res
    }
}

# ### ### ### ######### ######### #########

package provide icolist 0.1

