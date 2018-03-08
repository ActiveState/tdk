# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# transMenu.tcl --
#
#	This file implements the popup menu serving the main variable
#	display as transformation selector.
#
# Copyright (c) 2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: varWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########

package require transform
package require snit

# ### ### ### ######### ######### #########

snit::widget transMenu {

    # ### ### ### ######### ######### #########

    constructor {cmd} {
	set vcmd $cmd
	$self MakeWidgets
	return
    }

    method show {vname vtrans x y} {
	set oname  $vname
	set otrans $vtrans
	tk_popup $win.menu $x $y $indxof($vtrans)
	return
    }

    method MakeWidgets {} {
	menu $win.menu -tearoff 0
	foreach t [transform::listTransforms] {
	    $win.menu add command    \
		-label   $nameof($t) \
		-command [mymethod Set $t]
	}
	return
    }

    # ### ### ### ######### ######### #########

    variable vcmd
    variable oname
    variable otrans

    method Set {new} {
	# Ignore non-changes
	if {$new != $otrans} {
	    eval [linsert $vcmd end $oname $new]
	}
	return
    }

    # ### ### ### ######### ######### #########

    typevariable indxof -array {}
    typevariable nameof -array {}

    typeconstructor {
	set index 0
	foreach t [transform::listTransforms] {
	    set nameof($t) [transform::getTransformName $t]
	    set indxof($t) $index
	    incr index
	}
	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

package provide transMenu 0.1
