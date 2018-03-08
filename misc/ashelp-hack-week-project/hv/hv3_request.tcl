# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_request.tcl,v 1.6 2006/12/23 09:01:52 danielk1977 Exp $)} 1 }

#--------------------------------------------------------------------------
# This file contains the implementation of two types used by hv3:
#
#     ::hv3::download
#     ::hv3::uri
#


#--------------------------------------------------------------------------
# Class ::hv3::request
#
#     Instances of this class are used to interface between the protocol
#     implementation and the hv3 widget.
#
# METHODS:
#
#     Methods are used only by the protocol implementation.
#
#         append DATA
#         finish
#         fail
#         authority         (return the authority part of the -uri option)
#
#     destroy_hook SCRIPT
#         Configure the object with a script to be invoked just before
#         the object is about to be destroyed. If more than one of
#         these is configured, then the scripts are called in the
#         same order as they are configured in (i.e. most recently
#         configured is invoked last).
#
snit::type ::hv3::download {

  # The requestor (i.e. the creator of the ::hv3::download object) sets the
  # following configuration options. The protocol implementation may set the
  # -mimetype option before returning.
  #
  # The -cachecontrol option may be set to the following values:
  #
  #     * normal             (try to be clever about caching)
  #     * no-cache           (never return cached resources)
  #     * relax-transparency (return cached resources even if stale)
  #
  option -cachecontrol -default normal
  option -uri          -default ""
  option -postdata     -default ""
  option -mimetype     -default ""
  option -enctype      -default ""

  # The protocol implementation sets this option to contain the 
  # HTTP header (or it's equivalent). The format is a serialised array.
  # Example:
  # 
  #     {Set-Cookie safe-search=on Location http://www.google.com}
  #
  # The following http-header types are handled locally by the ConfigureHeader
  # method, as soon as the -header option is set:
  #
  #     Set-Cookie         (Call ::hv3::the_cookie_manager method)
  #     Content-Type       (Set the -mimetype option)
  #     Content-Length     (Set the -expectedsize option)
  #
  option -header -default "" -configuremethod ConfigureHeader

  option -requestheader -default ""

  # Expected size of the resource being requested. This is used
  # for displaying a progress bar when saving remote resources
  # to the local filesystem (aka downloadin').
  #
  option -expectedsize -default ""

  # Callbacks configured by the requestor.
  #
  option -incrscript   -default ""
  option -finscript    -default ""


  # END OF OPTIONS
  #----------------------------

  variable myData ""
  variable myChunksize 2048

  # Destroy-hook scripts configured using the [destroy_hook] method.
  variable myDestroyHookList [list]

  # Constructor and destructor
  constructor {args} {
    $self configurelist $args
  }

  destructor  {
    foreach hook $myDestroyHookList {
      eval $hook
    }
  }

  # Add a script to be called just before the object is destroyed. See
  # description above.
  #
  method destroy_hook {script} {
    lappend myDestroyHookList $script
  }

  # This method is called each time the -header option is set. This
  # is where the locally handled HTTP headers (see comments above the
  # -header option) are handled.
  #
  method ConfigureHeader {name option_value} {
    set options($name) $option_value
    foreach {name value} $option_value {
      switch -- $name {
        Set-Cookie {
          ::hv3::the_cookie_manager SetCookie $options(-uri) $value
        }
        Content-Type {
          if {[set idx [string first ";" $value]] >= 0} {
            set options(-mimetype) [string range $value 0 [expr $idx-1]]
          }
        }
        Content-Length {
          set options(-expectedsize) $value
        }
      }
    }
  }

  # Return the "authority" part of the URI configured as the -uri option.
  #
  method authority {} {
    set obj [::hv3::uri %AUTO% $options(-uri)]
    set authority [$obj cget -authority]
    $obj destroy
    return $authority
  }

  # Interface for returning data.
  method append {data} {
    ::append myData $data
    set nData [string length $myData]
    if {$options(-incrscript) != "" && $nData >= $myChunksize} {
      eval [linsert $options(-incrscript) end $myData]
      set myData {}
      if {$myChunksize < 30000} {
        set myChunksize [expr $myChunksize * 2]
      }
    }
  }

  # Called after all data has been passed to [append].
  method finish {} {
    eval [linsert $options(-finscript) end $myData] 
  }

  method fail {} {puts FAIL}
}

#--------------------------------------------------------------------------
# Class ::hv3::uri:
#
#     A very simple class for handling URI references. A partial 
#     implementation of the syntax specification found at: 
#
#         http://www.gbiv.com/protocols/uri/rfc/rfc3986.html
# 
# Usage:
#
#     set uri_obj [::hv3::uri %AUTO% $URI]
#
#     $uri_obj load $URI
#     $uri_obj get
#     $uri_obj cget ?option?
#
#     $uri_obj destroy
#
snit::type ::hv3::uri {

  # Public get/set variables for URI components
  option -scheme    file
  option -authority ""
  option -path      "/"
  option -query     ""
  option -fragment  ""

  # Constructor and destructor
  constructor {{url {}}} {$self load $url}
  destructor  {}

  # Remove any dot segments "." or ".." from the argument path and 
  # return the result.
  proc remove_dot_segments {path} {
    set output [list]
    foreach component [split $path /] {
      switch -- $component {
        .       { #Do nothing }
        ..      { set output [lreplace $output end end] }
        default { 
          if {[string match ?: $component]} {
            set component [string range $component 0 0]
          }
          if {$output ne "" || $component ne ""} {
            lappend output $component 
          }
        }
      }
    }
    return "/[join $output /]"
  }

  proc Merge {path1 path2} {
    return [regsub {[^/]*$} $path1 $path2]
  }

  # Set the contents of the object to the specified URI.
  method load {uri} {

    # First, parse the argument URI into it's 5 main components. All five
    # components are optional, as shown in the following syntax (each bracketed
    # section is optional).
    #
    #     (SCHEME ":") ("//" AUTHORITY) (PATH) ("?" QUERY) ("#" FRAGMENT)
    #
    # Save each of the components, if they exist, in the variables 
    # $Scheme, $Authority, $Path, $Query and $Fragment.
    set str $uri
    foreach {re var} [list \
        {^([A-Za-z][A-Za-z0-9+-\.]+):(.*)} Scheme            \
        {^//([^/#?]*)(.*)}                 Authority         \
        {^([^#?]*)(.*)}                    Path              \
        {^\?([^#]*)(.*)}                   Query             \
        {^#(.*)(.*)}                       Fragment          \
    ] {
      if {[regexp $re $str dummy A B]} {
        set $var $A
        set str $B
      }
    }
    if {$str ne ""} {
      error "Bad URL: $url"
    }

    # Using the current contents of the option variables as a base URI,
    # transform the relative argument URI to an absolute URI. The algorithm
    # used is defined in section 5.2.2 of RFC 3986.
    #
    set hasScheme 1
    set hasAuthority 1
    set hasQuery 1
    if {![info exists Path]}      {set Path ""}
    if {![info exists Fragment]}  {set Fragment ""}
    if {![info exists Scheme]}    {set Scheme ""    ; set hasScheme 0}
    if {![info exists Authority]} {set Authority "" ; set hasAuthority 0}
    if {![info exists Query]}     {set Query ""     ; set hasQuery 0}

    if {$hasScheme} {
      set options(-scheme)    $Scheme
      set options(-authority) $Authority
      set options(-path)      [remove_dot_segments $Path]
      set options(-query)     $Query
    } else {
      if {$hasAuthority} {
        set options(-authority) $Authority
        set options(-path)      [remove_dot_segments $Path]
        set options(-query)     $Query
      } else {
        if {$Path eq ""} {
          if {$hasQuery} {
            set options(-query) $Query
          }
        } else {
          if {[string match {/*} $Path]} {
            set options(-path) [remove_dot_segments $Path]
          } else {
            set merged_path [Merge $options(-path) $Path]
            set options(-path) [remove_dot_segments $merged_path]
          }
          set options(-query) $Query
        }
      }
    }
    set options(-fragment) $Fragment
    $self Escape
  }

  method Escape {} {
    if {[string match -nocase http* $options(-scheme)]} {
      set options(-path) [::tkhtml::escape_uri $options(-path)]
      set options(-query) [::tkhtml::escape_uri -query $options(-query)]
    }
  }

  # Return the contents of the object formatted as a URI.
  method get {{nofragment ""}} {
    set result "$options(-scheme)://$options(-authority)"
    ::append result "$options(-path)"
    if {$options(-query) ne ""}    {
      ::append result "?$options(-query)"
    }
    if {$nofragment eq "" && $options(-fragment) ne ""} {
      ::append result "#$options(-fragment)"
    }
    return $result
  }
}

# End of class ::hv3::uri
#--------------------------------------------------------------------------

#--------------------------------------------------------------------------
# Automated tests for ::hv3::uri:
#
#     The following block runs some quick regression tests on the ::hv3::uri 
#     implementation. These take next to no time to run, so there's little
#     harm in leaving them in.
#
if 1 {
  set test_data [list                                                 \
    {http://tkhtml.tcl.tk/index.html}                                 \
        -scheme http       -authority tkhtml.tcl.tk                   \
        -path /index.html  -query "" -fragment ""                     \
    {http:///index.html}                                              \
        -scheme http       -authority ""                              \
        -path /index.html  -query "" -fragment ""                     \
    {http://tkhtml.tcl.tk}                                            \
        -scheme http       -authority tkhtml.tcl.tk                   \
        -path "/"          -query "" -fragment ""                     \
    {/index.html}                                                     \
        -scheme http       -authority tkhtml.tcl.tk                   \
        -path /index.html  -query "" -fragment ""                     \
    {other.html}                                                      \
        -scheme http       -authority tkhtml.tcl.tk                   \
        -path /other.html  -query "" -fragment ""                     \
    {http://tkhtml.tcl.tk:80/a/b/c/index.html}                        \
        -scheme http       -authority tkhtml.tcl.tk:80                \
        -path "/a/b/c/index.html" -query "" -fragment ""              \
    {http://wiki.tcl.tk/}                                             \
        -scheme http       -authority wiki.tcl.tk                     \
        -path "/"          -query "" -fragment ""                     \
    {file:///home/dan/fbi.html}                                       \
        -scheme file       -authority ""                              \
        -path "/home/dan/fbi.html"  -query "" -fragment ""            \
    {http://www.tclscripting.com}                                     \
        -scheme http       -authority "www.tclscripting.com"          \
        -path "/"  -query "" -fragment ""                             \
    {file:///c:/dir1/dir2/file.html}                                  \
        -scheme file       -authority ""                              \
        -path "/c/dir1/dir2/file.html"  -query "" -fragment ""       \
    {relative.html}                                                   \
        -scheme file       -authority ""                              \
        -path "/c/dir1/dir2/relative.html"  -query "" -fragment ""   \
    ]

  set obj [::hv3::uri %AUTO%]
  for {set ii 0} {$ii < [llength $test_data]} {incr ii} {
    set uri [lindex $test_data $ii]
    $obj load $uri 
    while {[string match -* [lindex $test_data [expr $ii+1]]]} {
      set switch [lindex $test_data [expr $ii+1]]
      set value [lindex $test_data [expr $ii+2]]
      if {[$obj cget $switch] ne $value} {
        puts "URI: $uri"
        puts "SWITCH: $switch"
        puts "EXPECTED: $value"
        puts "GOT: [$obj cget $switch]"
        puts ""
      }
      incr ii 2
    }
  }
  $obj destroy
}
# End of tests for ::hv3::uri.
#--------------------------------------------------------------------------

