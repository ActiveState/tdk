# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# config.tcl --
#
#	Code to read and write configuration files.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------

namespace eval ::tcldevkit::config {}

interp alias {} once {} foreach _ _ ; # convencience : breakable sequence.

# -----------------------------------------------------------------------------

proc ::tcldevkit::config::Peek/2.0 {file} {
    # Determines information about the file from the standard headers.
    # Returns info if the file is a 2.0 config file, and for what
    # application if yes.

    set chan [open $file r]

    set format [set fversion [set ftool ""]]
    once {
	# Three-line standard header ...
	if {![getline $chan format]}                              { break }
	if {![getline $chan fversion]}                            { break }
	if {![getline $chan ftool]}                               { break }
    }
    close $chan

    # Check the retrieved information for conformance to the "Tcldevkit
    # Project File Format Specification, 2."0 and extract the tool
    # information.

    if {
	[string equal $format   "format  \{TclDevKit Project File\}"] &&
	[string equal $fversion "fmtver  2.0"] &&
	[regexp "^fmttool" $ftool]
    } {
	regexp "^fmttool *\{(\[^\}\]*)\} *(.*)\$" $ftool -> tool toolversion
	return [list 1 $tool]
    } else {
	return {0 {}}
    }
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::config::getline {chan var} {
    upvar 1 $var line
    return [expr {([gets $chan line] >= 0) && ![eof $chan]}]
}

# -----------------------------------------------------------------------------
# Write the configuration of the application in 2.0 format.

proc ::tcldevkit::config::Write/2.0 {
    outfile cfg appName appVers
} {
    global   tcl_platform
    variable off

    set    chan [open $outfile w]

    # Standard header ...

    puts  $chan "format  \{TclDevKit Project File\}"
    puts  $chan "fmtver  2.0"
    puts  $chan "fmttool [list $appName $appVers]"

    # Place some meta information in comments
    # (Note: Saved configuration is a tcl script)
    # Semi standard.

    puts  $chan ""
    puts  $chan "##  Saved at : [clock format [clock seconds]]"
    puts  $chan "##  By       : $tcl_platform(user)@[info hostname]"
    puts  $chan ""
    puts  $chan "########"
    puts  $chan "#####"
    puts  $chan "###"
    puts  $chan "##"
    puts  $chan "#"
    puts  $chan ""

    # And now the tool specific contents

    # Allow the specification of data written over multiple line.
    # ([llength cfg] % 2) == 0  ==> Standard output
    # [llength cfg]       == 3  ==> Multi-line keys + dummy element + regular configuration.

    set ml_keys {}
    if {[llength $cfg] == 3} {
	foreach {ml_keys __ cfg} $cfg { break }
	unset __
    }

    if {[array size off] == 0} {
	computeOff $cfg
    }

    array set data $cfg

    foreach key [array names data] {
	if {![info exists off($key)]} {
	    computeOff $cfg
	    break
	}
    }

    if {[llength $ml_keys] == 0} {
	foreach key [lsort [array names data]] {
	    puts $chan "$key$off($key) [list $data($key)]"
	}
    } else {
	foreach key [lsort [array names data]] {
	    if {[lsearch -exact $ml_keys $key] >= 0} {
		foreach item $data($key) {
		    puts $chan "$key$off($key) [list $item]"
		}
	    } else {
		puts $chan "$key$off($key) [list $data($key)]"
	    }
	}
    }

    # Semi standard trailer ...

    puts  $chan ""
    puts  $chan "#"
    puts  $chan "##"
    puts  $chan "###"
    puts  $chan "#####"
    puts  $chan "########"
    close $chan
    return
}

proc ::tcldevkit::config::computeOff {cfg} {
    variable off

    # Compute offset information so that all values are
    # vertically aligned. Done once, as it does not change
    # for the application.

    set maxlen 0
    foreach {key val} $cfg {
	set off($key) [set len [string length $key]]
	if {$len > $maxlen} {set maxlen $len}
    }
    foreach key [array names off] {
	set off($key) [string repeat " " [expr {$maxlen - [string length $key]}]]
    }
}


proc ::tcldevkit::config::WriteOrdered/2.0 {
    outfile cfg appName appVers {appcomment {}}
} {
    global   tcl_platform
    variable off

    set    chan [open $outfile w]

    # Standard header ...

    puts  $chan "format  \{TclDevKit Project File\}"
    puts  $chan "fmtver  2.0"
    puts  $chan "fmttool [list $appName $appVers]"

    # Place some meta information in comments
    # (Note: Saved configuration is a tcl script)
    # Semi standard.

    puts  $chan ""
    puts  $chan "##  Saved at : [clock format [clock seconds]]"
    puts  $chan "##  By       : $tcl_platform(user)@[info hostname]"

    if {$appcomment != {}} {
	puts  $chan "##"
	puts  $chan "##  $appcomment"
    }

    puts  $chan ""
    puts  $chan "########"
    puts  $chan "#####"
    puts  $chan "###"
    puts  $chan "##"
    puts  $chan "#"
    puts  $chan ""

    # And now the tool specific contents

    # Allow the specification of data written over multiple line.
    # ([llength cfg] % 2) == 0  ==> Standard output
    # [llength cfg]       == 3  ==> Multi-line keys + dummy element + regular configuration.

    set ml_keys {}
    if {[llength $cfg] == 3} {
	foreach {ml_keys __ cfg} $cfg { break }
	unset __
    }

    if {[array size off] == 0} {
	computeOff $cfg
    }
    foreach {key val} $cfg {
	if {![info exists off($key)]} {
	    computeOff $cfg
	    break
	}
    }

    if {[llength $ml_keys] == 0} {
	foreach {key val} $cfg {
	    puts $chan "$key$off($key) [list $val]"
	}
    } else {
	foreach {key val} $cfg {
	    if {[lsearch -exact $ml_keys $key] >= 0} {
		foreach item $data($key) {
		    puts $chan "$key$off($key) [list $item]"
		}
	    } else {
		puts $chan "$key$off($key) [list $val]"
	    }
	}
    }

    # Semi standard trailer ...

    puts  $chan ""
    puts  $chan "#"
    puts  $chan "##"
    puts  $chan "###"
    puts  $chan "#####"
    puts  $chan "########"
    close $chan
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::config::Read/2.0 {infile keys} {
    # The system already checked that this is a TclDevKit Project File, Format 2.0.
    # Now we ask the main widget for the valid keys and use this to initialize
    # the safe interpreter evaluating the configuration.

    # Setup an interpreter for the evaluation of the configuration
    # script. Make it safe against intrusions.

    set ip [CleanIP]
    foreach key $keys {
	#            Slave [$key x] ==> Master [GetKey $key x]
	interp alias $ip $key           {} ::tcldevkit::config::GetKey $key
    }
    interp alias $ip format  {} ::tcldevkit::config::Null
    interp alias $ip fmtver  {} ::tcldevkit::config::Null
    interp alias $ip fmttool {} ::tcldevkit::config::Null
    interp alias $ip unknown {} ::tcldevkit::config::Illegal

    # Initialize the reader state, then read and evaluate the
    # configuration script.

    variable readerr {}
    variable readcfg

    catch {unset readcfg}
    array set    readcfg {}

    $ip eval [read [set fh [open $infile r]]][close $fh]
    interp delete $ip

    # Now check the result and return it, or throw an error.

    if {$readerr != {}} {
	return -code error [join $readerr ", "]
    }

    return [array get readcfg]
}

proc ::tcldevkit::config::ReadOrdered/2.0 {infile keys} {
    # The system already checked that this is a TclDevKit Project File, Format 2.0.
    # Now we ask the main widget for the valid keys and use this to initialize
    # the safe interpreter evaluating the configuration.

    # Setup an interpreter for the evaluation of the configuration
    # script. Make it safe against intrusions.

    set ip [CleanIP]
    foreach key $keys {
	#            Slave [$key x] ==> Master [GetKeyOrder $key x]
	interp alias $ip $key           {} ::tcldevkit::config::GetKeyOrder $key
    }
    interp alias $ip format  {} ::tcldevkit::config::Null
    interp alias $ip fmtver  {} ::tcldevkit::config::Null
    interp alias $ip fmttool {} ::tcldevkit::config::Null
    interp alias $ip unknown {} ::tcldevkit::config::Illegal

    # Initialize the reader state, then read and evaluate the
    # configuration script.

    variable readerr {}
    variable readcfgo {}

    $ip eval [read [set fh [open $infile r]]][close $fh]
    interp delete $ip

    # Now check the result and return it, or throw an error.

    if {$readerr != {}} {
	return -code error [join $readerr ", "]
    }

    return $readcfgo
}

proc ::tcldevkit::config::CleanIP {} {
    set ip [interp create]
    foreach cmd [$ip eval {info commands}] {
	if {[string equal rename $cmd]} continue
	$ip eval [list rename $cmd {}]
    }
    $ip eval {rename rename {}}
    return $ip
}

# -----------------------------------------------------------------------------
# Helpers. The commands called by the sub-interpreter evaluating the
# configuration script.

proc ::tcldevkit::config::GetKey {key {value {}}} {
    variable readcfg
    lappend  readcfg($key) $value
    return
}

proc ::tcldevkit::config::GetKeyOrder {key {value {}}} {
    variable readcfgo
    lappend  readcfgo $key $value
    return
}

proc ::tcldevkit::config::Illegal {key args} {
    variable readerr
    lappend  readerr $key
    return
}

proc ::tcldevkit::config::Null {args} {return}

# -----------------------------------------------------------------------------

package provide tcldevkit::config 2.0
