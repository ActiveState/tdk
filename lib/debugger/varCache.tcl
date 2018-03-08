# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# varCache.tcl --
#
#	This file implements the data structures caching var information
#	for all stack levels.
#
# Copyright (c) 2007 ActiveState Software Inc.

#
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# ### ### ### ######### ######### #########

package require snit

# ### ### ### ######### ######### #########

snit::type varCache {

    #
    # Notes
    #
    # Var type information (i.e. scalar vs array) comes from the
    # outside. This is, well, stupid. This information is bound to the
    # variable name, and can be stored here. No need to keep this
    # info somewhere else.
    #
    # The split into scalar / array storage is also artificial and
    # makes things more complex than needed IMHO.  We cannot have two
    # variables with the same name and different s/a types.
    #

    #
    # 'list' is the main method used by widgets. It returns a list of
    # variables to display, their types, and other information, like
    # existence. The method _also_ prefetches the values of all scalar
    # variables, and of expanded arrays. Unexpanded arrays and
    # non-existing variables are not pre-fetched. The first are fetched
    # lazily, when they are expanded (first access).
    #
    # The information about expansion is provided by the caller, via a
    # callback which delivers the information for a specific variable.
    #

    # Variable information per stacklevel.
    #
    # Name x Level -> Value
    # For arrays the value is a dictionary.

    variable scalarVarData -array {}
    variable arrayVarData  -array {}

    # ### ### ### ######### ######### #########

    # method list --
    #
    #	Add data to the varData array from a list of variables or the
    #	locals for the specified level.  Note this routine should only
    #	be called while the debugger is stopped.
    #
    # Arguments:
    #   iaea
    #	level		The level to get variables from.
    #	vars		Optional.  A list of variable names to add.
    #
    # Results:
    #	Return an ordered list foreach ver of the following format:
    #	{mname oname type exist}

    method list {iaea level {vars {}}} {
	# First two arguments are callbacks. watchWin functionality
	# not belonging to the var data cache itself, but used to
	# control population, and result formation.

	# Foreach var in the vars, compute the list {mname oname type exist}
	# and set the value in the database.

	set infoVars  {}
	set foundVars {}
	set foundList {}
	set realVars  [$dbg getVariables $level $vars]

	# First, determine which variables values have already
	# been retrieved from the Nub or do not need to be fetched.

	NeedsFetching $realVars $level $iaea -> infoVars foundList foundVars

	# Next, fetch the values for the variables in the infoVars
	# list, add the list to the result and set them into the
	# database.

	Fetch $level $dbg $infoVars -> foundList foundVars

	# Finally, determine which variables do not exist.  If the
	# variable is in the realVars list and is not in the foundVars
	# list, then the variable does not exist.  Create the list, but
	# do not set the value in the database.

	return [Missing $realVars $foundVars $foundList]
    }

    proc NeedsFetching {realVars level excb -> iv flv fvv} {
	upvar 1 self self $iv infoVars $flv foundList $fvv foundVars

	foreach pair $realVars {
	    set oname [lindex $pair 0]
	    set vtype [lindex $pair 1]

	    # If the value has already been fetched or is an
	    # unexpanded array, then create the list and
	    # continue. Otherwise append the var name to the list of
	    # variables whose values need to be fetched.

	    if {
		[$self isFetched $oname $level $vtype] ||
		(($vtype eq "a") &&
		 (![eval [linsert $excb end $level $oname]]))
	    } {
		# Already fetched, or unexpanded array
		set mname [code::mangle $oname]
		lappend foundList [list $mname $oname $vtype 1]
		lappend foundVars $oname
	    } else {
		# Needs fetching
		lappend infoVars $oname
	    }
	}
    }

    proc Fetch {level dbg infoVars -> flv fvv} {
	upvar 1 self self $flv foundList $fvv foundVars

	if {![llength $infoVars]} return

	foreach info [$dbg getVar $level [font::get -maxchars] $infoVars] {
	    set oname [lindex $info 0]
	    set vtype [lindex $info 1]
	    set value [lindex $info 2]
	    set mname [code::mangle $oname]

	    $self set $oname $level $vtype $value

	    lappend foundList [list $mname $oname $vtype 1]
	    lappend foundVars $oname
	}
    }

    proc Missing {realVars foundVars foundList} {
	set result {}

	foreach pair $realVars {
	    set oname [lindex $pair 0]
	    if {[set index [lsearch -exact $foundVars $oname]] >= 0} {
		lappend result [lindex $foundList $index]
	    } else {
		set vtype [lindex $pair 1]
		set mname [code::mangle $oname]
		lappend result [list $mname $oname $vtype 0]
	    }
	}

	return $result
    }

    # ### ### ### ######### ######### #########

    # method set --
    #
    #	Set the value for a scalar or array variable.
    #
    # Arguments:
    #	oname	The original, unmangled, variable name.
    #	level	The level the variable is from.
    #	type	The type of the variable (s or a)
    #
    # Results:
    #	Returns the value of the variable.

    method set {oname level vtype value} {
	if {$vtype eq "a"} {
	    set arrayVarData($oname,$level) $value
	} else {
	    set scalarVarData($oname,$level) $value
	}
	return
    }

    # method get --
    #
    #	Get the value for a scalar or array variable.
    #	Arrays are assumed to exists in the database.
    #
    # Arguments:
    #	oname	The original, unmangled, variable name.
    #	level	The level to get variables from.
    #	type	The type of variable (s or a)
    #
    # Results:
    #	Returns the value of the variable.

    method get {oname level vtype} {
	if {$vtype eq "a"} {
	    return [$self get/array $oname $level]
	} else {
	    return [$self get/scalar $oname $level]
	}
    }

    # method get/scalar --
    #
    #	Get the scalar value for a variable.  If the
    #	variable does not exist at this level, then
    #	it has not been fetched.  Set the value to
    #	<No Value>.
    #
    # Arguments:
    #	oname		The original, unmangled, variable name.
    #	level		The level to get variables from.
    #	existVar	Optional var name that will contain a
    #			boolean indicating if the var exists.
    #
    # Results:
    #	Returns the value of the variable.

    # INTERNAL
    method get/scalar {oname level {existVar {}}} {
	if {$existVar != {}} {
	    upvar 1 $existVar exists
	}
	if {[info exists scalarVarData($oname,$level)]} {
	    set exists 1
	    return $scalarVarData($oname,$level)
	} else {
	    set exists 0
	    return $noValue
	}
    }

    # method get/array --
    #
    #	Get an array element/value ordered list for an array.
    #	May need to fetch the value if this is the first
    #	time an array is expanded.  Note: The array must
    #	exist!  Otherwise $self varDataFetched wont work.
    #
    # Arguments:
    #	oname	The original, unmangled, array name.
    #	level	The level to get variables from.
    #
    # Results:
    #	Returns an ordered list of element/value pairs.

    # INTERNAL
    method get/array {oname level} {
	if {![$self isFetched $oname $level "a"]} {
	    set value [lindex [lindex \
		    [$dbg getVar $level [font::get -maxchars] $oname] 0] 2]
	    set arrayVarData($oname,$level) $value
	}
	return $arrayVarData($oname,$level)
    }


    # method isFetched --
    #
    #	Determine if the variable's value has been
    #	fetched at this level.
    #
    # Arguments:
    #	oname	The original, unmangled, array name.
    #	level	The level to get variables from.
    #	type	The type of variable (a or s)
    #
    # Results:
    #	Returns 1 if the var exists, 0 if it does not.

    method isFetched {oname level vtype} {
	if {$vtype eq "a"} {
	    return [info exists arrayVarData($oname,$level)]
	} else {
	    $self get/scalar $oname $level exists
	    return $exists
	}
    }

    # method reset --
    #
    #	Clear the scalarVarData and arrayVarData arrays.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method reset {} {
	array unset scalarVarData *
	array unset arrayVarData  *
	return
    }

    # ### ### ### ######### ######### #########

    # The output message when a variable is undefined or out of scope.

    typevariable noValue {<No Value>}

    method noValue {} {return $noValue}

    # ### ### ### ######### ######### #########

    variable dbg

    constructor {d} {
	set dbg $d
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

package provide varCache 0.1
