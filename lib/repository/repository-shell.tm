# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::shell 0.1
# Meta platform    tcl
# Meta recommend   this/is/a/bogus/package/name
# Meta require     logger
# Meta require     pkg::mem
# Meta require     platform::shell
# Meta require     repository::api
# Meta require     snit
# Meta require     teapot::reference
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type encapsulating the packages seen by a tcl shell as a
# repository. This is _not_ a full repository. The only API methods
# supported are 'require', 'recommend', and 'find'. THe first two
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

package require logger           ; # Tracing
package require pkg::mem          ; # In-memory instance database
package require platform::shell   ; # Shell system identification
package require repository::api   ; # Repo interface core.
package require snit              ; # OO core
package require teapot::reference ; # Reference handling

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::shell
snit::type            ::repository::shell {

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
    # (We use the path of the shell it is constructed for)

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

    #method BadRequest {name args} { ::repository::api::complete $opt 1 "Bad request $name"; return }
    #method NoDeps     {args}      { ::repository::api::complete $opt 0 {}; return }

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
    method Meta         {opt args} {$self BadRequest $opt meta}
    method Dump         {opt args} {$self BadRequest $opt dump}
    method Keys         {opt args} {$self BadRequest $opt keys}
    method List         {opt args} {$self BadRequest $opt list}
    method Value        {opt args} {$self BadRequest $opt value}
    method Search       {opt args} {$self BadRequest $opt search}

    method Require   {opt args} {$self NoDeps $opt}
    method Recommend {opt args} {$self NoDeps $opt}

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
	    # Extend found instance with profile info - no profile.
	    set result [list [linsert [lindex $result 0] end 0]]
	}

	::repository::api::complete $opt 0 $result
	return
    }

    # ### ### ### ######### ######### #########
    ## API - Connect object to a shell. This loads the
    ##       in-memory database of packages.

    constructor {theshell args} {
	$self configurelist $args

	set arch  [::platform::shell::identify $theshell] 
	set shell $theshell

	set API [repository::api ${selfns}::API -impl $self]
	set db  [pkg::mem        ${selfns}::db]

	Fill $db $arch $theshell
	return
    }

    proc Fill {db arch shell} {
	foreach {name version} [exec $shell << {
	    ## Code Executed By External Shell (s.a.)
	    ## Lists all packages known to the shell
	    ## per the regular install.

	    set     packages {}
	    lappend packages Tcl [info patchlevel]
	    catch {package require this/is/a/bogus/package/name}
	    foreach p [package names] {
		if {$p == "Tcl"} continue
		foreach v [package versions $p] {
		    lappend packages $p $v
		}
	    }
	    puts $packages
	    exit 0
	}] {
	    $db enter [list $name $version $arch]
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable db
    variable shell

    oncget -location {
	return "shell ($shell)"
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
