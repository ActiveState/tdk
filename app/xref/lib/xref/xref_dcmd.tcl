# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xdcmd - xmainframe /snit::widgetadaptor
#
#	Main window, detail data for a 'namespace'

package require snit
package require xmainframe
package require ftext
package require mklabel
package require xlloccmddef
package require xllocfl
package require xlvarcmd
package require image  ; image::file::here
package require xrefchilddef
package require tooltip

snit::widgetadaptor xdcmd {

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
    variable mainwin
    #variable dcursor
    variable cmdvar
    component nb

    constructor {view_ row main args} {
	# Initialize data to show.

	[$view_ readonly] as view ; # Take ownership of our own copy ...
	$view cursor cursor ; set cursor(#) $row

        set mainwin $main

	installhull [xmainframe $win]
	wm withdraw $win
	$self title [$self Title]
	$self configurelist $args

	set frame [$win getframe]

	# Show details of the namespace ...
	foreach {l p label} {
	    name name Name
	} {
	    ttk::label $frame.l$l -text $label -anchor w
	    mklabel $frame.d$l -anchor w -cursor [varname cursor] -property $p
	}

	# Buttons: Show execution scope ...

	ttk::button $frame.gop -image [image::get originl] \
	    -text "Show execution namespace" \
	    -command [mymethod GoScope]
	tooltip::tooltip $frame.gop "Show execution namespace"

	[[$view storage] listview cmd/def cursor] as defs
	set escope -1
	$defs loop c {
	    if {$c(escope) >= 0} {set escope $c(escope)}
	}
	if {$escope < 0} {
	    $frame.gop configure -state disabled
	} else {
	    $frame.gop configure -state normal
	}
	unset c

	# -----------------------------------------------------
	install nb using ttk::notebook $frame.nb \
	    -width 500 -height 300 -padding 8
	foreach {page label creator} {
	    use Uses        CreateUsePage
	    def Definitions CreateDefPage
	    var Variables   CreateVarPage
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
    # xdcmd - NEW API

    # Namespace data available to us ...
    #
    # BASIC ______________________________________________
    # name   - name of command
    # dev/SV - loc
    #          type
    #          prot
    #          escope
    #          origin
    # use/SV - loc
    #
    # COMPUTED ___________________________________________
    # defn   - #of definitions
    # usen   - #of uses
    # def/SV -/ file_str   - file of location
    #        -| line       - line in file
    #        -\ origin_str - name for origin

    method Title {} {
	# Use selected cursor data for the title
	return "Command: $cursor(name)"
    }

    # ### ######### ###########################

    method CreateVarPage {} {
	# -----------------------------------------------------
	# List of variables in the scope of the command ...

	[[$view storage] listview cmd/var cursor] as cmdvar

	set var    $nb.var
	set list   [xlvarcmd $var.list $cmdvar]
	set button [$list add open/var open Open]

	$list configure \
		-filtertitle "[$self Title] Variables" \
		-onaction  [mymethod GoAction] \
		-browsecmd [mymethod SetChoice $list $button] \
		-basetype V \
		-childdef [xrefchilddef ${selfns}::var [$view storage]]

	$list itemconfigure $button \
		-command [mymethod GoChoice $button]

	xmainframe::gridSet       $var {list 0 0 1 1 swen}
	xmainframe::gridColResize $var 0
	xmainframe::gridRowResize $var 0
	return
    }

    method CreateUsePage {} {
	# -----------------------------------------------------
	# List of locations using the command ...

	set uses   [[$view storage] listview cmd/use cursor]
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

	xmainframe::gridSet       $use {list 0 0 1 1 swen}
	xmainframe::gridColResize $use 0
	xmainframe::gridRowResize $use 0
	return
    }

    method CreateDefPage {} {
	# -----------------------------------------------------
	# List of locations defining the command ...

	set defs [[$view storage] listview cmd/def cursor]
	set def  $nb.def
	set list [xlloccmddef $def.list $defs]
	set open [$list add open/def open Open]
	set goo  [$list add showorig origin "Show origin"]

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

	xmainframe::gridSet       $def {list 0 0 1 1 swen}
	xmainframe::gridColResize $def 0
	xmainframe::gridRowResize $def 0
	return
    }

    # ### ######### ###########################

    variable selid
    variable seltp
    variable escope
    variable origin

    method SetSel {list goo open sortedview rtype row} {
	# Using a static dcursor is bad !! Resorting in sublist causes
	# it to be out of sync with actual view. Therefore gen a
	# cursor whenever it is required.

	# row = key ... not # ... Select ...

	[$sortedview select loc $row] as v
	$v cursor dcursor
	set dcursor(#) 0

	set origin $dcursor(origin)

	if {$origin < 0} {
	    $list itemconfigure $goo -state disable
	} else {
	    $list itemconfigure $goo -state normal
	}

	set selid($open) $dcursor(loc)
	set seltp($open) $rtype

	if {$dcursor(loc) < 0} {
	    $list itemconfigure $open -state disable
	} else {
	    $list itemconfigure $open -state normal
	}
	return
    }

    method SetChoice {list button sortedview rtype row} {
	#$sortedview cursor c ; set c(#) $row

	set selid($button) $row
	set seltp($button) $rtype

	if {$row < 0} {
	    $list itemconfigure $button -state disable
	} else {
	    $list itemconfigure $button -state normal
	}
	return
    }
    method GoChoice {button} {
	$mainwin AnyDetail $seltp($button) $selid($button)
	return
    }

    method GoAction {sortedview rtype row} {
	#$sortedview cursor c ; set c(#) $row

	# The main window knows how to open a detail
	# window for any type of object.

	$mainwin AnyDetail $rtype $row
	return
    }

    method GoScope {} {
	if {$escope < 0} {return}
	$mainwin AnyDetail namespace $escope
	return
    }

    method GoOrigin {} {
	#if {![info exists dcursor(#)]} {return}	
	if {$origin < 0} {return}
	$mainwin AnyDetail command $dcursor(origin)
	return
    }

    # ### ######### ###########################
}

package provide xdcmd 0.1
