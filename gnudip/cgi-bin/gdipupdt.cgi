#!/usr/bin/perl
#####################################################
# gdipupdt.cgi
#
# This is the GnuDIP HTTP update server.
#
# See COPYING for licensing information.
#
#####################################################

# for mod_perl compatibility
package gnudip;

# Perl modules
use strict;

# locate ourselves
use vars qw($gnudipdir);
use FindBin;
BEGIN {
  $gnudipdir = '';
  if ($FindBin::Bin =~ /(.*)\/.+?/) {
    $gnudipdir = $1;
  }
}
use lib "$gnudipdir/lib";

# GnuDIP update server CGI subroutine
use gdipupdt;

# run the CGI
gdipupdt();

