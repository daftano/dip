#######################################################################
# gdipfrun.pm
#
# This routine is a common FastCGI template.
#
# It starts two non-looping acceptor threads initially, and starts a
# replacement acceptor when a current acceptor accepts a connection.
#
# See COPYING for licensing information.
#
#######################################################################

# Perl modules
use strict;
use FCGI;
use POSIX;

# global variables
use vars qw($cgi_exit $conf $logger $bad_config); 

# GnuDIP modules
use gdiplib;

sub gdipfrun {

  # functions to run in thread
  my $initfunc = shift;
  my $acptfunc = shift;
  if (! $initfunc) {
    print STDERR "GnuDIP FastCGI has exited - no initialization function passed\n";
    exit 1;
  }
  if (! $acptfunc) {
    print STDERR "GnuDIP FastCGI has exited - no accept function passed\n";
    exit 1;
  }

  # force persistence
  $$conf{'persistance'} = 'YES';

  # create a pipe to receive notifications
  pipe(NTFYREAD, NTFYWRITE);

  # set flush before forks
  select(NTFYWRITE);
  $| = 1;
  select(STDERR);
  $| = 1;
  select(STDOUT);
  $| = 1;

  # avoid zombie children
  sub REAPER {
    wait();
    $SIG{CHLD} = \&REAPER;
  }
  $SIG{CHLD} = \&REAPER;

  # start two inital acceptors
  # - can start any number
  fork_thread($initfunc, $acptfunc);
  fork_thread($initfunc, $acptfunc);

  # start new acceptor to replace each old one
  my $ntfy;
  while ($ntfy = <NTFYREAD>) {
    $ntfy = '' if ! defined $ntfy;
    chomp($ntfy);
    if ($ntfy eq '+') {
      # start replacement acceptor
      fork_thread($initfunc, $acptfunc);
      next;
    }
    last;
  }

  # thread got shut down request?
  return if $ntfy eq 'x';

  # should never get here

  # wait for all children to stop
  while (wait() gt 0) {};

  print STDERR "GnuDIP FastCGI has ended unexpectedly\n";
}

# subroutine to fork a thread
sub fork_thread {

  # functions to run in thread
  my $initfunc = shift;
  my $acptfunc = shift;

  # spawn child process
  defined(my $pid = fork()) or die "fork failed: $!\n";
  return $pid if $pid gt 0;

  # we are the child
  thread($initfunc, $acptfunc);
  POSIX::_exit(0);
}

# subroutine for each thread
sub thread {

  # functions to run in thread
  my $initfunc = shift;
  my $acptfunc = shift;

  # create request
  my $req = FCGI::Request();
  if (! $req->IsFastCGI()) {
    print NTFYWRITE "!\n";
    print STDERR "GnuDIP FastCGI not called as FastCGI program\n";
    return;
  }

  # configuration error handler for now
  $bad_config = sub {
    # go do Finish
    goto FINISH;
  };

  # run initialization
  &$initfunc();

  # accept connection
  my $rtc = $req->Accept();

  # shut down request?
  if ($rtc eq -1) {
    print NTFYWRITE "x\n";
    return;
  }

  # notify parent
  print NTFYWRITE "+\n";

  # did Accept succeed?
  return if $rtc ne 0;

  # override for "exit"
  $cgi_exit = sub {
    # go do Finish
    goto FINISH;
  };

  # run the CGI
  &$acptfunc();

FINISH:
  undef $bad_config;
  undef $cgi_exit;

  $req->Finish();
}

#####################################################
# must return 1
#####################################################
1;

