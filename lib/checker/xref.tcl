# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# xref.tcl --
#
#	This file contains the cross-reference database
#	(except for command usage and definition, this is
#	in 'userproc.tcl').
#
# Copyright (c) 2003-2006 ActiveState Software Inc.
#


# 
# SCCS: %Z% %M% %I% %E% %U%

package require log   ; # Tcllib | Logging and Tracing
package require md5 2 ; # Tcllib | md5 hash, option -hex supported

namespace eval xref {

    ############################################
    # Files

    # file/path -> hash (unique id)

    variable  files
    array set files {}

    # hash -> list of paths.

    variable  fids
    array set fids {}

    ############################################
    # Namespaces = contexts ...

    # context => list of definitions (namespace eval).

    variable  nsdef
    array set nsdef {}

    # context => list of usage (namespace xxx).

    variable  nsuse
    array set nsuse {}

    ############################################
    # Variables ...

    # varname => list of definitions

    variable  vardef
    array set vardef {}

    # varname => list of usage

    variable  varuse
    array set varuse {}

    ############################################
    # Packages ... Req'uired, and defined/provided

    variable preq ; array set preq {}
    variable pdef ; array set pdef {}
    variable plastname {}
    variable plastop   {}

    ############################################
}


#############################################################
# Files

proc xref::addfiles {files_} {
    # Adds the files in the list to the xref data. Computes a
    # hash. This can be used by a merge tool to look for identical
    # files in different locations when merging several xref databases
    # into one.

    variable files
    variable fids

    # Note: The hash is the unique id for the file.
    # It can be specified on the commandline (CILE
    # only so far).

    if {($::configure::md5 ne "") && ($::configure::md5 ne "Suppress")} {
	foreach f $files_ {
	    #PutsAlways "# xref file: $f"
	    set files($f) $::configure::md5
	    lappend fids($::configure::md5) $f
	}
    } else {
	foreach f $files_ {
	    #PutsAlways "# xref file: $f"
	    set files($f) [set id [md5::md5 -hex [read [set fh [open $f r]]][close $fh]]]
	    lappend fids($id) $f
	}
    }
    return
}

proc xref::files {} {
    variable files
    variable fids
    return [list [array get files] [array get fids]]
}


#############################################################
# Namespaces

proc xref::nsrecord {name def data} {
    variable nsdef
    variable nsuse

    #::log::log debug "NAMESPACE ($name) DEF $def ($data)"

    if {$def} {
	upvar 0 nsdef db
    } else {
	upvar 0 nsuse db
    }
    if {![info exists db($name)] || ($data ni $db($name))} {
	lappend db($name) $data
    }
    return
}

proc xref::nsget {} {
    variable nsdef
    variable nsuse
    return [list [array get nsdef] [array get nsuse]]
}


proc xref::nsDefine {name args} {
    array set _ $args
    set _(scope) [BaseScope [context::topScope]]
    set _(loc)   [analyzer::getLocation]

    nsrecord $name 1 [array get _]
    return
}


proc xref::nsUse {name args} {
    array set _ $args
    set _(scope) [BaseScope [context::topScope]]
    set _(loc)   [analyzer::getLocation]

    nsrecord $name 0 [array get _]
    return
}


#############################################################
# Variables


proc xref::varrecord {name def data} {
    variable vardef
    variable varuse

    #::log::log debug "VAR ($name) DEF $def ($data)"

    if {$def} {
	upvar 0 vardef db
    } else {
	upvar 0 varuse db
    }
    if {![info exists db($name)] || ($data ni $db($name))} {
	lappend db($name) $data
    }
    return
}

proc xref::varget {} {
    variable vardef
    variable varuse
    return [list [array get vardef] [array get varuse]]
}

proc xref::varId {name} {
    # Generate unique id for the variable referenced in 'name'.
    # Use the scopeStack to determine the scope we are in, and also
    # the location of the scope definition (via cmdrange) ...

    return [varIdAt [context::topScope] $name]
}

proc xref::varIdAt {scope name} {
    return [list [BaseScope $scope] $name]
}

proc xref::varIdAbsolute {absname} {
    # Split into namespace and name components, then create a proper
    # scope for the former, at last convert this into a variable
    # id.

    #::log::log debug "varIdAbsolute/s ([list namespace [context::head $absname]])"
    #::log::log debug "varIdAbsolute/t ([namespace tail $absname])"

    return [varIdAt \
	    [list namespace [context::head $absname]] \
	    [namespace tail $absname]]
}


proc xref::varUpdateUpvar {newname level origname scopes} {
    variable vardef
    set id [varId $newname]

    if {[info exists vardef($id)]} {
	#::log::log debug "varUpdateUpvar {$newname $level $origname $scopes}"
	#::log::log debug *\t[join $vardef($id) \n*\t]

	set n 0
	foreach d $vardef($id) {
	    array set _ $d

	    if {[info exists _(origin)] && ($_(origin) eq [list RESOLVE $level $origname])} {
		set _(originscopes) $scopes
		lset vardef($id) $n [array get _]
		return
	    }
	    unset _
	    incr n
	}
    }
    return
}


proc xref::varDef {type name args} {
    array set _  $args
    set _(type)  $type
    set _(loc)   [analyzer::getLocation]
    set _(scope) [BaseScope [context::topScope]]

    #::log::log debug "varDef SCOPEs: ($context::scopeStack)"

    varrecord [varId $name] 1 [array get _]
    return
}

proc xref::varDefAt {type id args} {
    array set _  $args
    set _(type)  $type
    set _(loc)   [analyzer::getLocation]
    set _(scope) [BaseScope [context::topScope]]

    varrecord $id 1 [array get _]
    return
}

proc xref::varDefAtClosure {type id args} {
    array set _  $args
    set _(type)  $type
    set _(loc)   [analyzer::getLocation]
    set _(scope) [BaseScope [context::topScope]]

    varrecord $id 1 [array get _]

    # Recurse to find all places this variable comes from and
    # set definitions there too.

    variable vardef
    foreach d $vardef($id) {
	if {
	    ($_(type)   eq "imported") &&
	    ($_(origin) ne "UNKNOWN")  &&
	    ![string match RESOLVE* $_(origin)]
	} {
	    varDefAtClosure exported $_(origin)
	}
    }
    return
}

proc xref::varDefAbsolute {type absname args} {
    array set _  $args
    set _(type)  $type
    set _(loc)   [analyzer::getLocation]
    set _(scope) [BaseScope [context::topScope]]

    set id [varIdAbsolute $absname]
    varrecord $id 1 [array get _]
    return
}

proc xref::varUse {name args} {
    array set _  $args
    set _(loc)   [analyzer::getLocation]
    set _(scope) [BaseScope [context::topScope]]

    varrecord [varId $name] 0 [array get _]
    return
}

proc xref::varUseAt {id args} {
    array set _  $args
    set _(loc)   [analyzer::getLocation]
    set _(scope) [BaseScope [context::topScope]]

    varrecord $id 0 [array get _]
    return
}

proc xref::varUseAbsolute {absname args} {
    array set _  $args
    set _(loc)   [analyzer::getLocation]
    set _(scope) [BaseScope [context::topScope]]

    set id [varIdAbsolute $absname]
    varrecord $id 0 [array get _]
    return
}

proc xref::varDefined {name defvar} {
    upvar 1 $defvar data
    return [varDefinedAt [varId $name] data]
}

proc xref::varDefinedAt {id defvar} {
    variable vardef

    #::log::log debug "xref::varDefinedAt ? ($id)"

    if {![info exists vardef($id)]} {
	#::log::log debug "\tNO"
	return 0
    }
    upvar 1 $defvar data
    set             data $vardef($id)

    #::log::log debug "\tYES"
    return 1
}

proc xref::varDefinedAbsolute {absname defvar} {
    upvar 1 $defvar data
    return [varDefinedAt [varIdAbsolute $absname] data]
}



proc xref::BaseScope {scope} {
    foreach {type scopename loc} $scope break
    if {($type eq "proc") || ($type eq "class")} {return $scope}

    # The scope is a merging scope, i.e. any fragments it may have
    # are seen as one scope. Multiple proc definitions on the
    # other hand do not merge, for example. Now for merging scopes
    # the location is not relevant to the id.
    
    return [list $type $scopename]
}

#############################################################
# Packages

proc xref::pkgrecord {name op v exact} {
    #::log::log debug %%($name|$op|$v)

    variable preq
    variable pdef

    set data [list \
	    loc [analyzer::getLocation] \
	    ver $v]

    if {$op eq "require"} {
	lappend data exact $exact
	upvar 0 preq db
    } else {
	upvar 0 pdef db
    }
    if {![info exists db($name)] || ($data ni $db($name))} {
	lappend db($name) $data
    }
    return
}

proc xref::pRequired {} {
    variable preq
    return [array get preq]
}

proc xref::pProvided {} {
    variable pdef
    return [array get pdef]
}

proc xref::pExternal {} {
    # This is (pRequired - pProvided)

    variable preq
    variable pdef

    #parray preq
    #parray pdef

    array set res {}
    foreach k [array names preq] {
	if {[info exists pdef($k)]} continue
	set res($k) $preq($k)
    }
    return [array get res]
}

proc xref::pVersions {pdata} {
    set res {}

    #::log::log debug @@@@$pdata

    foreach pd $pdata {
	array set _ $pd
	lappend res $_(ver)
    }

    #::log::log debug %%%%$res
    return [lsort -uniq $res]
}

#############################################################

proc xref::init {} {
    # Definition of global namespace, self-referential, without
    # location in a file.
    nsrecord :: 1 {scope {namespace ::} loc {{} {} {{} {}}}}
    return
}


#############################################################
xref::init
package provide xref 1.0
