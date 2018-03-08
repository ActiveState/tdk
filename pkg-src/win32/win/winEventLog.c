/*
 * Copyright (C) 2003-2006 ActiveState Software Inc.
 * Jeff Hobbs <jeffh@activestate.com>
 *
 * Adds command win32::eventlog
 */

#include "wintcl.h"

/*
 * External Functions
 */

TCL_OBJ_CMD(EventLogObjCmd)
{
    HANDLE  	hEventSource;
    WORD	wType       = EVENTLOG_INFORMATION_TYPE;
    WORD	wCategory   = 0;
    DWORD	dwEventID   = 1;
    LPCTSTR  	lpszStrings[1];
    char *	host   = NULL;
    char *	source = NULL;

    int		i, index, code = TCL_OK;

    static Cmd_Struct evTypes[] = {
	"success",		EVENTLOG_SUCCESS,
	"error",		EVENTLOG_ERROR_TYPE,
	"warning",		EVENTLOG_WARNING_TYPE,
	"information",		EVENTLOG_INFORMATION_TYPE,
	"audit_success",	EVENTLOG_AUDIT_SUCCESS,
	"audit_failure",	EVENTLOG_AUDIT_FAILURE,
	NULL,			0,
    };
    CONST84 char *options[] = {
	"-category", "-host", "-id", "-source", "-type", (char *) NULL
    };
    enum options {
	el_CATEGORY, el_HOST, el_ID, el_SOURCE, el_TYPE
    };

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "message ?options?");
	return TCL_ERROR;
    }

    for (i = 2; i < objc-1; i += 2) {
	if (Tcl_GetIndexFromObj(interp, objv[i], options, "switch", 0,
		&index) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch ((enum options) index) {
	    case el_CATEGORY:
		if (Tcl_GetIntFromObj(interp, objv[i+1], (int *)&wCategory)
			!= TCL_OK) {
		    return TCL_ERROR;
		}
		break;
	    case el_HOST:
		host = Tcl_GetString(objv[i+1]);
		break;
	    case el_ID:
		if (Tcl_GetLongFromObj(interp, objv[i+1], (long *)&dwEventID)
			!= TCL_OK) {
		    return TCL_ERROR;
		}
		break;
	    case el_SOURCE:
		source = Tcl_GetString(objv[i+1]);
		break;
	    case el_TYPE:
		if (Cmd_GetValue(interp, evTypes, Tcl_GetString(objv[i+1]),
			    (long *)&wType) != TCL_OK) {
		    return TCL_ERROR;
		}
		break;
	}
    }
    if (source == NULL || *source == '\0') {
	source = "Application";
    }
    hEventSource = RegisterEventSource(host, source);
    if (hEventSource == NULL) {
	Tcl_AppendResult(interp, "can't open eventlog for source \"",
		    source, "\"", (char*) NULL);
	if (host) {
	    Tcl_AppendResult(interp, " on host \"", host, "\"", (char*) NULL);
	}
	return TCL_ERROR;
    }

    lpszStrings[0] = Tcl_GetString(objv[1]);
    if (ReportEvent(hEventSource,	// handle of event source
		(WORD)wType,		// event type
		(WORD)wCategory,	// event category
		dwEventID,		// event ID
		NULL,		// current user's SID
		1,		// strings in lpszStrings
		0,		// no bytes of raw data
		lpszStrings,	// array of error strings
		NULL)	== 0) {	// no raw data
	Cmd_AppendSystemError(interp, GetLastError());
	code = TCL_ERROR;
    }

    (void) DeregisterEventSource(hEventSource);
    return code;
}
