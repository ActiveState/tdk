# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# transform.tcl --
#
#	This file implements the transformation database used
#	by the watch window and data display.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########

# Bugzilla 19719 ... Implementation of new functionality.
# #######################################################

namespace eval transform {
    # III. Transformations.
    #
    # Internally identified by a generated id (counter). The id is
    # mapped to two tcl commands: One to check that the value to
    # transform actually satisfies the requirements of the
    # transformation (like being an integer), and the transformation
    # itself. The id also maps to a short string which can be used in
    # a menu or other GUI element when selecting a transformation.
    #
    # Signatures
    #
    # value_is_ok:     args value -> boolean	True <=> value acceptable
    # value_transform: args value -> string
    #
    # The 'args' prefixes mean that the commands given to this
    # module are actually command prefixes, commands + some fixed
    # arguments.
    #
    # Predefined transformations are handled like user-defined
    # ones. I.e. registered here iwith the general data structures.
    #
    # All other parts refer to transform by id only

    variable idcounter 0
    variable value_is_ok     ; array set value_is_ok     {}
    variable value_transform ; array set value_transform {}
    variable value_dpytext   ; array set value_dpytext   {}
    variable value_id        ; array set value_id        {}

    # The standard transformation has a special id and is
    # registered directly, instead of via 'newTransform'.

    set value_is_ok()     {} ;#transform::valueIsAlwaysOk 
    set value_transform() {} ;#identity
    set value_dpytext()   "<No Transformation>"
    set {value_id(<No Transformation>)} {}
}

# #######################################################
# Transformation mgmt

# transform::newTransform --
#
#	Register a new transformation
#
# Arguments:
#	dpytext		Text to display in the UI
#	ok		See 'value_is_ok' above
#	transform	See 'value_transform' above
#
# Results:
#	None

proc transform::newTransform {dpytext ok transform} {
    variable idcounter
    set id [incr idcounter]

    variable value_is_ok
    variable value_transform
    variable value_dpytext
    variable value_id

    set value_is_ok($id)     $ok
    set value_transform($id) $transform
    set value_dpytext($id)   $dpytext

    # Reverse mapping NAME => ID (for UI)
    set value_id($dpytext)   $id
    return
}

# transform::listTransforms --
#
# Arguments:
#	None
#
# Results:
#	Return list of defined transformations

proc transform::listTransforms {} {
    variable value_dpytext
    return [lsort [array names value_dpytext]]
}

# transform::getTransformId --
#
# Arguments:
#	name	name of transformation to query
#
# Results:
#	Returns id of named transformation.
#

proc transform::getTransformId {name} {
    variable value_id
    return $value_id($name)
}

# transform::getTransformName --
#
# Arguments:
#	id	id of transformation to query
#
# Results:
#	Returns display text of id'd transformation.
#

proc transform::getTransformName {id} {
    variable value_dpytext
    return $value_dpytext($id)
}

# transform::getTransformCmds --
#
# Arguments:
#	id	id of transformation to query
#
# Results:
#	Return transform commands of id'd transformation.
#

proc transform::getTransformCmds {id} {
    variable value_is_ok
    variable value_transform

    return [list $value_is_ok($id) $value_transform($id)]
}

# #######################################################
# Transformation association and use.

# transform::transform --
#
#	Transform a value according to id'd transformation
#
# Arguments:
#	value	Value to transform
#	id	id of transformation to use.
#
# Results:
#	2-element list:
#	(0) boolean flag - False => Transform failure
#	(1) string       - Transformed value
#			   == input in case of failure

proc transform::transform {value id} {
    foreach {ok transform} [getTransformCmds $id] break

    if {$ok == {} || $transform == {}} {
	return [list 0 $value]
    }

    lappend ok $value
    if {![eval $ok]} {
	return [list 0 $value]
    }

    lappend transform $value
    if {[catch {
	set new [eval $transform]
    } msg]} {
	return [list 0 $value]
    } else {
	return [list 1 $new]
    }
}

# #######################################################
# Commands for predefined transformations.

proc transform::valueIsInteger  {value} {string is integer -strict $value}
proc transform::valueIsAlwaysOk {value} {return 1}

proc transform::valueIntToHex   {value} {format 0x%04x $value} ; # assumes 32 bits
proc transform::valueIntToOctal {value} {format 0o%o   $value}
proc transform::valueIntToBits  {value} {
    variable hexbits
    return 0b[string map $hexbits [format %x $value]]
}

namespace eval transform {
    variable hexbits {
	0 0000        4 0100        a 1010        A 1010
	1 0001        5 0101        b 1011        B 1011
	2 0010        6 0110        c 1100        C 1100
	3 0011        7 0111        d 1101        D 1101
	8 1000        9 1001        e 1110        E 1110
	f 1111        F 1111
    }
}

proc transform::valueStringToHex {value} {
    set res [list]
    foreach c [split $value {}] {
	lappend res [format %x [scan $c %c]]
    }
    return [join $res]
}

proc transform::valueStringToOctal {value} {
    set res [list]
    foreach c [split $value {}] {
	lappend res [format %o [scan $c %c]]
    }
    return [join $res]
}

proc transform::valueStringToUnicode {value} {
    set res ""
    foreach c [split $value {}] {
	append res \\u[format %04x [scan $c %c]]
    }
    return $res
}


# #######################################################
# Generate a tk_optionMenu for the selection of a transformation

# transform::transformSelectorOM --
#
#	
#
# Arguments:
#	w	Widget to create
#	var	Name of associated variable.
#
# Results:
#	A widget

proc transform::transformSelectorOM {w var} {
    upvar 1 $var x

    ttk::menubutton $w -textvariable $var -menu $w.menu
    set m [menu $w.menu -tearoff 0]
    foreach t [listTransforms] {
	set name [getTransformName $t]
	$m add command -label $name -command [list set $var $name]
    }
    set x [getTransformName [lindex [listTransforms] 0]]
    return $w
}

# #######################################################
# Declare predefined transformations

foreach {dpytext ok transform} {
    {String: As Hex}     transform::valueIsAlwaysOk transform::valueStringToHex
    {String: As Octal}   transform::valueIsAlwaysOk transform::valueStringToOctal
    {String: As Unicode} transform::valueIsAlwaysOk transform::valueStringToUnicode
    {Integer: As Hex}    transform::valueIsInteger  transform::valueIntToHex
    {Integer: As Octal}  transform::valueIsInteger  transform::valueIntToOctal
    {Integer: As Bits}   transform::valueIsInteger  transform::valueIntToBits
} {
    transform::newTransform $dpytext $ok $transform
}

# ### ### ### ######### ######### #########

package provide transform 0.1
