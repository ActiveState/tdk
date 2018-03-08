# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package mafter 0.1
# Meta platform    tcl
# Meta require     snit
# @@ Meta End

# -*- tcl -*-

package require snit

snit::type ::mafter {

    constructor {delay cmd} {
	set _delay  $delay
	set _cmd    $cmd
	return
    }

    method arm {} {
	#puts "$self ARM"
	catch {after cancel $_timer}
	set _timer [after $_delay $_cmd]
	return
    }

    variable _timer
    variable _delay
    variable _cmd
}

return
