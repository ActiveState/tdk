# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xrefdb - /snit::type
#
# Loads the database, is given view description objects.
# Runs the db extending methods for the view descriptions.
#

package require BWidget
package require mklist
package require oomk
package require snit


snit::type ::mkdb {

    variable db

    constructor {file args} {
	array set ldesc {}
	set db [mkstorage %AUTO% $file -readonly]
	# -partof $self
	$self configurelist $args
	return
    }

    destructor {
	foreach k [array names ldesc] {
	    rename $ldesc($k) {}
	}
    }


    # Add descriptions for views in the database.

    variable ldesc
    variable lbl
    method list {viewname label __ vcol bcol listscript args} {

	set obj [eval [linsert $args 0 \
		mklistdesc ${selfns}::%AUTO% $viewname $vcol $bcol $listscript \
		]]

	$obj db $self
	set ldesc($viewname) $obj
	set lbl($viewname) $label
	return
    }


    variable sldesc
    variable slbl

    method sublist {viewname label __ vcol bcol listscript args} {

	set obj [eval [linsert $args 0 \
		mklistdesc ${selfns}::%AUTO% $viewname $vcol $bcol $listscript \
		]]

	$obj db $self
	set sldesc($viewname) $obj
	set slbl($viewname) $label
	return
    }


    variable ddesc
    method detail {viewname label __ coldesc layout args} {

	set obj [eval [linsert $args 0 \
		mkdetaildesc ${selfns}::%AUTO% $viewname $coldesc $layout \
		]]

	$obj db $self
	set ddesc($viewname) $obj
	return
    }



    # And use them to get list and detail displays
    # for views and records

    method listlabel {viewname} {
	return $lbl($viewname)
    }

    method labels {} {
	set res [list]
	foreach k [array names lbl] {
	    lappend res [list $k $lbl($k)]
	}
	return $res
    }

    method listviews {{sorted 0}} {
	if {!$sorted} {
	    return [array names ldesc]
	} else {
	    set res {}
	    foreach item [lsort -index 1 [$self labels]] {
		lappend res [lindex $item 0]
	    }
	    return $res
	}
    }

    method newlist {w viewname {v {}}} {
	return [$ldesc($viewname) newlist $w $v]
    }
    method newsublist {w viewname subview} {
	return [$sldesc($viewname) newlist $w $subview]
    }
    method newdetail {w viewname rowid {v {}}} {
	return [$ldesc($viewname) newdetail $w $rowid $v]
    }


    method Deref {vv id -> str by vbname prop} {
	upvar $vbname    vb
	upvar ${vbname}c vbc
	upvar $vv v
	if {![info exists vb]} {
	    [$self view $vbname] as vb
	    $vb cursor vbc
	}
	if {$v($id) >= 0} {
	    set vbc(#) $v($id)
	    set v($str) $vbc($prop)
	} else {
	    set v($str) ""
	}
	return
    }

    method DerefSimple {ivar id str -> fcvar label} {
	upvar $ivar v $fcvar fc
	if {$v($id) >= 0} {
	    set fc(#)   $v($id)
	    set v($str) $fc($label)
	} else {
	    set v($str) ""
	}
	return
    }

    method DerefCopy {ivar id fcvar props} {
	upvar $ivar v $fcvar fc
	set fc(#) $v($id)
	foreach p $props {
	    set v($p) $fc($p)
	}
	return
    }

    delegate method * to db
    delegate option * to db
}





snit::type ::mklistdesc {

    # View description
    # - Code to extend it with all computed elements we need.
    # - Columns it has to have.
    # - Visible columns (can be computed)
    # - Column titles (for visibles only)

    variable visible {}
    variable titles  {}
    variable basic   {}
    variable vname   {}
    variable adjust  {}

    constructor {viewname vcolumns basiccolumns lscript args} {
	foreach {c t} $vcolumns {
	    lappend visible $c
	    lappend titles  $t
	}
	set basic   $basiccolumns
	set adjust  $lscript
	set vname   $viewname

	$self configurelist $args
	return
    }

    variable db
    method   db {container} {
	set db $container
	return
    }

    if 0 {
	variable view
	method connect {viewname} {
	    [$db view $viewname] as view
	    $self CheckProperties $basic
	    $self Extend
	    $self CheckProperties $visible
	    set vname $viewname
	    return
	}
    }

    method newlist {w {v {}}} {
	# New widget 'w'

	if {$v == {}} {set v [$db view $vname]}

	$self CheckProperties $v $basic
	$self CheckProperties $v $visible

	set list [mklist $w $v $visible $titles]

	# Run an additional script to modify the list.
	# Assumes presence of variable 'list' in scope.
	eval $adjust

	return $list
    }

    method newsublist {w subview} {
	# New widget 'w'

	$self CheckProperties $subview $basic
	$self CheckProperties $subview $visible

	set list [mksublist $w $subview $visible $titles]

	# Run an additional script to modify the list.
	# Assumes presence of variable 'list' in scope.
	eval $adjust

	return $list
    }

    method CheckProperties {view plist} {
	$self GetProperties $view p
	foreach b $plist {
	    if {![info exists p($b)]} {
		return -code error \
			"Description does not match view.\
			Required property \"$b\" is not \
			known to the view \"$view\""
	    }
	}
	return
    }

    method GetProperties {view {pvar {}}} {
	set pnames [list]
	foreach p [$view properties] {
	    foreach {pname ptype} [split $p :] break
	    lappend pnames $pname
	}
	if {$pvar != {}} {
	    upvar $pvar properties
	    array set   properties {}
	    foreach p $pnames {
		set properties($p) .
	    }
	}
	return $pnames
    }

    method Extend {} {
	# Run the extension script. It has access to
	# all the instance variables, especially
	# 'view'
	eval $extend
	return
    }
}



package provide mkdb 0.1

