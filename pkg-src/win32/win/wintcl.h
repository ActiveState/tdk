/*
 * wintcl.h
 *
 * Portability include file for MS Windows systems.
 *
 * $Id: wintcl.h,v 1.2 2002/04/04 06:13:21 hobbs Exp $
 */

#ifndef _WINTCL_H
#define _WINTCL_H

/*
 * We must specify the lower version we intend to support. In particular
 * the SystemParametersInfo API doesn't like to receive structures that
 * are larger than it expects which affects the font assignements.
 *
 * WINVER = 0x0410 means Windows 98 and above
 */

#ifndef WINVER
#define WINVER 0x0410
#endif
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0410
#endif

#ifndef _CRT_SECURE_NO_WARNINGS /* ignore sprintf security warnings */
#define _CRT_SECURE_NO_WARNINGS
#endif

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#undef WIN32_LEAN_AND_MEAN

#include <tchar.h>
#include <stdlib.h>

#include "tk.h"
#include "tkPlatDecls.h"

/*
 * Tcl/Tk 8.4 introduced better CONST-ness in the APIs, but we use CONST84 in
 * some cases for compatibility with earlier Tcl headers to prevent warnings.
 */
#ifndef CONST84
#  define CONST84
#endif

/*
 * Windows needs to know which symbols to export.
 */

#ifdef BUILD_win32
#undef TCL_STORAGE_CLASS
#define TCL_STORAGE_CLASS DLLEXPORT
#endif /* BUILD_sample */

#define TCL_OBJ_CMD(cmd)	int (cmd)(ClientData clientData, \
		Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])

/*
 * Functions in winUtils.c
 */

typedef struct {
    char * name;	/* message name */
    long   value;	/* message value */
} Cmd_Struct;

char *	Cmd_GetName _ANSI_ARGS_((const Cmd_Struct *cmds, long val));
int	Cmd_GetValue _ANSI_ARGS_((Tcl_Interp *interp, const Cmd_Struct *cmds,
					 const char *arg, long *value));
void	Cmd_GetError _ANSI_ARGS_((Tcl_Interp *interp, const Cmd_Struct *cmds,
					 const char *arg));
Tk_Window Cmd_WinNameOrHandle _ANSI_ARGS_((Tcl_Interp *interp, Tcl_Obj *objPtr,
						  HWND *hwndPtr, int reqToplevel));
void	Cmd_FormatMessage(Tcl_Interp *interp, DWORD error, Tcl_DString *dsPtr);
void	Cmd_AppendSystemError(Tcl_Interp *interp, DWORD error);

/*
 * Functions in winTrans.c
 */

TCL_OBJ_CMD(TransparentObjCmd);

/*
 * Functions in winCmds.c
 */

TCL_OBJ_CMD(KillObjCmd);
TCL_OBJ_CMD(StartObjCmd);
TCL_OBJ_CMD(WinHelpObjCmd);
TCL_OBJ_CMD(GetFileVersionObjCmd);
TCL_OBJ_CMD(FormatMessageObjCmd);
TCL_OBJ_CMD(GetLastErrorObjCmd);
TCL_OBJ_CMD(OutputDebugStringObjCmd);
TCL_OBJ_CMD(DebugBreakObjCmd);
TCL_OBJ_CMD(GetSpecialFolderPathObjCmd);
TCL_OBJ_CMD(CreateShortcutObjCmd);
#define WINTCL_CSIDL_VAR "::win32::CSIDL"
int WintclpInitCSIDL(Tcl_Interp *interp);

/*
 * Functions in winEventLog.c
 */

TCL_OBJ_CMD(EventLogObjCmd);

/*
 * Functions in wintclico.c
 */
TCL_OBJ_CMD(Wintcl_IcoObjCmd);
TCL_OBJ_CMD(Wintcl_TaskbarObjCmd);

void WintclpIcoDestroyCmd _ANSI_ARGS_((ClientData clientData));

/*
 * Functions in winSendMessage.c
 */
TCL_OBJ_CMD(SendMessageObjCmd);

/*
 * Functions in winSvc.c
 */
EXTERN int	Win32Svc_Init _ANSI_ARGS_((Tcl_Interp * interp));

/*
 * Extra Windows commands.
 */

EXTERN int	Win_Init _ANSI_ARGS_((Tcl_Interp * interp));
EXTERN int	Win32_Init _ANSI_ARGS_((Tcl_Interp * interp));

#endif /* WINTCL_H */
