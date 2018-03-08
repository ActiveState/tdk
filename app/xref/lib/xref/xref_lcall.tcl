# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xlcall - mklist /snit::widgetadaptor
#          Preconfigured command list.

package require mklist
package require snit

snit::widgetadaptor ::xlcall {

    delegate method * to hull
    delegate option * to hull

    variable view

    constructor {view_ args} {
	# We take ownership of this view.

	if {$view_ == {}} {
	    set view $view_
	} else {
	    [$view_ readonly] as view
	}

	installhull [mklist $win $view \
		{name} \
		{Procedure}]

	$win configurelist $args
	$hull adjust 0 left
	return
    }
}

package provide xlcall 0.1
