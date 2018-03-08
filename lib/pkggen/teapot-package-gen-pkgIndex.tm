# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::package::gen::pkgIndex 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     teapot::metadata::write
# Meta require     textutil
# @@ Meta End

# -*- tcl -*-
# Package generation - Backend: pkgIndex

# ### ### ### ######### ######### #########
## Requirements

package require fileutil 1.13.1         ; # File handling - relative has LexNormalize
package require teapot::entity
package require teapot::metadata::write ; # MD formatting for output.
package require textutil                ; # Text formatting

namespace eval ::teapot::package::gen::pkgIndex {}

# ### ### ### ######### ######### #########
## API. Initialization hook - This hook is called once per archive

proc ::teapot::package::gen::pkgIndex::arinit {archive} {
    # Delete an existing index file to get a clean state. This happens
    # only if the archive (= output path) is not indicating that we
    # are creating indices per package.

    if {$archive eq ""} return
    file delete	[file join $archive pkgIndex.tcl]
    return
}

# ### ### ### ######### ######### #########
## API. Initialization hook - This hook is called once per package directory.

proc ::teapot::package::gen::pkgIndex::init {top archive} {
    # Delete an existing index file to get a clean state. This happens
    # only if the archive (= output path) is not indicating that we
    # are creating a single master index.

    if {$archive ne ""} return
    file delete	[file join $top pkgIndex.tcl]
    return
}

# ### ### ### ######### ######### #########
## API. Name override hook

proc ::teapot::package::gen::pkgIndex::archive {p top archive} {
    # Backend hook to modify the name of the archive

    # We distinguish between single master index and per-package
    # indices, and generate different 'archive' names, i.e. paths for
    # pkgIndex per the found situation. Master index goes into archive,
    # per-package indices go into the package directory (top).

    if {$archive ne ""} {
	# Archive has a (to us bogus) filename already appended to the
	# output directory path. Remove that segment, we need only
	# the directory to create our own file.

	return [list [file join [file dirname $archive] pkgIndex.tcl] $top]
    }

    return [list [file join $top pkgIndex.tcl]]
}

# ### ### ### ######### ######### #########
## API. Profile recurse hook.

proc ::teapot::package::gen::pkgIndex::profileCapture {} {
    return 0
}

# ### ### ### ######### ######### #########
## API. Generation entry point

proc ::teapot::package::gen::pkgIndex::generate {p top archive} {
    if {[$p getfirst __ecmd] eq "keep"} {
	return -code error "Index is unable to handle the keeping of a pre-existing pkgIndex.tcl"
    }

    # Profiles have no pkgIndex.tcl file
    if {[IsProfile $p]} return

    # We distinguish between single master index and per-package
    # indices, and generate different slightly different index
    # scripts.

    if {[llength $archive] == 1} {
	set archive  [lindex $archive 0]
	set theindex [Index $p]\n

    } elseif {[llength $archive] == 2} {
	# Master index ...
	# Notes: Archive is index file, we need path to it, hence the dirname
	#        The top directory may be relative, hence using pwd to make it
	#        absolute.

	foreach {archive top} $archive break
	set rel      [::fileutil::relative \
			  [file join [pwd] [file dirname $archive]] \
			  [file join [pwd] $top]]
	set map      [list @ $rel]
	set cmd      {[file normalize [file join $dir {@}]]}
	set theindex [Index $p [string map $map $cmd]]\n
    } else {
	return -code error {INTERNAL ERROR in init/generate communication}
    }

    ::fileutil::appendToFile $archive $theindex
    return
}

proc ::teapot::package::gen::pkgIndex::IsProfile {p} {
    set t [teapot::entity::norm [$p type]]
    return [expr { ($t eq "profile") ||
		  (($t eq "package" && [$p exists profile]))}]
}

# ### ### ### ######### ######### #########
## API. Creation of the load command for a package.

proc ::teapot::package::gen::pkgIndex::Load {p {dircode {$dir}}} {
    set lines {}

    if {
	![$p getfor __skiprq] &&
	[$p exists require] &&
	[llength [$p getfor require]]
    } {
	set circles [expr {[$p exists __circles] ? [$p getfor __circles] : ""}]
	lappend lines \
	    [::teapot::metadata::write::requirePkgListString \
		 [$p getfor require] $circles]
    }

    if {[$p exists __autopath]} {
	lappend lines "    lappend auto_path {@}"
    }
    if {[$p exists __tcl_findLibrary/force]} {
	set var [$p getfirst __tcl_findLibrary/force]_LIBRARY
	lappend lines "    set [list ::env($var)] {@}"
    }

    set ecmd  [$p getfirst __ecmd]
    set efile [$p getfirst __efile]

    if {$ecmd eq "tcl"} {
	# efile is actually a tcl command.
	lappend lines "  set dir {@}"
	lappend lines $efile
    } else {
	# ecmd in {source,load}.
	# efile = list(path)

	array set pprefix {}
	if {[$p exists __initprefix]} {
	    array set pprefix [$p getfor __initprefix]
	}

	foreach f $efile {
	    set suffix ""
	    if {[info exists pprefix($efile)] && ($pprefix($efile) ne "")} {
		append suffix " $pprefix($efile)"
	    }
	    lappend lines "    [list $ecmd] \[file join {@} [list $f]\]$suffix"
	}
    }

    set pn [$p name]
    set pv [$p version]

    lappend lines {}
    lappend lines [::teapot::metadata::write::providePkgString $pn $pv]

    set lines [textutil::indent [join $lines \n] "        " 0]

    return "\[string map \[list @ $dircode\] \{\n$lines\n    \}\]"
}

# ### ### ### ######### ######### #########
## Internal. Create partial package index.

proc ::teapot::package::gen::pkgIndex::Index {p {dircode {$dir}}} {
    ## NOTE
    # This code generates a different pkgIndex.tcl file than the code
    # found in the 'zip' backend.
    #
    # The reason: The 'zip' backend generates an index for a single
    # package. Here on the other we have to be able to _extend_ the
    # package index, as the directory in question may contain multiple
    # packages.
    ##

    set loadcommand [Load $p $dircode]
    set pn          [$p name]
    set pv          [$p version]
    set ifneeded    "package ifneeded [list $pn $pv] $loadcommand"
    set guardian    [string map \
			 [list @ [$p getfirst __mintcl]] \
			 {[package vsatisfies [package provide Tcl] @]}]

    set     lines {}
    lappend lines {}
    lappend lines "if \{$guardian\} \{"
    lappend lines "    $ifneeded"
    lappend lines "\}"

    return [join $lines \n]
}

# ### ### ### ######### ######### #########
## Ready
return
