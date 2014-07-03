#!/usr/bin/perl
#####################################################
# gdiptinydns.pl
#
# This script scans the database and creates a data
# file for tinydns. Please make sure that other
# required dns entries are in your final data.cdb. See
# gdiprltiny.sh for a example.
#
# See COPYING for licensing information.
#
# Adapted for use with tinydns by:
#
#   Roel van Meer
#   rolek@lsof.org
#
# Made it work:
#
#   Thilo Bangert
#   thilo.bangert@gmx.net
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
usage: gdiptinydns.pl [ -h | [ [-o | -a] outfile ] [domain] ]
usage: Scans the database and generates tinydns input to create domain
usage: file. Scans for all domains unless "domain" is specified.
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
if ($opt_a) {
  close(STDOUT);
  open(STDOUT, ">>$opt_a");
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
      print "+$$uinfo{'username'}.$$uinfo{'domain'}:$$uinfo{'currentip'}:$TTL\n";
      $recs++;
      $marker = 1;

      if ($$uinfo{'MXbackup'} eq 'YES') {
        # this sets the first mx
        print "\@$$uinfo{'username'}.$$uinfo{'domain'}:$$uinfo{'currentip'}:a:100:$TTL\n";
        $recs++;
      }

      if ($$uinfo{'wildcard'} eq 'YES') {
        print "+*.$$uinfo{'username'}.$$uinfo{'domain'}:$$uinfo{'currentip'}:$TTL\n";
        $recs++;
      }
    }

    if ($$uinfo{'MXvalue'}) {
      # this sets the secondary/backup mx
      print "\@$$uinfo{'username'}.$$uinfo{'domain'}:$$uinfo{'MXvalue'}:b:200:$TTL\n";
      $recs++;
      $marker = 1;
    }

    if ($marker) {
      $users++;
    }
  }
}

# final message
writelog("$recs tinydns records written for $users users");

exit;

