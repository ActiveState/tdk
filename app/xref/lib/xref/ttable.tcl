# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# ttable - "tktable" / "mktable /snit::widgetadaptor
#           Defines specific appareance of titles,
#           justification, tags
#           Makes title row a button for sorting ...

##
## Appears to be unused
return
##

package require snit
package require arrow ;# Images for titles.


snit::widgetadaptor ::ttable::ttable {

    option -onsort   {}
    option -onaction {}
    option -onbrowse {}

    variable ncols 0
    variable sortorder
    variable sortlist {}
    variable arrow

    option      -titles {}
    onconfigure -titles {value} {
	# We intercept before delegation to insert spaces
	# before the actual titles, so that there is no
	# overlap with the arrow images we use as sort
	# indicator

	set res [list]
	foreach v $value {lappend res "    $v"}
	$hull configure -titles $res -bg white
	set options(-titles) $value
	return
    }

    constructor {basetype args} {
	array set sortorder {}
	set arrow(-increasing) [arrow::up]
	set arrow(-decreasing) [arrow::down]

	installhull [$basetype $win]

	# Standard settings ...

	$hull configure \
		-ncolcommand [mymethod NColChanged] \
		-browsecmd   [mymethod BrowseOut %r] \
		-selecttype     row  \
		-selectmode     single \
		-colstretchmode all  \
		-resizeborders  col \
		-invertselected 1 \
		-justify left     \
		-anchor w

	# Title row is sensitive and used to indicate sorting.

	bind $win <1> {
	    if {[%W index @%x,%y row] == 0} {
		%W SortOut [%W index @%x,%y col]
		break
	    }
	}

	# All other rows react to double click and execute
	# a callback

	bind $win <Double-1> {
	    if {[%W index @%x,%y row] > 0} {
		%W ActionOut [%W index @%x,%y row]
		break
	    }
	}

	# Create and apply standard tags ...
	# Columns tags are applied as we get information about
	# the present columns.

	$hull tag configure col_base \
		-state disabled -anchor e \
		-multiline 1
	$hull tag configure title \
		-fg black -bg lightgrey \
		-relief raised -bd 1
	$hull tag row       title 0

	$self configurelist $args
	return
    }

    method NColChanged {old new} {

	#puts  $self/NColChanged/$old/$new

	for {set i $old} {$i < $new} {incr i} {
	    set sortorder($i) -increasing

	    #puts  \tcol$i/$arrow(-increasing)

	    $hull tag configure col_base$i \
		    -state disabled
	    $hull tag configure col$i \
		    -anchor w \
		    -showtext 1 -image $arrow(-increasing)

	    # As we create these tags late we have to modify
	    # their priority explicitly to ensure that they
	    # are considered first.

	    $hull tag raise  col_base$i col_base
	    $hull tag raise  col$i      col_base$i

	    # Now apply the relevant tags.

	    $hull tag col  col_base $i

	    #puts  \tcell/col$i/0,$i

	    # Delayed application ... Defered until after
	    # after a possibly upcoming 'clear cache'.
	    # Seems to be required to ensure that the
	    # tags are applied well.

	    after 5 [list $hull tag col  col_base$i $i]
	    after 5 [list $hull tag cell col$i      0,$i]

            lappend sortlist $i
	}
	# Should call out to ensure correct sorting order.
	set ncols $new
	$self SortExecute
	return
    }

    method adjust {i just} {
	switch -exact -- $just {
	    right {$hull tag configure col_base$i -anchor e}
	    left  {$hull tag configure col_base$i -anchor w}
	    default {
		return -code error "Unknown adjustment \"$just\""
	    }
	}
	return
    }

    method ActionOut {rowidx} {
	# Execute a callback for the double-clicked row.
	if {$options(-onaction) == {}} {return}

	# We must not count the title row when going from
	# table to view index.

	incr rowidx -1
	uplevel #0 [linsert $options(-onaction) end $rowidx]
	return
    }

    method BrowseOut {rowidx} {
	# Execute a callback for the selected row.
	if {$options(-onbrowse) == {}} {return}

	# We must not count the title row when going from
	# table to view index.

	incr rowidx -1
	uplevel #0 [linsert $options(-onbrowse) end $rowidx]
	return
    }


    method SortOut {colidx} {
	# Sorting for column 'colidx' has to change.
	# Update internal data structures, then call
	# through the callback and ask the environment
	# for help.

	#puts $self/sort-change/$colidx

	set sortorder($colidx) [set neworder [$self OrderInvert $sortorder($colidx)]]
	$hull tag configure col$colidx -image $arrow($neworder)

	# Move the changed column to the front of the sort list.

	set p [lsearch -exact $sortlist $colidx]
	set sortlist [linsert [lreplace $sortlist $p $p] 0 $colidx]

	$self SortExecute
    }

    method OrderInvert {order} {
	switch -exact -- $order {
	    -increasing {return -decreasing}
	    -decreasing {return -increasing}
	}
	return -code error "Invalid order \"$order\""
    }

    method SortExecute {} {
	if {$options(-onsort) == {}} {return}

	set cmd $options(-onsort)

	set clist [$hull cget -columns]
	foreach i $sortlist {
	    set c [lindex $clist $i]
	    lappend cmd $c $sortorder($i)
	}

	#puts "Sorting via \[$cmd\]"

	uplevel #0 $cmd
	return
    }


    # Delegate the remainder to the base widget ...

    delegate method * to hull
    delegate option * to hull
}


package provide ttable 0.1
