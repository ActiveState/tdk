# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::tap 0.1
# Meta platform    tcl
# Meta require     jobs
# Meta require     logger
# Meta require     repository::api
# Meta require     snit
# Meta require     tap::cache
# Meta require     tap::db
# Meta require     teapot::package::gen::tm
# Meta require     teapot::package::gen::zip
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview
# Copyright (c) 2007-2008 ActiveState Software Inc.

# snit::type encapsulating the packages seen by an older TclApp
# (specified via .tap files) as a repository.

# This is _not_ a full repository. The only API methods supported are
# 'require', 'recommend', 'find', and 'get'. The first two always
# return empty lists (*), only the last two are operational. This is a
# pseudo-repository for use in package resolution.
#
# (*) .tap files do not have dependency information.

# 'get' is operational because TclApp will retrieve packages from this
# repository to put them into a wrapped kit. This repository will
# always return zip archives. In further contrast to the other
# pseudo-repository, 'repository::shell', this also writes to the
# filesystem. This is because it makes an effort to cache the zip
# archives it generated on the fly for future access.

# _________________________________________

# In the existing system .tap files may contain hidden packages,
# present only to hold the list of files for the package. This was a
# mechanism to cop with multiple packages sharing one directory. To
# avoid this package having to go into MD extraction heuristics here
# the hidden packages are now exposed! A package with a hidden package
# is just a profile, and the hidden package is used as the actual
# package. In this way we keep the sharing of directories an existing
# TclApp does as well. We do have to take care of generating unique
# names for the hidden packages however, as they are now visible.

# _________________________________________

# By basing this type on the 'repository::api' frontend package the
# code here does not have to perform argument checking. It can assume
# that the incoming arguments are ok.

# This also makes the processing of some errors faster as there is no
# dispatch through the event queue at all, but an immediate response.

# ### ### ### ######### ######### #########
## Requirements

package require log
package require snit                        ; # OO core
package require repository::api             ; # Generic repository processing
package require logger                      ; # Logging
package require teapot::package::gen::tm    ; # Direct generation of zip archives
package require teapot::package::gen::zip   ; # Direct generation of tcl modules
package require jobs                        ; # Manage defered jobs
package require logger                      ; # Tracing
package require tap::db                     ; # Actual database holding TAP information
package require tap::cache                  ; # Cache for package archive files.
package require teapot::instance            ; # Instance handling
package require teapot::metadata::container ; # MD container


# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::tap
snit::type            ::repository::tap {

    method valid {mode mv} {
	upvar 1 $mv message
	return [$type valid $options(-location) $mode message]
    }

    typemethod label {} { return "TAP Bridge" }

    typemethod valid {location mode mv} {
	upvar 1 $mv message
	return [tap::db valid $location $mode message]
    }

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

    # Location of the repository (TDK install path) in the filesystem.
    # Request asynchronous initialization.

    option -location -default {} -readonly 1 -cgetmethod cget-location

    # This repository only has a pseudo-location.
    # (We use the base path of the TDK installation)

    # ### ### ### ######### ######### #########
    ## These are the methods that are called from the generic frontend
    ## during dispatch.

    # ### ### ### ######### ######### #########

    method Link         {opt args} {$self BadRequest $opt link}
    method Put          {opt args} {$self BadRequest $opt put}
    method Del          {opt args} {$self BadRequest $opt del}
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

    method Recommend {opt args} {$self NoDeps $opt}

    # ### ### ### ######### ######### #########

    method Require {opt instance} {
	JobControl 0

	log::debug "$self Require ($instance)"
	::log::log debug "$self Require ($instance)"

	set res [$db get $instance]

	set req [lindex $res 1]
	if {$req ne ""} {
	    ::repository::api::complete $opt 0 [list $req]
	}

	::repository::api::complete $opt 0 {}
    }

    method Value {opt key spec} {
	# A very small set of meta data is available in this
	# repository: Description, Platform, Require, Profile

	# Queries for bad keys are answered immediately. Only for
	# valid keys we may have to defer execution until after the
	# repository is (re-)initialized.

	set key [string tolower $key]
	if {[lsearch -exact {description platform require profile} $key] < 0} {
	    # Outside of supported keys. Return nothing

	    log::debug "$self Value ($key $spec)"
	    ::log::log debug "$self Value ($key $spec)"
	    set res {}
	} else {
	    JobControl 1
	    log::debug "$self Value ($key $spec)"
	    ::log::log debug "$self Value ($key $spec)"

	    array set md [$self getmeta $spec]
	    if {[info exists md($key)]} {
		set res $md($key)
	    } else {
		set res {}
	    }
	}

	::repository::api::complete $opt 0 $res
    }

    method Meta {opt spec} {
	JobControl 1
	log::debug "$self Meta ($spec)"
	::log::log debug "$self Meta ($spec)"

	# A very small set of meta data is available in this
	# repository: Description, Platform, Require, Profile

	::repository::api::complete $opt 0 [$self getmeta $spec]
	return
    }

    method List {opt {spec {}}} {
	log::debug "$self RQ List ($spec)"
	::log::log debug "$self RQ List ($spec)"
	JobControl 1
	log::debug "$self List ($spec)"
	::log::log debug "$self List ($spec)"

	set res {}
	foreach i [$db list $spec] {
	    # Add the profile flag to the listed instances.

	    lappend i [lindex [$db get $i] 0]
	    lappend res $i
	}

	::repository::api::complete $opt 0 $res
	return
    }

    # Find package ...

    method Find {opt platforms template} {
	JobControl 1
	log::debug "$self Find (($platforms) $template)"
	::log::log debug "$self Find (($platforms) $template)"

	set result [$db findref $platforms $template]
	if {[llength $result]} {
	    # Extend the found instance with profile information.

	    set     instance [lindex $result 0]
	    lappend instance [lindex [$db get $instance] 0]
	    set result [list $instance]
	}

	::repository::api::complete $opt 0 $result
	return
    }

    # Get package ...

    method Get {opt instance destination} {
	JobControl 1
	log::debug "$self Get ($instance) : $destination"
	::log::log debug "$self Get ($instance) : $destination"

	set hasnew 1
	if {[catch {$db get $instance} res]} {
	    ::repository::api::complete $opt 1 $res
	    return
	}

	if {[$cache has $instance]} {
	    $cache get $instance $destination
	    ::repository::api::complete $opt 0 {}
	    return
	}

	log::debug "$self Create $destination"
	::log::log debug "$self Create $destination"

	# We have to generate a package file.
	# res is (isprofile require desc filemap basedir)

	foreach {isprofile require desc filemap basedir} $res break
	teapot::instance::split $instance _ pname pver parch

	set md [teapot::metadata::container %AUTO%]
	$md define $pname $pver
	$md add platform $parch
	if {$desc ne ""} {$md add description $desc}

	if {$isprofile} {
	    # Generate profile. Use a Tcl Module to keep things small.

	    $md retype profile
	    $md unset profile
	    $md add require $require

	    ::teapot::package::gen::tm::generate $md {} $destination
	} else {
	    # Zip archive for the file-based package
	    # Keep the existing package index.

	    foreach {src dst} $filemap {
		$md add __files $dst 0 $src
	    }
	    $md add __ecmd keep

	    ::teapot::package::gen::zip::generate $md {} $destination
	}

	log::debug "$self Save"
	::log::log debug "$self Save"

	$cache put $instance $destination
	::repository::api::complete $opt 0 {}
	return
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

    method getmeta {spec} {
	# First retrieve all instances matching the spec
	set instances [$db list $spec]

	array set res {}
	foreach instance $instances {
	    foreach {isp req desc _ _} [$db get $instance] break

	    if {0} {
		if {$isp} {set res(profile) .}
	    }

	    teapot::instance::split $instance _ _ _ arch

	    lappend res(platform)    $arch
	    lappend res(description) $desc

	    set res(platform)    [lsort -uniq $res(platform)]
	    set res(description) [lsort -uniq $res(description)]

	    if {$req ne ""} {
		lappend res(require) $req
		set     res(require) [lsort -uniq $res(require)]
	    }
	}

	if {[array size res]} {
	    set res(platform)    [lindex $res(platform) 0]
	    set res(description) [join $res(description) " "]
	}

	return [array get res]
    }

    # ### ### ### ######### ######### #########
    ## API. Construction. Connect to a TDK
    ##      installation (directory).

    option -readonly 0
    # Ignored. API compatibility. Tap repositories are local and always read/write.

    constructor {args} {
	log::debug "$self new ($args)"
	::log::log debug "$self new ($args)"

	$self configurelist $args
	set installdir $options(-location)

	set API   [repository::api ${selfns}::API -impl $self]
	set db    [tap::db         ${selfns}::db    $installdir]
	set cache [tap::cache      ${selfns}::cache $installdir]

	# Set up structures to handle requests coming in while an
	# async scan is running.

	set jobs      [jobs ${selfns}::jobs]
	set asyncdone [mymethod Done]

	$self scan

	log::debug "$self new OK"
	::log::log debug "$self new OK"
	return
    }

    method scan {} {
	log::debug "$self scan"
	::log::log debug "$self scan"

	DeferOn
	$db initialize [mymethod Done]
	return
    }

    method Done {args} {
	# Ok, the initialization is complete. We can now complete all
	# requests which came in during that time and were defered.

	# For defered tasks we prevent them from running the
	# initialization again, given that it is just done. Only
	# requests in a new burst restart the rescan again.
	#
	# See [x] as well, the flow control documentation.

	log::debug "Init/Done"
	::log::log debug "$self Init/Done"

	DeferOff
	set initoff 1
	$jobs do
	set initoff 0
	return
    }

    proc DeferOn  {} {
	::log::log debug JobControl/DeferOn
	upvar 1 defer defer ; set defer 1 ; return
    }
    proc DeferOff {} {
	::log::log debug JobControl/DeferOff
	upvar 1 defer defer ; set defer 0 ; return
    }
    proc DeferRq  {} {
	::log::log debug JobControl/DeferRequested
	upvar jobs jobs; uplevel 2 [list $jobs defer-us]
    }

    proc JobControl {doinit} {
	# See [x] for documentation

	upvar 1 \
	    defer           defer \
	    initoff         initoff \
	    db              db \
	    jobs            jobs \
	    asyncdone       asyncdone

	if {$defer} {
	    log::debug Defer
	    ::log::log debug JobControl/Defer
	    DeferRq
	    return -code return
	}

	# Disabled the automatic rescan after bursts. Have no bursts,
	# extreme slowdown of app startup, and wrap operation.
	if {0 && $doinit && !$initoff} {
	    log::debug DeferStart
	    ::log::log debug DeferStart
	    DeferOn
	    $db initialize $asyncdone
	    DeferRq
	    return -code return
	}

	log::debug Pass
	::log::log debug JobControl/Pass
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable db    ; # object (tap::db)    - Instance database
    variable cache ; # object (tap::cache) - File cache

    variable installdir

    method cget-location {args} {
	return "tap ($installdir)"
    }

    variable initoff 0 ; # Set iff db init is to be skipped.
    variable defer   0 ; # Set iff job deferal is active.
    variable jobs      ; # object (jobs) - Defered jobs when doing async init.
    variable asyncdone ;

    # [x] Flow control documentation

    # States
    # id d i
    # -- ---
    # A  1 0 - Initial state. Package scan running.
    #          JobControl defers all calls. When
    #          the scan is done, goto B.
    #
    # B  0 1 - Scan is done, system is now executing
    #          all the defered calls. JobControl
    #          prevents new scans. Goto C when done.
    #
    # C  0 0 - Basic quiescent state.  JobControl
    #          defers all calls, starts a scan and
    #          goes to state A.

    # In words.

    # After construction a scan for packages is running. All requests
    # coming in during that time are defered. When the scan is done
    # all defered requests are executed again. No scans are started
    # during that time (-> initoff).

    # When the system is quiescent a new request causes it to start a
    # package scan, in case something has changed on the filesystem.
    # The request causing this, and all others received during the
    # scan are defered.  When the scan is done all defered requests
    # are executed again. No scans are started during that time (->
    # initoff).

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Register us at the central type auto-detection.

::repository::api registerForAuto ::repository::tap

# ### ### ### ######### ######### #########
## Ready
return
