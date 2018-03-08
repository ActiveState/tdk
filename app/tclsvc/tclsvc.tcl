# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclsvc.tcl
#
#	A basic Tcl service manager application.
#	This uses the ActiveState tclsvc package to create and maintain
#	services on Windows NT/2K/XP for Tcl scripts.
#
# Copyright (c) 2002-2006 ActiveState Software Inc.
#
# See the file "license.txt" for information on usage and redistribution

#

if {[string match -psn* [lindex $::argv 0]]} {
    # Strip Apple's option providing the Processor Serial Number to bundles.
    incr ::argc -1
    set  ::argv [lrange $::argv 1 end]
}

package require Tk 8.4
wm withdraw .

if {$::tcl_platform(platform) ne "windows"
    || $::tcl_platform(os) ne "Windows NT"} {
    tk_messageBox -icon error -title "TclSvc Requires Windows NT" \
	-type ok -message "TclSvc Requires a Windows NT-based operating system"
    exit 1
}

package require style::as
style::as::init
style::as::enable control-mousewheel global

package require splash
::splash::start 1000 ; # 1 sec minimum

package require tile    ; set ::TILE 1
package require BWidget ; Widget::theme 1
package require widget::scrolledwindow
package require widget::dialog
package require Tktable
package require registry
package require win32; # private TDK win32 library
package require vfs::mk4
package require fileutil
package require tooltip
namespace import -force ::tooltip::tooltip
package require projectInfo

# Handle Tk 8.5 (ttk) or 8.4 (tile) usage of style
namespace eval ::ttk {
    # Ttk style mapping for invalid entry widgets
    style map TEntry -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
    style map TEntry -fieldbackground {alternate \#FFFFE0} \
	-foreground {alternate \#FF0000}
    style map TCombobox -fieldbackground {invalid \#FFFFE0} \
	-foreground {invalid \#FF0000}
}

# Do license check
if {[catch {package require compiler; compiler::tdk_license user-name} err]} {
    wm withdraw .
    if {![string match "*license*" $err]} {
	set err "Failed license check"
    }
    tk_messageBox -icon error -title "Invalid License" -type ok -message $err
    exit 1
}

namespace eval ::svc {
    variable VERSION 1.1
    variable DIR
    set DIR(EXE)    [file normalize [file dirname [info nameofexecutable]]]
    set DIR(SCRIPT) [file normalize [file dirname [info script]]]
    set DIR(IMAGES) [file join $DIR(SCRIPT) images]
    set DIR(LAST)   $DIR(EXE)

    variable executable ""; # base tclsvckit executable
    variable script     ""; # script to use for service
    variable starpack   ""; # starpack to use for service
    variable disp       ""; # display name of service
    variable desc       ""; # description of service
    variable type       ""; # type of service to create (starpack or script)
}

bind all <Control-q> { exit }

# This is the base services key.  Append appName for key to use.
set ::KEY "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\"

proc ::svc::GetExecutable {} {
    variable DIR
    set names [list tclsvc84.exe]
    if {[info exists ::env(TCLSVC_EXECUTABLE)]} {
	set names [linsert $names 0 $::env(TCLSVC_EXECUTABLE)]
    }
    foreach name $names {
	foreach exe [list [file join $DIR(EXE) $name] [auto_execok $name]] {
	    if {[file exists $exe]} {
		return [file nativename $exe]
	    }
	}
    }
}

proc ::svc::Init {argc argv {base {}}} {
    variable W
    variable DIR

    set root [expr {$base == "" ? "." : $base}]
    wm withdraw $root

    set W(base) $base
    set W(root) $root

    if {($argc & 1) || $argc > 6} {
	return -code error "Usage: $::argv0 ?-script script?\
		?-starpack starpack?\
		?-servicename name? ?-description text?"
    }
    foreach {key val} $argv {
	switch -glob -- $key {
	    "-script"   { set ::svc::script $val  ; set ::svc::type "script" }
	    "-starpack" { set ::svc::starpack $val; set ::svc::type "starpack" }
	    "-service*" { set ::svc::disp   $val }
	    "-desc*"    { set ::svc::desc   $val }
	}
    }

    # load constituent files
    uplevel #0 [list source [file join $DIR(SCRIPT) toolbar.tcl]]

    # load our images
    foreach img [glob -nocomplain -directory $DIR(IMAGES) *.gif] {
	image create photo [file tail $img] -file $img
    }

    set menus [InitMenus $base]

    ttk::separator $base.menusep -orient horizontal

    set tbar [Toolbar $base]

    ttk::separator $base.tbarsep -orient horizontal

    set main [InitMainUI $base]

    grid $base.menusep -row 0 -column 0 -sticky ew
    grid $tbar         -row 1 -column 0 -sticky ew
    grid $base.tbarsep -row 2 -column 0 -sticky ew
    grid $main         -row 3 -column 0 -sticky news -pady {2 0}

    # make the notebook the resizable component
    grid rowconfigure    $root 3 -weight 1
    grid columnconfigure $root 0 -weight 1

    set ::svc::executable [GetExecutable]
    if {![file exists $::svc::executable]} {
	tk_messageBox -title "TclSvc Error" -icon error -type ok \
	    -message "No base service executable found"
	exit 1
    }

    wm title $root "Tcl Service Manager"
    wm geometry $root 400x200
    update idle
    wm deiconify $root

    refresh
}

proc ::svc::InitMenus {base} {
    set root [expr {$base == "" ? "." : $base}]
    set menu [menu $base.menu]
    $root configure -menu $menu

    foreach m {File Help} {
	set l [string tolower $m]
	$menu add cascade -label $m -underline 0 -menu $menu.$l
    }

    # File Menu
    #
    set m [menu $menu.file -tearoff 0]
    $m add command -compound left -image new.gif \
	-label " New Tcl Service" -underline 1 -command ::svc::new
    $m add separator
    $m add command -compound left -image refresh.gif \
	-label " Refresh" -underline 1 -command ::svc::refresh
    $m add separator
    $m add command -label "Exit" -underline 1 -command exit

    # Help Menu
    #
    set m [menu $menu.help -tearoff 0]
    $m add command -compound left -image help.gif \
	-label "Help" -underline 0 -command ::svc::help \
	-accelerator F1
    $m add separator
    $m add command -label "About $::projectInfo::productName" -underline 0 -command ::splash::showAbout

    bind $root <Key-F1> [list $m invoke Help]

    return $menu
}

proc ::svc::install {} {
    variable executable ; # set above
    variable type       ; # set above
    variable disp       ; # set above
    variable script     ; # set above
    variable starpack   ; # set above
    variable desc       ; # set above
    set err ""
    if {![file executable $executable]} {
	set err "Invalid base service executable \"$executable\""
    } elseif {$disp == ""} {
	set err "Missing service display name"
    } elseif {[string match {*[\"\./\\\*\[\+\?]*} $disp]} {
	set err "Service name may not contain \"./\\*+?\"[]\""
    } elseif {[catch {registry keys $::KEY $disp} keys]} {
	set err "Error accessing registry:\n$keys"
    } elseif {$type eq "script" && ![file isfile $script]} {
	set err "Invalid script \"$script\""
    } elseif {$type eq "starpack" && ![file executable $starpack]} {
	set err "Invalid starpack \"$starpack\""
    }
    if {$err != ""} {
	tk_messageBox -icon info -title "Install Service Error" \
	    -message $err -type ok
	return 0
    }

    if {[string length $keys]} {
	if {[tk_messageBox -icon warning \
		-title "Overwrite Service \"$disp\"" \
		-message "Service \"$disp\" exists.  Overwrite?" \
		-type yesno] == "no"} {
	    tk_messageBox -icon info -title "Install Service Aborted" \
		    -message "No service installed." -type ok
	    return 0
	}
    }

    if {$type eq "script"} {
	set TclScript [list source $script]
	set useExe $executable
    } else {
	#set TclScript "starpack"
	set TclScript "source \[list \[file join \[info nameofexe\] main.tcl\]\]"
	set useExe [file nativename $starpack]
    }

    # Registry keys to set:
    # ImagePath   == base executable
    # TclScript   == script to eval (source $script)
    # DisplayName == key's name
    # Description == long description
    #
    set key $::KEY$disp
    if {[catch {
	::win32::svc::CreateService $disp \
	    -command     token \
	    -description $desc \
	    -displayname $disp \
	    -pathname    "\"$useExe\" \"$disp\"" \
	    -starttype   automatic
	registry set $key "TclScript" $TclScript
    } err]} {
	tk_messageBox -type ok -icon error -title "Error Creating Service" \
	    -message $err
	return 0
    }
    token close

    tk_messageBox -type ok -icon info -title "Service Installed" \
	-message "Service \"$disp\" successfully installed."
    after 100 [list ::svc::refresh]
    return 1
}

proc ::svc::services {} {
    if {[catch {registry keys $::KEY} keys]} {
	return -code error "Error accessing registry:\n$keys"
    }
    set svcs [list]
    set fetch "" ; # TclScript
    foreach key $keys {
	if {0} {
	    if {![catch {::win32::svc::OpenService $key token}]} {
		token close
		lappend svcs $key
	    }
	} else {
	    if {![catch {registry get $::KEY$key TclScript} script]} {
		# This is a tclsvc service
		lappend svcs $key
	    }
	}
    }
    return [lsort $svcs]
}

proc ::svc::refresh {} {
    variable W
    variable DATA
    set w $W(table)
    set svcs [::svc::services]
    $w configure -state normal
    $w clear all
    array unset DATA
    foreach {span dist} [$w spans] {
	$w span $span 0,0
    }
    set DATA(0,0) "Service Name"
    set DATA(0,1) "Tcl Script"
    set DATA(0,2) "Status"
    set DATA(0,3) "Startup"
    set DATA(0,4) "Description"
    $w width 0 12
    if {$svcs == ""} {
	$w configure -cols 5 -rows 2
	$w set 1,0 "NO TCL SERVICES FOUND"
	$w span 1,0 0,4
    } else {
	$w configure -cols 5 -rows [expr {[llength $svcs]+1}]
	set i 1
	foreach svc $svcs {
	    if {[catch {::win32::svc::OpenService $svc token} err]} {
		set msg "Error Accessing Service \"$svc\":\n  $err"
		append msg "\nYou may need to run as Administrator."
		append msg "\nContinue processing?"
		set res [tk_messageBox -title "Error Accessing Service" \
			     -type okcancel -message $msg]
		if {$res eq "cancel"} {
		    break
		} else {
		    continue
		}
	    }
	    array set info [token configure]
	    set info(status) [token control]
	    token close
	    catch {registry get $::KEY$svc TclScript} info(script)
	    if {[string match {source \[list * main.tcl\]\]} $info(script)]} {
		set info(script) "starpack"
		if {![catch {registry get $::KEY$svc ImagePath} path]} {
		    append info(script) " ([lindex [split $path] 0])"
		}
	    } elseif {[string match {source *} $info(script)]} {
		set info(script) [join [lrange $info(script) 1 end]]
	    }
	    set DATA($i,service) $svc
	    set DATA($i,0) $info(-displayname)
	    set DATA($i,1) $info(script)
	    set DATA($i,2) $info(status)
	    set DATA($i,3) $info(-starttype)
	    set DATA($i,4) $info(-description)
	    incr i
	    unset info
	}
    }
    $w configure -state disabled

    foreach btn {info remove start stop pause} {
	$W($btn) configure -state disabled -command {}
    }
}

proc ::svc::TableSelect {w row} {
    variable W
    variable DATA

    if {$row == 0} {
	# nothing changes for selecting the first row
	return
    }
    foreach btn {info remove start stop pause} {
	$W($btn) configure -state disabled -command {}
    }
    if {![info exists DATA($row,service)]} {
	return
    }

    set svc $DATA($row,service)
    ::win32::svc::OpenService $svc token
    $W(remove) configure -state normal -command [list ::svc::remove $svc]
    switch -exact -- [token control] {
	"continuepending" -
	"pausepending" -
	"startpending" -
	"stoppending" {
	    # do nothing for now
	}
	"paused" {
	    if {0} {
		# no pause capability for now
		$W(pause) configure -state normal \
		    -command [list ::svc::Control $svc continue]
	    }
	}
	"running" {
	    $W(stop)  configure -state normal \
		-command [list ::svc::Control $svc stop]
	    if {0} {
		# no pause capability for now
		$W(pause) configure -state normal \
		    -command [list ::svc::Control $svc pause]
	    }
	}
	"stopped" {
	    if {[token configure -starttype] ne "disabled"} {
		$W(start) configure -state normal \
		    -command [list ::svc::Control $svc start]
	    }
	}
    }
    token close
}

proc ::svc::InitMainUI {base} {
    variable W
    variable DATA

    set sw [widget::scrolledwindow $base.sw -relief sunken -borderwidth 1 \
	       -scrollbar vertical]
    set w [set W(table) $sw.tbl]
    table $w -cache 1 -variable ::svc::DATA \
	-titlerows 1 -multiline 0 -anchor w \
	-colstretchmode last -resizeborders col \
	-selecttype row -height 5 \
	-padx 2 -pady 0 -borderwidth 2 -relief flat \
	-background white -highlightthickness 0 \
	-cursor arrow -bordercursor sb_h_double_arrow \
	-browsecommand [list ::svc::TableSelect %W %r] \
	-ellipsis "..."
    set f [frame $base.__fbg]
    set bg [$f cget -background]
    destroy $f
    $w tag configure title -relief raised -borderwidth 1 \
	-foreground black -background $bg
    $w tag configure sel -relief flat

    $sw setwidget $w
    return $sw
}

proc ::svc::remove {svc} {
    variable DATA

    if {[tk_messageBox -icon warning -title "Remove Service?" -type yesno \
	     -message "Remove Tcl Service \"$svc\"?"]=="no"} {
	return
    }

    ::win32::svc::OpenService $svc token
    if {[catch {token delete} err]} {
	tk_messageBox -type ok -icon error -title "Error Removing Service" \
	    -message $err
    }
    catch {token close}
    after 100 [list ::svc::refresh]
}

proc ::svc::Control {svc ctrl} {
    ::win32::svc::OpenService $svc token
    if {$ctrl eq "start"} {
	set cmd [list token start]
    } else {
	set cmd [list token control $ctrl]
    }
    if {[catch $cmd err]} {
	tk_messageBox -type ok -icon error -title "Error Controlling Service" \
	    -message $err
    }
    catch {token close}
    after 100 [list ::svc::refresh]
}

proc ::svc::help {} {
    set dirs [list [file join [file dirname $::svc::DIR(EXE)] doc] \
		  [file join [file dirname $::svc::DIR(SCRIPT)] doc]]
    set idx "TclDevKit.chm"
    foreach dir $dirs {
	if {[file exists [file join $dir $idx]]} {
	    set file [file join $dir $idx]
	    break
	}
    }
    if {![info exists file]} {
	tk_messageBox -title "Help Not Found" -icon error -type ok \
	    -message "Could not find TclSvc help file in any of:\
		\n[join $dirs \n]"
	return
    }
    set url "mk:@MSITStore:[file nativename $file]::/ServMgr.html"
    set url [string map {{ } %20 & ^&} $url]
    set rc [catch {exec >NUL: <NUL: $::env(COMSPEC) /c start $url &} emsg]
    if {$rc} {
	tk_messageBox -type ok -icon error -title "Error Launching Help" \
	    -message "Error Launching $url:\n$emsg"
    }
}

::svc::Init $argc $argv

::splash::complete
