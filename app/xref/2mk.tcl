# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}


# This application takes the output of [procheck -xref] and converts
# it into a metakit database. See
# "devkit/doc/3.0/xref/03.01.Metakit.txt" for its definition, and
# "devkit/doc/3.0/xref/03.00.Database.txt" for the contents.

# Ensure silent closing of applicaiton when the output pipe is broken

rename puts __puts
proc puts {args} {
    if {[catch {
	eval [linsert $args 0 __puts]
    }]} {exit 0}
}

#################################################################

puts "#%% INIT/..... [clock seconds] -- [clock format [clock seconds]]"

package require Mk4tcl ; # we need only the base interface, no OO at all.

#################################################################

foreach {dbscript mkfile} $argv break
if {($dbscript == {}) || ($mkfile == {})} {
    puts stderr "Wrong#args, expected: $argv0 input output"
    exit 1
}

#################################################################
# Initialization (open file, generate views)
#
# Denormalized database ... Redundant data for easy display by
# frontend, no need for slow postprocessing regenerating we
# information we have here at no cost.

# 29 Jan 2004 (i) Restructured databse to not use subviews.
#                 The main view stores begin/end offsets
#                 into the secondary views.

catch {file delete -force $mkfile}

mk::file open db $mkfile

# ------------------------------------------------------------- #
# Keep in sync with installer/install_lib.tcl <patch_txr>
mk::view layout db.file {
    md5:S
    where_str:S
    rowid:I
}

# ------------------------------------------------------------- #
# Slightly different from the remainder. Instead of storing
# start/count information in the master the secondary has a
# column refering to the entry in the master. Required because
# the data does not come en bloc, like for the others.

mk::view layout db.location  {
    file:I line:I begin:I size:I end:I
    file_path:I
    parent:I
    hasobj:S
    rowid:I
}
mk::view layout db.location_obj  {
    locid:I
    id:I type:S name:S
}
# location.obj.type's
#
# V - variable
# P - Package
# C - Command(incl. procedures)
# N - Namespace
#

# ------------------------------------------------------------- #

mk::view layout db.namespace {
    name:S
    parent:I
    defst:I defn:I
    usest:I usen:I
    rowid:I
}
mk::view layout db.namespace_def {
    loc:I file_path:I line:I hasobj:S begin:I size:I
}
mk::view layout db.namespace_use {
    loc:I file_path:I line:I hasobj:S begin:I size:I
}

# ------------------------------------------------------------- #
# General start/count schema, plus back link from _def to master.
# For joining in the interface.

mk::view layout db.command   {
    name:S
    defst:I defn:I
    usest:I usen:I
    rowid:I
}
mk::view layout db.command_def   {
    cmdid:I
    loc:I type:S prot:S escope:I origin:I
    escope_str:S
    origin_str:S
    file_path:I line:I
    package:I
}
mk::view layout db.command_use   {
    loc:I file_path:I line:I hasobj:S begin:I size:I
}

# ------------------------------------------------------------- #
# Variable information, split over 4 views, no subviews. Master
# view knows per entry the range of the information in the secondary
# views

mk::view layout db.variable  {
    name:S type:S sid:I sloc:I
    scope:S fullname:S
    defst:I defn:I
    usest:I usen:I
    rowid:I
}
mk::view layout db.variable_def  {
    loc:I type:S otype:S oid:I
    file_path:I line:I
    callst:I calln:I
    origin_str:S
}
mk::view layout db.variable_def_call  {
    type:S id:I name:S
}
mk::view layout db.variable_use  {
    loc:I file_path:I line:I
}

# ------------------------------------------------------------- #

mk::view layout db.package  {
    name:S
    defst:I defn:I
    usest:I usen:I
    rowid:I
}
mk::view layout db.package_def  {
    loc:I file_path:I line:I version:S
}
mk::view layout db.package_use  {
    loc:I file_path:I line:I version:S exact:I
}

# ------------------------------------------------------------- #

#################################################################
# Generate a slave interp for the safe execution of the incoming
# script.

set ip [interp create -safe]
foreach c [$ip eval {info commands}] {
    if {[string equal rename $c]} {continue}
    $ip eval [list rename $c {}]
}
$ip eval {rename rename {}}

foreach p {file variable namespace command ping package warning:} {
    interp alias $ip $p {} X$p
}

proc Xwarning: {args} {}

#################################################################
# Define all required helpers ...

global fid   ; set       fid  0  ;# Id counter for files
global file  ; array set file {} ;# MD5(path) -> rowid
global fnam  ; array set fnam {} ;# MD5(path) -> paths
global fpid  ; array set fpid {} ;# paths     -> rowid

global nid  ; set       nid  0 ; # Id counter for namespaces
global ns   ; array set ns {}
global nsub ; set       nsub 0
global ndef ; set       ndef 0 ; # Id counter for nspace def's
global nuse ; set       nuse 0 ; # Id counter for nspace uses.

global lid  ; set       lid  0 ; # Id counter for locations
global loc  ; array set loc {}
global lsub ; set       lsub 0

global cid  ; set       cid  0 ; # Id counter for commands
global cmd  ; array set cmd {}
global csub ; set       csub 0
global cdef ; set       cdef 0 ; # Id counter for cmd def's
global cuse ; set       cuse 0 ; # Id counter for cmd uses.

global vid  ; set       vid  0 ; # Id counter for variables
global var  ; array set var {}
global vsub ; set       vsub 0 ; # Statistics, total #def/use
global vdef ; set       vdef 0 ; # Id counter for var def's
global vuse ; set       vuse 0 ; # Id counter for var uses.
global vcal ; set       vcal 0 ; # Id counter for def call.

global pid  ; set       pid  0 ; # Id counter for packages
global pkg  ; array set pkg {}
global psub ; set       psub 0
global pdef ; set       pdef 0 ; # Id counter for pkg def's
global puse ; set       puse 0 ; # Id counter for pkg uses.

set file() -1 ; # Default for things without files.

# Fixup database

global fixups ; set fixup {}

#################################################################
# Empty file path, predefined entry.

mk::row append db.file rowid $fid where_str "" md5 ""
set fpid()                        $fid
incr                               fid

#################################################################

proc Xping {} {
    # Feedback operation ...
    puts .
}

#################################################################

proc Xfile {id script} {
    global first
    if {$first} {
	puts "#%% DUMP/begin [clock seconds] -- [clock format [clock seconds]]"
    }
    set first 0

    puts "    File $id"

    global file fid fnam fpid
    # script = k/v 'path' path

    set  file($id) [set fileid $fid]
    incr fid

    mk::row append db.file \
	    md5 $id rowid $fileid

    set str {}
    foreach {k path} $script {
	if {[string match #* $k]} {continue}

	puts "    $fileid  $path"

	lappend str $path
    }

    # Derived data ...
    mk::set db.file!$fileid \
	    where_str [set fn [join $str \n]]

    set fnam($id) $fn
    set fpid($fn) $fileid

    return $fileid
}


global pstartd ; array set pstartd {}
global pstartu ; array set pstartu {}

proc Xpackage {op id script} {
    puts "    Package $op $id"

    global pkg pid psub pdef puse fpid pstartd pstartu

    set old [info exists pkg($id)]

    if {!$old} {
	set  pkg($id) [set plid $pid]
	incr pid
	mk::row append db.package \
		name   $id \
		rowid  $plid \
		defst $pdef defn   0    \
		usest $puse usen   0

	# pdef/puse are placeholders, and only that for now.
	# We use pstart(d/u) to keep track for which packages
	# the counters are initialized.

	set pstartd($plid) .
	set pstartu($plid) .

    } else {
	set plid $pkg($id)
    }

    set version {}
    set loc     {}
    set exact   {}

    foreach {k v} $script {
	if {[string match #* $k]} {continue}
	switch -exact -- $k {
	    loc        {set loc     $v}
	    version    {set version $v}
	    exact      {set exact   $v}
	}
    }

    if {$loc != {}} {
	foreach {fname __ line __ __ __} [XlocData $loc] break
	set locid [Xloc $loc = P $plid $id]
    } else {
	set fname {}
	set line 0
	set locid -1
    }

    if {$op eq "require"} {
	if {$exact == {}} {set exact 0}

	set  n [mk::get db.package!$plid usen]
	incr n
	mk::set db.package!$plid usen $n

	mk::row append db.package_use \
		loc       $locid \
		file_path $fpid($fname) \
		line      $line \
		version   $version \
		exact     $exact

	if {[info exists pstartu($plid)]} {
	    unset pstartu($plid)
	    mk::set db.package!$plid usest $puse
	}

	incr puse
    } else {
	set  n [mk::get db.package!$plid defn]
	incr n
	mk::set db.package!$plid defn $n

	mk::row append db.package_def \
		loc       $locid \
		file_path $fpid($fname) \
		line      $line \
		version   $version

	if {[info exists pstartd($plid)]} {
	    unset pstartd($plid)
	    mk::set db.package!$plid defst $pdef
	}

	incr pdef
    }

    incr psub
    return $plid
}


proc Xnamespace {id script} {
    puts "    Namespace $id"

    global ns nid nsub ndef nuse fpid
    # script = {definition {k v ...} ... usage {k v ...} ...}

    set  ns($id) [set nsid $nid]
    incr nid

    if {[string equal $id ::]} {
	set parent -1
    } else {
	set nsp [namespace qualifiers $id]
	if {$nsp == {}} {set nsp ::}
	if {[info exists ns($nsp)]} {
	    set parent $ns($nsp)
	} else {
	    Xfixup db.namespace!$nsid parent namespace $nsp 
	    set parent -1
	}
    }

    mk::row append db.namespace \
	    name   $id \
	    parent $parent rowid $nsid \
	    defst  $ndef \
	    usest  $nuse

    set defn 0
    set usen 0
    foreach {k v} $script {
	if {[string match #* $k]} {continue}
	switch -exact -- $k {
	    definition {
		set loc {}
		foreach {kd vd} $v {
		    if {[string match #* $kd]} {continue}
		    if {[string equal $kd loc]} {set loc $vd}
		}
		foreach {fname __ line begin size __} [XlocData $loc] break

		mk::row append db.namespace_def \
			loc       [Xloc $loc = N $nsid $id] \
			file_path $fpid($fname) \
			line      $line \
			begin     $begin \
			size      $size \
			hasobj    yes
		incr defn
		incr nsub
		incr ndef
	    }
	    usage {
		set loc {}
		foreach {ku vu} $v {
		    if {[string match #* $ku]} {continue}
		    if {[string equal $ku loc]} {set loc $vu}
		}
		foreach {fname __ line begin size __} [XlocData $loc] break

		mk::row append db.namespace_use \
			loc       [Xloc $loc] \
			file_path $fpid($fname) \
			line      $line \
			begin     $begin \
			size      $size
		# hasobj - TODO fixup required.
		incr usen
		incr nsub
		incr nuse
	    }
	    default {
		puts "Namespace: Unknown key \"$k\""
	    }
	}
    }

    # Derived data ... (I)
    mk::set db.namespace!$nsid defn $defn usen $usen

    return $nsid
}

proc Xcommand {id script} {
    puts "    Command $id"

    global cmd cid ns csub cdef cuse fpid

    set  cmd($id) [set cmdid $cid]
    incr cid

    mk::row append db.command \
	    name   $id rowid $cmdid \
	    defst $cdef \
	    usest $cuse

    set defn 0
    set usen 0
    foreach {k v} $script {
	if {[string match #* $k]} {continue}
	switch -exact -- $k {
	    definition {
		set type   {}
		set scope  {}
		set prot   {}
		set loc    {}
		set origin {}
		set pkg    {}

		foreach {kd vd} $v {
		    if {[string match #* $kd]} {continue}
		    switch -exact -- $kd {
			loc        {set loc    $vd}
			type       {set type   $vd}
			scope      {set scope  $vd}
			protection {set prot   $vd}
			origin     {set origin $vd}
			package    {set pkg    $vd}
		    }
		}
		foreach {__ nsname} $scope  break

		if {$origin == {}} {
		    set originid -1
		} elseif {[info exists cmd($origin)]} {
		    set originid $cmd($origin)
		} else {
		    set defid [mk::view size db.command_def]
		    Xfixup db.command_def!$defid origin proc $origin
		    set     originid -1
		}
		if {$pkg == {}} {
		    set p -1
		} else {
		    set fail [catch {set p [GetEntity package $pkg]}]
		    if {$fail} {
			# The command is refering to a package for
			# which there is no explicit definition. We
			# now create this package, but leave
			# definitions, etc blank. We do insert the
			# location of the command as the location of
			# the implicit 'require' statement. After the
			# we ask the database again for the entity,
			# and now we should be successful.

			puts "Creating missing package \"$pkg\""

			Xpackage require $pkg [list loc $loc]
			set p [GetEntity package $pkg]
		    }
		}

		foreach {fname __ line __ __ __} [XlocData $loc] break

		set loc    [Xloc $loc = C $cmdid $id]
		set escope [GetEntity namespace $nsname]

		mk::row append db.command_def \
			cmdid      $cmdid \
			loc        $loc \
			type       $type \
			prot       $prot \
			escope     $escope \
			escope_str $nsname \
			origin     $originid \
			origin_str $origin \
			file_path  $fpid($fname) \
			line       $line \
			package    $p
		incr defn
		incr csub
		incr cdef
	    }
	    usage {
		set loc {}
		foreach {ku vu} $v {
		    if {[string match #* $ku]} {continue}
		    if {[string equal $ku loc]} {set loc $vu}
		}
		foreach {fname __ line begin size __} [XlocData $loc] break

		mk::row append db.command_use \
			loc       [Xloc $loc] \
			file_path $fpid($fname) \
			line      $line \
			begin     $begin \
			size      $size
		# hasobj - TODO fixup required.
		incr usen
		incr csub
		incr cuse
	    }
	    default {
		puts "Command: Unknown key \"$k\""
	    }
	}
    }

    # Derived data ... (I)
    mk::set db.command!$cmdid defn $defn usen $usen
    return $cmdid
}

proc Xvariable {id script} {
    puts "    Variable $id"

    global vid var vsub vdef vuse vcal fpid

    set  var($id) [set varid $vid]
    incr vid

    # Break down id ...
    foreach {scope name}          $id    break
    foreach {type scopename loc}  $scope break
    if {$loc != {}} {
	set loc [Xloc $loc]
    } else {
	set loc -1
    }

    # Remember for loc'definitions
    set fullname "$type $scopename $name"

    if {[catch {set sid [GetEntity $type $scopename]}]} {
	puts "Undefined scope for variable \"$id\""
	set sid -1
    }

    mk::row append db.variable \
	    name     $name \
	    fullname $fullname \
	    scope    "$type $scopename" \
	    type     [string toupper [string index $type 0]] \
	    sid      $sid \
	    sloc     $loc \
	    rowid    $varid \
	    defst    $vdef \
	    usest    $vuse

    set defn 0
    set usen 0
    foreach {k v} $script {
	switch -exact -- $k {
	    definition {
		set loc     {}
		set type    {}
		set origin  {}
		set ocaller {}

		foreach {kd vd} $v {
		    if {[string match #* $kd]} {continue}
		    switch -exact -- $kd {
			loc           {set loc    $vd}
			type          {set type   $vd}
			origin        {set origin $vd}
			originscopes  {set ocaller $vd}
		    }
		}
		foreach {fname __ line __ __ __} [XlocData $loc] break

		foreach {__ nsname} $scope  break

		# Origin decoding ...

		if {$origin == {}} {
		    set ocaller {}
		    set otype {}
		    set oid -1
		    set origin_str ""
		} elseif {[string match UNKNOWN* $origin]} {
		    set ocaller {}
		    set otype   U
		    set oid     -1
		    set origin_str Unknown
		} elseif {[string match RESOLVE* $origin]} {
		    set otype   R
		    set oid     [lindex $origin 1] ;# level!
		    set res [list]
		    set origin_str "Upvar $oid"
		    foreach x $ocaller {
			# x is scope
			foreach {stype sname loc} $x break
			lappend res \
				[string toupper [string index $stype 0]] \
				[GetEntity $stype $sname] \
				"$stype $sname"
		    }
		    set ocaller $res
		} elseif {[info exists var($origin)]} {
		    set oid     $var($origin)
		    set otype   V
		    set ocaller {}
		    set origin_str $origin
		} else {
		    set defid [mk::view size db.variable_def]
		    Xfixup db.variable_def!$defid oid variable $origin

		    set oid -1
		    set otype V
		    set ocaller {}
		    set origin_str $origin
		}

		mk::row append db.variable_def \
			loc        [Xloc $loc = V $varid $fullname] \
			type       $type \
			otype      $otype \
			oid        $oid \
			origin_str $origin_str \
			file_path  $fpid($fname) \
			line       $line \
			callst     $vcal \
			calln      [set cn [expr {[llength $ocaller]/3}]]

		# Append callers ...

		foreach {t i name} $ocaller {
		    mk::row append db.variable_def_call \
			    type $t \
			    id   $i \
			    name $name
		}
		incr vcal $cn
		incr defn
		incr vsub
		incr vdef
	    }
	    usage {
		set loc {}
		foreach {ku vu} $v {
		    if {[string match #* $ku]} {continue}
		    if {[string equal $ku loc]} {set loc $vu}
		}
		foreach {fname __ line __ __ __} [XlocData $loc] break

		mk::row append db.variable_use \
			loc       [Xloc $loc] \
			file_path $fpid($fname) \
			line      $line
		incr usen
		incr vsub
		incr vuse
	    }
	    default {
		puts "Variable: Unknown key \"$k\""
	    }
	}
    }

    # Derived data ...
    mk::set db.variable!${varid} defn $defn usen $usen

    return $varid
}

proc XlocData {ld} {
    global file fnam

    # Take the location apart, and return important stuff ...

    foreach {fmdid line range} $ld break
    foreach {begin size}     $range break

    if {$range == {} || $begin == {} || $size == {}} {
	# For namespaces for which we do not know their location
	set begin -1
	set size  -1
	set end   -1
    } else {
	set end [expr {$begin + $size}]
    }
    if {$line == {}} {set line -1}

    if {$file($fmdid) >= 0} {
	set fname $fnam($fmdid)
    } else {
	set fname ""
    }

    return [list $fname $file($fmdid) $line $begin $size $end]
}

proc Xloc {ld args} {
    global lid loc file fnam lsub fpid

    if {![info exists loc($ld)]} {
	set  loc($ld) [set locid $lid]
	incr lid

	foreach {fname fid line begin size end} [XlocData $ld] break

	#puts "        Location NEW ($ld) - $locid | file $fid ($fname)"

	mk::row append db.location \
		file_path $fpid($fname) \
		file      $fid \
		line      $line \
		begin     $begin \
		size      $size \
		end       $end \
		parent    -1 \
		hasobj    no \
		rowid     $locid
    } else {
	set locid $loc($ld)
	#puts "        Location     $ld - $locid"
    }
    if {[llength $args] > 0} {
	# Register the new object for the location
	foreach {__ type id name} $args break
	mk::row append db.location_obj \
		locid $locid \
		id    $id \
		type  $type \
		name  "$type $name"
	mk::set db.location!${locid} hasobj yes
	incr lsub
    }

    #puts "        %"
    return $locid
}


proc Xfixup {path prop type name} {
    puts "    FIXUP $path/$prop = \[$type $name\]"

    global  fixup
    lappend fixup $path $prop $type $name
    return
}


proc GetEntity {type name} {
    global cmd var ns pkg

    switch -exact -- $type {
	namespace {
	    if {![info exists ns($name)]} {
		# Variable or proc refering to a namespace for
		# which there is no explicit definition. We now
		# create this namespace, but leave definitions,
		# etc blank.
		puts "Creating missing namespace \"$name\""
		Xnamespace $name {}
	    }
	    return $ns($name)
	}
	vimported - variable {
	    return $var($name)
	}
	proc {
	    if {![info exists cmd($name)]} {
		# proc refering to a command for which there is no
		# explicit definition. We now create this command,
		# but leave definitions, etc blank.
		puts "Creating missing proc \"$name\""
		Xcommand $name {}
	    }
	    return $cmd($name)
	}
	package {
	    return $pkg($name)
	}
    }
    return -code error "Unknown type \"$type\""
}

puts "#%% INIT/compl [clock seconds] -- [clock format [clock seconds]]"

#################################################################
# Run the input, this fills the metakit database.
#
# The input is processed line by line to keep memory usage low, and
# conversion fast. The input is multi-megabyte, and we do not wish to
# load all of it at once.

puts {Reading and converting the input}

if {$dbscript eq "-"} {
    set in stdin
} else {
    set in [open $dbscript r]
}


## Statistics ...

set inscript 0
global first ; set first 1

set buffer ""
while {[gets $in line] >= 0} {

    puts . ; # ping
    
    append buffer $line
    incr inscript [string length $line]
    incr inscript ;# For the EOL.
    if {[info complete $buffer]} {
	$ip eval $buffer
	set buffer ""
    }
}
# Handle remainder, this may cause errors.
if {$buffer != {}} {
    $ip eval $buffer
}

if {$dbscript ne "-"} {
    close $in
}

puts "#%% READ/done  [clock seconds] -- [clock format [clock seconds]]"

#################################################################
# Execute the accumulated fixups ...

puts {Backpatching the places requiring fixups}

foreach {path prop type name} $fixup {

    set id [GetEntity $type $name]
    puts "    $type $name = $id /FIXUP $path/$prop"
    mk::set $path $prop $id
}

puts "#%% BACP/done  [clock seconds] -- [clock format [clock seconds]]"

#################################################################
# Complete location parent relationship.

puts {Generate proper nesting of command ranges, i.e locations}

set nest {{-1 -1 -1}} ; # row begin end
set lastfile -1
foreach r [mk::select db.location -sort {file begin}] {
    foreach {fid lno b e} [mk::get db.location!$r file line begin end] break

    if {$fid != $lastfile} {
	#puts "LOC Reinitialize $fid"
	# Reinitialize for new file.
	set lastfile $fid
	set nest {{-1 -1 -1}} ; # row begin end
    }

    #puts "LOC $r - @$lno - $b $e | $fid"

    # Cases:
    # New range behind end of last (may share one character) => pop
    # - Do until stack empty or range found we are inside of.

    while {($b >= [lindex $nest end end]) && [llength $nest]} {
	#puts "    pop"
	set nest [lrange $nest 0 end-1]
    }
    if {[llength $nest] == 0} {
	# Popped everything, this is a toplevel range without
	# any parent ... pop on stack and leave it alone

	#puts "    push /toplevel"
	lappend nest [list $r $b $e]
	continue
    }
    # Range on top of stack begins before current range.
    # Has to end after it. It is our parent. Record this and
    # push us as potential parent of the following ranges.

    set parent [lindex $nest end 0]

    #puts "    parent = $parent"
    #puts "    push"

    mk::set db.location!$r parent $parent
    lappend nest [list $r $b $e]
}

puts "#%% PARE/done  [clock seconds] -- [clock format [clock seconds]]"

#################################################################
# Commit everything, and we are done.

puts {Committing data}

mk::file commit db

puts "#%% CMMT/done  [clock seconds] -- [clock format [clock seconds]]"

#################################################################

puts {Closing}

mk::file close  db

puts "#%% CLOS/done  [clock seconds] -- [clock format [clock seconds]]"

puts "#%% Statistics ..."
puts "#%% Tcl Xref dump: [format %9d $inscript] bytes"
puts "#%% Files:            [format %6d $fid])"
puts "#%% Packages:         [format %6d $pid] (Sub data: [format %6d $psub] | [format %6d $pdef]  [format %6d $puse])"
puts "#%% Namespaces:       [format %6d $nid] (Sub data: [format %6d $nsub] | [format %6d $ndef]  [format %6d $nuse])"
puts "#%% Commands:         [format %6d $cid] (Sub data: [format %6d $csub] | [format %6d $cdef]  [format %6d $cuse])"
puts "#%% Variables:        [format %6d $vid] (Sub data: [format %6d $vsub] | [format %6d $vdef]  [format %6d $vuse]  [format %6d $vcal])"
puts "#%% Locations:        [format %6d $lid] (Sub data: [format %6d $lsub])"

#################################################################
puts Done
exit
