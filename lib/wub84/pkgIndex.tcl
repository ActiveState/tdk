# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
package ifneeded dictcompat 0.1 [list source [file join $dir dictcompat.tcl]]

package ifneeded Timer      1.0 [list source [file join $dir Timer.tcl]]
package ifneeded Pool       1.0 [list source [file join $dir Pool.tcl]]

package ifneeded Listener   1.0 [list source [file join $dir Listener.tcl]]
package ifneeded Httpd      1.0 [list source [file join $dir Httpd.tcl]]
package ifneeded Entity     1.0 [list source [file join $dir Entity.tcl]]
package ifneeded HttpUtils  1.0 [list source [file join $dir HttpUtils.tcl]]

