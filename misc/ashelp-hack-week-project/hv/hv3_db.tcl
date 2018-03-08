# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_db.tcl,v 1.9 2007/07/16 07:39:09 danielk1977 Exp $)} 1 }

# Class ::hv3::visiteddb
#
# There is a single instance of the following type used by all browser
# frames created in the lifetime of the application. It's job is to
# store a list of URI's that are considered "visited". Links to these
# URI's should be styled using the ":visited" pseudo-class, not ":link".
#
# Object sub-commands:
#
#     init HV3-WIDGET
#
#         Configure the specified hv3 mega-widget to use the object
#         as a database of visited URIs (i.e. set the value of
#         the -isvisitedcmd option).
#
snit::type ::hv3::visiteddb {

  # Constant: Maximum size of database.
  variable MAX_ENTRIES 200

  constructor {} {
    if {![::hv3::have_sqlite3]} return

    # Make sure the database table has been created.
    catch {::hv3::sqlitedb eval "
      CREATE TABLE visiteddb(
          uri TEXT PRIMARY KEY, 
          lastvisited TIMESTAMP
      );
    "}
  }

  # This method is called whenever the application constructs a new 
  # ::hv3::hv3 mega-widget. Argument $hv3 is the new mega-widget.
  #
  method init {hv3} {
    if {![::hv3::have_sqlite3]} return

    bind $hv3 <<Location>> +[mymethod LocationHandler %W]
    $hv3 configure -isvisitedcmd [mymethod LocationQuery $hv3]
  }

  method LocationHandler {hv3} {
    set location [$hv3 location]
    $self addkey $location
  }

  method LocationQuery {hv3 reluri} {

    # Resolve the "href" attribute of the node against the current
    # location of the specified hv3 widget.
    #
    set obj [::hv3::uri %AUTO% [$hv3 location]]
    $obj load $reluri
    set full [$obj get]
    $obj destroy

    # Query the database to see if this URI has been visited before.
    # If so 1 is returned, otherwise 0.
    set sql {SELECT count(*) FROM visiteddb WHERE uri = $full}
    return [::hv3::sqlitedb eval $sql]
  }

  # Return a list of all visited URIs that match the pattern $pattern.
  # $pattern is interpreted by the SQLite GLOB operator.
  #
  method keys {pattern} {
    if {![::hv3::have_sqlite3]} return
    set sql { 
      SELECT uri FROM visiteddb 
      WHERE uri GLOB $pattern 
      ORDER BY lastvisited DESC
    }
    return [::hv3::sqlitedb eval $sql]
  }

  method addkey {uri} {

    # First statement inserts the new URI into the table, or updates the
    # timestamp if the URI is already in the table.
    #
    # Second statement deletes all but the most recent $MAX_ENTRIES URIs.
    # This is to stop the db growing indefinitely. Todo: This operation might
    # not be all that efficient...
    #
    set sql1 {REPLACE INTO visiteddb VALUES($uri, $timestamp)}
    set sql2 {
      DELETE FROM visiteddb WHERE oid IN (
        SELECT oid FROM visiteddb ORDER BY lastvisited DESC
        LIMIT -1 OFFSET $MAX_ENTRIES
      )
    }

    set timestamp [clock seconds]
    ::hv3::sqlitedb transaction {
      ::hv3::sqlitedb eval $sql1
      ::hv3::sqlitedb eval $sql2
    }
  }
}

#--------------------------------------------------------------------------
# ::hv3::cookiemanager
#
#     A cookie manager is a database of http cookies. It supports the 
#     following operations:
#    
#         * Add cookie to database,
#         * Retrieve applicable cookies for an http request, and
#         * Delete the contents of the cookie database.
#    
#     Also, a GUI to inspect and manipulate the database in a new top-level 
#     window is provided.
#    
#     Interface:
#    
#         $pathName SetCookie URI DATA
#         $pathName Cookie URI
#         $pathName debug
#
#     Reference:
#
#         http://wp.netscape.com/newsref/std/cookie_spec.html
#
snit::type ::hv3::cookiemanager {

  # Constants used to schedule background activity.
  variable GUI_UPDATE_DELAY 3000
  variable EXPIRE_COOKIES_DELAY 10000

  constructor {} {
    if {![::hv3::have_sqlite3]} return

    # Make sure the database table has been created.
    catch {::hv3::sqlitedb eval {
      CREATE TABLE cookiesdb(
        domain TEXT,
        flag BOOLEAN,
        path TEXT,
        secure BOOLEAN,
        expires TIMESTAMP,
        name TEXT,
        value TEXT,
        lastused TIMESTAMP,
        PRIMARY KEY(domain, path, name)
      );
    }}
    after $EXPIRE_COOKIES_DELAY [mymethod ExpireCookies]
  }

  destructor {
    after cancel [mymethod ExpireCookies]
  }


  #--------------------------------------------------------------------
  # Cookie expiration policy. All text taken from the reference above.
  #
  # * The "expires" attribute specifies a date string that defines the 
  #   valid life time of that cookie. Once the expiration date has 
  #   been reached, the cookie will no longer be stored or given out.
  #
  # * "expires" is an optional attribute. If not specified, the cookie 
  #   will expire when the user's session ends.
  #
  # * This is a specification of the minimum number of cookies that a client
  #   should be prepared to receive and store:
  #      * 300 total cookies
  #      * 20 cookies per server or domain
  #
  # * When the 300 cookie limit or the 20 cookie per server limit is exceeded,
  #   clients should delete the least recently used cookie.
  #--------------------------------------------------------------------

  # This method is called whenever a new cookie is added to the database.
  # It should discard cookies from the database as required to satisfy
  # the 300 cookie or 20 cookie per server limit.
  #
  # TODO: The 20 cookie per server limit. Right now, only the 300 cookie limit
  # is considered.
  #
  method ExpireCookies {} {
    set MAX_TOTAL 300
    set MAX_PERHOST 20

    # SQL to delete all expired cookies
    set rightnow [clock seconds]
    set sql0 {DELETE FROM cookiesdb WHERE expires != 0 AND expires < $rightnow}

    # SQL to get a list of any hosts that have more than $MAX_PERHOST cookies.
    set sql1 {
        SELECT domain FROM cookiesdb GROUP BY domain 
        HAVING count(*) > $MAX_PERHOST
    }

    # SQL to delete all but the most recent $MAX_PERHOST cookies for host
    # $domain. This will be executed once for each domain returned by
    # query $sql1.
    set sql2 {
        DELETE FROM cookiesdb 
        WHERE oid IN (
            SELECT oid FROM cookiesdb WHERE domain = $domain 
            ORDER BY lastused ASC 
            LIMIT -1 OFFSET $MAX_PERHOST
        )
    }

    # Delete all but the most recent $MAX_TOTAL cookies.
    set sql3 {
        DELETE FROM cookiesdb 
        WHERE oid IN (
            SELECT oid FROM cookiesdb
            ORDER BY lastused ASC 
            LIMIT -1 OFFSET $MAX_TOTAL
        )
    }

    ::hv3::sqlitedb transaction {
      ::hv3::sqlitedb eval $sql0
      foreach domain [::hv3::sqlitedb eval $sql1] {
        ::hv3::sqlitedb eval $sql2
      }
      ::hv3::sqlitedb eval $sql3
    }
    after $EXPIRE_COOKIES_DELAY [mymethod ExpireCookies]
  }

  #------------------------------------------------------------------------
  # SetCookie
  #
  # Add a cookie to the cookies database.
  #
  method SetCookie {uri data} {
    if {![::hv3::have_sqlite3]} return

    # Default values for "domain" and "path"
    set obj [::hv3::uri %AUTO% $uri]
    regexp {[^:]*} [$obj cget -authority] v(domain)
    regexp {^.*/} [$obj cget -path] v(path)
    $obj destroy

    set  v(flag) TRUE
    
    set d [string trim $data]
    while {$d ne ""} {
      regexp {^([^;]*)(.*)} $d dummy pair d
      set d [string range $d 1 end]

      set idx [string first = $pair]
      set K [string trim [string range $pair 0 [expr $idx-1]]]
      set V [string trim [string range $pair [expr $idx+1] end]]

      if {![info exists name]} {
        set name $K
        set value $V
      } else {
        set v([string tolower $K]) $V
      }
    }

    if {[info exists v(secure)]} {
      set v(secure) TRUE
    } else {
      set v(secure) FALSE
    }

    # Try to convert the "expires" header to a time_t time. This
    # may fail, if the header specifies a date too far in the future 
    # or if it get's the format wrong. In any case it's not particularly
    # important, just set the cookie to never expire and move on.
    set rc [catch {
      set v(expires) [clock scan $v(expires)]
    }]
    if {$rc} {
      set v(expires) 0
    }

    if {[info exists name]} {
      set lastused [clock seconds]
      set sql {REPLACE INTO cookiesdb VALUES(
          $v(domain), $v(flat), $v(path), $v(secure), $v(expires), $name,
          $value, $lastused)
      }
      ::hv3::sqlitedb eval $sql
    } else {
      puts "::hv3::cookiemanager SetCookie - parse failed"
      # puts $uri 
      # puts $data
    }
  }

  # Retrieve the cookies that should be sent with the request to the specified
  # URI.  The cookies are returned as a string of the following form:
  #
  #     "NAME1=OPAQUE_STRING1; NAME2=OPAQUE_STRING2 ..."
  #
  method Cookie {uri} {
    if {![::hv3::have_sqlite3]} return

    set obj [::hv3::uri %AUTO% $uri]
    set uri_domain [$obj cget -authority]
    set uri_path [$obj cget -path]
    $obj destroy

    set ret ""

    set rightnow [clock seconds]
    set sql {
      SELECT oid AS id, name, value FROM cookiesdb WHERE
        $uri_domain GLOB ('*' || domain) AND
        $uri_path GLOB (path || '*') AND
        (expires == 0 OR expires > $rightnow)
    }

    set used [list]
    ::hv3::sqlitedb eval $sql {
      append ret [format "%s=%s; " $name $value]
      lappend used $id
    }

    if {[llength $used] > 0} {
      set oids [join $used ,]
      set sql "UPDATE cookiesdb SET lastused = $rightnow WHERE oid IN ($oids)"
      ::hv3::sqlitedb eval $sql
    }

    return $ret
  }

  method Report {} {
    if {![::hv3::have_sqlite3]} return

    set Template {
      <html><head>
        <style>$Style</style>
        <meta http-equiv="refresh" content="3 ; url=cookies:///">
      </head>
      <body>
        <h1>Hv3 Cookies</h1>
        <p>
	  <b>Note:</b> This window is automatically updated when Hv3's 
	  internal cookies database is modified in any way. There is no need to
          close and reopen the window to refresh it's contents.
        </p>
        <div id="clear"></div>
        <br clear=all>
        $Content
      </body>
      <html>
    }

    set Style {
      .authority { margin-top: 2em; font-weight: bold; }
      .name      { padding-right: 5ex; }
      #clear { 
        float: left; 
        margin: 1em; 
        margin-top: 0px; 
      }
    }

    set Content ""
    append Content "<table border=1 cellpadding=5>"

    # Append the table header row to $Content
    append Content "<tr>"
    foreach h {Domain Flag Path Secure Expires Name Value Lastused} {
      append Content "<th>$h"
    }
    append Content "</tr>"

    set sql {SELECT * FROM cookiesdb}
    ::hv3::sqlitedb eval $sql {
      append Content "<tr><td>$domain<td>$flag<td>$path<td>$secure<td>$expires"
      append Content "<td>$name<td>$value<td>$lastused"
    }
    append Content "</table>"

    return [subst $Template]
  } 

  method cookies_request {downloadHandle} {
    $downloadHandle append [$self Report]
    $downloadHandle finish
  }
}

proc ::hv3::have_sqlite3 {} {
  return [expr [catch {package present sqlite3}] ? 0 : 1]
}

proc ::hv3::cookies_scheme_init {protocol} {
  $protocol schemehandler cookies {::hv3::the_cookie_manager cookies_request}
}

proc ::hv3::dbinit {} {
  if {"" eq [info commands ::hv3::the_cookie_manager]} {
    if {[::hv3::have_sqlite3]} {
      sqlite3 ::hv3::sqlitedb $::hv3::statefile
      ::hv3::sqlitedb eval {PRAGMA synchronous = OFF}
      ::hv3::sqlitedb timeout 2000
    }

    ::hv3::bookmarkdb      ::hv3::the_bookmark_manager ::hv3::sqlitedb
    ::hv3::cookiemanager   ::hv3::the_cookie_manager
    ::hv3::visiteddb       ::hv3::the_visited_db
  }
}

