/*
 * winTrans.c
 *
 * transparent windows code
 *
 * $Id: winTrans.c hobbs Exp $
 */

#include "wintcl.h"

HRGN		AddRegionData(HRGN hOrigin, LPRGNDATA pRgnData, int size);
int		SetTkWindowRegion(Tcl_Interp *interp, HWND hwnd,
					Tcl_Obj *picObjPtr);

TCL_OBJ_CMD(TransparentObjCmd)
{
    Tk_Window tkwin;
    HWND hwnd;

    if ((objc < 2) || (objc > 3)) {
	Tcl_WrongNumArgs(interp, 1, objv, "window ?image?");
	return TCL_ERROR;
    }

    tkwin = Cmd_WinNameOrHandle(interp, objv[1], &hwnd, 0);
    if (tkwin == NULL) {
	return TCL_ERROR;
    }

    if (Tk_IsTopLevel(tkwin)) {
#if 1
	hwnd = GetParent(hwnd);
#else
	int returnval;
	TCHAR myname[50];

	while ((returnval = GetClassName(hwnd, myname, 50))
		&& strcmp(myname, "TkTopLevel")) {
	    hwnd = GetParent(hwnd);
	}

	if (returnval == 0) {
	    Tcl_AppendResult(interp,
		    "could not get the class name of window \"",
		    Tcl_GetString(objv[1]), "\"", NULL);
	    return TCL_ERROR;
	}
#endif
    }

    if (objc == 2) {
	SetWindowRgn(hwnd, NULL, TRUE);
	return TCL_OK;
    }

    return SetTkWindowRegion(interp, hwnd, objv[2]);
}

HRGN
AddRegionData(HRGN hOrigin, LPRGNDATA pRgnData, int size)
{
    int datasize = sizeof(RGNDATAHEADER) + size*sizeof(RECT);
    HRGN hNewRgn;

    pRgnData->rdh.nCount = size;
    hNewRgn = ExtCreateRegion(NULL, datasize, pRgnData);

    if (hOrigin != NULL) {
	if (CombineRgn(hNewRgn, hNewRgn, hOrigin, RGN_OR) == ERROR) {
	    CloseHandle(hNewRgn);
	    return hOrigin;
	}
	CloseHandle(hOrigin);
    }
    return hNewRgn;
}

int
SetTkWindowRegion(Tcl_Interp *interp, HWND hwnd, Tcl_Obj *picObjPtr)
{
    Tk_PhotoImageBlock img;
    Tk_PhotoHandle photo;

    unsigned char *ptr;
    int nextline, i, imgsize;
    int x = 0, y = 0;

    LPRGNDATA pRgnData;
    LPRECT rects;

    HRGN hPicRegion = NULL;

    register unsigned char alpha;

    photo = Tk_FindPhoto(interp, Tcl_GetString(picObjPtr));
    if (photo == NULL) {
	Tcl_AppendResult(interp, "could not find image \"",
		Tcl_GetString(picObjPtr), "\"", NULL);
	return TCL_ERROR;
    }

    Tk_PhotoGetImage(photo, &img);

    if (img.pixelSize != 4) {
	/*
	 * No alpha channel - thus no transparent bits
	 */
	return TCL_OK;
    }

    ptr		= img.pixelPtr;
    nextline	= img.pitch - img.pixelSize * (img.width);
    imgsize	= img.width * img.height;
#define MAX_RECTS 400
    if (imgsize > MAX_RECTS) {
	imgsize	= MAX_RECTS; // max # rectangles at a time
    }

    pRgnData	= (LPRGNDATA)
	ckalloc(sizeof(RGNDATAHEADER) + imgsize*sizeof(RECT));
    if (pRgnData == NULL) {
	Tcl_SetResult(interp, "insufficient memory to allocate region",
		TCL_STATIC);
	return TCL_ERROR;
    }
    rects	= (RECT *)(pRgnData->Buffer);

    pRgnData->rdh.dwSize	 = sizeof(pRgnData->rdh);
    pRgnData->rdh.iType		 = RDH_RECTANGLES;
    pRgnData->rdh.nCount	 = MAX_RECTS;
    pRgnData->rdh.nRgnSize	 = 0;
    pRgnData->rdh.rcBound.top	 = 0;
    pRgnData->rdh.rcBound.left	 = 0;
    pRgnData->rdh.rcBound.right	 = img.width - 1;
    pRgnData->rdh.rcBound.bottom = img.height - 1;

    i = 0;
    while (y < img.height) {
	alpha = *(ptr + img.offset[3]);
	if (alpha) { // alpha == 0 is fully transparent pixel
	    rects[i].top    = y;
	    rects[i].bottom = y + 1;
	    rects[i].left   = x;
	    rects[i].right  = x + 1;
	    i++;
	    if (i >= imgsize) {
		hPicRegion = AddRegionData(hPicRegion, pRgnData, i);
		i = 0;
	    }
	}
	ptr += img.pixelSize;
	if (++x == img.width) {
	    x = 0;
	    ++y;
	    ptr += nextline;
	}
    }

    if (i > 0) {
	hPicRegion = AddRegionData(hPicRegion, pRgnData, i);
	i = 0;
    }

    SetWindowRgn(hwnd, hPicRegion, TRUE);
    ckfree((char *) pRgnData);
    return TCL_OK;
}
