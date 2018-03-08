# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package afs::sig 0.1
# Meta platform    tcl
# Meta summary     Digest generation for associative file storage
# Meta category    Database
# Meta description digest module for the associative, i.e., content-addressed, file storage.
# Meta subject     digest associative {file store} database signature repository
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
#
# Associative File Storage = AFS / Signature module
# ======================== = === / ================

# ### ### ### ######### ######### #########
## Requisites

package require md5 2

namespace eval ::afs::sig {}

# ### ### ### ######### ######### #########

proc ::afs::sig::gen {fname} {

    # Compute signature of file. Combination of content hash (md5) and size.
    # 1. File size - Result is binary data,  4 bytes  (32 bit).
    # 2. Md5 hash  - Result is binary data, 16 bytes (128 bit).
    #                                      =========
    # 3. Composition                        20 bytes concatenated.
    # 4. Encode    - Base32 code, every 5 bits are converted into a printable
    #                character in the range of 0..9, a..v. The 20*8 = 160 bit
    #                generate a printable string of 160/5 = 32 characters.
    #
    # (Ad 1) Big endian.
    # (Ad 3) Size (High variability) at the end.

    if 0 {
	# The whole operation in expanded form, for easier reading, and
	# insertion of debugging code should it be needed.

	set size [file size      $fname]
	set size [binary format I $size]      ;#  4 byte binary
	set hash [md5::md5 -file $fname]      ;# 16 byte binary

	binary scan $hash H* v ; puts H:$v\t[string length $hash]
	binary scan $size H* v ; puts S:$v\t[string length $size]

	set psig $size$hash           ;# 20 byte binary
	set sign [base32 $psig]       ;# 32 char string.
    }

    # Now all of the above in one nested command. i.e. all
    # intermediate results are kept on the bc stack, no temp
    # variables.

    return [base32 [md5::md5 -file $fname][binary format I [file size $fname]]]
}


proc ::afs::sig::genstr {text} {

    # Compute signature of text. Combination of content hash (md5) and size.
    # 1. Text size - Result is binary data,  4 bytes  (32 bit).
    # 2. Md5 hash  - Result is binary data, 16 bytes (128 bit).
    #                                      =========
    # 3. Composition                        20 bytes concatenated.
    # 4. Encode    - Base32 code, every 5 bits are converted into a printable
    #                character in the range of 0..9, a..v. The 20*8 = 160 bit
    #                generate a printable string of 160/5 = 32 characters.
    #
    # (Ad 1) Big endian.
    # (Ad 3) Size (High variability) at the end.

    if 0 {
	# The whole operation in expanded form, for easier reading, and
	# insertion of debugging code should it be needed.

	set size [string length   $text]
	set size [binary format I $size]      ;#  4 byte binary
	set hash [md5::md5 --     $text]      ;# 16 byte binary

	binary scan $hash H* v ; puts H:$v\t[string length $hash]
	binary scan $size H* v ; puts S:$v\t[string length $size]

	set psig $size$hash           ;# 20 byte binary
	set sign [base32 $psig]       ;# 32 char string.
    }

    # Now all of the above in one nested command. i.e. all
    # intermediate results are kept on the bc stack, no temp
    # variables.

    return [base32 [md5::md5 -- $text][binary format I [string length $text]]]
}


proc ::afs::sig::base32 {sig} {
    # Tcl level bit manipulation, mapping groups of 5 bits into
    # printable characters, a base32 code. This may be speed up using
    # a critcl-based implementation.

    binary scan $sig B* bits
    set bits [string map {
	00000 0	00001 1	00010 2	00011 3	00100 4	00101 5	00110 6	00111 7
	01000 8	01001 9	01010 a	01011 b	01100 c	01101 d	01110 e	01111 f
	10000 g	10001 h	10010 i	10011 j	10100 k	10101 l	10110 m	10111 n
	11000 o	11001 p	11010 q	11011 r	11100 s	11101 t	11110 u	11111 v
    } $bits] ; # {}
    return $bits
}

proc ::afs::sig::path {sig} {
    # The signature is 32 base32 characters. The last seven mostly encode
    # the file size (32 bit = 6 * 5 bit + 2 bit).

    # We place each file in a directory named xx, where xx are the
    # first two characters of the signature. As base32 characters each
    # of the two characters has a variance of 5 bit = 32. Making for a
    # possible total of 1024 toplevel directories.

    return [file join [string range $sig 0 1] $sig]
}

# ### ### ### ######### ######### #########
## Ready
return
