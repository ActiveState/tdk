# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# mdeditor.tcl --
# -*- tcl -*-
#
#	UI to edit the TEAPOT meta data of a basekit/wrap result.
#
# Copyright (c) 2005-2009 ActiveState Software Inc.
#
# RCS: @(#) $Id:  $

# ### ### ### ######### ######### #########
## Requisites

package require snit              ; # Tcllib, OO core.
package require dictentry
package require tile
package require teapot::metadata::read

# ### ### ### ######### ######### #########
## Implementation

snit::widget mdeditor {
    hulltype ttk::frame

    option -variable -default {}

    constructor {args} {
	# DEBUG # $hull configure -relief raised -bd 2 -bg coral

	dictentry $win.de \
	    -height 12 \
	    -labelks {meta data keyword} -labelkp {meta data keywords} \
	    -labelvs {value}             -labelvp {values} \
	    -titlek Keyword -titlev Value    \
	    -validk     [mymethod ValidKey]  \
	    -transformk [myproc   TransKey]  \
	    -dictvariable [myvar dedat]      \
	    -removable [mymethod Removable?] \
	    -sort      [mymethod Sort]
		
	grid $win.de -column 0 -row 0 -sticky swen

	grid columnconfigure $win 0 -weight 1 -minsize 30
	grid rowconfigure    $win 0 -weight 1

	trace variable [myvar current] w [mymethod T/ExportMD]

	# Handle initial options. This implies the initialization of
	# our state too, as part of -variable processing.

	$self configurelist $args

	trace add variable [myvar dedat] write [mymethod GetDE]
	return
    }

    destructor {
	$self TM/Remove
	trace vdelete [myvar current] w [mymethod T/ExportMD]
	trace remove variable [myvar dedat] write [mymethod GetDE]
	return
    }

    # ### ### ### ######### ######### #########
    ## Object state

    variable rows           0  ; # Number of rows shown by the display to handle the stringinfo
    variable origin_si      {} ; # StringInfo settings which are in 'origin'
    variable origin_ip      {} ; # OS X settings which are in 'origin'
    variable origin_exe     {} ; # Prefix whose MD settings are in 'origin'
    variable origin  -array {} ; # MD settings imported from the current prefix
    variable current -array {} ; # Current MD settings shown, possibly modified by the user
    variable key            {} ; # Current name of key to add
    variable value          {} ; # Current value for key to add

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

	set state(metadata) {}
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
	trace variable ${statev}(infoplist)       w [mymethod T/InfoPlist]
	trace variable ${statev}(stringinfo)      w [mymethod T/StringInfo]
	trace variable ${statev}(wrap,executable) w [mymethod T/Prefix]
	trace variable ${statev}(metadata)        w [mymethod T/ImportMD]
	return
    }

    method TM/Remove {} {
	if {$options(-variable) eq ""} return
	set statev $options(-variable)
	trace vdelete ${statev}(infoplist)       w [mymethod T/InfoPlist]
	trace vdelete ${statev}(stringinfo)      w [mymethod T/StringInfo]
	trace vdelete ${statev}(wrap,executable) w [mymethod T/Prefix]
	trace vdelete ${statev}(metadata)        w [mymethod T/ImportMD]
	return
    }

    # ### ### ### ######### ######### #########
    ## Trace callbacks

    method T/ExportMD {args} {
	# [XX] Flow (c), Trigger (1)
	if {$noexport} return
	#puts T/ExportMD\t($args)
	$self S/ExportMD
	return
    }

    method T/ImportMD {args} {
	# [XX] Flow (b), Trigger (1)
	if {$noimport} return
	#puts T/ImportMD\t($args)
	$self S/ImportMD
	$self UI/Make on
	return
    }

    method T/Prefix {args} {
	upvar #0 $options(-variable) state
	if {$origin_exe eq $state(wrap,executable)} return
	#puts T/Prefix\t($args)
	# [XX] Flow (a), Trigger (2)
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

    method T/StringInfo {args} {
	upvar #0 $options(-variable) state
	if {$origin_si eq $state(stringinfo)} return
	#puts T/Prefix\t($args)
	# [XX] Flow (a), Trigger (2)
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
	#puts S/Initialize/MD

	upvar #0 $options(-variable) state

	# Import prefix (name)
	# Import baseline MD from prefix
	# Import user MD
	# Update interface

	set origin_exe $state(wrap,executable)
	set origin_ip  [GetState infoplist]
	set origin_si  [GetState stringinfo]

	$self S/ImportOrigin
	$self S/ImportMD
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
	    $self S/ImportOrigin/OSX
	} else {
	    $self S/ImportOrigin/OSX
	    $self S/ImportOrigin/SI
	}
	$self S/ImportOrigin/Prefix
	$self S/ImportOrigin/Standard
	return
    }

    method S/ImportOrigin/SI {} {
	#puts \tS/ImportOrigin/SI

	upvar #0 $options(-variable) state

	# Inherit name and version from the windows String Resources

	array set md $origin_si

	foreach {k v} {
	    name    ProductName
	    version ProductVersion
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

    method S/ImportOrigin/OSX {} {
	#puts \tS/ImportOrigin/OSX

	upvar #0 $options(-variable) state

	# Inherit name and version from the OS X meta data.

	array set md $origin_ip

	foreach {k v} {
	    name    CFBundleName
	    version CFBundleVersion
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

    method S/ImportOrigin/Prefix {} {
	#puts \tS/ImportOrigin/Prefix

	set errors {}
	set plist  {}
	catch {
	    set plist [teapot::metadata::read::file $origin_exe single errors]
	}

	if {![llength $plist]} {
	    # Generate a bit of fake information based on the prefix
	    # architecture. The repository::prefix code will code
	    # fairly deep to determine something sensible (teapot
	    # first, then per file type and name.

	    if {$origin_exe ne ""} {
		catch {
		    set r [repository::prefix %AUTO% -location $origin_exe]
		    set a [$r architecture]
		    $r destroy
		    set origin(platform) $a
		}
	    }
	    return
	}

	set pkg [lindex $plist 0]

	array set   origin   [$pkg get]
	#set origin(name)     [$pkg name]
	#set origin(version)  [$pkg version]

	$pkg destroy
	return
    }

    method S/ImportOrigin/Standard {} {
	#puts \tS/ImportOrigin/Standard

	upvar #0 $options(-variable) state

	if {
	    ![info exists origin(name)] ||
	    ($origin(name) eq "")
	} {
	    # No name, or empty => Choose a default.

	    if {[catch {
		set out [file rootname [file tail $state(wrap,out)]]
	    }] || ($out eq "")} {
		set out {<Name of Application, please fill in>}
	    }
	    set origin(name) $out
	}

	if {
	    ![info exists origin(version)] ||
	    ($origin(version) eq "")
	} {
	    # No version, or empty => Choose a default.

	    set origin(version) {<Version of Application, please fill in>}
	}

	if {
	    ![info exists origin(platform)] ||
	    ($origin(platform) eq "")
	} {
	    # No platform, or empty => Choose a default. Can happen if
	    # there is no prefix, or the prefix had no teapot meta
	    # data.

	    set origin(platform) tcl
	}

	return
    }

    method S/ImportMD {} {
	#puts S/ImportMD
	# Flow (a), Action - Import user MD settings
	# Flow (b), Action - ditto

	# Clear settings
	# Merge baseline
	# Merge external MD
	# Re-export merge result

	# Importing the current meta data. Start out empty, then the
	# origin data, then lay the actual current information over
	# that. This automatically merges all previous edits over the
	# new baseline. After completion we can re-export the imported
	# information, as it was possibly changed.

	set md [GetState metadata]

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
	$self S/ExportMD
	return
    }

    method S/ExportMD {} {
	#puts S/ExportMD
	# Flow (c), Action - Export dialog MD settings to user settings
	# Nothing if no change, everything for change, nothing if equal

	if {[$self S/OriginUnchanged]} {
	    set exportedvalue {}
	} else {
	    set exportedvalue [array get current]
	}

	upvar #0 $options(-variable) state

	if {
	    [info exists state(metadata)] &&
	    ($state(metadata) eq $exportedvalue)
	} return

	#puts \tWriting:\t($exportedvalue)

	DisableImport
	set state(metadata) $exportedvalue
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
	    set tr {}
	    foreach k [array names current] {
		lappend tr [TransKey $k] $current($k)
	    }
	    set dedat $tr
	    $win.de configure -state normal
	}
	return
    }

    proc TransKey {k} {
	return [::textutil::cap [string tolower $k]]
    }

    method GetDE {args} {
	DisableExport
	array unset current *
	# Untranskey, internal keys lowercase only
	foreach {k v} $dedat {
	    set current([string tolower $k]) $v
	}
	EnableExport

	$self T/ExportMD
	return
    }

    method ValidKey {k} {
	if {$k eq ""} {
	    return Empty
	}
	return ""
    }

    method Removable? {k} {
	set k [TransKey $k]
	if {$k eq "Name"}     {return 0}
	if {$k eq "Version"}  {return 0}
	if {$k eq "Platform"} {return 0}
	return 1
    }

    method Sort {keys} {
	set keys [lsort -dict $keys]
	foreach x {Platform Version Name} {
	    set pos [lsearch -exact $keys $x]
	    if {$pos > 0} {
		set keys [linsert [lreplace $keys $pos $pos] 0 [lindex $keys $pos]]
	    }
	}
	return $keys
    }

    # ### ### ### ######### ######### #########

    typevariable fix tdk-licensed-to

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide mdeditor 1.0
