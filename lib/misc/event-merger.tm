# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package event::merger 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     snit
# @@ Meta End

# -*- tcl -*-

# Wait for multiple callbacks, a fixed number determined on
# construction time, run a callback when all have arrived.
# Suicidal.

package require snit
package require logger

logger::initNamespace ::event::merger
snit::type ::event::merger {

    constructor {cmd n} {
	log::debug "$type new (($cmd) $n) = $self"

	set _cmd $cmd
	set _n   $n
	set _res {}
	return
    }

    method done {args} {
	log::debug "$self done ($args)"

	lappend _res $args
	$self trigger
    }
    method trigger {} {
	incr _n -1
	if {$_n > 0} return

	log::debug "$self finally done"

	# The last callback has come in. Trigger our callback now.

	set c $_cmd  ; # Keep the data for the callback before
	set r $_res  ; # the suicide destroys them in the namespace.
	$self destroy

	uplevel \#0 [linsert $c end $r]
	return
    }

    variable _cmd {}
    variable _n 0
    variable _res {}
}

return
