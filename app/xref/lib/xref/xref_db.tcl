# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# xrefdb - /snit::type
#
# Loads the database, is given view description objects.
# Runs the db extending methods for the view descriptions.
#

package require snit
package require mkdb


snit::type ::xrefdb {
    delegate method * to db
    delegate option * to db

    option -mainframe {}

    variable db
    variable fname
    variable dbversion 0

    # Known versions:
    # -1 : NOT a TXR database.
    # 0  : Format used by TDK 3.0
    # 1  : Format used by TDK 3.1

    typemethod version {dbfile} {
	set result [$type dbversion [set v [mkdb ${type}::v $dbfile]]]
	log::log debug dbv=$result
	$v destroy
	return $result
    }
    typemethod dbversion {db} {
	## Look at the database and determine what version
	## it is. The database may not be a TXR database.

	# Phase I. Load structure for easy checking of view and
	# attribute existence (including types).

	array set s {}
	foreach v [$db properties] {
	    foreach {v t} [split $v :] break
	    set s($v,$t) .

	    [$db view $v] as vv
	    foreach i [$vv properties] {
		foreach {i t} [split $i :] break
		if {$t == {}} {set t S}
		set s($v,$i,$t) .
	    }
	}

	# Phase II. Check the structure information
	# against the needs of the various versions.

	foreach version [lsort -integer [array names knownversions]] {
	    set ok 1
	    foreach p $knownversions($version) {
		if {![info exists s($p)]} {
		    #puts missing/$p
		    set ok 0 ; break
		}
	    }
	    if {$ok} {return $version}
	}
	return -1
    }

    typevariable knownversions
    typeconstructor {
        array set knownversions {
            0 {
                command,V           file,V             location,line,I   variable,V
                command,def,V       file,md5,S         location,obj,V    variable,def,V
                command,defn,I      file,rowid,I       location,parent,I variable,defn,I
                command,name,S      file,where,V       location,rowid,I  variable,fullname,S
                command,rowid,I     file,where_str,S   location,size,I   variable,name,S
                command,use,V       namespace,V        package,V         variable,rowid,I
                command,usen,I      namespace,def,V    package,def,V     variable,scope,S
                location,V          namespace,defn,I   package,defn,I    variable,sid,I
                location,begin,I    namespace,name,S   package,name,S    variable,sloc,I
                location,end,I      namespace,parent,I package,rowid,I   variable,type,S
                location,file,I     namespace,rowid,I  package,use,V     variable,use,V
                location,file_str,S namespace,use,V    package,usen,I    variable,usen,I
                location,hasobj,S   namespace,usen,I
            }
            1 {
                command,V               command_def,escope,I      location,V
                command,defn,I          command_def,escope_str,S  location,begin,I
                command,defst,I         command_def,file_path,I   location,end,I
                command,name,S          command_def,line,I        location,file,I
                command,rowid,I         command_def,loc,I         location,file_path,I
                command,usen,I          command_def,origin,I      location,hasobj,S
                command,usest,I         command_def,origin_str,S  location,line,I
                command_def,V           command_def,package,I     location,parent,I
                command_use,begin,I     command_def,prot,S        location,rowid,I
                command_use,file_path,I command_def,type,S        location,size,I
                command_use,hasobj,S    command_use,V             namespace_def,V
                command_use,line,I      variable,sid,I            namespace_def,begin,I
                command_use,loc,I       variable_def,type,S       namespace_def,file_path,I
                command_use,size,I      namespace,V               namespace_def,hasobj,S
                file,V                  namespace,defn,I          namespace_def,line,I
                file,md5,S              namespace,defst,I         namespace_def,loc,I
                variable_def,otype,S    namespace,name,S          namespace_def,size,I
                variable,scope,S        namespace,parent,I        namespace_use,V
                file,rowid,I            namespace,rowid,I         namespace_use,begin,I
                file,where_str,S        namespace,usen,I          namespace_use,file_path,I
                location_obj,V          namespace,usest,I         namespace_use,hasobj,S
                location_obj,id,I       variable_use,V            namespace_use,line,I
                location_obj,locid,I    variable_use,file_path,I  namespace_use,loc,I
                location_obj,name,S     variable_use,line,I       namespace_use,size,I
                location_obj,type,S     variable_use,loc,I        package_use,V
                package,V               package_def,V             package_use,exact,I
                package,defn,I          package_def,file_path,I   package_use,file_path,I
                package,defst,I         package_def,line,I        package_use,line,I
                package,name,S          package_def,loc,I         package_use,loc,I
                package,rowid,I         package_def,version,S     package_use,version,S
                package,usen,I          variable_def,V            variable,usest,I
                package,usest,I         variable_def,calln,I      variable_def_call,type,S
                variable,V              variable_def,callst,I     variable,usen,I        
                variable,defn,I         variable_def,file_path,I  variable_def_call,name,S
                variable,defst,I        variable_def,line,I       variable,type,S        
                variable,fullname,S     variable_def,loc,I        variable_def_call,id,I
                variable,name,S         variable_def,oid,I        variable,sloc,I
                variable,rowid,I        variable_def,origin_str,S variable_def_call,V
            }
        }
    }


    constructor {file args} {
	set fname $file
	set db [mkdb ${selfns}::db $file]
	$db storage: $self

	$self configurelist $args

	# ### ########## ##############################
	## Look at the database and determine what version
	## it is. We can assume that the file is valid.

	set dbversion [$type dbversion $db]

	# ### ########## ##############################
	# Go through all views in the database and extend
	# them to contain the data we need for the display
	# (precomputaton, can't be done as part of the
	# display engine, would kill sorting, projection,
	# and row filtering)

	if 0 {
	    [$db view file] as f ; $f loop c {
		set c(rowid) $c(#)
	    }
	    [$db view location] as l ; $l loop c {
		set c(rowid) $c(#)
	    }
	}

	# ### ########## ##############################
	# Helper views, Single row ... To insert type
	# information into the content views.

	$db define typeN {type:S} {N}
	$db define typeC {type:S} {C}
	$db define typeV {type:S} {V}

	array set vcache {}
	return
    }

    destructor {
	rename $db {}
    }

    # ### ######### ###########################

    method filename  {}       {return $fname}
    method filename: {fname_} {set fname $fname_}

    # ### ######### ###########################
    # Views ... We do not allow reformatting ...

    variable vcache

    method view {name} {
	if {![info exists vcache($name)]} {
	    set v [$self GetView $name]

	    log::log debug "GetView ($name) = $v \n\t[$v properties]"

	    set vcache($name) $v
	    return [$v readonly]
	}
	return [$vcache($name) readonly]
    }

    method GetView {name} {
	switch -glob -- $name {
	    nsroot {
		[$db view namespace] as na
		return [$na select name ::]
	    }
	    *_contents {
		return [$self View/$name]
	    }
	    file_for_join {
		[$db view file]     as f
		[$f  rename rowid:I     file_path:I] as fa
		return [$fa rename where_str:S file_str:S]
	    }
	    file {
		if {$dbversion == 1} {
		    [$db view file] as f
		    if {[$f size] < 2} {
			# Bugzilla 31125.
			# Just the internal file entry. Create an
			# empty view having the correct structure. We
			# copy the original view, remove the offending
			# internal entry and return the result.

			set x [$f range 0 0]
			$x delete 0
			return $x
		    }
		    return [$f range 1 end]
		} else {
		    return [$db view file]
		}
	    }
	    location {
		if {$dbversion == 1} {
		    [$db view location]        as l
		    [$self view file_for_join] as f
		    return [$l join $f file_path]
		} else {
		    return [$db view location]
		}
	    }
	    default {
		return [$db view $name]
	    }
	}
    }

    method listview {name cursorvar} {
	upvar 1 $cursorvar cursor
	set v [$self GetListview $name cursor]

	log::log debug "GetListview ($name) = $v"
	if {$v == {}} {
	    log::log debug "\tEMPTY"
	} else {
	    log::log debug "\t[$v properties]"
	}
	log::logarray debug cursor

	return $v
    }

    method GetListview {name cursorvar} {
	upvar 1 $cursorvar cursor
	return [$self View/list_$name cursor]
    }

    # Layout of all content views:
    # key:I name:S type:I id:I
    # key = id of the object whose content is wanted later on.

    method View/file_contents {} {
	# Derived from 'location'. Flattened and projected.

	if {$dbversion == 0} {
	    # Conversion
	    # 1     file|line|begin|size|end|file_str|parent|hasobj|obj(id|type|name)|rowid
	    #   ren  key|line|begin|size|end|file_str|parent|hasobj|obj(id|type|name)|rowid
	    #   prj  key|obj(id|type|name)
	    #   flt  key|id|type|name

	    [$db view location]       as fa
	    [$fa rename file:I key:I] as fb
	    [$fb project key obj]     as fc
	    [$fc flatten obj]         as fd
	} else {
	    # Db version 1 requires a different approach to generate
	    # the final view.

	    # 1     file|line|begin|size|end|file_path|parent|hasobj|rowid
	    #   ren  key|line|begin|size|end|file_path|parent|hasobj|rowid
	    #   ren  key|line|begin|size|end|file_path|parent|hasobj|locid
	    #   prj  key|locid
	    # 2    locid|id|type|name
	    #   joi  key|id|type|name

	    [$db view location]          as fa
	    [$fa rename file:I  key:I]   as fb
	    [$fb rename rowid:I locid:I] as fc
	    [$fc project key locid]      as ga

	    [$db view location_obj] as gb
	    [$ga join $gb locid]    as fd
	}

	return [$fd readonly]
    }

    method View/namespace_contents {} {
	# This is more complex. We have to go through the
	# command, variable, and namespace views, link them to
	# the containing namespace and then concat all the results.

	# Namespaces, db version independent ...
	# 1     name|parent|defn|usen|rowid|def(...)|use(...)
	#   prj name|parent|rowid
	#   ren name|key   |rowid
	#   ren name|key   |id
	#   prd name|key|id|'N'

	[$db view namespace]            as na
	[$na project name parent rowid] as nb
	[$nb rename parent:I key:I]     as nc
	[$nc rename rowid:I id:I]       as nd
	[$nd product [$db view typeN]]  as nresult

	# The command part depends on the version of the database.
	
	if {$dbversion == 0} {
	    # 2     name|defn|usen|rowid|def(...)|use(...)
	    #   prj name|def(...)|rowid|
	    #   ren name|def(...)|id
	    #   flt name|loc|type|prot|escope|origin|escope_str|origin_str|file_str|line|package|id
	    #   prj name|escope|id
	    #   ren name|key   |id
	    #   prd name|key|id|'C'

	    [$db view command]             as ca
	    [$ca project name def rowid]   as cb
	    [$cb rename rowid:I id:I]      as cc
	    [$cc flatten def]              as cd
	    [$cd project name escope id]   as ce
	    [$ce rename escope:I key:I]    as cf
	    [$cf product [$db view typeC]] as cresult

	} else {
	    # 2    name|defn|usen|defst|usest|rowid
	    #  prj name|rowid
	    # -    cmdid|loc|type|prot|escope|origin|escope_str|origin_str|file_path|line|package|id
	    #  prj escope|cmdid
	    #  ren escope|rowid
	    #  joi name|escope|rowid
	    #  ren name|escope|id
	    #  ren name|key   |id
	    #  prd name|key|id|'C'

	    [$db view command]             as ca
	    [$ca project name rowid]       as cb
	    [$db view command_def]         as da
	    [$da project escope cmdid]     as dc
	    [$dc rename cmdid:I rowid:I]   as dd
	    [$cb join $dd rowid]           as cd
	    [$cd rename rowid:I  id:I]     as ce
	    [$ce rename escope:I key:I]    as cf
	    [$cf product [$db view typeC]] as cresult
	}

	# Variables, db version independent ...
	# 3     name|type|sid|sloc|scope|fullname|defn|usen|rowid|...
	#   sel s.a restricted to type == 'N'
	#   prj name|sid|rowid
	#   ren name|key|rowid
	#   ren name|key|id
	#   prd name|key|id|'V'

	[$db view variable]            as va
	[$va select type N]            as vb
	[$vb project name sid rowid]   as vc
	[$vc rename sid:I key:I]       as vd
	[$vd rename rowid:I id:I]      as ve
	[$ve product [$db view typeV]] as vresult

	[$nresult concat $cresult] as ra
	[$ra      concat $vresult] as rb
	return [$rb readonly]
    }

    method View/cmd_contents {} {
	# Same code for DB v0 and v1, database independent

	[$db view variable]            as va
	[$va select type P]            as vb
	[$vb project name sid rowid]   as vc
	[$vc rename sid:I key:I]       as vd
	[$vd rename rowid:I id:I]      as ve
	[$ve product [$db view typeV]] as vresult

	return [$vresult readonly]
    }

    # ### ######### ###########################

    method View/list_namespace/use {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(use)
	} else {
	    set count $cursor(usen)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(usest)
	    set end   [expr {$start + $count - 1}]

	    [$db view namespace_use] as v
	    [$v range $start $end] as nu
	    [$self view file_for_join] as f
	    set view [$nu join $f file_path]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }
    method View/list_namespace/def {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(def)
	} else {
	    set count $cursor(defn)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(defst)
	    set end   [expr {$start + $count - 1}]

	    [$db view namespace_def] as v
	    [$v range $start $end]   as nd
	    [$self view file_for_join] as f
	    set view [$nd join $f file_path]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }
    method View/list_namespace/subns {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$cursor(name) eq "::"} {
	    set pattern {^::[^:]+(:[^:]+)*$}
	} else {
	    set pattern "^$cursor(name)::\[^:\]*(:\[^:\]+)*\$"
	}

	[$db view namespace]    as nsv
	return [$nsv select -regexp name $pattern]
    }
    method View/list_namespace/cmd {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$cursor(name) eq "::"} {
	    set pattern {^::[^:]+(:[^:]+)*$}
	} else {
	    set pattern "^$cursor(name)::\[^:\]*(:\[^:\]+)*\$"
	}

	[$db view command] as cmdv
	return [$cmdv select -regexp name $pattern]
    }
    method View/list_namespace/var {cursorvar} {
	upvar 1 $cursorvar cursor

	[$db view variable]     as varv
	[$varv     select type N] as allnsvar
	return [$allnsvar select sid $cursor(rowid)]
    }

    # ### ######### ###########################

    method View/list_variable/use {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(use)
	} else {
	    set count $cursor(usen)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(usest)
	    set end   [expr {$start + $count - 1}]

	    [$db view variable_use] as v
	    [$v range $start $end] as vu
	    [$self view file_for_join] as f
	    set view [$vu join $f file_path]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }
    method View/list_variable/def {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(def)
	} else {
	    set count $cursor(defn)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(defst)
	    set end   [expr {$start + $count - 1}]

	    [$db view variable_def] as v
	    [$v range $start $end] as vd
	    [$self view file_for_join] as f
	    set view [$vd join $f file_path]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }
    method View/list_variable/def/caller {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(call)
	} else {
	    set count $cursor(calln)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(callst)
	    set end   [expr {$start + $count - 1}]

	    [$db view variable_def_call] as v
	    set view [$v range $start $end]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }

    # ### ######### ###########################

    method View/list_cmd/use {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(use)
	} else {
	    set count $cursor(usen)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(usest)
	    set end   [expr {$start + $count - 1}]

	    [$db view command_use] as v
	    [$v range $start $end] as cu
	    [$self view file_for_join] as f
	    set view [$cu join $f file_path]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }
    method View/list_cmd/def {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(def)
	} else {
	    set count $cursor(defn)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(defst)
	    set end   [expr {$start + $count - 1}]

	    [$db view command_def] as v
	    [$v range $start $end] as cd
	    [$self view file_for_join] as f
	    set view [$cd join $f file_path]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }
    method View/list_cmd/var {cursorvar} {
	upvar 1 $cursorvar cursor

	[$db view variable]           as varv
	[$varv select type P]         as allcmdvar
	return [$allcmdvar select sid  $cursor(rowid)]
    }

    # ### ######### ###########################

    method View/list_package/use {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(use)
	} else {
	    set count $cursor(usen)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(usest)
	    set end   [expr {$start + $count - 1}]

	    [$db view package_use] as v
	    [$v range $start $end] as pu
	    [$self view file_for_join] as f
	    set view [$pu join $f file_path]
	}

	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }
    method View/list_package/def {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(def)
	} else {
	    set count $cursor(defn)
	    if {$count == 0} {
		return {}
	    }
	    set start $cursor(defst)
	    set end   [expr {$start + $count - 1}]

	    [$db view package_def] as v
	    [$v range $start $end] as pd
	    [$self view file_for_join] as f
	    set view [$pd join $f file_path]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }

    # ### ######### ###########################

    method View/list_location/obj {cursorvar} {
	upvar 1 $cursorvar cursor

	if {$dbversion == 0} {
	    set view $cursor(obj)
	} else {
	    [$db view location_obj] as v
	    set view [$v select locid $cursor(rowid)]
	}
	if {[$view size]} {
	    return $view
	} else {
	    return {}
	}
    }

    # ### ######### ###########################
}

# ### ######### ###########################
# Ready to go

package provide xrefdb 0.1
