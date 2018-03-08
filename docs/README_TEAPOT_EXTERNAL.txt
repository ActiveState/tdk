
Please read README_TEAPOT.txt first.

Handling externally supplied teabags
====================================

ActiveState's side
------------------

To publish an externally supplied teabags for some package or other we
(AS) first have to get a valid bag file from the supplier.

Once we have such a file we can use

     teapot-pkg show FILE

to see the meta data. This partially checks validity of the file as
well, in the sense, that it fails if the meta data is not in the
expected place.

To inject into the publication process I propose that we run


	  % teapot-admin add R.Public FILE
	  % /whereever/publish_pot.sh R.Public

I.e. add the bag to the master repository on iguana and then initiate
a publication cycle. When the next nightly build runs this state is
aslo saved to crimper. We can leave out the second command if the
publication does not have to be done immediately. In that case the
actual publication to the web cluster also happens at the next nightly
build.


Supplier side
-------------

Now, how to get a teabag from a regular build ?

First let us see how we are doing it.

	For binary packages our buildsystem runs the regular package
	build code first. Then it runs a heuristic to extract
	information like the version number, main entry file,
	etc. This information is merged into a fixed teapot.txt we
	have for the package, in perforce. The result of the merge is
	copied into the install-dir for the package.

	At that point we run the internal equivalent of

		teapot-pkg generate -o OUTPUTDIR -type auto INSTALLDIR

	The code for our heuristics is internal, and the supplier will
	IMHO be better off to write and maintain the relevant
	teapot.txt file directly.

So, for the trusted supplier of a package FOO the basic steps are

	Once
	1. Write a teapot.txt for FOO

	Per Build
	2. Run whatever system is used to build FOO
	3. Copy the teapot.txt from step 1 to the INSTALLDIR
	4. Run teapot-pkg generate -o OUTPUTDIR -type auto INSTALLDIR
	5. Copy the resulting teabags from OUTPUTDIR to whereever
	   for upload to us.

Here is an example teapot.txt file, for the package Memchan

	Package Memchan 2.2.1
	Meta platform        linux-glibc2.2-ix86
	Meta entrykeep       .
	Meta excluded        *.a *.tap *.lib
	Meta included        *.tcl *.so *.sl *.dll *.dylib

	Meta require         {Tcl -require 8.4}
	Meta category        Channels
	Meta description     Memchan provides several new channel types for
	Meta description     in-memory channels and the appropriate commands for
	Meta description     their creation. They are useful to transfer large
	Meta description     amounts of data between procedures or interpreters,
	Meta description     and additionally provide an easy interface to
	Meta description     on-the-fly generation of code or data too. No need
	Meta description     to {[set]} or {[append]} to a string, just do a
	Meta description     simple {[puts].}
	Meta subject         channel memory fifo thread
	Meta summary         In-memory channels for Tcl.

In this example the important keys have been moved to the top

	Included	Glob patterns defining which files in INSTALLDIR
			belong to the package.

	Excluded	Glob patterns defining which files in INSTALLDIR
			do NOT belong to the package.

		Files in the intersection of Included & Excluded do
		not belong into the package. I.e. Excluded has
		priority over Included. I.e.

			Files = Included - Excluded

	Platform	The platform identifier for the package.
			IMHO this value should not be hardwired by the
			supplier, but inserted in step 3 above, using
			the package 'platform' to generate a suitable
			value.

	EntryKeep	This simply means that pkgIndex.tcl of the
			package shall be taken as is for the tea bag.

			This undocumented meta data key is IMHO the
			best, certainly the easiest way of handling a
			legacy package.

			Undocumented as in the documentation for
			teapot-pkg admits only to knowledge of the
			keys "EntrySource" and "EntryLoad".

			Internally, i.e. in AS's build system
			'EntryKeep' is the standard key used to create
			the bags for binary packages.

			See
			//depot/main/Apps/ActiveTcl/build/build/binary.tcl,
			line 118.

The manpage of teapot-pkg provides much of the same information.

			 
