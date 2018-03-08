# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package pkg::mem 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     platform
# Meta require     snit
# Meta require     teapot::instance
# Meta require     teapot::reference
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# In memory database of package instances. Each instance can have a
# single arbitrary value associated with it. Objects return this
# information, but do not impose any type of semantics on the value.

# Main purpose is to centralize methods for finding instances. Based
# on name, version, architecture, exact-ness, various
# (non-)restrictions.

# ### ### ### ######### ######### #########
## Requirements

package require logger            ; # Tracing
package require snit              ; # OO core
package require platform          ; # System identification.
package require teapot::instance  ; # Instance handling
package require teapot::reference ; # Reference handling

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::pkg::mem
snit::type ::pkg::mem {

    # ### ### ### ######### ######### #########
    ## API - Setting & retrieving the associated value

    method set {instance value} {
	if {![$self exists $instance]} {
	    return -code error "Instance \"$instance\" does not exist"
	}
	set instances($instance) $value
	return
    }

    method get {instance} {
	if {![$self exists $instance]} {
	    return -code error "Instance \"$instance\" does not exist"
	}
	return $instances($instance)
    }

    # ### ### ### ######### ######### #########
    ## API - Finding instances.

    method list {{spec {0}}} {
	log::debug "list ($spec)"

	set spectype [teapot::listspec::split $spec e name version arch]

	while 1 {
	    switch -exact -- $spectype {
		all {
		    return $linstances
		}
		name {
		    # name - all versions, all platforms

		    set res {}
		    foreach vkey [array names versions [list * $name *]] {
			set platform [lindex $vkey 1]
			foreach v $versions($vkey) {
			    lappend res [teapot::instance::cons package $name $v $platform]
			}
		    }
		    return $res
		}
		version {
		    # name + version - all platforms

		    set res {}
		    foreach i $linstances {
			if {$name ne [lindex $i 0]} continue
			if {[package vcompare $version [lindex $i 1]] != 0} continue
			lappend res $i
		    }
		    return $res
		}
		instance {
		    # name + version + platform

		    return [concat \
				[$self find/exact package [list $arch] $name $version] \
				[$self find/exact profile [list $arch] $name $version]]
		}
		eall - ename - eversion - einstance {
		    if {
			($e ne "package") &&
			($e ne "profile")
		    } {return {}}
		    set spectype [string range $spectype 1 end]
		    continue
		}
	    }
	    return -code error "Bad spec"
	}
	return -code error "Bad spec"
    }

    method exists {instance} {
	return [info exists instances($instance)]
    }

    # ### ### ### ######### ######### #########
    ##
    # Find the best matching instance for the reference, and given set
    # of acceptable platforms. Platforms are tried in listed order to
    # break ties if the same best version exists for several of them.

    method findref {platforms ref} {
	log::debug "findref ($ref) <$platforms>"
	set type [teapot::reference::type $ref name version]
	# exact  : version = a single version
	# version: version = list of  versions
	set etype [::teapot::reference::entity $ref package]
	switch -exact -- $type {
	    name    {return [$self find       $etype $platforms $name]}
	    version {return [$self find/reqs  $etype $platforms $name $version]}
	    exact   {return [$self find/exact $etype $platforms $name $version]}
	}

	return -code error "Bad reference \"$ref\""
    }

    method find {etype platforms name} {
	foreach p $platforms {
	    set vkey [list $etype $name $p]
	    if {![info exists versions($vkey)]} continue

	    # Choose highest possible version.
	    set v [lindex $versions($vkey) 0]
	    return [list [teapot::instance::cons $etype $name $v $p]]
	}
	return {}
    }

    method find/reqs {etype platforms name requirements} {
	# One or more requirements.
	set req [::teapot::reference::req2tcl $requirements]
	foreach p $platforms {
	    set vkey [list $etype $name $p]
	    if {![info exists versions($vkey)]} continue

	    # Scan the list of versions for an acceptable one.
	    foreach v $versions($vkey) {
		# 8.5 package vsatisfies $v {expand}$req
		if {[eval [linsert $req 0 ::package vsatisfies $v]]} {
		    return [list [teapot::instance::cons $etype $name $v $p]]
		}
	    }
	}
	return {}
    }

    method find/exact {etype platforms name version} {
	foreach p $platforms {
	    set instance [teapot::instance::cons $etype $name $version $p]
	    if {[info exists instances($instance)]} {
		return [list $instance]
	    }
	}
	return {}
    }

    # ### ### ### ######### ######### #########
    ## Find all possible matches of a ref, assuming the arch of an
    ## instance as context.

    method deref {instance ref platforms} {
	log::debug "deref ($ref) <$platforms>, user ($instance)"

	# Determine what instances match the reference, in the context
	# of the using instance. The architecture of the instance is
	# used to restrict the search to instances for the same or
	# similar platform. In the case of a 'tcl' package we accept
	# the platforms specified explicitly. If that list is empty we
	# accept all.

	# The code locates the best version for each possible platform
	# and returns that set as the result.

	teapot::instance::split $instance e n v arch
	if {$arch eq "tcl"} {
	    if {![llength $platforms]} {
		set platforms [$self find/platforms $ref]
	    }
	} else {
	    set platforms [platform::patterns $arch]
	}

	return [$self findref/bestall $platforms $ref]
    }

    method find/platforms {ref} {
	set name [teapot::reference::name $ref]
	set res {}
	foreach k [array names versions [list $name *]] {
	    lappend res [lindex $k 1]
	}
	return $res
    }

    # ### ### ### ######### ######### #########
    ##
    # Find the best matching instances (plural!) for the reference,
    # and the given set of acceptable platforms. The final result is the
    # union of the results for each possible platform.

    method findref/bestall {platforms ref} {
	set type [teapot::reference::type $ref name version]
	switch -exact -- $type {
	    name    {return [$self find/bestall       $platforms $name]}
	    version {return [$self find/reqs/bestall  $platforms $name $version]}
	    exact   {return [$self find/exact/bestall $platforms $name $version]}
	}

	return -code error "Bad reference \"$ref\""
    }

    method find/bestall {platforms name} {
	set res {}
	foreach p $platforms {
	    set maxv {}
	    set maxk {}
	    foreach vkey [array names versions [list * $name $p]] {
		# Choose the highest possible version.
		set v [lindex $versions($vkey) 0]
		if {$maxv eq "" || [package vcompare $v $maxv] > 0} {
		    set maxv $v
		    set maxk $vkey
		} elseif {[package vcompare $v $maxv] == 0} {
		    lappend maxk $vkey
		}
	    }
	    foreach vkey $maxk {
		set etype [lindex $vkey 0]
		lappend res [teapot::instance::cons $etype $name $maxv $p]
	    }
	}
	return $res
    }

    method find/reqs/bestall {platforms name requirements} {
	set res {}
	set req [::teapot::reference::req2tcl $requirements]
	foreach p $platforms {
	    set maxv {}
	    set maxk {}
	    foreach vkey [array names versions [list * $name $p]] {
		# Scan the list of versions for an acceptable
		# one. Remember that the list is sorted in decreasing
		# order, from highest to lowest version.

		foreach v $versions($vkey) {
		    # 8.5: package vsatisfies $v {expand}$req
		    if {[eval [linsert $req 0 package vsatisfies $v]]} {
			if {$maxv eq "" || [package vcompare $v $maxv] > 0} {
			    set maxv $v
			    set maxk $vkey
			} elseif {[package vcompare $v $maxv] == 0} {
			    lappend maxk $vkey
			}
			break ; # Next vkey (= different etype)
		    }
		}
	    }
	    foreach vkey $maxk {
		set etype [lindex $vkey 0]
		lappend res [teapot::instance::cons $etype $name $maxv $p]
	    }
	}
	return $res
    }

    method find/exact/bestall {platforms name version} {
	set res {}
	foreach p $platforms {
	    foreach etype {package profile} {
		set instance [teapot::instance::cons $etype $name $version $p]
		if {[info exists instances($instance)]} {
		    lappend res $instance
		}
	    }
	}
	return $res
    }

    # ### ### ### ######### ######### #########
    ##
    # Find all matching instances for the reference and the given set
    # of acceptable platforms.

    method findallref {platforms ref} {
	set type [teapot::reference::type $ref name version]
	switch -exact -- $type {
	    name    {return [$self findall       $platforms $name]}
	    version {return [$self findall/reqs  $platforms $name $version]}
	    exact   {return [$self findall/exact $platforms $name $version]}
	}

	return -code error "Bad reference \"$ref\""
    }

    method findall {platforms name} {
	set res {}
	foreach p $platforms {
	    foreach vkey [array names version [list * $name $p]] {
		set etype [lindex $vkey 0]
		# Choose all versions
		foreach v $versions($vkey) {
		    lappend res [teapot::instance::cons $etype $name $v $p]
		}
	    }
	}
	return $res
    }

    method findall/reqs {platforms name requirements} {
	set res {}
	foreach p $platforms {
	    foreach vkey [array names version [list * $name $p]] {
		set etype [lindex $vkey 0]
		# Scan list of versions for an acceptable one.
		foreach v $versions($vkey) {
		    # 8.5: package vsatisfies $v {expand}$requirements
		    if {![eval [linsert $requirements 0 package vsatisfies $v]]} continue
		    lappend res [teapot::instance::cons package $name $v $p]
		}
	    }
	}
	return $res
    }

    method findall/exact {platforms name version} {
	set res {}
	foreach p $platforms {
	    foreach etype {package profile} {
		set instance [teapot::instance::cons $type $name $version $p]
		if {![info exists instances($instance)]} continue
		lappend res [list $instance]
	    }
	}
	return $res
    }

    # ### ### ### ######### ######### #########
    ##
    # Find all matching instances for the reference, assuming that all
    # platforms are acceptable.

    method findallref/unrestricted {ref} {
	set type [teapot::reference::type $ref name version]
	switch -exact -- $type {
	    name    {return [$self list                [list $name]]}
	    version {return [$self findall/reqs/unrestricted $name $version]}
	    exact   {return [$self list                [list $name $version]]}
	}

	return -code error "Bad reference \"$ref\""
    }

    method findall/unrestricted {name} {
	return [$self list [list $name]]
    }

    method findall/reqs/unrestricted {name requirements} {
	# name, all platforms, all satisfying versions!

	set res {}
	foreach i $linstances {
	    if {$name ne [lindex $i 0]} continue
	    # 8.5: package vsatisfies [lindex $i 1] {expand}$requirements
	    if {![eval [linsert $requirements 0 package vsatisfies [lindex $i 1]]]} continue
	    lappend res $i
	}
	return $res
    }

    method findall/exact/unrestricted {name version} {
	return [$self list [list $name $version]]
    }

    # ### ### ### ######### ######### #########
    ## API - Entering instances.

    method enter {instance} {
	log::debug "$self enter ($instance)"

	# Non-packages are bad, as are bogus instances in general.

	if {![teapot::instance::valid $instance message]} {
	    return -code error "Bad instance \"$instance\": $message"
	}
	teapot::instance::split $instance entity name version arch
	if {
	    ([string tolower $entity] ne "package") &&
	    ([string tolower $entity] ne "profile")
	} {
	    return -code error "Neither package nor profile"
	}

	# Ignore entering of known instances.
	if {[info exists instances($instance)]} {return 0}

	set instances($instance) {}
	lappend linstances $instance

	set vkey [list $entity $name $arch]
	lappend versions($vkey) $version
	set     versions($vkey) [lsort -dict -decreasing $versions($vkey)]

	return 1
    }

    method replace {newinstances} {
	# Clear, then enter the new stuff.
	$self clear
	foreach i $newinstances {$self enter $i}
	return
    }

    # ### ### ### ######### ######### #########
    ## Clearing the database

    method clear {} {
	set linstances {}
	array unset instances *
	array unset versions  *
	return
    }

    # ### ### ### ######### ######### #########
    ## API - Construction, destruction - Defaults

    # ### ### ### ######### ######### #########
    ## Data structures
    #
    # - instance presence : For exact searching.
    # - package by arch, list of known versions.
    #   sorted descending, largest first (higher priority,
    #   find quick).
    # - List of all instances for quick return, instead of
    #   collecting from array.

    # instances  : array (list (name version arch) -> value)
    # versions   : array (list (name arch) -> list (version ...))
    # linstances : list (list (name version arch) ...)

    variable instances -array {}
    variable versions  -array {}
    variable linstances       {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
