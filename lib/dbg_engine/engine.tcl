# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# engine.tcl --
#
#	Umbrella object. Contains all the objects which manage the
#	backend for a single connection to a debugged application.
#	I.e. actual communication and adjacent databases. This object
#	does _not_ contain any UI components. It is able to talk to
#	some such components through the use of callbacks.
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
# Copyright (c) 2004-2006 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: debugger.tcl.in,v 1.25 2001/02/09 07:52:48 welch Exp $

# ### ### ### ######### ######### #########
## Requisites

package require snit
package require dbgtalk ;# Talking to the debuggee
package require breakdb ;# Database of breakpoints
package require blk     ;# Management of code blocks
package require filedb  ;# MRU list of used files.

# ### ### ### ######### ######### #########
## Implementation

snit::type engine {

    # ### ### ### ######### ######### #########
    ## Initialization

    delegate option -warninvalidbp     to dbg ; # [preference warnInvalidBp]
    delegate option -instrumentdynamic to dbg ; # [preference instrumentDynamic]
    delegate option -doinstrument      to dbg ; # [preference doInstrument]
    delegate option -dontinstrument    to dbg ; # [preference dontInstrument]
    delegate option -autoload          to dbg ; # [preference autoLoad]
    delegate option -erroraction       to dbg ; # [preference errorAction]
    delegate option -exit-on-eof       to dbg ; # How nub should handle frontend eof. Bug 75622.

    option -tempdir {}                        ; # Path to directory for scratch files
    option -fail-applaunch 0                  ; # Default is to not fail when copying not possible (Komodo).

    delegate method initInstrument to dbg

    constructor {args} {
	# Create the components.

	set dbg [dbgtalk ${selfns}::dbg]
	set brk [breakdb ${selfns}::brk]
	set blk [blkdb   ${selfns}::blk]
	set fdb [filedb  ${selfns}::fdb]

	# Link them together.

	$dbg break: $brk
	$dbg blk:   $blk
	$brk blk:   $blk
	$fdb blk:   $blk

	$self configurelist $args
	::dbgtalk::initialize
	return
    }
    destructor {
	# Delete the components.

	catch {rename $dbg {}}
	catch {rename $brk {}}
	catch {rename $blk {}}
	catch {rename $fdb {}}
	return
    }

    # ### ### ### ######### ######### #########
    ## Components & component accessors

    variable dbg {}
    method   dbg {} {return $dbg}

    variable brk {}
    method   brk {} {return $brk}

    variable blk {}
    method   blk {} {return $blk}

    variable fdb {}
    method   fdb {} {return $fdb}

    # ### ### ### ######### ######### #########

    onconfigure -tempdir {value} {
	log::log debug "Scratch directory -tempdir = ($value)"

	::dbgtalk::setScratchDir $value
	set options(-tempdir)    $value
	return
    }

    onconfigure -fail-applaunch {value} {
	log::log debug "Fail AL copy = ($value)"

	::dbgtalk::setFailApp        $value
	set options(-fail-applaunch) $value
	return
    }

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

package provide engine 0.1
