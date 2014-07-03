#!/usr/bin/perl
#####################################################
# gdipunld.pl
#
# This script scans the users table and dumps it to
# a flat file.
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
usage: gdipunld.pl [ -h | [ [-o | -a] outfile ] ]
usage: Dumps the users table to a flat file.
usage: -h: Print this usage message.
usage: -o: Specify file to write output to.
usage: -a: Specify file to append output to.
EOQ
}
use vars qw( $opt_h $opt_o $opt_a);
if (!getopts('ho:a:')) {
  usage();
  exit 2;
}
if (@ARGV gt 0) {
  usage();
  exit 2;
}
if ($opt_h) {
  usage();
  exit;
}

# redirect output?
if ($opt_o) {
  close(STDOUT);
  open(STDOUT, ">$opt_o");
}
if ($opt_a) {
  close(STDOUT);
  open(STDOUT, ">>$opt_a");
}

# get preferences from config file
$conf = getconf();

# scan users
my $sth = getusers();
my $users = 0;
while (my $uinfo = getuserseach($sth)) {
  $users++;
  while (my ($param, $value) = each %$uinfo) {
    $value = '' if ! defined $value;
    print "$param = $value\n"
      if $param ne 'createdate' and
         $param ne 'id';
  }
  print "\n";
}

# final message
writelog("$users users found");

exit;

