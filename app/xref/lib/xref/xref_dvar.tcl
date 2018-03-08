# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xdvar - "toplevel" /snit::widgetadaptor
#
#	Main window, detail data for a 'variable'

package require xmainframe
package require snit
package require ftext
package require mklabel
package require xllocfl
package require xllocvardef
package require xlcall
package require xrefchilddef
package require tooltip
package require image  ; image::file::here

snit::widgetadaptor xdvar {

    typemethod key {view row} {
	$view cursor c ; set c(\#) $row
	return $c(fullname)
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

	# Show details of the variable ...
	foreach {l p label} {
	    scope scope Scope:
	    name  name  Name
	} {
	    ttk::label $frame.l$l -text $label -anchor w
	    mklabel $frame.d$l -anchor w -cursor [varname cursor] -property $p
	}

	# Buttons: Show Parent

	ttk::button $frame.gop -image [image::get originl] \
	    -text "Show defining scope" \
	    -command [mymethod GoDefiningScope]
	tooltip::tooltip $frame.gop "Show defining scope"

	if {$cursor(sid) < 0} {
	    $frame.gop configure -state disabled
	}

	# -----------------------------------------------------

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

	xmainframe::gridSet $frame {
	    gop    0 0 1 1 w
	    dname  0 1 1 1 we
	    nb     1 0 1 3 swen
	}
	#    lname  0 1 1 1 w
	xmainframe::gridColResize $frame 2
	xmainframe::gridRowResize $frame 1

	$nb select $nb.def

	update idle
	wm deiconify $win
	return
    }


    # ### ######### ###########################
    # xdvar - NEW API

    # Variable data available to us ...
    #
    # BASIC ______________________________________________
    # name   - name of variable
    # type   -\ type of defining scope
    # sid    -| scope id
    # sloc   -/ location of scope
    # def/SV -/ loc'ations where the variable is defined.
    #        -| type  - type of the definition
    #        -| otype - type of origin scope \ if any
    #        -| oid   - id of origin scope   /
    #        -\ call/SV -/ type \ caller scopes, if any
    #                   -\ id   /
    # use/SV - loc'ations where the variable is used.
    #
    # COMPUTED ___________________________________________
    # scope    - Name of defining scope (sid/sloc)
    # fullname - Full name of var, including scope.
    # defn     - #of definitions
    # usen     - #of uses

    method Title {} {
	# Use selected cursor data for the title
	return "Variable: $cursor(fullname)"
    }

    method CreateDefPage {} {
	# -----------------------------------------------------
	# List of locations defining the variable ...

	set defs   [[$view storage] listview variable/def cursor]
	set def    $nb.def
	set list   [xllocvardef $def.list $defs]
	set open   [$list add open/def open Open]
	set goo    [$list add showorig origin "Show origin"]

	$list configure \
		-filtertitle "[$self Title] Definitions" \
		-onaction  [mymethod GoAction] \
		-browsecmd [mymethod SetSel $list $goo $open] \
		-basetype L \
		-childdef [xrefchilddef ${selfns}::def [$view storage]]

	$list itemconfigure $open \
		-command [mymethod GoChoice $open]

	$list itemconfigure $goo \
		-command [mymethod GoOrigin]

	xmainframe::gridSet       $def {list 1 0 1 1 swen}
	xmainframe::gridColResize $def 0
	xmainframe::gridRowResize $def 1
	return
    }

    method CreateUsePage {} {
	# -----------------------------------------------------
	# List of locations using the variable ...

	set uses   [[$view storage] listview variable/use cursor]
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
    variable oid
    variable otype

    method SetSel {list goo open sortedview rtype row} {
	#$sortedview dump
	#puts "($sortedview) ($row)"

	# Using a static dcursor is bad !! Resorting in sublist causes
	# it to be out of sync with actual view. Therefore gen a
	# cursor whenever it is required.

	# row = key ... not # ... Select ...

	[$sortedview select loc $row] as v
	$v cursor dcursor
	set dcursor(#) 0

	#parray dcursor

	set oid   $dcursor(oid)
	set otype $dcursor(otype)
	if {($oid < 0) || ($otype eq "R")} {
	    $list itemconfigure $goo -state disable
	} else {
	    $list itemconfigure $goo -state normal
	}

	set def $nb.def
	if {$dcursor(otype) eq "R"} {
	    # Add caller list

	    set caller [[$view storage] listview variable/def/caller dcursor]
	    xlcall $def.callers $caller \
		    -onaction [mymethod GoCaller]

	    grid $def.callers -row 1 -column 1 \
		    -columnspan 1 -sticky swen

	    xmainframe::gridColResize $def {0 1}
	} else {
	    destroy $def.callers
	    xmainframe::gridColResize $def 0
	}

	set selid($open) $dcursor(loc)
	if {$dcursor(loc) < 0} {
	    $list itemconfigure $open -state disable
	} else {
	    $list itemconfigure $open -state normal
	}
	return
    }

    method SetChoice {list button sortedview rtype row} {
	#$sortedview cursor c ; set c(#) $row
	#$sortedview dump
	#puts "($property) ($list) ($button) ($sortedview) ($row)"
	#parray c

	[$sortedview select loc $row] as v
	$v cursor dcursor
	set dcursor(#) 0

	set selid($button) $dcursor(loc)

	#puts $id

	if {$dcursor(loc) < 0} {
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

    method GoDefiningScope {} {
	if {$cursor(sid) < 0} {return}

	# We have to translate the 'P'rocedure type
	# to 'C'ommand. For AnyDetail 'P' is 'package'.

	set type $cursor(type)
	if {$type eq "P"} {set type command}

	$mainwin AnyDetail $type $cursor(sid)
	return
    }

    method GoOrigin {} {
	#if {![info exists dcursor(#)]} {return}	
	if {$oid < 0} {return}
	$mainwin AnyDetail $otype $oid
	return
    }

    method GoCaller {sortedview row} {
	$sortedview cursor c ; set c(#) $row

	# The main window knows how to open a detail
	# window for any type of object.

	$mainwin AnyDetail $c(type) $c(id)
	return
    }

    # ### ######### ###########################
}

package provide xdvar 0.1
