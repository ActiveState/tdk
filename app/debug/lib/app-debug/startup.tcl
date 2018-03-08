# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# startup.tcl --
#
#	This file is the primary entry point for the 
#       TclPro Debugger.
#
# Copyright (c) 1999 by Scriptics Corporation.

# 
# RCS: @(#) $Id: startup.tcl,v 1.13 2001/01/24 19:41:24 welch Exp $

# Initialize the debugger library

if {[string match -psn* [lindex $::argv 0]]} {
    # Strip Apple's option providing the Processor Serial Number to bundles.
    incr ::argc -1
    set  ::argv [lrange $::argv 1 end]
}

if {[set pos [lsearch -exact $argv -display]] >= 0} {

    set nxt $pos ; incr nxt

    set v [lreplace $argv $pos $nxt] ; set argv [lrange $argv $pos $nxt]
    set c [expr {$argc - 2}]         ; set argc 2

} else {
    set v $argv ; set argv {}
    set c $argc ; set argc 0
}

package provide app-debug 1.0
package require Tk

set argv $v ; unset v
set argc $c ; unset c pos

package require projectInfo
package require help
package require img::png

#package require comm ; puts "COMM [comm::comm self]"

package require style::as
style::as::init
style::as::enable control-mousewheel global

set icon {
    iVBORw0KGgoAAAANSUhEUgAAACAAAAAfCAYAAACGVs+MAAAABmJLR0QA/wD/
    AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAB3RJTUUH1gwGAA8P/w/m
    EQAABClJREFUSMetVy+IOlsUPvu4YcIEw8AaJhgMBmEnTDAYDG7bti4oGCYY
    DAYXDAZhBFksD1wwGJZlg8EFg2GCwWD4BVlcUDC4PxRmwWBQmDCC8Eb4Xlh0
    ndX13+6BU4Y793z33HO+79wzWjMAWfoFe35+Vu/u7uj9/Z0kSaLr62uKRCL5
    8/Pz/4iIzs7ONuMAyOIXrNFogDEGIrK5KIp4eHiAZVnYOKjX6/3r8/mgadqP
    Afj9/o3g6x4Oh2Ga5ieI5cmdTid4nkcoFIKu6ycFr1arO4MvXZIkTCaTDxDB
    YBCKokCSJBiGAcMwkE6nkUwmMRgMjkq9IAgHASAiuFwumKaJs3a7jcfHR+p2
    u/Tnzx9ijBER0e3tLd3f35MsyxQIBOji4oJEUSSn00mLxYKm0ynNZjN6eXmh
    t7c3mk6n9Pr6SrPZ7OBiTSQSRMsTuN1uJBKJ5f0gk8nsPQVjDOVyGZZlwTAM
    DIdDFItFuFyug7LAcRxoPB6jXq+D53kEg0H4fD5IkrS1kr+6qqoAgEKhAI7j
    wBhDpVKBZVnQNA3hcBiiKO7eZ/nj+n2rqnrQCUzThK7rYIyB47hvu2gymUDX
    dTSbTTSbTfT7fTSbzY+O0TQNsixv/ORwOHYG93q9AIBWq7WqbFmWIQgCSqXS
    zoLtdDoQRRGapoEAIBAILNsCADCfz8Hz/E4AgUBga+87HI6d3aNpGnieRyqV
    +mjDZDIJxhh8Ph8ajQYajcZeMlkSytIMw4CqqkgkEuj3+1sDm6aJeDwOxhgy
    mczyc5YO7duvrijKUQTldrshCMLXOsn+c6rgLBaLvWuGwyHd3NxQJBKhUChE
    g8GArq6u7IsOabdt7vF4lsKyYYPBAIqigOM4KIqCTqfzXXKypCgKTr2GWCy2
    Kjhd11EqlRAMBuFwOBCPx9Hr9fbdTpZ6vd6/x3D4LhdFEZlM5hgxyxKAbLlc
    /lHgYDCIWq2G+Xx+rIBmV3JcKBSOCsoYQzQaRbPZtLXjd3WxF8CyeNLp9E4W
    FAQB6XT62zTX63W02+3TAKxT5VcmFEURxWJxpZa7LJfLIRaLwTCM4wF0Oh3b
    YMHzPPL5/EGB1y0ajUIQBFQqlcMB9Ho9W3CPx4PRaHTSeKbruo01v8nGJwDL
    suD1em1qty5Qp5jT6Vzt53a7t+nEJ4BGo2G789+YkGVZtu3J8zxardZhWuB2
    u3/8QBFFkYiIFEWhRCJBs9mMLi8vqdvtbn+QhMPhjXHrJ5ZKpUBEK65IJpMg
    Ivj9/u1FaFkWfD7famCs1Wp7ZXbX8LFk2PVOiMfjcDgctnnABmI8Hq+mWsYY
    VFXdym75fH7vXDAajcAYw9PTk+37eDzefJ6tg+j3+7bRWpKkjaKUJAlEhFwu
    tzNL5XJ5G2tufwSvg+h0OhuULMsy8vm87c1QrVaPF6A1+x8x+Wv0OUgU9wAA
    AABJRU5ErkJggg==
}
if {[tk windowingsystem] ne "aqua"} {
    wm iconphoto . -default [image create photo -data $icon]
} else {
    # On OS X put the name into the Menubar as well. Otherwise
    # the name of the interpreter executing the application is
    # used.
    package require tclCarbonProcesses 1.1
    carbon::setProcessName [carbon::getCurrentProcess] TclDebugger
}

# Specify the additional debugger parameters.
# - We keep the defaults

::help::page Debugger

if {[catch {
    # This package require loads the debugger and system modules
    package require debugger

    debugger::init $argv
} err]} {
    set f [toplevel .init_error]
    set l [label $f.label -text "Startup Error"]
    set t [text $f.text -width 50 -height 30]
    $t insert end $errorInfo
    pack $f.text -expand 1 -fill both

    catch {console show}
}

# Add the TclPro debugger extensions

#Source xmlview.tcl

# Enter the event loop.
