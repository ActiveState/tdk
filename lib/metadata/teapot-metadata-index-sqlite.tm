# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::metadata::index::sqlite 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     snit
# Meta require     sqlite3
# Meta require     teapot::instance
# Meta require     teapot::listspec
# Meta require     teapot::reference
# Meta require     teapot::version
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview
# Perforce $Id$

# Copyright (c) 2006-2008 ActiveState Software Inc.

# snit::type for the generic management of meta data. This package
# manages the meta data of packages in a sqlite database. It is used
# by repository implementations which do not implement their own
# special meta data management.

# Current users are "repository::sqlitedir", "repository::local", and
# "repository::localma".  They basically differ in the way packages
# are stored on the disk.

# ### ### ### ######### ######### #########
## Requirements

package require fileutil              ; # Temp file and other utils.
package require logger                ; # Tracing
package require log
package require snit                  ; # OO core
package require sqlite3               ; # Database
package require teapot::reference     ; # Reference handling
package require teapot::instance      ; # Instance handling
package require teapot::listspec      ; # Spec handling
package require teapot::version       ; # Version/Requirement handling

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::teapot::metadata::index::sqlite
namespace eval        ::teapot::metadata::index::sqlite {
    ::variable revisioninfo
    array set  revisioninfo {
	name    TEAPOT
	version 0.2
	rcsid   {$Id$}
    }

    # Note: Keeping version at 0.2. Droppping 'dependencies' is an
    # incompatible change, but not visible. It becomes visible only to
    # teacups trying to write to an INDEX database. This happens only
    # for their local db. They are fine with cached databases. Going
    # to 0.3 would prevent use of new cached databases by older
    # teacups, which is ok.
    #
    # We should/could go to 0.3 only when teacup has code to upgrade
    # older databases.
}

snit::type ::teapot::metadata::index::sqlite {

    # ### ### ### ######### ######### #########
    ## API - Repository construction
    ##       (Not _object_ construction).

    typemethod new {location} {
	# Construct a repository in the specified location. The path
	# must not exist beforehand. It will exist after sucessful
	# completion of the command.

	if {[$type valid $location ro msg]} {
	    return -code error \
		"Cannot create repository index database at $location, already present."
	}

	file mkdir $location

	sqlite3      ${type}::TEMP [file nativename [$type index $location]]
	_setupTables ${type}::TEMP
	${type}::TEMP close
	return
    }

    typemethod index {path} {
	return [file join $path INDEX]
    }

    typemethod valid {path mode mv} {
	upvar 1 $mv message
	set idx [$type index $path]

	log::log debug "$type valid ${mode}($path) => $mv"
	log::log debug "=> index @ $idx"

	if {$mode eq "rw"} {
	    set mode efrw
	} elseif {$mode eq "ro"} {
	    set mode efr
	} else {
	    return -code error "Bad mode \"$mode\""
	}

	if {![fileutil::test $idx $mode message "Index database"]} {
	    return 0
	}

	log::log debug ".. index exists"

	set idx [file nativename $idx]
	if {[catch {sqlite3 ${type}::TEMP $idx} msg]} {
	    set message "File $idx: $msg"
	    return 0
	}

	log::log debug ".. index accessible to sqlite3"

	set ok [_hasTables ${type}::TEMP message]
	${type}::TEMP close

	log::log debug ".. index ok = $ok"
	return $ok
    }

    # ### ### ### ######### ######### #########
    ## API - Location of index (directory).
    ##       Filename is hardwired to "INDEX".
    ##     - Location of a journal file to keep.
    ##       Empty implies there is no journal.
    ##       The journal is only appended to.
    ##       An outside process is responsible
    ##       for truncating old entries.
    ##     - Readonly means that the journal is not written to.

    option -location -default {}
    option -journal  -default {} -readonly 1
    option -readonly -default 0  -readonly 1

    # ### ### ### ######### ######### #########

    ## First the methods which are not in the API core, but are used
    ## by full repositories to put meta data into the index, or to
    ## remove it from.

    method put {container sig} {
	# Keys in meta are expected to be in lower-case already, due
	# to mdparse.

	$self journalBegin
	$index transaction {
	    _removeInstance $index $container
	    _addInstance    $index $container $sig
	}
	$self journalCommit
	return
    }

    method get {opt instance} {
	if {![_exists $index $instance sig]} {
	    ::repository::api::complete $opt 1 "Instance \"$instance\" does not exist"
	}
	return $sig
    }

    method del {opt instance} {
	# Note that the instance -> signature mapping is separate from
	# the actual removal to allow us to recognize a missing
	# instance and properly report this as error.

	$index transaction {
	    if {[_exists $index $instance sig]} {
		$self journalBegin
		_remove $index $sig
		$self journalCommit
	    }
	}

	if {$sig eq ""} {
	    ::repository::api::complete $opt 1 "Instance \"$instance\" does not exist"
	}
	return $sig
    }

    method instance {sig} {
	return [_instance $index $sig]
    }

    method exists {instance sigvar} {
	upvar 1 $sigvar sig
	return [_exists $index $instance sig]
    }


    # ### ### ### ######### ######### #########
    ## Now the methods which can be directly called from the API core
    ## to query the index in various forms.

    method Require {opt instance} {
	# The instance -> signature mapping is separate from the
	# deletion to allow us to recognize a missing instance and
	# properly report this as error.

	# It would have been possible to use the instance data for the
	# search of meta data, but then we would not be able to
	# distinguish missing meta data (no error) from missing
	# instance.

	log::debug "Require <[join $instance "> <"]>"

	$index transaction {
	    if {[_exists $index $instance sig]} {
		log::debug "\tGet meta key Require"

		set res [_dep $index $sig require]
	    }
	}

	if {$sig eq ""} {
	    ::repository::api::complete $opt 1 "Instance \"$instance\" does not exist"
	} else {
	    ::repository::api::complete $opt 0 $res
	}
	return
    }

    method Recommend {opt instance} {
	# The instance -> signature mapping is separate from the
	# deletion to allow us to recognize a missing instance and
	# properly report this as error.

	# It would have been possible to use the instance data for the
	# search of meta data, but then we would not be able to
	# distinguish missing meta data (no error) from missing
	# instance.

	$index transaction {
	    if {[_exists $index $instance sig]} {
		set res [_dep $index $sig recommend]
	    }
	}

	if {$sig eq ""} {
	    ::repository::api::complete $opt 1 "Instance \"$instance\" does not exist"
	} else {
	    ::repository::api::complete $opt 0 $res
	}
	return
    }

    method Requirers {opt instance} {
	::repository::api::complete $opt 1 "Bad request requirers"
	return
    }

    method Recommenders {opt instance} {
	::repository::api::complete $opt 1 "Bad request recommenders"
    }

    method Find {opt platforms template} {
	::repository::api::complete $opt 0 [_find $index $platforms $template]
	return

    }

    method FindAll {opt platforms template} {
	::repository::api::complete $opt 0 [_findall $index $platforms $template]
	return
    }

    method Entities {opt} {
	$index transaction {
	    set entities [$index eval {
		SELECT DISTINCT name
		FROM instances
	    }]
	}

	::repository::api::complete $opt 0 $entities
	return
    }

    method Versions {opt entity} {
	set name [lindex $entity 0]

	$index transaction {
	    set tmp [$index eval {
		SELECT DISTINCT name, version
		FROM  instances
		WHERE name = $name
	    }]
	}

	::repository::api::complete $opt 0 [_zip_nv $tmp]
	return
    }

    method Instances {opt version} {
	foreach {n v} $version break

	$index transaction {
	    set tmp [$index eval {
		SELECT DISTINCT type, name, version, platform
		FROM  instances
		WHERE name    = $n
		AND   VEQUAL (version, $v)
	    }]
	}

	::repository::api::complete $opt 0 [_zip_tnvp $tmp]
	return
    }

    method Meta {opt spec} {
	::repository::api::complete $opt 0 [_meta $index $spec]
	return
    }

    method Meta/Direct {spec} {
	return [_meta $index $spec]
    }

    method Dump {opt} {
	::repository::api::complete $opt 0 [_dump $index]
	return
    }

    method Keys {opt {spec {0}}} {
	::repository::api::complete $opt 0 [_keys $index $spec]
	return
    }

    method List {opt {spec {0}}} {
	::repository::api::complete $opt 0 [_list $index $spec]
	return
    }

    method List/Direct {{spec {0}}} {
	return [_list $index $spec]
    }


    method Value {opt key spec} {
	# key is already lower-case, due to repository::api
	::repository::api::complete $opt 0 [_value $index $key $spec]
	return
    }

    method Value/Direct {key spec} {
	return [_value $index $key $spec]
    }

    method Search {opt query} {
	# Keys in queries are converted to lower-case during query translation.
	::repository::api::complete $opt 0 [_search $index $query]
	return
    }

    method Archs {opt} {
	::repository::api::complete $opt 0 [_archs $index]
	return
    }


    method verify {progresscmd} {
	set m [$index eval { PRAGMA integrity_check }]

	if {$m eq "ok"} { return 1 }
	foreach line $m {
	    uplevel #0 [linsert $progresscmd end error $line]
	}
	return 0
    }

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	$self configurelist $args

	if {$options(-location) eq ""} {
	    return -code error "No repository specified"
	}
	if {![$type valid $options(-location) ro msg]} {
	    return -code error "Not a repository: $msg"
	}

	sqlite3   ${selfns}::index [file nativename [$type index $options(-location)]]
	set index ${selfns}::index

	$index function VSATISFIES [myproc _vsatisfies]
	$index function VEQUAL     [myproc _vequal]
	$index function LIN        [myproc _listin]
	$index function LNI        [myproc _listni]
	$index function regexp     [myproc _regexp]

	$self journalInit
	return
    }

    destructor {
	catch {$index close}
	catch {close $jchan}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals ...

    variable index {}

    proc _vsatisfies {requirements v} {
	#package vsatisfies $v {expand}$requirements
	eval [linsert $requirements 0 package vsatisfies $v]
    }

    proc _vequal {base v} {
	expr {0 == [package vcompare $v $base]}
    }

    proc _listin {list element} {
	# element in list ?
	expr {
	      [lsearch -exact $list $element] < 0 ? 0 : 1
	  }
    }

    proc _listni {list element} {
	# element not in list ?
	expr {
	      [lsearch -exact $list $element] < 0 ? 1 : 0
	  }
    }

    proc _regexp {pattern string} {
	regexp -- $pattern $string
    }

    # ### ### ### ######### ######### #########
    ## Internal - List transformations

    proc _zip_tnvp {list} {
	set res {}
	foreach {t n v p} $list {
	    # No checking, we are assuming that we have valid instance
	    # data in the database.
	    lappend res [list $t $n $v $p]
	}
	return $res
    }

    proc _zip_tnvpi {list} {
	set res {}
	foreach {t n v p isprofile} $list {
	    # No checking, we are assuming that we have valid instance
	    # data in the database.

	    # Translate the old form of profiles to the new form in
	    # any type of search. This handles all already stored
	    # packages using the old form.

	    if {$isprofile && ($t eq "package")} {set t profile}
	    lappend res [list $t $n $v $p $isprofile]
	}
	return $res
    }

    proc _zip_nv {list} {
	set res {}
	foreach {n v} $list {
	    lappend res [list $n $v]
	}
	return $res
    }

    proc _zip_tnvpkv {list} {
	set res {}
	foreach {t n v p k va} $list {
	    lappend res [list $t $n $v $p $k $va]
	}
	return $res
    }

    proc _platselect {platforms list} {
	set tmp {}
	# The platform position is added to the element for sorting

	foreach e $list {
	    set pos [lsearch -exact $platforms [lindex $e 2]]
	    if {$pos < 0} continue
	    lappend e   $pos
	    lappend tmp $e
	}
	return $tmp
    }

    proc _strip5 {list} {
	set tmp {}
	foreach e $list {
	    lappend tmp [lrange $e 0 4]
	}
	return $tmp
    }

    proc _add5 {platforms list} {
	set tmp {}
	foreach e $list {
	    lappend e   [lsearch -exact $platforms [lindex $e 2]]
	    lappend tmp $e
	}
	return $tmp
    }

    # ### ### ### ######### ######### #########
    ## Internal - Database access layer

    proc _hasTables {index mv} {
	upvar 1 $mv message
	::variable revisioninfo

	# Check existence of all tables by name, and contents of the
	# version table.

	if {![llength [$index onecolumn {
	    SELECT name
	    FROM  sqlite_master 
	    WHERE type = 'table'
	    AND   name = 'teapot'
	}]]} {
	    set message "Revision information (Table TEAPOT) missing"
	    return 0
	}
	if {![llength [$index onecolumn {
	    SELECT name
	    FROM  sqlite_master 
	    WHERE type = 'table'
	    AND   name = 'instances'
	}]]} {
	    set message "Instance master (Table INSTANCES) missing"
	    return 0
	}
	if {![llength [$index onecolumn {
	    SELECT name
	    FROM  sqlite_master 
	    WHERE type = 'table'
	    AND   name = 'meta'
	}]]} {
	    set message "Meta data (Table META) missing"
	    return 0
	}
	if {[set got [lindex [$index onecolumn {
	    SELECT version
	    FROM  teapot
	    WHERE name = $revisioninfo(name)
	}] 0]] ne $revisioninfo(version)} {
	    set message "Expected revision \"$revisioninfo(version)\", got \"$got\""
	    return 0
	}
	return 1
    }

    proc _setupTables {index} {
	::variable revisioninfo

	# instances.file is the signature hash of the package file,
	# providing access to it in the associative storage module.
	#
	# Ditto meta.file

	$index transaction {
	    $index eval {
		CREATE TABLE teapot
		(  name      TEXT NOT NULL,
		   version   TEXT NOT NULL,
		   rcsid     TEXT NOT NULL
		   )
		;
		INSERT INTO teapot (name,                version,                rcsid)
		VALUES             ($revisioninfo(name), $revisioninfo(version), $revisioninfo(rcsid))
		;
		CREATE TABLE instances
		(  type      TEXT NOT NULL,
		   name      TEXT NOT NULL,
		   version   TEXT NOT NULL,
		   platform  TEXT NOT NULL,
		   isprofile INTEGER NOT NULL,
		   file	     TEXT NOT NULL,
		   PRIMARY KEY (type,name, version, platform),
		   UNIQUE (file)
		   )
		;
		CREATE TABLE meta
		(  file	 TEXT NOT NULL,
		   key	 TEXT NOT NULL,
		   value TEXT NOT NULL,
		   PRIMARY KEY (file, key)
		   )
		;
		CREATE INDEX meta_file
		ON           meta (file)
		;
	    }
	}
	return
    }

    proc _removeInstance {index container} {
	upvar 1 self self
	teapot::instance::split [$container instance] t n v p
	$index transaction {
	    # Instance argument. Version has to match string-exactly.
	    set sig [$index onecolumn {
		SELECT file FROM instances
		WHERE type     = $t
		AND   name     = $n
		AND   version  = $v
		AND   platform = $p
	    }]
	    if {$sig ne ""} {
		$index eval {
		    DELETE FROM meta         WHERE file = $sig;
		    DELETE FROM instances    WHERE file = $sig;
		}
		$self journalDelete $sig
	    }
	}
	return
    }

    proc _addInstance {index container sig} {
	upvar 1 self self
	teapot::instance::split [$container instance] t n v p
	array set md    [$container get]

	set t [teapot::entity::norm $t]

	# Special handling of the key 'profile', the marker for
	# profile packages. Denormalized storage for quick access.
	# Now we have to backward compat support that storage
	# form. Profiles are their entities now, can be detected
	# directly through their type. The old form is auto-magically
	# translated into the new form, canonical storage.

	# This handles all newly entering packages using the old form.

	set isprofile 0
	if {($t eq "package") && [info exists md(profile)]} {
	    set t profile
	    unset -nocomplain md(profile)
	    set isprofile 1
	} elseif {$t eq "profile"} {
	    set isprofile 1
	}

	$index transaction {
	    # Basic instance - file mapping

	    $index eval {
		INSERT INTO instances (type, name, version, platform, isprofile,  file)
		VALUES                ($t,   $n,   $v,      $p,       $isprofile, $sig)
	    }
	    $self journalInsert instances [list $t $n $v $p $isprofile $sig]

	    # Meta data, generic and special. The special keys are
	    # handled by forcibly adding them to the array,
	    # incidentially overwriting anything the user may have
	    # supplied. We do not allow the user to override these,
	    # they are reserved, like platform.
	    #
	    # The special keys are 'entity', 'name', and 'version'. To
	    # allow searches by this information as well. Not having
	    # search by name or version, or entity-type does not make
	    # sense.

	    set md(entity)  $t
	    set md(name)    $n
	    set md(version) $v

	    foreach {key val} [array get md] {
		$index eval {
		    INSERT INTO meta (file, key,  value)
		    VALUES           ($sig, $key, $val)
		}
		$self journalInsert meta [list $sig $key $val]
	    }
	}
	return
    }

    proc _exists {index instance {sigvar {}}} {
	if {$sigvar ne ""} {upvar 1 $sigvar sig}
	teapot::instance::split $instance t n v p
	set sig {}
	$index transaction {
	    # Instance argument. Version has to match string-exactly.
	    set sig [$index onecolumn {
		SELECT file FROM instances
		WHERE type     = $t
		AND   name     = $n
		AND   version  = $v
		AND   platform = $p
	    }]

	    if {($sig eq "") && ($t eq "profile")} {
		# In the case of searching for a profile look for an
		# old-style entry (type package + flag profile) as
		# well.

		set t package
		set sig [$index onecolumn {
		    SELECT file FROM instances
		    WHERE type      = $t
		    AND   name      = $n
		    AND   version   = $v
		    AND   platform  = $p
		    AND   isprofile = 1
		}]
	    }
	}

	expr {$sig ne ""}
    }

    proc _remove {index sig} {
	upvar 1 self self
	$index transaction {
	    $index eval {
		DELETE FROM meta         WHERE file = $sig;
		DELETE FROM instances    WHERE file = $sig;
	    }
	    $self journalDelete $sig
	}
	return
    }

    proc _dep {index sig key} {
	$index transaction {
	    set res [$index onecolumn {
		SELECT value
		FROM  meta
		WHERE file = $sig
		AND   key  = $key
	    }]
	}
	return $res
    }

    proc _instance {index sig} {
	$index transaction {
	    set instance [$index eval {
		SELECT type, name, version, platform
		FROM  instances
		WHERE file = $sig
	    }]
	}
	# The result of the query is implictly in the right order, so no
	# teapot::instance::cons
	return $instance
    }

    proc _findall {index platforms template} {
	log::debug "_findall $index ($platforms) ($template)"

	# Locate all packages matching a certain template. Versions in
	# the template are handled like 'package require' does.
	
	# ** Note **: 'platforms' is the _list_ of platform
	# identifiers a package may have to be acceptable to the
	# client making this request. The identifiers are listed from
	# most to least prefered. However a higher version has always
	# priority over a prefered platform. Platform preferences are
	# used only to sort identical versions.
	#
	# The sqlite documentation seems to indicate that it is not
	# possible to use the list of platform on the right side of
	# the IN operator. This part of the query is therefore handled
	# in Tcl, as a pre-processing step.

	# ** Note **: We use lsort over 'ORDER BY'. Only lsort has the
	# -dict option need for proper sorting of version numbers
	# (mixing numeric and alpha sort). Well, we could have defined
	# a new collation sequence through the tcl bindings of
	# sqlite. That would however most likely be slower, or as
	# slow, and I would have to define a comparison proc for a
	# -dict emulation in sqlite. Better to have it in C, via
	# lsort.

	# We can profile this later.

	set pl '[join $platforms ',']'

	# NOTE: With the change of references to allow multiple
	# requirements it is in priciple possible to collapse the
	# switch into a single case, 'version'. As all requirements
	# have a uniform syntax. The only reason to keep this
	# structure is that we can optimize the queries for the
	# different branches.

	switch -exact -- [teapot::reference::type $template n v] {
	    name {
		# Reference = (name)
		# Any version.

		set param "\$n = $n"
		set sql [string map [list @ $pl] {
		    SELECT type, name, version, platform, isprofile
		    FROM instances
		    WHERE name    = $n
		    AND   platform IN (@)
		}]
	    }
	    version {
		# Reference = (name -require R ...)
		# Old syntax  (name -version V ...)
		# Anything > version, but not a higher major version.
		# VSATISFIES - Tcl function!

		# Convert set of requirements from internal notation
		# into something which is acceptable to 'vsatisfies'.

		set v [teapot::reference::req2tcl $v]

		set param "\$n = $n, \$v = $v"
		set sql [string map [list @ $pl] {
		    SELECT type, name, version, platform, isprofile
		    FROM instances
		    WHERE name    = $n
		    AND   platform IN (@)
		    AND   VSATISFIES($v,version)
		}]
	    }
	    exact {
		# Reference = (name -require {v v})
		# Old syntax  (name -version v -exact 1)

		set param "\$n = $n, \$v = $v"
		set sql [string map [list @ $pl] {
		    SELECT type, name, version, platform, isprofile
		    FROM instances
		    WHERE name    = $n
		    AND   platform IN (@)
		    AND   VEQUAL (version, $v)
		}]
	    }
	}

	set etype [::teapot::reference::rawentity $template]
	if {$etype ne ""} {
	    append sql { AND type = $etype}
	}

	log::debug "parameters $param"
	log::debug "sql = $sql"

	$index transaction {
	    set matches [$index eval $sql]
	}

	log::debug "results = $matches"

	# Postprossing, in order ...
	# - zip n v p isprofile groups into quadruples
	# - add platform priority for sorting, smaller is better.
	# - sort by platform priority (idx 4)
	# - sort by version (idx 2, stable - keeps platform order).
	# - remove platform priority used for sorting

	return [_strip5 \
		    [lsort -dict -index 2 -increasing \
			 [lsort -integer -index 4 -increasing \
			      [_add5 $platforms \
				   [_zip_tnvpi $matches]]]]]
    }

    proc _find {index platform template} {
	# Locate the best [*] package matching a certain
	# template. Versions in the template are handled like 'package
	# require' does.
	#
	# [*] Best = Highest version number within the given
	#            constraints for the number.
	#
	# We use _findall and take the last entry. We have to,
	# because the final sorting through which we get the highest
	# version is done in Tcl, and cannot be done in SQL without
	# tricks (like special collation sequences).

	set res [_findall $index $platform $template]
	if {[llength $res]} {
	    return [list [lindex $res end]]
	} else {
	    return {}
	}
    }

    proc _dump {index} {
	set tmp [$index eval {
	    SELECT DISTINCT I.type, I.name, I.version, I.platform, M.key, M.value
	    FROM instances AS I, meta AS M
	    WHERE I.file = M.file
	}]

	return [_zip_tnvpkv $tmp]
    }

    proc _meta {index spec} {
	set spectype [teapot::listspec::split $spec e n v a]

	# Notes on the SQL where clauses
	#
	# * "I.file = M.file" is the join condition
	#   between instances I and meta M.
	#
	# * All other conditions just restrict
	#   the result set further based on the
	#   listspec given.

	switch -exact -- $spectype {
	    all - eall {
		return -code error "Bad spec"
	    }
	    name - ename {
		set q {
		    SELECT DISTINCT M.key, M.value
		    FROM instances AS I, meta AS M
		    WHERE I.file = M.file
		    AND   I.name = $n
		}
	    }
	    version - eversion {
		set q {
		    SELECT DISTINCT M.key, M.value
		    FROM instances AS I, meta AS M
		    WHERE I.file    = M.file
		    AND   I.name    = $n
		    AND   VEQUAL(I.version, $v)
		}
	    }
	    instance - einstance {
		# -> Version equality is string-exact.
		set q {
		    SELECT DISTINCT M.key, M.value
		    FROM instances AS I, meta AS M
		    WHERE I.file     = M.file
		    AND   I.name     = $n
		    AND   I.version  = $v
		    AND   I.platform = $a
		}
	    }
	}

	if {[string match e* $spectype]} {
	    append q "\nAND [_typeclause $e]\n"
	}

	$index transaction {
	    set tmp [$index eval $q]
	}

	# We may still have several values per key ... We merge them
	# into one value for the final dictionary to return.

	# See also mem.tcl, Meta

	array set res {}
	foreach {k v} $tmp {
	    if {[info exists res($k)]} {
		foreach e $v {lappend res($k) $e}
	    } else {
		set res($k) $v
	    }
	}
	return [array get res]
    }

    proc _value {index key spec} {
	# Key is already in lower-case due to the repository::api

	if 0 {
	    # Using general _meta ...

	    array set md [_meta $index $spec]
	    if {![info exists md($key)]} {return {}}
	    return $md($key)
	}

	# Instead of using meta and then plucking the requested value
	# out of the large dict we run our own queries, optimized to
	# return only the information truly needed.

	set spectype [teapot::listspec::split $spec e n v a]

	# General notes, see _meta above.

	switch -exact -- $spectype {
	    all - eall {
		return -code error "Bad spec"
	    }
	    name - ename {
		set q {
		    SELECT DISTINCT M.value
		    FROM instances AS I, meta AS M
		    WHERE I.file = M.file
		    AND   I.name = $n
		    AND   M.key  = $key
		}
	    }
	    version - eversion {
		set q {
		    SELECT DISTINCT M.value
		    FROM instances AS I, meta AS M
		    WHERE I.file    = M.file
		    AND   I.name    = $n
		    AND   VEQUAL (I.version, $v)
		    AND   M.key     = $key
		}
	    }
	    instance - einstance {
		# -> Version equality is string-exact.
		set q {
		    SELECT DISTINCT M.value
		    FROM instances AS I, meta AS M
		    WHERE I.file     = M.file
		    AND   I.name     = $n
		    AND   I.version  = $v
		    AND   I.platform = $a
		    AND   M.key      = $key
		}
	    }
	}

	if {[string match e* $spectype]} {
	    append q "\nAND [_typeclause $e]\n"
	}

	$index transaction {
	    set tmp [$index eval $q]
	}

	# We may still have several values for the key. Merge them
	# into one value for the final list to return.

	if {[llength $tmp] == 0} {return {}}
	if {[llength $tmp] == 1} {return [lindex $tmp 0]}

	set res [lindex $tmp 0]
	foreach v [lrange $tmp 1 end] {
	    foreach e $v {lappend res $e}
	}
	return $res
    }

    proc _typeclause {e} {
	if {$e eq "profile"} {
	    return {
		((I.type = $e) OR ((I.type = 'package') AND (I.isprofile = 1)))
	    }
	} elseif {$e eq "package"} {
	    return {
		((I.type = $e) AND (I.isprofile = 0))
	    }
	} else {
	    return {
		(I.type = $e)
	    }
	}
    }

    proc _list {index spec} {
	set spectype [teapot::listspec::split $spec e n v a]

	# Modify the queries based on the entity type, to properly
	# handle old and new forms of profiles.

	set q {
	    SELECT I.type, I.name, I.version, I.platform, I.isprofile
	    FROM  instances AS I
	}

	switch -exact -- $spectype {
	    all - eall {
	    }
	    name - ename {
		append q {
		    WHERE name = $n
		}
	    }
	    version - eversion {
		append q {
		    WHERE name    = $n
		    AND   VEQUAL (version, $v)
		}
	    }
	    instance - einstance {
		# Version equality is string-exact.
		append q {
		    WHERE name     = $n
		    AND   version  = $v
		    AND   platform = $a
		}
	    }
	}

	if {[string match eall $spectype]} {
	    append q "\nWHERE [_typeclause $e]\n"
	} elseif {[string match e* $spectype]} {
	    append q "\nAND [_typeclause $e]\n"
	}

	$index transaction {
	    set res [$index eval $q]
	}

	return [_zip_tnvpi $res]
    }

    proc _keys {index spec} {
	set spectype [teapot::listspec::split $spec e n v a]

	# General notes see _meta above.

	switch -exact -- $spectype {
	    all {
		set q  {
		    SELECT DISTINCT key
		    FROM meta
		}
	    }
	    eall {
		set q {
		    SELECT DISTINCT M.key
		    FROM instances AS I, meta AS M
		    WHERE I.file = M.file
		}
	    }
	    name - ename {
		set q {
		    SELECT DISTINCT M.key
		    FROM instances AS I, meta AS M
		    WHERE I.file = M.file
		    AND   I.name = $n
		}
	    }
	    version - eversion {
		set q {
		    SELECT DISTINCT M.key
		    FROM instances AS I, meta AS M
		    WHERE I.file    = M.file
		    AND   I.name    = $n
		    AND   VEQUAL (I.version, $v)
		}
	    }
	    instance - einstance {
		# Version equality is string-exact.
		set q {
		    SELECT DISTINCT M.key
		    FROM instances AS I, meta AS M
		    WHERE I.file     = M.file
		    AND   I.name     = $n
		    AND   I.version  = $v
		    AND   I.platform = $a
		}
	    }
	}

	if {[string match e* $spectype]} {
	    append q "\nAND [_typeclause $e]\n"
	}

	$index transaction {
	    set res [$index eval $q]
	}

	return $res
    }

    proc _archs {index} {
	$index transaction {
	    set res [$index eval {
		SELECT DISTINCT platform
		FROM instances
	    }]
	}
	return $res
    }

    proc _search {index query} {
	# Compile query into SQL WHERE condition, execute standard
	# query customized with that condition, and return the
	# results.

	set query  [_qrewrite $query]
	set select [_qtrans   $query]

	log::info "SQL = <$select>"

	$index transaction {
	    set tmp [$index eval $select]
	}

	return [_zip_tnvpi $tmp]
    }

    # ### ### ### ######### ######### #########
    ## Query translation i.e. Compilation
    ## Tcl (Nested List) -> SQL + Tcl (Command)

    proc _qrewrite {query} {

	# Term rewriting for proper handling of 'is' clauses. Because
	# of the two ways of specifying 'profile' entities these
	# clauses may now be compound queries. We have to do this
	# first so that the logic in the sql translator still works
	# (it assumes that compound queries are explicit, and before
	# the rewrite 'is' can be implicit compounds.

	set op  [lindex $query 0]

	switch -exact -- $op {
	    and - or {
		set res [list $op]
		foreach s [lrange $query 1 end] {
		    lappend res [_qrewrite $s]
		}
		return $res
	    }
	    nhaskey - haskey - key {
		return $query
	    }
	    is {
		set key [lindex $query 1]

		# The exact translation is type dependent.
		# 1. profile -> We accept packages as well,
		#    if they have the relevant marker.
		# 2. package -> We reject packages which have the
		#    profile marker.
		# We do this by replacing the term with a more complex one,
		# and recursing. To avoid infinite recursion we use special
		# types which are translated normally.

		if {$key eq "profile"} {
		    return {or
			{is profile}
			{and
			    {is package}
			    {haskey profile}}}

		} elseif {$key eq "package"} {
		    return {and 
			{is package} 
			{nhaskey profile}}
		}
		return $query
	    }
	    nis {
		set key [lindex $query 1]

		if {$key eq "profile"} {
		    # NOT a profile
		    # => type !profile && (type package -> nothaskey profile)
		    #    type !profile && (type !package || nothaskey profile)
		    return {and
			{nis profile}
			{or
			    {nis package}
			    {nhaskey profile}}}

		} elseif {$key eq "package"} {
		    # NOT a package
		    # -> type not package or (type package and haskey profile)

		    return {or
			{nis package} 
			{and
			    {is package}
			    {haskey profile}}}
		}
		return $query
	    }
	}
	error X
    }

    proc _qtrans {query} {

	# Query translation. While the regular client makes sure that
	# keywords are in lower-case in general we cannot assume
	# this. It might be an unofficial client doing the access. And
	# we have documented that comparison is case-insensitive, so
	# it is allowed to inject non-lowercase keywords.

	::variable sql

	# Translates a query expression into the equivalent SQL SELECT
	# statement.

	switch -exact -- [lindex $query 0] {
	    and {
		set res [_qtrans_compound $query INTERSECT]
	    }
	    or {
		set res [_qtrans_compound $query UNION]
	    }
	    haskey {
		set key [string tolower [lindex $query 1]]
		set res "$sql (M.key = '$key')"
	    }
	    nhaskey {
		set key [string tolower [lindex $query 1]]

		set res "
        SELECT DISTINCT I.type, I.name, I.version, I.platform, I.isprofile
	FROM instances AS I
	WHERE (0 = (SELECT COUNT(*) FROM meta AS M
                    WHERE M.key = '$key'
                    AND M.file = I.file))"
	    }
	    is {
		set key [lindex $query 1]
		set res "$sql (I.type = '$key')"
	    }
	    nis {
		set key [lindex $query 1]
		set res "$sql (I.type != '$key')"
	    }
	    key {
		foreach {__ key op val} $query break
		set key [string tolower $key]

		set guard "(M.key = '$key')"
		set vcond [_qtransop $key $op $val]
		set res "$sql ($guard AND $vcond)"
	    }
	}
	return $res
    }

    proc _qtrans_compound {query cop} {
	set e {}

	# Translation in two phases. First all simple sub-queries,
	# then any compound sub-queries. This moves any no-op select
	# statements as for to the back as possible.

	foreach sub [lrange $query 1 end] {
	    set es [_qtrans $sub]

	    set sop [lindex $sub 0]
	    if {($sop eq "and") || ($sop eq "or")} continue
	    lappend e $es
	}

	foreach sub [lrange $query 1 end] {
	    set es [_qtrans $sub]

	    set sop [lindex $sub 0]
	    if {($sop ne "and") && ($sop ne "or")} continue

	    # Wrap the nested compound statements into a no-op select
	    # to get around a limitation of sqlite with regard to
	    # nested compounds. We cannot use the parentheses
	    # directly.

	    set es "SELECT * FROM ($es)"
	    lappend e $es
	}

	return [join $e " $cop "]
    }


    proc _qtransop {key op val} {
	set res {}
	switch -exact -- $op {
	    eq    {set res "M.value = '$val'"}
	    ne    {set res "M.value != '$val'"}
	    glob  {set res "M.value GLOB '$val'"}
	    !glob {set res "M.value NOT GLOB '$val'"}
	    <     {set res "M.value < '$val'"}
	    >     {set res "M.value > '$val'"}
	    <=    {set res "M.value <= '$val'"}
	    >=    {set res "M.value >= '$val'"}
	    in    {set res "LIN(M.value,'$val')"}
	    ni    {set res "LNI(M.value,'$val')"}
	    rex   {set res "M.value REGEXP '$val'"}
	    !rex  {set res "M.value NOT REGEXP '$val'"}
	    default {
		return "Bad operator"
	    }
	}
	return ($res)
    }

    # ### ### ### ######### ######### #########
    ## Keeping a journal of changes

    variable jchan      {}
    variable hasjournal 0
    variable jserial    0

    method journalInit {} {
	set hasjournal 0
	if {($options(-journal) ne "") && !$options(-readonly)} {
	    set jchan [open $options(-journal) a]
	    set hasjournal 1
	}
	return
    }

    method journalBegin {} {
	if {!$hasjournal} return
	puts $jchan [list [clock seconds] $jserial begin_]
	incr jserial
    }

    method journalCommit {} {
	if {!$hasjournal} return
	puts $jchan [list [clock seconds] $jserial commit]
	incr jserial
    }

    method journalInsert {table data} {
	if {!$hasjournal} return
	puts $jchan [list [clock seconds] $jserial insert $table $data]
	incr jserial
	return
    }

    method journalDelete {what} {
	if {!$hasjournal} return
	puts $jchan [list [clock seconds] $jserial delete $what]
	incr jserial
	return
    }


    method Rejournal {} {
	if {!$hasjournal} return

	# Create a new journal by simply dumping the contents of the
	# INDEX.

	set savejchan $jchan
	set new   [fileutil::tempfile tpidx]
	set jchan [open $new a]


	$index transaction {
	    $index eval {
		SELECT type, name, version, platform, isprofile, file
		FROM   instances
	    } iv {
		$self journalBegin
		$self journalInsert instances [list $iv(type) $iv(name) $iv(version) $iv(platform) $iv(isprofile) $iv(file)]

		$index eval {
		    SELECT key, value
		    FROM   meta
		    WHERE  file = $iv(file)
		} md {
		    $self journalInsert meta [list $iv(file) $md(key) $md(value)]
		}

		$self journalCommit
	    }
	}

	# Rejournaling also vaccuums the database as we essentially
	# start cleanly from here on out.

	$index eval { VACUUM }

	close $jchan

	# Switch from old journal to the new

	close $savejchan
	file rename -force $options(-journal) $options(-journal).bak
	file rename -force $new               $options(-journal)
	$self journalInit
	return
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Constants and data structures

namespace eval ::teapot::metadata::index::sqlite {
    ::variable sql {
	SELECT DISTINCT I.type, I.name, I.version, I.platform, I.isprofile
	FROM instances AS I, meta AS M
	WHERE I.file = M.file AND
    }
    ::variable sqlb {
	SELECT DISTINCT I.type, I.name, I.version, I.platform, I.isprofile
	FROM instances AS I
	WHERE 
    }
}

# ### ### ### ######### ######### #########
## Ready
return
