/*
 * winInit.c --
 *
 * Tcl commands to access Wintcl functionality.
 *
 * Copyright 2002-2008 ActiveState Software Inc.
 *
 *----------------------------------------------------------------------
 * $Id: tclXwinCmds.c,v 1.2 2002/04/04 06:13:02 hobbs Exp $
 */

#include "wintcl.h"


/*
 *----------------------------------------------------------------------
 *
 * Win_Init --
 *
 *	Initialize the wintcl package.
 *
 * Results:
 *	A standard Tcl result
 *
 * Side effects:
 *	New commands are added to the Tcl interpreter.
 *
 *----------------------------------------------------------------------
 */

EXTERN int
Win_Init(Tcl_Interp *interp)
{
    return Win32_Init(interp);
}

EXTERN int
Win32_Init(Tcl_Interp *interp)
{
    if ((Tcl_InitStubs(interp, "8.1", 0) == NULL)) {
	return TCL_ERROR;
    }
    if (Tcl_PkgProvide(interp, "win32", PACKAGE_VERSION) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_CreateObjCommand(interp, "win32::ico", Wintcl_IcoObjCmd,
	    (ClientData) interp, (Tcl_CmdDeleteProc *) WintclpIcoDestroyCmd);

    Tcl_CreateObjCommand(interp, "win32::taskbar", Wintcl_TaskbarObjCmd,
	    (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);

    Tcl_CreateObjCommand(interp, "win32::kill", KillObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::start", StartObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::WinHelp",
	    WinHelpObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::SendMessage",
	    SendMessageObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::GetFileVersion",
	    GetFileVersionObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::FormatMessage",
	    FormatMessageObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::GetLastError",
	    GetLastErrorObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::OutputDebugString",
	    OutputDebugStringObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::DebugBreak",
	    DebugBreakObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::GetSpecialFolderPath",
	    GetSpecialFolderPathObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::CreateShortcut",
	    CreateShortcutObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::EventLog",
	    EventLogObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "win32::transparent",
	    TransparentObjCmd, NULL, NULL);

    if (WintclpInitCSIDL(interp) != TCL_OK) {
	return TCL_ERROR;
    }

    return Win32Svc_Init(interp);
}
