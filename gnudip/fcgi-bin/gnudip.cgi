#!/usr/bin/perl
#####################################################
# gnudip.cgi
#
# This is the GnuDIP Web Tool for FastCGI.
#
# See COPYING for licensing information.
#
#####################################################

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

# global variables
use vars qw($conf); 

# GnuDIP modules
use gdipfcgi;
use gdipcgi;

# function to run before accept
my $init = sub {
  # read header and trailer HTML files
  htmlgen_init();
  # initiate DB connection and get configuration data from DB
  getprefs();
  getdomains();
};

# run the CGI
gdipfcgi($init, \&gdipcgi);

