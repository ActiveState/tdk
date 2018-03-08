# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# ipeditor.tcl --
# -*- tcl -*-
#
#	UI to edit the OS X Info.plist meta data of a basekit/wrap result.
#
# Copyright (c) 2005-2007 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Requisites

package require snit              ; # Tcllib, OO core.
package require tipstack
package require tile
package require compiler          ; # License information
package require teapot::metadata::read
package require image ; image::file::here

# ### ### ### ######### ######### #########
## Implementation

snit::widget ipeditor {
    hulltype ttk::frame

    option -variable -default {}

    constructor {args} {
	# DEBUG # $hull configure -relief raised -bd 2 -bg coral

	dictentry $win.de \
	    -height 12 \
	    -labelks {OS X attribute} -labelkp {OS X attributes} \
	    -labelvs {value}          -labelvp {values} \
	    -titlek Attribute -titlev Value    \
	    -validk     [mymethod ValidKey]  \
	    -dictvariable [myvar dedat]      \
	    -removable [mymethod Removable?] \
	    -sort      [mymethod Sort]

	grid $win.de -column 0 -row 0 -sticky swen

	grid columnconfigure $win 0 -weight 1 -minsize 30
	grid rowconfigure    $win 0 -weight 1

	trace variable [myvar current] w [mymethod T/ExportIP]

	# Handle initial options. This implies the initialization of
	# our state too, as part of -variable processing.

	$self configurelist $args

	trace add variable [myvar dedat] write [mymethod GetDE]
	return
    }

    destructor {
	$self TM/Remove
	trace vdelete [myvar current] w [mymethod T/ExportIP]
	trace remove variable [myvar dedat] write [mymethod GetDE]
	return
    }

    # ### ### ### ######### ######### #########
    ## Object state

    variable rows           0  ; # Number of rows shown by the display to handle the stringinfo
    variable origin_si      {}
    variable origin_md      {}
    variable origin_osx     {}
    variable origin  -array {} ; # MD settings imported (defaults essentially)
    variable current -array {} ; # Current MD settings shown, possibly modified by the user

    variable noexport 0 ; # Flag controlling SI export, to prevent trace loops.
    variable noimport 0 ; # Flag controlling SI import, to prevent trace loops.

    variable dedat {} ; # Variable used to talk with the dictentry part

    # ### ### ### ######### ######### #########

    method reset {} {
	# Reset to initial state (i.e. completely empty).

	upvar #0 $options(-variable) state
	#puts RESET/$noexport$noimport

	# The write below triggers a re-import of the change, and due
	# to the merge-process on import, see Flow (a) for details.
	# This causes the settings to become the baseline SI settings
	# (from the prefix). Which we wanted, a reset to baseline.

	set state(infoplist) {}
	return
    }

    # ### ### ### ######### ######### #########
    # Option management

    onconfigure -variable {newvar} {
	# Ignore configure requests which change nothing
	if {$newvar eq $options(-variable)} return
	# Regenerate the traces
	$self TM/Remove
	set options(-variable) $newvar
	$self TM/Add
	# Reset state - [XX] Flow (a), Trigger (1)
	$self S/Initialize
	return
    }

    # ### ### ### ######### ######### #########
    # Trace management

    method TM/Add {} {
	if {$options(-variable) eq ""} return
	set statev $options(-variable)
	trace variable ${statev}(metadata)      w [mymethod T/MD]
	trace variable ${statev}(infoplist)     w [mymethod T/ImportIP]
	trace variable ${statev}(stringinfo)    w [mymethod T/StringInfo]
	trace variable ${statev}(wrap,out,osx)  w [mymethod T/OSX]
	return
    }

    method TM/Remove {} {
	if {$options(-variable) eq ""} return
	set statev $options(-variable)
	trace vdelete ${statev}(metadata)      w [mymethod T/MD]
	trace vdelete ${statev}(infoplist)     w [mymethod T/ImportIP]
	trace vdelete ${statev}(stringinfo)    w [mymethod T/StringInfo]
	trace vdelete ${statev}(wrap,out,osx)  w [mymethod T/OSX]
	return
    }

    # ### ### ### ######### ######### #########
    ## Trace callbacks

    method T/ExportIP {args} {
	# [XX] Flow (c), Trigger (1)
	if {$noexport} return
	#puts T/ExportIP\t($args)
	$self S/ExportIP
	return
    }

    method T/ImportIP {args} {
	# [XX] Flow (b), Trigger (1)
	if {$noimport} return
	#puts T/ImportIP\t($args)
	$self S/ImportIP
	$self UI/Make on
	return
    }

    method T/OSX {args} {
	upvar #0 $options(-variable) state
	if {$origin_osx eq $state(wrap,out,osx)} return
	#puts T/OSX\t($args)
	# [XX] Flow (a), Trigger (3)
	$self S/Initialize
	return
    }

    variable prio {}
    method T/MD {args} {
	upvar #0 $options(-variable) state
	if {$origin_md eq $state(metadata)} return
	#puts T/OSX\t($args)
	# [XX] Flow (a), Trigger (3)
	set prio metadata
	$self S/Initialize
	return
    }

    method T/StringInfo {args} {
	upvar #0 $options(-variable) state
	if {$origin_si eq $state(stringinfo)} return
	#puts T/OSX\t($args)
	# [XX] Flow (a), Trigger (3)
	set prio stringinfo
	$self S/Initialize
	return
    }

    # ### ### ### ######### ######### #########
    ## State manipulation

    proc GetState {key} {
	upvar 1 options options
	upvar #0 $options(-variable) state
	if {![info exists state($key)]} {return {}}
	return $state($key)
    }

    method S/Initialize {} {
	# Flow (a), Actions
	#puts S/Initialize/IP

	set origin_md [GetState metadata]
	set origin_si [GetState stringinfo]

	# Import prefix (name)
	# Import baseline MD from prefix
	# Import user MD
	# Update interface

	$self S/ImportOrigin
	$self S/ImportIP
	$self UI/Make on

	#puts S/Initialize\tOK
	return
    }

    method S/ImportOrigin {} {
	# Flow (a), Action - Import baseline MD from prefix.
	#puts S/ImportOrigin

	# Clear baseline
	# Merge from prefix, if possible

	array unset origin *

	if {$prio eq "stringinfo"} {
	    $self S/ImportOrigin/SI
	    $self S/ImportOrigin/TEAPOT
	} else {
	    $self S/ImportOrigin/TEAPOT
	    $self S/ImportOrigin/SI
	}
	$self S/ImportOrigin/Standard
	return
    }

    method S/ImportOrigin/SI {} {
	#puts \tS/ImportOrigin/SI

	upvar #0 $options(-variable) state

	# Inherit name and version from the windows String Resources

	array set md $origin_si

	foreach {k v} {
	    CFBundleName    ProductName
	    CFBundleVersion ProductVersion
	} {
	    if {
		(![info exists origin($k)] || ($origin($k) eq "")) &&
		[info exists md($v)]
	    } {
		# Nothing defined, or empty, and have something in the
		# teapot meta data => Take it.

		set origin($k) $md($v)
		#puts "$k = $md($v)"
	    }
	}
	return
    }

    method S/ImportOrigin/TEAPOT {} {
	#puts \tS/ImportOrigin/TEAPOT

	upvar #0 $options(-variable) state

	# Inherit name and version from the teapot meta data.

	array set md $origin_md

	foreach {k v} {
	    CFBundleName    name
	    CFBundleVersion version
	} {
	    if {
		(![info exists origin($k)] || ($origin($k) eq "")) &&
		[info exists md($v)]
	    } {
		# Nothing defined, or empty, and have something in the
		# teapot meta data => Take it.

		set origin($k) $md($v)
		#puts "$k = $md($v)"
	    }
	}
	return
    }

    method S/ImportOrigin/Standard {} {
	#puts \tS/ImportOrigin/Standard

	upvar #0 $options(-variable) state

	if {
	    ![info exists origin(CFBundleName)] ||
	    ($origin(CFBundleName) eq "")
	} {
	    # No name, or empty => Choose a default.

	    if {[catch {
		set out [file rootname [file tail $state(wrap,out)]]
	    }] || ($out eq "")} {
		set out {<Name of Application, please fill in>}
	    }
	    set origin(CFBundleName) $out
	}

	if {
	    ![info exists origin(CFBundleVersion)] ||
	    ($origin(CFBundleVersion) eq "")
	} {
	    # No version, or empty => Choose a default.

	    set origin(CFBundleVersion) {<Version of Application, please fill in>}
	}

	# OSX specifics. If -osxapp is set enter additional keys for
	# the users to fill in, if they do not exist, or are empty.

	if {$state(wrap,out,osx)} {
	    foreach {k default} {
		CFBundleGetInfoString      {<OS X Information String, please fill in>}
		CFBundleIdentifier         {<OS X Identifier, please fill in>}
		CFBundleDevelopmentRegion  English
		CFBundleShortVersionString {}
		CFBundleHelpBookFolder     {}
	    } {
		if {![info exists origin($k)] || ($origin($k) eq "")} {
		    set origin($k) $default
		}
	    }

	    if {![info exists origin(CFBundleSignature)]} {
		set origin(CFBundleSignature) ????
	    } else {
		set sign $origin(CFBundleSignature)
		append sign ????
		set origin(CFBundleSignature) [string toupper [string range $sign 0 3]]
	    }
	}
	return
    }

    method S/ImportIP {} {
	#puts S/ImportIP
	# Flow (a), Action - Import user MD settings
	# Flow (b), Action - ditto

	# Clear settings
	# Merge baseline
	# Merge external MD
	# Re-export merge result

	# Importing the current OS X info.plist. Start out empty, then
	# the origin data, then lay the actual current information
	# over that. This automatically merges all previous edits over
	# the new baseline. After completion we can re-export the
	# imported information, as it was possibly changed.

	set md [GetState infoplist]

	#puts \tReading:\t($md)

	DisableExport

	array unset current *
	if {![llength $md]} {
	    # No user defined MD, use origin for defaults.
	    array set current [array get origin]
	} else {
	    # User defined MD, all we want.
	    array set current $md
	}

	EnableExport
	$self S/ExportIP
	return
    }

    method S/ExportIP {} {
	#puts S/ExportIP
	# Flow (c), Action - Export dialog MD settings to user settings
	# Nothing if no change, everything for change, nothing if equal

	if {[$self S/OriginUnchanged]} {
	    set exportedvalue {}
	} else {
	    set exportedvalue [array get current]
	}

	upvar #0 $options(-variable) state

	if {
	    [info exists state(infoplist)] &&
	    ($state(infoplist) eq $exportedvalue)
	} return

	#puts \tWriting:\t($exportedvalue)

	DisableImport
	set state(infoplist) $exportedvalue
	EnableImport
	return
    }

    method S/OriginUnchanged {} {
	# Check if original string info is identical to edited string info.
	# Helper for S/ExportSI

	if {[array size origin] != [array size current]} {return 0}
	if {
	    [lsort [array names origin]] ne [lsort [array names current]]
	} {return 0}

	# Here we know that the sets of keys are identical. So now we
	# can compare the associated values.

	foreach k [array names current] {
	    if {$origin($k) ne $current($k)} {return 0}
	}

	return 1
    }

    # ### ### ### ######### ######### #########
    ## Manage locks for Import/Export actions

    proc DisableExport {} {upvar 1 noexport noexport ; set noexport 1 ; return ; puts -Ex ; return}
    proc EnableExport  {} {upvar 1 noexport noexport ; set noexport 0 ; return ; puts +Ex ; return}

    proc DisableImport {} {upvar 1 noimport noimport ; set noimport 1 ; return ; puts -In ; return}
    proc EnableImport  {} {upvar 1 noimport noimport ; set noimport 0 ; return ; puts +In ; return}

    # ### ### ### ######### ######### #########
    ## UI management

    method UI/Make {enable} {
	if {!$enable} {
	    set dedat {}
	    $win.de configure -state disabled
	} else {
	    set dedat [array get current]
	    $win.de configure -state normal
	}
	return
    }

    method GetDE {args} {
	DisableExport
	array unset current *
	array set   current $dedat
	EnableExport

	$self T/ExportIP
	return
    }

    method ValidKey {k} {
	if {$k eq ""} {
	    return Empty
	}
	return ""
    }

    method Removable? {k} {
	if {$k eq "CFBundleName"}     {return 0}
	if {$k eq "CFBundleVersion"}  {return 0}
	return 1
    }

    method Sort {keys} {
	set keys [lsort -dict $keys]
	foreach x {CFBundleVersion CFBundleName} {
	    set pos [lsearch -exact $keys $x]
	    if {$pos > 0} {
		set keys [linsert [lreplace $keys $pos $pos] 0 [lindex $keys $pos]]
	    }
	}
	return $keys
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide ipeditor 1.0
