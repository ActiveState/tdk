# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_search.tcl Exp $)} 1 }

snit::type ::hv3::search {

    typevariable SearchHotKeys -array {
	{Google}    g
	{Tcl Wiki}  w
    }

    variable mySearchEngines {
	----------- -
	{Google}    "http://www.google.com/search?q=%s"
	{Tcl Wiki}  "http://wiki.tcl.tk/2?Q=%s"
	----------- -
	{Ask.com}   "http://www.ask.com/web?q=%s"
	{MSN}       "http://search.msn.com/results.aspx?q=%s"
	{Wikipedia} "http://en.wikipedia.org/wiki/Special:Search?search=%s"
	{Yahoo}     "http://search.yahoo.com/search?p=%s"
    }
    variable myDefaultEngine Google

    constructor {} {
	bind Hv3HotKeys <Control-f>  [list gui_current Find]
	bind Hv3HotKeys <Control-F>  [list gui_current Find]
	foreach {label} [array names SearchHotKeys] {
	    set lc $SearchHotKeys($label)
	    set uc [string toupper $SearchHotKeys($label)]
	    bind Hv3HotKeys <Control-$lc> [mymethod search $label]
	    bind Hv3HotKeys <Control-$uc> [mymethod search $label]
	}
    }

    method populate_menu {path} {
	set cmd [list gui_current Find] 
	set acc (Ctrl-F)
	$path add command -label {Find in page...} -command $cmd \
	    -accelerator $acc

	foreach {label uri} $mySearchEngines {
	    if {[string match ---* $label]} {
		$path add separator
		continue
	    }

	    $path add command -label $label -command [mymethod search $label]

	    if {[info exists SearchHotKeys($label)]} {
		set acc "(Ctrl-[string toupper $SearchHotKeys($label)])"
		$path entryconfigure end -accelerator $acc
	    }
	}
    }

    method search {{default ""}} {
	if {$default eq ""} {set default $myDefaultEngine}

	# The currently visible ::hv3::browser_toplevel widget.
	set btl [$::hv3::G(notebook) current]

	set fdname ${btl}.findwidget
	set initval ""
	if {[llength [info commands $fdname]] > 0} {
	    set initval [${fdname}.entry get]
	    destroy $fdname
	}

	set conf [list]
	foreach {label uri} $mySearchEngines {
	    if {![string match ---* $label]} {
		lappend conf $label $uri
	    }
	}

	::hv3::googlewidget $fdname  \
	    -getcmd [list $btl goto] \
	    -config $conf            \
	    -initial $default

	$btl packwidget $fdname
	$fdname configure -borderwidth 1 -relief raised

	# Pressing <Escape> dismisses the search widget.
	bind ${fdname}.entry <KeyPress-Escape> gui_escape

	${fdname}.entry insert 0 $initval
	focus ${fdname}.entry
    }
}

snit::widget ::hv3::googlewidget {

    option -getcmd  -default ""
    option -config  -default ""
    option -initial -default Google

    delegate option -borderwidth to hull
    delegate option -relief      to hull

    variable myEngine 

    constructor {args} {
	$self configurelist $args

	set myEngine $options(-initial)

	ttk::label $win.label -text "Search:"
	ttk::entry $win.entry -width 30
	ttk::button $win.close -text "Dismiss" -command [list destroy $win]

	set w $win.menubutton
	ttk::menubutton $w -textvariable [myvar myEngine] -menu $w.menu
	::hv3::menu $w.menu
	foreach {label uri} $options(-config) {
	    $w.menu add radiobutton -label $label -variable [myvar myEngine]
	}

	pack $win.label -side left
	pack $win.entry -side left
	pack $w -side left
	pack $win.close -side right

	bind $win.entry <Return> [mymethod Search]

	# Propagate events that occur in the entry widget to the 
	# ::hv3::findwidget widget itself. This allows the calling script
	# to bind events without knowing the internal mega-widget structure.
	# For example, the hv3 app binds the <Escape> key to delete the
	# findwidget widget.
	#
	bindtags $win.entry [concat [bindtags $win.entry] $win]
    }

    method Search {} {
	array set a $options(-config)

	set search [::hv3::escape_string [${win}.entry get]]
	set query [format $a($myEngine) $search]

	if {$options(-getcmd) ne ""} {
	    set script [linsert $options(-getcmd) end $query]
	    eval $script
	}
    }
}

snit::widgetadaptor ::hv3::searchentry {
    delegate option * to hull
    delegate method * to hull

    option -command -default ""

    typeconstructor {
	set img ::hv3::img::zoom
	namespace eval ::ttk [list set img $img] ; # namespace resolved
	namespace eval ::ttk {
	    # Create -padding for space on left and right of icon
	    set pad [expr {[image width $img] + 4}]
	    style theme settings "default" {
		style layout SearchEntry {
		    Entry.field -children {
			SearchEntry.icon -side left
			Entry.padding -children {
			    Entry.textarea
			}
		    }
		}
		# center icon in padded cell
		style element create SearchEntry.icon image $img \
		    -sticky "" -padding [list $pad $pad 0 0]
	    }
	}
    }

    constructor args {
	installhull using ttk::entry -style SearchEntry

	bindtags $win [linsert [bindtags $win] 1 TSearchEntry]

	bind $win <Return> [mymethod invoke]

	$self configurelist $args
    }

    method invoke {} {
	if {[llength $options(-command)]} {
	    return [uplevel 1 $options(-command)]
	}
    }
}
