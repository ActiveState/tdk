# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# mkfilterd - "Dialog" /snit::widgetadaptor
#	Filter dialog based upon 'mkfilter'

#		Creates a frame containing entries to specify filtering
#		for the 'mktable' it is connected to. Changes to the filter
#		are propagated via callback. Titling for the filters comes
#		from the 'mktable'.

# ### ######### ###########################
# Prequisites

package require BWidget
package require snit
package require mkfilter

snit::widgetadaptor ::mkfilterd {

    delegate method * to hull
    delegate option * to hull

    option -onapply {}
    option -ondone  {}

    variable filter

    constructor {table_ args} {
	installhull [Dialog $win -modal none -transient 0]

	set   filter [mkfilter [$hull getframe].filter $table_]
	pack $filter -side top -fill both -expand 1

	$hull add -text Ok     -command [mymethod Ok]
	$hull add -text Apply  -command [mymethod Apply]
	$hull add -text Cancel -command [mymethod Cancel]
	$hull configure -default 0 -cancel 2

	#puts ([join $args ") ("])
	$self configurelist $args

	$hull draw
	return
    }

    # ### ######### ###########################
    # mkfilterd - NEW API

    # ### ######### ###########################
    # Internals ...

    method Ok {args} {
	$self ApplyOut [$filter get]
	$self Done
	destroy $win
	return
    }
    method Cancel {args} {
	$self Done
	destroy $win
	return
    }
    method Apply {args} {
	$self ApplyOut [$filter get]
	return
    }

    method ApplyOut {patterns} {
	if {$options(-onapply) == {}} {return}
	eval [linsert $options(-onapply) end $patterns]
	return
    }

    method Done {} {
	if {$options(-ondone) == {}} {return}
	eval $options(-ondone)
	return
    }
}

# ### ######### ###########################
# Ready to go

package provide mkfilterd 0.1
