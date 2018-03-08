# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::union 0.1
# Meta platform    tcl
# Meta require     event::merger
# Meta require     logger
# Meta require     repository::api
# Meta require     snit
# Meta require     struct::set
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type implemention for union repositories. Requests are given
# to all sub repositories either in parallel or sequence, depending on
# the type of the request. Results are accumulated and merged before
# returned to the caller.

# ### ### ### ######### ######### #########
## Requirements

package require snit            ; # OO core
package require repository::api ; # Repository core
package require logger          ; # Tracing
package require struct::set     ; # Set operations
package require event::merger   ; # Waiting for multiple callbacks
package require teapot::instance

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::union
snit::type            ::repository::union {

    option -location {}

    # ### ### ### ######### ######### #########
    ## API - Delegated to the generic frontend

    delegate method * to API
    variable             API

    # ### ### ### ######### ######### #########
    ## Special APIs for direct access to the contained sub-ordinate
    ## repositories.

    variable _archives {}

    method archives {} {
	return $_archives
    }

    method archive/add {r} {
	log::debug "$self archive/add $r @[$r cget -location]"

	lappend _archives $r
	return
    }

    # ### ### ### ######### ######### #########
    ## API - Implementation.

    ## These are the methods that are called from the frontend during
    ## dispatch.

    # Some methods are not supported for now, because TclApp does not need them.

    method Put          {opt file}               {repository::api::complete $opt 1 "Bad request"}
    method Del          {opt instance}           {repository::api::complete $opt 1 "Bad request"}
    method Path         {opt instance}           {repository::api::complete $opt 1 "Bad request"}
    method Dump         {opt}                    {repository::api::complete $opt 1 "Bad request"}
    method Requirers    {opt instance}           {repository::api::complete $opt 1 "Bad request"}
    method Recommenders {opt instance}           {repository::api::complete $opt 1 "Bad request"}
    method FindAll      {opt platforms template} {repository::api::complete $opt 1 "Bad request"}
    method Entities     {opt}                    {repository::api::complete $opt 1 "Bad request"}
    method Versions     {opt package}            {repository::api::complete $opt 1 "Bad request"}
    method Instances    {opt version}            {repository::api::complete $opt 1 "Bad request"}
    method Keys         {opt {spec {}}}          {repository::api::complete $opt 1 "Bad request"}
    method Search       {opt query}              {repository::api::complete $opt 1 "Bad request"}

    # Now the methods which have to be implemented for TclApp's expansion processes to work.

    method Value {opt key spec} {
	$self _serialm $_archives [mymethod _DoneValue $opt] value [list $key $spec]
	return
    }

    method _DoneValue {opt repo result} {
	repository::api::complete $opt 0 $result
	return
    }

    method Get {opt instance file} {
	# Sequential querying of all subordinates until one is able to
	# deliver. If origin information is present only the
	# repositories which can deliver are queried.

	log::debug "$self Get $instance"
	log::debug "\t=> $file"
	log::debug "\tOpt ($opt)"

	$self _serial $_archives {} [mymethod _DoneGet $opt $file] get [list $instance $file]
	return
    }

    method _DoneGet {opt file origin code result} {
	set origins($file) $origin
	repository::api::complete $opt $code $result
    }

    variable origins -array {}
    method originof {file} {
	set o $origins($file)
	unset origins($file)
	return $o
    }

    method Require {opt instance} {
	log::info "Require ($instance)"
	$API meta -command [mymethod _DoneDep $opt require] [teapot::instance::2spec $instance]
	return
    }

    method Recommend {opt instance} {
	log::info "Recommend ($instance)"
	$API meta -command [mymethod _DoneDep $opt recommend] [teapot::instance::2spec $instance]
	return
    }

    method _DoneDep {opt key code meta} {
	log::info "DoneDep $key $code ($meta)"

	if {$code} {
	    repository::api::complete $opt 0 {}
	    return
	}

	set res {}
	if {[llength $meta]} {
	    array set md $meta
	    if {[info exists md($key)]} {
		set res $md($key)
	    }
	}
	repository::api::complete $opt 0 $res
	return
    }

    proc Union {results} {
	set res {}
	foreach item $results {
	    foreach {__ code result} $item break
	    if {$code} continue
	    set res [struct::set union $res $result]
	}
	return $res
    }

    method Find {opt platforms template} {
	$self _parallel [mymethod _DoneFind $opt] find $platforms $template
	return
    }

    method _DoneFind {opt results} {
	# The total result is the best of all partial results. Best =
	# Maximal version number. In case of identical version numbers
	# the first of all elements having this version is taken.
	# After we have stripped failures and the result codes.

	# results = list (<code list(instance?)> ...)

	set best {}
	set bestv {}
	foreach item $results {
	    foreach {__ code result} $item break
	    if {$code} continue

	    # Ignore results where the template was not found.
	    if {![llength $result]} continue
	    set result [lindex $result 0]

	    teapot::instance::split $result e n v a
	    if {
		($best eq "") || ([package vcompare $v $bestv] > 0)
	    } {
		set best  $result
		set bestv $v
	    }
	}

	if {$best ne ""} {set best [list $best]}
	repository::api::complete $opt 0 $best
	return
    }



    method List {opt {spec {}}} {
	$self _parallel [mymethod _DoneList $opt] list $spec
	return
    }

    method _DoneList {opt results} {
	# The total result is the union of all partial results.
	# After we have stripped failures and the result codes.

	repository::api::complete $opt 0 [Union $results]
	return
    }



    method Meta {opt spec} {
	#$self _parallel [mymethod _DoneMeta $opt] meta $spec

	# Using serial instead of parallel broadcast because merging
	# the metadata from different repositories can yield a bogus
	# result. For example if repository A has the package as tm or
	# zip, and repository B has it as profile. The merged data
	# will wrongly claim that the package is a profile.

	log::debug "Meta ($spec)"

	$self _serialm $_archives [mymethod _DoneMetaS $opt] meta [list $spec]
	return
    }

    method _DoneMetaS {opt repo result} {
       	log::debug "Meta ([expr {($repo eq "") ? "<exhausted>" : [$repo cget -location]}]): \{$result\}"

	repository::api::complete $opt 0 $result
    }

    method _DoneMeta {opt results} {
	# The near-total result is the union of all partial results,
	# followed by merging the contents of specific keys together.
	# After we have stripped failures and the result codes.

	DictUnion md $results

	array set res {}
	foreach {k v} $md {
	    if {[info exists res($k)]} {
		foreach e $v {lappend res($k) $e}
	    } else {
		set res($k) $v
	    }
	}

	repository::api::complete $opt 0 [array get res]
	return
    }

    proc DictUnion {mv results} {
	upvar $mv md
	set md {}
	foreach item $results {
	    foreach {__ code result} $item break
	    if {$code} continue
	    foreach x $result {lappend md $x}
	}
	return
    }


    # ### ### ### ######### ######### #########
    ## Helpers. Parallel and serial execution of commands
    ## by the subordinate repositories.

    # chain = {expand}cmdprefix semi-dict(code result)

    method _parallel {chain cmd args} {
	set M [event::merger ${selfns}::M%AUTO% \
		   $chain [llength $_archives]]

	foreach r $_archives {
	    log::debug "\tHaving $r = [$r cget -location]"
	}

	if {![llength $_archives]} {
	    # No archives defined! Nothing to do.
	    # Force the merger to run the chain, and return
	    $M trigger
	    return
	}
	foreach r $_archives {
	    eval [linsert $args 0 $r $cmd -command [list $M done $r]]
	    #8.5: $r $cmd -command [list $M done $r] {expand}$args
	}
	return
    }

    # chain = {expand}cmdprefix code result

    method _serial {archives errors chain cmd argl} {
	log::debug "_serial $cmd ($argl), \[$chain]"
	foreach r $archives {
	    log::debug "\tHaving $r = [$r cget -location]"
	}

	# Exhausted supply of archives, total failure.
	if {![llength $archives]} {
	    log::debug "\texhausted, fail"
	    eval [linsert $chain end {} 1 $errors]
	    return
	}

	set r    [lindex $archives 0]
	set tail [lrange $archives 1 end]

	log::debug "\tR = $r ($cmd)"

	eval [linsert $argl 0 $r $cmd -command \
		  [mymethod _serialres $r $tail $errors $chain $cmd $argl]]
	#8.5: $r $cmd -command ... {expand}$argl
	return
    }

    method _serialres {repo archives errors chain cmd argl code result} {
	log::debug "_serialres $repo @[$repo cget -location]: $code ($result)"

	# Record failures and continue with the next archive.
	if {$code} {
	    #puts "[$repo cget -location] : $code '$result'"
	    lappend errors $result
	    $self _serial $archives $errors $chain $cmd $argl
	    return
	}

	# Success. Stop the execution.
	eval [linsert $chain end $repo 0 $result]
    }



    method _serialm {archives chain cmd argl} {
	log::debug "_serial $cmd ($argl), \[$chain]"

	# Exhausted supply of archives, total failure.
	if {![llength $archives]} {
	    eval [linsert $chain end {} {}]
	    return
	}

	set r    [lindex $archives 0]
	set tail [lrange $archives 1 end]

	eval [linsert $argl 0 $r $cmd -command \
		  [mymethod _serialresm $r $tail $chain $cmd $argl]]
	#8.5: $r $cmd -command ... {expand}$argl
	return
    }

    method _serialresm {repo archives chain cmd argl code result} {
	log::debug "_serialres $repo @[$repo cget -location]: $code ($result)"

	# Record failures and continue with the next archive.
	if {$code || ![llength $result]} {
	    #if {$code} {puts "[$repo cget -location] : $code '$result'"}
	    $self _serialm $archives $chain $cmd $argl
	    return
	}

	eval [linsert $chain end $repo $result]
    }

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	$self configurelist $args

	# -location is the list of archives to query.
	# This can be modified later.

	# The api object dispatches requests directly to us.
	set API [repository::api ${selfns}::API -impl $self]
	return
    }

    onconfigure -location {newvalue} {
	if {$newvalue eq $options(-location)} return
	set options(-location) $newvalue
	set _archives          $newvalue
	return
    }
}

# ### ### ### ######### ######### #########
## A union is a type of virtual repository. It has no presence in the
## file system, it is "just" an organizational thing to structure the
## internals of an application in a nice manner. In the end this simply
## means that it makes no sense to register this repository type with
## the auto-detection.

# ### ### ### ######### ######### #########
## Ready
return
