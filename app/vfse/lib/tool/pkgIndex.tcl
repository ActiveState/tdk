# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# Index for all megawidgets used by the vfse
# ====================================================

package ifneeded file::open    0.1 [list source [file join $dir fopen.tcl]]

package ifneeded fproperty 0.2 [list source [file join $dir properties.tcl]]

# Filesystem browser ...

package ifneeded fsb   0.2 [list source [file join $dir fsb.tcl]]
package ifneeded fsv   0.1 [list source [file join $dir fsv.tcl]]

# Win32 exe/dll version info reader

package ifneeded exe       0.1 [list source [file join $dir exe.tcl]]
