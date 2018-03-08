# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xref_gather - /snit::type
#
# Scans files, gathers xref data ...

package require snit
package require fileutil
package require Memchan

## ::selfapp required


snit::type ::xref_gather {

    option -command {}
    option -errcommand {}
    option -ping

    variable pingrate 15
    variable pingcnt  0

    variable pipe    {} ;# Pipe to scanner
    variable tmpfile {} ;# Tmp database where scanner stores data.

    constructor {files args} {
	after 1 [mymethod Run $files]
	$self configurelist $args
	return
    }
    destructor {
	if {$pipe ne ""} {
	    close $pipe
	    file delete -force $tmpfile
	}
    }

    # ------------------------------------------------

    method Call {dbfile} {
	if {[llength $options(-command)]} {
	    uplevel \#0 [linsert $options(-command) end $dbfile]
	}
    }

    method CallError {error} {
	if {[llength $options(-errcommand)]} {
	    set error "Error reported by [procheck] while scanning the files:\n\n\
                         [join [lrange [split $error \n] 0 10] "\n  "]"
	    uplevel \#0 [linsert $options(-errcommand) end $error]
	}
    }

    method Ping {} {
	if {[llength $options(-ping)] && ([incr pingcnt] == $pingrate)} {
	    uplevel \#0 $options(-ping)
	    set pingcnt 0
	}
    }

    method Run {files} {
	package require Memchan

	set tmpfile [fileutil::tempfile tdkxref_]
	set infile  [fileutil::tempfile tdkxrin_]
	set errfile [fileutil::tempfile tdkxrer_]

	# Construct the full command first.

	# NOTE: (::selfapp) defined in main.tcl ...
	# Better as a helper in some library ... (Starkit support)

	# On unix we check that the found checker is patched to run on
	# some tdkbase .. If not, we force the use of our own runtime.
	# This code should not trigger in a regular installation. It
	# does allow us however to run xref scanning from an unin-
	# stalled distribution. Used during build verification.
	set cmd {}
	if {$::tcl_platform(platform) ne "windows"} {
	    set c [procheck]
	    set c [open $c r]
	    gets $c ; # hash bang /bin/sh
	    gets $c ; # continuation line
	    gets $c execline
	    close $c
	    if {![string match *tdkbase* $execline]} {
		lappend cmd [info nameofexecutable]
	    }
	}

	lappend cmd [procheck]
	lappend cmd -xref -ping
	## lappend cmd 2> /dev/null   ;# 2>@ [null]

	lappend cmd -@ $infile

	set fx [open $infile w]
	foreach f $files {puts $fx $f}
	close $fx

	#foreach f $files {lappend cmd $f}
	lappend cmd |
	foreach {exe app} [::selfapp] break
	lappend cmd $exe
	if {$app != {}} {lappend cmd $app}
	lappend cmd -convert $tmpfile
	## lappend cmd > /dev/null ; #>@ [null]

	lappend cmd 2> $errfile

	#puts ">>|$cmd<<"

	set         pipe [open |$cmd r+]
	fconfigure $pipe -translation binary -encoding binary -blocking 0
	fileevent  $pipe readable [mymethod Handle $tmpfile $infile $errfile]
	return
    }

    variable n 0
    method Handle {dbfile infile errfile} {
	set blob [read $pipe] ;# Read anything waiting, and ignore the data
	#                     ;# this is just logging. We also drive the UI
	#                     ;# (Progressbar)

	if {[eof $pipe]} {
	    # EOF = Scanning completed, kill pipe and continue in
	    # main application

	    #puts Handle/EOF/$pipe/[file size $errfile]

	    catch {close $pipe}
	    set pipe {}

	    # On windows wait half a second for the OS to reap the
	    # closed child, or otherwise the 'errfile' may still be
	    # locked against deletion when we try to do so in
	    # 'Complete' below.
	    if {$::tcl_platform(platform) eq "windows"} {
		after 500 [mymethod Complete $dbfile $infile $errfile]
	    } else {
		after idle [mymethod Complete $dbfile $infile $errfile]
	    }
	}

	if {[string length $blob] == 0 } return

	#puts Handle/[incr n]/[string length $blob]
	#puts $blob

	$self Ping
    }

    method Complete {dbfile infile errfile} {
	file delete -force $infile
	if {[file size $errfile]} {
	    set err [read [set c [open $errfile]]][close $c]
	    file delete -force $errfile
	    set tmpfile {}
	    $self CallError $err
	} else {
	    file delete -force $errfile
	    #puts Complete
	    set tmpfile {}
	    $self Call $dbfile
	}
    }
}

package provide xref_gather 0.1

