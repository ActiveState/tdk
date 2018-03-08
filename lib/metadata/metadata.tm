# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::metadata 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     struct::set
# Meta require     teapot::reference
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Acessors for various pieces of information stored in meta data, or
## results coming from the extraction commands.

# ### ### ### ######### ######### #########
## Requirements

package require logger           ; # Tracing
package require teapot::reference ; # Reference handling
package require fileutil          ; # Directory traversal
package require struct::set       ; # Set difference

logger::initNamespace ::teapot::metadata
namespace eval        ::teapot::metadata {}

# ### ### ### ######### ######### #########
## Accessors

proc ::teapot::metadata::filesSet {top p mv} {
    upvar 1 $mv message
    set ok [files $top [$p get] files message]
    if {!$ok} {return 0}
    $p setfor __files $files
    return 1
}

proc ::teapot::metadata::entrySet {p mv} {
    upvar 1 $mv message
    set ok [entry [$p get] ecmd efile message]
    if {!$ok} {return 0}
    $p unset __ecmd  ; $p add __ecmd  $ecmd
    $p unset __efile ; $p add __efile $efile
    return 1
}

proc ::teapot::metadata::minTclVersionSet {p} {
    set v [minTclVersionMM [$p get]]
    $p unset __mintcl ; $p add __mintcl $v
    return
}

# ### ### ### ######### ######### #########

proc ::teapot::metadata::files {top meta fv mv} {
    upvar 1 $fv thefiles $mv errmessage
    array set md $meta

    # Changed. Removed heuristics regarding presence of 'included'.
    #
    # Now the 'entry*' are used to seed the list of included files,
    # extended by 'included' when present, and then reduced via
    # 'excluded', when present. This way of doing things is easier to
    # understand and also the same for single and multiple packages
    # per directory, obviating the need to distinguish the cases. The
    # 'needincluded' stuff therefore went bye-bye.

    log::debug "files top=($top)"
    set top [file dirname [file normalize [file join $top ___]]]
    log::debug "files ntop=($top)"

    set files {}
    set nofilesok 0

    if {[info exists md(entrysource)]} {
	foreach f $md(entrysource) {
	    lappend files $f
	}
    } elseif {[info exists md(entryload)]} {
	foreach f $md(entryload) {
	    lappend files $f
	}
    } elseif {[info exists md(entrytclcommand)]} {
	set nofilesok 1
    }

    if {[info exists md(included)]} {
	set missing {}
	set files [struct::set union \
			  $files \
			  [ExpandGlobs $top $md(included) missing]]

	if {[llength $missing]} {
	    if {[llength $missing] == 1} {
		set errmessage "Neither files nor directories found for pattern \"$missing\""
	    } else {
		set errmessage "Neither files nor directories found for patterns [linsert '[join $missing "', '"]' end-1 and]"
	    }
	    return 0
	}
    }

    if {[info exists md(excluded)]} {
	# Note: Patterns not matching anything are irrelevant when
	# excluding. It makes it easier to specify patterns handling
	# exclusion across platforms.

	set files [struct::set difference \
			  $files \
			  [ExpandGlobs $top $md(excluded) __]]
    }

    # Exclude a pre-existing "pkgIndex.tcl" and "teapot.txt". They do
    # not belong to the package in itself. Both their information will
    # be stashed into a package archive file as per the specification
    # of the archive format.

    if {![info exists md(entrykeep)]} {
	set files [struct::set difference \
		       $files \
		       {pkgIndex.tcl}]
    }

    set files [struct::set difference \
		      $files \
		      {teapot.txt}]


    log::debug "files ($files)"

    if {!$nofilesok && ![llength $files]} {
	set errmessage "No files specified"
	return 0
    }

    set thefiles $files
    return 1
}

proc ::teapot::metadata::ExpandGlobs {path patterns mv} {
    upvar 1 $mv missing
    set res {}
    foreach p $patterns {
	set files [glob -nocomplain -dir $path $p]

	if {![llength $files]} {
	    lappend missing $p
	    continue
	}

	foreach f $files {
	    if {[file isfile $f]} {
		lappend res [fileutil::stripPath $path $f]
	    } elseif {[file isdirectory $f]} {
		# Take all files in the selected directory.
		# We do the dirname/strip/join dance here because f might be a
		# softlink, and find will have changed paths to reflect that.
		# Our dance ensures that the relative paths include the link.

		set dir [file dirname [file normalize [file join $path $f __]]]
		foreach sub [fileutil::find $dir] {
		    lappend res [fileutil::stripPath $path [file join $f [fileutil::stripPath $dir $sub]]]
		}
	    }
	}
    }
    return $res
}

proc ::teapot::metadata::entry {meta ecmdv efilev mv} {
    upvar 1 $ecmdv ecmd $efilev efile $mv errmessage
    array set md $meta

    if {
	([info exists md(entrysource)] +
	 [info exists md(entryload)]   +
	 [info exists md(entrykeep)]   +
	 [info exists md(entrytclcommand)]) > 1
    } {
	set res {}
	foreach x {
	    entrykeep
	    entryload
	    entrysource
	    entrytclcommand
	} {
	    if {![info exists md($x)]} continue
	    lappend res $x
	}
	set errmessage "Ambiguous entry specification (Cannot use [linsert [join $res ", "] end-1 and] together)"
	return 0
    } elseif {
	[info exists md(entrysource)]
    } {
	set ecmd source
	set efile $md(entrysource)
	return 1
    } elseif {
	[info exists md(entryload)]
    } {
	set ecmd load
	set efile $md(entryload)
	return 1
    } elseif {
	[info exists md(entrytclcommand)]
    } {
	# A special case, entry is specified not as file, but as Tcl script.

	set ecmd  tcl
	set efile [lindex $md(entrytclcommand) 0]
	return 1
    } elseif {
	[info exists md(entrykeep)]
    } {
	# Another special case, keep an existing pkgIndex.tcl file.
	set ecmd keep
	set efile {}
	return 1
    } else {
	set errmessage "No entry file"
	return 0
    }
}

proc ::teapot::metadata::minTclVersionMM {meta} {
    minTclVersion $meta -> major minor
    return ${major}.${minor}
}

proc ::teapot::metadata::minTclVersion {meta __ majv minv} {
    upvar 1 $majv major $minv minor

    array set md $meta
    if {[info exists md(require)]} {
	foreach ref $md(require) {
	    if {[lindex $ref 0] ne "Tcl"} continue
	    switch -exact -- [teapot::reference::type $ref rn rv] {
		name break
		version {
		    # Smallest version is min boundary of first item.
		    MM [lindex [lindex $rv 0] 0] major minor
		    return
		}
	        exact {
		    MM $v major minor
		    return
		}
	    }
	}
    }

    set major 8
    set minor 4
    return
}

proc ::teapot::metadata::MM {v av mv} {
    upvar 1 $av major $mv minor
    set v [split $v .]
    if {[llength $v] > 1} {
	foreach {major minor} $v break
    } else {
	set major [lindex $v 0]
	set minor 0
    }
    return
}

# ### ### ### ######### ######### #########
## Ready
return
