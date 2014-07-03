#!/usr/bin/perl
#####################################################
# gdipinet.pl
#
# This is the GnuDIP (X)INETD server daemon.
#
# See COPYING for licensing information.
#
# Derived from GnuDIP 2.1.2 written by:
#
#   Mike Machado
#
#####################################################

# PERL modules
use strict;
use Getopt::Std;
use POSIX qw(strftime);
use Socket;

# global variables
use vars qw($conf $gnudipdir $logger $ip);

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
use gdipdaemon;
use gdiplib;
use dbusers;

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: gdipinet.pl [ -h | -e STDERR_file ]
usage: GnuDIP (X)INETD Daemon.
usage: -h: Print this usage message.
usage: -e: Specify filename prefix for STDERR output. The file name
usage:     will be this prefix followed by the process ID.
EOQ
}
use vars qw/ $opt_h $opt_e /;
if (!getopts('he:')) {
  usage();
  exit 1;
}
if ($opt_h) {
  usage();
  exit;
}
if (@ARGV ne 0) {
  usage();
  exit 1;
}

# redirect error messages?
if ($opt_e) {
  # trust the prefix
  if ($opt_e =~ /^(.*)$/) {
    $opt_e = $1;
  }
  open (STDERR, ">$opt_e$$");
}

# get preferences from config file
$conf = getconf();
if (!$conf) {
  print STDERR "gdipinet.pl has exited - getconf returned nothing\n";
  exit;
}

# logger command
$logger = $$conf{'logger_inet'};
if (!$logger) {
  print STDERR "Configuration parameter \"logger_inet\" not defined";
  exit;
}

# suppress error messages?
if (!$opt_e) {
  open (STDERR, ">/dev/null");
}

# seconds to wait for response to prompt
my $timeout = $$conf{'timeout'};
if (!$timeout) {
  writelog(
    "Configuration parameter \"timeout\" not defined"
  );
  exit;
}

# get IP address of remote end
my $client_addr = getpeername(STDIN);
if (! $client_addr) {
  my $msg = 'Could not get IP address of client';
  writelog($msg);
  print STDERR "$msg\n";
  print "$msg\n";
  exit;
}
my ($port, $packed_ip) = sockaddr_in($client_addr);
$ip = inet_ntoa($packed_ip);

# flush after each print
select(STDOUT);
$| = 1;

# send the salt
my $salt = randomsalt();
print STDOUT "$salt\n";

# only wait $timeout seconds for data before disconnecting
my $sin = '';
vec($sin, fileno(STDIN), 1) = 1;
my $found = select($sin, undef, undef, $timeout);

# timed out?
if (!$found) {
  writelog("Timed out receiving session data from $ip");
  print STDOUT "1\n";
  exit;
}

# get the response
my $data = '';
chomp($data = <STDIN>);
my ($clientuser, $clientpass, $clientdomain, $clientaction, $clientip) = split(/:/, $data);

# got a response?
if ($data eq '') {
  writelog("Empty response from $ip");
  print STDOUT "1\n";
  exit;
}

# sensible request?
if($clientaction ne '0' && $clientaction ne '1' && $clientaction ne '2') {
  writelog("Invalid request from $ip");
  print STDOUT "1\n";
  exit;
}

# "dummy" request?
if ($clientaction eq '2' and
    $$conf{'dummyuser'}  and
    $$conf{'dummydomn'}  and
    $$conf{'dummypswd'}) {
  # massage host template into valid Perl regular expression
  my $check = $$conf{'dummyuser'};
  $check =~ s/\*/\(\.\*\)/g;
  $check =~ s/\?/\(\.\)/g;
  # check for a match
  if ($clientuser   =~ /^$check\b/ and 
      $clientdomain eq $$conf{'dummydomn'} and 
      $clientpass   eq md5_hex(md5_hex($$conf{'dummypswd'}) . ".$salt")) {
    writelog(
      "Dummy request processed for user $clientuser from ip $ip");
    print STDOUT "0:$ip\n";
    exit;
  }
}

# retrieve user information
my $userinfo = getuser($clientuser, $clientdomain);

# bad login?
if (!$userinfo                              or
    $clientuser   ne $$userinfo{'username'} or
    $clientdomain ne $$userinfo{'domain'}   or
    $clientpass   ne md5_hex("$$userinfo{'password'}.$salt")
    ) {
  writelog("Invalid login attempt from $ip: user $clientuser.$clientdomain");
  print STDOUT "1\n";
  exit;
}

# use IP address client connected from?
$clientip = $ip if $clientaction eq '2';

# client passed an IP address?
if ($clientaction eq '0' and (!defined($clientip) or $clientip eq '')) {
  writelog("No IP address passed from $ip: user $clientuser.$clientdomain");
  $clientip = $ip;
  if (defined $$conf{'require_address'} and
              $$conf{'require_address'} = 'yes') {
    print STDOUT "1\n";
    exit;
  }
}

# invalid IP address?
if($clientaction ne '1' && !validip($clientip)) {
  writelog(
    "Unserviceable IP address $clientip for user $clientuser.$clientdomain");
  print STDOUT "1\n";
  exit;
}

# TTL value
my $TTL = 0;
$TTL = $$conf{'TTL'} if $$conf{'TTL'};
$TTL = $$conf{"TTL.$clientdomain"}
    if $$conf{"TTL.$clientdomain"};
$TTL = $$conf{"TTL.$clientuser.$clientdomain"}
    if $$conf{"TTL.$clientuser.$clientdomain"};

# a modify request?
if ($clientaction eq '0' or $clientaction eq '2') {

  # IP address unchanged?
  if ($$userinfo{'currentip'} eq $clientip) {
    writelog(
      "User $clientuser.$clientdomain remains at ip $clientip");
    updateuser($userinfo);

  # do the update
  } else {
    donsupdate($clientdomain,
      "update delete $clientuser.$clientdomain. A",
      "update add    $clientuser.$clientdomain. $TTL A $clientip");
    writelog(
      "User $clientuser.$clientdomain successful update to ip $clientip");
    $$userinfo{'currentip'} = $clientip;
    updateuser($userinfo);
  }

  if ($clientaction eq '2') {
    print STDOUT "0:$clientip\n";
  } else {
    print STDOUT "0\n";
  }

# an offline request
} else {

  # IP address unchanged?
  if ($$userinfo{'currentip'} eq '0.0.0.0') {
    writelog(
      "User $clientuser.$clientdomain remains removed");
    updateuser($userinfo);

  # do the update
  } else {
    donsupdate($clientdomain,
      "update delete $clientuser.$clientdomain. A");
    writelog(
      "User $clientuser.$clientdomain successful remove from ip $$userinfo{'currentip'}");
    $$userinfo{'currentip'} = '0.0.0.0';
    updateuser($userinfo);
  }

  print STDOUT "2\n";
}

exit;

