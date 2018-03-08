# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# inspectorWin.tcl --
#
#	This file implements the Inspector Window.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

#
# RCS: @(#) $Id: inspectorWin.tcl,v 1.4 2000/10/31 23:30:58 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require widget::scrolledwindow
package require fmttext
package require transform
package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type inspector {
    variable entVar   {}
    variable nameVar  {}
    variable levelVar {}
    variable viewVar  {}

    variable varText
    variable choiceBox

    variable levelCache {}
    variable nameCache  {}
    variable valueCache {}
    variable viewCache  {}

    variable dontLoop   0
    variable showResult 0

    # Bugzilla 19719 ... New variables to handle and store the display
    # transformation associated with the shown data.

    variable transVar     {} ; # Transformation chosen for displayed value
    variable transNameVar {} ; # Name of transformation, shown in dialog.
    variable transCache   {} ; # Last 'transVar'.
    
    # Bugzilla 19719 ... Holds the name of the transform chosen by the
    # user for the inspected variable.

    variable tsom

    # ### ### ### ######### ######### #########

    variable             dbg
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set engine_ [$gui cget -engine]
	set dbg     [$engine_ dbg]
	return
    }

    # ### ### ### ######### ######### #########

    # method showVariable --
    #
    #	Popup an Inspector window to display info on the selected 
    #	variable.
    #
    # Arguments:
    #	name	The variable name to show.
    #	level	The stack level containing the variable.
    #	trans	The id of the transformation to apply to the value
    #		of the variable before actually displaying it.
    #
    # Results:
    #	None.

    method showVariable {name level trans} {
	if {[$gui getCurrentState] != "stopped"} {
	    return
	}

	# If the window already exists, show it, otherwise
	# create it from scratch.

	if {![winfo exists [$gui dataDbgWin]]} {
	    $self createWindow
	}

	set showResult 0
	set entVar     [code::mangle $name]
	set nameVar    $entVar
	set levelVar   $level

	# Bugzilla 19719 ... Remember transformation given to us by Watch
	# Variables or Variable window, update the transform selector in
	# this dialog too.

	set transVar     $trans
	set transNameVar [transform::getTransformName $trans]
	set tsom         $transNameVar

	$self updateWindow 1

	wm deiconify [$gui dataDbgWin]
	focus        [$gui dataDbgWin]
	return       [$gui dataDbgWin]
    }

    # method updateVarFromEntry --
    #
    #	Update the Data Display to show the variable named in the 
    #	entry widget.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateVarFromEntry {} {
	set showResult 0
	set entVar     [code::mangle $entVar]
	set nameVar    $entVar
	set levelVar   [$gui getCurrentLevel]

	# Bugzilla 19719 ... Remember selected transform.
	set transVar     [transform::getTransformId $tsom]
	set transNameVar $tsom

	$self updateWindow 1
	return
    }

    # method showResult --
    #
    #	Popup an Inspector window to display info on the current
    #	interpreter result value.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method showResult {} {
	if {[$gui getCurrentState] != "stopped"} {
	    return
	}

	# If the window already exists, show it, otherwise
	# create it from scratch.

	if {![winfo exists [$gui dataDbgWin]]} {
	    $self createWindow
	}

	# Set the inspector into showResult mode and refesh the window.

	set showResult 1
	set entVar {}
	set nameVar "<Interpreter Result>"
	set levelVar [$dbg getLevel]

	# Bugzilla 19719 ... Results have no transformation, update displayed name
	set transVar     {}
	set transNameVar [transform::getTransformName $transVar]

	$self updateWindow 1

	wm deiconify [$gui dataDbgWin]
	focus        [$gui dataDbgWin]
	return       [$gui dataDbgWin]
    }

    # method createWindow --
    #
    #	Create an Inspector window that displays info on
    #	a particular variable and allows the variables 
    #	value to be changed and variable breakpoints to
    #	be set and unset.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method createWindow {} {
	set                        top [toplevel [$gui dataDbgWin]]
	::guiUtil::positionWindow $top 400x250
	wm minsize                $top 100 100
	wm title                  $top "Data Display - [$gui cget -title]"
	wm transient              $top $gui
	wm resizable              $top 1 1

	set pad 6

	# Create the info frame that displays the level and name.

	set mainFrm [ttk::frame $top.mainFrm]

	# Create the entry for adding new Watch variables.

	set inspectFrm [ttk::frame $mainFrm.inspectFrm]
	set inspectLbl [ttk::label $inspectFrm.inspectLbl -anchor w -text "Variable:"]
	set inspectEnt [ttk::entry $inspectFrm.inspectEnt -textvariable [varname entVar]]
	set inspectBut [ttk::button $inspectFrm.inspectBut -text "Display" -width 8 \
		-command [mymethod updateVarFromEntry]]
	set closeBut [ttk::button $inspectFrm.closeBut -text "Close" -width 8 \
		-command [list destroy $top]]

	# Bugzilla 19719 ... Added option menu for selection of
	# transformation to dialog, plus display of the name of the
	# transformation used to convert the shown values.

	set tsomLbl [ttk::label $inspectFrm.tsomLbl -anchor w -text "Display:"]
	set tsom [transform::transformSelectorOM $inspectFrm.tsom [varname tsom]]

	grid $inspectLbl -row 0 -column 0
	grid $inspectEnt -row 0 -column 1 -padx $pad -sticky we
	grid $inspectBut -row 0 -column 2
	grid $closeBut   -row 0 -column 3 -padx $pad
	grid $tsomLbl    -row 1 -column 0 -sticky we
	grid $tsom       -row 1 -column 1 -sticky we -padx $pad

	grid columnconfigure $inspectFrm 1 -weight 1

	set dataFrm  [ttk::frame $mainFrm.infoFrm]
	set infoFrm  [ttk::frame $dataFrm.infoFrm]
	set nameTitleLbl [ttk::label $infoFrm.nameTitleLbl -text "Variable Name:" ]
	set nameLbl [ttk::label $infoFrm.nameLbl -justify left \
		-textvariable [varname nameVar]]
	set levelTitleLbl [ttk::label $infoFrm.levelTitleLbl -text "Stack Level:" ]
	set levelLbl [ttk::label $infoFrm.levelLbl -justify left \
		-textvariable [varname levelVar]]
	set transLbl [ttk::label $infoFrm.transLbl -justify left \
		-textvariable [varname transNameVar]]

	pack $nameTitleLbl  -pady 3         -side left
	pack $nameLbl       -padx 3 -pady 3 -side left
	pack $levelTitleLbl -pady 3         -side left
	pack $levelLbl      -padx 3 -pady 3 -side left
	pack $transLbl      -padx 3 -pady 3 -side left

	# Place a separating line between the var info and the 
	# value of the var.

	set sep1Frm [ttk::separator $dataFrm.sep1 -orient horizontal]

	set choiceFrm [ttk::frame $dataFrm.choiceFrm]
	set choiceLbl [ttk::label $choiceFrm.choiceLbl -text "View As:" ]
	set choiceBox [ttk::combobox $choiceFrm.choiceCombo \
			   -textvariable [varname viewVar] -state readonly]
	bind $choiceBox <<ComboboxSelected>> [mymethod updateWindow 0]

	$choiceBox configure -values {Array List {Raw Data} {Line Wrap}}

	set viewVar "Line Wrap"
	pack $choiceLbl -pady 3         -side left
	pack $choiceBox -padx 3 -pady 3 -side left

	# Place a separating line between the var info and the value.

	set sep2Frm [ttk::separator $dataFrm.sep2 -orient horizontal]

	# Create an empty frame that will be populated in the updateWindow 
	# routine.

	set varFrm  [widget::scrolledwindow $dataFrm.varFrm \
			 -borderwidth 1 -relief sunken]
	set varText [text $varFrm.varText -width 1 -height 2 \
			 -borderwidth 0 -highlightthickness 0]
	$varFrm setwidget $varText

	pack $infoFrm -padx $pad -pady $pad -fill x
	pack $sep1Frm  -padx $pad -fill x
	pack $choiceFrm -padx $pad -pady $pad -fill x
	pack $sep2Frm  -padx $pad -fill x
	pack $varFrm  -padx $pad -pady $pad -expand true -fill both

	pack $dataFrm -padx $pad -pady $pad -fill both -expand true -side bottom
	pack $inspectFrm  -padx $pad -pady $pad -fill x -side bottom
	pack $mainFrm -fill both -expand true -side bottom

	fmttext::setDbgTextBindings $varText
	bind::addBindTags $varText [list noEdit dataDbgWin$self]
	bind::addBindTags $inspectEnt dataDbgWin$self
	bind::addBindTags $inspectBut dataDbgWin$self

	bind::commonBindings dataDbgWin$self [list $inspectEnt $inspectBut $varText]

	bind $inspectEnt <Return> "[mymethod updateVarFromEntry] ; break "
	return
    }

    # method updateWindow --
    #
    #	Update the display of the Inspector.  A Tcl variable
    # 	may be aliased with different names at different 
    #	levels, so update the name and level as well as the 
    #	value.
    #
    # Implicit Arguments (Namespace variable):
    #	name		The variable name.
    #	valu		The variable value.  If the variable is an 
    #			array, this is an ordered list of array
    #			index and array value.
    #	type		Variable type ('a' == array, 's' == scalar)
    #	level		The stack level of the variable.
    #
    # Results:
    #	None.

    method updateWindow {{setChoice 0}} {
	## puts "updateWindow (setChoice $setChoice)"

	if {![winfo exists [$gui dataDbgWin]]} {
	    return
	}
	if {[$gui getCurrentState] != "stopped"} {
	    return
	}

	if {$showResult} {
	    # Fetch the interpreter result and update the level
	    set type s
	    set value [lindex [$dbg getResult -1] 1]
	} else {
	    # Fetch the named variable
	    if {[catch {
		set varInfo [lindex [$dbg getVar $levelVar -1 [list $nameVar]] 0]
	    }]} {
		set varInfo {}
	    }
	    if {$varInfo == {}} {
		set type  s
		set value "<No-Value>"
	    } else {
		set type  [lindex $varInfo 1]
		set value [lindex $varInfo 2]
	    }
	}

	if {$setChoice} {
	    if {$type == "a"} {
		set viewVar "Array"
	    } else {
		set viewVar "Line Wrap"
	    }
	}
	set view [$choiceBox get]

	if {
	    ($nameVar  == $nameCache)  &&
	    ($levelVar == $levelCache) &&
	    ($value    == $valueCache) &&
	    ($transVar == $transCache) &&
	    ($view     == $viewCache)
	} {
	    if {[$varText get 1.0 1.1] != ""} {
		return
	    }
	}

	# Bugzilla 19719 ... Added execution of transformation before
	# inserting the values into the display.

	$varText delete 0.0 end
	switch $view {
	    "Raw Data" {
		$varText configure -wrap none -tabs {}
		foreach {tok data} [transform::transform $value $transVar] break
		# tok currently unused
		$varText insert 0.0 $data
	    }
	    "Line Wrap" {
		$varText configure -wrap word -tabs {}
		foreach {tok data} [transform::transform $value $transVar] break
		# tok currently unused
		$varText insert 0.0 $data
	    }
	    "List" {
		if {[catch {llength $value}]} {
		    # If we get an error in llength then we can't
		    # display as a list.

		    $varText insert end "<Not a valid list>"
		} else {
		    $varText configure -wrap none -tabs {}
		    foreach index $value {
			foreach {tok data} [transform::transform $index $transVar] break
			# tok currently unused
			$varText insert end "$data\n"
		    }
		}
	    } 
	    "Array" { 
		if {[catch {set len [llength $value]}] || ($len % 2)} {
		    # If we get an error in llength or we don't have
		    # an even number of elements then we can't
		    # display as an array.

		    $varText insert end "<Can't display as an array>"
		} else {
		    $varText configure -wrap none
		    
		    set line 1
		    set max 0
		    set maxLine 1
		    set nomax 1
		    foreach {entry index} $value {
			set entry [code::mangle $entry]
			$varText insert end "$entry \n"
			set len [string length $entry]
			if {$len > $max} {
			    set max $len
			    set maxLine $line
			}
			set nomax 0
			incr line
		    }

		    $varText see $maxLine.0
		    set maxWidth [lindex [$varText dlineinfo $maxLine.0] 2]
		    $varText delete 0.0 end
		    if {!$nomax} {
			$varText configure -tabs $maxWidth
		    }

		    array set temp $value

		    foreach entry [lsort -dictionary [array names temp]] {
			foreach {tok data} [transform::transform $temp($entry) $transVar] break
			# tok currently unused
			$varText insert end "$entry\t= $data\n"
		    }
		}
	    }
	    default {
		error "Unexpected view type \"$view\" in inspector::updateWindow"
	    }
	}
	
	set nameCache  $nameVar
	set levelCache $levelVar
	set valueCache $value
	set viewCache  $view
	set transCache $transVar
	return
    }
}

# ### ### ### ######### ######### #########
## Ready to go.

package provide inspector 1.0
