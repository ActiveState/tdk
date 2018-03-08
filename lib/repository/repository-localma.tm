# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::localma 0.1
# Meta platform    tcl
# Meta require     fileutil
# Meta require     logger
# Meta require     platform
# Meta require     platform::shell
# Meta require     repository::api
# Meta require     snit
# Meta require     teapot::instance
# Meta require     teapot::metadata
# Meta require     teapot::metadata::index::sqlite
# Meta require     teapot::metadata::read
# Meta require     teapot::package::gen::zip
# Meta require     teapot::repository::pkgIndex
# Meta require     zipfile::decode
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview
# Copyright (c) 2007-2010 ActiveState Software Inc.

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

# In contrast to 'repository::local' this package however is able to
# handle a multi-architecture repository. Initially only 'tcl'
# packages can be installed, but more architectures can be added
# incrementally to the repository.

# _________________________________________

# By basing this type on the 'repository::api' frontend package the
# code here does not have to perform argument checking. It can assume
# that the incoming arguments are ok.

# This also makes the processing of some errors faster as there is no
# dispatch through the event queue at all, but an immediate response.

# _________________________________________

# New feature: (Cisco, Bug 46111): A journal/log of the installed
# packages.

# This journal is NOT kept in the INDEX, but in a separate database
# (package idxjournal). Because in the future we may allow the export
# of a transparent repository over the network, and this means that
# the INDEX is made public. This new journal however is considered to
# be private/local information, not to be exported. Therefore is has
# to be kept out of the INDEX.

# ### ### ### ######### ######### #########
## Requirements

package require fileutil                        ; # File and path utilities
package require logger                          ; # Tracing
package require log
package require platform                        ; # System identification
package require platform::shell                 ; # s.a., shell details
package require repository::api                 ; # Repository interface core 
package require snit                            ; # OO core
package require teapot::instance                ; # Instance handling
package require teapot::metadata                ; # MD accessors
package require teapot::metadata::index::sqlite ; # General MD index
package require teapot::metadata::idxjournal    ; # MD install/remove journal
package require teapot::metadata::read          ; # MD extraction
package require teapot::package::gen::zip       ; # Regenerate zip-based packages
package require teapot::repository::pkgIndex    ; # Global package index
package require zipfile::decode                 ; # Zip archive expansion

# ### ### ### ######### ######### #########
## Implementation

snit::type ::repository::localma {

    option -readonly 0
    # For api compat, ignored.

    # ### ### ### ######### ######### #########
    ## API - Repository validation.

    # A multi-architecture local repository is represented by a r/w
    # directory containing a r/w file "teapot.local-ma.config" and a
    # valid MM database (the meta data).

    method valid {mode mv} {
	upvar 1 $mv message
	return [$type valid $base $mode message]
    }

    typemethod label {} { return "Local Installation" }

    typemethod valid {path mode mv} {
	upvar 1 $mv message
	set cfg [$type config $path]

	log::log debug "$type valid ${mode}($path) => $mv"
	log::log debug "=> config @ $cfg"

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

	# We are not checking if the log of installed packages
	# (idxjournal) is present. This part of the repository is
	# automatically created should it be missing when the
	# repository is opened for use.

	return 
    }

    typemethod config {path} {
	return [file join $path teapot.local-ma.config]
    }

    # ### ### ### ######### ######### #########
    ## API - Repository creation.
    ##       (Not _object_ construction).

    typemethod new {path} {
	if {[$type valid $path ro msg]} {
	    return -code error \
		"The chosen path \"$path\" already\
                 is a local repository for multiple\
                 architectures."
	}

	# Create the directory, a sqlite meta-data database, a sqlite
	# journal (of installed packages), and the configuration file.

	file mkdir                            $path
	::teapot::metadata::index::sqlite new $path
	::teapot::metadata::idxjournal    new $path
	::fileutil::writeFile [$type config $path] {}
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

    method Link {opt file instance meta artype} {
	# This method is special to 'localma'. The other classes,
	# except for the API do not implement it. It assumes that the
	# 'file' is a path to an installed package, be it Tcl Module
	# (File), or directory, in the local filesystem. This
	# repository will set a link to the file in the proper
	# location and store a copy of the meta-data.

	teapot::instance::split $instance t n v p
	set pkg [teapot::metadata::container %AUTO%]
	$pkg define $n $v $t
	$pkg set $meta ;# Sets platform implicitly

	# ----------------------------------------------------

	# The main new thing to do here is to check if the
	# architecture of the uploaded package matches any of
	# the architectures this repository can handle.

	if {![$self architecture valid $p]} {
	    ::repository::api::complete $opt 1 \
		"Package installation aborted, \
                 architecture \"$p\" does not match\
                 \"$archp\""
	    return
	}

	# ----------------------------------------------------

	# Also different to repository::sqlitedir : Use the meta-data
	# (Tcl dependency) to determine the base location for the
	# file. Installation is dependent on the type of the archive.

	set sig [Link/$artype $base $file $pkg]

	log::debug "Placed @ $sig"

	# The result is a unique path. This allows it to take the
	# place of the sig'nature used by the sqlite/dir repository.

	# ----------------------------------------------------

	$index put $pkg $sig
	::repository::api::complete $opt 0 [$pkg instance]
	$pkg destroy
	return

    }

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
	    set path [file join $base $sig]

	    if {
		![fileutil::test $path er msg] ||
		([file isdirectory $path] && ![fileutil::test $path/pkgIndex.tcl erf msg])
	    } {
		set m "<$instance> bad: $msg"
		uplevel #0 [linsert $progresscmd end error $m]
		incr err
		set code 1
	    }
	}

	# 2. Get all zip paths (See also RegenerateCLIP for the same),
	# and check that they correspond to packages known to the
	# repository.

	foreach basedir [glob -nocomplain -directory $base */*/lib] {
	    foreach dir [lsort -dict [glob -nocomplain -directory $basedir *]] {
		if {[file isfile $dir]} continue

		set ok [ExtractInstanceFromPath $dir -> entity name version parch abase _ _]
		if {!$ok} {
		    # Note: version is empty at this point, and name
		    # contains both name and version.
		    set m "<$entity $name$version $parch> bad: Has directory \"[join $abase /]\", but not found in the INDEX"
		    uplevel #0 [linsert $progresscmd end error $m]
		    incr err
		    set code 1
		}

	    }
	}

	repository::api::complete $opt $code "$err problem[expr {$err == 1 ? "" : "s"}] found"
    }

    proc ExtractInstanceFromPath {dir -> ev nv vv av dv pv sv} {
	upvar 1 $ev entity $nv name $vv version $av parch $dv abase $pv pkgdir $sv spec
	upvar 1 index index ; # instance data ...

	set abase [lrange [file split $dir] end-3 end]
	foreach {entity parch _ pkgdir} $abase break

	# This code has to be kept in sync with Path/Zip.  Split the
	# name/version string through digits. Do not give up if the
	# name is not found, but move characters from the version over
	# to the name, i.e. try all possible split positions, now (due
	# to change 285137) that we have no clear border between them
	# any longer.

	# Note: Old repositories may contain the old form of paths
	# still, so we have to keep our ability to process such.

	set ok 0

	if {[string match *-* $pkgdir]} {
	    set version [lindex [split $pkgdir -] end]
	    set name    [string map {__ _ _ ::} [join [lrange [split $pkgdir -] 0 end-1] -]]

	    if {![catch {
		set spec [teapot::listspec::einstance $entity $name $version $parch]
	    }]} {
		if {[llength [$index List/Direct $spec]]} {
		    set ok 1
		}
	    }
	}
	if {!$ok} {
	    regexp {^([-a-zA-Z_]*)(.*)$} $pkgdir -> name version

	    while {1} {
		# Exhausted possible versions, give up.
		if {$version eq ""} break

		# Split may be so wrong that the version has incorrect syntax.
		if {![catch {
		    set spec [teapot::listspec::einstance $entity [string map {__ _ _ ::} $name] $version $parch]
		}]} {
		    if {[llength [$index List/Direct $spec]]} {
			set ok 1
			break
		    }
		}

		# Try next split.
		append name [string index $version 0]
		set version [string range $version 1 end]
	    }
	}
	return $ok
    }

    method Put {opt file} {
	# ----------------------------------------------------

	# In contrast to 'repository::sqlitedir' this type has no
	# short path to quickly determine if a package is already
	# present. It always has to extract the full meta data from
	# the uploaded file before it can make that decision.

	# ----------------------------------------------------

	set errors {}
	set fail [catch {
	    ::teapot::metadata::read::file $file single errors artype
	} msg]
	if {$fail || [llength $errors]} {
	    if {!$fail} {set msg [join $errors \n]}
	    ::repository::api::complete $opt 1 $msg
	    return
	}

	# msg = list(object (teapot::metadata::container))/1
	# Single mode above ensure that at most one is present.

	set pkg [lindex $msg 0]

	# ----------------------------------------------------

	# The main new thing to do here is to check if the
	# architecture of the uploaded package matches any of
	# the architectures this repository can handle.

	set p [$pkg getfirst platform]
	if {![$self architecture valid $p]} {
	    $pkg destroy
	    ::repository::api::complete $opt 1 \
		"Package installation aborted, \
                 architecture \"$p\" does not match\
                 \"$archp\""
	    return
	}

	# ----------------------------------------------------

	# A previous installation of the package is removed.
	# Future: May have to run pre/post_uninstall scripts.

	if {[$index exists [$pkg instance] oldsig]} {
	    Delete $base $oldsig
	}

	# Also different to repository::sqlitedir : Use the meta-data
	# (Tcl dependency) to determine the base location for the
	# file. Installation is dependent on the type of the archive.

	# Here we do not need the details of the (everything after the
	# first -, if any).
	# Both 'tm-headers' and 'tm-mkvfs' reduce to 'tm'.

	regsub -- {-.*$} $artype {} artype
	set sig [Store/$artype $base $file $pkg]

	log::debug "Placed @ $sig"

	# The result is a unique path. This allows it to take the
	# place of the sig'nature used by the sqlite/dir repository.

	# ----------------------------------------------------

	$index   put $pkg $sig
	$journal add [$pkg instance] install ; # Bug 46111. Extend journal.

	::repository::api::complete $opt 0 [$pkg instance]
	$pkg destroy
	return
    }

    method Del {opt instance} {
	# Note that the instance -> signature mapping is separate from
	# the actual removal to allow us to recognize a missing
	# instance and properly report this as error.

	# [x] Ordering: Remove from pkgIndex.tcl file, then
	# filesystem, then from the INDEX database. Thus a failure in
	# the pkgIndex.tcl handling does not leave a reference to a
	# non-existent directory behind, breaking use of the
	# repository.

	# Failures in the filesystem and INDEX are no problem, users
	# already do not see the package any longer. Future attempts
	# just have to cleanup the later stages. And we have to acept
	# that early stages may already be done.

	# Another consequence, while we find the package in the index
	# database we have things to work on / clean up.

	if {![$index exists $instance sig]} {
	    ::repository::api::complete $opt 0 {}
	    return
	}
	# assert: sig ne ""

	Delete $base $sig
	$index del $opt $instance
	$journal add $instance remove ; # Bug 46111. Extend journal.

	::repository::api::complete $opt 0 {}
	return
    }

    method Get {opt instance file} {
	log::debug "$self Get $instance"
	log::debug "\t=> $file"
	log::debug "\tOpt ($opt)"

	set sig [$index get $opt $instance]
	# sig == "", index invoked 'api::complete' already.

	if {$sig ne ""} {
	    Retrieve $index $base $sig $instance $file
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
	    ::repository::api::complete $opt 0 \
		[file join $base $sig]
	}
    }

    method Chan {opt instance} {
	if {![$index exists $instance sig]} {
	    ::repository::api::complete $opt 1 \
		"Instance \"$instance\" does not exist"
	} else {
	    set path [file join $base $sig]

	    switch -exact -- [Type $sig] {
		teapot {
		    # TM - Just open the file.
		    set chan [open $path r]
		}
		lib {
		    # ZIP. Regenerate the archive from the directory
		    # and open that. We reuse the backend code for
		    # 'Get' here.

		    # NOTE: It is assumed that whoever is using the
		    # channel does additional work to determine
		    # whether it should delete the file behind the
		    # channel or not. This is possible by asking for
		    # the 'Path' as well, and if it is a directory
		    # then the 'Chan' result has to be a tempfile to
		    # delete after use.

		    set t [fileutil::tempfile]
		    Retrieve/lib $index $path $instance $t
		    set chan [open $t r]
		}
	    }

	    ::repository::api::complete $opt 0 $chan
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
    ## API - Query architecture and related information.

    method {log show all} {} {
	return [$journal list n -1]
    }

    method {log show n} {n} {
	return [$journal list n $n]
    }

    method {log show since} {since} {
	return [$journal list since $since]
    }

    method {log purge all} {} {
	return [$journal purge keep 0]
    }

    method {log purge keep} {n} {
	return [$journal purge keep $n]
    }

    method {log purge before} {before} {
	return [$journal purge before $before]
    }

    method {architecture list} {} {
	return [array names arch]
    }

    method {architecture ok} {a} {
	return [info exists arch($a)]
    }

    method {architecture platform} {a} {
	return [lindex $arch($a) 0]
    }

    method {architecture shells} {a} {
	foreach {_ shells} $arch($a) break
	array set sh $shells
	# FUTURE: struct::list map NORM
	set res {}
	foreach s [array names sh] {
	    lappend res [NORM $s]
	}
	return [lsort -unique $res]
    }

    proc NORM {f} {
	if {$::tcl_platform(platform) eq "windows"} {
	    return [string tolower [file nativename [file normalize $f]]]
	} else {
	    return [file nativename [file normalize $f]]
	}
    }

    method {architecture valid} {a} {
	return [expr {[lsearch -exact $archp $a] < 0 ? 0 : 1}]
    }

    method {architecture patterns} {} {
	return $archp
    }

    method {architecture default} {} {
	# Determine the architecture of the host we are on, using the
	# shells recorded in the local repository.

	foreach a [array names arch] {
	    array set shells [lindex $arch($a) 1]
	    foreach sh [array names shells] {
		if {![file exists     $sh]} continue
		if {![file executable $sh]} continue
		if {[catch {
		    set ax [platform::shell::identify $sh]
		}]} continue

		# The shell identifies the platform differently than
		# it is registered for. This is possible in a
		# multi-platform setup where the filesystem maps
		# different shells to the same location, dependent on
		# the acessing host and its platform. Example: Cisco.
		# Ignore such a shell.

		if {$a ne $ax} continue
		return $a
	    }
	    unset shells
	}
	# Failed to determine a default.
	return {}
    }

    # ### ### ### ######### ######### #########
    ## API - Connect object to a repository on disk.

    constructor {args} {
	$self configurelist $args

	set dir $options(-location)
	if {$dir eq ""} {
	    return -code error "No repository directory specified"
	}
	if {![$type valid $dir ro msg]} {
	    return -code error "Not a multi-architecture local repository: $msg"
	}

	# Check if the journal is present. If not we create it here,
	# automatically.  However if that fails we do error out as if
	# the repository had not been valid from the beginning.

	if {
	    ![teapot::metadata::idxjournal valid $dir ro msg] &&
	    [catch {teapot::metadata::idxjournal new $dir} jmsg]
	} {
	    set msg "Journal database: Does not exist, and cannot be created\n\t$jmsg"
	    return -code error "$dir: Not a multi-architecture local repository: $msg"
	}

	set       base   $dir
	set       config [$type config $base]
	array set arch   [::fileutil::cat $config]

	# Initialize API handler and meta data management.
	# The api object dispatches requests directly to us.

	set API     [repository::api                 ${selfns}::API -impl     $self]
	set index   [teapot::metadata::index::sqlite ${selfns}::MD  -location $base]
	set journal [teapot::metadata::idxjournal    ${selfns}::PJ  -location $base]

	$self SetupPatterns
	return
    }

    destructor {
	if {$API     ne ""} {$API     destroy}
	if {$index   ne ""} {$index   destroy}
	if {$journal ne ""} {$journal destroy}
    }

    # ### ### ### ######### ######### #########
    ## API - Extend number of architectures handled by the
    ##       repository.

    method add-shell {shell} {
	set shell [NORM $shell]
	set architecture [platform::shell::identify $shell]
	set platform     [platform::shell::platform $shell]

	if {![info exists arch($architecture)]} {
	    set arch($architecture) \
		[list $platform [list $shell 1]]
	} else {
	    foreach {p shells} $arch($architecture) break
	    array set sh $shells

	    if {![info exists sh($shell)]} {
		set  sh($shell) 1
	    } else {
		incr sh($shell)
	    }

	    set arch($architecture) \
		[list $p [array get sh]]
	}

	::fileutil::writeFile $config [array get arch]
	$self SetupPatterns
	return
    }

    method remove-shell {shell} {
	if {![array size arch]} return

	# We scan and modify all architectures in our search for the
	# shell. It is more work than identifying the architecture and
	# acessing only that, but also required work, for two reasons:
	# (1) The shell might not exist anymore, thus making us unable
	# to infer its architecture, and (2) it may (wrongly) be
	# listed under multiple architectures. Doing the removal this
	# way thus handles missing shells gracefully, and will cleanup
	# a bad data structure as well.

	set shell [NORM $shell]

	foreach architecture [array names arch] {
	    foreach {p shells} $arch($architecture) break
	    array set sh $shells
	    foreach s [array names sh] {
		if {[NORM $s] ne $shell} continue
		# Shell is present. Remove. Unset keys as needed.
		unset sh($s)
	    }
	    if {[array size sh]} {
		set arch($architecture) [list $p [array get sh]]
	    } else {
		# Last shell for the architecture is gone.
		unset arch($architecture)
	    }
	}

	::fileutil::writeFile $config [array get arch]
	$self SetupPatterns
	return
    }

    method has-shell {shell} {
	if {![array size arch]} {return 0}

	set architecture [platform::shell::identify $shell]
	if {![info exists arch($architecture)]} {return 0}

	set shell [NORM $shell]

	foreach {p shells} $arch($architecture) break
	array set sh {}
	foreach {s x} $shells {
	     set sh([NORM $s]) $x
	}

	if {![info exists sh($shell)]} {return 0}
	return 1
    }

    # ### ### ### ######### ######### #########
    ## Internal - Helper for architecture data.

    method SetupPatterns {} {
	array set _ {}
	set issues {}
	foreach a [array names arch] {
	    if {[catch {
		set patterns [platform::patterns $a]
	    }]} {
		lappend issues $a
	    } else {
		foreach p $patterns {
		    set _($p) .
		}
	    }
	}

	if {[llength $issues]} {
	    return -code error -errorcode LOCALMA \
		"Found bad platform names in configuration file $config: [join $issues {, }].\nPlease correct these."
	}

	set archp [array names _]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals - Data structures

    variable index        {}
    variable journal      {}
    variable base         {}
    variable config       {}
    variable arch -array  {}
    variable archp        {}

    # arch = array (architecture -> list (platform, dict (path -> count)))
    # path = path of a shell

    # ### ### ### ######### ######### #########
    ## Internal - Placement of packages, actual file access.

    proc Type {sig} {
	foreach {entity arch type} [file split $sig] break
	return $type
    }

    method artype {path} {
	# Determine the type of the original package archive file from
	# the path of the package into a 'localma'-repository. ... 

	switch -exact -- [Type [fileutil::stripPath $base $path]] {
	    teapot  {return tm}
	    lib     {return zip}
	    default {return -code error "Bad source path, cannot determine format of original archive file"}
	}
    }

    # General directory structure of the repository:

    # tm:  BASE/<ENTITY>/<ARCH>/teapot/tclX/X.y/<pkg+version-encoded>.tm
    # zip: BASE/<ENTITY>/<ARCH>/lib/<pkg+version>/
    #                                             pkgIndex.tcl
    #                                             pkgIndex.index
    #      0    1        2      3

    proc Delete {base sig} {
	# sig is relative to base
	foreach {entity arch type} [file split $sig] break
	set src [file join $base $sig]

	switch -exact -- $type {
	    teapot {
		file delete -force $src
	    }
	    lib {
		# See [x] for explanation of the ordering.

		# The path is for a general package based on a zip
		# archive. Update the global package index file.

		set basedir [file join $base $entity $arch lib]
		if {![::teapot::repository::pkgIndex::update $basedir modified {
		    ::teapot::repository::pkgIndex::remove $basedir \
			[fileutil::stripN $sig 3]
		} msg]} {
		    return -code error $msg
		}

		# Now remove it from the filesystem as well.

		file delete -force $src

		# FUTURE : Run a post-uninstallation script in the
		# archive.
	    }
	}
	return
    }

    proc Retrieve {index base sig instance dst} {
	Retrieve/[Type $sig] $index [file join $base $sig] $instance $dst
    }

    proc Retrieve/teapot {index src instance dst} {
	file copy -force $src $dst
    }

    proc Retrieve/lib {index src instance dst} {
	# Similar to package generation, generate a zip archive on the
	# fly, put the separately stored package files and their meta
	# data back together.

	# We use a variant of the general zip generator backend. The
	# minimal Tcl version, load command, etc. are all already
	# encoded in the pkgIndex.tcl file found in the package
	# directory.

	set meta [$index Meta/Direct [::teapot::instance::2spec $instance]]

	teapot::instance::split $instance t n v a
	set p [teapot::metadata::container %AUTO%]
	$p define $n $v $t
	$p set $meta

	::teapot::package::gen::zip::repack $p $src $dst
	return
    }

    proc Path/tm {basedir file pkg} {
	# Per the repository directory structure the path for this
	# package is
	#
	#     BASE/ENTITY/ARCH/teapot/tclX/X.Y/PKG.tm	Package
	#          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ sig
	#
	#     BASE/ENTITY/ARCH/teapot/PKG.tm		Other
	#          ~~~~~~~~~~~~~~~~~~~~~~~~~ sig
	#
	# BASE:   basedir | Repository top directory.
	# ENTITY: package|application, type of the entity
	# ARCH:   parch   | Package architecture
	# X.Y:    Minimal Tcl Version the package can run with.
	# PKG:    package name+version coded into a path (TIP #???)

	teapot::instance::split [$pkg instance] entity pname pver parch

	if {$entity eq "package"} {
	    ::teapot::metadata::minTclVersion [$pkg get] -> major minor

	    set maj tcl$major
	    set min ${major}.${minor}
	    set pkg [string map {:: /} $pname]-${pver}.tm

	    set sig  [file join $entity $parch teapot $maj $min $pkg]
	} else {
	    set pkg [string map {:: /} $pname]-${pver}.tm
	    set sig [file join $entity $parch teapot $pkg]
	}

	set path [file join $basedir $sig]

	return [list $path $sig]
    }

    proc Link/tm {basedir file pkg} {
	foreach {path sig} [Path/tm $basedir $file $pkg] break

	file mkdir [file dirname $path]
	file link -symbolic $path $file

	return $sig
    }

    proc Store/tm {basedir file pkg} {
	# Upload/Installation of a Tcl Module (.tm archive).

	log::debug "Store/tm @ $basedir | $file | $pkg"

	foreach {path sig} [Path/tm $basedir $file $pkg] break

	log::debug "    path @ $path"
	log::debug "    sig  @ $sig"

	file mkdir [file dirname $path]
	file copy -force $file $path

	# Force readable for unix. Executable is not needed for
	# packages. All Tcl Modules are activated via 'source'. Binary
	# stuff, like shared libraries have to be prepared by the
	# sourced header, this will have to set any necessary
	# permissions.

	# For applications we need the 'executable', be they tcl
	# script, starkit, or starpack.

	teapot::instance::split [$pkg instance] entity _ _ _

	if {$::tcl_platform(platform) ne "windows"} {
	    file attributes $path -permissions ugo+r
	    if {$entity eq "application"} {
		file attributes $path -permissions ugo+x

		# Future: Make writable if a starkit and header
		# signals that writing is possible (starkit::header
		# mk4 -nocommit).
	    }
	}

	return $sig
    }

    proc Path/zip {basedir file pkg} {
	# Upload/Installation of a Zip package (.zip archive).
	# Zip archives are not copied, but unpacked into a
	# unique directory.

	# Per the repository directory structure the path for this
	# package is
	#
	#     BASE/ENTITY/ARCH/lib/PKG
	#          ~~~~~~~~~~~~~~~~~~~ sig
	#
	# BASE: basedir | Repository top directory.
	# ARCH: parch   | Package architecture
	# PKG:  (NAME)(VERSION)

	# Changed from NAME-VERSION. This change doesn't affect any
	# existing package and their directories, only newly installed
	# packages. It was made to support old packages which are
	# using tcl_findLibrary, and are unable to find themselves.
	# They look for (NAME)(VERSION), and do not find the form
	# NAME-VERSION. See bug 73883.

	# NOTE: Keep the procedure 'ExtractInstanceFromPath' in sync
	# with the format of the path used here. Bug 76678 was caused
	# by not doing this.

	set mtv [::teapot::metadata::minTclVersionMM [$pkg get]]
	teapot::instance::split [$pkg instance] entity pname pver parch

	set pkgdir [string map {:: _ _ __} $pname]${pver}
	set sig    [file join $entity $parch lib $pkgdir]
	set path   [file join $basedir $sig]

	return [list $path $sig $mtv $pkgdir]
    }

    proc Link/zip {basedir file pkg} {
	foreach {path sig mtv pkgdir} [Path/zip $basedir $file $pkg] break

	# NOTE : We CANNOT run a post-installation script here.
	#        It was already run by the archive we link to and
	#        has imprinted the package on the directory.

	# So, linking to binary patched packages is something the
	# package itself has to allow. The repository cannot help any
	# further.

	set abase  [file dirname $path]
	file mkdir $abase
	file link -symbolic $path $file

	if {![::teapot::repository::pkgIndex::update $abase modified {
	    ::teapot::repository::pkgIndex::insert $abase $pkgdir $mtv
	} msg]} {
	    return -code error $msg
	}

	return $sig
    }

    proc Store/zip {basedir file pkg} {
	log::debug "Store/zip @ $basedir | $file | $pkg"

	foreach {path sig mtv pkgdir} [Path/zip $basedir $file $pkg] break

	log::debug "     path @ $path"
	log::debug "     sig  @ $sig"
	log::debug "     mtv  @ $mtv"
	log::debug "     pkgd @ $pkgdir"

	# FUTURE : Run a post-installation script in the package
	#          directory after the unpacking has been done.

	set abase        [file dirname $path]
	file mkdir       $abase

	# Put the files into the dir structure first.

	zipfile::decode::unzipfile $file $path

	# Then update the pkgIndex.tcl, this makes the package usable
	# to linked tcl shells.

	if {![::teapot::repository::pkgIndex::update $abase modified {
	    ::teapot::repository::pkgIndex::insert $abase $pkgdir $mtv
	} msg]} {
	    return -code error $msg
	}

	# Force executable for platforms which may need it (example
	# hpux, and file is shared library with vfs or some such).
	# Additionally force readable for everyone.

	if {$::tcl_platform(platform) ne "windows"} {
	    foreach f [fileutil::find $path] {
		file attributes $f -permissions ugo+rx
	    }
	}

	return $sig
    }

    method RegenerateCLIPs {logcmd} {
	foreach basedir [glob -nocomplain -directory $base */*/lib] {
	    $self RegenerateCLIP $basedir $logcmd
	}
	return
    }

    method RegenerateCLIP {basedir logcmd} {
	eval [linsert $logcmd end "Regenerating CLIP in $basedir"]

	# Regenerate (and thus possibly repair) broken CLIP files
	# (pkgIndex.tcl files in the */*/lib directories).

	# We get the names, versions, entity types and architectures
	# of the zip installed packages from the filesystem, use that
	# to retrive the associated requirements, needed for the
	# minTclVersion. These actions are essentially an inlined and
	# simplified Path/zip, to avoid unnecessary type conversions,
	# and retrieval of unneeded data.

	if {![::teapot::repository::pkgIndex::update $basedir generated {
	    # Note: There is a subtle interaction here. By sorting by
	    # name and version the highest version of any package is
	    # handled last in the loop, causing it to appear before
	    # the older versions as the insert process puts new
	    # packages at the beginning of its section.

	    ::teapot::repository::pkgIndex::clear $basedir
	    foreach dir [lsort -dict [glob -nocomplain -directory $basedir *]] {
		# dir = repobase/*/*/lib/*
		# ignore files.
		if {[file isfile $dir]} continue

		set ok [ExtractInstanceFromPath $dir -> entity name version parch _ pkgdir spec]

		eval [linsert $logcmd end "* $name $version"]

		if {!$ok} {
		    eval [linsert $logcmd end "  Removed from index, is not registered with the repository"]
		    continue
		}

		# Note: It is possible that we do not find 'require'
		# in the meta data: Broken meta data, unregistered
		# packages, ... In that case we assume 8.4, per
		# minTclVersionMM. Truly missing packages are ignored,
		# i.e. implicitly removed from the generated index.
		# See -> verify as well.

		::teapot::repository::pkgIndex::insert $basedir $pkgdir \
		    [::teapot::metadata::minTclVersionMM \
			 [list require [$index Value/Direct require $spec]]]
	    }
	} msg]} {
	    return -code error $msg
	}

	eval [linsert $logcmd end "OK."]
	return
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Register us at the central type auto-detection.

::repository::api registerForAuto ::repository::localma

# ### ### ### ######### ######### #########
## Tracing

namespace eval ::repository::localma {
    logger::init                              repository::localma
    logger::import -force -all -namespace log repository::localma
}

# ### ### ### ######### ######### #########
## Ready
return
