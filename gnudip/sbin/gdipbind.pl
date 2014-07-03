#!/usr/bin/perl
#####################################################
# gdipbind.pl
#
# This script scans the database and creates the
# BIND zone file input.
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
use dbusers;
use gdiplinemode;

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: gdipbind.pl [ -h | [ [-o | -a] outfile ] domain ]
usage: Scans the database and generates BIND zone file input.
usage: -h: Print this usage message.
usage: -o: Specify file to write output to.
usage: -a: Specify file to append output to.
EOQ
}
use vars qw( $opt_h $opt_o $opt_a);
if (!getopts('ho:a:')) {
  usage();
  exit 1;
}
if (@ARGV ne 1) {
  usage();
  exit 1;
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
my $domain = shift;

# get preferences from config file
$conf = getconf();

# scan users
my $sth = getusersdomain($domain);
my $recs = 0;
my $users = 0;
while (my $uinfo = getuserseach($sth)) {

  my $TTL = 0;
  $TTL = $$conf{'TTL'} if $$conf{'TTL'};
  $TTL = $$conf{"TTL.$domain"}
      if $$conf{"TTL.$domain"};
  $TTL = $$conf{"TTL.$$uinfo{'username'}.$domain"}
      if $$conf{"TTL.$$uinfo{'username'}.$domain"};

  my $marker = '';

  if ($$uinfo{'currentip'} ne '0.0.0.0') {
    print "$$uinfo{'username'}.$domain. $TTL A $$uinfo{'currentip'}\n";
    $recs++;
    $marker = 1;
  }

  if ($$uinfo{'MXvalue'}) {
    print "$$uinfo{'username'}.$domain. $TTL MX 200 $$uinfo{'MXvalue'}\n";
    $recs++;
    $marker = 1;
  }

  if ($$uinfo{'MXbackup'} eq 'YES') {
    print "$$uinfo{'username'}.$domain. $TTL MX 100 $$uinfo{'username'}.$domain.\n";
    $recs++;
    $marker = 1;
  }

  if ($$uinfo{'wildcard'} eq 'YES') {
    print "*.$$uinfo{'username'}.$domain. $TTL CNAME $$uinfo{'username'}.$domain.\n";
    $recs++;
    $marker = 1;
  }

  if ($marker) {
    $users++;
  }
}

# final message
writelog("$recs zone records written for $users users");

exit;

