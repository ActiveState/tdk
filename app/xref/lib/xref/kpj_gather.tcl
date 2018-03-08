# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# kpj_gather - /snit::type
#
# Scans files, gathers xref data ...

package require snit
package require xref_gather
package require tdom

snit::type ::kpj_gather {

    option -command {}
    option -onerror {}
    option -ping    {}


    variable xmlparse {}
    variable xg       {}
    variable files    {}
    variable kpfloc

    constructor {file args} {
	set xmlparse [::xml::parser kpj \
		-elementstartcommand  [mymethod begin] \
		-final 1 \
		]

	after 1 [mymethod Run $file]
	$self configurelist $args
	return
    }
    destructor {
	if {$xg != {}} {rename $xg {}}
	$xmlparse free
    }

    # ------------------------------------------------
    method Run {file} {
	set             fh [open $file r]
	set data [read $fh]
	close          $fh

	set files {}
	set kpfloc [file dirname $file]

	if {[catch {
	    $xmlparse parse $data
	} msg]} {
	    #puts $::errorInfo
	    $self CallError $msg
	    return
	} elseif {[llength $files] == 0} {
	    #puts No/Files
	    $self CallError "No files found"
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
    # Decoder callbacks

    variable state project

    method begin    {tag args} {
	set args [lindex $args 0]
	switch -exact -- $state {
	    project {
		if {
		    ($tag eq "project") &&
		    ([lsearch -exact $args kpf_version] >= 0)
		} {
		    # Is a komodo project, now look for files.
		    set state files
		    return
		}
		return -code error "The chosen\
			file is not a Komodo Project File"
	    }
	    files {
		# Ignore everything which is not a file.
		if {$tag ne "file"} {return}
		array set _ $args
		if {![info exists _(url)]} {
		    return -code error "The chosen\
			    file is not a Komodo Project File"
		}

		# We ignore all files which do not end in '.tcl'. Easy
		# skip over binaries which cannot be scanned for tcl
		# code.

		set f $_(url)
		# Check if a file:// scheme is in front of the url,
		# and strip it out if so.

		if {[$type isuri $f]} {
		    set f [$type uritopath $f]
		} elseif {[regexp {^((http)|(ftp)):} $f]} {
		    # Some other schema, ignore.
		    return
		}
		set f [file join $kpfloc $f]
		if {[file exists $f] && [$self isTcl $f]} {
		    lappend files $f
		}
	    }
	}
    }

    method isTcl {path} {
	# Use various methods to determine if a file is for the Tcl
	# language. This is the same algorithm as used by Komodo as
	# has to be kept in sync with it.
	# Check contents first.

	if {[$self isTclEmacs   $path]}       {return 1}
	if {[$self isTclShebang $path]}       {return 1}
	if {[file extension $path] eq ".tcl"} {return 1}
	return 0
    }

    method isTclEmacs {path} {
	set n [file size $path]
	set f [open $path r]
	if {$n < 1000} {
	    set head [read $f]
	    set tail $head
	} else {
	    set head [read $f 1000]
	    seek $f -1000 end
	    set tail [read $f 1000]
	}
	close $f

	# Spec: http://www.gnu.org/software/emacs/manual/html_chapter/emacs_33.html#SEC485

	if {[$self isTclEmacsTail $tail]} {return 1}
	if {[$self isTclEmacsHead $head]} {return 1}
	return 0
    }

    method  isTclEmacsHead {text} {
	set hp {-\*-\s*(.*?)\s*-\*-}

	if {[string first "-*-" $text] < 0}         {return 0}
	if {![regexp -- $hp $text total localVars]} {return 0}
	if {[string first "\n" $total] >= 0}        {return 0}

	set tmp {}
	foreach item [split $localVars \;] {
	    lappend tmp [string trim $item]
	}
	set localVars $tmp

	if {([llength $localVars] == 1) && ([string first : [lindex $localVars 0]] < 0)} {
	    # While not in the spec, this form is allowed by emacs:
	    #   -*- Tcl -*-
	    # where the implied "variable" is "mode". This form is only
	    # allowed if there are no other variables.

	    set localVars [list mode [string trim [lindex $localVars 0]]]
	} else {
	    set tmp {}
	    foreach item $localVars {
		foreach {var val} [split $item :] break
		lappend tmp [string tolower [string trim $var]] [string trim $val]
	    }
	    set localVars $tmp
	}
	unset tmp
	array set tmp $localVars

	if {![info exists tmp(mode)]} {return 0}
	if {![string equal [string tolower $tmp(mode)] tcl]} {return 0}
	return 1
    }

    method  isTclEmacsTail {text} {

	# This regular expression is intended to match blocks like this:
	#    PREFIX Local Variables: SUFFIX
	#    PREFIX mode: Tcl SUFFIX
	#    PREFIX End: SUFFIX
	# Some notes:
	# - "[ \t]" is used instead of "\s" to specifically exclude newlines
	# - "(\r\n|\n|\r)" is used instead of "$" because the sre engine does
	#   not like anything other than Unix-style line terminators.

	set pattern {([^\n]+)[ \t]*Local Variables:[ \t]*([^\n]*)\n(.*)End:}
	#set pattern {([^\n]+)[ \t]*Local Variables:[ \t]*}

        # Search the tail for a "Local Variables" block.

	if {![regexp -nocase $pattern $text -> prefix suffix content]} {
	    return 0
	}

	set lines [split $content \n]

	# Validate the Local Variables block: proper prefix and suffix
	# usage.

	set plen [string length $prefix]
	set slen [string length $suffix]
	if {$plen} {
	    foreach line $lines {
		if {![string first $prefix $line] == 0} {return 0}
	    }
	}

	# Don't validate suffix on last line. Emacs doesn't care,
	# neither should Komodo.
	if {$slen > 0} {
	    foreach line [lrange $lines 0 end-1] {
		if {![string last $suffix $line] == $slen} {return 0}
	    }
	}

	array set tmp {}
	foreach line [lrange $lines 0 end-1] {
	    if {$slen} {set line [string range $line 0 end-$slen]}
	    if {$plen} {set line [string range $line $plen end]}
	    set line [string trim $line]

	    foreach {var val} [split $line :] break
	    set tmp([string trim $var]) [string trim $val]
	}

	if {![info exists tmp(mode)]} {return 0}
	if {![string equal [string tolower $tmp(mode)] tcl]} {return 0}
	return 1
    }

    typevariable tclshebangpatterns [list \
	    {^#!.*tclsh.*$} \
	    {^#!.*wish.*$} \
	    {^#!.*expect.*$} \
	    {^#!.*\nexec tclsh} \
	    {^#!.*\nexec wish} \
	    {^#!.*\nexec expect} \
	    ]

    method isTclShebang {path} {
	set f [open $path r]
	set head [read $f 1000]
	close $f

	# Check a number of regex patterns ...
	foreach pattern $tclshebangpatterns {
	    if {[regexp -nocase $pattern $head]} {return 1}
	}
	return 0
    }


    typevariable fileschema    ; # Prefix for file URIs
    typeconstructor {
	set fileschema file://
	if {$::tcl_platform(platform) == "windows"} {
	    append fileschema /
	}
    }

    typemethod uritopath {uri} {
	regsub ^$fileschema $uri {} uri

	# Handle encoded characters in the uri. (Like %20 = space)
	# Minimal, only spaces are handled right now.

	set     path [string map {%20 { }} $uri]
	return $path
    }

    typemethod isuri {string} {
	return [regexp ^$fileschema $string]
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

package provide kpj_gather 0.1
