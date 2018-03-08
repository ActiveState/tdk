# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::metadata::read 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     fileutil::magic::mimetype
# Meta require     logger
# Meta require     teapot::entity
# Meta require     teapot::metadata::container
# Meta require     teapot::reference
# Meta require     zipfile::decode
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Command for the extraction of meta data from a file uploaded into a
# repository. The code assumes that the uploaded file either has a
# non-binary header, or is zip archive with a .zip comment.

# I.e. even if binary data is at the end of tcl Module we have text at
# the beginning. It is further assumed that this text is Tcl
# code. Meta data is there fore stored using the syntax for the
# embbeded form.

# Otherwise the meta data is stored in the zip comment, in the
# external form.

# ### ### ### ######### ######### #########
## Requirements

package require fileutil                    ; # Directory traversal
package require fileutil::magic::mimetype   ; # Detect zip archive
package require logger                     ; # Tracing
package require teapot::metadata::container ; # Container for read meta data
package require teapot::reference           ; # Reference validation.
package require teapot::entity              ; # Entity enumeration & validation.
package require zipfile::decode             ; # Parsing zip archives
package require vfs
package require vfs::mk4

logger::initNamespace ::teapot::metadata::read
namespace eval        ::teapot::metadata::read {}

# ### ### ### ######### ######### #########
## API.
## Read from a file, auto-detect type.
## Read from a string, type is chosen by caller.

proc ::teapot::metadata::read::file {path mode ev {atv {}} {allowminor 0}} {
    upvar 1 $ev errors
    if {$atv ne ""} {upvar 1 $atv archivetype}

    log::debug "file ($path $mode)"

    set mdtext [ExtractFromArchive $path archivetype errors]
    if {[llength $errors]} return

    set packages [Parse $mdtext errors $allowminor]
    if {[llength $errors]} return

    if {($mode eq "single") && ([llength $packages] > 1)} {
	lappend errors "Illegal definition of multiple packages"
	Delete
	return {}
    }

    return $packages
}

proc ::teapot::metadata::read::fileEx {path mode ev {allowminor 0}} {
    upvar 1 $ev errors
    log::debug "fileEx ($path $mode)"

    return [string [fileutil::cat $path] $mode external errors $allowminor]
}

proc ::teapot::metadata::read::string {mdtext mode archivetype ev {allowminor 0}} {
    upvar 1 $ev errors
    if {$archivetype eq "tm"} {
	# Embbeded - 
	set mdtext [ExtractFromTMString $mdtext errors]
	if {[llength $errors]} return
    }

    set packages [Parse $mdtext errors $allowminor]
    if {[llength $errors]} return

    if {($mode eq "single") && ([llength $packages] > 1)} {
	lappend error "Illegal definition of multiple packages"
	Delete
	return {}
    }

    return $packages
}

proc ::teapot::metadata::read::locationTM {path} {
    variable eofcz

    set header [fileutil::cat -eofchar $eofcz $path]

    set smarker "\n# @@ Meta Begin"
    set emarker "# @@ Meta End\n"

    set begin [::string first $smarker $header]
    set stop  [::string first $emarker $header $begin]

    incr begin
    incr stop [::string length $emarker]
    incr stop -1

    return [list $begin [expr {$stop - $begin}]]
}


# ### ### ### ######### ######### #########
## Extraction core. Lift the raw meta data
## out of a package archive file. The result
## is always in external format.

proc ::teapot::metadata::read::ExtractFromArchive {path atv ev} {
    upvar 1 $atv archivetype $ev errors

    set mtypes [fileutil::magic::mimetype $path]

    if {[lsearch -exact $mtypes  "application/zip"] >= 0} {
	set archivetype zip
	return [ExtractFromZip $path errors]
    } else {
	set archivetype tm
	return [ExtractFromTM $path errors archivetype]
    }
}

proc ::teapot::metadata::read::ExtractFromZip {path ev} {
    upvar 1 $ev errors

    zipfile::decode::open $path
    set zd [zipfile::decode::archive]

    if {![zipfile::decode::hasfile $zd teapot.txt]} {
	zipfile::decode::close
	lappend errors "No TEAPOT meta data found in zip archive \"$path\", no teapot.txt"
	return {}
    }

    set data [zipfile::decode::getfile $zd teapot.txt]
    zipfile::decode::close

    return $data
}

proc ::teapot::metadata::read::ExtractFromTMString {string ev} {
    set meta [CollectBlock [ContentsString $string]]
    if {![::string length $meta]} {
	upvar 1 $ev errors
	lappend errors "No TEAPOT meta data found in TM archive \"<string>\", no embedded meta data block"
    }
}

proc ::teapot::metadata::read::ExtractFromTM {path ev atv} {
    variable eofcz
    upvar 1 $ev errors $atv archivetype

    set header [fileutil::cat -eofchar $eofcz $path]
    set meta   [CollectBlock $header]
    if {[::string length $meta]} {
	# MD was embedded in the file header.
	append archivetype -header
	return $meta
    }

    # Nothing was found in the file header. Check if the file has a
    # metakit filesystem attached. If yes, mount and look for a
    # teapot.txt in the toplevel directory. If present its contents
    # are the meta data.

    # The tested file is only read, not modified. We are mounting it
    # read-only expressing this, and to allow the input to be a
    # non-writable file too.

    if {[lsearch -exact [fileutil::fileType $path] metakit] >= 0} {
	if {![catch {
	    vfs::mk4::Mount $path $path -readonly
	}]} {
	    set c [::file join $path teapot.txt]
	    if {[::file exists $c] && [::file readable $c]} {
		set meta [fileutil::cat $c]
	    }
	}
	vfs::unmount $path
    }

    if {[::string length $meta]} {
	# MD was found in the attached filesystem
	append archivetype -mkvfs
	return $meta
    }

    # No metakit filesystem, or no teapot.txt. Giving up.
    lappend errors "No TEAPOT meta data found in TM archive \"$path\", no embedded meta data block"
    return {}
}

proc ::teapot::metadata::read::ContentsString {string} {
    variable ctrlz
    set pos [::string first $ctrlz $string]
    if {$pos < 0} {return $string}
    return [::string range $string 0 [incr pos -1]]
}

proc ::teapot::metadata::read::CollectBlock {header} {
    set collect 0
    set meta    {}
    foreach line [split $header \n] {
	# Ignore everything until the beginning of the meta data
	# block.

	if {[regexp "^# @@ Meta Begin" $line]} {
	    log::debug "META $line"
	    set collect 1
	    continue 
	}

	if {!$collect} continue

	log::debug "META $line"

	# Stop collecting meta data when we reach the end of the
	# block.

	if {[regexp "^# @@ Meta End" $line]} {
	    break
	}

	# We are inside of the Meta data block. Strip the comment
	# prefix from the line, i.e. transform the embedded meta
	# information back into the regular form.

	regsub "^\#\[ \t\]*" $line {} line
	lappend meta $line
    }

    return [join $meta \n]
}

# ### ### ### ######### ######### #########
## Internal commands. Parsing core.
## Defines which entity types are accepted [x].

proc ::teapot::metadata::read::Parse {mdtext ev allowminor} {
    # mdtext is expected to be in the 'external' format.
    upvar 1 $ev errors

    set i [interp create -safe]

    # Action for data collection ...
    interp alias $i Meta {} ::teapot::metadata::read::M

    # Actions for entity collection (new sections) ...

    foreach entity [teapot::entity::names] {
	set display [teapot::entity::display $entity]
	interp alias $i $display {} ::teapot::metadata::read::Entity $allowminor $entity
    }

    Init
    set code [catch {interp eval $i $mdtext} res]
    interp delete $i

    if {$code} {
	Delete
	lappend errors "Bad meta data syntax: [::string map {
	    {::teapot::metadata::read::} {}
	} $res]"
    } else {
	SaveLast
	Normalize
	Validate errors
    }

    variable packages
    return  $packages
}

# ### ### ### ######### ######### #########
## Parser status and basic helpers

namespace eval ::teapot::metadata::read {
    # Parser status ...
    variable packages {} ; # List of collected entitites
    variable package  {} ; # Container for current entity.
}

proc ::teapot::metadata::read::Init {} {
    variable packages {}
    variable package  {}
    return
}

proc ::teapot::metadata::read::Normalize {} {
    variable packages
    if {![llength $packages]} return

    # Special knowledge about dependencies, remove duplicates,
    # redundancies. Ditto for platform, in an effort to handle
    # crooked input better.

    foreach p $packages {
	if {[$p exists platform]} {
	    $p setfor platform [lsort -uniq [$p getfor platform]]
	}

	foreach what {require recommend} {
	    if {![$p exists $what]} continue
	    $p setfor $what \
		[teapot::reference::normalize \
		     [$p getfor $what]]
	}
    }
    return
}

proc ::teapot::metadata::read::Validate {ev} {
    variable packages
    upvar 1 $ev errors

    if {![llength $packages]} {
	lappend errors "No entities found"
	return 0
    }

    set errors {}
    foreach p $packages {
	set prefix "Bad meta data for [$p type] [$p identity]:"

	if {![$p exists platform]} {
	    lappend errors "$prefix Incomplete, no platform specified"
	    continue
	} elseif {[llength [$p getfor platform]] > 1} {
	    lappend errors "$prefix Multi-platform archives are not acceptable."
	    continue
	}

	foreach {what label} {
	    require   requirement
	    recommend recommendation
	} {
	    if {![$p exists $what]} continue

	    # Special knowledge about dependencies, check their
	    # syntax.

	    foreach ref [$p getfor $what] {
		if {![teapot::reference::valid $ref message]} {
		    lappend errors "$prefix Bad reference syntax in $label \"$ref\": $message"
		    continue
		}
	    }
	}
    }

    if {[llength $errors]} {
	Delete
	set packages {}
	return 0
    }
    return 1
}

proc ::teapot::metadata::read::Delete {} {
    variable   packages
    foreach p $packages {$p destroy}
    return
}

proc ::teapot::metadata::read::SaveLast {} {
    variable packages
    variable package

    if {$package eq ""} return

    lappend packages $package
    set package ""
    return
}

# ### ### ### ######### ######### #########
## Parser actions

proc ::teapot::metadata::read::Entity {allowminor type name version} {
    variable package

    SaveLast
    log::debug "New $type : $name $version"

    set package [teapot::metadata::container %AUTO%]

    if {$allowminor} {
	$package define $name 0 $type
	$package reversion_unchecked $version
    } else {
	$package define $name $version $type
    }
    return
}

proc ::teapot::metadata::read::M {key args} {
    variable package

    # Ignore everything before a package start ...
    if {$package eq ""} return

    log::debug "M $key = ($args)"

    $package addlist $key $args
    return
}

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::teapot::metadata::read {
    variable ctrlz \x1A
    variable eofcz [list $ctrlz $ctrlz]
}

# ### ### ### ######### ######### #########
## Ready

#teapot::metadata::read::log::debug "Package loaded"
return

