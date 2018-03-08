# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# exe.tcl --
#
# Win32 exe header reading code
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
#

package require Tcl 8.4

# Instantiate vars we need for this package
namespace eval ::exe {
}

proc ::exe::getdword {fh} {
    binary scan [read $fh 4] i* tmp
    return $tmp
}

proc ::exe::getword {fh} {
    binary scan [read $fh 2] s* tmp
    return $tmp
}

proc ::exe::checkEXE {exe {mode r}} {
    set fh [open $exe $mode]
    fconfigure $fh -translation binary

    # verify PE header
    if {[read $fh 2] != "MZ"} {
	close $fh
	return -code error "not a DOS executable"
    }
    seek $fh 60 start
    seek $fh [getword $fh] start
    set sig [read $fh 4]
    if {$sig eq "PE\000\000"} {
	# move past header data
	seek $fh 24 current
	seek $fh [getdword $fh] start
    } elseif {[string match "NE*" $sig]} {
	seek $fh 34 current
	seek $fh [getdword $fh] start
    } else {
	close $fh
	return -code error "executable header not found"
    }

    # return file handle
    return $fh
}

proc ::exe::getStringFileInfo {file} {
    set file [file normalize $file]
    set fh   [checkEXE $file]

    fconfigure $fh -translation lf -encoding unicode -eofchar {}
    set readsize 8192 ; # chunked read size

    set lastdata ""
    while {1} {
	# make sure to account for the edge case
	set nextdata [read $fh $readsize]

	set data $lastdata$nextdata
	if {[set s [string first "StringFileInfo\000" $data]] >= 0} {
	    break
	}
	# we shouldn't need to check empty nextdata, but a bug
	# in memchan/vfs causes eof to not always trigger at eof
	if {[eof $fh] || $nextdata eq ""} {
	    close $fh
	    return -code error "StringFileInfo not found"
	}
	set lastdata [string range $nextdata end-20 end]
    }
    incr s -3
    set data [string range $data $s end][read $fh 12]

    if {![regexp {(.)\000(.)StringFileInfo\000(.)\000(.)(....)(....)\000} \
	      $data -> len type len2 type2 lang code]} {
	close $fh
        return -code error "StringFileInfo corrupt"
    }

    set len  [expr {[scan $len %c] / 2}]
    set len2 [expr {[scan $len2 %c] / 2}]

    if {[string length $data] < $len} {
	append data [read $fh [expr {$len - [string length $data]}]]
    } else {
	set data [string range $data 0 $len]
    }

    close $fh

    set s 30
    set result [list Language $lang CodePage $code]
    while {$s < $len2} {
        scan [string range $data $s end] %c%c%c slen vlen type
        if {$slen == 0} return
        set slen [expr {$slen / 2}]
        set name [string range $data [expr {$s + 3}] \
		      [expr {$s + $slen - $vlen - 1}]]
        set value [string range $data [expr {$s + $slen - $vlen}] \
		       [expr {$s + $slen - 2}]]
        set s [expr {$s + $slen + ($slen % 2)}]
        lappend result [string trimright $name \000] $value
    }
    return $result
}

proc ::exe::getFixedInfo {file} {
    set file [file normalize $file]
    set fh   [checkEXE $file]

    fconfigure $fh -translation lf -encoding unicode -eofchar {}
    set data [read $fh]
    set s [string first "VS_VERSION_INFO" $data]
    if {$s < 0} {
	close $fh
	return -code error "no version information found"
    }
    unset data
    fconfigure $fh -encoding binary
    seek $fh [expr {($s * 2) - 6}] start
    seek $fh [expr {[tell $fh] % 4}] current
    binary scan [read $fh 6] sss len vlen type
    seek $fh 34 current
    if {[getdword $fh] != 4277077181} {
	close $fh
	return -code error "version information corrupt"
    }
    set result [list]

    seek $fh 4 current
    binary scan [read $fh 8] ssss b a d c
    lappend result FileVer	$a.$b.$c.$d
    binary scan [read $fh 8] ssss b a d c
    lappend result ProductVer	$a.$b.$c.$d
    seek $fh 4 current
    #binary scan [read $fh 4] B32 flagmask
    lappend result Flags	[getdword $fh]
    lappend result OS		[getdword $fh]
    lappend result FileType	[getdword $fh]
    lappend result FileSubType	[getdword $fh]
    binary scan [read $fh 8] w date
    lappend result Date		$date

    close $fh
    return $result
}

# Ready to use
package provide exe 0.1
