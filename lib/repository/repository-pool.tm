# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::pool 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     pkg::mem
# Meta require     repository::api
# Meta require     snit
# Meta require     teapot::metadata
# Meta require     teapot::metadata::read
# Meta require     teapot::reference
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type encapsulating the packages stored in a pool file as a
# repository. This is _not_ a full repository. The only API methods
# supported are 'require', 'recommend', and 'find'. The first two
# always return empty lists, only the last is operational. This is a
# pseudo-repository for use in package resolution.

# _________________________________________

# By basing this type on the 'repository::api' frontend package the
# code here does not have to perform argument checking. It can assume
# that the incoming arguments are ok.

# This also makes the processing of some errors faster as there is no
# dispatch through the event queue at all, but an immediate response.

# ### ### ### ######### ######### #########
## Requirements

package require logger                ; # Tracing
package require pkg::mem               ; # In-memory instance database
package require repository::api        ; # Repo interface core
package require snit                   ; # OO core
package require teapot::metadata       ; # MD accessors
package require teapot::metadata::read ; # MD extraction
package require teapot::reference      ; # Reference handling

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::pool
snit::type            ::repository::pool {

    # ### ### ### ######### ######### #########
    ## API - Delegated to the generic frontend.
    #
    ##       However, the methods for setting
    ##       and querying the platform code do
    ##       not go through the frontend.

    delegate method * to API
    variable             API

    # ### ### ### ######### ######### #########
    ## API - Implementation.

    option -location {} ; # Location of the repository in the filesystem.

    # This repository only has a pseudo-location.
    # (We use the path of the pool it is constructed for)

    ## These are the methods that are called from the generic frontend
    ## during dispatch.

    #delegate method Link         to self as {BadRequest link}
    #delegate method Put          to self as {BadRequest put}
    #delegate method Del          to self as {BadRequest del}
    #delegate method Get          to self as {BadRequest get}
    #delegate method Path         to self as {BadRequest path}
    #delegate method Chan         to self as {BadRequest chan}
    #delegate method Requirers    to self as {BadRequest requirers}
    #delegate method Recommenders to self as {BadRequest recommenders}
    #delegate method FindAll      to self as {BadRequest findall}
    #delegate method Entities     to self as {BadRequest entities}
    #delegate method Versions     to self as {BadRequest versions}
    #delegate method Instances    to self as {BadRequest instances}
    #delegate method Meta         to self as {BadRequest meta}
    #delegate method Dump         to self as {BadRequest dump}
    #delegate method Keys         to self as {BadRequest keys}
    #delegate method List         to self as {BadRequest list}
    #delegate method Value        to self as {BadRequest value}
    #delegate method Search       to self as {BadRequest search}

    # Dependency tracking is not possible for packages in the regular
    # install.

    #delegate method Require   to self as NoDeps
    #delegate method Recommend to self as NoDeps

    #method BadRequest {name args} { ::repository::api::complete $opt 1 "Bad request $name" ; return }
    #method NoDeps     {args}      { ::repository::api::complete $opt 0 {} ; return }

    method Link         {opt args} {$self BadRequest $opt link}
    method Put          {opt args} {$self BadRequest $opt put}
    method Del          {opt args} {$self BadRequest $opt del}
    method Get          {opt args} {$self BadRequest $opt get}
    method Path         {opt args} {$self BadRequest $opt path}
    method Chan         {opt args} {$self BadRequest $opt chan}
    method Requirers    {opt args} {$self BadRequest $opt requirers}
    method Recommenders {opt args} {$self BadRequest $opt recommenders}
    method FindAll      {opt args} {$self BadRequest $opt findall}
    method Entities     {opt args} {$self BadRequest $opt entities}
    method Versions     {opt args} {$self BadRequest $opt versions}
    method Instances    {opt args} {$self BadRequest $opt instances}
    method Dump         {opt args} {$self BadRequest $opt dump}
    method Keys         {opt args} {$self BadRequest $opt keys}
    method Search       {opt args} {$self BadRequest $opt search}


    method List {opt spec} {
	set res {}
	foreach i [$db list $spec] {
	    # Add the profile flag to the listed instances.

	    lappend i [lindex [$db get $i] 0]
	    lappend res $i
	}

	::repository::api::complete $opt 0 $res
	return
    }

    method Meta {opt spec} {
	::repository::api::complete $opt 0 [_meta $db $spec]
    }

    method Value {opt key spec} {
	::repository::api::complete $opt 0 [_value $db $key $spec]
    }

    method Require   {opt instance} {_dep $db $opt require}
    method Recommend {opt instance} {_dep $db $opt recommend}

    proc _dep {db opt key} {
	if {[catch {$db get $instance} md]} {
	    ::repository::api::complete $opt 0 {}
	    return
	}
	array set meta $md
	if {![info exists meta($key)]} {
	    ::repository::api::complete $opt 0 {}
	    return
	}
	::repository::api::complete $opt 0 $meta($key)
	return
    }

    proc _value {db key spec} {
	array set md [_meta $db $spec]
	if {![info exists md($key)]} {return {}}
	return $md($key)
    }

    proc _meta {db spec} {
	set matches [$db list $spec]
	if {![llength $matches]} {return {}}

	array set tmp {}
	foreach m $matches {
	    array set tmp [$db get $m]
	}

	# See also repo_mm.tcl, _meta.
	array set res {}
	foreach {k v} [array get tmp] {
	    if {[info exists tm($k)]} {
		foreach e $v {lappend res($k) $e}
	    } else {
		set res($k) $v
	    }
	}
	return [array get res]
    }

    method BadRequest {opt name} {
	::repository::api::complete $opt 1 "Bad request $name"
	return
    }

    method NoDeps {opt} {
	::repository::api::complete $opt 0 {}
	return
    }

    # Find package ...

    method Find {opt platforms ref} {
	set result [$db findref $platforms $ref]

	if {[llength $result]} {
	    # Extend found instance with profile info
	    array set md [$db get $result]

	    ::teapot::instance::split $result t n v a
	    set isp 0
	    if {($t eq "package") && [info exists md(profile)]} {
		unset -nocomplain md(profile)
		set result [teapot::instance::cons profile $n $v $a]
		set isp 1
	    } elseif {$t eq "profile"} {
		set isp 1
	    }

	    set result [list [linsert [lindex $result 0] end $isp]]
	}

	::repository::api::complete $opt 0 $result
	return
    }

    # ### ### ### ######### ######### #########
    ## API - Connect object to a pool. This loads the
    ##       in-memory database of packages.

    constructor {thepool args} {
	log::debug "$self new ($thepool)"

	$self configurelist $args

	set API    [repository::api ${selfns}::API -impl $self]
	set db     [pkg::mem        ${selfns}::db]

	foreach instance [$thepool instances] {
	    $db enter $instance

	    set f [$thepool get]

	    set errors {}
	    set fail [catch {
		::teapot::metadata::read::file $file single errors
	    } msg]
	    if {$fail || [llength $errors]} {
		$db set $instance  {}

		# Do something with the errors.
		continue
	    }

	    # msg = list(object (teapot::metadata::container))/1
	    # Single mode above ensure that at most one is present.

	    set pkg  [lindex $msg 0]
	    set meta [$pkg get]
	    $pkg destroy

	    $db set $instance $meta
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable db

    oncget -location {
	return "(-pkgfile options)"
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
