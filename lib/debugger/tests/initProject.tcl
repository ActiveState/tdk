# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# initProject --
#
#	Initialize the Project group and the GlobalDefault group to a clean
#	state.  Also, hard code the project path and application arguments
#	so the project can actually start executing code.
#
# Arguments:
#	projPath
#	script		
#	arg		
#	dir		
#	interp
#
# Results:
#	None.

proc initProject {projPath script arg dir interp} {
    cleanProject
    
    initGlobalDefault

    pref::groupInit Project [list \
	    appScript		{}			{} \
	    appArg		{}			{} \
	    appDir		{}			{} \
	    appInterp		{}			{} \
	    appScriptList	[list $script]		{} \
	    appArgList		[list $arg]		{} \
	    appDirList		[list $dir]		{} \
	    appInterpList	[list $interp]		{} \
	    appType		local			{} \
	    breakList		{}			{} \
	    errorAction		1			{} \
	    dontInstrument	{}			{} \
	    instrumentDynamic	1			{} \
	    instrumentIncrTcl	1			{} \
	    instrumentExpect	1			{} \
	    instrumentTclx	1			{} \
	    noAutoLoad		1			{} \
	    portRemote		2576			{} \
	    projRemote		0			{} \
	    projVersion		1.0			{} \
	    prevViewFile 	{} 			{} \
    ]

    proj::setProjectPath $projPath
    proj::InitNewProj
    return
}

# initRemoteProject --
#
#	Initialize the Project group and the GlobalDefault group to a clean
#	state.  Make the loaded pojec a remote project.
#
# Arguments:
#	projPath
#	port
#
# Results:
#	None.

proc initRemoteProject {projPath port} {
    # Create the project and global preferences.
    initProject $projPath {} {} {} {}

    # Turn the existing project into a remote project.

    pref::prefNew Project portRemote $port  {}
    pref::prefNew Project appType    remote {}

    # Update the state to the GUI.

    proj::setProjectPath $projPath
    proj::InitNewProj
    return
}

# initGlobalDefault --
#
#	Initialize the GlobalDefault group.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc initGlobalDefault {} {
    pref::groupInit GlobalDefault [list \
	    browserCmd		[system::getBrowserCmd]	{} \
	    browserDefault	[system::getDefBrowser] {} \
	    comboListSize	10			{} \
	    exitPrompt		kill			{} \
	    fileOpenDir		[pwd]   		{} \
	    fontSize		10			{} \
	    fontType		courier 		{} \
	    highlight		lightblue 	        {} \
	    highlight_error	red			{} \
	    highlight_cmdresult	#ffff80			{} \
	    historySize		64			{} \
	    paneGeom		{}			{} \
	    projectList		{}			{} \
	    projectPrev		{}			{} \
	    projectReload	1			{} \
	    screenSize		300			{} \
	    tabSize		8			{} \
	    tclHelpFile		{}			{} \
	    showCodeLines	1			{} \
	    showResult		1			{} \
	    showStatusBar	1			{} \
	    showToolbar		1			{} \
	    warnOnKill		1			{} \
	    warnOnClose		0			{} \
	    warnInvalidBp	0			{} \
	    winGeoms		{}			{} \
    ]

    # Only set the widget attributes if we have loaded the image 
    # file.  If it hasn't been loaded, we assume the tests are non
    # gui test and therefore have not sourced needed files.

    if {[lsearch [namespace children ::] ::image] >= 0} {
	system::setWidgetAttributes
    }

    return
}

# initProjectDefault --
#
#	Initialize the ProjectDefault group.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc initProjectDefault {} {
    pref::groupInit ProjectDefault [list \
	    appScript		{}	projWin::updateScriptList \
	    appArg		{}	projWin::updateArgList    \
	    appDir		{}	projWin::updateDirList    \
	    appInterp	    [system::getInterps] projWin::updateInterpList \
	    appScriptList	{}				{} \
	    appArgList		{}				{} \
	    appDirList		{}				{} \
	    appInterpList	[system::getInterps]		{} \
	    appType		local				{} \
	    breakList		{}				{} \
	    errorAction		1	dbg::initInstrument	\
	    dontInstrument	{}	dbg::initInstrument	\
	    instrumentDynamic	1	dbg::initInstrument	\
	    instrumentIncrTcl	1	projWin::updateIncrTcl  \
	    instrumentExpect	1	projWin::updateExpect   \
	    instrumentTclx	1	projWin::updateTclX     \
	    autoLoad		0	dbg::initInstrument	\
	    portRemote		2576	projWin::updatePort     \
	    projVersion		1.0	{}			\
	    prevViewFile 	{} 	{}			\
	    watchList		{}	{}			\
    ]
    return
}

# initProjectFiles --
#
#	Initialize the various project files.
#
# Arguments:
#	dummy	The name of a dummy file.
#
# Results:
#	None.

proc initProjectFiles {dummy} {
    global projDir
    global corruptProj
    global noreadProj 
    global nowriteProj
    global localProj 
    global remoteProj
    global tcl_platform

    set projDir     $::tcltest::temporaryDirectory
    set corruptProj [file join $projDir Corrupt.tpj]
    set noreadProj  [file join $projDir NoReadPerm.tpj]
    set nowriteProj [file join $projDir NoWritePerm.tpj]
    set localProj   [file join $projDir Local.tpj]
    set remoteProj  [file join $projDir Remote.tpj]

    set proj::projectOpen 1
 
    set file [open $::corruptProj w]
    puts $file "set"
    close $file

    proj::setProjectPath $noreadProj
    pref::groupNew Project {proj::SaveProjCmd [proj::getProjectPath]} {}
    pref::groupCopy ProjectDefault Project
    proj::saveProj $noreadProj
    pref::groupDelete Project
    
    proj::setProjectPath $nowriteProj
    pref::groupNew Project {proj::SaveProjCmd [proj::getProjectPath]} {}
    pref::groupCopy ProjectDefault Project
    proj::saveProj $nowriteProj
    pref::groupDelete Project

    if {$tcl_platform(platform) == "windows"} {
	file attribute $nowriteProj -readonly 1
	set exeName tclsh$::protest::currentVersion(Tcl-short)
    } else {
	file attribute $noreadProj  -permissions 0000
	file attribute $nowriteProj -permissions 0400
	set exeName tclsh$::protest::currentVersion(Tcl)
    }
    proj::setProjectPath $localProj
    pref::groupNew Project {proj::SaveProjCmd [proj::getProjectPath]} {}
    pref::groupCopy ProjectDefault Project
    pref::prefSet Project appScriptList	[list $dummy]
    pref::prefSet Project appArgList	{}
    pref::prefSet Project appDirList	[list [file dirname $dummy]]
    pref::prefSet Project appInterpList [list [findExeFile $exeName]]
    proj::saveProj $localProj
    pref::groupDelete Project

    proj::setProjectPath $remoteProj
    pref::groupNew Project {proj::SaveProjCmd [proj::getProjectPath]} {}
    pref::groupCopy ProjectDefault Project
    pref::prefSet Project appType remote
    proj::saveProj $remoteProj
    pref::groupDelete Project
 
    set proj::projectOpen 0
    pref::prefSet GlobalDefault projectList {}
    return
}

# cleanProject --
#
#	Reset all of the project state.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc cleanProject {} {
    set proj::projectOpen 0
    set proj::projectNeverSaved 0

    if {[pref::groupExists Temp]} {
	pref::groupDelete Temp
    }
    if {[pref::groupExists Project]} {
	pref::groupDelete Project
    }

    cleanProjectFiles

    return
}

# cleanProjectFiles --
#
#	Remove the project files.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc cleanProjectFiles {} {
    global projDir
    global corruptProj
    global noreadProj 
    global nowriteProj
    global localProj 
    global remoteProj
    global tcl_platform

    if {![info exists projDir]} {
	return
    }

    if {$tcl_platform(platform) == "windows"} {
	file attribute $nowriteProj -readonly 0
    } else {
	file attribute $noreadProj  -permissions 0755
	file attribute $nowriteProj -permissions 0755
    }

    catch {file delete -force $corruptProj}
    catch {file delete -force $noreadProj}
    catch {file delete -force $nowriteProj}
    catch {file delete -force $localProj}
    catch {file delete -force $remoteProj}

    catch {unset corruptProj}
    catch {unset noreadProj}
    catch {unset nowriteProj}
    catch {unset localProj}
    catch {unset remoteProj}
 
    return
}

# Project Save and Restore Commands --
#
#	Redifine the save and restore commands for Unix and Windows so that
#	user preferences do not interfere with tests.
#
# Arguments:
#	group	The name of the group to restore preferences into.
#
# Results:
#	Return a boolean, 1 means that the save did not succeed, 
#	0 means it succeeded.

proc system::winRestoreCmd {group} {
    return 0
}

proc system::winSaveCmd {group} {
    return 0
}

proc system::unixRestoreCmd {group} {
    return 0
}

proc system::unixSaveCmd {group} {
    return 0
}
