# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xdpkg - "toplevel" /snit::widgetadaptor
#
#	Main window, detail data for a 'package'

package require xmainframe
package require snit
package require mklabel
package require xllocfl

snit::widgetadaptor xdpkg {

    typemethod key {view row} {
	$view cursor c ; set c(#) $row
	return $c(name)
    }

    # ### ######### ###########################

    delegate method * to hull
    delegate option * to hull

    variable status {}
    variable text

    variable frame
    variable view
    variable cursor
    #variable dcursor
    variable mainwin
    component nb

    constructor {view_ row main args} {
	# Initialize data to show.
	[$view_ readonly] as view
	$view cursor cursor ; set cursor(#) $row

        set mainwin $main

	installhull [xmainframe $win]
	wm withdraw $win
	$self title [$self Title]
	$self configurelist $args

	set frame [$win getframe]

	# Show details of the package ...
	if 0 {
	    foreach {l p label} {
		name  name  Name:
	    } {
		ttk::label   $frame.l$l -text $label -anchor w
		mklabel $frame.d$l -anchor w -cursor [varname cursor] -property $p
	    }
	}

	install nb using ttk::notebook $frame.nb \
	    -width 500 -height 300 -padding 8
	foreach {page label creator} {
	    use Uses        CreateUsePage
	    def Definitions CreateDefPage
	} {
	    set nbf [ttk::frame $nb.$page -padding 8]
	    $nb add $nbf -text $label
	    # XXX Should defer this creation to first view
	    $self $creator
	}

	#########################################################
	# Generate layout for the widgets.

	#    lname  0 0 1 1 w	dname  0 1 1 1 we
	xmainframe::gridSet $frame {
	    nb     1 0 1 2 swen
	}
	xmainframe::gridColResize $frame 1
	xmainframe::gridRowResize $frame 2

	$nb select $nb.def

	update idle
	wm deiconify $win
	return
    }


    # ### ######### ###########################
    # xdpkg - NEW API

    # Package data available to us ...
    #
    # BASIC ______________________________________________
    # name   - name of package
    # def/SV - loc'ations where the package is defined/provided.
    # use/SV - loc'ations where the package is used/required.
    #
    # COMPUTED ___________________________________________
    # defn     - #of definitions
    # usen     - #of uses

    method Title {} {
	# Use selected cursor data for the title
	return "Package: $cursor(name)"
    }

    method CreateDefPage {} {
	# -----------------------------------------------------
	# List of locations provide'ing the package ...

	set defs   [[$view storage] listview package/def cursor]
	set def    $nb.def
	set list   [xllocfl $def.list $defs]
	set open   [$list add open/def open Open]

	$list configure \
		-filtertitle "[$self Title] Definitions" \
		-onaction  [mymethod GoAction] \
		-browsecmd [mymethod SetChoice $list $open] \
		-basetype L \
		-childdef [xrefchilddef ${selfns}::def [$view storage]]

	$list itemconfigure $open \
		-command [mymethod GoChoice $open]

	xmainframe::gridSet       $def {list 1 0 1 1 swen}
	xmainframe::gridColResize $def 0
	xmainframe::gridRowResize $def 1
	return
    }

    method CreateUsePage {} {
	# -----------------------------------------------------
	# List of locations require'ing the package ...

	set uses   [[$view storage] listview package/use cursor]
	set use    $nb.use
	set list   [xllocfl $use.list $uses]
	set button [$list add open/use open Open]

	$list configure \
		-filtertitle "[$self Title] Uses" \
		-onaction  [mymethod GoAction] \
		-browsecmd [mymethod SetChoice $list $button] \
		-basetype L \
		-childdef [xrefchilddef ${selfns}::use [$view storage]]

	$list itemconfigure $button \
		-command [mymethod GoChoice $button]

	xmainframe::gridSet       $use {list 1 0 1 1 swen}
	xmainframe::gridColResize $use 0
	xmainframe::gridRowResize $use 1
	return
    }

    variable selid
    variable seltp

    method SetChoice {list button sortedview rtype row} {
	::log::log debug "$win SetChoice $list $button $sortedview $rtype $row"

	#$sortedview cursor c ; set c(#) $row
	#$sortedview dump
	#puts "($property) ($list) ($button) ($sortedview) ($row)"
	#parray c

	# Using a static dcursor is bad !! Resorting in sublist causes
	# it to be out of sync with actual view. Therefore gen a
	# cursor whenever it is required.

	# row = key 'rowid'. It is not the # ... The select is not
	# required. We take the value of column 'loc', which is the
	# same column we select on. I.e. the selected value is equal
	# to the contents of argument 'row'.

	#[$sortedview select loc $row] as v
	#$v cursor dcursor
	#set dcursor(#) 0
	#::log::logarray debug dcursor

	set selid($button) $row

	# Debug
	#[[[$sortedview storage] view location] select rowid $row] as vx ; $vx dump

	if {$row < 0} {
	    $list itemconfigure $button -state disable
	} else {
	    $list itemconfigure $button -state normal
	}
	return
    }

    method GoChoice {button} {
	$mainwin AnyDetail location $selid($button)
	return
    }

    method GoAction {sortedview rtype row} {
	# The main window knows how to open a detail
	# window for any type of object.

	$mainwin AnyDetail $rtype $row
	return
    }

    # ### ######### ###########################
}

package provide xdpkg 0.1
