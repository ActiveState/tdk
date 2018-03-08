# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# fileWidget.tcl --
#
#	This file implements a execution widget, a combination of
#	start-button and logging window.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: Exp $
#
# -----------------------------------------------------------------------------

package require BWidget  ; # BWidgets | Foundation for this mega-widget.
package require fileutil ; # Tcllib   | File finder ...
package require image ; image::file::here
package require tipstack
package require widget::scrolledwindow

# -----------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::tape::fileWidget::create
#     - tcldevkit::tape::fileWidget::destroy
#     - tcldevkit::tape::fileWidget::configure
#     - tcldevkit::tape::fileWidget::cget
#     - tcldevkit::tape::fileWidget::setfocus
# -----------------------------------------------------------------------------

namespace eval ::tcldevkit::tape::fileWidget {
    Tree::use
    ArrowButton::use

    Widget::declare tcldevkit::tape::fileWidget {
	{-variable	     String     ""     0}
        {-errorbackground    Color     "lightyellow" 0}
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
        {-connect            String     ""     0}
    }

    Widget::addmap tcldevkit::tape::fileWidget "" :cmd    {-background {}}
    Widget::addmap tcldevkit::tape::fileWidget "" :item   {-foreground -fill -font {}}
    Widget::addmap tcldevkit::tape::fileWidget "" .sw.t   {-background {}}

    foreach w {
	.e .a .r .bf .bd .bdr
    } {
	Widget::addmap tcldevkit::tape::fileWidget "" $w {
	    -background {} -foreground {} -font {}
	}
    }

    proc ::tcldevkit::tape::fileWidget {path args} {
	return [eval fileWidget::create $path $args]
    }
    proc use {} {}

    bind fileWidget <FocusIn> {::tcldevkit::tape::fileWidget::setfocus %W}

    # Widget class data
    set ::Widget::tcldevkit::tape::fileWidget::keymap {
	files     files
	fok       files,ok
	files,msg files,msg
    }
    set ::Widget::tcldevkit::tape::fileWidget::keymap_r {
	files     files
	files,ok  fok
	files,msg files,msg
    }
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::tape::fileWidget::create
# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::create { path args } {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::tape::fileWidget $path $args
    namespace eval ::Widget::tcldevkit::tape::fileWidget::$path {}

    InitState                     $path
    ValidateStoreVariable         $path
    set main_opt [Widget::subcget $path :cmd]

    eval [list ttk::frame $path -class tcldevkit::tape::fileWidget] $main_opt

    ## Scrolled Tree Window
    set f [widget::scrolledwindow $path.sw \
	       -borderwidth 1 -relief sunken -scrollbar vertical]
    set t [eval [list Tree $path.sw.t] [Widget::subcget $path .sw.t] \
	       -borderwidth 0 -height 20 \
	       -dragenabled 0 -dropenabled 0 \
	       -selectcommand [list [list ::tcldevkit::tape::fileWidget::TrackSelection $path]]]
    $f setwidget $t

    bind real${path} <Destroy> {tcldevkit::tape::fileWidget::destroy %W; rename %W {}}

    foreach {type w static_opts} {
	ttk::button  .a   {-text "Add" -state disabled}
	ttk::button  .r   {-text "Remove"}
	ttk::button  .ed  {-text "Edit"}
	ttk::button  .bf  {-text "Browse... (F)"}
	ttk::button  .bd  {-text "Browse... (D)"}
	ttk::button  .bdr {-text "Browse... (D/rec)"}
	ttk::button  .sa  {-text "Set Alias"}
	ttk::button  .tie {-text "Toggle Inc/Exc"}
	ttk::entry   .e   {}
	ttk::label   .pt  {-text ""}
	ttk::button  .up  {-text "Up"}
	ttk::button  .dn  {-text "Down"}
    } {
	eval [list $type $path$w] [Widget::subcget $path $w] $static_opts
	set tags [bindtags $path$w]
	bindtags $path$w [linsert $tags 1 $path]
    }

    ::tcldevkit::appframe::setkey $path Return   [list ::tcldevkit::tape::fileWidget::Add    $path]
    ::tcldevkit::appframe::setkey $path KP_Enter [list ::tcldevkit::tape::fileWidget::Add    $path]
    ::tcldevkit::appframe::setkey $path Delete   [list ::tcldevkit::tape::fileWidget::Remove $path]
    ::tcldevkit::appframe::setkey $path Up       [list ::tcldevkit::tape::fileWidget::MoveUp $path]
    ::tcldevkit::appframe::setkey $path Down     [list ::tcldevkit::tape::fileWidget::MoveDn $path]

    foreach {w cmd image} {
	.a   Add          add
	.r   Remove       delete
	.ed  EditEntry    {}
	.bf  BrowseFile   file
	.bd  BrowseDir    directory
	.bdr BrowseDirRec directory_rec
	.sa  SetAlias     {}
	.tie ToggleInEx   {}
	.up  MoveUp       up
	.dn  MoveDn       down
    } {
	$path$w configure -command [list ::tcldevkit::tape::fileWidget::$cmd $path]
	if {$image != {}} {$path$w configure -image [Icon $image]}
    }
    foreach {w opt key} {
	.e   -textvariable pattern
    } {
	$path$w configure $opt \
	    ::Widget::tcldevkit::tape::fileWidget::${path}::state($key)
    }

    bindtags $path [list real${path} fileWidget [winfo toplevel $path] all]

    foreach {slave col row stick padx pady cspan rspan} {
	.pt   0 0   e  1m 1m 1 1

	.up   0 1   e  1m 1m 1 1
	.dn   0 2   e  1m 1m 1 1

	.bf   2 0  wen 1m 1m 1 1
	.bd   3 0  wen 1m 1m 1 1
	.bdr  4 0  wen 1m 1m 1 1

	.a    2 1  wn  1m 1m 4 1
	.r    2 2  wn  1m 1m 4 1
	.ed   2 3  wen 1m 1m 4 1
	.sa   2 4  wen 1m 1m 4 1
	.tie  2 5  wen 1m 1m 4 1

	.e    1 0 swen 1m 1m 1 1
	.sw   1 1 swen 1m 1m 1 6
    } {
	grid $path$slave -column $col -row $row -sticky $stick \
	    -padx $padx -pady $pady -rowspan $rspan -columnspan $cspan
    }

    foreach {master col weight} {
	{}   0 0
	{}   1 1
	{}   2 0
	{}   3 0
	{}   4 0
	{}   5 0
    } {
	grid columnconfigure $path$master $col -weight $weight
    }
    # Bugzilla entry 19676 ...
    grid columnconfigure $path 0 -minsize 32 ; # Stop jittering when changing the icon later

    foreach {master row weight} {
	{} 0 0
	{} 1 0
	{} 2 0
	{} 3 0
	{} 4 0
	{} 5 1
    } {
	grid rowconfigure $path$master $row -weight $weight
    }

    tipstack::defsub $path {
	.a   {Add entry to the list of files in the package}
	.r   {Remove selected items from list}
	.ed  {Change the contents of the selected file or directory item}
	.bf  {Browse for file in the package}
	.bd  {List base directory containing files of the package}
	.bdr {List all files found under directory}
	.sa  {Set alias name for a file in the package}

	.e   {Enter file, or directory, for wrapping}
	.sw  {List of files and packages in package}
	.pt  {Type of current contents of the entry}
	.up  {}
	.dn  {}
	.tie {Toggle between included / excluded for a path in a directory}
    }

    # No help for these two buttons as it covers the item to be moved
    # 90% of the time, very bad.
    #	.up  {Move the selected item one row up}
    #	.dn  {Move the selected item one row down}

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::tape::fileWidget::\$cmd $path \$args\]\
	    "

    # Handle an initial setting of -connect.
    Connect $path [Widget::getoption $path -connect]

    TrackSelection $path {} {} ; # Initialize selection tracking.
    Serialize      $path       ; # First export of configuration

    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::fileWidget::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::tape::fileWidget::${path}::state
    variable $svar
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::linkvar

    if {[info exists linkvar]} {
	if {$linkvar != {}} {
	    # Remove the traces for linked variable, if existing
	    trace vdelete $linkvar w [list \
		    ::tcldevkit::tape::fileWidget::TraceIn $path $linkvar]
	    trace vdelete $svar    w [list \
		    ::tcldevkit::tape::fileWidget::TraceOut $path $svar]
	}
	unset linkvar
    }
    if {[info exists state]} {
	# Remove internal traces
	trace vdelete ${svar}(pattern) w [list \
		::tcldevkit::tape::fileWidget::TrackPattern $path $svar]
	unset state
    }
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::fileWidget::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    eval [linsert $args 0 configure $path]
}

proc ::tcldevkit::tape::fileWidget::configure { path args } {
    # addmap -option are already forwarded to their approriate subwidgets
    set res [Widget::configure $path $args]
    # Handle -errorbackground.

    if {[Widget::hasChanged $path -connect conn]} {
	Connect $path $conn
    }
    if {[Widget::hasChanged $path -variable dummy]} {
	ValidateStoreVariable $path
    }
    return $res
}

proc ::tcldevkit::tape::fileWidget::Connect { path cmd } {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    set state(connect) $cmd
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::fileWidget::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::fileWidget::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::ValidateStoreVariable { path } {

    set svar ::Widget::tcldevkit::tape::fileWidget::${path}::state
    variable $svar
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::linkvar


    set newvar [Widget::getoption $path -variable]
    if {[string equal $newvar $linkvar]} {
	# -variable unchanged.
	return
    }

    # -variable was changed.

    if {$newvar == {}} {
	# The variable was disconnected from the widget. Remove the traces.

	trace vdelete $linkvar w [list \
		::tcldevkit::tape::fileWidget::TraceIn $path $linkvar]
	trace vdelete $svar    w [list \
		::tcldevkit::tape::fileWidget::TraceOut $path $svar]

	set linkvar ""
	return
    }

    # Ok, newvar is the new variable to link to. Get a true namespaced
    # name for it.

    if {[set nsvar [namespace which -variable $newvar]] == {}} {
	# Variable not known, assume global.
	set newvar ::[string trimleft $newvar :]
    } else {
	set newvar $nsvar
    }

    if {$linkvar == {}} {
	# Attached variable to a widget not having one yet. Remember
	# name, setup traces, copy relevant information of state!

	CopyState $path $newvar

	trace variable $newvar w [list \
		::tcldevkit::tape::fileWidget::TraceIn $path $newvar]
	trace variable $svar   w [list \
		::tcldevkit::tape::fileWidget::TraceOut $path $svar]

	set linkvar $newvar
	return
    }

    # Changed from one variable to the other. Remove old traces, setup
    # new ones, copy relevant information of state!

    trace vdelete $linkvar w [list \
	    ::tcldevkit::tape::fileWidget::TraceIn $path $linkvar]
    trace vdelete $svar    w [list \
	    ::tcldevkit::tape::fileWidget::TraceOut $path $svar]

    CopyState $path $newvar

    trace variable $newvar w [list \
	    ::tcldevkit::tape::fileWidget::TraceIn $path $linkvar]
    trace variable $svar   w [list \
	    ::tcldevkit::tape::fileWidget::TraceOut $path $svar]

    set linkvar $newvar
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::UpCall {path args} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state
    set cmd $state(connect)
    log::log debug  "eval $cmd $args"
    return [uplevel \#0 [linsert $args 0 $state(connect) do]]
}

proc ::tcldevkit::tape::fileWidget::CopyState { path var } {
    upvar \#0 ::Widget::tcldevkit::tape::fileWidget::keymap map
    upvar \#0 $var data
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    foreach {inkey exkey} $map {
	set data($exkey) $state($inkey)
    }
    return
}

proc ::tcldevkit::tape::fileWidget::InitState { path } {
    set svar ::Widget::tcldevkit::tape::fileWidget::${path}::state
    variable $svar
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::linkvar

    set linkvar ""
    array set state {
	connect {}
	counter 0
	ptype   none pattern {}
	seltype null selctx  {}
	ok      0    msg     {}
	files   {}   fok     0 files,msg {}
	trace   {}
    }

    set state(lastdir,dir)  [pwd]
    set state(lastdir,file) [pwd]

    # Internal traces computing the ok/fail state of the entered information.

    trace variable ${svar}(pattern) w [list \
	    ::tcldevkit::tape::fileWidget::TrackPattern $path $svar]
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::TraceIn { path tvar var idx op } {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state   state

    # Lock out TraceIn if it is done in response to a change in the widget itself.
    if {[string equal $state(trace) out]} {return}

    upvar #0 ::Widget::tcldevkit::tape::fileWidget::keymap_r  map_r
    upvar #0 $tvar                                                data

    ##puts "TraceIn { $path $var /$idx/ $op }"

    array set tmp $map_r
    if {[info exists tmp($idx)]} {set inkey $tmp($idx)} else {return}
    set state($inkey) $data($idx)

    if {[string equal $inkey files]} {
	Deserialize $path
    }
    return
}

proc ::tcldevkit::tape::fileWidget::TraceOut { path tvar var idx op } {
    upvar #0 $tvar                                                      state
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::keymap           map
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::linkvar linkvar
    upvar #0 $linkvar                                                   data

    ##puts "TraceOut { $path $var /$idx/ $op }"

    array set tmp $map
    if {[info exists tmp($idx)]} {set exkey $tmp($idx)} else {return}
    set state(trace) out
    set data($exkey) $state($idx)
    set state(trace) ""
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::Icon {type} {
    set icon {}
    catch {set icon [image::get $type]}
    return $icon
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::Tag {path} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    set     tag [incr state(counter)]
    return $tag
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::AddEntry {path parent type text {where end}} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    set newitem [Tag $path]
    eval $path.sw.t insert $where $parent $newitem \
	    [Widget::subcget $path :item] \
	    -drawcross auto -data $type \
	    -image [Icon $type] -text [list $text]

    # Ensure visibility of new entry
    if {![string equal $parent root]} {
	$path.sw.t opentree $parent 0
    }

    set state(lastadded,item) $newitem
    set state(lastadded,path) $text

    if {$state(selection) != {}} {
	HandleMoves $path
    }
    return $newitem
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::SetPType {path type} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    switch -exact -- $type {
	none      -
	unknown   {$path.pt configure -text "?" -image {}}
	include   -
	exclude   -
	alias     -
	directory {$path.pt configure -image [Icon $type]}
	default   {return -code error "Unknown pattern type \"$type\""}
    }
    set state(ptype) $type
    return
}

proc ::tcldevkit::tape::fileWidget::SetMsg {path msg} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    set state(msg) $msg

    if {$msg == {}} {
	tipstack::pop $path.e
    } else {
	tipstack::push $path.e $msg
    }
    return
}

proc ::tcldevkit::tape::fileWidget::SetError {path msg} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    $path.a configure -state disabled
    $path.e state invalid
    SetMsg $path $msg
    set state(ok)  0
    return
}

proc ::tcldevkit::tape::fileWidget::ClearError {path} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    $path.e state !invalid
    $path.a configure -state normal
    SetMsg $path ""
    set state(ok)  1
    return
}

proc ::tcldevkit::tape::fileWidget::ClassifyPattern {path} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    ClearError $path

    if {[string equal $state(seltype) multi]} {
	# Cannot classify if there is more than one
	# item selected.
	SetPType $path unknown
	SetError $path "Cannot classify due to multi-selection in tree"
	return
    }
    if {$state(pattern) == {}} {
	SetPType $path none
	SetError $path "Pattern is empty"
	return
    }
    # Further classification is done using file operations and
    # knowledge of the current selection.

    # Input (pattern)	Selected		Class (Pattern type)
    # -----------------------------------------------------------
    # Relative path	None			Error
    #			Alias under dir X	include under X
    #			File under X		ditto
    #			Directory X		ditto
    # Absolute path
    #	directory	None			Add base path
    #			Alias under dir X	ditto
    #			File under X		ditto
    #			Directory X		ditto
    #
    #	file		None			Error
    #			Alias under dir X	include under X, relative
    #			File under X		include under X, relative
    #			Directory X		include under x, relative
    # -----------------------------------------------------------

    if {![string equal relative [file pathtype $state(pattern)]]} {
	# Absolute path ...
	if {[file isdirectory $state(pattern)]} {
	    # Directory ...
	    SetPType $path directory
	} else {
	    # File ...
	    if {$state(selection) == {}} {
		# No selection ...
		SetPType $path none
		SetError $path "Cannot add absolute path to file without a base directory selected."
	    } else {
		# Bugzilla 23405.
		# Check that the path for the base directory
		# (selection, or parent thereof) is a prefix for the
		# file path (pattern).

		set strip [StripLeading [TrueBase [FindBase $path]] \
			$state(pattern)]

		if {[string equal $strip $state(pattern)]} {
		    # Unchanged, no true prefix, error
		    SetPType $path none
		    SetError $path "Cannot add absolute path to file, selected base directory does not match."
		} else {
		    SetPType $path include
		}
	    }
	}
    } else {
	# Relative path
	if {$state(selection) == {}} {
	    # No selection ...
	    SetPType $path none
	    SetError $path "cannot determine base directory for relative path"
	} else {
	    SetPType $path include
	}
    }

    return
}

# ------------------------------------------------------------------------------

# Given the path to a base directory it returns the true path to use
# when checking if a file can be added. The true path is normally the
# same as the input, except if the input string contains one of the
# placeholders. For them the system determines the equivalent path in
# the current installation and returns this for use by the checker.

proc ::tcldevkit::tape::fileWidget::TrueBase {fpath} {
    if {[string match @TAP_DIR@* $fpath]}        {
	set fpath [string map [list @TAP_DIR@ \
		[file dirname [::tape::state::getInputFile]] \
		] $fpath]
    } elseif {[string match @TDK_INSTALLDIR@* $fpath]} {
	set fpath [string map [list @TDK_INSTALLDIR@ \
		[file dirname [file dirname $starkit::topdir]] \
		] $fpath]
    } elseif {[string match @TDK_LIBDIR@* $fpath]}     {
	set fpath [string map [list @TDK_LIBDIR@ \
		[file join [file dirname [file dirname $starkit::topdir]] lib] \
		] $fpath]
    }
    return $fpath
}

# ------------------------------------------------------------------------------
# This command is an internal helper. It extracts the base path for
# the chosen entry from the data in the tree widget and returns it to
# the caller.

proc ::tcldevkit::tape::fileWidget::FindBase {path} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    set parent $state(selection)
    while {![string equal directory [$path.sw.t itemcget $parent -data]]} {
	set parent [$path.sw.t parent $parent]
    }
    set header [$path.sw.t itemcget $parent -text]
    return $header
}

# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::TrackPattern {path svar var idx op} {
    upvar #0 $svar state

    # Classify the contents of the entry widget (.e) and (de)activate
    # the buttons accordingly.

    ClassifyPattern $path
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::TrackSelection {path tree selection} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    set state(selection) $selection

    # Common states. Modified later on.
    $path.a  configure -state normal

    if {[llength $selection] == 0} {
	set state(seltype)   null

	$path.r   configure -state disabled
	$path.ed  configure -state disabled
	$path.up  configure -state disabled
	$path.dn  configure -state disabled
	$path.sa  configure -state disabled
	$path.tie configure -state disabled

	ClassifyPattern $path
	return
    }

    $path.r   configure -state normal
    $path.ed  configure -state normal

    if {[llength $selection] > 1} {
	set state(seltype)   multi
	$path.a   configure -state disabled
	$path.ed  configure -state disabled
	$path.up  configure -state disabled
	$path.dn  configure -state disabled
	$path.sa  configure -state disabled
	$path.tie configure -state disabled
	return
    }

    # One item is selected. Use type information to handle entry and
    # buttons.

    set selected [lindex $selection 0]
    set type     [$path.sw.t itemcget $selected -data]

    set state(seltype) $type
    switch -exact --   $type {
	alias {
	    set state(selctx) ""
	}
	include   -
	exclude   -
	directory {
	    set state(selctx) [$path.sw.t itemcget $selected -text]
	}
    }
    switch -exact --   $type {
	directory -
	alias {
	    $path.sa  configure -state disabled
	    $path.tie configure -state disabled
	}
	include   -
	exclude   {
	    $path.sa  configure -state normal
	    $path.tie configure -state normal
	}
    }
    ClassifyPattern $path
    HandleMoves     $path
    return
}

proc ::tcldevkit::tape::fileWidget::HandleMoves {path} {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    $path.up configure -state normal
    $path.dn configure -state normal

    # Check where the selected item is in the tree (top, bottom,
    # border files / packages ?) and use that information to decide
    # which of the two arrow buttons can be used.

    if {[string equal alias [$path.sw.t itemcget $state(selection) -data]]} {
	# Alias information can't be moved.
	$path.up configure -state disabled
	$path.dn configure -state disabled
    }

    set parent  [$path.sw.t parent $state(selection)]
    set loc     [$path.sw.t index  $state(selection)]

    # Item is a directory or pattern.

    if {[string equal $parent root]} {
	# Item is directory.

	set bottom [expr {[llength [$path.sw.t nodes $parent]]-1}]

	if {$loc == 0} {
	    # Item is at top, cannot move up.
	    $path.up configure -state disabled
	}
	if {$loc == $bottom} {
	    # Item is at bottom, cannot move down
	    $path.dn configure -state disabled
	}
    } else {
	if {$loc == 0} {
	    # Item is pattern at beginning of its directory. It can move
	    # up if and only if another directory comes before its parent.

	    set pparent  [$path.sw.t parent $parent]
	    set ploc     [$path.sw.t index  $parent]

	    if {$ploc == 0} {
		# Parent is at top, therefore file cannot move up.
		$path.up configure -state disabled
	    }

	    # Bugzilla 23383
	    # If the item is the only child in the directory it is also at
	    # the bottom, so we also have to check if the directory is at
	    # the bottom.

	    set bottom [expr {[llength [$path.sw.t nodes $parent]]-1}]
	}

	set bottom [expr {[llength [$path.sw.t nodes $parent]]-1}]

	if {$loc == $bottom} {
	    # Item is pattern at the end of its directory. It can move
	    # down if and only if another directory comes after its parent.

	    set pparent  [$path.sw.t parent $parent]
	    set ploc     [$path.sw.t index  $parent]
	    set bottom   [expr {[llength [$path.sw.t nodes $pparent]]-1}]

	    if {$ploc == $bottom} {
		# Directory is at bottom, therefore item cannot move down
		$path.dn configure -state disabled
	    }
	}
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::Add {path} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    if {[string equal [$path.a cget -state] disabled]} {
	return
    }

    # Depending on contents of entry widget and selection.
    #
    # Pattern type	Action
    #---------------------------------
    # unknown           We do not come here
    # none		ditto
    # directory		Add new base path under root.
    # include		Walk selection up until directory
    #			found, add path to that node.
    #---------------------------------
    # Information about this will be provided by ClassifyPattern.

    set label $state(pattern)
    switch -exact -- $state(ptype) {
	none - unknown {
	    return -code error "Illegal pattern type \"$state(ptype)\""
	}
	directory {set parent root}
	include {
	    set parent $state(selection)
	    while {![string equal directory [$path.sw.t itemcget $parent -data]]} {
		set parent [$path.sw.t parent $parent]
	    }
	    set header [$path.sw.t itemcget $parent -text]
	    set label  [StripLeading [TrueBase $header] $state(pattern)]
	}
    }

    AddEntry $path $parent $state(ptype) $label
    set state(pattern) ""
    Serialize $path
    return
}

proc ::tcldevkit::tape::fileWidget::PlaceHolders {fpath} {
    if {[string match @TAP_DIR@* $fpath]}        {return 1}
    if {[string match @TDK_INSTALLDIR@* $fpath]} {return 1}
    if {[string match @TDK_LIBDIR@* $fpath]}     {return 1}
    return 0
}


proc ::tcldevkit::tape::fileWidget::EditEntry {path} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    set new [$path.sw.t edit $state(selection) \
	    [$path.sw.t itemcget $state(selection) -text]]
    if {$new != {}} {
	set type [$path.sw.t itemcget $state(selection) -data]

	if {
	    ($type eq "directory") &&
	    ![file isdirectory $new] &&
	    ![PlaceHolders $new]
	} {
	    tk_dialog $path.err "Error" \
		    "A directory path (possibly \
		    containing placeholders) had \
		    to be entered here, but was \
		    not." \
		    error 0 Ok
	    return
	}

	$path.sw.t itemconfigure $state(selection) -text $new
    }

    Serialize $path
    return
}

proc ::tcldevkit::tape::fileWidget::Remove {path} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    $path.sw.t delete $state(selection)

    # We have to check if the removed entry was a directory, cause in
    # that case we have to reset the -relativeto context.

    # Bugzilla 19720 ...
    # seltype directory indicates that the selected entry declared a
    # selection context (-relativeto). We have to reset that context.
    # We always have to reset the selection type as after this
    # operation nothing is selected anymore.

    if {![string equal $state(seltype) alias]} {
	set state(selctx)  {}
    }
    set state(seltype)   null
    set state(selection) {}

    Serialize       $path
    ClassifyPattern $path
    return
}

proc ::tcldevkit::tape::fileWidget::MoveUp {path} {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    set node     $state(selection)
    set parent   [$path.sw.t parent $node]
    set loc      [$path.sw.t index  $node]

    # Movements to consider ...
    # - Alias           - Impossible, supression done by HandleMoves
    # - Directory       - Swap places with child coming before.
    # - File, 1st child - Move to end of child coming before the parent
    #                   = Jump from our directory to the previous directory
    #   File, else      - Swap places with child coming before.

    if {$loc > 0} {
	# Child somewhere im the middle. Just swap places with the one coming before.
	incr loc -1
	$path.sw.t move $parent $node $loc
    } else {
	# First child. Movement is possible only if the child is a
	# file in a directory, and that directory is not the first in
	# the whole list. In other words, there is a place we can jump
	# to.

	set  pparent [$path.sw.t parent $parent]
	set  ploc    [$path.sw.t index $parent]
	incr ploc -1
	set before [$path.sw.t nodes $pparent $ploc]
	$path.sw.t move $before $node end
    }
    HandleMoves $path
    Serialize   $path
    return
}

proc ::tcldevkit::tape::fileWidget::MoveDn {path} {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    # Movements to consider ...
    # - Alias           - Impossible, supression done by HandleMoves
    # - Directory       - Swap places with child coming after.
    # - File, 1st child - Move to beginning of child coming after the parent
    #                   = Jump from our directory to the next directory
    #   File, else      - Swap places with child coming after.

    set node $state(selection)
    set parent     [$path.sw.t parent $node]
    set loc    [$path.sw.t index  $node]
    set bottom [expr {[llength [$path.sw.t nodes $parent]]-1}]

    if {$loc < $bottom} {
	# Child somewhere im the middle. Just swap places with the one coming after.
	incr loc
	$path.sw.t move $parent $node $loc
    } else {
	set  pparent [$path.sw.t parent $parent]
	set  ploc    [$path.sw.t index $parent]
	incr ploc
	set after [$path.sw.t nodes $pparent $ploc]
	$path.sw.t move $after $node 0
    }
    HandleMoves $path
    Serialize   $path
    return
}

proc ::tcldevkit::tape::fileWidget::StripLeading {dirPath filePath} {
    set dirPath [file split $dirPath]
    set filePath [file split $filePath]

    for {set i 0} {$i < [llength $dirPath]} {incr i} {
	if {[lindex $dirPath $i] != [lindex $filePath $i]} {
	    break;
	}
    }
    if {$i == [llength $dirPath]} {
	# The list for 'dirPath' was exhausted, therefore 'dirPath' is truly
	# a complete leading subset of 'filePath'.

	set filePath [lrange $filePath $i end]
    }
    if {[llength $filePath] == 0} {
	return ""
    }
    return [eval file join $filePath]
}

proc ::tcldevkit::tape::fileWidget::BrowseFile {path} {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    if {$state(selection) != {}} {
	set type [$path.sw.t itemcget $state(selection) -data]
    } else {
	set type none
    }

    if {[string equal $type directory]} {
	# A base path is selected. Start in that directory.
	# Munge the result so that it is relative to the
	# directory too, if possible.

	set header [file join [pwd] $state(selctx)]
	set file [tk_getOpenFile \
		-title     "Select file to wrap" \
		-parent    $path \
		-filetypes {{Tcl {.tcl}} {All {*}}} \
		-initialdir $header \
		]

	set file [StripLeading $header $file]
    } else {
	set file [tk_getOpenFile \
		-title     "Select file to wrap" \
		-parent    $path \
		-filetypes {{Tcl {.tcl}} {All {*}}} \
		-initialdir $state(lastdir,file) \
		]
    }

    if {$file == {}} {return}
    set state(lastdir,file) [file dirname $file]

    # Browsing implies adding

    set state(pattern) $file
    if {$state(ok)} {Add $path}
    return
}

proc ::tcldevkit::tape::fileWidget::__BrowseDir {path} {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    if {$state(selection) != {}} {
	set type [$path.sw.t itemcget $state(selection) -data]
    } else {
	set type none
    }

    if {[string equal $type directory]} {
	# A base path is selected. Start in that directory.
	# Munge the result so that it is relative to the
	# directory too, if possible.

	set header [file join [pwd] $state(selctx)]

	set dir [tk_chooseDirectory \
	    -title    "Select directory" \
	    -parent    $path \
	    -mustexist true \
	    -initialdir $header \
	    ]

	set dir [StripLeading $header $dir]
    } else {
	set dir [tk_chooseDirectory \
	    -title    "Select directory" \
	    -parent    $path \
	    -mustexist true \
	    -initialdir $state(lastdir,dir) \
	    ]
    }
    return $dir
}

proc ::tcldevkit::tape::fileWidget::BrowseDir {path} {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    set dir [__BrowseDir $path]
    if {$dir == {}} {return}
    set state(lastdir,dir) [file dirname $dir]

    # Browsing implies adding

    set state(pattern) $dir
    if {$state(ok)} {Add $path}
    return
}

proc ::tcldevkit::tape::fileWidget::BrowseDirRec {path} {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    set dir [__BrowseDir $path]
    if {$dir == {}} {return}

    set state(lastdir,dir) [set base $dir]

    # Browsing implies adding

    set state(pattern) $base
    if {!$state(ok)} {return}
    Add $path

    # Adding the directory as base path was ok.
    # Now scan the directory for its files and add them all.

    #set bdir [file tail $dir]
    set parent $state(lastadded,item)

    foreach subfile [FindFilesRec $dir] {
	AddEntry $path $parent include $subfile
    }
    Serialize $path
    return
}

proc ::tcldevkit::tape::fileWidget::FindFilesRec {basepath} {
    set res [list]
    set n [llength [file split $basepath]]

    foreach f [::fileutil::find $basepath {file isfile}] {
	lappend res [::fileutil::stripN $f $n]
    }
    return $res
}


proc ::tcldevkit::tape::fileWidget::SetAlias {path} {
    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    # Create alias node, default is same label as parent, then ...

    set parent $state(selection)
    set alias [AddEntry $path $parent alias [$path.sw.t itemcget $parent -text]]

    # select the alias and start the editing of the label.
    $path.sw.t selection set $alias

    EditEntry $path
    return
}

proc ::tcldevkit::tape::fileWidget::ToggleInEx {path} {

    variable ::Widget::tcldevkit::tape::fileWidget::${path}::state

    set type [$path.sw.t itemcget $state(selection) -data]
    switch -exact -- $type {
	include {set type exclude}
	exclude {set type include}
    }
    $path.sw.t itemconfigure $state(selection) \
	    -data $type \
	    -image [Icon $type]

    Serialize $path
    return
}


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::Serialize {path} {
    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    # Copy any change in the tree down to the state object.

    set       bases [list]
    array set fmap {}

    foreach item [$path.sw.t nodes root] {
	### Known - Directories only
	### set type  [$path.sw.t itemcget $item -data]

	set base [$path.sw.t itemcget $item -text]

	## Collate identical base directories into one bin
	if {![info exists fmap(b,$base)]} {
	    lappend bases $base
	    set fmap(b,$base) [list]
	}

	## Scan patterns under the directory.

	foreach sub [$path.sw.t nodes $item] {
	    ### Known - Include / Exclude
	    set subtype  [$path.sw.t itemcget $sub -data]
	    set sublabel [$path.sw.t itemcget $sub -text]

	    lappend fmap(b,$base) [list $subtype $sublabel]

	    ## Check for alias associated with the pattern.

	    set alist [$path.sw.t nodes $sub]
	    # assert [llength $alist] in {0, 1}

	    if {[llength $alist] == 1} {
		set new [$path.sw.t itemcget [lindex $alist 0] -text]
		lappend fmap(b,$base) [list alias [list $sublabel $new]]
	    }
	}
    }

    UpCall $path set-base-directories $bases
    foreach b $bases {
	UpCall $path set-base-data $b $fmap(b,$b)
    }
    unset fmap
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::fileWidget::ClearTree {path} {
    # Unset all relevant state information, together with clearing
    # the tree.

    $path.sw.t selection clear
    $path.sw.t delete [$path.sw.t nodes root]
    TrackSelection $path {} {}
    return
}


proc ::tcldevkit::tape::fileWidget::Deserialize {path} {
    ClearTree $path

    upvar #0 ::Widget::tcldevkit::tape::fileWidget::${path}::state state

    set directories [UpCall $path get-base-directories]
    set fnum 0

    foreach d $directories {
	set parentdir  [AddEntry $path root directory $d]
	set dirdata    [UpCall $path get-base-data $d]
	array set map {}

	foreach dd $dirdata {
	    foreach {cmd detail} $dd { break }

	    set label $detail
	    if {[string equal $cmd alias]} {
		set parent $map([lindex $detail 0])
		set label [lindex $detail 1]
	    } else {
		set parent $parentdir
	    }
	    set map($detail) [AddEntry $path $parent $cmd $label]
	    incr fnum
	}
    }

    if {$fnum == 0} {
	# Warning -- "Files: Nothing to wrap"
    } else {
	# Ok
    }
    return
}

# ------------------------------------------------------------------------------


proc ::tcldevkit::tape::fileWidget::do {path cmd args} {
    log::log debug "$path $cmd ([join $args ") ("])"

    switch -exact -- $cmd {
	error@ {### Ignore ###}
	select {### Ignore ###}
	refresh-current {
	    # Get the newest file information and regenerate the tree.
	    Deserialize $path
	}
	no-current {
	    ClearTree $path
	}
    }
}


# ------------------------------------------------------------------------------
package provide tcldevkit::tape::fileWidget 2.0
