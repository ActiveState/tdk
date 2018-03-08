# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# procomp.tcl --
#
#  Front-end script for the TclPro / Tcl Dev Kit bytecode compiler.
#  Compiles individual TCL scripts, or directories containing TCL scripts.
#  For individual scripts, the output file is either the one specified by the
#  -o flag, or it is created in the same location as the input file, but with
#  a different extension (.tbc). For directories, all files matching a given
#  pattern (which defaults to *.tcl) are compiled; the output files are either
#  placed in the directory specified by the -o flag, or in the same directory
#  as the input files. All output files have the same root as their input file,
#  and different extension.
#
#
# Copyright (c) 2004-2014 ActiveState Software Inc.
# Copyright (c) 1998 by Scriptics Corporation.
#


# 
# RCS: @(#) $Id: procomp.tcl,v 1.4 2001/02/08 21:40:55 welch Exp $

package require Tcl 8.0
package require compiler 1.0 ; # TclPro/AS | Compiler itself
package require fileutil     ; # Tcllib    | File utilities (tmpfile)
package require csv          ; # Tcllib    | CSV processing (See LoadConfig).

package require procomp::config
package provide procomp 1.0

namespace eval procomp {
    namespace export run setLogProc setErrorProc

    # The Log and Error procedures are used to emit output and errors,
    # respectively.

    variable logProc defaultLogProc errorProc defaultErrorProc

    variable fileList {}
    variable headerType auto 
    variable byteCodeExtension .tbc
    variable forceWrite 0
    variable input      cmdline ;# Where input comes from (files on the cmdline, or stdin)

    # This is the tag pattern that is recognized by the 'tag' header type.
    # The tag must appear on a comment line by itself.
    # The tagError variable controls the behaviour of the 'tag' lookup
    # routine; if it is 1, a missing tag trigger an error, if it is 0
    # a missing tag makes the proc return an empty header.

    variable tagValue TclPro::Compiler::Include
    variable tagPattern [format {^[ ]*#[ ]%s[ ]*$} $tagValue]
    variable tagError 0

    # Hold the code to timebomb our result if we are running for a trial version.

    variable code_bomb {}

    # Bugzilla 25844: New option '-'

    variable usage "Usage: [cmdline::getArgv0] ?options? path1 ?path2 ...?
  -             Take input from stdin instead of from files on the command line.
                If -out is present in this mode the result will be written to
                this file, else it will be written to stdout.
  -force	force overwrite; if the output file exists, delete it.
  -help		print this help message.
  -nologo	suppress copyright banner.
  -out name	specifies that the output path is 'name'.  If only one file
		is being compiled, 'name' may specify the complete output file
		name.  Otherwise 'name' must be the name of an existing
		directory to which all compiled files will be written.

		The special value 'stdout' causes the application to write the
		result to stdout instead of a file.

  -prefix type  specifies whether a prefix string should be prepended to the
		emitted output files, and if so how it should be generated
		'type' value can be one of the following:
		  none	do not add a prefix string
		  auto	extract the prefix from the input file: everything
			from the start of the file to the first non-comment
			or empty line is prepended to the output (default)
		  tag	extract the prefix from the input file: everything
			from the start of the file to the first occurrence
			of a comment line starting with the string 
			\"TclPro::Compiler::Include\" is prepended to output
		Any other value for type is assumed to be a path to a
		file that will be used as the output file prefix.
  -quiet	suppress warnings about non-existent files
  -verbose	verbose mode: messages are generated to log progress.
  pathN		one or more files to compile."
}

# procomp::run --
#
#  Runs the package.
#
# Arguments:
#  argList	(optional) the argument list. If not specified, the list is
#		initialized from ::argv.
#
# Results:
#  Returns 1 on success, 0 on failure.

proc procomp::run { {argList {}} } {
    variable fileList
    variable input
    variable outPath

    if {[init $argList] == 0} {
	return 0
    }

    # Bugzilla 25844: New option '-', read code to compile from stdin,
    # and possibly write it to stdout.

    if {[string equal $input stdin]} {
	# Compile the input from stdin ... Use a temp file inside of
	# the starkit (this a nice way for keeping transient data
	# without messing with the native FS ... Love VFS :)

	#set in [file join $starkit::topdir STDIN]
	set in [fileutil::tempfile tclc]

	set          fh [open $in w]
	fcopy stdin $fh
	close       $fh

	if {![info exists outPath] || ($outPath == {}) || ($outPath eq "stdout")} {
	    # Use a second tempfile to keep the result before writing
	    # it down the pipe (stdout).

	    #set outPath [file join $starkit::topdir STDOUT]
	    set outPath $in.out

	    if {![fileCompile $in $outPath]} {
		file delete $in $outPath
		return 0
	    }

	    set fh [open $outPath r]
	    fcopy $fh stdout
	    close $fh

	    file delete $outPath
	} else {
	    # Have an output path, regular compile into it.
	    if {![fileCompile $in]} {
		file delete $in
		return 0
	    }
	}
	file delete $in
	return 1
    } 

    if {[info exists outPath] && (($outPath == {}) || ($outPath eq "stdout"))} {
	set file [lindex $fileList 0]

	# Use a temp file to capture the result, then write it through stdout.

	set outPath [fileutil::tempfile tclc]

	if {![fileCompile $file $outPath]} {
	    file delete $in $outPath
	    return 0
	}

	set fh [open $outPath r]
	fcopy $fh stdout
	close $fh

	file delete $outPath
	return 1
    }

    foreach file $fileList {
	if {![fileCompile $file]} {
	    return 0
	}
    }
    return 1
}

# procomp::setLogProc --
#
#  Sets the log procedure for the package.
#  The log procedure is called by the package when it emits output; it is
#  assumed to take a single argument, the string to log.
#
# Arguments:
#  procName	the name of the log procedure to use
#
# Results:
#  Returns the name of the log procedure that was in use before the call.

proc procomp::setLogProc { procName } {
    variable logProc
    set logProc $procName
}

# procomp::setErrorProc --
#
#  Sets the error log procedure for the package.
#  The error log procedure is called by the package when it emits an error
#  message; it is assumed to take a single argument, the string to log.
#
# Arguments:
#  procName	the name of the log procedure to use
#
# Results:
#  Returns the name of the log procedure that was in use before the call.

proc procomp::setErrorProc { procName } {
    variable errorProc
    set errorProc $procName
}

# procomp::init --
#
#  Initializes the package: checks the arguments, initializes the control
#  structures and checks them for consistency.
#
# Arguments:
#  argList	(optional) the argument list. If not specified, the list is
#		initialized from ::argv.
#
# Results:
#  Returns 1 on success, 0 on failure.

proc procomp::init { {argList {}} } {
    variable headerType
    variable byteCodeExtension [compiler::getBytecodeExtension]
    variable fileList
    variable headerValue
    catch {unset headerValue}
    variable outPath
    catch {unset outPath}
    variable tagValue
    variable logProc
    variable forceWrite
    variable usage
    variable input

    set quiet 0

    if {[string compare $argList {}] == 0} {
	set argList $::argv
    }

    # if the user has entered nothing on the command line, display the
    # usage string and exit with error.
    # --- *** This should not happen anymore *** ---
    # --- *** Because previous code should   *** ---
    # --- *** have invoked the GUI for that  *** ---
    # --- *** case already                   *** ---

    if {[llength $argList] < 1} {
	log $usage
	return 0
    }

    # initialize the control structures from the argument list: parse the
    # flags

    set optionList {
	? f force h help n nologo o.arg out.arg p.arg prefix.arg
	config.arg
	%%.arg
	q quiet v verbose {}
    }

    set input cmdline
    set isVerbose 0
    set projectInfo::printCopyright 1

    array set cfgfiles {}
    array set cfgdata  {}

    set fileArgs {}

    while {[llength $argList]} {
	log::log debug "Process: $argList"

	set err [cmdline::getopt argList $optionList opt arg]

	log::log debug "  $err | $opt | $arg"

	if {$err < 0} {
	    log "[cmdline::getArgv0]: $arg (use \"-help\" for legal options)"
	    return 0
	} elseif {$err == 0} {
	    # File specification in between options.

	    lappend fileArgs [lindex $argList 0]
	    set argList [lrange $argList 1 end]

	} else {
	    # Bugzilla 25844: New option '-', reading code to compile from
	    #                 stdin, and possibly write it to stdout.
	    switch -exact $opt {
		{} {
		    # Just a dash (-), switch to pipe mode - i.e. reading input from stdin.
		    set input stdin
		}
		? -
		h -
		help {
		    log $usage
		    return 1
		}
		f -
		force {
		    set forceWrite 1
		}
		nologo {
		    # This will turn on the copyright printing info
		    # when we check out license.

		    set projectInfo::printCopyright 0
		}

		o -
		out {
		    set outPath $arg
		}

		p -
		prefix {
		    set headerType $arg
		}

		q -
		quiet {
		    set quiet 1
		}

		v -
		verbose {
		    set isVerbose 1
		}

		config {
		    # Here we check existence of configuration files,
		    # convert their contents into option sequences,
		    # and prevent recursive, infinite inclusion.
		    #
		    # For the check here we can simply prepend the new
		    # options to the options still waiting for
		    # processing. Beyond that we remember the mapping
		    # from file name to options so that future passes
		    # don't have to perform the conversion again.

		    set arg [file join [pwd] $arg]
		    set newoptions [LoadConfig $arg cfgfiles]
		    set cfgdata($arg) $newoptions

		    ::log::log debug "Loading $arg"
		    ::log::log debug "\t$newoptions"

		    set argList [concat $newoptions [list -%% $arg] $argList]
		}
		%% {
		    # Pop file context used for recursion check.
		    unset cfgfiles($arg)
		}
	    }
	}
    }

    # After processing args but before we go any futher we check
    # to see if the user has a valid license key.

    if {$projectInfo::printCopyright} {
	set logProc defaultLogProc
	set userinfo [compiler::tdk_license user-name]
	set useremail [compiler::tdk_license user-email]
	if {$useremail ne ""} {
	    append userinfo " <$useremail>"
	}
	log "# Tcl Dev Kit Compiler"
	log "# Copyright (C) 2001-2009 ActiveState Software Inc. All rights reserved."
	log "# [compiler::tdk_license type] license for $userinfo."
	set e [compiler::tdk_license expiration-date]
	if {$e != {}} {
	    log "# Expires: [compiler::tdk_license expiration-date]."
	}
    }

    if {!$isVerbose} {
	set logProc nullLogProc
    }

    # Ensure that the -out option is consistent with the list of files being
    # compiled.  Also ensure that we have at least one file.
    #
    # On the other hand, if input mode is stdin we have to ensure that
    # there are _no_ files at all.

    set fileList [cmdline::getfiles $fileArgs $quiet]

    if {[string equal $input cmdline]} {
	if {[llength $fileList] < 1} {
	    logError "no files to compile"
	    return 0
	} elseif {([llength $fileList] != 1) && [info exists outPath]} {
	    if {($outPath eq "stdout") || ![file isdir $outPath]} {
		logError "-out must specify a directory when compiling more than one file"
		return 0
	    }
	}
    } else {
	# Bugzilla 25844: New option '-', reading code to compile
	#            from stdin, and possibly write it to stdout.

	if {[llength $fileList] > 0} {
	    logError "Taking input from stdin is not consistent with specifying files to compile"
	    return 0
	}
	if {($outPath ne "stdout") && [file isdir $outPath]} {
	    logError "-out must _not_ specify a directory when compiling from stdin"
	}
    }

    # now check the control structures for internal consistency.
    # First, the header type; if not one of the known types, it must be an
    # existing file.

    switch -- $headerType {
	none -
	auto -
	tag {
	}

	default {
	    if {[catch {open $headerType r} istm] == 1} {
		logError "error: bad header type: $istm"
		return 0
	    }

	    set headerValue [read $istm]
	    close $istm
	    append headerValue [format "# %s\n" $tagValue]
	}
    }

    return 1
}

# procomp::defaultLogProc --
#
#  Default logging procedure: writes $msg to stdout.
#
# Arguments:
#  msg		the message to log.
#
# Results:
#  None.

proc procomp::defaultLogProc { msg } {
    puts stdout $msg
}

# procomp::defaultErrorProc --
#
#  Default error logging procedure: writes $msg to stdout.
#
# Arguments:
#  msg		the error message to log.
#
# Results:
#  None.

proc procomp::defaultErrorProc { msg } {
    puts stdout $msg
}

# procomp::nullLogProc --
#
#  Null logging procedure: does nothing with the argument.
#
# Arguments:
#  msg		the message to log.
#
# Results:
#  None.

proc procomp::nullLogProc { msg } {
}

# procomp::log --
#
#  Logging procedure: calls the current log procedure, passes $msg to it.
#
# Arguments:
#  msg		the message to log.
#
# Results:
#  None.

proc procomp::log { msg } {
    variable logProc
    $logProc $msg
}

# procomp::logError --
#
#  Error logging procedure: calls the current error log procedure, passes
#  "error: $msg" to it.
#
# Arguments:
#  msg		the error message to log.
#
# Results:
#  None.

proc procomp::logError { msg } {
    variable errorProc
    $errorProc "error: $msg"
}

# procomp::fileCompile --
#
#  Compiles a file.
#
# Arguments:
#  path		the path to the file to compile.
#  outputFile	(optional) the output file name; if not specified, determine
#		the output file name from the control structures.
#		This argument is used when fileCompile is called from
#		dirCompile.
#
# Results:
#  Returns 1 on success, 0 on failure.

proc procomp::fileCompile { path {outputFile {}} } {
    variable outPath
    variable byteCodeExtension
    variable headerType
    variable headerValue
    variable forceWrite
    variable code_bomb

    set cmd ::compiler::compile

    # Get the preamble if any

    if {[catch {
	switch -- $headerType {
	    none {
	    }

	    auto {
		lappend cmd -preamble [getAutoHeader $path]
	    }

	    tag {
		lappend cmd -preamble [getTagHeader $path]
	    }

	    default {
		lappend cmd -preamble $headerValue
	    }
	}
    } err] == 1} {
	logError "compilation of \"$path\" failed: $err"
	return 0
    }

    set outputFile [generateOutFileName $path $outputFile]

    # Timebomb the result if running on a trial license.
    if {$code_bomb != {}} {
	set newpath [fileutil::tempfile tclc]

	set   fh [open $newpath w]
	puts $fh $code_bomb
	set orig [open $path r]
	fcopy $orig $fh
	close $orig
	close $fh

	set inputFile $newpath
    } else {
	set inputFile $path
    }

    lappend cmd $inputFile $outputFile

    # and finally run the compile
    if {[catch {
	if {$forceWrite == 1} {
	    file delete -force $outputFile
	}
	uplevel #0 $cmd
    } err] == 1} {
	logError "compilation of \"$path\" failed: $err"
	return 0
    }

    log "compiled: $path to $outputFile"

    if {$code_bomb != {}} {
	file delete $newpath
    }
    return 1
}

# procomp::generateOutFileName --
#
#  Generate an output file name from the input file name and the given output
#  file name. The generated path may be more complete than the one passed in.
#
# Arguments:
#  path		the path to the file to compile.
#  outputFile	(optional) the output file name; if not specified, determine
#		the output file name from the control structures.
#
# Results:
#  Returns the generated path, which may be the same as the value of
#  $outputFile

proc procomp::generateOutFileName { path {outputFile {}} } {
    variable outPath
    variable byteCodeExtension

    set tbcName [file rootname [file tail $path]]$byteCodeExtension

    if {[string compare $outputFile {}] == 0} {
	# if outPath is specified, construct the output file name from it.
	# Otherwise, the output file name is the input file name, with 
	# the .tbc extension.

	if {[info exists outPath] == 1} {
	    if {[file isdirectory $outPath] == 1} {
		set tbcName [file join $outPath $tbcName]
	    } else {
		set tbcName $outPath
	    }
	} else {
	    set tbcName [file join [file dir $path] $tbcName]
	}
    } else {
	# if the given output file is a directory, get the input file name,
	# tag the .tbc extension, and append it to the directory path.
	# If it is a file, or we can't tell, return it as is

	if {[file isdirectory $outputFile] == 1} {
	    set tbcName [file join $outputFile $tbcName]
	} else {
	    set tbcName $outputFile
	}
    }

    return $tbcName
}

# procomp::getAutoHeader --
#
#  Parses a script, extract the 'auto' header from it: all lines from the
#  beginning up to the first non-comment or the first empty line. Here, a line
#  containing only whitespace is considered to be empty.
#
# Arguments:
#  path		the path to the script to parse.
#
# Results:
#  Returns the header; may throw on error.

proc procomp::getAutoHeader { path } {
    variable tagValue

    set istm [open $path r]
    set header {}
    set continuation 0

    while {[gets $istm line] >= 0} {
	if {$continuation == 0} {
	    if {([regexp {^[ ]*#} $line] == 0) \
		    || ([regexp {^[ ]*$} $line] == 1)} {
		break
	    }
	}

	# we need to check if this line is continued on the next one

	if {[regexp {\\$} $line] == 1} {
	    set continuation 1
	} else {
	    set continuation 0
	}

	append header $line "\n"
    }
    close $istm

    append header [format "# %s\n" $tagValue]

    return $header
}

# procomp::getTagHeader --
#
#  Parses a script, extract the 'tag' header from it: all lines from the
#  beginning up to the first occurrence of the Tcl Dev Kit compiler include
#  tag. It is an error to parse a script that is missing the tag.
#
# Arguments:
#  path		the path to the script to parse.
#
# Results:
#  Returns the header; may throw on error.

proc procomp::getTagHeader { path } {
    variable tagPattern
    variable tagValue
    variable tagError

    set istm [open $path r]
    set header {}
    set didSeeTag 0

    while {[gets $istm line] >= 0} {
	if {[regexp $tagPattern $line] == 1} {
	    set didSeeTag 1
	    break
	}

	append header $line "\n"
    }
    close $istm

    if {$didSeeTag == 0} {
	if {$tagError == 0} {
	    return {}
	}
	error "missing header include tag"
    }

    append header [format "# %s\n" $tagValue]

    return $header
}

#
# LoadConfig --
#
#	Loads and processes a configuration file.
#
# Arguments:
#	infile	The path to the file.
#
# Results:
#	None.

proc ::procomp::LoadConfig {infile cfgfilesvar} {
    upvar 1 $cfgfilesvar cfgfiles

    # Prevent infinite recursive inclusion of ocnfiguration files.

    if {[info exists cfgfiles($infile)]} {
	return -code error \
		"circular inclusion of configuration file $infile"
    }
    set cfgfiles($infile) .

    # Error messages for saving and loading a configuration.

    set mtitle  "Error while loading configuration file."
    set fmtbase "File format not recognized.\n\nThe chosen file does not contain TclDevKit Project information."
    set fmttool "The chosen TclDevKit Project file does not contain information for $::tcldevkit::appframe::appName, but"
    set fmtkey  "Unable to handle the following keys found in the TclDevKit Project file for"
    set basemsg "Could not load file"

    # Check the chosen file for format conformance.

    foreach {pro tool} [::tcldevkit::config::Peek/2.0 $infile] { break }
    if {!$pro} {
	# Assume that the file contains a list of options and
	# arguments, with at least one word per line. We use the
	# 'csv' module to allow quoting, space is the separator
	# character.

	set options [list]
	set in [open $infile r]
	while {![eof $in]} {
	    if {[gets $in line] < 0} {continue}
	    if {$line == {}} {continue}
	    set line [csv::split $line { }]
	    foreach item $line {lappend options $item}
	}
	close $in
	return $options
    }

    # Check that the application understands the information in the
    # file. To this end we ask the master widget for a list of
    # application names it supports. If this results in an error we
    # assume that only files specifically for this application are
    # understood.

    if {[lsearch -exact [config::tools] $tool] < 0} {
	# Is a project file, but not for this tool.

	return -code error "$basemsg ${infile}.\n\n$fmttool $tool"
    }

    # The file is tentatively identified as project file for this
    # tool, so read the information in it. If more than one tool is
    # supported by the application we ask its master widget for the
    # list of keys acceptable for the found tool.

    set allowed_keys [config::keys $tool]

    if {[catch {
	set cfg [::tcldevkit::config::Read/2.0 $infile $allowed_keys]
    } msg]} {
	return -code error "$basemsg ${infile}.\n\n$fmtkey ${tool}:\n\n$msg"
    }

    return [config::ConvertToOptions $cfg $tool]
}


proc procomp::bomb {} {
    variable code_bomb
    global env

    set expiry [compiler::tdk_license expiration-date]
    if {$expiry eq ""} {
	return
    }

    foreach {d m y} [split $expiry -] { break }
    set expiry ${y}-${m}-${d} ; # ISO form.
    set seconds [clock scan   $expiry]
    set expiry  [clock format $seconds]

    set user [compiler::tdk_license user-name]
    set mail [compiler::tdk_license user-email]
    if {$mail ne ""} {
	append user " <$mail>"
    }

    set map [list @seconds@ $seconds @user@ $user]
    set code_bomb [string map $map {

	if {[clock seconds] > @seconds@} {
	    set    msg ""
	    append msg "| This application has been generated with an evaluation license of the" \n
	    append msg "| Tcl Dev Kit 'tclcompiler' utility.  The evaluation license has expired" \n
	    append msg "| now.  Please contact the author of this application for a non-expiring" \n
	    append msg "| version of the program: @user@." \n

	    if {![catch {package require Tk}]} {
		# We can use Tk, so we do.

		tk_messageBox \
			-icon    error \
			-title   "Expired trial license" \
			-type    ok \
			-message $msg
	    } else {
		# Falling back to writing the message to stderr.
		# This should always work.

		puts -nonewline stderr $msg
	    }
	    exit
	    return
	}
    }] ; # {}

    # We don't do more with the bomb here, it will later be integrated
    # into each compiled file.
    return
}
 
# Initialize the timebomb, if any.
procomp::bomb
