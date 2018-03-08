# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-

proc dict {cmd args} {
    return [uplevel 1 [linsert $args 0 ::dict::$cmd]]
}

namespace eval ::dict {}

proc ::dict::create {args} {
    array set tmp $args
    return [array get tmp]
}

proc ::dict::replace {dict args} {
    array set tmp $dict
    array set tmp $args
    return [array get tmp]
}

proc ::dict::merge {dict args} {
    array set tmp $dict
    foreach a $args {
	array set tmp $a
    }
    return [array get tmp]
}

proc ::dict::get {dict key} {
    array set tmp $dict
    return $tmp($key)
}

proc ::dict::exists {dict key} {
    array set tmp $dict
    return [info exists tmp($key)]
}

proc ::dict::set {dictvar args} {
    upvar 1 $dictvar dict
    array set tmp $dict
    array set tmp $args
    ::set dict [array get tmp]
    return
}

proc ::dict::append {dictvar key val} {
    upvar 1 $dictvar dict
    array set tmp $dict
    ::append tmp($key) $val
    ::set dict [array get tmp]
    return
}

proc ::dict::unset {dictvar key} {
    upvar 1 $dictvar dict
    array set tmp $dict
    catch {::unset tmp($key)}
    ::set dict [array get tmp]
    return
}

proc ::dict::for {vars dict script} {
    uplevel 1 [list foreach $vars $dist $script]
    return
}

proc ::dict::keys {dict {pattern *}} {
    array set tmp $dict
    return [array names tmp $pattern]
}

# ### ### ### ######### ######### #########
## Ready

package provide dictcompat 0.1

