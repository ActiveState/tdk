# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*- coreTcl.pcx --
#
#	This file contains type and command checkers for the core Tcl
#	commands.
#
# Copyright (c) 2002-2011 ActiveState Software Inc.
# Copyright (c) 1998-2000 Ajuba Solutions

#
# RCS: @(#) $Id: coreTcl.tcl,v 1.14 2000/10/31 23:30:54 welch Exp $

# ### ######### ###########################
## Requisites

package require pcx          ; # PCX API

package require struct::list
package require struct::set

# ### ######### ###########################
## Tcl core version dependencies of the package this checker is for.

pcx::register coreTcl Tcl
pcx::tcldep   7.3 needs tcl 7.3
pcx::tcldep   7.4 needs tcl 7.4
pcx::tcldep   7.5 needs tcl 7.5
pcx::tcldep   7.6 needs tcl 7.6
pcx::tcldep   8.0 needs tcl 8.0
pcx::tcldep   8.1 needs tcl 8.1
pcx::tcldep   8.2 needs tcl 8.2
pcx::tcldep   8.3 needs tcl 8.3
pcx::tcldep   8.4 needs tcl 8.4
pcx::tcldep   8.5 needs tcl 8.5
pcx::tcldep   8.6 needs tcl 8.6

# ### ######### ###########################
## Package specific message types and their human-readable
## translations.

pcx::message badTraceOp     {invalid operation "%1$s": should be one or more of rwu} {err}
pcx::message serverAndPort  {Option -myport is not valid for servers} {err}
pcx::message socketArgOpt   {no argument given for "%1$s" option} {err}
pcx::message socketAsync    {cannot set -async option for server sockets} {err}
pcx::message socketBadOpt   {invalid option "%1$s", must be -async, -myaddr, -myport, or -server} {err}
pcx::message socketServer   {cannot set -async option for server sockets} {err}
pcx::message badCharMap     {string map list should have an even number of elements} {err}
pcx::message warnY2K        {"%%y" generates a year without a century. consider using "%%Y" to avoid Y2K errors.} {warn}
pcx::message warnAIPattern  {auto_import pattern is used to restrict loading in later versions of Tcl.} {upgrade}
pcx::message warnMemoryCmd  {memory is debugging command} {warn}
pcx::message badBinaryFmt   {Bad format for binary command: %1$s} {err}
pcx::message badFormatFmt   {Bad format for format command: %1$s} {err}
pcx::message warnFormatFmt  {Large positional specifier in format command: %1$s} {warn}
pcx::message badSerialMode  {Bad serial mode: %1$s} {err}
pcx::message pkgBadExactRq  {Package require has -exact, but no version specified} {err}
pcx::message pkgVConflict   {Conflict between requested (%1$s) and actually checked (%2$s) version.} {warn}
pcx::message pkgTclConflict {%1$s %2$s requires Tcl %3$s, we are checking %4$s} {warn}
pcx::message pkgTclUnknown  {Unable to determine the version of Tcl required by %1$s %2$s, we are assuming %3$s} {warn}
pcx::message pkgUnchecked   {Will not check commands provided by this package: %1$s} {warn}
pcx::message warnTclConflict {Script has requested Tcl version %1$s, but the checker has already loaded the definitions for version %2$s. Use option '-use Tcl%1$s' to override.} {warn}
pcx::message warnUplevel    {It is recommended to use an explicit level argument} {warn}
pcx::message badLocale      {Bad option "-locale", needs "-format"}  {err}
pcx::message badTimezone    {Bad option "-timezone", needs "-format"} {err}
pcx::message warnStyleThen  {Exclude "then" from "if" commands} style
pcx::message warnStyleNameVariableConstant {Variable name should be capitalized if constant} style
pcx::message badBisect      {Cannot use "-bisect" with "-all" or "-not"} err

# ### ######### ###########################

# ### ######### ###########################
## Tcl variables declared by this package

pcx::var 7.3 ::argv
pcx::var 7.3 ::argv0
pcx::var 7.3 ::argc
pcx::var 7.3 ::errorCode
pcx::var 7.3 ::errorInfo
pcx::var 7.3 ::env
pcx::var 7.3 ::auto_oldpath
pcx::var 7.3 ::auto_path
pcx::var 7.3 ::auto_index
pcx::var 7.3 ::tcl_version
pcx::var 7.3 ::tcl_interactive
pcx::var 7.3 ::tcl_patchLevel
pcx::var 7.3 ::tcl_libPath
pcx::var 7.3 ::tcl_library

pcx::var 7.5 ::tcl_rcFileName
pcx::var 7.5 ::tcl_platform 
pcx::var 7.5 ::tcl_platform(machine)
pcx::var 7.5 ::tcl_platform(os)
pcx::var 7.5 ::tcl_platform(osVersion)
pcx::var 7.5 ::tcl_platform(platform)

pcx::var 7.6 ::tcl_pkgPath 
pcx::var 7.6 ::tcl_rcRsrcName

pcx::var 8.0 ::tcl_traceCompile
pcx::var 8.0 ::tcl_traceExec
pcx::var 8.0 ::tcl_nonwordchars
pcx::var 8.0 ::tcl_wordchars
pcx::var 8.0 ::tcl_platform(byteOrder)
pcx::var 8.0 ::tcl_platform(debug)

pcx::var 8.1 ::tcl_platform(user)

# FUTURE: threaded if and only if tclsh is compiled for threading.
pcx::var 8.2 ::tcl_platform(threaded)

pcx::var 8.4 ::tcl_platform(wordSize)

pcx::var 8.6 ::tcl_platform(pathSeparator)

# ### ######### ###########################
## Expr operators and functions declared by this package

pcx::mathop 7.3 -  1
pcx::mathop 7.3 ~  1
pcx::mathop 7.3 !  1
pcx::mathop 7.3 *  2
pcx::mathop 7.3 /  2
pcx::mathop 7.3 %  2
pcx::mathop 7.3 +  2
pcx::mathop 7.3 -  2
pcx::mathop 7.3 << 2
pcx::mathop 7.3 >> 2
pcx::mathop 7.3 <  2
pcx::mathop 7.3 >  2
pcx::mathop 7.3 <= 2
pcx::mathop 7.3 >= 2
pcx::mathop 7.3 == 2
pcx::mathop 7.3 != 2
pcx::mathop 7.3 &  2
pcx::mathop 7.3 ^  2
pcx::mathop 7.3 |  2
pcx::mathop 7.3 && 2
pcx::mathop 7.3 || 2
pcx::mathop 7.3 ?  3

pcx::mathop 7.3 acos   1
pcx::mathop 7.3 cos    1
pcx::mathop 7.3 hypot  2
pcx::mathop 7.3 sinh   1
pcx::mathop 7.3 asin   1
pcx::mathop 7.3 cosh   1
pcx::mathop 7.3 log    1
pcx::mathop 7.3 sqrt   1
pcx::mathop 7.3 atan   1
pcx::mathop 7.3 exp    1
pcx::mathop 7.3 log10  1
pcx::mathop 7.3 tan    1
pcx::mathop 7.3 atan2  2
pcx::mathop 7.3 floor  1
pcx::mathop 7.3 pow    2
pcx::mathop 7.3 tanh   1
pcx::mathop 7.3 ceil   1
pcx::mathop 7.3 fmod   2
pcx::mathop 7.3 sin    1
pcx::mathop 7.3 abs    1
pcx::mathop 7.3 double 1
pcx::mathop 7.3 int    1
pcx::mathop 7.3 round  1

pcx::mathop 7.4 + 1

pcx::mathop 8.0 rand  0
pcx::mathop 8.0 srand 1

pcx::mathop 8.4 wide 1
pcx::mathop 8.4 ne   2
pcx::mathop 8.4 eq   2

pcx::mathop 8.5 in    2
pcx::mathop 8.5 ni    2
pcx::mathop 8.5 bool  1
pcx::mathop 8.5 **    2
pcx::mathop 8.5 isqrt 1
pcx::mathop 8.5 entier 1

pcx::mathvop 8.5 min 1 -1 ; # 1+ arguments, variadic
pcx::mathvop 8.5 max 1 -1 ; # 1+ arguments, variadic

# ### ######### ###########################

# ### ######### ###########################
## Define the set of commands that need to be recursed into when
## generating a list of user defined procs, namespace and Class
## contexts and procedure name resolutions info.

pcx::scan 7.3 case
pcx::scan 7.3 catch
pcx::scan 7.3 eval
pcx::scan 7.3 for
pcx::scan 7.3 foreach
pcx::scan 7.3 history
pcx::scan 7.3 if
pcx::scan 7.3 switch
pcx::scan 7.3 time
pcx::scan 7.3 while
pcx::scan 7.3 proc     {addContext 1 1 {} {} {checkSimpleArgs 3 3 \
	{{newScope proc addUserProc} addArgList checkBody}}}

pcx::scan 8.5 apply {checkListValues 2 3 {
    {addContext 2 0 {} {} {checkSimpleArgs 2 3 {
	{newScope apply addArgList}
	checkBody
	checkNamespace
    }}}
}}

pcx::scan 7.3 rename   {addRenameCmd}
pcx::scan 7.3 set      {scanTrackSetVariable}
pcx::scan 7.3 variable {scanTrackVariable}
pcx::scan 7.3 global   {scanTrackGlobal}

# Bug 82058. NOTE: This context implicitly defines that scanTrackUpvar
# is always called with 'index == 1'.
pcx::scan 7.3 upvar    {scanTrackUpvar}
pcx::scan 7.3 uplevel

## Nothing for 7.4

pcx::scan 7.5 after
pcx::scan 7.5 namespace	{checkOption {
    {code	    	{checkSimpleArgs 1 1 {checkBody}}}
    {eval	    	{addContext 2 0 {} {} {checkSimpleArgs 2 -1 \
 	    {{newNamespaceScope namespace checkWord} checkEvalArgs}}}}
    {export	    	{addExportCmd}}
    {import	    	{addImportCmd}}
} {checkCommand}}

pcx::scan 7.5 package {checkSimpleArgs 1 4 {{checkOption {
    {forget	 	{checkSimpleArgs 1 1 {checkWord}}}
    {ifneeded 		{checkSimpleArgs 2 3 {checkWord checkVersion checkBody}}}
    {names 		{checkSimpleArgs 0 0 {}}}
    {provide 		{coreTcl::checkPackageProvide}}
    {require 		{coreTcl::checkPackageRequire}}
    {unknown 		{checkSimpleArgs 0 1 {checkWord}}}
    {vcompare 		{checkSimpleArgs 2 2 {checkVersion}}}
    {versions 		{checkSimpleArgs 1 1 {checkWord}}}
    {vsatisfies 	{checkSimpleArgs 2 2 {checkVersion}}}
} {}}}}

## Nothing for 7.6
## Nothing for 8.0
## Nothing for 8.1
## Nothing for 8.2

pcx::scan 8.3 package {checkSimpleArgs 1 4 {{checkOption {
    {forget	 	{checkSimpleArgs 1 1 {checkWord}}}
    {ifneeded 		{checkSimpleArgs 2 3 {checkWord checkVersion checkBody}}}
    {names 		{checkSimpleArgs 0 0 {}}}
    {present 		{checkSwitches 1 {-exact} {checkSimpleArgs 1 2 {checkWord checkVersion}}}}
    {provide 		{coreTcl::checkPackageProvide}}
    {require 		{coreTcl::checkPackageRequire}}
    {unknown 		{checkSimpleArgs 0 1 {checkWord}}}
    {vcompare 		{checkSimpleArgs 2 2 {checkVersion}}}
    {versions 		{checkSimpleArgs 1 1 {checkWord}}}
    {vsatisfies 	{checkSimpleArgs 2 2 {checkVersion}}}
} {}}}}

## Nothing for 8.4

if 0 {
    variable proScanCmds {
	debugger_eval-TPC-SCAN	1
    }
}

## 8.5

pcx::scan 8.5 package {checkSimpleArgs 1 -1 {{checkOption {
    {forget	 	{checkSimpleArgs 1 1 {checkWord}}}
    {ifneeded 		{checkSimpleArgs 2 3 {checkWord checkExtVersion checkBody}}}
    {names 		{checkSimpleArgs 0 0 {}}}
    {present 		{checkSwitches 1 {-exact} {checkSimpleArgs 1 2 {checkWord checkVersion}}}}
    {provide 		{coreTcl::checkPackageProvide85}}
    {require 		{coreTcl::checkPackageRequire85}}
    {unknown 		{checkSimpleArgs 0 1 {checkWord}}}
    {vcompare 		{checkSimpleArgs 2 2 {checkExtVersion}}}
    {versions 		{checkSimpleArgs 1 1 {checkWord}}}
    {vsatisfies 	{checkSimpleArgs 2 -1 {checkExtVersion checkRequirement}}}
} {}}}}

# ### ######### ###########################

# ### ######### ###########################
## Define the set of command-specific checkers used by this
## package.

pcx::check 7.3 std append	{checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}
pcx::check 7.3 std array	{checkSimpleArgs 2 3 {{checkOption {
    {anymore	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {donesearch	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {names	    {checkSimpleArgs 1 1 {checkVarName}}}
    {nextelement    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {size	    {checkSimpleArgs 1 1 {checkVarName}}}
    {startsearch    {checkSimpleArgs 1 1 {checkVarName}}}
} {}}}}
pcx::check 7.3 std auto_execok	{checkSimpleArgs 1  1 {checkFileName}}
pcx::check 7.3 std auto_load	{checkSimpleArgs 1  1 {checkWord}}
pcx::check 7.3 std auto_mkindex	{checkSimpleArgs 1 -1 {checkFileName checkPattern}}
pcx::check 7.3 std auto_reset	{checkSimpleArgs 0  0 {}}
pcx::check 7.3 std break	{checkSimpleArgs 0 0 {}}
pcx::check 7.3 std case		{coreTcl::checkCaseCmd}
pcx::check 7.3 std catch	{checkSimpleArgs 1 2 {
    {checkAsStyle body/single-line checkBody}
    checkVarNameWrite
}}
pcx::check 7.3 std cd		{checkSimpleArgs 0 1 {checkFileName}}
pcx::check 7.3 std close	{checkSimpleArgs 1 1 {checkChannelID}}
pcx::check 7.3 std concat	{checkSimpleArgs 0 -1 {checkWord}}
pcx::check 7.3 std continue	{checkSimpleArgs 0 0 {}}
pcx::check 7.3 std eof		{checkSimpleArgs 1 1 {checkChannelID}}
pcx::check 7.3 std error	{analyzer::warn warnStyleError {} {checkSimpleArgs 1 3 {checkWord}}}
pcx::check 7.3 std eval		{checkSimpleArgs 1 -1 {checkEvalArgs}}

pcx::check 7.3 std exec		{checkSwitches 1 {
    -keepnewline --
} {checkDoubleDash {checkSimpleArgs 1 -1 {
    {coreTcl::ExecReplacements checkWord}
    checkWord
}}}}

pcx::check 7.3 std exit		{analyzer::warn warnStyleExit {} {checkSimpleArgs 0 1 {checkInt}}}
pcx::check 7.3 std expr		coreTcl::checkExprCmd
pcx::check 7.3 std file		{checkSimpleArgs 1 -1 {{checkOption {
    {atime 		{checkSimpleArgs 1 1 {checkFileName}}}
    {attributes 	{checkSimpleArgs 1 -1 {checkFileName {checkConfigure 1 {
	{-group       {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-owner       {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-permissions {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-archive     {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-hidden      {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-longname    {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-readonly    {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-shortname   {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-system      {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-creator     {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-type        {::analyzer::warn nonPortCmd {} {checkWord}}}}}}}
    }
    {dirname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {executable 	{checkSimpleArgs 1 1 {checkFileName}}}
    {exists 		{checkSimpleArgs 1 1 {checkFileName}}}
    {extension 		{checkSimpleArgs 1 1 {checkFileName}}}
    {isdirectory 	{checkSimpleArgs 1 1 {checkFileName}}}
    {isfile 		{checkSimpleArgs 1 1 {checkFileName}}}
    {lstat 		{checkSimpleArgs 2 2 {
	checkFileName
	checkVarNameWrite
    }}}
    {mtime 		{checkSimpleArgs 1 1 {checkFileName}}}
    {owned 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readable 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readlink 		{checkSimpleArgs 1 1 {checkFileName}}}
    {rootname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {size 		{checkSimpleArgs 1 1 {checkFileName}}}
    {stat 		{checkSimpleArgs 2 2 {
	checkFileName
	checkVarNameWrite
    }}}
    {tail 		{checkSimpleArgs 1 1 {checkFileName}}}
    {type 		{checkSimpleArgs 1 1 {checkFileName}}} 
    {writable 		{checkSimpleArgs 1 1 {checkFileName}}}
} {}}}}

pcx::check 7.3 std flush	{checkSimpleArgs 1 1 {checkChannelID}}
pcx::check 7.3 std for \
    {checkSimpleArgs 4 4 {
	{checkAsStyle body/single-line checkBody}
	checkExpr
	{checkAsStyle body/single-line checkBody}
	{checkOrderLoop checkBody}
    }}
pcx::check 7.3 std foreach	coreTcl::checkForeachCmd
pcx::check 7.3 std format	{checkSimpleArgs 1 -1 {coreTcl::checkFormatFmt checkWord}}
pcx::check 7.3 std gets		{checkSimpleArgs 1  2 {checkChannelID checkVarNameWrite}}
pcx::check 7.3 std glob		{checkSwitches 0 {
    -nocomplain --
} {checkSimpleArgs 1 -1 {{checkDoubleDash checkPattern} checkPattern}}}

pcx::check 7.3 std global	{coreTcl::checkGlobalCmd}
pcx::check 7.3 std history	{checkSimpleArgs 0 3 {{checkOption {
    {add 		{checkSimpleArgs 1 2 \
	    {checkBody {checkKeyword 0 {exec}}}}}
    {change 		{checkSimpleArgs 1 2 {checkWord}}}
    {event 		{checkSimpleArgs 0 1 {checkWord}}}
    {info 		{checkSimpleArgs 0 1 {checkInt}}}
    {keep 		{checkSimpleArgs 0 1 {checkInt}}}
    {nextid 		{checkSimpleArgs 0 0 {}}}
    {redo 		{checkSimpleArgs 0 1 {checkWord}}}
} {}}}}

pcx::check 7.3 std if 		{checkOrderBranches coreTcl::checkIfCmd}
pcx::check 7.3 std incr		{checkSimpleArgs 1  2 {checkVarNameReadWrite checkInt}}
pcx::check 7.3 std info		{checkSimpleArgs 1 4 {{checkOption {
    {args	{checkSimpleArgs 1  1 {checkWord}}}
    {body	{checkSimpleArgs 1  1 {checkWord}}}
    {cmdcount	{checkSimpleArgs 0  0 {}}}
    {commands	{checkSimpleArgs 0  1 {checkPattern}}}
    {complete	{checkSimpleArgs 1  1 {checkWord}}}
    {default	{checkSimpleArgs 3  3 \
	    {checkWord checkWord checkVarNameWrite}}}
    {exists	{checkSimpleArgs 1  1 {checkVarNameSyntax}}}
    {globals	{checkSimpleArgs 0  1 {checkPattern}}}
    {level	{checkSimpleArgs 0  1 {checkInt}}}
    {library	{checkSimpleArgs 0  0 {}}}
    {loaded	{checkSimpleArgs 0  1 {checkWord}}}
    {locals	{checkSimpleArgs 0  1 {checkPattern}}}
    {patchlevel	{checkSimpleArgs 0  0 {}}}
    {procs	{checkSimpleArgs 0  1 {checkPattern}}}
    {script	{checkSimpleArgs 0  0 {}}}
    {tclversion	{checkSimpleArgs 0  0 {}}}
    {vars	{checkSimpleArgs 0  1 {checkPattern}}}
} {}}}}

pcx::check 7.3 std join		{checkSimpleArgs 1  2 {checkList checkWord}}
pcx::check 7.3 std lappend	{checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}
pcx::check 7.3 std lindex	{checkSimpleArgs 2  2 {checkList checkInt}}
pcx::check 7.3 std linsert	{checkSimpleArgs 3 -1 {checkList checkInt checkWord}}
pcx::check 7.3 std list		{checkSimpleArgs 0 -1 {checkWord}}
pcx::check 7.3 std llength	{checkSimpleArgs 1  1 {checkList}}
pcx::check 7.3 std lrange	{checkSimpleArgs 3  3 {checkList checkInt}}
pcx::check 7.3 std lreplace	{checkSimpleArgs 3 -1 {checkList checkInt checkInt checkWord}}
pcx::check 7.3 std lsearch	{checkTailArgs \
	{checkHeadSwitches 0 2 {-exact -glob -regexp} {}} \
	{checkSimpleArgs 2 2 {checkList checkPattern}} 2}

pcx::check 7.3 std lsort	{checkTailArgs \
	{checkHeadSwitches 0 1 {-ascii -integer -real \
	{-command {checkProcCall 2}} \
	-increasing -decreasing} {}} \
	{checkSimpleArgs 1 1 {checkList}} 1}

pcx::check 7.3 std memory       {::analyzer::warn coreTcl::warnMemoryCmd {} {checkSimpleArgs 0 -1 {checkWord}}}
pcx::check 7.3 std open		{checkSimpleArgs 1 3 \
	{checkFileName checkAccessMode checkInt}}

pcx::check 7.3 std parray	{checkSimpleArgs 1  1 {checkArrayVarName}}
pcx::check 7.3 std pid		{checkSimpleArgs 0  1 {checkChannelID}}
pcx::check 7.3 std proc		{checkAll {
    coreTcl::checkPickProcOnePass
    {checkDynLit 2 {
	checkSimpleArgs 3 3 {
	    {checkSetStyle procname checkRedefined}
	    checkArgList
	    {checkOrdering {checkBody}}
	}
    } {
	checkContext 1 1 {checkSimpleArgs 3 3 {
	    {newScope proc {checkSetStyle procname checkRedefined}}
	    checkArgList
	    {checkOrdering {checkBody}}
	}}
    }}
}}

pcx::check 7.3 std puts		{checkOption {
    {-nonewline {checkNumArgs {
	{1  {checkSimpleArgs 1 1 {checkWord}}}
	{-1 {checkSimpleArgs 2 3 {
	    checkChannelID checkWord 
	    {checkKeyword 0 nonewline}}}}}
	}
    }
} {checkNumArgs {
    {1  {checkSimpleArgs 1 1 {checkWord}}}
    {-1 {checkSimpleArgs 2 3 {
	checkChannelID checkWord 
	{checkKeyword 0 nonewline}}}}}
    }
}

pcx::check 7.3 std pwd		{checkSimpleArgs 0  0 {}}
pcx::check 7.3 std read 	{coreTcl::checkReadCmd 0}
pcx::check 7.3 std regexp	{checkSwitches 1 {-nocase -indices --} {checkSimpleArgs 2 -1 \
    {{checkDoubleDash checkRegexp} checkWord checkVarNameWrite}}}

pcx::check 7.3 std regsub	{checkSwitches 1 {-all -nocase --} {checkSimpleArgs 4 4 \
    {{checkDoubleDash checkRegexp} checkWord checkWord checkVarNameWrite}}}

pcx::check 7.3 std rename	{checkSimpleArgs 2  2 {checkProcName checkWord}}
pcx::check 7.3 std return	coreTcl::checkReturnCmd
pcx::check 7.3 std scan		{checkSimpleArgs 3 -1 \
	{checkWord coreTcl::checkScanFmt checkVarNameWrite}}
pcx::check 7.3 std seek		{checkSimpleArgs 2  3 {checkChannelID checkInt \
	{checkKeyword 0 {start current end}}}}

pcx::check 7.3 std set {checkAll {
    {checkNumArgs {
	{1 {checkSimpleArgs 1 1 {
	    checkVarName
	}}}
	{2 {checkSimpleArgs 2 2 {
	    checkVarNameWrite
	    checkWord
	}}}
    }}
    {coreTcl::VarnameForConstant}
}}

pcx::check 7.3 std source	coreTcl::checkSourceCmd
pcx::check 7.3 std split	{checkSimpleArgs 1  2 {checkWord}}
pcx::check 7.3 std string	{checkSimpleArgs 2  4 {{checkOption {
    {compare 		{checkSimpleArgs 2 2 {checkWord}}}
    {first 		{checkSimpleArgs 2 2 {checkWord}}}
    {index 		{checkSimpleArgs 2 2 {checkWord checkInt}}}
    {last 		{checkSimpleArgs 2 2 {checkWord}}}
    {length 		{checkSimpleArgs 1 1 {checkWord}}}
    {match 		{checkSimpleArgs 2 2 {checkPattern checkWord}}}
    {range 		{checkSimpleArgs 3 3 {checkWord checkIndex}}}
    {tolower 		{checkSimpleArgs 1 1 {checkWord}}}
    {toupper 		{checkSimpleArgs 1 1 {checkWord}}}
    {trim 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimleft 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimright 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
} {}}}}

pcx::check 7.3 std switch		{checkSwitches 0 {
    -exact -glob -regexp --
} {checkDoubleDash coreTcl::checkSwitchCmd}}

pcx::check 7.3 std tcl_endOfWord		{checkSimpleArgs 2  2 {checkWord checkIndex}}
pcx::check 7.3 std tcl_startOfNextWord		{checkSimpleArgs 2  2 {checkWord checkIndex}}
pcx::check 7.3 std tcl_startOfPreviousWord	{checkSimpleArgs 2  2 {checkWord checkIndex}}
pcx::check 7.3 std tcl_wordBreakAfter		{checkSimpleArgs 2  2 {checkWord checkIndex}}
pcx::check 7.3 std tcl_wordBreakBefore		{checkSimpleArgs 2  2 {checkWord checkIndex}}
pcx::check 7.3 std tell		{checkSimpleArgs 1  1 {checkChannelID}}
pcx::check 7.3 std time		{checkSimpleArgs 1  2 {
    {checkAsStyle body/single-line checkBody}
    checkInt
}}
pcx::check 7.3 std trace		{checkNumArgs {
    {2  {checkSimpleArgs 2 2 \
	    {{checkKeyword 0 {vinfo}} \
	    checkVarName}}}
    {4  {checkSimpleArgs 4 4 \
	    {{checkKeyword 0 {variable vdelete}} \
	    checkVarName coreTcl::checkTraceOp \
	    {checkProcCall 3}}}}}
}
pcx::check 7.3 std unknown	{checkSimpleArgs 1 -1 {checkWord}}
pcx::check 7.3 std unset	{checkSimpleArgs 1 -1 {checkVarNameWrite}}
pcx::check 7.3 std uplevel	{coreTcl::checkUplevelCmd}
pcx::check 7.3 std upvar	{coreTcl::checkUpvarCmd}
pcx::check 7.3 std while \
    {checkSimpleArgs 2 2 {
	checkExpr
	{checkOrderLoop checkBody}
    }}

## ### #### ##### ######

pcx::check 7.4 std append	{checkSimpleArgs 1 -1 {checkVarNameWrite checkWord}}
pcx::check 7.4 std array	{checkSimpleArgs 2 3 {{checkOption {
    {anymore	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {donesearch	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {exists	    {checkSimpleArgs 1 1 {checkVarName}}}
    {get	    {checkSimpleArgs 1 2 {checkVarName checkPattern}}}
    {names	    {checkSimpleArgs 1 2 {checkVarName checkPattern}}}
    {nextelement    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {set	    {checkSimpleArgs 2 2 {checkVarNameWrite {checkListModNk 2 0}}}}
    {size	    {checkSimpleArgs 1 1 {checkVarName}}}
    {startsearch    {checkSimpleArgs 1 1 {checkVarName}}}
} {}}}}
pcx::check 7.4 std lappend	{checkSimpleArgs 1 -1 {checkVarNameWrite checkWord}}
pcx::check 7.4 std lindex	{checkSimpleArgs 2  2 {checkList checkIndex}}
pcx::check 7.4 std linsert	{checkSimpleArgs 3 -1 {checkList checkIndex checkWord}}
pcx::check 7.4 std lrange	{checkSimpleArgs 3  3 {checkList checkIndex}}
pcx::check 7.4 std lreplace	{checkSimpleArgs 3 -1 {checkList checkIndex \
	checkIndex checkWord}}
pcx::check 7.4 std parray	{checkSimpleArgs 1  2 {checkArrayVarName checkPattern}}
pcx::check 7.4 std string	{checkSimpleArgs 2  4 {{checkOption {
    {compare 		{checkSimpleArgs 2 2 {checkWord}}}
    {first 		{checkSimpleArgs 2 2 {checkWord}}}
    {index 		{checkSimpleArgs 2 2 {checkWord checkInt}}}
    {last 		{checkSimpleArgs 2 2 {checkWord}}}
    {length 		{checkSimpleArgs 1 1 {checkWord}}}
    {match 		{checkSimpleArgs 2 2 {checkPattern checkWord}}}
    {range 		{checkSimpleArgs 3 3 {checkWord checkIndex}}}
    {tolower 		{checkSimpleArgs 1 1 {checkWord}}}
    {toupper 		{checkSimpleArgs 1 1 {checkWord}}}
    {trim 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimleft 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimright 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {wordend 		{checkSimpleArgs 2 2 {checkWord checkIndex}}}
    {wordstart 		{checkSimpleArgs 2 2 {checkWord checkIndex}}}
} {}}}}
pcx::check 7.4 std subst		{checkSwitches 0 {
    -nobackslashes -nocommands -novariables
} {checkSimpleArgs 1 1 {checkWord}}}

## ### #### ##### ######

pcx::check 7.5 std after	{checkOption {
    {cancel	    {checkSimpleArgs 1 -1 {checkWord}}}
    {idle	    {checkSimpleArgs 0 -1 {checkEvalArgs}}}
    {info	    {checkSimpleArgs 0 -1 {checkWord}}}
} {checkSimpleArgs 1 -1 {checkInt checkEvalArgs}}}
pcx::check 7.5 std bgerror		{checkSimpleArgs 1 1 {checkWord}}
pcx::check 7.5 std clock		{checkSimpleArgs 1 6 {{checkOption {
    {clicks	    {checkSimpleArgs 0 0 {}}}
    {format	    {checkSimpleArgs 1 5 {
	checkInt
	{checkSwitches 0 {
	    {-format coreTcl::checkClockFormat} 
	    {-gmt checkBoolean}
	} {}}}}
    }
    {scan	    {checkSimpleArgs 1 5 {
	checkWord
	{checkSwitches 0 {
	    {-base checkInt}
	    {-gmt checkBoolean}
	} {}}}}
    }
    {seconds	    {checkSimpleArgs 0 0 {}}}
} {}}}}
pcx::check 7.5 std fblocked	{checkSimpleArgs 1 1 {checkChannelID}}
pcx::check 7.5 std fconfigure	{checkSimpleArgs 1 -1 {checkChannelID {
    checkExtensibleConfigure 1 {
	{-blocking checkBoolean}
	{-buffering {checkKeyword 0 {full line none}}}
	{-buffersize checkInt}
	{-eofchar {checkListValues 0 2 {checkWord}}}
	{-peername {checkSimpleArgs 0 0 {}}}
	{-sockname {checkSimpleArgs 0 0 {}}}
	{-translation {checkListValues 0 2 {
	    {checkKeyword 1 {auto binary cr crlf lf}}}}}}
	}
    }
}
pcx::check 7.5 std file	{checkSimpleArgs 1 -1 {{checkOption {
    {atime 		{checkSimpleArgs 1 1 {checkFileName}}}
    {attributes 	{checkSimpleArgs 1 -1 {checkFileName
    {checkConfigure 1 {
	{-group {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-owner {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-permissions {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-archive {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-hidden {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-longname {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-readonly {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-shortname {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-system {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-creator {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-type {::analyzer::warn nonPortCmd {} {checkWord}}}}}}}
    }
    {dirname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {executable 	{checkSimpleArgs 1 1 {checkFileName}}}
    {exists 		{checkSimpleArgs 1 1 {checkFileName}}}
    {extension 		{checkSimpleArgs 1 1 {checkFileName}}}
    {isdirectory 	{checkSimpleArgs 1 1 {checkFileName}}}
    {isfile 		{checkSimpleArgs 1 1 {checkFileName}}}
    {join 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {lstat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {mtime 		{checkSimpleArgs 1 1 {checkFileName}}}
    {nativename 	{checkSimpleArgs 1 1 {checkFileName}}}
    {owned 		{checkSimpleArgs 1 1 {checkFileName}}}
    {pathtype 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readable 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readlink 		{checkSimpleArgs 1 1 {checkFileName}}}
    {rootname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {size 		{checkSimpleArgs 1 1 {checkFileName}}}
    {split 		{checkSimpleArgs 1 1 {checkFileName}}}
    {stat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {tail 		{checkSimpleArgs 1 1 {checkFileName}}}
    {type 		{checkSimpleArgs 1 1 {checkFileName}}} 
    {writable 		{checkSimpleArgs 1 1 {checkFileName}}}
} {}}}}

pcx::check 7.5 std fileevent	{checkSimpleArgs 2 3 {checkChannelID \
	{checkKeyword 0 {readable writable}} checkBody}}
pcx::check 7.5 std info		{checkSimpleArgs 1 4 {{checkOption {
    {args	{checkSimpleArgs 1  1 {checkWord}}}
    {body	{checkSimpleArgs 1  1 {checkWord}}}
    {cmdcount	{checkSimpleArgs 0  0 {}}}
    {commands	{checkSimpleArgs 0  1 {checkPattern}}}
    {complete	{checkSimpleArgs 1  1 {checkWord}}}
    {default	{checkSimpleArgs 3  3 \
	    {checkWord checkWord checkVarNameWrite}}}
    {exists	{checkSimpleArgs 1  1 {checkVarNameSyntax}}}
    {globals	{checkSimpleArgs 0  1 {checkPattern}}}
    {hostname	{checkSimpleArgs 0  0 {}}}
    {level	{checkSimpleArgs 0  1 {checkInt}}}
    {library	{checkSimpleArgs 0  0 {}}}
    {loaded	{checkSimpleArgs 0  1 {checkWord}}}
    {locals	{checkSimpleArgs 0  1 {checkPattern}}}
    {nameofexecutable	{checkSimpleArgs 0  0 {}}}
    {patchlevel	{checkSimpleArgs 0  0 {}}}
    {procs	{checkSimpleArgs 0  1 {checkPattern}}}
    {script	{checkSimpleArgs 0  0 {}}}
    {sharedlibextension	{checkSimpleArgs 0  0 {}}}
    {tclversion	{checkSimpleArgs 0  0 {}}}
    {vars	{checkSimpleArgs 0  1 {checkPattern}}}
} {}}}}
pcx::check 7.5 std interp		{checkOption {
    {alias		{checkNumArgs {
	{2  {checkSimpleArgs 2 2 {
	    checkList checkWord}}
	}
	{3  {checkSimpleArgs 3 3 {
	    checkList checkWord \
		    {checkKeyword 1 {{}}}}}
	}
	{-1 {checkSimpleArgs 4 -1 {
	    checkList checkWord checkList checkWord}}}}
	}
    }
    {aliases		{checkSimpleArgs 0  1 {checkList}}}
    {create 		{checkSwitches 0 {
	-safe --
    } {checkSimpleArgs 0 1 {{checkDoubleDash checkList}}}}}
    {delete 		{checkSimpleArgs 0 -1 {checkList}}}
    {eval 		{checkSimpleArgs 2 -1 \
	    {checkList checkEvalArgs}}}
    {exists 		{checkSimpleArgs 1  1 {checkList}}}
    {issafe		{checkSimpleArgs 0  1 {checkList}}}
    {share 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}
    }
    {slaves 		{checkSimpleArgs 0  1 {checkList}}}
    {target 		{checkSimpleArgs 2  2 {checkList checkWord}}}
    {transfer 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}
    }
} {}}
pcx::check 7.5 std    load	{checkSimpleArgs 1  3 {checkFileName checkWord checkList}}
pcx::check 7.5 std    package	{checkSimpleArgs 1 4 {{checkOption {
    {forget	 	{checkSimpleArgs 1 1 {checkWord}}}
    {ifneeded 		{checkSimpleArgs 2 3 {checkWord checkVersion checkBody}}}
    {names 		{checkSimpleArgs 0 0 {}}}
    {provide 		{checkSimpleArgs 1 2 {checkWord checkVersion}}}
    {require 		{checkSwitches 1 {-exact} {checkSimpleArgs 1 2 {checkWord checkVersion}}}}
    {unknown 		{checkSimpleArgs 0 1 {checkWord}}}
    {vcompare 		{checkSimpleArgs 2 2 {checkVersion}}}
    {versions 		{checkSimpleArgs 1 1 {checkWord}}}
    {vsatisfies 	{checkSimpleArgs 2 2 {checkVersion}}}
} {}}}}
pcx::check 7.5 std pkg_mkIndex	{checkSimpleArgs 2 -1 {checkFileName checkPattern}}
pcx::check 7.5 std socket	coreTcl::checkSocketCmd
pcx::check 7.5 std update	{checkSimpleArgs 0  1 {{checkKeyword 0 {idletasks}}}}
pcx::check 7.5 std vwait	{checkSimpleArgs 0  1 {checkVarName}}

## ### #### ##### ######

pcx::check 7.6 std file		{checkSimpleArgs 1 -1 {{checkOption {
    {atime 		{checkSimpleArgs 1 1 {checkFileName}}}
    {attributes 	{checkSimpleArgs 1 -1 {checkFileName
    {checkConfigure 1 {
	{-group {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-owner {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-permissions {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-archive {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-hidden {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-longname {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-readonly {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-shortname {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-system {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-creator {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-type {::analyzer::warn nonPortCmd {} {checkWord}}}}}}}
    }
    {copy 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {delete 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 1 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {dirname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {executable 	{checkSimpleArgs 1 1 {checkFileName}}}
    {exists 		{checkSimpleArgs 1 1 {checkFileName}}}
    {extension 		{checkSimpleArgs 1 1 {checkFileName}}}
    {isdirectory 	{checkSimpleArgs 1 1 {checkFileName}}}
    {isfile 		{checkSimpleArgs 1 1 {checkFileName}}}
    {join 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {lstat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {mkdir 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {mtime 		{checkSimpleArgs 1 1 {checkFileName}}}
    {nativename 	{checkSimpleArgs 1 1 {checkFileName}}}
    {owned 		{checkSimpleArgs 1 1 {checkFileName}}}
    {pathtype 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readable 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readlink 		{checkSimpleArgs 1 1 {checkFileName}}}
    {rename 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {rootname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {size 		{checkSimpleArgs 1 1 {checkFileName}}}
    {split 		{checkSimpleArgs 1 1 {checkFileName}}}
    {stat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {tail 		{checkSimpleArgs 1 1 {checkFileName}}}
    {type 		{checkSimpleArgs 1 1 {checkFileName}}} 
    {writable 		{checkSimpleArgs 1 1 {checkFileName}}}
} {}}}}

## ### #### ##### ######

pcx::check 8.0 std auto_import	{checkSimpleArgs 1  1 {checkPattern}}
pcx::check 8.0 std auto_mkindex_old {checkSimpleArgs 1 -1 {checkFileName checkPattern}}
pcx::check 8.0 std auto_qualify	{checkSimpleArgs 2 2 {checkWord checkNamespace}}
pcx::check 8.0 std tcl_findLibrary	{checkSimpleArgs 6 6 {checkWord checkVersion \
	checkWord checkBody checkVarNameWrite}}
pcx::check 8.0 std binary		{checkOption {
    {format	    {checkSimpleArgs 1 -1 {
	{coreTcl::checkBinaryFmt aAbBhHcsSiIfdxX@}
	checkWord}}
    }
    {scan	    {checkSimpleArgs 2 -1 {checkWord \
	    {coreTcl::checkBinaryFmt aAbBhHcsSiIfdxX@} \
	    checkVarNameWrite}}}
} {}}

pcx::check 8.0 std fconfigure	{checkSimpleArgs 1 -1 {checkChannelID {
    checkExtensibleConfigure 1 {
	{-blocking checkBoolean}
	{-buffering {checkKeyword 0 {full line none}}}
	{-buffersize checkInt}
	{-eofchar {checkListValues 0 2 {checkWord}}}
	{-peername {checkSimpleArgs 0 0 {}}}
	{-error {checkSimpleArgs 0 0 {}}}
	{-mode {coreTcl::checkSerialMode}}
	{-sockname {checkSimpleArgs 0 0 {}}}
	{-translation {checkListValues 0 2 {
	    {checkKeyword 1 {auto binary cr crlf lf}}}}}}
	}
    }
}
pcx::check 8.0 std fcopy	{checkSimpleArgs 2 6 {
    checkChannelID checkChannelID
    {checkSwitches 0 {
	{-size checkInt} 
	{-command checkBody}
    } {}}}
}

pcx::check 8.0 std history	{checkSimpleArgs 0 3 {{checkOption {
    {add 		{checkSimpleArgs 1 2 \
	    {checkBody {checkKeyword 0 {exec}}}}}
    {change 		{checkSimpleArgs 1 2 {checkWord}}}
    {clear 		{checkSimpleArgs 0 0 {}}}
    {event 		{checkSimpleArgs 0 1 {checkWord}}}
    {info 		{checkSimpleArgs 0 1 {checkInt}}}
    {keep 		{checkSimpleArgs 0 1 {checkInt}}}
    {nextid 		{checkSimpleArgs 0 0 {}}}
    {redo 		{checkSimpleArgs 0 1 {checkWord}}}
} {}}}}
pcx::check 8.0 std interp	{checkOption {
    {alias		{checkNumArgs {
	{2  {checkSimpleArgs 2 2 {checkList checkWord}}}
	{3  {checkSimpleArgs 3 3 {checkList checkWord \
		{checkKeyword 1 {{}}}}}}
	{-1 {checkSimpleArgs 4 -1 {
	    checkList checkWord checkList checkWord}}}}
	}
    }
    {aliases		{checkSimpleArgs 0  1 {checkList}}}
    {create 		{checkSwitches 0 {
	-safe --
    } {checkSimpleArgs 0 1 {{checkDoubleDash checkList}}}}}
    {delete 		{checkSimpleArgs 0 -1 {checkList}}}
    {eval 		{checkSimpleArgs 2 -1 \
	    {checkList checkEvalArgs}}}
    {exists 		{checkSimpleArgs 1  1 {checkList}}}
    {expose 		{checkSimpleArgs 2  3 {checkList checkWord}}}
    {hide 		{checkSimpleArgs 2  3 {checkList checkWord}}}
    {hidden 		{checkSimpleArgs 0  1 {checkList}}}
    {invokehidden 	{checkNumArgs {
	{1  {checkSimpleArgs 1  1 {checkList}}}
	{-1 {checkSimpleArgs 1 -1 {checkList \
		{checkSwitches 1 {
	    {-global checkWord}
	} {checkSimpleArgs 0 -1 {checkWord}}}}}}}}
    }
    {issafe		{checkSimpleArgs 0  1 {checkList}}}
    {marktrusted 	{checkSimpleArgs 1  1 {checkList}}}
    {share 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}}
	{slaves 		{checkSimpleArgs 0  1 {checkList}}}
	{target 		{checkSimpleArgs 2  2 {checkList checkWord}}}
	{transfer 		{checkSimpleArgs 3  3 {
	    checkList checkChannelID checkList}}
	}
    } {}
}

pcx::check 8.0 std lsort	{checkTailArgs \
	{checkHeadSwitches 0 1 {-ascii -integer -real -dictionary \
	{-command {checkProcCall 2}} -increasing \
	-decreasing {-index checkIndex}} {}} \
	{checkSimpleArgs 1 1 {checkList}} 1
}

# Explain 'namespace eval'. Order below is order of dynlit branches.
#
# Word 0	Word 1	
# Nsname	Script	Action
# ------	------	------
# Dynamic	Dynamic	Checking basics, in the current scope,
#			nothing is pushed.
# Dynamic	Literal	Check body in UNKNOWN scope, defer pushing
#			until after the name has been checked in
#			current scope.
# Literal	Dynamic	Checking basics, in the current scope,
#			nothing is pushed.
# Literal	Literal	Check the body in the scope given by the
#			name. We push before the name check opens
#			its scope.
# ------	------	------

pcx::check 8.0 std namespace	{trackNamespace {checkOption {
    {children		{checkSimpleArgs 0 2 \
	    {checkNamespace checkNamespacePattern}}}
    {code	    	{checkSimpleArgs 1 1 {checkWord}}}
    {current	    	{checkSimpleArgs 0 0 {}}}
    {delete	    	{checkSimpleArgs 0 -1 {checkNamespace}}}
    {eval	    	{
	checkDynLit 0 {
	    checkDynLit 1 {
		checkSimpleArgs 2 -1 {
		    checkNamespace
		    {checkEvalArgs body}
		}
	    } {
		checkSimpleArgs 2 -1 {checkNamespace {checkContext 2 0 {checkEvalArgs body}}}
	    }
	} {
	    checkDynLit 1 {
		checkSimpleArgs 2 -1 {checkNamespace {checkEvalArgs body}}
	    } {
		checkContext 2 0 {checkSimpleArgs 2 -1 {
		    {newNamespaceScope namespace checkNamespace}
		    {checkEvalArgs body}
		}}
	    }
	}
    }}
    {export	    	{checkSwitches 0 {
	-clear
    } {checkSimpleArgs 0 -1 \
	    {checkExportPattern}}}}
    {forget	    	{checkSimpleArgs 0 -1 {checkNamespacePattern}}}
    {import	    	{checkSwitches 0 {
	-force
    } {checkSimpleArgs 0 -1 \
	    {checkNamespacePattern}}}}
    {inscope	    	{checkSimpleArgs 2 -1 \
	    {checkNamespace checkWord}}}
    {origin	    	{checkSimpleArgs 1 1 {checkProcName}}}
    {parent	    	{checkSimpleArgs 0 1 {checkNamespace}}}
    {qualifiers	    	{checkSimpleArgs 1 1 {checkWord}}}
    {tail	    	{checkSimpleArgs 1 1 {checkWord}}}
    {which	    	{checkSwitches 0 {
	-command -variable
    } {checkSimpleArgs 1  1 {checkWord}}}}
} {}}}
pcx::check 8.0 std resource	{::analyzer::warn nonPortCmd {} {checkOption {
    {close 		{checkSimpleArgs 1 1 {checkWord}}}
    {list 		{checkSimpleArgs 1 2 \
	    {checkResourceType checkWord}}}
    {open 		{checkSimpleArgs 1 2 {
	checkFileName
	checkAccessMode}}
    }
    {read 		{checkSimpleArgs 2 3 \
	    {checkResourceType checkWord}}}
    {types 		{checkSimpleArgs 0 1 {checkWord}}}
    {write 		{checkSwitches 0 {
	{-id checkWord} \
		{-name checkWord} \
		{-file checkWord}
    } {checkSimpleArgs 2 2 \
	    {checkResourceType checkWord}}}}
} {}}}
pcx::check 8.0 std variable {checkAll {
    coreTcl::checkVariableCmd
    coreTcl::VarnameForConstant
}}

## ### #### ##### ######

pcx::check 8.1 std encoding	{checkSimpleArgs 1 3 {{checkOption {
    {convertfrom	{checkSimpleArgs 1 2 {checkWord}}}
    {convertto		{checkSimpleArgs 1 2 {checkWord}}}
    {names 		{checkSimpleArgs 0 0 {}}}
    {system		{checkSimpleArgs 0 1 {checkWord}}}
} {}}}}
pcx::check 8.1 std fconfigure	{checkSimpleArgs 1 -1 {checkChannelID {
    checkExtensibleConfigure 1 {
	{-blocking checkBoolean}
	{-buffering {checkKeyword 0 {full line none}}}
	{-buffersize checkInt}
	{-eofchar {checkListValues 0 2 {checkWord}}}
	{-error {checkSimpleArgs 0 0 {}}}
	{-encoding {checkWord}}
	{-peername {checkSimpleArgs 0 0 {}}}
	{-mode {coreTcl::checkSerialMode}}
	{-sockname {checkSimpleArgs 0 0 {}}}
	{-translation {checkListValues 0 2 {
	    {checkKeyword 1 {auto binary cr crlf lf}}}}}}
	}
    }
}
pcx::check 8.1 std lindex	{checkSimpleArgs 2  2 {checkList checkIndexExpr}}
pcx::check 8.1 std linsert	{checkSimpleArgs 3 -1 {checkList checkIndexExpr checkWord}}
pcx::check 8.1 std lrange	{checkSimpleArgs 3  3 {checkList checkIndexExpr}}
pcx::check 8.1 std lreplace	{checkSimpleArgs 3 -1 {checkList checkIndexExpr \
	checkIndexExpr checkWord}}
pcx::check 8.1 std regexp		{checkSwitches 1 {
    -nocase -indices -expanded -line -linestop \
	    -lineanchor {-about coreTcl::checkRegexpMarkAbout} --
} {coreTcl::checkRegexpHandleAbout}}
pcx::check 8.1 std string	{checkSimpleArgs 2 -1 {{checkOption {
    {bytelength		{checkSimpleArgs 1 1 {checkWord}}}
    {compare 		{checkHeadSwitches 0 2 {
	-nocase {-length checkInt}
    } {checkSimpleArgs 2 2 {checkWord}}}}
    {equal 		{checkHeadSwitches 0 2 {
	-nocase {-length checkInt}
    } {checkSimpleArgs 2 2 {checkWord}}}}
    {first 		{checkSimpleArgs 2 3 \
	    {checkWord checkWord checkIndexExpr}}}
    {index 		{checkSimpleArgs 2 2 \
	    {checkWord checkIndexExpr}}}
    {is			{checkSimpleArgs 2 -1 {
	{checkKeyword 0 { \
		alnum alpha ascii boolean control digit \
		double false graph integer lower print punct space \
		true upper wordchar xdigit}}
	{checkHeadSwitches 0 1 {
	    -strict {-failindex checkVarNameWrite}
	} {checkSimpleArgs 1 1 {checkWord}}}}}
    }
    {last 		{checkSimpleArgs 2 3 \
	    {checkWord checkWord checkIndexExpr}}}
    {length 		{checkSimpleArgs 1 1 {checkWord}}}
    {map 		{checkHeadSwitches 0 2 {
	-nocase
    } {checkSimpleArgs 2 2 {
	coreTcl::checkCharMap checkWord}}}
    }
    {match 		{checkHeadSwitches 0 2 {
	-nocase
    } {checkSimpleArgs 2 2 {
	checkPattern checkWord}}}
    }
    {range 		{checkSimpleArgs 3 3 \
	    {checkWord checkIndexExpr}}}
    {repeat 		{checkSimpleArgs 2 2 {checkWord checkInt}}}
    {replace 		{checkSimpleArgs 3 4 {
	checkWord checkIndexExpr
	checkIndexExpr checkWord}}
    }
    {tolower 		{checkSimpleArgs 1 3 \
	    {checkWord checkIndexExpr}}}
    {totitle 		{checkSimpleArgs 1 3 \
	    {checkWord checkIndexExpr}}}
    {toupper 		{checkSimpleArgs 1 3 \
	    {checkWord checkIndexExpr}}}
    {trim 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimleft 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimright 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {wordend 		{checkSimpleArgs 2 2 \
	    {checkWord checkIndexExpr}}}
    {wordstart 		{checkSimpleArgs 2 2 \
	    {checkWord checkIndexExpr}}}} {}}}
}


## ### #### ##### ######

pcx::check 8.2 std regsub	{checkSwitches 1 {
    -all -nocase -expanded -line -linestop \
	    -lineanchor -about --
} {checkSimpleArgs 4 4 \
       {{checkDoubleDash checkRegexp} checkWord checkWord checkVarNameWrite}}
}

## ### #### ##### ######

pcx::check 8.3 std auto_import	{::analyzer::warn coreTcl::warnAIPattern {} {checkSimpleArgs 1  1 {checkPattern}}}
pcx::check 8.3 std array	{checkSimpleArgs 2 3 {{checkOption {
    {anymore	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {donesearch	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {exists	    {checkSimpleArgs 1 1 {checkVarName}}}
    {get	    {checkSimpleArgs 1 2 {checkVarName checkPattern}}}
    {names	    {checkSimpleArgs 1 2 {checkVarName checkPattern}}}
    {nextelement    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {set	    {checkSimpleArgs 2 2 {checkVarNameWrite {checkListModNk 2 0}}}}
    {size	    {checkSimpleArgs 1 1 {checkVarName}}}
    {startsearch    {checkSimpleArgs 1 1 {checkVarName}}}
    {unset	    {checkSimpleArgs 1 2 {checkVarNameWrite checkPattern}}}
} {}}}}	
pcx::check 8.3 std clock	{checkSimpleArgs 1 6 {{checkOption {
    {clicks	    {checkSwitches 0 {
	{-milliseconds {}}
    } {}}}
    {format	    {checkSimpleArgs 1 5 {
	checkInt
	{checkSwitches 0 {
	    {-format coreTcl::checkClockFormat} 
	    {-gmt checkBoolean}
	} {}}}}
    }
    {scan	    {checkSimpleArgs 1 5 {
	checkWord
	{checkSwitches 0 {
	    {-base checkInt}
	    {-gmt checkBoolean}
	} {}}}}
    }
    {seconds	    {checkSimpleArgs 0 0 {}}}
} {}}}}
pcx::check 8.3 std fconfigure	{checkSimpleArgs 1 -1 {checkChannelID {
    checkExtensibleConfigure 1 {
	{-blocking checkBoolean}
	{-buffering {checkKeyword 0 {full line none}}}
	{-buffersize checkInt}
	{-eofchar {checkListValues 0 2 {checkWord}}}
	{-encoding {checkWord}}
	{-peername {checkSimpleArgs 0 0 {}}}
	{-error {checkSimpleArgs 0 0 {}}}
	{-lasterror {::analyzer::warn nonPortCmd {} {
	    checkSimpleArgs 0 0 {}}}}
	    {-mode {coreTcl::checkSerialMode}}
	    {-sockname {checkSimpleArgs 0 0 {}}}
	    {-translation {checkListValues 0 2 {
		{checkKeyword 1 {auto binary cr crlf lf}}}}}
	    }
	}
    }
}
pcx::check 8.3 std file	{checkSimpleArgs 1 -1 {{checkOption {
    {atime 		{checkSimpleArgs 1 2 {
	checkFileName checkWholeNum}}
    }
    {attributes 	{checkSimpleArgs 1 -1 {checkFileName
    {checkConfigure 1 {
	{-group {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-owner {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-permissions {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-archive {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-hidden {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-longname {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-readonly {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-shortname {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-system {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-creator {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-type {::analyzer::warn nonPortCmd {} {checkWord}}}}}}}
    }
    {channels 		{checkSimpleArgs 0 1 {checkPattern}}}
    {copy 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {delete 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 1 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {dirname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {executable 	{checkSimpleArgs 1 1 {checkFileName}}}
    {exists 		{checkSimpleArgs 1 1 {checkFileName}}}
    {extension 		{checkSimpleArgs 1 1 {checkFileName}}}
    {isdirectory 	{checkSimpleArgs 1 1 {checkFileName}}}
    {isfile 		{checkSimpleArgs 1 1 {checkFileName}}}
    {join 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {lstat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {mkdir 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {mtime 		{checkSimpleArgs 1 2 {
	checkFileName checkWholeNum}}
    }
    {nativename 	{checkSimpleArgs 1 1 {checkFileName}}}
    {owned 		{checkSimpleArgs 1 1 {checkFileName}}}
    {pathtype 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readable 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readlink 		{checkSimpleArgs 1 1 {checkFileName}}}
    {rename 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {rootname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {size 		{checkSimpleArgs 1 1 {checkFileName}}}
    {split 		{checkSimpleArgs 1 1 {checkFileName}}}
    {stat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {tail 		{checkSimpleArgs 1 1 {checkFileName}}}
    {type 		{checkSimpleArgs 1 1 {checkFileName}}} 
    {volumes 		{checkSimpleArgs 0 0 {}}} 
    {writable 		{checkSimpleArgs 1 1 {checkFileName}}}
} {}}}}
pcx::check 8.3 std glob		{checkSwitches 0 {
    {-directory checkFileName}
    -join
    -nocomplain 
    {-path checkFileName}
    {-types checkWord}
    --
} {checkSimpleArgs 1 -1 {{checkDoubleDash checkPattern} checkPattern}}}

pcx::check 8.3 std lsort	{checkTailArgs {checkHeadSwitches 0 1 {
    -ascii -integer -real -dictionary 
    {-command {checkProcCall 2}} 
    -increasing -decreasing {-index checkIndexExpr} 
    -unique} {}} {checkSimpleArgs 1 1 {checkList}} 1
}
pcx::check 8.3 std package	{checkSimpleArgs 1 4 {{checkOption {
    {forget	 	{checkSimpleArgs 1 1 {
	checkWord
    }}}
    {ifneeded 		{checkSimpleArgs 2 3 {
	{checkSetStyle pkgname checkWord}
	checkVersion
	checkBody
    }}}
    {names 		{checkSimpleArgs 0 0 {}}}
    {present 		{checkSwitches 1 {-exact} {checkSimpleArgs 1 2 {
	checkWord
	checkVersion
    }}}}
    {provide 		{checkSimpleArgs 1 2 {
	{checkNumArgs {
	    {1 {
		checkWord
	    }}
	    {2 {checkSimpleArgs 2 2 {
		{checkSetStyle pkgname checkWord}
		checkVersion
	    }}}
	}}
    }}}
    {require 		{checkSwitches 1 {-exact} {checkSimpleArgs 1 2 {
	checkWord
	checkVersion
    }}}}
    {unknown 		{checkSimpleArgs 0 1 {{checkProcCall 2}}}}
    {vcompare 		{checkSimpleArgs 2 2 {checkVersion}}}
    {versions 		{checkSimpleArgs 1 1 {
	checkWord
    }}}
    {vsatisfies 	{checkSimpleArgs 2 2 {checkVersion}}}
} {}}}}

pcx::check 8.3 std pkg_mkIndex	{checkSwitches 1 {-lazy} {checkSimpleArgs 2 -1 {
    checkFileName checkPattern}}
}
pcx::check 8.3 std regexp		{checkSwitches 1 {
    -nocase -indices -expanded -line -linestop \
	-lineanchor {-about coreTcl::checkRegexpMarkAbout} -all -inline \
	    {-start checkInt} --
} {coreTcl::checkRegexpHandleAbout}}
pcx::check 8.3 std regsub		{checkSwitches 1 {
    -all -nocase -expanded -line -linestop \
	    -lineanchor -about {-start checkInt} --
} {checkSimpleArgs 4 4 \
       {{checkDoubleDash checkRegexp} checkWord checkWord checkVarNameWrite}}
}
pcx::check 8.3 std scan	{checkSimpleArgs 2 -1 \
	{checkWord coreTcl::checkScanFmt checkVarNameWrite}}

## ### #### ##### ######

pcx::check 8.4 std array {
    checkSimpleArgs 2 4 {
	{
	    checkOption {
		{anymore    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
		{donesearch {checkSimpleArgs 2 2 {checkVarName checkWord}}}
		{exists	    {checkSimpleArgs 1 1 {checkVarName}}}
		{get	    {checkSimpleArgs 1 2 {checkVarName checkPattern}}}
		{
		    names {
			checkNumArgs {
			    {1 {checkSimpleArgs 1 1 {checkVarName}}}
			    {2 {checkSimpleArgs 2 2 {checkVarName checkPattern}}}
			    {3 {checkSimpleArgs 3 3 {
				checkVarName
				{checkKeyword 1 {-exact -glob -regexp}}
				checkPattern}}
			    }
			}
		    }
		}
		{nextelement {checkSimpleArgs 2 2 {checkVarName checkWord}}}
		{set	     {checkSimpleArgs 2 2 {checkVarNameWrite {checkListModNk 2 0}}}}
		{size	     {checkSimpleArgs 1 1 {checkVarName}}}
		{startsearch {checkSimpleArgs 1 1 {checkVarName}}}
		{unset	     {checkSimpleArgs 1 2 {checkVarNameWrite checkPattern}}}
		{statistics  {checkSimpleArgs 1 1 {checkVarName}}}
	    } {}
	}
    }
}
pcx::check 8.4 std auto_load	{checkSimpleArgs 1  2 {checkWord}}
pcx::check 8.4 std binary {
    checkOption {
	{
	    format {
		checkSimpleArgs 1 -1 {
		    {coreTcl::checkBinaryFmt aAbBhHcsSiIfdxXwW@}
		    checkWord
		}
	    }
	}
	{
	    scan {
		checkSimpleArgs 2 -1 {
		    checkWord
		    {coreTcl::checkBinaryFmt aAbBhHcsSiIfdxXwW@}
		    checkVarNameWrite
		}
	    }
	}
    } {}
}
pcx::check 8.4 std fconfigure	{
    checkSimpleArgs 1 -1 {
	checkChannelID {
	    checkExtensibleConfigure 1 {
		{-blocking   checkBoolean}
		{-buffering  {checkKeyword 0 {full line none}}}
		{-buffersize checkInt}
		{-eofchar    {checkListValues 0 2 {checkWord}}}
		{-encoding   {checkWord}}
		{-peername   {checkSimpleArgs 0 0 {}}}
		{-error {checkSimpleArgs 0 0 {}}}
		{
		    -lasterror
		    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
		}
		{-mode {coreTcl::checkSerialMode}}
		{-sockname {checkSimpleArgs 0 0 {}}}
		{
		    -translation
		    {checkListValues 0 2 {{checkKeyword 1 {auto binary cr crlf lf}}}}
		} {
		    -handshake
		    {
			::analyzer::warn nonPortCmd {} {
			    checkKeyword 1 {none rtscts xonxoff dtrdsr}
			}
		    }
		} {
		    -queue
		    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
		} {
		    -timeout
		    {::analyzer::warn nonPortCmd {} {checkNatNum}}
		} {
		    -ttycontrol
		    {
			::analyzer::warn nonPortCmd {} {				    
			    checkDictValues 2 \
				    {checkKeywordNC 1 {txd rxd rts cts dtr dsr dcd ri break}} \
				    checkBoolean
			}
		    }
		} {
		    -ttystatus
		    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
		} {
		    -xchar
		    {::analyzer::warn nonPortCmd {} {checkListValues 2 2 {checkWord}}}
		} {
		    -pollinterval
		    {::analyzer::warn nonPortCmd {} {checkNatNum}}
		} {
		    -sysbuffer
		    {::analyzer::warn nonPortCmd {} {checkListValues 1 2 {checkNatNum}}}
		}
	    }
	}
    }
}
pcx::check 8.4 std fcopy {
    ::analyzer::warn warnBehaviourCmd "now respects value of \"-encoding\"" \
	    {checkSimpleArgs 2 6 {
	checkChannelID checkChannelID
	{checkSwitches 0 {
	    {-size checkInt} 
	    {-command checkBody}
	} {}}}
    }
}

pcx::check 8.4 std file	{checkSimpleArgs 1 -1 {{checkOption {
    {atime 		{checkSimpleArgs 1 2 {checkFileName checkWholeNum}}}
    {attributes 	{checkSimpleArgs 1 -1 {checkFileName
    {checkConfigure 1 {
	{-group {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-owner {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-permissions {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-archive {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-hidden {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-longname {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-readonly {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-shortname {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-system {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-creator {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-type {::analyzer::warn nonPortCmd {} {checkWord}}}}}}}
    }
    {channels 		{checkSimpleArgs 0 1 {checkPattern}}}
    {copy 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {delete 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 1 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {dirname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {executable 	{checkSimpleArgs 1 1 {checkFileName}}}
    {exists 		{checkSimpleArgs 1 1 {checkFileName}}}
    {extension 		{checkSimpleArgs 1 1 {checkFileName}}}
    {isdirectory 	{checkSimpleArgs 1 1 {checkFileName}}}
    {isfile 		{checkSimpleArgs 1 1 {checkFileName}}}
    {join 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {link {
	::analyzer::warn nonPortOption {} {
	    checkSimpleArgs 1 3 {
		{checkNumArgs {
		    {1 checkFileName}
		    {2 {checkSimpleArgs 2 2 {checkFileName checkFileName}}}
		    {3 {checkSimpleArgs 3 3 {{checkKeyword 0 {-symbolic -hard}} checkFileName checkFileName}}}}}
		}
	    }
	}
    }
    {lstat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {mkdir 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {mtime 		{checkSimpleArgs 1 2 {checkFileName checkWholeNum}}}
    {nativename 	{checkSimpleArgs 1 1 {checkFileName}}}
    {normalize 	{checkSimpleArgs 1 1 {checkFileName}}}
    {owned 		{checkSimpleArgs 1 1 {checkFileName}}}
    {pathtype 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readable 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readlink 		{checkSimpleArgs 1 1 {checkFileName}}}
    {rename 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {rootname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {separator 	{checkSimpleArgs 0 1 {checkFileName}}}
    {size 		{checkSimpleArgs 1 1 {checkFileName}}}
    {split 		{checkSimpleArgs 1 1 {checkFileName}}}
    {stat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {system 	{checkSimpleArgs 1 1 {checkFileName}}}
    {tail 		{checkSimpleArgs 1 1 {checkFileName}}}
    {type 		{checkSimpleArgs 1 1 {checkFileName}}} 
    {volumes 		{checkSimpleArgs 0 0 {}}} 
    {writable 		{checkSimpleArgs 1 1 {checkFileName}}}
} {}}}}
pcx::check 8.4 std format {
    checkSimpleArgs 1 -1 {coreTcl::checkFormatFmt checkWord}
}
pcx::check 8.4 std glob		{checkSwitches 0 {
    {-directory checkFileName}
    -join
    -nocomplain
    -tails
    {-path checkFileName}
    {-types checkWord}
    --
} {checkSimpleArgs 1 -1 {{checkDoubleDash checkPattern} checkPattern}}}
pcx::check 8.4 std info		{checkSimpleArgs 1 4 {{checkOption {
    {args	{checkSimpleArgs 1  1 {checkWord}}}
    {body	{checkSimpleArgs 1  1 {checkWord}}}
    {cmdcount	{checkSimpleArgs 0  0 {}}}
    {commands	{checkSimpleArgs 0  1 {checkPattern}}}
    {complete	{checkSimpleArgs 1  1 {checkWord}}}
    {default	{checkSimpleArgs 3  3 \
	    {checkWord checkWord checkVarNameWrite}}}
    {functions	{checkSimpleArgs 0  1 {checkPattern}}}
    {exists	{checkSimpleArgs 1  1 {checkVarNameSyntax}}}
    {globals	{checkSimpleArgs 0  1 {checkPattern}}}
    {hostname	{checkSimpleArgs 0  0 {}}}
    {level	{checkSimpleArgs 0  1 {checkInt}}}
    {library	{checkSimpleArgs 0  0 {}}}
    {loaded	{checkSimpleArgs 0  1 {checkWord}}}
    {locals	{checkSimpleArgs 0  1 {checkPattern}}}
    {nameofexecutable	{checkSimpleArgs 0  0 {}}}
    {patchlevel	{checkSimpleArgs 0  0 {}}}
    {procs	{checkSimpleArgs 0  1 {checkPattern}}}
    {script	{checkSimpleArgs 0  1 {checkFileName}}}
    {sharedlibextension	{checkSimpleArgs 0  0 {}}}
    {tclversion	{checkSimpleArgs 0  0 {}}}
    {vars	{checkSimpleArgs 0  1 {checkPattern}}}
} {}}}}
pcx::check 8.4 std interp		{checkOption {
    {alias		{checkNumArgs {
	{2  {checkSimpleArgs 2 2 {
	    checkList checkWord}}
	}
	{3  {checkSimpleArgs 3 3 {
	    checkList checkWord \
		    {checkKeyword 1 {{}}}}}
	}
	{-1 {checkSimpleArgs 4 -1 {
	    checkList checkWord checkList checkWord}}}}
	}
    }
    {aliases		{checkSimpleArgs 0  1 {checkList}}}
    {create 		{checkSwitches 0 {
	-safe --
    } {checkSimpleArgs 0 1 {{checkDoubleDash checkList}}}}}
    {delete 		{checkSimpleArgs 0 -1 {checkList}}}
    {eval 		{checkSimpleArgs 2 -1 \
	    {checkList checkEvalArgs}}}
    {exists 		{checkSimpleArgs 1  1 {checkList}}}
    {expose 		{checkSimpleArgs 2  3 {checkList checkWord}}}
    {hide 		{checkSimpleArgs 2  3 {checkList checkWord}}}
    {hidden 		{checkSimpleArgs 0  1 {checkList}}}
    {invokehidden 	{checkNumArgs {
	{1  {checkSimpleArgs 1  1 {checkList}}}
	{-1 {checkSimpleArgs 1 -1 {checkList \
		{checkSwitches 1 {
	    {-global checkWord}
	} {checkSimpleArgs 0 -1 {checkWord}}}}}}}}
    }
    {issafe		{checkSimpleArgs 0  1 {checkList}}}
    {marktrusted 	{checkSimpleArgs 1  1 {checkList}}}
    {recursionlimit     {checkSimpleArgs 1  2 {checkList checkNatNum}}}
    {share 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}
    }
    {slaves 		{checkSimpleArgs 0  1 {checkList}}}
    {target 		{checkSimpleArgs 2  2 {checkList checkWord}}}
    {transfer 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}}
    } {}
}
pcx::check 8.4 std lindex		{
    checkSimpleArgs 1  -1 {
	checkList
	{checkArgsOrList checkIndexExpr}
    }
}
pcx::check 8.4 std lsearch {
    checkTailArgs {
	checkHeadSwitches 0 2 {
	    -exact -glob -regexp
	    -all -ascii -decreasing -dictionary
	    -increasing -inline -integer -not -real -sorted
	    {-start checkIndexExpr}
	} {}
    } {checkSimpleArgs 2 2 {checkList checkPattern}} 2}

pcx::check 8.4 std lset {
    checkSimpleArgs 2 -1 {
	checkVarNameReadWrite
	{checkTailArgs {
	    checkListValues 1 -1 checkIndexExpr
	} {checkWord} 1}
    }
}

pcx::check 8.4 std namespace	{trackNamespace {checkOption {
    {children		{checkSimpleArgs 0 2 \
	    {checkNamespace checkNamespacePattern}}}
    {code	    	{checkSimpleArgs 1 1 {checkWord}}}
    {current	    	{checkSimpleArgs 0 0 {}}}
    {delete	    	{checkSimpleArgs 0 -1 {checkNamespace}}}
    {eval	    	{
	checkDynLit 0 {
	    checkDynLit 1 {
		checkSimpleArgs 2 -1 {
		    checkNamespace
		    {checkEvalArgs body}
		}
	    } {
		checkSimpleArgs 2 -1 {checkNamespace {checkContext 2 0 {checkEvalArgs body}}}
	    }
	} {
	    checkDynLit 1 {
		checkSimpleArgs 2 -1 {checkNamespace {checkEvalArgs body}}
	    } {
		checkContext 2 0 {checkSimpleArgs 2 -1 {
		    {newNamespaceScope namespace checkNamespace}
		    {checkEvalArgs body}
		}}
	    }
	}
    }}
    {exists	    	{checkSimpleArgs 1 1 {checkNamespace}}}
    {export	    	{checkSwitches 0 {
	-clear
    } {checkSimpleArgs 0 -1 \
	    {checkExportPattern}}}}
    {forget	    	{checkSimpleArgs 0 -1 {checkNamespacePattern}}}
    {import	    	{checkSwitches 0 {
	-force
    } {checkSimpleArgs 0 -1 \
	    {checkNamespacePattern}}}}
    {inscope	    	{checkSimpleArgs 2 -1 \
	    {checkNamespace checkWord}}}
    {origin	    	{checkSimpleArgs 1 1 {checkProcName}}}
    {parent	    	{checkSimpleArgs 0 1 {checkNamespace}}}
    {qualifiers	    	{checkSimpleArgs 1 1 {checkWord}}}
    {tail	    	{checkSimpleArgs 1 1 {checkWord}}}
    {which	    	{checkSwitches 0 {
	-command -variable
    } {checkSimpleArgs 1  1 {checkWord}}}}
} {}}}
pcx::check 8.4 std pkg_mkIndex	{checkSwitches 1 {-lazy --} {checkSimpleArgs 2 -1 {
    {checkDoubleDash checkFileName} checkPattern}}
}
pcx::check 8.4 std regsub		{checkSwitches 1 {
    -all -nocase -expanded -line -linestop \
	    -lineanchor -about {-start checkInt} --
} {checkSimpleArgs 3 4 \
       {{checkDoubleDash checkRegexp} checkWord 
checkWord checkVarNameWrite}}}

pcx::check 8.4 std scan		{
    checkSimpleArgs 2 -1 {
	checkWord coreTcl::checkScanFmt checkVarNameWrite
    }
}
pcx::check 8.4 std source		{
    ::analyzer::warn warnBehaviourCmd \
	{now treats 0x1a as end-of-file character on all platforms} \
	coreTcl::checkSourceCmd
}
pcx::check 8.4 std subst {
    ::analyzer::warn warnBehaviourCmd \
	{now treats break and continue during command substituation differently} \
	{checkSwitches 0 {-nobackslashes -nocommands -novariables} {checkSimpleArgs 1 1 {checkWord}}}
}

# Bugzilla 34567: trace add|remove execution - Trivial fix, reducing
# min#args to 2.

# Note: We are not able to express the fact that the enter/enterstep
# callback requires 2 args, but a leave/leavestep callback requires
# _4_. Not to mention what happens if values from both sets are
# present in the list. In that case the callback has to handle both 2
# and 4 arguments.

pcx::check 8.4 std trace \
    {checkOption {
	{variable {
	    WarnDeprecated -2 {} {trace add variable} {
		{trace {
		    insert 1 add
		    get 4 wsplit {} wmap {r read w write u unset} wbracequote replace 4
		}}
	    } {
		checkSimpleArgs 3 3 {
		    checkVarName
		    coreTcl::checkTraceOp
		    {checkProcCall 3}
		}
	    }
	}}
	{vdelete {
	    WarnDeprecated -1 {} {trace remove variable} {
		{variable {
		    insert 1 remove 
		    get 4 wsplit {} wmap {r read w write u unset} wbracequote replace 4
		}}
	    } {
		checkSimpleArgs 3 3 {
		    checkVarName
		    coreTcl::checkTraceOp
		    {checkProcCall 3}
		}
	    }
	}}
	{vinfo {
	    WarnDeprecated -1 {} {trace info variable} {
		{variable {
		    insert 1 info
		}}
	    } {
		checkSimpleArgs 1 1 {
		    checkVarName
		}
	    }
	}}
	{add {checkOption {
	    {command {checkSimpleArgs 3 3 {
		checkProcName
		{checkListValues 0 -1 {
		    {checkKeyword 1 {rename delete}}
		}}
		{checkProcCall 3}
	    }}}
	    {variable {checkSimpleArgs 3 3 {
		checkVarName
		{checkListValues 0 -1 {
		    {checkKeyword 1 {array read write unset}}
		}}
		{checkProcCall 3}
	    }}}
	    {execution {checkConstrained {checkSimpleArgs 3 3 {
		checkProcName
		{checkListValues 1 -1 {
		    {checkOption {
			{enter     {checkSetConstraint enter checkNOP}}
			{leave     {checkSetConstraint leave checkNOP}}
			{enterstep {checkSetConstraint enter checkNOP}}
			{leavestep {checkSetConstraint leave checkNOP}}
		    } {}}
		}}
		{checkConstraint {
		    {{enter && leave} {checkProcCall 5}}
		    {enter            {checkProcCall 3}}
		    {leave            {checkProcCall 5}}
		} {checkProcCall 5}}
	    }}}}
	} {}}}
	{remove {checkOption {
	    {command {checkSimpleArgs 3 3 {
		checkProcName
		{checkListValues 0 -1 {
		    {checkKeyword 1 {rename delete}}
		}}
		{checkProcCall 3}
	    }}}
	    {variable {checkSimpleArgs 3 3 {
		checkVarName
		{checkListValues 0 -1 {
		    {checkKeyword 1 {array read write unset}}
		}}
		{checkProcCall 3}
	    }}}
	    {execution {checkConstrained {checkSimpleArgs 3 3 {
		checkProcName
		{checkListValues 1 -1 {
		    {checkOption {
			{enter     {checkSetConstraint enter checkNOP}}
			{leave     {checkSetConstraint leave checkNOP}}
			{enterstep {checkSetConstraint enter checkNOP}}
			{leavestep {checkSetConstraint leave checkNOP}}
		    } {}}
		}}
		{checkConstraint {
		    {{enter && leave} {checkProcCall 5}}
		    {enter            {checkProcCall 3}}
		    {leave            {checkProcCall 5}}
		} {checkProcCall 5}}
	    }}}}
	} {}}}
	{info {checkOption {
	    {command   {checkSimpleArgs 1 1 {checkProcName}}}
	    {variable  {checkSimpleArgs 1 1 {checkVarName}}}
	    {execution {checkSimpleArgs 1 1 {checkProcName}}}
	} {}}}
    } {}}

pcx::check 8.4 std unset {
    checkRestrictedSwitches 1 {-nocomplain --} {
	checkSimpleArgs 1 -1 {{checkDoubleDash checkVarNameWrite} checkVarNameWrite}
    }
}

# ### ######### ###########################

pcx::check 8.5 std apply {checkSimpleArgs 1 -1 {
    {checkListValues 2 3 {
	{checkDynLit 2 {
	    checkSimpleArgs 2 3 {
		checkArgList
		{checkOrdering {checkBody}}
		checkNamespace
	    }
	} {
	    checkContext 2 0 {checkSimpleArgs 2 3 {
		{newScope apply checkArgList}
		{checkOrdering {checkBody}}
		checkNamespace
	    }}
	}}
    }} checkWord
}}

pcx::check 8.5 std binary {
    checkOption {
	{
	    format {
		checkSimpleArgs 1 -1 {
		    {coreTcl::checkBinaryFmtWithFlags aAbBhHcsSiIfdxXwW@tnmrRqQ u}
		    checkWord
		}
	    }
	}
	{
	    scan {
		checkSimpleArgs 2 -1 {
		    checkWord
		    {coreTcl::checkBinaryFmtWithFlags aAbBhHcsSiIfdxXwW@tnmrRqQ u}
		    checkVarNameWrite
		}
	    }
	}
    } {}
}

pcx::check 8.5 std catch \
    {checkSimpleArgs 1 3 {
	{checkAsStyle body/single-line checkBody}
	checkVarNameWrite
	checkVarNameWrite
    }}

pcx::check 8.5 std chan {
    checkSimpleArgs 1 -1 {
	{checkOption {
	    {blocked   {checkSimpleArgs 1 1 {checkChannelID}}}
	    {close     {checkSimpleArgs 1 1 {checkChannelID}}}
	    {configure {checkSimpleArgs 1 -1 {
		checkChannelID {
		    checkExtensibleConfigure 1 {
			{-blocking   checkBoolean}
			{-buffering  {checkKeyword 0 {full line none}}}
			{-buffersize checkInt}
			{-eofchar    {checkListValues 0 2 {checkWord}}}
			{-encoding   {checkWord}}
			{-peername   {checkSimpleArgs 0 0 {}}}
			{-error {checkSimpleArgs 0 0 {}}}
			{
			    -lasterror
			    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
			}
			{-mode {coreTcl::checkSerialMode}}
			{-sockname {checkSimpleArgs 0 0 {}}}
			{
			    -translation
			    {checkListValues 0 2 {{checkKeyword 1 {auto binary cr crlf lf}}}}
			} {
			    -handshake
			    {
				::analyzer::warn nonPortCmd {} {
				    checkKeyword 1 {none rtscts xonxoff dtrdsr}
				}
			    }
			} {
			    -queue
			    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
			} {
			    -timeout
			    {::analyzer::warn nonPortCmd {} {checkNatNum}}
			} {
			    -ttycontrol
			    {
				::analyzer::warn nonPortCmd {} {				    
				    checkDictValues 2 \
					{checkKeywordNC 1 {txd rxd rts cts dtr dsr dcd ri break}} \
					checkBoolean
				}
			    }
			} {
			    -ttystatus
			    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
			} {
			    -xchar
			    {::analyzer::warn nonPortCmd {} {checkListValues 2 2 {checkWord}}}
			} {
			    -pollinterval
			    {::analyzer::warn nonPortCmd {} {checkNatNum}}
			} {
			    -sysbuffer
			    {::analyzer::warn nonPortCmd {} {checkListValues 1 2 {checkNatNum}}}
			}
		    }
		}
	    }}}
	    {copy      {::analyzer::warn warnBehaviourCmd {now respects value of "-encoding"} {checkSimpleArgs 2 6 {
		checkChannelID checkChannelID
		{checkSwitches 0 {
		    {-size checkInt} 
		    {-command checkBody}
		} {}}}
	    }}}
	    {create    {checkSimpleArgs 2 2 {
		{checkListValues 1 -1 {{checkKeyword 0 {read write}}}}
		checkWord
	    }}}
	    {eof       {checkSimpleArgs 1 1 {checkChannelID}}}
	    {event     {checkSimpleArgs 2 3 {checkChannelID {checkKeyword 0 {
		readable writable
	    }} checkBody}}}
	    {flush     {checkSimpleArgs 1 1 {checkChannelID}}}
	    {gets      {checkSimpleArgs 1 2 {checkChannelID checkVarNameWrite}}}
	    {names     {checkSimpleArgs 0 1 {checkPattern}}}
	    {pending   {checkSimpleArgs 2 2 {
		{checkKeyword 0 {input output}}
		checkChannelID
	    }}}
	    {postevent {checkSimpleArgs 2 2 {
		checkChannelID
		{checkListValues 1 -1 {{checkKeyword 0 {read write}}}}
	    }}}
	    {puts      {checkOption {
		{-nonewline {checkNumArgs {
		    {1  {checkSimpleArgs 1 1 {checkWord}}}
		    {-1 {checkSimpleArgs 2 3 {
			checkChannelID checkWord 
			{checkKeyword 0 nonewline}}}}}
		}}
	    } {checkNumArgs {
		{1  {checkSimpleArgs 1 1 {checkWord}}}
		{-1 {checkSimpleArgs 2 3 {
		    checkChannelID checkWord 
		    {checkKeyword 0 nonewline}}}}}}}}
	    {read      {coreTcl::checkReadCmd 1}}
	    {seek      {checkSimpleArgs 2 3 {checkChannelID checkInt {checkKeyword 0 {start current end}}}}}
	    {tell      {checkSimpleArgs 1 1 {checkChannelID}}}
	    {truncate  {checkSimpleArgs 1 2 {checkChannelID checkWholeNum}}}
	} {}}
    }
}

pcx::check 8.5 std clock \
    {checkSimpleArgs 1 -1 {
	{checkOption {
	    {add {checkSimpleArgs 1 -1 {
		checkInt
		{checkConstrained {checkSequence {
		    {coreTcl::checkClockUnits {
			{-format   {checkSetConstraint hasfmt coreTcl::checkClockFormat}}
			{-locale   {checkSetConstraint hasloc checkWord}}
			{-timezone {checkSetConstraint hastz  checkWord}}
			{-gmt      checkBoolean}
		    }}
		    {checkConstraint {
			{{!hasfmt && hasloc} {warn coreTcl::badLocale {} checkNOP}}
		    } {}}
		    {checkConstraint {
			{{!hasfmt && hastz}  {warn coreTcl::badTimezone {} checkNOP}}
		    } {}}
		}}}
	    }}}
	    {clicks {checkSimpleArgs 0 1 {
		{checkOption {
		    {-milliseconds {
			WarnDeprecated -2 {} {clock milliseconds} {
			    {milliseconds {ldrop 2}}
			} {checkNOP}
		    }}
		} {}}
	    }}}
	    {format {checkSimpleArgs 1 9 {
		checkInt
		{checkConstrained {checkSequence {
		    {checkSwitches 0 {
			{-format   {checkSetConstraint hasfmt coreTcl::checkClockFormat}}
			{-locale   {checkSetConstraint hasloc checkWord}}
			{-timezone {checkSetConstraint hastz  checkWord}}
			{-gmt      checkBoolean}
		    } {}}
		    {checkConstraint {
			{{!hasfmt && hasloc} {warn coreTcl::badLocale {} checkNOP}}
		    } {}}
		    {checkConstraint {
			{{!hasfmt && hastz}  {warn coreTcl::badTimezone {} checkNOP}}
		    } {}}
		}}}
	    }}}
	    {microseconds {checkAtEnd}}
	    {milliseconds {checkAtEnd}}
	    {scan         {checkSimpleArgs 1 11 {
		checkWord
		{checkConstrained {checkSequence {
		    {checkSwitches 0 {
			{-format   {checkSetConstraint hasfmt coreTcl::checkClockFormat}}
			{-locale   {checkSetConstraint hasloc checkWord}}
			{-timezone {checkSetConstraint hastz  checkWord}}
			{-base     checkInt}
			{-gmt      checkBoolean}
		    } {}}
		    {checkConstraint {
			{{!hasfmt && hasloc} {warn coreTcl::badLocale {} checkNOP}}
		    } {}}
		    {checkConstraint {
			{{!hasfmt && hastz}  {warn coreTcl::badTimezone {} checkNOP}}
		    } {}}
		}}}
	    }}}
	    {seconds {checkAtEnd}}
	} {}}
    }}

if 0 {pcx::check 8.5 std close {
    WarnDeprecated -1 {} {chan close} {
	{chan {insert 1 close}}
    } {
	checkSimpleArgs 1 1 {checkChannelID}
    }
}}

pcx::check 8.5 std close \
    {checkSimpleArgs 1 1 {
	checkChannelID
    }}

pcx::check 8.5 std dict {checkSimpleArgs 1 -1 {{checkOption {
    {append  {checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}}
    {create  {checkSimpleArgsModNk 0 -1 2 0 {checkWord}}}
    {exists  {checkSimpleArgs 2 -1 {checkDict checkWord}}}
    {filter  {checkSimpleArgs 3 4  {checkDict {checkOption {
	{key    {checkSimpleArgs 1 1 checkPattern}}
	{value  {checkSimpleArgs 1 1 checkPattern}}
	{script {checkSimpleArgs 2 2 {
	    {checkListValues 2 2 {
		checkVarNameWrite
		checkVarNameWrite}}
	    checkBody}}}
    } {}}}}}
    {for     {coreTcl::checkDictForCmd}}
    {get     {checkSimpleArgs 1 -1 {checkDict checkWord}}}
    {incr    {checkSimpleArgs 2 3  {checkVarNameWrite checkWord checkInt}}}
    {info    {checkSimpleArgs 1 1  {checkDict}}}
    {keys    {checkSimpleArgs 1 2  {checkDict checkPattern}}}
    {lappend {checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}}
    {merge   {checkSimpleArgs 0 -1 {checkDict}}}
    {remove  {checkSimpleArgs 1 -1 {checkDict checkWord}}}
    {replace {checkSimpleArgsModNk 1 -1 2 1 {checkDict checkWord}}}
    {set     {checkSimpleArgs 3 -1 {checkVarNameWrite checkWord checkWord}}}
    {size    {checkSimpleArgs 1 1  {checkDict}}}
    {unset   {checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}}
    {update  {checkSimpleArgsModNk 4 -1 2 0 {
	checkVarNameWrite
	{checkTailArgs {checkSequence {checkWord checkVarNameWrite}} {checkBody} 1}
    }}}
    {values  {checkSimpleArgs 1 2  {checkDict checkPattern}}}
    {with    {checkSimpleArgs 2 -1 {
	checkVarNameWrite
	{checkTailArgs {checkWord} {checkBody} 1}
    }}}
} {}}}}

pcx::check 8.5 std encoding	{checkSimpleArgs 1 3 {{checkOption {
    {convertfrom	{checkSimpleArgs 1 2 {checkWord}}}
    {convertto		{checkSimpleArgs 1 2 {checkWord}}}
    {dirs               {checkSimpleArgs 0 1 {checkFileName}}}
    {names 		{checkSimpleArgs 0 0 {}}}
    {system		{checkSimpleArgs 0 1 {checkWord}}}
} {}}}}

if 0 {pcx::check 8.5 std eof		{
    WarnDeprecated -1 {} {chan eof} {
	{chan {insert 1 eof}}
    } {
	checkSimpleArgs 1 1 {checkChannelID}
    }
}}
pcx::check 8.5 std eof	\
    {checkSimpleArgs 1 1 {
	checkChannelID
    }}
pcx::check 8.5 std exec		{checkSwitches 1 {
    -keepnewline -ignorestderr --
} {checkDoubleDash {checkSimpleArgs 1 -1 {
    {coreTcl::ExecReplacements checkWord}
    checkWord
}}}}

pcx::check 8.5 std fblocked {
    WarnDeprecated -1 {} {chan blocked} {
	{chan {insert 1 blocked}}
    } {
	checkSimpleArgs 1 1 {checkChannelID}
    }
}

pcx::check 8.5 std fconfigure	{
    WarnDeprecated -1 {} {chan configure} {{chan {insert 1 configure}}} {
	checkSimpleArgs 1 -1 {
	    checkChannelID {
		checkExtensibleConfigure 1 {
		    {-blocking   checkBoolean}
		    {-buffering  {checkKeyword 0 {full line none}}}
		    {-buffersize checkInt}
		    {-eofchar    {checkListValues 0 2 {checkWord}}}
		    {-encoding   {checkWord}}
		    {-peername   {checkSimpleArgs 0 0 {}}}
		    {-error {checkSimpleArgs 0 0 {}}}
		    {
			-lasterror {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
		    }
		    {-mode {coreTcl::checkSerialMode}}
		    {-sockname {checkSimpleArgs 0 0 {}}}
		    {
			-translation
			{checkListValues 0 2 {{checkKeyword 1 {auto binary cr crlf lf}}}}
		    } {
			-handshake
			{
			    ::analyzer::warn nonPortCmd {} {
				checkKeyword 1 {none rtscts xonxoff dtrdsr}
			    }
			}
		    } {
			-queue
			{::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
		    } {
			-timeout
			{::analyzer::warn nonPortCmd {} {checkNatNum}}
		    } {
			-ttycontrol
			{
			    ::analyzer::warn nonPortCmd {} {				    
				checkDictValues 2 \
				    {checkKeywordNC 1 {txd rxd rts cts dtr dsr dcd ri break}} \
				    checkBoolean
			    }
			}
		    } {
			-ttystatus
			{::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
		    } {
			-xchar
			{::analyzer::warn nonPortCmd {} {checkListValues 2 2 {checkWord}}}
		    } {
			-pollinterval
			{::analyzer::warn nonPortCmd {} {checkNatNum}}
		    } {
			-sysbuffer
			{::analyzer::warn nonPortCmd {} {checkListValues 1 2 {checkNatNum}}}
		    }
		}
	    }
	}
    }
}

pcx::check 8.5 std fcopy {
    WarnDeprecated -1 {} {chan copy} {
	{chan {insert 1 copy}}
    } {
	::analyzer::warn warnBehaviourCmd {now respects value of "-encoding"} {
	    checkSimpleArgs 2 6 {
		checkChannelID checkChannelID
		{checkSwitches 0 {
		    {-size checkInt} 
		    {-command checkBody}
		} {}}}
	}
    }
}

pcx::check 8.5 std file	{checkSimpleArgs 1 -1 {{checkOption {
    {atime 		{checkSimpleArgs 1 2 {checkFileName checkWholeNum}}}
    {attributes 	{checkSimpleArgs 1 -1 {checkFileName
    {checkConfigure 1 {
	{-group       {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-owner       {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-permissions {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-archive     {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-hidden      {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-longname    {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-readonly    {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-rsrclength  {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-shortname   {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-system      {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-creator     {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-type        {::analyzer::warn nonPortCmd {} {checkWord}}}}}}}
    }
    {channels 		{checkSimpleArgs 0 1 {
	{WarnDeprecated -2 {} {chan names} {
	    {chan {ldrop 1 insert 1 names}}
	} {
	    checkPattern
	}}
    }}}
    {copy 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {delete 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 1 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {dirname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {executable 	{checkSimpleArgs 1 1 {checkFileName}}}
    {exists 		{checkSimpleArgs 1 1 {checkFileName}}}
    {extension 		{checkSimpleArgs 1 1 {checkFileName}}}
    {isdirectory 	{checkSimpleArgs 1 1 {checkFileName}}}
    {isfile 		{checkSimpleArgs 1 1 {checkFileName}}}
    {join 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {link {
	::analyzer::warn nonPortOption {} {
	    checkSimpleArgs 1 3 {
		{checkNumArgs {
		    {1 checkFileName}
		    {2 {checkSimpleArgs 2 2 {checkFileName checkFileName}}}
		    {3 {checkSimpleArgs 3 3 {{checkKeyword 0 {-symbolic -hard}} checkFileName checkFileName}}}}}
		}
	    }
	}
    }
    {lstat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {mkdir 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {mtime 		{checkSimpleArgs 1 2 {checkFileName checkWholeNum}}}
    {nativename 	{checkSimpleArgs 1 1 {checkFileName}}}
    {normalize 	{checkSimpleArgs 1 1 {checkFileName}}}
    {owned 		{checkSimpleArgs 1 1 {checkFileName}}}
    {pathtype 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readable 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readlink 		{checkSimpleArgs 1 1 {checkFileName}}}
    {rename 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {rootname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {separator 	{checkSimpleArgs 0 1 {checkFileName}}}
    {size 		{checkSimpleArgs 1 1 {checkFileName}}}
    {split 		{checkSimpleArgs 1 1 {checkFileName}}}
    {stat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {system 	{checkSimpleArgs 1 1 {checkFileName}}}
    {tail 		{checkSimpleArgs 1 1 {checkFileName}}}
    {type 		{checkSimpleArgs 1 1 {checkFileName}}} 
    {volumes 		{checkSimpleArgs 0 0 {}}} 
    {writable 		{checkSimpleArgs 1 1 {checkFileName}}}
} {}}}}

pcx::check 8.5 std fileevent	{
    WarnDeprecated -1 {} {chan event} {
	{chan {insert 1 event}}
    } {
	checkSimpleArgs 2 3 {checkChannelID {checkKeyword 0 {readable writable}} checkBody}
    }
}
if 0 {    WarnDeprecated -1 {} {chan flush} {
	{chan {insert 1 flush}}
    } {
    }
}
pcx::check 8.5 std flush	{
    checkSimpleArgs 1 1 {checkChannelID}
}

pcx::check 8.5 std format \
    {checkSimpleArgs 1 -1 {
	coreTcl::checkFormatFmt85
	checkWord
    }}
if 0 {    WarnDeprecated -1 {} {chan gets} {
	{chan {insert 1 gets}}
    } {
    }
}
pcx::check 8.5 std gets		{
	checkSimpleArgs 1 2 {checkChannelID checkVarNameWrite}
}

pcx::check 8.5 std info		{checkSimpleArgs 1 4 {{checkOption {
    {args	{checkSimpleArgs 1  1 {checkWord}}}
    {body	{checkSimpleArgs 1  1 {checkWord}}}
    {cmdcount	{checkSimpleArgs 0  0 {}}}
    {commands	{checkSimpleArgs 0  1 {checkPattern}}}
    {complete	{checkSimpleArgs 1  1 {checkWord}}}
    {default	{checkSimpleArgs 3  3 {checkWord checkWord checkVarNameWrite}}}
    {functions	{checkSimpleArgs 0  1 {checkPattern}}}
    {frame	{checkSimpleArgs 0  1 {checkInt}}}
    {exists	{checkSimpleArgs 1  1 {checkVarNameSyntax}}}
    {globals	{checkSimpleArgs 0  1 {checkPattern}}}
    {hostname	{checkSimpleArgs 0  0 {}}}
    {level	{checkSimpleArgs 0  1 {checkInt}}}
    {library	{checkSimpleArgs 0  0 {}}}
    {loaded	{checkSimpleArgs 0  1 {checkWord}}}
    {locals	{checkSimpleArgs 0  1 {checkPattern}}}
    {nameofexecutable	{checkSimpleArgs 0  0 {}}}
    {patchlevel	{checkSimpleArgs 0  0 {}}}
    {procs	{checkSimpleArgs 0  1 {checkPattern}}}
    {script	{checkSimpleArgs 0  1 {checkFileName}}}
    {sharedlibextension	{checkSimpleArgs 0  0 {}}}
    {tclversion	{checkSimpleArgs 0  0 {}}}
    {vars	{checkSimpleArgs 0  1 {checkPattern}}}
} {}}}}

pcx::check 8.5 std incr		{checkSimpleArgs 1  2 {checkVarNameWrite checkInt}}

pcx::check 8.5 std interp		{checkOption {
    {alias		{checkNumArgs {
	{2  {checkSimpleArgs 2 2 {
	    checkList checkWord}}
	}
	{3  {checkSimpleArgs 3 3 {
	    checkList checkWord \
		    {checkKeyword 1 {{}}}}}
	}
	{-1 {checkSimpleArgs 4 -1 {
	    checkList checkWord checkList checkWord}}}}
	}
    }
    {aliases		{checkSimpleArgs 0  1 {checkList}}}
    {bgerror {checkSimpleArgs 1 2 {checkList checkWord}}}
    {create 		{checkSwitches 0 {
	-safe --
    } {checkSimpleArgs 0 1 {{checkDoubleDash checkList}}}}}
    {debug {checkSimpleArgs 1 -1 {
	checkList
	{checkSwitches 1 {
	    {-frame {checkBoolean}}
	} {}}
    }}}
    {delete 		{checkSimpleArgs 0 -1 {checkList}}}
    {eval 		{checkSimpleArgs 2 -1 \
	    {checkList checkEvalArgs}}}
    {exists 		{checkSimpleArgs 1  1 {checkList}}}
    {expose 		{checkSimpleArgs 2  3 {checkList checkWord}}}
    {hide 		{checkSimpleArgs 2  3 {checkList checkWord}}}
    {hidden 		{checkSimpleArgs 0  1 {checkList}}}
    {invokehidden 	{checkNumArgs {
	{1  {checkSimpleArgs 1  1 {checkList}}}
	{-1 {checkSimpleArgs 1 -1 {checkList \
		{checkSwitches 1 {
		    {-global checkWord}
		    {-namespace checkNamespace}
	} {checkSimpleArgs 0 -1 {checkWord}}}}}}}}
    }
    {issafe		{checkSimpleArgs 0  1 {checkList}}}
    {limit {checkSimpleArgs 2 -1 {
	checkList
	{checkOption {
	    {time    {checkConfigure 1 {
		{-command      {checkList}}
		{-granularity  {checkNatNum}}
		{-seconds      {checkOption {{{} checkNOP}} checkNatNum}}
		{-milliseconds {checkOption {{{} checkNOP}} checkNatNum}}
	    }}}
	    {command {checkConfigure 1 {
		{-command     {checkList}}
		{-granularity {checkNatNum}}
		{-value       {checkOption {{{} checkNOP}} checkNatNum}}
	    }}}
	} {}}
    }}}
    {marktrusted 	{checkSimpleArgs 1  1 {checkList}}}
    {recursionlimit     {checkSimpleArgs 1  2 {checkList checkNatNum}}}
    {share 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}
    }
    {slaves 		{checkSimpleArgs 0  1 {checkList}}}
    {target 		{checkSimpleArgs 2  2 {checkList checkWord}}}
    {transfer 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}}
    } {}
}

pcx::check 8.5 std lassign		{
    checkSimpleArgs 2 -1 {
	checkList 
	checkVarNameWrite
    }
}

pcx::check 8.5 std lindex		{
    checkSimpleArgs 1  -1 {
	checkList
	{checkArgsOrList checkExtendedIndexExpr}
    }
}

pcx::check 8.5 std linsert	{
    checkSimpleArgs 3 -1 {
	checkList checkExtendedIndexExpr checkWord
    }
}

pcx::check 8.5 std lrange	{
    checkSimpleArgs 3  3 {
	checkList checkExtendedIndexExpr
    }
}

pcx::check 8.5 std lrepeat		{
    checkSimpleArgs 2 -1 {checkNatNum checkWord}
}

pcx::check 8.5 std lreplace	{
    checkSimpleArgs 3 -1 {
	checkList checkExtendedIndexExpr checkExtendedIndexExpr checkWord
    }
}

pcx::check 8.5 std lreverse {checkSimpleArgs 1 1 checkList}

pcx::check 8.5 std lsearch {
    checkTailArgs {
	checkHeadSwitches 0 2 {
	    -exact -glob -regexp -nocase
	    {-index checkWord} -subindices
	    -all -ascii -decreasing -dictionary
	    -increasing -inline -integer -not -real -sorted
	    {-start checkExtendedIndexExpr}
	} {}
    } {checkSimpleArgs 2 2 {checkList checkPattern}} 2
}

pcx::check 8.5 std lsort	{
    checkTailArgs {
	checkHeadSwitches 0 1 {
	    -ascii -integer -real -dictionary -indices
	    {-command {checkProcCall 2}} -nocase
	    -increasing -decreasing
	    {-index checkExtendedIndexExpr} 
	    -unique} {}
    } {checkSimpleArgs 1 1 {checkList}} 1
}

pcx::check 8.5 std namespace	{trackNamespace {checkOption {
    {children		{checkSimpleArgs 0 2 \
	    {checkNamespace checkNamespacePattern}}}
    {code	    	{checkSimpleArgs 1 1 {checkWord}}}
    {current	    	{checkSimpleArgs 0 0 {}}}
    {delete	    	{checkSimpleArgs 0 -1 {checkNamespace}}}
    {ensemble {checkSimpleArgs 1 -1 {
	{checkOption {
	    {create    {checkSimpleArgsModNk 0 -1 2 0 {
		{checkSwitches 1 {
		    {-subcommands {checkList}}
		    {-map         {checkDict}}
		    {-prefixes    {checkBoolean}}
		    {-unknown     {checkWord}}
		    {-command     {checkWord}}
		} {}}
	    }}}
	    {configure {checkSimpleArgs 1 -1 {
		checkNamespace
		{checkConfigure 1 {
		    {-subcommands {checkList}}
		    {-map         {checkDict}}
		    {-prefixes    {checkBoolean}}
		    {-unknown     {checkWord}}
		    {-namespace   {checkSimpleArgs 0 0 {}}}
		}}
	    }}}
	    {exists    {checkSimpleArgs 1 1 checkNamespace}}
	} {}}
    }}}
    {eval	    	{
	checkDynLit 0 {
	    checkDynLit 1 {
		checkSimpleArgs 2 -1 {checkNamespace {checkEvalArgs body}}
	    } {
		checkSimpleArgs 2 -1 {checkNamespace {checkContext 2 0 {checkEvalArgs body}}}
	    }
	} {
	    checkDynLit 1 {
		checkSimpleArgs 2 -1 {checkNamespace {checkEvalArgs body}}
	    } {
		checkContext 2 0 {checkSimpleArgs 2 -1 {
		    {newNamespaceScope namespace checkNamespace}
		    {checkEvalArgs body}
		}}
	    }
	}
    }}
    {exists	    	{checkSimpleArgs 1 1 {checkNamespace}}}
    {export	    	{checkSwitches 0 {
	-clear
    } {checkSimpleArgs 0 -1 \
	    {checkExportPattern}}}}
    {forget	    	{checkSimpleArgs 0 -1 {checkNamespacePattern}}}
    {import	    	{checkSwitches 0 {
	-force
    } {checkSimpleArgs 0 -1 \
	    {checkNamespacePattern}}}}
    {inscope	    	{checkSimpleArgs 2 -1 \
	    {checkNamespace checkWord}}}
    {origin	    	{checkSimpleArgs 1 1 {checkProcName}}}
    {parent	    	{checkSimpleArgs 0 1 {checkNamespace}}}
    {path               {checkSimpleArgs 0 1 {{checkListValues 1 -1 {checkNamespace}}}}}
    {qualifiers	    	{checkSimpleArgs 1 1 {checkWord}}}
    {tail	    	{checkSimpleArgs 1 1 {checkWord}}}
    {unknown            {checkSimpleArgs 0 1 {checkWord}}}
    {upvar              {checkSimpleArgsModNk 3 -1 2 1 {checkNamespace checkVarNameDecl checkVarNameDecl}}}
    {which	    	{checkSwitches 0 {
	-command -variable
    } {checkSimpleArgs 1  1 {checkWord}}}}
} {}}}

pcx::check 8.5 std open		{checkSimpleArgs 1 3 \
	{checkFileName checkAccessModeB checkInt}}

pcx::check 8.5 std package	{checkSimpleArgs 1 -1 {{checkOption {
    {forget	 	{checkSimpleArgs 1 1 {
	checkWord
    }}}
    {ifneeded 		{checkSimpleArgs 2 3 {
	{checkSetStyle pkgname checkWord}
	checkExtVersion
	checkBody
    }}}
    {names 		{checkSimpleArgs 0 0 {}}}
    {present 		{checkSwitches 1 {-exact} {checkSimpleArgs 1 2 {
	checkWord
	checkExtVersion
    }}}}
    {provide 		{checkSimpleArgs 1 2 {
	{checkNumArgs {
	    {1 {
		checkWord
	    }}
	    {2 {checkSimpleArgs 2 2 {
		{checkSetStyle pkgname checkWord}
		checkExtVersion
	    }}}
	}}
    }}}
    {require 		{checkOption {
	{-exact {checkSimpleArgs 2 2 {
	    checkWord
	    checkExtVersion
	}}}
    } {checkSimpleArgs 1 -1 {
	checkWord
	checkRequirement
    }}}}
    {unknown 		{checkSimpleArgs 0 1 {{checkProcCall 2}}}}
    {vcompare 		{checkSimpleArgs 2 2 {checkExtVersion}}}
    {versions 		{checkSimpleArgs 1 1 {
	checkWord
    }}}
    {vsatisfies 	{checkSimpleArgs 2 -1 {checkExtVersion checkRequirement}}}
} {}}}}

if 0 {    WarnDeprecated -1 {} {chan puts} {{chan {insert 1 puts}}} {
    }
}
pcx::check 8.5 std puts		{
	checkOption {
	    {-nonewline {checkNumArgs {
		{1  {checkSimpleArgs 1 1 {checkWord}}}
		{-1 {checkSimpleArgs 2 3 {
		    checkChannelID checkWord 
		    {checkKeyword 0 nonewline}}}}}
	    }
	    }
	} {checkNumArgs {
	    {1  {checkSimpleArgs 1 1 {checkWord}}}
	    {-1 {checkSimpleArgs 2 3 {
		checkChannelID checkWord 
		{checkKeyword 0 nonewline}}}}}
	}
}

if 0 {    WarnDeprecated -1 {} {chan read} {{chan {insert 1 read}}} {
    }
}
pcx::check 8.5 std read 	{
	coreTcl::checkReadCmd 0
}

pcx::check 8.5 std return ::coreTcl::checkReturnCmd85

if 0 {    WarnDeprecated -1 {} {chan seek} {{chan {insert 1 seek}}} {
    }
}
pcx::check 8.5 std seek		{
    checkSimpleArgs 2  3 {checkChannelID checkInt {checkKeyword 0 {start current end}}}
}

pcx::check 8.5 std scan \
    {checkSimpleArgs 2 -1 {
	checkWord
	coreTcl::checkScanFmt85
	checkVarNameWrite
    }}

pcx::check 8.5 std source		{
    ::analyzer::warn warnBehaviourCmd {now treats 0x1a as end-of-file character on all platforms} {
	checkSimpleArgs 1 -1 {
	    {checkSwitches 1 {
		{-encoding checkWord}
	    } {checkFileName}}
	}
    }
}

pcx::check 8.5 std string	{checkSimpleArgs 2 -1 {{checkOption {
    {bytelength		{checkSimpleArgs 1 1 {checkWord}}}
    {compare 		{checkHeadSwitches 0 2 {
	-nocase {-length checkInt}
    } {checkSimpleArgs 2 2 {checkWord}}}}
    {equal 		{checkHeadSwitches 0 2 {
	-nocase {-length checkInt}
    } {checkSimpleArgs 2 2 {checkWord}}}}
    {first 		{checkSimpleArgs 2 3 \
	    {checkWord checkWord checkExtendedIndexExpr}}}
    {index 		{checkSimpleArgs 2 2 \
	    {checkWord checkExtendedIndexExpr}}}
    {is			{checkSimpleArgs 2 -1 {
	{checkKeyword 0 { \
		alnum alpha ascii boolean control digit double \
		false graph integer list lower print punct space \
		true upper wideinteger wordchar xdigit}}
	{checkHeadSwitches 0 1 {
	    -strict {-failindex checkVarNameWrite}
	} {checkSimpleArgs 1 1 {checkWord}}}}}
    }
    {last 		{checkSimpleArgs 2 3 \
	    {checkWord checkWord checkExtendedIndexExpr}}}
    {length 		{checkSimpleArgs 1 1 {checkWord}}}
    {map 		{checkHeadSwitches 0 2 {
	-nocase
    } {checkSimpleArgs 2 2 {
	coreTcl::checkCharMap checkWord}}}
    }
    {match 		{checkHeadSwitches 0 2 {
	-nocase
    } {checkSimpleArgs 2 2 {
	checkPattern checkWord}}}
    }
    {range 		{checkSimpleArgs 3 3 \
	    {checkWord checkExtendedIndexExpr}}}
    {repeat 		{checkSimpleArgs 2 2 {checkWord checkInt}}}
    {replace 		{checkSimpleArgs 3 4 {
	checkWord checkExtendedIndexExpr
	checkExtendedIndexExpr checkWord}}
    }
    {reverse {checkSimpleArgs 1 1 {checkWord}}}
    {tolower 		{checkSimpleArgs 1 3 \
	    {checkWord checkExtendedIndexExpr}}}
    {totitle 		{checkSimpleArgs 1 3 \
	    {checkWord checkExtendedIndexExpr}}}
    {toupper 		{checkSimpleArgs 1 3 \
	    {checkWord checkExtendedIndexExpr}}}
    {trim 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimleft 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimright 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {wordend 		{checkSimpleArgs 2 2 \
	    {checkWord checkExtendedIndexExpr}}}
    {wordstart 		{checkSimpleArgs 2 2 \
	    {checkWord checkExtendedIndexExpr}}}} {}}}
}

pcx::check 8.5 std switch		{checkSwitches 0 {
    {-matchvar checkVarNameWrite}
    {-indexvar checkVarNameWrite}
    {}
    -exact -glob -regexp -nocase --
} {checkDoubleDash coreTcl::checkSwitchCmd}}

if 0 {    WarnDeprecated -1 {} {chan tell} {{chan {insert 1 tell}}} {
    }
}
pcx::check 8.5 std tell		{
    checkSimpleArgs 1 1 {checkChannelID}
}

pcx::check 8.5 std unload		{
    checkSimpleArgs 1 -1 {{checkSwitches 1 {
	-nocomplain -keeplibrary --
    } {
	checkSimpleArgs 1 3 {{checkDoubleDash checkFileName} checkWord checkWord}
    }}}
}

# ### ######### ###########################

pcx::check 8.6 std binary \
    {checkOption {
	{decode {checkSimpleArgs 2 -1 {
	    {checkOption {
		{base64   {checkSwitches 1 {
		    -strict
		} {
		    checkSimpleArgs 1 1 checkWord
		}}}
		{uuencode {checkSwitches 1 {
		    -strict
		} {
		    checkSimpleArgs 1 1 checkWord
		}}}
		{hex      {checkSwitches 1 {
		    -strict
		} {
		    checkSimpleArgs 1 1 checkWord
		}}}
	    } {}}
	}}}
	{encode {checkSimpleArgs 2 2 {
	    {checkKeyword 1 {base64 uuencode hex}}
	    checkWord
	}}}
	{format {checkSimpleArgs 1 -1 {
	    {coreTcl::checkBinaryFmtWithFlags aAbBhHcsSiIfdxXwW@tnmrRqQ u}
	    checkWord
	}}}
	{scan {checkSimpleArgs 2 -1 {
	    checkWord
	    {coreTcl::checkBinaryFmtWithFlags aAbBhHcsSiIfdxXwW@tnmrRqQ u}
	    checkVarNameWrite
	}}}
    } {}}

pcx::check 8.6 std chan {
    checkSimpleArgs 1 -1 {
	{checkOption {
	    {adler32   {checkSimpleArgs 1 1 {checkChannelID}}}
	    {blocked   {checkSimpleArgs 1 1 {checkChannelID}}}
	    {close     {checkSimpleArgs 1 1 {checkChannelID}}}
	    {configure {checkSimpleArgs 1 -1 {
		checkChannelID {
		    checkExtensibleConfigure 1 {
			{-blocking   checkBoolean}
			{-buffering  {checkKeyword 0 {full line none}}}
			{-buffersize checkInt}
			{-eofchar    {checkListValues 0 2 {checkWord}}}
			{-encoding   {checkWord}}
			{-peername   {checkSimpleArgs 0 0 {}}}
			{-error {checkSimpleArgs 0 0 {}}}
			{
			    -lasterror
			    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
			}
			{-mode {coreTcl::checkSerialMode}}
			{-sockname {checkSimpleArgs 0 0 {}}}
			{
			    -translation
			    {checkListValues 0 2 {{checkKeyword 1 {auto binary cr crlf lf}}}}
			} {
			    -handshake
			    {
				::analyzer::warn nonPortCmd {} {
				    checkKeyword 1 {none rtscts xonxoff dtrdsr}
				}
			    }
			} {
			    -queue
			    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
			} {
			    -timeout
			    {::analyzer::warn nonPortCmd {} {checkNatNum}}
			} {
			    -ttycontrol
			    {
				::analyzer::warn nonPortCmd {} {				    
				    checkDictValues 2 \
					{checkKeywordNC 1 {txd rxd rts cts dtr dsr dcd ri break}} \
					checkBoolean
				}
			    }
			} {
			    -ttystatus
			    {::analyzer::warn nonPortCmd {} {checkSimpleArgs 0 0 {}}}
			} {
			    -xchar
			    {::analyzer::warn nonPortCmd {} {checkListValues 2 2 {checkWord}}}
			} {
			    -pollinterval
			    {::analyzer::warn nonPortCmd {} {checkNatNum}}
			} {
			    -sysbuffer
			    {::analyzer::warn nonPortCmd {} {checkListValues 1 2 {checkNatNum}}}
			}
		    }
		}
	    }}}
	    {copy      {::analyzer::warn warnBehaviourCmd {now respects value of "-encoding"} {checkSimpleArgs 2 6 {
		checkChannelID checkChannelID
		{checkSwitches 0 {
		    {-size checkInt} 
		    {-command checkBody}
		} {}}}
	    }}}
	    {create    {checkSimpleArgs 2 2 {
		{checkListValues 1 -1 {{checkKeyword 0 {read write}}}}
		checkWord
	    }}}
	    {eof       {checkSimpleArgs 1 1 {checkChannelID}}}
	    {event     {checkSimpleArgs 2 3 {checkChannelID {checkKeyword 0 {
		readable writable
	    }} checkBody}}}
	    {flush     {checkSimpleArgs 1 1 {checkChannelID}}}
	    {fullflush {checkSimpleArgs 1 1 {checkChannelID}}}
	    {gets      {checkSimpleArgs 1 2 {checkChannelID checkVarNameWrite}}}
	    {names     {checkSimpleArgs 0 1 {checkPattern}}}
	    {pending   {checkSimpleArgs 2 2 {
		{checkKeyword 0 {input output}}
		checkChannelID
	    }}}
	    {pipe {checkSimpleArgs 0 0 {}}}
	    {pop {checkSimpleArgs 1 1 {
		checkChannelID
	    }}}
	    {postevent {checkSimpleArgs 2 2 {
		checkChannelID
		{checkListValues 1 -1 {{checkKeyword 0 {read write}}}}
	    }}}
	    {push {checkSimpleArgs 2 2 {
		checkChannelID
		checkWord
	    }}}
	    {puts      {checkOption {
		{-nonewline {checkNumArgs {
		    {1  {checkSimpleArgs 1 1 {checkWord}}}
		    {-1 {checkSimpleArgs 2 3 {
			checkChannelID checkWord 
			{checkKeyword 0 nonewline}}}}}
		}}
	    } {checkNumArgs {
		{1  {checkSimpleArgs 1 1 {checkWord}}}
		{-1 {checkSimpleArgs 2 3 {
		    checkChannelID checkWord 
		    {checkKeyword 0 nonewline}}}}}}}}
	    {read      {coreTcl::checkReadCmd 1}}
	    {seek      {checkSimpleArgs 2 3 {checkChannelID checkInt {checkKeyword 0 {start current end}}}}}
	    {tell      {checkSimpleArgs 1 1 {checkChannelID}}}
	    {truncate  {checkSimpleArgs 1 2 {checkChannelID checkWholeNum}}}
	} {}}
    }
}

pcx::check 8.6 std close {checkSimpleArgs 1 2 {
    checkChannelID
    {checkKeyword 1 {read write}}
}}

pcx::check 8.6 std coroutine {checkSimpleArgs 2 -1 {
    checkWord
    checkEvalArgs
}}

pcx::check 8.6 std dict {checkSimpleArgs 1 -1 {{checkOption {
    {append  {checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}}
    {create  {checkSimpleArgsModNk 0 -1 2 0 {checkWord}}}
    {exists  {checkSimpleArgs 2 -1 {checkDict checkWord}}}
    {filter  {checkSimpleArgs 1 -1  {checkDict {checkOption {
	{key    {checkSimpleArgs 0 -1 checkPattern}}
	{value  {checkSimpleArgs 0 -1 checkPattern}}
	{script {checkSimpleArgs 2 2 {
	    {checkListValues 2 2 {
		checkVarNameWrite
		checkVarNameWrite}}
	    checkBody}}}
    } {}}}}}
    {for     {coreTcl::checkDictForCmd}}
    {get     {checkSimpleArgs 1 -1 {checkDict checkWord}}}
    {incr    {checkSimpleArgs 2 3  {checkVarNameWrite checkWord checkInt}}}
    {info    {checkSimpleArgs 1 1  {checkDict}}}
    {keys    {checkSimpleArgs 1 2  {checkDict checkPattern}}}
    {lappend {checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}}
    {map     {coreTcl::checkDictForCmd}}
    {merge   {checkSimpleArgs 0 -1 {checkDict}}}
    {remove  {checkSimpleArgs 1 -1 {checkDict checkWord}}}
    {replace {checkSimpleArgsModNk 1 -1 2 1 {checkDict checkWord}}}
    {set     {checkSimpleArgs 3 -1 {checkVarNameWrite checkWord checkWord}}}
    {size    {checkSimpleArgs 1 1  {checkDict}}}
    {unset   {checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}}
    {update  {checkSimpleArgsModNk 4 -1 2 0 {
	checkVarNameWrite
	{checkTailArgs {checkSequence {checkWord checkVarNameWrite}} {checkBody} 1}
    }}}
    {values  {checkSimpleArgs 1 2  {checkDict checkPattern}}}
    {with    {checkSimpleArgs 2 -1 {
	checkVarNameWrite
	{checkTailArgs {checkWord} {checkBody} 1}
    }}}
} {}}}}

pcx::check 8.6 std file	{checkSimpleArgs 1 -1 {{checkOption {
    {atime 		{checkSimpleArgs 1 2 {checkFileName checkWholeNum}}}
    {attributes 	{checkSimpleArgs 1 -1 {checkFileName
    {checkConfigure 1 {
	{-group       {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-owner       {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-permissions {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-archive     {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-hidden      {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-longname    {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-readonly    {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-rsrclength  {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-shortname   {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-system      {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-creator     {::analyzer::warn nonPortCmd {} {checkWord}}}
	{-type        {::analyzer::warn nonPortCmd {} {checkWord}}}}}}}
    }
    {channels 		{checkSimpleArgs 0 1 {
	{WarnDeprecated -2 {} {chan names} {
	    {chan {ldrop 1 insert 1 names}}
	} {
	    checkPattern
	}}
    }}}
    {copy 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {delete 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 0 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {dirname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {executable 	{checkSimpleArgs 1 1 {checkFileName}}}
    {exists 		{checkSimpleArgs 1 1 {checkFileName}}}
    {extension 		{checkSimpleArgs 1 1 {checkFileName}}}
    {isdirectory 	{checkSimpleArgs 1 1 {checkFileName}}}
    {isfile 		{checkSimpleArgs 1 1 {checkFileName}}}
    {join 		{checkSimpleArgs 1 -1 {checkFileName}}}
    {link {
	::analyzer::warn nonPortOption {} {
	    checkSimpleArgs 1 3 {
		{checkNumArgs {
		    {1 checkFileName}
		    {2 {checkSimpleArgs 2 2 {checkFileName checkFileName}}}
		    {3 {checkSimpleArgs 3 3 {{checkKeyword 0 {-symbolic -hard}} checkFileName checkFileName}}}}}
		}
	    }
	}
    }
    {lstat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {mkdir 		{checkSimpleArgs 0 -1 {checkFileName}}}
    {mtime 		{checkSimpleArgs 1 2 {checkFileName checkWholeNum}}}
    {nativename 	{checkSimpleArgs 1 1 {checkFileName}}}
    {normalize 	{checkSimpleArgs 1 1 {checkFileName}}}
    {owned 		{checkSimpleArgs 1 1 {checkFileName}}}
    {pathtype 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readable 		{checkSimpleArgs 1 1 {checkFileName}}}
    {readlink 		{checkSimpleArgs 1 1 {checkFileName}}}
    {rename 		{checkSwitches 1 {
	-force --
    } {checkSimpleArgs 2 -1 {{checkDoubleDash checkFileName} checkFileName}}}}
    {rootname 		{checkSimpleArgs 1 1 {checkFileName}}}
    {separator 	{checkSimpleArgs 0 1 {checkFileName}}}
    {size 		{checkSimpleArgs 1 1 {checkFileName}}}
    {split 		{checkSimpleArgs 1 1 {checkFileName}}}
    {stat 		{checkSimpleArgs 2 2 {checkFileName \
	    checkVarNameWrite}}}
    {system 	{checkSimpleArgs 1 1 {checkFileName}}}
    {tail 		{checkSimpleArgs 1 1 {checkFileName}}}
    {tempfile  {checkSimpleArgs 0 2 {
	checkVarNameWrite
	checkWord
    }}}
    {type 		{checkSimpleArgs 1 1 {checkFileName}}} 
    {volumes 		{checkSimpleArgs 0 0 {}}} 
    {writable 		{checkSimpleArgs 1 1 {checkFileName}}}
} {}}}}

pcx::check 8.6 std format {checkSimpleArgs 1 -1 {
    coreTcl::checkFormatFmt86
    checkWord
}}

pcx::check 8.6 std glob		{checkSwitches 0 {
    {-directory checkFileName}
    -join
    -nocomplain
    -tails
    {-path checkFileName}
    {-types checkWord}
    --
} {checkSimpleArgs 0 -1 {
    {checkDoubleDash checkPattern} checkPattern}
}}

pcx::check 8.6 std global	{coreTcl::checkGlobalCmd86}

pcx::check 8.6 std info		{checkSimpleArgs 1 4 {{checkOption {
    {args	{checkSimpleArgs 1  1 {checkWord}}}
    {body	{checkSimpleArgs 1  1 {checkWord}}}
    {cmdcount	{checkSimpleArgs 0  0 {}}}
    {commands	{checkSimpleArgs 0  1 {checkPattern}}}
    {complete	{checkSimpleArgs 1  1 {checkWord}}}
    {coroutine	{checkSimpleArgs 0  0 {}}}
    {default	{checkSimpleArgs 3  3 {checkWord checkWord checkVarNameWrite}}}
    {functions	{checkSimpleArgs 0  1 {checkPattern}}}
    {frame	{checkSimpleArgs 0  1 {checkInt}}}
    {exists	{checkSimpleArgs 1  1 {checkVarNameSyntax}}}
    {globals	{checkSimpleArgs 0  1 {checkPattern}}}
    {hostname	{checkSimpleArgs 0  0 {}}}
    {level	{checkSimpleArgs 0  1 {checkInt}}}
    {library	{checkSimpleArgs 0  0 {}}}
    {loaded	{checkSimpleArgs 0  1 {checkWord}}}
    {locals	{checkSimpleArgs 0  1 {checkPattern}}}
    {nameofexecutable	{checkSimpleArgs 0  0 {}}}
    {patchlevel	{checkSimpleArgs 0  0 {}}}
    {procs	{checkSimpleArgs 0  1 {checkPattern}}}
    {script	{checkSimpleArgs 0  1 {checkFileName}}}
    {sharedlibextension	{checkSimpleArgs 0  0 {}}}
    {tclversion	{checkSimpleArgs 0  0 {}}}
    {vars	{checkSimpleArgs 0  1 {checkPattern}}}
} {}}}}

pcx::check 8.6 std interp		{checkOption {
    {alias		{checkNumArgs {
	{2  {checkSimpleArgs 2 2 {
	    checkList checkWord}}
	}
	{3  {checkSimpleArgs 3 3 {
	    checkList checkWord \
		    {checkKeyword 1 {{}}}}}
	}
	{-1 {checkSimpleArgs 4 -1 {
	    checkList checkWord checkList checkWord}}}}
	}
    }
    {aliases		{checkSimpleArgs 0  1 {checkList}}}
    {bgerror {checkSimpleArgs 1 2 {checkList checkWord}}}
    {cancel {checkSimpleArgs 0 -1 {
	{checkSwitches 1 {
	    -unwind --
	} {checkSimpleArgs 0 2 {
	    checkFileName
	    checkWord
	}}}
    }}}
    {create 		{checkSwitches 0 {
	-safe --
    } {checkSimpleArgs 0 1 {{checkDoubleDash checkList}}}}}
    {debug {checkSimpleArgs 1 -1 {
	checkFileName
	{checkSwitches 1 {
	    {-frame {checkBoolean}}
	} {}}
    }}}
    {delete 		{checkSimpleArgs 0 -1 {checkList}}}
    {eval 		{checkSimpleArgs 2 -1 \
	    {checkList checkEvalArgs}}}
    {exists 		{checkSimpleArgs 1  1 {checkList}}}
    {expose 		{checkSimpleArgs 2  3 {checkList checkWord}}}
    {hide 		{checkSimpleArgs 2  3 {checkList checkWord}}}
    {hidden 		{checkSimpleArgs 0  1 {checkList}}}
    {invokehidden 	{checkNumArgs {
	{1  {checkSimpleArgs 1  1 {checkList}}}
	{-1 {checkSimpleArgs 1 -1 {checkList \
		{checkSwitches 1 {
		    {-global checkWord}
		    {-namespace checkNamespace}
	} {checkSimpleArgs 0 -1 {checkWord}}}}}}}}
    }
    {issafe		{checkSimpleArgs 0  1 {checkList}}}
    {limit {checkSimpleArgs 2 -1 {
	checkList
	{checkOption {
	    {time    {checkConfigure 1 {
		{-command      {checkList}}
		{-granularity  {checkNatNum}}
		{-seconds      {checkOption {{{} checkNOP}} checkNatNum}}
		{-milliseconds {checkOption {{{} checkNOP}} checkNatNum}}
	    }}}
	    {command {checkConfigure 1 {
		{-command     {checkList}}
		{-granularity {checkNatNum}}
		{-value       {checkOption {{{} checkNOP}} checkNatNum}}
	    }}}
	} {}}
    }}}
    {marktrusted 	{checkSimpleArgs 1  1 {checkList}}}
    {recursionlimit     {checkSimpleArgs 1  2 {checkList checkNatNum}}}
    {share 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}
    }
    {slaves 		{checkSimpleArgs 0  1 {checkList}}}
    {target 		{checkSimpleArgs 2  2 {checkList checkWord}}}
    {transfer 		{checkSimpleArgs 3  3 {
	checkList checkChannelID checkList}}}
    } {}
}
pcx::check 8.6 std lassign {checkSimpleArgs 1 -1 {
    checkList 
    checkVarNameWrite
}}

pcx::check 8.6 std linsert {checkSimpleArgs 2 -1 {
    checkList
    checkExtendedIndexExpr
    checkWord
}}

pcx::check 8.6 std lmap	coreTcl::checkForeachCmd

pcx::check 8.6 std lrepeat		{
    checkSimpleArgs 1 -1 {checkWholeNum checkWord}
}

pcx::check 8.6 std lsearch {checkConstrained {checkSequence {
    {checkTailArgs {
	checkHeadSwitches 0 2 {
	    -ascii
	    -decreasing
	    -dictionary
	    -exact
	    -glob
	    -increasing
	    -inline
	    -integer
	    -nocase
	    -real
	    -regexp
	    -sorted
	    -subindices
	    {-all    {checkSetConstraint nobisect checkNOP}}
	    {-bisect {checkSetConstraint bisect   checkNOP}}
	    {-index  checkWord}
	    {-not    {checkSetConstraint nobisect checkNOP}}
	    {-start  checkExtendedIndexExpr}
	} {}
    } {checkSimpleArgs 2 2 {
	checkList checkPattern
    }} 2}
    {checkConstraint {
	{{bisect nobisect} {analyzer::warn coreTcl::badBisect {} checkNOP}}
    } {}}
}}}

pcx::check 8.6 std lset {checkSimpleArgs 2 -1 {
    checkVarNameReadWrite
    {checkTailArgs {
	    checkListValues 1 -1 checkIndexExprExtend
    } {checkWord} 1}
}}

pcx::check 8.6 std lsort {checkTailArgs {
    checkHeadSwitches 0 1 {
	-ascii -integer -real -dictionary -indices
	{-command {checkProcCall 2}} -nocase
	-increasing -decreasing
	{-index checkExtendedIndexExpr} 
	{-stride {checkIntMin 2}}
	-unique} {}
} {checkSimpleArgs 1 1 {checkList}} 1}

pcx::check 8.6 std namespace	{trackNamespace {checkOption {
    {children		{checkSimpleArgs 0 2 \
	    {checkNamespace checkNamespacePattern}}}
    {code	    	{checkSimpleArgs 1 1 {checkWord}}}
    {current	    	{checkSimpleArgs 0 0 {}}}
    {delete	    	{checkSimpleArgs 0 -1 {checkNamespace}}}
    {ensemble {checkSimpleArgs 1 -1 {
	{checkOption {
	    {create    {checkSimpleArgsModNk 0 -1 2 0 {
		{checkSwitches 1 {
		    {-subcommands {checkList}}
		    {-map         {checkDict}}
		    {-prefixes    {checkBoolean}}
		    {-unknown     {checkWord}}
		    {-command     {checkWord}}
		    {-parameters  {checkList}}
		} {}}
	    }}}
	    {configure {checkSimpleArgs 1 -1 {
		checkNamespace
		{checkConfigure 1 {
		    {-subcommands {checkList}}
		    {-map         {checkDict}}
		    {-prefixes    {checkBoolean}}
		    {-unknown     {checkWord}}
		    {-namespace   {checkSimpleArgs 0 0 {}}}
		}}
	    }}}
	    {exists    {checkSimpleArgs 1 1 checkNamespace}}
	} {}}
    }}}
    {eval	    	{
	checkDynLit 0 {
	    checkDynLit 1 {
		checkSimpleArgs 2 -1 {checkNamespace {checkEvalArgs body}}
	    } {
		checkSimpleArgs 2 -1 {checkNamespace {checkContext 2 0 {checkEvalArgs body}}}
	    }
	} {
	    checkDynLit 1 {
		checkSimpleArgs 2 -1 {checkNamespace {checkEvalArgs body}}
	    } {
		checkContext 2 0 {checkSimpleArgs 2 -1 {
		    {newNamespaceScope namespace checkNamespace}
		    {checkEvalArgs body}
		}}
	    }
	}
    }}
    {exists	    	{checkSimpleArgs 1 1 {checkNamespace}}}
    {export	    	{checkSwitches 0 {
	-clear
    } {checkSimpleArgs 0 -1 \
	    {checkExportPattern}}}}
    {forget	    	{checkSimpleArgs 0 -1 {checkNamespacePattern}}}
    {import	    	{checkSwitches 0 {
	-force
    } {checkSimpleArgs 0 -1 \
	    {checkNamespacePattern}}}}
    {inscope	    	{checkSimpleArgs 2 -1 \
	    {checkNamespace checkWord}}}
    {origin	    	{checkSimpleArgs 1 1 {checkProcName}}}
    {parent	    	{checkSimpleArgs 0 1 {checkNamespace}}}
    {path               {checkSimpleArgs 0 1 {{checkListValues 1 -1 {checkNamespace}}}}}
    {qualifiers	    	{checkSimpleArgs 1 1 {checkWord}}}
    {tail	    	{checkSimpleArgs 1 1 {checkWord}}}
    {unknown            {checkSimpleArgs 0 1 {checkWord}}}
    {upvar              {checkSimpleArgsModNk 1 -1 2 1 {
	checkNamespace
	checkVarNameDecl
	checkVarNameDecl
    }}}
    {which	    	{checkSwitches 0 {
	-command -variable
    } {checkSimpleArgs 1  1 {checkWord}}}}
} {}}}

pcx::check 8.6 std scan {checkSimpleArgs 2 -1 {
    checkWord
    coreTcl::checkScanFmt86
    checkVarNameWrite
}}

pcx::check 8.6 std string	{checkSimpleArgs 2 -1 {{checkOption {
    {bytelength		{checkSimpleArgs 1 1 {checkWord}}}
    {compare 		{checkHeadSwitches 0 2 {
	-nocase {-length checkInt}
    } {checkSimpleArgs 2 2 {checkWord}}}}
    {equal 		{checkHeadSwitches 0 2 {
	-nocase {-length checkInt}
    } {checkSimpleArgs 2 2 {checkWord}}}}
    {first 		{checkSimpleArgs 2 3 \
	    {checkWord checkWord checkExtendedIndexExpr}}}
    {index 		{checkSimpleArgs 2 2 \
	    {checkWord checkExtendedIndexExpr}}}
    {is			{checkSimpleArgs 2 -1 {
	{checkKeyword 0 { \
		alnum alpha ascii boolean control digit double \
		entier false graph integer list lower print punct \
		space true upper wideinteger wordchar xdigit}}
	{checkHeadSwitches 0 1 {
	    -strict {-failindex checkVarNameWrite}
	} {checkSimpleArgs 1 1 {checkWord}}}}}
    }
    {last 		{checkSimpleArgs 2 3 \
	    {checkWord checkWord checkExtendedIndexExpr}}}
    {length 		{checkSimpleArgs 1 1 {checkWord}}}
    {map 		{checkHeadSwitches 0 2 {
	-nocase
    } {checkSimpleArgs 2 2 {
	coreTcl::checkCharMap checkWord}}}
    }
    {match 		{checkHeadSwitches 0 2 {
	-nocase
    } {checkSimpleArgs 2 2 {
	checkPattern checkWord}}}
    }
    {range 		{checkSimpleArgs 3 3 \
	    {checkWord checkExtendedIndexExpr}}}
    {repeat 		{checkSimpleArgs 2 2 {checkWord checkInt}}}
    {replace 		{checkSimpleArgs 3 4 {
	checkWord checkExtendedIndexExpr
	checkExtendedIndexExpr checkWord}}
    }
    {reverse {checkSimpleArgs 1 1 {checkWord}}}
    {tolower 		{checkSimpleArgs 1 3 \
	    {checkWord checkExtendedIndexExpr}}}
    {totitle 		{checkSimpleArgs 1 3 \
	    {checkWord checkExtendedIndexExpr}}}
    {toupper 		{checkSimpleArgs 1 3 \
	    {checkWord checkExtendedIndexExpr}}}
    {trim 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimleft 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {trimright 		{checkSimpleArgs 1 2 {checkWord checkWord}}}
    {wordend 		{checkSimpleArgs 2 2 \
	    {checkWord checkExtendedIndexExpr}}}
    {wordstart 		{checkSimpleArgs 2 2 \
	    {checkWord checkExtendedIndexExpr}}}} {}}}
}

pcx::check 8.6 std tailcall {checkSimpleArgs 1 -1 {
    checkEvalArgs
}}

pcx::check 8.6 std throw {checkSimpleArgs 2 2 {
    checkWord
}}

pcx::check 8.6 std try {checkSimpleArgs 1 -1 {
    checkBody
    {checkOption {
	{on   {checkNextArgs 3 {
	    {checkOption {
		{ok       checkNOP}
		{error    checkNOP}
		{return   checkNOP}
		{break    checkNOP}
		{continue checkNOP}
	    } {checkInt}}
	    {checkListValues 0 2 {checkVarNameWrite}}
	    checkBody
	}}}
	{trap {checkNextArgs 3 {
	    checkList
	    {checkListValues 0 2 {checkVarNameWrite}}
	    checkBody
	}}}
	{finally {checkSimpleArgs 1 1 {
	    checkBody
	}}}
    } {}}
}}

pcx::check 8.6 std variable {checkAll {
    coreTcl::checkVariableCmd86
    coreTcl::VarnameForConstant
}}

pcx::check 8.6 std yield {checkSimpleArgs 0 1 {
    checkWord
}}

# note: 'os' - could use RFC 1952 codes to restrict set of legal values.
pcx::check 8.6 std zlib {checkSimpleArgs 1 -1 {
    {checkOption {
	{adler32    {coreTcl::checkZlibChecksumCmd}}
	{compress   {coreTcl::checkZlibCompressCmd}}
	{crc32      {coreTcl::checkZlibChecksumCmd}}
	{decompress {coreTcl::checkZlibDecompressCmd}}
	{deflate    {coreTcl::checkZlibCompressCmd}}
	{gunzip     {checkSimpleArgs 1 -1 {
	    checkWord
	    {checkSwitches 1 {
		{-headerVar {checkVarNameWrite}}
	    } {}}
	}}}
	{gzip       {checkSimpleArgs 1 -1 {
	    checkWord
	    {checkSwitches 1 {
		{-level  {coreTcl::checkZlibLevels}}
		{-header {coreTcl::checkZlibHeaderDict}}
	    } {}}
	}}}
	{inflate    {coreTcl::checkZlibDecompressCmd}}
	{push       {checkSimpleArgs 1 -1 {
	    coreTcl::checkZlibCommand
	    checkChannelID
	    {checkSwitches 1 {
		{-level     {coreTcl::checkZlibLevels}}
		{-limit     {checkInt}}
		{-headerVar {checkVarNameWrite}}
		{-header    {coreTcl::checkZlibHeaderDict}}
	    }}
	}}}
	{stream     {checkSimpleArgs 1 -1 {
	    coreTcl::checkZlibCommand
	    {checkSwitches 1 {
		{-level     {coreTcl::checkZlibLevels}}
		{-headerVar {checkVarNameWrite}}
		{-header    {coreTcl::checkZlibHeaderDict}}
	    } {}}
	}}}
    } {}}
}}

# ### ######### ###########################

# ### ######### ###########################
## Define the set of command-specific checkers for cross-reference
## mode used by this package.


pcx::check 7.3 xref append		{checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}
pcx::check 7.3 xref array		{checkSimpleArgs 2 3 {{checkOption {
    {anymore	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {donesearch	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {names	    {checkSimpleArgs 1 1 {checkVarName}}}
    {nextelement    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {size	    {checkSimpleArgs 1 1 {checkVarName}}}
    {startsearch    {checkSimpleArgs 1 1 {checkVarName}}}
} {}}}}
pcx::check 7.3 xref case		{coreTcl::checkCaseCmd}
pcx::check 7.3 xref catch		{checkSimpleArgs 1 2 {checkBody checkVarNameWrite}}
pcx::check 7.3 xref eval		{checkSimpleArgs 1 -1 {checkEvalArgs}}
pcx::check 7.3 xref expr		coreTcl::checkExprCmd
pcx::check 7.3 xref file		{checkSimpleArgs 1 -1 {{checkOption {
    {lstat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
    {stat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
} {checkSimpleArgs 0 -1 {checkWord}}}}}
pcx::check 7.3 xref for		{checkSimpleArgs 4 4 {checkBody checkExpr checkBody}}
pcx::check 7.3 xref foreach		coreTcl::checkForeachCmd
pcx::check 7.3 xref gets		{checkSimpleArgs 1  2 {checkWord checkVarNameWrite}}
pcx::check 7.3 xref global {coreTcl::checkGlobalCmd}
pcx::check 7.3 xref if 		coreTcl::checkIfCmd
pcx::check 7.3 xref incr		{checkSimpleArgs 1  2 {checkVarNameWrite checkWord}}
pcx::check 7.3 xref info		{checkSimpleArgs 1 3 {{checkOption {
    {default	{checkSimpleArgs 3  3 {checkWord checkWord checkVarNameWrite}}}
    {exists	{checkSimpleArgs 1  1 {checkVarName}}}
} {checkSimpleArgs 0 -1 {checkWord}}}}}
pcx::check 7.3 xref lappend		{checkSimpleArgs 2 -1 {checkVarNameWrite checkWord}}
pcx::check 7.3 xref lsort		{checkTailArgs \
	{checkHeadSwitches 0 1 {
    -ascii -integer -real \
	    {-command {checkProcCall 2}} \
	    -increasing -decreasing} {}} {checkSimpleArgs 1 1 {checkList}} 1
}
pcx::check 7.3 xref parray		{checkSimpleArgs 1  1 {checkVarName}}

pcx::check 7.3 xref proc		{
    checkAll {
	{
	    addContext 1 1 {} {} {checkSimpleArgs 3 3 {{newScope proc addUserProc} addArgList checkWord}}
	} {
	    checkDynLit 2 {
		checkSimpleArgs 3 3 {checkRedefined checkArgList checkBody}
	    } {
		checkContext 1 1 {checkSimpleArgs 3 3 {{newScope proc checkRedefined} checkArgList checkBody}}
	    }
	}
    }
}

pcx::check 7.3 xref regexp		{checkSwitches 1 {
    -nocase -indices --
} {checkSimpleArgs 2 -1 {checkWord checkWord checkVarNameWrite}}}
pcx::check 7.3 xref regsub	{checkSwitches 1 {
    -all -nocase --
} {checkSimpleArgs 4 4 {checkWord checkWord checkWord checkVarNameWrite}}}
pcx::check 7.3 xref rename	{checkSimpleArgs 2  2 {checkProcName checkWord}}
pcx::check 7.3 xref scan	{checkSimpleArgs 3 -1 {checkWord checkWord checkVarNameWrite}}


pcx::check 7.3 xref set {
    checkAll {
	{scanTrackSetVariable}
	{
	    checkNumArgs {
		{1 {checkSimpleArgs 1 1 {checkVarName}}}
		{2 {checkSimpleArgs 2 2 {checkVarNameWrite checkWord}}}
	    }
	}
    }
}

pcx::check 7.3 xref switch	{checkSwitches 0 {
    -exact -glob -regexp --
} coreTcl::checkSwitchCmd}
pcx::check 7.3 xref time	{checkSimpleArgs 1  2 {checkBody checkWord}}
pcx::check 7.3 xref trace	{checkNumArgs {
    {2  {checkSimpleArgs 2 2 {checkWord checkVarName}}}
    {4  {checkSimpleArgs 4 4 {checkWord checkVarName checkWord {checkProcCall 3}}}}}
}
pcx::check 7.3 xref unset	{checkSimpleArgs 1 -1 {checkVarNameWrite}}
pcx::check 7.3 xref uplevel	{checkLevel {checkSimpleArgs 1 -1 {checkEvalArgs}}}
pcx::check 7.3 xref upvar	{coreTcl::checkUpvarCmd}
pcx::check 7.3 xref while      	{checkSimpleArgs 2  2 {checkExpr checkBody}}

## ### #### ##### ######

pcx::check 7.4 xref append	{checkSimpleArgs 1 -1 {checkVarNameWrite checkWord}}
pcx::check 7.4 xref array	{checkSimpleArgs 2 3 {{checkOption {
    {anymore	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {donesearch	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {exists	    {checkSimpleArgs 1 1 {checkVarName}}}
    {get	    {checkSimpleArgs 1 2 {checkVarName checkWord}}}
    {names	    {checkSimpleArgs 1 2 {checkVarName checkWord}}}
    {nextelement    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {set	    {checkSimpleArgs 2 2 {checkVarNameWrite checkWord}}}
    {size	    {checkSimpleArgs 1 1 {checkVarName}}}
    {startsearch    {checkSimpleArgs 1 1 {checkVarName}}}
} {}}}}
pcx::check 7.4 xref lappend		{checkSimpleArgs 1 -1 {checkVarNameWrite checkWord}}
pcx::check 7.4 xref parray		{checkSimpleArgs 1  2 {checkVarName checkWord}}

## ### #### ##### ######

pcx::check 7.5 xref after	{checkOption {
    {cancel	    {checkSimpleArgs 1 -1 {checkWord}}}
    {idle	    {checkSimpleArgs 0 -1 {checkEvalArgs}}}
    {info	    {checkSimpleArgs 0 -1 {checkWord}}}
} {checkSimpleArgs 1 -1 {checkInt checkEvalArgs}}}
pcx::check 7.5 xref file	{checkSimpleArgs 1 -1 {{checkOption {
    {lstat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
    {stat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
} {checkSimpleArgs 0 1 {checkWord}}}}}
pcx::check 7.5 xref fileevent	{checkSimpleArgs 2 3 {checkWord checkWord checkBody}}
pcx::check 7.5 xref info	{checkSimpleArgs 1 4 {{checkOption {
    {default	{checkSimpleArgs 3  3 {checkWord checkWord checkVarNameWrite}}}
    {exists	{checkSimpleArgs 1  1 {checkVarName}}}
} {checkSimpleArgs 0  -1 {checkWord}}}}}
pcx::check 7.5 xref interp	{checkOption {
    {eval 		{checkSimpleArgs 2 -1 {checkWord checkEvalArgs}}}
} {checkSimpleArgs 0  -1 {checkWord}}}


pcx::check 7.5 xref package	{checkSimpleArgs 1 4 {{checkOption {
    {ifneeded 		{checkSimpleArgs 2 3 {checkWord checkWord checkBody}}}
    {provide 		{coreTcl::checkPackageProvide}}
    {require 		{coreTcl::checkPackageRequire}}
    {unknown 		{checkSimpleArgs 0 1 {{checkProcCall 2}}}}
} {checkSimpleArgs 1 -1 {checkWord}}}}}

pcx::check 7.5 xref vwait	{checkSimpleArgs 0  1 {checkVarName}}

## ### #### ##### ######

pcx::check 7.6 xref file		{checkSimpleArgs 1 -1 {{checkOption {
    {lstat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
    {stat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
} {checkSimpleArgs 0 1 {checkWord}}}}}

## ### #### ##### ######

pcx::check 8.0 xref auto_qualify	{checkSimpleArgs 2 2 {checkWord checkNamespace}}
pcx::check 8.0 xref tcl_findLibrary	{checkSimpleArgs 6 6 {checkWord checkWord checkWord checkBody checkVarNameWrite}}
pcx::check 8.0 xref binary		{checkOption {
    {format	    {checkSimpleArgs 1 -1 {checkWord checkWord}}}
    {scan	    {checkSimpleArgs 2 -1 {checkWord checkWord checkVarNameWrite}}}
} {}}
pcx::check 8.0 xref interp		{checkOption {
    {eval 		{checkSimpleArgs 2 -1 {checkWord checkEvalArgs}}}
} {checkSimpleArgs 0  -1 {checkWord}}}
pcx::check 8.0 xref lsort		{checkTailArgs {checkHeadSwitches 0 1 {
    -ascii -integer -real -dictionary
    {-command {checkProcCall 2}} -increasing
    -decreasing {-index checkWord}} {}} {checkSimpleArgs 1 1 {checkWord}} 1
}
pcx::check 8.0 xref namespace	{trackNamespace {checkOption {
    {children		{checkSimpleArgs 0 2  {checkNamespace checkNamespacePattern}}}
    {delete	    	{checkSimpleArgs 0 -1 {checkNamespace}}}
    {eval	    	{
	checkDynLit 1 {
	    checkSimpleArgs 2 -1 {checkNamespace checkEvalArgs}
	} {
	    checkContext 2 0 {checkSimpleArgs 2 -1 {{newNamespaceScope namespace checkNamespace} checkEvalArgs}}
	}
    }}
    {export	    	{checkSwitches 0 {
	-clear
    } {checkSimpleArgs 0 -1 {checkExportPattern}}}}
    {forget	    	{checkSimpleArgs 0 -1 {checkNamespacePattern}}}
    {import	    	{checkSwitches 0 {
	-force
    } {checkSimpleArgs 0 -1 {checkNamespacePattern}}}}
    {inscope	    	{checkSimpleArgs 2 -1 {checkNamespace checkWord}}}
    {origin	    	{checkSimpleArgs 1 1 {checkProcName}}}
    {parent	    	{checkSimpleArgs 0 1 {checkNamespace}}}
} {checkSimpleArgs 1  -1 {checkWord}}}}
pcx::check 8.0 xref variable	coreTcl::checkVariableCmd

## ### #### ##### ######

pcx::check 8.1 xref regexp	{checkSwitches 1 {
    -nocase -indices -expanded -line -linestop -lineanchor -about --
} {checkSimpleArgs 2 -1 {checkWord checkWord checkVarNameWrite}}}
pcx::check 8.1 xref string	{checkSimpleArgs 2 -1 {{checkOption {
    {is			{checkSimpleArgs 2 -1 {
	checkWord
	{checkHeadSwitches 0 1 {
	    -strict {-failindex checkVarNameWrite}
	} {checkSimpleArgs 1 1 {checkWord}}}}}}
    } {checkSimpleArgs 1 -1 {checkWord}}}}
}

## ### #### ##### ######

pcx::check 8.2 xref regsub	{checkSwitches 1 {
    -all -nocase -expanded -line -linestop -lineanchor -about --
} {checkSimpleArgs 4 4 {checkWord checkWord checkWord checkVarNameWrite}}}

## ### #### ##### ######

pcx::check 8.3 xref array	{checkSimpleArgs 2 3 {{checkOption {
    {anymore	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {donesearch	    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {exists	    {checkSimpleArgs 1 1 {checkVarName}}}
    {get	    {checkSimpleArgs 1 2 {checkVarName checkWord}}}
    {names	    {checkSimpleArgs 1 2 {checkVarName checkWord}}}
    {nextelement    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
    {set	    {checkSimpleArgs 2 2 {checkVarNameWrite checkWord}}}
    {size	    {checkSimpleArgs 1 1 {checkVarName}}}
    {startsearch    {checkSimpleArgs 1 1 {checkVarName}}}
    {unset	    {checkSimpleArgs 1 2 {checkVarNameWrite checkWord}}}
} {}}}}
pcx::check 8.3 xref file	{checkSimpleArgs 1 -1 {{checkOption {
    {lstat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
    {stat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
} {checkSimpleArgs 1 -1 {checkWord}}}}}
pcx::check 8.3 xref lsort	{checkTailArgs \
	{checkHeadSwitches 0 1 {
    -ascii -integer -real -dictionary
    {-command {checkProcCall 2}} -increasing
    -decreasing {-index checkWord} -unique
} {}} {checkSimpleArgs 1 1 {checkWord}} 1
}

pcx::check 8.3 xref package	{checkSimpleArgs 1 4 {{checkOption {
    {ifneeded 		{checkSimpleArgs 2 3 {checkWord checkWord checkBody}}}
    {provide 		{coreTcl::checkPackageProvide}}
    {require 		{coreTcl::checkPackageRequire}}
    {unknown 		{checkSimpleArgs 0 1 {{checkProcCall 2}}}}
} {checkSimpleArgs 1 -1 {checkWord}}}}}

pcx::check 8.3 xref regexp	{checkSwitches 1 {
    -nocase -indices -expanded -line -linestop \
	    -lineanchor -about -all -inline \
	    {-start checkWord} --
} {checkSimpleArgs 2 -1 {checkWord checkWord checkVarNameWrite}}}
pcx::check 8.3 xref regsub	{checkSwitches 1 {
    -all -nocase -expanded -line -linestop \
	    -lineanchor -about {-start checkWord} --
} {checkSimpleArgs 4 4 {checkWord checkWord checkWord checkVarNameWrite}
}   }
pcx::check 8.3 xref scan	{checkSimpleArgs 2 -1 {checkWord checkWord checkVarNameWrite}}


pcx::check 8.5 xref package	{checkSimpleArgs 1 4 {{checkOption {
    {ifneeded 		{checkSimpleArgs 2 3 {checkWord checkWord checkBody}}}
    {provide 		{coreTcl::checkPackageProvide85}}
    {require 		{coreTcl::checkPackageRequire85}}
    {unknown 		{checkSimpleArgs 0 1 {{checkProcCall 2}}}}
} {checkSimpleArgs 1 -1 {checkWord}}}}}


## ### #### ##### ######

pcx::check 8.4 xref array {
    checkSimpleArgs 2 4 {
	{
	    checkOption {
		{anymore    {checkSimpleArgs 2 2 {checkVarName checkWord}}}
		{donesearch {checkSimpleArgs 2 2 {checkVarName checkWord}}}
		{exists	    {checkSimpleArgs 1 1 {checkVarName}}}
		{get	    {checkSimpleArgs 1 2 {checkVarName checkWord}}}
		{
		    names {
			checkNumArgs {
			    {1 {checkSimpleArgs 1 1 {checkVarName}}}
			    {2 {checkSimpleArgs 2 2 {checkVarName checkWord}}}
			    {3 {checkSimpleArgs 3 3 {checkVarName checkWord checkWord}}}
			}
		    }
		}
		{nextelement {checkSimpleArgs 2 2 {checkVarName checkWord}}}
		{set	     {checkSimpleArgs 2 2 {checkVarNameWrite checkWord}}}
		{size	     {checkSimpleArgs 1 1 {checkVarName}}}
		{startsearch {checkSimpleArgs 1 1 {checkVarName}}}
		{unset	     {checkSimpleArgs 1 2 {checkVarNameWrite checkWord}}}
		{statistics  {checkSimpleArgs 1 1 {checkVarName}}}
	    } {}
	}
    }
}
pcx::check 8.4 xref binary {
    checkOption {
	{scan   {checkSimpleArgs 2 -1 {checkWord checkWord checkVarNameWrite}}}
    } {checkSimpleArgs 1 -1 {checkWord}}
}
pcx::check 8.4 xref file		{checkSimpleArgs 1 -1 {{checkOption {
    {lstat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
    {stat 		{checkSimpleArgs 2 2 {checkWord checkVarNameWrite}}}
} {checkSimpleArgs 1 -1 {checkWord}}}}}
pcx::check 8.4 xref info		{checkSimpleArgs 1 4 {{checkOption {
    {default	{checkSimpleArgs 3  3 {checkWord checkWord checkVarNameWrite}}}
    {exists	{checkSimpleArgs 1  1 {checkVarName}}}
} {checkSimpleArgs 1  -1 {checkWord}}}}}
pcx::check 8.4 xref interp		{checkOption {
    {eval 		{checkSimpleArgs 2 -1 {checkWord checkEvalArgs}}}
} {checkSimpleArgs 1  -1 {checkWord}}}
pcx::check 8.4 xref namespace	{trackNamespace {checkOption {
    {children		{checkSimpleArgs 0 2 \
	    {checkNamespace checkNamespacePattern}}}
    {delete	    	{checkSimpleArgs 0 -1 {checkNamespace}}}
    {eval	    	{
	checkDynLit 1 {
	    checkSimpleArgs 2 -1 {checkNamespace checkEvalArgs}
	} {
	    checkContext 2 0 {checkSimpleArgs 2 -1 {{newNamespaceScope namespace checkNamespace} checkEvalArgs}}
	}
    }}
    {exists	    	{checkSimpleArgs 1 1 {checkNamespace}}}
    {export	    	{checkSwitches 0 {
	-clear
    } {checkSimpleArgs 0 -1 \
	    {checkExportPattern}}}}
    {forget	    	{checkSimpleArgs 0 -1 {checkNamespacePattern}}}
    {import	    	{checkSwitches 0 {
	-force
    } {checkSimpleArgs 0 -1 \
	    {checkNamespacePattern}}}}
    {inscope	    	{checkSimpleArgs 2 -1 \
	    {checkNamespace checkWord}}}
    {origin	    	{checkSimpleArgs 1 1 {checkProcName}}}
    {parent	    	{checkSimpleArgs 0 1 {checkNamespace}}}
} {checkSimpleArgs 1  -1 {checkWord}}}}
pcx::check 8.4 xref regsub		{checkSwitches 1 {
    -all -nocase -expanded -line -linestop \
	    -lineanchor -about {-start checkInt} --
} {checkSimpleArgs 3 4 \
	{checkWord checkWord checkWord checkVarNameWrite}
}   }

pcx::check 8.4 xref scan		{
    checkSimpleArgs 2 -1 {checkWord checkWord checkVarNameWrite}
}
pcx::check 8.4 xref trace {
    checkOption {
	{variable {checkSimpleArgs 3 3 {checkVarName checkWord {checkProcCall 3}}}}
	{vdelete  {checkSimpleArgs 3 3 {checkVarName checkWord {checkProcCall 3}}}}
	{vinfo    {checkSimpleArgs 1 1 {checkVarName}}}
	{
	    add {
		checkOption {
		    {command   {checkSimpleArgs 3 3 {checkProcName checkWord {checkProcCall 3}}}}
		    {variable  {checkSimpleArgs 3 3 {checkVarName  checkWord {checkProcCall 3}}}}
		    {execution {checkSimpleArgs 3 3 {checkProcName checkWord {checkProcCall 3}}}}
		} {}
	    }
	}
	{
	    remove   {
		checkOption {
		    {command   {checkSimpleArgs 3 3 {checkProcName checkWord {checkProcCall 3}}}}
		    {variable  {checkSimpleArgs 3 3 {checkVarName  checkWord {checkProcCall 3}}}}
		    {execution {checkSimpleArgs 3 3 {checkProcName checkWord {checkProcCall 3}}}}
		} {}
	    }
	}
	{
	    info     {
		checkOption {
		    {command   {checkSimpleArgs 1 1 {checkProcName}}}
		    {variable  {checkSimpleArgs 1 1 {checkVarName}}}
		    {execution {checkSimpleArgs 1 1 {checkProcName}}}
		} {}
	    }
	}
    } {}
}
pcx::check 8.4 xref unset {
    checkSimpleArgs 1 -1 {
	{checkRestrictedSwitches 1 {-nocomplain} {checkVarNameWrite}}
	checkVarNameWrite
    }
}

pcx::check 8.6 xref global {coreTcl::checkGlobalCmd86}

# ### ######### ###########################

# TODO: Write custom checker for "lset" to make sure that
# number of indices matches number of levels in the list.

namespace eval ::coreTcl {
    if 0 {
	# ### ######### ###########################
	# The following additional checkers should be added to all
	# versions in order to properly handle the debugger commands.

	variable proCheckers {
	    debugger_break	{checkSimpleArgs 0 1 {checkWord}}
	    debugger_eval	{checkSwitches 1 {
		{-name checkWord}
		--
	    } {checkSimpleArgs 1 1 {checkBody}}}
	    debugger_init	{checkSimpleArgs 0 2 {checkWord checkInt}}
	}
    }

    #
    # ### ######### ###########################
}

# ### ######### ###########################
## Initialization

## This package provides its own initialization command to handle
## special definitions. For the common parts it uses the standard
## initialization.

proc ::coreTcl::init {ver} {
    pcx::init coreTcl $ver

    # The speciality requiring a custom 'init' command is that we load
    # and activate the rules for TclOO when Tcl 8.6+ is
    # requested. This is easier to handle than adding the TclOO
    # definitions directly to this (already overly large) file.

    if {[package vcompare $ver 8.6] < 0} return

    # 8.6+ is activated, therefore get TclOO as well.
    #
    # Note: We are currently inside of uproc::clear, see
    #       userProc.tcl. At that point the preloading of packages has
    #       already been done (see configure::packageSetup in
    #       configure.tcl). Therefore we have to load TclOO on our
    #       own. The activation of preloaded packages has not been run
    #       yet however, see again uproc::clear, preActivate comes
    #       after. The latter allows us to smuggle TclOO on the
    #       appropriate list and have the regular initialization take
    #       care of the proper activation.

    ::pcx::load TclOO
    lappend configure::preload TclOO 2.0
    return
}

# ### ######### ###########################

# ### ######### ###########################

proc ::coreTcl::ExecReplacements {chain tokens index} {
    return [checkOption {
	{date  {coreTcl::NonPortableCmdReplaced {
	    {{clock format {[clock seconds]}} builtin}
	}}}
	{rm    {coreTcl::NonPortableCmdReplaced {
	    {{file delete} builtin}
	}}}
	{cp    {coreTcl::NonPortableCmdReplaced {
	    {{file copy} builtin}
	}}}
	{mv    {coreTcl::NonPortableCmdReplaced {
	    {{file rename} builtin}
	}}}
	{ls    {coreTcl::NonPortableCmdReplaced {
	    {glob builtin {
		ifempty {+ *}
	    }}
	    {{file stat} {} {
		ifempty {+ <PATH>}
	    } {
		+ <VARNAME/ARRAY>}
	    }
	}}}
	{cat   {coreTcl::NonPortableCmdReplaced {
	    {fileutil::cat {Tcllib's}}
	    {read_file     {Tclx's}}
	}}}
	{touch {coreTcl::NonPortableCmdReplaced {
	    {{file mtime} builtin}
	    {{fileutil::touch} {Tcllib's}}
	}}}
	{chmod {coreTcl::NonPortableCmdReplaced {
	    {{file attribute} builtin}
	    {chmod {Tclx's}}
	}}}
	{sleep {coreTcl::NonPortableCmdReplaced {
	    {after {builtin} {
		get 0 w* 1000 replace 0
	    }}
	    {exp_sleep Expect's}
	}}}
	{kill  {coreTcl::NonPortableCmdReplaced {
	    {kill Tclx's}
	}}}
	{grep  {coreTcl::NonPortableCmdReplaced {
	    {fileutil::grep Tcllib's}
	}}}
	{egrep {coreTcl::NonPortableCmdReplaced {
	    {fileutil::grep Tcllib's}
	}}}
	{find  {coreTcl::NonPortableCmdReplaced {
	    {fileutil::find          Tcllib's}
	    {fileutil::findByPattern {}}
	}}}
	{file  {coreTcl::NonPortableCmdReplaced {
	    {fileutil::fileType        Tcllib's}
	    {fileutil::magic::fileType {}}
	    {fileutil::magic::mimeType {}}
	}}}
	{test  {coreTcl::NonPortableCmdReplaced {
	    {fileutil::test {Tcllib's}}
	}}}
	{tar   {coreTcl::NonPortableCmdReplaced {
	    {tar {Tcllib's (may be slower than regular tar)}}
	}}}
	{tr    {coreTcl::NonPortableCmdReplaced {
	    {{string map} builtin {} {ldropall}}
	    {regsub {} {} ldropall}
	}}}
    } $chain $tokens $index]
}


proc ::coreTcl::NonPortableCmdReplaced {map tokens index} {
    set before $index ; incr before -1
    # map = (replacement-cmd replacement-detail ??pre-cmd? post-cmd?)
    foreach item $map {
	lassign $item c d pre post
	# May need pre-/post-insert code to shuffle things around, per c
	lappend xcmd ldropto $before {*}$pre inserts 0 $c {*}$post save
	set buf ""
	if {$d ne ""} { append buf $d " " }
	append buf "\[$c\]"
	lappend detail $buf
    }
    set detail [join $detail ", or "]

    logExtendedError \
	[CorrectionsOf 0 $tokens {*}$xcmd] \
	nonPortCmdR \
	[getTokenRange [lindex $tokens $before]] $detail

    return [checkWord $tokens $index]
}

# ### ######### ###########################
# Checkers for specific commands --
#
#	Each checker is passed the tokens for the arguments to the command.
#	The name of each checker should be of the form coreTcl::check<Name>,
#	where <name> is the command being checked.
#
# Arguments:
#	tokens		The list of word tokens after the initial
#			command and subcommand names.
#	index		The index of the next word to be checked.
#
# Results:
#	Returns the index of the next token to be checked.

proc ::coreTcl::VarnameForConstant {tokens index} {
    # Looks at  'set      VAR VALUE'. Bug 77231, R2.7.
    # Ditto for 'variable VAR VALUE'.

    # Ignore query form 'set VAR', and 'variable VAR'.
    if {[llength $tokens] < 3} return

    set tokens [lrange $tokens 1 end]
    while {[llength $tokens] >= 2} {

	# Ignore dynamic varnames and values.
	set tokens [lassign $tokens var val]
	if {![getLiteral $var varname]} continue
	if {![getLiteral $val value]} continue

	# Ignore if the varname is capitalized, already indicating a
	# constant.
	if {[regexp {^[A-Z]+$} $varname]} continue

	# Ignore assignments of non-numeric values
	if {![string is integer -strict $value]} continue

	# Ignore pseudo-boolean assigments, numeric comparison!
	if {
	    ($value == 0) ||
	    ($value == 1) ||
	    ($value == -1)
	} continue

	# Ok. We have here an assigment of an non-boolean integer
	# value to a variable with a non-capitalized name. That is
	# what we wish to warn about.

	logError coreTcl::warnStyleNameVariableConstant [getTokenRange $var]
    }
    return
}

# coreTcl::checkCompletion

proc ::coreTcl::checkCompletion {tokens index} {
    # check the completion code for "return -code"

    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    if {[catch {incr value}]} {
	return [checkKeyword 1 {ok error return break continue} $tokens $index]
    }
    return [incr index]
}

# coreTcl::checkCharMap
proc ::coreTcl::checkCharMap {tokens index} {
    # check the map argument of "string map"

    set word [lindex $tokens $index]
    if {[getLiteral $word value]} {
	if {[catch {parse list $value {}} msg]} {
	    logError badList \
		    [list [getLiteralPos $word [lindex $::errorCode 2]] 1] $msg
	} elseif {([llength $msg] & 1)} {
	    logError coreTcl::badCharMap [getTokenRange $word]
	}
    }
    return [checkWord $tokens $index]
}

# coreTcl::checkExprCmd --

proc ::coreTcl::checkExprCmd {tokens index} {
    set argc [llength $tokens]

    #puts <<[analyzer::npeek]>>
    if {$analyzer::exprNesting && ([lindex [analyzer::npeek] 1] eq "expr")} {

	# For this message we have to temporarily munge with the
	# command range so that the proposed correction replaces the
	# full command, including its brackets. A search is needed, as
	# the bracket and command words may be separated by arbitrary
	# whitespace, even continuation lines.

	set here [analyzer::getCmdRange]
	lassign $here s l
	incr s -1
	incr l
	while {[analyzer::getChar $analyzer::script [list $s 1]] ne "\["} {
	    incr s -1
	    incr l
	}
	set e [expr {$s + $l - 1}]
	while {[analyzer::getChar $analyzer::script [list $e 1]] ne "\]"} {
	    incr e
	    incr l
	}
	analyzer::setCmdRange [list $s $l]

	logExtendedError \
	    [CorrectionsOf 1 $tokens \
		 ldrop 0 \
		 iflen == 1 {parens 0 0} \
		 iflen > 1  {parens 0 end} \
		 save] \
	    warnNestedExpr [getTokenRange [lindex $tokens 0]]

	analyzer::setCmdRange $here
    }

    #puts stderr ========================

    # Bug 81791. Multi-word expression is slow, and in danger of
    # double-subst. Unbraced and un-double-quoted single word is
    # slow. Double-quoted word which is not literal is in danger of
    # double-subst.

    set purelit 1
    for {set i $index} {$i < $argc} {incr i} {
	set word [lindex $tokens $i]
	if {![isLiteral $word]} {
	    set purelit 0 
	}
    }

    set word [lindex $tokens $index]
    set warn 0
    if {
	(($argc - $index) > 1) ||
	!([analyzer::hasQuotes "\{" $word] || [analyzer::hasQuotes "\"" $word]) ||
	([analyzer::hasQuotes "\"" $word] && ![isLiteral $word])
    } {
	# If the unquoted pieces are fully literal adding braces will
	# not change the subst behaviour, only the speed of the
	# code. No semantic change => This is auto-correctable.
	set auto $purelit

	logExtendedError \
	    [CorrectionsOf $auto $tokens \
		 braces 1 end save] \
	    warnExpr [getTokenRange $word]
	set warn 1
    }

    if {!$purelit} {
	return [checkSimpleArgs 1 -1 {checkWord} $tokens $index]
    }

    # Argument(s) is/are literal, one or many. If a warning has been
    # given it was not quoted correctly, so further checking is not
    # necessary.

    if {$warn} {
	return $argc
    }

    #puts stderr "EXPR ($tokens)"
    #puts stderr "$index | $argc"
    ##foreach t $tokens {puts stderr "$t = [getTokenString $t]"}

    if {($argc - $index) == 1} {
	return [checkExpr $tokens $index]
    } else {
	#/deprecated/ TODO: We could do better here since it is a literal, but we'd need to
	#/deprecated/ construct a new word that spans all of the remaining words.

	# We construct an artifical word containing the text of all
	# arguments to expr in one string and feed that into the
	# expression parser for checking.

	#puts stderr "EXPR/*"

	set expr_args       [lrange $tokens 1 end]
	set first_earg      [lindex $expr_args 0]
	set last_earg       [lindex $expr_args end]
	set first_startchar [lindex [getTokenRange $first_earg] 0]
	set last_range      [getTokenRange $last_earg]
	set last_startchar  [lindex $last_range 0]
	set last_rsize      [lindex $last_range 1]
	set new_rsize       [expr {($last_startchar-$first_startchar)+$last_rsize}]
	set expr_token      [list simple [list $first_startchar $new_rsize] $expr_args]

	#puts stderr "EXPR/* ai/token = \"[getTokenString $expr_token]\" ($expr_token)"
	## return [checkSimpleArgs 1 -1 {checkWord} $tokens $index]

	checkExpr [list $expr_token] 0
	return $argc
    }
}

# coreTcl::checkIfCmd --

proc ::coreTcl::checkIfCmd {tokens index} {
    # Syntax: if <expr> ?then? <body> (elseif <expr> ?then? <body>)... ?else? <body>

    set i $index
    set argc [llength $tokens]
    set text {}

    set clause "if"
    set keywordNeeded 0
    set keywordNeededAt {} ; # indices where a keyword is found missing (elseif, else)

    while {1} {

	# At this point in the loop, lindex i refers to an expression
	# to test, either for the main expression or an expression
	# following an "elseif".  The arguments after the expression
	# must be "then" (optional keyword) and a script to execute.

	if {$i >= $argc} {
	    lassign [lindex $tokens [expr {$i - 1}] 1] s l
	    logError noExpr [list [expr {$s + $l}] 1] $clause
	    return $argc
	}

	# Not using checkOrderBranch here because the check is
	# explicit and over Expr and Body.
	#
	# TODO To be fully correct we have to put in epsilons and arcs
	# between the expressions to model their order of execution.
	if {![analyzer::isScanning]} timeline::branchopen
	checkExpr $tokens $i
	incr i

	# lindex i now may refer to the optional keyword 'then'. If
	# yes, then we skip over this word.

	if {
	    ($i < $argc) &&
	    [getLiteral [lindex $tokens $i] text] &&
	    ($text eq "then")
	} {
	    logExtendedError \
		[CorrectionsOf 1 $tokens ldrop $i save]\
		coreTcl::warnStyleThen [getTokenRange [lindex $tokens $i]]
	    incr i
	}

	# lindex i now refers to the script of this branch of the
	# if. Or is beyond the range, signaling that the command is
	# malformed.

	if {$i >= $argc} {
	    set word [lindex $tokens [expr {$i - 1}] 1]
	    set end [expr {[lindex $word 0] + [lindex $word 1]}]
	    logError noScript [list $end 1] $clause

	    if {![analyzer::isScanning]} timeline::branchclose
	    return $argc
	}

	checkBody $tokens $i
	if {![analyzer::isScanning]} timeline::branchclose

	set keywordNeeded 1
	incr i
	set keywordNeededAt $i

	# lindex i now may refer to an 'elseif' keyword, starting a
	# new branch, the keyword 'else, starting the fallback clause,
	# or just a body, the script of the fallback clause, standing
	# alone. The latter is possible due to the 'else' being
	# optional.

	if {$i >= $argc} {
	    # We completed successfully
	    return $argc
	}

	if {[getLiteral [lindex $tokens $i] text] && ($text eq "elseif")} {
	    set keywordNeeded 0
	    set keywordNeededAt {}

	    set clause "elseif"
	    incr i
	    continue
	}
	break
    }

    # Now we check for an else clause
    if {[getLiteral [lindex $tokens $i] text] && ($text eq "else")} {
	set clause "else"
	set keywordNeeded 0
	set keywordNeededAt {}
	incr i

	if {$i >= $argc} {
	    set word [lindex $tokens [expr {$i - 1}] 1]
	    set end [expr {[lindex $word 0] + [lindex $word 1]}]
	    logError noScript [list $end 1] $clause
	    return $argc
	}
    }

    if {$keywordNeeded || (($i+1) != $argc)} {
	set range [lindex $tokens [expr {$i - 1}] 1]

	if {$keywordNeededAt eq ""} {
	    # Processing was not complete after the else-clause, if
	    # any.  Don't know how to correct. Generate a plain
	    # warning.
	    logError warnIfKeyword $range
	} else {
	    lassign $range start length
	    set end [expr {$start + $length}]

	    logExtendedError \
		[CorrectionsOf 0 $tokens \
		     insert $keywordNeededAt [expr {($i+1) == $argc ? "else" : "elseif"}] \
		     save] \
		warnIfKeyword [list $end 1]
	}
    }

    return [checkOrderBranch checkBody $tokens $i]
}


proc ::coreTcl::checkDictForCmd {tokens index} {
    set argc [expr {[llength $tokens] - $index}]
    if {$argc != 3} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }

    set index [checkListValues 2 2 {
	checkVarNameWrite checkVarNameWrite
    } $tokens $index]

    set index [checkDict $tokens $index]

    analyzer::def'run ;# Cancel deferal, actions now.
    set index [checkBody $tokens $index]
    return $index
}


# coreTcl::checkForeachCmd --

proc ::coreTcl::checkForeachCmd {tokens index} {
    set argc [llength $tokens]
    if {($argc < 4) || ($argc % 2)} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }

    # Make sure all odd args except for the last are varnames or lists of
    # varnames.  Only the last argument to the foreach command is a Tcl script.

    while {$index < ($argc - 1)} {
	set word [lindex $tokens $index]
	if {[getLiteral $word literal]} {
	    set index [checkListValues 1 -1 checkVarNameWrite $tokens $index]
	} else {
	    set index [checkVarNameWrite $tokens $index]
	}
	set index [checkWord $tokens $index]
    }
    analyzer::def'run ;# Cancel deferal, actions now.
    return [checkOrderLoop checkBody $tokens $index]
}

# coreTcl::checkReadCmd --

proc ::coreTcl::checkReadCmd {offset tokens index} {
    set argc [llength $tokens]
    incr argc -$offset
    if {($argc < 2) || ($argc > 3)} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkSimpleArgs 1 2 {checkChannelID checkInt} $tokens $index]
    }
    if {$value eq "-nonewline"} {
	incr index
    }
    return [checkSimpleArgs 1 2 {checkChannelID checkInt} $tokens $index]
}

# coreTcl::checkReturnCmd --

proc ::coreTcl::checkReturnCmd {tokens index} {
    set argc [llength $tokens]
    while {$index < $argc} {
	set index [checkOption {
	    {-code coreTcl::checkCompletion}
	    {-errorinfo checkWord}
	    {-errorcode checkWord}
	} {checkSimpleArgs 0 1 {checkWord}} $tokens $index]
    }
    return $index
}

proc ::coreTcl::checkReturnCmd85 {tokens index} {
    set argc [llength $tokens]
    while {$index < $argc} {
	if {($argc - $index) >= 2} {
	    # 2 words at least, option + value
	    set index [checkOption {
		{-code coreTcl::checkCompletion}
		{-errorinfo checkWord}
		{-errorcode checkWord}
		{-level     checkWholeNum}
		{-options   checkDict}
	    } {checkSequence {checkWord checkWord}} $tokens $index]
	} else {
	    # Last word, alone - message
	    set index [checkWord $tokens $index]
	}
    }
    return $index
}

# coreTcl::checkSocketCmd --

proc ::coreTcl::checkSocketCmd {tokens index} {
    set argc [llength $tokens]
    if {$argc < 3} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }
    
    set server 0
    set async  0
    set myPort 0

    for {} {$index < $argc} {} {
	set word [lindex $tokens $index]
	if {[getLiteral $word literal]} {
	    if {[string match "-*" $literal]} {
		if {$literal eq "-server"} {
		    if {$async} {
			logError coreTcl::socketAsync \
				[getTokenRange [lindex $tokens $index]]
			return [checkCommand $tokens $index]
		    }
		    set server 1
		    incr index
		    if {$index >= $argc} {
			logError noSwitchArg \
				[getTokenRange [lindex $tokens $index]] \
				$literal
			return [checkCommand $tokens $index]
		    } else {
			set index [checkWord $tokens $index]
		    }
		} elseif {$literal eq "-myaddr"} {
		    incr index
		    if {$index >= $argc} {
			logError noSwitchArg \
				[getTokenRange [lindex $tokens $index]] \
				$literal
			return [checkCommand $tokens $index]
		    } else {
			set index [checkWord $tokens $index]
		    }
		} elseif {$literal eq "-myport"} {
		    set myPort 1
		    set myPortIndex $index
		    incr index
		    if {$index >= $argc} {
			logError noSwitchArg \
				[getTokenRange [lindex $tokens $index]] \
				$literal
			return [checkCommand $tokens $index]
		    } else {
			set index [checkInt $tokens $index]
		    }
		} elseif {$literal eq "-async"} {
		    if {$server} {
			logError coreTcl::socketServer \
				[getTokenRange [lindex $tokens $index]]
			return [checkCommand $tokens $index]
		    }
		    set async 1
		    incr index
		} else {
		    logError badOption \
			    [getTokenRange [lindex $tokens $index]] \
			    "-async, -myaddr, -myport, or -server" $literal
		    return [checkCommand $tokens $index]
		}
	    } else {
		break
	    }
	} else {
	    return [checkCommand $tokens $index]
	}
    }
    if {$server} {
	if {$myPort} {
	    logError coreTcl::serverAndPort \
		    [getTokenRange [lindex $tokens $myPortIndex]]
	    return [checkCommand $tokens $index]
	}
	return [checkSimpleArgs 1 1 {checkInt} $tokens $index]
    } else {
	return [checkSimpleArgs 2 2 {checkWord checkInt} $tokens $index]
    }
}

# coreTcl::checkSourceCmd --

proc ::coreTcl::checkSourceCmd {tokens index} {
    set argc [llength $tokens]

    if {0} {
	# This is the declarative form of the code below.
	checkSimpleArgs 1 -1 {
	    checkNumArgs {
		{1 {checkFileName}}
		{-1 {
		    {checkSwitches 1 {
			{-rsrc   {checkWord}}
			{-rsrcid {checkInt}}
		    } {checkSimpleArgs 0 1 checkFileName}}
		}}
	    }
	} _tokens_ _index_
    }

    if {$argc == 1} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }
    if {$argc == 2} {
	return [checkFileName $tokens $index]
    } else {
	set word [lindex $tokens $index]
	if {![getLiteral $word value]} {
	    return [checkSimpleArgs 2 3 {checkWord checkWord checkFileName} \
		    $tokens $index]
	}
	incr index 
	if {$value eq "-rsrc"} {
	    return [checkSimpleArgs 1 2 {checkWord checkFileName} \
		    $tokens $index] 
	} elseif {$value eq "-rsrcid"} {
	    return [checkSimpleArgs 1 2 {checkInt checkFileName} \
		    $tokens $index]
	} else {
	    logError numArgs {}
	    return [checkCommand $tokens $index]
	}
    }
}

# coreTcl::checkSwitchCmd --

proc ::coreTcl::checkSwitchCmd {tokens index} {
    variable ::analyzer::scriptNesting

    set end  [llength $tokens]
    set argc [expr {$end - $index}]
    set i $index

    if {$argc < 2} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }
    
    # The index points at the first argument after the switches
    # The next argument should be the string to switch on.

    set i [checkWord $tokens $i]

    # We are then left with two cases: 1. one argument which
    # need to split into words.  Or 2. a bunch of pattern body
    # pairs.

    set hasdefault 0
    set defaultat -1
    set maxbranch -1

    if {($i + 1) == $end} {
	# Check to be sure the body doesn't contain substitutions

	set bodyToken [lindex $tokens $i]
	if {![isLiteral $bodyToken]} {
	    return [checkWord $tokens $i]
	}
	
	# If the body token contains backslash sequences, there will
	# be more than one subtoken, so we take the range for the whole
	# body and subtract the braces.  Otherwise it's a "simple" word
	# with only one part and we can get the range from the text
	# subtoken. 

	if {[llength [lindex $bodyToken 2]] > 1} {
	    set range [lindex $bodyToken 1]
	    lassign $range s l
	    set range [list [expr {$s + 1}] [expr {$l - 2}]]
	} else {
	    set range [lindex $bodyToken 2 0 1]
	}

	set script [getScript]
	set i [checkList $tokens $i]

	# Bug 85600.
	# The "body" of the switch, i.e. the pattern/action list
	# should not be treated as plain word, even if it could due to
	# simple code inside.
	analyzer::style::set [expr {$i-1}] none

	if {![analyzer::isScanning]} timeline::branchesfork

	# Count the nesting introduced by the list the branches are
	# in, both for maxnesting, and action indentation.
	incr scriptNesting 1
	catch {
	    # Bug 88396. Hide continuation lines in the p/b list from 'parse list'.
	    lassign $range s l ; set e [expr {$s + $l - 1}]
	    incr s -1 ; set pre  [string range $script 0 $s]
	    incr s    ; set mid  [string range $script $s $e]
	    incr e    ; set post [string range $script $e end]

	    foreach {pattern body} [parse list \
					$pre[string map [list \\\n {  }] $mid]$post \
					$range] {
		incr maxbranch

		if {$body eq ""} {
		    logError noScript \
			    [getTokenRange $bodyToken] \
			    pattern
		}

		if {[parse getstring $script $pattern] eq "default"} {
		    set defaultat $maxbranch
		    set hasdefault 1
		}

		# If the body is not "-", parse it as a command word and pass
		# the result to parseBody.  This isn't quite right, but it
		# should handle the common cases.

		if {$body ne "" && [parse getstring $script $body] ne "-"} {
		    set oi [analyzer::style::indent::get]
		    # Generate a fake word token from the range, to
		    # fit the expectations of the command.
		    analyzer::style::indent::at [list simple $pattern {}]
		    checkOrderBranch checkBody [lindex [parse command $script $body] 3] 0
		    analyzer::style::indent::set $oi
		}
	    }
	}
	incr scriptNesting -1

	if {![analyzer::isScanning]} timeline::branchesjoin
    } else {
	set bodyToken [lindex $tokens $i]

	if {![analyzer::isScanning]} timeline::branchesfork
	while {$i < $end} {
	    incr maxbranch
	    if {[getLiteral [lindex $tokens $i] string]} {
		if {$string eq "default"} {
		    set default $maxbranch
		    set hasdefault 1
		}
	    }
	    set i [checkWord $tokens $i]
	    if {$i < $end} {
		if {(![getLiteral [lindex $tokens $i] string] \
			|| $string eq "-")} {
		    set i [checkWord $tokens $i]
		} else {
		    set i [checkOrderBranch checkBody $tokens $i]
		}
	    }
	}
	if {![analyzer::isScanning]} timeline::branchesjoin
    }

    if {!$hasdefault} {
	logError warnNoDefault [getTokenRange $bodyToken] switch
    } elseif {$defaultat < $maxbranch} {
	logError warnMisplacedDefault [getTokenRange $bodyToken] switch
    }

    return $i
}

# coreTcl::checkTraceOp --

proc ::coreTcl::checkTraceOp {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    if {![regexp {^[rwu]+$} $value]} {
	logError coreTcl::badTraceOp [getTokenRange $word] $value
    }
    return [incr index]
}


proc ::coreTcl::checkGlobalCmd {tokens index} {
    if {$configure::xref || ![analyzer::isTwoPass]} {
	analyzer::scanTrackGlobal $tokens $index
    }
    return [analyzer::trackGlobal {checkSimpleArgs 1 -1 {checkVarNameDecl}} $tokens $index]
}

proc ::coreTcl::checkGlobalCmd86 {tokens index} {
    if {$configure::xref || ![analyzer::isTwoPass]} {
	analyzer::scanTrackGlobal $tokens $index
    }
    return [analyzer::trackGlobal {checkSimpleArgs 0 -1 {checkVarNameDecl}} $tokens $index]
}

# coreTcl::checkVariableCmd --

proc ::coreTcl::checkVariableCmd {tokens index} {
    if {$configure::xref || ![analyzer::isTwoPass]} {
	analyzer::scanTrackVariable $tokens $index
    }

    analyzer::trackVariable $tokens $index

    set argc [llength $tokens]
    if {$argc < 1} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }
    while {$index < $argc} {
	if {($index + 1) < $argc} {
	    # A value follows, the variable is written
	    set index [checkVarNameWrite $tokens $index]
	} else {
	    # No value ofter the variable, just declaration
	    set index [checkVarNameDecl $tokens $index]
	}
	if {$index < $argc} {
	    set index [checkWord $tokens $index]
	}
    }
    return $index
}

proc ::coreTcl::checkVariableCmd86 {tokens index} {
    if {$configure::xref || ![analyzer::isTwoPass]} {
	analyzer::scanTrackVariable $tokens $index
    }

    analyzer::trackVariable $tokens $index

    set argc [llength $tokens]
    if {$argc < 1} {
	return [checkCommand $tokens $index]
    }
    while {$index < $argc} {
	if {($index + 1) < $argc} {
	    # A value follows, the variable is written
	    set index [checkVarNameWrite $tokens $index]
	} else {
	    # No value ofter the variable, just declaration
	    set index [checkVarNameDecl $tokens $index]
	}
	if {$index < $argc} {
	    set index [checkWord $tokens $index]
	}
    }
    return $index
}

proc ::coreTcl::checkUplevelCmd {tokens index} {
    return [analyzer::checkLevel {checkIndexAtAndFix 1 coreTcl::warnUplevel {
	checkSimpleArgs 1 -1 {
	    checkEvalArgs
	}
    } {1 \#0 <INTEGER> \#<INTEGER>}} $tokens $index]
}

proc ::coreTcl::checkUpvarCmd {tokens index} {
    set argc [llength $tokens]
    if {($argc % 2) == 0} {
	# Command is (upvar level varname varname' ...).
	# We have a level, possibly dynamically specified, and skip it.
	incr index
    } else {
	# Command is (upvar varname varname' ...).
	# We have no level argument and complain about it.
	logExtendedError \
	    [CorrectionsOf 0 $tokens \
		 insert $index 1 save \
		 insert $index \#0 save \
		 insert $index <INTEGER> save \
		 insert $index \#<INTEGER> save \
		] \
	    coreTcl::warnUplevel [getTokenRange [lindex $tokens $index]]
    }

    if {$configure::xref || ![analyzer::isTwoPass]} {
	# Bug 82058. The other context calling scanTrackVar always
	# uses 'index == 1' (See the note at line 200 of this file),
	# so we have to do the same here to ensure a stable
	# environment for the procedure. .
	analyzer::scanTrackUpvar $tokens 1
    }

    # Bug 82058. This calls trackUpvar with the current token always
    # the first variable name to be imported, possibly skipping the
    # 'level' argument.
    analyzer::trackUpvar $tokens $index

    set word [lindex $tokens $index]
    set argc [expr {[llength $tokens] - 1}]

    foreach {orig new} [lrange $tokens $index end] {
	if {[getLiteral $orig literal]} {
	    analyzer::style::set $index varname/lhs
	    checkVariable decl $literal $literal [getTokenRange $orig] $orig
	} else {
	    checkWord $tokens $index
	}
	incr index
	if {$new eq ""} {
	    logError numArgs {}
	} else {
	    if {[getLiteral $new literal]} {
		analyzer::style::set $index varname/lhs
	    }
	    checkVarNameDecl $tokens $index
	}
	incr index
    }
    return $index
}


# coreTcl::checkSwitchCmd --

proc ::coreTcl::checkCaseCmd {tokens index} {
    set end  [llength $tokens]
    set argc [expr {$end - $index}]
    set i $index

    WarnDeprecated -1 {} switch {
	{switch {inserts 1 {-glob --}}}
    } {} $tokens $index

    if {$argc < 2} {
	logError numArgs {}
	return [checkCommand $tokens $index]
    }
    
    # The index points at the first argument after the switches
    # The next argument should be the string to switch on.

    set i [checkWord $tokens $i]

    # Look for the case specific keyword "in"

    if {([getLiteral [lindex $tokens $i] keyword]) && ($keyword eq "in")} {
	incr i
    }

    # We are then left with two cases: 1. one argument which
    # need to split into words.  Or 2. a bunch of pattern body
    # pairs.

    set hasdefault 0

    if {($i + 1) == $end} {
	# Check to be sure the body doesn't contain substitutions

	set bodyToken [lindex $tokens $i]
	if {![isLiteral $bodyToken]} {
	    return [checkWord $tokens $i]
	}

	# If the body token contains backslash sequences, there will
	# be more than one subtoken, so we take the range for the whole
	# body and subtract the braces.  Otherwise it's a "simple" word
	# with only one part and we can get the range from the text
	# subtoken. 

	if {[llength [lindex $bodyToken 2]] > 1} {
	    set range [lindex $bodyToken 1]
	    lassign $range s l
	    set range [list [expr {$s + 1}] [expr {$l - 2}]]
	} else {
	    set range [lindex $bodyToken 2 0 1]
	}

	set script [getScript]
	set i [checkList $tokens $i]
	if {![analyzer::isScanning]} timeline::branchesfork
	catch {
	    # Bug 88396. Hide continuation lines in the p/b list from 'parse list'.
	    lassign $range s l ; set e [expr {$s + $l - 1}]
	    incr s -1 ; set pre  [string range $script 0 $s]
	    incr s    ; set mid  [string range $script $s $e]
	    incr e    ; set post [string range $script $e end]

	    foreach {pattern body} [parse list \
					$pre[string map [list \\\n {  }] $mid]$post \
					$range] {
		if {$body eq ""} {
		    logError noScript \
			    [getTokenRange [lindex $tokens $i]] \
			    pattern
		}

		if {[parse getstring $script $pattern] eq "default"} {
		    set hasdefault 1
		}

		# If the body is not "-", parse it as a command word and pass
		# the result to parseBody.  This isn't quite right, but it
		# should handle the common cases.

		if {$body ne "" && [parse getstring $script $body] ne "-"} {
		    checkOrderBranch checkBody [lindex [parse command $script $body] 3] 0
		}
	    }
	}
	if {![analyzer::isScanning]} timeline::branchesjoin
    } else {
	set bodyToken [lindex $tokens $i]
	if {![analyzer::isScanning]} timeline::branchesfork
	while {$i < $end} {
	    if {[getLiteral [lindex $tokens $i] string]} {
		if {$string eq "default"} {
		    set hasdefault 1
		}
	    }
	    set i [checkWord $tokens $i]
	    if {$i < $end} {
		if {(![getLiteral [lindex $tokens $i] string] \
			|| $string eq "-")} {
		    set i [checkWord $tokens $i]
		} else {
		    set i [checkOrderBranch checkBody $tokens $i]
		}
	    }
	}
	if {![analyzer::isScanning]} timeline::branchesjoin
    }

    if {!$hasdefault} {
	logError warnNoDefault [getTokenRange $bodyToken] case
    }

    return $i
}

# coreTcl::checkRegexp --

# NOTE: These can be replaced by the general constraint checkers.
proc ::coreTcl::checkRegexpMarkAbout {tokens index} {
    variable reAbout 1
    return $index
}

proc ::coreTcl::checkRegexpHandleAbout {tokens index} {
    variable reAbout
    if {![info exists reAbout]} { set reAbout 0 }
    set has $reAbout
    set reAbout 0

    if {$has} {
	return [checkSimpleArgs 1 -1 \
		    {{checkDoubleDash checkRegexp} checkWord checkVarNameWrite} \
		    $tokens $index]
    } else {
	return [checkSimpleArgs 2 -1 \
		    {{checkDoubleDash checkRegexp} checkWord checkVarNameWrite} \
		    $tokens $index]
    }
}

# coreTcl::checkClockFormat --

proc ::coreTcl::checkClockFormat {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    if {[string match "*%y*" $value]} {
	logError coreTcl::warnY2K [getTokenRange $word]
    }
    # TODO: check the %-groups for legality.
    return [incr index]
}

proc ::coreTcl::checkClockUnits {chains tokens index} {
    set n [llength $tokens]

    set units [list \
		   years   year	months  month \
		   weeks   week	days    day \
		   hours   hour	minutes minute \
		   seconds second \
		  ]

    set argc [expr {$n - $index}]
    while {$argc >= 2} {
	analyzer::logOpen
	set index [checkInt $tokens $index]
	set msgs [analyzer::logGet]
	if {[llength $msgs]} {
	    incr index -1
	    break
	}

	set index [checkKeyword exact $units $tokens $index]
	set argc  [expr {$n - $index}]
    }

    set last [checkSwitches 0 $chains checkNOP $tokens $index]
    if {$last == $index} {
	# Still at checkInt location, assume we have messages from
	# the checkInt, push them out now.
	foreach cmd $msgs { {*}$cmd }
    } elseif {$last < $n} {
	# Aborted checkSwitches, could be non-switch. Treat as
	# badSwitch. Gymnastics because checkSwitches does not really
	# handle switches at end of command without any words expected
	# after.
	set word [lindex $tokens $last]
	if {[getLiteral $word value]} {
	    logError badSwitch [getTokenRange $word] $value
	}
    }
    # We have consumed all, even if the switches stopped earlier.
    return $n
}


# coreTcl::checkBinaryFmt --

proc ::coreTcl::checkBinaryFmt {types tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }

    # Ok, we got the literal value ...
    # Use the type spec to create a regexp pattern the format string
    # has to match. Cache the pattern keyed by 'types'. We also
    # accept the empty string as valid. For that case we skip
    # the generation of a pattern.

    if {$value eq {}} {
	return [incr index]
    }
    set pattern [GetBinaryFmtPattern $types]

    if {![regexp -- $pattern $value]} {
	logError coreTcl::badBinaryFmt [getTokenRange $word] $value
    }
    return [incr index]
}

proc ::coreTcl::GetBinaryFmtPattern {types} {
    global bfpCache
    if {![info exists bfpCache($types)]} {
	set bfpCache($types) [CreateBinaryFmtPattern $types]	
    }
    return $bfpCache($types)
}

proc ::coreTcl::CreateBinaryFmtPattern {types} {
    # types = string of type codes, no intervening whitespace

    return "^(\[$types\]((\[0-9\]*\[1-9\]\[0-9\]*)|\\*)? *)+\$"
}

proc ::coreTcl::checkBinaryFmtWithFlags {types flags tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }

    # Ok, we got the literal value ...
    # Use the type spec to create a regexp pattern the format string
    # has to match. Cache the pattern keyed by 'types'. We also
    # accept the empty string as valid. For that case we skip
    # the generation of a pattern.

    if {$value eq {}} {
	return [incr index]
    }
    set pattern [GetBinaryFmtPatternWithFlags $types $flags]

    if {![regexp -- $pattern $value]} {
	logError coreTcl::badBinaryFmt [getTokenRange $word] $value
    }
    return [incr index]
}

proc ::coreTcl::GetBinaryFmtPatternWithFlags {types flags} {
    global bffpCache
    if {![info exists bffpCache($types,$flags)]} {
	set bffpCache($types,$flags) [CreateBinaryFmtPatternWithFlags \
					  $types $flags]	
    }
    return $bffpCache($types,$flags)
}

proc ::coreTcl::CreateBinaryFmtPatternWithFlags {types flags} {
    # types = string of type codes, no intervening whitespace

    return "^(\[$types\](\[$flags\])?((\[0-9\]*\[1-9\]\[0-9\]*)|\\*)? *)+\$"
}

# coreTcl::checkFormatFmt --

proc ::coreTcl::checkFormatFmt {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    # Ok, we got the literal value ...

    # Remove everything which looks like a valid %-specifier
    # Not quite: We do not remove specifiers containing the
    # l length modifier. If such are present (and we are doing
    # 8.4 and above we warn about the change in behaviour).

    # clash - The * width specifier cannot be used together with an
    #         XPG positional specifier.

    set longp                 {%([0-9]+\$)?([+ 0#-]*)(\*|[0-9]+)?(\.[0-9]+)?l[duioxXcsfeEgG]}
    set clash                    {%([0-9]+\$)([+ 0#-]*)(\*)(\.[0-9]+)?([hl])?[duioxXcsfeEgG]}
    set pattn     {%([0-9]+\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?([hl])?[duioxXcsfeEgG]}
    set patts {%([0-9]{1,2}\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?([hl])?[duioxXcsfeEgG]}

    if {[regexp $longp $value]} {
	if {[pcx::getCheckVersion coreTcl] > 8.3} {
	    logError warnBehaviourCmd [getTokenRange $word] \
		    "l modifier in \"$value\" now treats\
		    argument as wide integer"
	}
    }

    if {[regexp $clash $value]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    }

    # We make sure to process one specifier after another, including %%
    # Otherwise we might get into sync trouble if something looks like
    # a specifier, but isn't.
    #
    # Example: %.0f%% full
    #               ~~~ looks like a specifier,but is not, the %% has
    #                   precendence.

    set nvalue $value
    while {
	[regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	[regsub $pattn       $nvalue {}   nvalue]
    } {}

    if {[regexp {%} $nvalue]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    } else {
	# No errors, run the loop again, but accept only double-digit
	# positional specs. If we have left overs from that we then
	# warn about possible bogus position values.

	set nvalue $value
	while {
	    [regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	    [regsub $patts       $nvalue {}   nvalue]
	} {}

	if {[regexp {%} $nvalue]} {
	    logError coreTcl::warnFormatFmt [getTokenRange $word] $value
	}
    }

    return [incr index]
}

proc ::coreTcl::checkFormatFmt85 {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    # Ok, we got the literal value ...

    # Remove everything which looks like a valid %-specifier
    # Not quite: We do not remove specifiers containing the
    # l length modifier. If such are present (and we are doing
    # 8.4 and above we warn about the change in behaviour).

    # clash - The * width specifier cannot be used together with an
    #         XPG positional specifier.

    # In 8.5 the bignum support added more specifiers:
    # lld, lli, llo, llx, llX.
    # Note: No llu!

    set longp                   {%([0-9]+\$)?([+ 0#-]*)(\*|[0-9]+)?(\.[0-9]+)?l[duioxXcsfeEgG]}
    set clash                      {%([0-9]+\$)([+ 0#-]*)(\*)(\.[0-9]+)?([hl])?[duioxXcsfeEgG]}
    set pattn       {%([0-9]+\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?([hl])?[duioxXcsfeEgG]}
    set patts   {%([0-9]{1,2}\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?([hl])?[duioxXcsfeEgG]}
    set bnpattn     {%([0-9]+\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?ll?[dioxX]}
    set bnpatts {%([0-9]{1,2}\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?ll?[dioxX]}

    if {[regexp $longp $value]} {
	logError warnBehaviourCmd [getTokenRange $word] \
	    "l modifier in \"$value\" now treats argument as wide integer"
    }

    if {[regexp $clash $value]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    }

    # We make sure to process one specifier after another, including %%
    # Otherwise we might get into sync trouble if something looks like
    # a specifier, but isn't.
    #
    # Example: %.0f%% full
    #               ~~~ looks like a specifier,but is not, the %% has
    #                   precendence.

    set nvalue $value
    while {
	[regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	[regsub $bnpattn     $nvalue {}   nvalue] ||
	[regsub $pattn       $nvalue {}   nvalue]
    } {}

    if {[regexp {%} $nvalue]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    } else {
	# No errors, run the loop again, but accept only double-digit
	# positional specs. If we have left overs from that we then
	# warn about possible bogus position values.

	set nvalue $value
	while {
	    [regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	    [regsub $bnpatts     $nvalue {}   nvalue] ||
	    [regsub $patts       $nvalue {}   nvalue]
	} {}

	if {[regexp {%} $nvalue]} {
	    logError coreTcl::warnFormatFmt [getTokenRange $word] $nvalue
	}
    }

    return [incr index]
}


proc ::coreTcl::checkFormatFmt86 {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    # Ok, we got the literal value ...

    # Remove everything which looks like a valid %-specifier
    # Not quite: We do not remove specifiers containing the
    # l length modifier. If such are present (and we are doing
    # 8.4 and above we warn about the change in behaviour).

    # clash - The * width specifier cannot be used together with an
    #         XPG positional specifier.

    # In 8.5 the bignum support added more specifiers:
    # lld, lli, llo, llx, llX.
    # Note: No llu!

    # In 8.6 the binary support added specifier 'b'.

    set longp                   {%([0-9]+\$)?([+ 0#-]*)(\*|[0-9]+)?(\.[0-9]+)?l[bduioxXcsfeEgG]}
    set clash                      {%([0-9]+\$)([+ 0#-]*)(\*)(\.[0-9]+)?([hl])?[bduioxXcsfeEgG]}
    set pattn       {%([0-9]+\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?([hl])?[bduioxXcsfeEgG]}
    set patts   {%([0-9]{1,2}\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?([hl])?[bduioxXcsfeEgG]}
    set bnpattn     {%([0-9]+\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?ll?[bdioxX]}
    set bnpatts {%([0-9]{1,2}\$)?([+ 0#-]*)(\*|[0-9]+)?(\.(\*|[0-9]+)?)?ll?[bdioxX]}

    if {[regexp $longp $value]} {
	logError warnBehaviourCmd [getTokenRange $word] \
	    "l modifier in \"$value\" now treats argument as wide integer"
    }

    if {[regexp $clash $value]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    }

    # We make sure to process one specifier after another, including %%
    # Otherwise we might get into sync trouble if something looks like
    # a specifier, but isn't.
    #
    # Example: %.0f%% full
    #               ~~~ looks like a specifier,but is not, the %% has
    #                   precendence.

    set nvalue $value
    while {
	[regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	[regsub $bnpattn     $nvalue {}   nvalue] ||
	[regsub $pattn       $nvalue {}   nvalue]
    } {}

    if {[regexp {%} $nvalue]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    } else {

	# No errors, run the loop again, but accept only double-digit
	# positional specs. If we have left overs from that we then
	# warn about possible bogus position values.

	set nvalue $value
	while {
	    [regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	    [regsub $bnpatts     $nvalue {}   nvalue] ||
	    [regsub $patts       $nvalue {}   nvalue]
	} {}

	if {[regexp {%} $nvalue]} {
	    logError coreTcl::warnFormatFmt [getTokenRange $word] $value
	}
    }

    return [incr index]
}

# coreTcl::checkScanFmt --

proc ::coreTcl::checkScanFmt {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    # Ok, we got the literal value ...

    # Remove everything which looks like a valid %-specifier
    # Not quite: We do not remove specifiers containing the
    # 'l' length modifier. If such are present (and we are doing
    # 8.4 and above we warn about the change in behaviour).

    # clash - The * width specifier cannot be used together with an
    #         XPG positional specifier.

    set pattn {%(\*)?([0-9]+\$)?([0-9]+)?([hlL])?[doxuicnsefg[]}
    set longp {%(\*)?([0-9]+\$)?([0-9]+)?[lL][doxuicnsefg[]}

    if {[regexp $longp $value]} {
	if {[pcx::getCheckVersion coreTcl] > 8.3} {
	    logError warnBehaviourCmd [getTokenRange $word] \
		    "l modifier in \"$value\" does not\
		    ignore the field width anymore"
	}
    }

    set nvalue $value
    while {
	[regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	[regsub $pattn       $nvalue {}   nvalue]
    } {}

    # Known problem: This test may overreact if a field specifier
    # contained a character class [...] or [^...], and the class
    # contained the % character.

    if {[regexp {%} $nvalue]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    }

    return [incr index]
}

proc ::coreTcl::checkScanFmt85 {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    # Ok, we got the literal value ...

    # Remove everything which looks like a valid %-specifier
    # Not quite: We do not remove specifiers containing the
    # 'l' length modifier. If such are present (and we are doing
    # 8.4 and above we warn about the change in behaviour).

    # clash - The * width specifier cannot be used together with an
    #         XPG positional specifier.

    # In 8.5 the bignum support added more specifiers:
    # lld, lli, llo, llx, llX.
    # Note: No llu!

    set pattn   {%(\*)?([0-9]+\$)?([0-9]+)?([hlL])?[doxuicnsefg[]}
    set longp   {%(\*)?([0-9]+\$)?([0-9]+)?[lL][doxuicnsefg[]}
    set bnpattn {%(\*)?([0-9]+\$)?([0-9]+)?ll[dioxX]}

    if {[regexp $longp $value]} {
	logError warnBehaviourCmd [getTokenRange $word] \
	    "l modifier in \"$value\" does not ignore the field width anymore"
    }

    set nvalue $value
    while {
	[regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	[regsub $bnpattn     $nvalue {}   nvalue] ||
	[regsub $pattn       $nvalue {}   nvalue]
    } {}

    # Known problem: This test may overreact if a field specifier
    # contained a character class [...] or [^...], and the class
    # contained the % character.

    if {[regexp {%} $nvalue]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    }

    return [incr index]
}

proc ::coreTcl::checkScanFmt86 {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }
    # Ok, we got the literal value ...

    # Remove everything which looks like a valid %-specifier
    # Not quite: We do not remove specifiers containing the
    # 'l' length modifier. If such are present (and we are doing
    # 8.4 and above we warn about the change in behaviour).

    # clash - The * width specifier cannot be used together with an
    #         XPG positional specifier.

    # In 8.5 the bignum support added more specifiers:
    # lld, lli, llo, llx, llX.
    # Note: No llu!

    # In 8.6 the binary support added specifier 'b'.

    set pattn   {%(\*)?([0-9]+\$)?([0-9]+)?([hlL])?[bdoxuicnsefg[]}
    set longp   {%(\*)?([0-9]+\$)?([0-9]+)?[lL][bdoxuicnsefg[]}
    set bnpattn {%(\*)?([0-9]+\$)?([0-9]+)?ll[bdioxX]}

    if {[regexp $longp $value]} {
	logError warnBehaviourCmd [getTokenRange $word] \
	    "l modifier in \"$value\" does not ignore the field width anymore"
    }

    set nvalue $value
    while {
	[regsub {^([^%]*)%%} $nvalue {\1} nvalue] ||
	[regsub $bnpattn     $nvalue {}   nvalue] ||
	[regsub $pattn       $nvalue {}   nvalue]
    } {}

    # Known problem: This test may overreact if a field specifier
    # contained a character class [...] or [^...], and the class
    # contained the % character.

    if {[regexp {%} $nvalue]} {
	logError coreTcl::badFormatFmt [getTokenRange $word] $value
    }

    return [incr index]
}

# coreTcl::checkSerialMode --

proc ::coreTcl::checkSerialMode {tokens index} {
    set word [lindex $tokens $index]
    if {![getLiteral $word value]} {
	return [checkWord $tokens $index]
    }

    # A literal value can be checked.
    # baud,             parity, data,  stop
    # [0-9]*[1-9][0-9]*,[noems],[5678],[12]

    if {![regexp {[0-9]*[1-9][0-9]*,[noems],[5678],[12]} $value]} {
	logError coreTcl::badSerialMode [getTokenRange $word] $value
    }
    return [incr index]
}


proc ::coreTcl::checkPackageProvide {tokens index} {
    variable ::analyzer::pOp        none
    variable ::analyzer::pName      {}
    variable ::analyzer::pVersion   {}

    set newindex [checkSimpleArgs 1 2 \
	    {{checkPackageName provide} checkPkgVersion} \
	    $tokens $index]

    #puts stderr "@@/$pOp/$pName/$pVersion/"

    if {($configure::xref || $configure::packages) && ($pOp ne "none") && ($pVersion ne "")} {
	xref::pkgrecord $pName provide $pVersion _dummy_
	#puts @@\\
    }

    return $newindex
}

proc ::coreTcl::checkPackageRequire {tokens index} {
    # Standard checks. We capture any errors, to see if there are
    # any. The types are not important, just their presence. Because
    # if the code has errors we can askip the loading of the checker
    # package for that package if there is any.

    # Note: As a sideeffect it stores some pieces of data in
    #       analyzer variables. These we then use to record
    #       xref information about the 'require'ment. This
    #       info however is also very useful for the PCX
    #       handling code. No need to duplicate data extraction.

    variable ::analyzer::pOp          none
    variable ::analyzer::pName        {}
    variable ::analyzer::pVersion     {}
    variable ::analyzer::pVersionType unknown
    variable ::analyzer::lastSwitch   {}

    logOpen
    set newindex [checkSwitches 1 {-exact} {
	checkSimpleArgs 1 2 {{checkPackageName require} \
		checkPkgVersion}
    } $tokens $index] ; # {}
    set hasErrors 0
    foreach e [logGet] {
	set hasErrors 1
	{*}$e
    }

    set exact [expr {$lastSwitch eq "-exact"}]

    #puts stderr "@@/$pOp/$pName/$pVersion/$lastSwitch/"

    if {($configure::xref || $configure::packages) && ($pOp ne "none")} {
	xref::pkgrecord $pName require $pVersion $exact
	#puts @@\\
    }
    if {$hasErrors} {return $newindex}

    # Ok, the input is ok, as it could be checked at all. If there is
    # enough literal information we use it to load additional checker
    # packages into the system. This happens during the scan phase.
    # This command must not be called during analysis.

    set errRange [getTokenRange [lindex $tokens $index]]
    coreTcl::GetPackage $pName $pVersion $pVersionType $exact $errRange

    return $newindex
}

proc ::coreTcl::checkPackageProvide85 {tokens index} {
    variable ::analyzer::pOp      none
    variable ::analyzer::pName    {}
    variable ::analyzer::pVersion {}

    set newindex [checkSimpleArgs 1 2 \
	    {{checkPackageName provide} checkPkgExtVersion} \
	    $tokens $index]

    #puts stderr "@@/$pOp/$pName/$pVersion/"

    if {($configure::xref || $configure::packages) && ($pOp ne "none") && ($pVersion ne "")} {
	xref::pkgrecord $pName provide $pVersion _dummy_
	#puts @@\\
    }

    return $newindex
}

proc ::coreTcl::checkPackageRequire85 {tokens index} {
    # Standard checks. We capture any errors, to see if there are
    # any. The types are not important, just their presence. Because
    # if the code has errors we can askip the loading of the checker
    # package for that package if there is any.

    # Note: As a sideeffect it stores some pieces of data in
    #       analyzer variables. These we then use to record
    #       xref information about the 'require'ment. This
    #       info however is also very useful for the PCX
    #       handling code. No need to duplicate data extraction.

    variable ::analyzer::pOp           none
    variable ::analyzer::pName         {}
    variable ::analyzer::pVersion      {}
    variable ::analyzer::pVersionType  unknown
    variable ::analyzer::pRequirements {}

    set errRange [getTokenRange [lindex $tokens $index]]

    logOpen
    set newindex [checkOption {
	{-exact {isPkgExact {checkSimpleArgs 2 2 {
	    {checkPackageName require}
	    checkPkgExtVersion
	}}}}
    } {checkSimpleArgs 1 -1 {
	{checkPackageName require}
	checkPkgRequirement
    }} $tokens $index] ; # {}

    set hasErrors 0
    foreach e [logGet] {
	set hasErrors 1
	{*}$e
    }

    if {($pName eq "") && ($pVersionType eq "exact")} {
	# Error in the exact branch is either wrong#args, or bad
	# version. Reparse with less restrictions on #args to get at
	# least the package name out of it.

	logOpen
	set last [checkSimpleArgs 2 -1 {
	    checkWord
	    {checkPackageName require}
	    checkPkgExtVersion
	} $tokens $index]
	logGet

	#puts |||$index|$last|[expr {$last - $index}]
	if {$last - $index <= 2} {
	    logError coreTcl::pkgBadExactRq $errRange
	}
    }

    # If we went through the -exact branch translate the result into a
    # regular requirement, so that the backend does not have to deal
    # with special cases.

    if {($pVersionType ne "non-exact") && ($pVersionType ne "unknown")} {
	lappend pRequirements ${pVersion}-$pVersion
	set     pVersionType non-exact
	set     pVersion {}
    }

    #puts stderr "@@/$pOp/$pName/$pRequirements/$pVersionType/"

    if {($configure::xref || $configure::packages) && ($pOp ne "none")} {
	xref::pkgrecord $pName require $pRequirements 0
	#puts @@\\
    }
    if {$hasErrors} {return $newindex}

    # Ok, the input is ok, as it could be checked at all. If there is
    # enough literal information we use it to load additional checker
    # packages into the system. This happens during the scan phase.
    # This command must not be called during analysis.

    coreTcl::GetPackage85 $pName $pRequirements $errRange

    return $newindex
}

proc ::coreTcl::GetPackage {pkg ver vertype exact errRange} {

    #puts stderr core/getp/$pkg/$ver/$exact/$errRange/

    if {$exact && ($ver == {})} {
	# We do not throw an error message to the user if the version
	# is present, just not a literal value.

	if {$vertype ne "dynamic"} {
	    logError coreTcl::pkgBadExactRq $errRange
	}
	set exact 0
    }

    ## Get the checker package for the package. We abort if some error
    ## occured (No checker available, or bad code).

    if {[catch {::pcx::load $pkg} msg]} {
	#puts stderr "\tError loading checker for $pkg | $msg"

	logError coreTcl::pkgUnchecked $errRange $msg
	return
    }

    ## Now that we have the checker package we can work on resolving
    ## which version of the definitions we (will) have to use.

    set chkPkg [::pcx::checkerOf $pkg]

    #puts stderr core/getp/ck/$chkPkg/

    if {![::pcx::isActive $chkPkg chkVers]} {
	# Activate the package checker iff not already active.

	set chkVers [GetPkgCheckerVersion $pkg $chkPkg $ver $exact \
		$errRange]

	#puts stderr core/getp/v/$chkVers/

	if {$chkVers == {}} {return}

	::pcx::require $chkPkg $chkVers uproc::all uproc::__vardb__
    } else {
	# Definitions for the package are already active in the
	# checker. Compare the active against the requested version,
	# if any.

	ReportChkVersionConflicts $chkVers $ver $pkg $exact $errRange
    }
    return
}


proc ::coreTcl::GetPackage85 {pkg requirements errRange} {
    ## Get the checker package for the package. We abort if some error
    ## occured (No checker available, or bad code).

    if {[catch {::pcx::load $pkg} msg]} {
	#puts stderr "\tError loading checker for $pkg | $msg"

	logError coreTcl::pkgUnchecked $errRange $msg
	return
    }

    ## Now that we have the checker package we can work on resolving
    ## which version of the definitions we (will) have to use.

    set chkPkg [::pcx::checkerOf $pkg]

    #puts stderr \[core/getp/ck/$chkPkg\]

    if {![::pcx::isActive $chkPkg chkVers]} {
	# Activate the package checker iff not already active.

	set chkVers [GetPkgCheckerVersion85 $pkg $chkPkg \
			 $requirements $errRange]

	#puts stderr core/getp/v/$chkVers/

	if {$chkVers == {}} {return}

	::pcx::require $chkPkg $chkVers uproc::all uproc::__vardb__
    } else {
	# Definitions for the package are already active in the
	# checker. Compare the active against the requested version,
	# if any.

	ReportChkVersionConflicts85 $chkVers $requirements $pkg $errRange
    }
    return
}


proc ::coreTcl::ReportChkVersionConflicts {chkVers ver pkg exact errRange} {

    #puts stderr core/rep/v/confl/ck/$chkVers/rq/$ver/$exact/$pkg 

    if {$exact} {
	if {$ver ne $chkVers} {
	    logError coreTcl::pkgVConflict $errRange $ver $chkVers
	}
    } elseif {$ver != {}} {
	# ver 1.5 is asked for, checker is 1.3 => bad
	# ver 1.3 is asked for, checker is 1.5 => ok
	# <=> package vsatisfies 1.5 1.3

	if {![package vsatisfies $chkVers $ver]} {
	    logError coreTcl::pkgVConflict $errRange $ver $chkVers
	} elseif {($ver ne $chkVers) && ($pkg eq "Tcl")} {
	    logError coreTcl::warnTclConflict $errRange $ver $chkVers
	}
    }
    return
}

proc ::coreTcl::ReportTclVersionConflicts {pkg chkPkg chkVers errRange} {

    #puts stderr core/rep/tcl/confl/$pkg/$chkPkg/$chkVers

    set tcl  [::pcx::getCheckVersion coreTcl]

    if {[catch {set ctcl [::pcx::tclOf $chkPkg $chkVers]}]} {
	logError coreTcl::pkgTclUnknown $errRange \
		$pkg $chkVers $tcl
	return
    }

    #puts stderr core/rep/tcl/confl/ctcl/$ctcl/tcl/$tcl/$pkg/$chkPkg/$chkVers

    if {![package vsatisfies $tcl $ctcl]} {
	logError coreTcl::pkgTclConflict $errRange \
		$pkg $chkVers $ctcl $tcl
    }
}

proc ::coreTcl::GetPkgCheckerVersion {pkg chkPkg ver exact errRange} {
    # We know here that there are no active checker definitions for
    # the package. We have to select some version number which is
    # supported by the checker package and a minimum of conflicts.

    # There are three situations to consider.
    # - Package requests exact version.
    # - Package requests version, but allows higher versions as
    #   long as the major version number is the same.
    # - Package requests no specific version.

    # In addition to the above the user may have asked to check the
    # code for a specific version of the package too.

    # Rules ...

    # I. User has priority, always. IOW if a recommendation is present
    # .. we use it, except if the checker package does not support
    # .. it. The latter case is handled as if no recommendation was
    # .. given at all. If a recommendation is used it can be in
    # .. conflict with the version of tcl we check against. We report
    # .. this, but use the user chosen information nevertheless. We
    # .. also report if it is in conflict the version requested by the
    # .. statement, if any.

    set userRecommends [::pcx::useRequest $pkg]
    if {
	($userRecommends != {}) &&
	[::pcx::supported $chkPkg $userRecommends]
    } {
	if {$exact || ($ver != {})} {
	    ReportChkVersionConflicts $userRecommends $ver $pkg $exact $errRange
	}
	ReportTclVersionConflicts $pkg $chkPkg $userRecommends $errRange
	return $userRecommends
    }

    # II. User is not asserting his priority.
    # ... The command we are currently checking however has requested
    # ... an exact version. If the version is not supported by loaded
    # ... checker definitions, then we drop the requirement for
    # ... exactness. Otherwise we choose this version, and report any
    # ... conflicts it might have.

    set oexact $exact
    if {$exact} {
	if {[::pcx::supported $chkPkg $ver]} {
	    ReportTclVersionConflicts $pkg $chkPkg $ver $errRange
	    return $ver
	}
	set exact 0
    }

    # III. The command is asking for a version, but does not require
    # .... exactness. We use the highest version greater than or equal
    # .... than requested which is supported by the checker for the
    # .... current version of Tcl, or higher. If there is none then we
    # .... handle this as if no version was specified at all.

    set coreTclVer [::pcx::getCheckVersion coreTcl]
    set over $ver

    if {$ver != {}} {
	set useable [::pcx::allfor $chkPkg $coreTclVer]

	#puts stderr core/getpv/$chkPkg/$coreTclVer/$ver/$useable/

	foreach v $useable {
	    if {[package vsatisfies $v $ver]} {
		ReportChkVersionConflicts $v $over $pkg $oexact $errRange
		return $v
	    }
	}
	# As explanation why the version was not taken.
	ReportTclVersionConflicts $pkg $chkPkg $ver $errRange
    }

    # We use the highest version which is supported by the checker for
    # the current version of Tcl, or higher. If there is none we
    # simply use the highest supported version. If the package does
    # not support any version we punt.

    set ver [::pcx::highest $chkPkg $coreTclVer]
    if {$ver != {}} {
	if {$oexact || ($over != {})} {
	    ReportChkVersionConflicts $ver $over $pkg $exact $errRange
	}
	ReportTclVersionConflicts $pkg $chkPkg $ver $errRange
	return $ver
    }

    set ver [::pcx::highest $chkPkg]
    if {$ver != {}} {
	if {$oexact || ($over != {})} {
	    ReportChkVersionConflicts $ver $over $pkg $exact $errRange
	}
	ReportTclVersionConflicts $pkg $chkPkg $ver $errRange
	return $ver
    }

    logError coreTcl::pkgUnchecked $errRange "PCX file does not support anything"
    return {}
}


proc ::coreTcl::GetPkgCheckerVersion85 {pkg chkPkg requirements errRange} {
    # We know here that there are no active checker definitions for
    # the package. We have to select some version number which is
    # supported by the checker package and a minimum of conflicts.

    # We have to see if we can satisfy the given requirements or not.

    # In addition to the above the user may have asked to check the
    # code for a specific version of the package too.

    # Rules ...

    # I. User has priority, always. IOW if a recommendation is present
    # .. we use it, except if the checker package does not support
    # .. it. The latter case is handled as if no recommendation was
    # .. given at all. If a recommendation is used it can be in
    # .. conflict with the version of tcl we check against. We report
    # .. this, but use the user chosen information nevertheless. We
    # .. also report if it is in conflict the version requested by the
    # .. statement, if any.

    set userRecommends [::pcx::useRequest $pkg]
    if {
	($userRecommends != {}) &&
	[::pcx::supported $chkPkg $userRecommends]
    } {
	ReportChkVersionConflicts85 $userRecommends $requirements $pkg $errRange
	return $userRecommends
    }

    # II. User is not asserting his priority.
    # ... The command may have made some requirements. Go through the
    # ... set of available versions and determine which of them
    # ... satisfy the requirements. Reduce this further by looking at
    # ... what is required by the current version of Tcl. If any of
    # ... the steps result in an empty set report that and then
    # ... activate the highest possible version per Tcl. Otherwise
    # ... choose the highest possible from the set.

    set coreTclVer [::pcx::getCheckVersion coreTcl]

    if {[llength $requirements]} {
	set satisfying [struct::list filter \
			    [struct::list map \
				 [pcx::allavailable $chkPkg] \
				 ::coreTcl::dekey] \
			    [list ::coreTcl::Satisfied $requirements]]

	if {[llength $satisfying]} {
	    struct::set subtract satisfying [pcx::allfor $chkPkg $coreTclVer]
	}
    } else {
	set satisfying [pcx::allfor $chkPkg $coreTclVer]
    }

    if {![llength $satisfying]} {
	set ver [::pcx::highest $chkPkg $coreTclVer]
	if {$ver == {}} {
	    set ver [::pcx::highest $chkPkg]
	}
	if {$ver == {}} {
	    logError coreTcl::pkgUnchecked $errRange "PCX file does not support anything"
	    return {}
	}
    } else {
	set ver [lindex [lsort -dict $satisfying] end]
    }

    return $ver
}

proc ::coreTcl::dekey {v} {
    # The argument has the form 'name,version', we need only the
    # version of that.
    return [lindex [split $v ,] end]
}

proc ::coreTcl::Satisfied {requirements v} {
    return [package vsatisfies $v {*}$requirements]
}

proc ::coreTcl::ReportChkVersionConflicts85 {chkVers requirements pkg errRange} {

    #puts stderr core/rep/v/confl/ck/$chkVers/rq/$requirements/$pkg 

    # No requirements, active version is ok, nothing to report.
    if {![llength $requirements]} return

    # ver 1.5 is asked for, checker is 1.3 => bad
    # ver 1.3 is asked for, checker is 1.5 => ok
    # <=> package vsatisfies 1.5 1.3

    if {![::coreTcl::PackageVsatisfies $chkVers $requirements]} {
	logError coreTcl::pkgVConflict $errRange $requirements $chkVers
	return
    }

    # The Tcl check makes no real sense anymore, I think.
    if {0 && ($requirements ne $chkVers) && ($pkg eq "Tcl")} {
	logError coreTcl::warnTclConflict $errRange $requirements $chkVers
    }
    return
}


proc ::coreTcl::PackageVsatisfies {v reqs} {
    set vList [::analyzer::vIntList $v]	;# verify valid version number
    foreach requirement $reqs {  ;# check all valid requirements
 	if {[llength [Lassign [split $requirement -] min max]]} {
 	    # More than one "-"
 	    return -code error "invalid requirement: \"$requirement\""
 	}
 	if {[catch {::analyzer::vIntList $min}]} {
 	    return -code error "invalid requirement: \"$requirement\""
 	}
 	if {$max ne "" && [catch {::analyzer::vIntList $max}]} {
 	    return -code error "invalid requirement: \"$requirement\""
 	}
    }
    foreach requirement $reqs {
 	Lassign [split $requirement -] min max
 	set minList [::analyzer::vIntList $min]
 	lappend minList -2
 	if {[Compare $vList $minList] < 0} {
 	    continue ;# not satisfied; on to the next one
 	}
 	if {[string match *- $requirement]} {
 	    # No max constraint => satisfied!
 	    return 1
 	}
 	if {$max eq ""} {
 	    set max [lindex $minList 0]
 	    incr max
 	}
 	set maxList [::analyzer::vIntList $max]
 	lappend maxList -2
 	if {[Compare $minList $maxList] == 0} {
 	    # Special case for "-exact" range
 	    set minList [lreplace $minList end end]
 	    if {[Compare $vList $minList] == 0} {
 		return 1
 	    }
 	    continue
 	}
 	if {[Compare $vList $maxList] < 0} {
 	    # Within the range => satisfied!
 	    return 1
 	}
    }
    return 0
}

proc ::coreTcl::Lassign {list args} {
    foreach v $args {upvar 1 $v x ; set x {}}
    foreach v $args x $list {upvar 1 $v var ; set var $x}
    if {[llength $args] < [llength $list]} {
 	set notassigned [lrange $list [llength $args] end]
    } else {
 	set notassigned {}
    }
    return $notassigned
}

proc ::coreTcl::Compare {l1 l2} {
    # Compare lists of integers
    foreach i1 $l1 i2 $l2 {
	if {$i1 eq {}} {set i1 0}
	if {$i2 eq {}} {set i2 0}
	if {$i1 < $i2} {return -1}
	if {$i1 > $i2} {return 1}
    }
    return 0
}

# ### ######### ###########################
## Tcl 8.6 - zlib pieces.

proc ::coreTcl::checkZlibChecksumCmd {tokens index} {
    return [checkSimpleArgs 1 -1 {
	checkWord
	{checkSwitches 1 {
	    {-startValue {checkInt}}
	} {}}
    } $tokens $index]
}

proc ::coreTcl::checkZlibDecompressCmd {tokens index} {
    return [checkSimpleArgs 1 -1 {
	checkWord
    } $tokens $index]
}

proc ::coreTcl::checkZlibCompressCmd {tokens index} {
    return [checkSimpleArgs 1 -1 {
	checkWord
	{checkSwitches 1 {
	    {-level {coreTcl::checkZlibLevels}}
	} {}}
    } $tokens $index]
}

proc ::coreTcl::checkZlibLevels {tokens index} {
    return [checkKeyword 1 {
	0 1 2 3 4 5 6 7 8 9
    } $tokens $index]
}

proc ::coreTcl::checkZlibCommand {tokens index} {
    return [checkKeyword 1 {
	deflate inflate compress decompress gzip gunzip
    } $tokens $index]
}

proc ::coreTcl::checkZlibHeaderDict {tokens index} {
    return [checkListValuesModNk 0 -1 2 0 {
	{checkOption {
	    {crc      {checkWord}}
	    {filename {checkFilename}}
	    {os       {checkInt}}
	    {size     {checkInt}}
	    {time     {checkInt}}
	    {type     {checkKeyword 1 {binary text}}}
	} {}}
    } $tokens $index]
}

proc ::coreTcl::checkPickProcOnePass {tokens index} {
    if {[analyzer::isTwoPass]} { return $index }
    return [analyzer::addContext 1 1 {} {} {checkSimpleArgs 3 3 {
	{newScope proc addUserProc}
	addArgList
	checkWord
    }} $tokens $index]
}


# ### ######### ###########################
pcx::complete
