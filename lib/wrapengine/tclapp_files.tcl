# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_files.tcl --
# -*- tcl -*-
#
#	Storage of information about the files to wrap.
#	+ Helpers to resolve file names and such.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

#
# RCS: @(#) $Id: tclapp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

package require tclapp::msgs

namespace eval ::tclapp::files {
    namespace export add addPkg list

    # Management of files to wrap.

    # Main data structure is an array ('paths') keyed by destination
    # directory. The paths used as keys are relative, and refer to the
    # directory in the output archive.
    #
    # Per destination directory we keep the following information:
    # - lock mode
    # - list of files in the directory.

    # The lock mode is either 'file' or 'pkg', telling us how this
    # directory was created.
    #
    # --If lock mode is 'pkg' no files may be added to this directory
    #	anymore, neither through other packages, nor through explicit
    #   specification of files. The parent directory can be 'file' or 'pkg'.
    #
    # --For lock mode 'file' the directory can be modified, either
    #   files can be added, or subdirectories, or packages (in
    #   subdirectories). The parent directory has to have lock mode
    #   'file' too.
    #
    # The lock mode is used to check that explicitly specified files
    #  not treat on the turf of packages, and the other way around.

    # The list of files is a key-value list. Key is the name of the files
    # in their directory, value is the absolute path to the file source.

    variable  paths
    array set paths {}

    # A set of package directories inside of the archive which have to
    # be searched when looking for directories.

    variable  pkgdirs
    array set pkgdirs {}

    # Additional per destination file information:
    # a) compile - tri-valued:
    #              not present - take cue from global -compile mode.
    #              present, 1  - Compile of this file is forced.
    #              present, 0  - Compilation of this file is suppressed.

    variable  meta
    array set meta {}
}

#
# Low-level commands for adding/retrieving data to/from the internal data
# structure.
#

#
# Add --
#
#	Add a file known via src path, dst path.
#	
#
# Arguments:
#	src     - path to src file
#	dst     - destination path, includes chosen name
#		  destination directory in path has to exist.
#
# Results:
#	None.

proc ::tclapp::files::Add {src dst} {
    variable paths

    log::log debug "files::Add \{\{$src\} \{$dst\}\}"

    set dstdir  [file dirname $dst]
    set dstfile [file tail    $dst]

    if {![info exists paths($dstdir)]} {
	error "Internal error: Add called for non-existing destination directory"
    }

    foreach {lock files} $paths($dstdir) { break }
    array set tmp $files
    set tmp($dstfile) $src

    set paths($dstdir) [list $lock [array get tmp]]
    return
}

#
# AddDir --
#
#	Add a directory known via dst path, specify and check lock mode.
#	Creates parent directories as required.
#
# Arguments:
#	dst     - destination directory
#
# Results:
#	None.

proc ::tclapp::files::AddDir {ev lock dstdir} {
    upvar 1 $ev errors
    log::log debug "files::AddDir \{$lock \{$dstdir\}\}"

    variable paths

    if {[info exists paths($dstdir)]} {
	# Check lock mode for consistency.
	foreach {currentlock files} $paths($dstdir) { break }

	if {![string equal $lock $currentlock]} {

	    if {[string equal $lock file]} {
		lappend errors \
		    [format [::tclapp::msgs::get 300_LOCK_CONFLICT_FILE] $dstdir ]
		return
	    } else {
		lappend errors \
		    [format [::tclapp::msgs::get 301_LOCK_CONFLICT_PKG] $dstdir]
		return
	    }
	}

	# Nothing to do.
	return
    }

    # Directory does not exist. Before creating it look for an
    # existing parent and check its lock mode against ours, if ours is
    # 'file' (A 'pkg' can be added to everything.) Any missing parent
    # is created with the same lock mode as ourselves.

    set parent [file dirname $dstdir]

    # dstdir == root == . => parent == . == dstdir
    # Use this to stop the recursion.

    if {![string equal $parent $dstdir]} {
	if {[string equal $lock file] && [LockConflict $lock $parent]} {
	    lappend errors \
		[format [::tclapp::msgs::get 300_LOCK_CONFLICT_FILE] $parent]
	    return
	}

	if {![info exists paths($parent)]} {
	    # Parent ... Always a file directory, even if we are a package.
	    AddDir errors file $parent
	}
    }

    # Update data structures.
    set paths($dstdir) [list $lock {}]
    return
}

proc ::tclapp::files::LockConflict {lock dir} {
    #log::log debug "\tfiles::LockConflict \{$lock \{$dir\}\}"

    # No conflict if we reach root.
    if {$dir == {}} {return 0}
    if {[string equal $dir .]} {return 0}

    # Skip over non-existing parent
    if {![info exists paths($dir)]} {
	return [LockConflict $lock [file dirname $dir]]
    }

    # Check lock mode for consistency.
    set currentlock [lindex $paths($dir) 0]
    
    if {![string equal $lock $currentlock]} {
	return 1
    }

    return 0
}

#
# MetaAdd --
#
#	Add meta information to the file.
#	
#
# Arguments:
#	dst     - destination path
#       key     - name of meta information
#       val     - value of meta information
#
# Results:
#	None.

proc ::tclapp::files::MetaAdd {dst key val} {
    variable meta

    log::log debug "files::MetaAdd \{\{$dst\} $key = $val\}"

    lappend meta($dst) $key $val
    return
}

#
# Exported commands to add files and packages.
#

#
# add --
#
#	Add a file known via src path, dst path.
#	Creates 'file' directories as required.
#
# Arguments:
#	src     - path to src file
#	dst     - destination path
#
# Results:
#	None.

proc ::tclapp::files::add {ev src dst {compile -1}} {
    upvar 1 $ev errors

    AddDir errors file [file dirname $dst]
    Add    $src $dst

    if {$compile != -1} {
	# No ./, when queried there is no such on front of the path either.
	# This disabled the -nocompilefile option.
	MetaAdd $dst compile $compile
    }
    return
}

#
# addPkg --
#
#	Add a package.
#	Creates 'pkg' directories as required.
#
# Arguments:
#	name	- Name of package
#	files	- list of files in package (src + dst relative to pkgdir)
#
# Results:
#	None.

proc ::tclapp::files::addPkg {ev name files} {
    upvar 1 $ev errors

    log::log debug "Add Package $name"

    set pkgdir [file join lib $name]
    AddDir errors pkg $pkgdir

    set directories [list]
    foreach {src dst} $files {
	set dstpath [file join $pkgdir $dst]
	lappend directories [file dirname $dstpath]
    }
    foreach dir [lsort -uniq $directories] {
	AddDir errors pkg $dir
    }

    foreach {src dst} $files {
	log::log debug "\t$src \t---> $dst"

	set dstpath [file join $pkgdir $dst]
	Add    $src $dstpath
	MetaAdd     $dstpath no-compile 1
    }
    return
}

#
# listFiles --
#
#	Return the stored information as key-value list.
#	key is destination directory. value is key-value
#	list of files in that directory. key is destination
#	name, value is src path.
#
# Arguments:
#	None.
#
# Results:
#	S.a.

proc ::tclapp::files::listFiles {} {
    variable paths

    set res [list]
    foreach dstdir [lsort [array names paths]] {
	lappend res $dstdir [lindex $paths($dstdir) 1]
    }
    return $res
}

#
# metaGet --
#
#	Return meta information for specific destination file.
#
# Arguments:
#	path	Destination path
#
# Results:
#	A key value list containing the meta information.

proc ::tclapp::files::metaGet {path} {
    variable meta

    if {![info exists meta($path)]} {return {}}
    array set tmp $meta($path)
    return [array get tmp]
}

#
# exist --
#
#	Check that the specified destination file exists
#
# Arguments:
#	path
#
# Results:
#	Boolean result. True if the file exists.

proc ::tclapp::files::exist {path} {
    variable paths

    set dir [file dirname $path]
    if {![info exists paths($dir)]} {return 0}

    array set f [lindex $paths($dir) 1]
    return [info exists f([file tail $path])]
}

#
# ::tclapp::files::reset --
#
#	Reset the state
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::tclapp::files::reset {} {
    variable paths
    variable pkgdirs
    foreach p [array names paths]   {unset paths($p)}
    foreach p [array names pkgdirs] {unset pkgdirs($p)}
    return
}


#
# ::tclapp::files::addPkgdir --
#
#	Add additional package directory.
#
# Arguments:
#	path.
#
# Results:
#	None.

proc ::tclapp::files::addPkgdir {path} {
    variable pkgdirs
    set      pkgdirs($path) .
    return
}

#
# ::tclapp::files::pkgdirs --
#
#	Return list containing the additional package directories
#
# Arguments:
#	None
#
# Results:
#	List of paths.

proc ::tclapp::files::pkgdirs {} {
    variable            pkgdirs
    return [array names pkgdirs]
}

#
# ::tclapp::files::validate --
#
#	Check that the additional package directories
#	are actually present in the archive-to-be.
#
# Arguments:
#	None.
#
# Results:
#	None.
#
# Sideeffects:
#	Compiles a list of errors.

proc ::tclapp::files::validate {ev} {
    upvar 1 $ev errors
    variable pkgdirs
    variable paths

    foreach p [array names pkgdirs] {
	if {![info exists paths($p)]} {
	    lappend errors \
		[format [::tclapp::msgs::get 106_PKGDIR_MISSING] $p]
	}
    }
    return
}

#
# ### ### ### ######### ######### #########

package provide tclapp::files 1.0
