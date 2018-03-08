# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################

# UI tools. Widget. Based on 'vtable', adds automatic scrolling around
# the table itself.

# ### ######### ###########################

# ### ######### ###########################
## Prerequisites

package require vtable  ; # The foundation for our display.
package require snit    ; # Object system
package require BWidget ; # Scrolled window

# ### ######### ###########################
## Implementation

snit::widgetadaptor svtable {
    # ### ######### ###########################
    # Most options are for configuring the table, so we we simplify
    # the setup by using *

    delegate method * to table
    delegate option * to table ;#except {-command -cache -usecommand -titlerows -titlecols}

    # The scrolledwindow specific options however need to be delegated
    # to the hull.

    delegate option -auto        to hull
    delegate option -scrollbar   to hull
    delegate option -background  to hull
    delegate option -bg          to hull
    delegate option -borderwidth to hull
    delegate option -bd          to hull
    delegate option -relief      to hull

    # ### ######### ###########################
    ## Public API. (De)Construction.

    constructor {args} {
	installhull using ScrolledWindow
	set              table [vtable $win.t -colstretchmode all]
	$hull setwidget $table
	$self configurelist $args
	return
    }

    # ### ######### ###########################
    ## Public API. 

    ## No new methods

    # ### ######### ###########################
    ## Internal. Data structures.

    variable table ; # Internal table widget.

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use

package provide svtable 0.1
