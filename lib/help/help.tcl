# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# Access to help for our applications ...
# Copyright (c) 2001-2010 ActiveState Software Inc.
#               Tools & Languages

# ### ######### ###########################
# Requisites

# Defer package require Tk until needed to delay Tk loading

namespace eval ::help {}

# ### ######### ###########################
# public API

proc ::help::page {page_} {
    variable page $page_
    return
}


proc ::help::appname {appname_} {
    variable appname $appname_
    return
}


proc ::help::helpfile {helpfile_} {
    variable winhelpfile $helpfile_
    return
}


proc ::help::activetcl {subdir} {
    variable activetcl 1
    variable sub       $subdir
    return
}


proc ::help::open {} {
    package require Tk
    switch -exact [tk windowingsystem] {
	x11	{ XOpen }
	aqua	{ MacOpen }
	win32	{ WinOpen }
	default { return -code error "unknown platform" }
    }
}


proc ::help::openUrl {url} {
    package require Tk
    switch -exact [tk windowingsystem] {
        x11	{UnixOpenUrl $url}
        win32	{WinOpenUrl  $url}
        aqua	{MacOpenUrl  $url}
	default { return -code error "unknown platform" }
    }
}

# ### ######### ###########################
# Internal commands

proc ::help::MacOpen {} {
    variable page
    variable activetcl

    # On darwin the aT tool specific docs are in the sub directory of
    # the main AT docs. Otherwise identical to XOpen.

    if {$activetcl} {
	variable sub
	set file [LocateFile $sub/$page.html]
	if {$file == {}} return
	openUrl file://$file
	return
    }

    set file [LocateFile tdk.index.html]
    if {$file == {}} return
    openUrl file://${file}?page=${page}.html
}

proc ::help::XOpen {} {
    variable page
    variable activetcl

    # On X11 the AT tool specific docs are in the toplevel doc
    # directory. The main AT docs do not exist, only the tool
    # docs. See also MacOpen (above), where the main AT docs are part
    # of the distribution, and the tool specific stuff moved into a
    # sub directory.

    if {$activetcl} {
	set file [LocateFile $page.html]
	if {$file == {}} return
	openUrl file://$file
	return
    }

    set file [LocateFile tdk.index.html]
    if {$file == {}} return
    openUrl file://${file}?page=${page}.html
}

proc ::help::WinOpen {} {
    variable winhelpfile
    variable page
    variable activetcl

    if {$activetcl} {
	set file [LocateFile $page.html]
	if {$file == {}} return
	WinOpenUrl file://$file
	return
    }

    set file [LocateFile $winhelpfile]
    if {$file == {}} return

    if 1 {
	WinOpenUrl "mk:@MSITStore:[file nativename $file]::/${page}.html"
    } else {
	WinOpenUrl "mk:@MSITStore:[file nativename $file]::/tdk.index.html?page=${page}.html"
    }
    return
}

proc ::help::WinOpenUrl {url} {
    # Perform basic url quoting and escape &'s in url ...
    set url [string map {{ } %20 & ^&} $url]

    set failed [catch {
	exec >NUL: <NUL: $::env(COMSPEC) /c start $url &
    } emsg]

    if {$failed} {
	tk_messageBox -title "Error Launching Help" -icon error -type ok \
		-message "Error Launching $url:\n$emsg"
    }
    return
}


proc ::help::MacOpenUrl {url} {
    set url [string map {{ } %20} $url]
    if {[catch {
	#package require Tclapplescript
	#AppleScript execute "do shell script \"open $url\""
	exec open $url &
    } emsg]} {
	tk_messageBox -title "Error displaying URL" -icon error -type ok \
	    -message "Error displaying url \"$url\":\n$emsg"
    }
}

proc ::help::UnixOpenUrl {url} {
    set redir ">&/dev/null </dev/null"

    if {[info exists ::env(BROWSER)]} {
	set browser $::env(BROWSER)
    }

    expr {
	[info exists browser] ||
	[FindExecutable firefox   browser] ||
	[FindExecutable mozilla   browser] ||
	[FindExecutable netscape  browser] ||
	[FindExecutable iexplorer browser] ||
	[FindExecutable opera     browser] ||
	[FindExecutable lynx      browser]
    }

    # lynx can also output formatted text to a variable
    # with the -dump option, as a last resort:
    # set formatted_text [ exec lynx -dump $url ] - PSE

    if {![info exists browser]} {
	return -code error "Could not find a browser to use"
    }

    if {[string equal [file tail $browser] netscape]} {
	# -remote url is not understood, only
	# -remote openUrl(url)

	if {
	    [catch {RunB $browser -remote openUrl($url)} xmsg] &&
	    [catch {RunB $browser $url &} emsg]
	} {
	    return -code error "Error displaying $url in browser\n$emsg"
	    # Another possibility is to just pop a window up
	    # with the URL to visit in it. - DKF
	}
    } else {
	# Assume that browser may understand -remote url
	# perhaps browser doesn't understand -remote flag
	if {
	    [catch {RunB $browser -remote $url} xmsg] &&
	    [catch {RunB $browser $url &} emsg]
	} {
	    return -code error "Error displaying $url in browser\n$emsg"
	    # Another possibility is to just pop a window up
	    # with the URL to visit in it. - DKF
	}
    }
    return
}


proc help::LocateFile {fname} {
    variable DIR
    variable appname
    variable activetcl
    global tcl_platform

    if {$tcl_platform(os) eq "Darwin"} {

	if {$activetcl} {
	    set pattern *
	} else {
	    set pattern TclDevKit-*
	}

	set docdir [file join [file dirname $DIR(EXE)] Resources English.lproj]
	set dirs [list [lindex [lsort -dictionary \
				    [glob -nocomplain -directory $docdir \
					 $pattern]] end]]
    } else {
	set dirs [list \
		      [file join [file dirname $DIR(EXE)] doc] \
		      [file join [file dirname $DIR(SCRIPT)] doc]]
    }

    foreach dir $dirs {
	set path [file join $dir $fname]
	if {[file exists $path]} {
	    return $path
	}
    }

    set res [tk_messageBox -title "Help Not Found" -icon error -type okcancel \
		 -message "Could not find $appname help file in any of:\
		\n[join $dirs \n]\nAccess online documentation?"]
    if {$res eq "ok"} {
	# Return a default pointer to online docs
	openUrl "http://aspn.activestate.com/ASPN/docs/TclDevKit"
    }
    return ""
}

proc ::help::FindExecutable {progname varname} {
    upvar 1 $varname result
    set progs [auto_execok $progname]
    if {[llength $progs]} {
	set result [lindex $progs 0]
    }
    return [llength $progs]
}

proc ::help::RunB {args} {
    ##puts ___$args
    eval exec $args
}

# ### ######### ###########################
# Define, initialize datastructures.

namespace eval ::help {
    variable activetcl 0
    variable winhelpfile TclDevKit.chm
    variable page
    if {![info exists page]} { set page "" }
    variable appname
    if {![info exists appname]} { set appname my }

    # Basic environment

    set DIR(EXE)    [file normalize [file dirname [info nameofexecutable]]]
    set DIR(SCRIPT) [file normalize [file dirname [info script]]]
}

# ### ######### ###########################
# Ready

package provide help 0.4
