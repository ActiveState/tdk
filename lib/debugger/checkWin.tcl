# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# checkWin.tcl --
#
#	This file implements the dialog to show syntax errors.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# SCCS: @(#) checkWin.tcl 1.16 98/05/02 14:01:16

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require icolist

# ### ### ### ######### ######### #########
## Implementation

snit::type checkWin {

    variable icoList {}

    # If the name of the file is empty, then it is assumed
    # to be a dynamic block.  Use this string to tell
    # the user.

    variable dynamicBlock {<Dynamic Block>}

    # map list items to code locations.

    variable lmap -array {}

    # ### ### ### ######### ######### #########

    variable             icon
    variable             checker
    variable             blkmgr
    variable             gui {}

    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set icon    [$gui icon]
	set checker [$gui checker]
	set engine_ [$gui cget -engine]
	set blkmgr  [$engine_ blk]
	return
    }

    # ### ### ### ######### ######### #########

    constructor {args} {
	$self configurelist $args
	return
    }

    # method showWindow --
    #
    #	Show the window to display syntax errors.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The handle top the toplevel window created.

    method showWindow {} {
	# If the window already exists, show it, otherwise create it
	# from scratch.

	set top [$gui synDbgWin]

	if {[winfo exists $top]} {
	    $self updateWindow
	    wm deiconify $top
	} else {
	    $self createWindow
	    $self updateWindow
	}    

	focus  $icoList
	return $top
    }

    # method createWindow --
    #
    #	Create the window that displays syntax errors.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    variable showBut
    variable remBut
    variable allBut

    method createWindow {} {
	set synDbgWin [toplevel [$gui synDbgWin]]

	::guiUtil::positionWindow $synDbgWin 400x250

	wm minsize   $synDbgWin 100 100
	wm title     $synDbgWin "Syntax errors - [$gui cget -title]"
	wm transient $synDbgWin $gui
	wm resizable $synDbgWin 1 1

	# Create the table that lists the found syntax errors.
	# This is a live, non-editable list that shows the
	# currently existing syntax errors. Add
	# buttons to the right for editing the table.

	set icoList   [icolist $synDbgWin.icoList \
			   -height 100 \
			   -columns  4 \
			   -headers {File Line Id Message} \
			   -tags     [list synDbgWin$self synDbgWin] \
			   -onselect [mymethod checkState] \
			   -statemap {
			       error   syn_error_s
			       warning warning
			   }]

	set butFrm   [ttk::frame $synDbgWin.butFrm]
	set showBut  [ttk::button $butFrm.showBut -text "Show Code" \
		-command [mymethod showCode] -state disabled]
	set closeBut [ttk::button $butFrm.closeBut -text "Close" \
		-command [list destroy $synDbgWin]]

	set pad 3
	pack $showBut $closeBut -fill x -padx $pad -pady 3

	grid $icoList   -row 0 -column 0 -sticky nswe -padx $pad -pady $pad
	grid $butFrm    -row 0 -column 1 -sticky ns

	grid columnconfigure $synDbgWin 0 -weight 1
	grid rowconfigure    $synDbgWin 0 -weight 1

	bind::addBindTags $showBut synDbgWin$self

	bind::commonBindings synDbgWin$self \
	    [list [$icoList ourFocus] $showBut $closeBut]

	# Set-up the default and window specific bindings.

	bind synDbgWin$self <Double-1>       "[mymethod showCode] ; break"
	bind synDbgWin$self <<Dbg_ShowCode>> "[mymethod showCode] ; break"

	bind $synDbgWin <Escape> "$closeBut invoke; break"
	return
    }

    # method updateWindow --
    #
    #	Update the list of syntax errors so it shows the most
    # 	current representation of all syntax errors.  This proc
    #	should be called after the checkWin::showWindow, and after
    #	changes in the color information for messages.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateWindow {} {
	# If the window is not current mapped, then there is no need to 
	# update the display.

	if {![winfo exists [$gui synDbgWin]]} return

	# Clear out the display ...

	set act [$icoList getActive]

	$icoList clear
	array unset lmap *

	# We get the errors from the 'checker module' sorted by filename,
	# linenumber, and start column.

	set msgs [$checker get]
	set data {}

	if {[llength $msgs]} {
	    set currentItem 1
	    foreach {blk file line col mtype mid msg} $msgs {

		set file [file tail $file]
		if {$file == {}} {
		    set file $dynamicBlock
		}

		lappend data [list $mtype $file $line $mid $msg]

		set lmap($currentItem) [loc::makeLocation $blk $line]
		incr currentItem
	    }
	}

	$icoList update $data

	catch {$icoList select $act}
	$self checkState
	return
    }

    # method showCode --
    #
    #	Show the block of code where the syntax error is marked.
    #	At this point the Stack and Var Windows will be out
    #	of synch with the Code Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method showCode {} {
	# There may be more then one line highlighted. Just get the
	# first line that's highlighted, and show it's code.

	set item [$icoList getActive]
	if {$item eq ""} return
	if {$item == 0} return

	set loc $lmap($item)

	# The .... are preserved between sessions. The file associated
	# with the breakpoint may or may not still exist. To verify
	# this, get the Block source. If there is an error, set the
	# loc to {}. This way the BP dosent cause an error, but gives
	# feedback that the file cannot be found.
	
	if {[catch {$blkmgr getSource [loc::getBlock $loc]}]} {
	    set loc {}
	}

	$gui showCode $loc
	return
    }

    # method checkState --
    #
    #	Check the state of the Syntax errors Window.
    #	Enable the "Show Code" button if there 
    #	are one or more selected lines.  Remove the first two
    #	chars where the BP icons are located.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method checkState {args} {
	# If the window is not current mapped, then there is no need to 
	# update the display.

	if {![winfo exists [$gui synDbgWin]]} return

	if {[llength [$icoList getSelection]]} {
	    set state normal
	} else {
	    set state disabled
	}

	$showBut configure -state $state
	return
    }
}

# ### ### ### ######### ######### #########
## Ready to go

package provide checkWin 1.0
