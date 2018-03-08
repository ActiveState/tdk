# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Listener
#
# Listener is a network server which listens for connection attempts and
# dispatches the connected socket to one of a pool of handler objects of
# -type type
#
# This implementation dispatches to a pool of objects which
# interact at the protocol level, to provide a network service.

if {[info exists argv0] && ($argv0 eq [info script])} {
    # test Listener
    lappend auto_path [pwd]
}

package provide Listener 1.0

package require logger
package require snit
package require Httpd
package require Pool

snit::type Listener {
    variable listen	;# socket upon which to accept connections

    option -server "Wub 1.0"	;# server name
    option -host ""	;# host name
    option -port 8015	;# port for listener to listen on
    option -myaddr 0	;# ip address to listen on
    option -type Httpd  ;# URI scheme - also controls socket handler type
    option -dispatcher ""

    # pool of sockets for this listener
    # note: this provides the release method
    # to return sockets to the pool
    component sockets -inherit true

    # base logger
    option -logger ::
    variable log

    option -retryafter 5	;# retry period for socket exhaustion

    method log {cmd args} {
        eval [linsert $args 0 ${log}::$cmd]
    }

    method Count {args} {}
    method CountStart {args} {}
    method CountHist {args} {}
    method CountName {args} {}

    # accept --
    #
    #	This is the socket accept callback invoked by Tcl when
    #	clients connect to the server.
    #
    # Arguments:
    #	self	A list of {protocol name port} that identifies the server
    #	sock	The new socket connection
    #	ipaddr	The client's IP address
    #	port	The client's port
    #
    # Results:
    #	none
    #
    # Side Effects:
    #	Set up a handler, HttpdRead, to read the request from the client.
    #	The per-connection state is kept in Httpd$sock, (e.g., Httpdsock6),
    #	and upvar is used to create a local "data" alias for this global array.

    method accept {sock ipaddr rport} {
	${log}::debug "$self accepted: $sock $ipaddr $rport"

	if {[catch {
	    $self Count accepts sockets

	    # select a Http block to handle incoming
	    if {[catch {$sockets get} http]} {
		${log}::error "accept failed $http"
		# we have exceeded per-listener pool size
		set date [clock format \
			      [clock seconds] \
			      -format {%a, %d %b %Y %T GMT} \
			      -gmt true]
		puts $sock "HTTP/1.1 503 Socket Exhaustion
Date: $date
Server: Wub 1.0
Connection: Close
Retry-After: $options(-retryafter)
"
		flush $sock
		close $sock
	    } else {
		# tell the Http object it's now connected
		$http configure -listener $self \
		    -ipaddr $ipaddr \
		    -rport $rport

		$http Connected $sock
		${log}::debug "$self accept complete: $http"
	    }
	} result]} {
	    ${log}::error "$self accept: $result"
	}
    }

    constructor {args} {
	if {[catch {
	    $self configurelist $args
	    set log [logger::init $options(-host)$options(-port)]
	    ${log}::disable debug

	    install sockets using Pool %AUTO%P \
		-type $options(-type) \
		-args [list -logger $log \
			   -dispatcher $options(-dispatcher)]
	    # ensure we have a host name
	    if {$options(-host) eq ""} {
		set options(-host) [info hostname]
	    }

	    set cmd [list socket -server [mymethod accept]]

	    if {$options(-myaddr) != 0} {
		lappend cmd -myaddr $options(myaddr)
	    }

	    lappend cmd $options(-port)

	    #puts stderr "server: $cmd"
	    if {[catch $cmd listen]} {
		error "$options(-host):$options(-port) $listen\ncmd=$cmd"
	    }
	} error]} {
	    #puts stderr "$self constructor err: $error"
	    ${::log}::error "$self constructor err: $error"
	}
    }

    destructor {
	$self log notice "Destroying $self"
	close $listen
	if {[catch {$sockets destroy} result]} {
	    $self log notice "Error destroying socket pool: $result"
	}

	${log}::delete
    }
}

if {[info exists argv0] && ($argv0 eq [info script])} {
    proc Dispatch {req} {
	#puts stderr "Dispatcher: $req"
	set http [dict get $req -http]
	set c {
	    <html>
	    <head>
	    <title>Test Page</title>
	    </head>
	    <body>
	    <h1>Test Content</h1>
	}

	append c "<table border='1' width='80%'>" \n
	append c <tr> <th> metadata </th> </tr> \n
	dict for {n v} $req {
	    if {[string match -* $n]} {
		append c <tr> <td> $n </td> <td> $v </td> </tr> \n
	    }
	}
	append c </table> \n

	append c "<table border='1' width='80%'>" \n
	append c <tr> <th> "HTTP field" </th> </tr> \n
	dict for {n v} $req {
	    if {![string match -* $n]} {
		append c <tr> <td> $n </td> <td> $v </td> </tr> \n
	    }
	}
	append c </table> \n
	append c {
	    </body>
	    </html>
	}

	$http Respond 200 [dict replace $req -content $c Content-Type text/html]
	$http Pipeline
    }

    # test Listener
    set listener [Listener %AUTO% -port 8080 -dispatcher Dispatch]
    #puts stderr "Listener $listener"

    proc Stdin {{prompt "% "}} {
	global Stdin

	if {[eof stdin]} {
	    fileevent stdin readable {}
	    return
	}

	append Stdin(command) [gets stdin]
	if {[info complete $Stdin(command)]} {
	    catch {uplevel \#0  $Stdin(command)} result
	    puts -nonewline "$result\n$prompt"
	    flush stdout
	    set Stdin(command) ""
	} else {
	    append Stdin(command) \n
	}
    }
    fileevent stdin readable Stdin

    set forever 0
    vwait forever
}
