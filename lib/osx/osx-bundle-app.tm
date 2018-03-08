# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package osx::bundle::app 0.1
# Meta platform    tcl
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Creating OS X .app bundles.

## The various routines use a dictionary for OS X meta data. The
## following keys are recognized. Unrecognized keys are ignored.

#		CFBundleExecutable		<automatic>
#		CFBundlePackageType		"APPL"
#		CFBundleInfoDictionaryVersion	"6.0"
# ------------	-----------------------------	-----------
# info		CFBundleGetInfoString		/optional
# id		CFBundleIdentifier		/optional
# region	CFBundleDevelopmentRegion	/optional
# sign		CFBundleSignature		/optional
# version	CFBundleVersion			/optional
# shortversion	CFBundleShortVersionString	/optional
# help		CFBundleHelpBookFolder		/optional
# icon		CFBundleIconFile		/optional

# ### ### ### ######### ######### #########
## Requirements

namespace eval ::osx::bundle::app {}

# ### ### ### ######### ######### #########
## Implementation

proc ::osx::bundle::app::create {exe appdir dict} {
    # Create a .app for an executable, in the appdir, using the OS X
    # meta data in dict. Assumes that the key 'help' is defined.

    DirStructure $appdir      $dict
    Executable   $appdir $exe
    Info         $appdir $exe $dict

    set md(help) ""
    array set md $dict

    if {
	[info exists md(CFBundleHelpBookFolder)] &&
	($md(CFBundleHelpBookFolder) ne "")
    } {
	set md(help) $md(CFBundleHelpBookFolder)
    }
    return $appdir/Contents/Resources/English.lproj/$md(help)
}

proc ::osx::bundle::app::scaffolding {appdir exe dict} {
    # Generate the basic structure of an .app, in the appdir, for the
    # executable exe, using the OSX meta data in dict.

    DirStructure $appdir      $dict
    Info         $appdir $exe $dict
    return
}

proc ::osx::bundle::app::DirStructure {appdir dict} {
    # Create the basic directory structure of an .app bundle.
    #
    # .app/Contents/
    # .app/Contents/Info.plist
    # .app/Contents/PkgInfo
    # .app/Contents/Resources/
    # .app/Contents/Resources/English.lproj	/optional
    # .app/Contents/Resources/<icon>		/optional
    # .app/Contents/MacOS/<executable>

    array set md $dict

    file mkdir $appdir/Contents/MacOS
    file mkdir $appdir/Contents/Resources

    if {
	([info exists md(help)]                    &&
	 ($md(help) ne ""))                        ||
	([info exists md(CFBundleHelpBookFolder)]  &&
	($md(CFBundleHelpBookFolder) ne ""))
    } {
	set dst $appdir/Contents/Resources/English.lproj
	file mkdir $dst

	# If requested copy the help tree into the bundle.
	if {[info exists md(x,help,copy)] && $md(x,help,copy)} {
	    if {
		[info exists md(CFBundleHelpBookFolder)] &&
		($md(CFBundleHelpBookFolder) ne "")
	    } {
		file copy -force $md(CFBundleHelpBookFolder) $dst
	    } elseif {
		[info exists md(help)] &&
		($md(help) ne "")
	    } {
		file copy -force $md(help) $dst
	    }
	}
    }
    # Copy the icon file into the bundle's directory tree, if present.
    if {
	[info exists md(CFBundleIconFile)] &&
	($md(CFBundleIconFile) ne "")
    } {
	file copy -force $md(CFBundleIconFile) $appdir/Contents/Resources/
    } elseif {
        [info exists md(icon)] &&
	($md(icon) ne "")
    } {
	file copy -force $md(icon) $appdir/Contents/Resources/
    }
    return
}

proc ::osx::bundle::app::Executable {appdir exe} {
    # Copy the executable into its place in the .app bundle.

    file copy -force $exe $appdir/Contents/MacOS/[file tail $exe]
    return
}

proc ::osx::bundle::app::Info {appdir exe dict} {
    # Generate OSX Meta data for the new bundle.
    # Map the incoming dict to Apple's keys

    array set md $dict

    # Translate old-style keys to regular bundle keys, if not
    # overriden by a bundle key.

    foreach {k ko} {
	version      CFBundleVersion
	sign         CFBundleSignature
	region       CFBundleDevelopmentRegion
	info         CFBundleGetInfoString
	id           CFBundleIdentifier
	shortversion CFBundleShortVersionString
	help         CFBundleHelpBookFolder
	icon         CFBundleIconFile
    } {
	if {[info exists md($k)]} {
	    if {[info exists md($ko)]} {
		unset md($k)
	    } else {
		set md($ko) $md($k)
	    }
	}
    }

    # Fix signature to be 4 characters, append blanks

    if {[info exists md(CFBundleSignature)]} {
	append md(CFBundleSignature) {    }
	set    md(CFBundleSignature) [string toupper \
		  [string range $md(CFBundleSignature) 0 3]]
    }

    # Shorten the path of an icon to its tail

    if {[info exists md(CFBundleIconFile)]} {
	set md(CFBundleIconFile) \
	    [file tail $md(CFBundleIconFile)]
    }

    # Shorten the path of a help book folder to its tail, if, and only
    # if the help tree was copied from the outside.

    if {
	[info exists md(CFBundleHelpBookFolder)] &&
	[info exists md(x,help,copy)] && $md(x,help,copy)
    } {
	set md(CFBundleHelpBookFolder) \
	    [file tail $md(CFBundleHelpBookFolder)]
    }

    # Remove all internal flags and indicators.
    array unset md x,*

    # Hardwired information, overrides anything the user may have
    # chosen.

    array set md {
	CFBundleInfoDictionaryVersion 6.0
	CFBundlePackageType           APPL
    }

    set md(CFBundleExecutable) [file tail $exe]

    fileutil::writeFile -encoding utf-8 \
	$appdir/Contents/Info.plist \
	[InfoString [array get md]]

    return
}

proc ::osx::bundle::app::InfoString {dict} {
    set lines {}
    lappend lines {<?xml version="1.0" encoding="UTF-8"?>}
    lappend lines {<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">}
    lappend lines {<plist version="1.0">}
    lappend lines {<dict>}

    set max 0
    foreach {k v} $dict {
	set l [string length $k]
	if {$l > $max} {set max $l}
    }
    foreach {k v} $dict {
	set blank [string repeat { } [expr {$max - [string length $k]}]]
	lappend lines "<key>${k}</key>$blank<string>${v}</string>"
    }
    lappend lines {</dict>}
    lappend lines {</plist>}
    return [join $lines \n]\n
}

# ### ### ### ######### ######### #########
## Ready
return
