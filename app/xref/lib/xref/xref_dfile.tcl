# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xdfile - xmainframe /snit::widgetadaptor
#
#	Display files, highlight location.

package require xmainframe
package require snit
package require ftext

snit::widgetadaptor xdfile {

    typemethod open {parentwin file main} {
	# TODO Logic to go for Komodo, or other editor ...
	# NOTE: When talking to Komodo we will have to return
	#       an object which allows 'showlocation' and similar
	#       operations ...

	# Defer to existing window if possible.
	if {[set w [xmainframe lookup $file]] != {}} {return $w}

	log::log debug "$type open: $parentwin [list $file] $main"

	if {![file exists $file]} {
	    tk_messageBox \
		-title Error \
		-parent $parentwin -type ok -icon error \
		-message "We were unable to find the file \"$file\"\
                          and therefore cannot show it. Our apologies."
	    return {}
	}

	xmainframe add $file [set w [$type create $parentwin.%AUTO% $file $main]]
	return $w
    }

    typemethod openAt {parentwin file begin end} {
	set w [$type open $parentwin $file]
	if {$w != {}} {
	    $w showlocation $begin $end
	}
	return $w
    }

    # ### ######### ###########################

    delegate method filename     to text
    delegate method showlocation to text

    ### BUG ? ### The delegation goes to hull ?!?!
    ##
    #delegate option storage to text
    #delegate option fid     to text
    ##
    # But this direct delegation works correct

    option -fid {}
    onconfigure -fid {value} {$text configure -fid $value}
    option -storage {}
    onconfigure -storage {value} {$text configure -storage $value}

    delegate method * to hull
    delegate option * to hull

    variable text
    variable mainwin {}

    constructor {fname main args} {
	set mainwin $main
	installhull [xmainframe $win]
	wm withdraw $win

	$self title "File: $fname"

	$win showstatusbar status
	set   text [ftext [$win getframe].text $fname -pop $main]
	pack $text -side top -expand 1 -fill both

	$self configurelist $args

	update idle
	wm deiconify $win
	return
    }

    # ### ######### ###########################
}

package provide xdfile 0.1
