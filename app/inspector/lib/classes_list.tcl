# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: classes_list.tcl,v Exp $
#

namespace eval class {}
proc class::init {w args} {
    eval [list inspect_box $w \
	      -updatecmd class::update \
	      -retrievecmd class::retrieve \
	      -filtercmd {}] $args
    return $w
}

proc class::update {path target} {
    set cmd [list if {[info command ::itcl::find]!=""} {::itcl::find classes *}]
    set classes [send $target $cmd]
    return [lsort -dictionary $classes]
}
proc class::retrieve {path target class} {
    return [class::retrieve_itcl $path $target $class]
}

proc class::retrieve_itcl {path target class} {
    set res "itcl::class $class {\n"

    set cmd [list ::namespace eval $class {info inherit}]
    set inh [send $target $cmd]
    if {$inh != ""} {
	append res "    inherit $inh\n\n"
    } else {
	append res "\n"
    }

    set cmd [list ::namespace eval $class {info variable}]
    set vars [send $target $cmd]
    foreach var $vars {
	set name [namespace tail $var]
	set cmd [list ::namespace eval $class \
		     [list info variable $name -protection -type -name -init]]
	set text [send $target $cmd]
	append res "    $text\n"
    }
    append res "\n"

    set funcs [send $target [list ::namespace eval $class {info function}]]
    foreach func [lsort $funcs] {
	set qualclass "::[string trimleft $class :]"
	if {[string first $qualclass $func] == 0} {
	    set name [namespace tail $func]
	    set cmd [list ::namespace eval $class [list info function $name]]
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
