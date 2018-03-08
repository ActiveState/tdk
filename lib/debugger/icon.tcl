# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# icon.tcl --
#
#	This file manages all of the icon drawing as well as 
#	setting the correct state in the nub based on the type
#	of icon drawn.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: icon.tcl,v 1.3 2000/10/31 23:30:58 welch Exp $

# ### ### ### ######### ######### #########
## NOTES
##
## The code handling the drawing of icons is severe need of an
## overhaul.
##
## In the beginning we had only one situation where multiple icons had
## to be drawn: location marker (current or history) over a breakpoint
## indicator (line or variable). Indicators for variable breakpoints
## are drawn in preference to line breakpoints, that is ok given that
## they show up only during runtime and have high priority.
##
## Then came spawnpoints, which can share locations with line
## breakpoints. At first we drew line breakpoints in preference to
## spawnpoints. Now we compose their icons, 4 possible states
## (enable/disabled, for each). Due to the current architecture of the
## code (assuming replacement over composition) we have now lots of
## more or less duplicated and similar code. And now that we compose
## the bp/sp icons, we need more composed icons for the location
## markers too, more similar/duplicate code.
##
## The upcoming skip markers (boeing) will excerbate the
## problem. Getting rid of the precomposed icons is possible, but
## problematic given the state of Tk's handling of transparency. A
## first step would be to reorganize the code to remove duplication,
## refactor similarities, in general make mapping from tag-sets to
## icon to show easy, data-driven, instead of hardwired in the code.

# ### ### ### ######### ######### #########
## Requisites

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type icon {

    # ### ### ### ######### ######### #########

    variable             code
    variable             dbg
    variable             brk
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
	set brk     [$engine_ brk]
	return
    }

    # ### ### ### ######### ######### #########

    # method getState --
    #
    #	Get the state of the BP based on the icon in the code bar.
    #
    # Arguments:
    #	text 	The Code Bar text widget.
    #	line	The line number in the text widget to check.
    #
    # Results:
    #	The state of the BP based on the icon

    method getState {text line} {
	foreach tag [$text tag names $line.0] {
	    switch $tag {
		enabledSpawn -
		disabledSpawn -
		enabledBreak -
		disabledBreak -
		mixedBreak {
		    return $tag
		}
	    }
	}
	return noBreak
    }

    # method getLBPState --
    #
    #	Return the state of the breakpoint for a <loc> type.
    #	The CodeBar only displays one icon per line, so the 
    #	breakpoint state is a combination of all breakpoints
    #	that exist on this line.  A breakpoint's state is 
    #	"mixed" if there are one or more enabled AND disabled
    #	breakpoints for the same line.
    #
    # Arguments:
    #	loc	A <loc> opaque type that contains the location 
    #		of the breakpoint in a script.
    #
    # Results:
    #	The state of the breakpoint at <loc>.  Either: enabledBreak,
    #	disabledBreak, mixedBreak or noBreak.

    method getLBPState {loc} {
	set state noBreak
	set bps [$dbg getLineBreakpoints $loc]
	foreach bp $bps {
	    if {[$brk getState $bp] eq "enabled"} {
		if {$state eq "disabled"} {
		    return mixedBreak
		} 
		set state enabledBreak
	    } else {
		if {$state eq "enabled"} {
		    return mixedBreak
		} 
		set state disabledBreak
	    }
	}
	return $state
    }

    # method toggleLBPOnOff --
    #
    #	Toggle the breakpoint on and off.  Based on the current
    #	state of the breakpoint, determine the next valid state,
    #	delete any existing icon and draw a new icon if necessary.
    #
    # Arguments:
    #	text		Text widget that contains breakpoint icons.
    #	index		Location to delete and insert icons.
    #	loc		The <loc> type needed set breakpoints.
    #	breakState	The current state of the breakpoint.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    method toggleLBPOnOff {text index loc breakState {pcType {}}} {

	# We use information from spawnpoints to determine
	# if we have to use merge states for display

	set loc [$code makeCodeLocation $text $index]
	set suffix [$self getSPState $loc]
	if {$suffix eq "noSpawn"} {
	    set suffix ""
	} else {
	    set suffix _$suffix
	}

	switch -exact $breakState {
	    noBreak {
		# If the "current" icon is on the current line,
		# delete it, then set the state to "enabled".
		if {$pcType != {}} {
		    $text delete $index
		}

		$dbg addLineBreakpoint $loc
		pref::groupSetDirty Project 1
		$self drawLBP $text $index enabledBreak$suffix $pcType
	    }
	    enabledBreak {
		# Delete "enabled" icon and set the state to "no break".
		$text delete $index

		$self setLBP  noBreak $loc 
		$self drawLBP $text $index noBreak $pcType
	    }
	    disabledBreak -
	    mixedBreak {
		# Delete the icon and set the state back to "enabled".
		$text delete $index

		$self setLBP  enabledBreak $loc 
		$self drawLBP $text $index enabledBreak$suffix $pcType
	    }
	    default {
		error "unknown line breakpoint state: $breakState"
	    }
	}
    }

    # method toggleLBPEnableDisable --
    #
    #	Toggle the breakpoint to enabled and disabled.  Based on the 
    #	current state of the breakpoint, determine the next valid 
    #	state, delete any existing icon, and draw a new icon if 
    # 	necessary.
    #
    # Arguments:
    #	text		Text widget that contains breakpoint icons.
    #	index		Location to delete and insert icons.
    #	loc		The <loc> type needed set breakpoints.
    #	breakState	The current state of the breakpoint.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    method toggleLBPEnableDisable {text index loc breakState {pcType {}}} {
	# This we got as argument! No need to recompute.
	#set loc [$code makeCodeLocation $text $index]

	set suffix [$self getSPState $loc]
	if {$suffix eq "noSpawn"} {
	    set suffix ""
	} else {
	    set suffix _$suffix
	}

	switch -exact $breakState {
	    noBreak {
		return
	    }
	    enabledBreak -
	    mixedBreak {
		# Delete the icon and set the state to "disabled".
		$self setLBP  disabledBreak $loc 
		if {$text != {}} {
		    $text delete $index
		    $self drawLBP $text $index disabledBreak$suffix $pcType
		}
	    }
	    disabledBreak {
		# Delete the disabled icon and set the state back to "enabled".
		$self setLBP  enabledBreak $loc 
		if {$text != {}} {
		    $text delete $index
		    $self drawLBP $text $index enabledBreak$suffix $pcType
		}
	    }
	    default {
		error "unknown line breakpoint state: $breakState"
	    }
	}
    }

    # method setLBP --
    #
    #	Set the new state of the breakpoint in the nub.
    #
    # Arguments:
    #	state	The new state of the breakpoint.
    #	loc	The <loc> object used to set the breakpoint.
    #
    # Results:
    #	None.

    method setLBP {state loc} {
	set bps [$dbg getLineBreakpoints $loc]
	switch -exact $state {
	    noBreak {
		foreach bp $bps {
		    pref::groupSetDirty Project 1
		    $dbg removeBreakpoint $bp
		}
	    }
	    enabledBreak {
		foreach bp $bps {
		    $dbg enableBreakpoint $bp
		}
	    }
	    disabledBreak {
		foreach bp $bps {
		    $dbg disableBreakpoint $bp
		}
	    }
	    default {
		error "unknown state in $self setLBP: $state"
	    }
	}
    }

    # method drawLBP --
    #
    #	Draw a new breakpoint icon into the text widget.
    #	It is assumed that any out-dated icons on this line 
    #	have already been deleted.
    #
    #	Icons are embedded into the text widget with two tags
    #	bound to them: setBreak and <tagName>.  SetBreak is used
    #	to identify it as a generic breakpoint icon, and
    #	<tagName> is used to identify the type of breakpoint.
    #
    # Arguments:
    #	text		The text widget to draw the icon into.
    #	index		The location in the text widget to insert the icon.
    #	breakState	The type of icon to draw.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    method drawLBP {text index breakState {pcType {}}} {
	#puts draw/LBP/--/$text/$index/--/$breakState/$pcType/

	set tagNameB {} ;# No secondary tag
	switch -exact $breakState {
	    noBreak {
		if {$pcType != {}} {
		    $text image create $index -name currentImage \
			    -image $image::image($pcType)
		}
		return
	    }
	    enabledBreak {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_enable
		} else {
		    set imageName enabledBreak
		    set imageType break_enable
		}
		set tagName enabledBreak
	    }
	    disabledBreak {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_disable
		} else {
		    set imageName disabledBreak
		    set imageType break_disable
		}
		set tagName disabledBreak
	    }
	    mixedBreak {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_mixed
		} else {
		    set imageName mixedBreak
		    set imageType break_mixed
		}
		set tagName mixedBreak
	    }
	    enabledBreak_enabledSpawn {
		# Merge states
		# NOTE: This code is __duplicated in 'drawSP'__.
		# FUTURE: Rationalize the toggle, set, and draw commands.

		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_bs_ee
		} else {
		    set imageName enabledBreakSpawn
		    set imageType breakspawn_enable
		}
		set tagName  enabledBreak
		set tagNameB enabledSpawn
	    }
	    enabledBreak_disabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_bs_ed
		} else {
		    set imageName enabledBreakDisabledSpawn
		    set imageType breakspawn_enabledisable
		}
		set tagName  enabledBreak
		set tagNameB disabledSpawn
	    }
	    disabledBreak_enabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_bs_de
		} else {
		    set imageName disabledBreakEnabledSpawn
		    set imageType breakspawn_disableenable
		}
		set tagName  disabledBreak
		set tagNameB enabledSpawn
	    }
	    disabledBreak_disabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_bs_dd
		} else {
		    set imageName disabledBreakSpawn
		    set imageType breakspawn_disable
		}
		set tagName  disabledBreak
		set tagNameB disabledSpawn
	    }
	    mixedBreak_enabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_enable
		} else {
		    set imageName mixedBreakEnabledSpawn
		    set imageType breakspawn_mixedenable
		}
		set tagName  mixedBreak
		set tagNameB enabledSpawn
	    }
	    mixedBreak_disabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_enable
		} else {
		    set imageName mixedBreakdisabledSpawn
		    set imageType breakspawn_mixeddisable
		}
		set tagName  mixedBreak
		set tagNameB disabledSpawn
	    }
	    default {
		error "unknown codebar break state: $breakState"
	    }
	}
	$text image create $index -name $imageName \
		-image $image::image($imageType)
	$text tag add $tagName $index
	if {$tagNameB != {}} {
	    $text tag add $tagNameB $index
	}
	$text tag add setBreak $index
    }

    # method getVBPState --
    #
    #	Get the VBP state for a specific variable.
    #
    # Arguments:
    #	level	The stack level of the variable location.
    #	name	The variable name.
    #
    # Results:
    #	The VBP state: enabledBreak, disabledBreak or noBreak.

    method getVBPState {level name} {
	set state noBreak

	if {[$gui getCurrentState] eq "stopped"} {
	    set vbps [$dbg getVarBreakpoints $level $name]
	    foreach vbp $vbps {
		if {[$brk getState $vbp] eq "enabled"} {
		    set state enabledBreak
		} elseif {$state ne "enabled"} {
		    set state disabledBreak
		}
	    }
	}
	return $state
    }

    # method toggleVBPOnOff --
    #
    #	Toggle the VBP state between on and off.
    #
    # Arguments:
    #	level 		The stack level of the variable location.
    #	name		The name of the variable.
    #	breakState	The current state of the breakpoint.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    # FUTURE: Move this out of icon. This has nothing to do with icons
    # anymore, only with state switching, and giving the appropriate
    # commands to the low-level engine. And the latter part might
    # actually be better done in the low-level engine itself too.

    method toggleVBPOnOff {level name breakState {pcType {}}} {
	switch -exact $breakState {
	    noBreak {
		set bp [$dbg addVarBreakpoint $level $name]
		$brk setData $bp [list [list $level $name] [list]]
		return enabledBreak
	    }
	    enabledBreak {
		$self setVBP noBreak $level $name
		return noBreak
	    }
	    disabledBreak {
		$self setVBP enabledBreak $level $name
		return enabledBreak
	    }
	    default {
		error "unknown variable breakpoint state: $breakState"
	    }
	}
    }

    # method toggleVBPEnableDisable --
    #
    #	Toggle the VBP state to enabled or disabled and redraw the icon
    #	in the text widget.
    #
    # Arguments:
    #	text 		The text widget to redraw the VBP icon in.
    #	index		Location to delete and insert icons.
    #	level 		The stack level of the variable location.
    #	name		The name of the variable.
    #	breakState	The current state of the breakpoint.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    method toggleVBPEnableDisable {level name breakState {pcType {}}} {

	# FUTURE: Move icon handling into breakWin, then see 'toggleVBPOnOff'.
	# FUTURE/Alt: convert breakwin to treectrl (single-column, but icons).

	switch -exact $breakState {
	    noBreak {
		return noBreak
	    }
	    enabledBreak {
		$self setVBP disabledBreak $level $name
		return disabledBreak
	    }
	    disabledBreak {
		$self setVBP enabledBreak  $level $name
		return enabledBreak
	    }
	    default {
		error "unknown variable breakpoint state: $breakState"
	    }
	}
    }

    # method setVBP --
    #
    #	Set the new state of the VBP in the nub.
    #
    # Arguments:
    #	state		The new state of the breakpoint.
    #	level 		The stack level of the variable location.
    #	name		The name of the variable.
    #
    # Results:
    #	None.

    method setVBP {state level name} {
	if {[$gui getCurrentState] ne "stopped"} {
	    error "$self setVBP called when state is running"
	}
	set bps [$dbg getVarBreakpoints $level $name]
	switch -exact $state {
	    noBreak {
		foreach bp $bps {
		    $dbg removeBreakpoint $bp
		}
	    }
	    enabledBreak {
		foreach bp $bps {
		    $dbg enableBreakpoint $bp
		    set orig [lindex [$brk getData $bp] 0]
		    if {$orig == {}} {
			$brk setData $bp [list [list $level $name] [list]]
		    } else {
			$brk setData $bp [list $orig [list $level $name]]
		    }
		}
	    }
	    disabledBreak {
		foreach bp $bps {
		    $dbg disableBreakpoint $bp
		    set orig [lindex [$brk getData $bp] 0]
		    $brk setData $bp [list $orig [list $level $name]]
		}
	    }
	    default {
		error "unknown state in $self setVBP: $state"
	    }
	}    
    }

    # method drawVBP --
    #
    #	Draw a new breakpoint icon into the text widget.
    #	It is assumed that any out-dated icons on this line 
    #	have already been deleted.
    #
    #	Icons are embedded into the text widget with two tags
    #	bound to them: setBreak and <tagName>.  SetBreak is used
    #	to identify it as a generic breakpoint icon, and
    #	<tagName> is used to identify the type of breakpoint.
    #
    # Arguments:
    #	text		The text widget to draw the icon into.
    #	index		The location in the text widget to insert the icon.
    #	breakState	The type of icon to draw.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    method drawVBP {text index breakState {pcType {}}} {
	# Var break points are only drawn where they occur.  If the
	# pcType is "history" then we should treat this as a line break 
	# point instead.

	if {$pcType eq "history"} {
	    $self drawLBP $text $index $breakState $pcType
	    return
	}

	switch -exact $breakState {
	    noBreak {
		if {$pcType != {}} {
		    $text image create $index -name currentImage \
			    -image $image::image($pcType)
		}
		return
	    }
	    enabledBreak {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_var
		} else {
		    set imageName enabledBreak
		    set imageType var_enable
		}
		set tagName enabledBreak
	    }
	    disabledBreak {
		if {$pcType != {}} {
		    error "This shouldn't happen:  current over disabled VBP!"
		    set imageName currentImage
		    set imageType ${pcType}_var_disable
		} else {
		    set imageName disabledBreak
		    set imageType var_disable
		}
		set tagName disabledBreak
	    }
	    default {
		error "unknown codebar break state: $breakState"
	    }
	}
	$text image create $index -name $imageName \
		-image $image::image($imageType)
	$text tag add $tagName $index
	$text tag add setBreak $index
    }

    # method getVBPOrigLevel --
    #
    #	Get the var name from when the VBP was created.
    #
    # Arguments:
    #	vbp	The VBP handle.
    #
    # Results:
    #	Return the var name from when the VBP was created.

    method getVBPOrigLevel {vbp} {
	return [lindex [lindex [$brk getData $vbp] 0] 0]
    }

    # method getVBPOrigName --
    #
    #	Get the stack level from when the VBP was created.
    #
    # Arguments:
    #	vbp	The VBP handle.
    #
    # Results:
    #	Return the stack level from when the VBP was created.

    method getVBPOrigName {vbp} {
	return [lindex [lindex [$brk getData $vbp] 0] 1]
    }

    # method getVBPNextName --
    #
    #	Get the var name from when the VBP was last set.
    #
    # Arguments:
    #	vbp	The VBP handle.
    #
    # Results:
    #	Return the var name from when the VBP was last set..

    method getVBPNextName {vbp} {
	return [lindex [lindex [$brk getData $vbp] 1] 1]
    }

    # method getVBPNextLevel --
    #
    #	Get the stack level from when the VBP was last set.
    #
    # Arguments:
    #	vbp	The VBP handle.
    #
    # Results:
    #	Return the stack level from when the VBP was last set.

    method getVBPNextLevel {vbp} {
	return [lindex [lindex [$brk getData $vbp] 1] 0]
    }

    # method isCurrentIconAtLine --
    #
    #	Determines if the "current" icon, if it exists, is
    #	on the same line as index.
    #
    # Arguments:
    #	text	Text widget to look for the "current" icon.
    #	index	Text index where to look for the "current" icon.
    #
    # Results:
    #	Boolean: true if "current" icon is on the same line
    #	as index.

    method isCurrentIconAtLine {text index} {
	set start  [$text index "$index linestart"]
	if {[catch {set cIndex [$text index currentImage]}] == 0} {
	    if {$start == $cIndex} {
		return 1
	    }
	}
	return 0
    }

    # method setCurrentIcon --
    #
    #	Draw the "current" icon at index.  If an icon is
    #	already on this line, delete it, and draw the 
    #	overlapped icon.
    #
    # Arguments:
    #	text	The text widget to insert the icon in to.
    #	index	The location in the text widget to insert the icon.
    #
    # Results:
    #	None.

    method setCurrentIcon {text index breakType pcType} {
	#puts ____/SCI/--/$text/$index/--/$breakType/$pcType/

	if {$breakType eq "var"} {
	    $self drawVBP $text $index enabledBreak $pcType
	} else {
	    set loc [$code makeCodeLocation $text $index]

	    # We can have line breakpoints here, and/or spawnpoints.

	    set breakState [$self getLBPState $loc]
	    set spawnState [$self getSPState  $loc]

	    if {($spawnState eq "noSpawn") && ($breakState ne "noBreak")} {
		# Neither breakpoint nor spawnpoint are present. Use
		# bp drawing to draw nothing.

		$text delete $index
		$self drawLBP $text $index $breakState $pcType
	    } elseif {($spawnState ne "noSpawn") && ($breakState eq "noBreak")} {
		# Spawnpoint present, no breakpoints. Draw the spawnpoint.

		$text delete $index
		$self drawSP $text $index $spawnState $pcType
	    } elseif {($spawnState eq "noSpawn") && ($breakState eq "noBreak")} {
		# Breakpoint present, no spawnpoints. Draw the bp's.

		$self drawLBP $text $index $breakState $pcType
	    } else {
		# Both spawn and break are present. Draw a mixture of
		# both bp and sp icons.

		$text delete $index
		$self drawLBP $text $index ${breakState}_${spawnState} $pcType
	    }
	}
	return
    }

    # method unsetCurrentIcon --
    #
    #	Delete the "current" icon and draw the icon that
    #	represents the breakpoint state on this line.
    #
    # Arguments:
    #	text	The text widget to delete the icon in from.
    #	index	The location of the icon.
    #
    # Results:
    #	None.

    method unsetCurrentIcon {text iconIndex} {
	# Test to see if the index passed in was valid.  It might be 
	# "currentImage" which may or may not exist.  If it does set
	# "index" to the numeric index.

	if {[catch {$text index $iconIndex} index]} {
	    return
	}
	set loc [$code makeCodeLocation $text $index]
	set breakState [$self getLBPState $loc]
	$text delete $index
	$self drawLBP $text $index $breakState
	return
    }

    # method drawSyn --
    #
    #	Draw a new syntax error/warn icon into the text widget.
    #	It is assumed that any out-dated icons on this line 
    #	have already been deleted.
    #
    #	Icons are embedded into the text widget with no tags
    #	bound to them: setBreak and <tagName>.  SetBreak is used
    #	to identify it as a generic breakpoint icon, and
    #	<tagName> is used to identify the type of breakpoint.
    #
    # Arguments:
    #	text		The text widget to draw the icon into.
    #	index		The location in the text widget to insert the icon.
    #	synType		The type of icon to draw.
    #
    # Results:
    #	None.

    method drawSyn {text index synType} {
	switch -exact $synType {
	    synError {
		set imageName synError
		set imageType syntax_error
	    }
	    synWarning {
		set imageName synWarning
		set imageType syntax_warning
	    }
	    default {
		error "unknown codebar syntax msg type: $synType"
	    }
	}
	$text image create $index -name $imageName -image $image::image($imageType)
	#    $text tag add $tagName $index
	#    $text tag add setBreak $index
	return
    }

    # ### ### ### ######### ######### #########

    # method getSPState --
    #
    #	Return the state of the spawn-point for a <loc> type.
    #	The CodeBar only displays one icon per line, so the 
    #	spawn-point state is a combination of all spawn-points
    #	that exist on this line.
    #
    # Arguments:
    #	loc	A <loc> opaque type that contains the location 
    #		of the spawn-point in a script.
    #
    # Results:
    #	The state of the spawn-point at <loc>.
    #   Either: enabledSpawn, disabledSpawn, or noSpawn.

    method getSPState {loc} {
	set  sp [$dbg getSpawnpoints $loc]
	if {$sp == {}} {return noSpawn}

	if {[$brk getState $sp] eq "enabled"} {
	    return enabledSpawn
	} else {
	    return disabledSpawn
	}
    }

    # method toggleSPOnOff --
    #
    #	Toggle the breakpoint on and off.  Based on the current
    #	state of the breakpoint, determine the next valid state,
    #	delete any existing icon and draw a new icon if necessary.
    #
    # Arguments:
    #	text		Text widget that contains breakpoint icons.
    #	index		Location to delete and insert icons.
    #	loc		The <loc> type needed set breakpoints.
    #	spawnState	The current state of the breakpoint.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    method toggleSPOnOff {text index loc spawnState {pcType {}}} {
	set loc [$code makeCodeLocation $text $index]
	set prefix [$self getLBPState $loc]
	if {$prefix eq "noBreak"} {
	    set prefix ""
	} else {
	    append prefix _
	}

	switch -exact $spawnState {
	    noSpawn {
		# If the "current" icon is on the current line,
		# delete it, then set the state to "enabled".

		if {$pcType != {}} {$text delete $index}

		$dbg addSpawnpoint $loc
		pref::groupSetDirty Project 1
		$self drawSP $text $index ${prefix}enabledSpawn $pcType

	    }
	    enabledSpawn {
		# Delete "enabled" icon and set the state to "no break".
		$text delete $index

		$self setSP  noSpawn $loc 
		$self drawSP $text $index noSpawn $pcType
	    }
	    disabledSpawn {
		# Delete the icon and set the state back to "enabled".
		$text delete $index

		$self setSP  enabledSpawn $loc 
		$self drawSP $text $index ${prefix}enabledSpawn $pcType
	    }
	    default {
		error "unknown spawn point state: $spawnState"
	    }
	}
    }

    # method toggleSPEnableDisable --
    #
    #	Toggle the breakpoint to enabled and disabled.  Based on the 
    #	current state of the breakpoint, determine the next valid 
    #	state, delete any existing icon, and draw a new icon if 
    # 	necessary.
    #
    # Arguments:
    #	text		Text widget that contains breakpoint icons.
    #	index		Location to delete and insert icons.
    #	loc		The <loc> type needed set breakpoints.
    #	spawnState	The current state of the breakpoint.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    method toggleSPEnableDisable {text index loc spawnState {pcType {}}} {
	set loc [$code makeCodeLocation $text $index]
	set prefix [$self getLBPState $loc]
	if {$prefix eq "noBreak"} {
	    set prefix ""
	} else {
	    append prefix _
	}

	switch -exact $spawnState {
	    noSpawn {
		return
	    }
	    enabledSpawn {
		# Delete the icon and set the state to "disabled".
		$text delete $index

		$self setSP  disabledSpawn $loc 
		$self drawSP $text $index ${prefix}disabledSpawn $pcType
	    }
	    disabledSpawn {
		# Delete the disabled icon and set the state back to "enabled".
		$text delete $index

		$self setSP  enabledSpawn $loc 
		$self drawSP $text $index ${prefix}enabledSpawn $pcType
	    }
	    default {
		error "unknown spawnpoint state: $spawnState"
	    }
	}
    }

    # method setSP --
    #
    #	Set the new state of the breakpoint in the nub.
    #
    # Arguments:
    #	state	The new state of the breakpoint.
    #	loc	The <loc> object used to set the breakpoint.
    #
    # Results:
    #	None.

    method setSP {state loc} {
	set sp [$dbg getSpawnpoints $loc]
	if {$sp == {}} return
	switch -exact $state {
	    noSpawn {
		pref::groupSetDirty Project 1
		$dbg removeBreakpoint $sp
	    }
	    enabledSpawn {
		$dbg enableBreakpoint $sp
	    }
	    disabledSpawn {
		$dbg disableBreakpoint $sp
	    }
	    default {
		error "unknown state in $self setSP: $state"
	    }
	}
    }

    # method drawSP --
    #
    #	Draw a new spawn-point icon into the text widget.
    #	It is assumed that any out-dated icons on this line 
    #	have already been deleted.
    #
    #	Icons are embedded into the text widget with two tags
    #	bound to them: setBreak and <tagName>.  SetBreak is used
    #	to identify it as a generic spawn-point icon, and
    #	<tagName> is used to identify the type of spawn-point.
    #
    # Arguments:
    #	text		The text widget to draw the icon into.
    #	index		The location in the text widget to insert the icon.
    #	spawnState	The type of icon to draw.
    #	pcType  	String, used to indicate if the "current"
    #			icon is also at this index and what type
    #			the icon is (current or history.)
    #
    # Results:
    #	None.

    method drawSP {text index spawnState {pcType {}}} {
	#puts draw/_SP/--/$text/$index/--/$spawnState/$pcType/

	set tagNameB {}
	switch -exact $spawnState {
	    noSpawn {
		if {$pcType != {}} {
		    $text image create $index -name currentImage \
			    -image $image::image($pcType)
		}
		return
	    }
	    enabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_sp_enable
		} else {
		    set imageName enabledSpawn
		    set imageType spawn_enable
		}
		set tagName enabledSpawn
	    }
	    disabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_sp_disable
		} else {
		    set imageName disabledSpawn
		    set imageType spawn_disable
		}
		set tagName disabledSpawn
	    }


	    enabledBreak_enabledSpawn {
		# Merge states
		# NOTE: This code is __duplicated in 'drawLBP'__.
		# FUTURE: Rationalize the toggle, set, and draw commands.

		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_bs_ee
		} else {
		    set imageName enabledBreakSpawn
		    set imageType breakspawn_enable
		}
		set tagName  enabledBreak
		set tagNameB enabledSpawn
	    }
	    enabledBreak_disabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_bs_ed
		} else {
		    set imageName enabledBreakDisabledSpawn
		    set imageType breakspawn_enabledisable
		}
		set tagName  enabledBreak
		set tagNameB disabledSpawn
	    }
	    disabledBreak_enabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_bs_de
		} else {
		    set imageName disabledBreakEnabledSpawn
		    set imageType breakspawn_disableenable
		}
		set tagName  disabledBreak
		set tagNameB enabledSpawn
	    }
	    disabledBreak_disabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_bs_dd
		} else {
		    set imageName disabledBreakSpawn
		    set imageType breakspawn_disable
		}
		set tagName  disabledBreak
		set tagNameB disabledSpawn
	    }
	    mixedBreak_enabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_enable
		} else {
		    set imageName mixedBreakEnabledSpawn
		    set imageType breakspawn_mixedenable
		}
		set tagName  mixedBreak
		set tagNameB enabledSpawn
	    }
	    mixedBreak_disabledSpawn {
		if {$pcType != {}} {
		    set imageName currentImage
		    set imageType ${pcType}_enable
		} else {
		    set imageName mixedBreakdisabledSpawn
		    set imageType breakspawn_mixeddisable
		}
		set tagName  mixedBreak
		set tagNameB disabledSpawn
	    }
	    default {
		error "unknown codebar break state: $spawnState"
	    }
	}
	$text image create $index -name $imageName \
		-image $image::image($imageType)
	$text tag add $tagName $index
	$text tag add setBreak $index
	if {$tagNameB != {}} {
	    $text tag add $tagNameB $index
	}
    }

}

# ### ### ### ######### ######### #########
## Ready to go
package provide icon 1.0
