# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# context.tcl --
#
#	This file contains routines for storing, combining and
#	locating context information (i.e., namespace or class path) 
#
# Copyright (c) 1998-2000 Ajuba Solutions

# 
# RCS: @(#) $Id: context.tcl,v 1.3 2000/10/31 23:30:54 welch Exp $

package require analyzer 1.0
namespace import -force ::analyzer::*

namespace eval context {
    # Known Contexts --
    # Store a list of known contexts so we can check for the 
    # existance of a context when locating absolute or relative
    # contexts.

    variable knownContext
    array set knownContext {}
    # Context Stack --
    # The context stack keeps track of the current context 
    # (e.g., namespace path or class name.)  When we enter 
    # a class body or namespace body, a new context is 
    # pushed on the stack.  This allows us to determine 
    # where commands are defined.

    variable contextStack "::"

    # Protection Stack --
    # The context stack keeps track of what the protection
    # level is for the current body being analyzed.  When
    # the public, private, or protected commands are used,
    # their protection level is pushed on the stack, and
    # popped when they finish.

    variable protectionStack "public"

    # Object stack --
    # This stack keeps track of the object (scope) the script
    # currently scanned belongs to (lexically). Its items are
    # duples containing type of the object and its fully qualified
    # name.

    # Pushes on the scope stack are handled by whatever command
    # opens a new lexical scope. Pops are done automatically in
    # 'analyzer::checkContext' if pushes were done.

    # Global scope is always present, and not bound to a file.
    variable scopeStack [list {namespace :: {{} {} {}}}]

}

# context::add --
#
#	Add a new context to the list of known contexts.
#
# Arguments:
#	context		A new context to add.
#
# Results:
#	None.

proc context::add {context} {
    if {$context eq ""} {set context "::"}

    #::log::log debug "CTX add ($context)"

    set context::knownContext($context) 1
}

# context::exists --
#
#	Determine if the specified context exists.
#
# Arguments:
#	context		A context to search for.
#
# Results:
#	Return 1 if the context exists, 0 if it does not.

proc context::exists {context} {
    if {$context eq ""} {set context "::"}
    return [info exists context::knownContext($context)]
}

# context::locate --
#
#	Given a current context and a qualified name,
#	locate the context.
#
# Arguments:
#	context		The local context.
#	name		The qualified name to find.
#	strip		Boolean indicating if the word containing
#			the context name should have the head stripped
#			off (i.e. "proc" vs. "namespace eval")
#
# Results:
#	The absolute context if one exists or empty string
#	if the context does not exist.

proc context::locate {context name {strip 1}} {

    #::log::log debug "CTX locate (($context) ($name) $strip)"

    # There are three possible scenarios for locating a context.
    # (1) The name is absolute. (begins with ::)  In this
    #     case, only search for the context in the absolute path
    #     specified by <name>.
    # (2) The name is qualified. (<relative> is not null)
    #     The context could exist in the concatenated path of
    #  	  <context>::<relative> or ::<relative>.
    # (3) The name is not qualified.  The context could exist
    #	  in <context> or ::.
    
    if {$strip} {
	set relative [namespace qualifiers $name]
    } else {
	set relative $name
    }

    if {[string match "::*" $name]} {
	set context [context::join :: $relative]
	set searchAltPath 0
    } elseif {$relative ne ""} {
	set context [context::join $context $relative]
	set searchAltPath 1
    } else {
	set searchAltPath 1
    }

    #::log::log debug "CTX locate (($context) ($name) saltp = $searchAltPath"

    # If the context is not found and name is not global, then
    # search for the existence of the context by making the
    # relative context global.

    if {[context::exists $context]} {
	#::log::log debug "CTX locate (($context) ($name) $strip)\t=A ($context)"

	return $context
    } elseif {($searchAltPath) && [context::exists ::$relative]} {
	#::log::log debug "CTX locate (($context) ($name) $strip)\t=B (::$relative)"

	return "::$relative"
    } else {
	#::log::log debug "CTX locate (($context) ($name) $strip)\t=C ()"

	return {}
    }
}

# context::join --
#
#	Do an intelligent join of the parent and child namespaces.
#
# Arguments:
#	parent	The parent namespace.
#	child	The child namespace.
#
# Results:
#	The join of the two namespaces.

proc context::join {parent child} {
    # If the child path is fully qualified, then return the child as
    # the join of the two.

    # If the parent's context is UNKNOWN then the childs context will
    # also be unknown. However, instead of naming it UNKNOWN we lump
    # everything together in the UNKNOWN namespace.

    # This will give rise to bogus redefine warnings if different
    # dynamic places define procedures of the same name. It is still
    # better than it was without the change. Because then all such
    # procedures were named UNKNOWN whatever their real names, causing
    # a much larger flood of bogus redefine warnings. The old style
    # further caused any command in a dynamic namespace eval to look
    # for its definition under UNKNOWN, find the bogus definitions
    # from before, and spit out procNumArgs errors.

    # Still, this is a deep change. While a search for uses of UNKNOWN
    # in the app showed nothing obviously affected we might have
    # missed something.

    # A second change made: We check for an FQN of the child first. If
    # the child is FQN the parent is irrelevant, even if unknown. The
    # old ordering was likely a bug.

    # Otherwise join the two together so the beginning of the context
    # has "::"s while the ending does not.

    #puts stderr "context::join \{[list $parent $child]\}"

    if {[string match "::*" $child]} {
	#puts stderr "\tchild only for fully qualified name"
	return $child
    } elseif {(0&&($parent eq "UNKNOWN")) || ($child eq "")} {
	#puts stderr "\tparent only for unknown parent or child"
	return $parent
    } else {
	#puts stderr "\tmerge"
	# If the parent is not the global context and does not
	# have trailing "::"s add them.  If the child has
	# leading "::"s strip them off.

	if {($parent ne "::") && ![string match "*::" $parent]} {
	    set parent "${parent}::"
	    #puts stderr "\textend parent for merge"
	}
	if {[string match "*::" $child]} {
	    #puts stderr "\ttrim child"
	    set child [string range $child 0 end-2]
	}
	#puts stderr "\tdone"
	return "${parent}${child}"
    }
}

# context::head --
#
#	Get the absolute qualifier for the context.  This is 
#	a wrapper around the "namespace qualifier" routine 
#	that turns empty strings into "::".
#
# Arguments:
#	context		A context to retrieve the head from.
#
# Results:
#	The qualified head of the context.

proc context::head {context} {
    set head [namespace qualifier $context]

    # If the head is null, and the context is fully qualified, set 
    # head to be :: so the fact that this context was fully qualified 
    # is not lost.

    if {($head eq "") && ([string match "::*" $context])} {
	set head "::"
    }
    return $head
}

# context::top --
#
#	Get the current context of the Checker.
#
# Arguments:
#	None.
#
# Results:
#	The current qualified context path.

proc context::top {} {
    #::log::log debug "CTX top = ([lindex $context::contextStack end])"
    return [lindex $context::contextStack end]
}

# context::push --
#
#	Set the current context of the Checker.
#
# Arguments:
#	context		The current qualified context path.
#
# Results:
#	None.

proc context::push {context} {
    #::log::log debug "CTX push = ($context)"
    lappend context::contextStack $context
    return
}

# context::pop --
#
#	Unset the current context of the Checker unless we're 
#	at the global context.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc context::pop {} {
    variable contextStack

    #::log::log debug "CTX pop"

    set len [llength $contextStack]
    if {$len > 1} {
	set contextStack [lrange $contextStack 0 end-1]
    }
    return
}

# context::topProtection --
#
#	Return the protection level on the top of the stack.
#
# Arguments:
#	None.
#
# Results:
#	The protection level on the top of the context stack or 
#	empty string if there is no context on the stack.

proc context::topProtection {} {
    return [lindex $context::protectionStack end]
}

# context::pushProtection --
#
#	Push a new context onto the context stack.  This is 
#	used to identify what type of body we are parsing and
#	which commands are valid.
#
# Arguments:
#	protection	A new protection level (public, private, or protected)
#
# Results:
#	None.

proc context::pushProtection {protection} {
    lappend context::protectionStack $protection
    return
}

# context::popProtection --
#
#	Pop the top of the protection stack.  This is called when
#	a protection command (public, protected, private) finishes.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc context::popProtection {} {
    variable protectionStack
    set len [llength $protectionStack]
    if {$len > 1} {
	set protectionStack [lrange $protectionStack 0 end-1]
    }
    return
}

# context::topScope --
#
#	Return the protection level on the top of the stack.
#
# Arguments:
#	None.
#
# Results:
#	The protection level on the top of the context stack or 
#	empty string if there is no context on the stack.

proc context::topScope {} {
    return [lindex $context::scopeStack end]
}


proc context::sizeScope {} {
    return [llength $context::scopeStack]
}

proc context::markScope {} {
    return [llength $context::scopeStack]
}

# context::pushScope --
#
#	Push a new context onto the context stack.  This is 
#	used to identify what type of body we are parsing and
#	which commands are valid.
#
# Arguments:
#	protection	A new protection level (public, private, or protected)
#
# Results:
#	None.

proc context::pushScope {scope} {
    #::log::log debug "CTX/SCOPE push = ($scope)"
    lappend context::scopeStack $scope
    return
}

# context::popScope --
#
#	Pop the top of the protection stack.  This is called when
#	a protection command (public, protected, private) finishes.
#
# Arguments:
#	None.
#
# Results:
#	None.

proc context::popScope {} {
    variable scopeStack
    set len [llength $scopeStack]
    if {$len > 1} {
	#::log::log debug "CTX/SCOPE pop"
	set scopeStack [lrange $scopeStack 0 end-1]
    }
    return
}

proc context::popScopeToMark {n} {
    variable scopeStack

    while {[llength $scopeStack] > $n} {
	#::log::log debug "CTX/SCOPE pop/n"
	set scopeStack [lrange $scopeStack 0 end-1]
    }
    return
}

proc context::globalScope {} {
    return {namespace :: {{} {} {}}}
}
