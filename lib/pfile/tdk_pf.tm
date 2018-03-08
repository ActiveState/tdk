# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package tdk_pf 0.1
# Meta platform    tcl
# Meta require     snit
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# Generic reading and writing files in {Tcl Dev Kit Project File} format.
# (c) 2003-2006 ActiveState Software Inc.

# ----------------------------------------------------
# Prerequisites

package require snit

# ----------------------------------------------------
# Interface & Implementation

snit::type tdk_pf {
    # ------------------------------------------------
    # Interface

    constructor {tool toolversion {keydefinition {}}} {}
    destructor  {}

    # Add the definition of a single named key. Associated with the
    # name is the number of arguments it takes.

    #method declare {key numargs} {}

    # Declare an external checker to use when reading a file. Default
    # is no additional checking.

    #method readchecker: {object} {}

    # match - Are the contents of file 'fname' a valid TDK Project
    #         file ?
    #
    # Legal results:
    # % -1 <=> Not a TDK project file at all.
    # %  0 <=> TDK project file, but not for this tool
    # %  1 <=> TDK project file for this tool.

    #method match {fname} {}

    # Return name of the tool handled by the object.

    #method tool {} {}

    # Return list of the keys defined for the tool

    #method keys {} {}

    # Check that the list of keys and values conforms to the key
    # definition for the object. Result is boolean value. True if the
    # data is conformant, else false. Values are lists containing the
    # arguments for the key.
    #
    # Note: Two additional keys are accepted:
    # '#' - Any number of arguments, comment.
    # {}  - No arguments, generates empty line

    #method check {data} {}

    # Like 'check' above, but for a single key and its arguments. This
    # is used by buffer objects to perform their checking.

    #method checkKey {key arguments {noextended 0}} {}

    # Write the data to the file. Successful if and only if the data
    # conforms to the key definition for the object. See the note
    # above check' about additionally accepted keys.

    #method write {data fname} {}

    # Reads the file and returns a list of the keys and and values
    # found inside. All values are lists containing the argument for
    # their key. Comments and empty lines (see above)
    # are ignored and not listed in the output.

    #method read {fname} {}

    # Allow for incremental generation of output. Returns a named
    # buffer associated with this object. See below for the definition
    # of the type.

    #method buffer {name} {}


    # ------------------------------------------------
    # ------------------------------------------------
    # ------------------------------------------------
    # Implementation

    # Map: key name to number of arguments it takes.
    #      this is a list of allowed argument numbers
    variable argnum

    # Map: key name to filler strings for nice vertical
    # alignment. Computed only when required, i.e. upon the first
    # write request.
    variable offsets

    # Name of the tool and its version relevant to the file.
    variable tool
    variable toolversion

    # Object for additional checks during reading
    variable rc {}

    constructor {tool_ toolversion_ {keydefinition {}}} {

	if {[llength $keydefinition] % 2} {
	    return -code error "Syntax error in key definition, invalid length"
	}

	array set argnum  {}
	array set offsets {}

	set tool        $tool_
	set toolversion $toolversion_
	set rc $self

	foreach {k n} $keydefinition {
	    $self declare $k $n
	}
	return
    }
    destructor  {
    }

    # Add the definition of a single named key. Associated with the
    # name is the number of arguments it takes.

    method declare {key numargs} {
	if 0 {
	    if {[info exists argnum($key)]} {
		return -code error \
			"Syntax error in key definition,\
			duplicate definition of key \"$key\""
	    }
	}
	if {
	    ![string is integer -strict $numargs] ||
	    ($numargs < 0)
	} {
	    return -code error \
		    "Syntax error in key definition,\
		    illegal number of arguments for key\
		    \"$key\": $numargs"
	}
	if {[info exists argnum($key)]} {
	    lappend argnum($key) $numargs
	} else {
	    set argnum($key) $numargs
	}
	return
    }

    # Declare an external checker to use when reading a file. Default
    # is the object itself.

    method readchecker: {object} {
	# When removing the external checker insert ourselves again.
	if {$object == {}} {set object $self}
	set rc $object
	return
    }

    # match - Are the contents of file 'fname' a valid TDK Project
    #         file ?
    #
    # Legal results:
    # % -1 <=> Not a TDK project file at all.
    # %  0 <=> TDK project file, but not for this tool
    # %  1 <=> TDK project file for this tool.

    method match {fname} {
	set chan [open $fname r]

	set format   ""
	set fversion ""
	set ftool    ""
	foreach _ _ {
	    # Three-line standard header ...
	    if {![$self Getline $chan format]}    { break }
	    if {![$self Getline $chan fversion]}  { break }
	    if {![$self Getline $chan ftool]}     { break }
	}
	close $chan

	# Check the retrieved information for conformance to the
	# "TclDevKit Project File Format Specification, 2."0 and
	# extract the tool information.

	if {
	    [string equal $format   "format  \{TclDevKit Project File\}"] &&
	    [string equal $fversion "fmtver  2.0"] &&
	    [regexp "^fmttool" $ftool]
	} {
	    regexp "^fmttool *\{(\[^\}\]*)\} *(.*)\$" \
		    $ftool -> tool_ toolversion_

	    if {[string equal $tool $tool_]} {
		# Is TPF, and matches our tool
		return 1
	    } else {
		# Is TPF, but not for our tool
		return 0
	    }
	} else {
	    # Not a TP file.
	    return -1
	}
	return -code error "panic, interpreter error"
    }

    # Return name of the tool handled by the object.

    method tool {} {
	return $tool
    }

    # Return list of the keys defined for the tool

    method keys {} {
	return [array names argnum]
    }

    # Check that the list of keys and values conforms to the key
    # definition for the object. Result is boolean value. True if the
    # data is conformant, else false. Values are lists containing the
    # arguments for the key.
    #
    # Note: Two additional keys are accepted:
    # '#' - Any number of arguments, comment.
    # {}  - No arguments, generates empty line

    method check {data} {
	if {[llength $data] % 2 == 1} {
	    return -code error "Not a list with even number of elements"
	}
	foreach {k v} $data {
	    $self checkKey $k $v
	}
	return
    }

    # Like 'check' above, but for a single key and its arguments. This
    # is used by buffer objects to perform their checking.

    method checkKey {key arguments {noextended 0}} {
	if {!$noextended} {
	    if {$key == {}}             {continue}
	    if {[string equal $key \#]} {continue}
	}
	if {![info exists argnum($key)]} {
	    return -code error "Illegal key \"$key\""
	}
	if {[lsearch -exact $argnum($key) [llength $arguments]] < 0} {
	    return -code error "Wrong#args for key \"$key\""
	}
	return
    }

    # Write the data to the file. Successful if and only if the data
    # conforms to the key definition for the object. See the note
    # above check' about additionally accepted keys.

    method write {data fname} {
	$self check $data
	$self writeUnchecked $data $fname
	return
    }

    # Reads the file and returns a list of the keys and and values
    # found inside. All values are lists containing the argument for
    # their key. Comments and empty lines (see above)
    # are ignored and not listed in the output.

    variable errors
    variable data
    method read {fname} {
	if {![file exists $fname]} {
	    return -code error "Unable to read file \"$fname\""
	}

	set ip [$self CleanIP]

	foreach k [array names argnum] {
	    #            Slave [$k x...] ==> Master [GetKey $k $n x...]
	    interp alias $ip $k {} $self GetKey $k $argnum($k)
	}
	interp alias $ip format  {} $self Null
	interp alias $ip fmtver  {} $self Null
	interp alias $ip fmttool {} $self Null
	interp alias $ip unknown {} $self Illegal

	# Initialize the reader state, then read and evaluate the
	# configuration script.

	set errors {}
	set data   {}

	# Initialization of validator.
	$rc startReading

	$ip eval [read [set fh [open $fname r]]][close $fh]
	interp delete $ip

	# finalization of validator.
	$rc doneReading

	# Now check the result and return it, or throw an error.

	if {[llength $errors] > 0} {
	    return -code error [join $errors \n]
	}

	return $data
    }

    # Allow for incremental generation of output. Returns a named
    # buffer associated with this object. See below for the definition
    # of the type.

    method buffer {name} {
	# Create new buffer and connect it with ourselves to give it
	# the ability to check its contents.

	set buf [tdk_tf::buffer $name]
	$buf def: $self
	return $buf
    }

    # ------------------------------------------------
    # ------------------------------------------------
    # ------------------------------------------------
    # Semi-public, for use by 'buffer' objects.

    method writeUnchecked {data fname} {
	set           chan [open $fname w]
	$self Header $chan
	$self Dump   $chan $data
	$self Footer $chan
	close        $chan
	return
    }

    # ------------------------------------------------
    # ------------------------------------------------
    # ------------------------------------------------
    # Internals

    # ------------------------------------------------
    # match

    method Getline {chan var} {
	upvar $var line
	return [expr {([gets $chan line] >= 0) && ![eof $chan]}]
    }

    # ------------------------------------------------
    # read

    method CleanIP {} {
	set ip [interp create]
	foreach cmd [$ip eval {info commands}] {
	    if {[string equal rename $cmd]} continue
	    $ip eval [list rename $cmd {}]
	}
	$ip eval {rename rename {}}
	return $ip
    }

    method GetKey {key nlist args} {
	if {[lsearch -exact $nlist [llength $args]] < 0} {
	    lappend errors "Wrong#args for key \"$key\""
	    return
	}
	# Route through validator.
	$rc checkKeyForRead $key $args errors
	lappend data $key $args
	return
    }

    method Illegal {key args} {
	lappend errors "Illegal key \"$key\""
	return
    }

    method Null {args} {return}

    # ------------------------------------------------
    # Nop methods for validation

    method startReading    {}                   {return}
    method doneReading     {}                   {return}
    method checkKeyForRead {key arguments evar} {return}


    # ------------------------------------------------
    # write(Unchecked)

    method Header {chan} {
	global tcl_platform

	puts  $chan "format  \{TclDevKit Project File\}"
	puts  $chan "fmtver  2.0"
	puts  $chan "fmttool [list $tool $toolversion]"

	# Place some meta information in comments
	# (Note: Saved configuration is a tcl script)
	# Semi standard.

	puts  $chan ""
	puts  $chan "##  Saved at : [clock format [clock seconds]]"
	puts  $chan "##  By       : $tcl_platform(user)@[info hostname]"
	puts  $chan ""
	puts  $chan "########"
	puts  $chan "#####"
	puts  $chan "###"
	puts  $chan "##"
	puts  $chan "#"
	puts  $chan ""
	return
    }

    method Dump {chan data} {
	if {[array size offsets] == 0} {
	    $self ComputeOff
	}
	foreach {k v} $data {
	    if {$k == {}} {
		puts $chan ""
	    } elseif {[string equal $k \#]} {
		puts $chan "# [join $v "\n# "]"
	    } elseif {$argnum($k) == 0} {
		puts $chan $k
	    } else {
		# no [list] around v, it is already one
		puts $chan "$k$offsets($k) $v"
	    }
	}
	return
    }

    method Footer {chan} {
	puts  $chan ""
	puts  $chan "#"
	puts  $chan "##"
	puts  $chan "###"
	puts  $chan "#####"
	puts  $chan "########"
	return
    }

    method ComputeOff {} {
	# Iteration I. Determine the length of the longest key
	set ml 0
	foreach k [array names argnum] {
	    set len [string length $k]
	    if {$len > $ml} {set ml $len}
	}

	# Iteration II. Compute the fillers.
	foreach k [array names argnum] {
	    set offsets($k) [string repeat " " [expr {$ml - [string length $k]}]]
	}
	return
    }
}

# ----------------------------------------------------
# Buffer type for the incremental generation of output in TDK/PF
# format.

snit::type tdk_pf::buffer {
    # ------------------------------------------------
    # Interface

    constructor {} {}
    destructor  {}

    # Connect the bufer to the TDK object responsible for item
    # checking.

    method def: {tdk} {}

    # Add various elements to the buffer / file

    method +key       {key arguments} {}
    method +comment   {comment} {}
    method +separator {} {}

    # Clear the buffers contents.

    method clear {} {}

    # Write the buffer to a file.

    method write {fname} {}

    # ------------------------------------------------
    # ------------------------------------------------
    # ------------------------------------------------
    # Implementation

    variable tdk
    variable buffer {}

    constructor {} {}
    destructor  {}

    # Connect the bufer to the TDK object responsible for item
    # checking.

    method def: {tdk_} {
	set tdk $tdk_
	return
    }

    # Add various elements to the buffer

    method +key       {key arguments} {
	# We stop comment and separators here, we want only keys.
	$tdk checkKey  $key $arguments 1
	lappend buffer $key $arguments
	return
    }

    method +comment {comment} {
	lappend buffer \# [list $comment]
	return
    }

    method +separator {} {
	lappend buffer {} {}
	return
    }

    # Clear the buffers contents.

    method clear {} {
	set buffer {}
	return
    }

    # Write the buffer to a file.

    method write {fname} {
	$tdk writeUnchecked $buffer $fname
	return
    }
}

# ----------------------------------------------------
# Ready to go ...
return
