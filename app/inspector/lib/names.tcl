# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: names.tcl,v 1.6 2002/10/26 16:31:17 patthoyts Exp $
#

namespace eval names {
    namespace export -clear names procs vars prototype value exports
}

proc ::names::unqualify {s} {
    # strip off just the leading '::', if any, for a cleaner output
    regsub -all "(^| ):+" $s {\1} s
    return $s
}

proc ::names::names {target {name ::}} {
    set result $name
    foreach n [send $target [list ::namespace children $name]] {
	eval [list lappend result] [names $target $n]
    }
    return $result
}

proc ::names::procs {target {names ""}} {
    if {$names == ""} {
	set names [names $target]
    }
    set result {}
    foreach n $names {
	foreach p [send $target [list ::namespace eval $n ::info procs]] {
	    lappend result "${n}::$p"
	}
    }
    return [unqualify $result]
}

# pinched from globals_list.tcl
proc ::names::prototype {target proc {verbose 0}} {
    # return "proc $name $formalArgs $body"
    if {$verbose} {
	set result [list proc $proc]
    } else {
	set result [list proc [namespace tail $proc]]
    }
    if {[catch {send $target [list ::info args $proc]} args]} {
	return "\# No known proc '$proc'"
    }
    set tmpVar "__inspector:default_arg__"
    set formals [list]
    foreach arg $args {
	if {[send $target [list ::info default $proc $arg $tmpVar]]} {
	    lappend formals [list $arg [send $target [list ::set $tmpVar]]]
	} else {
	    lappend formals $arg
	}
    }
    send $target [list ::catch [list ::unset $tmpVar]]
    lappend result $formals

    if {$verbose} {
	lappend result [send $target [list ::info body $proc]]
    } else {
	lappend result {}
    }
    return $result
}

proc ::names::vars {target {names ""}} {
    if {$names == ""} {
	set names [names $target]
    }
    set result {}
    foreach n $names {
	foreach v [send $target [list ::info vars ${n}::*]] {
	    lappend result $v
	}
    }
    return [unqualify $result]
}

proc ::names::value {target var} {
    set result "variable [list [namespace tail $var]]"
    if {![send $target [list ::info exists $var]]} {
	return "$result\t; # (UNDEFINED)"
    }
    if {[send $target [list ::array exists $var]]} {
	return "$result\t; # (ARRAY)" ; # dump it out?
    }
    if {[catch [list send $target [list ::set $var]] val]} {
	return "$result\t; # (UNDEFINED)"
    } else {
	return "$result\t[list $val]"
    }
}

proc ::names::exports {target namespace} {
    return [send $target [list ::namespace eval $namespace ::namespace export]]
}
