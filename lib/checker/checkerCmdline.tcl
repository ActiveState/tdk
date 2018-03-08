# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# checkerCmdline.tcl --
#
#	This file specifies what is done with command line arguments in
#       the Checker.
#
# Copyright (c) 1999-2000 Ajuba Solutions
# Copyright (c) 2002-2008 ActiveState Software Inc.

# 
# RCS: @(#) $Id: checkerCmdline.tcl,v 1.9 2001/04/11 18:48:12 welch Exp $

# ### ######### ###########################
## Requisites

package require pref::devkit ; # TDK    preferences

package require pcx ; # PCX Mgmt. Aka extension mgmt, aka package mgmtm
package require struct::list

# ### ######### ###########################
## Implementation

namespace eval checkerCmdline {

    # The usageStr variable stores the message to print if there is
    # an error in the command line args or -help was specified.

    variable usageStr   {}
    variable hasversion 0
    variable version    "Build @buildno@"

    variable dirlist {}
    variable here [file dirname [info script]]
}

# checkerCmdline::init --
#
#	Based on command line arguments, load type checkers
#	into the anaylyzer.
#
# Arguments:
#	None.
#
# Results:
#	A list of files to be analyzed; an empty list means stdin will
#	analyzed.  If file patterns were specified, but no matching files
#	exist, then print the usage string and exit with an error code of 1.

proc checkerCmdline::init {} {
    global argv ::configure::versions \
	    \
	    ::projectInfo::printCopyright \
	    ::configure::machine \
	    ::configure::summary \
	    ::configure::xref \
	    ::configure::ping \
	    ::configure::packages \
	    ::configure::maxsleep \
	    ::configure::eindent \
	    ::configure::preload
    variable usageStr
    variable hasversion
    variable version
    set printCopyright 0

    set usageStr "Usage: [cmdline::getArgv0] ?options? ?filePattern...?
  -help     Print this help message
  -quiet    Prints minimal error information
  -onepass  Perform a single pass without checking proc args
  -verbose  Prints additional summary information
  -summary  Prints only summary information
  -suppress \"messageID ?messageID ...?\"
            Prevent given messageIDs from being printed.
            Overrides the -Wx options, and pragmas for global scope
  -check    \"messageID ?messageID ...?\"
            Ensure printing of given messageIDs.
            Overrides the -Wx options, and pragmas for global scope
  -use      \"package?version? ?package?version? ...?\"
            Specify specific versions & packages to check
  -W0       Print nothing by default. Anything will have to enabled via -check.
  -W1       Print only error messages.
            Overridden for individual messages by -check/-suppress and pragmas.
  -W2       Print error and usage warnings.
            Overridden for individual messages by -check/-suppress and pragmas.
  -W3       Print all errors and all warnings except for upgrade warnings (default).
            Overridden for individual messages by -check/-suppress and pragmas.
  -W4       Print all errors and warnings.
            Overridden for individual messages by -check/-suppress and pragmas.
  -Wall     Print all types of messages (same as W3).
            Overridden by -check/-suppress and pragmas.
  -ranges \"ranges\"
  -range \"ranges\"
            Print only messages for lines in one of the ranges.
            ranges = range?,range,...?
            range = start-, -end, start-end
  -xref     Activate cross-reference mode. No syntax checking nor corresponding warnings.
  -packages Print the list of the packages required by the scanned code. Syntax checking
            is not done in this mode. Implies -onepass.
  -pcx \"path\"
            Extend the list of directories searched for .pcx files with the given path.
  -@ \"path\"
            Read file patterns to scan from the file"

    # Bug 76837 documentation.
    append usageStr "\n" \
	"  -style-maxsleep N\n" \
	"            Set the threshold above which to issue warnStyleSleep warnings"

    # Bug 84390 documentation.
    append usageStr "\n" \
	"  -indent N\n" \
	"            Set the indentation to expect for commands to multiples of N\n" \
	"            characters. The default is 4, matching the Tcl Style Guide.\n" \
	"            This affects the generation of warnStyleIndentCommand warnings.\n" \
	"            The minimum allowed value is 2."

    # Bug 76847 documentation.
    append usageStr "\n" \
	"  -as dict\n" \
	"            Write messages as machine readable Tcl dictionaries\n" \
	"  -as script\n" \
	"            Write messages as Tcl script, human and machine-readable\n" \
	"  -as overview\n" \
	"            Write messages in the regular compact form (default)"

    # Parse the command line args, ammending the global auto_path
    # if a path is specified, and building a list of packages if 
    # a one or more packages are specified.  

    set ping      0
    set xref      0
    set packages  0
    set machine   0
    set errorMsg  {}
    set errorCode -1
    set quiet 0
    set usrPkgArgs {}
    set filesources {}

    set optionList {
	? h help ping logo u.arg use.arg s.arg suppress.arg c.arg check.arg
	o onepass q quiet v verbose W0 W1 W2 W3 W4 Wall Wa pcx.arg xref packages
	@.arg pcxdebug range.arg ranges.arg style-maxsleep.arg as.arg summary
	indent.arg
    }
    # HACK. The option style-maxsleep is for Expect.pcx, yet we
    # process it with the checker core command line. May need
    # extensible command line options ? Options which go to specific
    # packages ?

    # pcxdebug is an internal, undocumented option. It activates lots
    # of output for when loading a .pcx file goes wrong.

    if {$hasversion} {lappend optionList V -version}

    # Allow activation of pcx debugging before loading the PCO's, so
    # that we can reuse the relevant commands for pco debugging as
    # well.
    if {[lindex $argv 0] eq "-pcxdebug"} { pcx::debug }

    # Bug 76835
    LoadOptionDefinitions optionList optionDef

    filter::defaultSet 1 warnStyleExit  ; # A number of style warnings are disabled by
    filter::defaultSet 1 warnStyleError ; # default. They can be enabled at a per-file
    filter::defaultSet 1 warnStyleSleep ; # level through per-file checker commands.
    #                                       Cisco will use this.
    filter::defaultSet 1 warnStyleNameVariableConstant

    # Bug 81277. Warnings about packages for which we have no .pcx
    # definitions are disabled by default. As Hemang put it, the user
    # cannot fix anything in the code to make this message go away.
    # Choosing -v(erbose) (or -summmary) will activate it however.
    filter::defaultSet 1 pkgUnchecked

    set explicitWlevel {}

    pref::setGroupOrder  [pref::devkit::init]
    set defaults [::pref::devkit::defaultCheckerOptions]
    if {[llength $defaults]} {
	set argv [list {*}$defaults {*}$argv]
    }

    set preload {} ; # List of packages requested by the command line.
    array set recursing {}
    set inputs {} ; # list (tuple/2 (ranges, list (file...))...)

    while {[llength $argv]} {
	# Process options ...
	ProcessOptions argv $optionList optionDef
	if {$errorCode > 0} break
	if {![llength $argv]} break
	# Process files ...
	set at 0
	while {($at < [llength $argv]) && ![string match -* [lindex $argv $at]]} { incr at }
	if {$at >= [llength $argv]} {
	    # Everything remaining is a file.
	    lappend inputs [list [filter::getranges] $argv]
	    set argv {}
	    break
	} else {
	    # Partial set of files.
	    lappend inputs [list [filter::getranges] [lrange $argv 0 $at-1]]
	    set argv [lrange $argv $at end]
	}
	# continue processing options.
    }

    # Set filtering
    if {$explicitWlevel eq ""} {
	# Default to -W3 if nothing was specified by the user.
	set explicitWlevel W3
    }
    switch -exact -- $explicitWlevel {
	W0 {
	    # filter everything. nothing printed but what is enabled explicitly via -check.
	    filter::addFilters {err warn nonPortable performance style upgrade usage nonPublic}
	}
	W1 {
	    # filter all warnings.
	    filter::addFilters {warn nonPortable performance style upgrade usage nonPublic}
	}
	W2 {
	    # filter aux warnings.
	    filter::addFilters {warn nonPortable performance style upgrade nonPublic}
	}
	W3 {
	    filter::addFilters {style upgrade}
	}
	W4 -
	Wa -
	Wall {
	    # No-op do not filter anything.
	}
    }

    set ::configure::md5 "Suppress"
    # Setting the variable to some value ensures that we don't compute
    # md5 for data on stdin. The regular linter does not need this.

    ## set xref 0 ; ## 3.0 FEATURE OFF
    ## set ping 0 ; ## 3.0 FEATURE OFF

    if {$xref} {
	# xref implies: multiple passes & as less output as possible.
	analyzer::setTwoPass 1
	analyzer::setVerbose 0
	set configure::summary 0
	analyzer::setQuiet   1
    } elseif {$packages} {
	# package listing mode: one pass, no output

	analyzer::setTwoPass 0 ; # Irrelevant, see 'analyzer::check'
	analyzer::setVerbose 0
	analyzer::setQuiet   1
	set configure::summary 0
    } else {
	# No pings if not in xref mode.
	set ping 0
    }

    if {[analyzer::getVerbose]} {
	# Verbose implies summary, not only summary.
	set configure::summary 0
	# Bug 81277.
	filter::defaultSet 0 pkgUnchecked
    }

    if {$configure::summary} {
	set ::message::displayProc ::message::displayNull
	# Bug 81277.
	filter::defaultSet 0 pkgUnchecked
    }

    # Print the copyright information and check the license.  By
    # setting the projectInfo::printCopyright variable above we tune
    # the output.  But, always call the procedure to ensure the
    # license is checked.  See also the startup.tcl script that sets
    # the projectInfo::verifyCommand

    projectInfo::printCopyright $::projectInfo::productName

    if {$errorCode >= 0} {
	Puts $errorMsg
	catch {$::projectInfo::licenseReleaseProc}
	exit $errorCode
    }

    # Load file patterns from -@ files.

    foreach f $filesources {
	set fx [open $f r]
	set files {}
	foreach l [split [read $fx] \n] {
	    if {$l == ""} continue
	    lappend files $l
	}
	close $fx
	lappend inputs [list [filter::getranges] $files]
    }

    # if no file patterns were specified, use stdin

    if {[llength $inputs] == 0} {
	return {}
    }

    # find the list of valid files to check, and fill the range
    # database with per-file information.

    set result {}
    foreach input $inputs {
	lassign $input ranges files
	foreach f [cmdline::getfiles $files $quiet] {
	    lappend result $f
	    filter::rangesfor $f $ranges
	}
    }

    # If no valid files were specified, print the usage string and
    # exit with an error result.  Otherwise, return the list of valid
    # files to check.

    if {[llength $result] == 0} {
	puts stdout $checkerCmdline::usageStr
	catch {$::projectInfo::licenseReleaseProc}
	exit 1
    }
    return $result
}

proc checkerCmdline::LoadOptionDefinitions {ov odv} {
    upvar 1 $ov optionList $odv optionDef
    variable dirlist

    InitializeDirs
    pcx::LOG {PCO RESOLVE for PCO}

    set dirlist [lsort -uniq $dirlist]

    #::log::log debug "PCO directories: [join $dirlist "\nPCO directories: "]"
    pcx::LOG {PCO Directory: [join $dirlist "\nPCO Directory: "]}
    foreach dir $dirlist {
	set files {}
	catch {set files [glob -nocomplain -dir $dir *.pco]} 
	foreach f $files {
	    pcx::LOG {PCO LOADING $f}
	    if {[catch {
		# Loading has to be done in the local scope, to have
		# access to the variables 'optionList' and
		# 'optionDef'.
		source $f
	    } err]} {
		pcx::LOG {PCO LOAD ERROR [join [split $::errorInfo \n] "\nLOAD ERROR "]}
		pcx::LOG {PCO LOADING FAILED}
		return -code error \
		"Error loading options $f:\n\
		$err\n$::errorInfo"
	    }
	    # Loading ok.
	    pcx::LOG {PCO LOADING OK}
	}
    }
    pcx::LOG {PCO LOADED}
    return
}

proc checkerCmdline::InitializeDirs {} {
    variable dirlist
    variable here
    global env

    # See also ::pcx::Initialize for a similar command.
    # XXX AK Consider generalization of such code in a TDK common
    # XXX package.

    # See tclapp/lib/app-tclapp/tclapp_pkg.tcl, SearchPaths for
    # equivalent code used by TclApp. We might wish to factor the
    # standard search into a command for the common tdk code.

    foreach base [list \
	    [file join $starkit::topdir data pcx] \
	    $::projectInfo::pcxPdxDir \
	    $here
	    ] {
	if {
	    [file exists      $base] &&
	    [file isdirectory $base] && 
	    [file readable    $base]
	} {
	    lappend dirlist $base
	}
    }

    # Paths from the preferences. Uses same key as TclApp.
    # I.e. where TclApp is looking for .tap files we are
    # looking for .pco files.

    foreach base [pref::devkit::pkgSearchPathList] {
	if {
	    [file exists      $base] &&
	    [file isdirectory $base] && 
	    [file readable    $base]
	} {
	    lappend dirlist $base
	}
    }

    # Paths from the User environment.

    foreach v [list \
	    $::projectInfo::pcxPdxVar \
	    TCLPRO_LOCAL \
	    ] {

	pcx::LOG {PCO INITDIRS ENV = $v}

	if {![info exists       env($v)]} {
	    pcx::LOG {PCO INITDIRS not in environment}
	    continue
	}
	if {![file exists      $env($v)]} {
	    pcx::LOG {PCO INITDIRS not in filesystem: $env($v)}
	    continue
	}
	if {![file isdirectory $env($v)]} {
	    pcx::LOG {PCO INITDIRS not a directory: $env($v)}
	    continue
	}
	if {![file readable    $env($v)]} {
	    pcx::LOG {PCO INITDIRS not readable: $env($v)}
	    continue
	}

	pcx::LOG {PCO INITDIRS added: $env($v)}
	lappend dirlist $env($v)
    }

    # Remove duplicates, do not disturb the order of paths. Normalize
    # the paths on the way. Unique before normalize reduces
    # normalization effort, unique after normalize because symlinks
    # may generate new duplicates.

    set dirlist [lsort -unique \
		     [struct::list map \
			  [lsort -unique $dirlist] \
			  {file normalize}]]

    # Add subdirectories of the search paths to the search to.
    # (Only one level).

    set res [list]
    foreach p $dirlist {
	lappend res $p
	set sub {}
	catch {set sub [glob -nocomplain -types d -directory $p *]}
	if {[llength $sub] > 0} {
	    foreach s $sub {
		lappend res $s
	    }
	}
    }
    set dirlist $res
    return
}

proc checkerCmdline::DefList {opt replacement} {
    upvar 1 optionList optionList optionDef optionDef

    if {[string match -* $opt]} {
	set opt [string range $opt 1 end]
    }
    if {![info exists optionDef($opt)]} {
	lappend optionList $opt
    }

    pcx::LOG {PCO Def '-$opt' :: $replacement}
    set optionDef($opt) $replacement
    return
}

proc checkerCmdline::Def {opt script} {
    upvar 1 optionList optionList optionDef optionDef

    if {[string match -* $opt]} {
	set opt [string range $opt 1 end]
    }
    if {![info exists optionDef($opt)]} {
	lappend optionList $opt
    }

    pcx::LOG {PCO Def '-$opt' :: <<$script>>}
    set replacement {}
    eval $script
    pcx::LOG {PCO Def '-$opt' :: ($replacement)}

    set optionDef($opt) $replacement
    return
}

proc checkerCmdline::add {args} {
    upvar 1 replacement r
    lappend r {*}$args
    return
}

proc checkerCmdline::ProcessOptions {av optionList odv} {
    variable dirlist
    variable usageStr
    upvar 1 $av argv $odv optionDef  errorMsg errorMsg \
	errorCode errorCode printCopyright printCopyright \
	preload preload quiet quiet explicitWlevel explicitWlevel \
	xref xref packages packages ping ping filesources filesources \
	recursing recursing machine machine version version

    pcx::LOG {PO <$argv>}
    while {[set err [cmdline::getopt argv $optionList opt arg]]} {

	pcx::LOG {PO handling <$opt> = ($arg) /$err}
	if {$err < 0} then {
	    append errorMsg "error: [cmdline::getArgv0]: " \
		    "$arg (use \"-help\" for legal options)"
	    set errorCode 1
	    break
	} else {
	    switch -exact $opt {
		? -
		h -
		help {
		    set errorMsg  $usageStr
		    set errorCode 0
		    break
		}
		logo {
		    # By modifying this variable in the projectInfo package
		    # we will suppress the logo information when we check
		    # out the license key.

		    set printCopyright 1
		}
		u -
		use {
		    # Specify which versions of a package to use, when
		    # loaded via [package require].

		    if {[catch {llength $arg}]} {
			set errorMsg  "invalid package name: \"$arg\""
			set errorCode 1
			break
		    }

		    # The argument can have one of two forms.
		    # <name>-<version>, or <name><version>.
		    # The dashed form is the same as accepted by
		    # TclApp's switch '-pkg'. The undashed form is the
		    # legacy form. In that form, and only there is the
		    # package name defined as the alpha chars up to
		    # but not including the first number.  The numbers
		    # after the package name must be a version number.
		    # Look for <name><major>.<minor>.<whatever>
		    # patterns.

		    if {![regexp {^([^-]+)(-([0-9]+(.[0-9]+)?).*)$} \
			    $arg dummy name verStr ver]} {
			if {![regexp {^([^0-9]+)(([0-9]+(.[0-9]+)?).*)$} \
				  $arg dummy name verStr ver]} {
			    set name   $arg
			    set verStr {}
			    set ver    {}
			}
		    }
		    ::pcx::use $name $ver
		    lappend preload $name $ver
		}
		ranges -
		range {
		    set ranges {}
		    foreach sub [split $arg ,] {
			set range [split $sub -]
			if {[llength $range] == 1} {
			    lassign $range s
			    set e $s
			    # Blow single-line range up to full range spec.
			    set range [list $s $e]
			} elseif {[llength $range] == 2} {
			    lassign $range s e
			} else {
			    set errorMsg "invalid range specification \"$sub\""
			    set errorCode 1
			    break
			}
			if {
			    (($s eq "") && ($e eq ""))      ||
			    ![string is integer $s] ||
			    ![string is integer $e]
			} {
			    set errorMsg "invalid range specification \"$sub\""
			    set errorCode 1
			    break
			}
			# Range is ok.
			lappend ranges $range
		    }
		    # Configure range filtering
		    filter::ranges $ranges
		}
		style-maxsleep {
		    # HACK. The option style-maxsleep is for
		    # Expect.pcx, yet we process it with the checker
		    # core command line. May need extensible command
		    # line options ? Options which go to specific
		    # packages ?
		    if {![string is integer -strict $arg]} {
			set errorMsg "invalid sleep value \"$arg\""
			set errorCode 1
			break
		    }
		    set configure::maxsleep $arg
		}
		indent {
		    if {![string is integer -strict $arg] || ($arg <= 1)} {
			set errorMsg "invalid indentation \"$arg\""
			set errorCode 1
			break
		    }
		    set configure::eindent $arg
		}
		as {
		    switch -exact -- $arg {
			dict {
			    set ::message::displayProc ::message::displayDict
			    set machine 1
			}
			script {
			    set ::message::displayProc ::message::displayScript
			    set machine 2
			}
			overview {
			    set ::message::displayProc ::message::displayTTY
			    set machine 0
			}
			default {
			    set errorMsg  "invalid output format \"$arg\""
			    set errorCode 1
			    break
			}
		    }
		}
		s -
		suppress {
		    # Ensure that argument is a proper Tcl list, and
		    # not empty.

		    if {[catch {llength $arg}] || ($arg eq "")} {
			set errorMsg  "invalid methodID \"$arg\""
			set errorCode 1
			break
		    }
		    filter::cmdlineSet 1 $arg
		}
		c -
		check {
		    # Ensure that argument is a proper Tcl list, and
		    # not empty.

		    if {[catch {llength $arg}] || ($arg eq "")} {
			set errorMsg  "invalid methodID \"$arg\""
			set errorCode 1
			break
		    }
		    filter::cmdlineSet 0 $arg
		}
		o -
		onepass {
		    analyzer::setTwoPass 0
		}
		q -
		quiet {
		    set quiet 1
		    analyzer::setQuiet 1
		}
		v -
		verbose {
		    analyzer::setVerbose 1
		}
		summary {
		    set configure::summary 1
		}
		W0 -
		W1 -
		W2 -
		W3 -
		W4 -
		Wa -
		Wall {
		    set explicitWlevel $opt
		}
		pcx {
		    # Extend PCX search path ...
		    pcx::search $arg
		    lappend dirlist $arg
		    LoadOptionDefinitions optionList optionDef
		}
		pcxdebug {
		    # pcxdebug is an internal, undocumented option. It
		    # activates lots of output for when loading a .pcx
		    # file goes wrong.
		    pcx::debug
		}
		xref {
		    set xref     1
		    set packages 0
		}
		ping {
		    set ping 1
		}
		packages {
		    set packages 1
		    set xref     0
		}
		V - -version {
		    # Can be executed if and only if 'hasversion' is set.
		    set msg "Tcl LINT $version"
		    if {[info exists ::tdk_feature]} {
			append msg " ($::tdk_feature)"
		    } else {
			# We know that license checking goes on, but
			# not exactly which license is asked for, as
			# that is hidden inside of 'parser'
			append msg " (license check active)"
		    }
		    puts stdout $msg
		    exit 0
		}
		@ {
		    if {
			![file exists   $arg] ||
			![file readable $arg]
		    } {
			set errorMsg  "invalid @file \"$arg\""
			set errorCode 1
			break
		    }

		    lappend filesources $arg
		}
		default {
		    if {![info exists optionDef($opt)]} {
			append errorMsg "error: [cmdline::getArgv0]: " \
			    "$arg (use \"-help\" for legal options)"
			set errorCode 1
			break
		    }

		    # This is a user-defined option
		    if {[info exists recursing($opt)]} {
			# And we are already processing it, so there
			# has to be a circle in the user-defined
			# options.
			append errorMsg "error: Circular option definition through [join [array names recursing] ", "]"
			set    errorCode 1
			return
		    }

		    # Recurse into the option definition. Mark the
		    # option as in use to detect circular definitions.
		    set recursing($opt) .
		    set suboptions $optionDef($opt)
		    ProcessOptions suboptions $optionList optionDef 

		    # Pop option from recursion memory.
		    unset recursing($opt)

		    pcx::LOG {PO done recursion ($errorCode)}
		    # The recursive call encountered errors, unwind
		    # the stack.
		    if {$errorCode > 0} return

		    # The calls was fine, continue to process the
		    # options after the user option.
		    pcx::LOG {PO done continue}
		    continue
		}
	    }
	}
    }

    return
}

# ### ######### ###########################
## Ready to use.

