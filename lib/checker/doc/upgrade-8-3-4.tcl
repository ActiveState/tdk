# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-

#
# Example script containing tcl code using features above and beyond
# version 8.3.1 of the tcl core. This code is used to test the
# extended tclpro checker.
#

# === 8.3.4 ============ ============ ============ ============

package require http    2.4
package require msgcat  1.1.1
package require opt     0.4.3
package require tcltest 1.0.1

set list    {{a 1 e i} {b 2 3 f g} {c 4 5 6 d h}}
#  slist == {{c 4 5 6 d h} {a 1 e i} {b 2 3 f g}}

set slist [lsort -index end-1 $list]

auto_import      ::foo::* ; # find definition of old behaviour
namespace import ::foo::*

# console ; # more subcommands ? which subcommands changed ?

tkConsoleOutput file5 foo
tkConsoleExit
