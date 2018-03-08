# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xllocfl - mklist /snit::widgetadaptor
#          Preconfigured location list (file + line only).

package require mklist
package require snit

snit::widgetadaptor ::xllocfl {

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
		{file_str line} \
		{File     Line} \
		-key loc]
	$win configurelist $args
	$hull adjust 0 left
	return
    }
}

package provide xllocfl 0.1
