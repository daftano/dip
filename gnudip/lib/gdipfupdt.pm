#######################################################################
# gdipfupdt.pm
#
# This file really is the GnuDIP update server FastCGI. The
# gdipupdt.cgi script just executes the gdipfupdt subroutine.
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

sub gdipfupdt {

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
  $logger = $$conf{'logger_updt'};
  if (! defined $logger) {
    $logger = $$conf{'logger_cgi'};
  }

  # call common routine
  gdipfrun($initfunc, $acptfunc);
}

#####################################################
# must return 1
#####################################################
1;

