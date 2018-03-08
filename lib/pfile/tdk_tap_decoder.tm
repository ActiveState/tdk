# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tdk_tap_decoder 0.1
# Meta platform    tcl
# Meta require     log
# Meta require     snit
# Meta require     starkit
# Meta require     tdk_tap
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# Generic reading and writing files in {Tcl Dev Kit Project File} format.
# (c) 2003-2006 ActiveState Software Inc.

# ----------------------------------------------------
# Prerequisites

package require log
package require snit
package require tdk_tap
package require starkit

# ----------------------------------------------------
# Interface & Implementation

snit::type tdk_tap_decoder {
    variable tap {}

    constructor {v} {
	set tap [tdk_tap tap $v]
	$self InitSubst
	return
    }

    destructor {
	if {$tap == {}} return
	$tap destroy
	return
    }

    method errors {} {
	return $errors
    }

    method read {fname dest} {
	if {[catch {
	    set tapdata [$tap read $fname]
	} msg]} {
	    return -code error "Tap data error:\n$msg"
	}

	# Transient package definition and processing status. Will be
	# written only if complete and without errors.

	set errors {}
	$self ClearMap
	$self InitState tmp $fname

	foreach {cmd val} $tapdata {
	    # The underlying reader delivers arguments always as a
	    # list. Take first element, our actual argument.

	    set val [lindex $val 0]

	    switch -exact -- $cmd {
		Package {
		    if {$tmp(haspkg) && !$tmp(skip)} {
			$self Store tmp $dest
		    }
		    foreach {name version} $val { break }
		    $self InitState tmp $fname $name $version
		    set tmp(haspkg) 1
		}
		Hidden      {$self Hide          tmp}
		See         {$self See           tmp $val}
		Base        {$self SetBase       tmp $val [file dirname $fname]}
		Path        {$self AddPattern    tmp $val}
		ExcludePath {$self RemovePattern tmp $val}
		Alias       {$self RenameFile    tmp $val}
		Platform    {$self SetPlatform   tmp $val}
		Desc        {$self AddDesc       tmp $val}
		default {
		    return -code error "internal error, illegal PD key \"$cmd\""
		}
	    }
	}
	if {$tmp(haspkg) && !$tmp(skip)} {
	    $self Store tmp $dest
	}
	return
    }

    delegate method * to tap

    # ------------------------------------------------
    # ------------------------------------------------
    # ------------------------------------------------
    # Internals

    variable basesubst
    variable filesubst

    method InitSubst {} {
	set installdir [file dirname [file dirname $starkit::topdir]]

	set basesubst [list \
		@TDK_INSTALLDIR@ $installdir \
		@TDK_LIBDIR@     [file join $installdir lib] \
		]
	set filesubst [list \
		@DLLEXT@         [string range [info sharedlibextension] 1 end] \
		]
	array set map {}
	return
    }

    variable errors
    variable map

    method logError {text} {
	lappend errors $text
	return
    }

    method InitState {var srcfile {name {}} {version {}}} {
	upvar $var   tmp
	catch {unset tmp}

	# haspkg - boolean - set to true if package defined
	# skip   - boolean - set to true if an error causes
	#                    us to skip over the remainder
	#                    of the definition
	# name, version - identity of the package.
	# base - base path
	# alias - last alias
	# platform - platform info of package
	# desc - description

	array set tmp {
	    haspkg   0  skip    0  hide 0
	    name     {} version {}
	    base     {} alias   {}
	    platform *  desc    {}
	}

	set tmp(name)    $name
	set tmp(version) $version
	set tmp(source)  $srcfile
	return
    }


    method SetBase {var val tapdir} {
	upvar $var tmp
	if {$tmp(skip)} return

	set sval [string map $basesubst \
		[string map [list @TAP_DIR@ $tapdir] \
		$val]]

	# Base path. Need a readable directory
	if {
	    ![file isdirectory $sval] ||
	    ![file readable    $sval]
	} {
	    log::log debug "\tUnuseable base path \"$val\""
	    log::log debug "\texpansion was       \"$sval\""
	    $self logError "$tmp(source): Unuseable base path \"$val\",\n\
		    was expanded to \"$sval\"."
	    set tmp(skip) 1
	    return
	}
	set tmp(base) [file normalize $sval]
	return
    }


    method Hide {var} {
	upvar $var tmp
	if {$tmp(skip)} return
	set tmp(hide) 1
	return
    }


    method See {var val} {
	upvar $var tmp
	if {$tmp(skip)} return

	set token [$self DerefMap $val]
	if {$token == {}} {
	    log::log             debug "\tRefering unknown package \"$val\""
	    $self logError "$tmp(source): Refering unknown package \"$val\""
	    set tmp(skip) 1
	    return
	}

	set tmp(see)      $token
	set tmp(see,name) $val
	return
    }


    method AddDesc {var text} {
	upvar $var tmp
	if {$tmp(skip)} return

	# expand, check and add.
	append tmp(desc) $text\n
	return
    }

    method SetPlatform {var val} {
	upvar $var tmp
	if {$tmp(skip)} return

	# expand, check and add.
	set tmp(platform) $val
	return
    }

    method AddPattern {var pattern} {
	upvar $var tmp

	if {$tmp(skip)} return
	# expand, check and add.

	# Need a base to work from
	if {$tmp(base) == {}} {
	    log::log             debug "\tPath \"$pattern\" has no base"
	    $self logError "$tmp(source): Path \"$pattern\" has no base"
	    set tmp(skip) 1
	    return
	}

	set spattern [string map $filesubst $pattern]
	set expanded [glob -nocomplain -directory $tmp(base) $spattern]

	log::log debug "\t\tPath = $pattern"
	log::log debug "\t\tBase = $tmp(base)"

	if {[llength $expanded] < 1} {
	    set tmp(skip) 1
	    log::log             debug "\tNo files matching \"$pattern\""
	    $self logError "$tmp(source): No files matching \"$pattern\""
	    return
	}
	foreach f $expanded {

	    log::log debug "\t\tSub  = $f"

	    if {[file isdirectory $f]} {
		# Directory, include everything.
		foreach ff [fileutil::find $f {file isfile}] {
		    set tmp(p,$ff) [tdk_tap_decoder::StripLeading $tmp(base) $ff]

		    log::log debug "\t\t\t$tmp(p,$ff)"
		}
	    } else {
		# Single file
		set tmp(p,$f) [tdk_tap_decoder::StripLeading $tmp(base) $f]

		log::log debug "\t\t\t$tmp(p,$f)"
	    }
	}
	return
    }


    method RemovePattern {var pattern} {
	upvar $var tmp

	if {$tmp(skip)} return
	# Need a base to work from
	if {$tmp(base) == {}} {
	    log::log             debug "\tExcludePath \"$pattern\" has no base"
	    $self logError "$tmp(source): ExcludePath \"$pattern\" has no base"
	    set tmp(skip) 1
	    return
	}
	# remove pattern

	set fullpattern [file join $tmp(base) $pattern]

	foreach key [array names tmp p,$pattern] {
	    unset tmp($key)
	}
	return
    }

    method RenameFile {var val} {
	upvar $var tmp

	if {$tmp(skip)} return

	foreach {old new} $val { break }

	# Need a base to work from
	if {$tmp(base) == {}} {
	    log::log             debug "\tAlias \"$val\" has no base"
	    $self logError "$tmp(source): Alias \"$val\" has no base"
	    set tmp(skip) 1
	    return
	}

	set fullpath [file join $tmp(base) $old]

	if {![info exists tmp(p,$fullpath)]} {
	    log::log             debug "\tUnable to alias unknown file \"$old\""
	    $self logError "$tmp(source): Unable to alias unknown file \"$old\""
	    set tmp(skip) 1
	    return
	}

	set olddst $tmp(p,$fullpath)
	set newdst [file join [file dirname $olddst] $new]
	set tmp(p,$fullpath) $newdst
	return
    }

    method Store {var dest} {
	upvar $var tmp
	log::log debug "Store $tmp(name)-$tmp(version)[expr {$tmp(hide) ? " HIDDEN" : ""}][expr {[info exists tmp(see)] ? " -----> $tmp(see,name)" : ""}]"

	set pkgKey $tmp(name)-$tmp(version)

	$dest add  $pkgKey
	$dest meta $pkgKey \
		source   $tmp(source) \
		name     $tmp(name) \
		version  $tmp(version) \
		platform $tmp(platform) \
		desc     $tmp(desc)

	if {[info exists tmp(see)]} {
	    $dest see $pkgKey $tmp(see)
	} else {
	    set filesList {}
	    foreach key [array names tmp p,*] {
		set src [lindex [split $key ,] 1]
		set dst $tmp($key)
		lappend filesList $src $dst

		log::log debug "\t$src \t---> $dst"
	    }
	    $dest files $pkgKey $filesList
	}

	if {$tmp(hide)} {
	    $dest hide $pkgKey
	}

	# Map for deref of hidden names
	set map($tmp(name)) $pkgKey
	return
    }

    method ClearMap {} {
	unset     map
	array set map {}
	return
    }

    method DerefMap {name} {
	set res {}
	catch {set res $map($name)}
	return   $res
    }

    #
    # StripLeading --
    #
    #	Given the arguments, 'dirPath' and 'filePath', this routine stripts
    #	off from 'filePath' those leading elements from both paths.
    #
    # Arguments
    #	dirPath		a directory path
    #	filePath	a file path that may contain a lead 'dirPath' pattern
    #
    # Results
    #	A file path is returned.

    proc StripLeading {dirPath filePath} {
	set dirPath  [file split $dirPath]
	set filePath [file split $filePath]

	for {set i 0} {$i < [llength $dirPath]} {incr i} {
	    if {[lindex $dirPath $i] != [lindex $filePath $i]} {
		break;
	    }
	}
	if {$i == [llength $dirPath]} {
	    # The list for 'dirPath' was exhausted, therefore 'dirPath' is truly
	    # a complete leading subset of 'filePath'.

	    set filePath [lrange $filePath $i end]
	}
	if {[llength $filePath] == 0} {
	    return ""
	}
	return [eval file join $filePath]
    }

}

# ----------------------------------------------------
# Ready to go ...
return
