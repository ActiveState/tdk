# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# mklist - "ScrolledWindow" /snit::widgetadaptor
#	    ScrolledWindow + LIST display + list controller
#	    for a list view of a mk view.


package require toolbar
package require snit
package require mkvtree

package require listctrl
package require mkfilterd

snit::widget ::mklist {
    hulltype ttk::frame

    delegate method adjust        to list
    delegate method add           to tbar
    delegate method itemconfigure to tbar
    delegate method itemcget      to tbar
    delegate method *             to hull

    delegate option -browsecmd    to control as -onbrowse
    delegate option -onbrowse     to control as -onbrowse
    delegate option -onaction     to control
    delegate option -basetype     to list
    delegate option -childdef     to list
    delegate option -key          to control

    component list
    component tbar
    component control

    option -filtertitle {}

    constructor {view visible titles args} {
	# Get titles/visible info from args, first ...	
	set sw [ScrolledWindow $win.sw]

	install tbar using toolbar $win.tbar

	$tbar add filter find Filter \
		-command [mymethod OpenFilter]

	$tbar itemconfigure filter -state normal

	install list using mkvtree $win.sw.list -titles $titles
	install control using ::listctrl ${selfns}::control \
	    -display $list \
	    -data $view -show $visible

	$sw setwidget $list

	grid $tbar -column 0 -row 0 -sticky nws
	grid $sw   -column 0 -row 1 -sticky swen

	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 0 -weight 0
	grid rowconfigure    $win 1 -weight 1

	$self configurelist $args
	return
    }

    destructor {
	catch {rename $control {}}
    }

    # ### ######### ###########################
    # mklist - NEW API (for mklistdesc)


    # ### ######### ###########################
    # Internals

    method OpenFilter {} {
	set title Filter
	if {$options(-filtertitle) != {}} {
	    append title " " $options(-filtertitle)
	}

	mkfilterd $win.filter $list \
		-title $title \
		-parent $win \
		-onapply [mymethod ApplyFilter] \
		-ondone  [mymethod CloseFilter]
	$tbar itemconfigure filter -state disable
	return
    }

    method CloseFilter {} {
	$tbar itemconfigure filter -state normal
	return
    }

    method ApplyFilter {patterns} {
	$control filter $patterns
	return
    }
}

package provide mklist 0.2
