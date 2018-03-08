# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# cdb.tcl -- -*- tcl -*-
#
#	This file contains a class implementing a command database.
#
# Copyright (c) 2003-2008 ActiveState Software Inc.
# Copyright (c) 1998-2000 Ajuba Solutions

#
# SCCS: %Z% %M% %I% %E% %U%

# ### ######### ###########################
## Requisites

package require Tcl 8.5
package require snit     ; # Object system
package require analyzer ; # Command scanning and analysis
package require xref     ; # Variable tracking.

# ### ######### ###########################
## Implementation

snit::type cdb {
    # ### ######### ###########################

    constructor {args} {
	#$self configurelist $args
	array set def      {}
	array set defCount {}
	array set defMap   {}
	return
    }

    # ### ######### ###########################
    ## Public API. 

    method clear {} {
	unset def      ; array set def      {}
	unset defCount ; array set defCount {}
	unset defMap   ; array set defMap   {}
	return
    }

    # add --
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

    method add {pInfo strip {tracknew 0}} {
	# Add the proc info is the exact pInfo type does not already
	# exist in the database.

	set new 0
	set name [$type getName $pInfo]

	if {[$self IndexProcInfo $name $pInfo] < 0} {
	    $self AddDefinition $name $pInfo
	    set new 1
	}

	# Keep track of how many times this command is redefined.
	# This is used by the isRedefined routine to log warnings
	# if a class or proc defined more than once.

	# When tracking we only do this if this is a newly copied
	# command, because the algorithm for collating will call this
	# twice to perform the transitive closure of all imports,
	# inherits and renames.

	if {!$tracknew || $new} {
	    if {![info exists defCount($name)]} {
		set defCount($name) 1
	    } else {
		incr defCount($name)
	    }
	}

	# Add the context to the list of known contexts.

	if {$strip} {
	    context::add [context::head $name]
	} else {
	    context::add $name
	}
	return
    }

    method addMany {defs strip} {
	foreach pInfo $defs {
	    $self add $pInfo $strip 1
	}
	return
    }

    # copyUserProc --
    #
    #	Copy proc info from one context to another.
    #
    # Arguments:
    #	impCmd		The fully qualified command name to import.
    #	expCmd		The fully qualified command name to export.
    #	type		A descriptor type for the new proc.
    #
    # Results:
    #	Return 1 if a proc was imported, return 0 if the exact
    #	proc info already existed.

    method copyUserProc {impCmd expCmd {ptype {}}} {
	# If no info exists for the exported proc, then the exported
	# proc has not been defined.  Return 0 and do nothing.

	if {![info exists def($expCmd)]} {
	    return 0
	}

	set new 0
	foreach pInfo $def($expCmd) {
	    # Update the pInfo so the info reflects it's new name and
	    # scope.  If <type> is not empty then copy the new type
	    # into the pInfo.  Then, replace the qualified exported
	    # name with the qualified imported name and the base name
	    # with the exported name.

	    if {$ptype != {}} {
		set pInfo [$type setType $pInfo $ptype]
	    }
	    # Remember the original name for xref-tracking
	    array set _   $pInfo
	    set _(origin) $_(name)
	    set pInfo [array get _]

	    set pInfo [$type setName $pInfo $impCmd]

	    ## Actually there is no need for this. The base
	    ## is already computed and set during command
	    ## definition.
	    set pInfo [$type setBase $pInfo [context::head $expCmd]]


	    # If the pInfo type does not currently exist in the import
	    # context, copy the pInfo type from the export context to
	    # the import context.

	    if {[$self IndexProcInfo $impCmd $pInfo] < 0} {
		$self AddDefinition $impCmd $pInfo cpy
		set new 1
	    }

	    # Keep track of how many times this command is redefined.
	    # This is used by the isRedefined routine to log warnings
	    # if a class or proc defined more than once.  Only do this
	    # if this is a newly copied command, because the algorithm
	    # for collating will call this twice to perform the transitive
	    # closure of all imports, inherits and renames.

	    if {$new} {
		if {![info exists defCount($impCmd)]} {
		    set defCount($impCmd) 1
		} else {
		    incr defCount($impCmd)
		}
	    }
	}
	return $new
    }

    # isRedefined --
    #
    #	Check to see if the proc has been defined more than once.  If
    #	so, then log an error.  This can happen if; there are multiple
    #	definitions of the same proc or class; a class has the same
    #	name as a proc; or procs are imported, renamed or inherited.
    #
    # Arguments:
    #	name		The fully qualified class or proc name.
    #	thisType	The type of proc being defined (proc or class)
    #
    # Results:
    #	None.  An error is logged if there are multiple definitions
    #	for the same class or proc name.

    method isRedefined {name thisType} {
	# This is a tricky algorithm.  We want to report exactly why the
	# proc or class was redefined to provide the best feedback.  For
	# example, was the proc redefined because an identically named
	# proc was imported from another namespace or renamed to the same
	# name.  The only context we have is that this is a new proc or
	# class about to be defined.  We cannot determine which pInfo
	# type in the list this proc is referring to.  So to provide the
	# best feedback possible we have the following heuristic:
	# (1) Do not report this proc or class if redefined by itself, so
	#     skip the first pInfo type that matches thisType.
	# (2) Do not report redefinitions for inherited commands.  This
	#     is standard behavior for incr Tcl.
	# (3) Report all other types.

	if {[info exists defCount($name)] && ($defCount($name) > 1)} {
	    set skipped  0
	    set thisFile [analyzer::getFile]
	    set thisLine [analyzer::getLine]

	    foreach pInfo $def($name) {
		set ptype [$type getType $pInfo]
		set file  [$type getFile $pInfo]
		set line  [$type getLine $pInfo]

		if {($ptype == $thisType) && ($file == $thisFile) \
			&& ($line == $thisLine) && (!$skipped) \
			&& ([llength $def($name)] > 1)} {
		    set skipped 1
		    continue
		}

		if {$ptype eq "inherit"} {
		    continue
		} elseif {$ptype eq "class"} {
		    logError warnRedefine {} $thisType $name "class" $file $line
		} elseif {$ptype eq "renamed" || $ptype eq "imported"} {
		    logError warnRedefine {} $thisType $name "$ptype proc" \
			    $file $line
		} else {
		    logError warnRedefine {} $thisType $name "proc" \
			    $file $line
		}
	    }
	}
	return
    }

    # searchThisContext --
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

    method searchThisContext {context pattern} {
	set result {}
	foreach name [array names def [context::join $context $pattern]] {
	    if {![string match [context::join $context *::*] $name]} {
		lappend result [list $name]
	    }
	}
	return $result
    }

    # exists --
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

    method exists {context name pInfoVar} {
	upvar 1 $pInfoVar pInfo

	# Attempt to locate the proc by looking in the concatenated
	# context of the <context> and any context defined in
	# <name>.

	# Note: The context UNKNOWN is accepted like any other regular
	# namespace. It is the dumping ground for procedures defined
	# in a dynamically named namespace. Having the procs there
	# instead is better, gives us a small modicum of
	# checkability.

	# The old way was to have the procedures all named UNKNOWN,
	# giving rise to a deluge of bogus warnRedefine warnings,
	# and/or bogus procNumArgs errors because no command was found
	# while parsing a dynamic namespace.

	# See analyzer::addUserProc for the place where the command
	# name is added in, and 'context::join' for the place which
	# was actually changed.

	set context [context::locate $context $name]

	#puts stderr "$self exists => ctx ($context) for '$name'"

	if {($context ne "")} {
	    set proc [context::join $context [namespace tail $name]]

	    #puts stderr "$self exists => proc ($proc)"

	    if {[info exists def($proc)]} {
		set pInfo $def($proc)

		#puts stderr "\t\t\t\t\t\t\tYES"
		return 1
	    }
	}

	# The concatenated context does not exist or the proc does
	# not exist in that context, look in the global context.

	set proc [context::join :: $name]

	#puts stderr "$self exists => proc ($proc)"

	if {[info exists def($proc)]} {
	    set pInfo $def($proc)
	    #puts stderr "\t\t\t\t\t\t\tYES"
	    return 1
	} else {
	    # The user proc is not defined in the local or global context.

	    #puts stderr "\t\t\t\t\t\t\tNO"
	    return 0
	}

	#puts stderr "\t\t\t\t\t\t\tIMPOSSIBLE/3"
    }

    method definitions {cmd} {
	if {![info exists def($cmd)]} {
	    return {}
	} else {
	    return $def($cmd)
	}
    }

    method names {} {
	return [array names def]
    }


    method resolve {context name} {
	# Attempt to locate the proc by looking in the concatenated
	# context of the <context> and any context defined in <name>.
	#
	# NOTE: The command we are looking for might be defined in a
	# file which will be scanned after the current one. So.
	#
	# If the name is already FQN, i.e. absolute, we take that as
	# the cmd name.
	#
	# Otherwise we look for a definition, and if found, take
	# that.
	#
	# At last, i.e. if no definition was found, we resolve it as
	# local command, local to the current namespace.

	if {[string match "::*" $name]} {
	    #puts stderr "\t\t\t\t\t\t\tFQN"
	    return $name
	}

	set context [context::locate $context $name]

	#puts stderr "$self resolve => ctx ($context)"

	if {$context != {}} {
	    set procL [context::join $context [namespace tail $name]]

	    #puts stderr "$self resolve => proc ($procL)"

	    if {[info exists def($procL)]} {
		#puts stderr "\t\t\t\t\t\t\tYES"
		return $procL
	    }
	} else {
	    # The name likely has a broken context, or similar (single :).
	    set procL $name
	}

	# The concatenated context does not exist or the proc does
	# not exist in that context, look in the global context.

	set proc [context::join :: $name]

	#puts stderr "$self resolve => proc ($proc)"

	if {[info exists def($proc)]} {
	    #puts stderr "\t\t\t\t\t\t\tYES"
	    return $proc
	} else {
	    # No definition found for the command, in neither local
	    # nor global context.

	    # We now assume that this is a local command.

	    #puts stderr "\t\t\t\t\t\t\tNO"
	    #puts stderr "XXX|$context|$name|"
	    return $procL
	}

	#puts stderr "\t\t\t\t\t\t\tIMPOSSIBLE/3"
	return {}
    }

    method locateScopes {cmdlist} {
	#puts stderr "locateScopes $cmdlist"

	set result [list]
	foreach cmd $cmdlist {
	    if {[info exists def($cmd)]} {
		foreach d $def($cmd) {
		    array set _ $d
		    #parray _
		    if {[string equal $_(type) proc]} {
			set loc [list $_(file) $_(line) $_(cmdrange)]
			lappend result [list proc $cmd $loc]
		    }
		    unset _
		}
	    }
	}

	#puts stderr "locateScopes $cmdlist /return ($result)"
	return $result
    }

    method pushCheck {cmdName cmd isscan} {
	#puts stderr push...over\n\t[join [array names def] \n\t]\n...........|

	set cmdName ::[string trim $cmdName :]

	if {![info exists def($cmdName)]} {
	    # Create a new entry ... (No package information)

	    #puts stderr ...new.../$cmdName/$cmd/$isscan

	    if {$isscan} {
		set new [$type newBuiltinInfo {} $cmdName {} $cmd]
	    } else {
		set new [$type newBuiltinInfo {} $cmdName $cmd {}]
	    }
	    set def($cmdName) [list $new]
	} else {
	    # Push the new checker into all existing pInfo's for the
	    # command.

	    #puts stderr ...old/push.../$cmdName/$cmd/$isscan

	    set res [list]
	    foreach pInfo $def($cmdName) {
		lappend res [$type PushCmd $pInfo $cmd $isscan]
	    }
	    set def($cmdName) $res
	}
    }

    method popCheck {cmdName isscan} {
	#puts pop...$cmdName

	set cmdName ::[string trim $cmdName :]

	if {![info exists def($cmdName)]} {
	    #puts ignore-unknown
	    # Ignore the request for non-existing command.
	    return
	}

	# Pop the checker from all existing pInfo's for the
	# command. Remove all pInfo's where the checkcmd is empty.
	# Remove the command from the database if there are no
	# pInfo's left.

	set res [list]
	foreach pInfo $def($cmdName) {
	    array set _ [set new [$type PopCmd $pInfo $isscan]]
	    if {$_(checkcmd) != {}} {
		lappend res $new
	    }
	}

	if {[llength $res] > 0} {
	    set def($cmdName) $res
	} else {
	    unset def($cmdName)
	    foreach k [array names defMap $cmdName,*] {
		unset defMap($k)
	    }
	}
    }

    method record {ctx name data} {
	## Extend the shared database of command usage information.

	#puts stderr CDB|record|$ctx|$name|$data|

	set cmd [$self resolve $ctx $name]

	#puts stderr CDB|record|=|$cmd|

	if {
	    ![info exists use($cmd)] ||
	    ($data ni $use($cmd))
	} {
	    lappend use($cmd) $data
	}
	return
    }

    method dump {} {
	## Return the database of commands and their usage.
	return [list [array get def] [array get use]]
    }

    method locateCallers {cmd level} {
	#puts stderr "locateCallers $cmd $level"

	if {$level <= 0} {
	    #puts stderr "locateCallers $cmd $level /0/return ($cmd)"
	    return $cmd
	} elseif {$level == 1} {
	    # Find direct callers of 'cmd'
	    #parray use

	    if {![info exists use($cmd)]} {
		#puts stderr "locateCallers $cmd $level /1/return ()"
		return {}
	    }
	    set result [list]
	    foreach d $use($cmd) {
		array set _ $d
		if {
		    [info exists _(scope)] &&
		    [string equal proc [lindex $_(scope) 0]]
		} {
		    lappend result [lindex $_(scope) 1]
		}
		unset _
	    }
	    #puts stderr "locateCallers $cmd $level /2/return ($result)"
	    return $result
	} else {
	    # Find all callers a level less and then their
	    # callers ...

	    incr level -1
	    set result [list]
	    foreach clist [$self locateCallers $cmd $level] {
		foreach c $clist {
		    foreach cc [$self locateCallers $c 1] {
			lappend result $cc
		    }
		}
	    }

	    #puts stderr "locateCallers $cmd $level /3/return ($result)"
	    return $result
	}
    }

    # ### ######### ###########################
    ## Internal. Data structures

    # Stores the set of procedures defined by the users.  The
    # fully qualified proc or class name is the array entry and
    # the value is a list of proc info data types that contains
    # information about max and min number of args, protection
    # level, type data, etc.  Note: Duplicate entries are removed
    # so the collation step and checking for redefined procs are
    # handled correcly.

    # TDK 3.0
    # NEW - Stores the definitions for __all__ commands the checker
    #       knows about.
    #
    # NEW - The value is not a simple list anymore, but a dictionary
    #       (more extensible). See the old/new mapping below. Old
    #       lists the numeric index of the information, new the dict
    #       key created for it. Not all data will be used by all types.
    #
    # Old	New		Notes
    # ---	---		-----
    #  0	name
    #  1	base
    #  2	hasarg		Not used for 'builtin'.
    #  3	minargno	Not used for 'builtin'.
    #  4	maxargno	Not used for 'builtin'.
    #  5	protection
    #  6	type		New: builtin
    #  7	file
    #  8	line
    #  9	verifycmd
    # 10	checkcmd
    #  -	cmdrange	New, complete range of command definition, not for 'builtin'.
    # ---	---		-----

    variable  def

    # This array is keyed by command name and serialized pInfo
    # for a fast check if a definition is already present. This
    # array is changed in 'AddDefinition', and queried by
    # 'IndexProcInfo'.

    variable  defMap

    # User Proc Counter --
    # Store the number of times a class or proc is redefined.
    # This is used by the isRedefined routine to determine if
    # a proc or class was redefined.  The llength of the entry
    # in the def array cannot be used because duplicates
    # are removed from the list.

    variable  defCount

    # ### ######### ###########################
    ## Internal. Helper methods.

    # IndexProcInfo --
    #
    #	Find the index of pInfo in the list of pInfo types.
    #
    # Arguments:
    #	name	The fully qualified name of the proc or class.
    #	pInfo	The associated pInfo type.
    #
    # Results:
    #	Return an index into the list if a match is found or
    #	-1 if no match is found.

    method IndexProcInfo {name pInfo} {
	if {[info exists def($name)]} {
	    # We cannot use lsearch here anymore. A dict is not sorted,
	    # meaning that internally identical dicts may have differing
	    # string representations. The other reason is that the pInfo's
	    # may contain xref data which is not relevant to the search,
	    # but would be used by lsearch nevertheless.
	    #
	    # We are serializing pInfo to get the old format, then looking
	    # index for this up in the side db.

	    set serial [$type Serial $pInfo]
	    if {[info exists defMap($name,$serial)]} {
		return $defMap($name,$serial)
	    } else {
		return -1
	    }
	} else {
	    return -1
	}
    }

    method AddDefinition {name pInfo {reason add}} {
	if {[catch {set idx [llength $def($name)]}]} {
	    set idx 0
	}
	set     defMap($name,[$type Serial $pInfo]) $idx
	lappend def($name) $pInfo

	#puts stderr "UPR $reason ($name) => ($pInfo)"
	#parray defMap
	return
    }

    # ### ######### ###########################
    ## Internal. Serialization of a pInfo structure

    typemethod Serial {pInfo} {
	array set _ $pInfo

	set res [list]
	foreach k {
	    name base hasarg minargno maxargno protection type file line
	    verifycmd checkcmd
	} {
	    lappend res $_($k)
	}
	return $res
    }

    # ### ######### ###########################
    ## Internal. Create modified clones of a list of definitions.

    typemethod clone {impCmd defs ptype} {
	set res [list]
	foreach pInfo $defs {
	    # Update the pInfo so the info reflects it's new name and
	    # scope.  If <type> is not empty then copy the new type
	    # into the pInfo.  Then, replace the qualified exported
	    # name with the qualified imported name and the base name
	    # with the exported name.

	    if {$ptype != {}} {
		set pInfo [$type setType $pInfo $ptype]
	    }
	    # Remember the original name for xref-tracking
	    array set _   $pInfo
	    set _(origin) $_(name)
	    set pInfo [array get _]

	    set pInfo [$type setName $pInfo $impCmd]

	    lappend res $pInfo
	}
	return $res
    }

    # ### ######### ###########################
    ## Internal. Generation, access, and manipulation of pInfo
    ## structures.

    # newProcInfo --
    #
    #	Create a new proc info type.  Note: Much of the info that
    #	composes a pInfo is retrieved from the system.  The
    #	context protection stack, current file and current line
    #	number must be up to date and accessable.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Return a new proc info opaque type.

    typemethod newProcInfo {} {
	return [list \
		name       {} \
		base       {} \
		hasarg     0 \
		minargno   -1 \
		maxargno   -1 \
		protection [context::topProtection] \
		type       proc \
		file       [analyzer::getFile] \
		line       [analyzer::getLine] \
		verifycmd  analyzer::verifyUserProc \
		checkcmd   analyzer::checkUserProc \
		cmdrange   [analyzer::getCmdRange] \
		]
    }

    typemethod newBuiltinInfo {package name cmd {scancmd {}}} {
	array set _  [$type newProcInfo]
	set _(base) [context::head $name]
	set _(name) $name
	set _(type) builtin
	set _(verifycmd) {}
	set _(package) $package

	if {$cmd == {}} {
	    set _(checkcmd) {}
	} else {
	    #puts stderr "UPR CHECK ($name) $cmd"
	    set _(checkcmd) [list ::analyzer::checkBuiltinCmd $cmd]
	}
	if {$scancmd == {}} {
	    set _(scancmd) {}
	} else {
	    #puts stderr "UPR SCAN ($name) $scancmd"
	    set _(scancmd) [list ::analyzer::checkBuiltinCmd $scancmd]
	}

	# Squash information not relevant to builtins like this,
	# or set empty data for non-optional fields.

	unset _(cmdrange)
	set   _(file) {}
	set   _(line) {}

	return [array get _]
    }

    # getName --
    #
    #	Get the fully qualified name of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	The name of the proc.

    typemethod getName {pInfo} {
	array set _ $pInfo
	return $_(name)
    }

    # setName --
    #
    #	Set the fully qualified name for the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	name	The new proc name.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setName {pInfo name} {
	array set _ $pInfo
	set _(name) $name
	return [array get _]
    }

    # getBase --
    #
    #	Get the fully qualified base context where this
    #	proc originated from.  This will be an empty
    #	string unless the proc was renamed, imported or
    #	inherited.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	The name of the base context of empty string if one doesnt exist.

    typemethod getBase {pInfo} {
	array set _ $pInfo
	return $_(base)
    }

    # setBase --
    #
    #	Set the base context of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	base	The new proc name.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setBase {pInfo base} {
	array set _ $pInfo
	set _(base) $base
	return [array get _]
    }

    # getDef --
    #
    #	Get the boolean indicating if the argList was defined.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	Return the boolean value to determine if the argList was defined.

    typemethod getDef {pInfo} {
	array set _ $pInfo
	return $_(hasarg)
    }

    # setDef --
    #
    #	Set the defined boolean indicating if the args list was validly
    #	defined of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	def	The new defined boolean.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setDef {pInfo def} {
	array set _ $pInfo
	set _(hasarg) $def
	return [array get _]
    }

    # getMin --
    #
    #	Get the minimum number of args allowable of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	The minimum number of args for this proc.

    typemethod getMin {pInfo} {
	array set _ $pInfo
	return $_(minargno)
    }

    # setMin --
    #
    #	Set the minimum number of args allowable of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	min	The minimum number of allowable args.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setMin {pInfo min} {
	array set _ $pInfo
	set _(minargno) $min
	return [array get _]
    }

    # getMax --
    #
    #	Get the maximum number of args allowable of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	The maximum number of args for this proc.

    typemethod getMax {pInfo} {
	array set _ $pInfo
	return $_(maxargno)
    }

    # setMax --
    #
    #	Set the maximum number of args allowable of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	max	The maximum number of allowable args.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setMax {pInfo max} {
	array set _ $pInfo
	set _(maxargno) $max
	return [array get _]
    }

    # getProt --
    #
    #	Get the protection level of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	Return either public, protected or private.

    typemethod getProt {pInfo} {
	array set _ $pInfo
	return $_(protection)
    }

    # setProt --
    #
    #	Set the protection level of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	prot	The new protection level.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setProt {pInfo prot} {
	array set _ $pInfo
	set _(protection) $prot
	return [array get _]
    }

    # getType --
    #
    #	Get the type descriptor of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	Return either tcl, class or inherit.

    typemethod getType {pInfo} {
	array set _ $pInfo
	return $_(type)
    }

    # setType --
    #
    #	Set the type descriptor of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	type	The new type.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setType {pInfo ptype} {
	array set _ $pInfo
	set _(type) $ptype
	return [array get _]
    }

    # getFile --
    #
    #	Get the file name of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	Return the current file being checked.

    typemethod getFile {pInfo} {
	array set _ $pInfo
	return $_(file)
    }

    # setFile --
    #
    #	Set the file name of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	file	The new file name.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setFile {pInfo file} {
	array set _ $pInfo
	set _(file) $file
	return [array get _]
    }

    # getLine --
    #
    #	Get the line number of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	Return the line number.

    typemethod getLine {pInfo} {
	array set _ $pInfo
	return $_(line)
    }

    # setLine --
    #
    #	Set the line number of the command definition.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	line	The new line number.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setLine {pInfo line} {
	array set _ $pInfo
	set _(line) $line
	return [array get _]
    }

    # getVerifyCmd --
    #
    #	Get the callback command needed to verify there is enough
    #	info in the proc info type to append this type onto the list
    #	of defined user procs.  This command should take one arg,
    #	pInfo, which is the proc info type to verify.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	Return the verify command for this pInfo type.

    typemethod getVerifyCmd {pInfo} {
	array set _ $pInfo
	return $_(verifycmd)
    }

    # setVerifyCmd --
    #
    #	Set the callback command needed to verify there is enough
    #	info in the proc info type to append this type onto the list
    #	of defined user procs.  This command should take one arg,
    #	pInfo, which is the proc info type to verify.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	vcmd	The new verifying command type.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setVerifyCmd {pInfo vcmd} {
	array set _ $pInfo
	set _(verifycmd) $vcmd
	return [array get _]
    }

    # getCheckCmd --
    #
    #	Get the callback command needed to check the calling of a
    #	user-defined proc.  This command should take one arg,
    #	pInfo, which is the proc info type to verify.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #
    # Results:
    #	Return the checker command for this pInfo type.

    typemethod getCheckCmd {pInfo} {
	array set _ $pInfo
	return $_(checkcmd)
    }

    # setCheckCmd --
    #
    #	Set the callback command needed to check the calling of a
    #	user-defined proc.  This command should take one arg,
    #	pInfo, which is the proc info type to verify.
    #
    # Arguments:
    #	pInfo	A procInfo opaque type.
    #	ccmd	The new verifying command type.
    #
    # Results:
    #	Return the new pInfo list.

    typemethod setCheckCmd {pInfo ccmd} {
	array set _ $pInfo
	set _(checkcmd) $ccmd
	return [array get _]
    }

    # ### ######### ###########################
    ## Internal. Managing a stack of command definitions in progress.

    # Proc Info Stack --
    # Store a stack of user procs being defined.  As a new proc
    # is defined, add info to the current proc type as the command
    # is defined.

    typevariable procInfoStack {}

    # topProcInfo --
    #
    #	Get the current proc info type currently being defined.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The current proc info type.

    typemethod topProcInfo {} {
	return [lindex $procInfoStack end]
    }

    # pushProcInfo --
    #
    #	Set the current proc info type currently being defined.
    #
    # Arguments:
    #	pInfo		The current qualified context path.
    #
    # Results:
    #	None.

    typemethod pushProcInfo {pInfo} {
	lappend procInfoStack $pInfo
	return
    }

    # popProcInfo --
    #
    #	Unset the current proc info type currently being defined.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The current proc info type.

    typemethod popProcInfo {} {
	set top           [lindex $procInfoStack end]
	set procInfoStack [lrange $procInfoStack 0 end-1]
	return $top
    }

    # addUserProc --
    #
    #	Add the user proc info to the current procInfo type on the stack.
    #
    # Arguments:
    #	name		A fully qualified class or proc name.
    #	type		A literal string that describes the proc info type.
    #
    # Results:
    #	None.  The proc name is added to the proc info stack.

    typemethod addUserProc {name ptype} {
	# Add the proc info type to the def array if the pInfo
	# type is a unique entry.

	set pInfo [$type popProcInfo]
	set pInfo [$type setName $pInfo $name]
	set pInfo [$type setBase $pInfo [context::head $name]]
	set pInfo [$type setType $pInfo $ptype]
	$type pushProcInfo $pInfo
	return
    }

    # addArgList --
    #
    #	Parse the argList and add the user proc info to the stack.
    #
    # Arguments:
    #	argList		The argument list to parse.
    #	min		Specify an initial minimum value.
    #	max		Specify an initial maximum value.
    #
    # Results:
    #	None.  The proc info is added to the user proc stack.
    #	the user proc counter is incremented for the proc name
    #	and the context is added to the context database.

    typemethod addArgList {argList {min 0} {max 0}} {
	# Parse each arg in argList.  If the arg has a length of two, then
	# it is a defaulted argument.  The min value stays fixed after this.
	# If the "args" keyword is the last argument in the argList, then
	# set max to "-1" indicating that any number of args > min is valid.

	set def 0
	foreach arg $argList {
	    if {[llength $arg] >= 2} {
		set def 1
	    }
	    if {!$def} {
		incr min
	    }
	    incr max
	}
	if {[string compare [lindex $argList end] "args"] == 0} {
	    incr min -1
	    set  max -1
	}

	set pInfo [$type popProcInfo]
	set pInfo [$type setMin $pInfo $min]
	set pInfo [$type setMax $pInfo $max]
	set pInfo [$type setDef $pInfo 1]
	$type pushProcInfo $pInfo

	# Variable tracking ... Add the listed arguments as
	# implicit variables to the scope for later checking.
	# The readonly bit can be used in the future to warn
	# when other commands write argument values. They are
	# incoming only, never written back to the caller.

	set narg 0
	foreach arg $argList {
	    if {[llength $arg] >= 2} {
		set def [lindex $arg 1]
		set arg [lindex $arg 0]

		# See analyzer.tcl, proc checkArgList
		# Disabling warning about overwritten arguments ...
		#readonly 1 \#
		xref::varDef argument $arg \
			default  $def \
			narg [incr narg]
	    } else {
		#readonly 1 \#
		xref::varDef argument $arg \
			narg [incr narg]
	    }
	}

	return
    }

    # ### ######### ###########################
    ## Internal. pInfo structure internal stack of definitions.

    typemethod PushCmd {pInfo cmd isscan} {
	array set _ $pInfo

	#puts stderr "UPR push/ $cmd $isscan"

	set key   [expr {$isscan ? "scancmd" : "checkcmd"}]
	set stack ${key}Stack

	# Push top on the stack, then replace the top.
	catch {lappend _($stack) $_($key)}
	set     _($key)   [list ::analyzer::checkBuiltinCmd $cmd]

	return [array get _]
    }

    typemethod PopCmd {pInfo isscan} {
	array set _ $pInfo

	set key   [expr {$isscan ? "scancmd" : "checkcmd"}]
	set stack ${key}Stack

	# Take TOS, move to key, shrink stack

	if {![info exist _($stack)]} {
	    set _($key) {}
	} else {
	    set _($key)   [lindex $_($stack) end]
	    set _($stack) [lrange $_($stack) 0 end-1]
	}
	return [array get _]
    }

    # Formatting offsets
    typevariable  off

    typemethod wrPinfo {prefix pInfo} {
	array set _ $pInfo

	foreach k {
	    name	type	base	protection
	    file	line	cmdrange
	    hasarg	minargno	maxargno
	    verifycmd	checkcmd	scancmd
	} {
	    if {![info exists _($k)]} {continue}
	    puts "$prefix$k$off($k) [list $_($k)]"
	}
	return
    }

    # ### ######### ###########################
    ## Internal. Mgmt of command usage information

    # User Proc Info --

    # Usage data Maps from the fully qualified command name
    # to a dictionary describing the usage:
    # - file, line, cmdrange, scope.
    # - cmdrange is char offset of cmd in file and length in chars.
    # - scope is the nearest lexical scope/entity containing the cmd.

    typevariable use -array {}

    # ### ######### ###########################
}

namespace eval cdb {
    # Initialize array type variables.
    array set off {
	protection ""
	verifycmd " "
	minargno "  "
	maxargno "  "
	checkcmd "  "
	cmdrange "  "
	scancmd "   "
	hasarg "    "
	name "      "
	base "      "
	type "      "
	file "      "
	line "      "
    }
    array set use {}
}

# ### ######### ###########################
## Support for parsing (scanning, analysis) of commands.

# cdb::checkUserProc --
#
#	Check the user-defined proc for the correct number
#	of arguments.  For procs that have been multiply
#	defined, check all of the argLists before flagging
#	an error.  This routine should be called during the
#	final analyzing phase of checking, after the proc
#	names have been found.
#
# Arguments:
#	uproc		The name of the proc to check.
#	pInfoList	A list of procInfo types for the the procedure.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc cdb::checkUserProc {uproc pInfoList tokens index} {
    # Search through the pInfoList and try to find a pInfo
    # type that satisfies the number of args passed to this
    # proc, the protection level and type.  Only flag
    # an error if none of the pInfo's match.

    set n [llength $pInfoList]
    set eCmds {}
    foreach pInfo $pInfoList {
	# Evaluate the check command for this user proc.  If the
	# return is an empty string, then this proc is valid.
	# Break out of the loop.  Otherwise this check failed.
	# Continue checking the remaining pInfo types.

	incr n -1
	set piCmd [cdb getCheckCmd $pInfo]
	if {[catch {
	    set eCmds [{*}$piCmd $pInfo $tokens $index]
	} msg]} {
	    array set pi $pInfo
	    set name $pi(name)
	    unset pi
	    set er [getTokenRange [lindex $tokens $index]]

	    ::analyzer::logError pcxError $er $name $msg
	    set eCmds [::analyzer::logGet]
	}
	#puts "LOG /got [llength $eCmds]"
	if {$eCmds == {}} {
	    break
	}
	if {$n > 0} {
	    # The getCheckCmd above closed the capture level opened by
	    # analyzeScript(Ascii). Knowing that another pInfo follows
	    # we have to reopen a new level one to prevent the upcoming
	    # additional closing from being unbalanced.
	    logOpen
	}
    }

    # Before the rewrite this code looked for a system proc
    # checker. This is not required anymore because the system
    # procs are stored here in our database now too.

    # At this point we have finished checking the list of proc
    # info types.  If no matches were found, report the error
    # of the last checked proc info type.  For common cases
    # there will only be one proc info type, so in general,
    # this should be OK.

    # For a counter case consider 'exit', which is defined by the
    # core, and Expect (as alias of exp_exit). This can cause
    # confusion, because an expected error or warnings seems to be
    # gobbled up and gone without any indication why.

    #puts "LOG /do [llength $eCmds]"
    foreach cmd $eCmds {
	{*}$cmd
    }

    # Make sure to check each word in the command.

    return [analyzer::checkCommandAndStyles $tokens $index]
}


proc cdb::scanRun {cmd pInfoList tokens index} {
    # Search through the pInfoList and try to find a pInfo
    # type that satisfies the number of args passed to this
    # proc, the protection level and type.  Only flag
    # an error if none of the pInfo's match.

    set eCmds {}
    foreach pInfo $pInfoList {
	# Evaluate the scan command for this commmand.  If the
	# return is an empty string, then this command is valid.
	# Break out of the loop.  Otherwise the scan failed.
	# Continue checking the remaining pInfo types.

	array set _ $pInfo
	if {[info exists _(scancmd)] && ($_(scancmd) != {})} {
	    #puts stderr "\t\t\t\t\tscan command present"
	    #puts stderr "\t\t\t\t\t $_(scancmd)"

	    set eCmds [{*}$_(scancmd) $pInfo $tokens $index]
	    if {$eCmds == {}} {
		break
	    }
	}
    }

    # At this point we have finished checking the list of proc
    # info types.  If no matches were found, report the error
    # of the last checked proc info type.  For common cases
    # there will only be one proc info type, so in general,
    # this should be OK.

    foreach cmd $eCmds {
	{*}$cmd
    }

    # Use generic command checker to look for possible scan inside of
    # the command

    return [::analyzer::checkCommand $tokens 0]
}

# ### ######### ###########################
## Ready to go.

package provide cdb 1.0
