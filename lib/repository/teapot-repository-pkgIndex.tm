# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::repository::pkgIndex 0.1
# Meta platform    tcl
# Meta require     fileutil
# @@ Meta End

# -*- tcl -*-
# Manage a global package index.

# ### ### ### ######### ######### #########
##

package require fileutil

namespace eval ::teapot::repository::pkgIndex {}

# ### ### ### ######### ######### #########
##

proc ::teapot::repository::pkgIndex::insert {base path tclver} {
    ExtendTrace Insert '$base', '$path', '$tclver'

    NewFile $base

    set lines   [Load $base]
    set changes 0

    if {![HasSection $lines $tclver at]} {
	set at [InsertSection lines $tclver]
	set changes 1
    } else {
	ExtendTrace Section $tclver found on line $at
    }

    if {![HasPackage $lines $path]} {
	InsertPackage lines $path $at
	set changes 1
    } else {
	ExtendTrace Package already present.
    }

    if {$changes} { Store $base $lines }

    #puts "| TRACE\t[join [DumpTrace] "\n| TRACE\t"]"
    return
}

proc ::teapot::repository::pkgIndex::remove {base path} {
    ExtendTrace Remove '$base', '$path'

    if {[NewFile $base]} return

    set lines [Load $base]
    set n 0
    foreach line $lines {
	if {[IsIfneeded $line p] && ($p eq $path)} {
	    ExtendTrace Package found on line $n

	    Store $base [lreplace $lines $n $n]
	    #puts "| TRACE\t[join [DumpTrace] "\n| TRACE\t"]"
	    return
	}
	incr n
    }

    ExtendTrace Package not found
    # Due to changes in the ordering of ops by repo::localma 'Not
    # found' is now an acceptable result. The package may have been
    # partially deleted already (pkgIndex.tcl at least, maybe more,
    # but not yet in the database).

    #puts "| TRACE\t[join [DumpTrace] "\n| TRACE\t"]"
    #foreach l $lines { set p "" ; if {[IsIfneeded $line p]} { set tag ** } else { set tag -- } ; puts "$tag $l -- $p" }
    return
}

# ### ### ### ######### ######### #########

proc ::teapot::repository::pkgIndex::update {base how script {mv {}}} {

    set old [Save $base]
    ClearTrace

    if {
	[catch {uplevel 1 $script}   msg] ||
	[ValidationFailed $base $how msg]
    } {
	Restore $base $old
	if {$mv ne ""} {
	    upvar 1 $mv m
	    set m $msg
	}
	return 0
    }
    return 1
}

proc ::teapot::repository::pkgIndex::clear {base} {
    file delete [Index       $base]
    file delete [IndexHelper $base]
    return
}

proc ::teapot::repository::pkgIndex::Save {base} {
    set gpi [Index       $base]
    set gps [IndexHelper $base]
    set res {}
    if {![file exists $gpi]} { lappend res [NewData] } else { lappend res [fileutil::cat $gpi] }
    if {![file exists $gps]} { lappend res {}        } else { lappend res [fileutil::cat $gps] }
    return $res
}

proc ::teapot::repository::pkgIndex::Restore {base data} {
    foreach {idx helper} $data break
    if {$idx    ne ""} { ::fileutil::writeFile [Index       $base] $idx    }
    if {$helper ne ""} { ::fileutil::writeFile [IndexHelper $base] $helper }
    return
}

# ### ### ### ######### ######### #########

proc ::teapot::repository::pkgIndex::ValidationFailed {base how mv} {
    upvar 1 $mv msg
    set script [fileutil::cat [Index $base]]

    interp create v
    interp eval v {proc package {args} {return 1}};# overload package vsatisfies
    interp eval v {proc source  {args} {}}        ;# overload source to nothing
    interp eval v {set dir placeholder}           ;# global var needed

    set fail [catch {
	interp eval v $script
    } xmsg]

    interp delete v

    if {!$fail} {return 0}

    ExtendTrace Syntax broken ___
    ExtendTrace $xmsg
    ExtendTrace _________________

    set    msg ""
    append msg "| FATALITY. ABORTING (Apologies for that).\n"
    append msg "|\n"
    append msg "| Teacup managed to screw up the editing of the repository internal package index\n"
    append msg "| (pkgIndex.tcl below).\n"
    append msg "|\n"
    append msg "| The good news is that it managed to detect this before it was fatal and left the\n"
    append msg "| repository in a usable state.\n"
    append msg "|\n"
    append msg "| To help us debug the situation please provide us with a report of this problem.\n"
    append msg "| Please use the ticketing system of the source repository you got teacup/teapot\n"
    append msg "| from.\n"
    append msg "|\n"
    append msg "| Please attach this output, especially the trace coming below, and also all\n"
    append msg "| of the files mentioned in the trace (they are marked with _FF_).\n"
    append msg "|\n"
    append msg "| Thank you for your help with this.\n"
    append msg "|\n"
    append msg "| TRACE\t[join [DumpTrace] "\n| TRACE\t"]"

    return 1
}

# ### ### ### ######### ######### #########
## Internal tracing of conditions and actions taken, to be used when
## the validation of the modified pkgIndex.tcl fails, indicating a bug
## in the logic of edits.

proc ::teapot::repository::pkgIndex::ClearTrace {} {
    variable actionlog ""
    return
}

proc ::teapot::repository::pkgIndex::ExtendTrace {args} {
    variable actionlog
    lappend  actionlog $args
    return
}

proc ::teapot::repository::pkgIndex::DumpTrace {} {
    variable actionlog
    return $actionlog
}

# ### ### ### ######### ######### #########
##

proc ::teapot::repository::pkgIndex::NewFile {base} {
    set gpi [Index $base]

    if {![file exists $gpi]} {
	ExtendTrace New File Made
	ExtendTrace _FF_ pkgIndex.tcl = $gpi

	::fileutil::writeFile $gpi [NewData]
	return 1
    }
    return 0
}

proc ::teapot::repository::pkgIndex::NewData {} {
    return [join [list \
		   "# -*- tcl -*-" \
		   "# TEAPOT CLIP (Consolidated Local Index of Packages)"
		 ] \n]\n
}

proc ::teapot::repository::pkgIndex::Index {base} {
    return [file join $base pkgIndex.tcl]
}

proc ::teapot::repository::pkgIndex::IndexHelper {base} {
    return [file join $base pkgIndex.index]
}

# ### ### ### ######### ######### #########

proc ::teapot::repository::pkgIndex::Load {base} {

    ExtendTrace Load index
    ExtendTrace _FF_ pkgIndex.tcl = [Index $base]

    return [split [string trimright [::fileutil::cat [Index $base]] \n] \n]
}

proc ::teapot::repository::pkgIndex::Store {base lines} {
    ExtendTrace Store changed index

    ::fileutil::writeFile [Index $base] [join $lines \n]\n

    ExtendTrace _FF_ pkgIndex.tcl = [Index $base]
    return
}

# ### ### ### ######### ######### #########

proc ::teapot::repository::pkgIndex::InsertSection {lv tclver} {
    upvar 1 $lv lines

    ExtendTrace Insert section $tclver

    set n 0
    foreach line $lines {
	if {[IsSectionStart $line v] && ([package vcompare $v $tclver] > 0)} {
	    # Start of first section after the section to insert
	    # (Larger version number).
	    set lines [linsert $lines $n [Section $tclver]]

	    ExtendTrace First higher section $v found on line $n, inserting here
	    return $n
	}
	incr n
    }

    # Nothing found.
    set n [llength $lines]
    lappend lines [Section $tclver]

    ExtendTrace No higher section found, extending at end (line $n)
    return $n
}

proc ::teapot::repository::pkgIndex::InsertPackage {lv path at} {
    #puts "insert pkg - $path"

    upvar 1 $lv lines

    incr at ; # Step after the section-start.

    ExtendTrace Insert package at line $at

    set packagecode [Ifneeded $path]
    set lines       [linsert $lines $at $packagecode]
    return
}

# ### ### ### ######### ######### #########

proc ::teapot::repository::pkgIndex::Section {tclver} {
    return [string map [list @ $tclver] \
		{if {![package vsatisfies [package provide Tcl] @]} return}]
}

proc ::teapot::repository::pkgIndex::IsSectionStart {line vvar} {
    set secstart [string match {*if \{!\[package vsatisfies \[package provide Tcl\]*} $line]
    if {$secstart} {
	upvar 1 $vvar ver
	regexp {provide Tcl\] ([0-9.]+)]} $line -> ver
    }
    return $secstart
}

proc ::teapot::repository::pkgIndex::HasSection {lines tclver atvar} {
    set n 0
    foreach line $lines {
	if {[IsSectionStart $line v] && ([package vcompare $v $tclver] == 0)} {
	    upvar 1 $atvar at
	    set at $n
	    return 1
	}
	incr n
    }
    return 0
}

# ### ### ### ######### ######### #########

proc ::teapot::repository::pkgIndex::Ifneeded {path} {
    return [string map [list @ $path] \
		{set _ $dir ; set dir [file join $_ @] ; source [file join $dir pkgIndex.tcl] ; set dir $_ ; unset _}]
}

proc ::teapot::repository::pkgIndex::IsIfneeded {line pvar} {
    set ifn [string match {*set _ $dir ; set dir \[file join $_*} $line]
    if {$ifn} {
	upvar 1 $pvar path
	set n [regexp {file join \$_ ([^]]*)]} $line -> path]
    }
    return $ifn
}

proc ::teapot::repository::pkgIndex::HasPackage {lines path} {
    foreach line $lines {
	if {[IsIfneeded $line p] && ($p eq $path)} {
	    return 1
	}
    }
    return 0
}

##
# ### ### ### ######### ######### #########

return
