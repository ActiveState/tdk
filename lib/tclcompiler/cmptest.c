/* 
 * cmptest.c --
 *
 *  The compiler test executable initialization routine and other support
 *  stuff.
 *  This file provides the init routine for "cmptest" (the test executable).
 *  Copyright (c) 2018 ActiveState Software Inc.
 *  Released under the BSD-3 license. See LICENSE file for details.
 *
 * Copyright (c) 1998 by Scriptics Corporation.
 *
 * RCS: @(#) $Id: cmptest.c,v 1.2 2000/10/31 23:30:56 welch Exp $
 */

static char *patchLevel = NULL;


/*
 *----------------------------------------------------------------------
 *
 * ScanArguments --
 *
 *  Scans the argument list, looks for a flag called "--patchLevel".
 *  If the flag is present, saves a pointer to the new patch level
 *  string, to be later used by the init procedure.
 *  Also, it drops --pathLevel and the following arg from the args list.
 *
 * Results:
 *  None.
 *
 * Side effects:
 *  May change the argv list.
 *
 *----------------------------------------------------------------------
 */

static void
ScanArguments(int *argcPtr, char **argvPtr)
{
    int argc = *argcPtr;
    int i;
    
    for (i=0 ; i < argc ; i++) {
        if (!strcmp(argvPtr[i], "--patchLevel")) {
            patchLevel = argvPtr[i+1];
            while (i < argc) {
                argvPtr[i] = argvPtr[i+2];
                i += 1;
            }
            argvPtr[i] = NULL;
            *argcPtr = argc - 2;
            return;
        }
    }
}


/*
 *----------------------------------------------------------------------
 *
 * CmptestAppInit --
 *
 *  Loads the loadr and the compiler as static Tcl packages.
 *
 * Results:
 *  Returns a standard Tcl completion code, and leaves an error
 *  message in interp->result if an error occurs.
 *
 * Side effects:
 *  Depends on the startup script.
 *
 *----------------------------------------------------------------------
 */

static int
CmptestAppInit(interp)
    Tcl_Interp *interp;		/* Interpreter for application. */
{
    char *oldPatchLevel = NULL;
    
    if (Tcl_Init(interp) == TCL_ERROR) {
        return TCL_ERROR;
    }

#ifdef WIN32
    if (Registry_Init(interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    Tcl_StaticPackage(interp, "registry", Registry_Init, NULL);
#endif
    
    /*
     * if the patchLevel variable is set, temporarily replace tcl_patchLevel
     * before we initialize tbcload. This will make the compatibility
     * layer in tbcload start as a different patch level as the interpreter
     * as a whole.
     */

    if (patchLevel) {
        char *p = Tcl_GetVar(interp, "tcl_patchLevel", TCL_LEAVE_ERR_MSG);
        if (p == NULL) {
            return TCL_ERROR;
        }

        oldPatchLevel = Tcl_Alloc(strlen(p) + 1);
        strcpy(oldPatchLevel, p);

        if (!Tcl_SetVar(interp, "tcl_patchLevel", patchLevel,
                TCL_LEAVE_ERR_MSG)) {
            Tcl_Free((char *) oldPatchLevel);
            return TCL_ERROR;
        }
    }

    if (Tbcload_Init(interp) == TCL_ERROR) {
        if (oldPatchLevel) {
            Tcl_Free((char *) oldPatchLevel);
        }
        return TCL_ERROR;
    }
    Tcl_StaticPackage(interp, (char *) TbcloadGetPackageName(),
            Tbcload_Init, Tbcload_SafeInit);

    if (oldPatchLevel) {
        char *p = Tcl_SetVar(interp, "tcl_patchLevel", oldPatchLevel,
                TCL_LEAVE_ERR_MSG);
        Tcl_Free((char *) oldPatchLevel);
        if (!p) {
            return TCL_ERROR;
        }
    }
    
    if (Compiler_Init(interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    Tcl_StaticPackage(interp, (char *) CompilerGetPackageName(),
            Compiler_Init, (Tcl_PackageInitProc *) NULL);

    if (Cmptest_Init(interp) == TCL_ERROR) {
        return TCL_ERROR;
    }
    Tcl_StaticPackage(interp, (char *) CmptestGetPackageName(),
            Cmptest_Init, (Tcl_PackageInitProc *) NULL);

    Tcl_SetVar(interp, "tcl_rcFileName", "~/tclshrc.tcl", TCL_GLOBAL_ONLY);

    return TCL_OK;
}
