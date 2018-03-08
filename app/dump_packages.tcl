# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Debugging packages - Dump all packages present when the applications exits
# --------------------------------------------------------------------------

rename exit _exit
proc exit {{status 0}} {
    set tmp {}
    set mlp 0
    set mlv 0

    foreach package [lsort [package names]] {
	foreach version [package versions $package] {
	    if {[catch {package present $package}]} continue
	    if {![string equal $version [package provide $package]]} continue

	    set ifneeded \
		[string replace \
		     [string trim \
			  [string map {"\n" " " "\t" " "} \
			       [package ifneeded $package $version]]] \
		     100 end "..."]

	    lappend tmp [list $package $version $ifneeded]
	    if {[set l [string length $package]] > $mlp} {set mlp $l}
	    if {[set l [string length $version]] > $mlv} {set mlv $l}
	}
    }

    puts ______________________________________________________________________________
    foreach entry $tmp {
	foreach {package version ifneeded} $entry break

	puts [format "%-${mlp}s %-${mlv}s %-55s" \
		  $package $version $ifneeded]
    }

    puts ______________________________________________________________________________
    _exit $status
}
