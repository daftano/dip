#######################################################################
# gdipfcgi.pm
#
# This file really is the GnuDIP FastCGI. The gnudip.cgi script just
# executes the gdipfcgi subroutine.
#
# See COPYING for licensing information.
#
#######################################################################

# Perl modules
use strict;
use FCGI;
use POSIX;

# global variables
use vars qw($conf $logger); 

# GnuDIP modules
use gdiplib;
use gdipfrun;

sub gdipfcgi {

  # functions to run in thread
  my $initfunc = shift;
  my $acptfunc = shift;

  # get preferences from config file
  $conf = getconf();
  if (! $conf) {
    print STDERR "GnuDIP FastCGI has exited - getconf returned nothing\n";
    exit 1;
  }

  # logger command
  $logger = $$conf{'logger_cgi'};

  # call common routine
  gdipfrun($initfunc, $acptfunc);
}

#####################################################
# must return 1
#####################################################
1;

