# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-

#
# Example script containing tcl code using features above and beyond
# version 8.3.1 of the tcl core. This code is used to test the
# extended tclpro checker.
#

# === 8.3.1 ============ ============ ============

# ________________________________________________
# Changes in Tcl ...

# ________________________________________________
# New and modified packages

package require http 2.3 ; # This is a 8.3.1. feature
package require http     ; # Notify that newer version available

# ________________________________________________
# Extended syntax

set uim [tk useinputmethods]
tk useinputmethods on
tk useinputmethods off
tk useinputmethods bar
