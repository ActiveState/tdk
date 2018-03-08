# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::metadata::idxjournal 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     snit
# Meta require     sqlite3
# Meta require     teapot::instance
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview
# Perforce $Id$

# Copyright (c) 2007 ActiveState Software Inc.

# snit::type for a journal of installed packages. This package manages
# the journal in a sqlite database. It is used by repository
# implementations which do not implement their own special journaling.

# Current user is "repository::localma".

# ### ### ### ######### ######### #########
## Requirements

package require fileutil              ; # Temp file and other utils.
package require logger                ; # Tracing
package require snit                  ; # OO core
package require sqlite3               ; # Database
package require teapot::instance      ; # Instance handling

# ### ### ### ######### ######### #########
## Implementation

logger::initNamespace ::teapot::metadata::idxjournal
namespace eval        ::teapot::metadata::idxjournal {
    ::variable revisioninfo
    array set  revisioninfo {
	name    TEAPOT-JOURNAL
	version 0.1
	rcsid   {$Id$}
    }
}

snit::type ::teapot::metadata::idxjournal {

    # ### ### ### ######### ######### #########
    ## API - Repository construction
    ##       (Not _object_ construction).

    typemethod new {location} {
	# Construct a repository in the specified location. The path
	# must not exist beforehand. It will exist after sucessful
	# completion of the command.

	if {[$type valid $location ro msg]} {
	    return -code error \
		"Cannot create repository journal database at $location, already present."
	}

	file mkdir $location
	set fname [file nativename [$type journal $location]]

	# Touch to check write permissions
	close [open $fname w]

	# Create and fill as sqlite DB
	sqlite3      ${type}::TEMP $fname
	_setupTables ${type}::TEMP
	${type}::TEMP close
	return
    }

    typemethod journal {path} {
	return [file join $path INSTALLLOG]
    }

    typemethod valid {path mode mv} {
	upvar 1 $mv message
	set idx [$type journal $path]

	if {$mode eq "rw"} {
	    set mode efrw
	} elseif {$mode eq "ro"} {
	    set mode efr
	} else {
	    return -code error "Bad mode \"$mode\""
	}

	if {![fileutil::test $idx $mode message "Journal database"]} {
	    return 0
	}

	set idx [file nativename $idx]
	if {[catch {sqlite3 ${type}::TEMP $idx} msg]} {
	    set message "File $idx: $msg"
	    return 0
	}

	set ok [_hasTables ${type}::TEMP message]
	${type}::TEMP close
	return $ok
    }

    # ### ### ### ######### ######### #########
    ## API - Location of journal (directory).
    ##       Filename is hardwired to "JOURNAL".
    ##     - Location of a journal file to keep.
    ##       Empty implies there is no journal.
    ##       The journal is only appended to.
    ##       An outside process is responsible
    ##       for truncating old entries.
    ##     - Readonly means that the journal is not written to.

    option -location -default {}

    # ### ### ### ######### ######### #########

    typevariable acode -array {
	install 0
	remove  1
    }

    method add {instance action} {
	teapot::instance::split $instance e n v a
	set  ac  $acode($action)
	set  now [clock seconds]
	incr serial

	$journal transaction {
	    # This is needed to handle the possibility of rapid
	    # creation and destruction of repository (and thus
	    # journal) objects. I.e. if the code creates multiple
	    # objects per second all of them will start with serial
	    # number 1 within the same second, and the journal key
	    # becomes non-unique. Check for that and correct.
	    while {1} {
		if {[llength [$journal eval {
		    SELECT seconds, serial
		    FROM journal
		    WHERE seconds = $now
		    AND   serial  = $serial
		}]]} {
		    incr serial
		    continue
		}
		break
	    }
	    # Now we are sure that the key now/serial is unique.
	    $journal eval {
		INSERT
		INTO   journal
		VALUES ($now, $serial, $ac, $e, $n, $v, $a)
		;
	    }
	}
	return
    }

    method {list n} {n} {
	# Show the last n rows. -1 => all rows. Newest first.

	if {$n < 0} {
	    $journal transaction {
		set res [$journal eval {
		    SELECT J.seconds, J.serial, A.text, J.entity, J.name, J.version, J.arch
		    FROM journal J, action A
		    WHERE J.action = A.id
		    ORDER BY seconds DESC, serial DESC
		    ;
		}]
	    }   
	} else {
	    set res [$journal eval {
		SELECT J.seconds, J.serial, A.text, J.entity, J.name, J.version, J.arch
		FROM journal J, action A
		WHERE J.action = A.id
		ORDER BY seconds DESC, serial DESC
		LIMIT $n
		;
	    }]
	}

	return [_zip $res]
    }

    method {list since} {since} {
	# Show rows younger than or equal to seconds. Newest come first.

	set res [$journal eval {
	    SELECT J.seconds, J.serial, A.text, J.entity, J.name, J.version, J.arch
	    FROM journal J, action A
	    WHERE (J.action = A.id)
	      AND (J.seconds >= $since)
	    ORDER BY seconds DESC, serial DESC
	    ;
	}]

	return [_zip $res]
    }

    method {purge keep} {n} {
	# Delete all entries except for the last n ones.
	if {$n <= 0} {
	    $journal transaction {
		$journal eval {
		    DELETE
		    FROM journal;
		}
	    }   
	} else {
	    $journal transaction {
		# Check if the journal contains more than we wish to
		# keep. If yes we determine the key of the first row
		# to keep, and delete everything which comes before
		# it. (order is by seconds/serial, with oldest first
		# and youngest last).

		set have [$journal eval {
		    SELECT COUNT(*)
		    FROM journal
		    ;
		}]

		if {$have > $n} {
		    incr n -1 ; # OFFSET counts from zero.
		    foreach {sec ser} [$journal eval {
			SELECT seconds, serial
			FROM journal
			ORDER BY seconds DESC, serial DESC
			LIMIT 1 OFFSET $n
			;
		    }] break

		    # (sec,ser) is now the key of the first entry to
		    # keep. Anything older/before goes away.

		    $journal eval {
			-- Purge the majority of old entries first

			DELETE
			FROM journal
			WHERE seconds < $sec
			;

			-- Purge the small number of entries which
			-- had the same date+time but are older per
			-- their serial number.

			DELETE
			FROM journal
			WHERE (seconds = $sec)
			AND   (serial  < $ser);
			;
		    }
		}
	    }
	}

	return
    }

    method {purge before} {before} {
	# Delete all entries older than 'before'.

	$journal transaction {
	    $journal eval {
		DELETE
		FROM journal
		WHERE seconds < $before;
	    }
	}   
	return
    }

    proc _zip {list} {
	set res {}
	foreach {seconds serial action entity name ver arch} $list {
	    # No checking, we are assuming that we have valid data in
	    # the database.
	    lappend res [list $seconds $serial $action $entity $name $ver $arch]
	}
	return $res
    }

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	$self configurelist $args

	if {$options(-location) eq ""} {
	    return -code error "No repository specified"
	}
	if {![$type valid $options(-location) ro msg]} {
	    return -code error "Not a journaled repository: $msg"
	}

	sqlite3     ${selfns}::journal [file nativename [$type journal $options(-location)]]
	set journal ${selfns}::journal
	return
    }

    destructor {
	catch {$journal close}
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals ...

    variable journal {}
    variable serial  0

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
	    AND   name = 'journal'
	}]]} {
	    set message "Journal (Table JOURNAL) missing"
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
	# and   dependencies.file

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
		CREATE TABLE journal
		(  seconds   INTEGER NOT NULL, -- seconds since the epoch
		   serial    INTEGER NOT NULL, -- serial number per client invocation
		   action    INTEGER NOT NULL, -- reference to -> action
		   entity    TEXT NOT NULL,    -- entity type
		   name      TEXT NOT NULL,    -- entity name
		   version   TEXT NOT NULL,    -- entity version
		   arch      TEXT NOT NULL,    -- entity architecture
		   PRIMARY KEY (seconds, serial)
		   )
		;
		CREATE TABLE action
		(  id   INTEGER NOT NULL,
		   text TEXT NOT NULL,
		   PRIMARY KEY (id)
		   )
		;
		INSERT INTO action (id,text) VALUES (0, 'install');
		INSERT INTO action (id,text) VALUES (1, 'remove');
	    }
	}
	return
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Constants and data structures

namespace eval ::teapot::metadata::idxjournal {}

# ### ### ### ######### ######### #########
## Ready
return
