# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# tclapp_msgs.tcl --
# -*- tcl -*-
#
#	Message facility.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.

#
# RCS: @(#) $Id: tdkwrap.tcl,v 1.7 2001/02/08 21:44:30 welch Exp $

package provide tclapp::msgs 1.0

namespace eval ::tclapp::msgs {

    namespace export get

    # The set of error and other messages that may be encountered
    # during the application.

    variable msgStrings
    
    append msgStrings(0_USAGE_STATEMENT) \
	"Usage: [cmdline::getArgv0] ?options? ?fileNamePatterns? "\
	"?options? fileNamePatterns ...\n" \
	"  -alias path              Specify wrapped name of file that follows\n" \
	"  -anchor path             Specify base path in archive for files that follow\n" \
	"  -app name                Like -pkg, and marks the package as the entrypoint for the application\n" \
	"  -architecture name       Specify the list of architectures for the wrap result. Useful for\n" \
	"                           defining multi-architecture starkit. For starpacks better rely\n" \
	"                           on inheriting this information from the -prefix\n" \
	"  -archive path|url        Specify a per-project repository to search for packages\n" \
	"  -arguments arguments     Specify additional arguments to application\n" \
	"  -code script             Interpreter initialization script\n" \
	"  -compile                 Compile tcl files before wrapping them (implies '-pkg tbcload')\n" \
	"  -compilefile             Explicitly force compilation of just the next file\n" \
	"  -compilefor tclVersion   Compile bytecodes for the specific version Tcl\n" \
	"  -config fileName         Collect more command line args from a file\n" \
	"  -encoding name           Specify additional encoding for starpack\n" \
	"  -executable fileName     Name of base kit (deprecated, use -prefix)\n" \
	"  -follow                  Add the required dependencies of the specified packages to the wrap result\n" \
	"  -follow-recommend        See -follow, but also add the recommended dependencies\n" \
	"  -force                   Accept missing package dependencies\n" \
	"  -fsmode mode             Set handling of the metakit database in the wrap result\n" \
	"                           transparent => readonly, writable => nocommit\n" \
	"  -help                    print this help message\n" \
	"  -icon path               Path to the icon to embed into the executable\n" \
	"  -infoplist dict          Metadata for OS X, as a Tcl dictionary. Ignored if -osxapp is not set\n" \
	"  -interpreter path        Name interpreter to insert into starkit\n" \
	"  -log path                Path to logfile\n" \
	"  -merge                   merge given files into output file\n" \
	"  -metadata dict           Metadata for Teapot, as a Tcl dictionary\n" \
	"  -nocompilefile           Explicitly force non-compilation of just the next file\n" \
	"  -nocompress              Do not compress the files in the wrap result\n" \
	"  -nologo                  Suppress copyright banner\n" \
	"  -noprovided              Prevent generation of a listing of all packages wrapped into the -output\n" \
	"  -nospecials              Prevent generation of main.tcl and application pkgIndex.tcl\n" \
	"  -notbcload               Suppresses the implicit '-pkg tbcload' of '-compile' above\n" \
	"  -osxapp                  Declare that output should be an OS X .app bundle\n" \
	"  -out fileName            Name of output file (default: tclapp-out?.kit?)\n" \
	"  -pkg-accept              Deprecated, use -upgrade\n" \
	"  -pkg name                Wrap all files of the specified package (simple syntax)\n" \
	"                           Syntax: 'name'|'name-version'\n" \
	"  -pkgdir path             Specify additional search path for package in non-standard location\n" \
	"  -pkgfile path            Specify package explicitly as path to package archive file\n" \
	"                           Commandline only option\n" \
	"  -pkgref ref              Like -pkg, but accepts syntax of Teapot package references\n" \
	"  -prefix fileName         Name of base kit\n" \
	"  -postcode script         Interpreter initialization script, run after application start\n" \
	"  -relativeto directory    Specify a relative directory for files that follow\n" \
	"  -startup initialScript   Declare starting script filename\n" \
	"  -stringinfo dict         Metadata for Windows (String resources), as a Tcl dictionary\n" \
	"  -temp directory          Specify an alternate temp. directory\n" \
	"  -upgrade                 Accept packages of higher versions found by a fuzzy search\n" \
	"                           when the regular exact search failed\n" \
	"  -verbose                 Produce detailed output during wrapping\n" \
	""

    array set msgStrings {
	0_USE_HELP_FOR_MORE_INFO
	    "(use \"-help\" for legal options)"
	1_NO_STARTUP_FILE_SPECIFIED
	    "no startup file specified"
	2_MALFORMED_STDIN_ARGS
	    "malformed arguments string from standard input"

	39_INVALID_INPUT_EXECUTABLE_TEAPOT_SYNTAX
	    "Bad syntax of Teapot-Prefix \"%s\""
	40_INVALID_INPUT_EXECUTABLE_TEAPOT
	    "Teapot-Prefix \"%s\" could not be found: %s"
	41_EXECUTABLE_SAME_AS_OUTPUT
	    "-prefix \"%s\" is the same as -out \"%s\""
	42_MISSING_EXECUTABLE_FLAG
	    "-prefix is a required flag"
	43_EXECUTABLE_DOES_NOT_EXIST
	    "-prefix \"%s\" does not exist"
	44_INVALID_INPUT_EXECUTABLE
	    "Prefix \"%s\" does not contain wrapper extensions"
	45_FATAL_ERROR
	    "Fatal error accessing \"%s\": %s"
	46_OUTPUT_DOES_NOT_EXIST
	    "-out \"%s\" does not exist, required for -merge"
	47_EXECUTABLE_NOT_ALLOWED
	    "-prefix not allowed, due to -merge"
	48_MERGE_NOT_ALLOWED
	    "-merge not allowed, due to -prefix"

	49_INTERP_DOES_NOT_EXIST
	    "-interpreter \"%s\" does not exist"
	50_INTERP_NOT_ALLOWED
	    "-interpreter not allowed, due to -merge"
	51_INVALID_INTERP_EXECUTABLE
	    "The chosen prefix file \"%s\" does not support the option '-interpreter'."
	52_INVALID_FSMODE_EXECUTABLE
	    "The chosen prefix file \"%s\" does not support the option '-fsmode'."
	53_FSMODE_NOT_ALLOWED
	    "-fsmode not allowed, due to -merge"
	54_FSMODE_ILLEGAL
	    "-fsmode \"%s\" is not legal"
	55_ICON_DOES_NOT_EXIST
	    "-icon \"%s\" does not exist, ignored"

	90_STARTUPSCRIPT_NOT_WRAPPED
	    "-startup \"%s\", but no such file wrapped"
	91_STARTUPSCRIPT_NOT_ALLOWED
	    "Illegal use of -startup, -app has precedence"

	100_RELATIVE_DOES_NOT_EXIST
	    "-relativeto directory \"%s\" does not exist or may be a file"
	101_NO_MATCHING_FILES
	    "no files matching pattern \"%s\""
	102_RELATIVE_TO
	    " relative to \"%s\""
	103_FILE_MULTIPLE_DIRS
	    "file \"%s\" specified from multiple directories:\n"
	104_CWD
	    "<current working directory>"
	105_RELATIVETO_MISMATCH
	    "-relativeto directory \"%s\" and file name pattern \"%s\" mismatch"

	106_PKGDIR_MISSING
	    "-pkgdir directory \"%s\" is missing in archive"

	110_UNABLE_TO_DETERMINE_TEMPDIR
	    "unable to determine temporary directory"
	111_UNABLE_TO_DESTROY_TEMPDIR
	    "unable to destroy temporary directory"
	112_UNABLE_TO_CREATE_TEMPDIR
	    "unable to create suitable temporary directory"
	113_UNABLE_TO_DETERMINE_TEMPDIR
	    "unable to determine a temporary directory; use -temp flag"
	114_TEMPORARY_DIR_NOEXIST
	    "temporary directory does not exist"
	115_TEMPDIRNAME_DOES_NOT_EXIST
	    "temporary directory \"%s\" does not exist"

	150_CREATING_INITSCRIPTINFOFILE
	    "Creating wrapper information file:\n"
	158_WRAPPER_INFORMATION
	    "    Startup file: \"%s\"\n    Arguments: \"%s\"\n    Base application: \"%s\""
	151_CREATING_APPINITSCRIPTFILE
	    "Creating application initialization script file."
	152_WRAPPING_CONTROL_FILES
	    "Wrapping information files:"
	153_WRAPPING_FILES
	    "Wrapping file(s):"
	154_CREATING_OUTEXEC
	    "Creating output executable:\n    %s"
	157_NOT_COMPRESSING_PATTERNS
	    "    Not compressing patterns: %s\n"
	156_RELATIVE_TO
	    "    Relative to: %s\n"
	155_FILENAME_PATTERNS
	    "    File names:"
	155_WRAPPING_PACKAGES
	    "Wrapping package(s):"

	200_UNSUPPORTED_PLATFORM
	    "unsupported platform"

	300_LOCK_CONFLICT_FILE
	    "package directory %s: invalid attempt to add non-package files"
	301_LOCK_CONFLICT_PKG
	    "directory %s: invalid attempt to make it a package directory"

	400_IN_DIR
	    "    Into: %s\n"

	500_UNKNOWN_PACKAGE
	    "    package '%s' is not known"
	501_EMPTY_PACKAGE
	    "    package '%s' does not provide any files to wrap."

	502_UNKNOWN_PACKAGE_RESOLVED
	    "    package '%s' was not known, changed to '%s'"

	503_NONPACKAGE_REFERENCE
	    "    Unacceptable reference '%s' to non-package."

	504_EMPTY_LOGFILE
	    "Path to logfile is empty."

	505_ICON_NOT_SUPPORTED_BY_PLATFORM
	    "-icon not supported on this platform, ignored"

	506_ICON_NOT_SUPPORTED_BY_INPUT
	    "-icon not supported by prefix file, ignored"

	507_SI_NOT_SUPPORTED_BY_INPUT
	    "-stringinfo not supported by prefix file, ignored. Error: %s"

	508_SI_REPLACEMENT_TOO_LARGE
	    "Stringinfo replacement is too large to fit."

	509_ICON_NOT_ICNS
	    "-icon is not in ICNS format, ignored"

	510_UNKNOWN_ARCHITECTURES
	    "    Could not map architectures '%s' to .tap platform codes, no tap packages possible"

	511_KNOWN_PACKAGE_PLATFORM_MISMATCH
	    "    package '%s' tap definition ignored due to a platform mismatch"

	512_PACKAGE_PLATFORM
	    "        The package is for platform '%s'"

	513_ACCEPTED_PLATFORM
	    "        An acceptable platform would have been '%s'"

	514_MAYBE_NO_PREFIX
	    "        A probable cause for this is that no prefix file was specified"

	600_CONFIG_FILE
	    "Configuration file '%s' does not exist"
    }
}

proc ::tclapp::msgs::get {id} {
    variable msgStrings
    return  $msgStrings($id)
}
