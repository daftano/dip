#!/usr/bin/perl
#####################################################
# gdipreld.pl
#
# This script reads the output from the gdipunld.pl
# script and loads the users table.
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
usage: gdipreld.pl [ -h | [ -i infile ] ]
usage: Loads the users table from a flat file.
usage: -h: Print this usage message.
usage: -i: Specify file to read from.
EOQ
}
use vars qw( $opt_h $opt_i );
if (!getopts('hi:')) {
  usage();
  exit 1;
}
if (@ARGV gt 0) {
  usage();
  exit 1;
}
if ($opt_h) {
  usage();
  exit;
}

# redirect input?
if ($opt_i) {
  close(STDIN);
  open(STDIN, "<$opt_i");
}

# get preferences from config file
$conf = getconf();

# read the file
my $users = 0;
my %userhash = ();
my $uinfo = \%userhash;
while (my $line = <STDIN>) {
  chomp($line);
  if (! $line) {
    if (loaduser($uinfo)) {
      $users++;
    } else {
      print
        "user $$uinfo{'username'}.$$uinfo{'domain'} already exists\n";
    }
    %userhash = ();
  } else {
    if ($line =~ /^\s*(\w[-\w|\.]*)\s*=\s*(.*?)\s*$/) {
      $$uinfo{$1} = $2;
    }
  }
}

# final message
writelog("$users users loaded");

exit;

