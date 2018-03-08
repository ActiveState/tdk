# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# procWin.tcl --
#
#	This file contains the implementation for the "procs" window
#	in the Tcl debugger.  It shows all the instrumented and
#	non-instrumented procedures in the running application.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: procWin.tcl,v 1.5 2000/10/31 23:31:00 welch Exp $

# ### ### ### ######### ######### #########

package require snit
package require icolist

# ### ### ### ######### ######### #########

snit::type procWin {
    # Handles to widgets in the Proc Window.

    variable patEnt      {}
    variable icoList     {}
    variable showBut     {}
    variable instruBut   {}
    variable uninstruBut {}
    variable patBut      {}
    variable showChk     {}

    # The <loc> cache of locations for each proc.  The showCode proc
    # uses this to display the proc.

    variable procCache -array {}
    variable showChkVar 1
    variable patValue   "*"

    # Used to delay UI changes do to state change.
    variable afterID

    # This variable provides a data base of the useable UI names for
    # procedures and the "real" names of procedures in the application.

    variable origProcNames -array {}

    # ### ### ### ######### ######### #########

    variable             code
    variable             dbg
    variable             blkmgr
    variable             fdb
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
	set engine_ [$gui cget -engine]
	set dbg     [$engine_ dbg]
	set fdb     [$engine_ fdb]
	set blkmgr  [$engine_ blk]
	return
    }

    # ### ### ### ######### ######### #########


    # method showWindow --
    #
    #	Create the procedure window that will display
    #	all the procedures in the running application. 
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The name of the Proc Windows toplevel.

    method showWindow {} {
	# If the window already exists, show it, otherwise create it
	# from scratch.

	set top [$gui procDbgWin]

	if {[winfo exists $top]} {
	    $self updateWindow
	    wm deiconify $top
	} else {
	    $self createWindow
	    $self updateWindow
	}

	focus $icoList
	return $top
    }

    # method createWindow --
    #
    #	Create the procedure window that will display
    #	all the procedures in the running application. 
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method createWindow {} {
	set                        top [toplevel [$gui procDbgWin]]
	::guiUtil::positionWindow $top 400x260
	wm minsize                $top 175 100
	wm title                  $top "Procedures - [$gui cget -title]"
	wm transient              $top $gui
	wm resizable              $top 1 1

	set pad  6

	# Create the pattern entry interface.   The default pattern is "*".

	set mainFrm [ttk::frame $top.mainFrm]
	set patLbl  [ttk::label $mainFrm.patLbl -anchor w -text "Pattern:"]
	set patEnt  [ttk::entry $mainFrm.patEnt \
			 -textvariable [varname patValue]]
	set patBut  [ttk::button $mainFrm.patBut -text "Search" \
			 -command [mymethod updateWindow]]

	# Place a separating line between the var info and the var value.

	set sepFrm [ttk::separator $mainFrm.sep1 -orient horizontal]

	# Create the text widget that displays all procs and the 
	# "Show Code" button.

	set showChk [ttk::checkbutton $mainFrm.showChk \
			 -variable [varname showChkVar] \
			 -text "Show Uninstrumented Procedures" \
			 -command [mymethod updateWindow]]

	set icoList [icolist $mainFrm.l \
			 -headers {{Procedure name}} \
			 -tags     [list procDbgWin$self procDbgWin] \
			 -onselect [mymethod checkState] \
			 -statemap {
			     inst   wrench
			     uninst {}
			 }]

	set butFrm  [ttk::frame $mainFrm.butFrm]
	set instLbl [ttk::label $mainFrm.butFrm.instLbl \
			 -compound left \
			 -image    [image::get wrench] \
			 -text     "Instrumented"]

	set showBut     [ttk::button $butFrm.showBut -text "Show Code" \
			     -command [mymethod showCode]]
	set instruBut   [ttk::button $butFrm.instruBut -text "Instrument" \
			     -command [mymethod instrument 1]]
	set uninstruBut [ttk::button $butFrm.uninstruBut -text "Uninstrument" \
			     -command [mymethod instrument 0]]
	set closeBut    [ttk::button $butFrm.closeBut -text "Close" \
			     -command [list destroy $top]]

	pack $showBut $instruBut $uninstruBut $closeBut $instLbl -fill x -pady 3

	grid $patLbl  -row 0 -column 0 -sticky we   -padx $pad -pady $pad
	grid $patEnt  -row 0 -column 1 -sticky we   -padx $pad -pady $pad
	grid $patBut  -row 0 -column 2 -sticky we   -padx $pad -pady $pad
	grid $sepFrm  -row 1 -column 0 -sticky we   -padx $pad -pady 3    -columnspan 3
	grid $showChk -row 2 -column 0 -sticky nw   -padx $pad            -columnspan 3
	grid $icoList -row 3 -column 0 -sticky nswe -padx $pad -pady $pad -columnspan 2

	grid $butFrm  -row 3 -column 2 -sticky nwe -padx $pad -pady $pad

	grid columnconfigure $mainFrm 1 -weight 1
	grid rowconfigure    $mainFrm 3 -weight 1

	pack $mainFrm -fill both -expand true ; # -padx $pad -pady $pad

	# Add default bindings and define tab order.

	bind::addBindTags $patEnt   procDbgWin$self
	bind::addBindTags $showBut  procDbgWin$self

	bind::commonBindings procDbgWin$self \
	    [list $patEnt $patBut [$icoList ourFocus] \
		 $showBut $instruBut $uninstruBut $closeBut]

	bind procDbgWin$self <<Dbg_ShowCode>> "\
		[mymethod showCode] ; \
		break \
		"
	bind procDbgWin$self <Double-1> "\
		[mymethod showCode] ; \
		break \
		"
	bind procDbgWin$self <Return> "\
		[mymethod showCode] ; \
		break \
		"
	bind $patEnt <Return> "\
		[mymethod updateWindow] ; \
		break \
		"

	bind $top <Escape> "$closeBut invoke; break"
	return
    }

    # method updateWindow --
    #
    #	Populate the Proc Windows list box with procedures
    #	currently defined in the running app. 
    #
    # Arguments:
    #	preserve	Preserve the selection status if true.
    #
    # Results:
    #	None.

    method updateWindow {{preserve 0}} {
	if {![winfo exists [$gui procDbgWin]]} return

	if {$preserve} {
	    set sel [$icoList getSelection]
	    set act [$icoList getActive]
	}

	if {[info exists afterID]} {
	    after cancel $afterID
	    unset afterID
	}

	# If the state is not running or stopped, then delete
	# the display, unset the procCache and disable the
	# "Show Code" button

	set state [$gui getCurrentState]
	if {$state != "stopped"} {
	    if {$state == "running"} {
		set afterID [after \
			[$gui afterTime] \
			[mymethod resetWindow]]
	    } else {
		$self resetWindow
	    }
	    return
	}

	set yview [$icoList scrollIsAt]

	$icoList clear
	array unset procCache *

	# If the user deletes the pattern, insert the star to provide
	# feedback that all procs will be displayed.

	if {$patValue == {}} {
	    set patValue "*"
	}

	# The list returned from $dbg getProcs is a list of pairs 
	# containing {procName <loc>}.  For each item in the list
	# insert the proc name in the window if it matches the
	# pattern.  If the proc is not instrumented, then add the
	# "unistrumented" tag to alter the look of the display.

	if {[catch {set procs [$dbg getProcs]}]} return

	set data {}
	foreach x [lsort $procs]  {
	    foreach {name loc} $x break

	    set procCache($name) $loc
	    set name [$self trimProcName $name]

	    if {![string match $patValue $name]} continue

	    if {($loc != {}) && [$blkmgr isInstrumented [loc::getBlock $loc]]} {
		lappend data [list inst $name]
	    } elseif {$showChkVar} {
		lappend data [list uninst $name]
	    }
	}

	$icoList update $data

	$showChk configure -state normal
	$patEnt  configure -state normal
	$patBut  configure -state normal

	$icoList scrollTo $yview

	$self checkState

	if {$preserve} {
	    foreach s $sel {
		catch {$icoList select $s}
	    }
	    catch {$icoList select $act}
	} else {
	    catch {$icoList select 1}
	}
	return
    }

    # method resetWindow --
    #
    #	Reset the window to be blank, or leave a message 
    #	in the text box.
    #
    # Arguments:
    #	msg	If not empty, then put this message in the 
    #		icoList text widget.
    #
    # Results:
    #	None.

    method resetWindow {{msg {}}} {
	if {![winfo exists [$gui procDbgWin]]} return

	$showChk configure -state disabled
	$patEnt  configure -state disabled
	$patBut  configure -state disabled

	array unset procCache *

	if {$msg == {}} {
	    $icoList clear
	} else {
	    $icoList message $msg
	}

	$self checkState
	return
    }

    # method showCode --
    #
    #	This function is run when we want to display the selected
    #	procedure in the proc window.  It will interact with the
    #	text box to find the selected procedure, find the corresponding
    #	location, and tell the code window to display the procedure.
    #
    # Arguments:
    #	text	The text window.
    #
    # Results:
    #	None.

    method showCode {} {
	set state [$gui getCurrentState]
	if {$state ne "running" && $state ne "stopped"} return

	set item [$icoList getActive]
	if {$item eq ""} return
	if {$item == 0} return

	# If we can succesfully extract a procName, verify that there
	# is a <loc> cached for the procName. If there is no <loc>
	# (empty string), then this may be uninstrumented code.
	# Request a <loc> based on the proc name.

	set loc          {}
	set runningErr   0
	set updateStatus 0

	set procName [$self getProcName $item]

	if {[info exists procCache($procName)]} {
	    set loc $procCache($procName)
	    if {$loc == {}} {
		if {[catch {set loc [$dbg getProcLocation $procName]}]} {
		    set runningErr 1
		}
		set updateStatus 1
	    }
	}

	$gui showCode $loc

	# An error will occur if 'getProcLocation' was called while
	# the state is 'running'.  If an error occured, provide
	# feedback in the CodeWindow.

	if {$runningErr} {
	    $code resetWindow "Cannot show uninstrumented code while running."
	}

	return
    }

    # method instrument --
    #
    #	This function is run when we want to either instrument or
    #	uninstrument the selected procedure in the proc window.  It will
    #	interact with the text box to find the selected procedure, find the
    #	corresponding location (if available), and the do the operation 
    #	specified by the op argument.
    #
    # Arguments:
    #	op	If 1 instrument the proc, if 0 uninstrument the proc.
    #	text	The text window.
    #
    # Results:
    #	None.

    method instrument {op} {

	set state [$gui getCurrentState]
	if {$state ne "stopped"} {
	    $code resetWindow \
		"Cannot instrument or uninstrumented code while running."
	    return
	}
	
	foreach item [$icoList getSelection] {
	    
	    # If we can succesfully extract a procName, verify that
	    # there is a <loc> cached for the procName. If there is no
	    # <loc> (empty string), then this may be uninstrumented
	    # code.  Request a <loc> based on the proc name.
	    
	    set loc {}
	    set procName [$self getProcName $item]
	    if {[info exists procCache($procName)]} {
		set loc $procCache($procName)
	    }

	    if {$op} {
		# Instrument the procedure, ignore instrumented procedures

		if {$loc ne ""} continue
		set loc [$dbg getProcLocation $procName]
		$dbg instrumentProc $procName $loc
	    } else {
		# Uninstrument the procedure, ignore uninstrumented procedures
		if {$loc eq ""} continue
		$dbg uninstrumentProc $procName $loc
	    }
	}

	# Extract and save the block number associated with the proc
	# name pointed to by the selection cursor. This will be used
	# to update the Code Window if the currently displayed block
	# number is identical to the block number for the proc.

	if {$op} {
	    set procName [$self getProcName [$icoList getActive]]
	    set blk      [loc::getBlock [$dbg getProcLocation $procName]]
	} elseif {[info exists procCache($procName)]} {
	    set blk [loc::getBlock $procCache($procName)]
	} else {
	    set blk {}
	}

	# Update the Proc Windows display.  This has the side affect
	# of assigning new block numbers to each proc name.

	$self updateWindow 1

	# Display the code if the old proc body was being displayed.
	# This needs to be called after "$self updateWindow" is
	# called, so the new block is displayed.

	if {($blk != {}) && ([$gui getCurrentBlock] == $blk) \
		&& [$blkmgr isDynamic $blk]} {
	    $self showCode
	}
	
	# The blocks have been changed.  Reset the block-to-filename
	# relationship.
	
	$fdb update
	return
    }

    # method checkState --
    #
    #	Determine if the "Show Code" button should be normal
    #	or disabled based on what is selected.
    #
    # Arguments:
    #	text	The icoList widget.
    #
    # Results:
    #	None.

    method checkState {args} {
	set inst   0
	set uninst 0

	foreach item [$icoList getSelection] {
	    if {[$icoList stateOf $item] eq "inst"} {
		set uninst 1
	    } else { 
		set inst   1
	    }
	}

	if {$inst} {
	    $instruBut configure -state normal
	} else {
	    $instruBut configure -state disabled
	}
	if {$uninst} {
	    $uninstruBut configure -state normal
	} else {
	    $uninstruBut configure -state disabled
	}

	set cursor [$icoList getActive]
	if {($cursor eq "") || ($cursor == 0)} {
	    $showBut configure -state disabled
	} else {
	    $showBut configure -state normal
	}
    }

    # method trimProcName --
    #
    #	If the app is 8.0 or higher, then namespaces exist.  
    #	This proc strips off the leading ::'s if the apps
    #	tcl_version is 8.0 or greater.  This procedure will
    #	also stip the name of characters that could cause
    #	problems to the text widget like NULLS or newlines.
    #
    # Arguments:
    #	procName	The name to trim.
    #
    # Results:
    #	The normalized procName depending on namespaces.

    method trimProcName {procName} {
	set orig     $procName
	set procName [code::mangle $procName]

	set appVersion [$dbg getAppVersion]
	if {$appVersion != {} && $appVersion >= 8.0 \
		&& [string match {::*} $procName]} {
	    set procName [string range $procName 2 end]
	}

	set origProcNames($procName) $orig
	return $procName
    }

    # method getProcName --
    #
    #	Get the procName from the text widget.  If the 
    #	app is 8.0 or higher, then namespaces exist.  
    #	This proc appends the leading ::'s if the apps
    #	tcl_version is 8.0 or greater.
    #
    # Arguments:
    #	text	The porcWin's text widget.
    #	line	The line number to search for procNames.
    #
    # Results:
    #	A procName modified for use by the nub (if 8.0 or greater
    #	append the leading ::'s)

    method getProcName {item} {
	return $origProcNames([$icoList textOf $item])
    }


    typevariable bstate -array {
	1 normal
	0 disabled
    }
}

# ### ### ### ######### ######### #########

package provide procWin 1.0
