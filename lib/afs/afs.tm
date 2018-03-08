# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package afs 0.1
# Meta platform    tcl
# Meta summary     Associative file storage
# Meta category    Database
# Meta description Associative, i.e., content-addressed, file storage.
# Meta subject     digest associative {file store} database repository
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type for associative file storage, i.e. storage of files based
# on a "cryptographically strong hash" of their contents.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require afs::sig
package require fileutil

# ### ### ### ######### ######### #########
## Implementation

snit::type ::afs {
    # ### ### ### ######### ######### #########
    ## API

    #method put           {path {newvar {}}} {}
    #method putstr        {text {newvar {}}} {}

    #method get           {sig}         {}
    #method remove        {sig}         {}
    #method copy          {sig dstpath} {}
    #method {Info exists} {sig}         {}
    #method {Info files}  {}            {}

    # ### ### ### ######### ######### #########
    ## Validation.

    method valid {mode mv} {
	upvar 1 $mv message
	return [$type valid $base $mode message]
    }

    typemethod valid {path mode mv} {
	upvar 1 $mv message

	if {$mode eq "rw"} {
	    return [fileutil::test $path edrw message "AFS"]
	} elseif {$mode eq "ro"} {	     			   
	    return [fileutil::test $path edr  message "AFS"]
	} else {
	    return -code error "Bad mode \"$mode\""
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## API Implementation.

    # Base directory used to store files placed into the storage.

    variable base

    method putstr {text {newvar {}}} {
	if {$newvar ne ""} {upvar 1 $newvar new}

	set sig   [sig::genstr $text]
	set store [file join $base [sig::path $sig]]

	if {[file exists $store]} {
	    set new 0
	    return $sig
	}

	file mkdir [file dirname $store]

	set ch [open $store w]
	puts -nonewline $ch $text
	close $ch

	set new 1
	return $sig
    }

    method put {path {newvar {}}} {
	if {$newvar ne ""} {upvar 1 $newvar new}

	set sig   [sig::gen $path]
	set store [file join $base [sig::path $sig]]

	if {[file exists $store]} {
	    set new 0
	    return $sig
	}

	file mkdir [file dirname $store]

        # The regular behaviour of Tcl for symlinks is to copy the
        # link, and not the contents of the file it is refering to.
	# Relative links would be broken immediately by this, and
	# keeping absolute links would couple the store contents to
	# the state of the environment. Neither is acceptable.
	# Therefore we resolve all symbolic links, including one in
	# the last element of the path. This ensures that the "file
	# copy" afterward copies an actual file.

        while {[file type $path] eq "link"} {
            set path [file normalize $path]
            set path [file join [file dirname $path] [file readlink $path]]
        }

	file copy $path $store
	set new 1
	return $sig
    }

    method get {sig} {
	set store [file join $base [sig::path $sig]]
	if {![file exists $store]} {
	    return -code error "Unknown file signature requested"
	}

	return [open $store r]
    }

    method path {sig} {
	set store [file join $base [sig::path $sig]]
	if {![file exists $store]} {
	    return -code error "Unknown file signature requested"
	}

	return $store
    }

    method remove {sig} {
	set store [file join $base [sig::path $sig]]
	if {![file exists $store]} {
	    return -code error "Unknown file signature requested"
	}
	file delete $store

	# Remove the directory as well, conserve a bit of space.
	set dir [file dirname $store]
	if {![llength [glob -directory $dir -nocomplain *]]} {
	    file delete $dir
	}
	return
    }

    method copy {sig dstpath} {
	set store [file join $base [sig::path $sig]]

	if {![file exists $store]} {
	    return -code error "Unknown file signature requested"
	}

	file copy -force $store $dstpath
	return
    }

    method {Info exists} {sig} {
	file exists [file join $base [sig::path $sig]]
    }

    method {Info files} {} {
	set res {}
	foreach p [glob -directory $base -tails */*] {
	    lappend res [lindex [file split $p] end]
	}
	return $res
    }

    # ### ### ### ######### ######### #########
    ##

    constructor {thebase} {
	if {[file exists $thebase]} {
	    if {![$type valid $thebase ro msg]} {
		return -code error "Not a valid AFS: $msg"
	    }
	} else {
	    file mkdir $thebase
	}

	set base $thebase
	return
    }
}

# ### ### ### ######### ######### #########
## Ready
return
