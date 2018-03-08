# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package as::tdk::komodo 0.1
# Meta platform        tcl
# Meta require         snit
# Meta description     This package allows TDK tools to talk to our
# Meta description     Komodo Editor/IDE, either opening a file in it,
# Meta description     or opening a file and selecting a text range
# Meta description     to highlight.
# @@ Meta End

# This code began as the 'talk_komodo' package and class inside of the
# Xref application. Now that both Xref and Debugger use it it was made
# more general. It has also moved out of the xref *kit/pack into the
# tdkbase *pack.

# -*- tcl -*-
# Copyright (c) 2003-2009 ActiveState Software Inc.
#               Tools & Languages
# $Id$
# --------------------------------------------------------------

# ### ### ### ######### ######### #########
## Requisites

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type as::tdk::komodo {

    constructor {} {
	# Search for a usable Komodo on the path. If none is found the
	# instance method 'usable' will return FALSE.

	foreach koname {
	    komodo ko komodow
	} {
	    set ko [auto_execok $koname]
	    if {$ko == {}} continue
	    set mykomodo $ko
	    break
	}
	return
    }

    # ### ### ### ######### ######### #########
    ##

    method usable {} {
	return [expr {$mykomodo ne {}}]
    }

    method open {path} {
	eval exec $mykomodo [list $path] &
	return
    }

    method openat {path line begin size end} {
	# end = first character after range, make it last character in
	#       range.
	# We specify end-begin to place the cursor at the beginning of
	# the range.

	# Convert the character offsets into line/column pairs for Komodo.

	# FUTURE :: Consider to have the lin/col data stored in the
	# xref database to avoid computing them here. We cache
	# results, but even so, not having to compute them at all is
	# much better here.

	set begin [join [$type LC $path $begin] ,]
	set end   [join [$type LC $path $end]   ,]

	#tk_messageBox -type ok -parent . -message "--selection=${end}-${begin} $path (l=$line, sz=$size)"

	eval exec $mykomodo [list --selection=${end}-${begin} $path] &
	return
    }

    # ### ### ### ######### ######### #########
    ## State

    variable mykomodo  {}

    # ### ### ### ######### ######### #########
    ##

    # This code snarfed from message.tcl of lib/checker and modified
    # to be typemethods instead of plain procedures, and to use a
    # cache keyed by path to avoid counting the lines multiple times.

    typemethod LC {path offset} {
	# Convert character offset pos into line number and
	# column in that line.
	set loffset [$type GetLines $path]

	set line   [$type FindLine $offset $loffset]
	set column [expr {$offset - [lindex $loffset $line] + 1}] ; # +1, Komodo counts columns from 1...
	incr line
	return [list $line $column]
    }

    typemethod FindLine {offset loffset} {
	# Check if we have lsearch -binary in 8.5
	# for even quicker access.

	set start 0
	set end   [llength $loffset]

	while {1} {
	    set len [expr {$end - $start}]
	    if {$len == 1} {
		return $start
	    }
	    if {$len == 2} {
		# Check the top half first.

		incr end -1
		set c [lindex $loffset $end]
		if {$c <= $offset} {
		    return $end
		}

		# Has to be bottom half
		return $start
	    }

	    set middle [expr {($start + $end) / 2}]
	    set result [lindex $loffset $middle]

	    if {$result == $offset} {
		return $middle
	    }

	    if {$result < $offset} {
		set start $middle
	    } else {
		set end $middle
	    }
	}
    }

    typemethod GetLines {path} {
	if {[info exists ourfiles($path)]} {
	    return $ourfiles($path)
	}

	set c [open $path r]
	set d [read $c]
	close $c

	# NOTE :: We are not using fconfigure here to set a specific
	# translation. The checker uses "-translation auto" when it
	# reads files, therefore the character offsets we have here
	# are based on unix EOL markers (LF only), and we have to use
	# "-translation auto" as well to match.

	set loffset 0
	set total 0
	foreach line [split $d \n] {
	    set  len [string length $line]
	    incr len ; # Count EOL too.
	    incr total $len
	    lappend loffset $total
	}

	set ourfiles($path) $loffset
	return $loffset
    }

    # ### ### ### ######### ######### #########
    ##

    typevariable ourfiles -array {} 

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
