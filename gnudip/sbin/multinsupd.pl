#!/usr/bin/perl
#####################################################
# multinsupd.pl
#
# This script can be used as the value for the
# "nsupdate" parameter in gnudip.conf or minidip.conf
# to expand single nsupdate delete and add commands
# for particular domains into multiple commands,
# including the original.
#
# The actual nsupdate command should be passed as the
# arguments to this script. So the name of this script
# just gets inserted in front of the nsupdate command.
#
# It reads the names of domains to be expanded, and
# the list of additional domains to insert, from the
# etc/multinsupd.conf, or from a file name passed as
# an argument.
#
# Note that the aliases must be in zones with the same
# TSIG key as the zone of the domain being expanded,
# since the updates are done in the same execution of
# nsupdate
#
#####################################################

# Perl modules
use strict;
use Getopt::Std;

# global variables
use vars qw($logger);

# locate ourselves
my $gnudipdir;
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

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: multinsupd.pl { -h | [ -c conffile ] nsupdate_command }
usage: Expand nsupdate delete and add commands for special domain
usage: names.  Read configuration from "conffile" if given, otherwise
usage: from multinsupd.conf in GnuDIP "etc".
usage: -h: Print this usage message.
EOQ
}
use vars qw/ $opt_h $opt_c /;
if (!getopts('hlc:')) {
  usage();
  exit 1;
}
if ($opt_h) {
  usage();
  exit;
}
if (@ARGV eq 0) {
  usage();
  exit 1;
}

# the real nsupdate command
my $nsupdate = join(' ', @ARGV);

# get preferences from config file
$opt_c = "$gnudipdir/etc/multinsupd.conf" if !$opt_c;
my $conf = getconf($opt_c);
if (!$conf) {
  print STDERR "multinsupd.pl has exited - getconf returned nothing\n";
  exit 1;
}

# logger command
$logger = $$conf{'logger'};
if (!$logger) {
  print STDERR "multinsupd.pl has exited - configuration parameter \"logger\" not defined";
  exit 1;
}

# read and process each line
my %expands;
my @lines;
while (<STDIN>) {
  chomp(my $line = $_);
  push @lines, ($line);
  my @token = split(' ', $line);
  next if !defined $token[0] or $token[0] ne 'update';
  my $domain = validdomain($token[2]);
  $domain = substr($domain, 0, -1);
  my $aliases;
  $aliases = $$conf{"alias.$domain."};
  $aliases = $$conf{"alias.$domain"}   if !defined($aliases);
  $aliases = $$conf{"$domain."}        if !defined($aliases);
  $aliases = $$conf{"$domain"}         if !defined($aliases);
  next if !defined($aliases);
  my @domains = split(' ', $aliases);
  if ($token[1] eq 'delete' and $token[3] eq 'A') {
    foreach my $alias (@domains) {
      push @lines, ("update delete $alias A");
    }
    $expands{$domain} = $aliases;
  } elsif ($token[1] eq 'add' and $token[4] eq 'A') {
    my $TTL    = $token[3];
    my $IP     = $token[5];
    foreach my $alias (@domains) {
      push @lines, ("update add    $alias $TTL A $IP");
    }
    $expands{$domain} = $aliases;
  }
}

# show some indication that we did something
foreach my $expand (keys %expands) {
  writelog("Inserted aliases for $expand: $expands{$expand}");
}

# for debugging
#debug_logger("nsupdate: $nsupdate");
#foreach my $line (@lines) {
#  debug_logger("$line");
#}

# call nsupdate
my $retc = callcommand('', \&writelog, $nsupdate, @lines);
exit if $retc;
print STDERR "multinsupd.pl has exited - callcommand failed: $nsupdate\n";
exit 1;

# for debugging
#sub debug_logger {
#  my $line = shift;
#  system('/usr/bin/logger', '-t', 'multinsupd.pl', $line);
#}
