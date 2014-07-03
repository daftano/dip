#!/usr/bin/perl
#####################################################
# gdipbkclt.pl
#
# This is the backend client script.
#
# It notifies the backend server that an update has
# has occured for the specified backend.
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
usage: gdipbkclt.pl [ -h | backend ]
usage: Notify the backend server that that an
usage: update to the backend has occured. The 'backend'
usage: argument is used for look ups in backend.conf.
usage: -h: Print this usage message.
EOQ
}
use vars qw/ $opt_h /;
if (!getopts('h')) {
  usage();
  exit 1;
}
if ($opt_h) {
  usage();
  exit;
}
if (@ARGV ne 1) {
  usage();
  exit 1;
}
my $backend = $ARGV[0];

# get preferences from config file
$conf = getconf("$gnudipdir/etc/backend.conf");

# FIFO to write to
my $fifo = $$conf{"fifo.$backend"};
if (! $fifo) {
  print STDERR "No FIFO file specified for $backend in backend.conf\n";
  exit 1;
}

# open the FIFO, with 5 second timeout
my $open;
eval {
  local $SIG{ALRM} = sub { die; };
  alarm 5;
  $open = open(FIFO, ">$fifo");
 };

# opened?
if (! $open) {
  print STDERR "Could not open FIFO file $fifo\n";
  exit 1;
}

# write backend name to it
print FIFO "$backend\n";

close FIFO;

