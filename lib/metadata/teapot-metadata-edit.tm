# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::metadata::edit 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     teapot::metadata::container
# Meta require     teapot::metadata::read
# Meta require     teapot::metadata::write
# Meta require     teapot::package::gen::zip
# Meta require     vfs
# Meta require     vfs::mk4
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# Editing the meta data of a teabag in place.  I.e. read it out of the
# file, apply the desired changes, then recreate the file using the
# new metadata. As our inputs are teabags we assert that we expect to
# find only one entity definition.

# ### ### ### ######### ######### #########
## Requirements

package require logger                      ; # Tracing
package require teapot::metadata::container ; # Container for read meta data
package require teapot::metadata::read      ; # Container for read meta data
package require teapot::metadata::write     ; # Container for read meta data
package require teapot::package::gen::zip   ; # Repackaging zip archives.
package require fileutil                    ; # Directory traversal & file manipulation.
package require vfs
package require vfs::mk4


logger::initNamespace ::teapot::metadata::edit
namespace eval        ::teapot::metadata::edit {}

# ### ### ### ######### ######### #########
## API.

proc ::teapot::metadata::edit::archive {path changes ev} {
    upvar 1 $ev errors

    set p [lindex [::teapot::metadata::read::file $path single errors artype] 0]
    if {[llength $errors]} return

    Apply $p $changes errors
    if {[llength $errors]} return

    Recreate $path $artype $p

    $p destroy
    return
}

proc ::teapot::metadata::edit::Apply {p changes ev} {
    upvar 1 $ev errors

    while {[llength $changes]} {
	set cmd     [lindex $changes 0]
	set changes [lrange $changes 1 end]
	switch -exact -- $cmd {
	    unset -
	    !     -
	    -     {$p unset [Get 1]}
	    clear -
	    c     {$p clear [Get 1]}
	    add   -
	    +     {
		foreach {k v} [Get 2] break
		$p add $k $v
	    }
	    set    -
	    =      {
		foreach {k v} [Get 2] break
		$p unset $k
		$p add   $k $v
	    }
	    name: {
		$p rename [Get 1]
	    }
	    version: {
		$p reversion [Get 1]
	    }
	    type: {
		$p retype [Get 1]
	    }
	    default {
		lappend errors "Unknown change \"$cmd\""
		return
	    }
	}
    }
}

proc ::teapot::metadata::edit::Get {n} {
    upvar 1 changes changes errors errors cmd cmd
    if {[llength $changes] < $n} {
	lappend errors "Not enough arguments for \"$cmd\", expected $n"
	return -code return
    }

    set n1 [expr {$n - 1}]
    set a       [lrange $changes 0 $n1]
    set changes [lrange $changes $n end]
    return $a
}

proc ::teapot::metadata::edit::Recreate {path artype p} {
    variable eofcz

    switch -exact -- $artype {
	tm-header {
	    # This is an easy case. Locate the MD in the file header,
	    # then do a replace-in-place. Well, not quite that easy.

	    # There may be binary data after a ^Z, which we must not
	    # modify. Just using binary translation is no good either,
	    # because then the offsets are wrong, as they were
	    # computed from auto translation. If we compute the
	    # offsets from binary as well, then our output can have
	    # mixed EOL termination (\n from the generated code, and
	    # \r\n from the surrounding tcl code.

	    # Our solution: Split on ^Z, handle the header in auto
	    # translation, and any thing behind is copied binary.
	    # This may convert the header part from DOS to unix line
	    # termination, but will neither touch anything which could
	    # be binary, nor generate mixed-type eol.

	    foreach {at n} [teapot::metadata::read::locationTM $path] break

	    set t [fileutil::tempfile]
	    set o [open $t    w]          ; # cat + writeFile of header
	    set i [open $path r]         
	    fconfigure $i -eofchar $eofcz
	    fcopy $i $o
	    close $o
	    close $i

	    # Note: The string range chops off the trailing the eol
	    # returned by getStringEmbeddedC, which is necessary
	    # because our replacement is in between two EOLs, without
	    # an EOL at the end. Leaving the EOL would add an empty
	    # line to the result.
	    fileutil::replaceInFile $t $at $n \
		[string range \
		     [teapot::metadata::write::getStringEmbeddedC $p] \
		     0 end-1]

	    # Now go to the binary data, if any, and copy.
	    #
	    # Note: In principle we have a ref to the binary data
	    # already, after the first fcopy. Somhow this is not
	    # resetting the eof or location in the file properly and
	    # we get nothing after -eof {}. It was necessary to close
	    # and then use the method below (open, -eof ^Z, read for
	    # skip to eof, -eof {}, copy the remainder, including ^Z).

	    set o [open $t    a] ; fconfigure $o -translation binary
	    set i [open $path r] ; fconfigure $i -eofchar $eofcz
	    read $i ; # skip header.
	    fconfigure $i -eofchar {} -translation binary
	    #read  $i 1
	    #puts -nonewline $o $ctrlz
	    fcopy $i $o
	    close $o
	    close $i

	    file rename -force $t $path
	}
	tm-mkvfs {
	    # Easy. Mount the file, overwrite teapot.txt, unmount.

	    vfs::mk4::Mount $path $path

	    fileutil::writeFile \
		[file join $path teapot.txt] \
                [teapot::metadata::write::getStringExternalC $p]

	    vfs::unmount $path
	}
	zip {
	    # Bleh. Decode zipfile, re-encode, with a different
	    # teapot.txt. Actually easy, even if not truly efficient,
	    # with decompress/compress cycle through the
	    # filesystem. The point is, we can use the
	    # pkggen::zip::repack functionality.

	    set          temp [fileutil::tempfile]
	    file delete $temp
	    file mkdir  $temp

	    zipfile::decode::unzipfile           $path $temp
	    file delete [file join $temp teapot.txt]
	    teapot::package::gen::zip::repack $p $temp $path
	    file delete -force $temp
	}
	default {error "Bad artype \"$artype\""}
    }
    return
}

# ### ### ### ######### ######### #########
## Extraction core. Lift the raw meta data
## out of a package archive file. The result
## is always in external format.

# ### ### ### ######### ######### #########
## Ready

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::teapot::metadata::edit {
    variable ctrlz \x1A
    variable eofcz [list $ctrlz $ctrlz]
}

#teapot::metadata::read::log::debug "Package loaded"
return
