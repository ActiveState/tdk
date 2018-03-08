# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xlfile - mklist /snit::widgetadaptor
#          Preconfigured file list.

package require mklist
package require snit

snit::widgetadaptor ::xlfile {

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
		{where_str} \
		{Files}]
	$win configurelist $args
	$hull adjust 0 left
	return
    }
}

package provide xlfile 0.1
