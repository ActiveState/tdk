# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::listspec 0.1
# Meta category    teapot
# Meta description Teapot support functionality. Queries, searching,
# Meta description listing. Data structures for various concepts, like
# Meta description references, entity instances and the like.
# Meta platform    tcl
# Meta require     logger
# Meta require     teapot::entity
# Meta require     teapot::version
# Meta subject     teapot {instance query information}
# Meta subject     {instance search information} {transfer data structures}
# Meta summary     Teapot support functionality. Queries, searching,
# Meta summary     listing. Data structures.
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Operations on and for list specifications

# ### ### ### ######### ######### #########
## Requirements

package require teapot::version
package require teapot::entity
package require logger

logger::initNamespace ::teapot::listspec
namespace eval        ::teapot::listspec {}

# ### ### ### ######### ######### #########
## Syntax

# i    all       list/1 (0)
# ii   name      list/2 (0 name)
# iii  version   list/3 (0 name ver)
# iv   instance  list/4 (0 name ver arch)
# v    eall      list/2 (1 entity)
# vi   ename     list/3 (1 entity name)
# vii  eversion  list/4 (1 entity name ver)
# viii einstance list/5 (1 entity name ver arch)

# ### ### ### ######### ######### #########
## Implementation

namespace eval  ::teapot::listspec {
    variable we "wrong\#elements, expected 'typed ?entity? ?name version architecture?'"
}

proc ::teapot::listspec::valid {listspec {mv {}}} {
    variable we

    if {$mv ne ""} {upvar 1 $mv message}

    if {[catch {llength $listspec} msg]} {
	set message $msg
	return 0
    }

    if {
	([llength $listspec] < 1) ||
	([llength $listspec] > 5)
    } {
	set message $we
	return 0
    }

    set typed [lindex $listspec 0]

    if {[catch {expr {!$typed}} msg]} {
	set message $msg
	return 0
    }

    set len   [llength $listspec]

    if {$typed} {
	switch -- $len {
	    2 {foreach {_ e}       $listspec break}
	    3 {foreach {_ e n}     $listspec break}
	    4 {foreach {_ e n v}   $listspec break}
	    5 {foreach {_ e n v a} $listspec break}
	    default {
		set message $we
		return 0
	    }
	}
	if {![teapot::entity::valid $e message]} {return 0}

	# The next command ensures that len values are identical for
	# the two branches. This allows us to move the n/v/a checks
	# behind the if and merge them into a single set.

	incr len -1
    } else {
	switch -- $len {
	    1 {foreach {_}       $listspec break}
	    2 {foreach {_ n}     $listspec break}
	    3 {foreach {_ n v}   $listspec break}
	    4 {foreach {_ n v a} $listspec break}
	    default {
		set message $we
		return 0
	    }
	}
    }

    if {($len > 1) && ($n eq "")} {set message "Empty name";         return 0}
    if {($len > 2) && ($v eq "")} {set message "Empty version";      return 0}
    if {($len > 3) && ($a eq "")} {set message "Empty architecture"; return 0}

    if {($len > 2) && ![teapot::version::valid $v message]} {return 0}

    return 1
}

proc ::teapot::listspec::all {} {
    set listspec [list 0]
    if {![valid $listspec message]} {
	return -code error $message
    }
    return $listspec
}

proc ::teapot::listspec::eall {e} {
    set listspec [list 1 [string tolower $e]]
    if {![valid $listspec message]} {
	return -code error $message
    }
    return $listspec
}

proc ::teapot::listspec::name {n} {
    set listspec [list 0 $n]
    if {![valid $listspec message]} {
	return -code error $message
    }
    return $listspec
}

proc ::teapot::listspec::ename {e n} {
    set listspec [list 1 [string tolower $e] $n]
    if {![valid $listspec message]} {
	return -code error $message
    }
    return $listspec
}

proc ::teapot::listspec::version {n v} {
    set listspec [list 0 $n $v]
    if {![valid $listspec message]} {
	return -code error $message
    }
    return $listspec
}

proc ::teapot::listspec::eversion {e n v} {
    set listspec [list 1 [string tolower $e] $n $v]
    if {![valid $listspec message]} {
	return -code error $message
    }
    return $listspec
}

proc ::teapot::listspec::instance {n v a} {
    set listspec [list 0 $n $v $a]
    if {![valid $listspec message]} {
	return -code error $message
    }
    return $listspec
}

proc ::teapot::listspec::einstance {e n v a} {
    set listspec [list 1 [string tolower $e] $n $v $a]
    if {![valid $listspec message]} {
	return -code error $message
    }
    return $listspec
}

proc ::teapot::listspec::cons {e pkg} {
    # entity = ?name ?version ?arch???

    if {$e eq ""} {
	switch -- [llength $pkg] {
	    0 {all}
	    1 {foreach {n}     $pkg break ; name     $n}
	    2 {foreach {n v}   $pkg break ; version  $n $v}
	    3 {foreach {n v a} $pkg break ; instance $n $v $a}
	}
    } else {
	switch -- [llength $pkg] {
	    0 {eall $e}
	    1 {foreach {n}     $pkg break ; ename     $e $n}
	    2 {foreach {n v}   $pkg break ; eversion  $e $n $v}
	    3 {foreach {n v a} $pkg break ; einstance $e $n $v $a}
	}
    }
}

proc ::teapot::listspec::changeName {lv n} {
    upvar 1 $lv listspec

    set typed [lindex  $listspec 0]

    if {$typed} {
	if {[llength $listspec] > 2} {
	    set listspec [lreplace $listspec 2 2 $n]
	}
    } else {
	if {[llength $listspec] > 1} {
	    set listspec [lreplace $listspec 1 1 $n]
	}
    }
}

proc ::teapot::listspec::split {listspec ev nv vv av} {
    upvar 1 $ev e $vv v $nv n $av a

    set typed [lindex  $listspec 0]
    set len   [llength $listspec]

    if {$typed} {
	switch -- $len {
	    2 {foreach {_ e}       $listspec break ; return eall}
	    3 {foreach {_ e n}     $listspec break ; return ename}
	    4 {foreach {_ e n v}   $listspec break ; return eversion}
	    5 {foreach {_ e n v a} $listspec break ; return einstance}
	}
    } else {
	switch -- $len {
	    1 {                                    return all}
	    2 {foreach {_ n}     $listspec break ; return name}
	    3 {foreach {_ n v}   $listspec break ; return version}
	    4 {foreach {_ n v a} $listspec break ; return instance}
	}
    }

    return -code error "Bad spec \"$listspec\""
}

proc ::teapot::listspec::print {listspec} {
    set typed [lindex  $listspec 0]
    set len   [llength $listspec]

    if {$typed} {
	switch -- $len {
	    2 {foreach {_ e}       $listspec break ; return "all ${e}s"}
	    3 {foreach {_ e n}     $listspec break ; return "all ${e}s $n"}
	    4 {foreach {_ e n v}   $listspec break ; return "all ${e}s $n $v"}
	    5 {foreach {_ e n v a} $listspec break ; return "all ${e}s $n $v for $a"}
	}
    } else {
	switch -- $len {
	    1 {                                    return "all"}
	    2 {foreach {_ n}     $listspec break ; return "all $n"}
	    3 {foreach {_ n v}   $listspec break ; return "all $n $v"}
	    4 {foreach {_ n v a} $listspec break ; return "all $n $v for $a"}
	}
    }

    return -code error "Bad spec \"$listspec\""
}

proc ::teapot::listspec::print2 {listspec} {
    set typed [lindex  $listspec 0]
    set len   [llength $listspec]

    if {$typed} {
	switch -- $len {
	    2 {foreach {_ e}       $listspec break ; return "${e}s"}
	    3 {foreach {_ e n}     $listspec break ; return "${e}s $n"}
	    4 {foreach {_ e n v}   $listspec break ; return "${e}s $n $v"}
	    5 {foreach {_ e n v a} $listspec break ; return "${e}s $n $v for $a"}
	}
    } else {
	switch -- $len {
	    1 {                                    return ""}
	    2 {foreach {_ n}     $listspec break ; return "$n"}
	    3 {foreach {_ n v}   $listspec break ; return "$n $v"}
	    4 {foreach {_ n v a} $listspec break ; return "$n $v for $a"}
	}
    }

    return -code error "Bad spec \"$listspec\""
}

proc ::teapot::listspec::2instance {listspec} {
    set  typed [lindex $listspec 0]
    if {$typed} {
	set len [llength $listspec]
	switch -- $len {
	    2 - 3 - 4 {}
	    5 {
		foreach {_ e n v a} $listspec break
		return [list $e $n $v $a]
	    }
	}
    }

    return -code error "Listspec \"$listspec\" not an instance"
}

proc ::teapot::listspec::type {listspec} {
    set typed [lindex  $listspec 0]
    set len   [llength $listspec]

    if {$typed} {
	switch -- $len {
	    2 {return eall}
	    3 {return ename}
	    4 {return eversion}
	    5 {return einstance}
	}
    } else {
	switch -- $len {
	    1 {return all}
	    2 {return name}
	    3 {return version}
	    4 {return instance}
	}
    }

    return -code error "Bad spec \"$listspec\""
}

# ### ### ### ######### ######### #########
## Ready
return
