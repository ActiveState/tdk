# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgman_s.tcl --
# -*- tcl -*-
#
#	Set search restrictions (architecture)
#
# Copyright (c) 2006-2007 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Docs

# Need callback for reporting ok yes/no information, plus error
# messages.

# ### ### ### ######### ######### #########
## Requisites

package require snit      ; # Tcllib, OO core.
package require listentry ; # Configurable list display and manipulation
package require tipstack  ; # Tooltips
package require pref::devkit ; # TDK preferences

# ### ### ### ######### ######### #########
## Implementation

snit::widget ::pkgman::architectures {
    hulltype ttk::frame

    # ### ### ### ######### ######### #########
    ## API. Definition

    option -data {} ; # Object holding the shown state.

    # ### ### ### ######### ######### #########
    ## API. Implementation

    constructor {args} {
	# DEBUG # $hull configure -relief raised -bd 2 -bg coral

	$self MakeWidgets
	$self PresentWidgets

	# Handle initial options.
	$self configurelist $args

	trace add variable [myvar _arch] write [mymethod Transfer]
	return
    }

    destructor {
	trace remove variable [myvar _arch] write [mymethod Transfer]
	return
    }

    method MakeWidgets {} {
	# Widgets to show

	ttk::labelframe $win.arch -text "Allowed architectures"

	listentryb $win.l -labels Architecture -labelp Architectures \
	    -listvariable [myvar _arch] \
	    -values [mymethod Config] \
	    -browse 0 -ordered 0

	return
    }

    method PresentWidgets {} {
	# Layout ... Frames ...

	grid $win.arch -column 0 -row 0 -padx 1m -pady 1m -sticky swen

	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1

	# Layout ... Lower frame

	grid $win.l -column 0 -row 0 -padx 1m -pady 1m -sticky swen -in $win.arch

	grid columnconfigure $win.arch 0 -weight 1
	grid rowconfigure    $win.arch 0 -weight 1

	# This is also presentation.

	tipstack::def [list \
	   $win      "Manage allowed architectures for package search" \
	   $win.arch "Manage allowed architectures for package search" \
	   $win.l    "Manage allowed architectures for package search" \
	  ]

	return
    }

    # ### ### ### ######### ######### #########

    method set {list} {
	set _arch $list
	return
    }

    method get {} {
	return $_arch
    }

    # ### ### ### ######### ######### #########

    method Transfer {args} {
	# Ignore trace if there nothing to transfer the change to.
	if {$options(-data) == {}} return
	if {[catch {
	    $options(-data) architectures = $_arch
	} msg]} {
	    puts TRANSFER\ FAILURE\n$::errorInfo
	}
	return
    }

    # ### ### ### ######### ######### #########

    method Config {cmd args} {
	switch -exact -- $cmd {
	    set {
		#pref::devkit::ArchitecturesMRUList [lindex $args 0]
		return
	    }
	    get {
		return [pref::devkit::ArchitecturesMRUList]
	    }
	}
	return -code error "Bad request \"$cmd\""
    }

    # ### ### ### ######### ######### #########

    onconfigure -data {newvalue} {
	if {$newvalue eq $options(-data)} return
	set options(-data) $newvalue

	if {$newvalue eq ""} return

	set _arch [$newvalue architectures get]
	return
    }

    # ### ### ### ######### ######### #########

    variable _arch {}

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide pkgman::architectures 1.0
