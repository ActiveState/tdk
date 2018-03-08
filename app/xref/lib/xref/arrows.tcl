# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# Embedded images ... Up/down Arrows.

package require Tk

namespace eval ::arrow {
    variable up        {}
    variable down      {}

    variable upimage   {}
    variable downimage {}
}

set ::arrow::up {
R0lGODlhEAAMAPAAAAAAAL29vSH5BAEAAAEALAAAAAAQAAwAAAJtTJgwYcKECRMmTJgwYcKE
CRMmTJgwYcCECRMmTJgwYcCECRMmTJgwIUCECRMmTJgwIUCECRMmTJgwIECACRMmTJgwIECA
CRMmTJgQIECACBMmTJgQIECACBMmTJgwYcKECRMmTJgwYcKECRMmBQA7
}

set ::arrow::down {
R0lGODlhEAAMAPAAAAAAAL29vSH5BAEAAAEALAAAAAAQAAwAAAJtTJgwYcKECRMmTJgwYcKE
CRMmTJgQIECACBMmTJgQIECACBMmTJgwIECACRMmTJgwIECACRMmTJgwIUCECRMmTJgwIUCE
CRMmTJgwYcCECRMmTJgwYcCECRMmTJgwYcKECRMmTJgwYcKECRMmBQA7
}


proc ::arrow::up {} {
    variable upimage
    variable up
    if {$upimage == {}} {
	set upimage [image create photo -data $up]
    }
    return $upimage
}

proc ::arrow::down {} {
    variable downimage
    variable down
    if {$downimage == {}} {
	set downimage [image create photo -data $down]
    }
    return $downimage
}


package provide arrow 0.1
