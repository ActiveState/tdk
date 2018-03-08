# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# compiler.tcl --
#
#	This file implements the main widget of the compiler GUI.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: Exp $
#
# -----------------------------------------------------------------------------

set ::AQUA [expr {[tk windowingsystem] eq "aqua"}]
if {$::AQUA} {
    set ::tk::mac::useThemedToplevel 1
    interp alias {} s {} ::tk::unsupported::MacWindowStyle style
}

package require tile
set ::TILE 1
package require BWidget ; # BWidgets | Foundation for this mega-widget.
Widget::theme 1

package require tcldevkit::compiler::optionWidget
package require tcldevkit::compiler::fileWidget
package require runwindow      ; # AS package  | run process, display log.
package require tipstack       ; # AS package  | Stackable tooltips
package require procomp        ; # AS/TclPro   | compiler engine

# Ttk style mapping for invalid entry widgets
# Handle Tk 8.5 (ttk) or 8.4 (tile) usage of style
namespace eval ::ttk {
    style map TEntry -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
    style map TCombobox -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
}

# -----------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::compiler::create
#     - tcldevkit::compiler::destroy
#     - tcldevkit::compiler::configure
#     - tcldevkit::compiler::cget
#     - tcldevkit::compiler::setfocus
# -----------------------------------------------------------------------------

namespace eval ::tcldevkit::compiler {
    tcldevkit::compiler::optionWidget::use
    tcldevkit::compiler::fileWidget::use

    Widget::declare tcldevkit::compiler {
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-errorbackground    Color     "lightyellow" 0}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
    }

    Widget::addmap tcldevkit::compiler "" :cmd    {-background {}}
    foreach w {.o .f .e} {
	Widget::addmap tcldevkit::compiler "" $w {
	    -background {} -foreground {} -font {} -errorbackground {}
	}
    }

    proc ::tcldevkit::compiler {path args} {
	return [eval ::tcldevkit::compiler::create $path $args]
    }
    proc use {} {}

    bind fileWidget <FocusIn> {::tcldevkit::compiler::setfocus %W}

    # Map for translation from keys in configuration files
    # to the keys of the internal state.

    variable keymap {
	out         DestinationDir
	prefix      Prefix/Mode
	prefix,path Prefix/File
	files       Files
	force       ForceOverwrite
    }

    variable keymap_valid
    foreach {old new} $keymap {set keymap_valid($new) .}
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::compiler::create
# -----------------------------------------------------------------------------

proc ::tcldevkit::compiler::create { path args } {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::compiler $path $args
    namespace eval ::Widget::tcldevkit::compiler::$path {}
    InitState $path

    eval [list ttk::frame $path -class tcldevkit::compiler] \
	[Widget::subcget $path :cmd] -padding 8

    set nb [ttk::notebook $path.nb]

    bind real${path} <Destroy> {::tcldevkit::compiler::destroy %W; rename %W {}}

    eval tcldevkit::compiler::optionWidget::create $path.o \
	[Widget::subcget $path .o] -padding 8
    eval tcldevkit::compiler::fileWidget::create   $path.f \
	[Widget::subcget $path .f] -padding 8

    eval runwindow $path.e -padding 8 \
	[Widget::subcget $path .e] \
	-label Compile -labelhelp [list {Compile files}]

    # Link the panes together ...
    set svar ::Widget::tcldevkit::compiler::${path}::state

    $path.e disable
    $path.e configure -command [list ::tcldevkit::compiler::Run $path]
    $path.o configure -variable $svar
    $path.f configure -variable ${svar}(files)

    # Generate a nice layout ...

    foreach {name w} {
	Files   .f
	Options .o
	Run     .e
    } {
	# Maybe we should add a frame to get even padding?
	$nb add $path$w -text $name
	# XXX Add <<NotebookTabChanged>> to [focus $path$w]
	set tags [bindtags $path$w]
	bindtags $path$w [linsert $tags 1 $path]
    }

    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 0 -weight 1
    grid $nb -column 0 -row 0 -sticky swen

    $nb select $path.f

    tipstack::defsub $path {
	.o {Enter compiler options}
	.f {Enter files to compile}
	.e {Start the compilation}
    }

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::compiler::\$cmd $path \$args\]\
	    "

    upvar #0 $svar state
    set state(_trace) 1 ; # Initialize dependent information, allow tracing Also invokes the trace!
    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::compiler::${path}::state
    upvar #0 $svar                                state

    if {[info exists state]} {
	# Remove internal traces
	trace vdelete ${svar} w [list \
		::tcldevkit::compiler::StateChange $path $svar]

	unset state
    }
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    eval [linsert $args 0 configure $path]
}

proc ::tcldevkit::compiler::configure { path args } {
    # addmap -option are already forwarded to their approriate subwidgets
    set res [Widget::configure $path $args]
    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::compiler::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::reset {path} {
    # Reset the configuration to a clear state

    configuration $path = {
	DestinationDir {}
	Prefix/Mode    tag
	Files          {}
	ForceOverwrite 0
	Prefix/File    {}
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::checkConfiguration {path data} {
    # See 'configuration below' for a description of the valid keys.
    # We get this information from they keymap.

    variable keymap_valid
    foreach {key val} $data {
	if {[info exists keymap_valid($key)]} continue
	return -code error "Found illegal key \"$key\" in configuration"
    }
    return
}

proc ::tcldevkit::compiler::configuration {path args} {
    # Return configuration in a serialized, saveable format.
    # Or apply an incoming configuration after checking it.

    # The chosen serialized format is a list of keys and values, as
    # accepted by [array set] (or returned by [array get]). This
    # format is easily written to file or read from it.

    # The keys in the list conform to
    # 	"TclDevKit Project File Format Specification, 2.0"
    #
    #    | Keyword/Command      | Type          | Notes 
    #   -+----------------------+---------------+-------------------------------
    #    | DestinationDir       | Path          | An empty vlaue is allowed. If
    #    |                      |               | the value is not empty it
    #    |                      |               | defines the directory to write
    #    |                      |               | the generated .tbc files to.
    #   -+----------------------+---------------+-------------------------------
    #    | Prefix/Mode          | Enum          | "none", "auto", "tag", "path"
    #   -+----------------------+---------------+-------------------------------
    #    | Prefix/File          | Path          | << Prefix/Mode == path >>
    #    |                      |               | implies that this value is not
    #    |                      |               | empty and contains the path to
    #    |                      |               | the file whose contents are to
    #    |                      |               | be used as prefix of the gen-
    #    |                      |               | erated .tbc files. For any
    #    |                      |               | other value of Prefix/Mode the
    #    |                      |               | value of Prefix/File is not
    #    |                      |               | relevant and ignored.
    #   -+----------------------+---------------+-------------------------------
    #    | Files                | List (Path)   | List of files to compile.
    #   -+----------------------+---------------+-------------------------------
    #    | ForceOverwrite       | Boolean       | ...
    #   -+----------------------+---------------+-------------------------------

    set svar ::Widget::tcldevkit::compiler::${path}::state
    upvar #0 $svar                                state
    variable keymap

    switch -exact -- [llength $args] {
	0 {
	    array set serial [array get state]

	    foreach key {_trace ok errmsg files,msg} {
		catch {unset serial($key)}
	    }

	    # We now have an array containing the data to
	    # save. The only difference to what we want is
	    # that the used keys are wrong. We fix that now.

	    ::tcldevkit::appframe::mapOut $keymap serial
	    return [array get serial]
	}
	1 {
	    if {![string equal keys [set opt [lindex $args 0]]]} {
		return -code error "Unknown subcommand \"$opt\", expected \"keys\""
	    }
	    return [::tcldevkit::appframe::mapKeys $keymap]
	}
	2 {
	    if {![string equal = [set opt [lindex $args 0]]]} {
		return -code error "Unknown subcommand \"$opt\", expected \"=\""
	    }
	    set                       data [lindex $args 1]
	    checkConfiguration $path $data

	    # We now know that the configuration is ok. What is
	    # left is to map the external keys to the internal
	    # ones before merging the new configuration into the
	    # current state.

	    array set serial $data
	    ::tcldevkit::appframe::mapIn $keymap serial

	    array set state [array get serial]
	}
	default {
	    return -code error "wrong#args: .w configuration ?= data?"
	}
    }
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::Run {path} {
    set svar ::Widget::tcldevkit::compiler::${path}::state
    upvar #0 $svar                                  state

    # Construct argument list for procomp::run, link the logging
    # system into the UI.

    $path.e disable ; # Prevent multi-clicks from restarting the command

    procomp::setLogProc   ::tcldevkit::compiler::Log
    procomp::setErrorProc ::tcldevkit::compiler::Error
    #

    set configuration [list]
    set flags         [list] ; # Purely for logging

    lappend configuration -verbose ; # Ensure that our log procedures
    #                              ; # are not overwritten by "nullLogProc".
    lappend configuration -nologo  ; # Supress logo generation, we do our own.
    if {$state(force)} {
	lappend configuration -force
	lappend flags         -force
    }
    if {$state(out) != {}} {
	set f [file nativename $state(out)]
	lappend configuration -out $f
	lappend flags        "-out $f"
    }
    if {![string equal $state(prefix) path]} {
	lappend configuration -prefix $state(prefix)
	lappend flags        "-prefix $state(prefix)"
    } else {
	set f [file nativename $state(prefix,path)]
	lappend configuration -prefix $f
	lappend flags        "-prefix $f"
    }
    # Bugzilla 25938 ... path => f, path overwrote proc argument :(
    foreach f $state(files) {
	lappend configuration [file nativename $f]
    }

    # And run the compiler ...

    set userinfo [compiler::tdk_license user-name]
    set useremail [compiler::tdk_license user-email]
    if {$useremail ne ""} {
	append userinfo " <$useremail>"
    }
    set licinfo "| [compiler::tdk_license type] license for $userinfo."
    $path.e clear
    ::log::log info    "| $::tcldevkit::appframe::appNameV"
    ::log::log info    "| Copyright (C) 2001-2009 ActiveState Software Inc. All rights reserved."
    ::log::log info    $licinfo

    ShowConfiguration $configuration
    ::log::log notice "Compiling ..."

    foreach flag $flags {
	::log::log info "    Flag: $flag"
    }

    set res [procomp::run $configuration]

    ::log::log notice "Done"

    if {$procomp::code_bomb != {}} {
	set expire [compiler::tdk_license expiration-date]
	::log::log warning ""
	::log::log warning $licinfo
	::log::log warning "| Expires: $expire."
	::log::log warning "| "
	::log::log warning "| "
	::log::log warning "| WARNING:  All applications using the code generated by this"
	::log::log warning "|           trial version will also stop working on $expire."
    }

    $path.e enable 0 ; # Allow future runs, do not _clear_ contents
    return
}

proc ::tcldevkit::compiler::ShowConfiguration {configuration} {
    global tcl_platform

    ##parray other
    ##puts "argv = $configuration"

    # Determine name of application executable in platform specific
    # way, because we use different wrap arrangements. Unix: starkits,
    # Win: starpacks.

    if {$tcl_platform(platform) eq "windows"} {
	set appname [info nameofexecutable]
    } else {
	set appname $::argv0
    }

    ::log::log notice "Command line:"
    ::log::log info "\t$appname [Shell $configuration]"
    ::log::log notice ""
    return
}

proc ::tcldevkit::compiler::Shell {list} {
    # Convert outer! braces in the command into something a shell
    # can/will understand. Inner braces will be seen by Tcl and have
    # to stay.

    set res ""
    foreach c $list {
	if {$c ne [list $c]} {
	    set c '$c'
	}
	append res " " $c
    }
    return $res
}


# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::InitState { path } {
    set svar ::Widget::tcldevkit::compiler::${path}::state
    upvar #0 $svar                                            state

    array set state {_trace 0 files {}}

    # Add internal traces
    trace variable ${svar} w [list \
	    ::tcldevkit::compiler::StateChange $path $svar]
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::compiler::StateChange {path svar var idx op} {
    upvar #0 $svar state
    if {!$state(_trace)} {return}

    # Disable the Start button of the runwindow if the system is in
    # an unusable state.

    set ok 1
    set msg [list]

    if {[llength $state(files)] == 0} {
	set state(files,msg) "No files to compile"
	set ok 0
	lappend msg $state(files,msg)
    } else {
	set state(files,msg) ""
    }

    if {!$state(ok)} {
	set ok 0
	lappend msg $state(errmsg)
    }
    if {!$ok} {
	$path.e disable [join $msg \n]
    } else {
	$path.e enable
    }
    return
}

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

proc ::tcldevkit::compiler::Log {msg} {
    variable logwidget

    regsub -- {^compiled: } $msg {    Compiled: } msg

    ::log::log info $msg
    return
}

proc ::tcldevkit::compiler::Error {msg} {
    variable logwidget

    # We remove the textual 'error marker' here because the gui use
    # visual markup to distinguish them from the other messages.

    regsub -- {^error: } $msg {} msg
    ::log::log error $msg
    return
}

# -----------------------------------------------------------------------------

package provide tcldevkit::compiler 2.0
