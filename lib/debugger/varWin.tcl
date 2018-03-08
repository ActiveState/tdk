# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# varWin.tcl --
#
#	This file implements the Var Window (contained in the
#	main debugger window.)
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: varWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########

package require transform
package require snit
package require varDisplay
package require transMenu

# ### ### ### ######### ######### #########

snit::widget var {

    delegate option * to hull

    # ### ### ### ######### ######### #########

    variable             bp
    variable             inspector
    variable             icon
    variable             watch
    variable             gui {}

    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui       $value
	set inspector [$gui inspector]
	set icon      [$gui icon]
	set watch     [$gui watch]
	set vcache    [$gui vcache]
	set bp        [$gui bp]
	return
    }

    variable vcache ; # Cache of variables and their values.
    variable vd     ; # Var Display widget

    option -tags -default {} -configuremethod C-tags

    method C-tags {option value} {
	if {$value eq $options(-tags)} return
	set options(-tags) $value

	if {![winfo exists $win.vd]} return
	$win.vd configure -tags \
	    [linsert $options(-tags) 0 varDbgWin$self transPopup$self]
	return
    }

    # ### ### ### ######### ######### #########

    constructor {args} {
	$self configurelist $args
	$self createWindow
	return
    }

    delegate method ourFocus     to vd
    delegate method hadFocus     to vd
    delegate method hasFocus     to vd
    delegate method hasHighlight to vd

    # ### ### ### ######### ######### #########

    # method createWindow --
    #
    #	Create the var window and all of the sub elements.
    #
    # Arguments:
    #	masterFrm	The frame that contains the var frame.
    #
    # Results:
    #	The frame that contains the Var Window.

    method createWindow {} {
	# Bugzilla 19719 ... Bindings for the popup menu

	set vd [varDisplay $win.vd \
		    -tags      [linsert $options(-tags) 0 varDbgWin$self transPopup$self] \
		    -onselect  [mymethod VarSelect] \
		    -ontoggle  [mymethod VarToggle] \
		    -exaccess  [mymethod VarExpand] \
		    -findtrans [mymethod VarFind] \
		    -inspector $inspector \
		    -gui       $gui]

	bind varDbgWin$self <<Dbg_AddWatch>> [mymethod addToWatch]

	# Bugzilla 19719 ... Bindings for the popup menu. Copy the
	# bindings for button 1 over so that the selection is done
	# correctly before invoking the menu itself.

	bind transPopup$self <<PopupMenu>>        [bind $win.vd.l.t <1>]
	bind transPopup$self <<PopupMenuRelease>> "\
		[bind $win.vd.l.t <ButtonRelease-1>]\n\
		[mymethod transform]"

	grid $win.vd -sticky wnse -row 0 -column 0
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1

	return
    }

    method VarSelect {args} {
    }

    method VarToggle {args} {
	$watch updateWindow
	$bp    updateWindow
	return
    }

    method VarExpand {oname level trans args} {
	if {[llength $args]} {
	    $self setArrayExpanded $level $oname [lindex $args 0]
	} else {
	    return [$self isArrayExpanded $level $oname]
	}
	return
    }

    method VarFind {oname level} {
	return [$self getTransform $oname $level]
    }

    # method updateWindow --
    #
    #	Update the display of the Var window.  This routine 
    #	expects the return of maingui getCurrentLevel to give
    #	the level displayed in the Stack Window.
    #
    # Arguments:
    #	None.
    #
    # Results: 
    #	None.

    method updateWindow {} {
	if {[$gui getCurrentState] ne "stopped"} return

	set level [$gui getCurrentLevel]

	$win.vd update [lsort -dictionary -index 1 \
			    [AddTransform $level \
				 [$vcache list \
				      [mymethod isArrayExpanded] \
				      $level]]] $level
	return
    }

    proc AddTransform {level result} {
	upvar 1 self self
	# Bugzilla 19719 ...
	# A last round through the list. 'vars' is empty, we are the
	# display of vars in the main window and use the unmangled
	# varnames to find the corresponding transformation.

	set finalRes [list]
	foreach item $result {
	    foreach {_1 oname _2 _3} $item break
	    set tid [$self getTransform $oname $level]
	    lappend item $tid
	    lappend finalRes $item
	}
	return $finalRes
    }

    # method resetWindow --
    #
    #	Clear the contents of the window and display a
    #	message in its place.
    #
    # Arguments:
    #	msg	If not null, then display the contents of the
    #		message in the window.
    #
    # Results:
    #	None.

    method resetWindow {{msg {}}} {
	if {$msg == {}} {
	    $vd clear
	} else {
	    $vd message $msg
	}
    }

    # method addToWatch --
    #
    #	Add the selected variables to the Watch Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method addToWatch {} {
	foreach line [$vd getSelection] {
	    $watch addVar [$vd varOf $line] [$vd transformOf $line]
	}
    }

    # method seeVarInWindow --
    #
    #	Move the Var Window to show the variable that was selected
    #	in the Stack Window.  The Var Window is assumed to be updated
    #	to the current frame and that the variable exists in the
    #	frame.  
    #
    # Arguments:
    #	varName		The name of the variable to be moved into
    #			sight of the var window.
    #	moveFocus	Boolean value, if true move the focus to the
    #			Var Window after the word is shown.
    #
    # Results:
    #	None.

    delegate method seeVarInWindow to vd

    # Bugzilla 19719 ... Implementation of the popup menu for selecting a
    # transformation for variables in the variable window.

    # method transform --
    #
    #	Callback for button <3>. Generates the menu on first call.
    #	Determines the affected variable, derives the location for the
    #	menu to appear at and saves the information about the variable
    #	for the callback invoked by the menu itself.
    #
    # Arguments:
    #	None.
    # Results:
    #	None.

    method transform {} {
	if {![winfo exists $win.tm]} {
	    transMenu $win.tm [mymethod TSET]
	}

	set line      [$vd getSelection]
	set vname     [$vd varOf        $line]
	set vtrans    [$vd transformOf  $line]
	foreach {x y} [$vd menuLocation $line] break

	$win.tm show $vname $vtrans $x $y
	return
    }
    method TSET {vname new} {
	# Callback to set new transformation. It is called if and only
	# if the transform was actually changed. Updates the database
	# and the various parts of the UI ...

	$self      SetTransform $vname [$gui getCurrentLevel] $new
	$self      updateWindow
	$watch     updateWindow
	$inspector updateWindow 1
	return
    }

    # ### ### ### ######### ######### #########

    delegate method showInspector to vd
    delegate method breakState    to vd

    method toggleVBP {mode} {
	$vd toggleVBP [$vd getActive] $mode
	return
    }

    # ### ### ### ######### ######### #########

    # I. Main variable window.
    #
    # Varname x Level => Transform code
    # Only scalars and keyed-scalars are allowed.

    variable  mainTransform -array {}

    # method SetTransform --
    #
    #	Associate a transformation with a variable shown
    #	in the main windows
    #
    # Arguments:
    #	varname	Name of the variable
    #	level	Stacklevel the variable appears at.
    #	id	id of transformation to use. {} dissociates
    #		the variable from its transformation.
    #
    # Results:
    #	None
    #

    method SetTransform {varname level id} {
	if {$id == {}} {
	    unset mainTransform($varname,$level)
	} else {
	    set mainTransform($varname,$level) $id
	}
	return
    }

    # method getTransform --
    #
    #	Retrieve transform for a value shown in the main window
    #
    # Arguments:
    #	varname	Name of variable the value belongs to
    #	level	Stacklevel of said variable
    #
    # Results:
    #	Id of transformation associated with the variable.
    #

    method getTransform {varname level} {
	if {![info exists mainTransform($varname,$level)]} {
	    return {}
	}
	return $mainTransform($varname,$level)
    }

    # #######################################################
    # Take the var/trans association and serialize it.
    # Note: Only for the global variable display. The
    # watchlist is already handled by existing code, updated
    # to know transforms.

    # method mainDeserialize --
    #
    #	Return var/trans association database for storage in a project file.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	var/transform associations to remember.

    method mainSerialize {} {
	set res [list]
	foreach {key value} [array get mainTransform] {
	    foreach {varname level} [split $key ,] break
	    set trans [transform::getTransformName $mainTransform($key)]
	    lappend res [list $varname $level $trans]
	}

	return [lsort -index 0 [lsort -index 1 $res]]
    }

    # method mainDeserialize --
    #
    #	Load var/trans association database with data from a project file.
    #
    # Arguments:
    #	data	var/transform associations to remember
    #
    # Results:
    #	None.

    method mainDeserialize {data} {
	foreach item $data {
	    foreach {var lev tr} $item break
	    if {[catch {set tid [transform::getTransformId $tr]}]} {
		# Ignore unknown transformations.
		continue
	    }
	    set mainTransform($var,$lev) $tid
	}
	return
    }

    # ### ### ### ######### ######### #########

    # method setArrayExpanded --
    #
    #	Set the expanded value for an array.
    #
    # Arguments:
    #	oname	The original, unmangled, array name.
    #	level	The level to get variables from.
    #	expand	Boolean, 1 means the array is expanded.
    #
    # Results:
    #	Returns 1 if the array is expanded.

	variable expanded -array {}

    method setArrayExpanded {level oname expand} {
	set expanded($level,$oname) $expand
	return
    }

    # method isArrayExpanded --
    #
    #	Check to see if an array is fully expanded.
    #
    # Arguments:
    #	oname	The original, unmangled, array name.
    #	level	The level to get variables from.
    #
    # Results:
    #	Returns 1 if the array is expanded.

    method isArrayExpanded {level oname} {
	# No transformation specified - vw
	set key $level,$oname
	if {[info exists expanded($key)] && $expanded($key)} {
	    return 1
	} else {
	    return 0
	}
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

package provide var 1.0
