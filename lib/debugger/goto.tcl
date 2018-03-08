# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# goto.tcl --
#
#	This file implements the Find and Goto Windows.  The find
#	namespace and associated code are at the top portion of
#	this file.  The goto namespace and associated files are 
#	at the bottom portion of this file.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: find.tcl,v 1.3 2000/10/31 23:30:58 welch Exp $

# ### ### ### ######### ######### #########

package require tile
package require snit

# ### ### ### ######### ######### #########

snit::type goto {
    # Handles to the Goto Window's widgets.

    variable choiceVar
    variable lineEnt
    variable gotoBut

    # The selected option in the combobox.

    variable choiceVar

    # The list of goto option in the choice combobox.

    variable gotoOptions  [list "Move Up Lines" "Move Down Lines" "Goto Line"]

    # ### ### ### ######### ######### #########

    variable             code
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set code    [$gui code]
	return
    }

    # ### ### ### ######### ######### #########

    # method showWindow --
    #
    #	Show the Goto Window.  If it dosent exist, then create it.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The toplevel handle to the Goto Window.

    method showWindow {} {
	# If the window already exists, show it, otherwise
	# create it from scratch.

	set top [$gui gotoDbgWin]
	if {[winfo exists $top]} {
	    wm deiconify $top
	} else {
	    $self createWindow
	}
	focus $lineEnt
	return $top
    }

    # method createWindow --
    #
    #	Create the Goto Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    variable choiceBox
    variable lineVar

    method createWindow {} {
	set pad 6

	set                        top [toplevel [$gui gotoDbgWin]]
	::guiUtil::positionWindow $top
	wm resizable              $top 0 0 ; # dont allow resize
	wm title                  $top "Goto - [$gui cget -title]"
	wm transient              $top $gui

	set mainFrm [ttk::frame $top.mainFrm -padding 8]

	set choiceBox [ttk::combobox $mainFrm.choiceBox -state readonly \
			   -values $gotoOptions -width 18 \
			   -textvariable [myvar choiceVar]]
	set lineLbl   [ttk::label $mainFrm.lineLbl \
			   -textvariable [myvar lineVar]]
	bind $choiceBox <<ComboboxSelected>> [mymethod updateLabels]
	set choiceVar [lindex $gotoOptions end]
	set lineVar " line "
	set lineEnt [ttk::entry $mainFrm.lineEnt]

	set placeFrm [ttk::frame $mainFrm.placeFrm]
	set gotoBut [ttk::button $placeFrm.gotoBut \
			 -textvariable [myvar choiceVar] -default active \
			 -command [mymethod execute]]
	set closeBut [ttk::button $placeFrm.closeBut -text "Close" \
			  -default normal -command [list destroy $top]]

	grid x $gotoBut $closeBut -sticky e -padx [list $pad 0]
	grid columnconfigure $placeFrm 0 -weight 1

	grid $choiceBox $lineLbl $lineEnt
	grid $placeFrm -sticky ew -columnspan 3 -pady $pad
	grid columnconfigure $mainFrm 2 -weight 1

	pack $mainFrm -fill both -expand true

	bind::addBindTags $choiceBox gotoDbgWin$self
	bind::addBindTags $lineEnt   gotoDbgWin$self
	bind::addBindTags $gotoBut   gotoDbgWin$self
	bind::commonBindings gotoDbgWin$self [list $choiceBox $lineEnt \
		$gotoBut $closeBut]

	bind gotoDbgWin$self <Return> "$gotoBut invoke; break"
	bind gotoDbgWin$self <Escape> "$closeBut invoke; break"

	bind gotoDbgWin$self <Up>   [mymethod changeCombo -1]
	bind gotoDbgWin$self <Down> [mymethod changeCombo 1]
    }

    # method updateLabels --
    #
    #	Make the button label and line label consistent 
    #	with the current goto option.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateLabels {} {
	set option [lsearch $gotoOptions $choiceVar]
	switch $option {
	    0 {
		# Move up lines.
		set lineVar " # of lines "
	    }
	    1 {
		# Move down lines.
		set lineVar " # of lines "
	    }
	    2 {
		# Goto line.
		set lineVar " line "
	    }
	}
    }

    # method execute --
    #
    #	Execute the goto request.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method execute {} {
	if {[$gui getCurrentBlock] == {}} {
	    bell -displayof [$gui gotoDbgWin]
	    return
	}

	# Get the line number and verify that it is numeric.

	set line [$lineEnt get]
	if {$line == ""} {
	    return
	}

	set end [$code getCodeSize]
	if {[catch {incr line 0}]} {
	    if {$line == "end"} {
		set line $end
	    } else {
		bell -displayof [$gui gotoDbgWin]
		$lineEnt delete 0 end
		return
	    }
	}

	set option [lsearch $gotoOptions $choiceVar]
	switch $option {
	    0 {
		# Move up lines.
		set start  [$code getInsertLine]
		set moveTo [expr {$start - $line}]
		if {$moveTo > $end} {
		    set moveTo $end
		}
		set loc [$code makeCodeLocation [$code text] $moveTo.0]
	    }
	    1 {
		# Move down lines.
		set start  [$code getInsertLine]
		set moveTo [expr {$start + $line}]
		if {$moveTo > $end} {
		    set moveTo $end
		}
		set loc [$code makeCodeLocation [$code text] $moveTo.0]
	    }
	    2 {
		# Goto line.
		if {$line > $end} {
		    set line $end
		}
		set loc [$code makeCodeLocation [$code text] $line.0]
	    }
	}
	$gui showCode $loc
    }

    # method changeCombo --
    #
    #	Callback to cycle the choice in the combobox.
    #
    # Arguments:
    #	amount	The number of choice to increment.
    #
    # Results:
    #	None.

    method changeCombo {amount} {
	set index [expr {[lsearch $gotoOptions $choiceVar] + $amount}]
	set length [llength $gotoOptions]
	if {$index < 0} {
	    set index [expr {$length - 1}]
	} elseif {$index >= $length} {
	    set index 0
	}
	$choiceBox set [lindex $gotoOptions $index]
	updateLabels
	return
    }
}

# ### ### ### ######### ######### #########

package provide goto 1.0
