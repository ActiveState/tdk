# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package obman 1.0
# Meta platform    tcl
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# ### ######### ###########################

# Tools. Observer management. This class encapsulates the management
# of observers (registration, removal and invocation. Any class
# wishing to handle observers of its changes should have an instance
# of this class as component, together with appropriate delegations.

#    delegate method change             to obman
#    delegate method onChangeCall       to obman
#    delegate method removeOnChangeCall to obman

# ### ######### ###########################
## Prerequisites

package require snit; # Object-system.

# ### ######### ###########################
## Implementation
#
## API expected from 'observer' objects.
##
## change object
##	The object has changed and is now notifying the observer.
#
# ### ######### ###########################

snit::type obman {
    # ### ######### ###########################

    option -partof {}

    # ### ######### ###########################
    ## Public API. (De)Construction.

    constructor {args} {
	array set observer {}
	$self configurelist $args
	if {$options(-partof) == {}} {
	    set options(-partof) $self
	}
	return
    }

    # ### ######### ###########################
    ## Public API. Change propagation

    method change {o} {
	# Standard behaviour when a notification comes in is to
	# forward the information to our observer.

	$self trigger
	return
    }

    method trigger {} {
	# This method is called by the object containing the obman
	# instance when its contents were changed. We notify all
	# registered observers.

	#puts "obman/$self/trigger"
	#puts /===
	#parray observer
	#puts \\===

	foreach o [array names observer] {
	    #puts "obman/$self/trigger/$o"
	    $o change $options(-partof)
	}
	return
    }

    method onChangeCall {object} {
	# Register <object> to be called on changes.
	if {$object eq $self} return
	if {[info exists observer($object)]} return
	#puts obman/$self/ad/$object
	set observer($object) .
	return
    }

    method removeOnChangeCall {object} {
	# Remove <object> from the list of objects to be called on
	# changes.
	if {$object eq $self} return
	if {![info exists observer($object)]} return
	#puts obman/$self/rm/$object
	unset observer($object)
	return
    }

    # ### ######### ###########################
    ## Internal. Internal data structures.

    variable observer ; # Hash of all observers.

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use
return
