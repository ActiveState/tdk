# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# cmdline.tcl --
#
#	Command line processor for wrapping. Frontend to the
#	actual engine. Used by the GUI parts as well.
#
# Copyright (c) 2006-2010 ActiveState Software Inc.
#
# RCS: @(#) $Id: tclapp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

package require cmdline
package require platform
package require pref::devkit
package require repository::cache ; # General object cache of repositories
package require struct::stack
package require teapot::config
package require teapot::instance  ; # Instance handling
package require teapot::reference ; # Reference handling
package require teapot::entity    ; # Handling entity types

package require tclapp::banner
package require tclapp::files
package require tclapp::fres
package require tclapp::misc
package require tclapp::msgs
package require tclapp::pkg
package require tclapp::tmp

namespace eval ::tclapp::cmdline {
    namespace import ::tclapp::msgs::get
    rename                           get mget
}

# ### ### ### ######### ######### #########

proc ::tclapp::cmdline::process {argv ev} {
    upvar 1 $ev errors

    ::log::log debug "tclapp::cmdline::process [list $argv]"

    # Force behaviour of "-help" if the command line is empty.

    if {![llength $argv]} {
	tclapp::misc::printHelp
	return
    }

    set notbcload    0
    set archpatterns {}
    set archives     {}
    set files        {}
    set instances    {}
    set references   {}

    ConfigAndPriority $argv errors notbcload \
	Basic         errors notbcload \
	Files         errors \
	Architectures errors          architectures archpatterns \
	Archives      errors archives architectures archpatterns \
	Packages      errors files instances references \
	Expansion     errors files instances references archives archpatterns \
	Closure

    if {[llength $errors]} {
	lappend errors " "
	lappend errors Aborting
	lappend errors " "
    }
    return
}

#
# ### ### ### ######### ######### #########

proc ::tclapp::cmdline::ConfigAndPriority {argv ev tv args} {
    variable switches
    variable argSwitch
    upvar 1 $ev errors $tv notbcload

    ::log::log debug "PASS 1 (Config file expansion, priority) __"
    ::log::log debug [list $argv]

    # This pass 
    # - expands configuration files
    # - handles for high-priority options
    #   (help, debug, nolog, temp directory)
    # - catches and reports all unknown options.

    set unprocessed {}
    array set cfg   {}

    while {[llength $argv]} {
	set err [cmdline::getopt argv $switches opt arg]

	log::log debug "[format %2d $err] ($opt) - ($arg)"

	# -1 - bad option
	#  1 - good option
	#  0 - non-option argument is at the front.

	if {$err < 0} {
	    # Unknown option. We record it, but do not stop
	    # processing. We might find more. The variable opt
	    # contains the error message. We extend it with
	    # a reference to the -help option.

       	    lappend errors "$opt [mget 0_USE_HELP_FOR_MORE_INFO]"
	    break

	} elseif {$err == 0} {
	    # Non-option arguments are ignored by this pass.

	    set opt [lindex $argv 0]

	    log::log debug "    Defered: <$opt>"

	    lappend unprocessed $opt
	    set argv [lrange $argv 1 end]
	} else {
	    # Regular options. Handle the options of this pass ...

	    switch -exact -- $opt {
		? - h - help {
		    tclapp::misc::printHelp
		    set unprocessed {}
		    return
		}
		nocompress {
		    tclapp::misc::nocompress
		}
		l - log {
		    if {![tclapp::misc::logfile $arg errors]} break
		}
		debug        {
		    tclapp::misc::debug
		    log::lvSuppress debug 0
		    logger::setlevel debug
		}
		v - verbose {
		    tclapp::misc::verbose
		}
		t - temp {
		    if {![tclapp::tmp::set $arg errors]} break
		}
	    	n - nologo {
		    tclapp::banner::no
		}
		notbcload {
		    set notbcload 1
		}
		config {
		    set configfile [file join [pwd] $arg]

		    if {![fileutil::test $configfile efr msg \
			      [format [mget 600_CONFIG_FILE] $configfile]]} {
			lappend errors $msg
			break
		    }

		    set newoptions [LoadConfig errors $configfile cfg]

		    ::log::log debug "Loading $arg"
		    ::log::log debug "\t$newoptions"

		    # This code insert several special options to
		    # control processing of configuration files here
		    # and in later stages:

		    # In stage Files.
		    #
		    # -%save    : Save the current anchor value.
		    # -%restore : Restore anchor value from stack
		    #
		    # This ensures that changes to the anchor in a
		    # configuration file are restricted to that file.

		    # In this stage.
		    #
		    # -%% : Remove the file from the database of files
		    #       currently being processed.
		    #
		    # This handles the recursion check properly,
		    # closing the file scope.

		    set argv [concat \
				  [list -%save] \
				  $newoptions \
				  [list -%% $configfile -%restore] \
				  $argv]
		}
		%% {
		    # Pop file context used for recursion check.
		    unset cfg($arg)
		}
		app {
		    # Usage of -app changes the anchor default. Handle
		    # this immediately, but otherwise consider the
		    # option as unprocessed.

		    log::log debug "    Change anchor default"
		    log::log debug "    Defered: -$opt"

		    tclapp::fres::anchor= ""
		    lappend unprocessed -$opt $arg
		}
		default {
		    log::log debug "    Defered: -$opt"

		    lappend unprocessed -$opt
		    if {$argSwitch($opt)} {
			lappend unprocessed $arg
		    }
		}
	    }
	}
	# while ...
    }

    tclapp::banner::print

    # Create the temporary directory; this would either be in the
    # default location, or a path specified via the option "-t?emp?".
    # It is the responsbility of the caller to remove the directory
    # (if it was actually created by the application).

    # We create it this early to be able to use it for package files
    # and other scratch stuff.

    if {[catch {tclapp::tmp::create} error]} {
	lappend errors $error
	return
    }

    # Errors in this pass imply that the other passes have nothing to
    # do anymore.

    if {[llength $errors]} return

    # Chain call the next pass, except if there is nothing to process.
    #if {![llength $unprocessed]} return

    log::log debug "Chain: [linsert $args 1 $unprocessed]"

    uplevel 1 [linsert $args 1 $unprocessed]
    return
}

#
# ### ### ### ######### ######### #########

proc ::tclapp::cmdline::Basic {argv ev tv args} {
    variable switches
    variable argSwitch
    upvar 1 $ev errors $tv notbcload

    ::log::log debug "PASS 2 (Basic options)_____________________"
    ::log::log debug [list $argv]

    # This pass
    # - extracts the majority of the standard information.
    # It defers only file and package processing.

    set unprocessed {}
    set encodings   {}

    while {[llength $argv]} {
	set err [cmdline::getopt argv $switches opt arg]

	log::log debug "[format %2d $err] ($opt) - ($arg)"

	# -1 - bad option  : assert (Cannot happen)
	#  1 - good option
	#  0 - non-option argument is at the front.

	if {$err < 0} {
	    # Unknown option. This should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"$opt (Should have been caught by previous pass)"
	} elseif {$err == 0} {
	    # Non-option arguments are ignored by this pass.

	    set opt [lindex $argv 0]
	    log::log debug "    Defered: <$opt>"

	    lappend unprocessed $opt
	    set argv [lrange $argv 1 end]
	} else {
	    # Regular options. Handle the options of this pass ...

	    # Use of the option -compile and -compilefile imply the
	    # need for the package tbcload. It is added automatically,
	    # except if the user overrode that via -notbcload.

	    switch -exact -- $opt {
	    	e - executable - prefix {if {![tclapp::misc::prefix      $arg errors]} break}
		i - interpreter         {if {![tclapp::misc::interpreter $arg errors]} break}
		o - out                 {tclapp::misc::output $arg}
		osxapp                  {tclapp::misc::osxapp 1}
		nospecials              {tclapp::misc::nospecials}
		noprovided              {tclapp::misc::providedp 0}
		compile                 {
		    tclapp::misc::compile
		    if {!$notbcload} {
			lappend unprocessed -pkg tbcload
		    }
		}
		compilefor {
		    tclapp::misc::compileForTcl $arg
		}
		compilefile {
		    if {!$notbcload} {
			lappend unprocessed -pkg tbcload
		    }

		    # Keep this option as unprocessed for the upcoming
		    # stage actually processing the file information.

		    lappend unprocessed -compilefile
		}
		icon                    {tclapp::misc::icon         $arg}
		stringinfo              {tclapp::misc::stringinfo   $arg}
		metadata                {tclapp::misc::metadata     $arg}
		infoplist               {tclapp::misc::iplist       $arg}
		fsmode                  {if {![tclapp::misc::fsmode $arg errors]} break}
		c - code                {tclapp::misc::code         $arg}
		postcode                {tclapp::misc::postcode     $arg}
		a - arguments           {tclapp::misc::args         $arg}
		merge                   {if {![tclapp::misc::merge errors]} break}
		encoding {
		    HandleEncoding $arg encodings errors
		}
		pkgdir {
		    # Just collect the additional package directories into the system state.
		    tclapp::files::addPkgdir $arg
		}

		default {
		    log::log debug "    Defered: -$opt"

		    lappend unprocessed -$opt
		    if {$argSwitch($opt)} {
			lappend unprocessed $arg
		    }
		}
	    }
	}
    }

    tclapp::misc::output/validate errors
    tclapp::misc::prefix/validate errors

    if {![llength $errors]} {
	RegisterEncodings $encodings errors
    }

    # Errors in this pass imply that the other passes have nothing to
    # do anymore.

    if {[llength $errors]} return

    # Chain call the next pass, except if there is nothing to process.
    #if {![llength $unprocessed]} return

    log::log debug "Chain: [linsert $args 1 $unprocessed]"

    uplevel 1 [linsert $args 1 $unprocessed]
    return
}

#
# ### ### ### ######### ######### #########

proc ::tclapp::cmdline::Files {argv ev args} {
    variable switches
    variable argSwitch
    upvar 1 $ev errors

    ::log::log debug "PASS 3 (File resolution)___________________"
    ::log::log debug [list $argv]

    # This pass catches all non-option arguments, i.e. file patterns,
    # and all the related options influencing their expansion and
    # resolution.

    # The anchor stack below is controlled by the options -%save and
    # -%restore. They were inserted into the command line by the first
    # stage, expanding configuration files, to ensure that -anchor
    # changes in a file stay in the scope of that file.

    set unprocessed {}
    set anchors     [struct::stack]

    while {[llength $argv]} {
	set err [cmdline::getopt argv $switches opt arg]

	log::log debug "[format %2d $err] ($opt) - ($arg)"

	# -1 - bad option  : assert (Cannot happen)
	#  1 - good option
	#  0 - non-option argument is at the front.

	if {$err < 0} {
	    # Unknown option. This should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"$opt (Should have been caught by previous pass)"
	} elseif {$err == 0} {
	    # Non-option arguments are file patterns. Resolve each
	    # under the current context, then record the mapping in
	    # our database.

	    set pattern [lindex $argv 0]
	    set argv    [lrange $argv 1 end]

	    ::log::log debug "Pattern <$pattern>"

	    set dstFiles [tclapp::fres::matchResolve $pattern errors]

	    # Handle only non-directories.
	    if {[llength $dstFiles]} {
		tclapp::misc::startup [lindex $dstFiles 1] 0 errors

		foreach {src dst} $dstFiles {
		    tclapp::files::add errors $src $dst [tclapp::fres::compile]
		}
	    }

	    # Reset the per-file (pattern) flags of the resolution
	    # context to their defaults for the next pattern.

	    tclapp::fres::unalias
	    tclapp::fres::compile= -1

	} else {
	    # Regular options. Handle the options of this pass ...

	    tclapp::fres::unalias

	    switch -exact -- $opt {
	    	r - relativeto {tclapp::fres::relativeto= $arg errors}
		alias          {tclapp::fres::alias=      $arg}
		anchor         {tclapp::fres::anchor=     $arg}
		nocompilefile  {tclapp::fres::compile= 0}
		compilefile    {tclapp::fres::compile= 1}
	    	s - startup    {tclapp::misc::startup $arg 1 errors}

		%save {
		    $anchors push [tclapp::fres::anchor]
		}
		%restore {
		    tclapp::fres::anchor= [$anchors pop]
		}

		default {
		    log::log debug "    Defered: -$opt"

		    lappend unprocessed -$opt
		    if {$argSwitch($opt)} {
			lappend unprocessed $arg
		    }
		}
	    }
	}
    }

    $anchors destroy

    # Errors in this pass imply that the other passes have nothing to
    # do anymore.

    if {[llength $errors]} return

    # Chain call the next pass, except if there is nothing to process.
    #if {![llength $unprocessed] && ![tclapp::misc::prefixIsTeapotPrefix]} return

    log::log debug "Chain: [linsert $args 1 $unprocessed]"

    uplevel 1 [linsert $args 1 $unprocessed]
    return
}

#
# ### ### ### ######### ######### #########

proc ::tclapp::cmdline::Architectures {argv ev arv av args} {
    variable switches
    variable argSwitch
    upvar 1 $ev errors $arv architectures $av archpatterns

    ::log::log debug "PASS 4 (Architectures)_____________________"
    ::log::log debug [list $argv]

    # This pass catches architecture information. For package
    # expansion, etc.

    set unprocessed   {}
    set architectures {}

    while {[llength $argv]} {
	set err [cmdline::getopt argv $switches opt arg]

	log::log debug "[format %2d $err] ($opt) - ($arg)"

	# -1 - bad option  : assert (Cannot happen)
	#  0 - non-option  : assert (Cannot happen)
	#  1 - good option

	if {$err < 0} {
	    # Unknown option. This should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"$opt (Should have been caught by previous pass)"
	} elseif {$err == 0} {

	    # Non-option arguments should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"File pattern should have been caught by previous pass"
	} else {
	    # Regular options. Handle the options of this pass ...

	    switch -exact -- $opt {
		architecture {
		    lappend architectures $arg
		}
		default {
		    log::log debug "    Defered: -$opt"

		    lappend unprocessed -$opt
		    if {$argSwitch($opt)} {
			lappend unprocessed $arg
		    }
		}
	    }
	}
    }

    # Errors in this pass imply that the other passes have nothing to
    # do anymore.

    if {[llength $errors]} return

    if {![tclapp::misc::prefixIsTeapotPrefix]} {
	# We do the full architecture expansion now if and only if the
	# prefix is not a teapot-reference. If it is then this
	# operation is defered to pass 5, Archive handling.
	ComputeArch architectures archpatterns
	# Force initialization of data in pkg mgmt, in case this
	# is the last pass.
	::tclapp::pkg::setArchitectures $archpatterns
    }

    # Chain call the next pass, except if there is nothing to process.
    #if {![llength $unprocessed] && ![tclapp::misc::prefixIsTeapotPrefix]} return

    log::log debug "Chain: [linsert $args 1 $unprocessed]"

    uplevel 1 [linsert $args 1 $unprocessed]
    return
}

proc ::tclapp::cmdline::ComputeArch {av apv} {
    upvar 1 $av architectures $apv archpatterns

    # If no architectures were explicitly specified go through the
    # defaults. First the information from a prefix file (or output,
    # in case of merging), if there is any. Then settings based on
    # TclApps platform.

    if {![llength $architectures]} {
	if {[tclapp::misc::merge?]} {
	    set output [tclapp::misc::output?]
	    ::log::log debug "ComputeArch output = $output"

	    if {$output ne ""} {
		set r [repository::cache get repository::prefix $output]
		set a [$r architecture]
		::log::log debug "       Arch = $a"

		lappend architectures $a
	    }

	} else {
	    set prefix [tclapp::misc::prefix?]
	    ::log::log debug "ComputeArch prefix = $prefix"

	    if {$prefix ne ""} {
		set r [repository::cache get repository::prefix $prefix]
		set a [$r architecture]
		::log::log debug "       Arch = $a"

		lappend architectures $a
	    }
	}
    }

    if {![llength $architectures]} {
	set architectures [list [platform::identify]]
    }

    # Expand the list of architecture per their patterns.

    foreach a $architectures {
	foreach x [platform::patterns $a] {
	    lappend architectures $x
	}
    }

    # Make the collected information available

    set archpatterns [lsort -uniq $architectures]
    ::log::log debug "Patterns: ($archpatterns)"
    return
}

#
# ### ### ### ######### ######### #########

proc ::tclapp::cmdline::Archives {argv ev av arv apv args} {
    variable switches
    variable argSwitch
    upvar 1 $ev errors $av archives $arv architectures $apv archpatterns

    ::log::log debug "PASS 5 (Archives)__________________________"
    ::log::log debug [list $argv]

    set Tconfig [teapot::config %AUTO%]

    # This pass extracts archive information. For package
    # expansion and retrieval.

    set unprocessed  {}
    set repositories {}

    # Before providing the set of archives to the other passes for use
    # the standard archives have to be added as well. These are, in
    # order of preference:
    #
    # - The pseudo-repository of the prefix file
    # - The pseudo repository holding all package files specified explicitly.
    # - The standard search paths per the preferences.
    # - The pseudo-repository holding just Tcl, to close the world.
    #    
    # The first two come before the project archives, the last two
    # come after.

    #--

    while {[llength $argv]} {
	set err [cmdline::getopt argv $switches opt arg]

	log::log debug "[format %2d $err] ($opt) - ($arg)"

	# -1 - bad option  : assert (Cannot happen)
	#  0 - non-option  : assert (Cannot happen)
	#  1 - good option

	if {$err < 0} {
	    # Unknown option. This should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"$opt (Should have been caught by previous pass)"
	} elseif {$err == 0} {

	    # Non-option arguments should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"File pattern should have been caught by previous pass"
	} else {
	    # Regular options. Handle the options of this pass ...

	    switch -exact -- $opt {
		archive {
		    log::log debug ARCHIVE___________________________________
		    log::log debug \t$arg
		    log::log debug \tIsProxy?

		    set proxy [IsProxy $arg]

		    log::log debug \tIsProxy=$proxy
		    log::log debug \tOpen/Cached

		    if {$proxy} {
			set fail [catch {
			    repository::cache open $arg -readonly 1 \
				-config $Tconfig \
				-notecmd ::tclapp::cmdline::NOTE
			} r]
		    } else {
			set fail [catch {repository::cache open $arg -readonly 1} r]
		    }

		    log::log debug \tOpen/Cached/Fail=$fail

		    if {$fail} {
			# Print warning, do not abort.
			::log::log warning $r
			foreach line [split $::errorInfo \n] {
			    log::log debug "ERROR: $line"
			}

			log::log debug \tSkip
			log::log debug __________________________________________
			continue
		    }

		    log::log debug \tTake
		    log::log debug __________________________________________

		    lappend repositories $r
		}
		default {
		    log::log debug "    Defered: -$opt"

		    lappend unprocessed -$opt
		    if {$argSwitch($opt)} {
			lappend unprocessed $arg
		    }
		}
	    }
	}
    }

    # Errors in this pass imply that the other passes have nothing to
    # do anymore.

    if {[llength $errors]} return

    # --

    foreach a [pref::devkit::pkgRepositoryList] {
	set proxy [IsProxy $a]
	if {$proxy} {
	    set fail [catch {repository::cache open $a -readonly 1 -config $Tconfig} r]
	} else {
	    set fail [catch {repository::cache open $a -readonly 1} r]
	}
	if {$fail} {
	    # Print warning, do not abort.
	    ::log::log warning $r
	    continue
	}
	lappend repositories $r
    }

    if {[tclapp::misc::prefixIsTeapotPrefix]} {
	tclapp::pkg::setArchives $repositories errors
	# More defered operations.
	if {![llength $errors]} {
	    ComputeArch architectures archpatterns
	    # Force initialization of data in pkg mgmt, in case this
	    # is the last pass.
	    ::tclapp::pkg::setArchitectures $archpatterns
	}
    }

    set virtual 1
    set repopre {}
    set prefix [tclapp::misc::prefix?]
    if {$prefix ne ""} {
	::log::log debug "prefix = <$prefix>"

	# Check for teapot:, should have been resolved by the
	# 'setArchives' above. However, if that operation fails (not
	# found, redirection failed, auth required, ...), then we
	# should not try to open as file.

	if {![tclapp::misc::prefixIsTeapotPrefix]} {
	    if {[catch {
		lappend repopre [repository::cache get repository::prefix $prefix]
		set virtual 0
	    } msg]} {
		::log::log debug "prefix repo creation failed <$msg>"

		# Print warning, do not abort.
		::log::log notice $msg
	    }
	}
    } elseif {[tclapp::misc::merge?]} {
	# Merging packages and files to an existing file.
	# Don't assume the virtual base.

	set virtual 0
    }

    lappend repopre [::tclapp::pkg::PackageFiles]

    set repositories [concat $repopre $repositories]

    if {$virtual} {
	# This happens iff there is no prefix specified.
	lappend repositories [::tclapp::pkg::VirtualBase]
    }

    # Errors in this pass imply that the other passes have nothing to
    # do anymore.

    if {[llength $errors]} return

    # Make the collected information available

    set archives $repositories

    ::log::log debug "Archives: ($archives)"
    foreach r $archives {
	::log::log debug "*   [$r cget -location]"
    }

    if {[llength $errors]} return

    # Chain call the next pass, except if there is nothing to process.
    #if {![llength $unprocessed]} return

    log::log debug "Chain: [linsert $args 1 $unprocessed]"

    uplevel 1 [linsert $args 1 $unprocessed]
    return
}

proc ::tclapp::cmdline::IsProxy {r} {
    if {[catch {
	set proxy [expr {[repository::api typeof $r] eq "::repository::proxy"}]
    } msg]} {
	set proxy 0
    }
    return $proxy
}

#
# ### ### ### ######### ######### #########
# Packages --

proc ::tclapp::cmdline::Packages {argv ev fv iv rv args} {
    variable switches
    variable argSwitch
    upvar 1 $ev errors $fv files $iv instances $rv references

    ::log::log debug "PASS 6 (Package pickup)____________________"
    ::log::log debug [list $argv]

    # This pass collects the specified packages and versions. The next
    # pass determines the applicable resolution strategy and executes
    # it. That is the main part of the TEAPOT integration.

    # Backward compat: TDK < 4 had special code to resolve bad package
    # names of old which had slipped into the .tap files of a release
    # and thus into project files. This is now handled outside of
    # TclApp, by providing a repository which provides the necessary
    # translations in the form of profiles.

    # The other fuzz (possible version upgrade) is handled through the
    # regular code. See the next pass.

    set unprocessed {}

    while {[llength $argv]} {
	set err [cmdline::getopt argv $switches opt arg]

	log::log debug "[format %2d $err] ($opt) - ($arg)"

	# -1 - bad option  : assert (Cannot happen)
	#  1 - good option
	#  0 - non-option argument is at the front.

	if {$err < 0} {
	    # Unknown option. This should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"$opt (Should have been caught by previous pass)"
	} elseif {$err == 0} {

	    # Non-option arguments should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"File pattern should have been caught by previous pass"
	} else {
	    switch -exact -- $opt {
		p - pkg {
		    lappend references [tclapp::pkg::toref $arg]
		}
		app {
		    lappend references [set app [tclapp::pkg::toref $arg]]
		    tclapp::misc::app  [list [lindex $app 0]]
		}
		pkgfile {
		    lappend files $arg
		}
		pkginstance {
		    lappend instances $arg
		}
		pkgref {
		    set ref [teapot::reference::normalize1 $arg]
		    set e [::teapot::entity::norm [::teapot::reference::entity $ref {}]]
		    if {$e eq ""} {
			# References without entity get limited to packages.
			lappend ref -is package
		    } elseif {$e ne "package"} {
			# Explicit non package references are rejected.
			lappend errors \
			    [format [mget 503_NONPACKAGE_REFERENCE] $arg]
			break
		    }

		    lappend references $ref
		}
		default {
		    log::log debug "    Defered: -$opt"

		    lappend unprocessed -$opt
		    if {$argSwitch($opt)} {
			lappend unprocessed $arg
		    }
		}
	    }
	}
    }

    # Errors in this pass imply that the other passes have nothing to
    # do anymore.

    if {[llength $errors]} {set unprocessed {}}

    ::log::log debug "Files:      $files"
    ::log::log debug "Instances:  $instances"
    ::log::log debug "References: $references"

    # Chain call the next pass. Even if there is nothing process
    # anymore. It may do something with the information we have picked
    # up, even if itself has no additional stuff to determine, just
    # use any defaults.

    log::log debug "Chain: [linsert $args 1 $unprocessed]"

    uplevel 1 [linsert $args 1 $unprocessed]
    return
}

#
# ### ### ### ######### ######### #########
# Expansion --

proc ::tclapp::cmdline::Expansion {argv ev fv iv rv arv apv args} {
    variable switches
    variable argSwitch
    upvar 1 $ev errors $fv files $iv instances $rv references $arv archives $apv archpatterns

    ::log::log debug "PASS 7 (Package expansion/resolution)______"
    ::log::log debug [list $argv]

    # This pass determines the applicable resolution strategy and
    # executes it. That is the main part of the TEAPOT integration.
    # As part of the resolution we perform fuzzy search, upgrading
    # package versions as necessary.

    log::log info Expanding...

    set accept      0
    set unprocessed {}
    set force       0
    set follow      0
    set recommend   0

    while {[llength $argv]} {
	set err [cmdline::getopt argv $switches opt arg]

	log::log debug "[format %2d $err] ($opt) - ($arg)"

	# -1 - bad option  : assert (Cannot happen)
	#  1 - good option
	#  0 - non-option argument is at the front.

	if {$err < 0} {
	    # Unknown option. This should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"$opt (Should have been caught by previous pass)"
	} elseif {$err == 0} {

	    # Non-option arguments should have been caught by previous
	    # passes. Thus this situation is an internal error!

	    return -code error \
		"File pattern should have been caught by previous pass"
	} else {
	    switch -exact -- $opt {
		upgrade - pkg-accept {
		    set accept 1
		}
		pkgfile {
		    tclapp::pkg::enterExternal $arg errors
		}
		follow {
		    set follow 1
		}
		follow-recommend {
		    set follow    1
		    set recommend 1
		}
		force {
		    set force 1
		}
		default {
		    log::log debug "    Defered: -$opt"

		    lappend unprocessed -$opt
		    if {$argSwitch($opt)} {
			lappend unprocessed $arg
		    }
		}
	    }
	}
    }

    ::log::log debug "Accept:    $accept"
    ::log::log debug "Follow:    $follow"
    ::log::log debug "Recommend: $recommend"
    ::log::log debug "Force:     $force"

    if {$recommend} {
	log::log info "    Following required & recommended dependencies"
    } elseif {$follow} {
	log::log info "    Following required dependencies"
    } else {
	log::log info "    Following only profile dependencies"
    }
    if {$force} {
	log::log info "    Accepting missing dependencies"
    }
    if {$accept} {
	log::log info "    Accepting version changes made by fuzzy search"
    }

    if {$accept || $recommend || $force} {
	log::log info " "
    }

    # Execute the specified expansion strategy, and choice of how to
    # handle recoverable problems.

    set recoverable {}
    set display     {}

    # display = list (list (isprofile ref instance origin) ...)

    # Profiles in package files and instances are expanded first. This
    # can be done independent of the expansion mode, profile is
    # minimum, and doing this separately is easier. Afterwards we have
    # additional references and also an initial set of package files
    # to wrap. Bad files and instances are recorded as errors.

    ::tclapp::pkg::setArchitectures $archpatterns
    ::tclapp::pkg::setArchives      $archives  errors

    array set state {}

    ::tclapp::pkg::enterExternals   $files     errors references display
    ::tclapp::pkg::enterInstances 1 $instances errors references display state

    # Extended references ?

    foreach r $references {::log::log debug "References: $r"}

    # Now the references. In a cycle they are converted to instances,
    # dependencies are taken as new references, converted to
    # instances, etc. until we have expanded all references as per the
    # mode set. The conversion of references to instances does the
    # fuzzy search, introducing the recoverable errors.

    # Note: enterInstances expands the profile packages.
    # expandInstances follows dependencies.

    set warnings {}
    set iserr 1

    # TAP handling.
    # Set of tap tokens already wrapped.

    set tap {}


    while {[llength $references]} {
	::log::log debug "ExpandReferences ..."

	set instances  [tclapp::pkg::uniq [::tclapp::pkg::expandReferences $iserr $references errors recoverable warnings state display tap]]
	set references {}
	foreach i $instances {::log::log debug "    Instances:  <$i>"}

	::log::log debug "EnterInstances ..."

	set instances  [::tclapp::pkg::enterInstances $iserr $instances errors references display state]

	foreach i $instances {::log::log debug "    Instances:  <$i>"}

	if {$follow} {
	    ::log::log debug "ExpandInstances ..."
	    ::tclapp::pkg::expandInstances $iserr $instances $recommend references state
	}

	foreach r $references {::log::log debug "References: <$r>"}
	set iserr 0
    }

    log::log info " "
    log::log info Issues...

    ProcessWarnings  errors $force  $warnings
    ProcessRecovered errors $accept $recoverable

    # The basic processing of the options has been done. If there are
    # errors we bail out now.

    if {[llength $errors]} return

    if {[llength $warnings] || [llength $recoverable]} {
	log::log info Recovered
    }

    # We can now display the references and instances and files which
    # are used for wrapping, with all their particulars. Sorted by
    # package name, version, and architecture. See teapot client, Gen
    # Listing.

    log::log info   " "
    log::log notice "Packages ..."

    if {[llength     $display]} {
	#Cleanup       display
	ShowPackages $display
	log::log info   " "
    } else {
	log::log notice "* No packages"
    }

    # Errors in this pass imply that the other passes have nothing to
    # do anymore.

    # Force here too ...

    if {[llength $errors]} {set unprocessed {}}

    # Chain call the next pass, except if there is nothing to process.
    if {![llength $unprocessed]} return

    log::log debug "Chain: [linsert $args 1 $unprocessed]"

    uplevel 1 [linsert $args 1 $unprocessed]
    return
}

proc tclapp::cmdline::Cleanup {dv} {
    upvar 1 $dv display

    # Merge the reference information separate from the regular
    # instance information into one record per instance.

    set       tmp {}
    array set ref {}

    foreach item $display {
	foreach {isprofile iref instance origin} $item break
	if {$isprofile eq ""} {
	    set ref($instance) $iref
	} else {
	    lappend tmp $item
	}
    }

    set display {}
    foreach item $tmp {
	foreach {isprofile iref instance origin} $item break

	if {[info exists ref($instance)]} {
	    set iref $ref($instance)
	}
	lappend display [list $isprofile $iref $instance $origin]
    }

    return
}

proc tclapp::cmdline::ShowPackages {display} {
    set maxn 0
    set maxv 0
    set maxa 0

    foreach item $display {
	foreach {__ instance __} $item break
	teapot::instance::split $instance _ n v a
	max maxn $n
	max maxv $v
	max maxa $a
    }

    foreach item $display {
	foreach {isprofile instance origin} $item break
	teapot::instance::split $instance _ n v a
	set tag [expr {$isprofile ? "P" : " "}]
	log::log notice "$tag [lj $maxn $n] [lj $maxv $v] [lj $maxa $a] @ $origin"
    }

    return
}

proc tclapp::cmdline::Max {resolved nv vv av} {
    upvar 1 $nv maxn $vv maxv $av maxa

    set maxn 0
    set maxv 0
    set maxa 0
    foreach {ref item} $resolved {
	foreach {installed einstance repolist} $item break
	if {![llength $einstance]} continue
	teapot::instance::split $einstance _ n v a
	max maxn $n
	max maxv $v
	max maxa $a
    }

    return
}

proc tclapp::cmdline::DisplayResolution {resolved maxn maxv maxa ev} {
    upvar 1 $ev errors

    foreach {ref item} $resolved {
	set v {}

	# NOTE: In case of a package with multiple requirements in its
	# reference and no matching instance the requirements fall
	# through into the display, either regular or error
	# message. The result may look off.

	teapot::reference::type          $ref n v
	foreach {installed einstance repolist} $item break

	if {[llength $einstance]} {
	    teapot::instance::split $einstance _ n v a
	    set isp [lindex $einstance end]
	}

	if {![llength $repolist] && !$installed} {
	    Log error       "  Unknown! " $n $v {} {}

	    if {$v ne ""} {append n -$v}
	    lappend errors [format [mget 500_UNKNOWN_PACKAGE] $n]

	} else {
	    set    tag [expr {$isp ? "P " : "  "}]
	    append tag [expr {$installed ?
			      "Installed" :
			      "         "}]

	    Log notice  $tag $n $v $a $repolist
	}
    }

    return
}

proc tclapp::cmdline::Retrieve {resolved maxn maxv maxa ev} {
    upvar 1 $ev errors

    if {![llength $resolved]} return

    log::log info   " "
    log::log notice "Retrieval ..."

    foreach {ref item} $resolved {
	foreach {installed einstance repolist} $item break

	if {$installed} continue
	if {![llength $repolist]} continue

	teapot::instance::split $einstance e n v a
	set  isprofile [lindex $einstance end]
	if {$isprofile} continue

	set dst      [fileutil::tempfile pkg]
	set instance [teapot::instance::cons $e $n $v $a]

	set ok 0
	foreach r $repolist {
	    if {[catch {
		$r sync get $instance $dst
	    } msg]} {
		log::log warning "Failed [lj $maxn $n] [lj $maxv $v] [lj $maxa $a] : [$r cget -location] : $msg"
	    } else {
		log::log notice  "Ok     [lj $maxn $n] [lj $maxv $v] [lj $maxa $a] : [$r cget -location]"

		tclapp::pkg::enterInternal $instance $dst
		set ok 1
		break
	    }
	}

	if {!$ok} {
	    lappend errors "Failed to retrieve package [teapot::reference::name $ref]"
	}
    }

    return
}


proc tclapp::cmdline::Log {level label n v a repolist} {
    upvar 1 maxn maxn maxv maxv maxa maxa

    if {![llength $repolist]} {
	log::log $level "$label [lj $maxn $n] [lj $maxv $v] $a"
    } elseif {[llength $repolist] == 1} {
	log::log $level "$label [lj $maxn $n] [lj $maxv $v] [lj $maxa $a] @ [[lindex $repolist 0] cget -location]"
    } else {
	set str "$label [lj $maxn $n] [lj $maxv $v] [lj $maxp $a] @ "
	foreach r $repolist {
	    log::log $level ${str}[$r cget -location]
	    set str [blankstr $str]
	}
    }
    return
}

proc tclapp::cmdline::max {v str} {
    upvar 1 $v max
    set l [string length $str]
    if {$l > $max} {set max $l}
    return
}

proc tclapp::cmdline::lj {n s} {format %-*s $n $s}
proc tclapp::cmdline::rj {n s} {format %*s $n $s}

proc tclapp::cmdline::blankstr {text} {
    # Replaces a string with equivalent whitespace.  All characters
    # except tab are replaced with a space.  Tab is whitespace, and
    # has to remain, or the replacement string will have different tab
    # stops.

    regsub -all -- {[^ 	]} $text { } text
    return $text
}

proc tclapp::cmdline::ProcessRecovered {ev accept recovered} {
    upvar 1 $ev errors

    if {![llength $recovered]} return

    # Decide wether to treat the recoverable problems as errors or not.

    if {[llength $errors] || !$accept} {
	# We consider trouble we recovered from as errors if they are
	# not auto-accepted, or if we have unrecoverable errors as
	# well.

	set unrec [llength $errors]

	lappend errors " "
	foreach item $recovered {
	    lappend errors $item
	}

	lappend errors " "
	lappend errors "Unrecognized package names and/or versions in input."

	if {$unrec} {
	    lappend errors "You have unrecoverable issues."
	    lappend errors "You cannot use -upgrade to ignore the recoverable issues."
	} else {
	    lappend errors "Use -upgrade to ignore the recoverable issues."
	}

    } else {
	# We had recoverable problems, but no errors, and the recovery
	# was accepted. We put the items into the log for
	# posteriority, but do not abort.

	foreach item $recovered {
	    ::log::log notice $item
	}
    }

    return
}

proc tclapp::cmdline::ProcessWarnings {ev force warnings} {
    upvar 1 $ev errors

    if {![llength $warnings]} return

    # Decide wether to treat the dependency resolution warnings as
    # errors or not.

    if {[llength $errors] || !$force} {
	# We consider dependency troubles as errors if they are not
	# forcibly accepted, or if we have other unrecoverable errors
	# as well.

	set unrec [llength $errors]

	lappend errors " "
	foreach item $warnings {
	    lappend errors $item
	}

	lappend errors " "
	lappend errors "Incomplete dependency expansion of packages in the input."

	if {$unrec} {
	    lappend errors "You have unrecoverable issues."
	    lappend errors "You cannot use -force to ignore the recoverable issues."
	} else {
	    lappend errors "Use -force to ignore the recoverable issues."
	}
    } else {
	# We had dependency problems, but no errors, and the recovery
	# was forced. We put the items into the log for posteriority,
	# but do not abort.

	foreach item $warnings {
	    ::log::log notice $item
	}
    }

    return
}

#
# ### ### ### ######### ######### #########
# Closure --

proc ::tclapp::cmdline::Closure {argv} {

    ::log::log debug "PASS X (Closure)___________________________"
    ::log::log debug [list $argv]

    # The previous passes have to have processed all arguments, be
    # they options or non-options. It is an internal error if they
    # have not.

    if {[llength $argv]} {
	return -code error "Unprocessed arguments [list $argv]"
    }
    return
}

#
# ### ### ### ######### ######### #########
# HandleEncoding --

proc ::tclapp::cmdline::HandleEncoding {name xv ev} {
    upvar 1 $xv encodings $ev errors

    # An encoding internally translates into a request to wrap a
    # particular file, where destination and source are both
    # implicitly known. Essentially the file resolution context is

    #     -relativeto [info library]/encoding
    #     -anchor     lib/tclX.y/encoding

    # ATTENTION __

    # When TclApp is running wrapped [info library] will refer to a
    # directory in the wrapped filesystem. This means that the wrapper
    # has to be wrapped with all available encodings or the result
    # will not be able to wrap the missing encodings.

    # We generate an error if the name of the chosen encoding is not
    # known (i.e. if no source file is present).

    # Bugzilla 23184. However we do ignore the option completely if
    # the specified encoding is one of the several encodings which are
    # hardwired into the Tcl interpreter, or the package Tk: identity,
    # unicode, utf-8, X11ControlChars, and ucs-2be.

    if {
	[string equal $name identity] ||
	[string equal $name unicode]  ||
	[string equal $name utf-8]    ||
	[string equal $name X11ControlChars] ||
	[string equal $name ucs-2be]
    } {
	return
    }

    set file ${name}.enc
    set src [file join [info library] encoding $file]

    if {![file exists $src]} {
	log::log debug "Encoding searcher: [info nameofexecutable]"
	log::log debug "Encoding searcher: $::argv0"
	log::log debug "Encoding searched CWD [pwd]"
	log::log debug "Encoding searched IL  [info library]"
	log::log debug "Encoding searched @ $src"
	log::log debug "Encoding \"$name\" is not known, not found"

	lappend errors "Encoding \"$name\" is not known"
	return
    }

    lappend encodings $src $file
    return
}


proc ::tclapp::cmdline::RegisterEncodings {encodings ev} {
    upvar 1 $ev errors
    variable theEncodings

    # We register the encodings only after the options have been
    # processed, because we have to look into the prefix file (if
    # there is any) for the destination directory. We cannot simply
    # use the tcl version of TclApp itself, as it may be different
    # from the version of the chosen basekit. If there is no basekit
    # we will have to use a default though, with the possibility that
    # the application later fails.

    # Note: We could route the definitions through the upcoming file
    # processing stage, by translating them into appropriate series of
    # options. This is IMHO a waste of cycles given that a direct
    # access is much easire, and less error-prone (not going through
    # th expansion and resolution phases). We know the anchor,
    # relativeto information, etc. already.

    set prefix [tclapp::misc::prefix?]
    if {$prefix ne ""} {
	if {[tclapp::misc::isTeapotPrefix $prefix]} {
	    # Save encodings for defered call by tclapp::pkg::setArchives
	    set theEncodings $encodings
	    return
	}

	# We mount the prefix over itself and then look for a tcl
	# library directory.

	# The prefix is only read, not modified. We are mounting it
	# read-only expressing this, and to allow the input to be a
	# non-writable file too.

	vfs::mk4::Mount $prefix $prefix -readonly
	set tcldirs [glob -nocomplain -directory $prefix \
			 -tails {lib/tcl[0-9].[0-9]}]
	vfs::unmount $prefix

	if {![llength tcldirs]} {
	    # No tcl library directory. Fall back to default, as if
	    # there is no prefix.

	    set tclver [info tclversion]
	    set base   [file join lib tcl$tclver encoding]

	} elseif {[llength tcldirs] > 1} {
	    # Multiple tcl library directories found.
	    # Report this ambiguity as error.

	    lappend errors "Prefix has multiple Tcl library directories, no unambiguous location to store the encodings into."
	    return

	} else {
	    set base [file join [lindex $tcldirs 0] encoding]
	}
    } else {
	set tclver [info tclversion]
	set base   [file join lib tcl$tclver encoding]
    }

    if {![llength $encodings] && [llength $theEncodings]} {
	# Pull defered encodings.
	set encodings $theEncodings
    }

    foreach {src file} $encodings {
	set dst [file join $base $file]
	tclapp::files::add errors $src $dst
    }
    return
}

#
# ### ### ### ######### ######### #########
# LoadConfig --
#
#	Loads and processes a configuration file.
#
# Arguments:
#	infile	The path to the file.
#
# Results:
#	None.

proc ::tclapp::cmdline::LoadConfig {ev infile cfgvar} {
    upvar 1 $ev errors $cfgvar cfg

    # Prevent infinite recursive inclusion of configuration files.

    if {[info exists cfg($infile)]} {
	lappend errors \
	    "circular inclusion of configuration file $infile"
	return {}
    }
    set cfg($infile) .

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

    if {[lsearch -exact [tclapp::config::tools] $tool] < 0} {
	# Is a project file, but not for this tool.

	lappend errors "$basemsg ${infile}.\n\n$fmttool $tool"
	return {}
    }

    # The file is tentatively identified as project file for this
    # tool, so read the information in it. If more than one tool is
    # supported by the application we ask its master widget for the
    # list of keys acceptable for the found tool.

    set allowed_keys [tclapp::config::keys $tool]

    if {[catch {
	set theconfig [::tcldevkit::config::Read/2.0 $infile $allowed_keys]
    } msg]} {
	lappend errors "$basemsg ${infile}.\n\n$fmtkey ${tool}:\n\n$msg"
	return {}
    }

    return [tclapp::config::ConvertToOptions errors $theconfig $tool]
}

#
# ### ### ### ######### ######### #########

proc ::tclapp::cmdline::NOTE {text} {
    variable logp
    foreach {p l} $logp {
	if {[string match $p $text]} {
	    if {$l eq {}} return

	    if {[regexp {^([^(]*)\((.*)\)(.*)$} $text -> pre html post]} {
		set text ${pre}([StripTags $html])$post
	    }
	    log::log $l $text
	    return
	}
    }

    log::log error $text
    return
}

proc ::tclapp::cmdline::StripTags {msg} {
    return [join $msg \n]
}

proc ::tclapp::cmdline::Init {} {
    variable switches
    variable argSwitch

    foreach k $switches {
	set args [string match "*.arg" $k]
	if {$args} {
	    set opt [string range $k 0 end-4]
	} else {
	    set opt $k
	}
	set argSwitch($opt) $args
    }

    #parray argSwitch
    return
}

namespace eval ::tclapp::cmdline {

    variable logp {
	*Failed*   warning
	*401*      warning
	*Disabled* warning
	{*Retrieving remote INDEX*} {}
	*Status*   {}
	{*Using locally cached INDEX*} {}
    }

    variable switches {
	%%.arg %save %restore
	alias.arg
	anchor.arg
	app.arg
	architecture.arg
	archive.arg
	arguments.arg a.arg 
	code.arg c.arg 
	postcode.arg
	compile
	compilefile
	compilefor.arg
	config.arg
	debug
	encoding.arg
	executable.arg e.arg prefix.arg
	follow
	follow-recommend
	force
	fsmode.arg
	help h ?
	icon.arg
	infoplist.arg
	interpreter.arg i.arg
	log.arg l.arg 
	merge
	metadata.arg
	nocompilefile
	nocompress
	nologo n
	noprovided
	nospecials
	notbcload
	osxapp
	out.arg o.arg
	pkg-accept
	pkg.arg p.arg
	pkgdir.arg
	pkgfile.arg
	pkgref.arg
	relativeto.arg r.arg
	startup.arg s.arg 
	stringinfo.arg
	temp.arg t.arg
	upgrade
	verbose v
    }
    # Disabled. Dealing only with references. Gui cannot show this.
    # pkginstance.arg

    variable  argSwitch
    array set argSwitch {}

    # Place to stash the encodings if we have to defer registration
    # until a teapot prefix reference has been resolved.

    variable theEncodings {}

    Init
}

#
# ### ### ### ######### ######### #########

package provide tclapp::cmdline 1.0
