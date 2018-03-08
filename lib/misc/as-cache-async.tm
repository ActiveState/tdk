# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package as::cache::async 0.1
# Meta platform    tcl
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
package require snit

snit::type ::as::cache::async {

    option -default -default {} -readonly 1
    option -now     -default 0

    constructor {cmd setcmd args} {
	set _cmd    $cmd
	set _setcmd $setcmd
	$self configurelist $args
	return
    }

    method get {key args} {

	# Return anything for which we have data in the cache.

	if {[info exists _data($key)]} {
	    return $_data($key)
	}

	if {$options(-now)} {
	    # Cache configured for sync request execution.

	    set command [linsert $_cmd end $self $key]
	    foreach a $args {lappend command $a}
	    uplevel \#0 $command

	    if {![info exists _data($key)]} {
		return $options(-default)
	    }

	    return $_data($key)
	}

	if {[info exists _pending($key)]} {
	    # We already have a request to compute the value sitting
	    # in the event queue. Which has not completed yet too. So
	    # there is no need to fire off more requests for the
	    # same. Just return the default and wait for the
	    # completion of this request.

	    return $options(-default)
	}

	set command [linsert $_cmd end $self $key]
	foreach a $args {lappend command $a}
	after idle $command
	set _pending($key) .

	return $options(-default)	
    }

    method set {key value} {
	set _data($key) $value

	catch {unset _pending($key)}

	uplevel \#0 [linsert $_setcmd end $self $key $value]
	return
    }

    method clear {{pattern *}} {
	array unset _data $pattern
	return
    }

    variable _cmd         {}
    variable _setcmd      {}
    variable _data -array {}

    variable _pending -array {}
}

return
