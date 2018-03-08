# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::package::gen::auto 0.1
# Meta platform    tcl
# Meta require     teapot::package::gen::zip
# Meta require     teapot::package::gen::tm
# @@ Meta End

# -*- tcl -*-
# Package generation - Backend: Autoselection of archive type

# ### ### ### ######### ######### #########
## Requirements

package require teapot::entity
package require teapot::package::gen::zip      ; # Zip archives
package require teapot::package::gen::tm       ; # TM archives

namespace eval ::teapot::package::gen::auto {}

# ### ### ### ######### ######### #########
## API. Name override hook

proc ::teapot::package::gen::auto::archive {p top archive} {
    # Backend hook to modify the name of the archive
    # Based on selection of backend.

    return [file rootname $archive].[Backend $p]
}

# ### ### ### ######### ######### #########
## API. Generation entry point.

proc ::teapot::package::gen::auto::generate {p top archive} {
    # NOTE: top ignored, all in p->__files

    # This backend auto-select what type of archive is generated, zip
    # or tm, based on the metadata (entry point, file dictionary,
    # platform).

    ::teapot::package::gen::[$p getfirst __backend]::generate $p $top $archive
    return
}

# ### ### ### ######### ######### #########

proc ::teapot::package::gen::auto::IsProfile {p} {
    set t [teapot::entity::norm [$p type]]
    return [expr { ($t eq "profile") ||
		  (($t eq "package" && [$p exists profile]))}]
}

proc ::teapot::package::gen::auto::Backend {p} {
    # NOTE: top ignored, all in p->__files

    # This backend auto-selects what type of archive is generated, zip
    # or tm, based on the metadata (entry point, file dictionary,
    # platform).

    # 1. Looking at the files, if there is no .so .sl .dll, or .dylib
    #    file in the set we assume that the package is actually pure Tcl.
    #    If so the platform information is forced to 'tcl'.
    # 2. An 'entrykeep' is always a .zip
    # 3. A profile is always a .tm
    # 4. A non pure-Tcl package is always a .zip
    # From here on the package is pure Tcl.
    # 5. If no files at all (bundle), or single file, a .tm
    # 6. A multi-file Tcl package depends. If all files entrypoints
    #    then .tm, else .zip.

    set binaries 0
    if {[$p exists __files]} {
	foreach {f istemp fsrc} [$p getfor __files] {
	    if {[string match *.so    $f]} {set binaries 1 ; break}
	    if {[string match *.sl    $f]} {set binaries 1 ; break}
	    if {[string match *.dll   $f]} {set binaries 1 ; break}
	    if {[string match *.dylib $f]} {set binaries 1 ; break}
	}
    }

    if {!$binaries && ([$p getfirst platform] ne "tcl")} {
	$p rearch tcl
    }

    if {[$p exists entrykeep]} {
	$p setfor __backend zip
	return zip
    } elseif {[IsProfile $p]} {
	$p setfor __backend tm
	return tm
    } elseif {$binaries} {
	$p setfor __backend zip
	return zip
    }

    set ecmd     [$p getfirst __ecmd]
    set efile    [$p getfirst __efile]
    set filedict [$p getfor   __files]

    if {[llength $filedict] == 3} {
	# single file
	$p setfor __backend tm
	return tm
    } elseif {[llength $filedict] == 0} {
	# no files, bundle
	$p setfor __backend tm
	return tm
    }

    if {$ecmd eq "source"} {
	# dict -> set of files
	set files {}
	foreach {f istemp fsrc} $filedict {lappend files $f}

	set excess [struct::set difference $files $efile]

	if {![llength $excess]} {
	    $p setfor __backend tm
	    return tm
	}
    }

    $p setfor __backend zip
    return zip
}


# ### ### ### ######### ######### #########
## Ready.
return
