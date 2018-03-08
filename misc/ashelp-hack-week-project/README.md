# Overview

In the `ashelp` project we used sqlite3 databases as container for
HTML help files, sort of like an opensource CHM format and archive and
the `ashelp` application itself was the viewer. The `Tkhtml` widget
used for it (v3) made trouble on some platforms IIRC.

There was the idea of possible storing these archives in the teapot,
for installation alongside with their packages, and modifying the
viewer to automatically look for them in a local repository. This was
never followed up on nor completed.
