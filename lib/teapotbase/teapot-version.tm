# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::version 0.1
# Meta category    teapot
# Meta description Teapot support functionality. Validation of version
# Meta description numbers. Data structures for various concepts, like
# Meta description references, entity instances and the like.
# Meta platform    tcl
# Meta require     logger
# Meta subject     teapot {version validation} {transfer data structures}
# Meta summary     Teapot support functionality. Validating version
# Meta summary     numbers. Data structures.
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Operations on and for package version numbers.

# ### ### ### ######### ######### #########
## Requirements

package require logger

logger::initNamespace ::teapot::version
namespace eval        ::teapot::version {}

# ### ### ### ######### ######### #########
## Implementation

proc ::teapot::version::check {v} {
    if {![valid $v message]} {return -code error $message}
}

proc ::teapot::version::valid {v {mv {}}} {
    # Was "repository::api::_versionok"

    if {$mv ne ""} {upvar 1 $mv message}

    # Defer to the underlying Tcl interpreter. While there is no
    # direct validation (sub)command we can mis-use "packagevcompare"
    # for our purposes. Provide a valid version number as second
    # argument and discard the comparison result. We are only
    # interested in the ok/error status, the latter thrown if and only
    # if the argument is a syntactically invalid version number.

    set ok [expr {[catch {package vcompare $v 0}] ? 0 : 1}]

    if {!$ok} {
	set message "Bad version \"$v\""
    }
    return $ok
}

proc ::teapot::version::grok {v} {
    # Try to extract a sensible version number out of arbitrary data.
    # (See f.e. .tap files which may contain mangled stuff)

    if {[regexp {^([0-9]+(\.[0-9]+)*)} $v -> xv]} {
	regsub      {^00+\.}     $xv {0.} xv
	regsub -all {\.0([0-9])} $xv {.\1} xv
	return $xv
    }

    # Create a sensible default number where we were unable to extract
    # anything from the string itself.

    return 0
}

proc ::teapot::version::next {v} {
    # Examples:
    # * 8.4   -> 8.5
    # * 8.5.9 -> 8.5.10
    #
    # Note: We remove leading zeros (via [scan]) to prevent
    # mis-interpretation as an octal number.

    set vn [split $v .]
    scan [lindex $vn end] %d last
    return [join [lreplace $vn end end [incr last]] .]
}

proc ::teapot::version::range {v} {
    return ${v}-[next $v]
}

proc ::teapot::version::major {v} {
    return [join [lrange [split $v .] 0 1] .]
}

# ### ### ### ######### ######### #########

proc ::teapot::version::reqcheck {req} {
    if {![reqvalid $req message]} {return -code error $message}
}

proc ::teapot::version::reqvalid {req {mv {}}} {
    if {$mv ne ""} {upvar 1 $mv message}

    if {[string match *-* $req]} {
	set rx [split $req -]
    } else {
	set rx $req
    }
    if {[llength $rx] == 1} {
	if {![valid [lindex $rx 0] message]} {return 0}
    } elseif {[llength $rx] == 2} {
	foreach {min max} $rx break
	if {![valid $min message]}                 {return 0}
	if {($max ne "") && ![valid $max message]} {return 0}
    } else {
	set message "Bad requirement \"$req\""
	return 0
    }
    return 1
}

proc ::teapot::version::reqstring {req} {
    if {[llength $req] == 1} {
	return [lindex $req 0]
    } elseif {[llength $req] == 2} {
	foreach {min max} $req break
	if {$max eq ""} {
	    return ${min}-
	} else {
	    return ${min}-$max
	}
    }
}

# ### ### ### ######### ######### #########
## Ready
return
