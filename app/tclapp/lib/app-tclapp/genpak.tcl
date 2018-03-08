# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#

# Copyright (c) 2006-2008 ActiveState Software Inc.
#


# 
# RCS: @(#) $Id: startup.tcl,v 1.5 2001/01/24 19:41:24 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require vfs::mk4
package require log
package require starkit
package require fileutil
package require tclapp

namespace eval ::tclapp::genpak {}

# ### ### ### ######### ######### #########
##

#
# genpak --
#
#	Conversion of starkits into starpacks.
#
# Arguments:
#	infile	The path to the file.
#
# Results:
#	None.

proc ::tclapp::genpak::run {spec} {
    package require fileutil

    Validate $spec basekit starkit result other

    # Mount the starkit under ourselves, then create a set of
    # options using this directory as a source, at last invoke
    # the regular wrapping process to handle the mechanics of
    # the wrapping. At the very last unmount the input starkit.

    # 'Using this directory as source' is the same as 'wrap all files
    # under the mounted directory into the new starpack, preserving
    # the whole hierarchy'.

    # The starkit to be converted is only read, not modified. We are
    # mounting it read-only expressing this, and to allow the input to
    # be a non-writable file too.

    set                       mountpoint [file join $starkit::topdir pak]
    vfs::mk4::Mount $starkit $mountpoint -readonly

    #lappend av -verbose

    set     av [list]
    lappend av -nospecials
    lappend av -prefix     $basekit
    lappend av -out        $result
    lappend av -anchor     /
    lappend av -relativeto $mountpoint

    foreach f [fileutil::find $mountpoint] {
	lappend av $f
    }

    # Add all additional options provided by the user
    # This handles special cases.

    foreach o $other {
	lappend av $o
    }

    #puts mountpoint=$mountpoint
    #puts ([join $av ") ("])
    #log::lvSuppress debug 0

    set ok [tclapp::wrap_safe $av]

    vfs::unmount $mountpoint
    return $ok
}

proc ::tclapp::genpak::Validate {spec bvar svar rvar ovar} {

    # Just enough arguments ?

    if {[llength $spec] < 3} {Abort wargs}

    # All arguments truly defined ?

    foreach {basekit starkit result} $spec break

    if {$basekit == {}} {Abort empty}
    if {$starkit == {}} {Abort empty}
    if {$result  == {}} {Abort empty}

    # All three files have to be different from each other.
    # Starkit has to exist, has to be kit, has to be readable.
    # Existence of result file does not matter.
    # Basekit has to exist, has to be kit. Checked later.

    if {$basekit eq $starkit} {Abort eq}
    if {$basekit eq $result}  {Abort eq}
    if {$starkit eq $result}  {Abort eq}

    if {![file exists   $starkit]} {Abort starkit/ex}
    if {![file readable $starkit]} {Abort starkit/read}

    upvar 1 $bvar b ; set b $basekit
    upvar 1 $svar s ; set s $starkit
    upvar 1 $rvar r ; set r $result
    upvar 1 $ovar o ; set o [lrange $spec 3 end]

    return
}

proc ::tclapp::genpak::Abort {code} {
    switch -exact -- $code {
	wargs {
	    set title {Syntax error}
	    set err   "Wrong#args for $::argv0.\nExpected: $::argv0 -genpak|genpak basekit starkit result "
	}
	empty {
	    set title {Empty files names}
	    set err   "$::argv0 -genpak basekit starkit result\nSome arguments are empty strings."
	}
	eq {
	    set title "Argument error"
	    set err   "$::argv0: basekit, starkit, and result have to be three different files."
	}
	starkit/ex {
	    set title "Argument error"
	    set err   "$::argv0: starkit does not exist."
	}
	starkit/read {
	    set title "Argument error"
	    set err   "$::argv0: starkit cannot be read."
	}
	starkit/write {
	    set title "Argument error"
	    set err   "$::argv0: starkit cannot be written to."
	}
	wargsvac {
	    set title {Syntax error}
	    set err   "Wrong#args for $::argv0.\nExpected: $::argv0 -vacuum|vacuum kit "
	}
	emptyvac {
	    set title {Empty files names}
	    set err   "$::argv0 vacuum kit\nSome arguments are empty strings."
	}
	nometakit {
	    set title {no metakit filesystem}
	    set err   "$::argv0 vacuum kit\nThe input file has no metakit filesystem."
	}
	nometakitsplit {
	    set title {no metakit filesystem}
	    set err   "$::argv0 vsplitpak starpack runtime filesystem\nThe input file has no metakit filesystem."
	}
	wargssplit {
	    set title {Syntax error}
	    set err   "Wrong#args for $::argv0.\nExpected: $::argv0 -splitpak|splitpak starpack runtime filesystem"
	}
	emptysplit {
	    set title {Empty files names}
	    set err   "$::argv0 splitpak kit\nSome arguments are empty strings."
	}
	eqsplit {
	    set title "Argument error"
	    set err   "$::argv0: starpack, runtime, and filesystem have to be three different files."
	}
    }
    if {[catch {
	package require Tk
	wm withdraw .
	tk_messageBox -icon error -title $title -type ok -message $err
    }]} {
	::log::log info $title\n$err
    }
    exit 1
}

# ### ### ### ######### ######### #########
##

# vacuum (starkit|starpack)

proc ::tclapp::genpak::vacuum {spec} {
    package require fileutil
    package require Mk4tcl

    ValidateVac $spec kit

    # Extract the kit/pack prefix sitting before the filesystem, copy
    # it to a compacted destination

    set binprefix [fileutil::cat -encoding binary -translation binary $kit]

    # Look for the metakit magic marker and strip it and everything
    # sitting behind it off the file.
    set footer [string range $binprefix end-15 end]

    set off [Xsplit I \x4a\x4c\x1a]
    if {$off < 0} {
	set off [Xsplit i \x4c\x4a\x1a]
	if {$off < 0} {
	    Abort nometakit

	    puts "Unable to locate start of MK"
	    exit 1
	}
    }

    incr off
    set binprefix [string range $binprefix 0 end-$off]

    set t [fileutil::tempfile TclAppSHRINK]
    fileutil::writeFile -encoding binary -translation binary $t $binprefix\x1A

    # Now vacuum the metakit filesystem and attach it to the saved
    # prefix, completing the operation.

    mk::file open  fs $kit   ; set chan [open $t a]
    mk::file save  fs $chan ; close $chan
    mk::file close fs

    # Finalize, by copying the vacuumed result over the input file.

    file copy -force $t $kit
    file delete $t
    return 1
}

proc ::tclapp::genpak::ValidateVac {spec bvar} {

    # Just enough arguments ?

    if {[llength $spec] != 1} {Abort wargsvac}

    # All arguments truly defined ?

    lassign $spec kit

    if {$kit == {}} {Abort empty}

    # Kit has to exist, has to be a kit, has to be readable and
    # writable.

    if {![file exists   $kit]} {Abort starkit/ex}
    if {![file readable $kit]} {Abort starkit/read}
    if {![file writable $kit]} {Abort starkit/write}

    upvar 1 $bvar b ; set b $kit
    return
}

proc ::tclapp::genpak::Xsplit {f tag} {
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

# ### ### ### ######### ######### #########
##

# splitpak (starpack runtime filesystem)

proc ::tclapp::genpak::split {spec} {
    package require fileutil
    package require Mk4tcl

    ValidateSplit $spec pack runtime fs

    # Extract the kit/pack prefix sitting before the filesystem, copy
    # it to a compacted destination

    set binprefix [fileutil::cat -encoding binary -translation binary $pack]

    # Look for the metakit magic marker and strip it and everything
    # sitting behind it off the file.
    set footer [string range $binprefix end-15 end]

    set off [Xsplit I \x4a\x4c\x1a]
    if {$off < 0} {
	set off [Xsplit i \x4c\x4a\x1a]
	if {$off < 0} {
	    Abort nometakitsplit
	}
    }

    fileutil::writeFile -encoding binary -translation binary \
	$runtime [string range $binprefix 0 end-$off]

    incr off -1

    fileutil::writeFile -encoding binary -translation binary \
	$fs [string range $binprefix end-$off end]

    return 1
}

proc ::tclapp::genpak::ValidateSplit {spec pvar rvar fvar} {
    # Just enough arguments ?

    if {[llength $spec] != 3} {Abort wargssplit}

    # All arguments truly defined ?

    lassign $spec pack runtime fs

    if {$pack    == {}} {Abort emptysplit}
    if {$runtime == {}} {Abort emptysplit}
    if {$fs      == {}} {Abort emptysplit}

    # All three files have to be different from each other.

    if {$pack eq $runtime} {Abort eqsplit}
    if {$pack eq $fs}      {Abort eqsplit}
    if {$runtime eq $fs}   {Abort eqsplit}

    # Pack has to exist, has to be a kit, has to be readable.

    if {![file exists   $pack]} {Abort starkit/ex}
    if {![file readable $pack]} {Abort starkit/read}

    upvar 1 $pvar p ; set p $pack
    upvar 1 $rvar r ; set r $runtime
    upvar 1 $fvar f ; set f $fs
    return
}

# ### ### ### ######### ######### #########
## Ready

package provide tclapp::genpak 1.1
