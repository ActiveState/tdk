# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################

if {[string match -psn* [lindex $::argv 0]]} {
    # Strip Apple's option providing the Processor Serial Number to bundles.
    incr ::argc -1
    set  ::argv [lrange $::argv 1 end]
}

# Get full pathname to this file
set ScriptDir [file normalize [file dirname [info script]]]
#cd $ScriptDir

# Command to create a full pathname in this file's directory
proc Path {args} {
    return [file normalize [eval [list file join $::ScriptDir] $args]]
}

lappend auto_path [Path lib]

# ### ######### ###########################
## Command line interface for TclVFSE.
## 
## tclvfse ARCHIVE ls
## tclvfse ARCHIVE cp PATH-IN-ARCHIVE PATH'
## tclvfse ARCHIVE cp PATH' PATH-IN-ARCHIVE
## tclvfse ARCHIVE rm PATH-IN-ARCHIVE...
## tclvfse ARCHIVE vacuum
## tclvfse ARCHIVE open
##
## open is the implied command if none is given

if {[llength $argv] > 1} {
    # Archive + command, or multiple archives.

    lassign $argv f c
    if {[file pathtype $f] ne "absolute"} {
	# The global var basepwd is set in main.tcl
	set f [file join $basepwd $f]
    }
    # Load cli command implementations
    source [Path cli.tcl]
    if {$c in [cli::commands]} {
	set argv [cli::do $f $c [lrange $argv 2 end]]
	set argc [llength $argv]
    }
}

##
# ### ######### ###########################

package require BWidget
package require splash
package require img::png

set top .
wm withdraw $top

#bind . <Double-3> {console show}

set ::TILE 1
set ::AQUA [expr {[tk windowingsystem] eq "aqua"}]

if {$::AQUA} {
    set ::tk::mac::useThemedToplevel 1
    interp alias {} s {} ::tk::unsupported::MacWindowStyle style
}

package require tile
if {[package vsatisfies [package present Tk] 8.5]} {
    # Tk 8.5+ (incl. tile)
    ttk::style configure Slim.Toolbutton -padding 1
} else {
    # Tk 8.4, tile is separate
    style default Slim.Toolbutton -padding 1
}

#package require comm
#set ::COMM [comm::comm self]

package require fsb
package require fsv

# we have to require this after other packages to make sure that
# the modified bindings are done after other packages are loaded.
package require style::as
style::as::init
style::as::enable control-mousewheel global

# make tree widgets use theming on non-x11 platforms
if {[tk windowingsystem] ne "x11"} {
    option add *TreeCtrl.useTheme 1
}

# Sources

## NOTE - Helpballoon - XREF package "helpballoon"
## NOTE - Toolbar     - XREF package "toolbar"

set files {menus toolbar defaults action msgbox}
foreach file $files {source [Path $file.tcl]}

proc MakeMainWindow {top} {
    if {$top eq "."} { set w "" } else { set w $top }
    wm title    $top "VFS Explorer"
    MakeMenuBar $top

    fsb $w.fsb \
	-data [fsv fs] \
	-closecmd [list action::setViewPane ""] \
	-show     action::showactive \
	-style details

    # Separator
    ttk::separator $w.div0 -orient horizontal
    # Toolbar
    MakeToolbar [ttk::frame $w.tbar]

    grid $w.div0 -row 0 -sticky ew
    grid $w.tbar -row 1 -sticky ew
    #grid $w.div1 -row 2 -sticky ew
    grid $w.fsb  -row 3 -sticky news

    grid columnconfigure $top 0 -weight 1
    grid rowconfigure    $top 3 -weight 1

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
	carbon::setProcessName [carbon::getCurrentProcess] TclVFSE
    }

    action::gotoSetup
    return
}

proc startup {top} {
    if {$top eq "."} { set w "" } else { set w $top }
    global W argv argv0 basepwd ; # basepwd is in main.tcl
    set W(root) $top

    splash::start

    MakeMainWindow  $top

    set cur [$top cget -cursor]
    $top configure -cursor watch
    update idle

    wm deiconify $top

    splash::complete
    update

    # ### ######### ###########################
    ## Handle arguments ...

    if {[llength $argv] == 0} {
	action::mountvol
    } else {
	foreach f $argv {
	    if {[file pathtype $f] ne "absolute"} {
		set f [file join $basepwd $f]
	    }

	    #puts @@@@@@@@@@@@@@@@@@\[$f

	    if {[catch {
		action::mountarchiveasroot $f
	    } msg]} {
		tk_messageBox -parent $top -title "Mount error" \
			-message "The archive file \"$f\" could\
			not be mounted. We were given the message:\n\t$msg" \
			-icon error -type ok
		return
	    }
	}
    }

    $top configure -cursor $cur
}

startup $top
