# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# Filesystem data
# A rootview combined with a plain directory view.

# ### ######### ###########################
## Prerequisites

package require snit
package require rootview
package require dirview
package require dirtreeview
package require ftype

# ### ######### ###########################
## Implementation

snit::type fsv {
    # ### ######### ###########################

    option -closecmd {}
    option -show     {}
    option -data     {}

    # ### ######### ###########################

    constructor {args} {
	rootview ${selfns}::roots -icon diskdrive \
		-opencmd [mymethod OpenRoot]
	dirview  ${selfns}::details -separate 1 \
		-icon [ftype ${selfns}::ft]
	return
    }

    destructor {
	catch {${selfns}::roots   destroy}
	catch {${selfns}::details destroy}
	return
    }

    # ### ######### ###########################
    ## Public. Component retrieval

    method tree {} {
	return ${selfns}::roots
    }

    method details {} {
	return ${selfns}::details
    }

    # ### ######### ###########################
    ## Public.

    # ### ######### ###########################

    method OpenRoot {cmd path} {

	#puts stderr "OpenRoot ($cmd) ($path)"

	switch -exact -- $cmd {
	    create {
		return [dirtreeview %AUTO% -path $path]
	    }
	    glob {
		return [dirtreeview glob $path]
	    }
	}
	return -code error "Bad command \"$cmd\""
    }

    # ### ######### ###########################
}


# ### ######### ###########################
## Ready for use

package provide fsv 0.1
