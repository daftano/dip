![GnuDIP Logo](gnudip/html/gnudip.jpg)

GnuDIP Release 2.3.5 - README File
==================================

* * * * *

This is GnuDIP Release 2.3.5.

The GnuDIP software implements a Dynamic IP DNS service. It provides
clients with a static DNS name even if their IP address is dynamically
assigned.

GnuDIP is written in [Perl](http://www.perl.com/).

GnuDIP has two main parts on the server side:

-   a daemon that listens for client requests and
-   a web interface that is used as the administration tool and as the
    user's tool to manage their own account.

A client which works with both Linux/UNIX and Windows is also provided.

GnuDIP is released under the GPL. Please see the file
[`COPYING`](COPYING) included in this distribution for more information.

* * * * *

The client Perl script, for Linux/UNIX, may be found in the directory:

> [gnudip/client/UNIX/](gnudip/client/UNIX/).

The directory above has a tar ball for the latest release, and a
directory which is just the unpacked tar ball which you can browse
through.

Using the client with Linux/UNIX is described in the file
[`gnudip/client/UNIX/gdipc/CLIENT.html`](gnudip/client/UNIX/gdipc/CLIENT.html).

The same client Perl script, but with minor changes to adapt it to the
Windows environment, may be found in the directory:

> [gnudip/client/Windows/](gnudip/client/Windows/).

The directory above has a Windows self-extracting zip executable file
and a directory which is just the expanded zip file which you can browse
through.

To use this software you must first install
[ActivePerl](http://aspn.activestate.com/ASPN/Downloads/ActivePerl/).
This software is a free port of Perl to Windows

Using the client with Windows is described in the file
[`gnudip/client/Windows/gdipc/CLIENT.html`](gnudip/client/Windows/gdipc/CLIENT.html).

A version of the Windows client package containing enough files from
ActivePerl to run stand alone may be found in the directory:

> [gnudip/client/Windows\_standalone/](gnudip/client/Windows_standalone/).

* * * * *

More specifically, the requirements are:

-   [the base Perl Language
    system](http://www.perl.com/pub/a/language/info/software.html)
-   the `nsupdate` command from either [BIND
    8](http://isc.org/products/BIND/bind8.html) or [BIND
    9](http://isc.org/products/BIND/bind9.html)
-   the `sendmail` command from [Sendmail](http://www.sendmail.org/) or
    the clone program provided by Sendmail replacements such as
    [Exim](http://www.exim.org/), [qmail](http://qmail.org/) or
    [Postfix](http://www.postfix.org/).

More specifically you need Perl version 5.6.0 or later. You can use Perl
5.005 if you are prepared to install a "dummy" `warnings.pm` file. This
is explained in [`INSTALL.html`](INSTALL.html).

To use secret key rather than IP address access control for dynamic DNS
you may also want the `dnskeygen` command from BIND 8 or the
`dnssec-keygen` command from BIND 9, to generate input files for
nsupdate, and probably the key values in them.

Although not required, GnuDIP will run a bit faster if you install [the
Perl Digest-MD5 module](http://search.cpan.org/search?dist=Digest-MD5).

In order to use [MySQL](http://mysql.com/) rather than the Linux/UNIX
file system for Web Tool configuration and user information, you will
also need:

-   [the MySQL database management
    software](http://mysql.com/downloads/mysql.html)
-   [the Perl DBI module](http://search.cpan.org/search?module=DBI)
-   [the DBI MySQL
    driver](http://search.cpan.org/search?module=DBD::mysql)

In order to use [PostreSQL](http://postgresql.com/) rather than the
Linux/UNIX file system for Web Tool configuration and user information,
you will also need:

-   [the PostreSQL database management
    software](http://www.postgresql.com/mirrors-ftp.html)
-   [the Perl DBI module](http://search.cpan.org/search?module=DBI)
-   [the DBI PostgreSQL
    driver](http://gborg.postgresql.org/project/dbdpg/projdisplay.php)

If you have [Linux](http://www.kernel.org/),
[OpenBSD](http://openbsd.org/) or such, Perl (including the DBI module),
BIND and Sendmail will probably be available as options from your
installation CD. You may need to obtain and install the rest.

Read [`INSTALL.html`](INSTALL.html) for instructions on installing
GnuDIP.

* * * * *

Changes since Release 2.1.2 are discussed in the file
[`release.html`](release.html).

* * * * *

The protocol used between the client and the update server is described
in the file [gnudip/html/protocol.html](gnudip/html/protocol.html).

* * * * *

This package includes a bare bones version of GnuDIP with no database or
web tool. There is a single configuration file, which includes the list
of host names and their passwords.

* * * * *
This software is derived from GnuDIP Release 2.1.2, which was the work of Mike Machado.

Release 2.3.5 of GnuDIP was written by Creighton MacDonnell.

