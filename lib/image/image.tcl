# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################

# UI tools. Mini database for access to bitmaps used by the
# application. The bitmaps are loaded on demand, the resulting Tk
# images cached.

# ### ######### ###########################
## Prerequisites

package require Tk

# ### ######### ###########################
## Implementation / API

namespace eval ::image {}

# ### ######### ###########################
## Public API, Retrieve image.

proc ::image::get {name} {
    variable img
    if {![info exists img($name)]} {
	set img($name) [LocateImage $name]
    }
    return $img($name)
}

# ### ######### ###########################
## Public API, Register a plugin

proc ::image::plugin {cmdprefix} {
    variable plugin
    if {[lsearch -exact $plugin $cmdprefix] >= 0} {
	return -code error "[info level 0]: Plugin already present"
    }

    # New plugins are added at the front, so that they are searched
    # first.

    set plugin [linsert $plugin 0 $cmdprefix]
    return
}


# ### ######### ###########################
## Internals. Main locator command, entry to plugin system.

proc ::image::LocateImage {name} {
    variable plugin
    foreach p $plugin {

	#puts stderr Locate/$name/$p

	if {[catch {set i [eval [linsert $p end $name]]} msg]} {
	    puts stderr \t\t%%\t$msg
	    continue
	}
	if {$i != {}} {return $i}
    }
    return -code error "[info level 0]: unable to locate image \"$name\""
}

# ### ######### ###########################
## Data structures

namespace eval ::image {
    # Database of loaded images.
    variable img ;    array set img {}

    # Database of plugins to query when trying to locate an
    # image. Actually a list of command prefixes to evaluate with the
    # image name as argument. The first plugin returning an image
    # wins.

    variable plugin ; set plugin {}
}

# ### ######### ###########################
## Standard plugin: Directory based search.

namespace eval ::image::file {
    # - List of paths to search for a file containing the requested
    #   image. Standard path is the subdirectory 'images' in the
    #   directory containing this package.

    variable paths {}

    variable extensions {{} .gif .xpm .ppm}
    variable x
    foreach x {png bmp jpeg} {
	if {[package provide img::$x] != ""} {
	    lappend extensions .$x
	}
    }
    unset x
}

# ### ######### ###########################
## File plugin, public API: Add a specific path.

proc ::image::file::add {path} {
    variable paths

    if {[lsearch -exact $paths $path] >= 0} {
	return -code error "[info level 0]: Path already present"
    }
    lappend paths $path
    return
}

# ### ######### ###########################
## File plugin, public API: Add images path of caller (implicitly
## defined through its script location). We ignore errors from
## multiple declarations of the same path, if they occur.

proc ::image::file::here {} {
    catch {add [file join [file dirname [info script]] images]}
    return
}

# ### ######### ###########################
## File plugin, internal: Plugin locator handler

proc ::image::file::Get {name} {
    # Standard image types only, i.e. gif and xpm.
    variable paths
    variable extensions
    foreach p $paths {
	foreach e $extensions {
	    set f [file join $p $name$e]
	    if {[file exists $f] && [file isfile $f] && [file readable $f]
		&& ![catch {set im [image create photo -file $f]}]} {
		return $im
	    }
	}
    }
    # Nothing was found
    return {}
}

# ### ######### ###########################
## Initialization: Standard plugin, and standard path

::image::plugin ::image::file::Get
::image::file::add [file join [file dirname [info script]] images]

# ### ######### ###########################
## Ready for use

package provide image 0.3
