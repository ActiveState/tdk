# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# sieditor.tcl --
# -*- tcl -*-
#
#	UI to edit the windows string resources of a basekit/wrap result.
#
# Copyright (c) 2005-2009 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Requisites

package require snit              ; # Tcllib, OO core.
package require dictentry
package require stringfileinfo
package require tile

# ### ### ### ######### ######### #########
## Implementation

snit::widget sieditor {
    hulltype ttk::frame

    option -variable -default {}
    # state variable of 'wrapper' widget.
    #
    # Keys relevant to the dialog.
    # - wrap,executable
    # - stringinfo
    #
    # Dataflows based on external and internal state. [XX]
    #
    # (a) "Initialization". Triggered by:
    #     (1) Actual change to option -variable
    #     (2) Actual change to prefix in state -variable
    #     Actions triggered:
    #     - Import name of current(1)/new(2) prefix
    #     - Import baseline SI settings from prefix
    #       - clear baseline
    #       - merge from prefix, if possible
    #       - extend/modify based on TDK license found
    #     - Import user SI settings
    #       - Clear settings
    #       - Merge baseline
    #       - Merge user SI settings, ignore keys unknown to baseline
    #       During this exporting is disabled
    #       - Re-export the fully merged SI settings, they may have
    #         changed due to dropped keys, or edits now equal to the
    #         new baseline.
    #     - Update Interface
    #
    # (b) "Update SI". Triggered by:
    #     (1) Change to user SI settings (Like caused by loading a different project)
    #     Actions triggered:
    #     - Import user SI settings. Details s.a.
    #
    # (c) "Edit". Triggered by:
    #     (1) Changes to the dialog SI settings.
    #     Actions triggered
    #     - Export dialog SI setttings to user SI settings
    #       - X = nothing if dialog SI is equal to baseline SI
    #       - X = everything in case of differences to baseline
    #       - however do nothing if X = user SI settings already
    #       During the export importing is disabled.

    constructor {args} {
	# DEBUG # $hull configure -relief raised -bd 2 -bg coral

	dictentry $win.de \
	    -height 12 -addremove 0 \
	    -labelks {keyword} -labelkp {keywords} \
	    -labelvs {value}   -labelvp {values} \
	    -titlek Keyword -titlev Value    \
	    -dictvariable [myvar dedat]      \
	    -sort         [mymethod Sort] -editk 0
		
	grid $win.de -column 0 -row 0 -sticky swen

	grid columnconfigure $win 0 -weight 1 -minsize 30
	grid rowconfigure    $win 0 -weight 1

	trace variable [myvar current] w [mymethod T/ExportSI]

	# Handle initial options. This implies the initialization of
	# our state too, as part of -variable processing.

	$self configurelist $args

	trace add variable [myvar dedat] write [mymethod GetDE]
	return
    }

    destructor {
	$self TM/Remove
	trace vdelete [myvar current] w [mymethod T/ExportSI]
	trace remove variable [myvar dedat] write [mymethod GetDE]
	return
    }

    # ### ### ### ######### ######### #########
    ## Object state

    variable rows           0  ; # Number of rows shown by the display to handle the stringinfo
    variable origin_md      {} ; # StringInfo settings which are in 'origin'
    variable origin_ip      {} ; # OS X settings which are in 'origin'
    variable origin_exe     {} ; # Prefix whose SI settings are in 'origin'
    variable origin  -array {} ; # SI settings imported from the current prefix
    variable current -array {} ; # Current SI settings shown, possibly modified by the user
    variable nv -array {}

    variable noexport 0 ; # Flag controlling SI export, to prevent trace loops.
    variable noimport 0 ; # Flag controlling SI import, to prevent trace loops.

    variable dedat {} ; # Variable used to talk with the dictentry part

    # ### ### ### ######### ######### #########

    method reset {} {
	upvar #0 $options(-variable) state
	#puts RESET/$noexport$noimport

	# The write below triggers a re-import of the change, and due
	# to the merge-process on import, see Flow (a) for details.
	# This causes the settings to become the baseline SI settings
	# (from the prefix). Which we wanted, a reset to baseline.

	set state(stringinfo) {}
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
	trace variable ${statev}(wrap,executable) w [mymethod T/Prefix]
	trace variable ${statev}(stringinfo)      w [mymethod T/ImportSI]
	trace variable ${statev}(infoplist)       w [mymethod T/InfoPlist]
	trace variable ${statev}(metadata)        w [mymethod T/MD]
	return
    }

    method TM/Remove {} {
	if {$options(-variable) eq ""} return
	set statev $options(-variable)
	trace vdelete ${statev}(wrap,executable) w [mymethod T/Prefix]
	trace vdelete ${statev}(stringinfo)      w [mymethod T/ImportSI]
	trace vdelete ${statev}(infoplist)       w [mymethod T/InfoPlist]
	trace vdelete ${statev}(metadata)        w [mymethod T/MD]
	return
    }

    # ### ### ### ######### ######### #########
    ## Trace callbacks

    method T/ExportSI {args} {
	# [XX] Flow (c), Trigger (1)
	if {$noexport} return
	#puts T/ExportSI\t($args)
	$self S/ExportSI
	return
    }

    method T/ImportSI {args} {
	# [XX] Flow (b), Trigger (1)
	if {$noimport} return
	#puts T/ImportSI\t($args)
	$self S/ImportSI
	$self UI/Make on
	return
    }

    method T/Prefix {args} {
	upvar #0 $options(-variable) state
	if {$origin_exe eq $state(wrap,executable)} return
	#puts T/Prefix\t($args)
	# [XX] Flow (a), Trigger (2)
	set prio {}
	$self S/Initialize
	return
    }

    variable prio {}
    method T/InfoPlist {args} {
	upvar #0 $options(-variable) state
	if {$origin_ip eq $state(infoplist)} return
	#puts T/Prefix\t($args)
	# [XX] Flow (a), Trigger (2)
	set prio infoplist
	$self S/Initialize
	return
    }

    method T/MD {args} {
	upvar #0 $options(-variable) state
	if {$origin_md eq $state(metadata)} return
	#puts T/Prefix\t($args)
	# [XX] Flow (a), Trigger (2)
	set prio metadata
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
	#puts S/Initialize/SI

	upvar #0 $options(-variable) state

	# Import prefix (name)
	# Import baseline SI from prefix
	# Import user SI
	# Update interface

	set origin_exe $state(wrap,executable)
	set origin_ip  [GetState infoplist]
	set origin_md  [GetState metadata]

	$self S/ImportOrigin
	$self S/ImportSI
	$self UI/Make [expr {$origin_exe ne ""}]

	#puts S/Initialize\tOK
	return
    }

    method S/ImportOrigin {} {
	# Flow (a), Action - Import baseline SI from prefix.
	#puts S/ImportOrigin

	# Clear baseline
	# Merge from prefix, if possible
	# Extend based on TDK license found.

	array unset origin  *

	if {$prio eq "metadata"} {
	    $self S/ImportOrigin/MD
	    $self S/ImportOrigin/OSX
	} else {
	    $self S/ImportOrigin/OSX
	    $self S/ImportOrigin/MD
	}

	catch {
	    ::stringfileinfo::getStringInfo $origin_exe origin
	}

	# We modify the information coming from the file a bit,
	# inserting strings coming out of the license. However only if
	# there is something to insert (in)to.

	if {[info exists origin(CompanyName)]} {
	    set origin(CompanyName) $tcl_platform(user)@[info hostname]
	}
	return
    }

    method S/ImportOrigin/MD {} {
	#puts \tS/ImportOrigin/MD

	upvar #0 $options(-variable) state

	# Inherit name and version from the TEAPOT meta data

	array set md $origin_md

	foreach {k v} {
	    ProductName	   name    
	    ProductVersion version 
	} {
	    if {
		(![info exists origin($k)] || ($origin($k) eq "")) &&
		[info exists md($v)]
	    } {
		# Nothing defined, or empty, and have something in the
		# teapot meta data => Take it.

		set origin($k) $md($v)
		set nv($k) $md($v)
		#puts "$k = $md($v)"
	    }
	}
	return
    }

    method S/ImportOrigin/OSX {} {
	#puts \tS/ImportOrigin/OSX

	upvar #0 $options(-variable) state

	# Inherit name and version from the OS X meta data.

	array set md $origin_ip

	foreach {k v} {
	    ProductName    CFBundleName
	    ProductVersion CFBundleVersion
	} {
	    if {
		(![info exists origin($k)] || ($origin($k) eq "")) &&
		[info exists md($v)]
	    } {
		# Nothing defined, or empty, and have something in the
		# teapot meta data => Take it.

		set origin($k) $md($v)
		set nv($k) $md($v)
		#puts "$k = $md($v)"
	    }
	}
	return
    }

    method S/ImportSI {} {
	#puts S/ImportSI
	# Flow (a), Action - Import user SI settings
	# Flow (b), Action - ditto

	# Clear settings
	# Merge baseline
	# Merge external SI, ignoring unknown keys
	# Re-export merge result

	# Importing the current stringinfo. Start out empty, then the
	# origin data, then lay the actual current information over
	# that. This automatically merges all previous edits over the
	# new baseline. As part of that we ignore all keys which are
	# not present in the new baseline. After completion we can
	# re-export the imported information, as it was possibly
	# changed.

	set si [GetState stringinfo]

	#puts \tReading:\t($si)

	DisableExport

	array unset current *
	array set   current [array get origin]

	foreach {k v} $si {
	    if {![info exists current($k)]} continue
	    set current($k) $v
	}

	if {$prio != {}} {
	    array set current [array get nv]
	}

	EnableExport
	$self S/ExportSI
	return
    }

    method S/ExportSI {} {
	#puts S/ExportSI
	# Flow (c), Action - Export dialog SI settings to user settings
	# Nothing if no change, everything for change, nothing if equal

	if {[$self S/OriginUnchanged]} {
	    set exportedvalue {}
	} else {
	    set exportedvalue [array get current]
	}

	upvar #0 $options(-variable) state

	if {
	    [info exists state(stringinfo)] &&
	    $state(stringinfo) eq $exportedvalue
	} return

	#puts \tWriting:\t($exportedvalue)

	DisableImport
	set state(stringinfo) $exportedvalue
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
	# Flow (a), Action - Update interface

	if {!$enable} {
	    set dedat {}
	    $win.de configure -state disabled
	} else {
	    set dedat [array get current]
	    $win.de configure -state normal
	}
	return
    }

    # ### ### ### ######### ######### #########

    method GetDE {args} {
	DisableExport
	array unset current *
	array set   current $dedat
	EnableExport

	$self T/ExportSI
	return
    }

    method Sort {keys} {
	set keys [lsort -dict $keys]
	foreach x {ProductVersion ProductName} {
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

package provide sieditor 1.0
