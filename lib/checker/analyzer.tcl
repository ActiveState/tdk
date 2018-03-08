# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# analyzer.tcl -- -*- tcl -*-
#
#	This file initializes the analyzer.
#
# Copyright (c) 2002-2009 ActiveState Software Inc.
# Copyright (c) 1998-2000 Ajuba Solutions

#
# RCS: @(#) $Id: analyzer.tcl,v 1.13 2000/10/31 23:30:53 welch Exp $

package provide analyzer 1.0
package require Tcl 8.5
package require md5 2 ; # md5 hash, option -hex supported
package require struct::stack

##package require configure

## TODO Some code belongs in coreTcl, this dependency comes from it.
package require pcx
package require log ; # Tcllib | Logging and Tracing

namespace eval analyzer {

    namespace export \
	    addCheckers addUserProc addWidgetOptions checkBoolean \
	    checkArgList checkScript checkBody checkChannelID checkColor \
	    checkCommand checkConfigure checkContext checkEvalArgs  \
	    checkExpr checkFileName checkFloatConfigure checkIndex \
	    checkIndexExpr checkInt checkFloat checkKeyword checkList \
	    checkListValues checkNamespacePattern checkOption \
	    checkWidgetOptions checkRedefined checkVariable checkWholeNum \
	    checkSimpleArgs checkSwitches checkVarName checkProcName \
	    checkProcCall checkWinName checkWord checkVarNameWrite \
            getLiteral getLiteralPos getScript getTokenRange isLiteral \
	    getLiteralRange checkNumArgs checkVersion checkSwitchArg \
	    logError matchKeyword pushChecker popChecker setCmdRange \
            topChecker init getTokenType getTokenString getTokenChildren \
	    getTokenNumChildren checkBodyOffset checkVarNameDecl \
	    logOpen logGet checkPackageName checkPkgVersion checkValidateBody \
	    checkVarNameSyntax checkAll checkDynLit checkDoubleDash \
	    checkExtendedIndexExpr checkSequence checkRequirement \
	    checkExtVersion checkDict checkNOP checkAccessModeB \
	    checkExtensibleConfigure checkArrayVarName checkDictValues \
	    checkConstrained checkSetConstraints checkConstraint \
            checkSetConstraint checkResetConstraint checkRegexp \
	    checkAtEnd checkNamespace checkConstraintAll checkSetStyle \
	    logExtendedError CorrectionsOf InvalidUsage WarnUnsupported \
	    WarnDeprecated WarnObsoleteCmd checkVarNameReadWrite \
            checkOrdering checkOrderLoop checkOrderOf checkOrderBranch \
	    checkOrderBranches checkAsStyle checkNextArgs checkSimpleArgsModNk \
	    checkListValuesModNk checkNatNum checkIndexExprExtend

    # The true script to use in error messages, if a checker
    # manipulates the analyzed script to get special things
    # done. Example: checking bind scripts has to deal with
    # %-placeholder and make them palatable to the standard checkers
    # invoked for the bind-script.

    variable trueScript {}

    # The twopass var is set to 1 when Checker should scan for
    # user defined procs, otherwise it will only analyze files
    # skipping the scan and collate phases.

    variable twoPass 1

    # The quiet var is set to 1 when the message should
    # print a minimal amount of output.

    variable quiet 0

    # The verbose var is set to 1 when we want to print summary
    # information.

    variable verbose 0

    # True if the current phase is scanning.

    variable scanning 0

    # Stores the set of command-specific checkers currently defined
    # for the global context.

    variable  checkers
    array set checkers {}

    # Stores the set of commands to be scanned for proc definitions.
    # (e.g., proc, namespace eval, and class)
    variable  scanCmds
    array set scanCmds {}

    # Log state. List of messages for the current level, log nesting
    # level we are at, and the stack of captured messages in previous
    # levels.

    variable capture {}
    variable logLevel 0
    variable logStack {}

    # Nesting level of checkScript ... This information is mainly
    # needed for bug 77230 (R1.3), however now we create it for bug
    # 76841, to help in the early abort of an analyze when an -endline
    # was specified.

    variable scriptNesting  0
    variable bracketNesting 0

    # Nesting level of checkExpr, to note and warn about nested 'expr'
    # constructions which are superfluous at best.
    variable exprNesting 0

    variable nCmd [struct::stack]

    # Store a list of known widget option checkers.  For example, a
    # -background option should always use "checkColor"

    array set standardWidgetOpts {
	-activebackground checkColor
	-activeforeground checkColor
	-activerelief checkRelief
	-anchor {checkKeyword 0 {n ne e se s sw w nw center}}
	-background checkColor
	-bd checkPixels
	-bg checkColor
	-bigincrement checkFloat
	-bitmap checkWord
	-borderwidth checkPixels
	-class checkWord
	-closeenough checkFloat
	-colormap checkColormap
	-command {checkAsStyle body/single-line checkBody}
	-compound {checkKeyword 1 {none center bottom top left right}}
	-confine checkBoolean
	-container checkBoolean
	-cursor checkCursor
	-default {checkKeyword 1 {normal active disabled}}
	-digits checkInt
	-disabledbackground checkColor
	-disabledforeground checkColor
	-elementborderwidth checkPixels
	-exportselection checkBoolean
	-fg checkColor
	-font checkWord
	-foreground checkColor
	-from checkFloat
	-height checkPixels
	-highlightbackground checkColor
	-highlightcolor checkColor
	-highlightthickness checkPixels
	-image checkWord
	-indicatoron checkBoolean
	-insertbackground checkColor
	-insertborderwidth checkPixels
	-insertofftime checkInt
	-insertontime checkInt
	-insertwidth checkPixels
	-jump checkBoolean
	-justify {checkKeyword 0 {left center right}}
	-label checkWord
	-length checkPixels
	-menu checkWinName
	-offrelief checkRelief
	-offvalue checkWord
	-onvalue checkWord
	-orient {checkKeyword 0 {horizontal vertical}}
	-overrelief checkRelief
	-padding {checkListValues 1 4 checkPixels}
	-padx checkPixels
	-pady checkPixels
	-postcommand checkBody
	-readonlybackground checkColor
	-relief checkRelief
	-repeatdelay checkInt
	-repeatinterval checkInt
	-resolution checkFloat
	-scrollcommand checkWord
	-scrollregion {checkListValues 4 4 {checkPixels}}
	-selectbackground checkColor
	-selectborderwidth checkPixels
	-selectcolor checkColor
	-selectforeground checkColor
	-selectimage checkWord
	-selectmode {checkKeyword 1 {single browse multiple extended}}
	-setgrid checkBoolean
	-show checkWord
	-showvalue checkBoolean
	-sliderlength checkPixels
	-sliderrelief checkRelief
	-spacing1 checkPixels
	-spacing2 checkPixels
	-spacing3 checkPixels
	-state {checkKeyword 1 {normal active disabled}}
	-style checkWord
	-takefocus checkWord
	-text checkWord
	-textvariable checkVarNameWrite
	-tickinterval checkFloat
	-to checkFloat
	-tristateimage checkWord
	-tristatevalue checkWord
	-troughcolor checkColor
	-underline checkInt
	-validate {checkKeyword 1 {none focus focusin focusout key all}}
	-validatecommand {checkAsStyle body/single-line checkValidateBody}
	-value checkWord
	-values checkList
	-variable checkVarNameWrite
	-visual coreTk::checkVisual
	-width checkPixels
	-wrap {checkKeyword 1 {char none word}}
	-wraplength checkPixels
	-xscrollcommand checkWord
	-xscrollincrement checkPixels
	-yscrollcommand checkWord
	-yscrollincrement checkPixels
    }
    # Note: coreTk::checkVisual

    # Colors are only portable if they are defined in the tk?.?/xlib/xcolors.c
    # file.  The portableColors8.0 is the list of colors that are valid for
    # Tk8.0.  For now this is the only version checked.

    variable portableColors80 [list \
	    "alice blue" "AliceBlue" "antique white" "AntiqueWhite" "AntiqueWhite1" \
	    "AntiqueWhite2" "AntiqueWhite3" "AntiqueWhite4" "aquamarine" \
	    "aquamarine1" "aquamarine2" "aquamarine3" "aquamarine4" "azure" \
	    "azure1" "azure2" "azure3" "azure4" "beige" "bisque" "bisque1" \
	    "bisque2" "bisque3" "bisque4" "black" "blanched almond" \
	    "BlanchedAlmond" "blue" "blue violet" "blue1" "blue2" "blue3" "blue4" \
	    "BlueViolet" "brown" "brown1" "brown2" "brown3" "brown4" "burlywood" \
	    "burlywood1" "burlywood2" "burlywood3" "burlywood4" "cadet blue" \
	    "CadetBlue" "CadetBlue1" "CadetBlue2" "CadetBlue3" "CadetBlue4" \
	    "chartreuse" "chartreuse1" "chartreuse2" "chartreuse3" "chartreuse4" \
	    "chocolate" "chocolate1" "chocolate2" "chocolate3" "chocolate4" "coral" \
	    "coral1" "coral2" "coral3" "coral4" "cornflower blue" "CornflowerBlue" \
	    "cornsilk" "cornsilk1" "cornsilk2" "cornsilk3" "cornsilk4" "cyan" \
	    "cyan1" "cyan2" "cyan3" "cyan4" "dark blue" "dark cyan" \
	    "dark goldenrod" "dark gray" "dark green" "dark grey" "dark khaki" \
	    "dark magenta" "dark olive green" "dark orange" "dark orchid" "dark red" \
	    "dark salmon" "dark sea green" "dark slate blue" "dark slate gray" \
	    "dark slate grey" "dark turquoise" "dark violet" "DarkBlue" "DarkCyan" \
	    "DarkGoldenrod" "DarkGoldenrod1" "DarkGoldenrod2" "DarkGoldenrod3" \
	    "DarkGoldenrod4" "DarkGray" "DarkGreen" "DarkGrey" "DarkKhaki" \
	    "DarkMagenta" "DarkOliveGreen" "DarkOliveGreen1" "DarkOliveGreen2" \
	    "DarkOliveGreen3" "DarkOliveGreen4" "DarkOrange" "DarkOrange1" \
	    "DarkOrange2" "DarkOrange3" "DarkOrange4" "DarkOrchid" "DarkOrchid1" \
	    "DarkOrchid2" "DarkOrchid3" "DarkOrchid4" "DarkRed" "DarkSalmon" \
	    "DarkSeaGreen" "DarkSeaGreen1" "DarkSeaGreen2" "DarkSeaGreen3" \
	    "DarkSeaGreen4" "DarkSlateBlue" "DarkSlateGray" "DarkSlateGray1" \
	    "DarkSlateGray2" "DarkSlateGray3" "DarkSlateGray4" "DarkSlateGrey" \
	    "DarkTurquoise" "DarkViolet" "deep pink" "deep sky blue" "DeepPink" \
	    "DeepPink1" "DeepPink2" "DeepPink3" "DeepPink4" "DeepSkyBlue" \
	    "DeepSkyBlue1" "DeepSkyBlue2" "DeepSkyBlue3" "DeepSkyBlue4" "dim gray" \
	    "dim grey" "DimGray" "DimGrey" "dodger blue" "DodgerBlue" "DodgerBlue1" \
	    "DodgerBlue2" "DodgerBlue3" "DodgerBlue4" "firebrick" "firebrick1" \
	    "firebrick2" "firebrick3" "firebrick4" "floral white" "FloralWhite" \
	    "forest green" "ForestGreen" "gainsboro" "ghost white" "GhostWhite" \
	    "gold" "gold1" "gold2" "gold3" "gold4" "goldenrod" "goldenrod1" \
	    "goldenrod2" "goldenrod3" "goldenrod4" "gray" "gray0" "gray1" "gray10" \
	    "gray100" "gray11" "gray12" "gray13" "gray14" "gray15" "gray16" \
	    "gray17" "gray18" "gray19" "gray2" "gray20" "gray21" "gray22" "gray23" \
	    "gray24" "gray25" "gray26" "gray27" "gray28" "gray29" "gray3" "gray30" \
	    "gray31" "gray32" "gray33" "gray34" "gray35" "gray36" "gray37" "gray38" \
	    "gray39" "gray4" "gray40" "gray41" "gray42" "gray43" "gray44" "gray45" \
	    "gray46" "gray47" "gray48" "gray49" "gray5" "gray50" "gray51" "gray52" \
	    "gray53" "gray54" "gray55" "gray56" "gray57" "gray58" "gray59" "gray6" \
	    "gray60" "gray61" "gray62" "gray63" "gray64" "gray65" "gray66" "gray67" \
	    "gray68" "gray69" "gray7" "gray70" "gray71" "gray72" "gray73" "gray74" \
	    "gray75" "gray76" "gray77" "gray78" "gray79" "gray8" "gray80" "gray81" \
	    "gray82" "gray83" "gray84" "gray85" "gray86" "gray87" "gray88" "gray89" \
	    "gray9" "gray90" "gray91" "gray92" "gray93" "gray94" "gray95" "gray96" \
	    "gray97" "gray98" "gray99" "green" "green yellow" "green1" "green2" \
	    "green3" "green4" "GreenYellow" "grey" "grey0" "grey1" "grey10" \
	    "grey100" "grey11" "grey12" "grey13" "grey14" "grey15" "grey16" \
	    "grey17" "grey18" "grey19" "grey2" "grey20" "grey21" "grey22" "grey23" \
	    "grey24" "grey25" "grey26" "grey27" "grey28" "grey29" "grey3" "grey30" \
	    "grey31" "grey32" "grey33" "grey34" "grey35" "grey36" "grey37" "grey38" \
	    "grey39" "grey4" "grey40" "grey41" "grey42" "grey43" "grey44" "grey45" \
	    "grey46" "grey47" "grey48" "grey49" "grey5" "grey50" "grey51" "grey52" \
	    "grey53" "grey54" "grey55" "grey56" "grey57" "grey58" "grey59" "grey6" \
	    "grey60" "grey61" "grey62" "grey63" "grey64" "grey65" "grey66" "grey67" \
	    "grey68" "grey69" "grey7" "grey70" "grey71" "grey72" "grey73" "grey74" \
	    "grey75" "grey76" "grey77" "grey78" "grey79" "grey8" "grey80" "grey81" \
	    "grey82" "grey83" "grey84" "grey85" "grey86" "grey87" "grey88" "grey89" \
	    "grey9" "grey90" "grey91" "grey92" "grey93" "grey94" "grey95" "grey96" \
	    "grey97" "grey98" "grey99" "honeydew" "honeydew1" "honeydew2" \
	    "honeydew3" "honeydew4" "hot pink" "HotPink" "HotPink1" "HotPink2" \
	    "HotPink3" "HotPink4" "indian red" "IndianRed" "IndianRed1" \
	    "IndianRed2" "IndianRed3" "IndianRed4" "ivory" "ivory1" "ivory2" \
	    "ivory3" "ivory4" "khaki" "khaki1" "khaki2" "khaki3" "khaki4" \
	    "lavender" "lavender blush" "LavenderBlush" "LavenderBlush1" \
	    "LavenderBlush2" "LavenderBlush3" "LavenderBlush4" "lawn green" \
	    "LawnGreen" "lemon chiffon" "LemonChiffon" "LemonChiffon1" \
	    "LemonChiffon2" "LemonChiffon3" "LemonChiffon4" "light blue" \
	    "light coral" "light cyan" "light goldenrod" "light goldenrod yellow" \
	    "light gray" "light green" "light grey" "light pink" "light salmon" \
	    "light sea green" "light sky blue" "light slate blue" \
	    "light slate gray" \
	    "light slate grey" "light steel blue" "light yellow" "LightBlue" \
	    "LightBlue1" \
	    "LightBlue2" "LightBlue3" "LightBlue4" "LightCoral" "LightCyan" \
	    "LightCyan1" "LightCyan2" "LightCyan3" "LightCyan4" "LightGoldenrod" \
	    "LightGoldenrod1" "LightGoldenrod2" "LightGoldenrod3" \
	    "LightGoldenrod4" \
	    "LightGoldenrodYellow" "LightGray" "LightGreen" "LightGrey" \
	    "LightPink" \
	    "LightPink1" "LightPink2" "LightPink3" "LightPink4" "LightSalmon" \
	    "LightSalmon1" "LightSalmon2" "LightSalmon3" "LightSalmon4" \
	    "LightSeaGreen" "LightSkyBlue" "LightSkyBlue1" "LightSkyBlue2" \
	    "LightSkyBlue3" "LightSkyBlue4" "LightSlateBlue" "LightSlateGray" \
	    "LightSlateGrey" "LightSteelBlue" "LightSteelBlue1" "LightSteelBlue2" \
	    "LightSteelBlue3" "LightSteelBlue4" "LightYellow" "LightYellow1" \
	    "LightYellow2" "LightYellow3" "LightYellow4" "lime green" "LimeGreen" \
	    "linen" "magenta" "magenta1" "magenta2" "magenta3" "magenta4" \
	    "maroon" \
	    "maroon1" "maroon2" "maroon3" "maroon4" "medium aquamarine" \
	    "medium blue" "medium orchid" "medium purple" "medium sea green"  \
	    "medium slate blue" "medium spring green" "medium turquoise" \
	    "medium violet red" "MediumAquamarine" "MediumBlue" "MediumOrchid" \
	    "MediumOrchid1" "MediumOrchid2" "MediumOrchid3" "MediumOrchid4" \
	    "MediumPurple" "MediumPurple1" "MediumPurple2" "MediumPurple3" \
	    "MediumPurple4" "MediumSeaGreen" "MediumSlateBlue" \
	    "MediumSpringGreen" \
	    "MediumTurquoise" "MediumVioletRed" "midnight blue" "MidnightBlue" \
	    "mint cream" "MintCream" "misty rose" "MistyRose" "MistyRose1" \
	    "MistyRose2" "MistyRose3" "MistyRose4" "moccasin" "navajo white" \
	    "NavajoWhite" "NavajoWhite1" "NavajoWhite2" "NavajoWhite3" \
	    "NavajoWhite4" "navy" "navy blue" "NavyBlue" "old lace" "OldLace" \
	    "olive drab" "OliveDrab" "OliveDrab1" "OliveDrab2" "OliveDrab3" \
	    "OliveDrab4" "orange" "orange red" "orange1" "orange2" "orange3" \
	    "orange4" "OrangeRed" "OrangeRed1" "OrangeRed2" "OrangeRed3" \
	    "OrangeRed4" "orchid" "orchid1" "orchid2" "orchid3" "orchid4" \
	    "pale goldenrod" "pale green" "pale turquoise" "pale violet red" \
	    "PaleGoldenrod" "PaleGreen" "PaleGreen1" "PaleGreen2" "PaleGreen3" \
	    "PaleGreen4" "PaleTurquoise" "PaleTurquoise1" "PaleTurquoise2" \
	    "PaleTurquoise3" "PaleTurquoise4" "PaleVioletRed" "PaleVioletRed1" \
	    "PaleVioletRed2" "PaleVioletRed3" "PaleVioletRed4" "papaya whip" \
	    "PapayaWhip" "peach puff" "PeachPuff" "PeachPuff1" "PeachPuff2" \
	    "PeachPuff3" "PeachPuff4" "peru" "pink" "pink1" "pink2" "pink3" \
	    "pink4" \
	    "plum" "plum1" "plum2" "plum3" "plum4" "powder blue" "PowderBlue" \
	    "purple" "purple1" "purple2" "purple3" "purple4" "red" "red1" "red2" \
	    "red3" "red4" "rosy brown" "RosyBrown" "RosyBrown1" "RosyBrown2" \
	    "RosyBrown3" "RosyBrown4" "royal blue" "RoyalBlue" "RoyalBlue1" \
	    "RoyalBlue2" "RoyalBlue3" "RoyalBlue4" "saddle brown" "SaddleBrown" \
	    "salmon" "salmon1" "salmon2" "salmon3" "salmon4" "sandy brown" \
	    "SandyBrown" "sea green" "SeaGreen" "SeaGreen1" "SeaGreen2" \
	    "SeaGreen3" \
	    "SeaGreen4" "seashell" "seashell1" "seashell2" "seashell3" \
	    "seashell4" \
	    "sienna" "sienna1" "sienna2" "sienna3" "sienna4" "sky blue" "SkyBlue" \
	    "SkyBlue1" "SkyBlue2" "SkyBlue3" "SkyBlue4" "slate blue" "slate gray" \
	    "slate grey" "SlateBlue" "SlateBlue1" "SlateBlue2" "SlateBlue3" \
	    "SlateBlue4" "SlateGray" "SlateGray1" "SlateGray2" "SlateGray3" \
	    "SlateGray4" "SlateGrey" "snow" "snow1" "snow2" "snow3" "snow4" \
	    "spring green" "SpringGreen" "SpringGreen1" "SpringGreen2" \
	    "SpringGreen3" \
	    "SpringGreen4" "steel blue" "SteelBlue" "SteelBlue1" "SteelBlue2" \
	    "SteelBlue3" "SteelBlue4" "tan" "tan1" "tan2" "tan3" "tan4" "thistle" \
	    "thistle1" "thistle2" "thistle3" "thistle4" "tomato" "tomato1" \
	    "tomato2" "tomato3" "tomato4" "turquoise" "turquoise1" "turquoise2" \
	    "turquoise3" "turquoise4" "violet" "violet red" "VioletRed" \
	    "VioletRed1" "VioletRed2" "VioletRed3" "VioletRed4" "wheat" "wheat1" \
	    "wheat2" "wheat3" "wheat4" "white" "white smoke" "WhiteSmoke" \
	    "yellow" \
	    "yellow green" "yellow1" "yellow2" "yellow3" "yellow4" "YellowGreen"]

    variable commonCursors [list \
	    "X_cursor" "arrow" "based_arrow_down" "based_arrow_up" "boat" \
	    "bogosity" "bottom_left_corner" "bottom_right_corner" \
	    "bottom_side" "bottom_tee" "box_spiral" "center_ptr" "circle" \
	    "clock" "coffee_mug" "cross" "cross_reverse" "crosshair" \
	    "diamond_cross" "dot" "dotbox" "double_arrow" "draft_large" \
	    "draft_small" "draped_box" "exchange" "fleur" "gobbler" "gumby" \
	    "hand1" "hand2" "heart" "icon" "iron_cross" "left_ptr" \
	    "left_side" "left_tee" "leftbutton" "ll_angle" "lr_angle" "man" \
	    "middlebutton" "mouse" "pencil" "pirate" "plus" "question_arrow" \
	    "right_ptr" "right_side" "right_tee" "rightbutton" "rtl_logo" \
	    "sailboat" "sb_down_arrow" "sb_h_double_arrow" "sb_left_arrow" \
	    "sb_right_arrow" "sb_up_arrow" "sb_v_double_arrow" "shuttle" \
	    "sizing" "spider" "spraycan" "star" "target" "tcross" \
	    "top_left_arrow" "top_left_corner" "top_right_corner" "top_side" \
	    "top_tee" "trek" "ul_angle" "umbrella" "ur_angle" "watch" "xterm"
    ]

    variable winCursors [list \
	    "starting" "no" "size" "size_ne_sw" "size_ns" "size_nw_se" \
	    "size_we" "uparrow" "wait"
    ]

    variable macCursors [list \
	    "text" "cross-hair"
    ]


    # The database of expr operators and functions known to the
    # checker. Maps from name/arity to number definitions.
    # Analogously for variadic operators (name/min/max).

    variable operators
    variable voperators

    # Version of coreTcl in use. Initialized once instead of checked
    # for every single command. More or less. Also results of the
    # common range checks on the version.

    variable coreTcl  {}
    variable after83  {}
    variable before84 {}
    variable before85 {}


    # stack of defered 'def' actions.

    variable defStack [struct::stack]
    variable defHold  [struct::stack]

}

proc analyzer::def'hold {} { variable twoPass ; if {$twoPass} return
    variable defStack
    variable defHold
    if {![$defStack size]} {
	$defHold push {}
    } elseif {[$defStack size] == 1} {
	$defHold push [list [$defStack pop]]
    } else {
	$defHold push [$defStack pop [$defStack size]]
    }
    return
}
proc analyzer::def'unhold {} { variable twoPass ; if {$twoPass} return
    variable defStack
    variable defHold
    set cmds [$defHold pop]
    if {![llength $cmds]} return
    $defStack push {*}$cmds
    return
}
proc analyzer::def'er {cmd} { variable twoPass ; if {$twoPass} { uplevel 1 $cmd ; return }
    variable defStack
    $defStack push $cmd
    return
}
proc analyzer::def'run {} { variable twoPass ; if {$twoPass} return
    variable defStack
    while {[$defStack size]} {
	{*}[$defStack pop]
    }
    return
}

proc analyzer::npush {cmd} {
    variable nCmd
    $nCmd push $cmd
    #puts push/$cmd
    return
}
proc analyzer::npop {} {
    variable nCmd
    $nCmd pop
    #puts pop
    return
}
proc analyzer::npeek {} {
    variable nCmd
    return [$nCmd peek [$nCmd size]]
}

# analyzer::initns --
#
#	Initialize the analyzer. This will set all global variables
#       to their respective initial value.
#
# Arguments:
#       None.
#
# Results:
#	None.

proc analyzer::initns {} {
    # Records the number of errors detected.
    variable errCount 0

    # Records the number of warnings detected.
    variable warnCount 0

    # Records the numbers messages, per message code
    variable    codeCount
    array set   codeCount {}
    array unset codeCount *

    # Records the name of the file being analyzed.
    variable file {}

    # Records the script currently being analyzed.
    variable script {}

    # Records the script currently being analyzed.
    variable scriptIsAscii 0
    # If a script has all 1-byte chars, we can do these efficient
    # translations of the 'parse' command:
    # 1. [parse charindex $script $range] == [lindex $range 0]
    # 2. [parse charlength $script $range] == [lindex $range 1]
    # 3. [parse getstring $script $range] ==
    #    [string range $script [lindex $range 0] \\n
    #		[expr {[lindex $range 0] + [lindex $range 1] - 1}]

    # Records the line number of the command currently being analyzed.
    variable currentLine 1

    # Records the range of the command currently being analyzed.
    variable cmdRange {}

    # Stores a stack of command range and line number pairs.
    variable cmdStack {}

    # Store a list of commands that need to be renamed within
    # a given context.
    variable inheritCmds
    catch {unset inheritCmds}
    array set inheritCmds {}

    # Store a list of commands that need to be renamed within
    # a given context.
    variable renameCmds
    catch {unset renameCmds}
    array set renameCmds {}

    # Store a list of patterns for commands that need to be exported
    # from a namespace.
    variable exportCmds
    catch {unset exportCmds}
    array set exportCmds {}

    # Store a list of patterns for commands that need to be imported
    # from a namespace.
    variable importCmds
    catch {unset importCmds}
    array set importCmds {}

    # Keep a table of commands that were executed but did not exists
    # in the user-defined proc list or the globally defined proc list.
    variable  unknownCmds
    array set unknownCmds {}

    variable  unknownCmdsLogged 0

    # Database of operators is initially empty.
    variable  operators
    array set operators {}

    variable  voperators
    array set voperators {}

    # Reset other internal variables
    catch {unset ::context::knownContext}
    array set ::context::knownContext {}

    # Database of per-file checker commands. Initially empty.
    variable perfile {}

    #::log::log debug "#%% ANA/init  [clock seconds] -- [clock format [clock seconds]]"
}

# analyzer::addPerfile --
#
#	Merge per-file checkers defined by a package checker with the
#	database.
#
# Arguments:
#	cmds	List.  Of command prefixes
#
# Results:
#	None.

proc ::analyzer::addPerfile {cmds} {
    variable perfile
    lappend perfile {*}$cmds
    set perfile [lsort -unique $perfile]
    return
}

# analyzer::addOps --
#
#	Merge math functions and operators defined by a package
#	checker with the operator database.
#
# Arguments:
#	ops	List.  Of operator names and arity (name/arity)
#
# Results:
#	None.

proc ::analyzer::addOps {ops} {
    variable operators
    foreach o $ops {
	# XXX AK NOTE: 8.5 incr TIP 215!
	if {[info exists operators($o)]} {
	    incr operators($o)
	} else {
	    set operators($o) 1
	}
    }
    return
}

# analyzer::addVOps --
#
#	Merge variadic math functions and operators defined by a package
#	checker with the operator database.
#
# Arguments:
#	ops	List.  Of variadic operator names and arities (name/min/max)
#
# Results:
#	None.

proc ::analyzer::addVOps {ops} {
    variable voperators
    foreach o $ops {
	# XXX AK NOTE: 8.5 incr TIP 215!
	if {[info exists voperators($o)]} {
	    incr voperators($o)
	} else {
	    set voperators($o) 1
	}
    }
    return
}

# analyzer::setTwoPass --
#
#	Set the twoPass bit to 1 or 0 depending on the type
#	of checking requested from the user.
#
# Arguments:
#	twoPassBit	Boolean.  Indicates if output should be terse.
#
# Results:
#	None.

proc analyzer::setTwoPass {twoPassBit} {
    variable twoPass $twoPassBit ; # Implicit 'set'
    return
}

# analyzer::isTwoPass --
#
#	Return the setting for the twoPass bit.
#
# Arguments:
#	None.
#
# Results:
#	Return 1 if we are in twoPass mode.

proc analyzer::isTwoPass {} {
    variable twoPass
    return  $twoPass
}

# analyzer::setQuiet --
#
#	Set the quiet bit to 1 or 0 depending on the type
#	of output requested from the user.
#
# Arguments:
#	quietBit	Boolean.  Indicates if output should be terse.
#
# Results:
#	None.

proc analyzer::setQuiet {quietBit} {
    variable quiet $quietBit ; # Implicit 'set'
    return
}

# analyzer::getQuiet --
#
#	Return the setting for the quiet bit.
#
# Arguments:
#	None.
#
# Results:
#	Return 1 if we are in quiet mode.

proc analyzer::getQuiet {} {
    variable quiet
    return  $quiet
}

# analyzer::setVerbose --
#
#	Set the verbose bit to 1 or 0 depending on the type
#	of output requested from the user.
#
# Arguments:
#	verboseBit	Boolean.  Indicates if summary info should print.
#
# Results:
#	None.

proc analyzer::setVerbose {verboseBit} {
    variable verbose $verboseBit ; # Implicit 'set'
    return
}

# analyzer::getVerbose --
#
#	Return the setting for the verbose bit.
#
# Arguments:
#	None.
#
# Results:
#	Return 1 if we are in verbose mode.

proc analyzer::getVerbose {} {
    variable verbose
    return  $verbose
}

# analyzer::getErrorCount --
#
#	Returns the number of errors that occured during the check.
#
# Arguments:
#	None.
#
# Results:
#	The number of errors.

proc analyzer::getErrorCount {} {
    variable errCount
    return  $errCount
}

# analyzer::getWarningCount --
#
#	Returns the number of warnings that occured during the check.
#
# Arguments:
#	None.
#
# Results:
#	The number of warnings.

proc analyzer::getWarningCount {} {
    variable warnCount
    return  $warnCount
}


# analyzer::getCodeCount --
#
#	Returns the number of messages that occured per message code
#
# Arguments:
#	None.
#
# Results:
#	The number of warnings.

proc analyzer::getCodeCount {} {
    variable  codeCount
    array get codeCount
}


proc analyzer::getLocation {} {
    set range [getCmdRange]
    if {$range eq {}} {
	return {{} {} {}}
    } else {
	return [list [getFile] [getLine] $range]
    }
}

proc analyzer::getChar {script range} {
    # 1. [parse charindex $script $range] == [lindex $range 0]
    variable scriptIsAscii
    if {$scriptIsAscii} {
	return [string index $script [lindex $range 0]]
    } else {
	return [string index $script [parse charindex $script $range]]
    }
}

proc analyzer::getString {script range} {
    # 3. [parse getstring $script $range] ==
    #    [string range $script [lindex $range 0] \\n
    #		[expr {[lindex $range 0] + [lindex $range 1] - 1}]
	return [parse getstring $script $range]
    variable scriptIsAscii
    if {$scriptIsAscii} {
	# XXX AK = convert range to s/e form, use {*} on result
	lassign $range start len
	return [string range $script $start [expr {$start + $len - 1}]]
    } else {
	return [parse getstring $script $range]
    }
}

# analyzer::getFile --
#
#	Retrieve the current file name.
#
# Arguments:
#	None.
#
# Results:
#	Returns the current file name.

proc analyzer::getFile {} {
    variable file
    return  $file
}

# analyzer::getScript --
#
#	Retrieve the current script contents.
#
# Arguments:
#	None.
#
# Results:
#	Returns the current script string.

proc analyzer::getScript {} {
    variable script
    variable trueScript

    # See 'coreTk::checkBindBody' for a checker differentiating
    # analyzed and true (reported) script.

    if {$trueScript ne {}} {return $trueScript}
    return $script
}

# analyzer::getLine --
#
#	Retrieve the current line number.
#
# Arguments:
#	None.
#
# Results:
#	Returns the current line number.

proc analyzer::getLine {} {
    variable currentLine
    return  $currentLine
}

# analyzer::getCmdRange --
#
#	Retrieve the current command range.
#
# Arguments:
#	None.
#
# Results:
#	Returns the current command range.

proc analyzer::getCmdRange {} {
    variable cmdRange
    return  $cmdRange
}

# analyzer::getTokenRange --
#
#	Extract the token's range from the token list.
#
# Arguments:
#	token	A token list.
#
# Results:
#	Returns the range of the token.

proc analyzer::getTokenRange {token} {
    return [lindex $token 1]
}

# analyzer::setCmdRange --
#
#	Set the anchor at the beginning of the given range.
#
# Arguments:
#	range	Range to set anchor before.
#
# Results:
#	None.  Updates the current line counter.

proc analyzer::setCmdRange {range} {
    variable script
    variable cmdRange
    variable currentLine
    variable scriptNesting

    # XXX AK: consider to replace this with message::lineOff
    # XXX AK: consider to compute only if needed (see range filter below).
    #set last $currentLine
    if {[lindex $range 0] < [lindex $cmdRange 0]} {
	incr currentLine -[parse countnewline $script $range $cmdRange]
    } else {
	incr currentLine [parse countnewline $script $cmdRange $range]
    }
    set cmdRange $range

    #puts <$currentLine>|[expr {$currentLine - $last}]|$last\t|$scriptNesting|[filter::getEndline]>|$range
    if {
	($scriptNesting <= 1) &&
	([filter::getEndline] ne "") &&
	($currentLine > [filter::getEndline])
    } {
	# Advise the caller (scanScript, analyzeScript(Ascii)) that we
	# have parsed beyond the -endline for sure. This is done only,
	# of course, if an -endline is specified. We also restrict
	# this to the toplevel script, as nested structures may
	# straddle the boundary and have to be parsed completely.
	# Also note that the caller is completely free to ignore this
	# advice.

	#puts <<stop>>
	return 0
    }
    return 1
}

# analyzer::pushCmdInfo --
#
#	Save the current command information on a stack.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc analyzer::pushCmdInfo {} {
    variable cmdRange
    variable currentLine
    variable cmdStack
    #::log::log debug "PUSH [list $cmdRange $currentLine]"

    # NOTE: Consider growing the stack through lappend => now copying, just extending
    set cmdStack [linsert $cmdStack 0 [list $cmdRange $currentLine]]
    return
}

# analyzer::popCmdInfo --
#
#	Restore a previously saved command info.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc analyzer::popCmdInfo {} {
    variable cmdRange
    variable currentLine
    variable cmdStack

    lassign [lindex $cmdStack 0] cmdRange currentLine
    set cmdStack [lrange $cmdStack 1 end]

    #::log::log debug "POP ($cmdRange $currentLine)"
    return
}

# analyzer::addWidgetOptions --
#
#	Add common widget options to the list of known widget options.  The
#	checkWidgetOptions checker uses the contents of this list to check
#	common options.
#
# Arguments:
#	optChkList	A list of "standard" widget options and the
#			checker associated with the option.
#
# Results:
#	None.

proc analyzer::addWidgetOptions {optChkList} {
    #::log::log debug $optChkList
    array set analyzer::standardWidgetOpts $optChkList
}

# analyzer::check --
#
#	Main routine that pre-scans, collates data, checks
#	the files and displays summary information.
#
# Arguments:
#	files	The files to be checked.
#
# Results:
#	None.

proc analyzer::check {files} {
    uproc::clear

    # pcx packages, especially versions are set up only after
    # uproc::clear

    variable coreTcl  [pcx::getCheckVersion coreTcl]
    variable after83  [expr {[package vcompare $coreTcl 8.3] > 0}] ; # 8.4+
    variable before84 [expr {[package vcompare $coreTcl 8.4] < 0}] ; # 8.3-
    variable before85 [expr {[package vcompare $coreTcl 8.5] < 0}] ; # 8.4-

    ## ######################################################

    if {$::configure::xref} {
	# Record the files in the general xref database.
	xref::addfiles $files

	# Disable the message reporting functionality completely.

	proc ::analyzer::logOpen {args} {}
	proc ::analyzer::logReset {args} {}
	proc ::analyzer::logGet {args} {}
	proc ::analyzer::logErrorRunDefered {args} {}
	proc ::analyzer::logError {args} { return 0 }
	proc ::analyzer::logExtendedError {args} {}
	proc ::analyzer::logError/Run {args} {}
    }
    if {$::configure::ping} {puts ping}

    ## ######################################################

    if {$::configure::packages} {
	#::log::log debug SCAN____________________________________________________
	set files [analyzer::scan $files]
	return
    } elseif {[isTwoPass]} {
	# Phase I - Scan the files and compile a list of procs to
	#	        check, handle namespaces and handle classes.

	#::log::log debug SCAN____________________________________________________
	set files [analyzer::scan $files]

	# Reset the embedded filtering to the initial state to keep
	# the phases from interfering with each other.
	filter::clearLine
	filter::clearBlock
	filter::clearLocal
	filter::clearGlobal ; # But not the cmdline settings!

	# Phase II - Collate the namespace imports/exports and class data.

	#::log::log debug COLL____________________________________________________
	analyzer::collate
    }

    # Phase III - Check each file specified on the command line.

    #::log::log debug ANALYZE_________________________________________________
    analyzer::analyze $files

    # If the verbose flag was set, print the summary info.

    if {[getVerbose] || $configure::summary} {
	message::showSummary
    }
}

proc analyzer::Progress {file} {
    if {[getQuiet]} return
    if {$file ne "stdin"} {
	set pwd [pwd]
	cd [file dirname $file]
	set file [file join [pwd] [file tail $file]]
	cd $pwd
    }
    if {[isScanning]} {
	set cmd scanning
    } else {
	set cmd checking
    }
    switch -exact -- $configure::machine {
	0 {
	    # Human
	    PutsAlways "${cmd}: $file"
	}
	1 {
	    # dict
	    PutsAlways [list progress [list $cmd $file]]
	}
	2 {
	    # script
	    PutsAlways [list progress $cmd $file]
	}
    }
}

# analyzer::isScanning --
#
#	Return true if the Checker is in the initial scanning phase.
#
# Arguments:
#	None.
#
# Results:
#	Boolean, 1 if the Checker is currently scanning all scripts.

proc analyzer::isScanning {} {
    variable scanning
    return  $scanning
}

# analyzer::scan --
#
#	Scan the list of files, searching for all user-defined
#	procedures, class definitions and namespace imports/exports.
#
# Arguments:
#	files	A list of files to scan.
#
# Results:
#	Return the list of files that were successfully opened and
#	scanned.

proc analyzer::scan {files} {
    variable scanning
    # Set the scanning bit to true, so no output is displayed.

    set scanning 1

    # Scan the files.  With the scanning bit set this will only scan
    # files looking into commands defined in the various scanCmds
    # lists of external packages.

    set files [analyze $files]

    # Restore the system to the previous state.

    set scanning 0
    return $files
}

# analyzer::scanScript --
#
#	Scan a script.  This procedure may be called directly
#	to scan a new script, or recursively to scan subcommands
#	and control function arguments.  If called with only a
#	block arg, it is assumed to be a new script and line
#	number information is initialized.
#
# Arguments:
#	scriptRange	The range in the script to analyze. A
#			default of {} indicates the whole script.
#
# Results:
#       None.

proc analyzer::scanScript {{scriptRange {}}} {
    variable script
    # Iterate over all of the commands in the script range, advancing the
    # range at the end of each command.

    pushCmdInfo
    if {$scriptRange eq ""} {
	set scriptRange [parse getrange $script]
    }

    for {} {[parse charlength $script $scriptRange] > 0} \
	    {set scriptRange $tail} {
	# Parse the next command
	setCmdRange $scriptRange
	# NOTE: In contrast to analyzeScript(...) this command ignores
	# the setCmdRange's advice regarding -endline. This is
	# necessary, as the scan has to pick up all information, as
	# data after the -endline can affect analysis before -endline.

	if {[catch {
	    lassign [parse command $script $scriptRange] comment cmdRange tail tree
	}]} {
	    # Attempt to keep parsing at the next thing that looks
	    # like a command.
	    set errPos [lindex $::errorCode 2]
	    lassign $scriptRange scriptStart scriptLen
	    set scriptRange [list $errPos [expr {$scriptStart + $scriptLen - $errPos}]]
	    # XXX FIX JH: Should be fixed with regexp -all to not reiterate
	    # XXX the regexp over the script.
	    if {[regexp -indices {[^\\][\n;]} \
		    [parse getstring $script $scriptRange] match]} {
		set start [parse charindex $script $scriptRange]
		set end [expr {$start + [lindex $match 1] + 1}]
		set len [expr {$start \
			+ [parse charlength $script $scriptRange] - $end}]
		set tail [parse getrange $script $end $len]
		setCmdRange $tail
		continue
	    }
	    break
	}

	if {$::configure::ping} {puts ping}

	if {[parse charlength $script $cmdRange] <= 0} {
	    continue
	}

	# Set the anchor at the beginning of the command, skipping over
	# any comments or whitespace.

	setCmdRange $cmdRange
	HandleComment $comment

	set index 0
	while {$index < [llength $tree]} {
	    set cmdToken [lindex $tree $index]
	    if {[getLiteral $cmdToken cmdName]} {
		# The scan command checkers do not distinguish between
		# commands with leading ::'s and those that do not.  In
		# order to see if this command is a scan command, the
		# leading ::'s need to be stripped off.

		##regsub {^::} $cmdName "" cmdName

		#::log::log debug "Scanning $cmdName ..."

		## We record always command usage ...
		## This is required for the upvar resolution ...

		#::log::log debug "\t\trecording usage @F [getLocation]"
		#::log::log debug "\t\trec             @E ($::context::contextStack)"
		#::log::log debug "\t\trec             @O ($::context::scopeStack)"

		# Record usage of the command (location) in
		# the database ...

		uproc::record  [context::top] $cmdName [list \
			loc   [getLocation] \
			scope [xref::BaseScope [context::topScope]] \
			]


		if {[uproc::exists [context::top] $cmdName pInfoList]} {
		    # Check the argList for the user-defined proc.

		    #::log::log debug "\t\t\t\t\tHas def"
		    #::log::log debug "\tuproc\t($pInfoList)"

		    incr index
		    set index [cdb::scanRun $cmdName $pInfoList $tree $index]
		    continue
		}
	    }

	    # The command was not literal or the command was not a scan
	    # command.  Invoke the generic command checker on all of the
	    # words in the statement.

	    set index [checkCommand $tree 0]
	}
    }
    popCmdInfo
    return
}

if 0 {
    # analyzer::scanCmdExists --
    #
    #	Determine if the command should be recursed into looking for
    #	user-defined procs.
    #
    # Arguments:
    #	cmdName		The name of the command to check.
    #
    # Results:
    #	Return 1 if this command should be scanned, or 0 if it should not.

    proc analyzer::scanCmdExists {cmdName} {
	return [expr {[info exists analyzer::scanCmds(${cmdName}-TPC-SCAN)] \
		|| [info exists analyzer::scanCmds($cmdName)]}]
    }
}

# analyzer::addScanCmds --
#
#	Add to the table of commands that need to be
#	checked for proc definitions during the initial
#	scan phase.
#
# Arguments:
#	cmdList		List of command/action pairs for commands that
#			need to be searched for proc definitions.
#
# Results:
#	None.

proc analyzer::addScanCmds {cmdList} {
    foreach {name cmd} $cmdList {
	set analyzer::scanCmds($name) [list $cmd]
    }
    return
}

# analyzer::addContext --
#
#	Push the new context on its stack and push a new proc
#	info type onto its stack.  Then call the chain command
#	to analyze the command given the new state.  When the
#	command is done being checked by the chain command, see
#	if enough info was gathered to add a user defined proc.
#	Before exiting, pop all appropriate stacks.  This routine
#	should be called during the initial scanning phase
#	and passed a token tree and current index, where the
#	index is the name of the proc being defined.
#
# Arguments:
#	cIndex		The index to use to extract context info.
#	strip		Boolean indicating if the word containing
#			the context name should have the head stripped
#			off (i.e. "proc" vs. "namespace eval")
#	vCmd		The command to call to verify that enough info
#			was gathered to define a user proc.  Can be an
#			empty string.
#	cCmd		The command to call during the analyze step (phase III)
#			that verifies the user proc was called correctly.
#			Can be an empty string.
#	chainCmd	The chain command to eval in the new context.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::addContext {cIndex strip vCmd cCmd chainCmd tokens index} {
    # Extract the new context from the token list and push it onto
    # the stack.  If the token pointed at by cIndex is a non-literal,
    # push the UNKNOWN descriptor.

    #::log::log debug "analyzer::addContext <<< ..."

    set word [lindex $tokens $cIndex]
    if {[getLiteral $word context]} {

	#::log::log debug "--- ($context)"

	if {$strip} {
	    set context [context::head $context]
	}

	#::log::log debug "--- ($context)"

	context::push [context::join [context::top] $context]
    } else {
	context::push UNKNOWN
    }

    # Add a new proc info type onto the stack.  This will get
    # populated with data when the command is checked that
    # creates a user proc.

    if {$cCmd eq ""} {set cCmd "analyzer::checkUserProc"}
    if {$vCmd eq ""} {set vCmd "analyzer::verifyUserProc"}
    set pInfo [cdb newProcInfo]
    set pInfo [cdb setVerifyCmd $pInfo $vCmd]
    set pInfo [cdb setCheckCmd  $pInfo $cCmd]
    cdb pushProcInfo $pInfo

    # Parse the remaining portion of the command with the
    # new context info.

    #::log::log debug "CHAIN <<< ..."

    # Remember current lexical scoping
    set mark [context::markScope]

    set index [{*}$chainCmd $tokens $index]

    #::log::log debug "... >>> CHAIN"

    # Return the stacks back to the previous state and add the
    # user proc if enough info was gathered to define this user
    # proc.

    context::pop
    set pInfo [cdb topProcInfo]
    if {[[cdb getVerifyCmd $pInfo] $pInfo]} {
	uproc::add $pInfo $strip
    }
    cdb popProcInfo

    # Return lexical scope to state before this command.
    context::popScopeToMark $mark

    #::log::log debug "... >>> analyzer::addContext"

    return $index
}

# analyzer::addUserProc --
#
#	Add the user-defined proc to the list of commands
#	to be checked during the final phase.  This routine
#	should be called during the initial scanning phase
#	and passed a token tree and current index, where the
#	index is the name of the proc being defined.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.  The
#	proc name will be added to the current pInfo type on top
#	of the proc info stack.

proc analyzer::addUserProc {tokens index} {
    set argc [llength $tokens]
    set word [lindex $tokens $index]
    if {($argc != 4) || (![getLiteral $word procName])} {
	return [checkCommand $tokens $index]
    }

    # Turn procName into an unqualified name.  The context of
    # the procName is *already* defined in the system and can
    # be retrieved by using the context::top command.

    set name [namespace tail $procName]
    set proc [context::join [context::top] $name]
    cdb addUserProc $proc proc

    return [incr index]
}

# analyzer::addArgList --
#
#	Add the user-defined proc's argList to the list of commands
#	to be checked during the final phase.  This routine
#	should be called during the initial scanning phase
#	and passed a token tree and current index, where the
#	index is the argList to parse.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.  The
#	arg list will be added to the current pInfo type on top
#	of the proc info stack.

proc analyzer::addArgList {tokens index} {
    # Get the argList.  If the value is nonLiteral, or is
    # not a valid Tcl list, then do nothing and return without
    # adding this proc to the database.

    set word [lindex $tokens $index]
    if {![getLiteral $word argList] \
	    || [catch {set len [llength $argList]}]} {
	return [checkCommand $tokens $index]
    }

    cdb addArgList $argList
    return [incr index]
}

# analyzer::addRenameCmd --
#
#	Add the commands to be renamed in the current context.  The
#	command names to be renamed must be parsed from the token
#	list.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::addRenameCmd {tokens index} {
    variable renameCmds

    # Extract the proc names from the token list.  If either
    # the source or destination proc name is a non-literal,
    # then bail and do nothing.

    set word [lindex $tokens $index]
    if {![getLiteral $word src]} {
	return [checkCommand $tokens $index]
    }
    incr index
    set word [lindex $tokens $index]
    if {![getLiteral $word dst]} {
	return [checkCommand $tokens $index]
    }

    # Get the fully qualified name of the source and destination
    # procs before adding them to the list.

    set srcCmd [context::join [context::top] $src]
    set dstCmd [context::join [context::top] $dst]
    set renameCmds($srcCmd,$dstCmd) [list $srcCmd $dstCmd]
    return [incr index]
}

# analyzer::addInheritCmd --
#
#	Add the base classes that the derived class (the current context)
#	should inherit from.  The base class names to inherit must be
#	parsed from the token list.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::addInheritCmd {tokens index} {
    variable inheritCmds

    # The inherit command could be called multiple times for the
    # same class if the class is deleted and recreated.  To handle
    # this case, and still be able to flatten the inheritance tree,
    # the inheritCmds array stores lists of inheritance order for
    # a given context.

    set result  {}
    set drvClass [context::top]

    while {$index < [llength $tokens]} {
	set word [lindex $tokens $index]
	if {[getLiteral $word baseClass]} {
	    incr index
	    lappend result $baseClass
	} else {
	    # The word is a non-literal value, check the word but
	    # do not append anything to the pattern list.

	    set index [checkWord $tokens $index]
	}
    }
    lappend inheritCmds($drvClass) $result
    return $index
}

# analyzer::addExportCmd --
#
#	Add the list of commands to the list of commands to
#	be exported for this namespace context.  The command
#	names to export must be extracted from the token list
#	and be literal values.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::addExportCmd {tokens index} {
    variable exportCmds

    set start $index
    set context [context::top]
    while {$index < [llength $tokens]} {
	set word [lindex $tokens $index]
	if {[getLiteral $word literal]} {
	    # If this is the first word, check for the -clear option.
	    # Do nothing if the -clear option is specified, because
	    # we cannot determine when this command will be called.

	    incr index
	    if {($index == ($start + 1)) && ($literal eq "-clear")} {
		continue
	    }

	    # Do not append patterns that specify a namespace.
	    # This is illegal and is logged as an error during
	    # phase III.

	    if {[string first "::" $literal] >= 0} {
		continue
	    }

	    lappend exportCmds($context) $literal
	} else {
	    # The word is a non-literal value, check the word but
	    # do not append anything to the pattern list.

	    set index [checkWord $tokens $index]
	}
    }
    return $index
}

# analyzer::addImportCmd --
#
#	Add the pattern to the list of imported namespace patterns.  The
#	pattern string must be extracted from the token list and must
#	be a literal value.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::addImportCmd {tokens index} {
    variable importCmds

    set start $index
    set context [context::top]
    while {$index < [llength $tokens]} {
	set word [lindex $tokens $index]
	if {[getLiteral $word literal]} {
	    # If this is the first word, check for the -force option.
	    # Do nothing if the -force option is specified, because
	    # we cannot determine when this command will be called.

	    incr index
	    if {($index == ($start + 1)) && ($literal eq "-force")} {
		continue
	    }
	    lappend importCmds($context) $literal
	} else {
	    # The word is a non-literal value, check the word but
	    # do not append anything to the pattern list.

	    set index [checkWord $tokens $index]
	}
    }
    return $index
}

# analyzer::verifyUserProc --
#
#	Verify the information contained in the proc info type
#	is enough to check the user defined proc.  This routine
#	should be called after a command that defines a user
#	proc has been parsed and checked. (see analyzer::addContext)
#
# Arguments:
#	pInfo	The proc info opaque type.
#
# Results:
#	Return a boolean, 1 if there is enough data, 0 otherwise.

proc analyzer::verifyUserProc {pInfo} {
    set name [cdb getName $pInfo]
    set def  [cdb getDef  $pInfo]
    return [expr {($name ne {}) && $def}]
}

# analyzer::collate --
#
#	Collate the namespace import and export commands and
#	add any imported commands to the user-defined proc
#	database.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc analyzer::collate {} {
    variable inheritCmds
    variable renameCmds
    variable exportCmds
    variable importCmds

    # FUTURE # Place these databases in 'uproc'
    # Note: File specific information is not possible.
    # Any import/export can influence every other file.

    uproc::collate inheritCmds renameCmds exportCmds importCmds
    return
}

# analyzer::analyze --
#
#	Perform syntactic analysis of a tcl script.  At this
# 	point, glob patterns have already been expanded.  If the
# 	-quiet flag was not specified, print the filename before
# 	checking.
#
# Arguments:
#	files		A list of file names to analyze.
#
# Results:
#	Return the list of files that were successfully opened and
#	scanned.

proc analyzer::analyze {files} {
    variable script
    set result {}
    set pwd    [pwd]

    ## TODO ... The way 'uproc::start' is used is not quite right yet
    ## for multi-pass scanning. We should factor handling of a single
    ## file out of the code below.

    if {![isScanning]} {
	# And for these we know that they won't work.  Use the special
	# error range '@' to signal that this is not associated with
	# any command, or file.
	variable ::configure::preloadTrouble
	if {[llength $preloadTrouble]} {
	    logOpen
	    foreach msg $preloadTrouble {
		logError coreTcl::pkgUnchecked @ $msg
	    }
	    LogFlush
	}
    }

    if {![llength $files]} {
	uproc::setfile stdin

	if {[isScanning] || ![isTwoPass]} {
	    if {![getQuiet] || $configure::machine} {
		Puts "scanning: stdin"
	    }

	    if 0 {
		# Code helping to debug the communication with Komodo.
		# What data do we get exactly ? Get binary, save binary
		# Do od -c on it later. Hardwired destination file.

		set save [open c:/cile_input.txt w]
		fconfigure $save -translation binary
		fconfigure stdin -translation binary
		fcopy stdin $save
		close $save
		close stdin
		exit 2
	    }

	    set script [read stdin]
	    StartFile stdin

	    if {$::configure::md5 eq ""} {
		# Compute the md5 from the script we have just read.

		package require md5 1
		set ::configure::md5 [md5::md5 -hex $script]
	    }

	    if {$::configure::mtime eq ""} {
		# Use current time for stdin, if not already specified
		# through the commandline
		set ::configure::mtime [clock seconds]
	    }

	    #global ktl_log ; puts $ktl_log "script = $script"

	    # Initialize command database with core
	    uproc::start
	    if {![isTwoPass]} timeline::open
	    WholeFile begin
	    checkScript
	    WholeFile done
	    if {![isTwoPass]} timeline::close
	    # [Bugzilla 88766] Flush toplevel messages
	    LogFlush
	} else {
	    if {![getQuiet]} {
		Puts "checking: stdin"
	    }
	    logOpen
	    timeline::open
	    WholeFile begin
	    checkScript
	    WholeFile done
	    # Note: order sensitive. timeline may generate error
	    # messages, flush therefore has to come after
	    timeline::close
	    LogFlush
	}
	return $result
    }

    foreach file $files {
	if {[catch {set fd [open $file r]} msg] == 1} {
	    Puts $msg
	    continue
	} else {
	    lappend result $file
	}
	Progress $file

	set script [read $fd]
	close $fd
	StartFile $file
	filter::userangesfor $file

	uproc::setfile $file

	if {[isScanning]} {
	    uproc::start
	} else {
	    logOpen
	    timeline::open
	}

	WholeFile begin
	checkScript
	WholeFile done

	# Prevent propagation of global scope pragmas between files.
	filter::clearGlobal

	if {![isScanning]} {
	    # Note: order sensitive. timeline may generate error messages,
	    # flush therefore has to come after
	    timeline::close
	    LogFlush
	}
    }
    return $result
}

proc analyzer::StartFile {fname} {
    variable script
    variable file
    variable currentLine
    variable scriptIsAscii
    variable cmdRange

    set file        $fname
    set currentLine 1
    set scriptIsAscii \
	[expr {[string length $script] == [string bytelength $script]}]
    if 0 {
	set scriptIsAscii \
	    [expr {$scriptIsAscii && [info exists ::env(ASCII)]
		   && [string is true -strict $::env(ASCII)]}]
    }
    set cmdRange [parse getrange $script]
    message::initLines $script
    return
}

proc analyzer::WholeFile {when} {
    # Run the known per-file checkers.
    variable perfile
    variable script
    variable perfilenow

    # Saving the per-file checker for a file, the same set will be
    # used after the file has been processed, regardless of new
    # checkers declared by the file itself. The code further saves and
    # restores the contents of the script, in case a checker tries to
    # modify it.
    if {$when eq "begin"} {
	set perfilenow $perfile
    }
    set saved $script
    foreach cmd $perfilenow {
	{*}$cmd $when
    }
    set script $saved

    if {$when eq "done"} return
    if {[isScanning]} return

    # First before the file, after user-checks, hardwired whole file
    # checks.

    CheckStyleLineLength
    return
}

# analyzer::analyzeScript --
#
#	Analyze a script.  This procedure may be called directly
#	to analyze a new script, or recursively to analyze
#	subcommands and control function arguments.  If called with
#	only a block arg, it is assumed to be a new script and line
#	number information is initialized.
#
# Arguments:
#	scriptRange	The range in the script to analyze. A
#			default of {} indicates the whole script.
#
# Results:
#       None.

proc analyzer::analyzeScript {{scriptRange {}}} {
    variable script
    variable before85

    # Iterate over all of the commands in the script range, advancing the
    # range at the end of each command.

    set oldPrevRange    {}
    set oldPrevCmdRange {}

    pushCmdInfo
    CheckBlockIndentation $scriptRange
    if {$scriptRange eq ""} {
	set scriptRange [parse getrange $script]
    }

    set prevLine  {}
    set prevRange {}
    set prevCmdRange {}
    for {} {
	    [parse charlength $script $scriptRange] > 0
	} {set scriptRange $tail} {
	# Parse the next command

	if {![setCmdRange $scriptRange]} {
	    # Beyond -endline? Abort early, no need to parse further.
	    popCmdInfo
	    return
	}
	if {[catch {
	    lassign [parse command $script $scriptRange] comment cmdRange tail tree
	}]} {
	    # An error occurred during parsing so generate the error.
	    set errPos [lindex $::errorCode 2]
	    lassign $scriptRange scriptStart scriptLen
	    set errLen [expr {$scriptLen - ($errPos - $scriptStart)}]
	    set errMsg [lindex $::errorCode end]

	    # Bugzilla 34989. Error messages generated here are stuck
	    # in the system and not printed. We have to unstuck
	    # them. This is only true if there is no nested capture
	    # open, or so ?!

	    if {[string match {*extra characters after close-brace*} $errMsg]} {
		# We do not have a proper cmdRange here. Actually,
		# cmdRange is defined, but points to the previous
		# command. Similar to getIndentation we use the errPos to
		# determine the beginning of the current line to get a
		# relevant part of the script and use it as fake command string
		# to operate on for corrections.

		set  eol [string last \n [getString $script [list 0 $errPos]]]
		incr eol

		# errPos relative to the beginning of the fake command.
		set at [expr {$errPos - $eol}]
		# fake token list (single word, token type irrelevant).
		set tokens [list [list _dummy_type_ [list $eol [expr {($at-1)+$errLen}]]]]

		logExtendedError \
		    [CorrectionsOf 0 $tokens \
			 get 0 wstrinsert $at { } replace 0 save] \
		    parse [list $errPos $errLen] $errMsg
	    } else {
		logError parse [list $errPos $errLen] $errMsg
	    }
	    # Attempt to keep parsing at the next thing that looks
	    # like a command.

	    # Hack coming up: The return value of ParseAfter... is
	    # either "break" or "continue", i.e. the very command
	    # telling us how to handle the outer loop.

            [ParseAfterSyntaxError]
	}

	if {$::configure::ping} {puts ping}

	if {[parse charlength $script $cmdRange] <= 0} {
	    continue
	}

	# Set the anchor at the beginning of the command, skipping over
	# any comments or whitespace.

	setCmdRange $cmdRange
	CheckCommandSpacing
	HandleComment $comment

	set index 0
	set treelen [llength $tree]

	set fake 0
	style::clear
	while {$index < $treelen} {
	    set cmdToken [lindex $tree $index]

	    # Save current state to context for 'style::indent::at'.
	    set ::analyzer::xtree            $tree
	    set ::analyzer::xoldPrevRange    $oldPrevRange
	    set ::analyzer::xoldPrevCmdRange $oldPrevCmdRange

	    style::set $index cmdname
	    style::indent::at $cmdToken

	    set forcegeneric 0
	    if {[hasExpansion $tree at]} {
		# Expansionist. Invoke the generic command checker on
		# all of the words in the statement.

		#::log::log debug "\texpansions, generic check only"

		if {$before85} {
		    # Expansions are parse errors for Tcl before 8.5.
		    #
		    # As the current parser package accepted the
		    # syntax we are running on 8.5+ and thus have to
		    # fake the error.

		    set exword [lindex $tree $at]
		    set range  [getTokenRange $exword]
		    lassign $range errPos errLen

		    set prefix [parse getrange $script $errPos 3]
		    if {$prefix eq {{*}}} {
			incr errPos  3
			incr errLen -3
		    } elseif {$prefix eq "\{ex"} {
			# length '<expand>' = 8
			incr errPos  8
			incr errLen -8
		    } else {
			# Internal error.
			logError parse [list $errPos $errLen] "Unknown expansion code \"$prefix\""
		    }

		    logExtendedError \
			[CorrectionsOf 0 $tree \
			     get $at wstrinsert $by { } wstrinsert 0 \{ wunquote replace $at save \
			     get $at wstrreplace 0 $by {}               wunquote replace $at save] \
			parse [list $errPos $errLen] {extra characters after close-brace}
		    set fake 1
		    break
		}

		# Force generic check in upcoming code.
		set forcegeneric 1
	    }

	    # Open a capture level
	    logOpen

	    # Post any defered error messages ...
	    logErrorRunDefered

	    set logclosed 0
	    if {!$forcegeneric && [getLiteral $cmdToken cmdName]} {
		# The system command checkers do not distinguish between
		# commands with leading ::'s and those that do not.  In
		# order to see if this command is a system command, the
		# leading ::'s need to be stripped off.

		set systemCmdName [string trimleft $cmdName :]

		#::log::log debug "========================================"
		#::log::log debug "ANA ($cmdName) /[context::top]/"

		if {[uproc::exists [context::top] $cmdName pInfo]} {
		    # Check the argList for the user-defined proc.

		    #::log::log debug "\tuproc\t($pInfo)"

		    incr index
		    set index [cdb::checkUserProc $cmdName $pInfo \
			    $tree $index]

		    # The log level is closed here. (checkUserProc has done it.)
		    set logclosed 1
		} elseif {[isTwoPass]} {
		    # Currently, Tk is not defining widget names as procs.
		    # Ignore all unknown commands that start with period.

		    if {![string match ".*" $cmdName]} {
			# This is a command that is neither defined by the
			# user or defined to be a global proc.

			WarnUndef $cmdName $cmdRange
		    }

		    #::log::log debug "\tunknown, no widget, generic check"

		    set index [checkCommandAndStyles $tree $index]
		} else {
		    # Nothing special is to be done, just check command.

		    #::log::log debug "\tunknown, generic check"

		    set index [checkCommandAndStyles $tree $index]
		}
	    } else {
		# Invoke the generic command checker on all of the words in
		# the statement.

		#::log::log debug "\tno literal, generic check"

		set index [checkCommandAndStyles $tree 0]
	    }

	    # Check if the log was already handled.
	    # If not we push the generated messages out here.
	    # This may push them to a higher capture level.

	    if {!$logclosed} {
		foreach cmd [logGet] {
		    {*}$cmd
		}
	    } ; # else {  puts stderr "MESSAGE /logclosed" }
	} ; # while index < treelen

	CheckCommandString $tree $cmdRange $tail \
	    CheckBlankContinuation

	# We had to fake a syntax error in the command processing loop
	# I.e. -use Tcl 8.4 or less, runtime is 8.5+, and checked code
	# contain expansions. Do the regular syn error handling now.
	if {$fake} {
	    # Attempt to keep parsing at the next thing that looks
	    # like a command.

	    # Hack coming up: The return value of ParseAfter... is
	    # either "break" or "continue", i.e. the very command
	    # telling us how to handle the outer loop.

	    [ParseAfterSyntaxError]
	}
    }
    popCmdInfo
    return
}

proc analyzer::analyzeScriptAscii {scriptRange} {
    variable script
    variable before85
    # Iterate over all of the commands in the script range, advancing the
    # range at the end of each command.

    pushCmdInfo
    CheckBlockIndentation $scriptRange
    if {$scriptRange eq ""} {
	set scriptRange [list 0 [string length $script]]
    }
    #puts S($scriptRange)>

    lassign $scriptRange scriptStart scriptLen
    set prevLine    {}
    set prevRange   {}
    set prevCmdRange   {}
    for {} {$scriptLen > 0} {
	set scriptRange $tail
	lassign $scriptRange scriptStart scriptLen
    } {
	# Parse the next command

	if {![setCmdRange $scriptRange]} {
	    # Beyond -endline? Abort early, no need to parse further.
	    popCmdInfo
	    return
	}
	if {[catch {
	    lassign [parse command $script $scriptRange] comment cmdRange tail tree
	}]} {
	    # An error occurred during parsing so generate the error.
	    set errPos [lindex $::errorCode 2]
	    set errLen [expr {$scriptLen - ($errPos - $scriptStart)}]
	    set errMsg [lindex $::errorCode end]

	    # Bugzilla 34989. Error messages generated here are stuck
	    # in the system and not printed. We have to unstuck
	    # them. This is only true if there is no nested capture
	    # open, or so ?!

	    if {[string match {*extra characters after close-brace*} $errMsg]} {
		# We do not have a proper cmdRange here. Actually,
		# cmdRange is defined, but points to the previous
		# command. Similar to getIndentation we use the errPos to
		# determine the beginning of the current line to get a
		# relevant part of the script and use it as fake command string
		# to operate on for corrections.

		set  eol [string last \n [getString $script [list 0 $errPos]]]
		incr eol

		# errPos relative to the beginning of the fake command.
		set at [expr {$errPos - $eol}]
		# fake token list (single word, token type irrelevant).
		set tokens [list [list _dummy_type_ [list $eol [expr {($at-1)+$errLen}]]]]

		logExtendedError \
		    [CorrectionsOf 0 $tokens \
			 get 0 wstrinsert $at { } replace 0 save] \
		    parse [list $errPos $errLen] $errMsg
	    } else {
		logError parse [list $errPos $errLen] $errMsg
	    }
	    # Attempt to keep parsing at the next thing that looks
	    # like a command.

	    # Hack coming up: The return value of ParseAfter... is
	    # either "break" or "continue", i.e. the very command
	    # telling us how to handle the outer loop.

	    [ParseAfterSyntaxErrorAscii]
	}

	#puts \tC($cmdRange)
	if {$::configure::ping} {puts ping}

	if {[lindex $cmdRange 1] <= 0} {
	    continue
	}

	# Set the anchor at the beginning of the command, skipping over
	# any comments or whitespace.

	setCmdRange $cmdRange
	CheckCommandSpacing
	HandleComment $comment

	set index 0
	set treelen [llength $tree]

	set fake 0
	style::clear
	while {$index < $treelen} {
	    set cmdToken [lindex $tree $index]

	    # Save current state to context for 'style::indent::at'.
	    set ::analyzer::xtree            $tree
	    set ::analyzer::xoldPrevRange    $oldPrevRange
	    set ::analyzer::xoldPrevCmdRange $oldPrevCmdRange

	    style::set $index cmdname
	    #puts \t\t@$index,\t[getTokenRange $cmdToken]:|[getString $script $cmdRange]|
	    style::indent::at $cmdToken

	    set forcegeneric 0
	    if {[hasExpansion $tree at]} {
		# Expansionist. Invoke the generic command checker on
		# all of the words in the statement.

		#::log::log debug "\texpansions, generic check only"

		if {$before85} {
		    # Expansions are parse errors for Tcl before 8.5.
		    #
		    # As the current parser package accepted the
		    # syntax we are running on 8.5+ and thus have to
		    # fake the error.

		    set exword [lindex $tree $at]
		    set range  [getTokenRange $exword]
		    lassign $range errPos errLen

		    set prefix [string range $script $errPos [expr {$errPos + 2}]]
		    if {$prefix eq {{*}}} {
			incr errPos  3
			incr errLen -3
			set by 2
		    } elseif {$prefix eq "\{ex"} {
			# length '<expand>' = 8
			incr errPos  8
			incr errLen -8
			set by 7
		    } else {
			# Internal error.
			logError parse [list $errPos $errLen] "Unknown expansion code \"$prefix\""
		    }

		    logExtendedError \
			[CorrectionsOf 0 $tree \
			     get $at wstrinsert $by { } wstrinsert 0 \{ wunquote replace $at save \
			     get $at wstrreplace 0 $by {}               wunquote replace $at save] \
			parse [list $errPos $errLen] {extra characters after close-brace}
		    set fake 1
		    break
		}

		# Force generic check in upcoming code.
		set forcegeneric 1
	    }

	    # Open a capture level
	    logOpen

	    # Post any defered error messages ...
	    logErrorRunDefered

	    set logclosed 0
	    set islit     [getLiteral $cmdToken cmdName]

	    npush $cmdName
	    if {!$forcegeneric && $islit} {
		# The system command checkers do not distinguish between
		# commands with leading ::'s and those that do not.  In
		# order to see if this command is a system command, the
		# leading ::'s need to be stripped off.

		set systemCmdName [string trimleft $cmdName :]

		#::log::log debug "========================================"
		#::log::log debug "ANA ($cmdName) /[context::top]/"

		if {[uproc::exists [context::top] $cmdName pInfo]} {
		    # Check the argList for the user-defined proc.

		    #::log::log debug "\tuproc\t($pInfo)"

		    incr index
		    set index [cdb::checkUserProc $cmdName $pInfo \
			    $tree $index]

		    # The log level is closed here. (checkUserProc has done it.)
		    set logclosed 1
		} elseif {[isTwoPass]} {
		    # Currently, Tk is not defininig widget names as procs.
		    # Ignore all unknown commands that start with period.

		    if {![string match ".*" $cmdName]} {
			# This is a command that is neither defined by the
			# user or defined to be a global proc.

			WarnUndef $cmdName $cmdRange
		    }

		    #::log::log debug "\tunknown, no widget, generic check"

		    set index [checkCommandAndStyles $tree $index]
		} else {
		    # Nothing special is to be done, just check command.

		    #::log::log debug "\tunknown, generic check"

		    set index [checkCommandAndStyles $tree $index]
		}
	    } else {
		# Invoke the generic command checker on all of the words in
		# the statement.

		#::log::log debug "\tno literal, generic check"

		set index [checkCommandAndStyles $tree 0]
	    }
	    npop

	    # Check if the log was already handled. If not we push the
	    # generated messages out here. This may push them to a
	    # higher capture level.

	    if {!$logclosed} {
		foreach cmd [logGet] {
		    {*}$cmd
		}
	    } ; # else {  puts stderr "MESSAGE /logclosed" }
	} ; # while index < treelen

	CheckCommandString $tree $cmdRange $tail \
	    CheckBlankContinuation

	# We had to fake a syntax error in the command processing loop
	# I.e. -use Tcl 8.4 or less, runtime is 8.5+, and checked code
	# contain expansions. Do the regular syn error handling now.
	if {$fake} {
	    # Attempt to keep parsing at the next thing that looks
	    # like a command.

	    # Hack coming up: The return value of ParseAfter... is
	    # either "break" or "continue", i.e. the very command
	    # telling us how to handle the outer loop.

	    [ParseAfterSyntaxErrorAscii]
	}
    }
    popCmdInfo
    return
}

proc analyzer::CheckBlockIndentation {range} {
    # Bug 77231, R1.8
    variable bracketNesting
    if {$range eq ""} return
    if {$bracketNesting} return

    lassign $range s l
    set lc [expr {$s + $l}]
    set berange [list $lc 1]

    #variable script
    #puts ==[getString $script $range]==
    #puts *=[getString $script $berange]=*

    set ci     [style::indent::get]
    set indent [getIndentation $berange]
    style::indent::set $ci

    #puts <$ci|$indent>

    if {$ci == $indent} return

    # In most cases the shown range is the exact block end character,
    # i.e. closing brace.
    set sberange $berange

    set bec [analyzer::getString $analyzer::script $berange]

    if {$indent > $ci} {
	# The block end is indented too far.
	# 2 cases: Block end is on same line as last command of the
	# block, or on its own line, consisting only of whitespace.

	set newcode [string repeat { } $ci]$bec

	# This is the range for the content of the line before block end.
	set xrange [list [expr {$lc-$indent}] $indent]

	#puts XX|[analyzer::getString $analyzer::script $xrange]|
	if {[regexp {^\s+$} [analyzer::getString $analyzer::script $xrange]]} {
	    # The block end is on a line of its own, with only
	    # whitespace preceding it. To express the correction we
	    # have to show the whole line before it, and then we can
	    # propose a shorter line using the expected indentation as
	    # correction.

	    set sberange  [list [expr {$lc-$indent}] [expr {$indent + 1}]]
	} else {
	    # Block end is on same line as the last command. Basic
	    # correction is same, i.e. use the expected indentation
	    # (already computed. see above). However we also need a
	    # newline, put it on a line of its own.

	    set newcode \n$newcode
	}

    } elseif {$indent < $ci} {
	# Block has not enough indentation. Simply add the missing
	# spaces to the code.

	set newcode [string repeat { } [expr {$ci - $indent}]]$bec
    }

    pushCmdInfo
    setCmdRange $sberange
    logExtendedError \
	[CorrectionsOf 1 {} \
	     ldropall insert 0 $newcode save] \
	warnStyleIndentBlock $berange $indent $ci
    popCmdInfo
    return
}

proc analyzer::CheckCommandString {tokens cmdRange tail chainCmd} {
    variable scriptIsAscii
    variable script

    # Ignore empty commands.
    if {![llength $tokens]} return

    # Look at the command just as a string now. Note that we look one
    # character past the word for better context.

    set s [lindex $cmdRange 0]
    set e [lindex $tail     0]

    # We also use the tail information to extend the last token to go
    # beyond the command, so that we can show how to correct it should
    # a message be necessary and the correction be in the part after
    # the command itself. Example: CheckBlankContinuation

    set lastword  [lindex $tokens end]
    set lastrange [lindex $lastword 1]
    lassign $lastrange start len
    set newlength [expr {$e - $start}]

    set etokens $tokens
    lset etokens end 1 1 $newlength

    # XXX AK - use analyzer::getString here?
    if {$scriptIsAscii} {
	set v [string range $script $s $e]
    } else {
	set v [parse getstring $script [rangebetween $s $e]]
    }

    {*}$chainCmd $tokens $etokens $cmdRange $v
    return
}

proc analyzer::CheckBlankContinuation {tokens etokens cmdRange cmdString} {

    # Bugzilla 76837. Check if the command ends in a continuation line
    # with at least one empty line following it. Note that the context
    # is needed here to distinguish a word which simply has trailing
    # whitespace with a continuation line from one where the
    # continuation line is an empty line.

    if {
	[regexp -indices "(\\\\)\n\[ \t\]*\n.\$" $cmdString -> end] ||
	[regexp -indices "(\\\\)\n\[ \t\]*\$"    $cmdString -> end]
    } {
	lassign $end s e
	# XXX AK - consider creation of range manipulation operators
	set range [list [expr {[lindex $cmdRange 0]+$s}] 1]
	logExtendedError \
	    [CorrectionsOf 0 $etokens \
		 get end wsplit {} dropafter end-1 wjoin {} replace end \
		 save] \
	    warnContinuation $range
    }
    return
}

proc analyzer::CheckCommandSpacing {} {
    variable script
    upvar 1 prevLine prevLine cmdRange cmdRange prevRange prevRange prevCmdRange prevCmdRange
    upvar 1 oldPrevRange oldPrevRange oldPrevCmdRange oldPrevCmdRange

    # Check command spacing. Bugzilla 76837.
    if {$prevLine != {}} {
	set delta [expr {[getLine] - $prevLine}]
	if {$delta < 1} {
	    upvar 1 tree tokens
	    # We ignore this if the command on the same line is empty.
	    # AK XXX: We have a superfluous semicolon in the code. We
	    # could warn about that.
	    if {[llength $tokens]} {

		# AK XXX: Note: We are using the indentation of the
		# previous command when putting this command on a new
		# line, to align them properly. That process has
		# limitations: In case of 3 or more commands on a line
		# the later commands get indented more and more. We do
		# not know about the block structure here, only the
		# previous command.
		logExtendedError \
		    [CorrectionsOf 1 $tokens \
			 +indent [getIndentation $prevCmdRange] newline save] \
		    warnStyleOneCommandPerLine $cmdRange
	    }
	} elseif {$delta > 2} {
	    # Before reporting this as a problem we have to check the
	    # lines between the two commands for content. Only empty
	    # lines (modulo whitespace) are considered to be trouble.
	    # Comment lines are ok.
	    
	    set v [getString $script [betweenranges $prevRange $cmdRange]]
	    if {[regexp "^(\[ \t\]*\n)+\$" $v]} {
		logError warnStyleCodeblockTooFar $cmdRange
	    }
	}
    }
    # Note: We have to compute the line the command ends on for
    # checking against the next, not the starting line.

    # Saved for use by indentation checking, which still needs data
    # about previous command, but doesn't have them in the regular
    # prev-variables, they already refer to data of the current
    # command, set below.
    set oldPrevRange    $prevRange
    set oldPrevCmdRange $prevCmdRange

    set  prevCmdRange $cmdRange
    set  prevRange [endofrange $cmdRange]
    set  prevLine  [getLine]
    incr prevLine  [parse countnewline $script $cmdRange $prevRange]
    return
}

proc analyzer::endofrange {range} {
    lassign $range start len
    return [list [expr {$start + $len - 1}] 1]
}

proc analyzer::betweenranges {rangea rangeb} {
    # assumes rangea before rangeb
    lassign $rangea sa la
    lassign $rangeb sb lb
    return [rangebetween [expr {$sa+$la}] $sb]
}

proc analyzer::rangebetween {a b} {
    return [list $a [expr {$b - $a}]]
}

proc analyzer::LogFlush {} {
    # Bugzilla 34989. Write the accumulated messages
    #puts LogFlush
    foreach cmd [logGet] {
	{*}$cmd
    }
    return
}

proc analyzer::ParseAfterSyntaxError {} {
    upvar 1 errPos errPos scriptRange scriptRange \
	scriptStart scriptStart scriptLen scriptLen \
	script script tail tail

    lassign $scriptRange s l
    set scriptRange [list $errPos [expr {$s + $l - $errPos}]]
    # XXX FIX JH: Should be fixed with regexp -all to not reiterate
    # XXX the regexp over the script.
    if {[regexp -indices {[^\\][\n;]} \
	     [parse getstring $script $scriptRange] match]} {
	set start     [parse charindex  $script $scriptRange]
	set scriptLen [parse charlength $script $scriptRange]
	set offset    [lindex $match 1]
	set end [expr {$start     + $offset + 1}]
	set len [expr {$scriptLen - $offset - 1}]
	set tail [parse getrange $script $end $len]
	setCmdRange $tail
	return continue
    }
    return break
}

proc analyzer::ParseAfterSyntaxErrorAscii {} {
    upvar 1 errPos errPos scriptRange scriptRange \
	scriptStart scriptStart scriptLen scriptLen \
	script script tail tail

    lassign $scriptRange s l

    set scriptStart $errPos
    set scriptLen   [expr {$s + $l - $errPos}]
    set scriptRange [list $scriptStart $scriptLen]

    #puts \tS'($scriptRange)

    # XXX FIX JH: Should be fixed with regexp -all to not reiterate
    # XXX the regexp over the script.
    if {[regexp -indices {[^\\][\n;]} \
	     [getString $script $scriptRange] match]} {

	#puts \tM|$match

	lassign $scriptRange start scriptLen
	lassign $match _ offset

	set end [expr {$start + $offset + 1}]
	set len [expr {$scriptLen - $offset - 1}]

	#puts \tE($end)
	#puts \tE($len)

	set tail [parse getrange $script $end $len]
	setCmdRange $tail

	#puts \tT'($tail)
	return continue
    }
    return break
}


namespace eval analyzer {
    variable lastcmdline {}
}

proc analyzer::HandleComment {commentRange} {
    variable script
    variable lastcmdline

    if {$lastcmdline ne [getLine]} {filter::clearLine}
    set lastcmdline [getLine]

    lassign $commentRange start len
    if {$len == 0} return

    # Retrieve the whitespace/comment in front of a command, do some
    # generic processing, and then hand it over to the standard
    # handler for extracting information from it. The generic processing does
    # - Remove whitespace before/after the whole block.
    # - Remove leading comment characters.
    # - Trailing whitespace (per line) is __not__ removed. User might have added
    #   some to disable a continuation line. Ditto for empty lines.

    set comment [getString $script $commentRange]

    regsub -all {^[ 	]*\#} $comment ""   comment
    regsub -all {\n[ 	]*\#} $comment "\n" comment

    FilterControl $comment

    # FUTURE : Here hook for additional plugins for the extraction
    # FUTURE : of information from comments in the code.

    return
}

# analyzer::addCheckers --
#
#	Add a set of checkers to the analyzer::checkers array.
#
# Arguments:
#	chkList 	An ordered list of checkers where the first
#			element is the command name and the second
#			element is the checker to execute.
#
# Results:
#	None.

proc analyzer::addCheckers {chkList} {
    foreach {name cmd} $chkList {
	set analyzer::checkers($name) [list $cmd]
    }
    return
}


proc analyzer::checkBuiltinCmd {chain pInfo tokens index} {
    # Just forward to the chained checker and drop the pInfo
    # data about the command ...

    # We have to capture any error message, our caller decides
    # what do to with it.

    #logOpen - Done in the caller (analyzeScript)
    {*}$chain $tokens $index
    return [logGet]
}

# analyzer::pushChecker --
#
#	Push a new command onto the checker array.
#
# Arguments:
#	cmdName		The name of the command.
#	cmd		The command to run to analyze cmdName
#
# Results:
#	None.

proc analyzer::pushChecker {cmdName cmd} {
    uproc::pushCheck $cmdName $cmd [isScanning]
    return
}

# analyzer::popChecker --
#
#	Pop the command checker off the command list.
#	If the list is empty, remove the checker for
#	the command from the checkers array.
#
# Arguments:
#	cmdName		The command name to pop.
#
# Results:
#	None.

proc analyzer::popChecker {cmdName} {
    uproc::popCheck $cmdName [isScanning]
}

# analyzer::topChecker --
#
#	Get the cmd to execute for the cmdName.
#
# Arguments:
#	cmdName		The command name to get the checker for.
#
# Results:
#	Returns the command to eval for the cmdName.

proc analyzer::topChecker {cmdName} {
    set res [pcx::topDefinition $cmdName]
    ## puts stderr topchecker/$cmdName/$res/
    return $res
}

# analyzer::logError --
#
#	This routine is called whenever an error is detected.  It is
#	responsible for invoking the filtering mechanism and then
#	recording any errors that aren't filtered out.
#
# Arguments:
#	mid		The message id that identifies a unique message.
#	errRange	The range where the error occured.
#	args		Any additional type specific arguments.
#
# Results:
#	None.

proc analyzer::logOpen {} {
    # Get is close.
    variable logLevel
    variable logStack
    variable capture

    incr    logLevel
    lappend logStack $capture
    logReset

    #::log::log debug "MESSAGE logOpen ($logLevel) - [getLocation]"

    return
}


proc analyzer::logReset {} {
    variable capture

    #::log::log debug "MESSAGE logReset"

    set      capture {}
    return
}

proc analyzer::logGet {} {
    variable capture
    variable logLevel
    variable logStack

    #::log::log debug "MESSAGE logGet ($logLevel) /[llength $capture]"
    #puts "MESSAGE logGet ($logLevel) /[llength $capture]"
    if 0 {
	set levels [info frame]
	set n -2
	set stack {}
	while {$levels > 2} {
	    puts STACK:\t[info frame $n]
	    incr n -1
	    incr levels -1
	}
    }

    set messages $capture

    set capture  [lindex $logStack end]
    if {$logLevel > 0} {
	set  logStack [lrange $logStack 0 end-1]
	incr logLevel -1
    }

    if {[llength $messages] > 0} {
	set res [list]
	#puts stderr Get_____________________________________
	#puts stderr \t[join [lsort -dict -index 3 $messages] \n\t]

	foreach item [lsort -dict -index 3 $messages] {
	    lappend res [linsert $item 0 analyzer::logError/Run]
	}
	#::log::log debug "MESSAGE logGet ($logLevel) /return [llength $res]"
	return $res
    }
    #::log::log debug "MESSAGE logGet ($logLevel) /return nothing"
    return {}
}


proc  analyzer::logErrorRunDefered {} {
    variable deferedMsg
    lassign [getLocation] file _ range
    lassign $range        start _

    # Flush all defered messages which are behind the line of
    # processing (Bug 82226).

    foreach loc [lsort -index 1 [array names deferedMsg [list $file *]]] {
	if {[lindex $loc end] > $start} break
	foreach m $deferedMsg($loc) {
	    analyzer::logExtendedError {*}$m
	}
	unset deferedMsg($loc)
    }
    return
}

proc analyzer::logError {mid errRange args} {
    return [logExtendedError {} $mid $errRange {*}$args]
}

proc analyzer::logExtendedError {extend mid errRange args} {
    # Message filtering happens here, at the time the message is
    # actually generated. This is required for the embedded
    # control. To have the filtering use the most current information
    # regarding the suppression status of message ids. Before embedded
    # control filtering could (and did) happen when the message were
    # about to be displayed. Doing it here is however a good thing
    # general, as it reduces the number of messages to transfer around
    # if heavy filtering is going on. Filtering at display time means
    # that lots of unwanted output is lugged around for some time.

    #puts LE|__($mid,$errRange,<[getLine]>,$args)

    set types [message::getTypes $mid]
    if {[filter::suppress $types $mid [getLine]]} {return 0}

    #puts LE|OK($mid,$errRange,$args)

    # The message is wanted, save it for display, in either next phase
    # or when returning from the nesting.

    if {[isScanning]} {
	# Scan errors are defered to analyze phase.
	# We do not record line, nor cmdrange, this
	# is added when the defered error is activated

	set newitem [linsert $args 0 $extend $mid $errRange]

	#::log::log debug "MESSAGE/defered:  $newitem"

	# Note: We are saving location as file/offset pair and later
	# flush when the processing is at or has passed the offset in
	# the file. At bit more complex in processing the deferals
	# later, yet it cannot miss a message we are not hitting
	# exactly during processing. Like for messages generated by
	# CheckStyleLineLength, which may apply to comments, something
	# the command processing will jump over (Bug 82226).

	lassign [getLocation] file _ range
	lassign $range        start _
	set offset [list $file $start]

	variable deferedMsg
	lappend  deferedMsg($offset) $newitem
    } else {
	variable capture
	variable logLevel

	set newitem [linsert $args 0 $extend $mid $errRange [getLine] [getCmdRange]]

	#::log::log debug "MESSAGE |$newitem|"
	#::log::log debug "CAPTURE |[join $capture "|\nCAPTURE |"]|"

	if {$newitem ni $capture} {
	    lappend capture $newitem

	    #::log::log debug "MESSAGE ($logLevel): $newitem /captured"
	} else {
	    #::log::log debug "MESSAGE ($logLevel): $newitem /ignored as duplicate"
	}
    }
    return 1
}

proc analyzer::logError/Run {extend mid errRange line cmdRange args} {
    # During scanning we do not move messages around, nor display
    # them. This is defered to the analyze phase.

    if {[isScanning]} return

    #::log::log debug "MESSAGE/r: [linsert $args 0 $extend $mid $errRange $line $cmdRange] /relog"

    # In a nested command, move the messages up the
    # capture stack ...

    variable logLevel
    if {$logLevel > 0} {
	#::log::log debug "MESSAGE: ($logLevel): Defering to higher level"

	variable capture
	set newitem [linsert $args 0 $extend $mid $errRange $line $cmdRange]

	if {$newitem ni $capture} {
	    lappend capture $newitem

	    #::log::log debug "MESSAGE/r: $newitem /recaptured"
	} else {
	    #::log::log debug "MESSAGE/r: $newitem /ignored as duplicate"
	}
	return
    }

    # Note: Filtering was done during message generation, see
    # logError. Here we can be sure that the message is ok to display.

    set types [message::getTypes $mid]

    # Record the occurence of errors and warnings.
    if {"err" in $types} {
	variable errCount
	incr     errCount
    } else {
	variable warnCount
	incr     warnCount
    }
    # Record how many messages per code. Verbose only.
    variable verbose
    if {$verbose || $configure::summary} {
	variable codeCount
	if {[info exists codeCount($mid)]} {
	    incr codeCount($mid)
	} else {
	    set codeCount($mid) 1
	}
    }

    #::log::log debug "MESSAGE: ($logLevel): SHOW ($mid ($errRange) $line ($cmdRange) ($args)) ($extend)"

    # Show the message.
    message::show $mid $errRange $line $cmdRange $args $extend
    return
}

# analyzer::isLiteral --
#
#	Check to see if a word only contains text that doesn't need to
#	be substituted.
#
# Arguments:
#	word		The token for the word to check.
#
# Results:
#	Returns 1 if the word contains no variable or command substitutions,
#	otherwise returns 0.

proc analyzer::isLiteral {word} {
    return [getLiteral $word dummy]
}

proc analyzer::isVar {word} {
    # Is the word a plain variable reference ?
    if {
	([lindex $word 0] eq "word") &&
	([llength [lindex $word 2]] == 1) &&
	[lindex $word 2 0 0] eq "variable"
    } {
	return 1
    } else {
	return 0
    }
}

# analyzer::hasExpansion --
#
#	Check the command for expansion words.
#
# Arguments:
#	words		The list of tokens of the command.
#	resultVar	The name of a variable where index of the
#			first expansion is stored.
#
# Results:
#	Returns 1 if the command contained {expand}/{*} codes,
#	otherwise returns 0.

proc analyzer::hasExpansion {words resultVar} {
    upvar 1 $resultVar result
    # words = list of tokens.

    set index 0
    foreach word $words {
	if {[getTokenType $word] eq "expand"} {
	    set result $index
	    return 1
	}
	incr index
    }

    return 0
}

# analyzer::getLiteral --
#
#	Retrieve the string value of a word without quotes or braces.
#
# Arguments:
#	word		The token for the word to fetch.
#	resultVar	The name of a variable where the text should be
#			stored.
#
# Results:
#	Returns 1 if the text contained no variable or command substitutions,
#	otherwise returns 0.

proc analyzer::getLiteral {word resultVar} {
    upvar 1 $resultVar result
    variable script

    if {0} {variable lmark ; if {[info exists lmark($word)]} {
	#puts stderr HIT/$word/\t$lmark($word)
	lassign $lmark($word) ok result
	return $ok
    } }
    #puts stderr MISS
    set result ""
    foreach token [lindex $word 2] {
	set type [lindex $token 0]
	if {$type eq "text"} {
	    append result [getString $script [lindex $token 1]]
	} elseif {$type eq "backslash"} {
	    append result [subst [getString $script [lindex $token 1]]]
	} else {
	    # Note: Tcl 8.5 expansion goes through this path and keys
	    # the word as dynamic. However in essence all the
	    # following words are dynamic as well as we cannot say
	    # anymore where in the syntax of the word we are. Worse,
	    # min/max checks become useless as well.

	    #set result [getString $script [lindex $word 1]]
	    #set lmark($word) {0 {}}
	    return 0
	}
    }

    if {$result eq "$"} {
	logError warnDollar [getTokenRange $word]
    }

    #set lmark($word) [list 1 $result]
    return 1
}

proc analyzer::getLiteralTail {word resultVar} {
    upvar 1 $resultVar result
    variable script
    set result ""
    set islit 0

    # We collect literal data, non literals reset the collection.
    # At the end we have the literal data which makes up the tail
    # of the word, if there is any.

    foreach token [lindex $word 2] {
	set type [lindex $token 0]
	if {$type eq "text"} {
	    append result [getString $script [lindex $token 1]]
	    set islit 1
	} elseif {$type eq "backslash"} {
	    append result [subst [getString $script [lindex $token 1]]]
	    set islit 1
	} else {
	    set result ""
	    set islit 0
	}
    }
    return $islit
}

# analyzer::getLiteralPos --
#
#	Given an index into a literal, compute the corresponding position
#	within the word from the script.
#
# Arguments:
#	word		The original word for the literal.
#	pos		The index within the literal.
#
# Results:
#	Returns the byte offset within the original script that corresponds
#	to the given literal index.

proc analyzer::getLiteralPos {word pos} {
    variable script
    set tokens [lindex $word 2]
    set count [llength $tokens]
    # XXX AK - Can we foreach over tokens here?
    for {set i 0} {$i < $count} {incr i} {
	set token [lindex $tokens $i]
	# XXX AK consider lassign to split token & range data into vars.
	set range [lindex $token 1]
	if {[lindex $token 0] eq "backslash"} {
	    set len [string length [subst \
		    [getString $script $range]]]
	} else {
	    set len [lindex $range 1]
	}
	if {$pos < $len} {
	    return [expr {[lindex $range 0]+$pos}]
	}
	incr pos -$len
    }

    # We fell off the end add the remainder to the first character after
    # the last token.

    lassign $range s l
    return [expr {$s + $l + $pos}]
}

# analyzer::getLiteralRange --
#
#	Given a range into a literal, compute the corresponding range
#	within the word from the script.
#
# Arguments:
#	word		The original word for the literal.
#	range		The range within the literal.
#
# Results:
#	Returns the range within the original script that corresponds
#	to the given literal range.

proc analyzer::getLiteralRange {word range} {
    lassign $range start len
    set end [expr {$start+$len}]
    set origStart [getLiteralPos $word $start]
    set origLen [expr {[getLiteralPos $word $end] - $origStart}]
    return [list $origStart $origLen]
}

# analyzer::checkScript --
#
#	Call the appropriate command based on the phase of checking
#	we are currently doing.
#
# Arguments:
#	scriptRange	The range in the script to analyze. A
#			default of {} indicates the whole script.
#
# Results:
#       None.

proc analyzer::checkScript {{scriptRange {}}} {
    variable scriptIsAscii
    variable scriptNesting
    incr     scriptNesting 1

    #::log::log debug _________________________checkScript/$scriptRange

    # Embedded control, block scope handling. Retain outer setting of
    # scope when entering, and restore outer settings after the block
    # has been handled.

    filter::blockSave

    if {[isScanning]} {
	scanScript $scriptRange
    } else {
	if {$scriptNesting > $configure::maxnesting} {
	    logError warnStyleNesting $scriptRange $configure::maxnesting
	}
	style::save
	if {$scriptIsAscii} {
	    # XXX: If string length == charlength, we have an all-ascii script,
	    # XXX: so use string functions for speed
	    analyzeScriptAscii $scriptRange
	} else {
	    analyzeScript $scriptRange
	}
	style::restore
    }

    filter::blockReset
    incr scriptNesting -1
    return
}

# analyzer::checkContext --
#
#	Push the new context on its stack and call the chain command
#	to analyze the command inside the new state.  When the
#	command is done being checked by the chain command, pop the
#	context stack.  This routine should be called during the
#	final analyze phase and passed a token tree and current
#	index, where the index is the name of the proc being defined.
#
# Arguments:
#	cIndex		The index to use to extract context info.
#	strip		Boolean indicating if the word containing
#			the context name should have the head stripped
#			off (i.e. "proc" vs. "namespace eval")
#	chainCmd	The chain cmd to eval in the new context.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkContext {cIndex strip chainCmd tokens index} {
    # Push the new context onto the stack.  If the token
    # pointed at by cIndex is a non-literal, push the
    # UNKNOWN descriptor.

    #::log::log debug "analyzer::checkContext <<< ..."

    set word [lindex $tokens $cIndex]
    if {[getLiteral $word context]} {

	#::log::log debug "--- ($context)"

	if {$strip} {
	    set context [context::head $context]
	}

	#::log::log debug "--- ($context)"

	context::push [context::join [context::top] $context]
    } else {
	context::push UNKNOWN
    }

    # Parse the remaining portion of the command with the
    # new context info.

    #::log::log debug "CHAIN <<< ..."

    # Remember current scoping
    set mark [context::markScope]

    set index [{*}$chainCmd $tokens $index]

    #::log::log debug "... >>> CHAIN"

    # Return the context stack back to the previous state.
    context::pop

    # Return scope to state before this command.
    context::popScopeToMark $mark

    #::log::log debug "... >>> analyzer::checkContext"
    return $index
}

# analyzer::checkUserProc --
#
#	Check the user-defined proc for the correct number
#	of arguments.  For procs that have been multiply
#	defined, check all of the argLists before flagging
#	an error.  This routine should be called during the
#	final analyzing phase of checking, after the proc
#	names have been found.
#
# Arguments:
#	pInfo		The proc info type of the proc to check.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the commands to call to log an error if this
#	user proc failed.  Otherwise, return empty string if
#	the user proc passed.

proc analyzer::checkUserProc {pInfo tokens index} {
    set argc  [llength $tokens]
    set min   [cdb getMin  $pInfo]
    set max   [cdb getMax  $pInfo]

    # We close the capture level opened for us in 'analyzeScript'.
    # It is irrelevant, we have no nesting, and we return any
    # error directly, see below.

    # Bug 86552. We may have logged errors in the closed capture level
    # from previous checks for the same command, either this word, or
    # previous words. Return them.

    set previous [logGet]
    # Check for the correct number of arguments.

    if {($argc >= ($min + $index)) \
	    && (($max == -1) || ($argc <= ($max + $index)))} {
	return $previous
    } else {
	set name [cdb getName $pInfo]
	if {[string match "::*" $name]} {
	    set name [string range $name 2 end]
	}

	set mid procNumArgs
	set types [message::getTypes $mid]
	if {[filter::suppress $types $mid [getLine]]} { return {} }

	lappend previous [list ::analyzer::logError/Run {} $mid {} [getLine] [getCmdRange] $name]
	return $previous
    }
}

# analyzer::checkRedefined --
#
#	Check to see if the proc is defined more then once.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkRedefined {tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word name]} {
	set fq [context::join [context::top] $name]
	uproc::isRedefined $fq proc
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkAsStyle {style chain tokens index} {
    style::override $style
    return [{*}$chain $tokens $index]
}

# analyzer::checkBody --
#
#	Parse a script body by stripping off any quote characters.
#
#	Attempt to parse a word like it is the body of a control
#	structure.  If the word is a simple string, it passes it to
#	checkScript, otherwise it just treats it like a normal word
#	and looks for subcommands.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkBody {tokens index} {
    checkBodyOffset 0 $tokens $index
}

proc analyzer::checkBodyOffset {offset tokens index} {
    set word [lindex $tokens $index]

    # Bug 80456: style is conditional on this being not a plain
    # variable reference. Such bodies can't be checked for style.
    if {![isVar $word]} {
	if {[style::overridden T]} {
	    style::set $index $T
	} else {
	    style::set $index body
	}
    }
    if {[isLiteral $word]} {
	variable script
	set range [lindex $word 1]
	set quote [getChar $script $range]
	if {$quote eq "\"" || $quote eq "\{"} {
	    lassign $range s l
	    set range [list [expr {$s + 1}] [expr {$l - 2}]]
	}

	if {$offset > 0} {
	    lassign $range start length
	    incr start $offset
	    # XXX AK The '0-$offset' is needed iff offset can be
	    # negative. Is that possible/allowed ? Rewrite to '[- $offset]'? TIP xxx?
	    incr length [expr {0 - $offset}]
	    set range [list $start $length]
	}

	#::log::log debug _________________________checkBodyOffset/$range

	# Embedded control, local scope handling. Retain outer setting
	# of scope when entering, and restore outer settings after the
	# block has been handled.

	filter::localSave

	checkScript $range

	filter::localReset

	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc ::analyzer::checkValidateBody {tokens index} {
    variable script
    variable trueScript

    set word [lindex $tokens $index]

    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }

    # The body is a literal, we can check it.

    # One separate pass over the literal to check the correctness of
    # %-placeholders. And if there are some use the same trick as used
    # for [expr] (see analyzer.tcl, checkExpr, line 2296) to replace
    # the placeholders with acceptable data ('%%' => ' %', '%x' => '$x').

    set start [lindex [lindex [lindex [lindex $word 2] 0] 1] 0]
    set end   [lindex [lindex [lindex $word 2] end] 1]
    set range [list $start [expr {[lindex $end 0] + [lindex $end 1] - $start}]]
    set start [lindex $range 0]
    set size  [lindex $range 1]

    set head   [string range $script 0            [expr {$start-1}]]
    set tail   [string range $script [expr {$start+$size}]      end]
    set script [string range $script $start [expr {$start+$size-1}]]

    # Now we have the script before and after the bind script, and the
    # bind script itself. Check for %-characters in the literal/bind script
    # Note invalid placeholders, note number of substitutions.

    set nscript [ReplacePercentsValidate $script $word]
    set save       $script
    set trueScript $save
    set script     $head$nscript$tail

    set res [checkBody $tokens $index]

    set script     $save
    set trueScript {}

    return $res
}

namespace eval ::analyzer {
    variable vpercent {
	%d {[]} %i {[]} %P {[]} %s {[]} %S {[]} %v {[]} %V {[]} %W {[]}
    }
}

proc ::analyzer::ReplacePercentsValidate {script word} {
    variable vpercent

    set nscript [string map $vpercent $script]

    if {[regexp {%} $nscript]} {
	logError badValidateSubst [getTokenRange $word] $script
    }

    return $nscript
}

# analyzer::checkWord --
#
#	Examine a word for subcommands.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkWord {tokens index} {
    set word [lindex $tokens $index]
    set type [getTokenType $word]

    if {[style::using]} {
	checkWordStyle $word $index
    }

    if {$type eq "variable"} {
	variable script
	set range [getTokenRange [lindex [getTokenChildren $word] 0]]
	set name  [getString $script $range]

	# Extract the full name of the variable, including subscript
	# of array if existing.
	set fullname [getString $script [getTokenRange $word]]
	regsub "^\\$"       $fullname {}   fullname
	regsub "^\{(.*)\}$" $fullname {\1} fullname

	checkVariable read $name $fullname $range $word

	# Note that if style-checks are active the subwords of the
	# variable need checking. We open a new style scope and set
	# the proper codes. The first word is always a varname, and a
	# second child, if present, an index without style.
	if {[style::using]} {
	    style::save
	    style::clear
	    style::set 0 varname/rhs
	}
	foreach subword [getTokenChildren $word] {
	    checkWord [list $subword] 0
	    style::set 0 none
	}
	if {[style::using]} {
	    style::restore
	}
    } elseif {$type eq "subexpr" || $type eq "word"} {
	# Note that while we disable the style checks for recursive
	# checkWord invokations we do not do so summarily with
	# 'style::use', but per-word via a special style-code. This
	# allows us to regain/perform checking on inner words, like
	# variable references buried in the word.
	if {[style::using]} {
	    style::save
	    style::clear
	    style::set 0 none
	}
	foreach subword [getTokenChildren $word] {
	    checkWord [list $subword] 0 ; # (**)
	}
	if {[style::using]} {
	    style::restore
	}
    } elseif {$type eq "command"} {
	variable scriptNesting
	variable bracketNesting
	set range [lindex $word 1]
	lassign $range s l
	set range [list [expr {$s + 1}] [expr {$l - 2}]]
	# Bracket-nesting does not count as a nesting level for
	# refactorization. Instead of making the counting code in
	# checkScript conditional and providing some flag argument we
	# simply cancel the counting actions taken by the command.
	incr scriptNesting -1
	incr bracketNesting
	def'hold
	if {[style::using]} {
	    # Fully disable style check during the recursion, and
	    # prevent changes to the current state.
	    style::save
	    style::clear
	    style::use 0
	    checkScript $range
	    style::use 1
	    style::restore
	} else {
	    checkScript $range
	}
	def'unhold
	incr bracketNesting -1
	incr scriptNesting
    } elseif {$type eq "simple"} {
	getLiteral $word v
	if {[regexp -indices "(\\\\)\[ \t\]+\n" $v -> end]} {
	    lassign $end s e
	    set range [getTokenRange $word]
	    set range [list [expr {[lindex $range 0]+$s+1}] 1]
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wregsub "\\\\\\s+\n" "\\\n" replace $index \
		     save] \
		badContinuation $range
	}
    } elseif {$type eq "backslash"} {
	variable script
	set range [getTokenRange $word]
	lassign $range s l
	set erange [list $s [expr {[string length $script] - $s}]]
	set v [getString $script $erange]
	if {[regexp -indices "^(\\\\)\[ \t\]+\n" $v -> end]} {
	    lassign $end s e
	    set range [list [expr {[lindex $range 0]+$s}] 1]

	    # AK XXX: A bad continuation between words looks to be
	    # part of a word, where it is introduced by a backslash,
	    # making it type 'word' instead of 'simple'. Therefore we
	    # are here in checkWord recursively called for this single
	    # token. See (**) above in this procedure for the calling
	    # location. To get the tokens of the actual command we
	    # have to peek into the calling context. We do not need
	    # the index, as it has to be the last word of the command.
	    upvar 1 tokens xtokens
	    logExtendedError \
		[CorrectionsOf 0 $xtokens \
		     get end wtrimr replace end save] \
		badContinuation $range
	}
    }

    incr index
    #return $index

    # Check for unmatched trailing brackets or braces in all words.

    if {$type ne "simple" && $type ne "word"} {
	return $index
    }
    set lasttok [lindex $word 2 end]
    set type [lindex $lasttok 0]
    if {$type eq "command" || $type eq "backslash"} {
	return $index
    }

    set range [lindex $lasttok 1]
    lassign $range s l
    set range [list [expr {$s+$l-1}] 1]

    CheckExtraCloseChar "\[" "\]" $word $range $tokens $index
    CheckExtraCloseChar "\{" "\}" $word $range $tokens $index
    return $index
}

# analyzer::CheckExtraCloseChar --
#
#	If the word ends in the closeChar character, make sure there is an
#	openChar character somewhere in the word.
#
# Arguments:
#	openChar	The opening char we match against a closing char,
#			either "\{" or "\[".
#	closeChar	The closing char we make sure is matched with an open char,
#			either "\]" or "\}".
#	word		The word to check.
#	range		The range to report for the word.
#
# Side Effects:
#	Logs a warnExtraClose warning if an unmatched close brace is detected.
#
# Results:
#	None.

proc ::analyzer::CheckExtraCloseChar {openChar closeChar word range tokens index} {
    variable script
    # Check for unmatched trailing brackets or braces in all words.  We only
    # check if the last character in the word is an unquoted bracket/brace that
    # isn't part of a subcommand invocation.  If we see a trailing bracket/brace,
    # we then scan each subtoken to see if it contains an open bracket/brace that
    # isn't quoted or part of a subcommand.  If there are no open brackets/braces
    # we generate the warning.  Note that this algorithm should handle most
    # common cases.  It will not detect unmatched brackets/braces in the middle of
    # a word.
    #
    # Note that backslash-quoted brackets/braces are OK.
    #
    # Note that this check is only a warning because Tcl is perfectly happy
    # to pass a naked close bracket/brace to a command without complaining and
    # people occasionally take advantage of this fact.  This is not
    # recommended practice, so we will still flag it as a potential error.

    if {[getString $script $range] ne $closeChar} {
	# Range is not a bracket/brace, ok
	return
    }

    # AS Bugzilla 58047
    # AS Bugzilla 58018

    lassign $range rstart rlen
    set previous [list [incr rstart -1] 1]

    if {[getString $script $previous] eq "\\"} {
	# Range is backslash-quoted, ok
	return
    }

    # Now the complex check if it is part of a subcommand, or quoted
    # through a matching opening bracket/brace.

    foreach subword [lindex $word 2] {
	set type [lindex $subword 0]
	if {$type eq "command"} {
	    continue
	}
	set subrange [lindex $subword 1]
	if {[string first $openChar [getString $script $subrange]] != -1} {
	    return
	}
    }

    incr index -1
    logExtendedError \
	[CorrectionsOf 0 $tokens \
	     get $index wsplit {} dropafter end-1 wjoin {} replace $index save] \
	warnExtraClose $range
    return
}

proc analyzer::checkWordStyle {word index} {
    #variable script ; upvar type type
    #puts '\[$index]=$type|[style::get $index]'\t<[getString $script [getTokenRange $word]]>
    switch -exact -- [style::get $index] {
	args {
	    upvar 1 tokens tokens
	    checkQuotes "\{" warnStyleArgumentList $word
	}
	body {
	    upvar 1 tokens tokens
	    checkQuotes "\{" warnStyleCodeBlock $word 1
	    checkBodyHeadTail $word
	}
	body/single-line {
	    upvar 1 tokens tokens
	    checkQuotes "\{" warnStyleCodeBlock $word 0
	}
	string {
	    set type [getTokenType $word]
	    if {
		($type eq "simple") &&
		[hasQuotes "\{" $word]
	    } {
		variable script
		upvar 1 tokens tokens
		set range [getTokenRange $word]
		set literal [getString $script $range]
		if {
		    ![string match "*\$*" $literal] &&
		    ![string match "*\\\[*" $literal]
		} {
		    logExtendedError \
			[CorrectionsOf 0 $tokens \
			     get $index wapoquote replace $index save] \
			warnStylePlainWord $range
		}
	    }
	    if {
		($type eq "word") &&
		([llength [getTokenChildren $word]] == 1) &&
		([getTokenType [lindex [getTokenChildren $word] 0]] eq "variable") &&
		[hasQuotes "\"" $word]
	    } {
		# Word is double-quoted simple variable reference
		set range [getTokenRange $word]
		upvar 1 tokens tokens
		logExtendedError \
		    [CorrectionsOf 1 $tokens \
			 get $index wtrim/ \" replace $index save] \
		    warnStylePlainVar $range
	    }
	}
	none {
	    # No style checks on this word.
	}
	cmdname {
	    # No style checks for command words.
	}
	procname {
	    # Bug 77231, R2.1 - Deviation I am allowing :: and thus namespaced procnames.
	    checkWordStyleRegexp proc warnStyleNameProcedure $word
	}
	nsname {
	    # Bug 77231, R2.2
	    checkWordStyleRegexp namespace warnStyleNameNamespace $word
	}
	varname/lhs {
	    variable script
	    # Bug 77231, R2.3
	    # Variable name as argument to some command, not a
	    # reference. These names may be array names, stem and
	    # index and all. We have to locate and strip the index
	    # before checking.

	    set literal [getString $script [getTokenRange $word]]
	    set idxstart [string first "(" $literal]
	    #puts X|$word|$idxstart
	    if {$idxstart >= 0} {
		lassign $word wtype wrange wchildren
		lassign $wrange ws wl
		set word [list $wtype [list $ws $idxstart] $wchildren]
	    }
	    checkStyleVariableName $word
	}
	varname/rhs {
	    # Bug 77231, R2.3
	    # Variable names inside of variable references. Due to the
	    # parsing we will see only plain scalar names here. The
	    # index data is a separate word and goes through style
	    # 'none', see 'checkWord'.
	    checkStyleVariableName $word
	}
	pkgname {
	    # Bug 77231, R2.4
	    checkWordStyleRegexp package warnStyleNamePackage $word
	}
	default {
	    puts UNKNOWN-STYLE-[style::get $index]@$index
	}
    }
    return
}

proc analyzer::checkStyleVariableName {word} {
    variable script
    checkWordStyleRegexp variable warnStyleNameVariable $word

    set range     [getTokenRange $word]
    set varlength [lindex $range 1]

    # XXX AK: Consider pcx command, cmdline switch to set the allowed
    # XXX range for the length of variable names.
    if {$varlength < 3} {
	logError warnStyleNameVariableTooShort $range [getString $script [getTokenRange $word]] 3
    } elseif {$varlength > 10} {
	logError warnStyleNameVariableTooLong $range [getString $script [getTokenRange $word]] 10
    }
    return
}

proc analyzer::checkWordStyleRegexp {pid mid word} {
    variable script
    #puts _|________________________________________
    #puts P|$pid|[style::pattern::get $pid]
    #puts M|$mid|
    #puts W|$word|[getLiteral $word literal]

    if {![getLiteral $word literal]} return
    set literal [getString $script [getTokenRange $word]]
    set pattern [style::pattern::get $pid]

    #puts L|$literal|\t|$pattern|[regexp -- $pattern $literal]|
    if {[regexp -- $pattern $literal]} return
    logError $mid [getTokenRange $word] $literal $pattern
    return
}

proc analyzer::checkBodyHeadTail {word} {
    variable script

    # Bug 77230, R1.1
    # Check that the beginning and closing braces have newlines
    # after/before them and the actual code in the block.

    set literal [getString $script [getTokenRange $word]]
    if {[string match "\{*" $literal]} {
	set literal [string range $literal 1 end-1]
    }

    regexp {^([ \t\n]*)} $literal -> head
    regexp {([ \t\n]*)$} $literal -> tail

    if {![string match *\n* $head] || ![string match *\n* $tail]} {
	upvar 1 tokens tokens index index
	logExtendedError \
	    [CorrectionsOf 1 $tokens \
		 get $index wunquote replace $index \
		 indent! 1 braces $index $index save] \
	    warnStyleCodeBlockShort [getTokenRange $word]
    }
    return
}

proc analyzer::checkQuotes {qexpected mid word {indent 0}} {
    if {![hasQuotes $qexpected $word]} {
	upvar 1 tokens tokens index index
	logExtendedError \
	    [CorrectionsOf 0 $tokens \
		 indent! $indent braces $index $index save] \
	    $mid [getTokenRange $word]
    }
    return
}

proc analyzer::hasQuotes {qexpected word} {
    variable script
    set range [lindex $word 1]
    set quote [getChar $script $range]
    return [expr {$quote eq $qexpected}]
}

proc analyzer::CheckStyleLineLength {} {
    # Bug 77230, R1.4
    variable script
    variable scanning
    set offset 0
    foreach line [split $script \n] {
	set start $offset
	set llen [string length $line]
	#puts <$start,$llen>

	incr offset $llen
	incr offset 1
	if {$llen <= 80} continue

	#puts \tERROR|[string range $script $start [expr {$start + $llen - 1}]]|
	set lrange [list $start $llen]

	# Note: The command range has to be set for two reasons:
	# (1) The message display needs for the correct calculation of
	#     the caret lines.
	# (2) This updates the line information, also need for the
	#     start/end filter to work correctly.
	#
	# We get away without push/popCmdRange because this happens in
	# the whole-file section before the regular range processing
	# happens.
	setCmdRange $lrange

	# We know that we are in the analyze phase. That is why saving
	# of the old value is not required. We use the scan-flag to
	# force the deferal of the message we generate here, to allow
	# pragmas in the code to suppress them as usual (Bug 82226).
	set scanning 1
	logError warnStyleLineTooLong $lrange 80
	set scanning 0
    }
    return
}

# ### ######### ###########################
## Checkers and commands for command ordering

proc analyzer::checkOrdering {chains tokens index} {
    if {![isScanning]} timeline::open
    foreach chain $chains {
	set last [{*}$chain $tokens $index]
    }
    if {![isScanning]} timeline::close
    return $last
}

proc analyzer::checkOrderLoop {chain tokens index} {
    if {![isScanning]} timeline::loopbegin
    set index [{*}$chain $tokens $index]
    if {![isScanning]} timeline::loopclose
    return $index
}

proc analyzer::checkOrderBranch {chain tokens index} {
    if {![isScanning]} timeline::branchopen
    set index [{*}$chain $tokens $index]
    if {![isScanning]} timeline::branchclose
    return $index
}

proc analyzer::checkOrderBranches {chain tokens index} {
    if {![isScanning]} timeline::branchesfork
    set index [{*}$chain $tokens $index]
    if {![isScanning]} timeline::branchesjoin
    return $index
}

proc analyzer::checkOrderOf {package name chain tokens index} {
    if {![isScanning]} {
	#puts "OA ([getString [getScript] [getCmdRange]]) = $package/$name"
	timeline::extend $package $name [getCmdRange] [getLine]
    }
    if {[llength $chain]} {
	return [{*}$chain $tokens $index]
    }
    return $index
}

# analyzer::checkVariable --
#
#	Check a variable name against a list of special names.
#
# Arguments:
#	name		The variable name to check.
#	range		The range to report for the variable.
#
# Results:
#	None.

proc analyzer::checkVariable {mode varName varNameFull range varword {ntype scalar}} {

    # Mode independent checks. Usage of non-portable variables.
    # In case of mode "write" varName is the same as varNameFull.

    if {$varName eq "tcl_precision"} {
	logError nonPortVar $range "tcl_precision"
    } elseif {$varName eq "tkVersion"} {
	upvar 1 tokens tokens index index
	WarnUnsupported 0 $range "tk_version" {} {} $tokens $index
    }

    #::log::log debug "checkVariable Stem \[$varName\]"
    #::log::log debug "checkVariable Full \[$varNameFull\]"

    if {![isScanning]} {
	# Definition/Usage tracking ...
	# Note: Usage of 'varNameFull' is _not_ correct. For arrays
	#       this contains the index part too. This is not stored
	#       in the var-db.

	#::log::log debug "checkVariable ($varName) | ($varNameFull)"

	if {$varName ne $varNameFull} {
	    # The variable is an array access. Check for a literal
	    # subscript. If we have one, we register both the stem and
	    # the full name as definition and/or usage.

	    if {[isLiteral [lindex [getTokenChildren $varword] 1]]} {
		TrackDefUseOfVariable $mode $varNameFull $range
	    }
	} else {
	    # Sometimes an array access slips through the test above.
	    if {
		[getTokenType $varword] eq "simple" &&
		[regexp {^([^(]*)\([^)]*\)$} $varNameFull -> stem]
	    } {
		TrackDefUseOfVariable $mode $stem $range
	    }
	}
	TrackDefUseOfVariable $mode $varName $range
    }

    # Mode dependent checks from now on.

    if {$mode eq "read"} {
	# tkPriv / tk::Priv array ... Checks depend on chosen
	# version ...

	if {[string match "tkPriv*" $varNameFull]} {
	    variable after83
	    ## TODO Move this code to coreTcl
	    if {$after83} {
		upvar 1 tokens tokens index index
		WarnUnsupported 0 $range "tk::Priv" {} {} $tokens $index
	    } else {
		# variable is private and should not be read
		logError nonPublicVar $range $varNameFull
	    }
	    if {$ntype eq "scalar"} {
		if {$varNameFull eq "tkPriv"} {
		    logError arrayReadAsScalar $range $varNameFull
		    return
		}
	    }
	    return
	}

	### TODO ### Use the new scope stack to help here ...
	# Note: How/Can we to deal with execution context
	# (should be able to check "namespace eval tk {...}")

	if {[string match "tk::Priv*" $varNameFull]} {
	    # TODO Move this code to coreTcl
	    variable before84
	    if {$before84} {
		upvar 1 tokens tokens index index
		WarnUnsupported 0 $range "tkPriv" {} {} $tokens $index
	    } else {
		# variable is private and should not be read
		logError nonPublicVar $range $varNameFull
	    }
	    if {$ntype eq "scalar"} {
		if {$varNameFull eq "tk::Priv"} {
		    logError arrayReadAsScalar $range $varNameFull
		    return
		}
	    }
	    return
	}

	# Reading from tcl_platform is hazardous, information is non
	# portable ... wordSize is new ...

	if {[string match "tcl_platform*" $varNameFull]} {
	    if {$varNameFull eq "tcl_platform"} {
		if {$ntype eq "scalar"} {
		    logError arrayReadAsScalar $range $varNameFull
		}
		return
	    } elseif {$varNameFull ne "tcl_platform(user)"} {
		# reading non portable information
		# logError nonPortVar $range $varNameFull
	    }

	    # TODO Move this code to coreTcl
	    # Scan through defined elements and warn if the element is
	    # not known in the chosen version of tcl.

	    if {![regexp {tcl_platform\((.*)\)} $varNameFull -> index]} {
		# Not an array access of tcl_platform, but some other
		# variable. No additional checks.

		return
	    }

	    set items {
		7.3 {}
		7.4 {}
		7.5 {machine os osVersion platform}
		7.6 {}
		8.0 {byteOrder}
		8.1 {user}
		8.2 {isWrapped}
		8.3 {}
		8.4 {wordSize}
		8.6 {pathSeparator}
	    }
	    # isWrapped is a special key used by the TclPro wrapper to
	    # indicate that a script is run as part of a wrapped
	    # application. The checker should know this.

	    set found 0
	    variable coreTcl
	    foreach {v itemlist} $items {
		foreach item $itemlist {
		    if {"$index" eq "$item"} {
			set found 1
			break
		    }
		}
		if {$found} break
		if {"$v" == $coreTcl} {
		    break
		}
	    }
	    if {!$found} {
		logError badArrayIndex $range $index
	    }
	}
    } elseif {$mode eq "write"} {
	# TODO Move this code to coreTcl

	if {($varName eq "tcl_traceExec") || ($varName eq "tcl_traceCompile")} {
	    # BCC tracing in a write context is possible but wrought
	    # with hazard.
	    variable after83
	    if {$after83} {
		logError warnBehaviour $range \
			"$varName has its tracing function only if the core\
			running this code was compiled with TCL_COMPILE_DEBUG"
	    }
	} elseif {[string match "tcl_platform*" $varName]} {
	    # Writing to tcl_platform is bad!
	    logError warnReadonlyVar $range tcl_platform
	} elseif {[string match "tkPriv*" $varName]} {
	    # tkPriv / tk::Priv array is considered read-only
	    variable after83
	    if {$after83} {
		upvar 1 tokens tokens index index
		WarnUnsupported 0 $range "tk::Priv" {} {} $tokens $index
	    }
	    logError warnReadonlyVar $range tkPriv
	    logError nonPublicVar    $range tkPriv
	    return
	} elseif {[string match "tk::Priv*" $varName]} {
	    # tkPriv / tk::Priv array is considered read-only
	    variable before84
	    if {$before84} {
		upvar 1 tokens tokens index index
		WarnUnsupported 0 $range "tkPriv" {} {} $tokens $index
	    }
	    logError warnReadonlyVar $range tk::Priv
	    logError nonPublicVar    $range tk::Priv
	    return
	}
    } elseif {($mode eq "decl") || ($mode eq "syntax")} {
	# No checks for declarations and plain checks.
    } else {
	logError internalError $range \
		"analyzer::checkVariable expected\
		\"decl\", \"syntax\", \"read\" or \"write\" for mode,\
		got \"$mode\""
    }

    return
}

proc analyzer::TrackDefUseOfVariable {mode varName range} {
    ## return ; ## 3.0 FEATURE OFF

    #::log::log debug "TrackDefUseOfVariable \{$mode $varName \{$range\}\}"

    if {$mode eq "read"} {
	# The variable is used here ...

	#lassign [set scope [context::topScope]] type name loc

	# Procedure, or namespace ...

	set id [VarNameToId $varName type]
	xref::varUseAt $id
	if {![xref::varDefinedAt $id _dummy_]} {
	    logError warnUndefinedVar $range $varName
	}

    } elseif {$mode eq "write"} {
	# This command defines the variable (if not existing).
	# Generate a definition. If there are similarly named
	# definitions for the same scope we issue a 'typo'
	# warning.

	if {0 && $TODO && [xref::varSimilarTo $varName idlist]} {
	    logError TODO {0 0} TODO/similar/$varName
	}

	set id [VarNameToId $varName deftype]
	def'er [list xref::varDefAt local $id]

	if {$deftype eq "relative"} {
	    # Check for scope definitions which are read-only.
	    # Warn of overwrite ...

	    if {[xref::varDefinedAt $id defs]} {
		foreach d $defs {
		    array set _ $d
		    if {$_(type) eq "argument"} {
			logError warnArgWrite $range $varName
			unset _
			break
		    }
		    unset _
		}
	    }
	}
    }
    # mode eq decl : Ignored. Each declarative command does
    # something special, so we create special checking for
    # them. ... FOR NOW ... We may add something to cover our
    # bases.
    return
}


proc analyzer::VarNameToId {varName {typevar {}}} {

    #::log::log debug "VarNameToId \{$varName\}"

    # The variable is used here ...

    lassign [set scope [context::topScope]] type name loc

    if {$typevar ne {}} {
	upvar 1 $typevar deftype
    } else {
	set deftype {}
    }

    if {[regexp {^::} $varName]} {
	# Absolute name

	#::log::log debug "VarNameToId => absolute ($varName)"

	set deftype absolute
	return [xref::varIdAbsolute $varName]

    } else {
	# Check if the varname is an array access.
	# We have to restrict our check to the stem.

	if {![regexp {^([^(]*)\([^)]*\)$} $varName -> stem]} {
	    set stem $varName
	}
	if {[regexp {::} $stem]} {
	    # Qualified name.
	    # Use [context] stack for search ..

	    set ctx     [context::locate [context::top] $varName]
	    set absname [context::join $ctx [namespace tail $varName]]

	    #::log::log debug "VarNameToId => CTX ($ctx)"
	    #::log::log debug "VarNameToId => ABS ($absname)"

	    set deftype qualified
	    return [xref::varIdAbsolute $absname]
	} else {
	    # Relative name, has to be proc/ns-local

	    # Bugzilla 28919. Not quite. If the code doing the var
	    # access is at the global level, then this unqualified
	    # variable is searched in the global context too.

	    #::log::log debug "Current context: [join $context::contextStack "\nCurrent context: "]"
	    #::log::log debug "Current scope:   [join $::context::scopeStack "\nCurrent scope:   "]"

	    if {[context::topScope] eq [context::globalScope]} {
		#::log::log debug "VarNameToId => absolute ... ($varName) **"

		set deftype absolute
		return [xref::varIdAbsolute ::$varName]
	    } else {
		#::log::log debug "VarNameToId => relative ... ($varName)"

		set deftype relative
		return [xref::varId $varName]
	    }
	}
    }
}


# analyzer::checkExpr --
#
#	Attempt to parse a word like it is an expression.
#	If the word is a simple string, it is examined for subcommands
#	within the expression, otherwise it is handled like a normal word.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkExpr {tokens index} {
    variable exprNesting
    set word [lindex $tokens $index]

    incr exprNesting
    npush expr

    # Bug 81791. Unbraced and un-double-quoted single word is
    # slow. Double-quoted word which is not literal is in danger of
    # double-subst.
    if {
	!([analyzer::hasQuotes "\{" $word] || [analyzer::hasQuotes "\"" $word]) ||
	([analyzer::hasQuotes "\"" $word] && ![isLiteral $word])
    } {
	logExtendedError \
	    [CorrectionsOf 0 $tokens \
		 braces 1 end save] \
	    warnExpr [getTokenRange $word]
    }

    #  Don't attempt to parse as an expression if the text contains
    #  substitutions.

    if {![isLiteral $word]} {
	incr exprNesting -1
	npop
	return [checkWord $tokens $index]
    }

    # Compute the range of the expression from the first and last token in
    # the word.

    set start [lindex $word 2 0 1 0]
    set end   [lindex $word 2 end 1]
    lassign $end s l
    set range [list $start [expr {$s + $l - $start}]]

    # Parse the word as an expression looking for subcommands.

    variable script
    if {[catch {parse expr $script $range} tree]} {

	# The expression might contain binary operators the core
	# executing the checker does not know about. Example:
	# "ne", "eq" for string comparison.

	# This happens to be a parsing error because the binary
	# operators are hardcoded into the parser, whereas functions
	# are parsed generically and only the later stages of the
	# bytecode compiler look them up in the table of declared math
	# functions. This means that the checker running on an older
	# core will fail to parse expressions containing newer
	# operators, if we don't help it. This help is what we do
	# below.

	# -----------------------------------------------------------

	# We now look for all such operators and replace them with a
	# || to make them parseable. This is done in a copy of the
	# script. The nice thing is that the parse tree contains only
	# references to the original script so if we replace the
	# offending operators with operators of the same length (#characters) and
	# arity the ranges in the parsing result will be ok for the
	# new operators despite parsing a copy ... Note that the parse
	# tree can be different as the replacement operators may or
	# will have a different priority than the original ones and
	# thus affect the grouping. But as we are not trying to give
	# optimization hints, just checking that the operators are ok
	# this difference does not matter to us.

	# -*- FUTURE -*- A future TIP may allow us to not only query
	# -*- FUTURE -*- and define math functions, but also binary
	# -*- FUTURE -*- operators as well. With that we could check
	# -*- FUTURE -*- that all operators we are looking for are
	# -*- FUTURE -*- supported, and if not declare the missing
	# -*- FUTURE -*- pieces just for recognition.

	lassign $range statrt size

	set head [string range $script 0       [expr {$start-1}]]
	set tail [string range $script [expr {$start+$size}] end]
	set expr [string range $script $start [expr {$start+$size-1}]]

	# Make the middle parseable ... (I have chosen the || operator
	# as replacement. & has special meaning to regsub too, where &&
	# is not palatable). The possible problem operators are the
	# new string comparison ops 'ne' and 'eq', now also 'in', 'ni', and '**'.

	regsub -all {([^a-z0-9_.])(?:ne|eq|in|ni)([^a-z0-9_.])} $expr {\1||\2} expr

	# ** is numerical op, may have digits before and after
	regsub -all {([^a-z_.])\*\*([^a-z_.])} $expr {\1||\2} expr

	if {[catch {parse expr $head$expr$tail $range} tree]} {
	    # Our fix of the problem failed. Give up.

	    # See also the analyzeScript... commands for similar code.
	    set errPos [lindex $::errorCode 2]
	    lassign $range s l
	    set errLen [expr {$l - ($errPos - $s)}]
	    set errMsg [lindex $::errorCode end]

	    if {[string match {*invalid bareword*} $errMsg]} {
		set after  [expr {$errPos - $s}]
		set before [expr {$after - 1}]
		logExtendedError \
		    [CorrectionsOf 0 $tokens \
			 get $index wstrinsert $before \$         replace $index save \
			 get $index wstrinsert $after {(SUBEXPR)} replace $index save \
			 get $index wstrinsert $after \} wstrinsert $before \{ replace $index save \
			] \
		    parse [list $errPos $errLen] $errMsg
	    } else {
		logError parse [list $errPos $errLen] $errMsg
	    }
	    incr exprNesting -1
	    npop
	    return [incr index]
	}

	#::log::log debug [dumpToken $tree]
	# The fix worked, go ahead with checking.
    }

    #puts ==============================
    #puts [dumpToken $tree]
    #puts ==============================

    checkSubExpr $word $tree _ ""

    #::log::log debug [dumpToken $tree]
    #puts X|$_

    incr exprNesting -1
    npop
    return [incr index]
}

# analyzer::checkSubExpr --

proc analyzer::checkSubExpr {wordfull word tv outerop} {
    upvar 1 $tv treesignature tokens tokens index index
    variable operators
    variable voperators

    # structure. word is of type 'subexpr'.

    # A subexpression can be a
    # (1) variable reference,
    # (2) nested bracketed command,
    # (3) plain text,
    # (4) or operator/function application.
    #
    # (Ad 1). One child, of type 'variable'.
    # (Ad 2). One child, of type 'command'.
    # (Ad 3). One child, of type 'text'.
    # (Ad 4). One or more children.
    #         The first child is of type 'operator',
    #         all others are of type 'subexpr', and
    #         are subexpressions themselves. The
    #         number of 'subexpr' children is the
    #         arity of the operator or funciton.

    set treesignature {}
    set arity [expr {[getTokenNumChildren $word]-1}]

    set oprange {}
    set lrange  {}
    set rrange  {}
    set sub 0

    foreach token [getTokenChildren $word] {
	set type [getTokenType $token]
	if {$type eq "operator"} {
	    # Todo: check for unkown operators and functions.
	    checkWord [list $token] 0

	    set bop [getTokenString $token]
	    set op  $bop/$arity

	    lappend treesignature $bop
	    set oprange [getTokenRange $token]

	    set done 0
	    foreach k [array names voperators $bop/*/*] {
		# Is a variadic operator. These are all functions.
		lassign [split $k /] _ mina maxa
		if {
		    ($arity < $mina) ||
		    (($maxa >=0 ) && ($arity > $maxa))
		} {
		    logError warnUndefFunc $oprange $op
		}
		set done 1
	    }

	    if {!$done && ![info exists operators($op)]} {
		# Error message depends on arity
		# 1 -> set of freely extensible math funcs.
		#      just warn
		# 0,2,3 -> builtin operators, error

		if {$arity == 1} {
		    logError warnUndefFunc $oprange $op
		} else {
		    logError badMathOp $oprange $op
		}
	    }

	    # Check that the operator is surrounded by whitespace.
	    CheckExprOpWhitespace $wordfull $word $op $oprange

	    # Check that we have parens at the boundaries between
	    # different ops.
	    CheckExprParens $wordfull $word $bop $arity $outerop

	} elseif {$type eq "subexpr"} {
	    if {!$sub} {
		set lrange [lindex $token 1]
		incr sub
	    } else {
		set rrange [lindex $token 1]
	    }
	    checkSubExpr $wordfull $token subsignature $bop
	    lappend treesignature $subsignature
	} elseif {$type eq "variable"} {
	    checkWord [list $token] 0
	    lappend treesignature v
	} elseif {$type eq "command"} {
	    checkWord [list $token] 0
	    lappend treesignature c
	} elseif {$type eq "text"} {
	    # There is nothing to recurse. We try to determine a type
	    # for the text, for use in the signature.
	    variable script
	    set literal [getString $script [getTokenRange $token]]
	    if {[string is boolean -strict $literal]} {
		set tsig bool
	    } elseif {[string is integer -strict $literal]} {
		set tsig int
	    } elseif {[string is double -strict $literal]} {
		set tsig double
	    } else {
		set tsig unknown
	    }
	    lappend treesignature t/$tsig
	} else {
	    lappend treesignature t/unknown
	}
    }

    # The 'treesignature' now contains the type signature of the
    # expression tree underneath this subexpr. It is a nested list
    # with the nesting representing the tree hierarchy. This signature
    # we can match against using glob and/or regexp.

    if {
	[string match {== * t/bool} $treesignature] ||
	[string match {!= * t/bool} $treesignature]
    } {
	set base [lindex $wordfull 1 0]
	lassign $oprange s _
	lassign $rrange  sx l

	set base [expr {$s - $base - 1}]
	set len  [expr {$sx+$l-$s}]

	logExtendedError \
	    [CorrectionsOf 1 $tokens \
		 get $index wstrreplace $base $len {} wtrimr replace $index save] \
	    warnStyleExprBoolEquality $oprange $bop
    } elseif {
	[string match {== t/bool *} $treesignature] ||
	[string match {!= t/bool *} $treesignature]
    } {
	set base [lindex $wordfull 1 0]
	lassign $lrange  s _
	lassign $oprange sx l

	set base [expr {$s - $base - 1}]
	set len  [expr {$sx+$l-$s}]

	logExtendedError \
	    [CorrectionsOf 1 $tokens \
		 get $index wstrreplace $base $len {} wtriml replace $index save] \
	    warnStyleExprBoolEquality $oprange $bop
    }

    #puts S|$treesignature
    return
}

proc analyzer::CheckExprOpWhitespace {wordfull word op oprange} {
    upvar 1 tokens tokens index index
    # Check that the operator is surrounded by whitespace. Ignore
    # logical negation. Furthermore ignore unary minus as well.
    # Bug 80460.

    # XXX AK: The set of operators and functions to ignore here should
    # XXX be specified as part of pcx::math(v)op definitions. Requires
    # XXX an extended API.

    if {$op eq "!/1"} return
    if {$op eq "-/1"} return

    lassign $oprange s l
    set bl $s
    incr s -1
    incr l

    set al [expr {$s+$l}]

    variable script
    set before [getChar $script [list $s 1]]
    set after  [getChar $script [list $al 1]]

    if {$after eq "("} {
	# The operator is a function. For the actual after
	# we have to skip behind the closing parens. This
	# we get from the main word.

	lassign [getTokenRange $word] s l
	set al [expr {$s+$l}]
	set after [getChar $script [list $al 1]]
    }

    set bound $before$after
    #puts |$bound|$s\ $l|[getString $script $oprange]
    if {[regexp {^[ \t]+$} $bound]} return

    set base [lindex $wordfull 1 0]
    set al [expr {$al - $base - 1}]
    set bl [expr {$bl - $base - 1}]

    logExtendedError \
	[CorrectionsOf 1 $tokens \
	     get $index wstrinsert $al { } wstrinsert $bl { } replace $index \
	     save] \
	warnStyleExprOperatorWhitespace $oprange
    return
}

proc analyzer::CheckExprParens {wordfull word op arity outerop} {
    variable script
    upvar 1 tokens tokens index index
    #puts C|$outerop|$op|[getString $script [getTokenRange $word]]|

    # No checks required for the toplevel operators.
    if {$outerop eq ""}  return
    # Ops at the same level of priority need no checks, nor parens.
    if {$op eq $outerop} return

    # Arity 1 minus is negation and doesn't need parens.
    if {($op eq "-") && ($arity == 1)} return

    set wrange [getTokenRange $word]
    # Function applications need no parentheses around them.
    if {[string match {*[a-z](*)} [getString $script $wrange]]} return

    # Split script into before/self/after pieces
    lassign $wrange s l
    set  e [expr {$s + $l - 1}]
    incr e
    set before [getString $script [list 0 $s]]
    set after  [getString $script [list $e [expr {[string length $script] - $e}]]]

    set bl $s
    set al $e

    #puts _|________________________________________
    #puts B|[string range $before end-5 end]|
    #puts E|[getString $script $wrange]|
    #puts A|[string range $after 0 5]|

    # Look for parens around self, only whitespace is allowed to intervene
    if {
	[regexp {\([ \t]*$} $before] &&
	[regexp {^[ \t]*\)} $after]
    } return

    set base [lindex $wordfull 1 0]
    set al [expr {$al - $base - 1}]
    set bl [expr {$bl - $base - 1}]

    # Not found
    logExtendedError \
	[CorrectionsOf 1 $tokens \
	     get $index wstrinsert $al ) wstrinsert $bl ( replace $index \
	     save] \
	warnStyleExprOperatorParens $wrange
    return
}

# analyzer::checkCommand --
#
#	This is the generic command wrapper.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkCommand {tokens index} {
    set argc [llength $tokens]
    while {$index < $argc} {
	set index [checkWord $tokens $index]
    }
    return $argc
}

proc analyzer::checkCommandAndStyles {tokens index} {
    # run accumulated defered xref definitions
    def'run
    style::use 1
    set index [checkCommand $tokens $index]
    style::use 0
    return $index
}

# analyzer::checkSimpleArgs --
#
#	This function checks any command that consists of a set of
#	fixed arguments followed by a set of optional arguments that
#	must appear in a fixed sequence.
#
# Arguments:
#	min		The minimum number of arguments.
#	max		The maximum number of arguments.  If -1, then the
#			last argument may be repeated.
#	argList		A list of scripts that should be called for
#			the corresponding argument.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkSimpleArgs {min max argList tokens index} {

    # Verify that there are the correct number of fixed arguments and
    # not too many optional arguments.

    set argc [llength $tokens]
    if {($argc < ($min + $index)) \
	    || (($max != -1) && ($argc > ($max + $index)))} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }

    # Starting with the first argument after the command name, invoke
    # the type checker associated with each argument.  If there are more
    # arguments than type commands, use the last command for all of the
    # remaining arguments.

    set i $index ; # TODO: Use lindex to step through argList, no need to shrink the list ...
    while {$i < $argc} {
	set cmd [lindex $argList 0]
	set i [{*}$cmd $tokens $i]
	if {[llength $argList] > 1} {
	    set argList [lrange $argList 1 end]
	}
    }
    return $argc
}

proc analyzer::checkSimpleArgsModNk {min max n k argList tokens index} {
    # Verify that there are the correct number of fixed arguments and
    # not too many optional arguments.

    set argc [llength $tokens]
    if {($argc < ($min + $index)) \
	    || (($max != -1) && ($argc > ($max + $index)))} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }

    if {(($argc-$index) % $n) != $k} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }

    # Starting with the first argument after the command name, invoke
    # the type checker associated with each argument.  If there are more
    # arguments than type commands, use the last command for all of the
    # remaining arguments.

    set i $index ; # TODO: See checkSimpleArgs
    while {$i < $argc} {
	set cmd [lindex $argList 0]
	set i [{*}$cmd $tokens $i]
	if {[llength $argList] > 1} {
	    set argList [lrange $argList 1 end]
	}
    }
    return $argc
}

proc analyzer::checkAtEnd {tokens index} {
    return [checkSimpleArgs 0 0 {} $tokens $index]
}

# analyzer::checkNextArgs --
#
#	This function checks any command that consists of a set of
#	fixed arguments followed by a set of optional arguments that
#	must appear in a fixed sequence.
#
#	It is simplar to checkSimpleArgs N -1, except that it doesn't
#	repeat the last argument.
#
# Arguments:
#	n		The number of arguments we have to have for checking.
#	argList		A list of scripts that should be called for
#			the corresponding argument.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkNextArgs {min argList tokens index} {

    # Verify that there are the correct number of fixed arguments and
    # not too many optional arguments.

    set argc [llength $tokens]
    if {($argc < ($min + $index))} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }

    # Starting with the first argument after the command name, invoke
    # the type checker associated with each argument.

    set i $index
    foreach cmd $argList {
	set i [{*}$cmd $tokens $i]
    }
    return $argc
}

# analyzer::checkSequence --
#
#	This function checks (part of) any command that consists of a set
#	of fixed arguments that must appear in a fixed sequence.
#
#	This is mainly a grouping operation.
#
# Arguments:
#	chains		A list of scripts that should be called for
#			the corresponding argument.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkSequence {chains tokens index} {
    # Starting with the first argument after the command name, invoke
    # the type checker associated with each argument.

    set i $index
    foreach cmd $chains {
	set i [{*}$cmd $tokens $i]
    }
    return $i
}

# analyzer::checkTailArgs --
#
#	This command checks, in reverse order, the arguments to a command.
#	This checker is useful for commands where the last N elements are
#	known, but the middle arguments are undetermined.

#
# Arguments:
#	headCmd		Checker to apply to middle arguments.
#	tailCmd		Checker to apply to tail arguments.
#	backup		Number of tail arguments.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkTailArgs {headCmd tailCmd backup tokens index} {
    # Calculate the index where the tail command checker should
    # begin checking command arguments.

    set tailIdx [expr {[llength $tokens] - $backup}]

    # Evaluate the head command checker and save the index where it
    # stopped checking.  Many checkers will not check a word that is
    # non-literal.  So if the stop index is less then the tail index
    # call "checkWord" on each word up to the tail index.

    set stopIdx $index
    while {$stopIdx < $tailIdx} {
	set nextIdx [{*}$headCmd $tokens $stopIdx]
	if {$nextIdx == $stopIdx} {
	    if {[isLiteral [lindex $tokens $nextIdx]]} {
		break
	    } else {
		set nextIdx [checkWord $tokens $nextIdx]
	    }
	}
	set stopIdx $nextIdx
    }

    # Evaluate the tail checker.

    set stopIdx [{*}$tailCmd $tokens $stopIdx]
    return $stopIdx
}

# analyzer::checkTailArgsFirst --
#
#	This command checks the arguments to a command in 2 parts:
#	First it checks the last "numTailArgs".  Then it checks the
#	args from index to the first tail arg.
#
# Arguments:
#	headCmd		Checker to apply to head arguments.
#	tailCmd		Checker to apply to tail arguments.
#	numTailArgs	Number of tail arguments.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkTailArgsFirst {headCmd tailCmd numTailArgs tokens index} {
    # Calculate the index where the tail command checker should
    # begin checking command arguments & check the tail first.

    set tailIdx [expr {[llength $tokens] - $numTailArgs}]
    set stopIdx [{*}$tailCmd $tokens $tailIdx]

    # Create a token list where the last numTailArgs tokens are removed.
    # Evaluate the head command checker on this reduced token list.

    set reducedTokens [lrange $tokens 0 [expr {$tailIdx - 1}]]
    {*}$headCmd $reducedTokens $index

    return $stopIdx
}

# analyzer::checkSwitchArg --
#
#	This command checks switch arguments similar to the checkSimpleArgs
#	checker.  It checks to see if the minimum number of words can be
#	found in the current command, and then checks "num" args.  This
#	checker is designed to be used inside custom checkers to assist
#	checking switch arguments (e.g., the "expect" command.)
#
# Arguments:
#	switch		The name of the switch being checked.  Used for
#			logging errors.
#	min		The minimum number of arguments.
#	num		The number of words to check.
#	cmds		A list of scripts that should be called for
#			the corresponding argument.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkSwitchArg {switch min num cmds tokens index} {
    # Verify that there are the correct number of fixed arguments and
    # not too many optional arguments.

    set argc [llength $tokens]
    if {$argc < ($min + $index)} {
	set word [lindex $tokens [expr {$argc - 1}]]
	logError noSwitchArg [getTokenRange $word] $switch
    }

    set i   $index
    set end [expr {$i + $num}]

    while {($i < $argc) && ($i < $end)} {
	set cmd [lindex $cmds 0]
	set i [{*}$cmd $tokens $i]
	if {[llength $cmds] > 1} {
	    set cmds [lrange $cmds 1 end]
	}
    }
    return $i
}

# analyzer::checkOption --
#
#	Check a command to see if it matches the allowed set of options
#	and dispatch on the given option table.  Allows abbreviations.
#
# Arguments:
#	optionTable	The list of option/action pairs.
#	default		The default action to take if no options match, may
#			be null to indicate that an error should be generated.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkOption {optionTable default tokens index} {
    if {($index == [llength $tokens]) && ($default eq "")} {
	logError numArgs {}
	return [incr index]
    }

    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	## The first word = option/subcommand is no literal, but if a
	## default was specified we can still check try to check it.

	if {[llength $default]} {
	    return [{*}$default $tokens $index]
	}
	return [checkCommand $tokens $index]
    }

    if {![matchKeyword $optionTable $value 0 0 script __ignore]} {
	if {[llength $default]} {
	    return [{*}$default $tokens $index]
	}

	# XXX AK FUTURE/TODO: Use the list to find the keyword(s)
	# nearest to the bad value (some sort of word-distance metric)
	# and place them at the beginning of the list of corrections.

	# Construct and collect the correction commands for all
	# keywords. AK: Could be done as (struct::list fold) instead
	# of a separate loop. See also 'BadSwitch'.

	set keywords {}
	foreach keyword $optionTable {
	    lappend keywords [lindex $keyword 0]
	}
	set keywords [lsort -dict $keywords]
	set xcmd {}
	foreach keyword $keywords {
	    lappend xcmd lset $index $keyword save
	}

	# Now log the error and generate the suggestions for
	# correction.
	logExtendedError \
	    [CorrectionsOf 0 $tokens {*}$xcmd] \
	    badOption [getTokenRange $word] $keywords $value
	set script checkCommand
    }
    if {![llength $script]} {
	Puts "INTERNAL ERROR: bad script for '$value' in table: $optionTable"
    }
    incr index
    return [{*}$script $tokens $index]
}

# analyzer::checkWidgetOptions --
#
#	Check widget configuration options.  The commonOptions are
#	passed as a list of switches which will be looked up in the
#	standardWidgetOptions array.  These standard options will be
#	added to the widget specific options for checking purposes.
#
# Arguments:
#	allowSingle	If 1, this is a "configure" context and a single
#			option name without a value is allowed.
#	commonOptions	A list of standard widget options.
#	options		A list of additional option/action pairs.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkWidgetOptions {
    allowSingle commonOpts widgetOpts tokens index
} {
    variable standardWidgetOpts

    foreach option $commonOpts {
	lappend widgetOpts [list $option $standardWidgetOpts($option)]
    }
    return [checkConfigure $allowSingle $widgetOpts $tokens $index]
}

# analyzer::checkKeyword --
#
#	Check a word against a list of possible values, allowing for
#	unique abbreviations.
#
# Arguments:
#	exact		If 0, abbreviations are allowed.
#	keywords	The list of allowed keywords.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkKeyword {exact keywords tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }

    if {![matchKeyword $keywords $value $exact 0 script __ignore]} {
	logError badKey [getTokenRange $word] $keywords $value
    }
    return [incr index]
}

# analyzer::checkKeywordNC --
#
#	Check a word against a list of possible values, allowing for
#	unique abbreviations. The comparison is done case-independent
#
# Arguments:
#	exact		If 0, abbreviations are allowed.
#	keywords	The list of allowed keywords.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkKeywordNC {exact keywords tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }

    if {![matchKeyword $keywords $value $exact 1 script __ignore]} {
	logError badKey [getTokenRange $word] $keywords $value
    }
    return [incr index]
}

# analyzer::checkSwitches --
#
#	Check the argument list for optional switches, possibly followed
#	by additional arguments.  Switch names may not be abbreviated.
#
# Arguments:
#	exact		Boolean value.  If true, then switches have to match
#			exactly.
#	switches	A list of switch/action pairs.  The action may be
#			omitted if the switch does not take an argument.
#			If "--" is included, it acts as a terminator.
#	chainCmd	The command to use to check the remainder of the
#			command line arguments.  May be null for trailing
#			switches.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
#
# Results:
#	Returns the index of the next token to be checked.

namespace eval analyzer {
    variable lastSwitch {}
}

proc analyzer::checkSwitches {exact switches chainCmd tokens index} {
    variable lastSwitch {}
    set argc [llength $tokens]
    while {$index < $argc} {
	set word [lindex $tokens $index]
	if {![getLiteral $word value]} {
	    break
	}
	if {![string match "-*" $value]} {
	    break
	}

	set script ""
	if {![matchKeyword $switches $value $exact 0 script value]} {
	    BadSwitch $switches $word $value
	    incr index
	} else {
	    incr index
	    if {$value eq "--"} {
		break
	    }
	    set lastSwitch $value
	    if {$script ne ""} {
		if {$index >= $argc} {
		    logError noSwitchArg [getTokenRange $word] $value
		    return $argc
		}

		set index [{*}$script $tokens $index]
	    }
	}
    }

    if {[llength $chainCmd]} {
	return [{*}$chainCmd $tokens $index]
    }
    if {$index != $argc} {
 	logError numArgs {}
    }
    return $argc
}

# analyzer::checkSwitchesArg --
#
#	Check the argument list for optional switches, possibly followed
#	by additional arguments.  Switch names may not be abbreviated.
#
# Arguments:
#	exact		Boolean value.  If true, then switches have to match
#			exactly.
#	switches	A list of switch/action pairs.  The action may be
#			omitted if the switch does not take an argument.
#
#                       Having a script on the other hand does not
#                       mean that the switch takes an argument. This
#                       is signaled by using the suffix ".arg" to the
#                       switch.
#
#			If "--" is included, it acts as a terminator.
#
#	chainCmd	The command to use to check the remainder of the
#			command line arguments.  May be null for trailing
#			switches.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkSwitchesArg {exact switches chainCmd tokens index} {
    set argc [llength $tokens]

    # We construct a second list of 'switches' as it is expected by
    # "matchKeyWord" as that command does not kow about the ".arg"
    # suffix for switches. We also use the occasion to generate an
    # internal array which tells us which switches take an argument.

    set switches_match [list]
    array set takearg {}

    foreach item $switches {
	if {[llength $item] == 1} {
	    if {[regexp {^(.*)\.arg$} $item -> stem]} {
		lappend switches_match $stem
		set takearg($stem) 1
	    } else {
		lappend switches_match $item
		set takearg($item) 0
	    }
	} elseif {[llength $item] == 2} {
	    lassign $item item action
	    if {[regexp {^(.*)\.arg$} $item -> stem]} {
		lappend switches_match [list $stem $action]
		set takearg($stem) 1
	    } else {
		lappend switches_match [list $item $action]
		set takearg($item) 0
	    }
	} else {
	    return -code error "invalid item of switches list: $item"
	}
    }

    while {$index < $argc} {
	set word [lindex $tokens $index]
	if {![getLiteral $word value]} {
	    break
	}
	if {![string match "-*" $value]} {
	    break
	}

	set script ""
	if {![matchKeyword $switches_match $value $exact 0 script value]} {
	    BadSwitch $switches $word $value
	    incr index
	} else {
	    incr index
	    if {$value eq "--"} {
		break
	    }

	    # Acceptable combinations
	    #
	    # takearg + script    => check that arg is present, execute script
	    # takearg, no script  => check that arg is present
	    # no arg  + script    =>                            execute script
	    # no arg, no script   => nothing to do

	    if {$takearg($value)} {
		if {$index >= $argc} {
		    logError noSwitchArg [getTokenRange $word] $value
		    return $argc
		}
	    }
	    if {$script ne ""} {
		set index [{*}$script $tokens $index]
	    }
	}
    }
    if {[llength $chainCmd]} {
	return [{*}$chainCmd $tokens $index]
    }
    if {$index != $argc} {
 	logError numArgs {}
    }
    return $argc
}

# analyzer::checkRestrictedSwitches --
#
#	Check the argument list for optional switches, possibly followed
#	by additional arguments.  Switch names may or may not be abbreviated.
#       Unrecognized switches stop the processing, but are __not__ logged
#       as error. This is for commands which recognize some switches
#       and everything else as a normal argument, even if it could
#       have been a switch (8.4: 'unset -foo' is legal!)
#
# Arguments:
#	exact		Boolean value.  If true, then switches have to match
#			exactly.
#	switches	A list of switch/action pairs.  The action may be
#			omitted if the switch does not take an argument.
#			If "--" is included, it acts as a terminator.
#	chainCmd	The command to use to check the remainder of the
#			command line arguments.  May be null for trailing
#			switches.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkRestrictedSwitches {exact switches chainCmd tokens index} {
    set argc [llength $tokens]
    while {$index < $argc} {
	set word [lindex $tokens $index]
	if {![getLiteral $word value]} {
	    break
	}
	if {![string match "-*" $value]} {
	    break
	}

	set script ""
	if {![matchKeyword $switches $value $exact 0 script __ignore]} {
	    # NOT a bad switch, but the first normal argument.
	    break
	} else {
	    incr index
	    if {$value eq "--"} {
		break
	    }
	    if {$script ne ""} {
		if {$index >= $argc} {
		    logError noSwitchArg [getTokenRange $word] $value
		    return $argc
		}

		set index [{*}$script $tokens $index]
	    }
	}
    }
    if {[llength $chainCmd]} {
	return [{*}$chainCmd $tokens $index]
    }
    if {$index != $argc} {
 	logError numArgs {}
    }
    return $argc
}

# analyzer::checkHeadSwitches --
#
#	Modified version of checkSwitches.  It does not require the chain
#	command to exist, it will not log an error if there are arguments
#	remaining after the switches are done being checked, and it will
#	stop checking on a designated index.
#
# Arguments:
#	exact		Boolean value.  If true, then switches have to match
#			exactly.
#	backup		The number of words to backup from the end of the
#			token list.  This will be used to calculate the index
#			to stop checking for switches.
#	switches	A list of switch/action pairs.  The action may be
#			omitted if the switch does not take an argument.
#			If "--" is included, it acts as a terminator.
#	chainCmd	The command to use to check the remainder of the
#			command line arguments.  May be null for trailing
#			switches.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkHeadSwitches {exact backup switches chainCmd tokens index} {
    # Calculate the index where the tail command checker should
    # begin checking command arguments.

    set argc    [llength $tokens]
    set stopIdx [expr {$argc - $backup}]

    while {$index < $stopIdx} {
	set word [lindex $tokens $index]
	if {![getLiteral $word value]} {
	    break
	}
	if {![string match "-*" $value]} {
	    break
	}

	set script ""
	if {![matchKeyword $switches $value $exact 0 script __ignore]} {
	    BadSwitch $switches $word $value
	    incr index
	} else {
	    incr index
	    if {$value eq "--"} {
		break
	    }
	    if {$script ne ""} {
		if {$index >= $argc} {
		    logError noSwitchArg [getTokenRange $word] $value
		    return $argc
		}

		set index [{*}$script $tokens $index]
	    }
	}
    }
    if {[llength $chainCmd]} {
	return [{*}$chainCmd $tokens $index]
    }
    return $index
}

# analyzer::checkConfigure --
#
#	Check a configuration option list where there may be a single
#	argument that specifies an option to retrieve or a list of
#	option/value pairs to be set.  Option names may be abbreviated.
#
# Arguments:
#	allowSingle	If 1, a single argument is ok, otherwise it's an error.
#	options		A list of switch/action pairs.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkConfigure {allowSingle options tokens index} {
    set argc [llength $tokens]
    set start $index

    while {$index < $argc} {
	set word [lindex $tokens $index]
	set script ""
	if {[getLiteral $word value]} {
	    if {![matchKeyword $options $value 0 0 script __ignore]} {
		BadSwitch $options $word $value
	    }
	}

	# Check to see if there is a value for this option.

	if {$index == ($argc - 1)} {
	    # If this is the first and last option, we're done.

	    if {$allowSingle && ($index == $start)} {
		return $argc
	    }
	    logError noSwitchArg [getTokenRange $word] $value
	    break
	}
	if {$script eq ""} {
	    set script checkWord
	}
	incr index
	set index [{*}$script $tokens $index]
    }
    return $argc
}

proc analyzer::checkExtensibleConfigure {allowSingle options tokens index} {
    set argc [llength $tokens]
    set start $index

    while {$index < $argc} {
	set word [lindex $tokens $index]
	set script ""
	if {[getLiteral $word value]} {
	    if {![matchKeyword $options $value 0 0 script __ignore]} {
		# XX AK later - BadSwitch $options $word $value
		logError maybeBadSwitch [getTokenRange $word] $value
	    }
	}

	# Check to see if there is a value for this option.

	if {$index == ($argc - 1)} {
	    # If this is the first and last option, we're done.

	    if {$allowSingle && ($index == $start)} {
		return $argc
	    }
	    logError noSwitchArg [getTokenRange $word] $value
	    break
	}
	if {$script eq ""} {
	    set script checkWord
	}
	incr index
	set index [{*}$script $tokens $index]
    }
    return $argc
}

# analyzer::checkFloatConfigure --
#
#	Similar to checkConfigure except its keywords are not
#	required to have a script associated to the next word.
#
# Arguments:
#	options		A list of switch/action pairs.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkFloatConfigure {exact options default tokens index} {
    set argc [llength $tokens]
    set start $index

    set script {}
    while {$index < $argc} {
	set word [lindex $tokens $index]
	if {![getLiteral $word value] \
		|| (![matchKeyword $options $value $exact 0 script __ignore])} {
	    break
	}
	incr index
	if {$script ne ""} {
	    set index [{*}$script $tokens $index]
	}
    }

    if {$index < $argc} {
	if {$default ne ""} {
	    set index [{*}$default $tokens $index]
	}
	if {$index < $argc} {
	    set word  [lindex $tokens $index]
	    set range [getTokenRange $word]
	    if {$default ne ""} {
		logError numArgs $range
	    } else {
		BadSwitch $options $word $value
	    }
	    set index [checkCommand $tokens $index]
	}
    }
    return $index
}


# analyzer::matchKeyword --
#
#	Find the unique match for a string in a keyword table and return
#	the associated value.
#
# Arguments:
#	table	A list of keyword/value pairs.
#	str	The string to match.
#	exact	If 1, only exact matches are allowed, otherwise unique
#		abbreviations are considered valid matches.
#       nocase  If 1 comparison is case-independent
#	varName	The name of a variable that will hold the resulting value.
#
# Results:
#	Returns 1 on a successful match, else 0.

proc analyzer::matchKeyword {table str exact nocase varName keyName} {
    upvar 1 $varName result
    upvar 1 $keyName reskey

    if {$str eq ""} {
	foreach pair $table {
	    lassign $pair key tmp
	    if {$key eq ""} {
		set result $tmp
		set reskey $key
		return 1
	    }
	}
	return 0
    }

    if {![string is boolean -strict $nocase]} {
	switch -exact -- $nocase {
	    nocase {set nocase 1}
	    case   {set nocase 0}
	    {}     {set nocase 0}
	}
    }
    if {![string is boolean -strict $exact]} {
	switch -exact -- $exact {
	    exact  {set exact 1}
	    abbrev {set exact 0}
	}
    }

    if {$nocase} {set str [string tolower $str]}
    if {$exact} {
	set end end
    } else {
	set end [expr {[string length $str] - 1}]
    }
    set found ""
    foreach pair $table {
	lassign $pair key tmp
	if {$nocase} {set key [string tolower $key]}
	if {$str eq [string range $key 0 $end]} {
	    # If the string matches exactly, return immediately.

	    if {$exact || ($end == ([string length $key]-1))} {
		set result $tmp
		set reskey $key
		return 1
	    } else {
		lappend found $tmp
		lappend found $key
	    }
	}
    }
    if {[llength $found] == 2} {
	set result [lindex $found 0]
	set reskey [lindex $found 1]
	return 1
    } else {
	return 0
    }
}

# analyzer::checkNumArgs --
#
#	This function checks the command based on the number
#	of args in the command.  If the number of args in the
#	command is not in the command list, then a numArgs
#	error is logged.
#
# Arguments:
#	chainList	A list of tuples.  The first element is
#			the number of args required in order to
#			eval the command.  The second element is
#			the cmd to eval.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkNumArgs {chainList tokens index} {
    set argc [expr {[llength $tokens] - $index}]
    set prevNum -1

    # LogError is called if argc does not match any of
    # the numArgs in the nested lists or does not have
    # the minimum required num args for infinite num args.
    # For example:
    #   - "foo" can take 1 3 or many args.
    #   - The list looks like {{1 cmd} {3 cmd} {-1 cmd}}
    #   - LogError is only called when argc == 2 or argc == 0.
    #   - A num spec can be a list of 4 giving min, max, mod n == k data.
    foreach numCmds $chainList {
	lassign $numCmds nextNum cmd
	if {[llength $nextNum] == 4} {
	    lassign $nextNum min max n k
	    if {($min < $argc) && (($max < 0) || ($argc < $max)) && (([llength $literal] % $n) == $k)} {
		return [{*}$cmd $tokens $index]
	    }
	    set prevNum -1 ; # reset gap detector
	    continue
	}
	if {($nextNum == $argc) || ($nextNum == -1)} {
	    return [{*}$cmd $tokens $index]
	} elseif {($prevNum < $argc) && ($argc < $nextNum)} {
	    break
	}
	set prevNum $nextNum
    }
    logError numArgs {}
    return [checkCommand $tokens $index]
}

# analyzer::checkListValues --
#
#	This function checks the elements of a list in the manner as checkSimpleArgs.
#
# Arguments:
#	min		The minimum number of list elements
#	max		The maximum number of list elements.  If -1, then the
#			last argument may be repeated.
#	argList		A list of scripts that should be called for
#			the corresponding element.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkListValues {min max argList tokens index} {
    set word [lindex $tokens $index]

    # First perform generic list checks

    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }
    if {[catch {parse list $literal {}} ranges]} {
	logError badList \
		[list [getLiteralPos $word [lindex $::errorCode 2]] 1] $ranges
	return [incr index]
    }


    # Construct an artificial token list for the elements of the list.
    # Note that this algorithm is incorrect if the list elements contain
    # backslash substitutions because it does not properly unquote things.

    set listTokens {}
    foreach range $ranges {
	set origRange [getLiteralRange $word $range]
	set quote [getChar $literal $range]
	if {$quote eq "\{" || $quote eq "\""} {
	    lassign $range s l
	    set textRange [getLiteralRange $word \
		    [list [expr {$s+1}] [expr {$l - 2}]]]
	} else {
	    set textRange [getLiteralRange $word $range]
	}

	# We are constructing an artificial token list, in order for the
	# checkVarRef checker to flag warnings, we need to check for a
	# preceeding dollar sign, and give that token a "variable" type
	# instead of the generic "text" type.

	set type "text"
	if {[string index $literal [lindex $range 0]] eq "\$"} {
	    set type "variable"

	    # A variable token, even if artifical has to have at least
	    # one child, to refer to the variable name. An example
	    # which may crash if such a child is not put into the
	    # created token list is a 'bindtags' with a var-ref in the
	    # list of tags: 'bindtags .w {$f foo bar}' (Erroneous use
	    # of a script instead of a tag list). Bugzilla 45707.

	    lassign $textRange s l
	    incr s ; incr l -1
	    set vnRange [list $s $l]

	    lappend listTokens [list word $origRange [list \
		  [list $type $textRange [list [list text $vnRange {}]]]]]

	} else {
	    lappend listTokens [list word $origRange [list \
			  [list $type $textRange {}]]]
	}
    }

    # Verify that there are the correct number of fixed list elts and
    # not too many optional list elts.

    set eltc [llength $listTokens]
    if {$eltc < $min} {
	logError numListElts [getTokenRange $word]
    } elseif {($max != -1) && ($eltc > $max)} {
	logError numListElts [getTokenRange $word]
	set eltc $max
    }

    # Starting with the first element after the command name, invoke
    # the type checker associated with each element.  If there are more
    # elements than type commands, use the last command for all of the
    # remaining elements.

    style::save
    style::clear
    set i 0
    while {$i < $eltc} {
	set cmd [lindex $argList 0]
	set i [{*}$cmd $listTokens $i]
	if {[llength $argList] > 1} {
	    set argList [lrange $argList 1 end]
	}
    }

    # Explicitly run the style checks on the artificial list. We can't
    # defer to the regular checking, as at that time the inner
    # structure of the list is not known any longer.
    style::use 1
    set i 0
    foreach w $listTokens {
	checkWordStyle $w $i
	incr i
    }
    style::use 0
    style::restore

    return [incr index]
}

proc analyzer::checkListValuesModNk {min max n k argList tokens index} {
    set word [lindex $tokens $index]

    # First perform generic list checks

    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }
    if {[catch {parse list $literal {}} ranges]} {
	logError badList \
		[list [getLiteralPos $word [lindex $::errorCode 2]] 1] $ranges
	return [incr index]
    }


    # Construct an artificial token list for the elements of the list.
    # Note that this algorithm is incorrect if the list elements contain
    # backslash substitutions because it does not properly unquote things.

    set listTokens {}
    foreach range $ranges {
	set origRange [getLiteralRange $word $range]
	set quote [getChar $literal $range]
	if {$quote eq "\{" || $quote eq "\""} {
	    lassign $range s l
	    set textRange [getLiteralRange $word \
		    [list [expr {$s+1}] [expr {$l - 2}]]]
	} else {
	    set textRange [getLiteralRange $word $range]
	}

	# We are constructing an artificial token list, in order for the
	# checkVarRef checker to flag warnings, we need to check for a
	# preceeding dollar sign, and give that token a "variable" type
	# instead of the generic "text" type.

	set type "text"
	if {[string index $literal [lindex $range 0]] eq "\$"} {
	    set type "variable"

	    # A variable token, even if artifical has to have at least
	    # one child, to refer to the variable name. An example
	    # which may crash if such a child is not put into the
	    # created token list is a 'bindtags' with a var-ref in the
	    # list of tags: 'bindtags .w {$f foo bar}' (Erroneous use
	    # of a script instead of a tag list). Bugzilla 45707.

	    lassign $textRange s l
	    incr s ; incr l -1
	    set vnRange [list $s $l]

	    lappend listTokens [list word $origRange [list \
		  [list $type $textRange [list [list text $vnRange {}]]]]]

	} else {
	    lappend listTokens [list word $origRange [list \
			  [list $type $textRange {}]]]
	}
    }

    # Verify that there are the correct number of fixed list elts and
    # not too many optional list elts.

    set eltc [llength $listTokens]
    if {$eltc < $min} {
	logError numListElts [getTokenRange $word]
    } elseif {($max != -1) && ($eltc > $max)} {
	logError numListElts [getTokenRange $word]
	set eltc $max
    }

    if {([llength $literal] % $n) != $k} {
	logError badListLength [getTokenRange $word] $n $k
    }

    # Starting with the first element after the command name, invoke
    # the type checker associated with each element.  If there are more
    # elements than type commands, use the last command for all of the
    # remaining elements.

    style::save
    style::clear
    set i 0
    while {$i < $eltc} {
	set cmd [lindex $argList 0]
	set i [{*}$cmd $listTokens $i]
	if {[llength $argList] > 1} {
	    set argList [lrange $argList 1 end]
	}
    }

    # Explicitly run the style checks on the artificial list. We can't
    # defer to the regular checking, as at that time the inner
    # structure of the list is not known any longer.
    style::use 1
    set i 0
    foreach w $listTokens {
	checkWordStyle $w $i
	incr i
    }
    style::use 0
    style::restore

    return [incr index]
}

# analyzer::checkDictValues --
#
#	This function checks the elements of a list in the manner as checkSimpleArgs.
#       It assumes that the list consists of keys and values as per [array set].
#
# Arguments:
#       min             min number of elements, even integer (0,2,...)
#       keycmd          Script to call for checking keys
#       valcmd          Script to call for checking values
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkDictValues {min keycmd valcmd tokens index} {
    set word [lindex $tokens $index]

    # First perform generic list checks

    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }
    if {[catch {parse list $literal {}} ranges]} {
	logError badList \
		[list [getLiteralPos $word [lindex $::errorCode 2]] 1] $ranges
	return [incr index]
    }

    # Construct an artificial token list for the elements of the list.
    # Note that this algorithm is incorrect if the list elements contain
    # backslash substitutions because it does not properly unquote things.

    set listTokens {}
    foreach range $ranges {
	set origRange [getLiteralRange $word $range]
	set quote [getChar $literal $range]
	if {$quote eq "\{" || $quote eq "\""} {
	    lassign $range s l
	    set textRange [getLiteralRange $word \
		    [list [expr {$s+1}] [expr {$l - 2}]]]
	} else {
	    set textRange [getLiteralRange $word $range]
	}

	# We are constructing an artificial token list, in order for the
	# checkVarRef checker to flag warnings, we need to check for a
	# preceeding dollar sign, and give that token a "variable" type
	# instead of the generic "text" type.

	set type "text"
	if {[string index $literal [lindex $range 0]] eq "\$"} {
	    set type "variable"
	}
	lappend listTokens [list word $origRange [list \
		[list $type $textRange {}]]]
    }

    # Verify that there are the correct number of list elts (>= min, even)
    set eltc [llength $listTokens]

    if {$min % 2 == 1} {incr min}
    if {$eltc < $min} {
	logError numListElts [getTokenRange $word]
    } elseif {$eltc % 2 == 1} {
	logError numListElts [getTokenRange $word]
    }

    # Starting with the first element after the command name, invoke
    # the type checker associated with each element (key or value).

    style::save
    style::clear
    set i 0
    while {$i < $eltc} {
	set cmd [expr {($i%2==0) ? "$keycmd" : "$valcmd"}]
	set i [{*}$cmd $listTokens $i]
    }

    # Explicitly run the style checks on the artificial list. We can't
    # defer to the regular checking, as at that time the inner
    # structure of the list is not known any longer.
    style::use 1
    set i 0
    foreach w $listTokens {
	checkWordStyle $w $i
	incr i
    }
    style::use 0
    style::restore

    return [incr index]
}

# analyzer::checkLevel --
#
#	This function attempts to determine if the next
#	word is a valid level.  If it is then it increments
#	the index and calls the chainCmd.  Otherwise it calls
#	the chainCmd without updating the index.
#
# Arguments:
#	chainCmd	The command to use to check the remainder of the
#			command line arguments.  This can not be null.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkLevel {chainCmd tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	if {[string match "#*" $literal]} {
	    incr index
	    set level [string range $literal 1 end]
	    if {[catch {incr level}]} {
		logError badLevel [getTokenRange $word] $literal
	    }
	} elseif {![catch {incr literal}]} {
	    incr index
	}
    } elseif {[string match "#*" $literal]} {
	incr index
    }
    return [{*}$chainCmd $tokens $index]
}

proc analyzer::checkIndexAt {idx error chainCmd tokens index} {
    if {$index == $idx} {
	logError $error [getTokenRange [lindex $tokens $index]]
    }

    return [{*}$chainCmd $tokens $index]
}

proc analyzer::checkIndexAtAndFix {idx error chainCmd newlist tokens index} {
    if {$index == $idx} {
	set xcmd {}
	foreach new $newlist {
	    lappend xcmd insert $idx $new save
	}
	logExtendedError \
	    [CorrectionsOf 0 $tokens {*}$xcmd] \
	    $error [getTokenRange [lindex $tokens $index]]
    }

    return [{*}$chainCmd $tokens $index]
}

# analyzer::checkArgsOrList

# Assumes that the remainder of the tokens falls into one of the
# following three cases:
#
# 0.  one argument, which is not a list.
# i.  one argument, which is a list.
# ii. multiple arguments.
#
# In case (i) chain is called for each item of the list.
# In cases (0) and (ii) chain is called for each remaining argument.

proc analyzer::checkArgsOrList {chain tokens index} {

    set end  [llength $tokens]
    set argc [expr {$end - $index}]

    if {$chain eq {}} {
	set chain checkWord
    }
    if {$argc == 1} {
	set word [lindex $tokens $index]
	if {[getLiteral $word literal]} {
	    # case (i)
	    if {![catch {parse list $literal {}} msg]} {
		return [checkListValues 0 -1 [list $chain] $tokens $index]
	    }
	}
    }

    # cases (0) and (ii)

    set i $index
    while {$i < $end} {
	set i [{*}$chain $tokens $i]
    }
    return $end
}

# As long as the current word is not a switch (i.e. starting with a
# dash '-') we run the chain. We stop processing on the first switch
# seen. Non-literal words are not switches.

proc analyzer::checkToSwitches {chain tokens index} {
    while {1} {
	set word [lindex $tokens $index]
	if {
	    [getLiteral $word literal] &&
	    [string match -* $literal]
	} break
	set index [{*}$chain $tokens $index]
    }
    return $index
}

proc analyzer::trackNamespace {chain tokens index} {
    ## return [eval $chain [list $tokens $index]] ; ## 3.0 FEATURE OFF

    if {$::configure::xref} {
	set idx $index
	set wsubcmd [lindex $tokens $idx]
	if {[getLiteral $wsubcmd subcmd]} {

	    if {
		$subcmd eq "children" ||
		$subcmd eq "delete" ||
		$subcmd eq "eval" ||
		$subcmd eq "exists" ||
		$subcmd eq "inscope" ||
		$subcmd eq "parent"
	    } {
		incr idx ; set wname [lindex $tokens $idx]
		if {[getLiteral $wname name]} {
		    # Record def/use of the namespace ...

		    set def [string equal $subcmd "eval"]

		    #::log::log debug "trackNamespace ==================="
		    #::log::log debug "trackNamespace ($subcmd) $def"
		    #::log::log debug "trackNamespace ($name)"

		    set name [context::join [context::top] $name]

		    if {$def} {
			xref::nsDefine $name
		    } else {
			xref::nsUse    $name
		    }
		}
	    }
	}
    }

    return [{*}$chain $tokens $index]
}


proc analyzer::newScope {type chain tokens index} {

    # Open a named lexical context/scope the script
    # coming after this word is in. xref-tracking.

    set word [lindex $tokens $index]
    if {[getLiteral $word name]} {
	set name [context::join [context::top] [namespace tail $name]]
	context::pushScope [list $type $name [getLocation]]
    }
    return [{*}$chain $tokens $index]
}


proc analyzer::newNamedScope {type name chain tokens index} {

    # Open a named lexical context/scope the script
    # coming after this word is in. xref-tracking.

    set name [context::join [context::top] $name]
    context::pushScope [list $type $name [getLocation]]

    return [{*}$chain $tokens $index]
}


proc analyzer::newNamespaceScope {type chain tokens index} {

    #::log::log debug "newNamespaceScope = ([context::top])"

    # Open a named lexical context/scope the script
    # coming after this word is in. xref-tracking.
    # NOTE: The fq classname is [context::top], because
    # it is also a namespace and was pushed in
    # 'CheckContext'.

    context::pushScope [list $type [context::top] [getLocation]]
    context::add [context::top] ; # Remember as existing context.

    return [{*}$chain $tokens $index]
}


# analyzer::warn
#
#	Generate a warning and call another checker.
#
# Arguments:
#	type		The message id to use.
#	detail		The detail string for the message.
#	chainCmd	The command to use to check the remainder of the
#			command line arguments.  This may be null.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::warn {type detail chainCmd tokens index} {
    logError $type [getTokenRange [lindex $tokens [expr {$index - 1}]]] $detail
    if {[llength $chainCmd]} {
	return [{*}$chainCmd $tokens $index]
    } else {
	return [checkCommand $tokens $index]
    }
}

proc ::analyzer::InvalidUsage {r chain tokens index} {
    logExtendedError \
	[CorrectionsOf 0 $tokens \
	     ldropto $index insert 0 $r save] \
	invalidUsage [getTokenRange [lindex $tokens ${index}-1]] $r
    return [{*}$chain $tokens $index]
}

proc ::analyzer::WarnUnsupported {offset range txtr reps chain tokens index} {
    return [WarnXX warnUnsupported $offset $range $txtr $reps $chain $tokens $index]
}

proc ::analyzer::WarnDeprecated {offset range txtr reps chain tokens index} {
    return [WarnXX warnDeprecated $offset $range $txtr $reps $chain $tokens $index]
}

proc ::analyzer::WarnObsoleteCmd {offset range txtr reps chain tokens index} {
    return [WarnXX obsoleteCmd $offset $range $txtr $reps $chain $tokens $index]
}

proc ::analyzer::WarnXX {mid offset range txtr reps chain tokens index} {
    if {![llength $range]} {
	set range [getTokenRange [lindex $tokens [expr {$index - 1}]]]
    }
    if {![llength $reps]} {
	set reps [list $txtr]
    }
    set  base $index
    incr base $offset
    set xcmd {}
    foreach r $reps {
	set postcmds {}
	if {[llength $r] == 2} {
	    lassign $r r postcmds
	}
	lappend xcmd label $base @ ldrop $base insert $base $r {*}$postcmds save
    }

    logExtendedError \
	[CorrectionsOf 0 $tokens {*}$xcmd] \
	$mid $range $txtr
    if {![llength $chain]} return
    return [{*}$chain $tokens $index]
}

proc analyzer::checkNOP {tokens index} {
    return $index
}

# Checkers for specific types --
#
#	Each type checker performs one or more checks on the type
#	of a given word.  If the word is not a literal value, then
#	it falls through to the generic checkWord procedure.
#
# Arguments:
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkBoolean {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's a boolean value

    if {[getLiteral $word literal]} {
	if {[catch {clock format 1 -gmt $literal}]} {
	    logError badBoolean [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkInt {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's an integer (as opposed to a float.)

    if {[getLiteral $word literal]} {
	if {[catch {incr literal}]} {
	    logError badInt [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkFloat {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's a float

    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }
    if {[catch {expr {abs($literal)}}]} {
	logError badFloat [getTokenRange $word]
    }
    return [incr index]
}

proc analyzer::checkWholeNum {tokens index} {
    # <=> 'checkIntMin 0', except for the associated message code.

    set word [lindex $tokens $index]
    # Check to see if:
    # - it's an integer that is >= 0.

    if {[getLiteral $word literal]} {
	if {[catch {incr literal 0}]} {
	    logError badWholeNum [getTokenRange $word] $literal
	} elseif {$literal < 0} {
	    logError badWholeNum [getTokenRange $word] $literal
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkNatNum {tokens index} {
    # <=> 'checkIntMin 1', except for the associated message code.

    set word [lindex $tokens $index]
    # Check to see if:
    # - it's an integer that is > 0.

    if {[getLiteral $word literal]} {
	if {[catch {incr literal 0}]} {
	    logError badNatNum [getTokenRange $word] $literal
	} elseif {$literal < 1} {
	    logError badNatNum [getTokenRange $word] $literal
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkIntMin {min tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's an integer that is >= $min

    if {[getLiteral $word literal]} {
	if {[catch {incr literal 0}]} {
	    logError badInt [getTokenRange $word] $literal
	} elseif {$literal < $min} {
	    logError badInt [getTokenRange $word] $literal
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkIndex {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's a string then verify it's "end".
    # - it's an integer (as opposed to a float.)

    if {[getLiteral $word literal]} {
	if {[catch {incr literal}]} {
	    if {$literal ne "end"} {
		logError badIndex [getTokenRange $word]
	    }
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkIndexExpr {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's a string then verify it's "end", or "end-<integer>"
    # - it's an integer (as opposed to a float.)

    if {[getLiteral $word literal]} {
	set length [string length $literal]
	if {[string equal -length [expr {($length > 3) ? 3 : $length}] \
		"end" $literal]} {
	    if {$length <= 3} {
		return [incr index]
	    } elseif {[string index $literal 3] eq "-"} {
		set literal [string range $literal 4 end]
		if {[catch {incr literal}]} {
		    logError badIndexExpr [getTokenRange $word]
		}
		return [incr index]
	    } else {
		logError badIndexExpr [getTokenRange $word]
	    }

	} elseif {[catch {incr literal}]} {
	    logError badIndexExpr [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkIndexExprExtend {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's a string then verify it's "end", or "end-<integer>", or "end+1"
    # - it's an integer (as opposed to a float.)

    if {[getLiteral $word literal]} {
	set length [string length $literal]
	if {[string equal -length [expr {($length > 3) ? 3 : $length}] \
		"end" $literal]} {
	    if {$length <= 3} {
		return [incr index]
	    } elseif {[string index $literal 3] eq "-"} {
		set literal [string range $literal 4 end]
		if {[catch {incr literal}]} {
		    logError badIndexExpr [getTokenRange $word]
		}
		return [incr index]
	    } elseif {[string range $literal 3 end] eq "+1"} {
		return [incr index]
	    } else {
		logError badIndexExpr [getTokenRange $word]
	    }

	} elseif {[catch {incr literal}]} {
	    logError badIndexExpr [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkExtendedIndexExpr {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's a string then verify it's "end", "end-<integer>", or "end+<integer>"
    # - its "<integer>-<integer>", or "<integer>+<integer>"
    # - it's an integer (as opposed to a float.)

    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }

    switch -exact -- $literal {
	e - en - end {return [incr index]}
    }

    if {[regexp {^end[+-](\d+)$} $literal -> n]} {
	# end+n, end-n
	if {[catch {incr n}]} {
	    logError badExtendedIndexExpr [getTokenRange $word]
	}
	return [incr index]
    }

    if {[regexp {^(\d+)[+-](\d+)$} $literal -> m n]} {
	# m+n, m-n
	if {[catch {incr m}] || [catch {incr n}]} {
	    logError badExtendedIndexExpr [getTokenRange $word]
	}
	return [incr index]
    }

    if {[catch {incr literal}]} {
	logError badExtendedIndexExpr [getTokenRange $word]
    }

    return [incr index]
}

proc analyzer::checkByteNum {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's an integer between 0 and 255

    if {[getLiteral $word literal]} {
	if {[catch {incr literal}]} {
	    logError badByteNum [getTokenRange $word]
	} elseif {($literal < 1) || ($literal > 256)} {
	    logError badByteNum [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkList {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - the list command can parse it.

    if {[getLiteral $word literal]} {
	if {[catch {parse list $literal {}} msg]} {
	    logError badList \
		    [list [getLiteralPos $word [lindex $::errorCode 2]] 1] $msg
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkDict {tokens index} {
    checkListModNk 2 0 $tokens $index
}

proc analyzer::checkListModNk {n k tokens index} {
    # Check that 'list length % N == k'.

    set word [lindex $tokens $index]
    # Check to see if:
    # - the list command can parse it.

    if {[getLiteral $word literal]} {
	if {[catch {parse list $literal {}} msg]} {
	    logError badList \
		    [list [getLiteralPos $word [lindex $::errorCode 2]] 1] $msg
	}

	if {([llength $literal] % $n) != $k} {
	    logError badListLength [getTokenRange $word] $n $k
	}

	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}


proc analyzer::checkRegexp {tokens index} {
    # When upgrading Tcl 8.0 to 8.1, warn about possible incompatabilities
    # from the old regexp packages.  The new regexp package defines many
    # new special chars that follow backslashes.  As well, backslashes in
    # brackets have changed meaning.  They are now quotes, not a simple char.
    # The three types of warnings are:
    # 
    # (1) Backslash followed by 8.1 ESCAPE char:
    #      Warn about change of behavior in 8.1.
    #
    # (2) Backslash followed by non-special char in 8.0 or 8.1.
    #      Warn them this could be superfluous or missing another '\'.
    #
    # (3) Inside brackets, odd number of backslashes.
    #      Warn that the \ is now a quote and not a char.
    
    set escapeChar {
	a A b B c d D e f
	n m M r t u U v
	s S w W x y Y Z 0
    }
    set specialChar {\"\*+?.^$()[]|{}}
    
    set word  [lindex $tokens $index]
    set range [getTokenRange $word]

    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }

    # Preliminary checks using the regexp command itself.

    if {![getLiteral [lindex $tokens [expr {$index + 1}]] inputStringValue]} {
	# We have literal pattern, but are unable to determine the
	# input string. Test with a bogus input string to catch at
	# least compile errors in the pattern.
	#
	# Use -- to prevent a heading - in the pattern to mess this
	# check up.

	set fail [catch {regexp -- $value XXX_bogus_XXX} errmsg]

    } else {
	# For both literal pattern and input string we can check for
	# match errors as well.

	set fail [catch {regexp $value $inputStringValue} errmsg]
    }
    if {$fail} {
	logError badRegexp $range $errmsg
    }

    while {$value ne {}} {
	set bsFirst [string first "\\" $value]
	set bkFirst [string first "\[" $value]

	if {($bsFirst < 0) && ($bkFirst < 0)} {
	    # No backslashes or brackets.  This is a simple expression.
	    # Do nothing and return.

	    break
	} elseif {($bkFirst == -1) || (($bsFirst < $bkFirst) && ($bsFirst != -1))} {
	    # Found a backslash first.  Check according to (1) and (2).
	    # When this body is done, 'i' should point to the char
	    # immediately after the backslashed character.

	    set i    [expr {$bsFirst + 1}]
	    set c    [string index $value $i]
	    set oct2 [string range $value $i [expr {$i+1}]]
	    set oct3 [string range $value $i [expr {$i+2}]]

	    if {$c in $escapeChar} {
		# The next character is an escape char in Tcl8.1.
		# Warn the user that this regexp will change in 8.1.

		if {[pcx::getCheckVersion coreTcl] < 8.1} {
		    logError warnEscapeChar $range $c
		}
	    } elseif {[Octal $oct3]} {
		# The next three characters form a valid octal
		# number.

		if {[pcx::getCheckVersion coreTcl] < 8.1} {
		    logError warnEscapeChar $range $oct3
		}
	    } elseif {[Octal $oct2]} {
		# The next two characters form a valid octal
		# number.

		if {[pcx::getCheckVersion coreTcl] < 8.1} {
		    logError warnEscapeChar $range $oct2
		}
	    } elseif {[string first $c $specialChar] < 0} {
		# The next character has no meaning when quoted.
		# Generate an error stating that the backslash has no
		# purpose or could be missing an additional backslash.

		logExtendedError \
		    [CorrectionsOf 0 $tokens \
			 get $index wmap [list \\$c $c]     replace $index save \
			 get $index wmap [list \\$c \\\\$c] replace $index save] \
		    warnNotSpecial $range $c
	    }
	    incr i
	} else {
	    # Found a open bracket first.  Check according to (3).
	    # When this body is done, 'i' should point to the char 
	    # just after the closing bracket.

	    set v [string range $value $bkFirst end]

	    # Extract the string within the brackets.  Strip off leading
	    # ^\]s or \]s to simplify the scan.  If there are backslashes
	    # inside of the brackets, check for odd numger of brackets. 
	    # Otherwise bump the index to the char after the trailing
	    # bracket and continue.  

	    set exp  {}
	    set brkt {}

	    if {[regexp {\[(\]|\^\]|)([^\]]*)(\])?} $v match lead exp brkt]} {
		# Only check for quotes inside of brackets for 8.0 or older.
		# If there is an odd number of backslashes in a row, warn the
		# user that the semantics will change in 8.1.

		if {[pcx::getCheckVersion coreTcl] < 8.1} {
		    set numBs 0
		    for {set i 0} {$i < [string length $exp]} {incr i} {
			if {[string index $exp $i] eq "\\"} {
			    incr numBs
			} else {
			    if {$numBs % 2} {
				logError warnQuoteChar $range
			    }
			    set numBs 0
			}
		    }
		    if {$numBs % 2} {
			logError warnQuoteChar $range
		    }
		}
		set i [expr {$bkFirst + [string length $match]}]
	    } else {
		# We should never get here, but if we do it is probably
		# because the regular expression above was ill-formed.

		puts "internal error: the expression could not be parsed."
		return [checkWord $tokens $index]
	    }

	    # If the regexp above did not find a closing bracket, the 
	    # brkt variable will be an empty string.  Warn the use 
	    # they have a poorly formed bracket expression.

	    if {$brkt eq {}} {
		logError errBadBrktExp $range
	    }
	}

	# The next backslash or bracket expression has just been checked.
	# Modify the "value" string to point to the next char to check.
	# The 'i' variable shouldbe pointing to the next char.

	set value [string range $value $i end]

    }
    return [incr index]
}

proc analyzer::Octal {str} {
    return [regexp {^[0-7]+$} $str]
}

proc analyzer::checkVarName {tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	style::set $index varname/lhs
	checkVariable read $literal $literal [getTokenRange $word] $word
	return [incr index]
    } else {
	set subtokens [lindex $word 2]
	if {([llength $subtokens] >= 1) \
		&& ([lindex $subtokens 0 0] eq "variable")} {
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wsplit {} drop 0 wjoin {} replace $index save] \
		warnVarRef [getTokenRange $word]
	} else {
	    return [checkWord $tokens $index]
	}
    }
    return [incr index]
}

proc analyzer::checkArrayVarName {tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	style::set $index varname/lhs
	checkVariable read $literal $literal [getTokenRange $word] $word array
	return [incr index]
    } else {
	set subtokens [lindex $word 2]
	if {([llength $subtokens] >= 1) \
		&& ([lindex $subtokens 0 0] eq "variable")} {
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wsplit {} drop 0 wjoin {} replace $index save] \
		warnVarRef [getTokenRange $word]
	} else {
	    return [checkWord $tokens $index]
	}
    }
    return [incr index]
}

proc analyzer::checkVarNameWrite {tokens index} {
    # Variant of checkVarName where we are sure that
    # the command does write to the variable.

    set word [lindex $tokens $index]

    #::log::log debug "checkVarNameWrite $word"

    if {[getLiteral $word literal]} {
	style::set $index varname/lhs
	checkVariable write $literal $literal [getTokenRange $word] $word
	return [incr index]
    } else {
	#::log::log debug "checkVarNameWrite /not a literal, do subtokens only, simple checkWord"

	set subtokens [getTokenChildren $word]
	if {([llength $subtokens] >= 1) \
		&& ([getTokenType [lindex $subtokens 0]] eq "variable")} {
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wsplit {} drop 0 wjoin {} replace $index save] \
		warnVarRef [getTokenRange $word]
	} else {
	    # One token, or first token is not a variable ...
	    #
	    # This can be a write access to an array variable,
	    # with a dynamic index.

	    if {[llength $subtokens] == 3} {
		lassign $subtokens varstem idx trail

		#::log::log debug "\tstem  [getTokenType $varstem] |[getTokenString $varstem]|"
		#::log::log debug "\tidx   [getTokenType $idx    ] |[getTokenString $idx]|"
		#::log::log debug "\ttrail [getTokenType $trail  ] |[getTokenString $trail]|"

		if {
		    ([getTokenType $varstem] eq "text") &&
		    ([getTokenType $idx] eq "variable") &&
		    ([getTokenType $trail] eq "text") &&
		    [regexp {^[^(]+\(} [getTokenString $varstem]] &&
		    ([getTokenString $trail] eq ")")
		} {
		    #::log::log debug "\tARRAY access with literal array and dynamic index"

		    style::set $index varname/lhs
		    checkVariable write \
			    [string range [getTokenString $varstem] 0 end-1] \
			    [getTokenString $word] \
			    [getTokenRange $word] $word
		}
	    }

	    return [checkWord $tokens $index]
	}
    }
    return [incr index]
}

proc analyzer::checkVarNameReadWrite {tokens index} {
    # Variant of checkVarName where we are sure that
    # the command does write to the variable, after reading it.

    set word [lindex $tokens $index]

    #::log::log debug "checkVarNameWrite $word"

    if {[getLiteral $word literal]} {
	style::set $index varname/lhs
	checkVariable read  $literal $literal [getTokenRange $word] $word
	checkVariable write $literal $literal [getTokenRange $word] $word
	return [incr index]
    } else {
	#::log::log debug "checkVarNameWrite /not a literal, do subtokens only, simple checkWord"

	set subtokens [getTokenChildren $word]
	if {([llength $subtokens] >= 1) \
		&& ([getTokenType [lindex $subtokens 0]] eq "variable")} {
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wsplit {} drop 0 wjoin {} replace $index save] \
		warnVarRef [getTokenRange $word]
	} else {
	    # One token, or first token is not a variable ...
	    #
	    # This can be a write access to an array variable,
	    # with a dynamic index.

	    if {[llength $subtokens] == 3} {
		lassign $subtokens varstem idx trail

		#::log::log debug "\tstem  [getTokenType $varstem] |[getTokenString $varstem]|"
		#::log::log debug "\tidx   [getTokenType $idx    ] |[getTokenString $idx]|"
		#::log::log debug "\ttrail [getTokenType $trail  ] |[getTokenString $trail]|"

		if {
		    ([getTokenType $varstem] eq "text") &&
		    ([getTokenType $idx] eq "variable") &&
		    ([getTokenType $trail] eq "text") &&
		    [regexp {^[^(]+\(} [getTokenString $varstem]] &&
		    ([getTokenString $trail] eq ")")
		} {
		    #::log::log debug "\tARRAY access with literal array and dynamic index"

		    style::set $index varname/lhs
		    checkVariable read \
			    [string range [getTokenString $varstem] 0 end-1] \
			    [getTokenString $word] \
			    [getTokenRange $word] $word
		    checkVariable write \
			    [string range [getTokenString $varstem] 0 end-1] \
			    [getTokenString $word] \
			    [getTokenRange $word] $word
		}
	    }

	    return [checkWord $tokens $index]
	}
    }
    return [incr index]
}

proc analyzer::checkVarNameDecl {tokens index} {
    # Variant of checkVarName where we are sure that
    # the command does nothing with the variable (except
    # declaring it in the scope).

    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	style::set $index varname/lhs
	checkVariable decl $literal $literal [getTokenRange $word] $word
	return [incr index]
    } else {
	set subtokens [lindex $word 2]
	if {([llength $subtokens] >= 1) \
		&& ([lindex $subtokens 0 0] eq "variable")} {
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wsplit {} drop 0 wjoin {} replace $index save] \
		warnVarRef [getTokenRange $word]
	} else {
	    return [checkWord $tokens $index]
	}
    }
    return [incr index]
}

proc analyzer::checkVarNameSyntax {tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	style::set $index varname/lhs
	checkVariable syntax $literal $literal [getTokenRange $word] $word
	return [incr index]
    } else {
	set subtokens [lindex $word 2]
	if {([llength $subtokens] >= 1) \
		&& ([lindex $subtokens 0 0] eq "variable")} {
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wsplit {} drop 0 wjoin {} replace $index save] \
		warnVarRef [getTokenRange $word]
	} else {
	    return [checkWord $tokens $index]
	}
    }
    return [incr index]
}

proc analyzer::checkProcName {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - it's a non-literal
    # - it's a built-in command
    # - it's a user-defined procedure
    # - it's an object command (starts with '.')

    if {[getLiteral $word cmdName]} {

	set systemCmdName [string trimleft $cmdName :]

	if {![uproc::exists [context::top] $cmdName pInfo] \
		&& ![info exists analyzer::checkers($systemCmdName)] \
		&& ![string match ".*" $cmdName]} {

	    # This is a command that is neither defined by the
	    # user or defined to be a global proc.

	    WarnUndef $cmdName [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

# analyzer::checkProcCall --
#
#	This function checks a procedure call where some fixed number of args
#	will be appended implicitly.  This proc fixes bugs 826, 883, and 1039.
#
#	Limitation:  If the proc is a system command, is non-literal or begins
#	with a dot, we don't check the number or validity of the args.
#
# Arguments:
#	argsToAdd	Number of non-literal args to append to the proc call.
#			Currently, this value is ignored, as we do not yet
#			check the number and validity of the proc's args.
#	tokens		The list of word tokens for the current command.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc analyzer::checkProcCall {argsToAdd tokens index} {
    # If it's a non-literal proc call, just check that it's a valid word.
    # Otherwise, check that the first elt of the list is a valid proc name.

    set word [lindex $tokens $index]
    if {[getLiteral $word cmdName]} {
	if {[uproc::exists [context::top] $cmdName pInfo]} {
	    # HACK:  append "argsToAdd" extra empty elements to the "tokens"
	    # list.  This works because checkUserProc only uses "tokens" for
	    # its length.

	    set fakeTokens [list $word]
	    for {set i 1} {$i <= $argsToAdd} {incr i} {
		lappend fakeTokens $word
	    }

	    # Don't return the result of checkUserProc because it is affected
	    # by the fact that we've purturbed the token list.  Just assume the
	    # checkUserProc call went well and return the next index to check.

	    cdb::checkUserProc $cmdName $pInfo $fakeTokens 1
	    return [expr {$index + 1}]
	} else {
	    return [checkListValues 1 -1 {checkProcName checkWord} \
		    $tokens $index]
	}
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkFileName {tokens index} {
    variable script
    set word [lindex $tokens $index]
    set hasSubst 0
    set result ""

    # Check to see if the word contains both a substitution and a directory
    # separator character.  This is probably a situation where "file join"
    # should be used.

    foreach token [lindex $word 2] {
	set type [lindex $token 0]
	if {($type eq "variable") || ($type eq "command")} {
	    set hasSubst 1
	} elseif {$type eq "backslash"} {
	    append result [subst [getString $script [lindex $token 1]]]
	} else {
	    append result [getString $script [lindex $token 1]]
	}
    }
    if {$hasSubst && [regexp {[/\\:]} $result]} {
	logExtendedError \
	    [CorrectionsOf 0 $tokens \
		 get $index \
		 wsplit / winsert 0 {file join} wjoin { } \
		 replace $index brackets $index $index save] \
	    nonPortFile [getTokenRange $word]
    }
    return [checkWord $tokens $index]
}

proc analyzer::checkChannelID {tokens index} {
    set word [lindex $tokens $index]
    # Check to see if:
    # - the id is file0, file1, or file2

    if {[getLiteral $word literal]} {
	if {[string match {file[0-2]} $literal]} {
	    set thestd [lindex {stdin stdout stderr} [string index $literal 4]]
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     lset $index $thestd save] \
		nonPortChannel [getTokenRange $word] $thestd
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkArgList {tokens index} {
    style::set $index args
    set word [lindex $tokens $index]

    # Check to see if:
    # - the list command can parse it.
    # - no arguments follow "args".
    # - no args are variable references.
    # - no non-default args follow defaulted args (unless args.)
    # - defaulted args is a list of only two elements.
    # - args is not defaulted (e.g., proc foo {{args 2}} {})

    if {[getLiteral $word literal]} {
	checkList $tokens $index

	set defaultFound 0
	set argsFound    0
	set argAfterArgsFound   0
	set nonDefAfterDefFound 0

	# Ignore list parsing errors because they have already been
	# reported by checkList.
	set ::errorInfo {}
	catch {
	    set n 0
	    foreach arg $literal {
		set defaultFlag  0
		set argsFlag     0

		if {[string match "$*" $arg]} {
		    logExtendedError \
			[CorrectionsOf 0 $tokens \
			     get $index wregsub {(\s+)\$} {\1} replace $index save] \
			warnVarRef [getTokenRange $word]
		}
		if {[llength $arg] > 2} {
		    logExtendedError \
			[CorrectionsOf 0 $tokens \
			     get $index dropafterx 2 $n 1 replace $index save \
			    ] \
			tooManyFieldArg [getTokenRange $word]
		    incr n
		    continue
		}

		if {[llength $arg] == 2} {
		    set defaultFlag 1
		    set arg [lindex $arg 0]
		}
		if {$arg eq "args"} {
		    set argsFlag 1
		}

		if {$defaultFlag} {
		    set defaultFound 1
		} elseif {$defaultFound && !$argsFlag} {
		    if {!$nonDefAfterDefFound} {
			set no $n
			incr n -1
			logExtendedError \
			    [CorrectionsOf 0 $tokens \
				 get $index drop         $no  replace $index save \
				 get $index dropafter    $n   replace $index save \
				 get $index dropafterx 2 $n 0 replace $index save \
				] \
			    nonDefAfterDef [getTokenRange $word]
			set nonDefAfterDefFound 1
			incr n
		    }
		}
		if {$argsFlag && !$argsFound} {
		    if {$defaultFlag} {
			logExtendedError \
			    [CorrectionsOf 0 $tokens \
				get $index dropafterx 2 $n 0 replace $index save] \
			    argsNotDefault [getTokenRange $word]
		    }
		    set argsFound 1
		} elseif {$argsFound && !$argAfterArgsFound} {
		    incr n -1
		    logExtendedError \
			[CorrectionsOf 0 $tokens \
			     get $index drop      $n replace $index save \
			     get $index dropafter $n replace $index save \
			     get $index movetoend $n replace $index save \
			    ] \
			argAfterArgs [getTokenRange $word]
		    set argAfterArgsFound 1
		    incr n
		}
		incr n
	    }
	}

	set ::errorInfo {}
	catch {
	    # Now do the same as in the scan phase, add variable
	    # definitions for the arguments. This ensures that
	    # we have at least minimal var/arg tracking in the
	    # analyze phase, for a -onepass.

	    # Variable tracking ... Add the listed arguments as
	    # implicit variables to the scope for later checking.
	    # The readonly bit can be used in the future to warn
	    # when other commands write argument values. They are
	    # incoming only, never written back to the caller.

	    # Keep order information as well

	    set narg 0
	    foreach arg $literal {
		if {[llength $arg] >= 2} {
		    lassign $arg arg def

		    # See cdb.tcl, typemethod addArgList
		    # Disabling warning about overwritten arguments ...
		    #readonly 1 \#
		    xref::varDef argument $arg \
			    default  $def \
			    narg [incr narg]
		} else {
		    #readonly 1 \#
		    xref::varDef argument $arg \
			    narg [incr narg]
		}
	    }
	}

	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkEvalArgs {args} {
    switch -exact -- [llength $args] {
	2 {
	    lassign $args tokens index
	    set style body/single-line
	}
	3 {
	    lassign $args style tokens index
	}
	default {
	    return -code error "wrong\#args, expected ?style? tokens index"
	}
    }

    # Check to see if:
    # - there is a single literal argument that can be recursed into

    set argc [llength $tokens]
    if {($index != ($argc - 1)) \
	    || ![isLiteral [lindex $tokens $index]]} {
	return [checkCommand $tokens $index]
    }
    return [checkAsStyle $style checkBody $tokens $index]
}

proc analyzer::checkNamespace {tokens index} {
    # Check to see if:
    # - the namespace is correctly qualified.

    style::set $index nsname
    return [checkWord $tokens $index]
}

proc analyzer::checkNamespacePattern {tokens index} {
    # Check to see if:
    # - there are glob characters before the last :: in a namespace pattern

    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	if {[regexp {[][\\*?]+.*::} $literal]} {
	    logError warnNamespacePat [getTokenRange $word]
	}

	if {$::configure::xref} {
	    # Record namespace in pattern as used.

	    set literal [context::head [context::join [context::top] $literal]]

	    #::log::log debug "trackNamespace Pt ==================="
	    #::log::log debug "trackNamespace Pt ($literal)"

	    xref::nsUse $literal
	}
    }
    return [checkPattern $tokens $index]
}

proc analyzer::checkExportPattern {tokens index} {
    # Check to see if:
    # - there are any namespace qualifiers in the string

    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	if {[regexp {::} $literal]} {
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wregsub {^.*::} {} replace $index save \
		     get $index wregsub ::      {} replace $index save \
		    ]\
		warnExportPat [getTokenRange $word]
	}
	return [checkPattern $tokens $index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkPattern {tokens index} {
    # Check to see if:
    # - a pattern has a word with a mix of sub-commands and
    #   non-sub-commands.  If it does then they might have
    #   a bracketed sequence that was not correctly delimited.

    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	return [incr index]
    } else {
	set subCmdFound 0
	set nonCmdFound 0
	foreach subWord [lindex $word 2] {
	    if {[lindex $subWord 0] eq "command"} {
		set subCmdFound 1
	    } else {
		set nonCmdFound 1
	    }
	    if {$subCmdFound && $nonCmdFound} {
		logError warnPattern [getTokenRange $word]
		break
	    }
	}
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkAccessMode {tokens index} {
    # If the word is a literal and begins with a capital letter
    # then check against POSIX access list.  Otherwise check
    # against the standard Tcl access list.

    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	if {[string match {[a-z]*} $literal]} {
	    return [checkKeyword 1 {r r+ w w+ a a+} $tokens $index]
	}

	if {[catch {parse list $literal {}} ranges]} {
	    logError badList [list [getLiteralPos $word \
		    [lindex $::errorCode 2]] 1] $ranges
	    return [incr index]
	}

	# Make sure at least one of the read/write flags was
	# specified (RDONLY, WRONLY or RDWR).  It is an error
	# to specify other w/o a read/write flag.

	set gotRW 0
	set modes {RDONLY WRONLY RDWR APPEND CREAT EXCL NOCTTY NONBLOCK TRUNC}
	foreach mode $literal range $ranges {
	    set i [lsearch -exact $modes $mode]
	    if {$i == -1} {
		logError badKey [getLiteralRange $word $range] $modes $mode
	    } elseif {$i >= 0 && $i <= 2} {
		set gotRW 1
	    }
	}
	if {!$gotRW} {
	    logError badMode [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkAccessModeB {tokens index} {
    # If the word is a literal and begins with a capital letter
    # then check against POSIX access list.  Otherwise check
    # against the standard Tcl access list.

    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	if {[string match {[a-z]*} $literal]} {
	    return [checkKeyword 1 {
		r   r+ w   w+ a   a+
		br br+ bw bw+ ba ba+
		rb rb+ wb wb+ ab ab+
	    } $tokens $index]
	}

	if {[catch {parse list $literal {}} ranges]} {
	    logError badList [list [getLiteralPos $word \
		    [lindex $::errorCode 2]] 1] $ranges
	    return [incr index]
	}

	# Make sure at least one of the read/write flags was
	# specified (RDONLY, WRONLY or RDWR).  It is an error
	# to specify other w/o a read/write flag.

	set gotRW 0
	set modes {BINARY RDONLY WRONLY RDWR APPEND CREAT EXCL NOCTTY NONBLOCK TRUNC}
	foreach mode $literal range $ranges {
	    set i [lsearch -exact $modes $mode]
	    if {$i == -1} {
		logError badKey [getLiteralRange $word $range] $modes $mode
	    } elseif {$i >= 0 && $i <= 2} {
		set gotRW 1
	    }
	}
	if {!$gotRW} {
	    logError badMode [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::checkResourceType {tokens index} {
    # Check to see if:
    # - The resource is a four letter word.  If it is not
    #   just warn them of the error.

    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	if {[string length $literal] != 4} {
	    logError badResource [getTokenRange $word]
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

namespace eval analyzer {
    # State variables used by 'package' statements to record
    # information.
    variable pName        ; # Name of the package
    variable pOp          ; # Manager operation, possibly none.
    variable pVersion     ; # Package version string
    variable pVersionType ; # More information about the version
    #                     ; # string: dynamic / literal / unknown
    variable pRequirements ; # More information about the versions (85)
    #                      ; # string: dynamic / literal / unknown
}

proc analyzer::isPkgExact {chain tokens index} {
    variable pVersionType exact
    return [{*}$chain $tokens $index]
}

proc analyzer::checkPackageName {op tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	variable pName $literal
	variable pOp   $op
    } else {
	variable pName {}
	variable pOp   none
    }

    return [checkWord $tokens $index]
}

proc analyzer::checkPkgVersion {tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	variable pVersion     $literal
	variable pVersionType literal
    } else {
	variable pVersion     {}
	variable pVersionType dynamic
    }

    return [checkVersion $tokens $index]
}

proc analyzer::checkPkgExtVersion {tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	variable pVersion     $literal
	variable pVersionType literal
    } else {
	variable pVersion     {}
	variable pVersionType dynamic
    }

    return [checkExtVersion $tokens $index]
}

proc analyzer::checkPkgRequirement {tokens index} {
    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {
	variable pRequirements
	lappend  pRequirements $literal
	variable pVersionType non-exact
    }

    return [checkRequirement $tokens $index]
}

proc analyzer::checkVersion {tokens index} {
    # Check to see if:
    # - it's a valid version (it must have a decimal in it:  X.XX)

    set word [lindex $tokens $index]
    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }

    foreach ver [split $literal .] {
	if {[catch {incr ver}]} {
	    logError badVersion [getTokenRange $word]
	}
    }
    return [incr index]
}

proc analyzer::checkRequirement {tokens index} {

    set word [lindex $tokens $index]
    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }

    set vl [split $literal -]

    if {
	([llength $vl] > 2) ||
	[BadExtVersion [lindex $vl 0]] ||
	(([llength $vl] == 2) &&
	 ([string length [lindex $vl 1]] > 0) &&
	 [BadExtVersion [lindex $vl 1]])
    } {
	logError badRequirement [getTokenRange $word]
    }

    return [incr index]
}


proc analyzer::checkExtVersion {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }
    if {[BadExtVersion $literal]} {
	logError badVersion [getTokenRange $word]
    }
    return [incr index]
}

proc analyzer::BadExtVersion {version} {
    if {[catch {vIntList $version} msg]} {
	return 1
    } else {
	return 0
    }
}

proc analyzer::vIntList {version} {
    # Convert a version number to an equivalent list of integers
    # Raise error for invalid version number

    if {$version eq {} || [string match *-* $version]} {
 	# Reject literal negative numbers
 	return -code error "invalid version number: \"$version\""
    }
    # Note only lowercase "a" and "b" accepted and only one
    if {[llength [split $version ab]] > 2} {
 	return -code error "invalid version number: \"$version\""
    }
    set converted [string map {a .-2. b .-1.} $version]
    set list {}
    foreach element [split $converted .] {
 	if {[::scan $element %d%s i trash] != 1} {
 	    # Require decimal formatted numbers with no suffix
 	    return -code error "invalid version number: \"$version\""
 	}
 	if {[catch {incr i 0}] || $i < -2 } {
           # Verify each component is integer >= -2
 	    return -code error "invalid version number: \"$version\""
 	}
 	lappend list $i
    }
    return $list
 }

proc analyzer::checkWinName {tokens index} {
    # Check to see if:
    # - the first character is "."
    # - the second character is a number or lowercase letter

    set word [lindex $tokens $index]
    if {[getLiteral $word literal]} {

	if {![string match ".*" $literal]} {
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		    get $index wstrinsert 0 . replace $index save] \
		winBeginDot [getTokenRange $word]
	} else {
	    analyzer::CheckWinNameInternal $literal $word $tokens $index
	}
	return [incr index]
    } else {
	return [checkWord $tokens $index]
    }
}

proc analyzer::CheckWinNameInternal {name word tokens index} {
    lassign [getTokenRange $word] errIndex errLen  
    set errPos 0

    foreach win [split [string range $name 1 end] .] {
	incr errPos
	if {$win eq {}} {
	    set errRange [list [expr {$errIndex + $errPos}] \
		    [expr {$errLen + $errPos}]]
	    logError winNotNull $errRange
	} elseif {[string match {[A-Z]*} $win]} {
	    set errRange [list [expr {$errIndex + $errPos}] \
		    [expr {$errLen + $errPos}]]
	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     get $index wstrlow 1 replace $index save] \
		winAlpha $errRange
	}
	incr errPos [string length $win]
    }
    return
}

proc analyzer::checkColor {tokens index} {
    # Check #RBG format and known Windows colors for 8.0

    set word [lindex $tokens $index]
    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }
    analyzer::CheckColorInternal $literal $word
    return [incr index]
}

proc analyzer::CheckColorInternal {color word} {
    variable portableColors80

    # If the literal begind with a # sign, then check to
    # see if it the correct format.  Otherwise, verify
    # the specified color is portable.

    if {[string match "#*" $color]} {
	# If the length is not the correct number of
	# digits, or the value of "integer" is not
	# an integer, then log a color format error.

	set hex [string range $color 1 end]
	set len [string length $hex]
	if {$len ni {3 6 9 12}} {
	    logError badColorFormat [getTokenRange $word]
	} else {
	    set index 0
	    set range [expr {$len / 3}]
	    while {$index < $len} {
		set c "0x[string range $hex $index [expr {$index + $range - 1}]]"
		if {[catch {expr {abs($c)}}]} {
		    logError badColorFormat [getTokenRange $word]
		    break
		}
		incr index $range
	    }
	}
    } elseif {$color ni $portableColors80} {
	# AK XXX We can provide corrections, in principle, using the
	# 80 colors in portableColors80. However, 80 suggestions is a
	# bit much I believe.
	logError nonPortColor [getTokenRange $word]
    }
    return
}

proc analyzer::checkPixels {tokens index} {
    # Check the pixel format: <float>?c,i,m,p?

    set word [lindex $tokens $index]
    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }

    if {[string match {*[cimp]} $literal]} {
	set float [string range $literal 0 end-1]
    } else {
	set float $literal
    }
    if {[catch {expr {abs($float)}}]} {
	logError badPixel [getTokenRange $word]
    }
    return [incr index]
}

proc analyzer::checkCursor {tokens index} {
    # Check the following patterns:
    # ""
    # name
    # "name fgColor"
    # "@sourceFile fgColor"
    # "name fgColor bgColor"
    # "@sourceFile maskFile fgColor bgColor"

    set word [lindex $tokens $index]
    if {![getLiteral $word literal]} {
	return [checkWord $tokens $index]
    }
    if {[catch {llength $literal}]} {
	logError badCursor [getTokenRange $word]
	return [incr index]
    }
    set parts [split $literal]

    set lp [llength $parts]
    if {$lp == 0} {
	# No-op
    } elseif {$lp == 1} {
	analyzer::CheckCursorInternal $parts $word
    } elseif {$lp == 2} {
	logError nonPortCmd [getTokenRange $word]
	lassign $parts cursor color
	if {![string match "@*" $cursor]} {
	    analyzer::CheckCursorInternal $cursor $word
	}
	analyzer::CheckColorInternal $color $word
    } elseif {$lp == 3} {
	logError nonPortCmd [getTokenRange $word]
	lassign $parts cursor color mask
	analyzer::CheckCursorInternal $cursor $word
	analyzer::CheckColorInternal  $color  $word
	analyzer::CheckColorInternal  $mask   $word
    } elseif {$lp == 4} {
	logError nonPortCmd [getTokenRange $word]
	lassign $parts file _ color mask
	if {![string match "@*" $file]} {
	    logError badCursor [getTokenRange $word]
	}
	analyzer::CheckColorInternal $color $word
	analyzer::CheckColorInternal $mask  $word
    } else {
	logError badCursor [getTokenRange $word]
    }
    return [incr index]
}

proc analyzer::CheckCursorInternal {name word} {
    variable commonCursors
    variable winCursors
    variable macCursors

    # Verify the cursor name is defined across all platforms.

    if {$name ni $commonCursors} {
	if {$name in $winCursors} {
	    # AK XXX We can provide corrections, in principle, using
	    # the common-win-mac cursors. However, ~76 suggestions is
	    # a bit much I believe.
	    logError nonPortCursor [getTokenRange $word]
	} elseif {$name in $macCursors} {
	    logError nonPortCursor [getTokenRange $word]
	} else {
	    logError badCursor [getTokenRange $word]
	}
    }
    return
}

proc analyzer::checkRelief {tokens index} {
    # Check the relief.  This is defined as a proc because there are three
    # switches that call the same routine (-relief, -activerelief and
    # -sliderelief.)

    return [checkKeyword 1 {raised sunken flat ridge solid groove} \
	    $tokens $index]
}

proc analyzer::checkDynLit {off dynchain litchain tokens index} {
    # Conditional checking. Two different sub checkers. One invoked
    # for a literal word, the other for a dynamic word. The word to
    # check is given as offset relative to the current word (index).

    # Basic length check ..

    set  argc [llength $tokens]
    incr argc -$index

    if {$off > $argc} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }

    set body $index ; incr body $off

    #::log::log debug "checkDynLit: Check word @ $index + $off = $body"

    # Check first if the word to check for literalness is outside of
    # the token list. If so we go through the dynamic branch. This was
    # a toss-up, as we assume that both branches do proper checking of
    # the number of expected arguments. Bug 45702.

    if {($body >= [llength $tokens]) || ![isLiteral [lindex $tokens $body]]} {
	#::log::log debug "checkDynLit: Dynamic - $dynchain"

	set index [{*}$dynchain $tokens $index]
    } else {
	#::log::log debug "checkDynLit: Literal - $litchain"

	set index [{*}$litchain $tokens $index]
    }
    return $index
}


proc analyzer::checkAll {chains tokens index} {
    # This checker executes all chains it was given, one by one.
    # Each checker is started from index. In a sense the checkers
    # are done in parallel. Message accumulate. This is actually
    # more to allow the execution of preparatory work before the
    # actual checker. Example: The 'xref proc' checker uses this
    # to run scan pass commands during analysis, allowing for more
    # work done in a single pass.
    #
    # The code remembers the _max_ index returned by a chain and returns
    # that as the index for the next word to process.

    set max $index

    foreach chain $chains {
	set n [{*}$chain $tokens $index]
	if {$n > $max} {set max $n}
    }
    return $max
}

proc analyzer::checkDoubleDash {chain tokens index} {
    if {$index >= [llength $tokens]} {
	return [{*}$chain $tokens $index]
    }

    variable script

    set word [lindex $tokens $index]
    if {[isLiteral $word]} {
	# The current token is a pure literal, no check required,
	# invoke chain.
	return [{*}$chain $tokens $index]
    }

    set wtype  [lindex $word 0]
    if {$wtype  eq "word"} {
	# XXX AK fold into single multi-index lindex
	set fctype [lindex [lindex [lindex $word 2] 0] 0]
	# 2 - children, 0 - first child, 0 - type of child

	if {$fctype eq "text"} {
	    # The token is dynamic, but begins with a literal text
	    # (First child is literal text). No check required if
	    # there is no dash at the beginning. Otherwise we should
	    # check for -- and warn anyway.

	    # XXX AK fold into single multi-index lindex
	    set head [getString $script [lindex [lindex [lindex $word 2] 0] 1]]
	    # 2,0 see above, 1 - token range

	    if {![string match -* $head]} {
		return [{*}$chain $tokens $index]
	    }
	} elseif {$fctype eq "backslash"} {

	    # The token is dynamic, but begins with a literal text
	    # (First child is backslash). As backslash it cannot have
	    # a double dash, so no further checks required.

	    return [{*}$chain $tokens $index]
	}
    }

    # The word under scrutiny is dynamic. This means that a double
    # dash (--) is needed to prevent a possible interpretation of its
    # contents as switch. We have to check all arguments coming before
    # the current one.

    set ok 0
    for {set prev $index ; incr prev -1} {$prev >= 0} {incr prev -1} {
	if {![getLiteral [lindex $tokens $prev] doubledash] || ($doubledash ne "--")} continue
	set ok 1
	break
    }
    if {!$ok} {
	# Report not only the problem, but a possible fix.
	logExtendedError \
	    [CorrectionsOf 1 $tokens \
		 insert $index -- save] \
	    warnDoubleDash [getTokenRange $word]
    }

    return [{*}$chain $tokens $index]
}

#
# ----------------------------------------------------------------------------
#

proc analyzer::checkConstrained {chain tokens index} {
    variable    constraints
    array unset constraints *
    return [{*}$chain $tokens $index]
}

proc analyzer::checkSetConstraints {list chain tokens index} {
    variable constraints
    # Set/Reset multiple contraints at once.
    foreach name $list {
	if {[string match !* $name]} {
	    set name [string range $name 1 end]
	    catch {unset constraints($name)}
	} else {
	    set constraints($name) 1
	}
    }
    return [{*}$chain $tokens $index]
}

proc analyzer::checkSetConstraint {name chain tokens index} {
    variable constraints
    set constraints($name) 1
    return [{*}$chain $tokens $index]
}

proc analyzer::checkResetConstraint {name chain tokens index} {
    variable constraints
    catch {unset constraints($name)}
    return [{*}$chain $tokens $index]
}

proc analyzer::checkConstraint {guardtable default tokens index} {
    foreach guard $guardtable {
	lassign $guard cond action
	if {[MatchGuard $cond]} {
	    return [{*}$action $tokens $index]
	}
    }

    if {[llength $default]} {
	return [{*}$default $tokens $index]
    }

    return $index
}

proc analyzer::checkConstraintAll {guardtable chain tokens index} {
    set last $index
    foreach guard $guardtable {
	lassign $guard cond action
	if {[MatchGuard $cond]} {
	    set last [{*}$action $tokens $index]
	}
    }
    if {[llength $chain]} {
	return [{*}$chain $tokens $index]
    } else {
	return $last
    }
}

proc analyzer::MatchGuard {cond} {
    variable constraints

    set match 0
    if {[regexp {[^.:_a-zA-Z0-9 \n\r\t]+} $cond] != 0} {
	# something like {a || b} should be turned into
	# [MGF a] || [MGF b].
	regsub -all {[.\w]+} $cond {[MGF {&}]} c
	catch {set match [eval expr $c]}
    } elseif {![catch {llength $cond}]} {
	# just simple constraints such as {unixOnly fonts}.
	set match 1
	foreach flag $cond {
	    if {[MGF $flag]} continue
	    set match 0
	    break
	}
    }
    return $match
}

proc analyzer::MGF {flag} {
    variable constraints
    expr {[info exists constraints($flag)] && $constraints($flag)}
}

#
# ----------------------------------------------------------------------------
#

#
# -- == ** Helper commands for handling tokens and their substructure ** == --
#

# Definition:      token = [list type range [list token ...]]
#                  range = [list start_offset size]

# Acessors required for
# - type
# - range
# - subtokens (derived #subtokens)
# - translation into original string of the token

# range acessor already defined, s.a. "analyzer::getTokenRange"

# Constructors required for ranges and tokens, and token lists.
# Debugging help: Dump of tokens and token lists ...

#
# ----------------------------------------------------------------------------
#

# analyzer::getTokenType --
#
#	Extract the token's type from the token structure.
#
# Arguments:
#	token	A token list.
#
# Results:
#	Returns the type of the token.

proc analyzer::getTokenType {token} {
    return [lindex $token 0]
}

# analyzer::getTokenChildren --
#
#	Extract the token's child tokens from the token structure.
#
# Arguments:
#	token	A token list.
#
# Results:
#	Returns the children of the token.

proc analyzer::getTokenChildren {token} {
    return [lindex $token 2]
}

# analyzer::getTokenNumChildren --
#
#	Extract the number of child tokens from the token structure.
#
# Arguments:
#	token	A token list.
#
# Results:
#	Returns the number of children of the token.

proc analyzer::getTokenNumChildren {token} {
    return [llength [getTokenChildren $token]]
}

# analyzer::getTokenString --
#
#	Extract the token's string rep from the token structure.
#
# Arguments:
#	token	A token list.
#
# Results:
#	Returns the string rep of the token.

proc analyzer::getTokenString {token} {
    variable script
    return [getString $script [getTokenRange $token]]
}

# getCmdString ...
# A list containing the strings the command is made out of. Each
# element contains a word of the command. The inter-word whitespace is
# ignored, we generate something when the modified words are joined
# into a full corrected command. Trying to keep the whitespace as is
# is way to much work.

proc analyzer::getCmdStringList {tokens} {
    variable script
    foreach t $tokens n [linsert [lrange $tokens 1 end] end {}] {
	lappend res [getTokenString $t]
    }
    return $res
}

#
# ----------------------------------------------------------------------------
# wip like processor with a mini language for the specification of corrections
# through operations on the command list derived from the tokens.

proc analyzer::CorrectionsOf {auto tokens args} {
    # Do not spend time on generating correction proposals when the
    # backend writing the messages will not use them anyway.
    if {!$configure::machine} { return {} }

    # State, accessible via upvar
    array set state {}
    if {[llength $tokens]} {
	set state(tocorrect)   [getCmdStringList $tokens]
	set state(indentation) [string repeat { } [getIndentation [getTokenRange [lindex $tokens 0]]]]
    } else {
	set state(tocorrect)   {}
	set state(indentation) ""
    }
    set state(corrections) {}
    set state(current)     $state(tocorrect)
    set state(indent) 0 ; # No indentation for braces

    #puts ****************************************************\t<$args>\n

    Correct|Run $args

    #puts \n

    set res {}
    if {[llength $state(corrections)]} {
	# Squash devel auto marker if it cannot be true.
	if {$auto && ([llength $state(corrections)] > 1)} {
	    set auto 0
	}

	set res [list \
		     suggestedCorrections [lsort -unique $state(corrections)] \
		     autoCorrectable $auto]
    }
    return $res
}

proc analyzer::Correct|Run {words} {Correct/State
    while {[llength $words]} {
	set cmd   [lindex $words 0]
	set words [lrange $words 1 end]

	#puts ====================================================/$cmd\t<$words>
	#parray state

	set words [Correct/$cmd {*}$words]

	#puts >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	#parray state
	#puts ====================================================
    }
    return
}

proc analyzer::Correct/State {} {
    uplevel 1 {upvar 1 state state}
}

proc analyzer::Correct/save {args} {Correct/State
    if {[llength $state(current)]} {
	lappend state(corrections) [join $state(current) { }]
    }
    set state(current) $state(tocorrect)
    return $args
}

proc analyzer::Correct/insert {at text args} {Correct/State
    set state(current) [linsert $state(current) $at $text]
    return $args
}

proc analyzer::Correct/inserts {at words args} {Correct/State
    set state(current) [linsert $state(current) $at {*}$words]
    return $args
}

proc analyzer::Correct/lset {at text args} {Correct/State
    lset state(current) $at $text
    return $args
}

proc analyzer::Correct/ldrop {at args} {Correct/State
    set state(current) [lreplace $state(current) $at $at]
    return $args
}

proc analyzer::Correct/ldropall {args} {Correct/State
    set state(current) {}
    return $args
}

proc analyzer::Correct/ifempty {words args} {Correct/State
    if {![llength $state(current)]} {
	Correct|Run $words
    }
    return $args
}

proc analyzer::Correct/iflen {op n words args} {Correct/State
    if {[expr [llength $state(current)] $op $n]} {
	Correct|Run $words
    }
    return $args
}

proc analyzer::Correct/iflenorig {op n words args} {Correct/State
    if {[expr [llength $state(tocorrect)] $op $n]} {
	Correct|Run $words
    }
    return $args
}

proc analyzer::Correct/label {at label args} {Correct/State
    set state(l,$label) $at
    return $args
}

proc analyzer::Correct/l++ {label n args} {Correct/State
    incr state(l,$label) $n
    return $args
}

proc analyzer::Correct/at {label cmd args} {Correct/State
    set at $state(l,$label)
    # No need for recursion. Outer handler simply gets a modified
    # program.
    return [list $cmd $at {*}$args]
}

proc analyzer::Correct/comment {text args} {Correct/State
    return $args
}

proc analyzer::Correct/ldropto {at args} {Correct/State
    incr at
    set state(current) [lrange $state(current) $at end]
    return $args
}

proc analyzer::Correct/+ {words args} {Correct/State
    lappend state(current) {*}$words
    return $args
}

proc analyzer::Correct/indent! {enable args} {Correct/State
    set state(indent) $enable
    return $args
}

proc analyzer::Correct/indent= {n args} {Correct/State
    set state(indentation) [string repeat { } $n]
    return $args
}

proc analyzer::Correct/newline {args} {Correct/State
    set cmd [lindex $state(current) 0]
    set cmd "\n$cmd"
    lset state(current) 0 $cmd
    return $args
}

proc analyzer::Correct/+indent {n args} {Correct/State
    set cmd [lindex $state(current) 0]
    if {$n eq ""} {
	set indent $state(indentation)
    } else {
	set indent [string repeat { } $n]
    }
    set cmd "$indent$cmd"
    lset state(current) 0 $cmd
    return $args
}


proc analyzer::Correct/braces {s e args} {Correct/State
    # post/pre brace strings.
    if {$state(indent)} {
	set post "\n$state(indentation)    ";#indent+4 after
	set pre  "$state(indentation)\n";#indent before
    } else {
	set post ""
	set pre  ""
    }
    set previous  [lrange $state(current) 0 ${s}-1]
    set last      [lrange $state(current) ${e}+1 end]
    # Bug 80545: Trim double-quotes before adding the braces around
    # the words, to make it a proper replacement. Only if a single
    # word is handled.
    if {$s == $e} {
	set middle [string trim [lindex $state(current) $s] \"]
    } else {
	set middle [join [lrange $state(current) $s $e] { }]
    }
    set middle    \{$post$middle$pre\}
    set state(current) [list {*}$previous $middle {*}$last]
    return $args
}

proc analyzer::Correct/parens {s e args} {Correct/State
    # post/pre parentheses
    if {$state(indent)} {
	set post "\n$state(indentation)    ";#indent+4 after
	set pre  "$state(indentation)\n";#indent before
    } else {
	set post ""
	set pre  ""
    }
    set previous  [lrange $state(current) 0 ${s}-1]
    set last      [lrange $state(current) ${e}+1 end]
    # Bug 80545: Trim double-quotes and braces before adding the parens around
    # the words, to make it a proper replacement. Only if a single
    # word is handled.
    if {$s == $e} {
	set middle [string trim [lindex $state(current) $s] \"\{\}]
    } else {
	set middle [join [lrange $state(current) $s $e] { }]
    }

    set middle    ($post$middle$pre)
    set state(current) [list {*}$previous $middle {*}$last]
    return $args
}

proc analyzer::Correct/brackets {s e args} {Correct/State
    set previous  [lrange $state(current) 0 ${s}-1]
    set last      [lrange $state(current) ${e}+1 end]
    set middle    \[[join [lrange $state(current) $s $e] { }]\]
    set state(current) [list {*}$previous $middle {*}$last]
    return $args
}

proc analyzer::Correct/get {at args} {Correct/State
    set word [lindex $state(current) $at]
    if {[string index $word 0] eq "\{"} {
	set state(quote) brace
	set state(word) [string range $word 1 end-1]
    } elseif {[string index $word 0] eq "\{"} {
	set state(quote) apo
	set state(word) [string range $word 1 end-1]
    } else {
	set state(quote) {}
	set state(word) $word
    }
    return $args
}

proc analyzer::Correct/wunquote {args} {Correct/State
    set state(quote) {}
    return $args
}

proc analyzer::Correct/wapoquote {args} {Correct/State
    set state(quote) apo
    return $args
}

proc analyzer::Correct/wbracequote {args} {Correct/State
    set state(quote) brace
    return $args
}

proc analyzer::Correct/replace {at args} {Correct/State
    switch -exact -- $state(quote) {
	brace { set s "\{" ; set e "\}" }
	apo   { set s "\"" ; set e "\"" }
	{}    { set s [set e {}] }
    }

    lset  state(current) $at $s$state(word)$e
    unset state(word)
    return $args
}

proc analyzer::Correct/insert-w {at args} {Correct/State
    set state(current) [linsert $state(current) $at $state(word)]
    unset state(word)
    return $args
}


# word operations, assuming that the word is a list.
proc analyzer::Correct/drop {at args} {Correct/State
    set state(word) [lreplace $state(word) $at $at]
    return $args
}

proc analyzer::Correct/w* {by args} {Correct/State
    set state(word) [expr {$state(word) * $by}]
    return $args
}

proc analyzer::Correct/wregsub {pattern rep args} {Correct/State
    set state(word) [regsub -all $pattern $state(word) $rep]
    return $args
}

proc analyzer::Correct/wstrinsert {at text args} {Correct/State
    set state(word) [string range $state(word) 0 ${at}-1]${text}[string range $state(word) ${at} end]
    return $args
}

proc analyzer::Correct/wstrreplace {at len text args} {Correct/State
    set state(word) [string replace $state(word) $at [expr {$at+$len-1}] $text]
    return $args
}

proc analyzer::Correct/wstrlow {at args} {Correct/State
    set state(word) [string tolower $state(word) $at $at]
    return $args
}

proc analyzer::Correct/wmap {map args} {Correct/State
    set state(word) [string map $map $state(word)]
    return $args
}

proc analyzer::Correct/wtrimr {args} {Correct/State
    set state(word) [string trimright $state(word)]
    return $args
}

proc analyzer::Correct/wtriml {args} {Correct/State
    set state(word) [string trimleft $state(word)]
    return $args
}

proc analyzer::Correct/wtrim/ {set args} {Correct/State
    set state(word) [string trim $state(word) $set]
    return $args
}

proc analyzer::Correct/wsplit {by args} {Correct/State
    set state(word) [split $state(word) $by]
    return $args
}

proc analyzer::Correct/wjoin {by args} {Correct/State
    set state(word) [join $state(word) $by]
    return $args
}

proc analyzer::Correct/winsert {at words args} {Correct/State
    set state(word) [linsert $state(word) $at {*}$words]
    return $args
}

proc analyzer::Correct/dropafter {at args} {Correct/State
    set state(word) [lrange $state(word) 0 $at]
    return $args
}

proc analyzer::Correct/dropafterx {n args} {Correct/State
    set indices [lrange $args 0 ${n}-1]
    set args    [lrange $args $n end]

    set where [lrange $indices 0 end-1]
    set after [lindex $indices end]

    lset state(word) {*}$where [lrange [lindex $state(word) {*}$where] 0 $after]
    return $args
}

proc analyzer::Correct/movetoend {at args} {Correct/State
    set state(word) [linsert [lreplace $state(word) $at $at] end [lindex $state(word) $at]]
    return $args
}

# ----------------------------------------------------------------------------
# Dump a token, with an indentation level, into a string.

proc analyzer::dumpToken {token {my {}} {chld {}} {lchld {}}} {

    #::log::log debug "($my)($chld)($lchld)"

    set type     [getTokenType     $token]
    set range    [getTokenRange    $token]
    set string   [getTokenString   $token]
    set children [getTokenChildren $token]

    set lines [list]
    lappend lines "$my $type ($range) = $string"

    if {[llength $children] == 1} {
	lappend lines [dumpToken [lindex $children end] "$lchld +- " "$lchld |  " "$lchld    "]
    } elseif {[llength $children] > 1} {
	foreach c [lrange $children 0 end-1] {
	    lappend lines [dumpToken $c "$chld +- " "$chld |  " "$lchld    "]
	}
	lappend lines [dumpToken [lindex $children end] "$lchld +- " "$lchld |  " "$lchld    "]
    }
    return [join $lines \n]
}



#############################################################
# Scan commands for tracking variable definitions and usage.
# Note: 'index == 0' always, because this is called for the
# whole command.

proc analyzer::scanTrackSetVariable {tokens index} {
    variable script
    ## return [checkCommand $tokens $index] ; ## 3.0 FEATURE OFF

    #::log::log debug scanTrackSetVariable_____________________________

    # Document "TDK_3.0_Checker_Xref_Var.txt"
    # Section: I.

    #::log::log debug "scanTrackSetVariable /[llength $tokens]"

    # Skip over 'set x', these are variable usages, not definitions.

    if {[llength $tokens] != 3} {
	#::log::log debug scanTrackSetVariable@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@/1

	return [checkCommand $tokens $index]
    }

    lassign [context::topScope] type name loc

    #::log::log debug "scanTrackSetVariable /$type/$name"

    set varword [lindex $tokens 1]

    #::log::log debug scanTrackSetVariable///($varword)///WORD///[getString $script [getTokenRange $varword]] <=> !!getTokenString!!
    #::log::log debug scanTrackSetVariable///NC/[getTokenNumChildren $varword]
    if 0 {
	foreach c  [getTokenChildren $varword] {
	    #::log::log debug scanTrackSetVariable///NC/($c)
	}
    }

    if {[getLiteral $varword varname]} {
	#::log::log debug scanTrackSetVariable/LiteralVarname

	TrackDefVariable $type $varname [getTokenRange $varword]

	# Varname is array subscript. Handle the stem too.
	if {[regexp -- {^([^(]*)\(.*\)$$} $varname -> stem]} {

	    #::log::log debug scanTrackSetVariable///STEM///$stem

	    TrackDefVariable $type $stem [getTokenRange $varword]
	}
    } elseif {[getTokenNumChildren $varword] > 1} {
	# Array access, or constructed variable name. First and
	# last children have to be literals, and together match
	# 'foo()' for this to be an array access. And while the
	# whole word is not a literal, the first word, the stem,
	# might still be.

	set vchildren [getTokenChildren $varword]
	if {
	    ("text" eq [getTokenType [lindex $vchildren   0]]) &&
	    ("text" eq [getTokenType [lindex $vchildren end]])
	} {
	    # NOTE: getString/getTokenRange is getTokenString, do getTokenChildren once
	    set    base [getString $script [getTokenRange [lindex $vchildren   0]]]
	    append base [getString $script [getTokenRange [lindex $vchildren end]]]

	    #::log::log debug " $base"
	    # The base may contain fixed text after the opening '('. We ignore this.

	    if {[regexp -- {^([^(]*)\(.*\)$} $base -> varname]} {
		#::log::log debug scanTrackSetVariable/LiteralStem/$varname

		TrackDefVariable $type $varname [getTokenRange $varword]
	    }
	}
    }

    #::log::log debug scanTrackSetVariable@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@/2
    return [checkCommand $tokens $index]
}


proc analyzer::TrackDefVariable {type varname range} {
    if {$type eq "namespace"} {
	# I.ii.a | Scan 'set' only when in a namespace ...
	#        | Ignore all commands which do not have
	#        | two arguments. We need a literal value
	#        | for the name of the variable written to.

	# Absolute path to variable ?

	#::log::log debug "scanTrackSetVariable => NS ($varname) /[getLocation]"

	set id [VarNameToId $varname deftype]
	xref::varDefAt local $id

	if {$deftype eq "relative"} {
	    # Issue a defered warning if there is a global
	    # variable of the same name, and we are not at
	    # the global scope.

	    #::log::log debug "scanTrackSetVariable => NS/relative ($varname)"
	    #::log::log debug "scanTrackSetVariable [context::topScope]"
	    #::log::log debug "scanTrackSetVariable [context::globalScope]"

	    if {
		([context::topScope] ne [context::globalScope]) &&
		[xref::varDefinedAt [xref::varIdAt [context::globalScope] $varname] _dummy_]
	    } {
		logError warnGlobalVarColl $range $varname
	    }
	}
    }

    if {$type eq "proc" || $type eq "apply"} {
	# Even for a proc context we have to create some defines in
	# the scan phase, i.e. if the variable is namespaced in any way.
	# Note: A relative path may cause a definition too, if the
	# variable is imported from a namespace. In that case we add
	# definitions to the origin variable ...

	# Absolute path to variable ?

	#::log::log debug "scanTrackSetVariable => PROC ($varname)"

	set id [VarNameToId $varname deftype]

	if {$deftype eq "relative"} {
	    # Relative path. Check if we have an 'imported'
	    # definition for it. If yes, add a definition
	    # for the origin variable using the current
	    # location ...

	    if {[xref::varDefined $varname defs]} {
		foreach d $defs {
		    array set _ $d
		    if {
			$_(type)  eq "imported" &&
			"UNKNOWN" ne  $_(origin) &&
			![string match RESOLVE* $_(origin)]
		    } {
			# We have to propagate this location
			# as definition of the imported
			# variable. ... Closure !!
			# Ignore everything where we don't know the exact origin.
			xref::varDefAtClosure exported $_(origin)
		    }
		    unset _
		}
	    }

	    # Check for existence of a previous definition depends
	    # on the line number (order), for a first approximation.
	    # We need the definition for 'upvar' resolution over callers ...
	}

	xref::varDefAt local $id
    }
}


proc analyzer::scanTrackVariable {tokens index} {
    ## return [checkCommand $tokens $index] ; ## 3.0 FEATURE OFF

    #::log::log debug scanTrackVariable

    # Document "TDK_3.0_Checker_Xref_Var.txt"
    # Section: II.

    foreach {vartoken value} [lrange $tokens 1 end] {

	if {[getLiteral $vartoken varname]} {
	    #::log::log debug "scanTrackVariable => ($varname)"

	    lassign [context::topScope] type name loc

	    if {$type eq "proc" || $type eq "namespace" || $type eq "apply"} {
		# proc or namespace ...

		# II.i.a  | Define imported variables ...
		#         | The difference is in the origin ...

		#::log::log debug "scanTrackVariable => local ([namespace tail $varname])"

		set vid          [VarNameToId $varname deftype]
		set localVarname [namespace tail $varname]

		if {$deftype eq "absolute"} {
		    # Absolute path, origin scope is the named namespace.

		    #::log::log debug "scanTrackVariable => abs origin ($vid)"

		    xref::varDef imported $localVarname \
			origin $vid

		    # Define origin in its scope as well.
		    xref::varDefAt local $vid

		} else {
		    # Relative or qualified path, make absolute using the
		    # namespace execution context for the proc
		    # we are in, and then generate the id for that.

		    if {$type eq "namespace"} {
			# For a namespace this means that it is a local variable.

			xref::varDef local $localVarname
		    } else {
			#::log::log debug "scanTrackVariable => abs ([context::join [context::top] $varname])"

			set origin [xref::varIdAbsolute \
					[context::join [context::top] $varname]]

			#::log::log debug "scanTrackVariable => rel origin ($origin)"

			xref::varDef imported $localVarname \
			    origin $origin

			# Define origin in its scope as well.
			xref::varDefAt local $origin
		    }
		}

		if {$type eq "namespace"} {
		    # II.ii.a | Issue a defered warning if a local
		    #         | definition is already present.

		    xref::varDefined $localVarname definitions
		    # We know that at least one is present.
		    # Because we just created it. If there
		    # are more we have shadowing and redefinition.

		    if {[llength $definitions] > 1} {
			logError warnShadowVar [getTokenRange [lindex $tokens 1]] $varname
		    }
		}
	    }
	} elseif {[getLiteralTail [lindex $tokens 1] varname]} {
	    set varname [namespace tail $varname]

	    #::log::log debug "scanTrackVariable => ($varname)"

	    lassign [context::topScope] type name loc
	    if {$type eq "proc" || $type eq "apply" || $type eq "namespace"} {
		# proc (named or anon) or namespace ...

		# II.i.a  | Define imported variables ...
		#         | The difference is in the origin ...

		#::log::log debug "scanTrackVariable => local ([namespace tail $varname])"

		set vid          [VarNameToId $varname deftype]
		set localVarname $varname

		if {$deftype eq "absolute"} {
		    #::log::log debug "scanTrackVariable => abs origin ($vid)"

		    return -code error "Tail cannot be absolute."
		}

		# Relative or qualified path, make absolute using the
		# namespace execution context for the proc
		# we are in, and then generate the id for that.

		if {$type eq "namespace"} {
		    # For a namespace this means that it is a local variable.

		    xref::varDef local $localVarname
		} else {
		    #::log::log debug "scanTrackVariable => rel origin ($origin)"

		    xref::varDef imported $localVarname \
			origin UNKNOWN
		}

		if {$type eq "namespace"} {
		    # II.ii.a | Issue a defered warning if a local
		    #         | definition is already present.

		    xref::varDefined $localVarname definitions
		    # We know that at least one is present.
		    # Because we just created it. If there
		    # are more we have shadowing and redefinition.

		    if {[llength $definitions] > 1} {
			logError warnShadowVar [getTokenRange [lindex $tokens 1]] $varname
		    }
		}
	    }
	}
    }

    return [checkCommand $tokens $index]
}


proc analyzer::scanTrackGlobal {tokens index} {
    ## return [checkCommand $tokens $index] ; ## 3.0 FEATURE OFF

    #::log::log debug scanTrackGlobal

    # Document "TDK_3.0_Checker_Xref_Var.txt"
    # Section: III.

    lassign [context::topScope] type name loc
    if {$type eq "proc" || $type eq "apply"} {
	# III.i.a. | Import, like for variable, except that
	#          | relative paths are anchored in ::.
	#          | Also have to do it for all words after
	#          | the command.

	foreach word [lrange $tokens 1 end] {
	    if {[getLiteral $word varname]} {
		# Make relative varnames absolute,
		# anchored in global namespace.

		if {![regexp {^::} $varname]} {
		    set varname ::$varname
		}
		xref::varDef imported [namespace tail $varname] \
			origin [xref::varIdAbsolute $varname]

		if {![isTwoPass]} {
		    # One-pass mode. Do immediate export of the
		    # variable definition to the global namespace,
		    # ensure that it is visible at least after this
		    # proc.

		    xref::varDefAt local \
			    [xref::varIdAbsolute $varname]
		}
	    }
	}
    }
    return [checkCommand $tokens $index]
}


proc analyzer::scanTrackUpvar {tokens index} {
    ## return [checkCommand $tokens $index] ; ## 3.0 FEATURE OFF

    #::log::log debug scanTrackUpvar

    # Document "TDK_3.0_Checker_Xref_Var.txt"
    # Section: IV.

    # If there are odd numbers of arguments, assume that the first argument
    # is a level. == even number of words in the whole command.

    # Values for level obtained:
    # empty string  - unable to get this information.
    # 'global'      - #0
    # 'absolute'    - #something
    # <number>      - relative level

    # Bug 82058. The 'index' this procedure is called with is always
    # '1', regardless of context. See coreTcl.tcl for the relevant
    # notes. This means the index points to either the level argument
    # if such is present, or the name of the first variable to be
    # imported.

    set idx $index
    set argc [expr {[llength $tokens] - 1}]

    #puts scan-track-upvar|$idx|[llength $tokens]|

    if {([llength $tokens] % 2) == 0} {
	# Bug 82058. Given the definition of 'index' above there is
	# no need to adjust it backward.

	#::log::log debug "scanTrackUpvar - has level"

	set word [lindex $tokens $idx]
	if {[getLiteral $word level]} {

	    #::log::log debug "scanTrackUpvar - has level ($level)"

	    if {[string match "#*" $level]} {
		set level [string range $level 1 end]
		if {![string is integer -strict $level]} {
		    set level {}
		} elseif {$level == 0} {
		    set level global
		} else {
		    set level absolute
		}
	    } else {
		if {![string is integer -strict $level]} {
		    set level {}
		}
	    }
	    incr idx
	} else {
	    set level {}
	}
    } else {
	# No level specified, default is (relative '1').
	set level 1
    }

    #::log::log debug "scanTrackUpvar - has final level ($level)"

    # Distinguish between namespace and proc scopes ...

    lassign [context::topScope] type name loc

    if {$type eq "proc" || $type eq "apply"} {
	# IV.i.a. - proc (possibly anon)
	# To deduce an origin we remember the level and origvar.

	#::log::log debug "scanTrackUpvar - in proc ($name)"

	foreach {origvar newvar} [lrange $tokens $idx end] {
	    # newvar has to be literal for the tracker to work.

	    if {[getLiteral $newvar newname]} {
		# If origvar is not a literal the origin is simply
		# unknown, but the main stuff works.

		#::log::log debug "scanTrackUpvar - new name: ($newname)"

		if {[getLiteral $origvar origname]} {
		    # Now the level comes into play.

		    #::log::log debug "scanTrackUpvar - origin ($origname)"

		    if {$level eq "" || $level eq "absolute"} {
			# We can't determine the origin.
			set origin UNKNOWN
		    } elseif {$level eq "global"} {
			# Make relative varnames absolute, anchored in global namespace.

			if {![regexp {^::} $origname]} {
			    set origname ::$origname
			}
			set origin [xref::varIdAbsolute $origname]
		    } else {
			# Relative level ... remember for
			# possible resolution in analysis
			# phase
			set origin [list RESOLVE $level $origname]
		    }
		} else {
		    set origin UNKNOWN
		}

		#::log::log debug "scanTrackUpvar - import ($newname) from origin ($origin)"

		xref::varDef imported $newname origin $origin
	    }
	}

    } elseif {$type eq "namespace"} {
	# IV.ii.a - namespace
	# Only a level 'global' is of relevance.
	# Everything else is ignored.

	#::log::log debug "scanTrackUpvar - in namespace ($name)"

	if {$level eq "global"} {
	    foreach {origvar newvar} [lrange $tokens $idx end] {
		# newvar has to be literal for the tracker to work.

		if {[getLiteral $newvar newname]} {
		    # If origvar is not a literal the origin is simply
		    # unknown, but the main stuff works.

		    if {[getLiteral $origvar origname]} {
			# Make relative varnames absolute, anchored in global namespace.

			if {![regexp {^::} $origname]} {
			    set origname ::$origname
			}
			set origin [xref::varIdAbsolute $origname]
		    } else {
			set origin UNKNOWN
		    }

		    xref::varDef imported $newname origin $origin
		}
	    }
	}
    }

    return [checkCommand $tokens $index]
}


proc analyzer::trackVariable {tokens index} {
    ## return ; ## 3.0 FEATURE OFF

    #::log::log debug aTrackVariable

    # Document "TDK_3.0_Checker_Xref_Var.txt"
    # Section: II.

    foreach {vartoken value} [lrange $tokens 1 end] {

	if {[getLiteral $vartoken varname]} {

	    #::log::log debug "aTrackVariable => ($varname)"

	    lassign [context::topScope] type name loc
	    if {$type eq "proc" || $type eq "apply" || $type eq "namespace"} {
		# proc (possibly anon) or namespace ...

		# II.i.a  | Define imported variables ...
		#         | The difference is in the origin ...

		#::log::log debug "aTrackVariable => local ([namespace tail $varname])"

		if {[regexp {^::} $varname]} {
		    # Absolute path, origin scope is the named namespace.
		    set origin [xref::varIdAbsolute $varname]

		    #::log::log debug "aTrackVariable => abs origin ($origin)"

		    if {![xref::varDefinedAt $origin defs]} {
			logError warnUndefinedVar [getTokenRange [lindex $tokens 1]] $varname
		    }

		} else {
		    if {![xref::varDefined [namespace tail $varname] defs]} {
			logError warnUndefinedVar [getTokenRange [lindex $tokens 1]] $varname
		    }
		}

		if {$type eq "proc" || $type eq "apply"} {
		    # Now look for the variable def in the current scope
		    # and check if there are definitions we are shadowing.
		    # This is restricted to procedures.

		    if {[xref::varDefined [namespace tail $varname] defs]} {

			#::log::log debug "aTrackVariable => ($varname) /locate shadowed"

			foreach d $defs {
			    array set _ $d
			    set line [lindex $_(loc) 1]
			    unset _
			    if {$line < [getLine]} {
				# We have a previous definition.
				logError warnShadowVar [getTokenRange [lindex $tokens 1]] [namespace tail $varname]
				break
			    }
			}
		    }
		}

		if {[llength $tokens] == 3} {
		    # variable foo [...] --  This is also a usage !!
		    xref::varUse [namespace tail $varname]
		}
	    }

	} elseif {
		  [getLiteralTail [lindex $tokens 1] vartail] &&
		  [regexp {::} $vartail]
	      } {
	    # The variable name is not full literal, but parts of it
	    # may be. Here we are interested if the trailing part is
	    # a literal, and it is. Because if that is true, and we
	    # find a full '::' in it (also true), then we can determine
	    # the namespace tail, and this gives us a literal for the
	    # local name of the variable in question. IOW while we
	    # don't know for sure where the variable is coming from we
	    # do know what it is named locally, and can define it. Thus
	    # enabling more local checks, i.e. reducing the number of
	    # reports cascading from here.

	    lassign [context::topScope] type name loc
	    set vartail [namespace tail $vartail]

	    if {$type eq "proc" || $type eq "apply" || $type eq "namespace"} {
		# proc (possibly anon) or namespace ...

		# II.i.a  | Define imported variables ...
		#         | The difference is in the origin ...

		#::log::log debug "aTrackVariable => local $vartail"

		if {![xref::varDefined [namespace tail $vartail] defs]} {
		    logError warnUndefinedVar [getTokenRange [lindex $tokens 1]] $vartail
		}

		if {$type eq "proc" || $type eq "apply"} {
		    # Now look for the variable def in the current scope
		    # and check if there are definitions we are shadowing.
		    # This is restricted to procedures.

		    if {[xref::varDefined $vartail defs]} {

			#::log::log debug "aTrackVariable => ($vartail) /locate shadowed"

			foreach d $defs {
			    array set _ $d
			    set line [lindex $_(loc) 1]
			    unset _
			    if {$line < [getLine]} {
				# We have a previous definition.
				logError warnShadowVar [getTokenRange [lindex $tokens 1]] $vartail
				break
			    }
			}
		    }
		}

		if {[llength $tokens] == 3} {
		    # variable foo [...] --  This is also a usage !!
		    xref::varUse [namespace tail $vartail]
		}
	    }
	}
    }
    return
}

proc analyzer::trackGlobal {chain tokens index} {
    ## return [eval $chain [list $tokens $index]] ; ## 3.0 FEATURE OFF

    #::log::log debug aTrackGlobal

    # Document "TDK_3.0_Checker_Xref_Var.txt"
    # Section: III.

    lassign [context::topScope] type name loc
    if {$type eq "proc" || $type eq "apply"} {
	# III.i.a. | Import, like for variable, except that
	#          | relative paths are anchored in ::.
	#          | Also have to do it for all words after
	#          | the command.

	foreach word [lrange $tokens 1 end] {
	    if {[getLiteral $word varname]} {
		# Make relative varnames absolute,
		# anchored in global namespace.

		if {![regexp {^::} $varname]} {
		    set varname ::$varname
		}
		if {![xref::varDefined [namespace tail $varname] defs]} {
		    logError warnUndefinedVar [getTokenRange $word] $varname
		} else {
		    foreach d $defs {
			array set _ $d
			set line [lindex $_(loc) 1]
			unset _
			if {$line < [getLine]} {
			    # We have a previous definition.
			    logError warnShadowVar [getTokenRange $word] [namespace tail $varname]
			    break
			}
		    }
		}
	    }
	}
    } elseif {$type eq "namespace"} {
	if {[context::sizeScope] > 1} {
	    # No global scope. For the global scope it makes sense.
	    logError warnGlobalNsNonsense [getTokenRange [lindex $tokens 0]]
	}
    }
    return [{*}$chain $tokens $index]
}


proc analyzer::trackUpvar {tokens index} {
    ## return ; ## 3.0 FEATURE OFF

    #::log::log debug aTrackUpvar

    # Document "TDK_3.0_Checker_Xref_Var.txt"
    # Section: IV.

    # If there are odd numbers of arguments, assume that the first argument
    # is a level. == even number of words in the whole command.

    # Values for level obtained:
    # empty string  - unable to get this information.
    # 'global'      - #0
    # 'absolute'    - #something
    # <number>      - relative level

    # Bug 82058. The absolute 'index' this procedure is called with
    # changes depending on the presence of a level argument or
    # not. Its relative position is always the name of the first
    # variable to be imported. See coreTcl.tcl for the relevant notes.

    set idx $index
    set argc [expr {[llength $tokens] - 1}]

    #puts track-upvar|$idx|[llength $tokens]|

    if {([llength $tokens] % 2) == 0} {
	# Bug 82058. Given the definition of the 'index' above we have
	# to adjust it to refer to the 'level' token.
	incr idx -1

	#::log::log debug "aTrackUpvar - has level"

	set word [lindex $tokens $idx]
	if {[getLiteral $word level]} {

	    #::log::log debug "aTrackUpvar - has level ($level)"

	    if {[string match "#*" $level]} {
		set level [string range $level 1 end]
		if {![string is integer -strict $level]} {
		    set level {}
		} elseif {$level == 0} {
		    set level global
		} else {
		    set level absolute
		}
	    } else {
		if {![string is integer -strict $level]} {
		    set level {}
		}
	    }
	    incr idx
	} else {
	    set level {}
	}
    } else {
	# No level specified, default is (relative '1').
	set level 1
    }

    #::log::log debug "aTrackUpvar - has final level ($level)"

    # Distinguish between namespace and proc scopes ...

    lassign [context::topScope] type scopename loc

    if {$type eq "proc" || $type eq "apply"} {
	# IV.i.a. - proc
	# To deduce an origin we remember the level and origvar.

	#::log::log debug "aTrackUpvar - in proc ($scopename)"

	foreach {origvar newvar} [lrange $tokens $idx end] {
	    # newvar check only if a literal, look for previous
	    # definition we may now shadow.

	    if {[getLiteral $newvar newname]} {
		#::log::log debug "aTrackUpvar - new name: ($newname) /locate shadowed"

		if {[xref::varDefined $newname defs]} {
		    foreach d $defs {
			array set _ $d
			set line [lindex $_(loc) 1]
			unset _
			if {$line < [getLine]} {
			    # We have a previous definition.
			    logError warnShadowVar [getTokenRange $newvar] $newname
			    break
			}
		    }
		}
	    }

	    # If origvar is not a literal the origin is simply
	    # unknown, but the main stuff works.

	    if {[getLiteral $origvar origname]} {
		# Now the level comes into play.

		#::log::log debug "aTrackUpvar - origin ($origname)"

		if {$level eq "" || $level eq "absolute"} {
		    #::log::log debug "aTrackUpvar - ignore ($level)"
		    # Ignore. Resolving this case is not possible for us.
		} elseif {$level eq "global"} {
		    #::log::log debug "aTrackUpvar - global"
		    # Make relative varnames absolute, anchored in global namespace.

		    if {![regexp {^::} $origname]} {
			set origname ::$origname
		    }
		    set origin [xref::varIdAbsolute $origname]

		    # Now we check if a definition is present.

		    if {![xref::varDefinedAt $origin defs]} {
			logError warnUndefinedVar [getTokenRange $origvar] $origname
		    }
		} else {
		    #::log::log debug "aTrackUpvar - ($level)"
		    # We know the procedure we are in. We now
		    # determine a list of all callers at the
		    # specified level and check that they have
		    # a definition of the variable ...

		    set callers [uproc::locateCallers $scopename $level]
		    set cscopes [uproc::locateScopes $callers]

		    #::log::log debug "aTrackUpvar - scopes = ($cscopes)"

		    foreach s $cscopes {
			# Check that the found calling scope
			# has a definition for the upvar'd
			# variable.

			if {![xref::varDefinedAt [xref::varIdAt $s $origname] defs]} {

			    #::log::log debug "aTrackUpvar - missing in caller scope"

			    logError warnUndefinedUpvar [getTokenRange $origvar] $origname [lindex $s 1]
			}
		    }

		    # If possible update the definition of
		    # 'newvar' with the caller data (scopes) ...

		    if {[llength $cscopes] && [getLiteral $newvar newname]} {
			xref::varUpdateUpvar $newname $level $origname $cscopes
		    }
		}
	    }
	}
    } elseif {$type eq "namespace"} {
	# IV.ii.a - namespace
	# Level 'global' - Check that 'a' is defined.
	# Level 'absolute' or number - Makes no sense.
	# We ignore commands where we cannot determine the level.

	#::log::log debug "aTrackUpvar - in namespace ($scopename)"

	if {$level eq "global"} {
	    foreach {origvar newvar} [lrange $tokens $idx end] {
		# newvar is irrelevant here and now.

		# If origvar is not a literal the origin is simply
		# unknown, but the main stuff works.

		if {[getLiteral $origvar origname]} {
		    # Make relative varnames absolute, anchored in global namespace.

		    if {![regexp {^::} $origname]} {
			set origname ::$origname
		    }
		    set origin [xref::varIdAbsolute $origname]

		    # Now we check if a definition is present.

		    if {![xref::varDefinedAt $origin defs]} {
			logError warnUndefinedVar [getTokenRange $origvar] $origname
		    }
		}
	    }
	} elseif {$level ne ""} {
	    # absolute, or relative (number)

	    logError warnUpvarNsNonsense [getTokenRange [lindex $tokens 1]]

	} ; # else : empty - unknown level. {}
    }

    return
}


############################################################
##
## Cross referencing, dumping the database.

proc analyzer::dumpXref {} {
    ## ##################################################
    ## Write the cross-reference database to stdout.
    ##
    ## i.   Files
    ## ii.  Namespaces (def & use)
    ## iii. Commands   (definitions, and usage)
    ## iv.  Variables  (definitions, and usage)
    ## v.   Packages   (defined by code, required external packages)

    ## ##################################################
    ## I.a	Get file information
    ## II.a	Get namespace definitions and usage
    ## III.a	Get command definitions and usage
    ## IV.a	Get variable definitions and usage
    ## V.a      Get defined and required packages

    #::log::log debug "#%% DXR/start [clock seconds] -- [clock format [clock seconds]]"

    foreach {f i}  [xref::files] {
	array set files $f
	array set fids $i
	unset f i
	break
    }
    foreach {d u}  [xref::nsget] {
	array set ndef $d
	array set nuse $u
	unset d u
	break
    }
    foreach {c u} [uproc::dump] {
	array set cmds $c
	array set use  $u
	unset c u
	break
    }
    foreach {v u} [xref::varget] {
	array set vdef $v
	array set vuse $u
	unset v u
	break
    }

    array set pdef [xref::pProvided]
    array set preq [xref::pRequired]

    #puts @@@@@@@@@@@@@@@@@@@@@
    #parray pdef
    #parray preq
    #puts @@@@@@@@@@@@@@@@@@@@@

    ## ##################################################

    #::log::log debug "#%% DXR/compl [clock seconds] -- [clock format [clock seconds]]"

    completeVars
    completeNamespaces

    ## ##################################################

    #::log::log debug "#%% DXR/dump  [clock seconds] -- [clock format [clock seconds]]"

    puts ""
    puts "## --- === <<<"
    puts ""

    dumpFiles
    dumpPackages
    dumpNamespaces
    dumpCommands
    dumpVariables

    ## ##################################################

    #::log::log debug "#%% DXR/done  [clock seconds] -- [clock format [clock seconds]]"
    ## ##################################################
    ## ... Done
    return
}


proc analyzer::completeVars {} {
    upvar 1 vdef vdef

    # We look for imported variables whose origin has no
    # definition. For these we add a definition which makes
    # it clear that there is no real definition in the code
    # (type = defined-through-import).

    foreach v [array names vdef] {
	foreach d $vdef($v) {
	    array set _ $d
	    if {$_(type) eq "imported"} {

		# Ignore the special origin indicators.
		if {[string match UNKNOWN* $_(origin)]} {continue}
		if {[string match RESOLVE* $_(origin)]} {continue}

		if {![info exists vdef($_(origin))]} {
		    lappend vdef($_(origin)) [list \
			    type defined-through-import \
			    loc {{} {} {{} {}}} \
			    scope {} \
			    ]
		}
	    }
	    unset _
	}
    }
    return
}


proc analyzer::completeNamespaces {} {
    upvar 1 vdef vdef ndef ndef cmd cmd

    # We look at namespace variables and check that their
    # namespace is defined. If that is not the case we add
    # a definition which makes it clear that there is no
    # real definition in the code (type = defined-through-import).

    foreach v [array names vdef] {
	lassign $v scope name
	lassign $scope type scopename _
	if {$type ne "namespace"} continue

	# Variable is for a namespace. Does it exist ?

	if {[info exists ndef($scopename)]} {continue}

	# No. Create a fake definition ...

	lappend ndef($scopename) [list \
		scope {} \
		loc {{} {} {{} {}}}
	]
    }

    # We also look at all commands and check that their
    # namespace is defined. If that is not the case we add
    # a definition which makes it clear that there is no
    # real definition in the code (type = defined-implicitly).

    foreach c [array names cmd] {
	foreach d $cmds($c) {
	    array set _ $d
	    if {[info exists ndef($_(scope))]} {continue}

	    # No. Create a fake definition ...

	    lappend ndef($_(scope)) [list \
		    scope {} \
		    loc {{} {} {{} {}}}
	    ]
	}
    }
    return
}


proc analyzer::dumpFiles {} {
    upvar 1 fids fids

    ## ##################################################
    ## I.b	Format and write files
    ##
    ##    file <id> {}
    ##        path <file>
    ##        ...
    ##    {}

    foreach id [lsort [array names fids]] {
	puts "file $id \{"
	foreach f [lsort $fids($id)] {
	    puts "    path  [list $f]"
	}
	puts "\}"
    }
    return
}

proc analyzer::dumpNamespaces {} {
    upvar 1 ndef ndef nuse nuse files files

    ## ##################################################
    ## II.b	Format and write namespaces
    ##
    ##    namespace <name> {}
    ##        definition {}
    ##            <data>
    ##        {}
    ##        ...
    ##        usage {}
    ##            <data>
    ##        {}
    ##        ...
    ##    {}

    foreach n [lsort [array names ndef]] {
	puts "namespace [list $n] \{"
	foreach item $ndef($n) {
	    array set _ $item
	    puts "    definition \{"
	    puts [dumpScope $_(scope) "        "]
	    puts [dumpLoc   $_(loc)   "        "]
	    puts "    \}"
	    unset _
	}
	if {[info exists nuse($n)]} {
	    foreach item $nuse($n) {
		array set _ $item
		puts "    usage \{"
		puts [dumpScope $_(scope) "        "]
		puts [dumpLoc   $_(loc)   "        "]
		puts "    \}"
		unset _
	    }
	}
	puts "\}"
    }
    # Namespace used, but not defined in the set of files scanned.
    foreach n [lsort [array names nuse]] {
	if {[info exists ndef($n)]} {continue}
	puts "namespace [list $n] \{"
	foreach item $nuse($n) {
	    array set _ $item
	    puts "    usage \{"
	    puts [dumpScope $_(scope) "        "]
	    puts [dumpLoc   $_(loc)   "        "]
	    puts "    \}"
	    unset _
	}
	puts "\}"
    }
    return
}

proc analyzer::commandDef {av} {
    upvar 1 $av _ cmds cmds files files

    set def {}

    # We ignore internal, redundant, and irrelevant information:
    # - checkcmd
    # - scancmd
    # - verifycmd
    # - name
    # - hasarg
    # - minargno
    # - maxargno

    # A definition context which is a command has to be a class. Else
    # it has to be a namespace.

    if {[info exists cmds($_(base))]} {
	set _(base) [list class $_(base)]
    } else {
	set _(base) [list namespace $_(base)]
    }

    lappend def "        type       [list $_(type)]"
    lappend def [dumpScope $_(base) "        "]

    if {[info exists _(origin)]} {
	lappend def "        origin     [list $_(origin)]"
    }

    if {[info exists _(package)]} {
	lappend def "        package    [list $_(package)]"
    }

    lappend def "        protection [list $_(protection)]"

    if {[info exists _(cmdrange)]} {
	set loc [list $_(file) $_(line) $_(cmdrange)]
    } else {
	set loc [list $_(file) $_(line) {{} {}}]
    }
    lappend def [dumpLoc  $loc "        "]

    return $def
}

proc analyzer::commandUse {av} {
    upvar 1 $av _ files files

    set     use {}
    lappend use [dumpScope $_(scope) "        "]
    lappend use [dumpLoc   $_(loc)   "        "]

    return $use
}

proc analyzer::dumpCommands {} {
    upvar 1 cmds cmds use use files files

    ## ##################################################
    ## III.b	Format and write commands
    ##		Note: Classes are commands (with attached namespace)
    ##
    ##    command <name> {}
    ##        definition {}
    ##            <data>
    ##        {}
    ##        ...
    ##        usage {}
    ##            <data>
    ##        {}
    ##        ...
    ##    {}

    foreach c [lsort [array names cmds]] {

	array set dupdef {}
	array set dupuse {}

	set hashead 0
	set builtin 1

	#puts "command [list $c] \{"
	foreach d $cmds($c) {

	    array set _ $d
	    if {$_(type) eq "builtin"} {
		unset _
		continue
	    }

	    set builtin 0

	    set cdef [commandDef _]
	    unset _

	    if {[info exists dupdef($cdef)]} continue
	    set dupdef($cdef) .

	    # Now write ...

	    if {!$hashead} {
		puts "command [list $c] \{"
		set hashead 1
	    }

	    puts "    definition \{"
	    puts [join $cdef \n]
	    puts "    \}"
	}

	if {!$builtin && [info exists use($c)]} {
	    foreach item $use($c) {
		array set _ $item
		set cuse [commandUse _]
		unset _

		if {[info exists dupuse($cuse)]} continue
		set dupuse($cuse) .

		if {!$hashead} {
		    puts "command [list $c] \{"
		    set hashead 1
		}

		puts "    usage \{"
		puts [join $cuse \n]
		puts "    \}"
	    }
	}

	unset dupdef
	unset dupuse

	if {!$hashead} continue
	puts "\}"

    }
    return
}

proc analyzer::dumpVariables {} {
    upvar 1 vdef vdef vuse vuse files files

    ## ##################################################
    ## II.b	Format and write variables
    ##
    ##    variable <name> {}
    ##        definition {}
    ##            <data>
    ##        {}
    ##        ...
    ##        usage {}
    ##            <data>
    ##        {}
    ##        ...
    ##    {}

    foreach v [lsort [array names vdef]] {
	lassign $v scope name
	set vid [list [Rescope $scope] $name]

	## puts "#######  [list $v]"
	puts "variable [list $vid] \{"
	foreach item $vdef($v) {
	    array set _ $item
	    puts "    definition \{"
	    puts "        type   [list $_(type)]"
	    puts [dumpScope $_(scope) "        "]
	    puts [dumpLoc   $_(loc)   "        "]
	    if {[info exists _(origin)]} {
		# origin = scope name
		lassign $_(origin) scope name
		set _(origin) [list [Rescope $scope] $name]
		puts "        origin     [list $_(origin)]"
		if {[info exists _(originscopes)]} {
		    puts "        originscopes \{"
		    foreach s $_(originscopes) {
			puts "            [list [Rescope $s]]"
		    }
		    puts "        \}"
		}
	    }
	    unset _
	    puts "    \}"
	}
	if {[info exists vuse($v)]} {
	    foreach item $vuse($v) {
		array set _ $item
		puts "    usage \{"
		puts [dumpScope $_(scope) "        "]
		puts [dumpLoc   $_(loc)   "        "]
		puts "    \}"
		unset _
	    }
	}
	puts "\}"
    }
    # Variable used, but not defined in the set of files scanned.
    foreach v [lsort [array names vuse]] {
	if {[info exists vdef($v)]} {continue}

	lassign $v scope name
	set vid [list [Rescope $scope] $name]

	## puts "#######  [list $v]"
	puts "variable [list $vid] \{"
	foreach item $vuse($v) {
	    array set _ $item
	    puts "    usage \{"
	    puts [dumpScope $_(scope) "        "]
	    puts [dumpLoc   $_(loc)   "        "]
	    puts "    \}"
	    unset _
	}
	puts "\}"
    }
    return
}

proc analyzer::dumpPackages {} {
    upvar 1 preq preq pdef pdef files files

    ## ##################################################
    ## V.b	Format and write packages
    ##
    ##    package require/provide <name> {}
    ##        <data>
    ##        ...
    ##    {}

    foreach p [lsort [array names pdef]] {
	foreach pd $pdef($p) {
	    puts "package provide [list $p] \{"
	    array set _ $pd
	    puts "    version [list $_(ver)]"
	    dumpLoc   $_(loc)   "    "
	    unset _
	    puts "\}"
	}
    }

    foreach p [lsort [array names preq]] {
	foreach pd $preq($p) {
	    puts "package require [list $p] \{"
	    array set _ $pd
	    puts "    version [list $_(ver)]"
	    puts "    exact   [list $_(exact)]"
	    dumpLoc   $_(loc)   "    "
	    unset _
	    puts "\}"
	}
    }
    return
}


proc analyzer::dumpLoc {loc prefix {key {loc }}} {
    upvar 1 files files

    lassign $loc file line range

    set fid $file
    if {[catch {set fid $files($fid)}]} {set fid {}}
    set nloc [list $fid $line $range]

    ## puts "${prefix}####  [list $loc]" ; # DEBUG
    return "${prefix}$key  [list $nloc]"
}

proc analyzer::dumpScope {scope prefix} {
    upvar 1 files files

    if {$scope eq {}} {
	return "${prefix}scope [list $scope]"
    }

    lassign $scope type name loc
    if {$loc eq {}} {
	return "${prefix}scope [list $scope]"
    }
    # Located scope ...

    lassign $loc file line range

    set fid $file
    if {[catch {set fid $files($fid)}]} {set fid {}}
    set nscope [list $type $name [list $fid $line $range]]

    ## puts "${prefix}##### [list $scope]" ; # DEBUG
    return "${prefix}scope [list $nscope]"
}

proc analyzer::Rescope {scope} {
    upvar 1 files files

    if {$scope eq {}} {return {}}

    lassign $scope type name loc
    if {$loc eq {}} {
	return $scope
    }
    # Located scope ...
    lassign $loc file line range

    set fid $file
    if {[catch {set fid $files($fid)}]} {set fid {}}
    return [list $type $name [list $fid $line $range]]
}

############################################################
##
## Package listing. Similar to what -verbose delivers
## (see message::showSummary). Key differences: Lists all
## packages the code required (- provided), and machine
## readable.

proc analyzer::dumpPkg {} {
    array set pkgs [xref::pExternal]

    #puts @@@@@@@@@@@@@@@@@@@
    #parray   pkgs
    #puts @@@@@@@@@@@@@@@@@@@

    # Determine longest pkg name, for formatting.

    set max 0
    foreach p [array names pkgs] {
	if {[set len [string length $p]] > $max} {
	    set max $len
	}
    }

    set prefix "package require "
    foreach name [lsort -dictionary [array names pkgs]] {
	if {![llength $pkgs($name)]} {
	    # No version information.
	    puts $prefix$name
	} else {
	    foreach v [lsort -dictionary [xref::pVersions $pkgs($name)]] {
		puts $prefix[format "%-${max}.${max}s %-s" $name $v]
	    }
	}
    }
    return
}

############################################################

proc analyzer::FilterControl {text} {
    # Extract instructions for the checker message generation & filter
    # from the given text, which originated as a paragraph of
    # comments. It is stripped down to the bare text now tough.

    foreach line [split $text \n] {
	if {![regexp {^checker} $line]} continue
	if {![info complete $line]} {
	    logError pragmaNotComplete {} $line
	    continue
	} ; # HACK: line is complete command, with arguments. eval needed to split it correctly into words
	if {[catch {eval pragma-$line} msg]} {
	    logError pragmaBad {} $line $msg
	    continue
	}
    }
    return
}

proc analyzer::pragma-checker {args} {
    if {[llength $args] < 2} pragma-checker-usage
    set scope line
    while {[string match -* [set opt [lindex $args 0]]]} {
	switch -exact -- $opt {
	    -scope {
		if {[llength $args] < 4} pragma-checker-usage
		set scope [lindex $args 1]

		set args [lrange $args 2 end]
	    }
	    default {
		return -code error "Bad option \"$opt\", expected -scope"
	    }
	}
    }
    set what [lindex $args 0]
    switch -exact -- $what {
	include - exclude {}
	default {
	    return -code error "Bad action \"$what\", expected include, or exclude"
	}
    }
    switch -exact -- $scope {
	global - local - block - line {}
	default {
	    return -code error "Bad scope \"$scope\", expected global, local, block, or line"
	}
    }
    pragma-checker-do $what $scope [lrange $args 1 end]
    return
}

proc analyzer::pragma-checker-usage {} {
    return -code error "wrong\#args: Expected 'checker ?-scope line|global|local? include|exclude id...'"
}

proc analyzer::pragma-checker-do {what scope idlist} {
    #puts PRAGMA($what,$scope,$idlist)

    # global: Change the global settings underlying all scope based
    #         filters. Takes effect if and only if there is no scope
    #         based override active (line, local, block).

    # line: Change the settings for all commands on the next line.

    switch -exact -- $what/$scope {
	include/global {filter::globalSet 0 $idlist}
	exclude/global {filter::globalSet 1 $idlist}
	include/line   {filter::lineSet   0 $idlist}
	exclude/line   {filter::lineSet   1 $idlist}
	include/block  {filter::blockSet  0 $idlist}
	exclude/block  {filter::blockSet  1 $idlist}
	include/local  {filter::localSet  0 $idlist}
	exclude/local  {filter::localSet  1 $idlist}
    }
    return
}

###########################################################

proc analyzer::BadSwitch {optionTable word value} {
    upvar 1 tokens tokens index index
    # Reporting badSwitch has a number of things to perform which are
    # the same everywhere. 

    # XXX AK: Similar to the code in checkOption, for badOption,
    # except there we also need the keyword list for use in the log
    # message. To merge this here and have a message code we have to
    # make keywords the 2nd argument, currently first, and update the
    # references in the message templates.

    # XXX AK FUTURE/TODO: Use the list to find the keyword(s) nearest
    # to the bad value (some sort of word-distance metric) and place
    # them at the beginning of the list of corrections.

    set keywords {}
    foreach keyword $optionTable {
	lappend keywords [lindex $keyword 0]
    }
    set keywords [lsort -dict $keywords]
    set xcmd {}
    foreach k $keywords {
	if {$k eq ""} {
	    lappend xcmd ldrop $index save
	} else {
	    lappend xcmd lset $index $k save
	}
    }
    logExtendedError \
	[CorrectionsOf 0 $tokens {*}$xcmd] \
	badSwitch [getTokenRange $word] $value
    return
}

###########################################################

proc analyzer::WarnUndef {cmdName cmdRange} {
    variable unknownCmds
    variable unknownCmdsLogged
    if {![info exists unknownCmds($cmdName)]} {
	# Give a warning if and only if this is the 1st time the
	# undefined proc is called.

	set unknownCmds($cmdName) .
	if {[logError warnUndefProc $cmdRange $cmdName]} {
	    set unknownCmdsLogged 1
	}
    }
    return
}

proc analyzer::getIndentation {range} {
    variable script

    # Determine location 
    set ws [lindex $range 0]

    #puts RA|$range
    #puts WS|$ws

    # All text before the command word
    set head [getString $script [list 0 $ws]]

    #puts <<$head>>

    # Determine the start of the line the command word is in.
    set  eol [string last \n $head]
    incr eol

    #puts EO|$eol

    # Determine the text of the line before the command word, and
    # expand tabs. NOTE! Tabs expand only as much as is needed to
    # reach the next tab-stop (every eight columns). They do NOT
    # uniformly expand to 8 spaces.

    set prefix [string range $head $eol end]

    #puts <<$prefix>><<[getString $script $range]>>

    set col 0
    foreach c [split $prefix {}] {
	if {$c ne "\t"} {
	    incr col
	} else {
	    incr col [expr {8 - ($col % 8)}]
	}
	#puts CH|$col|[string map {{ } {<<SPACE>>} {	} {<<TAB>>}} $c]|
    }
    #puts IN|$col
    return $col
}

############################################################
## style handling. style info per word of a command, set by highlevel checkers.
## queried when doing the style based general checks of all words in a command.
## needs push/pop (aka save/restore) to handle nesting of checkScript.

proc analyzer::checkSetStyle {style chain tokens index} {
    style::set $index $style
    return [{*}$chain $tokens $index]
}

namespace eval analyzer::style {
    variable  style
    array set style {}
    variable stack {}
    variable active 0
    variable override ""
}

proc analyzer::style::use {enable} {
    variable active $enable
    return
}

proc analyzer::style::using {} {
    variable active
    return $active
}

proc analyzer::style::override {type} {
    variable override $type
    return
}

proc analyzer::style::overridden {rv} {
    variable override
    if {$override eq ""} {return 0}
    upvar 1 $rv result
    #force use of core command, style namespace has its own 'set' command
    ::set result $override
    ::set override ""
    return 1
}

proc analyzer::style::set {index type} {
    #puts /style::set/$type/$index/@[analyzer::getLine]
    variable style
    ::set style($index) $type
    return
}

proc analyzer::style::get {index} {
    variable style
    if {![info exists style($index)]} { return string }
    return $style($index)
}

proc analyzer::style::save {} {
    #puts /style::save
    variable style
    variable stack
    lappend stack [array get style]
    return
}

proc analyzer::style::restore {} {
    #puts /style::restore
    variable style
    variable stack
    array unset style *
    array set style [lindex $stack end]
    ::set stack [lreplace $stack end end]
    return
}

proc analyzer::style::clear {} {
    #puts /style::clear
    variable style
    array unset style *
    return
}

############################################################

##
# analyzer::addNameStylePattern --
#
#	Merge name-style patterns defined by a package checker with the
#	database.
#
# Arguments:
#	dict	dict style -> pattern
#
# Results:
#	None.

proc ::analyzer::addNameStylePatterns {dict} {
    foreach {style pattern} $dict {
	style::pattern::set $style $pattern
    }
    return
}

namespace eval analyzer::style::pattern {
    variable  p
    array set p {}

    # Default/Standard patterns ...

    # Basic variable name, without a namespace prefix
    variable varname {[a-zA-Z0-9_]+}

    # Basic procedure name, without a namespace prefix.
    variable procname {[a-zA-Z_][a-zA-Z0-9_-]*}
    # proc name allows _ as first char, and - inside, but not _ inside.

    # Segment of a namespace path/package name
    variable nsitem {[a-zA-Z_][a-zA-Z0-9_-]*}

    # Package name, consisting of one or more segments,
    # all separated by ::
    variable pkgname   "(${nsitem})(::${nsitem})*"

    # Namespace path, like a package name, with an
    # optional :: at the beginning (if absolute).
    variable nspath "(::)?(${pkgname})"

    # Now the final patterns based on these components. The basic
    # var/proc names are extended with an optional namespace path.
    # All are anchored at beginning and end to cover the whole name.

    set p(package)   "^${pkgname}\$"
    set p(namespace) "^${nspath}\$"
    set p(proc)      "^(${nspath}::)?${procname}\$"
    set p(variable)  "^(${nspath}::)?${varname}\$"

    unset nsitem pkgname nspath varname procname
}

proc analyzer::style::pattern::set {id pattern} {
    variable p
    ::set    p($id) $pattern
    return
}

proc analyzer::style::pattern::get {id} {
    variable p
    return  $p($id)
}

############################################################
## Indentation management.

namespace eval analyzer::style::indent {
    variable cmd {}
    #trace add variable ::analyzer::style::indent::cmd write [list apply {{var idx op} { puts X|$var|$idx|$op|''|[info frame -2] ; return }}]
}

proc analyzer::style::indent::get {} {
    variable cmd
    #puts ig|$cmd|
    return  $cmd
}

proc analyzer::style::indent::set {n} {
    #puts is|$n|[info frame -1]
    variable cmd $n
    return
}

proc analyzer::style::indent::at {word} {
    # Bug 77231, R1.7
    variable cmd
    # Bracketed subcommands do not count when doing indentation
    # checks.
    variable ::analyzer::bracketNesting
    if {$bracketNesting} {
	return
    }
    # During scanning we do not have a properly initialized
    # context. And can't make one. Just leave the checks to the
    # analyze phase.
    if {[analyzer::isScanning]} {
	return
    }

    variable ::analyzer::scriptNesting

    # Determine indentation of the command word
    ::set wrange [::analyzer::getTokenRange $word]
    ::set indent [analyzer::getIndentation $wrange]

    # Bug 80390. Indentation per level is set through the cmdline
    # switch -indent.

    # XXX AK: Consider pcx command to set the expected indentation
    # XXX per level.

    ::set eindent [expr {($scriptNesting - 1) * $::configure::eindent}]

    #puts WO|$word|[info frame -1]
    #puts WR|$wrange|
    #puts EI|$eindent|$indent

    #variable ::analyzer::script
    #puts <$scriptNesting|$bracketNesting|[::analyzer::getString $script $wrange]|$indent|$eindent>

    if {$indent > $eindent} {
	# Command is indented farther than expected. It may or may not
	# be on the same line as a previous command. If there is a
	# command on the same line the -warnStyleOneCommandPerLine
	# already provided a correction proposal (except if blocked).

	# If the command stands alone we cannot give a correction,
	# because we cannot express the removal of whitespace _before_
	# the command in the corrected command. If there is a previous
	# command on the same line however then the correction is a
	# newline added, and that can be expressed.

	# We use namespace variables for the context, because we the
	# analyzeScript* commands are not our only caller,
	# checkSwitchCmd is as well, and the latter doesn't know how
	# far back it has to upvar to bring the old proc local
	# variable into scope. Therefore this data is now saved to
	# namespace, and that can be imported regardless of how deeply
	# nested this command is from the code defining the data.

	#upvar 1 oldPrevRange oldRange oldPrevCmdRange oldCmdRange
	variable ::analyzer::xoldPrevRange
	variable ::analyzer::xoldPrevCmdRange

	if {
	    [llength $xoldPrevRange] &&
	    [string match {*;*} [analyzer::getString $analyzer::script $xoldPrevRange]]
	} {
	    #upvar 1 tree tokens
	    variable ::analyzer::xtree
	    logExtendedError \
		[CorrectionsOf 0 $xtree \
		     +indent [analyzer::getIndentation $xoldPrevCmdRange] newline save] \
	    warnStyleIndentCommand $wrange $indent $eindent
	} else {
	    logError \
		warnStyleIndentCommand $wrange $indent $eindent
	}
    } elseif {$indent < $eindent} {
	# Command is not indented enough, add spaces in front.
	#upvar 1 tree tokens
	variable ::analyzer::xtree
	logExtendedError \
	    [CorrectionsOf 0 $xtree \
		 +indent [expr {$eindent - $indent}] save] \
	    warnStyleIndentCommand $wrange $indent $eindent
    }

    ::set cmd $indent
    return
}

############################################################
## internal debugging helper command

if {0} {
    rename ::exit ::analyzer::EXIT
    proc exit {{status 0}} {
	analyzer::stacks::dump
	analyzer::EXIT $status
    }
    namespace eval analyzer::stacks {
	variable stacks
	array set stacks {}
    }
    proc analyzer::stacks::dump {} {
	variable stacks
	foreach {stack count} [array get stacks] {
	    puts "STACK $count \{"
	    puts \t[join $stack \n\t]
	    puts "\}"
	}
	return
    }
    proc analyzer::stacks::mark {} {
	variable stacks
	set levels [info frame]
	set n -2
	set stack {}
	while {$levels > 2} {
	    lappend stack [info frame $n]
	    incr n -1
	    incr levels -1
	}
	if {[info exists stacks($stack)]} {
	    incr stacks($stack)
	} else {
	    set stacks($stack) 1
	}
	return
    }
    proc analyzer::stacks::print {} {
	variable stacks
	set levels [info frame]
	set n -2
	set stack {}
	while {$levels > 2} {
	    lappend stack [info frame $n]
	    incr n -1
	    incr levels -1
	}
	puts \t[join $stack \n\t]
	return
    }
}

############################################################
