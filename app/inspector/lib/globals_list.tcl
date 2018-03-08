# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#
# $Id: globals_list.tcl,v 1.11 2002/10/21 22:43:14 patthoyts Exp $
#

snit::widget variable_trace {
    hulltype toplevel

    option -target	""
    option -variable	""
    option -width	50
    option -height	5
    option -savelines	50
    option -main	""

    variable is_array	0
    variable trace_cmd	""
    variable tw

    constructor {args} {
	set menu [menu $win.menu]
	$hull configure -menu $menu

	# File
	set m [menu $menu.file -tearoff 0]
	$menu add cascade -label "File" -underline 0 -menu $m
	$m add command -label "Save Trace..." -underline 0 \
	    -command [list $self save]
	$m add separator
	$m add command -label "Close Window" -underline 0 \
	    -command [list destroy $self]

	widget::scrolledwindow $win.sw
	set tw [text $win.sw.text -setgrid 1 -bd 0 \
	    -width $options(-width) -height $options(-height)]
	$win.sw setwidget $tw
	pack $win.sw -fill both -expand 1

	$self configurelist $args

        set where [$options(-main) target name]
	if {![send $options(-target) ::array exists $options(-variable)]} {
	    set trace_cmd [list send $where $self update_scalar]
	    $self update_scalar "" "" w
	    set is_array 0
	    set title "Trace Scalar"
	} else {
	    set trace_cmd [list send $where $self update_array]
	    set is_array 1
	    set title "Trace Array"
	}
        $self check_remote_send
	send $options(-target) \
	    [list ::trace variable $options(-variable) wu $trace_cmd]
	wm title $win "$title: $options(-target)/$options(-variable)"
	wm iconname $win "$title: $options(-target)/$options(-variable)"
    }

    onconfigure -width {value} {
	if {$value eq $options(-width)} return
	$tw configure -width $value
    }
    onconfigure -height {value} {
	if {$value eq $options(-height)} return
	$tw configure -height $value
    }

    destructor {
	catch {send $options(-target) \
		   [list ::trace vdelete $options(-variable) wu $trace_cmd]}
    }
    method update_scalar {args} {
	set op [lindex $args end]
	if {$op eq "w"} {
	    $tw insert end-1c \
		[list set $options(-variable) \
		     [send $options(-target) [list ::set $options(-variable)]]]
	} else {
	    $tw insert end-1c [list unset $options(-variable)]
	}
	$tw insert end-1c "\n"
	$self scroll
    }
    method update_array {args} {
	set n1 [lindex $args 0]
	if {[llength $args] == 3} {
	    set n2 [lindex $args 1]
	    set op [lindex $args 2]
	} else {
	    set op [lindex $args 1]
	}
	if {$op eq "w"} {
	    $tw insert end-1c \
		[list set [set options(-variable)]([set n2]) \
		     [send $options(-target) \
			  [list ::set [set options(-variable)]([set n2])]]]
	} elseif {[info exists n2]} {
	    $tw insert end-1c \
		[list unset [set options(-variable)]([set n2])]
	} else {
	    $tw insert end-1c [list unset $options(-variable)]
	}
	$tw insert end-1c "\n"
	$self scroll
    }
    method scroll {} {
	scan [$tw index end] "%d.%d" line col
	if {$line > $options(-savelines)} {
	    $tw delete 1.0 2.0
	}
	$tw see end
    }
    method save {} {
        set file [tk_getSaveFile -title "Save $options(-variable) Trace"]
	if {![string length $file]} return
	set fp [open $file w]
	puts $fp [$tw get 1.0 end-1c]
	close $fp
	$options(-main) status "Trace saved to \"$file\"."
    }
    method check_remote_send {} {
        # ensure that the current target has a valid send command
        # This is commonly not the case under Windows.
        set cmd [send $options(-target) [list ::info commands ::send]]
        set type [$options(-main) target type]

        # If we called in using 'comm' then even if we do have a built
        # in send we need to also support using comm.
	switch -exact -- $type {
	    comm {
		set script {
		    if {[llength [info command ::send]]} {
			catch {rename ::send ::tk_send}
		    } else {
			proc ::tk_send args {}
		    }
		    proc send {app args} {
			if {[string match {[0-9]*} $app]} {
			    eval [list ::comm::comm send $app] $args
			} else {
			    eval [list ::tk_send $app] $args
			}
		    }
		}
		set cmd [send $options(-target) $script]
		$options(-main) status "comm: $cmd"
	    }
	    dde {
		set script {
		    proc send {app args} {
			eval [list dde eval $app] $args
		    }
		}
		send $options(-target) $script
	    }
	    default {
		$options(-main) status "Target requires \"send\" command."
	    }
	}
        return $cmd
    }
}

namespace eval vars {
    variable UID 0
}
proc vars::init {w args} {
    eval [list inspect_box $w \
	      -separator :: \
	      -updatecmd vars::update \
	      -retrievecmd vars::retrieve \
	      -filtercmd {}] $args
    $w add menu separator
    $w add menu command -label "Trace Variable" -underline 0 \
	-command [list vars::trace_variable $w]
    return $w
}

proc vars::update {path target} {
    return [lsort -dictionary [names::vars $target]]
}
proc vars::retrieve {path target var} {
    if {![send $target [list ::info exists $var]]} {
	return "\# [list $var] declared but not defined"
    }
    if {![send $target [list ::array exists $var]]} {
	if {[catch [list send $target [list ::set $var]] msg]} {
	    return "Unable to retrieve value of [list $var]:\\\n\t$msg\n"
	} else {
	    return [list set $var $msg]
	}
    }
    # Here we have an array
    array set local [send $target [list ::array get $var]]
    set res "array set [list $var] \{\n"
    foreach elt [lsort -dictionary [array names local]] {
	append res "    [list $elt]\t[list $local($elt)]\n"
    }
    append res "\}\n"
    unset local

    return $res
}
proc vars::trace_variable {path} {
    variable UID
    set target [$path target]
    set item   [$path curselection]
    if {$item eq ""} {
	tk_messageBox -title "No Selection" -type ok -icon warning \
	    -message "No variable has been selected.\
			Please select one first."
	return
    }

    variable_trace .vt[incr UID] -target $target \
	-variable $item -main [$path cget -main]
}
