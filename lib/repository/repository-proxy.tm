# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::proxy 0.1
# Meta platform    tcl
# Meta require     http
# Meta require     logger
# Meta require     repository::api
# Meta require     snit
# Meta require     teapot::config
# Meta require     teapot::listspec
# Meta require     teapot::metadata::index::sqlite
# Meta require     teapot::reference
# Meta require     Trf
# Meta require     uri
# Meta require     htmlparse
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview
# Copyright (c) 2007-2010 ActiveState Software Inc.

# snit::type implemention for proxy repositories. Requests are routed
# to the actual (remote) repository by way of http requests. Responses
# are collected in the same way. The remote repository is specified
# through its base url.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require repository::api
package require http
package require logger
package require uri
package require teapot::listspec                ; # Spec handling
package require teapot::reference               ; # Reference handling
package require teapot::config                  ; # Teapot client configuration
package require teapot::metadata::index::sqlite ; # Database used when local cache is present
package require Trf
package require autoproxy                       ; # Http proxying
package require fileutil
package require htmlparse                       ; # For StripTags

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::repository::proxy
snit::type            ::repository::proxy {

    option -readonly 0
    # For api compat, ignored.

    typemethod label {} { return "Proxy to remote" }

    typemethod valid {location mode mv} {
	upvar 1 $mv message
	if {![regexp {^http://} $location]} {
	    set message "Not an http uri"
	    return 0
	} elseif {[catch {uri::split $location} msg]} {
	    set message $msg
	    return 0
	} else {
	    return 1
	}
    }

    method valid {mode mv} {
	upvar 1 $mv message
	$type valid $options(-location) $mode message
    }

    option -timeout  -1     ;# HTTP timeout for requests (<= 0 = infinity)
    option -location {}     ;# Repository url
    option -config   {}     ;# TEAPOT configuration object
    option -notecmd  {}     ;# Callback for internal notes
    option -credentials {}  ;# list (user password) for basic authentication.

    # ### ### ### ######### ######### #########
    ## API - Delegated to the generic frontend

    delegate method * to API
    variable             API

    # ### ### ### ######### ######### #########
    ## API - Implementation.

    ## These are the methods that are called from the frontend during
    ## dispatch.

    method Put  {opt file}     {repository::api::complete $opt 1 "Bad request"}
    method Del  {opt instance} {repository::api::complete $opt 1 "Bad request"}
    method Path {opt instance} {repository::api::complete $opt 1 "Bad request"}
    method Dump {opt}          {repository::api::complete $opt 1 "Bad request"}

    method Verify {opt progresscmd} {
	repository::api::complete $opt 1 "Bad request. Remote repository not accessible for verification"
    }

    method Get {opt instance file} {
	log::debug "$self Get $instance"
	log::debug "\t=> $file"
	log::debug "\tOpt ($opt)"

	## This request is not cached. Archives aka teabags are always
	## retrieved from the remote server.

	teapot::instance::split $instance ptype pname pver plat

	set new [list command [mymethod GetReceived $opt $instance $file] opt $opt]

	$self Send $new [RequestFile [mymethod CheckIntegrity $instance] \
			     $file $ptype name $pname ver $pver arch $plat xfile]
	return
    }

    method GetReceived {opt instance file code result} {
	# Note: CheckIntegrity hacks on the command callback to bypass
	# this command if the xfile request was ok in the basics.  IOW
	# this command is called if and only if the 'xfile' requests
	# fails, because of the server not supporting the url.

	$self AbortOnAuthFailure [list __ $opt]

	# xfile request failed. Fall back to a plain 'file' request,
	# without any integrity checking of the transfered
	# information.

	log::debug "xfile failed, falling back to unchecked file"

	teapot::instance::split $instance ptype pname pver plat
	$self Send $opt [RequestFile {} $file $ptype name $pname \
			     ver $pver arch $plat file]
	return
    }

    method CheckIntegrity {instance opt request code result} {
	# Post processor

	# Pull the original callback out of the context structure.
	# This means that repository::complete calls will bypass
	# GetReceived, whatever the integrity check delivers.

	array set o $opt
	set opt $o(opt)

	# rq(file) = received file + integrity data, to be checked for
	# accurate transmission.

	log::debug "xfile ok, checking file for accurate transfer"

	# Disassemble the received file, i.e. extract the integrity
	# information, and replace the received complex file with the
	# actual data.

	log::debug "extracting checksum and payload, payload goes back to xfile"

	array set rq $request
	set tf [fileutil::tempfile]

	set p [open $rq(file) r]
	fconfigure $p -encoding utf-8
	foreach {esz ecs} [gets $p] break
	fconfigure $p -translation binary -encoding binary
	set t [open $tf w]
	fconfigure $t -translation binary -encoding binary
	fcopy $p $t
	close $t
	close $p

	#puts ""
	#puts "Received: $rq(file) [file size $rq(file)] | [md5::md5 -hex -file $rq(file)]"
	#puts "Data:     $tf       [file size $tf] | [md5::md5 -hex -file $tf]"

	file rename -force $tf $rq(file)

	log::debug "xfile ok, computing local checksum"

	# Now compute actual (received) size and checksum, then
	# compare against the expected data. Mismatches indicate a
	# transfer error.

	set asz [file size $rq(file)]
	set acs [string tolower [md5::md5 -hex -file $rq(file)]]

	log::debug "Actual   Size $asz"
	log::debug "         MD5  $acs"
	log::debug "Expected Size $esz"
	log::debug "         MD5  $ecs"

	if {($asz == $esz) && ($acs eq $ecs)} {
	    if {!$asz} {
		# Bug 83008.
		log::debug "xfile empty, means 404"
		# While complete and properly match, an empty package
		# is not possible. However the server seems to
		# generate this for files which do not exist. So size
		# zero, empty means => 404, nothing present.
		repository::api::complete $opt 1 \
		    "File not present"
		return
	    }

	    # Complete, transfer is ok.
	    repository::api::complete $opt $code $result
	    return
	}

	set err "Bad transfer:"
	if {$asz != $esz} {
	    append err " Size mismatch, expected '$esz', received '$asz'."
	}
	if {$acs ne $ecs} {
	    append err " MD5 mismatch, expected '$ecs', received '$acs'."
	}

	repository::api::complete $opt 1 $err
	return
    }

    method Require {opt instance} {
	PerCache Require $opt $instance
	$self Send $opt [RequestDep $instance require]
	return
    }

    method Recommend {opt instance} {
	PerCache Recommend $opt $instance
	$self Send $opt [RequestDep $instance recommend]
	return
    }

    method Requirers {opt instance} {
	PerCache Requirers $opt $instance
	$self Send $opt [RequestDep $instance requirers]
	return
    }

    method Recommenders {opt instance} {
	PerCache Recommenders $opt $instance
	$self Send $opt [RequestDep $instance recommenders]
	return
    }

    method Find {opt platforms ref} {
	PerCache Find $opt $platforms $ref
	$self Send $opt [RequestFind $platforms $ref max]
	return
    }

    method FindAll {opt platforms ref} {
	PerCache FindAll $opt $platforms $ref
	$self Send $opt [RequestFind $platforms $ref all]
	return
    }

    method Entities {opt} {
	PerCache Entities $opt
	$self Send $opt [Request index]
	return
    }

    method Versions {opt package} {
	PerCache Versions $opt $package
	foreach {pname} $package break
	$self Send $opt [Request entity name $pname index]
	return
    }

    method Instances {opt version} {
	PerCache Instances $opt $version
	foreach {pname pver} $version break
	$self Send $opt [Request entity name $pname ver $pver index]
	return
    }

    method List {opt {spec {}}} {
	PerCache List $opt $spec
	if {![llength $spec]} {
	    set rq [Request list]
	} else {
	    set rq [RequestPVI $spec list]
	}
	$self Send $opt $rq
	return
    }

    method Meta {opt spec} {
	PerCache Meta $opt $spec
	$self Send $opt [RequestPVI $spec meta]
	return
    }

    method Keys {opt {spec {}}} {
	PerCache Keys $opt $spec
	if {![llength $spec]} {
	    set rq [Request keys]
	} else {
	    set rq [RequestPVI $spec keys]
	}
	$self Send $opt $rq
	return
    }

    method Value {opt key spec} {
	PerCache Value $opt $key $spec
	$self Send $opt [RequestPVI $spec value $key]
	return
    }

    method Search {opt query} {
	PerCache Search $opt $query
	$self Send $opt [Request search $query]
	return
    }

    # ### ### ### ######### ######### #########
    ## Helpers.

    proc PerCache {args} {
	upvar 1 self self localcache localcache cachechecked cachechecked

	log::debug "$args"
	log::debug "LC ($localcache)"
	log::debug "CC $cachechecked"

	if {$localcache eq ""} {
	    # Pass through if there is no caching. The caller then
	    # goes through the network to the remote server.
	    return
	} elseif {$cachechecked} {
	    # Caching is active, and we have an uptodate local
	    # cache. Perform the operation on the cache database
	    # instead of going throw the network. This completes
	    # the call as well, so force the caller to abort its own
	    # processing.

	    $self LocalReq $args
	    return -code return
	}

	log::debug {Caching active, get status first}

	# Caching is active, however this is the first call ever. We
	# defer the request for a bit and update our local copy
	# first. When that has been done we execute the actual
	# request, using the local copy.

	$self GetStatus $args
	return -code return
    }

    method Disabled {request reason} {
	log::debug "DISABLED. $reason - Remote: $request"
	$self Note "Disabled local processing. $reason"

	$self AbortOnAuthFailure $request

	set localcache {}
	set cachestatusmsg "$reason.\n\tThe system\
            used slow(er) remote queries to keep working."

	# Now re-run the waiting request, this will do it remotely.
	eval [linsert $request 0 $self]
	return
    }

    method AbortOnAuthFailure {request} {
	if {($lasthttpcode != 401) && ($lasthttpcode != 403)} return

	# I know, we won't get 403. Now. Be prepared, just in case
	# this is changed in the future.

	# Abort command processing in full if we got an authorization
	# error. In that case retrying the original command makes no
	# sense, it would get the same auth error. Similarly it makes
	# no sense to have an auth-failed 'xfile' fall back to plain
	# 'file'.

	# request = (command options-dict args...)
	foreach {_cmd _opt} $request break

	repository::api::complete $_opt 1 [$self AuthMessage]
	return -code return
    }

    method AuthMessage {} {
	# Assemble a message ...

	if {[llength $options(-credentials)]} {
	    # Credentials were present in the request. These were
	    # either bogus, or are expired ...

	    set    msg "Your installed license"
	    append msg " seems to have expired. Please visit your"
	    append msg " account wherever you got the license to"
	    append msg " renew it"
	} else {
	    # No credentials were present, the user has no license.

	    set msg    "This operation needs some kind of license"
	    append msg " installed to succeed. Please talk to"
	    append msg " the administrator of the repository to"
	    append msg " learn where and how to get such."
	}

	return $msg
    }

    # This part is not required any longer.
    variable mymessage
    method StripTags {msg} {
	set mymessage {}
	htmlparse::parse -cmd [mymethod StripTagHandler] $msg
	return [join $mymessage]
    }
    method StripTagHandler {tag slash param text} {
	set text [string trim $text]
	if {$text eq {}} return
	lappend mymessage $text
	return
    }


    method cachestatus {} {
	return $cachestatusmsg
    }

    method Note {msg} {
	if {![llength $options(-notecmd)]} return
	set m "$options(-location): $msg"
	if {[catch {
	    eval [linsert $options(-notecmd) end $m]
	}]} {
	    puts stderr $m
	    puts stderr "INTERNAL ERROR: Notification failed"
	}
	return
    }

    method GetStatus {request} {
	log::debug "Get Status"
	$self Note "Retrieving remote INDEX status ..."
	set         opt [list command [mymethod DoneStatus $request]]
	$self Send $opt [Request db status]
	return
    }

    method DoneStatus {request code result} {
	# request = cmd opt arg...

	# result = rimtime rjmtime rjfirst rjlast ?index-integrity?
	#          idx mtime, journal mtime, journal first, last serial no
	# If index integrity is present, then = md5 & size uncompressed,
	#                                       md5 & size compressed
	# (4 elements, in the given order).

	# If the status inquiry caused an error we disable the cache and
	# re-run the original query, which will then go through the remote
	# server for the requested information.

	$self Note "Got   Status $tclcode($code)"
	$self Note "Got   Status = $lasthttpcode ($result)"
	#log::debug "Got Status $code ($result)"

	if {$code} {
	    $self Disabled $request {No status}
	    return
	}

	# We have the remote status now. Compare against the local one.
	# Without local status we assume that the local file does not
	# exist yet either, so we retrieve it in toto.

	# localcache is a path here/now. Later it will be the database
	# object.

	set indexIntegrity [lindex $result 4]

	set c $options(-config)
	if {[catch {set here [$c cache status? $options(-location)]}]} {
	    log::debug "No cached status"
	    $self Note "No cached status, get INDEX"
	    # Extended with INDEX integrity data. May be empty for older
	    # servers.
	    $self GetIndex $request $result
	    return
	}

	$self Note "Local Status = ($here)"

	# Got the current status of the cache as well, now compare.
	# The local status can be the empty list. This is the state
	# after a clear, and is the same as having no cached status.

	if {![llength $here]} {
	    log::debug "No cached status, empty"
	    $self Note "No cached status, get INDEX"
	    # Extended with INDEX integrity data. May be empty for older
	    # servers.
	    $self GetIndex $request $result
	    return
	}

	foreach {rimtime rjmtime rjfirst rjlast} $result break
	foreach {himtime hjmtime hjfirst hjlast} $here   break

	if {$rimtime <= $himtime} {
	    log::debug "Cache is up-to-date"

	    # The remote server was not updated since we checked last.
	    # We can use our copy unchanged.
	    if {[catch {
		$self MakeCache
	    } msg]} {
		# Failed to access the cache, just found to be
		# valid. Abort the current request cleanly, instead of
		# spitting an internal error upward and letting a
		# possible outer eventloop abort uncleanly.
		#
		# Note: The request options are always the second
		# word, just after the command to be run.
		repository::api::complete [lindex $request 1] 1 $msg
		return
	    }
	    $self LocalReq $request
	    return
	}

	log::debug "Outdated cache, get INDEX"
	$self Note "Outdated cache, get INDEX"

	$self Note "Remote INDEX last modified at $rimtime '[clock format $rimtime]'"
	$self Note "Local  INDEX last modified at $himtime '[clock format $himtime]'"

	# We have to update the index. For simplicity we retrieve the
	# for now whole index file.  FUTURE: Use the journal keys to
	# determine if we can use the journal instead of the full
	# index for the update.

	$self GetIndex $request $result
	return
    }

    method MakeCache {} {
	log::debug "Accessor for locally cached index"
	$self Note "Using locally cached INDEX"

	set localcache [teapot::metadata::index::sqlite ${selfns}::MD  \
			    -location [file dirname $localcache]]
	set cachechecked 1
    }

    method GetIndex {request status} {
	log::debug "Get Index"
	$self Note "Retrieving remote INDEX ..."

	set dst [fileutil::tempfile]

	$self Note "Storing received data in $dst"

	set         opt [list command [mymethod DoneIndex $request $status $dst]]
	$self Send $opt [RequestFile "" $dst db index]
	return
    }


    method DoneIndex {request status src code result} {
	#log::debug "Got Index $code ($result)"
	$self Note "Got Index: $tclcode($code) ($result)"

	# Failure to retrieve the database index disables the local
	# cache. The request is re-run, now going through the network.

	if {$code} {
	    $self Disabled $request "Retrieval of INDEX failed ($result)"
	    return
	}

	set integrity [lindex $status 4]

	if {$integrity eq ""} {
	    $self Note "Received  [file size $src] bytes"
	    $self Note "Server did no supply integrity data"

	} else {
	    # Check reception of compressed index.
	    foreach {ucmd ucsz cmd csz} $integrity break

	    $self Note "Expecting $csz bytes"

	    if {$csz != [file size $src]} {
		$self Note "Received  [file size $src] bytes FAIL"
		$self Disabled $request {Sizes not matching for compressed INDEX}
		return
	    } else {
		$self Note "Received  [file size $src] bytes OK"
		$self Note "Expecting md5 checksum: $cmd"

		set rcmd [string tolower [md5::md5 -hex -file $src]]
		if {$cmd ne $rcmd} {
		    $self Note "Received  md5 checksum: $rcmd FAIL"
		    $self Disabled $request {MD5 not matching for compressed INDEX}
		    return
		} else {
		    $self Note "Received  md5 checksum: $rcmd OK"
		}
	    }
	    # Ok, compressed index looks to be ok.
	}

	# We have the index. Unzip it first, then create the object
	# for accessing it and run the defered request through
	# it. Remember the status information too.

	set dst [fileutil::tempfile]
	$self Note "Unzip received data to $dst"

	if {[catch {
	    $self Unzip $src $dst ;#$localcache
	} msg]} {
	    $self Note "Unzip failed ($msg)"

	    # The new INDEX is bad, and we have overwritten the old
	    # one already. Disable the fast path and fall back to slow
	    # queries. Hope that the INDEX is fixed the next time we
	    # retrieve it.

	    $self Disabled $request {Bad INDEX}
	    return
	}

	if {$integrity eq ""} {
	    $self Note "Received  [file size $dst] bytes"
	} else {
	    $self Note "Expecting $ucsz bytes"

	    if {$ucsz != [file size $dst]} {
		$self Note "Received  [file size $dst] bytes FAIL"
		$self Disabled $request {Sizes not matching for decompressed INDEX}
		return
	    } else {
		$self Note "Received  [file size $dst] bytes OK"
		$self Note "Expecting md5 checksum: $ucmd"

		set rucmd [string tolower [md5::md5 -hex -file $dst]]

		if {$ucmd ne $rucmd} {
		    $self Note "Received  md5 checksum: $rucmd FAIL"
		    $self Disabled $request {MD5 not matching for decompressed INDEX}
		    return
		} else {
		    $self Note "Received  md5 checksum: $rucmd OK"
		}
	    }
	    # Ok, decompressed index looks to be ok as well.
	} 

	$self Note "Save  Status = ($status)"

	if {[catch {
	    # Copy temp decompressed INDEX to persistent cache, i.e. after
	    # the checks are done.
	    file mkdir [file dirname $localcache]
	    file rename -force $dst  $localcache

	    $options(-config) cache status $options(-location) $status
	} msg]} {
	    # Failed to store the received index in the cache
	    # area. Abort the current request cleanly, instead of
	    # spitting an internal error upward and letting a possible
	    # outer eventloop abort uncleanly.
	    #
	    # Note: The request options are always the second word,
	    # just after the command to be run.
	    $self Note "Saving failed ($msg)."
	    repository::api::complete [lindex $request 1] 1 $msg
	    return
	}

	$self Note "New INDEX accepted, saved to $localcache"

	if {[catch {
	    # Remove the temp file.
	    file delete $src
	} msg]} {
	    # Failed to remove temp file
	    $self Note "Removal of temp file failed ($msg)"
	    repository::api::complete [lindex $request 1] 1 $msg
	    return
	}

	if {[catch {
	    $self MakeCache
	} msg]} {
	    # Failed to access the cache, just found to be
	    # valid. Abort the current request cleanly, instead of
	    # spitting an internal error upward and letting a possible
	    # outer eventloop abort uncleanly.
	    #
	    # Note: The request options are always the second word,
	    # just after the command to be run.
	    $self Note "Access to cached index failed ($msg)"
	    repository::api::complete [lindex $request 1] 1 $msg
	    return
	}
	$self LocalReq $request
	return
    }

    method LocalReq {request} {
	log::debug "Local: $request"
	eval [linsert $request 0 $localcache]
    }

    method Unzip {src dst} {
	log::debug "Unzip"
	log::debug "  From $src"
	log::debug "  To   $dst"

	file mkdir [file dirname $dst]
	set chan [open $src r]
	set out  [open $dst w]
	fconfigure $chan -translation binary
	fconfigure $out  -translation binary
	zip -mode decompress -attach $out
	fcopy $chan $out
	#puts -nonewline $out [zip -mode decompress -- [read $chan]]
	close $chan
	close $out
	return
    }

    typevariable tclcode -array {
	0 Ok
	1 Failed
	2 Continue
	3 Break
    }

    # ### ### ### ######### ######### #########

    # * Convert request into a dict representation containing all
    #   pertinent information, and map it to an url
    # * Send request.
    # * Handle the response.

    proc Request {args} {
	return [list binary 0 url [Encode $args]]
    }

    proc RequestFile {postprocess file args} {
	# They key 'process' is used by 'Receive' to invoke a
	# postprocessing method, should it be needed. The method will
	# get request and options, after the file has been saved.
	return [list postprocess $postprocess binary 1 file $file url [Encode $args]]
    }

    proc RequestFind {platform ref what} {
	# As a repository backend we can expect that ref is already
	# normalized.
       
	return [Request find $what $ref $platform]
    }

    proc RequestDep {instance what} {
	teapot::instance::split $instance ptype pname pver plat
	return [Request $ptype name $pname ver $pver arch $plat $what]
    }

    proc RequestPVI {spec args} {
	set spectype [teapot::listspec::split $spec e n v a]
	switch -exact -- $spectype {
	    all       {set cmd [linsert $args 0 Request]}
	    name      {set cmd [linsert $args 0 Request entity name $n]}
	    version   {set cmd [linsert $args 0 Request entity name $n ver $v]}
	    instance  {set cmd [linsert $args 0 Request entity name $n ver $v arch $a]}
	    eall      {set cmd [linsert $args 0 Request $e]}
	    ename     {set cmd [linsert $args 0 Request $e     name $n]}
	    eversion  {set cmd [linsert $args 0 Request $e     name $n ver $v]}
	    einstance {set cmd [linsert $args 0 Request $e     name $n ver $v arch $a]}
	    default {
		return -code error "Bad spec \"$spec\""
	    }
	}
	return [eval $cmd]
    }

    proc Encode {pathlist} {
	set tmp {}
	foreach u $pathlist {
	    lappend tmp [repository::proxy segencode $u]
	}
	return $tmp
    }

    variable unhandled -array {}

    method Send {opt request} {
	array set rq $request

	log::debug "Sending request"
	log::debug "@ $options(-location)/[join $rq(url) /]"
	log::debug "T $options(-timeout), [expr {$rq(binary) ? "binary" : "text"}]"

	#$self Note "Sending request"
	#$self Note "@ $options(-location)/[join $rq(url) /]"
	#$self Note "T $options(-timeout), [expr {$rq(binary) ? "binary" : "text"}]"

	set unhandled($opt) .

	## global tick ; set tick [clock seconds]
	set where $options(-location)/[join $rq(url) /]
	set cback [mymethod Receive $opt $request]

	set command [list \
			 http::geturl \
			 $where \
			 -binary  $rq(binary) \
			 -command $cback]

	if {$options(-timeout) > 0} {
	    lappend command \
		-timeout $options(-timeout)
	}

	log::debug "C [list $options(-credentials)]"
	if {[llength $options(-credentials)]} {
	    lappend command \
		-headers [list Authorization \
			      [concat "Basic" \
				   [base64::encode \
				       [join $options(-credentials) :]]]]
	}

	log::debug "Executing \"$command\""
	if {[catch {
	    set token [eval $command]
	} msg]} {
	    log::debug "Failed ($msg)"
	    set m {}
	    foreach line [split $::errorInfo \n] {
		set x "HTTP INTERNAL ERROR: $line"
		log::debug $x
		lappend m $x
	    }

	    # [x] Catch and report connectivity problems
	    if {[info exists unhandled($opt)]} {
		repository::api::complete $opt 1 [join $m \n]
		unset unhandled($opt)
	    }
	    return
	}

	log::debug $token
	return
    }

    method Receive {opt request token} {
	# Defer a bit to get out of the http::Finish without error, as
	# this silences any error of ours. Well, it stores it in the
	# token. A token which we are cleaning up.
	log::debug "Receive Defer ($token) $opt $request"
	after 0 [mymethod ProcessReceived $opt $request $token]
	return
    }

    method ProcessReceived {opt request token} {
	array set rq $request

	## global tick tack ; set tack [clock seconds]
	## puts $tick
	## puts $tack
	## puts [expr {$tack - $tick}]

	log::debug "Received response ($token)"
	log::debug [http::status $token]|[http::code $token]|[http::ncode $token]

	#$self Note "Received response ($token)"
	#$self Note [http::status $token]|[http::code $token]|[http::ncode $token]

	set lasthttpcode   [http::ncode $token]
	set lasthttpresult [http::data  $token]

	if {[http::status $token] eq "timeout"} {
	    # See [x] for counterpart. It is unclear which problems
	    # are caught, which are not. Using 'unhandled' to
	    # explicitly remember to which calls we have responded
	    # already to prevent double calls and yet not miss
	    # anything.

	    unset unhandled($opt)
	    repository::api::complete $opt 1 timeout
	    return
	}

	if {[http::status $token] ne "ok"} {
	    # Network error ...
	    set code 1
	    set result [$self StripTags [http::error $token]]

	    log::debug "Network error: $result"

	} elseif {[http::ncode $token] != 200} {
	    # Http error ...
	    set code 1
	    set result [$self StripTags [http::data $token]]

	    log::debug "Http error: $result"
	} else {
	    # Result is stored inside of the returned text.
	    # In case of binary we actually have to copy
	    # into a file.

	    set code 0
	    set result [http::data $token]

	    #puts "Result size [string length $result]"
	    #puts "Result MD5  [md5::md5 -hex $result]"

	    if {$rq(binary)} {
		log::debug "File response, writing to \"$rq(file)\""

		set code [catch {
		    set ch [open $rq(file) w]
		    fconfigure $ch -translation binary
		    puts -nonewline $ch $result
		    close $ch
		} result]

		log::debug "File response: $code ($result)"
		log::debug "File response: \#bytes = [file size $rq(file)]"

		# This code path is invoked for the methods 'Get' and
		# 'GetIndex'. Our TODO above applies only to
		# 'Get'. 'GetIndex' has its own type of integrity
		# checking via 'GetStatus', done during setup of the
		# cached index. We have distinguish the two cases.

		# This is done via the contents of rq(postprocess).
		# This key is filled in by RequestFile at the
		# direction of its invoker, and is a command prefix to
		# run after the file has been saved. Currently only
		# 'Get' supplies such a processor, to perform the
		# integrity checking we want.

		if {$rq(postprocess) ne ""} {
		    log::debug "Postprocessing & cleaning up ($code ($result))\t/$token"

		    http::cleanup $token
		    unset unhandled($opt)

		    eval [linsert $rq(postprocess) end $opt $request $code $result]

		    # Stop here, cleanup is already done, and the post
		    # processor is responsible for completing the
		    # request.
		    return
		}
	    } else {
		# Automatically detect if we got a HTML result. And if
		# so extract the actual result embedded into the
		# visual fluff.

		set pattern "<body>\n<!-- \\\[\\\[TPM\\\[\\\[(.*)\\\]\\\]MPT\\\]\\\] -->"
		if {[regexp -- $pattern $result -> tclresult]} {

		    log::debug "HTML response detected, extracting Tcl response"
		    log::debug "Response: $tclresult"

		    set result $tclresult
		} else {
		    log::debug "Response: $result"

		    # This is a bad response. The embedded comment
		    # containing the result in Tcl form is missing.

		    set code 1
		    set result {The expected embedded Tcl result was not found. This indicates the presence of a http proxy rewriting the page.}
		}
	    }
	}

	log::debug "Cleaning up ($code ($result))\t/$token"

	http::cleanup $token
	unset unhandled($opt)
	repository::api::complete $opt $code $result
	return
    }

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	$self configurelist $args
	if {$options(-location) eq ""} {
	    return -code error "Remote location not specified"
	} elseif {![$type valid $options(-location) ro msg]} {
	    return -code error "Not a valid repository: $msg"
	}

	set options(-location) [string trimright $options(-location) /]

	# Query the client configuration if local caching of indices
	# is on. If yes we use a local copy of the remote sqlite
	# database to perform most operations (list, find, etc.). The
	# only operation calling to the remote location in that
	# situation will be the retrieval of any archive files.

	log::debug "$self -config = ($options(-config))"

	if {$options(-config) ne ""} {
	    set c $options(-config)
	    log::debug "$self cache is active = [$c cache is active]"

	    if {[$c cache is active]} {
		set localcache [file join [$c cache path $options(-location)] INDEX]

		log::debug "$self local cache = $localcache"
	    }

	    # Check if the user is overriding the automatic proxy
	    # configuration through the teacup configuration.

	    set hp [$c proxy get]
	    if {[llength $hp] == 2} {
		foreach {h p} $hp break
		log::debug "$self proxy = $h @ $p"
		autoproxy::init ${h}:${p}
		#autoproxy::configure -proxy_host $h
		#autoproxy::configure -proxy_port $p
	    }
	}

	# The api object dispatches requests directly to us.
	set API [repository::api ${selfns}::API -impl $self]
	return
    }

    variable localcache {}
    variable cachechecked 0
    variable cachestatusmsg {}
    variable lasthttpcode 0
    variable lasthttpresult {}

    typemethod segencode {segment} {
	# do x-www-urlencoded character mapping
	# The spec says: "non-alphanumeric characters are replaced by '%HH'"
	# 1 leave alphanumerics characters alone
	# 2 Convert every other character to an array lookup
	# 3 Escape constructs that are "special" to the tcl parser
	# 4 "subst" the result, doing all the array substitutions
	# The above is done for path segments, not the path string.
	# The / separators are not touched.

	set alphanumeric	a-zA-Z0-9
	regsub -all \[^$alphanumeric\] $segment {$urlMap(&)} segment
	regsub -all \n $segment {\\n} segment
	regsub -all \t $segment {\\t} segment
	regsub -all {[][{})\\]\)} $segment {\\&} segment
        set segment [subst $segment]
        return $segment
    }

    typevariable urlMap

    typeconstructor {
	set alphanumeric	a-zA-Z0-9
	for {set i 1} {$i <= 256} {incr i} {
	    set c [format %c $i]
	    if {![string match \[$alphanumeric\] $c]} {
		set urlMap($c) %[format %.2x $i]
	    }
	}
	return
    }
}

# ### ### ### ######### ######### #########
## Register us at the central type auto-detection.

autoproxy::init
::repository::api registerForAuto ::repository::proxy

# ### ### ### ######### ######### #########
## Ready
return
