# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# appframe.tcl --
#
#	Application framework used by the wrapper and compiler
#	gUIs. Contains the application code shared by both of them.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: watchWin.tcl,v 1.3 2000/10/31 23:31:01 welch Exp $
#
# -----------------------------------------------------------------------------

package require log ; ::log::lvColor notice #90EE90
package require projectInfo
package require starkit
package require tcldevkit::tk

if {[tcldevkit::tk::present]} {
    package require BWidget
    package require splash
    package require help
    package require img::png
    package require image;image::file::here
}

# -----------------------------------------------------------------------------
# HACK: We source and initialize some code coming from the debugger so that we
# can launch a browser (from the about box and for help) and help. We have to
# tweak things a bit so that this part of the debugger works. This should go
# into a shared package instead of residing in the debugger code.

set here [file dirname [info script]]
##source [file join $here pref.tcl]                                 ; # Debugger code dealing with
##source [file join $here system.tcl]                               ; # launching a browser, and help.
##proc system::setWidgetAttributes {} {}          ; # Disable this code, not needed
namespace eval ::gui {}                         ; # Fake hook into debugger
proc           ::gui::getParent {} {return "."} ; #
namespace eval ::debugger {}                    ; # variable required during 
set ::debugger::parameters(appType) local       ; # system initialization
##system::init

namespace eval ::tcldevkit::appframe {
    variable here     $::here
    variable imagedir [file join $starkit::topdir data images]
    # This is the Lick the Frog's head, 32x32
    variable icon {
	iVBORw0KGgoAAAANSUhEUgAAACAAAAAfCAYAAACGVs+MAAAABmJLR0QA/wD/
	AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAB3RJTUUH1gwGAA8P/w/m
	EQAABClJREFUSMetVy+IOlsUPvu4YcIEw8AaJhgMBmEnTDAYDG7bti4oGCYY
	DAYXDAZhBFksD1wwGJZlg8EFg2GCwWD4BVlcUDC4PxRmwWBQmDCC8Eb4Xlh0
	ndX13+6BU4Y793z33HO+79wzWjMAWfoFe35+Vu/u7uj9/Z0kSaLr62uKRCL5
	8/Pz/4iIzs7ONuMAyOIXrNFogDEGIrK5KIp4eHiAZVnYOKjX6/3r8/mgadqP
	Afj9/o3g6x4Oh2Ga5ieI5cmdTid4nkcoFIKu6ycFr1arO4MvXZIkTCaTDxDB
	YBCKokCSJBiGAcMwkE6nkUwmMRgMjkq9IAgHASAiuFwumKaJs3a7jcfHR+p2
	u/Tnzx9ijBER0e3tLd3f35MsyxQIBOji4oJEUSSn00mLxYKm0ynNZjN6eXmh
	t7c3mk6n9Pr6SrPZ7OBiTSQSRMsTuN1uJBKJ5f0gk8nsPQVjDOVyGZZlwTAM
	DIdDFItFuFyug7LAcRxoPB6jXq+D53kEg0H4fD5IkrS1kr+6qqoAgEKhAI7j
	wBhDpVKBZVnQNA3hcBiiKO7eZ/nj+n2rqnrQCUzThK7rYIyB47hvu2gymUDX
	dTSbTTSbTfT7fTSbzY+O0TQNsixv/ORwOHYG93q9AIBWq7WqbFmWIQgCSqXS
	zoLtdDoQRRGapoEAIBAILNsCADCfz8Hz/E4AgUBga+87HI6d3aNpGnieRyqV
	+mjDZDIJxhh8Ph8ajQYajcZeMlkSytIMw4CqqkgkEuj3+1sDm6aJeDwOxhgy
	mczyc5YO7duvrijKUQTldrshCMLXOsn+c6rgLBaLvWuGwyHd3NxQJBKhUChE
	g8GArq6u7IsOabdt7vF4lsKyYYPBAIqigOM4KIqCTqfzXXKypCgKTr2GWCy2
	Kjhd11EqlRAMBuFwOBCPx9Hr9fbdTpZ6vd6/x3D4LhdFEZlM5hgxyxKAbLlc
	/lHgYDCIWq2G+Xx+rIBmV3JcKBSOCsoYQzQaRbPZtLXjd3WxF8CyeNLp9E4W
	FAQB6XT62zTX63W02+3TAKxT5VcmFEURxWJxpZa7LJfLIRaLwTCM4wF0Oh3b
	YMHzPPL5/EGB1y0ajUIQBFQqlcMB9Ho9W3CPx4PRaHTSeKbruo01v8nGJwDL
	suD1em1qty5Qp5jT6Vzt53a7t+nEJ4BGo2G789+YkGVZtu3J8zxardZhWuB2
	u3/8QBFFkYiIFEWhRCJBs9mMLi8vqdvtbn+QhMPhjXHrJ5ZKpUBEK65IJpMg
	Ivj9/u1FaFkWfD7famCs1Wp7ZXbX8LFk2PVOiMfjcDgctnnABmI8Hq+mWsYY
	VFXdym75fH7vXDAajcAYw9PTk+37eDzefJ6tg+j3+7bRWpKkjaKUJAlEhFwu
	tzNL5XJ5G2tufwSvg+h0OhuULMsy8vm87c1QrVaPF6A1+x8x+Wv0OUgU9wAA
	AABJRU5ErkJggg==
    }
}

# -----------------------------------------------------------------------------

package require tcldevkit::config
namespace eval ::tcldevkit::appframe {}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::setName {name {tclvers {}}} {
    # Implicit [set]

    # Base references
    variable appNameD  "$::projectInfo::productName $name"
    variable appName   "[string map {{ } {}} $::projectInfo::productName] $name"
    variable appVers   "$::projectInfo::baseVersion"
    variable appNameV  "$appName $appVers"
    variable appNameFile $appName
    variable appNameVFile $appNameV

    if {[tcldevkit::tk::present]} {
	if {![string equal $tclvers ""]} {
	    # Show only major.minor in the title
	    # strip alpha/beta segments
	    regsub -all {[ab][0-9]+} $tclvers . tclvers
	    regsub -all {[.][.]}     $tclvers . tclvers
	    # reduce to major.minor
	    set tclvers [join [lrange [split $tclvers .] 0 1] .]
	    set appNameD "$appNameD for $tclvers"
	}

	wm title . $appNameD

	if {[tk windowingsystem] eq "aqua"} {
	    # On OS X put the name into the Menubar as well. Otherwise
	    # the name of the interpreter executing the application is
	    # used.
	    package require tclCarbonProcesses 1.1
	    carbon::setProcessName [carbon::getCurrentProcess] $name
	}

	if {[tk windowingsystem] ne "aqua"} {
	    variable icon
	    setIcon $icon
	}
    }
    return
}

proc ::tcldevkit::appframe::setIcon {data} {
    variable icon
    if {[lsearch -exact [image names] $data] != -1} {
	set icon $data
    } elseif {[file exists $data]} {
	if {[catch {set icon [image create photo -file $data]} err]} {
	    return
	}
    } elseif {$data ne ""} {
	if {[catch {set icon [image create photo -data $data]} err]} {
	    return
	}
    } else {
	return
    }
    wm iconphoto . -default $icon
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::Clear {} {
    variable nb
    variable lastsaved
    variable appNameD

    # Bug 47728: Undefine lastsaved so that next save forces the user
    # to chose a new name for the new project.

    set lastsaved {}
    $nb reset

    # Bug 76276. Remove project name from title bar as well.
    wm title . "$appNameD"

    SaveMenuStateHookInvoke noproject
    return
}

proc ::tcldevkit::appframe::HasProject {path} {
    variable lastsaved $path
    SaveMenuStateHookInvoke hasproject
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::Exit {} {
    variable dirty
    variable appNameVFile
    if {!$dirty}   exit

    set reply [tk_messageBox \
	    -icon warning -type yesnocancel \
	    -default yes \
	    -title "Save \"$appNameVFile\" configuration" \
	    -parent . -message "The current configuration is\
	    changed, yet not saved.\n\nDo you wish to save it ?"]

    switch -exact -- $reply {
	yes    {Save -1 ; exit}
	no     {exit}
	cancel {
	    # Exiting is canceled!
	    return
	}
    }
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::Help {} {
    if {[catch {
	help::open
    } msg]} {
	if {
	    [string match {Error displaying*}  $msg] &&
	    [string match {*couldn't execute*} $msg]
	} {
	    regexp {couldn't execute \"(.*)\"} -> browser
	    tk_messageBox \
		-icon error -type ok \
		-title "Help Error" \
		-parent . -message "Unable to show the help, browser $browser was not found or is not executable.\n\nPlease set the environment variable BROWSER to the path of a usable web browser."
	    return
	}

	if {[string match {Could not find a browser*} $msg]} {
	    tk_messageBox -icon error -title "Help Error" \
		-type ok \
		-message "Unable to find a browser to display the help.\n\nPlease set the environment variable BROWSER to the path of a usable web browser."
	    return
	}

	return -code error -errorinfo $::errorInfo -errorcode $::errorCode $msg
    }
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::Save {saveas} {
    variable lastdir
    variable lastsaved
    variable appName
    variable appNameVFile
    variable appNameD
    variable appNameV
    variable dirty

    #           / -1 - Chose automatically between 0/1.
    # saveas = <   0 - Use the name of the last saved project.
    #           \  1 - Chose name explicitly

    if {$saveas == -1} {
	if {$lastsaved == {}} {
	    set saveas 1
	} else {
	    set saveas 0
	}
    }

    if {$saveas} {
	# Let user choose where to save

	variable projExt
	variable projExtF
	if {$lastsaved != {}} {
	    set outfile [tk_getSaveFile \
		-title       "Save $appNameVFile configuration" \
		-parent      . \
	        -initialfile [file tail $lastsaved] \
		-initialdir  $lastdir \
		-filetypes   [SaveExtensionHookInvoke all]
	    ]
	} else {
	    set outfile [tk_getSaveFile \
		-title      "Save $appNameVFile configuration" \
		-parent     . \
		-initialdir $lastdir \
		-filetypes  [SaveExtensionHookInvoke all]
	    ]
	}
	if {$outfile == {}} {return 0}
	set lastdir [file dirname $outfile]

	log::log debug "SAVE. Raw path   ($outfile)"

	# Append default extension if not provided by the dialog.
	if {[file extension $outfile] == {}} {
	    log::log debug "SAVE. Adding ($projExtF), extension was missing"
	    append outfile [SaveExtensionHookInvoke default]
	}

	log::log debug "SAVE. Final path ($outfile)"
    } else {
	# Write to the loaded project file.

	set outfile $lastsaved
    }

    #  Check permissions first.

    if {[file exists $outfile]} {
	if {![file writable $outfile]} {
	    tk_messageBox -icon error \
		-parent . -type ok \
		-title "Save $appNameVFile Error" \
		-message "Unable to save to the chosen file. \
                          It exists and is not writable. "
	    return
	}
    } else {
	if {[catch {
	    set ch [open $outfile w]
	} msg]} {
	    tk_messageBox -icon error -title {Tcl Dev Kit Save Error} \
		-type ok -message "Could not create \"$outfile\"."
	    return
	}
	# Can be created. Restore non-existence for actual save op.
	close $ch
	file delete -force $outfile
    }

    # Run the actual save operation.

    SaveHookInvoke $outfile $saveas

    SaveMenuStateHookInvoke hasproject
    markclean

    set lastsaved $outfile

    if {$saveas} {
	wm title . "$appNameD : [file tail $outfile]"
    }

    return 1
}

proc ::tcldevkit::appframe::SaveExtensions {cmd} {
    variable projExt
    variable projExtF

    if {$cmd eq "all"} {
	return  $projExt
    } elseif {$cmd eq "default"} {
	return  $projExtF
    } else {
	return -code error "Bad extension hook cmd \"$cmd\""
    }
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::SaveHookSet {cmdprefix} {
    variable saveHook $cmdprefix
    return
}

proc ::tcldevkit::appframe::SaveExtensionHookSet {cmdprefix} {
    variable saveExtensionHook $cmdprefix
    return
}

proc ::tcldevkit::appframe::SaveHookInvoke {path saveas} {
    variable saveHook
    return [uplevel \#0 [linsert $saveHook end $path $saveas]]
}

proc ::tcldevkit::appframe::SaveExtensionHookInvoke {cmd} {
    variable saveExtensionHook
    return [uplevel \#0 [linsert $saveExtensionHook end $cmd]]
}

proc ::tcldevkit::appframe::SaveConfig {outfile saveas} {
    variable appName
    variable appNameFile
    variable appNameV
    variable appNameVFile
    variable appVers
    variable writemode
    variable nb

    if {[file exists $outfile]} {
	foreach {pro tool} [::tcldevkit::config::Peek/2.0 $outfile] { break }

	if {$pro && ![string equal $tool $appNameFile]} {
	    # The chosen file exists, is a Tcl Dev Kit Project File in
	    # Format 2.0, and was written by a different tool than the
	    # current one. Ask the user again, if overwriting it is
	    # wanted.

	    set reply [tk_messageBox \
		    -icon warning -type yesno \
		    -default no \
		    -title "Save $appNameVFile configuration" \
		    -parent . -message "The chosen file \"$outfile\"\
		    contains project information for \"$tool\", whereas\
		    we are the $appNameFile.\n\nDo you truly wish to\
		    overwrite the contents of this file ?"]

	    if {[string equal $reply "no"]} {
		return
	    }
	}
    }

    ::tcldevkit::config::Write${writemode}/2.0 $outfile [$nb configuration] \
	    $appNameFile $appVers
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::SaveMenuStateHookSet {cmdprefix} {
    variable saveMenuStateHook $cmdprefix
    return
}

proc ::tcldevkit::appframe::SaveMenuStateHookInvoke {loadstate} {
    variable saveMenuStateHook
    return [uplevel \#0 [linsert $saveMenuStateHook end $loadstate]]
}

proc ::tcldevkit::appframe::SaveMenuState {loadstate} {
    if {$loadstate eq "hasproject"} {
	menu save   -> normal
	menu saveas -> normal
    } else {
	menu save   -> disabled
	menu saveas -> normal
    }
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::LoadChainAppend {cmd} {
    variable loadchain
    lappend  loadchain $cmd
    return
}

proc ::tcldevkit::appframe::Load {} {
    variable appNameVFile
    variable lastdir
    variable lastsaved
    variable projExt

    set infile [tk_getOpenFile \
	    -title     "Load $appNameVFile configuration" \
	    -parent    . \
	    -initialdir $lastdir \
	    -filetypes $projExt
    ]

    if {$infile == {}} {return}
    set lastdir [file dirname $infile]

    LoadChainInvoke $infile
    return
}

proc ::tcldevkit::appframe::LoadChainInvoke {path} {
    variable loadchain
    variable appNameD
    variable lastsaved

    set messages {}
    foreach loader $loadchain {
	set msg {}
	set status [eval [linsert $loader end $path msg]]
	if {$status eq "ok"} {
	    # This loader has sucessfully processed the chosen
	    # path. Stop.

	    set lastsaved $path

	    SaveMenuStateHookInvoke hasproject
	    markclean

	    wm title . "$appNameD : [file tail $path]"
	    return
	}

	if {$status eq "fatal"} {
	    # Fatal failure in this loader, report, and stop.
	    LoadError $path [list $msg]
	    return
	}

	# status 'rejected'
	# This loader failed, but not in a fatal way, remember
	# the message, and invoke the next loader, if any.
	lappend messages $msg
    }

    LoadError $path $messages
    return
}

proc ::tcldevkit::appframe::LoadError {path messagelist} {
    set mtitle  "Error while loading configuration file"
    set message "${mtitle}:\n\n  ${path}\n\n[join $messagelist \n\n]"

    if {[tcldevkit::tk::present]} {
	tk_messageBox -type ok -icon error -parent . \
	    -title $mtitle \
	    -message $message
    } else {
	puts stderr \n$message\n
    }
    return
}

proc ::tcldevkit::appframe::LoadConfiguration/2.0 {infile mv} {
    variable nb
    variable appName
    variable appNameFile
    variable readmode

    upvar 1 $mv message

    # Check the chosen file for format conformance.

    foreach {pro tool} [::tcldevkit::config::Peek/2.0 $infile] { break }

    if {!$pro} {
	# Wrong format. Reject, fatal only if there is no other loader
	# coming after this one.
	set fmtbase "File format not recognized.\n\nThe chosen file does not contain Tcl Dev Kit Project information."
	set message $fmtbase
	return rejected
    }

    # Check that the application understands the information in the
    # file. To this end we ask the master widget for a list of
    # application names it supports. If this results in an error we
    # assume that only files specifically for this application are
    # understood.

    if {[catch {
	set allowed_tools [$nb configuration tools]
    }]} {
	set allowed_tools [list $appNameFile]
    }
    if {[lsearch -exact $allowed_tools $tool] < 0} {
	# Is a project file, but not for this tool.
	# Non-fatal rejection.
	set fmttool "The chosen Tcl Dev Kit Project file does not contain information for $appNameFile, but"
	set message "$fmttool $tool"
	return rejected
    }

    # The file has been accepted as belonging to this loader. Any
    # other problem found with it will cause a fatal rejection to
    # prevent other loaders from even trying.

    # The file is tentatively identified as project file for this
    # tool, so read the information in it. If more than one tool is
    # supported by the application we ask its master widget for the
    # list of keys acceptable for the found tool.

    if {[llength $allowed_tools] > 1} {
	set allowed_keys [$nb configuration keys $tool]
    } else {
	set allowed_keys [$nb configuration keys]
    }

    if {[catch {
	set cfg [::tcldevkit::config::Read${readmode}/2.0 $infile \
		$allowed_keys]
    } msg]} {
	set fmtkey  "Unable to handle the following keys found in the Tcl Dev Kit Project file for"
	set message "$fmtkey ${tool}:\n\n$msg"
	return fatal
    }

    if {[catch {
	# If more than one tool configuration is supported we tell the
	# master widget not only the configuration, but also for what
	# tool it is for.

	# Bugzilla 27128 / HACK
	# Provide name of loaded file to the application code.
	# The application may not support this, hence we catch.

	catch {$nb configuration fname $infile}

	if {[llength $allowed_tools] > 1} {
	    $nb configuration = $cfg $tool
	} else {
	    $nb configuration = $cfg
	}
    } msg]} {
	set message $msg
	return fatal
    }

    # File was not only accepted but sucessfully read and stored into
    # the application state. We are good.
    return ok
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::markdirty {} {
    variable dirty
    set      dirty 1
    return
}

proc ::tcldevkit::appframe::markclean {} {
    variable dirty
    set      dirty 0
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::initConfig {configfile} {
    variable initial_cfg {}
    if {$configfile != {}} {
	set initial_cfg $configfile
    }
    return
}

proc ::tcldevkit::appframe::feedback {flag} {
    if {$flag} {
	.main showstatusbar progression
	.main configure \
		-progresstype nonincremental_infinite \
		-progressmax 100
    } else {
	.main showstatusbar status
    }

    update
    return
}
proc ::tcldevkit::appframe::feednext {} {
    variable progress
    incr     progress

    update
    return
}

proc ::tcldevkit::appframe::nb {} {
    variable nb
    return  $nb
}

proc ::tcldevkit::appframe::run {subpackage {script {}}} {
    variable lastsaved
    package require $subpackage
    set ::tcldevkit::appframe::progress 0

    variable initial_cfg
    variable nb
    variable                                            menu
    variable                      status_message ""

    MainFrame .main -textvariable status_message -menu $menu \
	    -progressvar ::tcldevkit::appframe::progress

    .main showstatusbar status
    set fr [.main getframe]
    set nb [::$subpackage $fr.nb]

    grid .main -column 0 -row 0 -sticky swen
    grid columnconfigure . 0 -weight 1
    grid rowconfigure    . 0 -weight 1

    grid $nb -column 0 -row 0 -sticky swen
    grid columnconfigure $fr 0 -weight 1
    grid rowconfigure    $fr 0 -weight 1

    ## Special code of the application itself

    if {$script != {}} {
	uplevel #0 $script
    }

    ## Start the event loop (Can't assume wish and a running
    ## eventloop).

    SaveMenuStateHookInvoke noproject
    markclean

    if {$initial_cfg != {}} {
	LoadChainInvoke $initial_cfg
    }

    update idle
    wm deiconify .

    if {[tcldevkit::tk::present]} {
	splash::complete
    }

    vwait __forever
    exit [expr {$status == 0}]
    return
}

# -----------------------------------------------------------------------------


proc ::tcldevkit::appframe::Init {} {
    variable menu

    set hastk 0
    if {[tcldevkit::tk::present]} {
	wm  withdraw .
	wm  protocol . WM_DELETE_WINDOW ::tcldevkit::appframe::Exit

	splash::start
	set hastk 1
    }

    set fmenu {
	{command {&New Project}        {new}    {New Configuration}                {} -command ::tcldevkit::appframe::Clear}
	{separator}
	{command {&Save Project}       {save}   {Save configuration, use known name} {} -command {::tcldevkit::appframe::Save 0}}
	{command {&Save Project As...} {saveas} {Save configuration and choose name} {} -command {::tcldevkit::appframe::Save 1}}
	{command {&Load Project...}    {load}   {Load a configuration}               {} -command ::tcldevkit::appframe::Load}
    }

    set hcmd {command &Help {help} {Launch help viewer} {F1} -command ::tcldevkit::appframe::Help}

    if {$hastk} {
	lappend hcmd -compound left -image [image::get help]

	set hmenu [list $hcmd]

	if {[tk windowingsystem] ne "aqua"} {
	    lappend fmenu separator \
		    {command &Exit {exit} {Exit the application} {} -command ::tcldevkit::appframe::Exit}
	    lappend hmenu separator \
		[list command "&About $::projectInfo::productName" {about} {Show copyright information} {} -command splash::showAbout]
	} else {
	    interp alias "" ::tk::mac::Quit "" ::tcldevkit::appframe::Exit
	    bind all <Command-q> ::tk::mac::Quit
	}
    } else {
	set hmenu [list $hcmd]
    }

    set menu {}

    if {$hastk} {
	if {[tk windowingsystem] eq "aqua"} {
	    # Get the About into the special .apple menu, which has to be FIRST.
	    set acmd [list command "&About $::projectInfo::productName" {about} {Show copyright information} {} -command splash::showAbout]
	    lappend menu &TDK {} apple 0 [list $acmd separator]
	}
    }

    # Default appframe menus
    lappend menu &File {} fmenu 0 $fmenu
    lappend menu &Help {} help  0 $hmenu
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::setkey {w k command} {

    bind $w <Key-$k> $command
    foreach c [winfo children $w] {
	setkey $c $k $command
    }
    return
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::mapOut {map arrayvar} {
    upvar 1 $arrayvar serial
    foreach {old new} $map {
	set   serial($new) $serial($old)
	unset serial($old)
    }
    return
}

proc ::tcldevkit::appframe::mapIn {map arrayvar} {
    upvar 1 $arrayvar serial
    foreach {old new} $map {
	# Ignore missing keys. They simply do not influence the
	# current configuration.

	if {[info exists serial($new)]} {
	    set   serial($old) $serial($new)
	    unset serial($new)
	}
    }
    return
}

proc ::tcldevkit::appframe::mapKeys {map} {
    set res [list]
    foreach {old new} $map {lappend res $new}
    return $res
}

# -----------------------------------------------------------------------------

proc ::tcldevkit::appframe::NeedReadOrdered {} {
    variable readmode
    set      readmode Ordered
    return
}

proc ::tcldevkit::appframe::NeedWriteOrdered {} {
    variable writemode
    set      writemode Ordered
    return
}

proc ::tcldevkit::appframe::setProjExt {label newext} {
    variable projExt  [list [list $label [list $newext]] {All {*}}]
    variable projExtF $newext
    return
}

proc ::tcldevkit::appframe::clearProjExt {} {
    variable projExt  {}
    variable projExtF {}
    return
}

proc ::tcldevkit::appframe::appendProjExt {label newext} {
    variable projExt
    variable projExtF

    lappend projExt  [list $label [list $newext]]
    if {$newext eq "*"} return
    set projExtF $newext
    return
}

proc ::tcldevkit::appframe::setInitialDir {dir} {
    variable lastdir $dir
    return
}

proc ::tcldevkit::appframe::menu {menu _ state} {
    .main setmenustate $menu $state
    return
}

proc ::tcldevkit::appframe::appVersion {} {
    variable appVers
    return  $appVers
}

proc ::tcldevkit::appframe::appName {} {
    variable appName
    return  $appName
}

proc ::tcldevkit::appframe::menu {menu _ state} {
    .main setmenustate $menu $state
    return
}

namespace eval ::tcldevkit::appframe {
    variable appNameD  {} ; # Display (Window Titles)
    variable appName   {} ; # Config File tool name
    variable appNameFile {} ;# As above
    variable appVers   {}
    variable appNameV  {}
    variable appNameVFile  {}
    variable nb        {}
    variable menu      {}
    variable lastdir   [pwd]
    variable lastsaved {}
    variable readmode  {}
    variable writemode {}
    variable dirty     0
    variable projExt   {{TPJ {.tpj}} {All {*}}}
    variable projExtF  .tpj

    variable dynhelp ; array set dynhelp {}
    variable off     ; array set off     {}

    # List of commands to use when loading a project file.
    # Default: Standard command for .tpj syntax-based files.
    variable loadchain {
	::tcldevkit::appframe::LoadConfiguration/2.0
    }

    # Hook to intercept the saving of a project file.

    variable saveHook \
	::tcldevkit::appframe::SaveConfig

    # Hook to intercept various manipulations of the save(as) menu
    # buttons (during/after load and save of project files).

    variable saveMenuStateHook \
	::tcldevkit::appframe::SaveMenuState

    # Hook to return file extension information during save, to allow
    # for per dynamic changes based on the loaded project.

    variable saveExtensionHook \
	::tcldevkit::appframe::SaveExtensions
}

# -----------------------------------------------------------------------------

::tcldevkit::appframe::Init
package provide tcldevkit::appframe 1.0
