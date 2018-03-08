# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# find.tcl --
#
#	This file implements the Find and Goto Windows.  The find
#	namespace and associated code are at the top portion of
#	this file.  The goto namespace and associated files are 
#	at the bottom portion of this file.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: find.tcl,v 1.3 2000/10/31 23:30:58 welch Exp $

# ### ### ### ######### ######### #########

package require tile
package require snit

# ### ### ### ######### ######### #########

snit::type find {
    # These vars are used to generalized the find command
    # in case a new window wants to use the APIs.  Currently
    # the code is not re-entrant, but small modifications will
    # fix this (only if necessary.)
    #
    # findText		The text widget to search.
    # findSeeCmd 	The see cmd for the widget or set of widgets.
    # findYviewCmd 	The yview cmd for the widget or set of widgets.

    variable findText		{}
    variable findSeeCmd		{}
    variable findYviewCmd	{}

    # These are the var that strore the history and current search
    # patterns or words.
    #
    # findBox	The handle to the combobox used to show history.
    # findList	The list of items in the history (persistent between runs)
    # findVar	The pattern/word to search for.
    
    variable findBox
    variable findList  {}
    variable findVar   {}

    # These vars are booleans for the selected search options.
    #
    # wordVar	If true match the who word only.
    # caseVar	If true perform a case sensitive search.
    # regexpVar	If true perform a regexp based search.
    # searchVar	If true search in all open documents.
    # dirVar	If true search forwards.

    variable wordVar   0
    variable caseVar   0
    variable regexpVar 1
    variable searchVar 0
    variable dirVar    1

    # These vars are used for performing incremental searches.
    # Such as searching for the next var that matches.
    # 
    # blkIndex	The index where the search will start.
    # blkList	The list of blocks to search.
    # nextBlk	An index into the blkList that points to the 
    #		next block to search.
    # startBlk	Stores where the search began to pervent infinite loops.
    # found	Array that stores previously found words.

    variable blkList  {}
    variable blkIndex 1.0
    variable nextBlk  0
    variable startBlk 0
    variable found

    # ### ### ### ######### ######### #########

    variable             blkmgr
    variable             code
    variable             gui {}
    option              -gui {}
    onconfigure         -gui {value} {
	if {$value eq $gui} return
	$self GSetup $value
	return
    }

    method GSetup {value} {
	set gui     $value
	set code    [$gui code]
	set engine_ [$gui cget -engine]
	set blkmgr  [$engine_ blk]
	return
    }

    # ### ### ### ######### ######### #########

    # method showWindow --
    #
    #	Show the Find Window.  If it dosent exist, then create it.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The toplevel handle to the Find Window.

    method showWindow {} {
	# If the window already exists, show it, otherwise
	# create it from scratch.

	set top [$gui findDbgWin]
	if {[winfo exists $top]} {
	    wm deiconify $top
	} else {
	    $self createWindow
	}
	focus $findBox
	return $top
    }

    # method createWindow --
    #
    #	Create the Find Window.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method createWindow {} {
	set pad 6

	set                        top [toplevel [$gui findDbgWin]]
	::guiUtil::positionWindow $top
	## wm minsize             $top 100 100 ; # allow resizing
	wm resizable              $top 1 0
	wm title                  $top "Find - [$gui cget -title]"
	wm transient              $top $gui

	set mainFrm [ttk::frame $top.mainFrm -padding 4]

	set findFrm [ttk::frame $mainFrm.findFrm]
	set findLbl [ttk::label $findFrm.findLbl -text "Find What "]
	set findBox [ttk::combobox $findFrm.findBox -width 10 \
			 -textvariable [myvar findVar]]

	set pattern [list]
	for {set i [expr {[llength $findList] - 1}]} {$i >= 0} {incr i -1} {
	    lappend pattern [lindex $findList $i]
	}
	$findBox configure -values $pattern


	pack $findLbl -side left -pady $pad
	pack $findBox -side left -pady $pad -fill x -expand true

	set checkFrm [ttk::frame $mainFrm.checkFrm]
	set wordChk [ttk::checkbutton $checkFrm.wordChk \
		-variable [myvar wordVar] \
		-text "Match whole word only"]
	set caseChk [ttk::checkbutton $checkFrm.caseChk \
		-variable [myvar caseVar] \
		-text "Match case" ]
	set regexpChk [ttk::checkbutton $checkFrm.regexpChk \
		-variable [myvar regexpVar] \
		-text "Regular expression"]
	set searchChk [ttk::checkbutton $checkFrm.searchChk \
		-variable [myvar searchVar] \
		-text "Search all open documents"]
	pack $wordChk -padx $pad -anchor w
	pack $caseChk -padx $pad -anchor w
	pack $regexpChk -padx $pad -anchor w
	pack $searchChk -padx $pad -anchor w

	set dirFrm [prefWin::createSubFrm $mainFrm dirFrm "Direction"]

	set upRad  [ttk::radiobutton $dirFrm.upRad -text Up \
		-variable [myvar dirVar] -value 0]
	set downRad [ttk::radiobutton $dirFrm.downRad -text Down \
		-variable [myvar dirVar] -value 1]

	grid $upRad   -row 0 -column 0 -sticky w -padx $pad
	grid $downRad -row 1 -column 0 -sticky w -padx $pad
	grid columnconfigure $dirFrm 0 -weight 1

	grid $mainFrm.dirFrm -row 1 -column 1 -sticky nswe -padx $pad -pady $pad
	set findBut [ttk::button $mainFrm.findBut -text "Find Next" \
			 -default active -command [mymethod execute]]
	set closeBut [ttk::button $mainFrm.closeBut -text "Close" \
			  -default normal -command [list destroy $top]]

	grid $findFrm  -row 0 -column 0 -sticky nwe -columnspan 2 -padx $pad
	grid $findBut  -row 0 -column 2 -sticky nwe -padx $pad -pady $pad
	grid $closeBut -row 1 -column 2 -sticky nwe -padx $pad -pady $pad
	grid $checkFrm -row 1 -column 0 -sticky nsw
	#   grid $dirFrm   -row 1 -column 1 -sticky nswe -padx $pad -pady $pad
	grid columnconfigure $mainFrm 1 -weight 1
	grid rowconfigure $mainFrm 2 -weight 1
	pack $mainFrm -fill both -expand true ; # -padx $pad -pady $pad

	set winList [list $findBox $wordChk $caseChk $regexpChk \
		$searchChk $upRad $downRad $findBut $closeBut]
	foreach win $winList {
	    bind::addBindTags $win findDbgWin$self
	}
	bind::commonBindings findDbgWin$self $winList
	bind findDbgWin$self <Return> "$findBut  invoke; break"
	bind $top            <Escape> "$closeBut invoke; break"
    }

    # method execute --
    #
    #	Initialize the search based on the Code Window widgets
    #	and code functions.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method execute {} {
	# This is a feeble attempt to generalize the find command
	# so it is not tied directly to the Code Window.  If a new
	# text widget requires the find command then it will need
	# to re-implement this function and initialize these vars.

	set findText     [$code text]
	set findSeeCmd   [list $code see]
	set findYviewCmd [list $code yview]

	# Add the new pattern to the combo box history.
	# But only if it is not already present.

	set     findList [$findBox cget -values]

	if {[lsearch -exact $findList $findVar]} {
	    lappend findList $findVar
	    $findBox configure -values $findList
	}

	# Initialize the search data and execute the search.
	$self init
	$self next

	## Put focus back to the Code Window and remove the Find Window.
	focus $findText
	wm withdraw [$gui findDbgWin]
    }

    # method init --
    #
    #	Initialize a find request.  This is done when "Find Next"
    #	is executed in the Find Window, or when <<Dbg_FindNext>> is
    #	requested on a new block.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method init {} {
	# Create the list of documents to search through.  If the
	# user selected "search all open..." then the list will 
	# contain all files, otherwise it will only contain the
	# currently displayed block.

	if {$searchVar} {
	    set blkList [lsort [$blkmgr getFiles]]
	    set nextBlk [lsearch $blkList [$gui getCurrentBlock]]
	    if {$nextBlk < 0} {
		set nextBlk 0
	    }
	} else {
	    set blkList [$gui getCurrentBlock]
	    set nextBlk 0
	}

	# Start the search from the index of the insert cursor
	# in the Code Win.

	set blkIndex [$findText index "insert + 1c"]

	# Cache this index into the blkList so we know when
	# to stop looping in the $self next function.

	set startBlk $nextBlk

	# If there is data for found matches, remove them and 
	# start searching fresh.

	if {[info exists found]} {
	    unset found
	}
    }

    # method nextOK --
    #
    #	Determine if data has been initialized so that 
    #	find next will execute.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	Boolean, true is find next can be called.

    method nextOK {} {
	return [expr {$findText != {}}]
    }

    # method next --
    #
    #	Find the next match.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method next {} {
	# If the two blocks are different, then re-initialize the search
	# variables to start the search from this block and index.

	if {[lindex $blkList $nextBlk] != [$gui getCurrentBlock]} {
	    $self init
	}

	# Short circut if we cannot find a match in this document and
	# we are not searching all open documents.

	set range [$self search]
	if {($range == {}) && ($searchVar == 0)} {
	    return
	}

	# We are searching multiple documents, loop through the open
	# documents and try to find a match.  When the while loop is
	# entered, a new block may be loaded into the text widget so
	# we can perform text-based seraches.  If no match is found 
	# we want to restore the code display to its original state. 
	# Store this state.

	set thisBlk      [$gui getCurrentBlock]
	set restoreBlk   $thisBlk
	set restoreView  [lindex [$findText yview] 0]
	set restoreRange [$findText tag nextrange highlight 1.0 end]

	# Loop until range has a value that was not already an existing
	# match.  If the nextBlk equals the startBlk and range is an
	# empty string, then we cannot find a match in any documents.
	# In this case we will also break the loop.

	while {$range == {} || [info exists found($range,$thisBlk)]} {
	    # Get the next block from the list of open blocks.
	    # If the next block is the same as when we started,
	    # (determined in $self init) then unset any found
	    # data and continue.

	    incr nextBlk 
	    if {$nextBlk >= [llength $blkList]} {
		set nextBlk 0
	    }
	    if {$nextBlk == $startBlk} {
		bell
		if {[info exists found]} {
		    unset found
		}
		if {$range == {}} {
		    break
		}
	    }

	    # If we have a valid new block, bring that block into the
	    # Code Window's text widget so we can perform text based
	    # searches.  

	    set thisBlk [lindex $blkList $nextBlk]
	    if {$thisBlk != [$gui getCurrentBlock]} {
		set loc [loc::makeLocation $thisBlk {}]
		$gui showCode $loc
	    }
	    
	    # Reset the starting search index and search the new block.
	    if {$dirVar} {
		set blkIndex 1.0
	    } else {
		set blkIndex end
	    }
	    set range [$self search]
	}

	if {$range != {}} {
	    # Add this range and block to the found index so we know
	    # when we looped searching in this block.

	    set found($range,$thisBlk) 1
	    set start [lindex $range 0]
	    set end   [lindex $range 1]

	    if {$dirVar} {
		# Searching Forwards
		set blkIndex [$findText index $end]
	    } else {
		# Searching Backwards
		set blkIndex [$findText index "$start - 1c"]
	    }

	    # Add the selection tag to the matched string, move the 
	    # insertion cursor to this location and call the code:see
	    # routine that lines up all of the code text widgets to 
	    # the same view region.

	    $findText tag remove sel  0.0 end
	    $findText tag add sel $start $end
	    $findText mark set insert $start
	    eval [linsert $findSeeCmd end $start]
	} elseif {$restoreBlk != {}} {
	    # Restore the original block, highlight the text,
	    # reset the insertion cursor and view the region.

	    $gui showCode [loc::makeLocation $restoreBlk {}]
	    eval [linsert $findYviewCmd end moveto $restoreView]
	    if {$restoreRange != {}} {
		eval {$findText tag add highlight} $restoreRange
		$findText mark set insert [lindex $restoreRange 0]
	    }
	}
	focus $findText
	return
    }

    # method search --
    #
    #	Search the Code Window to find a match.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	A range into the text widget with the start and 
    #	end index of the match, or empty string if no
    #	match was found.

    method search {} {
	if {$caseVar} {
	    set nocase ""
	} else {
	    set nocase "-nocase"
	}
	if {$regexpVar} {
	    set match "-regexp"
	} else {
	    set match "-exact"
	}
	if {$dirVar} {
	    set dir "-forwards"
	} else {
	    set dir "-backwards"
	}

	# Try to find the next match in this block.  The value of
	# index is the first char that matches the pattern or 
	# empty string if no match was found.  If a match was
	# found, then the var "numChars" will be set with the 
	# number of chars that matched.

	set index [eval "$findText search $dir $match $nocase \
		-count numChars --  [list $findVar] $blkIndex"]

	if {$index != {}} {
	    set start $index
	    set end   "$index + ${numChars}c"
	    if {[$self wholeWordMatch $start $end]} {
		return [list $start $end]
	    }
	}
	return {}
    }

    # method wholeWordMatch --
    #
    #	If "Match whole word..." was selected determine if the
    #	the current selection actually matched the whole word.
    #
    # Arguments:
    #	start	The starting index of the match.
    #	end	The ending index of the match.
    #
    # Results:
    #	Boolean, true if the string matches the whole word or
    #	the option was not selected.

    method wholeWordMatch {start end} {
	# Match only the whole word.  If the index for the
	# end of the word is greater than the end index of
	# the search result, then the match failed.  Call
	# method next to search further.
	
	if {$wordVar} {
	    set wordEnd "$start wordend"
	    if {[$findText compare $wordEnd > $end]} {
		return 0
	    }
	}
	return 1
    }
}

# ### ### ### ######### ######### #########

package provide find 1.0
