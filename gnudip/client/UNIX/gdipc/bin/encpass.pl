#!/usr/bin/perl
#####################################################
# encpass.pl
#
# This script takes a plain text password
# provided as an argument, encrypts it and
# prints it.
#
# See COPYING for licensing information
#
#####################################################

# PERL packages and options
use strict;
use FindBin;

# try for compiled MD5, otherwise use pure Perl
BEGIN {
  eval {
    require Digest::MD5;
    import Digest::MD5 'md5_hex'
  };
  if ($@) { # ups, no Digest::MD5
    # get path to our parent directory
    my $binpath = $FindBin::Bin;
    my $gnudipdir = '';
    if ($binpath =~ /(.*)\/.+?/) {
      $gnudipdir = $1;
    }
    require $gnudipdir . '/lib/Digest/Perl/MD5.pm';
    import Digest::Perl::MD5 'md5_hex'
  }             
}

# get program name
my $pgm = $0;
if ($pgm =~ /^.*\/(.+?)$/) {
  $pgm = $1;
}

sub usage {
  print STDOUT "usage: $pgm password\n";
  print STDERR "usage: Encrypt a plain text password.\n";
  exit;
}
if (@ARGV ne 1) {
  usage();
}

my $plainpass = shift;
my $encpass = md5_hex($plainpass);
print "$encpass\n";

