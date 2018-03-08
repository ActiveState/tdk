# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# appOptsWidget.tcl --
#
#	This file implements ...
#
# Copyright (c) 2002-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: $
#
# ------------------------------------------------------------------------------

package require BWidget ; # BWidgets | Foundation for this mega-widget.
package require tipstack

# ------------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::wrapper::appOptsWidget::create
#     - tcldevkit::wrapper::appOptsWidget::destroy
#     - tcldevkit::wrapper::appOptsWidget::configure
#     - tcldevkit::wrapper::appOptsWidget::cget
#     - tcldevkit::wrapper::appOptsWidget::setfocus
#     - tcldevkit::wrapper::appOptsWidget::getcfg
#     - tcldevkit::wrapper::appOptsWidget::setcfg
# ------------------------------------------------------------------------------

namespace eval ::tcldevkit::wrapper::appOptsWidget {
    ScrolledWindow::use

    Widget::declare tcldevkit::wrapper::appOptsWidget {
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
    }

    Widget::addmap tcldevkit::wrapper::appOptsWidget "" :cmd    {-background {}}
    Widget::addmap tcldevkit::wrapper::appOptsWidget "" .args.l {-background {}}

    foreach w {
	.code .code.t
	.pcode .pcode.t
	.args .args.add .args.rem .args.e .args.l.l
	.pd   .pd.add   .pd.rem   .pd.e   .pd.l.l
    } {
	Widget::addmap tcldevkit::wrapper::appOptsWidget "" $w {
	    -background {} -foreground {} -font {}
	}
    }

    proc ::tcldevkit::wrapper::appOptsWidget {path args} {
	return [eval appOptsWidget::create $path $args]
    }
    proc use {} {}

    bind appOptsWidget <FocusIn> {::tcldevkit::wrapper::appOptsWidget::setfocus %W}
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::appOptsWidget::create
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::appOptsWidget::create { path args } {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init             tcldevkit::wrapper::appOptsWidget  $path $args
    namespace eval ::Widget::tcldevkit::wrapper::appOptsWidget::$path {}

    InitState             $path

    set svar ::Widget::tcldevkit::wrapper::appOptsWidget::${path}::state
    upvar #0 $svar state

    set main_opt [Widget::subcget $path :cmd]

    eval [list ttk::frame $path -class tcldevkit::wrapper::appOptsWidget] \
	$main_opt

    bind real${path} <Destroy> {tcldevkit::wrapper::appOptsWidget::destroy %W; rename %W {}}

    set base {
	ttk::labelframe  .code     {-text "Initialization"}
	ttk::labelframe  .pcode    {-text "Post-Initialization"}
	ttk::labelframe  .args     {-text "Arguments"}
	ttk::labelframe  .pd       {-text "Nonstandard package directories"}
    }
    set sub {
	text           .code  .t  {-width 40 -height 5 -bd 1}
	text           .pcode .t  {-width 40 -height 5 -bd 1}
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

    set state(.args.le) [listentryb $state(.args).le \
			     -listvariable ${svar}(arguments) \
			     -labels  {argument} \
			     -labelp  {arguments} \
			     -height 3 \
			     -ordered 1 \
			     -browse  0]

    set state(.pd.le) [listentryb $state(.pd).le \
			   -listvariable ${svar}(pdirs) \
			   -labels  {non-standard package directory} \
			   -labelp  {non-standard package directories} \
			   -height 3 \
			   -ordered 1 \
			   -browse  0]

    foreach {slave col row stick padx pady span colspan} {
	.code     0 0 swen 1m 1m 1 1
	.code.t   0 0 swen 1m 2m 1 1
	.pcode    1 0 swen 1m 1m 1 1
	.pcode.t  0 0 swen 1m 2m 1 1
	.args     0 1 swen 1m 1m 1 1
	.args.le  0 0 swen 1m 1m 1 1
	.pd       1 1 swen 1m 1m 1 1
	.pd.le    0 0 swen 1m 1m 1 1
    } {
	grid $state($slave) -columnspan $colspan -column $col -row $row \
	    -sticky $stick -padx $padx -pady $pady -rowspan $span
    }
    foreach {master col weight} {
	{}     0 1
	{}     1 1
	.code  0 1
	.pcode 0 1
	.args  0 1
	.pd    0 1
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid columnconfigure $_w $col -weight $weight
    }
    foreach {master row weight} {
	{}     0 1
	{}     1 1
	{}     2 0
	.code  0 1
	.pcode 0 1
	.args  0 1
	.pd    0 1
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid rowconfigure $_w $row -weight $weight
    }

    tipstack::defsub $path {
	.code     {Wrapper specific initialization code for application}
	.pcode    {Wrapper specific initialization code for application run after startup}
	.args     {Predefined arguments of wrapped application}
	.pd       {Additional package search paths for the wrapped application}
    }
    tipstack::def [list \
	    $state(.code.t)   {Enter wrapper specific initialization code for application} \
	    $state(.pcode.t)  {Enter wrapper specific initialization code for application run after startup} \
		      ]

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::wrapper::appOptsWidget::\$cmd $path \$args\]\
	    "
    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::appOptsWidget::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::appOptsWidget::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::appOptsWidget::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::appOptsWidget::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    return [eval [linsert $args 0 configure $path]]
}

proc ::tcldevkit::wrapper::appOptsWidget::configure { path args } {
    # addmap -option are already forwarded to their appriopriate subwidgets
    set res [Widget::configure $path $args]
    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::appOptsWidget::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::appOptsWidget::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::appOptsWidget::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::appOptsWidget::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::appOptsWidget::InitState { path } {
    set svar ::Widget::tcldevkit::wrapper::appOptsWidget::${path}::state
    upvar #0 $svar                                              state
    array set state {
	arguments  {}
	pdirs      {}
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::appOptsWidget::getcfg {path} {
    set svar ::Widget::tcldevkit::wrapper::appOptsWidget::${path}::state
    upvar #0 $svar state

    # We trim out irrelevant whitespace in the code.

    ## puts "args ([$state(.args.l.l) size]) = [$state(.args.l.l) get 0 end]"

    return [list \
	    code     [string trim [$state(.code.t) get 1.0 end]] \
	    postcode [string trim [$state(.pcode.t) get 1.0 end]] \
	    args     $state(arguments) \
	    pkgdirs  $state(pdirs) \
	    ]
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::appOptsWidget::setcfg {path sub data} {
    set svar ::Widget::tcldevkit::wrapper::appOptsWidget::${path}::state
    upvar #0 $svar state

    switch -exact -- $sub {
	code {
	    $state(.code.t) delete 1.0 end
	    $state(.code.t) insert end $data
	}
	postcode {
	    $state(.pcode.t) delete 1.0 end
	    $state(.pcode.t) insert end $data
	}
	args {
	    set state(arguments) $data
	}
	pkgdirs {
	    set state(pdirs) $data
	}
	default {return -code error "Illegal sub key \"$sub\""}
    }
}

# ------------------------------------------------------------------------------

package provide tcldevkit::wrapper::appOptsWidget 1.0
