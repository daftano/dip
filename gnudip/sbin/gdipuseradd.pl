#!/usr/bin/perl
#####################################################
# gdipuseradd.pl
#
# This script adds a user to the GnuDIP database.
#
# Return codes:
# 0 - success
# 1 - user already exists
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
usage: gdipuseradd.pl { -h | [-p password] [-m email] user domain }
usage: Add GnuDIP user \"user\" within domain \"domain\" with
usage: password \"password\" and (optionally) E-mail address \"email\".
usage: -h: Print this usage message.
usage: -p: Specify clear text password. The stored password will the MD5
usage:     hash of this value. Password is disabled if not specified.
usage: -m: Specify E-mail address.
EOQ
}
use vars qw/ $opt_h $opt_p $opt_m /;
if (!getopts('hp:m:')) {
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
$$maintinfo{'password'} = $opt_p;
$$maintinfo{'email'}    = $opt_m;

# get preferences from config file
$conf = getconf();

# do it
exit maintadd($maintinfo);

