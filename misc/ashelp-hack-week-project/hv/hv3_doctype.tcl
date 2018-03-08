# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_doctype.tcl,v 1.7 2007/06/26 14:41:27 danielk1977 Exp $)} 1 }

namespace eval hv3 {}

proc ::hv3::char {text idx} {
  return [string range $text $idx $idx]
}

proc ::hv3::next_word {text idx idx_out} {

  while {[char $text $idx] eq " "} { incr idx }

  set idx2 $idx
  set c [char $text $idx2] 

  if {$c eq "\""} {
    # Quoted identifier
    incr idx2
    set c [char $text $idx2] 
    while {$c ne "\"" && $c ne ""} {
      incr idx2
      set c [char $text $idx2] 
    }
    incr idx2
    set word [string range $text [expr $idx+1] [expr $idx2 - 2]]
  } else {
    # Unquoted identifier
    while {$c ne ">" && $c ne " " && $c ne ""} {
      incr idx2
      set c [char $text $idx2] 
    }
    set word [string range $text $idx [expr $idx2 - 1]]
  }

  uplevel [list set $idx_out $idx2]
  return $word
}

proc ::hv3::sniff_doctype {text pIsXhtml} {
  upvar $pIsXhtml isXHTML
  # <!DOCTYPE TopElement Availability "IDENTIFIER" "URL">

  set QuirksmodeIdentifiers [list \
    "-//w3c//dtd html 4.01 transitional//en" \
    "-//w3c//dtd html 4.01 frameset//en"     \
    "-//w3c//dtd html 4.0 transitional//en" \
    "-//w3c//dtd html 4.0 frameset//en" \
    "-//softquad software//dtd hotmetal pro 6.0::19990601::extensions to html 4.0//en" \
    "-//softquad//dtd hotmetal pro 4.0::19971010::extensions to html 4.0//en" \
    "-//ietf//dtd html//en//3.0" \
    "-//w3o//dtd w3 html 3.0//en//" \
    "-//w3o//dtd w3 html 3.0//en" \
    "-//w3c//dtd html 3 1995-03-24//en" \
    "-//ietf//dtd html 3.0//en" \
    "-//ietf//dtd html 3.0//en//" \
    "-//ietf//dtd html 3//en" \
    "-//ietf//dtd html level 3//en" \
    "-//ietf//dtd html level 3//en//3.0" \
    "-//ietf//dtd html 3.2//en" \
    "-//as//dtd html 3.0 aswedit + extensions//en" \
    "-//advasoft ltd//dtd html 3.0 aswedit + extensions//en" \
    "-//ietf//dtd html strict//en//3.0" \
    "-//w3o//dtd w3 html strict 3.0//en//" \
    "-//ietf//dtd html strict level 3//en" \
    "-//ietf//dtd html strict level 3//en//3.0" \
    "html" \
    "-//ietf//dtd html//en" \
    "-//ietf//dtd html//en//2.0" \
    "-//ietf//dtd html 2.0//en" \
    "-//ietf//dtd html level 2//en" \
    "-//ietf//dtd html level 2//en//2.0" \
    "-//ietf//dtd html 2.0 level 2//en" \
    "-//ietf//dtd html level 1//en" \
    "-//ietf//dtd html level 1//en//2.0" \
    "-//ietf//dtd html 2.0 level 1//en" \
    "-//ietf//dtd html level 0//en" \
    "-//ietf//dtd html level 0//en//2.0" \
    "-//ietf//dtd html strict//en" \
    "-//ietf//dtd html strict//en//2.0" \
    "-//ietf//dtd html strict level 2//en" \
    "-//ietf//dtd html strict level 2//en//2.0" \
    "-//ietf//dtd html 2.0 strict//en" \
    "-//ietf//dtd html 2.0 strict level 2//en" \
    "-//ietf//dtd html strict level 1//en" \
    "-//ietf//dtd html strict level 1//en//2.0" \
    "-//ietf//dtd html 2.0 strict level 1//en" \
    "-//ietf//dtd html strict level 0//en" \
    "-//ietf//dtd html strict level 0//en//2.0" \
    "-//webtechs//dtd mozilla html//en" \
    "-//webtechs//dtd mozilla html 2.0//en" \
    "-//netscape comm. corp.//dtd html//en" \
    "-//netscape comm. corp.//dtd html//en" \
    "-//netscape comm. corp.//dtd strict html//en" \
    "-//microsoft//dtd internet explorer 2.0 html//en" \
    "-//microsoft//dtd internet explorer 2.0 html strict//en" \
    "-//microsoft//dtd internet explorer 2.0 tables//en" \
    "-//microsoft//dtd internet explorer 3.0 html//en" \
    "-//microsoft//dtd internet explorer 3.0 html strict//en" \
    "-//microsoft//dtd internet explorer 3.0 tables//en" \
    "-//sun microsystems corp.//dtd hotjava html//en" \
    "-//sun microsystems corp.//dtd hotjava strict html//en" \
    "-//ietf//dtd html 2.1e//en" \
    "-//o'reilly and associates//dtd html extended 1.0//en" \
    "-//o'reilly and associates//dtd html extended relaxed 1.0//en" \
    "-//o'reilly and associates//dtd html 2.0//en" \
    "-//sq//dtd html 2.0 hotmetal + extensions//en" \
    "-//spyglass//dtd html 2.0 extended//en" \
    "+//silmaril//dtd html pro v0r11 19970101//en" \
    "-//w3c//dtd html experimental 19960712//en" \
    "-//w3c//dtd html 3.2//en" \
    "-//w3c//dtd html 3.2 final//en" \
    "-//w3c//dtd html 3.2 draft//en" \
    "-//w3c//dtd html experimental 970421//en" \
    "-//w3c//dtd html 3.2s draft//en" \
    "-//w3c//dtd w3 html//en" \
    "-//metrius//dtd metrius presentational//en" \
  ]

  set isXHTML 0
  set idx [string first <!DOCTYPE $text]
  if {$idx < 0} { return "quirks" }

  # Try to parse the TopElement bit. No quotes allowed.
  incr idx [string length "<!DOCTYPE "]
  while {[string range $text $idx $idx] eq " "} { incr idx }

  set TopElement   [string tolower [next_word $text $idx idx]]
  set Availability [string tolower [next_word $text $idx idx]]
  set Identifier   [string tolower [next_word $text $idx idx]]
  set Url          [next_word $text $idx idx]

#  foreach ii [list TopElement Availability Identifier Url] {
#    puts "$ii -> [set $ii]"
#  }

  # Figure out if this should be handled as XHTML
  #
  if {[string first xhtml $Identifier] >= 0} {
    set isXHTML 1
  }


  if {$Availability eq "public"} {
    set s [expr [string length $Url] > 0]
    if {
         $Identifier eq "-//w3c//dtd xhtml 1.0 transitional//en" ||
         $Identifier eq "-//w3c//dtd xhtml 1.0 frameset//en" ||
         ($s && $Identifier eq "-//w3c//dtd html 4.01 transitional//en") ||
         ($s && $Identifier eq "-//w3c//dtd html 4.01 frameset//en")
    } {
      return "almost standards"
    }
    if {[lsearch $QuirksmodeIdentifiers $Identifier] >= 0} {
      return "quirks"
    }
  }

  return "standards"
}


proc ::hv3::configure_doctype_mode {html text pIsXhtml} {
  upvar $pIsXhtml isXHTML
  set mode [sniff_doctype $text isXHTML]

  switch -- $mode {
    "quirks"           { set defstyle [::tkhtml::htmlstyle -quirks] }
    "almost standards" { set defstyle [::tkhtml::htmlstyle] }
    "standards"        { set defstyle [::tkhtml::htmlstyle]
    }
  }

  $html configure -defaultstyle $defstyle -mode $mode

#  puts "Using mode $mode"
  return $mode
}

