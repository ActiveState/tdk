# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# potPkgDisplay.tcl --
#
#	Implementation of the widget to display the information for a single
#	package in the pot under edit.
#
# Copyright (c) 2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# ------------------------------------------------------------------------------

package require snit
package require tcldevkit::teapot::fileWidget
package require tcldevkit::teapot::descWidget
package require tcldevkit::teapot::depsWidget
package require tcldevkit::teapot::indxWidget
package require tcldevkit::teapot::mdWidget
package require tipstack


snit::widget tcldevkit::teapot::pkgDisplay {
    hulltype ttk::frame

    option -connect -default {}

    constructor {args} {
	$self MakeWidgets
	$self PresentWidgets

	# Handle initial options.
	$self configurelist $args
	return
    }

    onconfigure -connect {new} {
	if {$options(-connect) eq $new} return
	set options(-connect) $new
	# Forward to subordinate displays
	$win.files configure -connect $new
	$win.reqs  configure -connect $new
	$win.recs  configure -connect $new
	$win.desc  configure -connect $new
	$win.indx  configure -connect $new
	$win.md    configure -connect $new
	return
    }

    destructor {}

    method MakeWidgets {} {
	ttk::notebook                 $win.nb
	tcldevkit::teapot::fileWidget $win.files
	tcldevkit::teapot::descWidget $win.desc
	tcldevkit::teapot::indxWidget $win.indx
	tcldevkit::teapot::depsWidget $win.reqs -key require   -label required
	tcldevkit::teapot::depsWidget $win.recs -key recommend -label recommended
	tcldevkit::teapot::mdWidget   $win.md

	# Generate a nice layout ...

	$win.nb add $win.desc  -text "Basic"
	$win.nb add $win.files -text "Files"
	$win.nb add $win.reqs  -text "Requirements"
	$win.nb add $win.recs  -text "Recommendations"
	$win.nb add $win.indx  -text "Indexing"
	$win.nb add $win.md    -text "Other"
	# XXX Add <<NotebookTabChanged>> to [focus $win$w]

	# TODO = More panels
	#      - autopath, entrysource, entryload, entrykeep,
	#      - entrytclcommand, initprefix, tcl_findlibrary/force - pkggen
	#
	# FUTURE: plugin driven, declaration driven (loadable)

	return
    }

    method PresentWidgets {} {
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1
	grid $win.nb -column 0 -row 0 -sticky swen

	$win.nb select $win.desc

	tipstack::defsub $win {
	    .desc  {Identify the package}
	    .files {List files contained in the package}
	    .reqs  {List the required package dependencies}
	    .recs  {List the recommended package dependencies}
	    .indx  {Indexing information for the packages}
	    .md    {Describe the package}
	}
	return
    }

    method {do enable-files} {on} {
	if {$on} {
	    $win.nb tab $win.files -state normal
	} else {
	    $win.nb select $win.desc
	    $win.nb tab    $win.files -state disabled
	}
	return
    }

    method {do error@} {index key msg} {
	$win.desc  do error@ $index $key $msg
	$win.files do error@ $index $key $msg
	$win.reqs  do error@ $index $key $msg
	$win.recs  do error@ $index $key $msg
	$win.indx  do error@ $index $key $msg
	$win.md    do error@ $index $key $msg
	return
    }

    method {do select} {selection} {
	$win.desc  do select $selection
	$win.files do select $selection
	$win.reqs  do select $selection
	$win.recs  do select $selection
	$win.indx  do select $selection
	$win.md    do select $selection
	return
    }

    method {do refresh-current} {} {
	$win.desc  do refresh-current
	$win.files do refresh-current
	$win.reqs  do refresh-current
	$win.recs  do refresh-current
	$win.indx  do refresh-current
	$win.md    do refresh-current
	return
    }

    method {do no-current} {} {
	$win.desc  do no-current
	$win.files do no-current
	$win.reqs  do no-current
	$win.recs  do no-current
	$win.indx  do no-current
	$win.md    do no-current
	return
    }
}

# ------------------------------------------------------------------------------

package provide tcldevkit::teapot::pkgDisplay 1.0
