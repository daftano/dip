#######################################################################
# gdipfrun.pm
#
# This routine is a common FastCGI template.
#
# It runs a single looping acceptor thread.
#
# See COPYING for licensing information.
#
#######################################################################

# Perl modules
use strict;
use FCGI;

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

  # force persistence
  $$conf{'persistance'} = 'YES';

  # create request
  my $req = FCGI::Request();
  if (! $req->IsFastCGI()) {
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
  while ($req->Accept() eq 0) {

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
  }

  FINISH:
    undef $bad_config;

  # should never get here

  print STDERR "GnuDIP FastCGI has ended unexpectedly\n";
}

#####################################################
# must return 1
#####################################################
1;

