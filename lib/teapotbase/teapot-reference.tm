# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::reference 0.1
# Meta category    teapot
# Meta description Teapot support functionality. Entity references. Data
# Meta description structures for various concepts, like references, entity
# Meta description instances and the like.
# Meta platform    tcl
# Meta require     logger
# Meta require     teapot::entity
# Meta require     teapot::version
# Meta subject     teapot {entity reference information}
# Meta subject     {transfer data structures}
# Meta summary     Teapot support functionality. Entity references. Data
# Meta summary     structures.
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Operations on and for package references in various formats.
#
## Old format:   Foo-X.y (TclApp)
## New format:   {Foo ?-version X? ?-exact 0|1? ?-is entity? ...}
## Newer format: {Foo ?-require req? ?-is entity? ...}
## Even newer:   {Foo ?req? ?-require req? ?-is entity? ...}
##       where   req in <version, {version {}}, {version version}>
##           and req in <version, version-, version-version>
##       and     multiple -requirements are allowed.
#
## -version X          => -require [list {X {}}]
## -version X -exact 1 => -require [list {X X}]
#
## A reference using the new or newer format during construction is
## automatically converted to the even newer format.
#
## Other recognized options: -platform, -archglob

# ### ### ### ######### ######### #########
## Requirements

package require teapot::version
package require teapot::entity
package require logger

logger::initNamespace ::teapot::reference
namespace eval        ::teapot::reference {}

# ### ### ### ######### ######### #########
## Implementation

proc ::teapot::reference::valid {ref {mv {}}} {
    # Was "repository::api::_templateok / depok"

    if {$mv ne ""} {upvar 1 $mv message}

    # Get size to check, implicitly also checks that the reference is
    # a valid list.

    if {[catch {
	set size [llength $ref]
    } msg]} {
	set message $msg
	return 0
    }

    # Basics: Empty is bad. Just the package name is ok.

    if {$size == 0} {set message "Empty" ; return 0}
    if {$size == 1} {return 1}

    set ref [lrange $ref 1 end] ; # Cut name

    while {[llength $ref]} {
	# Scan until first option
	set v [lindex $ref 0]
	if {[string match -* $v]} break
	# Check that the non-option is a valid requirements.
	if {![teapot::version::reqvalid $v message]} {
	    return 0
	}
	set ref [lrange $ref 1 end] ; # Cut requirement
    }

    # Uneven length is bad. The last option will have no
    # value. Remember, first element is name, then requirements, then
    # option/value pairs. An even length is expected when looking at
    # the option/value pairse.

    if {[llength $ref] % 2 == 1} {
	set message "Last option is without value"
	return 0
    }

    # Scan the options and validate them.

    foreach {k v} $ref {
	switch -exact -- $k {
	    -require {
		if {![teapot::version::reqvalid $v message]} {
		    return 0
		}
	    }
	    -platform -
	    -archglob {}
	    -is {
		if {![teapot::entity::valid $v message]} {
		    return 0
		}
	    }
	    default {
		set message "Unknown option \"$k\""
		return 0
	    }
	}
    }

    return 1
}

proc ::teapot::reference::name {ref} {
    return [lindex $ref 0]
}

proc ::teapot::reference::type {ref nv vv} {
    # Was "repository::api::templatetype"

    # Possible return values and effect on nv, vv
    #
    # name    - nv = name, vv unmodified
    # version - nv = name, vv = list of version requirements
    # exact   - nv = name, vv = the exact version

    upvar 1 $nv name $vv version

    if {[llength $ref] == 1} {
	set name [lindex $ref 0]
	return name
    }

    set name       [lindex $ref 0]
    set hasversion 0
    set isexact    0
    set n          0
    set old        0
    set vlist      {}
    set vex        {}

    set oidx 1
    foreach v [lrange $ref 1 end] {
	# Scan until first option
	if {[string match -* $v]} break
	incr oidx
	# Process requirement, imports this context
	VPR $v
    }

    foreach {k v} [lrange $ref $oidx end] {
	switch -exact -- $k {
	    -require {
		# Process requirement as option, imports this context
		VPR $v
	    }
	    -version {
		set old        1
		set hasversion 1
		set version $v
	    }
	    -exact {
		set old     1
		set isexact $v
	    }
	    default {}
	}
    }

    if {$old} {
	if {$isexact && $hasversion} {
	    # version was already set in the -version branch above
	    return exact
	} elseif {$hasversion} {
	    # version was already set in the -version branch above
	    return version
	} else {
	    # Bogus, -exact without -version
	    return -code error "-exact without -version"
	}
    } elseif {$isexact && $hasversion} {
	set version $vex
	return exact
    } elseif {$hasversion} {
	set version $vlist
	return version
    } else {
	return name
    }
}

proc ::teapot::reference::VPR {v} {
    # Importing calling context
    upvar 1 hasversion hasversion isexact isexact vlist vlist n n vex vex

    # System reports all requirements via 'vv' aka 'version'.
    set hasversion 1

    if {!$n} {
	if {[string match *-* $v]} {
	    set v [split $v -]
	}
	if {[llength $v] == 1} {
	    set isexact 0
	} elseif {[llength $v] == 2} {
	    set vex     [lindex $v 0]
	    set isexact [expr {$vex eq [lindex $v 1]}]
	}
    } else {
	# Multiple requirements. Cannot be exact. Remember that cons
	# removes duplicate requirements, so it is not possible in
	# this situation that the requirement matches an earlier exact
	# one.
	
	set isexact 0
    }
    lappend vlist $v
    incr n
    return
}

proc ::teapot::reference::Options {ref} {
    set idx 1
    foreach v [lrange $ref 1 end] {
	# Scan until first option
	if {[string match -* $v]} break
	incr idx
    }
    return [lrange $ref $idx end]
}

proc ::teapot::reference::cons {name args} {
    conslist $name $args
}

proc ::teapot::reference::conslist {name spec} {

    # The constructor for references recognizes not only the options
    # for the newer syntax, but also for the new syntax (see top of
    # file). The latter are accepted if and only if not mixed with the
    # newer options, and are converted on the fly to the newer syntax.
    # Requirements between name and options are recognized and
    # collected as well.

    # Additional work done by the constructor is
    # - Removal of redundant switches
    #   @ -platform, -archglob, -is = Only last value counts.
    #   @ -require                  = Only unique ranges, non-redundant ranges
    # - Sort of switches.
    # This generates a canonical reference.

    # Quick return if reference is plain name without switches.

    if {![llength $spec]} {
	return [list $name]
    }

    # Phase I. Take spec apart into requirements and regular switches.

    set ver   {} ; set hasver  0 ; # Data for -version,  flag when used.
    set exact 0  ; set hasex   0 ; # Data for -exact,    flag when used.
    set plat  {} ; set hasplat 0 ; # Data for -platform, flag when used.
    set ag    {} ; set hasag   0 ; # Data for -archglob, flag when used.
    set is    {} ; set hasis   0 ; # Data for -is,       flag when used.

    array set reqs {}

    set oidx 0
    foreach v $spec {
	# Scan until first option
	if {[string match -* $v]} break
	incr oidx
	set reqs($v) .
    }

    foreach {o v} [lrange $spec $oidx end] {
	switch -exact -- $o {
	    -exact    {set exact $v ; set hasex   1}
	    -version  {set ver   $v ; set hasver  1}
	    -platform {set plat  $v ; set hasplat 1}
	    -archglob {set ag    $v ; set hasag   1}
	    -is       {set is    $v ; set hasis   1}
	    -require  {set reqs($v) .}
	}
    }

    # Phase II. Validate the input, basics. Check for old vs. new, and
    # various other simple validations.

    if {$hasver || $hasex} {
	if {[array size reqs]} {
	    return -code error "Cannot mix old and new style version requirements"
	}

	# -exact implies -version
	if {$hasex && !$hasver} {
	    return -code error "-exact without -version"
	}

	if {$hasex && ![string is boolean -strict $exact]} {
	    return -code error "Expected boolean for -exact, but got \"$v\""
	}
	if {$hasver && ![teapot::version::valid $ver message]} {
	    return -code error $message
	}

	# Translate to new form.

	lappend item $ver
	if {$exact} {
	    # -exact 8   => 8-9
	    # -exact 8.4 => 8.4-8.5
	    # ...

	    ### TODO ### Use teapot::version::next

	    set x [split $ver .]

	    # Increment the last element. Remove leading zeros to
	    # prevent mis-interpretation as an octal number. See Bug
	    # 72117.

	    scan [lindex $x end] %d ld
	    incr ld

	    lappend item [join [lreplace $x end end $ld] .]
	} else {
	    # Cap at next major version.
	    # -version 8   => 8-9
	    # -version 8.4 => 8.4-9

	    lappend item [expr {[lindex [split $ver .] 0]+1}]
	}
	set reqs($item) .
    }

    if {$hasis} {
	set is [string tolower $is]
	if {![teapot::entity::valid $is message]} {
	    return -code error $message
	}
    }

    # Phase III. Get over the requirements and remove redundant
    # ranges. Validate them first. If there is only one range it
    # cannot be redundant.

    if {[array size reqs]} {
	foreach req [array names reqs] {
	    teapot::version::reqcheck $req
	    # Translate X-Y forms into the list form for all internal use
	    if {[string match *-* $req]} {
		set rx [split $req -]
		unset reqs($req)
		set reqs($rx) .
	    }
	}

	if {[array size reqs] > 1} {
	    foreach req [array names reqs] {
		foreach other [array names reqs] {
		    # Ignore self.
		    if {$other eq $req} continue
		    if {[Subset $req $other]} {
			unset reqs($req)
			break
		    }
		}
	    }
	}
    }

    # Phase IV. Put the pieces back together to get the canonical
    # form. Which contains every requirement in option form.

    set ref [list $name]
    if {$hasis}   {lappend ref -is $is}
    if {$hasag}   {lappend ref -archglob $ag}
    if {$hasplat} {lappend ref -platform $plat}

    if {[array size reqs]} {
	foreach req [lsort -dict [array names reqs]] {
	    lappend ref -require $req
	}
    }

    # No validation required, we know that the result is ok. We
    # checked all the inputs in the same manner as the validator.

    return $ref
}

proc ::teapot::reference::normalize1 {ref} {
    return [conslist [lindex $ref 0] [lrange $ref 1 end]]
}

proc ::teapot::reference::normalize {references} {
    # Take a list of references and remove redundancies in each
    # reference, and across all references.

    # In a first iteration each reference is brought into canonical
    # form. This removes the redundancies in each reference. Then we
    # sort the references by package name, and for each package with
    # more than one reference we put them together and re-construct
    # the canonical form.

    array set package {}

    # Bug 72969. Keep the order of dependencies, it may be important
    # during setup.

    set names {}

    foreach ref $references {
	set name [lindex $ref 0]
	set spec [lrange $ref 1 end]

	set ref [conslist $name $spec]

	set name [lindex $ref 0]
	set spec [lrange $ref 1 end]

	if {![info exists package($name)]} {
	    lappend names $name
	}
	lappend package($name) $spec
    }

    set references {}
    foreach name $names {
	set specs $package($name)

	if {[llength $specs] == 1} {
	    # Single reference, reconstruct from parts, is canonical
	    # already.

	    lappend references [linsert [lindex $specs 0] 0 $name]
	} else {
	    # Multiple references to one package.
	    # Merge specs into one list and re-canonicalize.

	    # 8.5 .. [concat {expand}$specs]
	    set spec [eval [linsert $specs 0 concat]]
	    lappend references [conslist $name $spec]
	}
    }

    return $references
}

proc ::teapot::reference::ref2tcl {ref} {
    # Convert internal form (requirements are 1/2-element lists) to
    # Tcl form, requirements are 'a', 'a-b', 'a-'. This form is
    # accepted on input, easier to read by a user, and no difference
    # to regular Tcl. We additionally convert -require options into
    # plain non-option requirements sitting between name and the
    # option/value part.

    set res [lindex $ref 0]

    # Non-option requirements.

    set oidx 1
    foreach v [lrange $ref 1 end] {
	# Scan until first option
	if {[string match -* $v]} break
	incr oidx
	lappend res [teapot::version::reqstring $v]
    }
    set options [lrange $ref $oidx end]

    # Option requirements to non-option requirements.

    foreach {k v} $options {
	if {$k ne "-require"} continue
	lappend res [teapot::version::reqstring $v]
    }

    # All other options.

    foreach {k v} $options {
	if {$k eq "-require"} continue
	lappend res $k $v
    }
    return $res
}

proc ::teapot::reference::pseudoinstance {ref} {
    # Was "repository::api::templateinstance"
    # Caller has to filter out non-package references.

    # We are not using teapot::instance commands because they would
    # fail us, as we are creating something which is invalid, strictly
    # speaking, and these commands do not allow such a
    # construction. It would also cause a cicular dependency between
    # instance and reference.

    switch -exact -- [type $ref name version] {
	name    {return [list Package $name {} {}]}
	exact   {return [list Package $name $version {}]}
	version {
	    # For the pseudo-instance we take the lowest possible version.
	    set version [lindex [lindex $version 0] 0]
	    return [list Package $name $version {}]
	}
    }
    return -code error "Bad reference \"$ref\""
}

proc ::teapot::reference::requirecmd {ref} {
    # Caller has to filter out non-package references.
    #
    # Note: exact could have been translated to the new form of
    # package require, however I wish to retain as much backward
    # compatibility in the code as is possible. I.e. use TIP 268
    # syntax if and only if truly needed.

    switch -exact -- [type $ref name version] {
	name    {return [list package require $name]}
	exact   {return [list package require -exact $name $version]}
	version {
	    # Multiple requirements are possible. They can all be
	    # found in 'version' already. Put them into the
	    # constructed command, properly formatted.

	    return [linsert [req2tcl $version] 0 package require $name]
	}
    }
    return -code error "Bad reference \"$ref\""
}

proc ::teapot::reference::req2tcl {req} {
    # Convert a list of requirements in reference form (1/2-list) into
    # the form understood by vsatisfies.

    set res {}
    foreach v $req {
	lappend res [teapot::version::reqstring $v]
    }
    return $res
}

proc ::teapot::reference::skip? {ref platform architecture} {
    # Check if we should skip the reference, based on its contents,
    # and the specified execution context (p/a).

    # Unguarded reference. Never skip.
    if {[llength $ref] == 1} {return 0}

    # Extract the guards from the reference, if any, then check them.

    set haspguard 0 ; set pguard ""
    set hasaguard 0 ; set aguard ""

    foreach {k v} [Options $ref] {
	switch -exact -- $k {
	    -platform {
		set pguard $v
		set haspguard 1
	    }
	    -archglob {
		set hasaguard 1
		set aguard $v
	    }
	    default {}
	}
    }

    return [expr {
	  ($haspguard && ($pguard ne $platform)) ||
	  ($hasaguard && ![string match $aguard $architecture])
    }]
}

proc ::teapot::reference::guards {ref} {
    # Was "repository::api::templateguards"

    # Check the reference for guards and return them as a dictionary.
    # Key:   Option, stripped of its initial dash.
    # Value: The value associated with the option.

    # Unguarded reference. Nothing.
    if {[llength $ref] == 1} {return {}}

    set guards {}

    foreach {k v} [Options $ref] {
	switch -exact -- $k {
	    -platform {lappend guards platform $v}
	    -archglob {lappend guards archglob $v}
	    default {}
	}
    }

    return $guards
}

proc ::teapot::reference::entity {ref contextentity} {
    # Check the reference for an entity-type specification and return
    # it (the last). If the reference has no type of its own then it
    # has the type of the entity containing the reference, i.e. the
    # context.

    # Intra-entity reference. Context.
    if {[llength $ref] == 1} {return $contextentity}

    set entity $contextentity

    foreach {k v} [Options $ref] {
	switch -exact -- $k {
	    -is {set entity $v}
	    default {}
	}
    }

    return $entity
}

proc ::teapot::reference::rawentity {ref} {
    # Check the reference for an entity-type specification and return
    # it (the last).

    # Intra-entity reference. No type.
    if {[llength $ref] == 1} {return {}}

    set entity {}

    foreach {k v} [Options $ref] {
	switch -exact -- $k {
	    -is {set entity $v}
	    default {}
	}
    }

    return $entity
}

proc ::teapot::reference::completetype {rv contextentity} {
    # Add entity information to references without.
    upvar 1 $rv ref

    # Check the reference for an entity-type specification and return
    # it (the last). If the reference has no type of its own then it
    # has the type of the entity containing the reference, i.e. the
    # context.

    # Intra-entity reference. Context.
    if {[llength $ref] == 1} {
	lappend ref -is $contextentity
	return
    }

    set entity $contextentity

    set ref [normalize1 $ref]
    foreach {k v} [Options $ref] {
	switch -exact -- $k {
	    -is {return $ref}
	    default {}
	}
    }

    lappend ref -is $contextentity
    return
}

# ### ### ### ######### ######### #########
## Internals

proc ::teapot::reference::Subset {a b} {
    # Returns true if the requirement A is a true subset of requirement B.

    # 1  A = vA            B = vB
    # 2  A = vA -          B = vB -
    # 3  A = vAmin vAmax   B = vBmin vBmax

    # 3 cases per A and B, for a total of 9 combinations.

    # This can be reduced by recognizing that (1) is actually (3),
    # with the max value implied, i.e. derived from the min value.
    # This reduces the situation to four combinations.

    set a [Rtype $a mina maxa]
    set b [Rtype $b minb maxb]

    # 22, 32 are one case, they have the same condition to check. See below.
    ##
    # 22 :
    # A and B are ranges from a minimum to infinity.
    # The range with the larger minimum is the true subset.
    # This implies: A is a true subset of B iff minA > minB. ** same
    ##
    # 32 :
    # A is min to a max,    i.e. of finite size.
    # B is min to infinity, i.e. of infinite size.
    # This implies: A is a true subset iff minA > minB.      ** same
    ##
    # 23 :
    # A is min to infinity, i.e. of infinite size.
    # B is min to a max,    i.e. of finite size.
    # An infinite subset of a finite set is not possible.
    # This implies: A is not a true subset of B
    ##
    # 33 :
    # Both A and B are finite ranges. A is a true subset of B iff
    # (minA >  minB) && (maxA <= maxB) or
    # (minA >= minB) && (maxA <  maxB)

    switch -exact -- $a$b {
	22 -
	32 {return [expr {[package vcompare $mina $minb] > 0}]}
	23 {return 0}
	33 {return [expr {
			  (([package vcompare $mina $minb] >  0) &&
			   ([package vcompare $maxa $maxb] <= 0)) ||
			  (([package vcompare $mina $minb] >= 0) &&
			   ([package vcompare $maxa $maxb] <  0))
		      }]}
    }
}

proc ::teapot::reference::Rtype {a minv maxv} {
    upvar 1 $minv min $maxv max

    if {[llength $a] == 1} {
	# (1), make it a (3)
	set min   [lindex $a 0]
	set major [lindex [split $min .] 0]
	set max   $major
	# Bug 67186
	incr max
	return 3
    } else {
	# (llength a == 2)
	# (2), (3)
	foreach {min max} $a break
	return [expr {$max eq "" ? 2 : 3}]
    }
}

# ### ### ### ######### ######### #########
## Ready
return
