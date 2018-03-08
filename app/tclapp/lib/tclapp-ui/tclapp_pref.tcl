# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_pref.tcl --
# -*- tcl -*-
#
#	UI to modify the TDK preferences.
#	Currently only the pkgRepositoryList.
#
# Copyright (c) 2005-2007 ActiveState Software Inc.
#
# RCS: @(#) $Id: tdkwrap.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit              ; # Tcllib, OO core.
package require pref::devkit      ; # TDK preferences.
package require widget::dialog
package require pkgman::archives
package require pkgman::tap

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor tclapp::pref {
    delegate method * to hull
    delegate option * to hull

    variable _apaths    {}
    variable _aoldpaths {}
    variable arc {}

    variable _tpaths    {}
    variable _toldpaths {}
    variable tap {}

    constructor {args} {
	installhull using widget::dialog -title "TclDevKit TclApp Preferences" \
	    -type okcancel -modal none -synchronous 0 -padding 4 \
	    -command [mymethod callback]

	set f [$hull getframe]

	# Create Widgets
	set nb [ttk::notebook $f.nb -padding [pad notebook]]

	set arc [pkgman::archives $nb.arc]
	set tap [pkgman::tap      $nb.tap]

	$nb add $arc -sticky news -text {TEAPOT Repositories}
	$nb add $tap -sticky news -text {TAP Search Paths}

	# Present Widgets
	grid $nb -column 0 -row 0 -sticky swen

	grid columnconfigure $f 0 -weight 1
	grid rowconfigure    $f 0 -weight 1

	$self configurelist $args

	pref::devkit::onSaveError [mymethod Trouble]
	return
    }

    destructor {
	pref::devkit::onSaveError {}
	return
    }

    method Trouble {key m} {
	# Ignore trouble for all but the list of tap search paths.
	# This causes only one error dialog to show instead of many.
	if {$key ne "pkgSearchPathList"} return

	tk_messageBox -icon error -parent $self -type ok \
	    -title "Tcl Dev Kit TclApp Preferences Problem" \
	    -message "Our apologies, we encountered problems while trying to save the changed preferences. The operating systems reports:\n\n$m"
    }

    method display {args} {
	set _apaths    [pref::devkit::pkgRepositoryList]
	set _aoldpaths $_apaths
	$arc configure -data $self

	set _tpaths    [pref::devkit::pkgSearchPathList]
	set _toldpaths $_tpaths
	$tap configure -data $self

	uplevel 1 [list $hull display] $args
    }

    method callback {w result} {
	if {$result eq "ok"} {
	    $self Apply
	} else {
	    set _apaths $_aoldpaths
	    set _tpaths $_toldpaths
	}
    }

    method Apply {} {
	# Not only saving listbox to in-memory preference database,
	# but persisting the change to the external database as
	# well. At last we reinitialize our package database using the
	# new/changed paths.

	pref::devkit::pkgRepositoryList $_apaths
	pref::devkit::pkgSearchPathList $_tpaths

	if {$_apaths ne $_aoldpaths} {
	    # Notify the pkg mgmt that the paths to the standard
	    # repositories changed.  This may require a rescan.
	    tclapp::pkg::reinitialize
	}

	if {$_tpaths ne $_toldpaths} {
	    # Notify the old pkg mgmt (.tap file based) that the list
	    # of paths to search for .tap files was changed. We force
	    # a rescan the next time a list of packages is asked for.
	    tclapp::tappkg::uninitialize
	}

	return
    }

    proc edit {} {
	set w .preferences
	if {![winfo exists $w]} {
	    tclapp::pref $w
	}
	$w display
    }

    ##
    # - List of archives of any type.

    method {archives externals get} {} {
	return $_apaths
    }

    method {archives externals =} {xarchives} {
	set _apaths $xarchives
	return
    }

    method {tap externals get} {} {
	return $_tpaths
    }

    method {tap externals =} {xtap} {
	set _tpaths $xtap
	return
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide tclapp::pref 1.0
