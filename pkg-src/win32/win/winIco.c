/* 
 *  tkwinico.c implements a "winico" tcl-command which permits to
 *  change the Taskbar and Titlebar-Icon of a Tk-Toplevel
 *  Copyright Brueckner & Jarosch Ing.GmbH,Erfurt,Germany 1998
 */

/* most of the icon handling functions are taken from the Microsoft */
/* IconPro Wintcl SDK-sample                                         */

/************************************************************************\
*     FILES:     ICONS.C  DIB.C
*     PURPOSE:  IconPro Project Icon handing Code C file
*     COMMENTS: This file contains the icon handling code
*     FUNCTIONS:
*       MakeIconFromResource
*       ReadIconFromICOFile
*       AdjustIconImagePointers
*       ReadICOHeader
*       FindDIBBits
*       DIBNumColors
*       PaletteSize
*       BytesPerLine
*
*     Copyright 1995-1996 Microsoft Corp.
* History:
*                July '95 - Created
\************************************************************************/

#include "wintcl.h"

#include <shellapi.h>

typedef struct {
    UINT		Width, Height, Colors; // Width, Height and bpp
    LPBYTE		lpBits;		       // ptr to DIB bits
    DWORD		dwNumBytes;	       // how many bytes?
    LPBITMAPINFO	lpbi;		       // ptr to header
    LPBYTE		lpXOR;		       // ptr to XOR image bits
    LPBYTE		lpAND;		       // ptr to AND image bits
    HICON		hIcon;		       // DAS ICON
} ICONIMAGE, *LPICONIMAGE;

typedef struct {
    BOOL	bHasChanged;			 // Has image changed?
    TCHAR	szOriginalICOFileName[MAX_PATH]; // Original name
    TCHAR	szOriginalDLLFileName[MAX_PATH]; // Original name
    int		nNumImages;			 // How many images?
    ICONIMAGE	IconImages[1];			 // Image entries
} ICONRESOURCE, *LPICONRESOURCE;

// These next two structs represent how the icon information is stored
// in an ICO file.
// The following two structs are for the use of this program in
// manipulating icons. They are more closely tied to the operation
// of this program than the structures listed above. One of the
// main differences is that they provide a pointer to the DIB
// information of the masks.
typedef struct {
    BYTE	bWidth;		// Width of the image
    BYTE	bHeight;	// Height of the image (times 2)
    BYTE	bColorCount;	// Number of colors in image (0 if >=8bpp)
    BYTE	bReserved;	// Reserved
    WORD	wPlanes;	// Color Planes
    WORD	wBitCount;	// Bits per pixel
    DWORD	dwBytesInRes;	// how many bytes in this resource?
    DWORD	dwImageOffset;	// where in the file is this image
} ICONDIRENTRY, *LPICONDIRENTRY;
typedef struct {
    WORD	idReserved;	// Reserved
    WORD	idType;		// resource type (1 for icons)
    WORD	idCount;	// how many images?
    ICONDIRENTRY idEntries[1];	// the entries for each image
} ICONDIR, *LPICONDIR;

// How wide, in bytes, would this many bits be, DWORD aligned?
#define WIDTHBYTES(bits)      ((((bits) + 31)>>5)<<2)

HINSTANCE
Ico_GetHINSTANCE()
{
    static HINSTANCE instance = NULL;
    /*
     * We have to figure out how to make this optionally Tk_GetHINSTANCE.
     */
    if (instance == NULL) {
	instance = GetModuleHandle(NULL);
    }
    return instance;
}

// used function prototypes
static LPSTR FindDIBBits (LPSTR lpbi);
static WORD DIBNumColors (LPSTR lpbi);
static WORD PaletteSize (LPSTR lpbi);
static DWORD BytesPerLine(LPBITMAPINFOHEADER lpBMIH);

/****************************************************************************/
// Prototypes for local functions
static int ReadICOHeader(HANDLE hFile);
static BOOL AdjustIconImagePointers(LPICONIMAGE lpImage);
/****************************************************************************/

/****************************************************************************
*
*     FUNCTION: MakeIconFromResource
*
*     PURPOSE:	Makes an HICON from an icon resource
*
*     PARAMS:	LPICONIMAGE	lpIcon - pointer to the icon resource
*
*     RETURNS:	HICON - handle to the new icon, NULL for failure
*
* History:
*		 July '95 - Created
*
\****************************************************************************/
static HICON MakeIconFromResource(LPICONIMAGE lpIcon)
{
    HICON hIcon;
    // Sanity Check
    if ((lpIcon == NULL) || (lpIcon->lpBits == NULL)) {
	return NULL;
    }
    // Let the OS do the real work :)
    hIcon = (HICON) CreateIconFromResourceEx(lpIcon->lpBits,
	    lpIcon->dwNumBytes, TRUE, 0x00030000,
	    (*(LPBITMAPINFOHEADER)(lpIcon->lpBits)).biWidth,
	    (*(LPBITMAPINFOHEADER)(lpIcon->lpBits)).biHeight/2, 0);
    // It failed, odds are good we're on NT3.5 so try the non-Ex way
    if (hIcon == NULL) {
	// We would break on NT if we try with a 16bpp image
	if (lpIcon->lpbi->bmiHeader.biBitCount != 16) {
	    hIcon = CreateIconFromResource(lpIcon->lpBits,
		    lpIcon->dwNumBytes, TRUE, 0x00030000);
	}
    }
    return hIcon;
}

static void FreeIconResource(LPICONRESOURCE lpIR)
{
    int i;
    if (lpIR == NULL)
	return;
    // Free all the bits
    for (i=0; i< lpIR->nNumImages; i++) {
	if (lpIR->IconImages[i].lpBits != NULL)
	    ckfree((char*)lpIR->IconImages[i].lpBits);
	if (lpIR->IconImages[i].hIcon != NULL)
	    DestroyIcon(lpIR->IconImages[i].hIcon);
    }
    ckfree((char*) lpIR);
}

/****************************************************************************
*
*     FUNCTION: ReadIconFromICOFile
*
*     PURPOSE:	Reads an Icon Resource from an ICO file
*
*     PARAMS:	LPCTSTR szFileName - Name of the ICO file
*
*     RETURNS:	LPICONRESOURCE - pointer to the resource, NULL for failure
*
* History:
*		 July '95 - Created
*
\****************************************************************************/
static LPICONRESOURCE
ReadIconFromICOFile(Tcl_Interp *interp, LPCTSTR szFileName)
{
    LPICONRESOURCE	lpIR , lpNew ;
    HANDLE		hFile;
    int			i;
    DWORD		dwBytesRead;
    LPICONDIRENTRY	lpIDE;

    // Open the file
    if ((hFile = CreateFile(szFileName, GENERIC_READ, 0, NULL, OPEN_EXISTING,
	    FILE_ATTRIBUTE_NORMAL, NULL)) == INVALID_HANDLE_VALUE) {
	Tcl_AppendResult(interp,"Error Opening File for Reading",(char*)NULL);
	return NULL;
    }
    // Allocate memory for the resource structure
    if ((lpIR = (LPICONRESOURCE) ckalloc(sizeof(ICONRESOURCE))) == NULL) {
	Tcl_AppendResult(interp,"Error Allocating Memory",(char*)NULL);
	CloseHandle(hFile);
	return NULL;
    }
    // Read in the header
    if ((lpIR->nNumImages = ReadICOHeader(hFile )) == -1) {
	Tcl_AppendResult(interp,"Error Reading File Header",(char*)NULL);
	CloseHandle(hFile);
	ckfree((char*) lpIR);
	return NULL;
    }
    // Adjust the size of the struct to account for the images
    lpNew = (LPICONRESOURCE) ckrealloc((char*)lpIR,
	    sizeof(ICONRESOURCE) + ((lpIR->nNumImages-1) * sizeof(ICONIMAGE)));
    if (lpNew == NULL) {
	Tcl_AppendResult(interp,"Error Allocating Memory",(char*)NULL);
	CloseHandle(hFile);
	ckfree((char*)lpIR);
	return NULL;
    }
    lpIR = lpNew;
    // Store the original name
    lstrcpy(lpIR->szOriginalICOFileName, szFileName);
    lstrcpy(lpIR->szOriginalDLLFileName, "");
    // Allocate enough memory for the icon directory entries
    if ((lpIDE = (LPICONDIRENTRY)
	    ckalloc(lpIR->nNumImages * sizeof(ICONDIRENTRY))) == NULL) {
	Tcl_AppendResult(interp,"Error Allocating Memory",(char*)NULL);
	CloseHandle(hFile);
	ckfree((char*) lpIR);
	return NULL;
    }
    // Read in the icon directory entries
    if (! ReadFile(hFile, lpIDE, lpIR->nNumImages * sizeof(ICONDIRENTRY ),
	    &dwBytesRead, NULL )) {
	Tcl_AppendResult(interp,"Error Reading File",(char*)NULL);
	CloseHandle(hFile);
	ckfree((char*) lpIR);
	return NULL;
    }
    if (dwBytesRead != lpIR->nNumImages * sizeof(ICONDIRENTRY )) {
	Tcl_AppendResult(interp,"Error Reading File",(char*)NULL);
	CloseHandle(hFile);
	ckfree((char*) lpIR);
	return NULL;
    }
    // Loop through and read in each image
    for (i = 0; i < lpIR->nNumImages; i++) {
	// Allocate memory for the resource
	if ((lpIR->IconImages[i].lpBits =
		(LPBYTE) ckalloc(lpIDE[i].dwBytesInRes)) == NULL) {
	    Tcl_AppendResult(interp,"Error Allocating Memory",(char*)NULL);
	    CloseHandle(hFile);
	    ckfree((char*)lpIR);
	    ckfree((char*)lpIDE);
	    return NULL;
	}
	lpIR->IconImages[i].dwNumBytes = lpIDE[i].dwBytesInRes;
	// Seek to beginning of this image
	if (SetFilePointer(hFile, lpIDE[i].dwImageOffset, NULL, FILE_BEGIN)
		== 0xFFFFFFFF) {
	    Tcl_AppendResult(interp,"Error Seeking in File",(char*)NULL);
	    CloseHandle(hFile);
	    ckfree((char*)lpIR);
	    ckfree((char*)lpIDE);
	    return NULL;
	}
	// Read it in
	if (! ReadFile(hFile, lpIR->IconImages[i].lpBits,
		lpIDE[i].dwBytesInRes, &dwBytesRead, NULL )) {
	    Tcl_AppendResult(interp,"Error Reading File",(char*)NULL);
	    CloseHandle(hFile);
	    ckfree((char*)lpIR);
	    ckfree((char*)lpIDE);
	    return NULL;
	}
	if (dwBytesRead != lpIDE[i].dwBytesInRes) {
	    Tcl_AppendResult(interp,"Error Reading File",(char*)NULL);
	    CloseHandle(hFile);
	    ckfree((char*)lpIDE);
	    ckfree((char*)lpIR);
	    return NULL;
	}
	// Set the internal pointers appropriately
	if (! AdjustIconImagePointers(&(lpIR->IconImages[i]) )) {
	    Tcl_AppendResult(interp,
		    "Error Converting to Internal Format",(char*)NULL);
	    CloseHandle(hFile);
	    ckfree((char*)lpIDE);
	    ckfree((char*)lpIR);
	    return NULL;
	}
	lpIR->IconImages[i].hIcon =
	    MakeIconFromResource(&(lpIR->IconImages[i]));
    }
    // Clean up
    ckfree((char*) lpIDE);
    CloseHandle(hFile);
    return lpIR;
}
/* End ReadIconFromICOFile() **********************************************/


/****************************************************************************
*
*     FUNCTION: AdjustIconImagePointers
*
*     PURPOSE:	Adjusts internal pointers in icon resource struct
*
*     PARAMS:	LPICONIMAGE lpImage - the resource to handle
*
*     RETURNS:	BOOL - TRUE for success, FALSE for failure
*
* History:
*		 July '95 - Created
*
\****************************************************************************/
BOOL AdjustIconImagePointers(LPICONIMAGE lpImage)
{
    // Sanity check
    if (lpImage==NULL)
	return FALSE;
    // BITMAPINFO is at beginning of bits
    lpImage->lpbi = (LPBITMAPINFO)lpImage->lpBits;
    // Width - simple enough
    lpImage->Width = lpImage->lpbi->bmiHeader.biWidth;
    // Account for funky format of icons where height is doubled
    lpImage->Height = (lpImage->lpbi->bmiHeader.biHeight)/2;
    // How many colors?
    lpImage->Colors = lpImage->lpbi->bmiHeader.biPlanes
	* lpImage->lpbi->bmiHeader.biBitCount;
    // XOR bits follow the header and color table
    lpImage->lpXOR = (LPBYTE)FindDIBBits((LPSTR)lpImage->lpbi);
    // AND bits follow the XOR bits
    lpImage->lpAND = lpImage->lpXOR
	+ (lpImage->Height*BytesPerLine((LPBITMAPINFOHEADER)(lpImage->lpbi)));
    return TRUE;
}
/* End AdjustIconImagePointers() *******************************************/


/****************************************************************************
*
*     FUNCTION: ReadICOHeader
*
*     PURPOSE:	Reads the header from an ICO file
*
*     PARAMS:	HANDLE hFile - handle to the file
*
*     RETURNS:	UINT - Number of images in file, -1 for failure
*
* History:
*		 July '95 - Created
*
\****************************************************************************/
static int ReadICOHeader(HANDLE hFile)
{
    WORD  Input;
    DWORD dwBytesRead;

    if (// Read the 'reserved' WORD
	!ReadFile(hFile, &Input, sizeof(WORD), &dwBytesRead, NULL)
	// Did we get a WORD?
	|| (dwBytesRead != sizeof(WORD))
	// Was it 'reserved' ?   (ie 0)
	|| (Input != 0)
	// Read the type WORD
	|| (!ReadFile(hFile, &Input, sizeof(WORD), &dwBytesRead, NULL))
	// Did we get a WORD?
	|| (dwBytesRead != sizeof(WORD))
	// Was it type 1?
	|| (Input != 1)
	// Get the count of images
	|| (!ReadFile(hFile, &Input, sizeof(WORD), &dwBytesRead, NULL))
	// Did we get a WORD?
	|| (dwBytesRead != sizeof(WORD))
	) {
	return -1;
    }
    // Return the count
    return (int)Input;
}
/* End ReadICOHeader() ****************************************************/


/****************************************************************************
*
*     FUNCTION: FindDIBits
*
*     PURPOSE:	Locate the image bits in a CF_DIB format DIB.
*
*     PARAMS:	LPSTR lpbi - pointer to the CF_DIB memory block
*
*     RETURNS:	LPSTR - pointer to the image bits
*
* History:
*		 July '95 - Copied <g>
*
\****************************************************************************/
static LPSTR FindDIBBits(LPSTR lpbi)
{
    return (lpbi + (*(LPDWORD) lpbi) + PaletteSize(lpbi));
}
/* End FindDIBits() *********************************************************/

/****************************************************************************
*
*     FUNCTION: DIBNumColors
*
*     PURPOSE:	Calculates the number of entries in the color table.
*
*     PARAMS:	LPSTR lpbi - pointer to the CF_DIB memory block
*
*     RETURNS:	WORD - Number of entries in the color table.
*
* History:
*		 July '95 - Copied <g>
*
\****************************************************************************/
static WORD DIBNumColors(LPSTR lpbi)
{
    WORD wBitCount;
    DWORD dwClrUsed;

    dwClrUsed = ((LPBITMAPINFOHEADER) lpbi)->biClrUsed;

    if (dwClrUsed)
	return (WORD) dwClrUsed;

    wBitCount = ((LPBITMAPINFOHEADER) lpbi)->biBitCount;

    switch (wBitCount) {
	case 1: return 2;
	case 4: return 16;
	case 8:	return 256;
	default:return 0;
    }
}
/* End DIBNumColors() ******************************************************/


/****************************************************************************
*
*     FUNCTION: PaletteSize
*
*     PURPOSE:	Calculates the number of bytes in the color table.
*
*     PARAMS:	LPSTR lpbi - pointer to the CF_DIB memory block
*
*     RETURNS:	WORD - number of bytes in the color table
*
*
* History:
*		 July '95 - Copied <g>
*
\****************************************************************************/
static WORD PaletteSize(LPSTR lpbi)
{
    return ((WORD)(DIBNumColors(lpbi ) * sizeof(RGBQUAD )));
}
/* End PaletteSize() ********************************************************/



/****************************************************************************
*
*     FUNCTION: BytesPerLine
*
*     PURPOSE:	Calculates the number of bytes in one scan line.
*
*     PARAMS:	LPBITMAPINFOHEADER lpBMIH - pointer to the BITMAPINFOHEADER
*					    that begins the CF_DIB block
*
*     RETURNS:	DWORD - number of bytes in one scan line (DWORD aligned)
*
* History:
*		 July '95 - Created
*
\****************************************************************************/
static DWORD BytesPerLine(LPBITMAPINFOHEADER lpBMIH)
{
    return WIDTHBYTES(lpBMIH->biWidth * lpBMIH->biPlanes * lpBMIH->biBitCount);
}
/* End BytesPerLine() ********************************************************/


typedef struct IcoInfo {
    HICON hIcon;		/*icon handle returned by LoadIcon*/
    int itype;
    int id;			/* Integer identifier for command;  used to
				 * cancel it. */
    LPICONRESOURCE lpIR;	/*IconresourcePtr if type==ICO_FILE */
    int iconpos;		/*hIcon is the nth Icon*/
    char* taskbar_txt;		/*malloced text to display in the taskbar*/
    Tcl_Interp* interp;		/*interp which created the icon*/
    char* taskbar_command;	/*command to eval if events in the taskbar arrive*/
    int taskbar_flags;	      /*taskbar related flags*/
    struct IcoInfo *nextPtr;
} IcoInfo;

static IcoInfo* firstIcoPtr = NULL;
#define ICO_LOAD   1
#define ICO_FILE   2

#define TASKBAR_ICON 1
#define ICON_MESSAGE WM_USER+1234

static HWND CreateTaskbarHandlerWindow(void) ;

static int TaskbarOperation(Tcl_Interp *interp,
	IcoInfo *icoPtr,
	int oper,
	HICON hIcon,
	char *txt)
{
    int result;
    NOTIFYICONDATA ni;

    ni.cbSize	= sizeof(NOTIFYICONDATA);
    ni.hWnd	= CreateTaskbarHandlerWindow();
    ni.uID	= icoPtr->id;
    ni.uFlags	= NIF_ICON | NIF_TIP | NIF_MESSAGE;
    ni.hIcon	= (HICON)hIcon;
    ni.uCallbackMessage = ICON_MESSAGE;
    strncpy(ni.szTip, txt, 63);
    result = Shell_NotifyIconA(oper, &ni);
    if (result == TRUE) {
	if (oper == NIM_ADD || oper == NIM_MODIFY) {
	    icoPtr->taskbar_flags |= TASKBAR_ICON;
	} else if (oper == NIM_DELETE) {
	    icoPtr->taskbar_flags &= ~TASKBAR_ICON;
	}
    }
    if (interp != NULL) {
	Tcl_SetObjResult(interp, Tcl_NewIntObj(result));
    }
    return TCL_OK;
}

static IcoInfo *NewIcon(Tcl_Interp *interp,
	HICON hIcon, int itype, LPICONRESOURCE lpIR, int iconpos)
{
    static int nextId = 1;
    char buffer[50];
    IcoInfo *icoPtr;

    icoPtr = (IcoInfo *) ckalloc((unsigned) (sizeof(IcoInfo)));
    ZeroMemory(icoPtr, sizeof(IcoInfo));
    icoPtr->id	    = nextId;
    icoPtr->hIcon   = hIcon;
    icoPtr->itype   = itype;
    icoPtr->lpIR    = lpIR;
    icoPtr->iconpos = iconpos;
    sprintf(buffer, "ico#%d", icoPtr->id);
    icoPtr->taskbar_txt = ckalloc(strlen(buffer)+1);
    strcpy(icoPtr->taskbar_txt, buffer);
    icoPtr->interp  = interp;
    icoPtr->taskbar_command = NULL;
    icoPtr->taskbar_flags = 0;
    if (itype == ICO_LOAD) {
	icoPtr->lpIR    = (LPICONRESOURCE)NULL;
	icoPtr->iconpos = 0;
    }
    nextId += 1;
    icoPtr->nextPtr = firstIcoPtr;
    firstIcoPtr = icoPtr;
    Tcl_SetResult(interp, buffer, TCL_VOLATILE);
    return icoPtr;
}

static void FreeIcoPtr(Tcl_Interp *interp,IcoInfo *icoPtr)
{
    /*
     * Splice out this icon from the list
     */
    if (firstIcoPtr == icoPtr) {
	firstIcoPtr = icoPtr->nextPtr;
    } else {
	IcoInfo *prevPtr;
	for (prevPtr = firstIcoPtr; prevPtr->nextPtr != icoPtr;
	     prevPtr = prevPtr->nextPtr) {
	    /* Empty loop body. */
	}
	prevPtr->nextPtr = icoPtr->nextPtr;
    }
    if (icoPtr->taskbar_flags & TASKBAR_ICON) {
	TaskbarOperation(NULL, icoPtr, NIM_DELETE, NULL, "");
    }
    if (icoPtr->itype == ICO_FILE) {
	FreeIconResource(icoPtr->lpIR);
    }
    if (icoPtr->taskbar_txt != NULL) {
	ckfree((char *) icoPtr->taskbar_txt);
    }
    if (icoPtr->taskbar_command != NULL) {
	ckfree((char *) icoPtr->taskbar_command);
    }
    ckfree((char *) icoPtr);
}

static IcoInfo *GetIcoPtr(Tcl_Interp *interp, Tcl_Obj *objPtr)
{
    IcoInfo *icoPtr;
    int id;
    char *end, *string = Tcl_GetString(objPtr);

    if (strncmp(string, "ico#", 4) != 0) {
	goto badIco;
    }
    string += 4;
    id = strtoul(string, &end, 10);
    if ((end == string) || (*end != 0)) {
	goto badIco;
    }
    for (icoPtr = firstIcoPtr; icoPtr != NULL;
	 icoPtr = icoPtr->nextPtr) {
	if (icoPtr->id == id) {
	    return icoPtr;
	}
    }
    badIco:
    if (interp != NULL) {
	Tcl_AppendResult(interp, "icon \"", string, "\" doesn't exist",
		(char *) NULL);
    }
    return NULL;
}

static Cmd_Struct g_TaskbarMsgs[] = {
    "WM_MOUSEMOVE",	WM_MOUSEMOVE,
    "WM_LBUTTONDOWN",	WM_LBUTTONDOWN,
    "WM_LBUTTONUP",	WM_LBUTTONUP,
    "WM_LBUTTONDBLCLK",	WM_LBUTTONDBLCLK,
    "WM_RBUTTONDOWN",	WM_RBUTTONDOWN,
    "WM_RBUTTONUP",	WM_RBUTTONUP,
    "WM_RBUTTONDBLCLK",	WM_RBUTTONDBLCLK,
    "WM_MBUTTONDOWN",	WM_MBUTTONDOWN,
    "WM_MBUTTONUP",	WM_MBUTTONUP,
    "WM_MBUTTONDBLCLK",	WM_MBUTTONDBLCLK,
    NULL,		0,
};

static void
TaskbarExpandPercents(IcoInfo *icoPtr, WPARAM wParam, LPARAM lParam,
	CONST char *before, Tcl_DString *dsPtr)
{
    register CONST char *string;
    char buffer[2*TCL_INTEGER_SPACE];
    int length;
    Tcl_UniChar ch;
    POINT pt;

    while (1) {
	if (*before == '\0') {
	    break;
	}
	/*
	 * Find everything up to the next % character and append it
	 * to the result string.
	 */

	/* No need to convert '%', as it is in ascii range */
	string = strchr(before, '%');
	if (string == (char *) NULL) {
	    Tcl_DStringAppend(dsPtr, before, -1);
	    break;
	} else if (string != before) {
	    Tcl_DStringAppend(dsPtr, before, string-before);
	    before = string;
	}

	before++; /* skip over % */
	if (*before != '\0') {
	    before += Tcl_UtfToUniChar(before, &ch);
	} else {
	    ch = '%';
	}
	string = buffer; /* default */
	switch(ch) {
	    case 'M': case 'm':
		string = Cmd_GetName(g_TaskbarMsgs, (long) lParam);
		if (string == NULL) {
		    string = "none";
		}
		break;
	    case 'i':
		sprintf(buffer, "ico#%d", icoPtr->id);
		break;
	    case 'w':
		sprintf(buffer, "0x%lx", (long) wParam);
		break;
	    case 'l':
		sprintf(buffer, "0x%lx", (long) lParam);
		break;
	    case 't':
		sprintf(buffer, "0x%lx", (long) GetTickCount());
		break;
	    case 'x':
		GetCursorPos(&pt);
		sprintf(buffer, "%ld", (long) pt.x);
		break;
	    case 'y':
		GetCursorPos(&pt);
		sprintf(buffer, "%ld", (long) pt.y);
		break;
	    case 'X':
		sprintf(buffer, "%ld", (long) LOWORD(GetMessagePos()));
		break;
	    case 'Y':
		sprintf(buffer, "%ld", (long) HIWORD(GetMessagePos()));
		break;
	    default:
		length = Tcl_UniCharToUtf(ch, buffer);
		buffer[length] = '\0';
		break;
	}

	Tcl_DStringAppend(dsPtr, string, -1);
    }
}

static void
TaskbarEval(IcoInfo *icoPtr, WPARAM wParam, LPARAM lParam)
{
    if (icoPtr->interp != NULL) {
	Tcl_DString ds;
	int result;

	Tcl_DStringInit(&ds);
	TaskbarExpandPercents(icoPtr, wParam, lParam,
		icoPtr->taskbar_command, &ds);

	Tcl_Preserve(icoPtr->interp);
	result = Tcl_EvalEx(icoPtr->interp, Tcl_DStringValue(&ds),
		Tcl_DStringLength(&ds), TCL_EVAL_GLOBAL | TCL_EVAL_DIRECT);
	Tcl_DStringFree(&ds);

	if (result != TCL_OK) {
	    char buffer[100];
	    sprintf(buffer, "\n\t(command bound to taskbar icon ico#%d)",
		    icoPtr->id);
	    Tcl_AddErrorInfo(icoPtr->interp, buffer);
	    Tcl_BackgroundError(icoPtr->interp);
	}
	Tcl_Release(icoPtr->interp);
    }
}

/*
 * Windows callback procedure for taskbar icons.
 * If ICON_MESSAGE arrives, try to execute the taskbar_command.
 */
static LRESULT CALLBACK
TaskbarHandlerProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    if (message == ICON_MESSAGE) {
	IcoInfo *icoPtr;

	for (icoPtr = firstIcoPtr; icoPtr != NULL;
	     icoPtr = icoPtr->nextPtr) {
	    if ((wParam == (WPARAM) icoPtr->id)
		    && (icoPtr->taskbar_command != NULL)) {
		TaskbarEval(icoPtr, wParam, lParam);
	    }
	}
	return 0;
    }
    return DefWindowProc(hwnd, message, wParam, lParam);
}

/*registers the handler window class*/
#define HANDLER_CLASS "Tk_TaskbarHandler"
static int
RegisterHandlerClass(HINSTANCE hInstance)
{
    WNDCLASS wndclass;
    ZeroMemory(&wndclass, sizeof(WNDCLASS));
    wndclass.lpfnWndProc	= TaskbarHandlerProc;
    wndclass.hInstance		= hInstance;
    wndclass.hIcon		= LoadIcon(NULL, IDI_APPLICATION);
    wndclass.hCursor		= LoadCursor(NULL, IDC_ARROW);
    wndclass.hbrBackground	= (HBRUSH) GetStockObject(WHITE_BRUSH);
    wndclass.lpszClassName	= HANDLER_CLASS;
    return RegisterClass(&wndclass);
}
/*
 * creates a hidden window to handle taskbar messages
 */
static HWND handlerWindow = (HWND)0;
static HWND
CreateTaskbarHandlerWindow(void) {
    static int registered = 0;
    HINSTANCE hInstance = Ico_GetHINSTANCE();

    if (handlerWindow) {
	return handlerWindow;
    }
    if (!registered) {
	if (!RegisterHandlerClass(hInstance)) {
	    return 0;
	}
	registered = 1;
    }
    handlerWindow = CreateWindow(HANDLER_CLASS,"",WS_OVERLAPPED,0,0,
	    CW_USEDEFAULT,CW_USEDEFAULT,NULL, NULL, hInstance, NULL);
    return handlerWindow;
}

static void
DestroyHandlerWindow(void) {
    if (handlerWindow)
	DestroyWindow(handlerWindow);
}

void
WintclpIcoDestroyCmd (ClientData clientData) {
    IcoInfo *icoPtr;
    IcoInfo *nextPtr;
    Tcl_Interp *interp = (Tcl_Interp *) clientData;
    DestroyHandlerWindow();
    for (icoPtr = firstIcoPtr; icoPtr != NULL; icoPtr = nextPtr) {
	nextPtr = icoPtr->nextPtr;
	FreeIcoPtr(interp, icoPtr);
    }
}

static Cmd_Struct g_StdIcons[] = {
    "application",	(long) IDI_APPLICATION,
    "asterisk",		(long) IDI_ASTERISK,
    "exclamation",	(long) IDI_EXCLAMATION,
    "hand",		(long) IDI_HAND,
    "question",		(long) IDI_QUESTION,
    "winlogo",		(long) IDI_WINLOGO,
    NULL,		0,
};

TCL_OBJ_CMD(Wintcl_IcoObjCmd)
{
    HICON hIcon;
    int i, cmdIndex, result = TCL_OK;
    IcoInfo *icoPtr;

    static CONST84 char *commandNames[] = {
	"createfromfile", "delete", "hicon", "info", "load",
	"position", "setwindow", (char *) NULL
    };
    enum command {
	CMD_CREATE, CMD_DELETE, CMD_HICON, CMD_INFO, CMD_LOAD,
	CMD_POSITION, CMD_SETWINDOW
    };

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "option ?arg arg ...?");
	return TCL_ERROR;
    }

    /* parse the first parameter */
    result = Tcl_GetIndexFromObj(interp, objv[1], commandNames,
	    "option", 0, &cmdIndex);
    if (result != TCL_OK) {
	return result;
    }

    switch ((enum command) cmdIndex) {
	case CMD_CREATE: {
	    LPICONRESOURCE lpIR;
	    int pos;
	    if (objc < 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "icofilename");
		return TCL_ERROR;
	    }
	    lpIR = ReadIconFromICOFile(interp, Tcl_GetString(objv[2]));
	    if (lpIR == NULL) {
		Tcl_AppendResult(interp, "failed to read \"",
			Tcl_GetString(objv[2]), "\"", (char*)NULL);
		return TCL_ERROR;
	    }
	    hIcon = NULL;
	    for (i = 0; i < lpIR->nNumImages; i++) {
		/*take the first or a 32x32 16 color icon*/
		if (i==0 || (lpIR->IconImages[i].Height == 32
			&& lpIR->IconImages[i].Width == 32
			&& lpIR->IconImages[i].Colors == 4)) {
		    hIcon=lpIR->IconImages[i].hIcon;
		    pos=i;
		}
	    }
	    if (hIcon == NULL) {
		FreeIconResource(lpIR);
		Tcl_AppendResult(interp, "could not find an icon in \"",
			Tcl_GetString(objv[2]), "\"", (char*) NULL);
		return TCL_ERROR;
	    }
	    NewIcon(interp,hIcon,ICO_FILE,lpIR,pos);
	    return TCL_OK;
	}
	case CMD_DELETE: {
	    if (objc != 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "id");
		return TCL_ERROR;
	    }
	    if ((icoPtr = GetIcoPtr(interp, objv[2])) == NULL) {
		Tcl_ResetResult(interp);
		return TCL_OK;
	    }
	    FreeIcoPtr(interp, icoPtr);
	    return TCL_OK;
	}
	case CMD_HICON: {
	    char buffer[4 + TCL_INTEGER_SPACE];

	    if (objc != 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "id");
		return TCL_ERROR;
	    }
	    if ((icoPtr = GetIcoPtr(interp, objv[2])) == NULL) {
		return TCL_ERROR;
	    }
	    sprintf(buffer, "0x%lx", (unsigned long) icoPtr->hIcon);
	    Tcl_SetResult(interp, buffer, TCL_VOLATILE);
	    return TCL_OK;
	}
	case CMD_INFO: {
	    if (objc == 2) {
		char buffer[4 + TCL_INTEGER_SPACE];

		for (icoPtr = firstIcoPtr; icoPtr != NULL;
		     icoPtr = icoPtr->nextPtr) {
		    sprintf(buffer, "ico#%d", icoPtr->id);
		    Tcl_AppendElement(interp, buffer);
		}
		return TCL_OK;
	    }
	    if (objc != 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "?id?");
		return TCL_ERROR;
	    }
	    if ((icoPtr = GetIcoPtr(interp, objv[2])) == NULL) {
		return TCL_ERROR;
	    }
	    if (icoPtr->itype == ICO_LOAD) {
		char buffer[200];
		sprintf(buffer,
			"{-pos 0 -width 32 -height 32 -bpp 4 -hicon 0x%lx -ptr 0x0}",
			(unsigned long) icoPtr->hIcon);
		Tcl_SetResult(interp, buffer, TCL_VOLATILE);
	    } else {
		Tcl_Obj *objPtr, *elemPtr;
		char buffer[64];
		objPtr = Tcl_NewObj();
		for (i = 0; i < icoPtr->lpIR->nNumImages; i++) {
		    elemPtr = Tcl_NewObj();
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewStringObj("-pos", -1));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewIntObj(i));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewStringObj("-width", -1));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewIntObj(icoPtr->lpIR->IconImages[i].Width));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewStringObj("-height", -1));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewIntObj(icoPtr->lpIR->IconImages[i].Height));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewStringObj("-bpp", -1));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewIntObj(icoPtr->lpIR->IconImages[i].Colors));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewStringObj("-hicon", -1));
		    sprintf(buffer,"0x%lx", (unsigned long) icoPtr->lpIR->IconImages[i].hIcon);
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewStringObj(buffer, -1));
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewStringObj("-ptr", -1));
		    sprintf(buffer,"0x%lx", (unsigned long) icoPtr->lpIR);
		    Tcl_ListObjAppendElement(NULL, elemPtr,
			    Tcl_NewStringObj(buffer, -1));

		    Tcl_ListObjAppendElement(NULL, objPtr, elemPtr);
		}
		Tcl_SetObjResult(interp, objPtr);
	    }
	    return TCL_OK;
	}
	case CMD_LOAD: {
	    int number;
	    char* arg;
	    HINSTANCE hinst = Ico_GetHINSTANCE();

	    if (objc < 3 || objc > 4) {
		Tcl_WrongNumArgs(interp, 2, objv,
			"resourceNameOrNumber ?dllname?");
		return TCL_ERROR;
	    }
	    if (objc > 3) {
		hinst = LoadLibrary(Tcl_GetString(objv[3]));
		if (hinst == NULL) {
		    Tcl_AppendResult(interp, "could not load dll \"",
			    Tcl_GetString(objv[3]), "\"", (char*)NULL);
		    return TCL_ERROR;
		}
	    }
	    if (Tcl_GetIntFromObj(interp, objv[2], &number) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if (number > 32511) {
		hinst = NULL;
		hIcon = LoadIcon(hinst, MAKEINTRESOURCE(number));
		if (hIcon != NULL) {
		    NewIcon(interp, hIcon, ICO_LOAD, NULL, 0);
		    return TCL_OK;
		}
	    }
	    Tcl_ResetResult(interp);
	    
	    if (Cmd_GetValue(NULL, g_StdIcons, Tcl_GetString(objv[2]),
			(long *)&arg) != TCL_OK) {
		arg = Tcl_GetString(objv[2]);
	    } else {
		hinst = NULL;
	    }
	    if ((hIcon = LoadIcon(hinst,arg)) == NULL) {
		Tcl_AppendResult(interp, "could not find a resource for \"",
			Tcl_GetString(objv[2]), "\"", (char*) NULL);
		return TCL_ERROR;
	    }
	    NewIcon(interp, hIcon, ICO_LOAD, NULL, 0);
	    return TCL_OK;
	}
	case CMD_POSITION: {
	    if (objc < 3 || objc > 4) {
		Tcl_WrongNumArgs(interp, 2, objv, "id ?newposition?");
		return TCL_ERROR;
	    }
	    if ((icoPtr = GetIcoPtr(interp, objv[2])) == NULL) {
		return TCL_ERROR;
	    }
	    if (objc == 3 || icoPtr->itype == ICO_LOAD) {
		Tcl_SetIntObj(Tcl_GetObjResult(interp), icoPtr->iconpos);
	    } else {
		int newpos;
		if (Tcl_GetIntFromObj(interp, objv[3], &newpos) != TCL_OK) {
		    return TCL_ERROR;
		}
		if (newpos < 0 ||  newpos >= icoPtr->lpIR->nNumImages) {
		    Tcl_AppendResult(interp, "invalid new position",
			    (char*) NULL);
		    return TCL_ERROR;
		}
		icoPtr->iconpos = newpos;
		icoPtr->hIcon   = icoPtr->lpIR->IconImages[newpos].hIcon;
	    }
	    return TCL_OK;
	}
	case CMD_SETWINDOW: {
	    HWND h;
	    int iconpos, iconsize = ICON_BIG;

	    if (objc < 4 || objc > 6) {
		Tcl_WrongNumArgs(interp, 2, objv,
			"windowId id ?big|small? ?position?");
		return TCL_ERROR;
	    }
	    if (Cmd_WinNameOrHandle(interp, objv[2], &h, 1) == NULL) {
		return TCL_ERROR;
	    }
	    if ((icoPtr = GetIcoPtr(interp, objv[3])) == NULL) {
		return TCL_ERROR;
	    }
	    if (objc > 4) {
		if (!strcmp(Tcl_GetString(objv[4]), "small")) {
		    iconsize = ICON_SMALL;
		}
		else if (!strcmp(Tcl_GetString(objv[4]), "big")) {
		    iconsize = ICON_BIG;
		} else {
		    Tcl_WrongNumArgs(interp, 2, objv,
			    "windowId id ?big|small? ?position?");
		    return TCL_ERROR;
		}
	    }
	    if (objc > 5 && icoPtr->itype == ICO_FILE) {
		if (Tcl_GetIntFromObj(interp, objv[5], &iconpos) != TCL_OK) {
		    return TCL_ERROR;
		}
		if (iconpos < 0 || iconpos >= icoPtr->lpIR->nNumImages) {
		    Tcl_AppendResult(interp, "invalid position", (char*) NULL);
		    return TCL_ERROR;
		}
	    } else {
		iconpos = icoPtr->iconpos;
	    }
	    if (icoPtr->itype == ICO_FILE) {
		hIcon = icoPtr->lpIR->IconImages[iconpos].hIcon;
	    } else {
		hIcon = icoPtr->hIcon;
	    }
	    result = SendMessage(h, WM_SETICON, iconsize, (LPARAM) hIcon);
	    Tcl_SetIntObj(Tcl_GetObjResult(interp), result);
	    return TCL_OK;
	}
    }

    return result;
}

/*-----------------------------------------------------------------------------
 * Wintcl_TaskbarObjCmd --
 *   taskbar Windows statusbar control function.
 *-----------------------------------------------------------------------------
 */

TCL_OBJ_CMD(Wintcl_TaskbarObjCmd)
{
    HICON hIcon;
    int cmdIndex, result = TCL_OK;
    IcoInfo* icoPtr;
    int oper, newpos;
    char *txt = NULL, *callback = NULL;
    static char *errMsg =
	"id ?-callback script -pos iconPosition -text tooltipText?";
    static CONST84 char *barCmdNames[] = {
	"add", "cget", "configure", "delete", "text", (char *)NULL
    };
    enum barCmd {
	BARCMD_ADD, BARCMD_CGET, BARCMD_CONFIGURE, BARCMD_DELETE, BARCMD_TEXT
    };
    static CONST84 char *barCmdOpts[] = {
	"-callback", "-position", "-text", (char *)NULL
    };
    enum barCmdOpts {
	BAROPT_CALLBACK, BAROPT_POSITION, BAROPT_TEXT
    };

    if (objc < 3) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"option icoId ?arg arg ...?");
	return TCL_ERROR;
    }

    /* parse the first parameter */
    result = Tcl_GetIndexFromObj(interp, objv[1], barCmdNames,
	    "option", 0, &cmdIndex);
    if (result != TCL_OK) {
	return result;
    }

    if ((icoPtr = GetIcoPtr(interp, objv[2])) == NULL) {
	return TCL_ERROR;
    }
    hIcon = icoPtr->hIcon;
    txt   = icoPtr->taskbar_txt;

    switch ((enum barCmd) cmdIndex) {
	case BARCMD_ADD: {
	    if (objc < 3) {
		wrongArgs:
		Tcl_WrongNumArgs(interp, 2, objv, errMsg);
		return TCL_ERROR;
	    }
	    oper = NIM_ADD;
	    break;
	}
	case BARCMD_CGET: {
	    if (objc != 4) {
		Tcl_WrongNumArgs(interp, 2, objv, "option");
		return TCL_ERROR;
	    }
	    result = Tcl_GetIndexFromObj(interp, objv[3], barCmdOpts,
		    "option", 0, &cmdIndex);
	    if (result != TCL_OK) {
		return result;
	    }
	    switch ((enum barCmdOpts) cmdIndex) {
		case BAROPT_CALLBACK: {
		    Tcl_AppendResult(interp, icoPtr->taskbar_command,
			    (char*) NULL);
		    break;
		}
		case BAROPT_POSITION: {
		    Tcl_SetIntObj(Tcl_GetObjResult(interp), icoPtr->iconpos);
		    break;
		}
		case BAROPT_TEXT: {
		    Tcl_AppendResult(interp, icoPtr->taskbar_txt,
			    (char*) NULL);
		    break;
		}
	    }
	    return TCL_OK;
	}
	case BARCMD_CONFIGURE: {
	    if (objc < 3) {
		goto wrongArgs;
	    }
	    oper = NIM_MODIFY;
	    break;
	}
	case BARCMD_DELETE: {
	    if (objc < 3) {
		goto wrongArgs;
	    }
	    oper = NIM_DELETE;
	    break;
	}
	case BARCMD_TEXT: {
	    if (objc < 3 || objc > 4) {
		Tcl_WrongNumArgs(interp, 2, objv, "icoId ?string?");
		return TCL_ERROR;
	    }
	    if (objc > 3) {
		char *newtxt = Tcl_GetString(objv[3]);
		if (icoPtr->taskbar_txt != NULL) {
		    ckfree(icoPtr->taskbar_txt);
		}
		icoPtr->taskbar_txt = ckalloc(strlen(newtxt)+1);
		strcpy(icoPtr->taskbar_txt, newtxt);
	    }
	    Tcl_AppendResult(interp, icoPtr->taskbar_txt, (char*)NULL);
	    return TCL_OK;
	}
    }
    if (objc > 3) {
	for (objc -= 3, objv += 3; objc > 1; objc -= 2, objv += 2) {
	    result = Tcl_GetIndexFromObj(interp, objv[0], barCmdOpts,
		    "taskbar option", 0, &cmdIndex);
	    if (result != TCL_OK) {
		return result;
	    }
	    switch ((enum barCmdOpts) cmdIndex) {
		case BAROPT_CALLBACK: {
		    callback = Tcl_GetString(objv[1]);
		    break;
		}
		case BAROPT_POSITION: {
		    if (Tcl_GetIntFromObj(interp, objv[1], &newpos)
			    != TCL_OK) {
			return TCL_ERROR;
		    }
		    if (icoPtr->itype == ICO_FILE) {
			if (newpos < 0 || newpos >= icoPtr->lpIR->nNumImages) {
			    Tcl_AppendResult(interp, "invalid position \"",
				    Tcl_GetString(objv[1]), "\"",
				    (char*) NULL);
			    return TCL_ERROR;
			}
			hIcon = icoPtr->lpIR->IconImages[newpos].hIcon;
		    }
		    break;
		}
		case BAROPT_TEXT: {
		    txt = Tcl_GetString(objv[1]);
		    break;
		}
	    }
	}
	if (objc == 1) {
	    goto wrongArgs;
	}
    }
    if (callback != NULL) {
	if (icoPtr->taskbar_command != NULL) {
	    ckfree((char *) icoPtr->taskbar_command);
	}
	icoPtr->taskbar_command = ckalloc(strlen(callback)+1);
	strcpy(icoPtr->taskbar_command, callback);
    }
    return TaskbarOperation(interp, icoPtr, oper, hIcon, txt);
}
