#!/usr/bin/perl
#####################################################
# gdipdlet.pl
#
# This script scans the database and creates
# the nsupdate input needed to delete the domain
# name for users not updated within a specified
# number of days. Optionally, it also deletes
# the user from the database.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
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
use gdiplib;
use gdiplinemode;
use dbusers;

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: gdipdlet.pl [ -h | [ -d ] [ -o outfile ] ] days
usage: Generates the nsupdate input needed to delete zone records
usage: not updated within \"days\" days. Optionally, it also
usage: deletes the user from the database.
usage: -h: Print this usage message.
usage: -d: Delete users from the database.
usage: -o: Specify file to write output to.
EOQ
}
use vars qw/ $opt_h $opt_o $opt_d /;
if (!getopts('ho:d')) {
  usage();
  exit 1;
}
if ($opt_h) {
  usage();
  exit;
}
if (@ARGV ne 1) {
  usage();
  exit 1;
}
my $days = shift;

# redirect output?
if ($opt_o) {
  close(STDOUT);
  open(STDOUT, ">$opt_o");
}

# get preferences from config file
$conf = getconf();

# scan users
my $users = 0;
my $sth = getusersolder($days);
while (my $uinfo = getuserseach($sth)) {
  if ($$uinfo{'domain'}) {
    $users++;
    print "update delete   $$uinfo{'username'}.$$uinfo{'domain'}.\n";
    print "update delete *.$$uinfo{'username'}.$$uinfo{'domain'}.\n";
    print "\n";
    deleteuser($uinfo) if $opt_d;
  }
}

# final message
my $msg = "nsupdate records written for $users users";
if ($opt_o) {
  $msg .= " to $opt_o";
}
writelog($msg);

exit;

