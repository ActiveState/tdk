# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_history.tcl,v 1.23 2007/06/05 15:34:14 danielk1977 Exp $)} 1 }

package require snit

# History state for a single browser window.
#
snit::type ::hv3::history_state {

  # Variable $myUri stores the document URI to fetch. This is the value
  # that will be displayed in the "location" entry field when the 
  # history state is loaded.
  #
  # Variable $myTitle stores the title of the page last seen at location
  # $myUri. These two variables are used in concert to determine the
  # displayed title of the history list entry (on the history menu).
  #
  variable myUri     ""
  variable myTitle   ""

  # Values to use with [pathName xscroll|yscroll moveto] to restore
  # the previous scrollbar positions. Currently only the main browser
  # window scrollbar positions are restored, not the scrollbars used
  # by any <frame> or "overflow:scroll" elements.
  #
  variable myXscroll ""
  variable myYscroll ""

  # Object member $myUri stores the URI of the top-level document loaded
  # into the applicable browser window. However if that document is a 
  # frameset document a URI is required for each frame in the (possibly
  # large) tree of frames. This array stores those URIs, indexed by
  # the frames "positionid" (see the [positionid] sub-command of class
  # ::hv3::browser_frame).
  #
  # Note that the top-level frame is included in this array (the index
  # of the top-level frame is always "0 0"). The code in this file uses
  # $myUri for display purposes (i.e. in the history menu) and 
  # $myFrameUri for reloading states.
  #
  variable myFrameUri -array [list]

  method Getset {var arglist} {
    if {[llength $arglist] > 0} {
      set $var [lindex $arglist 0]
    }
    return [set $var]
  }

  method uri     {args} { return [$self Getset myUri $args] }
  method title   {args} { return [$self Getset myTitle $args] }
  method xscroll {args} { return [$self Getset myXscroll $args] }
  method yscroll {args} { return [$self Getset myYscroll $args] }

  # Retrieve the URI associated with the frame $positionid.
  #
  method get_frameuri {positionid} {
    if {[info exists myFrameUri($positionid)]} {
      return $myFrameUri($positionid)
    }
    return ""
  }

  # Set an entry in the $myFrameUri array.
  #
  method set_frameuri {positionid uri} {
    set myFrameUri($positionid) $uri
  }

  # Clear the $myFrameUri array.
  #
  method clear_frameurilist {} {
    array unset myFrameUri
  }
}

# class ::hv3::history
#
# Options:
#     -gotocmd
#     -backbutton
#     -forwardbutton
#
# Methods:
#     locationvar
# 
snit::type ::hv3::history {
  # corresponding option exported by this class.
  #
  variable myLocationVar ""
  variable myTitleVarName ""

  variable myHv3 ""
  variable myProtocol ""
  variable myBrowser ""

  # The following two variables store the history list
  variable myStateList [list]
  variable myStateIdx 0 

  variable myRadioVar 0 

  # Variables used when loading a history-state.
  variable myHistorySeek -1
  variable myIgnoreGotoHandler 0
  variable myCacheControl ""

  # Configuration options to attach this history object to a set of
  # widgets - back and forward buttons and a menu widget.
  #
  option -backbutton    -default ""
  option -forwardbutton -default ""
  option -addressbar    -default ""

  # An option to set the script to invoke to goto a URI. The script is
  # evaluated with a single value appended - the URI to load.
  #
  option -gotocmd -default ""

  # Events:
  #     <<Goto>>
  #     <<Complete>>
  #     <<SaveState>>
  #     <<Location>>
  #
  #     Also there is a trace on "titlevar" (set whenever a <title> node is
  #     parsed)
  #

  constructor {hv3 protocol browser args} {
    $hv3 configure -locationvar [myvar myLocationVar]
    $self configurelist $args

    trace add variable [$hv3 titlevar] write [mymethod Locvarcmd]

    set myTitleVarName [$hv3 titlevar]
    set myHv3 $hv3
    set myProtocol $protocol
    set myBrowser $browser

    # bind $hv3 <<Reset>>    +[mymethod ResetHandler]
    bind $hv3 <<Complete>>  +[mymethod CompleteHandler]
    bind $hv3 <<Location>>  +[mymethod Locvarcmd]
    $self add_hv3 $hv3

    # Initialise the state-list to contain a single, unconfigured state.
    set myStateList [::hv3::history_state %AUTO%]
    set myStateIdx 0
  }

  destructor {
    trace remove variable $myTitleVarName write [mymethod Locvarcmd]
    foreach state $myStateList {
      $state destroy
    }
  }

  method add_hv3 {hv3} {
    bind $hv3 <<Goto>>      +[mymethod GotoHandler]
    bind $hv3 <<SaveState>> +[mymethod SaveStateHandler $hv3]
  }

  method loadframe {frame} {
    if {$myHistorySeek >= 0} {
      set state [lindex $myStateList $myHistorySeek]
      set uri [$state get_frameuri [$frame positionid]]
      if {$uri ne ""} {
        incr myIgnoreGotoHandler
        $frame goto $uri -cachecontrol $myCacheControl
        incr myIgnoreGotoHandler -1
        return 1
      }
    }
    return 0
  }

  # Return the name of the variable configured as the -locationvar option
  # of the hv3 widget. This is provided so that other code can add
  # [trace] callbacks to the variable.
  method locationvar {} {return [myvar myLocationVar]}

  # This method is bound to the <<Goto>> event of the ::hv3::hv3 
  # widget associated with this history-list.
  #
  method GotoHandler {} {
    if {!$myIgnoreGotoHandler} {
      # We are not in "history" mode any more.
      set myHistorySeek -1
    }
  }

  # This method is bound to the <<Complete>> event of the ::hv3::hv3 
  # widget associated with this history-list. If the <<Complete>> is
  # issued because a history-seek is complete, then scroll the widget
  # to the stored horizontal and vertical offsets.
  #
  method CompleteHandler {} {
    if {$myHistorySeek >= 0} {
      set state [lindex $myStateList $myStateIdx]
      after idle [list $myHv3 yview moveto [$state yscroll]]
      after idle [list $myHv3 xview moveto [$state xscroll]]
    }
  }

  # Invoked whenever our hv3 widget is reset (i.e. just before a new
  # document is loaded) or when moving to a different #fragment within
  # the same document. The current state of the widget should be copied 
  # into the history list.
  #
  method SaveStateHandler {hv3} {
    set state [lindex $myStateList $myStateIdx]

    # Update the current history-state record:
    $state xscroll [lindex [$myHv3 xview] 0]
    $state yscroll [lindex [$myHv3 yview] 0]

    $state clear_frameurilist
    foreach frame [$myBrowser get_frames] {
      set positionid [$frame positionid]
      set uri [[$frame hv3] location]
      $state set_frameuri $positionid $uri
    }

    if {$myHistorySeek >= 0} {
      set myStateIdx $myHistorySeek
      set myRadioVar $myStateIdx
    } else {
      # Add an empty state to the end of the history list. Set myStateIdx
      # and myRadioVar to the index of the new state in $myStateList.
      set myStateList [lrange $myStateList 0 $myStateIdx]
      incr myStateIdx
      set myRadioVar $myStateIdx
      lappend myStateList [::hv3::history_state %AUTO%]

      # If the widget that generated this event is not the main widget,
      # copy the URI and title from the previous state.
      if {$hv3 ne $myHv3 && $myStateIdx >= 1} {
        set prev [lindex $myStateList [expr $myStateIdx - 1]]
        set new [lindex $myStateList $myStateIdx]
        $new uri [$prev uri]
        $new title [$prev title]
      }
    }

    $self populatehistorymenu
  }

  # Invoked when the [$myHv3 titlevar] variable is modified.  are modified.
  # Update the current history-state record according to the new value.
  #
  method Locvarcmd {args} {
    set state [lindex $myStateList $myStateIdx]
    $state uri $myLocationVar
    set t [set [$myHv3 titlevar]]
    if {$t ne ""} {
      $state title $t
    }
    $self populatehistorymenu
  }

  # Load history state $idx into the browser window.
  #
  method gotohistory {idx} {
    set myHistorySeek $idx
    set state [lindex $myStateList $idx]

    incr myIgnoreGotoHandler 
    set myCacheControl relax-transparency
    set c $myCacheControl
    eval [linsert $options(-gotocmd) end [$state uri] -cachecontrol $c]
    incr myIgnoreGotoHandler -1
  }

  method reload {} {
    set myHistorySeek $myStateIdx
    set state [lindex $myStateList $myHistorySeek]
    incr myIgnoreGotoHandler 
    set myCacheControl no-cache
    set c $myCacheControl
    eval [linsert $options(-gotocmd) end [$state uri] -cachecontrol $c]
    incr myIgnoreGotoHandler -1
  }

  # This method reconfigures the state of the -historymenu, -backbutton
  # and -forwardbutton to match the internal state of this object. To
  # summarize, it:
  #
  #     * Enables or disabled the -backbutton button
  #     * Enables or disabled the -forward button
  #     * Clears and repopulates the -historymenu menu
  #
  # This should be called whenever some element of internal state changes.
  # Possibly as an [after idle] background job though...
  #
  method populatehistorymenu {} {

    # Handles for the four widgets this object is controlling.
    set back $options(-backbutton)
    set forward $options(-forwardbutton)
    set addressbar $options(-addressbar)

    set myRadioVar $myStateIdx

    set backidx [expr $myStateIdx - 1]
    set backcmd [mymethod gotohistory $backidx]
    if {$backidx >= 0} {
        bind Hv3HotKeys <Alt-Left> $backcmd
        if {$back ne ""} { $back configure -state normal -command $backcmd }
    } else {
        bind Hv3HotKeys <Alt-Left> ""
        if {$back ne ""} { $back configure -state disabled }
    }

    set fwdidx [expr $myStateIdx + 1]
    set fwdcmd [mymethod gotohistory $fwdidx]
    if {$fwdidx < [llength $myStateList]} {
        bind Hv3HotKeys <Alt-Right> $fwdcmd
        if {$forward ne ""} { $forward configure -state normal -command $fwdcmd}
    } else {
        bind Hv3HotKeys <Alt-Right> ""
        if {$forward ne ""} { $forward configure -state disabled }
    }

    if {$addressbar ne ""} {
        $addressbar set $myLocationVar
    }
  }

  method populate_menu {menu} {
    $menu delete 0 end

    set backidx [expr $myStateIdx - 1]
    $menu add command -label Back -accelerator (Alt-Left) -state disabled
    if {$backidx >= 0} {
      $menu entryconfigure end -command [mymethod gotohistory $backidx]
      $menu entryconfigure end -state normal
    }

    set fwdidx [expr $myStateIdx + 1]
    $menu add command -label Forward -accelerator (Alt-Right) -state disabled
    if {$fwdidx < [llength $myStateList]} {
      $menu entryconfigure end -command [mymethod gotohistory $fwdidx]
      $menu entryconfigure end -state normal
    }

    $menu add separator

    set myRadioVar $myStateIdx

    set idx [expr [llength $myStateList] - 15]
    if {$idx < 0} {set idx 0}
    for {} {$idx < [llength $myStateList]} {incr idx} {
      set state [lindex $myStateList $idx]

      # Try to use the history-state "title" as the menu item label, 
      # but if this is an empty string, fall back to the URI.
      set caption [$state title]
      if {$caption eq ""} {set caption [$state uri]}

      $menu add radiobutton                       \
        -label $caption                           \
        -variable [myvar myRadioVar]              \
        -value    $idx                            \
        -command [mymethod gotohistory $idx]
    }
  }
}

snit::widgetadaptor ::hv3::addressbar {
    delegate option * to hull
    delegate method * to hull

    # Command to invoke when the location-entry widget is "activated" (i.e.
    # when the browser is supposed to load the contents as a URI). At
    # present this happens when the user presses enter.
    option -command -default "" -configuremethod C-command
    option -expand -default "none" \
	-type [list snit::enum -values [list none tab]]
    option -autocomplete -default 0 \
	-type [list snit::boolean]

    typeconstructor {
	bind AddressbarHotTrack <Motion> {
	    %W selection clear 0 end
	    %W activate @%x,%y
	    %W selection set @%x,%y
	}
    }

    constructor {args} {
	installhull using ttk::combobox -postcommand [mymethod OnPost]
	bind $win <<ComboboxSelected>> [mymethod invoke]

	bind $win <Return> [mymethod invoke]

	# Any button-press anywhere in the GUI folds up the drop-down menu.
	#bind [winfo toplevel $win] <ButtonPress> +[mymethod AnyButtonPress %W]

	#bind $myEntry <KeyPress>        +[mymethod KeyPress]
	#bind $myEntry <KeyPress-Return> +[mymethod KeyPressReturn]
	#bind $myEntry <KeyPress-Down>   +[mymethod KeyPressDown]
	#bind $myEntry <KeyPress-Escape> gui_escape

	#$myListbox configure -listvariable [myvar myListboxVar]

	# bind $myListbox.listbox <<ListboxSelect>> [mymethod ListboxSelect]
	#bind $myListbox.listbox <KeyPress-Return> [mymethod ListboxReturn]
	#bind $myListbox.listbox <1>   [mymethod ListboxPress %y]

	$self configurelist $args
    }

    method C-command {option value} {
	set options($option) $value
    }

    # Binding for <KeyPress-Return> events that occur in the entry widget.
    #
    method invoke {} {
	if {$options(-command) ne ""} {
	    uplevel 1 $options(-command)
	}
	#$self CloseDropdown
    }

    method OnPost {{ptn *}} {
	if {$ptn ne "*"} {
	    set ptn *$ptn*
	}
	$win configure -values [::hv3::the_visited_db keys $ptn]
    }

    method escape {} {
	ttk::combobox::Unpost $win
	$win selection clear
    }

    method _expand {} {
	set values [$win cget -values]
	if {![llength $values]} {
	    bell
	    return 0
	}

	set found  {}
	set curval [$win get]
	set curlen [$win index insert]
	if {$curlen < [string length $curval]} {
	    # we are somewhere in the middle of a string.
	    # if the full value matches some string in the listbox,
	    # reorder values to start matching after that string.
	    set idx [lsearch -exact $values $curval]
	    if {$idx >= 0} {
		set values [concat [lrange $values [expr {$idx+1}] end] \
				[lrange $values 0 $idx]]
	    }
	}
	if {$curlen == 0} {
	    set found $values
	} else {
	    foreach val $values {
		if {[string equal -length $curlen $curval $val]} {
		    lappend found $val
		}
	    }
	}
	if {[llength $found]} {
	    $win set [lindex $found 0]
	    if {[llength $found] > 1} {
		set best [$self _best_match $found \
			      [string range $curval 0 $curlen]]
		set blen [string length $best]
		$win icursor $blen
		$win selection range $blen end
	    }
	} else {
	    bell
	}
	return [llength $found]
    }

    # best_match --
    #   finds the best unique match in a list of names
    #   The extra $e in this argument allows us to limit the innermost loop a
    #   little further.
    # Arguments:
    #   l		list to find best unique match in
    #   e		currently best known unique match
    # Returns:
    #   longest unique match in the list
    #
    method _best_match {l {e {}}} {
	set ec [lindex $l 0]
	if {[llength $l]>1} {
	    set e  [string length $e]; incr e -1
	    set ei [string length $ec]; incr ei -1
	    foreach l $l {
		while {$ei>=$e && [string first $ec $l]} {
		    set ec [string range $ec 0 [incr ei -1]]
		}
	    }
	}
	return $ec
    }

    method _auto_complete {key} {
	set path $win
	## Any key string with more than one character and is not entirely
	## lower-case is considered a function key and is thus ignored.
	if {[string length $key] > 1 && [string tolower $key] != $key} {
	    return
	}

	set text [$win get]
	if {$text eq ""} { return }
	set values [$win cget -values]
	set text [string map [list {[} {\[} {]} {\]}] $text] ; # glob safe
	set x [lsearch -glob $values $text*]
	if {$x < 0} { return }

	set idx [$win index insert]
	$win set [lindex $values $x]
	$win icursor $idx
	$win select range insert end
    }

}

