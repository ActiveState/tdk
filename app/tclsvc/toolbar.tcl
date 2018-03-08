# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# toolbar.tcl --
#
#	Toolbar management routines
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
#
# See the file "license.txt" for information on usage and redistribution

#

namespace eval ::tbar {
    variable W
    array set W {}
}

proc ::svc::Toolbar {base} {
    variable W
    set win [frame $base.tbar]

    set column 0	;# which column

    ## Create icons
    foreach {name img cmd info} {
	new     new.gif     {::svc::new} "Create New Tcl Service"
	info    gear.gif    {} "Properties"
	refresh refresh.gif {::svc::refresh} "Refresh"
	remove  delete.gif  {} "Remove Tcl Service"
	separator {} {} {}
	help    help.gif    {::svc::help} "Help"
	separator {} {} {}
	start   run.gif     {} "Start Tcl Service"
	stop    stop.gif    {}  "Stop Tcl Service"
	pause   pause.gif   {} "Pause Tcl Service"
    } {
	if {$name eq "separator"} {
	    ## separator frame
	    set w [ttk::separator $win.sep$column -orient vertical]
	    grid $w -in $win -row 0 -column [incr column] \
		-sticky ns -pady 1 -padx 3
	} else {
	    set w [set W($name) $win.$name]
	    ttk::button $w -style Toolbutton -image $img -takefocus 0 \
		-command $cmd
	    grid $w -in $win -row 0 -column [incr column] -sticky s
	    tooltip $w $info
	}
    }

    # Configure one final column to take up additional space when enlarged
    grid columnconfigure $win [incr column] -weight 1

    return $win
}

proc ::svc::new {} {
    variable W
    set w $W(base).__new
    if {![winfo exists $w]} {
	widget::dialog $w -title "Create Tcl Service" -parent $W(root) \
	    -transient 1 -type custom -synchronous 0 -padding 8
	wm attributes $w -toolwindow 1

	set f [$w getframe]

	# We have 2 kinds of services possible:
	# 1) Tcl Scripts that rely on other executables
	# 2) starpacks that can install themselves

	# script tab
	ttk::radiobutton $f.scriptl -text "Tcl Script:" \
	    -value "script" -variable ::svc::type \
	    -command [list ::svc::SelectType $f]
	entry $f.scripte -width 30 -textvariable ::svc::script \
	    -validate key -vcmd {::svc::ValidateScript %W %P}
	ttk::button $f.scriptb -text "Browse ..." -command {
	    set ::tmp [tk_getOpenFile \
			   -title "Select script to use as service" \
			   -initialdir $::svc::DIR(LAST) -filetypes {
			       {{Tcl Scripts} .tcl}
			       {{All Files} *}
			   }
		      ]
	    if {$::tmp != ""} {
		set ::svc::script $::tmp
		set ::svc::DIR(LAST) [file dirname $::tmp]
	    }
	}

	# starpack tab
	ttk::radiobutton $f.packl -text "Tcl Starpack:" \
	    -value "starpack" -variable ::svc::type \
	    -command [list ::svc::SelectType $f]
	entry $f.packe -width 30 -textvariable ::svc::starpack \
	    -validate key -vcmd {::svc::ValidateStarpack %W %P}
	ttk::button $f.packb -text "Browse ..." -command {
	    set ::tmp [tk_getOpenFile \
			   -title "Select starpack to use as service" \
			   -initialdir $::svc::DIR(LAST) -filetypes {
			       {{Tcl Starpacks} .exe}
			       {{All Files} *}
			   }
		      ]
	    if {$::tmp != ""} {
		set ::svc::starpack $::tmp
		set ::svc::DIR(LAST) [file dirname $::tmp]
	    }
	}

	ttk::label $f.displ -text "Service Display Name:" -anchor w
	entry $f.dispe -width 30 -textvariable ::svc::disp \
	    -validate key -vcmd {::svc::ValidateName %W %P} -invcmd bell
	ttk::label $f.sdescl -text "Service Description:" -anchor nw
	text $f.sdesc -width 30 -height 5 -wrap word
	if {[info exists ::svc::desc]} {
	    $f.sdesc insert 1.0 $::svc::desc
	}

	$w add button -text "Install Service" \
	    -command "set ::svc::desc \[[list $f.sdesc] get 1.0 end-1c\];\
			if {\[::svc::install\]} { [list $w] close ok }"
	$w add button -text "Cancel" -command [list $w close cancel]

	grid $f.scriptl $f.scripte $f.scriptb -sticky ew -pady 2
	grid $f.packl   $f.packe   $f.packb   -sticky ew -pady 2
	grid $f.displ   $f.dispe   -          -sticky ew -pady 2
	grid $f.sdescl  $f.sdesc   -          -sticky nsew -pady 2

	grid rowconfigure    $f 3 -weight 1; # text frame
	grid columnconfigure $f 1 -weight 1
    }
    set f [$w getframe]
    ::svc::SelectType $f
    $f.scripte validate
    $f.packe validate
    $f.dispe validate

    $w display
}

proc ::svc::SelectType {w} {
    variable type

    $w.scripte configure -state disabled
    $w.scriptb configure -state disabled
    $w.packe configure -state disabled
    $w.packb configure -state disabled
    if {$type eq "script"} {
	$w.scripte configure -state normal
	$w.scriptb configure -state normal
    } elseif {$type eq "starpack"} {
	$w.packe configure -state normal
	$w.packb configure -state normal
    }
}

proc ::svc::ValidateStarpack {w str} {
    set ok [file isfile $str]
    set bg [expr {$ok ? "white" : "lightyellow"}]
    if {$ok} {
	if {[lsearch -exact [fileutil::fileType $str] "metakit"] == -1} {
	    set bg "lightyellow"
	} else {
	    # The tested file is only read, not modified. Allow use of
	    # a non-writable file, open only as readonly.

	    if {[catch {::vfs::mk4::Mount $str $str -readonly} err]} {
		set ::svc::error $err
		set bg "lightyellow"
	    } elseif {![file exists [file join $str main.tcl]]} {
		set bg "lightyellow"
	    }
	    catch {vfs::unmount $str}
	}
    }
    $w configure -bg $bg
    return 1
}

proc ::svc::ValidateScript {w str} {
    set ok [file isfile $str]
    $w configure -bg [expr {$ok ? "white" : "lightyellow"}]
    return 1
}

proc ::svc::ValidateName {w str} {
    set ok [expr {![string match {*[\"\./\\\*\[\+\?]*} $str]}]
    $w configure -bg [expr {(($str ne "") && $ok) ? "white" : "lightyellow"}]
    return $ok
}
