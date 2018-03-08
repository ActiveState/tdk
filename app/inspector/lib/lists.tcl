# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: lists.tcl,v Exp $
#

proc splitx {input splitStr} {
    return [split [string map [list $splitStr \0] $input] \0]
}

snit::widgetadaptor filter_dlg {
    delegate option * to hull
    delegate method * to hull

    option -attach -default {}

    variable patterns {}
    variable filtertype exclude

    component entry
    component listbox

    constructor {args} {
	installhull using widget::dialog -transient 1 -synchronous 0 \
	    -type okcancelapply -place above -padding 4 \
	    -command [mymethod callback]

	set frame [$hull getframe]
	set tf [ttk::frame $frame.top]
	ttk::label $tf.l -text "Pattern:"
	set entry [ttk::entry $tf.e]
	bind $entry <Return> [mymethod add_pattern]
	grid $tf.l $tf.e -sticky ew
	grid columnconfigure $tf 1 -weight 1

	set left [ttk::frame $frame.left]
	ttk::button $left.add -text "Add Pattern" \
	    -command [mymethod add_pattern]
	ttk::button $left.del -text "Delete Pattern(s)" \
	    -command [mymethod delete_patterns]
	ttk::radiobutton $left.inc -variable [myvar filtertype] \
	    -value include -text "Include Patterns"
	ttk::radiobutton $left.exc -variable [myvar filtertype] \
	    -value exclude -text "Exclude Patterns"
	grid $left.inc -sticky ew -padx 2 -pady 2
	grid $left.exc -sticky ew -padx 2 -pady 2
	grid $left.add -sticky ew -padx 2 -pady 2
	grid $left.del -sticky ew -padx 2 -pady 2
	grid rowconfigure $left 5 -weight 1

	widget::scrolledwindow $frame.sw -scrollbar vertical
	set listbox [listbox $frame.list -width 30 -height 10 \
			 -selectmode multiple -borderwidth 1 -relief flat \
			 -highlightthickness 0 \
			 -listvariable [myvar patterns]]
	$frame.sw setwidget $frame.list

	grid $frame.top - -sticky ew -pady {0 2}
	grid $frame.left $frame.sw -sticky news
	grid columnconfigure $frame 1 -weight 1
	grid rowconfigure    $frame 1 -weight 1

	$self configurelist $args

	# Get good initial state
	set patterns   [lsort -unique [$options(-attach) cget -patterns]]
	set filtertype [$options(-attach) cget -filtertype]
    }
    method callback {w result} {
	if {$result eq "apply" || $result eq "ok"} {
	    $options(-attach) configure -patterns $patterns \
		-filtertype $filtertype
	    if {$result eq "apply"} {
		# prevent dialog from disappearing
		return -code break
	    }
	} else {
	    $listbox selection clear 0 end
	    set patterns [lsort -unique [$options(-attach) cget -patterns]]
	    set filtertype [$options(-attach) cget -filtertype]
	}
    }
    method add_pattern {} {
	set pat [$entry get]
	if {$pat ne ""} {
	    # keep patterns sorted
	    set patterns [lsort -unique [linsert $patterns 0 $pat]]
	}
    }
    method delete_patterns {} {
	# reverse order to safely delete without perturbing index
	set idxs [lsort -decreasing -integer [$listbox curselection]]
	foreach idx $idxs {
	    set patterns [lreplace $patterns $idx $idx]
	}
	$listbox selection clear 0 end
    }
}

snit::widgetadaptor showlist_dlg {
    delegate option * to hull
    delegate method * to hull

    component combobox -public combobox
    delegate option -postcommand to combobox

    constructor {args} {
	installhull using widget::dialog -transient 1 -synchronous 0 \
	    -type okcancel -place above -padding 4

	wm resizable $win 1 0
	set frame [$hull getframe]

	ttk::label $frame.l -text "Show: "
	install combobox using ttk::combobox $frame.e
	grid $frame.l $frame.e -sticky ew
	grid columnconfigure $frame 1 -weight 1

	bind $frame.e <Return> [mymethod close ok]
	focus $frame.e

	$self configurelist $args
    }
}

snit::widget inspect_box {
    # Use a regular frame to allow us to recess it.
    # We'll place a ttk::frame right inside.
    hulltype frame

    component tree
    component label
    delegate option -width  to tree
    delegate option -height to tree
    delegate option * to hull
    delegate method * to hull

    option -title	-default {} -configuremethod C-title
    option -command     -default {}
    option -main        -default {}
    option -patterns    -default {} -configuremethod C-needupdate
    option -filtertype  -default exclude -configuremethod C-needupdate
    option -contents    -default {}
    option -name        -default {}
    option -updatecmd   -default {}
    option -filtercmd   -default {}
    option -retrievecmd -default {}
    option -separator   -default {} -configuremethod C-separator
    option -menu        -default {} -configuremethod C-menu

    variable current_item {}
    variable search_index 0
    variable contents {}
    variable filtered_contents {}
    variable update_pending 0

    constructor {args} {
	if {[tk windowingsystem] eq "win32"} {
	    $win configure -relief groove -borderwidth 1
	} else {
	    $win configure -relief sunken -borderwidth 1
	}
	ttk::frame $win.top
	install label using ttk::label $win.title -anchor w

	foreach {img action tip} {
	    find    search_dialog "Find in list"
	    refresh refresh       "Refresh window"
	    delete  remove        "Delete this view"
	} {
	    ttk::button $win.$img -style Slim.Toolbutton -image $img.gif \
		-takefocus 0 -command [mymethod $action]
	    tooltip $win.$img $tip
	}

	widget::scrolledwindow $win.sw -scrollbar vertical -borderwidth 0
	install tree using treectrl $win.sw.tree \
	    -borderwidth 0 -highlightthickness 0 \
	    -selectmode browse \
	    -showheader 0 \
	    -showroot 0 \
	    -showbuttons 0 \
	    -showlines 0
	$win.sw setwidget $tree
	$self _build_tree

	grid $win.title $win.find $win.refresh $win.delete \
		-in $win.top -sticky ew -pady 2 -padx 0
	grid columnconfigure $win.top 0 -weight 1
	grid $win.top -sticky ew
	grid $win.sw  -sticky news
	grid columnconfigure $win 0 -weight 1
	grid rowconfigure    $win 1 -weight 1

	$self configurelist $args
    }

    method _build_tree {} {
	$tree column create -text "Items" -tags "items" -expand 1 \
	    -borderwidth 1 -itembackground [list "#FFFFFF" "#eeeeff"]

	set selbg $::style::as::highlightbg
	set selfg $::style::as::highlightfg

	# Create the elements
	$tree element create elemImg image
	$tree element create elemText text -lines 1 \
	    -fill [list $selfg {selected focus}]
	$tree element create selRect rect \
	    -fill [list $selbg {selected focus} gray {selected !focus}]

	# text style (other columns)
	set S [$tree style create styText]
	$tree style elements $S {selRect elemText}
	$tree style layout $S selRect -union {elemText} -iexpand news
	$tree style layout $S elemText -squeeze x -expand ns -padx 2

	$tree notify bind $tree <Selection> [mymethod trigger]

	# tree options now that we have columns and styles
	set height [font metrics [$tree cget -font] -linespace]
	if {$height < 18} { set height 18 }
	$tree configure -treecolumn items -defaultstyle styText \
	    -itemheight $height
    }

    method windows_info {args} {
	uplevel 1 [list $options(-main) windows_info] $args
    }
    method target {args} {
	uplevel 1 [list $options(-main) target] $args
    }
    method main {args} {
	uplevel 1 [list $options(-main)] $args
    }
    method C-needupdate {option value} {
	# Use this for options that require an update
	set options($option) $value
	$self update_needed
    }
    method C-separator {option value} {
	set options($option) $value
	set nonnull [string compare $value ""]
	$tree configure -showlines $nonnull -showbuttons $nonnull
	$self update_needed
    }
    method C-title {option value} {
	$label configure -text "$value:"
	set options($option) $value
    }
    method C-menu {option menu} {
	if {[winfo exists $menu]} {
	    $menu delete 0 end
	    $menu add command -underline 0 \
		-label "Show a $options(-name)..." \
		-command [mymethod show_dialog]
	    $menu add command -underline 0 -label "Edit Filter..." \
		-command [mymethod edit_filter]
	    $menu add command -underline 1 -label "Find $options(-title)..." \
		-command [mymethod search_dialog]
	    # Images don't work on Aqua, and don't enhance much anyways
	    #-compound left -image find.gif
	    $menu add command -underline 1 -label "Refresh" \
		-command [mymethod refresh]
	    #-compound left -image refresh.gif
	    if {0} {
		$menu add command -underline 2 -label " Remove" \
		    -command [mymethod remove] \
		    -compound left -image delete.gif
	    }
	    if {[tk windowingsystem] eq "aqua"} {
		bind $tree <Button-2> [list tk_popup $menu %X %Y]
		bind $tree <Control-Button-1> [list tk_popup $menu %X %Y]
	    } else {
		bind $tree <Button-3> [list tk_popup $menu %X %Y]
	    }
	} else {
	    if {[tk windowingsystem] eq "aqua"} {
		bind $tree <Button-2> {}
		bind $tree <Control-Button-1> {}
	    } else {
		bind $tree <3> {}
	    }
	}
	set options($option) $menu
    }
    method add {what args} {
	if {[winfo exists $options(-menu)]} {
	    eval [linsert $args 0 $options(-menu) add]
	}
    }
    method curselection {} {
	return $current_item
    }
    method update_needed {} {
	after cancel $update_pending
	set update_pending [after idle "if {\[winfo exists $win\]} [list [mymethod do_update] ]"]
    }
    method do_update {} {
	$tree item delete 0 end
	set x [string equal $options(-filtertype) "exclude"]
	foreach item $contents {
	    set include $x
	    foreach pattern $options(-patterns) {
		if {[regexp -- $pattern $item]} {
		    set include [expr {!$x}]
		    break
		}
	    }
	    if {$include} {
		set sep $options(-separator)
		if {$sep ne "" && $item ne $sep} {
		    set parts [splitx $item $sep]
		} else {
		    set parts [list $item]
		}
		set last ""
		foreach part $parts {
		    # XXX ignore empty parts?  Root indicator?
		    if {$part eq ""} { continue }
		    set parent [expr {$last eq "" ? "root" : $last}]
		    set tag $last$sep[string trim $part $sep]
		    if {[$tree item id "tag \"$tag\""] eq ""} {
			set i [$tree item create \
				   -parent $parent \
				   -open 0 \
				   -button auto \
				   -tags [list $tag] \
				  ]
			$tree item element configure $i \
			    items elemText -text $part -data $tag
			$tree item enabled $i 0
		    }
		    set last $tag
		}
		# Enable the leaf items
		$tree item enabled $i 1
		lappend filtered_contents $item
	    }
	}
    }
    method update {target} {
	set contents ""
	set filtered_contents ""
	if {$options(-updatecmd) ne ""} {
	    set contents [uplevel \#0 $options(-updatecmd) [list $win $target]]
	}
	$self update_needed
    }
    method refresh {} {
	set target [$options(-main) target]
	# Without a target an update is impossible, skip. The problem
	# has been reported already by the 'target'-method itself.
	if {$target eq ""} return
	$self update $target
    }
    method trigger {} {
	set sel [lindex [$tree selection get] 0]
	if {$sel eq ""} return
	set name [$tree item element cget $sel items elemText -data]
	$self run_command $name
    }
    method retrieve {target item} {
	if {$options(-retrievecmd) ne ""} {
	    return [uplevel \#0 $options(-retrievecmd) \
			[list $win $target $item]]
	}
    }
    method send_filter {str} {
	if {$options(-filtercmd) ne ""} {
	    return [uplevel \#0 $options(-filtercmd) [list $win $str]]
	} else {
	    return $str
	}
    }
    method run_command {item} {
	if {$options(-command) ne ""} {
	    set current_item $item
	    if {$item ne ""} {
		uplevel \#0 [concat $options(-command) [list $item]]
	    }
	}
    }
    method remove {} {
	$options(-main) delete_list $self
    }
    method edit_filter {} {
	set editor $win.editor
	if {![winfo exists $editor]} {
	    filter_dlg $editor -attach $win -parent $win \
		-title "Edit $options(-title) Filter"
	}
	$editor display
    }
    method search_dialog {} {
	if {![winfo exists $win.search]} {
	    find_dialog $win.search -attach $win \
		-title "Find in $options(-title)" \
		-parent [winfo toplevel $win]
	    ::tk::PlaceWindow $win.search center
	} else {
	    wm deiconify $win.search
	}
    }
    method reset_search {{set_see 0}} {
	set search_index 0
	if {$set_see} {
	    $tree see $search_index
	}
    }
    method search {search_type match_case text} {
	if {$text eq ""} { return }
	switch -- $search_type {
	    "exact"  {
		set cmd [list string equal]
		if {!$match_case} { lappend cmd "-nocase" }
	    }
	    "glob"   {
		set cmd [list string match]
		if {!$match_case} { lappend cmd "-nocase" }
	    }
	    "regexp" {
		set cmd regexp
		if {!$match_case} { lappend cmd "-nocase" }
		lappend cmd "--"
	    }
	}

	foreach item [lrange $filtered_contents $search_index end] {
	    set found [eval $cmd [list $text $item]]
	    if {$found} {
		$tree selection clear
		set i [$tree item id "tag $options(-separator)$item"]
		$tree selection add $i
		$tree item expand $i
		$tree see $i
		incr search_index
		$self run_command $item
		break
	    }
	    incr search_index
	}
	if {!$found} {
	    bell
	    $options(-main) status "No $search_type match for \"$text\""
	    $self reset_search
	}
    }

    method show_dialog {} {
	set showdlg $win.show
	if {![winfo exists $showdlg]} {
	    showlist_dlg $showdlg -title "Show a $options(-name)" \
		-parent $win \
		-command [mymethod show_dialog_ok $showdlg] \
		-postcommand [mymethod show_dialog_postcmd $showdlg]
	}
	$showdlg display
    }
    method show_dialog_postcmd {showdlg} {
	$showdlg combobox configure -values $contents
    }
    method show_dialog_ok {showdlg w result} {
	if {$result eq "ok"} {
	    set value [$showdlg combobox get]
	    if {$value ne ""} {
		$self run_command $value
	    }
	}
    }
}
