# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -- Tcl Module

# @@ Meta Begin
# Package cmatch 0.1
# Meta platform tcl
# Meta description Provides commands to convert tcl scripts into parses
# Meta description and ASTs, and to match AST templates against code trees.
# Meta subject parse tree match unify
# Meta summary Convert and match tcl scripts via trees
# Meta category Processing Tcl code
# Meta require         {Tcl -version 8.4}
# Meta require         parser
# Meta require         logger
# @@ Meta End

# -*- tcl -*-
# -*- tcl -*-
# Copyright (c) 2006-2007 ActiveState Software Inc.
#               Tools & Languages
# $Id$

# ### ### ### ######### ######### #########
## Description

# CMatch - Code Match - Matching command on top of the tcl parser.
# Derived from the buildsystem's TP package. 

## FUTURE : consider use of struct:tree (critcl accelerated) for easier
## ...... : implementation of the ops, reconversion, and matching.
## ...... : consider tree matching in struct::tcl

# ### ### ### ######### ######### #########
## Requisites

package require parser ; # Use Tcl itself for the parsing of code.
package require logger

logger::initNamespace ::cmatch
namespace eval        ::cmatch::match {}

# ### ### ### ######### ######### #########
## Script, single command -> Convert to AST

proc ::cmatch::cmdtree {script} {
    set first 1
    set scriptRange [parse getrange $script]

    for {} \
	{[parse charlength $script $scriptRange] > 0} \
	{set scriptRange $tail} {

	    #log::debug "Range: $scriptRange"

	    # Parse the next command
	    set cmdrange $scriptRange

	    if {[catch {
		foreach {comment cmdRange tail tree} \
		    [parse command $script $scriptRange] \
		    {}
	    } msg]} {
		# We do not try to recover from parse errors.
		# We simply report and abort.

		#log::debug "Bad parse for $scriptRange"
		#log::debug "$::errorCode"
		#log::debug "$::errorInfo"

		return -code error "Parse error for $scriptRange"
	    }

	    #log::debug "Tail:  $tail"

	    if {[parse charlength $script $cmdRange] <= 0} {
		continue
	    }

	    set words {}
	    foreach token $tree {
		#puts -\t$token
		lappend words [detok $script $token]
	    }

	    # Only one command in the script ...
	    return [linsert $words 0 cmd]
	}
}

# ### ### ### ######### ######### #########
## Script conversion
# Use Tcl parser to convert the provided Tcl script into AST form.
# The first element of each node is a type tag, followed by type
# specific information. Known tags and their information are

# lit        literal value
# word       .
# cmd        .
# var/scalar name
# var/array  name, index
# bs         literal
# cmdtree    cmd-script
# <exprop>   op-arguments

proc ::cmatch::scripttree {script} {

    set cmds {}

    set first 1
    set scriptRange [parse getrange $script]

    for {} \
	{[parse charlength $script $scriptRange] > 0} \
	{set scriptRange $tail} {

	    #log::debug "Range: $scriptRange"

	    # Parse the next command
	    set cmdrange $scriptRange

	    if {[catch {
		foreach {comment cmdRange tail tree} \
		    [parse command $script $scriptRange] \
		    {}
	    } msg]} {
		# We do not try to recover from parse errors.
		# We simply report and abort.

		#log::debug "Bad parse for $scriptRange"
		#log::debug "$::errorCode"
		#log::debug "$::errorInfo"

		return -code error "Parse error for $scriptRange"
	    }

	    #log::debug "Tail:  $tail"

	    if {[parse charlength $script $cmdRange] <= 0} {
		continue
	    }

	    set words {}
	    foreach token $tree {
		#puts -\t$token
		lappend words [detok $script $token]
	    }

	    lappend cmds [linsert $words 0 cmd]
	}

    return [linsert $cmds 0 script]
}

# ### ### ### ######### ######### #########
## Convert expression into AST.

proc ::cmatch::exprtree {expr} {
    return [detok $expr \
		[parse expr $expr \
		     [parse getrange $expr]]]
}

# ### ### ### ######### ######### #########
## Back conversion - AST to Tcl code.

# ### ### ### ######### ######### #########
## Quote a literal text as constant

proc ::cmatch::qlit {text} {
    if {[regexp "\[ \t\n\]" $text]} {
	set text "\{$text\}"
    }
    return $text
}

# ### ### ### ######### ######### #########
## Remove superfluous whitespace, cont. lines, etc.

proc ::cmatch::trim {script} {
    set go 1
    while {$go} {
	set go 0
	while {[regsub "^\[ \t\n\]+" $script {} script]} {set go 1}
	while {[regsub "^\\\\\n"     $script {} script]} {set go 1}
	while {[regsub "\[ \t\n\]+$" $script {} script]} {set go 1}
	while {[regsub "\\\\$"       $script {} script]} {set go 1}
    }
    return $script
}

# ### ### ### ######### ######### #########
## Convert an AST back into the Tcl code it was generated from.

proc ::cmatch::literal {tree} {
    set type [lindex $tree 0]
    switch -exact -- $type {
	lit {
	    return [lindex $tree 1]
	}
	word {
	    set buf ""
	    foreach c [lrange $tree 1 end] {
		set ctype [lindex $c 0]
		if {$ctype eq "cmd"} {
		    append buf \[[literal $c]\]
		} else {
		    append buf [literal $c]
		}
	    }
	    return $buf
	}
	cmd {
	    set buf {}
	    foreach c [lrange $tree 1 end] {
		set ctype [lindex $c 0]

		if {$ctype eq "cmd"} {
		    append buf " \[[literal $c]\]"
		} elseif {[string match var* $ctype]} {
		    append buf " [literal $c]"
		} else {
		    append buf " [list [literal $c]]"
		}
	    }
	    return [string trimleft $buf]
	}
	var/scalar {
	    return \$[qlit [literal [lindex $tree 1]]]
	}
	var/array {
	    # Bugzilla 89337. Bad handling of tcl_platform(platform).
	    set name  [literal [lindex $tree 1]]
	    set index [literal [lindex $tree 2]]

	    return \$${name}($index)
	}
	bs {
	    return [string map \
			[list \\\\ \\ \\n \n \\t \t] \
			[lindex $tree 1]]
	}
	default {
	    return -code error "Unknown token type [lindex $tree 0]"
	}
    }
}

# ### ### ### ######### ######### #########
## Script parsing. convert a single token into an AST node.

proc ::cmatch::detok {script t} {
    foreach {type range children} $t break
    switch -exact -- $type {
	simple - text {
	    set lit [parse getstring $script $range]
	    if {[string match "\{*\}" $lit]} {
		set lit [string range $lit 1 end-1]
	    } elseif {[string match "\"*\"" $lit]} {
		set lit [string range $lit 1 end-1]
	    }
	    return [list lit $lit]
	}
	word {
	    if {[llength $children] == 1} {
		return [detok $script [lindex $children 0]]
	    } else {
		set islit 1
		set x word
		foreach c $children {
		    set sub [detok $script $c]
		    lappend x $sub
		    if {
			([lindex $sub 0] ne "lit") &&
			([lindex $sub 0] ne "bs")
		    } {set islit 0}
		}
		if {$islit} {
		    set lit [parse getstring $script $range]
		    if {[string match "\{*\}" $lit]} {
			set lit [string range $lit 1 end-1]
		    }
		    return [list lit $lit]
		}
		return $x
	    }
	}
	command {
	    set cmdscript [string range \
			       [parse getstring $script $range] \
			   1 end-1]
	    return [cmdtree $cmdscript]
	}
	variable {
	    if {[llength $children] == 1} {
		return [list var/scalar [detok $script [lindex $children 0]]]
	    } elseif {[llength $children] == 2} {
		return [list var/array \
			    [detok $script [lindex $children 0]] \
			    [detok $script [lindex $children 1]]]
	    } else {
		log::debug "complex $t"
	    }
	}
	backslash {
	    set lit [parse getstring $script $range]
	    return [list bs $lit]	    
	}
	subexpr {
	    if {[llength $children] == 1} {
		return [detok $script [lindex $children 0]]
	    }
	    set x [detok $script [lindex $children 0]]
	    foreach c [lrange $children 1 end] {
		lappend x [detok $script $c]
	    }
	    return $x
	}
	operator {
	    # Not a tree, just the operator name.
	    # See subexpr above for use.
	    return [parse getstring $script $range]
	}
	default {
	    log::debug "Unknown $t"
	}
    }
}

# ### ### ### ######### ######### #########
## Matching - AST against AST-template.
##            Run script if successful.

proc ::cmatch::on {tree template script} {
    set ok [uplevel 1 [list ::cmatch::match $tree $template]]
    if {!$ok} return
    uplevel 1 $script
}

# ### ### ### ######### ######### #########
## Matching - AST against AST-template, boolean result

proc ::cmatch::match {tree template} {
    set res [uplevel 1 [list ::cmatch::Match $tree $template]]
    #puts "MATCH: $res = <$tree> / <$template>"
    return $res
}

# ### ### ### ######### ######### #########
## Matching - AST against AST-template, recursive main worker command

proc ::cmatch::Match {tree template} {
    #puts \[$tree\]\ \\\ \[$template\]
    if {[llength $template] == 1} {
	if {[string match {$*} $template]} {
	    upvar 1 [string range $template 1 end] var
	    set var $tree
	    return 1
	} else {
	    return [string equal $tree $template]
	}
    } elseif {[llength $tree] != [llength $template]} {
	return 0
    } else {
	foreach a $tree b $template {
	    set res [uplevel 1 [list ::cmatch::match $a $b]]
	    if {!$res} {
		return 0
	    }
	}
	return 1
    }
}

proc ::cmatch::match::Eval {tree template} {
    set res [uplevel 1 [list ::cmatch::match::[lindex $tree 0] \
			    [lindex $template 0] \
			    [lrange $tree 1 end] \
			    [lrange $template 1 end]]]

    puts "MATCH: $res = <$tree> / <$template>"
    return $res
}

# ### ### ### ######### ######### #########
# Type dependent matcher commands for a single node.

proc ::cmatch::match::cmd {tmtype tchildren tmchildren} {
    if {[string match {$*} $tmtype]} {
	upvar 1 [string range $tmtype 1 end] out
	if {![llength $tmchildren]} {
	    set out [list cmd $tchildren]
	    return 1
	}
	set out cmd
    } elseif {$tmtype ne "cmd"} {
	return 0
    }

    foreach tree $tchildren template $tmchildren {
	if {![uplevel 1 [list ::cmatch::match::Eval $tree $template]]} {return 0}
    }
    return 1
}

proc ::cmatch::match::word {tmtype tchildren tmchildren} {
    if {[string match {$*} $tmtype]} {
	upvar 1 [string range $tmtype 1 end] out
	set out word
    } elseif {$tmtype ne "word"} {
	return 0
    }

    foreach tree $tchildren template $tmchildren {
	if {![uplevel 1 [list ::cmatch::match::Eval $tree $template]]} {return 0}
    }
    return 1
}

proc ::cmatch::match::var/scalar {tmtype tchildren tmchildren} {
    if {[string match {$*} $tmtype]} {
	upvar 1 [string range $tmtype 1 end] out
	set out var/scalar
    } elseif {$tmtype ne "var/scalar"} {
	return 0
    }

    foreach tree $tchildren template $tmchildren {
	if {![uplevel 1 [list ::cmatch::match::Eval $tree $template]]} {return 0}
    }
    return 1
}

proc ::cmatch::match::bs {tmtype tchildren tmchildren} {
    if {[string match {$*} $tmtype]} {
	upvar 1 [string range $tmtype 1 end] out
	set out bs
    } elseif {$tmtype ne "bs"} {
	return 0
    }

    foreach tree $tchildren template $tmchildren {
	if {[string match {$*} $template]} {
	    upvar 1 [string range $template 1 end] out
	    set out $tree
	} elseif {$template ne $tree} {
	    return 0
	}
    }
    return 1
}

proc ::cmatch::match::lit {tmtype tchildren tmchildren} {
    if {[string match {$*} $tmtype]} {
	upvar 1 [string range $tmtype 1 end] out
	set out lit
    } elseif {$tmtype ne "lit"} {
	return 0
    }

    foreach tree $tchildren template $tmchildren {
	if {[string match {$*} $template]} {
	    upvar 1 [string range $template 1 end] out
	    set out $tree
	} elseif {$template ne $tree} {
	    return 0
	}
    }
    return 1
}

# ### ### ### ######### ######### #########
## Match a AST template against an AST and return all subtrees where the
## template was found.

proc ::cmatch::locate {mv tree template} {
    #puts "@@@locate ($tree)"
    upvar 1 $mv matches

    if {[match $tree $template]} {
	lappend matches $tree
	return
    }

    set type [lindex $tree 0]
    set sub  [lrange $tree 1 end]

    if {$type eq "lit"} {
	# Unfold literals in our search for matching trees.

	set stext [lindex $sub 0]

	if {$stext eq "\""} return

	if {[catch {
	    #puts S\ $stext
	    set stree [scripttree $stext]
	}]} {
	    if {[catch {
		#puts E\ $stext
		set stree [exprtree   $stext]
	    }]} {
		# Unparseable, neither script nor expression.
		# no deeper structure. Will not match.
		return
	    }
	}

	if {$stree eq [list script [list cmd [list lit $stext]]]} {
	    # Literal is atomic, unexpandable. Will not match.
	    return
	}

	locate matches $stree $template
	return
    }

    # Recurse into children, aka sub-trees

    foreach s $sub {
	locate matches $s $template
    }
    return
}

# ### ### ### ######### ######### #########
## Ready
return
