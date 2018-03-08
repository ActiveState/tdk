# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xldefined - mklist /snit::widgetadaptor
#          Preconfigured list of typed objects.

package require mklist
package require snit

snit::widgetadaptor ::xldefined {

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
		{Defined} \
		-key id]
	$win configurelist $args
	$hull adjust 0 left
	return
    }
}

package provide xldefined 0.1
