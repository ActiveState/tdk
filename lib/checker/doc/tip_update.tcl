# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#

# Code to check the checker for the new stuff ...

radiobutton .rb -offrelief foo
radiobutton .rb -offrelief sunken

checkbutton .cb -offrelief foo
checkbutton .cb -offrelief sunken

wm attributes .
wm attributes . -topmost
wm attributes . -topmox
wm attributes . -topmost 1
wm attributes . -topmost foo

tk caret
tk caret .
tk caret . -x
tk caret . -x 0
tk caret . -x foo
tk caret . -kaboom 0

file link
file link -foo
file link -foo a
file link -foo a b
file link -hard a
file link -hard a b
file link -symbolic a
file link -symbolic a b

trace list command p
trace info command p
