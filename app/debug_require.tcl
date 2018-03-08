# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Debugging 'package require' invokations
# ---------------------------------------

rename ::package ::__package
proc ::package {args} {
    if {[lindex $args 0] eq "require"} {
	puts ">>> [info script]"
	puts "    package $args"
	puts ""
    }
    return [uplevel 1 [linsert $args 0 ::__package]]
}
