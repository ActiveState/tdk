# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_string.tcl,v 1.6 2007/07/10 09:11:04 danielk1977 Exp $)} 1 }


namespace eval ::hv3::string {

  # A generic tokeniser procedure for strings. This proc splits the
  # input string $input into a list of tokens, where each token is either:
  #
  #     * A continuous set of alpha-numeric characters, or
  #     * A quoted string (quoted by " or '), or
  #     * Any single character.
  #
  # White-space characters are not returned in the list of tokens.
  #
  proc tokenise {input} {
    set tokens [list]
    set zIn [string trim $input]
  
    while {[string length $zIn] > 0} {
  
      if {[ regexp {^([[:alnum:]_.-]+)(.*)$} $zIn -> zToken zIn ]} {
        # Contiguous alpha-numeric characters
        lappend tokens $zToken
  
      } elseif {[ regexp {^(["'])} $zIn -> zQuote]} {      #;'"
        # Quoted string
  
        set nEsc 0
        for {set nToken 1} {$nToken < [string length $zIn]} {incr nToken} {
          set c [string range $zIn $nToken $nToken]
          if {$c eq $zQuote && 0 == ($nEsc%2)} break
          set nEsc [expr {($c eq "\\") ? $nEsc+1 : 0}]
        }
        set zToken [string range $zIn 0 $nToken]
        set zIn [string range $zIn [expr {$nToken+1}] end]
  
        lappend tokens $zToken
  
      } else {
        lappend tokens [string range $zIn 0 0]
        set zIn [string range $zIn 1 end]
      }
  
      set zIn [string trimleft $zIn]
    }
  
    return $tokens
  }

  # Dequote $input, if it appears to be a quoted string (starts with 
  # a single or double quote character).
  #
  proc dequote {input} {
    set zIn $input
    set zQuote [string range $zIn 0 0]
    if {$zQuote eq "\"" || $zQuote eq "\'"} {
      set zIn [string range $zIn 1 end]
      if {[string range $zIn end end] eq $zQuote} {
        set zIn [string range $zIn 0 end-1]
      }
      set zIn [regsub {\\(.)} $zIn {\1}]
    }
    return $zIn
  }


  # A procedure to parse an HTTP content-type (media type). See section
  # 3.7 of the http 1.1 specification.
  #
  # A list of exactly three elements is returned. These are the type,
  # subtype and charset as specified in the parsed content-type. Any or
  # all of the fields may be empty strings, if they are not present in
  # the input or a parse error occurs.
  #
  proc parseContentType {contenttype} {
    set tokens [::hv3::string::tokenise $contenttype]

    set type [lindex $tokens 0]
    set subtype [lindex $tokens 2]

    set enc ""
    foreach idx [lsearch -regexp -all $tokens (?i)charset] {
      if {[lindex $tokens [expr {$idx+1}]] eq "="} {
        set enc [::hv3::string::dequote [lindex $tokens [expr {$idx+2}]]]
        break
      }
    }

    return [list $type $subtype $enc]
  }

}

proc pretty_print_heapdebug {} {
  set data [lsort -index 2 -integer [::tkhtml::heapdebug]]
  set ret ""
  set nTotalS 0
  set nTotalB 0
  foreach type $data {
    foreach {zStruct nStruct nByte} $type {}
    append ret [format "%-30s %10d %10d\n" $zStruct $nStruct $nByte]
    incr nTotalB $nByte
    incr nTotalS $nStruct
  }
  append ret [format "%-30s %10d %10d\n" "Totals" $nTotalS $nTotalB]
  set ret
}

proc pretty_print_vars {} {
  set ret ""
  foreach e [lsort -integer -index 1 [get_vars]] {
    append ret [format "%-50s %d\n" [lindex $e 0] [lindex $e 1]]
  }
  set ret
}

proc tree_to_report {tree indent} {
  set i [string repeat " " $indent]
  set f [lindex $tree 0]

  set name [$f cget -name]
  set uri  [[$f hv3] uri get]

  append ret [format "%-40s %s\n" $i\"$name\" $uri]
  foreach child [lindex $tree 1] {
    append ret [tree_to_report $child [expr {$indent+4}]] 
  }
  set ret
}
proc pretty_print_frames {} {
  tree_to_report [lindex [gui_current frames_tree] 0] 0
}

proc get_vars {{ns ::}} {
  set nVar 0
  set ret [list]
  set vlist [info vars ${ns}::*]
  foreach var $vlist {
    if {[array exists $var]} {
      incr nVar [llength [array names $var]]
    } else {
      incr nVar 1
    }
  }
  lappend ret [list $ns $nVar]
  foreach child [namespace children $ns] {
    eval lappend ret [get_vars $child]
  }
  set ret
}
proc count_vars {{ns ::} {print 0}} {
  set nVar 0
  foreach entry [get_vars $ns] {
    incr nVar [lindex $entry 1]
  }
  set nVar
}
proc count_commands {{ns ::}} {
  set nCmd [llength [info commands ${ns}::*]]
  foreach child [namespace children $ns] {
    incr nCmd [count_commands $child]
  }
  set nCmd
}
proc count_namespaces {{ns ::}} {
  set nNs 1
  foreach child [namespace children $ns] {
    incr nNs [count_namespaces $child]
  }
  set nNs
}

