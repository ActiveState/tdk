# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Entity - handler for document body entities

package provide Entity 1.0

package require snit

snit::type Entity {
    option -bufsize 16384 ;# buffer size
    option -maxentity -1 ;# maximum entity size

    variable req	;# request being processed
    variable entity	;# collected raw entity
    variable sock	;# connected socket
    variable length	;# entity length

    method readEntity {} {
	set left [expr {$length - [string bytelength $entity]}] 
	if {[catch {read $sock $left} block]} {
	    return "Error reading Entity - $block"
	} else {
	    append entity $block
	}

	if {[string bytelength $entity] == $length} {
	    fileevent $sock readable {}	;# disable reading here
	    dict set request -query $entity
	    
	    # completed entity

	    runcomp [dict get $req -completion] $req
	}
    }

    proc runcomp {comp req} {
	set     cmd $comp
	lappend cmd $req
	uplevel 1 $cmd
    }

    proc listcomp {comp req} {
	set     cmd $comp
	lappend cmd $req
	return $cmd
    }

    # continue with request by receiving Entity
    method continue {} {
	# rfc2616 4.3
	# The presence of a message-body in a request is signaled by the
	# inclusion of a Content-Length or Transfer-Encoding header field in
	# the request's headers.
	if {![dict exists $req content-length]
	    && ![dict exists $req transfer-encoding]} {
	    return
	}

	# start the transmission of POST entity, if necessary/possible
	if {[dict get $req -version] >= 1.1 && [dict exists $req expect]} {
	    if {[dict get $req expect] == "100-continue"} {
		# the client wants us to tell it to continue
		# before reading the body
		puts $sock "HTTP/1.1 100 Continue\n"
	    }
	}
    }

    method Read {request completion} {
	set req $request
	set sock [dict get $req -sock]
	dict set req -completion $completion

	$self continue	;# tell client to start the transfer

	# start the copy of POST data
	if {[dict exists $req content-length]} {
	    set length [dict get $req content-length]
	    if {($options(-maxentity) > 0) && ($length > $options(-maxentity))} {
		return -code 413 -request $req
	    }
	    fconfigure $sock -blocking 0 \
		-buffersize $options(-bufsize) \
		-translation {binary crlf}
	    
	    fileevent $sock readable [mymethod readEntity]
	} else {
	    return -code 411 -request $req
	}
    }

    # Discard - 
    # called when a request with possible entity data can't be satisfied.
    # when completely drained, call read to restart the protocol.
    #	drain any pending POST data, or avoid it if possible.
    #	called when a request with possible entity data can't be satisfied.
    #
    # Arguments:
    # Results:
    #
    # Side Effects:
    #	when completely drained, call read to restart the protocol.

    method Discard {request completion} {
	set req $request
	set sock [dict get $req -sock]
	dict set req -completion $completion

	if {[dict get $req -version] >= 1.1
	    && [dict exists $req expect] 
	    && ([dict get $req expect] eq "100-continue")} {
	    # we're in luck - the client wants a prompt before it sends entity
	    # we just don't give it one, and it won't send an entity
	    runcomp $completion $request
	} elseif {[dict exists $http content-length]} {
	    # rfc2616 4.3
	    # The presence of a message-body in a request is signaled by the
	    # inclusion of a Content-Length or Transfer-Encoding header field in
	    # the request's message-http.

	    # have to discard content explicitly
	    $self continue	;# tell client to start the transfer

	    if {![info exists ::devnull]} {
		# we'll keep around a /dev/null fd for this
		set ::devnull [open /dev/null w]
	    }

	    # drain the socket of pending data, then restart protocol
	    fcopy $options(-sock) $::devnull \
		-size [dict get $request content-length] \
		-command [listcomp $completion $request]

	} elseif {[dict exists $http transfer-encoding]} {
	    # somehow handle a transfer encoded entity
	    return -code 501 -request $req "Don't know how to drain a transfer encoded entity"
	} else {
	    # there is no entity to discard - we win.
	    runcomp $completion $request
	}
    }
}
