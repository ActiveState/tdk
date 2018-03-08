# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xdns - "toplevel" /snit::widgetadaptor
#
#	Main window, detail data for a 'namespace'

package require xmainframe
package require snit
package require ftext
package require mklabel
package require xldefined
package require xlvarcmd
package require xlcmd
package require BWidget
package require image  ; image::file::here
package require xrefchilddef
package require tooltip

snit::widgetadaptor xdns {

    typemethod key {view row} {
	$view cursor c ; set c(#) $row
	return $c(name)
    }

    # ===================================================

    delegate method * to hull
    delegate option * to hull

    variable status {}
    variable text

    variable view
    variable cursor
    variable mainwin
    variable frame
    variable nsvar ; # Variables in the namespace
    variable nscmd ; # Commands in the namespace.
    variable subns ; # Sub-namespaces.
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

	# Show details of the namespace ...
	foreach {l p label} {
	    name name Name
	} {
	    ttk::label $frame.l$l -text $label -anchor w
	    mklabel $frame.d$l -anchor w -cursor [varname cursor] -property $p
	}

	# -----------------------------------------------------
	# Buttons: Show Parent

	if {$cursor(parent) >= 0} {
	    ttk::button $frame.gop -image [image::get originl] \
		-text "Show parent namespace" \
		-command [mymethod GoParent]
	    tooltip::tooltip $frame.gop "Show parent namespace"
	    #$frame.gop configure -state disabled
	}

	# -----------------------------------------------------

	install nb using ttk::notebook $frame.nb \
	    -width 500 -height 300 -padding 8
	foreach {page label creator} {
	    use Uses        CreateUsePage
	    def Definitions CreateDefPage
	    ns  Namespaces  CreateNspPage
	    cmd Commands    CreateCmdPage
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
    # xdns - NEW API

    # Namespace data available to us ...
    #
    # BASIC ______________________________________________
    # name   - name of namespace
    # parent - parent namespace, if any.
    # def/SV - loc'ations where the namespace is defined.
    # use/SV - loc'ations where the namespace is used.
    #
    # COMPUTED ___________________________________________
    # defn   - #of definitions
    # usen   - #of uses

    method Title {} {
	# Use selected cursor data for the title
	return "Namespace: $cursor(name)"
    }

    method CreateNspPage {} {
	# -----------------------------------------------------
	# List of sub-namespaces in the scope of the namespace ...
	# Select the namespace via their ns-prefix in the 'name'

	[[$view storage] listview namespace/subns cursor] as subns

	set ns     $nb.ns
	set list   [xlcmd $ns.list $subns]
	set button [$list add open/ns open Open]

	$list configure \
		-filtertitle "[$self Title] Namespaces" \
		-onaction  [mymethod GoAction] \
		-browsecmd [mymethod SetChoice $list $button] \
		-basetype N \
		-childdef [xrefchilddef ${selfns}::ns [$view storage]]

	$list itemconfigure $button \
		-command [mymethod GoChoice $button]

	xmainframe::gridSet       $ns {list 0 0 1 1 swen}
	xmainframe::gridColResize $ns 0
	xmainframe::gridRowResize $ns 0
	return
    }

    method CreateCmdPage {} {
	# -----------------------------------------------------
	# List of commands in the scope of the namespace ...
	# Select the command via their ns-prefix in the 'name'
	# Note: The pattern has to exclude commands in sub-namespaces.

	[[$view storage] listview namespace/cmd cursor] as nscmd
	#$nscmd dump
	#puts /$pattern

	set cmd    $nb.cmd
	set list   [xlcmd $nb.cmd.list $nscmd]
	set button [$list add open/cmd open Open]

	$list configure \
		-filtertitle "[$self Title] Commands" \
		-onaction  [mymethod GoAction] \
		-browsecmd [mymethod SetChoice $list $button] \
		-basetype C \
		-childdef [xrefchilddef ${selfns}::cmd [$view storage]]

	$list itemconfigure $button \
		-command [mymethod GoChoice $button]

	xmainframe::gridSet       $cmd {list 0 0 1 1 swen}
	xmainframe::gridColResize $cmd 0
	xmainframe::gridRowResize $cmd 0
	return
    }

    method CreateVarPage {} {
	# -----------------------------------------------------
	# List of variables in the scope of the namespace ...

	[[$view storage] listview namespace/var cursor] as nsvar

	set var    $nb.var
	set list   [xlvarcmd $var.list $nsvar]
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
	# List of locations using the namespace ...

	set uses   [[$view storage] listview namespace/use cursor]
	set use    $nb.use
	set list   [xlloc $use.list $uses]
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
	# List of locations defining the namespace ...

	set defs   [[$view storage] listview namespace/def cursor]
	#parray cursor
	#puts $defs
	#$defs dump

	set def    $nb.def
	set list   [xlloc $def.list $defs]
	set button [$list add open/def open Open]

	$list configure \
		-filtertitle "[$self Title] Definitions" \
		-onaction  [mymethod GoAction] \
		-browsecmd [mymethod SetChoice $list $button] \
		-basetype L \
		-childdef [xrefchilddef ${selfns}::def [$view storage]]

	$list itemconfigure $button \
		-command [mymethod GoChoice $button]

	xmainframe::gridSet       $def {list 0 0 1 1 swen}
	xmainframe::gridColResize $def 0
	xmainframe::gridRowResize $def 0
	return
    }

    variable selid
    variable seltp

    method SetChoice {list button sortedview rtype row} {
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
	# The main window knows how to open a detail
	# window for any type of object.

	$mainwin AnyDetail $rtype $row
	return
    }

    method GoParent {} {
	if {$cursor(parent) < 0} {return}
	$mainwin AnyDetail namespace $cursor(parent)
	return
    }

    # ### ######### ###########################
}

package provide xdns 0.1
