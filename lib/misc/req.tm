# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package req 1.0
# Meta platform    tcl
# Meta require     snit
# @@ Meta End

# -*- tcl -*-

package require snit

snit::type req {
    constructor {cmd} {
	set _cmd $cmd
	return
    }
    method rq {} {
	if {$_ticked} return
	after idle [mymethod Tick]
	set _ticked 1
	return
    }
    variable _cmd {}
    variable _ticked 0
    method Tick {} {
	set _ticked 0
	uplevel \#0 $_cmd
	return
    }
}

return
