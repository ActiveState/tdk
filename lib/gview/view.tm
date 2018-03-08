# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package view 1.0
# Meta platform    tcl
# Meta require     obman
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ######### ###########################

# Tools. Basic adaptor class for tabular views, with arrays cursors.

# In other words, the instances of this class provide a tabular
# interface to some data, and are able to create arrays as cursors
# into the data. The data itself is queried from a different object
# using a standardized set of methods. This set of methods is
# described as part of the public interface of the class defined
# here. Instances can be used as components of other classes so that
# their instances can have a tabular interface too.

# Origin: oomk, an object-oriented Tcl wrapper around Metakit /
# Mk4tcl, both (oomk and Metakit/Mk4tcl) by Jean-Claude Wippler
# <jcw@equi4.com>. Basically oomk was stripped of all metakit specific
# code, and of all code dealing with databases. The only stuff left is
# the basic functionality and interface of a view, with code to route
# any inquiry to the actual data source.

# New functionality added here is a notification mechanism by which a
# data source can tell the views on it about changes in the data, so
# that they can be propagated into both cursors on the view, and views
# derived from it.

# ### ######### ###########################
## Prerequisites

package require snit  ; # Object-system.
package require obman ; # Observer management

# ### ######### ###########################
## Implementation
#
## API expected from the 'source' object.
##
##-----------------------------------------
## General note: The following two methods are optional. If they are
## not present in the source the view will simply not react to changes
## in the contents of the source.
##
## onChangeCall object
##	Register <object> to be called on changes.
##
##	The source will invoke the method 'change' of <object> with
##	itself as argument whenever its contents change.
##
## removeOnChangeCall object
##	Remove <object> from the list of objects to be called on
##	changes.
##-----------------------------------------
##
## names
##	Return a list of the attributes (aka columns) in the
##	source. This list contains only the names of said columns, and
##	no type information.
##
## isview attribute
##	Result is boolean flag. The flag is set if the contents of the
##	attribute are a view in themselves.
##
## isstring attribute
##	Result is boolean flag. The flag is set if the contents of the
##	attribute are printable strings.
##
## set row attribute value
##	Set the contents of the cell <row>,<attribute> in the
##	source to value. This operation is illegal for attributes which
##	contain sub-views.
##
## get row attribute
##	Returns the contents of cell <row>,<attribute>.
##
## open row attribute
##	Legal only for the attributes which contain sub-views. Returns
##	a view for the sub-view in cell <row>,<attribute>.
#
# ### ######### ###########################

snit::type view {
    # ### ######### ###########################

    delegate method * to source
    delegate option * to source

    option -source {}

    # ### ######### ###########################
    ## Public API. (De)Construction.

    constructor {args} {
	set obman [obman ${selfns}::om -partof $self]
	$self configurelist $args
	return
    }

    destructor {
	$obman destroy
	# Remove tracing of changes from the source.
	catch {$source removeOnChangeCall $self}
	return
    }

    # ### ######### ###########################
    ## Public API. Exposed source API.
    #
    ## All methods required by this class
    ## are also exposed to its users.

    delegate method names     to source
    delegate method size      to source
    delegate method isview    to source
    delegate method isstring  to source
    delegate method get       to source
    delegate method set       to source
    delegate method open      to source

    # ### ######### ###########################
    ## Public API. Change propagation

    delegate option -partof to obman

    delegate method change             to obman
    delegate method trigger            to obman
    delegate method onChangeCall       to obman
    delegate method removeOnChangeCall to obman

    # ### ######### ###########################
    ## Public API. 

    # Place self into a variable, use an unset trace to destroy self
    # when this variable is destroyed, for example goes out of scope.

    method as {varname} {
	upvar 1 $varname v
	set v $self
	trace add variable v unset "$self destroy ;#"
	return
    }

    # Create a cursor to match a row

    method cursor {aname} {
	upvar 1    $aname aref
	unset -nocomplain aref

	set aref(#) 0

	foreach prop [$source names] {
	    set aref($prop) ""
	}

	trace add variable aref read  [mymethod OnRead]
	trace add variable aref write [mymethod OnWrite]
	trace add variable aref unset [mymethod OnUnset]
	return
    }

    # Create a cursor and loop over it

    method loop {arrayvarname body} {
	upvar 1 $arrayvarname aref
	$self cursor aref

	set n [$source size]
	upvar 0 aref(#) row

	for {set row 0} {$row < $n} {incr row} {
	    set c [catch { uplevel 1 $body } r]
	    switch -exact -- $c {
		0 {}
		1 { return -errorcode $::errorCode -code error $r }
		3 { return }
		4 {}
		default {
		    return -code $c $r
		}
	    }
	}
	return
    }

    # Pretty-print the contents of the view

    method dump {{prefix ""}} {
	set h [$source names]
	foreach x $h {
	    set a [expr {[$source isstring $x] ? "-" : ""}]
	    lappend wv [string length $x]
	    lappend hv $x
	    lappend av $a
	}
	set dv {}
	$self loop c {
	    set ov {}
	    set nv {}
	    set cv {}
	    foreach x $h w $wv {
		set d $c($x)
		lappend cv $d
		set l [string length $d]
		if {$l > $w} { set w $l }
		lappend ov $d
		lappend nv $w
	    }
	    set wv $nv
	    lappend dv $cv
	}
	foreach w $wv a $av {
	    lappend sv [string repeat - $w]
	    lappend fv "%${a}${w}s"
	}
	set sep "${prefix}--------  [join $sv "  "]"
	set fmt [join $fv "  "]
	puts "$prefix       #  [eval [linsert $hv 0 format $fmt]]"
	puts $sep
	set id 0
	foreach x $dv {
	    puts "$prefix[format %8d $id]  [eval [linsert $x 0 format $fmt]]"
	    incr id
	}
	puts $sep
	puts "$prefix       #  [eval [linsert $hv 0 format $fmt]]"
	return
    }

    # ### ######### ###########################
    ## Internal. Data structures

    variable source   {} ; # Handle of the data source.
    variable varname  {} ; # Transient data, captures true varname of cursors.
    variable obman    {} ; # Observer mgmt component.

    # ### ######### ###########################
    ## Internal. Handling of changes to options.

    onconfigure -source {value} {
	if {$options(-source) != {}} {
	    return -code error "$self configure -source: \
		    Reconfiguration of the data source not allowed"
	}
	set source $value
	catch {$source onChangeCall $self}
	return
    }

    # ### ######### ###########################
    ## Internal. Handle changes in and queries from cursor variables.

    method GetVar {var element op} {
	set varname $var
	return
    }

    method OnRead {var element op} {
	# Fulfill queries by getting the data from the source and
	# placing it into the cursor variable generating the
	# request. Exception is element '#', the row id managed by the
	# cursor. If the caller asked for the data of a 'V'iew
	# attribute then we ask the source to create a new view, and
	# the resulting handle is placed into the cursor. A trace on
	# the cursor is used to ensure that all views created in this
	# way are cleaned up together with the cursor.

	upvar 1 $var aref
	if {$element eq "#"} return

	if {[$source isview $element]} {
	    # View attribute.

	    set aref($element) [$source open $aref(#) $element]
	    trace add variable aref($element) unset "$aref($element) destroy ;#"
	} else {
	    # Normal attribute

	    set aref($element) [$source get $aref(#) $element]
	}
	return
    }

    method OnWrite {var element op} {
	# Transform the change of a cursor variable into a write
	# operation on the source of the view. The exception is
	# element '#', the row id managed by the cursor.

	upvar 1 $var aref
	if {$element eq "#"} return

	$source set $aref(#) $element $aref($element)
	return
    }

    method OnUnset {var element op} {
	# Remove variable from the list of cursors to be refreshed on
	# changes.

	upvar 1 $var aref
	trace remove variable aref read  [mymethod OnRead]
	trace remove variable aref write [mymethod OnWrite]
	trace remove variable aref unset [mymethod OnUnset]
	return
    }

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use
return
