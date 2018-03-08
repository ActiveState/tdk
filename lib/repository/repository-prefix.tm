# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::prefix 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     jobs
# Meta require     logger
# Meta require     pkg::mem
# Meta require     repository::api
# Meta require     repository::provided
# Meta require     snit
# Meta require     teapot::instance
# Meta require     teapot::metadata::read
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Copyright (c) 2006-2008 ActiveState Software Inc.

#
# RCS: @(#) $Id: $

# snit::type encapsulating the packages stored in a prefix file as a
# repository. This is _not_ a full repository. The only API methods
# supported are 'require', 'recommend', and 'find'. The first two
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

package require logger                    ; # Tracing
package require pkg::mem                  ; # In-memory instance database
package require repository::api           ; # Repo interface core
package require repository::provided      ; # Scanner index files
package require snit                      ; # OO core
package require fileutil                  ; # File type detection
package require jobs                      ; # Manage defered jobs
package require teapot::instance          ; # Instance manipulation
package require teapot::metadata::read    ; # Meta data extraction.
package require fileutil::magic::filetype ; # File type detection, advanced

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::prefix
snit::type            ::repository::prefix {

    typemethod label {} { return "Prefix file" }

    typemethod valid {location mode mv} {
	upvar 1 $mv message
	if {$mode eq "rw"} {
	    return -code error "Bad mode \"$mode\""
	}
	if {![fileutil::test $location efr message "Prefix"]} {
	    return 0
	} elseif {[lsearch -exact [fileutil::fileType $location] metakit] < 0} {
	    set message "No metakit filesystem present"
	    return 0
	} elseif {[catch {
	    # The prefix is only read, not modified. We are mounting
	    # it read-only expressing this, and to allow the input to
	    # be a non-writable file too.

	    vfs::mk4::Mount $location $location -readonly
	    vfs::unmount    $location
	} msg]} {
	    set message $msg
	    return 0
	}
	return 1
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

    # Location of the repository (= prefix file) in the filesystem.
    # Request asynchronous initialization.

    option -location -default {} -readonly 1 -cgetmethod cget-location
    option -async    -default  0 -readonly 1

    # This repository only has a pseudo-location.
    # (We use the path of the prefix it is constructed for)

    # ### ### ### ######### ######### #########
    ## These are the methods that are called from the generic frontend
    ## during dispatch.

    # ### ### ### ######### ######### #########

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
    method Dump         {opt args} {$self BadRequest $opt dump}
    method Keys         {opt args} {$self BadRequest $opt keys}
    method Search       {opt args} {$self BadRequest $opt search}

    # ### ### ### ######### ######### #########

    method Require      {opt args} {$self NoDeps $opt}
    method Recommend    {opt args} {$self NoDeps $opt}

    # ### ### ### ######### ######### #########

    method Value {opt key spec} {
	if {$defer} {$jobs defer-us}
	# No meta data available in this repository.
	# This will change when the special teapot scanner is
	# available and used.

	# TODO See ScanPrefix... for more ...

	::repository::api::complete $opt 0 [_value $db $key $spec]
	return
    }

    method Meta {opt spec} {
	if {$defer} {$jobs defer-us}

	# No meta data available in this repository.
	# This will change when the special teapot scanner is
	# available and used.

	# TODO See ScanPrefix... for more ...

	set res [_meta $db $spec]
	::repository::api::complete $opt 0 $res
	return
    }

    # List & Find packages ...

    method List {opt {spec {}}} {
	if {$defer} {$jobs defer-us}
	set res {}
	foreach i [$db list $spec] {
	    # Add the profile flag to the listed instances.
	    # -- Could be hardwired to fixed value '1'.
	    # Current set is much nearer to mem repo.

	    # db get = dict {platform P profile .}
	    lappend i 1
	    lappend res $i
	}
	::repository::api::complete $opt 0 $res
	return
    }

    method Find {opt platforms template} {
	if {$defer} {$jobs defer-us}

	set result [$db findref $platforms $template]
	if {[llength $result]} {
	    # Extend found instance with profile info - no profile.
	    set result [list [linsert [lindex $result 0] end 0]]
	}

	::repository::api::complete $opt 0 $result
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

    proc _value {db key spec} {
	array set md [_meta $db $spec]
	if {![info exists md($key)]} {return {}}
	return $md($key)
    }

    proc _meta {db spec} {
	set matches [$db list $spec]
	if {![llength $matches]} {return {}}

	array set tmp {}
	foreach m $matches {
	    array set tmp [$db get $m]
	}

	# See also repo_mm.tcl, _meta.
	array set res {}
	foreach {k v} [array get tmp] {
	    if {[info exists tm($k)]} {
		foreach e $v {lappend res($k) $e}
	    } else {
		set res($k) $v
	    }
	}
	return [array get res]
    }

    # ### ### ### ######### ######### #########

    method architecture {} {
	$self ScanAP
	log::debug "architecture = $architecture"
	return $architecture
    }

    method platform {} {
	$self ScanAP
	return $platform
    }

    # ### ### ### ######### ######### #########
    ## API - Connect object to a prefix. This loads the
    ##       in-memory database of packages.

    constructor {args} {
	log::debug "$self new ($args)"

	$self configurelist $args
	set theprefix $options(-location)

	set API    [repository::api ${selfns}::API -impl $self]
	set db     [pkg::mem        ${selfns}::db]
	set prefix $theprefix

	if {$options(-async)} {
	    # Set up structures to handle requests coming in while
	    # async init is running.

	    set jobs [jobs ${selfns}::jobs]
	    DeferOn

	    $self ScanPrefixForPackagesAsync
	} else {
	    # Sync initialization.
	    $self ScanPrefixForPackages
	}
	return
    }

    # ### ### ### ######### ######### #########
    ##
    # Two methods for finding packages. Both are employed. The first
    # is a file "teapot_provided.txt" providing exact information
    # (especially architecture information). The second, scanning the
    # pkgIndex.tcl files in the prefix, is more of a fallback. It
    # cannot provide architecture data, but versions and names will be
    # exact. Using both allows us to merge the information into a
    # coherent whole.
    #
    # Note: A package listed in "teapot_provided.txt", but not found
    # in the package indices is kept on the roster. It may be
    # statically linked into the prefix, thus have no index
    # file. Example: Package zip in the standard basekits.
    #
    # However nothing is done if the prefix is not mountable.

    method ScanPrefixForPackagesAsync {} {
	if {![Mount $prefix]} {
	    DeferOff

	    # Note: This part was still sync, so there can be no
	    # defered jobs.
	    return
	}

	repository::provided::scan/async \
	    $prefix \
	    [mymethod Trouble] \
	    [mymethod Init] \
	    [mymethod Package] \
	    [mymethod Done]
	return
    }

    method Trouble {text} {
	# Ignore problem reports for now.
	log::debug "Trouble $text"
    }

    method Init {statevar} {
	log::debug Scan/Init

	upvar 1 $statevar state ; # array (). Ours!
	set state(hastcl) 0
	return
    }

    method Package {statevar name version} {
	log::debug Scan/Package\ ($name\ $version)

	upvar 1 $statevar state ; # array (). Ours!
	upvar 0 state(hastcl) hastcl

	# The meta data makes the packages profiles without
	# dependencies. This ensures that the wrap engine filters them
	# out and will not try to retrieve an archive file for them.

	set instance [teapot::instance::cons package $name $version tcl]
	$db enter $instance
	$db set   $instance {platform tcl profile .}

	if {$name eq "Tcl"} {set hastcl 1}
	return
    }

    method Done {statevar} {
	log::debug Scan/Done

	vfs::unmount $prefix

	log::debug Scan/Unmounted

	upvar 1 $statevar state ; # array (). Ours!
	upvar 0 state(hastcl) hastcl

	if {!$hastcl} {
	    log::debug Scan/Pseudo-Tcl
	    $self PseudoTcl
	}

	# !FUTURE! Handle the method 1 stuff too, incl. merging of
	# !FUTURE! information.

	# Ok, the initialization is complete. We can now complete all
	# requests which came in during that time and were defered.

	DeferOff
	$jobs do

	log::debug Scan/Completed
	return
    }

    method ScanPrefixForPackages {} {
	if {![Mount $prefix]} return

	# Method 1. Search for file 'teapot_provided.txt', and parse.
	# Method 2. Search for and scan index files.

	set provided [file join $prefix teapot_provided.txt]
	set pp {}
	if {[file exist $provided]} {
	    set pp [teapot::metadata::read::fileEx $provided many errors 1]
	    # pp is empty in case of errors. We ignore errors here.
	}

	set trouble {}
	set packages [repository::provided::scan $prefix trouble]
	# dict (package_name -> package_version)

	if {[llength $trouble]} {
	    foreach l $trouble {
		log::debug "ScanPrefixForPackages Trouble = $l"
	    }
	}

	vfs::unmount $prefix

	# Merge information from 1 and 2.
	# For packages listed in both 'packages' and 'pp' use pp
	# architecture and packages version. We ignore entries for
	# non-packages.

	array set arch {}
	foreach x $pp {
	    if {[$x type] eq "package"} {
		if {![teapot::version::valid [$x version]]} {$x reversion 0}
		set arch([$x identity]) [list [$x getfirst platform] [$x instance]]
	    }
	    $x destroy
	}

	# Anything not listed in 'pp' is given the default
	# architecture of 'tcl'.

	set hastcl 0
	array set have {}
	foreach {p v} $packages {
	    set id ${p}-$v

	    if {[info exists have($id)]} continue
	    set have($id) .

	    if {[info exists arch($id)]} {
		set a [lindex $arch($id) 0]
		unset arch($id)
	    } else {
		set a tcl
	    }

	    log::debug "++pa package $p $v $a"

	    set instance [teapot::instance::cons package $p $v $a]
	    $db enter $instance
	    $db set   $instance [list platform $a profile .]
	    if {$p eq "Tcl"} {set hastcl 1}
	}

	# Insert everything from 'pp' not yet listed by 'packages'.

	foreach id [array names arch] {
	    set instance [lindex $arch($id) 1]

	    log::debug "++pp $instance"

	    teapot::instance::split $instance e n v a
	    $db enter $instance
	    $db set   $instance [list platform $a profile .]
	    if {$n eq "Tcl"} {set hastcl 1}
	}

	# Create an artificial entry for Tcl itself if the prefix
	# files did not list it among its packages.

	if {!$hastcl} {
	    log::debug Scan/Pseudo-Tcl
	    $self PseudoTcl
	}

	return
    }

    method PseudoTcl {} {
	if {[catch {
	    set v [$self DigForTclVersion]
	}]} {
	    # Unidentifiable version. Falling back to our own version.
	    set v [info tclversion]
	}

	set instance [teapot::instance::cons package Tcl $v tcl]
	$db enter $instance
	$db set   $instance {platform tcl profile .}
	return
    }

    method DigForTclVersion {} {
	log::debug "$self DigForTclVersion"

	if {![Mount $prefix]} {
	    return -code error Should_Not_Happen
	}
	set libdirs [glob -nocomplain -directory $prefix/lib {tcl[0-9]*}]
	vfs::unmount $prefix

	if {![llength $libdirs]} {
	    log::error         {nothing found}
	    return -code error {nothing found}
	} elseif {[llength $libdirs] > 1} {
	    # Take smallest version found of many. But not
	    # single-digit versions.
	    set libdir [lsort -dict $libdirs]
	}

	while {1} {
	    regsub -all {^tcl} [file tail [lindex $libdirs 0]] {} v
	    if {[string match *.* $v]} break
	    # Single digit version, ignore, take next
	    set libdirs [lrange $libdirs 1 end]
	    # No next, same as if empty.
	    if {![llength $libdirs]} {
		log::error         {nothing found}
		return -code error {nothing found}
	    }
	}

	log::debug "= $v"

	if {[package vcompare $v 8.4] < 0} {
	    log::debug "clamped to 8.4 minimum"
	    set v 8.4
	}

	#puts "Dig=$v"
	return $v
    }

    method ScanAP {} {
	global tcl_platform

	# Scan only once.

	if {$scanned} return

	# Several methods.
	# (1) Retrieve data from an embedded teapot.txt file
	#     describing the basekit in terms of a package.
	# (2) Use file type information to determine the platform.
	# (3) At last fall back to identifying the platform based on
	#     the kit name (path name). Failing that we go with
	#     standard values which are likely wrong. The patterns for
	#     that are those used by us in the names of our basekits.

	if {![Mount $prefix]} return

	# Method (1)
	set md [file join $prefix teapot.txt]
	set pp {}

	if {[file exists $md]} {
	    set pp [teapot::metadata::read::fileEx $md single errors]

	    # pp is empty in case of errors. We fall back to (2) in
	    # that case, see below.
	}

	vfs::unmount $prefix
	set scanned 1

	if {[llength $pp]} {
	    set pp [lindex $pp 0]
	    teapot::instance::split [$pp instance] _ _ _ architecture
	    $pp destroy

	    log::debug "architecture = $architecture (meta data)"

	    if {[string match win* $architecture]} {
		set platform windows
	    } else {
		set platform unix
	    }

	    return
	}

	# Method (2). Match on file type.

	if {[PerFileType $prefix architecture platform]} return

	# Method (3). Check path name for patterns.

	if {[PathPattern $prefix architecture platform]} return

	# Defaults based on the wrapper application itself.

	set architecture [platform::identify]

	log::debug "architecture = $architecture (identify)"

	set platform     $tcl_platform(platform)
	return
    }

    # ### ### ### ######### ######### #########

    proc PerFileType {prefix av pv} {
	upvar 1 $av architecture $pv platform

	set type [fileutil::magic::filetype $prefix]
	log::debug "file type = $type"

	# We try to determine cpu and os separately. And for whichever
	# we fail we additionally look at the name of the prefix for
	# more hints.

	set os  unknown
	set cpu unknown
	set pla unknown

	# Note: Merced is bigendian, IA64 little-endian. We made no
	# difference in our basekits (be is hpux, le is linux).
	# Java - That is how tcllib magic::filetype identifies macosx universal!

	foreach {rule xcpu} {
	    {*32-bit* *ARM* *LSB*}               arm
	    {*32-bit* *ARM* *MSB*}               arm_be
	    {*32-bit* *MIPS*}                    mips
	    {*32-bit* *PA-RISC*}                 parisc
	    {*32-bit* *PowerPC*}                 powerpc
	    {*32-bit* *S/390*}                   s390
	    {*32-bit* *SPARC*}                   sparc
	    {*32-bit* {*Intel 80386*}}           ix86
	    {*64-bit* *Alpha*}                   alpha
	    {*64-bit* *IA-64*}                   ia64
	    {*64-bit* *Intel* *Merced*}          ia64
	    {*64-bit* *MIPS*}                    mips64
	    {*64-bit* *S/390*}                   s390x
	    {*64-bit* *x86-64*}                  x86_64
	    {*64-bit* {*cisco 7500*}}            powerpc64
	    {*COFF* *alpha*}                     alpha
	    {*MS-DOS*}                           ix86
	    {*MacBinary*}                        universal
	    {*Mach-O*i386*}                      ix86
	    {*Mach-O*ppc*}                       powerpc
	    {*PA-RISC1.1*}                       parisc
	    {*PA-RISC2.0*}                       parisc
	    {{*MS Windows*}}                     ix86
	    {{*RISC System/6000*}}               powerpc
	    {{*compiled Java class data*}}       universal
	} {
	    if {[PFTMatch $rule $type]} {
		log::debug "match cpu ($rule)"
		set cpu $xcpu
		break
	    }
	}

	foreach {rule p xos} {
	    {*FreeBSD*}                    unix    freebsd
	    {*Linux*}                      unix    linux
	    {*MS-DOS*}                     windows win32
	    {*MacBinary*}                  macos   macos
	    {*Mach-O*}                     unix    macosx
	    {{*MS Windows*}}               windows win32
	    {{*compiled Java class data*}} unix    macosx
	} {
	    if {[PFTMatch $rule $type]} {
		log::debug "match platform/os ($rule)"
		set pla $p
		set os  $xos
		break
	    }
	}

	if {$cpu eq "unknown"} {
	    foreach {pattern xcpu} {
		*alpha*  alpha
		*arm_be* arm_be
		*arm*    arm
		*hppa*   parisc
		*ia64*   ia64
		*macos-fat* universal
		*mips*   mips
		*n770*   arm
		*ppc64*  powerpc64
		*ppc*    powerpc
		*univ*   universal
		*x86_64* x86_64
		*x86*    ix86
	    } {
		if {[string match *${pattern}* $prefix]} {
		    log::debug "match cpu:filename ($rule)"
		    set cpu $cpu
		    break
		}
	    }
	}

	if {$os eq "unknown"} {
	    foreach {pattern p xos} {
		*aix*           unix aix
		*bsdos*         unix bsdos
		*darwin*	unix macosx
		*freebsd*       unix freebsd
		*hpux*          unix hpux
		*irix*          unix irix
		*linux-glibc2.0* unix linux-glibc2.0
		*linux-glibc2.1* unix linux-glibc2.1
		*linux-glibc2.2* unix linux-glibc2.2
		*linux-glibc2.3* unix linux-glibc2.3
		*linux*         unix linux
		*macos-fat*     macos macos
		*netbsd*	unix netbsd
		*openbsd*	unix openbsd
		*osf1*		unix osf1
		*solaris-sparc-2.8* unix solaris2.8
		*solaris2.10*   unix solaris2.10
		*solaris2.6*    unix solaris2.6
		*solaris2.8*    unix solaris2.8
		*solaris*	unix solaris
		*win32*		windows win32
		*win64*		windows win64
	    } {
		if {[string match *${xos}* $prefix]} {
		log::debug "match platform/os:filename ($rule)"
		    set pla $p
		    set os  $xos
		    break
		}
	    }
	} elseif {$os eq "linux"} {
	    # For plain linux we try to find out more via the
	    # filename. If we can't we fake the highest glibc, to
	    # match as much as possible.
	    set found 0
	    foreach {pattern xos} {
		*linux-glibc2.0* linux-glibc2.0
		*linux-glibc2.1* linux-glibc2.1
		*linux-glibc2.2* linux-glibc2.2
		*linux-glibc2.3* linux-glibc2.3
	    } {
		if {[string match *${xos}* $prefix]} {
		    log::debug "match os:linux ($xos)"
		    set os $xos
		    set found 1
		    break
		}
	    }
	    if {!$found} {
		set os linux-glibc2.3
	    }

	} elseif {$os eq "solaris"} {
	    # For plain solaris we try to find out more via the
	    # filename. If we can't we fake the highest solaris
	    # version to match as much as possible.
	    set found 0
	    foreach {pattern xos} {
		*solaris2.6*  solaris2.6
		*solaris2.7*  solaris2.7
		*solaris2.8*  solaris2.8
		*solaris2.9*  solaris2.9
		*solaris2.10* solaris2.10
	    } {
		if {[string match *${xos}* $prefix]} {
		    log::debug "match os:solaris ($xos)"
		    set os $xos
		    set found 1
		    break
		}
	    }
	    if {!$found} {
		set os solaris2.10
	    }
	}

	if {$os eq "unknown" && $cpu eq "unknown"} {return 0}

	set architecture ${os}-${cpu}
	set platform     $pla

	log::debug "filetype matched $architecture"
	return 1
    }

    proc PFTMatch {rule type} {
	foreach r $rule {
	    if {![string match $r $type]} {return 0}
	}
	return 1
    }

    proc PathPattern {prefix av pv} {
	upvar 1 $av architecture $pv platform

	#!DANGER!NOTE!HACK!
	# Order of patterns: Most common first.

	foreach {pattern p a} {
	    win32-ix86        windows win32-ix86
	    linux-ix86        unix    linux-glibc2.2-ix86
	    solaris-sparc     unix    solarisc2.6-sparc
	    macosx-universal  unix    macosx-universal

	    macosx10.5-i386-x86_64  unix macosx10.5-i386-x86_64

	    win32-x64         windows win32-x86_64
	    linux-x86_64      unix    linux-glibc2.3-x86_64
	    hpux-parisc       unix    hpux-parisc
	    macosx-powerpc    unix    macosx-powerpc
	    macosx-ix86       unix    macosx-ix86
	    solaris-sparc-2.8 unix    solaris2.8-sparc
	    aix-rs6000        unix    aix-powerpc
	    solaris-ix86      unix    solaris2.10-ix86
	    linux-ia64        unix    linux-glibc2.3-ia64
	    hpux-ia64         unix    hpux-ia64
	    freebsd-ix86      unix    freebsd-ix86
	} {
	    if {[string match *${pattern}* $prefix]} {

		log::debug "architecture = $architecture (file pattern $pattern)"

		set architecture $a
		set platform     $p
		return 1
	    }
	}

	return 0
    }

    # ### ### ### ######### ######### #########

    proc Mount {prefix} {
	if {[lsearch -exact [fileutil::fileType $prefix] metakit] < 0} {
	    return 0
	} elseif {[catch {
	    # The prefix is only read, not modified. We are mounting
	    # it read-only expressing this, and to allow the input to
	    # be a non-writable file too.

	    vfs::mk4::Mount $prefix $prefix -readonly
	} msg]} {
	    return 0
	}
	return 1
    }

    proc DeferOn  {} {upvar 1 defer defer ; set defer 1 ; return}
    proc DeferOff {} {upvar 1 defer defer ; set defer 0 ; return}

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable db             ; # object (pkg::mem) - Instance database
    variable prefix         ; # copy of options(-prefix)

    variable scanned      0 ; # Bool flag. True iff arch/plat are valid.
    variable architecture
    variable platform

    method cget-location {args} {
	return "prefix ($prefix)"
    }

    variable defer 0 ; # Set if job deferal is active.
    variable jobs    ; # object (jobs) - Defered jobs when doing async init.

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Register us at the central type auto-detection.

::repository::api registerForAuto ::repository::prefix

# ### ### ### ######### ######### #########
## Ready
return
