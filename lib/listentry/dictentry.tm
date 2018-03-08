# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package dictentry 1.0
# Meta platform    tcl
# Meta require     BWidget
# Meta require     snit
# Meta require     tile
# Meta require     tipstack
# Meta require     treectrl
# Meta category	 Widget
# Meta subject	 widget {data entry} {dict entry}
# Meta summary	 A widget to enter values into a dictionary
# Meta description A megawidget for entering values into
# Meta description a dictionary. Similar to listentryb.
# @@ Meta End

# -*- tcl -*-
# listentry.tcl --
# -*- tcl -*-
#
#	Standard panel for managing a(n ordered) dictionary.
#
# Copyright (c) 2007 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Docs

# ### ### ### ######### ######### #########
## Requisites

package require img::png
package require image ; image::file::here
package require snit                ; # Tcllib, OO core.
package require tile                ; # Theming support.
package require BWidget             ; # Only for 'ScrolledWindow'
package require tipstack            ; # Tooltips.
package require treectrl            ; # Tree widget used for the multi-column list.
package require syscolor

ScrolledWindow::use

# ### ### ### ######### ######### #########
## Implementation

snit::widget dictentry {
    hulltype ttk::frame

    # ### ### ### ######### ######### #########
    ## API. Definition

    ## Options ....

    option -dictvariable -default {} -configuremethod C-dictvar
    # The variable the dictionary managed by the widget is exported to,
    # and import from.

    option -addremove 1  ; # Flag controlling the add/remove buttons and entries.

    option -removable {} ; # Test callback. Executed with a key as single argument.
    #                    ; # Returns boolean value indicating whether the key can
    #                    ; # be removed by the user, or not. True = removable.

    option -sort      {} ; # Sort callback. Executed with list of keys, returns
    #                    ; # keys in sorted order.

    option -height -default 20     -configuremethod C-height
    # Widget height in lines (#entries)

    option -state  -default normal -configuremethod C-state
    # Widget state, normal/disabled

    # Options to configure the key column ...

    option -titlek  Key  ; # Column title
    option -labelks Key  ; # Name of dict keys, singular | Used in
    option -labelkp Keys ; # Name of dict keys, plural   | tooltips

    option -editk 1      ; # Flag controlling the ability to add keys in place.

    option -validk {} ; # Key validation callback.
    #                 ; # Executed with current text as argument.
    #                 ; # Text result. Empty     => Ok.
    #                 ; #              Otherwise => The error message

    option -transformk {} ; # Key transformation callback.
    #                     ; # Executed with current text as argument (valid!)
    #                     ; # Result is text to actually add.

    # Options to configure the value column ...

    option -titlev  Value  ; # Column title
    option -labelvs Value  ; # Name of dict values, singular | Used in
    option -labelvp Values ; # Name of dict values, plural   | tooltips

    option -editv 1        ; # Flag controlling the ability to add values in place.

    option -validv {} ; # Value validation callback.
    #                 ; # Executed with current text as argument.
    #                 ; # Text result. Empty     => Ok.
    #                 ; #              Otherwise => The error message

    option -transformv {} ; # Value transformation callback.
    #                     ; # Executed with current text as argument (valid!)
    #                     ; # Result is text to actually add.

    # ### ### ### ######### ######### #########
    ## API. Implementation

    constructor {args} {
	# DEBUG # $hull configure -relief raised -bd 2 -bg coral

	$self configurelist $args
	$self MakeWidgets
	$self PresentWidgets

	trace add variable [myvar _key]    {write} [mymethod KeyOk?]
	trace add variable [myvar _val]    {write} [mymethod ValOk?]
	trace add variable [myvar current] {write} [mymethod Export]

	set _key {}
	set _val {}

	# Fire initial validations.
	$self KeyOk?
	$self ValOk?
	$self Contents?
	$self OnSelection
	return
    }

    destructor {
	trace remove variable [myvar _key]    {write} [mymethod KeyOk?]
	trace remove variable [myvar _val]    {write} [mymethod ValOk?]
	trace remove variable [myvar current] {write} [mymethod Export]
	tipstack::clearsub $win
	return
    }

    # ### ### ### ######### ######### #########
    ## UI definition. Creation, Layout

    method MakeWidgets {} {
	ttk::button    $win.add  -command [mymethod Add]       -text "Add"    -image [image::get add]  -state disabled
	ttk::button    $win.rem  -command [mymethod Remove]    -text "Remove" -image [image::get delete]

	ScrolledWindow   $win.l -managed 0 -ipad 0 -scrollbar vertical -relief sunken -bd 1
	$self MC         $win.l.t
	$win.l setwidget $win.l.t

	# Use the validation callbacks to ensure that the display is
	# correct even after focus changes. Without that the state
	# changes caused by the focus change may cause the entry to be
	# shown as valid despite being invalid (bg color wrong).

	ttk::entry  $win.nk -textvariable [myvar _key] \
	    -validate        focus \
	    -validatecommand [mymethod FocusKeyOk?]

	ttk::entry  $win.nv -textvariable [myvar _val] \
	    -validate        focus \
	    -validatecommand [mymethod FocusValOk?] \
	    -width           40

	# Bindings ...

	setkey $win Return   [mymethod Add]
	setkey $win KP_Enter [mymethod Add]
	setkey $win Delete   [mymethod Remove]

	# Override 'setkey' for the key entry, refocus, can't add yet.
	bind $win.nk <Return>   [list focus $win.nv]
	bind $win.nk <KP_Enter> [list focus $win.nv]

	bind $win.nk <Tab>      [list focus $win.nv]
	bind $win.nv <Tab>      [mymethod Add]

	foreach w {.add .rem .l .nk .nv} {
	    if {![winfo exists $win$w]} continue
	    bindtags $win$w [linsert [bindtags $win$w] 1 $w]
	}
	return
    }

    method PresentWidgets {} {
	if {$options(-addremove)} {
	    set layout  $layout_full
	    set weightc $weightc_full
	    set weightr $weightr_full
	    set focus   $focus_full
	} else {
	    set layout  $layout_noar
	    set weightc $weightc_noar
	    set weightr $weightr_noar
	    set focus   $focus_noar
	}

	foreach {w col row stick padx pady rowspan colspan} $layout {
	    grid $win$w \
		-columnspan $colspan -column $col \
		-rowspan    $rowspan -row    $row \
		-padx $padx \
		-pady $pady \
		-sticky $stick
	}

	foreach {col weight} $weightc {
	    grid columnconfigure $win $col -weight $weight
	}

	foreach {row weight} $weightr {
	    grid rowconfigure $win $row -weight $weight
	}

	set tips [list             \
	   $win     $_mc(main)     \
	   $win.add $_mc(add)      \
	   $win.rem $_mc(remove)   \
	   $win.nk  $_mc(entrykey) \
	   $win.nv  $_mc(entryval) \
	   $win.l   $_mc(list)     \
	  ]

	tipstack::def $tips

	focus $win$focus
	return
    }

    typevariable focus_full .add
    typevariable weightc_full {0 0  1 1  2 0}
    typevariable weightr_full {0 0  1 0  2 0  3 1}
    typevariable layout_full {
	.add  2 1  wen 1m 1m 1 1
	.rem  2 2  wen 1m 1m 1 1
	.nk   0 0 swen 1m 1m 1 1
	.nv   1 0 swen 1m 1m 1 1
	.l    0 1 swen 1m 1m 3 2
    }

    typevariable focus_noar .l.t
    typevariable weightc_noar {0 1}
    typevariable weightr_noar {0 1}
    typevariable layout_noar {
	.l    0 0 swen 1m 1m 1 1
    }

    method MC {tree} {
	treectrl $tree \
	    -borderwidth 0 -showheader 1 -xscrollincrement 20 \
	    -highlightthickness 0 -width 310 -height 400

	$tree debug configure -enable no -display no \
		-erasecolor pink -displaydelay 30

	# Details ____________________________

	set height [Height $tree]

	$tree configure -showroot no -showbuttons no -showlines no \
		-itemheight $height -selectmode extended \
		-xscrollincrement 20 -scrollmargin 16 \
		-xscrolldelay {500 50} \
		-yscrolldelay {500 50}

	# Columns

	Column $tree 0 $options(-titlek) key -width 100
	Column $tree 1 $options(-titlev) val -expand 1

	# Elements -> Styles -> Columns

	$tree element create e_txt text -lines 1 \
	    -fill [list $::syscolor::highlightText {selected focus}]
	 
	$tree element create e_sel rect -showfocus yes \
	    -fill [list \
		       $::syscolor::highlight {selected focus} \
		       gray                   {selected !focus}]

	# Styles -> Columns

	# column 0,1 = Key,Value: text
	# Bug 87674: Two styles, although identical in layout, to
	# allow separate state changes when editing, i.e. affect only
	# the edited column, not the other.

	set S [$tree style create s_ktext]
	$tree style elements $S {e_sel e_txt}
	$tree style layout   $S e_txt -padx 6 -squeeze x -expand ns
	$tree style layout   $S e_sel -union {e_txt} -iexpand nsew -ipadx 2

	set S [$tree style create s_vtext]
	$tree style elements $S {e_sel e_txt}
	$tree style layout   $S e_txt -padx 6 -squeeze x -expand ns
	$tree style layout   $S e_sel -union {e_txt} -iexpand nsew -ipadx 2

	# Set up in-place editing of values.

	$tree notify install <Edit-begin>
	$tree notify install <Edit-end>
	$tree notify install <Edit-accept>

	TreeCtrl::SetEditable $tree {{key s_ktext e_txt}}
	TreeCtrl::SetEditable $tree {{val s_vtext e_txt}}

	# During editing, hide the text and selection-rectangle elements.
	# Bug 87674: Two edit state, one per editable column.

	$tree state define editk
	$tree style layout s_ktext e_txt -draw {no editk}
	$tree style layout s_ktext e_sel -draw {no editk}

	$tree state define editv
	$tree style layout s_vtext e_txt -draw {no editv}
	$tree style layout s_vtext e_sel -draw {no editv}

	# Disable "scan" bindings on windows.
	if {$::tcl_platform(platform) eq "windows"} {
	    bind $tree <Control-ButtonPress-3> { }
	}

	bind $tree <Delete> [mymethod Remove]

	# In-place editing

	bindtags $tree [list $tree DictEntryEdit TreeCtrl [winfo toplevel $tree] all]

	$tree notify bind $tree <Edit-begin>  [mymethod DE_Begin  %T %I %C %E]
	$tree notify bind $tree <Edit-end>    [mymethod DE_End    %T %I %C %E]
	$tree notify bind $tree <Edit-accept> [mymethod DE_Accept %T %I %C %E %t]

	# Selection tracing

	$tree notify bind $tree <Selection> [mymethod OnSelection]

	return $tree
    }

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

    proc setkey {w k command} {
	bind $w <Key-$k> $command
	foreach c [winfo children $w] {
	    setkey $c $k $command
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Management of the tree (new item, regeneration, item <-> key mapping)

    variable data -array {} ; # map: item -> dict key
    variable xdat -array {} ; # map: dict key -> item

    method RefreshTree {k} {
	Refresh $win.l.t current

	# Select the key which caused the refresh, i.e. resorting.
	$win.l.t selection add $xdat($k)
	return
    }

    proc Refresh {tree cv} {
	upvar 1 $cv current data data options options xdat xdat
	$tree item delete first last
	array unset data *
	array unset xdat *

	if {![llength $options(-sort)]} {
	    set names [lsort -dict [array names current]]
	} else {
	    set names [uplevel \#0 [linsert $options(-sort) end [array names current]]]
	}

	foreach k $names {
	    NewItem $tree $k $current($k)
	}
	return
    }

    proc NewItem {tree k v} {
	upvar 1 data data xdat xdat
	set newitem [$tree item create]

	$tree item lastchild 0 $newitem
	$tree collapse         $newitem
	$tree item configure   $newitem -button 0 -visible 1
	$tree item style set   $newitem 0 s_ktext 1 s_vtext
	$tree item element configure $newitem \
	    0 e_txt -text $k , \
	    1 e_txt -text $v

	set data($newitem) $k ; # item -> key mapping for selection handling
	set xdat($k) $newitem ; # and reverse
	return
    }

    # ### ### ### ######### ######### #########
    ## Button callbacks (Add, Remove)

    method Add {} {
	if {[$win.add cget -state] eq "disabled"} return

	if {[llength $options(-transformk)]} {
	    set _key [uplevel \#0 [linsert $options(-transformk) end $_key]]
	}
	if {[llength $options(-transformv)]} {
	    set _val [uplevel \#0 [linsert $options(-transformv) end $_val]]
	}

	set current($_key) $_val ; # Implied Export.
	$self RefreshTree $_key  ; # Regen display and highlight new entry.

	set _key ""
	set _val ""

	$self Contents?

	focus $win.nk
	return
    }

    method Remove {} {
	if {[$win.rem cget -state] eq "disabled"} return

	set selection [$win.l.t selection get]
	if {![llength $selection]} return

	# Block export of each change as is
	set lock   1
	set change 0

	foreach i $selection {
	    set k $data($i)

	    if {![$self Removable $k]} continue

	    $win.l.t item delete $i
	    unset data($i)
	    unset xdat($k)
	    unset current($k)
	    set change 1
	}

	# Export all changes in one go, if there are any.
	set lock 0
	if {$change} {$self Export}
	$self Contents?
	return
    }

    method Removable {k} {
	if {![llength $options(-removable)]} {return 1}
	return [uplevel \#0 [linsert $options(-removable) end $k]]
    }

    # ### ### ### ######### ######### #########
    ## Trace selection and update widget state based on it.

    method OnSelection {} {
	if {[$self RemoveOk?]} {
	    $win.rem configure -state normal
	} else {
	    $win.rem configure -state disabled
	}
	return
    }

    method RemoveOk? {} {
	set sel [$win.l.t selection get]
	if {![llength $sel]} {return 0}
	foreach i $sel {
	    if {[$self Removable $data($i)]} {return 1}
	}
	return 0
    }

    # ### ### ### ######### ######### #########
    ## Internal validation callbacks

    # Ensure proper display of colors when one of entries gains or
    # looses focus.

    method FocusKeyOk? {args} {return [$self KeyOk?]}
    method FocusValOk? {args} {return [$self ValOk?]}

    # Basic validation, keys, values ...

    method KeyOk? {args} {
	if {[llength $options(-validk)]} {
	    set msg   [uplevel \#0 [linsert $options(-validk) end $_key]]
	    set valid [expr {$msg eq ""}]

	    if {!$valid} {
		set msge "$_mc(entrykey)\n$msg"
		set msga "$_mc(add)\n$msg"
	    }
	} else {
	    # Standard validation: Empty entry is not valid, everything else is.
	    set valid [expr {$_key ne ""}]
	    if {!$valid} {
		set msge "$_mc(entrykey)\n* Empty"
		set msga "$_mc(add)\n* Nothing to enter"
	    }
	}

	if {$valid} {
	    # One additional check. Is the current entry a duplicate
	    # of something already in the list ? If yes we do not
	    # accept the value.

	    if {[info exists current($_key)]} {
		set valid 0
		set msg "* The list already contains this item"
		set msge "$_mc(entrykey)\n$msg"
		set msga "$_mc(add)\n$msg"
	    }
	}

	if {$valid} {
	    tipstack::pop $win.nk
	    tipstack::pop $win.add
	    $win.add configure -state normal
	    $win.nk  state !invalid
	} else {
	    tipstack::pop  $win.nk
	    tipstack::push $win.nk $msge
	    tipstack::pop  $win.add
	    tipstack::push $win.add $msga
	    $win.add configure -state disabled
	    $win.nk  state invalid
	}

	return $valid
    }

    method ValOk? {args} {
	if {![$self KeyOk?]} {
	    set valid 0
	    set msge "$_mc(entryval)\nInvalid $options(-labelks)"
	    set msga ""

	} elseif {[llength $options(-validv)]} {
	    set msg   [uplevel \#0 [linsert $options(-validv) end $_val]]
	    set valid [expr {$msg eq ""}]

	    if {!$valid} {
		set msge "$_mc(entryval)\n$msg"
		set msga "$_mc(add)\n* Nothing to enter"
	    }
	} else {
	    # Standard validation: Everything is valid
	    set valid 1 
	}

	if {$valid} {
	    tipstack::pop $win.nv
	    tipstack::pop $win.add
	    $win.add configure -state normal
	    $win.nv  state !invalid
	} else {
	    tipstack::pop  $win.nv
	    tipstack::push $win.nv $msge
	    if {$msga ne ""} {
		tipstack::pop  $win.add
		tipstack::push $win.add $msga
	    }
	    $win.add configure -state disabled
	    $win.nv  state invalid
	}

	return $valid
    }

    method Contents? {} {
	if {[array size current]} {
	    tipstack::pop  $win.l
	} else {
	    tipstack::pop  $win.l
	    tipstack::push $win.l $_mc(list,empty)
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Handling dictionary changes (import from & export to
    ## the -dictvariable)

    variable lock 0

    method Import {args} {
	if {$lock} return
	upvar \#0 $options(-dictvariable) outside
	set lock 1 ; # Block re-export
	array unset current *
	array set   current $outside
	set lock 0
	if {[winfo exists $win.l.t]} {
	    Refresh $win.l.t current
	}
	return
    }

    method Export {args} {
	if {$lock} return
	upvar \#0 $options(-dictvariable) outside
	set lock 1 ; # Block re-import
	set outside [array get current]
	set lock 0
	return
    }

    # ### ### ### ######### ######### #########
    ## Option management

    method C-dictvar {option newvalue} {
	if {$newvalue eq $options($option)} return

	if {$options($option) ne {}} {
	    trace remove variable $options($option) {write} [mymethod Import]
	    array unset current *
	    if {[winfo exists $win.l.t]} {
		Refresh $win.l.t current
	    }
	}

	set options($option) $newvalue

	if {$options($option) ne {}} {
	    trace add variable $options($option) {write} [mymethod Import]
	    $self Import
	}
	return
    }

    method C-state {option newvalue} {
	# Ignore non-changes.
	if {$newvalue eq $options($option)} return
	switch -exact -- $newvalue {
	    normal -
	    disabled {
		$win.add configure -state $newvalue
		$win.rem configure -state $newvalue
		$win.nk  configure -state $newvalue
		$win.nv  configure -state $newvalue
	    
		# When enabling things we have to take the dynamic
		# state into account, like during construction.
		if {$newvalue eq "normal"} {
		    $self KeyOk?
		    $self ValOk?
		    $self Contents?
		}
	    }
	    default {
		return -code error "Bad state \"$newvalue\""
	    }
	}
	set options($option) $newvalue
	return
    }

    # Simple delegation not possible due to ordering
    method C-height {option newvalue} {
	# Ignore non-changes.
	if {$newvalue eq $options($option)} return
	if {[winfo exists $win.l.t]} {
	    $win.l.t configure -height $options(-height)
	}
	set options($option) $newvalue
	return
    }

    # Use of key label, singular
    onconfigure -labelks {newvalue} {
	set options(-labelks) $newvalue
	set _mc(add)      "Add a new ${newvalue}/$options(-labelvs)"
	set _mc(entrykey) "Enter a new ${newvalue}"
	return
    }

    # Use of value label, singular
    onconfigure -labelvs {newvalue} {
	set options(-labelvs) $newvalue
	set _mc(add)      "Add a new $options(-labelks)/${newvalue}"
	set _mc(entryval) "Enter a new ${newvalue}"
	return
    }

    # Use of key label, plural
    onconfigure -labelkp {newvalue} {
	set options(-labelkp) $newvalue
	set _mc(main)        "List of ${newvalue} and $options(-labelvp)"
	set _mc(remove)      "Remove the selected ${newvalue} from the list"
	set _mc(remove,none) "$_mc(remove)\n* Nothing selected for removal"
	set _mc(list)        $_mc(main)
	set _mc(list,empty)  "$_mc(list): Empty"
	return
    }

    # Use of value label, plural
    onconfigure -labelvp {newvalue} {
	set options(-labelvp) $newvalue
	set _mc(main)        "List of $options(-labelkp) and ${newvalue}"
	set _mc(list)        $_mc(main)
	set _mc(list,empty)  "$_mc(list): Empty"
	return
    }

    # ### ### ### ######### ######### #########
    ## Widget state

    variable _key           {} ; # Entry state, new key to add
    variable _val           {} ; # Entry state, value for new key to add.
    variable current -array {} ; # Current dict contents as array for easier access

    # Semi-constants for tooltip messages.
    # See onconfigure -label{s,p} above.

    variable _mc -array {
	main     {}
	add      {}
	remove   {}
	entrykey {}
	entryval {}
	list     {}
    }

    # ### ### ### ######### ######### #########
    ## Management of in-place editing (event callbacks, setup)

    typeconstructor {
	bind DictEntryEdit <Double-ButtonPress-1> \
	    "[myproc DE_Begin %W %x %y] ; break"
    }

    proc DE_Begin {w x y} {
	# Locate enclosing mega widget and dispatch action to it.
	set de [winfo parent [winfo parent $w]]
	$de DE_Start $x $y
    }

    method DE_Start {x y} {
	variable ::TreeCtrl::Priv
	set w $win.l.t

	if {$options(-editv) || $options(-editk)} {
	    set id [$w identify $x $y]
	    if {$id eq ""} return
	    if {[lindex $id 0] eq "item"} {
		lassign $id where item arg1 arg2
		if {$arg1 eq "column"} {
		    set col $arg2
		    if {
			([$w column compare $col == key] && $options(-editk)) ||
			([$w column compare $col == val] && $options(-editv))
		    } {
			DE_EditCancel $w
			set Priv(editId,$w) \
			    [after $Priv(edit,delay) [myproc DE_Edit $w $item $col e_txt]]
			return
		    }
		}
	    }
	}

	# Fallback to regular double-click processing
	::TreeCtrl::DoubleButton1 $w $x $y
	return
    }

    proc DE_Edit {T I C E} {
	variable ::TreeCtrl::Priv
	array unset Priv editId,$T

	# Scroll item into view
	$T see $I ; update

	::TreeCtrl::EntryExpanderOpen $T $I $C $E
	::TreeCtrl::TryEvent          $T Edit begin [list I $I C $C E $E]
	return
    }

    proc DE_EditCancel {T} {
	variable ::TreeCtrl::Priv
	if {[info exists Priv(editId,$T)]} {
	    after cancel $Priv(editId,$T)
	    array unset Priv editId,$T
	}
	return
    }

    # Bug 87674: Use edit state appropriate to the chosen column.
    # Further: Use absolute values (set, reset), instead of toggle.
    # The latter is brittle against additional events, which we happen
    # to get of Edit-end due to the state trace ripples and other
    # actions caused by committing the new text.

    method DE_Begin {T I C E} {
	if {$C == 0} {
	    $T item state set $I editk
	} else {
	    $T item state set $I editv
	}
	return
    }

    method DE_End {T I C E} {
	if {$C == 0} {
	    $T item state set $I !editk
	} else {
	    $T item state set $I !editv
	}
	return
    }

    method DE_Accept {T I C E new} {
	$T item element configure $I $C $E -text $new
	# Move the changed mapping into the widget state,
	# especially the connected variable.

	if {[$T column compare $C == val]} {

	    # Value of item changed, use item to locate the relevant
	    # key. Ignore non-changes.

	    if {$new eq $current($data($I))} return
	    set current($data($I)) $new
	    return
	}

	if {[$T column compare $C == key]} {

	    # Key of item changed. Use item to locate old key. This
	    # means that a key is removed/added/modified, check that
	    # the old key can be removed! If so this is done, else the
	    # edit transforms into just adding the new key, maybe
	    # replacing an existing setting of that key. The
	    # individual changes are not exported, only the whole
	    # transaction. This may also require a full refresh of the
	    # display.

	    if {[llength $options(-transformk)]} {
		set new [uplevel \#0 [linsert $options(-transformk) end $new]]
	    }

	    # Locate old key, ignore non-changes.
	    set old $data($I)
	    if {$new eq $old} return

	    set oldval $current($old)
	    set lock   1

	    # Cases
	    # 1 old removable, new exists   => unset old, write new, export, refresh
	    # 2 old removable, new missing  => unset old, write new, export, refresh
	    # 3 old !removable, new exists  =>            write new, export, refresh
	    # 4 old !removable, new missing =>            write new, export, refresh

	    # The refresh in case 3 is not necessary if we were taking
	    # only key existence into account, i.e. the new key simply
	    # replaces the old without fuss. However we sort the
	    # entries in some manner, and requires to refresh and
	    # resort as the new key may have to move to a different
	    # row.

	    if {[$self Removable $old]} {
		unset xdat($old)
		unset current($old)
	    }

	    set current($new) $oldval

	    set data($I) $new         ; # Update item -> key map
	    set xdat($new) $I         ; # This is transient, the refresh coming
	    #                         ; # up, see below may/will change everything
	    #                         ; # However we do not want bad data until
	    #                         ; # this kicks in, so the update here

	    set lock 0
	    $self Export
	    $self Contents?

	    after 1 [mymethod RefreshTree $new]
	}

	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
