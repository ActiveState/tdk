/*
 * winUtils.c
 *
 *
 * $Id: winUtils.c,v 1.2 2002/04/04 06:13:21 hobbs Exp $
 */

#include "wintcl.h"


/*
 * simple Cmd_Struct lookup functions
 */

char *
Cmd_GetName(const Cmd_Struct *cmds, long val)
{
    for(;cmds->name && cmds->name[0];cmds++) {
	if (cmds->value == val) {
	    return cmds->name;
	}
    }
    return NULL;
}

int
Cmd_GetValue(Tcl_Interp *interp, const Cmd_Struct *cmds,
	const char *arg, long *value)
{
    size_t len = strlen(arg);
    for(;cmds->name && cmds->name[0];cmds++) {
	if ((arg[0] == cmds->name[0])
		&& (strncmp(cmds->name, arg, len) == 0)) {
	    if (value) {
		*value = cmds->value;
	    }
	    return TCL_OK;
	}
    }
    if (interp) {
	Cmd_GetError(interp, cmds, arg);
    }
    return TCL_ERROR;
}

void
Cmd_GetError(Tcl_Interp *interp, const Cmd_Struct *cmds, const char *arg)
{
    int i;
    Tcl_AppendResult(interp, "bad option \"", arg, "\" must be ", (char *) 0);
    for(i=0;cmds->name && cmds->name[0];cmds++,i++) {
	Tcl_AppendResult(interp, (i?", ":""), cmds->name, (char *) 0);
    }
}

/*
 * Try to get a valid window handle from a Tk-pathname for a toplevel
 */
Tk_Window
Cmd_WinNameOrHandle(Tcl_Interp *interp, Tcl_Obj *objPtr, HWND *hwndPtr,
	int requireToplevel)
{
    Tk_Window tkwin;

    if (Tk_InitStubs(interp, "8.1", 0) == NULL) {
	return NULL;
    }

    if (Tcl_GetIntFromObj(NULL, objPtr, (int*) hwndPtr) == TCL_OK) {
	return Tk_HWNDToWindow(*hwndPtr);
    }

    tkwin = Tk_NameToWindow(interp, Tcl_GetString(objPtr),
	    Tk_MainWindow(interp));
    if (tkwin == NULL) {
	return NULL;
    }
    if (requireToplevel && !Tk_IsTopLevel(tkwin)) {
	Tcl_AppendResult(interp, "\"", Tcl_GetString(objPtr),
		"\" is not a valid toplevel window", (char*) NULL);
	return NULL;
    }
    Tk_MakeWindowExist(tkwin);
    *hwndPtr = Tk_GetHWND(Tk_WindowId(tkwin));
    if (*hwndPtr == NULL) {
	Tcl_AppendResult(interp, "could not get window id of \"",
		Tcl_GetString(objPtr), "\"", (char*)NULL);
	return NULL;
    }
    return tkwin;
}

/*
 *----------------------------------------------------------------------
 *
 * Cmd_AppendSystemMessage --
 *
 *	This routine formats a Windows system error message and places
 *	it into the interpreter result.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
Cmd_FormatMessage(
    Tcl_Interp *interp,		/* Current interpreter. */
    DWORD error,		/* Result code from error. */
    Tcl_DString *dsPtr)
{
    int length;
    WCHAR *wMsgPtr;

    Tcl_DStringInit(dsPtr);
    length = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM
	    | FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, error,
	    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (WCHAR *) &wMsgPtr,
	    0, NULL);
    if (length == 0) {
	char *msgPtr;

	length = FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM
		| FORMAT_MESSAGE_ALLOCATE_BUFFER, NULL, error,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (char *) &msgPtr,
		0, NULL);
	if (length > 0) {
	    wMsgPtr = (WCHAR *) LocalAlloc(LPTR, (length + 1) * sizeof(WCHAR));
	    MultiByteToWideChar(CP_ACP, 0, msgPtr, length + 1, wMsgPtr,
		    length + 1);
	    LocalFree(msgPtr);
	}
    }
    if (length == 0) {
	char msgBuf[24 + TCL_INTEGER_SPACE];

	sprintf(msgBuf, "unknown error: %ld", error);
	Tcl_DStringAppend(dsPtr, msgBuf, -1);
    } else {
	Tcl_Encoding encoding;
	char *msg;

	encoding = Tcl_GetEncoding(NULL, "unicode");
	Tcl_ExternalToUtfDString(encoding, (char *) wMsgPtr, -1, dsPtr);
	Tcl_FreeEncoding(encoding);
	LocalFree(wMsgPtr);

	msg = Tcl_DStringValue(dsPtr);
	length = Tcl_DStringLength(dsPtr);

	/*
	 * Trim the trailing CR/LF from the system message.
	 */
	if (msg[length-1] == '\n') {
	    msg[--length] = 0;
	}
	if (msg[length-1] == '\r') {
	    msg[--length] = 0;
	}
	Tcl_DStringSetLength(dsPtr, length);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Cmd_AppendSystemError --
 *
 *	This routine formats a Windows system error message and places
 *	it into the interpreter result.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
Cmd_AppendSystemError(
    Tcl_Interp *interp,		/* Current interpreter. */
    DWORD error)		/* Result code from error. */
{
    char id[TCL_INTEGER_SPACE];
    Tcl_DString ds;
    Tcl_Obj *resultPtr = Tcl_GetObjResult(interp);

    Cmd_FormatMessage(interp, error, &ds);

    sprintf(id, "%ld", error);
    Tcl_SetErrorCode(interp, "WINDOWS", id, Tcl_DStringValue(&ds),
	    (char *) NULL);
    Tcl_AppendToObj(resultPtr, Tcl_DStringValue(&ds), Tcl_DStringLength(&ds));

    Tcl_DStringFree(&ds);
}
