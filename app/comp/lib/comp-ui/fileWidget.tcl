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
# RCS: @(#) $Id:  Exp $
#
# ------------------------------------------------------------------------------

package require BWidget ; # BWidgets | Foundation for this mega-widget.
package require tipstack
package require widget::scrolledwindow
package require img::png
package require image ; image::file::here

# ------------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::compiler::fileWidget::create
#     - tcldevkit::compiler::fileWidget::destroy
#     - tcldevkit::compiler::fileWidget::configure
#     - tcldevkit::compiler::fileWidget::cget
#     - tcldevkit::compiler::fileWidget::setfocus
# ------------------------------------------------------------------------------

namespace eval ::tcldevkit::compiler::fileWidget {

    Widget::declare tcldevkit::compiler::fileWidget {
	{-variable	     String     ""     0}
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-errorbackground    Color     "lightyellow" 0}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
	{-padding	     String     ""     0}
    }

    Widget::addmap tcldevkit::compiler::fileWidget "" :cmd {-padding {}}
    Widget::addmap tcldevkit::compiler::fileWidget "" .f.list {-variable -listvariable}

    foreach w {.add .rem .browse .f.list} {
	Widget::addmap tcldevkit::compiler::fileWidget "" $w {
	    -background {} -foreground {} -font {}
	}
    }
    Widget::addmap tcldevkit::compiler::fileWidget "" .file {-foreground {} -font {}}

    proc ::tcldevkit::compiler::fileWidget {path args} {
	return [eval fileWidget::create $path $args]
    }
    proc use {} {}

    bind fileWidget <FocusIn> {::tcldevkit::compiler::fileWidget::setfocus %W}
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::fileWidget::create
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::fileWidget::create { path args } {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::compiler::fileWidget $path $args
    namespace eval ::Widget::tcldevkit::compiler::fileWidget::$path {}
    InitState    $path

    eval [list ttk::frame $path -class tcldevkit::compiler::fileWidget] \
	[Widget::subcget $path :cmd]

    set f [eval [list widget::scrolledwindow $path.f] \
	       [Widget::subcget $path .f] \
	       -borderwidth 1 -relief sunken -auto both -scrollbar vertical]

    bind real${path} <Destroy> {tcldevkit::compiler::fileWidget::destroy %W; rename %W {}}

    foreach {type w static_opts} {
	ttk::button  .add    {-text "Add" -state disabled}
	ttk::button  .rem    {-text "Remove"}
	ttk::button  .browse {-text "Browse..."}
	ttk::entry   .file   {}
	listbox .f.list {-bd 0 -highlightthickness 0}
    } {
	eval $type $path$w [Widget::subcget $path $w] $static_opts
	set tags [bindtags $path$w]
	bindtags $path$w [linsert $tags 1 $path]
    }

    $f setwidget $path.f.list

    $path.f.list configure -selectmode extended

    ::tcldevkit::appframe::setkey $path Return   [list ::tcldevkit::compiler::fileWidget::Add    $path]
    ::tcldevkit::appframe::setkey $path KP_Enter [list ::tcldevkit::compiler::fileWidget::Add    $path]
    ::tcldevkit::appframe::setkey $path Delete   [list ::tcldevkit::compiler::fileWidget::Remove $path]

    foreach {w cmd image} {
	.add    Add    add
	.rem    Remove delete
	.browse Browse file
    } {
	$path$w configure -command [list ::tcldevkit::compiler::fileWidget::$cmd $path] -image [image::get $image]
    }
    foreach {w opt key} {
	.file   -textvariable file
    } {
	$path$w configure $opt \
		::Widget::tcldevkit::compiler::fileWidget::${path}::state($key)
    }

    bindtags $path [list real${path} fileWidget [winfo toplevel $path] all]

    foreach {slave col row stick padx pady rspan cspan} {
	.browse 1 0  we  1m 1m 1 1
	.add    1 1  we  1m 1m 1 1
	.rem    1 2  wen 1m 1m 1 1
	.file   0 0 swen 1m 1m 1 1
	.f      0 1 swen 1m 1m 3 1
    } {
	grid $path$slave -column $col -row $row -rowspan $rspan -sticky $stick \
		-padx $padx -pady $pady -columnspan $cspan
    }
    foreach {master col weight} {
	{}   0 1
	{}   1 0
	{}   2 0
    } {
	grid columnconfigure $path$master $col -weight $weight
    }
    foreach {master row weight} {
	{} 0 0
	{} 1 0
	{} 2 0
	{} 3 1
    } {
	grid rowconfigure $path$master $row -weight $weight
    }

    tipstack::defsub $path {
	.add    {Add entry to list}
	.rem    {Remove selected items from list}
	.browse {Browse for file to compile}
	.file   {Enter file to compile}
	.f.list {List of files to compile}
    }

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::compiler::fileWidget::\$cmd $path \$args\]\
	    "
    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::fileWidget::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::fileWidget::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::compiler::fileWidget::${path}::state
    upvar #0 $svar                                            state

    if {[info exists state]} {
	# Remove internal traces
	trace vdelete ${svar}(file) w [list \
		::tcldevkit::compiler::fileWidget::Ok $path $svar]
	unset state
    }
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::fileWidget::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::fileWidget::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    eval [linsert $args 0 configure $path]
}

proc ::tcldevkit::compiler::fileWidget::configure { path args } {
    # addmap -option are already forwarded to their approriate subwidgets
    set res [Widget::configure $path $args]

    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::fileWidget::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::fileWidget::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::fileWidget::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::fileWidget::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::fileWidget::InitState { path } {
    set svar ::Widget::tcldevkit::compiler::fileWidget::${path}::state
    upvar #0 $svar                                            state

    array set state {file {} ok 1 errmsg {} use 0}
    set state(lastdir,file) [pwd]

    # Internal traces computing the ok/fail state of the entered information.

    trace variable ${svar}(file) w [list \
	    ::tcldevkit::compiler::fileWidget::Ok $path $svar]
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::fileWidget::Ok {path svar var idx op} {
    upvar #0 $svar state

    set use 0
    set ok  1
    set file $state(file)

    if {$file == {}} {
	set state(errmsg) ""
    } elseif {![file exists $file]} {
	set state(errmsg) "File does not exist: $file"
	set ok 0
    } elseif {![file isfile $file]} {
	set state(errmsg) "File is not a file: $file"
	set ok 0
    } elseif {![file readable $file]} {
	set ok 0
	set state(errmsg) "File is not readable: $file"
    } else {
	set state(errmsg) ""
	set use 1
    }

    set filevar [$path.f.list cget -listvariable]
    upvar #0 $filevar files
    if {[lsearch -exact $files $file] >= 0} {
	set state(errmsg) "File is already present: $file"
	set ok  0
	set use 0
    }

    if {!$ok} {
	$path.file state invalid
	tipstack::push $path.file $state(errmsg)
    } else {
	# TODO: entry-bg option
	$path.file state !invalid
	tipstack::pop $path.file
    }
    if {$use} {
	$path.add configure -state normal
    } else {
	$path.add configure -state disabled
    }

    set state(ok)  $ok
    set state(use) $use
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::fileWidget::Add {path} {
    set svar ::Widget::tcldevkit::compiler::fileWidget::${path}::state
    upvar #0 $svar                                            state

    # Can be invoked from a button or via key binding.
    # Because of the latter we have to check here if adding
    # is actually possible. The button is already disabled
    # if it is not. Actually we just query the button.

    if {[string equal [$path.add cget -state] disabled]} {
	return
    }

    $path.f.list insert 0 [file nativename $state(file)]
    set state(file) ""
    return
}

proc ::tcldevkit::compiler::fileWidget::Remove {path} {
    foreach idx [lsort -integer -decreasing [$path.f.list curselection]] {
	$path.f.list delete $idx
    }

    Ok $path ::Widget::tcldevkit::compiler::fileWidget::${path}::state __ __ w
    return
}

proc ::tcldevkit::compiler::fileWidget::Browse {path} {
    upvar #0 ::Widget::tcldevkit::compiler::fileWidget::${path}::state state

    set file [tk_getOpenFile \
	    -title     "Select file to compile" \
	    -parent    $path \
	    -filetypes {{Tcl {.tcl}} {All {*}}} \
	    -initialdir $state(lastdir,file) \
	    ]

    if {$file == {}} {return}
    set state(lastdir,file) [file dirname $file]

    # Browsing implies adding

    set state(file) $file
    if {$state(use)} {
	Add $path
    }
    return
}

# ------------------------------------------------------------------------------

package provide tcldevkit::compiler::fileWidget 2.0
