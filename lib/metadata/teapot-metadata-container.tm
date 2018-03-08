# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package teapot::metadata::container 1.0
# Meta platform    tcl
# Meta require     snit
# Meta require     teapot::instance
# Meta require     teapot::metadata::write
# @@ Meta End

# -*- tcl -*-
# Copyright (c) 2006 ActiveState Software Inc.
#               Tools & Languages
# $Id$
# --------------------------------------------------------------
# PI : Container for Meta Data

package require snit                    ; # OO core
package require teapot::metadata::write ; # MD formatting for output
package require teapot::instance        ; # Instance construction ...
package require teapot::version         ; # Version validation ...

# ### ### ### ######### ######### #########
##

snit::type ::teapot::metadata::container {
    # Collect information about a single package instance.
    # ### ### ### ######### ######### #########

    constructor {} {}

    method clone {name} {
	set n [$type create $name]
	$n define $_iname $_iversion $_itype
	$n set    [array get _idata]
	return $n
    }

    method mergeOver {p} {
	array set _idata [$p get]
	return
    }

    method define {iname iversion {itype Package}} {
	teapot::version::check $iversion
	teapot::entity::check  $itype
	set _iname    $iname
	set _iversion $iversion
	set _itype    $itype
	return
    }

    method type    {} {return $_itype}
    method name    {} {return $_iname}
    method version {} {return $_iversion}
    method arch    {} {return $_idata(platform)}

    method retype {t} {
	teapot::entity::check $t
	set _itype            $t
	return
    }

    method reversion {v} {
	teapot::version::check $v
	set _iversion          $v
	return
    }

    method rename {n} {
	set _iname $n
	return
    }

    method rearch {a} {
	set _idata(platform) [list $a]
	return
    }

    method reversion_unchecked {v} {
	set _iversion $v
	return
    }

    method identity {} {
	return ${_iname}-${_iversion}
    }

    method instance {} {
	if {![info exists _idata(platform)]} {
	    return -code error "No platform defined"
	}
	return [teapot::instance::cons \
		    $_itype $_iname $_iversion $_idata(platform)]
    }

    # ### ### ### ######### ######### #########
    ## Cheat sheet
    #
    # set      DICT       :      <change contents of container>
    # get                 : DICT <get complete contents of container>
    # names               : LIST <get list of keys>
    #
    # setfor   KEY LIST   :      <change contents of key>
    # getfor   KEY        : LIST <get list of values for KEY>
    #
    # getfirst KEY        : VAL  <get first value in list of values for KEY>
    #
    # add      KEY VAL... :      <add values to KEY>
    # addlist  KEY VLIST  :      <add values in VLIST to KEY>
    #
    # unset    KEY        :      <remove KEY>
    # clear    ?PATTERN?  :      <remove keys matching glob PATTERN, default * = all>
    #
    # exists   KEY        : BOOL <test existence of key>
    #
    # copy SRC DST        :      <copy contents of key SRC to key DST>
    # move SRC DST        :      <like copy, and remove key SRC>
    #
    # serialize           : list(name version type data) <serialize container to value>
    # deserialize SER     :      <set container from serialization value>
    ##
    # ### ### ### ######### ######### #########

    method set {dict} {
	array unset _idata *
	array set   _idata $dict
	return
    }

    method setfor {k list} {
	set k [string tolower $k]
	set _idata($k) $list
	return
    }

    method add {k args} {
	set k [string tolower $k]
	# Bug 46019
	if {![info exists _idata($k)]} {set _idata($k) {}}
	foreach a $args {
	    lappend _idata($k) $a
	}
	return
    }

    method addlist {k alist} {
	set k [string tolower $k]
	# Bug 46019
	if {![info exists _idata($k)]} {set _idata($k) {}}
	foreach a $alist {
	    lappend _idata($k) $a
	}
	return
    }

    method remove {k item} {
	set k [string tolower $k]
	if {![info exists _idata($k)]} return
	set pos [lsearch -exact $_idata($k) $item]
	if {$pos < 0} return
	set _idata($k) [lreplace $_idata($k) $pos $pos]
	return
    }

    method remove* {k pattern} {
	set k [string tolower $k]
	if {![info exists _idata($k)]} return
	while {1} {
	    set pos [lsearch -glob $_idata($k) $pattern]
	    if {$pos < 0} return
	    set _idata($k) [lreplace $_idata($k) $pos $pos]
	}
	return
    }

    method unset {k} {
	set k [string tolower $k]
	unset -nocomplain _idata($k)
	return
    }

    method clear {{pattern *}} {
	set pattern [string tolower $pattern]
	array unset _idata $pattern
	return
    }

    method getfor {k} {
	set k [string tolower $k]
	return $_idata($k)
    }

    method getfirst {k} {
	set k [string tolower $k]
	return [lindex $_idata($k) 0]
    }

    # ### ### ### ######### ######### #########

    method get {}  {
	array get _idata
    }

    method exists {k} {
	set k [string tolower $k]
	info exists _idata($k)
    }

    method names {{pattern *}} {
	array names _idata $pattern
    }

    # ### ### ### ######### ######### #########

    method copy {ksrc kdst} {
	## $self setfor $kdst [$self getfor $ksrc]

	set ksrc [string tolower $ksrc]
	set kdst [string tolower $kdst]

	set _idata($kdst) $_idata($ksrc)
	return
    }

    method move {ksrc kdst} {
	## $self copy  $ksrc $kdst
	## $self unset $ksrc

	set ksrc [string tolower $ksrc]
	set kdst [string tolower $kdst]

	set   _idata($kdst) $_idata($ksrc)
	unset                _idata($ksrc)
	return
    }

    # ### ### ### ######### ######### #########

    method serialize {} {
	return [list $_iname $_iversion $_itype [array get _idata]]
    }

    method deserialize {serialization} {
	foreach {n v t md} $serialization break

	set _itype    $t     ; # retype
	set _iname    $n     ; # rename
	set _iversion $v     ; # reversion
	array unset _idata * ; # /
	array set _idata $md ; # / set
	return
    }

    # ### ### ### ######### ######### #########

    variable _itype        {} ; # Instance type (Package, Application, ...)
    variable _iname        {} ; # Instance name
    variable _iversion     {} ; # Instance version
    variable _idata -array {} ; # Instance meta data

    # ### ### ### ######### ######### #########
    ## DEBUG

    method DUMP {} {
	puts stdout "DUMP $self"
	puts "$_itype $_iname ($_iversion)"
	parray _idata
	return
    }
}

# ### ### ### ######### ######### #########
## Ready
return
