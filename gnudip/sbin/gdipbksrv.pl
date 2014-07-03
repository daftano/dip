#!/usr/bin/perl
#####################################################
# gdipbksrv.pl
#
# This script starts the GnuDIP backend server.
#
# The backend server receives notifications that an
# update has has occured for the specified backend.
#
# It runs the reload script if it is not too soon.
# Otherwise it waits the necessary period of time.
#
# See COPYING for licensing information.
#
#####################################################

# PERL modules at compile time
use strict;
use Getopt::Std;
use POSIX qw(setsid);

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
usage: gdipbksrv.pl [ -h | [ -d ] backend ]
usage: GnuDIP backend server.
usage: Receive notififications that updates to the backend have occured,
usage: and initiate reloads. The 'backend' argument is used for look
usage: ups in backend.conf.
usage: -h: Print this usage message.
usage: -d: Debug - stay attached to current terminal.
EOQ
}
use vars qw( $opt_h $opt_d );
if (!getopts('hd')) {
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
die "gdipbksrv.pl has exited - getconf returned nothing\n" if !$conf;

# logger command
my $logger = $$conf{'logger'} ||
  die
  "gdipbksrv.pl has exited - no logger command specified in backend.conf\n";

# FIFO to read from
my $fifo = $$conf{"fifo.$backend"} ||
  die
  "gdipbksrv.pl has exited - no FIFO specified in backend.conf for back end $backend\n";

# reload script to call
my $script = $$conf{"reload.$backend"} ||
  die
  "gdipbksrv.pl has exited - no reload script specified in backend.conf for back end $backend\n";

# required wait between reloads
my $wait = $$conf{"wait.$backend"};
$wait = 0 if !$wait;

# daemonize?
if (! $opt_d) {
  # see "man perlipc"
  chdir '/'  or die "Can't chdir to /: $!";
  open STDIN, '/dev/null'
    or die "Can't read /dev/null: $!";
  open STDOUT, '>/dev/null'
    or die "Can't write to /dev/null: $!";
  defined(my $pid = fork())
    or die "Can't fork: $!";
  if ($pid) {
    # parent
    print STDERR "GnuDIP back end server started for back end $backend\n";
    exit;
  }
  # child (daemon)
  setsid()
    or die "Can't start a new session: $!";
  open STDERR, '>&STDOUT'
    or die "Can't dup stdout: $!";
} else {
  print STDERR "Running in foreground with debug messages\n";
}

# daemon is up
writelog("GnuDIP back end server started for back end $backend");

# pretend the last update was at time 0
my $lasttime = 0;

# avoid zombie children
$SIG{CHLD} = 'IGNORE';

# wait for a signal
my $ok = open(FIFO, "<$fifo");
while ($ok) {

  # drain and close again ASAP
  my $line;
  read(FIFO, $line, 5000);
  # a race here? can lose notification?
  close FIFO;

  my $timenow = time;
  my $remaining = $lasttime + $wait - $timenow;

  # too soon?
  if ($remaining > 0) {
    if ($opt_d) {
      print STDERR "notification received on $fifo - too soon\n";
    }
    # wait on FIFO with a timeout
    $ok = 1;
    eval {
      local $SIG{ALRM} = sub { die "alarm\n"; };
      alarm $remaining;
      $ok = open(FIFO, "<$fifo");
    }

  # otherwise spawn reload
  } else {
    if ($opt_d) {
      print STDERR "notification received on $fifo - spawning $script\n";
    }
    $lasttime = $timenow;
    spawn_reload();
    $ok = open(FIFO, "<$fifo");
  }
}
# should never get here

# open failed?
error_exit("Could not open FIFO $fifo for back end $backend") if !$ok;

exit;

#####################################################
# subroutines
#####################################################

# spawn the reload script
sub spawn_reload {
  writelog("Invoking reload command for backend $backend");
  my $pid = fork();
  error_exit('fork failed') if ! defined $pid;
  return if $pid ne 0;  # parent
  # child
  callcommand('', \&writelog, $script) or
    writelog("Reload script $script failed");
  exit;
}

# display error and exit
sub error_exit {
  my $msg = shift;
  writelog("gdipbksrv.pl: $msg");
  exit 1;
}

# write to log
sub writelog {
  my $msg = shift;
  if (! calllogger($logger, $msg)) {
    print STDERR "calllogger failed\n";
  }
  if ($opt_d) {
    print STDERR "$msg\n";
  }
}

