# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# ### ### ### ######### ######### #########
## Requirements

package require fileutil
package require fileutil::traverse
package require snit
package require sqlite3
package require struct::list
package require tdom
package require htmlparse ; # Entity mapping
#Debug
#package require fileutil::magic::mimetype
#package require md5 2

# ### ### ### ######### ######### #########
## Database version information

namespace eval ::ashelp {
    ::variable revisioninfo
    array set  revisioninfo {
	name    ASHELP
	version 0.1
	rcsid   {$Id$}
    }
    ::variable untitled {<< Untitled >>}
}

# ### ### ### ######### ######### #########
## Accessor class

snit::type ashelp {

    # Construct a help file in the specified location. The path must
    # not exist beforehand. It will exist after sucessful completion
    # of the command.

    typemethod new {location} {
	if {[$type valid $location ro msg]} {
	    return -code error \
		"Cannot create help file at $location, already present."
	}

	set           db ${type}::TEMP
	sqlite3      $db [file nativename $location]
	_setupTables $db
	$db close
	return
    }

    # Validate the the specified file can be used as a help file.

    typemethod valid {location mode mv} {
	upvar 1 $mv message

	if {$mode eq "rw"} {
	    set mode efrw
	} elseif {$mode eq "ro"} {
	    set mode efr
	} else {
	    return -code error "Bad mode \"$mode\""
	}

	if {![fileutil::test $location $mode message "Help file"]} {
	    return 0
	}

	set loc [file nativename $location]

	set db ${type}::TEMP
	if {[catch {sqlite3 $db $loc} msg]} {
	    set message "File $location: $msg"
	    return 0
	}

	set ok [_hasTables $db message]
	$db close
	return $ok
    }

    typemethod getTitle {path} {
	return [_get_title [fileutil::cat $path]]
    }

    # Construct a Table of Contents usable by ashelp from an
    # ActiveState toc.xml file.

    typemethod toc.xml {tocfile} {
	set toc {}

	# FUTURE?! Look in the directories references by the leaf
	# nodes for more toc.xml files with which we can extend the
	# logical tree. This will allow code generating a doc
	# hierarchy to create the table of contents in pieces.

	# Alternative: Add commands to extend / prune the TOC, and
	# move this extended functionality one level higher, into the
	# application.

	set doc  [dom parse [fileutil::cat $tocfile]]
	set root [$doc documentElement]

	# Start an iterative recursion over the dom tree, depth-first
	# pre-order.

	set toc {}
	array set map {}
	set map($root) 0

	set tn [$root getAttribute name]
	set tv [$root getAttribute version]

	set pending [struct::list reverse [$root childNodes]]
	set at 0
	set first {}

	while {[llength $pending]} {
	    # Pull next node to visit, and ignore non-'node' nodes.
	    set node    [lindex   $pending end]
	    set pending [lreplace $pending end end]
	    if {[$node nodeName] ne "node"} continue

	    # Node information to put into the TOC.
	    set label [$node getAttribute name]
	    if {[catch {
		set link  [$node getAttribute link]
	    }]} {
		set link {} ; # Node without page to show.
	    }

	    # Save first link, for use by the toc root (as the root
	    # has no explicit link in its XML attributes).
	    if {$first eq {}} {set first $link}

	    # Extend toc in creation.
	    set map($node) [expr {1+[llength $toc]}]
	    set parent $map([$node parentNode])
	    lappend toc [list $parent $label $link]

	    # Add children to visit next.
	    foreach c [struct::list reverse [$node childNodes]] {lappend pending $c}
	}

	# Now put the root node in at the front (as we now know where
	# its link is going).
	set toc [linsert $toc 0 \
		     [list -1 "${tn}-${tv}" $first]]

	$doc delete
	return $toc
    }

    # Construct a Table Of Contents from a directory tree by looking
    # for specially named files to determine which sub directories
    # should correspond to TOC nodes.

    typemethod toc.physical {dir} {
	set t [fileutil::traverse %AUTO% $dir -filter [myproc _isdir]]

	# FUTURE: Look for toc.xml files too, and use them intregate
	# logical tocs in lower levels into the physical tree.

	$t foreach d {
	    if {![_hasindex $d index]} continue;
	    set title [_get_title [fileutil::cat $d/$index]]
	    set map($d) [list $index $title]
	}
	$t destroy

	set toc {}
	foreach f [lsort -dict [array names map]] {
	    foreach {i t} $map($f) break
	    set map($f) [llength $toc]

	    set pd [file dirname $f]
	    if {[info exists map($pd)]} {
		set parent $map($pd)
	    } else {
		set parent -1
	    }

	    lappend toc \
		[list $parent $t [fileutil::stripPath $dir $f/$i]]
	}
	return $toc
    }

    # Convert a linear TOC into the equivalent XML.

    typemethod xml.toc {toc} {
	# Ok, here the linear rep of the toc bites us, we do not know
	# immediately if a node has children, or not. Two runs, first
	# convert into an actual tree structure, then emit the tag by
	# recursing the tree.

	array set c {} ; Tree c $toc
	set   lines {} ; Emit c lines 0 "" 1

	return [join $lines \n]
    }

    typemethod plaintext.toc {toc} {
	# Ok, here the linear rep of the toc bites us, we do not know
	# immediately if a node has children, or not. Two runs, first
	# convert into an actual tree structure, then emit the tag by
	# recursing the tree.

	array set c {} ; Tree c $toc
	set   lines {} ; EmitPlain c lines 0 "" 1 

	return [join $lines \n]
    }

    typemethod tree {cv toc} {
	upvar 1 $cv c
	Tree c $toc
	return
    }

    proc Tree {cv toc} {
	upvar 1 $cv c

	set n 0
	foreach e $toc {
	    foreach {p label link} $e break
	    set c($n,i) $e
	    set c($n,c) {}
	    lappend c($p,c) $n
	    incr n
	}
	return
    }

    proc Emit {cv tv id prefix {root 0}} {
	upvar 1 $cv c $tv toclines

	foreach {p label link} $c($id,i) break
	set children $c($id,c)

	if {$root} {
	    set tag toc
	    foreach {n v} [split $label -] break
	    if {![llength $children]} {
		lappend toclines $prefix[Tag/ $tag name $n version $v]
	    } else {
		lappend toclines $prefix[Tag+ $tag name $n version $v]
	    }
	} else {
	    set tag node
	    if {![llength $children]} {
		if {$link eq ""} {
		    lappend toclines $prefix[Tag/ $tag name $label]
		} else {
		    lappend toclines $prefix[Tag/ $tag name $label link $link]
		}
	    } else {
		if {$link eq ""} {
		    lappend toclines $prefix[Tag+ $tag name $label]
		} else {
		    lappend toclines $prefix[Tag+ $tag name $label link $link]
		}
	    }
	}

	foreach id $children {
	    Emit c toclines $id "$prefix    "
	}

	if {[llength $children]} {
	    lappend toclines $prefix[Tag- $tag]
	}
	return
    }

    proc EmitPlain {cv tv id prefix {root 0}} {
	upvar 1 $cv c $tv toclines

	foreach {p label link} $c($id,i) break
	set children $c($id,c)

	if {$root} {
	    lappend toclines $prefix<[split $label -]>
	} else {
	    lappend toclines $prefix$label\t$link
	}

	foreach id $children {
	    EmitPlain c toclines $id "$prefix    "
	}
	return
    }

    proc Tag+ {tag args} {
	set s "<$tag"
	foreach {k v} $args {
	    append s " ${k}=\"$v\""
	}
	append s ">"
	return $s
    }

    proc Tag/ {tag args} {
	set s "<$tag"
	foreach {k v} $args {
	    append s " ${k}=\"$v\""
	}
	append s " />"
	return $s
    }

    proc Tag- {tag} {
	return "</$tag>"
    }

    # ### ### ### ######### ######### #########
    ## Public API
    ## Create /destroy an acessor object for a help file

    option -location {}

    constructor {args} {
	$self configurelist $args

	if {$options(-location) eq ""} {
	    return -code error "No help file specified"
	}
	if {![$type valid $options(-location) ro msg]} {
	    return -code error "Not a help file: $msg"
	}

	set db ${selfns}::DB
	sqlite3 $db [file nativename $options(-location)]
	$db enable_load_extension 1
	return
    }

    destructor {
	catch {$db close}
	return
    }

    # ### ### ### ######### ######### #########
    ## Public API.
    ## Querying the help

    # Find the pages matching a query. The query is in sqlite3::fts2
    # syntax. The result is a dictionary, keys are pages identified by
    # their physical path, values are the page titles. The latter are
    # part of the result for human readable identification of pages.

    method find {query} {
	# result = dict (path -> title)
	$db transaction {
	    set res [$db eval {
		SELECT path, title
		FROM   page
		JOIN   contents
		ON     page.rowid = contents.rowid
		WHERE  data MATCH $query
	    }]
	}
	return $res
    }

    # Read the contents of the page identified by its physical path.

    method read {path} {
	# result = string
	$db transaction {
	    set res [$db eval {
		SELECT data
		FROM   page
		JOIN   contents
		ON     page.rowid = contents.rowid
		WHERE  path = $path
	    }]
	}
	set contents [lindex $res 0]
	#puts \t[md5::md5 -hex $contents]
	return $contents
    }

    # Determine the paths of all stored files.

    method files {} {
	$db transaction {
	    set res [$db eval {
		SELECT path
		FROM   page
	    }]
	}
	return $res
    }

    # Read the table of contents. Tree in linear form (depth-first
    # pre-order) with each entry refering to its parent per index in
    # the list, and root entries using -1 to indicate that they have
    # no parent. The other information per entry is the human readable
    # label, and the associated page.

    method toc {} {
	# result = list (list (parent, label, link))

	# FUTURE: Cache the result.

	set res {}
	array set map {}

	foreach {id parent label link} [$db eval {
	    SELECT id, parent, label, link
	    FROM toc
	    ORDER BY id ASC
	}] {
	    set map($id) [llength $res]
	    if {$parent >= 0} {set parent $map($parent)}
	    lappend res [list $parent $label $link]
	}

	return $res
    }

    # ### ### ### ######### ######### #########
    ## Public API
    ## Filling the help

    # Add a bunch of files as pages to the help file. The paths have
    # to be relative, which also implies that the current working
    # directory has to be set such that we can read the file. The
    # optional anchor allows us to move the whole tree into a specific
    # location in the help file.

    method addpages {files {anchor /}} {
	# For the time of inserting documents into the fts index we
	# run on the more dangerous side, shaving of about 10% of the
	# time under sync=full.

	set old [$db eval {PRAGMA synchronous}]
	$db eval {PRAGMA synchronous = off}

	while {[llength $files]} {
	    # We also fts insertions in sets of fifty as part of the
	    # effort to speed things up.
	    set chunk [lrange   $files end-50 end]
	    set files [lreplace $files end-50 end]

	    $db transaction {
		# Enter files and contents ...
		foreach f $chunk {
		    #puts [set mt [fileutil::magic::mimetype $f]]\t$f

		    set fx       [file join $anchor $f]
		    set contents [fileutil::cat -translation binary $f]
		    set title    [_get_title $contents]

		    #puts \t[md5::md5 -hex $contents]

		    $db eval {
			insert into page     ( title,  path )
			values               ( $title, $fx  );
			insert into contents ( rowid,               data      )
			values               ( last_insert_rowid(), $contents );
		    }
		}
	    }
	}
	# Restore old mode. The pragma command doesn't take a variable/string
	switch -exact -- $old {
	    0 {$db eval {PRAGMA synchronous = off}}
	    1 {$db eval {PRAGMA synchronous = normal}}
	    2 {$db eval {PRAGMA synchronous = full}}
	}
	return
    }

    # Set the table of contents. Input is the toc in linear form, see
    # 'toc()' for the full description of the format. The anchor
    # shifts the physical paths given in the toc around to the actual
    # location.

    method setToc {toc {anchor /}} {

	# First validate the toc against the set of known pages

	array set ff {}
	foreach f [$db eval {
	    SELECT path
	    FROM page
	}] {
	    set ff($f) .
	}

	foreach tocitem $toc {
	    foreach {parent label link} $tocitem break
	    # Ignore empty links, they node without a page behind them.
	    if {$link eq ""} continue
	    # Strip a fragment, if present
	    regsub {\#.*$} $link {} link
	    # Shift to actual location
	    set link [file join $anchor $link]
	    if {![info exists ff($link)]} {
		return -code error "toc references missing page $link"
	    }
	}

	# Then actually enter the toc entries

	set id 0
	set np {}

	$db transaction {
	    foreach tocitem $toc {
		lappend np $id
		foreach {parent label link} $tocitem break
		if {$parent >= 0} {set parent [lindex $np $parent]}
		if {$link ne ""} {
		    # Anchor only actual links.
		    set link [file join $anchor $link]
		}
		$db eval {
		    insert into toc ( id,  parent,  label,  link  )
		    values          ( $id, $parent, $label, $link );
		}

		incr id
	    }
	}
	return
    }

    # ### ### ### ######### ######### #########
    ## State 
    ## - Database handle / object
    ## - Cached table of contents.

    variable db  {}
    #variable toc {}

    # ### ### ### ######### ######### #########
    ## Internal commands - Database access layer

    proc _isdir {f} {
	file isdirectory $f
    }

    proc _hasindex {base iv} {
	upvar 1 $iv index
	foreach c {
	    toc.html
	    index.html
	    welcome.html
	    contents.html
	    tcl-man.html
	} {
	    set cx [file join $base $c]
	    if {![fileutil::test $cx efr]} continue
	    set index $c
	    return 1
	}
	return 0
    }

    proc _get_title {html} {
	::variable untitled
	set low [string tolower $html]

	set start [string first <title> $low]
	if {$start < 0} {return $untitled}
	incr start 7
	set end   [string first </title> $low]
	if {$end < 0} {return $untitled}
	incr end -1
	set title [string trim [string range $html $start $end]]

	# Postprocess title -> Single line, reduce whitespace, fix
	# HTML standard entities.

	regsub -all -- {[\n\t]} $title { } title
	regsub -all -- {[ ]+} $title { } title

	return [htmlparse::mapEscapes $title]
    }

    # Check that the given database has all the necessary tables of a
    # help file. FUTURE: Additional check that the tables have the
    # proper columns and column types.

    proc _hasTables {db mv} {
	upvar 1 $mv message
	::variable revisioninfo

	# Check existence of all tables by name, and contents of the
	# version table.

	foreach {table label} {
	    _help_   {Revision information}
	    toc      {Table Of Contents}
	    page     {Page Index}
	    contents {Page Contents}
	} {
	    if {![llength [$db onecolumn {
		SELECT name
		FROM  sqlite_master 
		WHERE type = 'table'
		AND   name = $table
	    }]]} {
		set message "$label (Table [string toupper $table]) missing"
		return 0
	    }
	}
	if {[set got [lindex [$db onecolumn {
	    SELECT version
	    FROM  _help_
	    WHERE name = $revisioninfo(name)
	}] 0]] ne $revisioninfo(version)} {
	    set message "Expected revision \"$revisioninfo(version)\", got \"$got\""
	    return 0
	}
	return 1
    }

    # Add the tables of a help file to the given database, plus
    # supporting indices, etc.

    proc _setupTables {db} {
	::variable revisioninfo
	set rname    $revisioninfo(name)
	set rversion $revisioninfo(version)
	set rrcsid   $revisioninfo(rcsid)

	$db enable_load_extension 1
	$db transaction {
	    $db eval {
		-- Revision information and magic
		CREATE TABLE _help_
		(  name      TEXT NOT NULL,
		   version   TEXT NOT NULL,
		   rcsid     TEXT NOT NULL
		   )
		;
		INSERT INTO _help_ (name,   version,   rcsid)
		VALUES             ($rname, $rversion, $rrcsid)
		;
		-- Table Of Contents. Logical hierachical structure of pages
		CREATE TABLE toc
		(  id       INTEGER NOT NULL,	-- node id, ascending in depth-first pre-order
		   parent   INTEGER NOT NULL,	-- id of parent node.
		   label    TEXT NOT NULL,	-- human readable label of the node
		   link     TEXT NOT NULL,	-- reference to --> page to display
		   PRIMARY KEY (id)
		   )
		;
		-- Pages. The paths define a physical hierarchical structure of pages
		CREATE TABLE page
		(  path	 TEXT NOT NULL,	-- path of page
		   title TEXT NOT NULL,	-- page title
		   PRIMARY KEY (path)	-- page contents in separate table, linked by rowid
		   )
		;
		-- Page Contents. Linked to page via rowid
		CREATE VIRTUAL TABLE contents
		USING fts3 ( data )
		--CREATE TABLE contents (
		--       data TEXT NOT NULL
		--)
		;
		CREATE INDEX page_title
		ON           page (title)
		;
	    }
	}
	return
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide ashelp 0.1
