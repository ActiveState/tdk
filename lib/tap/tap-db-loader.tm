# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tap::db::loader 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     snit
# Meta require     tcldevkit::config
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Helper type for the tap database. Processing a tap file and loading
# it into the database.

# ### ### ### ######### ######### #########
## Requirements

package require log
package require logger
package require fileutil
package require snit
package require tcldevkit::config

# ### ### ### ######### ######### #########
## Implementation

snit::type ::tap::db::loader {

    # Determine the list of loader to search for package definitions in
    # .tap files.

    option -error {}

    constructor {theinstalldir args} {
	set installdir $theinstalldir

	set basesubst [list \
			   @TDK_INSTALLDIR@ $installdir \
			  ]

	set filesubst [list \
			   @DLLEXT@ [string range [info sharedlibextension] 1 end] \
			  ]

	return
    }

    method process {tapfile master rv} {
	if {![$self Load $tapfile data]} {return 0}

	log::debug "Processing $tapfile"
	::log::log debug "Processing $tapfile"

	upvar 1 $rv result
	set result {}

	# Transient package definition and processing status. Will be
	# written only if complete and without errors.

	ClearMap  map
	InitState tmp $tapfile
	set counter 0

	foreach {cmd val} $data {
	    switch -exact -- $cmd {
		Package {
		    if {$tmp(haspkg) && !$tmp(skip)} {
			Store map tmp result $counter
			incr counter
		    }
		    foreach {name version} $val { break }
		    InitState tmp $tapfile $name $version
		    set tmp(haspkg) 1
		}
		Hidden      {      Hide          tmp}
		See         {$self See       map tmp $val}
		Base        {$self SetBase       tmp $val [file dirname $tapfile] $master}
		Path        {$self AddPattern    tmp $val}
		ExcludePath {$self RemovePattern tmp $val}
		Alias       {$self RenameFile    tmp $val}
		Platform    {      SetPlatform   tmp $val}
		Desc        {      AddDesc       tmp $val}
		default {
		    return -code error \
			"Internal error, illegal PD key \"$cmd\""
		}
	    }
	}
	if {$tmp(haspkg) && !$tmp(skip)} {
	    Store map tmp result $counter
	}
	return 1
    }

    # ### ### ### ######### ######### #########
    ## 

    method Load {fname dv} {
	log::debug "Loading... $fname"
	::log::log debug "Loading... $fname"

	upvar 1 $dv data
	if {[catch {
	    set data [tcldevkit::config::ReadOrdered/2.0 $fname {
		Package
		Base
		Path
		ExcludePath
		Alias
		See
		Hidden
		Platform
		Desc
	    }] ; # {}
	} msg]} {
	    # File is not package definition, skip.
	    $self ReportError "Failed to load \"$fname\": $msg"
	    return 0
	}
	return 1
    }

    proc ClearMap {mv} {
	upvar 1 $mv map
	catch {unset map}
	array set   map {}
	return
    }

    proc DerefMap {mv name} {
	upvar 1 $mv map
	set res {}
	catch {set res $map($name)}
	return $res
    }

    proc InitState {var srcfile {name {}} {version {}}} {
	upvar 1 $var tmp
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
	    haspkg 0 skip 0 hide 0
	    name {} version {}
	    base {} alias {}
	    platform * desc {}
	}

	set tmp(name)    $name
	set tmp(version) $version
	set tmp(source)  $srcfile
	return
    }

    method SetBase {var val tapdir mainpath} {
	upvar 1 $var tmp
	if {$tmp(skip)} return

	set     subst $basesubst
	lappend subst @TAP_DIR@    $tapdir
	lappend subst @TDK_LIBDIR@ $mainpath

	set sval [string map $subst $val]

	# Base path. Need a readable directory
	if {
	    ![file isdirectory $sval] ||
	    ![file readable    $sval]
	} {
	    $self ReportError "Unusable base path \"$val\""
	    $self ReportError "Expanded into      \"$sval\""
	    set tmp(skip) 1
	    return
	}
	set tmp(base) [file normalize $sval]
	return
    }

    proc Hide {var} {
	upvar 1 $var tmp
	if {$tmp(skip)} return

	set tmp(hide) 1
	return
    }

    method See {mv var val} {
	upvar 1 $var tmp
	if {$tmp(skip)} return
	upvar 1 $mv map

	set token [DerefMap map $val]
	if {$token == {}} {
	    $self ReportError "Refering unknown package \"$val\""
	    set tmp(skip) 1
	    return
	}

	set tmp(see)      $token
	set tmp(see,name) $val
	return
    }

    proc AddDesc {var text} {
	upvar 1 $var tmp
	if {$tmp(skip)} return

	# expand, check and add.
	append tmp(desc) $text\n
	return
    }

    proc SetPlatform {var val} {
	upvar 1 $var tmp
	if {$tmp(skip)} return

	# expand, check and add.
	set tmp(platform) $val
	return
    }

    method AddPattern {var pattern} {
	upvar 1 $var tmp

	if {$tmp(skip)} return
	# expand, check and add.

	# Need a base to work from
	if {$tmp(base) == {}} {
	    $self ReportError "$tmp(source): Path \"$pattern\" has no base"
	    set tmp(skip) 1
	    return
	}

	set spattern [string map $filesubst $pattern]
	set expanded [glob -nocomplain -directory $tmp(base) $spattern]

	log::debug "\t\tPath = $pattern"
	::log::log debug "\t\tPath = $pattern"
	log::debug "\t\tBase = $tmp(base)"
	::log::log debug "\t\tBase = $tmp(base)"

	if {[llength $expanded] < 1} {
	    $self ReportError "$tmp(source): No files matching \"$pattern\""
	    set tmp(skip) 1
	    return
	}
	foreach f $expanded {
	    log::debug "\t\tSub  = $f"
	    ::log::log debug "\t\tSub  = $f"

	    if {[file isdirectory $f]} {
		# Directory, include everything.
		foreach ff [fileutil::find $f {file isfile}] {
		    set tmp(p,$ff) [fileutil::stripPath $tmp(base) $ff]

		    log::debug "\t\t\t$tmp(p,$ff)"
		    ::log::log debug "\t\t\t$tmp(p,$ff)"
		}
	    } else {
		# Single file
		set tmp(p,$f) [fileutil::stripPath $tmp(base) $f]

		log::debug "\t\t\t$tmp(p,$f)"
		::log::log debug "\t\t\t$tmp(p,$f)"
	    }
	}
	return
    }

    method RemovePattern {var pattern} {
	upvar 1 $var tmp

	if {$tmp(skip)} return
	# Need a base to work from
	if {$tmp(base) == {}} {
	    $self ReportError "$tmp(source): ExcludePath \"$pattern\" has no base"
	    set tmp(skip) 1
	    return
	}
	# remove pattern

	set fullpattern [file join $tmp(base) $pattern]

	foreach key [array names tmp p,$pattern] {
	    unset tmp($key)
	}
    }

    method RenameFile {var val} {
	upvar 1 $var tmp

	if {$tmp(skip)} return

	foreach {old new} $val { break }

	# Need a base to work from
	if {$tmp(base) == {}} {
	    $self ReportError "$tmp(source): Alias \"$val\" has no base"
	    set tmp(skip) 1
	    return
	}

	set fullpath [file join $tmp(base) $old]

	if {![info exists tmp(p,$fullpath)]} {
	    $self ReportError "$tmp(source): Unable to alias unknown file \"$old\""
	    set tmp(skip) 1
	    return
	}

	set olddst $tmp(p,$fullpath)
	set newdst [file join [file dirname $olddst] $new]
	set tmp(p,$fullpath) $newdst
	return
    }

    proc Store {mv var rv id} {
	upvar 1 $var tmp
	upvar 1 $rv result
	upvar 1 $mv map

	log::debug "Store $tmp(name)-$tmp(version)[expr {$tmp(hide) ? " HIDDEN" : ""}][expr {[info exists tmp(see)] ? " -----> $tmp(see,name)" : ""}]"
	::log::log debug "Store $tmp(name)-$tmp(version)[expr {$tmp(hide) ? " HIDDEN" : ""}][expr {[info exists tmp(see)] ? " -----> $tmp(see,name)" : ""}]"

	# Create storage for definition

	array set data {}
	set data(source)   $tmp(source)
	set data(name)     $tmp(name)
	set data(version)  $tmp(version)
	set data(platform) $tmp(platform)
	set data(desc)     $tmp(desc)
	set data(hidden)   $tmp(hide)
	set data(base)     $tmp(base)

	if {![info exists tmp(see)]} {
	    foreach key [array names tmp p,*] {
		set src [lindex [split $key ,] 1]
		set dst $tmp($key)
		lappend data(filesList) $src $dst

		log::debug "\t$src \t---> $dst"
		::log::log debug "\t$src \t---> $dst"
	    }
	    set data(see) {}
	} else {
	    set data(see) $tmp(see)
	    set data(filesList) {}
	}

	lappend result [array get data]

	# Map for deref of hidden names
	set map($tmp(name)) $id
	return $id
    }

    method ReportError {text} {
	log::debug "Error: $text"
	::log::log debug "Error: $text"
	if {![llength $options(-error)]} return
	uplevel \#0 [linsert $options(-error) end $text]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    # installdir  = path
    # basesubst   = dict (placeholder -> value)
    # filesubst   = dict (placeholder -> value)

    variable installdir {}
    variable basesubst
    variable filesubst

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::tap::db::loader {
    logger::init                              tap::db::loader
    logger::import -force -all -namespace log tap::db::loader
}

# ### ### ### ######### ######### #########
## Ready
return
