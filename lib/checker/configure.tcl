# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# configure.tcl --
#
#	This file configures the analyzer by loading checkers and
#	message tables based on command line arguments.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2008-2009 ActiveState Software Inc.
#
# RCS: @(#) $Id: configure.tcl,v 1.17 2001/03/13 19:02:53 welch Exp $

# ### ######### ###########################
## Requisites

# ### ######### ###########################
## Implementation

namespace eval  configure {

    namespace export register 

    # The versions variable is an array and stores the requested
    # command line version and the default version of every package
    # being loaded in the checker.  The requested command line version
    # is keyed based on pkg name (e.g., $versions($pkg)) the 
    # default version is keyed based on pkg name and the string
    # "default" (e.g., $versions($pkg,default)).

    variable versions

    # Store a mapping from user specified package names to
    # Tcl package names.

    array set validPkgs {
	tcl 		coreTcl
	tk 		coreTk
	expect		expect
	incrTcl 	incrTcl
	tclX		tclX
    }


    #
    # Boolean flag for cross-reference mode. If activated no regular
    # output is produced. The checker collects only declarations,
    # definitions, and their usage, and then dumps this to stdout.
    #

    variable xref     0

    # Boolean flag which is relevant only if xref mode is active.
    # It generates a "." per command processed by the checker. This
    # should be used to drive user feedback, like a progressbar.

    variable ping     0

    variable packages 0

    # Flag set when output is machine-readable (-as-script, -as-dict)
    # 0 - human, 1 - dict, 2 - script

    variable machine 0

    # Flag set when output is only the summary.

    variable summary 0

    # User specified mtime information, or data for stdin.

    variable mtime {}

    # User specified md5 information for the provided file

    variable md5 {}

    # User specified file name for the data on stdin.

    variable stdin {}

    # Max. sleep value allowed before warnStyleSleep is issued.
    # HACK. This information is for Expect.pcx, yet we store it in the
    # checker core configuration. May need extensible command line
    # options ? Options which go to specific packages ?

    variable maxsleep 5

    # Max nesting level before a refactor style warning is issued.

    variable maxnesting 8

    # Dictionary of package and versions to load and activate before
    # scanning even starts. Sort of like 'package require' on the
    # command line. Initialized by checkerCmdline::init. Used by
    # 'packageSetup' below (load), and 'uproc::clear' in userproc.tcl
    # (activation).

    variable preload {}

    # Indentation to expect from commands (in multiples). 
    # The default value matches the Tcl Style Guide.

    variable eindent 4
}

# configure::packageSetup --
#
#	Based on command line arguments, load type checkers
#	into the analyzer.
#
# Arguments:
#	pkgArgs          The selected packages, which will be loaded.
#
# Results:
#	1 for success, 0 if the package setup failed

proc configure::packageSetup {} {
    variable preload
    ## We preload Tcl/Tk files as they are most used, and also internal to us.
    ## The Tcl definitions are activated later in 'uproc::clear'. Tk
    ## is activated through 'package require' in the scanned code,
    ## like all other packages.
    variable preloadTrouble {}

    foreach p {coreTcl.tcl} {
	if {[catch {
	    pcx::LoadPkgFile [file join $::checker::libdir $p]
	} msg]} {
	    puts $msg
	    return 0
	}
    }

    # Now preload the files for packages requested on the command
    # line. Ignore the internal ones, these were already done. In case
    # of trouble (no definition found) we do not abort, but keep the
    # info. The packages won't be loaded, and a bit in the future fake
    # 'pkgUnchecked' messages will be generated.

    set tmp {}

    foreach {n v} $preload {
	if {$n in {Tcl Tk}} continue
	if {[catch {
	    pcx::load $n
	} msg]} {
	    # Note: Keep pattern in sync with the code in 'pcx::load'
	    # generating the message.
	    if {[string match {No checker for package * available.} $msg]} {
		# Keep info about the troubles around.
		lappend preloadTrouble $msg
		continue
	    }
	    return -code error $msg
	}
	lappend tmp $n $v
    }

    # Cut out the packages which gave us trouble above.
    set preload $tmp

    return 1
}

# configure::setFilter --
#
#	This sets the filter array that determines what
#       kind of warnings are displayed.
#
# Arguments:
#	filter	The filter string, or W1, W2, W3, Wa or Wall. The
#               W* strings are predefined filters commonly used.
#
# Results:
#	The side effect is, if the package name does not exist in
#	versions array, the version is added to the array.

proc configure::setFilter {filter} {

    filter::clearFilters
    switch -- $filter {
        {W1} {
            # filter all warnings.
	    filter::addFilters {warn nonPortable performance upgrade usage}
        }
        {W2} {
	    # filter aux warnings.
	    filter::addFilters {warn nonPortable performance upgrade}
        }
        {W3} -
        {Wa} -
        {Wall} {
            # filter nothing.
        }
        {default} {
	    filter::addFilters $filter
        }
    }
}

# configure::setSuppressors --
#
#	This sets the array that determines what message
#       ids are displayed.
#
# Arguments:
#	mids	The message id's to suppress.
#
# Results:
#	None.

proc configure::setSuppressors {mids} {

   filter::clearSuppressors
   filter::addSuppressor $mids
}

# configure::register --
#
#	This is the well-known procedure that each analyzer
#	package calls to tell the analyzer that it's package
#	needs to be loaded into the analyzer's checker.
#
# Arguments:
#	name	The name of the analyzer package.
#	ver	The default version of the analyzer package.
#
# Results:
#	The side effect is, if the package name does not exist in
#	versions array, the version is added to the array.

proc configure::register {name ver} {
    variable versions
    variable validPkgs

    # Map the extension name to the same package name if a mapping isn't
    # already established.

    if {![info exists validPkgs($name)]} {
	set validPkgs($name) $name
    }

    set versions($name,default) $ver
    return
}

# configure::errorVerConflicts --
#
#	Print the error message for version conflicts.
#
# Arguments:
#	pkg	The name of the package.
#	ver	The version requested for the package,
#		"" if no specific version was requested.
#	tclVer	The version requested for the Tcl package.
#
# Results:
#	None.

proc configure::errorVerConflicts {pkg ver tclVer} {
    switch $pkg {
	coreTcl {
	    set message "Can't run Tcl $ver"
	}
	coreTk {
	    set message "Can't run Tk $ver with Tcl $tclVer"
	}
	default {
	    set message "Can't run $pkg $ver with Tcl $tclVer"
	}
    }
    Puts "Error: $message"
    Puts "See $::projectInfo::usersGuide for compatible versions."
    return
}

# configure::humanList --
#
#	Convert a Tcl List to a list separated by commas and
#	and a final "and" or "or" keyword.
#
# Arguments:
#	tclList		The Tcl List to convert.
#	ending		The final ending keyword.
#
# Results:
#	A human readable list.

proc configure::humanList {tclList ending} {
    if {[llength $tclList] == 1} {
	return [lindex $tclList 0]
    }
    set result {}
    while {1} {
	set element [lindex $tclList 0]
	if {[llength $tclList] > 1} {
	    append result "$element, "
	} else {
	    append result "$ending $element"
	    break
	}
	set tclList [lrange $tclList 1 end]
    }
    return $result
}

# ### ######### ###########################
## Ready to use.

package provide configure 1.0
