# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package selfile 0.1
# Meta platform    tcl
# Meta require     snit
# Meta require     Tk
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
#
# selfile - A wrapper around 'tk_getOpenFile'.
#           Takes all the arguments for that command
#           at the time of its creation. Manages -initialdir
#           on its own, remembering the last directory
#           we dialog was in.

package require Tk
package require snit

snit::type selfile {

    variable lastdir       {}
    variable cmd           {}

    constructor {args} {
	set cmd     [from args -command tk_getOpenFile]
	set lastdir [from args -lastdir]
	set cmd     [linsert $args 0 $cmd]
	return
    }

    # ### ######### ###########################

    method choose {} {
	set result [eval [linsert $cmd end -initialdir $lastdir]]
	if {$result == {}} {return {}}
	set lastdir [file dirname $result]
	return $result
    }

    # ### ######### ###########################
}

return
