# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################

# UI tools. Widget. See 'vlabel' and 'clabel 'for related
# widgets. This one is a table connected to a view (see generic ->
# 'view' class and relations). It shows the contents of the view, with
# the user configuring which view to display, what attributes to show,
# order of attributes, and titles.

# (A precursor widget adapted automatically to the view shown, but
# this is cumber some when trying to display only parts of a view, it
# necessitates an additional projection on top of the view we actually
# wish to display)

# A future enhancement I am thinking about, but are currently not
# quite sure how to implement is to use the data in the shown view to
# drive visual attributes of the table beyond the text
# shown. Examples:
#
# - Change color of a column, row, or cell based on the shown data.
# - Do not show text, but images, or windows in a cell, based on the
#   data.
#
# The change of color and similar attributes could be handled via
# tags, and a mechanism to retrieve a tag from the shown view in some
# way. Display of images and the like requires more work.

# -- Orientation: Horizontal or vertical display
# -- Vertical is default.
# -- Titles on/off

# ### ######### ###########################

# ### ######### ###########################
## Prerequisites

package require Tktable ; # The foundation for our display.
package require snit    ; # Object system
package require req     ; # Refresh handling

# ### ######### ###########################
## Implementation

snit::widgetadaptor vtable {
    # ### ######### ###########################

    delegate method * to hull
    delegate option * to hull except {-command -cache -usecommand -titlerows -titlecols}

    option -view {} ; # Reference to the view displayed by the widget.
    # ............... # The widget does _not_ own this view.

    option -attributes {} ; # List of attributes the view has to
    # ..................... # have. The contents of these attributes
    # ..................... # are displayed by the widget.
    # In the order given, from left to right.

    # Special column. If specified (non-empty) it is used to retrieve
    # row tags for colorization. The attribute can be among
    # -attributes, but usually is not. Recommended is not.

    option -tagattr {}

    option -titles {} ; # List of titles to show. Matched to the
    # ................. # attributes shown through the order in the
    # ................. # list. Elements at the same position belong
    # ................. # together. If there are more titles than
    # ................. # attributes the excess elements are
    # ................. # ignored. If there are not enough elements
    # ................. # the attribute name will be used for the
    # ................. # titling.

    option -orientation vertical
    option -usetitles   1

    # ### ######### ###########################
    ## Public API. (De)Construction.

    constructor {args} {
	installhull using table -cache 1 -multiline 1

	req ${selfns}::tick [mymethod RefreshDisplay]

	$self configurelist $args		
	return
    }
    destructor {
	${selfns}::tick destroy
	return
    }

    # ### ######### ###########################
    ## Public API. 

    ## No new methods

    # ### ######### ###########################
    ## Internal. Data structures.

    variable crow ; # Cursor connected to the view given to the
    # ............. # widget. Contains the data of the current row,
    # ............. # used when retrieving the data to display from
    # ............. # the view.

    variable vertical 1

    # ### ######### ###########################
    ## Internal. Handle changes to the options.

    onconfigure -tagattr {attr} {
	if {$options(-tagattr) eq $attr} return

	if {$attr ne ""} {
	    if {$options(-view) != {}} {
		# Ensure that the view contains the attribute
		# requested for tagging

		$self CheckAttr $option(-view) [list $attr]
	    }
	}

	set options(-tagattr) $attr
	return
    }

    onconfigure -view {view} {
	if {$options(-view) eq $view} return

	if {$view != {}} {
	    # Ensure that the view contains all the attributes
	    # requested for display, and tagging

	    $self CheckAttr $view

	    if {$options(-tagattr) ne ""} {
		$self CheckAttr $view $options(-tagattr)
	    }
	}

	if {$options(-view) != {}} {
	    $options(-view) removeOnChangeCall $self
	    unset     crow
	    array set crow {}
	}

	set options(-view) $view

	if {$view != {}} {
	    ## The cursor variable will be regenerated in
	    ## RefreshDisplay, i.e. when the view in actual
	    ## use is known.
	    ## $view cursor crow
	    $view onChangeCall $self
	}
	# Schedule a refresh of the display
	${selfns}::tick rq
	return
    }

    onconfigure -attributes {alist} {
	if {$options(-attributes) eq $alist} return
	set options(-attributes) $alist

	if {$options(-view) != {}} {
	    # Ensure that the view contains all the attributes
	    # requested for display

	    $self CheckAttr $options(-view)
	}

	# Schedule a refresh of the display
	${selfns}::tick rq
	return
    }

    onconfigure -titles {value} {
	if {$options(-titles) eq $value} return
	set  options(-titles)    $value

	# Schedule a refresh of the display
	${selfns}::tick rq
	return
    }

    onconfigure -usetitles {value} {
	if {$options(-usetitles) eq $value} return
	set  options(-usetitles)    $value

	# Schedule a refresh of the display
	${selfns}::tick rq
	return
    }

    onconfigure -orientation {value} {
	if {$options(-orientation) eq $value} return

	switch -exact -- $value {
	    vertical - vertica - vertic - verti - \
		    vert - ver - ve - v {set vertical 1}
	    horizontal - horizonta - horizont - \
		    horizon - horizo - horiz - hori - \
		    hor - ho - h {set vertical 0}
	    default {
		return -code error \
			"Illegal orientation \"$value\""
	    }
	}

	set  options(-orientation)    $value

	# Schedule a refresh of the display
	${selfns}::tick rq
	return
    }

    # ### ######### ###########################
    ## Internal. Update display after options changed.

    method RefreshDisplay {} {
	# Reconfigure table to match the view ...

	set view   $options(-view)
	set alist  $options(-attributes)
	set titles $options(-titles)

	set rows 0
	set cols [llength $alist]

	if {$vertical} {
	    set topt -titlerows
	    set norm -titlecols
	} else {
	    set topt -titlecols
	    set norm -titlerows
	}

	# Heading

	if {$options(-usetitles)} {
	    $hull configure $topt 1 $norm 0
	    incr rows
	} else {
	    $hull configure $topt 0 $norm 0
	}

	# Main display proportions and setup

	if {$view != {}} {
	    incr rows [$view size]

	    # Create  cursor to use in "GetData" ...
	    # Do this before the reconfigure of the
	    # table, as this will already ask for it.
	    $view cursor crow

	    if {
		($rows > 1) &&
		($options(-tagattr) ne "")
	    } {
		# Non-empty view
		set crow(#) 0
		set tag $crow($options(-tagattr))

		#puts .TAG|ATTR|USE|0|$options(-tagattr)|=<$tag>

		$hull tag row $tag 1
	    }
	}

	if {!$rows} {
	    $hull configure -usecommand 0 -command {}
	} else {
	    if {$vertical} {
		$hull configure -usecommand 1 -command \
			[mymethod GetData %r %c]
	    } else {
		$hull configure -usecommand 1 -command \
			[mymethod GetData %c %r]
	    }
	}

	# We change the geometry only after the command callback has
	# been setup, because this change may already cause its
	# invocation.

	if {$vertical} {
	    $hull configure -rows $rows -cols $cols
	} else {
	    $hull configure -rows $cols -cols $rows
	}

	# Invalidating the cache causes a display refresh for the
	# tktable.

	$win clear cache
	return
    }

    # ### ######### ###########################
    ## Internal. Access to the view from the inner table widget.

    method GetData {r c} {
	#puts "- r$r / c$c - ([lindex $options(-attributes) $c])"
	set tr $r

	# Heading ?

	# Title handling
	if {$options(-usetitles)} {
	    if {$r == 0} {
		set v [lindex $options(-titles) $c]
		if {$v != {}} {
		    #puts "= title = '$v'"
		    return $v
		}
		set v [lindex $options(-attributes) $c]
		#puts "= title = '$v'"
		return $v
	    }
	    # Not the title row. Adjust the index for upcoming access
	    # of the view.
	    incr r -1
	}

	#puts "- r$r / c$c - ([lindex $options(-attributes) $c])"

	if {![llength $options(-attributes)]} {return {}}

	# The cursor we have is an optimization. We move it to the row
	# asked for by the table, except if the row is already
	# set. Retrieval is just a matter of reading from the cursor.

	if {[info exists crow(#)] && ($crow(#) != $r)} {
	    #puts "$win vtable/ROW $r"
	    set crow(#) $r
	    if {$options(-tagattr) ne ""} {

		set tag $crow($options(-tagattr))

		#puts ,TAG|ATTR|USE|$r|$options(-tagattr)|=<$tag>

	        $hull tag row $tag $tr
            }
	}

	#puts @@@@@@@@@@@@@@@@@@@@@@@@@@
	#parray crow
	#puts @@@@@@@@@@@@@@@@@@@@@@@@@@

	# Map column index to attribute name and return its value
	# from the cursor ...

	set value $crow([lindex $options(-attributes) $c])

	#puts "\t$value"

	return $value
    }

    # ### ######### ###########################
    ## Internal. Attribute verification.

    method CheckAttr {v {attr {}}} {
	if {![llength $attr]} {set attr $options(-attributes)}
	if {![llength $attr]} return

	array set p {}
	foreach a [$v names] {
	    set p($a) .
	}
	# The rowid attribute is always there, auto-created by the
	# view for any cursor.
	set p(#) .

	foreach a $attr {
	    if {[info exists p($a)]} continue
	    return -code error \
		    "Requested attribute \"$a\" not known to view \"$v\""
	}
	return
    }

    # ### ######### ###########################
    ## Internal. Change propagation. Called by the view we are
    ## attached to when its contents have changed.

    method change {o} {
	${selfns}::tick rq ; # Trigger display refresh
	return
    }

    # ### ######### ###########################
    ## Internal. Debugging helpers.

    if 0 {
	# Debug methods to looks at tag and clear operations.
	method tag {args} {
	    # Intercept and print tag operations ...
	    puts "$self tag $args"
	    return [eval [linsert $args 0 $hull tag]]
	}

	method clear {args} {
	    # Intercept and print clear operations ...
	    puts "$self clear $args"
	    return [eval [linsert $args 0 $hull clear]]
	}
    }

    # ### ######### ###########################
    ## Block the options we use internally ...
    ## They are effectively nulled out.

    foreach o {-command -cache -usecommand} {
	option $o {}
	onconfigure $o {args} "#return -code error \"Unknown option $o\""
	oncget      $o        "#return -code error \"Unknown option $o\""
    }
    unset o

    foreach o {-titlerows -titlecols} {
	option $o {}
	oncget $o "\$hull cget $o"
    }
    unset o

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use

package provide vtable 0.1
