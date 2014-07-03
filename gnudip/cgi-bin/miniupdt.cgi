#!/usr/bin/perl
#####################################################
# miniupdt.cgi
#
# This is the MiniDIP HTTP update server.
#
# See COPYING for licensing information.
#
#####################################################

# for mod_perl compatibility
package minidip;

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

# MiniDIP update server CGI subroutine
use miniupdt;

# run the CGI
miniupdt();

