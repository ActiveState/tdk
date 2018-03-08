# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::api 0.1
# Meta platform    tcl
# Meta require     cmdline
# Meta require     logger
# Meta require     snit
# Meta require     teapot::instance
# Meta require     teapot::listspec
# Meta require     teapot::query
# Meta require     teapot::reference
# Meta require     teapot::version
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview
# Copyright (c) 2007-2008 ActiveState Software Inc.

# snit::type providing the basic API for repositories. Processes and
# dispatches requests to the actual implementation of a repository.
# Generic processing of the arguments for -command completion callback
# and -progress feedback callback.

# Instances are facades for the actual implementations.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require cmdline
package require logger
package require teapot::reference ; # Reference handling
package require teapot::version   ; # Version handling
package require teapot::instance  ; # Instance handling
package require teapot::query     ; # Query handling
package require teapot::listspec  ; # Listspec handling
package require log

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::api
snit::type            ::repository::api {

    # ### ### ### ######### ######### #########
    ## API. Known methods. Async processing.

    option -impl {}

    method link         {args} {$self Dispatch Link         [$self Cmdline args] [__lnk $args]}
    method put          {args} {$self Dispatch Put          [$self Cmdline args] [__put $args]}
    method get          {args} {$self Dispatch Get          [$self Cmdline args] [__get $args]}
    method del          {args} {$self Dispatch Del          [$self Cmdline args] [__i0  $args]}
    method path         {args} {$self Dispatch Path         [$self Cmdline args] [__i0  $args]}
    method chan         {args} {$self Dispatch Chan         [$self Cmdline args] [__i0  $args]}
    method require      {args} {$self Dispatch Require      [$self Cmdline args] [__i0  $args]}
    method recommend    {args} {$self Dispatch Recommend    [$self Cmdline args] [__i0  $args]}
    method requirers    {args} {$self Dispatch Requirers    [$self Cmdline args] [__i0  $args]}
    method recommenders {args} {$self Dispatch Recommenders [$self Cmdline args] [__i0  $args]}
    method find         {args} {$self Dispatch Find         [$self Cmdline args] [__fin $args]}
    method findall      {args} {$self Dispatch FindAll      [$self Cmdline args] [__fin $args]}
    method entities     {args} {$self Dispatch Entities     [$self Cmdline args] [_n 0  $args]}
    method versions     {args} {$self Dispatch Versions     [$self Cmdline args] [__ver $args]}
    method instances    {args} {$self Dispatch Instances    [$self Cmdline args] [__ins $args]}
    method meta         {args} {$self Dispatch Meta         [$self Cmdline args] [__met $args]}
    method keys         {args} {$self Dispatch Keys         [$self Cmdline args] [__key $args]}
    method list         {args} {$self Dispatch List         [$self Cmdline args] [__key $args]}
    method value        {args} {$self Dispatch Value        [$self Cmdline args] [__val $args]}
    method search       {args} {$self Dispatch Search       [$self Cmdline args] [__sea $args]}
    method dump         {args} {$self Dispatch Dump         [$self Cmdline args] [_n 0  $args]}
    method archs        {args} {$self Dispatch Archs        [$self Cmdline args] [_n 0  $args]}
    method verify       {args} {$self Dispatch Verify       [$self Cmdline args] [_n 1  $args]}

    # ### ### ### ######### ######### #########
    ## API. Generic sync processing of any method.

    method sync {args} {
	return [Sync [linsert $args 0 $self]]
    }

    # ### ### ### ######### ######### #########
    ## Functionality

    # A generic option processor captures the data about the command
    # completion callback. The dispatcher then runs the method, via
    # the event queue, using this information.

    # TODO: Make this a proc instead of a method.
    method Cmdline {argvVar {hasprogress 0}} {
	upvar 1 $argvVar arguments

	set     rqOptions {}
	lappend rqOptions {command.arg {} {Command completion callback}}

	if {$hasprogress} {
	    lappend rqOptions {progress.arg {} {Feedback callback}}
	}

	array set opt [cmdline::getoptions arguments $rqOptions]

	if {
	    ![info exists opt(command)] ||
	    ($opt(command) eq "")
	} {
	    return -code error "Completion callback is missing"
	}

	return [array get opt]
    }

    method Dispatch {method opt arguments} {
	# An initial implementation put the request on the event queue
	# via a timer, but then invoked it synchronously when its time
	# came. That is incorrect. Because the request implementation
	# can be asynchronous. We therefore do only some simple
	# checking here and then run the request itself fully
	# asynchronously. The request implementation is responsible
	# for the proper invokation of the completion callback.
	#
	# We provide a typemethod as convenient helper.

	# Assemble the full request to run ...

	set     req $options(-impl)
	lappend req $method
	lappend req $opt
	foreach a $arguments {lappend req $a}

	# Put request into the event queue for execution ...

	log::debug "Dispatch [list $req]"

	after 0 $req
	return
    }

    # ### ### ### ######### ######### #########
    ## Basic argument validation commands.

    proc __lnk {a} {_fdir  0 [_n 4 $a]}
    proc __put {a} {_file  0 [_n 1 $a]}
    proc __get {a} {_inst  0 [_filec 1 [_n 2 $a]]}
    proc __i0  {a} {_inst  0 [_n 1 $a]}
    proc __fin {a} {_ref   1 [_n 2 $a]}
    proc __ver {a} {_pkg   0 [_n 1 $a]}
    proc __ins {a} {_ver   0 [_n 1 $a]}
    proc __met {a} {_spec  0 [_n 1 $a]}
    proc __key {a} {_spec0 0 [_r 0 1 $a]}
    proc __val {a} {_lc    0 [_spec 1 [_n 2 $a]]}
    proc __sea {a} {_query 0 [_n 1 $a]}

    proc _n {n arguments} {
	if {[llength $arguments] != $n} {
	    return -code error "wrong\#args"
	}
	return $arguments
    }

    proc _r {min max arguments} {
	if {
	    ([llength $arguments] < $min) ||
	    ([llength $arguments] > $max)
	} {
	    return -code error "wrong\#args"
	}
	return $arguments
    }

    proc _file {i arguments} {
	set f [lindex $arguments $i]
	if {
	    ![file exists   $f] ||
	    ![file readable $f] ||
	    ![file isfile   $f]
	} {
	    return -code error "Bad file \"$f\""
	}
	return $arguments
    }

    proc _fdir {i arguments} {
	set f [lindex $arguments $i]
	if {
	    ![file exists   $f] ||
	    ![file readable $f]
	} {
	    return -code error "Bad path \"$f\""
	}
	return $arguments
    }

    proc _filec {i arguments} {
	set f [lindex $arguments $i]
	if {
	    ([file exists $f] &&
	     (![file writable $f] ||
	      ![file isfile   $f])) ||
	    (![file exists $f] &&
	     (![file exists   [file dirname $f]] ||
	      ![file readable [file dirname $f]] ||
	      [file isfile    [file dirname $f]]))
	} {
	    return -code error "Bad file \"$f\""
	}
	return $arguments
    }

    proc _inst {i arguments} {
	set inst [lindex $arguments $i]
	if {![teapot::instance::valid $inst message]} {
	    return -code error "Bad instance \"$inst\""
	}
	return $arguments
    }

    proc _pkg {i arguments} {
	set pkg [lindex $arguments $i]
	if {[llength $pkg] != 1} {
	    return -code error "Bad package \"$pkg\""
	}
	return $arguments
    }

    proc _ver {i arguments} {
	set ver [lindex $arguments $i]
	if {[llength $ver] != 2} {
	    return -code error "Bad version \"$ver\""
	}
	foreach {n v} $ver break
	_version $v
	return $arguments
    }

    proc _spec {i arguments} {
	set spec [lindex $arguments $i]
	if {![teapot::listspec::valid $spec msg]} {
	    return -code error "Bad spec \"$spec\": $msg"
	}
	if {[string match *all [teapot::listspec::type $spec]]} {
	    # Empty spec ... Not allowed
	    return -code error "Bad spec \"$spec\": Would list everything"
	}
	return $arguments
    }

    proc _spec0 {i arguments} {
	if {![llength $arguments]} {
	    # Default listspec: all
	    set arguments {0}
	}
	set spec [lindex $arguments $i]
	if {![teapot::listspec::valid $spec msg]} {
	    return -code error "Bad spec \"$spec\": $msg"
	}
	# 'Empty' spec is allowed.
	return $arguments
    }

    proc _ref {i arguments} {
	set ref [lindex $arguments $i]
	if {![teapot::reference::valid $ref message]} {
	    return -code error "Bad reference \"$ref\": $message"
	}
	# The repository backends can expect normalized references.
	return [lreplace $arguments $i $i [teapot::reference::normalize1 $ref]]
    }

    proc _query {i arguments} {
	set q [lindex $arguments $i]
	if {![teapot::query::valid $q message]} {
	    return -code error "Bad query \"$q\": $message"
	}
	return $arguments
    }

    proc _lc {i arguments} {
	return [lreplace $arguments $i $i \
		    [string tolower [lindex $arguments $i]]]
    }

    proc _version {v} {
	if {![teapot::version::valid $v]} {
	    return -code error "Bad version \"$v\""
	}
    }

    # ### ### ### ######### ######### #########
    ##

    proc complete {optdict code result} {
	log::debug "COMPLETE [list $code $result]"

	array set opt $optdict
	if {[catch {
	    uplevel \#0 [linsert $opt(command) end $code $result]
	}]} {
	    global errorInfo
	    foreach l [split $errorInfo \n] {
		log::debug "INT.ERROR $l"
	    }
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Eventloop and result handling for the sync processing of
    ## methods.

    proc Sync {arguments} {
	# arguments = list (repo cmd arg ...)

	set cmd [linsert $arguments 2 -command ::repository::api::DONE]
	log::debug Sync\ ($cmd)

	set   ::repository::api::DONE {}
	eval $cmd
	vwait ::repository::api::DONE

	foreach {code result} $::repository::api::DONE break

	log::debug "Sync Done ($arguments)"
	log::debug "Sync Result = $code ($result)"

	return -code $code $result
    }
    ::variable DONE

    proc DONE {args} {
	log::debug "\tDONE ($args)"
	::variable DONE $args ; # list (code result)
	return
    }

    # ### ### ### ######### ######### #########
    ## Database and API for automatic repository type
    ## detection. Typelevel API, for all instances, and outside of
    ## them.

    typevariable detect -array {}

    typemethod registerForAuto {repositorytype} {
	log::log debug "$type registerForAuto ($repositorytype) = \"[$repositorytype label]\""
	set detect($repositorytype) .
	return
    }

    typemethod typeof {location} {
	log::log debug "$type typeof ($location)"

	# file uri's are auto-stripped of their schema
	# to make them palatable.

	if {[regexp {^file://} $location]} {
	    regsub {^file://} $location {} location
	}

	log::log debug "= ($location)"

	set types [lsort -dict [array names detect]]
	set messages {}

	log::log debug "repository types: [llength $types]"

	foreach rtype $types {
	    log::log debug ". checking ($rtype = \"[$rtype label]\")"
	    if {[$rtype valid $location ro message]} {
		log::log debug "typeof($location) = $rtype";
		log::debug     "typeof($location) = $rtype";
		# " (of [lsort -dict [array names detect]])"
		return $rtype
	    }
	    log::log debug ". failed   = $message"
	    lappend messages "[$rtype label]? No: $message"
	}
	log::log debug "typeof($location) = Undefined"
	log::debug     "typeof($location) = Undefined"
	return -code error "No known repository at $location\n[join $messages \n]"
    }

    typemethod open {obj location args} {
	if {[regexp {^file://} $location]} {
	    regsub {^file://} $location {} location
	}

	return [eval [linsert [linsert \
	   $args end -location $location] 0 \
	   [$type typeof $location] $obj]]
    }

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	$self configurelist $args
	if {$options(-impl) eq ""} {
	    return -code error "API implementation not specified"
	}
	return
    }
}

# ### ### ### ######### ######### #########
## Ready
return
