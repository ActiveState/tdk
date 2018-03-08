# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# userproc.tcl --
#
#	This file contains routines for storing and retrieving
#	user-defined procs.
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
# Copyright (c) 1998-2000 Ajuba Solutions

#
# SCCS: %Z% %M% %I% %E% %U%

# ### ######### ###########################

# Rewrite of command database visible to the system at large. Now
# maintains:
#
# - one database per file, for builtins (tcl + package require)
# - one global database of all user defined procedures
# - one global database for all commands
#
# The user defined procedures are collected during the scan phase and
# spread to all file-specific databases during collation, as part of
# the resolution of imported and renamed commands. The second global
# database is maintained iff cross-reference data is collected.

# ### ######### ###########################

package require cdb ; # Basic command database functionality.
package require pcx ; # PCX api

namespace eval uproc {
    # ### ######### ###########################

    cdb all ; # All commands.

    # ### ######### ###########################
}

# uproc::setfile --
#
#	Called before the scanning or analysis of a file starts,
#	ensures that the proper command database is used for
#	checking.
#
# Arguments:
#	fname	The path to the current file.
#
# Results:
#	None.

proc uproc::setfile {fname} {
    return
}

# uproc::clear --
#
#	Part of analyzer initialization. Ensures that all the
#	databases are empty.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc uproc::clear {} {
    variable file

    all clear

    # Bugzilla 34988.
    # Influence chosen version by -use option, or other. Load core
    # commands into the full database. This has to be done only once,
    # which is the reason for placing it here. The file specific
    # databases are initialized in 'uproc::start', see below.

    set userRecommends [::pcx::useRequest Tcl]
    if {$userRecommends != {}} {
	if {[::pcx::supported coreTcl $userRecommends]} {
	    pcx::require coreTcl $userRecommends uproc::all uproc::__vardb__
	    preActivate
	    return
	}

	Puts "Falling back to Tcl $::projectInfo::baseTclVers, user asked for unsupported version $userRecommends."
    }

    pcx::require coreTcl $::projectInfo::baseTclVers uproc::all uproc::__vardb__
    preActivate
    return
}

proc uproc::preActivate {} {
    variable ::configure::preload
    # Now handle any other user-requested packages
    foreach {n v} $preload {
	#puts <<Activate|$n|$v>>
	if {$n eq "Tcl"} continue
	# v = pcx::useRequest $n. Same data. Ensured by
	# checkerCmdline::init using by configure::preload and
	# pcx::use to store the data. Ignore packages already active,
	# and those for which we have good version.

	set chkPkg [::pcx::checkerOf $n]
	if {[::pcx::isActive $chkPkg chkVers]} continue

	set chkVers [coreTcl::GetPkgCheckerVersion $n $chkPkg $v 0 {}]
	#puts <<\t\ \ |$chkPkg|$chkVers>>
	if {$chkVers eq ""} continue

	::pcx::require $chkPkg $chkVers uproc::all uproc::__vardb__
	#puts <<Ok>>
    }
    return
}


proc uproc::__vardb__ {cmd var} {
    # ASSERT (cmd eq "declare")
    #puts stderr vdb/decl/$var
    xref::varDefAbsolute local $var
    return
}

# uproc::start --
#
#	Part of analyzer initialization. Load current database
#	(= for current file) with core definitions.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc uproc::start {} {
    ## TODO ## Influence chosen version by -use option, or other.
    #variable current
    #pcx::use coreTcl $::projectInfo::baseTclVers $current {}
    return
}

# ### ######### ###########################

# uproc::add --
#
#	Called after a complete user defined proc has been defined.
#
# Arguments:
#	pInfo	The fully specified proc info type.
#
# Results:
#	None.  The proc info is added to the user proc database,
#	the user proc counter is incremented for the proc name
#	and the context is added to the context database.

proc uproc::add {pInfo strip} {
    # Procedure definitions go into 'proc', regardless of the current
    # file. It is also recorded in the full database (all). This makes
    # the collation step easier as we can be sure where we will find
    # all commands. This code is called only during the scan phase.

    all add $pInfo $strip
    return
}

# uproc::isRedefined --
#
#	Check to see if the proc has been defined more than once.  If
#	so, then log an error.  This can happen if; there are multiple
#	definiions of the same proc or class; a class has the same
#	name as a proc; or procs are imported, renamed or inherited.
#
# Arguments:
#	name		The fully qualified class or proc name.
#	thisType	The type of proc being defined (proc or class)
#
# Results:
#	None.  An error is logged if there are multiple definitions
#	for the same class or proc name.

proc uproc::isRedefined {name thisType} {
    all isRedefined $name $thisType
    return
}

# uproc::searchThisContext --
#
#	Search the user-defined proc database for the
#	existence of context and pattern, where pattern
#	will only match procs in the current context.
#
# Arguments:
#	context		The base context to begin looking.
#	pattern		The pattern to query in this context only.
#
# Results:
#	The entries in the database that exist.

proc uproc::searchThisContext {context pattern} {
    return [all searchThisContext $context $pattern]
}

# uproc::exists --
#
#	Determine if the procName exists at the current context
#	or any parent of the current context.  If so set the
#	infoVar variable to contain the list of procInfo types.
#
# Arguments:
#	context		The base context to begin looking.
#	name		The name of the user proc.
#	pInfoVar	The variable that will contain the procInfo
#			list, if it exists.
#
# Results:
#	Boolean, 1 if the proc exists.

proc uproc::exists {context name pInfoVar} {
    upvar 1 $pInfoVar pInfo

    set res [all exists $context $name pInfo]
    return $res
}

proc uproc::pushCheck {cmdName cmd isscan} {
    return [all pushCheck $cmdName $cmd $isscan]
}

proc uproc::popCheck {cmdName isscan} {
    return [all popCheck $cmdName $isscan]
}

proc uproc::record {ctx name data} {
    return [all record $ctx $name $data]
}

## Return the database of commands and their usage.

proc uproc::dump {} {
    return [all dump]
}

proc uproc::resolve {context name} {
    return [all resolve $context $name]
}

proc uproc::locateCallers {cmd level} {
    # Only procedures can call a command doing an upvar.
    # Therefore we can restrict the search to the user
    # defined procedures.

    return [all locateCallers $cmd $level]
}

proc uproc::locateScopes {cmdlist} {
    # Only procedures can call a command doing an upvar.
    # Therefore we can restrict the search to the user
    # defined procedures.

    return [all locateScopes $cmdlist]
}

# ### ######### ###########################
## Public API. Collation and transfer of command definitions.

# uproc::collate --
#
#	Collate the namespace import and export commands and
#	add any imported commands to the various command databases.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc uproc::collate {inVar reVar exVar imVar} {
    upvar 1 $inVar inheritCmds
    upvar 1 $reVar renameCmds
    upvar 1 $exVar exportCmds
    upvar 1 $imVar importCmds

    #  I. Export and import of commands.
    #     The basic database we operate on is 'all', as this
    #     information is cross-file. The file-specific databases are
    #     updated in parallel by copying the relevant definitions over
    #     into them.
    #
    # II. User defined commands.
    #     This is easy. The contents of 'procs' are copied to all
    #     file-specific databases.

    # Foreach context that imports a proc (i.e., namespace import,
    # inherit, or rename), import all of the procs into the import
    # context from specified export context.  Do a transitive
    # closure searching until there are no more commands to be
    # imported.  This is important because one cycle of importing
    # may add new commands to a context that should have been
    # imported to a different context.

    # ### ######### ###########################
    #parray importCmds
    #parray exportCmds

    set search 1
    while {$search} {
	set search 0

	# Import the list of commands that have been renamed.

	foreach rename [array names renameCmds] {
	    foreach {srcCmd dstCmd} $renameCmds($rename) {}
	    set search [all copyUserProc $dstCmd $srcCmd renamed]
	}

	# Import all of the commands that have been imported
	# or exported from a namespace.

	foreach impCtx [array names importCmds] {
	    foreach impPat $importCmds($impCtx) {
		#puts stderr "EXPORT FOR ($impPat): \{[uproc::getExportedCmds $impCtx $impPat exportCmds]\}"

		foreach expCmd [uproc::getExportedCmds $impCtx $impPat exportCmds] {
		    set name   [namespace tail $expCmd]
		    set impCmd [context::join $impCtx $name]
		    set search [all copyUserProc $impCmd $expCmd imported]
		    #puts stderr "\tImported definition $impCmd"
		}
	    }
	}

	# Import all of the public or protected class procs from all
	# base classes into the derived class.  Although there can be
	# only one inherit call per class, we have to handle the case
	# where a class is deleted and recreated.  Therefore we could
	# have multiple inheritance lists.  Make a union of all of
	# the inherited class procs.

	foreach drvClass [array names inheritCmds] {
	    foreach baseClasses $inheritCmds($drvClass) {
		foreach baseCmd [uproc::getInheritedCmds \
			$drvClass $baseClasses] {
		    set name   [namespace tail $baseCmd]
		    set drvCmd [context::join $drvClass $name]
		    set search [all copyUserProc $drvCmd $baseCmd inherit]
		}
	    }
	}
    }

    # ### ######### ###########################
    return
}


# uproc::getExportedCmds --
#
#	Given an import context and an import pattern, compile
#	a list of commands that will be imported into the import
#	context.
#
# Arguments:
#	impCtx		The import context.
#	impPat		The import pattern.
#
# Results:
#	A list of commands to import into the import context.

proc uproc::getExportedCmds {impCtx impPat exportCmdsVar} {
    upvar 1 $exportCmdsVar exportCmds

    set expCtx  [context::locate $impCtx $impPat]
    if {![info exists exportCmds($expCtx)]} {
	return
    }

    set impPat  [namespace tail $impPat]
    set impCmds [all searchThisContext $expCtx $impPat]

    set result {}
    foreach expPat $exportCmds($expCtx) {
	foreach expCmd [all searchThisContext $expCtx $expPat] {
	    # Add the command if it exists in the import pattern
	    # list and does not already exist in the result list.

	    # AK: Should this be -exact ? If yes, we can switch to in/ni as well.
	    set qualExpCmd [context::join $expCtx $expCmd]
	    if {([lsearch $impCmds $qualExpCmd] >= 0) \
		    && ([lsearch $result $qualExpCmd] < 0)} {
		lappend result $qualExpCmd
	    }
	}
    }
    return $result
}

# uproc::getInheritedCmds --
#
#	Given an ordered list of base classes to inherit, create a
#	list of public and protected commands that should be
#	inherited (imported.)
#
# Arguments:
#	drvClass	The derived class.
#	baseClasses	The ordered list of base classes to inherit.
#
# Results:
#	A list of quialified proc names to inherit into the derived
#	class.

proc uproc::getInheritedCmds {drvClass baseClasses} {
    # Search the list in reverse order clobbering commands that
    # appear first.  This is done to maintain the correct inheritance
    # hierarchy.

    set context [context::head $drvClass]

    for {set i [expr {[llength $baseClasses] - 1}]} {$i >= 0} {incr i -1} {
	set baseClass [lindex $baseClasses $i]
	set baseClass [context::locate $context $baseClass 0]
        foreach baseCmd [all searchThisContext $baseClass "*"] {
	    set cmds([namespace tail $baseCmd]) $baseCmd
	}
    }

    # Take the flatten list of procs and make a list of the fully
    # qualified command names.

    set result {}
    foreach {tail cmd} [array get cmds] {
	lappend result $cmd
    }
    return $result
}

# ### ######### ###########################
## Ready to go.

package provide userproc 1.0
