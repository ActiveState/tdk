# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# pkgIndex.tcl --
#
#	This file contains the package index for the Tcl Wrapper UI.
#	Assumes that all files, even shared code is in the same directory.
#
# Copyright (c) 2002-2007 ActiveState Software Inc.
# All rights reserved.
# 
# RCS: @(#) $Id: pkgIndex.tcl.in,v 1.6 2000/07/26 04:51:40 welch Exp $

package ifneeded ipeditor                           1.0 [list source [file join $dir ipeditor.tcl]]
package ifneeded mdeditor                           1.0 [list source [file join $dir mdeditor.tcl]]
package ifneeded page                               1.0 [list source [file join $dir page.tcl]]
package ifneeded pkgman                             1.0 [list source [file join $dir pkgman.tcl]]
package ifneeded pkgman::architectures              1.0 [list source [file join $dir pkgman_s.tcl]]
package ifneeded pkgman::archives                   1.0 [list source [file join $dir pkgman_a.tcl]]
package ifneeded pkgman::packages                   1.0 [list source [file join $dir pkgman_p.tcl]]
package ifneeded pkgman::plist                      1.0 [list source [file join $dir plist.tcl]]
package ifneeded pkgman::scanfiles                  1.0 [list source [file join $dir pkgscan.tcl]]
package ifneeded pkgman::tap                        1.0 [list source [file join $dir pkgman_t.tcl]]
package ifneeded sieditor                           1.0 [list source [file join $dir sieditor.tcl]]
package ifneeded tclapp::pref                       1.0 [list source [file join $dir tclapp_pref.tcl]]
package ifneeded tclapp::prjrepo                    1.0 [list source [file join $dir repo.tcl]]
package ifneeded tcldevkit::wrapper                 1.0 [list source [file join $dir wrapper.tcl]]
package ifneeded tcldevkit::wrapper::appOptsWidget  1.0 [list source [file join $dir appOptsWidget.tcl]]
package ifneeded tcldevkit::wrapper::fileWidget     1.0 [list source [file join $dir fileWidget.tcl]]
package ifneeded tcldevkit::wrapper::sysOptsWidget  1.0 [list source [file join $dir sysOptsWidget.tcl]]
package ifneeded tcldevkit::wrapper::wrapOptsWidget 1.0 [list source [file join $dir wrapOptsWidget.tcl]]
