# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Snit wrapper around ::struct::pool for containing Snit objects
# adds dynamic object construction

package provide Pool 1.0
package require snit
package require struct::pool

snit::type Pool {
    component pool -inherit true
    option -maxsize -default 256 \
	-cgetmethod getmax -configuremethod setmax

    method getmax {option} {
	return [$pool maxsize]
    }
    method setmax {option value} {
	#puts "<<<$option $value>>> $self"
	$pool maxsize $value
    }

    # contained type and constructor args
    option -type ""
    option -args ""

    method get {} {
	while {![info exists item]} {
	    if {![$pool request item]} {
		if {[$pool maxsize] > [$pool info cursize]} {
		    # create a new object on demand and put it into pool
		    set s [eval [linsert $options(-args) 0 $options(-type) %AUTO%]]
		    $pool add $s
		} else {
		    # we have exceeded per-listener pool size
		    error "Exhaustion [$pool maxsize] [$pool info cursize]"
		}
	    }
	}
	return $item
    }

    destructor {
	# first try to destroy each object
	foreach {item id} [$pool info allocstate] {
	    if {$id != -1} {
		$pool release $item
		$pool remove $item
	    }
	    catch {$item destroy}
	}

	if {[catch {$pool destroy}]} {
	    $pool destroy -force
	}
    }

    constructor {args} {
	#puts stderr "Pool $self: $args"
	if {[catch {
	    install pool using ::struct::pool %AUTO%P 256
	    #puts <<$self/[$self cget -maxsize]>>
	    #puts "<<cons: $args>>"
	    $self configurelist $args
	} result]} {
	    puts stderr "Pool constructor error $self: $result"
	} else {
	    #puts stderr "Pool $self: [array get options]"
	}
    }
}
