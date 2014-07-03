#!/usr/bin/perl
#####################################################
# gdiprmaint.pl
#
# This is the GnuDIP remote user maintenance (X)INETD
# server daemon.
#
# See COPYING for licensing information.
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
use gdipmaint;

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: gdiprmaint.pl [ -h | -e STDERR_file ]
usage: GnuDIP Remote User Maintenance (X)INETD Daemon.
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
  print STDERR "gdiprmaint.pl has exited - getconf returned nothing\n";
  exit;
}

# logger command
$logger = $$conf{'logger_rmaint'};
if (!$logger) {
  print STDERR "Configuration parameter \"logger_rmaint\" not defined";
  exit;
}

# suppress error messages?
if (!$opt_e) {
  open (STDERR, ">/dev/null");
}

# seconds to wait for response to prompt
my $timeout = $$conf{'timeout_rmaint'};
if (!$timeout) {
  writelog(
    "Configuration parameter \"timeout_rmaint\" not defined"
  );
  exit;
}

# rmaint password
my $password = $$conf{'password_rmaint'};
if (!$password) {
  writelog(
    "Configuration parameter \"password_rmaint\" not defined"
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
  writelog("Timed out receiving session data");
  print STDOUT "2\n";
  exit;
}

# get the message type
my $line = '';
chomp($line = <STDIN>);
if ($line eq '') {
  writelog("Empty response");
  print STDOUT "2\n";
  exit;
}

# these two routines do not return
if ($line eq '0') {
  do_clear();
} elsif ($line eq '1') {
  do_blowfish();
}

writelog("Invalid message type");
print STDOUT "2\n";
exit;

#####################################################
# Blowfish format
# - not implemented yet
#####################################################

sub do_blowfish {
  writelog("Blowfish message type requested");
  print STDOUT "2\n";
  exit;
}

#####################################################
# clear text format
#####################################################
sub do_clear {

  # get the hashed password
  my $line = '';
  chomp($line = <STDIN>);
  if ($line eq '') {
    writelog("Hashed password not sent");
    print STDOUT "2\n";
    exit;
  }

  # bad login?
  if ($line ne md5_hex("$password.$salt")) {
    writelog("Invalid hashed password");
    print STDOUT "2\n";
    exit;
  }

  # collect remaining lines of request
  my @request;
  while ($line = <STDIN>) {
    chomp($line);
    if (!$line) {
      writelog("Request ended before \"end\"");
      print STDOUT "2\n";
      exit;
    }
    last if ($line eq 'end');
    push @request, ($line);
  }

  # process request and send response
  my $response = '';
  print STDOUT do_request(\@request, \$response) . "\n";
  print STDOUT $response . "end\n" if $response;

  exit;
}

#####################################################
# process maintenance request
#####################################################
sub do_request() {
  my $request  = shift;
  my $response = shift;

  # check request type
  my $reqt = shift @$request;
  if ($reqt ne 'get' and $reqt ne 'add' and
      $reqt ne 'mod' and $reqt ne 'del') {
    writelog("Invalid request type");
    print STDOUT "2\n";
    exit;
  }

  # hash reference for gdipmaint routine
  my %mainthash;
  my $maintinfo = \%mainthash;
  while (my $line = shift @$request) {
    if ($line =~ /^(.*?)\#(.*)$/) {
      $line = $1;
    }    
    if ($line =~ /^\s*(\w[-\w|\.]*)\s*=\s*(.*?)\s*$/) {
      if ($$maintinfo{$1}) {
        # same parameter again
        writelog("Duplicate request parameter");
        print STDOUT "2\n";
        exit;
      }
      $$maintinfo{$1} = $2;
    }
  }

  # do it
  return maintadd($maintinfo) if $reqt eq 'add';
  return maintdel($maintinfo) if $reqt eq 'del';
  return maintmod($maintinfo) if $reqt eq 'mod';
  return maintget($maintinfo, $response);
}

