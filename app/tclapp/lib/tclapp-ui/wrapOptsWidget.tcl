# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# wrapOptsWidget.tcl --
#
#	This file implements a widget for entering the basic wrap options.
#
# Copyright (c) 2002-2008 ActiveState Software Inc.

# 
# RCS: @(#) $Id: $
#
# -----------------------------------------------------------------------------

package require BWidget           ; # BWidgets | Foundation for this mega-widget.
package require fileutil
package require ico 1
package require image ; image::file::here
package require img::ico
package require img::png
package require ipeditor
package require mdeditor
package require pkgman::architectures
package require pref              ; # Preference core package.
package require pref::devkit      ; # TDK shared package : Global TDK preferences.
package require sieditor
package require stringfileinfo
package require tclapp::misc
package require tipstack
package require widget::dialog
package require pkgman::plist
package require mafter            ; # Delayed validation processing.

# -----------------------------------------------------------------------------
#  Index of commands:
#     - tcldevkit::wrapper::wrapOptsWidget::create
#     - tcldevkit::wrapper::wrapOptsWidget::destroy
#     - tcldevkit::wrapper::wrapOptsWidget::configure
#     - tcldevkit::wrapper::wrapOptsWidget::cget
#     - tcldevkit::wrapper::wrapOptsWidget::setfocus
#     - tcldevkit::wrapper::wrapOptsWidget::log
# -----------------------------------------------------------------------------

namespace eval ::tcldevkit::wrapper::wrapOptsWidget {

    Widget::declare tcldevkit::wrapper::wrapOptsWidget {
	{-variable	     String     ""     0}
        {-foreground         TkResource ""     0 button}
        {-background         TkResource ""     0 button}
        {-errorbackground    Color     "#FFFFE0" 0}
        {-font               TkResource ""     0 text}
        {-fg                 Synonym    -foreground}
        {-bg                 Synonym    -background}
    }

    Widget::addmap tcldevkit::wrapper::wrapOptsWidget "" :cmd {-background {}}

    foreach w {
	.exec   .exec.b   .exec.e .exec.l .exec.k
	.interp .interp.b .interp.e
	.out    .out.b    .out.e  .out.merge .out.osx
	.fsmode .fsmode.default .fsmode.write .fsmode.transp
	.mod.compile
	.mod.nospecials
	.mod.notbcload
	.mod.noprovided
	.icon.l .icon.e .icon.b
    } {
	Widget::addmap tcldevkit::wrapper::wrapOptsWidget "" $w {
	    -background {} -foreground {} -font {}
	}
    }

    proc ::tcldevkit::wrapper::wrapOptsWidget {path args} {
	return [eval [list wrapOptsWidget::create $path] $args]
    }
    proc use {} {}

    bind wrapOptsWidget <FocusIn> {::tcldevkit::wrapper::wrapOptsWidget::setfocus %W}

    # Widget class data
    set ::Widget::tcldevkit::wrapper::wrapOptsWidget::keymap {
	out        wrap,out
	exec       wrap,executable
	interp     wrap,interp
	fsmode     wrap,fsmode
	compile    wrap,compile
	compilefor wrap,compilefor
	merge      wrap,merge
	osx        wrap,out,osx
	nospecials wrap,nospecials
	noprovided wrap,noprovided
	ok         wrap,ok
	errmsg     wrap,msg
	encs       encs
	notbcload  wrap,notbcload
	icon       wrap,icon
	out,arch   pkg,platforms
    }
    set ::Widget::tcldevkit::wrapper::wrapOptsWidget::keymap_r {
	wrap,out        out
	wrap,out,osx	osx
	wrap,executable exec
	wrap,interp     interp
	wrap,fsmode     fsmode
	wrap,compile    compile
	wrap,compilefor compilefor
	wrap,nospecials nospecials
	wrap,noprovided noprovided
	wrap,merge      merge
	wrap,ok	        ok
	wrap,msg	errmsg
	encs            encs
	wrap,notbcload  notbcload
	wrap,icon       icon
    }
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::wrapper::wrapOptsWidget::create
# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::create { path args } {
    global tcl_platform

    # Initialize the private state, validate, store and link to the value of
    # option "-variable".

    Widget::init tcldevkit::wrapper::wrapOptsWidget $path $args
    namespace eval ::Widget::tcldevkit::wrapper::wrapOptsWidget::$path {}

    InitState             $path
    ValidateStoreVariable $path

    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    set main_opt [Widget::subcget $path :cmd]

    eval [list ttk::frame $path \
	      -class tcldevkit::wrapper::wrapOptsWidget] $main_opt

    bind real${path} <Destroy> {tcldevkit::wrapper::wrapOptsWidget::destroy %W; rename %W {}}

    set base {
	ttk::labelframe  .out        {-text "Output file"}
	ttk::labelframe  .exec       {-text "Prefix file"}
	ttk::labelframe  .icon       {-text "Custom icon"}
	ttk::labelframe  .interp     {-text "Interpreter"}
	ttk::labelframe  .mod        {-text "Modifier"}
	ttk::labelframe  .fsmode     {-text "Make Application Writable"}
    }
    set sub {
	ttk::button      .out    .b          {-text "Browse..."}
	ttk::entry       .out    .e          {}
	ttk::checkbutton .out    .merge      {-text "Merge selected files"}
	ttk::checkbutton .out    .osx        {-text "Make an OS X Application Bundle"}
	ttk::button      .out    .md         {-text "Meta Data..."}
	ttk::button      .out    .ip         {-text "OS X Info.plist..."}
	ttk::button      .out    .arch       {-text "Architectures..."}
	ttk::button      .out    .sinfo      {-text "Win32 String Resources..."}

	ttk::label       .exec   .l          {-anchor w -justify left -text "No icon"}
	ttk::button      .exec   .b          {-text "Browse..."}
	ttk::button      .exec   .k          {-text "Browse TEAPOT..."}
	ttk::combobox    .exec   .e          {-values {}}
	ttk::button      .exec   .esel       {-text "Select Encodings..."}
	ttk::label       .exec   .elbl       {-anchor w -justify left}
	ttk::button      .exec   .pprov      {-text "Provided packages..."}

	ttk::label       .icon   .l          {-anchor w -justify left -text "No icon"}
	ttk::combobox    .icon   .e          {-values {} -state disabled}
	ttk::button      .icon   .b          {-text "Browse..."         -state disabled}

	ttk::button      .interp .b          {-text "Browse..."}
	ttk::combobox    .interp .e          {-values {}}
	ttk::checkbutton .mod    .compile    {-text "Compile .tcl files"}
	ttk::checkbutton .mod    .nospecials {-text "Suppress special files"}
	ttk::checkbutton .mod    .noprovided {-text "Suppress list of packages wrapped in the prefix"}
	ttk::checkbutton .mod    .notbcload  {-text "(no tbcload)"}
	ttk::combobox    .mod    .tclver     {-values {{} 8.4 8.5}}
	ttk::radiobutton .fsmode .default    {-text "Default"     -value {}}
	ttk::radiobutton .fsmode .transp     {-text "Transparent" -value transparent}
	ttk::radiobutton .fsmode .write      {-text "Writable"    -value writable}
    }
    # sinfo - aka 'Windows Resource Strings'.
    # We need a better button label here. Or maybe an image ?
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
	.fsmode.default -variable     fsmode
	.fsmode.transp  -variable     fsmode
	.fsmode.write   -variable     fsmode
	.mod.compile    -variable     compile
	.mod.nospecials -variable     nospecials
	.mod.noprovided -variable     noprovided
	.mod.notbcload  -variable     notbcload
	.mod.tclver     -textvariable compilefor
	.out.e          -textvariable out
	.out.merge      -variable     merge
	.out.osx        -variable     osx
	.exec.e         -textvariable exec
	.icon.e         -textvariable icon
	.interp.e       -textvariable interp
    } {
	$state($w) configure $opt \
		::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state($key)
    }

    $state(.out.b) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::chooseOut $path] \
	-image [image::get file]

    $state(.out.md) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::MetadataOpen $path] \
	-image [image::get comments]

    $state(.out.ip) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::OSXIPOpen $path] \
	-image [image::get comments]

    $state(.out.arch) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::ArchOpen $path] \
	-image [image::get server]

    $state(.out.sinfo) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::StringInfoOpen $path] \
	-image [image::get note]

    $state(.exec.b) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::chooseExec $path] \
	-image [image::get file]

    # Browse for prefix in the configured teapot repositories.
    $state(.exec.k) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::chooseExecTeapot $path] \
	-image [image::get package_add]

    $state(.exec.e) configure \
	-values [pref::prefGet prefixList]

    $state(.exec.esel) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::EncodingsSelect $path] \
	-image [image::get font]

    $state(.exec.pprov) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::PProvOpen $path] \
	-image [image::get package_green]

    $state(.icon.b) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::IconSelect $path] \
	-image [image::get file]

    $state(.icon.e) configure \
	-values [pref::prefGet iconList]

    $state(.interp.b) configure -command [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::chooseInterp $path] \
	-image [image::get file]

    $state(.interp.e) configure \
	-values [pref::prefGet interpList]

    bindtags $path [list real${path} wrapOptsWidget [winfo toplevel $path] all]

    ## 2.6.1. retraction: Do not expose feature 'Make Application Writeable' for this version.
    ## was after .interp:
    ## 	.fsmode      0 2 swen 1m 1m 1

    foreach {slave col row stick padx pady colspan} {
	.exec        0 0 swen 1m 1m 1
	.icon        0 1 swen 1m 1m 1
	.interp      0 2 swen 1m 1m 1
	.mod         0 3 swen 1m 1m 1
	.out         0 4 swen 1m 1m 1

	.out.merge   0 0 swen 1m 1m 1
	.out.osx     1 0 swn  1m 1m 4
	.out.e       0 1 swen 1m 2m 4
	.out.b       4 1   wn 1m 2m 1

	.out.arch    0 2   wn 1m 1m 1
	.out.md      1 2   wn 1m 1m 1
	.out.ip      2 2   wn 1m 1m 1
	.out.sinfo   3 2   wn 1m 1m 1

	.exec.l      0 0  w   1m 2m 1
	.exec.e      1 0  we  1m 2m 2
	.exec.b      3 0  wen 1m 2m 1
	.exec.k      3 1  wen 1m 2m 1
	.exec.esel   0 1  wn  1m 1m 2
	.exec.elbl   2 1 swen 2m 1m 1
	.exec.pprov  0 2  wn  1m 1m 2

	.icon.l      0 0  w   2m 2m 1
	.icon.e      1 0  we  1m 2m 1
	.icon.b      2 0  wen 1m 2m 1

	.interp.e    0 0 swen 1m 2m 2
	.interp.b    2 0 swen 1m 2m 1

	.fsmode.default   0 0 swen 1m 1m 1
	.fsmode.transp    0 1 swen 1m 1m 1
	.fsmode.write     0 2 swen 1m 1m 1

	.mod.compile    0 0 swen 1m 1m 1
	.mod.tclver     1 0 swen 1m 1m 1
	.mod.notbcload  2 0 swen 1m 1m 1
	.mod.nospecials 0 1 swen 1m 1m 1
	.mod.noprovided 1 1 swen 1m 1m 2
    } {
	grid $state($slave) -columnspan $colspan -column $col -row $row -sticky $stick -padx $padx -pady $pady
    }

    foreach {master col weight} {
	{}      0 1
	.out    0 0
	.out    1 0
	.out    2 0
	.out    3 1
	.out    4 0
	.exec   0 0
	.exec   1 0
	.exec   2 1
	.exec   3 0
	.icon   0 0
	.icon   1 1
	.icon   2 0
	.interp 0 0
	.interp 1 1
	.interp 2 0
	.fsmode 0 0
	.fsmode 1 1
	.mod    0 0
	.mod    1 0
	.mod    2 1
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid columnconfigure $_w $col -weight $weight
    }
    foreach {master row weight} {
	{}      0 0
	{}      1 0
	{}      2 0
	{}      3 0
	{}      4 0
	{}      5 0
	{}      6 1
	.exec   0 1
	.exec   1 1
	.exec   2 1
	.exec   3 1
	.icon   0 1
	.interp 0 1
	.fsmode 0 0
	.fsmode 1 0
	.fsmode 2 0
	.fsmode 3 1
    } {
	set _w $path$master
	if {[info exists state($master)]}   {set _w $state($master)}
	if {[info exists state($master,f)]} {set _w $state($master,f)}
	grid rowconfigure $_w $row -weight $weight
    }

    # Initially disabled as compilation is off initially too.
    $state(.mod.notbcload) configure -state disabled

    tipstack::defsub $path {
	.out        {Output metakit file, written by wrapper}
	.mod        {Modifiers for the wrap process}
	.exec       {Input metakit FS file for wrapped application}
	.icon       {Customize the icon of the prefix file}
	.interp     {Interpreter for wrapped application}
	.fsmode     {Writability of the generated application.

In other words, choose how far the wrapped application can go
when writing to itself.}
    }
    tipstack::def [list \
	    $state(.mod.compile)    {Compile the chosen .tcl files before wrapping} \
	    $state(.mod.nospecials) {Suppress the generation of file /main.tcl} \
	    $state(.mod.noprovided) {Suppress the generation of file /teapot_provided.txt} \
	    $state(.mod.notbcload)  {Do not wrap package 'tbcload' implicitly when compiling .tcl files} \
	    $state(.mod.tclver)     {Version of Tcl to compile for} \
	    $state(.out.b)     {Browse for output executable} \
	    $state(.out.e)     {Enter output executable.

This is the name of the file
to be generated by TclApp} \
	    $state(.out.merge) {Merge the chosen files into an existing output file.} \
	    $state(.out.osx)   {Make the result an OS X Application Bundle.} \
            $state(.out.md)    {Edit the TEApot meta data of the wrap result} \
            $state(.out.ip)    {Edit the OS X Info.plist meta data of the wrap result} \
            $state(.out.sinfo) {Edit the Win32 String Resources of the wrap result, if present} \
            $state(.out.arch)  {Set the architecture of the wrap result} \
	    $state(.exec.l)    {The icon embedded in the prefix file} \
	    $state(.exec.b)    {Browse for prefix file} \
	    $state(.exec.k)    {Browse for prefix in the configured TEAPOT repositories} \
	    $state(.exec.e)    {Enter prefix file.

When specified a copy of this file is used as the base (prefix) for the output.
To generate a Starpack a TclKit has to be used as the prefix file.
Do not use this field when merging files into an existing output file.} \
            $state(.exec.esel) {Select the encodings to add to the wrapped application} \
            $state(.exec.pprov) {Show the packages wrapped in the prefix file} \
	    $state(.icon.l)    {The custom icon to embed in the result} \
	    $state(.icon.e)    {Enter file containing a custom icon} \
	    $state(.icon.b)    {Browse for a custom icon for the application} \
	    $state(.interp.b)  {Browse for interpreter} \
	    $state(.interp.e)  {Enter interpreter.

When specified the chosen path is inserted into the starkit header of
the chosen prefix file as the interpreter to run the generated
starkit. This option is not accessible if the prefix file does not
support the operation (basekits and tclkits for example do not provide
such support as they are the interpreter used to run the application
by themselves).

Do not use this field when merging files into an existing output file.} \
	$state(.fsmode.default) {The default mode is like 'transparent' below,
except that this can be used when merging files into an existing
output file.} \
	$state(.fsmode.transp) {In transparent mode the application is allowed write files to its own
virtual filesystem, but these files will be lost after the application
exits.

Do not use this field when merging files into an existing output file.} \
	$state(.fsmode.write) {If the application is made 'writable' new virtual files will be
automatically written into the application file on disk, and are
therefore persistent across several invocations of the
application. Because of this it is required that the application file
on disk is writable from the OS point of view too.

This option is not accessible if the prefix file does not support the
operation (basekits and tclkits for example do not provide such
support as the operating system will forbid writing to the file of a
running executable).

Do not use this field when merging files into an existing output file.} \
    ]

    elabel $path

    rename $path ::$path:cmd
    proc ::$path {cmd args} "\
	    return \[eval ::tcldevkit::wrapper::wrapOptsWidget::\$cmd $path \$args\]\
	    "

    # More init of dynamic state (dependent state).

    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    OSXOkActual  $path $svar
    #called by OSXOk : ExecOkActual $path $svar
    return $path
}

proc ::tcldevkit::wrapper::wrapOptsWidget::elabel {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    set n [llength $state(encs)]
    set t "$n additional encoding[expr {($n==1) ? "" : "s"}] selected"

    if {([$state(.exec.esel) cget -state] eq "disabled") && ($n > 0)} {
	append t " (not used, no valid prefix)"
    }

    $state(.exec.elbl) configure -text $t
    return
}


# -----------------------------------------------------------------------------
#  Command tcldevkit::wrapper::wrapOptsWidget::destroy
# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::destroy { path } {
    Widget::destroy

    tipstack::clearsub $path

    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::linkvar
    variable $svar

    if {[info exists linkvar]} {
	if {$linkvar != {}} {
	    # Remove the traces for linked variable, if existing
	    trace vdelete $linkvar w [list \
		    ::tcldevkit::wrapper::wrapOptsWidget::TraceIn $path $linkvar]
	    trace vdelete $svar    w [list \
		    ::tcldevkit::wrapper::wrapOptsWidget::TraceOut $path $svar]
	}
	unset linkvar
    }
    if {[info exists state]} {
	# Kill the validation delay timers.
	$state(/ma,out)    destroy
	$state(/ma,exec)   destroy
	$state(/ma,interp) destroy
	$state(/ma,fsmode) destroy
	$state(/ma,merge)  destroy
	$state(/ma,icon)   destroy
	$state(/ma,osx)    destroy
	$state(/ma,ok)     destroy
	$state(/ma,comp)   destroy
	$state(/ma,comf)   destroy

	# Remove internal traces
	trace vdelete ${svar}(out) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::OutOk $path $svar]
	trace vdelete ${svar}(exec) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::ExecOk $path $svar]
	trace vdelete ${svar}(interp) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::InterpOk $path $svar]
	trace vdelete ${svar}(fsmode) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::FsmodeOk $path $svar]
	trace vdelete ${svar}(merge) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::MergeOk $path $svar]
	trace vdelete ${svar}(icon) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::IconOk $path $svar]
	trace vdelete ${svar}(osx) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::OSXOk $path $svar]

	trace vdelete ${svar}(out,ok) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::Ok $path $svar]
	trace vdelete ${svar}(exec,ok) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::Ok $path $svar]
	trace vdelete ${svar}(interp,ok) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::Ok $path $svar]
	trace vdelete ${svar}(fsmode,ok) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::Ok $path $svar]

	trace vdelete ${svar}(compile) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::CompileProp $path $svar]
	trace vdelete ${svar}(compilefor) w [list \
		::tcldevkit::wrapper::wrapOptsWidget::CompileFor $path $svar]
	unset state
    }
    return
}

# -----------------------------------------------------------------------------
#  Command tcldevkit::wrapper::wrapOptsWidget::configure
# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::config { path args } {
    if {[llength $args] == 0} {
	return "Can't retrieve all options"
    }
    return [eval [linsert $args 0 configure $path]]
}

proc ::tcldevkit::wrapper::wrapOptsWidget::configure { path args } {
    # addmap -option are already forwarded to their appriopriate subwidgets
    set res [Widget::configure $path $args]

    # Handle -variable and -errorbackground.

    if {[Widget::hasChanged $path -variable dummy]} {
	ValidateStoreVariable $path
    }
    return $res
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::wrapOptsWidget::cget
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command tcldevkit::wrapper::wrapOptsWidget::setfocus
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::setfocus { path } {
    focus $path ; return

    set w [Widget::cget $path -focus]
    if { [winfo exists $w] && [Widget::focusOK $w] } {
	focus $w
    }
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::ValidateStoreVariable { path } {

    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::linkvar

    set newvar [Widget::getoption $path -variable]
    if {[string equal $newvar $linkvar]} {
	# -variable unchanged.
	return
    }

    # -variable was changed.

    if {$newvar == {}} {
	# The variable was disconnected from the widget. Remove the traces.

	trace vdelete $linkvar w [list \
		::tcldevkit::wrapper::wrapOptsWidget::TraceIn $path $linkvar]
	trace vdelete $svar    w [list \
		::tcldevkit::wrapper::wrapOptsWidget::TraceOut $path $svar]

	set linkvar ""
	return
    }

    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

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
		::tcldevkit::wrapper::wrapOptsWidget::TraceIn $path $newvar]
	trace variable $svar   w [list \
		::tcldevkit::wrapper::wrapOptsWidget::TraceOut $path $svar]

	set linkvar $newvar
	return
    }

    # Changed from one variable to the other. Remove old traces, setup
    # new ones, copy relevant information of state!

    trace vdelete $linkvar w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::TraceIn $path $linkvar]
    trace vdelete $svar    w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::TraceOut $path $svar]

    CopyState $path $newvar

    trace variable $newvar w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::TraceIn $path $linkvar]
    trace variable $svar   w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::TraceOut $path $svar]

    set linkvar $newvar
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::CopyState { path var } {
    upvar #0 ::Widget::tcldevkit::wrapper::wrapOptsWidget::keymap  map
    upvar #0 $var                                                  data
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    foreach {inkey exkey} $map {
	set data($exkey) $state($inkey)
    }
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::InitState {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable $svar
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::linkvar

    set linkvar ""
    array set state {
	compile     0 compilefor {} cfuser 0 cft 0 cftkey {}
	merge       0
	osx         0
	nospecials  0
	noprovided  0
	notbcload   0
	out         ""  out,ok    1 out,msg    ""  out,last  {}
	exec        ""  exec,ok   1 exec,msg   ""  exec,last {}
	interp      ""  interp,ok 1 interp,msg ""
	fsmode      ""  fsmode,ok 1 fsmode,msg ""
	ok          1
	errmsg      ""
	trace       ""
	encs        {}
	icon          {} icon,ok 1
	exec,icache   {}
	exec,icondata {}
	exec,icondesc {}
	exec,rcache   {}
	out,arch      {}
	out,arch,user 0
    }
    set state(out) [DefaultOut]

    # Query preferences for the default path to browse to when
    # looking for prefix files, i.e. basekits.

    set pp [pref::prefGet prefixPath]
    set ip [pref::prefGet interpPath]
    set cp [pref::prefGet iconPath]

    set changes 0
    if {$pp eq ""} {
	# If there is no suitable default generate one, and save it as
	# well.

	set pp [pwd]
	pref::prefSet   GlobalDefault prefixPath $pp
	set changes 1
    }
    if {$ip eq ""} {
	# If there is no suitable default generate one, and save it as
	# well.

	set ip [pwd]
	pref::prefSet   GlobalDefault interpPath $ip
	set changes 1
    }
    if {$cp eq ""} {
	# If there is no suitable default generate one, and save it as
	# well.

	set cp [pwd]
	pref::prefSet   GlobalDefault iconPath $cp
	set changes 1
    }
    if {$changes} {
	pref::groupSave GlobalDefault
    }

    set state(lastdir,exec)   $pp
    set state(lastdir,out)    [pwd]
    set state(lastdir,use)    [pwd]
    set state(lastdir,interp) $ip
    set state(lastdir,icon)   $cp

    # Internal traces computing the ok/fail state of the entered information.

    trace variable ${svar}(out) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::OutOk $path $svar]
    trace variable ${svar}(exec) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::ExecOk $path $svar]
    trace variable ${svar}(interp) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::InterpOk $path $svar]
    trace variable ${svar}(fsmode) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::FsmodeOk $path $svar]
    trace variable ${svar}(merge) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::MergeOk $path $svar]
    trace variable ${svar}(icon) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::IconOk $path $svar]
    trace variable ${svar}(osx) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::OSXOk $path $svar]

    trace variable ${svar}(out,ok) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::Ok $path $svar]
    trace variable ${svar}(exec,ok) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::Ok $path $svar]
    trace variable ${svar}(interp,ok) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::Ok $path $svar]
    trace variable ${svar}(fsmode,ok) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::Ok $path $svar]

    trace variable ${svar}(compile) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::CompileProp $path $svar]
    trace variable ${svar}(compilefor) w [list \
	    ::tcldevkit::wrapper::wrapOptsWidget::CompileFor $path $svar]

    # The actual validation processing is decoupled from the traces
    # via 'after x', the timers are handled by the objects we now
    # create ...

    set state(/ma,out)    [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::OutOkActual $path $svar]]
    set state(/ma,exec)   [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::ExecOkActual $path $svar]]
    set state(/ma,interp) [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::InterpOkActual $path $svar]]
    set state(/ma,fsmode) [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::FsmodeOkActual $path $svar]]
    set state(/ma,merge)  [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::MergeOkActual $path $svar]]
    set state(/ma,icon)   [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::IconOkActual $path $svar]]
    set state(/ma,osx)    [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::OSXOkActual $path $svar]]
    set state(/ma,ok)     [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::OkActual $path $svar]]
    set state(/ma,comp)   [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::CPActual $path $svar]]
    set state(/ma,comf)   [mafter %AUTO% 500 [list ::tcldevkit::wrapper::wrapOptsWidget::CFActual $path $svar]]
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::TraceIn { path tvar var idx op } {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    # Lock out TraceIn if it is done in response to a change in the widget itself.

    ##puts "TraceIn { $path $var /$idx/ $op }"
    ##parray state

    if {[string equal $state(trace) out]} {return}

    upvar #0 $tvar data
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::keymap_r

    array set tmp $keymap_r
    if {[info exists tmp($idx)]} {set inkey $tmp($idx)} else {return}
    set state($inkey) $data($idx)

    if {[string equal $inkey "encs"]} {elabel $path}
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::TraceOut { path tvar var idx op } {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::keymap
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::linkvar
    upvar #0 $linkvar data $tvar state

    ##puts "TraceOut { $path $var /$idx/ $op }"
    ##parray state

    array set tmp $keymap
    if {[info exists tmp($idx)]} {set exkey $tmp($idx)} else {return}

    set state(trace) out
    set data($exkey) $state($idx)
    set state(trace) ""
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::CFT {path svar} {
    upvar #0 $svar state

    log::log debug wrapOptsWidget::CFT/begin

    if {$state(cft)} {
	log::log debug wrapOptsWidget::CFT/denied-already-in-progress
	return
    }

    set state(cft) 1

    tipstack::pop $state(.mod.tclver)
    $state(.mod.tclver) configure -state disabled

    set message {Version of Tcl to compile for}

    if {!$state(compile)} {
	tipstack::push $state(.mod.tclver) $message

	set state(compilefor) {}
	set state(cfuser) 0
	set state(cft) 0

	log::log debug wrapOptsWidget::CFT/done/!compile
	return
    }

    # CFT can be called if and only if the prefix temp file has been
    # retrieved.
    if {[tclapp::misc::isTeapotPrefix $state(exec)]} {
	set arfile $state(exec,temp)
    } else {
	set arfile $state(exec)
    }

    set key [list $state(merge) $state(out) $arfile]

    log::log debug wrapOptsWidget::CFT/(last,key=($state(cftkey)))
    log::log debug wrapOptsWidget::CFT/(next,key=($key))

    if {$key eq $state(cftkey)} {
	log::log debug wrapOptsWidget::CFT/Cached/SameKey

	# Scan requested, data not changed, report from cache.
	foreach {v fallback msg} $state(cftcache) break
    } else {
	log::log debug wrapOptsWidget::CFT/Changed/Run

	# Perform scan on actual key changes.
	set v [tclapp::misc::CFT $state(merge) $state(out) $arfile fallback msg]

	set state(cftkey)   $key
	set state(cftcache) [list $v $fallback $msg]
    }

    if {!$fallback} {
	append message \n$msg
	tipstack::push $state(.mod.tclver) $message

	set state(compilefor) $v
	set state(cfuser) 0
	set state(cft) 0

	log::log debug wrapOptsWidget::CFT/done/normal
	return
    }

    # We can allow the user to choose the version if and only if the
    # system could not determine the version on its own.

    $state(.mod.tclver) configure -state normal

    if {!$state(cfuser)} {
	append message \n$msg
	tipstack::push $state(.mod.tclver) $message

	set state(compilefor) $v
	set state(cfuser) 0
	set state(cft) 0

	log::log debug wrapOptsWidget::CFT/done/fallback,!user
	return
    }

    append message "\nChosen by the user"
    tipstack::push $state(.mod.tclver) $message
    set state(cft) 0

    log::log debug wrapOptsWidget::CFT/done
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::CompileFor {path svar var idx op} {
    upvar #0 $svar state
    if {$state(cft)} return
    $state(/ma,comf) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::CFActual {path svar} {
    upvar #0 $svar state

    if {$state(cft)} return

    set state(cfuser) 1

    # Defer actual computation if a prefix is in retrieval, will be
    # done when retrieval is complete.
    if {[info exists state(exec,/get)]} return

    CFT $path $svar
    return
}


proc ::tcldevkit::wrapper::wrapOptsWidget::CompileProp {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma,comp) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::CPActual {path svar} {
    upvar #0 $svar state

    # Deactivate the '-notbcload' switch depending on whether we wish
    # to compile tcl code or not.

    if {!$state(compile)} {
	$state(.mod.notbcload) configure -state disabled
    } else {
	$state(.mod.notbcload) configure -state normal
    }

    # Defer actual computation if a prefix is in retrieval, will be
    # done when retrieval is complete.
    if {[info exists state(exec,/get)]} return

    CFT $path $svar
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::MergeOk {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma,merge) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::MergeOkActual {path svar} {
    # Changing the value of merge influences the validity of the prefix
    # and output files, also of the chosen interpreter, if any.

    OutOkActual    $path $svar
    ExecOkActual   $path $svar
    ## InterpOk $path $svar Not required, done in ExecOk.
    ## FsmodeOk $path $svar Not required, done in ExecOk.
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::OutOk {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma,out) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::OutOkActual {path svar} {
    upvar #0 $svar state

    set ok 1
    set file $state(out)
    set edir [file dirname $file]

    if {$file == {}} {
	# An empty name is ok, it just means that the default output is used.
	#set state(out,msg) ""
	# NO. We use a default value here, and forbid emptiness.
	set state(out,msg) "No output file was chosen"
	set ok 0
    } elseif {![file exists $edir]} {
	set state(out,msg) "Path to output file does not exist: $edir"
	set ok 0
    } elseif {![file isdirectory $edir]} {
	set state(out,msg) "Path to output file is not a directory: $edir"
	set ok 0
    } elseif {![file writable $edir]} {
	set ok 0
	set state(out,msg) "Path to output file is not writeable: $edir"
    } elseif {$state(merge)} {
	# Merging active means that the output file itself has to
	# exist, has to be file, has to be writable, and has to be a
	# metakit FS. For a regular output. For an OSX .app bundle it
	# has to be a bit different: Existing, directory, specific
	# subdirectory, specific existing, writable file with a
	# metakit FS in that subdir.

	if {$state(osx)} {
	    set tfile $file
	    if {[file extension $tfile] ne ".app"} {append tfile .app}

	    if {![file exists $tfile]} {
		set state(out,msg) "Output app bundle directory (for merge) does not exist: $tfile"
		set ok 0
	    } elseif {![file isdirectory $tfile]} {
		set state(out,msg) "Output app bundle (for merge) is not a directory: $tfile"
		set ok 0
	    } else {
		set exedir [file join $tfile Contents MacOS]
		set pat    [file rootname [file tail $file]]*

		set exelist [glob -nocomplain -directory $exedir $pat]

		if {[llength $exelist] < 1} {
		    set state(out,msg) "Output app bundle (for merge) has no executable"
		    set ok 0
		} elseif {[llength $exelist] > 1} {
		    set state(out,msg) "Output app bundle (for merge) has several possible executables"
		    set ok 0
		} else {
		    set exe [lindex $exelist 0]

		    if {![file writable $exe]} {
			set ok 0
			set state(out,msg) "Output file (for merge) is not writeable: $exe"
		    
		    } elseif {![tclapp::misc::IsWrapCore $exe emsg]} {
			# The low-level engine declares that the
			# chosen file is not an acceptable output
			# file. We take its error message as our own.

			set ok 0
			set state(out,msg) $emsg
		    } else {
			set state(out,msg) ""
		    }
		}
	    }
	} else {
	    if {![file exists $file]} {
		set state(out,msg) "Output file (for merge) does not exist: $file"
		set ok 0
	    } elseif {![file isfile $file]} {
		set state(out,msg) "Output file (for merge) is not a file: $file"
		set ok 0
	    } elseif {![file writable $file]} {
		set ok 0
		set state(out,msg) "Output file (for merge) is not writeable: $file"
	    } elseif {![tclapp::misc::IsWrapCore $file emsg]} {
		# The low-level engine declares that the chosen file is not an
		# acceptable output file. We take its error message as our own.

		set ok 0
		set state(out,msg) $emsg
	    } else {
		set state(out,msg) ""
	    }
	}
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

    # Defer actual computation while a prefix is in retrieval, will be
    # done when retrieval is complete, through ExecOk.
    if {[info exists state(exec,/get)]} return

    CFT $path $svar
    UpdateArch $path
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecImgOff {statevar reason} {
    upvar 1 $statevar state

    set tip "A customization of the icon is not possible.\nThis is because $reason"

    $state(.exec.l) configure -image {}

    foreach w {.exec.l .icon.b .icon.e .icon.l} {
	tipstack::pop  $state($w)
	tipstack::push $state($w) $tip
    }

    $state(.icon.b) configure -state disabled
    $state(.icon.e) configure -state disabled
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecImgOn {statevar} {
    upvar 1 $statevar state

    $state(.exec.l) configure -image $state(exec,icondata)

    # Update tooltips
    tipstack::pop  $state(.exec.l)
    tipstack::push $state(.exec.l) \
	    "The icon embedded in the prefix \
	    file.\nVariants found:\n\n$state(exec,icondesc)"

    $state(.icon.b) configure -state normal
    $state(.icon.e) configure -state normal
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecOk {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma,exec) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::ExecOkActual {path svar} {
    upvar #0 $svar state

    set ok   1
    set icon 1 ; # May have an icon
    set res  1 ; # May have windows resources.
    set pot  0 ; # Is a teapot-reference
    set state(exec,msg) ""

    $state(.exec.esel) configure -state normal
    elabel $path

    #Bug 77097
    #$state(.interp.e)   configure -state normal
    $state(.out.sinfo)  configure -state normal
    $state(.exec.pprov) configure -state normal
    tipstack::pop $state(.exec.e)
    tipstack::pop $state(.exec.pprov)

    if {[tclapp::misc::isTeapotPrefix $state(exec)]} {
	# Teapot prefix. If we have a temp file for it already we use
	# that for our checks. Otherwise we bail out without doing any
	# of our checks.

	foreach {n v a} [tclapp::misc::splitTeapotPrefix $state(exec)] break

	if {($n eq "") || ($v eq "") || ($a eq "") || [catch {
	    set instance [teapot::instance::cons application $n $v $a]
	}]} {
	    # The data is syntactically bogus, ignore any temp file we
	    # may have, do not try to regenerate anything either.
	    # Message it directly as syntax error.
	    set icon 0
	    set res 0
	    set ok 0
	    set state(exec,msg) "Prefix syntax error in teapot reference: $state(exec)"
	    set file ""
	} else {
	    # Data is good enough, now check for cached valid temp file.

	    if {![info exists state(exec,temp)]} {
		if {[info exists state(exec,/get)]} {
		    # No temp file, and currently in process of retrieval. Ignore call
		    # and wait for completion of retrieval.
		} else {
		    # No temp file, not in retrieval, start retrieval, then wait.
		    GetExecTeapot $path $state(exec) $instance
		}
		DisablePartsWaitingForTeapot $path
		return
	    }

	    if {$state(exec) ne $state(exec,tempref)} {
		# exec has changed relative to the data for temp,
		# therefore invalidate temp, and start the process to
		# regenerate it.

		ClearExecTeapot $path
		GetExecTeapot $path $state(exec) $instance
		DisablePartsWaitingForTeapot $path
		return
	    } else {

		# Data is aligned, run the regular checks using the
		# temp file we may have.

		set file $state(exec,temp)
		set pot 1
	    }
	}
    } else {
	# Regular file. Check if we have a temp file from a previous
	# teapot prefix still around, and get rid of it, if yes.

	if {[info exists state(exec,temp)] && ($state(exec,temp) ne "")} {
	    ClearExecTeapot $path
	}

	set file $state(exec)
    }

    set fileshown $state(exec)

    if {$ok} {
	if {$file == {}} {
	    if {$pot} {
		# An empty file for a teapot reference means that it
		# was not found.
		set state(exec,msg) "Prefix not found: $fileshown"

		# Extended error, from the teapot retrieval sub system.
		if {[info exists state(exec,tempmsg)] && ($state(exec,tempmsg) ne {})} {
		    append state(exec,msg) \n$state(exec,tempmsg)
		}

		set icon 0
		set res  0
		set ok   0
	    } else {
		# An empty name is ok, it just means that an empty
		# default file is used.
		set state(exec,msg) ""
		set icon 0
		set res  0
	    }
	} elseif {$state(merge) && ($file != {})} {
	    # A non-empty name is incorrect if merging is active, we
	    # need only the output file for that.

	    set state(exec,msg) "Specification of a prefix file is illegal when merging"
	    set ok 0

	} elseif {![file exists $file]} {
	    set state(exec,msg) "Prefix file does not exist: $fileshown"
	    set ok 0
	    set icon 0
	    set res  0

	} elseif {![file isfile $file]} {
	    set state(exec,msg) "Prefix file is not a file: $fileshown"
	    set ok 0
	    set icon 0
	    set res  0

	} elseif {![file readable $file]} {
	    set ok 0
	    set icon 0
	    set res  0
	    set state(exec,msg) "Prefix file is not readable: $fileshown"
	} elseif {![tclapp::misc::IsWrapCore $file emsg $fileshown]} {

	    # The low-level engine declares that the chosen file is
	    # not an acceptable base file. We take its error message
	    # as our own.

	    set ok 0
	    set state(exec,msg) $emsg
	} else {
	    set state(exec,msg) ""
	}
    }

    if {!$ok} {
	$state(.exec.e) state invalid
	tipstack::push $state(.exec.e) $state(exec,msg)

	# While the file has problems it does exist, so an icon may as
	# well. Do not prevent it from being shown.
	#set icon 0

	# Ditto for possible resources.
	#set res 0

    } else {
	# TODO: entry-bg option
	$state(.exec.e) state !invalid
	tipstack::pop $state(.exec.e)

	if {$fileshown ne ""} {
	    # Put chosen file into the dropdown list, if not already
	    # present. Save it also into the global preferences for
	    # use by future sessions.

	    set plistbase [$state(.exec.e) cget -values]
	    set plist [lsort -unique -dict \
			   [linsert $plistbase 0 $fileshown]]

	    if {[llength $plist] > [llength $plistbase]} {
		$state(.exec.e) configure -values $plist

		pref::prefSet   GlobalDefault prefixList $plist
		pref::groupSave GlobalDefault
	    }
	}
    }

    if {!$icon} {
	$state(.exec.esel) configure -state disabled
	elabel $path

	#Bug 77097
	#$state(.interp.e)  configure -state disabled

	# Bad prefix file, or empty, no custom icon to select.
	ExecImgOff state "the prefix file is not defined"
    } else {
	# Prefix file is good. Check if an icon is present. If yes,
	# arrange for its display and allow the selection of a custom
	# icon. If no icon is present we keep the elements disabled.

	# As optimization a number of things is done if and only if
	# the path to the prefix file changed. Otherwise we do
	# nothing, as we keep a cache of the important data.

	if {$file ne $state(exec,icache)} {
	    set state(exec,icache) $file

	    ClearIcon $path
	    set state(exec,icache,hasicon) [HasIcon $path $file]
	}

	if {$state(exec,icache,hasicon) || $state(osx)} {
	    # Even if the chosen prefix has no embedded icon we can
	    # customize the icon of the result, should the user signal
	    # the creation of an OS X .app bundle.

	    ExecImgOn state
	    IconOkActual $path $svar;# $var icon $op
	} else {
	    set msg "the prefix file does not contain any icons to customize,\nnor do we create an .app bundle for OS X"
	    if {$state(icon) ne ""} {
		append msg ". The chosen file is ignored"
	    }

	    ExecImgOff state $msg
	}
    }

    if {!$res} {
	$state(.out.sinfo)  configure -state disabled
	$state(.exec.pprov) configure -state disabled
    } else {
	# Test if prefix file has windows resources.
	# Test if prefix file has list of provided packages (teapot_provided.txt)

	# As optimization a number of things is done if and only if
	# the path to the prefix file changed. Otherwise we do
	# nothing, as we keep a cache of the important data.

	if {$file ne $state(exec,rcache)} {
	    set state(exec,rcache) $file
	    set state(exec,rcache,hasstrinfo) [HasStringInfo $path $file \
						  state(exec,rcache,strinfo,err)]
	    set state(exec,rcache,haspprov)   [HasPProv      $path $file]
	}

	if {$state(exec,rcache,hasstrinfo)} {
	    ExecSIOn  state
	} else {
	    ExecSIOff state "the prefix file does not contain any window string resources to customize. $state(exec,rcache,strinfo,err)"
	}

	if {$state(exec,rcache,haspprov)} {
	    ExecPPOn  state
	} else {
	    ExecPPOff state "the prefix file does not provide a list of contained packages"
	}
    }

    set state(exec,ok) $ok

    # We have to run an Interp check too, as changing the prefix
    # influences the interp's validity.

    InterpOkActual $path $svar

    # We have to run an FSMode check too, as changing the prefix
    # influences the validity of that information.

    FsmodeOkActual $path $svar

    CFT $path $svar

    # At last, update the architecture filter for packages
    UpdateArch $path
    return
}


proc ::tcldevkit::wrapper::wrapOptsWidget::InterpOk {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma,interp) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::InterpOkActual {path svar} {
    upvar #0 $svar state

    set ok 1
    set file $state(interp)

    if {$state(exec,ok)} {
	if {[tclapp::misc::isTeapotPrefix $state(exec)]} {
	    # Defer actual computation if a prefix is in retrieval,
	    # will be done when retrieval is complete.
	    if {[info exists state(exec,/get)]} return
	    # Generate fallback if the temp data should be there but
	    # is not. This can happen during the loading of a project
	    # file. The InterpOk check is triggered (through the
	    # traces) before the data is fully set up, and actually
	    # runs before other checks and initializers.
	    if {![info exists state(exec,temp)]} {
		set exec {}
	    } else {
		set exec $state(exec,temp)
	    }
	} else {
	    set exec $state(exec)
	}
    } else {
	set exec {}
    }

    if {$file == {}} {
	# An empty name is ok. It means that the system will use the
	# defaults (tclsh), if possible.
	set state(interp,msg) ""
    } elseif {$state(merge) && ($file != {})} {
	# A non-empty name is incorrect if merging is active, we need
	# only the output file for that.

	set state(interp,msg) "Specification of an interpreter is illegal when merging"
	set ok 0

    } elseif {$state(exec,ok) && ($exec != {})
	      && ![tclapp::misc::HasInterp $exec emsg $state(exec)]} {

	# The low-level engine declares that the chosen prefix !! file
	# does not support -interp. We take its error message as our own.

	set ok 0
	set state(interp,msg) $emsg
    } else {
	set state(interp,msg) ""
    }
    if {!$ok} {
	$state(.interp.e) state invalid
	tipstack::push $state(.interp.e) $state(interp,msg)
    } else {
	# TODO: entry-bg option
	$state(.interp.e) state !invalid
	tipstack::pop $state(.interp.e)

	if {$file ne ""} {
	    # Put chosen file into the dropdown list, if not already
	    # present. Save it also into the global preferences for
	    # use by future sessions.

	    set ilistbase [$state(.interp.e) cget -values]
	    set ilist [lsort -unique -dict \
			   [linsert $ilistbase 0 $file]]

	    if {[llength $ilist] > [llength $ilistbase]} {
		$state(.interp.e) configure -values $ilist

		pref::prefSet   GlobalDefault interpList $ilist
		pref::groupSave GlobalDefault
	    }
	}
    }

    set state(interp,ok) $ok
    return
}


proc ::tcldevkit::wrapper::wrapOptsWidget::FsmodeOk {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma,fsmode) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::FsmodeOkActual {path svar} {
    upvar #0 $svar state

    set ok 1
    set mode $state(fsmode)

    if {[tclapp::misc::isTeapotPrefix $state(exec)]} {
	# Defer actual computation if a prefix is in retrieval,
	# will be done when retrieval is complete.
	if {[info exists state(exec,/get)]} return
	set exec $state(exec,temp)
    } else {
	set exec $state(exec)
    }

    if {$mode == {}} {
	# An empty mode is ok. It means that the system will use the
	# defaults (readonly), if possible.
	set state(fsmode,msg) ""

    } elseif {$state(merge) && ($mode != {})} {
	# A non-empty mode is incorrect if merging is active, we need
	# only the output file for that.

	set state(fsmode,msg) "Specification of an update mode is illegal when merging."
	set ok 0

    } elseif {($exec != {}) && ![tclapp::misc::HasFSMode $exec emsg $state(exec)]} {

	# The low-level engine declares that the chosen prefix !! file
	# does not support -fsmode. We take its error message as our own.

	set ok 0
	set state(fsmode,msg) $emsg
    } else {
	set state(fsmode,msg) ""
    }
    if {!$ok} {
	# XXX Change $state(.fsmode(|.default|transp|write)) bg to errorbg
	tipstack::push $state(.fsmode.default) $state(fsmode,msg)
	tipstack::push $state(.fsmode.transp)  $state(fsmode,msg)
	tipstack::push $state(.fsmode.write)   $state(fsmode,msg)
    } else {
	# TODO: entry-bg option
	tipstack::pop $state(.fsmode.default)
	tipstack::pop $state(.fsmode.transp)
	tipstack::pop $state(.fsmode.write)
    }

    set state(fsmode,ok) $ok
    return
}


proc ::tcldevkit::wrapper::wrapOptsWidget::Ok {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma,ok) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::OkActual {path svar} {
    upvar #0 $svar state

    set state(ok) [expr {$state(out,ok) && $state(exec,ok) && $state(fsmode,ok) && $state(interp,ok)}]
    if {$state(ok)} {
	set state(errmsg) ""
    } else {
	set msg [list]
	if {!$state(out,ok)}    {lappend msg "Wrapping: $state(out,msg)"}
	if {!$state(exec,ok)}   {lappend msg "Wrapping: $state(exec,msg)"}
	if {!$state(interp,ok)} {lappend msg "Wrapping: $state(interp,msg)"}
	if {!$state(fsmode,ok)} {lappend msg "Wrapping: $state(fsmode,msg)"}
	set state(errmsg) [join $msg \n]
    }
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::OSXOk {path svar var idx op} {
    # Icon changes ...
    upvar #0 $svar state
    $state(/ma,osx) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::OSXOkActual {path svar} {
    # Icon changes ...
    upvar #0 $svar state

    ExecOkActual $path $svar

    # Switch the button giving access to the info.plist dialog.

    if {$state(osx)} {
	ExecOSXIPOn  state
    } else {
	ExecOSXIPOff state
    }

    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::IconOk {path svar var idx op} {
    upvar #0 $svar state
    $state(/ma,icon) arm
    return
}
proc ::tcldevkit::wrapper::wrapOptsWidget::IconOkActual {path svar} {
    upvar #0 $svar state

    set ok 1
    set warn 0
    set icon 1
    set display 1
    set file $state(icon)

    if {$file == {}} {
	# An empty name is ok, it just means that an empty default file is used.
	set state(icon,msg) ""
	set icon 0

    } elseif {![file exists $file]} {
	set state(icon,msg) "Icon file does not exist: $file"
	set ok 0
    } elseif {![file isfile $file]} {
	set state(icon,msg) "Icon file is not a file: $file"
	set ok 0
    } elseif {![file readable $file]} {
	set ok 0
	set state(icon,msg) "Icon file is not readable: $file"
    } else {
	# File basics are ok. Now look into it for its icons.

	if {$state(osx)} {
	    if {[lsearch -exact [fileutil::fileType $file] icns] >= 0} {
		# For now simply show acceptance of the icon file,
		# even if we cannot show the contained icon itself.

		set ok 1
		set state(icon,msg) "Apple ICNS. Will be added to the .app bundle"
		set display 0
	    } else {
		set ok 0
		set state(icon,msg) "Not an Apple ICNS file."
	    }
	} else {
	    # only handles 1st icon resource in a file
	    if {
		[catch {set ico [lindex [ico::icons $file -type ICO] 0]} msg] ||
		([llength $ico] == 0)
	    } {
		# No icons present.
		set ok 0
		set state(icon,msg) "No icons found"
	    } else {
		# We found some icons. Compare to the bitmaps in the
		# icon found in the prefix file.

		set icons [ico::iconMembers $file $ico -type ICO]

		foreach {warn m} [CompareIcons $path $icons] break
		set ok 1
		set state(icon,msg) $m
	    }
	}
    }

    if {!$ok} {set icon 0}

    # Update the display ...

    if {$display} {
	$state(.icon.l) configure -text "No icon";# Default text when icons can be shown.
	if {$icon} {
	    #set img [image create photo -format ico -file $file]

	    set ico   [lindex [ico::icons $file] 0]
	    set icons [ico::iconMembers $file $ico -type ICO]
	    set img   [GetIconImage $file ICO $ico $icons 32]
	} else {
	    set img {}
	}
	catch {image delete [$state(.icon.l) cget -image]}
	$state(.icon.l) configure -image $img
    } else {
	$state(.icon.l) configure -image ""
	$state(.icon.l) configure -text "Not shown"
    }

    if {!$ok || $warn} {
	$state(.icon.e) state invalid
    } else {
	# ok && !warn
	# TODO: entry-bg option
	$state(.icon.e) state !invalid

	tipstack::pop $state(.icon.l)
	tipstack::pop $state(.icon.e)
    }

    if {$ok && ($file ne "")} {
	# Put chosen file into the dropdown list, if not already
	# present. Save it also into the global preferences for
	# use by future sessions.

	set ilistbase [$state(.icon.e) cget -values]
	set ilist [lsort -unique -dict \
		       [linsert $ilistbase 0 $file]]

	if {[llength $ilist] > [llength $ilistbase]} {
	    $state(.icon.e) configure -values $ilist

	    pref::prefSet   GlobalDefault iconList $ilist
	    pref::groupSave GlobalDefault
	}
    }

    # In contrast to the other checkers this one can define a message
    # even if the data is deemed ok.

    tipstack::pop  $state(.icon.e)
    tipstack::pop  $state(.icon.l)

    if {$state(icon,msg) != {}} {
	tipstack::push $state(.icon.l) $state(icon,msg)
	tipstack::push $state(.icon.e) $state(icon,msg)
    }
    set state(icon,ok) $ok
    return
}

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::chooseOut {path} {
    upvar #0 ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state state

    # Bugzilla 19695 ... Switch to 'Save' to allow the selection of not yet existing files.

    set file [tk_getSaveFile \
	    -title     "Select output file" \
	    -parent    $path \
	    -filetypes {{All {*}}} \
	    -initialdir $state(lastdir,out) \
	    ]

    if {$file == {}} {return}
    set state(lastdir,out) [file dirname $file]
    set state(out) $file
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::chooseExec {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    set file [tk_getOpenFile \
	    -title     "Select prefix file" \
	    -parent    $path \
	    -filetypes {{All {*}}} \
	    -initialdir $state(lastdir,exec) \
	    ]

    if {$file == {}} {return}

    # Determine the new default path to browse to when searching for
    # basekits. We keep this in memory, and save it to the global
    # preferences as well, for future sessions.

    set pp [file dirname $file]
    if {$pp ne $state(lastdir,exec)} {
	set state(lastdir,exec) $pp
	pref::prefSet   GlobalDefault prefixPath $pp
	pref::groupSave GlobalDefault
    }

    set state(exec) $file
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::chooseExecTeapot {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    $path.exec.k configure -state disabled

    set prefixes [lsort -dict -index 5 -unique \
		      [lsort -dict -index 0 \
			   [lsort -dict -index 1 \
				[lsort -dict -index 2 -decreasing \
				     [lsort -dict -index 3 -decreasing \
					  [lsort -dict -index 4 -decreasing \
					       [Applications $path]]]]]]]

    pkgman::plist $path.prefixsel -parent $path.exec.k -place left \
	-with-arch 1 -selectmode single \
	-title {Select Prefix For Wrap} \
	-command [list tcldevkit::wrapper::wrapOptsWidget::chooseExecTeapotEnter $path]

    $path.prefixsel enter $prefixes
    $path.prefixsel display
    # Calls chooseExecTeapotEnter

    ::destroy $path.prefixsel

    $path.exec.k configure -state normal
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::Applications {path} {
    ::tcldevkit::appframe::feedback on

    # list (list (name version isprofile istap))

    # path = <WRAPPER>.ow
    # package panel is <WRAPPER>.pmp

    set pkgpanel [join [lrange [split $path .] 0 end-1] .].pmp
    set r [$pkgpanel Repo]

    set res \
	[struct::list map \
	     [struct::list filter \
		  [$r sync list] \
		  [list ::pkgman::packages::onlyapp $r]] \
	     [list ::pkgman::packages::cutE $r]]

    #puts \t*[join $res *\n\t*]*
    
    ::tcldevkit::appframe::feedback off
    return $res
}

proc ::tcldevkit::wrapper::wrapOptsWidget::chooseExecTeapotEnter {path selection} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    # selection = list (list (name version arch))
    #
    # Outer list always contains only one element (The used plist is
    # configured for single-selection).

    if {![llength $selection]} {return}

    foreach {n v a} [lindex $selection 0] break
    set ref      [tclapp::misc::makeTeapotPrefix $n $v $a]
    set instance [teapot::instance::cons application $n $v $a]

    # Remove temp information of the previous selection, if any. Do
    # this before setting the new selection, so that ExecOk sees a
    # consistent state.
    if {[info exists state(exec,temp)] && ($state(exec,temp) ne "")} {
	ClearExecTeapot $path
    }

    set state(exec) $ref

    # Start retrieval of basekit in background, to a temp file. Store
    # path of temp file in exec,temp.  ExecOK checks for teapot-ref
    # and defers the main checks until the file is known, then
    # rechecks.

    GetExecTeapot $path $ref $instance
    DisablePartsWaitingForTeapot $path
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::GetExecTeapot {path ref instance} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    set state(exec,/get) .

    set pkgpanel [join [lrange [split $path .] 0 end-1] .].pmp
    set location [fileutil::tempfile tclapp_tempp]

    #puts |get|\t|$ref|\t|$instance|\t|$location|

    # XXX AK Future - Do not remove retrieved files when the
    # teapot-reference changes, but cache the association, allowing us
    # to forego repeated downloads on re-selection.

    [$pkgpanel Repo] get \
	-command [list tcldevkit::wrapper::wrapOptsWidget::GBK $path $instance $ref $location] \
	$instance $location
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::DisablePartsWaitingForTeapot {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    # <xx>
    foreach w {
	.exec.pprov
    } {
	$state($w) configure -state disabled
	tipstack::pop  $state($w)
	tipstack::push $state($w) "Defered until the file for the reference is available"
    }
    return
}


proc ::tcldevkit::wrapper::wrapOptsWidget::ClearExecTeapot {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    file delete $state(exec,temp)
    unset state(exec,temp)
    unset state(exec,tempref)
    unset state(exec,tempmsg)

    #puts |clear|
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::GBK {path instance ref location code result} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    # instance = application. If retrieval failed look for a redirect.

    if {$code || ![file size $location]} {
	teapot::instance::split $instance __ n v a
	set redir [teapot::instance::cons redirect $n $v $a]

	set pkgpanel [join [lrange [split $path .] 0 end-1] .].pmp
	[$pkgpanel Repo] get \
	    -command [list tcldevkit::wrapper::wrapOptsWidget::GBK/R $path $redir $ref $location $result] \
	    $redir $location
	return
    }

    GBK/Complete/Ok $path $location $ref
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::GBK/R {path instance ref location oldmessage code result} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    # instance = redir. If retrieval failed we simply fail overall.

    if {$code || ![file size $location]} {
	GBK/Complete/Error $path $ref $oldmessage
	return
    }

    # Ok, we have a file containing the redirection, decode it, and
    # perform some checks.

    set fail [catch {
	foreach {origin orepos} [teapot::redirect::decode $location] break
	if {![llength $orepos]} { return -code error "No repositories in redirection" }
    } msg]
    file delete $location

    if {$fail} {
	GBK/Complete/Error $path $ref $msg
	return
    }

    # We got the origin instance, and have some repository names. Check more ...
    teapot::instance::split $origin eorigin __ __ __
    if {$eorigin ne "application"} {
	GBK/Complete/Error $path $ref \
	    "Expected an application, was redirected to \"$eorigin\""
	return
    }

    # Now we can pull the actual file ...

    set u [tclapp::pkg::UnionFor $orepos]
    $u get \
	-command [list tcldevkit::wrapper::wrapOptsWidget::GBK/O $path $origin $ref $location $u $orepos] \
	$origin $location
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::GBK/O {path origin ref location repo orepos code result} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    $repo destroy

    if {$code || ![file size $location]} {
	set orepos \n[tclapp::pkg::Indent [join $orepos \n] {  }]\n
	set result [tclapp::pkg::Indent [tclapp::pkg::StripTags $result] {    }]
	set result "\nRedirection to${orepos}failed:\n$result"

	GBK/Complete/Error $path $ref $result
    } else {
	GBK/Complete/Ok $path $location $ref
    }
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::GBK/Complete/Error {path ref message} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    # Failed, clear lock, and clear state

    unset state(exec,/get)

    # Errors, wether reported explicitly, or implicit in that
    # nothing was retrieved, are handled by injecting an empty
    # location => File does not exist.
    set state(exec,temp) ""
    set state(exec,tempref) $ref
    set state(exec,tempmsg) $message

    if {[catch {
	ExecOkActual $path \
	    ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    }]} {
	puts $::errorInfo
    }

    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::GBK/Complete/Ok {path location ref} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    # Success, clear lock, then safe the info

    unset state(exec,/get)

    # NOTE: We tie the location to a specific teapot-reference,
    # allowing us to determine when the information in 'exec' is not
    # in sync with its temp file any longer, invalidating it.

    #puts |$ref|=\t|$code|$result|\t|$location|sz=[file size $location]

    set state(exec,temp) $location
    set state(exec,tempref) $ref
    set state(exec,tempmsg) ""

    if {[catch {
	ExecOkActual $path \
	    ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    }]} {
	puts $::errorInfo
    }
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::chooseInterp {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    set file [tk_getOpenFile \
	    -title     "Select interpreter" \
	    -parent    $path \
	    -filetypes {{All {*}}} \
	    -initialdir $state(lastdir,interp) \
	    ]

    if {$file == {}} {return}

    # Determine the new default path to browse to when searching for
    # interpreters. We keep this in memory, and save it to the global
    # preferences as well, for future sessions.

    set ip [file dirname $file]
    if {$ip ne $state(lastdir,interp)} {
	set state(lastdir,interp) $ip
	pref::prefSet   GlobalDefault interpPath $ip
	pref::groupSave GlobalDefault
    }

    set state(interp) $file
    return
}

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::DefaultOut {} {
    # Bugzilla 26353. Use path WITHOUT extension even on windows.
    # This ensures that the auto-selection of the extension based
    # on the prefix-file kicks in. See -> Bugzilla 26006,
    # -> File 'tclapp_misc.tcl', -> Proc '::tclapp::misc::validate'.

    return [file join [DefaultPath] tclapp-out]
    if 0 {
	global tcl_platform
	switch -exact -- $tcl_platform(platform) {
	    windows {return [file join [DefaultPath] tclapp-out]}
	    unix    {return [file join [DefaultPath] tclapp-out]}
	}
    }
}

proc ::tcldevkit::wrapper::wrapOptsWidget::DefaultPath {} {
    global env tcl_platform

    foreach vl {
	HOME
	HOMEDRIVE
	APPDATA
	TMP
	TEMP
    } {
	set ok 1
	set res ""
	foreach v $vl {
	    if {![info exists env($v)]} {
		set ok 0
		break
	    }
	    append res $env($v)
	}
	if {!$ok} continue

	# Bugzilla 19675 ...
	if {[string equal [file pathtype $res] "volumerelative"]} {
	    # Convert 'C:' to 'C:/' if necessary, innocuous otherwise
	    append res /
	}
	return $res
    }
    switch -exact -- $tcl_platform(platform) {
	windows {return C:/}
	unix    {return /tmp}
    }
}

# ------------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::dismiss {path lb apply} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable ::tcldevkit::wrapper::wrapOptsWidget::encs

    if {$apply} {
	set newencs [list]
	foreach i [$lb curselection] {
	    lappend newencs [lindex $encs $i]
	}
	set state(encs) $newencs
	elabel $path
    }
    grab release [winfo toplevel $lb]
    wm withdraw  [winfo toplevel $lb]
}

proc ::tcldevkit::wrapper::wrapOptsWidget::EncodingsSelect {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    # Pop up a dialog for the selection of the encodings to be
    # (additionally) supported by the wrapped application.

    # - $state(encs)     = chosen encodings (pre-select!)
    # - [encoding names] = all known encodings.

    set encvar ::tcldevkit::wrapper::wrapOptsWidget::encs
    variable $encvar [lsort -dictionary [encoding names]]

    set top $path.encsel
    set exists [winfo exists $top]
    if {!$exists} {
	widget::dialog $top -parent $state(.exec.esel) -transient 1 -modal local \
	    -type okcancel -title "Select Encodings" -place right \
	    -padding [pad labelframe]
	set frame [$top getframe]

	# Dialog contents ...
	set sw [ScrolledWindow $frame.sw -managed 0 -ipad 0 \
		    -scrollbar vertical]
	listbox $sw.list -selectmode extended -listvariable $encvar \
	    -highlightthickness 1 -height 20

	$sw setwidget $sw.list

	grid $sw -column 0 -row 0 -sticky news
	grid columnconfigure $frame 0 -weight 1
	grid rowconfigure    $frame 0 -weight 1
    }
    set lb [$top getframe].sw.list

    $lb selection clear 0 end
    if {[llength $state(encs)]} {
	# Preselect the previously chosen encodings.
	# And ensure that the first one is visible.

	set visible 1
	foreach e $state(encs) {
	    set pos [lsearch -dictionary -sorted -exact $encs $e]
	    $lb selection set $pos
	    if {$visible} {
		$lb see $pos
		set visible 0
	    }
	}
    }

    set res [$top display]
    ::tcldevkit::wrapper::wrapOptsWidget::dismiss $path $lb \
	[expr {$res eq "ok"}]
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::IconSelect {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    if {$state(osx)} {
	set filetypes {{ICNS {*.icns}}}
    } else {
	set filetypes {{All {*}}}
    }

    set file [tk_getOpenFile \
	    -title     "Select custom icon file" \
	    -parent    $path \
	    -filetypes $filetypes \
	    -initialdir $state(lastdir,icon) \
	    ]

    if {$file == {}} {return}

    # Determine the new default path to browse to when searching for
    # icons. We keep this in memory, and save it to the global
    # preferences as well, for future sessions.

    set ip [file dirname $file]
    if {$ip ne $state(lastdir,icon)} {
	set state(lastdir,icon) $ip
	pref::prefSet   GlobalDefault iconPath $ip
	pref::groupSave GlobalDefault
    }

    if {$state(osx)} {
	if {[lsearch -exact [fileutil::fileType $file] icns] < 0} {
	    tk_messageBox -parent $path -title "Format error" \
		-icon error -type ok \
		-message "The chosen file \"$file\" has to be\
		in Apple's ICNS format, and was not"
	    return
	}
    } else {
	if {[catch {
	    #set img [image create photo -format ico -file $file]
	    set img [ico::getIcon $file  [lindex [ico::icons $file] 0] -type ICO]
	} msg]} {
	    tk_messageBox -parent $path -title "Format error" \
		-icon error -type ok \
		-message "The chosen file \"$file\" has to be\
		in ICO format, and was not\n(Error: $msg)"
	    return
	}
	image delete $img
    }

    # This assignment also propagates the information whereever
    # it is needed (display, checking, tooltips, ...).
    set state(icon) $file

    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::ClearIcon {path} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    catch {image delete $state(exec,icondata)}
    set state(exec,icondata) {}
    set state(exec,icondesc) {}
    set state(exec,icons)    {}
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::HasIcon {path exefile} {
    global tcl_platform

    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    # Determine embedded icon(s), and its data.
    # Failure to extract anything useful, either by thrown error or nothing
    # returned indicates that a custom icon is not possible.
    # Currently only handles 1st icon resource in a file

    if {
	[catch {set ico [lindex [ico::icons $exefile -type EXE] 0]}] ||
	([llength $ico] == 0)
    } {return 0}

    # Convert found the data into something we can use in the UI.

    set icons [ico::iconMembers $exefile $ico -type EXE]

    set desc {}
    foreach icon $icons {
	foreach {id w h bpp} $icon break
	append desc "${w}x${h}: ${bpp} bpp\n"
    }
    set desc [string trim $desc]

    set state(exec,icondata) [GetIconImage $exefile EXE $ico $icons 32]
    set state(exec,icondesc) $desc
    set state(exec,icons)    $icons

    return 1
}

proc ::tcldevkit::wrapper::wrapOptsWidget::GetIconImage {file type ico icons res} {
    # If we have only one resolution take it, regardless how off it
    # would be copared to the prefered res'olution. We can't do
    # better.
    if {[llength $icons] == 1} {
	return [ico::getIcon $file $ico -type $type]
    }

    # rewrite the icon list a bit. Size 0 is 256 actually.
    set tmp {} ; foreach x $icons {
	if {[lindex $x 1] == 0} {
	    lappend tmp [lreplace $x 1 2 256 256]
	} else {
	    lappend tmp $x
	}
    } ; set icons $tmp ; unset tmp


    # Find exact matches for the prefered resolution.
    set match {}
    foreach x $icons {
	if {[lindex $x 1] != $res} continue
	lappend match $x
    }

    # Nothing found, now look for inexact matches. Actually:
    # Take the largest one which is smaller than prefered, or, if no
    # such exists, take the smallest one of the larger resolutions.
    if {![llength $match]} {
	set match {}
        foreach x [lsort -integer -index 1 $icons] {
	    if {[lindex $x 1] > $res} break
	    lappend match $x
	}
	if {![llength $match]} {
	    set match {}
	    foreach x [lsort -integer -index 1 -decreasing $icons] {
		if {[lindex $x 1] < $res} break
		lappend match $x
	    }
	}
	set match [list [lindex $match end]]
    }

    # Of the bits per pixel, select the highest.
    set match [lindex [lsort -integer -decreasing -index 3 $match] end]
    foreach {id res h bpp} $match break

    return [ico::getIcon $file $ico -type $type -res $res -bpp $bpp -exact 1]
}

proc ::tcldevkit::wrapper::wrapOptsWidget::CompareIcons {path icons} {
    variable ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state

    if {![info exists state(exec,icons)]} {
	# Bug 74205. During loading of a project we have a time where
	# the custom icon can be set already, but not yet the prefix
	# (exec), and then we are asked to compare them. We ignore
	# that call, it will be followed by another call later on,
	# when the prefix and its icon are known as well.
	return {0 {}}
    }

    set warn 0

    array set _ {}
    foreach e $state(exec,icons) {
	foreach {id w h bpp} $e break
	set _(${w}x${h}:$bpp) [list $w $h $bpp]
    }

    set    desc "The custom icon to embed in the result\n"
    append desc "Status of contents, compared to the icon in the prefix\n\n"
    foreach icon $icons {
	foreach {id w h bpp} $icon break

	append desc "${w}x${h}: ${bpp} bpp"
	if {![info exists _(${w}x${h}:$bpp)]} {
	    append desc " - Superfluous\n"
	    set warn 1
	} else {
	    append desc " - Ok\n"
	    unset _(${w}x${h}:$bpp)
	}
    }
    foreach k [lsort [array names _]] {
	foreach {w h bpp} $_($k) break
	append desc "${w}x${h}: ${bpp} bpp - Missing\n"
	set warn 1
    }
    return [list $warn [string trim $desc]]
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::StringInfoOpen {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    set lvar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::linkvar
    variable $svar

    if {[winfo exists $path.sid]} {
	wm deiconify $path.sid
	raise        $path.sid
	return
    }

    set d [widget::dialog $path.sid \
	       -place above -parent $state(.out.sinfo) \
	       -title "TclApp Windows String Resources (Wrap Result)" \
	       -padding [pad labelframe] \
	       -synchronous 0]

    # Note: Use the linked variable of this widget for the sieditor,
    # _not_ our internal state!

    $d add button -text Defaults -command [list $d.sie reset]
    $d add button -text Close    -command [list $d close]
    $d setwidget [sieditor $d.sie -variable [set $lvar]]
    $d display
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::HasStringInfo {path exefile var} {
    upvar 1 $var message
    global tcl_platform

    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable $svar

    # Determine if there are windows string resources.
    # Failure to extract anything useful, either by thrown error or nothing
    # returned indicates that windows string resources are not present.
    
    if {[catch {
	    ::stringfileinfo::getStringInfo $exefile origin
    } m]} {
	set message $m
	return 0
    }

    return 1
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecSIOff {statevar reason} {
    upvar 1 $statevar state

    set tip "A customization of windows string resources is not possible.\nThis is because $reason"

    foreach w {.out.sinfo} {
	tipstack::pop  $state($w)
	tipstack::push $state($w) $tip
    }

    $state(.out.sinfo) configure -state disabled
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecSIOn {statevar} {
    upvar 1 $statevar state

    # Update tooltips
    tipstack::pop  $state(.out.sinfo)

    $state(.out.sinfo) configure -state normal
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecOSXIPOff {statevar} {
    upvar 1 $statevar state

    set tip "A customization of the OS X Info.plist is not possible, because we are not creating an .app bundle for OS X"

    foreach w {.out.ip} {
	tipstack::pop  $state($w)
	tipstack::push $state($w) $tip
    }

    $state(.out.ip) configure -state disabled
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecOSXIPOn {statevar} {
    upvar 1 $statevar state

    # Update tooltips
    tipstack::pop  $state(.out.ip)

    $state(.out.ip) configure -state normal
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::OSXIPOpen {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    set lvar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::linkvar
    variable $svar

    if {[winfo exists $path.ipd]} {
	wm deiconify $path.ipd
	raise        $path.ipd
	return
    }

    set d [widget::dialog $path.ipd \
	       -place above -parent $state(.out.ip) \
	       -title "TclApp OS X Info.plist (Wrap Result)" \
	       -padding [pad labelframe] \
	       -synchronous 0]

    # Note: Use the linked variable of this widget for the mdeditor,
    # _not_ our internal state!

    $d add button -text Defaults -command [list $d.ipe reset]
    $d add button -text Close    -command [list $d close]
    $d setwidget [ipeditor $d.ipe -variable [set $lvar]]
    $d display
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::MetadataOpen {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    set lvar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::linkvar
    variable $svar

    if {[winfo exists $path.mdd]} {
	wm deiconify $path.mdd
	raise        $path.mdd
	return
    }

    set d [widget::dialog $path.mdd \
	       -place above -parent $state(.out.md) \
	       -title "TclApp TEApot Meta Data (Wrap Result)" \
	       -padding [pad labelframe] \
	       -synchronous 0]

    # Note: Use the linked variable of this widget for the mdeditor,
    # _not_ our internal state!

    $d add button -text Defaults -command [list $d.mde reset]
    $d add button -text Close    -command [list $d close]
    $d setwidget [mdeditor $d.mde -variable [set $lvar]]
    $d display
    return
}

# -----------------------------------------------------------------------------
# NOTE TODO FUTURE - Extract the dialog below and put it into its own class,
# ---- ---- ------ - and file.

proc ::tcldevkit::wrapper::wrapOptsWidget::ArchOpen {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable $svar

    set d $path.arch

    if {![winfo exists $path.arch]} {
	widget::dialog $d \
	           -place above -parent $state(.out.arch) \
		   -title "TclApp Architecture Selection (Wrap Result)" \
		   -padding [pad labelframe] \
		   -synchronous 0

	$d add button -text Defaults \
	    -command [list ::tcldevkit::wrapper::wrapOptsWidget::ArchDefault $path]

	$d add button -text Apply \
	    -command [list ::tcldevkit::wrapper::wrapOptsWidget::ArchApply $path]

	$d add button -text Close \
	    -command [list ::tcldevkit::wrapper::wrapOptsWidget::ArchClose $path]


	$d setwidget [pkgman::architectures $d.a]
    }

    $d.a set $state(out,arch)
    $d display
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ArchApply {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable $svar

    set new [lsort -increasing [$path.arch.a get]]

    if {$new ne $state(out,arch)} {
	set state(out,arch) $new
	set state(out,arch,user) 1
    }
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ArchClose {path} {
    ArchApply $path
    $path.arch close
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ArchDefault {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable $svar

    # Forcibly replace the user choice with the default architecture,
    # based on the prefix.

    set new [DefaultArch $path]

    set state(out,arch,user) 0
    set state(out,arch)      $new

    $path.arch.a set $new
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::DefaultArch {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable $svar

    # Determine the default architecture of the result, based on the
    # chosen prefix, output file, and merge flag, and return this as a
    # list.

    # 1. !Merge -> Chosen prefix is source
    # 2. Merge  -> Chosen output is source

    if {$state(merge)} {
	set base out
    } else {
	set base exec
    }

    # Note: Default architecture without prefix, bad prefix, or
    # problems with the prefix, is 'tcl'. That way we always have an
    # architecture defined, and it makes sense to limit ourselves to
    # 'pure-tcl' packages in case of a starkit (i.e. no prefix).

    if {$state($base) == {}} { return tcl }
    if {!$state($base,ok)}   { return tcl }

    if {$base eq "exec"} {
	if {[tclapp::misc::isTeapotPrefix $state(exec)]} {
	    # Generate fallback while the prefix is in retrieval.
	    if {[info exists state(exec,/get)]} {
		return tcl
	    }
	    # Generate fallback if the temp data should be there but
	    # is not. This can happen during the loading of a project
	    # file. The OutOk check is triggered (through the traces)
	    # before the data is fully set up, and actually runs
	    # before other checks and initializers.
	    if {![info exists state(exec,temp)]} {
		return tcl
	    }
	    set arfile $state(exec,temp)
	} else {
	    set arfile $state(exec)
	}
    } else {
	set arfile $state($base)
    }

    if {[catch {
	set r [repository::cache get repository::prefix $arfile]
    }]} { return tcl }

    return [list [$r architecture]]
}


proc ::tcldevkit::wrapper::wrapOptsWidget::UpdateArch {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable $svar

    # Nothing to update if the set came from the user.
    if {$state(out,arch,user)} return

    # Now set the architecture per the other settings, however only if
    # there was an actual change.

    set new [DefaultArch $path]
    if {$state(out,arch) eq $new} return

    set state(out,arch) $new
    if {[winfo exists $path.arch]} {
	$path.arch.a set $new
    }
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::PProvOpen {path} {
    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    set lvar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::linkvar
    variable $svar

    if {![winfo exists $path.ppd]} {
	pkgman::plist $path.ppd -place right \
	    -parent $state(.exec.pprov) \
	    -title {TclApp Prefix Packages} -type ok
    }

    # NOTE: This command cannot be called if the prefix temp file is
    # not defined. See <xx> for the code making sure of this.
    if {[tclapp::misc::isTeapotPrefix $state(exec)]} {
	set arfile $state(exec,temp)
    } else {
	set arfile $state(exec)
    }

    vfs::mk4::Mount $arfile $arfile -readonly
    set pl [::teapot::metadata::read::fileEx [file join $arfile teapot_provided.txt] all errors 1]
    vfs::unmount $arfile

    set p {}
    foreach x $pl {
	set v [$x version]
	if {![teapot::version::valid $v]} {set v 0}
	lappend p [list [$x name] $v [$x exists profile] 0]
	$x destroy
    }
    $path.ppd enter [lsort -dict -index 0 \
			 [lsort -dict -index 1 \
			      [lsort -dict -index 2 -decreasing \
				   [lsort -dict -index 3 -decreasing $p]]]]
    $path.ppd display
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::wrapper::wrapOptsWidget::HasPProv {path exefile} {
    global tcl_platform

    set svar ::Widget::tcldevkit::wrapper::wrapOptsWidget::${path}::state
    variable $svar

    # Determine if there are teapot provided packages. Failure to
    # extract anything useful, either by thrown error or nothing
    # returned indicates that such a list is not present.

    log::log debug "HasPProv $exefile exists [file exists   $exefile]"
    log::log debug "HasPProv $exefile isfile [file isfile   $exefile]"
    log::log debug "HasPProv $exefile read.. [file readable $exefile]"

    if {![file exists   $exefile]} {return 0}
    if {![file isfile   $exefile]} {return 0}
    if {![file readable $exefile]} {return 0}

    if {[lsearch -exact [fileutil::fileType $exefile] metakit] < 0} {
	log::log debug "HasPProv $exefile No Metakit"
	return 0
    }

    set pp [file join $exefile teapot_provided.txt]
    set pl {}
    if {[catch {
	vfs::mk4::Mount $exefile $exefile -readonly
    } msg]} {
	log::log debug "HasPProv $exefile Mount Failure: $msg"
	return 0
    }
    if {[file exists $pp]} {
	set errors {}
	set pl [::teapot::metadata::read::fileEx $pp all errors 1]
    }
    vfs::unmount $exefile
    if {![llength $pl]} {
	log::log debug "HasPProv $exefile No packages"
	return 0
    }
    # Destroy the objects, we do not need them here.
    foreach x $pl {$x destroy}
	log::log debug "HasPProv $exefile Has Packages"
    return 1
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecPPOff {statevar reason} {
    upvar 1 $statevar state

    set tip "Showing the list of provided packages is not possible.\nThis is because $reason"

    foreach w {.exec.pprov} {
	tipstack::pop  $state($w)
	tipstack::push $state($w) $tip
    }

    $state(.exec.pprov) configure -state disabled
    return
}

proc ::tcldevkit::wrapper::wrapOptsWidget::ExecPPOn {statevar} {
    upvar 1 $statevar state

    # Update tooltips
    tipstack::pop  $state(.exec.pprov)

    $state(.exec.pprov) configure -state normal
    return
}

# -----------------------------------------------------------------------------

package provide tcldevkit::wrapper::wrapOptsWidget 1.0
