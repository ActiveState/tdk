# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp.tcl --
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

package require cmdline
package require compiler
package require csv
package require fileutil
package require log
package require starkit
package require tcldevkit::config
package require vfs::mk4

package require tclapp::banner
package require tclapp::cmdline
package require tclapp::config
package require tclapp::cursor
package require tclapp::files
package require tclapp::fres
package require tclapp::misc
package require tclapp::msgs
package require tclapp::tmp
package require tclapp::wrapengine

namespace eval tclapp {
    namespace import ::tclapp::msgs::get
    rename                           get mget
}

if 0 {
    # Debug help
    vfs::filesystem internalerror report
    proc report {} {
	puts stderr \n\n%%%%%%%%%%%%%%%%%%\n
	puts stderr $::errorInfo
	puts stderr \n%%%%%%%%%%%%%%%%%%\n\n
	return
    }
}

#
#  --
#
#	Perform one round of wrapping.
#	
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.


proc tclapp::wrap_safe {argv} {
    #log::lvSuppress debug 0
    #[logger::servicecmd repository::union]::setlevel error

    if {[catch {
	wrap $argv errors
    }]} {
	foreach line [split $::errorInfo \n] {
	    log::log critical "INTERNAL ERROR: $line"
	}
	return 0
    } elseif {[llength $errors]} {
	foreach e $errors {
	    log::log error $e
	}
	return 0
    }
    return 1
}

proc tclapp::wrap {argv errVar} {
    upvar 1 $errVar errors
    set             errors {}

    Reset
    tclapp::cmdline::process $argv errors

    if {[misc::printHelp?]} {
	projectInfo::printCopyright "Tcl Dev Kit TclApp"

	if {[string equal $::tcl_platform(platform) windows]} {
	    tk_messageBox -icon info -title "TclApp Help" \
		-type ok -message [mget 0_USAGE_STATEMENT]
	} else {
	    ::log::log info [mget 0_USAGE_STATEMENT]
	}
	return
    }

    if {![llength $errors]} {
	misc::validate errors
    }

    if {![llength $errors]} {
	files::validate errors
    }

    if {![llength $errors]} {
	::cursor::propagate . watch
	tclapp::wrapengine::run errors
	::cursor::restore .
    }

    # Delete the directory used to wrap things.
    catch {tmp::delete}

    return
}

#
# Reset --
#
#	Prepares the engine for another round of wrapping. This enable
#	multiple rounds of wrapping per invokation of the application.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::tclapp::Reset {} {
    misc::reset
    files::reset
    fres::reset
    pkg::reset
    return
}

#
# dumpPWData --
#
#	Debugging helper. Dumps the internal state.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::tclapp::dumpPWdata {} {
}

#
# LoadConfig --
#
#	Loads and processes a configuration file.
#
# Arguments:
#	infile	The path to the file.
#
# Results:
#	None.

proc ::tclapp::LoadConfig {ev infile cfgfilesvar} {
    upvar 1 $ev errors $cfgfilesvar cfgfiles

    # Prevent infinite recursive inclusion of configuration files.

    if {[info exists cfgfiles($infile)]} {
	lappend errors \
		"circular inclusion of configuration file $infile"
	return
    }
    set cfgfiles($infile) .

    # Error messages for saving and loading a configuration.

    set mtitle  "Error while loading configuration file."
    set fmtbase "File format not recognized.\n\nThe chosen file does not contain Tcl Dev Kit Project information."
    set fmttool "The chosen Tcl Dev Kit Project file does not contain information for $::tcldevkit::appframe::appNameFile, but"
    set fmtkey  "Unable to handle the following keys found in the Tcl Dev Kit Project file for"
    set basemsg "Could not load file"

    # Check the chosen file for format conformance.

    foreach {pro tool} [::tcldevkit::config::Peek/2.0 $infile] { break }
    if {!$pro} {
	# Assume that the file contains a list of options and
	# arguments, with at least one word per line. We use the
	# 'csv' module to allow quoting, space is the separator
	# character.

	set options [list]
	set in [open $infile r]
	while {![eof $in]} {
	    if {[gets $in line] < 0} {continue}
	    if {$line == {}} {continue}
	    set line [csv::split $line { }]
	    foreach item $line {lappend options $item}
	}
	close $in
	return $options
    }

    # Check that the application understands the information in the
    # file. To this end we ask the master widget for a list of
    # application names it supports. If this results in an error we
    # assume that only files specifically for this application are
    # understood.

    if {[lsearch -exact [config::tools] $tool] < 0} {
	# Is a project file, but not for this tool.

	lappend errors "$basemsg ${infile}.\n\n$fmttool $tool"
	return
    }

    # The file is tentatively identified as project file for this
    # tool, so read the information in it. If more than one tool is
    # supported by the application we ask its master widget for the
    # list of keys acceptable for the found tool.

    set allowed_keys [config::keys $tool]

    if {[catch {
	set cfg [::tcldevkit::config::Read/2.0 $infile $allowed_keys]
    } msg]} {
	lappend errors "$basemsg ${infile}.\n\n$fmtkey ${tool}:\n\n$msg"
	return
    }

    return [config::ConvertToOptions errors $cfg $tool]
}

# =========================================================

package provide tclapp 1.0
