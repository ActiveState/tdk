# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::package::gen 0.1
# Meta platform    tcl
# Meta require     compiler
# Meta require     teapot::metadata
# Meta require     teapot::reference
# Meta require     teapot::metadata::read
# Meta require     teapot::metadata::container
# @@ Meta End

# -*- tcl -*-
# Package generation - Frontend: Directory processing,
#                                MD validation.
#                                Invokation of the chosen backend.

# ### ### ### ######### ######### #########
## Requirements

package require logger                 ; # Tracing
package require teapot::instance       ; # Instance handling
package require teapot::reference      ; # References.
package require teapot::metadata       ; # MD accessors
package require teapot::metadata::read ; # MD extraction
package require teapot::metadata::container ; # MD container handling.

logger::initNamespace ::teapot::package::gen
namespace eval        ::teapot::package::gen {}

# ### ### ### ######### ######### #########
## API. Setting the patterns for directories to ignore.

proc ::teapot::package::gen::ignore {patterns} {
    variable ipatterns $patterns
    return
}

# ### ### ### ######### ######### #########
## API. File processing. Trivial TM.

proc ::teapot::package::gen::simple {thefile respath arinfix} {

    set errors {}
    set plist [teapot::metadata::read::file $thefile single errors]
    if {[llength $errors] || ![llength $plist]} {
	return -code error [join $errors \n]
    }

    set p [lindex $plist 0]
    teapot::instance::split [$p instance] e n v a
    $p destroy

    set archive [file join $respath [PFilename $e $n $v $a tm $arinfix]]

    clearArchives
    newArchive         $archive
    file copy -force $thefile $archive
    return
}

# ### ### ### ######### ######### #########
## API. Recursive directory processing.

proc ::teapot::package::gen::do {top cv} {
    upvar 1 $cv config ; # array - artype respath timestamp arinfix logcmd {compile 0}
    if {![info exists config(compile)]} { set config(compile) 0 }

    # respath *has to be* a directory (or not existent).
    set artype  $config(artype)
    set respath $config(respath)

    if {[catch {
	package require teapot::package::gen::$artype
    }]} {
	Log "- Error ***"
	Log "  Backend \"$artype\" not known."
	return
    }

    if {[llength [info commands ::teapot::package::gen::${artype}::arinit]]} {
	# Initialize the backend for the current archive/output
	::teapot::package::gen::${artype}::arinit $respath
    }

    clearArchives
    return [recurse $top config]
}

proc ::teapot::package::gen::recurse {top cv} {
    upvar 1 $cv config ; # array - artype respath timestamp arinfix logcmd {compile 0}
    if {![info exists config(compile)]} { set config(compile) 0 }
    # Recursive search for packages in the toplevel directory
    # and below.

    Log "Scanning \"$top\""

    set artype    $config(artype)
    set respath   $config(respath)
    set timestamp $config(timestamp)
    set arinfix   $config(arinfix)
    set logcmd    $config(logcmd)
    set compile   $config(compile)

    # Case I. No file 'teapot.txt' in this directory.
    #         Process all subdirectories.
    #
    # Case II. A file 'teapot.txt' is present. Read it, as
    #          further handling of the directory is dependent
    #          on its contents.
    #
    #          * Multiple profiles have been found, or
    #            A mix of package and profile has been found.
    #
    #            This is an error.
    #
    #          * One or more packages have been found.
    #
    #            Hand the directory to the regular processing.
    #            No further recursion takes places (packages
    #            are not allowed to nest).
    #
    #          * One profile has been found
    #
    #            Recurse into the subdirectories and handle
    #		 their packages. Put the collected packages
    #		 as requirements into the profile. Use exact
    #		 versions.

    # Check for case I. If so (no meta data, or not useable at
    # all). Do as described above, plain recursion through the
    # subdirectories.

    set mdfile [MDFile $top]

    if {![file exists $mdfile]} {
	return [RecurseCore $top config]
    }

    if {![file isfile $mdfile]} {
	Log "- Error ***"
	Log "  Meta-data file is a directory, ignoring."

	return [RecurseCore $top config]
    }

    if {![file readable $mdfile]} {
	Log "- Error ***"
	Log "  Meta-data file is not readable, ignoring."

	return [RecurseCore $top config]
    }

    set errors {}
    set fail [catch {
	set packages [::teapot::metadata::read::fileEx $mdfile multi errors]
    } msg]
    if {$fail || [llength $errors]} {
	if {!$fail} {set msg [join $errors \n]}
	Log "- Error ***"
	Log "  Bad syntax: $msg"
	Log "  Meta-data not useable, ignoring."

	return [RecurseCore $top config]
    }

    # Note: packages is a list of containers now, not of old
    # instance/meta information anymore.

    set nprofiles [NProfiles $packages]
    set npackages [expr {[llength $packages] - $nprofiles}]

    if {($nprofiles > 0) && ($npackages > 0)} {
	Log "- Error ***"
	Log "  Mixture of profiles and packages, ignoring."

	return [RecurseCore $top config]
    }

    if {$nprofiles > 1} {
	Log "- Error ***"
	Log "  More than one profile definition, ignoring."

	return [RecurseCore $top config]
    }

    # Ok, two cases now: A single profile, or one or more packages.

    if {$nprofiles == 1} {
	Log "- Profile"

	set refs [RecurseCore $top config]
	# refs :: dict (ref -> full meta)
	set nrefs [expr {[llength $refs]/2}]

	if {[llength [info commands ::teapot::package::gen::${artype}::profileCapture]]} {
	    # Initialize the backend for the current package directory.
	    set capture [::teapot::package::gen::${artype}::profileCapture]
	} else {
	    set capture 1
	}

	# Extend the meta data with the collected packages as
	# requirements, then call directly into the backend, faking
	# whatever is necessary and not present for a profile.

	# Note: Profiles are without functionality, therefore
	# byte-compilation is not relevant. Nor are files to handle.

	Log "Back in  \"$top\""

	if {$nrefs == 1} {
	    Log "Profile references $nrefs package ..."
	} else {
	    Log "Profile references $nrefs packages ..."
	}

	if {!$capture} {
	    # The chosen backend does not deal with profiles. An
	    # example is the pkgIndex backend. It cannot generate code
	    # for the profile here. Profiles have no pkgIndex.tcl

	    Log "  Backend does not handle profiles, ignoring"
	    return {}
	}

	set main [lindex $packages 0]

	# Multi-profile based on Tcl runtime ?

	if {[info exists config(splitbytcl)] &&
	    [llength $config(splitbytcl)]} {
	    # We are generating multiple profiles from the capture,
	    # separating the subordinate packages by their min tcl
	    # version and the chosen buckets.

	    set result {}
	    foreach bucket $config(splitbytcl) {

		set undot [join [split $bucket .] {}]
		set now [$main clone NOW]
		$now rename [$now name]$undot

		$now add require [teapot::reference::cons Tcl -version $bucket -exact 1]
		foreach {r m} $refs {
		    # Ignore packages where the current bucket (Tcl
		    # runtime version) is not good enough.
		    set min [teapot::metadata::minTclVersionMM $m]
		    if {![package vsatisfies $bucket $min]} continue

		    $now add require $r
		}

		teapot::instance::split [$now instance] pe pn pv pa
		set archive [file join $respath \
				 [PFilename $pe $pn $pv $pa $artype $arinfix]]

		if {[llength [info commands ::teapot::package::gen::${artype}::archive]]} {
		    set arcmd ::teapot::package::gen::${artype}::archive
		    set archive [$arcmd $now __ $archive]
		}

		Log "- $archive ($bucket)"

		$now reversion $pv$timestamp

		::teapot::package::gen::${artype}::generate $now $top $archive

		lappend result \
		    [list [$now name] -version $pv -exact 1] [$now get]

		$now destroy
	    }

	    return $result
	}

	# Regular profile (no splitting)

	foreach {r rmeta} $refs {
	    $main add require $r
	}

	teapot::instance::split [$main instance] pe pn pv pa
	set archive [file join $respath \
			 [PFilename $pe $pn $pv $pa $artype $arinfix]]

	if {[llength [info commands ::teapot::package::gen::${artype}::archive]]} {
	    set arcmd ::teapot::package::gen::${artype}::archive
	    set archive [$arcmd $main __ $archive]
	}

	Log "- $archive"

	$main reversion $pv$timestamp

	::teapot::package::gen::${artype}::generate $main $top $archive

	# Return only the profile itself as a collected package.
	# Because everything underneath is captured by it.

	return [list [list [$main name] -version $pv -exact 1] [$main get]]
    }

    # Last case: One or more packages in this directory.
    # Stop recursion, no further packages possible.

    Log "- Regular, Leaf"

    set refs {}
    if {![generate $top config errmessage refs]} {
	Log "- Error ***"
	Log "  $errmessage"
    }

    return $refs
}

# ### ### ### ######### ######### #########
## API. Non-recursive directory processing.
##      Meta data implicit in file "teapot.txt".

proc ::teapot::package::gen::generate {top cv mv {rv {}}} {
    # config = artype respath timestamp arinfix logcmd compile
    upvar 1 $cv config $mv errmessage
    if {$rv ne ""} {upvar 1 $rv refs} else {set refs {}}

    if {![ValidArguments \
	      $top $config(artype) $config(respath) \
	      packages errmessage]} {
	return 0
    }

    # packages = list (object (teapot::metadata::container))

    return [genMeta $packages $top config errmessage refs]
}

# ### ### ### ######### ######### #########
## API. Non-recursive directory processing.
##      Explicit meta data.

proc ::teapot::package::gen::genMeta {packages top cv mv {rv {}}} {
    # config = artype respath timestamp (logcmd)
    upvar 1 $cv config $mv errmessage
    if {$rv ne ""} {upvar 1 $rv refs} else {set refs {}}

    # packages = list (object (teapot::metadata::container))
    #          = list (OMTC)

    if {![Process $top config packages errmessage]} {
	return 0
    }

    set artype    $config(artype)
    set respath   $config(respath)
    set timestamp $config(timestamp)

    # packages = list(list (OMTC archive))

    if {[llength $packages] == 1} {
	Log "[llength $packages] package found, generate $artype archive ..."
    } else {
	Log "[llength $packages] packages found, generating $artype archives ..."
    }

    if {[llength [info commands ::teapot::package::gen::${artype}::init]]} {
	# Initialize the backend for the current package directory.
	::teapot::package::gen::${artype}::init $top $respath
    }

    if {[llength [info commands ::teapot::package::gen::${artype}::archive]]} {
	set arcmd ::teapot::package::gen::${artype}::archive

	foreach item $packages {
	    foreach {p archive} $item break
	    set archive [$arcmd $p $top $archive]

	    Log "- $archive"

	    set pv [$p version]
	    $p reversion $pv$timestamp

	    ::teapot::package::gen::${artype}::generate $p $top $archive
	    newArchive $archive

	    # Record references, for use by a recursion.
	    lappend refs [list [$p name] -version $pv -exact 1] [$p get]
	    $p destroy
	}

    } else {
	foreach item $packages {
	    foreach {p archive} $item break

	    Log "- $archive"

	    set pv [$p version]
	    $p reversion $pv$timestamp

	    ::teapot::package::gen::${artype}::generate $p $top $archive
	    newArchive $archive

	    # Record references, for use by a recursion.
	    lappend refs [list [$p name] -version $pv -exact 1] [$p get]
	    $p destroy
	}
    }

    return 1
}

# ### ### ### ######### ######### #########
## Internals. Recursion helper, logging, common strings,
##            validation.

proc ::teapot::package::gen::RecurseCore {top cv} {
    upvar 1 $cv config ;# array - artype respath timestamp arinfix logcmd compile
    set references {}

    foreach subdir [glob -nocomplain -dir $top -type d *] {
	if {[Ignore [file tail $subdir]]} continue
	foreach p [recurse $subdir config] {
	    lappend references $p
	}
    }

    return $references
}

proc  ::teapot::package::gen::Ignore {d} {
    variable ipatterns
    foreach p $ipatterns {
	if {[string match $p $d]} {return 1}
    }
    return 0
}

proc ::teapot::package::gen::Log {text} {
    upvar 1 config config
    if {$config(logcmd) eq ""} return
    set logcmd $config(logcmd)
    lappend logcmd $text
    uplevel #0 $logcmd
    return
}

proc ::teapot::package::gen::MDFile {top} {
    return [file join $top teapot.txt]
}

proc ::teapot::package::gen::ValidArguments {top artype respath pv mv} {
    upvar 1 $pv packages $mv errmessage

    # Checks
    # - chosen backend (artype) ok ?
    # - top/teapot.txt : exists & readable ?
    # - top/teapot.txc : md parse ok ?
    # - Do we have packages at all ?
    # - type of result path and #packages compatible ?

    if {[catch {
	package require teapot::package::gen::$artype
    }]} {
	set errmessage "Backend \"$artype\" not known."
	return 0
    }

    set mdfile [MDFile $top]

    if {![file exists $mdfile]} {
	set errmessage "No meta-data file found in \"$top\"."
	return 0
    }

    if {![file readable $mdfile]} {
	set errmessage "Meta-data file in \"$top\" is not readable."
	return 0
    }

    if {![file isfile $mdfile]} {
	set errmessage "Meta-data file in \"$top\" is not file."
	return 0
    }

    set errors {}
    set fail [catch {
	set packages [::teapot::metadata::read::fileEx $mdfile multi errors]
    } msg]
    if {$fail || [llength $errors]} {
	if {!$fail} {set msg [join $errors \n]}
	set errmessage $msg
	return 0
    }

    # packages = list (object (teapot::metadata::container))

    if {[llength $packages] == 0} {
	set errmessage "No packages specified."
	return 0
    } elseif {[llength $packages] > 1} {
	if {[file exists $respath] && [file isfile $respath]} {
	    set errmessage "Multiple packages specified, but user requested generation of a single file"
	    return 0
	}
    }

    return 1
}

proc ::teapot::package::gen::Process {top cv pv mv} {
    # config = artype arinfix respath compile (logcmd)
    upvar 1 $pv packages $mv errmessage $cv config

    set res {}
    set artype  $config(artype)
    set arinfix $config(arinfix)
    set respath $config(respath)
    set compile $config(compile)

    # packages = list (object (teapot::metadata::container))
    #          = list (OTMC)
    #    assert (length (packages) > 0)

    # res = list(list (OMTC archive))

    # =1 package - Included/Excluded optional
    # >1 package - Included required, Excluded optional

    # =1 package + file - Archive = respath
    # =1 package + dir  - see below.
    # >1 package + dir  - Archive = respath/name+version+platform.artype

    if {[file exists $respath]} {
	set dir [file isdirectory $respath]
    } else {
	set multiple [expr {[llength $packages] > 1}]
	set dir $multiple
    }

    foreach p $packages {
	$p clear __*

	Log [$p instance]

	teapot::instance::split [$p instance] pe pn pv pa

	if {![::teapot::metadata::filesSet $top $p errmessage]} {
	    append errmessage " for $pe \"$pn\""
	    return 0
	}

	::teapot::metadata::minTclVersionSet $p

	if {![::teapot::metadata::entrySet $p errmessage]} {
	    append errmessage " found for package \"$pn\""
	    return 0
	}

	if {$dir} {
	    set archive [file join $respath \
			     [PFilename $pe $pn $pv $pa $artype $arinfix]]
	} else {
	    set archive $respath
	}

	# Copy flags for various special actions over to the keys
	# actually used by the backends.

	if {[$p exists autopath]} {
	    $p add __autopath
	}

	if {[$p exists tcl_findLibrary/force]} {
	    $p add __tcl_findLibrary/force [$p getfirst tcl_findLibrary/force]
	}

	if {[$p exists initprefix]} {
	    $p setfor __initprefix [$p getfor initprefix]
	}

	if {[$p exists circles]} {
	    $p setfor __circles [$p getfor circles]
	}

	if {[$p exists as::pkggen::hint::skiprq]} {
	    $p setfor __skiprq [$p getfirst as::pkggen::hint::skiprq]
	} else {
	    $p setfor __skiprq 0
	}

	# Remove the meta data keywords used by the generator but of
	# no use to the user of the package from the database.

	foreach key {
	    included excluded
	    entrysource entryload
	    entrytclcommand entrykeep
	    autopath tcl_findLibrary/force initprefix circles
	    as::pkggen::hint::skiprq
	} {
	    $p unset $key
	}

	FileDict $p $top
	if {$compile} {Compile $p}

	lappend res [list $p $archive]
    }

    # FUTURE: intersection/union of files against each other, and warn
    #         about anomalities.

    set packages $res
    return 1
}

# - NProfiles
#
# Count the number of profiles in the list of packages.

proc ::teapot::package::gen::NProfiles {packages} {

    # packages = list (object (teapot::metadata::container))

    set n 0
    foreach p $packages {
	if {[IsProfile $p]} {incr n}
    }
    return $n
}

proc ::teapot::package::gen::IsProfile {p} {
    set t [teapot::entity::norm [$p type]]
    return [expr { ($t eq "profile") ||
		  (($t eq "package" && [$p exists profile]))}]
}

# - PFilename
#
# Construct the file name for a package archive out of package name,
# version, architecture, and type/format of the archive to be.

proc ::teapot::package::gen::PFilename {entity name version architecture artype arinfix} {
    variable namemap

    if {$arinfix ne ""} {append version -$arinfix}

    return \
	${entity}-[string map $namemap $name]-${version}-${architecture}.$artype
}

proc ::teapot::package::gen::FileDict {p top} {
    # Standardize the __files into a (path status) dict instead of a
    # path list. with the status preset to 'non-transient' aka 'external'
    # file.

    if {![$p exists __files]} {$p setfor __files {} ; return}
    set res {}
    foreach f [$p getfor __files] {
	lappend res $f 0 [file join $top $f]

	log::debug "FileDict ([lindex $res end-2])"
	log::debug "         ([lrange $res end-1 end])"
    }

    log::debug "    Set __files"
    $p setfor __files $res
    return
}

proc ::teapot::package::gen::Compile {p} {
    upvar 1 config config
    package require compiler

    set     preamble {}
    lappend preamble {#}
    lappend preamble {# TEAPOT Compiled by package generator}
    lappend preamble {#}
    set     preamble [join $preamble \n]

    # Sourced entry files are always Tcl files, to be compiled.
    # Bug 46016.

    array set e {}
    if {[$p getfirst __ecmd] eq "source"} {
	foreach efile [$p getfirst __efile] {set e($efile) .}
    }

    set compiled 0
    set res {}
    foreach {f istemp fsrc} [$p getfor __files] {
	if {![IsTclFileNoIndex $f] && ![info exists e($f)]} {
	    Log "    $f"

	    # File which is not compiled.
	    lappend res $f $istemp $fsrc
	    continue
	}

	# Compile the file. Throw away a temp src.
	Log "  * $f"

	set temp [fileutil::tempfile]
	uplevel #0 [list ::compiler::compile -preamble $preamble $fsrc $temp]
	lappend res $f 1 $temp
	set compiled 1

	if {$istemp} {file delete $fsrc}
    }

    log::debug "    Set __files (compiled)"
    $p setfor __files $res

    # Extend the list of requirements for the package. A package with
    # compiled files needs tbcload for their interpretation.

    if {$compiled} {
	$p add require tbcload
    }

    return
}

#
# IsTclFile --
#
#	Identify Tcl files by name (extension)
#	Identify Tcl files which are not package indices.
#
# Arguments:
#	path	path to file to identify
#
# Results:
#	Boolean flag.

proc ::teapot::package::gen::IsTclFileNoIndex {path} {
    return [expr {
	[string equal .tcl [file extension $path]] &&
	![string equal pkgIndex.tcl [file tail $path]]
    }]
}

# ### ### ### ######### ######### #########
## List of generated archives.

proc ::teapot::package::gen::clearArchives {} {
    variable thearchives {}
    return
}

proc ::teapot::package::gen::newArchive {path} {
    variable thearchives
    lappend  thearchives $path
    return
}

proc ::teapot::package::gen::generatedArchives {} {
    variable thearchives
    return  $thearchives
}

# ### ### ### ######### ######### #########
## Internals. Initialization of data structures.

namespace eval ::teapot::package::gen {
    variable namemap   {% %25 : %3a}
    variable ipatterns {}
    variable thearchives {}
}

# ### ### ### ######### ######### #########
## Ready
return

# ### ### ### ######### ######### #########
## NOTES ==================================

# Backend API.
#
# Special keys in the container. The behaviour of the backend is
# controlled by these keys (and 'profile'). It must not print them
# into the generated archive file. It actually must not pass any key
# matching '__*' into the generated archive file.
#
# __mintcl - min version of tcl, first element only
# __files  - list of files in the package
# __ecmd   - first, code for package index, 'entry command'
#            source - __efile = list of files to source
#            load   - __efile = list of files to load
#            keep   - __efile irrelevant, keep existing package index
# __efile  - first, list of files which are entrypoints
