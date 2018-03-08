/*
 * Copyright (c) 2003-2006 ActiveState Software Inc.
 *
 * Implements Tcl Services under Windows NT.
 *
 */

#include "wintcl.h"

#include <process.h>

static Cmd_Struct g_Controls[] = {
    "continue",		SERVICE_CONTROL_CONTINUE,
    "interrogate",	SERVICE_CONTROL_INTERROGATE,
    "pause",		SERVICE_CONTROL_PAUSE,
    "stop",		SERVICE_CONTROL_STOP,
    (char *) NULL, 0,
};

static Cmd_Struct g_States[] = {
    "continuepending",	SERVICE_CONTINUE_PENDING,
    "pausepending",	SERVICE_PAUSE_PENDING,
    "paused",		SERVICE_PAUSED,
    "running",		SERVICE_RUNNING,
    "startpending",	SERVICE_START_PENDING,
    "stoppending",	SERVICE_STOP_PENDING,
    "stopped",		SERVICE_STOPPED,
    "SERVICE_CONTINUE_PENDING",	SERVICE_CONTINUE_PENDING,
    "SERVICE_PAUSE_PENDING",	SERVICE_PAUSE_PENDING,
    "SERVICE_PAUSED",		SERVICE_PAUSED,
    "SERVICE_RUNNING",		SERVICE_RUNNING,
    "SERVICE_START_PENDING",	SERVICE_START_PENDING,
    "SERVICE_STOP_PENDING",	SERVICE_STOP_PENDING,
    "SERVICE_STOPPED",		SERVICE_STOPPED,
    (char *) NULL, 0,
};

static Cmd_Struct g_ErrorControls[] = {
    "ignore",	SERVICE_ERROR_IGNORE,
    "normal",	SERVICE_ERROR_NORMAL,
    "severe",	SERVICE_ERROR_SEVERE,
    "critical",	SERVICE_ERROR_CRITICAL,
    "SERVICE_ERROR_IGNORE",	SERVICE_ERROR_IGNORE,
    "SERVICE_ERROR_NORMAL",	SERVICE_ERROR_NORMAL,
    "SERVICE_ERROR_SEVERE",	SERVICE_ERROR_SEVERE,
    "SERVICE_ERROR_CRITICAL",	SERVICE_ERROR_CRITICAL,
    (char *) NULL, 0,
};

static Cmd_Struct g_StartTypes[] = {
    "automatic",	SERVICE_AUTO_START,
    "boot",		SERVICE_BOOT_START,
    "manual",		SERVICE_DEMAND_START,
    "disabled",		SERVICE_DISABLED,
    "system",		SERVICE_SYSTEM_START,
    "SERVICE_AUTO_START",	SERVICE_AUTO_START,
    "SERVICE_BOOT_START",	SERVICE_BOOT_START,
    "SERVICE_DEMAND_START",	SERVICE_DEMAND_START,
    "SERVICE_DISABLED",		SERVICE_DISABLED,
    "SERVICE_SYSTEM_START",	SERVICE_SYSTEM_START,
    (char *) NULL, 0,
};

static Cmd_Struct g_ServiceTypes[] = {
    "SERVICE_FILE_SYSTEM_DRIVER",	SERVICE_FILE_SYSTEM_DRIVER,
    "SERVICE_KERNEL_DRIVER",		SERVICE_KERNEL_DRIVER,
    "SERVICE_WIN32_OWN_PROCESS",	SERVICE_WIN32_OWN_PROCESS,
    "SERVICE_WIN32_SHARE_PROCESS",	SERVICE_WIN32_SHARE_PROCESS,
    "SERVICE_INTERACTIVE_PROCESS",	SERVICE_WIN32_OWN_PROCESS|SERVICE_INTERACTIVE_PROCESS,
    (char *) NULL, 0,
};

SC_HANDLE g_Manager  = NULL;

void svc_Cleanup(ClientData clientData)
{
    if (g_Manager) {
	CloseServiceHandle(g_Manager);
	g_Manager = NULL;
    }
}

int svc_InitSCManager(Tcl_Interp *interp)
{
    static initialized = 0;

    if (!initialized) {
	initialized = 1;
	g_Manager = OpenSCManager(NULL, NULL, SC_MANAGER_ALL_ACCESS);
	if (g_Manager) {
	    Tcl_CreateThreadExitHandler((Tcl_ExitProc *) svc_Cleanup, NULL);
	}
    }

    if (!g_Manager) {
	Cmd_AppendSystemError(interp, GetLastError());
	return TCL_ERROR;
    }
    return TCL_OK;
}

void svc_ServiceCmdDeleted(ClientData clientData)
{
    SC_HANDLE service = (SC_HANDLE) clientData;
    CloseServiceHandle(service);
}

#define SVC_SET 1
#define SVC_GET 0

static int
svc_Description(Tcl_Interp *interp, SC_HANDLE service,
	TCHAR *dispName, int doSet, ClientData clientData)
{
    HKEY hKey;
    Tcl_DString ds;
    int needed, code = 0;

    /*
     * Set / Get description via the registry
     */

    code = GetServiceKeyName(g_Manager, dispName, NULL, &needed);
    if (code == 0 && GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
	Tcl_DString dsName;

	Tcl_DStringInit(&dsName);
	Tcl_DStringSetLength(&dsName, needed*sizeof(TCHAR) + 1);
	code = GetServiceKeyName(g_Manager, dispName,
		Tcl_DStringValue(&dsName), &needed);
	if (code) {
	    Tcl_DStringInit(&ds);
	    Tcl_DStringAppend(&ds,
		    "System\\CurrentControlSet\\Services\\", -1);
	    Tcl_DStringAppend(&ds, Tcl_DStringValue(&dsName), -1);
	}
	Tcl_DStringFree(&dsName);
    }
    if (code == 0) {
	if (interp) {
	    Tcl_AppendResult(interp, "GetServiceKeyName failed for \"",
		    dispName, "\"", NULL);
	}
	return TCL_ERROR;
    }

    if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, Tcl_DStringValue(&ds), 0,
		(doSet ? KEY_SET_VALUE : KEY_QUERY_VALUE), &hKey)
	    == ERROR_SUCCESS) {
	/*
	 * FIX: Convert UTF8 to TCHAR
	 */
	if (doSet) {
	    char *desc = (char *) clientData;
	    RegSetValueEx(hKey, "Description", 0, REG_SZ,
		    (BYTE*) desc, strlen(desc));
	} else {
	    LONG needed;
	    Tcl_DString *dsPtr = (Tcl_DString *) clientData;

	    Tcl_DStringInit(dsPtr);
	    if (RegQueryValueEx(hKey, "Description", NULL, NULL, NULL, &needed)
		    == ERROR_SUCCESS) {
		Tcl_DStringSetLength(dsPtr, needed + 1);
		RegQueryValueEx(hKey, "Description", NULL, NULL,
			(LPTSTR) Tcl_DStringValue(dsPtr), &needed);
	    }
	}
	RegCloseKey(hKey);
    } else {
	if (interp) {
	    Tcl_AppendResult(interp, "RegOpenKeyEx failed for \"",
		    Tcl_DStringValue(&ds), "\"", NULL);
	}
	Tcl_DStringFree(&ds);
	return TCL_ERROR;
    }

    Tcl_DStringFree(&ds);
    return TCL_OK;
}

TCL_OBJ_CMD(svc_ServiceObjCmd)
{
    SC_HANDLE service = (SC_HANDLE) clientData;
    int index, code = TCL_OK;
    static CONST char *options[] = {
	"close", "control",	"configure",	"delete",	"start",
	(char *) NULL
    };
    enum options {
	svc_CLOSE, svc_CONTROL,	svc_CONFIG,	svc_DELETE,	svc_START,
    };
    static CONST char *confOptions[] = {
	"-binarypathname",	"-description",	"-displayname",	"-errorcontrol",
	"-servicetype",		"-starttype",	"-username",	(char *) NULL
    };
    enum confOptions {
	svc_C_PATH,	svc_C_DESC,	svc_C_DISP,	svc_C_ERROR,
	svc_C_SERVICE,	svc_C_START,	svc_C_USER, svc_C_LAST
    };

    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "option arg ?arg ...?");
	return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj(interp, objv[1], options, "option", 0,
	    &index) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_Preserve(interp);
    switch ((enum options) index) {
	case svc_CLOSE: {
	    if (objc != 2) {
		Tcl_WrongNumArgs(interp, 2, objv, NULL);
		goto error;
	    }

	    if (CloseServiceHandle(service) == 0) {
		Cmd_AppendSystemError(interp, GetLastError());
	    }
	    /*
	     * We are deleting ourself
	     */
	    code = Tcl_DeleteCommand(interp, Tcl_GetString(objv[0]));
	    break;
	}
	case svc_CONTROL: {
	    DWORD request;
	    SERVICE_STATUS status;
	    BOOL success;

	    if ((objc != 2) && (objc != 3)) {
		Tcl_WrongNumArgs(interp, 2, objv, "?request?");
		goto error;
	    }

	    if (objc == 3) {
		if (Tcl_GetIntFromObj(NULL, objv[2], (int*)&request)
			    != TCL_OK) {
		    char *str = Tcl_GetString(objv[2]);
		    if (Cmd_GetValue(NULL, g_Controls, str, &request)
			    != TCL_OK) {
			Cmd_GetError(interp, g_Controls, str);
			Tcl_AppendResult(interp,
				" or an integer from 128 to 255",
				(char *) NULL);
			goto error;
		    }
		}

		success = ControlService(service, request, &status);
	    } else {
		success = QueryServiceStatus(service, &status);
	    }
	    if (success == 0) {
		Cmd_AppendSystemError(interp, GetLastError());
		goto error;
	    }
	    Tcl_AppendResult(interp,
		    Cmd_GetName(g_States, status.dwCurrentState),
		    (char *) NULL);
	    break;
	}
	case svc_CONFIG: {
	    DWORD needed;
	    char *str, *buffer = NULL;
	    QUERY_SERVICE_CONFIG *qsc = NULL;

	    if ((objc < 2) || ((objc > 3) && (objc & 1))) {
		Tcl_WrongNumArgs(interp, 2, objv, "?option ?value? ...?");
		goto error;
	    }

	    QueryServiceConfig(service, NULL, 0, &needed);
	    if (GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
		buffer = (char *) ckalloc((int)(needed*sizeof(TCHAR)) + 1);
		qsc = (QUERY_SERVICE_CONFIG *) buffer;
		if (!QueryServiceConfig(service, qsc, needed, &needed)) {
		    ckfree(buffer);
		    buffer = NULL;
		}
	    }

	    if (buffer == NULL) {
		Cmd_AppendSystemError(interp, GetLastError());
		goto error;
	    }

	    if (objc == 2) {
		Tcl_Obj *objPtr = Tcl_NewObj();
		for (needed = 0; needed < svc_C_LAST; needed++) {
		    Tcl_ListObjAppendElement(NULL, objPtr,
			    Tcl_NewStringObj(confOptions[needed], -1));
		    index = needed;
		    goto getName;
		    appendElem:
		    Tcl_ListObjAppendElement(NULL, objPtr,
			    Tcl_NewStringObj(str, -1));
		}
		Tcl_SetObjResult(interp, objPtr);
		/* Output all options */
	    } else if (objc == 3) {
		Tcl_DString ds;

		needed = svc_C_LAST;
		/* Get value of one option */
		if (Tcl_GetIndexFromObj(interp, objv[2], confOptions,
			    "option", 0, &index) != TCL_OK) {
		    ckfree(buffer);
		    goto error;
		}
		getName:
		switch ((enum confOptions) index) {
		    case svc_C_PATH:
			str = qsc->lpBinaryPathName;
			break;
		    case svc_C_DESC:
			Tcl_DStringInit(&ds);
			if (svc_Description(NULL, service, qsc->lpDisplayName,
				    SVC_GET, (ClientData) &ds) == TCL_OK) {
			    str = Tcl_DStringValue(&ds);
			} else {
			    str = "";
			}
			break;
		    case svc_C_DISP:
			str = qsc->lpDisplayName;
			break;
		    case svc_C_ERROR:
			str = Cmd_GetName(g_ErrorControls,qsc->dwErrorControl);
			break;
		    case svc_C_SERVICE:
			str = Cmd_GetName(g_ServiceTypes, qsc->dwServiceType);
			break;
		    case svc_C_START:
			str = Cmd_GetName(g_StartTypes, qsc->dwStartType);
			break;
		    case svc_C_USER:
			str = qsc->lpServiceStartName;
			break;
		}
		if (!str) str = "";
		if (needed != svc_C_LAST) goto appendElem;
		Tcl_SetObjResult(interp, Tcl_NewStringObj(str, -1));
		if ((enum confOptions) index == svc_C_DESC) {
		    Tcl_DStringFree(&ds);
		}
	    } else {
		char *lpServiceName    = NULL;
		char *lpDescription    = NULL;
		char *lpDisplayName    = NULL;
		char *lpBinaryPathName = NULL;
		char *lpUsername       = NULL;
		int i;

		DWORD dwServiceType    = SERVICE_NO_CHANGE;
		DWORD dwStartType      = SERVICE_NO_CHANGE;
		DWORD dwErrorControl   = SERVICE_NO_CHANGE;
		for (i = 2; i < objc-1 && code == TCL_OK; i += 2) {
		    if (Tcl_GetIndexFromObj(interp, objv[i], confOptions,
				"option", 0, &index) != TCL_OK) {
			code = TCL_ERROR;
			break;
		    }
		    switch ((enum confOptions) index) {
			case svc_C_PATH:
			    lpBinaryPathName = Tcl_GetString(objv[i+1]);
			    break;
			case svc_C_DESC:
			    lpDescription    = Tcl_GetString(objv[i+1]);
			    break;
			case svc_C_DISP:
			    lpDisplayName    = Tcl_GetString(objv[i+1]);
			    break;
			case svc_C_ERROR:
			    str  = Tcl_GetString(objv[i+1]);
			    code = Cmd_GetValue(interp, g_ErrorControls, str,
				    &dwErrorControl);
			    break;
			case svc_C_SERVICE:
			    str  = Tcl_GetString(objv[i+1]);
			    code = Cmd_GetValue(interp, g_ServiceTypes, str,
				    &dwServiceType);
			    break;
			case svc_C_START:
			    str  = Tcl_GetString(objv[i+1]);
			    code = Cmd_GetValue(interp, g_StartTypes, str,
				    &dwStartType);
			    break;
			case svc_C_USER:
			    lpUsername = Tcl_GetString(objv[i+1]);
			    break;
		    }
		}
		if (code == TCL_OK) {
		    if (ChangeServiceConfig(service,
				dwServiceType,
				dwStartType,
				dwErrorControl,
				lpBinaryPathName,
				NULL, /* lpLoadOrderGroup */
				NULL, /* lpdwTagId */
				NULL, /* lpDependencies */
				lpUsername,
				NULL, /* lpPassword */
				lpDisplayName) == 0) {
			Cmd_AppendSystemError(interp, GetLastError());
			code = TCL_ERROR;
		    } else if (lpDescription != NULL) {
			if (lpDisplayName == NULL) {
			    lpDisplayName = qsc->lpDisplayName;
			}
			code = svc_Description(interp, service, lpDisplayName,
				SVC_SET, (ClientData) lpDescription);
		    }
		}
	    }

	    ckfree(buffer);
	    break;
	}
	case svc_DELETE: {
	    SERVICE_STATUS status;
	    int count = 10, timeout = 1000;

	    if (objc > 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "?timeout?");
		goto error;
	    }

	    if ((objc == 3) && (Tcl_GetIntFromObj(interp, objv[2], &timeout)
			!= TCL_OK)) {
		goto error;
	    }

	    if (timeout > 0) {
		/*
		 * First attempt to stop the service
		 */
		if (QueryServiceStatus(service, &status) == 0) {
		    Cmd_AppendSystemError(interp, GetLastError());
		    goto error;
		} else if (status.dwCurrentState != SERVICE_STOPPED) {
		    if (ControlService(service, SERVICE_CONTROL_STOP,
				&status)) {
			Tcl_Sleep(timeout / 10);
			while (count--
				&& QueryServiceStatus(service, &status)) {
			    if (status.dwCurrentState !=SERVICE_STOP_PENDING) {
				break;
			    }
			    Tcl_Sleep(timeout / 10); // 10th of timeout
			}
		    }

		    if (status.dwCurrentState != SERVICE_STOPPED) {
			Tcl_AppendResult(interp, "unable to stop service",
				NULL);
			goto error;
		    }
		}
	    }

	    if (DeleteService(service) == 0) {
		Cmd_AppendSystemError(interp, GetLastError());
		goto error;
	    } else {
		/*
		 * We are deleting ourself
		 */
		CloseServiceHandle(service);
		code = Tcl_DeleteCommand(interp, Tcl_GetString(objv[0]));
	    }
	    break;
	}
	case svc_START: {
	    if (objc != 2) {
		Tcl_WrongNumArgs(interp, 2, objv, NULL);
		goto error;
	    }

	    if (StartService(service, 0, NULL) == 0) {
		Cmd_AppendSystemError(interp, GetLastError());
		goto error;
	    }
	    break;
	}
    }

    Tcl_Release(interp);
    return code;

    error:
    Tcl_Release(interp);
    return TCL_ERROR;
}

TCL_OBJ_CMD(svc_CreateService)
{
    SC_HANDLE service;
    Tcl_Obj *cmdObjPtr;
    char *str;
    char *lpServiceName     = NULL;
    char *lpDescription     = NULL;
    char *lpDisplayName     = NULL;
    char *lpBinaryPathName  = NULL;
    char *lpUsername        = NULL;
    char *lpPassword        = NULL;
    int index, i, boolVal = 0;

    DWORD dwServiceType    = SERVICE_WIN32_OWN_PROCESS;
    DWORD dwStartType      = SERVICE_DEMAND_START;
    DWORD dwErrorControl   = SERVICE_ERROR_NORMAL;

    static CONST char *options[] = {
	"-command",	"-description",	"-displayname",	"-errorcontrol",
	"-interactive",	"-pathname",	"-password",	"-starttype",
	"-username",	(char *) NULL
    };
    enum options {
	svc_O_COMMAND,	svc_O_DESC,	svc_O_DISP,	svc_O_ERROR,
	svc_O_INTER,	svc_O_PATH,	svc_O_PASSWD,	svc_O_START,
	svc_O_USER,
    };

    if ((objc < 2) || (objc & 1)) {
	Tcl_WrongNumArgs(interp, 1, objv, "serviceName ?option value ...?");
	return TCL_ERROR;
    }

    if (svc_InitSCManager(interp) != TCL_OK) {
	return TCL_ERROR;
    }
    lpServiceName = Tcl_GetString(objv[1]);
    lpDisplayName = lpServiceName;
    cmdObjPtr     = objv[1];
    for (i = 2; i < objc; i += 2) {
	if (Tcl_GetIndexFromObj(interp, objv[i], options, "switch", 0,
		&index) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch ((enum options) index) {
	    case svc_O_COMMAND:
		cmdObjPtr        = objv[i+1];
		break;
	    case svc_O_DESC:
		lpDescription    = Tcl_GetString(objv[i+1]);
		break;
	    case svc_O_DISP:
		lpDisplayName    = Tcl_GetString(objv[i+1]);
		break;
	    case svc_O_ERROR:
		str = Tcl_GetString(objv[i+1]);
		if (Cmd_GetValue(interp, g_ErrorControls, str,
			    &dwErrorControl) != TCL_OK) {
		    return TCL_ERROR;
		}
 		break;
	    case svc_O_INTER:
		if (Tcl_GetBooleanFromObj(interp, objv[i+1], &boolVal)
			!= TCL_OK) {
		    return TCL_ERROR;
		}
		if (boolVal) {
		    dwServiceType |= SERVICE_INTERACTIVE_PROCESS;
		} else {
		    dwServiceType &= ~SERVICE_INTERACTIVE_PROCESS;
		}
		break;
	    case svc_O_PATH:
		lpBinaryPathName = Tcl_GetString(objv[i+1]);
		break;
	    case svc_O_PASSWD:
		lpPassword       = Tcl_GetString(objv[i+1]);
		break;
	    case svc_O_START:
		str = Tcl_GetString(objv[i+1]);
		if (Cmd_GetValue(interp, g_StartTypes, str,
			    &dwStartType) != TCL_OK) {
		    return TCL_ERROR;
		}
 		break;
	    case svc_O_USER:
		lpUsername = Tcl_GetString(objv[i+1]);
		break;
	}
    }

    service = CreateService(g_Manager,
	    lpServiceName,
	    lpDisplayName,
	    SERVICE_ALL_ACCESS,
	    dwServiceType,
	    dwStartType,
	    dwErrorControl,
	    lpBinaryPathName,
	    NULL,
	    NULL,
	    NULL,
	    lpUsername,
	    lpPassword);

    svc_Description(interp, service, lpDisplayName, SVC_SET,
	    (ClientData) lpDescription);

    if (!service) {
	Cmd_AppendSystemError(interp, GetLastError());
	return TCL_ERROR;
    }

    Tcl_CreateObjCommand(interp, Tcl_GetString(cmdObjPtr), svc_ServiceObjCmd,
	    (ClientData) service,
	    (Tcl_CmdDeleteProc *) svc_ServiceCmdDeleted);
    Tcl_SetObjResult(interp, cmdObjPtr);
    return TCL_OK;
}

TCL_OBJ_CMD(svc_OpenService)
{
    SC_HANDLE service;
    Tcl_Obj *cmdObjPtr;
    char *lpServiceName;

    if ((objc < 2) || (objc > 3)) {
	Tcl_WrongNumArgs(interp, 1, objv, "serviceName ?commandName?");
	return TCL_ERROR;
    }

    if (svc_InitSCManager(interp) != TCL_OK) {
	return TCL_ERROR;
    }
    lpServiceName = Tcl_GetString(objv[1]);

    service = OpenService(g_Manager, lpServiceName, SERVICE_ALL_ACCESS);

    if (!service) {
	Cmd_AppendSystemError(interp, GetLastError());
	return TCL_ERROR;
    }

    cmdObjPtr = objv[objc-1];
    Tcl_CreateObjCommand(interp, Tcl_GetString(cmdObjPtr), svc_ServiceObjCmd,
	    (ClientData) service,
	    (Tcl_CmdDeleteProc *) svc_ServiceCmdDeleted);
    Tcl_SetObjResult(interp, cmdObjPtr);
    return TCL_OK;
}

EXTERN int
Win32Svc_Init(Tcl_Interp *interp)
{
    OSVERSIONINFO os;

    os.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
    GetVersionEx(&os);
    if (os.dwPlatformId != VER_PLATFORM_WIN32_NT) {
	/*
	 * None of those old, cranky variants for us.
	 */
	return TCL_OK;
    }

    if (Tcl_InitStubs(interp, "8.4", 0) == NULL) {
	return TCL_ERROR;
    }
    if (Tcl_PkgRequire(interp, "Tcl", "8.4", 0) == NULL) {
	return TCL_ERROR;
    }

    if (Tcl_PkgProvide(interp, "win32::svc", PACKAGE_VERSION) != TCL_OK) {
	return TCL_ERROR;
    }

    Tcl_CreateObjCommand(interp, "win32::svc::OpenService",
	    svc_OpenService, (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);

    Tcl_CreateObjCommand(interp, "win32::svc::CreateService",
	    svc_CreateService, (ClientData) NULL, (Tcl_CmdDeleteProc *) NULL);

    return TCL_OK;
}


/*
***********************************************************************
***********************************************************************
***********************************************************************
***********************************************************************
*/
#if 0

#if 0
static SERVICE_STATUS           g_Status;
static SERVICE_STATUS_HANDLE    g_StatusHandle = NULL;
static char                    *g_ServiceName  = NULL;
static HANDLE                   g_EventLog     = NULL;
static BOOL                     g_Warn         = FALSE;
static HANDLE                   g_Event        = NULL;
#endif

void
EventLog(char *msg, int error=0)
{
    if (!g_EventLog)
        return;

    int count = 0;
    char *strings[2];

    char err[256];
    if (error) {
        sprintf(err, "%s error: %d\n", g_ServiceName? g_ServiceName : "(null)", error);
        strings[count++] = err;
        if (g_Warn)
            warn(err);
    }
    strings[count++] = msg;
    if (g_Warn)
        warn(msg);

    ReportEvent(g_EventLog, EVENTLOG_ERROR_TYPE, 0, 0, NULL,
                count, 0, (const char**)strings, NULL);
}


BOOL
ReportStatus(DWORD dwCurrentState, DWORD dwWaitHint)
{
    static DWORD dwCheckPoint = 1;

    g_Status.dwCurrentState = dwCurrentState;
    g_Status.dwWaitHint = dwWaitHint;

    if ((dwCurrentState == SERVICE_RUNNING) || (dwCurrentState == SERVICE_STOPPED))
	g_Status.dwCheckPoint = 0;
    else
	g_Status.dwCheckPoint = dwCheckPoint++;

    if (!SetServiceStatus(g_StatusHandle, &g_Status)) {
	EventLog("SetServiceStatus", GetLastError());
        return FALSE;
    }

    return TRUE;
}


void WINAPI
CtrlHandler(DWORD dwControl)
{
    switch (dwControl) {
    case SERVICE_CONTROL_STOP:
    case SERVICE_CONTROL_SHUTDOWN:
        g_Status.dwCurrentState = SERVICE_STOP_PENDING;
        break;
    case SERVICE_CONTROL_PAUSE:
        g_Status.dwCurrentState = SERVICE_PAUSE_PENDING;
        break;
    case SERVICE_CONTROL_CONTINUE:
        g_Status.dwCurrentState = SERVICE_CONTINUE_PENDING;
        break;
    default:
        ReportStatus(g_Status.dwCurrentState, 0);
        return;
    }
    ReportStatus(g_Status.dwCurrentState, 0);
    SetEvent(g_Event);
}

XS(XS_ReportStatus)
{
    DWORD dwWaitHint = 0;
    dXSARGS;
    if (items < 1)
        croak("usage: ReportStatus(STATE[, WAITHINT])");
    if (items == 2)
        dwWaitHint = (DWORD)(SvNV(ST(1))*1000);
    ReportStatus(SvIV(ST(0)), dwWaitHint);
    XSRETURN_EMPTY;
}

int
PerlSvcMain(int argc, char **argv)
{
    int i;
    char **new_argv;
    CV *cv;
    int exitstatus = 0;

    g_EventLog = RegisterEventSource(NULL, "Application");

    if (paperl_init())
        return 1;

    new_argv = (char**)malloc((argc+2)*sizeof(char*));
    if (!new_argv) {
        fprintf(stderr, "Panic: Cannot reallocate argv");
        return 1;
    }

    new_argv[0] = argv[0];
    new_argv[1] = "--";
    for (i=1; i<argc; ++i)
        new_argv[i+1] = argv[i];

    try {
        void *paperl = NULL;
        int exitstatus = paperl_create(&paperl, NULL, NULL, NULL,
                                       argc+1, new_argv, xsinit, 0);

        if (paperl) {
            PerlInterpreter *my_perl = paperl_get_perl(paperl);
            PerlInterpreter *old_perl = (PerlInterpreter*)Perl_get_context();
            Perl_set_context(my_perl);

            dSP;
            dJMPENV;
            int ret;

            SV *sv = get_sv("PerlSvc::_action", TRUE);
            if (SvTRUE(sv)) {
                JMPENV_PUSH(ret);
                if (ret == 0) {
                    ENTER;
                    SAVETMPS;
                    PUSHMARK(SP);
                    perl_call_sv(sv, G_EVAL|G_DISCARD);
                    FREETMPS;
                    LEAVE;
                    if (SvTRUE(ERRSV))
                        EventLog(SvPV_nolen(ERRSV), 0);
                }
                JMPENV_POP;
            }

            // Run END blocks
            if (PL_endav) {
                JMPENV_PUSH(ret);
                if (ret == 0) {
                    PL_curstash = PL_defstash;
                    call_list(PL_scopestack_ix, PL_endav);
                }
                JMPENV_POP;
            }

            Perl_set_context(old_perl);

            paperl_destruct(paperl);
        }
        paperl_cleanup();
    }
    catch (...) {
        EventLog("Perl interpreter failed", 0);
        return 1;
    }

    DeregisterEventSource(g_EventLog);

    return exitstatus;
}

void
ServiceMain(int argc, char *argv[])
{
    g_ServiceName = strdup(argv[0]);

    g_Event = CreateEvent(NULL, TRUE, FALSE, NULL);

    g_StatusHandle = RegisterServiceCtrlHandler(g_ServiceName, CtrlHandler);
    if (!g_StatusHandle)
        return;

    g_Status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    g_Status.dwWin32ExitCode = NO_ERROR;
    g_Status.dwServiceSpecificExitCode = 0;
    g_Status.dwControlsAccepted = SERVICE_ACCEPT_STOP | SERVICE_ACCEPT_SHUTDOWN
                                | SERVICE_ACCEPT_PAUSE_CONTINUE;

    if (ReportStatus(SERVICE_START_PENDING, 3000)) {
        PerlSvcMain(argc, argv);
        ReportStatus(SERVICE_STOPPED, 0);
    }

    CloseHandle(g_Event);
}

int
main(int argc, char **argv, char **env)
{
    SERVICE_TABLE_ENTRY dispatchTable[] = {
        { "", (LPSERVICE_MAIN_FUNCTION)ServiceMain },
        { NULL, NULL }
    };

    // Only call StartServiceCtrlDispatcher() when it is likely that
    // we are running as a service.  It is really slow to fail when
    // running as a normal console application.
    if (GetStdHandle(STD_INPUT_HANDLE) == NULL &&
        // Startup service thread
        StartServiceCtrlDispatcher(dispatchTable))
    {
        return 0;
    }

    // or run as a commandline up instead (for -install/-remove/-help)
    g_Warn = TRUE;
    return PerlSvcMain(argc, argv);
}
#endif
