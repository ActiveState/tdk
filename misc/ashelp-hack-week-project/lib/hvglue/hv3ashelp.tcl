# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
package require fileutil
package require ashelp

namespace eval hv3 {
    variable  file    ; # 
    array set file {} ; # base -> file
    variable  base    ; #
    array set base {} ; # file -> base
    variable  db      ; #
    array set db {}   ; # file -> db accessor object

    variable files {}
    variable err   {}
}

proc hv3::ashelp_drop {} {
    variable    base
    array unset base *
    variable    file
    array unset file *
    variable    db
    array unset db   *
    variable files {}
    return
}

proc hv3::B {f} {
    return [file rootname [file tail $f]]
}

proc hv3::ashelp {helpfiles} {
    variable base
    variable file
    variable db
    variable files
    foreach f $helpfiles {
	if {![::ashelp valid $f ro msg]} {
	    return -code error $msg
	}
    }

    foreach f $helpfiles {
	set fbase [B $f]

	if {[info exists base($fbase)]} {
	    set n 1
	    while {[info exists base(${fbase}-$n)]} {incr n}
	    set fbase ${fbase}-$n
	}
	set file($fbase) $f
	set base($f)     $fbase
	set db($f)       [::ashelp %AUTO% -location $f]
    }

    set first [lindex $helpfiles 0]
    set fo $db($first)
    set fb $base($first)

    set files $helpfiles

    # Return first link in first file as homeuri
    set top [lindex [$fo toc] 0 2]
    return ashelp:///db/$fb$top
}

proc hv3::ashelp_toc {} {
    variable files
    variable base
    variable db

    set res {} 

    # Merge the tocs and finalize the links (schema, and relocation
    # into separate sub-trees).

    set id 0
    foreach f $files {
	set pid {}
	set fo $db($f)
	set fb $base($f)
	set toc [$fo toc]
	foreach t $toc {
	    foreach {p label link} $t break
	    lappend pid $id
	    if {$p >=0} {
		set p [lindex $pid $p]
	    }
	    if {$link eq ""} {
		lappend res [list $p $label {}]
	    } else {
		lappend res [list $p $label ashelp:///db/$fb$link]
	    }
	    #puts [lindex $res end]
	    incr id
	}
    }

    #puts [join $res \n]
    return $res
}

proc hv3::ashelp_search {phrase} {
    variable files
    variable base
    variable db
    variable err

    set res {}

    foreach f $files {
	set fo $db($f)
	set fb $base($f)
	if {[catch {
	    set dict [$fo find $phrase]
	}]} {
	    #puts FTS\t$::errorInfo
	    set err $::errorInfo
	    return -code error {Bad Phrase Syntax}
	}
	foreach {link title} $dict {
	    set link ashelp:///db/$fb$link
	    lappend res $link $title
	}
    }

    return $res
}



proc hv3::ashelp_request {do} {
    # do - download object.

    # Get link and strip schema (known to be ashelp://).
    set link [$do cget -uri]

    #puts Z:$link
    #puts M:[$do cget -mimetype]

    $do append [ashelp_read $link]
    $do finish
    return
}

proc hv3::ashelp_read {link} {
    variable files
    variable file
    variable base
    variable db
    variable err

    # Strip off a possible fragment specification
    regsub -all {#.*$} $link {} link

    set res {}
    if {[string match "ashelp:///sys*" $link]} {
	if {$link eq "ashelp:///sys/error"} {
	    append res {<h1>Search Error</h1><pre>}
	    append res $err
	    append res {</pre>}
	} else {
	    append res {<h1>Bad Link</h1><pre>}
	    append res $link
	    append res {</pre>}
	}
	return $res
    } elseif {![string match "ashelp:///db/*" $link]} {
	append res {<h1>Bad Link</h1><pre>}
	append res $link
	append res {</pre>}
	return $res
    }

    set link [string range $link 12 end]
    #puts X:$link

    # Use first segment of link (after /db, already stripped) to
    # determine which # of the several help files to use. The
    # remainder is the link # inside of that file.  #parray map

    set thebase [lindex [file split $link] 1]
    set link /[fileutil::stripN $link 2]
    #puts B:$base

    set f $file($thebase)

    set fo $db($f)
    set fb $base($f) ; # assert ($fb eq $thebase)

    #puts H:$f
    #puts @:$fo
    #puts L:$link

    if 0 {
	if {![string match text* [$do cget -mimetype]]} {
	    fconfigure $fd -encoding binary -translation binary
	}
    }

    if {[catch {
	set res [$fo read $link]
    } msg]} {
	set res "<h1>Bad reference $link</h1><pre>$msg</pre>"
    }

    return $res
}

package provide hv3::ashelp 0.1
