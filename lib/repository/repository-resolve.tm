# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::resolve 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     snit
# Meta require     struct::list
# Meta require     teapot::reference
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview
#
# This class encapsulates the package resolution algorithm. Instances
# are configured with a set of repositories to query and then expand
# package references into a list of best matching instances for the
# original packages and all relevant dependencies.
##
# The repositories given to a resolver fall into two classes.
##
# Class I.  Packages found here are considered as already
#           installed. Dependencies are followed, but they
#           are not added to the list of things to retrieve.
##
# Class II. Packages found here are considered as missing.
#          Dependencies are followed, and they are put on
#          the list of packages to retrieve.
##
# Internally we have a Class 0. as well, containing the package
# references we have handled already in any way. If such
# references are repeated latere there is no need to check them
# again.
##
# A progress callback can be used to report on the progress of
# resolution.
##
# The resolver uses only the three repository API methods listed
# below:
#
# - require
# - recommend
# - find

# ### ### ### ######### ######### #########
## Requirements

package require logger
package require snit
package require struct::list
package require teapot::instance   ; # Instance handling
package require teapot::reference  ; # Reference handling

# ### ### ### ######### ######### #########
##

logger::initNamespace ::repository::resolve
snit::type            ::repository::resolve {

    # Input:  list(package-ref)
    # Result: dict (package-ref -> resolve-result)
    #
    # resolve-result    = list (installed extended-instance archives)
    # extended-instance = list (name version architecture isprofile)
    # archives          = list (repository)

    # ### ### ### ######### ######### #########
    ## API

    option -follow-recommends 0
    option -progress          {}
    option -on-error          {}

    constructor {arch platform args} {}

    #method add-archive  {isinstallation repository} {}
    #method resolve      {references} {}
    #method find         {ref} {}
    #method dependencies {repolist instance} {}

    # ### ### ### ######### ######### #########
    ## API Implementation

    constructor {a p args} {
	set platform      $p
	set architecture  $a
	set archpatterns  [platform::patterns $a]
	set archives      {}
	set installations {}
	array set archive {}

	$self configurelist $args
	return
    }

    method add-archive {isinstallation repository} {
	log::debug "$self add-archive $isinstallation $repository [$repository cget -location]"

	if {[info exists archive($repository)]} {
	    return -code error "Repository $epository already known"

	}

	set     archive($repository) $isinstallation
	if {$isinstallation} {
	    lappend installations $repository
	} else {
	    lappend archives $repository
	}
	lappend all $repository
	return
    }

    method resolve {references} {
	log::debug "$self resolve  [llength $references]"
	log::debug "* [join $references "\n* "]"

	set       result   {}
	array set resolved {}
	set       waiting  {}
	set at             0

	Enter: $references

	while {$at < [llength $waiting]} {
	    set here $at
	    incr at
	    set ref [lindex $waiting $here]

	    log::debug "    Handle ($ref)"

	    set res	[$self Resolve $ref]
	    foreach {installed einstance repolist} $res break

	    lappend result $ref $res

	    if {[llength $repolist]} {
		teapot::instance::norm  einstance
		$self Follow $repolist $einstance
	    }
	}

	log::debug $result
	return $result
    }

    method find {ref} {
	log::debug "$self find ($ref)"

	set res	[$self Resolve $ref]
	foreach {installed einstance repolist} $res break
	if {![llength $repolist]} {
	    	log::debug "    NOT FOUND"
	    return {}
	}
	log::debug "    ($einstance) @ ([l $repolist])"
	return [list $einstance $repolist]
    }

    proc l {repos} {
	set res {}
	foreach r $repos {lappend res [$r cget -location]}
	return $res
    }

    method dependencies {repolist instance} {
	log::debug "$self dependencies ($instance) @ ([l $repolist])"

	set result [$self Require $repolist $instance]

	if {!$options(-follow-recommends)} {
	    log::debug "    * [join $result "\n    * "]"
	    return $result
	}

	foreach ref [$self Recommend $repolist $instance] {
	    lappend result $ref
	}

	log::debug "    * [join $result "\n    * "]"
	return $result
    }

    # ### ### ### ######### ######### #########
    ## Internals

    method Resolve {ref} {
	# Exact ref implies sequential search through installations,
	# then archives for the first match. Otherwise a parallel
	# search across all repositories is done, followed by the
	# selection of the best matching instance. From that
	# determination if the instance is installed.

	log::debug "$self Resolve ($ref)"

	set reftype [::teapot::reference::type $ref pn pv]
	set isexact [expr {"exact" eq $reftype}]

	if {!$isexact} {
	    set idict [$self Find $all $ref]
	    # dict(einstance -> list(repo))

	    if {![llength $idict]} {
		# Nothing found
		return {0 {} {}}
	    }

	    foreach {einstance rlist} [BestMatch $idict] break
	    return [list [Installed $rlist archive] $einstance $rlist]
	}

	# Exact search, installations first. Will return exactly
	# one instance, or none.

	set idict [$self Find $installations $ref]
	if {[llength $idict]} {
	    # idict is nearly in result form, just put install flag in
	    # front.

	    return [linsert $idict 0 1]
	}

	# Exact search, not installed, go to archives.

	set idict [$self Find $archives $ref]
	if {[llength $idict]} {
	    # idict is nearly in result form, just put install flag in
	    # front.

	    return [linsert $idict 0 1]
	}

	# Exact search, nothing found.

	return {0 {} {}}

	# Result: list (installed einstance repolist)
    }

    proc BestMatch {dict} {
	# dict(einstance -> list(repo))

	log::debug BestMatch\ ($dict)

	if {[llength $dict] == 2} {
	    # Only one entry, is best match.
	    return $dict
	}

	set match  [lrange $dict 0 1]
	set matchv [lindex [lindex $match 0] 1]

	foreach {einstance rlist} [lrange $dict 2 end] {
	    set ev [lindex $einstance 1]
	    if {[package vcompare $ev $matchv] <= 0} continue

	    set matchv $ev
	    set match  [list $einstance $rlist]
	}

	return $match
    }

    proc Installed {rlist av} {
	upvar 1 $av archive
	foreach r $rlist {
	    if {$archive($r)} {return 1}
	}
	return 0
    }

    method Find {repolist ref} {
	# find returns 1-element list. After collection this is
	#    list(list(repo list(instance)))
	# fold changes this to
	#     dict(repo -> instance)
	# inversion changes it to
	#     dict(instance -> list(repo))

	log::debug "$self Find ($ref) @ ([l $repolist])"

	return [Invert [$self Do $repolist {} [myproc DictFind] \
			    find $archpatterns $ref]]
    }
    proc DictFind {a new} {
	foreach {r list} $new break
	# Filtering out the repositories where the instance was not found.
	if {[llength $list]} {
	    lappend a $r [lindex $list 0]
	}
	return $a
    }
    proc Invert {dict} {
	array set res {}
	foreach {r i} $dict {
	    lappend res($i) $r
	}
	return [array get res]
    }

    # ### ### ### ######### ######### #########

    method Follow {repolist instance} {
	upvar 1 waiting waiting resolved resolved
	Enter: [$self dependencies $repolist $instance]
	return
    }

    method Require {repolist instance} {
	set     res [$self Do $repolist {} [myproc Merge] require $instance]
	return $res
    }

    method Recommend {repolist instance} {
	set     res [$self Do $repolist {} [myproc Merge] recommend $instance]
	return $res
    }

    proc Merge {a new} {
	foreach {r list} $new break
	foreach l $list {lappend a $l}
	return $a
    }

    # ### ### ### ######### ######### #########

    ## Add new references to list of references we have to process.
    ## Weed out all references already seen, and the references
    ## which are irrelevant to the platform.

    proc Enter: {references} {
	upvar 1 waiting waiting resolved resolved
	upvar 1 platform platform architecture architecture
	foreach ref $references {
	    if {[info exists resolved($ref)]} continue
	    if {[::teapot::reference::skip? $ref $platform $architecture]} continue

	    log::debug "Enter: $ref"
	    lappend waiting    $ref
	    set       resolved($ref) .
	}
	return
    }

    # ### ### ### ######### ######### #########

    method Do {repolist zero fold args} {
	foreach {res err} [Do $repolist $args] break

	if {[llength $err]} {
	    if {[llength $options(-on-error)]} {
		foreach {r msg} $err {
		    uplevel \#0 [linsert $options(-on-error) end $r $msg]
		}
	    }

	    # Report errors into the log as well.
	    foreach {r msg} $err {
		log::debug "ERR ($r): $msg"
	    }
	}

	if {[llength $fold]} {
	    return [struct::list fold $res $zero $fold]
	} else {
	    return $res
	}
    }

    ::variable do_counter
    ::variable do_wait
    ::variable do_result
    ::variable do_error

    proc Do {repolist alist} {
	::variable do_counter [llength $repolist]
	::variable do_result {}
	::variable do_error  {}

	# Run all repositories in parallel. The results
	# are folded together.

	foreach r $repolist {

	    # alist = cmd args
	    #
	    # insert before 1 : callback
	    # insert before 0 : repository
	    #
	    # cmd = repo cmd callback args

	    set   cmd [linsert [linsert $alist 1 -command [myproc Done $r]] 0 $r]

	    log::debug "Do ($cmd)"

	    eval $cmd
	}
	# cannot use myvar, we are in a proc
	vwait ::repository::resolve::do_wait

	return [list $do_result $do_error]
    }

    proc Done {r code result} {
	::variable do_counter
	::variable do_wait
	::variable do_result
	::variable do_error

	log::debug "Done $r $code ($result)"

	if {!$code} {
	    lappend do_result [list $r $result]
	} else {
	    lappend do_error $r $result
	}

	log::debug "Done 1/$do_counter"

	incr do_counter -1
	if {$do_counter <= 0} {
	    log::debug "Done all, release"
	    set do_wait .
	}
	return
    }

    # ### ### ### ######### ######### #########

    # ### ### ### ######### ######### #########
    ## Data structures

    variable platform
    variable architecture
    variable archpatterns

    variable archive
    variable installations
    variable archives
    variable all

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
