#!/usr/bin/perl
#####################################################
# gdipuserdel.pl
#
# This script deletes a user from the GnuDIP database
# and completely removes its related DNS records.
#
# Return codes:
# 0 - success
# 1 - user does not exist
# 2 - configuration problem
#
# See COPYING for licensing information.
#
#####################################################

# PERL modules
use strict;
use Getopt::Std;

# global variables
use vars qw($conf $gnudipdir);

# locate ourselves
use FindBin;
BEGIN {
  $gnudipdir = '';
  if ($FindBin::Bin =~ /(.*)\/.+?/) {
    $gnudipdir = $1;
  }
}
use lib "$gnudipdir/lib";

# GnuDIP common subroutines
use gdipmaint;
use gdiplinemode;

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: gdipuserdel.pl { -h | user domain }
usage: Delete GnuDIP user \"user\" within domain \"domain\".
usage: -h: Print this usage message.
EOQ
}
use vars qw/ $opt_h /;
if (!getopts('h')) {
  usage();
  exit 2;
}
if ($opt_h) {
  usage();
  exit;
}
if (@ARGV ne 2) {
  usage();
  exit 2;
}

# hash reference for gdipmaint routine
my %mainthash;
my $maintinfo = \%mainthash;
$$maintinfo{'username'} = $ARGV[0];
$$maintinfo{'domain'}   = $ARGV[1];

# get preferences from config file
$conf = getconf();

# do it
exit maintdel($maintinfo);

