# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# Copyright (c) 2006-2014 ActiveState Software Inc.
#


# 
# RCS: @(#) $Id: startup.tcl,v 1.5 2001/01/24 19:41:24 welch Exp $

package require compiler
package require fileutil
package require log
package require osx::bundle::app
package require starkit
package require teapot::metadata::container
package require teapot::metadata::read
package require teapot::metadata::write
package require teapot::instance
package require teapot::version
package require vfs::mk4
package require repository::prefix

package require tclapp::files
package require tclapp::misc
package require tclapp::msgs
package require tclapp::pkg

package require as::tdk::obfuscated

package require tlocate
package require csv

namespace eval ::tclapp::wrapengine {}

# ### ### ### ######### ######### #########

# Notes

# This needs a completely new graft to a completely new package
# management system / database. Currently packages (.tap) are handled
# through the regular files. With TEAPOT packages are instance data,
# meta data + the archive. And we have to unpack and copy them
# separately from the files.

# ### ### ### ######### ######### #########

#
# tclapp::wrapengine::run --
#
#	This is the internal command to perform the actual wrapping
#	after the command line was decoded and processed.
#
# Arguments
#	None.
#
# Results
#	Upon completion of this routine the native filesystem contains
#	a starkit or starpack filled with the files specified on the command line.

proc tclapp::wrapengine::run {ev} {
    upvar 1 $ev errors

    ::log::log debug "wrapengine::run ..."

    set kitfile          [CreateOutputFile errors]

    if {[llength $errors]} {
	CleanupPrefix
	return
    }

    set compressionState [SetCompression]
    set license          BSD

    Mount $kitfile errors
    if {[llength  $errors]} {
	RestoreCompression $compressionState
	CleanupPrefix
	return
    }

    InsertMetadata $kitfile

    WrapPackages  $kitfile                    pkgdirs
    WrapFilesInto $kitfile $license
    LicenseAdd    $kitfile $license

    if {[tclapp::misc::specials?]} {
	CreateWrapMainFile $kitfile $license $pkgdirs
    }

    Unmount       $kitfile

    RestoreCompression $compressionState

    # At near last, check if a bundle is created, and if yes, then
    # create the basic structure, meta data, etc.

    if {[tclapp::misc::osxapp?]} {

	set exe    [tclapp::misc::output?]
	set appdir [file dirname [file dirname [file dirname $exe]]]
	#set appdir [eval [linsert [lrange [file split [tclapp::misc::output?]] 0 end-3] 0 file join]]

	log::log info "Creating an OSX Application Bundle"
	log::log info "  $appdir"

	array set omd [OSXMD]

	# Compute max key length, for proper column alignment in the
	# upcoming dump
	set max 0
	foreach k [array names omd] {
	    set l [string length $k]
	    if {$l > $max} {set max $l}
	}

	# Dump the accumulated OS X meta data to log
	foreach k [array names omd] {
	    set blank [string repeat { } [expr {$max - [string length $k]}]]

	    if {
		($k eq "CFBundleHelpBookFolder") &&
		($omd($k) ne "") &&
		![fileutil::test $omd($k) edr msg]
	    } {
		# Disable this key, data is bogus. Also provide a nice
		# warning about the problem.

		log::log warning "  - $k: $blank$msg. Continuing, but ignoring this key."
		unset omd($k)
		continue
	    } elseif {
		($k eq "CFBundleHelpBookFolder") &&
		($omd($k) eq "")
	    } {
		# Disable this key, data is empty means 'no
		# data'. This doesn't rank a warning.
		unset omd($k)
		continue
	    } elseif {
	        ($k eq "CFBundleIconFile") &&
		($omd($k) ne "") &&
		![fileutil::test $omd($k) efr msg]
	    } {
		# Disable this key, data is bogus. Also provide a nice
		# warning about the problem.

		log::log warning "  - $k: $blank$msg. Continuing, but ignoring this key."
		unset omd($k)
		continue
	    }

	    log::log info "  - $k: $blank$omd($k)"
	}

	# TclApp copies any specified help tree into the bundle.
	set omd(x,help,copy) 1

	::osx::bundle::app::scaffolding $appdir $exe [array get omd]
    }

    # Transfer the generated file to the final destination and set
    # the proper permissions.

    file copy -force $kitfile [tclapp::misc::output?]
    MakeWritable              [tclapp::misc::output?]

    ::log::log info " "
    ::log::log info "Generated [tclapp::misc::output?]"
    ::log::log debug \tok

    CleanupPrefix
    return
}

proc tclapp::wrapengine::OSXMD {} {
    array set omd {}

    # Pull the user specified OS X meta data out of configuration.

    array set omd [::tclapp::misc::iplist?]

    # Overrides ...

    # A version number specified via -infoplist is overriden by the
    # version specified via -metadata. If no version could be found at
    # all a warning is issued and a placeholder written.

    array set md [tclapp::misc::metadata?]

    if {[info exists md(version)]} {
	set omd(CFBundleVersion) $md(version)
    } elseif {![info exists omd(CFBundleVersion)]} {
	set omd(CFBundleVersion) "Unspecified"

	log::log warning "  Application version is MISSING."
	log::log warning "  Use either the switch -infoplist (command line)"
	log::log warning "  or the OS X meta data dialog (gui, reachable in"
	log::log warning "  tab 'Basic', panel 'Output file'), to fill in"
	log::log warning "  the requested information"
    }

    # Look if an icon was specified, in ICNS format. Put it into the
    # plist as well.

    if {[tclapp::misc::HasOSXIcon]} {
	set omd(CFBundleIconFile) [tclapp::misc::icon?]
    }

    return [array get omd]
}


#

proc tclapp::wrapengine::CreateOutputFile {ev} {
    upvar 1 $ev errors

    set kitfile [SelectKit]
    set prefix  [SelectPrefix]

    log::log debug "Prefix is $prefix"
    log::log debug "Output is $kitfile"

    InsertInterpAndMode $prefix $kitfile
    InsertIcon          $prefix $kitfile
    InsertStringInfo    $prefix $kitfile errors

    if {[llength $errors]} return

    MakeWritable $kitfile
    return       $kitfile
}

#

proc tclapp::wrapengine::SelectKit {} {
    set kitfile [fileutil::tempfile wrapresult]

    log::log debug "Will write to $kitfile"

    return $kitfile
}

proc tclapp::wrapengine::SelectPrefix {} {
    # Options influencing the operation of this command
    #
    # * -out path        : Path to file to create
    # * -prefix path     : File to use as base for the kit/pack (duplicated as executable)
    #                    : If the prefix file is a tclkit the result is a starpack.
    # * -merge           : excludes -prefix : Merge files into 'out' (Has to exist).
    #
    # If neither -prefix nor -merge are given an empty prefix is generated here.

    # Maps: -prefix     path <=> input_executableName
    #       -out        path <=> output_executableName
    #       -merge           <=> merge [Boolean: TRUE <=> option is set]

    if {[tclapp::misc::merge?]} {
	# Merge into existing executable

	return [tclapp::misc::output?]
    }

    set prefix [tclapp::misc::prefix?]
    if {$prefix ne ""} {
	# User-specified executable is base for new executable.  If
	# the input is a starkit the result stays a starkit.  If the
	# input is a tclkit or starpack the result becomes a starpack.

	return $prefix
    }

    # No prefix was chosen at all. Use a default prefix, an empty
    # starkit.

    return [file join $starkit::topdir data empty.kit]
}

#

proc tclapp::wrapengine::InsertInterpAndMode {chosen kitfile} {
    set hasinterp [tclapp::misc::HasInterp $chosen __dummy__]
    set hasfsmode [tclapp::misc::HasFSMode $chosen __dummy__]

    if {$hasinterp || $hasfsmode} {
	# Splice the chosen interpreter and fsmode into the output file, if
	# required by it. It is known that this is in the first 200
	# characters of the input (see misc::HasInterp/FSMode check).
	# If the user did not specify an interpreter we fall back
	# to 'tclsh'. If the user did not specify a mode we fall back
	# to '-readonly'.

	set map [list]
	if {$hasinterp} {
	    set interp [tclapp::misc::interpreter?]
	    if {$interp eq ""} {set interp tclsh}

	    ::log::log info  "Inserting \"$interp\" into starkit header."

	    lappend map @__interpreter__@ $interp
	}
	if {$hasfsmode} {
	    # We default to transparent mode if the user made no
	    # choice.

	    set fsmode [tclapp::misc::fsmode?]
	    if {$fsmode eq ""} {set fsmode -readonly}

	    ::log::log info "Inserting \"$fsmode\" into starkit header."

	    lappend map @__fsmode__@      $fsmode
	}

	set in   [open $chosen  r] ; fconfigure $in  -translation binary -eofchar {}
	set out  [open $kitfile w] ; fconfigure $out -translation binary -eofchar {}

	puts -nonewline $out [string map $map [read $in 200]]
	fcopy       $in $out
	close           $out
    } else {
	::log::log debug "Nothing to insert, copying prefix to output"

	# NOTE! This copies the permissions as well, so if the chosen
	# file is read-only, the kitfile will be read-only as well
	# (Bugzilla 71643). That is bad. While we make the file
	# writable at the end of CreateOutputFile this is too late for
	# icons and windows string resources. So we force writability
	# here too.

	file copy -force [Delink $chosen] $kitfile
	MakeWritable                      $kitfile
    }

    return
}

proc tclapp::wrapengine::CleanupPrefix {} {
    # Remove a temporary prefix file. Such files occur when the
    # user-chosen prefix was a reference to a teapot-instance and had
    # to be downloaded from a remote repository. See
    # tclapp::misc::prefix and tclapp::pkg::setArchives for the
    # relevant checks and conversions.

    if {([tclapp::misc::prefix?] ne "") && [tclapp::misc::prefixtemp?]} {
	::log::log info  "Removing temporary prefix file [tclapp::misc::prefix?]"
	file delete [tclapp::misc::prefix?]
    }

    return
}

#

proc tclapp::wrapengine::InsertIcon {chosen kitfile} {
    if {[tclapp::misc::HasIcon $chosen icon members]} {
       array set _ {}
	foreach k $members {
	    # k = id w h bpp
	    set id [lindex $k 0]
	    set k  [lrange $k 1 end]
	    ::log::log debug "Basekit Icon \[$icon $id\] = ($k)"

	    set _($k) $id
	}

	set ifile    [tclapp::misc::icon?]
	set cicon    [lindex [ico::icons $ifile] 0]
	set cmembers [ico::iconMembers $ifile $cicon -type ICO]

	::log::log info  "Inserting custom -icon $ifile"
	::log::log debug "\t    = $cicon ($cmembers)"

	foreach nk $cmembers {
	    set id [lindex $nk 0]
	    set nk [lrange $nk 1 end]
	    ::log::log debug "Custom Icon  \[$cicon $id\] = ($nk)"
	}

	set changes 0

	foreach newico $cmembers {
	    foreach {id w h bpp} $newico break
	    set nk [lrange $newico 1 end]
	    if {![info exists _($nk)]} {
		::log::log warning "    \[__\] ${w}x${h}/${bpp}bpp: ignored, missing in prefix"
		continue
	    }

	    set oindex $_($nk)
	    unset       _($nk)

	    # getIcon reads icon not by member name, but bpp/resolution
	    # writeIcon uses icon name and res/bpp implied by the
	    # getIcon data to adress destination.
	    ico::writeIcon $kitfile $oindex $bpp \
		[ico::getIcon $ifile $cicon -bpp $bpp -res $w -exact 1 -format colors] \
		-type EXE

	    ::log::log info "    \[[format %02d $oindex]\] ${w}x${h}/${bpp}bpp: replaced"

	    set changes 1
	}
	foreach newico [lsort [array names _]] {
	    foreach {w h bpp} $newico break
	    ::log::log warning "    \[__\] ${w}x${h}/${bpp}bpp: not replaced, missing in custom icon"
	}

	if {!$changes} {
	    ::log::log warning " The chosen custom icon caused no replacements"
	}
    } ; # {}
}

#

proc tclapp::wrapengine::InsertStringInfo {chosen kitfile ev} {
    upvar 1 $ev errors

    if {[tclapp::misc::HasStringinfo $chosen si]} {
	# 
	::log::log info "Inserting custom string information"

	array set osi $si
	array set nsi [tclapp::misc::stringinfo?]

	foreach k [array names osi] {
	    if {[info exists nsi($k)]} continue
	    ::log::log warning     "Dropped: $k"
	}

	set mx -1
	set dict {}
	foreach k [array names nsi] {
	    set l [string length $k]
	    if {$l > $mx} {set mx $l}
	    lappend dict $k $l
	}

	foreach {k l} $dict {
	    set v [string repeat " " [expr {$mx - $l}]]\ $nsi($k)

	    if {[info exists osi($k)]} {
		::log::log info    "Replace: $k = $v"
	    } else {
		::log::log warning "New:     $k = $v"
	    }
	}

	if {[catch {
	    ::stringfileinfo::writeStringInfo $kitfile nsi
	} msg]} {
	    if {[string match {*Replacement is too large*} $msg]} {
		# Report user error.

		set msg [format [tclapp::msgs::get 508_SI_REPLACEMENT_TOO_LARGE] $kitfile]

		lappend errors $msg
		return
	    }

	    # Anything else is likely an internal problem.

	    return -code error $msg
	}
    }
}

#

proc tclapp::wrapengine::InsertMetadata {kitdir} {
    # 
    ::log::log info "Inserting TEApot metadata"

    set dict [tclapp::misc::metadata?]

    # Checking the information.

    if {![llength $dict]} {
	::log::log info "  Nothing to insert"
	return
    } elseif {[catch {array set md $dict}]} {
	::log::log error "  Not a valid dictionary, ignoring"
	return
    } elseif {[catch {set appname $md(name)}]} {
	::log::log error "  No 'name' specified"
	return
    } elseif {[catch {set appversion $md(version)}]} {
	::log::log error "  No 'version' specified"
	return
    }
    if {![teapot::version::valid $appversion]} {
	::log::log error "  Bad version '$appversion' specified"
	return
    }
    unset md(name)
    unset md(version)

    if {![tclapp::misc::osxapp?]} {
	array unset md osx,*
    }

    set dict [array get md]

    set mdc [teapot::metadata::container %AUTO%]
    $mdc define $appname $appversion Application
    $mdc set $dict

    set mdfile [file join $kitdir teapot.txt]

    if {![$mdc exists platform]} {
	::log::log warning "  No 'platform' specified, using fallbacks"

	# User did not specify platform. Inherit from basekit, if any,
	# otherwise use the platform hosting TclApp.

	if {[file exists $mdfile]} {
	    set packages [teapot::metadata::read::fileEx $mdfile single error]
	    if {[llength $packages]} {
		::log::log info "  Using basekit platform"
		set base [lindex $packages 0]
		$mdc add platform [$base getfirst platform]
		$base destroy
	    } else {
		::log::log warning "  Problems with basekit metadata, using fallback"
		::log::log info    "  Using TclApp platform"

		$mdc add platform [platform::identify]
	    }
	} else {
	    ::log::log warning "  No basekit metadata, using fallback"
	    ::log::log info    "  Using TclApp platform"

	    $mdc add platform [platform::identify]

	    ::log::log info "  <[$mdc getfirst platform]>"
	}

	::log::log info "    <[$mdc getfirst platform]>"
    }

    fileutil::writeFile $mdfile \
	[teapot::metadata::write::getStringExternalC $mdc]

    foreach l [split [teapot::metadata::write::getStringHumanC $mdc] \n] {
	log::log info $l
    }

    return
}

#

proc tclapp::wrapengine::MakeWritable {path} {
    # Executable as well, the result is an application.

    global tcl_platform
    if {$tcl_platform(platform) eq "unix"} {
	file attributes $path -permissions u+wx
    } elseif {$tcl_platform(platform) eq "windows"} {
	file attributes $path -readonly 0
    }
}

#

proc tclapp::wrapengine::SetCompression {} {
    set oldcompress $::mk4vfs::compress
    if {[tclapp::misc::nocompress?]} {
	log::log notice "Store files uncompressed"
	set ::mk4vfs::compress 0
    }
    return $oldcompress
}

proc tclapp::wrapengine::RestoreCompression {state} {
    set ::mk4vfs::compress $state
    return
}

#

proc tclapp::wrapengine::Mount {kitfile ev} {
    upvar 1 $ev errors

    log::log debug "Mount output file ..."

    ## TODO - USER - ERROR - Different reporting

    # The output file is written too, therefore it is mounted as
    # writable as well, and we assume that the file is writable.

    set types [fileutil::fileType $kitfile]
    log::log debug "\tFile types = ([join $types ", "])"

    # Dump trace...
    foreach l $::tclapp::misc::traceft {
	log::log debug FT\t$l
    }
    log::log debug "FT result = ([join $types ", "])"

    if {[lsearch -exact $types metakit] < 0} {
	log::log debug "\tMetakit signature not found"
	lappend errors [format [tclapp::msgs::get 44_INVALID_INPUT_EXECUTABLE] $kitfile]
	return
    } elseif {[catch {
	vfs::mk4::Mount $kitfile $kitfile
    } msg]} {
	lappend errors "[format [tclapp::msgs::get 44_INVALID_INPUT_EXECUTABLE] $kitfile]: $msg"
	return
    }

    ::log::log debug "Begin adding contents"
    return
}

proc tclapp::wrapengine::Unmount {kitfile} {
    ::log::log debug "Unmount output, writing complete"

    vfs::unmount $kitfile
    return
}

#

proc tclapp::wrapengine::LicenseAdd {kitfile license} {

    # Information about the license ... Separate file, and also
    # appended to standard files if present (config.tcl, boot.tcl).

    fileutil::writeFile [file join $kitfile ORIGIN.txt] $license

    foreach f {boot.tcl config.tcl} {
	set fx [file join $kitfile $f]
	if {[file exists $fx]} {
	    fileutil::appendToFile $fx $license
	}
    }
    return
}

#
# tclapp::wrapengine::CreateWrapMainFile --
#
#	Create the file 'main.tcl'. The contents of this file are a
#	script that (later may include other things) sets up the
#	variables necessary for locating the wrapped system of Tcl &
#	Tk libraries; this information comes from the "-code" flags
#	that were collected when the command line was processed.
#
# Arguments
#	kitdir	Path to the directory where we are collecting the kit.
#
# Returns
#	Nothing

proc tclapp::wrapengine::CreateWrapMainFile {kitdir license pkgdirs} {
    global   tcl_platform

    ::log::log debug CreateWrapMainFile

    set    f [open [file join $kitdir main.tcl] w]
    puts  $f "## Starkit Initialization script"
    puts  $f "##"
    puts  $f "## Creator  : Tcl Dev Kit TclApp"
    puts  $f "## Created @: [clock format [clock seconds]]"
    puts  $f "## User     : $tcl_platform(user)"
    puts  $f $license
    puts  $f ""

    if {
	[llength [tclapp::misc::code?]] ||
	[llength [tclapp::misc::args?]]
    } {
	if {[llength [tclapp::misc::args?]]} {
	    puts $f "## ###"
	    puts $f "## Creator specified argument list, add before user arguments"
	    puts $f ""
	    puts $f "set  ::argv \[concat [tclapp::misc::args?] \$::argv\]"
	    puts $f "incr ::argc [llength [tclapp::misc::args?]]"
	    puts $f ""
	}
	if {[llength [tclapp::misc::code?]]} {
	    puts $f "## ###"
	    puts $f "## Creator specified code fragments"
	    puts $f ""
	    foreach fragment [tclapp::misc::code?] {
		puts $f $fragment
		puts $f ""
	    }
	}
    }

    puts  $f "## ###"
    puts  $f "## Standard setup"
    puts  $f ""
    puts  $f "package require starkit"
    puts  $f "starkit::startup"
    puts  $f ""

    # User specified package dirs.
    if {[llength [tclapp::files::pkgdirs]]} {
	puts $f "## ###"
	puts $f "## Additional package directories, user-specified"
	puts $f ""
	foreach p [tclapp::files::pkgdirs] {
	    puts $f "lappend auto_path \[file join \$starkit::topdir [list $p]\]"
	}
	puts $f ""
    }
    # Package dirs for the wrapped packages. This part uses the 'platform' package
    # to activate only the directories for the relevant platforms.
    if {[llength $pkgdirs]} {
	puts $f "## ###"
	puts $f "## Additional package directories, wrapped packages"
	puts $f ""

	# Note: WrapPackages sets things up so that the platform
	# package is always present in a fixed location, and not as a
	# regular package.

	puts $f {package forget platform}
	puts $f {source [file join $starkit::topdir lib platform.tcl]}

	# Note: While we know the exact list of directories here (see
	# pkgdirs) it is easier to have the starkit glob the list on
	# its own, automatically restricting to the platform patterns
	# of its runtime.

	puts $f "global a p"

	if {[tclapp::misc::merge?]} {
	    set pfx [tclapp::misc::output?]
	} else {
	    set pfx [tclapp::misc::prefix?]
	}
	if {$pfx eq ""} {
	    puts $f "# No prefix. Starkit. Determine platform dynamically"
	    puts $f "set a \[platform::identify\]"
	} else {
	    set pr [repository::prefix %AUTO% -location $pfx]
	    puts $f "# Prefix file. Starpack. Use platform of the prefix."
	    puts $f "set a [$pr architecture]"
	    $pr destroy
	}

	puts $f "set p \{\}"
	puts $f "foreach a \[platform::patterns \$a] \{"
	puts $f "    foreach p \[glob -nocomplain -directory \$starkit::topdir/lib P-\$a] \{"
	puts $f "        lappend auto_path \$p"
	puts $f "    \}"
	puts $f "\}"
	puts $f "unset a p"

	# This ensures that a platform package wrapped by the user has
	# precedence over the package injected by TclApp, at least for
	# the application itself. Note that TclApp's revision of the
	# package was injected in such a manner that it is invisible
	# to package management, search-wise. We got it above only
	# because it was explicitly sourced.

	puts $f {package forget platform}
	puts $f ""
    }

    if {[tclapp::misc::osxapp?]} {
	# For OS X bundles add code to strip Apple's option providing
	# the Processor Serial Number. See bug 74619.

	puts $f "## ###"
	puts $f "## OS X magic for bundles. Strip the processor serial"
	puts $f "## number (option -psnXXX) from the arguments"
	puts $f ""
	puts $f "if \{\[string match -psn* \[lindex \$::argv 0\]\]\} \{"
	puts $f "    incr ::argc -1"
	puts $f "    set  ::argv \[lrange \$::argv 1 end\]"
	puts $f "\}"
	puts $f ""
    }

    puts $f "## ###"
    puts $f "## Jump to wrapped application"
    puts $f ""

    if {[llength [tclapp::misc::app?]]} {
	foreach name [lsort -uniq [tclapp::misc::app?]] {
	    puts  $f [list package require $name]
	}
    } else {
	# Insert code to directly jump to the entrypoint of the
	# application. We forego usage of a 'package require'.
	# This makes wrapping of legacy applications easier, as
	# there is no need to modify the main file so that it
	# becomes a package.

	puts $f "set startup \[file join \$starkit::topdir [list [tclapp::misc::startup?]]\]"
	puts $f "set ::argv0 \$startup"
	puts $f "source      \$startup"
    }

    if {[llength [tclapp::misc::postcode?]]} {
	puts $f ""
	puts $f "## ###"
	puts $f "## Creator specified code fragments running after app start"
	puts $f ""
	foreach fragment [tclapp::misc::postcode?] {
	    puts $f $fragment
	    puts $f ""
	}
    }

    close $f
    ::log::log debug \tok
    return
}

#

proc tclapp::wrapengine::WrapPackages {kitfile pv} {
    upvar 1 $pv ourpkgdirs

    set ourpkgdirs {}
    set verbose [tclapp::misc::verbose?]
    set pprov   [tclapp::misc::providedp?]

    ::log::log info " "
    if {$verbose} {
	::log::log info [tclapp::msgs::get 155_WRAPPING_PACKAGES]
    }

    set provided {}
    set errors   {}

    variable hastbcload 0

    foreach instance [tclapp::pkg::pkg instances] {
	set file [tclapp::pkg::pkg get $instance]

	teapot::instance::split $instance e n v a
	::log::log info "  $n $v ($a)"

	if {$n eq "tbcload"} { set hastbcload 1 }

	# dst directory = E-arch-name-version
	# E = first char of entity, uppercase.
	# Map :'s in the name to _

	set e   [string toupper [string index $e 0]]
	set nx  [string map {: _} $n]

	set libdir ${e}-${a}
	set dst [file join $kitfile lib $libdir ${nx}${v}]

	#tclapp::files::addPkgdir lib/$libdir
	lappend ourpkgdirs $libdir

	# Perform wrapping

	tclapp::pkg::wrapFile $n $v $file $dst

	# Accumulate the meta data information of this package, for
	# copying to the list of 'provided' packages. If active.

	if {$pprov} {
	    foreach p [::teapot::metadata::read::file $file all errors] {
		lappend provided \
		    [::teapot::metadata::write::getStringExternalC $p]
		$p destroy
	    }
	}
    }

    if {!$hastbcload && ![tclapp::misc::merge?] && ([tclapp::misc::prefix?] ne "")} {
	set r          [tclapp::pkg::PrefixRepository]
	set matches    [$r sync find [tclapp::pkg::getArchitectures] [teapot::reference::cons tbcload]]
	set hastbcload [expr {!![llength $matches]}]
    }

    if {$pprov} {
	if {1||$verbose} {
	    ::log::log notice "  Extending the list of provided packages"
	}

	fileutil::appendToFile \
	    [file join $kitfile teapot_provided.txt] \
	    [join $provided \n]
    } else {
	if {1||$verbose} {
	    ::log::log notice "  Removing the list of provided packages"
	}

	file delete -force [file join $kitfile teapot_provided.txt]
    }

    if {$verbose} {
	::log::log info " "
    }

    if {[llength $ourpkgdirs]} {
	set ourpkgdirs [lsort -unique $ourpkgdirs]

	# Set up the injection of 'platform.tcl', to be used by the
	# generated main.tcl file.

	log::log debug "platform [package present platform]"

	# Get ifneeded script for the package
	set ifns [package ifneeded platform [package present platform]]

	log::log debug "platform = $ifns"

	# Assumed and accepted forms of the package ifneeded script ...
	# (1) source FOO.tcl ; package provide FOO x.y
	# (2) package provide FOO x.y ; source FOO.tcl

	# Get source command, drop a possible package provide statement.
	set sc {}
	foreach cmd [split $ifns \;] {
	    log::log debug "cmd = ($cmd)"
	    if {[lindex $cmd 0] eq "source"} {
		set sc $cmd
		break
	    }
	}
	log::log debug "   trail = ($sc)"

	if {$sc eq {}} {
	    global auto_path
	    log::log debug "    self = [info nameofexecutable]"
	    log::log debug "autopath = [join $auto_path "\nautopath = "]"

	    return -code error \
		"Unable to find the source command in the package ifneeded script '$ifns' of the platform package wrapped in tdkbase/tclapp"
	}

	# Get path from source command. This is always the last
	# argument of 'source'. May be preceded by an -encoding
	# option.
	set src [lindex $sc end]

	log::log debug "  source = ($src)"

	# Add to wrap, force non-compilation! This code is needed to
	# determine the current platform, and is thus, for example,
	# responsible for deciding which tbcload binary has to be
	# loaded to decode bytecompiled sources.  Bytecompiling this
	# code thus sets up a deadlock as it would need tbcload
	# itself, but only after it has run we know which tbcload can
	# actually be used. See bug 80867.
	tclapp::files::add errors $src lib/platform.tcl 0
    }
    return
}

#

proc tclapp::wrapengine::WrapFilesInto {kitfile license} {
    set first [expr {1 - [tclapp::misc::verbose?]}]
    foreach {dir files} [tclapp::files::listFiles] {
	if {$first} {::log::log info " " ; set first 0}
	if {[llength $files] > 0} {
	    NoteSection $dir
	    WrapSection $dir $files $license $kitfile
	}
    }
    RunDeferedCompile
    return
}

#

proc ::tclapp::wrapengine::WrapSection {dir files license kitfile} {
    variable hastbcload

    if {$dir eq "."} {set dir ""}

    foreach {dst src} $files {
	# Generate full destination path
	# (kit, dir - see outer loop, filename)

	set srcdisplay $src ; # Always show the original sourcefile, even if changed by
	# ................. ; # the special hacks to something else.

	set dstfile $dst
	set dstrel  [file join $dir $dstfile]
	set dst     [file nativename [file join $kitfile $dstrel]]

	if {[file exists $dst]} {
	    NoteOverwrite $dstrel
	}

	file mkdir [file dirname $dst]

	if {[info exists ::tdkpack] || ![IsTclFile $src]} {
	    # Non tcl files are always copied verbatim.
	    # I.e. no compiling.
	    #
	    # INTERNAL - magic switch
	    # When packaging for a distribution installer everything is
	    # done verbatim too

	    Show 0 $srcdisplay $dstfile
	    Put  0 $license $src $dst
	    continue
	}

	set   compile [Compile $src $dstrel]
	Show $compile $srcdisplay $dstfile

	set iscompiled [as::tdk::obfuscated::is $src inputversions]

	if {$compile && $iscompiled} {
	    # We were about to double-compile. Fix that, and issue a
	    # warning.

	    set compile 0
	    ::log::log warning "\t  Prevented the double-compilation of this file. It was"
	    ::log::log warning "\t  already run through the tclcompiler or an equivalent tool."

	    # Check that core version baked into the input byte code
	    # matches the version we wish to compile for. If not we
	    # have an error and issue the proper message.

	    set requested [CompileFor]
	    foreach {_ inputcore} $inputversions break

	    if {$inputcore ne $requested} {
		::log::log debug "\t  M=[tclapp::misc::merge?]"
		::log::log debug "\t  P='[tclapp::misc::prefix?]'"

		if {![tclapp::misc::merge?] && ([tclapp::misc::prefix?] eq "")} {
		    ::log::log warning "\t  The input file contains bytecode for Tcl $inputcore"
		    ::log::log warning "\t  This may be in conflict with the project, which is"
		    ::log::log warning "\t  configured to generate bytecode for Tcl $requested,"
		    ::log::log warning "\t  depending on the chosen runtime, i.e. basekit."
		} else {
		    ::log::log error "\t  The input file contains bytecode for Tcl $inputcore"
		    ::log::log error "\t  This is in conflict with the project, which is"
		    ::log::log error "\t  configured to generate bytecode for Tcl $requested"
		}
	    }
	}

	if {!$compile && $iscompiled && !$hastbcload} {

	    # A file not set for compilation contains bytecode and we
	    # have no tbcload package wrapped to handle it, neither
	    # directly, nor provided by a prefix. The exact nature of
	    # the message to issue depends on the prefix.  If there is
	    # none, i.e. a starkit we issue only a warning, as the
	    # tclkit/basekit runtime may provide the missing
	    # package. Otherwise it is an error.

	    ::log::log debug "\t  M=[tclapp::misc::merge?]"
	    ::log::log debug "\t  P='[tclapp::misc::prefix?]'"

	    if {![tclapp::misc::merge?] && ([tclapp::misc::prefix?] eq "")} {
		::log::log warning "\t  The input file contains bytecode, and the project is"
		::log::log warning "\t  not wrapping the package 'tbcload' to handle such."
		::log::log warning "\t  The wrap result may not run, depending on the chosen"
		::log::log warning "\t  runtime, i.e. basekit, providing tbcload or not."
	    } else {
		::log::log error   "\t  The input file contains bytecode, and the project is"
		::log::log error   "\t  not wrapping the package 'tbcload' to handle such."
		::log::log error   "\t  The wrap result will not run."
	    }
	}

	Put $compile $license $src $dst
    }
    if {[tclapp::misc::verbose?]} {::log::log info " "}
    return
}

#

proc ::tclapp::wrapengine::Compile {src dst} {
    # Determine if we compile the file or not, based on type of file
    # (tcl-file & !index y/n), per-file settings (y/n/dont-care), and
    # global settings (y/n).

    # tcl? per-file global => compile?
    # ---- -------- ------    --------
    # n    *        *         no
    # ---- -------- ------    --------
    # y    dc       n         no
    # y    dc       y         yes
    # ---- -------- ------    --------
    # y    y        n         yes
    # y    y        y         yes
    # ---- -------- ------    --------
    # y    n        n         no
    # y    n        y         no
    # ---- -------- ------    --------

    # <=> 'tcl? && ((!dontcare && perfile) || (dontcare && global))'

    array set meta [tclapp::files::metaGet $dst]
		
    return [expr {
		  [IsTclFileNoIndex $src] &&
		  (( [info exists meta(compile)] && $meta(compile)) ||
		   (![info exists meta(compile)] && [tclapp::misc::compile?]))
	      }]
}

#

proc ::tclapp::wrapengine::NoteSection {dir} {
    if {[tclapp::misc::verbose?]} {
	::log::log info [tclapp::msgs::get 153_WRAPPING_FILES]
	::log::log info [format [tclapp::msgs::get 400_IN_DIR] $dir]
    }
    return
}

proc ::tclapp::wrapengine::NoteOverwrite {path} {
    # Generate a meaningful warning message if the destination file is
    # already present in the outputfile (like for example in a
    # base... kit). We ignore these files and continue copying. In the
    # future a 'force write' option may exist to overide this
    # behaviour.

    # Bypass -verbose. We are not allowed to suppress errors and
    # warnings.

    ::log::log warning "           NOTE $path"
    ::log::log warning "                This file is already present in the archive."
    ::log::log warning "                It is now overwritten by the selected source"
    ::log::log warning "                file."
    ::log::log info    ""
    return
}

#

proc ::tclapp::wrapengine::Show {compile srcdisplay dstdisplay} {
    set tag [expr {$compile ? "*" : " "}]
    if {[tclapp::misc::verbose?]} {
	::log::log info "\t$tag $dstdisplay\t$srcdisplay"
    } else {
	::log::log info "F$tag [KMG [file size $srcdisplay]] $srcdisplay"
    }
    return
}


proc ::tclapp::wrapengine::KMG {s} {
    variable kmg
    variable kmgmax
    set n 0
    while {($s > 1024) && ($n < $kmgmax)} {
	set s [expr {$s/1024.0}]
	incr n
    }
    return [format %4d [expr {int(ceil($s))}]]$kmg($n)
}

namespace eval ::tclapp::wrapengine {
    variable  kmg
    array set kmg {
	0 {B  }
	1 KiB
	2 MiB
	3 GiB
	4 TiB
	5 PiB
	6 EiB
    }
    variable kmgmax 6

    variable cprefix {}
    variable compdir {}
    variable map     {}
    variable count   {}
    variable who     {}
}

proc ::tclapp::wrapengine::Put {compile license src dst} {
    set nativesrc [file nativename [Delink $src]]
    if {$compile} {

	# When compiling things we have to know for which version of
	# Tcl we are doing this. If the version of Tcl matches the
	# version of our runtime we can use the compiler package which
	# was baked into the application, as it is for exactly that
	# version. Otherwise we have to spawn a sub-process and invoke
	# the compiler application for the requested version of Tcl.

	# Internal note: Direct access to the configuration
	# information, like by the build system, allows us to force
	# the use of an external process, regardless of the version,
	# matching or not. The command line does not allow this.

	# Note 2: Spawning a process takes longer, of course.
	# Especially should we go and actually spawn one per file to
	# compile. Instead of doing that we handle this case by
	# collecting the files and then invoking the compiler once, on
	# the whole set.

	set requested [CompileFor]

	if {[catch {
	    set ctcl [compiler::getTclVer]
	}]} {
	    log::log debug "Compiler getTclVer ???, falling back to 8.4"
	    set ctcl 8.4
	}

	if {
	    ![::tclapp::misc::forceExternalCompile?] &&
	    ($ctcl eq $requested)
	} {
	    log::log debug "Compile internal ($requested)"

	    uplevel #0 [list ::compiler::compile -preamble $license $nativesrc $dst]
	} else {
	    variable cprefix
	    variable compdir
	    variable map
	    variable count
	    variable who

	    log::log debug "Compile external (requested $requested vs internal $ctcl)"

	    if {$compdir == {}} {
		# The tool is expected to have Tcl version number in
		# the name, without dots. I.e. tclcompiler84,
		# tclcompiler85, etc.

		set whois tclcompiler[string map {. {}} $requested]
		set who [tlocate::find $whois]

		if {![llength $who]} {
		    # The external compiler was not found. Report the
		    # problem, and abort. Note that we have no state
		    # yet requiring cleanup.

		    return -code error "Tool $whois not found"
		}

		log::log debug "  Tool is   $who"

		# Setup the collection directory and its internal state.

		set compdir [fileutil::tempfile BCC]
		file delete $compdir
		file mkdir  $compdir
		set count 0
		set cprefix [fileutil::tempfile BCCX]
		fileutil::writeFile $cprefix $license

		log::log debug "  Collect @ $compdir"
	    }

	    set newsrc [file join $compdir [incr count]]
	    file copy $nativesrc $newsrc.tcl
	    lappend map $newsrc.tcl $newsrc.tbc $dst
	}

    } else {
	# No compilation, simply copy the file
	file copy -force $nativesrc $dst
    }
    return
}

proc ::tclapp::wrapengine::CompileFor {} {
    set requested [::tclapp::misc::compileForTcl?]

    if 0 {
	# Bug 83012. If requested is 8.6 downgrade to 8.5, the
	# bytecodes are compatible.

	if {$requested eq "8.6"} {
	    ::log::log debug "Requested 8.6, is 8.5 compatible, requesting that now"
	    set requested 8.5
	}
    }

    return $requested
}

proc ::tclapp::wrapengine::RunDeferedCompile {} {
    variable cprefix
    variable compdir
    variable map
    variable count
    variable who

    # Nothing was collected, skip.
    if {$compdir eq {}} {
	::log::log debug "No defered bytecode compilation"
	return
    }

    ::log::log info "Running defered bytecode compilation"
    ::log::log info "    Using external compiler $who"
    ::log::log info "    For Tcl [tclapp::misc::compileForTcl?]"
    ::log::log info "    TclApp based on Tcl [package present Tcl]"

    # Build the command line. We use a temp file to contain all the
    # options, to keep the command line short. (Especially important
    # on windows).

    set config [fileutil::tempfile BCCZ]

    set     cmd {}
    lappend cmd -nologo          ; # Reduce output we are ignoring anyway
    lappend cmd -prefix $cprefix ; # License preamble
    lappend cmd -out    $compdir ; # Use input directory for the output too.

    fileutil::appendToFile $config [csv::join $cmd { }]\n

    # List the files to compile.
    foreach {src _ _} $map {
	fileutil::appendToFile $config [csv::join [list $src] { }]\n
    }

    set     cmd [linsert $who 0 exec]
    lappend cmd -config $config

    # Run the defered compilation.
    eval $cmd
    # 85: exec {*}$cmd

    # The external compiler writes to a temp file, it has no direct
    # access to the virtual fs of the wrap. We move the results over.

    foreach {_ src dst} $map {
	file copy -force $src $dst
    }

    # Cleanup scratch areas
    file delete -force $compdir
    file delete -force $cprefix
    file delete -force $config

    # Clear state
    set cprefix {}
    set compdir {}
    set map     {}
    set count   {}
    set who     {}
    return
}


#
# IsTclFile --
#
#	Identify Tcl files by name (extension)
#	Identify Tcl files which are not package indices.
#
# Arguments:
#	path	path to file to identify
#
# Results:
#	Boolean flag.

proc ::tclapp::wrapengine::IsTclFileNoIndex {path} {
    return [expr {
	[string equal .tcl [file extension $path]] &&
	![string equal pkgIndex.tcl [file tail $path]]
    }]
}

proc ::tclapp::wrapengine::IsTclFile {path} {
    return [string equal .tcl [file extension $path]]
}

proc ::tclapp::wrapengine::Delink {path} {
    # The regular behaviour of Tcl for symlinks is to copy the link,
    # and not the contents of the file it is refering to. Relative
    # links would be broken immediately by this, and keeping absolute
    # links would couple the store contents to the state of the
    # environment. Neither is acceptable. Therefore we resolve all
    # symbolic links, including one in the last element of the
    # path. This ensures that the "file copy" afterward copies an
    # actual file.

    while {[file type $path] eq "link"} {
	set path [file normalize $path]
	set path [file join [file dirname $path] [file readlink $path]]
    }

    return $path
}

#
# ### ### ### ######### ######### #########

package provide tclapp::wrapengine 1.0
