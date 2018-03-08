# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# startup.tcl --
#
#	This file is the primary entry point for the 
#       TclPro Debugger.
#
# Copyright (c) 1999-2000 by Ajuba Solutions.

# 
# RCS: @(#) $Id: startup.tcl,v 1.3 2000/10/31 23:31:03 welch Exp $

# Initialize the debugger library

package require projectInfo

# Specify the additional debugger parameters.

set parameters [list \
	aboutCmd {::TclProAboutBox images/about.gif images/logo.gif} \
	aboutCopyright "$::projectInfo::copyright\nVersion $::projectInfo::patchLevel" \
	appType remote \
	]

if {$::tcl_platform(platform) == "windows"} {
    package require Winico
    lappend parameters iconImage [winico load dbg scicons.dll]
} else {
    lappend parameters iconImage images/debugUnixIcon.gif
}

# ::TclProAboutBox --
#
#	This procedure displays the TclPro about box or
#	splash screen.
#
# Arguments:
#	image		The main image to display in the about box.
#
# Results:
#	None.

proc ::TclProAboutBox {aboutImage logoImage} {
    catch {destroy .about}

    # Create an undecorated toplevel with a raised bevel
    set top [toplevel .about -bd 4 -relief raised]
    wm overrideredirect .about 1

    # This is a hack to get around a Tk bug.  Once Tk is fixed, we can
    # let the geometry computations happen off-screen
    wm geom .about 1x1
#    wm withdraw .about

    # Create a container frame so we can set the background without
    # affecting the color of the outermost bevel.
    set f1 [frame .about.f -bg white]
    pack $f1 -fill both

    # Create the images
    
    image create photo about -file $aboutImage
    image create photo logo -file $logoImage

    # Compute various metrics
    set logoWidth [image width logo]
    set aboutWidth [image width about]
    set screenWidth [winfo screenwidth .]
    set screenHeight [winfo screenheight .]

    label $f1.about -bd 0 -bg white -padx 0 -pady 0 -highlightthickness 0 \
	    -image about
    pack $f1.about -side top -anchor nw

    set f2 [frame $f1.f2 -bg white -bd 0]
    pack $f2 -padx 6 -pady 6 -side bottom -fill both -expand 1

    label $f2.logo -bd 0 -bg white -padx 0 -pady 0 -highlightthickness 0 \
	    -image logo
    pack $f2.logo -side left -anchor nw -padx 0 -pady 0

    set okBut [button $f2.ok -text "OK" -width 6 -default active \
	    -command {destroy .about}]
    pack $okBut -side right -anchor se -padx 0 -pady 0

    label $f2.version -bd 0 -bg white -padx 10 -pady 0 -highlightthickness 0 \
	    -text $::debugger::parameters(aboutCopyright) -justify left
    pack $f2.version -side top -anchor nw

    label $f2.url -bd 0 -bg white -padx 10 -pady 0 -highlightthickness 0 \
	    -text "http://www.scriptics.com" -fg blue \
	    -cursor hand2
    pack $f2.url -side top -anchor nw

    # Establish dialog bindings

    bind .about <1> {
	raise .about
    }
    bind $f2.url <ButtonRelease-1> {
	destroy .about
	system::openURL http://www.scriptics.com
    }
    bind .about <Return> "$okBut invoke"

    # Add the Windows-only console hack

    if {$::tcl_platform(platform) == "windows"} {
	bind $okBut <F12> {
	    console show
	    destroy .about; break
	}
    }

    # Place the window in the center of the screen
    update
    set width [winfo reqwidth .about]
    set height [winfo reqheight .about]
    set x [expr {([winfo screenwidth .]/2) - ($width/2)}]
    set y [expr {([winfo screenheight .]/2) - ($height/2)}]
    wm deiconify .about
    wm geom .about ${width}x${height}+${x}+${y}

    catch {
	focus -force $okBut
	grab -global .about
    }

    # Return the about window so we can destroy it from external bindings
    # if necessary.
    return .about
}


package require debugger
debugger::init $argv $parameters

# Add the TclPro debugger extensions

#Source xmlview.tcl

# Enter the event loop.
