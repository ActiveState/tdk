# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_misc.tcl --
# -*- tcl -*-
#
#	Miscellaneous state information
#
# Copyright (c) 2002-2007 ActiveState Software Inc.

#
# RCS: @(#) $Id: tclapp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

package require fileutil
package require ico 1
package require stringfileinfo

package require tclapp::files
package require tclapp::fres
package require tclapp::msgs

package require repository::prefix
package require teapot::instance
package require teapot::listspec

namespace eval ::tclapp::misc {
    namespace import ::tclapp::msgs::get
    rename                           get mget

    variable traceft {}
}

# ### ### ### ######### ######### #########
# ### ### ### ######### ######### #########

# A copy of fileutil::fileType which has been extended to trace its
# operation in detail, to put into messages when an unexpected error
# occurs to aid the diagnosis

# ### ### ### ######### ######### #########

proc ::fileutil::fileType {filename} {
    ;## existence test

    variable ::tclapp::misc::traceft {}
    lappend traceft "fileType ($filename)"
    lappend traceft "CWD      ([pwd])"

    if { ! [ file exists $filename ] } {
        set err "file not found: '$filename'"
        return -code error $err
    }
    lappend traceft \texists
    ;## directory test
    if { [ file isdirectory $filename ] } {
        set type directory
        if { ! [ catch {file readlink $filename} msg] } {
            lappend type link
        }
	lappend traceft readlink=$msg
        return $type
    }
    lappend traceft \tnot-a-directory
    ;## empty file test
    if { ! [set _ [ file size $filename ]] } {
        set type empty
        if { ! [ catch {file readlink $filename} msg] } {
            lappend type link
        }
	lappend traceft readlink=$msg
        return $type
    }
    lappend traceft \tnot-empty<${_}>

    set bin_rx {[\x00-\x08\x0b\x0e-\x1f]}

    if { [ catch {
        set fid [ open $filename r ]
        fconfigure $fid -translation binary
        fconfigure $fid -buffersize 1024
        fconfigure $fid -buffering full
        set test [ read $fid 1024 ]
        ::close $fid
    } err ] } {
        catch { ::close $fid }
        return -code error "::fileutil::fileType: $err"
    }

    lappend traceft \t1st-1K-read

    if { [ regexp $bin_rx $test ] } {
	lappend traceft \tmatches-${bin_rx}-=>binary
        set type binary
        set binary 1
    } else {
	lappend traceft \tnot-matching-${bin_rx}-=>text
        set type text
        set binary 0
    }

    # SF Tcllib bug [795585]. Allowing whitespace between #!
    # and path of script interpreter

    set metakit 0

    if { [ regexp {^\#\!\s*(\S+)} $test -> terp ] } {
        lappend type script $terp
    } elseif {[regexp "\\\[manpage_begin " $test]} {
	lappend type doctools
    } elseif {[regexp "\\\[toc_begin " $test]} {
	lappend type doctoc
    } elseif {[regexp "\\\[index_begin " $test]} {
	lappend type docidx
    } elseif { $binary && [ regexp {^[\x7F]ELF} $test ] } {
        lappend type executable elf
    } elseif { $binary && [string match "MZ*" $test] } {
        if { [scan [string index $test 24] %c] < 64 } {
            lappend type executable dos
        } else {
            binary scan [string range $test 60 61] s next
            set sig [string range $test $next [expr {$next + 1}]]
            if { $sig == "NE" || $sig == "PE" } {
                lappend type executable [string tolower $sig]
            } else {
                lappend type executable dos
            }
        }
    } elseif { $binary && [string match "BZh91AY\&SY*" $test] } {
        lappend type compressed bzip
    } elseif { $binary && [string match "\x1f\x8b*" $test] } {
        lappend type compressed gzip
    } elseif { $binary && [string range $test 257 262] == "ustar\x00" } {
        lappend type compressed tar
    } elseif { $binary && [string match "\x50\x4b\x03\x04*" $test] } {
        lappend type compressed zip
    } elseif { $binary && [string match "GIF*" $test] } {
        lappend type graphic gif
    } elseif { $binary && [string match "icns*" $test] } {
        lappend type graphic icns bigendian
    } elseif { $binary && [string match "snci*" $test] } {
        lappend type graphic icns smallendian
    } elseif { $binary && [string match "\x89PNG*" $test] } {
        lappend type graphic png
    } elseif { $binary && [string match "\xFF\xD8\xFF*" $test] } {
        binary scan $test x3H2x2a5 marker txt
        if { $marker == "e0" && $txt == "JFIF\x00" } {
            lappend type graphic jpeg jfif
        } elseif { $marker == "e1" && $txt == "Exif\x00" } {
            lappend type graphic jpeg exif
        }
    } elseif { $binary && [string match "MM\x00\**" $test] } {
        lappend type graphic tiff
    } elseif { $binary && [string match "BM*" $test] && [string range $test 6 9] == "\x00\x00\x00\x00" } {
        lappend type graphic bitmap
    } elseif { $binary && [string match "\%PDF\-*" $test] } {
        lappend type pdf
    } elseif { ! $binary && [string match -nocase "*\<html\>*" $test] } {
        lappend type html
    } elseif { [string match "\%\!PS\-*" $test] } {
       lappend type ps
       if { [string match "* EPSF\-*" $test] } {
           lappend type eps
       }
    } elseif { [string match -nocase "*\<\?xml*" $test] } {
        lappend type xml
        if { [ regexp -nocase {\<\!DOCTYPE\s+(\S+)} $test -> doctype ] } {
            lappend type $doctype
        }
    } elseif { [string match {*BEGIN PGP MESSAGE*} $test] } {
        lappend type message pgp
    } elseif { $binary && [string match {IGWD*} $test] } {
        lappend type gravity_wave_data_frame
    } elseif {[string match "JL\x1a\x00*" $test] && ([file size $filename] >= 27)} {
	lappend type metakit smallendian
	set metakit 1
    } elseif {[string match "LJ\x1a\x00*" $test] && ([file size $filename] >= 27)} {
	lappend type metakit bigendian
	set metakit 1
    } elseif { $binary && [string match "RIFF*" $test] && [string range $test 8 11] == "WAVE" } {
        lappend type audio wave
    } elseif { $binary && [string match "ID3*" $test] } {
        lappend type audio mpeg
    } elseif { $binary && [binary scan $test S tmp] && [expr {$tmp & 0xFFE0}] == 65504 } {
        lappend type audio mpeg
    }

    # Additional checks of file contents at the end of the file,
    # possibly pointing into the middle too (attached metakit,
    # attached zip).

    ## Metakit File format: http://www.equi4.com/metakit/metakit-ff.html
    ## Metakit database attached ? ##

    lappend traceft \tmetakit=$metakit

    if {!$metakit && ([file size $filename] >= 27)} {
	lappend traceft \tchecking-for-attached-metakit

	# The offsets in the footer are in always bigendian format

	if { [ catch {
	    set fid [ open $filename r ]
	    fconfigure $fid -translation binary
	    fconfigure $fid -buffersize 1024
	    fconfigure $fid -buffering full
	    seek $fid -16 end
	    set test [ read $fid 16 ]
	    ::close $fid
	} err ] } {
	    catch { ::close $fid }
	    return -code error "::fileutil::fileType: $err"
	}

	binary scan $test H32 hex
	lappend traceft \tlast-16-bytes-read=|[string range $hex 0 7]|[string range $hex 8 15]|[string range $hex 16 23]|[string range $hex 24 end]|
	lappend traceft \t..................=|________|__offset|________|________|
	binary scan $test IIII __ hdroffset __ __

	lappend traceft \traw-hdr-offset=$hdroffset

	set hdroffset [expr {[file size $filename] - 16 - $hdroffset}]

	lappend traceft \tactual-hdr-offset=$hdroffset

	# Further checks iff the offset is actually inside the file.

	if {($hdroffset >= 0) && ($hdroffset < [file size $filename])} {
	    # Seek to the specified location and try to match a metakit header
	    # at this location.

	    lappend traceft \tseek-to-hdr

	    if { [ catch {
		set         fid [ open $filename r ]
		fconfigure $fid -translation binary
		fconfigure $fid -buffersize 1024
		fconfigure $fid -buffering full
		seek       $fid $hdroffset start
		set test [ read $fid 16 ]
		::close $fid
	    } err ] } {
		catch { ::close $fid }
		return -code error "::fileutil::fileType: $err"
	    }

	    binary scan $test H32 hex
	    lappend traceft \thdr-16-bytes-read=$hex
	    lappend traceft \t.................=^^^^^^^^........................

	    if {[string match "JL\x1a\x00*" $test]} {
		lappend traceft \tlittle-endian-metakit

		lappend type attached metakit smallendian
		set metakit 1
	    } elseif {[string match "LJ\x1a\x00*" $test]} {
		lappend traceft \tbig-endian-metakit

		lappend type attached metakit bigendian
		set metakit 1
	    } else {
		lappend traceft \tno-match
	    }
	} else {
	    lappend traceft \thdr-out-of-bounds-0...[file size $filename]
	}
    }

    ## Zip File Format: http://zziplib.sourceforge.net/zzip-parse.html
    ## http://www.pkware.com/products/enterprise/white_papers/appnote.html


    ;## lastly, is it a link?
    if { ! [ catch {file readlink $filename} msg] } {
        lappend type link
    }
    lappend traceft readlink=$msg

    return $type
}


# ### ### ### ######### ######### #########
# ### ### ### ######### ######### #########

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::printHelp --
#
#	Set/return printHelp
#	
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::printHelp {} {
    variable printHelp 1
    return
}

proc ::tclapp::misc::printHelp? {} {
    variable printHelp
    return  $printHelp
}

namespace eval ::tclapp::misc {
    # Boolean flag. Control printing of a usage/help message.
    # Defaults to false, no printing.

    variable printHelp 0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::logfile --
#
#	Set/return logfile
#
# Arguments:
#	single	- Path. If empty throw an error
#
# Results:
#	The current setting.

proc ::tclapp::misc::logfile {path ev} {
    variable logfile
    variable logchan
    upvar 1 $ev errors

    if {$path eq ""} {
	lappend errors [mget 504_EMPTY_LOGFILE]
	return 0
    }

    set logfile $path

    # Now we make sure that any previous -log option is superceded by
    # the current settings.

    set newchan [open $logfile w]
    log::lvChannelForall $newchan

    if {$logchan ne ""} {
	if {$logchan ne "stdout"} {
	    close $logchan
	}
	set logchan ""
    }
    set logchan $newchan

    return 1
}

proc ::tclapp::misc::logfile? {} {
    variable logfile
    return  $logfile
}

namespace eval ::tclapp::misc {

    # Path of the log-file to use in command line mode.
    # Default is empty path, logging to stdout.

    variable logfile {}

    # Handle of the channel we are logging to. Required so that we can
    # close the channel in case of changes.

    variable logchan {}
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::debug --
#
#	Set/return debug
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::debug {} {
    variable debug 1
    return
}

proc ::tclapp::misc::debug? {} {
    variable debug
    return  $debug
}

namespace eval ::tclapp::misc {
    # Boolean flag. Controls if internal debugging is active or not.
    # Default to false, no internal debugging.

    variable debug 0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::specials --
#
#	Set/return specials
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::nospecials {} {
    variable specials 0
    return
}

proc ::tclapp::misc::specials? {} {
    variable specials
    return  $specials
}

namespace eval ::tclapp::misc {
    # Boolean flag. Controls the generation of the main.tcl
    # entrypoint. Default is true, to generate this file.

    variable specials 1
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::nocompress --
#
#	Set/return nocompress
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::nocompress {} {
    variable nocompress 1
    return
}

proc ::tclapp::misc::nocompress? {} {
    variable nocompress
    return  $nocompress
}

namespace eval ::tclapp::misc {
    # Boolean flag. Controls compression of files by the VFS during
    # wrapping. Defaults to false, perform compression.

    variable nocompress 0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::compile --
#
#	Set/return compile flag.
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::compile {} {
    variable compile 1
    return
}

proc ::tclapp::misc::compile? {} {
    variable compile
    return  $compile
}

namespace eval ::tclapp::misc {

    # Boolean flag. Controls usage of the bytecode compiler. The
    # default is false, to not compile Tcl files. Each setting (copile
    # y/n) can be overridden on a per-file basis. Relevant only to
    # files with the extension .tcl (except for 'pkgIndex.tcl',
    # i.e. package indices).

    variable compile 0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::verbose --
#
#	Set/return verbose
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::verbose {} {
    variable verbose 1
    return
}

proc ::tclapp::misc::verbose? {} {
    variable verbose
    return  $verbose
}

namespace eval ::tclapp::misc {
    # Boolean flag. Controls verbose output during the wrapping
    # process. Defaults to false, no verbose output.

    variable verbose 0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::code --
#
#	Set/return code fragment
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::code {code} {
    variable code_fragments
    if {$code ne ""} {
	lappend code_fragments $code
    }
    return
}

proc ::tclapp::misc::code? {} {
    variable code_fragments
    return  $code_fragments
}

namespace eval ::tclapp::misc {
    # Additional code fragments to be run before the application is
    # started (Added to the special main file).

    variable code_fragments {}
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::postcode --
#
#	Set/return postcode fragment
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::postcode {code} {
    variable postcode_fragments
    if {$code ne ""} {
	lappend postcode_fragments $code
    }
    return
}

proc ::tclapp::misc::postcode? {} {
    variable postcode_fragments
    return  $postcode_fragments
}

namespace eval ::tclapp::misc {
    # Additional code fragments to be run after the application is
    # started (Added to the special main file).

    variable postcode_fragments {}
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::args --
#
#	Set/return arg_list fragment
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::args {argument} {
    variable argument_list
    if {$argument ne ""} {
	set argument_list $argument
    }
    return
}

proc ::tclapp::misc::args? {} {
    variable argument_list
    return  $argument_list
}

namespace eval ::tclapp::misc {
    # The wrapped application's argument list (Pre-defined arguments).

    variable argument_list ""
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::icon --
#
#	Set/return the optional custom icon
#
# Arguments:
#	single	- Name of the icon file to use for starpack.
#	none	- Return the name of the icon file
#
# Results:
#	The name of the current custom icon file.

proc ::tclapp::misc::icon {path} {
    # If an icon cannot be used the system will generate warnings
    # later, do not treat this as an error. This allows for better
    # portability of project files. This also implies that we do not
    # have to perform additional checking here.

    variable iconfile $path
    return
}

proc ::tclapp::misc::icon? {} {
    variable iconfile
    return  $iconfile
}

namespace eval ::tclapp::misc {
    # The path to a custom icon file. The default empty string signals
    # that no icon file has been chosen.

    variable iconfile {}
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::stringinfo --
#
#	Set/return the optional custom string information
#
# Arguments:
#	single	- Name of the icon file to use for starpack.
#	none	- Return the name of the icon file
#
# Results:
#	The current custom string information.

proc ::tclapp::misc::stringinfo {si} {
    # If string info cannot be used we will generate warnings later,
    # but do not treat this as an error. This allows for better
    # portability of project files. This also implies that we do not
    # have to perform additional checking here.

    variable stringinfo $si
    return
}

proc ::tclapp::misc::stringinfo? {} {
    variable stringinfo
    return  $stringinfo
}

namespace eval ::tclapp::misc {
    # Dictionary of custom string information, for insertion into
    # a windows basekit.

    variable stringinfo {}
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::metadata --
#
#	Set/return the teapot metadata information
#
# Arguments:
#
# Results:
#	The current teapot meta data.

proc ::tclapp::misc::metadata {si} {
    # If metadata cannot be used we will generate warnings later,
    # but do not treat this as an error. This allows for better
    # portability of project files. This also implies that we do not
    # have to perform additional checking here.

    variable metadata
    foreach item $si {lappend metadata $item}
    return
}

proc ::tclapp::misc::metadata? {} {
    variable metadata
    return  $metadata
}

namespace eval ::tclapp::misc {
    # Dictionary of teapot metadata.

    variable metadata {}
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::iplist --
#
#	Set/return the OS X meta data
#
# Arguments:
#	single	- Name of the icon file to use for starpack.
#	none	- Return the name of the icon file
#
# Results:
#	The current custom string information.

proc ::tclapp::misc::iplist {si} {
    # If string info cannot be used we will generate warnings later,
    # but do not treat this as an error. This allows for better
    # portability of project files. This also implies that we do not
    # have to perform additional checking here.

    variable iplist $si
    return
}

proc ::tclapp::misc::iplist? {} {
    variable iplist
    return  $iplist
}

namespace eval ::tclapp::misc {
    # Dictionary of OS X meta data, for insertion into an OS X .app
    # bundle.

    variable iplist {}
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::prefix --
#
#	Set/return the optional wrap prefix (basekit)
#
# Arguments:
#	single	- Name of the prefix to use for starpack.
#	none	- Return the name of the prefix.
#
# Results:
#	The name of the current prefix file.

proc ::tclapp::misc::makeTeapotPrefix {n v a} {
    return "teapot:$n/$v/$a"
}

proc ::tclapp::misc::prefixIsTeapotPrefix {} {
    variable pathPrefix
    return [isTeapotPrefix $pathPrefix]
}

proc ::tclapp::misc::isTeapotPrefix {path} {
    return [string match {teapot:*} $path]
}

proc ::tclapp::misc::prefix?nva {} {
    variable pathPrefix
    # teapot: = 7 characters
    return [split [string range $pathPrefix 7 end] /]
}

proc ::tclapp::misc::splitTeapotPrefix {path} {
    return [split [string range $path 7 end] /]
}

#
# int.doc: format of prefix reference in teapot
# =>       teapot:<NAME>/<VERSION>/<ARCH>
#

proc ::tclapp::misc::prefixtemp {bool} {
    variable pathTemp $bool
    return
}

proc ::tclapp::misc::prefixtemp? {} {
    variable pathTemp
    return  $pathTemp
}

proc ::tclapp::misc::prefix {path ev} {
    variable pathPrefix
    variable pathInterpreter
    variable fsmode
    variable merge

    ::log::log debug "tclapp::misc::prefix = <$path>"

    upvar 1 $ev errors

    # If specified the file has to exist, and has to be suitable for
    # wrapping.

    if {[isTeapotPrefix $path]} {
	# The prefix-'file' is actually a reference into the
	# configured archives, an application instance in the form
	# teapot:name/version/arch. We accept this data as is, for
	# now. When the archives to use become known we convert the
	# reference into an actual path, possibly to a temp file, and
	# check the validity of the choice again. See
	# 'tclapp::pkg::setArchives' for that.

	foreach {n v a} [splitTeapotPrefix $path] break

	if {($n eq "") || ($v eq "") || ($a eq "") || [catch {
	    set instance [teapot::instance::cons application $n $v $a]
	}]} {
	    lappend errors \
		[format [mget 39_INVALID_INPUT_EXECUTABLE_TEAPOT_SYNTAX] \
		     $path]
	    return 0
	}

	set pathPrefix $path
	return 1
    }

    if {($path == {}) || ![file isfile $path]} {
	lappend errors \
	    [format [mget 43_EXECUTABLE_DOES_NOT_EXIST] \
		 $path]
	return 0
    } elseif {![IsWrapCore $path emsg]} {
	lappend errors $emsg
	return 0
    } else {

	# If an -interpreter is set we have to check the prefix that
	# an interpreter can be set into it. If no prefix is set the
	# internal one is used (empty.kit) and that has the necessary
	# stuff in it, so no error message for that case.
	    
	if {
	    ($pathInterpreter != {}) &&
	    ![HasInterp $pathPrefix emsg]
	} {
	    lappend errors $emsg
	    return 0
	}

	# If a -fsmode is set we have to check the prefix that an
	# fsmode can be set into it. If no prefix is set the internal
	# one is used (empty.kit) and that has the necessary stuff in
	# it, so no error message for that case.
	    
	if {
	    ($fsmode != {}) &&
	    ![HasFSMode $pathPrefix emsg]
	} {
	    lappend errors $emsg
	    return 0
	}
    }

    # If -merge is set a prefix is not allowed.

    if {$merge} {
	lappend errors \
	    [mget 47_EXECUTABLE_NOT_ALLOWED]
	return 0
    }

    set pathPrefix $path
    return 1
}

proc ::tclapp::misc::prefix? {} {
    variable pathPrefix
    return  $pathPrefix
}

proc ::tclapp::misc::prefix/validate {ev} {
    variable pathPrefix
    variable pathWrapResult

    upvar 1 $ev errors

    # Check if a -prefix was specified. If so, check further that the
    # specified file exists. If so, check further that it is not the
    # same name as the output executable (wrapping in-place is
    # currently not supported).

    # BUG !! Normalize here (incl. last path segment), to make sure
    # that we are not confused by symlinks of different names pointing
    # to the same location!

    if {
	($pathPrefix ne "") &&
	($pathPrefix eq $pathWrapResult)
    } {
	lappend errors \
	    [format [mget 41_EXECUTABLE_SAME_AS_OUTPUT] \
		 $pathPrefix $pathWrapResult]
    }
    return
}

namespace eval ::tclapp::misc {
    # Path of the file used as prefix to the wrapping. Usually an
    # executable (basekit), may be a starkit, or starpack. Also known
    # as the 'wrapping core'. SDX calls it the 'runtime'. Default is
    # empty string, signaling that no prefix was defined. That is
    # allowed too, causing the engine to use a default prefix which
    # will make the wrap result a starkit.

    variable pathPrefix ""

    # Bool flag. Set if and only if the pathPrefix refers to a
    # temporary file we have to delete after use.
    variable pathTemp   0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::interpreter --
#
#	Set/return the optional interpreter executable
#
# Arguments:
#	single	- Name of the prefix to use for starpack.
#	none	- Return the name of the prefix.
#
# Results:
#	The name of the current interpreter file.

proc ::tclapp::misc::interpreter {path ev} {
    variable pathInterpreter
    variable pathPrefix
    variable merge

    upvar 1 $ev errors

    # If specified then the file has to exist.

    if {$path == {}} {
	lappend errors \
	    [format [mget 49_INTERP_DOES_NOT_EXIST] $path]
	return 0
    } else {
	# If a -prefix (!) is set we have to check it that an
	# interpreter can be set into it. If no prefix is set the
	# internal prefix is used (empty.kit) and we know that that
	# one has the necessary stuff in it, so no error message for
	# that case.
	    
	if {
	    ($pathPrefix ne "") &&
	    ![HasInterp $pathPrefix emsg]
	} {
	    lappend errors $emsg
	    return 0
	}
    }

    # If -merge is set an interpreter is not allowed.
    if {$merge} {
	lappend errors [mget 50_INTERP_NOT_ALLOWED]
	return 0
    }
    
    set pathInterpreter $path
    return 1
}

proc ::tclapp::misc::interpreter? {} {
    variable pathInterpreter
    return  $pathInterpreter
}

namespace eval ::tclapp::misc {
    # The path to the executable we wish to use to run the
    # starkit. Can be relative. The default is an empty string,
    # signaling that no special interpreter is required.

    variable pathInterpreter ""
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::fsmode --
#
#	Set/return the optional fsmode for the runtime
#
# Arguments:
#	single	- Name of the mode to use for starpack.
#	none	- Return the mode of the prefix.
#
# Results:
#	The name of the current interpreter file.

proc ::tclapp::misc::fsmode {mode ev} {
    variable fsmode
    variable pathPrefix
    variable merge
    upvar 1 $ev errors

    # If specified only two modes are allowed.

    switch -exact -- $mode {
	transparent   {set mode -readonly}
	writable      {set mode -nocommit}
	default {
	    lappend errors [format [mget 54_FSMODE_ILEGAL] $mode]
	    return 0
	}
    }

    # If a -prefix (!) is set we have to check it that an fsmode can
    # be set into it. If no prefix is set the internal prefix is used
    # (empty.kit) and we know that that one has the necessary stuff in
    # it, so no error message for that case.
	    
    if {
	($pathPrefix != {}) &&
	![HasFSMode $pathPrefix emsg]
    } {
	lappend errors $emsg
	return 0
    }

    # If -merge is set an fsmode is not allowed.
    if {$merge} {
	lappend errors [mget 53_FSMODE_NOT_ALLOWED]
	return 0
    }

    set fsmode $mode
    return 1
}

proc ::tclapp::misc::fsmode? {} {
    variable fsmode
    return  $fsmode
}

namespace eval ::tclapp::misc {
    # The filesystem mode to use when the generated wrapped
    # application mounts itself at runtime. This determines if the
    # application can write into itself or not.

    variable fsmode ""
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::osxapp --
#
#	Set/return osxapp flag for output file.
#
# Arguments:
#
# Results:
#	None.

proc ::tclapp::misc::osxapp {bool} {
    variable pathWrapResultOSX $bool
    return
}

proc ::tclapp::misc::osxapp? {} {
    variable pathWrapResultOSX
    return  $pathWrapResultOSX
}

namespace eval ::tclapp::misc {
    # A boolean flag indicating if the result is a OSX .app bundle
    # (true) or not (false). The latter is the default.

    variable pathWrapResultOSX 0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::output --
#
#	Set/return output file.
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::output {path} {
    variable pathWrapResult $path
    return
}

proc ::tclapp::misc::output? {} {
    variable pathWrapResult
    return  $pathWrapResult
}

proc ::tclapp::misc::BadOutput {} {
    variable pathWrapResult
    upvar 1 errors errors

    lappend errors \
	[format [mget 46_OUTPUT_DOES_NOT_EXIST] $pathWrapResult]
    return -code return
}

proc ::tclapp::misc::output/validate {ev} {
    global tcl_platform
    variable pathWrapResult
    variable pathWrapResultOSX
    variable pathPrefix
    variable merge

    upvar 1 $ev errors

    if {$merge} {
	# Cannot use a default, has to exist. If OSXapp is active the
	# main path has to be a directory (handle both with and
	# without .app), and the executable in a specific place.

	if {$pathWrapResult eq ""}                                 BadOutput
	if {!$pathWrapResultOSX && ![file isfile $pathWrapResult]} BadOutput

	if {$pathWrapResultOSX} {
	    if {[file extension [set dir $pathWrapResult]] eq ".app"} {
		if {![file isdirectory $pathWrapResult]} BadOutput
	    } else {
		if {
		    ![file isdirectory [set dir ${pathWrapResult}.app]] &&
		    ![file isdirectory [set dir $pathWrapResult]]
		} BadOutput
	    }
	    set dir [file join $dir Contents MacOS]
	    set pat [file rootname [file tail $pathWrapResult]]*

	    set exelist [glob -nocomplain -directory $dir $pat]

	    if {[llength $exelist] != 1} BadOutput

	    set pathWrapResult [lindex $exelist 0]
	    return
	}

	# Fall through of old, only if !OSX, retains existing behaviour
    }

    # If no output executable name was selected, take on the default.

    if {$pathWrapResult eq ""} {
        set pathWrapResult tclapp-out
    }

    # Bugzilla 26006.
    # If the user did not specify an extension, then consider two
    # cases. One: A -prefix file was specified. Two: There is no
    # -prefix.
    #
    # Ad 1) Take the extension of the -prefix file and slap it on to
    #       the output file. If the -prefix has no extension do
    #       nothing.
    #
    # Ad 2) On windows, and only there, add a .tcl extension.
    #
    # If the user did specify an extension we take things as they are.

    if {$pathWrapResultOSX} {
	set exe [file tail $pathWrapResult]
	if {[file extension $exe] eq ".app"} {
	    set exe [file rootname $exe]
	} else {
	    append pathWrapResult .app
	}
	if {$pathPrefix ne ""} {
	    if {![NoSensibleExtension $pathPrefix]} {
		append exe \
		    [file extension $pathPrefix]
	    }
	} elseif {$tcl_platform(platform) eq "windows"} {
	    append exe .tcl
	}

	set pathWrapResult [file join $pathWrapResult Contents MacOS $exe]

    } elseif {[NoExtension $pathWrapResult]} {
	log::log debug "output/validate PathPrefix = $pathPrefix"

	if {$pathPrefix ne ""} {
	    if {![NoSensibleExtension $pathPrefix]} {
		append pathWrapResult \
			[file extension $pathPrefix]
	    } elseif {[isTeapotPrefix $pathPrefix]} {
		# Bug 82992: When we have a teapot reference use .exe
		# as the extension for a windows basekit like it would
		# have, if it were stored locally, on disk.
		foreach {n v a} [prefix?nva] break
		if {[string match win32-* $a]} {
		    append pathWrapResult .exe
		}
	    }
	} elseif {$tcl_platform(platform) eq "windows"} {
	    append pathWrapResult .tcl
	}
    }

    return
}

proc ::tclapp::misc::NoExtension {fname} {
    set e [file extension $fname]
    return [expr { $e eq "" }]
}

proc ::tclapp::misc::NoSensibleExtension {fname} {
    set e [file extension $fname]
    # No extension if there really is no extension, or if the extension is not sensible.
    return [expr {
		  ($e eq "") || ([lsearch -exact {.tcl .kit .exe .tm} $e] < 0)
	      }]
}

namespace eval ::tclapp::misc {
    # The path of the wrap result, i.e. where to place the wrap result
    # after wrapping has completed. The empty string signals that it
    # has not been defined. It is an error if, after processing the
    # command line, -merge is active and this condition persists.

    variable pathWrapResult ""
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::merge --
#
#	Set/return merge
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::merge {ev} {
    variable merge
    variable pathPrefix
    upvar 1 $ev errors

    # If a prefix is set merging is not possible.

    if {$pathPrefix ne ""} {
	lappend errors [mget 48_MERGE_NOT_ALLOWED]
	return 0
    }
    set merge 1
    return 1
}

proc ::tclapp::misc::merge? {} {
    variable merge
    return  $merge
}

namespace eval ::tclapp::misc {
    # Boolean flag. Set to true if the system is asked to merge the
    # files to wrap into an existing output executable. Default is
    # false.

    variable merge 0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::app --
#
#	Set/return application package
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::app {name} {
    variable app_package $name

    # Force general anchor
    ::tclapp::fres::anchor= ""
    return
}

proc ::tclapp::misc::app? {} {
    variable app_package
    return  $app_package
}

namespace eval ::tclapp::misc {
    # Name of the application package, if any.
    variable app_package ""
}

#
# ::tclapp::misc::app-startup --
#
#	Return startup derived name of application package
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::app-start {} {
    variable startup_fileName

    return \
	    [string map {{ } _} \
	    [file rootname \
	    [file tail $startup_fileName]]]
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::startup --
#
#	Set/return startup file
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::startup {name explicit ev} {
    variable startup_fileName
    variable app_package
    upvar 1 $ev errors

    log::log debug "misc::startup \{$name\} $explicit"

    if {$app_package != {}} {
	# Ignore implicit definitions.
	if {!$explicit} return

	# May not specify -startup if -app is present.
	lappend errors \
	    [mget 91_STARTUPSCRIPT_NOT_ALLOWED]
	return
    }
    if {($startup_fileName == {}) || $explicit} {
	set startup_fileName $name
    }
    return
}

proc ::tclapp::misc::startup? {} {
    variable startup_fileName
    return  $startup_fileName
}

namespace eval ::tclapp::misc {
    # The startup file as specified by the user (via -startup),
    # or implicitly as the first file. Ignored if a package
    # is explicitly defined as application (package).

    variable startup_fileName ""
}

#
# ::tclapp::misc::reset --
#
#	Reset the state
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::tclapp::misc::reset {} {
    foreach {var value} {
	app_package       ""
	argument_list     ""
	code_fragments    {}	
	compile           0
	compileForTcl     ""
	debug             0
	forceExternalCompile 0
	fsmode            ""
	iconfile          ""
	iplist            ""
	merge             0
	metadata          ""
	nocompress        0
	pathInterpreter   ""
	pathPrefix        ""
	pathTemp          0
	pathWrapResult    ""
	pathWrapResultOSX 0
	postcode_fragments {}	
	printHelp         0
	providedp         1
	specials          1
	startup_fileName  ""
	stringinfo        ""
	verbose           0
    } {
	variable $var
	set $var $value
    }

    return
}

#
# ::tclapp::misc::validate --
#
#	This routine performs some sanity checks on all the variables in the
#	namespace to ensure the processing will go as error-free as posible.
#
# Arguments
#	None.
#
# Results
#	A list of errors is compiled.

proc ::tclapp::misc::validate {ev} {
    upvar 1 $ev errors

    variable app_package 
    variable startup_fileName
    variable merge
    variable pathPrefix
    variable pathWrapResult

    # Check for a minimum set of arguments and print a usage statement
    # if not valid. Note: Having -merge implies that -startup is not
    # needed, and if present, ignored.

    if {!$merge} {
	if {($app_package == {}) && ($startup_fileName == {})} {
	    lappend errors [mget 1_NO_STARTUP_FILE_SPECIFIED]
	}

	if {($app_package == {}) && ![::tclapp::files::exist $startup_fileName]} {
	    lappend errors \
		[format [mget 90_STARTUPSCRIPT_NOT_WRAPPED] \
		     $startup_fileName]
	}
    }

    # Check input, output and merge.
    return
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::IsWrapCore --
#
#	This routine performs some sanity checks on all the variables in the
#	namespace to ensure the processing will go as error-free as posible.
#
# Arguments
#	None.
#
# Results
#	An exception is raised with a list of errors.

proc ::tclapp::misc::IsWrapCore {file emsgvar {fshown {}}} {
    upvar 1 $emsgvar errormsg
    set ok 1

    log::log debug "misc::IsWrapCore $file ($fshown)"

    if {$fshown eq ""} { set fshown $file }

    # Check that the executable contains a metakit FS we can write into.
    # Note that the file does not have to be executable, nor is
    # a starkit prefix required, nor is tclkit prefix required.
    #
    # It is perfectly valid to use tclapp to insert files into
    # a non-executable metakit based filesystem file.

    set types [fileutil::fileType $file]
    log::log debug "\tFile types = ([join $types ", "])"

    # Dump trace...
    foreach l $::tclapp::misc::traceft {
	log::log debug FT\t$l
    }
    log::log debug "FT result = ([join $types ", "])"

    if {[lsearch -exact $types metakit] < 0} {
	log::log debug "\tMetakit signature not found"
	set errormsg "[format [mget 44_INVALID_INPUT_EXECUTABLE] $fshown]"
	set ok 0
    }
    log::log debug "\t$ok"
    return $ok
}

#
# ::tclapp::misc::HasInterp --
#
#	This command checks that a prefix has the contents
#	required to support -interpreter.
#
# Arguments
#	file	- Path of file to check
#	emsgvar	- Name of variable to store error messages into.
#
# Results
#	A boolean value. True <=> Ok, else not.

proc ::tclapp::misc::HasInterp {file emsgvar {fshown {}}} {
    upvar 1 $emsgvar errormsg
    set ok 1

    log::log debug "misc::HasInterp $file ($fshown)"

    if {$fshown eq ""} { set fshown $file }

    set f [open $file r]
    set header [read $f 200]
    close $f
    set  loc [string first @__interpreter__@ $header]
    if {$loc < 0} {
	log::log debug "Missing @__interpreter__@ in \{$header\}  "

	set ok 0
	set errormsg "[format [mget 51_INVALID_INTERP_EXECUTABLE] $fshown]"
    }
    log::log debug "\t$ok"
    return $ok
}

#
# ::tclapp::misc::HasFSMode --
#
#	This command checks that a prefix has the contents
#	required to support -fsmode
#
# Arguments
#	file	- Path of file to check
#	emsgvar	- Name of variable to store error messages into.
#
# Results
#	A boolean value. True <=> Ok, else not.

proc ::tclapp::misc::HasFSMode {file emsgvar {fshown {}}} {
    upvar 1 $emsgvar errormsg
    set ok 1

    log::log debug "misc::HasFSMode $file ($fshown)"

    if {$fshown eq ""} { set fshown $file }

    set f [open $file r]
    set header [read $f 200]
    close $f
    set  loc [string first @__fsmode__@ $header]
    if {$loc < 0} {
	log::log debug "Missing @__fsmode__@ in \{$header\}  "

	set ok 0
	set errormsg "[format [mget 52_INVALID_FSMODE_EXECUTABLE] $fshown]"
    }
    log::log debug "\t$ok"
    return $ok
}


#
# ::tclapp::misc::HasIcon --
#
#	This command checks that a custom icon can be used, if such
#       was chosen. Generates warnings if any precondition for use
#	of a custom icon was violated.
#
# Arguments
#	file	- Path of file to check
#	emsgvar	- Name of variable to store error messages into.
#
# Results
#	A boolean value. True <=> Ok, else not.

proc ::tclapp::misc::HasIcon {input iconvar membersvar} {
    log::log debug "misc::HasIcon"

    ::log::log debug "\tUsing ico [package present ico]"
    ::log::log debug "\t@ [package ifneeded ico [package present ico]]"

    # This check is for a Windows icon we can replace in the prefix
    # file. If the chosen icon is a .icns for an OS X .app bundle we
    # have to ignore it here. Or rather return 0 to cause the
    # 'wrapengine::InsertIcon' to ignore it.

    variable iconfile

    # No custom icon requested, bail out, no warnings required.
    if {$iconfile == {}} {
	log::log debug "\tno icon specified, ignore"
	return 0
    }

    # Requested file truly useable ?

    if {![file isfile $iconfile]} {
	::log::log error [format [mget 55_ICON_DOES_NOT_EXIST] $iconfile]
	return 0
    }

    # Check that the input file contains an icon (if defined)

    if {[lsearch -exact [fileutil::fileType $iconfile] icns] >= 0} {
	# While no icon present this is not an error. Not a _windows_
	# icon, but the OS X parts of the engine will pick it up.
	log::log debug "\tSpecified icon is in Apple ICNS format, ignore for Windows wrap"
	return 0
    }

    # Currently only handles 1st icon resource in a file
    if {
	[catch {set ico [ico::icons $input -type EXE]}] ||
	([llength $ico] == 0)
    } {
	::log::log error [mget 506_ICON_NOT_SUPPORTED_BY_INPUT]
	return 0
    }

    set icons [ico::iconMembers $input $ico -type EXE]

    # We give the information about the currently embedded icon now
    # back to the caller for use in the replacement engine.

    upvar 1 $iconvar i $membersvar m
    set i $ico   ; # Name of icon in basekit/prefix
    set m $icons ; # Icon member under that name.

    log::log debug "\tico ($input)"
    log::log debug "\t    = $ico ($icons)"
    log::log debug "\tok"
    return 1
}

proc ::tclapp::misc::HasOSXIcon {} {
    log::log debug "misc::HasOSXIcon"

    # This check is for an OS X icon

    variable iconfile

    # No custom icon requested, bail out, no warnings required.
    if {$iconfile == {}} {return 0}

    # Requested file truly useable ?

    if {![file isfile $iconfile]} {
	::log::log error [format [mget 55_ICON_DOES_NOT_EXIST] $iconfile]
	return 0
    }

    # Check that the input file contains an icon (if defined)

    if {[lsearch -exact [fileutil::fileType $iconfile] icns] < 0} {
	::log::log error [mget 509_ICON_NOT_ICNS]
	return 0
    }

    log::log debug "\tok"
    return 1
}

#
# ::tclapp::misc::HasStringinfo --
#
#	This command checks that custom string information can be
#	used, if such was chosen. Generates warnings if any
#	precondition for the use of custom string information was
#	violated.
#
# Arguments
#	file	- Path of file to check
#	statvar	- Name of variable to store original string info into.
#
# Results
#	A boolean value. True <=> Ok, else not.

proc ::tclapp::misc::HasStringinfo {input statvar} {
    log::log debug "misc::HasStringinfo ($input)"

    variable stringinfo

    # No custom string information requested, bail out, no warnings required.
    if {$stringinfo == {}} {return 0}

    # Check that the input file contains string information (if
    # defined). See also the TclApp GUI code -> wrapOptsWidget.tcl,
    # procedure HasStringInfo, and its caller.
    array set si {}
    if {[catch {
	::stringfileinfo::getStringInfo $input si
    } msg]} {
	::log::log error [format [mget 507_SI_NOT_SUPPORTED_BY_INPUT] $msg]
	return 0
    }
    if {[array size si] == 0} {
	::log::log error [format [mget 507_SI_NOT_SUPPORTED_BY_INPUT] {No keys, nor data}]
	return 0
    }

    # We give the information about the currently embedded string
    # information now back to the caller for use in the replacement
    # engine.

    upvar 1 $statvar v
    set              v [array get si]

    log::log debug "\tok"
    return 1
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::providedp --
#
#	Set/return providedp
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::providedp {{val 1}} {
    variable providedp $val
    return
}

proc ::tclapp::misc::providedp? {} {
    variable providedp
    return  $providedp
}

namespace eval ::tclapp::misc {

    # Boolean flag. Controls if a list of provided packages is put
    # into a wrap result or not.  Default to true, list is provided.

    variable providedp 1
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::forceExternalCompile --
#
#	Set/return forceExternalCompile
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::forceExternalCompile {{val 1}} {
    variable forceExternalCompile $val
    return
}

proc ::tclapp::misc::forceExternalCompile? {} {
    variable forceExternalCompile
    return  $forceExternalCompile
}

namespace eval ::tclapp::misc {

    # Boolean flag. Controls if invokiation of bytecompiling is forced
    # to use an external process or not. Defaults to false, not forced.

    variable forceExternalCompile 0
}

#
# ### ### ### ######### ######### #########
# ::tclapp::misc::compileForTcl --
#
#	Set/return compileForTcl
#
# Arguments:
#	single	- Boolean. Set to true if this call is a one-shot.
#	argc	- #arguments
#	argv	- Arguments defining the wrap.
#
# Results:
#	None.

proc ::tclapp::misc::compileForTcl {{val 1}} {
    variable compileForTcl $val
    return
}

proc ::tclapp::misc::compileForTcl? {} {
    variable compileForTcl

    if {$compileForTcl ne {}} {
	log::log debug "CompileForTcl (Cached): $compileForTcl"
	return  $compileForTcl
    }

    set compileForTcl [CFT [merge?] [output?] [prefix?] _ _]
    return  $compileForTcl
}

proc ::tclapp::misc::CFT {merge output prefix fbv mv} {
    upvar 1 $fbv fallback $mv message

    set fallback 0

    # This is influenced by the merge, prefix and output flags.
    # -merge  => Extract version from -output
    # !-merge => Extract version from -prefix

    # Note: First call sets compileForTcl, so this path is run only
    # once, and then the cached information is used.

    set f     [expr {$merge ? $output  : $prefix}]
    set label [expr {$merge ? "output" : "prefix"}]
    set labex [expr {$merge ? "Output" : "Prefix"}]

    log::log debug "CompileForTcl"
    log::log debug "    Checking $label: $f"

    if {$f eq ""} {
	log::log debug "    No file specified"
	set message "No $label file specified."
    } elseif {![file exists $f]} {
	log::log debug "    File does not exist"
	set message "$labex file does not exist."
    } elseif {![file readable $f]} {
	log::log debug "    File is not readable"
	set message "$labex file is not readable."
    } elseif {![file isfile $f]} {
	log::log debug "    File is not a file."
	set message "$labex file is not a file."
    } elseif {[lsearch -exact [fileutil::fileType $f] metakit] < 0} {
	log::log debug "    File has no attached mk filesystem"
	set message "$labex File has no attached mk filesystem."
    } else {
	# Scan prefix or output for the provided packages and then
	# look at the version of the Tcl package, present.

	log::log debug "    Scanning for provided packages ..."

	set pr [repository::prefix %AUTO% -location $f]
	set instances [$pr sync list [teapot::listspec::ename package Tcl]]
	$pr destroy

	set n [llength $instances]
	if {$n == 1} {
	    teapot::instance::split [lindex $instances 0] e n v a
	    log::log debug "    Raw version $v"

	    # strip alpha/beta segments
	    regsub -all {[ab][0-9]+} $v . v
	    regsub -all {[.][.]} $v . v
	    # reduce to major.minor
	    set v [join [lrange [split $v .] 0 1] .]
	    log::log debug "    Major/Minor $v"

	    # Force .0 if there is no minor version.
	    if {![string match *.* $v]} {append v .0}
	    log::log debug "    Totality    $v"

	    set message "Forced by $label file"
	    return $v
	}

	# 0 times, or more than one time.
	log::log debug "    Tcl provided [llength $instances] times"
	if {$n == 0} {
	    set message "Tcl not provided."
	} else {
	    set message " Tcl provided $n times, too ambiguous."
	}
    }

    log::log debug "    Falling back to 8.4"
    append message " Falling back to 8.4"
    set fallback 1
    return "8.4"
}

namespace eval ::tclapp::misc {
    # Version number of Tcl for which we wish to bytecompile tcl
    # files. Default is to inherit this from the basekit, if there is
    # any. This falls back to 8.4 if there is no basekit, or its
    # version could not be determined.

    variable compileForTcl {}
}

#
# ### ### ### ######### ######### #########

package provide tclapp::misc 1.0
