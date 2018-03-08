# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Tcl package index file
# ### ######### ###########################
## Public API. 

package ifneeded checker 1.4 [list source [file join $dir checker.tcl]]

# ### ######### ###########################
## Internal. 

package ifneeded pcx       1.0 [list source [file join $dir pcx.tcl]]
package ifneeded cdb       1.0 [list source [file join $dir cdb.tcl]]
package ifneeded userproc  1.0 [list source [file join $dir userproc.tcl]]
package ifneeded xref      1.0 [list source [file join $dir xref.tcl]]
package ifneeded timeline  1.0 [list source [file join $dir timeline.tcl]]
package ifneeded configure 1.0 [list source [file join $dir configure.tcl]]
package ifneeded message   1.0 [list source [file join $dir message.tcl]]

package ifneeded analyzer       1.0 [list source [file join $dir analyzer.tcl]]
package ifneeded location       1.0 [list source [file join $dir location.tcl]]
package ifneeded context        1.0 [list source [file join $dir context.tcl]]
package ifneeded filter         1.0 [list source [file join $dir filter.tcl]]
package ifneeded checkerCmdline 1.0 [list source [file join $dir checkerCmdline.tcl]]

# ### ######### ###########################
