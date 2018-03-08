# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: objects_list.tcl,v Exp $
#

namespace eval objects {}
proc objects::init {w args} {
    eval [list inspect_box $w \
	      -updatecmd objects::update \
	      -retrievecmd objects::retrieve \
	      -filtercmd {}] $args
    return $w
}

proc objects::update {path target} {
    set cmd [list if {[info command ::itcl::find]!=""} {::itcl::find objects *}]
    set objects [send $target $cmd]
    return [lsort -dictionary $objects]
}
proc objects::retrieve {path target object} {
    return [objects::retrieve_itcl $path $target $object]
}
proc objects::retrieve_itcl {path target object} {
    set class [send $target [list $object info class]]
    set res "$class $object {\n"

    set cmd [list $object info inherit]
    set inh [send $target $cmd]
    if {$inh != ""} {
	append res "    inherit $inh\n\n"
    } else {
	append res "\n"
    }

    set vars [send $target $object info variable]
    foreach var $vars {
	set name [namespace tail $var]
	set cmd [list $object info variable $name]
	set text [send $target $cmd]
	append res "    $text\n"
    }
    append res "\n"

    set funcs [send $target [list $object info function]]
    foreach func [lsort $funcs] {
	set qualclass "::[string trimleft $class :]"
	if {[string first $qualclass $func] == 0} {
	    set name [namespace tail $func]
	    set cmd [list $object info function $name]
	    set text [send $target $cmd]

	    if {![string match "@itcl-builtin*" [lindex $text 4]]} {
		switch -exact -- $name {
		    constructor {
			append res "    $name [lrange $text 3 end]\n"
		    }
		    destructor {
			append res "    $name [lrange $text 4 end]\n"
		    }
		    default {
			append res "    [lindex $text 0] [lindex $text 1] $name\
				 [lrange $text 3 end]\n"
		    }
		}
	    }
	}
    }

    append res "}\n"
    return $res
}
