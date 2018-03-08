# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# (c) 2008 ActiveSTate Software Inc.
# Implementation of the VFSE command line operations.
# ### ######### ###########################

# ### ######### ###########################

namespace eval cli {
    variable ar {}
}

package require fileutil

# ### ######### ###########################

proc cli::commands {} {
    return {open vacuum rm put get ls unwrap}
}

proc cli::do {ar cmd cmdargs} {
    # cmd 'open' is special, it goes back to the GUI.

    if {$cmd eq "open"} {
	if {![llength $cmdargs]} {
	    return [list $ar]
	    # This cuts the command out of the cmdline and falls
	    # through to the gui open.
	} else usage
    }

    do_$cmd $cmdargs [setarchive $ar]
    catch {vfs::unmount /ARCHIVE}
    exit
}

proc cli::setarchive {arfile} {
    # Mount a file. Metakit, or Zip. We mount it at a fixed location,
    # /ARCHIVE. Result is the type of the archive.

    # Errors are caught and cause us to print the usage line.

    variable ar $arfile

    set type [fileutil::fileType $arfile]

    if {"metakit" in $type} {
	package require vfs::mk4
	if {[catch {
	    vfs::mk4::Mount $arfile /ARCHIVE
	} msg]} {usage "$ar: $msg"}
	return metakit
    }

    # Not metakit, try as zip file instead.
    if {"zip" in $type} {
	package require vfs::zip
	if {[catch {
	    vfs::zip::Mount $arfile /ARCHIVE
	} msg]} {usage "$ar: $msg"}
	return zip
    }

    usage "$ar is neither zip- nor metakit archive, but a $type"
    return
}

proc cli::do_rm {cmdargs artype} {
    if {![llength $cmdargs]} usage
    if {$artype eq "zip"}    usage
    foreach path $cmdargs {
	file delete -force /ARCHIVE/$path
    }
    return
}

proc cli::do_put {cmdargs artype} {
    if {[llength $cmdargs] != 2} usage
    if {$artype eq "zip"}        usage
    lassign $cmdargs src dst
    file copy -force $src /ARCHIVE/$dst
    return
}

proc cli::do_get {cmdargs artype} {
    if {[llength $cmdargs] != 2} usage
    lassign $cmdargs src dst
    file copy -force /ARCHIVE/$src $dst
    return
}

proc cli::do_ls {cmdargs artype} {
    if {[llength $cmdargs]} usage
    array set has {}
    foreach f [fileutil::find /ARCHIVE] {
	# TODO: Determine why 'find' returns each path twice!
	if {[info exists has($f)]} continue
	set has($f) .
	puts [fileutil::stripPath /ARCHIVE $f]
    }
    return
}

proc cli::do_unwrap {cmdargs artype} {
    variable ar
    if {[llength $cmdargs]} usage

    set dst [file join [pwd] [file rootname [file tail $ar]].vfs]
    if {[file exists $dst]} {
	return -code error "Destination $dst already exists, cannot overwrite"
    }

    array set has {}
    set n 0
    foreach f [fileutil::find /ARCHIVE] {
	# TODO: Determine why 'find' returns each path twice!
	if {[info exists has($f)]} continue
	set has($f) .
	if {[file isdirectory $f]} continue
	incr n
	set fx [fileutil::stripPath /ARCHIVE $f]

	file mkdir [file dirname $dst/$fx]
	file copy $f $dst/$fx
    }

    puts "$n [expr {$n == 1 ? "file" : "files"}] written."
    return
}

proc cli::do_vacuum {cmdargs artype} {
    if {[llength $cmdargs]} usage
    if {$artype eq "zip"}   usage

    # SNARFED from devkit/app.shrinkit.tcl
    # Consider creation of a small package we can share around.

    # Something of note: Vacuuming a vacuumed file seems to extend it
    # by a single byte, and this can be repeated. Find out why. Theory:
    # Additional separator chars between prefix and fs get added.

    variable ar
    vfs::unmount /ARCHIVE

    # Get a kit/pack prefix coming before the filesystem, copy to
    # compacted destination
    set binprefix [fileutil::cat -encoding binary -translation binary $ar]

    # Look for the MK magic marker, strip it and everthing after off.
    set footer [string range $binprefix end-15 end]
    set off    [xsplit I \x4a\x4c\x1a]
    if {$off < 0} {
	set off [xsplit i \x4c\x4a\x1a]
	if {$off < 0} {
	    puts "Unable to locate start of MK"
	    exit 1
	}
    }

    incr off
    set binprefix [string range $binprefix 0 end-$off]

    set t [fileutil::tempfile SHRINK]
    fileutil::writeFile -encoding binary -translation binary $t $binprefix\x1A

    # Vacuum the filesystem, and attach it to the compacted destination
    mk::file open  fs $ar   ; set chan [open $t a]
    mk::file save  fs $chan ; close $chan
    mk::file close fs
    
    file copy -force $t $ar
    file delete $t
    return
}

# ### ######### ###########################

proc cli::xsplit {f tag} {
    upvar 1 footer footer binprefix binprefix

    binary scan $footer $f$f$f$f _ hdr _ _
    #puts $hdr

    incr hdr 15
    set x $hdr ; incr x -2

    set h [string range $binprefix end-$hdr end-$x]
    #puts |$h|

    if {$h ne $tag} {
	#puts Mismatch
	return -1
    }
    return $hdr
}

# ### ######### ###########################

proc cli::usage  {{msg {}}} {
    global argv argv0
    puts stderr ""
    puts stderr "Usage: $argv0 "
    puts stderr "       $argv0 ARCHIVE"
    puts stderr "       $argv0 ARCHIVE open"
    puts stderr "       $argv0 ARCHIVE vacuum"
    puts stderr "       $argv0 ARCHIVE ls"
    puts stderr "       $argv0 ARCHIVE rm PATH-IN-ARCHIVE..."
    puts stderr "       $argv0 ARCHIVE get PATH-IN-ARCHIVE PATH'"
    puts stderr "       $argv0 ARCHIVE put PATH' PATH-IN-ARCHIVE"
    puts stderr "       $argv0 ARCHIVE..."
    puts stderr ""
    puts stderr "Note: vacuum, put, and rm work only for metakit archives"
    puts stderr "Note: open, get, and ls work for both metakit and zip archives"
    puts stderr ""

    if {$msg ne ""} {
	puts stderr "$msg"
	puts stderr ""
    }
    exit 1
}

# ### ######### ###########################
