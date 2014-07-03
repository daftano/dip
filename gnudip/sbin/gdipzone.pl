#!/usr/bin/perl
#####################################################
# gdipzone.pl
#
# This script scans the database and creates
# the nsupdate input needed to recreate the
# zone records.
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
usage: gdipzone.pl [ -h | [ -o outfile ] [domain] ]
usage: Scans the database and generates nsupdate input to create zone
usage: records. Scans for all domains unless "domain" is specified.
usage: -h: Print this usage message.
usage: -o: Specify file to write output to.
EOQ
}
use vars qw/$opt_h $opt_o/;
if (!getopts('ho:')) {
  usage();
  exit 1;
}
if (@ARGV gt 1) {
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

# domain specified?
my $domain = '';
if (@ARGV eq 1) {
  $domain = shift;
}

# get preferences from config file
$conf = getconf();

# scan users
my $sth;
if ($domain) {
  $sth = getusersdomain($domain);
} else {
  $sth = getusers();
}
my $recs = 0;
my $users = 0;
while (my $uinfo = getuserseach($sth)) {

  if ($$uinfo{'domain'}) {

    my $TTL = 0;
    $TTL = $$conf{'TTL'} if $$conf{'TTL'};
    $TTL = $$conf{"TTL.$$uinfo{'domain'}"}
        if $$conf{"TTL.$$uinfo{'domain'}"};
    $TTL = $$conf{"TTL.$$uinfo{'username'}.$$uinfo{'domain'}"}
        if $$conf{"TTL.$$uinfo{'username'}.$$uinfo{'domain'}"};

    my $marker = '';

    if ($$uinfo{'currentip'} ne '0.0.0.0') {
      print "update add $$uinfo{'username'}.$$uinfo{'domain'}. $TTL A $$uinfo{'currentip'}\n";
      $recs++;
      $marker = 1;
    }

    if ($$uinfo{'MXvalue'}) {
      print "update add $$uinfo{'username'}.$$uinfo{'domain'}. $TTL MX 200 $$uinfo{'MXvalue'}\n";
      $recs++;
      $marker = 1;
    }

    if ($$uinfo{'MXbackup'} eq 'YES') {
      print "update add $$uinfo{'username'}.$$uinfo{'domain'}. $TTL MX 100 $$uinfo{'username'}.$$uinfo{'domain'}.\n";
      $recs++;
      $marker = 1;
    }

    if ($$uinfo{'wildcard'} eq 'YES') {
      print "update add *.$$uinfo{'username'}.$$uinfo{'domain'}. $TTL CNAME $$uinfo{'username'}.$$uinfo{'domain'}.\n";
      $recs++;
      $marker = 1;
    }

    if ($marker) {
      print "\n";
      $users++;
    }
  }
}

# final message
writelog("$recs nsupdate records written for $users users");

exit;

