# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# This file contains code to implement the dynamic logging window. 
#
namespace eval hv3 { set {version($Id: hv3_log.tcl,v 1.16 2007/06/30 16:43:49 danielk1977 Exp $)} 1 }

source [file join [file dirname [info script]] hv3_widgets.tcl]

snit::widget ::hv3::dynamiclog {
  component myText

  # The Tkhtml3 widget producing events to log.
  variable myHtml ""

  # The DOM widget producing events to log.
  variable myDom ""

  variable myState -array {
    LAYOUTENGINE 0
    STYLEENGINE  0
    ACTION       0
    "ECMASCRIPT Get"  1
    "ECMASCRIPT Put"  1
  }

  constructor {html} {
    set myHtml $html
    $html configure -logcmd [mymethod log]

    set myDom [[winfo parent [winfo parent $html]] dom]
    $myDom configure -logcmd [mymethod log]

    set myText ${win}.text
    ::hv3::scrolled ::hv3::text $myText -width 400 -height 300 -wrap none

    set f ${win}.checkbutton
    frame $f

    foreach key [array names myState] {
      set w [string tolower ${f}.${key}]
      checkbutton $w -variable [myvar myState($key)] -text $key
      pack $w -side left
    }

    frame ${win}.button
    ::hv3::button ${win}.button.dismiss -text Dismiss 
    ::hv3::button ${win}.button.clear -text Clear 
    ${win}.button.dismiss configure -command [mymethod Dismiss]
    ${win}.button.clear configure -command [mymethod Clear]

    pack ${win}.button.dismiss -side left -fill x -expand true
    pack ${win}.button.clear -side left -fill x -expand true

    pack ${win}.button -fill x -side bottom
    pack ${win}.checkbutton -fill x -side bottom
    pack ${win}.text   -fill both -expand true
  }

  method log {args} {
    set subject [lindex $args 0]
    if {[info exists myState($subject)]} {
      if {$myState($subject)} {
        $myText insert end "$args\n"
      }
    }
  }

  method Clear {} {
    $myText delete 0.0 end
  }
  method Dismiss {} {
    destroy [winfo parent ${win}]
  }

  destructor {
    $myHtml configure -logcmd ""
    if {$myDom ne ""} {$myDom configure -logcmd ""}
  }
}

proc ::hv3::log_window {html} {
  toplevel .event_log
  ::hv3::dynamiclog .event_log.log $html
  pack .event_log.log -expand 1 -fill both
}

set ::hv3::event_log_subjects { ACTION }

