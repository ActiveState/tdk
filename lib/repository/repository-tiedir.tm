# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package repository::tiedir 0.1
# Meta platform    tcl
# Meta require     afs
# Meta require     repository::api
# Meta require     snit
# Meta require     struct::set
# Meta require     teapot::metadata
# Meta require     teapot::metadata::read
# Meta require     tie
# @@ Meta End

# -*- tcl -*-
# ### ### ### ######### ######### #########
## Overview

# snit::type for a hybrid repository (database + directory). This type
# of repository is not intended for use by a regular
# tclsh/wish. I.e. it cannot be used for a local installation
# repository.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require repository::api
package require teapot::metadata
package require teapot::metadata::read

package require tie
package require afs
package require struct::set

# ### ### ### ######### ######### #########
## Implementation

snit::type ::repository::tiedir {

    option -dir {}

    # ### ### ### ######### ######### #########
    ## API - Delegated to the generic frontend

    delegate method * to API
    variable             API

    # ### ### ### ######### ######### #########
    ## API - Implementation.

    ## These are the methods that are called from the frontend during
    ## dispatch.

    method Put {opt file} {
	set sig [$fs put $file new]

	# NOTE -- Any error caught after the file has been inserted
	# NOTE -- and is new has to cause removal of the file,
	# NOTE -- otherwise any further attempt at adding it will
	# NOTE -- shortcircuit without updating the index.

	# Short path for instances which are fully identical to a
	# known file.

	if {!$new} {
	    repository::api complete $opt 0 [$self Instance $sig]
	    return
	}

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

	set pkg      [lindex $msg 0]
	set meta     [$pkg get]
	set instance [$pkg instance]
	$pkg destroy

	# FUTURE - pass the object to the 'index' database.

	if {![catch {set oldsig [$self File $instance]}]} {
	    $self Remove $instance $oldsig
	}
	$self Add $instance $sig $data

	repository::api complete $opt 0 [$self Instance $sig]
	return
    }

    method Get {opt instance file} {
	if {![Exists $instance]} {
	    repository::api complete $opt 1 "Instance \"$instance\" does not exist"
	    return
	}

	set sig [$self File $instance]
	$fs copy $sig $file

	repository::api complete $opt 0 {}
	return
    }

    method Del {opt instance} {
	if {![Exists $instance]} {
	    repository::api complete $opt 1 "Instance \"$instance\" does not exist"
	    return
	}

	$self Remove $instance [$self File $instance]

	repository::api complete $opt 0 {}
	return
    }

    method Path {opt instance} {
	return -code error "Bad request"
    }

    method Require {opt instance} {
	if {![Exists $instance]} {
	    repository::api complete $opt 1 "Instance \"$instance\" does not exist"
	    return
	}

	if {[catch {
	    set res [$self MetaGet $instance Require]
	}]} {
	    repository::api complete $opt 0 {}
	}
	repository::api complete $opt 0 $res
	return
    }

    method Recommend {opt instance} {
	if {![Exists $instance]} {
	    repository::api complete $opt 1 "Instance \"$instance\" does not exist"
	    return
	}

	if {[catch {
	    set res [$self MetaGet $instance Recommend]
	}]} {
	    repository::api complete $opt 0 {}
	}
	repository::api complete $opt 0 $res
	return
    }

    method Requirers {opt instance} {
	if {![Exists $instance]} {
	    repository::api complete $opt 1 "Instance \"$instance\" does not exist"
	    return
	}

	if {[catch {
	    set res [$self Users $instance q]
	}]} {
	    repository::api complete $opt 0 {}
	}
	repository::api complete $opt 0 $res
	return
    }

    method Recommenders {opt instance} {
	if {![Exists $instance]} {
	    repository::api complete $opt 1 "Instance \"$instance\" does not exist"
	    return
	}

	if {[catch {
	    set res [$self Users $instance c]
	}]} {
	    repository::api complete $opt 0 {}
	}
	repository::api complete $opt 0 $res
	return
    }

    method Find {opt platform template} {
	# Find everything and take last. _findall guarantuees that the
	# last element has max version.

	if {![repository::api depok $template]} {
	    repository::api complete $opt 1 "Bad template \"$template\""
	    return
	}
	repository::api complete $opt 0 [list [lindex [$self _findall $platform $template] end]]
	return

    }

    method FindAll {opt platform template} {
	if {![repository::api depok $template]} {
	    repository::api complete $opt 1 "Bad template \"$template\""
	    return
	}
	repository::api complete $opt 0 [$self _findall $platform $template]
	return
    }

    method Entities {opt} {
	array set p {}
	foreach k [array names F,*] {
	    set p([lindex [split $k ,] 1]) .
	}
	repository::api complete $opt 0 [array names p]
	return
    }

    method Versions {opt package} {
	if {[llength $package] != 1} {
	    repository::api complete $opt 1 "Bad package \"$package\""
	    return
	}
	array set p {}
	foreach k [array names F,${package},*] {
	    set p([lrange [split $k ,] 1 2]) .
	}
	repository::api complete $opt 0 [array names p]
	return
    }

    method Instances {opt version} {
	if {[llength $version] != 2} {
	    repository::api complete $opt 1 "Bad version \"$version\""
	    return
	}
	array set p {}
	foreach k [array names F,[join $version ,],*] {
	    set p([lrange [split $k ,] 1 end]) .
	}
	repository::api complete $opt 0 [array names p]
	return
    }

    method Meta {opt spec} {
	switch -exact -- [llength $spec] {
	    1       -
	    2       -
	    3       {set res [$self MetaSpec $spec]}
	    default {
		repository::api complete $opt 1 "Bad spec \"$spec\""
	    }
	}
	repository::api complete $opt 0 $res
	return
    }

    method Keys {opt {spec {}}} {
	switch -exact -- [llength $spec] {
	    0       {set res [$self KeysAll]}
	    1       -
	    2       -
	    3       {set res [$self KeysSpec $spec]}
	    default {
		repository::api complete $opt 1 "Bad spec \"$spec\""
	    }
	}
	repository::api complete $opt 0 $res
	return
    }

    method Value {opt key spec} {
	switch -exact -- [llength $spec] {
	    1       -
	    2       -
	    3       {set res [$self ValueSpec $spec $key]}
	    default {
		repository::api complete $opt 1 "Bad spec \"$spec\""
	    }
	}
	repository::api complete $opt 0 $res
	return
    }

    method Search {opt query} {
	if {![repository::api validate $query]} {
	    repository::api complete $opt 1 "Bad syntax"
	}
	repository::api complete $opt 0 [_search index $query]
	return
    }

    # ### ### ### ######### ######### #########
    ##

    constructor {args} {
	$self configurelist $args
	if {$options(-dir) eq ""} {
	    return -code error "repository directory not specified"
	}

	$self Setup $options(-dir)

	# The api object dispatches requests directly to us.
	set API [repository::api ${selfns}::API -impl $self]
	return
    }

    # ### ### ### ######### ######### #########
    ## Internals ...

    variable index -array {}
    variable fs           {}

    method Setup {dir} {
	set store [file join $dir STORE]
	set idx   [file join $dir INDEX]
	if {![file exists $store]} {
	    file mkdir $store
	} elseif {![file isdirectory $store]} {
	    return -code error "STORE \"$store\" should be directory, is a file"
	}

	tie::tie [myvar index] file $idx
	set fs [::afs ${selfns}::FS $store]
	return
    }

    # index : 'F' x pname x pver x platform        -> file signature
    #         'I' x file signature                 -> pname x pver x platform
    #         'M' x  pname x pver x platform x key -> value

    # inverted dependencies ...
    #
    #         'q' x pname x pver x platform -> users, require
    #         'c' x pname x pver x platform -> users, recommend

    # inverted dependencies, two ... templates to users, for packages
    # which are not present (yet).


    # NOTE : The definition of index above allows for files containing
    # NOTE : more than one package instance, and files for more than
    # NOTE : one platform. It use is however restricted to one file
    # NOTE : <=> one package instance. Multi-platform instances and
    # NOTE : files are not possible, nor are multi-package files.

    # NOTE : This actually already checked for in the MD 
    # NOTE : extractor / parser.


    method Instance {sig} {
	return $index(I,$sig)
    }

    method File {instance} {
	return $index(F,[join $instance ,])
    }

    method Users {instance what} {
	return $index($what,[join $instance ,])
    }

    method Exists {instance} {
	info exists index(F,[join $instance ,])
    }

    method Remove {instance sig} {
	set iky [join $instance ,]

	$fs del $sig
	unset index(I,$sig)
	unset index(F,$iky)

	unset -nocomplain index(q,$iky)
	unset -nocomplain index(c,$iky)

	# Resolve dependencies and remove us as user

	foreach what {Require Recommend} {
	    if {[info exists index(M,$iky,$what)]} {
		foreach template $index(M,$iky,$what) {
		    foreach x [$self _findall $platform $template] {
			ldelete index(q,[join $x ,]) $instance
		    }
		}
	    }
	}

	array unset index M,$iky,*
	return
    }

    method Add {instance sig meta} {
	set iky [join $instance ,]

	# File is already stored.
	set index(I,$sig) $instance
	set index(F,$iky) $sig

	set platform [lindex $instance 2]

	foreach {k v} [lindex $meta end] {
	    # Additional handling of the dependencies. Keep the
	    # inverted indices uptodate. Resolve template to _all_
	    # packages matching it and note us as their user ...
	    # Also cleanup, removal of duplicates ...

	    # BUG / MISSING : The newly added instance may satisfy
	    # requirements of existing packages, i.e. its users. These
	    # have to add themselves as user to this package.

	    if {$k eq "Require"} {
		set v [lsort -uniq $v]

		# For P determine all P' known required by P. Register
		# P as user of P'

		foreach template $v {
		    foreach x [$self _findall $platform $template] {
			lappend index(q,[join $x ,]) $instance
		    }
		}

		# MISSING -- BUG
		# For P determine all P' using P, register P' as user
		# of P.

	    } elseif {$k eq "Recommend"} {
		set v [lsort -uniq $v]
		foreach template $v {
		    foreach x [$self _findall $platform $template] {
			lappend index(c,[join $x ,]) $instance
		    }
		}
	    }

	    set index(M,$iky,$k) $v
	}
	return
    }

    proc MetaInstance {meta} {
	return [lrange $meta 0 2]
    }

    proc MetaDep {meta what} {
	array set md [lindex $meta end]
	if {![info exist md($what)]} {return {}}

	# Special knowlegde about dependencies.
	# Remove duplicate references.

	return [lsort -uniq $md($what)]
    }

    method MetaGet {instance key} {
	return $index(M,[join $instance ,],$key)
    }

    proc ldelete {listvar el} {
	upvar 1 $listvar l
	set pos [lsearch -exact $l $el]
	if {$pos < 0} return
	set l [lreplace [K $l [unset l]] $pos $pos]
	return
    }

    proc K {x y} {return $x}

    method _findall {platform template} {
	set pname [lindex $template 0]
	set match {}

	if {[llength $template] == 3} {
	    set pver [lindex $template 1]
	    foreach k [array names index F,$pname,$pver,*] {
		set p [lindex [split $k ,] end]
		if {![string match $platform $p]} continue
		lappend match [lrange [split $k ,] 1 end]
	    }
	} elseif {[llength $template] == 2} {
	    set pver   [lindex $template 1]
	    set pmajor [lindex [split $pver .] 0]

	    foreach k [array names index F,$pname,${pmajor}*,*] {
		set p [lindex [split $k ,] end]
		if {![string match $platform $p]} continue
		lappend match [lrange [split $k ,] 1 end]
	    }
	} else {
	    foreach k [array names index F,$pname,*,*] {
		set p [lindex [split $k ,] end]
		if {![string match $platform $p]} continue
		lappend match [lrange [split $k ,] 1 end]
	    }
	}

	# NOTE __ The lsort used here will sort regular version
	# NOTE __ numbers (X.y.etc....) right, highest last. It will
	# NOTE __ generate bogus results for version numbers contain
	# NOTE __ aX, bX, etc. i.e. alpha and beta designations. For
	# NOTE __ now I exclude such from the system.

	return [lsort $match]
    }


    method MetaSpec {spec} {
	set pt M,[join $spec ,],*
	set tmp {}
	foreach k [array names index $pt] {
	    set tmp([lindex [split $k ,] end],$index($k)) .
	}
	array set res {}
	foreach k [array names tmp] {
	    foreach {i v} [split $k ,] break
	    lappend res($k) $v
	}
	return [array get res]
    }

    method ValueSpec {spec key} {
	while {[llength $spec] < 3} {lappend spec *}
	set pt M,[join $spec ,],$key
	array set res {}
	foreach k [array names index $pt] {
	    set res($index($k)) .
	}
	return [array names res]
    }

    method KeysSpec {spec} {
	set pt M,[join $spec ,],*
	array set res {}
	foreach k [array names index $pt] {
	    set res([lindex [split $k ,] end]) .
	}
	return [array names res]
    }

    method KeysAll {} {
	set pt M,*
	array set res {}
	foreach k [array names index $pt] {
	    set res([lindex [split $k ,] end]) .
	}
	return [array names res]
    }


    proc _search {db query} {
	upvar 1 $db index

	switch -exact -- [lindex $query 0] {
	    and {
		# Shortcircuit when empty
		set res [_search index [lindex $query 1]]
		if {![llength $res]} {
		    return $res
		}
		foreach sub [lrange $query 2 end] {
		    set res [struct::set intersect \
				 [K $res [unset res]] \
				 [_search index $sub]]
		    if {![llength $res]} {
			return $res
		    }
		}
	    }
	    or {
		# Shortcircuit when everything found
		set max [llength [array names M,*]]

		set res [_search index [lindex $query 1]]
		if {$max == [llength $res]} {
		    return $res
		}
		foreach sub [lrange $query 2 end] {
		    set res [struct::set union \
				 [K $res [unset res]] \
				 [_search index $sub]]
		    if {$max == [llength $res]} {
			return $res
		    }
		}
	    }
	    haskey {
		set key [lindex $query 1]
		set res {}
		foreach k [array names M,*,$key] {
		    lappend res [lrange [split $k ,] 1 3]
		}
	    }
	    key {
		foreach {__ key op val} $query break

		# Limit to those which have the key ...
		set tmp {}
		foreach k [array names M,*,$key] {
		    lappend tmp [lrange [split $k ,] 1 3]
		}

		set res {}
		switch -exact -- $op {
		    eq    {
			foreach i $tmp {
			    if {$index(M,[join $i ,],$key) ne $val} continue
			    lappend res $i
			}
		    }
		    rex   {
			foreach i $tmp {
			    if {![regexp -- $val $index(M,[join $i ,],$key)]} continue
			    lappend res $i
			}
		    }
		    glob  {
			foreach i $tmp {
			    if {![string match $val $index(M,[join $i ,],$key)]} continue
			    lappend res $i
			}
		    }
		    ne    {
			foreach i $tmp {
			    if {$index(M,[join $i ,],$key) eq $val} continue
			    lappend res $i
			}
		    }
		    !rex  {
			foreach i $tmp {
			    if {[regexp -- $val $index(M,[join $i ,],$key)]} continue
			    lappend res $i
			}
		    }
		    !glob {
			foreach i $tmp {
			    if {[string match $val $index(M,[join $i ,],$key)]} continue
			    lappend res $i
			}
		    }
		    <     {
			foreach i $tmp {
			    set fail [catch {expr {$index(M,[join $i ,],$key) < $val}} match]
			    if {$fail || !$match} continue
			    lappend res $i
			}
		    }
		    >     {
			foreach i $tmp {
			    set fail [catch {expr {$index(M,[join $i ,],$key) > $val}} match]
			    if {$fail || !$match} continue
			    lappend res $i
			}
		    }
		    <=    {
			foreach i $tmp {
			    set fail [catch {expr {$index(M,[join $i ,],$key) <= $val}} match]
			    if {$fail || !$match} continue
			    lappend res $i
			}
		    }
		    >=    {
			foreach i $tmp {
			    set fail [catch {expr {$index(M,[join $i ,],$key) >= $val}} match]
			    if {$fail || !$match} continue
			    lappend res $i
			}
		    }
		}
	    }
	}
	return $res
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready
return
