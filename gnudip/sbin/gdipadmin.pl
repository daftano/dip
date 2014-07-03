#!/usr/bin/perl
#####################################################
# gdipadmin.pl
#
# This script adds an admin user to the GnuDIP
# database.
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
use gdiplib;
use dbusers;
use gdiplinemode;

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: gdipadmin.pl [ -h | [ -u ] userid password ]
usage: Add GnuDIP administrative user \"user\" with password \"password\".
usage: -h: Print this usage message.
usage: -u: Update user if it already exists.
EOQ
}
use vars qw/ $opt_h $opt_u /;
if (!getopts('hu')) {
  usage();
  exit 1;
}
if ($opt_h) {
  usage();
  exit;
}
if (@ARGV ne 2) {
  usage();
  exit 1;
}
my $username = $ARGV[0];
my $password = $ARGV[1];

# get preferences from config file
$conf = getconf();

# user exists?
my $userinfo = getuser($username, '');

# user exists
if ($userinfo) {

  # did not say to update
  if (!$opt_u) {
    print STDOUT "User $username already exists - use \"-u\" to update\n";

  # supposed to update
  } else {
    $$userinfo{'password'} = md5_hex($password);
    $$userinfo{'level'}    = 'ADMIN';
    updateuser($userinfo);
    print STDOUT
     "Updated username $username with password $password and set as ADMIN\n";
  }

# user does not exist yet
} else {
  createuser(
    $username,
    '', # domain
    md5_hex($password),
    'ADMIN',
    '' # E-mail
    );
  print STDOUT "Added username $username with password $password and set as ADMIN\n";
}

exit;

