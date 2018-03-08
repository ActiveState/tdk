# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# watchWin.tcl --
#
#	This file implements the Watch Window and the common APIs
#	used by the Watch Window and the Var Window.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########

package require transform
package require snit

# ### ### ### ######### ######### #########

snit::type watch {

    # Object caching variables and values, so that the frontend fetches
    # them only once from the backend during a break.

    variable vcache {} ; # Cache of variables and their values.
    variable vd

    # Handles to the buttons in the Watch window.

    variable inspectBut {}
    variable remBut     {}
    variable allBut     {}

    # The list of variable that are currently being watched.
    # Bugzilla 19719 ... INVALID ... Using varTransList now!, see later.
    # variable varList {}

    # Maintain a list of all the expanded arrays at a given level.
    # When update is called, the text in the window is deleted and
    # the current state is inserted.  This array will assure that
    # arrays expanded before the update are still expanded after
    # the update.

    variable expanded

    variable afterID

    # Bugzilla 19719 ... Holds the name of the transform chosen by the
    # user for a variable to add.

    variable tsom     {}
    variable tsomMenu {}

    # Connected to 'addEnt', traced to enable/disable 'tsom'.
    variable addvar {}

    # New data structures to handle transformations of
    # values shown in the various variable windows.

    # II. Watched variable dialog
    #
    # The list varList is deprecated and substituted by
    # 'varTransList' below. A list of lists. The sublists
    # contain the varname to watch, and the transformation
    # to use, in this order

    variable varTransList {}

    # TODO = consider the use of a supplementary array keyed by the
    # TODO = pairs (var x trans) for quick existence test.

    # ### ### ### ######### ######### #########

    variable             stack
    variable             icon
    variable             inspector
    variable             bp
    variable             varwin

    variable             dbg
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	# Dependency: watchWin is done after varWin, stackWin.

	set gui     $value
	set stack     [$gui stack]
	set icon      [$gui icon]
	set inspector [$gui inspector]
	set bp        [$gui bp]
	set varwin    [$gui var]
	set dbg       [[$gui cget -engine] dbg]
	set vcache    [$gui vcache]
	return
    }

    # ### ### ### ######### ######### #########

    constructor {args} {
	trace variable [varname addvar] w [mymethod tsomMenuState]
	array set expanded {}

	$self configurelist $args
	return
    }

    destructor {
	trace vdelete [varname addvar] w [mymethod tsomMenuState]
    }

    # ### ### ### ######### ######### #########

    method tsomMenuState {args} {
	if {$tsomMenu == {}} {return}

	if {$addvar == {}} {
	    $tsomMenu configure -state disabled
	} else {
	    $tsomMenu configure -state normal
	}
    }

    # method showWindow --
    #
    #	Show the Watch Window.  If the window exists then just
    #	raise it to the foreground.  Otherwise, create the window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The name of the Watch Window's toplevel.

    method showWindow {} {
	# If the window already exists, show it, otherwise
	# create it from scratch.

	set top [$gui watchDbgWin]
	if {[winfo exists $top]} {
	    $self updateWindow
	    wm deiconify $top
	} else {
	    $self createWindow
	    $self updateWindow
	}
	focus $vd
	return $top
    }

    # method createWindow --
    #
    #	Create the Watch Window and all of the sub elements.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method createWindow {} {
	set pad  6
	set pad2 [expr {$pad * 2}]

	set                        top [toplevel [$gui watchDbgWin]]
	::guiUtil::positionWindow $top 400x250
	wm minsize                $top 100 100
	wm title                  $top "Watch Variables - [$gui cget -title]"
	wm transient              $top $gui
	wm resizable              $top 1 1

	# Create the entry for adding new Watch variables.
	# Also a selector for a transformation ...

	set mainFrm [ttk::frame $top.mainFrm ]
	set addFrm  [ttk::frame $mainFrm.addFrm]

	set addLbl [ttk::label $addFrm.addLbl -anchor w -text "Variable:"]
	set addEnt [ttk::entry $addFrm.addEnt -textvariable [varname addvar]]

	# Bugzilla 19719 ... Added an option menu for sleection of the
	# transformation before adding the variable to the list.

	set tsomLbl  [ttk::label $addFrm.tsomLbl -anchor w -text "Display:"]
	set tsomMenu [transform::transformSelectorOM $addFrm.tsom [varname tsom]]
	$tsomMenu configure -state disabled

	grid $addLbl  -row 0 -column 0 -sticky we
	grid $tsomLbl -row 1 -column 0 -sticky we

	grid $addEnt   -row 0 -column 1 -sticky we -padx 3
	grid $tsomMenu -row 1 -column 1 -sticky w  -padx 3
	grid columnconfigure $addFrm 1 -weight 1

	set addBut [ttk::button $mainFrm.addBut -text "Add" \
			-command [mymethod addVarFromEntry $addEnt]]

	# Place a separating line between the var info and the 
	# value of the var.

	set sepFrm [ttk::separator $mainFrm.sep1 -orient horizontal]

	# Create the table for displaying var names and values.

	set varFrm [ttk::frame $mainFrm.varFrm]
	set vd [varDisplay $varFrm.vd \
		    -tags      [list watchDbgWin$self] \
		    -onselect  [mymethod WatchSelect] \
		    -ontoggle  [mymethod WatchToggle] \
		    -exaccess  [mymethod WatchExpand] \
		    -findtrans [mymethod WatchFind]   \
		    -inspector $inspector \
		    -gui       $gui]

	# Create the buttons to Inspect and remove vars.

	set butFrm [ttk::frame $mainFrm.butFrm]
	set inspectBut [ttk::button $butFrm.insBut -text "Data Display" \
		-command [list $vd showInspector] \
		-state disabled]
	set remBut [ttk::button $butFrm.remBut -text "Remove" \
			-command [mymethod removeSelected] -state disabled]
	set allBut [ttk::button $butFrm.allBut -text "Remove All" \
			-command [mymethod removeAll] -state disabled]
	set closeBut [ttk::button $butFrm.closeBut -text "Close" \
			  -command [list destroy $top]]
	pack $inspectBut $remBut $allBut $closeBut -fill x -pady 3

	grid $addFrm  -row 0 -column 0 -sticky   we -padx $pad -pady $pad
	grid $addBut  -row 0 -column 1 -sticky  nwe -padx $pad -pady $pad2
	grid $sepFrm  -row 1 -column 0 -sticky   we -padx $pad -columnspan 2
	grid $varFrm  -row 2 -column 0 -sticky nswe -padx $pad -pady $pad2
	grid $butFrm  -row 2 -column 1 -sticky  nwe -padx $pad -pady [expr {$pad2 - 3}]
	grid columnconfigure $mainFrm 0 -weight 1
	grid rowconfigure    $mainFrm 2 -weight 1
	pack $mainFrm -fill both -expand true ;# -padx $pad -pady $pad


	grid $vd -sticky wnse -row 0 -column 0
	grid columnconfigure $varFrm 0 -weight 1
	grid rowconfigure    $varFrm 0 -weight 1


	# Add all of the common bindings and create the tab focus
	# order for each widget that can get the focus.

	bind::commonBindings watchDbgWin [list $addEnt $addBut \
	      [$vd ourFocus] $inspectBut $remBut $allBut $closeBut]

	# Define bindings specific to the Watch Window.

	bind::addBindTags $addEnt     watchDbgWin$self
	bind::addBindTags $inspectBut watchDbgWin$self
	bind::addBindTags $remBut     watchDbgWin$self
	bind::addBindTags $allBut     watchDbgWin$self

	bind watchDbgWin$self <<Dbg_RemSel>> [mymethod removeSelected]
	bind watchDbgWin$self <<Dbg_RemAll>> [mymethod removeAll]

	bind $addEnt <Return> "[mymethod addVarFromEntry $addEnt]; break"
	bind $top    <Escape> "$closeBut invoke; break"
    }

    method WatchSelect {args} {
	# Define the command to be called after each selection event.
	$self checkState
    }

    method WatchToggle {args} {
	$varwin updateWindow

        # We, the watch window can have several entries per variable.
        # It is necessary to update fully on toggling one, to toggle
        # all of them. Otherwise the state of all related entries goes
        # out of sync.

	$self   updateWindow
	$bp     updateWindow
	return
    }

    method WatchExpand {oname level trans args} {
	if {[llength $args]} {
	    $self setArrayExpanded $level $oname [lindex $args 0] $trans
	} else {
	    return [$self isArrayExpanded $level $oname $trans]
	}
    }

    method WatchFind {oname level} {
	# Irrelevant to watch dialog, here a transform is associated
	# with the whole array. Which means that this method will not
	# be called.

	# Still, present in case something changes during development.
	return {}
    }

    # method updateWindow --
    #
    #	Update the display of the Watch Window.  
    #
    # Arguments:
    #	None.
    #
    # Results: 
    #	None.

    method updateWindow {} {
	set state [$gui getCurrentState]
	set level [$gui getCurrentLevel]

	if {![winfo exists [$gui watchDbgWin]]} {
	    return
	}
	if {$state == "running"} {
	    return
	}

	if {[info exists afterID]} {
	    after cancel $afterID
	    unset afterID
	}

	set varInfo {}
	if {
	    $state == "stopped" &&
	    ![$stack isVarFrameHidden] &&
	    ($varTransList != {})
	} {
	    # Bugzilla 19719 ... 'vars' is not empty, it is not a list
	    # of variable names as before, but a list of list of
	    # varname and transform. We extract the unique varnames
	    # from that list and also setup a mapping so that we know
	    # for item in 'vars' where the transform-independent
	    # information about its variable will be in the near-final
	    # result. This is used by JoinTransform to join the
	    # variable values with 'vars' to get the final result.

	    UniqMap $varTransList -> varnames vmap

	    set varInfo [JoinTransform $varTransList [$vcache list \
		[mymethod isArrayExpandedAny] \
		$level $varnames] $vmap]
	    
	} else {
	    # The GUI is dead so there is no variable information.
	    # Foreach var in varTransList, generate a dbg getVar result
	    # that indicates the var does not exist.
	    # {mname oname type exist transform-id}
	    
	    foreach var $varTransList {
		set var [lindex $var 0] ; # ignore transform
		lappend varInfo [list [code::mangle $var] $var n 0 {}]
	    }
	}

	# Call the internal routine that populates the var name and
	# var value windows.

	if {$state == "running"} {
	    set afterID [after \
		    [$gui afterTime] \
		    [mymethod UpdateAndCheck $varInfo $level]]
	} else {
	    $self UpdateAndCheck $varInfo $level
	}
    }

    method UpdateAndCheck {varInfo level} {
	# Save and restore active item
	set active [$vd getActive]
	$vd update $varInfo $level
	catch {$vd select $active 0} ; # May not exist anymore (remove(all)).
	$self checkState
    }

    proc UniqMap {vars -> vnv vmv} {
	upvar 1 $vnv varnames $vmv vmap
	if {![llength $vars]} return
	array set tmp {}
	set idx 0
	# Extract unique varnames from list of varnames + transforms
	foreach vinfo $vars {
	    foreach {vname __} $vinfo break
	    if {![info exists tmp($vname)]} {
		set tmp($vname) $idx
		lappend varnames $vname
		incr idx
	    }
	    lappend vmap $tmp($vname)
	}
    }

    proc JoinTransform {vars result vmap} {
	# Bugzilla 19719 ...
	# A last round through the list. 'vars' is not empty we
	# iterate over 'vars' and use 'vmap' (s.a.) to join the
	# transformation ids with the variable information retrieved
	# earlier.

	set finalRes [list]

	# This join operation may duplicate a base record if the
	# variable is shown multiple times, with different
	# transformations

	foreach vinfo $vars idx $vmap {
	    foreach {_ tid} $vinfo break
	    set item [lindex $result $idx]
	    lappend item $tid
	    lappend finalRes $item
	}

	return $finalRes
    }

    # method resetWindow --
    #
    #	Clear the contents of the window and display a
    #	message in its place, or set all of the values
    #	to <No Value> for the case that the Var Frame is 
    #	hidden.
    #
    # Arguments:
    #	msg		If not null, then display the contents 
    #			of the message in the window.
    #
    # Results:
    #	None.

    method resetWindow {msg} {
	if {![winfo exists [$gui watchDbgWin]]} {
	    return
	}

	$inspectBut configure -state disabled
	if {[$stack isVarFrameHidden]} {
	    # The var frame is hidden so there is no variable information
	    # Foreach var in varTransList, generate a dbg getVar result
	    # that indicates the var does not exist.

	    set varInfo {}
	    foreach pair $varTransList {
		set var [lindex $pair 0] ; # ignore transform
		lappend varInfo [list [code::mangle $var] $var s 0 {}]
	    }

	    # Repopulate the var display.

	    $vd update $varInfo [$gui getCurrentLevel]
	} else {
	    if {$msg == {}} {
		$vd clear
	    } else {
		$vd message $msg
	    }
	}
    }

    # method addVar --
    #
    #	Add newVar to the list of watched variables as long as
    #	newVar is not a duplicate or an empty string.
    #
    # Arguments:
    #	newVar	The new variable to add to the Watch window.
    #
    # Results:
    #	None.

    method addVar {newVar trans} {
	# Bugzilla 19719 ... Duplicate checking is now done respecting
	# transformations.

	set watchItem [list $newVar $trans]

	if {($newVar != {}) && ([lsearch $varTransList $watchItem] < 0)} {
	    lappend varTransList $watchItem
	    $self setVarList $varTransList

	    # And open the dialog to let the user see the new watch
	    # entry.
	    $self showWindow
	}
	return
    }

    # method addVarFromEntry --
    #
    #	Add a variable to the Watch Window by extracting the
    #	variable name from an entry widget.
    #
    # Arguments:
    #	ent	The entry widget to get the var name from.
    #
    # Results:
    #	None.

    method addVarFromEntry {ent} {
	# Bugzilla 19719 ... Remember chosen transformation too.
	set newVar [$ent get]
	$ent delete 0 end
	$self addVar $newVar [transform::getTransformId $tsom]
    }

    # method removeAll --
    #
    #	Remove all of the Watched variables.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method removeAll {} {
	$self setVarList {}
	return
    }

    # method removeSelected --
    #
    #	Remove all of the highlighted variables.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method removeSelected {} {
	set yview [$vd scrollIsAt]

	set selectedLines [$vd getSelection]
	set selectCursor  [$vd getActive]

	if {[llength $selectedLines]} {
	    # Create a new varTransList containing only the unselected
	    # variables. Then call updateWindow to display the updated
	    # varTransList.
	    
	    set tempList $varTransList
	    foreach item $selectedLines {
		struct::set exclude tempList \
		    [list [$vd baseOf $item] [$vd transformOf $item]]
	    }

	    $self setVarList $tempList
	    catch {$vd select $selectCursor 0} ; # May be gone
	}
	$self checkState
	$vd scrollTo $yview
	return
    }

    # method checkState --
    #
    #	If one or more selected variables has a value for
    #	the variable, then enable the "Data Display"
    #	and "Remove" buttons.  If there are values being
    #	watched then enable the "Remove All" button.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method checkState {} {
	set cursor [$vd getActive]
	set lines  [$vd getSelection]

	if {
	    ([lsearch $lines $cursor] >= 0) &&
	    [$vd varExists $cursor]
	} {
	    $inspectBut configure -state normal
	} else {
	    $inspectBut configure -state disabled
	}
	if {![llength $lines]} {
	    $remBut configure -state disabled
	} else {
	    $remBut configure -state normal
	}	
	if {![llength $varTransList]} {
	    $allBut configure -state disabled
	} else {
	    $allBut configure -state normal
	}
	return
    }

    # method getVarList --
    #
    #	Return the current list variables being displayed 
    #	in the Watch Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns a list of variable names.

    method getVarList {} {
	return $varTransList
    }

    # method setVarList --
    #
    #	Set the list of Vars to watch.
    #
    # Arguments:
    #	vars	The list of vars to watch.
    #	dirty	Boolean, indicating if the dirty bit should be set.  
    #		Can be null.
    #
    # Results:
    #	None.

    method setVarList {vars {dirty 1}} {
	# If the level is empty, then a remote app has connected
	# but has not initialized the GUIs state.

	set varTransList $vars
	if {$dirty} {
	    pref::groupSetDirty Project 1
	}
	if {[winfo exists [$gui watchDbgWin]]} {
	    $self updateWindow
	}
	return
    }

    # method setArrayExpanded --
    #
    #	Set the expanded value for an array.
    #
    # Arguments:
    #	text	The text widget where the array is displayed.
    #	oname	The original, unmangled, array name.
    #	level	The level to get variables from.
    #	expand	Boolean, 1 means the array is expanded.
    #
    # Results:
    #	Returns 1 if the array is expanded.

    method setArrayExpanded {level oname expand trans} {
	# Bugzilla 19719 ... Expansion in WV dialog has to take transforms
	# into account.
	set expanded($level,$oname,$trans) $expand
	return
    }

    # method isArrayExpanded --
    #
    #	Check to see if an array is fully expanded.
    #
    # Arguments:
    #	oname	The original, unmangled, array name.
    #	level	The level to get variables from.
    #	trans	Optional transform to check
    #
    # Results:
    #	Returns 1 if the array is expanded.

    method isArrayExpanded {level oname trans} {
	# Bugzilla 19719 ... Expansion in WV dialog has to take
	# transforms into account.

	# Transformation set - wvd
	set key $level,$oname,$trans

	if {[info exists expanded($key)] && ($expanded($key))} {
	    return 1
	} else {
	    return 0
	}
    }

    # Bugzilla 19719 ... 
    # method isArrayExpandedAny --
    #
    #	Check to see if some instance of an array is fully expanded.
    #
    # Arguments:
    #	oname	The original, unmangled, array name.
    #	level	The level to get variables from.
    #
    # Results:
    #	Returns 1 if at least one instance of the array is expanded.

    method isArrayExpandedAny {level oname} {
	# Watched Variables Dialog - check all possible instances (=
	# var + transform), stop immediately if the existence of an
	# expanded instance is confirmed.

	foreach key [array names expanded $level,$oname,*] {
	    if {$expanded($key)} {return 1}
	}
	# No expanded instance
	return 0
    }

    # method setTransformForWatch --
    #
    #	Associate a transformation with a watched variable
    #
    # Arguments:
    #	index	Index of variable to modify in 'varTransList'.
    #	id	id of transformation to use. {} dissociates
    #		the variable from its transformation.
    #
    # Results:
    #	None
    #

    method setTransformForWatch {index id} {
	foreach {var oldid} [lindex $varTransList $index] break

	# 8.4: lset
	set varTransList \
		[lreplace $varTransList \
		$index $index \
		[list $var $id]]
	return
    }

    # method getTransformForWatch --
    #
    #	Retrieve transform for a value shown in the watched
    #       variables dialog
    #
    # Arguments:
    #	index	Index of variable in 'varTransList'.
    #
    # Results:
    #	Id of transformation associated with the index.
    #

    method getTransformForWatch {index} {
	foreach {var id} [lindex $varTransList $index] break
	return $id
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

package provide watch 1.0
