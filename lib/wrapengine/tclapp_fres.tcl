# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_fres.tcl --
# -*- tcl -*-
#
#	The 'engine' for the "Tcl Dev Kit Wrapper Utility" - tclapp
#	This file is for usage in TDK 3.0 or higher, and creates Starkits and Starpacks.
#	Because of this it requires an 8.4 interpreter to run on, and will generate
#	8.4 dependent wrapped applications.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

#
# RCS: @(#) $Id: tclapp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

package require vfs::mk4
package require log
package require fileutil

package require tclapp::msgs
package provide tclapp::fres 1.0

namespace eval ::tclapp::fres {
    namespace export relativeto= anchor= alias= compile= resolve

    # Context information used by the command line processor to guide file resolution

    # Current -relativeto setting. This is a path,
    # or the empty string. The latter indicates [pwd] as relativeto
    # context, but _only_ for relative file specs. In contrast to
    # a non-empty relativeto-context absolute paths outside of
    # [pwd] can be used. A standard relativeto context will throw
    # an error for absolute paths outside of its directory.

    variable relativeto    ""
    variable relativeToAbs [pwd]

    # Current anchor. The anchor is always relative to the root of
    # the wrapped file.
    variable anchor "lib/application"

    # Current alias path. This is always a relative path.
    variable alias ""

    # Current per-file compilation flag. Values
    #  1 - compile this file
    #  0 - do not compile this file
    # -1 - Compile or not depending on the global compile flag.
    #
    # Default is -1

    # Can be set, then the next set of files is (not) compiled, even
    # if -compile is (not) set in general. This allows the exclusion /
    # inclusion of specific files from / into compilation. Like
    # 'boot.tcl', for example.

    variable compile -1
}

#
# ::tclapp::fres::relativeto= --
#
#	Set new relativeto context
#	
#
# Arguments:
#	path	- Path for -relativeto stripping.
#
# Results:
#	None.

proc ::tclapp::fres::relativeto= {path ev} {
    variable relativeto
    variable relativeToAbs
    upvar 1 $ev errors

    if {$path != {}} {
	if {![file isdirectory $path]} {
	    lappend errors [format \
		[::tclapp::msgs::get 100_RELATIVE_DOES_NOT_EXIST] \
		$path]
	    return
	}
	# On windows you can pass in a native pathname with \ from the
	# command line - here we map those to / so we can string match

	regsub -all {\\} $path / path
    }

    set relativeto [FixTilde $path]
    if {$relativeto == {}} {
	set relativeToAbs [pwd]
    } else {
	set relativeToAbs [EnforceAbsolute $relativeto]
    }

    log::log debug "    relativeto $path"
    log::log debug "    relativeto $relativeto"
    log::log debug "               $relativeToAbs"
    return
}

proc ::tclapp::fres::FixTilde {path} {
    if {[lindex [file split $path] 0] ne "~"} { return $path }
    return [eval [linsert [lrange [file split $path] 1 end] 0 file join [file nativename ~]]]
}

#
# ::tclapp::fres::anchor= --
#
#	Set new anchor context
#	
#
# Arguments:
#	path	- Path to destination anchor
#
# Results:
#	None.

proc ::tclapp::fres::anchor= {path} {
    variable anchor
    set      anchor [EnforceRelative $path]
    return
}

#
# ::tclapp::fres::anchor --
#
#	Retrieve anchor context
#	
#
# Arguments:
#	None.
#
# Results:
#	Anchor path

proc ::tclapp::fres::anchor {} {
    variable anchor
    return  $anchor
}

#
# ::tclapp::fres::alias= --
#
#	Set new alias context.
#	
#
# Arguments:
#	path	- Path for -alias
#
# Results:
#	None.

proc ::tclapp::fres::alias= {path} {
    variable alias
    set      alias [EnforceRelative $path]
    return
}

#
# ::tclapp::fres::compile= --
#
#	Set new no-compile context.
#	
#
# Arguments:
#	noc	- Boolean.
#
# Results:
#	None.

proc ::tclapp::fres::compile= {flag} {
    variable compile
    set      compile $flag
    return
}

proc ::tclapp::fres::compile {} {
    variable compile
    return  $compile
}

#
# ::tclapp::fres::unalias --
#
#	Deactivate aliasing.
#	
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::tclapp::fres::unalias {} {
    variable alias ""
    return
}

#
# ::tclapp::fres::matchResolve --
#
#	Resolve a source path. In other words, convert it
#	into a path into the wrapped archive. The path may
#	contain wild-card patterns (on windows). If so they
#	are expanded as part of the resolution process (on windows).
#	
#
# Arguments:
#	srcPattern	- Path pattern to resolve
#
# Results:
#	A list containing the source and resolved paths.
#	An empty list indicates that the pattern is a directory
#	and therefore has to be skipped.

proc ::tclapp::fres::matchResolve {srcPattern ev} {
    variable relativeto
    variable relativeToAbs
    variable anchor
    variable alias
    upvar 1 $ev errors

    log::log debug "fres::matchResolve $srcPattern"

    # 1. Determine relative path of the src.
    # 2. Make it relative to the anchor.
    # 3. Replace file name with the alias, if defined.

    # Ad 1.

    # On windows you can pass in a native pathname with \ from the
    # command line - here we map those to / so we can string match

    regsub -all {\\} $srcPattern / srcPattern
    set srcPattern [FixTilde $srcPattern]

    log::log debug "        normalized $srcPattern"

    # The leading portion of the given file spec. may not
    # contain the -relativeto directory currently being
    # processed. Emit an error.
    #
    # Note: We can skip this check for -relativeto == "".
    #   as this is always true.
    #
    # Note II: It is important that we use the unresolved relativeto
    #   context (relative, _not_ relativeToAbs) for the check as it
    #   this which ensures that absolute paths are accepted for the
    #   empty context.

    if {$relativeto != {}} {
	if {[string first $relativeto $srcPattern] != 0} {
	    log::log debug "                   relativeto mismatch |$relativeto"
	    log::log debug "                   relativeto mismatch |$srcPattern"

	    lappend errors [format \
		[::tclapp::msgs::get 105_RELATIVETO_MISMATCH] \
		$relativeto $srcPattern]
	    return
	}
    }

    # Now we can enforce an absolute path for the specification.
    set srcPattern [EnforceAbsolute $srcPattern]

    log::log debug "          absolute $srcPattern"

    if {[file isdirectory $srcPattern]} {
	# Don't bother wrapping directory elements that appear on
	# the command line.  Directories that exist within file
	# path specifications will be created elsewhere.

	log::log debug "                   stop on directory"
	return {}
    }

    # Resolve the file spec. which may include a glob spec.
    set dstpaths [GetFiles [list $srcPattern] 1]

    if {[llength $dstpaths] < 1} {
	# The given file spec. resolved to no files in the
	# file-system.  Emit an error.

	log::log debug "                   no matching files"

	lappend errors [format \
	    [::tclapp::msgs::get 101_NO_MATCHING_FILES] \
	    $srcPattern]
	return
    }

    # Ad 1., 2., 3.

    set res [list]
    foreach dst $dstpaths {
	foreach {src dst} [resolve $dst] { break }
	lappend res $src $dst
    }
    log::log debug "                   + [llength $res]"
    log::log debug "  * ---------------------"
    return $res
}

#
# ::tclapp::fres::EnforceRelative --
#
#	Ensure that the path is relative.
#
# Arguments:
#	path	- Path, possibly absolute.
#
# Results:
#	The path, unchanged if relative, made absolute else.

proc ::tclapp::fres::EnforceRelative {path} {
    if {[string equal [file pathtype $path] absolute]} {
	set path [lrange [file split $path] 1 end]
	if {[llength $path] > 0} {
	    set path [eval file join $path]
	}
    }
    return $path
}

#
# ::tclapp::fres::EnforceAbsolute --
#
#	Ensure that the path is Absolute.
#
# Arguments:
#	path	- Path, possibly absolute.
#
# Results:
#	The path, unchanged if Absolute, made absolute else.

proc ::tclapp::fres::EnforceAbsolute {path} {
    return [file join [pwd] $path]
}

#
# ::tclapp::fres::GetFiles --
#
#	Given a list of file arguments from the command line, compute
#	the set of valid files.  On windows, file globbing is performed
#	on each argument.  On Unix, only file existence is tested.  If
#	a file argument produces no valid files, a warning is optionally
#	generated.
#
#	This code also uses the full path for each file.  If not
#	given it prepends [pwd] to the filename.  This ensures that
#	these files will never comflict with files in our zip file.
#
# Arguments:
#	patterns	The file patterns specified by the user.
#	quiet		If this flag is set, no warnings will be generated.
#
# Results:
#	Returns the list of files that match the input patterns.

proc ::tclapp::fres::GetFiles {patterns quiet} {
    log::log debug "fres::GetFiles $quiet \{$patterns\}"

    set result {}
    if {1} {
	# Always expand a glob pattern.
	# $::tcl_platform(platform) == "windows"
	foreach pattern $patterns {
	    regsub -all {\\} $pattern {\\\\} pat
	    set files [glob -nocomplain -- $pat]
	    if {$files == {}} {
		if {! $quiet} {
		    ::log::log warning "no files match \"$pattern\""
		}
	    } else {
		foreach file $files {
		    lappend result $file
		}
	    }
	}
    } else {
	set result $patterns
    }
    set files {}
    foreach file $result {
	# Make file an absolute path so that we will never conflict
	# with files that might be contained in our zip file.

	set fullPath [EnforceAbsolute $file]
	
	if {[file isfile $fullPath]} {
	    lappend files $fullPath
	} elseif {! $quiet} {
	    ::log::log warning "no files match \"$file\""
	}
    }
    return $files
}

#
# ::tclapp::fres::reset --
#
#	Reset the state
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::tclapp::fres::reset {} {
    variable relativeto
    variable anchor
    variable alias

    set relativeto ""
    set anchor     "lib/application"
    set alias      ""
    return
}


proc ::tclapp::fres::resolve {src} {
    variable relativeto
    variable relativeToAbs
    variable anchor
    variable alias

    # Remember alias for processing and auto-invalidate to prevent
    # contamination of next pattern. Easier to perform this here
    # than just before every return.

    set thealias $alias
    unalias

    log::log debug "    alias      $thealias"
    log::log debug "    relativeto $relativeto"
    log::log debug "               $relativeToAbs"
    log::log debug "    anchor     $anchor"

    # 1
    # Create a version of the file name that does not contain the
    # "relative to" part of the path.
    #
    # Note: 'stripPath' may return an unchanged path if the path is
    # absolute and there is no preceding -relativeto context (== empty
    # context). So we enforce the relative path.

    set dst $src

    log::log debug "  * ---------------------"
    log::log debug "  * src        $dst"

    set dst [fileutil::stripPath $relativeToAbs $dst]
    log::log debug "  * rel/dst    $dst"

    set dst [EnforceRelative $dst]
    log::log debug "  * rel/dst/f  $dst"

    regsub ^/ $anchor {} anchor
    if {$anchor ne ""} {
	set dst [file join $anchor $dst]
    }
    log::log debug "  * anchored   $dst"

    if {$thealias != {}} {
	set dst [file join [file dirname $dst] $thealias]
    }
    log::log debug "  * aliased    $dst"
    return [list $src $dst]
}
