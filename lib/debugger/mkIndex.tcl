# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# mkIndex.tcl --
#
#	This script generates a pkgIndex.tcl file for an installed extension.
#
# Copyright (c) 1998-2000 Ajuba Solutions

#
# Notes:
#
# If you redefine $(libdir) using the configure switch --libdir=, then
# this script will probably fail for you.
#
# UNIX:
#      exec_prefix
#           |
#           |
#           |
#          lib
#          / \
#         /   \
#        /     \
#   PACKAGE   (.so files)
#       |
#       |
#       |
#  pkgIndex.tcl
#
# WIN:
#      exec_prefix
#          / \
#         /   \
#        /     \
#      bin     lib
#       |        \
#       |         \
#       |          \
# (.dll files)   PACKAGE
#                    |
#                    |
#                    |
#                pkgIndex.tcl
       
# The pkg_mkIndex routines from Tcl 8.2 and later support stub-enabled
# extensions.  Notify the user if this is not a valid tcl shell.
# Exit with a status of 0 so that the make-install process does not stop.

if {[catch {package require Tcl 8.2} msg]} {
    puts stderr "**WARNING**"
    puts stderr $msg
    puts stderr "Could not build pkgIndex.tcl file.  You must create one by hand"
    exit 0
}

# The name of the library(s) should be passed in as arguments.

set libraryList $argv

# Nativepath --
#
#	Convert a Cygnus style path to a native path
#
# Arguments:
#	pathName	Path to convert
#
# Results:
#	The result is the native name of the input pathName.
#	On Windows, this is z:/foo/bar, on Unix the input pathName is
#	returned.

proc Nativepath {pathName} {
    global tcl_platform

    if {![string match $tcl_platform(platform) unix]} {
	regsub -nocase {^//([a-z])/(.*)$} $pathName {\1:/\2} pathName
	regsub -nocase {^/cygdrive/([a-z])/(.*)$} $pathName {\1:/\2} pathName
    }
    return $pathName
}

set prefix "/home/redman/tcl8.2"
set exec_prefix "${prefix}"

set exec_prefix [Nativepath $exec_prefix] 

set libdir ${exec_prefix}/lib
set package debugger
set version 1.4

cd $libdir
puts "Making pkgIndex.tcl in [file join [pwd] $package]"

if {$tcl_platform(platform) == "unix"} {
    if {[llength $libraryList] > 0} {
	set libraryPathList {}
	foreach lib $libraryList {
	    lappend libraryPathList [file join .. $lib]
	}
	puts "eval pkg_mkIndex $package$version $libraryPathList *.tcl"
	eval pkg_mkIndex $package$version $libraryPathList *.tcl
    }
} else {
    if {[llength $libraryList] > 0} {
	set libraryPathList {}
	foreach lib $libraryList {
	    lappend libraryPathList [file join .. .. bin $lib]
	}
	puts "eval pkg_mkIndex $package$version $libraryPathList *.tcl"
	eval pkg_mkIndex $package$version $libraryPathList *.tcl
    }
}
