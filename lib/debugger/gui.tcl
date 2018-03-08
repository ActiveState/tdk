# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# gui.tcl --
#
#	This is the main interface for the Debugger.
#
# Copyright (c) 1998-2000 Ajuba Solutions
# Copyright (c) 2002-2009 ActiveState Software Inc.

#
# RCS: @(#) $Id: gui.tcl,v 1.15 2001/10/17 18:08:33 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requisites

package require parser
package require tile
package require BWidget ; Widget::theme 1 ; # use themed widgets in BWidgets
package require ui_engine ;# Pane per engine.
package require fmttext
package require tooltip

if {[info exists ::env(TDK_DEBUG)]} {
    package require comm
    puts "COMM [comm::comm self]"
}

# ### ### ### ######### ######### #########
## Implementation

snit::type topgui {

    # The gui::gui array stores; information on the current state of
    # GUI; handles to Tk widgets created in this namespace, and to
    # text variables of the status window.
    #
    #
    # Toplevel window names.
    #
    # gui(mainDbgWin)		Toplevel window for the debugger.
    # gui(prefDbgWin)		The toplevel window used to display
    # 				and set debugger preferences.
    #
    # State of the Debugger. --> see ui_engine
    #
    # Widgets in the Debugger.
    #
    #
    # gui(dbgFrm)		NoteBook that contains the panes containing the stack, var and
    # 				code windows for all debugger connecitons.
    # gui(resultFrm)		Frame that contains the result window.
    # gui(statusFrm)		Frame that contains the status window.
    # gui(toolbarFrm)		Frame that contains the toolbar window.
    #
    #
    # Checkbox variables.
    #
    #
    # gui(showToolbar)		Checkbutton var that indicates if the
    #				toolbar is currently being displayed.
    #				1 if it is diaplayed and 0 if not.
    # gui(showStatus)		Checkbutton var that indicates if the
    #				status is currently being displayed.
    #				1 if it is diaplayed and 0 if not.
    #
    # Other...
    #

    variable gui

    # Set all the names of the toplevel windows.


    # When the GUI state goes to running, clear out the Stack, Var,
    # Watch, and PC icon.  To reduce flickering, only do this after
    # <after Time>.  The afterID is the handle to the after event
    # so it can be canceled if the GUIs state changes before it fires.

    variable afterTime 500
    variable instMsg
    variable counter 0

    variable infoText
    variable instLbl
    variable fileText

    variable afterStatus


    variable mainengine {}
    method   engine: {value} {
	# Remember the main debugger engine for the creation of the UI.

	set mainengine $value
	return
    }

    # ### ### ### ######### ######### #########

    constructor {args} {
	set gui(fileDbgWin)   .fileDbgWin
	set gui(mainDbgWin)   .mainDbgWin
	set gui(prefDbgWin)   .prefDbgWin
	set gui(statusStateMsg)    "new session"

	#$self configurelist $args
	return
    }

    foreach _ {
	fileDbgWin
	mainDbgWin
	prefDbgWin
	toolbarFrm
	resultFrm
	statusFrm
    } {
	method $_ {} [list set gui($_)]
    }
    foreach _ {
	afterTime
    } {
	method $_ {} [list set $_]
    }

    #-----------------------------------------------------------------------------
    # Main Debugger Window Functions
    #-----------------------------------------------------------------------------

    # method showMainWindow
    #
    #	Displays the Main Debugger window.  If it has already been created
    #	it deiconifies, and raises the window to the foreground.  Otherwise
    #	it creates the toplevel window and all of it's components.
    #
    # Arguments:
    #	None.

    # Results:
    #	The handle to the toplevel window of the debugger.

    method showMainWindow {} {
	if {[winfo exists $gui(mainDbgWin)]} {
	    wm deiconify $gui(mainDbgWin)
	    raise        $gui(mainDbgWin)
	    return       $gui(mainDbgWin)
	}

	set          mainDbgWin [toplevel $gui(mainDbgWin)]
	wm protocol $mainDbgWin WM_DELETE_WINDOW {ExitDebugger}
	wm minsize  $mainDbgWin 350 300
	wm withdraw $mainDbgWin

	update

	$self setDebuggerTitle ""
	system::bindToAppIcon     $mainDbgWin

	if {$::tcl_platform(os) eq "darwin"} {
	    # On OS X we make the default wider. See Bug 80445.
	    ::guiUtil::positionWindow $mainDbgWin 650x500
	} else {
	    ::guiUtil::positionWindow $mainDbgWin 500x500
	}
	pack propagate            $mainDbgWin off

	# Create the Menus and bind the functionality.

	menu::create $mainDbgWin

	# Create the debugger window, which consists of the
	# stack, var and code window with sliding panels.
	# Insert it into the grid and ensure that it expands to fill
	# all available space.

	### Create one pane per engine we know.
	### For now we create one pane for the single connection we
	### have, which is the main connection too ...

	set gui(dbgFrm) [ttk::notebook $mainDbgWin.engines]

	set key  [$self NewKey]
	set pane [ttk::frame $gui(dbgFrm).$key -padding 4]
	$gui(dbgFrm) insert end $pane -text Project -compound left
	bind $gui(dbgFrm) <<NotebookTabChanged>> [mymethod RaiseEngine]

	# This definition of tooltips depends on the internals
	# of the Bwidget notebook !!
	# XXX adapt for ttk
	#tooltip::tooltip $gui(dbgFrm).c -item ${key}:text Project
	#tooltip::tooltip $gui(dbgFrm).c -item ${key}:img  Project

	set uie  [ui_engine $pane.uie -gui $self -engine $mainengine]

	grid columnconfigure $pane 0 -weight 1
	grid rowconfigure    $pane 0 -weight 1
	grid $uie        -in $pane -column 0 -row 0 -sticky swen

	$self AddEngine [$gui(dbgFrm) index $pane] $uie
	set active           $uie ;# Some stuff needs this right now
	set master           $active

	grid $gui(dbgFrm) -row 1 -sticky nsew -padx 4 -pady 2
	grid rowconfigure    $mainDbgWin 1 -weight 1
	grid columnconfigure $mainDbgWin 0 -weight 1

	# Create the Toolbar, Status and Result windows.

	set gui(toolbarFrm) [tool::createWindow       $mainDbgWin]
	set gui(statusFrm)  [$self createStatusWindow $mainDbgWin]
	set gui(resultFrm)  [result::createWindow     $mainDbgWin]

	# Add global keybindings

	bind::addBindTags $mainDbgWin mainDbgWin

	# Initialize the coverage gui.
	coverage::globalInit

	# Invoke the appropriate menu times to ensure that the display
	# reflects the user's preferences.

	eval [$menu::menu(view) entrycget Toolbar -command]
	eval [$menu::menu(view) entrycget Status -command]
	eval [$menu::menu(view) entrycget Result -command]
	eval [$menu::menu(view) entrycget {Line Numbers} -command]

	$gui(dbgFrm) select $pane
	$self RaiseEngine ; # first pane doesn't trigger NotebookTabChanged

	$active changeState new
	focus -force [$active mainFocus]

	return $gui(mainDbgWin)
    }

    # method setDebuggerTitle --
    #
    #	Set the title of the Debugger based on the prj name.
    #
    # Arguments:
    #	proj	The name of the project currently loadded.  Use empty
    #		if no project is currently loaded.
    #
    # Results:
    #	None.  Change the title of the main toplevel window.

    method setDebuggerTitle {proj} {
	if {$proj == ""} {
	    set proj "<no project loaded>"
	}
	wm title $gui(mainDbgWin) "$::debugger::parameters(productName): $proj"
	return
    }




    #-----------------------------------------------------------------------------
    #-----------------------------------------------------------------------------

    # method getParent --
    #
    #	Return the parent window that a tk_messageBox should use.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	A window name.

    method getParent {} {
	if {[set parent [focus]] == {}} {
	    return "."
	}
	return [winfo toplevel $parent]
    }

    #-----------------------------------------------------------------------------
    # Status Window Functions
    #-----------------------------------------------------------------------------

    # method createStatusWindow --
    #
    #	Create the status bar and initialize the status label.
    #
    # Arguments:
    #	mainDbgWin	The toplevel window for the main debugger.
    #
    # Results:
    #	The frame that contains the status window.

    variable errCount {} ; # Remember them for the switch of the active engine
    variable wrnCount {} ; # 

    method createStatusWindow {mainDbgWin} {
	set bg     [$mainDbgWin cget -bg]
	set cursor [system::getArrow]

	set statusFrm [ttk::frame $mainDbgWin.status]
	set statusPw [ttk::panedwindow $statusFrm.status -orient horizontal]

	# Left-hand side of status pane
	set infoFrm   [ttk::frame $statusPw.infoFrm]
	set infoText  [ttk::label $infoFrm.infoText -width 1 -anchor w]
	# Checker integration ... (Accumulated error statistics)
	set errCount  [ttk::label $infoFrm.err -compound left \
			   -image $image::image(syntax_error) \
			   -background [[$active checker] color error] \
			   -textvariable [[$active checker] errorvar]]
	set wrnCount  [ttk::label $infoFrm.wrn -compound left \
			   -image $image::image(syntax_warning) \
			   -background [[$active checker] color warning] \
			   -textvariable [[$active checker] warnvar]]
	tooltip::tooltip $errCount "\# of code syntax errors"
	tooltip::tooltip $wrnCount "\# of code syntax warnings"
	# double-click on error/warning count pops up Errors panel
	bind $errCount <Double-1> [list maingui cwShowWindow]
	bind $wrnCount <Double-1> [list maingui cwShowWindow]

	grid $infoText $errCount $wrnCount -sticky ew
	grid columnconfigure $infoFrm 0 -weight 1

	# Right-hand side of status pane
	set fileFrm [ttk::frame $statusPw.fileFrm -width 0]
	set instLbl [ttk::label $fileFrm.instLbl \
			 -image $image::image(instrumented_disable)]
	tooltip::tooltip $instLbl "File not instrumented"
	set fileText [text $fileFrm.fileText -bd 1 \
			  -width 0 -height 1 -bg $bg \
			  -wrap none -cursor $cursor]

	grid $instLbl  -row 0 -column 0 -sticky we
	grid $fileText -row 0 -column 1 -sticky we -padx 2
	grid columnconfigure $fileFrm 1 -weight 1

	$statusPw add $infoFrm -weight 3
	$statusPw add $fileFrm -weight 1

	set grip [ttk::sizegrip $statusFrm.grip]
	grid $statusPw $grip -sticky sew
	grid columnconfigure $statusFrm 0 -weight 1

	$fileText tag configure right -justify right -rmargin 4
	bind::removeBindTag $fileText Text

	bind $fileText <Configure> [mymethod updateStatusFileFormat]
	$fileText tag bind lineStatus <Double-1> [mymethod gotoShowWindow]
	$self updateStatusMessage
	return $statusFrm
    }

    # ### ### ### ######### ######### #########

    method setStatusMsg {msg} {
	$self updateStatusMessage -state 1 -msg $msg
	return
    }

    method  StatusDelayed {bwin delay msg} {
	set afterStatus($bwin) [after $delay [mymethod updateStatusMessage -msg $msg]]
	return
    }

    method updateChkHighlights {} {
	$active codeCheckInit
	$wrnCount configure -background [[$active checker] color warning]
	$errCount configure -background [[$active checker] color error]
	return
    }

    method updateCovHighlights {} {
	# Propagate to all open sessions.
	foreach uie $uiengines {
	    $uie updateCovHighlights
	}
	return
    }

    method updateProfHighlights {} {
	# Propagate to all open sessions.
	foreach uie $uiengines {
	    $uie updateProfHighlights
	}
	return
    }

    # ### ### ### ######### ######### #########

    # method updateStatusMessage --
    #
    #	Set messages in the Status window.
    #
    # Arguments:
    #	args	Ordered list of flag and value, used to set the
    #		portions of the Status message.  Currently supported
    #		flags are: -msg and -state
    #
    # Results:
    #	None.

    method updateStatusMessage {args} {
	set a(-state) 0
	set a(-msg)  {}
	array set a $args

	# If the message is an empty string, display the current
	# GUI state information.  If the message type is 'state'
	# then we have a new GUI state, cache the message in the
	# gui array.

	if {$a(-msg) == {}} {
	    set a(-msg) $gui(statusStateMsg)
	}
	if {$a(-state)} {
	    set gui(statusStateMsg) $a(-msg)
	}
	$infoText configure -text $a(-msg)
	return
    }

    # method updateStatusLine --
    #
    #	Update the status line number.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateStatusLine {line} {
	set update 0
	set range [$fileText tag range lineStatus]
	if {$range == {}} {
	    set update 1
	} else {
	    foreach {start end} $range {
		$fileText delete $start $end
	    }

	    set start [lindex [split [lindex $range 0] .] 1]
	    set end   [lindex [split [lindex $range 1] .] 1]
	    set oldLen [expr {$end - $start}]
	    set newLen [string length $line]
	    if {$oldLen != $newLen} {
		set update 1
	    }
	}
	$fileText insert end " : $line" [list right lineStatus]
	if {$update} {
	    fmttext::formatText $fileText left
	}
    }

    method clearStatusFile {} {
	fmttext::unformatText $fileText
	$fileText delete 0.0 end
	$instLbl configure -image $image::image(instrumented_disable)
	tooltip::tooltip $instLbl "File not instrumented"
	return
    }
    method updateStatusInstrumentFlag {inst} {
	# Insert a "*" into the status if the block
	# is instrumented.

	if {$inst} {
	    $instLbl configure -image $image::image(instrumented)
	    tooltip::tooltip $instLbl "File instrumented"
	} else {
	    $instLbl configure -image $image::image(instrumented_disable)
	    tooltip::tooltip $instLbl "File not instrumented"
	}
	return
    }
    method updateStatusFile {file line} {
	# Insert the name of the block being shown.

	$fileText insert 0.0 $file right

	# Insert the line number that the cursor is on.

	if {$line != {}} {
	    $fileText insert end " : $line" [list right lineStatus]
	}

	$self updateStatusFileFormat
	return
    }

    # method updateStatusFileFormat --
    #
    #	Make sure that the rhs of the filename is
    #	always viewable.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method updateStatusFileFormat {} {
	if {[info exists  afterStatus($fileText)]} {
	    after cancel $afterStatus($fileText)
	    unset         afterStatus($fileText)
	}
	set afterStatus($fileText) [after 50 [mymethod updateStatusFileFormatAfter]]
	return
    }
    method updateStatusFileFormatAfter {} {
	fmttext::formatText $fileText left
	return
    }

    # method registerStatusMessage --
    #
    #	Add the <Enter> and <Leave> bindings to a widget
    #	that displays the message after the mouse has
    #	been in the widget for more then N seconds.
    #
    # Arguments:
    #	win	The widget to add bindings to.
    #	msg	The message to display.
    #	delay	The number of ms. to wait before displaying the msg.
    #
    # Results:
    #	None.

    method registerStatusMessage {bwin msg {delay 1000}} {
	bind $bwin <Enter> [mymethod StatusEnter $delay $msg %W]
	bind $bwin <Leave> [mymethod StatusLeave %W]
    }
    method StatusEnter {delay msg bwin} {
	if {[$bwin cget -state] == "normal"} {
	    set afterStatus($bwin) [after $delay [mymethod updateStatusMessage -msg $msg]]
	}
    }
    method StatusLeave {bwin} {
	if {[info exists  afterStatus($bwin)]} {
	    after cancel $afterStatus($bwin)
	    unset         afterStatus($bwin)
	    $self updateStatusMessage -msg {}
	}
    }

    #-----------------------------------------------------------------------------
    # About Window Functions
    #-----------------------------------------------------------------------------

    # ### ### ### ######### ######### #########
    # Methods for actions on the current active connection ...

    delegate method showCode        to active
    delegate method quit            to active
    delegate method run             to active
    delegate method runTo           to active
    delegate method interrupt       to active
    delegate method kill            to active
    delegate method changeState     to active

    delegate method getCurrentState   to active
    delegate method getCurrentBlock   to active
    delegate method getCurrentLevel   to active
    delegate method getCurrentFile    to active
    delegate method getCurrentBreak   to active
    delegate method getCurrentVer     to active

    delegate method blkIsInstrumented to active
    delegate method blkGetFile        to active
    delegate method getUniqueFiles    to active

    delegate method setCurrentBlock to active
    delegate method setCurrentFile  to active
    delegate method setCurrentLine  to active
    delegate method setCurrentVer   to active

    delegate method showConnectStatus to active
    delegate method askToKill         to active

    delegate method codeCheckCore     to active

    method preservables {} {
	set result [list \
		[$self fileDbgWin]  \
		[$self mainDbgWin]  \
		]

	foreach uie $uiengines {
	    lappend result \
		    [$uie breakDbgWin] \
		    [$uie dataDbgWin]  \
		    [$uie errorDbgWin] \
		    [$uie parseDbgWin]  \
		    [$uie errorDbgDefWin]  \
		    [$uie evalDbgWin]  \
		    [$uie findDbgWin]  \
		    [$uie gotoDbgWin]  \
		    [$uie procDbgWin]  \
		    [$uie watchDbgWin]
	}
	return $result
    }

    # Menu/Toolbar/System actions ..

    delegate method bpShowWindow    to active
    delegate method cwShowWindow    to active
    delegate method covShowWindow   to active
    delegate method evalShowWindow  to active
    delegate method procShowWindow  to active
    delegate method gotoShowWindow  to active
    delegate method watchShowWindow to active
    delegate method showResult      to active

    delegate method prShowNewProjWindow  to master
    delegate method prOpenProjCmd        to master
    delegate method prCloseProjCmd       to master
    delegate method prSaveProjCmd        to master
    delegate method prSaveAsProjCmd      to master
    delegate method prShowThisProjWindow to master
    delegate method prRestartProj        to master
    delegate method prIsProjectOpen      to master
    delegate method prProjectNeverSaved  to master
    delegate method prGetProjectPath     to master
    delegate method prIsRemoteProj       to master
    delegate method prOpenFileWindow     to master
    delegate method prCloseProjDialog    to master
    delegate method prCloseProj          to master

    method tkConUpdate {} {
	foreach uie $uiengines {$uie tkConUpdate}
	return
    }
    method initInstrument {} {
	foreach uie $uiengines {$uie initInstrument}
	return
    }
    method warnInvalidBp {} {
	foreach uie $uiengines {$uie warnInvalidBp}
	return
    }

    delegate method prwUpdateScriptList to master
    delegate method prwUpdateArgList    to master
    delegate method prwUpdateDirList    to master
    delegate method prwUpdateInterpList to master
    delegate method prwUpdateIncrTcl    to master
    delegate method prwUpdateExpect     to master
    delegate method prwUpdateTclX       to master
    delegate method prwUpdatePort       to master

    delegate method findShowWindow to active
    delegate method findNext       to active
    delegate method findNextOK     to active

    delegate method varShowInspector to active
    delegate method varAddToWatch    to active
    delegate method varToggleVBP     to active
    delegate method varBreakState    to active
    delegate method codeBreakState   to active

    delegate method editInKomodo to active
    delegate method useKomodoOK  to active

    # ### ### ### ######### ######### #########
    # Toolbar and menu actions.

    method dbgrun {} {
	$active run [list [$activengine dbg] run]
    }
    method dbgstep {} {
	$active run [list [$activengine dbg] step]
    }
    method dbgstepover {} {
	$active run [list [$activengine dbg] step over]
    }

    method dbgstepout {} {
	$active run [list [$activengine dbg] step out]
    }
    
    method dbgstepcmdresult {} {
	$active run [list [$activengine dbg] step cmdresult]
    }

    delegate method openFile         to active
    delegate method refreshFile      to active
    delegate method cutcopy          to active
    delegate method toggleLBP        to active
    delegate method toggleSP         to active
    delegate method allSPOn          to active
    delegate method showInstrumented to active
    delegate method toggleLogOutput  to active
    delegate method debugvar         to active
    delegate method focusArea        to active
    delegate method focusHighlight   to active
    delegate method focusVarWin      to active
    delegate method focusStackWin    to active
    delegate method focusCodeWin     to active

    delegate method codeLineBar        to active
    delegate method codeUpdateTabStops to active
    ##delegate method codeCheckInit    to active

    delegate method stayingdead to active
    delegate method chgCoverage to active

    method closeDebugger {} {
	$self RemoveEngine $active

	# Use last engine as new active one.
	set uie [lindex $uiengines end]
	set key $keymap($uie)
	$gui(dbgFrm) select $key
	return
    }

    # ### ### ### ######### ######### #########

    variable master      {} ; # Main ui_engine
    variable active      {}
    variable activengine {}
    variable uiengines   {}
    variable keycnt 0
    variable keymap

    method Activate {uie} {
	set active      $uie
	set activengine [$uie cget -engine]

	$errCount configure -textvariable [[$active checker] errorvar]
	$wrnCount configure -textvariable [[$active checker] warnvar]
	$self updateChkHighlights

	tool::setActive $uie
	menu::setActive $uie
    }
    method NewKey {} {
	return [incr keycnt]
    }
    method AddEngine {key uie {parent {}}} {
	set keymap($key) $uie
	set keymap($uie) $key
	lappend uiengines $uie
	$uie configure -onspawn [mymethod HandleSpawn]
	if {$parent != {}} {
	    # Sub sessions inherit their coverage settings
	    # from the parent session.
	    $uie configure -coverage [$parent cget -coverage]
	}
	return
    }
    method RaiseEngine {} {
	set key [$gui(dbgFrm) index current]
	if {$key ne ""} {
	    set uie $keymap($key)
	    $self Activate $uie
	}
	return
    }

    method RemoveEngine {uie} {
	set key       $keymap($uie)
	set pos       [lsearch -exact $uiengines $uie]
	set uiengines [lreplace $uiengines $pos $pos]

	$gui(dbgFrm) forget $key
	destroy $key

	unset keymap($uie) keymap($key)
	catch {
	    set port  $keymap(p,$uie)
	    set title $keymap(t,$uie)
	    unset keymap(p,$uie) keymap(e,$port) keymap(t,$uie)
	    unset titles($title)
	}
	return
    }

    method HandleSpawn {cmd detail parent} {
	# The backend is asking for a new debugger connection ...

	#puts "SPAWN $cmd $detail"

	if {$cmd eq "request"} {
	    # New engine wanted ... detail = title
	    #
	    # We have to
	    # - create a new debugger engine
	    # - create a new ui engine
	    # - connect and initialize them
	    # - create a new pane in our notebook and add the new uie
	    #   to it.
	    # - determine the port the new engine is listening on.

	    set newengine [engine %AUTO% \
		    -warninvalidbp     [pref::prefGet warnInvalidBp] \
		    -instrumentdynamic [pref::prefGet instrumentDynamic] \
		    -doinstrument      [pref::prefGet doInstrument] \
		    -dontinstrument    [pref::prefGet dontInstrument] \
		    -autoload          [pref::prefGet autoLoad] \
		    -erroraction       [pref::prefGet errorAction] \
		    ]

	    set titlePrefix [$self titlePrefix $detail]
	    set label       $titlePrefix[string replace $detail 10 end ...]

	    set key  [$self NewKey]
	    set pane [ttk::frame $gui(dbgFrm).$key]

	    set uie  [ui_engine $pane.uie \
		    -gui $self -engine $newengine \
		    -title $titlePrefix$detail]
	    set port [$uie spawnstart]

	    # Without port we deny sub process debugging
	    if {$port == {}} {
		destroy $pane
		return {}
	    }

	    $gui(dbgFrm) insert end $pane -text $label -compound left

	    # This definition of tooltips depends on the internals
	    # of the Bwidget notebook !!
	    # XXX adapt for ttk
	    #tooltip::tooltip $gui(dbgFrm).c -item ${key}:text $titlePrefix$detail
	    #tooltip::tooltip $gui(dbgFrm).c -item ${key}:img  $titlePrefix$detail

	    grid columnconfigure $pane 0 -weight 1
	    grid rowconfigure    $pane 0 -weight 1
	    grid $uie        -in $pane -column 0 -row 0 -sticky swen

	    $self AddEngine [$gui(dbgFrm) index $pane] $uie $parent
	    set keymap(e,$port) $uie
	    set keymap(p,$uie)  $port
	    set keymap(t,$uie)  $titlePrefix$detail
	    $gui(dbgFrm) select $pane

	    return $port
	} elseif {$cmd eq "error"} {
	    # Removal half-baked engine wanted ... detail = port it is listening on.
	    # Map from the port to the proper engine, then remove it.

	    set uie $keymap(e,$detail)
	    $self RemoveEngine $uie

	} else {
	    return -code error "[info level 0]: Bad spawn request"
	}
    }

    method setState {uie state} {
	switch -exact -- $state {
	    dead              {set img $image::image(stop)}
	    stopped           {set img $image::image(pause)}
	    stopped/result    {set img $image::image(pause)}
	    stopped/line      {set img $image::image(break_enable_sx)}
	    stopped/var       {set img $image::image(var_enable_sx)}
	    stopped/cmdresult {set img $image::image(pause)}
	    stopped/error     {set img $image::image(syntax_error_sx)}
	    running           {set img $image::image(run)}
	    error             {set img $image::image(syntax_error_sx)}
	    default {
		error "Unknown state \"$state\""
	    }
	}
	set pos $keymap($uie)
	$gui(dbgFrm) tab $pos -image $img

	if {[string match stopped* $state]} {
	    #puts S/A/$state/$pos/$uie
	    $gui(dbgFrm) select $pos
	}
	return
    }

    variable titles
    method titlePrefix {title} {
	if {![info exists titles($title)]} {
	    set titles($title) .
	    return ""
	}
	set pfx 1
	while {[info exists "titles(($pfx) $title)"]} {incr pfx}
	set "titles(($pfx) $title)" .
	return "($pfx) "
    }


    method useTooltips {} {
	if {[pref::prefGet useTooltips]} {
	    tooltip::tooltip on
	} else {
	    tooltip::tooltip off
	}
	return
    }
}

# ### ### ### ######### ######### #########
## Ready to go

package provide gui 1.0
