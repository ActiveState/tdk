# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#

# This script tests the new jump rewrite code added to fix bug 87738.
# Without the rewrite, compiler will emit code where the proc calls
# are expanded to hold the tbcload::bcproc literal, yet the 'jump'
# instruction for the 'if' segment is not updated and thus pointing to
# the wrong instruction, or into the middle of one, with subsequent
# crash.

package require compiler

set in   procliteral.tcl
set out  procliteral.tbc
set chan [open $in w]

# Big set of literals
for {set i 0} {$i < 500} {incr i} {
    puts $chan [list proc p$i {args} { puts nothing }]
}

# And a procedure defined conditional, to have jumps around its code.
puts $chan {
    set x 0
    if {$x} {
	proc shifting {} { puts gone }
    }
}
close $chan

# Generate the bytecode
compiler::compile $in $out

# Run it, must not crash.
source $out
file delete $in $out
