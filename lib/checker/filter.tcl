# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# filter.tcl --
#
#	This file implements the analyzer's filter.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2008 ActiveState Software Inc.
#


# 
# SCCS: @(#) filter.tcl 1.5 98/07/24 13:56:33

namespace eval filter {}


proc filter::lineSet {sup idlist} {
    #puts LINE/$sup/$idlist/@[analyzer::getLine]
    variable supLine
    foreach id $idlist {set supLine($id) $sup}
    return
}

proc filter::clearLine {} {
    #puts LINE/clear@[analyzer::getLine]__________________________________________________
    variable    supLine
    array unset supLine *
    return
}


proc filter::blockSet {sup idlist} {
    #puts BLOCK/$sup/$idlist
    variable supBlock
    foreach id $idlist {set supBlock($id) $sup}
    return
}

proc filter::blockSave {} {
    variable supBlock
    variable supBlockStack

    lappend  supBlockStack [array get supBlock]
    return
}

proc filter::blockReset {} {
    variable supBlock
    variable supBlockStack

    array unset supBlock *
    array set   supBlock [lindex $supBlockStack end]
    set supBlockStack [lrange $supBlockStack 0 end-1]
    return
}

proc filter::clearBlock {} {
    variable supBlock
    variable supBlockStack {}
    array unset supBlock *
    return
}


proc filter::localSet {sup idlist} {
    #puts LOCAL/$sup/$idlist
    variable supLocal
    foreach id $idlist {set supLocal($id) $sup}
    return
}

proc filter::localSave {} {
    variable supLocal
    variable supLocalStack

    lappend  supLocalStack [array get supLocal]
    return
}

proc filter::localReset {} {
    variable supLocal
    variable supLocalStack

    array unset supLocal *
    array set   supLocal [lindex $supLocalStack end]
    set supLocalStack [lrange $supLocalStack 0 end-1]
    return
}

proc filter::clearLocal {} {
    variable supLocal
    variable supLocalStack {}
    array unset supLocal *
    return
}

# filter::addFilters --
#
#	Add a set of filters that suppresses certain types
#	of error messages or warnings.
#
# Arguments:
#	msgTypes	The list of message types to filter.
#
# Results:
#	None.

proc filter::addFilters {msgTypes} {
    variable supTypes
    foreach type $msgTypes {set supTypes($type) 1}
    return
}

# filter::globalSet --
#
#	Add a set of filters that suppresses certain messageIDs.
#
# Arguments:
#	mids	The list of messageIDs to supress.
#
# Results:
#	None.

proc filter::globalSet {sup mids} {
    variable supGlobal
    foreach mid $mids {set supGlobal($mid) $sup}
    return
}

proc filter::cmdlineSet {sup mids} {
    variable supCmdline
    foreach mid $mids {set supCmdline($mid) $sup}
    return
}

proc filter::defaultSet {sup mids} {
    variable supDefault
    foreach mid $mids {set supDefault($mid) $sup}
    return
}

# filter::clearFilters --
#
#	Reset the filter to empty.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc filter::clearFilters {} {
    variable    supTypes
    array unset supTypes *
    return
}

# filter::clearSuppressors --
#
#	Clear all current message id suppressors.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc filter::clearGlobal {} {
    variable    supGlobal
    array unset supGlobal *
    return
}

proc filter::clearCmdline {} {
    variable    supCmdline
    array unset supCmdline *
    return
}

# filter::removeFilters --
#
#	Remove a set of filters that suppresses certain types
#	of error messages or warnings.
#
# Arguments:
#	msgTypes	The list of message types to stop filtering.
#
# Results:
#	None.

proc filter::removeFilters {msgTypes} {
    variable supTypes
    foreach type $msgTypes {
	if {[info exists supTypes($type)]} {
	    unset supTypes($type)
	}
    }
    return
}

# filter::ranges --
#
#	Set a range of lines for which to accept messages. Messages
#	for lines outsode of the specified range are suppressed. This
#	has precedence over any other type of filter.
#
# Arguments:
#	line	The line where the range begins and/or ends.
#
# Results:
#	None.

proc filter::ranges {theranges} {
    # ranges := list(range ...)
    # range  := list(start end)
    # start  := ""|number
    # end    := ""|number

    # We sort the ranges in ascending order by startline, then
    # endline. (Which translates to sort by endline first, then by
    # startline). We use dict instead of integer because the latter
    # will balk on empty strings, which are allowed.
    variable ranges [lsort -dict -index 0 [lsort -dict -index 1 $theranges]]

    # Note: For simplicities sake we are not doing complex stuff like
    # range intersection and such to merge overlapping intervals into
    # larger ones. This is implicitly covered by the way we are
    # searching for a matching range in 'InRange'. Doing merging will
    # make the search only a tiny bit faster for the expected
    # situation of a few, less than 10 ranges, at the expense of
    # considerable complexity.

    # We compute the max line to analyze as well, to allow the checker
    # an early abort of its operation.
    variable maxline
    set maxline -1
    foreach range $ranges {
	lassign $range s e
	if {$e eq ""} {
	    set maxline ""
	    break
	} elseif {$e > $maxline} {
	    set maxline $e
	}
    }

    #puts R|$ranges|
    #puts M|$maxline|
    return
}

proc filter::getEndline {} {
    variable maxline
    return  $maxline
}

proc filter::InRange {line} {
    variable ranges

    # Scan all ranges for the one the given line is inside of.

    foreach range $ranges {
	lassign $range s e
	if {$s ne "" && ($line < $s)} {
	    #puts BEFORE/$s/$line
	    continue
	}
	if {$e ne "" && ($e < $line)  } {
	    #puts AFTER/$e/$line
	    continue
	}
	# This range we are in.
	return 1
    }
    # None of the ranges match.
    return 0
}

proc filter::getranges {} {
    variable ranges
    return  $ranges
}

proc filter::rangesfor {path theranges} {
    variable rangesperfile
    set      rangesperfile($path) $theranges
    return
}

proc filter::userangesfor {path} {
    variable rangesperfile
    #puts "__ $path ___"
    ranges $rangesperfile($path)
    return
}

# filter::suppress --
#
#	Determines if the message should be filtered.
#
# Arguments:
#	msgTypes	A list of msgTypes associated with
#			the reported message.
#	mid		The messageID associated with the message.
#
# Results:
#	Returns 1 if the message should be suppressed, 0 if
#	it should be displayed.

proc filter::suppress {msgTypes mid line} {
    variable supTypesCache
    variable supDefault
    variable supGlobal
    variable supCmdline
    variable supLine
    variable supBlock
    variable supLocal
    variable ranges

    if {![InRange $line]} {
	return 1
    }

    # Suppress the message if either all its message types are
    # blocked, or if the id itself has been blocked. We are checking
    # the id first, as that can be done faster.  We also use a cache
    # to keep the results for sets of message types, making this fast
    # as well, by computing the information only once per unique set
    # of types. Note that filtering by id has precedence over
    # filtering by type. This is required to allow the -check option
    # to work, to force checking of a specific id even if it would
    # have been suppressed via a type filter option -Wx.

    set mid [namespace tail $mid]
    #puts FILTER|$mid|

    if {[info exists supLine($mid)]} {
	#puts LINE/$supLine($mid)
	return $supLine($mid)
    }

    if {[info exists supBlock($mid)]} {
	#puts BLOCK/$supBlock($mid)
	return $supBlock($mid)
    }

    if {[info exists supLocal($mid)]} {
	#puts LOCAL/$supLocal($mid)
	return $supLocal($mid)
    }

    if {[info exists supCmdline($mid)]} {
	#puts GLOBAL/cmdline/$supCmdline($mid)
	return $supCmdline($mid)
    }

    if {[info exists supGlobal($mid)]} {
	#puts GLOBAL/embedd/$supGlobal($mid)
	return $supGlobal($mid)
    }

    if {[info exists supDefault($mid)]} {
	#puts DEFAULT/$supDefault($mid)
	return $supDefault($mid)
    }

    set msgTypes [lsort -uniq $msgTypes]
    if {![info exists supTypesCache($msgTypes)]} {
	set supTypesCache($msgTypes) [suppressSet $msgTypes]
    }
    #puts GLOBAL/type/$supTypesCache($msgTypes)
    return $supTypesCache($msgTypes)
}


proc filter::suppressSet {msgTypes} {
    variable supTypes
    foreach type $msgTypes {
	if {[info exists supTypes($type)]} {return 1}
    }
    return 0
}


namespace eval filter {

    # Array of message ids to filter on the next line, current block,
    # or current proc.

    variable  supLineAt {}
    variable  supLine
    array set supLine {}

    variable  supBlock
    array set supBlock {}
    variable  supBlockStack {}

    variable  supLocal
    array set supLocal {}
    variable  supLocalStack {}

    # Array of messageIDs to suppress or not.

    variable  supGlobal
    array set supGlobal {}

    variable  supCmdline
    array set supCmdline {}

    # Array of messages types to filter.

    variable  supTypes
    array set supTypes {}

    # Cache of results for sets of message types.

    variable  supTypesCache
    array set supTypesCache {}

    # The range of lines for which to report messages. The empty
    # string signals a non-existent boundary.

    variable ranges  {{{} {}}}
    variable maxline {}
    variable  rangesperfile
    array set rangesperfile {}
}
