# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# procomp_config.tcl --
# -*- tcl -*-
#
#	Information for and about configurations (Compiler).
#
# Copyright (c) 2005-2006 ActiveState Software Inc.

#
# RCS: @(#) $Id: procomp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

if {[catch {package require compiler}]} {
    # Compiler package missing, we cannot work.
    exit
}
## package require tcldevkit::appframe ; # already through startup.
package provide procomp::config 1.0

namespace eval ::procomp::config {

    # =============================================================
    # Fundamental information ...
    #
    # Left  -- key for the data in state arrays
    # Right -- Name of command in configuration file.
    #
    # I.   Keys used by the 'TclDevKit Wrapper'
    # II.  Keys used by the 'TclDevKit Compiler'
    # III. Tools to variables

    # Currently we process only Compiler .tpj files to locate
    # files. In the future we will process .tap files as well.

    if 0 {
	variable keymap_wrapper {
	    {TclDevKit Wrapper} keymap_wrapper
	    code		App/Code
	    args		App/Args
	    files		Files
	    sys,verbose	System/Verbose
	    sys,tempdir	System/TempDir
	    wrap,executable	Wrap/BaseExecutable
	    wrap,out	Wrap/Output
	    wrap,tcllib	Wrap/TclLibraryDir
	    wrap,spec	Wrap/Specification
	    wrap,compile    Wrap/Compile/Tcl
	}
	variable keymap_wrapper_valid
	foreach {old new} $keymap_wrapper {set keymap_wrapper_valid($new) .}
    }

    variable keymap_comp {
	. DestinationDir
	. Files
	. ForceOverwrite
	. Prefix/File
	. Prefix/Mode
    }

    variable  tool_map
    array set tool_map {
	{TclDevKit Compiler} keymap_comp
    }

    # =============================================================
    # Derived information
    # Valid configuration commands/keys ...

    variable keymap_procomp_valid
    foreach {old new} $keymap_comp {set keymap_comp_valid($new) .}
}


proc ::procomp::config::check {tool data} {
    # See 'configuration' below for a description of the valid keys.
    # We get this information from they keymap.

    variable  tool_map
    variable $tool_map($tool)_valid
    upvar  0 $tool_map($tool)_valid keymap_valid

    foreach {key val} $data {
	if {[info exists keymap_valid($key)]} continue
	return -code error "Found illegal key \"$key\" in configuration"
    }
    return
}

proc ::procomp::config::keys {tool} {
    variable  tool_map
    variable $tool_map($tool)_valid
    upvar 0  $tool_map($tool)_valid keymap_valid

    return [array get keymap_valid]
}

proc ::procomp::config::tools {} {
    variable tool_map
    return [array names tool_map]
}


proc ::procomp::config::ConvertToOptions {cfg {tool {TclDevKit Procomp}}} {
    # Process the configuration information.
    # Configuration is in a format as produced by
    # tcldevkit::config::Read/2.0
    # Essence: One entry per unique key.
    #          Data per key is a list for all usage of that key.
    #          Order is not preserved.

    # We convert this into a list of options. ... The conversion
    # is different for the various configuration formats.
    # Note: Neither of these two formats allows sub-configurations

    # We enforce that files are listed after the normal options,
    # i.e. last.

    set options   [list]
    set files     [list]
    set pmode     {}
    set pfile     {}

    log::log debug "config::ConvertToOptions $tool"
    log::log debug "\t[join $cfg \n\t]"

    if {[string equal $tool {TclDevKit Compiler}]} {
	# Compiler configuration

	foreach {key val} $cfg {
	    set last_val  [lindex $val end]

	    switch -exact -- $key {
		DestinationDir {
		    if {$last_val != {}} {
			lappend options -out $last_val
		    }
		}
		ForceOverwrite {
		    if {$last_val} {
			lappend options -force
		    }
		}
		Prefix/File {
		    if {$last_val != {}} {
			set pfile $last_val
		    }
		}
		Prefix/Mode {
		    if {$last_val != {}} {
			set pmode $last_val
		    }
		}
		Files {
		    if {$last_val != {}} {
			foreach p $last_val {
			    lappend files $p
			}
		    }
		}
	    }
	}

	# Prefix handled after the loop, ordering of items while in
	# loop is effectively random.

	if {$pmode ne {}} {
	    if {$pmode eq "file"} {
		lappend options -prefix $pfile
	    } else {
		lappend options -prefix $pmode
	    }
	}

    } else {
	return -code error "Unknown input format"
    }

    if {[llength $files] > 0} {
	eval [list lappend options] $files
    }
    return $options
}

if 0 {

    proc ::procomp::config::convertProcompFiles {files defanchor optvar} {
	upvar 1 $optvar options
	# val = list of (subcommand args) specifications

	# We have to maintain a bit of file resolution context, because
	# 'Startup' is a marker, not a filespec, and we have to resolve
	# the marked file as the CLI expects a 'resolved path' as value of
	# -startup.

	set rel       ""
	set anchor    $defanchor
	set alias     ""
	set last      ""
	set lastalias ""

	foreach item $files {
	    foreach {cmd arg} $item break ; # lassign
	    switch -exact -- $cmd {
		File       {
		    lappend options [set narg [file normalize $arg]]
		    set last        $narg
		    set lastalias   $alias
		    set alias ""
		}
		Startup    {
		    procomp::fres::anchor=     $anchor
		    procomp::fres::alias=      $lastalias
		    procomp::fres::relativeto= $rel

		    ## TODO / FUTURE / NOTE Possible bug:
		    ## Startup set to true glob  pattern. ...
		    ## No expansion performed here, wrapping fails.
		    ## Need expansion here, but have to suppress
		    ## error messages. ... Errors should cause the
		    ## system to use the pattern as is, failing later.

		    # Handle a ~/ through limited glob expansion.
		    if {[string match ~* $last]} {
			set last [glob ~][string range $last 1 end]
		    }
		    lappend options -startup \
			[lindex [procomp::fres::resolve $last] end]
		    procomp::fres::reset
		    set alias ""
		}
		Anchor     {
		    lappend options -anchor $arg
		    set anchor              $arg
		    set alias ""
		}
		Alias      {
		    lappend options -alias $arg
		    set alias              $arg
		}
		Relativeto {
		    lappend options -relativeto [file normalize $arg]
		    set rel                     $arg
		    set alias ""
		}
		default {
		    return -code error "Unknown Path subcommand: $cmd"
		}
	    }
	}
	procomp::fres::reset
	# options are implicitly returned
    }

    proc ::procomp::config::ConvertToArray {arrayvar cfg tool} {
	# Process the configuration information.
	# Convert into an array which can be sync'd with the widgets.

	variable keymap_procomp
	variable keymap_wrapper
	upvar 1 $arrayvar serial

	# Enforce existence of required fields. The defaults set now will
	# be overwritten during mapIn by any data coming from the outside.

	array set serial {
	    args  {} wrap,executable {} sys,verbose 0  
	    code  {} wrap,out        {} sys,tempdir {} 
	    paths {} wrap,compile    0  wrap,interp {}
	    app   {} wrap,nospecials 0  wrap,notbcload 0
	    pkgs  {} wrap,merge      0  wrap,fsmode {}
	    encs  {} pkgdirs         {} wrap,icon {}
	}
	array set serial $cfg

	if {[string equal $tool {TclDevKit Procomp}]} {
	    # Procomp configuration

	    ::tcldevkit::appframe::mapIn $keymap_procomp serial
	    set   serial(files) $serial(paths)
	    unset serial(paths)
	} else {
	    # prowrap configuration
	    # We unset the parts Procomp is not interested in.

	    unset serial(Wrap/TclLibraryDir)
	    unset serial(Wrap/Specification)

	    # We have to convert the data of most keys from a list into
	    # one element, to match the expectations of the other parts
	    # of the system.

	    foreach key {
		App/Args Files System/Verbose
		System/TempDir Wrap/BaseExecutable
		Wrap/Output Wrap/Compile/Tcl
		Wrap/Compile/NoTbcload
	    } {
		catch {set serial($key) [lindex $serial($key) end]}
	    }
	    ::tcldevkit::appframe::mapIn $keymap_wrapper serial

	    # Rewrite the wrapper 'files' serialization into a procomp
	    # 'paths' serialization. Note that the current contents is a
	    # list of all calls to 'Files', i.e. a lsit of one element.

	    set serial(files) [ConvertWrappertoProcomp $serial(files)]
	}

	foreach k {
	    wrap,executable sys,verbose
	    wrap,out        sys,tempdir
	    wrap,compile    code
	    wrap,notbcload
	    wrap,nospecials app
	    wrap,merge      wrap,interp
	    wrap,fsmode     wrap,icon
	} {
	    set serial($k) [lindex $serial($k) end]
	}
    }

    proc ::procomp::config::mapOut {arrayvar} {
	variable keymap_procomp
	upvar 1 $arrayvar serial

	::tcldevkit::appframe::mapOut $keymap_procomp serial
	return [array get serial]
    }

    proc ::procomp::config::ConvertWrappertoProcomp {files} {
	set res [list]
	set fhasrelto 0

	log::log debug "config::ConvertWrappertoProcomp\n\t[join $files \n\t]"

	foreach fitem $files {
	    foreach {ftype fpattern more} $fitem break ; # lassign

	    log::log debug "* $ftype $fpattern ..."

	    switch -exact -- $ftype {
		file - glob {
		    lappend res [list File $fpattern]
		}
		startup {
		    lappend res [list File $fpattern]
		    lappend res Startup
		}
		directory {
		    set fhasrelto 1
		}
	    }
	}

	log::log debug $fhasrelto
	log::log debug \t==[join $res \n\t==]

	if {$fhasrelto} {
	    foreach fitem $files {
		foreach {ftype fdir more} $fitem break ; # lassign
		if {![string equal directory $ftype]} {continue}

		log::log debug "* $ftype $fdir ..."

		lappend res [list Relativeto $fdir]

		foreach fitem $more {
		    foreach {ftype fpattern} $fitem break ; # lassign

		    log::log debug "  - $ftype $fpattern ..."

		    set fporig   $fpattern
		    set fpattern [file join $fdir $fpattern]
		    switch -exact -- $ftype {
			file - glob {
			    lappend res [list File $fpattern]
			}
			startup {
			    lappend res [list File    $fpattern]
			    lappend res Startup
			}
		    }
		}
	    }
	}

	log::log debug \t==[join $res \n\t==]

	return $res
    }

    proc ::procomp::config::ConvertOptionsToArray {options} {
	## FUTURE ## Allow loading of -config files from GUI
	##
    }

}
