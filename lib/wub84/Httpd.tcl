# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Httpd - network service object to implement (near) HTTP1.1
#
# Designed to be invoked by a Listener object

package provide Httpd 1.0

package require Timer
package require HttpUtils
package require Entity

snit::type Httpd {

    # connection description and state
    option -close 0	;# set to close connection
    option -version 1.0	;# http version from header

    option -readentity 1	;# we will handle the entity
    component entity -public entity

    variable req	;# request dict
    variable pending 0 ;# count of pending requests

    # connection data provided by Listener
    option -listener	;# listener for this socket
    option -dispatcher	;# dispatcher for this socket
    option -counter ""	;# statistics
    option -logger	;# logger for this socket

    option -sock	;# socket for this connection
    option -ipaddr	;# client's ip address
    option -rport	;# client's (remote) port

    component timer -public timer	;# a Timer for protocol timeouts

    # timeouts
    option -timeout1 120000	;# inter-transaction timeout
    option -timeout2 120000	;# request processing timout

    # keepalive transaction parameters
    option -maxtrans 25	;# number of transactions per keepalive
    variable transaction 0	;# number of transactions left this keepalive
    variable response	0	;# last response sent

    variable replies -array {}	;# pending transaction list
    variable debug 10
    option -events 1		;# filter events through $self

    method log {cmd args} {
	eval [linsert $args 0 $options(-logger)::$cmd]
    }

    # event --
    #
    #	filter events through $self, for logging and error handling
    #
    # Arguments:
    #	handler	event handler, if any
    #
    # Results:
    #
    # Side Effects:
    #	logs event, evaluates handler logs any errors

    method event {handler} {
	$options(-logger)::debug "EVENT: $handler"
	#::Trace
	if {[set code [catch {eval $handler} result]]} {
	    #$options(-logger)::error "EVENT ERROR: $result"
	    #puts stderr  "EVENT ERROR: $::errorInfo"

	    # set the informational error message
	    if {$code eq 1} {
		set code 500
	    }
	    if {![info exists message] || ($message eq "")} {
		set message [::http::ErrorMsg $code]
	    }
	    
	    $options(-logger)::error "$self $code - '$result'"
	    
	    # create a response
	    $self Respond [list $code $result] [dict replace $req -content "
<html>
<head>
<title>Error: $code</title>
</head>
<body>
<h1>Error $code</h1>
<p>$message - $result</p>
</body>
</html>
" Content-Type text/html]
	} else {
	    $options(-logger)::debug "EVENT COMPLETE: $handler"
	}
    }

    # fileevent --
    #
    #	set fileevent handler with $self filtering
    #
    # Arguments:
    #	event	which fileevent to handle
    #	handler	event handler, if any
    #
    # Results:
    #
    # Side Effects:
    #	sets event handler with logging

    method fileevent {event handler} {
	if {$handler eq ""} {
	    $options(-logger)::debug "Filevent $options(-sock) $event OFF"
	    fileevent $options(-sock) $event {}
	} else {
	    $options(-logger)::debug "Filevent $options(-sock) $event ($handler)"
	    if {$options(-events)} {
		fileevent $options(-sock) $event [mymethod event $handler]
	    } else {
		fileevent $options(-sock) $event $handler
	    }
	}
    }

    # Disconnect --
    #
    #	Central close procedure.  All close operations should funnel
    #	through here so the right cleanup occurs.
    #
    # Arguments:
    #	message	If non-empty, then something went wrong on the socket.
    #
    # Results:
    #
    # Side Effects:
    #	Cleans up any after events associated with the connection.
    #	Detaches any attached domains
    #	Closes the socket.
    #	Makes the callback to the URL domain implementation.

    method Disconnect {{message ""}} {

	$options(-logger)::debug "Disconnect $message"

	# cancel any pending timeouts
	$self timer cancel

	if {$options(-counter) ne ""} {
	    $options(-counter) Count sockets -1
	}

	# close the socket
	if {[catch {close $options(-sock)} err]} {
	    $options(-logger)::info "CloseError $err on $options(-sock)"
	}

	# log any errors
	if {$message != ""} {
	    $options(-logger)::info "$message ($req)"
	}

	# clean up state
	array set replies {}
	set req [dict create -http $self -scheme http]
	set options(-close) 0

	# finally, put $self back in the Listener's sockets pool
	catch {$options(-listener) release $self}
    }
    
    # Dispatch request
    # it's up to handler to deal with the connection
    # until Pipeline is called. This allows handler to read
    # its own PUT entity if it wishes.
    # handler may already have called Pipeline before returning here.

    method dispatch {r} {
	set req $r
	set code 500
	if {[catch {
	    set code [eval [linsert $options(-dispatcher) end $req]]
	} result]} {
	    #puts DISPATCH:\n\t\ $::errorInfo

	    $self Pipeline
	    return -code $code -errorinfo $::errorInfo -errorcode $::errorCode $result
	}
    }

    # header --
    #
    #	asynchronous stream parser for HTTP/1.? http headers
    #
    # Arguments:
    # Results:
    #
    # Side Effects:
    #	Consumes input from socket
    #	Builds http from HTTP parameters
    #	Calls dispatch when complete

    method header {} {
	if {[eof $options(-sock)]} {
	    # client has dropped - clean up
	    $self Disconnect "eof in header"
	} elseif {[catch {gets $options(-sock) line} count]} {
	    # we have an error reading the socket - clean up
	    $self Disconnect "read error: $count"
	} elseif {$count != 0} {
	    # got some data in mime state
	    if {[regexp {^([^ :]+):[ \t]*(.*)} $line -> key value]} {
		# this is a new header line
		set key [string tolower $key]
		if {[dict exists $req $key]} {
		    if {$key eq "host"} {
			# the request has already supplied host
			# we may not override it
		    } else {
			dict append req $key ",$value"
		    }
		} else {
		    dict set req $key $value
		}
	    } elseif {[regexp {^[ \t]+(.*)}  $line -> value]} {
		# header continuation line
		if {[info exists key]} {
		    dict append req $key " $value"
		} else {
		    return -code 400 "bad header continuation line $line"
		}
	    } else {
		return -code 400 "badly formed header $line"
	    }
	} else {
	    # got empty line in mime state - end of header state

	    # Disable the fileevent as we have completely read the header
	    # this leaves the file able to be read/written by some handler
	    # the fileevent is re-enabled for protocol by Pipeline command
	    $options(-logger)::debug "Completed header"
	    $self fileevent readable {}
	    $self timer cancel	;# cancel header timeout

	    # ensure that the client sent a Host: if protocol requires it
	    if {[dict exists $req -host]} {
		if {[dict exists $req -host] && ([dict get $req -host] ne "")} {
		    # rfc 5.2.1 - a host header field must be ignored
		    dict set req -host [$options(-listener) cget -host]
		    dict set req -port [$options(-listener) cget -port]
		} else {
		    # use the Host field to determine the host
		    foreach c [split [dict get $req host] :] f {host port} {
			dict set req $f $c
		    }
		}
	    } elseif {[dict get $req version] > 1.0} {
		return -code 400 "HTTP 1.1 is required to send Host request"
	    } else {
		# HTTP 1.0 isn't required to send a Host request
		if {![dict exists $req -host]} {
		    # make sure the req has some idea of our host&port
		    dict set req -host [$options(-listener) cget -host]
		    dict set req -port [$options(-listener) cget -port]
		}
	    }

	    # completed req header decode - now dispatch on the URL
	    incr pending

	    if {$options(-counter) ne ""} {
		# count the hits we get
		$options(-counter) CountHist urlhits
		$options(-counter) CountName [dict get $req -url] hit
	    }

	    # set up some useful header data for domain handler
	    dict set req -url [::http::genURL $req]
	    dict set req -uri [::http::genURI $req]

	    # read Entity if requested
	    if {([dict get $req -method] eq "POST") && $options(-readentity)} {
		$self entity Read $req [mymethod dispatch]
	    } else {

		# Dispatch request
		# it's up to handler to deal with the connection
		# until Pipeline is called.
		$self dispatch $req
	    }
	}
    }

    # request --
    #
    #	reads the HTTP initial line
    #
    # Arguments:
    # Results:
    #
    # Side Effects:
    #	Consumes input from socket
    #	Builds req with HTTP parameters
    #	sets socket readable to header when complete

    method request {} {
	if {[eof $options(-sock)]} {
	    # client has dropped - clean up
	    $self Disconnect "eof in request"
	} elseif {[catch {gets $options(-sock) line} count]} {
	    $self Disconnect "read error: $count"
	} elseif {$count > 0} {
	    if {$line eq ""} {
		# rfc2616 4.1: In the interest of robustness,
		# servers SHOULD ignore any empty line(s)
		# received where a Request-Line is expected.
		return
	    }

	    # Count up transactions per keepalive
	    incr transaction
	    $options(-logger)::debug "TRANS INCR: $transaction"
	    dict set req -transaction $transaction

	    # got some data in start state
	    $options(-logger)::debug "LINE: $line"
	    #puts stderr "LINE: $line"
	    foreach {head(-method) head(-uri) head(-version)} [split $line] break

	    if {[string match HTTP/* $head(-version)]} {
		set head(-version) [lindex [split $head(-version) /] 1]
		set options(-version) $head(-version) ;# http version

		$options(-logger)::debug "$head(-method) $head(-uri) HTTP/$head(-version)"

		# TODO - check URI length
		# rfc2616 3.2.1
		# A server SHOULD return 414 (Request-URI Too Long) status
		# if a URI is longer than the server can handle (see section 10.4.15).

		# record header data in req dict
		#puts stderr "PREPARSE: $req - [array get head]"
		set req [dict merge $req [array get head] [::http::urlparse $head(-uri)]]

		foreach {n} {listener sock ipaddr rport} {
		    dict set req -$n $options(-$n)
		}
		foreach {n} {host port} {
		    dict set req -$n [$options(-listener) cget -$n]
		}

		# Limit the time allowed to serve this request
		$self timer after $options(-timeout2) \
		    [mymethod Disconnect "Timeout: processing request"]x
		
		# configure the socket for reading HTTP http
		$self fileevent readable [mymethod header]
	    } else {
		# Could check for FTP requests, here...
		return -code 400 "Error $line"
	    }
	}
    }

    # CloseP --
    #	See if we should close the socket
    #
    # Arguments:
    #
    # Results:
    #	1 if the connection should be closed now, 0 if keep-alive
    #
    # Side Effects:
    #	sets option -close

    method CloseP {} {
	set reason "no close"

	if {$options(-close)} {
	    set reason "Already decided to close"
	} elseif {[dict exists $req connection]} {
	    # what does the client think about the connection type?
	    if {[string tolower [dict get $req connection]] == "keep-alive"} {
		# an old HTTP/1.0 client wants keep-alive
		set reason "keep alive"
		if {$options(-counter) ne ""} {
		    $options(-counter) Count keepalive
		}
		set options(-close) 0	;# we'll honour keep-alive
	    } else {
		# default for connection or HTTP/1.0 is to close
		set reason "close request"
		if {$options(-counter) ne ""} {
		    $options(-counter) Count connclose
		}
		set options(-close) 1
	    }
	} elseif {[dict exists $req proxy-connection]} {
	    # what does the proxy think about the connection type?
	    if {[string tolower [dict get $req proxy-connection]] == "keep-alive"} {
		# an old HTTP/1.0 proxy wants keep-alive
		set reason "proxy keep alive"
		if {$options(-counter) ne ""} {
		    $options(-counter) Count keepalive
		}
		set options(-close) 0	;# we'll honour keep-alive
	    } else {
		# default for connection or HTTP/1.0 is to close
		set reason "proxy close request"
		if {$options(-counter) ne ""} {
		    $options(-counter) Count connclose
		}
		set options(-close) 1
	    }
	} elseif {$options(-version) >= 1.1} {
	    # the default for HTTP/1.1 is keep-alive
	    set reason "http1.1 - default keep alive"
	    if {$options(-counter) ne ""} {
		$options(-counter) Count http1.1
	    }
	    set options(-close) 0
	} else {
	    # default for HTTP/1.0 is to close
	    set reason "http1.0 - default close"
	    if {$options(-counter) ne ""} {
		$options(-counter) Count http1.0
	    }
	    set options(-close) 1
	}

	# in any case, we only have a finite allowance
	# of transactions per request connection.
	if {[expr {$transaction > $options(-maxtrans)}]} {
	    # Exceeded transactions per connection
	    set reason "transactions exceeded"
	    if {$options(-counter) ne ""} {
		$options(-counter) Count noneleft
	    }
	    set options(-close) 1
	}

	# debug log the reason for closing - this will go
	$options(-logger)::debug "$reason"

	return $options(-close)
    }

    # Close --
    #	Close a transaction, although the socket might actually
    #	remain open for a keep-alive connection.
    #
    #	Calling Close means the HTTP transaction is fully complete.
    #
    # Arguments:
    #	message	Logging message.  If this is "Close", which is the default,
    #		then an entry is made to the standard log.  Otherwise
    #		an entry is made to the debug log.
    #
    # Side Effects:
    #	Cleans up all state associated with the connection, including
    #	after events for timeouts, the data array, and fileevents.

    method Close {{message ""}} {

	$self timer cancel	;# cancel any timer

	if {$message != ""} {
	    $options(-logger)::info "$message"
	}

	if {[$self CloseP]} {
	    # we have no more transactions anyway
	    # just close it without fussing with unread data
	    $options(-logger)::debug "Closing - $message"
	    $self Disconnect
	} else {
	    # We intend to keep alive and there may be unread POST data.
	    # To ensure that the client can read our reply properly,
	    # we must read and discard this data before proceeding
	    $self entity Discard
	}
    }

    # Pipeline --
    #
    #	We have control of the socket and can process more requests
    #	(re)Initialize or reset the socket state.
    #	We allow multiple transactions per socket (keep alive).
    #
    # Arguments:
    # Results:
    #
    # Side Effects:
    #	Resets state (which has the effect of incrementing transaction number)
    #	Cancels any pending timeouts.
    #	Closes the socket upon error or if the reuse counter goes to 0.
    #	Sets up the fileevent for the protocol engine (method read)

    method Pipeline {} {
	$options(-logger)::debug Pipeline 

	# Set up a timeout to close the socket if the next request
	# is not received soon enough.
	$self timer after $options(-timeout1) \
	    [mymethod Disconnect "Timeout: Request"]

	# try to flush the socket
	if {[catch {flush $options(-sock)} err]} {
	    $self Disconnect $err
	    $options(-logger)::error "Pipeline flushing $err"
	    return
	}

	# this is a clean (re)start
	# start the stream protocol parser
	translation $options(-sock) -rmode crlf -blocking 1 -buffering line

	# start the read process
	$self fileevent readable [mymethod request]
    }

    # Connected --
    #
    #	Initial connection from Listener
    #
    # Arguments:
    #
    # Results:
    #
    # Side Effects:
    #	Resets state
    #	Cancels any pending timeouts or fileevents
    #	Detaches any attached domains

    method Connected {sock} {
	$options(-logger)::debug "$self Connected: $sock - [fconfigure $sock]"

	set options(-sock) $sock

	# count connections
	if {$options(-counter) ne ""} {
	    $options(-counter) Count connections
	}

	# reset any fileevents (should be none anyway)
	$self fileevent writable {}
	$self fileevent readable {}
	translation $options(-sock) -wmode crlf -rmode crlf -encoding binary

	# clean up connection state
	catch {unset replies}
	array set replies {}
	set req [dict create -http $self -scheme http] ;# initial header
	set options(-close) 0	;# we don't know about keep-alive

	# Count down transactions per keepalive
	$options(-logger)::debug "TRANS: reset to 0"
	set transaction 0
	set response 0

	$self Pipeline
    }

    # doneTx --
    #	completed transmission of a file
    #
    # Arguments:
    #
    #	fd	file descriptor being sent
    #	epilog	epilog to file
    #
    # Side Effects:
    #
    #	re-enable responder
    #	close file

    method doneTx {fd epilog args} {
	if {[llength $args] > 1} {
	    $options(-logger)::error [lindex $args 1]
	}
	flush $options(-sock)	;# make sure it's gone
	$options(-logger)::debug "doneTx: $args"

	if {$epilog ne ""} {
	    # we have string epilog to deliver
	    
	    # Note: we must *not* send a newline, as this
	    # screws up the Content-Length, and confuses the client
	    # which doesn't then pick up the next response in the pipeline
	    puts -nonewline $options(-sock) $epilog ;# send the prolog
	    flush $options(-sock)	;# make sure it's gone out
	}
	catch {close $fd}
	translation $options(-sock) -wmode crlf
	$self fileevent writable [mymethod responder]
    }

    # responder --
    #	deliver in-sequence transaction responses
    #
    # Arguments:
    #
    # Side Effects:
    #	Send transaction responses to client
    #	Possibly close socket

    method responder {} {
	$options(-logger)::debug "RESPONDER: [array get replies]"

	if {![array size replies]} {
	    # we've no more responses queued
	    $options(-logger)::debug "No replies"

	    # turn off responder
	    $self fileevent writable {}

	    if {[$self CloseP]} {
		# we've been asked to close
		$self Close
	    }

	    return
	}

	# determine next available response
	set next [lsort -integer [array names replies]]

	# ensure we don't send responses out of sequence
	if {$next != ($response + 1)} {
	    # something's blocking the response pipeline
	    # we have to wait until the preceding transactions
	    # have something to send

	    $options(-logger)::debug "$next doesn't follow $response in [array names replies]"
	    $self fileevent writable {}
	    return
	}

	# we're going to respond to the next transaction
	if {[catch {

	    $options(-logger)::debug "SEND TRANS: $next / $response"
	    set response $next	;# count the responses

	    # fetch the reply dict for this response from replies queue
	    foreach {code errmsg dict} $replies($next) break
	    foreach n [dict keys $dict {[A-Za-z]*}] {
		set fields($n) [dict get $dict $n]
	    }
	    unset replies($next)
	    incr pending -1	;# one fewer request pending

	    # find out about content prolog and epilog, if any
	    # calculate true transmission size
	    foreach n {prolog epilog fd_close auth} {
		if {[dict exists $dict -$n]} {
		    set $n [dict get $dict -$n]
		} else {
		    set $n ""
		}
	    }

	    # strip content from reply array
	    if {[dict exists $dict -content]} {
		set content "$prolog[dict get $dict -content]$epilog"
		set fields(Content-Length) [string length $content]
	    } elseif {[dict exists $dict -fd]} {
		# the content to deliver is a file rewound to start
		# here's its fd
		set fd [dict get $dict -fd]

		set base [tell $fd]
		seek $fd 0 end
		set fields(Content-Length) \
		    [expr {
			   [tell $fd] - $base
			   + [string length $prolog]
			   + [string length $epilog]}]
		seek $fd $base start
	    } else {
		# clear out sender's values
		catch {array unset fields content-*}
		catch {unset fields(transfer-encoding)}
	    }

	    # add in Auth header elements
	    foreach {n v} $auth {
		append header "WWW-Authenticate: $n $v" \n
	    }

	    # format up the header
	    set header "HTTP/$options(-version) $code $errmsg\n"
	    if {$code != 100} {
		append header "Date: [::http::Date [clock seconds]]" \n
		append header "Server: [$options(-listener) cget -server]" \n
		foreach {n v} [array get fields] {
		    append header "$n: $v" \n
		}
		if {($pending == 0) && [$self CloseP]} {
		    append header "Connection: Close" \n
		}
	    }

	    # send the header
	    translation $options(-sock) -wmode crlf;# HTTP header mode
	    puts $options(-sock) "${header}"	;# send headers with terminating nl
	    flush $options(-sock)		;# make sure they're gone
	    translation $options(-sock) -wmode binary; ;# content is binary

	    $options(-logger)::debug "HEADER: $req"

	    # send the content/file (if any)
	    if {[info exists fd]} {
		if {$prolog ne ""} {
		    $options(-logger)::debug "Sending prolog"

		    # we have string prolog to deliver
		    # note: we must *not* send a newline, as this
		    # screws up the Content-Length, and confuses the client
		    # which doesn't then pick up the next response
		    # in the pipeline
		    puts -nonewline $options(-sock) $prolog ;# send the prolog
		    flush $options(-sock)	;# make sure it's gone
		}

		$options(-logger)::debug "Sending file $fd"

		# content is a file - set up to send it
		fconfigure $fd -translation binary
		$self fileevent writable {}	;# responder off while sending

		# this will copy the content then restart responder
		fcopy $fd $options(-sock) \
		    -size $fields(Content-Length) \
		    -command [mymethod doneTx $fd $epilog]
	    } elseif {[info exists content]} {
		$options(-logger)::debug "Sending content"

		# we have string content to deliver

		# note: we must *not* send a newline, as this
		# screws up the Content-Length, and confuses the client
		# which doesn't then pick up the next response
		# in the pipeline
		puts -nonewline $options(-sock) "$content" ;# send the content
		flush $options(-sock)	;# make sure it's gone
		translation $options(-sock) -wmode crlf
		
		$options(-logger)::debug "Sent: $options(-sock) / $transaction"
	    }
	} result]} {
	    # there's been an error sending the response
	    translation $options(-sock) -wmode crlf
	    $self fileevent writable {}	;# responder off
	    $self Disconnect "$self responder ERR: $result"
	}
    }

    # Respond --
    #	queue up a transaction response
    #
    # Arguments:
    #	code	list of response code and (optional) error message
    #
    # Side Effects:
    #	queues the response for sending by method responder

    method Respond {code {reply {}}} {
	$options(-logger)::debug

	# fetch transaction from the caller's identity
	set trx [dict get $reply -transaction]

	if {[catch {
	    foreach {code errmsg} $code break
	    
	    $options(-logger)::debug $trx / $code - '$errmsg'
	    
	    # ensure no data is sent when it's illegal to do so
	    if {[dict exists $reply -content] || [dict exists $reply -fd]} {
		if {[dict exists $reply -method]
		    && ([dict get $reply -method] eq "HEAD")} {
		    # All responses to the HEAD request method MUST NOT
		    # include a message-body.
		    if {[dict exists $reply -fd]} {
			close [lindex [dict get $reply -fd] 0]
			dict unset reply -fd
		    }
		} else {
		    # 1xx (informational), 204 (no content), and 304 (not modified)
		    # responses MUST NOT include a message-body
		    switch -glob -- $code {
			204 - 304 - 1* {
			    if {[dict exists $reply -content]} {
				dict unset reply -content
			    }
			    if {[dict exists $reply -fd]} {
				close [lindex [dict get $reply -fd] 0]
				dict unset reply -fd
			    }
			}
		    }
		}
	    }
	    
	    # handle keepalive
	    if {[$self CloseP]} {
		# no more transactions - tell them we're closing (courtesy :)
		dict set reply connection Close
	    } elseif {$options(-version) == 1.0} {
		#dict set reply connection Keep-Alive
	    }

	    # set the informational error message
	    if {![info exists errmsg] || ($errmsg eq "")} {
		set errmsg [::http::ErrorMsg $code]
	    }

	    # strip http fields which don't have relevance in response
	    foreach {n v} $reply {
		set nl [string tolower $n]
		if {
		    [info exists ::http::headers($nl)] &&
		    ($::http::headers($nl) eq "rq")
		} {
		    dict unset reply $n
		}
	    }

	    # record transaction and kick off the responder
	    set replies($trx) [list $code $errmsg $reply]
	    $options(-logger)::debug "ADD TRANS: $trx / $response ([array get replies])"
	    $self fileevent writable [mymethod responder]
	} result]} {
	    $options(-logger)::error "Respond ERR: $result"
	}

	# now the response has been collected
	# the thread will release itself
    }

    constructor {args} {
	#puts "Constructing $self"
	if {[catch {
	    install timer using Timer %AUTO%	;# create our Timer
	    install entity using Entity %AUTO%	;# entity handler
	    $self configurelist $args		;# configure self

	    $options(-logger)::debug "Constructed $self"

	} result]} {
	    $options(-logger)::error "$self Err: $result"
	}
    }

    destructor {
	$options(-logger)::info "Destroying $self"
	catch {$self Disconnect}
	catch {$timer destroy}
	catch {$entity destroy}

	# remove us from the listener request pool
	if {[catch {
	    $options(-listener) remove $self
	} result]} {
	    $options(-logger)::error "pool removal of $self: $result"

	    if {[catch {
		$options(-listener) remove $self -force
	    } result]} {
		    $options(-logger)::error "forced pool removal of $self: $result"
	    }
	}
    }
}

snit::type httpsConn {
    constructor {args} {
	$self configurelist $args	;# configure self
	
	# There is still a lengthy handshake that must occur.
	# We do that by calling tls::handshake in a fileevent
	# until it is complete, or an error occurs.
	
	if {$options(-counter) ne ""} {
	    $options(-counter) Count accept_https
	}
	fconfigure $options(-sock) -blocking 0
	$self fileevent readable [list HttpdHandshake $options(-sock)]
    }
}
