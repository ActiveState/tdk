# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# sysOptsWidget.tcl --
#
#	This file implements a execution widget, a combination of
#	start-button and logging window.
#
# Copyright (c) 2002-2008 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# ------------------------------------------------------------------------------

package require BWidget ; # BWidgets | Foundation for this mega-widget.
package require tipstack
package require mafter  ; # Delayed trace processing = delayed validation.

# ------------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::wrapper::sysOptsWidget::create
#     - tcldevkit::wrapper::sysOptsWidget::destroy
#     - tcldevkit::wrapper::sysOptsWidget::configure
#     - tcldevkit::wrapper::sysOptsWidget::cget
#     - tcldevkit::wrapper::sysOptsWidget::setfocus
#     - tcldevkit::wrapper::sysOptsWidget::log
# ------------------------------------------------------------------------------

namespace eval ::tcldevkit::wrapper::sysOptsWidget {
    Widget::declare tcldevkit::wrapper::sysOptsWidget {
	{-variable	     String     ""     0}
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-errorbackground    Color     "#FFFFE0" 0}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
    }

    Widget::addmap tcldevkit::wrapper::sysOptsWidget "" :cmd {-background {}}

    foreach w {
	.verbose .tempdir .tempdir.b .tempdir.e
	.nocompress
    } {
	Widget::addmap tcldevkit::wrapper::sysOptsWidget "" $w {
	    -background {} -foreground {} -font {}
	}
    }

    proc ::tcldevkit::wrapper::sysOptsWidget {path args} {
	return [eval sysOptsWidget::create $path $args]
    }
    proc use {} {}

    bind sysOptsWidget <FocusIn> {::tcldevkit::wrapper::sysOptsWidget::setfocus %W}

    # Widget class data
    set ::Widget::tcldevkit::wrapper::sysOptsWidget::keymap {
	nocompress sys,nocompress
	verbose    sys,verbose
	tempdir    sys,tempdir
	sys,ok     sys,ok
	sys,msg    sys,msg
    }
    set ::Widget::tcldevkit::wrapper::sysOptsWidget::keymap_r {
	sys,nocompress nocompress 
	sys,verbose verbose
	sys,tempdir tempdir
	sys,ok	    sys,ok
	sys,msg     sys,msg
    }
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::sysOptsWidget::create
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::create { path args } {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::wrapper::sysOptsWidget $path $args
    namespace eval ::Widget::tcldevkit::wrapper::sysOptsWidget::$path {}

    InitState             $path
    ValidateStoreVariable $path

    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state state

    set main_opt [Widget::subcget $path :cmd]

    eval [list ttk::frame $path -class tcldevkit::wrapper::sysOptsWidget] \
	$main_opt

    bind real${path} <Destroy> {tcldevkit::wrapper::sysOptsWidget::destroy %W; rename %W {}}

    set base {
	ttk::checkbutton .verbose    {-text "Verbose log"}
	ttk::checkbutton .nocompress {-text "No compression"}
	ttk::labelframe  .tempdir    {-text "Temporary build directory"}
    }
    set sub {
	ttk::button      .tempdir .b  {-text "Browse..."}
	ttk::entry       .tempdir .e  {}
    }
    foreach {type w static_opts} $base {
	eval $type $path$w [Widget::subcget $path $w] $static_opts
	set tags [bindtags $path$w]
	bindtags $path$w [linsert $tags 1 $path]

	set state($w) $path$w
    }
    foreach {type parent w static_opts} $sub {
	set optcode $parent$w
	set truepath $path$parent$w
	eval $type $truepath [Widget::subcget $path $optcode] $static_opts
	set tags [bindtags $truepath]
	bindtags $truepath [linsert $tags 1 $path]

	set state($optcode) $truepath
    }


    foreach {w opt key} {
	.verbose    -variable     verbose
	.nocompress -variable     nocompress
	.tempdir.e  -textvariable tempdir
    } {
	$state($w) configure $opt \
		::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state($key)
    }

    $state(.tempdir.b) configure -command [list \
	    ::tcldevkit::wrapper::sysOptsWidget::chooseTemp $path] \
	-image [image::get file]

    bindtags $path [list real${path} sysOptsWidget [winfo toplevel $path] all]

    foreach {slave col row stick padx pady colspan} {
	.verbose    0 0 swen 1m 1m 1
	.nocompress 1 0 swn  1m 1m 1
	.tempdir    0 1 swen 1m 1m 2
	.tempdir.e  0 0 swen 1m 2m 1
	.tempdir.b  1 0 swen 1m 2m 1
    } {
	grid $state($slave) -column $col -row $row -sticky $stick -padx $padx -pady $pady -columnspan $colspan
    }
    foreach {master col weight} {
	{}       0 0
	{}       1 1
	.tempdir 0 1
	.tempdir 1 0
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid columnconfigure $_w $col -weight $weight
    }
    foreach {master row weight} {
	{} 0 0
	{} 1 0
	{} 2 1
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid rowconfigure $_w $row -weight $weight
    }

    tipstack::defsub $path {
	.verbose    {Verbose log}
	.nocompress {Do not compress files in the wrap result}
	.tempdir    {Temporary build directory}
    }
    tipstack::def [list \
	    $state(.tempdir.b) {Browse for temporary build directory} \
	    $state(.tempdir.e) {Enter temporary build directory} \
    ]

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::wrapper::sysOptsWidget::\$cmd $path \$args\]\
	    "
    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::sysOptsWidget::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::linkvar linkvar
    upvar #0 $svar                                                      state

    if {[info exists linkvar]} {
	if {$linkvar != {}} {
	    # Remove the traces for linked variable, if existing
	    trace vdelete $linkvar w [list \
		    ::tcldevkit::wrapper::sysOptsWidget::TraceIn $path $linkvar]
	    trace vdelete $svar    w [list \
		    ::tcldevkit::wrapper::sysOptsWidget::TraceOut $path $svar]
	}
	unset linkvar
    }
    if {[info exists state]} {
	# Kill the delay timer for validation processing.
	$state(/ma) destroy

	# Remove internal traces
	trace vdelete ${svar}(tempdir) w [list \
		::tcldevkit::wrapper::sysOptsWidget::TempOk $path $svar]
	unset state
    }
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::sysOptsWidget::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    return [eval [linsert $args 0 configure $path]]
}

proc ::tcldevkit::wrapper::sysOptsWidget::configure { path args } {
    # addmap -option are already forwarded to their appriopriate subwidgets
    set res [Widget::configure $path $args]

    # Handle -variable and -errorbackground.

    if {[Widget::hasChanged $path -variable dummy]} {
	ValidateStoreVariable $path
    }
    if {[Widget::hasChanged $path -errorbackground ebg]} {
	upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state state

	if {!$state(sys,ok)} {$state(.tempdir.e) configure -bg $ebg}
    }
    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::sysOptsWidget::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::sysOptsWidget::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::ValidateStoreVariable { path } {

    set svar ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::linkvar linkvar

    set newvar [Widget::getoption $path -variable]
    if {[string equal $newvar $linkvar]} {
	# -variable unchanged.
	return
    }

    # -variable was changed.

    if {$newvar == {}} {
	# The variable was disconnected from the widget. Remove the traces.

	trace vdelete $linkvar w [list \
		::tcldevkit::wrapper::sysOptsWidget::TraceIn $path $linkvar]
	trace vdelete $svar    w [list \
		::tcldevkit::wrapper::sysOptsWidget::TraceOut $path $svar]

	set linkvar ""
	return
    }

    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state state

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
		::tcldevkit::wrapper::sysOptsWidget::TraceIn $path $newvar]
	trace variable $svar   w [list \
		::tcldevkit::wrapper::sysOptsWidget::TraceOut $path $svar]

	set linkvar $newvar
	return
    }

    # Changed from one variable to the other. Remove old traces, setup
    # new ones, copy relevant information of state!

    trace vdelete $linkvar w [list \
	    ::tcldevkit::wrapper::sysOptsWidget::TraceIn $path $linkvar]
    trace vdelete $svar    w [list \
	    ::tcldevkit::wrapper::sysOptsWidget::TraceOut $path $svar]

    CopyState $path $newvar

    trace variable $newvar w [list \
	    ::tcldevkit::wrapper::sysOptsWidget::TraceIn $path $linkvar]
    trace variable $svar   w [list \
	    ::tcldevkit::wrapper::sysOptsWidget::TraceOut $path $svar]

    set linkvar $newvar
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::CopyState { path var } {
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::keymap         map
    upvar #0 $var                                                     data
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state state

    foreach {inkey exkey} $map {
	set data($exkey) $state($inkey)
    }
    return
}

proc ::tcldevkit::wrapper::sysOptsWidget::InitState { path } {
    set svar ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::linkvar linkvar
    upvar #0 $svar                                                      state

    set linkvar ""
    array set state {
	verbose     0
	nocompress  0
	tempdir     ""  sys,ok 1 sys,msg "" msg ""
	trace       ""
    }

    set state(lastdir,temp)  [pwd]
    set state(/ma) [mafter %AUTO% 500 \
			[list ::tcldevkit::wrapper::sysOptsWidget::TempOkActual $path $svar]]

    # Internal traces computing the ok/fail state of the entered information.

    trace variable ${svar}(tempdir) w [list \
	    ::tcldevkit::wrapper::sysOptsWidget::TempOk $path $svar]
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::TraceIn { path tvar var idx op } {
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state   state

    # Lock out TraceIn if it is done in response to a change in the widget itself.
    if {[string equal $state(trace) out]} {return}

    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::keymap_r         map_r
    upvar #0 $tvar                                                      data

    ##puts "TraceIn { $path $var /$idx/ $op }"

    array set tmp $map_r
    if {[info exists tmp($idx)]} {set inkey $tmp($idx)} else {return}
    set state($inkey) $data($idx)
    return
}

proc ::tcldevkit::wrapper::sysOptsWidget::TraceOut { path tvar var idx op } {
    upvar #0 $tvar                                                      state
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::keymap           map
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::linkvar linkvar
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

proc ::tcldevkit::wrapper::sysOptsWidget::TempOk {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma) arm
    return
}

proc ::tcldevkit::wrapper::sysOptsWidget::TempOkActual {path svar args} {
    upvar #0 $svar state

    set ok 1
    set file $state(tempdir)

    if {$file == {}} {
	# An empty name is ok, it just means that the compilation is in place.
	set state(msg) ""
    } elseif {![file exists $file]} {
	#set ok 0
	#set state(msg) "Temporary directory does not exist: $file"

	# Bugzilla 19510

	# Accept non-existing temp.dir - will be created in wrapper::Run !
	# (Low-level engine assumes that directory exists).

	# We do check if the parent path is accessible to us (existing
	# and writable).

	set edir [file dirname $file]

	if {![file exists $edir]} {
	    set state(msg) "Path above chosen temporary directory does not exist: $edir"
	    set ok 0
	} elseif {![file isdirectory $edir]} {
	    set state(msg) "Path above chosen temporary directory is not a directory: $edir"
	    set ok 0
	} elseif {![file writable $edir]} {
	    set ok 0
	    set state(msg) "Path above chosen temporary directory is not writable: $edir"
	}
    } elseif {![file isdirectory $file]} {
	set ok 0
	set state(msg) "Temporary build directory is not a directory: $file"
    } elseif {![file writable $file]} {
	set ok 0
	set state(msg) "Temporary build directory is not writable: $file"
    } elseif {![file readable $file]} {
	set ok 0
	set state(msg) "Temporary build directory is not readable: $file"
    } else {
	set state(msg) ""
    }
    if {!$ok} {
	$state(.tempdir.e) state invalid
	tipstack::push $state(.tempdir.e) $state(msg)
    } else {
	# TODO: entry-bg option
	$state(.tempdir.e) state !invalid
	tipstack::pop $state(.tempdir.e)
    }

    set state(sys,msg) "System: $state(msg)"
    set state(sys,ok) $ok
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::sysOptsWidget::chooseTemp {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::sysOptsWidget::${path}::state state

    set dir [tk_chooseDirectory \
	    -title    "Select temporary build directory" \
	    -parent    $path \
	    -initialdir $state(lastdir,temp) \
	    ]
    if {$dir == {}} {return}

    set state(lastdir,temp) [file dirname $dir]
    set state(tempdir) $dir
    return
}

# ------------------------------------------------------------------------------

package provide tcldevkit::wrapper::sysOptsWidget 1.0


