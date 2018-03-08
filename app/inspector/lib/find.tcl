# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# find.tcl --
#
#	This file defines the find dialog for Inspector
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
#
#

snit::widget find_dialog {
    hulltype toplevel

    option -attach	""
    option -search_type regexp
    option -match_case  0
    option -allowglob   1
    option -title       ""
    option -parent      ""

    constructor {args} {
	set t [ttk::frame $self.top]
	set r [ttk::frame $self.right]
	set y [ttk::labelframe $self.type -text " Search Type: "]
	set b [ttk::frame $self.btm]

	ttk::button $r.go    -text "Find Next" -state disabled \
	    -command [list $self search] -default active
	ttk::button $r.reset -text "Reset" -command [list $self reset]
	ttk::button $r.close -text "Cancel" -command [list destroy $self]

	bind $self <Escape> [list $r.close invoke]

	ttk::label $t.l -text "Find what:"
	ttk::entry $t.e -validate key \
	    -validatecommand [list $self find_ok %P]
	bind $t.e <Return> [list $r.go invoke]

	ttk::checkbutton $y.ex -variable [varname options(-search_type)] \
	    -onvalue exact -offvalue exact -text "Exact"
	ttk::checkbutton $y.gl -variable [varname options(-search_type)] \
	    -onvalue glob -offvalue exact -text "Glob"
	ttk::checkbutton $y.re -variable [varname options(-search_type)] \
	    -onvalue regexp -offvalue exact -text "Regexp"
	ttk::checkbutton $b.mc -variable [varname options(-match_case)] \
	    -onvalue 1 -offvalue 0 -text "Case Sensitive"

	grid $t.l $t.e -sticky ew -pady 2
	grid columnconfigure $t 1 -weight 1
	pack $y.ex $y.gl $y.re -fill both -side left -padx 2 -pady 2
	if {!$options(-allowglob)} {
	    pack forget $y.gl
	}
	pack $y.ex $y.re -fill both -side left -padx 2 -pady 2
	pack $b.mc -fill both -side top -padx 2 -pady 2
	pack $r.go $r.reset -fill both -side top -padx 2 -pady 2
	pack $r.close -fill both -side bottom -padx 2 -pady 2
	grid $t -row 0 -column 0 -sticky news -padx 2 -pady 2
	grid $r -row 0 -column 1 -rowspan 3 -sticky news -padx 2 -pady 2
	grid $y -row 1 -column 0 -sticky news -padx 2 -pady 2
	grid $b -row 2 -column 0 -sticky news -padx 2 -pady 2
	grid columnconfigure $self 0 -weight 1
	grid rowconfigure $self 2 -weight 1

	$self configurelist $args

	$t.e validate

	if {![winfo exists $options(-parent)]} {
	    set options(-parent) [winfo toplevel $options(-attach)]
	}

	wm title $self $options(-title)
	wm group $self $options(-parent)
	wm transient $self $options(-parent)
	wm resizable $self 1 0
	focus $self.top.e
    }
    onconfigure -attach {value} {
	if {![winfo exists $value]} {
	    return -code error "invalid window \"$value\" for -attach"
	}
	set options(-attach) $value
    }
    method find_ok {str} {
	$self.right.go configure \
		-state [expr {[string length $str]?"normal":"disabled"}]
	return 1
    }
    method reset {} {
	# Clear search results and reset dialog to original vals
	set options(-search_type) exact
	set options(-match_case)  0
	$self.top.e delete 0 end
	$options(-attach) reset_search 1
    }
    method search {} {
	set text [$self.top.e get]
	if {![string length $text]} return
	$options(-attach) search \
	    $options(-search_type) $options(-match_case) $text
    }
}
