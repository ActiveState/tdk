# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pcx.tcl --
#
#	This file defines the API for use by PCX files.
#
# Copyright (c) 2003-2009 ActiveState Software Inc.
#


# 
# SCCS: %Z% %M% %I% %E% %U%

# ### ######### ###########################
## Requisites

package require projectInfo  ; # AS/TclPro | Global shared project information
package require configure    ; # AS/TclPro | Command line configuration

# Break circularity pcx <-> analyzer
#package require analyzer     ; # AS/TclPro | Analyzer status
#

package require log          ; # Tcllib    | Logging and Tracing
package require struct::list ; # Tcllib    | List operations.
package require struct::set  ; # Tcllib    | Set operations.
package require pref::devkit ; # TDK preferences

#
# Notes:
#
# (1) The loading of core checker rules (Tcl, Tk) happens in the
# procedure -> "configure::packageSetup", defined by the file
# 'configure.tcl'.
#
# (2) The activation then happens in the procedure 'uproc::clear'
# defined by the file 'userproc.tcl'.
#

# ### ######### ###########################
## Implementation

namespace eval ::pcx {}

# ### ######### ###########################
## API/checker. Extend list of paths to search for PCX files.

proc ::pcx::search {dirpath} {
    variable dirlist

    LOG {EXTEND BY $dirpath}

    if {![file exists      $dirpath]} return
    if {![file isdirectory $dirpath]} return
    if {![file readable    $dirpath]} return

    lappend dirlist [file normalize $dirpath]
    return
}

# ### ######### ###########################
## PCX Debugging helpers

proc ::pcx::debug {} {
    variable loaddebug 1
    return
}

proc ::pcx::DEBUG {script} {
    variable loaddebug
    if {!$loaddebug} return
    uplevel 1 $script
    return
}

proc ::pcx::LOG {string} {
    variable loaddebug
    if {!$loaddebug} return
    set prefix {PCX DEBUG }
    puts stderr ${prefix}[join \
			      [split \
				   [uplevel 1 \
					[list ::subst $string]] \
				   \n] \
			      \n$prefix]
    return
}

# ### ######### ###########################
## API/pcx/checker. Load a PCX file.

proc ::pcx::lastloaded {} {
    variable lastloaded
    return  $lastloaded
}

proc ::pcx::load {pkg} {
    variable pcx
    variable loaded
    # parray loaded

    if {[info exists loaded(t,$pkg)]} {
	variable lastloaded $pkg
	return
    }

    ResolvePCX
    if {![info exists pcx($pkg)]} {
	# Note: Keep the pattern used by 'configure::packageSetup' in
	# sync with the message generated here.
	return -code error \
		"No checker for package \"$pkg\" available."
    }

    #::log::log debug pcx/load/$pkg

    set file $pcx($pkg)
    LoadPkgFile $file

    if {[lastloaded] ne $pkg} {
	return -code error \
	    "Content mismatch, file \"$file\" registered package \"[lastloaded]\" instead"
    }
    return
}

proc ::pcx::LoadPkgFile {file} {
    #::log::log debug "Loading PCX definitions from \"$file\""

    LOG {LOADING $file}

    if {[catch {
	uplevel \#0 [list source $file]
    } err]} {
	LOG {LOAD ERROR [join [split $::errorInfo \n] "\nLOAD ERROR "]}

	#::log::log error "Error loading extension $file:\n\$err\n$::errorInfo"

	LOG {LOADING FAILED}
	return -code error \
		"Error loading extension $file:\n\
		$err\n$::errorInfo"
    }

    # Loading ok.
    LOG {LOADING OK}
    LOG {LOADED}

    # The name(s) of the loaded package(s) are now recorded
    # in the array 'loaded'. This prevents the system from
    # loading the file again (see ::pcx::load).
    return 1
}

# ### ######### ###########################
## API/checker. Command line calls for user declaration of which
## package versions to use when the package is actually required.
#
## NOTE: The package name is the user visible name, not the name of
## the checker package for the package. This means that it has to be
## translated later on, when the checker queries this information.

proc ::pcx::use {pkg ver} {
    variable useVersions
    set      useVersions($pkg) $ver

    #::log::log debug pcx/use/$pkg/$ver
    return
}

proc ::pcx::useRequest {pkg} {
    variable useVersions
    if {![info exists useVersions($pkg)]} {return {}}
    return  $useVersions($pkg)
    return
}

# ### ######### ###########################
## API/checker. Get checker/scanner/variable/expr-op definitions for a
## particular version of a loaded package. These are added to the
## specified command, variable, and operator databases.

proc ::pcx::require {chkPkg ver cdb vdb} {
    variable checker  ; unset -nocomplain checker  ; array set checker {}
    variable scanner  ; unset -nocomplain scanner  ; array set scanner {}
    variable vars     ; unset -nocomplain vars     ; set vars          {}
    variable mathops  ; unset -nocomplain mathops  ; set mathops       {}
    variable mathvops ; unset -nocomplain mathvops ; set mathvops      {}
    variable perfile  ; unset -nocomplain perfile  ; set perfile       {}
    variable nspattern; unset -nocomplain nspattern; set nspattern     {}
    variable orders   ; unset -nocomplain orders   ; array set orders  {}
    variable chkVersions

    #::log::log debug pcx/require/$chkPkg/$ver/[info commands ::${chkPkg}::init]/

    if {[llength [info commands ::${chkPkg}::init]]} {
	# Package has special initialization code.

	::${chkPkg}::init $ver
    } else {
	# No special package init present, therefore perform a
	# standard initialization sequence.

	init $chkPkg $ver
    }

    #::log::log debug pcx/require/$chkPkg/$ver/$vdb/decl/$vars/

    foreach v [lsort -uniq $vars] {
	## TODO Define var database.
	$vdb declare $v
    }

    foreach n [array names orders] {
	timeline::def $n $orders($n)
    }

    #puts EE/$mathops
    ::analyzer::addOps  $mathops
    ::analyzer::addVOps $mathvops
    #puts Per-file checkers
    ::analyzer::addPerfile $perfile
    #puts name-style patterns
    ::analyzer::addNameStylePatterns $nspattern

    set pkg [packageOf $chkPkg]

    foreach {name cmd} [array get checker] {
	#::log::log debug "pcx::use _________________\n ($name) ($cmd)"

	## We add them to the uproc database, and use a special
	## wrapper around the command to match the expected
	## call interfaces.

	# Basic logic from 'scanCmdExists'. Use a specific scanner
	# command if present, or the checker command if so indicated,
	# or do not scan at all.

	if {[info exists scanner($name)]} {
	    set scancmd $scanner($name)
	} elseif {[info exists scanner(${name}-TPC-SCAN)]} {
	    set scancmd $cmd
	} else {
	    set scancmd {}
	}

	# Only add fully-qualified names, required for correct search
	# later.

	set xname $name
	if {![regexp {^::} $name]} {set xname ::$xname}

	### ### #
	##
	## TODO Determine the need for re-scanning the current file !!
	##
	### ### #

	set       pInfo [cdb newBuiltinInfo $pkg $xname $cmd $scancmd]
	$cdb add $pInfo 1

	#::log::log debug "______________________________________________"
	unset -nocomplain checkers($name)
	unset -nocomplain scanner($name)
    }

    set f [::analyzer::getFile]
    if {$f != {}} {
	set chkVersions($f,$chkPkg) $ver
    }
    set chkVersions($chkPkg) $ver
    return
}

# ### ######### ###########################
## API/pcx. Register the checker package as loaded.

proc ::pcx::register {name {label {}}} {
    variable loaded
    variable current
    variable currentname
    variable currentpkg

    set name [string trim $name :]
    if {$label == {}} {set label $name}
    set      loaded($name)    $label
    set      loaded(t,$label) $name ; # t <=> T'rue package name

    LOG {        Registered '$name' (for package '$label')}

    # We remember the name (= namespace of checker package) for use by
    # all following pcx declaration commands.

    set current   ::$name
    set currentname $name
    set currentpkg  $label

    # Initialize the namespace for the checker package
    # - We provide the common checker commands.

    namespace eval ::$name {
	namespace import -force ::analyzer::*
    }

    return
}

proc ::pcx::complete {} {
    # Reset
    variable currentname
    variable currentpkg
    variable current
    variable lastloaded $currentpkg
    set current     {}
    set currentname {}
    set currentpkg  {}
    return
}

# ### ######### ###########################
## API/pcx. Register version dependencies

proc ::pcx::tcldep {version needs pkg {tclver {}}} {
    if {$needs ne "needs"} {
	return -code error "[info level 0] syntax error: expected \"needs\", got \"$needs\""
    }
    if {$pkg ne "tcl"} {
	return -code error "Unknown dependency \"$pkg\""
    }

    variable verTable
    variable currentname

    if {$currentname == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }
    if {$tclver == {}} {
	set tclver $::projectInfo::baseTclVers
    }
    set verTable($currentname,$version) $tclver
    return
}

# ### ######### ###########################
## API/pcx. Declare package specific error message

proc ::pcx::message {code text types} {
    variable current
    variable currentname
    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }

    upvar #0 ${current}::messages m

    set fullcode ${currentname}::$code

    if {[info exists m($fullcode)]} {
	return -code error "[info level 0]: Duplicate definition of message code."
    }

    set m($fullcode) [linsert $types 0 $text]
    return
}

# ### ######### ###########################
## API/pcx. Declare package specific command sequencing.

proc ::pcx::order-by-pairs {version pairs} {

    # This is the low-level interface to the ordering system, directly
    # define the pairs of commands which are legal for us.

    variable current
    variable currentname

    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }

    # Extract the legal action names from the pairs. We ignore only
    # the empty string, as it is special to us, internally, and not
    # really a user action.

    # Further collect the allowed predecessors for each action. The
    # latter for error messages, to tell the user what commands had
    # been expected.

    array set pre {}
    set actions {}
    foreach pair $pairs {
	lassign $pair a b
	lappend actions $b
	lappend pre($b) $a
	if {$a eq ""} continue
	lappend actions $a
    }
    set actions [lsort -unique $actions]
    foreach k [array names pre] {
	set pre($k) [lsort -unique $pre($k)]
    }

    # Pull the relevant data structures into scope and save the
    # definition.

    upvar #0 ${current}::order$version order
    set order [list $actions $pairs [array get pre]]
    return
}

proc ::pcx::order {version args} {

    # Highlevel interface to ordering. The legal command orders are
    # specified through one or more context-free grammars. From which
    # we can deduce the legal command pairs, and feed them into the
    # low-level interface.

    # Each word in args is a separate grammar, the pairs they generate
    # are however merged into one set.

    set pairs {}
    foreach grammar $args {
	lappend pairs {*}[PairsOfGrammar $grammar]
    }

    order-by-pairs $version $pairs
    return
}

proc ::pcx::PairsOfGrammar {rules} {
    # grammar is in rules = dict (lhs -> rhs), rhs = list(symbol)

    # Convert grammar dictionary with duplicate keys into compact
    # form, collecting the rules for each symbol in a list. Computes
    # the total set of symbols as well, and checks that the start
    # symbol is present as non-terminal.

    set hasstart 0
    foreach {lhs rhs} $rules {
	lappend gr($lhs) $rhs
	lappend all {*}$rhs

	if {$lhs ne ""} continue
	set hasstart 1
    }

    if {!$hasstart} {
	return -code error "Start symbol (empty string) missing on left-hand-side of grammar"
    }

    # gr = array (symbol -> list (rules))

    # Compute the various sets of symbols, i.e. terminals,
    # non-terminals, and their union.

    set all [lsort -unique $all]
    set nt  [array names gr]
    set ts  [struct::set difference $all $nt]

    # all = set of all symbols
    # ts  = set of terminal symbols
    # nt  = set of non-terminal symbols

    #ShowGrammar

    # Convert the grammar into Greibach-Normal-Form. Each rule has at
    # most 2 symbols on the right-hand-side. Done by inserting helper
    # non-terminals (-> Prefix $$$ is reserved). This makes the first
    # follow computation a bit easier as we have a finite set of cases
    # and no need for iteration.

    set counter 0
    foreach lhs $nt {
	set newrhs {}
	foreach rhs $gr($lhs) {
	    while {[llength $rhs] > 2} {
		set nsy $$$[incr counter]
		set gr($nsy) [list [lrange $rhs end-1 end]] ; # Note: list(rule) for a symbol
		lappend all $nsy
		lappend nt $nsy
		set rhs [lrange $rhs 0 end-2]
		lappend rhs $nsy
	    }
	    lappend newrhs $rhs
	}
	set gr($lhs) $newrhs
    }

    #ShowGrammar

    # Compute nullability of symbols. Terminal symbols are not, and
    # symbols are if all their rules are empty or consist of nullable
    # symbols. This is later needed when computing first/follow as
    # nullability creates more propagation paths. Data flow iteration
    # here, re-computing nullability of all non-nullable non-terminal
    # until there are no more changes.

    array set null {}
    foreach sy $all { set null($sy) 0 }
    set null() 0

    set changed 1
    while {$changed} {
	set changed 0
	foreach lhs $nt {
	    if {$null($lhs)} continue
	    foreach rhs $gr($lhs) {
		set isnull 1
		foreach s $rhs {
		    if {!$null($s)} {
			set isnull 0
			break
		    }
		}
		if {$isnull} {
		    set changed 1
		    set null($lhs) 1
		}
	    }
	}
    }

    #parray null

    # Compute the first/follow sets for all symbols. The FOLLOW sets
    # for the terminals, plus the FIRST set of the start symbol
    # contain the pair information we are looking for. The greibach
    # normal form makes things easier as we are restricted to 0,1,2
    # symbols on the right hand sides, easy to switch over.

    array set first  {}
    array set follow {}

    # The basic first/follow sets. terminal first sets are the
    # terminal itself. Everything else starts empty.

    foreach w $nt {
	set first($w) {}
	set follow($w) {}
    }
    foreach w $ts {
	set first($w) [list $w]
	set follow($w) {}
    }

    #puts ________________________________________________________________
    #parray first
    #parray follow

    # Data flow iteration. Propagates first/follow information through
    # the symbols using the grammar rules as guide what to propagate
    # where. Until nothing changes anymore.

    set changed 1
    while {$changed} {
	set changed 0
	foreach lhs $nt {
	    foreach rhs $gr($lhs) {
		#puts "___ ($lhs) := ($rhs) _________________________"

		switch -exact -- [llength $rhs] {
		    0 {
			# no symbols.
			# first(lhs) += follow(lhs)
			SetPlus first($lhs) $follow($lhs) changed
		    }
		    1 {
			# one symbol.
			set w [lindex $rhs 0]
			# first (lhs) += first(symbol)
			# first (lhs) += follow(symbol) if nullable(symbol)
			# follow(symbol) += follow(lhs)

			SetPlus first($lhs) $first($w) changed
			if {$null($w)} {
			    SetPlus first($lhs) $follow($w) changed
			}
			SetPlus follow($w) $follow($lhs) changed
		    }
		    2 {
			# two symbols, a b
			lassign $rhs a b

			# follow(b) += follow(lhs)

			# follow(a) += first(b)
			# follow(a) += follow(b) if nullable(b)

			# first (lhs) += first(a)
			# first (lhs) += follow(a) if nullable(a)

			SetPlus follow($b) $follow($lhs) changed
			SetPlus follow($a) $first($b) changed
			if {$null($b)} {
			    SetPlus follow($a) $follow($b) changed
			}
			SetPlus first($lhs) $first($a) changed
			if {$null($a)} {
			    SetPlus first($lhs) $follow($a) changed
			}
		    }
		}
	    }
	}
    }

    #puts ________________________________________________________________
    #parray first
    #parray follow

    # Our pairs are the FOLLOW sets for the terminal symbols, and the
    # FIRST set of the start symbol.

    set pairs {}
    foreach s $first() {
	lappend pairs [list {} $s]
    }
    foreach t $ts {
	foreach f $follow($t) { lappend pairs [list $t $f] }
    }

    #puts PAIRS=\t[llength $pairs]\t$pairs

    return $pairs
}

proc pcx::ShowGrammar {} {
    upvar 1 gr gr all all ts ts nt nt
    puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    parray gr
    puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    puts A\t[lsort -dict $all]
    puts N\t[lsort -dict $nt]
    puts T\t[lsort -dict $ts]
    puts ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return
}

proc pcx::SetPlus {av b cv} {
    upvar 1 $av a $cv c

    #puts -nonewline "\t$av ($a) += ([join $b {) (}])"

    if {[struct::set empty $b] || [struct::set empty [struct::set difference $b $a]]} {
	#puts ...no
	return
    }
    #puts ...yes
    struct::set add a $b
    set c 1
    return
}


# ### ######### ###########################
## API/pcx. Declare variable exported by a specific version of the
## package we are checking.

## Right now we are simply filling some datastructures in the
## namespace of this checker package. The data structures are
## ready for interpretation by the 'pcx::init' command.

proc ::pcx::var {version vname} {
    variable current
    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }

    upvar #0 ${current}::vars$version v

    lappend v $vname
    set     v [lsort -uniq $v]
    return
}

# ### ######### ###########################
## API/pcx. Declare expr operator or function provided by a specific
## version of the package we are checking.

## Right now we are simply filling some datastructures in the
## namespace of this checker package. The data structures are
## ready for interpretation by the 'pcx::init' command.

proc ::pcx::mathop {version opname oparity} {
    variable current
    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }

    upvar #0 ${current}::mathop$version v

    #puts OP/$current/$version/$opname/$oparity

    lappend v $opname/$oparity
    set     v [lsort -unique $v]
    return
}

proc ::pcx::mathvop {version opname minarity maxarity} {
    variable current
    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }

    upvar #0 ${current}::mathvop$version v

    #puts OP/$current/$version/$opname/$oparity

    lappend v $opname/$minarity/$maxarity
    set     v [lsort -unique $v]
    return
}

# ### ######### ###########################
## API/pcx. Declare a per-file checker provided by a specific version
## of the package we are checking.

proc ::pcx::perfile {version checkercommandprefix} {
    variable current
    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }

    upvar #0 ${current}::perfile$version v

    #puts OP/$current/$version/$checkercommandprefix

    lappend v $checkercommandprefix
    set     v [lsort -unique $v]
    return
}

# ### ######### ###########################
## API/pcx. Declare a pattern to check the specified type of name (styleid) against.

proc ::pcx::nameStylePattern {version styleid pattern} {
    variable current
    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }

    upvar #0 ${current}::nspattern$version v

    #puts OP/$current/$version/$styleid/$pattern

    lappend v [list $styleid $pattern]
    set     v [lsort -unique -index 0 $v]
    return
}

# ### ######### ###########################
## API/pcx. Declare scanner command for a command provided by a
## specific version of the package we are checking. If no checker is
## provided a checker is expected for this version, and will be used.

## Right now we are simply filling some datastructures in the
## namespace of this checker package. The data structures are
## ready for interpretation by the 'pcx::init' command.

proc ::pcx::scan {version command {def {}}} {
    variable current
    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }

    upvar #0 ${current}::scanCmds$version s

    if {$def == {}} {
	lappend s ${command}-TPC-SCAN 1
    } else {
	lappend s $command $def
    }
    return
}

# ### ######### ###########################
## API/pcx. Declare checker command for a command provided by a
## specific version of the package we are checking. If no checker is
## provided a checker is expected for this version, and will be used.

## Right now we are simply filling some datastructures in the
## namespace of this checker package. The data structures are
## ready for interpretation by the 'pcx::init' command.

proc ::pcx::check {version mode command def} {
    variable current
    if {$current == {}} {
	return -code error \
		"[info level 0] has to be called\
		after 'pcx::register'"
    }
    if {$def == {}} {
	return -code error \
		"[info level 0]: Definition must not be empty."
    }

    if {$mode eq "std"} {
	upvar #0 ${current}::checkers$version     c
    } elseif {$mode eq "xref"} {
	upvar #0 ${current}::xrefCheckers$version c
    } else {
	return -code error \
		"[info level 0]: Unknown check mode \"$mode\",\
		expected \"std\", or \"xref\""
    }

    lappend c $command $def
    return
}

# ### ######### ###########################
## API/pcx. Test if a version is supported by the checker package.
## Find highest version supporting a specific version of tcl.

proc ::pcx::supported {chkPkg ver} {
    variable            verTable
    return [info exists verTable($chkPkg,$ver)]
}

proc ::pcx::tclOf {chkPkg ver} {
    variable verTable
    return  $verTable($chkPkg,$ver)
}

proc ::pcx::highest {chkPkg {tclver {}}} {
    variable            verTable

    if {$tclver == {}} {
	# Just return the highest possible.
	return [lindex [split [lindex \
		[lsort -dict -decreasing [array names verTable ${chkPkg},*]] \
		0] ,] 1]
    }
    foreach k [lsort -dict -decreasing [array names verTable ${chkPkg},*]] {
	set requiredTcl $verTable($k)
	if {[package vcompare $requiredTcl $tclver] <= 0} {
	    return [lindex [split $k ,] 1]
	}
    }
    return {}
}

proc ::pcx::allfor {chkPkg tclver} {
    variable verTable

    set res [list]
    foreach k [lsort -dict -decreasing [allavailable $chkPkg]] {
	set requiredTcl $verTable($k)
	if {[package vcompare $requiredTcl $tclver] <= 0} {
	    lappend res [lindex [split $k ,] 1]
	}
    }
    return $res
}

proc ::pcx::allavailable {chkPkg} {
    variable verTable
    return [array names verTable ${chkPkg},*]
}

# ### ######### ###########################
## API/pcx. Test if package definitions are active.

proc ::pcx::isActive {chkPkg versVar} {
    upvar 1 $versVar version
    variable             chkVersions
    set res [info exists chkVersions($chkPkg)]
    if {$res} {
	set version $chkVersions($chkPkg)
    }
    return $res
}

# ### ######### ###########################
## API/pcx. Register checker, scanner, variables

proc ::pcx::checkers {cmds} {
    variable checker
    foreach {name cmd} $cmds {
	set checker($name) $cmd
    }
    return
}

proc ::pcx::scanners {cmds} {
    variable scanner
    foreach {name cmd} $cmds {
	set scanner($name) $cmd
    }
    return
}

proc ::pcx::variables {vars_} {
    variable vars
    foreach v $vars_ {lappend vars $v}
    return
}

proc ::pcx::mathoperators {ops_} {
    variable mathops
    foreach o $ops_ {lappend mathops $o}
    return
}

proc ::pcx::orderdef {name def} {
    variable orders
    set      orders($name) $def
    return
}

proc ::pcx::mathvoperators {ops_} {
    variable mathvops
    foreach o $ops_ {lappend mathvops $o}
    return
}

proc ::pcx::perfilecheckers {cmds_} {
    variable perfile
    lappend  perfile {*}$cmds_
    return
}

proc ::pcx::nspatterns {dict} {
    variable nspattern
    lappend  nspattern {*}$dict
    return
}

# TODO: topDefinition: Incorrect when trying to copy/overload the
# checker def of a command having both scan and checker
# definitions. We will get the scan definition.

proc ::pcx::topDefinition {cmd} {
    variable checker
    variable scanner

    if {[analyzer::isScanning] && [info exists scanner($cmd)]} {
	return $scanner($cmd)
    }

    if {[info exists checker($cmd)]} {
	return $checker($cmd)
    }

    if {![uproc::exists [context::globalScope] $cmd pdef]} {
	return {}
    }

    # Previously generated definition.
    # Look for a 'builtin' first.

    foreach p $pdef {
	array set _ $p
	if {[string equal $_(type) builtin]} {
	    if {[analyzer::isScanning] && [info exists _(scancmd)] && ($_(scancmd) != {})} {
		# scancmd = 'checkBuiltinCmd {chained}'
		return [lindex $_(scancmd) 1]
	    }
	    if {[info exists _(checkcmd)] && ($_(checkcmd) != {})} {
		# checkcmd = 'checkBuiltinCmd {chained}'
		return [lindex $_(checkcmd) 1]
	    }
	    return {}
	}
	unset _
    }

    # No builtin found. Its a procedure. Return the command for
    # the first definition.

    array set _ [lindex $pdef 0]
    if {[analyzer::isScanning] && [info exists _(scancmd)] && ($_(scancmd) != {})} {
	return $_(scancmd)
    }
    if {[info exists _(checkcmd)] && ($_(checkcmd) != {})} {
	return $_(checkcmd)
    }

    return {}
}

# ### ######### ###########################
# API/pcx

# pcx::getCheckVersion --
#
#	Return the version of pkg that is being checked.
#
# Arguments:
#	pkg	The name of the package.
#
# Results:
#	The version number, or -1 if the package is not loaded.

proc pcx::getCheckVersion {pkg} {
    variable chkVersions
    #parray  chkVersions

    set key [::analyzer::getFile],$pkg
    if {[info exists chkVersions($key)]} {
	set res $chkVersions($key)
    } elseif {[info exists chkVersions($pkg)]} {
	set res $chkVersions($pkg)
    } else {
	set res -1
    }

    # Magic to allow ok execution in unwrapped form during
    # development. The projectInfo package may provide us with a bogus
    # version number, a place holder for the actual one.

    if {($pkg eq "coreTcl") && ($res eq "@tcltkver@")} {
	set res [info tclversion]
    }

    #::log::log debug pcx/getCheckVersion/$pkg/__/$res/

    return $res
}


# ### ######### ###########################
## API/checker/pcx. Common initialization sequence.

proc ::pcx::init {namespace ver} {
    #
    ## Register scan commands

    #::log::log debug pcx/::${namespace}::scanCmds$ver

    set stop ::${namespace}::scanCmds$ver
    foreach name [lsort [info vars ::${namespace}::scanCmds*]] {
	#::log::log debug pcx/\t$name
	if {[string compare $name $stop] > 0} {break}
	pcx::scanners [set $name]
	if {$name eq $stop} {break}
    }

    ## Register regular checker commands, possibly reduced to
    ## handle only cross-referencing.

    set normal 1
    if {$::configure::xref} {
	set xr [lsort [info vars ::${namespace}::xrefCheckers*]]
	if {[llength $xr]} {
	    set normal 0
	    set stop   ::${namespace}::xrefCheckers$ver
	    foreach name $xr {
		#::log::log debug pcx/\t$name
		if {[string compare $name $stop] > 0} {break}
		pcx::checkers [set $name]
		if {$name eq $stop} {break}
	    }
	}
    }
    if {$normal} {
	set stop ::${namespace}::checkers$ver
	foreach name [lsort [info vars ::${namespace}::checkers*]] {
	    #::log::log debug pcx/\t$name
	    if {[string compare $name $stop] > 0} {break}
	    pcx::checkers [set $name]
	    if {$name eq $stop} {break}
	}
    }

    ## Register package variables.
    # Bugzilla 28919. Fixed typo, 'var*' -> 'vars*', prevented
    # declaration of variables.

    set stop ::${namespace}::vars$ver
    foreach name [lsort [info vars ::${namespace}::vars*]] {
	#::log::log debug pcx/\t$name
	if {[string compare $name $stop] > 0} {break}
	pcx::variables [set $name]
	if {$name eq $stop} {break}
    }

    # Register package expr operators and functions.

    #puts OP/def!$namespace

    set stop ::${namespace}::mathop$ver
    foreach name [lsort [info vars ::${namespace}::mathop*]] {
	#::log::log debug pcx/\t$name
	if {[string compare $name $stop] > 0} {break}

	#puts OP/def\ [set $name]

	pcx::mathoperators [set $name]
	if {$name eq $stop} {break}
    }

    set stop ::${namespace}::order$ver
    foreach name [lsort [info vars ::${namespace}::order*]] {
	#::log::log debug pcx/\t$name
	if {[string compare $name $stop] > 0} {break}

	#puts OP/def\ [set $name]

	pcx::orderdef $namespace [set $name]
	if {$name eq $stop} {break}
    }

    set stop ::${namespace}::mathvop$ver
    foreach name [lsort [info vars ::${namespace}::mathvop*]] {
	#::log::log debug pcx/\t$name
	if {[string compare $name $stop] > 0} {break}

	#puts OP/def\ [set $name]

	pcx::mathvoperators [set $name]
	if {$name eq $stop} {break}
    }

    # Register package per-file checkers

    set stop ::${namespace}::perfile$ver
    foreach name [lsort [info vars ::${namespace}::perfile*]] {
	#::log::log debug pcx/\t$name
	if {[string compare $name $stop] > 0} {break}

	#puts OP/def\ [set $name]

	pcx::perfilecheckers [set $name]
	if {$name eq $stop} {break}
    }

    # Register package style patterns. 

    set stop ::${namespace}::nspattern$ver
    foreach name [lsort [info vars ::${namespace}::nspattern*]] {
	#::log::log debug pcx/\t$name
	if {[string compare $name $stop] > 0} {break}

	#puts OP/def\ [set $name]
	set dict {}
	foreach item [set $name] {
	    lassign $item s p
	    lappend dict $s $p
	}
	pcx::nspatterns $dict
	if {$name eq $stop} {break}
    }

    ## Done
    return
}

# ### ######### ###########################
## API/checker. Return list of packages checked. Translate checker
## package to true package name

proc ::pcx::loaded {} {
    variable loaded

    set res [list]
    foreach {k v} [array get loaded] {
	if {[string match t,* $k]} continue
	lappend res $k $v
    }
    return $res
}

proc ::pcx::checkerOf {pkg} {
    variable loaded
    return  $loaded(t,$pkg)
}

proc ::pcx::packageOf {chkPkg} {
    variable loaded
    return  $loaded($chkPkg)
}

# ### ######### ###########################
## API/checker. Return list of versions for checker package.

proc ::pcx::used {} {
    variable chkVersions
    set res [list]
    foreach {k v} [array get chkVersions] {
	if {[string match *,* $k]} continue
	lappend res $k [packageOf $k]
    }
    return $res
}

proc ::pcx::usedversions {chkPkg} {
    # chkPkg = checker package
    variable chkVersions

    set res [list]
    if {[info exists chkVersions($chkPkg)]} {
	lappend res $chkVersions($chkPkg)
    }
    foreach k [array names chkVersions *,$chkPkg] {
	lappend res $chkVersions($k)
    }
    return [lsort -uniq $res]
}

# ### ######### ###########################
## Internals. Data structures.

namespace eval ::pcx {
    # List of paths containing PCX files. Initialized with static
    # paths, and data from the command line.

    variable dirlist {}

    # Map. Package name to file containing the checker definitions for
    # that package. Initialized by the first search for PCX files.

    variable  pcx
    array set pcx {}

    # Map. Existence of a key indicates that the package with the same
    # name as the key is already loaded. The mapped value is the
    # true name of the package. An additional key is to keep the
    # true name also.

    variable  loaded
    array set loaded {}

    # Note which package versions were chosen for checking.
    #
    # Keys: file,package -> version
    #       package      => version
    #
    # The per file information allows us to find inconsistently
    # required packages in the code. The package name is the name of
    # the checker package.

    variable  chkVersions
    array set chkVersions {}

    # Notes which package versions were asked for by the user.
    #
    # NOTE / DANGER
    #
    # The package name used as key is the true name of the Tcl
    # package, _and not_ the name of the checker package. Use the
    # information in 'loaded' (s.a.) to translate from checker package
    # to true package.

    variable  useVersions
    array set useVersions {}

    # The verTable array maps package versions to specific versions
    # of Tcl packages.  This information is used when resolving which
    # versions should be loaded for each package.
    #
    # In other words, the array delivers the minimal version of the
    # tcl core which is required to run specific versions of packages.
    #
    # The package name used as key is the name of the checker package.

    variable  verTable
    array set verTable {}

    # ### ### ### ######### ######### #########
    ## Reading PCX files ...
    ## - The namespace for the checker package, so that the
    ## declaration commands following it don't have to repeat
    ## the name.

    variable current     {} ; # Namespace
    variable currentname {} ; # Base name

    ## ######### ######### #########
}

# ### ######### ###########################
## Internals. Initialization

proc ::pcx::Initialize {} {
    global   env
    variable dirlist
    variable here

    # See tclapp/lib/app-tclapp/tclapp_pkg.tcl, SearchPaths for
    # equivalent code used by TclApp. We might wish to factor the
    # standard search into a command for the common tdk code.

    foreach base [list \
	    [file join $starkit::topdir data pcx] \
	    $::projectInfo::pcxPdxDir \
	    $here
	    ] {
	if {
	    [file exists      $base] &&
	    [file isdirectory $base] && 
	    [file readable    $base]
	} {
	    lappend dirlist $base
	}
    }

    # Paths from the preferences. Uses same key as TclApp.
    # I.e. where TclApp is looking for .tap files we are
    # looking for .pcx files.

    foreach base [pref::devkit::pkgSearchPathList] {
	if {
	    [file exists      $base] &&
	    [file isdirectory $base] && 
	    [file readable    $base]
	} {
	    lappend dirlist $base
	}
    }

    # Paths from the User environment.

    foreach v [list \
	    $::projectInfo::pcxPdxVar \
	    TCLPRO_LOCAL \
	    ] {
	if {![info exists       env($v)]} continue
	if {![file exists      $env($v)]} continue
	if {![file isdirectory $env($v)]} continue
	if {![file readable    $env($v)]} continue
	lappend dirlist $env($v)
    }

    # Remove duplicates, do not disturb the order of paths. Normalize
    # the paths on the way. Unique before normalize reduces
    # normalization effort, unique after normalize because symlinks
    # may generate new duplicates.

    set dirlist [lsort -unique \
		     [struct::list map \
			  [lsort -unique $dirlist] \
			  {file normalize}]]

    # Add subdirectories of the search paths to the search to.
    # (Only one level).

    set res [list]
    foreach p $dirlist {
	lappend res $p
	set sub {}
	catch {set sub [glob -nocomplain -types d -directory $p *]}
	if {[llength $sub] > 0} {
	    foreach s $sub {
		lappend res $s
	    }
	}
    }
    set dirlist $res

    # Expansion complete.

    ## Standard versions of Tcl/Tk we should use for checking.
    # Can be overridden through command line options.

    use Tcl $::projectInfo::baseTclVers
    return
}

proc ::pcx::ResolvePCX {} {
    variable dirlist
    variable pcx

    LOG {RESOLVE for external PCX}

    set dirlist [lsort -uniq $dirlist]

    #::log::log debug "PCX directories: [join $dirlist "\nPCX directories: "]"
    LOG {PCX Directory: [join $dirlist "\nPCX Directory: "]}

    set ml 0
    foreach dir $dirlist {
	set files {}
	catch {set files [glob -nocomplain -dir $dir *.pcx]} 
	foreach f $files {
	    set pkg [file rootname [file tail $f]]
	    regsub -all _ $pkg :: pkg
	    set pcx($pkg) $f
	    set l [string length $pkg]
	    if {$l > $ml} {set ml $l}
	}
    }

    DEBUG {foreach pkg [lsort -dict [array names pcx]] {
	LOG {Package ([format %-${ml}s $pkg]) @ $pcx($pkg)}
    }}

    proc ::pcx::ResolvePCX {} {}
    return
}

# ### ######### ###########################
## Ready to use.

namespace eval pcx {
    variable here [file dirname [info script]]
    variable loaddebug 0
}

::pcx::Initialize
package provide pcx 1.0
