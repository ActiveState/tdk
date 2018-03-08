# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 {set {version($Id: main.tcl,v 1.7 2006/06/10 15:25:37 danielk1977 Exp $)} 1}

package require starkit
starkit::startup
set ::HV3_STARKIT 1
source [file join [file dirname [info script]] hv3_main.tcl] 

