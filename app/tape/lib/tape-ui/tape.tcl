# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tape.tcl --
#
#	This file implements the main widget for the package editor
#	Main feature is a list-notebook with one page per package
#	in the file.
#
# Copyright (c) 2003-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# -----------------------------------------------------------------------------

# Notes.
#
# (1) The mode dependent dispatch of various operations to the two
#     different state packages is a hack. A cleaner solution would be for
#     the state packages to be proper singleton objects, this widget to be
#     snit-based, and then to use delegation to a component, with the
#     component switchable. Underneath it would be essentially the same
#     type of dispatch currently in use, but more readably written.

# (2) The dispatch of things through 'do' and 'potdo' should be replaced by
#     proper methods and their call from the state packages/singletons.

# -----------------------------------------------------------------------------

set  ::AQUA [expr {[tk windowingsystem] eq "aqua"}]
if {$::AQUA} {
    set ::tk::mac::useThemedToplevel 1
}

# -----------------------------------------------------------------------------

package require runwindow
package require tile
package require snit
package require widget::dialog
package require widget::scrolledwindow
package require widget::toolbar 1.2
package require image ; image::file::here
package require tipstack

package require tape::state  ; # State/data of the .TAP file under edit.
package require tape::teapot ; # State/data of the TEApot under edit.

package require tcldevkit::tape::pkgDisplay
package require tcldevkit::teapot::pkgDisplay

# -----------------------------------------------------------------------------

# Ttk style mapping for invalid entry widgets
# Handle Tk 8.5 (ttk) or 8.4 (tile) usage of style
namespace eval ::ttk {
    style map TEntry -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
    style map TCombobox -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
}

# -----------------------------------------------------------------------------

snit::widget tcldevkit::tape {
    hulltype ttk::frame

    option -errorbackground -default lightyellow

    constructor {args} {
	$self MakeWidgets
	$self PresentWidgets

	$self configurelist $args

	set selbg [$win.sw.l cget -selectbackground]
	set selfg [$win.sw.l cget -selectforeground]

	tape::state  update $win ; # Register with state singletons
	tape::teapot update $win ; # for tap and teapot

	$self ProjectType teapot ; # Default project type
	$self TrackOn            ; # Track selection
	$self TrackSel           ; #

	# Set window title and general application state

	::tcldevkit::appframe::markclean

	set save  $::tcldevkit::appframe::appName
	::tcldevkit::appframe::setName {TclApp PackageDefinition}
	wm title . $save

	trace variable nsp_dir w [mymethod NSPTrack]
	trace variable ga_dir  w [mymethod GATrack]
	return
    }

    destructor {
	trace vdelete nsp_dir w [mymethod NSPTrack]
	trace vdelete ga_dir  w [mymethod GATrack]
    }

    method MakeWidgets {} {
	# No toggle, aka tap/pot conversion. Use pot scan for packages
	# to convert, heuristics are better.

	# --- ---
	# Toolbar for actions.
	widget::toolbar $win.tb -separator bottom

	foreach {btn label method sep img} {
	    new   "New"              NewPackage     1 package_add
	    scan  "New/Scan"         NewScanPackage 0 directory_rec
	    del   "Delete"           DelPackage     1 delete
	    exp   "Expand to dir"    ExpandToDir    1 arrow_out
	    gen   "Generate Arch"    GenArchives    0 package_go
	} {
	    $win.tb add button $btn \
		-image     [image::get $img]  \
		-command   [mymethod $method] \
		-separator $sep
	}
	$win.tb add space

	# --- ---
	# Info area at the top showing the path to the loaded project
	# and type indicators.

	ttk::frame $win.pinfo -relief sunken
	ttk::label $win.ptype -image [image::get package_pot]
	ttk::label $win.ftype -image [image::get teabag_none]
	ttk::label $win.fpath

	# --- ---
	# List of packages, and display of the information for the
	# package selected in that list. Tied together by a paned
	# window to allow user to change space allocation.

	# Listbox showing the names of all packages currently known to
	# the editor state

	widget::scrolledwindow $win.sw   -borderwidth 1 -relief sunken
	listbox                $win.sw.l -selectmode extended -bd 0 -width 20
	$win.sw setwidget $win.sw.l

	# Package display TAP / TEAPOT. Switched according to type of
	# current project. Contents of the display itself is switched
	# based on the selected package (in the listbox).

	ttk::frame                    $win.detail
	tcldevkit::tape::pkgDisplay   $win.pdt -connect tape::state
	tcldevkit::teapot::pkgDisplay $win.pdp -connect tape::teapot

	# Tie them into the panes

	ttk::panedwindow $win.pkg -orient horizontal
	$win.pkg add $win.sw     -weight 1
	$win.pkg add $win.detail -weight 2

	raise $win.sw
	return
    }

    method PresentWidgets {} {

	# Main areas ... Rows

	foreach {slave col row stick padx pady cspan rspan ix iy comment} {
	    .tb    0 0 ew   0  0  1 1 0  0  {toolbar, top}
	    .pinfo 0 1 swe  0  0  1 1 0  0  {project information, 2nd row}
	    .pkg   0 2 swen 0  0  1 1 0  0  {package display, 3rd row}
	} {
	    grid $win$slave -column $col -row $row -sticky $stick \
		-ipadx $ix -ipady $iy \
		-padx $padx -pady $pady -rowspan $rspan -columnspan $cspan
	}

	grid columnconfigure $win 0 -weight 1

	grid rowconfigure $win 0 -weight 0
	grid rowconfigure $win 1 -weight 0
	grid rowconfigure $win 2 -weight 1

	# Project information ... Columns

	foreach {slave col row stick padx pady cspan rspan ix iy comment} {
	    .ptype 0 0 wn  1m 1m 1 1 1m 1m {project type, leftmost}
	    .ftype 1 0 wn  1m 1m 1 1 1m 1m {file type, middle}
	    .fpath 2 0 swn 1m 1m 1 1 1m 1m {project path, rightmost}
	} {
	    grid $win$slave -column $col -row $row -sticky $stick \
		-ipadx $ix -ipady $iy \
		-padx $padx -pady $pady -rowspan $rspan -columnspan $cspan \
		-in $win.pinfo
	}

	grid columnconfigure $win.pinfo 0 -weight 0
	grid columnconfigure $win.pinfo 1 -weight 0
	grid columnconfigure $win.pinfo 2 -weight 1

	grid rowconfigure    $win.pinfo 0 -weight 0

	# Package display (details) ...
	# Note: pdt and pdp are on top of each other. Whichever of the
	# two is needed per the project type is raised to the front.

	foreach {slave col row stick padx pady cspan rspan ix iy comment} {
	    .pdt 0 0 swen 1m 1m 1 1 0  0  {tap display, right of list}
	    .pdp 0 0 swen 1m 1m 1 1 0  0  {pot display, right of list}
	} {
	    grid $win$slave -column $col -row $row -sticky $stick \
		-ipadx $ix -ipady $iy \
		-padx $padx -pady $pady -rowspan $rspan -columnspan $cspan \
		-in $win.detail
	}

	grid rowconfigure    $win.detail 0 -weight 1
	grid columnconfigure $win.detail 0 -weight 1

	# Tool tips ...

	tipstack::defsub $win {
	    .ftype {Type of the package origin}
	    .fpath {Origin of the package information}
	    .ptype {Type of the current project}
	    .sw    {Names of all currently known packages}
	    .pdt   {Information of the TAP package selected at the left}
	    .pdp   {Information of the TEApot package selected at the left}
	}

	tipstack::def [list \
		[$win.tb itemid new]  {Create new package} \
		[$win.tb itemid scan] {Create new packages, scan directory} \
		[$win.tb itemid del]  {Delete selected packages} \
		[$win.tb itemid exp]  {Expand TEApot Archive to directory} \
		[$win.tb itemid gen]  {Generate TEApot Archives} \
	  ]

	bind $win.pkg <Map> [mymethod WatchGeometries]
	return
    }

    method WatchGeometries {} {
	#puts watch
	bind $win.pkg <Map> {}
	after 10 [mymethod DoGeom]
    }

    method DoGeom {} {
	update idletasks
	set total    [winfo width $win.pkg]
	set relative 0.25
	set sash     [expr {int(double($relative) * double($total))}]

	# FUTURE: Save to/Restore from TDK global
	# preferences/defaults.

	$win.pkg sashpos 0 $sash
	return
    }

    variable state   {} ; # Prj.type dependent state object.
    variable pd      {} ; # Prj.type dependent package display.
    variable ptype   {} ; # Current project type
    variable selbg   {}
    variable selfg   {}
    variable lastdir {}


    method TrackOn {} {
	bind $win.sw.l <<ListboxSelect>> [mymethod TrackSel]
	return
    }

    method TrackOff {} {
	bind $win.sw.l <<ListboxSelect>> {}
	return
    }

    method TrackSel {} {
	# Whenever the selection in the list of packages changes we
	# have to motify the internal state so that it can switch the
	# package display to the appropriate data.

	set sel [$win.sw.l curselection]

	$state setSelectionTo $sel
	$self  UpdateDelBtn   $sel
	return
    }

    method ProjectType? {} {
	return $ptype
    }

    method ProjectType {pt} {
	if {$pt eq $ptype} return
	set ptype $pt
	switch -exact -- $pt {
	    teapot {
		set pd    $win.pdp
		set state tape::teapot
	    }
	    tap {
		set pd    $win.pdt
		set state tape::state
	    }
	    default {error "internal error - bad project type"}
	}

	set s [expr {[$state addOk] ? "normal" : "disabled"}]
	$win.tb itemconfigure new  -state $s
	$win.tb itemconfigure scan -state $s

	# Make associated package display visible
	raise $pd

	# Change source of package list.
	$win.sw.l configure -listvar [$state pkgListVar]

	$self UpdateTypeDisplay
	return
    }

    method UpdateTypeDisplay {} {
	if {$ptype eq "tap"} {
	    set pimage [image::get package_tap]
	    set ptext  {TAP project}

	    set fimage {}
	    set ftext  {}

	    $win.tb itemconfigure gen -state disabled
	    $win.tb itemconfigure exp -state disabled
	} else {
	    set pimage [image::get package_pot]
	    set ptext  {TEAPOT project}
	    set gen    disabled
	    set exp    disabled

	    switch -exact -- [::tape::teapot getInputType] {
		{}  {
		    set fimage [image::get teabag_none]
		    set ftext  {Undefined file type}
		}
		tm-header {
		    set fimage [image::get teabag_tm]
		    set ftext  {TEAPOT Tcl Module}
		    set exp normal
		}
		tm-mkvfs {
		    set fimage [image::get teabag_tm]
		    set ftext  {TEAPOT Tcl Module with attached Mk filesystem (KIT|EXE)}
		    set exp normal
		}
		zip {
		    set fimage [image::get teabag_zip]
		    set ftext  {TEAPOT Zip Archive}
		    set exp normal
		}
		pot {
		    set fimage [image::get teabag_pot]
		    set ftext  {TEAPOT Package directory}

		    # generation possible only if >= 1 packages available.
		    # hacky: accessing pot state directly. Should be queried
		    # through accessor, or made notification based.
		    if {[llength $tape::teapot::packages]} {
			set gen normal
		    }
		}
	    }

	    $win.tb itemconfigure gen -state $gen
	    $win.tb itemconfigure exp -state $exp
	}

	$win.ptype configure -image $pimage
	$win.ftype configure -image $fimage
	$win.fpath configure -text  [$state getInputFile]

	tipstack::def [list \
			   $win.ptype $ptext \
			   $win.ftype $ftext \
			  ]
	return
    }

    method UpdateDelBtn {sel} {
	if {[$state deleteOk] && ([llength $sel] > 0)} {
	    $win.tb itemconfigure del -state normal
	} else {
	    $win.tb itemconfigure del -state disabled
	}
	return
    }

    method reset_tap {} {
	$self reset 
	$self ProjectType tap
	::tcldevkit::appframe::SaveMenuStateHookInvoke noproject
	return
    }

    method NewPackage {} {
	$state NewPackage
	$self UpdateTypeDisplay
	::tcldevkit::appframe::markdirty
	return
    }

    variable nsp_dir {}

    method NewScanPackage {} {
	if {![winfo exists $win.nsp]} {

	    widget::dialog $win.nsp -modal local -transient 1 \
		-parent $win -place center \
		-command [mymethod NSPClose]
	    set ok [$win.nsp add button -text [msgcat::mc "OK"] \
			-default active \
			-command [list $win.nsp close ok]]
	    set frame [$win.nsp getframe]

	    ttk::labelframe $frame.x -text Destination
	    ttk::labelframe $frame.a -text Log

	    ttk::entry  $frame.d -textvariable [myvar nsp_dir]
	    ttk::button $frame.b -image [image::get file] \
		-command [mymethod NSPDir $frame]
	    runwindow $frame.r -command [mymethod NSPRun $frame $ok] \
		-labelhelp {Generate archives}

	    grid $frame.x -column 0 -row 0 -sticky swen -padx 1m -pady 1m
	    grid $frame.a -column 0 -row 1 -sticky swen -padx 1m -pady 1m
	    grid $frame.d -column 0 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.x
	    grid $frame.b -column 1 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.x
	    grid $frame.r -column 0 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.a

	    grid columnconfigure $frame 0 -weight 1
	    grid rowconfigure    $frame 0 -weight 0
	    grid rowconfigure    $frame 1 -weight 1

	    grid columnconfigure $frame.x 0 -weight 1
	    grid columnconfigure $frame.x 1 -weight 0
	    grid rowconfigure    $frame.x 0 -weight 1

	    grid columnconfigure $frame.a 0 -weight 1
	    grid rowconfigure    $frame.a 0 -weight 1

	    tipstack::def [list \
		$frame.d {Source directory containing the package} \
		$frame.b {Browse for source directory} \
		$frame.r {Log actions taken during scanning} \
	    ]

	    set nsp_dir {}
	} else {
	    set frame [$win.nsp getframe]
	}

	$win.nsp configure -title \
	    "TclPE Scan For [expr {$ptype eq "tap" ? "TAP" : "TEApot"}] Packages"

	set pkgdir [$state pkgdir]

	if {$pkgdir ne ""} {
	    # Locked to a directory, force us there, and disallow changing.
	    set nsp_dir $pkgdir
	    $frame.b configure -state disabled
	    $frame.d configure -state disabled
	} else {
	    # A directory might have been chosen, but not yet locked
	    # in, due to trouble when scanning it. The user is allowed
	    # to change it.

	    $frame.b configure -state enabled
	    $frame.d configure -state enabled
	}

	$frame.r clear
	$win.nsp display
	return
    }

    method NSPTrack {args} {
	set frame [$win.nsp getframe]

	$frame.d state invalid
	$frame.r disable

	set msg Empty
	set pi [file join $nsp_dir pkgIndex.tcl]
	if {
	    ($nsp_dir eq "") ||
	    ![fileutil::test $nsp_dir edrx msg] ||
	    ![fileutil::test $pi      efr  msg {Package Index File}]
	} {
	    tipstack::pop  $frame.d
	    tipstack::push $frame.d "Source directory containing the package\n$msg"
	    return
	}

	tipstack::pop  $frame.d
	$frame.d state !invalid
	$frame.r enable 1
	return
    }

    method NSPDir {frame} {
	# Possible only if the project has not been locked to a location yet.

	set nsp_dir [tk_chooseDirectory \
			-title    "Select package directory" \
			-parent    $win \
			-mustexist true \
			-initialdir $nsp_dir \
		       ]
	return
    }

    method NSPClose {d result} {
	return
    }

    method NSPRun {frame ok} {
	$frame.r clear
	$frame.r disable

	$ok configure -state disabled

	if {[$state NewScanPackage $nsp_dir \
		 [list $frame.r log]]} {

	    # Ok, the project is now locked to that directory, if it
	    # was not already so.

	    if {[$state pkgdir] eq ""} {
		$state setInputFile [file join $nsp_dir teapot.txt]
	    }

	    ::tcldevkit::appframe::markdirty

	    $frame.r log info   { }
	    $frame.r log notice {Ok}
	} else {
	    $frame.r log info    { }
	    $frame.r log warning {Aborted due to problems}
	}

	$frame.r log info " "
	$frame.r enable 0

	$ok configure -state normal
	return
    }

    method DelPackage {} {
	$state DeleteSelection
	$self UpdateTypeDisplay
	::tcldevkit::appframe::markdirty
	return
    }

    variable ed_dir     {}

    method ExpandToDir {} {
	# Possible only for ptype 'teapot'.
	# (inputtypes: tm-*, zip).

	if {![winfo exists $win.ed]} {

	    widget::dialog $win.ed -modal local -transient 1 \
		-parent $win -place center \
		-title {TclPE Expand TEApot Archive} \
		-command [mymethod EDClose]
	    set ok [$win.ed add button -text [msgcat::mc "OK"] \
			-default active \
			-command [list $win.ed close ok]]
	    set frame [$win.ed getframe]

	    ttk::labelframe $frame.x -text Destination
	    ttk::labelframe $frame.a -text Log

	    ttk::entry  $frame.d -textvariable [myvar ed_dir]
	    ttk::button $frame.b -image [image::get file] \
		-command [mymethod EDDir $frame]
	    runwindow $frame.r -command [mymethod EDRun $frame $ok] \
		-labelhelp {Expand archive}

	    grid $frame.x -column 0 -row 0 -sticky swen -padx 1m -pady 1m
	    grid $frame.a -column 0 -row 2 -sticky swen -padx 1m -pady 1m
	    grid $frame.d -column 0 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.x
	    grid $frame.b -column 1 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.x
	    grid $frame.r -column 0 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.a

	    grid columnconfigure $frame 0 -weight 1
	    grid rowconfigure    $frame 0 -weight 0
	    grid rowconfigure    $frame 1 -weight 0
	    grid rowconfigure    $frame 2 -weight 1

	    grid columnconfigure $frame.x 0 -weight 1
	    grid columnconfigure $frame.x 1 -weight 0
	    grid rowconfigure    $frame.x 0 -weight 1

	    grid columnconfigure $frame.a 0 -weight 1
	    grid rowconfigure    $frame.a 0 -weight 1

	    tipstack::def [list \
		$frame.d {Destination directory for expanded archive} \
		$frame.b {Browse for destination directory} \
		$frame.r {Log actions taken during generation} \
	    ]

	    set ed_dir {}
	} else {
	    set frame [$win.ed getframe]
	}

	$frame.r clear
	$win.ed display
	return
    }

    method EDTrack {args} {
	set frame [$win.ed getframe]

	$frame.d state invalid
	$frame.r disable

	set msg Empty
	if {
	    ($ed_dir eq "") ||
	    ![fileutil::test $ed_dir edw msg]
	} {
	    tipstack::pop  $frame.d
	    tipstack::push $frame.d "Destination directory for expanded archive\n$msg"
	    return
	}

	tipstack::pop  $frame.d
	$frame.d state !invalid
	$frame.r enable 1
	return
    }

    method EDDir {frame} {
	set ed_dir [tk_chooseDirectory \
			-title    "Select destination directory" \
			-parent    $win \
			-mustexist false \
			-initialdir $ed_dir \
		       ]
	return
    }

    method EDClose {d result} {
	return
    }

    method EDRun {frame ok} {
	$ok configure -state disabled

	$frame.r disable
	$frame.r clear
	$frame.r 

	$state ExpandToDir $ed_dir [list $frame.r log]

	$frame.r log info   " "
	$frame.r enable 0 ;# keep log

	$ok configure -state normal
	return
    }

    variable ga_type    auto
    variable ga_compile 0
    variable ga_stamp   0
    variable ga_dir     {}

    typevariable ga_atype -array {
	auto {Automatically chosen}
	tm   {Tcl Module}
	zip  {Zip archive}
    }

    method GenArchives {} {
	# Possible only for ptype 'teapot'.

	if {![winfo exists $win.ga]} {
	    set ga_type    auto
	    set ga_compile 0
	    set ga_stamp   0

	    widget::dialog $win.ga -modal local -transient 1 \
		-parent $win -place center \
		-title {TclPE Generate TEApot Archives} \
		-command [mymethod GAClose]
	    set ok [$win.ga add button -text [msgcat::mc "OK"] \
			-default active \
			-command [list $win.ga close ok]]
	    set frame [$win.ga getframe]

	    ttk::labelframe $frame.x -text Destination
	    ttk::labelframe $frame.o -text Options
	    ttk::labelframe $frame.a -text Log

	    ttk::label  $frame.l -text {Archive format}
	    ttk::entry  $frame.d -textvariable [myvar ga_dir]
	    ttk::button $frame.b -image [image::get file] \
		-command [mymethod GADir $frame]
	    ttk::combobox $frame.t -values {tm zip auto} \
		-state readonly	-textvariable [myvar ga_type]
	    ttk::checkbutton $frame.c -text {Compile to bytecode}   -variable [myvar ga_compile]
	    ttk::checkbutton $frame.s -text {Timestamp the version} -variable [myvar ga_stamp]
	    runwindow $frame.r -command [mymethod GARun $frame $ok] \
		-labelhelp {Generate archives}

	    grid $frame.x -column 0 -row 0 -sticky swen -padx 1m -pady 1m
	    grid $frame.o -column 0 -row 1 -sticky swen -padx 1m -pady 1m
	    grid $frame.a -column 0 -row 2 -sticky swen -padx 1m -pady 1m
	    grid $frame.d -column 0 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.x
	    grid $frame.b -column 1 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.x
	    grid $frame.l -column 0 -row 0 -sticky swn  -padx 1m -pady 1m -in $frame.o
	    grid $frame.t -column 1 -row 0 -sticky swn  -padx 1m -pady 1m -in $frame.o
	    grid $frame.c -column 1 -row 1 -sticky wn   -padx 1m -pady 1m -in $frame.o
	    grid $frame.s -column 1 -row 2 -sticky wn   -padx 1m -pady 1m -in $frame.o
	    grid $frame.r -column 0 -row 0 -sticky swen -padx 1m -pady 1m -in $frame.a

	    grid columnconfigure $frame 0 -weight 1
	    grid rowconfigure    $frame 0 -weight 0
	    grid rowconfigure    $frame 1 -weight 0
	    grid rowconfigure    $frame 2 -weight 1

	    grid columnconfigure $frame.x 0 -weight 1
	    grid columnconfigure $frame.x 1 -weight 0
	    grid rowconfigure    $frame.x 0 -weight 1

	    grid columnconfigure $frame.o 0 -weight 0
	    grid columnconfigure $frame.o 1 -weight 1
	    grid rowconfigure    $frame.o 0 -weight 0
	    grid rowconfigure    $frame.o 1 -weight 0
	    grid rowconfigure    $frame.o 2 -weight 0

	    grid columnconfigure $frame.a 0 -weight 1
	    grid rowconfigure    $frame.a 0 -weight 1

	    tipstack::def [list \
		$frame.d {Destination directory for generated archives} \
		$frame.b {Browse for destination directory} \
		$frame.t {Choose format of generated archives} \
		$frame.c {Compile Tcl files to bytecodes during generation} \
		$frame.s {Add a timestamp to the package version} \
		$frame.r {Log actions taken during generation} \
	    ]

	    set ga_dir {}
	} else {
	    set frame [$win.ga getframe]
	}

	$frame.r clear
	$win.ga display
	return
    }

    method GATrack {args} {
	set frame [$win.ga getframe]

	$frame.d state invalid
	$frame.r disable

	set msg Empty
	if {
	    ($ga_dir eq "") ||
	    ![fileutil::test $ga_dir edw msg]
	} {
	    tipstack::pop  $frame.d
	    tipstack::push $frame.d "Destination directory for generated archives\n$msg"
	    return
	}

	tipstack::pop  $frame.d
	$frame.d state !invalid
	$frame.r enable 1
	return
    }

    method GADir {frame} {
	set ga_dir [tk_chooseDirectory \
			-title    "Select destination directory" \
			-parent    $win \
			-mustexist false \
			-initialdir $ga_dir \
		       ]
	return
    }

    method GAClose {d result} {
	return
    }

    method GARun {frame ok} {
	$ok configure -state disabled

	$frame.r disable
	$frame.r clear
	$frame.r log notice "Destination:           $ga_dir"
	$frame.r log notice "Compile to bytecodes:  [expr {$ga_compile ? "Yes" : "No"}]"
	$frame.r log notice "Timestamp the version: [expr {$ga_stamp ?   "Yes" : "No"}]"
	$frame.r log notice "Archive type:          $ga_atype($ga_type)"
	$frame.r log info " "

	set over     {}
	set haserror 0
	$state GenArchives $ga_type $ga_dir $ga_compile $ga_stamp \
	    [mymethod GALog [list $frame.r log]]

	$frame.r log info   " "
	if {$haserror} {
	    $frame.r log error "Encountered $haserror error[expr {$haserror > 1 ? "s" : ""}]"
	} else {
	    $frame.r log notice "Ok"
	}
	$frame.r log info   " "
	$frame.r enable 0 ;# keep log

	$ok configure -state normal
	return
    }

    variable haserror 0
    variable over {}

    method GALog {cmd l t} {
	# Special interception ... Generator does not announce errors
	# properly in the level. When fe find the announcement in the
	# text we fix the level for the next message, and suppress the
	# marker message.

	if {$over ne ""} {
	    set l $over
	    set over {}
	}
	if {[string match *Error* $t]} {
	    set over error
	    set l    error
	    incr haserror
	    return
	}

	eval [linsert $cmd end $l $t]
	return
    }

    method configuration {args} {
	# TAP entry. Compat to appframe.
	# Return configuration in a serialized, saveable format.
	# Or apply an incoming configuration after checking it.

	### Note ###
	##
	#   The configuration _is_ the .tap file format.
	#   See "doc/TclApp_FileFormats.txt"
	#   We simply retrieve it from and load it into the general state.

	switch -exact -- [llength $args] {
	    0 {
		# Syntax: ''
		# Hazard: Multi-line forms ?
		return [tape::state getState]
	    }
	    1 {
		# 'tools' or 'keys'

		set opt [lindex $args 0]
		if {[string equal tools $opt]} {
		    return {{TclDevKit TclApp PackageDefinition}}
		}
		if {[string equal keys $opt]} {
		    return {
			See  Desc   Package
			Base Alias  Platform
			Path Hidden ExcludePath
		    }
		}
		return -code error \
		    "Unknown subcommand \"$opt\", expected \"tools\", or \"keys\""
	    }
	    2 {
		# Syntax
		# '= cfg', 'fname file'

		set opt [lindex $args 0]
		switch -exact -- $opt {
		    fname {
			tape::state setInputFile [lindex $args 1] 
		    }
		    = {
			set data [lindex $args 1]

			tape::state check    $data
			tape::state clear

			# Switch display to tap mode, then set the state.
			$self ProjectType tap

			tape::state setState $data
		    }
		    default {
			return -code error "Unknown subcommand \"$opt\", expected \"=\", or \"fname\""
		    }
		}
	    }
	    default {
		return -code error "wrong#args: .w configuration ?= data?"
	    }
	}
    }

    method potConfigSet {plist} {
	# TEAPOT entry
	# The configuration is a list of teapot MD container objects.

	tape::teapot check    $plist
	tape::teapot clear

	# Switch display to teapot mode, then set the state
	$self ProjectType teapot

	tape::teapot setState $plist
	$self UpdateTypeDisplay
	return
    }

    method reset {} {
	# Reset the configuration to a clear state (i.e. empty).

	tape::state  resetInput
	tape::teapot resetInput

	$self potConfigSet    {}
	$self configuration = {} ; # {TclDevKit TclApp PackageDefinition}

	# Back to project default
	$self ProjectType teapot
	return
    }

    method inputChanged {} {
	set s [$state addOk]
	$win.tb itemconfigure new  -state $s
	$win.tb itemconfigure scan -state $s

	$self UpdateDelBtn [$win.sw.l curselection]
	$self UpdateTypeDisplay
	return
    }

    method {do select} {selection} {
	$self TrackOff
	$win.sw.l selection clear 0 end
	if {[llength $selection]} {
	    $win.sw.l selection set $selection
	}
	$self TrackOn
	$self UpdateDelBtn $selection
	$pd do select      $selection
	return
    }

    method {do error@} {index key msg} {
	# We have to update the highlight in the list if the error is
	# about the name.

	if {[string equal $key name]} {
	    if {$msg == {}} {
		set newbg [$win.sw.l cget -background]
		set newfg $selfg
	    } else {
		set newbg $options(-errorbackground)
		set newfg $newbg
	    }
	    $win.sw.l itemconfigure $index   \
			-background       $newbg \
			-selectforeground $newfg
	}

	$pd do error@ $index $key $msg
	return
    }

    method {do enable-files}    {bool} {$pd do enable-files $bool}
    method {do no-current}      {}     {$pd do no-current}
    method {do refresh-current} {}     {$pd do refresh-current}

    # TAP specific
    method {do no-alias} {} {
	if {$ptype ne "tap"} return
	$pd do no-alias
    }
    method {do show-alias-ref} {id} {
	if {$ptype ne "tap"} return
	$pd do show-alias-ref $id
    }
}

# -----------------------------------------------------------------------------

package provide tcldevkit::tape 2.1
