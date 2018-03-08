# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# Debugging source invokations
# ----------------------------

rename ::source ::__source
proc   ::source {args} {
    puts SOURCE\ [join $args]
    uplevel 1 ::__source $args
}
