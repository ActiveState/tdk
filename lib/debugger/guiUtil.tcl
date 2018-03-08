# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# guiUtil.tcl --
#
#	Utility procedures for the debugger GUI.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: guiUtil.tcl,v 1.3 2000/10/31 23:30:58 welch Exp $

package provide guiUtil 1.0
namespace eval guiUtil {
    # This array is used by the Pane and Table commands
    # to preserve and restore the geometry of the pane
    # or table between sessions.  The procs: 
    # guiUtil::savePaneGeometry and guiUtil::restorePaneGeometry
    # preserve the data in the prefs Default group between 
    # sessions.

    variable paneGeom
}

# --------------------------------------------------------------------------
# Panedwindow geometry save/restore methods
# --------------------------------------------------------------------------

proc guiUtil::pwSave {master} {

    if {[$master cget -orient] eq "horizontal"} {
	set total [winfo width $master]
	set sash  [$master sashpos 0]
    } else {
	set total [winfo height $master]
	set sash  [$master sashpos 0]
    }

    set relative [expr {double($sash)/double($total)}]

    #puts "...pwSave \[pane $master\]: ${relative}"

    set guiUtil::paneGeom($master) $relative
    return
}

proc guiUtil::pwRestore {master {default {}}} {

    if {![info exists guiUtil::paneGeom($master)]} {
	if {$default == {}} return
	set relative $default
    } else {
	set relative $guiUtil::paneGeom($master)
    }

    update idletasks
    if {[$master cget -orient] eq "horizontal"} {
	set total [winfo width $master]
    } else {
	set total [winfo height $master]
    }

    set sash [expr {int(double($relative) * double($total))}]

    #puts "...pwRestore \[pane $master\]: ${relative} of $total @ $sash"

    if {[$master cget -orient] eq "horizontal"} {
	$master sashpos 0 $sash
    } else {
	$master sashpos 0 $sash
    }
    return
}


#-----------------------------------------------------------------------------
# Table Procedures
#-----------------------------------------------------------------------------

# guiUtil::tableCreate --
#
#	Create a sliding pane between two frames.
#
# Arguments:
#	frm1	-
#	frm2 	Frames to create the pane between.
#	args	Optional argument that override the defaults.
#		-orient	  The orientation of the sliding pane.
#			  vertical   - slides left and right.
#			  horizontal - slides up and down.
#		-percent  Split between the two frames.
#		-in       The parent window to pack the frames into.
#
# Results: 
#	None.

proc guiUtil::tableCreate {master frm1 frm2 args} {

    # Map optional arguments into array values
    set t(-percent) 0.5
    set t(-title1) ""
    set t(-title2) ""
    set t(-justify) left
    array set t $args
    if {[info exists guiUtil::paneGeom($master)]} {
	set t(-percent) $guiUtil::paneGeom($master)
    }

    # Keep state in an array associated with the master frame.
    upvar #0 Pane$master pane
    array set pane [array get t]
    
    $master configure -borderwidth 1 -relief sunken
    # Create sub frames that contain the title bars and  windows.
    set title [frame $master.title] 
    set wins  [frame $master.wins]

    # Create the first pane with a title bar and the embedded 
    # window.  

    set pane(1) $frm1
    set pane(t1) [label $title.title0  -relief raised -bd 1 \
	    -text $pane(-title1) -justify $pane(-justify) \
	    -anchor w -padx 6]

    # Get the font height and re-configure the title bars
    # frame height.

    set fontHeight [lindex [font metrics [$pane(t1) cget -font]] 5]
    set lblHeight  [expr {int($fontHeight * 1.5)}]
    $title    configure -height $lblHeight

    place $pane(t1) -in $title -relx 0.0 -y 0 -anchor nw \
	    -height $lblHeight -relwidth 1.0
    place $pane(1) -in $wins -relx 0.0 -y 0 -anchor nw \
	    -relheight 1.0 -relwidth 1.0
    raise $pane(1)

    # If there are two sub windows, create the grip to slide
    # the widows vertically and add the bindings.

    if {$frm2 != {}} {
	set pane(2) $frm2
	set pane(t2) [label $title.title1  -relief raised -bd 1 \
		-text $pane(-title2) -justify $pane(-justify) \
		-anchor w -padx 6]
	set pane(grip) [frame $title.grip -bg gray50 \
		-bd 0 -cursor sb_h_double_arrow -width 2]
	place $pane(t2) -in $title -relx 1.0 -y 0 -anchor ne \
		-height $lblHeight -relwidth 0.5
	place $pane(2) -in $wins -relx 1.0 -y 0 -anchor ne \
		-relheight 1.0 -relwidth 0.5
	raise $pane(2)
	
	# Set up bindings for resize, <Configure>, and 
	# for dragging the grip.
	
	bind $pane(grip) <ButtonPress-1> \
		[list guiUtil::tableDrag $master %X]
	bind $pane(grip) <B1-Motion> \
		[list guiUtil::tableDrag $master %X]
	bind $pane(grip) <ButtonRelease-1> \
		[list guiUtil::tableStop $master]
	bind $master <Configure> [list guiUtil::tableGeometry $master]
	
	guiUtil::tableGeometry $master
    }

    pack $master  -fill both -expand true -padx 2
    pack $title -fill x
    pack $wins  -fill both -expand true
    
    pack propagate $master off
    pack propagate $title off
    pack propagate $wins off
}

# guiUtil::tableDrag --
#
#	Slides the panel in one direction based on the orientation.
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#	D	???
#
# Results: 
#	None.

proc guiUtil::tableDrag {master x} {
    upvar #0 Pane$master pane
    if {[info exists pane(lastX)]} {
	set delta [expr {double($pane(lastX) - $x) / $pane(size)}]
	set percent [expr {$pane(-percent) - $delta}]
	set setPercent 1
	set grip 0
	if {$percent < 0.0} {
	    set setPercent 0
	    set grip 0
	    set percent 0.0
	} elseif {$percent > 1.0} {
	    set setPercent 0
	    set grip -4
	    set percent 1.0
	}
	$pane(grip) configure -width 4 -bg grey25
	place $pane(grip) -relheight 1.0 -x $grip -relx $percent
	if {!$setPercent} {
	    return
	}
	set pane(-percent) $percent
    }
    set pane(lastX) $x
}

# guiUtil::tableStop --
#
#	Releases the hold on the sliding panel.
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#
# Results: 
#	None.

proc guiUtil::tableStop {master} {
    upvar #0 Pane$master pane
    guiUtil::tableGeometry $master
    catch {unset pane(lastX)}
    $pane(grip) configure -width 2 -bg gray50
}

# guiUtil::tableGeometry
#
#	Sets the geometry of the sub frames???
#
# Arguments:
#	master	The parent window that contains both the sub frames.
#
# Results: 
#	None.

proc guiUtil::tableGeometry {master} {
    upvar #0 Pane$master pane

    # Prevent loosing the grip if the percent is virtually
    # zero.  Otherwise place the grip off by two pixels for
    # aesthetics.
 
    place $pane(t1)   -width -2 -relwidth $pane(-percent)
    place $pane(1)    -relwidth $pane(-percent)
    if {$pane(-percent) < 0.01} {
	place $pane(grip) -relx $pane(-percent) -relheight 1.0
	place $pane(t2)   -relwidth [expr {1.0 - $pane(-percent)}]
	place $pane(2)    -relwidth [expr {1.0 - $pane(-percent)}]
    } else {
	place $pane(grip) -x -2 -relx $pane(-percent) -relheight 1.0
	place $pane(t2)   -x -2 -relwidth [expr {1.0 - $pane(-percent)}]
	place $pane(2)    -x -2 -relwidth [expr {1.0 - $pane(-percent)}]
    }

    set pane(size) [winfo width $master]

    #puts ...T/$master/$pane(-percent)

    set guiUtil::paneGeom($master) $pane(-percent)
}

#-----------------------------------------------------------------------------
# Misc Functions
#-----------------------------------------------------------------------------

# guiUtil::positionWindow --
#
#	Given a top level window this procedure will position the window
#	in the same location it was the last time it was used (if we knew
#	about it).  If the location would be off the screen we move it so
#	it will be visable.  We also set up a destroy handler so that we
#	save the window state when the window goes away.
#
# Arguments:
#	win		A toplevel window.
#	defaultGeom	A default geometry if none exists.
#
# Results:
#	None.

proc guiUtil::positionWindow {win {defaultGeom {}}} {
    if {![winfo exists $win] || ($win != [winfo toplevel $win])} {
	error "positionWindow not called on toplevel"
    }

    set tag [string range $win 1 end]
    set winGeoms [pref::prefGet winGeoms]
    set index    [lsearch -regexp $winGeoms [list $tag *]]

    if {$index == -1} {
	if {$defaultGeom != ""} {
	    #puts "Posw/$win/$defaultGeom/def"
	    wm geometry $win $defaultGeom
	}
    } else {
	set geom [lindex [lindex $winGeoms $index] 1]
	#puts "Posw/$win/$geom"

	# See if window is on the screen.  If it isn't then don't
	# use the saved value.  Either use the default or nothing.

	foreach {w h x y} {0 0 0 0} {}
	scan $geom "%dx%d+%d+%d" w h x y
	set slop 10
	set sw [expr {[winfo screenwidth $win]  - $slop}]
	set sh [expr {[winfo screenheight $win] - $slop}]
	
	if {($x > $sw) || ($x < 0) || ($y > $sh) || ($y < 0)} {
	    if {($defaultGeom != "")} {
		# Perform some sanity checking on the default value.

		foreach {w h x y} {0 0 0 0} {}
		scan $defaultGeom "%dx%d+%d+%d" w h x y
		if {$w > $sw} {
		    set w $sw
		    set x $slop
		}
		if {$h > $sh} {
		    set h $sh
		    set y $slop
		}
		if {($x < $slop) || ($x > $sw)} {
		    set x $slop
		}
		if {($y < $slop) || ($y > $sh)} {
		    set y $slop
		}
		wm geometry $win ${w}x${h}+${x}+${y}
	    }
	} else {
	    wm geometry $win ${w}x${h}+${x}+${y}
	}
    }
    
    bind $win <Destroy> {::guiUtil::saveGeometry %W}
}

# guiUtil::saveGeometry --
#
#	Given a toplevel window this procedure will save the geometry
#	state of the window so it can be placed in the same position
#	the next time it is created.
#
# Arguments:
#	win	A toplevel window.
#
# Results:
#	None.  State is stored in global preferences.

proc guiUtil::saveGeometry {win} {
    set result [catch {set top [winfo toplevel $win]}]
    if {($result != 0) || ($win != $top)} {
	return
    }

    # If wins geometry has been saved before, get an index into the list and 
    # replace the old value with the new value.  If wins has not been saved
    # before the index value will be -1.

    set geometry [wm geometry $win]
    set tag [string range $win 1 end]
    set winGeoms [pref::prefGet winGeoms GlobalDefault]
    set index    [lsearch -glob $winGeoms [list $tag *]]

    #puts SG/$win/$geometry/$index

    # If the window was never saved before, append the tag name and the 
    # geometry of the window onto the list.  Otherwise replace the value
    # referred to at index.

    if {$index == -1} {
	lappend winGeoms [list $tag $geometry]
    } else {
	set winGeoms [lreplace $winGeoms $index $index [list $tag $geometry]]
    }

    # Update the winGeoms preference value in the GlobalDefault group

    #puts SG/set/$winGeoms
    pref::prefSet GlobalDefault winGeoms $winGeoms 
    return
}

# guiUtil::restorePaneGeometry --
#
#	Restore the pane's -percent value, so the window
#	can be restored to it's identical percentage of 
#	distribution.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc guiUtil::restorePaneGeometry {} {
    array set guiUtil::paneGeom [pref::prefGet paneGeom GlobalDefault] 
    return
}

# guiUtil::preservePaneGeometry --
#
#	Save the pane's -percent value, so the window can
#	be restored to it's identical percentage of 
#	distribution.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc guiUtil::preservePaneGeometry {} {
    # Update the winGeoms preference value in the GlobalDefault group
    
    pref::prefSet GlobalDefault paneGeom [array get ::guiUtil::paneGeom]
    return
}
