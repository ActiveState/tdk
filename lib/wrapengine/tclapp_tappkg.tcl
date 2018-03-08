# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_pkg.tcl --
# -*- tcl -*-
#
#	Package database.
#
# Copyright (c) 2002 ActiveState CRL.

#
# RCS: @(#) $Id: tdkwrap.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

package require pref              ; # Preference core package.
package require pref::devkit      ; # TDK shared package : Global TDK preferences.
package require tclapp::msgs
package require tclapp::misc
package require tclapp::fres
package require starkit
package require tcldevkit::config
package require log
package require fileutil

package provide tclapp::tappkg 1.0

#log::lvSuppress debug 0


namespace eval tclapp::tappkg {
    namespace export ...

    # Array of known packages.
    # Map: Name x Version -> name of data array.

    variable  pkg
    array set pkg {}

    # Per data array
    # Map 'files'      -> list of files to wrap (src, dst)
    #     'source'     => name of file the definition is from.
    #     'depends'    -> package names + versions | Dependency tracking | FUTURE 
    #     'recommends' -> package names + versions |                     /
    #     'conflicts'  -> package names + versions |                    /

    # Boolean flag. Set to true if this package is initialized.
    variable initialized 0

    # Counter for the generation of data array names
    variable id 0

    # transient data. Map package names to tokens, for deref
    # of hidden packages when used in a package definition file
    variable  map
    array set map {}

    # Unchanging placeholders
    variable basesubst {}
    variable filesubst {}

    # Log cmd for tap load errors.
    variable logerrcmd {}
    variable errors {}

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

    # ### ### ### ######### ######### #########
    ## Translation from old-style platform names in .tap files to the
    ## new standard platform codes.

    variable archmap {
	aix-rs6000		aix-powerpc
	aix-rs6000_64		aix-powerpc64
	hpux-ia64		hpux-ia64
	hpux-ia64_32		hpux-ia64_32
	hpux-parisc		hpux-parisc
	hpux-parisc64		hpux-parisc64
	linux-ia64		linux-glibc2.3-ia64
	linux-ix86		linux-glibc2.2-ix86
	linux-x86_64		linux-glibc2.3-x86_64
	macosx-ix86		macosx-ix86
	macosx-powerpc		macosx-powerpc
	macosx-universal	macosx-universal
	solaris-ix86		solaris2.10-ix86
	solaris-sparc		solaris2.6-sparc
	solaris-sparc-2.8	solaris2.8-sparc
	solaris-sparc64-2.8	solaris2.8-sparc64
	win32-ix86		win32-ix86
	win32-x86		win32-x86_64
	*			tcl
    }

    # And the inverse, from new-style names to our old names.

    variable iarchmap ; array set iarchmap {
	aix-powerpc	       aix-rs6000		
	aix-powerpc64	       aix-rs6000_64		
	hpux-ia64	       hpux-ia64		
	hpux-ia64_32	       hpux-ia64_32		
	hpux-parisc	       hpux-parisc		
	hpux-parisc64	       hpux-parisc64		
	linux-glibc*-ia64      linux-ia64		
	linux-glibc*-ix86      linux-ix86		
	linux-glibc*-x86_64    linux-x86_64		
	macosx-ix86	       macosx-ix86		
	macosx-powerpc	       macosx-powerpc		
	macosx-universal       macosx-universal	
	solaris*-ix86          solaris-ix86		
	solaris2.6-sparc       solaris-sparc		
	solaris2.8-sparc       solaris-sparc-2.8	
	solaris2.8-sparc64     solaris-sparc64-2.8	
	win32-ix86	       win32-ix86		
	win32-x86_64	       win32-x86		
	tcl                    *			
    }

    # ### ### ### ######### ######### #########
}


# ========================================================

proc tclapp::tappkg::setLogError {cmd} {
    variable logerrcmd $cmd
    return
}

proc tclapp::tappkg::hasErrors {} {
    variable                errors
    return [expr {[llength $errors] > 0}]
}

proc tclapp::tappkg::logError {text} {
    variable errors
    lappend  errors $text
    return
}

proc tclapp::tappkg::dumpErrors {} {
    variable logerrcmd
    variable errors
    foreach e $errors {
	eval [linsert $logerrcmd end $e]
    }
    set errors [list]
    return
}

proc tclapp::tappkg::getErrors {} {
    variable errors
    set result $errors
    set errors [list]
    return $result
}

proc tclapp::tappkg::splitName {name} {
    set stem    {}
    set version {}
    if {![regexp {^([^0-9]*)(-[0-9]+(\.[0-9]+)*)?$} $name \
	    -> stem version __]} {
	return [list $name {}]
    }
    # range 1 end => cut out the '-'
    return [list $stem [string range $version 1 end]]
}

proc tclapp::tappkg::basename {name} {
    foreach {base v} [splitName $name] { break }
    return $base
}

proc tclapp::tappkg::exists {name} {
    variable pkg
    Initialize

    log::log debug "tclapp::tappkg::exists $name"

    # Assume a name of either 'pkg-version', or plain package

    if {[info exists pkg($name)]} {return 1}
    return [expr {[llength [array names pkg ${name}-*]] > 0}]
}


proc tclapp::tappkg::name {token} {
    variable $token
    upvar 0  $token data

    if {![info exists data]} {
	return -code error "Invalid package token $token"
    }

    return $data(name)-$data(version)
}

proc tclapp::tappkg::delete {token} {
    variable pkg
    variable $token
    upvar 0  $token data

    if {![info exists data]} {
	return -code error "Invalid package token $token"
    }

    set pkey $data(name)-$data(version)

    if {[info exists pkg($pkey)]} {
	unset pkg($pkey)
    }
    unset data
    return
}

proc tclapp::tappkg::locate {name} {
    variable pkg
    Initialize

    log::log debug "tclapp::tappkg::locate $name"

    if {[info exists pkg($name)]} {
	return $pkg($name)
    }

    set vlast 0.0
    set plast ""
    foreach c [array names pkg ${name}-*] {
	set v [lindex [split $c -] 1]
	if {[package vcompare $vlast $v] < 0} {
	    set vlast $v
	    set plast $c
	}
    }
    if {![string equal $plast ""]} {
	return $pkg($plast)
    }
    return {}
}


proc tclapp::tappkg::locate-fuzzy {name} {
    variable pkg
    Initialize

    log::log debug "tclapp::tappkg::locate-fuzzy $name"

    # Why was fuzzy called, the name is present as is ?
    if {[info exists pkg($name)]} {
	log::log debug "tclapp::tappkg::locate-fuzzy - present"
	return $name
    }

    foreach {n v} [splitName $name] break

    if {$v == {}} {
	log::log debug "tclapp::tappkg::locate-fuzzy - name only"

	# Name only, no version, so try for the upgrade path
	# and only that.

	set new [tap_upgrade $name]
	if {$new == {}} {return {}}

	log::log debug "tclapp::tappkg::locate-fuzzy - up $new"

	# Check that the upgrade package actually exists
	# before telling the caller that the search was ok.

	set token [locate $new]
	if {$token == {}} {return {}}

	log::log debug "tclapp::tappkg::locate-fuzzy - is ok"
	return $new

    } else {
	# We have name and version. Look for a different
	# version under the same name first. Then check
	# if the upgrade path is possible, and if so,
	# check it using the current version, and then for
	# a different version ...

	log::log debug "tclapp::tappkg::locate-fuzzy - name & version"

	# Different version maybe ?
	set token [locate $n]
	if {$token != {}} {
	    log::log debug "tclapp::tappkg::locate-fuzzy - got it"
	    return $n
	}

	log::log debug "tclapp::tappkg::locate-fuzzy - try up"

	# No. Check for upgrade path.
	set new [tap_upgrade $n]
	if {$new == {}} {return {}}

	log::log debug "tclapp::tappkg::locate-fuzzy - up $new-$v"

	# Try upgrade with incoming version first ...
	set token [locate ${new}-$v]
	if {$token != {}} {return ${new}-$v}

	# No try again without version ...
	log::log debug "tclapp::tappkg::locate-fuzzy - up $new"

	set token [locate $new]
	if {$token == {}} {return {}}

	log::log debug "tclapp::tappkg::locate-fuzzy - is ok"
	return $new
    }
}


proc tclapp::tappkg::tap_upgrade {name} {
    variable tapchanges
    if {[info exists tapchanges($name)]} {
	return $tapchanges($name)
    }
    return {}
}


#
# tclapp::tappkg::listNames --
#
#	Return list of known packages
#
# Arguments:
#	Name, may contain version number.
#
# Results:
#	A boolean value. True if bombing is required.

proc tclapp::tappkg::listNames {} {
    variable pkg
    Initialize
    return [array names pkg]
}

#
# tclapp::tappkg::files --
#
#	Return files for package FOO
#
# Arguments:
#	Data key
#
# Results:
#	A boolean value. True if bombing is required.

proc tclapp::tappkg::files {token} {
    variable $token
    upvar 0  $token data
    return         $data(files)
}

proc tclapp::tappkg::filesList {token} {
    variable $token
    upvar 0  $token data
    return         $data(filesList)
}

proc tclapp::tappkg::hasFiles {token} {
    variable $token
    upvar 0  $token data
    return [expr {
	[info exists data(filesList)] &&
	([llength $data(filesList)] > 0)
    }]
}

#
# tclapp::tappkg::source --
#
#	Return source of definition for package FOO
#
# Arguments:
#	Name, may contain version number.
#
# Results:
#	A boolean value. True if bombing is required.

proc tclapp::tappkg::source {token} {
    variable $token
    upvar 0  $token data
    return         $data(source)
}

#
# tclapp::tappkg::name --
#
#	Return name of definition for package FOO
#
# Arguments:
#	Name, may contain version number.
#
# Results:
#	A boolean value. True if bombing is required.

proc tclapp::tappkg::name {token} {
    variable $token
    upvar 0  $token data
    return         $data(name)
}

#
# tclapp::tappkg::version --
#
#	Return version of definition for package FOO
#
# Arguments:
#	Name, may contain version number.
#
# Results:
#	A boolean value. True if bombing is required.

proc tclapp::tappkg::version {token} {
    variable $token
    upvar 0  $token data
    return       $data(version)
}

#
# tclapp::tappkg::platform --
#
#	Return platform of definition for package FOO
#
# Arguments:
#	Name, may contain version number.
#
# Results:
#	A boolean value. True if bombing is required.

proc tclapp::tappkg::platform {token} {
    variable $token
    upvar 0  $token data
    return       $data(platform)
}

proc tclapp::tappkg::newplatform {token} {
    variable archmap
    return [string map $archmap [platform $token]]
}

proc tclapp::tappkg::2platform {architectures} {
    variable iarchmap
    set res {}
    foreach a $architectures {
	if {[info exists iarchmap($a)]} {
	    lappend res $iarchmap($a)
	} else {
	    foreach {pattern value} [array get iarchmap] {
		if {![string match $pattern $a]} continue
		lappend res $value
		set iarchmap($a) $value
		break
	    }
	}
    }
    return [lsort -unique $res]
}

#
# tclapp::tappkg::desc --
#
#	Return description in definition for package FOO
#
# Arguments:
#	Name, may contain version number.
#
# Results:
#	A boolean value. True if bombing is required.

proc tclapp::tappkg::desc {token} {
    variable $token
    upvar 0  $token data
    return       $data(desc)
}

## ===============================================================

#
# tclapp::tappkg::Initialize --
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

proc tclapp::tappkg::Initialized {} {
    variable initialized
    return  $initialized
}

proc tclapp::tappkg::Initialize {{fb 0}} {
    variable initialized
    variable basesubst
    variable filesubst

    if {$initialized} {return}
    set initialized 1

    if {$fb} {::tcldevkit::appframe::feedback on}

    log::log debug tclapp::tappkg::Initialize

    # Initialize placeholders for 'Base' processing.

    set installdir [file dirname [file dirname $starkit::topdir]]
    set basesubst [list \
	    @TDK_INSTALLDIR@ $installdir \
	    ]
    set filesubst [list \
	    @DLLEXT@         [string range [info sharedlibextension] 1 end] \
	    ]

    foreach p [SearchPaths $fb] {
	foreach {p master} $p break
	if {[tclapp::misc::verbose?]} { log::log info "  Searching $p ..." }

	foreach pdfile [FindPackageDefinitions $p $fb] {
	    LoadPackageDefinition $pdfile $master $fb
	}
    }

    HardwiredTclPackage

    if {$fb} {::tcldevkit::appframe::feedback off}
    return
}

proc tclapp::tappkg::uninitialize {} {
    variable initialized
    if {!$initialized} return
    DeleteAll
    set initialized 0
    return
}

proc tclapp::tappkg::reinitialize {{fb 0}} {
    variable initialized

    # If the module had not been initialized before we can wait with
    # doing so a bit more.
    if {!$initialized} return

    DeleteAll
    set initialized 0
    Initialize $fb
}

proc tclapp::tappkg::DeleteAll {} {
    variable pkg

    foreach k [array names pkg] {
	set token $pkg($k)
	variable $token
	unset    $token
    }

    array unset pkg *
    return
}

proc tclapp::tappkg::HardwiredTclPackage {} {
    # Enter a hardwired definition for the predefined core package
    # Tcl.

    # This definition is always made. Tcl is present in all runtime #
    # environments, without fail.

    return [EnterStatic Tcl [info tclversion]]
}

proc tclapp::tappkg::HardwiredTkPackage {} {
    # Enter a hardwired definition for the predefined core package
    # Tk.

    # Note. This definition is made if and only if no prefix file was
    # chosen. IOW if there is no prefix file we assume that the
    # runtime environment will provide Tk. Otherwise, i.e. if there is
    # a prefix file existence of Tk has to come from the packages
    # found in the basekit already.

    return [EnterStatic Tk [info tclversion]]
}

proc tclapp::tappkg::EnterStatic {p v} {
    # Enter a definition for a static package. I.e. a package
    # found inside of the chosen basekit.

    ClearMap
    InitState tmp {} $p $v
    return [Store tmp]
}


proc tclapp::tappkg::FindStaticPackages {basekitpath} {
    ::log::log debug "FindStaticPackages ($basekitpath)"

    Initialize

    # Bugzilla 30601.
    # We interogate the chosen prefix file.

    # Bugzilla 35491.
    # To keep our ability for cross-wrapping we cannot really use
    # Tcl's introspection features as we did initially. The prefix
    # file may not be executable on the current platform. Or actually
    # not executable at all, if a starkit is chosen as prefix file, or
    # just a metakit filesystem in a plain file, without header.

    # We mount the metakit filesystem instead, scan it for
    # pkgIndex.tcl files, and extract from them which packages they
    # provide. The found packages are entered into the package
    # database as static packages, provided that there is no external
    # definition via TAP file.

    # For the extraction we use a heuristic parser, it attacks the
    # code via regular expressions and other string operations.

    # If no metakit filesystem is present we ignore the prefix file,
    # i.e. skip this step.

    set obase $basekitpath
    set basekitpath [file normalize $basekitpath]

    if {[lsearch -exact [fileutil::fileType $basekitpath] metakit] < 0} {
	return {}
    } elseif {[catch {
	vfs::mk4::Mount $basekitpath $basekitpath -readonly
    } msg]} {
	return {}
    }

    set indices {}
    foreach f [fileutil::findByPattern $basekitpath *pkgIndex.tcl] {
	set fchan [open $f r]
	set fcont [read $fchan]
	close $fchan
	lappend indices $f $fcont
    }

    vfs::unmount $basekitpath

    # Now that we have the indices we can process them, and determine
    # which packages they provide.

    set packages {}
    set haserr 0
    foreach {fidx idx} $indices {
	set err [ParsePkgIndex $fidx $idx packages]
	if {[llength $err]} {
	    if {!$haserr} {
		log::log warning " "
                log::log warning "Problems found while looking for packages provided by the"
                log::log warning "prefix file \"$obase\""
                log::log warning "to resolve -pkg requests we found no .tap files for."
		set haserr 1
	    }
	    regsub ^$basekitpath $fidx {} fidx
	    regsub ^/            $fidx {} fidx
	    log::log warning " "
	    log::log warning "* In file \"$fidx\":"
	    foreach e $err {
		log::log warning "  $e"
	    }
	}
    }
    if {$haserr} {
	log::log warning " "
    }

    # Ok, we have the packages and versions from the prefix
    # file. Exclude all packages which have tap files, enter the
    # remainder as static definitions, collect their tokens for
    # removal from the database after the wrap.

    #::log::log debug "\tGot [join $packages "\n\tGot "]"
    ::log::log debug XXXXXXXXXXXXXXXXXXX

    #variable pkg ; log::logarray debug pkg

    set res {}
    foreach pv $packages {
	foreach {p v} $pv break
	set token [locate ${p}-$v]
	if {$token ne ""} {
	    ::log::log debug "\tGot    $pv"
	} else {
	    ::log::log debug "\tGot ** $pv"
	    lappend res [EnterStatic $p $v]
	}
    }
    return $res
}

proc tclapp::tappkg::ParsePkgIndex {fidx idx pvar} {
    upvar 1 $pvar packages

    # Heuristic parsing of the index script.

    # FUTURE ? Use something tclchecker based for proper parsing and
    # scanning of the code ? Not sure if this would be truly required
    # because although hackish the code below handles all the indices
    # I found in ActiveTcl without problems.

    # Ignore comment lines, and lines without the 'ifneeded' keyword
    # (from 'package ifneeded'). Remove everything before the
    # 'ifneeded' keyword, and the keyword from the line. Then cut
    # everything after a digit followed by an opening bracket, brace
    # or double apostroph. That is the last digit of the version
    # number, followed by the provide command. Now treat the line as
    # list, and its two elements are package name and version.

    set found 0
    set problems {}

    foreach line [split $idx \n] {
	if { [regexp "#"        $line]} {continue}
	if {![regexp {ifneeded} $line]} {continue}

	set xline $line
	regsub {^.*ifneeded }             $line {}   line
	regsub -all {[ 	]+}               $line { }  line
	regsub "(\[0-9\]) \[\{\[\"\].*\$" $line {\1} line

	if {[catch {
	    foreach {p v} $line break
	} msg]} {
	    lappend problems "General parser failure in line"
	    lappend problems "'$xline'"
	    lappend problems "Error message: $msg"
	    lappend problems "for string '$line'"
	    continue
	} elseif {![regexp {^[0-9]+(\.[0-9]+)*$} $v]} {
	    lappend problems "Bad version number \"$v\" in line"
	    lappend problems "'$xline'"
	    continue
	}

	lappend packages [list $p $v]
	incr found
    }

    if {!$found} {
	lappend problems "No packages found"
    }

    return $problems
}

proc tclapp::tappkg::SearchPaths {{fb 0}} {
    # This commands determines where to look for package
    # definition files.

    global env auto_path tcl_pkgPath tcl_platform

    # Initial set of paths ...
    # First the TDK installation itself, then preferences, at last the
    # environment.

    set paths [list]

    lappend paths [file join [file dirname [file dirname $starkit::topdir]] lib]

    foreach p [pref::prefGet pkgSearchPathList] {
	lappend paths $p
    }

    if {[info exists env(TCLAPP_PKGPATH)]} {
	if {$tcl_platform(platform) == "windows"} {
	    eval lappend paths [split $env(TCLAPP_PKGPATH) ;]
	} else {
	    eval lappend paths [split $env(TCLAPP_PKGPATH) :]
	}
    }

    # Remove duplicates, do not disturb the order of paths.
    # Normalize the paths on the way

    set res [list]
    array set _ {}
    foreach p $paths {
	set p [file normalize $p]
	if {[info exists _($p)]} {continue}
	lappend res $p
	set _($p) .
    }
    set paths $res
    unset _

    # Add subdirectories of the search paths to the search to.
    # (Only one level).

    # We also associate each directory with the base directory from
    # the original list of search paths. These base paths are now the
    # anchors for TDK_LIBDIR expansion. The data added here is passed
    # through to LoadPackageDefinition and SetBase. There it is used
    # for the mentioned substitution.

    set res [list]
    foreach p $paths {
	if {$fb} ::tcldevkit::appframe::feednext
	lappend res [list $p $p]
	set sub [glob -nocomplain -types d -directory $p *]
	if {[llength $sub] > 0} {
	    foreach s $sub {
		lappend res [list $s $p]
	     }
	}
    }

    # Expansion complete.

    foreach p $res {
	log::log debug "tclapp::tappkg::SearchPaths\t$p"
    }
    return $res
}

proc tclapp::tappkg::FindPackageDefinitions {path {fb 0}} {
    # This commands finds files which may contain package
    # definitions.

    set res [list]

    if {$fb} ::tcldevkit::appframe::feednext

    foreach ext {tap tpj tdk} {
	if {[catch {
	    set files [::glob -nocomplain -types {f l} -directory $path *.$ext]
	}]} {
	    # Can happen if and only if we do not have the permissions
	    # to read or stat (r/x) the chosen directory. Ignore the
	    # problem, keep scanning the remaining directories.
	    continue
	}

	foreach f $files {
	    if {$fb} ::tcldevkit::appframe::feednext
	    if {![file isfile $f]} {continue}

	    # Check that the type is correct and ignore all files
	    # which are not package definitions.
	    foreach {ok tool} [tcldevkit::config::Peek/2.0 $f] break
	    if {!$ok} continue
	    if {$tool ne "TclDevKit TclApp PackageDefinition"} continue

	    lappend res $f
	}
    }

    if {$fb} ::tcldevkit::appframe::feednext
    return $res
}

proc tclapp::tappkg::LoadPackageDefinition {fname mainpath {fb 0}} {
    log::log debug "tclapp::tappkg::LPD Trying $fname ..."
    log::log debug \t[tcldevkit::config::Peek/2.0 $fname]

    if {[tclapp::misc::verbose?]} { log::log info "    Found $fname ..." }

    if {$fb} ::tcldevkit::appframe::feednext

    if {[catch {
	set data [tcldevkit::config::ReadOrdered/2.0 $fname {
	    Package
	    Base
	    Path
	    ExcludePath
	    Alias
	    See
	    Hidden
	    Platform
	    Desc
	}] ; # {}
    } msg]} {
	# File is not package definition, skip.
	log::log debug "\tfailed ... $msg"
	logError  "$fname failed to load\n* $msg"
	return
    }

    if {$fb} ::tcldevkit::appframe::feednext

    # Process the package definitions found in the file.

    log::log debug "\tprocessing ..."

    # Transient package definition and processing status. Will be
    # written only if complete and without errors.

    ClearMap
    InitState tmp $fname

    foreach {cmd val} $data {
	if {$fb} ::tcldevkit::appframe::feednext
	switch -exact -- $cmd {
	    Package {
		if {$tmp(haspkg) && !$tmp(skip)} {Store tmp}
		foreach {name version} $val { break }
		InitState tmp $fname $name $version
		set tmp(haspkg) 1
	    }
	    Hidden      {Hide          tmp}
	    See         {See           tmp $val}
	    Base        {SetBase       tmp $val [file dirname $fname] $mainpath}
	    Path        {AddPattern    tmp $val}
	    ExcludePath {RemovePattern tmp $val}
	    Alias       {RenameFile    tmp $val}
	    Platform    {SetPlatform   tmp $val}
	    Desc        {AddDesc       tmp $val}
	    default {
		return -code error "internal error, illegal PD key \"$cmd\""
	    }
	}
    }
    if {$tmp(haspkg) && !$tmp(skip)} {Store tmp}
    if {$fb} ::tcldevkit::appframe::feednext
    return
}


proc tclapp::tappkg::InitState {var srcfile {name {}} {version {}}} {
    upvar 1 $var tmp
    catch {unset tmp}

    # haspkg - boolean - set to true if package defined
    # skip   - boolean - set to true if an error causes
    #                    us to skip over the remainder
    #                    of the definition
    # name, version - identity of the package.
    # base - base path
    # alias - last alias
    # platform - platform info of package
    # desc - description

    array set tmp {
	haspkg 0 skip 0 hide 0
	name {} version {}
	base {} alias {}
	platform * desc {}
    }

    set tmp(name)    $name
    set tmp(version) $version
    set tmp(source)  $srcfile
}


proc tclapp::tappkg::SetBase {var val tapdir mainpath} {
    variable basesubst
    upvar 1 $var tmp

    if {$tmp(skip)} return

    set     subst $basesubst
    lappend subst @TAP_DIR@    $tapdir
    lappend subst @TDK_LIBDIR@ $mainpath

    set sval [string map $subst $val]

    # Base path. Need a readable directory
    if {
	![file isdirectory $sval] ||
	![file readable    $sval]
    } {
	log::log error "\tUnuseable base path \"$val\""
	log::log error "\texpansion was       \"$sval\""
	logError "$tmp(source): Unuseable base path \"$val\",\n\
		was expanded to \"$sval\"."
	set tmp(skip) 1
	return
    }
    set tmp(base) [file normalize $sval]
}


proc tclapp::tappkg::Hide {var} {
    upvar 1 $var tmp

    if {$tmp(skip)} return
    set tmp(hide) 1
    return
}


proc tclapp::tappkg::See {var val} {
    upvar 1 $var tmp

    if {$tmp(skip)} return

    set token [DerefMap $val]
    if {$token == {}} {
	log::log       error "\tRefering unknown package \"$val\""
	logError "$tmp(source): Refering unknown package \"$val\""
	set tmp(skip) 1
	return
    }

    set tmp(see)      $token
    set tmp(see,name) $val
    return
}


proc tclapp::tappkg::AddDesc {var text} {
    upvar 1 $var tmp

    if {$tmp(skip)} return
    # expand, check and add.

    append tmp(desc) $text\n
}

proc tclapp::tappkg::SetPlatform {var val} {
    upvar 1 $var tmp

    if {$tmp(skip)} return
    # expand, check and add.

    set tmp(platform) $val
}

proc tclapp::tappkg::AddPattern {var pattern} {
    variable filesubst
    upvar 1 $var tmp

    if {$tmp(skip)} return
    # expand, check and add.

    # Need a base to work from
    if {$tmp(base) == {}} {
	log::log       error "\tPath \"$pattern\" has no base"
	logError "$tmp(source): Path \"$pattern\" has no base"
	set tmp(skip) 1
	return
    }

    set spattern [string map $filesubst $pattern]
    set expanded [glob -nocomplain -directory $tmp(base) $spattern]

    log::log debug "\t\tPath = $pattern"
    log::log debug "\t\tBase = $tmp(base)"

    if {[llength $expanded] < 1} {
	set tmp(skip) 1
	log::log       error "\tNo files matching \"$pattern\""
	logError "$tmp(source): No files matching \"$pattern\""
	return
    }
    foreach f $expanded {

	log::log debug "\t\tSub  = $f"

	if {[file isdirectory $f]} {
	    # Directory, include everything.
	    foreach ff [fileutil::find $f {file isfile}] {
		set tmp(p,$ff) [::fileutil::stripPath $tmp(base) $ff]

		log::log debug "\t\t\t$tmp(p,$ff)"
	    }
	} else {
	    # Single file
	    set tmp(p,$f) [::fileutil::stripPath $tmp(base) $f]

	    log::log debug "\t\t\t$tmp(p,$f)"
	}
    }
    return
}


proc tclapp::tappkg::RemovePattern {var pattern} {
    upvar 1 $var tmp

    if {$tmp(skip)} return
    # Need a base to work from
    if {$tmp(base) == {}} {
	log::log       error "\tExcludePath \"$pattern\" has no base"
	logError "$tmp(source): ExcludePath \"$pattern\" has no base"
	set tmp(skip) 1
	return
    }
    # remove pattern

    set fullpattern [file join $tmp(base) $pattern]

    foreach key [array names tmp p,$pattern] {
	unset tmp($key)
    }
}

proc tclapp::tappkg::RenameFile {var val} {
    upvar 1 $var tmp

    if {$tmp(skip)} return

    foreach {old new} $val { break }

    # Need a base to work from
    if {$tmp(base) == {}} {
	log::log       error "\tAlias \"$val\" has no base"
	logError "$tmp(source): Alias \"$val\" has no base"
	set tmp(skip) 1
	return
    }

    set fullpath [file join $tmp(base) $old]

    if {![info exists tmp(p,$fullpath)]} {
	log::log       error "\tUnable to alias unknown file \"$old\""
	logError "$tmp(source): Unable to alias unknown file \"$old\""
	set tmp(skip) 1
	return
    }

    set olddst $tmp(p,$fullpath)
    set newdst [file join [file dirname $olddst] $new]
    set tmp(p,$fullpath) $newdst
    return
}

proc tclapp::tappkg::Store {var} {
    upvar 1 $var tmp
    variable pkg
    variable id
    variable map

    log::log debug "tclapp::tappkg::Store $tmp(name)-$tmp(version) /$tmp(platform)[expr {$tmp(hide) ? " HIDDEN" : ""}][expr {[info exists tmp(see)] ? " -----> $tmp(see,name)" : ""}]"

    # Create storage for definition
    variable  da$id
    upvar 0   da$id data
    set dvar  da$id
    incr id

    set data(source)   $tmp(source)
    set data(name)     $tmp(name)
    set data(version)  $tmp(version)
    set data(platform) $tmp(platform)
    set data(desc)     $tmp(desc)

    if {[info exists tmp(see)]} {
	set data(files) $tmp(see)
	# FIXME future - deref reference chain.
    } else {
	foreach key [array names tmp p,*] {
	    set src [lindex [split $key ,] 1]
	    set dst $tmp($key)
	    lappend data(filesList) $src $dst

	    log::log debug "\t$src \t---> $dst"
	}
	set data(files) $dvar
    }

    set pkey $tmp(name)-$tmp(version)

    # Delete previous definition, if any
    if {[info exists pkg($pkey)]} {
	unset ::tclapp::tappkg::$pkg($pkey)
    }
    if {!$tmp(hide)} {
	set pkg($pkey) $dvar
    }

    # Map for deref of hidden names
    set map($tmp(name)) $dvar
    return $dvar
}

proc tclapp::tappkg::ClearMap {} {
    variable  map
    unset     map
    array set map {}
    return
}

proc tclapp::tappkg::DerefMap {name} {
    variable  map
    set res {}
    catch {set res $map($name)}
    return   $res
}



## ===============================================================
