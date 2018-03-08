# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-

#
# Example script containing tcl code using features above and beyond
# version 8.3.1 of the tcl core. This code is used to test the
# extended tclpro checker.
#

# === 8.4   ============ ============ ============ ============

# ________________________________________________
# Changes in Tcl ...

package require dde     1.2
package require tcltest 2.0

# ________________________________________________
# New commands
# 

# Known problems in check of "lset" ...
#
# Currently there is no check that the nesting of the list actually
# matches the number of indices provided by the caller. I.e. there
# have to less or equal indices than the nesting. Requires context
# sensitive check (digging into the literal list) and a custom checker
# command.

# lset list ?index ...? newvalue

set list {a b c d ef g h}

lset {a b c d ef g h} 2 C
lset {a b c d ef g h} C
lset {a b c d ef g h}           2 3 C ; # undetected error
lset {a b {c i j k l} d ef g h} 2 3 C
lset $list            2 C
lset $list            2 3 C
lset
lset $list
lset foo 2 3 C                        ; # undetected error

# ________________________________________________
# New subcommands

array set        a {}
array statistics a

file normalize foo/bar/../blub
file normalize
file normalize foo/bar/../blub brag

file separator
file separator foo/bla
file separator foo/bla zap

file system
file system foo/bla
file system foo/bla zap

info functions
info functions *
info functions * zap
info functions blo*

interp recursionlimit
interp recursionlimit {}
interp recursionlimit {} 4000
interp recursionlimit {a b} 100 .
interp recursionlimit {a b} 100
interp recursionlimit {a b} 0
interp recursionlimit "\{\{" 1

namespace exists
namespace exists foo
namespace exists foo bar

# ________________________________________________
# Added warnings for debugging power commands ...

memory foo

# ________________________________________________
# Old-style variable tracing is deprecated, new interface also allows
# command traces.

proc foo {name idx op} {}
proc p {} {}

trace variable a rw foo
trace vdelete  a rw foo
trace vinfo    a

trace add    variable a {read unset array write} foo
trace add    command  p {rename delete}          foo
trace remove variable a {read unset array write} foo
trace remove command  p {rename delete}          foo
trace list   variable a
trace list   command  p
trace
trace foo    foo      foo foo foo
trace add    foo      foo foo foo
trace remove foo      foo foo foo
trace list   foo      foo
trace add    variable a {r w} foo
trace add    command  p {r d} foo

# ________________________________________________
# Extended syntax of existing subcommands.

array names a -regexp "a$" ; # new mode
array names a -exact  "a$" ; # new mode
array names a -glob   "a$" ; # new mode
array names a -foo    "a$" ; # invalid mode
array names a         "a$"

# ________________________________________________

binary format  wW 5     ; # new format specifiers
binary scan $v wW wa wb ; #

binary format  i1I 5     ; # old format specifiers
binary scan $v iI* ia ib ; #

binary format  i0 5     ; # invalid count
binary format  i-1 5    ; # invalid count
binary format  i+1 5    ; # invalid count

binary format  k 5      ; # invalid format specifiers
binary scan $v k ka     ; #

# ________________________________________________

glob -tails -directory [pwd] *

# ________________________________________________

info script foo/bar

# ________________________________________________

lindex $list 1        ; # old syntax
lindex $list end      ; # old syntax
lindex $list end-1    ; # old syntax
lindex $list          ;
lindex $list 1 2      ;
lindex $list 1 2 3    ;
lindex $list {1 2 3}  ;
lindex $list {1 3} 1  ; # error

# ________________________________________________

lsearch -all         $list foo
lsearch -ascii       $list foo
lsearch -decreasing  $list foo
lsearch -dictionary  $list foo
lsearch -increasing  $list foo
lsearch -inline      $list foo
lsearch -integer     $list foo
lsearch -not         $list foo
lsearch -real        $list foo
lsearch -sorted      $list foo
lsearch -start       $list foo
lsearch -start 1     $list foo
lsearch -start end   $list foo
lsearch -start end-1 $list foo
lsearch -start foo   $list foo

# ________________________________________________

unset             bar -foo    ; # ok ! (-foo is varname)
unset             foo  bar    ; # ok
unset             -foo bar    ; # ok ! s.a.
unset             -foo        ; # ok ! s.a.
unset -nocomplain foo bar     ; # ok
unset -nocomplain -- -foo bar ; # ok
unset -nocomplain -foo bar    ; # ok ! s.a.
unset -nocomplain -nocomplain ; # ok
unset --          -nocomplain ; # ok
unset -foo        -nocomplain ; # ok ! s.a.

# ________________________________________________

set string [regsub $pattern $string {}]

# ________________________________________________

fcopy a b

# ________________________________________________

source foo

# ________________________________________________

format %ld 5        ; # warn
format %%
format {%5$-0*h}  5 ; # error
format {%1$-0*hi} 5 ; # error
format {%5$-0h}   5 ; # error
format {%1$-0hi}  5
format %04.3f 4.4
format %04.3k 4.4   ; # error

# ________________________________________________

scan 5 %ld v

# ________________________________________________

set tcl_traceExec    2
set tcl_traceCompile 1
set a $tcl_platform(wordSize)
set a $tcl_platform
set a(b) 5

set a(b) $c(d)
set a(b) ${c(d)}
set a(b) ${c}(d)

set tcl_platform 5
set tcl_platform(os) foo

# ________________________________________________

subst "......"

# ________________________________________________

set chan [open /dev/ttyS0]

fconfigure $chan -mode baud,parity,data,stop  ; # error, violates N1,[noems],[5678],[12]
fconfigure $chan -mode 1200,n,8,2
fconfigure $chan -mode 1200,n,8,3

fconfigure $chan -handshake                   ; # error (query), not flagged
fconfigure $chan -handshake     none          ; # nonport/WU, (none,rtscts,xonxoff,dtrdsr[win]), no query
fconfigure $chan -handshake     rtscts
fconfigure $chan -handshake     xonxoff
fconfigure $chan -handshake     dtrdsr
fconfigure $chan -handshake     foo

fconfigure $chan -queue                       ; # nonport/WU, query only
fconfigure $chan -queue foo

fconfigure $chan -ttystatus                   ; # nonport/WU, query only
fconfigure $chan -ttystatus foo

fconfigure $chan -timeout                     ; # error (query) not flagged
fconfigure $chan -timeout       0             ; # nonport/WU, N1, no query
fconfigure $chan -timeout       10
fconfigure $chan -timeout       msec

fconfigure $chan -pollintervall 0             ; # nonport/W,  N1 
fconfigure $chan -pollintervall 10
fconfigure $chan -pollintervall msec

# signalMap = {signal boolean signal boolean ...}
#              signal in {txd rxd rts cts dtr dsr dcd ri break} (case independent) 
#
fconfigure $chan -ttycontrol                  ; # error (query), not flagged
fconfigure $chan -ttycontrol    signalMap     ; # nonport/WU, map see below, no query
fconfigure $chan -ttycontrol    {TXD 0   RXD 1}
fconfigure $chan -ttycontrol    {RTS 0   CTS on}
fconfigure $chan -ttycontrol    {DTR off DSR on}
fconfigure $chan -ttycontrol    {DCD 0   RI  1}
fconfigure $chan -ttycontrol    {BREAK 0}
fconfigure $chan -ttycontrol    {TXD 0   RXD}   ; # error, not flagged
fconfigure $chan -ttycontrol    {____ 0}

fconfigure $chan -xchar         charPair      ; # nonport/WU, charPair = {char char}
fconfigure $chan -xchar         {on off}
fconfigure $chan -xchar         {on off zap}

# sizeList = N1 | {N1 N1}
#
fconfigure $chan -sysbuffer     sizeList      ; # nonport/W,  see below
fconfigure $chan -sysbuffer     1
fconfigure $chan -sysbuffer     1 2
fconfigure $chan -sysbuffer     {1 2}
fconfigure $chan -sysbuffer     0

# ________________________________________________

expr 5+3
expr {5+3}
expr {5+$i}
expr 5+3*4
expr (5+3)*4
expr {5-[p]}
expr 5 - [p]
expr 5 + 3
expr {($a != $b) * sin(f($x))}
expr {($a != $b) * wide(f($x))}
expr {$a ? "b" : "c"}

expr {"a" eq "b"}
expr {"a" eq$b}
expr {${b}eq$b}

expr {"a" ne "b"}
expr {"a" ne$b}
expr {${b}ne$b}

# ________________________________________________
# Changes in Tk ...

set    tkPriv(activeItem) foo
set a $tkPriv(activeItem)
set b $tkPriv

set    tk::Priv(activeItem) foo
set a $tk::Priv(activeItem)
set b $tk::Priv

namespace eval tk {
    set    Priv(activeItem) foo
    set a $Priv(activeItem)
    set b $Priv
}

# ________________________________________________

tk_getSaveFile
tk_getOpenFile

tk_getSaveFile -multiple
tk_getOpenFile -message

tk_getSaveFile -message
tk_getOpenFile -multiple

tk_getSaveFile -multiple 0
tk_getOpenFile -message foo

# ________________________________________________

text .t -undo 0
text .t -undo foo
text .t -autoseparators 0
text .t -autoseparators foo

# ________________________________________________

radiobutton .rb -overrelief raised 
radiobutton .rb -overrelief sunken 
radiobutton .rb -overrelief flat 
radiobutton .rb -overrelief ridge 
radiobutton .rb -overrelief solid 
radiobutton .rb -overrelief groove
radiobutton .rb -overrelief foo

# ________________________________________________

checkbutton .cb -overrelief raised 
checkbutton .cb -overrelief sunken 
checkbutton .cb -overrelief flat 
checkbutton .cb -overrelief ridge 
checkbutton .cb -overrelief solid 
checkbutton .cb -overrelief groove
checkbutton .cb -overrelief foo

# ________________________________________________

entry .en -overrelief raised 
entry .en -overrelief sunken 
entry .en -overrelief flat 
entry .en -overrelief ridge 
entry .en -overrelief solid 
entry .en -overrelief groove
entry .en -overrelief foo

# ________________________________________________

button .b -compound none
button .b -compound bottom
button .b -compound top
button .b -compound left
button .b -compound right
button .b -compound center
button .b -compound foo
	
button .b -overrelief raised 
button .b -overrelief sunken 
button .b -overrelief flat 
button .b -overrelief ridge 
button .b -overrelief solid 
button .b -overrelief groove
button .b -overrelief foo

# ________________________________________________

bell -nice
bell
bell -displayof .rb -nice

# ________________________________________________

frame .f -padx foo
frame .f -pady foo

frame .f -padx 1m
frame .f -pady 1c

# ________________________________________________

listbox .lb -state foo
listbox .lb -state normal
listbox .lb -disabledforeground red

# ________________________________________________

menubutton .mb -compound none
menubutton .mb -compound bottom
menubutton .mb -compound top
menubutton .mb -compound left
menubutton .mb -compound right
menubutton .mb -compound center
menubutton .mb -compound foo

# ________________________________________________

grid configure .f -padx 1
grid configure .f -pady 2
grid configure .f -padx {1 2}
grid configure .f -pady {3 4}

grid columnconfigure .f 1 -uniform
grid columnconfigure .f 1 -uniform foo

grid rowconfigure    .f 2 -uniform
grid rowconfigure    .f 2 -uniform foo

# ________________________________________________

pack configure .f -padx 1
pack configure .f -pady 2
pack configure .f -padx {1 2}
pack configure .f -pady {3 4}

# ________________________________________________

clipboard get

# ________________________________________________

image inuse
image inuse image0

# ________________________________________________

wm stackorder                ; # /
wm stackorder foo            ; # /
wm stackorder .f             ; # 
wm stackorder .f foo         ; # /
wm stackorder .f .w          ; # /
wm stackorder .f isabove .w  ; # 
wm stackorder .f isbelow .w  ; # 
wm stackorder .f foo .w      ; # /
wm stackorder .f foo .w foo  ; # /

# ________________________________________________

spinbox .s
      
spinbox .s -activebackground    red
spinbox .s -highlightthickness 1
spinbox .s -repeatinterval 1
spinbox .s -background      red    
spinbox .s -insertbackground   red
spinbox .s -selectbackground red
spinbox .s -borderwidth         2
spinbox .s -insertborderwidth  2
spinbox .s -selectborderwidth 2
spinbox .s -cursor             arrow 
spinbox .s -insertontime       1
spinbox .s -selectforeground blue
spinbox .s -exportselection    on 
spinbox .s -insertwidth        1
spinbox .s -takefocus 1
spinbox .s -font       helvetica         
spinbox .s -insertofftime      4
spinbox .s -textvariable  foo
spinbox .s -foreground       red   
spinbox .s -justify            right
spinbox .s -xscrollcommand .r
spinbox .s -highlightbackground red
spinbox .s -relief sunken
spinbox .s -highlightcolor      red
spinbox .s -repeatdelay 5
spinbox .s -buttonbackground red
spinbox .s -buttoncursor cross
spinbox .s -buttondownrelief raised
spinbox .s -buttonuprelief groove
spinbox .s -command p
spinbox .s -disabledbackground red
spinbox .s -disabledforeground red
spinbox .s -format checkWord
spinbox .s -from 0.5
spinbox .s -invalidcommand p
spinbox .s -invcmd p
spinbox .s -increment 0.77
spinbox .s -readonlybackground red
spinbox .s -state normal
spinbox .s -state disabled
spinbox .s -state readonly
spinbox .s -state foo
spinbox .s -to 1.5
spinbox .s -validate none
spinbox .s -validate focus
spinbox .s -validate focusin
spinbox .s -validate focusout
spinbox .s -validate key
spinbox .s -validate all
spinbox .s -validate foo
spinbox .s -validatecommand checkWord
spinbox .s -vcmd checkWord
spinbox .s -values {checkList foo zap}
spinbox .s -width 1
spinbox .s -wrap off

# ________________________________________________

panedwindow .pw

panedwindow .pw -background red
panedwindow .pw -height 50
panedwindow .pw -width 70
panedwindow .pw -borderwidth 3
panedwindow .pw -orient vertical
panedwindow .pw -cursor arrow
panedwindow .pw -relief sunken
panedwindow .pw -handlepad 5
panedwindow .pw -handlesize 66
panedwindow .pw -opaqueresize off
panedwindow .pw -sashcursor arrow
panedwindow .pw -sashpad 5
panedwindow .pw -sashrelief groove
panedwindow .pw -sashwidth 44
panedwindow .pw -showhandle on

# ________________________________________________

labelframe .lf

labelframe .lf -borderwidth   1
labelframe .lf -highlightbackground   red
labelframe .lf -pady                2
labelframe .lf -cursor        arrow
labelframe .lf -highlightcolor     green
labelframe .lf -relief sunken
labelframe .lf -font  courier
labelframe .lf -highlightthickness    2
labelframe .lf -takefocus off
labelframe .lf -foreground   blue 
labelframe .lf -padx  1
labelframe .lf -text  zap
labelframe .lf -background red
labelframe .lf -class foo
labelframe .lf -colormap new
labelframe .lf -colormap .pw
labelframe .lf -colormap foo
labelframe .lf -container off
labelframe .lf -height 4c
labelframe .lf -labelanchor nw
labelframe .lf -labelanchor n
labelframe .lf -labelanchor ne
labelframe .lf -labelanchor en
labelframe .lf -labelanchor e
labelframe .lf -labelanchor es
labelframe .lf -labelanchor se
labelframe .lf -labelanchor ssw
labelframe .lf -labelanchor ws
labelframe .lf -labelanchor w
labelframe .lf -labelanchor wn
labelframe .lf -labelanchor foo
labelframe .lf -labelwidget .pw
labelframe .lf -visual best
labelframe .lf -width 3m

# ________________________________________________

tkButtonDown
tkButtonEnter
tkButtonInvoke
tkButtonLeave
tkButtonUp
tkCancelRepeat
tkCheckRadioInvoke
tkEntryAutoScan
tkEntryBackspace
tkEntryButton1
tkEntryClosestGap
tkEntryGetSelection
tkEntryInsert
tkEntryKeySelect
tkEntryMouseSelect
tkEntryNextWord
tkEntryPaste
tkEntryPreviousWord
tkEntrySeeInsert
tkEntrySetCursor
tkEntryTranspose
tkEventMotifBindings
tkFirstMenu
tkGenerateMenuSelect
tkListboxAutoScan
tkListboxBeginExtend
tkListboxBeginSelect
tkListboxBeginToggle
tkListboxCancel
tkListboxDataExtend
tkListboxExtendUpDown
tkListboxMotion
tkListboxSelectAll
tkListboxUpDown
tkMbButtonUp
tkMbEnter
tkMbLeave
tkMbMotion
tkMbPost
tkMenuButtonDown
tkMenuDownArrow
tkMenuEscape
tkMenuFind
tkMenuFindName
tkMenuFirstEntry
tkMenuInvoke
tkMenuLeave
tkMenuLeftArrow
tkMenuMotion
tkMenuNextEntry
tkMenuNextMenu
tkMenuRightArrow
tkMenuUnpost
tkMenuUpArrow
tkPostOverPoint
tkRestoreOldGrab
tkSaveGrabInfo
tkScaleActivate
tkScaleButton2Down
tkScaleButtonDown
tkScaleControlPress
tkScaleDrag
tkScaleEndDrag
tkScaleIncrement
tkScreenChanged
tkScrollButton2Down
tkScrollButtonDown
tkScrollButtonUp
tkScrollByPages
tkScrollByUnits
tkScrollDrag
tkScrollEndDrag
tkScrollSelect
tkScrollStartDrag
tkScrollToPos
tkScrollTopBottom
tkTabToWindow
tkTextAutoScan
tkTextButton1
tkTextClosestGap
tkTextInsert
tkTextKeyExtend
tkTextKeySelect
tkTextNextPara
tkTextNextPos
tkTextNextWord
tkTextPaste
tkTextPrevPara
tkTextPrevPos
tkTextResetAnchor
tkTextScrollPages
tkTextSelectTo
tkTextSetCursor
tkTextTranspose
tkTextUpDownLine
tkTraverseToMenu
tkTraverseWithinMenu

