# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# -*- tcl -*-
#
# File properties dialog
#

package require BWidget
package require snit
package require syscolor
package require image    ; image::file::here
package require stringfileinfo      ; # for reading Windows DLL info
package require widget::dialog

snit::widgetadaptor fproperty {
    delegate method * to hull
    delegate option * to hull

    option -path ""

    variable directory {}
    variable tail      {}
    variable fullpath  {}
    variable fileinfo  {}

    component notebook
    component general
    component version

    constructor {args} {
	installhull using widget::dialog -type ok \
	    -command [mymethod OnOK] -title "File Properties" \
	    -synchronous 0

	install notebook using ttk::notebook $win.nb -padding 8
	$win setwidget $notebook

	install general using ttk::frame $notebook.general -padding 4
	install version using ttk::frame $notebook.version -padding 4

	$notebook add $general -text "General" -sticky news
	$notebook add $version -text "Version" -sticky news

	$notebook select $general

	$self configurelist $args
    }

    onconfigure -path {value} {
	if {$options(-path) eq $value} { return }
	if {0&&![file exists $value]} {
	    return -code error "file \"$value\" does not exist"
	}
	set options(-path) $value

	set fullpath  $value
	set directory [file dirname $fullpath]
	set tail      [file tail    $fullpath]

	$self refresh
    }

    method refresh {} {
	wm title $win "$tail Properties"

	$self GeneralPage
	if {([string match -nocase "*.dll" $tail]
	    || [string match -nocase "*.exe" $tail])
	    && ![catch {stringfileinfo::getStringInfo $fullpath fi}]} {
	    set fileinfo [array get fi]
	    $notebook tab $version -state normal
	    $self VersionPage
	} else {
	    $notebook tab $version -state disabled
	    $notebook select $general
	}
    }


    method OnOK {w result} {
	if {$result eq "ok"} {
	    set nfileinfo [$self VersionInfo]

	    if {$fileinfo ne $nfileinfo} {
		# Overwrite the strings information with the new strings.

		array set nsi $nfileinfo

		if {[catch {
		    ::stringfileinfo::writeStringInfo $fullpath nsi
		} msg]} {
		    return -code error $msg
		}
	    }
	}
	# each path gets it's own, and we don't assume users will
	# reuse these properties dialogs much
	after idle [list destroy $win]
    }

    # ### ######### ###########################
    ## General Page
    variable ar
    variable aw
    variable ax
    variable ah
    variable as
    variable aa

    method GeneralPage {} {
	global tcl_platform
	set p $general

	# TODO: properties should get 'ftype' object for icons ...
	# NOTE: Path may not exist.

	ttk::label $p.img -image \
	    [image::get [[[[.fsb cget -data] details] cget -icon] icon big $fullpath]]

	# This should allow editing and renaming - but not yet
	ttk::entry $p.name -textvariable [varname tail] \
	    -state readonly

	ttk::separator $p.div0 -orient horizontal
	ttk::separator $p.div1 -orient horizontal
	ttk::separator $p.div2 -orient horizontal

	ttk::label $p.typel -text "Type:" -anchor nw
	ttk::label $p.type  \
		-justify left -anchor nw \
		-text [join [$self TypeInformation $fullpath] \n]

	ttk::label $p.locl -text "Location:"
	#ttk::entry $p.loc -bd 0 -bg [$p.locl cget -bg] -fg [$p.locl cget -fg]
	ttk::entry $p.loc
	$p.loc insert 0 $directory
	$p.loc configure -state readonly

	if {![file exists $fullpath]} {
	    set sz "N/A"
	} elseif {[file isfile $fullpath]} {
	    set size [file size $fullpath]
	    set sz "[format %.1f [expr {$size/1024.0}]] KB ($size bytes)"
	} else {
	    set sz ""
	}

	ttk::label $p.sizel -text "Size:"
	ttk::label $p.size  -text $sz

	if {![file exists $fullpath]} {
	    array set stat {
		ctime {}
		mtime {}
		atime {}
	    }
	} else {
	    file stat $fullpath stat
	    #parray stat
	}

	foreach {cmd text} {
	    ctime Created:
	    mtime Modified:
	    atime Accessed:
	} {
	    ttk::label $p.${cmd}l -text $text
	    # use locale-specific clock format
	    ttk::label $p.${cmd}  -text [expr {($stat($cmd) eq "") ? "N/A" : [clock format $stat($cmd) -format "%c"]}]
	}

	ttk::separator $p.div3 -orient horizontal
	ttk::label     $p.attr -text "Attributes:"
	if {$tcl_platform(platform) eq "unix"} {
	    ttk::checkbutton $p.ar -text Readable   -variable [varname ar]
	    ttk::checkbutton $p.aw -text Writable   -variable [varname aw]
	    ttk::checkbutton $p.ax -text Executable -variable [varname ax]

	    set ar [file readable   $fullpath]
	    set aw [file writable   $fullpath]
	    set ax [file executable $fullpath]

	} elseif {$tcl_platform(platform) eq "windows"} {
	    ttk::checkbutton $p.aa  -text Archive   -variable [varname aa]
	    ttk::checkbutton $p.as  -text System    -variable [varname as]
	    ttk::checkbutton $p.aro -text Read-only -variable [varname ar]
	    ttk::checkbutton $p.ahd -text Hidden    -variable [varname ah]

	    set aa [file attributes $fullpath -archive]
	    set ar [file attributes $fullpath -readonly]
	    set ah [file attributes $fullpath -hidden]
	    set as [file attributes $fullpath -system]
	}

	foreach {w r c cs px py st} {
	    img     0 0 2 0 0 w
	    name    0 1 2 0 0 we
	    div0    1 0 3 0 2 we
	    typel   2 0 2 0 0 nw
	    type    2 1 2 0 0 w
	    div1    4 0 3 0 2 we
	    locl    5 0 2 0 0 w
	    loc     5 1 2 0 0 ew
	    sizel   6 0 2 0 0 w
	    size    6 1 2 0 0 w
	    div2    7 0 3 0 2 we
	    ctimel  8 0 2 0 0 w
	    ctime   8 1 2 0 0 w
	    mtimel  9 0 2 0 0 w
	    mtime   9 1 2 0 0 w
	    atimel 10 0 2 0 0 w
	    atime  10 1 2 0 0 w
	    div3   11 0 3 0 2 we
	    attr   12 0 1 0 0 w
	    ar     12 1 2 0 0 w
	    aw     13 1 2 0 0 w
	    ax     14 1 2 0 0 w
	    aa     12 1 1 0 0 w
	    as     12 2 1 0 0 w
	    aro    13 1 1 0 0 w
	    ahd    13 2 1 0 0 w
	} {
	    if {![winfo exists $p.$w]} continue
	    grid $p.$w -column $c -row $r -columnspan $cs \
		-sticky $st -padx $px -pady $py
	    grid rowconfigure $p $r -weight 0
	}

	grid columnconfigure $p {1 2} -weight 1
	grid rowconfigure    $p 15 -weight 1

	return
    }

    method VersionPage {} {
	set p $version

	foreach {key val} $fileinfo {
	    ttk::label $p.l$key -text "$key:" -anchor w
	    ttk::entry $p.e$key
	    $p.e$key insert end $val
	    $p.e$key configure ;#-state readonly

	    grid $p.l$key $p.e$key -sticky ew
	}

	grid columnconfigure $p 1 -weight 1
	grid rowconfigure $p [lindex [grid size $p] 1] -weight 1
    }

    method VersionInfo {} {
	set p $version
	set res {}
	foreach {key val} $fileinfo {
	    lappend res $key [$p.e$key get]
	}

	return $res
    }

    method anOrA {string} {
	if {[regexp {^[aeiouAEIOU]} $string]} {
	    return an
	} else {
	    return a
	}
    }

    method TypeInformation {path} {
	global tcl_platform

	if {![file exists $path]} {
	    return {{File does not exist}}
	}

	set tcltype  ""
	set unixtype ""
	## set mix      ""
	set link     ""

	# ### ######### ###########################
	## Determine various data about the file.

	set path [file normalize $path]
	set fs [file system $path]

	if {[file readable $path]} {
	    ##lappend mix readable
	    set tcltype  [fileutil::fileType $path]

	    if {$tcl_platform(platform) eq "unix"} {
		if {[file isdirectory $path]} {
		    set unixtype directory
		} else {
		    set extpath [file normalize [file::Temporize $path]]
		    set unixtype [exec file $extpath]
		    if {$extpath ne $path} {
			file delete $extpath
		    }
		    if {$unixtype != {}} {
			regsub {^[^:]*: } $unixtype {} unixtype
		    }
		    set unixtype [string trim $unixtype]
		}

		set unixtype "[$self anOrA $unixtype] $unixtype"
	    }
	}

	if 0 {
	    if {[file writable $path]}   {lappend mix writable}
	    if {[file executable $path]} {lappend mix executable}
	}
	if {[file type $path] eq "link"} {
	    set link [file readlink $path]
	}

	set wintype [[[.fsb cget -data] details] filetype $path]
	set wintype "[$self anOrA $wintype] $wintype"

	# ### ######### ###########################
	## Combine data into report

	set result [list]

	lappend result "Filesystem: $fs"
	if {$link != {}} {
	    lappend result "Link to $link"
	}
	if {[llength $tcltype]} {
	    if {[llength $tcltype] == 1} {
		set tcltype "[$self anOrA $tcltype] $tcltype"
	    }
	    lappend result "Tcl sees $tcltype"
	}
	if {$unixtype != {}} {
	    lappend result "Unix sees $unixtype"
	}
	lappend result "Windows sees $wintype"

	if 0 {
	    if {[llength $mix]} {
		lappend result "File is [join $mix ", "]"
	    }
	}

	# ### ######### ###########################
	return $result
    }

    # ### ######### ###########################
}

# ### ######### ###########################
## Ready to use

package provide fproperty 0.2
