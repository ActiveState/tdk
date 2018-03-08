# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xlloc - mklist /snit::widgetadaptor
#          Preconfigured location list.

package require mklist
package require snit

snit::widgetadaptor ::xlloc {

    delegate method * to hull
    delegate option * to hull

    variable view

    constructor {view_ args} {
	# We take ownership of an independent copy of the incoming view.

	if {$view_ == {}} {
	    set view $view_
	} else {
	    [$view_ readonly] as view
	}

	installhull [mklist $win $view \
		{file_str line hasobj   begin size} \
		{File     Line Objects? Begin Size} \
		-key loc]
	$win configurelist $args
	$hull adjust 0 left
	return
    }
}

package provide xlloc 0.1
