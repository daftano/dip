#!/usr/bin/perl
#####################################################
# gdipdbfix.pl
#
# This script scans the database and modifies
# or deletes users in the user database in order
# to be consistent with the set of domains and
# the administrative settings.
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
use dbprefs;
use dbusers;

# process command line
sub usage {
 print STDERR <<"EOQ";
usage: gdipdbfix.pl [ -h | -s | -u ]
usage: Scans the database and modifies or deletes users in
usage: the user database in order to be consistent with the
usage: set of domains and the administrative settings.
usage: One of the three options must be given.
usage: -h: Print this usage message.
usage: -s: Just scan database and determine count of changes.
usage: -u: Actually update the database.
EOQ
}
use vars qw( $opt_h $opt_s $opt_u );
if (!getopts('hsu')) {
  usage();
  exit 1;
}
if ($opt_h) {
  usage();
  exit;
}
if (! ($opt_s or $opt_u)) {
  usage();
  exit 1;
}

# get preferences from config file
$conf = getconf();

# get preferences from the database
my $pref = getprefs();

# scan users
my $autousers = 0;
my $wildusers = 0;
my $mxusers   = 0;
my $domusers  = 0;
my $sth = getusers();
while (my $uinfo = getuserseach($sth)) {

  my $doupdate = '';

  # fix any auto URL issues
  if ($$pref{'ALLOW_AUTO_URL'} eq 'NO' and
      ( $$uinfo{'autourlon'}   ne '' or
        $$uinfo{'forwardurl'}  ne '')) {
    $$uinfo{'autourlon'}  = '';
    $$uinfo{'forwardurl'} = '';
    $autousers++;
    $doupdate = 1;
  }

  # fix any wild card issues
  if ($$pref{'ALLOW_WILD'} eq 'NO' and
      ($$uinfo{'wildcard'}  ne 'NO' or
       $$uinfo{'allowwild'} ne 'NO')) {
    $$uinfo{'wildcard'}  = 'NO';
    $$uinfo{'allowwild'} = 'NO';
    $wildusers++;
    $doupdate = 1;
  } elsif ($$pref{'ALLOW_WILD'} eq 'USER' and
           $$uinfo{'allowwild'} ne 'YES'  and
           $$uinfo{'wildcard'}  ne 'NO') {
    $$uinfo{'wildcard'} = 'NO';
    $wildusers++;
    $doupdate = 1;
  }

  # fix any MX issues
  if ($$pref{'ALLOW_MX'} eq 'NO' and
      ($$uinfo{'MXvalue'}          or
       $$uinfo{'MXbackup'} ne 'NO' or
       $$uinfo{'allowmx'}  ne 'NO')) {
    $$uinfo{'MXvalue'}   = '';
    $$uinfo{'MXbackup'}  = 'NO';
    $$uinfo{'allowwild'} = 'NO';
    $mxusers++;
    $doupdate = 1;
  } elsif ($$pref{'ALLOW_MX'} eq 'USER' and
           $$uinfo{'allowmx'} ne 'YES'  and
            ($$uinfo{'MXvalue'}          or
             $$uinfo{'MXbackup'} ne 'NO')) {
    $$uinfo{'MXvalue'}   = '';
    $$uinfo{'MXbackup'}  = 'NO';
    $mxusers++;
    $doupdate = 1;
  }

  # fix any missing domains
  # - must come last since user will be deleted
  if ($$uinfo{'domain'} and
      !getdomain($$uinfo{'domain'})) {
    deleteuser($uinfo) if $opt_u;
    $domusers++;
    $doupdate = '';
  }

  updateuser($uinfo) if $doupdate and $opt_u;
}

writelog("auto URL values reset for $autousers users");
writelog("wildcard values reset for $wildusers users");
writelog("MX values reset for $mxusers users");
writelog("$domusers users deleted for invalid domains");

exit;

