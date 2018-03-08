# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# Filesystem browser widget.
# A combination of vtree, vpage in a panedwindow.

# ### ######### ###########################
## Prerequisites

package require snit
package require hpane
package require vtree
package require vpage

# ### ######### ###########################
## Implementation

snit::widget fsb {
    hulltype ttk::frame
    component pane
    component dpane
    component dtree
    component details
    # ### ######### ###########################

    option -closecmd {}
    option -show     {}
    option -data     {}
    option -style    large

    # ### ######### ###########################

    constructor {args} {
	install pane using ttk::panedwindow $win.pw -orient horizontal

	install dpane using hpane $win.dpane -text "Folders"
	install dtree using vtree $dpane.t \
	    -show     [mymethod TreeActive] \
	    -onaction [mymethod TreeAction]
	install details using vpage $win.details -width 400 -height 300 \
	    -show     [mymethod DetailActive] \
	    -onaction [mymethod DetailAction]

	$dpane setwidget $dtree

	$pane add $dpane   -weight 0
	$pane add $details -weight 1

	grid $pane -row 0 -sticky news
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 1

	$self configurelist $args
	$self PropStyle
	return
    }

    # ### ######### ###########################
    ## Public. Folder (un)hiding

    method folderHide {} {
	# don't error if we've already forgotten $dpane
	catch {$pane forget $dpane}
	return
    }

    method folderUnhide {} {
	$pane forget $details
	$pane add $dpane   -weight 0
	$pane add $details -weight 1
	return
    }

    # ### ######### ###########################
    ## Public.

    delegate method show       to dtree
    delegate method showdetail to details as show
    delegate method sortby     to details

    method refresh {} {
	$dtree   refresh
	$details refresh
	return
    }

    # ### ######### ###########################
    ## Internal. Option handling

    onconfigure -closecmd {value} {
	if {$value eq $options(-closecmd)} return
	set options(-closecmd) $value
	$self SetCloseState
	return
    }

    onconfigure -data {value} {
	if {$value eq $options(-data)} return

	if {$options(-data) != {}} {
	    $dtree   configure -view {}
	    $details configure -view {}
	}

	set options(-data) $value

	if {$value != {}} {
	    $dtree   configure -view [$value tree]
	    $details configure -view [$value details]
	    $self PropStyle
	}
	return
    }

    onconfigure -style {value} {
	if {$value eq $options(-style)} return

	switch -exact -- $value {
	    large   {}
	    small   {}
	    list    {}
	    details {}
	    default {
		return -code error "Illegal style \"$value\"."
	    }
	}

	set options(-style) $value

	$self PropStyle
	return
    }

    # ### ######### ###########################
    ## Internal. Handling -closecmd

    method SetCloseState {} {
	if {$options(-closecmd) == {}} {
	    $dpane configure -closecmd {}
	} else {
	    $dpane configure -closecmd [mymethod Close]
	}
	return
    }

    method Close {dummy} {
	$self folderHide
	eval $options(-closecmd)
	return
    }

    method PropStyle {} {
	if {$options(-data) == {}} return
	set d $options(-data)
	set d [$d details]

	switch -exact -- $options(-style) {
	    large   {
		$details  configure -style icons
		$d        configure -iconprefix big
	    }
	    small   {
		$details configure -style smalllist
		$d       configure -iconprefix small
	    }
	    list    {
		$details configure -style list
		$d       configure -iconprefix small
	    }
	    details {
		$details configure -style details
		$d       configure -iconprefix small
	    }
	}
	return
    }

    # ### ######### ###########################
    ## Internal. Handle the selection/active events coming from the
    ## components.

    variable activepathid {}

    method TreeActive {pathid view rowid} {
	# We ignore the more internal view/rowid information,
	# and pass on only the path data combined with empty
	# detail selection information. It also determines
	# the data to show in the detail view.

	set activepathid $pathid
	set fspath [eval [linsert $pathid 0 file join]]
	[$details cget -view] configure -path $fspath

	if {$options(-show) == {}} return

	eval [linsert $options(-show) end [list $pathid {}]]
	return
    }

    method DetailActive {pathid view rowid} {
	# We ignore the more internal view/rowid information,
	# and pass on only the path data combined with the
	# active path in the tree.

	if {$options(-show) == {}} return

	eval [linsert $options(-show) end [list $activepathid [list $pathid]]]
	return
    }

    # ### ######### ###########################

    method TreeAction {pathid view rowid} {
	$dtree open $pathid
	return
    }

    method DetailAction {id view rowid} {
	set newpath $activepathid
	lappend newpath $id

	set fullpath [eval [linsert $newpath 0 file join]]
	if {[file isdirectory $fullpath]} {
	    $dtree show $newpath
	} else {
	    # Open this file according to the platform ...
	    # HACK / TODO / FUTURE - option, callback ...
	    action::openfile $fullpath
	}
	return
    }


    # ### ######### ###########################
}


# ### ######### ###########################
## Ready for use

package provide fsb 0.2
