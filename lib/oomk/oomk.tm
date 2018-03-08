# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package oomk 0.3.1
# Meta platform    tcl
# Meta require     {Mk4tcl -version 2.4.9}
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# oomk -- an object-oriented Tcl wrapper around Metakit / Mk4tcl
#
# Example: instead of "mk::view size db.names", we create a $names cmd
# and use "$names size", this is similar to the way Tk widgets work.
#
# This implementation uses Will Duquette's "snit" pure-tcl OO system,
# see http://wiki.tcl.tk/snit and http://www.wjduquette.com/snit/
#
# Written by Jean-Claude Wippler <jcw@equi4.com>, Jan 2003.
# Hold the author harmless and any lawful use is permitted.

package require snit ;# 0.8
package require Mk4tcl 2.4.9
#package provide oomk 0.3.1

if {
    ([package require Mk4tcl] eq "2.4.9.2") ||
    ([package require Mk4tcl] eq "2.4.9.3") ||
    ([package require Mk4tcl] eq "2.4.9.4") ||
    ([package require Mk4tcl] eq "2.4.9.5") ||
    ([package require Mk4tcl] eq "2.4.9.6") ||
    ([package require Mk4tcl] eq "2.4.9.7")
} {
    snit::macro mkview::select::bug {} {return 1}
} else {
    snit::macro mkview::select::bug {} {return 0}
}

# wrapper for MK storages (which are also views)
snit::type mkstorage {
    delegate method * to mk
    variable db

    variable storage

    constructor {args} {
	set db db_[namespace tail $self]
	eval [linsert $args 0 mk::file open $db]
	set mk [mkpath $db]
	set storage $self
	$mk storage: $self
	return
    }

    destructor {
	catch {$mk close}
	catch {mk::file close $db}
    }

    # underlying MK dataset name
    method dbname {} { return $db }

    # set storage of storage, for wrapper around this type
    method storage: {storage_} {
	set storage  $storage_
	$mk storage: $storage_
	return
    }


    # puts self in a var, with cleanup as unset trace
    method as {vname} {
	upvar 1 $vname v
	set v $self
	trace add variable v unset "$self destroy ;#"
    }

    # calls which operate on the dataset
    method commit {} {
	mk::file commit $db
    }

    # define or restructure or inspect a top level view
    method layout {view args} {
	eval mk::view layout $db.$view $args
    }

    # create toplevel view object, restructuring it if needed
    method view {view {fmt ""}} {
	if {$fmt ne ""} { $self layout $view $fmt }
	$self open 0 $view
    }

    # create and fill a (flat) view with data
    method define {vname vars {data ""}} {
	upvar 1 $vname v
	[$self view $vname $vars] as v
	set i 0
	foreach x $vars { lappend temps v[incr i] }
	foreach $temps $data {
	    set c [list $v append]
	    foreach x $vars y $temps { lappend c $x [set $y] }
	    eval $c
	}
    }
}

# create snit object (a "snob"?) from a MK path description
proc mkpath {args} {
    _mksnit [eval [linsert $args 0 mk::view open]]
}

# mk commands objects are renamed to "blah.mk", so snit becomes "blah"
proc _mksnit {v} {
    set v [namespace which $v]
    rename $v $v.mk
    mkview $v $v.mk
}

# wrapper for MK views
snit::type mkview {
    delegate method * to mk

    constructor {v} { set mk $v }

    destructor { $mk close }

    # underlying MK view name
    method mkname {} { return $mk }

    variable storage
    # return storage object which created the view
    method storage {} {return $storage}

    # set the storage to remember.
    method storage: {storage_} {set storage $storage_}


    # puts self in a var, with cleanup as unset trace
    method as {vname} {
	upvar 1 $vname v
	set v $self
	trace add variable v unset "$self destroy ;#"
    }

    # row operations
    method insert {pos args} {
	if {[llength $args] == 1} { set args [lindex $args 0] }
	eval [linsert $args 0 $self.mk insert $pos]
    }

    method append {args} {
	$self insert end $args
    }

    # expand args if needed (i.e. if 1 arg given, "flatten" it)
    foreach x {find search} {
	eval [string map [list #M# $x] {
	    method #M# {args} {
		if {[llength $args] == 1} { set args [lindex $args 0] }
		eval [linsert $args 0 $self.mk #M#]
	    }
	}] ; # {}
    }

    # unary view ops
    foreach x {blocked clone copy readonly unique} {
	eval [string map [list #M# $x] {
	    method #M# {} {
		set v [_mksnit [$self.mk view #M#]]
		$v storage: [$self storage]
		return $v
	    }
	}] ; # {}
    }

    # binary view ops
    foreach x {concat different intersect map minus pair product union} {
	eval [string map [list #M# $x] {
	    method #M# {view} {
		set v [_mksnit [$self.mk view #M# $view.mk]]
		$v storage: [$self storage]
		return $v
	    }
	}] ; # {}
    }

    # unary varargs view ops
    foreach x {indexed ordered project range rename restrict} {
	eval [string map [list #M# $x] {
	    method #M# {args} {
		set v [_mksnit [eval [linsert $args 0 $self.mk view #M#]]]
		$v storage: [$self storage]
		return $v
	    }
	}] ; # {}
    }

    # 2003-06-11: work around groupby bug in mk4too
    method groupby {subv args} {
	set v [_mksnit [eval [linsert $args 0 $self.mk view groupby $subv:V]]]
	$v storage: [$self storage]
	return $v
    }

    method flatten {subv} {
	set v [_mksnit [eval [list $self.mk view flatten $subv:V]]]
	$v storage: [$self storage]
	return $v
    }

    # binary varargs view ops
    foreach x {hash join} {
	eval [string map [list #M# $x] {
	    method #M# {view args} {
		set v [_mksnit [eval [linsert $args 0 $self.mk view #M# $view.mk]]]
		$v storage: [$self storage]
		return $v
	    }
	}] ; # {}
    }

    # 2003-04-08: work around select bug in 2.4.9.2
    # 2004-02-10: Updated to also handle    2.4.9.3
    # 2006-11-10: 2.4.9.5 still needs work around.
    # 2007-06-20: No changes in 2496, 2497. Keeping workaround.

    if {[mkview::select::bug]} {
	method select {args} {
	    if {[llength $args] == 1} { set args [lindex $args 0] }
	    set tmpView [_mksnit [eval [linsert $args 0 $self.mk select]]]
	    if {
		[lsearch -exact $args -sort] >= 0 ||
		[lsearch -exact $args -rsort] >= 0
	    } {
		$tmpView storage: [$self storage]
		return $tmpView
	    }
	    set view [$self map $tmpView]
	    $tmpView destroy
	    $view storage: [$self storage]
	    return $view
	}
    } else {
	method select {args} {
	    if {[llength $args] == 1} { set args [lindex $args 0] }
	    set v [_mksnit [eval [linsert $args 0 $self.mk view select]]]
	    $v storage: [$self storage]
	    return $v
	}
    }

    # other ops
    method noop {} { } ;# baseline for timing purposes

    # create subview object
    method open {row prop} {
	set v [_mksnit [$self.mk open $row $prop]]
	$v storage: [$self storage]
	return $v
    }

    # avoid "info" name clash with snit
    method properties {} {
	$self.mk info
    }

    # pretty-print contents
    method dump {{prefix ""}} {
	set h [$self.mk info]
	foreach x $h {
	    foreach {h t} [split $x :] break
	    switch $t I - F - D - B { set a "" } default { set a - }
	    lappend wv [string length $h]
	    lappend hv $h
	    lappend tv $t
	    lappend av $a
	}
	set dv {}
	$self.mk loop c {
	    set c [eval [linsert $hv 0 $self.mk get $c]]
	    set ov {}
	    set nv {}
	    foreach d $c w $wv t $tv a $av {
		set l [string length $d]
		if {$l > $w} { set w $l }
		lappend ov $d
		lappend nv $w
	    }
	    set wv $nv
	    lappend dv $c
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

    # create a cursor to match a row
    method cursor {aname} {
	# A special reason why this doesn't use '$self', but the
	# internal handle ?

	uplevel 1 [list mkx::acursor $aname $self.mk $storage]
    }

    # create a cursor and loop over it
    method loop {aname body} {
	uplevel 1 [list $self cursor $aname]
	upvar $aname aref
	set n [$self size]
	for {set aref(#) 0} {$aref(#) < $n} {incr aref(#)} {
	    set c [catch { uplevel 1 $body } r]
	    switch -exact -- $c {
		0 {}
		1 { return -errorcode $::errorCode -code error $r }
		3 { return }
		4 {}
		default { return -code $c $r }
	    }
	}
    }
}

namespace eval mkx {

    proc _rtracer {view subs storage a e op} {
	upvar 1 $a aref
	if {$e ne "#"} {
	    if {[lsearch -sorted $subs $e] < 0} {
		set aref($e) [$view get $aref(#) $e]
	    } else {
		set aref($e) [_mksnit [$view open $aref(#) $e]]
		$aref($e) storage: $storage
		trace add variable aref($e) unset "$aref($e) destroy ;#"
	    }
	}
    }

    proc _wtracer {view a e op} {
	upvar 1 $a aref
	if {$e ne "#"} {
	    $view set $aref(#) $e $aref($e)
	}
    }

    proc acursor {aname view storage} {
	upvar 1 $aname aref
	unset -nocomplain aref
	set aref(#) 0
	set subs {}
	foreach x [$view info] {
	    foreach {prop type} [split $x :] break
	    if {$type eq "V"} {
		lappend subs $prop
	    }
	    set aref($prop) ""
	}
	trace add variable aref read \
		[list [namespace which _rtracer] $view [lsort $subs] $storage]
	trace add variable aref write \
		[list [namespace which _wtracer] $view]
    }

    proc viewof {aname} {
	upvar 1 $aname aref
	foreach x [trace info variable aref] {
	    if {[lindex $x 1 0] eq "::mkx::_rtracer"} {
		return [lindex $x 1 1]
	    }
	}
    }
}

return
