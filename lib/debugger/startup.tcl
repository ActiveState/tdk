# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# startup.tcl --
#
#	This file is the primary entry point for the 
#       TclPro Debugger.
#
# Copyright (c) 1999 by Scriptics Corporation.

# 
# RCS: @(#) $Id: startup.tcl,v 1.13 2001/01/24 19:41:24 welch Exp $

# Initialize the debugger library

package require projectInfo

# Specify the additional debugger parameters.

set parameters [list \
	aboutCmd {::TclProAboutBox images/about.gif} \
	aboutCopyright "$::projectInfo::copyright\nVersion $::projectInfo::patchLevel" \
	appType local \
	]

if {$::tcl_platform(platform) == "windows"} {
    catch {
	package require Winico
	lappend parameters iconImage [winico load dbg scicons.dll]
    }
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

proc ::TclProAboutBox {aboutImage splash} {
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

    # Compute various metrics
    set aboutWidth [image width about]
    set screenWidth [winfo screenwidth .]
    set screenHeight [winfo screenheight .]

    label $f1.about -bd 0 -bg white -padx 0 -pady 0 -highlightthickness 0 \
	    -image about
    pack $f1.about -side top -anchor nw

    if {!$splash} {
	package require help
	set url http://www.activestate.com/tcl

	label $f1.url -bd 1 -bg white -padx 10 -pady 0 -highlightthickness 0 \
		-text "$url" -fg blue -cursor hand2 -relief raised
	##pack $f1.url -side top -anchor nw

	place $f1.url -x 180 -y 220
	bind  $f1.url <ButtonRelease-1> [list help::openUrl $url]
    }


    # Establish dialog bindings

    bind .about <ButtonRelease-1> {
	destroy .about
    }
    bind .about <Return> {destroy .about}

    # Add the Windows-only console hack

    if {$::tcl_platform(platform) == "windows"} {
	bind .about <F12> {
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
    raise .about

    catch {
	focus .about
	grab -global .about
    }

    # Return the about window so we can destroy it from external bindings
    # if necessary.
    return .about
}

if {[catch {

    # This package require loads the debugger and system modules
    package require debugger

    # Set TclPro license hook
#	package require licenseWin
#	licenseWin::verifyLicense
#	set ::projectInfo::licenseReleaseProc lclient::release

    debugger::init $argv $parameters
} err]} {
    set f [toplevel .init_error]
    set l [label $f.label -text "Startup Error"]
    set t [text $f.text -width 50 -height 30]
    $t insert end $errorInfo
    pack $f.text

    catch {console show}
}

# Add the TclPro debugger extensions

#Source xmlview.tcl

# Enter the event loop.
