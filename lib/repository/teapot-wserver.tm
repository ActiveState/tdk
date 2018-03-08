# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::wserver 0.1
# Meta platform    tcl
# Meta require     dictcompat
# Meta require     fileutil
# Meta require     Listener
# Meta require     logger
# Meta require     snit
# Meta require     teapot::instance
# Meta require     Trf
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type for a adaptor between a repository object and the
# web. Transforms Repo Web API requests into regular requests, and
# responses into the other direction.

# ### ### ### ######### ######### #########
## Requirements

if {![package vsatisfies [package present Tcl] 8.5]} {
    # Load dict emulation for Tcl 8.4 and before.
    package require dictcompat
}

package require platform
package require teapot::instance
package require teapot::reference
package require teapot::listspec
package require snit
package require fileutil
package require Listener ; # Draws in most of the required Http stuff as well.
package require logger  ; # Tracing
package require Trf

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::teapot::wserver
logger::initNamespace ::teapot::wserver::time
logger::initNamespace ::teapot::wserver::stat
snit::type            ::teapot::wserver {

    # ### ### ### ######### ######### #########
    ## Parameterization.

    # - Repository exported through server. Required. Construction time
    #   only.
    # - Port for server to listen on. 0 = System decision
    # - Result formatting: Html vs Tcl responses. Defaults to 'Tcl only'.
    # - Caching of results returned by the regular creation of dynamic content.

    option -repo     -default {} -readonly 1
    option -port     -default 0
    option -html     -default 0
    option -cachedir -default {} -readonly 1
    option -md       -default {} -readonly 1
    option -header   -default {} -readonly 1
    option -footer   -default {} -readonly 1

    # ### ### ### ######### ######### #########
    ## Construction

    constructor {args} {
	$self configurelist $args
	if {$options(-repo) eq ""} {
	    return -code error "repository object not specified"
	}

	$self Setup
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals ...

    variable hascache 0
    variable cachedir {}
    variable myheader ""
    variable myfooter ""

    method Setup {} {
	# HTTP server, dispatcher, etc.

	log::info "Teapot Web API [package present teapot::wserver]"
	log::info "Listening on TCP/IP port $options(-port)"

	Listener ${selfns}::antenna \
	    -port   $options(-port) \
	    -server "TPM Web API 0.1" \
	    -dispatcher [mymethod Handle]

	if {($options(-cachedir) ne "") &&
	    [fileutil::test $options(-cachedir) edrw]} {
	    set hascache 1
	    set cachedir $options(-cachedir)

	    log::info "Caching of dynamic content"
	    log::info "Cache directory: $cachedir"
	} else {
	    log::info "No caching of dynamic content"
	}

	foreach var {header footer} {
	    if {($options(-$var) ne "") &&
		[fileutil::test $options(-$var) efr]} {
		set my$var [fileutil::cat $options(-$var)]
		log::info "Using $var file $options(-$var)"
		log::info ====================================================
		log::info [set my$var]
		log::info ====================================================
	    } else {
		log::info "No $var"
	    }
	}
	return
    }

    method Handle {request} {
	# _ _ _ ___ ___ ___ _________ _________ _________
	# Unpack the request, then unlock the listener, allow it
	# receive more requests on the socket while we work. Most
	# notably, we do not need processing of PUT data. We add some
	# data to the request for timing and other statistics.

	lappend request \
	    -tpm-Received [clock seconds] \
	    -tpm-Begin    [clock clicks -milliseconds]

	array set r $request
	set conn $r(-http)
	$conn Pipeline

	# _ _ _ ___ ___ ___ _________ _________ _________
	# Decode the incoming path (basics).

	log::debug "Request received\n[parray r]"

	set path [string trimleft $r(-path) /]

	log::debug "Dispatch for \"$path\""
	log::info  [string repeat "=" [string length "Request: $path"]]
	log::info  "Request: $path"

	# _ _ _ ___ ___ ___ _________ _________ _________
	# Check if we have a file in the cache area for the path.
	# If yes we simply serve that. No need for expensive
	# dynamic generation.

	# _ NOTE _ This facility is also used to capture requests for
	# special things, like a 'robots.txt' file to handle search
	# engines.

	$self PerCache $path $request

	# _ _ _ ___ ___ ___ _________ _________ _________
	# Handle the special requests (version, db status, various db files)

	# They are not cached as they return either files directly
	# (index, journal), or are not expected to be called often, or
	# to take much time (status). The latter because they do repo
	# internal caching of the information.

	if {$path eq "version"} {
	    clear ; put $options(-md)
	    $self Done/Text $request
	    return
	} elseif {$path eq "db/status"} {

	    set     status [$options(-repo) IndexStatus]
	    lappend status [$self IndexIntegrityInformation]

	    $self Done/Html/IS $request $status
	    return
	} elseif {$path eq "db/journal"} {
	    # When requested the journal is delivered in zlib
	    # compressed form, and also cached in this form, if a
	    # cache is active.

	    set src [$self Zip [$options(-repo) Journal] [file join $cachedir $path]]

	    if {!$hascache} {file delete $src}
	    return
	} elseif {$path eq "db/index"} {
	    # When requested the index is delivered in zlib compressed
	    # form, and also cached in this form, if a cache is
	    # active.

	    set src [$self Zip [$options(-repo) INDEX] [file join $cachedir $path]]
	    $self ServeCache $src $request

	    if {!$hascache} {file delete $src}
	    return
	}

	# _ _ _ ___ ___ ___ _________ _________ _________
	# Re-encode the requested path as a request for the repository
	# serving us and let it work the problems out.

	set newurl [Redirect $path]
	if {[string length $newurl]} {
	    $self Done/Redirect $request $newurl
	    return
	}

	set code [Decode $path]
	if {![llength $code]} {
	    $self Done/404 $request
	    return
	}

	foreach {use thefile method args} [Encode $code] break

	lappend request -M $method -A $args

	if {$use eq "FILE"} {
	    lappend request FILE $thefile
	} elseif {$use eq "CHAN"} {
	    lappend request CHAN {}
	}

	# Choose result formatter
	if {$options(-html)} {
	    set done Done/Html/$method
	} else {
	    set done Done/Tcl
	}

	if {[string match X* $method]} {
	    log::info "Server Internal Method"

	    set cmd [list $self $method [mymethod Done $done $request]]

	} else {
	    log::info "Repository Method"

	    set cmd [list $options(-repo) \
			 $method \
			 -command [mymethod Done $done $request]]
	}

	foreach a $args {lappend cmd $a}

	log::debug "Command $cmd"

	eval $cmd
	return
    }

    proc Redirect {path} {
	::variable redirmap

	# Check for redirection. We are using it to convert urls
	# normally to short into something sensible (index, list). See
	# the 'redir' commands in the SETUP below for the exact
	# mapping generated. The redirection result is given as
	# special status to the browser for re-submission. This way
	# the browser, and more importantly, the user sitting in front
	# of it, will see the new and correct url. Otherwise we would
	# simply see the same data in several places.

	foreach {p dst} $redirmap {
	    log::debug "Redir Check $p"

	    if {![regexp "^$p$" $path]} continue

	    log::info "Redirection Pattern:     $p"
	    log::info "Redirection Destination: $dst"

	    set path [string map [list ! $path] $dst]

	    log::info "Redirected to:           $path"
	    return $path
	}

	log::info "Redirection: None"
	return {}
    }

    proc Decode {path} {
	::variable patternmap
	# Try to recognize the incoming url.

	foreach {p m adefs} $patternmap {

	    log::debug "Check $p"

	    set matches [regexp -inline "^$p$" $path]
	    if {![llength $matches]} continue

	    # ### #########
	    ## Pattern found. Processing now assembles the backend request.

	    log::debug "Ok, invokes \"$m\" ($adefs)"

	    log::info "Pattern: $p"
	    log::info "Method:  $m ($adefs)"

	    set tmp {}
	    foreach el $matches {lappend tmp [_segdecode $el]}
	    set matches $tmp

	    log::debug "Matches: ([join $matches "\) \("])"

	    return [list $matches $m $adefs]
	}

	log::warn "Bad URL; rejected"
	return {}
    }

    proc Encode {am} {
	foreach {matches method adefs} $am break
	set arg {}
	set cmd {}
	set use {}
	set thefile {}

	foreach adef $adefs {
	    set t [lindex $adef 0]
	    switch -exact -- $t {
		+ {
		    log::debug "ARG: $arg"
		    lappend cmd $arg
		    set arg {}
		}
		i {
		    lappend arg [lindex $adef 1]
		}
		@ {
		    lappend arg [lindex $matches [lindex $adef 1]]
		}
		= {
		    set arg [lindex $matches [lindex $adef 1]]
		}
		r {
		    foreach {_ s e} $adef break
		    set arg [lrange $matches $s $e]
		}
		file {
		    set thefile [fileutil::tempfile rws]
		    file delete $thefile ; # Backend will create it.
		    set arg $thefile
		    set use FILE
		}
		chan {
		    set use CHAN
		}
	    }
	}

	log::info "Method:  $method [list $cmd]"

	if {$use ne ""} {
	    log::info "Result:  $use"
	} else {
	    log::info "Result:  Immediate"
	}
	return [list $use $thefile $method $cmd]
    }

    method XchanX {done instance} {
	# Get path first. This will give us archive type, size, and
	# the md5 checksum. The latter are used for transfer integrity
	# checking by the proxy repository. We distinguish between
	# opaque and transparent repositories later, i.e. we check we
	# get a directory path, and retrieve th

	$options(-repo) path \
	    -command [mymethod XchanX/Done $done $instance] $instance
	return
    }

    method XchanX/Done {done instance code result} {
	# result = path

	log::debug "Code   = $code"
	log::debug "Result = $result"

	if {$code} {
	    # In the case of an error we pull the original request out
	    # of the callback for if we had been successful, and use
	    # it to compose the error reply.

	    set request [lindex $done end]
	    log::debug "ERROR ($result)"
	    $self Done/Error $request
	    return
	}

	log::info  "Path = $result ([expr {[file isfile $result]?"file":"dir"}])"

	if {[file isfile $result]} {
	    # We have a file. Proceed to final processing.
	    $self XchanX/Done/File $done $result
	} else {
	    # Its a directory. Can come only from a transparent
	    # repository. Do a second step, 'get' the zip archive.
	    # This will generate the archive on the fly. We put it
	    # into a temp file, will be cleaned up after use.
	    set t [fileutil::tempfile]
	    $options(-repo) get -command \
		[mymethod XchanX/Done/Get $done $t] \
		$instance $t
	}
	return
    }

    method XchanX/Done/Get {done tempfile code result} {
	# result = empty, tempfile now defined, and contains
	# the generated zip archive. We delete it after final
	# processing.
	$self XchanX/Done/File $done $tempfile
	# As the zip is generated we delete it after use.
	file delete $tempfile
	return
    }

    method XchanX/Done/File {done packagefile} {

	# Final processing. Get archive size, md5 hash, content
	# type. Assemble a file containing the integrity info and data
	# it came from. This eXtended file will be shipped to the
	# client.

        set ct [ar-content-type $packagefile]
	set sz [file size $packagefile]
	set cs [string tolower [md5::md5 -hex -file $packagefile]]

	log::info "Package file  $packagefile"
	log::info "Content-type  $ct"
	log::info "File size     $sz"
	log::info "MD5 signature $cs"

	set tempfile [fileutil::tempfile]

	set p [open $packagefile r]
	fconfigure $p -translation binary -encoding binary
	set t [open $tempfile    w]

	# Format of the extended file: Integrity information (size and
	# md5 checksum of the data) first, on a single line, followed
	# by the actual data. The content type CT will become part of
	# the http response, i.e. is not handled here.

	fconfigure $t -encoding utf-8
	puts       $t "$sz $cs"
	fconfigure $t -translation binary -encoding binary
	fcopy   $p $t
	close   $p
	close $t

	# And proceed to the server core completing the request,
	# shipping the result out.
	eval [linsert $done end 0 [list FILE $tempfile $ct]]
	return
    }

    method Done/Html/XchanX {request result} {
	foreach {what tempfile ctype} $result break
	# detail = file, dyn generated! try to cache
	# what = FILE, always

	$self Done/File [linsert $request end FILE $tempfile CACHEIT .] $ctype
	# Done/File always assumes that it got a temp file and deletes
	# it after use.
	return
    }

    method Xchan {done instance} {
	# Getting channel, and archive type (through path).
	# Could determine it from the link name, except that this
	# trusts the user to not modify the link before giving it to
	# us. So we do it again ourselves.

	if {[$options(-repo) info type] eq "::repository::localma"} {
	    # Transparent repository.
	    # Get and check path first. A directory implies .zip archive,
	    # implies dynamic regeneration, implies possible caching.

	    $options(-repo) path \
		-command [mymethod Xchan/Done/T $done $instance] $instance
	} else {
	    $options(-repo) chan \
		-command [mymethod Xchan/Done $done $instance] $instance
	}
	return
    }

    # Path for regular repository
    method Xchan/Done {done instance code result} {
	if {$code} {
	    # In the case of an error we pull the original request out
	    # of the callback for if we had been successful, and use
	    # it to compose the error reply.

	    set request [lindex $done end]
	    log::debug "ERROR ($result)"
	    $self Done/Error $request
	    return
	}

	# result = channel handle
	$options(-repo) path -command \
	    [mymethod Xchan/DonePath $done $result] $instance
	return
    }

    method Xchan/DonePath {done chan code result} {
	if {$code} {
	    # In the case of an error we pull the original request out
	    # of the callback for if we had been successful, and use
	    # it to compose the error reply.

	    set request [lindex $done end]
	    log::debug "ERROR ($result)"
	    $self Done/Error $request
	    return
	}

	# result = path
	eval [linsert $done end $code \
		  [list CHAN $chan [ar-content-type $result]]]
	return
    }

    # Path for transparent repository
    method Xchan/Done/T {done instance code result} {
	if {$code} {
	    # In the case of an error we pull the original request out
	    # of the callback for if we had been successful, and use
	    # it to compose the error reply.

	    set request [lindex $done end]
	    log::debug "ERROR ($result)"
	    $self Done/Error $request
	    return
	}

	# result = path
	if {[file isfile $result]} {
	    # Switch over to the regular path, using a channel.
	    $options(-repo) chan \
		-command [mymethod Xchan/Done $done $instance] $instance
	    return
	}

	# We have a directory here, meaning that we are dealing with
	# an unpacked zip file. We 'get' it from the repository into a
	# temp file, and try to cache it later.

	set t [fileutil::tempfile]
	$options(-repo) get -command \
	    [mymethod Xchan/Done/TGet $done $result $t] \
	    $instance $t
	return
    }

    method Xchan/Done/TGet {done path tempfile code result} {
	# result = empty
	eval [linsert $done end $code \
		  [list FILE $tempfile [ar-content-type $path]]]
	return
    }


    method Xdetails {done instance} {
	# Collate detailed information about the instance.
	log::info Collate

	$options(-repo) meta -command [mymethod Xdetails/DoneMeta $done $instance] \
	    [linsert $instance 0 1]
	return
    }

    method Xdetails/DoneMeta {done instance code result} {
	# result = meta
	# Currently the entity details consist only of the meta data.
	# But we need the list of available platforms as well, for
	# references and find.

	$options(-repo) archs -command \
	    [mymethod Xdetails/DoneArchs $done $instance $result]
	return
    }

    method Xdetails/DoneArchs {done instance meta code result} {
	# result = archs

	$options(-repo) path -command [mymethod Xdetails/DonePath $done $meta $result] \
	    $instance
	return
    }

    method Xdetails/DonePath {done meta archs code result} {
	# result = path
	eval [linsert $done end $code \
		  [list $meta $archs [ar-extension $result]]]
	return
    }

    method Done {chain request code result} {
	log::debug "Result ready: $code [list $result]"
	log::info  "Result:  $code [list $result]"

	if {$code} {
	    lappend request -content $result
	    $self Done/Error $request
	    return
	}

	log::debug "Generating via $chain"

	$self $chain $request $result
	return
    }


    method Done/Tcl {request result} {
	# Insert the various result data ...
	# Either immediate, or FILE, CHAN, or xCHAN

	array set r $request

	if {
	    [info exists  r(FILE)] &&
	    [file exists $r(FILE)]
	} {
	    $self Done/File $request

	} elseif {[info exists r(CHAN)]} {

	    $self Done/Chan [linsert $request end CHAN $result]

	} else {
	    clear ; put $result
	    $self Done/Text $request
	}
	return
    }

    method Done/Html {request} {
	put "$myfooter\n</body></html>\n"
	$self Done/Text $request text/html
    }

    # ### ### ### ######### ######### #########
    # Methods doing the final responses.

    method Done/Text {request {ctype text/plain}} {
	set text [get]
	array set r $request
	lappend request -content $text
	$self Respond 200 $request $ctype
	$self PutCache/Text [string trimleft $r(-path) /] $text $ctype
	return
    }

    method Done/File {request {ctype application/octect-stream}} {
	array set r $request
	set thefile $r(FILE)
	set cacheit [info exists r(CACHEIT)]

	set r(-fd)   [open $thefile r]
	unset r(FILE)
	catch {unset r(CACHEIT)}
	fconfigure $r(-fd) -translation binary -encoding binary
	$self Respond 200 [array get r] $ctype

	if {$cacheit && $hascache} {
	    $self PutCache/File [string trimleft $r(-path) /] $thefile $ctype
	}

	# Note: Next command is unix-specific, will fail on
	# Windows.
	file delete -force $thefile
	# FUTURE Look for a completion callback in wub to delay
	# deletion until after use.
	return
    }

    method Done/Chan {request {ctype application/octect-stream}} {
	array set r $request
	set r(-fd) $r(CHAN)
	unset       r(CHAN)
	fconfigure $r(-fd) -translation binary -encoding binary
	# HOW TO : Set http encoding to binary.

	if {[info exists r(TYPE)]} {
	    set ctype   $r(TYPE)
	    unset        r(TYPE)
	}
	$self Respond 200 [array get r] $ctype
	return
    }

    method Done/Redirect {request newurl} {
	lappend request location /$newurl -content {Redirecting short url}
	$self Respond 301 $request
	return
    }

    method Done/404 {request} {
	if {$options(-html)} {
	    set request [BadHtml $request]
	    set ctype   text/html
	} else {
	    set request [Bad $request]
	    set ctype   text/plain
	}
	$self Respond 404 $request $ctype
	return
    }

    method Done/Error {request} {
	$self Respond 404 $request text/plain
	return
    }

    method Respond {code request {ctype text/plain}} {
	array set r $request

	lappend request Content-Type $ctype
	$r(-http) Respond $code $request

	# Collect statistics here.
	# r(-tpm-Received)
	# r(-tpm-Begin)
	# r(-ipaddr)
	# r(-path)
	# r(user-agent)

	time::log::info [list $r(-path) $r(-tpm-Received) [expr {[clock clicks -milliseconds] - $r(-tpm-Begin)}]]
	stat::log::info [list $r(-path) $r(-ipaddr) $r(user-agent)]

	switch -exact -- $code {
	    404     { log::error "NOT_FOUND  $code = [list $r(-path) $r(-ipaddr) $r(user-agent)]" }
	    301     { log::warn  "REDIRECTED $code = [list $r(-path) $r(-ipaddr) $r(user-agent)]" }
	    default {}
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## Handling the cache ... (Checking, Filling).

    method IndexIntegrityInformation {} {

	# Compute integrity information, size information and md5 #
	# checksum for both uncompressed and compressed INDEX so that
	# # a user (teacup) can check the integrity of the download #
	# result. This implicitly puts the INDEX into the cache too.

	set ucindex [$options(-repo) INDEX]
	set cindex [file join $cachedir db/index]

	if {![file exists $cindex]} {
	    # Not in cache ...
	    set cindex [$self Zip $ucindex $cindex]
	}

	set ucsz [file size $ucindex]
	set ucmd [md5::md5 -hex -file $ucindex]

	# Getting the info for the compressed index is a bit more
	# complicated, due to the ctype preamble we have to skip for
	# both size and md5 calculation.
	set ci [open $cindex r]
	gets $ci ; # skip preamble
	set csz  [expr {[file size $cindex] - [tell $ci]}]
	fconfigure $ci -translation binary
	set cmd  [md5::md5 -hex -channel $ci]
	close $ci

	if {!$hascache} {
	    file delete $cindex
	} elseif {![file exists $cindex]} {
	    PutCache/File [file join $cachedir db/index] $cindex application/octect-stream 
	}

	return [list [string tolower $ucmd] $ucsz [string tolower $cmd] $csz]
    }

    method Zip {src dst} {
	if {!$hascache} {
	    set dst [fileutil::tempfile]
	}

	file mkdir [file dirname $dst]
	set chan [open $src r]
	set out  [open $dst w]

	# See PutCache/Text - content-type is first line.
	puts       $out application/octet-stream

	fconfigure $chan -translation binary
	fconfigure $out  -translation binary
	zip -mode compress -level 9 -attach $out
	fcopy $chan $out
	close $chan
	close $out

	log::info "Zipped to $dst"
	return $dst
    }

    method ServeCache {cfile request} {
	# Get the content type out of the first line of the cache
	# file. The remainder is the actual response to serve.

	lappend request CHAN [set chan [open $cfile r]]
	set ctype [gets $chan]
	$self Done/Chan $request $ctype
	return
    }

    method PerCache {path request} {
	if {$hascache} {
	    set cfile [file join $cachedir $path]
	    if {[fileutil::test $cfile efr]} {
		# Found a match. Serve it up.
		log::info  "Cache match"
		$self ServeCache $cfile $request
		return -code return
	    }
	}
    }

    method PutCache/Text {path text ctype} {
	if {!$hascache} return
	fileutil::writeFile [file join $cachedir $path] $ctype\n$text
	return
    }

    method PutCache/File {path src ctype} {
	if {!$hascache} return
	set out [file join $cachedir $path]
	fileutil::writeFile $out $ctype\n
	set o [open $out a]
	set i [open $src r]
	fconfigure $o -translation binary
	fconfigure $i -translation binary
	fcopy $i $o
	close $i
	close $o
	return
    }

    # ### ### ### ######### ######### #########

    proc urlof {args} {
	set tmp {}
	foreach u $args {
	    lappend tmp [_segencode $u]
	}
	return /[join $tmp /]
    }

    proc findurl {archs ref what} {
	# We are forcing the reference into canonical form before
	# constructing the url for the page under construction.

	return [urlof find $what [teapot::reference::normalize1 $ref] $archs]
    }

    method Done/Html/Xdetails {request result} {
	# entity details. Not used by the cmdline client.
	# Therefore no embedded result.
	# The result are currently the meta data of the entity.

	array set r $request

	clear
	prolog

	foreach {meta archs ext} $result break
	# ext in <.zip, .tm, .kit, exe> archive file type

	array set md $meta
	unset -nocomplain md(name)
	unset -nocomplain md(version)

	teapot::instance::split [lindex $r(-A) 0] t n v a
	tag/ h1 {
	    tag* a Index href /index
	    put " | $n "
	    tag* a Versions href /entity/name/$n/index
	    put " > "
	    tag* a "$v Instances" href /entity/name/$n/ver/$v/index
	    put " > "
	    tag em "$a Details"
	}
	set tx [string tolower $t]

	tag/ h2 {
	    tag* a {Package archive} href /$tx/name/$n/ver/$v/arch/$a/file$ext
	}
	tag h2 "Details of [lindex $r(-A) 0]"
	tag/ table {
	    tag/ tr {
		tag th Key
		tag th Value
	    }
	    foreach k [lsort -dict [array names md]] {
		set v $md($k)
		tag/ tr {
		    # FUTURE: Create package/DSL to describe meta data
		    # FUTURE: keywords (type (string, list, dict,
		    # FUTURE: etc.), formatting (text, html, ...),
		    # FUTURE: human label, description, and so on (*))
		    # FUTURE: and use that to drive the conversion
		    # FUTURE: here. See also 'build/ashelp.tcl' and
		    # FUTURE: the package overview generated there, it
		    # FUTURE: requires the same type of driving, just
		    # FUTURE: a different backend.
		    # FUTURE: 
		    # FUTURE: (Ad *) In essence meta data of the meta
		    # FUTURE: data keywords.

		    tag* td $k valign top
		    if {($k eq "require") || ($k eq "recommend")} {
			tag/ td {
			    tagjoin $v ref {
				set name [teapot::reference::name $ref]
				if {$name eq "Tcl"} {
				    put $ref
				} else {
				    if {$a eq "tcl"} {
					set archf $archs
				    } else {
					set archf [platform::patterns $a]
				    }
				    tag* a $ref href [findurl $archf $ref all]
				}
			    } {
				tag0 br
			    }
			} valign top
		    } elseif {[string match *origin* $k]} {
			tag/ td {
			    tagjoin $v url {
				tag* a $url href $url
			    } {
				tag0 br
			    }
			} valign top
		    } elseif {[string match *author* $k]} {
			tag/ td {
			    tagjoin [lsort -dict $v] name {
				put $name
			    } {
				tag0 br
			    }
			} valign top
		    } else {
			tag* td [join $v { }] valign top
		    }
		}
	    }
	}

	$self Done/Html $request
	return
    }

    method Done/Html/IS {request result} {
	# /db/status

	clear
	prolog
	embresult $result
	put <pre>$result</pre>

	$self Done/Html $request
    }

    method Done/Html/entities {request result} {
	# /index
	# - List of entity names.

	clear ; prolog
	embresult $result
	tag h1 {List of all entities}
	tag/ ul {
	    foreach p [lsort -dict $result] {
		tag/ li {
		    # Refer to versions ...
		    tag* a $p href /entity/name/$p/index
		}
	    }
	}

	$self Done/Html $request
    }

    method Done/Html/versions {request result} {
	# Urls mapped to here.
	# /entity/name/PNAME/index
	# /PTYPE/name/PNAME/index
	#
	# Result
	# - List of entity versions.

	clear ; prolog
	embresult $result
	if {[llength $result]} {
	    set n [lindex $result 0 0]

	    tag/ h1 {
		tag* a Index href /index
		put " | $n "
		tag em "Versions"
	    }
	    tag/ ul {
		foreach ver $result {
		    foreach {n v} $ver break
		    tag/ li {
			# Refer to instances ...
			tag* a $v href /entity/name/$n/ver/$v/index
		    }
		}
	    }
	}

	$self Done/Html $request
    }

    method Done/Html/instances {request result} {
	# Urls
	# /entity/name/PNAME/ver/PVER/index
	# /PTYPE//name/PNAME/ver/PVER/index

	# Result
	# - List of entity instances.

	clear ; prolog
	embresult $result
	if {[llength $result]} {
	    teapot::instance::split [lindex $result 0] t n v p
	    tag/ h1 {
		tag* a Index href /index
		put " | $n "
		tag* a Versions href /entity/name/$n/index
		put " > "
		tag em "$v Instances"
	    }

	    tag/ table {
		tag/ tr {
		    tag th Type
		    tag th Platform
		}
		foreach ins $result {
		    teapot::instance::split $ins t n v p
		    set tx [string tolower $t]
		    tag/ tr {
			tag/ td {
			    # Refer to list of instances having this type ...
			    tag* a $t href /$tx/list
			}
			tag/ td {
			    # Refer to entity details ...
			    tag* a $p href /$tx/name/$n/ver/$v/arch/$p/details
			}
		    }
		}
	    }
	}

	$self Done/Html $request
    }

    method Done/Html/find {request result} {
	# /find/pkg/max/PNAME/PLATFORM
	# /find/ver/max/PNAME/PVER/PLATFORM
	# /find/exact/max/PNAME/PVER/PLATFORM
	# - List of instances

	array set r $request
	set heading [findheading r]

	clear ; prolog
	instances/find "Best instance of [lindex $r(-A) 1]" $heading $result
	$self Done/Html $request
    }

    method Done/Html/findall {request result} {
	# /find/pkg/all/PNAME/PLATFORM
	# /find/ver/all/PNAME/PVER/PLATFORM
	# /find/exact/all/PNAME/PVER/PLATFORM
	# - List of instances

	array set r $request
	set heading [findheading r]

	clear ; prolog
	instances/find "All instances of [lindex $r(-A) 1]" $heading $result
	$self Done/Html $request
    }

    proc findheading {reqv} {
	upvar 1 $reqv r

	clear
	tag h2 {Acceptable platforms}
	tag/ ul {
	    foreach a [lsort -dict [lindex $r(-A) 0]] {
		tag li $a
	    }
	}
	tag h2 Results
	return [get]
    }

    method Done/Html/get {request result} {
	# /package/PNAME/ver/PVERSION/arch/PLATFORM/file
	# - Instance file (.tm, .zip, ...)
	$self Done/File $request
    }

    method Done/Html/Xchan {request result} {
	foreach {what detail ctype} $result break

	if {$what eq "CHAN"} {
	    # detail = chan
	    $self Done/Chan [linsert $request end CHAN $detail] $ctype
	} else {
	    # detail = file, dyn generated! try to cache
	    $self Done/File [linsert $request end FILE $detail CACHEIT .] $ctype
	}
	return
    }

    method Done/Html/chan {request result} {
	# /package/PNAME/ver/PVERSION/arch/PLATFORM/file
	# - Instance file (.tm, .zip, ...)

	# result = channel handle

	$self Done/Chan [linsert $request end CHAN $result]
    }

    method Done/Html/keys {request result} {
	# /keys
	# /package/PNAME/keys
	# /package/PNAME/ver/PVERSION/keys
	# /package/PNAME/ver/PVERSION/arch/PLATFORM/keys
	# - List of names

	array set r $request

	clear ; prolog
	embresult $result

	if {$r(-A) eq ""} {
	    tag h1 "All known keys"
	} else {
	    tag h1 "Keys for $r(-A)"
	}

	tag/ table {
	    tag/ tr {tag th Key}
	    foreach k $result {
		tag/ tr {tag td $k}
	    }
	}

	$self Done/Html $request
    }

    method Done/Html/list {request result} {
	# Urls which mapped to this operation and come here
	#
	# /entity/PNAME/list
	# /entity/PNAME/ver/PVERSION/list
	# /entity/PNAME/ver/PVERSION/arch/PLATFORM/list
	#
	# /PTYPE/list
	# /PTYPE/PNAME/list
	# /PTYPE/PNAME/ver/PVERSION/list
	# /PTYPE/PNAME/ver/PVERSION/arch/PLATFORM/list
	#
	# Result
	# - List of instances
	#   (entity name version architecture profile)

	array set r $request

	clear ; prolog
	instances/find "Instances of \"[teapot::listspec::print2 [lindex $r(-A) 0]]\"" "" $result
	$self Done/Html $request
    }

    method Done/Html/meta {request result} {
	# /package/PNAME/meta
	# /package/PNAME/ver/PVERSION/meta
	# /package/PNAME/ver/PVERSION/arch/PLATFORM/meta
	# - Dictionary

	array set r $request

	clear ; prolog
	embresult $result
	tag h1 "Meta data for $r(-A)"
	tag/ table {
	    tag/ tr {
		tag th Key
		tag th Value
	    }
	    foreach {k v} $result {
		tag/ tr {
		    tag td $k
		    tag td $v
		}
	    }
	}

	$self Done/Html $request
	return
    }

    method Done/Html/value {request result} {
	# /package/PNAME/value/KEYWORD
	# /package/PNAME/ver/PVERSION/value/KEYWORD
	# /package/PNAME/ver/PVERSION/arch/PLATFORM/value/KEYWORD
	# - Value for key.

	array set r $request

	clear ; prolog
	embresult $result
	tag h1 "Meta data value for $r(-A)"
	tag/ table {
	    tag/ tr {
		tag th Value
	    }
	    tag/ tr {
		tag td $result
	    }
	}

	$self Done/Html $request
    }

    method Done/Html/recommend {request result} {
	# /package/PNAME/ver/PVERSION/arch/PLATFORM/recommend
	# - List of templates/(dependency refs)

	array set r $request

	clear ; prolog
	refs/full "Packages recommended by ($r(-A))" $result
	$self Done/Html $request
    }

    method Done/Html/require {request result} {
	# /package/PNAME/ver/PVERSION/arch/PLATFORM/require
	# - List of templates/(dependency refs)

	array set r $request

	clear ; prolog
	refs/full "Packages required by ($r(-A))" $result
	$self Done/Html $request
    }

    method Done/Html/search {request result} {
	# /search
	# - List of instances

	array set r $request

	clear ; prolog
	instances/find "Results for search query $r(-A)" "" $result
	$self Done/Html $request
    }

    proc ar-extension {path} {
	# Extension to give to the 'file' in a download link. Based on
	# the kind of archive. See ar-content-type below for what we
	# deal with. Only the mapping is different.

	# Mapping
	# (Ad 1)   -> .tm
	# (Ad 2)   -> .kit
	# (Ad 3)   -> .zip
	# (Ad 4)   -> .exe

	set types [fileutil::fileType $path]
	if {[_in zip $types] || [_in directory $types]} {
	    # (3,5)
	    # NOTE: Directories are .zip files, from a transparent
	    # repository.
	    return .zip
	} elseif {[_in metakit $types]} {
	    if {[_in binary $types]} {
		# (4)
		return .exe
	    } elseif {[_in text $types]} {
		# (2)
		return .kit
	    } else {
		# Metakit, neither text, nor binary ?
		# Consider it as generic binary
		return .dat
	    }
	} elseif {[_in text $types]} {
	    # (1)
	    return .tm
	} else {
	    # Unknown. Consider it binary and use a generic extension
	    # to indicate this.
	    return .dat
	}
    }

    proc ar-content-type {path} {
	# content-type for archive files.
	# Consider:

	#     Types           | Kind of archive
	# (1) text            - Tcl Module
	# (2) text, metakit   - Tcl Module with attached Metakit FS, Starkit
	# (3) binary, zip     - Zip archive
	# (4) binary, metakit - Starpack
	# (5) directory       - Zip archive unpacked in transparent repository.

	# Mapping
	# (Ad 1)   -> text/plain
	# (Ad 2,4) -> full binary (octet-stream)
	# (Ad 3)   -> zip

	set types [fileutil::fileType $path]
	if {[_in zip $types] || [_in directory $types]} {
	    # (3,5)
	    return application/x-zip
	} elseif {[_in metakit $types]} {
	    # (2,4)
	    return application/octet-stream
	} elseif {[_in text $types]} {
	    # (1)
	    return text/plain
	} else {
	    # Unknown type. Consider it as binary.
	    return application/octet-stream
	}
    }

    proc _in {item list} {
	return [expr {[lsearch -exact $list $item] >=0}]
    }

    proc instances/find {title heading result} {
	embresult $result
	tag/ h1 {
	    tag* a Index href /index
	    put " | $title"
	}

	if {$heading ne ""} {
	    put $heading
	}

	tag/ table {
	    tag/ tr {
		tag th What
		tag th Name
		tag th Version
		tag th Platform
	    }
	    foreach ins [lsort -dict -index 1 \
			     [lsort -dict -index 2 \
				  [lsort -dict -index 3 \
				       $result]]] {
		# teapot::instance::split - not usable for extended item.
		foreach {t n v a _} $ins break
		set tx [string tolower $t]
		tag/ tr {
		    tag/ td {
			# Refer to all instances having this type
			tag* a $t href /$tx/list
		    }
		    tag/ td {
			# Refer to versions ...
			tag* a $n href /$tx/name/$n/list
		    }
		    tag/ td {
			# Refer to instances ...
			tag* a $v href /$tx/name/$n/ver/$v/list
		    }
		    tag/ td {
			# Refer to entity details ...
			tag* a $a href /$tx/name/$n/ver/$v/arch/$a/details
		    }
		}
	    }
	}
    }

    proc refs/full {title result} {
	log::debug "refs/full TIT ($title)"

	embresult $result
	tag h1 $title
	tag/ table {
	    tag/ tr {
		tag th What
		tag th Name
		tag th Version
		tag th Exact
		tag th Notes
	    }
	    foreach ref $result {
		log::debug "refs/full REF ($ref)"

		set n [lindex $ref 0]
		set v ""
		set e ""
		set t ""
		set notes {}
		foreach {opt val} [lrange $ref 1 end] {
		    switch -exact -- $opt {
			-version {set v $val}
			-exact   {set e [expr {$val?"yes":""}]}
			-is      {set t $v}
			default {
			    lappend notes $opt $val
			}
		    }
		}
		tag/ tr {
		    tag td $t
		    tag td $n
		    tag td $v
		    tag td $e
		    tag td $notes
		}
	    }
	}
    }

    proc clear {} {
	::variable buf ""
	return
    }
    proc put {text} {
	::variable buf
	append buf $text
	return
    }

    proc get {} {
	::variable buf
	return $buf
    }

    proc prolog {} {
	upvar 1 myheader myheader

	put <html><head>\n
	if {$myheader ne ""} {
	    put $myheader\n
	}
	put </head><body>\n
    }

    proc tag {tag text} {put "<$tag>$text</$tag>\n"}
    proc tag0 {tag} {put "</$tag>\n"}

    proc tag* {tag text args} {
	put "[tagkv $tag $args]$text</$tag>\n"
	return
    }

    proc tagkv {tag kv} {
	::variable buf
	append buf "<$tag"
	foreach {k v} $kv {put " ${k}=\"$v\""}
	put ">"
	return
    }

    proc tag/ {tag script args} {
	tagkv $tag $args
	put \n
	uplevel 1 $script
	put </$tag>\n
	return
    }

    proc tagjoin {list var itemscript joinscript} {
	if {![llength $list]} return

	upvar 1 $var item
	set item [lindex $list 0]
	uplevel 1 $itemscript

	if {[llength $list] < 2} return

	foreach item [lrange $list 1 end] {
	    uplevel 1 $joinscript
	    uplevel 1 $itemscript
	}
	return
    }


    proc embresult {text} {comment \[\[TPM\[\[$text\]\]MPT\]\]}
    proc comment {text} {put "<!-- $text -->\n"}

    proc Bad {request} {
	array set r $request
	set r(-content) "Bad Request\n[parray r]"
	return [array get r]
    }

    proc BadHtml {request} {
	array set r $request
	set r(-content) "<h1>Bad Request</h1>\n[parrayHtml r]"
	return [array get r]
    }

    proc parray {a {pattern *}} {
	upvar 1 $a array
	if {![array exists array]} {
	    error "\"$a\" isn't an array"
	}
	set maxl 0
	foreach name [array names array $pattern] {
	    if {[string length $name] > $maxl} {
		set maxl [string length $name]
	    }
	}
	set maxl [expr {$maxl + [string length $a] + 2}]
	set lines ""
	foreach name [lsort [array names array $pattern]] {
	    set nameString [format %s(%s) $a $name]
	    append lines [format "%-*s = %s" $maxl $nameString $array($name)]\n
	}
	return $lines
    }

    proc parrayHtml {a {pattern *}} {
	upvar 1 $a array
	if {![array exists array]} {
	    error "\"$a\" isn't an array"
	}
	set     lines ""
	lappend lines "<table>"
	lappend lines "<tr>$a<th></th> <th></th></tr>"

	foreach name [lsort [array names array $pattern]] {
	    lappend lines "<tr><td>$name</td> <td>$array($name)</td></tr>"
	}
	lappend lines "</table>"
	return [join $lines \n]
    }

    proc _segdecode {segment} {
	::variable urlMapD
	return [string map $urlMapD $segment]
    }

    proc _segencode {segment} {
	::variable urlMapE
	# do x-www-urlencoded character mapping
	# The spec says: "non-alphanumeric characters are replaced by '%HH'"
	# 1 leave alphanumerics characters alone
	# 2 Convert every other character to an array lookup
	# 3 Escape constructs that are "special" to the tcl parser
	# 4 "subst" the result, doing all the array substitutions
	# The above is done for path segments, not the path string.
	# The / separators are not touched.

	set alphanumeric	a-zA-Z0-9
	regsub -all \[^$alphanumeric\] $segment {$urlMapE(&)} segment
	regsub -all \n $segment {\\n} segment
	regsub -all \t $segment {\\t} segment
	regsub -all {[][{})\\]\)} $segment {\\&} segment
        set segment [subst $segment]
        return $segment
    }

    ##
    # ### ### ### ######### ######### #########
}

proc ::teapot::wserver::SETUP {} {
    ::variable patternmap    ; # list (list (pattern cmd argspec) ...)
    ::variable urlMapD
    ::variable urlMapE

    # Reference is transmitted fully, in encoded form, like is done
    # for the query part of a search.

    url find/all/@/@            findall {= 2} + {= 1} + ; # ref platforms => platforms ref
    url find/max/@/@            find    {= 2} + {= 1} + ; # ref platforms => platforms ref
    
    url index                   entities
    url keys                    keys     
    url search/@                search   {= 1} +

    url list                             list  {i 0}                   + ; # all
    url entity/name/@/list               list  {i 0} {@ 1}             + ; # name
    url entity/name/@/ver/@/list         list  {i 0} {@ 1} {@ 2}       + ; # version
    url entity/name/@/ver/@/arch/@/list  list  {i 0} {@ 1} {@ 2} {@ 3} + ; # instance

    url keys                             keys  {i 0}                   + ; # all
    url entity/name/@/keys               keys  {i 0} {@ 1}             + ; # name
    url entity/name/@/ver/@/keys         keys  {i 0} {@ 1} {@ 2}       + ; # version
    url entity/name/@/ver/@/arch/@/keys  keys  {i 0} {@ 1} {@ 2} {@ 3} + ; # instance

    url entity/name/@/meta                  meta  {i 0} {@ 1}                      + ; # name
    url entity/name/@/ver/@/meta            meta  {i 0} {@ 1} {@ 2}                + ; # version
    url entity/name/@/ver/@/arch/@/meta     meta  {i 0} {@ 1} {@ 2} {@ 3}          + ; # instance

    url entity/name/@/value/@               value  {= 2} + {i 0} {@ 1}             + ; # name
    url entity/name/@/ver/@/value/@         value  {= 3} + {i 0} {@ 1} {@ 2}       + ; # version
    url entity/name/@/ver/@/arch/@/value/@  value  {= 4} + {i 0} {@ 1} {@ 2} {@ 3} + ; # instance

    url entity/name/@/index                 versions      {= 1} +
    url entity/name/@/ver/@/index           instances     {r 1 2} +

    redir {}                          index
    redir entity                      index
    redir entity/name                 index
    redir entity/name/@               !/list
    redir entity/name/@/ver/@         !/list
    redir entity/name/@/ver/@/arch/@  !/list

    foreach e [teapot::entity::names] {
	set ex [list i $e]

	# Listspec argument ...

	url $e/list                         list           {i 1} $ex                   + ; # eall
	url $e/name/@/list                  list           {i 1} $ex {@ 1}             + ; # ename
	url $e/name/@/ver/@/list            list           {i 1} $ex {@ 1} {@ 2}       + ; # eversion
	url $e/name/@/ver/@/arch/@/list     list           {i 1} $ex {@ 1} {@ 2} {@ 3} + ; # einstance

	redir $e                    !/list
	redir $e/name               $e
	redir $e/name/@             !/list

	redir $e/name/@/ver/@            !/list
	redir $e/name/@/ver/@/arch/@     !/list

	url $e/keys                         keys           {i 1} $ex                   + ; # eall
	url $e/name/@/keys                  keys           {i 1} $ex {@ 1}             + ; # ename
	url $e/name/@/ver/@/keys            keys           {i 1} $ex {@ 1} {@ 2}       + ; # eversion
	url $e/name/@/ver/@/arch/@/keys     keys           {i 1} $ex {@ 1} {@ 2} {@ 3} + ; # einstance

	url $e/name/@/meta                  meta           {i 1} $ex {@ 1}             + ; # ename    
	url $e/name/@/ver/@/meta            meta           {i 1} $ex {@ 1} {@ 2}       + ; # eversion 
	url $e/name/@/ver/@/arch/@/meta     meta           {i 1} $ex {@ 1} {@ 2} {@ 3} + ; # einstance

	url $e/name/@/value/@               value  {= 2} + {i 1} $ex {@ 1}             + ; # ename    
	url $e/name/@/ver/@/value/@         value  {= 3} + {i 1} $ex {@ 1} {@ 2}       + ; # eversion 
	url $e/name/@/ver/@/arch/@/value/@  value  {= 4} + {i 1} $ex {@ 1} {@ 2} {@ 3} + ; # einstance

	# Instance argument

	url $e/name/@/ver/@/arch/@/file          Xchan         $ex {@ 1} {@ 2} {@ 3} + chan
	url $e/name/@/ver/@/arch/@/file.zip      Xchan         $ex {@ 1} {@ 2} {@ 3} + chan
	url $e/name/@/ver/@/arch/@/file.tm       Xchan         $ex {@ 1} {@ 2} {@ 3} + chan
	url $e/name/@/ver/@/arch/@/file.kit      Xchan         $ex {@ 1} {@ 2} {@ 3} + chan
	url $e/name/@/ver/@/arch/@/file.exe      Xchan         $ex {@ 1} {@ 2} {@ 3} + chan
	url $e/name/@/ver/@/arch/@/file.dat      Xchan         $ex {@ 1} {@ 2} {@ 3} + chan

	url $e/name/@/ver/@/arch/@/xfile         XchanX        $ex {@ 1} {@ 2} {@ 3} + file

	url $e/name/@/ver/@/arch/@/recommend     recommend     $ex {@ 1} {@ 2} {@ 3} +
	url $e/name/@/ver/@/arch/@/require       require       $ex {@ 1} {@ 2} {@ 3} +

	# Instance details

	url $e/name/@/ver/@/arch/@/details       Xdetails $ex {@ 1} {@ 2} {@ 3} +
    }

    # --- --- --- --------- --------- #########

    set alphanumeric {[a-zA-Z0-9]}
    for {::set i 1} {$i <= 256} {::incr i} {
	set c [format %c $i]
	if {![string match $alphanumeric $c]} {
	    set hex %[format %.2x $i]
	    set urlMapE($c) $hex
	    lappend urlMapD $hex $c

	    # Accept uppercase hex input as well (%7b and %7B are the same)
	    set hex [string toupper $hex]
	    lappend urlMapD $hex $c
	}
    }

    return
}

proc ::teapot::wserver::url {pattern cmd args} {
    ::variable patternmap
    lappend    patternmap [string map {@ {([^/]*)}} $pattern] $cmd $args
    return
}

proc ::teapot::wserver::redir {from to} {
    ::variable redirmap
    lappend    redirmap [string map {@ {([^/]*)}} $from] $to
    return
}

namespace eval ::teapot::wserver {
    ::variable patternmap {}
    # list (list (pattern cmd argspec) ...)

    ::variable redirmap {}
    # list (pattern to)

    ::variable urlMap {}

}

# ### ### ### ######### ######### #########
## Ready

::teapot::wserver::SETUP
return
