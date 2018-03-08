# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: value.tcl,v 1.10 2002/03/22 01:06:46 pat Exp $
#

set value_priv(counter) -1

proc value_no_filter {text} {
    return $text
}

snit::widget value {
    hulltype ttk::frame

    option -width	64
    option -height	8
    option -main	""
    option -savehist	15
    option -searchbackground indianred
    option -searchforeground white

    variable history
    variable hist_no		0
    variable send_filter	value_no_filter
    variable search_index	1.0
    variable tw			""

    constructor args {
	$hull configure -padding [list 4 0 4 4]

	ttk::frame $win.top
	ttk::label $win.top.l -text "Value:  "
	ttk::menubutton $win.top.vname -menu $win.top.vname.m \
	    -state disabled
	menu $win.top.vname.m -postcommand [mymethod fill_vname_menu] \
	    -tearoff 0
	ttk::button $win.top.send -text "Send" \
	    -command [mymethod send_value]

	grid $win.top.l $win.top.vname x $win.top.send \
	    -sticky news -pady 2 -padx 2
	grid columnconfigure $win.top 2 -weight 1

	widget::scrolledwindow $win.sw
	set tw [text $win.sw.text -bd 0 \
		    -width $options(-width) -height $options(-height)]
	$win.sw setwidget $tw
	bind $tw <Control-x><Control-s> [mymethod send_value]
	bind $tw <Control-s>            [mymethod search_dialog]

	grid $win.top -sticky ew
	grid $win.sw -sticky news
	grid columnconfig $win 0 -weight 1
	grid rowconfigure $win 1 -weight 1

	$tw tag configure search -background $options(-searchbackground) \
	    -foreground $options(-searchforeground)

	$self configurelist $args

	set m [$options(-main) add_menu Value]
	bind $tw <3> [list tk_popup $m %X %Y]
	$m add command -label "Send Value" -command [mymethod send_value] \
	    -underline 1
	$m add command -label "Find ..." -command [mymethod search_dialog] \
	    -underline 0
	$m add command -label "Save As ..." -command [mymethod save] \
	    -underline 0
	$m add command -label "Load File ..." -command [mymethod load] \
	    -underline 0
	$m add command -label "New Window" -command [mymethod detach] \
	    -underline 0
	return
    }

    onconfigure -width {value} {
	if {$value eq $options(-width)} return
	$tw configure -width $value
    }
    onconfigure -height {value} {
	if {$value eq $options(-height)} return
	$tw configure -height $value
    }
    onconfigure -searchbackground {value} {
	if {$value eq $options(-searchbackground)} return
	$tw tag configure search -background $value
    }
    onconfigure -searchforeground {value} {
	if {$value eq $options(-searchforeground)} return
	$tw tag configure search -foreground $value
    }

    method set_value {name value redo_command} {
	$tw delete 1.0 end
	$tw insert 1.0 $value
	$win.top.vname config -text $name -state normal
	# Only save command in history if it isn't a repeat of the last one
	set histcmd [list $name $redo_command]
	if {![info exists history($hist_no)] \
		|| $history($hist_no) ne $histcmd} {
	    set history([incr hist_no]) $histcmd
	    if {($hist_no - $options(-savehist)) > 0} {
		unset history([expr {$hist_no-$options(-savehist)}])
	    }
	}
    }
    method fill_vname_menu {} {
	set m $win.top.vname.m
	catch {$m delete 0 last}
	for {set i $hist_no} {[info exists history($i)]} {incr i -1} {
	    $m add command -label "$i: [lindex $history($i) 0]" \
		-command [lindex $history($i) 1]
	}
    }
    method set_send_filter {command} {
	if {![string length $command]} {
	    set command value_no_filter
	}
	set send_filter $command
    }
    method send_value {} {
	set cmd [string trim [$tw get 1.0 end-1c]]
	set target [$options(-main) target]
	if {[string length $cmd] && [string length $target]} {
	    send $target [eval $send_filter [list $cmd]]
	    $options(-main) status "Value sent"
	} else {
	    $options(-main) status "Empty value or target - nothing sent"
	}
    }
    method detach {} {
	set w [::inspector::create_main_window \
		   -target [$options(-main) cget -target]]
	$w.value copy $tw
    }
    method copy {old} {
	$tw insert 1.0 [$old get 1.0 end-1c]
    }
    method search_dialog {} {
	if {![winfo exists $win.search]} {
	    find_dialog $win.search -attach $self -title "Find in Value" \
		-parent [winfo toplevel $win] -allowglob 0
	    center_window $win.search
	} else {
	    wm deiconify $win.search
	}
    }
    method reset_search {{set_see 0}} {
	$tw tag remove search 0.0 end
	set search_index 1.0
	if {$set_see} {
	    $tw see $search_index
	}
    }
    method search {search_type match_case text} {
	$tw tag remove search 1.0 end
	if {$text eq ""} { return }
	# only handle exact and regexp search types
	set opts ""
	if {$search_type eq "regexp"} {
	    # regexp type
	    lappend opts "-regexp"
	}
	if {!$match_case} {
	    lappend opts "-nocase"
	}
	set w $tw
	set idx [eval [list $w search] $opts [list -count numc --] \
		     [list $text $search_index end]]
	if {$idx ne ""} {
	    $w tag add search $idx "$idx + $numc chars"
	    set search_index "$idx + 1 char"
	    $w see search.first
	} else {
	    bell
	    $options(-main) status "Search text not found."
	}
    }
    method save {} {
        set file [tk_getSaveFile -title "Save Value"]
	if {![string length $file]} {
	    $options(-main) status "Save cancelled."
	    return
	}
	set fp [open $file w]
	puts $fp [$tw get 1.0 end-1c]
	close $fp
	$options(-main) status "Value saved to \"$file\""
    }
    method load {} {
        set file [tk_getOpenFile -title "Load Value"]
	if {![string length $file]} {
	    $options(-main) status "Load cancelled."
	    return
	}
	$tw delete 1.0 end
	set fp [open $file r]
	$tw insert 1.0 [read $fp]
	close $fp
	$options(-main) status "Value read from \"$file\""
    }
}
