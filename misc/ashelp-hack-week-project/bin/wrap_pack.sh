#!/bin/sh

bin=$(dirname $0)


time tclapp -nologo -verbose \
    -archive ~/.teapot/repository \
    -prefix $HOME/TDK/bin/base-tk-linux-ix86 \
    -out hv_ashelp \
    -pkgref 'Tkhtml 3.0' \
    -pkgref 'sqlite3 3.3.17' \
    -pkgref Img \
    -pkgref fileutil \
    -pkgref fileutil::traverse \
    -pkgref 'snit 1' -pkgref htmlparse \
    -pkgref struct::list -pkgref struct::stack \
    -pkgref tdom -pkgref widget::scrolledwindow \
    -pkgref treectrl -pkgref tile \
    -pkgref cmdline -pkgref control -pkgref widget \
    -pkgref img::base -pkgref img::gif -pkgref img::bmp \
    -pkgref img::ico -pkgref img::jpeg -pkgref img::pcx \
    -pkgref img::pixmap -pkgref img::png -pkgref img::ppm \
    -pkgref img::ps -pkgref img::sgi -pkgref img::sun \
    -pkgref img::tga -pkgref img::tiff -pkgref img::window \
    -pkgref img::xbm -pkgref img::xpm -pkgref jpegtcl \
    -pkgref pngtcl -pkgref zlibtcl -pkgref tifftcl \
    -startup                    hv/hv3_main.tcl \
    -anchor hv  -relativeto hv  hv/* \
    -anchor lib -relativeto lib lib/ashelp/* \
> LOG 2>&1
tail LOG

# Packages after Img -> ashelp support. sqlite3 is the sole exception,
# it is already listed for hv3 itself, so not listed again.

# Note: Tls, and Tclsee are optional packages, for https support, and
# javascript. Leaving them out for now, our prototype doesn't do
# security, nor dynamic stuff.

# Note 2: Also reduced is the number of supported image formats.
