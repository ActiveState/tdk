# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgman_t.tcl --
# -*- tcl -*-
#
#	Manipulate list of search paths for .tap files.
#
# Copyright (c) 2007 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Docs

# configuration set/get methods for connection to containing wrapper
# and communication of state (save/load project).

# Need callback for reporting ok yes/no information, plus error
# messages.

# Option for prefix file. Container responsible for changing it. We
# responsible for updating set of available tap.

# !TODO! Connect listentry to preferences for MRU list of archive
#        locations.

# !TODO! Connect the checkbuttons to the data object. Defaults on
#        create or option set, writing back any changes.

# ### ### ### ######### ######### #########
## Requisites

package require snit         ; # Tcllib, OO core.
package require listentryb   ; # Configurable list display and manipulation
package require tipstack     ; # Tooltips
package require pref::devkit ; # TDK preferences
package require fileutil     ; # File testing

package require repository::api      ; # Repo interface core

# Repository types for the type auto-detection.

package require repository::tap       ; # TAP compatibility repository
package require repository::sqlitedir ; # Standard opaque repository (server)
package require repository::localma   ; # Standard open repository (installation)
package require repository::prefix    ; # Prefix files
package require repository::proxy     ; # Http accessible repositories (network)

package require img::png
package require image ; image::file::here

# ### ### ### ######### ######### #########
## Implementation

snit::widget ::pkgman::tap {
    hulltype ttk::frame

    # ### ### ### ######### ######### #########
    ## API. Definition

    option -data {} ; # Object holding the shown state.

    # ### ### ### ######### ######### #########
    ## API. Implementation

    constructor {args} {
	# Create widgets
	listentryb $win.l \
	    -labels {TAP Search path} \
	    -labelp {TAP Search paths} \
	    -listvariable [myvar _tap] \
	    -values [mymethod Config] \
	    -valid  [mymethod ValidTAP] \
	    -ordered 1 \
	    -browseimage [image::get directory]
	# image::get - TODO - Find a better icon 'browse repo path/url'

	# Present widgets
	grid $win.l -column 0 -row 0 -padx 1m -pady 1m -sticky swen -in $win

	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1

	tipstack::def [list \
	   $win "Management of Tap for Packages" \
	  ]

	# Handle initial options.
	$self configurelist $args

	trace add variable [myvar _tap] write [mymethod TransferArc]
	return
    }

    destructor {
	trace remove variable [myvar _tap] write [mymethod TransferArc]
	return
    }

    # ### ### ### ######### ######### #########

    method TransferArc {args} {
	$options(-data) tap externals = $_tap
	return
    }

    # ### ### ### ######### ######### #########

    method Config {cmd args} {
	switch -exact -- $cmd {
	    set {
		pref::devkit::pkgSearchPathMRUList [lindex $args 0]
		return
	    }
	    get {
		return [pref::devkit::pkgSearchPathMRUList]
	    }
	}
	return -code error "Bad request \"$cmd\""
    }

    # ### ### ### ######### ######### #########

    method ValidTAP {text} {
	if {$text eq ""}          {return "Empty"}
 	if {![file exists $text]} {return "Undefined"}
	return {}
    }

    # ### ### ### ######### ######### #########

    onconfigure -data {newvalue} {
	# Can't cache this, as we request data that may have changed
	#if {$newvalue eq $options(-data)} return
	set options(-data) $newvalue

	if {$newvalue eq ""} return

	set _tap [$newvalue tap externals get]
	return
    }

    # ### ### ### ######### ######### #########

    variable _tap {}

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide pkgman::tap 1.0
