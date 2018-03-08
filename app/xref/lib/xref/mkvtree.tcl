# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# mkvtree - treectrl /snit::widgetadaptor
#           modifies treectrl to use mk view as data source.
#           auto-configures #row / #col to match view
#           external configuration for mapping from column
#           number to property names.
#           titling of widget is different ...
#           external configuration
#           external configuration for titling ...

# NOTE: does no transformation of column data, nor 
# hiding of columns, combination of columns, etc.
# For this 'virtual views' can be used performing the
# desired operations ...

package require treectrl
package require syscolor
package require snit

namespace eval ::mkvtree {}

snit::widgetadaptor ::mkvtree {

    delegate method * to hull
    delegate option * to hull except -command

    constructor {args} {
	array set sortorder {}

	installhull [treectrl $win]
	$self configurelist $args
	$hull configure -showroot 0 -showheader 0

	$hull element create __E_text text \
		-fill [list \
		$::syscolor::highlightText {selected focus}]

	$hull element create __E_image image

	$hull element create __E_hilitrect rect -showfocus yes \
		-fill [list \
		$::syscolor::highlight {selected focus} \
		gray {selected !focus}]

	$hull style create   __S_treecol
	$hull style elements __S_treecol {__E_image __E_hilitrect __E_text}
	$hull style layout   __S_treecol __E_image -padx {0 4} -expand ns
	$hull style layout   __S_treecol __E_text  -padx {0 6} -expand ns
	$hull style layout   __S_treecol __E_hilitrect -union {__E_text} -iexpand ns -ipadx 2

	$hull style create   __S_datacol
	$hull style elements __S_datacol {__E_hilitrect __E_text}
	$hull style layout   __S_datacol __E_text -padx {0 6} -expand ns
	$hull style layout   __S_datacol __E_hilitrect -union {__E_text} -iexpand ns -ipadx 2

	# Elements and style for an invisible column of item data ...

	$hull element create __E_type text
	$hull element create __E_row  text

	$hull style create   __S_data
	$hull style elements __S_data {__E_type __E_row}

	# Event handling ...

        $hull notify install <Header>
        $hull notify install <Header-invoke>

	$hull notify bind $win <Header-invoke> \
		[mymethod SortOut %C]

	$hull notify bind $win <ActiveItem> \
		[mymethod BrowseOut %p %c]

	bind $win <Double-1> \
		[mymethod ActionOut %x %y]

	# Lazy creation of the children for the toplevel items.

	$hull notify bind $win <Expand-before> [mymethod Populate %I]
	return
    }

    # ### ######### ###########################
    # mkvtree - NEW API

    option -onsort   {}
    option -onaction {}
    option -onbrowse {}

    variable sortorder
    variable sortcol {}
    variable arrow

    option -basetype {}
    option -childdef {}

    ### FAKE - TODO ...
    method adjust {args} {}

    ## I. Our data source is a metakit view ...

    # Option to hold the reference to the view we
    # are connected to.
    #
    # Note: We are __not__ responsible for the destruction
    #       of the data view. We do not take ownership !

    option -data {}
    option -key  rowid

    # Option hold a list of property names. These properties
    # are expected to exist in -data, and are shown in the
    # table in the same order as in the value of the option.

    option -columns {}

    # Metakit cursor we use to access the elements of the
    # view.

    variable dcursor {}

    # Mapping from column indices to property names.
    # This mapping can be set automatically or via the
    # option -columns. If the latter is done the system
    # will check the data against all views given to it
    # as data source.

    variable columns


    # Title information ... If empty no titling is used.
    # If not empty the first n elements are used for titling,
    # where n = number of columns. If there are less the
    # name of the mapped property is used. If there are more
    # the overshot is ignored.

    option -titles {}

    # A callback to call whenever the number of columns has changed.

    ##option -ncolcommand {}
    variable ncols 0

    # Handle changes to the data source ...

    onconfigure -data {view} {
	# Ignore changes which are not.
	if {[string equal $view $options(-data)]} {return}

	#puts " ($view) <-- ($options(-data))"

	#puts MVT//[$view properties]

	set oldncols $ncols

	if {$view != {}} {
	    set pnames [$self GetProperties $view pnew]

	    # Check that all properties which are already mapped
	    # are known to the new view.
	    # A column mapping exists. Check that the new view
	    # has at least these columns. If not, fail.

	    $self ValidateProps [array names columns] $view pnew

	    # Map all properties which were not yet known to
	    # columns, i.e. indices ...

	    $self MapColumns $pnames
	    set ncols [array size columns]
	} else {
	    # The new view is {} = This widget has nothing to
	    # display.
	    set ncols 0
	}

	# Close cursor of previous view, if any
	if {$options(-data) != {}} {
	    unset dcursor ; array set dcursor {}
	}
	set options(-data) $view

	if 0 {
	    if {($oldncols != $ncols) && ($options(-ncolcommand) != {})} {
		uplevel #0 [linsert $options(-ncolcommand) end $oldncols $ncols]
	    }
	    if {($oldncols != $ncols)} {
		$self SortExecute
	    }
	}

	$self RequestRefresh
	return
    }

    # Handle changes to the column mapping

    onconfigure -columns {columnlist} {

	# Cut out internal key column
	set pos        [lsearch -exact $columnlist $options(-key)]
	set columnlist [lreplace       $columnlist $pos $pos]

	# Ignore changes which are not.
	if {[string equal $columnlist $options(-columnlist)]} {return}

	# We have a -data view ?
	# If so we also have an automatic mapping.
	# Check that all columns listed here are present.
	# If yes, use the order here to reorder the display.
	#
	# We have no -data (empty). Just set the column
	# mapping. The check will happen when -data changes.

	if {$options(-data) != {}} {
	    set                              view $options(-data)
	    $self GetProperties             $view pnew
	    $self ValidateProps $columnlist $view pnew
	}

	set options(-columns) {}
	unset columns ; array set columns {}
	$self MapColumns $columnlist
	$self RequestRefresh
	return
    }

    # Handle changes to the titles

    onconfigure -titles {value} {
	# Ignore changes which are not.
	if {[string equal $value $options(-titles)]} {return}

	set options(-titles) $value
	$self RequestRefresh
	return
    }

    # Change to basetype => implies image of toplevel items ...
    onconfigure -basetype {newvalue} {
	if {$options(-basetype) eq $newvalue} return
	set  options(-basetype) $newvalue

	# Can't do a thing without a child definition
	# object.

	if {$options(-childdef) == {}} return

	# Translate type to image, then update the style
	# element.

	if {$newvalue == {}} {
	    $hull element configure __E_image -image {}
	} else {
	    set image [$options(-childdef) image $newvalue]
	    $hull element configure __E_image -image $image
	}
	return
    }

    onconfigure -childdef {newvalue} {
	# Standard behaviour, remember the data

	if {$options(-childdef) eq $newvalue} return
	set  options(-childdef) $newvalue

	# Additionally set the image of toplevel items,
	# if defined.

	if {$options(-basetype) != {}} {
	    set image [$newvalue image $options(-basetype)]
	    $hull element configure __E_image -image $image
	} else {
	    $hull element configure __E_image -image {}
	}
	return
    }


    # ### ######### ###########################
    # Internals ...

    # Refresh handling ...

    # Boolean flag. Set if refresh was requested, but not yet
    # handled. Used to collapse multiple requests coming in a
    # series into a single true refresh

    variable tick 0

    method RequestRefresh {} {
	if {$tick} {return}
	set tick 1
	after idle [mymethod Refresh]
	return
    }
    method Refresh {} {
	# Reconfigure tree control to match the view ...

	set view $options(-data)

	# I. Titles, column definition.

	if {[llength $options(-titles)]} {
	    set coltitles $options(-titles)
	    $hull configure -showheader 1
	} else {
	    set coltitles $options(-columns)
	}
	set c 0

	#puts refresh/$self/${view}/______________________________________
	#puts C=([$hull column list])

	set sortcol [lindex $options(-columns) 0]
	foreach text $coltitles tag $options(-columns) {
	    if {![info exists sortorder($tag)]} {
		set sortorder($tag) up ; # increasing
	    }

	    #puts /col/configure/$c/$tag/$text
	    $hull column create
	    $hull column configure $c -visible 1 \
		    -background lightgrey -itembackground white \
		    -expand 1 -text $text -tag $tag \
		    -arrow $sortorder($tag) -arrowside left \
		    -borderwidth 1
	    incr c
	}
	if {$sortcol != {}} {
	    $hull column configure $sortcol -itembackground $sortcolor
	}

	#puts /col/configured/$c/[$hull column count]
	#puts C=([$hull column list])

	while {$c < [$hull column count]} {
	    #puts /col/delete/$c/of/[$hull column count]
	    $hull column delete "order $c"
	}

	#puts /col/reduced/$c/$k/[$hull column count]
	#puts C=([$hull column list])

	# Create another column, invisible, to contain
	# additional data about the item (view rowid,
	# and type, base-type here for the toplevels)

	$hull column create

	#puts C=([$hull column list])/[$hull column count]

	$hull column configure "order $c" -visible 0 \
		-text DATA -tag __DATA

	$hull configure -treecolumn 0

	#puts ___________________\n
	#puts /data/insertion\n---------------------------

	# II. Fill the tree (actually more table like) with items
	#     one per row in the view.
	#
	# Items with children are populated in a lazy fashion (see
	# Expand-before event)

	set  hasbutton [expr {$options(-childdef) != {}}]
	if {$hasbutton} {
	    set hasbutton [$options(-childdef) mayhavechildren $options(-basetype)]
	}

	#puts hasbutton=$hasbutton

	$hull item delete all
	if {$view != {}} {
	    #$view dump

	    set key $options(-key)
	    $view loop row {
		set r [$hull item create]

		#puts /item/$r

		$hull item lastchild root    $r
		$hull item configure         $r -button  $hasbutton
		$hull item configure         $r -visible 1
		$hull collapse               $r

		set style __S_treecol
		foreach property $options(-columns) {
		    #puts /item/$r/$property/'$row($property)

		    $hull item style set         $r $property $style
		    $hull item element configure $r $property __E_text -text $row($property)

		    #puts DEF//[$hull item element configure $r $property __E_text]
		    set style __S_datacol
		}

		# Invisible associated data ...

		$hull item style set         $r __DATA __S_data
		$hull item element configure $r __DATA __E_type -text $options(-basetype)
		$hull item element configure $r __DATA __E_row  -text $row($key)
	    }
	    # loop done
	}

	# Now sort the toplevel items according to the chosen spec.

	$self SortExecute

	set tick 0
	return
    }

    # Column mapping ...

    method MapColumns {clist} {
	set n [array size columns]
	foreach p $clist {
	    if {![info exists columns($p)]} {
		set columns($p) $n
		incr n

		# Make changes to the mapping available to the
		# users of the widget.

		lappend options(-columns) $p
	    }
	}
	return
    }

    method ValidateProps {plist view pvar} {
	upvar $pvar properties
	foreach p $plist {
	    if {![info exists properties($p)]} {
		return -code error \
			"$self column error: Mapped property\
			\"$p\" is not known to the view \"$view\" ([$view properties])"
	    }
	}
	return
    }

    method GetProperties {view {pvar {}}} {
	set pnames [list]
	foreach p [$view properties] {
	    foreach {pname ptype} [split $p :] break

	    # Cut out internal key column
	    if {$pname eq $options(-key)} continue

	    lappend pnames $pname
	}
	if {$pvar != {}} {
	    upvar $pvar properties
	    array set   properties {}
	    foreach p $pnames {
		set properties($p) .
	    }
	}
	return $pnames
    }

    method ActionOut {x y} {
	# Execute a callback for the double-clicked row.
	if {$options(-onaction) == {}} {return}

	# Translations:
	# 1. x/y coordinates to item id
	# 2. item id to rowid in view
	#    Ad 2) See 'BrowseOut'.
	# We ignore all clicks happening in the header line.

	set ident [$hull identify $x $y]
	if {$ident == {}} {return}
	foreach {itype item} $ident break
	if {$itype eq "header"} {return}

	set rowid   [$hull item element cget $item __DATA __E_row -text]
	set rowtype [$hull item element cget $item __DATA __E_type -text]

	#puts _______________________________________________
	#$options(-data) dump |
	#puts "Action: t/$itype | i$item | r$rowid / rt/$rowtype"
	#puts _______________________________________________

	uplevel #0 [linsert $options(-onaction) end $rowtype $rowid]
	return
    }

    method BrowseOut {old new} {
	# Execute a callback for the selected row.
	if {$options(-onbrowse) == {}} {return}
	if {$old eq $new} {return}

	# Translate the item id into a rowid for the view we display.
	#
	# For all items we get this information out of the elements
	# in the invisible column '__DATA'.

	set rowid   [$hull item element cget $new __DATA __E_row -text]
	set rowtype [$hull item element cget $new __DATA __E_type -text]

	# FUTURE: Distinguish toplevel and sub items.
	# Sub items have to be taken from a different view.

	#puts _______________________________________________
	#$options(-data) dump |
	#puts "Browse: i$new | r$rowid | rt/$rowtype"
	#puts _______________________________________________

	uplevel #0 [linsert $options(-onbrowse) end $rowtype $rowid]
	return
    }

    #                   RRggBB
    variable sortcolor \#fff7f7

    method SortOut {colidx} {
	# Sorting for column 'colidx' has to change.
	# Update internal data structures, then call
	# through the callback and ask the environment
	# for help.

	#puts $self/sort-change/$colidx

	# With no view attached sorting is not possible.
	if {$options(-data) == {}} return


	set colidx [$hull column cget $colidx -tag]

	set sortorder($colidx) [set neworder [$self OrderInvert $sortorder($colidx)]]

	$hull column configure $colidx -arrow $neworder

	# We maintain only one sort column ...
	#

	if {$sortcol != {}} {
	    $hull column configure $sortcol -itembackground white
	}

	set sortcol $colidx

	if {$sortcol != {}} {
	    $hull column configure $sortcol -itembackground $sortcolor
	}

	$self SortExecute
    }

    method OrderInvert {order} {
	switch -exact -- $order {
	    up   {return down}
	    down {return up}
	}
	return -code error "Invalid order \"$order\""
    }

    method SortExecute {} {
	switch -exact -- $sortorder($sortcol) {
	    up   {set option -increasing}
	    down {set option -decreasing}
	}
	set cmd [list $hull item sort 0 \
		-column     $sortcol \
		-element    __E_text \
		-dictionary $option \
		]


	#puts "Sorting via \[$cmd\]"

	eval $cmd
	return
    }

    method Populate {parent} {
	#puts "Populate $parent ... ?"

	# If a child definition is present we use it
	# to populate everything. Without a child
	# definition nothing can be populated.

	set cd $options(-childdef)
	if {$cd == {}} return

	# If we have already children in this node
	# nothing has to be done.

	if {[$hull item numchildren $parent]} {return}

	# Determine the type of this node and use that
	# to retrieve the metakit view from the CD which
	# contains the cildren to display. If there is no
	# view then there are no children either.

	set type [$hull item element cget $parent __DATA __E_type -text]
	set view [$cd view $type]

	if {$view == {}} return

	#puts "Populate $parent ... YES"

	# Translate item to a rowid, this is our key into the childview.

	set rowid [$hull item element cget $parent __DATA __E_row -text]
	set level [llength [$hull item ancestors $parent]]

	#puts "Key = $rowid / $view / $type / $level"

	$view loop c {
	    if {$c(key) != $rowid} continue

	    # Images from the child-definition

	    set image [$cd image $c(type)]
	    set label [$cd text  $c(type) $level $c(name)]

	    #puts "\tAdd ... ($label) / ($c(id)) / ($c(type))" ;# parray c

	    # Create items and add to parent ...

	    set r [$hull item create]
	    $hull item lastchild $parent $r
	    $hull item configure         $r -visible 1
	    $hull collapse               $r
	    $hull item configure         $r -button [$cd mayhavechildren $c(type)]

	    $hull item style set         $r 0 __S_treecol
	    $hull item element configure $r 0 __E_text  -text  $label
	    $hull item element configure $r 0 __E_image -image $image

	    $hull item style set         $r __DATA __S_data
	    $hull item element configure $r __DATA __E_type -text $c(type)
	    $hull item element configure $r __DATA __E_row  -text $c(id)
	}

	#$cv dump
	return
    }

    # Delegate the remainder to the original tktable ...

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
}

package provide mkvtree 0.1
