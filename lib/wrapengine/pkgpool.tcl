# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgpool.tcl --
# -*- tcl -*-
#
#	Pool of package instances
#	+ the archive files containing them
#
# Copyright (c) 2006 ActiveState Software Inc.
#
# RCS: @(#) $Id: tdkwrap.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

# ### ### ### ######### ######### #########
## Requirements

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type tclapp::pkg::pool {

    # ### ### ### ######### ######### #########
    ## API

    method enter {instance path} {
	set db($instance) $path
	return
    }

    method instances {} {
	return [array names db]
    }

    method get {instance} {
	return $db($instance)
    }

    method clear {} {
	array unset db *
	return
    }

    # ### ### ### ######### ######### #########
    ## Data structures

    # array (instance -> path)

    variable db -array {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide tclapp::pkg::pool 1.0




