# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################
## From here on the actual application code.

if {[string match -psn* [lindex $::argv 0]]} {
    # Strip Apple's option providing the Processor Serial Number to bundles.
    incr ::argc -1
    set  ::argv [lrange $::argv 1 end]
}

package require log
log::lvSuppress debug

proc selfapp {} {
    set here [file dirname [info script]]
    set main [file join $here main.tcl]

    switch -exact [starkit::startup] {
	starkit {
	    set self [list \
		    [info nameofexecutable] \
		    $here]
	}
	starpack {
	    set self [list [info nameofexecutable]]
	}
	unwrapped -
	sourced {
	    set self [list \
		    [info nameofexecutable] \
		    $main]
	}
    }
    proc selfapp {} [list return $self]
    return $self
}
selfapp

proc procheck {} {
    package require tlocate
    set pc [tlocate::find tclchecker]
    proc procheck {} [list return $pc]
    return $pc
}

proc complete {tmpfile} {
    set ::complete $tmpfile
    return
}

proc complete_error {text} {
    puts $text
    exit 1
    return
}

set n 0
proc ping {} {
    global n ; incr n ; if {$n >= 10} {set n 0}
    if {$n == 0} {set c *} else {set c .}
    puts -nonewline $c ; flush stdout
    return
}

proc checkfile {label infile} {
    if {$infile == {}} {
	usage "Empty path to $label is not allowed"
    } elseif {![file exists $infile]} {
	usage "$label \"$infile\" does not exist."
    } elseif {![file readable $infile]} {
	usage "$label \"$infile\" is not readable."
    } elseif {[file size $infile] == 0} {
	usage "$label \"$infile\" is empty"
    }
}

proc blank {s} {
    regsub -all {[^	]} $s { } s
    return $s
}

proc usage {text} {
    puts stderr $text
    exit 1
}

proc abortonerror {} {
    upvar 1 cmdline_err err
    if {$err == {}} return
    usage $err
}

proc run_scan {dbfile files} {
    if {$dbfile == {} || ![llength $files]} {
	usage "wrong#args, expected: $argv0 -scan dbfile file file..."
    }

    catch {wm withdraw .}
    package require xref_gather

    # Perform glob expansion on the file arguments, in case they
    # contain globbing patterns. Very needed on win platforms where
    # cmd.exe is not expanding file patterns before invoking an
    # application.
    #
    # See tclapp, tclapp_fres.tcl (matchResolve), and tcllib,
    # cmdline.tcl (getfiles) for equivalent code used by other apps in
    # TDK.

    set res {}
    foreach pattern $files {
	regsub -all {\\} $pattern {\\\\} pat
	set efiles [glob -nocomplain -- $pat]
	if {![llength $efiles]} {
	    puts "no files match \"$pattern\""
	} else {
	    lappend res {*}$efiles
	}
    }
    set files $res

    if {![llength $files]} {
	usage "no file pattern matching any files, nothing left to process"
    }

    xref_gather td $files -command complete -ping ping

    vwait ::complete
    rename td {}
    file rename -force $::complete $dbfile
    exit 0
}

proc prepare_gui {f} {
    global mode inputfile argv

    # Regular GUI was invoked ...
    # Check the argument extensively.
    # Check that database is txr db ...

    set inputfile $f
    checkfile "TDK Xref Database file" $inputfile

    package require fileutil
    set t [fileutil::fileType $inputfile]
    if {![string match *metakit* $t]} {
	usage "The file \"$inputfile\" does not contain a TDK Xref database"
    }

    package require xrefdb
    if {[xrefdb version $inputfile] < 0} {
	usage "The file \"$inputfile\" does not contain a TDK Xref database"
    }

    set mode db:
    return
}


# Command line ...
# 1. -scan dbfile infile infile...	Scan files, generate database
# 2. -gui ?dbfile?			Open GUI with database.
# 3. -convert dbfile			INTERNAL, for use GUI scan modes
# 4. -tap tapfile			-scan for .tap, auto-invoke GUI.
#    -tpj, -komodo, -teapot
#
# Ad 3: Internal mode to convert procheck xref output
#       into the metakit database schema the GUI will
#	read (condensed data).

set mode      db:
set inputfile ""

if {[llength $argv] > 0} {
    switch -glob -- [set opt [lindex $argv 0]] {
	-scan {
	    # Scan mode, generation of a xref database ...
	    set dbfile [lindex $argv 1]
	    set files  [lrange $argv 2 end]
	    run_scan $dbfile $files
	}
	-tap {
	    # Similar to regular GUI. We start the regular GUI without
	    # anything first and then invoke the tap scanner. Before
	    # that we however check that the effort is worth it.
	    # Check the argument extensively.

	    set inputfile [lindex $argv 1]
	    checkfile "TDK Package Definition file" $inputfile
	    set mode scanTap:
	}
	-tpj {
	    # See -tap, just for .tpj (tdk project) files.
	    # Check the argument extensively.

	    set inputfile [lindex $argv 1]
	    checkfile "TDK Project file" $inputfile
	    set mode scanTpj:
	}
	-komodo {
	    # See -tap, just for .kpf (komodo project) files.
	    # Check the argument extensively.

	    set inputfile [lindex $argv 1]
	    checkfile "Komodo Project file" $inputfile
	    set mode scanKomodo:
	}
	-teapot {
	    # See -tap, just for teapot.txt (TEAPOT meta data) files.
	    # Check the argument extensively.

	    set inputfile [lindex $argv 1]
	    checkfile "TEAPOT Meta Data file" $inputfile
	    set mode scanTeapot:
	}
	-convert {
	    ## Internal
	    # Conversion of tclchecker -xref output to metakit ...
	    # Reuse the existing tool, just a different file ...
	    # Replace the -convert with a '-' for input on stdin.
	    ##

	    lset argv 0 -
	    set  argc 2
	    source [file join [file dirname [info script]] 2mk.tcl]
	    exit 0
	}
	{} {
	    # No options, regular GUI
	}
	-gui {
	    prepare_gui [lindex $argv 1]
	}
	-* {
	    # Unknown option
	    set blank [blank $argv0]
	    set     err [list "Wrong\#args, expected:"]
	    lappend err "    $argv0 -scan   dbfile file ..."
	    lappend err "    $blank -gui    dbfile"
	    lappend err "    $blank -tap    tdk-tapfile"
	    lappend err "    $blank -tpj    tdk-projectfile"
	    lappend err "    $blank -komodo komodo-projectfile"
	    lappend err "    $blank -teapot teapot-file"
	    lappend err "    $blank dbfile"
	    usage [join $err \n]
	}
	default {
	    # Some argument, maybe a file ?
	    prepare_gui $opt
	}
    }
}

package require Tk
package require splash ; # Splash screen management
wm withdraw .
splash::start

package require style::as
style::as::init
style::as::enable control-mousewheel global

package require tile
if {[package vsatisfies [package present Tk] 8.5]} {
    # Tk 8.5+ (incl. tile)
    ttk::style configure Slim.Toolbutton -padding 1
} else {
    # Tk 8.4, tile is separate
    style default Slim.Toolbutton -padding 1
}

set ::TILE 1
set ::AQUA [expr {[tk windowingsystem] eq "aqua"}]
if {$::AQUA} {
    set ::tk::mac::useThemedToplevel 1
    interp alias {} s {} ::tk::unsupported::MacWindowStyle style
}
# make tree widgets use theming on non-x11 platforms
if {[tk windowingsystem] ne "x11"} {
    option add *TreeCtrl.useTheme 1
}
option add *TreeCtrl.highlightThickness 1
option add *TreeCtrl.borderWidth 1

package require help   ; # Online help
package require xrefdb ; # xref database
package require xmain  ; # Main application window
package require img::png

# ### ######### ###########################
## package require comm ; puts [comm::comm self]

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
    carbon::setProcessName [carbon::getCurrentProcess] TclXRef
}

help::appname XRef
help::page    Xref

set main  [xmain .%AUTO%]
set delay 300

if {$inputfile ne ""} {
    after $delay [list $main $mode $inputfile]
}

splash::complete

## Run the event loop ...
## We assume a wish
