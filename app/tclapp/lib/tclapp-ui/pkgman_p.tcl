# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgman_p.tcl --
# -*- tcl -*-
#
#	Display available packages, chosen packages
#	Operations on both.
#
# Copyright (c) 2006-2007 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Docs

# configuration set/get methods for connection to containing wrapper
# and communication of state (save/load project).

# Need callback for reporting ok yes/no information, plus error
# messages.

# ### ### ### ######### ######### #########
## Requisites

package require snit                  ; # Tcllib, OO core.
package require tile                  ; # Theming
package require svtable               ; # Viewing the package tables
package require widget::dialog        ; # Tklib, simple dialog
package require pkgman::scanfiles     ; # AS package  | Pkg mgmt: Scanning files for requested packages
package require logger
package require tclapp::prjrepo       ; # AS package  | Pkg mgmt: Repository selection.
package require widget::toolbar 1.2   ; # Earliest version with item identification as itemid
package require widget::dialog
package require tclapp::tappkg
package require pkgman::plist
package require struct::list
package require struct::set

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::pkgman::packages
snit::widget          ::pkgman::packages {
    hulltype ttk::frame

    # ### ### ### ######### ######### #########
    ## API. Definition

    option -variable {}
    option -log      {}
    option -config   {}

    # ### ### ### ######### ######### #########
    ## API. Implementation

    constructor {args} {
	::tclapp::pkg::reinitcmd [mymethod RepoChanged]

	# DEBUG # $hull configure -relief raised -bd 2 -bg coral

	$self MakeWidgets
	$self PresentWidgets

	# Handle initial options.
	$self configurelist $args
	$self ToolbarState
	return
    }

    destructor {
	return
    }

    # ### ### ### ######### ######### #########

    # ### ### ### ######### ######### #########

    method MakeWidgets {} {
	# Widgets to show

	#%TODO% Images/Icons

	widget::toolbar $win.tb -separator bottom
	foreach {btn label method sep img} {
	    scanf   "Scan Files"     Add/ScanFiles  0 arrow_rotate_clockwise
	    dep     "Add Dep (Req)"  Add/Depends    0 package_go
	    depall  "Add Dep (Rec)"  Add/DependsAll 0 package_go_all
	    add     "Add"            Add            0 package_add
	    rem     "Remove"         Remove         0 package_delete
	    {}      {}               {}             {} {}
	    repo    "Repositories"   Repositories   0 feed_edit
	} {
	    if {$btn eq {}} {
		$win.tb add space
		continue
	    }

	    if {$img ne ""} {
		$win.tb add button $btn \
		    -image     [image::get $img]  \
		    -command   [mymethod $method] \
		    -separator $sep
	    } else {
		$win.tb add button $btn \
		    -text      $label \
		    -command   [mymethod $method] \
		    -separator $sep
	    }
	}
	#$win.tb add space

	# Table of chosen packages and package references.

	page $win.ch \
	    -ondel [mymethod Remove] \
	    -onsel [mymethod OnSelection]
	return
    }

    method PresentWidgets {} {
	# Layout ... Paned window

	grid $win.tb -in $win -column 0 -row 0 -sticky swen -padx 1m -pady 1m
	grid $win.ch -in $win -column 0 -row 1 -sticky swen -padx 1m -pady 1m

	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 0
	grid rowconfigure    $win 1 -weight 1

	tipstack::def [list \
		$win      "Management of Packages to wrap" \
		$win.ch   "List of packages to wrap" \
		\
		[$win.tb itemid scanf]  "Scan files for required packages" \
		[$win.tb itemid dep]    "Add required dependent packages" \
		[$win.tb itemid depall] "Add required and recommended dependent packages" \
		[$win.tb itemid add]    "Add packages from list of all packages" \
		[$win.tb itemid rem]    "Remove selected packages" \
		[$win.tb itemid repo]   "Edit list of per-project TEAPOT repositories" \
	   ]
	return
    }

    # ### ### ### ######### ######### #########
    ## Data structures

    # ### ### ### ######### ######### #########
    ## Button activity.

    # ### ### ### ######### ######### #########
    ## Adding packages to wrap, based on package requirements found in
    ## the chosen files. The button is available only if at least one
    ## file is listed.

    method files {numfiles} {
	if {$numfiles >= 1} {
	    $win.tb itemconfigure scanf -state normal
	} else {
	    $win.tb itemconfigure scanf -state disabled
	}
	return
    }

    method Add/ScanFiles {} {
	# Disabled if the user has no files chosen for wrapping (See
	# method 'files' for where this information comes in).

	if {[$win.tb itemcget scanf -state] eq "disabled"} return

	# Disable button while we are scanning, and activate the progressbar.

	$win.tb itemconfigure scanf -state disabled
	::tcldevkit::appframe::feedback on

	# Get list of files to scan.
	if {[catch {
	    upvar \#0 $options(-variable) state
	    if {![info exists state(files)]} {
		set files {}
	    } else {
		set files {}
		foreach item $state(files) {
		    foreach {code fpath} $item break
		    if {$code ne "File"} continue
		    if {![llength [glob -nocomplain $fpath]]} continue
		    lappend files $fpath
		}
	    }
	}]} {
	    # In case of failure remove the feedback and re-enable the
	    # button for future scans.

	    $win.tb itemconfigure scanf -state normal
	    ::tcldevkit::appframe::feedback off
	}

	if {![llength $files]} {
	    tk_messageBox   \
		-default ok \
		-type    ok \
		-icon    warning \
		-message {No files found to scan} \
		-parent  [$win.tb itemid scanf] \
		-title   {Scan Files - Warning}

	    if 0 {
	    widget::dialog $win.tb.d \
		-parent $win.tb -transient 1 -modal local \
		-type ok -title "Error" -place right \
		-padding [pad labelframe]
	    set frame [$win.tb.d getframe]
	    label $frame.l \
		-text "No files found to scan."
	    pack $frame.l -expand 1 -fill both

	    $win.tb.d display
	    }

	    $win.tb itemconfigure scanf -state normal
	    ::tcldevkit::appframe::feedback off
	    return
	}

	if {[catch {
	    # The object auto-destroys itself when done.
	    pkgman::scanfiles %AUTO% $files \
		[mymethod Add/ScanFiles/New] \
		[mymethod Add/ScanFiles/Done]
	}]} {
	    # In case of failure remove the feedback and re-enable the
	    # button for future scans.

	    $win.tb itemconfigure scanf -state normal
	    ::tcldevkit::appframe::feedback off
	}

	return
    }

    method Add/ScanFiles/New {ref} {
	set v {}
	set t [teapot::reference::type $ref n v]

	$self EnterItem [list $n $v 0 0 [list $n $v]]
	update
	return
    }

    method Add/ScanFiles/Done {code msg} {
	# %TODO% Handle a failure in some way ...
	# Currently it simply goes into the status.

	if {$code} {
	    log::error "ScanFiles($code): \"$msg\""
	}

	# Remove the feedback and re-enable the button for future scans.

	$win.tb itemconfigure scanf -state normal
	::tcldevkit::appframe::feedback off
	return
    }

    # ### ### ### ######### ######### #########
    ## Add
    ## Add packages manually, use the .tap files and teapot
    ##repositories as data source.

    method Add {} {
	$win.tb itemconfigure add -state disabled

	# Result structure:
	#             0    1       2         3
	# list (list (name version isprofile istap))
	# istap (bool)    : true <=> package defined by .tap file
	# isprofile (bool): true <=> package is profile refering others.
	# REF : actual data to use to refer to the package.

	$self CalcAcceptableArchitectures
	# Result is stored in aok, ahint.

	set pkglist [lsort -dict -index 4 -unique \
			 [lsort -dict -index 0 \
			      [lsort -dict -index 1 \
				   [lsort -dict -index 2 -decreasing \
					[lsort -dict -index 3 -decreasing \
					     [concat \
						  [$self TapPackages] \
						  [$self RepoPackages]]]]]]]

	# unique by <name,version> requires separate key. Note that
	# 'lsort -unique' uses the prevalent order of the list and
	# retains only the last of a set of unique elements.  sorting
	# regular after profile, and teapot after tap causes teapot
	# packages to shadow tap packages.

	# Open a modal dialog listing the available packages

	pkgman::plist $win.pkgsel -parent $win -place right \
	    -arch [lsort -dict $aok] -hint $ahint \
	    -title {Select Packages To Wrap} -command [mymethod Enter]

	$win.pkgsel enter $pkglist
	$win.pkgsel display
	destroy $win.pkgsel

	$win.tb itemconfigure add -state normal
	return
    }

    variable pkgs {}
    variable imap -array {}

    method Enter {selection} {
	# selection = list (list (name version))

	foreach s $selection {
	    $self EnterItem $s
	}

	return
    }

    method EnterItem {s {nv {}}} {
	if {$nv != {}} {upvar 1 $nv new}
	set new 0
	if {[struct::set contains $pkgs $s]} return
	struct::set include pkgs $s
	set imap($s) [$win.ch NewItem $s]
	$self ToolbarState
	set new 1
	return
    }

    # ### ### ### ######### ######### #########
    ## Add/Depends

    method Add/Depends {} {
	# Disabled if the user has no packages chosen for wrapping
	# (See method 'packages' for where this information comes in).

	if {[$win.tb itemcget dep -state] eq "disabled"} return
	$win.tb itemconfigure dep -state disabled
	::tcldevkit::appframe::feedback on

	$self Log notice {Add Required Dependencies}

	$self TraceDependencies required $pkgs
	return
    }

    method Add/DependsAll {} {
	if {[$win.tb itemcget depall -state] eq "disabled"} return
	$win.tb itemconfigure depall -state disabled
	::tcldevkit::appframe::feedback on

	$self Log notice {Add Required & Recommended Dependencies}

	$self TraceDependencies all $pkgs
	return
    }

    method ToolbarState {} {
	# Called whenever something changed which affects toolbar
	# state (initial, new packages, removed packages, repo list
	# changed).

	$self RemState
	$self DepState
	return
    }

    method DepState {} {
	set dr [$win.tb itemid dep]
	set da [$win.tb itemid depall]
	set mr "Add required dependent packages"
	set ma "Add required and recommended dependent packages"

	tipstack::pop $dr
	tipstack::pop $da

	if {[struct::set empty $pkgs]} {
	    # Nothing can be traced, so disable.
	    $win.tb itemconfigure dep    -state disabled
	    $win.tb itemconfigure depall -state disabled
	    tipstack::push $dr "$mr\nThe list is empty"
	    tipstack::push $da "$ma\nThe list is empty"

	} elseif {![llength [[$self Repo] archives]]} {
	    # Nothing will be found, so disable.
	    $win.tb itemconfigure dep    -state disabled
	    $win.tb itemconfigure depall -state disabled
	    tipstack::push $dr "$mr\nNo repositories specified"
	    tipstack::push $da "$ma\nNo repositories specified"

	} else {
	    # We have something to trace, and repositories to look
	    # into too, enable.
	    $win.tb itemconfigure dep    -state normal
	    $win.tb itemconfigure depall -state normal
	    tipstack::push $dr $mr
	    tipstack::push $da $ma
	}
	return
    }

    method RemState {} {
	# Change state of toolbar button 'remove' based on number of
	# selected packages in the list.

	set w [$win.tb itemid rem]
	set m "Remove selected packages"

	tipstack::pop $w

	if {[struct::set empty $pkgs]} {
	    # Nothing can be selected, so disable.
	    $win.tb itemconfigure rem -state disabled
	    tipstack::push $w "$m\nThe list is empty"
	} elseif  {![llength [$win.ch Selection]]} {
	    # Nothing is selected, so disable.
	    tipstack::push $w "$m\nNothing is selected"
	} else {
	    # Something is selected, enable.
	    $win.tb itemconfigure rem -state normal
	    tipstack::push $w $m
	}
	return
    }

    method TraceDependencies {mode packages} {
	# packages = list (list (name list(version|range) isprofile istap UKEY))

	# Remove everything which is known to be a .tap based package.
	# We cannot trace their dependencies.

	set x {}
	foreach p $packages {
	    set istap [lindex $p 3]
	    if {$istap} {
		$self Log warning "Ignore TAP package <[lrange $p 0 1]>, no dependency information available"
		continue
	    }
	    lappend x $p
	}

	# What are the repositories to search, what architectures do
	# we have to look for ?

	$self CalcAcceptableArchitectures
	set alist [[$self Repo] archives]

	# Print status

	if {![llength $aok]} {
	    $self Log error "No architectures specified."
	} else {
	    $self Log info [pl [llength $aok] Architecture]
	    foreach a [lsort -dict $aok] {
		$self Log info "    $a"
	    }
	}
	if {![llength $alist]} {
	    $self Log error "No repositories specified"
	} else {
	    $self Log info [pl [llength $alist] Repository Repositories]
	    foreach a $alist {
		$self Log info "    [$a cget -location]"
	    }
	}

	# Cut search/execution short if we know that nothing will be
	# found, either because there are no repositories to find
	# stuff in, or because no architecture is acceptable.

	if {![llength $aok] || ![llength $alist]} {
	    $self TraceComplete
	    return
	}

	$self TraceStep $mode $x
	return
    }

    # Event based execution of dependency tracing, starting with TraceStep
    #
    # -- direct call, possibly conditional
    # ~~ event loop, repository call
    #
    # TraceStep -done----> TraceComplete
    #  ~~r find
    # TraceFind -nothing-> TraceStep /recurse
    #  ~~r require
    # TraceVRequired -!all-> TraceEnter -> TraceStep /recurse
    #  ~~r recommend       >
    # TraceVRecommend ----/

    method TraceStep {mode packages} {
	# Now start the actual tracing, executing in the background
	::tcldevkit::appframe::feednext

	$self Log notice "([format %4d [llength $packages]])__________________________"

	if {![llength $packages]} {
	    $self TraceComplete
	    return
	}

	set head     [lindex $packages 0]
	set packages [lrange $packages 1 end]
	foreach {n v _ _ _} $head break

	$win.ch FlashStatic $imap($head) 1 flashb

	# Phase I. Reference -> Instance

	if {$v == {}} {
	    set ref [teapot::reference::cons $n -is package]
	} else {
	    # v = list(version|range)
	    # Put name in front of this list, and the result is a
	    # proper reference in short notation.

            # 8.5: set ref [teapot::reference::cons $n {*}$v]
	    set ref [eval [linsert $v 0 teapot::reference::cons $n]]
	    lappend ref -is package
	}

	$self Log info "Find <$ref>"

	[$self Repo] find \
	    -command [mymethod TraceFind $mode $head $packages $ref] \
	    $aok $ref
    }

    method TraceFind {mode head packages ref code result} {
	::tcldevkit::appframe::feednext

	# Ignore packages which we were not able locate (error or no instance).
	if {$code || ![llength $result]} {

	    $win.ch FlashStatic $imap($head) 0 flashb

	    $self Log warning "  Not found, ignore"

	    $self TraceStep $mode $packages
	    return
	}

	#puts \tFIND

	# Phase II. Get required/recommended from the instance. The
	# modes comes in here.

	set instance [lindex $result 0]
	teapot::instance::norm instance

	$self Log info "  Found <$instance>, retrieve required dependencies ..."

	[$self Repo] require \
	    -command [mymethod TraceVRequired $mode $head $packages $instance] \
	    $instance
	return
    }

    method TraceVRequired {mode head packages spec code result} {
	::tcldevkit::appframe::feednext

	if {$mode eq "all"} {
	    $self Log info "  Retrieve recommended dependencies as well ..."

	    [$self Repo] recommend \
		-command [mymethod TraceVRecommend $mode $head $packages $result] \
		$spec
	    return
	}

	$self TraceEnter $mode $head $packages $result	
	return
    }

    method TraceVRecommend {mode head packages required code result} {
	::tcldevkit::appframe::feednext

	if {!$code} {
	    set result [struct::set union $required $result]
	} else {
	    set result $required
	}

	$self TraceEnter $mode $head $packages $result	
	return
    }

    method TraceEnter {mode head packages dependencies} {
	# Enter the dependencies, and everything which is new goes
	# into the trace state (packages) as well.

	$self Log info "  [pl [llength $dependencies] dependency dependencies]"

	set hasnew 0
	foreach dep $dependencies {
	    set v {}
	    set t [teapot::reference::type $dep n v]
	    set x [list $n $v 0 0 [list $n $v]]

	    $self EnterItem $x new

	    if {!$new} continue

	    $self Log info "  Added new dependency <$dep>"

	    lappend packages $x
	    set hasnew 1
	}

	if {!$hasnew && [llength $dependencies]} {
	    $self Log info "  No new dependencies."
	}

	$win.ch FlashStatic $imap($head) 0 flashb

	$self TraceStep $mode $packages
	return
    }

    method TraceComplete {} {
	$self Log notice Done

	::tcldevkit::appframe::feedback off
	$self ToolbarState ; # Regenerate proper button states.
	return
    }

    proc pl {n s {p {}}} {
	if {$p eq ""} {set p ${s}s}
	return "$n [expr {($n == 1) ? "$s" : "$p"}]"
    }

    # ### ### ### ######### ######### #########
    ## Remove

    method OnSelection {} {
	$self RemState
	return
    }

    method Remove {} {
	if {[$win.tb itemcget rem -state] eq "disabled"} return
	$win.tb itemconfigure rem -state disabled

	set sel [$win.ch Selection]
	if {[llength $sel]} {
	    struct::set subtract pkgs $sel
	    $win.ch RemoveSelection
	    foreach s $sel {unset imap($s)}
	}
	$win.tb itemconfigure rem -state normal
	$self ToolbarState
	return
    }

    # ### ### ### ######### ######### #########

    method TapPackages {} {
	# Ensure that we have tap error messages, if any.
	::tclapp::tappkg::Initialize 1 ; # 1 = feedback
	$self TapShowErrors ; # If any

	set pkglist {}
	set aokoldstyle [tclapp::tappkg::2platform $aok]

	log::log debug "AOk     = <$aok>"
	log::log debug "AOk'Tap = <$aokoldstyle>"

	foreach p [tclapp::tappkg::listNames] {
	    set token [tclapp::tappkg::locate $p]

	    # Check for acceptable architecture. Only if there is a
	    # set of restrictions. In that case we also have to
	    # convert the old .tap architecture descriptions into a
	    # modern one.

	    if {
		![struct::set empty $aokoldstyle] &&
		![struct::set contains $aokoldstyle \
		      [tclapp::tappkg::platform $token]]} continue

	    set n [tclapp::tappkg::name     $token]
	    set v [tclapp::tappkg::version  $token]
	    set i [expr {$token ne [tclapp::tappkg::source $token]}]

	    lappend pkglist [list $n $v $i 1 [list $n $v]]
	    # list (list (name version isprofile istap UKEY))
	}
	return $pkglist
    }

    method TapShowErrors {} {
	return
	set e [$self TapGetErrors]
	if {$e eq ""} return

	set d $win.pkgerr

	widget::dialog $d -modal local -transient 1 \
	    -parent $win -place center -separator 1 \
	    -title {TclApp TAP Warnings} -type ok

	set frame [$d getframe]

	label $frame.cap -anchor w \
		-text "The following messages were generated while loading the TAP files."

	set sw [eval ScrolledWindow::create $frame.sw \
		-borderwidth 0 -relief sunken -auto both \
		-scrollbar vertical]

	text $sw.t -relief sunken -bg white -width 60 -height 12
	$sw.t insert end  $e

	$sw setwidget $sw.t

	grid $frame.cap -column 0 -row 0 -sticky swen -padx 1m -pady 1m
	grid $sw        -column 0 -row 1 -sticky swen -padx 1m -pady 1m
	grid columnconfigure $frame 0 -weight 1
	grid rowconfigure    $frame 1 -weight 1

	# Interaction ...

	$d display
	::destroy $d
	return
    }

    method TapGetErrors {} {
	if {[::tclapp::tappkg::hasErrors]} {
	    # Manipulate the messages into something more structured.
	    set msg [list]
	    foreach entry  [::tclapp::tappkg::getErrors] {
		foreach l [split $entry \n] {
		    if {[regexp {^([^:]*):(.*)$} $l -> before after]} {
			lappend msg $before "    [string trim $after]"
		    } else {
			lappend msg "    [string trim $l]"
			lappend msg {}
		    }
		}
	    }
	    return [join $msg \n]
	}

	return {}
    }

    # ### ### ### ######### ######### #########

    method RepoPackages {} {
	::tcldevkit::appframe::feedback on

	# list (list (name version isprofile istap))
	set r [$self Repo]

	set res \
	    [struct::list map \
		 [$self FilterArch \
		      [struct::list filter \
			   [$r sync list] \
			   [list ::pkgman::packages::notapp $r]]] \
		 [list ::pkgman::packages::cut $r]]

	::tcldevkit::appframe::feedback off
	return $res
    }

    method Repo {} {
	if {$union == {}} {
	    # Pull all specified repos (per-project, global)
	    # into one aggregate (union repository). The union
	    # automatically delegates queries to its components,
	    # parallel, or serial, depending on the operation.
	    #
	    # Memoize result

	    # The prefix is not used! This for adding external
	    # packages, and whatever is in the prefix is already
	    # present, it doesn't have to be added.

	    repository::union ${selfns}::ru
	    set union ${selfns}::ru

	    upvar \#0 $options(-variable) state
	    set cmd [list $union archive/add]

	    if 0 {
		if {$state(wrap,executable) ne ""} {
		    $self GetPFX $state(wrap,executable) $cmd
		}
	    }
	    if {[info exists state(pkg,repo,urls)] && [llength $state(pkg,repo,urls)]} {
		foreach p $state(pkg,repo,urls) {
		    ::tcldevkit::appframe::feednext
		    $self GetEX $p $cmd
		}
	    }
	    foreach p [pref::devkit::pkgRepositoryList] {
		::tcldevkit::appframe::feednext
		$self GetEX $p $cmd
	    }
	}
	return $union
    }

    variable badr -array {}

    method GetPFX {path cmd} {
	if {[info exists badr($path)]} return
	if {[catch {
	    set r [repository::cache get repository::prefix $path]
	}]} {
	    set badr($path) .
	    $self Log error $msg
	    return
	}
	uplevel \#0 [linsert $cmd end $r]
	return
    }

    method GetEX {path cmd} {
	if {[info exists badr($path)]} return
	set proxy [IsProxy $path]
	if {[catch {
	    if {$proxy} {
		set r [repository::cache open $path -readonly 1 \
			   -config $options(-config) \
			   -notecmd [mymethod Log warning]]
	    } else {
		set r [repository::cache open $path -readonly 1]
	    }
	} msg]} {
	    set badr($path) .
	    $self Log error $msg
	    return
	}

	uplevel \#0 [linsert $cmd end $r]
	return
    }

    proc IsProxy {r} {
	if {[catch {
	    set proxy [expr {[repository::api typeof $r] eq "::repository::proxy"}]
	} msg]} {
	    set proxy 0
	}
	return $proxy
    }

    # ### ### ### ######### ######### #########

    method RepoChanged {} {
	# List of repositories was modified. Regenerate the union.
	# Regeneration is required because the exact number of repos
	# controls the state of some toolbar buttons.

	if {$union != {}} {
	    $union destroy
	    set union {}
	}

	$self Repo
	$self ToolbarState
	return
    }

    variable union {}

    method Log {level text} {
	if {![llength $options(-log)]} return
	uplevel \#0 [linsert $options(-log) end log $level $text]
	return
    }

    # ### ### ### ######### ######### #########

    variable oldpfx {}
    method Prefix {new} {return ; # -- changes not relevant
	# only user FilterArch, always picks up the current value

	if {$new eq $oldpfx} return
	set oldpfx $new
	$self RepoChanged
	return
    }

    # ### ### ### ######### ######### #########

    variable aok {}
    variable ahint {}
    method CalcAcceptableArchitectures {} {
	upvar $options(-variable) state
	set aok   {}
	set ahint {}
	if {![info exists state(pkg,platforms)]} return
	if {![llength    $state(pkg,platforms)]} return
	foreach x $state(pkg,platforms) {
	    struct::set add aok [platform::patterns $x]
	}

	upvar \#0 $options(-variable) state
	if {$state(wrap,executable) eq {}} {
	    set ahint "No prefix defined, used fallbacks."
	} else {
	    set f [expr {[tclapp::misc::isTeapotPrefix $state(wrap,executable)] ?
			 $state(wrap,executable) :
			 [file tail $state(wrap,executable)]}]
	    set ahint "Based on prefix $f"
	}
	return
    }

    method FilterArch {pkglist} {
	# Filter out unwanted platforms.
	if {[struct::set empty $aok]} {return $pkglist}	
	return [struct::list filter \
		    $pkglist \
		    [list ::pkgman::packages::okarch $aok]]
    }

    # ### ### ### ######### ######### #########
    ## Per-project list of repositories

    method Repositories {} {
	# Edit the list of per-project repositories.

	set d $win.repositories

	if {![winfo exists $d]} {
	    tclapp::prjrepo $d \
		-place center -parent $win \
		-command [mymethod Repositories/Changed]
	}

	upvar \#0 $options(-variable) state
	if {![info exists state(pkg,repo,urls)]} {
	    set state(pkg,repo,urls) {}
	}

	$d display $state(pkg,repo,urls)
	return
    }

    method Repositories/Changed {list} {
	# This method is called by win.repositories if and only if the
	# list of repositories was actually changed by the dialog.

	upvar \#0 $options(-variable) state
	set state(pkg,repo,urls) $list
	$self RepoChanged
	return
    }

    # ### ### ### ######### ######### #########

    method getcfg {} {
	set refs {}
	foreach p [lsort -uniq $pkgs] {
	    # p = list (n v tap profile (n v))
	    foreach {n v} $p break
	    if {$v != {}} {
		# Bug 74807. The contents of v are a list of one
		# element. This element can be a plain version number,
		# or a range. To handle the second form, which is a
		# 2-element list, correctly we have to extract element
		# before constructing the reference.

		set ref [teapot::reference::cons $n [lindex $v 0]]
	    } else {
		set ref [teapot::reference::cons $n]
	    }
	    lappend refs [teapot::reference::ref2tcl $ref]
	}
	return [list pkg,references $refs]
    }

    method setcfg {_ refs} {
	# Remove existing references before filling in the new ...

	set pkgs {}
	$win.ch Clear
	array unset imap *

	foreach r $refs {
	    set v {}
	    teapot::reference::type $r n v
	    # p = list (n v tap profile (n v))
	    $self EnterItem [list $n $v 0 0 [list $n $v]]
	}
	return
    }

    # ### ### ### ######### ######### #########
}

proc ::pkgman::packages::notapp {r item} {
    # item = list (entity name version arch isprofile)
    #::tcldevkit::appframe::feednext

    if {[lindex $item 0] eq "package"} {
	return 1
    } elseif {[lindex $item 0] eq "redirect"} {
	# Pull the necessary piece of meta data and check if this
	# redirect is to a package.
	# Note: Because of the repo index cache this is a local op and
	# should be fast enough.
	teapot::instance::norm item
        if {[$r sync value as::type \
		 [teapot::instance::2spec $item]] eq "package"} {
	    return 1
	}
    }
    return 0
}

proc ::pkgman::packages::onlyapp {r item} {
    # item = list (entity name version arch isprofile)
    #::tcldevkit::appframe::feednext

    if {[lindex $item 0] eq "application"} {
	return 1
    } elseif {[lindex $item 0] eq "redirect"} {
	# Pull the necessary piece of meta data and check if this
	# redirect is to an application.
	# Note: Because of the repo index cache this is a local op and
	# should be fast enough.
	teapot::instance::norm item
        if {[$r sync value as::type \
		 [teapot::instance::2spec $item]] eq "application"} {
	    return 1
	}
    }
    return 0
}

proc ::pkgman::packages::cut {r item} {
    # item = list (entity name version arch isprofile)
    # res  = list (name version isprofile istap UKEY)
    #::tcldevkit::appframe::feednext
    foreach {_ n v a i} $item break
    teapot::instance::norm item
    set note [$r sync value as::note [teapot::instance::2spec $item]]
    return [list $n $v $i 0 [list $n $v] $note]
    #            0  1  2  3 4            5
}

proc ::pkgman::packages::cutE {r item} {
    # item = list (entity name version arch isprofile)
    # res  = list (name version arch isprofile istap UKEY)
    #::tcldevkit::appframe::feednext
    foreach {_ n v a i} $item break
    teapot::instance::norm item
    set note [$r sync value as::note [teapot::instance::2spec $item]]
    return [list $n $v $a $i 0 [list $n ${v} $a] $note]
    #            0  1  2  3  4 5                 6
}

proc ::pkgman::packages::okarch {a item} {
    # a = set of good architectures
    # item = 'package' name version arch isprofile
    #if {[struct::set contains $a [lindex $item 4]]} {puts <$item>}
    return [struct::set contains $a [lindex $item 3]]
}

# ### ### ### ######### ######### #########
## Ready

package provide pkgman::packages 1.0
