#####################################################
# gdiplinemode.pm
#
# These are GnuDIP common subroutines for use in line
# commands.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;

#####################################################
# write to the "log"
#####################################################
sub writelog {
  my @text;
  foreach my $line (@_) {
    if ($line =~ /\n/) {
      # split on new line
      push @text, (split(/\n/, $line));
    } else {
      push @text, ($line);
    }
  }
  foreach my $line (@text) {
    print STDERR "$line\n";
  }
}

#####################################################
# called for database error
#####################################################
sub dberror {
  exit 2;
}

#####################################################
# call nsupdate and catch errors
#####################################################
sub donsupdate {
  if (! callnsupdate(@_)) {
    writelog("callnsupdate failed");
    exit 2;
  }
}

#####################################################
# must return 1
#####################################################
1;

