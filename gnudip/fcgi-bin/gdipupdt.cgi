#!/usr/bin/perl
#####################################################
# gdipupdt.cgi
#
# This is the GnuDIP HTTP update server for FastCGI.
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
use gdipfupdt;
use gdipupdt;

# function to run before accept
my $init = sub {
  # initiate DB connection and get configuration data from DB
  getprefs();
};

# run the CGI
gdipfupdt($init, \&gdipupdt);

