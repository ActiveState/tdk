# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::package::gen::tm 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     starkit
# Meta require     struct::set
# Meta require     teapot::metadata::write
# Meta require     vfs::mk4
# @@ Meta End

# -*- tcl -*-
# Package generation - Backend: Tcl Module

# ### ### ### ######### ######### #########
## Requirements

package require fileutil                ; # File handling
package require struct::set             ; # Set operations.
package require teapot::entity
package require teapot::metadata::write ; # MD formatting for output
package require vfs::mk4                ; # Metakit/Starkit Filesystem

namespace eval ::teapot::package::gen::tm {}

# ### ### ### ######### ######### #########
## API. Generation entry point.

proc ::teapot::package::gen::tm::generate {p top archive} {
    # NOTE: top ignored, all in p->__files

    if {[$p exists __ecmd] && ([$p getfirst __ecmd] eq "keep")} {
	return -code error "TM is unable to handle the keeping of a pre-existing pkgIndex.tcl"
    }

    file mkdir [file dirname $archive]

    set usevfs [UseVFS $p files]
    if {$usevfs} {
	$p add require starkit
    }

    set       ch [open $archive w]
    TMHeader $ch [IsProfile $p]
    MDHeader $ch $p

    if {[IsProfile $p]} {
	# The package is a profile. It consists of only the meta
	# data. Close it.

	StopHeader $ch
	close $ch
	return
    }

    set ecmd     [$p getfirst __ecmd]
    set efile    [$p getfirst __efile]
    set filedict [$p getfor   __files]

    RqHeader $ch $p

    if {[llength $filedict] == 3} {
	# [x]
	# Single file package. Just attach the file to the header
	# part generated so far.

	StopHeader $ch
	foreach {f istemp fsrc} $filedict break

	Attach $ch $fsrc
	close  $ch

	if {$istemp} {file delete $fsrc}
	return
    }

    # Multiple files, or no files. Here the entry code comes into
    # play.

    if {[llength $filedict] == 0} {
	# No files. Package is a bundle, or other type of thing which
	# uses direct tcl code for activation instead reading a file.

	StopHeader $ch
	LdHeader   $ch $ecmd $efile
	close      $ch
	return
    }

    # Multiple files.
    # We already know whether to use VFS or not, because of the UseVFS
    # at the beginning. No need to replicate that.

    if {!$usevfs} {
	# 'files' is populated already as well.

	puts   $ch "\#\# Multi-entry Tcl package."
	puts   $ch "\#\# Concatenating the implementation files."
	puts   $ch "\#\#"

	StopHeader $ch

	array set temp {}
	array set src  {}
	foreach {f istemp fsrc} $filedict {
	    set temp($f) $istemp
	    set src($f)  $fsrc
	}

	foreach f $efile {
	    puts   $ch "\#\# * $f"
	}

	foreach f $efile {
	    puts   $ch ""
	    puts   $ch "\#\#"
	    puts   $ch "\# --- $f --- --- ---"
	    puts   $ch "\#\#"
	    puts   $ch ""
	    Attach $ch $src($f)

	    if {$temp($f)} {file delete $src($f)}
	}
	close  $ch
	return
    }

    # Continue the header generated so far with the
    # boilerplate code for kit activation and transfer of control to
    # the entrypoint, then close the file and mount it as a kit, at
    # last copy the package files into this filesystem.

    KitHeader $ch
    close     $ch
    KitAttach $archive $filedict $ecmd $efile $p

    return
}

# ### ### ### ######### ######### #########
## Test is a profile ?

proc ::teapot::package::gen::tm::IsProfile {p} {
    set t [teapot::entity::norm [$p type]]
    return [expr { ($t eq "profile") ||
		  (($t eq "package" && [$p exists profile]))}]
}

# ### ### ### ######### ######### #########
## Internals. Code generation, VFS filling, ...

proc ::teapot::package::gen::tm::UseVFS {p fv} {
    upvar 1 $fv files

    # Determine details of the packaging. I.e is a VFS used or not ?

    if {[$p exists __ecmd] && ([$p getfirst __ecmd] eq "keep")} {
	return -code error "TM is unable to handle the keeping of a pre-existing pkgIndex.tcl"
    }

    if {[IsProfile $p]} {
	return 0 ; # No VFS
    }

    set ecmd     [$p getfirst __ecmd]
    set efile    [$p getfirst __efile]
    set filedict [$p getfor   __files]

    if {[llength $filedict] == 3} {
	return 0 ; # No VFS
    }

    # Multiple files, or no files. Here the entry code comes into
    # play.

    if {[llength $filedict] == 0} {
	# No files. Package is a bundle, or other type of thing which
	# uses direct tcl code for activation instead reading a file.

	return 0 ; # No VFS
    }

    # Multiple files.

    # If we have one or more entry files which are a true subset of
    # all files in the package we are forced to go with a virtual
    # filesystem. Ditto if the entry files are load'ed, as binaries
    # cannot be concatenated. In that case the entry files are sourced
    # or loaded from the virtual filesystem, in the order specified.

    # Otherwise, i.e. all files in the packages are the entry files,
    # and they are source'd, we concatenate them in the order
    # specified, and assume that they are not bailing out with early
    # returns. The code at [x] is actually a special case of this,
    # knowing that for a single file the set of entries and set of
    # impl. have to be identical.

    if {$ecmd eq "source"} {
	# dict -> set of files
	set files {}
	foreach {f istemp fsrc} $filedict {lappend files $f}

	set excess [struct::set difference $files $efile]

	if {![llength $excess]} {
	    return 0
	}
    }

    return 1
}

proc ::teapot::package::gen::tm::StopHeader {ch} {
    puts $ch "\# OPEN TEAPOT-PKG END TM"
    return
}

proc ::teapot::package::gen::tm::TMHeader {ch isprofile} {
    global tcl_platform
    puts $ch "\# OPEN TEAPOT-PKG BEGIN TM -*- tcl -*-"
    puts $ch "\# -- Tcl Module"
    if {$isprofile} {
	puts $ch "\# -- Profile"
    }
    return
}

proc ::teapot::package::gen::tm::MDHeader {ch p} {
    puts $ch ""
    puts $ch [::teapot::metadata::write::getStringEmbeddedC $p]
    puts $ch ""
    return
}

proc ::teapot::package::gen::tm::RqHeader {ch p} {
    # Code checking all requirements, insert before handing control to
    # the actual package functionality. Should we have any.

    if {
	![$p getfor __skiprq] &&
	[$p exists require] &&
	[llength [$p getfor require]]
    } {
	set circles [expr {[$p exists __circles] ? [$p getfor __circles] : ""}]
	puts $ch \
	    [::teapot::metadata::write::requirePkgListString \
		 [$p getfor require] $circles]
    }

    puts $ch [::teapot::metadata::write::providePkgString [$p name] [$p version]]
    return
}

proc ::teapot::package::gen::tm::Attach {ch path} {
    set    f [open $path r]
    fcopy $f $ch
    close $f
    return
}

proc ::teapot::package::gen::tm::LdHeader {ch type file} {
    if {$type ne "tcl"} {
	return -code error \
	    "Bad package activation type \"$type\".\
             Need a file, have none."
    }

    # file is actually a tcl command.

    puts $ch $file
    return
}

proc ::teapot::package::gen::tm::KitHeader {ch} {
    puts $ch "\# OPEN TEAPOT-PKG BEGIN TM_STARKIT_PROLOG"
    puts $ch "package require starkit"
    puts $ch "starkit::header mk4 -readonly"
    puts $ch "\# OPEN TEAPOT-PKG END TM_STARKIT_PROLOG"
    StopHeader $ch
    # force eof for source command.
    puts -nonewline $ch "\x1A"
    return
}

proc ::teapot::package::gen::tm::KitAttach {outdir filedict type file p} {
    vfs::mk4::Mount $outdir $outdir

    set main [file join $outdir main.tcl]
    if {$type eq "tcl"} {
	# file is actually a tcl command.
	set    content ""
	append content {set dir [file dirname [info script]]} \n
	append content $file
    } else {
	# ecmd in {source,load}.
	# efile = list(path)

	# The main.tcl forwards to the actual entrypoints. The starkit
	# startup is already done when this happens, by the TM
	# header. Otherwise main.tcl itself would be inaccessible.

	set content ""
	foreach f $file {
	    append content [string map [list \
				      @@ $type \
				      %% $f \
		   ] {@@ [file join [file dirname [info script]] {%%}]}]\n
	}
    }

    set pn [$p name]
    set pv [$p version]

    append content [::teapot::metadata::write::providePkgString $pn $pv]\n

    fileutil::writeFile $main $content

    foreach {f istemp fsrc} $filedict {
	set dst    [file join $outdir $f]
	file mkdir [file dirname $dst]
	file copy -force $fsrc $dst
	if {$istemp} {file delete $fsrc}
    }
    vfs::unmount $outdir
    return
}

# ### ### ### ######### ######### #########
## Ready
return
