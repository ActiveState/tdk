# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xlloccmdef - mklist /snit::widgetadaptor
#          Preconfigured location list for cmd definitions.

package require mklist
package require snit

snit::widgetadaptor ::xlloccmddef {

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
		{file_str line type prot escope_str origin_str} \
		{File     Line Type Prot Scope      Origin?} \
		-key loc]
	$win configurelist $args
	$hull adjust 0 left
	return
    }
}

package provide xlloccmddef 0.1
