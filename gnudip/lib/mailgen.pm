#######################################################################
# mailgen.pm
#
# These routines generate the GnuDIP E-mail.
#
# See COPYING for licensing information.
#
#######################################################################

# Perl modules
use strict;
use gdipcgi_cmn;

# global variables
use vars qw($pref $thishost $thisurl);
use vars qw($bad_config);

# GnuDIP common subroutines
use gdiplib;

#######################################################################
# E-mail to complete self registration
#######################################################################
sub mail_self {
  my $username = shift;
  my $domain   = shift;
  my $password = shift;
  my $email    = shift;

  # sign the creation data
  my $checkval = md5_base64(
    "$username.$domain.$password.$email.$$pref{'SERVER_KEY'}"
    );

  my $url =
    "$thisurl?selfcreate=$username,$domain,$password," .
    uri_escape($email) . "," . uri_escape($checkval)
    ;

  dosendmail($email, qq*
Subject: GnuDIP Self Registration at $thishost

To complete self registration use this URL:

  $url
.
*);

  writelog(
    "Self registration E-mail for $username.$domain sent to $email"
    );
}

#######################################################################
# E-mail to complete E-mail change
#######################################################################
sub mail_newemail {
  my $username = shift;
  my $domain   = shift;
  my $password = shift;
  my $email    = shift;

  # sign the change data
  my $checkval = md5_base64(
    "$username.$domain.$password.$email.$$pref{'SERVER_KEY'}"
    );

  my $url =
    "$thisurl?newemail=$username,$domain,$password," .
    uri_escape($email) . "," . uri_escape($checkval)
    ;

  dosendmail($email, qq*
Subject: GnuDIP E-mail Update at $thishost

To complete your E-mail address update use this URL:

  $url
.
*);

  writelog(
    "E-mail address change E-mail for $username.$domain sent to $email"
    );
}

#######################################################################
# E-mail with Quick Login URL
#######################################################################
sub mail_quick {
  my $username = shift;
  my $domain   = shift;
  my $password = shift;
  my $email    = shift;

  my $quick =
    "$thisurl?login=enc&username=$username&password=$password";
  if ($domain ne '') {
    $quick .= "&domain=$domain";
  }

  dosendmail($email, qq*
Subject: GnuDIP Quick Login URL for $thishost

You may login to GnuDIP at $thishost using this Quick Login URL:

  $quick
.
*);

  writelog(
    "Quick login E-mail for $username.$domain sent to $email"
    );
}

#############################################################
# subroutines
#############################################################

# call sendmail and catch errors
# - prepend From: and To: headers
sub dosendmail {
  my $to = shift;
  my $msg = shift;

  $to  = '' if !defined $to;
  $msg = '' if !defined $msg;
  $msg = tst($msg);

  $msg = 'From: GnuDIP@' . $thishost . "\nTo: " . $to . "\n" . $msg;

  if (! callsendmail($msg)) {
    writelog("GnuDIP CGI has exited - callsendmail failed");
    bad_config();
  }
}

#######################################################################
# must return 1
#######################################################################
1;

