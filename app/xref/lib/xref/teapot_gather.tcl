# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# teapot_gather - /snit::type
#
# Scans files, gathers xref data ...

package require snit
package require xref_gather
package require teapot::metadata
package require teapot::metadata::read

snit::type ::teapot_gather {

    option -command {}
    option -onerror {}
    option -ping    {}

    variable xg    {}
    variable files {}

    constructor {file args} {
	after 1 [mymethod Run $file]
	$self configurelist $args
	return
    }
    destructor {
	if {$xg != {}} {rename $xg {}}
    }

    # ------------------------------------------------
    method Run {file} {
	# Note: We allow violations of version syntax here, as they
	# have no bearing on our ability to look for and scan the
	# files in the package.

	set errors {}
	set plist [teapot::metadata::read::fileEx $file multi errors 1]
	if {![llength $plist] || [llength $errors]} {
	    $self CallError "The chosen file does not contain TEAPOT Meta Data:\n[join $errors \n]"
	    return
	}

	# Pull out a list of files for each package via the
	# included/excluded keywords, globbing, uniqueifying.

	set top   [file dirname [file normalize $file]]
	set files {}
	set ferr  {}
	foreach p $plist {
	    teapot::instance::split [$p instance] pe pn pv pa
	    if {![::teapot::metadata::filesSet $top $p errmessage]} {
		append errmessage " for $pe \"$pn\""
		lappend ferr $errmessage
	    } else {
		foreach f [$p getfor __files] {
		    if {[file extension $f] ne ".tcl"} continue
		    lappend files [file join $top $f]
		}
	    }
	    $p destroy
	}

	if {![llength $files]} {
	    $self CallError [join $ferr \n]
	    return
	}

	# Constructor auto-launches the scanning
	set xg [xref_gather ${selfns}::xg [lsort -uniq $files] \
		    -command [mymethod Call] \
		    -errcommand [mymethod CallError] \
		    -ping $options(-ping)]
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

package provide teapot_gather 0.1
