# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xlns - mklist /snit::widgetadaptor
#          Preconfigured namespace list.

package require mklist
package require snit

snit::widgetadaptor ::xlns {

    delegate method * to hull
    delegate option * to hull

    variable view

    constructor {view_ args} {
	# We take ownership of this view.
	if {$view_ == {}} {
	    set view $view_
	} else {
	    $view_ as view
	}

	installhull [mklist $win $view \
		{name defn usen} \
		{Namespace #Definitions #Uses}]

	$win configurelist $args
	$hull adjust 0 left

	return
    }
}

package provide xlns 0.1
