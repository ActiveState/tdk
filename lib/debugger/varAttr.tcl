# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# varAttr.tcl --
#
#	This file implements data structures remembering additional
#	information for an entry in a dictentry widget. This information
#	is a dict, individual keys can be set and queried. This is for
#	the currently displayed stacklevel.
#
# Copyright (c) 2007 ActiveState Software Inc.

#
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########

package require snit

# ### ### ### ######### ######### #########

snit::type varAttr {
    # ### ### ### ######### ######### #########

    method unset {item {pattern *}} {
	#puts "VA UNSET $item $pattern"
	array unset attr [list $item $pattern]
	return
    }

    method exists {item key} {
	return [info exists attr([list $item $key])]
    }

    # ### ### ### ######### ######### #########

    # method set, setdict, setmany --
    #
    #	Set the attribute value for variable (represented by item).
    #
    # Arguments:
    #	item	Data representing a variable.
    #	key	The name of the attribute to set.
    #	value	The new value of the attribute.
    #	dict	Dictionary of keys and values to set.
    #	args	Like a dict, but as var args.
    #
    # Results:
    #	Returns the value of the variable.

    method set {item key value} {
	#puts "VA SET/1 $item $key"
	set attr([list $item $key]) $value
	return $value
    }

    method setdict {item dict} {
	foreach {key value} $dict {
	    #puts "VA SET/D $item $key"
	    set attr([list $item $key]) $value
	}
	return
    }

    # varargs form of setdict
    method setmany {item args} {
	foreach {key value} $args {
	    #puts "VA SET/M $item $key"
	    set attr([list $item $key]) $value
	}
	return
    }

    # method get --
    #
    #	Get the attribute value if the variable represented by the item.
    #
    # Arguments:
    #	item	Data representing a variable.
    #	key	The name of the attribute to retrieve.
    #
    # Results:
    #	Returns the value of the specified variable attribute.

    method get {item key} {
	#puts "VA GET $item $key"

	set k [list $item $key]
	if {![info exists attr($k)]} {
	    return -code error "illegal attribute \"$key\" for item $item"
	}
	return $attr($k)
    }

    # method reset --
    #
    #	Clear the storage, remove all stored attributes.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method reset {} {
	#puts "VA RESET"
	array unset attr *
	return
    }

    # ### ### ### ######### ######### #########

    variable attr -array {}

    # Attribute storage
    # attr = array (key -> value)
    # key  = list  (varref attrname)

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

package provide varAttr 0.1
