# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
namespace eval hv3 { set {version($Id: hv3_http.tcl,v 1.46 2007/08/01 06:42:04 danielk1977 Exp $)} 1 }

#
# This file contains implementations of the -requestcmd script used with 
# the hv3 widget for the browser. Supported functions are:
#
#     * http:// (including cookies)
#     * file:// (code for this is now in hv3_file.tcl)
#     * data://
#     * blank://
#     * https:// (if the "tls" package is available)
#

package require snit
package require Tk
package require http
catch { package require tls }

#
# ::hv3::protocol
#
#     Connect hv3 to the outside world via download-handle objects.
#
# Synopsis:
#
#     set protocol [::hv3::protocol %AUTO%]
#
#     $protocol requestcmd DOWNLOAD-HANDLE
#
#     $protocol schemehandler scheme handler
#
#     $protocol destroy
#
snit::type ::hv3::protocol {

  # Lists of waiting and in-progress http URI download-handles.
  variable myWaitingHandles    [list]
  variable myInProgressHandles [list]

  variable myTokenMap -array [list]
 
  # If not set to an empty string, contains the name of a global
  # variable to set to a short string describing the state of
  # the object. The string is always of the form:
  #
  #     "X1 waiting, X2 in progress"
  #
  # where X1 and X2 are integers. An http request is said to be "waiting"
  # until the header identifying the mimetype is received, and "in progress"
  # from that point on until the resource has been completely retrieved.
  #
  option -statusvar -default "" -configuremethod ConfigureStatusvar
  option -relaxtransparency -default 0

  # Instance of ::hv3::cookiemanager. Right now this is a global object.
  # But this may change in the future. Hence this variable.
  #
  variable myCookieManager ""

  # Both built-in ("http" and "file") and any configured scheme handlers 
  # (i.e. "home:") are stored in this array.
  variable mySchemeHandlers -array [list]

  constructor {args} {
    $self configurelist $args

    # It used to be that each ::hv3::protocol object would create it's
    # own cookie-manager database. This has now changed so that the
    # whole application (all browser tabs) use a single cookies 
    # database. The net effect is that you can log in to a web site
    # in one tab and then continue in another.
    #
    # The global cookie-manager object is named "::hv3::the_cookie_manager".
    #
    set myCookieManager ::hv3::the_cookie_manager
    if {[info commands $myCookieManager] eq ""} {
      ::hv3::cookiemanager $myCookieManager
    }

    # Register the 4 basic types of URIs the ::hv3::protocol code knows about.

      package require hv3::ashelp
      $self schemehandler ashelp  ::hv3::ashelp_request

    $self schemehandler file  ::hv3::request_file
    $self schemehandler http  [mymethod request_http]
    $self schemehandler data  [mymethod request_data]
    $self schemehandler blank [mymethod request_blank]
    $self schemehandler about [mymethod request_blank]

    # If the tls package is loaded, we can also support https.
    if {[info commands ::tls::socket] ne ""} {
      $self schemehandler https [mymethod request_https]
      ::http::register https 443 [list ::hv3::protocol SSocket]
    }

    # Configure the Tcl http package to pretend to be Gecko.
    # ::http::config -useragent {Mozilla/5.0 Gecko/20050513}
    ::http::config -useragent {Mozilla/5.1 (X11; U; Linux i686; en-US; rv:1.8.0.3) Gecko/20060425 SUSE/1.5.0.3-7 Firefox/1.5.0.3}
    set ::http::defaultCharset utf-8
  }

  destructor { 
    # Nothing to do. We used to destroy the $myCookieManager object here,
    # but that object is now global and exists for the lifetime of the
    # application.
  }

  # Register a custom scheme handler command (like "home:").
  method schemehandler {scheme handler} {
    set mySchemeHandlers($scheme) $handler
  }

  # This method is invoked as the -requestcmd script of an hv3 widget
  method requestcmd {downloadHandle} {

    # Extract the URI scheme to figure out what kind of URI we are
    # dealing with. Currently supported are "file" and "http" (courtesy 
    # Tcl built-in http package).
    set uri_obj [::hv3::uri %AUTO% [$downloadHandle cget -uri]]
    set uri_scheme [$uri_obj cget -scheme]
    $uri_obj destroy

    # Fold the scheme to lower-case. Should ::hv3::uri have already done this?
    set uri_scheme [string tolower $uri_scheme]

    # Execute the scheme-handler, or raise an error if no scheme-handler
    # can be found.
    if {[info exists mySchemeHandlers($uri_scheme)]} {
      eval [concat $mySchemeHandlers($uri_scheme) $downloadHandle]
    } else {
      error "Unknown URI scheme: \"$uri_scheme\""
    }
  }

  # Handle an http:// URI.
  #
  method request_http {downloadHandle} {
    set uri       [$downloadHandle cget -uri]
    set postdata  [$downloadHandle cget -postdata]
    set enctype   [$downloadHandle cget -enctype]
    set authority [$downloadHandle authority]

    # Knock any #fragment off the end of the URI.
    set obj [::hv3::uri %AUTO% $uri]
    set uri [$obj get -nofragment]
    $obj destroy

    # Store the HTTP header containing the cookies in variable $headers
    set headers [$downloadHandle cget -requestheader]
    set cookies [$myCookieManager Cookie $uri]
    if {$cookies ne ""} {
      lappend headers Cookie $cookies
    }

    switch -- [$downloadHandle cget -cachecontrol] {
      relax-transparency {
        lappend headers Cache-Control relax-transparency=1
      }
      no-cache {
        lappend headers Cache-Control no-cache
      }
      default {
      }
    }
    if {$options(-relaxtransparency)} {
      lappend headers Cache-Control relax-transparency=1
    }

    # Fire off a request via the http package.
    set geturl [list ::http::geturl $uri                     \
      -command [mymethod _DownloadCallback $downloadHandle]  \
      -handler [mymethod _AppendCallback $downloadHandle]    \
      -headers $headers                                      \
    ]
    if {$postdata ne ""} {
      lappend geturl -query $postdata
      if {$enctype ne ""} {
        lappend geturl -type $enctype
      }
    }

    set mimetype [$downloadHandle cget -mimetype]
    if {$mimetype ne "" && ![string match text* $mimetype]} {
      lappend geturl -binary 1
    }

    
    set token [eval $geturl]
    $self AddToWaitingList $downloadHandle
    set myTokenMap($downloadHandle) $token
#puts "REQUEST $geturl -> $token"
  }

  method AddToWaitingList {downloadHandle} {
    if {[lsearch -exact $myWaitingHandles $downloadHandle] >= 0} return

    # Add this handle the the waiting-handles list. Also add a callback
    # to the -failscript and -finscript of the object so that it 
    # automatically removes itself from our lists (myWaitingHandles and
    # myInProgressHandles) after the retrieval is complete.
    #
    lappend myWaitingHandles $downloadHandle
    $downloadHandle destroy_hook [mymethod FinishRequest $downloadHandle]
    $self Updatestatusvar
  }

  # The following methods:
  #
  #     [request_https], 
  #     [SSocketReady], 
  #     [SSocketProxyReady], and
  #     [SSocket], 
  #
  # along with the type variable $theWaitingSocket, are part of the
  # https:// support implementation.
  # 
  method request_https {downloadHandle} {
    set obj [::hv3::uri %AUTO% [$downloadHandle cget -uri]]

    set host [$obj cget -authority]
    set port 443
    regexp {^(.*):([0123456789]+)$} $host -> host port

    set proxyhost [::http::config -proxyhost]
    set proxyport [::http::config -proxyport]

    $self AddToWaitingList $downloadHandle

    if {$proxyhost eq ""} {
      set fd [socket -async $host $port]
      fileevent $fd writable [mymethod SSocketReady $fd $downloadHandle]
    } else {
      set fd [socket $proxyhost $proxyport]
      fconfigure $fd -blocking 0 -buffering full
      puts $fd "CONNECT $host:$port HTTP/1.1"
      puts $fd ""
      flush $fd
      fileevent $fd readable [mymethod SSocketProxyReady $fd $downloadHandle]
    }
  }
  method SSocketReady {fd downloadHandle} {
    # There is now a tcp/ip socket connection to the https server ready 
    # to use. Invoke ::tls::import to add an SSL layer to the channel
    # stack. Then call [$self request_http] to format the HTTP request
    # as for a normal http server.
    fileevent $fd writable ""
    fileevent $fd readable ""

    if {[info commands $downloadHandle] eq ""} {
      # This occurs if the download-handle was cancelled by Hv3 while
      # waiting for the SSL connection to be established. 
      close $fd
    } else {
      set theWaitingSocket [::tls::import $fd]
      $self request_http $downloadHandle
    }
  }
  method SSocketProxyReady {fd downloadHandle} {
    set str [gets $fd line]
    if {$line ne ""} {
      if {! [regexp {^HTTP/.* 200} $line]} {
        puts "ERRRORR!: $line"
        close $fd
        return
      } 
      while {[gets $fd r] > 0} {}
      $self SSocketReady $fd $downloadHandle
    }
  }

  typevariable theWaitingSocket ""
  typemethod SSocket {host port} {
    set ss $theWaitingSocket
    set theWaitingSocket ""
    return $ss
  }
  # End of code for https://
  #-------------------------

  # Handle a data: URI.
  #
  # RFC2397: # http://tools.ietf.org/html/2397
  #
  #    dataurl    := "data:" [ mediatype ] [ ";base64" ] "," data
  #    mediatype  := [ type "/" subtype ] *( ";" parameter )
  #    data       := *urlchar
  #    parameter  := attribute "=" value
  #
  method request_data {downloadHandle} {
    set uri [$downloadHandle cget -uri]
    set iData [expr [string first , $uri] + 1]

    set data [string range $uri $iData end]
    set header [string range $uri 0 [expr $iData - 1]]

    if {[string match {*;base64} $header]} {
      set bin [::tkhtml::decode -base64 $data]
    } else {
      set bin [::tkhtml::decode $data]
    }

    if {[regexp {^data:///([^,;]*)} $uri dummy mimetype]} {
        $downloadHandle configure -mimetype $mimetype
    }

    $downloadHandle append $bin
    $downloadHandle finish
  }

  method request_blank {downloadHandle} {
    # Special case: blank://
    if {[string first blank: [$downloadHandle cget -uri]] == 0} {
      $downloadHandle append ""
      $downloadHandle finish
      return
    }
  }

  method FinishRequest {downloadHandle} {
    if {[set idx [lsearch $myInProgressHandles $downloadHandle]] >= 0} {
      set myInProgressHandles [lreplace $myInProgressHandles $idx $idx]
    }
    if {[set idx [lsearch $myWaitingHandles $downloadHandle]] >= 0} {
      set myWaitingHandles [lreplace $myWaitingHandles $idx $idx]
    }
    if {[info exists myTokenMap($downloadHandle)]} {
      ::http::reset $myTokenMap($downloadHandle);
      unset myTokenMap($downloadHandle)
    }
    $self Updatestatusvar
  }

  # Update the value of the -statusvar variable, if the -statusvar
  # option is not set to an empty string.
  method Updatestatusvar {} {
    if {$options(-statusvar) ne ""} {
      set    value "[llength $myWaitingHandles] waiting, "
      append value "[llength $myInProgressHandles] in progress"
      uplevel #0 [list set $options(-statusvar) $value]
    }
    catch {$myGui populate}
  }
  
  method busy {} {
    return [expr [llength $myWaitingHandles] + [llength $myInProgressHandles]]
  }

  # Invoked to set the value of the -statusvar option
  method ConfigureStatusvar {option value} {
    set options($option) $value
    $self Updatestatusvar
  }

  # Invoked when data is available from an http request. Pass the data
  # along to hv3 via the downloadHandle.
  #
  method _AppendCallback {downloadHandle socket token} {
    upvar \#0 $token state 

    # If this download-handle is still in the myWaitingHandles list,
    # process the http header and move it to the in-progress list.
    if {0 <= [set idx [lsearch $myWaitingHandles $downloadHandle]]} {

      # Remove the entry from myWaitingHandles.
      set myWaitingHandles [lreplace $myWaitingHandles $idx $idx]

      # Copy the HTTP header to the -header option of the download handle.
      $downloadHandle configure -header $state(meta)

      # Add the handle to the myInProgressHandles list and update the
      # status report variable.
      lappend myInProgressHandles $downloadHandle 
      $self Updatestatusvar
    }

    set data [read $socket 2048]
    set rc [catch [list $downloadHandle append $data] msg]
    if {$rc} { puts "Error: $msg $::errorInfo" }
    set nbytes [string length $data]
    return $nbytes
  }

  # Invoked when an http request has concluded.
  #
  method _DownloadCallback {downloadHandle token} {
#puts "FINISH [$downloadHandle uri]"

    if {
      [lsearch $myInProgressHandles $downloadHandle] >= 0 ||
      [lsearch $myWaitingHandles $downloadHandle] >= 0
    } {
      catch {$myGui uri_done [$downloadHandle cget -uri]}
      $downloadHandle finish
    }

    ::http::cleanup $token
  }

  method debug_cookies {} {
    $myCookieManager debug
  }

  # gui --
  #
  #     This method is called to retrieve the GUI associated with
  #     this protocol implementation. The protocol GUI should be a 
  #     window named $name suitable to [pack] in with the main browser 
  #     window.
  #
  variable myGui ""
  method gui {name} {
    catch {destroy $myGui}
    ::hv3::protocol_gui $name $self
    set myGui $name
  }

  method waiting_handles {} {
    return $myWaitingHandles
  }
  method inprogress_handles {} {
    return $myInProgressHandles
  }
}

snit::widget ::hv3::protocol_gui {
  
  variable myProtocol ""
  variable myTimerId ""

  variable myDoneList [list]

  constructor {protocol} {
    set myProtocol $protocol
    ::hv3::scrolled ::hv3::text ${win}.text -propagate 1
    ${win}.text.widget configure -height 2
    pack ${win}.text -expand 1 -fill both
    $self populate
  }

  destructor {
    catch {after cancel $myTimerId}
  }

  method uri_done {uri} {
    lappend myDoneList $uri
    $self populate
  }

  method populate {} {
    set yview [lindex [${win}.text yview] 0]
    ${win}.text delete 0.0 end

    set n 0
    foreach uri $myDoneList {
      ${win}.text insert end [format "%-15s%s\n" DONE $uri]
      incr n
    }
    foreach h [$myProtocol waiting_handles] {
      ${win}.text insert end [format "%-15s%s\n" WAITING [$h cget -uri]] 
      incr n
    }
    foreach h [$myProtocol inprogress_handles] {
      ${win}.text insert end [format "%-15s%s\n" {IN PROGRESS} [$h cget -uri]]
      incr n
    }

    if {$n > 15} {set n 15}
    if {$n > [${win}.text.widget cget -height]} {
      ${win}.text.widget configure -height $n
    }
    ${win}.text yview moveto $yview
  }
}

# ::hv3::filedownload
#
# Each currently downloading file is managed by an instance of the
# following object type. All instances in the application are managed
# by the [::hv3::the_download_manager] object, an instance of
# class ::hv3::downloadmanager (see below).
#
# SYNOPSIS:
#
#     set obj [::hv3::filedownload %AUTO% ?OPTIONS?]
#
#     $obj set_destination $PATH
#     $obj append $DATA
#     $obj finish
#
# Options are:
#
#     Option        Default   Summary
#     -------------------------------------
#     -source       ""        Source of download (for display only)
#     -cancelcmd    ""        Script to invoke to cancel the download
#
snit::type ::hv3::filedownload {

  # The destination path (in the local filesystem) and the corresponding
  # tcl channel (if it is open). These two variables also define the 
  # three states that this object can be in:
  #
  # INITIAL:
  #     No destination path has been provided yet. Both myDestination and
  #     myChannel are set to an empty string.
  #
  # STREAMING:
  #     A destination path has been provided and the destination file is
  #     open. But the download is still in progress. Neither myDestination
  #     nor myChannel are set to an empty string.
  #
  # FINISHED:
  #     A destination path is provided and the entire download has been
  #     saved into the file. We're just waiting for the user to dismiss
  #     the GUI. In this state, myChannel is set to an empty string but
  #     myDestination is not.
  #
  variable myDestination ""
  variable myChannel ""

  # Buffer for data while waiting for a file-name. This is used only in the
  # state named INITIAL in the above description. The $myIsFinished flag
  # is set to true if the download is finished (i.e. [finish] has been 
  # called).
  variable myBuffer ""
  variable myIsFinished 0

  option -source    -default ""
  option -cancelcmd -default ""
  option -updateguicmd -default ""

  # Total bytes downloaded so far.
  variable myDownloaded 0

  # Total bytes expected (i.e. size of the download)
  variable myExpected 0

  constructor {args} {
    $self configurelist $args
  }

  method set_destination {dest isFinished} {
    if {$isFinished} {
      set myIsFinished 1
    }

    # It is an error if this method has been called before.
    if {$myDestination ne ""} {
      error "This ::hv3::filedownloader already has a destination!"
    }

    if {$dest eq ""} {
      # Passing an empty string to this method cancels the download.
      # This is for conveniance, because [tk_getSaveFile] returns an 
      # empty string when the user selects "Cancel".
      $self Cancel
      destroy $self
    } else {
      # Set the myDestination variable and open the channel to the
      # file to write. Todo: An error could occur opening the file.
      set myDestination $dest
      set myChannel [open $myDestination w]
      fconfigure $myChannel -encoding binary -translation binary

      # If a buffer has accumulated, write it to the new channel.
      puts -nonewline $myChannel $myBuffer
      set myBuffer ""

      # If the myIsFinished flag is set, then the entire download
      # was already in the buffer. We're finished.
      if {$myIsFinished} {
        $self finish {} {}
      }

      ::hv3::the_download_manager manage $self
    }
  }

  # This internal method is called to cancel the download. When this
  # returns the object will have been destroyed.
  #
  method Cancel {} {
    # Evaluate the -cancelcmd script and destroy the object.
    eval $options(-cancelcmd)
    if {$myDestination ne ""} {
      catch {close $myChannel}
      catch {file delete $myDestination}
    }
  }

  # Update the GUI to match the internal state of this object.
  #
  method Updategui {} {
    if {$options(-updateguicmd) ne ""} {
      eval $options(-updateguicmd)
    }
  }

  method append {handle data} {
    set myExpected [$handle cget -expectedsize]
    if {$myChannel ne ""} {
      puts -nonewline $myChannel $data
      set myDownloaded [file size $myDestination]
    } else {
      append myBuffer $data
      set myDownloaded [string length $myBuffer]
    }
    $self Updategui
  }

  # Called by the driver download-handle when the download is 
  # complete. All the data will have been already passed to [append].
  #
  method finish {handle data} {
    if {$data ne ""} {
      $self append $handle $data
    }

    # If the channel is open, close it. Also set the button to say "Ok".
    if {$myChannel ne ""} {
      close $myChannel
      set myChannel ""
    }

    # If myIsFinished flag is not set, set it and then set myElapsed to
    # indicate the time taken by the download.
    if {!$myIsFinished} {
      set myIsFinished 1
    }

    # Update the GUI.
    $self Updategui

    # Delete the download request.
    if {$handle ne ""} {
      $handle destroy
    }
  }

  destructor {
    catch { close $myChannel }
  }

  # Query interface used by ::hv3::downloadmanager GUI. It cares about
  # four things: 
  #
  #     * the percentage of the download has been completed, and
  #     * the state of the download (either "Downloading" or "Finished").
  #     * the source URI
  #     * the destination file
  #
  method state {} {
    if {$myIsFinished} {return "Finished"}
    return "Downloading"
  }
  method percentage {} {
    if {$myIsFinished} {return 100}
    if {$myExpected eq "" || $myExpected == 0} {
      return [expr {$myDownloaded > 0 ? 50 : 0}]
    }
    return [expr double($myDownloaded) / double($myExpected) * 100]
  }
  method bytes {} {
    return $myDownloaded
  }
  method source {} {
    return $options(-source)
  }
  method destination {} {
    return $myDestination
  }
}

# ::hv3::downloadmanager
#
# SYNOPSIS
#
#     set obj [::hv3::downloadmanager %AUTO%]
#
#     $obj show
#     $obj manage FILE-DOWNLOAD
#
#     destroy $obj
#
snit::type ::hv3::downloadmanager {
  variable myDownloads [list]
  variable myHv3List [list]

  method manage {filedownload} {
    $filedownload configure -updateguicmd [mymethod UpdateGui $filedownload]
    lappend myDownloads $filedownload
    $self CheckGuiList
    foreach hv3 $myHv3List {
      $hv3 goto download:
    }
  }

  # This is a helper proc for method [savehandle] to extract any
  # filename-parameter from the value of an HTTP Content-Disposition
  # header. If one exists, the value of the filename parameter is
  # returned. Otherwise, an empty string.
  # 
  # Refer to RFC1806 for the complete format of a Content-Disposition 
  # header. An example is:
  #
  #     {inline ; filename="src.tar.gz"}
  #
  proc ParseContentDisposition {value} {
    set tokens [::hv3::string::tokenise $value]

    set filename ""
    for {set ii 0} {$ii < [llength $tokens]} {incr ii} {
      set t [lindex $tokens $ii]
      set t2 [lindex $tokens [expr $ii+1]]

      if {[string match -nocase $t "filename"] && $t2 eq "="} {
        set filename [lindex $tokens [expr $ii+2]]
        set filename [::hv3::string::dequote $filename]
        break
      }
    }

    return $filename
  }

  # Activate the download manager to save the resource targeted by the
  # ::hv3::download passed as an argument ($handle) to the local 
  # file-system. It is the responsbility of the caller to configure 
  # the download-handle and pass it to the protocol object. The second
  # argument, $data, contains an initial segment of the resource that has
  # already been downloaded. 
  #
  method savehandle {handle data isFinished} {

    # Create a GUI to handle this download
    set dler [::hv3::filedownload %AUTO%                \
        -source    [$handle cget -uri]                  \
        -cancelcmd [list catch [list $handle fail]]     \
    ]
    ::hv3::the_download_manager show

    # Redirect the -incrscript and -finscript commands to the download GUI.
    $handle configure -finscript  [list $dler finish $handle]
    $handle configure -incrscript [list $dler append $handle]
    $dler append $handle $data

    # Figure out a default file-name to suggest to the user. This
    # is one of the following (in order of preference):
    #
    # 1. The "filename" field from a Content-Disposition header. The
    #    content disposition header is described in RFC 1806 (and 
    #    later RFC 2183). A Content-Disposition header looks like
    #    this:
    #
    # 2. By extracting the tail of the URI.
    #
    set suggested ""
    foreach {key value} [$handle cget -header] {
      if {[string equal -nocase $key Content-Disposition]} {
        set suggested [ParseContentDisposition $value]
      }
    }
    if {$suggested eq ""} {
      regexp {/([^/]*)$} [$handle cget -uri] -> suggested
    }

    # Pop up a GUI to select a "Save as..." filename. Schedule this as 
    # a background job to avoid any recursive entry to our event handles.
    set cmd [subst -nocommands {
      $dler set_destination [file normal [
          tk_getSaveFile -initialfile {$suggested}
      ]] $isFinished
    }]
    after idle $cmd
  }

  method CheckGuiList {} {
    # Make sure the list of GUI's is up to date.
    set newlist [list]
    foreach hv3 $myHv3List {
      if {[info commands $hv3] eq ""} continue
      if {[string match download* [$hv3 location]] && [$hv3 pending] == 0} {
        lappend newlist $hv3
      } 
    }
    set myHv3List $newlist
  }

  method UpdateGui {{fdownload ""}} {
# puts "UPDATE $fdownload"

    $self CheckGuiList

    set dl_list $fdownload
    if {[llength $dl_list] == 0} {
      set dl_list $myDownloads
    } 
    foreach filedownload $dl_list {
      set id [string map {: _} $filedownload]
      foreach hv3 $myHv3List {

        set search "#$id .progressbar"
        foreach N [$hv3 search $search] {
          $N override [list width [$filedownload percentage]%]
        }

        set search "#$id .downloading"
        set val visible
        if {[$filedownload state] eq "Finished"} {
          set val hidden
        }
        foreach N [$hv3 search $search] { 
          $N override [list visibility $val] 
        }

        set val hidden
        if {[$filedownload state] eq "Finished"} {
          set val visible
        }
        set search "#$id .finished"
        foreach N [$hv3 search $search] { 
          $N override [list visibility $val] 
        }

        set search "#$id .button"
        foreach N [$hv3 search $search] { 
          set a(Finished)    Dismiss
          set a(Downloading) Cancel
          $N attr value $a([$filedownload state])
        }

        set search "#$id .status span"
        foreach N [$hv3 search $search] { 
          set percent [format %.2f%s [$filedownload percentage] %]
          set bytes [$filedownload bytes]
          switch -- [$filedownload state] {
            Downloading { set status "Downloaded $bytes bytes ($percent)" }
            Finished    { set status "Finished ($bytes bytes)" }
          }
          $N attr spancontent $status
        }
      }
    }
  }

  method request {hv3 handle} {

    set uri [$handle cget -uri]
    if {[regexp {.*delete=([^=&]*)} $uri -> delete]} {
      set dl [string map {__ ::} $delete]
      set newlist [list]
      foreach download $myDownloads {
        if {$download ne $dl} {lappend newlist $download}
      }
      set myDownloads $newlist
      catch {
        if {[$dl state] ne "Finished"} {
          $dl Cancel
        }
        $dl destroy
      }
      $handle append ""
      $handle finish
      $self CheckGuiList
      foreach hv3 $myHv3List {
        after idle [list $hv3 goto download:]
      }
      return
    }

    set document {
      <html><head>
        <style>
          .download { border:solid black 1px; width:90%; margin: 1em auto; }
          .download td { padding: 0px 5px; } 
          .source { width:99%; }
          .progress .progressbarwrapper { border:solid black 1px; width:100%; }
          .progress .progressbar { background-color: navy; height: 1em; }
          .buttons { display:block;width:12ex }
          input { float:right; }
        </style>
        <title>Downloads</title>
        </head>
        <body>
          <h1 align=center>Downloads</h1>
    }
 
    append document "<p>There are [llength $myDownloads] downloads.</p>"

    foreach download $myDownloads {
      set id [string map {: _} $download]
      append document [subst {
        <table class="download" id="$id">
          <tr><td>Source:      
              <td class="source">[$download source]
              <td rowspan=4 valign=bottom>
                 <div class="buttons">
                      <form method=get action=download:///>
                      <input class="button"      type=submit value=Cancel>
                      <input name="delete"       type=hidden value=$id>
                      </form>
          <tr><td>Destination: 
              <td class="destination">[$download destination]
          <tr><td>Status:      
              <td class="status">
                <span spancontent="Waiting (0%)">
              </td>
          <tr><td>Progress:    
              <td class="progress">
                 <div class="progressbarwrapper">
                 <div class="progressbar">
        </table>
      }]
    }

    if {[lsearch $myHv3List $hv3] < 0} {
      lappend myHv3List $hv3
    }

    $handle append $document
    $handle finish

    after idle [list $self UpdateGui]
  }

  method show {} {
    $self CheckGuiList
    if {[llength $myHv3List] > 0} {
      set hv3 [lindex $myHv3List 0]
      set win [winfo parent [winfo parent $hv3]]
      $::hv3::G(notebook) select $win
    } else {
      $::hv3::G(notebook) add download:
    }
  }
}

proc ::hv3::download_scheme_init {hv3 protocol} {
  $protocol schemehandler download [
    list ::hv3::the_download_manager request $hv3
  ]
}

#-----------------------------------------------------------------------
# Work around a bug in http::Finish
#

# First, make sure the http package is actually loaded. Do this by 
# invoking ::http::geturl. The call will fail, since the arguments (none)
# passed to ::http::geturl are invalid.

#Tell checker to not bother reporting the problem, this is intentionally bogus
#checker exclude numArgs
catch {::http::geturl}

# Declare a wrapper around ::http::Finish
proc ::hv3::HttpFinish {token args} {
  upvar 0 $token state
  catch {
    close $state(sock)
    unset state(sock)
  }
  eval [linsert $args 0 ::http::FinishReal $token]
}

# Install the wrapper.
rename ::http::Finish ::http::FinishReal
rename ::hv3::HttpFinish ::http::Finish
#-----------------------------------------------------------------------

