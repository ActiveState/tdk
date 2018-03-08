# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################

# UI tools. Plugin for the image database, handling tinted images.
# Requires the package 'tktreectrl', it provides the relevant
# operations.

# ### ######### ###########################
## Prerequisites

package require Tk
package require image      ; # Base package is needed.
package require treectrl   ; # Tinting operations.
package require syscolor   ; # System color definitions

# ### ######### ###########################
## Implementation / API

namespace eval ::image::tint {}

# ### ######### ###########################
## Public API, define a tinted image in terms of a different image.

proc image::tint::define {name origname} {
    variable tints
    #puts stderr **\tdefine/tint|$name|$origname
    set      tints($name) $origname
    return
}

proc image::tint::undef {name} {
    variable tints
    #puts stderr **\tundef/tint|$name
    if {![info exists tints($name)]} return
    unset tints($name)
    variable tintimg
    if {![info exists tintimg($name)]} return
    image delete $tintimg($name)
    unset tintimg($name)
    return
}

proc image::tint::defined {name} {
    variable tints
    #puts stderr **\tdefined/tint|$name
    return [info exists tints($name)]
}

proc image::tint::hasimage {name} {
    #puts stderr **\thasimg/tint|$name
    if {![defined $name]} {return 0}
    variable tintimg
    return [info exists tintimg($name)]
}

proc image::tint::get {name} {Get $name}

# ### ######### ###########################
## Internal: Plugin locator handler

proc ::image::tint::Get {name} {
    variable tints
    variable tintimg

    #puts stderr GetTint/$name

    # Module doesn't know the name, signal caller to search elsewhere.
    if {![info exists tints($name)]} {return {}}

    # Return cache, no need for time-consuming processing.
    if {[info exists tintimg($name)]} {return $tintimg($name)}

    #puts stderr \tfound

    set orig [image::get $tints($name)]
    set new  [image create photo]
    $new copy $orig
    imagetint $new $::syscolor::highlight 128

    # Cache image for access later.
    set tintimg($name) $new

    #puts stderr \tok
    return $new
}

# ### ######### ###########################
## Data structures

namespace eval ::image::tint {
    # Map : icon name -> name of icon it derives from
    variable tints ;  array set tints {}

    # Map : icon name -> generated image (cache, to allow manipulation after the fact).
    variable tintimg ; array set tintimg {}
}

# ### ######### ###########################
## Initialization: Register this plugin

::image::plugin ::image::tint::Get

# ### ######### ###########################
## Ready for use

package provide image::tint 0.1
