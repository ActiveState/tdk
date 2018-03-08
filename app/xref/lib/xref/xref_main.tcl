# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xmain - xmainframe /snit::widgetadaptor
#
#	Main window to a xref database.

package require BWidget
package require snit
package require tap_gather
package require kpj_gather
package require tclapp_gather
package require teapot_gather

package require xmainframe

package require xlfile
package require xlloc
package require xlns
package require xlvar
package require xlcmd
package require xlpkg

package require xdfile
package require xdloc
package require xdns
package require xdcmd
package require xdvar
package require xdpkg

package require xrefchilddef
package require xrefchilddeffile
package require xrefdb

package require fileutil
package require selfile
package require as::tdk::komodo

snit::widgetadaptor xmain {

    delegate method * to hull
    delegate option * to hull

    component nb

    # tk_getOpenFile management (remember last dir)
    variable opkom ; # komodo     .kpj
    variable optpj ; # tdk tclapp .tpj
    variable optap ; # tdk tclpe  .tap
    variable optxr ; # tdk xref   .txr
    variable oppot ; # teapot     teapot.txt

    variable koedit {}

    constructor {args} {
	if 0 {
	    {command {&Select list}                               {scan-select}
	    {Scan files selected by the user}                     {} -command {%SELF% Scan select}}
	}
	# NOTE: %SELF% is substituted by the xmainframe, and refers to its window.
	#       The commands invoked by the menu for %SELF% are
	#       methods of xmainframe.

	installhull [xmainframe $win -menu {
	    &File {} fmenu 0 {
		{command {&Open database}               {open}     {Load database into this window} {} -command {%SELF% Open 0}}
		{command {Open database in &new window} {open/new} {Load database into new window}  {} -command {%SELF% Open 1}}
		separator
		{command {&Save database}               {save}     {Save database} {} -command {%SELF% Save}}
		separator
		{
		    cascad {&Scan files for database} {} scan 0 {
			{command {&Komodo project}                            {scan-komodo}
			{Scan files in Komodo project}                        {} -command {%SELF% Scan komodo}}
			{command {Tcl Dev Kit TclApp/Prowrap &project}        {scan-tdk-tpj}
			{Scan files in Tcl Dev Kit TclApp or Wrapper project} {} -command {%SELF% Scan tpj}}
			{command {Tcl Dev Kit P&ackage Definition}            {scan-tdk-tap}
			{Scan files in Tcl Dev Kit Package Definition}        {} -command {%SELF% Scan tap}}
			{command {TEAPOT meta data}                           {scan-teapot}
			{Scan files in TEAPOT Meta Data}                      {} -command {%SELF% Scan teapot}}
		    }
		}
	    }
	}] ; # {}

	set opkom [selfile ${selfns}::opkom \
		-title     "Load Komodo Project File" \
		-parent    $win \
		-initialdir {} \
		-filetypes $komExt \
		]
	set optpj [selfile ${selfns}::optpj \
		-title     "Load Tcl Dev Kit Project File" \
		-parent    $win \
		-initialdir {} \
		-filetypes $tpjExt \
		]
	set optap [selfile ${selfns}::optap \
		-title     "Load Tcl Dev Kit Package Definition" \
		-parent    $win \
		-initialdir [file join [file dirname [info library]] tap] \
		-filetypes $tapExt \
		]
	set optxr [selfile ${selfns}::optxr \
		-title     "Load cross-reference database" \
		-parent    $win \
		-initialdir [file dirname [info library]] \
		-filetypes $projExt \
		]
	set oppot [selfile ${selfns}::oppot \
		-title     "Load TEAPOT meta data" \
		-parent    $win \
		-initialdir [file dirname [info library]] \
		-filetypes $potExt \
		]

	$self configurelist $args
	wm withdraw $win
	$win title "<no database loaded>"

	$win showstatusbar status
	$win status {}
	$win lockScan
	$win unlockScan
	$win lockSave

	install nb using ttk::notebook [$win getframe].n \
	    -width 500 -height 300 -padding 8
	pack $nb -side top -expand 1 -fill both
	$self InitializeNoteBook

	update idle
	wm deiconify $win

	$type Add $win ; # Remember this toplevel ...

	# TODO FUTURE = Plugin system to allow different editors.

	set koedit [as::tdk::komodo ${selfns}::koedit]
	return
    }

    destructor {
	$type Remove $win
	# Remove internal components
	$opkom destroy
	$optpj destroy
	$optap destroy
	$optxr destroy
	$oppot destroy

	if {$gather != {}} {
	    rename $gather {}
	}
	return
    }

    # ### ######### ###########################
    # xmain - NEW API

    variable db {}
    method db: {dbfile} {
	######################
	# Kill all toplevel children (= detail windows) spawned from
	# this main window. After the database has changed their data
	# references (db indices) are outdated. They may be out of
	# bounds, or refer to something completely different.

	foreach c [winfo children $win] {
	    if {[winfo class $c] eq "Toplevel"} {destroy $c}
	}

	######################

	$win showstatusbar progression
	$win status "Loading $dbfile"

	# Kill previous database now.
	if {$db != {}} {rename $db {}}
	set db [xrefdb ${selfns}::db $dbfile -mainframe $win]

	$win showstatusbar status
	$win status {}

	$self UpdateNoteBook
	$self title [$db filename]
	$self unlockSave
	return
    }

    # ### ########## ##############################
    # Internal

    variable open

    # No main list of locations in UI. Too big.
    #    locations  Locations  xlloc  location  LocationDetail

    method InitializeNoteBook {} {
	foreach {page label class viewname handler basetype cdef} {
	    files      Files      xlfile file      FileDetail      F xrefchilddeffile
	    packages   Packages   xlpkg  package   PkgDetail       P xrefchilddef
	    namespaces Namespaces xlns   nsroot    NamespaceDetail N xrefchilddef
	    commands   Commands   xlcmd  command   CmdDetail       C xrefchilddef
	    variables  Variables  xlvar  variable  VarDetail       V xrefchilddef
	} {
	    set frame [ttk::frame $nb.$page -padding 8]
	    $nb add $frame -text $label
	    # XXX Should defer this creation to first view
	    # XXX We should consider a status message "Loading ..."
	    $self CreateNoteBookPage $page $label \
		$class $viewname $handler $basetype $cdef
	}

	$nb select $nb.files
	return
    }

    method CreateNoteBookPage {
	page label class viewname handler basetype cdef
    } {
	set p $nb.$page

	if {$db == {}} {
	    set v {}
	} else {
	    set v [$db view $viewname]
	}

	set list   [$class create $p.list $v]
	set button [$list add open/$page open Open]

	set cd [$cdef ${selfns}::$page $db]

	$list configure \
		-filtertitle $label \
		-onaction    [mymethod AnyDetailAction] \
		-browsecmd   [mymethod SetChoice $list $button] \
		-basetype    $basetype \
		-childdef    $cd

	$list itemconfigure $button \
		-command [mymethod GoChoice $button]

	pack $list -side top -expand 1 -fill both
	return
    }

    method UpdateNoteBook {} {
	# Kill previous content (including the childdef objects)
	foreach tab [$nb tabs] {
	    if {[winfo exists $tab.list]} {
		set cd [$tab.list cget -childdef]
		$cd destroy
	    }
	    destroy $tab
	}
	$self InitializeNoteBook
	return
    }

    # ### ########## ##############################
    # Menu operations ...

    variable projExt {{TXR {.txr}} {All {*}}}
    variable tapExt  {{TAP {.tap}} {All {*}}}
    variable tpjExt  {{TPJ {.tpj}} {All {*}}}
    variable komExt  {{KPF {.kpf}} {All {*}}}
    variable potExt  {{TEA {.txt}} {All {*}}}

    method Open {newwindow} {
	set infile [$optxr choose]
	if {$infile == {}} {return}

	# Check that the file is a proper database.
	# Check that database is txr db ...

	set t [fileutil::fileType $infile]
	if {![string match *metakit* $t]} {
	    $self BasicFmtError "The file \"$infile\" does not contain a TDK Xref database"
	    return
	} else {
	    if {[xrefdb version $infile] < 0} {
		$self BasicFmtError "The file \"$infile\" does not contain a TDK Xref database"
		return
	    }
	}

	$self Load $infile $newwindow
	return
    }

    method Save {} {
	if {$db == {}} {return}

	set dbfile [$db filename]
	set outfile [tk_getSaveFile \
		-title     "Save Xref database" \
		-parent    . \
		-initialfile [file tail    $dbfile] \
		-initialdir  [file dirname $dbfile] \
		-filetypes $projExt
	]
	if {$outfile == {}} return

	# Append default extension if not provided by the dialog.
	if {[file extension $outfile] == {}} {
	    append outfile .txr
	}

	if {$outfile eq $dbfile} return

	#  Check permissions first.

	if {[file exists $outfile]} {
	    if {![file writable $outfile]} {
		tk_messageBox -icon error \
		    -parent . -type ok \
		-title "Save Tcl Dev Kit Xref Error" \
		-message "Unable to save to the chosen file. \
                          It exists and is not writable. "
		return
	    }
	} else {
	    if {[catch {
		set ch [open $outfile w]
	    } msg]} {
		tk_messageBox -icon error -title {Tcl Dev Kit Save Error} \
		    -type ok -message "Could not create \"$outfile\"."
		return
	    }
	    # Can be created. Restore non-existence for actual save op.
	    close $ch
	    file delete -force $outfile
	}

	# Perform the save (copy current db file to new/chosen location).

	file copy -force $dbfile $outfile
	$db filename: $outfile
	$self title [$db filename]
	return
    }

    method Load {dbfile newwindow} {
	if {$newwindow} {
	    set w [xmain .%AUTO%]
	    after 1000 [list $w   db: $dbfile]
	} else {
	    after 1000 [list $win db: $dbfile]
	}
	return
    }

    variable gather {} ; # Reference to the object running the
    #                  ; # process of gathering xref data.

    method Scan {scantype} {
	# Deactivate scan menu during operation, only one scan
	# may run ... This is be handled across all main windows!

	$type LockScan

	switch -exact -- $scantype {
	    komodo {$self ScanKomodo}
	    tpj    {$self ScanTpj}
	    tap    {$self ScanTap}
	    teapot {$self ScanTeapot}
	    select {
		# Not Implemented
		$self ScanSelect
	    }
	    default {
		tk_messageBox -icon error \
			-title "Internal error" \
			-type ok -message "Internal error,\
			illegal scan type \"$scantype\""
		$type UnlockScan
	    }
	}
	return
    }

    method ScanKomodo {} {
	set infile [$opkom choose]
	if {$infile == {}} {$type UnlockScan ; return}

	$self scanKomodo: $infile
	return
    }

    method scanKomodo: {infile} {
	$type LockScan
	## Decode contents of a Komodo project file.
	## Then scan the found files ...
	## The constructor auto-launches the bg process

	$self showstatusbar progression
	$self status "Scanning $infile"
	$self pinfinite 100
	set gather [kpj_gather tg $infile \
		-command [mymethod ScanComplete $infile] \
		-onerror [mymethod FmtError] \
		-ping [mymethod Progress]]
	return
    }

    method ScanTpj {} {
	set infile [$optpj choose]
	if {$infile == {}} {$type UnlockScan ; return}

	$self scanTpj: $infile
	return
    }

    method scanTpj: {infile} {
	$type LockScan
	## Decode contents of TDK project file.
	## Acceptable: TclApp 
	## Then scan the found files ...
	## The constructor auto-launches the bg process

	$self showstatusbar progression
	$self status "Scanning $infile"
	$self pinfinite 100
	set gather [tclapp_gather tg $infile \
		-command [mymethod ScanComplete $infile] \
		-onerror [mymethod FmtError] \
		-ping [mymethod Progress]]
	return
    }

    method ScanTap {} {
	set infile [$optap choose]
	if {$infile == {}} {$type UnlockScan ; return}

	$self scanTap: $infile
	return
    }

    method scanTap: {infile} {
	$type LockScan
	## Decode contents of TDK package definition
	## Acceptable: Tape
	## Then scan the found files ...
	## The constructor auto-launches the bg process

	$self showstatusbar progression
	$self status "Scanning $infile"
	$self pinfinite 100
	set gather [tap_gather tg $infile \
		-command [mymethod ScanComplete $infile] \
		-onerror [mymethod FmtError] \
		-ping [mymethod Progress]]
	return
    }

    method ScanTeapot {} {
	set infile [$oppot choose]
	if {$infile == {}} {$type UnlockScan ; return}

	$self scanTeapot: $infile
	return
    }

    method scanTeapot: {infile} {
	$type LockScan
	## Decode contents of the TEAPOT file.
	## Then scan the files for each package ...
	## The constructor auto-launches the bg process

	$self showstatusbar progression
	$self status "Scanning $infile"
	$self pinfinite 100
	set gather [teapot_gather tg $infile \
		-command [mymethod ScanComplete $infile] \
		-onerror [mymethod FmtError] \
		-ping [mymethod Progress]]
	return
    }

    method Progress {} {
	#puts tick
	$self ptick 1
    }

    method FmtError {text} {
	tk_messageBox -icon error \
		-title "File Format Error" \
		-type ok -message $text
	rename $gather {}
	set     gather {}
	$type UnlockScan
	$self showstatusbar status
	$self status {}
	return
    }

    method BasicFmtError {text} {
	tk_messageBox -icon error \
		-title "File Format Error" \
		-type ok -message $text
	$self showstatusbar status
	$self status {}
	return
    }

    method ScanComplete {infile dbfile} {
	rename $gather {}
	set     gather {}
	$type UnlockScan
	$self showstatusbar status
	$self status {}

	if {[file size $dbfile] == 0} {
	    tk_messageBox -icon error \
		    -title "Conversion Error" \
		    -type ok -message \
		    "The generated database is empty, loading aborted."
	    return
	}
	if {[xrefdb version $dbfile] < 0} {
	    tk_messageBox -icon error \
		    -title "Conversion Error" \
		    -type ok -message \
		    "The generated file is not a TXR database, loading aborted."
	    return
	}


	# Possible operations ...
	# Scan only ... dump to some file
	# Scan and load here (use tmp file)
	# Scan and load in different window (use tmp file)

	# Simpler: Scan and load + 'Save database' menu operation.
	# Prototype ...

	## set newdbfile [file rootname $infile].txr
	## file rename -force $dbfile $newdbfile

	$self Load $dbfile 0
	return
    }


    # ### ########## ##############################
    # Handlers for events in the sub-ordinate lists
    # and the detail windows they spawned.

    variable selid   ; # Id's and types of the selected
    variable seltp   ; # objects.

    method GoChoice {button} {
	$self AnyDetail $seltp($button) $selid($button)
	return
    }
    method SetChoice {list button sortedview rtype row} {
	log::log debug "$win SetChoice $list $button $sortedview $rtype $row"

	set selid($button) $row
	set seltp($button) $rtype

	if {$row < 0} {
	    $list itemconfigure $button -state disable
	} else {
	    $list itemconfigure $button -state normal
	}
	return
    }

    # Handling double-clicks on the rows of the various view listings.

    method AnyDetailAction {sortedview rtype row} {
	$self AnyDetail $rtype $row
    }
    method AnyDetail {otype id} {
	if {$id < 0} {
	    # We have no information in the database we could show for
	    # the package.

	    tk_messageBox \
		    -title "Note: No information available" \
		    -parent $win -type ok -icon info \
		    -message "The database does not contain any\
                              information which could be shown.\
                              Our apologies."
	    return
	    #return -code error "$self AnyDetail: unable to dereference \"$otype [list $id]\""
	}
	switch -exact -- $otype {
	    namespace - N     {
		set viewname namespace
		set handler  NamespaceDetail
	    }
	    variable - V     {
		set viewname variable
		set handler  VarDetail
	    }
	    command - C {
		set viewname command
		set handler  CmdDetail
	    }
	    location - L {
		set viewname location
		set handler  LocationDetail
	    }
	    file - F {
		set viewname file
		set handler  FileDetail
	    }
	    package - P {
		set viewname package
		set handler  PkgDetail
	    }
	    default {
		return -code error "$self AnyDetail: Unknown type \"$otype\""
	    }
	}

	log::log debug "$self AnyDetail $otype $id"
	log::log debug "$self AnyDetail db = $db $viewname, $handler"

	[$db view $viewname] as   view ; # Transient view object.
	$self $handler $viewname $view $id
	return
    }

    method PkgDetail {viewname sortedview row} {
	# The detail window is given both view and row,
	# so that it can create a cursor which lasts for
	# its own lifetime. Otherwise any subview object
	# in the cursor would go away the moment this
	# command returns :(
	#
	# Additionally we provide a reference to ourselves
	# to the window, so that it can ask for resolution
	# of 'typed object references' it may have. Resolution
	# = pop up a detail window for the referenced object.

	xmainframe opendetail $win xdpkg $sortedview $row $self
	return
    }

    method FileDetail {viewname sortedview row} {

	log::log debug "$self FileDetail $viewname $sortedview $row"

	[$sortedview select rowid $row] as v ; $v cursor c ; set c(#) 0

	##$sortedview cursor c ; set c(#) $row
	###parray c
	set path [lindex [split $c(where_str) \n] 0]

	log::logarray debug c

	if {[$koedit usable]} {
	    $koedit open $path
	    return
	}

	set w [xdfile open $win $path $self]
	if {$w != {}} {
	    $w configure -storage [$sortedview storage] -fid $c(rowid)
	}
	return
    }

    method LocationDetail {viewname sortedview row} {
	# The detail window is given both view and row,
	# so that it can create a cursor which lasts for
	# its own lifetime. Otherwise any subview object
	# in the cursor would go away the moment this
	# command returns :(
	#
	# Additionally we provide a reference to ourselves
	# to the window, so that it can ask for resolution
	# of 'typed object references' it may have. Resolution
	# = pop up a detail window for the referenced object.

	if {$row == 0} {
	    # This is the no-file entry (empty filename), for things
	    # like the global namespace, which have no real location
	    # in the script, predefined as they are by the system.

	    tk_messageBox \
		    -title "Note: No information available" \
		    -parent $win -type ok -icon info \
		    -message "The database does not contain any\
                              information which could be shown.\
                              Our apologies."
	    return
	}

	# We select the entry in the view via column 'rowid'. The '#'
	# is not reliable (anymore, v0 yes, v1 no, and v0 works with
	# this method too).

	[$sortedview select rowid $row] as v ; $v cursor c ; set c(#) 0

	log::log      debug ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	log::log      debug "$win LocationDetail $viewname $sortedview $row"
	log::logarray debug c
	log::log      debug ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	#$sortedview dump

	if {[$koedit usable]} {
	    if {($c(file) != -1)} {
		if {$c(line) != -1} {
		    $koedit openat $c(file_str) $c(line) $c(begin) $c(size) $c(end)
		} else {
		    $koedit open $c(file_str)
		}
		return
	    }
	}

	set paths [split $c(file_str) \n]
	# The 'file_str' can actually be a pseudo-list of paths, using
	# newline as separator, one path per line.

	set ok 0
	foreach p $paths {
	    if {[file exists $p]} {set ok 1 ; break}
	}
	if {!$ok} {
	    tk_messageBox \
		-title Error \
		-parent $win -type ok -icon error \
		-message "We were unable to find the file \"[join $paths \n]\"\
                          and therefore cannot show it. Our apologies."
	    return
	}

	xmainframe opendetail $win xdloc $v 0 $self
	return
    }

    method NamespaceDetail {viewname sortedview row} {
	xmainframe opendetail $win xdns $sortedview $row $self
	return
    }

    method CmdDetail {viewname sortedview row} {
	xmainframe opendetail $win xdcmd $sortedview $row $self
	return
    }

    method VarDetail {viewname sortedview row} {
	xmainframe opendetail $win xdvar $sortedview $row $self
	return
    }

    # ### ########## ##############################
    # Track main windows, global (un)lock of menu items.

    typevariable windows
    typemethod Add {w} {
	set windows($w) .
	return
    }

    typemethod Remove {w} {
	unset -nocomplain windows($w)
	return
    }

    typemethod LockScan {} {
	foreach w [array names windows] {
	    $w lockScan
	}
	return
    }
    typemethod UnlockScan {} {
	foreach w [array names windows] {
	    $w unlockScan
	}
	return
    }

    method lockSave {} {
	$win setmenustate save         disabled
    }
    method unlockSave {} {
	$win setmenustate save         normal
    }

    method lockScan {} {
	$win setmenustate scan         disabled
	$win setmenustate scan-komodo  disabled
	$win setmenustate scan-tdk-tpj disabled
	$win setmenustate scan-tdk-tap disabled
	$win setmenustate scan-select  disabled
	return
    }
    method unlockScan {} {
	$win setmenustate scan         normal
	$win setmenustate scan-komodo  normal
	$win setmenustate scan-tdk-tpj normal
	$win setmenustate scan-tdk-tap normal
	#$win setmenustate scan-select  normal
	return
    }

    # ### ########## ##############################
}

# ### ########## ##############################
# Ready to go

package provide xmain 0.1
