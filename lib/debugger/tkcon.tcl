# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
#exec wish "$0" ${1+"$@"}

#
## tkcon.tcl
## Enhanced Tk Console, part of the VerTcl system
##
## Originally based off Brent Welch's Tcl Shell Widget
## (from "Practical Programming in Tcl and Tk")
##
## Thanks to the following (among many) for bug reports & code ideas:
## Steven Wahl <steven@indra.com>, Jan Nijtmans <nijtmans@nici.kun.nl>
## Crimmins <markcrim@umich.edu>, Wart <wart@ugcs.caltech.edu>
##
## Copyright 1995-1997 Jeffrey Hobbs
## Initiated: Thu Aug 17 15:36:47 PDT 1995
##
## jeff.hobbs@acm.org, http://www.cs.uoregon.edu/~jhobbs/
##
## source standard_disclaimer.tcl
## source bourbon_ware.tcl
##

## FIX NOTES - ideas on the block:
## can tkConSplitCmd be used for debugging?
## can return/error be overridden for debugging?
## add double-click to proc editor or man page reader

if {[package vcompare 8.3 [package present Tk]] < 0} {
    # Added to allow usage of code by an 8.4 core.
    ::tk::unsupported::ExposePrivateCommand tkTextSetCursor
    ::tk::unsupported::ExposePrivateCommand tkTextUpDownLine
    ::tk::unsupported::ExposePrivateCommand tkTextTranspose 
    ::tk::unsupported::ExposePrivateCommand tkTextScrollPages
}

# ### ### ### ######### ######### #########
## Requisites

package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type tkCon {

    variable TKCON
    variable evalWin

    # ### ### ### ######### ######### #########

    constructor {ev root args} {
	set evalWin $ev
	$self SetupState $root
	#$self configurelist $args
    }
    destructor {}

    method SetupState {root} {
	array set TKCON {
	    color,blink	\#C7C7C7
	    color,proc	\#008800
	    color,var	\#ffc0d0
	    color,prompt	\#8F4433
	    color,stdin	\#000000
	    color,stdout	\#0000FF
	    color,stderr	\#FF0000
	    color,prompt2	\#00FF00

	    tag,prompt prompt

	    autoload	{}
	    blinktime	1000
	    blinkrange	0
	    cols		40
	    history		48
	    lightbrace	1
	    lightcmd	1
	    maxBuffer	200
	    rows		20
	    scrollypos	right
	    showmultiple	1
	    subhistory	1

	    appname		{}
	    namesp		::
	    cmd		{}
	    cmdbuf		{}
	    cmdsave		{}
	    event		1
	    histid		0
	    errorInfo	{}
	    version		1.1
	    release		{8 October 1997}
	    docs		{http://tkcon.sourceforge.net/}
	    email		{jeff (at) hobbs . org}
	    root		{}
	    console             {}
	}
	set TKCON(root)        $root ;# .evalDbgWin
	set TKCON(prompt1)     {[history nextid] % }
	set TKCON(A:version)   [info tclversion]
	set TKCON(A:namespace) [string compare {} [info commands namespace]]
	return
    }

    # ### ### ### ######### ######### #########


    ## method InitUI - inits UI portion (console) of tkCon
    ## Creates all elements of the console window and sets up the text tags
    # ARGS:	root	- widget pathname of the tkCon console root
    #	title	- title for the console root and main (.) windows
    # Calls:	 tkCon::Prompt
    ##
    method InitUI {w title} {
	set root $TKCON(root)
	set TKCON(base) $w

	# Update history and buffer info that may have been 
	# changed in the prefs window.
	$self update

	## Text Console
	set con [text $w.text -wrap char -padx 2 \
		     -font $font::metrics(-font) \
		     -yscrollcommand [list $w.sy set] \
		     -foreground $TKCON(color,stdin) \
		     -highlightthickness 0 \
		     -width $TKCON(cols) -height $TKCON(rows)]
	set TKCON(console) $con
	bindtags $con [list $con PreCon TkConsole$self PostCon$self \
		$root all]

	## Scrollbar
	set TKCON(scrolly) [scrollbar $w.sy -takefocus 0 \
				-command [list $con yview]]

	$self Bindings

	pack $w.sy -side $TKCON(scrollypos) -fill y
	pack $con -side left -fill both -expand true

	$self Prompt

	foreach col {prompt prompt2 stdout stderr stdin proc} {
	    $con tag configure $col -foreground $TKCON(color,$col)
	}
	$con tag configure var     -background $TKCON(color,var)
	$con tag configure blink   -background $TKCON(color,blink)
	$con tag configure disable -background gray75 -borderwidth 0

	return $TKCON(console)
    }

    # tkCon::update --
    #
    #	Update tkcon data in the TKCON array.
    #
    # Arguments:
    #	None.
    #
    # Results:
    #	None.

    method update {} {
	set TKCON(maxBuffer) [pref::prefGet screenSize]
	set TKCON(history)   [pref::prefGet historySize]
	history keep $TKCON(history)
    }

    ## method Eval - evaluates commands input into console window
    ## This is the first stage of the evaluating commands in the console.
    ## They need to be broken up into consituent commands (by tkCon::CmdSep) in
    ## case a multiple commands were pasted in, then each complete command
    ## is appended to one large statement and passed to tkCon::EvalCmd.  Any
    ## uncompleted command will not be eval'ed.
    # ARGS:	w	- console text widget
    # Calls:	tkCon::CmdGet, tkCon::CmdSep, tkCon::EvalCmd
    ## 
    method Eval {w} {
	set incomplete [$self CmdSep [$self CmdGet $w] cmds last]
	$w mark set insert end-1c
	$w insert end \n

	if {[llength $cmds]} {
	    set evalCmd {}
	    foreach c $cmds {
		append evalCmd "$c\n"
	    }
	    $self EvalCmd $w $evalCmd
	    $w insert insert $last {}
	} elseif {!$incomplete} {
	    $self EvalCmd $w $last
	}
	$w see insert
    }

    ## method EvalCmd - evaluates a single command, adding it to history
    # ARGS:	w	- console text widget
    # 	cmd	- the command to evaluate
    # Calls:	tkCon::Prompt
    # Outputs:	result of command to stdout (or stderr if error occured)
    # Returns:	next event number
    ## 
    method EvalCmd {w cmd} {

	$w mark set output end
	if {[string compare {} $cmd]} {
	    set code 0
	    if {$TKCON(subhistory)} {
		set ev [history nextid]
		incr ev -1
		if {[string match !! $cmd]} {
		    set code [catch {history event $ev} cmd]
		    if {!$code} {$w insert output $cmd\n stdin}
		} elseif {[regexp {^!(.+)$} $cmd dummy event]} {
		    ## Check last event because history event is broken
		    set code [catch {history event $ev} cmd]
		    if {!$code && ![string match ${event}* $cmd]} {
			set code [catch {history event $event} cmd]
		    }
		    if {!$code} {$w insert output $cmd\n stdin}
		} elseif {[regexp {^\^([^^]*)\^([^^]*)\^?$} $cmd dummy old new]} {
		    set code [catch {history event $ev} cmd]
		    if {!$code} {
			regsub -all -- $old $cmd $new cmd
			$w insert output $cmd\n stdin
		    }
		}
	    }
	    if {$code} {
		$w insert output $cmd\n stderr
	    } else {
		## We are about to evaluate the command, so move the limit
		## mark to ensure that further <Return>s don't cause double
		## evaluation of this command - for cases like the command
		## has a vwait or something in it
		$w mark set limit end
		history add $cmd
		set id [$evalWin evalCmd [list eval $cmd]]
		$w mark set result$id [$w index "end - 2 chars"]
	    }
	}
	$self Prompt
	set TKCON(event) [history nextid]
    }

    ## method EvalSlave - evaluates the args in the associated slave
    ## args should be passed to this procedure like they would be at
    ## the command line (not like to 'eval').
    # ARGS:	args	- the command and args to evaluate
    ##
    method EvalSlave {args} {
	return [$evalWin evalCmd $args]
    }

    method EvalResult {id code result errInfo errCode} {
	if {![winfo exists $TKCON(console)]} {
	    return
	}
	set w $TKCON(console)

	# If the index of the result is >= limit then the text
	# buffer was cleared and the marks have been altered.
	# Update the index to be the current "output" mark and
	# insert the newline before the result string.  Otherwise
	# the current result mark is valid, just insert the 
	# newine after the result.

	set index [$w index result$id]
	if {[$w compare $index >= limit]} {
	    set index output
	    set result $result\n
	} else {
	    set result \n$result
	}

	if {$code} {
	    set TKCON(errorInfo) $errInfo
	    $w insert $index $result stderr
	} elseif {[string compare {} $result]} {
	    $w insert $index $result stdout
	}
	$TKCON(console) see end
    }

    ## method CmdGet - gets the current command from the console widget
    # ARGS:	w	- console text widget
    # Returns:	text which compromises current command line
    ## 
    method CmdGet w {
	if {[string match {} [$w tag nextrange prompt limit end]]} {
	    $w tag add stdin limit end-1c
	    return [$w get limit end-1c]
	}
    }

    ## method CmdSep - separates multiple commands into a list and remainder
    # ARGS:	cmd	- (possible) multiple command to separate
    # 	list	- varname for the list of commands that were separated.
    #	last	- varname of any remainder (like an incomplete final command).
    #		If there is only one command, it's placed in this var.
    # Returns:	constituent command info in varnames specified by list & rmd.
    ## 
    method CmdSep {cmd list last} {
	upvar 1 $list cmds $last inc
	set inc {}
	set cmds {}
	foreach c [split [string trimleft $cmd] \n] {
	    if {[string compare $inc {}]} {
		append inc \n$c
	    } else {
		append inc [string trimleft $c]
	    }
	    if {[info complete $inc] && ![regexp {[^\\]\\$} $inc]} {
		if {[regexp "^\[^#\]" $inc]} {lappend cmds $inc}
		set inc {}
	    }
	}
	set i [string compare $inc {}]
	if {!$i && [string compare $cmds {}] && ![string match *\n $cmd]} {
	    set inc [lindex $cmds end]
	    set cmds [lreplace $cmds end end]
	}
	return $i
    }

    ## method CmdSplit - splits multiple commands into a list
    # ARGS:	cmd	- (possible) multiple command to separate
    # Returns:	constituent commands in a list
    ## 
    method CmdSplit {cmd} {
	set inc {}
	set cmds {}
	foreach cmd [split [string trimleft $cmd] \n] {
	    if {[string compare {} $inc]} {
		append inc \n$cmd
	    } else {
		append inc [string trimleft $cmd]
	    }
	    if {[info complete $inc] && ![regexp {[^\\]\\$} $inc]} {
		#set inc [string trimright $inc]
		if {[regexp "^\[^#\]" $inc]} {lappend cmds $inc}
		set inc {}
	    }
	}
	if {[regexp "^\[^#\]" $inc]} {lappend cmds $inc}
	return $cmds
    }

    ## method Prompt - displays the prompt in the console widget
    # ARGS:	w	- console text widget
    # Outputs:	prompt (specified in TKCON(prompt1)) to console
    ## 
    method Prompt {{pre {}} {post {}} {prompt {}}} {

	if {![winfo exists $TKCON(console)]} {
	    return
	}
	set w $TKCON(console)

	set buffer [lindex [split [$w index end] .] 0]
	if {$buffer > $TKCON(maxBuffer)} {
	    set newStart [expr {$buffer - $TKCON(maxBuffer)}]
	    $w delete 0.0 $newStart.0
	}

	if {[string compare {} $pre]} { $w insert end $pre stdout }
	set i [$w index end-1c]
	if {[string compare {} $TKCON(appname)]} {
	    $w insert end ">$TKCON(appname)< " prompt
	}
	if {[string compare :: $TKCON(namesp)]} {
	    $w insert end "<$TKCON(namesp)> " prompt
	}
	if {[string compare {} $prompt]} {
	    $w insert end $prompt TKCON(tag,prompt)
	} else {
	    $w insert end [subst $TKCON(prompt1)] TKCON(tag,prompt)
	}
	$w mark set output $i
	$w mark set insert end
	$w mark set limit insert
	$w mark gravity limit left
	if {[string compare {} $post]} { $w insert end $post stdin }
	$w see "end + 1 lines"
    }

    ## method Event - get history event, search if string != {}
    ## look forward (next) if $int>0, otherwise look back (prev)
    # ARGS:	W	- console widget
    ##
    method Event {int {str {}}} {
	if {!$int} return

	if {![winfo exists $TKCON(console)]} {
	    return
	}
	set w $TKCON(console)

	set nextid [history nextid]
	if {[string compare {} $str]} {
	    ## String is not empty, do an event search
	    set event $TKCON(event)
	    if {$int < 0 && $event == $nextid} { set TKCON(cmdbuf) $str }
	    set len [string len $TKCON(cmdbuf)]
	    incr len -1
	    if {$int > 0} {
		## Search history forward
		while {$event < $nextid} {
		    if {[incr event] == $nextid} {
			$w delete limit end
			$w insert limit $TKCON(cmdbuf)
			break
		    } elseif {
			![catch {history event $event} res] &&
			![string compare $TKCON(cmdbuf) [string range $res 0 $len]]
		    } {
			$w delete limit end
			$w insert limit $res
			break
		    }
		}
		set TKCON(event) $event
	    } else {
		## Search history reverse
		while {![catch {history event [incr event -1]} res]} {
		    if {![string compare $TKCON(cmdbuf) \
			    [string range $res 0 $len]]} {
			$w delete limit end
			$w insert limit $res
			set TKCON(event) $event
			break
		    }
		}
	    } 
	} else {
	    ## String is empty, just get next/prev event
	    if {$int > 0} {
		## Goto next command in history
		if {$TKCON(event) < $nextid} {
		    $w delete limit end
		    if {[incr TKCON(event)] == $nextid} {
			$w insert limit $TKCON(cmdbuf)
		    } else {
			$w insert limit [history event $TKCON(event)]
		    }
		}
	    } else {
		## Goto previous command in history
		if {$TKCON(event) == $nextid} {
		    set TKCON(cmdbuf) [$self CmdGet $w]
		}
		if {[catch {history event [incr TKCON(event) -1]} res]} {
		    incr TKCON(event)
		} else {
		    $w delete limit end
		    $w insert limit $res
		}
	    }
	}
	$w mark set insert end
	$w see end
    }

    ##
    ## Some procedures to make up for lack of built-in shell commands
    ##

    ## clear - clears the buffer of the console (not the history though)
    ## This is executed in the parent interpreter
    ## 
    method clear {{pcnt 100}} {

	if {![winfo exists $TKCON(console)]} {
	    return
	}

	if {![regexp {^[0-9]*$} $pcnt] || $pcnt < 1 || $pcnt > 100} {
	    return -code error \
		    "invalid percentage to clear: must be 1-100 (100 default)"
	} elseif {$pcnt == 100} {
	    $TKCON(console) delete 1.0 end
	} else {
	    set tmp [expr {$pcnt/100.0*[tkcon console index end]}]
	    $TKCON(console) delete 1.0 "$tmp linestart"
	}
    }

    method Bindings {} {

	global tcl_platform tk_version

	#-----------------------------------------------------------------------
	# Elements of tkPriv that are used in this file:
	#
	# char -		Character position on the line;  kept in order
	#			to allow moving up or down past short lines while
	#			still remembering the desired position.
	# mouseMoved -	Non-zero means the mouse has moved a significant
	#			amount since the button went down (so, for example,
	#			start dragging out a selection).
	# prevPos -		Used when moving up or down lines via the keyboard.
	#			Keeps track of the previous insert position, so
	#			we can distinguish a series of ups and downs, all
	#			in a row, from a new up or down.
	# selectMode -	The style of selection currently underway:
	#			char, word, or line.
	# x, y -		Last known mouse coordinates for scanning
	#			and auto-scanning.
	#-----------------------------------------------------------------------

	switch -glob $tcl_platform(platform) {
	    win*	{ set TKCON(meta) Alt }
	    mac*	{ set TKCON(meta) Command }
	    default	{ set TKCON(meta) Meta }
	}

	## Get all Text bindings into TkConsole
	foreach ev [bind Text] {
	    bind TkConsole$self $ev [bind Text $ev]
	}	
	## We really didn't want the newline insertion
	bind TkConsole$self <Control-Key-o> {}

	## Now make all our virtual event bindings

	foreach {ev key} [subst -nocommand -noback {
	    <<TkCon_Tab>>		<Control-i>
	    <<TkCon_Tab>>		<$TKCON(meta)-i>
	    <<TkCon_Eval>>		<Return>
	    <<TkCon_Eval>>		<KP_Enter>
	    <<TkCon_Clear>>		<Control-l>
	    <<TkCon_PreviousImmediate>>	<Up>
	    <<TkCon_PreviousImmediate>>	<Control-p>
	    <<TkCon_PreviousSearch>>	<Control-r>
	    <<TkCon_NextImmediate>>		<Down>
	    <<TkCon_NextImmediate>>	<Control-n>
	    <<TkCon_NextSearch>>	<Control-s>
	    <<TkCon_Transpose>>	<Control-t>
	    <<TkCon_ClearLine>>	<Control-u>
	    <<TkCon_SaveCommand>>	<Control-z>
	}] {
	    event add $ev $key
	    ## Make sure the specific key won't be defined
	    bind TkConsole$self $key {}
	}

	## Redefine for TkConsole what we need
	##
	event delete <<Paste>> <Control-V>
	$self ClipboardKeysyms <Copy> <Cut> <Paste>

	bind TkConsole$self <Insert> [mymethod BInsert %W]
	bind TkConsole$self <Triple-1> "+[mymethod BTriple1 %W]"

	## binding editor needed
	## binding <events> for .tkconrc

	bind TkConsole$self <<TkCon_Tab>>  [mymethod BTkCon_Tab %W]
	bind TkConsole$self <<TkCon_Eval>> [mymethod Eval %W]

	bind TkConsole$self <Delete> {
	    if {[string compare {} [%W tag nextrange sel 1.0 end]] \
		    && [%W compare sel.first >= limit]} {
		%W delete sel.first sel.last
	    } elseif {[%W compare insert >= limit]} {
		%W delete insert
		%W see insert
	    }
	}
	bind TkConsole$self <BackSpace> {
	    if {[string compare {} [%W tag nextrange sel 1.0 end]] \
		    && [%W compare sel.first >= limit]} {
		%W delete sel.first sel.last
	    } elseif {[%W compare insert != 1.0] && [%W compare insert > limit]} {
		%W delete insert-1c
		%W see insert
	    }
	}
	bind TkConsole$self <Control-h> [bind TkConsole$self <BackSpace>]

	bind TkConsole$self <KeyPress> [mymethod Insert %W %A]
	bind TkConsole$self <Control-a> {
	    if {[%W compare {limit linestart} == {insert linestart}]} {
		tkTextSetCursor %W limit
	    } else {
		tkTextSetCursor %W {insert linestart}
	    }
	}
	bind TkConsole$self <Control-d> {
	    if {[%W compare insert < limit]} break
	    %W delete insert
	}
	bind TkConsole$self <Control-k> {
	    if {[%W compare insert < limit]} break
	    if {[%W compare insert == {insert lineend}]} {
		%W delete insert
	    } else {
		%W delete insert {insert lineend}
	    }
	}
	bind TkConsole$self <<TkCon_Clear>>    [mymethod BTkCon_Clear %W]
	bind TkConsole$self <<TkCon_Previous>> [mymethod BTkCon_Previous %W]
	bind TkConsole$self <<TkCon_Next>>     [mymethod BTkCon_Next %W]

	bind TkConsole$self <<TkCon_NextImmediate>>     [mymethod Event 1]
	bind TkConsole$self <<TkCon_PreviousImmediate>> [mymethod Event -1 ]

	bind TkConsole$self <<TkCon_PreviousSearch>> [mymethod BTkCon_PreviousSearch %W]
	bind TkConsole$self <<TkCon_NextSearch>>	[mymethod BTkCon_NextSearch %W]

	bind TkConsole$self <<TkCon_Transpose>>	{
	    ## Transpose current and previous chars
	    if {[%W compare insert > "limit+1c"]} { tkTextTranspose %W }
	}
	bind TkConsole$self <<TkCon_ClearLine>> {
	    ## Clear command line (Unix shell staple)
	    %W delete limit end
	}
	bind TkConsole$self <<TkCon_SaveCommand>> [mymethod BTkCon_SaveCommand %W]

	## Bugzilla 18397. Ensure that our settings for the arrow keys
	## (see virtual bindings above) are not overidden here anymore.
	##
	##catch {bind TkConsole$self <Key-Up>   { tkTextScrollPages %W -1 }}
	##catch {bind TkConsole$self <Key-Down> { tkTextScrollPages %W 1 }}

	catch {bind TkConsole$self <Key-Prior>     { tkTextScrollPages %W -1 }}
	catch {bind TkConsole$self <Key-Next>      { tkTextScrollPages %W 1 }}
	bind TkConsole$self <$TKCON(meta)-d> {
	    if {[%W compare insert >= limit]} {
		%W delete insert {insert wordend}
	    }
	}
	bind TkConsole$self <$TKCON(meta)-BackSpace> {
	    if {[%W compare {insert -1c wordstart} >= limit]} {
		%W delete {insert -1c wordstart} insert
	    }
	}
	bind TkConsole$self <$TKCON(meta)-Delete> {
	    if {[%W compare insert >= limit]} {
		%W delete insert {insert wordend}
	    }
	}
	bind TkConsole$self <ButtonRelease-2> [mymethod BBR2 %W %x %y]


	##
	## End TkConsole bindings
	##

	##
	## Bindings for doing special things based on certain keys
	##
	bind PostCon$self <Key-parenright>   [mymethod BKey-parenright %W]
	bind PostCon$self <Key-bracketright> [mymethod BKey-bracketright %W]
	bind PostCon$self <Key-braceright>   [mymethod BKey-braceright %W]
	bind PostCon$self <Key-quotedbl>     [mymethod Key-quotedbl %W]
	return
    }

    method BTriple1 {w} {
	catch {
	    eval $w tag remove sel [$w tag nextrange prompt sel.first sel.last]
	    eval $w tag remove sel sel.last-1c
	    $w mark set insert sel.first
	}
    }
    method BInsert {w} {
	catch {
	    $self Insert $w [selection get -displayof $w]
	}
    }
    method BTkCon_Tab {w} {
	if {[$w compare insert >= limit]} {
	    $self Insert $w \t
	}
    }
    method BTkCon_Clear {w} {
	## Clear console buffer, without losing current command line input
	set TKCON(tmp) [$self CmdGet $w]
	$self clear
	$self Prompt {} $TKCON(tmp)
	return
    }
    method BTkCon_Previous {w} {
	if {[$w compare {insert linestart} != {limit linestart}]} {
	    tkTextSetCursor $w [tkTextUpDownLine $w -1]
	} else {
	    $self Event -1
	}
    }
    method BTkCon_Next {w} {
	if {[$w compare {insert linestart} != {end-1c linestart}]} {
	    tkTextSetCursor $w [tkTextUpDownLine $w 1]
	} else {
	    $self Event 1
	}
    }
    method BTkCon_PreviousSearch {w} {
	$self Event -1 [$self CmdGet $w] 
    }
    method BTkCon_NextSearch {w} {
	$self Event 1 [$self CmdGet $w] 
    }
    method BTkCon_SaveCommand {w} {
	## Save command buffer (swaps with current command)
	set TKCON(tmp) $TKCON(cmdsave)
	set TKCON(cmdsave) [$self CmdGet $w]
	if {[string match {} $TKCON(cmdsave)]} {
	    set TKCON(cmdsave) $TKCON(tmp)
	} else {
	    $w delete limit end-1c
	}
	$self Insert $w $TKCON(tmp)
	$w see end
    }
    method BBR2 {w x y} {
	global tkPriv
	if {
	    (!$tkPriv(mouseMoved) || $::tk_strictMotif) &&
	    (![catch {selection get -displayof $w} TKCON(tmp)] ||
	    ![catch {selection get -displayof $w -type TEXT} TKCON(tmp)]
	    || ![catch {selection get -displayof $w
	    -selection CLIPBOARD} TKCON(tmp)])
	} {
	    if {[$w compare @$x,$y < limit]} {
		$w insert end $TKCON(tmp)
	    } else {
		$w insert @$x,$y $TKCON(tmp)
	    }
	    if {[string match *\n* $TKCON(tmp)]} {
		$self Eval $w
	    }
	}
    }
    method BKey-parenright {w} {
	if {$TKCON(lightbrace) && $TKCON(blinktime)>99 && \
		[string compare \\ [$w get insert-2c]]} {
	    $self MatchPair $w \( \) limit
	}
    }
    method BKey-bracketright {w} {
	if {$TKCON(lightbrace) && $TKCON(blinktime)>99 && \
		[string compare \\ [$w get insert-2c]]} {
	    $self MatchPair $w \[ \] limit
	}
    }
    method BKey-braceright {w} {
	if {$TKCON(lightbrace) && $TKCON(blinktime)>99 && \
		[string compare \\ [$w get insert-2c]]} {
	    $self MatchPair $w \{ \} limit
	}
    }
    method Key-quotedbl {w} {
	if {$TKCON(lightbrace) && $TKCON(blinktime)>99 && \
		[string compare \\ [$w get insert-2c]]} {
	    $self MatchQuote $w limit
	}
    }

    # tkCon::ClipboardKeysyms --
    # This procedure is invoked to identify the keys that correspond to
    # the "copy", "cut", and "paste" functions for the clipboard.
    #
    # Arguments:
    # copy -	Name of the key (keysym name plus modifiers, if any,
    #		such as "Meta-y") used for the copy operation.
    # cut -		Name of the key used for the cut operation.
    # paste -	Name of the key used for the paste operation.

    method ClipboardKeysyms {copy cut paste} {
	bind TkConsole$self <$copy>	[mymethod Copy  %W]
	bind TkConsole$self <$cut>	[mymethod Cut   %W]
	bind TkConsole$self <$paste>	[mymethod Paste %W]
    }

    method Cut w {
	if {[string match $w [selection own -displayof $w]]} {
	    clipboard clear -displayof $w
	    catch {
		clipboard append -displayof $w [selection get -displayof $w]
		if {[$w compare sel.first >= limit]} {
		    $w delete sel.first sel.last
		}
	    }
	}
    }
    method Copy w {
	if {[string match $w [selection own -displayof $w]]} {
	    clipboard clear -displayof $w
	    catch {
		clipboard append -displayof $w [selection get -displayof $w]
	    }
	}
    }
    ## Try and get the default selection, then try and get the selection
    ## type TEXT, then try and get the clipboard if nothing else is available
    ## Why?  Because the Kanji patch screws up the selection types.
    method Paste w {
	if {
	    ![catch {selection get -displayof $w} tmp] ||
	    ![catch {selection get -displayof $w -type TEXT} tmp] ||
	    ![catch {selection get -displayof $w -selection CLIPBOARD} tmp] ||
	    ![catch {selection get -displayof $w -selection CLIPBOARD \
		    -type STRING} tmp]
	} {
	    if {[$w compare insert < limit]} {
		$w mark set insert end
	    }
	    $w insert insert $tmp
	    $w see insert
	    if {[string match *\n* $tmp]} {
		$self Eval $w
	    }
	}
    }

    ## method MatchPair - blinks a matching pair of characters
    ## c2 is assumed to be at the text index 'insert'.
    ## This proc is really loopy and took me an hour to figure out given
    ## all possible combinations with escaping except for escaped \'s.
    ## It doesn't take into account possible commenting... Oh well.  If
    ## anyone has something better, I'd like to see/use it.  This is really
    ## only efficient for small contexts.
    # ARGS:	w	- console text widget
    # 	c1	- first char of pair
    # 	c2	- second char of pair
    # Calls:	tkCon::Blink
    ## 
    method MatchPair {w c1 c2 {lim 1.0}} {
	if {[string compare {} [set ix [$w search -back $c1 insert $lim]]]} {
	    while {
		[string match {\\} [$w get $ix-1c]] &&
		[string compare {} [set ix [$w search -back $c1 $ix-1c $lim]]]
	    } {}
	    set i1 insert-1c
	    while {[string compare {} $ix]} {
		set i0 $ix
		set j 0
		while {[string compare {} [set i0 [$w search $c2 $i0 $i1]]]} {
		    append i0 +1c
		    if {[string match {\\} [$w get $i0-2c]]} continue
		    incr j
		}
		if {!$j} break
		set i1 $ix
		while {$j && [string compare {} \
			[set ix [$w search -back $c1 $ix $lim]]]} {
		    if {[string match {\\} [$w get $ix-1c]]} continue
		    incr j -1
		}
	    }
	    if {[string match {} $ix]} { set ix [$w index $lim] }
	} else { set ix [$w index $lim] }

	if {$TKCON(blinkrange)} {
	    $self Blink $w $ix [$w index insert]
	} else {
	    $self Blink $w $ix $ix+1c [$w index insert-1c] [$w index insert]
	}
    }

    ## method MatchQuote - blinks between matching quotes.
    ## Blinks just the quote if it's unmatched, otherwise blinks quoted string
    ## The quote to match is assumed to be at the text index 'insert'.
    # ARGS:	w	- console text widget
    # Calls:	tkCon::Blink
    ## 
    method MatchQuote {w {lim 1.0}} {
	set i insert-1c
	set j 0
	while {[string compare [set i [$w search -back \" $i $lim]] {}]} {
	    if {[string match {\\} [$w get $i-1c]]} continue
	    if {!$j} {set i0 $i}
	    incr j
	}
	if {[expr {$j&1}]} {
	    if {$TKCON(blinkrange)} {
		$self Blink $w $i0 [$w index insert]
	    } else {
		$self Blink $w $i0 $i0+1c [$w index insert-1c] [$w index insert]
	    }
	} else {
	    $self Blink $w [$w index insert-1c] [$w index insert]
	}
    }

    ## method Blink - blinks between n index pairs for a specified duration.
    # ARGS:	w	- console text widget
    # 	i1	- start index to blink region
    # 	i2	- end index of blink region
    # 	dur	- duration in usecs to blink for
    # Outputs:	blinks selected characters in $w
    ## 
    method Blink {w args} {
	eval $w tag add blink $args
	after $TKCON(blinktime) eval $w tag remove blink $args
	return
    }


    ## method Insert
    ## Insert a string into a text console at the point of the insertion cursor.
    ## If there is a selection in the text, and it covers the point of the
    ## insertion cursor, then delete the selection before inserting.
    # ARGS:	w	- text window in which to insert the string
    # 	s	- string to insert (usually just a single char)
    # Outputs:	$s to text widget
    ## 
    method Insert {w s} {
	if {[string match {} $s] || [string match disabled [$w cget -state]]} {
	    return
	}
	if {[$w comp insert < limit]} {
	    $w mark set insert end
	}
	catch {
	    if {[$w comp sel.first <= insert] && [$w comp sel.last >= insert]} {
		$w delete sel.first sel.last
	    }
	}
	$w insert insert $s
	$w see insert
    }

    method Stdout {chanid text} {
	if {![winfo exists $TKCON(console)]} {
	    return
	}
	set w $TKCON(console)

	if {[string equal $chanid STDERR]} {
	    $w insert end $text stderr
	} else {
	    $w insert end $text stdout
	}
	$TKCON(console) see end

	# Ensure that the logged characters are
	# not considered as command input.

	$w mark set output [$w index end-1c]
	$w mark set insert end
	$w mark set limit insert
	return
    }

    method ConGets {cmd} {
	if {![winfo exists $TKCON(console)]} {
	    return
	}
	set w $TKCON(console)

	set old [bind TkConsole$self <<TkCon_Eval>>]

	bind TkConsole$self <<TkCon_Eval>> [list \
		set [varname TKCON](wait) 0 \
		]

	set w $TKCON(console)

	$w insert end \n

	#set TKCON(tag,prompt) prompt2
	$self Prompt {} {} "(STDIN: $cmd) % "
	#set TKCON(tag,prompt) prompt

	set             TKCON(wait) 1
	vwait [varname TKCON](wait)

	set line [$self CmdGet $w]

	$w insert end \n
	bind TkConsole$self <<TkCon_Eval>> $old

	# Ensure that the new characters are
	# not considered as command input later on.

	$w mark set output [$w index end-1c]
	$w mark set insert end
	$w mark set limit insert

	return $line
    }
}
# ### ### ### ######### ######### #########

package provide tkCon 1.0
