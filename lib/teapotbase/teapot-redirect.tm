# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::redirect 0.1
# Meta category    teapot
# Meta description Teapot support functionality. Redirection entities.
# Meta description Creation of redirections from instance and additional
# Meta description information, i.e. notes and repositories, etc.
# Meta platform    tcl
# Meta require     {Tcl 8.4}
# Meta require     teapot::instance
# Meta require     teapot::metadata::container
# Meta subject     teapot redirections
# Meta summary     Teapot support functionality. Redirection entities.
# @@ Meta End

# Copyright (c) 2009 ActiveState Software Inc.
#               Tools & Languages

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# ### ### ### ######### ######### #########
## Requirements

package require teapot::instance
package require teapot::metadata::container

logger::initNamespace ::teapot::redirect
namespace eval        ::teapot::redirect {}

# ### ### ### ######### ######### #########
## Implementation

proc ::teapot::redirect::make {instance destination {othermeta {}}} {

    # Make the container and specify the basics.
    set c [teapot::metadata::container %AUTO%]
    teapot::instance::split $instance e n v a
    $c define $n $v redirect

    # Merge any additional data, if any.
    if {[llength $othermeta]} {
	set m [$c get]
	foreach x $othermeta { lappend m $x }
	$c set $m
    }

    # Drop some magic fields, if present, unneeded.
    $c unset entity
    $c unset name
    $c unset version

    # Save the original type info, and remember the destination.
    $c add as::type $e
    $c rearch $a
    $c add as::repository $destination
    return $c
}

proc ::teapot::redirect::2instance {redirect} {
    teapot::instance::split [$redirect instance] e n v a
    set e [$redirect getfirst as::type]
    return [teapot::instance::cons $e $n $v $a]
}


proc ::teapot::redirect::decode {redirectfile} {
    set errors {}
    set p [lindex [::teapot::metadata::read::file $redirectfile single errors] 0]

    if {$p eq {}} {
	return -code error "Bad meta data ($errors), ignored"
    }

    # Determine origin instance, and where to find it.
    set origin [2instance $p]
    set orepos [$p getfor as::repository]
    $p destroy

    return [list $origin $orepos]
}

# ### ### ### ######### ######### #########
## Internals

# ### ### ### ######### ######### #########
## Ready
return
