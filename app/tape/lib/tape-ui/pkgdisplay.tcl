# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgDisplay.tcl --
#
#	Implementation of the widget to display the information for a single
#	package in the .tap file under edit.
#
# Copyright (c) 2003-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# ------------------------------------------------------------------------------

package require BWidget ; # BWidgets | Foundation for this mega-widget.
package require tcldevkit::tape::fileWidget
package require tcldevkit::tape::descWidget
package require tipstack

# ------------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::tape::pkgDisplay::create
#     - tcldevkit::tape::pkgDisplay::destroy
#     - tcldevkit::tape::pkgDisplay::configure
#     - tcldevkit::tape::pkgDisplay::cget
#     - tcldevkit::tape::pkgDisplay::setfocus
#     - tcldevkit::tape::pkgDisplay::getcfg
#     - tcldevkit::tape::pkgDisplay::setcfg
# ------------------------------------------------------------------------------

namespace eval ::tcldevkit::tape::pkgDisplay {

    Widget::declare tcldevkit::tape::pkgDisplay {
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-font               TkResource ""     0 text}
        {-connect            String     ""     0}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
        {-errorbackground    Color     "lightyellow" 0}
    }

    Widget::addmap tcldevkit::tape::pkgDisplay "" :cmd {-background {}}
    foreach w {.files .desc} {
	Widget::addmap tcldevkit::tape::pkgDisplay "" $w {
	    -background {} -foreground {} -font {} -errorbackground {}
	    -connect {}
	}
    }

    proc ::tcldevkit::tape::pkgDisplay {path args} {
	return [eval pkgDisplay::create $path $args]
    }
    proc use {} {}

    bind pkgDisplay <FocusIn> {::tcldevkit::tape::pkgDisplay::setfocus %W}
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::pkgDisplay::create
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::pkgDisplay::create { path args } {
    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::tape::pkgDisplay  $path $args
    namespace eval ::Widget::tcldevkit::tape::pkgDisplay::$path {}
    InitState $path

    variable ::Widget::tcldevkit::tape::pkgDisplay::${path}::state

    set main_opt [Widget::subcget $path :cmd]
    set nb_opt   [Widget::subcget $path .nb]

    eval [list ttk::frame $path -class tcldevkit::tape::pkgDisplay] $main_opt

    set nb [eval [list ttk::notebook $path.nb] $nb_opt]

    bind real${path} <Destroy> {tcldevkit::tape::pkgDisplay::destroy %W; rename %W {}}

    eval tcldevkit::tape::fileWidget::create $path.files \
	[Widget::subcget $path .files]
    eval tcldevkit::tape::descWidget::create $path.desc \
	[Widget::subcget $path .desc]

    # Generate a nice layout ...

    $nb add $path.desc  -text "Basic"
    $nb add $path.files -text "Files"
    # XXX Add <<NotebookTabChanged>> to [focus $path$w]

    foreach w {.desc .files} {
	set tags [bindtags $path$w]
	bindtags $path$w [linsert $tags 1 $path]
    }

    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 0 -weight 1
    grid $nb -column 0 -row 0 -sticky swen

    $nb select $path.desc

    tipstack::defsub $path {
	.files {Enter files contained in package}
	.desc  {Describe the package}
    }

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::tape::pkgDisplay::\$cmd $path \$args\]\
	    "
    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::pkgDisplay::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::pkgDisplay::destroy { path } {
    Widget::destroy

    tipstack::clearsub                  $path
    variable ::Widget::tcldevkit::tape::pkgDisplay::${path}::state

    namespace delete ::Widget::tcldevkit::tape::pkgDisplay::${path}
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::pkgDisplay::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::pkgDisplay::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    return [eval [linsert $args 0 configure $path]]
}

proc ::tcldevkit::tape::pkgDisplay::configure { path args } {
    # addmap -option are already forwarded to their appropriate subwidgets
    set res [Widget::configure $path $args]

    if {[Widget::hasChanged $path -connect conn]} {
	variable ::Widget::tcldevkit::tape::pkgDisplay::${path}::state

	set state(connect) $conn
    }
    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::pkgDisplay::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::pkgDisplay::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::tape::pkgDisplay::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::pkgDisplay::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::pkgDisplay::InitState { path } {
    set svar ::Widget::tcldevkit::tape::pkgDisplay::${path}::state
    variable $svar
    array set state {connect {}}

    # Internal traces computing the ok/fail state of the entered information.

    trace variable ${svar}(argument) w [list \
	    ::tcldevkit::tape::pkgDisplay::Ok $path $svar]
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::tape::pkgDisplay::do {path cmd args} {
    log::log debug "$path $cmd ([join $args ") ("])"
    
    #after idle $path.nb itemconfigure desc -state normal
    switch -exact -- $cmd {
	no-alias       -
	show-alias-ref {
	    # Delegate to description widget
	    eval [linsert $args 0 $path.desc do $cmd]
	}
	enable-files {
	    # (De)activate the file selection pane according
	    # to sharing status of package.

	    set on [lindex $args 0]
	    if {$on} {
		$path.nb tab $path.files -state normal
	    } else {
		$path.nb select $path.desc
		$path.nb tab $path.files -state disabled
	    }
	}
	error@ -
	select -
	refresh-current -
	no-current {
	    # Delegate to description and file widgets
	    eval [linsert $args 0 $path.desc do $cmd]
	    eval [linsert $args 0 $path.files do $cmd]
	    #after idle $path.nb itemconfigure desc -state disabled
	}
    }
    return
}

# ------------------------------------------------------------------------------

package provide tcldevkit::tape::pkgDisplay 2.0
