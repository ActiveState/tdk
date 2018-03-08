# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}

package require vfs::mk4
package require fileutil

set mfs [lindex $argv 0]
if {$mfs == {}} {
    puts stderr "Usage: $argv0 mfsfile"
    exit 1
}

set mfs [file join [pwd] $mfs]
vfs::mk4::Mount     $mfs $mfs -readonly

# List contents, just the names

# Specialized code recursing through the directory tree.  Note that
# 'fileutil::find' does not work correctly.  I believe because it
# tries to use stat (i-nodes) to avoid recursive symlinks, and the
# metakit FS does not return good i-node information.

proc listdir {dir {listvar {}}} {
    if {$listvar != {}} {
	upvar 1 $listvar flist
    } else {
	set flist {}
    }
    foreach item [lsort [glob -nocomplain -directory $dir *]] {
	if {[file isdirectory $item]} {
	    listdir $item flist
	    continue
	}
	lappend flist $item
    }
    if {$listvar == {}} {
	return $flist
    }
    return
}

foreach fname [listdir $mfs] {
    puts [fileutil::stripN [fileutil::stripPwd $fname] 2]
}


vfs::unmount $mfs
exit 0
