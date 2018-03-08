# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tape_state.tcl --
# -*- tcl -*-
#
#	State module for Tap Editor application.
#
# Copyright (c) 2003 ActiveState CRL.

#
# RCS: @(#) $Id: tclapp.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

# ==================================================================================
# ==================================================================================

if {[catch {
    package require compiler
    compiler::tdk_license user-name
} err]} {
    # Compiler package missing, we cannot work - No license.
    wm withdraw .
    if {![string match "*license*" $err]} {
	set err "Failed license check"
    }
    tk_messageBox -icon error -title "Invalid License" \
	    -type ok -message $err
    exit 1
}

package require tapscan

# ==================================================================================
# ==================================================================================

namespace eval ::tape::state {}

# Dispatcher - singleton object.
proc ::tape::state {cmd args} {
    return [uplevel 1 [linsert $args 0 tape::state::$cmd]]
}

# ==================================================================================

proc ::tape::state::pkgListVar {} {
    # returns name of namespaced variable containing the list of
    # package names.

    return ::tape::state::packages
}

proc ::tape::state::pkgdir {} {
    return {}
}

proc ::tape::state::do {cmd args} {
    # command called by the package display widget whenever it needs
    # information from the state manager, and has to provide something

    log::log debug "$cmd ([join $args ") ("])"

    switch -exact -- $cmd {
	set-base-directories {
	    variable current
	    if {$current == {}} {
		log::log debug "No current display, killed change"
		return
	    }
	    variable idxmap
	    variable $idxmap($current)
	    upvar  0 $idxmap($current) data

	    # The complexity comes from the set operation
	    # to determine the deleted directories, so that
	    # we can delete their file-data too.

	    array set old {}
	    foreach b $data(bases) {set old($b) .}
	    set data(bases) [set new [lindex $args 0]]
	    foreach b $new {unset -nocomplain old($b)}
	    foreach b [array names old] {
		unset data(b,$b)
	    }
	    unset old
	    ::tcldevkit::appframe::markdirty
	}
	set-base-data {
	    variable current
	    if {$current == {}} {
		log::log debug "No current display, killed change"
		return
	    }
	    variable idxmap
	    variable $idxmap($current)
	    upvar  0 $idxmap($current) data
	    set data(b,[lindex $args 0]) [lindex $args 1]
	    ::tcldevkit::appframe::markdirty
	}
	get-base-directories {
	    variable current
	    variable idxmap
	    variable $idxmap($current)
	    upvar  0 $idxmap($current) data

	    return $data(bases)
	}
	get-base-data {
	    variable current
	    variable idxmap
	    variable $idxmap($current)
	    upvar  0 $idxmap($current) data
	    return $data(b,[lindex $args 0])
	}
	get-see-ref {
	    set key [lindex $args 0]
	    variable current
	    variable idxmap

	    # Load current package
	    variable $idxmap($current)
	    upvar  0 $idxmap($current) data

	    # Load package referenced as source

	    if {$data(see,ref) == {}} {
		# There is no reference set yet.
		return {}
	    }

	    variable $data(see,ref)
	    upvar  0 $data(see,ref) source

	    # We need its index in the list of all packages
	    # == Index in list of possible references for
	    #    current.

	    return   $source(pindex)
	}
	get-allowed-references {
	    # Generate a list of all packages defined
	    # 'before' this one.

	    variable packages
	    variable current

	    set i 0 ; set res [list]
	    foreach p $packages {
		if {$i == $current} {break}
		incr i ; lappend res $p
	    }
	    return $res
	}
	get {
	    # Assume that this is called only for current != {}.

	    set key [lindex $args 0]
	    variable current
	    variable idxmap
	    variable $idxmap($current)
	    upvar  0 $idxmap($current) data
	    if {[string equal $key hidden]} {set key hide}
	    return $data($key)
	}
	change {
	    variable current
	    # Return changes if nothing is currently selected
	    # for display.
	    if {$current == {}} {
		log::log debug "No current display, killed change"
		return
	    }
	    variable idxmap
	    variable $idxmap($current)
	    upvar  0 $idxmap($current) data
	    set key [lindex $args 0]
	    set val [lindex $args 1] ; set oval $val

	    # Translation between ui/our keys
	    if {[string equal $key hidden]} {set key hide}

	    # Translation of values
	    if {[string equal $key see,ref]} {
		# Translate package reference
		# UI   - Index in packages list.
		# Here - Name of data array for package.
		set val $idxmap($val)
	    }

	    # Make persistent ...

	    set oldval $data($key)
	    set data($key) $val

	    ::tcldevkit::appframe::markdirty

	    # And run key dependent code.

	    switch -exact -- $key {
		see {
		    # Tell UI that change is accepted and to update
		    # its component to reflect this.

		    UpCall show-alias-ref $data(see)
		    UpCall enable-files  [expr {!$data(see)}]
		    SameAsOk $current
		}
		see,ref {
		    SameAsOk $current
		}
		name {
		    # Map from array back to index in list and
		    # change that entry in the list. This propagates
		    # the changed name to the selector list.

		    variable packages
		    set idx $data(pindex)
		    lset packages $idx $val
		    NameClash $oldval $val
		    NameOk $current
		}
		version {
		    VersionOk $current
		}
		platform {
		    PlatformOk $current
		}
	    }
	}
	default {
	    error "Unknown action \"$cmd\""
	}
    }
    return
}

proc ::tape::state::update {obj} {
    # Sets the callback command to use whenever the package display has to
    # change somehow.

    variable upCmd $obj
    return
}

proc ::tape::state::setSelectionTo {list} {
    # Tells the state which elements in the listbox are selected =
    # which packages.

    variable selection $list
    log::log debug "::tape::state::setSelectionTo $list"

    if {[llength $list] != 1} {
	DeactivatePkgDisplay
    } else {
	SwitchPkgDisplay [lindex $list 0]
    }
    return
}

proc ::tape::state::getState {} {
    # returns current state - For use by writing to .tap file (appframe/Write)
    variable packages
    variable idxmap
    variable packages

    # Enforce that everything shown in the display is known to us too.
    UpCall select {}


    set tapstate [list]
    for {set i 0} {$i < [llength $packages]} {incr i} {
	variable $idxmap($i)
	upvar 0  $idxmap($i) data

	lappend tapstate Package [list $data(name) $data(version)]
	if {$data(hide)} {
	    lappend tapstate Hidden {}
	}
	if {$data(desc) != {}} {
	    lappend tapstate Desc $data(desc)
	}
	if {$data(see)} {
	    variable $data(see,ref)
	    upvar 0  $data(see,ref) source
	    lappend tapstate See $source(name)
	} else {
	    foreach base $data(bases) {
		lappend tapstate Base $base
		foreach e $data(b,$base) {
		    set key [lindex $e 0]
		    set val [lindex $e 1]
		    switch -exact -- $key {
			include {set key Path}
			exclude {set key ExcludePath}
			alias {set key Alias}
		    }
		    lappend tapstate $key $val
		}
	    }
	}
    }

    log::log debug "TAP = << $tapstate >>"
    return $tapstate
}

proc ::tape::state::clear {} {
    # clears current state

    variable selection
    variable packages
    variable idxmap
    variable id
    variable clash

    DeactivatePkgDisplay

    for {set i 0} {$i < [llength $packages]} {incr i} {
	set dvar $idxmap($i)
	variable $dvar
	unset    $dvar
	unset idxmap($i)
    }

    set packages  {}
    set selection {}
    set id 0

    unset     clash
    variable  clash
    array set clash {}

    return
}

proc ::tape::state::check {data} {
    # Validate the provided data
    LoadPackageDefinition  $data 1 ; # Checking mode throws error
    return
}

proc ::tape::state::setState {data} {
    # Set current state to data
    LoadPackageDefinition $data
    SetupDisplay
    return
}

proc ::tape::state::resetInput {} {
    variable inputfile {}
    # no gui call - won't be active for tap anyway.
    return
}

proc ::tape::state::setInputFile {fname} {
    variable inputfile $fname
    return
}

proc ::tape::state::getInputFile {} {
    variable inputfile
    return  $inputfile
}

# ==================================================================================
## Internal functionality

proc ::tape::state::Initialize {} {
    # Global initialization of package
    # Nothing for now.
    return
}


proc ::tape::state::NameClash {old new} {
    variable clash
    set change 0

    catch {
	incr clash($old) -1
	if {$clash($old) == 0} {
	    unset clash($old)
	} elseif {$clash($old) == 1} {
	    # Old value had clash, not anymore
	    set change 1
	}
    }
    if {![info exists clash($new)]} {
	set clash($new) 1
    } else {
	incr clash($new)
	if {$clash($new) > 1} {
	    # New value is now in clash
	    set change 1
	}
    }
    if {$change} {
	# Send (un)clash messages up
	variable packages
	set i 0
	foreach p $packages {
	    if {$clash($p) > 1} {
		UpCall error@ $i name {The name of the package is not unique}
	    } else {
		UpCall error@ $i name {}
	    }
	    incr i
	}
    }
}


proc ::tape::state::NameOk {idx} {
    variable idxmap
    variable clash
    variable $idxmap($idx)
    upvar  0 $idxmap($idx) data

    if {[info exists clash($data(name))] && ($clash($data(name)) > 1)} {
	# Report existing name clash
	UpCall error@ $idx name {The name of the package is not unique}
    } elseif {[string length $data(name)] == 0} {
	# Highlight as problem
	UpCall error@ $idx name {The name of the package is empty, and should not be}
    } else {
	UpCall error@ $idx name {}
    }
    return
}


proc ::tape::state::VersionOk {idx} {
    variable idxmap
    variable $idxmap($idx)
    upvar  0 $idxmap($idx) data

    if {[string length $data(version)] == 0} {
	# Highlight as problem
	UpCall error@ $idx version {The version of the package is empty, and should not be}
    } else {
	UpCall error@ $idx version {}
    }
    return
}

proc ::tape::state::PlatformOk {idx} {
    variable idxmap
    variable $idxmap($idx)
    upvar  0 $idxmap($idx) data

    if {[string length $data(platform)] == 0} {
	# Highlight as problem
	UpCall error@ $idx platform {The platform of the package is empty, and should not be}
    } else {
	UpCall error@ $idx platform {}
    }
    return
}

proc ::tape::state::SameAsOk {idx} {
    variable idxmap
    variable $idxmap($idx)
    upvar  0 $idxmap($idx) data

    if {$data(see) && ($data(see,ref) == {})} {
	# Highlight as problem
	UpCall error@ $idx see {No package selected}
    } else {
	UpCall error@ $idx see {}
    }
    return
}


proc ::tape::state::SetupDisplay {} {
    # Select first package for display
    variable packages
    variable current
    set      current {}

    if {[llength $packages] > 0} {
	SwitchPkgDisplay 0
    } else {
	DeactivatePkgDisplay
    }
}


proc ::tape::state::NewPackage {} {
    # We use commands from the parser below to setup things.
    # The work-horse here is the 'Store' command which creates
    # all the relevant data structures. We provide a dummy name.

    variable        packages
    variable        newcnt
    set n [llength $packages]

    InitState tmp "New package [incr newcnt]"
    set       tmp(checking) 0
    set       tmp(errors)   {}
    Store     tmp
    ClearMap

    # Select new package for immediate editing.
    SwitchPkgDisplay $n
    return
}


proc ::tape::state::NSPL {log level text} {
    uplevel \#0 [linsert $log end $level $text]
    return
}

proc ::tape::state::NewScanPackage {dir log} {

    # The check for a package index file has been done by the GUI already.
    # Exists, is a file, is readable. Checking the syntax, etc. is our
    # responsibility.

    NSPL $log info "Reading package information ..."

    array set pkg [tapscan::listPackages $dir]

    if {![array size pkg]} {
	NSPL $log error "No packages found in package index file."
	return 0
    }

    foreach {files binary} [tapscan::listFiles $dir] break

    if {![llength $files]} {
	NSPL $log error "No files found in the chosen directory."
	return 0
    }

    ## ## The data seems to be ok, so we now copy them over into
    ## ## our data structures.

    NSPL $log info "Adding packages ..."

    variable        packages
    variable        newcnt
    set n [llength $packages]

    if {[array size pkg] > 1} {
	# Generate a hidden package for the files shared by all
	# the packages in the directory

	NSPL $log warning "Hidden package keeping the files"

	InitState tmp [set shared "__Hidden [incr newcnt]"] 0.0
	set       tmp(checking) 0
	set       tmp(errors)   {}
	Hide      tmp
	SetBase   tmp $dir __dummy__
	foreach f $files {
	    AddPattern tmp $f
	}
	Store     tmp

	set n [llength $packages]

	foreach p [lsort [array names pkg]] {
	    NSPL $log info "   $p $pkg($p)"

	    InitState tmp $p $pkg($p)
	    set       tmp(checking) 0
	    set       tmp(errors)   {}
	    See       tmp $shared
	    Store     tmp
	}
	ClearMap
    } else {
	set p [lindex [array names pkg] 0]

	NSPL $log info "   $p $pkg($p)"

	InitState tmp $p $pkg($p)
	set       tmp(checking) 0
	set       tmp(errors)   {}
	SetBase   tmp $dir __dummy__
	foreach f $files {
	    AddPattern tmp $f
	}
	Store     tmp
	ClearMap
    }

    # Select first of the new packages for immediate editing.
    SwitchPkgDisplay $n
    return 1
}


proc ::tape::state::DeleteSelection {} {

    variable selection
    variable packages

    # Shortcut when asked to delete everything.
    if {[llength $selection] == [llength $packages]} {
	clear
	return
    }

    # Delete from back to front, to minimize move ops.
    foreach pidx [lsort -decreasing $selection] {
	DeletePkg $pidx
    }
    SetupDisplay
    return
}

proc ::tape::state::DeletePkg {idx} {
    variable idxmap
    variable packages
    variable clash

    # Things to make and do ...
    # - Scan through all items above and adjust their pindex
    #   Ditto adjust idxmap
    #   If pkg uses file list of deleted one, switch to see == 0.
    # - Squash the data array of the package
    # - Remove name from package list.

    set dvar $idxmap($idx)
    variable $dvar
    upvar  0 $idxmap($idx) del

    set j $idx ; incr idx
    for {set i $idx} {$i < [llength $packages]} {incr i ; incr j} {
	variable $idxmap($i)
	upvar  0 $idxmap($i) data
	incr data(pindex) -1
	set idxmap($j) $idxmap($i)
	if {$data(see) && [string equal $dvar $data(see,ref)]} {
	    set data(see) 0
	}
    }

    NameClash $del(name) {}
    incr clash() -1    

    unset idxmap($j)
    unset $dvar

    incr idx -1 ; # cancel up 1 before loop
    set packages [lreplace $packages $idx $idx]
    return
}

proc ::tape::state::deleteOk {} {
    # Query by GUI if deletion of packages is possible. Always.
    return 1
}

proc ::tape::state::addOk {} {
    # Query by GUI if creation of packages is possible. Always.
    return 1
}

proc ::tape::state::SwitchPkgDisplay {index} {
    ### Switch package display to data of specific package

    variable selection

    UpCall select    $index
    variable current $index
    UpCall refresh-current

    # Ensure a correct alias display for the package we have switched
    # to.

    variable idxmap
    variable $idxmap($current)
    upvar  0 $idxmap($current) data

    UpCall show-alias-ref $data(see)
    UpCall enable-files  [expr {!$data(see)}]

    # The first package cannot take the list of files of a different
    # package in the same tap file.

    if {$current == 0} {
	UpCall no-alias
    }

    # Update error display based on state of chosen package
    NameOk     $current
    VersionOk  $current
    PlatformOk $current
    SameAsOk   $current

    set selection [list $index]
    return
}

proc ::tape::state::DeactivatePkgDisplay {} {
    ### Switch package display to state where everything is disabled.

    #UpCall select    {}
    variable current {}

    UpCall show-alias-ref 0
    UpCall enable-files   0
    UpCall no-current
    return
}

proc ::tape::state::UpCall {args} {
    # Run the update callback
    variable upCmd
    log::log debug "$upCmd $args"
    return [uplevel \#0 [linsert $args 0 $upCmd do]]
}

# ==================================================================================
## Parser package definitions. Derived from parser in TclApp.
## Differences:
## - Check mode
## - Different storage backend
## - No substitution of place holders.
## = missing directories or files are
##   no impediment to the usage of a
##   file, only syntax violations are
##   

proc ::tape::state::LoadPackageDefinition {data {checking 0}} {
    # Process the package definitions found in the file.

    log::log debug "\tprocessing ..."

    # Transient package definition and processing status. Will be
    # written only if complete and without errors.

    ClearMap
    InitState tmp
    set       tmp(checking) $checking
    set       tmp(errors) {}

    foreach {cmd val} $data {
	switch -exact -- $cmd {
	    Package {
		if {$tmp(haspkg) && !$tmp(skip)} {
		    Store tmp
		}
		foreach {name version} $val { break }
		set e    $tmp(errors)
		InitState tmp $name $version
		set       tmp(checking) $checking
		set       tmp(errors) $e
		set       tmp(haspkg) 1
	    }
	    Hidden      {Hide          tmp}
	    See         {See           tmp $val}
	    Base        {SetBase       tmp $val __dummy__}
	    Path        {AddPattern    tmp $val}
	    ExcludePath {RemovePattern tmp $val}
	    Alias       {RenameFile    tmp $val}
	    Platform    {SetPlatform   tmp $val}
	    Desc        {AddDesc       tmp $val}
	    default {
		if {$checking} {
		    lappend tmp(errors) "Illegal keyword \"$cmd\""
		} else {
		    return -code error "Illegal keyword \"$cmd\""
		}
	    }
	}
    }

    if {$tmp(haspkg) && !$tmp(skip)} {
	Store tmp
    }
    ClearMap
    if {$checking && [llength $tmp(errors)] > 0 } {
	return -code error [join $tmp(errors) \n]
    }
    return
}


proc ::tape::state::InitState {var {name {}} {version {}}} {
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
	bases {}
	see 0 see,ref {} see,name {}
    }

    set tmp(name)    $name
    set tmp(version) $version
}


proc ::tape::state::SetBase {var val tapdir} {
    upvar 1 $var tmp

    # No handling of placeholders, no checking of existence.
    # tapdir = __dummy__ . required in the future ?


    if {$tmp(skip)} return
    set     tmp(base)  $val
    lappend tmp(bases) $val
    set     tmp(b,$val) ""
    return

    if 0 {
	variable basesubst
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
	    set tmp(skip) 1
	    return
	}
    }
}


proc ::tape::state::Hide {var} {
    upvar 1 $var tmp

    if {$tmp(skip)} return
    set tmp(hide) 1
    return
}


proc ::tape::state::See {var val} {
    upvar 1 $var tmp

    if {$tmp(skip) && !$tmp(checking)} return

    set token [DerefMap $val]
    if {$token == {}} {
	log::log debug "\tRefering unknown package \"$val\""
	set tmp(skip) 1
	lappend tmp(errors) "$tmp(name): Reference to undefined package \"$val\""
	return
    }

    set tmp(see)      1
    set tmp(see,ref)  $token
    set tmp(see,name) $val
    return
}


proc ::tape::state::AddDesc {var text} {
    upvar 1 $var tmp

    if {$tmp(skip)} return
    # expand, check and add.

    append tmp(desc) $text\n
}

proc ::tape::state::SetPlatform {var val} {
    upvar 1 $var tmp

    if {$tmp(skip)} return
    # expand, check and add.

    set tmp(platform) $val
}

proc ::tape::state::AddPattern {var pattern} {
    upvar 1 $var tmp

    if {$tmp(skip) && !$tmp(checking)} return
    # expand, check and add.

    # Need a base to work from
    if {$tmp(base) == {}} {
	log::log debug "\tPath \"$pattern\" has no base"
	set tmp(skip) 1
	lappend tmp(errors) "$tmp(name): Pattern \"$pattern\" is without base path"
	return
    }

    lappend tmp(b,$tmp(base)) [list include $pattern]
    return

    if 0 {
	variable filesubst
	set spattern [string map $filesubst $pattern]
	set expanded [glob -nocomplain -directory $tmp(base) $spattern]

	if {[llength $expanded] < 1} {
	    set tmp(skip) 1
	    log::log debug "\tNo files matching \"$pattern\""
	    return
	}
	foreach f $expanded {
	    if {[file isdirectory $f]} {
		# Directory, include everything.
		foreach ff [fileutil::find $f {file isfile}] {
		    set tmp(p,$ff) [tclapp::fres::StripLeading $tmp(base) $ff]
		}
	    } else {
		# Single file
		set tmp(p,$f) [tclapp::fres::StripLeading $tmp(base) $f]
	    }
	}
	return
    }
}


proc ::tape::state::RemovePattern {var pattern} {
    upvar 1 $var tmp

    if {$tmp(skip) && !$tmp(checking)} return

    # Need a base to work from
    if {$tmp(base) == {}} {
	log::log debug "\tExcludePath \"$pattern\" has no base"
	set tmp(skip) 1
	lappend tmp(errors) "$tmp(name): Pattern \"$pattern\" is without base path"
	return
    }
    # remove pattern

    lappend tmp(b,$tmp(base)) [list exclude $pattern]
    return

    if 0 {
	set fullpattern [file join $tmp(base) $pattern]

	foreach key [array names tmp p,$pattern] {
	    unset tmp($key)
	}
    }
}

proc ::tape::state::RenameFile {var val} {
    upvar 1 $var tmp

    if {$tmp(skip) && !$tmp(checking)} return

    foreach {old new} $val { break }

    # Need a base to work from
    if {$tmp(base) == {}} {
	log::log debug "\tAlias \"$val\" has no base"
	set tmp(skip) 1
	lappend tmp(errors) "$tmp(name): Alias \"$val\" is without base path"
	return
    }

    lappend tmp(b,$tmp(base)) [list alias $val]
    return

    if 0 {
	set fullpath [file join $tmp(base) $old]

	if {![info exists tmp(p,$fullpath)]} {
	    log::log debug "\tUnable to alias unknown file \"$old\""
	    set tmp(skip) 1
	    return
	}

	set olddst $tmp(p,$fullpath)
	set newdst [file join [file dirname $olddst] $new]
	set tmp(p,$fullpath) $newdst
	return
    }
}

proc ::tape::state::Store {var} {
    upvar 1 $var tmp
    variable packages
    variable idxmap
    variable id
    variable map

    if {$tmp(checking)} {
	# Map for deref of hidden names - Future checking
	set map($tmp(name)) __dummy__
	return
    }

    log::log debug "::tape::state::Store $tmp(name)-$tmp(version)[expr {$tmp(hide) ? " HIDDEN" : ""}][expr {$tmp(see) ? " -----> $tmp(see,name)" : ""}]"

    # Create storage for definition
    variable da$id
    upvar 0  da$id data
    set dvar da$id
    incr id

    # Make data persistent, except for transient parser state
    array set data [array get tmp]
    unset data(haspkg) data(skip) data(base) data(alias) \
	    data(errors) data(checking)

    # Update list of known packages and mapping from that list to the
    # actual data. We also maintain a back-pointer from data array to
    # index in list for when we have to change the list because of
    # changes in the data area.

    set       idxmap([llength $packages]) $dvar
    set data(pindex) [llength $packages]
    lappend packages $data(name)

    # Map for deref of hidden names
    set map($data(name)) $dvar

    NameClash {} $data(name)
    return
}

proc ::tape::state::ClearMap {} {
    variable  map
    unset     map
    array set map {}
    return
}

proc ::tape::state::DerefMap {name} {
    variable  map
    set res {}
    catch {set res $map($name)}
    return   $res
}

# ==================================================================================
# ==================================================================================

proc ::tape::state::ScanResult {path} {
    return [file join $path [file tail $path].tap]
}

proc ::tape::state::SaveState {path} {
    ::tcldevkit::config::WriteOrdered/2.0 $path [getState] \
	$::tcldevkit::appframe::appNameFile \
	[::tcldevkit::appframe::appVersion]
    return
}

# ==================================================================================
# ==================================================================================

namespace eval ::tape::state {
    # Callback used to update the UI.
    variable upCmd    ""     ; # Update callback, command prefix.

    # Data structures managed here.
    #
    # 1. List of package names
    #    In order of definition in the tap file.
    #    Index is key to other data structures.
    #
    # 1a. Array mapping list indices to the package data arrays.
    #
    # 2. One array per package containing its data.
    # 2a One value (key 'pindex') refers back to the
    #    location of the package in the list.
    #
    # 3. List index of the currently shown package, or
    #    empty if there is none.

    variable packages [list] ; # No packages known initially.

    variable  idxmap
    array set idxmap {}

    variable current {} ; # nothing shown


    # Counter for the generation of data array names
    variable id 0

    # transient data. Map package names to tokens, for deref
    # of hidden packages when used in a package definition file
    variable  map
    array set map {}

    # List of selected packages.
    variable selection {}

    # Scoreboard tracking name clashes
    variable  clash
    array set clash {}

    # Counter for new packages ... distinct id's
    variable newcnt 0

    # Full path to the .tap file currently loaded.

    variable inputfile {}
}

# ==================================================================================

package provide tape::state 1.0
