# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################
## Code to open a file based on the type of its contents.
## Specific per platform.
##
## - Windows: Registroy and file associations.
## - Unix:    env(EDITOR) for now, more smarts later.
##
## FUTURE -- Use an extended tcllib/fileutil::type
#
# (C) 2003 ActiveState
# ### ######### ###########################

package require fileutil
namespace eval file {}

# ### ######### ###########################

namespace eval file {
    variable tfirst 1
    variable TYPE
    array set TYPE [list "" "File"]
}

proc file::Temporize {path} {
    # Paths in the native file system need no modification.

    if {[lindex [file system $path] 0] eq "native"} {return $path}

    # The file is virtual. Copy it to a temp location
    # for access by the external viewer

    if 1 {
	variable tfirst
	if {$tfirst} {
	    # First call. Look for older vfse files in the temp location
	    # and delete them, ifp ossible. (Undeleteable files belong to
	    # other users)

	    # DANGER - This way of performing cleanup is fragile when a
	    # user runs multiple instances of vsfe. They may delete files
	    # out under each other.

	    set dummy [fileutil::tempfile vsfe.]
	    foreach f [glob -nocomplain -dir [file dirname $dummy] vfse.*] {
		catch {file delete -- $f}
	    }
	    set tfirst 0
	}
    }

    set newpath [file nativename [fileutil::tempfile vsfe.[file tail $path].]]
    file copy -force -- $path $newpath
    return $newpath
}

global tcl_platform
if {$tcl_platform(platform) eq "windows"} {

    package require registry

    proc file::LocateApp {type} {
	global env
	# Code origin: Wiki page 557 - Chris Nelson
	# Look for the application under --> HKEY_CLASSES_ROOT, based on the file extension.

	set root HKEY_CLASSES_ROOT
	set key  $root\\$type

	# Get the application key for this type of file
	if {[catch {
	    #checker exclude nonPortcmd
	    set appKey [registry get $key ""]
	}]} {
	    return {}
	}

	#puts stderr ||||$key\t$appKey

	# Get the command for opening this type of files
	if {[catch {
	    #checker exclude nonPortcmd
	    set appCmd [registry get $root\\$appKey\\shell\\open\\command ""]
	}]} {
	    return {}
	}

	#puts stderr ||||$appCmd

	# Resolve all environment variables used in the path. This has
	# to be done iteratively until all are gone. Ensure full uppercase
	# for the comparison.

	set begin 0
	while {[regexp -start $begin -indices {%([^%]*)%} $appCmd -> match]} {
	    foreach {s e} $match break
	    set var [string toupper [string range $appCmd $s $e]]
	    if {[info exists env($var)]} {
		incr s -1
		incr e
		set appCmd [string replace $appCmd $s $e $env($var)]

		# We do _not_ advance the begin reference. The
		# replacement text may contain more variable
		# references to resolve.

	    } else {
		# Unresolvable variable, skip.
		set begin $e
	    }
	}

	return $appCmd
    }

    proc file::type {path} {
	if {[file isdirectory $path]} {
	    return "Folder"
	} else {
	    set root  HKEY_CLASSES_ROOT
	    set type  [file extension $path]
	    set ltype [string tolower $type]

	    if {[info exists TYPE($ltype)]} {
		return $TYPE($ltype)
	    }

	    # Get the application key for this type of file
	    #checker exclude nonPortcmd
	    if {(![catch {set appKey [registry get "$root\\$ltype" ""]}] ||
		 ![catch {set appKey [registry get "$root\\$type"  ""]}])
		&& ![catch {set appName [registry get "$root\\$appKey" ""]}]} {
		set TYPE($ltype) $appName
	    } else {
		set TYPE($ltype) "[string range [string toupper $type] 1 end] File"
	    }
	    return $TYPE($ltype)
	}
    }

    proc file::open {path} {
	if {![file isfile $path]} {
	    return -code error "file::open: unable to open directory \"$path\""
	}

	set appCmd [LocateApp [file extension $path]]
	if {$appCmd == {}} {
	    return -code error "file::open: unable to open file \"$path\", unknown type"
	}

	#puts stderr %%%|=--$appCmd

	## FUTURE: Use tcllib/fileutil::type for a second attempt at
	## guessing the file type and subsequent lookup of a viewer
	## application.

	set path [Temporize $path]

	# Substitute the filename into the command for %1, into a
	# multi-argument placeholder (%*), or simply append if no
	# exact parameter location is specified

	if {[string match *%1* $appCmd]} {
	    set appCmd [string map [list %1 $path] $appCmd]
	} elseif {[string match *%\** $appCmd]} {
	    set appCmd [string map [list %* "\"$path\""] $appCmd]
	} else {
	    append appCmd " \"$path\""
	}

	# Remove any remaining '%*' placeholder for multiple parameters.
	if {[string match *%\** $appCmd]} {
	    set appCmd [string map [list %* {}] $appCmd]
	}

	# Double up the backslashes for eval (below)
	regsub -all {\\} $appCmd  {\\\\} appCmd

	#puts stderr %%%%=--$appCmd

	# Invoke the command
	eval exec $appCmd &
	return
    }

} else {
    ## Unix. Spawn an editor, based on the EDITOR environment
    ## variable.

    proc file::LocateApp {type} {
	return {}
    }

    proc file::type {path} {
	if {[file isdirectory $path]} {
	    return "Folder"
	} else {
	    set type [string toupper [file extension $path]]
	    if {$type ne ""} {
		return "[string range $type 1 end] File"
	    } else {
		return "File"
	    }
	}
    }

    proc file::open {path} {
	global env

	if {[file isdirectory $path]} {
	    # Invoke the regular open mechanism in the fsb ... (HACK)
	    .fsb show [file split $path]
	    return
	}

	# FUTURE :: Plugin based system to determine viewer based
	#           on the type of file.

	if {[info exists env(EDITOR)]} {
	    set                 path [Temporize $path]
	    set fail [catch {exec  $env(EDITOR) $path &} msg]
	    if {!$fail} return
	    set msg "We tried to use the application \"$env(EDITOR)\" to view the contents of the file. It failed to start and we got the following message:\n\n$msg"
	} else {
	    set fail 1
	    set msg  {Unable to view the file, as no application for viewing is known. Cause for the latter: The environment variable EDITOR is not set.}
	}

	tk_messageBox -parent . -title "Error" \
		-message $msg \
		-icon error -type ok
	return
    }
}

# ### ######### ###########################
## Ready to go

package provide file::open 0.1
