#######################################################################
# gdipfrun.pm
#
# This routine is a common FastCGI template.
#
# It starts two looping acceptor threads initially, and starts another
# acceptor whenever all acceptors have a connection. These acceptors
# remain running forever.
#
# See COPYING for licensing information.
#
#######################################################################

# Perl modules
use strict;
use FCGI;
use POSIX;

# global variables
use vars qw($cgi_exit $conf $bad_config); 

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

  # number of threads running
  # - this many will be started initially
  my $pcnt = 2;

  # force persistence
  $$conf{'persistance'} = 'YES';

  # create a pipe to receive notifications
  pipe(NTFYREAD, NTFYWRITE);

  # flush before forks
  select(NTFYWRITE);
  $| = 1;
  select(STDERR);
  $| = 1;
  select(STDOUT);
  $| = 1;

  # count of current connections
  my $ccnt = 0;

  # start threads
  for (my $idx = 0; $idx < $pcnt; $idx++) {
    fork_thread($initfunc, $acptfunc);
  }

  # keep track of notifications
  while (my $ntfy = <NTFYREAD>) {
    $ntfy = '' if ! defined $ntfy;
    chomp($ntfy);
    if ($ntfy eq '-') {
      # an acceptor has become available
      $ccnt--;
      next;
    }
    if ($ntfy eq '+') {
      # an acceptor has become unavailable
      $ccnt++;
      if ($ccnt ge $pcnt)) {
        # all acceptors are in use
        fork_thread($initfunc, $acptfunc);
        $pcnt++;
        print STDERR "GnuDIP FastCGI has increased number of threads to $pcnt\n";
      }
      next;
    }
    if ($ntfy eq 'x') {
      # an acceptor has shut down
      $pcnt--;
      print STDERR "GnuDIP FastCGI has decreased number of threads to $pcnt\n";
      next if $pcnt gt 0;
    }
    last;
  }

  # all threads shut down?
  return if $pcnt eq 0;

  # should never get here

  # wait for all children to stop
  while (wait() gt 0) {};

  # should never get here
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

  # accept connections
  my $rtc;
  while (($rtc = $req->Accept()) eq 0) {

    # notify parent
    print NTFYWRITE "+\n";

    # override for "exit"
    $cgi_exit = sub {
      # next connection
      goto ENDLOOP;
    };

    # run the CGI
    &$acptfunc();

  ENDLOOP:
    undef $cgi_exit;

    $req->Finish();

    # notify parent
    print NTFYWRITE "-\n";
  }

  # shut down request?
  if ($rtc eq -1) {
    print NTFYWRITE "x\n";
    return;
  }

  FINISH:
    undef $bad_config;

  # should never get here
  print NTFYWRITE "!\n";
  print STDERR "GnuDIP FastCGI thread has ended unexpectedly\n";
}

#####################################################
# must return 1
#####################################################
1;

