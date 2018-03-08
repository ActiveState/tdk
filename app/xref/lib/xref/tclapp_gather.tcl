# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# tclapp_gather - /snit::type
#
# Scans files, gathers xref data ...

package require snit
package require xref_gather
package require tdk_tclapp
package require tdk_prowrap

snit::type ::tclapp_gather {

    option -command {}
    option -onerror {}
    option -ping    {}


    variable td    ; # Array, initialized in constructor.
    variable pp    ; # Array, initialized in constructor.
    variable xg    {}
    variable files {}

    constructor {file args} {
	foreach {fmt class postprocessor} {
	    {Tcl Dev Kit TclApp}  tdk_tclapp  ProcessTclApp
	    {Tcl Dev Kit Wrapper} tdk_prowrap ProcessWrapper
	} {
	    set td($fmt) [$class %AUTO% {}]
	    set pp($fmt) $postprocessor
	}

	after idle [mymethod Run $file]
	$self configurelist $args
	return
    }
    destructor {
	if {$xg != {}} {rename $xg {}}
    }
    # ------------------------------------------------
    method Run {file} {

	set fmt [$self FindFormat $file]
	if {$fmt == {}} {
	    $self CallError [$self InvalidFormat]
	    return
	}

	# Dynamic choice of processing objects and methods
	# based on the detected format.

	set files {}
	if {[catch {
	    set data [$td($fmt) read $file]
	} msg]} {
	    #puts $::errorInfo
	    $self CallError $msg
	    return
	}

	if {$pp($fmt) != {}} {
	    $self $pp($fmt) $data
	}

	if {[llength $files] == 0} {
	    #puts No/Files
	    $self CallError "No Files Found" ;#[$td($fmt) errors]
	    return
	}

	# Constructor auto-launches the scanning
	set xg [xref_gather xg [lsort -uniq $files] \
		    -command [mymethod Call] \
		    -errcommand [mymethod CallError] \
		    -ping $options(-ping)]
	return
    }

    # ------------------------------------------------
    # Find format.

    method FindFormat {file} {
	foreach fmt [array names pp] {
	    if {[$td($fmt) match $file] == 1} {
		return $fmt
	    }
	}
	return {}
    }

    method InvalidFormat {} {
	set formats [array names pp]
	if {[llength $formats] == 1} {
	    return "The chosen file is not a\
		    [lindex $formats 0] file"
	} else {
	    set msg "The chosen file is neither a\
		    [lindex $formats 0] file"
	    foreach f [lrange $formats 1 end] {
		append msg ", nor a $f file"
	    }
	    append  msg .
	    return $msg
	}
    }

    # ------------------------------------------------
    # Decoding

    method ProcessTclApp {tclapp_data} {
	# Only some keys are of interest to us.

	foreach {k v} $tclapp_data {

	    #   v = list of arguments. #args = 1 => Unpack list into v
	    set v [lindex $v 0]

	    switch -exact -- $k {
		App/Package - Package {
		    ##-- Future / TODO : Recurse into .tap
		}
		Path {
		    ## File data
		    foreach {cmd detail} $v break
		    switch -exact -- $cmd {
			File {
			    ## Expand a possible glob pattern.
			    foreach f [glob -nocomplain $detail] {
				if {[file extension $f] ne ".tcl"} continue
				lappend files $f
			    }
			}
			default {
			    # Ignoring:
			    # Relativeto, Startup, Anchor, Alias
			}
		    }
		}
		default {# Ignore everything else}
	    }
	}
	return
    }

    method ProcessWrapper {prowrap_data} {
	# Only some keys are of interest to us.
	foreach {k v} $prowrap_data {

	    #   v = list of arguments. #args = 1 => Unpack list into v
	    set v [lindex $v 0]

	    if {$k eq "Files"} {
		foreach fitem $files {
		    foreach {ftype fpattern more} $fitem break ; # lassign
		    if {$ftype ne "directory"} {
			lappend options $fpattern
		    } else {
			# ftype eq "directory"
			set fdir $fpattern
			foreach fitem $more {
			    foreach {ftype fpattern} $fitem break ; # lassign
			    lappend options [file join $fdir $fpattern]
			}
		    }
		}
	    } ; # else ignore everything else {}
	}

	# Now de-glob the collected patterns ...

	foreach detail $options {
	    foreach f [glob -nocomplain $detail] {
		if {[file extension $f] ne ".tcl"} continue
		lappend files $f
	    }
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

package provide tclapp_gather 0.1

