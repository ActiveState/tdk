# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-

#
# Example script containing tcl code using features above and beyond
# version 8.3.1 of the tcl core. This code is used to test the
# extended tclpro checker.
#

# === 8.3.3 ============ ============ ============ ============

package require opt 0.4.2

expr {![set a on]}
scan [format %o -1] %o v
scan [format %x -1] %x v

wm iconbitmap . -default foo.ico
wm iconbitmap . -def     foo.ico
wm iconbitmap . foo.ico




