# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::local 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     platform
# Meta require     platform::shell
# Meta require     repository::api
# Meta require     snit
# Meta require     teapot::metadata
# Meta require     teapot::metadata::index::sqlite
# Meta require     teapot::metadata::read
# Meta require     teapot::reference
# Meta require     teapot::repository::pkgIndex
# Meta require     zipfile::decode
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type for managing a local installation as a repository. The
# meta data of all packages is still stored in a sqlite database.
# Handles both Tcl Modules and general packages (stored in zip
# archives).

# The files of Tcl Modules are not put into an associative file
# storage, but into a directory hierarchy per the rules for Tcl
# Modules. Zip archives are unpacked and put into a directory branch
# separate from the TM's. For the general packages, and only them the
# repository also manages a global package index file for quick
# consumption by the Tcl package management code.

# DANGER / NOTE / SPECIALITY ______________

# The paths of .tm files encode package name and version, but nothing
# else. more bluntly, they do not contain information about the
# platform a Tcl module is for. Because of this packages stored in
# this type of repository are restricted to packages for one specific
# platform, and packages for platform '*' (i.e. all, i.e. pure Tcl
# packages).

# The platform for binary packages is set during creation and locked
# from then on.

# _________________________________________

# By basing this type on the 'repository::api' frontend package the
# code here does not have to perform argument checking. It can assume
# that the incoming arguments are ok.

# This also makes the processing of some errors faster as there is no
# dispatch through the event queue at all, but an immediate response.

# ### ### ### ######### ######### #########
## Requirements

package require fileutil                     ; # File and path utilities
package require logger                       ; # Tracing
package require platform                     ; # System identification
package require platform::shell              ; # s.a., shell details
package require repository::api              ; # Repository interface core 
package require teapot::metadata::index::sqlite ; # General MD index
package require snit                         ; # OO core
package require teapot::metadata             ; # MD accessors
package require teapot::metadata::read       ; # MD extraction
package require teapot::instance             ; # Instance handling
package require teapot::reference            ; # Reference handling
package require teapot::repository::pkgIndex ; # Global package index
package require zipfile::decode              ; # Zip archive expansion

# ### ### ### ######### ######### #########
## Implementation

snit::type ::repository::local {

    # ### ### ### ######### ######### #########
    ## API - Repository construction and validation.
    ##       (Not _object_ construction).

    typemethod new {location shell} {
	# shell = path of the tcl shell used to compute the
	# platform/architecture identifier for the repository we are
	# creating.

	if {[$type valid $location ro msg]} {
	    return -code error \
		"Cannot create local repository at $location, already present."
	}

	set arch [platform::shell::identify $shell]
	set plat [platform::shell::platform $shell]

	$type Create $location plat $arch $shell
	return
    }

    typemethod new-arch {location plat arch {shell {}}} {
	# shell = path of the tcl shell used to compute the
	# platform/architecture identifier for the repository we are
	# creating.

	if {[$type valid $location ro msg]} {
	    return -code error \
		"Cannot create local repository at $location, already present."
	}

	$type Create $location plat $arch $shell
	return
    }

    typemethod Create {location plat arch shell} {
	::teapot::metadata::index::sqlite new $location

	::fileutil::writeFile [file join $location ARCH] \
	    [list $plat $arch $shell]
	return
    }

    typemethod config {path} {
	return [file join $path ARCH]
    }

    typemethod valid {path mode mv} {
	upvar 1 $mv message
	set cfg [$type config $path]

	if {$mode eq "rw"} {
	    return [expr {
		  [fileutil::test $path edrw message "Repository"              ] &&
		  [fileutil::test $cfg  efrw message "Repository configuration"] &&
		  [teapot::metadata::index::sqlite valid $path rw       message]
	      }]
	} elseif {$mode eq "ro"} {
	    return [expr {
		  [fileutil::test $path edr message "Repository"              ] &&
		  [fileutil::test $cfg  efr message "Repository configuration"] &&
		  [teapot::metadata::index::sqlite valid $path ro      message]
	      }]
	} else {
	    return -code error "Bad mode \"$mode\""
	}

	return
    }

    # ### ### ### ######### ######### #########
    ## API - Delegated to the generic frontend.
    #
    ##       However, the methods for setting
    ##       and querying the platform code do
    ##       not go through the frontend.

    delegate method * to API
    variable             API

    # ### ### ### ######### ######### #########
    ## API - Implementation.

    option -location {} ; # Location of the repository in the filesystem.

    ## These are the methods that are called from the generic frontend
    ## during dispatch.

    method Put {opt file} {
	# Contrary to the regular sqlite/dir repository this
	# repository type has no short path to quickly determine if a
	# package is already present. It always has to extract the
	# full meta data from the uploaded file before it can make
	# that decision.

	# ----------------------------------------------------

	set errors {}
	set fail [catch {
	    ::teapot::metadata::read::file $file single errors type
	} msg]
	if {$fail || [llength $errors]} {
	    $fs remove $sig
	    if {!$fail} {set msg [join $errors \n]}
	    ::repository::api::complete $opt 1 $msg
	    return
	}

	# msg = list(object (teapot::metadata::container))/1
	# Single mode above ensure that at most one is present.

	set pkg      [lindex $msg 0]
	set meta     [$pkg get]
	set instance [$pkg instance]
	$pkg destroy

	# FUTURE - pass the object to the 'index' database.

	teapot::instance::split $instance _ n v p


	# ----------------------------------------------------
	# The main new thing to do here is to check if the platform
	# the uploaded package will run on matches the platform this
	# repository is for.

	if {[lsearch -exact $archpatterns $p] < 0} {
	    ::repository::api::complete $opt 1 \
		"Package installation aborted, \
                 platform \"$p\" does not match\
                 \"$archpatterns\""
	    return
	}

	# ----------------------------------------------------

	# Also different to repository::sqlitedir : Use require data
	# (on Tcl) to determine the base location for the file.

	# Installation is dependent on the type of the archive.

	set sig [_place/$type $base $file $n $v $meta]

	# The result is a path. It is unique and thus can take the
	# place of the sig'nature used by the sqlite/dir repository.

	# ----------------------------------------------------

	$index put $n $v $p $sig $meta

	::repository::api::complete $opt 0 $instance
	return
    }

    method Get {opt instance file} {
	set sig [$index get $opt $instance]

	if {$sig ne ""} {
	    file copy -force $sig $file
	    ::repository::api::complete $opt 0 {}
	}
	return
    }

    method Del {opt instance} {
	# Note that the instance -> signature mapping is separate from
	# the actual removal to allow us to recognize a missing
	# instance and properly report this as error.

	set sig [$index del $opt $instance]
	if {$sig ne ""} {
	    _remove $base $sig
	    ::repository::api::complete $opt 0 {}
	}
	return
    }

    method Path {opt instance} {
	$index exists $instance sig
	if {$sig eq ""} {
	    ::repository::api::complete $opt 1 "Instance \"$instance\" does not exist"
	} else {
	    ::repository::api::complete $opt 0 $sig
	}
    }

    method Chan {opt instance} {
	if {![$index exists $instance sig]} {
	    ::repository::api::complete $opt 1 "Instance \"$instance\" does not exist"
	} else {
	    ::repository::api::complete $opt 0 [open $sig r]
	}
    }

    delegate method Require      to index
    delegate method Recommend    to index
    delegate method Requirers    to index
    delegate method Recommenders to index
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

    # ### ### ### ######### ######### #########
    ## API - Implementation - Platform setting

    method {platform get id} {} {
	return $arch
    }

    method {platform get platform} {} {
	return $pl
    }

    method {platform get shell} {} {
	return $shell
    }

    method {platform patterns} {} {
	return $archpatterns
    }

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	$self configurelist $args

	if {$options(-location) eq ""} {
	    return -code error "Repository directory not specified"
	}
	if {![$type valid $options(-location) ro msg]} {
	    return -code error "Not a repository: $msg"
	}

	set afile    [$type config $options(-location)]
	set location $options(-location)

	# Initialize meta data management.
	# This may throw 'Not a repository' as well.

	set index [teapot::metadata::index::sqlite ${selfns}::MM \
		       -location $location]

	# The api object dispatches requests directly to us.

	set API [repository::api ${selfns}::API -impl $self]

	foreach {pl arch shell} [::fileutil::cat $afile] break
	set archpatterns [::platform::patterns $arch]
	set base         $location
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals ...

    variable index        {}
    variable shell        {}
    variable pl           {}
    variable arch         {}
    variable archpatterns {}
    variable afile        {}
    variable base         {}

    # ### ### ### ######### ######### #########
    ## Internal - File access, and placement.

    proc _remove {base path} {
	set libpath [fileutil::stripPath $base $path]
	switch -exact -- [lindex [file split $libpath] 0] {
	    teapot {
		file delete -force $path
	    }
	    lib {
		# FUTURE : Run a post-uninstallation script in the
		# archive.

		file delete -force $path

		# The path is for a general package based on a zip
		# archive. Update the global package index file.

		::teapot::repository::pkgIndex::remove $base [fileutil::stripN $libpath 1]
	    }
	}
	return
    }

    proc _place/tm {basedir file pname pver meta} {
	# Installation of a Tcl Module (.tm archive)

	# Place the package file into the installation. I.e. "install
	# the code".

	# Path is <base>/teapot/tclX/X.y/<pkg-version-encoded>.tm
	# X.y is determined via Require(Tcl).
	# If not present X.y = 8.4.

	::teapot::metadata::minTclVersion $meta -> maj min
	set tclver ${maj}.${min}

	set path [file join $basedir teapot \
		      tcl$maj $tclver \
		      [string map {:: /} $pname]-${pver}.tm
		     ]

	log::debug "Placed @ $path"

	file mkdir [file dirname $path]
	file copy -force $file $path
	return $path
    }

    proc _place/zip {basedir file pname pver meta} {
	# Installation of a Zip package (.zip archive)

	# Place the package file into the installation. I.e. "install
	# the code". This implies unpacking the archive into the
	# package path, and updating the global package index file.

	# FUTURE : Run a post-installation script in the archive.

	# Path is <base>/lib/<pkg-version-encoded>/
	# X.y determines the section of the global package index the
	# ifneeded statement will be put into.
	# X.y is determined via Require(Tcl).
	# If not present X.y = 8.4.

	set tclver [::teapot::metadata::minTclVersionMM $meta]
	set ppath  [string map {:: _ _ __} $pname]-${pver}
	set path   [file join $basedir lib $ppath]

	log::debug "Placed @ $path"

	#puts "/zip: $basedir $file $pname $pver $meta"
	#puts "/zip: Encoded $ppath"
	#puts "/zip: Placed  $path"
	#puts "/zip: Min Tcl $tclver"
	#puts "/zip: Mkdir ..."

	file mkdir [file dirname $path]

	#puts "/zip: Unzip   $file ..."

	zipfile::decode::open $file
	set zd [zipfile::decode::archive]
	zipfile::decode::unzip $zd $path
	zipfile::decode::close

	#puts "/zip: Update index"

	::teapot::repository::pkgIndex::insert $basedir $ppath $tclver

	return $path
    }

    # TODO - Use teapot::metadata commands here
    proc _mintclversion {meta} {
	array set md $meta
	if {![info exists md(Require)]} {return "8.4"}

	foreach ref $md(Require) {
	    if {[lindex $ref 0] ne "Tcl"} continue
	    switch -exact -- [teapot::reference::type $ref rn rv] {
		name {return "8.4"}
		version {
		    set rv [lindex [lindex $rv 0] 0]
		    set rev [split $rv .]
		    if {[llength $rv] > 1} {
			return [lrange $rv 0 1]
		    }
		    return [lindex $rv 0].0
		}
		exact {
		    set rev [split $rv .]
		    if {[llength $rv] > 1} {
			return [lrange $rv 0 1]
		    }
		    return [lindex $rv 0].0
		}
	    }
	}
	return "8.4"
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Register us at the central type auto-detection.

::repository::api registerForAuto ::repository::local

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::repository::local {
    logger::init                              repository::local
    logger::import -force -all -namespace log repository::local
}

# ### ### ### ######### ######### #########
## Ready
return
