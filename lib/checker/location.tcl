# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# location.tcl --
#
#	This file contains functions that maintain the
#	location data structure.
#
# Copyright (c) 1998-2000 Ajuba Solutions
#


# 
# SCCS: @(#) location.tcl 1.4 98/04/14 15:48:29

package provide loc 1.0
namespace eval loc {
    # location data type --
    #
    #	A location encapsulates the state associated with a range of
    #	bytes within a block of code.  Each location is represented by
    #	a Tcl list of the form {block line range}.  The block is
    #	the block identifier for the code that contains the range.
    #	The line is the line number of the first byte in the range.
    #	The range indicates the extent of the location within the
    #	block in a form suitable for use with the parser.

}
# end namespace loc


# loc::getBlock --
#
#	Returns the block that contains the given location.
#	If no such location exists, an error is generated.
#
# Arguments:
#	location	The code location whose block is returned.
#
# Results:
#	Returns the block that contains the given location.

proc loc::getBlock {location} {
    return [lindex $location 0]
}


# loc::getLine --
#
#	Returns the line number for the start of the location as an
#	offset from the beginning of the block.  If no such location 
#	exists, an error is generated.
#
# Arguments:
#	location	The code location whose line number is returned.
#
# Results:
#	Returns the line number for the start of the location as an
#	offset from the beginning of the block.

proc loc::getLine {location} {
    return [lindex $location 1]
}

# loc::getRange --
#
#	Returns the range for the given location in a form suitable
#	for use with the parser interface.  If no such location 
#	exists, an error is generated.
#
# Arguments:
#	location	The code location whose range is returned.
#
# Results:
#	Returns the range for the given location in a form suitable
#	for use with the parser interface.

proc loc::getRange {location} {
    variable locArray

    return [lindex $location 2]
}

# loc::makeLocation --
#
#	Creates a new location based on the block, range, and line values.
#	If the block is invalid, an error is generated.  Either the range
#	or line must be non-empty, otherwise an error is generated.
#
# Arguments:
#	block	The block containing the location to be created.
#	line	The line number of the beginning of the location.
#	range	Optional. A pair of the location's start and length
#		byte values.
#
# Results:
#	Returns a unique location identifier.

proc loc::makeLocation {block line {range {}}} {
    return [list $block $line $range]
}

# loc::match --
#
#	Compare two locations to see if the second location is a match
#	for the first location.  If the first location has no range, then
#	it will match all locations with the same line number.  If the
#	first location has no line number, then it will match all locations
#	with the same block.  Otherwise it will only match locations that
#	have exactly the same block, line and range.
#
# Arguments:
#	pattern		The location pattern.
#	location	The location to test.
#
# Results:
#	Returns 1 if the location matches the pattern.

proc loc::match {pattern location} {
    # Check for null line.
    if {[lindex $pattern 1] == ""} {
	return [expr {[string compare [lindex $pattern 0] \
		[lindex $location 0]] == 0}]
    }
    # Check for null range.
    if {[lindex $pattern 2] == ""} {
	return [expr {[string compare [lrange $pattern 0 1] \
		[lrange $location 0 1]] == 0}]
    }
    # Compare the full location.
    return [expr {[string compare $pattern $location] == 0}]
}

