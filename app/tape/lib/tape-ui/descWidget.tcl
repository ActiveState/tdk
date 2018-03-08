# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# descWidget.tcl --
#
#	Package description display
#	- Name
#	- Version
#	- Textual description
#	- Platform dependency
#	- Hidden
#	- Reference
#
# Copyright (c) 2003-2006 ActiveState Software Inc.

# 
# RCS: @(#) $Id: Exp $
#
# -----------------------------------------------------------------------------

package require BWidget ; # BWidgets | Foundation for this mega-widget.
package require tipstack

# -----------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::tape::descWidget::create
#     - tcldevkit::tape::descWidget::destroy
#     - tcldevkit::tape::descWidget::configure
#     - tcldevkit::tape::descWidget::cget
#     - tcldevkit::tape::descWidget::setfocus
# -----------------------------------------------------------------------------

namespace eval ::tcldevkit::tape::descWidget {
    Widget::declare tcldevkit::tape::descWidget {
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-font               TkResource ""     0 text}
        {-errorbackground    Color     "lightyellow" 0}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
        {-connect            String     ""     0}
	{-state              String     normal 0}
    }

    foreach w {
	.desc.t  .cat.name .cat.vers .cat.arch .cat.hidden
	.cat.see .cat.nl   .cat.vl   .cat.al   .cat.scb
    } {
	Widget::addmap tcldevkit::tape::descWidget "" $w {-state {}}
    }

    proc ::tcldevkit::tape::descWidget {path args} {
	return [eval descWidget::create $path $args]
    }
    proc use {} {}

    bind descWidget <FocusIn> {::tcldevkit::tape::descWidget::setfocus %W}
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::tape::descWidget::create
# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::descWidget::create { path args } {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init             tcldevkit::tape::descWidget  $path $args
    namespace eval ::Widget::tcldevkit::tape::descWidget::$path {}
    InitState                                             $path

    set svar ::Widget::tcldevkit::tape::descWidget::${path}::state
    variable $svar

    set main_opt [Widget::subcget $path :cmd]

    eval [list ttk::frame $path -class tcldevkit::tape::descWidget] $main_opt

    bind real${path} <Destroy> {tcldevkit::tape::descWidget::destroy %W; rename %W {}}

    set base {
	ttk::labelframe  .cat    {-text "Identification"}
	ttk::labelframe  .desc   {-text "Description"}
	text             .desc.t     {-width 10 -height 10}
	ttk::entry       .cat.name   {}
	ttk::entry       .cat.vers   {}
	ttk::entry       .cat.arch   {}
	ttk::checkbutton .cat.hidden {-text Hidden}
	ttk::checkbutton .cat.see    {-text "Same files as"}
	ttk::label       .cat.nl     {-text Name}
	ttk::label       .cat.vl     {-text Version}
	ttk::label       .cat.al     {-text Platform}
	ttk::combobox    .cat.scb    {-state readonly}
    }
    foreach {type w static_opts} $base {
	eval [list $type $path$w] [Widget::subcget $path $w] $static_opts
	set tags [bindtags $path$w]
	bindtags $path$w [linsert $tags 1 $path]

	set state($w) $path$w
	catch {set state(bg,$w) [$path$w cget -background]}
    }

    bindtags $path [list real${path} descWidget [winfo toplevel $path] all]

    foreach {slave col row stick padx pady span} {
	.cat         0 0 swen 8  8 1
	.desc        0 1 swen 8  8 1
	.cat.nl      0 0 swen 1m 1m 1
	.cat.name    1 0  wen 1m 1m 1
	.cat.vl      0 1 swen 1m 1m 1
	.cat.vers    1 1  wen 1m 1m 1
	.cat.al      0 2 swen 1m 1m 1
	.cat.arch    1 2  wen 1m 1m 1
	.cat.hidden  2 0 swen 1m 1m 1
	.cat.see     2 1 swen 1m 1m 1
	.cat.scb     3 1   wn 1m 1m 1
	.desc.t      0 0 swen 1m 2m 1
    } {
	grid $state($slave) -column $col -row $row -sticky $stick -padx $padx -pady $pady -rowspan $span
    }
    foreach {master col weight} {
	{}    0 1
	.desc 0 1
	.cat  0 0
	.cat  1 0
	.cat  2 0
	.cat  3 1
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid columnconfigure $_w $col -weight $weight
    }
    foreach {master row weight} {
	{}    0 0
	{}    1 1
	.desc 0 1
	.cat  0 0
	.cat  1 0
	.cat  2 0
	.cat  3 1
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid rowconfigure $_w $row -weight $weight
    }

    tipstack::defsub $path {
	.desc     {Textual description of the package}
	.cat      {Basic information about the package}
    }
    tipstack::def [list \
		       $state(.desc.t)     {Enter the textual description of the package} \
		       $state(.cat.name)   {Name of the package} \
		       $state(.cat.vers)   {Version of the package} \
		       $state(.cat.arch)   {Platform the package can be used on} \
		       $state(.cat.hidden) {If set the package is hidden from users of TclApp} \
		       $state(.cat.see)    {Check this if the package uses the same list
			   of files as a previous package.} \
		      ]

    # Link the widgets to the system state.

    $state(.cat.see)    configure -variable     ${svar}(see)
    $state(.cat.hidden) configure -variable     ${svar}(hidden)
    $state(.cat.name)   configure -textvariable ${svar}(name)
    $state(.cat.vers)   configure -textvariable ${svar}(version)
    $state(.cat.arch)   configure -textvariable ${svar}(platform)

    $state(.cat.scb) configure \
	-postcommand [list ::tcldevkit::tape::descWidget::getrefs $path $state(.cat.scb)]
    bind <<ComboboxSelected>> \
	[list ::tcldevkit::tape::descWidget::setref $path $state(.cat.scb)]

    ## The text field is not linked directly. Instead it is
    ## saved whenever the data would change because of switches
    ## or deactivation. See 'do select'.

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::tape::descWidget::\$cmd $path \$args\]\
	    "

    # Handle an initial setting of -connect.
    Connect $path [Widget::getoption $path -connect]

    set state(_trace) 1 ; # Initialize dependent information, allow tracing. Also invokes the trace!
    return $path
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::tape::descWidget::destroy
# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::descWidget::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::tape::descWidget::${path}::state
    variable $svar

    if {[info exists state]} {
	# Remove internal traces
	trace vdelete ${svar} w \
	    [list ::tcldevkit::tape::descWidget::StateChange $path $svar]
	unset state
    }
    namespace delete ::Widget::tcldevkit::tape::descWidget::${path}

    return
}

# -----------------------------------------------------------------------------
#  Command tcldevkit::tape::descWidget::configure
# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::descWidget::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    return [eval [linsert $args 0 configure $path]]
}

proc ::tcldevkit::tape::descWidget::configure { path args } {
    # addmap -option are already forwarded to their appriopriate subwidgets
    set res [Widget::configure $path $args]

    if {[Widget::hasChanged $path -connect conn]} {
	Connect $path $conn
    }
    return $res
}

proc ::tcldevkit::tape::descWidget::Connect { path cmd } {
    variable ::Widget::tcldevkit::tape::descWidget::${path}::state

    set state(connect) $cmd
    return
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::tape::descWidget::cget
# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::descWidget::cget { path option } {
    return [Widget::cget $path $option]
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::tape::descWidget::setfocus
# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::descWidget::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::descWidget::InitState { path } {
    set svar ::Widget::tcldevkit::tape::descWidget::${path}::state
    variable $svar
    array set state {
	desc     {}
	see      0
	hidden   0
	name     {}
	version  {}
	platform {}
	connect  {}
	_trace 0
    }

    # Internal traces to propagate the information to the global state
    # package

    # Add internal traces
    trace variable ${svar} w \
	[list ::tcldevkit::tape::descWidget::StateChange $path $svar]
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::descWidget::StateChange {path svar var idx op} {
    upvar #0 $svar state

    #puts "($idx -- $state($idx))"

    if {!$state(_trace)}             {return}
    if {[string equal $idx connect]} {return}
    if {[string equal $idx _trace]}  {return}
    if {[string match bg,* $idx]}    {return}
    if {[llength $state(connect)] == 0} {return}

    #puts "($idx -- $state($idx))"

    if {[catch {
	# Propagate the change, based upon the changed information.
	# Tell the new current value too, to make the update easier.
	# Internal changes are not propagated (connect, _trace, s.a.).

	#puts "eval [linsert $cmd end change $idx $state($idx)]"

	UpCall $path change $idx $state($idx)
    } msg]} {
	log::log critical ::tcldevkit::tape::descWidget::StateChange
	log::log critical "Trace Failure:"
	log::log critical $msg
    }
    return
}


proc ::tcldevkit::tape::descWidget::UpCall {path args} {
    variable ::Widget::tcldevkit::tape::descWidget::${path}::state
    set cmd $state(connect)
    log::log debug  "eval $cmd $args"
    return [uplevel \#0 [linsert $args 0 $state(connect) do]]
}


proc ::tcldevkit::tape::descWidget::do {path cmd args} {
    variable ::Widget::tcldevkit::tape::descWidget::${path}::state

    log::log debug "$path $cmd ([join $args {) (}])"

    # Bugzilla 23380 Using this general enablement cancels 'no-alias'
    # below whenever the widget is ticked by the model.

    #$path configure -state normal
    switch -exact -- $cmd {
	error@ {
	    set key [lindex $args 1]
	    set msg [lindex $args 2]

	    switch -exact -- $key {
		name {
		    ClearError $path .cat.name
		    if {$msg != {}} {
			SetError   $path .cat.name $msg
		    }
		}
		version {
		    ClearError $path .cat.vers
		    if {$msg != {}} {
			SetError   $path .cat.vers $msg
		    }
		}
		platform {
		    ClearError $path .cat.arch
		    if {$msg != {}} {
			SetError   $path .cat.arch $msg
		    }
		}
		see {
		    ClearError $path .cat.see
		    ClearError $path .cat.scb ; # No -bg
		    if {$msg != {}} {
			SetError $path .cat.see $msg
			SetError $path .cat.scb $msg ; # No -bg
		    }
		}
	    }
	}
	no-alias {
	    $state(.cat.see) configure -state disabled
	    $state(.cat.scb) configure -state disabled
	}
	show-alias-ref {
	    set see [lindex $args 0]
	    if {$see} {
		$state(.cat.scb) configure -state normal
	    } else {
		$state(.cat.scb) configure -state disabled
	    }
	}
	select {
	    # The model changes the currently shown package.
	    # This can be immediately followed by
	    # a 'refresh-current', so save the description
	    # as the text widget is not linked with our
	    # state. The save is require if and only if the
	    # data in the text widget is different from the
	    # data in the state. Only this signals that the
	    # user changed the text. The save is done into
	    # the state, a trace then ensures propagation into
	    # the model.

	    set newdesc [string trimright [$path.desc.t get 0.1 end-1c]]
	    if {$newdesc ne $state(desc)} {
		set state(desc) $newdesc
	    }
	}
	refresh-current {
	    # Bugzilla 23380 General enable moved here, will be
	    # partially canceled via no-alias, if necessary.

	    $path configure -state normal
	    # Stop propagation of our state to the state section. The
	    # data we are writing comes from there.
	    set state(_trace) 0

	    $state(.cat.see) configure -state normal
	    $state(.cat.scb) configure -state normal

	    foreach key {name version hidden see desc platform} {
		set state($key) [UpCall $path get $key]
	    }
	    set state(desc) [string trim $state(desc)]
	    $path.desc.t delete 0.1 end
	    $path.desc.t insert end $state(desc)

	    # Retrieve ref names + index of current reference,
	    # place them into our combobox.
	    set state(see,ref) {}
	    if {$state(see)} {
		getrefs $path $state(.cat.scb)
		set state(see,ref) [UpCall $path get-see-ref]
		if {$state(see,ref) != {}} {
		    $state(.cat.scb) set \
			[lindex [$state(.cat.scb) cget -values] $state(see,ref)]
		}
	    } else {
		# Bugzilla 23406. Clean out entry part too.
		$state(.cat.scb) configure -values {}
		$state(.cat.scb) set {}
	    }

	    set state(_trace) 1
	}
	no-current {
	    foreach {key val} {
		name     {}
		version  {}
		hidden    0
		see       0
		desc     {}
		platform {}
	    } {
		set state($key) $val
	    }
	    # Bugzilla 23406. Clean out entry part too.
	    $state(.cat.scb) configure -values {}
	    $state(.cat.scb) set {}
	    $path.desc.t delete 0.1 end
	    $path configure -state disabled
	}
    }
    return
}

proc ::tcldevkit::tape::descWidget::getrefs {path combo} {
    set values [UpCall $path get-allowed-references]

    $combo configure -values $values

    # Bugzilla 23406. Clean out entry part too, if necessary (nothing selectable)
    if {$values == {}} {$combo set {}}
    return
}

proc ::tcldevkit::tape::descWidget::setref {path combo} {
    variable ::Widget::tcldevkit::tape::descWidget::${path}::state

    set state(see,ref) [$combo get]
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::tape::descWidget::SetMsg {path sub msg} {
    variable ::Widget::tcldevkit::tape::descWidget::${path}::state

    if {$msg == {}} {
	tipstack::pop $path$sub
    } else {
	tipstack::push $path$sub $msg
    }
    return
}

proc ::tcldevkit::tape::descWidget::SetError {path sub msg} {
    variable ::Widget::tcldevkit::tape::descWidget::${path}::state

    $path$sub state invalid

    SetMsg $path $sub $msg
    return
}

proc ::tcldevkit::tape::descWidget::ClearError {path sub} {
    variable ::Widget::tcldevkit::tape::descWidget::${path}::state

    $path$sub state !invalid

    SetMsg $path $sub ""
    return
}


package provide tcldevkit::tape::descWidget 2.0
