# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::sqlitedir 0.1
# Meta platform    tcl
# Meta require     afs
# Meta require     fileutil
# Meta require     logger
# Meta require     repository::api
# Meta require     snit
# Meta require     teapot::metadata
# Meta require     teapot::metadata::index::sqlite
# Meta require     teapot::metadata::read
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview
# Copyright (c) 2007-2008 ActiveState Software Inc.

# snit::type for a hybrid repository (database + directory). This type
# of repository is not intended for use by a regular
# tclsh/wish. I.e. it cannot be used for a local installation
# repository.

# By basing this type on the 'repository::api' frontend package the
# code here does not have to perform argument checking. It can assume
# that the incoming arguments are ok.

# This also makes the processing of some errors faster as there is no
# dispatch through the event queue at all, but an immediate response.

# ### ### ### ######### ######### #########
## Requirements

package require afs                             ; # Assoc file store (content adressed, package files)
package require fileutil                        ; # File and path utilities
package require logger                          ; # Tracing
package require log
package require repository::api                 ; # Repository interface core 
package require teapot::metadata                ; # MD accessors
package require teapot::metadata::read          ; # MD extraction
package require teapot::metadata::index::sqlite ; # General MD index
package require snit                            ; # OO core

# ### ### ### ######### ######### #########
## Implementation

snit::type ::repository::sqlitedir {

    # ### ### ### ######### ######### #########
    ## API - Repository validation.

    # An opaque repository is represented by a r/w directory
    # containing a r/w file "teapot.sqlitedir.config", a r/w directory
    # "STORE" and a valid MM database (the meta data).

    method valid {mode mv} {
	upvar 1 $mv message
	return [$type valid $options(-location) $mode message]
    }

    typemethod label {} { return "Local Opaque" }

    typemethod valid {path mode mv} {
	upvar 1 $mv message
	set cfg [$type config $path]
	set str [$type store  $path]

	log::log debug "$type valid ${mode}($path) => $mv"
	log::log debug "=> config @ $cfg"
	log::log debug "=> store  @ $str"

	if {$mode eq "rw"} {
	    return [expr {
		  [fileutil::test $path edrw message "Repository"              ] &&
		  [fileutil::test $cfg  efrw message "Repository configuration"] &&
		  [fileutil::test $cfg  efrw message "Repository file-storage" ] &&
		  [teapot::metadata::index::sqlite valid $path rw       message]
	      }]
	} elseif {$mode eq "ro"} {
	    return [expr {
		  [fileutil::test $path edr message "Repository"              ] &&
		  [fileutil::test $cfg  efr message "Repository configuration"] &&
		  [fileutil::test $cfg  efr message "Repository file-storage" ] &&
		  [teapot::metadata::index::sqlite valid $path ro      message]
	      }]
	} else {
	    return -code error "Bad mode \"$mode\""
	}

	return
    }

    typemethod config {path} {
	return [file join $path teapot.sqlitedir.config]
    }

    typemethod store {path} {
	return [file join $path STORE]
    }

    # ### ### ### ######### ######### #########
    ## API - Repository construction
    ##       (Not _object_ construction).

    typemethod new {path} {
	if {[$type valid $path ro msg]} {
	    return -code error \
		"The chosen path \"$path\" already\
                 is a sqlitedir repository."
	}

	# Create the directory, a sqlite meta-data database, the
	# configuration file, and the directory for the data store.

	file mkdir                          $path
	::teapot::metadata::index::sqlite new                $path
	file mkdir            [$type store  $path]
	::fileutil::writeFile [$type config $path] {}
	return
    }

    # ### ### ### ######### ######### #########
    ## Special APIs to retrieve INDEX and Journal files
    ## They return the path to the requested file.
    ## Also a call to retrieve the Index timestamps.

    method INDEX {} {
	return [teapot::metadata::index::sqlite index $options(-location)]
    }

    method Journal {} {
	return [file join $options(-location) Journal]
    }

    variable imtime {}
    variable jmtime {}
    variable jfirst {}
    variable jlast  {}

    method IndexStatus {} {
	set imtime  [file mtime [$self INDEX]]
	set jmtimen [file mtime [$self Journal]]

	if {$jmtimen > $jmtime} {
	    set f [open [$self Journal] r]
	    set jfirst [lrange [gets $f] 0 1]
	    set jlast $jfirst
	    while {[gets $f line] >= 0} {
		# Handling broken lines by ignoring them.
		if {![catch {lrange $line 0 1} l]} {
		    set jlast $l
		}
	    }
	    close $f
	}
	set jmtime $jmtimen
	return [list $imtime $jmtime $jfirst $jlast]
    }

    delegate method Rejournal to index

    # ### ### ### ######### ######### #########
    ## API - Delegated to the generic frontend.

    delegate method * to API
    variable             API

    # ### ### ### ######### ######### #########
    ## API - Implementation.

    option -location {}

    ## These are the methods that are called from the generic frontend
    ## during dispatch.

    method Verify {opt progresscmd} {

	set err 0
	set code 0

	# 0. Check the integrity of the index, before trying to use
	#    it. Trouble there causes us to abort early.

	if {![$index verify $progresscmd]} {
	    repository::api::complete $opt 1 "1 problem found"
	    return
	}

	# 1. Get all instances, their paths, and check that the paths
	#    exist in the repository, and are readable. In case of a
	#    directory also check for a readable 'pkgIndex.tcl' file.

	foreach instance [$index List/Direct] {
	    $index exists $instance sig
	    set path [$fs path $sig]

	    if {![fileutil::test $path erf msg]} {
		set m "<$instance> bad: $msg"
		uplevel #0 [linsert $progresscmd end error $m]
		incr err
		set code 1
	    }
	}

	repository::api::complete $opt $code "$err problem[expr {$err == 1 ? "" : "s"}] found"
    }

    method Put {opt file} {
	set sig [$fs put $file new]

	# --==**<< NOTE >>**==--
	# Any error caught after the file has been inserted and is new
	# has to cause removal of the file, otherwise any further
	# attempt at adding it will shortcircuit without updating the
	# index.

	# Short path for instances which are fully identical to a
	# known file.

	if {!$new} {
	    ::repository::api::complete $opt 0 [$index instance $sig]
	    return
	}

	# ----------------------------------------------------

	set errors {}
	set fail [catch {
	    ::teapot::metadata::read::file $file single errors
	} msg]
	if {$fail || [llength $errors]} {
	    $fs remove $sig
	    if {!$fail} {set msg [join $errors \n]}
	    ::repository::api::complete $opt 1 $msg
	    return
	}

	# msg = list(object (teapot::metadata::container))/1
	# Single mode above ensure that at most one is present.

	set pkg [lindex $msg 0]

	# ----------------------------------------------------

	# Note: It is possible that this newly put instance overwrites
	# an existing one. Check for an existing instance, and delete
	# its file. Otherwise the abandoned file will clutter the
	# store and blow things up real fast.

	# Note 2: The generated Tcl Modules have a timestamp and thus
	# always a new signature, even if nothing else has
	# changed. With currently about 600 TMs we got a very good
	# example of the blowup we wish to avoid.

	set hasold [$index exists [$pkg instance] oldsig]
	$index put $pkg $sig
	if {$hasold} {$fs remove $oldsig}

	::repository::api::complete $opt 0 [$pkg instance]
	$pkg destroy
	return
    }

    method Get {opt instance file} {
	log::debug "$self Get $instance"
	log::debug "\t=> $file"
	log::debug "\tOpt ($opt)"

	set sig [$index get $opt $instance]
	# sig == "", index invoked 'api::complete' already.

	if {$sig ne ""} {
	    $fs copy $sig $file
	    ::repository::api::complete $opt 0 {}
	}
	return
    }

    method Del {opt instance} {
	# Note that the instance -> signature mapping is separate from
	# the actual removal to allow us to recognize a missing
	# instance and properly report this as error.

	set sig [$index del $opt $instance]
	# sig == "", index invoked 'api::complete' already.

	if {$sig ne ""} {
	    $fs remove $sig
	    ::repository::api::complete $opt 0 {}
	}
	return
    }

    method Path {opt instance} {
	$index exists $instance sig
	if {$sig eq ""} {
	    ::repository::api::complete $opt 1 \
		"Instance \"$instance\" does not exist"
	} else {
	    ::repository::api::complete $opt 0 [$fs path $sig]
	}
    }

    method Chan {opt instance} {
	if {![$index exists $instance sig]} {
	    ::repository::api::complete $opt 1 "Instance \"$instance\" does not exist"
	} else {
	    ::repository::api::complete $opt 0 [$fs get $sig]
	}
    }

    delegate method Require      to index
    delegate method Recommend    to index
    delegate method Requirers    to index ;# Bad request per idxsqlite
    delegate method Recommenders to index ;# Bad request per idxsqlite
    delegate method Find         to index
    delegate method FindAll      to index
    delegate method Entities     to index
    delegate method Versions     to index
    delegate method Instances    to index
    delegate method Meta         to index
    delegate method Dump         to index
    delegate method Keys         to index
    delegate method List         to index
    delegate method Value        to index
    delegate method Search       to index
    delegate method Archs        to index

    # ### ### ### ######### ######### #########
    ##

    option -readonly 0

    constructor {args} {
	$self configurelist $args
	set dir      $options(-location)
	set readonly $options(-readonly)

	if {$dir eq ""} {
	    return -code error "No repository directory specified"
	}

	# Even for a non-readonly repository we check for ro only
	# first.

	if {![$type valid $dir ro msg]} {
	    return -code error "Not a valid repository: $msg"
	}

	set location $dir
	set store    [$type store $dir]

	# Initialize API handler, data store, and meta data
	# management. The api object dispatches requests directly to
	# us.

	set API   [repository::api                 ${selfns}::API -impl     $self]
	set index [teapot::metadata::index::sqlite ${selfns}::MM  \
		       -location $dir \
		       -journal  [file join $dir Journal] \
		       -readonly $readonly]
	set fs    [::afs                           ${selfns}::FS $store]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals ...

    variable index {}
    variable fs    {}

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Register us at the central type auto-detection.

::repository::api registerForAuto ::repository::sqlitedir

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::repository::sqlitedir {
    logger::init                              repository::sqlitedir
    logger::import -force -all -namespace log repository::sqlitedir
}

# ### ### ### ######### ######### #########
## Ready
return
