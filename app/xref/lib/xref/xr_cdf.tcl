# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xrefchilddeffile - /snit::type
#
# Loads the database, is given view description objects.
# Runs the db extending methods for the view descriptions.
#

package require snit
package require mkdb
package require image  ; image::file::here

snit::type ::xrefchilddeffile {

    constructor {db_} {
	set db $db_
    }

    variable db

    method view {ctype} {
	switch -exact $ctype {
	    F {return [$db view file_contents]}
	    N {return [$db view namespace_contents]}
	    C {return [$db view cmd_contents]}
	    V {return {}}
	    P {return {}}
	}
	return -code error "$self view: Illegal type \"$ctype\""
    }

    method mayhavechildren {ctype} {
	switch -exact $ctype {
	    F {return 1}
	    N {return 1}
	    C {return 1}
	    V {return 0}
	    P {return 0}
	}
	return -code error "$self mayhavechildren: Illegal type \"$ctype\""
    }

    method text {ctype level string} {
	switch -exact $ctype {
	    F {return $string}
	    N {return $string}
	    C {
		if {$level == 1} {
		    return [string range $string 2 end]
		} else {
		    return [namespace tail $string]
		}
	    }
	    V {
		if {$level == 1} {
		    return [string range $string 2 end]
		} else {
		    return $string
		}
	    }
	    P {return $string}
	}
	return -code error "$self text: Illegal type \"$ctype\""
    }

    method image {ctype} {
	switch -exact $ctype {
	    F {set name file}
	    N {set name nspace}
	    C {set name cmd}
	    V {set name var}
	    P {set name pkg}
	    default {
		return -code error "$self image: Illegal type \"$ctype\""
	    }
	}
	return [image::get $name]
    }
}

package provide xrefchilddeffile 0.1
