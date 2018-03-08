# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# controller - /snit::type
#
# talks to a LIST display for a metaki view and has a basic data view.
# whenever a sort call out happens, or a change of the filter
# definitions it creates the appropriate filtered and sorted view and
# reconfigures the display ...

# Note: This code assumes that the only things done on the basic view
# are
# a) row filtering    - metakit
# b) sorting          - metakit
# c) column filtering - here
#
# The controller does them in the order from top to bottom
# The transforms (a) and (c) are specified externally. (b)
# is done in reaction to callbacks from the display, for the
# columns shown in the table ...


snit::type ::listctrl {

    # Table to display the data, and the data source ...
    # show is the list of visible properties.
    # empty => Show all.

    option -display  {}
    option -data     {}
    option -show     {}
    option -onaction {}
    option -onbrowse {}

    # Generated view based on -data (select, sorted, projected)
    variable displaydata {}
    variable sortspec    {}
    variable filtspec    {}

    onconfigure -onaction {value} {
	# Ignore changes which are not.
	if {[string equal $value $options(-onaction)]} {return}

	set options(-onaction) $value
	if {$options(-display) != {}} {
	    $self ActionForward
	}
	return
    }

    onconfigure -onbrowse {value} {
	# Ignore changes which are not.
	if {[string equal $value $options(-onbrowse)]} {return}

	set options(-onbrowse) $value
	if {$options(-display) != {}} {
	    $self BrowseForward
	}
	return
    }

    option      -key rowid
    onconfigure -key {value} {
	set     options(-key) $value
	if {$options(-display) != {}} {
	    $self KeyForward
	}
	return
    }


    onconfigure -data {value} {
	# Ignore changes which are not.
	if {[string equal $value $options(-data)]} {return}

	#puts LC//[$value properties]

	set options(-data) $value
	$self RequestRefresh
	return
    }

    onconfigure -display {value} {
	# Ignore changes which are not.
	if {[string equal $value $options(-display)]} {return}

	set options(-display) $value
	# Forward data source to display, and link ourselves
	# into its sorting mechanism
	if {$value != {}} {
	    $value configure \
		    -data $displaydata \
		    -onsort [mymethod HandleSort]
	    $self ActionForward
	    $self BrowseForward
	    $self KeyForward
	}
	return
    }

    onconfigure -show {value} {
	set options(-show) $value
	$self RequestRefresh
	return
    }

    method filter {patterns} {
	set filtspec $patterns
	$self RequestRefresh
	return
    }

    method HandleSort {args} {
	#puts H/SORT

	set sortspec $args
	$self RequestRefresh
	return
    }

    method HandleAction {rtype row} {
	# We are be called if and only if -onaction is not empty.
	# Forego the check.

	# Here we add the name of the view the action is for.

	## uplevel #0 [linsert $options(-onaction) end $options(-data) $row]
	## return sorted view, row# is correct for this, only it.

	uplevel #0 [linsert $options(-onaction) end $sorted $rtype $row]
	return
    }

    method ActionForward {} {
	if {$options(-onaction) == {}} {
	    set cmd {}
	} else {
	    set cmd [mymethod HandleAction]
	}
	$options(-display) configure -onaction $cmd
	return
    }

    method KeyForward {} {
	$options(-display) configure -key $options(-key)
	return
    }

    method HandleBrowse {rtype rowid} {
	# We are be called if and only if -onbrowse is not empty.
	# Forego the check.

	# We ignore browsing into the title row.
	if {$rowid < 0} {return}

	# Here we add the name of the view the browse is for.

	## uplevel #0 [linsert $options(-onbrowse) end $options(-data) $row]
	## return sorted view, row# is correct for this, only it.

	#$sorted dump

	uplevel #0 [linsert $options(-onbrowse) end $sorted $rtype $rowid]
	return
    }

    method BrowseForward {} {
	if {$options(-onbrowse) == {}} {
	    set cmd {}
	} else {
	    set cmd [mymethod HandleBrowse]
	}
	$options(-display) configure -onbrowse $cmd
	return
    }

    method DataToDisplay {} {
	# Forward to display, if there is any
	if {$options(-display) == {}} {return}
	$options(-display) configure -data $displaydata
	return
    }

    # Internal variables for internal views ...

    variable filtered
    variable sorted

    method RecreateDisplayData {} {
	if {$options(-data) == {}} {
	    # Easy with no input, display is empty too.
	    set displaydata {}
	    return
	}

	# Kill previous views
	set displaydata {}
	set sorted      {}
	set filtered    {}

	# a) row filtering    - metakit
	# b) sorting          - metakit
	# c) column filtering - here

	# Ad a - not yet.
	# Ad c - not yet.

	if {[llength $filtspec] == 0} {
	    #puts no/filter
	    set filtered $options(-data)
	} else {
	    #puts FILTER/$filtspec
	    set cmd [list $options(-data) select]

	    # Currently fixed to glob patterns.
	    set hastruepattern 0
	    foreach {col pattern} $filtspec {
		if {$pattern eq "*"} {continue}
		set hastruepattern 1
		lappend cmd -glob $col $pattern
	    }

	    if {$hastruepattern} {
		#puts "FILTERING/$cmd"
		[eval $cmd] as filtered

		#$filtered dump
	    } else {
		#puts "FILTERING/no - all * - all match"
		set filtered $options(-data)
	    }
	}

	# Bug workaround: do not try to sort if the view has less
	# than two rows. It makes no sense, so the shortcut is ok,
	# however when tried metaskit delivers a bogus sorted view
	# containing bogus properties. The projection when shears
	# these off and the 'mklist' bails out because it misses
	# the properties to display.

	if {([llength $sortspec] == 0) || ([$filtered size] < 2)} {
	    #puts no/sort
	    set sorted $filtered
	} else {
	    #puts SORT/$sortspec
	    set cmd [list $filtered select]
	    foreach {col order} $sortspec {
		switch -exact -- $order {
		    -increasing {lappend cmd -sort $col}
		    -decreasing {lappend cmd -rsort $col}
		    default     {error "Unknown sortorder \"$order\""}
		}
	    }
	    #puts "SORTING/$cmd"
	    [eval $cmd] as sorted
	}

	# Ad c) Handle filtering of columns = projection.

	if {[llength $options(-show)] == 0} {
	    #puts no/project
	    set displaydata $sorted
	} else {
	    #puts PROJECT/$options(-show)
	    set cmd [linsert $options(-show) 0 $sorted project $options(-key)]
	    #puts PROJECTION/$cmd
	    [eval $cmd] as displaydata
	}
	return
    }


    variable tick 0

    method RequestRefresh {} {
	if {$tick} {return}
	#puts Req/REFRESH

	set tick 1
	after idle [mymethod Refresh]
	return
    }
    method Refresh {} {
	#puts REFRESH

	# Unlock the system before processing.
	# The processing below can generate more
	# requests for refresh
	set tick 0

	$self RecreateDisplayData
	$self DataToDisplay

	#puts R/ok...
	return
    }
}


package provide listctrl 0.1

