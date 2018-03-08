# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_home.tcl,v 1.23 2007/08/05 06:54:47 danielk1977 Exp $)} 1 }

# Register the home: scheme handler with ::hv3::protocol $protocol.
#
proc ::hv3::home_scheme_init {hv3 protocol} {
  set dir $::hv3::maindir
  $protocol schemehandler home [list ::hv3::home_request $protocol $hv3 $dir]
}

proc ::hv3::create_undo_trigger {db zTable} {
  set columns [list]
  $db eval "PRAGMA table_info($zTable)" {
    lappend columns quote(old.${name})
  }
  set trigger "CREATE TRIGGER ${zTable}_ud AFTER DELETE ON $zTable BEGIN "
  append trigger "INSERT INTO bm_undo1 VALUES("
  append trigger   "'sql', 'INSERT INTO $zTable VALUES(' || "
  append trigger   [join $columns "|| ', ' || "]
  append trigger   "|| ')'" 
  append trigger ");" 
  append trigger "END;"

  $db eval $trigger
}

::snit::type ::hv3::bookmarkdb {
  variable myDb ""

  typevariable Schema {

      /* Each bookmark is represented by a single entry in this
       * table. The "bookmark_id" is allocated when the record
       * is created and never modified.
       */
      CREATE TABLE bm_bookmarks1(
        bookmark_id     INTEGER PRIMARY KEY,

        bookmark_name   TEXT,          /* Link caption */
        bookmark_uri    TEXT,          /* Uri of bookmarked page */
        bookmark_tags   TEXT,          /* Arbitrary. Used for user queries */

        bookmark_folder     INTEGER,
        bookmark_folder_idx INTEGER
      );

      /* This table defines the display order for folders. Also, whether
       * or not the folder is in "hidden" state. 
       */
      CREATE TABLE bm_folders1(
        folder_id       INTEGER PRIMARY KEY,
        folder_name     TEXT,
        folder_hidden   BOOLEAN,
        folder_idx      INTEGER
      );

      CREATE TABLE bm_version1(
        version         INTEGER PRIMARY KEY
      );

      /* The "undo" log. Each entry is either a caption or an sql
       * statement. The type column is either 'caption' or 'sql'.
       */
      CREATE TABLE bm_undo1(
        type       TEXT,
        str        TEXT
      );

      INSERT INTO bm_version1 VALUES(1);
  }

  typevariable BookmarkTemplate [join {
      {<DIV 
         class="bookmark" 
         active="true"
         id="${bookmark_id}"
         onmousedown="return bookmark_mousedown(this, event)"
         bookmark_id="$bookmark_id"
         bookmark_name="$bookmark_name"
         bookmark_uri="$bookmark_uri"
         bookmark_tags="$bookmark_tags"
      >}
      {<SPAN class="edit" 
         onclick="return bookmark_edit(this.parentNode)">(edit)</SPAN>}
      {<A href="$bookmark_uri">$bookmark_name</A>}
      {<DIV></DIV>}
      {</DIV>}
  } ""]

  typevariable FolderTemplate [join {
    {<DIV
      class="folder"
      id="$folder_id"
      folder_id="$folder_id"
      folder_name="$folder_name"
      folder_hidden="$folder_hidden"
    >}
      {<H2 
         style="display:$folder_display"
         onmousedown="return folder_mousedown(this, event)"
         onclick="return folder_toggle(this.parentNode, event, 1)"
       >}
      {<SPAN class="edit" 
         onclick="return folder_edit(this.parentNode.parentNode)">(edit)</SPAN>}
      {<SPAN>- </SPAN>$folder_name}
      {<DIV></DIV>}
      {</H2><UL style="clear:both;width:100%">}
  } ""]

  constructor {db} {
    set myDb $db

    set rc [catch { $myDb eval $Schema } msg]

    # When this is loaded, each bookmarks record is transformed to
    # the following HTML:
    #
    if {$rc == 0} {
      set folderid 0

      $myDb transaction {
        set ii 0
        foreach B {

      { "Report Hv3 bugs here!" {http://tkhtml.tcl.tk/cvstrac/tktnew} }

      { "Tkhtml and Hv3 Related" }
      { "tkhtml.tcl.tk"             {http://tkhtml.tcl.tk} }
      { "Tkhtml3 Mailing List"      {http://groups.google.com/group/tkhtml3} }
      { "Hv3 site at freshmeat.net" {http://freshmeat.net/hv3} }

      { "Components Used By Hv3" }
      { "Sqlite" {http://www.sqlite.org} }
      { "Tk Combobox" {http://www.purl.org/net/oakley/tcl/combobox/index.html} }
      { "Polipo (web proxy)" {http://www.pps.jussieu.fr/~jch/software/polipo/} }
      { "SEE (javascript engine)" {http://www.adaptive-enterprises.com.au/~d/software/see/} }
      { "Icons used in Hv3" {http://e-lusion.com/design/greyscale} }

      { "Tcl Sites" }
      { "Tcl site"         {http://www.tcl.tk} }
      { "Tcl wiki"         {http://mini.net/tcl/} }
      { "ActiveState"      {http://www.activestate.com/} }
      { "Evolane (eTcl)"   {http://www.evolane.com/} }
      { "comp.lang.tcl"    {http://groups.google.com/group/comp.lang.tcl} }
      { "tclscripting.com" {http://www.tclscripting.com/} }

      { "WWW" }
      { "W3 Consortium"   {http://www.w3.org} }
      { "CSS 1.0"         {http://www.w3.org/TR/CSS1} }
      { "CSS 2.1"         {http://www.w3.org/TR/CSS21/} }
      { "HTML 4.01"       {http://www.w3.org/TR/html4/} }
      { "W3 DOM Pages"    {http://www.w3.org/DOM/} }
      { "Web Apps 1.0"    {http://www.whatwg.org/specs/web-apps/current-work/} }
      { "Acid 2 Test"     {http://www.webstandards.org/files/acid2/test.html} }

        } {
          if {[llength $B] == 1} {
            set f [lindex $B 0]
            $myDb eval { 
              INSERT INTO bm_folders1(folder_name, folder_hidden, folder_idx) 
              VALUES($f, 0, (
                  SELECT coalesce(max(folder_idx),0)+1 FROM bm_folders1
                )
              )
            }
            set folderid [$myDb last_insert_rowid]
          } else {
            foreach {name uri} $B {
              $myDb eval { 
                INSERT INTO bm_bookmarks1(
                  bookmark_name, bookmark_uri, bookmark_tags, 
                  bookmark_folder, bookmark_folder_idx) 
                  VALUES($name, $uri, '', $folderid, $ii)
              }
              incr ii
            }
          }
        }
      }

      ::hv3::create_undo_trigger $myDb bm_bookmarks1
      ::hv3::create_undo_trigger $myDb bm_folders1
    }
  }

  # This method is called to add a bookmark to the system.
  #
  method add {name uri {tags ""}} {
    $myDb transaction {
      $myDb eval {
        INSERT INTO bm_bookmarks1 (
          bookmark_name, bookmark_uri, bookmark_tags, 
          bookmark_folder, bookmark_folder_idx
        ) VALUES(
          $name, $uri, $tags, 0, (
            SELECT min(bookmark_folder_idx)-1 FROM bm_bookmarks1
          )
        )
      }
      $myDb eval {UPDATE bm_version1 SET version = version + 1}
    }

    $myDb last_insert_rowid
  }

  method GetFolderTemplate {} {return $FolderTemplate}
  method GetBookmarkTemplate {} {return $BookmarkTemplate}

  method db {} {return $myDb}
}

proc ::hv3::create_domref {} {

  append doctop {
    <H1 class=title>Hv3 DOM Object Reference</H1><DIV class="toc">
  }
  foreach c [lsort [::hv3::dom2::classlist]] {
    append docmain [::hv3::dom2::document $c]
    append doctop [subst {
      <DIV class="tocentry"><A href="#${c}">$c</A></DIV>
    }]
  }
  append doctop {
    </DIV>
    <STYLE>
      H1 {
        clear:both;
      }
      H2 {
        margin-left: 1cm;
      }
      TABLE {
        width: 90%;
        margin-left: 2cm;
      }
      TD {
        vertical-align: top;
        padding: 0 5px;
        width: 100%;
      }
      .mode {
        width: auto;
      }
      TH {
        vertical-align: top;
        text-align: left;
        padding: 0 5px;
        background-color: #d9d9d9;
        white-space: nowrap;
      }
      UL {
        list-style-type: none;
      }
      .tocentry {
        float: left;
        width: 32ex;
      }
      .toc {
        margin-left: 2cm;
        overflow: auto;
      }
      .title {
        text-align: center;
      }
      .uri {
        margin-left: 1cm;
      }
      .nodocs {
        color: silver;
      }
    </STYLE>

    <P>
      This document is a reference to Hv3's version of the Document Object
      Model (DOM). It is generated by the DOM implementation
      itself and augmented by comments in the DOM source code. It is always
      available from within Hv3 itself by selecting the 
      "Debug->DOM Reference..." menu option. The intended audience for
      this document already has a strong grasp of cross-browser DOM
      principles.
    </P>

    <P>
      Any hyperlinked documents (except for internal references to other
      parts of this document) are for informational purposes only. They
      are not part of Hv3 documentation.
    </P>
  }
  set ::hv3::dom::Documentation $doctop
  append ::hv3::dom::Documentation $docmain
}

# When a URI with the scheme "home:" is requested, this proc is invoked.
#
proc ::hv3::home_request {http hv3 dir downloadHandle} {

  set obj [::hv3::uri %AUTO [$downloadHandle cget -uri]]
  set path [$obj cget -path]
  set authority [$obj cget -authority]
  $obj destroy

  switch -exact -- $authority {

    blank { }

    about {
      set tkhtml_version [::tkhtml::version]
      set hv3_version ""
      foreach version [lsort [array names ::hv3::version]] {
        set t [string trim [string range $version 4 end-1]]
        append hv3_version "$t\n"
      }
    
      set html [subst {
        <html> <head> </head> <body>
        <h1>Tkhtml Source Code Versions</h1>
        <pre>$tkhtml_version</pre>
        <h1>Hv3 Source Code Versions</h1>
        <pre>$hv3_version</pre>
        </body> </html>
      }]
    
      $downloadHandle append $html
    }

    domref {
      $downloadHandle append $::hv3::dom::Documentation
    }

    default {
      set filename [file join $dir bookmarks.html]
      set fd [open $filename]
      $downloadHandle append [read $fd]
      close $fd
    }
  }

  $downloadHandle finish
}

proc ::hv3::compile_bookmarks_object {} {

# This is a custom object used by the javascript part of the bookmarks
# appliation to access the database. Interface:
#
#     remove(node)
#     bookmark_edit(node)
#     bookmark_move(node)
#     folder_edit(node)
#     folder_move(node)
#     folder_hidden(node)
#
#     bookmark_new()
#     folder_new()
#
#     get_html_content()
#     get_version()
#
::hv3::dom2::stateless Bookmarks {} {
  dom_parameter myManager

  dom_call remove {THIS node} {
    set db [$myManager db]
    bookmark_transaction $db {
      set N [GetNodeFromObj [lindex $node 1]]
      if {[$N attr class] eq "bookmark"} {
        set bookmark_id [$N attr bookmark_id]
        set n " \"[$N attr bookmark_name]\""
        $db eval { 
          DELETE FROM bm_undo1;
          INSERT INTO bm_undo1 VALUES('caption', 'Undelete Bookmark' || $n);
          DELETE FROM bm_bookmarks1 WHERE bookmark_id = $bookmark_id 
        }
      }
      if {[$N attr class] eq "folder"} {
        set folder_id [$N attr folder_id]
        set n " \"[$N attr folder_name]\""
        $db eval { 
          DELETE FROM bm_undo1;
          INSERT INTO bm_undo1 VALUES('caption', 'Undelete Folder ' || $n);
          DELETE FROM bm_bookmarks1 WHERE bookmark_folder = $folder_id;
          DELETE FROM bm_folders1 WHERE folder_id = $folder_id;
        }
      }
    }
  }

  dom_call undelete {THIS} {
    set db [$myManager db]
    bookmark_transaction $db {
      set oid [$db one {SELECT max(rowid) FROM bm_undo1 WHERE type = 'caption'}]
      if {$oid ne ""} {
        $db eval { 
          SELECT str FROM bm_undo1 WHERE rowid > $oid
        } {
          $db eval $str
        }
        $db eval { DELETE FROM bm_undo1 WHERE rowid >= $oid }
      }
    }
  }

  dom_call bookmark_edit {THIS node} {
    set db [$myManager db]
    bookmark_transaction $db {
      set N [GetNodeFromObj [lindex $node 1]]
      foreach v {bookmark_id bookmark_name bookmark_uri bookmark_tags} {
        set $v [$N attribute $v]
      }

      $db eval {
        UPDATE bm_bookmarks1 SET bookmark_name = $bookmark_name,
                              bookmark_uri = $bookmark_uri,
                              bookmark_tags = $bookmark_tags
        WHERE bookmark_id = $bookmark_id
      }
    }
  }

  dom_call bookmark_move {THIS node} {
    set db [$myManager db]
    bookmark_transaction $db {
      set N [GetNodeFromObj [lindex $node 1]]
      set P [$N parent]
      set F [[$N parent] parent]

      set bookmark_folder [$F attr folder_id]

      set iMax [$db onecolumn {
        SELECT max(bookmark_folder_idx) 
        FROM bm_bookmarks1 
        WHERE bookmark_folder = $bookmark_folder
      }]
      if {$iMax eq ""} {set iMax 1}
 
      foreach child [$P children] {
        set bookmark_id [$child attr bookmark_id]
        incr iMax
        $db eval {
          UPDATE bm_bookmarks1 
          SET bookmark_folder = $bookmark_folder, bookmark_folder_idx = $iMax
          WHERE bookmark_id = $bookmark_id
        }
      }
    }
  }

  dom_call folder_move {THIS node} {
    set db [$myManager db]
    bookmark_transaction $db {
      set N [GetNodeFromObj [lindex $node 1]]
      set P [$N parent]

      set iMax [$db onecolumn {
        SELECT max(folder_idx) FROM bm_folders1 
      }]
      if {$iMax eq ""} {set iMax 1}

      foreach child [$P children] {
        if {[catch {set folder_id [$child attr folder_id]}]} continue
        incr iMax
        $db eval {
          UPDATE bm_folders1 SET folder_idx = $iMax WHERE folder_id = $folder_id
        }
      }
    }
  }

  dom_call folder_edit {THIS node} {
    set db [$myManager db]
    bookmark_transaction $db {
      set N [GetNodeFromObj [lindex $node 1]]
      foreach v {folder_id folder_name} {
        set $v [$N attribute $v]
      }
      $db eval {
        UPDATE bm_folders1 SET folder_name = $folder_name
        WHERE folder_id = $folder_id;
      }
    }
  }

  dom_call folder_hidden {THIS node} {
    set db [$myManager db]
    bookmark_transaction $db {
      set N [GetNodeFromObj [lindex $node 1]]
      foreach v {folder_id folder_hidden} {
        set $v [$N attribute $v]
      }
      $db eval {
        UPDATE bm_folders1 SET folder_hidden = $folder_hidden
        WHERE folder_id = $folder_id
      }
      $db eval {UPDATE bm_version1 SET version = version + 1}
    }
  }

  dom_call -string bookmark_new {THIS tag} {
    set db [$myManager db]
    list string [$myManager add {New Bookmark} {} $tag]
  }

  dom_call folder_new {THIS} {
    set db [$myManager db]

    set rc 1
    set msg "column folder_name is not unique"

    $db transaction {
      set idx 1
      while {$rc && $msg eq "column folder_name is not unique"} {
        set rc [catch {
          $db eval {
            INSERT INTO bm_folders1 (
              folder_idx, folder_name, folder_hidden 
            ) VALUES (
              (SELECT min(folder_idx)-1 FROM bm_folders1), 'New Folder ' || $idx, 0
            );
          }
        } msg]
        incr idx
        $db eval {UPDATE bm_version1 SET version = version + 1}
      }
    }

    list string [$db last_insert_rowid]
  }

  dom_call -string get_undelete {THIS} {
    set db [$myManager db]
    set caption [$db one { 
      SELECT str FROM bm_undo1 WHERE type = 'caption' ORDER BY oid DESC LIMIT 1
    }]
    if {$caption ne ""} {
      list string [subst {
        <INPUT 
          onclick="bookmark_undelete()" 
          type=button value="[htmlize $caption]">
        </INPUT>
      }]
    } else {
      list string ""
    }
  }

  dom_call -string get_html_content {THIS zFilter} {
    set ret ""

    set BookmarkTemplate [$myManager GetBookmarkTemplate]
    set FolderTemplate [$myManager GetFolderTemplate]

    set where { 1 }
    if {$zFilter ne ""} {
      set where { 
          bookmark_name LIKE ('%' || $zFilter || '%') OR
          bookmark_uri  LIKE ('%' || $zFilter || '%') OR
          bookmark_tags LIKE ('%' || $zFilter || '%')
      }
    }

    set sql [subst { 
      SELECT 
      bookmark_id, bookmark_name, bookmark_uri, bookmark_tags, 
      '' AS folder_name, bookmark_folder_idx, 
      0 AS folder_id, 0 AS folder_hidden, null AS folder_idx
      FROM bm_bookmarks1 
      WHERE bookmark_folder = 0 AND ( $where )

      UNION ALL

      SELECT 
      bookmark_id, bookmark_name, bookmark_uri, bookmark_tags, 
      folder_name, bookmark_folder_idx, folder_id, 
      folder_hidden, folder_idx
      FROM bm_folders1 LEFT JOIN (SELECT * FROM bm_bookmarks1 WHERE $where) 
        ON (bookmark_folder=folder_id)
      ORDER BY folder_idx, bookmark_folder_idx
    }]

    set current_folder ""
    set folder_name ""
    set folder_id 0
    set folder_hidden 0
    set folder_display none
    set content_display block
    set folder_marker -
    append ret [subst -nocommands $FolderTemplate]
    
    [$myManager db] eval $sql {

      set folder_name [htmlize $folder_name]

      if {$folder_name ne $current_folder} {
        append ret "</UL></DIV>"
        set folder_display block
        set content_display block
        set folder_marker -
        if {$folder_hidden} {
          set content_display none
          set folder_marker +
        }

        append ret [subst -nocommands $FolderTemplate]
        set current_folder $folder_name
      }

      if {$bookmark_id ne ""} {
        set bookmark_name [htmlize $bookmark_name]
        set bookmark_uri  [htmlize $bookmark_uri]
        set bookmark_id   [htmlize $bookmark_id]
        set bookmark_tags [htmlize $bookmark_tags]
        append ret [subst -nocommands $BookmarkTemplate]
      }
    }

    list string $ret
  }

  dom_call get_version {THIS} {
    list string [[$myManager db] onecolumn {SELECT version FROM bm_version1}]
  }
}

eval [::hv3::dom2::compile Bookmarks]

}

namespace eval ::hv3::DOM {
  proc bookmark_transaction {db script} {
    set ret -1
    $db transaction {
      uplevel $script
      $db eval {UPDATE bm_version1 SET version = version + 1}
      set ret [$db one {SELECT version FROM bm_version1}]
    }
    list number $ret
  }
}

