# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgman.tcl --
# -*- tcl -*-
#
#	state object to manage the available packages, and the
#	set of packages chosen for wrapping.
#
# Copyright (c) 2006-7 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Docs

# TODO: Need callback for reporting ok yes/no information

# TODO : connect -config to all panel (change notification,
#        data retrieval).

# ### ### ### ######### ######### #########
## Requisites

#package require struct::graph    ; # Tcllib, dependency tracking
package require as::cache::async
package require as::cache::sync
package require logger           ; # Standard tracing
package require mafter
package require pkg::mem
package require platform
package require req              ; # Delayed computes
package require snit             ; # Tcllib, OO core.
package require struct::list     ; #
package require tclapp::pkg
package require view             ; # View core api

package require repository::localma   ; # 
package require repository::prefix    ; # 
package require repository::proxy     ; # 
package require repository::sqlitedir ; # Archives we can use ...
package require repository::tap       ; # 

package require teapot::instance      ; # Instance handling
package require teapot::listspec      ; # List/spec handling
package require teapot::reference     ; # Reference handling

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::pkgman
snit::type ::pkgman {
    # ### ### ### ######### ######### #########
    ## API. Definition

    option -prefix   {}
    option -config   {}
    option -variable {}
    option -log      {}

    # ### ### ### ######### ######### #########
    ## API. Implementation

    constructor {args} {
	# Handle initial options.
	$self configurelist $args

	set dbc [::pkg::mem ${selfns}::dbchosen]
	set dba [::pkg::mem ${selfns}::dbavail]

	# Views exported to the GUI
	set _vchosen [view::chosen ${selfns}::chosen $self]
	set _vavail  [view::avail  ${selfns}::avail  $self]

	set _mavchosen [mafter ${selfns}::mavchosen 10 [mymethod VTrigger $_vchosen]]
	set _mavavail  [mafter ${selfns}::mavavail  10 [mymethod VTrigger $_vavail]]

	# Recalc available instances, trigger compression.
	# Recalc chosen    instances, trigger compression.

	set _rqchosen [req ${selfns}::rqchosen [mymethod CalcChosen]]
	set _rqavail  [req ${selfns}::rqavail  [mymethod CalcAvailable]]

	# Recalc unresolved references.

	set _rqbref [req ${selfns}::rqbref [mymethod CalcUnresolved]]

	$self InitOriginCache
	$self InitDescCache
	$self InitDepCache
	$self InitStatusCaches
	$self InitCompleteCache

	# Get notified when the set of tap search paths was changed,
	# like the preferences.

	::tclapp::pkg::reinitcmd [mymethod StdPathsChanged]

	#after 1500 [mymethod RegenRepositories]
	return
    }

    destructor {
	return
    }

    # ### ### ### ######### ######### #########
    ## Architectures state

    # ### ### ### ######### ######### #########
    ## Changes to the allowed architectures

    method {architectures =} {arch} {
	log::debug "architectures = $arch"
	log::debug "      current = $_arch"

	if {$arch eq $_arch} return
	set _arch $arch

	$self RegenArchitectures
	return
    }

    # ### ### ### ######### ######### #########
    ## Retrieve current state of architectures allowed for wrapping

    method {architectures get} {} {return $_arch}

    # ### ### ### ######### ######### #########
    ## Archive state

    # ### ### ### ######### ######### #########
    ## Changes to the set of archives to consider for packages.

    method {archives externals =} {archives} {
	log::debug "archives externals = $archives"

	if {$archives eq $_aextern} return
	set _aextern $archives

	#$self RegenRepositories
	return
    }

    method StdPathsChanged {} {
	#$self RegenRepositories
	return
    }

    # ### ### ### ######### ######### #########
    ## Retrieve current state of archives considered for packages.

    method {archives externals get}      {} {return $_aextern}

    # ### ### ### ######### ######### #########
    ## Views (of available and chosen packages)

    method {viewof chosen}    {} {return $_vchosen}
    method {viewof available} {} {return $_vavail}

    # ### ### ### ######### ######### #########
    ## View API. Data retrieval

    method {chosen size} {} {
	#log::debug "cSz [llength $_ichosen]"
	return [llength $_ichosen]
    }

    method {chosen get} {row attr} {
	# See avail get regarding docs for this check.

	if {$row >= [llength $_ichosen]} {return {}}
	set instance [lindex $_ichosen $row]

	#log::debug "cGt $row = ($instance), $attr"

	set instance [lindex $_ichosen $row]
	switch -exact -- $attr {
	    name    {return [lindex $instance 1]}
	    version {return [lindex $instance 2]}
	    arch    {return [lindex $instance 3]}
	    origin  {return [$self FormattedOrigin       $instance]}
	    desc    {return [$self FormattedDesc         $instance]}
	    status  {return [$self FormattedChosenStatus $instance]}
	    __tag   {
		return $tagof([$self FormattedChosenStatus $instance])
	    }
	}
	return {}
    }

    typevariable tagof -array {
	--- {}
	M-- Missing
	-P- Prefix
	--I Incomplete
	M-I Missing
	-PI Incomplete
    }

    # The following combinations cannot happen
    #
    # MP- | From prefix, but missing
    # MPI | is not possible

    method {avail size} {} {
	#log::debug "aSz [llength $_iavailable]"
	return [llength $_iavailable]
    }

    method {avail get} {row attr} {
	# NOTE: Between the time the vtable has asked the view for its
	# size and is asking for cell data the view may have
	# recalculated its contents, due to a triggered CalcAvailable
	# slipping in between. This is ok for most of the data as it
	# delivers the new information. However the table may ask for
	# rows beyond the current size of the view if shrinkage has
	# happened. We check for this and return empty strings for
	# these rows. In such a situation the CalcAvailable will also
	# have retriggered a display refresh, so in the next cycle the
	# data will be ok.

	if {$row >= [llength $_iavailable]} {return {}}
	set instance [lindex $_iavailable $row]

	#log::debug "aGt $row = ($instance), $attr"

	switch -exact -- $attr {
	    name    {return [lindex $instance 1]}
	    version {return [lindex $instance 2]}
	    arch    {return [lindex $instance 3]}
	    origin  {return [$self FormattedOrigin      $instance]}
	    desc    {return [$self FormattedDesc        $instance]}
	    status  {
		return {}
		# Disable status processing. Too much CPU load right now
		return [$self FormattedAvailStatus $instance]
	    }
	    __tag   {
		return {}
		# Disable color cues, status processing. Too much load right now.
		if {[$self FormattedAvailStatus $instance] eq "Incomplete"} {
		    return Incomplete
		} else {
		    return {}
		}
	    }
	}
	return {}
    }

    # ### ### ### ######### ######### #########
    ## Actions

    typemethod {append defaults to} {lv} {
	upvar 1 $lv defaults

	lappend defaults \
	    Pkg/Instance  {} \
	    Pkg/Reference {} 

	# Defaults from preferences. Note: The std archives are _not_
	# put into the project. They are implicit defaults.

	lappend defaults \
	    Pkg/Architecture [pref::devkit::defaultArchitectures]
	return
    }

    method {save configuration into} {sv} {
	upvar 1 $sv serial

	#set serial(pkg,repo,urls)   [$self archives externals get]
	#set serial(pkg,platforms)   [$self architectures get]

	set ins {}
	set ref {}
	array set has {}

	foreach instance $_ichosen {
	    # Prefix instances are stored as references, to be
	    # resolved automatically on load to the actual package.
	    # Bogus instances have to be saved in a form from which we
	    # can reconstruct them upon loading. Well, that is the
	    # reference which caused the bogus instance to be
	    # generated.

	    if {[$self OriginInPrefix $instance]} {
		teapot::instance::split $instance e n v a
		set r [teapot::reference::cons $n -is $e -require $v]
		if {[info exists has($r)]} continue
		lappend ref $r
		set has($r) .
	    } elseif {[info exists _brefi($instance)]} {
		set r $_brefi($instance)
		if {[info exists has($r)]} continue
		lappend ref $r
		set has($r) .
	    } else {
		set i $instance
		if {[info exists has($i)]} continue
		lappend ins $i
		set has($i) .
	    }
	}

	set serial(pkg,instances)  $ins
	set serial(pkg,references) $ref
	return
    }

    method {restore configuration from} {sv} {
	upvar 1 $sv serial

	if 0 {
	    if {[info exists serial(pkg,repo,urls)]} {
		$self archives externals = $serial(pkg,repo,urls)
		unset serial(pkg,repo,urls)
	    }

	    if {[info exists serial(pkg,platforms)]} {
		$self architectures = $serial(pkg,platforms)
		unset serial(pkg,platforms)
	    }
	}

	if {[info exists serial(pkg,instances)]} {
	    foreach instance $serial(pkg,instances) {
		$self add instance $instance
	    }
	    unset serial(pkg,instances)
	}

	if {[info exists serial(pkg,references)]} {
	    foreach ref $serial(pkg,references) {
		$self add reference $ref
	    }
	    unset serial(pkg,references)
	}

	if {[info exists serial(pkgs)]} {
	    if {[llength $serial(pkgs)]} {

		# Well, the project file contains old-style package
		# references. We put them into data structures as
		# 'references', which will cause them to be resolved
		# automatically to the best of our ability.

		# The special hardwired package names are upgraded
		# automatically to the correct name as well,
		# always. The system will not try to search for the
		# old name before doing this.

		foreach p $serial(pkgs) {
		    tclapp::pkg::Split $p name version ref
		    tclapp::pkg::TapUpgrade $name name
		    set ref [lreplace $ref 0 0 $name]

		    $self add reference $ref
		}
	    }

	    unset serial(pkgs)
	}

	return
    }

    method {add packages} {rows} {
	# Rows in list of available packages

	if {![llength $rows]} return

	set tick 0
	foreach row $rows {
	    set instance [lindex $_iavailable $row]

	    # Ignore elements out of bounds.
	    if {![llength $instance]} continue

	    $self add instance $instance
	}

	return
    }

    method {add instance} {instance} {
	if {[info exists _pchosen($instance)]} {return 0}
	log::debug "add instance ($instance)"

	set _pchosen($instance) .

	if {[teapot::instance::valid $instance]} {
	    $dbc enter $instance
	}

	# Note: The database of bogus instances and their references
	# is extended in 'add reference' instead of here. However
	# removal of information is handled by 'remove instance'.

	$self RecalcAvailable
	$self RecalcChosen
	return 1
    }

    method {add reference} {ref {context {}} {nv {}}} {
	log::debug "add reference ($ref)"
	if {$nv ne ""} {upvar 1 $nv newinstances}

	# Locate matches for the reference in the database. For
	# unresolved references we create a bogus instance without an
	# origin and not kept in the base databases.

	# We may (have to) fake a package context for the search. All
	# of entity type, name, and version are not relevant. Only the
	# architecture, 'tcl', is needed for the call of 'deref'
	# below. This value forces the use of _archpattern.

	if {![llength $context]} {
	    set context [teapot::instance::cons package _ 0 tcl]
	}

	# We check the database of chosen instances first.
	# If we find suitable matches there nothing has to be
	# done. And the reference is not new either.

	set matches [$dbc deref $context $ref $_archpattern]

	log::debug [list $dbc deref $context $ref $_archpattern => $matches]

	if {[llength $matches]} {return 0}

	# The database of available instances is checked next. If it
	# has nothing suitable the bogus instance comes into play, as
	# placeholder for future suitable instances.

	set matches [$dba deref $context $ref $_archpattern]

	log::debug [list $dba deref $context $ref $_archpattern => $matches]

	if {![llength $matches]} {
	    log::debug "Placeholder!"

	    set              bogus [teapot::reference::pseudoinstance $ref]
	    lappend matches $bogus

	    # Bogus database extended here, not in 'add instance'.
	    # Removal is done in 'remove instance'.

	    set _brefr($ref) $bogus
	    set _brefi($bogus) $ref
	    $self MoreBad
	}

	set hasnew 0
	foreach mi $matches {
	    if {[$self add instance $mi]} {
		lappend newinstances $mi
		set hasnew 1
	    }
	}

	return $hasnew
    }

    method {add dependencies} {followrecommend donecmd {newinstances {}}} {
	# We are looking at the dependencies of either all, or all
	# incomplete instances. Only missing instances are always
	# ignored.

	# NOTE: At this point in time we cannot abide to have
	# incomplete information, and we cannot wait for the
	# information to come in later either. Because of this this
	# code accesses the database synchronously, filling up
	# everything needed from the caches and still missing, and
	# waiting for the responses from repositories, should they
	# happen to be queried.

	# 1. Missing - GetOrigins -
	#    cpkgorig (sync cache) - FindOrigins - 'list' results.
	#
	# Everything except the last is synchronous already, with no
	# need for special handling. This last however may be
	# incomplete for a while after the set of repositories was
	# changed, as the repositories send their results back over
	# time. And we cannot really wait ...
	#
	# Solution: We disable the buttons while this most basic
	# information is in the process of getting updated. I.e. the
	# user is prevented from using it at an inopportune time. And
	# now we can be sure here/now that the information is present
	# and complete.

	# 2. IsChosenComplete - IsComplete -
	#    _cpkgcomplete (async cache!) - xxCalcComplete -
	#    xCalcComplete - CalcComplete - GetRequired -
	#    _cpkgreq (async cache) - FindDep -
	#    'value' results (- GetOrigins ...)
	#
	# This is extremely async over 3 levels. The async caches can
	# be handled easily. For them an option to switch them into a
	# sync mode. This leaves FindDep. For this an internal flag
	# which tells it to execute sync.

	# 3. GetRequired/GetRecommended - s.a. 2.

	$self SyncOn

	if {[llength $newinstances]} {
	    set source $newinstances
	} else {
	    set source $_ichosen
	}

	set instances {}
	if {$followrecommend} {
	    foreach instance $source {
		if {[$self Missing $instance]} continue
		lappend instances $instance
	    }
	} else {
	    foreach instance $source {
		if {[$self Missing          $instance]} continue
		if {[$self IsChosenComplete $instance]} continue
		lappend instances $instance
	    }
	}

	# Now we have the list of instances we will check for
	# dependencies to add to the choice. We look at all its
	# references, all matching instances, and try to find any in
	# the choice.

	set changed 0
	set newinstances {}
	if {[llength $instances]} {
	    foreach instance $instances {
		teapot::instance::split $instance ctx _ _ _
		foreach r [$self GetRequired $instance] {
		    # Ignore non-package references
		    if {"package" ne [teapot::reference::entity $r package]} continue

		    if {[$self add reference $r $instance newinstances]} {
			set changed 1
		    }
		}
		if {$followrecommend} {
		    foreach r [$self GetRecommended $instance] {
			# Ignore non-package references
			if {"package" ne [teapot::reference::entity $r package]} continue

			if {[$self add reference $r $instance newinstances]} {
			    set changed 1
			}
		    }
		}
	    }
	}

	# Time to update the UI. Note that the stati of the chosen
	# instances may have changed. Any new instances affect the
	# completeness.

	if {$changed} {
	    # Re-execute this action if new instances were added to
	    # the display. Because we have to follow their
	    # dependencies as well. We allow the GUI to update in
	    # between to handle the just added instances and whatever
	    # else was triggered.

	    $self ClearStatusCacheChosen
	    after 100 [mymethod add dependencies $followrecommend $donecmd $newinstances]
	} else {
	    # Notify the GUI that the action has completed.

	    $self SyncOff
	    $self RedisplayAll
	    uplevel \#0 $donecmd
	}
	return
    }

    method {remove packages} {rows} {
	# Selected rows in list of chosen packages

	if {![llength $rows]} return

	foreach row $rows {
	    set instance [lindex $_ichosen $row]

	    # Ignore elements out of bounds.
	    if {![llength $instance]} continue

	    $self remove instance $instance
	}

	return
    }

    method {remove missing} {} {
	set changed 0
	foreach instance $_ichosen {
	    if {![$self Missing $instance]} continue
	    $self remove instance $instance
	}
	return
    }

    method {remove unused} {} {
	# %TODO% remove unused packages
	error NYI
    }

    method {remove instance} {instance} {
	if {![info exists _pchosen($instance)]} return
	log::debug "remove instance ($instance)"

	unset _pchosen($instance)

	if {[info exists _brefi($instance)]} {
	    log::debug "remove placeholder"

	    # Removal of bogus instance does not touch the database.
	    unset _brefr($_brefi($instance))
	    unset _brefi($instance)
	    $self LessBad
	} else {
	    log::debug "regenerate chosen"

	    # Full regeneration of the choice database, minus bogus
	    # instances.
	    set res {}
	    foreach i [array names _pchosen] {
		if {![teapot::instance::valid $i]} continue
		lappend res $i
	    }

	    log::debug "perform replace"
	    foreach x $res {log::debug "-- $x"}

	    $dbc replace $res
	}

	log::debug "UI maintenance (clear status cache, tick recalculations)"

	$self ClearStatusCacheChosen
	$self RecalcAvailable
	$self RecalcChosen
	return
    }

    method rescan {} {
	$self RegenRepositories
	return
    }

    # ### ### ### ######### ######### #########
    # Option management

    onconfigure -prefix {newvalue} {
	if {$options(-prefix) eq $newvalue} return

	# Thought about suspending the initialization of a prefix file
	# as repository should it be changed while such is still
	# running. Decided against. The init, even in event-driven
	# mode is so fat that not even a GUI tester should be able to
	# change before it is complete. And even if we manage it we do
	# not waste that much.

	log::debug "Prefix: ($newvalue)"

	set options(-prefix) $newvalue
	#$self RegenRepositories
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals

    # ### ### ### ######### ######### #########
    ## Track changes in the list of used repositories

    proc IsProxy {r} {
	if {[catch {
	    set proxy [expr {[repository::api typeof $r] eq "::repository::proxy"}]
	} msg]} {
	    set proxy 0
	}
	return $proxy
    }

    variable badr -array {}

    method RegenRepositories {} {
	log::debug "RegenRepositories"

	# ---------------------------------------------
	log::debug "- Construct list of repositories in use"

	set _repositories {}

	if {$options(-prefix) ne ""} {
	    # %NOTE% I would have liked to use -async 1 here to run
	    # %NOTE% the scanning in parallel with other stuff. This
	    # %NOTE% however causes problems. It gives the wrap-opt
	    # %NOTE% panel the opportunity to check the prefix file
	    # %NOTE% again and see that it became a directory. While
	    # %NOTE% this state is temporary the panel doesn't know
	    # %NOTE% and proclaims that the prefix is invalid. This
	    # %NOTE% gets propagated through the main wrapper widget
	    # %NOTE% back to us, with the prefix set to empty. This
	    # %NOTE% invalidates the origin information and aborts the
	    # %NOTE% origin-update in flight (see the handling of the
	    # %NOTE% _poepoch counter). End result is that we think
	    # %NOTE% that there is no prefix, and the instances
	    # %NOTE% provided by it have no origin, causing bogus
	    # %NOTE% stati, etc. all over the place.

	    log::debug "  + prefix ($options(-prefix))"

	    if {![info exists badr($options(-prefix))]} {
		if {[catch {
		    lappend _repositories \
			[repository::cache get \
			     repository::prefix $options(-prefix)]
		}]} {
		    set badr($options(-prefix)) .
		    $self Log error $msg
		}
	    }
	}

	foreach r $_aextern {
	    set proxy [IsProxy $r]
	    log::debug "  + <$proxy> project ($r)"

	    if {![info exists badr($r)]} {
		if {[catch {
		    if {$proxy} {
			set repo [repository::cache open $r -readonly 1 \
				      -config $options(-config) \
				      -notecmd [mymethod Log warning]]
		    } else {
			set repo [repository::cache open $r -readonly 1]
		    }
		} msg]} {
		    set badr($r) .
		    $self Log error $msg
		} else {
		    lappend _repositories $repo
		}
	    }
	}

	foreach r [pref::devkit::pkgRepositoryList] {
	    set proxy [IsProxy $r]

	    log::debug "  + <$proxy> standard ($r)"

	    if {![info exists badr($r)]} {
		if {[catch {
		    if {$proxy} {
			set repo [repository::cache open $r -readonly 1 \
				      -config $options(-config) \
				      -notecmd [mymethod Log warning]]
		    } else {
			set repo [repository::cache open $r -readonly 1]
		    }
		} msg]} {
		    set badr($r) .
		    $self Log error $msg
		} else {
		    lappend _repositories $repo
		}
	    }
	}

	log::debug "  + virtual"
	lappend _repositories [::tclapp::pkg::VirtualBase]

	# ---------------------------------------------

	$self ClearOriginCache

	# ---------------------------------------------

	if {[llength $_repositories]} {
	    log::debug "- Initiate async rescan of repository contents (packages only)"
	    # 

	    $self oNotDone [llength $_repositories]
	    foreach r $_repositories {
		log::debug "  * [$r cget -location]"

		# %FUTURE% Consider specifying and using a repository API
		# %FUTURE% command 'incrementally list'ing the repository
		# %FUTURE% contents.

		$r list -command \
		    [mymethod GotRepositoryInstances $r $_poepoch] \
		    [teapot::listspec::eall package]
	    }
	} else {
	    log::debug "- Trigger redisplay, no repositories at all"

	    $self oDone
	    $_mavchosen arm
	    $self RecalcAvailable
	}

	log::debug "- Clear complete/status caches"

	$self ClearCompleteCache
	return
    }

    method GotRepositoryInstances {repo epoch code result} {
	log::debug "GotRepositoryInstances <$epoch/$_poepoch> $code (\#: [llength $result])"

	# Ignore outdated results.
	if {$epoch != $_poepoch} {
	    log::debug "Canceled, out-of-date"
	    return
	}

	# %NOTE% Panic for bad repository ...
	# %TODO% Handle this more gracefully. Like pushing the
	# %TODO% information over to the archive panel, for
	# %TODO% colorization of the relevant entry.

	if {$code} {
	    # Remember this repository as failing and exclude it from any future
	    # usage in this session.

	    set loc [$repo cget -location]
	    set badr($loc) .
	    $self Log error $loc
	    $self Log error "        $result"
	    $self Log error "        while retrieving list of instances"
	    after idle [mymethod RegenRepositories]
	    return
	}

	# Add the instances to the global list and the origin
	# cache. This may trigger a redisplay of the list of the
	# chosen and available packages.

	foreach instance $result {
	    # instance = list (entity name ver arch isprofile)

	    teapot::instance::norm    instance
	    $self NewInstance        $instance
	    $self UpdateOrigin $repo $instance
	}

	# Always recalculate the display, instances may have become
	# invisible (no origin anymore, f.e.).

	$self RecalcAvailable

	# Unlock badness and recalc
	incr _popending -1
	if {$_popending <= 0} {$self oDone}
	return
    }

    method ClearOriginCache {} {
	log::debug "- Clearing origin cache."

	$self MoreBad ; # While origin is computed
	# we lock wrapping.

	set _podone 0
	array unset _porigin   *
	array unset _pinprefix *
	$_cpkgorig clear

	log::debug "  Invalidated queries in flight."
	incr _poepoch
	return
    }

    method oNotDone {n} {
	log::debug "Origins are in flux due to rescan, lock dependencies, wrapping"

	set _podone    0
	set _popending $n
	$self MoreBad

	# ... Tell UI.
	$self raise origin-flux
	return
    }
    method oDone {} {
	log::debug "Origins are done, compute exact missing for chosen"

	set _podone 1
	set _popending 0

	# Force this, otherwise we can get them while we compute
	# missing (it apparently oopen a small eventloop
	# somewhere). This would cause us to compute bad stati despite
	# the origins now stable. Chosen as well, otherwise the list
	# might be out of date

	$self CalcUnresolved
	$self CalcChosen

	set n 0
	foreach i $_ichosen {
	    incr n [$self Missing $i]
	}
	$self ClearBad
	$self MoreBad [array size _brefr]
	$self MoreBad $n

	# ... Tell UI.
	$self raise origin-stable
	return
    }

    method FormattedOrigin {instance} {
	return [join [lsort -dict [struct::list map \
			  [$self GetOrigins $instance] \
			       [myproc FormatLocation]]] \
		    " "]
    }

    proc FormatLocation {r} {$r cget -location}

    method HasOrigin {instance} {
	return [llength [array names _porigin [list * $instance]]]
    }

    method GetOrigins {instance} {$_cpkgorig get $instance}

    method Missing {instance} {
	expr {![llength [$self GetOrigins $instance]]}
    }

    method OriginInPrefix {instance} {
	$self GetOrigins   $instance ; # Force validity of _pinprefix
	return $_pinprefix($instance)
    }

    method InitOriginCache {} {
	if {$_cpkgorig ne ""} return
	log::debug "- Initialize instance origin cache"
	set _cpkgorig [as::cache::sync ${selfns}::cpkgorig \
			   [mymethod FindOrigins]]
	return
    }

    method FindOrigins {instance} {
	# Side effect: Compute data for _pinprefix as well.

	set origins {}
	set inprefix 0
	foreach key [array names _porigin [list * $instance]] {
	    set repository [lindex $key 0]
	    lappend origins $repository

	    # We consider packages provided by an in-'mem' repository
	    # as prefix packages too. The only in-mem repo we have is
	    # the tclapp::pkg::VirtualBase, containing Tcl itself.

	    if {
		([$repository info type] eq "::repository::prefix") ||
		([$repository info type] eq "::repository::mem")
	    } {
		set inprefix 1
	    }
	}
	set _pinprefix($instance) $inprefix
	return $origins
    }

    method UpdateOrigin {repo instance} {
	log::debug "UpdateOrigin (($instance) = $repo)"

	set _porigin([list $repo $instance]) .
	$_cpkgorig clear $instance
	$self RedisplayAll
	return
    }

    # ### ### ### ######### ######### #########
    ## Track and cache package dependency completeness.
    ## - For main table of all available packages.

    # Note: Changes to the list of allowed architectures,
    #       incoming new/changed dependency information require
    #       full recalculation, i.e. clearing the cache.

    method IsComplete {instance} {
	set c [$_cpkgcomplete get $instance]

	log::debug IsComplete\ ($instance)\ =\ $c
	return $c
    }

    method IsChosenComplete {instance} {

	# For a chosen package instance its completeness flag is
	# computed slightly differently from available instances. We
	# have to take the border between chosen and not chosen
	# packages into a account: A chosen instance is also
	# incomplete if one of its references is not chosen.

	# Note how this criterion is _NOT_ recursive. If all
	# references of the chosen instance are satisfied then we
	# consider it complete, even if the instances refered
	# themselves are not. In other words, the table of chosen
	# instances shows only the incomplete leafs. Whereas the main
	# table shows everything as incomplete which has somethng
	# missing, even if 10 levels down.

	##
	# We first get the regular flag. Instances incomplete by that
	# strict criterion we can pass through. Only complete
	# instances need the border check.

	if !{[$self IsComplete $instance]} {
	    #puts INCOMPLETE/strict\t$instance
	    return 0
	}

	# Note: We know that the instance is not missing, otherwise it
	# would not have been complete according to the strict
	# criterion. So we go directly to the references. We also know
	# that if there requirements they will have matching
	# instances. Otherwise, again, the strict check would have
	# already signaled it as incomplete.

	# The database of chosen instances is checked. It is smaller,
	# and if we have a suitable match we know that the border is
	# good. And if nothing is in there we also know that the
	# border is bad, and thus we do not have to check the large
	# master database either.

	foreach ref [$self GetRequired $instance] {
	    set matches [$dbc deref $instance $ref $_archpattern]

	    if {[llength $matches]} continue

	    # Nothing suitable in the choice db means that this
	    # instance is not complete.

	    #puts INCOMPLETE/ref\t$instance\t($ref)
	    return 0
	}

	#puts OK/all-satisfied\t$instance
	return 1
    }


    method ClearCompleteCache {} {
	log::debug Clear/Cache/Completeness
	$_cpkgcomplete clear
	$self ClearStatusCaches
	return
    }

    method InitCompleteCache {} {
	if {$_cpkgcomplete ne ""} return
	log::debug "- Initialize instance dependencies cache"
	set _cpkgcomplete [as::cache::async ${selfns}::cpcomplete \
			       [mymethod xxCalcComplete] \
			       [mymethod Recomplete] \
			      -default 1]
    }

    method Recomplete {cache instance iscomplete} {
	$_cstatchosen clear $instance
	$_cstatavail  clear $instance
	$self RedisplayAll
	return
    }

    method xxCalcComplete {cache instance} {
	array set visting {}
	log::debug "_________________________________"
	set c [$self xCalcComplete $cache $instance visiting]
	log::debug "_________________________________"
	return $c
    }

    method xCalcComplete {cache instance vv} {
	upvar 1 $vv visiting
	log::debug "CalcComplete ($instance) ..."
	set c [$self CalcComplete $cache $instance visiting]
	log::debug "CalcComplete ($instance) = $c"
	return $c
    }

    method CalcComplete {cache instance vv} {
	upvar 1 $vv visiting

	# An instance which is not found in any repository, i.e. is
	# missing, is also incomplete. This setting automatically
	# ensures that references to missing packages cause
	# incompleteness of the refering instance.

	if {[$self Missing $instance]} {
	    $cache set $instance 0
	    return 0
	}

	# Ok, the instance actually comes from somewhere, so we can
	# determine its dependencies. Without an origin, well, s.a.

	set dependencies [$self GetRequired $instance]

	# An instance without any dependencies is complete.

	if {![llength $dependencies]} {
	    $cache set $instance 1
	    return 1
	}

	# For a package with dependencies we find all instances which
	# match the reference and take the best completeness result.
	# If and only if we find an incomplete reference this instance
	# is incomplete as well.

	# Note that recommendations do not matter.

	foreach ref $dependencies {log::debug "\t* $ref"}

	set visiting($instance) .

	foreach ref $dependencies {
	    set c [$self RefComplete $instance $ref $cache visiting]

	    # Ignore references leading into a cycle
	    if {$c == 2} continue
	    if {!$c} {
		$cache set $instance 0
		return 0
	    }
	}

	unset visiting($instance)

	# Nothing incomplete was found, this instance is complete too.

	$cache set $instance 1
	return 1
    }

    method RefComplete {instance ref cache vv} {
	upvar 1 $vv visiting

	log::debug \tRefComplete,\ checking\ $ref

	set matches [$dba deref $instance $ref $_archpattern]

	# An unresolvable reference indicates incompleteness
	if {![llength $matches]} {
	    log::debug "\t= $ref - No matching instance found"
	    return 0
	}

	# We consider us complete if at least one of the matches is
	# complete. Note the recursion through the cache!

	foreach mi $matches {
	    # Are we in a cyclic dependency ?
	    # If yes we ignore it in the computation.

	    if {[info exists visiting($mi)]} {
		log::debug "\t= $ref - Cycle detected. Ignoring this reference"
		return 2
	    }

	    if {[$self xCalcComplete $cache $mi visiting]} {return 1}
	}

	if {0} {
	    foreach mi $matches {
		if {[$self IsComplete $mi]} {return 1}
	    }
	}

	return 0
    }

    # ### ### ### ######### ######### #########
    ## Track changes to the database of package dependencies

    method GetRequired    {instance} {$_cpkgreq get $instance}
    method GetRecommended {instance} {$_cpkgrec get $instance}

    method InitDepCache {} {
	if {$_cpkgreq ne ""} return
	log::debug "- Initialize instance dependencies cache"
	set _cpkgreq [as::cache::async ${selfns}::cpreq \
			   [mymethod FindDep require]   [mymethod Redependency require]]
	set _cpkgrec [as::cache::async ${selfns}::cprec \
			   [mymethod FindDep recommend] [mymethod Redependency recommend]]

	#set _gpkgrec [struct::graph ${selfns}::grec]
	return
    }

    method FindDep {key cache instance} {
	if {$_sync} {$self FindDep/Sync $key $cache $instance ; return}

	log::debug "FindDep ($key ($instance) $cache)"

	# Re-query the repositories the package is from for changed
	# dependencies

	foreach r [$self GetOrigins $instance] {
	    $r value \
		-command [mymethod GotDep $r $key $cache $instance] \
		$key [teapot::instance::2spec $instance]
	}

	# If we have nothing the default returned by the cache (empty
	# string) is good enough. And the queries above may change
	# this in the future.

	if {![info exists _pdep($instance,$key)]} return

	# Deliver existing information, may be updated in the future.

	$cache set $instance $_pdep($instance,$key)
	return
    }

    method FindDep/Sync {key cache instance} {
	log::debug "FindDep/Sync ($key ($instance) $cache)"

	# Re-query the repositories the package is from for changed
	# dependencies

	foreach r [$self GetOrigins $instance] {
	    set refs [$r sync value $key [teapot::instance::2spec $instance]]
	    $self GotDep $r $key $cache $instance 0 $refs
	}

	# If we have nothing the default returned by the cache (empty
	# string) is good enough. And the queries above may change
	# this in the future.

	if {![info exists _pdep($instance,$key)]} return

	# Deliver existing information, may be updated in the future.

	$cache set $instance $_pdep($instance,$key)
	return
    }

    method GotDep {repo key cache instance code result} {
	# %NOTE%   Ignoring failures.
	# %TODO%   Handle this better.
	# %FUTURE% Record failures somewhere for view by the user.
	# %FUTURE% Maybe a blinking red pseudo-LED when it happens.

	if {$code} {
	    set loc [$repo cget -location]
	    ## set badr($loc) . - Might be temporary ... No exclusion for now.
	    $self Log warning $loc
	    $self Log warning "        $result"
	    $self Log warning "        while retrieving dependencies ($key, $instance)"
	    return
	}

	log::debug "GotDep (($instance).$key = $result)"

	# We assume that whereever an instance is coming from it will
	# have the same dependencies. Except that some rpeositories do
	# not know about them, so the empty list of dependencies is
	# special. It has to be ignored, not cause us to delete the
	# known dependencies.

	set result [lsort -uniq $result]

	if {
	    ![llength $result] ||
	    ([info exists _pdep($instance,$key)] &&
	    ($result eq $_pdep($instance,$key)))
	} return
       
	# Extend our knowledge, and the cache. This also triggers the
	# code updating the dependency graph, and through that the
	# redisplay.

	set _pdep($instance,$key) $result
	$cache set $instance $result
	return
    }

    method Redependency {dep cache instance references} {
	# args =         dep cache key      value

	log::debug "Redependency (($instance).$dep = $references"

	# No graph for recommend stuff yet.
	if {$dep eq "recommended"} return

	# Force recalc of the complete status.

	# When in sync mode (add dependencies) only the display has to
	# change. The cache mus not clear, it is being filled!

	if {$_sync} {
	    $self RedisplayAll
	    return
	}

	$self ClearCompleteCache
	$self RedisplayAll

	# Do not need the graph for this !!

	return
    }


    # ### ### ### ######### ######### #########
    ## Make and track changes to the database of package descriptions.

    method FormattedDesc {instance} {
	return [string trim [join [$self GetDescription $instance] " "]]
    }

    method GetDescription {instance} {$_cpkgdesc get $instance}

    method InitDescCache {} {
	if {$_cpkgdesc ne ""} return
	log::debug "- Initialize instance description cache"
	set _cpkgdesc [as::cache::async ${selfns}::cpdesc \
			   [mymethod FindDesc] [mymethod RedisplayAll]]
	return
    }

    method FindDesc {cache instance} {
	# Re-query the repositories the package is from for changed
	# descriptions.

	foreach r [$self GetOrigins $instance] {
	    $r value \
		-command [mymethod GotDescription $r $cache $instance] \
		description [teapot::instance::2spec $instance]
	}

	# If we have nothing the default returned by the cache (empty
	# string) is good enough. And the queries above may change
	# this in the future.

	if {![info exists _pdesc($instance)]} return

	# Deliver existing information, may be updated in the future.

	$cache set $instance $_pdesc($instance)
	return
    }

    method RedisplayAll {args} {
	# Arguments are present only when called from as::cache::async,
	# key&value. This is ignored.

	$_mavchosen arm
	$_mavavail  arm
	return
    }

    method GotDescription {repo cache instance code result} {
	# %NOTE%   Ignoring failures.
	# %TODO%   Handle this better.
	# %FUTURE% Record failures somewhere for view by the user.
	# %FUTURE% Maybe a blinking red pseudo-LED when it happens.

	if {$code} {
	    set loc [$repo cget -location]
	    ## set badr($loc) . - Might be temp.
	    $self Log warning $loc
	    $self Log warning "        $result"
	    $self Log warning "        while retrieving description ($instance)"
	    return
	}

	# Ignore items we already know about.

	if {
	    [info exists _pdesc($instance)] &&
	    [lsearch -exact $_pdesc($instance) $result] >= 0
	} return

	# Extend our knowledge, and the cache. This also triggers the
	# redisplay.

	lappend _pdesc($instance) $result
	$cache set $instance $_pdesc($instance)
	return
    }

    # ### ### ### ######### ######### #########
    ## Track changes to instance stati.

    method FormattedChosenStatus {instance} {
	$_cstatchosen get $instance
    }

    method FormattedAvailStatus {instance} {
	$_cstatavail get $instance
    }

    method ClearStatusCaches {} {
	log::debug Clear/Cache/FormattedStati
	$_cstatchosen clear
	$_cstatavail  clear
	return
    }

    method ClearStatusCacheChosen {} {
	log::debug Clear/Cache/FormattedStati/Chosen-only
	$_cstatchosen clear
	return
    }

    method InitStatusCaches {} {
	if {$_cstatavail ne ""} return
	log::debug "- Initialize instance status caches"
	set _cstatchosen [as::cache::sync ${selfns}::cstatchosen [mymethod ChosenStatus]]
	set _cstatavail  [as::cache::sync ${selfns}::cstatavail  [mymethod AvailStatus]]
	return
    }

    method ChosenStatus {instance} {
	# Display of chosen package instances.
	# We have the following stati around
	#
	# (1) Instance complete              y/n
	# (2) Instance origin is prefix file y/n
	# (3) Instance is missing            y/n
	# (4) Instance is used               y/n

	# All four stati are used. To fit them all into
	# the cell we use single-character abbreviations.

	append status [expr {[$self Missing          $instance] ? "M" : "-"}]
	append status [expr {[$self OriginInPrefix   $instance] ? "P" : "-"}]
	append status [expr {[$self IsChosenComplete $instance] ? "-" : "I"}]

	# %TODO% Compute and integrate the Used status ...
	# %NOTE% Iff we add this functionality at all.

	return $status
    }

    method AvailStatus {instance} {
	# Display of available package instances.
	# We have the following stati around
	#
	# (1) Instance complete              y/n
	# (2) Instance origin is prefix file y/n
	# (3) Instance is missing            y/n
	# (4) Instance is used               y/n
	#
	# Of these (2) and (3) are irrelevant for the display because
	# such instances are kept hidden, i.e. are not shown. And (4)
	# is irrelevant as the 'usage' is defined on the instances
	# chosen for wrapping, and not the whole available set.
	#
	# This leaves 'completeness' as the status to show.

	log::debug AvailStatus($instance)
	return [expr {[$self IsComplete $instance] ?
		      "" :
		      "Incomplete"}]
    }

    proc Missing {origins} {
	if {![llength $origins]} {return M}
	return -
    }

    proc OSpecials {origins} {
	if {![llength $origins]} {return -}
	set archive 0
	foreach r $origins {
	    if {[$r info type] eq "::repository::prefix"}  {return P}
	    if {[$r info type] eq "::repository::localma"} continue
	    if {[$r info type] eq "::repository::tap"}     continue
	    set archive 1
	}      
	if {$archive} {return A}
	return -
    }

    # ### ### ### ######### ######### #########
    ## Track changes to the list of allowed architectures

    method RegenArchitectures {} {
	log::debug RegenArchitectures

	array set patterns {}
	foreach a $_arch {
	    foreach p [platform::patterns $a] {
		set patterns($p) .
	    }
	}

	set newpat [lsort [array names patterns]]
	if {$newpat eq $_archpattern} return

	set _archpattern     $newpat
	array unset _archset *
	array set   _archset [array get patterns]

	# Triggering view of chosen as well, status change is possible
	# Clearing stati of chosen to force their re-calculation.

	$self ClearCompleteCache
	$_mavchosen arm

	$self RecalcAvailable

	# We check unresolved references as well, as their match
	# process is influenced by the architectures chosen by the
	# user.

	$self RecalcUnresolved
	return
    }

    proc dictsort {dict} {
	array set a $dict
	set out [list]
	foreach key [lsort [array names a]] {
	    lappend out $key $a($key)
	}
	return $out
    }

    # ### ### ### ######### ######### #########
    ## Make and track changes to the global list of packages.

    method NewInstance {instance} {
	log::debug "NewInstance $instance"

	if {[$dba enter $instance]} {
	    # Truly new packages instances have become known. This
	    # forces us to try and resolve as many of the references
	    # with bogus package instances shown in the table of
	    # chosen packages as we can. After all the new instances
	    # are known.

	    $self RecalcUnresolved
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Track changes to the set of chosen package instances
    # This is the subset of all instances which was chosen by the user
    # for wrapping. Missing instances, bad architectures, etc. are
    # allowed and just reflected in the instance status

    method RecalcChosen {} {
	log::debug "RecalcChosen ..."

	$_rqchosen rq ; # CalcChosen
	return
    }

    method CalcChosen {} {
	log::debug "CalcChosen"

	set new [SortInstances [array names _pchosen]]

	# Ignore non-changes.
	if {$new eq $_ichosen} return

	set _ichosen $new
	$_mavchosen arm
	return
    }

    method RecalcUnresolved {} {
	log::debug "RecalcUnresolved ..."

	# Ignore this if we do not have any unresolved bogus
	# references sitting around. Otherwise schedule the
	# recalculation for a convenient quiet time.

	if {![array size _brefr]} return
	$_rqbref rq
    }

    method CalcUnresolved {} {
	log::debug "CalcUnresolved (#[array size _brefr])"

	# Fake package context for the search. All of entity type,
	# name, and version are not relevant. Only the architecture,
	# 'tcl', is needed for the call of 'deref' below. This value
	# forces the use of _archpattern.

	set dummy [teapot::instance::cons package _ 0 tcl]

	foreach ref [array names _brefr] {
	    set matches [$dba deref $dummy $ref $_archpattern]

	    log::debug [list $dba deref $dummy $ref $_archpattern => $matches]

	    # Keep anything which is still not resolving
	    if {![llength $matches]} continue

	    # We found actual instances for the reference. Replace the
	    # shown bogus instance with them.

	    log::debug "replace placeholder"

	    $self remove instance $_brefr($ref)

	    foreach mi $matches {
		$self add instance $mi
	    }
	}

	log::debug "            to (#[array size _brefr])"
	return
    }

    # ### ### ### ######### ######### #########
    ## Track changes to the list of available package instances
    # This is the subset of all instances which are not missing, not
    # chosen, and pass the architecture filtering.

    method RecalcAvailable {} {
	log::debug "RecalcAvailable ..."

	$_rqavail rq ; # CalcAvailable
	return
    }

    method CalcAvailable {} {
	log::debug "CalcAvailable"

	set instances [$dba list]

	log::debug "             # [llength $instances]"

	set result {}
	foreach instance $instances {
	    teapot::instance::split $instance __ __ __ plat

	    # Do not show instances which
	    # - are chosen for wrapping
	    # - do not have an allowed architecture
	    # - are not provided by any repository
	    # - are provided by the prefix file

	    if {[info exists  _pchosen($instance)]} continue
	    if {![$self ArchVisible    $instance]}  continue
	    if {![$self HasOrigin      $instance]}  continue
	    if {[$self  OriginInPrefix $instance]}  continue

	    lappend result $instance
	}

	log::debug "          to # [llength $result]"

	# Final sorting, then trigger redisplay through view change
	# notification.

	set new [SortInstances $result]

	# Ignore non-changes.
	if {$new eq $_iavailable} return

	log::debug "          Changed"

	set _iavailable $new
	$_mavavail arm
	return
    }

    method ArchVisible {instance} {
	teapot::instance::split $instance __ __ __ a
	if {
	    [llength $_archpattern] &&
	    ![info exists _archset($a)]
	} {
	    return 0
	}
	return 1
    }

    # Stolen from the TEAPOT client app (see client.tcl, GenListing)
    proc SortInstances {instances} {
	return [lsort -dict -index 1 \
		    [lsort -dict -index 2 \
			 [lsort -dict -index 3 $instances]]]
    }

    # ### ### ### ######### ######### #########

    variable _sync 0

    method SyncOn {} {
	#puts SYNC/on
	set _sync 1
	$_cpkgcomplete configure -now 1
	$_cpkgreq      configure -now 1
	$_cpkgrec      configure -now 1

	# descriptions are async as well, but not relevant when doing
	# sync access (for transtivite closure of dependencies), so we
	# ignore them.

	return
    }

    method SyncOff {} {
	#puts SYNC/off
	set sync 0
	$_cpkgcomplete configure -now 0
	$_cpkgreq      configure -now 0
	$_cpkgrec      configure -now 0

	# descriptions are async as well, but not relevant when doing
	# sync access (for transtivite closure of dependencies), so we
	# ignore them.

	return
    }

    method VTrigger {view} {
	log::debug "Trigger ($view)"
	$view trigger
	return
    }

    # ### ### ### ######### ######### #########
    ## Track bad-ness state of the chosen set of packages.

    variable badcounter 0
    method MoreBad {{n 1}} {
	incr badcounter $n
	#puts +/$badcounter/
	if {$badcounter <= 0} return
	Signal 0 "Missing packages"
	return
    }
    method LessBad {} {
	incr badcounter -1
	#puts -/$badcounter/
	if {$badcounter > 0} return
	Signal 1 ""
	set badcounter 0
	return
    }
    method ClearBad {} {
	set badcounter 0
	#puts c/$badcounter/
	Signal 1 ""
	return
    }

    proc Signal {ok msg} {
	upvar 1 options options
	if {$options(-variable) eq ""} return
	upvar \#0 $options(-variable) state
	set state(pkg,msg) $msg
	set state(pkg,ok)  $ok
	return
    }

    # ### ### ### ######### ######### #########

    method Log {level text} {
	if {![llength $options(-log)]} return
	uplevel \#0 [linsert $options(-log) end log $level $text]
	return
    }

    # ### ### ### ######### ######### #########

    variable _sig {}
    method signal {o} {set    _sig $o ; return}
    method raise {x}  {$_sig raise $x ; return}

    # ### ### ### ######### ######### #########
    ## Data structures - The database.

    ##
    # - Views seen by the UI, and used to show the main information
    #   about chosen and available packages.
    # - Delay windows for triggering view updates i.e. change
    #   notifications. Reduces UI flicker due to excessive update
    #   activity.

    variable _vchosen  {} ; # object (pkgman::view::chosen)
    variable _vavail   {} ; # object (pkgman::view::avail)

    variable _mavchosen {} ; # object (mafter)
    variable _mavavail  {} ; # object (mafter)

    ##
    # - List of project specific archives

    variable _aextern {} ; # list (location ...)

    ##
    # - List of repositories in use. Derived from
    #   _aextern. Regenerated immediately when the base information
    #   changed. See "RegenRepositories".

    variable _repositories {} ; # list (object (repository) ...)

    ##
    # - List of all known package instances. It does not matter
    #   whether they are known to the current set of repositories or
    #   not. They might have been, or are referenced by the current
    #   project. Not being known is simply reflected in the status.
    #   Because of this this structure can only grow during a session.
    #
    #   The position in the list (i.e. index) is the "global id" of
    #   the package instance.
    #
    # - Translation from instances to their "global id" (short: gid).

    variable dba {} ; # object (pkg::mem)
    variable dbc {} ; # object (pkg::mem)

    ##
    # - Architecture codes, for filtering the list of available
    #   instances.
    # - The set of patterns generated from the basic codes.

    variable _arch               {} ; # list (arch ...)
    variable _archpattern        {} ; # list (arch ...)
    variable _archset     -array {} ; # array (arch -> '.')

    ##
    # - List of available package instances. Items are instances, to
    #   allow sorting (increasing by name, increasing by architecture,
    #   decreasing by version)
    # - Trigger object for recalculations of this list.

    variable _iavailable {} ; # list (instance ...)
    variable _rqavail    {} ; # object (req)

    ##
    # - Set and list of chosen package instances. Items are
    #   instances, to allow sorting. See _iavailable above as well.
    # - Trigger object for recalculations of this list.
    # - Set of references with bogus package instances shown in the
    #   table of chosen. Whenenver the set of repositories changes we
    #   maybe able to resolve them into actual instances.

    variable _ichosen          {} ; # list (instance ...)
    variable _pchosen   -array {} ; # array (instance -> '.')
    variable _rqchosen         {} ; # object (req)
    variable _brefr     -array {} ; # array (reference -> instance)
    variable _brefi     -array {} ; # array (instance  -> reference)
    variable _rqbref           {} ; # object (req)

    ##
    # Package origins.
    # - Set of repository x instance.
    #   Cleared whenever the list of repositories is changed.
    # - Associated epoch counter. It is possible that a wave of
    #   regeneration is in progress when the list of repositories is
    #   changed again, clearing the already collected partial
    #   information. The increased epoch counter is used to prevent
    #   the old weave from trying to put their outdated information
    #   into the set.
    #
    # - A cache of formatted origin strings, the final form used by
    #   the view (and tooltips).
    # - An array as cache for the 'comes-from-prefix' flag, computed
    #   as sideeffect of getting the origins.

    variable _porigin -array   {} ; # array (object (repository) x instance -> '.')
    variable _poepoch          0  ; # integer
    variable _cpkgorig         {} ; # object (as::cache::sync)
    variable _pinprefix -array {} ; # instance -> boolean 'comes-from-prefix'
    variable _popending        0  ; #
    variable _podone           0  ; #

    ##
    # Package descriptions.
    # - Per instance a list of descriptions. This information is
    #   updated from new repositories, but never cleared. This ensures
    #   both that new information is used appropriately, and that
    #   nothing is lost when repositories are excluded from the
    #   search.
    #
    #   The contents are computed lazily however, .i.e on-demand, when
    #   requested by the user interface.

    variable _pdesc -array {} ; # array (instance -> list (string ...))
    variable _cpkgdesc     {} ; # object (as::cache::async)

    ##
    # Package dependencies
    # - A per instance x {req,rec} set of dependencies.
    # - 2 async caches duplicating the info.
    #   -- not sure if _pdep is thus needed.
    #   -- oh, we cannot query and test the cache.
    #   -- for that the _pdep backend is needed.

    # - Graphs of expanded references, between instances. Nodes are
    #   instances. Attributes for stati.
    #   - complete y/n
    #   - complete y/n per reference!
    #   - mark arcs with the reference

    variable _pep -array {} ; # array (instance x {require,recommended} -> list (pkg-reference ...))
    variable _cpkgrec    {} ; # object (as::cache::async)
    variable _cpkgreq    {} ; # object (as::cache::async)

    #variable _gpkgrec    {} ; # object (struct::graph)

    ##
    # - Main status caches (avail, chosen)

    variable _cstatavail   {} ; # object (as::cache::sync)
    variable _cstatchosen  {} ; # object (as::cache::sync)
    variable _cpkgcomplete {} ; # object (as::cache::async)

    proc blank {s} {
	regsub -all {[^ 	]} $s { } s
	return $s
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Helper classes. The view implementations, delegating requests to
## the main manager as needed ("size", and "get". All others can be
## handled locally).

snit::type ::pkgman::view::chosen {
    constructor {pm} {
	set _pm $pm
	set view [view ${selfns}::v -source $self -partof $self]
	return
    }

    destructor {
	if {$view ne ""} {$view destroy}
	return
    }

    component view

    # View API commands.
    delegate method * to view

    # API implementation by (view api object reflects most back to us
    # again).

    method names    {}               {return {status origin name version arch desc __tag}}
    method size     {}               {$_pm chosen size}
    method isview   {attr}           {return 0}
    method isstring {attr}           {return 1}
    method set      {row attr value} {return -code error "$type $self is read-only"}
    method get      {row attr}       {$_pm chosen get $row $attr}
    method open     {row attr}       {return -code error "$self open ($attr): Not a subview"}

    variable _pm
}

snit::type ::pkgman::view::avail {
    constructor {pm} {
	set _pm $pm
	set view [view ${selfns}::v -source $self -partof $self]
	return
    }

    destructor {
	if {$view ne ""} {$view destroy}
	return
    }

    component view

    # View API commands.
    delegate method * to view

    # API implementation by (view api object reflects most back to us
    # again).

    method names    {}               {return {origin name version arch desc}}
    method size     {}               {$_pm avail size}
    method isview   {attr}           {return 0}
    method isstring {attr}           {return 1}
    method set      {row attr value} {return -code error "$type $self is read-only"}
    method get      {row attr}       {$_pm avail get $row $attr}
    method open     {row attr}       {return -code error "$self open ($attr): Not a subview"}

    variable _pm
}

# ### ### ### ######### ######### #########
## Ready

package provide pkgman 1.0
