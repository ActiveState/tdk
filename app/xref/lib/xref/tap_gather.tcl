# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# tap_gather - /snit::type
#
# Scans files, gathers xref data ...

package require snit
package require xref_gather
package require tdk_tap_decoder

snit::type ::tap_gather {

    option -command {}
    option -onerror {}
    option -ping    {}


    variable td    {}
    variable xg    {}
    variable files {}

    constructor {file args} {
	set td [tdk_tap_decoder ${selfns}::td {}]

	after 1 [mymethod Run $file]
	$self configurelist $args
	return
    }
    destructor {
	if {$xg != {}} {rename $xg {}}
	if {$td != {}} {rename $td {}}
    }

    # ------------------------------------------------
    method Run {file} {
	switch -exact -- [$td match $file] {
	    -1 - 0 {
		$self CallError "The chosen\
			file is not a Tcl Dev Kit Package\
			Definition"
	    }
	    1 {
		set files {}
		if {[catch {
		    $td read $file $self
		} msg]} {
		    #puts $::errorInfo
		    $self CallError $msg
		    return
		} elseif {[llength $files] == 0} {
		    #puts No/Files
		    $self CallError [$td errors]
		    return
		}

		# Constructor auto-launches the scanning
		set xg [xref_gather ${selfns}::xg [lsort -uniq $files] \
			-command [mymethod Call] \
			-errcommand [mymethod CallError] \
			-ping $options(-ping)]
	    }
	}
	return
    }

    # ------------------------------------------------
    # Decoder callbacks

    method add  {args} {}
    method meta {args} {}
    method see  {args} {}
    method hide {args} {}
    method files {key files_} {

	#puts files/$key/$files_

	# We ignore the file destinations, they are only relevant to
	# wrapping, not xref gathering. We also ignore all files which
	# do not end in '.tcl'. Easy skip over binaries which cannot
	# be scanned for tcl code.

	foreach {f __} $files_ {
	    if {[file extension $f] ne ".tcl"} continue
	    lappend files $f
	}
	return
    }

    # ------------------------------------------------

    method Call {dbfile} {
	rename $xg {}
	set     xg {}
	if {$options(-command) == {}} return
	eval [linsert $options(-command) end $dbfile]
	return
    }

    method CallError {text} {
	if {$options(-onerror) == {}} return
	eval [linsert $options(-onerror) end $text]
	return
    }

}

package provide tap_gather 0.1

