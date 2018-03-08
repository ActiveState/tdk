# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package listentryb 1.0
# Meta platform    tcl
# Meta require     BWidget
# Meta require     snit
# Meta require     tile
# Meta require     tipstack
# Meta category	 Widget
# Meta subject	 widget {data entry} {list entry}
# Meta summary	 A widget to enter values into a list
# Meta description A megawidget for entering values into
# Meta description a list. Delivers all of listentry's
# Meta description features, and more. Allows
# Meta description transformation on entry, browsing for
# Meta description values, ordered list.
# @@ Meta End

# -*- tcl -*-
# listentry.tcl --
# -*- tcl -*-
#
#	Standard panel for managing a(n ordered) list of values.
#
# Copyright (c) 2006-2007 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Docs

# !TODO! See if we can use delegation for the -listvariable
#        stuff. Likely requires us to process -mru before
#        the other configuration options.

# ### ### ### ######### ######### #########
## Requisites

package require img::png
package require image ; image::file::here
package require snit                ; # Tcllib, OO core.
package require tile                ; # Theming support.
package require BWidget             ; # Only for 'ScrolledWindow'
package require tipstack            ; # Tooltips.

ScrolledWindow::use

# ### ### ### ######### ######### #########
## Implementation

snit::widget listentryb {
    hulltype ttk::frame

    # ### ### ### ######### ######### #########
    ## API. Definition

    option -listvariable {} ; # Variable the managed list is exported to.
    option -values       {} ; # Callback to read/store list of values to 
    #                       ; # enter. May connect to preferences, for
    #                       ; # example. Define this at creation time!
    #                       ; # If set a combo-entry is used for entering values, otherwise a
    #                       ; # entry widget.

    option -labels {} ; # Name of list items, singular
    option -labelp {} ; # Name of list items, plural

    option -valid {} ; # Validation callback.
    #                ; # Executed with current text as argument.
    #                ; # Text result. Empty     => Ok.
    #                ; #              Otherwise => The error message

    option -transform {} ; # Transformation callback.
    #                    ; # Executed with current text as argument (valid!)
    #                    ; # Result is text to actually add.

    option -browseimage {}
    option -ordered 1
    option -browse  1
    option -browsecmd {}

    option -state  -default normal -configuremethod C-state
    option -height -default 20     -configuremethod C-height

    # ### ### ### ######### ######### #########
    ## API. Implementation

    constructor {args} {
	# DEBUG # $hull configure -relief raised -bd 2 -bg coral

	# Handle initial options, then create the interface.

	$self configurelist $args
	$self MakeWidgets

	trace add variable [myvar _text] {write} [mymethod Ok?]

	set lastdir [pwd]
	set _text   {}

	# Fire initial validations.
	$self Ok?
	$self Select?
	$self Contents?
	return
    }

    destructor {
	trace remove variable [myvar _text] {write} [mymethod Ok?]
	tipstack::clearsub $win
	return
    }

    # ### ### ### ######### ######### #########

    method MakeWidgets {} {
	if {$options(-browse)} {
	    if {$options(-browseimage) != {}} {
		ttk::button $win.brw  -command [mymethod BrowseDir] -image $options(-browseimage)
	    } else {
		ttk::button $win.brw  -command [mymethod BrowseDir] -text "Browse..." -width 8
	    }
	}

	ttk::button    $win.add  -command [mymethod Add]       -text "Add"    -image [image::get add]  -state disabled
	ttk::button    $win.rem  -command [mymethod Remove]    -text "Remove" -image [image::get delete]
	ScrolledWindow $win.l    -managed 0 -ipad 0 -scrollbar vertical -relief sunken -bd 1
	listbox        $win.l.l  -selectmode extended -height $options(-height) -bd 0

	if {$options(-ordered)} {
	    ttk::button  $win.up -command [mymethod MoveUp] -image [image::get up]
	    ttk::button  $win.dn -command [mymethod MoveDn] -image [image::get down]
	}

	$win.l setwidget $win.l.l

	if {$options(-listvariable) ne ""} {
	    $win.l.l configure -listvariable $options(-listvariable)
	}

	bind $win.l.l <<ListboxSelect>> [mymethod Select?]

	if {[llength $options(-values)]} {
	    ttk::combobox $win.e -values [$self vget]
	} else {
	    # Using the validation callbacks to ensure that the
	    # display is correct even after focus changes. Without
	    # that the state changes caused by the focus change may
	    # cause the entry to be shown as valid despite
	    # being invalid (bg color wrong).

	    ttk::entry $win.e \
		-validate        focus \
		-validatecommand [mymethod FocusOk?]
	}

	$win.e configure -textvariable [myvar _text] -width 50

	foreach w {.add .rem .l .e .up .dn} {
	    if {![winfo exists $win$w]} continue
	    bindtags $win$w [linsert [bindtags $win$w] 1 $w]
	}
	bindtags $win.l.l [list $win.l.l $win Listbox [winfo toplevel $win] all]

	setkey $win Return   [mymethod Add]
	setkey $win KP_Enter [mymethod Add]
	setkey $win Delete   [mymethod Remove]
	if {$options(-ordered)} {
	    setkey $win Up   [mymethod MoveUp]
	    setkey $win Down [mymethod MoveDn]
	}

	foreach {w col row stick padx pady rowspan colspan} {
	    .brw  2 0   wn 1m 1m 1 1
	    .add  2 1  wen 1m 1m 1 1
	    .rem  2 2  wen 1m 1m 1 1
	    .e    1 0 swen 1m 1m 1 1
	    .l    1 1 swen 1m 1m 3 1
	    .up   0 1   e  1m 1m 1 1
	    .dn   0 2   e  1m 1m 1 1
	} {
	    if {![winfo exists $win$w]} continue
	    grid $win$w \
		-columnspan $colspan -column $col \
		-rowspan    $rowspan -row    $row \
		-padx $padx \
		-pady $pady \
		-sticky $stick
	}
	foreach {col weight} {0 0  1 1  2 0} {
	    grid columnconfigure $win $col -weight $weight
	}
	foreach {row weight} {0 0  1 0  2 0  3 1} {
	    grid rowconfigure $win $row -weight $weight
	}

	set tips [list \
	   $win     $_mc(main) \
	   $win.add $_mc(add) \
	   $win.rem $_mc(remove) \
	   $win.e   $_mc(entry) \
	   $win.l   $_mc(list) \
	   $win.up  {} \
	   $win.dn  {} \
	  ]
	if {$options(-browse)} {
	    lappend tips $win.brw $_mc(brw)
	}
	if {$options(-ordered)} {
	    lappend tips $win.up $_mc(mup)
	    lappend tips $win.dn $_mc(mdn)
	}

	tipstack::def $tips

	if {$options(-ordered)} {
	    $self HandleMoves
	}
	return
    }

    # ### ### ### ######### ######### #########

    variable lastdir {}
    method BrowseDir {} {

	if {[llength $options(-browsecmd)]} {
	    set path [eval [linsert $options(-browsecmd) end \
				$win \
				-title      $_mc(brwt) \
				-parent     $win]]
	    if {$path == {}} {return}
	} else {
	    set path [tk_chooseDirectory \
			  -title      $_mc(brwt) \
			  -parent     $win \
			  -initialdir $lastdir]
	    if {$path == {}} {return}
	    set lastdir [file dirname $path]
	}

	set _text $path
	$self Add
	return
    }

    method Add {} {
	if {[$win.add cget -state] eq "disabled"} return
	if {[lsearch -exact [$win.l.l get 0 end] $_text] >= 0} return

	if {[llength $options(-transform)]} {
	    set _text [uplevel \#0 [linsert $options(-transform) end $_text]]
	}

	$win.l.l insert end $_text
	$win.l.l see    end
	$self SaveMRU       $_text

	set _text ""

	$self Contents?
	return
    }

    method Remove {} {
	if {[$win.rem cget -state] eq "disabled"} return

	foreach idx [lsort -integer -decreasing \
			 [$win.l.l curselection]] {
	    $win.l.l delete $idx
	}

	$self Contents?
	return
    }

    method MoveUp {} {
	if {[string equal [$win.up cget -state] disabled]} {
	    return
	}
	foreach idx [lsort -integer -increasing [$win.l.l curselection]] {
	    set el [$win.l.l get $idx] ; $win.l.l selection clear $idx
	    $win.l.l delete $idx
	    incr idx -1
	    $win.l.l insert $idx $el ; $win.l.l selection set $idx
	}
	$self HandleMoves
	return
    }

    method MoveDn {} {
	if {[string equal [$win.dn cget -state] disabled]} {
	    return
	}
	foreach idx [lsort -integer -decreasing [$win.l.l curselection]] {
	    set el [$win.l.l get $idx] ; $win.l.l selection clear $idx
	    $win.l.l delete $idx
	    incr idx
	    $win.l.l insert $idx $el ; $win.l.l selection set $idx
	}
	$self HandleMoves
	return
    }

    method HandleMoves {} {
	$win.up configure -state normal
	$win.dn configure -state normal

	set nodes [lsort -integer -increasing [$win.l.l curselection]]

	if {![llength $nodes]} {
	    $win.up configure -state disabled
	    $win.dn configure -state disabled
	    return
	}

	if {[lindex $nodes 0] == 0} {
	    # Can't go up
	    $win.up configure -state disabled
	}

	if {[lindex $nodes end] == [expr {[$win.l.l index end]-1}]} {
	    # Can't go down
	    $win.dn configure -state disabled
	}
	return
    }


    method Select? {args} {
	if {[llength [$win.l.l curselection]]} {
	    tipstack::pop  $win.rem
	    $win.rem configure -state normal
	} else {
	    tipstack::pop  $win.rem
	    tipstack::push $win.rem $_mc(remove,none)
	    $win.rem configure -state disabled
	}
	if {![winfo exists $win.up]} return
	$self HandleMoves
	return
    }

    method Contents? {} {
	if {[$win.l.l size]} {
	    tipstack::pop  $win.l
	} else {
	    tipstack::pop  $win.l
	    tipstack::push $win.l $_mc(list,empty)
	}
	return
    }

    method FocusOk? {args} {
	# Ensure proper display of colors when the entry gains or
	# looses focus.
	return [$self Ok?]
    }

    method Ok? {args} {
	if {[llength $options(-valid)]} {
	    set msg   [uplevel \#0 [linsert $options(-valid) end $_text]]
	    set valid [expr {$msg eq ""}]

	    if {!$valid} {
		set msge "$_mc(entry)\n$msg"
		set msga "$_mc(add)\n$msg"
	    }
	} else {
	    # Standard validation: Empty entry is not valid, everything else is.
	    set valid [expr {$_text ne ""}]
	    if {!$valid} {
		set msge "$_mc(entry)\n* Empty"
		set msga "$_mc(add)\n* Nothing to enter"
	    }
	}

	if {$valid} {
	    # One additional check. Is the current entry a duplicate
	    # of something already in the list ? If yes we do not
	    # accept the value.

	    if {[lsearch -exact [$win.l.l get 0 end] $_text] >= 0} {
		set valid 0
		set msg "* The list already contains this item"
		set msge "$_mc(entry)\n$msg"
		set msga "$_mc(add)\n$msg"
	    }
	}

	if {$valid} {
	    tipstack::pop $win.e
	    tipstack::pop $win.add
	    $win.add configure -state normal
	    $win.e   state !invalid
	} else {
	    tipstack::pop  $win.e
	    tipstack::push $win.e $msge
	    tipstack::pop  $win.add
	    tipstack::push $win.add $msga
	    $win.add configure -state disabled
	    $win.e   state invalid
	}

	return $valid
    }

    method SaveMRU {text} {
	if {![llength $options(-values)]} return
	set values [$win.e cget -values]

	set pos [lsearch -exact $values $text]
	if {$pos < 0} {
	    # Insert at front
	    set values [linsert $values 0 $text]
	} else {
	    # Exists in the list, move to front.

	    set values [linsert [lreplace $values $pos $pos] 0 $text]
	}

	$win.e configure -values $values
	$self vsave              $values
	return	
    }


    method vget {} {
	if {![llength $options(-values)]} return
	return [uplevel \#0 [linsert $options(-values) end get]]
    }

    method vsave {list} {
	if {![llength $options(-values)]} return
	uplevel \#0 [linsert $options(-values) end set $list]
	return
    }

    # ### ### ### ######### ######### #########

    proc setkey {w k command} {
	bind $w <Key-$k> $command
	foreach c [winfo children $w] {
	    setkey $c $k $command
	}
	return
    }

    # ### ### ### ######### ######### #########
    # Option management

    onconfigure -listvariable {newvalue} {
	if {$newvalue eq $options(-listvariable)} return
	set options(-listvariable) $newvalue

	if {![winfo exists $win.l.l]} return
	$win.l.l configure -listvariable $newvalue
	return
    }

    # Use of label, singular
    onconfigure -labels {newvalue} {
	set _mc(brwt)  "Select ${newvalue}"
	set _mc(brw)   "Browse for ${newvalue} to add"
	set _mc(add)   "Add a new ${newvalue} to the list"
	set _mc(entry) "Enter a new ${newvalue}"
	set _mc(mup)   "Move the selected ${newvalue} one entry up"
	set _mc(mdn)   "Move the selected ${newvalue} one entry down"
	return
    }

    # Use of label, plural
    onconfigure -labelp {newvalue} {
	set _mc(main)        "List of ${newvalue}"
	set _mc(remove)      "Remove the selected ${newvalue} from the list"
	set _mc(remove,none) "$_mc(remove)\n* Nothing selected for removal"
	set _mc(list)        $_mc(main)
	set _mc(list,empty)  "$_mc(list): Empty"
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
		$win.e   configure -state $newvalue

		if {$options(-browse)} {
		    $win.brw configure -state $newvalue
		}
		if {$options(-ordered)} {
		    $win.up configure -state $newvalue
		    $win.dn configure -state $newvalue
		}
	    
		# When enabling things we have to take the dynamic
		# state into account, like during construction.
		if {$newvalue eq "normal"} {
		    $self Ok?
		    $self Select?
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
	if {[winfo exists $win.l.l]} {
	    $win.l.l configure -height $options(-height)
	}
	set options($option) $newvalue
	return
    }

    # ### ### ### ######### ######### #########

    variable _text   {}

    # Semi-constants for tooltip messages.
    # See onconfigure -label{s,p}

    variable _mc -array {
	main   {}
	add    {}
	remove {}
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
