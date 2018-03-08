# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# repo.tcl --
# -*- tcl -*-
#
#	UI to modify the TDK TclApp Project Settings - Repositories
#
# Copyright (c) 2007 ActiveState Software Inc.
#
# RCS: @(#) $Id: tdkwrap.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit              ; # Tcllib, OO core.
package require widget::dialog
package require pkgman::archives

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor tclapp::prjrepo {
    option -command {}

    delegate method * to hull
    delegate option * to hull

    variable _paths    {}
    variable _oldpaths {}
    variable arc {}

    constructor {args} {
	installhull using widget::dialog -title "TclDevKit TclApp Project Repositories" \
	    -type okcancel -modal none -synchronous 0 -padding 4 \
	    -command [mymethod callback]

	set f [$hull getframe]

	# Create Widgets
	set arc [pkgman::archives $f.arc]

	# Present Widgets
	grid $arc -column 0 -row 0 -sticky swen
	grid columnconfigure $f 0 -weight 1
	grid rowconfigure    $f 0 -weight 1

	$self configurelist $args
	return
    }

    method display {paths args} {
	set _paths    $paths
	set _oldpaths $paths
	$arc configure -data $self
	uplevel 1 [list $hull display] $args
    }

    method callback {w result} {
	# Run callback with modified list of paths. No callback if
	# there are no changes to report (See _oldpaths). Also nothing
	# done if the dialog was canceled. This is tested first.

	if {$result ne "ok"} return
	if {$_paths eq $_oldpaths} return

	uplevel \#0 [linsert $options(-command) end $_paths]
	return
    }

    ##
    # - List of archives of any type.
    # - Called by the pkgman::archives snidget to transfer information.

    method {archives externals get} {} {
	return $_paths
    }

    method {archives externals =} {archives} {
	set _paths $archives
	return
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide tclapp::prjrepo 1.0
