# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# util.tcl --
#
#	This file contains miscellaneous utilities.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2001-2006 ActiveState Software Inc.
#

# 
# RCS: @(#) $Id: util.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $

# lassign --
#
#	This function emulates the TclX lassign command.
#
# Arguments:
#	valueList	A list containing the values to be assigned.
#	args		The list of variables to be assigned.
#
# Results:
#	Returns any values that were not assigned to variables.

proc lassign {valueList args} {
  if {[llength $args] == 0} {
      error "wrong # args: lassign list varname ?varname..?"
  }

  uplevel 1 [list foreach $args $valueList {break}]
  return [lrange $valueList [llength $args] end]
}

# matchKeyword --
#
#	Find the unique match for a string in a keyword table and return
#	the associated value.
#
# Arguments:
#	table	A list of keyword/value pairs.
#	str	The string to match.
#	exact	If 1, only exact matches are allowed, otherwise unique
#		abbreviations are considered valid matches.
#	varName	The name of a variable that will hold the resulting value.
#
# Results:
#	Returns 1 on a successful match, else 0.

proc matchKeyword {table str exact varName} {
    upvar 1 $varName result
    if {$str == ""} {
	foreach pair $table {
	    set key [lindex $pair 0]
	    if {$key == ""} {
		set result [lindex $pair 1]
		return 1
	    }
	}
	return 0
    }
    if {$exact} {
	set end end
    } else {
	set end [expr {[string length $str] - 1}]
    }
    set found ""
    foreach pair $table {
	set key [lindex $pair 0]
	if {[string compare $str [string range $key 0 $end]] == 0} {
	    # If the string matches exactly, return immediately.

	    if {$exact || ($end == ([string length $key]-1))} {
		set result [lindex $pair 1]
		return 1
	    } else {
		lappend found [lindex $pair 1]
	    }
	}
    }
    if {[llength $found] == 1} {
	set result [lindex $found 0]
	return 1
    } else {
	return 0
    }
}


# kill --
#
#	Unix only:  Define "kill" to exec "kill -9".
#	Windows version of "kill" is written in c.    -- Tclx
#
# Arguments:
#	pid	Id of application to kill.
#
# Results:
#	The application with with process id "pid" is killed.

if {[catch {package require Tclx}]} {
    if {$tcl_platform(platform) == "unix"} {
	proc kill {pid} {
	    exec kill -9 $pid
	}
    }
}


proc dumpStack {} {
    set n [info level]
    puts "___\t___________________________"
    for {set i 0} {$i <= $n} {incr i} {
	puts "\[$i\]\t[info level $i]"
    }
    puts "___\t___________________________"
    return
}

package provide util 1.0
