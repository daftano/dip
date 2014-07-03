#!/usr/bin/perl

# This scripts checks whether the interface to the internet is up,
# and exits with a non-zero status if not.

# You can use it in a timed shell script to restart your network
# interface if it drops.

# This script takes an optional argument - the depth into the network
# to your ISP's router. This defaults to one.

# If a router is found at the specified depth, this script will exit
# with a code of zero and report success to standard error. Uncomment
# the line at the bottom to also write the address of the router to
# standard output.

# Otherwise it will exit with a code of one and report an error to
# standard error.

# This script uses the traceroute command available from:

#   http://ee.lbl.gov/

# The one that comes with your UNIX system will probably also work -
# with fewer arguments (see below).

# It uses either a reserved address or private address as the destination
# so that the routers will route packets to their default gateway, or drop
# them. Packets will go no further than your ISP's routers. The objective
# is to have minimal impact.

# location of traceroute binary 
my $traceroute = '/usr/local/traceroute/sbin/traceroute';
#my $traceroute = '/usr/bin/traceroute';

# set address
my $address;
# sample reserved addresses
# - see http://www.iana.org/assignments/ipv4-address-space
$address = '197.0.0.1';
#$address = '219.0.0.1';
#$address = '220.0.0.1';
#$address = '221.0.0.1';
#$address = '222.0.0.1';
#$address = '223.0.0.1';
# sample private addresses
# - see http://ietf.org/rfc/rfc1918.txt
#$address = '172.16.1.1';
#$address = '10.1.1.1';
#$address = '192.168.1.1';

# Perl modules
use strict;

# distance to router
my $depth = shift;
$depth = 1 if ! defined $depth;

# traceroute exists?
if (! -x $traceroute) {
  print STDERR "could not execute traceroute binary $traceroute\n";
  exit 2;
}

# number of hops for traceroute
my $hops = $depth;
$hops = 2 if $hops < 2;

# run traceroute
my $cmd = "$traceroute -I -n -q 1 -w 3 -m $hops $address 2> /dev/null";
#my $cmd = "$traceroute -n -m $hops $address 2> /dev/null";
#print STDERR $cmd . "\n";
my $output = `$cmd`;
my $status = $? >> 8;
#print STDERR $output;

# executed OK?
if ($status ne 0) {
  print STDERR
    "invalid status code: $status\n" .
    "command: $cmd\n";
  exit 2;
}

# split output into lines
my @lines = split(/\n/, $output);
#foreach my $line (@lines) {
#  print STDERR $line . "\n";
#}

# got line at routers depth?
my $line = $lines[$depth - 1];
if (! defined $line) {
  print STDERR "router not found at depth $depth - too deep\n";
  print STDERR $output;
  exit 1;
}
#print STDERR $line . "\n";

# split line into tokens
$line =~ s/^\s+//;
my ($hopnum, $hopaddr) = split(/\s+/, $line);
#print STDERR "hopnum = $hopnum\n";
#print STDERR "hopaddr = $hopaddr\n";
if (! defined $hopnum or ! defined $hopaddr) {
  print STDERR
    "invalid response from traceroute\nhop number and addess not found\n";
  print STDERR $output;
  exit 2;
}

# depth matches?
if ($hopnum ne $depth) {
  print STDERR "invalid response from traceroute\nincorrect hop number\n";
  print STDERR $output;
  exit 2;
}

# timed out?
if ($hopaddr eq '*') {
  print STDERR "router not found at depth $depth - timed out\n";
  print STDERR $output;
  exit 1;
}

# report address
print STDERR "router address $hopaddr found at depth $depth\n";
#print STDOUT $hopaddr;

