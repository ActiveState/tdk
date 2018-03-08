# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
# ### ######### ###########################

# UI tools. Widget. Display of a tree structure (forest actually, as
# more than one root is allowed). The structure is described by a view
# (see --> view.tcl) with the properties listed below. The widget is
# configured with the handle of the view to show. The widget registers
# itself as observer to the view and any changes to it are reflected
# in the display. The widget uses idle events to defer actual changes
# to the display until after the observed view has settled down after
# a series of changes.

# Properties of the shown view:
#
# - The view provides at least the following attributes:
#
#   Attribute	Type	Contents
#   =========	====	========
#   id		string	Unique identifier for the row in the view.
#   label	string	Label shown in the widget for the row.
#   =========	====	========
#
#   The following attributes are optional. IOW they can be absent. If
#   they are present however, then they have to support the
#   interpretation described below.
#
#   Attribute	Type	Contents
#   =========	====	========
#   icon	string	symbolic name of an image shown to the left
#			of the label. The image is retrieved via the
#			application icon database provided by the
#			package 'image'.
#   =========	====	========
#
# - Each row of the view is an entry in the display.

# ### ######### ###########################

# ### ######### ###########################
## Prerequisites

package require treectrl ; # The foundation for our display.
package require snit     ; # Object system
package require syscolor ; # System colors
package require image ; image::file::here ; # Predefined images
package require widget::scrolledwindow

# ### ######### ###########################
## Implementation

snit::widgetadaptor vpage {
    # ### ######### ###########################
    component tree

    delegate method * to tree
    delegate option * to tree
    delegate option -borderwidth to hull
    delegate option -relief      to hull
    # FUTURE: Exclude ...

    option -view {} ; # Reference to the view displayed by the widget.
    # ............... # The widget does _not_ own this view. It does
    # ............... # however own all sub-views it asked for from
    # ............... # the view.

    option -show {} ; # Callback. Executed whenever the active item
    # ............. ; # changes. Three arguments: path id of active
    # ............. ; # item, view containing it, and rowid of for the
    # ............. ; # active entry in the view. In this order.

    option -onaction {} ; # Callback. Same arguments as -show. Executed
    # ................. ; # when an item in the tree is double-clicked.

    # color to use on details view sorted column
    variable sortcolor "#fff7ff"

    variable     styles {icons smalllist details list}
    option -style icons ; # Display styling.

    # ### ######### ###########################
    ## Public API. (De)Construction.

    constructor {args} {
	set items          {}
	array set entry    {}
	array set pathmap  {}

	installhull using widget::scrolledwindow \
	    -borderwidth 1 -relief sunken

	install tree using treectrl $win.tree -highlightthickness 0 \
		      -borderwidth 0 -showheader 1 -xscrollincrement 20
	$hull setwidget $tree

	$tree debug configure -enable no -display no \
		-erasecolor pink -displaydelay 30

	## Explorer pane ....

	$tree notify install <Header>
	$tree notify install <Header-invoke>

	$tree notify install <Drag>
	$tree notify install <Drag-begin>
	$tree notify install <Drag-end>
	$tree notify install <Drag-receive>

	$tree notify install <Edit>
	$tree notify install <Edit-accept>

	###

	# Disable "scan" bindings on windows.
	if {$::tcl_platform(platform) eq "windows"} {
	    bind $tree <Control-ButtonPress-3> { }
	}

	bindtags $tree [list $tree TreeCtrl [winfo toplevel $tree] all]

	$tree notify bind $tree <ActiveItem> [mymethod ChangeActiveItem %p %c]
	bind $tree <Double-1>                [mymethod Action %x %y]

	$self configurelist $args
    }

    # ### ######### ###########################
    ## Public API. 

    # ### ######### ###########################
    ## Public API. Full refresh of the tree.

    method refresh {} {
	$options(-view) reset
	$self RegenItem
	return
    }

    # ### ######### ###########################
    ## Public API. Make a path visible. It becomes
    ## the active item.

    method show {pathid} {
	# Ensure that $pathmap($pathid) is present.
	# (Showing and opening the parent is not
	# enough, as the id might not be present in
	# the data).

	if {![info exists pathmap($pathid)]} {
	    return -code error \
		    "$self show: Pathid \"$pathid\" is not known."
	}

	# We can ensure the visibility of the item now.

	set theitem $pathmap($pathid)

	$tree selection clear all
	$tree see           $theitem
	$tree selection add $theitem
	$tree activate      $theitem
	return
    }

    method sortby {tag} {
	$self HeaderInvoke $tag
	return
    }

    # ### ######### ###########################
    ## Internal. Data structures.

    variable hasicon 0  ; # Indicator if view has an 'icon' attribute.

    # We keep per view which is open a record storing the association
    # between entries in the view, identified by rowid and item in the
    # tree. After a change the map is recomputed and the attribute
    # 'id' is temporariliy used to keep track of the entries, in case
    # their location in the view has moved. This record is essentially
    # a widget-internal attribute of the view.

    # The data structure is an array keyed by view handle. The value
    # is a list with a 1-1 correspondence between rowids and list
    # index.

    # The reverse mapping of the above is required for some operations
    # too. This reversal maps from item ids to the view containing
    # them, and the row therein, and the associated id.

    variable items ; # -> list of item id's
    variable entry ; # item -> {rowid id}

    # The outside world talks mainly in path ids, i.e. lists of id's
    # to describe items/entries in the tree. Mapping from items to
    # path id's can handled by the array 'entry' above, but we add
    # another structure for full caching of item to path translations.
    # However we also need a data structure going from path id's to
    # items translating outside data to the internal
    # representation. Only visible items are listed in the array
    # chosen for this task.

    variable pathmap ; # id -> item

    # ### ######### ###########################
    ## Internal. Handle changes to the options.

    onconfigure -view {view} {
	# Ignore changes which are not.
	if {$options(-view) eq $view} return

	if {$view != {}} {
	    # Ensure that the new view contains all the attributes
	    # required for proper display

	    $self CheckAttr $view
	}

	# Disconnect from the previous view, remember the new view,
	# and attach to it.

	if {$options(-view) != {}} {$self Detach}
	set options(-view) $view
	if {$view != {}}           {$self Attach}
	return
    }

    onconfigure -style {value} {
	if {$value eq $options(-style)} return
	if {[lsearch -exact $styles $value] < 0} {
	    return -code error "Unknown $type style \"$value\" found"
	}
	set options(-style) $value

	# This cycling kills and regenerates the items.
	$self Detach
	$self ConfigureStyle-$value
	$self Attach
	return
    }

    # ### ######### ###########################
    ## Internal. Access to the view from the inner table widget.

    # ### ######### ###########################
    ## Internal. Attribute verification.

    method CheckAttr {v} {
	array set p {}
	foreach a [$v names] {
	    set p($a) .
	}
	# The rowid attribute is always there, auto-created by the
	# view for any cursor.
	set p(#) .

	foreach a {id label} {
	    if {[info exists p($a)]} continue
	    return -code error \
		    "Required attribute \"$a\" not known to view \"$v\""
	}
	set hasicon [info exists p(icon)]
	return
    }

    # ### ######### ###########################
    ## Detach view from widget. Clears out the display.

    method Detach {} {
	$tree collapse 0
	#$options(-view) removeOnChangeCall $self

	## ASSERT: data structures empty
	## TODO: check assertion.

	#parray entry
	#parray pathmap

	set items {}
	unset     entry    ; array set entry    {}
	unset     pathmap  ; array set pathmap  {}


	$tree item delete all

	# Clear all bindings on the list added by the last show
	# This is why DontDelete it used for the <Selection>
	# binding.

	foreach pattern [$tree notify bind $tree] {
	    $tree notify bind $tree $pattern {}
	}

	# Clear all run-time states
	# Delete columns in list
	# Delete all styles in list
	# Delete all elements in list

	foreach state [$tree state names] {
	    $tree state undefine $state
	}
	$tree column delete all
	eval [list $tree style delete]   [$tree style names]
	eval [list $tree element delete] [$tree element names]

	$tree item configure root -button no
	$tree expand root

	# Restore some happy defaults to the list

	$tree configure -orient vertical -wrap "" -xscrollincrement 0 \
		-yscrollincrement 0 -itemheight 0 -showheader yes \
		-background white -scrollmargin 0 -xscrolldelay 50 \
		-yscrolldelay 50 -buttonimage "" -backgroundmode row \
		-treecolumn "" -indent 19

	# Restore default bindings to the list

	bindtags $tree [list \
		$tree \
		TreeCtrl \
		[winfo toplevel $tree] all]

	destroy $tree.entry
	destroy $tree.text
	return
    }

    # ### ######### ###########################
    ## Attach view to widget. Initializes basic display.

    method Attach {} {
	# options(view) is the master view. managing the children of
	# the true root (item 0).

	set pathmap()  0

	### FillItem ##

	set items {}
	set ::TreeCtrl::Priv(DirCnt,$tree) 0 ; # HACK

	$options(-view) loop row {
	    set rowid $row(#)
	    set id    $row(id)

	    set newitem [$self NewItem $rowid]
	    lappend items $newitem

	    set entry($newitem) [list $rowid $id]
	    set pathmap($id) $newitem

	    if {$row(type) eq "directory"} {incr ::TreeCtrl::Priv(DirCnt,$tree)} ; # HACK
	}

	# We monitor the view for changes as they may effect the
	# display.

	$options(-view) onChangeCall $self

	#parray entry
	#parray pathmap

	$self Attach-$options(-style)
	return
    }

    # ### ######### ###########################
    ## Internal. Create a new item for an entry in a view.

    method NewItem {rowid} {
	set newitem [$tree item create]
	$tree item lastchild 0 $newitem
	$tree collapse         $newitem

	$self NewItemSetStyle-$options(-style) $newitem
	##$tree item style set   $newitem TREE s1

	$self ConfigureItem $newitem $rowid
	return $newitem
    }

    # ### ######### ###########################
    ## Internal. Configure an item with data from an entry in a view.

    method ConfigureItem {theitem rowid} {
	set view  $options(-view)
	set label [$view get $rowid label]

	$tree item configure         $theitem -button 0
	$tree item configure         $theitem -visible 1

	## FUTURE -- configurable style stuff better ...
	if 0 {
	    $tree item element configure $theitem TREE e3 -text $label
	    if {$hasicon} {
		set icon [$view get $rowid icon]
		if {$icon != {}} {
		    $tree item element configure $theitem TREE e1 \
			    -image [image::get $icon]
		}
	    }
	}

	$view cursor c ; set c(#) $rowid
	$self ConfigureItem-$options(-style) $theitem c
	return
    }

    # ### ######### ###########################
    ## Internal. Change propagation. Called by the views we are
    ## attached to when their contents have changed.

    method change {o} {
	# It has to be one of the views associated with an open node
	# which changed, because these are the only ones we monitor.
	# We get the parent tree item containing its data and enforce
	# a refresh of the display.

	$self RegenItem
	return
    }

    # ### ######### ###########################
    ## Internal. Regenerate the tree under an item
    ## after a change to the view.

    method RegenItem {} {
	# The view changed. This means that the data in 'items' and
	# 'entry' for this item and view is now obsolete. We have to
	# recompute this information, handling the cases of new
	# entries appearing, entries disappearing, entries moved to a
	# different row, entries being relabeled, having gotten
	# children, or having no children anymore.

	# As the rowid is no hard connection anymore we turn to the
	# 'id' column to match items and rows together.

	# Get the 'id -> item' map from before the
	# change.

	array set map {}
	foreach c $items {
	    foreach {__ id} $entry($c) break
	    set map($id) $c
	}

	# Run over the changed view to handle all
	# changes.

	set items {}
	set ::TreeCtrl::Priv(DirCnt,$tree) 0 ; # HACK

	$options(-view) loop row {
	    set id    $row(id)
	    set rowid $row(#)

	    if {$row(type) eq "directory"} {incr ::TreeCtrl::Priv(DirCnt,$tree)} ; # HACK

	    if {[info exists map($id)]} {
		# The item survived. It may require reconfiguration
		# though. By moving it to the last position we ensure
		# that after the loop all entries is shown in the same
		# order as they occur in the view.

		set childitem $map($id)

		lappend items $childitem
		set entry($childitem) [list $rowid $id]

		$tree item lastchild 0 $childitem
		$self ConfigureItem $childitem $rowid

		unset map($id) ;# Excempt this from the deletion loop.

		# The pathmap is unchanged by this.
	    } else {
		# We have an unknown id here. IOW it is new. Create an
		# item for it.

		set newitem [$self NewItem $rowid]
		lappend items $newitem
		set entry($newitem) [list $rowid $id]

		set pathmap($id) $newitem
	    }
	}

	# Every id still left in 'map' has disappeared from the
	# view. Kill their items now.

	foreach k [array names map] {
	    set theitem $map($k)

	    $tree item delete $theitem

	    set path [lindex $entry($theitem) 1]
	    unset pathmap($path)
	}
	return
    }


    # ### ######### ###########################
    ## Internal. Event binding. Respond to changes in the active item.

    method ChangeActiveItem {p c} {
	# We don't really care about changes if there is nothing we
	# should tell them to.

	if {$options(-show) == {}} return
	if {$p != $c} {$self Show $c}
	return
    }

    # ### ######### ###########################
    ## Internal. Execute the show callback for an item.

    method Show {theitem} {

	# Call only if $options(-show) is not empty

	# We convert the item into a tuple containing its rowid and
	# the view containing its entry. The rowid is determined by
	# searching for the item's id in the view.

	if {$theitem != 0} {
	    foreach {rowid id} $entry($theitem) break
	} else {
	    set rowid -1
	    set id    {}
	}

	uplevel #0 [linsert $options(-show) end $id $options(-view) $rowid]

	$tree see $theitem
	return
    }

    # ### ######### ###########################
    ## Execute the double-click callback for a click at some
    ## coordinates. Ignored if no callback specified.

    method Action {x y} {
	# Execute a callback for the double-clicked row.
	if {$options(-onaction) == {}} {return}

	# Translations:
	# 1. x/y coordinates to item id
	# 2. item id to rowid in view
	# We ignore all clicks happening in the header line.

	set identity [$tree identify $x $y]
	if {$identity == {}} return
	foreach {type theitem} $identity break

	if {$type eq "header"} {return}

	foreach {rowid id} $entry($theitem) break

	uplevel #0 [linsert $options(-onaction) end $id $options(-view) $rowid]
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

    foreach o {-command -cache -usecommand -titlerow -titlecols} {
	option $o {}
	onconfigure $o {args} "#return -code error \"Unknown option $o\""
	oncget      $o        "#return -code error \"Unknown option $o\""
    }
    unset o

    # ### ######### ###########################

    method ConfigureStyle-icons {} {
	# Tree is horizontal, wrapping occurs at right edge
	# of window, each item is as wide as the smallest
	# needed multiple of 110 pixels

	# Item height is 32 for icon, 4 padding, 3 lines of text

	set itemHeight [expr {32 + 4 + \
		[font metrics [$tree cget -font] -linespace] * 3}]

	$tree configure -showroot no -showbuttons no -showlines no \
		-selectmode extended -wrap window \
		-orient horizontal -itemheight $itemHeight \
		-showheader no -scrollmargin 16 \
		-xscrolldelay {500 50} \
		-yscrolldelay {500 50}

	$tree column create
	$tree column configure 0 -width 75

	set prefix [$options(-view) cget -iconprefix]
	if {$prefix == ""} {set prefix big}

	$tree element create elemImg image \
		-image [list \
		[image::get ${prefix}-folderSel] selected \
		[image::get ${prefix}-folder] {} \
		]

	$tree element create elemTxt text \
		-fill [list $::syscolor::highlightText {selected focus}] \
		-justify center -lines 1 -width 71 -wrap word

	$tree element create elemSel rect -showfocus yes \
		-fill [list $::syscolor::highlight {selected focus} gray {selected}]

	# image + text
	set S [$tree style create STYLE -orient vertical]
	$tree style elements $S {elemSel elemImg elemTxt}
	$tree style layout $S elemImg -expand we
	$tree style layout $S elemTxt -pady {4 0} -padx 2 -squeeze x -expand we
	$tree style layout $S elemSel -union [list elemTxt]

	TreeCtrl::SetEditable $tree {
	    {0 STYLE elemTxt}
	}
	TreeCtrl::SetSensitive $tree {
	    {0 STYLE elemImg elemTxt}
	}
	TreeCtrl::SetDragImage $tree {
	    {0 STYLE elemImg elemTxt}
	}

	$tree notify bind $tree <Edit-accept> {
	    %T item text %I 0 %t
	}

	bindtags $tree [list \
		$tree \
		TreeCtrlFileList TreeCtrl \
		[winfo toplevel $tree] all]
	return
    }

    method ConfigureStyle-smalllist {} {
	$self ConfigureStyle-list
	$tree configure -orient horizontal -xscrollincrement 0
	# stepwidth should be dynamically determined
	$tree column create
	$tree column configure 0 -width {}
	$tree configure -itemwidthmultiple 150 -itemwidthequal no
	return
    }

    method ConfigureStyle-details {} {
	set height [font metrics [$tree cget -font] -linespace]
	if {$height < 18} {
	    set height 18
	}
	$tree configure -showroot no -showbuttons no -showlines no \
		-itemheight $height -selectmode extended \
		-xscrollincrement 20 -scrollmargin 16 \
		-xscrolldelay {500 50} \
		-yscrolldelay {500 50}

	$tree column create
	$tree column create
	$tree column create
	$tree column create

	$tree column configure 0 -width 130 -text "Name" \
	    -tag name -arrow up -arrowpadx 6 -borderwidth 1 \
	    -itembackground $sortcolor
	$tree column configure 1 -width  60 -text "Size" -tag size \
		-justify right -arrowside left -arrowgravity right \
		-borderwidth 1
	$tree column configure 2 -width  70 -text "Type"    \
		-tag type -borderwidth 1
	$tree column configure 3 -width 120 -text "Modified" \
		-tag modified -borderwidth 1

	$tree element create e1 image \
		-image [list \
		[image::get small-folderSel] {selected} \
		[image::get small-folder] {} \
		]
	$tree element create e2 text \
		-fill [list $::syscolor::highlightText {selected focus}] -lines 1
	$tree element create txtType text -lines 1
	$tree element create txtSize text -lines 1 -datatype integer -format "%dKB"
	$tree element create txtDate text -lines 1 -datatype time -format "%Y-%m-%d %H:%M"
	$tree element create e4 rect -showfocus yes \
		-fill [list $::syscolor::highlight {selected focus} gray {selected !focus}]

	# image + text
	set S [$tree style create styName -orient horizontal]
	$tree style elements $S {e4 e1 e2}
	$tree style layout $S e1 -expand ns
	$tree style layout $S e2 -padx {2 0} -squeeze x -expand ns
	$tree style layout $S e4 -union [list e2] -iexpand ns -ipadx 2

	# column 1: text
	set S [$tree style create stySize]
	$tree style elements $S txtSize
	$tree style layout $S txtSize -padx 6 -squeeze x -expand ns

	# column 2: text
	set S [$tree style create styType]
	$tree style elements $S txtType
	$tree style layout $S txtType -padx 6 -squeeze x -expand ns

	# column 3: text
	set S [$tree style create styDate]
	$tree style elements $S txtDate
	$tree style layout $S txtDate -padx 6 -squeeze x -expand ns

	TreeCtrl::SetEditable $tree {
	    {name styName e2}
	}
	TreeCtrl::SetSensitive $tree {
	    {name styName e1 e2}
	}
	TreeCtrl::SetDragImage $tree {
	    {name styName e1 e2}
	}

	$tree notify bind $tree <Edit-accept> {
	    %T item text %I 0 %t
	}

	bindtags $tree [list \
		$tree \
		TreeCtrlFileList TreeCtrl \
		[winfo toplevel $tree] all]
	return
    }

    method ConfigureStyle-list {} {
	set height [font metrics [$tree cget -font] -linespace]
	if {$height < 18} {
	    set height 18
	}

	$tree configure -showroot no -showbuttons no -showlines no \
		-itemheight $height -selectmode extended \
		-wrap window -showheader no -scrollmargin 16 \
		-xscrolldelay "500 50" \
		-yscrolldelay "500 50"

	$tree column create
	$tree column configure 0 -widthhack yes

	$tree element create elemImg image \
		-image [list \
		[image::get small-folderSel] {selected} \
		[image::get small-folder]    {} \
		]
	$tree element create elemTxt text -lines 1 \
		-fill [list $::syscolor::highlightText {selected focus}]
	$tree element create elemSel rect -showfocus yes \
		-fill [list $::syscolor::highlight {selected focus} gray {selected !focus}]

	# image + text
	set S [$tree style create STYLE]
	$tree style elements $S {elemSel elemImg elemTxt}
	$tree style layout $S elemImg -expand ns
	$tree style layout $S elemTxt -squeeze x -expand ns -padx {2 0}
	$tree style layout $S elemSel -union [list elemTxt] -iexpand ns -ipadx 2

	TreeCtrl::SetEditable $tree {
	    {0 STYLE elemTxt}
	}
	TreeCtrl::SetSensitive $tree {
	    {0 STYLE elemImg elemTxt}
	}
	TreeCtrl::SetDragImage $tree {
	    {0 STYLE elemImg elemTxt}
	}

	$tree notify bind $tree <Edit-accept> {
	    %T item text %I 0 %t
	}

	bindtags $tree [list \
		$tree \
		TreeCtrlFileList TreeCtrl \
		[winfo toplevel $tree] all]
	return
    }

    # ### ######### ###########################

    method NewItemSetStyle-icons {theitem} {
	$tree item style set $theitem 0 STYLE
    }

    method NewItemSetStyle-smalllist {theitem} {
	$tree item style set $theitem 0 STYLE
    }

    method NewItemSetStyle-details {theitem} {
	# FUTURE: Configurable attributes ...
	$tree item style set $theitem 0 styName 1 stySize 2 styType 3 styDate
    }

    method NewItemSetStyle-list {theitem} {
	$tree item style set $theitem 0 STYLE
    }

    # ### ######### ###########################

    method ConfigureItem-icons {theitem datavar} {
	upvar $datavar a
	$self ConfigureIcons $theitem a
    }

    method ConfigureItem-smalllist {theitem datavar} {
	upvar $datavar a
	$self ConfigureIcons $theitem a
    }

    method ConfigureItem-list {theitem datavar} {
	upvar $datavar a
	$self ConfigureIcons $theitem a
    }

    method ConfigureIcons {theitem datavar} {
	upvar $datavar a
	set img $a(icon)
	set imgconfig [list \
		[image::get ${img}Sel] {selected} \
		[image::get $img]      {}]

	$tree item element configure $theitem 0 \
		elemImg -image $imgconfig + \
		elemTxt -text  $a(label)
	return
    }

    method ConfigureItem-details {theitem datavar} {
	# FUTURE: Configurable attributes.

	upvar $datavar a
	set img $a(icon)
	set imgconfig [list \
		[image::get ${img}Sel] {selected} \
		[image::get $img]      {}]

	$tree item element configure $theitem \
		0 \
		e1 -image $imgconfig + \
		e2 -text $a(label) , \
		1 txtSize -data [expr {$a(size) / 1024 + 1}] , \
		2 txtType -text $a(ftype) , \
		3 txtDate -data $a(mtime)
	return
    }

    # ### ######### ###########################

    method Attach-icons {} {
	bind $tree <Double-1>                [mymethod Action %x %y]
	$tree notify bind $tree <ActiveItem> "\n\
		catch {%T item element configure %p 0 elemTxt -lines {}} \n\
		%T item element configure %c 0 elemTxt -lines 3 \n\
		[mymethod ChangeActiveItem %p %c]\n\
		"
	return
    }

    method Attach-smalllist {} {
	bind $tree <Double-1>                [mymethod Action %x %y]
	$tree notify bind $tree <ActiveItem> [mymethod ChangeActiveItem %p %c]
	return
    }

    method Attach-list {} {
	bind $tree <Double-1>                [mymethod Action %x %y]
	$tree notify bind $tree <ActiveItem> \
		[mymethod ChangeActiveItem %p %c]
	return
    }

    method Attach-details {} {
	bind $tree <Double-1>                [mymethod Action %x %y]
	$tree notify bind $tree <ActiveItem> [mymethod ChangeActiveItem %p %c]

	set sortcol 0
	$tree notify bind $tree <Header-invoke> \
		[mymethod HeaderInvoke %C]
	return
    }

    # ### ######### ###########################

    variable sortcol 0
    method HeaderInvoke {C} {
	if {$C == $sortcol} {
	    if {[$tree column cget $sortcol -arrow] eq "down"} {
		set order -increasing
		set arrow up
	    } else {
		set order -decreasing
		set arrow down
	    }
	} else {
	    if {[$tree column cget $sortcol -arrow] eq "down"} {
		set order -decreasing
		set arrow down
	    } else {
		set order -increasing
		set arrow up
	    }
	    $tree column configure $sortcol -arrow none -itembackground white
	    set sortcol $C
	}
	$tree column configure $C -arrow $arrow -itembackground $sortcolor
	set dirCount $::TreeCtrl::Priv(DirCnt,$tree)
	set lastDir [expr {$dirCount - 1}]
	switch -exact [$tree column cget $C -tag] {
	    name {
		if {$dirCount} {
		    $tree item sort root $order -last "root child $lastDir" -column $C -dictionary
		}
		if {$dirCount < [$tree item count] - 1} {
		    $tree item sort root $order -first "root child $dirCount" -column $C -dictionary
		}
	    }
	    size {
		if {$dirCount < [$tree item count] - 1} {
		    $tree item sort root $order -first "root child $dirCount" -column $C -integer -column name -dictionary
		}
	    }
	    type {
		if {$dirCount < [$tree item count] - 1} {
		    $tree item sort root $order -first "root child $dirCount" -column $C -dictionary -column name -dictionary
		}
	    }
	    modified {
		if {$dirCount} {
		    $tree item sort root $order -last "root child $dirCount prevsibling" -column $C -integer -column name -dictionary
		}
		if {$dirCount < [$tree item count] - 1} {
		    $tree item sort root $order -first "root child $dirCount" -column $C -integer -column name -dictionary
		}
	    }
	}
	return
    }

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready for use

package provide vpage 0.1
