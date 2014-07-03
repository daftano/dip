#!/usr/bin/perl
#####################################################
# gdiprmclt.pl
#
# This script is used to test the remote maintenance
# daemon (gdiprmaint.pl).
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

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: gdiprmclt.pl [ -h ] host port 
usage: Test remote maintenance daemon.
usage: Request is read from standard input with final line containing
usage: just "end".
usage: -h: Print this usage message.
EOQ
}
use vars qw/ $opt_h /;
if (!getopts('h')) {
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
my $serverhost = $ARGV[0];
my $serverport = $ARGV[1];

# get preferences from config file
$conf = getconf("$gnudipdir/etc/gdiprmclt.conf");
if (!$conf) {
  print STDERR "Exiting - getconf returned nothing\n";
  exit 2;
}

# rmaint password defined?
my $password = $$conf{"rmaint_password.$serverhost"};
if (!$password) {
  print STDERR
    "Configuration parameter \"rmaint_password.$serverhost\" not defined\n";
  exit 2;
}

# look up host
my $inet_addr = gethostbyname($serverhost);
if (!$inet_addr) {
  print STDERR "Could not do DNS lookup for $serverhost\n";
  exit 2;
}
my $paddr = sockaddr_in($serverport, $inet_addr);

# connect to server
socket(SERVER, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
if (!connect(SERVER, $paddr)) {
  print STDERR "Could not connect to $serverhost:$serverport\n";
  exit 2;
}

# set autoflush on
select(SERVER);
$| = 1;
select(STDOUT);

# retrieve the salt
my $salt = <SERVER>;
$salt = '' if ! defined $salt;
chomp($salt);

# got a salt?
if (!$salt) {
  print STDERR "Server did not send salt\n";
  close SERVER;
  exit 2;
}

# salt and digest password
$password = md5_hex("$password.$salt");

# test clear text messages
print SERVER "0\n";

# send hashed password
print SERVER "$password\n";

# read and send lines of request
print STDERR "Enter request - terminate with \"end\"\n";
while (my $line = <STDIN>) {
  chomp($line);
  print SERVER "$line\n";
  last if ($line eq 'end');
}

# get response
print STDERR "\nResponse ...\n";
while (my $line = <SERVER>) {
  chomp($line);
  print STDOUT "$line\n";
}

close SERVER;

