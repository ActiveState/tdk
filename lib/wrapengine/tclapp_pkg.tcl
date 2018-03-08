# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_pkg.tcl --
# -*- tcl -*-
#
#	Package database.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.

#
# RCS: @(#) $Id: tdkwrap.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

# ### ### ### ######### ######### #########
## Requirements

package require fileutil
package require pref::devkit           ; # Preference access.
package require repository::api        ; # Generic repository processing
package require repository::localma    ; # Transparent local repositories
package require repository::mem        ; # Wholly in-memory, virtual base.
package require repository::pool       ; # Pool of files as repository.
package require repository::prefix     ; # Prefix file as repository
package require repository::provided   ; # Data extraction from prefix.
package require repository::resolve    ; # Package resolver
package require repository::tap        ; # Tap compat repositories
package require repository::union      ; # Aggregating repository.
package require tclapp::misc           ; # General wrap database
package require tclapp::msgs           ; # Message pool
package require tclapp::pkg::pool      ; # Container of resolution results and options.
package require tclapp::files
package require tclapp::tappkg
package require teapot::config         ; # Teapot client configuration access.
package require teapot::instance       ; # Instance handling
package require teapot::metadata       ; # MD accessors
package require teapot::metadata::read ; # MD extraction
package require teapot::redirect       ; # Redirection handling.
package require teapot::reference      ; # Reference handling
package require zipfile::decode        ; # Zip archive expansion

namespace eval tclapp::pkg {
    namespace import ::tclapp::msgs::get
    rename                           get mget
}

# ### ### ### ######### ######### #########
## Implementation

# ### ### ### ######### ######### #########
## Convert command line package references into standard
## references. This includes checking that the package does exist, and
## possible rewriting the reference to recover from bad version
## numbers, or bogus package names which may float around in projects
## made with older releases of TDK.

proc ::tclapp::pkg::applocation! {} {
    variable location
    variable applocation
    set applocation $location
    return
}

proc ::tclapp::pkg::deref {isapp package ev rv} {
    variable location
    upvar 1 $ev errors $rv recoverable

    # Generate basic regular reference, no modifications.

    set type [Split $package name version ref]

    # Locate the package in the system.

    if {[Locate $isapp $ref]} {
	return $ref
    }

    # Failed. Go into recovery mode and try some different
    # combinations. Attempts are based on type of original reference.

    # (a) name
    #
    # n1. Try to map old to new name via tap_upgrade information.
    #
    # (b) exact
    #
    # v1. Name only (maybe a different version)
    # v2. map name via tap_upgrade, then name+version
    # v3. map name via tap_upgrade, then name only.

    if {$type eq "name"} {
	# (a) n1
	if {![TapUpgrade $name newname]} {Fail $name ; return}
	set newref [list $newname]
	if {![Locate $isapp $newref]}    {Fail $name ; return}

	Recover $package $newname
	return $newref
    }

    # (b) v1 - strip version, find any ...

    set newref [list $name]
    if {[Locate $isapp $newref]} {
	Recover $package ${name}-[lindex [lindex $location 0] 1]
	return $newref
    }

    # (b) v2 - upgrade name, search for with version.

    if {![TapUpgrade $name newname]} {Fail $name ; return}

    set newref [list $newname -version $version -exact 1]
    if {[Locate $isapp $newref]} {
	Recover $package ${name}-[lindex [lindex $location 0] 1]
	return $newref
    }

    # b (v3) - strip version, use only the new name

    set newref [list $newname]
    if {![Locate $isapp $newref]} {Fail $name ; return}

    Recover $package ${name}-[lindex [lindex $location 0] 1]
    return $newref
}

proc ::tclapp::pkg::reset {} {
    variable resolver
    variable rprefix
    variable pool

    Initialize

    foreach k [array names resolver] {
	$resolver($k) destroy
	unset resolver($k)
    }

    # Notes:
    #
    # We keep the teapot default repository. Any changes there we will
    # see automatically on the next query.
    #
    # The prefix repository we have to get rid of, it may change from
    # run to run.
    #
    # The tap repository may change as well, however it automatically
    # re-scans all directories whenever something was not found on the
    # first try. As only new and modified files are read and parsed
    # the only time taken if nothing is new is a directory deep scan.
    # This is acceptable.

    if {$rprefix ne ""} {
	$rprefix destroy
	set rprefix ""
    }

    $pool clear
    return
}


# Belongs into special package
proc tclapp::pkg::toref {package} {
    set t [Split $package __ __ ref]
    ::teapot::reference::completetype ref package

    log::log debug "P($package) => R($ref) /$t"
    return $ref
}

proc tclapp::pkg::Split {package nv vv rv} {
    upvar 1 $nv name $vv version $rv ref

    log::log debug "Split ($package)"

    set n {} ; # Local results, use for all internals
    set v {} ; # calculations. Prevent badness for
    #        ; # nv and vv refering to the same var.

    if {![regexp {^(.*)(-([0-9]+((\.[0-9]+)*)))$} $package -> n __ v __ __]} {
	# Format is name, name may contain dashes. No version at the end.

	log::log debug "  not matching name-version"

	set version {}
	set name    $package
	set ref [teapot::reference::cons $name -is package]
	return name
    }

    # Format is 'name-version'. name may contain dashes.

    set version $v
    set name    $n

    if {$v eq ""} {
	log::log debug "  empty version"

	set ref [teapot::reference::cons $n -is package]
	return name
    }

    log::log debug "  versioned"

    set ref [teapot::reference::cons $n -version $v -exact 1 -is package]
    return exact
}

proc tclapp::pkg::Locate {isapp ref} {
    variable location

    set resolver [GetResolver $isapp]
    set res [$resolver find $ref]

    # res = dict (instance -> repolist)/1
    #     = list (instance repolist)
    # Save for access outside ...

    if {[llength $res]} {
	set location $res
	return 1
    }
    return 0
}

proc ::tclapp::pkg::TapUpgrade {name nv} {
    variable tapchanges
    upvar 1 $nv newname

    if {[info exists tapchanges($name)]} {
	set newname $tapchanges($name)
	return 1
    }

    return 0
}

namespace eval ::tclapp::pkg {
    ## Hardwired database of package names which changed
    ## in the supplied tap files from 2.6 to the new version
    ## because of changes in the generation ... We map from
    ## old (as we may encounter them) to the new name of the
    ## same package.

    variable tapchanges ; array set tapchanges {
	bwidget		BWidget
	tclcompiler	compiler
	tcldomxml	dom::libxml2
	img		Img
	itcl		Itcl
	itk		Itk
	memchan		Memchan
	mk4tcl		Mk4tcl
	tclparser	parser
	tclexpat	xml::expat
	tclx		Tclx
	tclxslt		xslt
	tkhtml		Tkhtml
	trf		Trf
    }
}

proc ::tclapp::pkg::Fail {name} {
    upvar 1 errors errors

    lappend errors [format [mget 500_UNKNOWN_PACKAGE] $name]
    return
}

proc ::tclapp::pkg::Recover {old new} {
    upvar 1 recoverable recoverable 

    lappend recoverable \
	[format [mget 502_UNKNOWN_PACKAGE_RESOLVED] $old $new]
    return
}

proc ::tclapp::pkg::GetResolver {isapp} {
    variable resolver
    if {[info exists resolver($isapp)]} {
	return $resolver($isapp)
    }

    foreach {arch platform} [PrefixPlatform] break
    set r [repository::resolve %AUTO% $arch $platform]

    if {!$isapp && ([tclapp::misc::prefix?] ne "")} {
	$r add-archive 1 [PrefixRepository]
    }

    $r add-archive 0 [TapRepository]
    $r add-archive 0 [TeapotDefault]

    set resolver($isapp) $r
    return $r
}

proc ::tclapp::pkg::PrefixPlatform {} {
    global tcl_platform
    variable localarch

    # TODO
    # Option to override: -platform for arch, platform derived.

    if {[tclapp::misc::prefix?] ne ""} {
	# A prefix is defined. Try to extract the arch/platform
	# information from it. We use its repository for that.

	set r [PrefixRepository]

	set arch     [$r architecture]
	set platform [$r platform]

    } else {
	# Default information, from tcl version and system
	# identification of the wrapper. This can be completely
	# different from the actual arch/platform of the basekit. If
	# there is any.

	# This can prevent x-platform wrapping. Override with option,
	# s.a.

	set arch     $localarch
	set platform $tcl_platform(platform)
    }

    return [list $arch $platform]
}

proc ::tclapp::pkg::PrefixRepository {} {
    variable rprefix
    if {$rprefix eq ""} {
	set rprefix [repository::prefix %AUTO% \
			 -location [::tclapp::misc::prefix?]]
    }
    return $rprefix
}

proc ::tclapp::pkg::TapRepository {} {
    variable rtap
    if {$rtap eq ""} {
	set installdir [file dirname [file dirname $starkit::topdir]]
	set rtap       [repository::tap %AUTO% -location $installdir]
    }
    return $rtap
}

proc ::tclapp::pkg::TeapotDefault {} {
    variable rdefault
    if {$rdefault eq ""} {
	set rdefault [::repository::localma %AUTO% \
			  -location [[TeapotConfig] default get]]
    }
    return $rdefault
}

proc ::tclapp::pkg::VirtualBase {} {
    variable rvirtual
    if {$rvirtual eq ""} {
	set rvirtual [::repository::mem %AUTO%]

	set instance [teapot::instance::cons package Tcl [info tclversion] tcl]
	$rvirtual enter $instance
	$rvirtual set   $instance {
	    platform    tcl
	    profile     .
	    description {Tcl core}
	}

	set instance [teapot::instance::cons package Tk [info tclversion] tcl]
	$rvirtual enter $instance
	$rvirtual set   $instance {
	    platform    tcl
	    profile     .
	    description {Tk core}
	}

	# Bugzilla 71637. Add the starkit support packages to the
	# virtual base, as we can expect them to be present as well in
	# a system running a starkit. Either through a basekit/tclkit,
	# or packages known to tclsh/wish.

	foreach n {
	    Mk4tcl vfs::mk4
	    Vfs    vfs    vfslib
	    starkit
	} {
	    set instance [teapot::instance::cons package $n 1.0 tcl]
	    $rvirtual enter $instance
	    $rvirtual set   $instance {
		platform    tcl
		profile     .
		description {Starkit support}
	    }
	}
    }
    return $rvirtual
}

proc ::tclapp::pkg::PackageFiles {} {
    variable rfiles
    variable pool

    Initialize

    if {$rfiles eq ""} {
	set rfiles [::repository::pool %AUTO% $pool]
    }
    return $rfiles
}

proc ::tclapp::pkg::TeapotConfig {} {
    variable tc
    if {$tc eq ""} {
	set tc [teapot::config tc]
    }
    return $tc
}

namespace eval ::tclapp::pkg {
    # instance and list of repositories for last reference run through
    # 'Locate'.
    # . dict (instance -> repolist)/1
    # = list (instance repolist)

    # Ditto for the application.

    variable location    {}
    variable applocation {}

    # Cache of resolver objects for package resolution.
    # Also caches of various repositories
    #
    # The repositories Tclapp looks at are
    #
    #                             | App | Pkg |
    # Prefix repository           |     | y   |
    # Tap repository              | y   | y   |
    # Default TEAPOT repository   | y   | y   |
    # Explicit package files      | y   | y   |
    # Configured archives         | y   | y   |
    # Virtual base                | y   | y   |

    variable  resolver
    array set resolver {}

    variable rprefix  {}
    variable rtap     {}
    variable rdefault {}
    variable rfiles   {}
    variable rvirtual {}

    # Teapot Configuration

    variable tc {}
}

# ### ### ### ######### ######### #########
##

proc ::tclapp::pkg::wrapFile {pname pversion src dst} {
    set verbose [tclapp::misc::verbose?]

    # Distinguish 3 cases

    # 1. Zip archive.
    # 2. Tcl Module with attached Metakit filesystem
    # 3. Tcl Module without attached Metakit filesystem

    # (Ad 1) Mount as filesystem, copy all files into the dst.
    # (ad 2) Mount as fs, copy all files into dir. copy prefix code
    #        as separate file, create pkgIndex for it.
    # (Ad 3) Generate pkgIndex for it and copy into dst dir

    set mtypes [fileutil::magic::mimetype $src]
    if {[lsearch -exact $mtypes "application/zip"] >= 0} {
	# Ad (1) Zip archive.

	if {$verbose} {
	    log::log info "    Zip archive"
	    log::log info "      Unpacking"
	}

	zipfile::decode::open $src
	set zdict [zipfile::decode::archive]

	if {$verbose} {log::log info "      Copying contents"}

	zipfile::decode::unzip $zdict $dst
	zipfile::decode::close

	# No, we do not keep the meta data if we can help it. That is
	# what teapot_provided.txt is for, and under user control.

	catch {file delete [file join $dst teapot.txt]}

	# Consider updateInPlace and special command for this.
	set lines [split [fileutil::cat $dst/pkgIndex.tcl] \n]
	set start [lsearch -glob $lines {*@@ Meta Begin*}]
	set stop  [lsearch -glob $lines {*@@ Meta End*}]

	log::log debug "Meta data begins on line: $start"
	log::log debug "Meta data ends on line:   $stop"

	if {($start >= 0) && ($stop >= 0) && ($start < $stop)} {
	    log::log info "      Cutting out the meta data"

	    fileutil::writeFile $dst/pkgIndex.tcl \
		[join [lreplace $lines $start $stop] \n]\n
	} else {
	    log::log info "      No meta data to cut"
	}

    } else {
	# Ad (2,3) Tcl Module.

	set entry implementation.tcl

	if {$verbose} {log::log info "    Tcl Module"}

	# Strip the block of data which was inserted by the package
	# generator. See above, about not keeping meta data if
	# possible. Note that we do not strip the entire header
	# created by the package generator. Requirements and
	# declaration block are still needed for execution.

	set lines [split [fileutil::cat -eofchar \x1A $src] \n]
	set start [lsearch -glob $lines {*@@ Meta Begin*}]
	set stop  [lsearch -glob $lines {*@@ Meta End*}]
	set del 0
	set kitsrc $src

	if {($start >= 0) && ($stop >= 0) && ($start < $stop)} {
	    set t [fileutil::tempfile tclapp]
	    fileutil::writeFile $t [join [lreplace $lines $start $stop] \n]\n
	    set src $t
	    set del 1
	}

	if {[lsearch -exact [fileutil::fileType $kitsrc] metakit] >= 0} {
	    # (Ad 2) With attached metakit filesystem. Mount and copy.

	    if {$verbose} {log::log info "      Copying attached filesystem"}

	    # readonly! Because we do not modify, and the temp files
	    # will be set ro too, and writable mounting would fail
	    # due to that.

	    vfs::mk4::Mount  $kitsrc $kitsrc -readonly
	    file copy -force $kitsrc $dst
	    vfs::unmount     $kitsrc

	    # Assuming that the TM+fs was generated by the pkggen
	    # (teapot-pkg) the code coming before the fs is generated
	    # stuff to setup the fs. This code we throw away, as it
	    # does stuff the expanded form here has no need of. This
	    # file is like a zip archive, just a different format.

	    # The generator now marks which code is needed for the fs
	    # setup, meaning we can now throw exactly this part away,
	    # and the remainder can be used as general prolog, as seen
	    # in the zip. pkgIndex.tcl (load command). This goes in
	    # front of the main.tcl

	    set lines [split [fileutil::cat -eofchar \x1A $src] \n]
	    set start [lsearch -glob $lines {*TEAPOT-PKG BEGIN TM_STARKIT_PROLOG*}]
	    set stop  [lsearch -glob $lines {*TEAPOT-PKG END TM_STARKIT_PROLOG*}]

	    if {($start >= 0) && ($stop >= 0) && ($start < $stop)} {
		fileutil::insertIntoFile $dst/main.tcl 0 [join [lreplace $lines $start $stop] \n]\n
	    }

	    # We parameterize the code generating the package index
	    # (see below (**)) to jump directly to 'main.tcl'. That
	    # file contains the load script of the module and is what
	    # the TM startup code we threw away jumped to. Note that
	    # we do not have enough information in the meta data of
	    # the TM to generate a truly nice index script, all that
	    # information is gone, so we have to make do with a simple
	    # one.

	    set entry main.tcl

	} else {
	    # (Ad 3) Without attached metakit filesystem.

	    if {$verbose} {log::log info "    Copying as is"}

	    file mkdir $dst
	    file copy $src [file join $dst $entry]
	}

	if {$del} {
	    # Clean up the temp file needed to strip the teapot-pkg block.
	    file delete $src
	}

	# (**) Generate package index.

	if {$verbose} {log::log info "      Generating package index"}

	# NOTE: The load command generated for the 'package ifneeded'
	# statement below has to be kept in sync with the code
	# generated by the UnknownHandler in tm.tcl, and the
	# extraction code in platform::shell (procedure 'LOCATE').

	set   ch [open [file join $dst pkgIndex.tcl] w]
	puts $ch [string map \
		      [list NAME $pname VER $pversion ENTRY $entry] \
		      {package ifneeded {NAME} VER "package provide {NAME} VER;[list source [file join $dir ENTRY]]"}]
	close $ch
    }

    if {$verbose} {
	log::log info "    Ok."
	::log::log info " "
    }
}


# ### ### ### ######### ######### #########
## Pool of package files. Coming in through resolution or explicit
## specification by the user. For external files report troubles.

proc ::tclapp::pkg::pkg {args} {
    variable pool
    Initialize
    return [eval [linsert $args 0 $pool]]
}

proc ::tclapp::pkg::enterExternals {paths ev rv dv} {
    upvar 1 $ev errors $rv references $dv display

    set verbose [tclapp::misc::verbose?]
    foreach f $paths {
	# Get the package name and version from its meta data.  Report
	# errors if there is trouble.

	if {![fileutil::test $f efr msg "Package file"]} {
	    lappend errors $msg
	    continue
	}

	set perrors {}
	set fail [catch {
	    ::teapot::metadata::read::file $f single perrors
	} msg]
	if {$fail} {
	    lappend errors "Package file \"$f\": $msg"
	    return 0
	} elseif {[llength $perrors]} {
	    foreach e $perrors {lappend errors $e}
	    return 0
	}

	set pkg      [lindex $msg 0]
	set instance [$pkg instance]
	set etype    [$pkg type]

	unset -nocomplain md
	array set         md [$pkg get]

	set isprofile [expr {
	     [string equal $etype profile] ||
	     ([string equal $etype package] && [info exists md(profile)])
	 }]

	# Check for and expand profile instances.

	if {$isprofile} {
	    log::log info "P   $instance ..."

	    if {[info exists md(require)]} {
		set first 1
		foreach ref $md(require) {
		    lappend references $ref

		    if {$verbose && $first} {log::log info " "}
		    if {$verbose}           {log::log info "      $ref"}
		    set first 0
		}
	    }
	    lappend display [list 1 $instance "F $f"]
	    continue
	}

	# Regular instances are recorded for wrapping.

	pkg enter $instance $f

	lappend display [list 0 $instance "F $f"]
    }
    return 1
}

proc ::tclapp::pkg::enterInternal {instance path} {
    # Internal file, i.e. resolved in the engine, we are responsible
    # for the cleanup.

    pkg enter $instance $path
    return
}

# ### ### ### ######### ######### #########

proc ::tclapp::pkg::expandInstances {iserr instances recommend rv sv} {
    variable ALL
    upvar 1 $rv references $sv state

    set verbose [tclapp::misc::verbose?]
    set tag     [expr {$iserr ? "*" : "-"}]

    set has 0
    foreach instance $instances {
	if {$verbose && $has} {log::log info " "}
	log::log info "$tag   $instance ..."
	set has 0
	set dep {}
	if {[catch {$ALL sync require $instance} dep]} continue
	set first 1
	foreach d $dep {
	    ::teapot::reference::completetype d package
	    if {[info exists state($d)]} continue
	    lappend references $d
	    if {$verbose && $first} {log::log info " "}
	    if {$verbose}           {log::log info "      Required    $d"}
	    set has 1
	    set first 0
	}
	if {!$recommend} continue
	set dep {}
	if {[catch {$ALL sync recommend $instance} dep]} continue
	set first 1
	foreach d $dep {
	    ::teapot::reference::completetype d package
	    if {[info exists state($d)]} continue
	    lappend references $d
	    if {$verbose && $first} {log::log info " "}
	    if {$verbose}           {log::log info "      Recommended $d"}
	    set has 1
	    set first 0
	}
    }
    if {$verbose && $has} {log::log info " "}
    return
}

proc ::tclapp::pkg::expandReferences {iserr references ev rv wv sv dv tv} {
    upvar 1 $ev errors $rv recoverable $wv warnings $sv state $dv display $tv tap
    set instances  {}

    foreach ref $references {
	# Ignore references we have handled before.
	if {[info exists state($ref)]} continue
	set state($ref) .
	expandOneReference $ref $iserr errors recoverable warnings display instances tap
    }

    return $instances
}

proc ::tclapp::pkg::expandOneReference {ref iserr ev rv wv dv iv tv} {
    upvar 1 $ev errors $rv recoverable $wv warnings $dv display $iv instances $tv tap

    log::log debug "Standard ..."

    set matches [Find $ref]
    if {[llength $matches]} {
	Record $ref $matches
	return 1
    }

    # If the reference was for a package and it was not found we check if there
    # is a profile with that name.

    if {[::teapot::reference::entity $ref package] eq "package"} {
	log::log debug "Recheck for profile ..."

	set ref [::teapot::reference::normalize1 [linsert $ref end -is profile]]
	set matches [Find $ref]
	if {[llength $matches]} {
	    Record $ref $matches
	    return 1
	}

	log::log debug "Recheck for redirection ..."
	set ref [::teapot::reference::normalize1 [linsert $ref end -is redirect]]
	set matches [Find $ref]
	if {[llength $matches]} {
	    Record $ref $matches
	    return 1
	}
    }

    # HACK - If, and only if the package/profile was not found in the
    # specified TEAPOT repositories we search the .tap based old
    # system as well.  I.e. we are directly accessing the .tap files
    # without going through an emulation layer. If the package is
    # found there it is also properly inserted into the wrap
    # configuration using the TDK32 code.

    if {$iserr} {
	set suffix " (Specified, Not recoverable)"
	upvar 0 errors   messages
    } else {
	set suffix " (Dependency, Recoverable)"
	upvar 0 warnings messages
    }

    log::log debug "Falling back to TAP."

    # Name only ...

    if {[llength $ref] <= 1} {
    log::log debug "Name ..."

	if {[checkTap $ref $suffix messages display tap recoverable]} {
	    return 1
	}
	lappend messages [format [mget 500_UNKNOWN_PACKAGE] $ref]$suffix
	return 0
    }

    log::log debug "Remove search restrictions ..."

    # Strip version and other qualifiers, then search again.
    set newref [list [lindex $ref 0]]
    set matches [Find $newref]
    if {[llength $matches]} {
	Record $ref $matches
	lappend recoverable \
	    [format [mget 502_UNKNOWN_PACKAGE_RESOLVED] $ref $newref]
	return 1
    }

    # Extended search failed as well, now go to .tap

    if {[checkTap $ref $suffix messages display tap recoverable]} {
	return 1
    }

    lappend messages [format [mget 500_UNKNOWN_PACKAGE] $ref]$suffix
    return 0
}

proc ::tclapp::pkg::checkTap {ref suffix mv dv tv rv} {
    variable architectures
    upvar 1 $mv messages $tv tap $dv display $rv recoverable

    if {![tclapp::tappkg::Initialized]} {
	log::log info "Reading .tap files ..."

	# We are in the wrapping process, UI shows the log.
	# Activating feedback makes sense.
	tclapp::tappkg::Initialize 1

	log::log info "Done"
    }

    set t [teapot::reference::type $ref n v]

    set oldarch [tclapp::tappkg::2platform $architectures]

    if {![llength $oldarch]} {
	# If we could not map the requested architectures to old-style
	# names then we will not tap files for it, and can bail out
	# early.

	lappend messages \
	    [format [::tclapp::msgs::get 510_UNKNOWN_ARCHITECTURES] $architectures]$suffix
	return 0
    }

    switch -exact -- $t {
	name    {return [checkTapOldRef $n      $suffix $oldarch messages display tap recoverable]}
	exact   {return [checkTapOldRef ${n}-$v $suffix $oldarch messages display tap recoverable]}
	version {
	    foreach req $v {
		if {[llength $req] == 1} {
		    if {[checkTapOldRef ${n}-$req $suffix $oldarch messages display tap recoverable]} {
			return 1
		    }
		} elseif {[llength $req] == 2} {
		    foreach {min max} $req break
		    if {[checkTapOldRef ${n}-$min $suffix $oldarch messages display tap recoverable]} {
			return 1
		    }
		}
	    }
	}
    }
    return 0
}


proc ::tclapp::pkg::checkTapOldRef {ref suffix platforms mv dv tv rv} {
    upvar 1 $mv messages $tv tap $dv display $rv recoverable

    set token [tclapp::tappkg::locate $ref]

    ::log::log debug "== -pkg: ($token)"

    if {$token == {}} {
	::log::log debug "== -pkg: fuzz?"

	# Basic lookup failed. Now try a fuzzy search by checking if
	# the package needs a name change or if there is a version
	# mismatch.

	set ok 0
	set  newname [tclapp::tappkg::locate-fuzzy $ref]

	::log::log debug "== -pkg: fuzzed '$newname'"

	if {$newname != {}} {
	    set token [tclapp::tappkg::locate $newname]

	    ::log::log debug "== -pkg: fuzzed token '$token'"

	    if {$token != {}} {
		# Remember this as error/warning to show the user later ...
		lappend recoverable \
		    "[format [::tclapp::msgs::get 502_UNKNOWN_PACKAGE_RESOLVED] $ref $newname] (Recoverable)"
		set ok 1
	    }
	}
	if {!$ok} {
	    return 0
	}
    }

    ::log::log debug "== -pkg: ($token)"
    ::log::log debug "== -pkg: name     '[tclapp::tappkg::name     $token]'"
    ::log::log debug "== -pkg: version  '[tclapp::tappkg::version  $token]'"
    ::log::log debug "== -pkg: platform '[tclapp::tappkg::platform $token]'"

    if {![struct::set contains $platforms \
	      [tclapp::tappkg::platform $token]]} {
	lappend messages \
	    [format [::tclapp::msgs::get 511_KNOWN_PACKAGE_PLATFORM_MISMATCH] \
		 $ref]

	lappend messages \
	    [format [::tclapp::msgs::get 512_PACKAGE_PLATFORM] \
		 [tclapp::tappkg::platform $token]]

	foreach p $platforms {
	    lappend messages \
		[format [::tclapp::msgs::get 513_ACCEPTED_PLATFORM] \
		     $p]
	}

	if {
	    ([llength $platforms] == 1) &&
	    ([lindex $platforms 0] eq "tcl")
	} {
	    lappend messages \
	        [::tclapp::msgs::get 514_MAYBE_NO_PREFIX]
	}
	return 0
    }

    set psrc [tclapp::tappkg::source $token]

    ::log::log debug "== -src: ($psrc)"

    set pseudoinstance [teapot::instance::cons package \
			    [tclapp::tappkg::name    $token] \
			    [tclapp::tappkg::version $token] {}]

    ::log::log debug "== ($pseudoinstance)"

    if {$psrc eq ""} {
	lappend display [list 0 $pseudoinstance {Static package, skip}]
    } else {
	lappend display [list 0 $pseudoinstance "TAP $psrc"]

	set ftoken [tclapp::tappkg::files $token]

	::log::log debug "== -files ($ftoken)"

	if {[struct::set contains $tap $ftoken]} {return 1}
	struct::set include tap $ftoken

	if {![tclapp::tappkg::hasFiles $ftoken]} {
	    lappend messages \
		[format [::tclapp::msgs::get 501_EMPTY_PACKAGE] $ref]$suffix
	    return 1
	}

	tclapp::files::addPkg messages \
	    [tclapp::tappkg::name      $ftoken][tclapp::tappkg::version $ftoken] \
	    [tclapp::tappkg::filesList $ftoken]
    }

    ::log::log debug "== OK."
    return 1
}


# mem deref without context, mem findref/bestall, see there too.
proc ::tclapp::pkg::Find {ref} {
    variable ALL
    variable architectures

    set matches {}
    foreach a $architectures {
	set ilist {}
	log::log debug "    Find ($ref) \[$a\]"
	if {[catch {
	    $ALL sync find [list $a] $ref
	} ilist]} {
	    log::log debug "INTERNAL ERROR"
	    foreach l [split $::errorInfo \n] {log::log error "INTERNAL ERROR    $l"}
	    continue
	}
	log::log debug OK
	foreach i $ilist {lappend matches $i}
	log::log debug "    [llength $ilist] [expr {[llength $ilist]==1 ? "match" : "matches"}]"

	# Should we stop the search here when we have matches ?  If we
	# don't the wrapper can pick up multiple instances for a
	# reference. This doesn't seem right at first glance.

	# OTOH, if the user specified multiple -architecture clauses
	# she may want us to pick all possible instances. The
	# canonical example would be a multi-platform starkit. So yes,
	# we do wish to continue.

	# This question came up when wrapping the Komodo/Linter on OSX
	# picked both -ix86 and -universal instances of a package, and
	# a -universal and tcl variant of another. This however was
	# more a problem with the .tap files we had. tcl/universal was
	# outdated. ix86/universal was a matter of order. The platform
	# was ix86, so it looked for that, and an additional pattern
	# for the platform is universal. Specifying universal
	# explicitly removed the ix86 from the search.

	# Hm. A two-class approach ? Use derived patterns only if the
	# main had no matches ? Except we do not have the information
	# to distinguish main from derived, only a simple list. For
	# now simply do not abort. We can do more complex stuff later,
	# if truly needed.

    }
    return $matches
}

proc ::tclapp::pkg::Record {ref matches} {
    upvar 1 instances instances
    foreach m $matches {
	# Matches are extended-instances, have to strip the profile
	# flag.

	lappend instances [lrange $m 0 3]
    }
    return
}

# ### ### ### ######### ######### #########

proc ::tclapp::pkg::enterInstances {iserr instances ev rv dv sv} {
    variable ALL
    upvar 1 $ev errors $rv references $dv display $sv state

    set verbose [tclapp::misc::verbose?]
    array set _ {}
    set tag     [expr {$iserr ? "P" : "p"}]

    set res {}
    foreach instance $instances {
	if {[info exists state($instance)]} continue
	set state($instance) .

	set ispec [::teapot::instance::2spec $instance]

	log::log debug "    Existence? List <$ispec>"

	if {[catch {$ALL sync list $ispec} r]} {
	    log::log debug "    Error <$r>"
	    lappend errors $r
	    continue
	} elseif {![llength $r]} {
	    log::log debug "    Unknown <$instance>"
	    lappend errors "Unknown package instance \"$instance\""
	    continue
	}

	teapot::instance::split $instance etype __ __ __

	log::log debug "    Existence? Metadata <$ispec>"

	if {[catch {$ALL sync meta $ispec} r]} {
	    log::log debug "    Metadata Error <$r>"
	    lappend errors $r
	    continue
	}

	unset -nocomplain md
	array set md $r
	set isprofile [expr {
	     [string equal $etype profile] ||
	     ([string equal $etype package] && [info exists md(profile)])
	 }]

	# Check for and expand profile instances.

	if {$isprofile} {
	    log::log info "$tag   $instance ..."

	    log::log debug "    Existence? Metadata <$ispec>"

	    if {[catch {$ALL sync meta $ispec} r]} {
		log::log debug "    Metadata Error <$r>"
		lappend errors $r
		continue
	    }

	    unset -nocomplain md
	    array set md $r

	    if {[info exists md(require)]} {
		# Check if the profile was used as application
		# package. If yes its expansion is the set of
		# application packages. This can be recursive, so we
		# take care to preserve all other elements, replace
		# just the profile we found with its expansion. If
		# the profile had an empty expansion this code is not
		# executed, leaving the profile in place, causing a
		# runtime error because of a missing package.

		set first 1
		foreach ref $md(require) {
		    lappend references $ref

		    if {$verbose && $first} {log::log info " "}
		    if {$verbose}           {log::log info "      $ref"}
		    set first 0
		}

		set app [tclapp::misc::app?]
		set n [lindex $instance 0]

		if {
		    [llength $app] &&
		    [set pos [lsearch -exact $app $n]] >= 0
		} {
		    set app [lreplace $app $pos $pos]
		    foreach ref $md(require) {
			lappend app [lindex $ref 0]
		    }
		    tclapp::misc::app $app
		}
	    }

	    lappend display [list 1 $instance {}]
	    continue
	}

	# For a regular package retrieve its archive file and record
	# it for wrapping.

	# Note: This code will never be called for packages specified
	#       through -pkgfile.

	#puts GET:($instance)

	# For a redirection we pull the file for the referenced
	# instance. We already have all the necessary meta data
	# available, in the array md, so, instead of recursing we can
	# rewrite the instance on the fly.

	set f [fileutil::tempfile]
	set SRC $ALL
	set redir 0

	if {[string equal $etype redirect]} {
	    # Determine instance refered to by the redirection.
	    teapot::instance::split $instance ____ n v a
	    set new [teapot::instance::cons $md(as::type) $n $v $a]

	    if {$verbose} {
		log::log info "      $instance"
		log::log info "      $new (@ $md(as::repository))"
	    }

	    log::log debug "    Redirecting <$instance> --> <$new> @ $md(as::repository)"

	    # Now generate a repository to query from the specified
	    # list of destination repositories.
	    set SRC [UnionFor $md(as::repository)]

	    # Rewrite the request to use the referenced instance
	    # instead of the redirection itself.
	    set old $instance
	    set instance $new
	    set redir 1
	} else {
	    if {$verbose} {log::log info "      $instance"}
	}

	# Finally perform the retrieval ...

	log::log debug "    Retrieve <$instance> --> $f"

	if {[catch {$SRC sync get $instance $f} r]} {
	    # Some error happened.

	    file delete -force $f

	    # Redirection errors are handled a bit differently, the
	    # are shown immediately in the log, in full form, and the
	    # list of issues coming later gets a smaller form of the
	    # same.
	    set r [StripTags $r]
	    if {$redir} {
		if {!$verbose} {log::log error "      $instance (@ $md(as::repository))"}
		log::log error [Indent $r {          }]
		# Render the full error message down to a simpler one for the issue list.
		set r "    Authorization required for <$instance> @ $md(as::repository)"
		if {[info exists md(as::note)]} {
		    append r \n "    " $md(as::note) \n
		}
	    }

	    lappend errors $r

	    if {$redir} {
		log::log debug "Kill temporary redirect union repository"
		$SRC destroy
	    }
	    continue
	}

	set origin [$SRC originof $f]
	lappend display [list 0 $instance \
		     "R [$origin cget -location]"]

	enterInternal $instance $f
	lappend res   $instance

	# After a redir we can kill the temporary union repository we
	# made for it.
	if {$redir} {
	    log::log debug "Kill temporary redirect union repository"
	    $SRC destroy
	}
    }

    return $res
}

proc ::tclapp::pkg::setArchitectures {archs} {
    variable architectures $archs
    return
}

proc ::tclapp::pkg::getArchitectures {} {
    variable architectures
    return  $architectures
}

proc ::tclapp::pkg::setArchives {archives ev} {
    upvar 1 $ev errors
    variable ALL
    if {($ALL ne "") && ([$ALL archives] eq $archives)} {
	FixPrefix errors
	return
    }

    if {[llength $archives]} {
	log::log debug "ARCHIVES = \{"
	foreach a $archives {log::log debug "    [$a cget -location]"}
	log::log debug "\}"
    }

    catch {::tclapp::pkg::ALL destroy}
    set ALL [repository::union ::tclapp::pkg::ALL -location $archives]
    FixPrefix errors
    return
}

proc ::tclapp::pkg::FixPrefix {ev} {
    upvar 1 $ev errors
    variable ALL

    ::log::log debug "Check, convert teapot prefix"

    # Get the configured prefix, if any (as set by
    # 'tclapp::cmdline::Basic'), convert it to a regular path, if it
    # is a teapot reference instead of a regular path, then
    # reconfigure the prefix. This will automatically also do all the
    # checks which where defered when the teapot-reference was
    # configured in the beginning.

    if {![tclapp::misc::isTeapotPrefix [tclapp::misc::prefix?]]} return
    foreach {n v a} [tclapp::misc::prefix?nva] break

    # First try to find a regular application.
    set instance [teapot::instance::cons application $n $v $a]

    ::log::log debug "teapot-prefix = ($instance)"

    set location [GetPrefix $ALL $instance temp ereason]
    if {$location eq {}} {
	# No application found, retry, now look for a redirection.
	set instance [teapot::instance::cons redirect $n $v $a]

	::log::log debug "teapot-prefix = ($instance)"

	set location [GetPrefix $ALL $instance temp ereasonx] ; # ereasonx -> ignored

	::log::log debug "teapot-prefix = redirect location = $location"

	if {$location ne {}} {
	    # Redirection found, extract the destination, check that
	    # it is an application. If yes, pull that.

	    set fail [catch {
		foreach {origin orepos} [teapot::redirect::decode $location] break
		if {![llength $orepos]} { return -code error "No repositories in redirection" }
	    } msg]

	    if {$temp} { file delete $location ; set temp 0 }
	    set location {}

	    if {$fail} {
		::log::log debug "redirection decoding failed ($fail, ($msg))"

		set ereason $msg
	    } else {
		::log::log debug "redirection decodes to <$origin> @ $orepos"

		# We got the origin instance, and have some repository names. Check more ...
		teapot::instance::split $origin eorigin __ __ __
		if {$eorigin ne "application"} {
		    ::log::log debug "redirection to non-application, bogus"

		    set ereason "Expected an application, was redirected to \"$eorigin\""
		} else {
		    ::log::log debug "redirection retrieval"

		    # Pull the referenced app, using the specified repos as source.
		    set u [UnionFor $orepos]
		    set location [GetPrefix $u $origin temp ereason]
		    if {$location eq {}} {
			set orepos \n[Indent [join $orepos \n] {  }]\n
			set ereason "\nRedirection to${orepos}failed:\n[Indent [StripTags $ereason] {      }]"
		    }
		    $u destroy
		}
	    }
	}
    }

    ::log::log debug "teapot-prefix path = $location"
    ::log::log debug "teapot-prefix temp = $temp"

    if {$location eq {}} {
	::log::log debug "bad teapot prefix : $ereason"

	lappend errors [format [mget 40_INVALID_INPUT_EXECUTABLE_TEAPOT] \
			    [tclapp::misc::prefix?] \
			    $ereason]
    } else {
	tclapp::misc::prefix $location errors
	tclapp::misc::prefixtemp $temp
    }

    # The temp flag we set here is used in
    # tclapp::wrapengine::InsertInterpAndMode

    # Another defered action...
    tclapp::cmdline::RegisterEncodings {} errors
    return
}

proc ::tclapp::pkg::UnionFor {repositories} {
    set u [repository::union ::tclapp::pkg::REDIR]

    # The next object leaks...
    set Tconfig [teapot::config %AUTO%]

    foreach r $repositories {
	set proxy [tclapp::cmdline::IsProxy $r]
	if {$proxy} {
	    set fail [catch {repository::cache open $r -readonly 1 -config $Tconfig} r]
	} else {
	    set fail [catch {repository::cache open $r -readonly 1} r]
	}
	if {$fail} {
	    # Print warning, do not abort.
	    log::log debug " ... Bad repository $r"
	    continue
	}
	$u archive/add $r
    }

    return $u
}

proc ::tclapp::pkg::GetPrefix {srcrepo instance tv ev} {
    upvar 1 $tv temp $ev errormsg

    set temp 0
    if {[catch {
	::log::log debug "teapot-prefix local path?"

	set location [$srcrepo sync path $instance]
    }]} {
	::log::log debug "teapot-prefix temporary file"

	set location [fileutil::tempfile tclapp_tempp]
	if {[catch {
	    $srcrepo sync get $instance $location
	    set temp 1
	} msg]} {
	    set errormsg $msg
	    ::log::log debug $msg
	    file delete $location
	    return {}
	}
    }

    return $location
}


# For pkgman.tcl
proc ::tclapp::pkg::getArchives {} {
    variable ALL
    if {$ALL eq ""} {
	set ALL [repository::union ::tclapp::pkg::ALL]
    }
    return $ALL
}

namespace eval ::tclapp::pkg {
    variable ALL {}
}

# ### ### ### ######### ######### #########

proc ::tclapp::pkg::uniq {list} {
    array set _ {}
    set res {}
    foreach item $list {
	if {[info exists _($item)]} continue
	set _($item) .
	lappend res $item
    }
    return $res
}

proc ::tclapp::pkg::Indent {msg prefix} {
    return $prefix[join [split $msg \n] \n$prefix]
}

proc ::tclapp::pkg::StripTags {msg} {
    set msg [string map {--- \n\n} [join $msg]]
    set res \n
    foreach para [textutil::splitx $msg "\n\n"] {
	append res [textutil::adjust $para -length 64]\n\n
    }
    return [string range $res 0 end-1];# chop last \n
}

proc ::tclapp::pkg::StripTagHandler {tag slash param text} {
    variable mymessage
    set text [string trim $text]
    if {$text eq {}} return
    lappend mymessage $text
    return
}

# ### ### ### ######### ######### #########
## Data structures and setup

proc ::tclapp::pkg::reinitcmd {cmd} {
    variable reinitcmd $cmd
    return
}

proc ::tclapp::pkg::reinitialize {} {
    variable reinitcmd
    uplevel \#0 $reinitcmd
    return
}

#
# tclapp::pkg::Initialize --
#
#	Initializes this package, searches for package definitions
#	and fills the in-memory database.
#
# Arguments:
#	None.
#
# Results:
#	None.
#
# Sideeffects:
#	See above.
#

proc ::tclapp::pkg::Initialize {} {
    variable initialized
    variable pool

    if {$initialized} return
    set  initialized 1

    set pool [::tclapp::pkg::pool thepool]
    return
}

namespace eval tclapp::pkg {

    # Boolean flag. Set to true if this package is initialized.

    variable initialized 0

    # Reference to the object holding the information about the
    # package files to wrap.

    variable pool {}

    # The local arch has to be the arch of TclApp itself. Not the
    # identify of the host. We identify the buildsystem actually.

    variable localarch [platform::identify]
}

# ### ### ### ######### ######### #########
## Ready

package provide tclapp::pkg 1.0
