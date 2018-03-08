# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# potFileWidget.tcl --
#
#	This file implements a widget which handes the teapot meta data file
#       information as used by 'teapot-pkg gen' (included, excluded).
#
# Copyright (c) 2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: Exp $
#
# -----------------------------------------------------------------------------

package require snit
package require tipstack
package require listentryb
package require image ; image::file::here

# -----------------------------------------------------------------------------

snit::widget tcldevkit::teapot::fileWidget {
    hulltype ttk::frame

    option -connect -default {}

    constructor {args} {
	$self MakeWidgets
	$self PresentWidgets

	# Handle initial options.
	$self configurelist $args

	trace variable [myvar included] w [mymethod Export included]
	trace variable [myvar excluded] w [mymethod Export excluded]
	return
    }

    onconfigure -connect {new} {
	if {$options(-connect) eq $new} return
	set options(-connect) $new
	$self Export included
	$self Export excluded
	return
    }

    destructor {
	trace vdelete [myvar included] w [mymethod Export included]
	trace vdelete [myvar excluded] w [mymethod Export excluded]
    }

    variable included {}
    variable excluded {}

    method MakeWidgets {} {
	ttk::labelframe $win.i -text "Included Files"
	ttk::labelframe $win.e -text "Excluded Files"

	listentryb $win.i.l \
	    -ordered 0 \
	    -labels {include glob pattern} \
	    -labelp {include glob patterns} \
	    -listvariable [myvar included] \
	    -browseimage [image::get file] \
	    -browsecmd [mymethod Browse]

	listentryb $win.e.l \
	    -ordered 0 \
	    -labels {exclude glob pattern} \
	    -labelp {exclude glob patterns} \
	    -listvariable [myvar excluded] \
	    -browseimage [image::get file] \
	    -browsecmd [mymethod Browse]
	return
    }

    method PresentWidgets {} {
	foreach {slave col row stick padx pady span colspan} {
	    .i    0 0 swen 1m 1m 1 1
	    .e    1 0 swen 1m 1m 1 1
	    .i.l  0 0 swen 1m 1m 1 1
	    .e.l  0 0 swen 1m 1m 1 1
	} {
	    grid $win$slave -columnspan $colspan -column $col -row $row \
		-sticky $stick -padx $padx -pady $pady -rowspan $span
	}

	grid columnconfigure $win 0 -weight 1
	grid columnconfigure $win 1 -weight 1
	grid rowconfigure    $win 0 -weight 1
	#grid rowconfigure    $win 1 -weight 1

	grid columnconfigure $win.i 0 -weight 1
	grid rowconfigure    $win.i 0 -weight 1

	grid columnconfigure $win.e 0 -weight 1
	grid rowconfigure    $win.e 0 -weight 1

	tipstack::defsub $win {
	    .i   {Include Patterns}
	    .e   {Exclude Patterns}
	    .i.l {Include Patterns}
	    .e.l {Exclude Patterns}
	}
	return
    }

    method Browse {listwin args} {
	# Our file browser for the listentryb widgets.
	# We force browsing in the package directory (PD).
	# We jail the selection to the PD, in case the user went outside.
	# We record relative paths.

	set pkgdir [$self State pkgdir]

	if {$pkgdir == {}} {
	    # Not locked into a directory.
	    set cmd [linsert $args 0 tk_getOpenFile]
	} else {
	    # Start in the directory.
	    set cmd [linsert [linsert $args 0 \
				  tk_getOpenFile] end \
			 -initialdir $pkgdir]
	}

	set path [uplevel \#0 $cmd]
	if {$pkgdir == {}} {
	    set pkgdir [LocatePkgDirFrom $path]

	    # Compute the input file from the package dir found based
	    # on the chosen file.

	    $self State setInputFile [file join $pkgdir teapot.txt]
	}
	set path [fileutil::stripPath $pkgdir [fileutil::jail $pkgdir $path]]
	return $path
    }

    method Export {key args} {
	if {![llength [set $key]]} {
	    # Empty pattern lists are removed from the meta data.
	    $self State unset $key
	} else {
	    $self State change $key [set $key]
	}
	return
    }

    method State {args} {
	# Delegate action to state object connected to this widget.
	if {$options(-connect) eq ""} return
	return [uplevel \#0 [linsert $args 0 $options(-connect)]]
    }

    # These methods are called by the state to influence the GUI. This
    # is filtered by the main pot package display.

    method {do error@} {index key msg} {}
    method {do select} {selection}     {}

    method {do refresh-current} {} {
	# Get the newest file information and refresh the display
	set included [$self State get included]
	set excluded [$self State get excluded]
	return
    }

    method {do no-current} {} {
	# Clear display
	set included {}
	set excluded {}
	return
    }


    proc LocatePkgDirFrom {path} {
	set first [file dirname [file normalize $path]]
	set dir $first
	set last {}
	while 1 {
	    # Containing package found
	    if {[file exists [file join $dir pkgIndex.tcl]]} {return $dir}
	    # Nothing found, use directory the file is in as package directory.
	    if {$last eq $dir} {return $first}
	    # Step into parent for next round of checks.
	    set last $dir
	    set dir [file dirname $dir]
	}
    }
}

# ------------------------------------------------------------------------------
package provide tcldevkit::teapot::fileWidget 1.0
