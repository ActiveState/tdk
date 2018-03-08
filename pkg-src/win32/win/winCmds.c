/*
 * dbgext.c --
 *
 *	The file contains various C based commands used by the Tcl
 *	debugger.  In the future these types of commands may work
 *	themselves into the Tcl core.
 *
 * Copyright (c) 1998-2000 Ajuba Solutions
 *
 *  Copyright (c) 2018 ActiveState Software Inc.
 *  Released under the BSD-3 license. See LICENSE file for details.
 *
 * RCS: @(#) $Id: dbgext.c,v 1.3 2000/05/30 21:15:01 wart Exp $
 */

#include "wintcl.h"
#include <shellapi.h>
#include <shlobj.h>
#include <ole2.h>

typedef struct ThreadSpecificData {
    int initialized;		/* Set to 1 when the module is initialized. */
} ThreadSpecificData;

static Tcl_ThreadDataKey dataKey;

/*
 * Declarations for functions defined in this file.
 */

static void		FinalizeWinCmd(ClientData clientData);


/*
 *----------------------------------------------------------------------
 *
 * KillObjCmd --
 *
 *	This function will kill a process given a passed in PID.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	The specified process will die.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(KillObjCmd)
{
    HANDLE processHandle;
    int pid;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "pid");
	return TCL_ERROR;
    }

    if (Tcl_GetLongFromObj(interp, objv[1], &pid) != TCL_OK) {
	return TCL_ERROR;
    }

    processHandle = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
    if (processHandle == NULL) {
	Tcl_AppendResult(interp, "invalid pid \"",
		Tcl_GetString(objv[1]), "\"", (char *) NULL);
	return TCL_ERROR;
    }

    TerminateProcess(processHandle, 7);
    CloseHandle(processHandle);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * WinHelpObjCmd --
 *
 *	This function launch the WINHELP.EXE application and show help
 *	based on the information passed in.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	The WINHELP.EXE will be launched and/or change state.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(WinHelpObjCmd)
{
    char *string, *nativeName;
    Tcl_DString buffer, nativeStr;
    int result;
    unsigned long sectionNumber;

    if ((objc != 3) && (objc != 2)) {
	Tcl_WrongNumArgs(interp, 1, objv, "path ?section?");
	return TCL_ERROR;
    }

    /*
     * Get the file path to the help file.
     */
    
    string = Tcl_GetString(objv[2]);
    nativeName = Tcl_TranslateFileName(interp, string, &buffer);
    if (nativeName == NULL) {
	return TCL_ERROR;
    }
    nativeName = Tcl_UtfToExternalDString(NULL, nativeName, -1, &nativeStr);

    /*
     * Get the sub section if given.
     */

    if (objc == 4) {
	result = Tcl_GetLongFromObj(interp, objv[3], &sectionNumber);
	if (result != TCL_OK) {
	    result = TCL_ERROR;
	} else {
	    WinHelp(NULL, nativeName, HELP_CONTEXT, sectionNumber);
	}
    } else {
	WinHelp(NULL, nativeName, HELP_FINDER, 0);
	result = TCL_OK;
    }

    Tcl_DStringFree(&buffer);
    Tcl_DStringFree(&nativeStr);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * StartObjCmd --
 *
 *	Perform a ShellExecuteEx.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(StartObjCmd)
{
    SHELLEXECUTEINFO info;
    char *lpFileStr, *lpParmStr, *lpDirStr;
    Tcl_DString lpFileBuf, lpParmBuf, lpDirBuf;
    int code = TCL_OK;

    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "executable args startdir");
	return TCL_ERROR;
    }

    /*
     * Convert all of the UTF stirings to the native encoding
     * before passing off the arguments to the system.
     */
    
    lpFileStr = Tcl_UtfToExternalDString(NULL, Tcl_GetStringFromObj(objv[1],
	    NULL), -1, &lpFileBuf);
    lpParmStr = Tcl_UtfToExternalDString(NULL, Tcl_GetStringFromObj(objv[2],
	    NULL), -1, &lpParmBuf);
    lpDirStr  = Tcl_UtfToExternalDString(NULL, Tcl_GetStringFromObj(objv[3],
	    NULL), -1, &lpDirBuf);

    memset(&info, 0, sizeof(SHELLEXECUTEINFO));
    info.cbSize       = sizeof(SHELLEXECUTEINFO);
    info.fMask        = SEE_MASK_FLAG_NO_UI;
    info.hwnd         = NULL;
    info.lpVerb       = NULL;
    info.lpFile       = lpFileStr;
    info.lpParameters = lpParmStr;
    info.lpDirectory  = lpDirStr;
    info.nShow        = SW_SHOWNORMAL;
    info.hInstApp     = NULL;
    info.hProcess     = NULL;

    if (ShellExecuteEx(&info) == 0) {
	Cmd_AppendSystemError(interp, GetLastError());
	code = TCL_ERROR;
    }

    Tcl_DStringFree(&lpFileBuf);
    Tcl_DStringFree(&lpParmBuf);
    Tcl_DStringFree(&lpDirBuf);
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * GetFileVersion --
 *
 *	Get file version info.
 *	Could be extended to get all the FileDescription / ... info.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(GetFileVersionObjCmd)
{
    DWORD size;
    DWORD handle;
    char *data;
    char *lpFileStr;
    Tcl_DString lpFileBuf;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "executable");
	return TCL_ERROR;
    }

    /*
     * Convert all of the UTF strings to the native encoding
     * before passing off the arguments to the system.
     */
    lpFileStr = Tcl_UtfToExternalDString(NULL, Tcl_GetString(objv[1]),
	    -1, &lpFileBuf);
    size = GetFileVersionInfoSize(lpFileStr, &handle);
    if (!size) {
	Tcl_DStringFree(&lpFileBuf);
	return TCL_OK;
    }

    data = (char *) ckalloc(size);

    if (GetFileVersionInfo(lpFileStr, handle, size, data)) {
        VS_FIXEDFILEINFO *info;
        UINT len;
        if (VerQueryValue(data, "\\", (void**)&info, &len)) {
	    Tcl_Obj *objPtr = Tcl_NewObj();
	    Tcl_ListObjAppendElement(NULL, objPtr,
		    Tcl_NewIntObj((info->dwFileVersionMS>>16)));
	    Tcl_ListObjAppendElement(NULL, objPtr,
		    Tcl_NewIntObj((info->dwFileVersionMS&0xffff)));
	    Tcl_ListObjAppendElement(NULL, objPtr,
		    Tcl_NewIntObj((info->dwFileVersionLS>>16)));
	    Tcl_ListObjAppendElement(NULL, objPtr,
		    Tcl_NewIntObj((info->dwFileVersionLS&0xffff)));
	    Tcl_SetObjResult(interp, objPtr);
        }
    }

    ckfree(data);
    Tcl_DStringFree(&lpFileBuf);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * FormatMessage --
 *
 *	FormatMessage
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(FormatMessageObjCmd)
{
    Tcl_DString ds;
    DWORD code;

    if (objc > 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "?code?");
	return TCL_ERROR;
    }

    if (objc == 1) {
	code = GetLastError();
    } else if (Tcl_GetLongFromObj(interp, objv[1], (long *)&code) != TCL_OK) {
	return TCL_ERROR;
    }

    Cmd_FormatMessage(interp, code, &ds);
    Tcl_SetObjResult(interp,
	    Tcl_NewStringObj(Tcl_DStringValue(&ds), Tcl_DStringLength(&ds)));
    Tcl_DStringFree(&ds);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * GetLastError --
 *
 *	GetLastError
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(GetLastErrorObjCmd)
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewLongObj((long) GetLastError()));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * OutputDebugString --
 *
 *	
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(OutputDebugStringObjCmd)
{
    Tcl_DString ds;
    char *str;
    int len;

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "msg");
	return TCL_ERROR;
    }

    str = Tcl_GetStringFromObj(objv[1], &len);
    OutputDebugString(Tcl_WinUtfToTChar(str, len, &ds));
    Tcl_DStringFree(&ds);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DebugBreak --
 *
 *	
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(DebugBreakObjCmd)
{
    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

    DebugBreak();
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * GetSpecialFolderPath --
 *
 *	For more info on folder ids, see:
 *	http://msdn2.microsoft.com/en-us/library/bb762494(VS.85).aspx
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(GetSpecialFolderPathObjCmd)
{
    int folderId;
    WCHAR szPath[MAX_PATH];

    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "folderId");
	return TCL_ERROR;
    }

    /*
     * Allow user to specify folderId directly, or by name
     */
    if (Tcl_GetIntFromObj(NULL, objv[1], &folderId) != TCL_OK) {
	Tcl_Obj *objPtr = Tcl_GetVar2Ex(interp, WINTCL_CSIDL_VAR,
		Tcl_GetString(objv[1]), TCL_GLOBAL_ONLY);
	if ((objPtr == NULL)
		|| Tcl_GetIntFromObj(NULL, objPtr, &folderId) != TCL_OK) {
	    Tcl_ResetResult(interp);
	    Tcl_AppendResult(interp, "invalid folderId \"",
		    Tcl_GetString(objv[1]), "\"", NULL);
	    return TCL_ERROR;
	}
    }

    if (SHGetSpecialFolderPathW(NULL, szPath, folderId, 0) == FALSE) {
	Tcl_AppendResult(interp, "unable to get special folder path", NULL);
	return TCL_ERROR;
    }

    if (sizeof(WCHAR) != sizeof(Tcl_UniChar)) {
	Tcl_AppendResult(interp, "bad WCHAR size assumption", NULL);
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, Tcl_NewUnicodeObj(szPath, -1));

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Win32CreateShortcutA --
 *
 *	Create a Windows shell shortcut file (.lnk) (ascii variant).
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int Win32CreateShortcutA(
    Tcl_Interp *interp,		/* For use in error reporting, and to access
				 * the interp regexp cache. */
    Tcl_Obj *linkObjPtr,
    Tcl_Obj *targetObjPtr,
    Tcl_Obj *objArgs,
    Tcl_Obj *objDesc,
    Tcl_Obj *objDir,
    Tcl_Obj *objIpath,
    int iconIndex)
{
    char *str, *msg = NULL;
    int len;
    HRESULT hres;
    IShellLinkA* psl = NULL;
    IPersistFile* ppf = NULL;
    Tcl_Encoding uni;
    Tcl_DString pathds, ds;


    /* Get a pointer to the IShellLink interface. */
    hres = CoCreateInstance(&CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER,
	    &IID_IShellLinkA, (LPVOID*) &psl);
    if (FAILED(hres)) { msg = "CoCreateInstance"; goto shortcutError; }

    // targetPath
    str = Tcl_TranslateFileName(interp, Tcl_GetString(targetObjPtr), &pathds);
    str = Tcl_WinUtfToTChar(str, Tcl_DStringLength(&pathds), &ds);
    hres = psl->lpVtbl->SetPath(psl, (TCHAR *) str);
    Tcl_DStringFree(&pathds);
    Tcl_DStringFree(&ds);
    if (FAILED(hres)) { msg = "SetPath"; goto shortcutError; }

    if (objArgs) {
	str = Tcl_GetStringFromObj(objArgs, &len);
	hres = psl->lpVtbl->SetArguments(psl,
		Tcl_WinUtfToTChar(str, len, &ds));
	Tcl_DStringFree(&ds);
	if (FAILED(hres)) { msg = "SetArguments"; goto shortcutError; }
    }
    if (objDesc) {
	str = Tcl_GetStringFromObj(objDesc, &len);
	hres = psl->lpVtbl->SetDescription(psl,
		Tcl_WinUtfToTChar(str, len, &ds));
	Tcl_DStringFree(&ds);
	if (FAILED(hres)) { msg = "SetDescription"; goto shortcutError; }
    }
    if (objDir) {
	str = Tcl_TranslateFileName(interp, Tcl_GetString(objDir), &pathds);
	str = Tcl_WinUtfToTChar(str, Tcl_DStringLength(&pathds), &ds);
	hres = psl->lpVtbl->SetWorkingDirectory(psl, (TCHAR *) str);
	Tcl_DStringFree(&pathds);
	Tcl_DStringFree(&ds);
	if (FAILED(hres)) { msg = "SetWorkingDirectory"; goto shortcutError; }
    }
    if (objIpath) {
	str = Tcl_TranslateFileName(interp, Tcl_GetString(objIpath), &pathds);
	str = Tcl_WinUtfToTChar(str, Tcl_DStringLength(&pathds), &ds);
	hres = psl->lpVtbl->SetIconLocation(psl, (TCHAR *) str, iconIndex);
	Tcl_DStringFree(&pathds);
	Tcl_DStringFree(&ds);
	if (FAILED(hres)) { msg = "SetIconLocation"; goto shortcutError; }
    }

    hres = psl->lpVtbl->QueryInterface(psl, &IID_IPersistFile, (LPVOID*) &ppf);
    if (FAILED(hres)) { msg = "QueryInterface"; goto shortcutError; }

    /* Save the link - must be unicode still. */
    uni = Tcl_GetEncoding(interp, "unicode");
    str = Tcl_TranslateFileName(interp, Tcl_GetString(linkObjPtr), &pathds);
    str = Tcl_UtfToExternalDString(uni, str, Tcl_DStringLength(&pathds), &ds);
    hres = ppf->lpVtbl->Save(ppf, (WCHAR *) str, TRUE);
    msg = "Save";
    Tcl_FreeEncoding(uni);
    Tcl_DStringFree(&pathds);
    Tcl_DStringFree(&ds);
    ppf->lpVtbl->Release(ppf);

 shortcutError:
    if (psl) {
        psl->lpVtbl->Release(psl);
    }
    if (FAILED(hres)) {
	if (msg) {
	    char buf[128];

	    sprintf(buf, "failed in \"%s\" with code %d", msg, hres);
	    Tcl_AppendResult(interp, buf, NULL);
	}
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Win32CreateShortcutW --
 *
 *	Create a Windows shell shortcut file (.lnk).
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int Win32CreateShortcutW(
    Tcl_Interp *interp,		/* For use in error reporting, and to access
				 * the interp regexp cache. */
    Tcl_Obj *linkObjPtr,
    Tcl_Obj *targetObjPtr,
    Tcl_Obj *objArgs,
    Tcl_Obj *objDesc,
    Tcl_Obj *objDir,
    Tcl_Obj *objIpath,
    int iconIndex)
{
    char *str, *msg = NULL;
    int len;
    HRESULT hres;
    IShellLinkW* psl = NULL;
    IPersistFile* ppf = NULL;
    Tcl_Encoding uni;
    Tcl_DString pathds, ds;

    uni = Tcl_GetEncoding(interp, "unicode");

    /* Get a pointer to the IShellLink interface. */
    hres = CoCreateInstance(&CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER,
	    &IID_IShellLinkW, (LPVOID*) &psl);
    if (FAILED(hres)) { msg = "CoCreateInstance"; goto shortcutError; }

    // targetPath
    str = Tcl_TranslateFileName(interp, Tcl_GetString(targetObjPtr), &pathds);
    str = Tcl_UtfToExternalDString(uni, str, Tcl_DStringLength(&pathds), &ds);
    hres = psl->lpVtbl->SetPath(psl, (WCHAR *) str);
    Tcl_DStringFree(&pathds);
    Tcl_DStringFree(&ds);
    if (FAILED(hres)) { msg = "SetPath"; goto shortcutError; }

    if (objArgs) {
	str = Tcl_GetStringFromObj(objArgs, &len);
	hres = psl->lpVtbl->SetArguments(psl,
		(WCHAR *) Tcl_UtfToExternalDString(uni, str, len, &ds));
	Tcl_DStringFree(&ds);
	if (FAILED(hres)) { msg = "SetArguments"; goto shortcutError; }
    }
    if (objDesc) {
	str = Tcl_GetStringFromObj(objDesc, &len);
	hres = psl->lpVtbl->SetDescription(psl,
		(WCHAR *) Tcl_UtfToExternalDString(uni, str, len, &ds));
	Tcl_DStringFree(&ds);
	if (FAILED(hres)) { msg = "SetDescription"; goto shortcutError; }
    }
    if (objDir) {
	str = Tcl_TranslateFileName(interp, Tcl_GetString(objDir), &pathds);
	str = Tcl_UtfToExternalDString(uni, str, Tcl_DStringLength(&pathds),
		&ds);
	hres = psl->lpVtbl->SetWorkingDirectory(psl, (WCHAR *) str);
	Tcl_DStringFree(&pathds);
	Tcl_DStringFree(&ds);
	if (FAILED(hres)) { msg = "SetWorkingDirectory"; goto shortcutError; }
    }
    if (objIpath) {
	str = Tcl_TranslateFileName(interp, Tcl_GetString(objIpath), &pathds);
	str = Tcl_UtfToExternalDString(uni, str, Tcl_DStringLength(&pathds),
		&ds);
	hres = psl->lpVtbl->SetIconLocation(psl, (WCHAR *) str, iconIndex);
	Tcl_DStringFree(&pathds);
	Tcl_DStringFree(&ds);
	if (FAILED(hres)) { msg = "SetIconLocation"; goto shortcutError; }
    }

    hres = psl->lpVtbl->QueryInterface(psl, &IID_IPersistFile, (LPVOID*) &ppf);
    if (FAILED(hres)) { msg = "QueryInterface"; goto shortcutError; }

    /* Save the link. */
    str = Tcl_TranslateFileName(interp, Tcl_GetString(linkObjPtr), &pathds);
    str = Tcl_UtfToExternalDString(uni, str, Tcl_DStringLength(&pathds), &ds);
    hres = ppf->lpVtbl->Save(ppf, (WCHAR *) str, TRUE);
    msg = "Save";
    Tcl_DStringFree(&pathds);
    Tcl_DStringFree(&ds);
    ppf->lpVtbl->Release(ppf);

 shortcutError:
    Tcl_FreeEncoding(uni);
    if (psl) {
        psl->lpVtbl->Release(psl);
    }
    if (FAILED(hres)) {
	if (msg) {
	    char buf[128];

	    sprintf(buf, "failed in \"%s\" with code %d", msg, hres);
	    Tcl_AppendResult(interp, buf, NULL);
	}
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * CreateShortcut --
 *
 *	Create a Windows shell shortcut file (.lnk).
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

TCL_OBJ_CMD(CreateShortcutObjCmd)
{
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	Tcl_GetThreadData(&dataKey, sizeof(ThreadSpecificData));

    Tcl_Obj *objArgs, *objDesc, *objDir, *objIpath, *objPtr;
    Tcl_Obj *linkObjPtr, *targetObjPtr;
    int len, i, index, iconIndex = 0;
    OSVERSIONINFO os;

    static CONST char *options[] = {
	"-args",	"-description",	"-directory",
	"-iconpath",	"-iconindex",	(char *) NULL
    };
    enum options {
	SHORTCUT_ARGS,	SHORTCUT_DESC,	SHORTCUT_DIR,
	SHORTCUT_IPATH,	SHORTCUT_IIDX
    };

    if (!tsdPtr->initialized) {
	tsdPtr->initialized = 1;
	CoInitializeEx(0, COINIT_APARTMENTTHREADED);
	Tcl_CreateThreadExitHandler(FinalizeWinCmd, NULL);
    }

    if (objc < 3) {
	wrongShortcutArgs:
	Tcl_WrongNumArgs(interp, 1, objv,
		"linkPath targetPath ?-args targetArgs?"
		" ?-description desc? ?-directory dir?"
		" ?-iconpath path? ?-iconindex iconidx?");
	return TCL_ERROR;
    }

    /* Check that it has .lnk before we get the normalized path */
    if (!Tcl_StringCaseMatch(Tcl_GetString(objv[1]), "*.lnk", 1 /*nocase*/)) {
	Tcl_AppendToObj(objv[1], ".lnk", -1);
    }
    linkObjPtr = Tcl_FSGetNormalizedPath(interp, objv[1]);
    targetObjPtr = Tcl_FSGetNormalizedPath(interp, objv[2]);
    if ((linkObjPtr == NULL) || (targetObjPtr == NULL)) {
	Tcl_AppendResult(interp, "unable to convert path of link or target",
		NULL);
        return TCL_ERROR;
    }

    objArgs  = NULL;
    objDesc  = NULL;
    objDir   = NULL;
    objIpath = NULL;
    for (i = 3; i < objc - 1; i++) {
	if (Tcl_GetIndexFromObj(interp, objv[i++], options, "CreateShortcut", 0,
			&index) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (((enum options) index) == SHORTCUT_IIDX) {
	    if (Tcl_GetIntFromObj(interp, objv[i], &iconIndex) != TCL_OK) {
		return TCL_ERROR;
	    }
	} else {
	    objPtr = objv[i];
	    (void) Tcl_GetStringFromObj(objPtr, &len);
	    if (len == 0) {
		objPtr = NULL;
	    }
	    switch ((enum options) index) {
		case SHORTCUT_ARGS:  objArgs  = objPtr; break;
		case SHORTCUT_DESC:  objDesc  = objPtr; break;
		case SHORTCUT_DIR:
		    if (objPtr &&
			    (Tcl_FSGetNormalizedPath(interp, objPtr) == NULL)) {
			return TCL_ERROR;
		    }
		    objDir   = objPtr;
		    break;
		case SHORTCUT_IPATH:
		    if (objPtr &&
			    (Tcl_FSGetNormalizedPath(interp, objPtr) == NULL)) {
			return TCL_ERROR;
		    }
		    objIpath = objPtr;
		    break;
	    }
	}
    }
    if (i != objc) {
	goto wrongShortcutArgs;
    }

    /*
     * Swap on Win9x / NT-based (Unicode aware) variants.
     */
    os.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
    GetVersionEx(&os);
    if (os.dwPlatformId == VER_PLATFORM_WIN32_WINDOWS) {
	return Win32CreateShortcutA(interp, linkObjPtr, targetObjPtr,
		objArgs, objDesc, objDir, objIpath, iconIndex);
    } else {
	return Win32CreateShortcutW(interp, linkObjPtr, targetObjPtr,
		objArgs, objDesc, objDir, objIpath, iconIndex);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * FinalizeWinCmd --
 *
 *	Call CoUninitialize.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static void
FinalizeWinCmd(ClientData clientData)	/* Not used. */
{
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	Tcl_GetThreadData(&dataKey, sizeof(ThreadSpecificData));

    CoUninitialize();
    tsdPtr->initialized = 0;
}

/*
 *----------------------------------------------------------------------
 *
 * WintclpInitCSIDL --
 *
 *	Initialize win32::CSIDL() array
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
WintclpInitCSIDL(Tcl_Interp *interp)
{
    int i;
    static CONST char *folders[] = {
	"APPDATA", "RoamingAppData",
	"BITBUCKET", "RecycleBinFolder",
	"COMMON_APPDATA", "ProgramData",
	"COMMON_DESKTOPDIRECTORY", "PublicDesktop",
	"COMMON_DOCUMENTS", "PublicDocuments",
	"COMMON_PROGRAMS", "CommonPrograms",
	"COMMON_STARTMENU", "CommonStartMenu",
	"COMMON_STARTUP", "CommonStartup",
	"CONTROLS", "ControlPanelFolder",
	"DESKTOPDIRECTORY", "Desktop",
	"FONTS", "Fonts",
	"LOCAL_APPDATA", "LocalAppData",
	"PERSONAL", "Documents",
	"PROFILE", "Profile",
	"PROGRAM_FILES", "ProgramFiles",
	"PROGRAM_FILESX86", "ProgramFilesX86",
	"PROGRAM_FILES_COMMON", "ProgramFilesCommon",
	"PROGRAM_FILES_COMMONX86", "ProgramFilesCommonX86",
	"PROGRAMS", "Programs",
	"SENDTO", "SendTo",
	"STARTMENU", "StartMenu",
	"STARTUP", "Startup",
	"SYSTEM", "System",
	"SYSTEMX86", "SystemX86",
	"TEMPLATES", "Templates",
	"WINDOWS", "Windows",
	(char *) NULL
    };
    static int folderIds[] = {
	CSIDL_APPDATA, CSIDL_APPDATA,
	CSIDL_BITBUCKET, CSIDL_BITBUCKET,
	CSIDL_COMMON_APPDATA, CSIDL_COMMON_APPDATA,
	CSIDL_COMMON_DESKTOPDIRECTORY, CSIDL_COMMON_DESKTOPDIRECTORY,
	CSIDL_COMMON_DOCUMENTS, CSIDL_COMMON_DOCUMENTS,
	CSIDL_COMMON_PROGRAMS, CSIDL_COMMON_PROGRAMS,
	CSIDL_COMMON_STARTMENU, CSIDL_COMMON_STARTMENU,
	CSIDL_COMMON_STARTUP, CSIDL_COMMON_STARTUP,
	CSIDL_CONTROLS, CSIDL_CONTROLS,
	CSIDL_DESKTOPDIRECTORY, CSIDL_DESKTOPDIRECTORY,
	CSIDL_FONTS, CSIDL_FONTS,
	CSIDL_LOCAL_APPDATA, CSIDL_LOCAL_APPDATA,
	CSIDL_PERSONAL, CSIDL_PERSONAL,
	CSIDL_PROFILE, CSIDL_PROFILE,
	CSIDL_PROGRAM_FILES, CSIDL_PROGRAM_FILES,
	CSIDL_PROGRAM_FILESX86, CSIDL_PROGRAM_FILESX86,
	CSIDL_PROGRAM_FILES_COMMON, CSIDL_PROGRAM_FILES_COMMON,
	CSIDL_PROGRAM_FILES_COMMONX86, CSIDL_PROGRAM_FILES_COMMONX86,
	CSIDL_PROGRAMS, CSIDL_PROGRAMS,
	CSIDL_SENDTO, CSIDL_SENDTO,
	CSIDL_STARTMENU, CSIDL_STARTMENU,
	CSIDL_STARTUP, CSIDL_STARTUP,
	CSIDL_SYSTEM, CSIDL_SYSTEM,
	CSIDL_SYSTEMX86, CSIDL_SYSTEMX86,
	CSIDL_TEMPLATES, CSIDL_TEMPLATES,
	CSIDL_WINDOWS, CSIDL_WINDOWS,
	0
    };

    for (i = 0; folders[i] != NULL; i++) {
	if (Tcl_SetVar2Ex(interp, WINTCL_CSIDL_VAR, folders[i],
			Tcl_NewIntObj(folderIds[i]),
			TCL_GLOBAL_ONLY|TCL_LEAVE_ERR_MSG) == NULL) {
	    return TCL_ERROR;
	}
    }

    return TCL_OK;
}
