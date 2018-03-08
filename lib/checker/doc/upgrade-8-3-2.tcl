# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-

#
# Example script containing tcl code using features above and beyond
# version 8.3.1 of the tcl core. This code is used to test the
# extended tclpro checker.
#

# === 8.3.2 ============ ============ ============

# ________________________________________________
# Changes in Tcl ...

# ________________________________________________
# New and modified packages

package require msgcat 1.1 ; # This is a 8.3.1. feature           
package require msgcat	   ; # Notify that newer version available

# ________________________________________________
# Changes in Tk ...

# ________________________________________________
# Labels got a -state option (normal|active|disabled) ...

label .l -text foo -state active
label .l -text foo -state normal
label .l -text foo -state disabled
label .l -text foo -state ...invalid_state...

.l configure -state active
.l configure -state disabled
.l configure -state normal
.l configure -state ...invalid_state...


