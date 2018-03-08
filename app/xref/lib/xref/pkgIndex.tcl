# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# Index for all megawidgets used by the xref-frontend.
# ====================================================

## Attic ...
## ### #### ##### ###### ####### ######## #########
## package ifneeded mktable  0.1 [list source [file join $dir mktable.tcl]]
## package ifneeded ttable   0.1 [list source [file join $dir ttable.tcl]]
## ### #### ##### ###### ####### ######## #########

package ifneeded xref_gather   0.1 [list source [file join $dir xref_gather.tcl]]
package ifneeded tap_gather    0.1 [list source [file join $dir tap_gather.tcl]]
package ifneeded kpj_gather    0.1 [list source [file join $dir kpj_gather.tcl]]
package ifneeded tclapp_gather 0.1 [list source [file join $dir tclapp_gather.tcl]]
package ifneeded teapot_gather 0.1 [list source [file join $dir teapot_gather.tcl]]

package ifneeded arrow       0.1 [list source [file join $dir arrows.tcl]]
package ifneeded ftext       0.1 [list source [file join $dir ftext.tcl]]
package ifneeded mklabel     0.1 [list source [file join $dir mklabel.tcl]]
package ifneeded mkvtree     0.1 [list source [file join $dir mkvtree.tcl]]

package ifneeded mkfilter  0.1 [list source [file join $dir mkfilter.tcl]]
package ifneeded mkfilterd 0.1 [list source [file join $dir mkfilterd.tcl]]

package ifneeded listctrl 0.1 [list source [file join $dir listctrl.tcl]]
package ifneeded mklist   0.2 [list source [file join $dir mklist.tcl]]

package ifneeded mkdb         0.1 [list source [file join $dir mkdb.tcl]]
package ifneeded xrefdb       0.1 [list source [file join $dir xref_db.tcl]]
package ifneeded xrefchilddef 0.1 [list source [file join $dir xr_cd.tcl]]
package ifneeded xrefchilddeffile 0.1 [list source [file join $dir xr_cdf.tcl]]

package ifneeded xmainframe 0.2 [list source [file join $dir xref_mainframe.tcl]]

package ifneeded xmain    0.1 [list source [file join $dir xref_main.tcl]]

package ifneeded xdfile   0.1 [list source [file join $dir xref_dfile.tcl]]
package ifneeded xdloc    0.1 [list source [file join $dir xref_dloc.tcl]]
package ifneeded xdns     0.1 [list source [file join $dir xref_dns.tcl]]
package ifneeded xdcmd    0.1 [list source [file join $dir xref_dcmd.tcl]]
package ifneeded xdvar    0.1 [list source [file join $dir xref_dvar.tcl]]
package ifneeded xdpkg    0.1 [list source [file join $dir xref_dpkg.tcl]]

package ifneeded xlfile      0.1 [list source [file join $dir xref_lfile.tcl]]
package ifneeded xlloc       0.1 [list source [file join $dir xref_lloc.tcl]]
package ifneeded xllocfl     0.1 [list source [file join $dir xref_llocfl.tcl]]
package ifneeded xlloccmddef 0.1 [list source [file join $dir xref_lloccmddef.tcl]]
package ifneeded xllocvardef 0.1 [list source [file join $dir xref_llocvardef.tcl]]
package ifneeded xldefined   0.1 [list source [file join $dir xref_ldefined.tcl]]
package ifneeded xlns        0.1 [list source [file join $dir xref_lns.tcl]]
package ifneeded xlcmd       0.1 [list source [file join $dir xref_lcmd.tcl]]
package ifneeded xlcall      0.1 [list source [file join $dir xref_lcall.tcl]]
package ifneeded xlvar       0.1 [list source [file join $dir xref_lvar.tcl]]
package ifneeded xlvarcmd    0.1 [list source [file join $dir xref_lvarcmd.tcl]]
package ifneeded xlpkg       0.1 [list source [file join $dir xref_lpkg.tcl]]
