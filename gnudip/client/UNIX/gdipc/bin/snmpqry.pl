#!/usr/bin/perl
#####################################################
# snmpqry.pl
#
# This script uses SNMP to query an NAT gateway for
# its external address. The NAT gateway must support
# SNMP and MIB-II.
#
# See COPYING for licensing information
#
#####################################################

# suffix for text files
my $cfgsuff = '';
$cfgsuff = '.txt' if $ENV{'windir'} and $ENV{'comspec'};

# PERL packages and options
use strict;
use Socket;
use Getopt::Std;

# locate ourselves
use vars qw($gnudipdir);
use FindBin;
BEGIN {
  $gnudipdir = '';
  if ($FindBin::Bin =~ /^(.*)\/bin$/) {
    $gnudipdir = $1;
  } else {
    $gnudipdir = $FindBin::Bin;
  }
}
use lib "$gnudipdir/lib";

# modules for SNMP support
use BER;
use SNMP_util;

# get program name
my $pgm = $0;
if ($pgm =~ /^.*\/(.+?)$/) {
  $pgm = $1;
}

# process command line
sub usage {
  print STDOUT <<EOQ;
usage: $pgm { -h | [ -e ] host }
usage: Use SNMP/MIB-2 to determine the "external" IP address of host.
usage: -h: Print this usage message.
usage: -e: Show detailed error messages produced by Perl SNMP routines.
EOQ
  exit;
}
use vars qw($opt_e $opt_h);
if (!getopts('eh')) {
  usage();
}
if ($opt_h) {
  usage();
}
if (@ARGV ne 1) {
  usage();
}
my $host = shift;

# allow warnings from Perl modules?
$SNMP_Session::suppress_warnings = 2 if ! $opt_e;

# generate trace messages?
my $trace = '';
#$trace = 1;

# get default gateway interface number from target host
my ($external_if) = snmpget($host, 'ip.ipRouteTable.ipRouteEntry.ipRouteIfIndex.0.0.0.0');
if (! $external_if) {
  print STDERR "Could not get default gateway interface number from target host\n";
  exit 1;
}
if ($trace) {
  print STDERR "default gateway interface number from $host: $external_if\n";
}

# get address <=> interface number pairs from target host
my @address_ifs = snmpwalk($host, 'ip.ipAddrTable.ipAddrEntry.ipAdEntIfIndex');
if (! $address_ifs[0]) {
  print STDERR "Could not get address <=> interface number pairs from target host\n";
  exit 1;
}
if ($trace) {
  print STDERR "address <=> interface number pairs from $host:\n";
  foreach my $address_if (@address_ifs) {
    print "  $address_if\n";
  }
}

# scan for external interface number
my $external_addr;
foreach my $address_if (@address_ifs) {
  my ($address, $ifnum) = split(/:/, $address_if);
  if ($ifnum == $external_if) {
    $external_addr = $address;
    last;
  }
}
if (! $external_addr) {
  print STDERR "Could not find address for default gateway interface number\n";
  exit 1;
}

# provide external address
print "$external_addr\n";

exit;

