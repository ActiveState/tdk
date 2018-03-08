# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# block.tcl --
#
#	This file contains functions that maintain the block data structures as SNIT class
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2001-2006 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: block.tcl,v 1.6 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require instrument
package require filedb

# ### ### ### ######### ######### #########
## Implementation

snit::type blkdb {
    # block data type --
    #
    #   A block encapsulates the state associated with a unit of 
    #   instrumented code.  Each block is represented by a Tcl array
    #   whose name is of the form blk<num> and contains the
    #   following elements:
    #		file		The name of the file that contains this
    #				block.  May be null if the block contains
    #				dynamic code.
    #		script		The original uninstrumented script.
    #		version		A version counter for the contents of
    #				the block.
    #		instrumented	Indicates that a block represents instrumented
    #				code.
    #		lines		A list of line numbers in the script that
    #				contain the start of a debugged statement.
    #				These are valid breakpoint lines.
    #
    # Fields:
    #	blockCounter	This counter is used to generate block names.
    #	blockFiles	This array maps from file names to blocks.
    #	blkTemp		This block is the shared temporary block.  It is
    #			used for showing uninstrumented code.

    variable blockCounter 0
    variable blockFiles   
    variable blkTemp

    # ### ### ### ######### ######### #########
    ## Public methods

    constructor {args} {
	array set blockFiles {}
	array set blkTemp {file {} version 0 instrumented 0 script {} lines {}}

	#$self configurelist $args
    }

    method blocks {} {
	set res {}
	foreach v [info vars ${selfns}::blk*] {
	    # Skip over the temp block var
	    if {[string match *Temp $v]} continue
	    regexp "^${selfns}::blk(.*)\$" $v -> id
	    lappend res $id
	}
	return $res
    }

    method blockCounter {} {
	return $blockCounter
    }

    # method makeBlock --
    #
    #	Retrieve the block associated with a file, creating a new
    #	block if necessary.
    #
    # Arguments:
    #	file	The file that contains the block or {} for dynamic blocks.
    #
    # Results:
    #	Returns the block identifier.

    method makeBlock {file} {
	# check to see if the block already exists
	
	set formatFile [filedb formatFilename $file]
	if {[info exists blockFiles($formatFile)]} {
	    return $blockFiles($formatFile)
	}

	# find an unallocated block number and create the array

	incr blockCounter
	while {[info exists ${selfns}::blk$blockCounter]} {
	    incr blockCounter
	}
	array set ${selfns}::blk${blockCounter} [list \
		file $file \
		version 0 \
		instrumented 0 \
		lines {} \
		ranges {} \
		spawnLines {} \
		loffset {} \
		map {} \
		rmap {} \
	    ]

	#puts "makeBlock b/${blockCounter}/ = v0 - $file"

	# Don't create an entry for dynamic blocks

	if {$file != ""} {
	    set blockFiles($formatFile) $blockCounter
	}
	return $blockCounter
    }

    # method release --
    #
    #	Release the storage associated with one or more blocks.
    #
    # Arguments:
    #	args	The blocks to release, "dynamic" to release all dynamic
    #		blocks, or "all" to release all blocks, or the ids of the
    #           specific blocks to release.
    #
    # Results:
    #	None.

    method release {args} {
	#puts "release $args"

	if {$args == "dynamic"} {
	    foreach block [info var ${selfns}::blk*] {
		if {[set ${block}(file)] == ""} {
		    unset $block
		}
	    }
	} elseif {$args == "all"} {
	    if {[info exists blockFiles]} {
		unset blockFiles
	    }
	    set all [info var ${selfns}::blk*]
	    if {$all != ""} {
		eval unset $all
	    }

	    # Bugfix for MTBD ... Reset counter to 0, so that the
	    # internal special code is always block 1. Also makes
	    # sense in general, if we release all blocks we can
	    # start over from the beginning.

	    # Note: lib/debugger/codeWin.tcl (updateWindow) relied on
	    # the ever incrementing counter and required an update.

	    set blockCounter 0
	} else {
	    foreach block $args {
		if {! [info exists ${selfns}::blk$block]} {
		    continue
		}
		set file [$self getFile $block]
		if {$file != ""} {
		    unset blockFiles([filedb formatFilename $file])
		}
		unset ${selfns}::blk$block
	    }
	}

	if {! [info exists blkTemp]} {
	    array set blkTemp {
		file {} version 0 instrumented 0 script {} lines {}
	    }

	    #puts "\tblkTemp (reset to empty, v0)"
	}
    }

    # method exists --
    #
    #	Determine if the block still exists.
    #
    # Arguments:
    #	blockNum	The block to check for existence.
    #
    # Results:
    #	Return 1 if the block exists.

    method exists {blockNum} {
	upvar #0 ${selfns}::blk$blockNum block
	return [info exists block(instrumented)]
    }


    # method getSource --
    #
    #	Return the script associated with a block.  If block's script
    #	has never been set, open the file and read the contents.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns the script.

    method getSource {blockNum} {
	upvar #0 ${selfns}::blk$blockNum block

	if {[info exists block(script)]} {
	    return $block(script)
	} elseif {$block(file) != ""} {
	    #puts "getSource $blockNum /incr version"

	    set fd [open $block(file) r]
	    set script [read $fd]
	    close $fd
	    incr block(version)

	    # Bugzilla 26382 ... Remember the script ...
	    set  block(script) $script
	    return $script
	} else {
	    return ""
	}
    }

    # Bugzilla 26382 ... New method to clear script cache of block
    method clearSourceCache {blockNum} {
	upvar #0 ${selfns}::blk$blockNum block
	unset -nocomplain                block(script)
	return
    }

    # method getFile --
    #
    #	Return the name associated with the given block.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns the file name or {} if the block is dynamic.

    method getFile {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	return                            $block(file)
    }

    # method getLines --
    #
    #	Return the list of line numbers that represent valid
    #	break-points for this block.  If the block does not
    #	exist or the block is not instrumented we return -1.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns a list of line numbers.

    method getLines {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	if {
	    ![info exists block(instrumented)] ||
	    !$block(instrumented)
	} {
	    return -1
	}
	return $block(lines)
    }

    # method getSpawnLines --
    #
    #	Return the list of line numbers that represent valid
    #	spawn-points for this block.  If the block does not
    #	exist or the block is not instrumented we return -1.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns a list of line numbers.

    method getSpawnLines {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	if {
	    ![info exists block(instrumented)] ||
	    !$block(instrumented)
	} {
	    return -1
	}
	return $block(spawnlines)
    }

    # method getRanges --
    #
    #     Return the list of ranges that represent valid
    #     break-points for this block.  If the block does not
    #     exist or the block is not instrumented, we return -1.
    #
    # Arguments:
    #     blockNum        The block number.
    #
    # Results:
    #     Returns a list of range numbers.

    method getRanges {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	if {! [info exists block(instrumented)]} {
	    return -1
	}
	if {!$block(instrumented)} {
	    return -1
	}
	return [lsort $block(ranges)]
    }

    # method getLineOffsets --
    #
    #	Return the list of line offsets. If the block does not
    #	exist or the block is not instrumented we return the empty
    #	list.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns a list of line offsets.

    method getLineOffsets {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	if {
	    ![info exists block(instrumented)] ||
	    !$block(instrumented)
	} {
	    return -1
	}
	return $block(loffset)
    }

    # method getMap --
    #
    #	Return a dictionary mapping from lines to the ranges
    #   of all commands beginning on that line. If the block
    #	does not exist or the block is not instrumented we
    #	return the empty dictionary.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns a dictionary.

    method getMap {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	if {
	    ![info exists block(instrumented)] ||
	    !$block(instrumented)
	} {
	    return -1
	}
	return $block(map)
    }

    # method getRMap --
    #
    #	Return a dictionary mapping from ranges to the line it begins
    #   on. If the block
    #	does not exist or the block is not instrumented we
    #	return the empty dictionary.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns a dictionary.

    method getRMap {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	if {
	    ![info exists block(instrumented)] ||
	    !$block(instrumented)
	} {
	    return {}
	}
	return $block(rmap)
    }

    # method Instrument --
    #
    #	Set the source script associated with a block and return the
    #	instrumented form.
    #
    # Arguments:
    #	blockNum	The block number.
    #	script		The new source for the block that should be
    #			instrumented.
    #
    # Results:
    #	Returns the instrumented script.

    variable ierrorhdl {}
    method iErrorHandler {handler} {
	set ierrorhdl $handler
	return
    }

    method Instrument {blockNum script} {
	upvar #0 ${selfns}::blk${blockNum} block

	$self SetSource $blockNum $script

	set instrument::errorHandler $ierrorhdl

	#puts stderr "block ($blockNum): instrument"

	set script [instrument::Instrument $self $blockNum]
	set instrument::errorHandler {}

	# Don't mark the block as instrumented unless we have successfully
	# completed instrumentation.

	if {$script != ""} {
	    set block(instrumented) 1

	    # Compute the sorted list of line numbers containing statements.
	    # We need to suppress duplicates since there may be more than one
	    # statement per line. Ensure that the lines are in numerically
	    # ascending order.

	    set block(lines) [lsort -uniq -integer $::instrument::lines]

	    # Ditto for spawnpoints.

	    set block(spawnlines) [lsort -uniq -integer $::instrument::spawnlines]

	    # Get the coverable ranges for this block.

	    set block(ranges) $::instrument::ranges

	    # Get line offsets for this block

	    set block(loffset) $::instrument::loffset

	    # Get the cmd map for this block

	    set block(map) [array get ::instrument::cmdmap]

	    # Invert the command map to go from a range to the line it
	    # is on.

	    set rmap {}
	    foreach {line rangelist} $block(map) {
		foreach range $rangelist {
		    lappend rmap $range $line
		}
	    }
	    set block(rmap) $rmap
	}
	return $script
    }

    # method isInstrumented --
    #
    #	Test whether a block has been instrumented.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns 1 if the block is instrumented else 0.

    method isInstrumented {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	if {[catch {set block(instrumented)} result]} {
	    return 0
	}
	return $result
    }

    # method unmarkInstrumentedBlock --
    #
    #	Mark all the instrumented blocks as uninstrumented.  If it's
    #	a block to a file remove the source.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method unmarkInstrumentedBlock {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	if {$block(instrumented) == 1} {
	    set block(instrumented) 0
	    if {$block(file) != ""} {
		unset block(script)
	    }
	}
	return
    }

    # method unmarkInstrumented --
    #
    #	Mark all the instrumented blocks as uninstrumented.  If it's
    #	a block to a file remove the source.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method unmarkInstrumented {} {
	foreach block [info var ${selfns}::blk*] {
	    if {[set ${block}(instrumented)] == 1} {
		set ${block}(instrumented) 0
		if {[set ${block}(file)] != ""} {
		    unset ${block}(script)
		}
	    }
	} 
	return
    }

    # method getVersion --
    #
    #	Retrieve the source version for the block.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns the version number.

    method getVersion {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	return                            $block(version)
    }

    # method getFiles --
    #
    #	This function retrieves all of the blocks that are associated
    #	with files.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns a list of blocks.

    method getFiles {} {
	set result {}
	foreach name [array names blockFiles] {
	    lappend result $blockFiles($name)
	}
	return $result
    }

    # method getAll --
    #
    #	This function retrieves all known blocks.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns a list of blocks.

    method getAll {} {
	set result {}
	foreach name [info vars ${selfns}::blk*] {
	    regsub ^${selfns}::blk $name {} name
	    lappend result $name
	}
	return $result
    }

    # method SetSource --
    #
    #	This routine sets the script attribute of a block and incremenets
    #	the version number.
    #
    # Arguments:
    #	blockNum	The block number.
    #	script		The new contents of the block.
    #
    # Results:
    #	None.

    method SetSource {blockNum script} {
	#puts stderr "SetSource $blockNum /incr version ([string length $script])"
	upvar #0 ${selfns}::blk${blockNum} block

	set  block(script) $script
	incr block(version)
	return
    }

    # method isDynamic --
    #
    #	Check whether the current block is associated with a file or
    #	is a dynamic block.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns 1 if the block is not associated with a file.

    method isDynamic {blockNum} {
	upvar #0 ${selfns}::blk${blockNum} block
	return [expr {$block(file) == ""}]
    }

    # Bugzilla 19824 ...
    # method title --
    #
    #	Constructs a human readable title string for the block.
    #
    # Arguments:
    #	blockNum	The block number.
    #
    # Results:
    #	Returns title string for the block.

    method title {blockNum} {
	if {[$self isDynamic $blockNum]} {
	    # User code will be accessed here. This can be a
	    # dynamically created procedure, in which case the code
	    # can be assumed to be syntactically valid list, or it can
	    # be from a remotely debugged file, i.e. any type of
	    # script, which usually is not a valid list.
	    #
	    # See Bug 75172.

	    if {[catch {
		set str "Procedure [lindex [$self getSource $blockNum] 1]"
	    }]} {
		set str "Remote file"
	    }
	    return $str
	} else {
	    return "File [$self getFile $blockNum]"
	}
    }
}

# ### ### ### ######### ######### #########
## Ready to go

package provide blk 1.0
