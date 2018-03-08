# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# mkfilter - "frame" /snit::widgetadaptor
#		Creates a frame containing entries to specify filtering
#		for the 'mktable' it is connected to. Changes to the filter
#		are propagated via callback. Titling for the filters comes
#		from the 'mktable'.

# ### ######### ###########################
# Prequisites

package require Tk
package require snit

snit::widgetadaptor ::mkfilter {

    delegate method * to hull
    delegate option * to hull

    variable table
    variable titles
    variable properties

    constructor {table_ args} {
	installhull [frame $win]

	set table      $table_
	set titles     [$table cget -titles]
	set properties [$table cget -columns]

	$self MakeUI
	$self configurelist $args
	return
    }

    # ### ######### ###########################
    # mkfilter - NEW API

    method set {patterns} {
	foreach p $properties pt $patterns {
	    set text($p) $pt
	}
	return
    }

    method get {} {
	return [array get text]
    }

    # ### ######### ###########################
    # Internals ...

    # We begin with a filter restricted to plain glob ...

    variable text
    method MakeUI {} {
	set r 0
	foreach t $titles p $properties {
	    label $win.l$r -text $t
	    entry $win.e$r -text [varname text($p)]
	    set text($p) *

	    grid  $win.l$r -row $r -column 0 -sticky w
	    grid  $win.e$r -row $r -column 1 -sticky we
	    grid rowconfigure $win $r -weight 0
	    incr r
	}

	grid rowconfigure    $win $r -weight 1
	grid columnconfigure $win 0  -weight 0
	grid columnconfigure $win 1  -weight 1
	return
    }
}

# ### ######### ###########################
# Ready to go

package provide mkfilter 0.1
