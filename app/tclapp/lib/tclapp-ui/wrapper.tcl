# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# wrapper.tcl --
#
#	This file implements the main
#	start-button and logging window.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# -----------------------------------------------------------------------------

## package require prowrap ## Get prowrap functionality - Not a package
## Assume that the startup file loaded this functionality.

package require BWidget ; # BWidgets | Foundation for this mega-widget.
package require tile
Widget::theme 1
#bind . <Double-3> { console show }


# Handle Tk 8.5 (ttk) or 8.4 (tile) usage of style
namespace eval ::ttk {
    style map TEntry -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
    style map TCombobox -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
}

package require tcldevkit::wrapper::sysOptsWidget
package require tcldevkit::wrapper::wrapOptsWidget
package require tcldevkit::wrapper::appOptsWidget
package require tcldevkit::wrapper::fileWidget

package require sieditor         ; # AS package  | Show Stringfileinfo, allow editing.
package require mdeditor         ; # AS package  | Show TEApot metadata, allow editing.

#package require pkgman           ; # AS package  | Package management panel.
package require pkgman::packages ; # AS package  | Package management panel.

package require runwindow      ; # AS package  | run process, display log.
package require clogwindow     ; # AS package  | display log, clearable.
package require tipstack       ; # AS package  | Stackable tooltips
package require log            ; # Tcllib      | Logging and Tracing
package require tclapp         ; # Application | Base engine
package require tclapp::config ; # Application | Configuration
package require tclapp::banner ; # Application | Banner printing

package require logger

package require teapot::config

# -----------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::wrapper::create
#     - tcldevkit::wrapper::destroy
#     - tcldevkit::wrapper::configure
#     - tcldevkit::wrapper::cget
#     - tcldevkit::wrapper::setfocus
# -----------------------------------------------------------------------------

logger::initNamespace ::tcldevkit::wrapper
namespace eval ::tcldevkit::wrapper {
    NoteBook::use
    tcldevkit::wrapper::sysOptsWidget::use
    tcldevkit::wrapper::wrapOptsWidget::use
    tcldevkit::wrapper::appOptsWidget::use
    tcldevkit::wrapper::fileWidget::use

    Widget::declare tcldevkit::wrapper {
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-errorbackground    Color     "#FF7F50" 0}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
    }

    Widget::addmap tcldevkit::wrapper "" :cmd    {-background {}}
    Widget::addmap tcldevkit::wrapper "" .nb     {-background {} -foreground {} -font {}}
    foreach w {.os .ow .oa .f .e .l} {
	Widget::addmap tcldevkit::wrapper "" $w {
	    -background {} -foreground {} -font {} -errorbackground {}
	}
    }
    if 0 {
	Widget::addmap tcldevkit::wrapper "" .si {
	    -background {} -foreground {} -font {}
	}
	Widget::addmap tcldevkit::wrapper "" .md {
	    -background {} -foreground {} -font {}
	}
    }

    Widget::addmap tcldevkit::wrapper "" .pmp {
	-background {} -foreground {} -font {}
    }

    proc ::tcldevkit::wrapper {path args} {
	return [eval [list ::tcldevkit::wrapper::create $path] $args]
    }
    proc use {} {}

    bind wrapper <FocusIn> {::tcldevkit::wrapper::setfocus %W}
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::wrapper::create
# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::create {path args} {

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::wrapper $path $args
    namespace eval ::Widget::tcldevkit::wrapper::$path {}
    InitState $path

    set main_opt [Widget::subcget $path :cmd]
    set nb_opt   [Widget::subcget $path .nb]

    eval [list ttk::frame $path -class tcldevkit::wrapper] $main_opt

    set  nb [eval [list ttk::notebook $path.nb -padding [pad notebook]]]

    bind real${path} <Destroy> {::tcldevkit::wrapper::destroy %W; rename %W {}}

    eval [list tcldevkit::wrapper::fileWidget::create     $path.f] \
	[Widget::subcget $path .f]
    eval [list tcldevkit::wrapper::wrapOptsWidget::create $path.ow] \
	[Widget::subcget $path .ow]
    #eval [list sieditor                                   $path.si] \
    #	[Widget::subcget $path .si]
    #eval [list mdeditor                                   $path.md] \
    #	[Widget::subcget $path .md]
    eval [list pkgman::packages                           $path.pmp] \
	[Widget::subcget $path .pmp]
    ttk::frame $path.adv
    eval [list tcldevkit::wrapper::sysOptsWidget::create  $path.adv.os] \
	[Widget::subcget $path .os]
    eval [list tcldevkit::wrapper::appOptsWidget::create  $path.adv.oa] \
	[Widget::subcget $path .oa]

    eval [list runwindow $path.e] [Widget::subcget $path .e] \
	[list -label Wrap -labelhelp "Wrap application"]

    eval [list clogwindow $path.l] [Widget::subcget $path .l]

    # Link the panes together ...
    set svar ::Widget::tcldevkit::wrapper::${path}::state

    # $path.l ... Nothing to configure ...
    $path.e  disable
    $path.e      configure -command [list ::tcldevkit::wrapper::Run $path]
    $path.ow     configure -variable $svar
    #$path.si     configure -variable $svar
    #$path.md     configure -variable $svar
    $path.adv.os configure -variable $svar
    #$path.adv.oa configure -variable $svar  ; # NO variable here !
    #$path.pmp    configure -variable $svar  ; # NO variable here !
    $path.f      configure -variable $svar
    $path.pmp    configure -variable $svar \
	-config [teapot::config %AUTO%] \
	-log    [list ::tcldevkit::wrapper::LOG $path]

    #$path.pmp configure -env $path

    # Connect the package display to the state it will show and manipulate.

    #set pm [pkgman ::Widget::tcldevkit::wrapper::${path}::pkg]
    #$path.pmp configure -variable $pm
    #$pm configure -variable $svar -config [teapot::config %AUTO%]
    #-log [list ::tcldevkit::wrapper::LOG $path]

    # Generate a nice layout ...

    foreach {pkey name w class pw r c} {
	optw  Basic      .ow  tcldevkit::wrapper::wrapOptsWidget {}     0 0
	files Files      .f   tcldevkit::wrapper::fileWidget     {}     0 0
	pkgmp Packages   .pmp pkgman::packages                   {}     0 0
	opta  Advanced   .adv Frame                              {}     0 0
	opta  Advanced   .os  tcldevkit::wrapper::sysOptsWidget  {.adv} 0 0
	opta  Advanced   .oa  tcldevkit::wrapper::appOptsWidget  {.adv} 1 0
	exec  Run        .e   runwindow                          {}     0 0
	state State      .l   clogwindow                         {}     0 0
    } {
	#mded  "Metadata" .md  mdeditor                           {}     0 0
	#sied  "Kit Info" .si  sieditor                           {}     0 0
	if {$pw == {}} {
	    set page [ttk::frame $nb.$pkey -padding [pad labelframe]]
	    $nb add $page -sticky news -text $name

	    grid columnconfigure $page $r -weight 1
	    grid rowconfigure    $page $c -weight 1
	    grid $path$w     -in $page    -column $c -row $r -sticky swen
	} else {
	    grid $path$pw$w  -in $path$pw -column $c -row $r -sticky swen
	}

	bindtags $path$pw$w [list $path$pw$w $path $class [winfo toplevel $path] all]
    }

    grid columnconfigure $path.adv 0 -weight 1
    grid rowconfigure    $path.adv 0 -weight 0
    grid rowconfigure    $path.adv 1 -weight 1

    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 0 -weight 1
    grid $nb -column 0 -row 0 -sticky swen

    $nb select $nb.optw

    tipstack::defsub $path {
	.ow     {Enter basic wrapping options}
	.pmp    {Management of Packages to wrap}
	.adv    {Enter advanced options}
	.f      {Enter files to wrap}
	.e      {Start the wrapping}
	.l      {Status Log}
    }
    #	.md     {Edit the TEApot metadata of the wrap result}
    #	.si     {Edit the Windows string information of the chosen basekit}
    #	.oa        {Enter application specific options}

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::wrapper::\$cmd $path \$args\]\
	    "

    upvar #0 $svar state
    set state(_trace) 1 ; # Initialize dependent information, allow tracing Also invokes the trace!
    ::tcldevkit::appframe::markclean

    if {![log::lvIsSuppressed debug]} {
	# When debugging trace is on force everything to stdout for
	# capture (redirect to a file) instead of just showing the
	# data in the log window.
	log::lvCmdForall ::tcldevkit::wrapper::DEBUG
    }

    return $path
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::destroy
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar                                state

    if {[info exists state]} {
	# Remove internal traces
	trace vdelete ${svar} w [list ::tcldevkit::wrapper::StateChange $path]

	trace vdelete ${svar}(metadata)   w [list ::tcldevkit::wrapper::MD $path]
	trace vdelete ${svar}(stringinfo) w [list ::tcldevkit::wrapper::SI $path]
	trace vdelete ${svar}(infoplist)  w [list ::tcldevkit::wrapper::IP $path]

	unset state
    }
    return
}

# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::configure
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    eval [linsert $args 0 configure $path]
}

proc ::tcldevkit::wrapper::configure { path args } {
    # addmap -option are already forwarded to their approriate subwidgets
    set res [Widget::configure $path $args]
    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# -----------------------------------------------------------------------------
# State Log for package management. Routing through us to allow tricks with
# the notebook.
# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::LOG {path cmd level text} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar                                  state

    $path.l $cmd $level $text

    #$path.nb tab 7 cget -text
    return
}

proc ::tcldevkit::wrapper::DEBUG {level text} {
    puts "$level $text"
}

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------


proc ::tcldevkit::wrapper::getFiles { path } {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar                                  state

    set res {}
    foreach item $state(files) {
	foreach {code fpath} $item break
	if {$code ne "File"} continue
	lappend res $fpath
    }
    return $res
}

proc ::tcldevkit::wrapper::GetDefaultConfiguration {} {
    set defaultconfiguration {
	App/Code               {}	Path             {}
	Package                {}	Encoding         {}
	App/Package            {}	Wrap/NoSpecials   0 
	Wrap/Merge              0 	Wrap/Interpreter {}
	Wrap/FSMode            {}	Wrap/Icon        {}
	System/TempDir         {}	Wrap/InputPrefix {}
	System/Verbose          0	Wrap/Compile/Tcl  0
	Wrap/Compile/NoTbcload  0 	App/Argument     {}
	StringInfo             {}       Wrap/Output/OSXApp 0
	Metadata               {}       Wrap/NoProvided    0
	Pkg/Instance           {}	Pkg/Reference    {}
	Wrap/Compile/Version   {}       OSX/Info.plist   {}
	App/PostCode           {}
    }

    # Bug 76277, properly quote output path for later conversions.
    lappend defaultconfiguration \
	Wrap/Output      [list [::tcldevkit::wrapper::wrapOptsWidget::DefaultOut]] \
	Pkg/Architecture [pref::devkit::defaultArchitectures]

    #::pkgman append defaults to defaultconfiguration
    return $defaultconfiguration
}

proc ::tcldevkit::wrapper::reset {path} {
    # Reset the configuration to a clear state

    configSet $path {TclDevKit TclApp} [GetDefaultConfiguration]
    return
}

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::configuration {path args} {
    # Return configuration in a serialized, saveable format.
    # Or apply an incoming configuration after checking it.
    #
    # The chosen serialized format is a list of keys and values, as
    # accepted by [array set] (or returned by [array get]). This
    # format is easily written to file or read from it.
    #
    # The keys in the list conform to
    # 	"TclDevKit Project File Format Specification, 2.0"
    # The tool information is {TclDevKit TclApp}

    switch -exact -- [llength $args] {
	0 {
	    # Syntax: ''
	    # Meaning: cget - retrieve configuration

	    return [configGet $path]
	}
	1 {
	    # Syntax: 'tools'
	    # Meaning: Retrieve legal tool names.

	    set opt [lindex $args 0]
	    if {[string equal tools $opt]} {
		return [tclapp::config::tools]
	    } else {
		return -code error "Unknown subcommand \"$opt\", expected \"tools\""
	    }
	}
	2 {
	    # Syntax: 'keys <tool>'
	    # Meaning: Retrieve project file keys for tool <tool>.

	    set opt [lindex $args 0]
	    if {[string equal keys $opt]} {
		return [tclapp::config::keys [lindex $args 1]]
	    } else {
		return -code error "Unknown subcommand \"$opt\", expected \"keys\""
	    }
	}
	3 {
	    # Syntax: '= <cfg> <tool>'
	    # Meaning: configure - set configuration,
	    #          assuming <cfg> data in format
	    #          for the tool <tool>.

	    set opt [lindex $args 0]
	    if {![string equal = $opt]} {
		return -code error "Unknown subcommand \"$opt\", expected \"=\""
	    }

	    set data [lindex $args 1]
	    set tool [lindex $args 2]

	    configSet $path $tool $data
	}
	default {
	    return -code error "wrong#args: $path configuration ?= data?"
	}
    }
}

proc ::tcldevkit::wrapper::configGet {path} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar                                  state

    # For serialization, i.e. retrieval of the current state, we
    # remove the internal and transient information from a copy of the
    # current state.

    array set serial [array get state]
    array unset serial x,*
    array set serial [$path.adv.oa getcfg]
    array set serial [$path.pmp    getcfg]

    foreach key {
	_trace files,msg files,ok sys,msg sys,ok pkg,ok pkg,msg
	wrap,msg wrap,ok
	wrap,use wrap,use,spec wrap,use,path
    } {
	catch {unset serial($key)}
    }

    # We now have an array containing the data to save. The only
    # difference to what we want is that some of the keys used in the
    # array are wrong, i.e. they differ from the keys used in a
    # project. We fix that now.

    set   serial(paths) $serial(files)
    unset serial(files)

    # Enforce that -notbcload is not relevant without -compile.
    if {!$serial(wrap,compile)} {set serial(wrap,notbcload) 0}

    # Enforce that encodings are not relevant without a prefix
    # file to put them into.

    if {$serial(wrap,executable) eq ""} {
	set serial(encs) {}
    }

    # Create the keys which are optional while internal

    foreach k {
	pkg,repo,urls stringinfo metadata infoplist pkg,instances
    } {
	if {![info exists serial($k)]} {
	    set serial($k) {}
	}
    }

    # Tell framework that we wish some keys in multi-line form.

    set multiline {
	Pkg/Path Encoding Package Path App/Argument
	Pkg/Archive  Pkg/Architecture
	Pkg/Instance Pkg/Reference
    }

    #parray serial

    return [list $multiline __ [tclapp::config::mapOut serial]]
}

proc ::tcldevkit::wrapper::configSet {path tool data} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar                                  state

    tclapp::config::check $tool $data

    # We now know that the configuration is ok. What is left is to map
    # the external keys to the internal ones before merging the new
    # configuration into the current state.

    # We do not store the data into the engine !! Reason: The UI is
    # allowed to hold inconsistent and erroneous data. Only when
    # trying to perform the wrap full checking is required.

    set data [concat [GetDefaultConfiguration] $data]

    tclapp::config::ConvertToArray serial $data $tool

    # Move parts of the information directly to their widgets.

    if {[llength $serial(pkgs)]} {
	# Turn old-style package references over to the new system.
	# Prevent them from going to the filewidget.
	foreach p $serial(pkgs) {
	    lappend serial(pkg,references) $p
	}
	unset serial(pkgs)
    }

    if {$state(app) != {}} {
	# Application package is package, move to new system.
	# Prevent filewidget from seeing it.

	lappend serial(pkg,references) $state(app)
	unset state(app)

	# ERROR: Losing the ability to mark packages as the
	# application startup.
	#
	# Using -code {package require FOO} as replacement is not
	# possible, is executed to early during application startup.
	#
	#append serial(code) \n[list package require $state(app)]
    }

    # Push most of the information into the state array, excluding
    # only the data going explicitly to the subwidgets. This
    # automatically syncs the information to the various widgets,
    # through traces.

    # It is necessary to do this first because some of the data will
    # be needed when we talk to the sub-widgets. Example:
    # 'pkg,repo,urls' is needed by .pmp, or other wise the union
    # repository will not be set up correctly.

    array set serialb [array get serial]
    unset serialb(code)	       
    unset serialb(postcode)      
    unset serialb(args)	       
    unset serialb(pkgdirs)       
    unset serialb(pkg,references)
    array set state [array get serialb]

    $path.adv.oa setcfg code     $serial(code)           ; unset serial(code)
    $path.adv.oa setcfg postcode $serial(postcode)       ; unset serial(postcode)
    $path.adv.oa setcfg args     $serial(args)           ; unset serial(args)
    $path.adv.oa setcfg pkgdirs  $serial(pkgdirs)        ; unset serial(pkgdirs)
    $path.pmp    setcfg pkg      $serial(pkg,references) ; unset serial(pkg,references)

    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::Run {path} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar                               state

    set laststate [UserOff $path]

    $path.e clear
    GetConfiguration $path configuration errors

    # Debugging
    #set configuration [linsert $configuration 0 -debug]

    # We provide the banner directly, and always. Note that getting
    # errors when constructing a command line from the GUI state
    # indicates a bug in either the construction, or the GUI state.

    tclapp::banner::print
    if {[llength $errors]} {
	foreach e $errors {log::log error $e}
	UserOn $path $laststate
	return
    }

    # Now we invoke the regular processor as if the tool had been
    # invoked with a command line. This code is a nearly duplicate of
    # part of "tclpro/modules/wrapper/src/startup.tcl". The handling
    # of errors is a bit different.

    ShowConfiguration $configuration
    lappend configuration -force -pkg-accept

    ::log::log notice "Wrapping ..."

    set ok [tclapp::wrap_safe $configuration]

    # Back to the regular GUI stuff.

    if {$ok} {
	::log::log notice "Done"
    } else {
	::log::log error "Done with errors, please read the log"
    }
    ::tclapp::banner::print/tail

    UserOn $path $laststate
    return
}

proc ::tcldevkit::wrapper::GetConfiguration {path cv ev} {
    upvar 1 $cv configuration $ev errors

    log::debug "GetConfiguration: $path"

    # Entries in state which are relevant:
    #
    # * sys,tempdir	(-temp)			| Path
    # * sys,verbose	(-verbose)		| Boolean
    # * sys,nocompress	(-nocompress)		| Boolean
    # * wrap,executable	(-executable)		| Path
    # * wrap,compile				| Boolean
    # * wrap,notbcload  (-notbcload)		| Boolean
    # * wrap,out	(-out)			| Path
    # * paths		(files, -anchor, ...)	| Path, patterns
    # * app		(-app)			| Name
    # * pkgs		(-pkg)			| Names
    # * encs            (-encoding)             | Names
    # * pkgdirs         (-pkgdir)               | Paths
    # * wrap,interp     (-interpreter)		| Path
    # * wrap,fsmode     (-fsmode)		| transparent/writable
    # * wrap,icon       (-icon)                 | Path
    # * stringinfo      (-stringinfo)           | Dict
    # * metadata        (-metadata)             | Dict
    # * infoplist       (-infoplist)            | Dict

    # Not in state, but also relevant:

    # appOptsWidget (-code, -arguments)
    # pkgman        

    #####################################################################

    # Converting state into directives for the low-level
    # functionality.  We create an artificial command line to
    # process. This way we get the benefit of all checks performed by
    # the regular command line processor without having to duplicate
    # functionality.

    # We reuse some code: Conversion is done as if we were writing the
    # configuration to a file. Then we convert that into a list of
    # options for the engine to process.

    # Note: 'configuration' returns a three element list
    #       for consumption by the 'appframe::config' module.
    #       The actual configuration is the last element in
    #       that list.

    set configuration [lindex [configGet $path] end]

    # We have to convert the data of all non-multiline keys (which are
    # most) into a list (containing one element), to match the
    # interface of ConvertToOptions.

    set cfg [list]
    foreach {key value} $configuration {
	log::debug "CFG ($key): <$value>"

	if {[lsearch -exact  {
	    App/Package App/Code System/Verbose System/TempDir
	    Wrap/InputPrefix Wrap/Output Wrap/Compile/Tcl
	    Wrap/NoSpecials  Wrap/Merge  Wrap/Interpreter
	    Wrap/Compile/NoTbcload Wrap/FSMode Wrap/Icon
	    StringInfo Metadata OSX/Info.plist Wrap/Output/OSXApp
	    Wrap/NoProvided Wrap/Compile/Version App/PostCode
	} $key] >= 0} {
	    lappend cfg $key [list $value]
	} else {
	    lappend cfg $key $value
	}
    }

    set errors        {}
    set configuration [tclapp::config::ConvertToOptions errors $cfg]
    return
}


proc ::tcldevkit::wrapper::ShowConfiguration {configuration} {
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

    if 0 {
	foreach flag $flags {
	    ::log::log info    "    Flag: $flag"
	}
	foreach l [log::levels] {
	    puts stderr "XXX $l = [log::lvIsSuppressed $l]"
	}
    }

    return
}

proc ::tcldevkit::wrapper::Shell {list} {
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

proc ::tcldevkit::wrapper::UserOff {path} {

    $path.e disable ; # Prevent multi-clicks from restarting the command
    set laststate [$path.nb state disabled]

    return $laststate
}

proc ::tcldevkit::wrapper::UserOn {path laststate} {
    $path.e enable 0 ; # Allow future runs, do not _clear_ contents
    $path.nb state $laststate

    ::tclapp::banner::reset
    return
}

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::InitState { path } {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar                                  state

    array set state {_trace 0 x,name {} x,version {}}

    # Add internal traces
    trace variable ${svar} w [list ::tcldevkit::wrapper::StateChange $path]

    trace variable ${svar}(metadata)   w [list ::tcldevkit::wrapper::MD $path]
    trace variable ${svar}(stringinfo) w [list ::tcldevkit::wrapper::SI $path]
    trace variable ${svar}(infoplist)  w [list ::tcldevkit::wrapper::IP $path]
    return
}

# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::MD {path var idx op} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar state

    #puts MD

    array set x $state(metadata)
    if {[info exists x(name)]    && ($state(x,name)    ne $x(name))}    {SetName    $path $x(name)}
    if {[info exists x(version)] && ($state(x,version) ne $x(version))} {SetVersion $path $x(version)}
    return
}

proc ::tcldevkit::wrapper::SI {path var idx op} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar state

    #puts SI

    array set x $state(stringinfo)
    if {[info exists x(ProductName)]    && ($state(x,name)    ne $x(ProductName))}    {SetName    $path $x(ProductName)}
    if {[info exists x(ProductVersion)] && ($state(x,version) ne $x(ProductVersion))} {SetVersion $path $x(ProductVersion)}
    return
}

proc ::tcldevkit::wrapper::IP {path var idx op} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar state

    #puts IP

    array set x $state(infoplist)
    if {[info exists x(CFBundleName)]    && ($state(x,name)    ne $x(CFBundleName))}    {SetName    $path $x(CFBundleName)}
    if {[info exists x(CFBundleVersion)] && ($state(x,version) ne $x(CFBundleVersion))} {SetVersion $path $x(CFBundleVersion)}
    return
}

proc ::tcldevkit::wrapper::SetName {path newname} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar state

    #puts \tname

    SetKeyXX   $path metadata   name         $newname
    SetKeyXX   $path stringinfo ProductName  $newname
    SetKeyXX   $path infoplist  CFBundleName $newname

    set state(x,name) $newname
    return
}

proc ::tcldevkit::wrapper::SetVersion {path newversion} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar state

    #puts \tversion

    SetKeyXX   $path metadata   version         $newversion
    SetKeyXX   $path stringinfo ProductVersion  $newversion
    SetKeyXX   $path infoplist  CFBundleVersion $newversion

    set state(x,version) $newversion
    return
}

proc ::tcldevkit::wrapper::SetKeyXX {path key vkey newvalue} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar state

    if {![info exists state($key)]} return
    if {![llength $state($key)]} return
    array set x $state($key)
    if {![info exists x($vkey)]} return
    if {$x($vkey) eq $newvalue} return

    #puts SKX/$key/$vkey/$newvalue

    # Truly changed, and we have key to update.
    set x($vkey) $newvalue
    set state($key) [array get x]
    #puts "    $state($key)"
    return
}
# ------------------------------------------------------------------------------
proc ::tcldevkit::wrapper::StateChange {path var idx op} {
    set svar ::Widget::tcldevkit::wrapper::${path}::state
    upvar #0 $svar state
    if {!$state(_trace)} {return}

    #log::debug "StateChange ($var ($idx) $op) = \"$state($idx)\""

    ::tcldevkit::appframe::markdirty

    # Disable the Start button of the runwindow if the system is in
    # an unusable state. Entries to check:
    #
    # * files,ok - File panel
    # * sys,ok   - Advanced panel
    # * wrap,ok  - Wrap options panel
    # * pkg,ok   - Package mgmt panel

    set ok  1
    set msg ""

    if {[info exists state(sys,ok)]   && !$state(sys,ok)}   {set ok 0 ; lappend msg $state(sys,msg)}
    if {[info exists state(wrap,ok)]  && !$state(wrap,ok)}  {set ok 0 ; lappend msg $state(wrap,msg)}
    if {[info exists state(files,ok)] && !$state(files,ok)} {set ok 0 ; lappend msg $state(files,msg)}
    if {[info exists state(pkg,ok)]   && !$state(pkg,ok)}   {set ok 0 ; lappend msg $state(pkg,msg)}

    if {!$ok} {
	$path.e disable [join $msg \n]
    } else {
	$path.e enable
    }

    # Inform the package management GUI of changes to the set of
    # files, and or prefix.


    $path.pmp files [llength $state(files)]

    if {
	[info exists state(wrap,ok)] && $state(wrap,ok) &&
	[info exists    state(wrap,executable)] &&
	[file exists   $state(wrap,executable)] &&
	[file readable $state(wrap,executable)]
    } {
	$path.pmp Prefix $state(wrap,executable)
    } else {
	$path.pmp Prefix {}
    }
    return
}

# ------------------------------------------------------------------------------

package provide tcldevkit::wrapper 1.0
