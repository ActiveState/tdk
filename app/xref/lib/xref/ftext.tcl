# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# ftext - ScrolledWindow "ctext" /snit::widgetadaptor
#
#	Construction with file data, prearranged highlighting
#	for tcl syntax.

package require BWidget
package require ctext
package require snit

snit::widgetadaptor ::ftext {

    option -storage {}
    option -fid     {}

    onconfigure -storage {d} {
	set options(-storage) $d
	if {$options(-fid) != {}} {$self InitTagging}
	return
    }
    onconfigure -fid {d} {
	set options(-fid) $d
	if {$options(-storage) != {}} {$self InitTagging}
	return
    }
    option -pop {}

    delegate method * to hull
    delegate option * to hull

    set w_command	"#893793"; # purple
    set w_comment	"#A03030"; # maroon
    set w_syntax	"#1F2FAA"; # dark blue
    set w_var		"#507850"; # dark green

    typevariable yellow lightyellow

    # class type pattern color
    typevariable hl_classes [list \
	    [list comment ClassForRegexp         {\#\[^\n\]*} $w_comment] \
	    [list var     ClassWithOnlyCharStart "\$"         $w_var] \
	    [list syntax  ClassForSpecialChars   "\[\]{}\""   $w_syntax] \
	    [list command Class               [info commands] $w_command] \
	    ]


    variable text
    variable filename

    constructor {fname args} {
	set filename $fname

	installhull [ScrolledWindow $win]
	$self configurelist $args

	set text [ctext $win.t -bg white]
	$win setwidget $text

	ctext::clearHighlightClasses $text
	foreach class $hl_classes {
	    foreach {cname ctype cptn ccol} $class break
	    ctext::addHighlight$ctype $text $cname $ccol $cptn
	}
	$text tag configure highlight -background lightgreen ;#lightyellow

	set f [open $fname r]
	$text delete 1.0 end
	$text insert 1.0 [read $f]
	close $f

	# Binding for popup menu ...
	bind $text.t <ButtonRelease-3> [mymethod ContextMenu %X %Y]
	return
    }

    destructor {}

    # ### ######### ###########################
    # ftext NEW api's

    method filename {} {return $filename}

    method showlocation {begin end} {
	# Highlight the location between character offsets 'begin'
	# and 'end'

	$self highlight "1.0 + $begin chars" "1.0 + $end chars"
	return
    }

    variable hilitbegin {}
    variable hilitend {}

    method highlight {begin end} {
	if {$hilitbegin != {}} {
	    $text tag remove highlight $hilitbegin $hilitend
	}
	$text tag add    highlight $begin $end
	$text see "$begin - 1 line"

	# Remember location.
	set hilitbegin $begin
	set hilitend   $end
	return
    }

    # ### ######### ###########################

    method ContextMenu {rootx rooty} {
	#puts CTX/menu

	set tags   [$text tag names current]
	set ranges [$self Ranges $tags]

	#puts TAG/$tags
	#puts RAN/$ranges

	# Use information about the locations to construct a menu ...

	set menu [$self MakeMenu $ranges]

	if {$menu == {}} {return}
	incr rooty 20 ; # CHANGE use bbox data to place exactly below the chosen line.
	tk_popup $menu $rootx $rooty 0
	return
    }

    method Ranges {taglist} {
	set res {}
	foreach tag $taglist {
	    if {![string match loc_* $tag]} {continue}
	    # Ignore all tags not used for location data
	    lappend res [string range $tag 4 end]
	}
	return $res
    }

    method MakeMenu {ranges} {
	catch {destroy $text.context}
	set m [menu $text.context -tearoff 0]

	# The ranges for any location are nested and
	# connected via their parent references. Use
	# this to (a) find the closest range, and (b)
	# then work our way outward.

	[$options(-storage) view location] as loc
	$loc cursor l
	set r [$self Closest l $ranges]

	#puts CLOSE/$r

	# And now we are going upward, and whenever we detect
	# defined objects we add them to the menu.

	set items 0
	set sep 0
	while {$r != -1} {
	    set l(#) $r

	    [[$view storage] listview location/obj l] as objs
	    if {$objs != {}} {
		if {$sep} {$m add separator}
		$objs loop o {
		    #parray o
		    $m add command -label "D: $o(name)" \
			    -command [mymethod PopDo \
			    $o(id) $o(type)]
		    incr items
		}
		set sep 1
		unset objs
	    }
	    set r $l(parent)
	}

	if {$items == 0} {
	    destroy $m
	    return {}
	}
	return $m
    }

    method Closest {lvar ranges} {
	upvar $lvar l
	# We use down to create an inverted parent/child reference.
	# I.e. from parent to child.
	array set down {}
	foreach r $ranges {
	    set l(#) $r
	    set down($l(parent)) $r
	    #puts ____________________
	    #parray l

	}

	#puts ____________________
	#parray down
	#puts ____________________

	set closest -1
	while {[info exists down($closest)]} {
	    	set closest $down($closest)
	}
	return $closest
    }


    method PopDo {id otype} {
	$options(-pop) AnyDetail $otype $id
	return
    }

    variable isdone 0
    method InitTagging {} {
	if {$isdone} return
	#puts InitTagging

	if {![$type Map $filename map]} {
	    #puts \tNoMap
	    # No map, create map, if possible.
	    if {![$self ComputeMap map]} {
		#puts \tNoComputingOfMap
		return
	    }
	    $type AddMap $filename $map
	}

	#puts \tApply
	# Apply the map  ...

	foreach {start until tag} $map {
	    #puts Apply\t\t$start/$until/$tag

	    $text tag add $tag $start "$until + 1 char"
	    if 0 {
		# DEBUG
		$text tag bind $tag <Enter> "\
			$text tag configure $tag -background green ;\
			puts \{ENTER $tag\}
		"
		$text tag bind $tag <Leave> "\
			$text tag configure $tag -background [$text cget -bg] ;\
			puts \{LEAVE $tag\}
		"
	    }

	    ## Need reverse order for good priority ! low to high
	    ## $text tag bind $tag <ButtonRelease-3> [mymethod ContextMenu %X %Y $tag]
	}
	return
    }

    method ComputeMap {mapvar} {
	#parray options

	if {$options(-storage) == {}} {return 0}
	upvar $mapvar map
	set map {}

	# Access database for map. The order is important, as
	# later tags are nsted in former, and have higher
	# priority. - Future use to get the closest tag immediately.

	[$options(-storage) view location] as loc
	[$loc select -sort file -sort begin -sort end] as locsort

	#puts loop/loc

	$locsort loop c {
	    if {$c(file) != $options(-fid)} {continue}
	    set tag   loc_$c(rowid) ; # Tag encodes location id !!
	    set start [$text index "1.0 + $c(begin) chars"]
	    set until [$text index "1.0 + $c(end)   chars"]

	    #puts -------------------------------
	    #puts \t$c(begin)--$start/-/$c(end)--$until/-/$tag
	    #puts --------[array get c]

	    lappend map $start $until $tag
	}
	return 1
    }


    # ### ######### ###########################
    # Type information ... Cache of line/offset mapping for a file.
    #                      Used to efficiently map between text
    #                      line.char indices and the character
    #                      offsets used by procheck/xref to describe
    #                      locations.

    typevariable tagcache
    typemethod Map {fname mapvar} {
	if {![info exists tagcache($fname)]} {return 0}
	upvar $mapvar map
	set           map $tagcache($fname)
	return 1
    }
    typemethod AddMap {fname map} {
	set tagcache($fname) $map
	return
    }


}

# ### ######### ###########################
# Ready to go

package provide ftext 0.1
