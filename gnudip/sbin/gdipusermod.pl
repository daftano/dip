#!/usr/bin/perl
#####################################################
# gdipusermod.pl
#
# This script modifies a user in the GnuDIP database.
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
usage: gdipusermod.pl { -h | \
usage:   [-m email] [-p password] [-x rawpassword] \
usage:   [-w {YES|NO}] [-y {YES|NO}] [-r] \
usage:    user domain }
usage: Modify GnuDIP user \"user\" within domain \"domain\".
usage: -h: Print this usage message.
usage: -m: Specify E-mail address.
usage: -p: Specify clear text password. The stored password will
usage:     the MD5 hash of this value.
usage: -x: Specify the hashed password. This will be stored as
usage:     password hash value without any change.
usage: -w: Allow ("YES") or disallow ("NO") wild cards.
usage: -y: Allow ("YES") or disallow ("NO") MX records.
usage: -r: Remove all DNS information.
EOQ
}
use vars qw/ $opt_h $opt_m $opt_p $opt_x $opt_w $opt_y  $opt_r/;
if (!getopts('hrm:p:x:w:y:')) {
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
$$maintinfo{'username'}  = $ARGV[0];
$$maintinfo{'domain'}    = $ARGV[1];
$$maintinfo{'password'}  = $opt_p;
$$maintinfo{'hashedpw'}  = $opt_x;
$$maintinfo{'email'}     = $opt_m;
$$maintinfo{'allowwild'} = $opt_w;
$$maintinfo{'allowmx'}   = $opt_y;
$$maintinfo{'removedns'} = 'YES' if $opt_r;

# get preferences from config file
$conf = getconf();

# do it
exit maintmod($maintinfo);

