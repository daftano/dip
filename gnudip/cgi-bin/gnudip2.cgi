#!/usr/bin/perl
#####################################################
# gnudip2.cgi
#
# This is a stub to redirect to the GnuDIP Web
# Tool.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;

# redirect
my $redir = 'http://' . $ENV{'HTTP_HOST'} .
            '/gnudip/cgi-bin/gnudip.cgi';
if ($ENV{'QUERY_STRING'} ne '') {
  $redir .= '?' . $ENV{'QUERY_STRING'};
}
print STDOUT "Location: $redir\n\n";

