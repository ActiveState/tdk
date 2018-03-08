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
#   nchildren	integer Number of children for the entry.
#   children	view	The subview detailing the children.
#			Valid iff 'nchildren > 0'.
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
#   icon-open   string	See 'icon'. If not present then only 'icon'
#			is used to create the image to the left of
#			the label, independent of the state of the
#			node. If however both 'icon-open' and 'icon'
#			are present' then 'icon-open' determines the
#			icon if the node is open, and 'icon' when it
#			is closed. Note: If 'icon-open' is present,
#			but not 'icon' then the attribute will be
#			ignored.
#   =========	====	========
#
# - Each row of the view is an entry in the display, a 'root' of the
#   shown forest.
#
# - Each valid subview has to have the same structure as the main
#   view, but only with respect to the attributes listed above. Beyond
#   that the sub-views can vary from entry to entry. This also means
#   that all views can be of different types.
#
# - The path id of an entry E in an arbitrarily deep subview V is
#   constructed by lappend'ing the id of E to the path id of the entry
#   in the parent view of V through which V can be reached. This
#   implies that path id's are lists of id's, and the first element
#   will always be the id of an entry in the main view.
#
#   Given the definition above we require that each path id which can
#   be constructed by recursively traversing the entire main view and
#   its sub views is unique. This unique-ness and the unique-ness of
#   entry id's within their view allows the widget to construct and
#   maintain an bijective mapping between the nodes in the tree to the
#   entries in the view structure even for entries appearing,
#   disappearing and changing.

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

snit::widgetadaptor vtree {
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

    option -onaction ; # Callback. Same arguments as -show. Executed
    # .............. ; # when an item in the tree is double-clicked.

    # ### ######### ###########################
    ## Public API. (De)Construction.

    constructor {args} {
	array set item     {}
	array set entry    {}
	array set children {}
	array set parent   {}
	array set pathmap  {}
	array set itemmap  {}

	installhull using widget::scrolledwindow \
	    -borderwidth 1 -relief sunken

	install tree using treectrl $win.tree -highlightthickness 0 \
	    -borderwidth 0 -showheader 0 -xscrollincrement 20
	$hull setwidget $tree

	$tree debug configure -enable no -display no

	set height [font metrics [$tree cget -font] -linespace]
	if {$height < 18} {
	    # ensure that we have image space
	    set height 18
	}

	$tree configure -itemheight $height -selectmode single \
	    -showroot no -showrootbutton no -showbuttons yes \
	    -showlines yes -scrollmargin 16 \
	    -xscrolldelay {500 50} \
	    -yscrolldelay {500 50}

	# One column, tree-like

	$tree column create
	$tree column configure 0 -expand yes -tag TREE \
	    -itembackground [list \#f6f9f4 {}]
	$tree configure -treecolumn 0

	# Elements to display, styles containing them
	#
	# s1 e5 rect  | focus rectangle (e3 on top)     | Node style
	#    e1 image | image left to text, open/closed |
	#    e3 text  | label text                      |
	#
	# s1 e5 rect  | focus rectangle (e3 on top)     | Drag style
	#    e2 image | 'small file'                    |
	#    e3 text  | label text                      |

	$tree element create e1 image \
	    -image [list \
			[image::get folder-open]   open \
			[image::get folder-closed] {}]
	$tree element create e2 image -image [image::get small-file]
	$tree element create e3 text \
	    -fill [list \
		       [syscolor::highlightText] {selected focus} \
		      ]
	##$tree element create e4 text -fill blue
	$tree element create e5 rect -showfocus yes \
	    -fill [list \
		       [syscolor::highlight] {selected focus} \
		       gray                  {selected !focus} \
		      ]
	## $tree element create e6 text

	$tree style create s1
	$tree style elements s1 {e5 e1 e3} ;# e4
	$tree style layout s1 e1 -padx {0 4} -expand ns
	$tree style layout s1 e3 -padx {0 4} -expand ns
	## $tree style layout s1 e4 -padx {0 6} -expand ns
	$tree style layout s1 e5 -union [list e3] -iexpand ns -ipadx 2

	$tree style create s2
	$tree style elements s2 {e5 e2 e3}
	$tree style layout s2 e2 -padx {0 4} -expand ns
	$tree style layout s2 e3 -padx {0 4} -expand ns
	$tree style layout s2 e5 -union [list e3] -iexpand ns -ipadx 2

	::TreeCtrl::SetSensitive $tree {
	    {TREE s1 e5 e1 e3}
	    {TREE s2 e5 e2 e3}
	}
        ::TreeCtrl::SetDragImage $tree {
	    {TREE s1 e1 e3}
	    {TREE s2 e2 e3}
	}

	bindtags $tree [list $tree TreeCtrl [winfo toplevel $tree] all]

	$tree notify bind $tree <Expand-before>  [mymethod Populate   %I]
	$tree notify bind $tree <Collapse-after> [mymethod Depopulate %I]

	$tree notify bind $tree <ActiveItem> [mymethod ChangeActiveItem %p %c]
	bind $tree <Double-1>                [mymethod Action %x %y]

	$self configurelist $args
    }

    # ### ######### ###########################
    ## Public API. 

    # ### ######### ###########################
    ## Public API. Full refresh of the tree.

    method refresh {} {
	$self RefreshTree 1
	return
    }

    # ### ######### ###########################
    ## Public API. Make a path visible. It becomes
    ## the active item.

    method open {pathid} {
	$self show $pathid
	set theitem $pathmap($pathid)
	$tree expand $theitem
	return
    }

    method show {pathid} {
	# Ignore the call if the item is already
	# visible. We may have to shift the column
	# around to bring the item into the visible
	# range.

	if {![info exists pathmap($pathid)]} {
	    # The item is not visible. Make the
	    # parent visible and open it.

	    set parentpath [lrange $pathid 0 end-1]
	    $self show $parentpath

	    set parentitem $pathmap($parentpath)
	    $tree expand $parentitem
	}

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

    # ### ######### ###########################
    ## Internal. Data structures.

    variable hasicon 0  ; # Indicator if view has an 'icon' attribute.
    variable hasopen 0  ; # Indicator if view has an 'icon-open' attribute.

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

    variable item  ; # view -> list of item id's
    variable entry ; # item -> {view rowid id}

    # A second data structure records per item the view managing the
    # children of that item. A reverse mapping from view to parental
    # item is present too. Both structures are arrays keyed by item
    # and view handle respectively. Data is present iff the item has
    # children and is currently open.

    variable children ; # item -> childview
    variable parent   ; # view -> parental item

    # The outside world talks mainly in path ids, i.e. lists of id's
    # to describe items/entries in the tree. Mapping from items to
    # path id's can handled by the array 'entry' above, but we add
    # another structure for full caching of item to path translations.
    # However we also need a data structure going from path id's to
    # items translating outside data to the internal
    # representation. Only visible items are listed in the array
    # chosen for this task.

    variable pathmap ; # path -> item
    variable itemmap ; # item -> path

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

	foreach a {id label nchildren children} {
	    if {[info exists p($a)]} continue
	    return -code error \
		    "Required attribute \"$a\" not known to view \"$v\""
	}
	set hasicon [info exists p(icon)]
	set hasopen [expr {$hasicon && [info exists p(icon-open)]}]
	return
    }

    # ### ######### ###########################
    ## Detach view from widget. Clears out the display.

    method Detach {} {
	$tree collapse 0
	#$options(-view) removeOnChangeCall $self

	## ASSERT: data structures empty
	## TODO: check assertion.

	#parray item
	#parray entry
	#parray children
	#parray parent
	#parray pathmap
	#parray itemmap

	unset     item	   ; array set item     {}
	unset     entry    ; array set entry    {}
	unset     children ; array set children {}
	unset     parent   ; array set parent   {}
	unset     pathmap  ; array set pathmap  {}
	unset     itemmap  ; array set itemmap  {}
	return
    }

    # ### ######### ###########################
    ## Attach view to widget. Initializes basic display.

    method Attach {} {
	# options(view) is the master view. managing the children of
	# the true root (item 0).

	set pathmap()  0
	set itemmap(0) {}

	$self FillItem 0 $options(-view)
	return
    }

    # ### ######### ###########################
    ## Internal. Create a new item for an entry in a view.

    method NewItem {parentitem view rowid} {
	set newitem [$tree item create]
	$tree item lastchild $parentitem $newitem
	$tree collapse $newitem
	$tree item style set $newitem TREE s1

	$self ConfigureItem $newitem $view $rowid
	return $newitem
    }

    # ### ######### ###########################
    ## Internal. Configure an item with data from an entry in a view.

    method ConfigureItem {theitem view rowid} {
	set nchildren [$view get $rowid nchildren]
	set label     [$view get $rowid label]
	set haschildren [expr {$nchildren > 0}]

	#puts !$theitem!$haschildren!

	$tree item element configure $theitem TREE e3 -text $label
	$tree item configure         $theitem -button $haschildren
	set hc($theitem) $haschildren
	$tree item configure         $theitem -visible 1

	if {!$haschildren && ([llength [$tree item children $theitem]] > 0)} {
	    # We are reusing an item having children for an entry
	    # without such. To this end we kill all the children
	    # currently known.

	    # Bug 64807.
	    # It is this part which requires us to perform the refresh
	    # from the bottom up. When a selection is unmounted the
	    # archive is possibly open, and refresh top down will kill
	    # the children and entry here, and then handle it again
	    # later, trying to delete it a second time, and failing
	    # with an internal error. The order from the bottom up
	    # avoids this snag.

	    foreach child [$tree item children $theitem] {
		$self DeleteItem $child
	    }
	}
	if {$hasicon} {
	    set icon [$view get $rowid icon]

	    if {$hasopen} {
		set icono [$view get $rowid icon-open]

		$tree item element configure $theitem TREE e1 \
			-image [list \
			[image::get $icono] open \
			[image::get $icon]  {}]
	    } else {
		$tree item element configure $theitem TREE e1 \
			-image [image::get $icon]
	    }
	}
	return
    }

    # ### ######### ###########################
    ## Internal. Populate a node for display.

    variable hc -array {}

    method Populate {theitem} {
	# This is possible only for an item associated with an entry
	# which has children. We have to check this nevertheless, the
	# keyboard bindings allow the activation of this command even
	# if 'hasbutton' for item is false. :(

	#puts <$theitem|[$tree item cget $theitem -button]>

	#if {![$tree item cget $theitem -button]} return
	if {!$hc($theitem)} return

	# We can also assume that the item itself has no children yet
	# (is closed). This means that 'children' and 'parent' have no
	# data about 'theitem' yet (or not anymore). We do have data
	# in 'entry' telling us where the associated entry lives
	# (view, row). This is enough for us to get the childview we
	# need for the expansion.

	foreach {view rowid __} $entry($theitem) break
	set childview [$view open $rowid children]
	# NOTE: We own this childview.

	$self FillItem $theitem $childview
	return
    }

    # ### ######### ###########################
    ## Internal. Code common to Attach and Populate

    method FillItem {parentitem childview} {
	set children($parentitem) $childview
	set parent($childview) $parentitem

	set parentpath $itemmap($parentitem)

	set items {}
	$childview loop row {
	    set rowid $row(#)
	    set id    $row(id)

	    set newitem [$self NewItem $parentitem $childview $rowid]
	    lappend items $newitem

	    set entry($newitem) [list $childview $rowid $id]

	    set newpath $parentpath ; lappend newpath $id

	    set pathmap($newpath) $newitem
	    set itemmap($newitem) $newpath
	}

	set item($childview) $items

	# We monitor the view for changes as they may effect the
	# display.

	$childview onChangeCall $self

	#parray item
	#parray entry
	#parray children
	#parray parent
	#parray pathmap
	#parray itemmap

	return
    }

    # ### ######### ###########################
    ## Internal. Smash a node which has been closed.
    ## We ignore events on items without children.
    ## They happen during creation of an item when
    ## it is initially configured.

    method Depopulate {theitem} {
	if {[llength [$tree item children $theitem]] == 0} {return}

	# After collapsing the item on the screen we release all
	# resources held internally, by deleting the now invisible
	# nodes. We also free their management data structures.

	foreach child [$tree item children $theitem] {
	    $self DeleteItem $child

	    set path $itemmap($child)
	    unset itemmap($child)
	    unset pathmap($path)
	}

	set childview $children($theitem)
	unset children($theitem)
	unset parent($childview)

	set items $item($childview) ; # NOTE == list in first loop
	unset item($childview)
	foreach c $items {
	    unset entry($c)
	}

	# We must not destroy the view associated with the true root
	# node. This one view does _not_ belong to us.
	if {$theitem == 0} return

	$childview destroy
	return
    }

    # ### ######### ###########################
    ## Internal. Delete a single item and the tree below it.

    method DeleteItem {theitem} {
	if {[llength [$tree item children $theitem]] > 0} {
	    $self Depopulate $theitem
	}
	$tree item delete $theitem
	unset -nocomplain hc($theitem)
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

	set parentitem $parent($o)
	$self RegenItem $parentitem $o
	return
    }

    # ### ######### ###########################
    ## Internal. Regenerate the tree under an item
    ## after a change to the view.

    method RegenItem {theitem view {reset 0}} {
	# The child view managing the children of 'theitem'
	# changed. This means that the data in 'item' and 'entry' for
	# this item and view is now obsolete. We have to recompute
	# this information, handling the cases of new entries
	# appearing, entries disappearing, entries moved to a
	# different row, entries being relabeled, having gotten
	# children, or having no children anymore.

	# As the rowid is no hard connection anymore we turn to the
	# 'id' column to match items and rows together.

	# Get the 'id -> item' map from before the
	# change. id = last element of path

	array set map {}
	foreach c $item($view) {
	    foreach {__ __ id} $entry($c) break
	    set map($id) $c
	}

	# Run over the changed view to handle all
	# changes.

	set parentpath $itemmap($theitem)

	if {$reset} {$view reset}

	set items {}
	$view loop row {
	    set id    $row(id)
	    set rowid $row(#)
	    if {[info exists map($id)]} {
		# The item survived. It may require reconfiguration
		# though. By moving it to the last position we ensure
		# that after the loop all entries are shown in the same
		# order as they occur in the view.

		set childitem $map($id)

		lappend items $childitem
		set entry($childitem) [list $view $rowid $id]

		$tree item lastchild $theitem $childitem
		$self ConfigureItem $childitem $view $rowid

		unset map($id) ;# Excempt this from the deletion loop.

		# The pathmap is unchanged by this. Ditto for the itemmap.
	    } else {
		# We have an unknown id here. IOW it is new. Create an
		# item for it.

		set newitem [$self NewItem $theitem $view $rowid]
		lappend items $newitem
		set entry($newitem) [list $view $rowid $id]

		set newpath $parentpath ; lappend newpath $id
		set pathmap($newpath) $newitem
		set itemmap($newitem) $newpath
	    }
	}

	# Every id still left in 'map' has disappeared from the
	# view. Kill their items now. Remove their item <-> path
	# mappings from the cache too.

	foreach k [array names map] {
	    set theitem $map($k)

	    $self DeleteItem $theitem

	    set path $itemmap($theitem)
	    unset     pathmap($path)
	    unset     itemmap($theitem)
	}

	set item($view) $items
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

	foreach {view rowid __} $entry($theitem) break
	set itempath $itemmap($theitem)

	uplevel #0 [linsert $options(-show) end $itempath $view $rowid]

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

	foreach {view rowid __} $entry($theitem) break
	set itempath $itemmap($theitem)

	uplevel #0 [linsert $options(-onaction) end $itempath $view $rowid]
	return
    }

    # ### ######### ###########################
    ## Internal. Regenerate the entire tree on
    ## demand of the user. sort of assumes that
    ## the widget is connected to a view which
    ## does not generate change notifications.
    ## (Could be by design, or limitations in
    ## the underlying structures make it impossible.

    method RefreshTree {reset} {
	# We remember the path id's of all open
	# nodes (not 'visible' nodes. That is more),
	# then we regen the root and keep regen'ing
	# the open nodes, if they are still present.

	set open {}
	foreach i [array names children] {
	    lappend open $itemmap($i)
	}

	# Do the refresh from the bottom up (longer paths first). This
	# ensures that deeper nested deletions happen first and cannot
	# be affected by deletions in higher levels. Bug 64807.

	foreach i [lsort -decreasing $open] {
	    if {![info exists pathmap($i)]} continue
	    set theitem $pathmap($i)
	    $self RegenItem $theitem $children($theitem) $reset
	}

	# Regen root, last.
	$self RegenItem 0 $children(0) $reset
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
}

# ### ######### ###########################
## Ready for use

package provide vtree 0.1
