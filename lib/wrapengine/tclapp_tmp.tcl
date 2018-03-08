# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_tmp.tcl --
# -*- tcl -*-
#
#	Creates, deletes, or retrieves the name of a temporary directory for
#	the utility to use.  The name of the temporary directory is derived
#	from the prefix "TCLAPPTMP" concatenated with the process-id.  This
#	directory will either be created in the directory specified by the
#	variable "temp_directory" or a directory defined by the
#	environment variables: TEMP, TMP, TMPDIR, temp, tmp, tmpdir, Temp,
#	Tmp, Tmpdir.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

#
# RCS: @(#) $Id: tclapp::tmp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

package require fileutil
package require log

package require tclapp::msgs

namespace eval ::tclapp::tmp {}

# ### ### ### ######### ######### #########

#
# ::tclapp::tmp::create --
#
#	Creates the name of a temporary directory for
#	the utility to use. The name of the temporary directory is derived
#	from the prefix "TCLAPPTMP" concatenated with the process-id.  This
#	directory will either be created in the directory specified by the
#	variable "temp_directory" or a directory defined by the
#	environment variables: TEMP, TMP, TMPDIR, temp, tmp, tmpdir, Temp,
#	Tmp, Tmpdir.
#
# Arguments
#	None.
#
# Results
#	Returns the full path of the temporary directory.  If a
#	temporary directory cannot be create or determined, an
#	exception is raised.

proc ::tclapp::tmp::create {} {
    variable tempDir
    variable statePrefix

    log::log debug "tclapp::tmp::create ($tempDir)"

    # Clear the fixed tempdir setting set by a previous wrap run
    ::set ::fileutil::tempdirSet 0
    ::set ::fileutil::tempdir    {}

    # Determine the temporary directory
    ::set tempDir [::fileutil::tempdir]
    ::set appdir  [file join $tempDir ${statePrefix}[pid]]

    if {[catch {file mkdir $appdir} error]} {
	return -code error \
	    "[tclapp::msgs::get 112_UNABLE_TO_CREATE_TEMPDIR]: $error"
    }

    log::log debug "\t$appdir"

    # We set the selected directory as the location for all temp files
    # used by the current process, overriding any other selection the
    # temp. file system of fileutil would have made.

    fileutil::tempdir $appdir
    ::set tempDir     $appdir
    return
}

#
# ::tclapp::tmp::delete --
#
#	Deletes the temporary directory for the utility to use.
#
# Arguments
#	None.
#
# Results
#	Returns	nothing but an exception may be raised if the deletion fails.

proc ::tclapp::tmp::delete {} {
    variable tempDir

    # Clear the fixed tempdir setting set by the wrap run
    ::set ::fileutil::tempdirSet 0
    ::set ::fileutil::tempdir    {}

    if {[catch {file delete -force $tempDir} error]} {
	return -code error \
	    "[tclapp::msgs::get 111_UNABLE_TO_DESTROY_TEMPDIR]: $error"
    }
    return
}

#
# ::tclapp::tmp::set --
#
#	Sets the name of the main temporary directory for the utility to
#	use.
#
# Arguments
#	The path to use.
#
# Results
#	None.

proc ::tclapp::tmp::set {path ev} {
    variable tempDir

    upvar 1 $ev errors

    ::set path [file join [pwd] $path]

    if {![fileutil::test $path edrw msg "Temporary directory"]} {
	lappend errors $msg
	return 0
    }

    ::set tempDir $path
    return 1
}

# ### ### ### ######### ######### #########

namespace eval ::tclapp::tmp {
    namespace export create delete set

    # The directory for temporary files in use. Slightly different
    # values in different phases of the system:
    #
    # - After tmp::set (cmdline processing) the main directory where
    #   the state directory of the process will be placed.
    #
    # - After tmp::create the state directory itself, under which all
    #   temp. files of the process will go.

    variable tempDir ""

    # Prefix used to construct the name of the subdirectory of the
    # temp. directory holding the transient files of this process.

    variable statePrefix TCLAPPTMP
}

# ### ### ### ######### ######### #########
package provide tclapp::tmp 1.0
