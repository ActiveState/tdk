# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: procs_list.tcl,v Exp $
#

namespace eval procs {}
proc procs::init {w args} {
    eval [list inspect_box $w \
	      -separator :: \
	      -updatecmd procs::update \
	      -retrievecmd procs::retrieve \
	      -filtercmd {}] $args
    return $w
}

proc procs::update {path target} {
    return [lsort -dictionary [names::procs $target]]
}
proc procs::retrieve {path target proc} {
    return [::names::prototype $target $proc 1]; # verbose
}
