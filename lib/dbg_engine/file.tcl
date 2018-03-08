# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# file.tcl --
#
#	This file implements the file database that maintains
#	unique file names and a most-recently-used file list.
#	as a SNIT class.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2001-2006 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: file.tcl,v 1.3 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type filedb {

    # ### ### ### ######### ######### #########
    ## Instance data

    # A list of most-recently-used files in their absolute
    # path form.

    variable mruList     {}
    variable orderedList {}
    variable uniqueList  {}

    variable updateOrdered 1
    variable updateUnique  1

    variable prevUnique

    # ### ### ### ######### ######### #########

    variable blkmgr
    method blk: {blkmgr_} {
	set blkmgr $blkmgr_
	return
    }

    # ### ### ### ######### ######### #########
    ## Public methods ...

    # method update --
    #
    #	The list of ordered blocks and unique file names
    #	is computed lazily and the results are cached 
    #	internally.  Call this command when the lists
    #	need to be re-computed (e.g. after a break.)
    #
    # Arguments:
    #	hard	Boolean, if true, do a hard update that 
    #		resets the mruList to {}.  This should
    #		only be true when the app is restarted.
    #
    # Results:
    #	None.

    method update {{hard 0}} {
	set updateOrdered 1
	set updateUnique  1
	if {$hard} {
	    set mruList     {}
	    set orderedList {}
	    set uniqueList  {}
	}
    }

    # method getOrderedBlocks --
    #
    #	Get an ordered list of open block, where the order
    #	is most-recently-used, with any remining blocks
    #	appended to the end.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns an ordered list of blocks.  The list
    #	is ordered in a most-recently-used order, then 
    #	any remaining blocks are appended to the end.

    method getOrderedBlocks {} {
	if {$updateOrdered} {
	    # Copy the list of MRU blocks into the result.  Then
	    # append any blocks that are not in the MRU list onto
	    # the end of the new list.
	    
	    set orderedList $mruList
	    set blockList   [lsort [$blkmgr getFiles]]
	    foreach block $blockList {
		if {[$blkmgr isDynamic $block]} {
		    continue
		}
		if {[lsearch -exact $mruList $block] < 0} {
		    lappend orderedList $block
		}
	    }
	    set updateOrdered 0
	}
	return $orderedList
    }

    # method getUniqueFiles --
    #
    #	Get a list of open files where each name is a 
    #	unique name for the file.  If there are more than
    #	one open file with the same name, then the name 
    #	will have a unique identifier.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Returns a list of tuples containing the unique name
    #	and the block number for the file.  The list
    #	is ordered in a most-recently-used order, then 
    #	any remaining files are appended to the end.

    method getUniqueFiles {} {
	if {$updateUnique} {
	    set blockList [$self getOrderedBlocks]
	    set uniqueList {}
	    foreach block $blockList {
		set short [file tail [$blkmgr getFile $block]]
		if {[info exists prevUnique($block)]} {
		    # The file previously recieved a unique
		    # identifier (i.e "fileName <2>".)  To
		    # maintain consistency, use the old ID.

		    set short "$short <$prevUnique($block)>"
		} elseif {[info exists unique($short)]} {
		    # A new file has been loaded that matches
		    # a previously loaded filename.  Bump
		    # the unique ID and append a unique ID,
		    # cache the ID for future use.

		    incr unique($short)
		    set prevUnique($block) $unique($short) 
		    set short "$short <$unique($short)>"
		} else {
		    # This is a file w/o a matching name,
		    # just initialize the unique ID.

		    set unique($short) 1
		}
		lappend uniqueList $short $block
	    }
	    set updateUnique 0
	}
	return $uniqueList
    }

    # method getUniqueFile --
    #
    #	Get the unique name for the block.
    #
    # Arguments:
    #	block	The block type for the file.
    #
    # Results:
    #	The unique name of the block.

    method getUniqueFile {block} {
	foreach {file uBlock} [$self getUniqueFiles] {
	    if {$uBlock == $block} {
		return $file
	    }
	}
	return ""
    }

    # method pushBlock --
    #
    #	Push a new block onto the list of most-recently-used
    #	blocks.
    #
    # Arguments:
    #	block	The block of the file to push onto the stack.
    #
    # Results:
    #	None.

    method pushBlock {block} {
	if {($block != {}) && (![$blkmgr isDynamic $block])} {
	    if {[set index [lsearch -exact $mruList $block]] >= 0} {
		set mruList [lreplace $mruList $index $index]
	    }
	    set mruList [linsert $mruList 0 $block]
	    $self update
	}
    }

    # method getUntitledFile --
    #
    #	Return a filename of <Name><N> where Name is the default name
    #	to use and N is the first integer that creates a filename the 
    #	doesn't exist in this directory.
    #
    # Arguments:
    #	dir	The directory to search finding name conflicts.
    #	name	The default name of the file.
    #	ext	The file extension to append to the filename.
    #
    # Results:
    #	A string that is the filename to use.  The directory is not 
    #	included in the filename.

    method getUntitledFile {dir name ext} {
	for {set i 1} {1} {incr i} {
	    if {![file exists [file join $dir ${name}${i}${ext}]]} {
		return ${name}${i}${ext}
	    }
	}
    }


    # formatFilename --
    #
    #	For Windows apps, we need to do a case insensitive filename
    #	comparison.  Convert the filename to lower case.  For UNIX
    #	this command is a no-op and just returns the original name.
    #
    # Arguments:
    #	filename
    #
    # Results:
    #	The system dependent fileName used for comparisons.
    
    typemethod formatFilename {filename} {
	if {$::tcl_platform(platform) == "windows"} {
	    # Note that use of 'file normalize' makes the file name
	    # absolute. That is OK. The backend delivers absolute
	    # paths to us anyway, as only these truly identify a file.

	    return [string tolower [file normalize $filename]]
	} else {
	    # Bugzilla 19824 ...
	    # On some operating systems (i.e. Linux) the [pwd] system call
	    # will return a path where symbolic links are resolved, making
	    # it possible that the filename used by the backend is not the
	    # same as the name used here in the frontend, because the
	    # backend switches into the directory of a file to determine
	    # its absolute path, and the frontend doesn't. Yet. Now we use
	    # the commands below, the same sequence as used by the
	    # backend, to get the canonical absolute path to the
	    # file. Thus assuring that front- and backend use the same
	    # path when dealing with files and blocks. The catch makes
	    # sure that we are able to continue working even if the
	    # directory or file is not present. This is no problem later
	    # on because the checks we perform before launching the
	    # application will then fail too.

	    if {![catch {
		set here [pwd]
		cd [file dirname $filename]
		set fnew [file join [pwd] [file tail $filename]]
		cd $here
	    }]} {
		set filename $fnew
	    }
	    return $filename
	}
    }
}

# ### ### ### ######### ######### #########
## Ready to go

package provide filedb 1.0
