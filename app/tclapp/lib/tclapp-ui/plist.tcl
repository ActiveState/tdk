# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# plist.tcl --
# -*- tcl -*-
#
#	List of packages shown
#
# Copyright (c) 2007-2008 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Docs

# ### ### ### ######### ######### #########
## Requisites

package require snit         ; # Tcllib, OO core.
package require page
package require widget::menuentry

# ### ### ### ######### ######### #########
## Implementation

snit::widgetadaptor ::pkgman::plist {
    delegate method * to hull
    delegate option * to hull

    # ### ### ### ######### ######### #########
    ## API. Definition

    option -with-arch -default 0 ;# Show architecture data? Default no.
    option -arch    -default {}
    option -hint    -default {}
    option -command -default {}
    delegate option -type to hull
    delegate option -selectmode to sw

    # ### ### ### ######### ######### #########
    ## API. Implementation

    variable sw
    variable me
    variable filter
    variable timer

    constructor {args} {
	installhull using widget::dialog \
	    -type okcancel -modal local -transient 1 -separator 1 \
	    -command [mymethod closing]

	set wa [from args -with-arch] ; # Need now, for page creation.

	set frame [$hull getframe]
	set sw    [page $frame.sw -labelv Version -with-arch $wa]

	# No menu for the filter right now, hardwired to filter by name.

	set me [widget::menuentry $frame.me \
		    -textvariable [myvar filter]]

	if {!$wa} {
	    set ar [ttk::label $frame.ar -anchor w]
	    grid $ar -column 0 -row 0 -sticky swen -padx 1m -pady 1m
	}

	grid $me -column 0 -row 1 -sticky swen -padx 1m -pady 1m
	grid $sw -column 0 -row 2 -sticky swen -padx 1m -pady 1m
	grid columnconfigure $frame 0 -weight 1
	grid rowconfigure    $frame 0 -weight 0
	grid rowconfigure    $frame 1 -weight 0
	grid rowconfigure    $frame 2 -weight 1

	# Handle initial options.
	$self configurelist $args

	if {!$wa} {
	    set alabel "Only packages for architecture"
	    if {[llength $options(-arch)] < 2} {
		# Only one architecture. Likely 'tcl'.
		append alabel " '$options(-arch)'"
	    } else {
		append alabel "s '[linsert [join $options(-arch) "', '"] end-1 or]'"
	    }
	    append alabel " are shown."

	    if {$options(-hint) ne {}} {
		append alabel "\n$options(-hint)"
	    }

	    $frame.ar configure -text $alabel
	}

	trace variable [myvar filter] w [mymethod FilterChanged]
	return
    }

    destructor {
	trace vdelete [myvar filter] w [mymethod FilterChanged]
	return
    }

    # ### ### ### ######### ######### #########

    method FilterChanged {args} {
	catch {after cancel $timer}
	set timer [after 1000 [mymethod RunFilter]]
	return
    }

    method RunFilter {args} {
	# Need a way to determine which field is active.
	$sw filter $filter -fields name
	return
    }

    # ### ### ### ######### ######### #########

    method enter {xlist} {
	#                 xlist = list (list (name version isprofile istap UKEY) note)
	# with-arch 1 ==> xlist = list (list (name version arch isprofile istap UKEY) note)

	$sw Clear
	foreach p $xlist {
	    $sw NewItem $p
	}
	return
    }

    method entermore {xlist} {
	#                 xlist = list (list (name version isprofile istap UKEY) note)
	# with-arch 1 ==> xlist = list (list (name version arch isprofile istap UKEY) note)

	foreach p $xlist {
	    $sw NewItem $p
	}
	return
    }

    # ### ### ### ######### ######### #########

    method closing {w result} {
	if {
	    ($result eq "cancel") ||
	    ![llength $options(-command)]
	} return

	# Ok, and callback is present => Process selection

	uplevel \#0 [linsert $options(-command) end [[$hull getframe].sw Selection]]
	return
    }

    # ### ### ### ######### ######### #########
    # ### ### ### ######### ######### #########
    # ### ### ### ######### ######### #########
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide pkgman::plist 1.0
