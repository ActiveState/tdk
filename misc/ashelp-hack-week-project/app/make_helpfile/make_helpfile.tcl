# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}
lappend auto_path [file dirname [file dirname [info script]]]/lib

# argv = dbfile directory ?anchor?

# ### ### ### ######### ######### #########
##

proc usage {} {
    global argv0
    puts stderr "usage: $argv0 helpfile dir ?anchor?"
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
    global argc argv location dir anchor

    if {($argc < 2) || ($argc > 3)} usage;

    set anchor /
    foreach {location dir anchor} $argv break
    set dir    [file normalize $dir]
    set anchor [file join / $anchor]
    return
}

proc setup {location} {
    package require ashelp

    if {[ashelp valid $location ro msg]} {
	global argv0
	puts stderr "$argv0: $location already a help file"
	exit 1
    } else {
	#puts $msg
    }

    ashelp new $location
    return [ashelp %AUTO% -location $location]
}

proc isfile {f} {
    # Do not accept non-files, nor xml tables of contents
    expr {[file isfile $f] && ![string match *toc.xml $f]}
}

proc pl {n singular {plural {}}} {
    if {$plural == {}} {set plural ${singular}s}
    return "$n [expr {$n == 1 ? $singular : $plural}]"
}

proc scanfiles {db dir anchor} {
    package require fileutil::traverse
    log "Scanning $dir for pages ..."
    set t [fileutil::traverse %AUTO% $dir -filter isfile]
    set files {}
    $t foreach f {
	ping
	set f [fileutil::stripPath $dir $f]
	lappend files $f
    }
    $t destroy
    log "\nAdding [pl [llength $files] page] .."
    set here [pwd] ; cd $dir
    $db addpages $files $anchor
    cd $here
    log Done
    return
}

proc entertoc {db dir anchor} {
    if {[file exists $dir/toc.xml]} {
	log "TOC: Logical structure per toc.xml ..."

	set toc [ashelp toc.xml $dir/toc.xml]
    } else {
	log "TOC: Physical structure based on directory tree ..."

	set toc [ashelp toc.physical $dir]
    }

    log "Found [pl [llength $toc] node] ..."
    #puts [join $toc \n]
    #exit 1
    log "Adding TOC ..."

    $db setToc $toc $anchor
    log Done
}

# ### ### ### ######### ######### #########
##

proc main {} {
    global location dir anchor here
    cmdline
    set here [pwd]
    set db [setup $location]
    scanfiles $db $dir $anchor
    entertoc  $db $dir $anchor
    return
}

# ### ### ### ######### ######### #########
##

main
