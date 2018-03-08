/* Copyright (c) 2018 ActiveState Corp.
 * See the file LICENSE for licensing information.
 *
 * Based on:
 * ------------------------------------------------------------------------
 * Author's Statement:
 *
 * This script is based on ideas of the author. You may copy, modify and
 * use it for any purpose. The only condition is that if you publish web
 * pages that use this script you point to its author at a suitable place
 * and don't remove this Statement from it. It's your responsibility to
 * handle possible bugs even if you didn't modify anything. I cannot
 * promise any support.
 *
 * Dieter Bungers
 *
 * GMD (www.gmd.de) and infovation (www.infovation.de)
 * ------------------------------------------------------------------------
 */


//---- logging support

var _LOGGING_ENABLED = false;

function _log(msg) {
    if (!_LOGGING_ENABLED) return;
    try {
        if (typeof(window._log_initialized) == "undefined")
        {
            //XXX Should make this robust for multiple 0 or >1 body tags. And
            //    add support for namespaced HTML tags.
            var body = document.getElementsByTagName("body")[0];
            if (typeof(body) == "undefined") { // in some frames
                window._log_initialized = false;
            } else {
                var textarea = document.createElement("textarea");
                textarea.setAttribute("rows", "10");
                textarea.setAttribute("id", "_log");
                textarea.setAttribute("readonly", "true");
                //XXX This style doesn't work in IE. Great. At some point
                //    change to something other than a textbox, allow markup,
                //    and manually do the scrollbar thing, if possible.
                textarea.setAttribute("style", "width: 100%;");
                body.insertBefore(textarea, body.firstChild);
                window._log_initialized = true;
            }
        }
        if (window._log_initialized) {
            var statusArea = document.getElementById("_log");
            statusArea.value += msg + "\n";
        }
    } catch(ex) {
        alert("error in _log(): "+ex);
    }
}


//---- mainline

var mdi;
if (typeof(textSizes) != 'undefined') {
    if (navigator.appName.toLowerCase().indexOf("explorer") > -1) {
        mdi=textSizes[1], sml=textSizes[2];
    } else {
        mdi=textSizes[3], sml=textSizes[4];
    }
}

function getCurrentTargetHref(anchorName) {
    // Find the entry in tocTab that corresponds to the named anchor
    // The anchor doesn't have the file-specific bit, so we need to
    // look at the current file's href to figure out what URL
    // we're currently in, add the anchor, and then look for that.
    var currentHref;
    currentHref = self.location.href;
    if (currentHref.indexOf('#') != -1) {
        // strip current anchor
        currentHref = currentHref.slice(0, currentHref.indexOf('#'));
    }
    if (currentHref.indexOf('/') != -1) {
        // strip leading path bits
        currentHref = currentHref.slice(currentHref.lastIndexOf('/')+1,
                                        currentHref.length);
    }
    if (currentHref.indexOf('\\') != -1) {
        // strip leading path bits
        currentHref = currentHref.slice(currentHref.lastIndexOf('\\')+1,
                                        currentHref.length);
    }
    return currentHref + '#' + anchorName;
}

function getTocNodeId(targetHref) {
    var nodeId = '0';
    for (var i = 0; i < tocTab.length; i++) {
        if (tocTab[i][2] == targetHref) {
            nodeId = tocTab[i][0];
            break
        }
    }
    _log("getTocNodeId(targetHref='"+targetHref+"'): nodeId='"+nodeId+"'");
    return nodeId;
}


// Split the given URL at the root of this document set.
//
//  "path" is the full current URL.
//  "docPage" is the relative doc page URL.
//  "depth" is the directory depth of the docPage in the document set.
//
// Returns an object with "dirname" and "docPage" attributes. The "docPage"
// is escaped for inclusion in a URL query fragment.
function docPageFromPath(path, docPage, depth) {
    _log("docPageFromPath(path='"+path+"', docPage='"+docPage+
         "', depth="+depth+"):");
    path = path.replace(/\\/g, '/'); // Normalize path seps in IE on Windows.
    var dirname = path.substring(0, path.lastIndexOf('/'));
    for (var i=0; i < depth; i++) {
        docPage = dirname.substring(dirname.lastIndexOf('/')+1) + '/' + docPage;
        dirname = dirname.substring(0, dirname.lastIndexOf('/'));
    }
    var ret = new Object();
    ret.dirname = dirname;
    ret.docPage = docPage;
    _log("   dirname: '"+dirname+"'");
    _log("   docPage: '"+docPage+"'");
    return ret;
}


// Return an appropriate URL for showing/hiding the TOC.
//
//  "docPage" is the relative Komodo doc page (and anchor) for the content
//      frame.
//
// To show the TOC we want a URL of the form:
//      <url to Komodo's index.html>?page=<docPage>
// To hide the TOC we want a URL of the form:
//      <url to base Komodo doc dir>/<docPage>
//
// We want to show the TOC when we are not in a frameset and vice versa.
function toggleFrameURL(docPage, depth /* =0 */)
{
    if (typeof(depth) == 'undefined') depth=0;
    _log("toggleFrameURL(docPage='"+docPage+"', depth="+depth+")");

    var url, path, dirname;
    if (top == window) {
        // We're not in a frameset: want to show the TOC.
        var info = docPageFromPath(self.location.pathname, docPage, depth);
        var escapedDocPage = info.docPage.replace(/\//g, "%2F"); // bug 32870
        url = self.location.protocol + '//' + self.location.host +
              info.dirname + '/index.html?page=' + escapedDocPage;
    } else {
        // We're in a frameset: want to hide the TOC.
        path = window.location.pathname;
        path = path.replace(/\\/g, '/'); // Normalize path seps in IE on Windows.
        dirname = path.substring(0, path.lastIndexOf('/'));
        url = unescape(dirname+'/'+docPage);
    }
    return url;
}


// Return an appropriate URL for syncing the TOC to the current page and
// anchor.
//
//  "docPage" is relative Komodo doc page (and anchor) for the content
//      frame.
function syncFrameURL(docPage, anchorName, depth) {
    if (typeof(depth) == 'undefined') depth = 0;
    var url;
    if (top == window) {
        // We are not in a frameset (i.e. the TOC is not showing), therefore
        // we want to do the same thing as "Show/Hide TOC".
        url = toggleFrameURL(docPage, depth);
    } else {
        // The TOC is showing: we want to re-display the TOC at the current
        // doc page.
        var info = docPageFromPath(unescape(self.location.pathname),
                                   unescape(docPage), depth);
        var nodeId = getTocNodeId(info.docPage);
        url = 'javascript:top.reDisplay(\''+nodeId+'\',true);';
    }
    return url;
}



// Re-display the TOC and possibly change the content frame.
//
//  "changeContent" is a boolean (default true) indicating if this
//      re-display should change the content frame URL. This is set to
//      false for the +/- icons so that the TOC can be manipulated without
//      changing the content.
//
function reDisplay(currentNumber, currentIsExpanded,
                   changeContent /* =true */) {
                   top.TclDevKitDoc.location.href = theHref;
}


function getPage() {
    var string = top.location.search.substring(1);
    var parm = 'page';
    var pageLink = null;
    // returns value of parm from string
    var startPos = string.indexOf(parm + "=");
    if (startPos > -1) {
        startPos = startPos + parm.length + 1;
        var endPos = string.indexOf("&",startPos);
        if (endPos == -1)
            endPos = string.length;
        pageLink = unescape(string.substring(startPos,endPos));
    }
    if (pageLink) {
        top.TclDevKitDoc.location.href = pageLink;
    }
}
