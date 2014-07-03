#!/usr/bin/perl
#####################################################
# gnudip.cgi
#
# This is the GnuDIP Web Tool.
#
# See COPYING for licensing information.
#
# Derived from GnuDIP 2.1.2 written by:
#
#   Mike Machado
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

# GnuDIP CGI subroutine
use gdipcgi;

# run the CGI
gdipcgi();

