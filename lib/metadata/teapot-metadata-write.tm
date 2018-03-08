# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::metadata::write 0.1
# Meta platform    tcl
# Meta require     logger
# Meta require     teapot::entity
# Meta require     teapot::reference
# Meta require     textutil
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

## Writing of TEAPOT meta data in various formats, and of information
## derived from it.

# ### ### ### ######### ######### #########
## Requirements

package require logger            ; # Tracing
package require textutil          ; #
package require teapot::reference ; # Reference handling
package require teapot::entity    ; # Conversion of entities names for output

logger::initNamespace ::teapot::metadata::write
namespace eval        ::teapot::metadata::write {}

# ### ### ### ######### ######### #########
## API

proc ::teapot::metadata::write::getStringHumanC {container} {
    join [HumanLines [$container name] [$container version] [$container type] [$container get]] \n
}

proc ::teapot::metadata::write::getStringEmbeddedC {container} {
    join [EmbeddedLines [$container name] [$container version] [$container type] [$container get]] \n
}

proc ::teapot::metadata::write::getStringExternalC {container} {
    join [ExternalLines [$container name] [$container version] [$container type] [$container get]] \n
}

proc ::teapot::metadata::write::getStringEmbedded {name ver type meta} {
    join [EmbeddedLines $name $ver $type $meta] \n
}

proc ::teapot::metadata::write::getStringExternal {name ver type meta} {
    join [ExternalLines $name $ver $type $meta] \n
}

proc ::teapot::metadata::write::providePkgString {name version} {
    set     lines {}
    lappend lines "\# OPEN TEAPOT-PKG BEGIN DECLARE"
    lappend lines {}
    lappend lines [list package provide $name $version]
    lappend lines {}
    lappend lines "\# OPEN TEAPOT-PKG END DECLARE"

    return [join $lines \n]
}

proc ::teapot::metadata::write::requirePkgListString {reflist {circ {}}} {
    # Convert the list of references to packages into a tcl script
    # which checks that the listed packages are present in the running
    # interpreter, aborting executing if one is missing. I.e. a list
    # of 'package require' statements. The statements take any guards
    # into accounts as well, i.e. proper conditionals are generated.

    array set circular {}
    foreach p $circ { set circular($p) . }

    set     lines {}
    lappend lines "\# OPEN TEAPOT-PKG BEGIN REQUIREMENTS"
    lappend lines {}

    foreach ref $reflist {
	lappend lines [RequirePkgRefString $ref circular]
    }

    lappend lines {}
    lappend lines "\# OPEN TEAPOT-PKG END REQUIREMENTS"
    lappend lines {}

    return [join $lines \n]
}

# ### ### ### ######### ######### #########
## Internal helper commands

proc ::teapot::metadata::write::EmbeddedLines {name ver type meta} {
    lappend lines {# @@ Meta Begin}
    foreach l [ExternalLines $name $ver $type $meta "\#"] {
	if {[string trim $l] eq ""} continue
	lappend lines "\# $l"
    }
    lappend lines {# @@ Meta End}
    lappend lines {} ; # Forces a \n at the end of the block when joining the lines.
    return $lines
}

proc ::teapot::metadata::write::ExternalLines {name ver type meta {nlprefix {}}} {
    array set   md $meta
    array unset md __* ; # Squash everything internal

    Canonical
    set  maxl [MaxKey md]
    set  margin 67 ; # 72 -5 (Meta )
    incr margin -$maxl

    lappend lines [list [teapot::entity::display $type] $name $ver]

    foreach k [lsort [array names md]] {
	set sk [string tolower $k]

	switch -exact -- $sk {
	    require -
	    recommend {
		# Bug 72969. Do not sort dependencies, order may be
		# important during setup.
		foreach e [teapot::reference::normalize $md($k)] {
		    # Convert internal list form of requirements into
		    # Tcl form for easier use by humans.
		    set e [teapot::reference::ref2tcl $e]
		    lappend lines [ALine $k $maxl [list $e] $nlprefix]
		}
		continue
	    }
	}

	# Semi paragraph-formatting of everything else across multiple
	# lines.

	if {![llength $md($k)]} {
	    lappend lines [ALine $k $maxl "" $nlprefix]
	    continue
	}

	set buf ""
	foreach e $md($k) {
	    if {![llength $buf]} {
		lappend buf $e
		continue
	    }
	    if {([string length $buf] + [string length $e] + 1) > $margin} {
		lappend lines [ALine $k $maxl $buf $nlprefix]
		set buf {}
	    }
	    lappend buf $e
	}
	if {[llength $buf]} {
	    lappend lines [ALine $k $maxl $buf $nlprefix]
	}
    }

    lappend lines {} ; # Forces a \n at the end of the block when joining the lines.
    return $lines
}

proc ::teapot::metadata::write::ALine {k maxl v nlprefix} {
    if {$nlprefix ne ""} {
	set tmp {}
	foreach i $v {
	    if {[regexp "\n" $i]} {
		lappend tmp [string map [list \n \n$nlprefix] $i]
	    } else {
		lappend tmp $i
	    }
	}
	set v $tmp
    }
    return "Meta [format "%-*s" $maxl [list $k]] $v"
}

# ExternalLines vs HumanLines - Factor our maxkey/margin =>
# Distinction between both is in the start- and continuation
# prefixes. Commands to generate, invoke per unique key.

proc ::teapot::metadata::write::HumanLines {name ver type meta} {
    array set md $meta
    array unset md __* ; # Squash everything internal

    Canonical
    set  maxl [MaxKey md]
    set  margin 67 ; # 72 -5 (Meta )
    incr margin -$maxl

    lappend lines "[list [teapot::entity::display $type] $name $ver] ($md(platform))"
    lappend lines {}

    foreach k [lsort [array names md]] {
	set sk [string tolower $k]

	set prefix [format "%-*s : " $maxl [::textutil::cap $sk]]
	set blank  [format "%-*s | " $maxl ""]

	switch -exact -- $sk {
	    require -
	    recommend {
		foreach e [lsort -dict [teapot::reference::normalize $md($k)]] {
		    # Convert internal list form of requirements into
		    # Tcl form for easier use by humans.
		    set e [teapot::reference::ref2tcl $e]
		    lappend lines $prefix[list $e]
		    set prefix $blank
		}
		continue
	    }
	    as::author {
		foreach e [lsort -dict $md($k)] {
		    # Convert internal list form of list of authors into
		    # a form easier to read by humans.
		    lappend lines $prefix$e
		    set prefix $blank
		}
		continue
	    }
	}

	# Semi paragraph-formatting of everything else across multiple
	# lines.

	if {![llength $md($k)]} {
	    lappend lines $prefix
	    continue
	}

	set buf ""
	foreach e $md($k) {
	    # Magic transform of free-standing --- in descriptions
	    # into paragraph breaks.
	    if {($k eq "description") && ($e eq "---")} {
		lappend lines $prefix[join $buf]
		set prefix $blank
		lappend lines $prefix
		set buf {}
		continue
	    }

	    if {![llength $buf]} {
		lappend buf $e
		continue
	    }
	    if {([string length $buf] + [string length $e] + 1) > $margin} {
		lappend lines $prefix[join $buf]
		set prefix $blank
		set buf {}
	    }
	    lappend buf $e
	}
	if {[llength $buf]} {
	    lappend lines $prefix[join $buf]
	}
    }

    lappend lines {} ; # Forces a \n at the end of the block when joining the lines.
    return $lines
}


proc ::teapot::metadata::write::Canonical {} {
    upvar 1 type type md md

    # Canonicalize the handling of profiles. Old form of marking them
    # is auto-magically translated to the new canonical form.

    # This handles the generation of new archives and output where the
    # source meta data is still in the new form. It may also rewrite
    # that meta data to the new form, in the right context.

    if {($type eq "package") && [info exists md(profile)]} {
	set type profile
	unset -nocomplain md(profile)
    }

    return
}


proc ::teapot::metadata::write::MaxKey {mv} {
    upvar 1 $mv md

    set maxl 0
    foreach k [array names md] {
	set l [string length [list $k]]
	if {$l > $maxl} {set maxl $l}
    }

    return $maxl
}

proc ::teapot::metadata::write::RequirePkgRefString {ref cv} {
    upvar 1 $cv circular
    set lines {}

    array set g {}
    array set g [::teapot::reference::guards $ref]
    set indent ""

    if {[array size g]} {
	set guard {}
	if {[info exists g(archglob)]} {
	    lappend lines [list package require platform]
	    lappend guard "\[string match [list $g(archglob)] \[platform::identify\]\]"
	}
	if {[info exists g(platform)]} {
	    lappend guard "\[string equal \$tcl_platform(platform) [list $g(platform)]\]"
	}
	lappend lines "if \{\n    [join $guard " &&\n    "]\n\} \{"
	set indent "    "
    }

    set cmd  [::teapot::reference::requirecmd $ref]
    set name [::teapot::reference::name       $ref]
    if {[info exists circular($name)]} {
	set cmd "catch \{ $cmd \} ; # Circular, recover"
    }
    lappend lines "${indent}$cmd"

    if {[array size g]} {
	lappend lines "\}"
    }

    return [join $lines \n]
}

# ### ### ### ######### ######### #########
## Ready
return
