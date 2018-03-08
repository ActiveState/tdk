# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xdloc - "toplevel" /snit::widgetadaptor
#
#	Main window, detail data for a 'location'

package require xmainframe
package require snit
package require ftext
package require mklabel
package require xldefined
package require xrefchilddef
package require tooltip
package require image  ; image::file::here

snit::widgetadaptor xdloc {

    typemethod key {view row} {
	$view cursor c ; set c(#) $row
	return $c(file),$c(begin)
    }

    # ===================================================

    delegate method * to hull
    delegate option * to hull

    #delegate option storage to text
    #delegate option fid     to text

    option -fid {}
    onconfigure -fid {value} {$text configure -fid $value}
    #option -storage {}
    #onconfigure -storage {value} {$text configure -storage $value}


    variable text
    variable view
    variable cursor
    variable mainwin
    variable frame

    constructor {view_ row main args} {
	# Initialize data to show.

	[$view_ readonly] as view
	$view cursor cursor ; set cursor(#) $row
        set mainwin $main

	log::log      debug "Location: ${win} ($view_ $row $main $args)="
	log::logarray debug cursor

	installhull [xmainframe $win]
	wm withdraw $win
	$self title [$self Title]

	set frame [$win getframe]
	$self MakeUI

	$self configurelist $args

	update idle
	wm deiconify $win
	return
    }


    # ### ######### ###########################
    # xdloc - NEW API

    # Location data available to us ...
    #
    # BASIC ______________________________________________
    # file   - id of file containing the location
    # line   - line in file on which the location begins.
    # begin  - offset to begin of location, in characters
    # size   - length of the location, in characters.
    # end    - offset to first character after location, in characters
    # parent - id of a containing location, if any.
    # obj/SV - / id   id of object defined by location \
    #          \ type type of object                   /
    #
    # COMPUTED ___________________________________________
    # hasobj   - yes/no, where yes <=> (#obj > 0)
    # file_str - name of file refered to by 'file' (s.a.)
    # obj/SV   - name  name of referenced object.

    method Title {} {
	# Use selected cursor data for the title

	if {$cursor(file) < 0} {
	    return " Location: Undefined / Unknown"
	} else {
	    return " Location: $cursor(line)@$cursor(file_str) ($cursor(begin))"
	}
    }

    method MakeUI {} {
	# Show details of the location ...

	if {$cursor(file) >= 0} {
	    # Create detail data iff the location is not
	    # the 'undefined' location.

	    foreach {l p label} {
		file file_str {File}
		line line     {Starting @ Line}
		beg  begin    {Starting @ Char}
		size size     {Length}
		end  end      {End @ Char}
	    } {
		ttk::label $frame.l$l -text "${label}:" -anchor w
		mklabel $frame.d$l -anchor w -cursor [varname cursor] -property $p
	    }

	    # Buttons: Source, Show Parent

	    # The 'file_str' can actually be a pseudo-list of paths,
	    # using newline as separator, one path per line. We show
	    # the first existing file. We know one exists, otherwise
	    # we would not reach this lcoation.

	    foreach p [split $cursor(file_str) \n] {
		if {[file exists $p]} break
	    }

	    set text [ftext $frame.text $p]
	    $text configure \
		    -fid $cursor(file) -pop $mainwin \
		    -storage [$view storage]
	    $text showlocation $cursor(begin) $cursor(end)

	    if {$cursor(parent) >= 0} {
		ttk::button $frame.gop -image [image::get originl] \
		    -style Toolbutton \
		    -text "Show containing location" \
		    -command [mymethod GoParent]
		tooltip::tooltip $frame.gop "Show containing location"
	    }
	}

	# Defined objects can be present even for the undefined
	# location.

	ttk::label $frame.lobj -text Objects

	set objs [[$view storage] listview location/obj cursor]
	if {$objs != {}} {
	    # List of typed objects ...

	    # 'objs' is a view, and it exists only as long as the
	    # cursor. Create an independent view the list can own

	    set list   [xldefined $frame.dobj $objs]
	    set button [$list add open open Open]

	    $list configure \
		    -onaction  [mymethod GoDefinedObject] \
		    -browsecmd [mymethod SetChoice $list $button] \
		    -basetype  L \
		    -childdef  [xrefchilddef ${selfns}::obj [$view storage]]

	    $list itemconfigure $button \
		    -command [mymethod GoChoice $button]

	} else {
	    set list [ttk::label $frame.dobj -text {No objects defined} -anchor w]
	}

	#########################################################
	# Generate layout for the widgets.

	xmainframe::gridSet $frame {
	    gop    0 0 1 2 w
	    lfile  1 0 1 1 w	    dfile  1 1 1 1 we
	    lline  2 0 1 1 w	    dline  2 1 1 1 we
	    lbeg   3 0 1 1 w	    dbeg   3 1 1 1 we
	    lend   4 0 1 1 w	    dend   4 1 1 1 we
	    lsize  5 0 1 1 w	    dsize  5 1 1 1 we
	    lobj   6 0 1 1 nw	    dobj   6 1 1 1 we
	    text   7 0 1 2 swen
	}
	xmainframe::gridColResize $frame 1
	xmainframe::gridRowResize $frame 7
	return
    }

    variable selid {}
    variable seltp {}

    method GoChoice {button} {
	$mainwin AnyDetail $seltp $selid
	return
    }
    method SetChoice {list button sortedview rtype row} {
	[$sortedview select id $row] as v
	$v cursor c ; set c(#) 0

	set selid $c(id)
	set seltp $c(type)

	if {$row < 0} {
	    $list itemconfigure $button -state disable
	} else {
	    $list itemconfigure $button -state normal
	}
	return
    }

    method GoDefinedObject {sortedview rtype row} {
	#$sortedview cursor c ; set c(#) $row

	[$sortedview select id $row] as v
	$v cursor c ; set c(#) 0

	# The main window knows how to open a detail
	# window for any type of object.

	$mainwin AnyDetail $c(type) $c(id)
	return
    }

    method GoParent {} {
	if {$cursor(parent) < 0} {return}
	$mainwin AnyDetail location $cursor(parent)
	return
    }

    # ### ######### ###########################
}

package provide xdloc 0.1
