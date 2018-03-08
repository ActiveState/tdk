# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# coverage.tcl --
#
#	This file contains the Debugger extension
#	to implement the code coverage feature.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: coverage.tcl,v 1.6 2000/10/31 23:30:57 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require csv     ; # Tcllib   | CSV handling
package require BWidget ; # BWidgets | Use its mega widgets.
NoteBook::use           ; # BWidgets / Widget used here.
ScrolledWindow::use
package require Tktable ; # Tabular list for Calls.
package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type coverage {

    # The coverageEnabled variable knows whether coverage is on or off.
    # It is off by default.

    variable coverageEnabled 0

    # Store the list {line numRepeatedCoverage} for each range that
    # has been covered at least once.  The indices are stored as follows:
    # <blockNum>:R:<range>

    variable  currentCoverage

    # Store the list {line-number} for each range that has not yet been
    # covered.  The indices are stored as follows: <blockNum>:R:<range>

    variable  currentUncoverage

    # Like currentCoverage (same keys), but maps to timing infromation
    # instead of the number of calls.

    variable currentProfile


    # Store the name of the file associated with each instrumented block.
    # Use this array to find block num of a "selected" file.

    variable  instrumentedBlock

    # Store number of times the most repeated command was covered.
    # Use this value to calculate the number of repetitions needed to
    # to increase the intensity of coverage shading.

    variable maxRepeatedCoverage 1

    # Handles to widgets in the Coverage Window.

    variable coverWin    {}
    variable profileWin  {}
    variable showBut     {}
    variable clearBut    {}
    variable clearAllBut {}
    variable fList       {}
    variable shownfiles  {}
    variable hasmessage  0

    # Toggle between showing un-coverage: radio(val) = 1
    #                       and coverage: radio(val) = 0
    # Widget handles are radio(uncvr) and radio(cvr).

    variable radio

    # Toggle/Checkbox save ALL data in csv, or only covered.

    variable saveall 1

    # Used to delay UI changes do to state change.
    variable afterID

    # Key of the currently active list (pane: fList or profileWin, keys in {Files, Calls})
    variable activePane ""

    # Coverage intensities and associated color shades.
    # Other information regarding shading too.

    variable numShades 20
    variable intensityArray
    variable istep -1


    # Variable used by the profiling list/table to store
    # its information. The blocknum is not shown!, but
    # used for selection processing.

    variable  profile

    # Profiling information as a sortable list ...
    # Per item: calls filename line location

    variable proflist {}

    # Sorting order for the profile information, and type
    # information

    variable  profsort {3 4 5 6 2 1 0}
    variable lastdir   [pwd]

    variable profsinfo

    # ### ### ### ######### ######### #########

    variable             code
    variable             blkmgr
    variable             fdb
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
	set dbg     [$engine_ dbg]
	set blkmgr  [$engine_ blk]
	set fdb     [$engine_ fdb]

	$dbg  configure -coverobj $self
	$code configure -coverobj $self
	return
    }

    # ### ### ### ######### ######### #########

    constructor {args} {
	array set currentProfile    {}
	array set currentCoverage   {}
	array set currentUncoverage {}
	array set instrumentedBlock {}
	array set radio {val 1}
	array set intensityArray {}
	array set profile {
	    0,0 {      #Calls}
	    0,1 {      Filename}
	    0,2 {      Line}
	    0,3 {      Min}
	    0,4 {      Avg}
	    0,5 {      Max}
	    0,6 {      Total}
	    0,7 {//Location//}
	}
	array set profsinfo {
	    t,0 -integer o,0 -decreasing
	    t,1 -ascii   o,1 -increasing
	    t,2 -integer o,2 -increasing
	    t,3 -dict    o,3 -decreasing
	    t,4 -dict    o,4 -increasing
	    t,5 -dict    o,5 -increasing
	    t,6 -dict    o,6 -increasing
	    img,-decreasing {}
	    img,-increasing {}
	    neg,-decreasing -increasing
	    neg,-increasing -decreasing
	}

	# Setup the images for sorting ...

	set profsinfo(img,-increasing) $image::image(sort_increasing)
	set profsinfo(img,-decreasing) $image::image(sort_decreasing)

	$self configurelist $args
	return
    }

    # ### ### ### ######### ######### #########


    method raiseList {tabWin} {
	set activePane [$tabWin tab current -text]
	$self checkState
	return
    }

    # method checkState --
    #
    #	Determine if the "Show Code" button should be normal
    #	or disabled based on what is selected.
    #
    # Arguments:
    #	None
    #
    # Results:
    #	None.

    method checkState {} {
	# Bugzilla 19627 ... Code is independent of the state the backend
	# .................. is in.
	if {0} {
	    set state [$gui getCurrentState]
	    if {$state != "stopped"} {
		$clearAllBut configure -state disabled
	    } else {
		$clearAllBut configure -state normal
	    }
	}

	set files 0
	switch -exact -- $activePane {
	    Files {
		set noShow $hasmessage
		set files 1
	    }
	    Calls {
		set win                     $profileWin
		set noShow [expr {[llength [$profileWin curselection]] == 0}]
	    }
	}

	if {$noShow} {
	    $showBut  configure -state disabled
	    $clearBut configure -state disabled
	} else {
	    $showBut  configure -state normal
	    $clearBut configure -state normal
	}

	if {[focus] == $win} {
	    if {$files} {
		sel::changeFocus $win in
	    }
	}
	return
    }

    # method clearAllCoverage --
    #
    #	Remove all memory of having covered any code.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method clearAllCoverage {} {
	# Bugzilla 19627 ... Code is independent of the state the backend
	# .................. is in.
	if {0} {
	    set state [$gui getCurrentState]
	    if {$state != "running" && $state != "stopped"} {
		return
	    }
	}

	$self clearCoverageArray    
	$self updateWindow
    }

    # method clearBlockCoverage --
    #
    #	Remove all memory of having covered the specified block.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method clearBlockCoverage {} {
	# Bugzilla 19627 ... Code is independent of the state the backend
	# .................. is in.
	if {0} {
	    set state [$gui getCurrentState]
	    if {$state != "running" && $state != "stopped"} {
		return
	    }
	}

	$self clearCoverageArray [loc::getBlock [$self getSelectedLocation]]
	$self updateWindow
	return
    }

    # method clearCoverageArray --
    #
    #	Remove all memory of having covered the specified block.  If no
    #	block is specified, do so for all blocks and reset
    #	maxRepeatedCoverage to 1
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method clearCoverageArray {{blk -1}} {
	if {$blk == -1} {
	    unset     currentProfile
	    array set currentProfile    {}
	    unset     currentCoverage
	    array set currentCoverage   {}
	    unset     currentUncoverage
	    array set currentUncoverage {}
	    set maxRepeatedCoverage 1
	} else {
	    foreach index [array names currentProfile "${blk}:*"] {
		unset currentProfile($index)
	    }
	    foreach index [array names currentCoverage "${blk}:*"] {
		unset currentCoverage($index)
	    }
	    foreach index [array names currentUncoverage "${blk}:*"] {
		unset currentUncoverage($index)
	    }
	    catch {unset currentProfile($blk)}
	    catch {unset currentCoverage($blk)}
	    catch {unset currentUncoverage($blk)}
	}
	return
    }

    # method createWindow --
    #
    #	Create the Coverage Window that will display
    #	all the instrumented files in the running application. 
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method createWindow {} {
	set coverWin [$gui coverWin]
	set top [toplevel $coverWin]

	::guiUtil::positionWindow $top 400x225

	wm minsize   $top 175 100
	wm title     $top "Code Coverage & Profiling - [$gui cget -title]"
	wm transient $top $gui
	wm resizable $top 1 1

	set pad 6

	# Create the text widget that displays all files and the 
	# "Show Code" button.

	set mainFrm [ttk::frame $top.mainFrm]

	set radio(cvr)  [ttk::radiobutton $mainFrm.radioCvr \
		-variable [varname radio](val) -value 0 \
		-text "Highlight covered code for selected file" \
		-command [mymethod reHighlightCurrentBlock]]
	set radio(uncvr)  [ttk::radiobutton $mainFrm.radioUncvr \
		-variable [varname radio](val) -value 1 \
		-text "Highlight uncovered code for selected file" \
		-command [mymethod reHighlightCurrentBlock]]

	set tabWin [ttk::notebook $mainFrm.nb]
	foreach {key var} {
	    Files files
	    Calls calls
	} {
	    set $var [set w [ttk::frame $tabWin.f$key -padding 4]]
	    $tabWin insert end $w -text $key
	}
	bind $tabWin <<NotebookTabChanged>> [mymethod raiseList $tabWin]

	## XXX: These should be widget::scrolledwindow's
	set sw [ScrolledWindow $files.files \
		    -managed 0 -ipad 0 -scrollbar both -relief sunken -bd 1]
	set fList [listbox $sw.l -width 30 -height 5 \
		       -borderwidth 1 -listvariable [myvar shownfiles]]
	$sw setwidget $fList

	set profileWin [table $calls.profileWin -width 30 -height 5 \
		-relief sunken -bd {1 0} -bg white -selecttype row \
		-cols 7 -colstretchmode all -rows 1 -selectmode single \
		-titlerows 1 -variable [varname profile] \
		-browsecommand [mymethod callBrowse] \
		-highlightthickness 0 \
		-resizeborders col -yscroll [list $calls.sb set]]
	set sbp [scrollbar $calls.sb -command [list $profileWin yview]]

	# Configure the columns

	$profileWin tag configure col0     -image [$self orderImage $profsinfo(o,0)] -showtext 1 -anchor w
	$profileWin tag configure col1     -image [$self orderImage $profsinfo(o,1)] -showtext 1 -anchor w
	$profileWin tag configure col2     -image [$self orderImage $profsinfo(o,2)] -showtext 1 -anchor w
	$profileWin tag configure col3     -image [$self orderImage $profsinfo(o,3)] -showtext 1 -anchor w
	$profileWin tag configure col4     -image [$self orderImage $profsinfo(o,4)] -showtext 1 -anchor w
	$profileWin tag configure col5     -image [$self orderImage $profsinfo(o,5)] -showtext 1 -anchor w
	$profileWin tag configure col6     -image [$self orderImage $profsinfo(o,6)] -showtext 1 -anchor w
	$profileWin tag configure col_base -state disabled -anchor e
	$profileWin tag configure title    -fg black -relief raised -bd 1
	$profileWin tag row       title    0
	$profileWin tag col       col_base 0 1 2 3 4 5 6
	$profileWin tag cell      col0     0,0
	$profileWin tag cell      col1     0,1
	$profileWin tag cell      col2     0,2
	$profileWin tag cell      col3     0,3
	$profileWin tag cell      col4     0,4
	$profileWin tag cell      col5     0,5
	$profileWin tag cell      col6     0,6

	# Bugzilla 19690 ...
	#$profileWin tag configure sel -bg [pref::prefGet highlight]
	$profileWin configure -invertselected 1

	set butFrm [ttk::frame $mainFrm.butFrm]
	set showBut [ttk::button $butFrm.showBut -text "Show Code" \
		-command [mymethod showCode]]
	set clearBut [ttk::button $butFrm.clearBut -text "Clear Selected" \
		-command [mymethod clearBlockCoverage]]
	set clearAllBut [ttk::button $butFrm.clearAllBut -text "Clear All" \
		-command [mymethod clearAllCoverage]]
	set saveBut [ttk::button $butFrm.saveBut -text "Save Data" \
		-command [mymethod saveCoverageData]]
	set closeBut [ttk::button $butFrm.closeBut -text "Close" \
		-command [list destroy $coverWin]]
	set saveCheck [ttk::checkbutton $butFrm.saveCheck -text "Save all data" \
			   -variable [myvar saveall]]

	pack $showBut $clearBut $clearAllBut $saveBut $saveCheck $closeBut \
	    -fill x -pady 2

	grid $radio(uncvr) -row 1 -column 0 -sticky w -columnspan 2
	grid $radio(cvr)   -row 2 -column 0 -sticky w -columnspan 2

	grid $tabWin -row 3 -column 0 -sticky nswe -padx $pad -pady $pad
	grid $butFrm -row 3 -column 1 -sticky nw -padx $pad -pady $pad

	grid columnconfigure $mainFrm 0 -weight 1
	grid rowconfigure $mainFrm 3 -weight 1

	pack $mainFrm -fill both -expand true; # -padx $pad -pady $pad

	grid $sw -row 0 -column 0 -sticky nswe
	grid columnconfigure $files 0 -weight 1
	grid rowconfigure    $files 0 -weight 1

	grid $profileWin -row 0 -column 0 -sticky nswe
	grid $sbp        -row 0 -column 1 -sticky nswe -in $calls

	grid columnconfigure $calls 0 -weight 1
	grid columnconfigure $calls 1 -weight 0
	grid rowconfigure    $calls 0 -weight 1

	# Add default bindings and define tab order.

	bind::addBindTags $fList        coverDbgWin$self
	bind::addBindTags $showBut      coverDbgWin$self
	bind::addBindTags $clearBut     coverDbgWin$self
	bind::addBindTags $clearAllBut  coverDbgWin$self

	bind::commonBindings coverDbgWin$self [list $fList $showBut \
		$clearBut $clearAllBut]

	bind $fList <<ListboxSelect>>     [mymethod checkState]
	sel::setWidgetCmd $profileWin all [mymethod checkState]

	bind coverDbgWin$self <<Dbg_ShowCode>> "\
		[mymethod showCode] ; \
		break \
		"
	bind $fList <Double-1> "\
		[mymethod showCode] ; \
		break \
		"
	bind $fList <Return> "\
		[mymethod showCode] ; \
		break \
		"

	bind $profileWin <1> [mymethod titleResort %W %x %y]

	$tabWin select 0
	$self raiseList $tabWin
	return
    }

    method titleResort {w x y} {
	if {[$w index @$x,$y row] == 0} {
	    $self reSort [$w index @$x,$y col]
	}
	return
    }

    method reHighlightCurrentBlock {} {
	set textw [$code text]
	set tbg   [$textw cget -background]
	set tfg   [$textw cget -foreground]

	if {$radio(val)} {
	    $textw tag configure uncovered -background [pref::prefGet highlight_uncovered]
	    foreach intensity [array names intensityArray] {
		$textw tag configure "covered${intensity}" \
		    -background $tbg \
		    -foreground $tfg
	    }
	} else {
	    $textw tag configure uncovered -background $tbg

	    foreach intensity [array names intensityArray] {
		$textw tag configure "covered${intensity}" \
		    -background $intensityArray($intensity) \
		    -foreground white
	    }
	}
	return
    }

    # method highlightRanges --
    #
    #	(Re)apply the tags for both the covered or uncovered ranges,
    #	then select one set as the visible one, based on the value of
    #	radio(val).
    #
    # Arguments:
    #	blk	the block in which to highlight ranges
    #
    # Results:
    #	None.

    method highlightRanges {blk} {
	# remove any prior "*covered*" tags

	set textw [$code text]

	foreach tag [$textw tag names] {
	    if {[regexp "covered" $tag]} {
		$textw tag remove $tag 0.0 end
	    }
	}

        # Find the uncovered ranges, tag them "uncovered"

	set src       [$blkmgr getSource $blk]
        set indexList [array names currentUncoverage "${blk}:R:*"]

        foreach index $indexList {
	    set range [lindex [split $index :] 2]
	    set start [parse charindex $src $range]
	    set end   [expr {$start + [parse charlength $src $range]}]

	    coverage::tag $textw uncovered $start $end
	}

	# Find the covered ranges, and tag them "covered<intensity>"

	set indexList [array get currentCoverage "${blk}:R:*"]

	foreach {index pair} $indexList {
	    set tag   covered[expr {int([lindex $pair 1] / $istep)}]

	    set range [lindex [split $index :] 2]
	    set start [parse charindex $src $range]
	    set end   [expr {$start + [parse charlength $src $range]}]

	    coverage::tag $textw $tag $start $end
	}

	$self reHighlightCurrentBlock
	return
    }

    # method resetWindow --
    #
    #	Reset the window to be blank, or leave a message 
    #	in the text box.
    #
    # Arguments:
    #	msg	If not empty, then put this message into the 
    #		list of files.
    #
    # Results:
    #	None.

    method resetWindow {{msg {}}} {
	if {![winfo exists $coverWin]} return

	$radio(cvr)   configure -state disabled
	$radio(uncvr) configure -state disabled

	set shownfiles {} ; # Implicit clear of fList via -listvariable trace
	$self checkState
	if {$msg != {}} {
	    set shownfiles [list $msg]
	    set hasmessage 1
	}
    }

    # method showCode --
    #
    #	This function is run when we want to display the selected
    #	file in the Coverage Window.  It will interact with the
    #	text box to find the selected file, find the corresponding
    #	block, and tell the code window to display the file's coverage.
    #
    # Arguments:
    #	text	The text window.
    #
    # Results:
    #	None.

    method showCode {} {
	if {[$showBut cget -state] eq "disabled"} return

	# Bugzilla 19627 ... Code is independent of the state the backend
	# .................. is in.
	if {0} {
	    set state [$gui getCurrentState]
	    if {$state != "running" && $state != "stopped"} {
		return
	    }
	}

	# Show the selected block in the code window, and get the current
	# coverage from the nub. -- Actually from the locally cached
	# profile information.

	$gui showCode [$self getSelectedLocation]
	#$self updateWindow
    }

    # method showWindow --
    #
    #	Create the Coverage Window that will display
    #	all the instrumented files in the running application. 
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	The name of the Coverage Window's toplevel.

    method showWindow {} {
	if {[winfo exists $coverWin]} {
	    $self updateWindow
	    wm deiconify $coverWin
	} else {
	    $self createWindow
	    $self updateWindow
	}
	focus $fList
	return $coverWin
    }

    # method tabulateCoverage --
    #
    #	Compare expected coverage with existing coverage.  Update
    #	currentCoverage and currentUncoverage arrays.
    #
    # Arguments:
    #	coverage	A list of {location numRepeatedCoverage} pairs
    #			that represent the locations covered since the
    #			last breakpoint.
    #
    # Results:
    #	No value.

    method tabulateCoverage {cover} {
	# puts stderr tabulateCoverage

	# Break coverage and timings apart.

	foreach {coverage timing} $cover break

	# First tally locations and number of calls.

	# For each covered location store the block number, range, line number,
	# total number of times the location was covered.

	foreach {location qty} $coverage {
	    set location [lindex [split $location :] 1]
	    set blk      [::loc::getBlock $location]
	    set line     [::loc::getLine  $location]
	    set range    [::loc::getRange $location]

	    # Bugzilla 19622 ...
	    # Look for existing data, add the new data to it. Do not
	    # replace or the profile counters will be off.

	    set key ${blk}:R:${range}

	    if {[info exists currentCoverage($key)]} {
		# Tally up
		incr qty [lindex $currentCoverage($key) 1]
	    }
	    # From here on proceed as usual, now that the profile counter
	    # has a correct(ed) value.

	    set currentCoverage($key) [list $line $qty]

	    if {$qty > $maxRepeatedCoverage} {
		set maxRepeatedCoverage $qty
	    }
	}

	# Now tally the timings

	foreach {location times} $timing {
	    set location [lindex [split $location :] 1]
	    set blk      [::loc::getBlock $location]
	    set line     [::loc::getLine  $location]
	    set range    [::loc::getRange $location]

	    set key ${blk}:R:${range}

	    foreach {min max total} $times break

	    if {[info exists currentProfile($key)]} {
		# Tally up
		foreach {mins maxs totals} $currentProfile($key) break
		incr total $totals
		if {$mins < $min} {set min $mins}
		if {$maxs < $max} {set max $maxs}
	    }

	    set currentProfile($key) [list $min $max $total]
	}


	set n [$blkmgr blockCounter]
	for {set blk 1} {$blk <= $n} {incr blk} {
	    # Optimization:  Only calculate all possible ranges if
	    # currentUncoverage($blk) doesn't exist.  Once all possible
	    # ranges are calculated, just un-set the ones that have been
	    # covered since the last breakpoint.

	    if {[info exists currentUncoverage($blk)]} {
		foreach index [array names currentCoverage ${blk}:R:*] {
		    catch {unset currentUncoverage($index)}
		}
	    } else {
		set expectedRanges [$blkmgr getRanges $blk]
		array set rmap     [$blkmgr getRMap   $blk]
		
		# remove uninstrumented block from the array

		if {$expectedRanges == -1} {
		    $self clearCoverageArray $blk
		    continue
		}

		set currentUncoverage($blk) 1
		foreach range $expectedRanges {
		    if {![info exists currentCoverage(${blk}:R:${range})]} {
			set currentUncoverage(${blk}:R:${range}) \
			    $rmap($range)
		    }
		}
		unset rmap
	    }
	}
	return
    }

    # method tagRange --
    #
    #	Given a range, tag that range in the code display.
    #
    # Arguments:
    #	blk	the block in which to tag the range
    #	range	the range to tag
    #	tag	the value of the tag to apply
    #
    # Results:
    #	None.

    method tagRange {blk range tag} {
	set textw [$code text]
	set src   [$blkmgr getSource $blk]
	set start [parse charindex $src $range]
	set end   [expr {$start + [parse charlength $src $range]}]

	set cmdStart [$textw index "0.0 + $start chars"]
	set cmdMid   [$textw index "$cmdStart lineend"]
	set cmdEnd   [$textw index "0.0 + $end chars"]

	# If cmdEnd > cmdMid, the range spans multiple lines, we only
	# want to tag the first line.
	if {[$textw compare $cmdEnd > $cmdMid]} {
	    set cmdEnd $cmdMid
	}

	#puts "$code text tag add $tag $cmdStart $cmdEnd"

	$textw tag add $tag $cmdStart $cmdEnd
	return
    }

    # method updateWindow --
    #
    #	Populate the Coverage Window's list box with file names
    #	currently instrumented in the running app. 
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateWindow {} {

	if {![winfo exists $coverWin]} {
	    return
	}

	if {[info exists afterID]} {
	    after cancel $afterID
	    unset afterID
	}

	# If the state is not running or stopped, then delete
	# the display and disable the "Show Code" button

	set yview  [lindex [$fList yview] 0]
	set shownfiles {}
	set hasmessage 0

	# Find the unique names of the files that are instrumented.
	# Store the corresponding block number for each file in the
	# instrumentedBlock array.  Add each file to the text widget.

	foreach index [array names instrumentedBlock] {
	    unset instrumentedBlock($index)
	}
	foreach {file block} [$fdb getUniqueFiles] {
	    # Bugzilla 19627 ... Use currentcoverage as source for which
	    # files we have coverage information, instead of the
	    # instrument markers. The instrument markers are reset when
	    # the debugged application exists.

	    # Bugzilla 23465. Had a constant value in the query instead of
	    # the actual block number.

	    if {[llength [array names currentCoverage ${block}:*]] > 0} {
		set instrumentedBlock($file) $block
		lappend shownfiles $file
	    }
	}

	$radio(cvr)   configure -state normal
	$radio(uncvr) configure -state normal
	$fList yview moveto $yview

	# Also convert current coverage information into a sortable list,
	# and copy that list into the array for the table (updateProfile).

	$self CalcColors
	$self updateProfile
	$self checkState

	set blk [$gui getCurrentBlock]
	if {$blk ne ""} {
	    $self highlightRanges $blk
	}

	# restore the blue or red color if one was previously present

	$code text tag configure highlight \
		-background [pref::prefGet highlight]
	$code text tag configure highlight_error \
		-background [pref::prefGet highlight_error]
	return
    }

    method CalcColors {} {
	# For each <step> times a line is covered, its intensity is
	# There are <numShades> possible intensities, and <step> must
	# be at least 2.

	set istep [expr {int($maxRepeatedCoverage / $numShades) + 1}]
	if {$istep < 2} {
	    set istep 2
	}

	#puts "numShades           = $numShades"
	#puts "maxRepeatedCoverage = $maxRepeatedCoverage"
	#puts "step                = $istep"

	# Find the covered ranges, and tag them "covered<intensity>"

	set indexList [array get currentCoverage "*:R:*"]

	foreach {index pair} $indexList {
	    set intensity [expr {int([lindex $pair 1] / $istep)}]
	    set intensityArray($intensity) .
	    #puts "[lindex [split $index :] 2] intensity $intensity"
	}

	# For each increasing intensity, darken the background color
	# We use 'shade' to compute the color between pref. and black

	set orig [pref::prefGet highlight_profiled]
	set dest #000000 ; # black

	# Bugfix => steps is used to convert/map absolute
	# call-frequencies into intensities. These are now mapped to
	# colors through numshades. Using steps here is plain wrong.

	# Map from intensities to shader fractions.
	# min intensity - fraction 0 - original color
	# max intensity - fraction 1 - black

	set intensities [lsort [array names intensityArray]]

	if {[llength $intensities] < 1} {return}

	set minIntensity [lindex $intensities 0]
	set maxIntensity [lindex $intensities end]

	if {$minIntensity == $maxIntensity} {
	    # Horizontal line
	    set a 0
	    set n 0
	} else {
	    # Angled line
	    set a [expr {1.0/($maxIntensity - $minIntensity)}]
	    set n [expr {$a * $minIntensity}]
	}

	#puts "($maxIntensity - $minIntensity) / $numShades = $diff"

	foreach intensity $intensities {
	    set frac  [expr {$a * $intensity + $n}]
	    set shade [coverage::shade $orig $dest $frac]

	    #puts "shade $intensity => $shade (${shade})"

	    set intensityArray($intensity) $shade

	    $code text tag configure "covered${intensity}" \
		    -background $shade -foreground white

	    $profileWin tag configure "covered${intensity}" \
		    -background $shade -foreground white
	}
	return
    }

    method intensity {calls} {
	return [expr {int($calls / $istep)}]
    }

    method color {calls} {
	return $intensityArray([intensity $calls])
    }

    method updateProfile {} {
	#puts updateProfile

	set indexList [array get currentCoverage "*:R:*"]

	set proflist {}
	foreach {index pair} $indexList {
	    foreach {blk __ range} [split $index :] break
	    foreach {line calls}   $pair break

	    set file [file tail [set ffile [$blkmgr getFile $blk]]]
	    set loc [loc::makeLocation $blk $line $range]

	    set item [list $calls $file $line]

	    if {[info exists currentProfile($index)]} {
		foreach {min max total} $currentProfile($index) break
		lappend item $min [expr {double($total)/double($calls)}] $max $total
	    } else {
		lappend item {} {} {} {}
	    }
	    lappend item $loc $ffile
	    lappend proflist $item
	}

	$self sortProfile
	$self setProfile
	return
    }

    method setProfile {} {
	set n 1
	foreach item $proflist {
	    foreach {calls file line min avg max total loc} $item break
	    set profile($n,0) $calls
	    set profile($n,1) $file
	    set profile($n,2) $line
	    set profile($n,3) $min
	    set profile($n,4) $avg
	    set profile($n,5) $max
	    set profile($n,6) $total
	    set profile($n,7) $loc ; # Invisible !

	    $profileWin tag row covered[$self intensity $calls] $n

	    # puts stderr "\[\] $calls $file $line $loc - covered[$self intensity $calls] - [$self color $calls]"

	    incr n
	}

	$profileWin configure -rows $n
	return
    }

    method sortProfile {} {
	foreach idx $profsort {
	     #puts stderr "$idx $profsinfo(t,$idx) $profsinfo(o,$idx) =| [lindex $proflist 0]"

	    set proflist [lsort -index $idx $profsinfo(t,$idx) $profsinfo(o,$idx) $proflist]
	}

	return
    }


    method getSelectedLocation {} {
	switch -exact -- $activePane {
	    Files {
		set sel [$fList index active]
		set file [lindex $shownfiles $sel]

		# Get the name and block number associated with the
		# selected file.
		
		set blk $instrumentedBlock($file)
		set loc [loc::makeLocation $blk {}]
	    }
	    Calls {
		if {![llength [$profileWin curselection]]} return

		# In our configuration curselection always returns a list
		# of three indices (row-selection, 3 columns per row).
		# Each index is row,col.

		set sel [$profileWin curselection]
		set row [lindex [split [lindex $sel 0] ,] 0]

		# Get the location associated with the selected list
		# item (invisible cell).

		set loc $profile($row,7)
	    }
	}

	return $loc
    }

    method callBrowse {} {
	$self checkState
	return
    }


    method reSort {col} {
	set pos [lsearch -exact $profsort $col]
	lappend profsort $col
	if {$pos < 0} {
	    set profsort [lrange $profsort 1 end]
	} else {
	    set profsort [lreplace $profsort $pos $pos]
	}

	set profsinfo(o,$col) [$self orderInvert $profsinfo(o,$col)]
	$profileWin tag configure col$col -image [$self orderImage $profsinfo(o,$col)]

	$self sortProfile
	$self setProfile
	return
    }

    method orderImage {order} {
	return $profsinfo(img,$order)
    }

    method orderInvert {order} {
	return $profsinfo(neg,$order)
    }

    method saveCoverageData {} {
	# Select a file and store the profiling information into it (CSV format)

	set file [tk_getSaveFile \
		-title     "Select output file" \
		-parent    $coverWin.mainFrm \
		-filetypes {{Csv {*.csv}} {All {*}}} \
		-initialdir $lastdir \
		]

	if {$file == {}} {return}
	set lastdir [file dirname $file]

	set fh [open $file w]
	
	puts $fh [csv::join {NrCallsToCmd Filename CmdLine Min Avg Max Total CmdCharIndex CmdLength}]

	# Saving profiling information for covered locations.
	foreach item $proflist {
	    set ff   [lindex $item 8]
	    set item [lreplace $item 8 8]
	    set item [lreplace $item 1 1 $ff]
	    foreach {ci cs} [lindex [lindex $item 7] 2] break
	    set item [lreplace $item 7 7 $ci $cs]
	    puts $fh [csv::join $item]
	}

	if {$saveall} {

	    # Now saving information for uncovered locations.  We have
	    # to make up most of the data, however the fact that the
	    # lcoations were not called makes that easy. Zero all the
	    # way, except for the location information itself.

	    foreach index [array names currentUncoverage "*:R:*"] {
		set line $currentUncoverage($index)
		foreach {block _ range} [split $index :] break
		set file [$blkmgr getFile $block]
		foreach {start length} $range break
		#              calls file  line  min avg max total index  length
		set item [list 0     $file $line 0   0   0   0     $start $length]
		puts $fh [csv::join $item]
	    }

	    # Save more. Go over all blocks, find those which have no
	    # coverage data at all (nothing even computed), then save
	    # all their ranges as uncovered.

	    foreach block [$blkmgr blocks] {
		if {[info exists currentUncoverage($blk)]} continue
		if {![$blkmgr isInstrumented $block]}      continue
		# This block has no uncoverage data computed for it yet.
		# This means that it is uncovered as a whole. We also
		# know that it is instrumented. Un-instrumented
		# un-covered blocks are not saved. It is simply not
		# possible. We have no data about it ranges.

		array set rmap [$blkmgr getRMap   $blk]
		set file [$blkmgr getFile $block]
		foreach range [$blkmgr getRanges $blk] {
		    set line $rmap($range)
		    foreach {start length} $range break
		    #              calls file  line  min avg max total index  length
		    set item [list 0     $file $line 0   0   0   0     $start $length]
		    puts $fh [csv::join $item]
		}
		unset rmap
	    }
	}

	close $fh
	return
    }

    method hasCoverage {} {
	return [expr {[array size currentCoverage] > 0}]
    }

    method updateProfHighlights {} {
	# Pickup any changes to the color for profiling.

	$self CalcColors
	$self reHighlightCurrentBlock
	return
    }
    method updateCovHighlights {} {
	# Pickup any changes to the color for profiling.

	$self reHighlightCurrentBlock
	return
    }
}

# coverage::globalInit --
#
#	Set up the debugger event hooks for monitoring document status.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc coverage::globalInit {} {

    tool::addButton $image::image(win_cover) \
	    $image::image(win_cover) \
	    {Display the Code Coverage Window.} \
	    {maingui covShowWindow}

    # Add an entry to the View menu.

    menu::insert view "Connection status*" command \
	    -label "Code Coverage..." \
	    -command {maingui covShowWindow} -underline 0

    return
}

# rgb2dec --
#
#   Turns #rgb into 3 elem list of decimal vals.
#
# Arguments:
#   c		The #rgb hex of the color to translate
# Results:
#   Returns a #RRGGBB or #RRRRGGGGBBBB color
#
proc coverage::rgb2dec c {
    set c [string tolower $c]
    if {[regexp -nocase {^#([0-9a-f])([0-9a-f])([0-9a-f])$} $c x r g b]} {
	# double'ing the value make #9fc == #99ffcc
	scan "$r$r $g$g $b$b" "%x %x %x" r g b
    } else {
	if {![regexp {^#([0-9a-f]+)$} $c junk hex] || \
		[set len [string length $hex]]>12 || $len%3 != 0} {
	    if {[catch {winfo rgb . $c} rgb]} {
		return -code error "bad color value \"$c\""
	    } else {
		return $rgb
	    }
	}
	set len [expr {$len/3}]
    	scan $hex "%${len}x%${len}x%${len}x" r g b
    }
    return [list $r $g $b]
}


# shade --
#
#   Returns a shade between two colors
#
# Arguments:
#   orig	start #rgb color
#   dest	#rgb color to shade towards
#   frac	fraction (0.0-1.0) to move $orig towards $dest
# Results:
#   Returns a shade between two colors based on the
# 
proc coverage::shade {orig dest frac} {
    if {$frac >= 1.0} { return $dest } elseif {$frac <= 0.0} { return $orig }
    foreach {origR origG origB} [rgb2dec $orig] \
	    {destR destG destB} [rgb2dec $dest] {
	set shade [format "\#%02x%02x%02x" \
		[expr {int($origR+double($destR-$origR)*$frac)}] \
		[expr {int($origG+double($destG-$origG)*$frac)}] \
		[expr {int($origB+double($destB-$origB)*$frac)}]]
	return $shade
    }
}


proc coverage::tag {textw tag start end} {

    # Note: This section, excluding the actual tagging operation is
    # the time-expensive part of the loop (in the caller). Memoization
    # of the results will not amortize for this one loop, because all
    # ranges are different. It will amortize only over many
    # invokations of the loop, i.e. the user switching back and forth
    # between different files (blocks).

    set cmdStart [$textw index "0.0 + $start chars"]
    set cmdMid   [$textw index "$cmdStart lineend"]
    set cmdEnd   [$textw index "0.0 + $end chars"]

    # If cmdEnd > cmdMid, the range spans multiple lines, we only
    # want to tag the first line.

    if {[$textw compare $cmdEnd > $cmdMid]} {
	set cmdEnd $cmdMid
    }

    $textw tag add $tag $cmdStart $cmdEnd
    return
}

# ### ### ### ######### ######### #########
## Ready to go

package provide coverage 1.0
