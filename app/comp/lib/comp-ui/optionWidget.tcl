# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# optionWidget.tcl --
#
#	This file implements a execution widget, a combination of
#	start-button and logging window.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# -----------------------------------------------------------------------------

package require BWidget ; # BWidgets | Foundation for this mega-widget.
package require tipstack
package require img::png
package require image ; image::file::here

# -----------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::compiler::optionWidget::create
#     - tcldevkit::compiler::optionWidget::destroy
#     - tcldevkit::compiler::optionWidget::configure
#     - tcldevkit::compiler::optionWidget::cget
#     - tcldevkit::compiler::optionWidget::setfocus
# -----------------------------------------------------------------------------

namespace eval ::tcldevkit::compiler::optionWidget {
    Widget::declare tcldevkit::compiler::optionWidget {
	{-variable	     String     ""     0}
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-errorbackground    Color     "lightyellow" 0}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
	{-padding	     String     ""     0}
    }

    Widget::addmap tcldevkit::compiler::optionWidget "" :cmd {-padding {}}

    foreach w {
	.force .out .out.b .pfx
	.pfx.rn .pfx.ra .pfx.rt .pfx.rp .pfx.b
    } {
	Widget::addmap tcldevkit::compiler::optionWidget "" $w {
	    -background {} -foreground {} -font {}
	}
    }
    Widget::addmap tcldevkit::compiler::optionWidget "" .out.e {-foreground {} -font {}}
    Widget::addmap tcldevkit::compiler::optionWidget "" .pfx.e {-foreground {} -font {}}


    proc ::tcldevkit::compiler::optionWidget {path args} {
	return [eval optionWidget::create $path $args]
    }
    proc use {} {}

    bind optionWidget <FocusIn> {::tcldevkit::compiler::optionWidget::setfocus %W}

    # Widget class data
    set ::Widget::tcldevkit::compiler::optionWidget::keymap {
	force    force
	pfx      prefix
	pfx,path prefix,path
	out      out
	ok       ok
	errmsg   errmsg
    }
    set ::Widget::tcldevkit::compiler::optionWidget::keymap_r {
	force       force
	prefix	    pfx
	prefix,path pfx,path
	out	    out
	ok	    ok
	errmsg	    errmsg
    }
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::compiler::optionWidget::create
# -----------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::create { path args } {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::compiler::optionWidget $path $args
    namespace eval ::Widget::tcldevkit::compiler::optionWidget::$path {}

    InitState             $path
    ValidateStoreVariable $path

    variable ::Widget::tcldevkit::compiler::optionWidget::${path}::state

    eval [list ttk::frame $path -class tcldevkit::compiler::optionWidget] \
	[Widget::subcget $path :cmd]

    bind real${path} <Destroy> {tcldevkit::compiler::optionWidget::destroy %W; rename %W {}}

    set base {
	ttk::checkbutton .force  {-text "Force overwrite"}
	ttk::labelframe  .out    {-text "Destination directory"}
	ttk::labelframe  .pfx    {-text "Prefix handling"}

	ttk::button      .out.b  {-text "Browse..."}
	ttk::entry       .out.e  {}
	ttk::radiobutton .pfx.rn {-text "None"         -value "none"}
	ttk::radiobutton .pfx.ra {-text "Auto"         -value "auto"}
	ttk::radiobutton .pfx.rt {-text "Tag"          -value "tag"}
	ttk::radiobutton .pfx.rp {-text "Specify file" -value "path"}
	ttk::button      .pfx.b  {-text "Browse..."}
	ttk::entry       .pfx.e  {}
    }

    foreach {type w static_opts} $base {
	eval $type $path$w [Widget::subcget $path $w] $static_opts
	set tags [bindtags $path$w]
	bindtags $path$w [linsert $tags 1 $path]
	set state($w) $path$w
    }

    foreach {w opt key} {
	.force  -variable     force
	.out.e  -textvariable out
	.pfx.e  -textvariable pfx,path
	.pfx.rn -variable     pfx
	.pfx.ra -variable     pfx
	.pfx.rt -variable     pfx
	.pfx.rp -variable     pfx
    } {
	$state($w) configure $opt \
	    ::Widget::tcldevkit::compiler::optionWidget::${path}::state($key)
    }

    $state(.out.b) configure -command \
	[list ::tcldevkit::compiler::optionWidget::chooseOut $path] \
	-image [image::get file]

    $state(.pfx.b) configure -command \
	[list ::tcldevkit::compiler::optionWidget::choosePfx $path] \
	-image [image::get file]


    bindtags $path [list real${path} optionWidget [winfo toplevel $path] all]

    foreach {slave col row stick padx pady} {
	.force  0 0 swen 1m 1m
	.out    0 1 swen 1m 1m
	.pfx    0 2 swen 1m 1m
	.out.e  0 0 swen 1m 2m
	.out.b  1 0 swen 1m 2m
	.pfx.rn 0 0  we  1m 1m
	.pfx.ra 0 1  we  1m 1m
	.pfx.rt 0 2  we  1m 1m
	.pfx.rp 0 3  we  1m 1m
	.pfx.e  1 3 swen 1m 1m
	.pfx.b  2 3 swen 1m 1m
    } {
	grid $state($slave) -column $col -row $row -sticky $stick -padx $padx -pady $pady
    }
    foreach {master col weight} {
	{}   0 1
	.out 0 1
	.out 1 0
	.pfx 0 0
	.pfx 1 1
	.pfx 2 0
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid columnconfigure $_w $col -weight $weight
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
	.force {Force overwrite of old compilation results}
	.out   {Destination directory for results}
	.pfx   {Specify how to handle prefixes}
    }
    tipstack::def [list \
	    $state(.out.b)  {Browse for destination directory} \
	    $state(.out.e)  {Enter destination directory} \
	    $state(.pfx.rn) {No prefix handling} \
	    $state(.pfx.ra) {Automatic handling of prefix} \
	    $state(.pfx.rt) {Use tagged prefix} \
	    $state(.pfx.rp) {Use a prefix file} \
	    $state(.pfx.b)  {Browse for prefix file} \
	    $state(.pfx.e)  {Enter prefix file} \
    ]

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::compiler::optionWidget::\$cmd $path \$args\]\
	    "
    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::optionWidget::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::compiler::optionWidget::${path}::state
    variable $svar
    variable ::Widget::tcldevkit::compiler::optionWidget::${path}::linkvar

    if {[info exists linkvar]} {
	if {$linkvar != {}} {
	    # Remove the traces for linked variable, if existing
	    trace vdelete $linkvar w [list \
		    ::tcldevkit::compiler::optionWidget::TraceIn $path $linkvar]
	    trace vdelete $svar    w [list \
		    ::tcldevkit::compiler::optionWidget::TraceOut $path $svar]
	}
	unset linkvar
    }
    if {[info exists state]} {
	# Remove internal traces
	trace vdelete ${svar}(pfx) w [list \
		::tcldevkit::compiler::optionWidget::PfxOk $path $svar]
	trace vdelete ${svar}(pfx,path) w [list \
		::tcldevkit::compiler::optionWidget::PfxOk $path $svar]
	trace vdelete ${svar}(out) w [list \
		::tcldevkit::compiler::optionWidget::OutOk $path $svar]
	trace vdelete ${svar}(pfx,ok) w [list \
		::tcldevkit::compiler::optionWidget::Ok $path $svar]
	trace vdelete ${svar}(out,ok) w [list \
		::tcldevkit::compiler::optionWidget::Ok $path $svar]
	unset state
    }
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::optionWidget::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    return [eval [linsert $args 0 configure $path]]
}

proc ::tcldevkit::compiler::optionWidget::configure { path args } {
    # addmap -option are already forwarded to their appriopriate subwidgets
    set res [Widget::configure $path $args]

    # Handle -variable.

    if {[Widget::hasChanged $path -variable dummy]} {
	ValidateStoreVariable $path
    }
    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::optionWidget::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::optionWidget::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::ValidateStoreVariable { path } {

    set svar ::Widget::tcldevkit::compiler::optionWidget::${path}::state
    variable $svar
    variable ::Widget::tcldevkit::compiler::optionWidget::${path}::linkvar linkvar

    set newvar [Widget::getoption $path -variable]
    if {[string equal $newvar $linkvar]} {
	# -variable unchanged.
	return
    }

    # -variable was changed.

    if {$newvar == {}} {
	# The variable was disconnected from the widget. Remove the traces.

	trace vdelete $linkvar w [list \
		::tcldevkit::compiler::optionWidget::TraceIn $path $linkvar]
	trace vdelete $svar    w [list \
		::tcldevkit::compiler::optionWidget::TraceOut $path $svar]

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
		::tcldevkit::compiler::optionWidget::TraceIn $path $newvar]
	trace variable $svar   w [list \
		::tcldevkit::compiler::optionWidget::TraceOut $path $svar]

	set linkvar $newvar
	return
    }

    # Changed from one variable to the other. Remove old traces, setup
    # new ones, copy relevant information of state!

    trace vdelete $linkvar w [list \
	    ::tcldevkit::compiler::optionWidget::TraceIn $path $linkvar]
    trace vdelete $svar    w [list \
	    ::tcldevkit::compiler::optionWidget::TraceOut $path $svar]

    CopyState $path $newvar

    trace variable $newvar w [list \
	    ::tcldevkit::compiler::optionWidget::TraceIn $path $newvar]
    trace variable $svar   w [list \
	    ::tcldevkit::compiler::optionWidget::TraceOut $path $svar]

    set linkvar $newvar
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::CopyState { path var } {
    upvar #0 ::Widget::tcldevkit::compiler::optionWidget::keymap         map
    upvar #0 $var                                                     data
    upvar #0 ::Widget::tcldevkit::compiler::optionWidget::${path}::state state

    foreach {inkey exkey} $map {
	set data($exkey) $state($inkey)
    }
    return
}

proc ::tcldevkit::compiler::optionWidget::InitState { path } {
    set svar ::Widget::tcldevkit::compiler::optionWidget::${path}::state
    variable $svar
    variable ::Widget::tcldevkit::compiler::optionWidget::${path}::linkvar

    set linkvar ""
    array set state {
	force       0
	pfx         none
	pfx,path    ""  pfx,ok 1 pfx,msg ""
	out         ""  out,ok 1 out,msg ""
	ok          1
	errmsg      ""
	trace       ""
    }
    if {[package vcompare [info tclversion] 8.3] <= 0} {
	array set state {frame,.out {} frame,.pfx {}}
    }

    set state(lastdir,out) [pwd]
    set state(lastdir,pfx) [pwd]

    # Internal traces computing the ok/fail state of the entered information.

    trace variable ${svar}(pfx) w [list \
	    ::tcldevkit::compiler::optionWidget::PfxOk $path $svar]
    trace variable ${svar}(pfx,path) w [list \
	    ::tcldevkit::compiler::optionWidget::PfxOk $path $svar]
    trace variable ${svar}(out) w [list \
	    ::tcldevkit::compiler::optionWidget::OutOk $path $svar]
    trace variable ${svar}(pfx,ok) w [list \
	    ::tcldevkit::compiler::optionWidget::Ok $path $svar]
    trace variable ${svar}(out,ok) w [list \
	    ::tcldevkit::compiler::optionWidget::Ok $path $svar]
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::TraceIn { path tvar var idx op } {
    upvar #0 ::Widget::tcldevkit::compiler::optionWidget::${path}::state   state

    # Lock out TraceIn if it is done in response to a change in the widget itself.
    if {[string equal $state(trace) out]} {return}

    upvar #0 ::Widget::tcldevkit::compiler::optionWidget::keymap_r   map_r
    upvar #0 $tvar                                                   data

    ##puts "TraceIn { $path $var /$idx/ $op }"

    array set tmp $map_r
    if {[info exists tmp($idx)]} {set inkey $tmp($idx)} else {return}
    set state($inkey) $data($idx)
    return
}

proc ::tcldevkit::compiler::optionWidget::TraceOut { path tvar var idx op } {
    upvar #0 $tvar                                                      state
    upvar #0 ::Widget::tcldevkit::compiler::optionWidget::keymap           map
    upvar #0 ::Widget::tcldevkit::compiler::optionWidget::${path}::linkvar linkvar
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

proc ::tcldevkit::compiler::optionWidget::PfxOk {path svar var idx op} {
    upvar #0 $svar state

    if {![string equal $state(pfx) path]} {
	# TODO: entry-bg option
	$state(.pfx.e) configure -background white ; # [Widget::getoption $path -background]
	set state(pfx,msg) ""
	set state(pfx,ok)  1

	tipstack::pop $state(.pfx.e)
	return
    }

    set ok 1
    set file $state(pfx,path)

    if {![file exists $file]} {
	set state(pfx,msg) "Prefix file does not exist: $file"
	set ok 0
    } elseif {![file isfile $file]} {
	set state(pfx,msg) "Prefix file is not a file: $file"
	set ok 0
    } elseif {![file readable $file]} {
	set ok 0
	set state(pfx,msg) "Prefix file is not readable: $file"
    } else {
	set state(pfx,msg) ""
    }
    if {!$ok} {
	$state(.pfx.e) state invalid
	tipstack::push $state(.pfx.e) $state(pfx,msg)
    } else {
	# TODO: entry-bg option
	$state(.pfx.e) state !invalid
	tipstack::pop $state(.pfx.e)
    }

    set state(pfx,ok) $ok
    return
}

proc ::tcldevkit::compiler::optionWidget::OutOk {path svar var idx op} {
    upvar #0 $svar state

    set ok 1
    set file $state(out)

    if {$file == {}} {
	# An empty name is ok, it just means that the compilation is in place.
	set state(out,msg) ""
    } elseif {![file exists $file]} {
	set ok 0
	set state(out,msg) "Destination does not exist: $file"
    } elseif {![file isdirectory $file]} {
	set ok 0
	set state(out,msg) "Destination is not a directory: $file"
    } elseif {![file writable $file]} {
	set ok 0
	set state(out,msg) "Destination is not writable: $file"
    } else {
	set state(out,msg) ""
    }
    if {!$ok} {
	$state(.out.e) state invalid
	tipstack::push $state(.out.e) $state(out,msg)
    } else {
	# TODO: entry-bg option
	$state(.out.e) state !invalid
	tipstack::pop $state(.out.e)
    }

    set state(out,ok) $ok
    return
}

proc ::tcldevkit::compiler::optionWidget::Ok {path svar var idx op} {
    upvar #0 $svar state

    set state(ok) [expr {$state(out,ok) && $state(pfx,ok)}]
    if {$state(ok)} {
	set state(errmsg) ""
    } else {
	set msg [list]
	if {!$state(out,ok)} {lappend msg $state(out,msg)}
	if {!$state(pfx,ok)} {lappend msg $state(pfx,msg)}
	set state(errmsg) [join $msg \n]
    }
    return
}

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

proc ::tcldevkit::compiler::optionWidget::chooseOut {path} {
    upvar #0 ::Widget::tcldevkit::compiler::optionWidget::${path}::state state

    set dir [tk_chooseDirectory \
	    -title    "Select destination directory" \
	    -parent    $path \
	    -initialdir $state(lastdir,out) \
	    ]
    if {$dir == {}} {return}

    set state(lastdir,out) [file dirname $dir]
    set state(out) [file nativename $dir]
    return
}

proc ::tcldevkit::compiler::optionWidget::choosePfx {path} {
    upvar #0 ::Widget::tcldevkit::compiler::optionWidget::${path}::state state

    set file [tk_getOpenFile \
	    -title     "Select prefix file" \
	    -parent    $path \
	    -filetypes {{All {*}}} \
	    -initialdir $state(lastdir,pfx) \
	    ]

    if {$file == {}} {return}
    set state(lastdir,pfx) [file dirname $file]
    set state(pfx,path) [file nativename $file]
    return
}

# -----------------------------------------------------------------------------

package provide tcldevkit::compiler::optionWidget 2.0
