# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}
lappend auto_path [file dirname [file dirname [file dirname [info script]]]]/lib

# argv = dbfile ?directory?

# ### ### ### ######### ######### #########
##

proc usage {} {
    global argv0
    puts stderr "usage: $argv0 helpfile ?dir?"
    exit 1
}

proc log {text} {
    puts stdout $text
}

proc ping {} {
    puts -nonewline .
    flush stdout
}

# ### ### ### ######### ######### #########
##

proc cmdline {} {
    global argc argv location dir

    if {($argc < 1) || ($argc > 2)} usage;

    set dir {}
    foreach {location dir} $argv break
    return
}

proc setup {location} {
    package require ashelp

    if {![ashelp valid $location ro msg]} {
	global argv0
	puts stderr "$argv0: $location not a help file"
	exit 1
    } else {
	#puts $msg
    }

    return [ashelp %AUTO% -location $location]
}

proc dumpfiles {db dir} {
    log "\tFiles:"

    if {$dir ne ""} {
	foreach f [lsort -dict [$db files]] {
	    # Chop leading /
	    set f [string range $f 1 end]
	    set dst [file join $dir $f]
	    file mkdir [file dirname $dst]
	    log "\t\t$f ..."
	    fileutil::writeFile $dst [$db read $f]
	}
    } else {
	foreach f [lsort -dict  [$db files]] {
	    # Chop leading /
	    set f [string range $f 1 end]
	    log "\t\t$f ..."
	}
    }
    return
}

proc dumptoc {db dir} {
    log "\tTable Of Contents:"

    set toc [$db toc]
    if {$dir ne ""} {
	fileutil::writeFile $dir/toc.xml [ashelp xml.toc $toc]\n
    }
    puts \t\t[join [split [ashelp plaintext.toc $toc] \n] \n\t\t]
    return
}

# ### ### ### ######### ######### #########
##

proc main {} {
    global location dir anchor here
    cmdline
    set here [pwd]
    set db [setup $location]

    log "ASHelp Dump <$location>"

    if {$dir ne ""} {
	log "\tInto $dir"
    }

    dumpfiles $db $dir
    dumptoc   $db $dir

    log Done
    return
}

# ### ### ### ######### ######### #########
##

main
