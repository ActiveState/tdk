# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::package::gen::zip 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     teapot::metadata::container
# Meta require     teapot::metadata::write
# Meta require     teapot::package::gen::pkgIndex
# Meta require     zipfile::encode
# @@ Meta End

# -*- tcl -*-
# Package generation - Backend: ZIP archives

# ### ### ### ######### ######### #########
## Requirements

package require fileutil                       ; # File handling
package require logger                         ; # Tracing
package require teapot::entity
package require teapot::metadata::container    ; # MD container
package require teapot::metadata::write        ; # MD formatting for output
package require teapot::package::gen::pkgIndex ; # Generation of a load command
package require zipfile::encode                ; # ZIP archive creation

logger::initNamespace ::teapot::package::gen::zip
namespace eval        ::teapot::package::gen::zip {}

# ### ### ### ######### ######### #########
## API. Generation entry point.

proc ::teapot::package::gen::zip::generate {p top archive} {
    # NOTE: top ignored, all in p->__files

    zipfile::encode z
    z file: teapot.txt 1 [set mdf [Meta $p]]
    z comment: [fileutil::cat $mdf]

    if {![IsProfile $p]} {
	# Any package requirements are stuffed into the loadcommand of
	# the package, in the index script we generate for the
	# package. All the complexity of stuffing them in front of the
	# entry file, or creating a new entry file to run before
	# loading a binary is not required anymore and has been
	# removed again.

	# Note that we generate a package index if and only if an
	# existing index file is not kept.

	if {[$p getfirst __ecmd] ne "keep"} {
	    z file: pkgIndex.tcl 1 [Index $p]
	}

	# Put the remaining files after the special ones.

	foreach {f istemp fsrc} [$p getfor __files] {
	    log::debug "zip ($f)"
	    log::debug "    ($istemp $fsrc)"

	    z file: $f $istemp $fsrc
	}
    }

    file mkdir [file dirname $archive]
    z write $archive
    z destroy
    return
}

# ### ### ### ######### ######### #########
## API. Recreation of archive from unpacked form + its MD

proc ::teapot::package::gen::zip::repack {p top archive} {

    zipfile::encode z
    z file: teapot.txt 1  [set mdf [Meta $p]]
    z comment: [fileutil::cat $mdf]

    log::debug "*repack top=($top)"
    set top [file dirname [file normalize [file join $top ___]]]
    log::debug "        top=($top)"

    foreach f [fileutil::find $top] {
	set fx [fileutil::stripPath $top $f]

	# Ignore a teapot.txt file in the directory. Its contents were
	# given to us via md container argument P, possibly modified.

	if {$fx eq "teapot.txt"} continue

	log::debug "       f = ($f)"
	log::debug "         = ($fx)"

	z file: $fx 0 $f
    }

    file mkdir [file dirname $archive]
    z write $archive
    z destroy
    return
}

# ### ### ### ######### ######### #########
## Internal. Generation of package index.

proc ::teapot::package::gen::zip::IsProfile {p} {
    set t [teapot::entity::norm [$p type]]
    return [expr { ($t eq "profile") ||
		  (($t eq "package" && [$p exists profile]))}]
}

proc ::teapot::package::gen::zip::Meta {p} {
    set meta [fileutil::tempfile]
    fileutil::writeFile $meta [::teapot::metadata::write::getStringExternalC $p]
    return $meta
}

proc ::teapot::package::gen::zip::Index {p} {

    # if {![package vsatisfies [package provide Tcl] @]} return
    # package ifneeded NAME VER {... source/load $dir/FILE ...}
    # @ = min version of Tcl needed for the package.

    set loadcommand [::teapot::package::gen::pkgIndex::Load $p]
    set pn          [$p name]
    set pv          [$p version]
    set ifneeded    "package ifneeded [list $pn $pv] $loadcommand"
    set guardian    [string map \
			 [list @ [$p getfirst __mintcl]] \
			 {[package vsatisfies [package provide Tcl] @]}]

    set     lines {}
    lappend lines {}
    lappend lines [::teapot::metadata::write::getStringEmbeddedC $p]
    lappend lines {}
    lappend lines "if \{!$guardian\} return"
    lappend lines {}
    lappend lines $ifneeded
    lappend lines {}

    set index [fileutil::tempfile]
    ::fileutil::writeFile $index [join $lines \n]
    return $index
}

# ### ### ### ######### ######### #########
## Ready.
return
