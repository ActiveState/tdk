# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tape_state.tcl --
# -*- tcl -*-
#
#	State module for Tap Editor application.
#	State of TEApot based packages.
#
# Copyright (c) 2007 ActiveState CRL.

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

package require platform
package require pref::teapot
package require struct::list
package require teapot::entity
package require teapot::instance
package require teapot::metadata::container
package require teapot::metadata::edit
package require teapot::metadata::read
package require teapot::metadata::scan
package require teapot::metadata::write
package require teapot::package::gen
package require teapot::version

# ==================================================================================
# ==================================================================================

namespace eval ::tape::teapot {}

# Dispatcher - singleton object.
proc ::tape::teapot {cmd args} {
    return [uplevel 1 [linsert $args 0 tape::teapot::$cmd]]
}

# ==================================================================================

proc ::tape::teapot::pkgListVar {} {
    # returns name of namespaced variable containing the list of
    # package names.

    return ::tape::teapot::pkgnames
}

proc ::tape::teapot::changeType {newtype} {
    variable curpkg
    if {$curpkg == {}} return
    if {$newtype eq [$curpkg type]} return
    $curpkg retype $newtype
    ::tcldevkit::appframe::markdirty
    UpdateName
    TypeOk
    return
}

proc ::tape::teapot::changeName {newname} {
    variable curpkg
    if {$curpkg == {}} return
    if {$newname eq [$curpkg name]} return
    $curpkg rename $newname
    ::tcldevkit::appframe::markdirty
    UpdateName
    NameOk
    return
}

proc ::tape::teapot::changeVersion {newversion} {
    variable curpkg
    if {$curpkg == {}} return
    if {$newversion eq [$curpkg version]} return
    $curpkg reversion_unchecked $newversion
    ::tcldevkit::appframe::markdirty
    UpdateName
    VersionOk
    return
}

proc ::tape::teapot::changeArch {newarch} {
    variable curpkg
    if {$curpkg == {}} return
    if {$newarch eq [lindex [$curpkg getfor platform] 0]} return
    $curpkg rearch $newarch
    ::tcldevkit::appframe::markdirty
    UpdateName
    PlatformOk
    return
}

proc ::tape::teapot::changeDescription {newdesc} {
    variable curpkg
    if {$curpkg == {}} return
    if {[$curpkg exists description] && ($newdesc eq [join [$curpkg getfor description]])} return
    $curpkg setfor description [split $newdesc]
    ::tcldevkit::appframe::markdirty
    return
}

proc ::tape::teapot::changeSummary {newsy} {
    variable curpkg
    if {$curpkg == {}} return
    if {[$curpkg exists summary] && ($newsy eq [join [$curpkg getfor summary]])} return
    if {$newsy eq ""} {
	$curpkg unset summary
    } else {
	$curpkg setfor summary [split $newsy]
    }
    ::tcldevkit::appframe::markdirty
    return
}

proc ::tape::teapot::changeCategory {newsy} {
    variable curpkg
    if {$curpkg == {}} return
    if {[$curpkg exists category] && ($newsy eq [join [$curpkg getfor category]])} return
    if {$newsy eq ""} {
	$curpkg unset category
    } else {
	$curpkg setfor category [split $newsy]
    }
    ::tcldevkit::appframe::markdirty
    return
}

proc ::tape::teapot::change {key newvalue} {
    variable curpkg
    if {$curpkg == {}} return
    if {[$curpkg exists $key] && ($newvalue eq [$curpkg getfor $key])} return
    $curpkg setfor $key $newvalue
    ::tcldevkit::appframe::markdirty
    return
}

proc ::tape::teapot::getType {} {
    variable curpkg
    return [$curpkg type]
}

proc ::tape::teapot::getName {} {
    variable curpkg
    return [$curpkg name]
}

proc ::tape::teapot::getVersion {} {
    variable curpkg
    return [$curpkg version]
}

proc ::tape::teapot::getArch {} {
    variable curpkg
    return [lindex [$curpkg getfor platform] 0]
}

proc ::tape::teapot::getDescription {} {
    variable curpkg
    if {![$curpkg exists description]} {return {}}
    return [string trim [join [$curpkg getfor description]]]
}

proc ::tape::teapot::getSummary {} {
    variable curpkg
    if {![$curpkg exists summary]} {return {}}
    return [string trim [join [$curpkg getfor summary]]]
}

proc ::tape::teapot::getCategory {} {
    variable curpkg
    if {![$curpkg exists category]} {return {}}
    return [string trim [join [$curpkg getfor category]]]
}

proc ::tape::teapot::get {key} {
    variable curpkg
    if {![$curpkg exists $key]} {return {}}
    return [$curpkg getfor $key]
}

# FUTURE: Create set/get which are type-specific: string, list, ...

proc ::tape::teapot::setdict {x} {
    variable curpkg
    # Merge old special data over into the new general data to be kept
    foreach {k v} [$curpkg get] {
	if {![isSpecial $k]} continue
	lappend x $k $v
    }
    $curpkg set $x
    return
}

proc ::tape::teapot::getdict {} {
    variable curpkg
    variable special

    # Remove all the keys which are handled specially, i.e. outside of
    # the panel for general metadata.

    array set md [$curpkg get]

    foreach k $special {
	::unset -nocomplain md($k)
    }

    # FUTURE: Plugin driven

    return [array get md]
}

proc ::tape::teapot::isSpecial {k} {
    variable panel
    return [info exists panel([string tolower $k])]
}

proc ::tape::teapot::panelOf {k} {
    variable panel
    return  $panel([string tolower $k])
}
namespace eval ::tape::teapot {
    variable  panel
    array set panel {
	category    Indexing
	description Basic
	entity      Basic
	excluded    Files
	included    Files
	name        Basic
	platform    Basic
	recommend   Recommendations
	require     Requirements
	subject     Indexing
	summary     Basic
	version     Basic
    }
    variable special [lsort -dict [array names panel]]
}

proc ::tape::teapot::UpdateName {} {
    variable curpkg
    variable current
    variable pkgnames

    set before [lindex $pkgnames $current]
    set after  [NameOf $curpkg]
    lset pkgnames $current $after
    NameClash $before $after
    return
}

proc ::tape::teapot::unset {key} {
    variable curpkg
    if {$curpkg == {}} return
    if {![$curpkg exists $key]} return
    return [$curpkg unset $key]
}

proc ::tape::teapot::pkgdir {} {
    variable inputfile
    variable inputtype
    if {$inputtype == {}}    {return {}}
    if {$inputtype ne "pot"} {return {}}
    if {$inputfile == {}}    {return {}}
    return [file normalize [file dirname $inputfile]]
}

proc ::tape::teapot::do {cmd args} {
    # command called by the package display widget whenever it needs
    # information from the state manager, and has to provide something

    # log::log debug "$cmd ([join $args ") ("])"

    switch -exact -- $cmd {
	get {
	    # Assume that this is called only for current != {}.
	    set key [lindex $args 0]
	    variable current
	    variable packages
	    set p [lindex $packages $current]
	    return [$p getfor $key]
	}
	default {
	    error "Unknown action \"$cmd\""
	}
    }
    return
}

proc ::tape::teapot::update {obj} {
    # Sets the callback command to use whenever the package display has to
    # change somehow.

    variable upCmd $obj
    return
}

proc ::tape::teapot::setSelectionTo {list} {
    # Tells the state which elements in the listbox are selected =
    # which packages.

    variable selection $list
    log::log debug "::tape::teapot::setSelectionTo $list"

    if {[llength $list] != 1} {
	# None selected, or multiple selected, cannot show a single package.

	DeactivatePkgDisplay
    } else {
	SwitchPkgDisplay [lindex $list 0]
    }
    return
}

proc ::tape::teapot::getState {} {
    # returns current state - Used to write md back to file/teabag
    variable packages

    # Enforce that everything shown in the display is known to us too.
    UpCall do select {}

    return $packages

    log::log debug "TAP = << $packages >>"
    return $tapstate
}

proc ::tape::teapot::clear {} {
    # clears current state

    variable selection
    variable packages
    variable pkgnames
    variable clash
    variable current
    variable curpkg

    DeactivatePkgDisplay

    foreach p $packages {
	$p destroy
    }

    set packages  {}
    set pkgnames  {}
    set selection {}
    set current   {}
    set curpkg    {}

    ::unset   clash
    variable  clash
    array set clash {}
    return
}

proc ::tape::teapot::check {data} {
    # Validate the provided data
    # -- Nothing --
    return
}

proc ::tape::teapot::setState {data} {
    # Set current state to data

    variable packages 
    variable pkgnames

    # The list of names will show the full identification (abbreviated
    # entity type, name, version, platform).

    set packages $data
    set pkgnames [struct::list map $data ::tape::teapot::NameOf]

    SetupDisplay
    return
}

proc ::tape::teapot::NameOf {p} {

    # We cannot use '$p instance' followed by split to get our
    # information. The method uses 'instance::cons' internally, and
    # that command will check its arguments. I.e. it will choke on
    # invalid information (like a temp. bad version number).

    set t [string index [teapot::entity::display [$p type]] 0]
    set n [$p name]
    set v [$p version]
    set a [lindex [$p getfor platform] 0]

    return "${t} ${n}-${v} ($a)"
}

proc ::tape::teapot::setInputFile {path} {
    variable inputfile $path
    variable inputtype pot

    # call into gui to refresh button and such.
    UpCall inputChanged

    # Tell the app.framework about the chosen project as well, so that
    # it can update the menus and such.
    ::tcldevkit::appframe::HasProject $path
    return
}

proc ::tape::teapot::resetInput {} {
    variable inputfile {}
    variable inputtype {}
    # call into gui to refresh button and such.
    UpCall inputChanged
    return
}

proc ::tape::teapot::getInputFile {} {
    variable inputfile
    return  $inputfile
}

proc ::tape::teapot::getInputType {} {
    variable inputtype
    return  $inputtype
}

# ==================================================================================
## Internal functionality

proc ::tape::teapot::Initialize {} {
    # Global initialization of package
    # Nothing for now.
    return
}

proc ::tape::teapot::NameClash {old new} {
    variable clash
    set change 0

    catch {
	incr clash($old) -1
	if {$clash($old) == 0} {
	    ::unset clash($old)
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
	variable pkgnames
	set i 0
	set notunique {The package is not uniquely identified}
	foreach pname $pkgnames {
	    if {$clash($pname) > 1} {
		UpCall do error@ $i type     $notunique
		UpCall do error@ $i name     $notunique
		UpCall do error@ $i version  $notunique
		UpCall do error@ $i platform $notunique
	    } else {
		UpCall do error@ $i type     {}
		UpCall do error@ $i name     {}
		UpCall do error@ $i version  {}
		UpCall do error@ $i platform {}
	    }
	    incr i
	}
    }
}

proc ::tape::teapot::Unique {field} {
    variable pkgnames
    variable clash
    variable current

    set id [lindex $pkgnames $current]
    if {[info exists clash($id)] && ($clash($id) > 1)} {
	# Report existing name clash
	UpCall do error@ $current $field {The package is not uniquely identified}
	return -code return
    }
    return
}

proc ::tape::teapot::TypeOk {} {
    variable current
    variable curpkg

    Unique type
    return
}
proc ::tape::teapot::NameOk {} {
    variable current
    variable curpkg

    Unique name
    if {[$curpkg name] eq ""} {
	# Highlight as problem
	UpCall do error@ $current name {The name of the package is empty, and should not be}
    } else {
	UpCall do error@ $current name {}
    }
    return
}

proc ::tape::teapot::VersionOk {} {
    variable current
    variable curpkg

    Unique version
    if {![teapot::version::valid [$curpkg version] msg]} {
	# Highlight as problem
	UpCall do error@ $current version $msg
    } else {
	UpCall do error@ $current version {}
    }
    return
}

proc ::tape::teapot::PlatformOk {} {
    variable current
    variable curpkg

    Unique platform
    # ** TODO ** - teapot:: xxx platform xxx
    # ** TODO ** - Need some type validation for platform codes
    if {
	![$curpkg exists platform] ||
	([$curpkg getfirst platform] eq "")
    } {
	# Highlight as problem
	UpCall do error@ $current platform {The platform of the package is empty, and should not be}
    } else {
	UpCall do error@ $current platform {}
    }
    return
}

proc ::tape::teapot::SetupDisplay {} {
    # Select first package for display
    variable packages
    variable current {}
    variable curpkg  {}

    if {[llength $packages] > 0} {
	SwitchPkgDisplay 0
    } else {
	DeactivatePkgDisplay
    }
}

proc ::tape::teapot::NewTap {} {
    UpCall reset_tap
}

proc ::tape::teapot::NewPackage {} {
    # We use commands from the parser below to setup things.
    # The work-horse here is the 'Store' command which creates
    # all the relevant data structures. We provide a dummy name.

    variable packages
    variable pkgnames
    variable newcnt
    variable inputtype

    if {$inputtype eq ""} {
	set inputtype pot
    }

    set l [llength $packages]
    set n "New package [incr newcnt]"
    set p [teapot::metadata::container %AUTO%]

    $p define $n 0
    $p set [list platform [list [platform::identify]]]

    lappend packages $p
    lappend pkgnames [set name [NameOf $p]]

    NameClash {} $name

    # Select new package for immediate editing.
    SwitchPkgDisplay $l
    return
}

proc ::tape::teapot::NSPL {log level text} {
    uplevel \#0 [linsert $log end $level $text]
    return
}

proc ::tape::teapot::NewScanPackage {dir log} {
    variable inputtype
    variable packages
    variable pkgnames
    variable xlog $log

    set n [llength $packages]

    if {$inputtype eq ""} {
	set inputtype pot
    }

    set mds [teapot::metadata::scan %AUTO% $dir \
		 -log [list ::tape::teapot::NSPL $log]]

    $mds hints= {
	options registry -platform windows
	options dde      -platform windows
    }

    if {[catch {
	set scanresult [$mds scan]
    }]} {
	NSPL $log error { }
	NSPL $log error {ERROR	INTERNAL ERROR}
	foreach line [split $::errorInfo \n] {
	    NSPL $log error ERROR\t$line
	}
	NSPL $log error {ERROR	INTERNAL ERROR}
	NSPL $log error { }

	$mds destroy
	return 0
    }

    if {[llength $scanresult]} {
	NSPL $log info   { }
	NSPL $log notice {Adding to the project ...}

	foreach p $scanresult {
	    # Convert the internal formal form of references into the
	    # human readable form for use by the interface.

	    foreach k {require recommend} {
		if {![$p exists $k]} continue
		$p setfor $k [struct::list map [$p getfor $k] \
				  ::teapot::reference::ref2tcl]
	    }

	    lappend packages $p
	    lappend pkgnames [set name [NameOf $p]]
	    NameClash {} $name

	    NSPL $log info "    $name"
	}

	# Select first of the new packages for immediate editing.
	SwitchPkgDisplay $n
    }

    $mds destroy

    return 1
}

proc ::tape::teapot::ExpandToDir {dst log} {
    variable packages
    variable inputfile

    # Expand the archive held in our state into the destination
    # directory. The latter is created as needed. This is essentially
    # the same done by the TDK tclapp wrap-engine
    # (lib/wrapengine/tclapp_pkg.tcl, wrapFile).

    # Code snarfed from that location. Modified (always verbose, log
    # via callback). Also used by Tteapot-pkg.  => FUTURE: Factor into
    # its own package.

    # Get md first ...

    set p [lindex $packages 0]
    set pname    [$p name]
    set pversion [$p version]

    NSPL $log notice "Destination: $ed_dir"
    NSPL $log notice "Expanding:   [$p type] $pname $pversion ..."
    NSPL $log info   " "

    # Distinguish 3 cases

    # 1. Zip archive.
    # 2. Tcl Module with attached Metakit filesystem
    # 3. Tcl Module without attached Metakit filesystem

    # (Ad 1) Mount as filesystem, copy all files into the dst.
    # (ad 2) Mount as fs, copy all files into dir. copy prefix code
    #        as separate file, create pkgIndex for it.
    # (Ad 3) Generate pkgIndex for it and copy into dst dir

    # Could optimize access to type of archive (have iti n the
    # state. not done to keep changes small, ease refactoring this
    # again).

    set src $inputfile

    set mtypes [fileutil::magic::mimetype $src]
    if {[lsearch -exact $mtypes "application/zip"] >= 0} {
	# Ad (1) Zip archive.

	NSPL $log info "    Zip archive"
	NSPL $log info "      Unpacking"

	zipfile::decode::open $src
	set zdict [zipfile::decode::archive]

	NSPL $log info "      Copying contents"

	file mkdir                    $dst
	zipfile::decode::unzip $zdict $dst
	zipfile::decode::close

    } else {
	# Ad (2,3) Tcl Module.

	set entry implementation.tcl

	NSPL $log info "    Tcl Module"

	# Strip the block of data which was insert by the package
	# generator. If we do not do this the addition of such a
	# block by the next round of generation will cause the header
	# to continously expand, always with the same code.

	set lines [split [fileutil::cat $src -eofchar \x1A $src] \n]
	set start [lsearch -glob $lines {*TEAPOT-PKG BEGIN TM*}]
	set stop  [lsearch -glob $lines {*TEAPOT-PKG END TM*}]
	set del 0
	set kitsrc $src

	if {($start >= 0) && ($stop >= 0) && ($start < $stop)} {
	    NSPL $log info "    Stripping teapot-pkg generate'd block"

	    set t [fileutil::tempfile tclpe]
	    fileutil::writeFile $t [join [lreplace $lines $start $stop] \n]\n
	    set src $t
	    set del 1
	}

	if {[lsearch -exact [fileutil::fileType $src] metakit] >= 0} {
	    # (Ad 2) With attached metakit filesystem. Mount and copy.

	    NSPL $log info "      Copying attached filesystem"

	    # readonly! Because we do not modify, and the temp files
	    # will be set ro too, and writable mounting would fail
	    # due to that.

	    vfs::mk4::Mount  $kitsrc $kitsrc -readonly
	    file mkdir            $dst
	    file copy -force $kitsrc $dst
	    vfs::unmount     $kitsrc

	    if {[file exists [file join $dst $entry]]} {
		set n
		set base implementation
		while {[file exists [file join $dst $base$n.tcl]]} {incr n}
		set entry $base$n.tcl
	    }

	    NSPL $log info "      Generating entrypoint"

	    fileutil::writeFile [file join $dst $entry] \
		[fileutil::cat -eofchar \x1A $src]

	} else {
	    # (Ad 3) Without attached metakit filesystem.

	    NSPL $log info "    Copying as is"

	    file mkdir $dst
	    file copy -force $src [file join $dst $entry]
	}

	if {$del} {
	    # Clean up the temp file needed to strip the teapot-pkg block.
	    file delete $src
	}

	# Generate package index.

	NSPL $log info "      Generating package index"

	fileutil::writeFile [file join $dst pkgIndex.tcl] \
	    [string map \
		 [list NAME $pname VER $pversion ENTRY $entry] \
		 {package ifneeded {NAME} VER [list source [file join $dir ENTRY]]}]\n
    }

    NSPL $log info "      Generating metadata ..."

    fileutil::writeFile [file join $dst teapot.txt] \
	[::teapot::metadata::write::getStringExternalC $p]

    NSPL $log info   " "
    NSPL $log notice "Ok"
    return
}

proc ::tape::teapot::GenArchives {type dir compile stamp log} {
    variable inputfile

    # Force unsaved state to the filesystem for the package generator
    # to pick up.
    SaveTeapot $inputfile 0

    if {$stamp} {
	set stamp [string map {.0 .} \
		       [clock format [clock seconds] \
			    -gmt 1 -format {.%Y.%m.%d.%H.%M.%S}]]
    } else {
	set stamp {}
    }

    # Standard message level.
    lappend log info

    array set config [list \
			  artype    $type \
			  respath   $dir \
			  timestamp $stamp \
			  arinfix   {} \
			  logcmd    $log \
			  compile   $compile]

    file mkdir $dir
    ::teapot::package::gen::ignore [pref::teapot::ignorePatternList]
    ::teapot::package::gen::do     [file dirname $inputfile] config
    return
}

proc ::tape::teapot::DeleteSelection {} {
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
	::update
    }
    SetupDisplay
    return
}

proc ::tape::teapot::DeletePkg {idx} {
    variable packages
    variable pkgnames
    variable clash

    set pname [lindex $pkgnames $idx]

    NameClash $pname {}
    incr clash() -1    

    #?? incr idx -1 ; # cancel up 1 before loop
    set packages [lreplace $packages $idx $idx]
    set pkgnames [lreplace $pkgnames $idx $idx]
    return
}

proc ::tape::teapot::deleteOk {} {
    # Query by GUI if deletion of packages is possible. Not for teabags.
    variable inputtype
    return [expr {$inputtype eq "pot"}]
}

proc ::tape::teapot::addOk {} {
    # Query by GUI if adding of packages is possible. Not for teabags.
    variable inputtype
    return [expr {($inputtype eq "pot") || ($inputtype eq "")}]
}

proc ::tape::teapot::SwitchPkgDisplay {index} {
    ### Switch package display to data of specific package

    variable packages
    variable current
    variable curpkg
    variable selection
    variable inputtype

    UpCall do select    $index
    set current         $index
    set curpkg  [lindex $packages $index]
    UpCall do refresh-current

    # File information editing only for pot files, not permitted
    # for (wrapped) tm/zip/kit/exe files, i.e. teabags.
    UpCall do enable-files [expr {$inputtype eq "pot"}]

    # Update error display based on the state of chosen package
    TypeOk
    NameOk
    VersionOk
    PlatformOk

    set selection [list $index]
    return
}

proc ::tape::teapot::DeactivatePkgDisplay {} {
    # Switch package display to state where everything is disabled.
    variable current
    variable curpkg

    #UpCall do select {}
    set current   {}
    set curpkg    {}
    UpCall do enable-files 0
    UpCall do no-current
    return
}

proc ::tape::teapot::UpCall {args} {
    # Run the update callback
    variable upCmd
    log::log debug "$upCmd $args"
    return [uplevel \#0 [linsert $args 0 $upCmd]]
}

# ==================================================================================
# ==================================================================================

proc ::tape::teapot::LoadTeapot {path mv} {
    upvar 1 $mv message

    # Load a teapot package. Can be .tm, .zip, .kit, .exe, or
    # teapot.txt (in the directory of the package(s)). In case of a
    # .tm file it may or may not have an attached Mk filesystem.
    # In that case it is more likely a .kit or .exe.

    # First we assume that the file is a plain teapot.txt and try to
    # get the meta data directly from it. Should that fail we try
    # again, using the assumption that the file is an archive of some
    # kind. We non-fatally reject the file if that second try fails as
    # well.

    set errors {}
    set artype {}

    # 1 = allow minor errors, currently syntax error in version number
    set plist [::teapot::metadata::read::fileEx $path all errors 1]

    #puts EX\t[llength $plist]|$errors|

    if {[llength $errors]} {
	set msg    [join $errors \n]
	set errors {}
	set plist  [::teapot::metadata::read::file $path all errors artype 1]

	if {[llength $errors]} {
	    set message ${msg}\n[join $errors \n]
	    return rejected
	}
	# artype in <zip, tm-header, tm-mkvfs>
	#set artype [lindex [split $artype -] 0]
    } else {
	set artype pot
    }
    # artype in <zip, tm-*, pot>
    # The file is acceptable to this loader. From here on errors are fatal.

    variable inputfile [file normalize $path]
    variable inputtype $artype

    # Convert the internal formal form of references into the human
    # readable form for use by the interface.

    foreach p $plist {
	foreach k {require recommend} {
	    if {![$p exists $k]} continue
	    $p setfor $k [struct::list map [$p getfor $k] \
			      ::teapot::reference::ref2tcl]
	}
    }

    if {[catch {
	UpCall potConfigSet $plist
    } msg]} {
	set message $msg
	return fatal
    }

    # File was not only accepted but sucessfully read and stored into
    # the application state. We are good.
    return ok
}

# ==================================================================================
# ==================================================================================

proc ::tape::teapot::MenuTeapot {loadstate} {
    # This is hooked the system setting the state of the menu buttons
    # for save(as).

    #puts MT/$loadstate/[UpCall ProjectType?]

    if {[UpCall ProjectType?] eq "tap"} {
	# Fall back to the standard command if we are looking at a tap project.
	::tcldevkit::appframe::SaveMenuState $loadstate
	return
    }

    # Menu handling for teapot projects.

    # 1. Teabags: zip, tm (tm+mk : kit, exe).
    #    (a) No project  - Impossible configuration  (2a is default state)
    #    (b) Has project - save/saveas ok

    # 2. teapot.txt
    #    (a) No project  - save/saves disabled (Default!)
    #    (b) Has project - save ok, saveas disabled.

    variable inputtype

    if {($inputtype eq "pot") || ($inputtype eq "")} {
	if {$loadstate eq "hasproject"} {
	    tcldevkit::appframe::menu save   -> normal
	    tcldevkit::appframe::menu saveas -> disabled
	} else {
	    tcldevkit::appframe::menu save   -> disabled
	    tcldevkit::appframe::menu saveas -> disabled
	}
	return
    }

    # input is zip, tm - loadstate noproject is impossible.
    if {$loadstate ne "hasproject"} {
	return -code error "Inconsistent internal state, bag&no-project"
    }

    tcldevkit::appframe::menu save   -> normal
    tcldevkit::appframe::menu saveas -> normal
    return
}

# ==================================================================================
# ==================================================================================

proc ::tape::teapot::SaveExtTeapot {cmd} {

    if {[UpCall ProjectType?] eq "tap"} {
	# Tap files ...

	if {$cmd eq "all"} {
	    return {{TAP {.tap}} {All {*}}}
	} else {
	    return .tap
	}
    }

    # TEApot project, can be general, or various forms of archives

    variable inputtype

    switch -exact -- $inputtype {
	{} -
	pot {
	    if {$cmd eq "all"} {
		return {{POT {.txt}} {All {*}}}
	    } else {
		return .txt
	    }
	}
	tm-header {
	    if {$cmd eq "all"} {
		return {{TM {.tm}} {All {*}}}
	    } else {
		return .tm
	    }
	}
	tm-mkvfs {
	    if {$cmd eq "all"} {
		return {{TM {.tm}} {EXE {.exe}} {KIT {.kit}} {All {*}}}
	    } else {
		return .tm
	    }
	}
	zip {
	    if {$cmd eq "all"} {
		return {{ZIP {.zip}} {All {*}}}
	    } else {
		return .zip
	    }
	}
    }
}

proc ::tape::teapot::SaveTeapot {path saveas} {
    # This is hooked into the system for the saving of the currently
    # loaded project.

    if {[UpCall ProjectType?] eq "tap"} {
	# Fall back to the standard command if we are looking at a tap project.
	::tcldevkit::appframe::SaveConfig $path $saveas
	return
    }

    # Save TEApot based projects now.

    # Enforce that everything shown in the display is known to us too.
    UpCall do select {}

    variable inputtype
    variable packages

    if {$inputtype ne "pot"} {
	# Saving to a teabag.

	if {$saveas} {
	    variable inputfile
	    file copy -force $inputfile $path
	}

	# !saveas => (path == inputfile)
	# teabags imply that a single entity is shown and under edit.
	# I.e. llength package == 1

	# Another assumption we can make is that the 'inputtype'
	# contains the 'artype' of the archive in question, as
	# delivered by 'metadata::read::file' upon loading it. This
	# allows us to use a non-public low-level command of
	# metadata::edit, as we can feed it all the required
	# information. The public highlevel command would re-read the
	# information, and also require us to convert the meta data
	# into a different format (set of changes).

	::teapot::metadata::edit::Recreate $path $inputtype \
	    [lindex $packages 0]
	return
    }

    # Saving to an external teapot project, path == inputfile
    # SaveAs is not possible here.

    if {$saveas} {
	return -code error \
	    "Internal error, trying to do saveas teapot.txt, not possible"
    }

    SaveState $path
    return
}

proc ::tape::teapot::ScanResult {path} {
    return [file join $path teapot.txt]
}

proc ::tape::teapot::SaveState {path} {
    variable packages

    set md ""
    foreach p $packages {
	append md [::teapot::metadata::write::getStringExternalC $p]\n
    }

    fileutil::writeFile $path $md
}

# ==================================================================================

namespace eval ::tape::teapot {
    # Callback used to update the UI.
    variable upCmd    ""     ; # Update callback, command prefix.

    # Data structures managed here.
    #
    # 1. List of package. Each package is represented by an
    #    object, a teapot meta data container. The objects
    #    are listed in the order of their occurence in the
    #    meta data.
    #
    # 1a. List of package names, as extracted from the containers, in
    #     the same order, for the display.

    # 2. List index of the currently shown package, or
    #    empty if there is none.
    #
    # 2a. Currently used container.

    variable packages {} ; # No packages known initially.
    variable pkgnames {} ; # Ditto.
    variable current  {} ; # Nothing shown
    variable curpkg   {} ;

    # List of selected packages.
    variable selection {}

    # Scoreboard tracking name clashes.
    # Indexed by package names, value counts the number of uses.
    variable  clash
    array set clash {}

    # Counter for new packages ... distinct id's
    variable newcnt 0

    # Absolute path type of the file the metadata is coming from. The
    # type determines how much we can edit the metadata. See below.
    # Types are: zip, tm, pot

    variable inputfile {}
    variable inputtype {}

    # What     Notes       Actions                  Type
    #                      +Pkg -Pkg Edit File-Edit
    # ---- --- ----------- ---- ---- ---- --------- ----
    # .zip ZIP General     No   No   Yes  No        zip
    #          >=1 Package
    # ---- --- ----------- ---- ---- ---- --------- ----
    # .tm  TM  Tcl Module  No   No   Yes  No        tm
    # .kit KIT Starkit     No   No   Yes  No
    # .exe EXE Starpack    No   No   Yes  No
    #          1 Package
    # ---- --- ----------- ---- ---- ---- --------- ----
    # .txt POT Directory   Yes  Yes  Yes  Yes       pot
    #          >=0 Package
    # ---- --- ----------- ---- ---- ---- --------- ----
    #
    # +Pkg      : Add package to the meta data
    # -Pkg      : Delete package from the meta data
    # Edit      : Change the meta data of the available packages
    # File-Edit : Add/Delete/Modify file-information in the meta data
    #             (includes, excludes)
    #
    # Only a generic teapot.txt in a directory allows full editing of
    # all information. When the metadata comes out of a packaged
    # teabag the only thing editable is the meta data itself,
    # excluding file information if present. However it is not
    # possible to add/remove packages from a teabag, nor is it
    # possible to modify any existing file information.
}

# ==================================================================================

package provide tape::teapot 1.0
