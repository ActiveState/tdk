# Copyright (c) 2018 ActiveState Software Inc.
# Released under the BSD-3 license. See LICENSE file for details.
#
# potDescWidget.tcl --
#
#	Display & Edit of teapot meta data
#
# Copyright (c) 2007 ActiveState Software Inc.

# 
# RCS: @(#) $Id: Exp $
#
# -----------------------------------------------------------------------------

# ** TODO **
#
# ** Consider to factorize the id panel out of this widget into its own.
# ** Consider to move the factored id panel into the outer display widget.
# ** Have to extend either this widget, or the out with a panel allowing
#    the user to enter arbitrary meta data.

# -----------------------------------------------------------------------------

package require snit
package require tipstack
package require struct::list
package require teapot::entity

# -----------------------------------------------------------------------------

snit::widget tcldevkit::teapot::descWidget {
    hulltype ttk::frame

    option -connect         -default {}
    option -errorbackground -default lightyellow

    constructor {args} {
	$self MakeWidgets
	$self PresentWidgets

	# Handle initial options.
	$self configurelist $args
	return
    }

    destructor {
	tipstack::clearsub $win

	trace vdelete [myvar ptype]    w [mymethod ChangeType]
	trace vdelete [myvar pname]    w [mymethod ChangeName]
	trace vdelete [myvar pversion] w [mymethod ChangeVersion]
	trace vdelete [myvar parch]    w [mymethod ChangeArch]

	trace vdelete [myvar summary]  w [mymethod ChangeSummary]
    }

    method MakeWidgets {} {
	# Consider factorization of the id panel into a separate widget.
	# Consider movement of such a widget to the outer package display.

	set base {
	    ttk::labelframe  .id        {-text "Identification"}
	    ttk::combobox    .id.type   {}
	    ttk::entry       .id.name   {}
	    ttk::entry       .id.vers   {}
	    ttk::entry       .id.arch   {}
	    ttk::label       .id.tl     {-text Type}
	    ttk::label       .id.nl     {-text Name}
	    ttk::label       .id.vl     {-text Version}
	    ttk::label       .id.al     {-text Platform}
	    ttk::labelframe  .su        {-text "Summary"}
	    ttk::entry       .su.e      {}
	    ttk::labelframe  .desc      {-text "Description"}
	    text             .desc.t    {-width 10 -height 10}
	}
	foreach {type w static_opts} $base {
	    eval [linsert $static_opts 0 $type $win$w]
	}

	# Load combobox listbox from low-level entity package, accept
	# that we do not accept doc entities, so these are fitlered
	# out.

	$win.id.type configure -values \
	    [struct::list map \
		 [struct::list filter \
		      [::teapot::entity::names] \
		      [myproc nodoc]] \
		 ::teapot::entity::display]

	$win.id.type configure -textvariable [myvar ptype]
	$win.id.name configure -textvariable [myvar pname]
	$win.id.vers configure -textvariable [myvar pversion]
	$win.id.arch configure -textvariable [myvar parch]

	# The text field is not linked directly. Instead it is saved
	# whenever the data would change because of switches or
	# deactivation. See 'do select'.

	trace variable [myvar ptype]    w [mymethod ChangeType]
	trace variable [myvar pname]    w [mymethod ChangeName]
	trace variable [myvar pversion] w [mymethod ChangeVersion]
	trace variable [myvar parch]    w [mymethod ChangeArch]

	$win.su.e    configure -textvariable [myvar summary]

	trace variable [myvar summary]  w [mymethod ChangeSummary]
	return
    }

    method PresentWidgets {} {
	foreach {slave col row stick padx pady span} {
	    .id         0 0 swen 8  8  1
	    .su         0 1 swen 8  8  1
	    .desc       0 2 swen 8  8  1

	    .id.tl      0 0 swen 1m 1m 1
	    .id.type    1 0  wen 1m 1m 1
	    .id.nl      0 1 swen 1m 1m 1
	    .id.name    1 1  wen 1m 1m 1
	    .id.vl      0 2 swen 1m 1m 1
	    .id.vers    1 2  wen 1m 1m 1
	    .id.al      0 3 swen 1m 1m 1
	    .id.arch    1 3  wen 1m 1m 1

	    .su.e       0 0 swen 1m 2m 1

	    .desc.t     0 0 swen 1m 2m 1
	} {
	    grid $win$slave -column $col -row $row -sticky $stick -padx $padx -pady $pady -rowspan $span
	}

	foreach {master col weight} {
	    {}   0 1    .desc 0 1   .su   0 1
	    .id  0 0    .id  1 0    .id  2 0    .id  3 1
	} {
	    grid columnconfigure $win$master $col -weight $weight
	}
	foreach {master row weight} {
	    {}    0 0    {}    1 0    {}    2 1    .desc 0 1    .su   0 1
	    .id   0 0    .id   1 0    .id   2 0    .id   3 0    .id   4 1
	} {
	    grid rowconfigure $win$master $row -weight $weight
	}

	tipstack::defsub $win {
	    .desc    {Textual description of the package}
	    .desc.t  {Enter the textual description of the package}
	    .su      {One line summary of the package}
	    .su.e    {Enter the one line summary of the package}
	    .id      {Basic information about the package}
	    .id.type {Type of described entity}
	    .id.name {Name of the package}
	    .id.vers {Version of the package}
	    .id.arch {Platform the package can be used on}
	}

	return
    }

    proc nodoc {x} {expr {![string equal $x documentation]}}

    variable ptype
    variable pname
    variable pversion
    variable parch
    variable summary

    method ChangeType {args} {
	$self UpCall changeType $ptype
	return
    }

    method ChangeName {args} {
	$self UpCall changeName $pname
	return
    }

    method ChangeVersion {args} {
	$self UpCall changeVersion $pversion
	return
    }

    method ChangeArch {args} {
	$self UpCall changeArch $parch
	return
    }

    method ChangeSummary {args} {
	$self UpCall changeSummary $summary
	return
    }

    method UpCall {args} {
	# Assume that -connect is set.
	return [uplevel \#0 [linsert $args 0 $options(-connect)]]
    }

    method {do error@} {index key msg} {
	switch -exact -- $key {
	    type     {set w $win.id.type}
	    name     {set w $win.id.name}
	    version  {set w $win.id.vers}
	    platform {set w $win.id.arch}
	}

	$w state !invalid
	tipstack::pop $w

	if {$msg != {}} {
	    $w state invalid
	    tipstack::push $w $msg
	}
	return
    }

    method {do select} {selection} {
	# The model changes the currently shown package.

	# This is usually followed by a 'refresh-current' to re-load
	# the widget state. Therefore save the current description
	# back to the model (which hasn't switched to the new package
	# just yet).

	$self UpCall changeDescription [string trimright [$win.desc.t get 0.1 end-1c]]
	return
    }

    method {do refresh-current} {} {
	$win.id.type configure -state normal
	$win.id.name configure -state normal
	$win.id.vers configure -state normal
	$win.id.arch configure -state normal
	$win.desc.t  configure -state normal
	$win.su.e    configure -state normal

	set ptype    [$self UpCall getType]
	set pname    [$self UpCall getName]
	set pversion [$self UpCall getVersion]
	set parch    [$self UpCall getArch]
	set summary  [$self UpCall getSummary]

	$win.desc.t delete 0.1 end
	$win.desc.t insert end [$self UpCall getDescription]

	$win.id.type state !invalid
	return
    }

    method {do no-current} {} {
	set ptype    package ; # Default entity, valid.
	set pname    {}
	set pversion {}
	set parch    {}
	set summary  {}

	$win.desc.t delete 0.1 end

	$win.id.type configure -state disabled
	$win.id.name configure -state disabled
	$win.id.vers configure -state disabled
	$win.id.arch configure -state disabled
	$win.desc.t  configure -state disabled
	$win.su.e    configure -state disabled
	return
    }
}

# -----------------------------------------------------------------------------
package provide tcldevkit::teapot::descWidget 1.0
