# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::mem 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     pkg::mem
# Meta require     repository::api
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type for a wholly in-memory repository. To have something
# where we can keep pseudo-packages, like Tcl itself. This is _not_ a
# full repository. The only API methods supported are 'require',
# 'recommend', and 'find'. The first two always return empty lists,
# only the last is operational. This is a pseudo-repository for use in
# package resolution.

# _________________________________________

# By basing this type on the 'repository::api' frontend package the
# code here does not have to perform argument checking. It can assume
# that the incoming arguments are ok.

# This also makes the processing of some errors faster as there is no
# dispatch through the event queue at all, but an immediate response.

# ### ### ### ######### ######### #########
## Requirements

package require logger               ; # Tracing
package require pkg::mem             ; # In-memory instance database
package require repository::api      ; # Repo interface core
package require snit                 ; # OO core
package require teapot::instance     ; # Instance handling

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::mem
snit::type            ::repository::mem {

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

    option -location {} ; # Location of the repository, fake.

    # This repository only has a pseudo-location.
    # (We use the fixed string 'virtual').

    # ### ### ### ######### ######### #########
    ## These are the methods that are called from the generic frontend
    ## during dispatch.

    # ### ### ### ######### ######### #########

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

    # ### ### ### ######### ######### #########

    method Require   {opt instance} {_dep $db $opt require}
    method Recommend {opt instance} {_dep $db $opt recommend}

    # ### ### ### ######### ######### #########

    method Meta {opt spec} {
	::repository::api::complete $opt 0 [_meta $db $spec]
    }

    method List {opt {spec {}}} {
	log::debug "$self List ($spec)"

	set res {}
	foreach i [$db list $spec] {
	    # Add the profile flag to the listed instances.

	    lappend i [lindex [$db get $i] 0]
	    lappend res $i
	}

	::repository::api::complete $opt 0 $res
	return
    }

    method Value {opt key spec} {
	::repository::api::complete $opt 0 [_value $db $key $spec]
    }

    # ### ### ### ######### ######### #########

    method BadRequest {opt name} {
	::repository::api::complete $opt 1 "Bad request $name"
	return
    }

    method NoDeps {opt} {
	::repository::api::complete $opt 0 {}
	return
    }

    # ### ### ### ######### ######### #########
    # Find package ...

    method Find {opt platforms template} {
	log::debug "$self Find (($platforms) $template)"

	set result [$db findref $platforms $template]
	if {[llength $result]} {
	    # Extend found instance with profile info. To get the
	    # relevant meta-data we have to make it a list-spec as
	    # well for a moment.

	    array set md [_meta $db [::teapot::instance::2spec $result]]

	    ::teapot::instance::split $result t n v a
	    set isprofile 0
	    if {($t eq "package") && [info exists md(profile)]} {
		unset -nocomplain md(profile)
		set result [teapot::instance::cons profile $n $v $a]
		set isprofile 1
	    } elseif {$t eq "profile"} {
		set isprofile 1
	    }

	    set result [list [linsert [lindex $result 0] end $isprofile]]
	}
	::repository::api::complete $opt 0 $result
	return
    }

    # ### ### ### ######### ######### #########

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

    # ### ### ### ######### ######### #########

    delegate method enter to db
    delegate method set   to db ; # Set 'meta'

    # ### ### ### ######### ######### #########
    ## API - Connect object to a pool. This loads the
    ##       in-memory database of packages.

    constructor {args} {
	log::debug "$self new"
	$self configurelist $args

	set API [repository::api ${selfns}::API -impl $self]
	set db  [pkg::mem        ${selfns}::db]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable db

    oncget -location {return {virtual}}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
