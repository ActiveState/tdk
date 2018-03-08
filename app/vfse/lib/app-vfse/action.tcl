# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# Implementation of the menu and toolbar operations ...

# ### ######### ###########################

package require help
help::appname TclVFSE
help::page    TclVFSE
help::activetcl vfse

package require struct::list    ; # Tcllib, list ops
package require struct::stack   ; # Tcllib, stack objects.
package require fileutil        ; # Tcllib, file types
package require vfs

package require snit
package require tdom
package require fileutil

# ### ######### ###########################

namespace eval action {}

# ### ######### ###########################

proc action::chgStyle {style} {
    global menu
    .fsb configure -style $style
    if {$style ne "details"} {
	# Deactivate sorting (Arrange).
	$menu(view) entryconfigure "Arrange Icons" -state disabled
    } else {
	$menu(view) entryconfigure "Arrange Icons" -state normal
    }
}

# ### ######### ###########################

proc action::gotoSetup {} {
    global menu
    # Initial setup of menu and toolbar for forw/back/up

    # up   - disabled.
    # forw - disabled.
    # back - disabled.

    .tbar.back configure -state disabled
    $menu(view,goto) entryconfigure "Back" -state disabled

    .tbar.fore configure -state disabled
    $menu(view,goto) entryconfigure "Forward" -state disabled

    .tbar.up configure -state disabled
    $menu(view,goto) entryconfigure "Up One Level" -state disabled

    SelectionToState
    return
}

# ### ######### ###########################

proc action::setViewPane {{what {}}} {
    global W
    if {[llength [info level 0]] == 2} {
	set W(disp) $what
    }
    # We only support folders view for now
    if {$W(disp) eq "folders"} {
	.fsb folderUnhide
    } else {
	.fsb folderHide
    }
}

# ### ######### ###########################

# ### ######### ###########################

if 0 {
    proc action::delete {} {}
    proc action::rename {} {}
}

proc action::refresh {} {
    .fsb refresh
    return
}


package require fproperty

proc action::showproperties {} {
    variable selection

    foreach {path chosen} $selection break
    set path [eval [linsert $path 0 file join]]

    # make sure that we have a valid base path
    if {![file exists $path]} { return }

    if {[llength $chosen]} {
	foreach c $chosen {
	    [fproperty .fp%AUTO% -path [file join $path $c]] display
	}
    } else {
	[fproperty .fp%AUTO% -path $path] display
    }
    return
}

# ### ######### ###########################

namespace eval action {
    variable lastmountdir [pwd]
    variable  mounts    ; # Keep track of mountpoints
    array set mounts {} ; # for the menu.
}

proc action::mountarchive {} {
    variable lastmountdir

    set arfile [tk_getOpenFile \
	    -parent . \
	    -title {Mount archive file} \
	    -initialdir $lastmountdir \
	    ]

    if {$arfile == {}} return

    # We remember the directory the file came from for the next
    # selection.

    set lastmountdir [file dirname $arfile]

    if {[file isdirectory $arfile]} {
	# On OSX a .app bundle is a directory to us, but the file
	# selection dialog treats it as a file. If we get something
	# like this back we try to locate an executable in the bundle,
	# and see if we can mount that as our archive.

	# Relevant paths and information:
	# Contents/Info.plist CFBundleExecutable
	# Contents/MacOS/<CFBundleExecutable>

	# FUTURE: Put snit type 'action::infop' into separate package,
	# maybe extend to general parsing of info.plist files.

	set info $arfile/Contents/Info.plist
	if {[fileutil::test $info efr]} {
	    # ok, have an osx info block
	    set i [::action::infop %AUTO%]
	    set exe [$i scan $info]
	    $i destroy
	    if {$exe ne ""} {
		# info does name the executable
		set exe $arfile/Contents/MacOS/$exe
		if {[fileutil::test $exe efr]} {
		    # executable file exists, this now our archive to mount
		    set arfile $exe
		}
	    }
	}
    }

    if {[catch {
	action::mountarchiveasroot $arfile
    } msg]} {
	tk_messageBox -parent . -title "Mount error" \
		-message "The archive file \"$arfile\" could\
		not be mounted. We were given the message:\n\t$msg" \
		-icon error -type ok
	return
    }
    .fsb refresh
    return
}

proc action::mountvol {} {
    global menu
    initialize-volumes
    $menu(tools) entryconfigure 0 -state disabled
    return
}

proc action::mountarchiveasroot {arfile} {
    variable mounts

    # Mount a file. Metakit, or Zip.
    # By mounting the file over itself we transform it into a
    # directory. This directory becomes an additional root in the
    # explorer UI.

    # Error here are catched and handled by the caller.
    # action::mountarchive only so far.

    set type [fileutil::fileType $arfile]

    if {[lsearch -exact $type metakit] >= 0} {
	package require vfs::mk4

	vfs::mk4::Mount $arfile $arfile -readonly
	set tree [[.fsb cget -data] tree]
	$tree add $arfile

	set mounts($arfile) .
	SelectionToState
	return
    }

    # Not metakit, try as zip file instead.

    if {[lsearch -exact $type zip] >= 0} {
	package require vfs::zip
	vfs::zip::Mount $arfile $arfile

	set tree [[.fsb cget -data] tree]
	$tree add $arfile

	set mounts($arfile) .
	SelectionToState
	return
    }

    return -code error \
	"$arfile is neither zip- nor metakit archive, but a $type"
}

proc action::mountkitfileinplace {kitfile} {
    # Mount a file, assuming that it contains a metakit filesystem. By
    # mounting the file over itself we transform it into a
    # directory. This directory becomes an additional root in the
    # explorer UI.

    variable mounts
    package require vfs::mk4

    set type [fileutil::fileType $kitfile]
    if {[lsearch -exact $type metakit] < 0} {
	return -code error "No metakit filesystem present"
    }
    vfs::mk4::Mount   $kitfile $kitfile -readonly

    .fsb refresh
    .fsb show [file split $kitfile]

    set mounts($kitfile) .
    SelectionToState
    return
}

proc action::mountzipfileinplace {zipfile} {
    # Mount a file, assuming that it contains a zip filesystem. By
    # mounting the file over itself we transform it into a
    # directory. This directory becomes an additional root in the
    # explorer UI.

    variable mounts
    package require vfs::zip
    vfs::zip::Mount   $zipfile $zipfile

    .fsb refresh
    .fsb show [file split $zipfile]

    set mounts($zipfile) .
    SelectionToState
    return
}


proc action::unmount {} {
    variable selection
    variable mounts

    foreach {path chosen} $selection break
    set path [eval [linsert $path 0 file join]]

    set tree [[.fsb cget -data] tree]

    if {[llength $chosen]} {
	foreach c $chosen {
	    set p [file join $path $c]
	    vfs::unmount $p
	    unset mounts($p)
	    if {[$tree has $p]} {
		$tree remove $p
	    }
	}
    } else {
	# The left-side path itself is the mountpoint.

	vfs::unmount $path
	unset mounts($path)
	if {[$tree has $path]} {
	    $tree remove $path
	}
    }

    .fsb refresh ; # Convert all the unmounted directories back into files.
    SelectionToState
    return
}

# ### ######### ###########################

proc action::help  {} {help::open}
proc action::about {} {splash::showAbout 0}

# ### ######### ###########################

namespace eval action {
    variable history     [struct::stack h]
    variable selection   {}
    variable future      [struct::stack f]
    variable historylock 0

    # selection = list (pathid, list (id))
    # i.e.      = tuple of chosen path as path id
    #             (list of ids in tree) and list of
    #             chosen id's in the detail pane
}

proc action::SetSelection {{expand 0}} {
    variable selection

    foreach {path chosen} $selection break

    .fsb show $path
    if {$chosen != {}} {
	.fsb showdetail $chosen
    } else {
	.fsb showdetail {}
    }
    return
}

proc action::back {} {
    enter
    # Go back in the history ...
    variable history
    variable historylock 1
    variable future
    variable selection
    global menu

    $future push $selection
    NewSelection [$history pop]

    if {[$history size] == 0} {
	.tbar.back configure -state disabled
	$menu(view,goto) entryconfigure "Back" -state disabled
    } else {
	.tbar.back configure -state normal
	$menu(view,goto) entryconfigure "Back" -state normal
    }
    .tbar.fore configure -state normal
    $menu(view,goto) entryconfigure "Forward" -state normal

    action::SetSelection
    set historylock 0

    hDump back/complete
    return
}

proc action::forward {} {
    enter
    variable history
    variable historylock 1
    variable future
    variable selection
    global menu

    $history push $selection
    NewSelection  [$future pop]

    if {[$future size] == 0} {
	.tbar.fore configure -state disabled
	$menu(view,goto) entryconfigure "Forward" -state disabled
    } else {
	.tbar.fore configure -state normal
	$menu(view,goto) entryconfigure "Forward" -state normal
    }
    .tbar.back configure -state normal
    $menu(view,goto) entryconfigure "Back" -state normal

    action::SetSelection
    set historylock 0

    hDump forward/complete
    return
}

proc action::AddStep {path} {
    enter
    variable history
    variable future
    variable selection
    global menu

    if {$selection != {}} {
	$history push $selection
	.tbar.back configure -state normal
	$menu(view,goto) entryconfigure "Back" -state normal
    }

    NewSelection $path

    $future clear
    .tbar.fore configure -state disabled
    $menu(view,goto) entryconfigure "Forward" -state disabled

    hDump AddStep
    return
}

proc action::upward {} {
    enter
    variable selection
    variable historylock 1

    foreach {path chosen} $selection break
    set path [lrange $path 0 end-1]

    # can't go higher than the root
    if {![llength $path]} { return }

    action::AddStep [list $path {}]
    action::SetSelection
    set historylock 0

    hDump up/complete
    return
}

# ### ######### ###########################
## Open a file ...

package require file::open

proc action::openfile {path} {
    # All relevant smarts is in the 'file::open' package.

    file::open $path
    return
}

# ### ######### ###########################
## Selection changed, compute states based on it.

proc action::NewSelection {s} {
    enter
    variable selection $s
    SelectionToState
    return
}


proc action::SelectionToState {} {
    variable selection
    variable mounts
    global menu

    set p {}
    if {[llength $selection]} {
	foreach {path chosen} $selection break
	if {[llength $path]} {
	    set p [eval [linsert $path 0 file join]]
	}
    } else {
	set path   {}
	set chosen {}
    }

    if {[llength $path] > 1} {
	if {[[[.fsb cget -data] tree] has $p]} {
	    .tbar.up configure -state disabled
	    $menu(view,goto) entryconfigure "Up One Level" -state disabled
	} else {
	    .tbar.up configure -state normal
	    $menu(view,goto) entryconfigure "Up One Level" -state normal
	}
    } else {
	.tbar.up configure -state disabled
	$menu(view,goto) entryconfigure "Up One Level" -state disabled
    }

    if {[llength $selection] && [file exists $p]} {
	.tbar.type configure -state normal
	$menu(file)  entryconfigure 0 -state normal

	$menu(edit) entryconfigure 0 -state normal
	$menu(edit) entryconfigure 3 -state normal

	# Multi-selection => No mount requests possible.
	if {[llength $chosen] > 1} {
	    $menu(tools) entryconfigure 1 -state disabled ; # Mount selection
	    $menu(tools) entryconfigure "Unmount Selection" -state disabled ; # Unmount selection
	} else {
	    # Length of chosen is 1, or 0 !
	    # Depending on the type of the chosen path we can either
	    # try to mount or umount.

	    if {[llength $chosen]} {
		set p [file join $p [lindex $chosen 0]]
	    }

	    #puts stderr ([file isdirectory $p])\t$p

	    if {[file isdirectory $p]} {
		$menu(tools) entryconfigure 1 -state disabled ; # Mount selection
		if {[info exists mounts($p)]} {
		    $menu(tools) entryconfigure "Unmount Selection" -state normal
		} else {
		    $menu(tools) entryconfigure "Unmount Selection" -state disabled
		}
	    } else {
		$menu(tools) entryconfigure 1 -state normal
		$menu(tools) entryconfigure "Unmount Selection" -state disabled
	    }
	}
    } else {
	$menu(tools) entryconfigure 1 -state disabled ; # Mount selection
	$menu(tools) entryconfigure "Unmount Selection" -state disabled ; # Unmount selection

	.tbar.type configure -state disabled
	$menu(file)  entryconfigure 0 -state disabled

	$menu(edit) entryconfigure 0 -state disabled ;# Copy
	$menu(edit) entryconfigure 3 -state disabled ;# Copy to folder
    }
    return
}

# ### ######### ###########################
## Mounting of the selected archive file in place.

proc action::mountsel {} {
    variable selection

    foreach {path chosen} $selection break
    set path [eval [linsert $path 0 file join]]

    if {[llength $chosen]} {
	foreach c $chosen {
	    set p     [file join $path $c]
	    set types [fileutil::fileType $p]

	    if {[lsearch -exact $types metakit] >= 0} {
		if {![catch {action::mountkitfileinplace $p} msg]} {
		    refresh
		    continue
		}

		tk_messageBox -parent . -title "Mount error" \
			-message "The metakit file \"$p\" could \
			not be mounted. We were given the \
			message:\n\n$msg" \
			-icon error -type ok
		continue
	    }
	    # Not a metakit file, try as zip file.

	    if {![catch {action::mountzipfileinplace $p} msg]} {
		refresh
		continue
	    }

	    tk_messageBox -parent . -title "Mount error" \
		    -message "The file \"$p\" could not be \
		    mounted. We were given the message:\n\n$msg" \
		    -icon error -type ok
	    # continue
	}
    } else {
	tk_messageBox -parent . -title "Mount error" \
		-message "A directory (\"$path\") can not be \
		mounted." \
		-icon error -type ok
    }
    return
}

# ### ######### ###########################

namespace eval action {
    variable copylist {}
}

proc action::copysel {} {
    variable selection
    variable copylist
    global menu

    set copylist [cvtSelToList $selection]

    $menu(edit) entryconfigure 1 -state normal
    return
}

proc action::pastesel {} {
    variable copylist
    variable selection

    foreach {path chosen} $selection break
    set dir [eval [linsert $path 0 file join]]

    # Check that we do not try to copy a directory into itself. Abort
    # with an error message if that is so.

    foreach item $copylist {
	if {
	    ([file dirname $item] eq $dir) ||
	    $item eq $dir
	} {
	    # Target directory is parent directory of the item to copy => Item will be copied into itself
	    # Item is equal to target directory => Again copying over/into itself.

	    tk_messageBox -parent . -title "Copy error" \
		    -message "Unable to copy [file tail $item] over itself." \
		    -icon error -type ok
	    return
	}
    }

    # Check that we do not try to copy into a mounted file (read-only).

    if {[lindex [file system $dir] 0] ne "native"} {
	tk_messageBox -parent . -title "Copy error" \
		-message "Unable to copy [file tail $item] into a mounted directory." \
		-icon error -type ok
	return
    }

    action::CopyFiles $copylist $dir
    return
}

namespace eval action {
    variable lastcopydir [pwd]
}

proc action::copytofolder {} {
    variable lastcopydir
    variable selection

    set dest [tk_chooseDirectory \
	    -parent . \
	    -title "Browse For Folder to copy to" \
	    -mustexist 1 \
	    -initialdir $lastcopydir \
	    ]

    # Canceled, do nothing.
    if {$dest == {}} return
    set lastcopydir $dest

    action::CopyFiles [cvtSelToList $selection] $dest
    return
}


namespace eval action {
    variable  copyid 0
    variable  cnt
    array set cnt {}
}

proc action::CopyFiles {listoffiles destination} {
    enter
    variable copyid
    variable cnt

    incr copyid
    set ::action::cnt($copyid) 0

    set          top [toplevel .copy$copyid]
    frame       $top.inner -width 200 -height 100
    label       $top.current -anchor w -height 2
    ProgressBar $top.p -relief sunken \
	    -type normal \
	    -maximum [llength $listoffiles] \
	    -variable ::action::cnt($copyid) \
	    -height 20

    #    -width 50 -height 10 \#

    pack         $top.inner   -side top -expand 1 -fill both -in $top
    pack         $top.current -side top -expand 1 -fill both -in $top.inner
    pack         $top.p       -side top -expand 1 -fill both -in $top.inner
    wm title     $top "Copying Files ..."
    wm transient $top .
    wm resizable $top 0 0
    update ; # Show and place ...

    #set width  [winfo reqwidth  $top]
    #set height [winfo reqheight $top]
    #set x [expr {([winfo screenwidth  .]/2) - ($width/2)}]
    #set y [expr {([winfo screenheight .]/2) - ($height/2)}]
    #wm geom $top ${width}x${height}+${x}+${y}

    # Force the window to the top.

    if {$::tcl_platform(platform) eq "windows"} {
	wm attributes $top -topmost 1
    }

    wm deiconify $top
    raise        $top
    focus        $top
    update

    after 10 [list action::CopyFilesAction $top $copyid $listoffiles $destination 0]
    return
}

proc action::CopyFilesAction {top id listoffiles destination overwrite_all} {
    enter
    variable cnt

    # Completion handling.

    if {[llength $listoffiles] == 0} {
	destroy $top
	unset cnt($id)
	.fsb refresh ; # And refresh the display ...
	return
    }

    # Copy a single file, then reschedule yourself ...

    set f           [lindex $listoffiles 0]
    set listoffiles [lrange $listoffiles 1 end]

    $top.current configure -text $f
    update

    # ### ######### ###########################
    ## Handling of errors and other exceptional situations.

    set tail [file tail $f]
    set dst  [file join $destination $tail]
    set copy 1

    if {[file exists $dst]} {

	if {$overwrite_all == 0} {
	    # Let user choose to copy or not.
	    #
	    # We always use the '::tk::MessageBox' here, because this is
	    # the custom one supporting the type
	    # 'yesyesallnonoallcancel'. The native one doesn't.

	    set res [::tk::MessageBox -parent $top -title "Confirm File Replace" \
		    -message "This folder already contains a file named \"$tail\".\n\n\
		    Would you like to replace the existing file\n\n\
		    \t${tail}: [file size $dst] bytes, last modified on [clock format [file mtime $dst]]\n\n\
		    with this one ?\n\n\
		    \t${tail}: [file size $f] bytes, last modified on [clock format [file mtime $f]]" \
		    -icon info -type yesyesallnonoallcancel \
		    ]
	    switch -exact -- $res {
		yes    {set copy 1}
		yesall {set copy 1 ; set overwrite_all 1}
		no     {set copy 0}
		noall  {set copy 0 ; set overwrite_all -1}
		cancel {set copy 0 ; set listoffiles {}}
	    }

	} elseif {$overwrite_all < 0} {
	    # Never overwrite anymore.
	    set copy 0
	} ; # > 0 => Always overwrite (copy already 1)
    }

    if {$copy} {
	set  fail [catch {file copy -force $f $destination} msg]
	if {$fail} {
	    # Report error. Allow for abort on next cycle.

	    set res [tk_messageBox -parent $top -title "Copy Error" \
		    -message "The copying of file \"$tail\" to \
		    folder \"$destination\" encountered \
		    an error. The message is:\n\n$msg" \
		    -icon error -type okcancel \
		    ]
	    if {$res eq "cancel"} {
		set listoffiles {}
	    }
	}
    }

    # ### ######### ###########################
    incr cnt($id)

    after 10 [list action::CopyFilesAction $top $id $listoffiles $destination $overwrite_all]
    return
}

# ### ######### ###########################
# ### ######### ###########################
## Helpers ...

proc globdir {path} {
    ## return [glob -nocomplain -dir $path -types d *]
    ## glob does not return mounted files as directories!

    set r [list]
    foreach f [glob -nocomplain -dir $path *] {
	if {[file isfile $f]} continue
	lappend r $f
    }
    return $r
}
proc globfiles {path} {
    ## return [glob -nocomplain -dir $path -types f *]
    ## glob does not return mounted files as directories!

    set r [list]
    foreach f [glob -nocomplain -dir $path *] {
	if {[file isdirectory $f]} continue
	lappend r $f
    }
    return $r
}

proc action::initialize-volumes {} {
    ### HERE is the code generating the initial population of the tree

    set dostat [expr {$::tcl_platform(platform) ne "windows"}]

    set tree [[.fsb cget -data] tree]
    set vols [file volumes]
    set home [file normalize ~]
    # add user's home dir if it isn't a listed volume already
    if {[lsearch -exact $vols $home] < 0} {
	$tree add $home $dostat
    }
    foreach dir $vols {
	$tree add $dir $dostat
    }
    return
}

proc action::showactive {active} {
    variable historylock
    if {$historylock} return
    enter

    foreach {tree details} $active break

    wm title $::W(root) "[eval [linsert $tree 0 file join]] - VFS Explorer"

    # Active/Selected element(s) in the browser.
    # tree    = pathid in tree panel
    # details = list of ids in detail panel
    #
    # This drives the history and other stuff.

    action::AddStep $active
    return
}

proc action::cvtSelToList {selectiondata} {

    foreach {dir files} $selectiondata break
    set dir [eval [linsert $dir 0 file join]]

    #puts %%-$dir
    #puts %%-$files

    set res {}
    if {[llength $files] > 0} {
	foreach f $files {
	    lappend res [file join $dir $f]
	}
    } else {
	lappend res $dir
    }
    return $res
}


##################
## DEBUG Helpers ##
####################

proc action::enter {} {
    puts [info level -1]\t%%%%%%%%%%%%%%%%%%%%%%%
}
proc action::hDump {{text {}}} {
    variable history
    variable selection
    variable future
    if {$text != {}} {
	puts \t@========================
	puts "\t| $text"
    }
    puts \t@----------------------------
    catch {puts \t*\t[join [struct::list reverse [sGet $history]] \n\t*\t]}
    puts \t@----------------------------
    puts \t>\t$selection
    puts \t@----------------------------
    catch {puts \t*\t[join [sGet $future] \n\t*\t]}
    puts \t@----------------------------
    return
}
proc action::sGet {s} {
    set sz [$s size]
    if {$sz == 0} {return {}}
    if {$sz == 1} {return [list [$s peek]]}
    return [$s peek $sz]
}


proc action::hDump {args} {}
proc action::enter {args} {}

# ### ### ### ######### ######### #########
##
# FUTURE: Put snit type 'action::infop' into separate package, maybe
# extend it to general parsing of info.plist files, i.e. conversion of
# info.plist into tcl dictionary structure.

snit::type action::infop {

    constructor {} {
	set parser [xml::parser ${selfns}::P -final 1 \
		-elementstartcommand  [mymethod ESC] \
		-elementendcommand    [mymethod EEC] \
		-characterdatacommand [mymethod CDC]]
    }
    destructor {
	$parser free
    }

    variable parser
    variable usebuf 0
    variable buf ""
    variable exenext 0
    variable exe ""

    method scan {f} {
	set usebuf 0
	set buf ""
	set exenext 0
	set exe ""
	$parser parse [fileutil::cat $f]
	return $exe
    }

    method ESC {tag args} {
	# collect info only for key, string tags, ignore remainder.
	set usebuf [expr {($tag eq "key") || ($tag eq "string")}]
	set buf ""
	return
    }

    method CDC {data} {
	# ignore if not collecting information
	if {!$usebuf} return
	append buf $data
	return
    }

    method EEC {tag args} {
	# ignore if not collecting information
	if {!$usebuf} return
	set buf [string trim $buf]
	if {$tag eq "key"} {
	    # /key - bundle special, triggers that next string is the
	    # value sought.

	    if {$buf eq "CFBundleExecutable"} {
		set exenext 1
	    }
	} else {
	    # /string - ignore until special key seen
	    if {$exenext} {
		set exe $buf
		# abort parsing, no need to look further.
		return -code break
	    }
	}
	return
    }
}
