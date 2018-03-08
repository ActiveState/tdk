# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package listentry 1.0
# Meta platform    tcl
# Meta require     BWidget
# Meta require     snit
# Meta require     tile
# Meta require     tipstack
# Meta category	 Widget
# Meta subject	 widget {data entry} {list entry}
# Meta summary	 A widget to enter values into a list
# Meta description A megawidget for entering values into
# Meta description a list, unordered, i.e. set. No browsing.
# Meta description Validation is supported. Entry can be
# Meta description a combobox.
# @@ Meta End

# -*- tcl -*-
# listentry.tcl --
# -*- tcl -*-
#
#	Standard panel for managing a list of values.
#
# Copyright (c) 2006 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Docs

# !TODO! See if we can use delegation for the -listvariable
#        stuff. Likely requires us to process -mru before
#        the other configuration options.

# ### ### ### ######### ######### #########
## Requisites

package require snit                ; # Tcllib, OO core.
package require tile                ; # Theming support.
package require BWidget             ; # Only for 'ScrolledWindow'
package require tipstack            ; # Tooltips.

ScrolledWindow::use

# ### ### ### ######### ######### #########
## Implementation

snit::widget listentry {
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

    # ### ### ### ######### ######### #########
    ## API. Implementation

    constructor {args} {
	# DEBUG # $hull configure -relief raised -bd 2 -bg coral

	# Handle initial options, then create the interface.

	$self configurelist $args
	$self MakeWidgets

	trace add variable [myvar _text] {write} [mymethod Ok?]

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
	ttk::button    $win.add  -command [mymethod Add]    -text "Add" -state disabled
	ttk::button    $win.rem  -command [mymethod Remove] -text "Remove"
	ScrolledWindow $win.l    -managed 0 -ipad 0 -scrollbar vertical -relief sunken -bd 1
	listbox        $win.l.l  -selectmode extended -height 20 -bd 0

	$win.l setwidget $win.l.l

	if {$options(-listvariable) ne ""} {
	    $win.l.l configure -listvariable $options(-listvariable)
	}

	bind $win.l.l <<ListboxSelect>> [mymethod Select?]

	if {[llength $options(-values)]} {
	    ttk::combobox $win.e -values [$self vget]
	} else {
	    ttk::entry $win.e
	}

	$win.e configure -textvariable [myvar _text] -width 50

	foreach w {.add .rem .l .e} {
	    bindtags $win$w [linsert [bindtags $win$w] 1 $w]
	}
	bindtags $win.l.l [list $win.l.l $win Listbox [winfo toplevel $win] all]

	setkey $win Return   [mymethod Add]
	setkey $win KP_Enter [mymethod Add]
	setkey $win Delete   [mymethod Remove]

	foreach {w col row stick padx pady rowspan colspan} {
	    .add  2 0  wen 1m 1m 1 1
	    .rem  2 1  wen 1m 1m 1 1
	    .e    1 0 swen  1m 1m 1 1
	    .l    1 1 swen 1m 1m 3 1
	} {
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

	tipstack::def [list \
	   $win     $_mc(main) \
	   $win.add $_mc(add) \
	   $win.rem $_mc(remove) \
	   $win.e   $_mc(entry) \
	   $win.l   $_mc(list) \
	  ]

	return
    }

    # ### ### ### ######### ######### #########

    method Add {} {
	if {[$win.add cget -state] eq "disabled"} return
	if {[lsearch -exact [$win.l.l get 0 end] $_text] >= 0} return

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

    method Select? {args} {
	if {[llength [$win.l.l curselection]]} {
	    tipstack::pop  $win.rem
	    $win.rem configure -state normal
	} else {
	    tipstack::pop  $win.rem
	    tipstack::push $win.rem $_mc(remove,none)
	    $win.rem configure -state disabled
	}
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
	} else {
	    tipstack::pop  $win.e
	    tipstack::push $win.e $msge
	    tipstack::pop  $win.add
	    tipstack::push $win.add $msga
	    $win.add configure -state disabled
	}

	# !TODO! Find a way to colorize the entry based on the
	#        validation result.
	return
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
	set _mc(add)   "Add a new ${newvalue} to the list"
	set _mc(entry) "Enter a new ${newvalue}"
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
