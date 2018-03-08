# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_config.tcl --
# -*- tcl -*-
#
#	Information for and about configurations (TclApp, Wrapper).
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

#
# RCS: @(#) $Id: tclapp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

if {[catch {package require compiler}]} {
    # Compiler package missing, we cannot work.
    exit
}
## package require tcldevkit::appframe ; # already through startup.

package require teapot::reference
package provide tclapp::config 1.0

namespace eval tclapp::config {

    # =============================================================
    # Fundamental information ...
    #
    # Left  -- key for the data in state arrays
    # Right -- Name of command in configuration file.
    #
    # I.   Keys used by the 'TclDevKit Wrapper'
    # II.  Keys used by the 'TclDevKit TclApp'
    # III. Tools to variables

    variable keymap_wrapper {
	args		App/Args
	code		App/Code
	files		Files
	sys,tempdir	System/TempDir
	sys,verbose	System/Verbose
	wrap,compile    Wrap/Compile/Tcl
	wrap,compilefor Wrap/Compile/Version
	wrap,executable	Wrap/BaseExecutable
	wrap,out	Wrap/Output
	wrap,spec	Wrap/Specification
	wrap,tcllib	Wrap/TclLibraryDir
    }

    variable keymap_tclapp {
	app             App/Package
	args		App/Argument
	code		App/Code
	postcode	App/PostCode
	encs            Encoding
	infoplist       OSX/Info.plist
	metadata        Metadata
	paths		Path
	pkg,instances   Pkg/Instance
	pkg,platforms   Pkg/Architecture
	pkg,references  Pkg/Reference
	pkg,repo,urls   Pkg/Archive
	pkgdirs         Pkg/Path
	pkgs            Package
	stringinfo      StringInfo
	sys,tempdir	System/TempDir
	sys,verbose	System/Verbose
	sys,nocompress	System/Nocompress
	wrap,compile    Wrap/Compile/Tcl
	wrap,compilefor Wrap/Compile/Version
	wrap,executable	Wrap/InputPrefix
	wrap,fsmode     Wrap/FSMode
	wrap,icon       Wrap/Icon
	wrap,interp     Wrap/Interpreter
	wrap,merge      Wrap/Merge
	wrap,noprovided Wrap/NoProvided
	wrap,nospecials Wrap/NoSpecials
	wrap,notbcload  Wrap/Compile/NoTbcload
	wrap,out	Wrap/Output
	wrap,out,osx    Wrap/Output/OSXApp
    }

    variable  tool_map
    array set tool_map {
	{TclDevKit TclApp}  keymap_tclapp
	{TclDevKit Wrapper} keymap_wrapper
    }

    # =============================================================
    # Derived information
    # Valid configuration commands/keys ...

    variable keymap_wrapper_valid
    foreach {old new} $keymap_wrapper {set keymap_wrapper_valid($new) .}

    variable keymap_tclapp_valid
    foreach {old new} $keymap_tclapp {set keymap_tclapp_valid($new) .}
}


proc ::tclapp::config::check {tool data} {
    # See 'configuration below' for a description of the valid keys.
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

proc ::tclapp::config::keys {tool} {
    variable  tool_map
    variable $tool_map($tool)_valid
    upvar 0  $tool_map($tool)_valid keymap_valid

    return [array get keymap_valid]
}

proc ::tclapp::config::tools {} {
    variable tool_map
    return [array names tool_map]
}

proc ::tclapp::config::convertWrapperFiles {files optvar} {
    upvar 1 $optvar options

    set fhasrelto 0

    foreach fitem $files {
	foreach {ftype fpattern more} $fitem break ; # lassign
	switch -exact -- $ftype {
	    file - glob {
		lappend options $fpattern
	    }
	    startup {
		lappend options $fpattern
		lappend options -startup $fpattern
	    }
	    directory {set fhasrelto 1}
	}
    }
    if {$fhasrelto} {
	foreach fitem $files {
	    foreach {ftype fdir more} $fitem break ; # lassign
	    if {![string equal directory $ftype]} {continue}

	    lappend options -relativeto $fdir

	    foreach fitem $more {
		foreach {ftype fpattern} $fitem break ; # lassign

		set fporig   $fpattern
		set fpattern [file join $fdir $fpattern]
		switch -exact -- $ftype {
		    file - glob {
			lappend options $fpattern
		    }
		    startup {
			lappend options $fpattern
			lappend options -startup $fporig
		    }
		}
	    }
	}
    }

    # options are implicitly returned
}

proc ::tclapp::config::convertTclAppFiles {ev files defanchor optvar} {
    upvar 1 $ev errors $optvar options
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
		tclapp::fres::anchor=     $anchor
		tclapp::fres::alias=      $lastalias
		tclapp::fres::relativeto= $rel       errors

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
			[lindex [tclapp::fres::resolve $last] end]
		tclapp::fres::reset
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
		lappend options -relativeto [set narg [file normalize $arg]]
		set rel                     $narg
		set alias ""
	    }
	    default {
		lappend errors "Unknown Path subcommand: $cmd"
		return
	    }
	}
    }
    tclapp::fres::reset
    # options are implicitly returned
}

proc ::tclapp::config::ConvertToOptions {ev cfg {tool {TclDevKit TclApp}}} {
    # Process the configuration information.
    # Configuration is in a format as produced by
    # tcldevkit::config::Read/2.0
    # Essence: One entry per unique key.
    #          Data per key is a list for all usage of that key.
    #          Order is not preserved.

    # We convert this into a list of options. ... The conversion
    # is different for Wrapper and TclApp configurations.
    # Note: Neither of these two formats allows sub-configurations

    # We enforce that packages are listed after the normal options,
    # and files specifications are listed last.

    upvar 1 $ev errors

    set options   [list]
    set packages  [list]
    set files     [list]
    set encodings [list]
    set pkgdirs   [list]

    log::log debug "config::ConvertToOptions $tool"
    log::log debug "\t[join $cfg \n\t]"

    if {[string equal $tool {TclDevKit TclApp}]} {
	# TclApp configuration

	set defanchor lib/application
	set paths {}

	foreach {key val} $cfg {
	    set last_val  [lindex $val end]

	    switch -exact -- $key {
		App/PostCode            {
		    if {$last_val != {}} {
			lappend options -postcode $last_val
		    }
		}
		App/Code            {
		    if {$last_val != {}} {
			lappend options -code $last_val
		    }
		}
		App/Argument        {
		    if {$val != {}} {
			lappend options -arguments  $val
		    }
		}
		System/Verbose      {
		    if {$last_val} {
			lappend options -verbose
		    }
		}
		System/Nocompress      {
		    if {$last_val} {
			lappend options -nocompress
		    }
		}
		System/TempDir      {
		    if {$last_val != {}} {
			lappend options -temp [file normalize $last_val]
		    }
		}
		Wrap/InputPrefix {
		    if {$last_val != {}} {
			if {[tclapp::misc::isTeapotPrefix $last_val]} {
			    lappend options -prefix $last_val
			} else {
			    lappend options -prefix [file normalize $last_val]
			}
		    }
		}
		Wrap/Interpreter {
		    if {$last_val != {}} {
			lappend options -interpreter [file normalize $last_val]
		    }
		}
		Wrap/FSMode {
		    if {$last_val != {}} {
			lappend options -fsmode $last_val
		    }
		}
		Wrap/Output         {
		    if {$last_val != {}} {
			lappend options -out [file normalize $last_val]
		    }
		}
		Wrap/Output/OSXApp  {
		    if {$last_val} {
			lappend options -osxapp
		    }
		}
		Wrap/Icon         {
		    if {$last_val != {}} {
			lappend options -icon $last_val
		    }
		}
		Wrap/Compile/Tcl    {
		    if {$last_val} {
			lappend options -compile
		    }
		}
		Wrap/Compile/Version {
		    if {$last_val != {}} {
			lappend options -compilefor $last_val
		    }
		}
		Wrap/Compile/NoTbcload {
		    if {$last_val} {
			lappend options -notbcload
		    }
		}
		App/Package         {
		    if {$last_val != {}} {
			lappend packages -app $last_val
			set defanchor ""
		    }
		}
		Wrap/NoSpecials     {
		    if {$last_val} {
			lappend options -nospecials
		    }
		}
		Wrap/NoProvided     {
		    if {$last_val} {
			lappend options -noprovided
		    }
		}
		Wrap/Merge          {
		    if {$last_val} {
			lappend options -merge
		    }
		}
		Package             {
		    foreach p $val {
			lappend packages -pkg $p
		    }
		}
		Encoding           {
		    foreach p $val {
			lappend encodings -encoding $p
		    }
		}
		Pkg/Path           {
		    foreach p $val {
			lappend pkgdirs -pkgdir $p
		    }
		}
		Path                {
		    set paths $val
		}
		StringInfo            {
		    if {$last_val != {}} {
			lappend options -stringinfo $last_val
		    }
		}
		Metadata            {
		    if {$last_val != {}} {
			lappend options -metadata $last_val
		    }
		}
		OSX/Info.plist       {
		    if {$last_val != {}} {
			lappend options -infoplist $last_val
		    }
		}
		Pkg/Archive {
		    foreach a $val {
			lappend options -archive $a
		    }
		}
		Pkg/Architecture {
		    foreach a $val {
			lappend options -architecture $a
		    }
		}
		Pkg/Instance {
		    foreach i $val {
			lappend options -pkginstance $i
		    }
		}
		Pkg/Reference {
		    foreach a $val {
			lappend packages -pkgref $a
		    }
		}
	    }
	}
	convertTclAppFiles errors $paths $defanchor files
    } else {
	# prowrap configuration
	foreach {key val} $cfg {
	    set last_val  [lindex $val end]

	    switch -exact -- $key {
		App/Code            {
		    if {$last_val != {}} {
			lappend options -code       $last_val
		    }
		}
		App/Args            {
		    # Drill down, this is a one-shot key.
		    if {$last_val != {}} {
			lappend options -arguments  $last_val
		    }
		}
		System/Verbose      {
		    if {$last_val} {
			lappend options -verbose
		    }
		}
		System/TempDir      {
		    if {$last_val != {}} {
			lappend options -temp   [file normalize $last_val]
		    }
		}
		Wrap/BaseExecutable {
		    if {$last_val != {}} {
			lappend options -prefix [file normalize $last_val]
		    }
		}
		Wrap/Output         {
		    if {$last_val != {}} {
			lappend options -out    [file normalize $last_val]
		    }
		}
		Wrap/TclLibraryDir  {# ignore}
		Wrap/Specification  {# ignore}
		Wrap/Compile/Tcl    {
		    if {$last_val} {
			lappend options -compile
		    }
		}
		Files               {
		    # Called only once, have to drill down to get
		    # the correct information.
		    convertWrapperFiles $last_val files
		}
	    }
	}
    }

    if {[llength $pkgdirs] > 0} {
	eval [list lappend options] $pkgdirs
    }
    if {[llength $encodings] > 0} {
	eval [list lappend options] $encodings
    }
    if {[llength $packages] > 0} {
	eval [list lappend options] $packages
    }
    if {[llength $files] > 0} {
	eval [list lappend options] $files
    }
    return $options
}

proc ::tclapp::config::ConvertToArray {arrayvar cfg tool} {
    # Process the configuration information.
    # Convert into an array which can be sync'd with the widgets.

    variable keymap_tclapp
    variable keymap_wrapper
    upvar 1 $arrayvar serial

    # Enforce existence of required fields. The defaults set now will
    # be overwritten during mapIn by any data coming from the outside.

    array set serial {
	args  {} wrap,executable {} sys,verbose 0    wrap,out,osx 0
	code  {} wrap,out        {} sys,tempdir {}   sys,nocompress 0
	paths {} wrap,compile    0  wrap,interp {}
	app   {} wrap,nospecials 0  wrap,notbcload 0 wrap,noprovided 0
	pkgs  {} wrap,merge      0  wrap,fsmode {} postcode {}
	encs  {} pkgdirs         {} wrap,icon {}
	stringinfo {} metadata {} infoplist {}
	pkg,instances   {}	pkg,platforms   {}
	pkg,references  {}	pkg,repo,urls   {}
    }
    array set serial $cfg

    if {[string equal $tool {TclDevKit TclApp}]} {
	# TclApp configuration

	::tcldevkit::appframe::mapIn $keymap_tclapp serial
	set   serial(files) $serial(paths)
	unset serial(paths)
    } else {
	# prowrap configuration
	# We unset the parts TclApp is not interested in.

	unset serial(Wrap/TclLibraryDir)
	unset serial(Wrap/Specification)

	# We have to convert the data of most keys from a list into
	# one element, to match the expectations of the other parts
	# of the system.

	foreach key {
	    App/Args Files System/Verbose System/Nocompress
	    System/TempDir Wrap/BaseExecutable
	    Wrap/Output Wrap/Compile/Tcl
	    Wrap/Compile/NoTbcload
	} {
	    catch {set serial($key) [lindex $serial($key) end]}
	}
	::tcldevkit::appframe::mapIn $keymap_wrapper serial

	# Rewrite the wrapper 'files' serialization into a tclapp
	# 'paths' serialization. Note that the current contents is a
	# list of all calls to 'Files', i.e. a lsit of one element.

	set serial(files) [ConvertWrappertoTclApp $serial(files)]
    }

    # Convert the items which are not multi-line from list-form to
    # single value.

    foreach k {
	wrap,executable sys,verbose sys,nocompress
	wrap,out        sys,tempdir
	wrap,out,osx    wrap,compilefor
	wrap,compile    code
	wrap,notbcload	wrap,noprovided
	wrap,nospecials app
	wrap,merge      wrap,interp
	wrap,fsmode     wrap,icon       postcode
	stringinfo      metadata	infoplist
    } {
	set serial($k) [lindex $serial($k) end]
    }
}

proc ::tclapp::config::mapOut {arrayvar} {
    variable keymap_tclapp
    upvar 1 $arrayvar serial

    ::tcldevkit::appframe::mapOut $keymap_tclapp serial
    return [array get serial]
}

proc ::tclapp::config::ConvertWrappertoTclApp {files} {
    set res [list]
    set fhasrelto 0

    log::log debug "config::ConvertWrappertoTclApp\n\t[join $files \n\t]"

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

proc ::tclapp::config::ConvertOptionsToArray {options} {
    ## FUTURE ## Allow loading of -config files from GUI
    ##
}
