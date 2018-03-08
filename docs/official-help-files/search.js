
// Highlight matched words in results
var Highlighting = 0;           // 0 = off, 1 = on
var HighlightColor = "#FFFF40"; // Highlight colour
var HighlightLimit = 1000;      // Max number of words matched before
                                // highlighting is disabled

// The options available in the dropdown menu for number of results
// per page
var PerPageOptions = new Array(10, 20, 50, 100);

var FormFormat = 2;    //0 = No search form (note that you must pass parameters to
                       //    the script directly from elsewhere on your website).
                       //1 = Basic search form
                       //2 = Advanced search form (with options)

var OutputStyle = 1;    //0 = Basic Style, Page Title, Score and URL
                        //1 = Descriptive Style, Match number, Page Title,
                        //    Page description, Score and URL

var ZoomInfo = 1;       //0 = Don't display Zoom info line at bottom of search
                        //1 = Display Zoom info line at bottom of search

var WordSplit = 1;      //0 = Only split input search phrase into words when a
                        //    Space character is found
                        //1 = Split input search phrase at Space ' ',
                        //    UnderScore '_' , Dash '-' and Plus '+' characters

var Timing = 0;         // 0 = Do not display and calculate search time
                        // 1 = Display and calculate search time

var UseUTF8 = 0;        // 0 = do not use UTF-8 for search parameters
                        // 1 = use UTF-8 encoding for search parameters

var SearchAsSubstring = 0;  // 0 = do not force substring search, word must match entirely
                            // 1 = force substring search for all searchwords

var ToLowerSearchWords = 1; // 0 = Do not change search words to lowercase (for non-alphabetic languages)
                            // 1 = Change search words to lowercase (for alphanumeric languages)


// ----------------------------------------------------------------------------
// Helper Functions
// ----------------------------------------------------------------------------

// This function will return the value of a GET parameter
function getParam(paramName)
{
    paramStr = document.location.search;
    if (paramStr == "")
        return "";

    // remove '?' in front of paramStr
    if (paramStr.charAt(0) == "?")
        paramStr = paramStr.substring(1, paramStr.length);

    arg = (paramStr.split("&"));
    for (i=0; i < arg.length; i++) {
        arg_values = arg[i].split("=")
        if (unescape(arg_values[0]) == paramName) {
            if (UseUTF8 == 1 && self.decodeURIComponent) // check if decodeURIComponent() is defined
                ret = decodeURIComponent(arg_values[1]);
            else
                ret = unescape(arg_values[1]);  // IE 5.0 and older does not have decodeURI
            return ret;
        }
    }
    return;
}

// Compares the two values, used for sorting output results
// Results that match all search terms are put first, highest score
function SortCompare (a, b)
{
    if (a[2] < b[2]) return 1;
    else if (a[2] > b[2]) return -1;
    else if (a[1] < b[1]) return 1;
    else if (a[1] > b[1]) return -1;
    else return 0;
}

function pattern2regexp(pattern) {
    pattern = pattern.replace(/\./g, "\\.");
    pattern = pattern.replace(/\*/g, ".*");
    pattern = pattern.replace(/\?/g, ".?");
    if (SearchAsSubstring == 1)
        return pattern;

    return "^" + pattern + "$";
}

function HighlightDescription(line) {
    res = " " + line + " ";
    for (i = 0; i < matchwords_num; i++) {
        // replace with marker text, assumes [;:] and [:;] is not the search text...
        // can not use \\b due to IE's regexp bug with foreign diacritic characters
        // treated as non-word characters
        res = res.replace(new RegExp("([\\s\.\,\:]+)("+matchwords[i]+")([\\s\.\,\:]+)", "gi"), "$1[;:]$2[:;]$3");
    }
    // replace the marker text with the html text
    // this is to avoid finding previous <span>'ed text.
    res = res.replace(/\[;:\]/g, "<span style=\"background: " + HighlightColor + "\">");
    res = res.replace(/\[:;\]/g, "</span>");
    return res;
}

// ----------------------------------------------------------------------------
// Parameters initialisation (globals)
// ----------------------------------------------------------------------------

var query = getParam("zoom_query");
query = query.replace(/\+/g, " ");  // replace the '+' with spaces

var per_page = parseInt(getParam("zoom_per_page"));
if (isNaN(per_page)) per_page = 10;

var page = parseInt(getParam("zoom_page"));
if (isNaN(page)) page = 1;

var andq = parseInt(getParam("zoom_and"));
if (isNaN(andq)) andq = 0;

var cat = parseInt(getParam("zoom_cat"));
if (isNaN(cat)) cat = -1;   // search all categories

if (typeof(catnames) != "undefined" && typeof(catpages) != "undefined")
    UseCats = true;
else
    UseCats = false;

var searchWords = new Array();
var data = new Array();
var output = new Array();

if (Highlighting == 1) {
    var matchwords = new Array();
    var matchwords_num = 0;
}


// ----------------------------------------------------------------------------
// Main search function starts here
// ----------------------------------------------------------------------------

function ZoomSearch() {

    if (Timing == 1) {
        timeStart = new Date();
    }

    // Display the form
    if (FormFormat > 0) {
        document.writeln("<form method=\"GET\" action=\"" + document.location.href + "\">");
        document.writeln("<input type=\"text\" name=\"zoom_query\" size=\"20\" value=\"" + query + "\">");
        document.writeln("<input type=\"submit\" value=\"Search\">");
        if (FormFormat == 2) {
            document.writeln("<small>Results per page:");
            document.writeln("<select name='zoom_per_page'>");
            for (i = 0; i < PerPageOptions.length; i++) {
                document.write("<option");
                if (PerPageOptions[i] == per_page)
                    document.write(" selected=\"selected\"");
                document.writeln(">" + PerPageOptions[i] + "</option>");
            }
            document.writeln("</select></small></p>");
            if (UseCats) {
                document.write("Category: ");
                document.write("<select name='zoom_cat'>");
                // 'all cats option
                document.write("<option value=\"-1\">All</option>");
                for (i = 0; i < catnames.length; i++) {
                    document.write("<option value=\"" + i + "\"");
                    if (i == cat)
                        document.write(" selected=\"selected\"");
                    document.writeln(">" + catnames[i] + "</option>");
                }
                document.writeln("</select>&nbsp;&nbsp;");
            }

            document.writeln("<small>Match: ");
            if (andq == 0) {
                document.writeln("<input type=\"radio\" name=\"zoom_and\" value=\"0\" checked>any search words");
                document.writeln("<input type=\"radio\" name=\"zoom_and\" value=\"1\">all search words");
            } else {
                document.writeln("<input type=\"radio\" name=\"zoom_and\" value=\"0\">any search words");
                document.writeln("<input type=\"radio\" name=\"zoom_and\" value=\"1\" checked>all search words");
            }
            document.writeln("</small>");
        }
        document.writeln("</form>");
    }

    // give up early if no search words provided
    if (query.length == 0) {
        //document.writeln("No search query entered.<br>");
        if (ZoomInfo == 1)
            document.writeln("");
        return;
    }

    if (WordSplit == 1)
        query = query.replace(/[\+\_]/g, " "); // replace '+', '_' with spaces.

    // split search phrase into words
    searchWords = query.split(" "); // split by spaces.

    document.write("<h2>Search results for \"" + query + "\"");
    if (UseCats) {
        if (cat == -1)
            document.writeln(" in all categories");
        else
            document.writeln(" in category \"" + catnames[cat] + "\"");
    }
    document.writeln("</h2>");

    numwords = searchWords.length;
    kw_ptr = 0;
    outputline = 0;
    usewildcards = 0;
    ipage = 0;
    matches = 0;
    var SWord;
    pagesCount = urls.length;

    // Initialise a result table the size of all pages
    res_table = new Array(pagesCount);
    for (i = 0; i < pagesCount; i++)
    {
        res_table[i] = new Array(2);
        res_table[i][0] = 0;
        res_table[i][1] = 0;
    }

    // Begin searching...
    for (sw = 0; sw < numwords; sw++) {

        if (searchWords[sw].indexOf("*") == -1 && searchWords[sw].indexOf("?") == -1) {
            UseWildCards = 0;
        } else {
            UseWildCards = 1;
            if (ToLowerSearchWords == 0)
                re = new RegExp(pattern2regexp(searchWords[sw]), "g");
            else
                re = new RegExp(pattern2regexp(searchWords[sw]), "gi");
        }

        for (kw_ptr = 0; kw_ptr < keywords.length; kw_ptr++) {

            data = keywords[kw_ptr].split(",");

            if (UseWildCards == 0) {
                if (ToLowerSearchWords == 0)
                    SWord = searchWords[sw];
                else
                    SWord = searchWords[sw].toLowerCase();

                if (SearchAsSubstring == 0)
                    //match_result = data[0].lastIndexOf(SWord, 0);
                    match_result = data[0].search("^" + SWord + "$");
                else
                    match_result = data[0].indexOf(SWord);
            } else
                match_result = data[0].search(re);


            if (match_result != -1) {
                // keyword found, include it in the output list

                if (Highlighting == 1) {
                    // Add to matched words list
                    // Check if its already in the list
                    for (i = 0; i < matchwords.length && matchwords[i] != data[0]; i++);
                    if (i == matchwords.length) {
                        // not in list
                        matchwords_num = matchwords.push(data[0]);
                        if (matchwords.length >= HighlightLimit) {
                            Highlighting = 0;
                            document.writeln("<small>Too many words to highlight. Highlighting disabled.</small><br><br>");
                        }
                    }
                }

                for (kw = 1; kw < data.length; kw += 2) {
                    // check if page is already in output list
                    pageexists = 0;
                    ipage = data[kw];
                    if (res_table[ipage][0] == 0) {
                        matches++;
                        res_table[ipage][0] += parseInt(data[kw+1]);
                    }
                    else {

                        if (res_table[ipage][0] > 10000) {
                            // take it easy if its too big to prevent gigantic scores
                            res_table[ipage][0] += 1;
                        } else {
                            res_table[ipage][0] += parseInt(data[kw+1]); // add in score
                            res_table[ipage][0] *= 2;           // double score as we have two words matching
                        }
                    }
                    res_table[ipage][1] += 1;
                }
                if (UseWildCards == 0 && SearchAsSubstring == 0)
                    break;    // this search word was found, so skip to next

            }
        }

    }

    // Count number of output lines that match ALL search terms
    oline = 0;
    fullmatches = 0;
    ResFiltered = false;
    output = new Array();
    for (i = 0; i < pagesCount; i++) {
        IsFiltered = false;
        if (res_table[i][0] != 0) {
            if (UseCats && cat != -1) {
                // using cats and not doing an "all cats" search
                if (catpages[i] != cat) {
                    IsFiltered = true;
                }
            }
            if (IsFiltered == false) {
                if (res_table[i][1] >= numwords) {
                    fullmatches++;
                } else {
                    if (andq == 1)
                        IsFiltered = true;
                }
            }
            if (IsFiltered == false) {
                // copy if not filtered out
                output[oline] = new Array(3);
                output[oline][0] = i;
                output[oline][1] = res_table[i][0];
                output[oline][2] = res_table[i][1];
                oline++;
            } else {
                ResFiltered = true;
            }
        }
    }
    if (ResFiltered == true)
        matches = output.length;

    // Sort results in order of score, use "SortCompare" function
    if (matches > 1)
        output.sort(SortCompare);

    //Display search result information
    document.writeln("<small>");
    if (matches == 1)
        document.writeln("<i>1 result found.</i><br>");
    else if (matches == 0)
        document.writeln("<i>No results found.</i><br>");
    else if (numwords > 1 && andq == 0) {
        //OR
        SomeTermMatches = matches - fullmatches;
        document.writeln("<i>" + fullmatches + " pages found containing all search terms. ");
        if (SomeTermMatches > 0)
            document.writeln(SomeTermMatches + " pages found containing some search terms.");
        document.writeln("</i><br>");
    }
    else if (numwords > 1 && andq == 1) //AND
        document.writeln("<i>" + fullmatches + " pages found containing all search terms.</i><br>");
    else
        document.writeln("<i>" + matches + " results found.</i><br>");

    document.writeln("</small>\n");

    // number of pages of results
    num_pages = Math.ceil(matches / per_page);
    if (num_pages > 1)
        document.writeln("<br>" + num_pages + " pages of results.<br>\n");

    // determine current line of result from the output array
    if (page == 1) {
        arrayline = 0;
    } else {
        arrayline = ((page - 1) * per_page);
    }

    // the last result to show on this page
    result_limit = arrayline + per_page;


    // display the results
    while (arrayline < matches && arrayline < result_limit) {
        ipage = output[arrayline][0];
        score = output[arrayline][1];
        if (OutputStyle == 0) {
            // basic style
            document.writeln("<p>Page: <a href=\"" + urls[ipage] + "\">" + titles[ipage] + "</a><br>\n");
            document.writeln("Score: " + score + "&nbsp;&nbsp;<small><i>URL:" + urls[ipage] + "</i></small></p>\n");
        } else {
            // descriptive style
            document.writeln("<p><b>" + (arrayline+1) + ".</b>&nbsp;<a href=\"" + urls[ipage] + "\">" + titles[ipage] + "</a>");
            if (UseCats) {
                catindex = catpages[ipage];
                document.writeln(" <font color=\"#999999\">[" + catnames[catindex] + "]</font>");
            }
            document.writeln("<br>");

            if (Highlighting == 1)
                document.writeln(HighlightDescription(descriptions[ipage]));
            else
                document.writeln(descriptions[ipage]);
            document.writeln("...<br>\n");
            document.writeln("<font color=\"#999999\"><small><i>Terms matched: " + output[arrayline][2] + " Score: " + score + "&nbsp;&nbsp;URL: " + urls[ipage] + "</i></small></font></p>\n");
        }
        arrayline++;
    }


    // Show links to other result pages
    if (num_pages > 1) {
        // 10 results to the left of the current page
        start_range = page - 10;
        if (start_range < 1)
            start_range = 1;

        // 10 to the right
        end_range = page + 10;
        if (end_range > num_pages)
            end_range = num_pages;

        document.writeln("<p>Result Pages: ");
        if (page > 1)
            document.writeln("<a href=\"" + document.location.pathname + "?zoom_query=" + query + "&zoom_page=" + (page-1) + "&zoom_per_page=" + per_page + "&zoom_cat=" + cat + "&zoom_and=" + andq + "\">&lt;&lt; Previous</a> ");

        for (i = start_range; i <= end_range; i++) {
            if (i == page) {
                document.writeln(page + " ");
            } else {
                document.writeln("<a href=\"" + document.location.pathname + "?zoom_query=" + query + "&zoom_page=" + i + "&zoom_per_page=" + per_page + "&zoom_cat=" + cat + "&zoom_and=" + andq + "\">" + i + "</a> ");
            }
        }

        if (page != num_pages)
            document.writeln("<a href=\"" + document.location.pathname + "?zoom_query=" + query + "&zoom_page=" + (page+1) + "&zoom_per_page=" + per_page + "&zoom_cat=" + cat + "&zoom_and=" + andq + "\">Next &gt;&gt;</a> ");
    }

    document.writeln("<br><br>");

    if (ZoomInfo == 1)
        document.writeln("");

    if (Timing == 1) {
        timeEnd = new Date();
        timeDifference = timeEnd - timeStart;
        document.writeln("<br><br><small>Search took: " + (timeDifference/1000) + " seconds</small>\n");
    }

}

