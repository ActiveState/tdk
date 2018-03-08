# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::metadata::scan 0.1
# Meta platform    tcl
# @@ Meta End

# -*- tcl -*-
# Copyright (c) 2006-2011 ActiveState Software Inc.
#               Tools & Languages
# $Id$

# ### ### ### ######### ######### #########
## Description

# metadata::scan - Generate meta data from the files in a directory.
# Automatic detection of packages, ftheir files, information about
# them. ...

# First iteration of the was the buildsystem's md_gen package.

# ### ### ### ######### ######### #########
## Requisites

package require cmatch
package require doctools
package require fileutil
package require snit
package require struct::set
package require teapot::metadata::container
package require teapot::reference

# ### ### ### ######### ######### #########
## Implementation

snit::type teapot::metadata::scan {
    # ### ### ### ######### ######### #########
    ## API

    option -log -default {}

    constructor {dir args} {}

    #method hints= {text} {}
    #method hints~ {path} {}
    #method scan   {}     {}

    # ### ### ### ######### ######### #########
    ## Implementation

    constructor {dir args} {
	set base [file normalize $dir]
	$self configurelist $args
	return
    }

    method hints= {text} {HintsLoad $text ; return}
    method hints~ {path} {
	HintsLoad [fileutil::cat $path]
	return
    }

    method scan {} {
	if {![IsPkgDir $base]} {
	    return -code error "not a package directory"
	}

	set packages {}

	Log info   { }
	Log notice "Package directory:  $base"

	$self Setup
	$self ScanModule $base packages

	Log info   { }
	Log notice {Scan completed}

	return $packages
    }

    method packages {} {
	if {![IsPkgDir $base]} {
	    return -code error "not a package directory"
	}

	set packages {}

	Log info   { }
	Log notice "Package directory:  $base"

	$self Setup
	set packages [$self ScanIndex $base]
	$self Cleanup $packages

	Log info   { }
	Log notice {Scan completed}

	return $packages
    }

    # ### ### ### ######### ######### #########
    ## State information

    variable base         {} ; # Directory to scan
    variable hignore      {} ; # Hints: Names of the packages to ignore.
    variable hopts -array {} ; # Hints: Options for packages.

    # ### ### ### ######### ######### #########
    ## Helpers

    proc Recommended {container pn args} {
	upvar 1 options options hignore hignore hoptions hoptions
	if {[struct::set contains $hignore $pn]} return
	set spec [teapot::reference::ref2tcl [Specials $pn $args]]
	Log info "    Recommended: $spec"
	$container add recommend $spec
	return
    }

    proc Required {container pn args} {
	upvar 1 options options hignore hignore hoptions hoptions
	if {[struct::set contains $hignore $pn]} return
	set spec [teapot::reference::ref2tcl [Specials $pn $args]]
	Log info "    Required   : $spec"
	$container add require $spec
	return
    }

    # Hint processing, hardwired and loaded.
    proc Specials {pn spec} {
	upvar 1 hoptions hoptions

	set spec [linsert $spec 0 $pn]

	# Loaded hints
	if {[info exists hoptions($pn)]} {
	    foreach o $hoptions($pn) {lappend spec $o}
	}

	# Hardwired hints.
	switch -exact -- $pn {
	    dde -
	    registry {
		# These are known win-only packages.
		# Add the proper guardian clause, and
		# re-normalize to kill duplicates, if any.

		lappend spec -platform windows
		set     spec [teapot::reference::normalize1 $spec]
	    }
	    default {
		# Not a special case. Do nothing.
	    }
	}

	return $spec
    }

    proc MinTclReq {container} {
	upvar 1 options options mintclversion mintclversion
	if {$mintclversion eq ""} return
	Log info "    Requires at least Tcl $mintclversion"
	$container add require [teapot::reference::cons Tcl -require $mintclversion]
	return
    }

    proc MinTclReqEx {container mt label} {
	upvar 1 options options
	Log info "    Requires at least Tcl $mt (because of $label)"
	$container add require [teapot::reference::cons Tcl -require $mt]
	return
    }

    proc NewKeep {label name version} {
	upvar 1 options options mintclversion mintclversion

	set arch [platform::identify]

	Log info    " "
	Log info    "  Package $name $version ..."
	Log info    "    $label"
	Log info    "    Entrypoint: Keeping existing package index"
	Log warning "    Binary package most likely, assumed"
	Log warning "    Platform defaults to \"$arch\"."
	Log warning "    Set this manually should we be wrong."

	set md [teapot::metadata::container %AUTO%]
	$md define $name $version
	$md add entrykeep
	$md add platform $arch

	if {$mintclversion eq ""} {
	    set mintclversion 8.4
	    MinTclReq $md
	    set mintclversion ""
	}
	return $md
    }

    proc NewImmediate {label name version loadcommand} {
	upvar 1 options options mintclversion mintclversion
	Log info " "
	Log info "  Package $name $version ..."
	Log info   "    $label"
	Log info   "    Entrypoint: Immediate Load command, Tcl package"

	set md [teapot::metadata::container %AUTO%]
	$md define $name $version
	$md add __immediate     $loadcommand
	$md add platform    tcl

	MinTclReq $md
	return $md
    }

    proc NewTcl {name version loadcommand} {
	upvar 1 options options mintclversion mintclversion
	Log info " "
	Log info "  Package $name $version ..."
	Log info   "    Entrypoint: Immediate Load command, Tcl package"

	set md [teapot::metadata::container %AUTO%]
	$md define $name $version
	$md add __immediate $loadcommand
	$md add platform    tcl

	MinTclReq $md
	return $md
    }

    proc NewLoaded {name version entrypoints eprefix sourced} {
	upvar 1 options options mintclversion mintclversion

	set arch [platform::identify]

	Log info    " "
	Log info    "  Package $name $version ..."
	Log warning "    Binary package (loaded entry points)"
	Log warning "    Platform defaults to \"$arch\"."
	Log warning "    Set this manually should we be wrong."

	set md [teapot::metadata::container %AUTO%]
	$md define $name $version
	$md add platform $arch

	foreach e $entrypoints {
	    Log info "    Entrypoint (L): $e"
	    $md add entryload  $e
	    $md add __entry    $e
	}
	foreach {e p} $eprefix {
	    Log info "    Entrypoint (L): $e"
	    $md add entryload  $e
	    $md add initprefix $e $p
	    $md add __entry    $e
	}
	foreach e $sourced {
	    Log info "    Entrypoint (S): $e"
	    $md add entrysource $e
	    $md add __entry     $e
	}

	MinTclReq $md
	return $md
    }

    proc NewSourced {name version entrypoints} {
	upvar 1 options options mintclversion mintclversion
	Log info " "
	Log info   "  Package $name $version ..."
	Log info   "    Tcl package (sourced entry points)"
	foreach e $entrypoints {
	    Log info "    Entrypoint: $e"
	}

	set md [teapot::metadata::container %AUTO%]
	$md define $name $version
	foreach e $entrypoints {
	    $md add entrysource $e
	    $md add __entry     $e
	}
	$md add platform    tcl

	MinTclReq $md
	return $md
    }

    proc INLoadCmd {loadcommand} {
	set llc [cmatch::trim [cmatch::literal $loadcommand]]
	if {[lindex $loadcommand 0] eq "word"} {
	    # Ensure that a double-quoted word is run in a
	    # generated file as a script with full subst.
	    set llc "eval \"$llc\""
	} elseif {[lindex $loadcommand 0] eq "cmd"} {
	    # Ensure that a bracket-quoted word is run in a
	    # generated file as a script with full subst.
	    set llc "eval \[$llc\]"
	}
	return $llc
    }

    proc BundleLoadCmd {packages} {
	set lc {}
	foreach {pkg ver __} $packages {
	    lappend lc [list package require $pkg $ver]
	}
	return [join $lc \n]
    }

    method Bundle1 {cmd pv} {
	upvar 1 $pv packages mintclversion mintclversion

	if {![cmatch::match $cmd {cmd
	    {lit ::tcl::pkgindex}
	    {var/scalar {lit dir}}
	    {lit $bundle}
	    {lit $bundlever}
	    {lit $bpackages}
	}] && ![cmatch::match $cmd {cmd
	    {lit tcl::pkgindex}
	    {var/scalar {lit dir}}
	    {lit $bundle}
	    {lit $bundlever}
	    {lit $bpackages}
	}]} {
	    # Construction does not match, check next possibility.
	    return 0
	}
	# -> bundle bundlever bpackages

	Log info " "
	Log notice "tcl::pkgindex setup"

	foreach {pkg ver entry} $bpackages {
	    lappend packages [NewSourced $pkg $ver $entry]
	}

	if {$bundle ne ""} {
	    lappend packages [set b [NewImmediate Bundle $bundle $bundlever \
					 [BundleLoadCmd $bpackages]]]
	    foreach {pkg ver __} $bpackages {
		Required $b $pkg -require $ver
	    }
	}

	# We have handled the command, skip the other possibilities
	return 1
    }

    method Critcl {cmd pv} {
	upvar 1 $pv packages mintclversion mintclversion

	if {![cmatch::match $cmd {cmd
	    {lit critcl::loadlib}
	    {var/scalar {lit dir}}
	    {lit $pkgname}
	    {lit $pkgversion}
	}]} {
	    # No match for critcl construction, skip
	    return 0
	}

	Log info " "
	Log notice "Critcl setup"

	lappend packages [set c [NewKeep Critcl $pkgname $pkgversion]]
	# critcl is 8.4 based. The package code may impose a
	# higher restriction though.
	MinTclReqEx $c 8.4 "Critcl"

	# We have handled the command, skip the other possibilities
	return 1
    }

    method Critcl2 {cmd pv} {
	upvar 1 $pv packages mintclversion mintclversion

	if {![cmatch::match $cmd {cmd
	    {lit critcl2::loadlib}
	    {var/scalar {lit dir}}
	    {lit $pkgname}
	    {lit $pkgversion}
	    {lit $pkgpreloadmap}
	}]} {
	    # No match for critcl construction, skip
	    return 0
	}

	Log info " "
	Log notice "Critcl v2 setup"

	lappend packages [set c [NewKeep Critcl $pkgname $pkgversion]]
	# critcl is 8.4 based. The package code may impose a
	# higher restriction though.
	MinTclReqEx $c 8.4 "Critcl"

	# We have handled the command, skip the other possibilities
	return 1
    }

    method Critcl21 {cmd pv} {
	upvar 1 $pv packages mintclversion mintclversion

	if {![cmatch::match $cmd {cmd
	    {lit ::critcl::runtime::loadlib}
	    {var/scalar {lit dir}}
	    {lit $pkgname}
	    {lit $pkgversion}
	    {lit $pkgtsources}
	    {lit $pkgpreloadmap}
	}]} {
	    # No match for critcl construction, skip
	    return 0
	}

	Log info " "
	Log notice "Critcl v2.1 setup"

	lappend packages [set c [NewKeep Critcl $pkgname $pkgversion]]
	# critcl is 8.4 based. The package code may impose a
	# higher restriction though.
	MinTclReqEx $c 8.4 "Critcl"

	# We have handled the command, skip the other possibilities
	return 1
    }

    method Critcl21b {cmd pv} {
	upvar 1 $pv packages mintclversion mintclversion

	if {![cmatch::match $cmd {cmd
	    {lit ::critcl::runtime::loadlib}
	    {var/scalar {lit dir}}
	    {lit $pkgname}
	    {lit $pkgversion}
	    {lit $pkglibname}
	    {lit $pkginitfun}
	    {lit $pkgtsources}
	    {lit $pkgpreloadmap}
	}]} {
	    # No match for critcl construction, skip
	    return 0
	}

	Log info " "
	Log notice "Critcl v2.1/new setup, also critcl v3"

	lappend packages [set c [NewKeep Critcl $pkgname $pkgversion]]
	# critcl is 8.4 based. The package code may impose a
	# higher restriction though.
	MinTclReqEx $c 8.4 "Critcl"

	# We have handled the command, skip the other possibilities
	return 1
    }
    method MTGuard {cmd pv} {
	upvar 1 $pv packages mintclversion mintclversion

	if {![cmatch::match $cmd {
	    cmd
	    {lit if}
	    {lit $guard}
	    {lit $return}
	}]} {return 0}

	# Index has conditional code. Check deeper.

	if {[catch {
	    set guard [cmatch::exprtree $guard]
	}]} {
	    Log warning "      Parse error, cannot handle guard"
	    return 0
	}

	if {[cmatch::match $guard {
	    cmd
	    {lit package}
	    {lit vsatisfies}
	    {cmd
		{lit package}
		{lit provide}
		{lit Tcl}
	    }
	    {lit $mt}
	}]} {
	    Log notice "Guard for minimally required Tcl version: $mt"

	    # Now scan the branch script for package declarations as
	    # well.

	    $self HandleIndex packages $mt $return
	    return 1
	}

	if {![cmatch::match $guard {
	    !
	    {cmd
		{lit package}
		{lit vsatisfies}
		{cmd
		    {lit package}
		    {lit provide}
		    {lit Tcl}
		}
		{lit $mt}
	    }
	}]} {return 1}

	# Negative guardian. Check that the branch code is a
	# return. It may have a frink pragma in front.

	set return [string trim $return]
	regsub {\#[ 	]+PRAGMA:[ 	]+returnok} $return {} return
	set return [string trim $return]

	if {$return ne "return"} {return 1}

	if {
	    ($mintclversion eq "") ||
	    ([package vcompare $mt $mintclversion] > 0)
	} {
	    Log notice "Guard for minimally required Tcl version: $mt"
	    set mintclversion $mt
	}
	return 1
    }

    proc IsABundle {loadcommand} {
	# Dynamic ? Cannot check, assume that it is not a bundle. To
	# complex for us.
	if {[lindex $loadcommand 0] ne "lit"} {return 0}

	set loadcommand [string trimright [lindex $loadcommand 1]]
	set hasprovided 0
	if {[catch {
	    set commands [lrange [cmatch::scripttree $loadcommand] 1 end]
	}]} {
	    Log warning "      Parse error, assume that it is not a bundle"
	    return 0
	}
	foreach cmd $commands {
	    if {[cmatch::match $cmd {cmd
		{lit package}
		{lit require}
		{lit $pkgname}
		{lit $pkgversion}
	    }]} continue
	    if {[cmatch::match $cmd {cmd
		{lit package}
		{lit require}
		{lit $pkgname}
	    }]} continue
	    if {[cmatch::match $cmd {cmd
		{lit package}
		{lit provide}
		{lit $pkgname}
		{lit $pkgversion}
	    }]} {set hasprovided 1 ; continue}
	    # Not a package require command => Assume 'not a bundle',
	    # to complex for us.
	    return 0
	}

	# The load script consists of package require statements, but
	# no package is provided => Not a bundle.

	if {!$hasprovided} {return 0}
	return 1
    }

    typevariable esourcep {
	cmd
	{lit list}
	{lit source}
	{cmd
	    {lit file}
	    {lit join}
	    {var/scalar {lit dir}}
	    {lit $entryfile}
	}
    }
    typevariable eloadp {
	cmd
	{lit list}
	{lit load}
	{cmd
	    {lit file}
	    {lit join}
	    {var/scalar {lit dir}}
	    {lit $entryfile}
	}
    }

    proc Entrypoints {loadcommand pattern} {
	set res     {}
	set matches {}
	cmatch::locate matches $loadcommand $pattern
	foreach m     $matches {
	    if {![cmatch::match $m $pattern]} continue
	    # entryfile is set by 'match',
	    lappend res $entryfile
	}
	return $res
    }

    typevariable eloadpp {
	cmd
	{lit list}
	{lit load}
	{cmd
	    {lit file}
	    {lit join}
	    {var/scalar {lit dir}}
	    {lit $entryfile}
	}
	{lit $pprefix}
    }

    proc EntrypointsLP {loadcommand} {
	set res     {}
	set matches {}
	cmatch::locate matches $loadcommand $eloadpp
	foreach m     $matches {
	    if {![cmatch::match $m $eloadpp]} continue
	    # entryfile, pprefix are set by 'match',
	    lappend res $entryfile $pprefix
	}
	return $res
    }

    typevariable epkgsetup  {
	cmd
	{lit list}
	{lit tclPkgSetup}
	{var/scalar {lit dir}}
	{lit $_}
	{lit $_}
	{lit $pkgsetup}
    }

    proc TclPkgSetup {loadcommand sv lv} {
	upvar 1 $sv sourced $lv loaded
	set matches {}
	cmatch::locate matches $loadcommand $epkgsetup
	set ok 0
	foreach m $matches {
	    if {![cmatch::match $m $epkgsetup]} continue
	    set ok 1
	    # pkgsetup set by match
	    foreach item $pkgsetup {
		foreach {efile etype cmdlist} $item break
		if {$etype eq "source"} {
		    lappend sourced $efile
		} elseif {$etype eq "load"} {
		    lappend loaded $efile
		} else {
		    Log warning "Unknown file load command \"$etype\" found in tclPkgSetup"
		}
	    }
	}
	return $ok
    }

    method Ifneeded {cmd pv} {
	upvar 1 $pv packages mintclversion mintclversion

	if {![cmatch::match $cmd {cmd
	    {lit package}
	    {lit ifneeded}
	    {lit $pkgname}
	    {lit $pkgversion}
	    $loadcommand
	}]} {return 0}

	# Regular package ifneeded statement. Run through a series of
	# templates to determine more closely what it is, and what is
	# needed.

	if {[IsABundle $loadcommand]} {
	    lappend packages [NewImmediate Bundle $pkgname $pkgversion \
				  [string trimright [lindex $loadcommand 1]]]
	    return 1
	}

	set sourced {}
	set loaded  {}
	set loadedp {}

	set lazysourced {}
	set lazyloaded  {}

	if {[TclPkgSetup $loadcommand lazysourced lazyloaded]} {
	    # A lazy source/load was found. It may be mixed with other
	    # source/load commands, and regular Tcl setting up
	    # variables and what not. Make this an 'entrytclcommand'
	    # to capture all possibilities.

	    lappend packages [NewTcl $pkgname $pkgversion \
				  [INLoadCmd $loadcommand]]
	    return 1
	}

	foreach x [Entrypoints   $loadcommand $esourcep] {lappend sourced $x}
	foreach x [Entrypoints   $loadcommand $eloadp]   {lappend loaded  $x}
	foreach x [EntrypointsLP $loadcommand]           {lappend loadedp $x}

	if {[llength $loaded] || [llength $loadedp]} {
	    lappend packages [NewLoaded $pkgname $pkgversion \
				  $loaded $loadedp $sourced]
	    return 1
	}

	# !loaded && !loadedp

	if {[llength $sourced]} {
	    lappend packages [NewSourced $pkgname $pkgversion $sourced]
	    return 1
	}

	# !loaded && !loadedp && !sourced
	# No detailed information about entrypoints found. We simply
	# use the load command at large.

	lappend packages [NewTcl $pkgname $pkgversion \
			      [INLoadCmd $loadcommand]]
	return 1
    }

    method HandleIndex {pv mintclversion indexscript} {
	upvar 1 $pv packages

	if {[catch {
	    set commands [lrange [cmatch::scripttree $indexscript] 1 end]
	}]} {
	    Log warning "      Parse error, skipping index"
	    return
	}

	foreach cmd $commands {
	    # Check each command in the index against a series of templates,
	    # i.e. known constructions.

	    if {[$self Bundle1   $cmd packages]} continue
	    if {[$self Critcl    $cmd packages]} continue
	    if {[$self Critcl2   $cmd packages]} continue
	    if {[$self Critcl21  $cmd packages]} continue
	    if {[$self Critcl21b $cmd packages]} continue ;# This also critcl 3
	    if {[$self MTGuard   $cmd packages]} continue
	    if {[$self Ifneeded  $cmd packages]} continue
	}
	return
    }

    method ScanIndex {path} {
	set index [file join $path pkgIndex.tcl]
	Log info "Index @ [fileutil::stripPath $base $index]"
	set packages {}
	$self HandleIndex packages {} [fileutil::cat $index]
	return $packages
    }

    typevariable fpatterns  {*.tcl tclIndex *.so *.sl *.dll *.dylib}
    typevariable dfpatterns {*.man}
    typevariable bpatterns  {*.so *.sl *.dll *.dylib}

    proc FindFiles {path} {
	set files {}
	foreach f [fileutil::findByPattern $path -glob -- $fpatterns] {
	    lappend files [fileutil::stripPath $path $f]
	}
	return $files
    }

    proc FindDocFiles {path} {
	set files {}
	foreach f [fileutil::findByPattern $path -glob -- $dfpatterns] {
	    lappend files [fileutil::stripPath $path $f]
	}
	return $files
    }

    proc Binary? {f} {
	if {[lsearch -exact [fileutil::fileType $f] binary] >= 0} {
	    return 1
	}
	foreach pat $bpatterns {
	    if {[string match $pat $f]} {return 1}
	}
	return 0
    }

    proc Pragmas {script} {
	upvar 1 options options
	# Extraction of pragmas influencing the process from a file.

	# Syntax: Pragmas are found only in Tcl comments, and look
	# like a Tcl command. Leading and trailing whitespace is
	# ignored. The following commands are recognized as PRAGMA
	# intros: @mdgen, @md_pragma.

	# The recognized pragma commands after the intro marker are
	#
	# "OWNER"   ":" <file-glob-pattern>
	# "EXCLUDE" ":" <file>
	# "NODEP"   ":" <package>

	# NODEP pragmas tell us which package names found in the code
	# are no true dependencies. Example: Plugin pseudo-packages a
	# plugin can check the environment against, but which do not
	# exist beyond that.

	set ex {}
	set in {}
	set no {}

	foreach line [split $script \n] {
	    # ignore leading/trailing whitespace
	    set line [string trim $line]
	    # Ignore non-comment lines
	    if {![string match "#*" $line]} continue
	    # Ignore non-pragma comments
	    if {
		![regexp {^\#\s*@mdgen\s+(.+)$}     $line -> pragma] &&
		![regexp {^\#\s*@md_pragma\s+(.+)$} $line -> pragma]
	    } continue
	    set pragma [string trimright $pragma]
	    #if {![regexp {^\#\s*((@mdgen)|(@md_pragma))\s+(\S+)\s*$} $line -> _ _ _ pragma]} continue
	    #puts |$line
	    #puts @$pragma@
	    if {[regexp {EXCLUDE\s*:\s*(\S+)} $pragma -> path]} {
		lappend ex $path
		continue
	    }
	    if {[regexp {OWNER\s*:\s*(\S+)} $pragma -> path]} {
		#puts "OWNER|$path"
		lappend in $path
		continue
	    }
	    if {[regexp {NODEP\s*:\s*(\S+)} $pragma -> pkgname]} {
		#puts NODEP|$pkgname
		lappend no $pkgname
		continue
	    }
	    Log warning "Unknown pragma found, ignored: \"$pragma\""
	}

	return [list excluded $ex included $in nodep $no]
    }

    method MapFilesImmediate {path packages fv mv allfiles} {
	upvar 1 $fv files $mv map

	if {![llength $files]} return

	Log info " "
	Log notice "II. Find files in immediate load scripts"

	foreach p $packages {
	    # Ignore packages without immediate script
	    if {![$p exists __immediate]} continue

	    Log info " "
	    Log info "  [$p identity]"

	    set script [lindex [$p getfor __immediate] 0]
	    if {[catch {
		set stree [cmatch::scripttree $script]
	    }]} {
		Log warning "      Parse error, skipping."
		continue
	    }

	    set newcheck {}
	    $self MapTclScript $stree <Immediate> $p map files newcheck $allfiles
	}
	return
    }

    method MapFilesTrace {path packages fv mv allfiles} {
	upvar 1 $fv files $mv map

	#if {![llength $files]} return

	# We have may not files left over, per our check for
	# code. However the package may contain non-code files as
	# well, and these will only be found through OWNER pragmas,
	# and, maybe, through source statements. Or we have files left
	# over and have to map them too. Whichever, we now try to find
	# out which other files belong where by looking for source
	# statements and pragmas in the files we have already mapped
	# (and have a .tcl extension). Note that each newly mapped
	# file may cause more mappings, due to its own source commands
	# and pragmas.

	# Note that we look only at files with a .tcl extension, and
	# tclIndex files to locate more traces. Data files are added,
	# but not traced further.

	Log info " "
	Log notice "III. Trace source commands and pragmas"

	set done {}
	set check [array names map]

	while {[llength $check]} {
	    set newcheck {}
	    foreach f $check {
		if {[struct::set contains $done $f]} continue
		struct::set include done $f
		if {![trace $f]} continue

		Log info "  Checking $f ..."

		$self MapTrace $path $f map files newcheck $allfiles
	    }
	    set check $newcheck
	}
	return
    }

    method Include {label f p fname mv fv ncv} {
	upvar 1 $mv map $fv files $ncv newcheck

	struct::set exclude files $fname

	# Add file to package, and prepare to trace it as well.

	Log info "  $fname -> [$p identity] ($label by $f)"

	struct::set include newcheck $fname
	$p add included $fname

	if {([info exists map($fname)]) && ($p ne $map($fname))} {
	    Log warning "    Shared with [$map($fname) identity]"
	}
	set map($fname) $p
	return
    }

    method MapTclIndex {code f p mv fv ncv allfiles} {
	upvar 1 $mv map $fv files $ncv newcheck

	set taken {}

	foreach cmd [lrange $code 1 end] {
	    if {![cmatch::match $cmd {
		cmd
		{lit set}
		{lit $varname}
		{
		    cmd
		    {lit list}
		    {lit source}
		    {
			cmd
			{lit file}
			{lit join}
			$___
			{lit $fname}
		    }
		}
	    }]} continue
	    if {![string match "auto_index(*" $varname]} continue

	    # Ignore files which are not within the package directory.
	    # The file may be in a subdirectory.

	    set nfname [MatchFile $fname $allfiles]
	    if {$nfname eq {}} continue
	    set fname $nfname

	    # Skip files we have already processed. In a tclindex many
	    # commands will map to the same file. No need to add them
	    # that often.

	    if {[struct::set contains $taken $fname]} continue
	    struct::set include taken $fname

	    # Ok, file is unknown so far, remember it.

	    $self Include Autoloaded $f $p $fname map files newcheck
	}
	return
    }

    proc MatchFile {fname allfiles} {
	# Search for exact match first, then for subdir match, this
	# latter using glob-style matching. For this we force literal
	# interpretation of the filename even if it contains glob
	# special chars.

	set pos [lsearch -exact $allfiles $fname]
	if {$pos >= 0 } {
	    return [lindex $allfiles $pos]
	}

	set qfname \\[join [split $fname {}] \\]
	set pos [lsearch -glob $allfiles */$qfname]
	if {$pos >= 0 } {
	    return [lindex $allfiles $pos]
	}

	return {}
    }

    typevariable sourcep {
	{
	    cmd
	    {lit source}
	    {
		cmd
		{lit file}
		{lit join}
		$___
		{lit $fname}
	    }
	} {
	    cmd
	    {lit file}
	    {lit join}
	    $___
	    {lit $fname}
	}
    }

    method MapTclScript {code f p mv fv ncv allfiles} {
	upvar 1 $mv map $fv files $ncv newcheck

	set taken {}

	foreach pattern $sourcep {
	    set matches {}
	    cmatch::locate matches $code $pattern
	    foreach m $matches {
		if {![cmatch::match $m $pattern]} continue
		# -> fname

		# Ignore files which are not within the package
		# directory. Force literal interpretation of the
		# filename even if it contains glob special chars.

		set nfname [MatchFile $fname $allfiles]
		if {$nfname eq {}} continue
		set fname $nfname

		# Skip files we have already processed. A file may
		# source in several locations.

		if {[struct::set contains $taken $fname]} continue
		struct::set include taken $fname

		$self Include Sourced $f $p $fname map files newcheck
	    }
	}
	return
    }

    variable nodep -array {}
    variable pincl -array {}

    method MapTrace {path f mv fv ncv allfiles} {
	upvar 1 $mv map $fv files $ncv newcheck

	set script [fileutil::cat [file join $path $f]]

	if {[catch {
	    set stree [cmatch::scripttree $script]
	}]} {
	    Log warning "      Parse error, skipping."
	    return
	}

	set p $map($f)
	if {
	    ("tclIndex" eq $f) ||
	    [string match "*/tclIndex" $f]
	} {
	    $self MapTclIndex  $stree $f $p map files newcheck $allfiles
	} else {
	    $self MapTclScript $stree $f $p map files newcheck $allfiles
	}

	# We are checking all traced files for pragmas indicating the
	# ownwership, aka INCLUSION of other files. Included files
	# belong to the file containing the pragma, and its package,
	# without getting directly sourced.

	# There is no need to check for excluded files, this has been
	# handled already before we even started with the mapping.

	foreach in $pincl($f) {
	    #Log info "  <$in>"
	    foreach fx [glob -directory $path $in] {
		if {[file isdirectory $fx]} continue
		set fxs [fileutil::stripPath $path $fx]

		$self Include Owned $f $p $fxs map files newcheck

		# Reading pragmas of not yet known files.
		if {![info exists nodep($fxs)]} {
		    Log info "    Reading pragmas ..."
		    array set pr [Pragmas [fileutil::cat $fx]]
		    set nodep($fxs) $pr(nodep)
		    set pincl($fxs) $pr(included)
		    unset pr
		}
	    }
	}
	return
    }

    proc trace {f} {
	return [expr {
		      [string match *.tcl $f] ||
		      ("tclIndex" eq $f) ||
		      [string match "*/tclIndex" $f]
		  }]
    }

    method MapFilesEntrypoints {path packages fv mv} {
	upvar 1 $fv files $mv map
	Log info " "
	Log notice "I.   Entrypoints, trivial to map to their package"

	foreach p $packages {
	    # Ignore packages without entrypoints.
	    if {![$p exists __entry]} continue

	    Log info " "
	    Log info "  [$p identity]"

	    # Check how many of the entrypoints are already mapped, to
	    # which other packages.

	    # (A) All mapped, and to the same package => This package
	    # is an alias of the other. Note this, and change the
	    # entrypoints, requirements, platform of this package to
	    # simply refer to the other. I.e. this package is
	    # converted into a bundle of one.

	    # (B) To different packages, or not all mapped => Warn of
	    # the overlap, but accept the package as its own.

	    # (C) No existing mapping => Map to this package.

	    set alreadymapped 0
	    set mapdst        {}
	    set maxem 0
	    set maxe  0

	    foreach e [$p getfor __entry] {
		set l [string length $e]
		if {$l > $maxe} {set maxe $l}
		if {![info exists map($e)]} continue
		if {$l > $maxem} {set maxem $l}
		incr alreadymapped
		struct::set include mapdst $map($e)
	    }

	    if {$alreadymapped} {
		if {
		    ($alreadymapped == [llength [$p getfor __entry]]) &&
		    ([struct::set size $mapdst] == 1)
		} {
		    # (A)
		    set origin [lindex $mapdst 0]
		    set on     [$origin name]
		    set ov     [$origin version]

		    Log warning "    Alias of [$origin identity]"

		    $p unset entrysource
		    $p unset entryload
		    $p unset entrytclcommand
		    $p add __immediate [list package require $on $ov]
		    $p rearch tcl
		    $p setfor require  [list [teapot::reference::cons $on -require $ov]]

		    continue
		} else {
		    # (B)
		    Log warning "    $alreadymapped file[pl $alreadymapped " is" "s are"] shared with other packages:"
		    # FUTURE - determine string length, format in columns
		    foreach e [$p getfor __entry] {
			if {![info exists map($e)]} continue
			Log warning "    - [lj $maxem $e] with [$map($e) identity]"
		    }
		}
	    }

	    # (B,C)
	    foreach e [$p getfor __entry] {
		struct::set exclude files $e
		$p add included $e
		Log info "    + [lj $maxe $e] (Entrypoint)"
		if {[info exists map($e)]} continue
		set map($e) $p
	    }
	}

	return
    }

    proc pl {n {s {}} {p s}} {expr {$n == 1 ? "$s" : "$p"}}
    proc lj {n s} {format %-*s $n $s}
    proc rj {n s} {format %*s $n $s}
    proc MaxL {list} {
	set max 0
	foreach i $list {
	    set l [string length $i]
	    if {$l <= $max} continue
	    set max $l
	}
	return $max
    }

    method MapFilesMulti {path packages fv} {
	upvar 1 $fv files
	Log info "  Many packages, scan sources for hints"

	set allfiles $files
	array set map {}

	$self MapFilesEntrypoints $path $packages files map
	$self MapFilesImmediate   $path $packages files map $allfiles
	$self MapFilesTrace       $path $packages files map $allfiles

	if {![llength $files]} {
	    Log info "No files left over, done"
	}
	return
    }

    method MapFilesSingle {path md fv} {
	upvar 1 $fv files

	# Well, not quite all. pragmas in the entrypoints may indicate
	# that some files are not wanted. These we exclude.

	# Check the entrypoints, if we know any for pragmas indicating
	# the EXCLUSION of files. These files do not belong the
	# package. All others are taken by the package.

	Log info "  Single package, capturing everything"

	foreach f $files {
	    $md add included $f
	}

	# Bug 70456.
	# Gather owned files as well, may be outside of the basic list
	# of files captured.
	foreach f [array names pincl] {
	    if {![llength $pincl($f)]} continue
	    foreach o $pincl($f) {
		$md add included $o
	    }
	}

	# All files mapped
	set files {}
	return
    }

    method MapFiles {path packages} {
	Log info " "
	Log notice "Find package files"
	Log info   "  Patterns: [join $fpatterns " "]"

	set files [FindFiles $path]
	set n     [llength $files]

	Log info "  $n File[pl $n]."
	if {![llength $files]} return

	# We read the pragmas out of the tcl files first and save the
	# results. That way we can use them anywhere we need without
	# having to scan a file many times.

	Log info "  Reading pragmas ..."

	set pexcl {}

	foreach f $files {
	    Log info "    $f ..."
	    array set pr [Pragmas [fileutil::cat [file join $path $f]]]
	    set nodep($f) $pr(nodep)
	    set pincl($f) $pr(included)
	    
	    struct::set add pexcl $pr(excluded)
	    unset pr

	    # Exclusion of package indices is hardwired
	    if {[string match *pkgIndex.tcl $f]} {
		struct::set include pexcl $f
	    }
	}

	# Excluding all unwanted files in one go.

	if {[struct::set size $pexcl]} {
	    Log info   " "
	    Log notice "Excluding unwanted files"

	    foreach f $pexcl {
		Log info   "  $f"
		struct::set exclude files $f
	    }
	}

	Log info " "
	Log notice "Determine which files belong to what package"

	if {[llength $packages] == 1} {
	    $self MapFilesSingle $path [lindex $packages 0] files
	} else {
	    $self MapFilesMulti  $path $packages files
	}

	set r [llength $files]
	if {$r > 0} {
	    Log warning " "
	    Log warning "For $r file[pl $r] of $n was it impossible to determine the package [pl $r it they] belong[pl $r s ""] to."
	    Log warning "[pl $r {This file is} {These files are}]:"
	    foreach f $files {
		Log warning "- $f"
	    }
	}
	return
    }

    method Requirements {path packages} {
	Log info " "
	Log notice "Determine the requirements of all packages"
	foreach p $packages {
	    $self GetRequirements $path $p
	}
	return
    }

    method GetRequirements {path p} {
	Log info " "
	Log info "  [$p identity]"

	set unwanted [$self Unwanted $p]

	if {[llength $unwanted]} {
	    Log info "    Excluded dependencies"
	    foreach ref $unwanted {
		Log info "      $ref"
	    }
	}

	set n 0
	if {[$p exists included]} {
	    foreach f [lsort -uniq [$p getfor included]] {
		# Ignore files which have extensions indicating
		# binary contents

		set fx [file join $path $f]
		if {[Binary? $fx]} {
		    Log warning "    Ignoring likely binary file $f ..."
		    continue
		}

		if {[file isdirectory $fx]} {
		    Log warning "    Ignoring directory $f ..."
		    continue
		}

		Log info "    Extracting from $f ..."
		incr n [$self ExtractReq $p [fileutil::cat $fx] $unwanted]
	    }
	}
	if {[$p exists __immediate]} {
	    Log info "    Extracting from <Immediate> ..."
	    incr n [$self ExtractReq $p [$p getfor __immediate] $unwanted]
	}

	if {$n == 0} {
	    Log info "    No dependencies found"
	}
	return
    }

    method Unwanted {p} {
	set res [list [$p name]]
	if {[$p exists included]} {
	    foreach f [lsort -uniq [$p getfor included]] {
		if {![info exists nodep($f)]} continue
		foreach x $nodep($f) {lappend res $x}
	    }
	}
	if {[$p exists __immediate]} {
	    array set pr [Pragmas [$p getfor __immediate]]
	    foreach x $pr(nodep) {lappend res $x}
	}
	return [lsort -uniq $res]
    }

    method ExtractReq {p script unwanted} {
	set rec  $unwanted

	if {[catch {
	    set code [cmatch::scripttree $script]
	}]} {
	    # Parse error in the file. Note this in the log, but otherwise
	    # ignore it.
	    Log warning "      Parse error, skipping."
	    return 0
	}

	# First look for recommendations (package require within a catch).

	set n 0
	foreach pattern {
	    {
		cmd
		{lit catch}
		{lit $caught}
	    } {
		cmd
		{lit catch}
		{lit $caught}
		{lit $cvar}
	    }
	} {
	    set matches {}
	    cmatch::locate matches $code $pattern
	    foreach m $matches {
		if {![cmatch::match $m $pattern]} continue
		# -> caught
		if {[catch {
		    set references [GetRequire [cmatch::scripttree $caught] $unwanted]
		}]} {
		    Log warning "      Parse error, continuing search,"
		    Log warning "      requirements may be incomplete"
		    continue
		}
		foreach ref $references {
		    eval [linsert $ref 0 ${type}::Recommended $p]
		    struct::set include rec [teapot::reference::name $ref]
		    incr n
		}
	    }
	}

	# Then look for requirements, and remove the recommendations
	# we found before (as we find them here again).

	# We do not detect when a package X is both required and
	# catch(required).

	foreach ref [GetRequire $code $rec] {
	    eval [linsert $ref 0 ${type}::Required $p]
	    incr n
	}

	return $n
    }

    proc GetRequire {code ignore} {
	set refs {}
	set matches {}
	set pattern {
	    cmd
	    {lit package}
	    {lit require}
	    {lit $pname}
	}
	cmatch::locate matches $code $pattern
	foreach m $matches {
	    if {![cmatch::match $m $pattern]} continue
	    # -> pname
	    if {[struct::set contains $ignore $pname]} continue
	    lappend refs [teapot::reference::cons $pname]
	}
	set matches {}
	set pattern {
	    cmd
	    {lit package}
	    {lit require}
	    {lit $pname}
	    {lit $pversion}
	}
	cmatch::locate matches $code $pattern
	foreach m $matches {
	    if {![cmatch::match $m $pattern]} continue
	    # -> pname pversion
	    if {[struct::set contains $ignore $pname]} continue
	    lappend refs [teapot::reference::cons $pname -require $pversion]
	}
	set matches {}
	set pattern {
	    cmd
	    {lit package}
	    {lit require}
	    {lit -exact}
	    {lit $pname}
	    {lit $pversion}
	}
	cmatch::locate matches $code $pattern
	foreach m $matches {
	    if {![cmatch::match $m $pattern]} continue
	    # -> pname pversion
	    if {[struct::set contains $ignore $pname]} continue
	    lappend refs [teapot::reference::cons $pname -require [list $pversion $pversion]]
	}

	return $refs
    }

    proc denter {p pn pv} {
	upvar 1 pkg pkg
	set pkg(${pn}-$pv) $p
	set pkg([string tolower $pn]-$pv) $p
	set pkg([string toupper $pn]-$pv) $p
	set pkg([string totitle $pn]-$pv) $p
	set pkg(${pn}) $p
	set pkg([string tolower $pn]) $p
	set pkg([string toupper $pn]) $p
	set pkg([string totitle $pn]) $p
	return
    }

    proc dok {key pv} {
	upvar 1 pkg pkg $pv package
	if {![info exists pkg($key)]} {return 0}
	set package $pkg($key)
	return 1
    }

    proc dpackage {desc} {
	upvar 1 pkg pkg
	array set d $desc

	# I.  See if title+version can be found among the candidates.
	# II. See if a requirement can be found among the candidates.
	#     (a: name + version, and version as in the title)
	#     (b: name + version)
	#     (c: name only)
	#     This counts only if there is exactly one match.

	# Basis for II:
	# It is normal for the manpage to list the package itself as
	# requirement. And other required packages are usually in a
	# different directory and are not in the list of packages
	# provided by this specific directory. This allows us to find
	# the name with high probability. To be more sure we reject
	# multiple matches.

	# III. Try to locate file name among the candidates
	#     (a: file + version from title)
	#     (b: file only)

	# I.
	if {[dok $d(title)-$d(version) px]} {return $px}

	set matches {}
	# II.a.
	foreach {r v} $d(require) {
	    if {$r eq "Tcl"} continue
	    if {$v ne ""} {
		if {$v ne $d(version)} continue
		set v "-$v"
	    }
	    if {![dok $r$v px]} continue
	    lappend matches $px
	}
	if {![llength $matches]} {
	    # II.b.
	    foreach {r v} $d(require) {
		if {$r eq "Tcl"} continue
		if {$v ne ""} {set v "-$v"}
		if {![dok $r$v px]} continue
		lappend matches $px
	    }
	}
	if {![llength $matches]} {
	    # II.c
	    foreach {r v} $d(require) {
		if {$r eq "Tcl"} continue
		if {![dok $r px]} continue
		lappend matches $px
	    }
	}
	if {[llength $matches] == 1} {
	    return [lindex $matches 0]
	}

	# III.a.
	if {[dok $d(file)-$d(version) px]} {return $px}

	# III.b.
	if {[dok $d(file) px]} {return $px}

	return {}
    }

    method Documentation {path packages} {
	Log info   " "
	Log notice "Find package documentation files (doctools based)"
	Log info   "  Patterns: [join $dfpatterns " "]"

	set files [FindDocFiles $path]
	set n     [llength $files]

	Log info "  $n File[pl $n] found."
	if {![llength $files]} return

	Log info   " "
	Log notice "Scan documentation"

	array set desc [$self GetDoc $path $files]

	# Map doc files to packages.

	array set pkg {}
	foreach p $packages  {
	    set pn [$p name]
	    set pv [$p version]

	    denter $p $pn $pv
	    regsub -all {::} $pn _ pn
	    denter $p $pn $pv
	}

	set maxl 0
	foreach f $files {
	    set l [string length $f]
	    if {$l > $maxl} {set maxl $l}
	}

	set d {}
	foreach f $files {

	    set p [dpackage $desc($f)]

	    if {$p eq ""} {
		Log warning "  [lj $maxl $f] : Unable to determine package."
	    } else {
		Log info    "  [lj $maxl $f] : Package [$p identity]"

		$self SaveDocInfo $p $desc($f)
	    }
	}

	return
    }

    method SaveDocInfo {p data} {
	array set d $data

	# Copy doctools meta-data, as far as we have it, over to the
	# equivalent teapot keywords.

	foreach {k m} {
	    title     summary
	    keywords  subject
	    desc      description
	} {
	    if {![info exists d($k)] || ($d($k) eq "")} continue

	    if {[catch {llength $d($k)}]} {
		set v [split $d($k)]
	    } else {
		set v $d($k)
	    }

	    foreach e $v {
		$p add $m $e
	    }
	}

	# The category information is handled a bit differently, as we
	# have two possible sources for it. The categorical
	# 'category', or the 'shortdesc'. We prefer the former over
	# the latter and thus try each one in this order, stopping
	# when we had a success.

	foreach k {category shortdesc} {
	    if {![info exists d($k)] || ($d($k) eq "")} continue

	    if {[catch {llength $d($k)}]} {
		set v [split $d($k)]
	    } else {
		set v $d($k)
	    }

	    foreach e $v { $p add category $e }
	    break
	}

	return
    }

    method GetDoc {path files} {
	set t [DocSetup]
	set dt [::doctools::new ${selfns}::dt -format $t]

	array set desc {}
	foreach f $files {
	    set fx [file join $path $f]
	    Log info "  Scanning $f ..."
	    $dt configure -file $fx
	    if {[catch {
		set desc($f) [$dt format [fileutil::cat $fx]]
	    } msg]} {
		Log warning "    Failed, ignoring the file ($msg)"
	    } else {
		lappend desc($f) file [file rootname $f]
	    }
	}

	$dt destroy
	file delete -- $t

	return [array get desc]
    }

    proc DocSetup {} {
	set t [fileutil::tempfile]
	# Special doctools formatting engine for the extraction of the
	# data of interest to the scanner.
	fileutil::writeFile $t {
	    ################################################################
	    global data ; array set data {} ; proc fmt_initialize {} {return}
	    proc fmt_shutdown   {} {return} ; proc fmt_numpasses  {} {return 1}
	    foreach p {
		manpage_begin moddesc titledesc manpage_end require description
		section para list_begin list_end lst_item call usage bullet enum
		arg_def cmd_def opt_def tkoption_def see_also keywords example
		example_begin example_end nl arg cmd opt emph comment image
		sectref syscmd method option widget fun type package class var
		file uri term const copyright namespace subsection manpage
	    } {proc fmt_$p {args} {return {}}}
	    proc fmt_postprocess {text} {
		global data ; foreach key {seealso keywords} {
		    array set _ {} ; foreach ref $data($key) {set _($ref) .}
		    set data($key) [array names _]; unset _
		}
		return [array get data]\n
	    }
	    proc fmt_plain_text    {text} {return ""}
	    proc fmt_manpage_begin {title section version} {
		global data ; set data(title) $title ; set data(version) $version
		array set data {require {} desc {} shortdesc {} keywords {} seealso {}}
		return
	    }
	    proc fmt_moddesc   {desc} {global data ; set data(shortdesc) $desc}
	    proc fmt_titledesc {desc} {global data ; set data(desc)      $desc}
	    proc fmt_keywords  {args} {global data ; foreach ref $args {lappend data(keywords) $ref} ; return}
	    proc fmt_see_also  {args} {global data ; foreach ref $args {lappend data(seealso)  $ref} ; return}
	    proc fmt_require   {p {v {}}} {global data ; lappend data(require) $p $v ; return}
	    ################################################################
	}
	return $t
    }

    method Cleanup {packages} {

	Log info   " "
	Log notice "Postprocessing accumulated metadata, cleanup"

	foreach p $packages {
	    # Convert __immediate to entrytcl

	    if {[$p exists __immediate]} {
		Log info "  [$p name] immediate -> entrytclcommand"

		$p add entrytclcommand \
		    [lindex [$p getfor __immediate] 0]
	    }

	    # All __* keys are internal, do not propagate them.

	    foreach k [$p names __*] {
		$p unset $k
	    }

	    # Remove any basic duplicates which crept in

	    foreach t {included excluded require recommend} {
		if {[$p exists $t]} {
		    $p setfor $t [lsort -uniq [$p getfor $t]]
		}
	    }

	    # Normalize the dependencies a bit further

	    foreach t {require recommend} {
		if {[$p exists $t]} {
		    $p setfor $t [teapot::reference::normalize \
				      [$p getfor $t]]
		}
	    }
	}
	return
    }

    method ScanModule {path pv} {
	upvar 1 $pv packages

	# Gather information about the module ...
	# - Does it already have meta data ?
	#
	# - Package index:
	#   = #packages,
	#   = package names,
	#   = package versions,
	#   = source/load, entry file
	#   = Tcl version dependencies? (guards)
	#
	# - Tcl code
	#   = sourced files, loaded files
	#   = required packages, provided packages
	#
	# - Man pages
	#   = Package descriptions
	#   = Package keywords
	#   = required packages!
	#
	# - C code
	#   = provided packages, required packages
	#
	# Dump the information as metadata ...

	set mpackages [$self ScanIndex $path]

	$self MapFiles      $path $mpackages
	$self Requirements  $path $mpackages
	$self Documentation $path $mpackages
	$self Cleanup             $mpackages

	foreach p $mpackages {lappend packages $p}
	return
    }

    proc IsPkgDir {path} {
	expr {
	    [fileutil::test $path                          edrx] &&
	    [fileutil::test [file join $path pkgIndex.tcl] efr]
	}
    }

    proc Modules {} {
	upvar 1 base base
	set m {}
	if {[IsPkgDir $base]} {lappend m $base}
	foreach x [fileutil::find $base ::teapot::metadata::scan::IsPkgDir] {
	    lappend m $x
	}
	return $m
    }

    method Setup {} {
	set hf [HintsFile $base]
	if {![file exists $hf]} {
	    Log info "No hints file present."
	} elseif {[fileutil::test $hf fr msg {Hints file}]} {
	    Log notice "Hints file found, now loading ..."
	    HintsLoad [fileutil::cat $hf]
	    Log info Ok
	} else {
	    Log warning $msg
	}
    }

    proc HintsLoad {text} {
	upvar 1 hignore hignore hopts hopts options options

	# Syntax:
	# (1) One hint per line.
	# (2) Ignore leading and trailing whitespace
	# (3) Ignore empty lines.
	# (4) Ignore comment lines (starting with #).
	# (5) "ignore"  <package name>
	# (6) "options" <package name> <options>
	#
	# (5,6): Words are separated by whitespace.
	#        The last word goes to the end of
	#        the line, except whitespace (see 2).

	# (1) One hint per line.
	foreach line [split $text \n] {
	    # (2) Ignore leading and trailing whitespace
	    set line [string trim $line]

	    # (3) Ignore empty lines.
	    if {$line eq ""} continue

	    # (4) Ignore comment lines (starting with #).
	    if {[string match "#*" $line]} continue

	    # (5) "ignore" <package name>
	    if {[regexp {^ignore\s+(.*)$} $line -> pkgname]} {
		lappend hignore $pkgname
		continue
	    }

	    # (6) "options" <package name> <options>
	    if {[regexp {^options\s+(\S*)\s+(.*)$} $line -> pkgname pkgoptions]} {
		set hoptions($pkgname) $pkgoptions
		continue
	    }

	    Log warning "Unknown hint: $line"
	}

	return
    }

    proc HintsFile {dir} {
	return [file join $dir teapot_hints.txt]
    }

    proc Log {level text} {
	upvar 1 options o
	uplevel \#0 [linsert $o(-log) end $level $text]
	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
