#####################################################
# gdipdaemon.pm
#
# These are GnuDIP common subroutines for use in
# (X)INETD daemon scripts.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;

# global variables
use vars qw($logger $ip);

#####################################################
# write to the "log"
#####################################################
sub writelog {
  my @text;
  my $msgprfx = '';
  $msgprfx = "$ip - " if defined $ip;
  while (my $line = shift @_) {
    if ($line =~ /\n/) {
      # split on new line
      push @text, (split(/\n/, $msgprfx . $line));
    } else {
      push @text, ($msgprfx . $line);
    }
  }
  if (!calllogger($logger, @text)) {
    print STDERR "Exited - calllogger failed\n";
    print STDOUT "Exited - calllogger failed\n";
    exit;
  }
}

#####################################################
# called for database error
#####################################################
sub dberror {
  exit;
}

#####################################################
# call nsupdate and catch errors
#####################################################
# call nsupdate
sub donsupdate {
  if (!callnsupdate(@_)) {
    writelog("Exited - callnsupdate failed");
    exit;
  }
}

#####################################################
# must return 1
#####################################################
1;

