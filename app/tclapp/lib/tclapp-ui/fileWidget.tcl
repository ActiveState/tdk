# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# fileWidget.tcl --
#
#	This file implements the Run tab, a combination of
#	start-button and logging window.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# ------------------------------------------------------------------------------

package require BWidget  ; # BWidgets | Foundation for this mega-widget.
package require fileutil ; # Tcllib   | File finder ...
package require tclapp::pkg
package require img::png
package require image ; image::file::here
package require tipstack
package require widget::dialog

# ------------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::wrapper::fileWidget::create
#     - tcldevkit::wrapper::fileWidget::destroy
#     - tcldevkit::wrapper::fileWidget::configure
#     - tcldevkit::wrapper::fileWidget::cget
#     - tcldevkit::wrapper::fileWidget::setfocus
# ------------------------------------------------------------------------------

namespace eval ::tcldevkit::wrapper::fileWidget {
    Tree::use
    ScrolledWindow::use

    Widget::declare tcldevkit::wrapper::fileWidget {
	{-variable	     String     ""     0}
        {-errorbackground    Color     "#FFFFE0" 0}
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
    }

    Widget::addmap tcldevkit::wrapper::fileWidget "" :cmd    {-background {}}
    Widget::addmap tcldevkit::wrapper::fileWidget "" :item   {-foreground -fill -font {}}
    Widget::addmap tcldevkit::wrapper::fileWidget "" .sw     {-background {}}
    Widget::addmap tcldevkit::wrapper::fileWidget "" .sw.t   {-background {}}

    foreach w {
	.e .a .r .bf .bd .bdr .st
    } {
	Widget::addmap tcldevkit::wrapper::fileWidget "" $w {
	    -background {} -foreground {} -font {}
	}
    }

    proc ::tcldevkit::wrapper::fileWidget {path args} {
	return [eval fileWidget::create $path $args]
    }
    proc use {} {}

    bind fileWidget <FocusIn> {::tcldevkit::wrapper::fileWidget::setfocus %W}

    # Widget class data
    set ::Widget::tcldevkit::wrapper::fileWidget::keymap {
	files     files
	fok       files,ok
	files,msg files,msg
	pkgs      pkgs
	app       app
    }
    set ::Widget::tcldevkit::wrapper::fileWidget::keymap_r {
	files     files
	files,ok  fok
	files,msg files,msg
	pkgs      pkgs
	app       app
    }

    variable checker ""
    variable pings 0
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::fileWidget::create
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::create { path args } {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::wrapper::fileWidget $path $args
    namespace eval ::Widget::tcldevkit::wrapper::fileWidget::$path {}

    InitState                     $path
    ValidateStoreVariable         $path
    set main_opt [Widget::subcget $path :cmd]

    eval [list ttk::frame $path -class tcldevkit::wrapper::fileWidget] \
	$main_opt

    ## Scrolled Tree Window
    set f [eval [list ScrolledWindow::create $path.sw] \
	       [Widget::subcget $path .sw] \
	       -managed 0 -ipad 0 -relief sunken -bd 1]
    set t [eval [list Tree::create $path.sw.t] [Widget::subcget $path .sw.t] \
	       -borderwidth 1 -relief flat -height 20 -deltay 18 \
	       -dragenabled 0 -dropenabled 0 -linestipple gray50 \
	       -selectcommand [list [list ::tcldevkit::wrapper::fileWidget::TrackSelection $path]]]
    $f setwidget $t

    bind real${path} <Destroy> {tcldevkit::wrapper::fileWidget::destroy %W; rename %W {}}

    set sub {
	ttk::button  .a   {-text "Add" -state disabled}
	ttk::button  .r   {-text "Remove"}
	ttk::button  .ed  {-text "Edit"}
	ttk::button  .bf  {-text "Browse... (F)"}
	ttk::button  .bd  {-text "Browse... (D)"}
	ttk::button  .bdr {-text "Browse... (D/rec)"}
	ttk::button  .st  {-text "Set Main"}
	ttk::entry   .e   {}
	ttk::label   .pt  {-text ""}
	ttk::button  .up {}
	ttk::button  .dn {}
    }
    foreach {type w static_opts} $sub {
	eval $type $path$w [Widget::subcget $path $w] $static_opts
	set tags [bindtags $path$w]
	bindtags $path$w [linsert $tags 1 $path]
    }

    ::tcldevkit::appframe::setkey $path Return   [list ::tcldevkit::wrapper::fileWidget::Add    $path]
    ::tcldevkit::appframe::setkey $path KP_Enter [list ::tcldevkit::wrapper::fileWidget::Add    $path]
    ::tcldevkit::appframe::setkey $path Delete   [list ::tcldevkit::wrapper::fileWidget::Remove $path]
    ::tcldevkit::appframe::setkey $path Up       [list ::tcldevkit::wrapper::fileWidget::MoveUp $path]
    ::tcldevkit::appframe::setkey $path Down     [list ::tcldevkit::wrapper::fileWidget::MoveDn $path]

    foreach {w cmd image} {
	.a   Add          add
	.r   Remove       delete
	.ed  EditEntry    {}
	.bf  BrowseFile   file
	.bd  BrowseDir    directory
	.bdr BrowseDirRec directory_rec
	.st  MarkStartup  {}
	.up  MoveUp       up
	.dn  MoveDn       down
    } {
	$path$w configure -command [list ::tcldevkit::wrapper::fileWidget::$cmd $path]
	if {$image != {}} {$path$w configure -image [image::get $image]}
    }
    foreach {w opt key} {
	.e   -textvariable pattern
    } {
	$path$w configure $opt \
		::Widget::tcldevkit::wrapper::fileWidget::${path}::state($key)
    }

    bindtags $path [list real${path} fileWidget [winfo toplevel $path] all]

    foreach {slave col row stick padx pady cspan rspan} {
	.pt   0 0  swen  1m 1m 1 1

	.up   0 1   e  1m 1m 1 1
	.dn   0 2   e  1m 1m 1 1

	.bf   2 0  wen 1m 1m 1 1
	.bd   3 0  wen 1m 1m 1 1
	.bdr  4 0  wen 1m 1m 1 1
	.a    2 1  wn  1m 1m 4 1
	.r    2 2  wn  1m 1m 4 1
	.st   2 3  wen 1m 1m 4 1
	.ed   2 4  wen 1m 1m 4 1

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
	{} 5 0
	{} 6 1
    } {
	grid rowconfigure $path$master $row -weight $weight
    }

    tipstack::defsub $path {
	.a   {Add entry to list of files to wrap}
	.r   {Remove selected items from list}
	.ed  {Change the contents of the selected file or directory item}
	.bf  {Browse for file to wrap}
	.bd  {Set base directory containing files to wrap}
	.bdr {Wrap all files found under directory}
	.st  {Mark selected item as the main file of the application}
	.e   {Enter file, directory, or glob pattern for wrapping}
	.sw  {List of files to wrap}
	.pt  {Type of current contents of the entry}
	.up  {}
	.dn  {}
    }

    # No help for these two buttons as it covers the item to be moved
    # 90% of the time, very bad.
    #	.up  {Move the selected item one row up}
    #	.dn  {Move the selected item one row down}

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::wrapper::fileWidget::\$cmd $path \$args\]\
	    "

    TrackSelection $path {} {} ; # Initialize selection tracking.
    Serialize      $path       ; # First export of configuration

    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::fileWidget::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::linkvar linkvar
    upvar #0 $svar                                            state

    if {[info exists linkvar]} {
	if {$linkvar != {}} {
	    # Remove the traces for linked variable, if existing
	    trace vdelete $linkvar w [list \
		    ::tcldevkit::wrapper::fileWidget::TraceIn $path $linkvar]
	    trace vdelete $svar    w [list \
		    ::tcldevkit::wrapper::fileWidget::TraceOut $path $svar]
	}
	unset linkvar
    }
    if {[info exists state]} {
	# Remove internal traces
	trace vdelete ${svar}(pattern) w [list \
		::tcldevkit::wrapper::fileWidget::TrackPattern $path $svar]
	unset state
    }
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::fileWidget::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    eval [linsert $args 0 configure $path]
}

proc ::tcldevkit::wrapper::fileWidget::configure { path args } {
    # addmap -option are already forwarded to their approriate subwidgets
    set res [Widget::configure $path $args]
    # Handle -errorbackground.

    if {[Widget::hasChanged $path -errorbackground ebg]} {
	return ; # tile works on themes/states
	upvar #0 ::Widget::tcldevkit::compiler::fileWidget::${path}::state state

	if {!$state(ok)} {$path.e configure -bg $ebg}
    }
    if {[Widget::hasChanged $path -variable dummy]} {
	ValidateStoreVariable $path
    }
    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::fileWidget::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::fileWidget::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::ValidateStoreVariable { path } {

    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::linkvar linkvar

    set newvar [Widget::getoption $path -variable]
    if {[string equal $newvar $linkvar]} {
	# -variable unchanged.
	return
    }

    # -variable was changed.

    if {$newvar == {}} {
	# The variable was disconnected from the widget. Remove the traces.

	trace vdelete $linkvar w [list \
		::tcldevkit::wrapper::fileWidget::TraceIn $path $linkvar]
	trace vdelete $svar    w [list \
		::tcldevkit::wrapper::fileWidget::TraceOut $path $svar]

	set linkvar ""
	return
    }

    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

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
		::tcldevkit::wrapper::fileWidget::TraceIn $path $newvar]
	trace variable $svar   w [list \
		::tcldevkit::wrapper::fileWidget::TraceOut $path $svar]

	set linkvar $newvar
	return
    }

    # Changed from one variable to the other. Remove old traces, setup
    # new ones, copy relevant information of state!

    trace vdelete $linkvar w [list \
	    ::tcldevkit::wrapper::fileWidget::TraceIn $path $linkvar]
    trace vdelete $svar    w [list \
	    ::tcldevkit::wrapper::fileWidget::TraceOut $path $svar]

    CopyState $path $newvar

    trace variable $newvar w [list \
	    ::tcldevkit::wrapper::fileWidget::TraceIn $path $linkvar]
    trace variable $svar   w [list \
	    ::tcldevkit::wrapper::fileWidget::TraceOut $path $svar]

    set linkvar $newvar
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::CopyState { path var } {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::keymap         map
    upvar #0 $var                                                     data
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    foreach {inkey exkey} $map {
	set data($exkey) $state($inkey)
    }
    return
}

proc ::tcldevkit::wrapper::fileWidget::InitState { path } {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::linkvar linkvar
    upvar #0 $svar                                                      state

    set linkvar ""
    array set state {
	counter 0
	ptype   none pattern {}
	seltype null selctx  {}
	ok      0    msg     {}
	startup {}
	startup,type {}
	files   {}   fok     0 files,msg {}
	trace   {}
	pkgs    {}
	app     {}
	pkgerrs {}
    }

    set state(lastdir,dir)  [pwd]
    set state(lastdir,file) [pwd]

    # Ensure that we have tap error messages.

    ::tclapp::pkg::Initialize

    # Internal traces computing the ok/fail state of the entered information.

    trace variable ${svar}(pattern) w [list \
	    ::tcldevkit::wrapper::fileWidget::TrackPattern $path $svar]
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::TraceIn { path tvar var idx op } {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state   state

    # Lock out TraceIn if it is done in response to a change in the widget itself.
    if {[string equal $state(trace) out]} {return}

    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::keymap_r  map_r
    upvar #0 $tvar                                                data

    ##puts "TraceIn { $path $var /$idx/ $op }"

    array set tmp $map_r
    if {[info exists tmp($idx)]} {set inkey $tmp($idx)} else {return}
    set state($inkey) $data($idx)

    if {
	[string equal $inkey files] ||
	[string equal $inkey app] ||
	[string equal $inkey pkgs]
    } {
	Deserialize $path
    }
    return
}

proc ::tcldevkit::wrapper::fileWidget::TraceOut { path tvar var idx op } {
    upvar #0 $tvar                                                      state
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::keymap           map
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::linkvar linkvar
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

proc ::tcldevkit::wrapper::fileWidget::Tag {path} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                           state

    set     tag [incr state(counter)]
    return $tag
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::AddEntry {path parent type text {where end}} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    set newitem [Tag $path]
    eval $path.sw.t insert $where $parent $newitem \
	    [Widget::subcget $path :item] \
	    -drawcross auto -data $type \
	    -image [image::get $type] -text [list $text]

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

namespace eval ::tcldevkit::wrapper::fileWidget {
    variable  pthelp
    array set pthelp {
	none      {Unable to classify contents of entry field}
	unknown   {Unable to classify contents of entry field}
	file      {The contents of the entry are a path to a file}
	glob      {The contents of the entry are a glob pattern}
	directory {The contents of the entry are a path to a directory}
    }
}

proc ::tcldevkit::wrapper::fileWidget::SetPType {path type} {
    variable pthelp
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                              state

    # package, pkg_app is not possible

    switch -exact -- $type {
	none      -
	unknown   {$path.pt configure -text " " -image {}}
	package   -
	pkg_app   -
	file      -
	glob      -
	directory {$path.pt configure -image [image::get $type]}
	default   {return -code error "Unknown pattern type \"$type\""}
    }
    set state(ptype) $type

    tipstack::pop $path.pt
    if {[info exists pthelp($type)]} {
	tipstack::push $path.pt $pthelp($type)
    }
    return
}

proc ::tcldevkit::wrapper::fileWidget::SetMsg {path msg} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                           state

    set state(msg) $msg

    if {$msg == {}} {
	tipstack::pop $path.e
    } else {
	tipstack::push $path.e $msg
    }
    return
}

proc ::tcldevkit::wrapper::fileWidget::SetError {path msg} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                           state

    $path.a configure -state disabled
    $path.e state invalid
    SetMsg $path $msg
    set state(ok)  0
    return
}

proc ::tcldevkit::wrapper::fileWidget::ClearError {path} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                           state

    $path.e state !invalid
    $path.a configure -state normal
    SetMsg $path ""
    set state(ok)  1
    return
}

proc ::tcldevkit::wrapper::fileWidget::ClassifyPattern {path} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                           state

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

    switch -exact -- $state(seltype) {
	null - file - glob - startup - package - pkg_app {
	    # No selection, or files, or patterns, or packages => New entries go into level 0 (no -relativeto).

	    if {[file exists $state(pattern)]} {
		# Is a regular path, distinguish files and directories.
		if {[file isdirectory $state(pattern)]} {
		    SetPType $path directory
		} elseif {[file isfile $state(pattern)]} {
		    SetPType $path file
		} else {
		    SetPType $path unknown
		    SetError $path "Cannot determine path type"
		}
	    } else {
		SetPType $path glob
		# TODO : - future - Match pattern and see if there are files
	    }
	}
	directory {
	    # The file and/or pattern have to be relative and are
	    # interpreted in the context of the chosen directory.
	    # directories are not allowed !

	    if {[string equal absolute [file pathtype $state(pattern)]]} {
		SetPType $path unknown
		SetError $path "Absolute path not allowed in -relativeto context."
		return
	    }

	    set file [file join $state(selctx) $state(pattern)]

	    if {[file exists $file]} {
		# Is a regular path, distinguish files and directories.
		if {[file isdirectory $file]} {
		    SetPType $path directory
		    SetError $path "Directory not allowed in -relativeto context."
		} elseif {[file isfile $file]} {
		    SetPType $path file
		} else {
		    SetPType $path unknown
		    SetError $path "Cannot determine path type"
		}
	    } else {
		SetPType $path glob
		# TODO : -future - Match pattern and see if there are files
	    }
	}
	default {
	    return -code error "Illegal item type \"$state(seltype)\""
	}
    }
    return
}

proc ::tcldevkit::wrapper::fileWidget::TrackPattern {path svar var idx op} {
    upvar #0 $svar state

    # Classify the contents of the entry widget (.e) and (de)activate
    # the buttons accordingly.

    ClassifyPattern $path
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::TrackSelection {path tree selection} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                           state

    set state(selection) $selection

    # Common states. Modified later on.
    $path.a  configure -state normal
    $path.st configure -state disabled

    if {[llength $selection] == 0} {
	set state(seltype)   null
	set state(selctx)    ""

	$path.r  configure -state disabled
	$path.ed configure -state disabled
	$path.up configure -state disabled
	$path.dn configure -state disabled

	ClassifyPattern $path
	return
    }

    $path.r  configure -state normal
    $path.ed configure -state normal

    if {[llength $selection] > 1} {
	set state(seltype)   multi
	set state(selctx)    ""
	$path.a  configure -state disabled
	$path.ed configure -state disabled
	$path.up configure -state disabled
	$path.dn configure -state disabled
	return
    }

    # One item is selected. Use type information to handle entry and
    # buttons.

    set selected [lindex $selection 0]
    set type     [$path.sw.t itemcget $selected -data]

    set state(seltype) $type
    switch -exact --   $type {
	file - package {
	    $path.st configure -state normal
	    set state(selctx) ""
	}
	glob - startup - pkg_app {
	    set state(selctx) ""
	}
	directory {
	    set state(selctx) [$path.sw.t itemcget $selected -text]
	}
    }
    switch -exact -- $type {
	package - pkg_app {
	    # Package names cannot be altered.
	    $path.ed configure -state disabled
	}
    }
    ClassifyPattern $path
    HandleMoves     $path
    return
}

proc ::tcldevkit::wrapper::fileWidget::HandleMoves {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    $path.up configure -state normal
    $path.dn configure -state normal

    # Check where the selected item is in the tree (top, bottom,
    # border files / packages ?) and use that information to decide
    # which of the two arrow buttons can be used.

    set in  [$path.sw.t parent $state(selection)]
    set loc [$path.sw.t index  $state(selection)]

    if {[string equal $in root]} {
	# Item is either directory or package.
	set bottom [expr {[llength [$path.sw.t nodes $in]]-1}]
	set iam    [TypeClass [$path.sw.t itemcget $state(selection) -data]]

	if {$loc == 0} {
	    # Item is at top, cannot move up.
	    $path.up configure -state disabled
	} else {
	    # Check if item is different class than item above
	    # If so it is at the package/file border it cannot cross.

	    set before [$path.sw.t nodes $in [expr {$loc - 1}]]
	    set bis [TypeClass [$path.sw.t itemcget $before -data]]
	    if {![string equal $iam $bis]} {
		$path.up configure -state disabled
	    }
	}
	if {$loc == $bottom} {
	    $path.dn configure -state disabled
	    # Item is a bottom, cannot move down
	} else {
	    # Check if item is different class than item below.
	    # If so it is at package/file border it cannot cross.

	    set after [$path.sw.t nodes $in [expr {$loc + 1}]]
	    set ais [TypeClass [$path.sw.t itemcget $after -data]]
	    if {![string equal $iam $ais]} {
		$path.dn configure -state disabled
	    }
	}
    }
    return
}

proc ::tcldevkit::wrapper::fileWidget::TypeClass {itemtype} {
    switch -exact -- $itemtype {
	directory - 
	startup   -
	glob      -
	file      {return file}
	package   -
	pkg_app   {return package}
    }
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::Add {path} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                            state

    if {[string equal [$path.a cget -state] disabled]} {
	return
    }

    # Depending on contents of entry widget and selection.
    # seltype IN {null,directory}
    #
    # null => ptype IN {file, glob, directory}
    #         MAP ptype => item type
    #             file      => file
    #             glob      => glob
    #             directory => directory
    #
    # directory => ptype IN {file, glob}, item type === file.

    switch -exact -- $state(ptype) {
	none - unknown {
	    return -code error "Illegal pattern type \"$state(ptype)\""
	}
    }
    switch -exact -- $state(seltype) {
	null - file - startup - glob - package - pkg_app {set parent root}
	directory                    {set parent [lindex $state(selection) 0]}
	multi {
	    return -code error "Illegal selection type \"$state(seltype)\""
	}
    }

    AddEntry $path $parent $state(ptype) $state(pattern)
    set state(pattern) ""
    Serialize $path
    return
}

proc ::tcldevkit::wrapper::fileWidget::EditEntry {path} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                            state

    ## TODO : After editing the entry 
    ##        recompute the image to display
    ##        Also : Recheck the validity of the contents of the entry,
    ##               and signal problems if there are any (through an
    ##               error image)

    set new [$path.sw.t edit $state(selection) \
	    [$path.sw.t itemcget $state(selection) -text]]
    if {$new != {}} {
	$path.sw.t itemconfigure $state(selection) -text $new
	Serialize $path
    }
    return
}

proc ::tcldevkit::wrapper::fileWidget::Remove {path} {
    set svar ::Widget::tcldevkit::wrapper::fileWidget::${path}::state
    upvar #0 $svar                                            state

    # We have to reset 'startup' information if the removed entry
    # was marked as such.

    # Bug 86610 - We have to do the same if the node to be deleted is
    # an (indirect) parent. The easiest way to handle this is to check
    # if the node is gone after the deletion or not.

    $path.sw.t delete $state(selection)

    if {($state(startup) ne {}) && ![$path.sw.t exists $state(startup)]} {
	set state(startup)      {}
	set state(startup,type) {}
    }

    # We have to check if the removed entry was a directory, because
    # in that case we have to reset the -relativeto context.

    # Bugzilla 19720 ...
    # seltype directory indicates that the selected entry declared a
    # selection context (-relativeto). We have to reset that context.
    # We always have to reset the selection type as after this
    # operation nothing is selected anymore.

    if {[string equal $state(seltype) directory]} {
	set state(selctx)  {}
    }
    set state(seltype)   null
    set state(selection) {}

    Serialize $path
    return
}

proc ::tcldevkit::wrapper::fileWidget::MoveUp {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    if {[string equal [$path.up cget -state] disabled]} {
	return
    }

    set node $state(selection)
    set in   [$path.sw.t parent $node]
    set loc  [$path.sw.t index  $node]

    if {$loc > 0} {
	# If the entry above ourselves is a directory we move
	# into that node, and add us to the end of its list.
	# Not for directories, they just swap.

	incr loc -1

	if {![string equal directory [$path.sw.t itemcget $node -data]]} {
	    set before [$path.sw.t nodes $in $loc]
	    if {[string equal directory [$path.sw.t itemcget $before -data]]} {
		set in $before
		set loc end
	    }
	}
	$path.sw.t move $in $node $loc
    } else {
	# Move into the outer parent
	set pin   [$path.sw.t parent $in]
	set ploc  [$path.sw.t index  $in]

	$path.sw.t move $pin $node $ploc
    }
    HandleMoves $path
    return
}

proc ::tcldevkit::wrapper::fileWidget::MoveDn {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    if {[string equal [$path.dn cget -state] disabled]} {
	return
    }

    set node $state(selection)
    set in     [$path.sw.t parent $node]
    set loc    [$path.sw.t index  $node]
    set bottom [expr {[llength [$path.sw.t nodes $in]]-1}]

    if {$loc < $bottom} {
	# If the entry below ourselves is a directory
	# we add us to the beginning of its list of
	# children. Not for directories, they just swap.

	incr loc
	if {![string equal directory [$path.sw.t itemcget $node -data]]} {
	    set after [$path.sw.t nodes $in $loc]
	    if {[string equal directory [$path.sw.t itemcget $after -data]]} {
		set in $after
		set loc 0
	    }
	}
	$path.sw.t move $in $node $loc
    } else {
	# Move into the outer parent
	set pin   [$path.sw.t parent $in]
	set ploc  [$path.sw.t index  $in]
	incr ploc
	$path.sw.t move $pin $node $ploc
    }
    HandleMoves $path
    return
}

proc ::tcldevkit::wrapper::fileWidget::BrowseFile {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    if {$state(selctx) != {}} {
	# A -relativeto spec is selected. Start in that directory.
	# Munge the result so that it is relative to the directory too, if
	# possible.

	set header [file join [pwd] $state(selctx)]
	set filelist [tk_getOpenFile \
		-title     "Select file to wrap" \
		-parent    $path \
		-filetypes {{Tcl {.tcl}} {All {*}}} \
		-initialdir $header \
		-multiple 1 \
		]

	set res [list]
	foreach f $filelist {
	    lappend res [fileutil::stripPath $header $f]
	}
	set filelist $res
    } else {
	set filelist [tk_getOpenFile \
		-title     "Select file to wrap" \
		-parent    $path \
		-filetypes {{Tcl {.tcl}} {All {*}}} \
		-initialdir $state(lastdir,file) \
		-multiple 1 \
		]
    }

    if {[llength $filelist] == 0} {return}
    set state(lastdir,file) [file dirname [lindex $filelist end]]

    # Browsing implies adding. Have to handle multiple files.
    # Files which generate errors are ignored. If the last file in the
    # list causes an error it stays in the entry field. Previous files
    # causing an error cannot be seen.

    foreach f $filelist {
	set state(pattern) $f
	if {$state(ok)} {Add $path}
    }
    return
}

proc ::tcldevkit::wrapper::fileWidget::__BrowseDir {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    if {$state(selctx) != {}} {
	# A -relativeto spec is selected. Start in that directory.
	# Munge the result so that it is relative to the directory too, if
	# possible.

	set header [file join [pwd] $state(selctx)]

	set dir [tk_chooseDirectory \
	    -title    "Select directory" \
	    -parent    $path \
	    -mustexist true \
	    -initialdir $header \
	    ]

	set dir [fileutil::stripPath $header $dir]
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

proc ::tcldevkit::wrapper::fileWidget::BrowseDir {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    set dir [__BrowseDir $path]
    if {$dir == {}} {return}
    set state(lastdir,dir) [file dirname $dir]

    # Browsing implies adding

    set state(pattern) $dir
    if {$state(ok)} {Add $path}
    return
}

proc ::tcldevkit::wrapper::fileWidget::BrowseDirRec {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    set dir [__BrowseDir $path]
    if {$dir == {}} {return}

    set state(lastdir,dir) [set base [file dirname $dir]]

    # Browsing implies adding

    set state(pattern) $base
    if {!$state(ok)} {return}
    Add $path

    # Adding the directory as relative context was ok.
    # Now scan the directory for its files and add them all.

    set bdir [file tail $dir]
    set parent $state(lastadded,item)

    foreach subfile [FindFilesRec $dir] {
	AddEntry $path $parent file [file join $bdir $subfile]
    }
    Serialize $path
    return
}

proc ::tcldevkit::wrapper::fileWidget::FindFilesRec {basepath} {
    set res [list]
    set n [llength [file split $basepath]]

    foreach f [::fileutil::find $basepath {file isfile}] {
	lappend res [::fileutil::stripN $f $n]
    }
    return $res
}

proc ::tcldevkit::wrapper::fileWidget::MarkStartup {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    # seltype === file|startup|package KNOWN

    set selected [lindex $state(selection) 0]

    if {[string equal $selected $state(startup)]} {
	# No change, ignore call
	return
    }
    MarkStartupNode $path $selected

    # Update internal structure.
    Serialize $path

    # disable the button we used, as now the selection is marked
    $path.st configure -state disabled
    return
}

proc ::tcldevkit::wrapper::fileWidget::MarkStartupNode {path node} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    # pkg_app not possible anymore (wrapper diverts to new pkg mgmt).

    if {$state(startup) != {}} {
	$path.sw.t itemconfigure $state(startup) \
		-data  $state(startup,type) \
		-image [image::get $state(startup,type)]
    }
    set state(startup)      $node
    set state(startup,type) [$path.sw.t itemcget $node -data]

    if {
	[string equal $state(startup,type) file] ||
	[string equal $state(startup,type) glob]
    } {
	set newtype startup
    } else {
	set newtype pkg_app
    }
    $path.sw.t itemconfigure $node -data $newtype -image [image::get $newtype]
    return
}


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::Serialize {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    # Files & packages.

    set pkgs [list]
    set res  [list]
    set app  ""

    foreach item [$path.sw.t nodes root] {
	set type  [$path.sw.t itemcget $item -data]
	set label [$path.sw.t itemcget $item -text]

	# Simple serialization, without nested structures.
	# Files first, then relativeto information.
	switch -exact -- $type {
	    directory   {#ignore}
	    startup     {
		lappend res [list File      $label]
		lappend res Startup ; # Mark preceding file
	    }
	    glob - file {
		lappend res [list File      $label]
	    }
	    package {
		lappend pkgs $label
	    }
	    pkg_app {
		set     app  $label
	    }
	}
    }
    foreach item [$path.sw.t nodes root] {
	set type  [$path.sw.t itemcget $item -data]
	set label [$path.sw.t itemcget $item -text]

	switch -exact -- $type {
	    package     -
	    pkg_app     -
	    startup     -
	    glob        -
	    file        {#ignore}
	    directory   {
		lappend res [list Relativeto $label]

		foreach sitem [$path.sw.t nodes $item] {
		    set stype  [$path.sw.t itemcget $sitem -data]
		    set slabel [$path.sw.t itemcget $sitem -text]

		    lappend res [list File [file join $label $slabel]]
		    if {[string equal $stype startup]} {
			lappend res Startup
		    }
		}
	    }
	}
    }

    set state(files) $res
    set state(pkgs)  $pkgs
    set state(app)   $app

    if {
	([llength $res]  == 0) &&
	([llength $pkgs] == 0) &&
	([string equal $app ""])
    } {
	set state(files,msg) "Files: Nothing to wrap"
	set state(fok)       0
    } else {
	set state(files,msg) ""
	set state(fok)       1
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::Deserialize {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::fileWidget::${path}::state state

    # Unset all relevant state information, together with clearing
    # the tree.

    $path.sw.t selection clear
    TrackSelection $path {} {}

    $path.sw.t delete [$path.sw.t nodes root]
    set state(startup) {}
    set state(startup,type) {}

    # Local transient context for building up the tree.
    set parent     root ; # Node to add files to.
    set last       ""   ; # Node for last added file or package.
    set prefixpath ""
    array set map  {}
    set startup    "" ; # Node of startup file.

    foreach p $state(pkgs) {
	AddEntry $path root package $p
    }
    if {$state(app) != {}} {
	set appnode [AddEntry $path root package $state(app)]
	MarkStartupNode $path $appnode
    }

    foreach item $state(files) {
	foreach {cmd arg} $item { break }

	switch -exact -- $cmd {
	    Anchor     {## FIXME ## TODO ## NYI}
	    Alias      {## FIXME ## TODO ## NYI}
	    Relativeto {
		set parent     [AddEntry $path root directory $arg]
		set prefixpath $arg
	    }
	    File {
		if {![string equal $parent root]} {
		    # Strip path prefix
		    set file [fileutil::stripPath $prefixpath $arg]
		} else {
		    set file $arg
		}
		if {[file exists $arg]} {
		    set type file
		} else {
		    set type glob
		}
		set last [AddEntry $path $parent $type $file]
	    }
	    Startup    {
		# Last file is startup. Remember node for marking.
		set startup $last
	    }
	    default {
		return -code error "Internal error: unknown Path subcommand: $cmd"
	    }
	}
    }

    # App has precedence over Startup.

    if {($state(app) == {}) && ($startup != {})} {
	MarkStartupNode $path $startup
    }

    if {
	([llength $state(files)] == 0) &&
	([llength $state(pkgs)]  == 0)
    } {
	set state(files,msg) "Files: Nothing to wrap"
	set state(fok)       0
    } else {
	set state(files,msg) ""
	set state(fok)       1
    }

    # Report the data. This enforces that the data that goes out
    # during a configuration write is the formatted list, and not the
    # possibly non-formatted string we got in.
    #
    # Serialize $path
    return
}

# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::fileWidget::RemovePathPrefix {headpath path} {
    # Remove a path prefix from an absolute path and return the
    # generated relative path.

    global tcl_platform
    if {[string equal $tcl_platform(platform) windows]} {
	set headpath [string tolower $headpath]
	set path     [string tolower $path]
    }

    if {[regsub ^$headpath $path {} path]} {
	regsub ^/        $path {} path
    }
    return $path
}

# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
package provide tcldevkit::wrapper::fileWidget 1.0
