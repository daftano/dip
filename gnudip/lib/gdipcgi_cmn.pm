########################################################################
# gdipcgi_cmn.pm
#
# These routines are common to the GnuDIP web interface and update
# server CGI-s.
#
# See COPYING for licensing information.
#
########################################################################

# Perl modules
use strict;

# global variables
use vars qw($reqparm $thishost $bad_config $logger $remote_ip $cgi_exit);

# GnuDIP common subroutines
use gdiplib;

# override "exit"
use subs qw(exit);

########################################################################
# override for "exit"
########################################################################
sub exit {
  # call handler?
  &$cgi_exit(@_) if defined $cgi_exit;

  # under mod_perl?
  Apache::exit(@_) if defined &Apache::exit;

  # normal exit
  CORE::exit(@_);
}

########################################################################
# called for database error
########################################################################
sub dberror {
  bad_config();
}

########################################################################
# write to the log and catch errors
########################################################################
sub writelog {
  my @text;
  my $msgprfx = '';
  $msgprfx = "$remote_ip - " if defined $remote_ip;
  while (my $line = shift @_) {
    if ($line =~ /\n/) {
      # split on new line
      push @text, (split(/\n/, $msgprfx . $line));
    } else {
      push @text, ($msgprfx . $line);
    }
  }
  if (! calllogger($logger, @text)) {
    print STDERR "GnuDIP CGI has exited - calllogger failed\n";
    bad_config();
  }
}

########################################################################
# call nsupdate and catch errors
########################################################################
sub donsupdate {
  if (! callnsupdate(@_)) {
    writelog("GnuDIP CGI has exited - callnsupdate failed");
    bad_config();
  }
}

########################################################################
# display the CGI data in the HTTP server log
########################################################################
sub logreq {
  my $var;
  my $val;
  print STDERR "ENV:\n";
  foreach $var (sort(keys(%ENV))) {
    $val = $ENV{$var};
    $val =~ s|\n|\\n|g;
    $val =~ s|"|\\"|g;
    print STDERR "  ${var}=\"${val}\"\n";
  }
  print STDERR "reqparm:\n";
  foreach $var (sort(keys(%$reqparm))) {
    $val = $$reqparm{$var};
    $val =~ s|\n|\\n|g;
    $val =~ s|"|\\"|g;
    print STDERR "  ${var}=\"${val}\"\n";
  }
}

########################################################################
# configuration error handler
########################################################################
sub bad_config {

  # call handler
  &$bad_config() if defined $bad_config;

  # no handler set - default action
  tpr(qq*
Content-Type: text/html; charset=iso-8859-1

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd\">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<title>
GnuDIP Common CGI Code Error Handler
</title>
</head>
<body>
<center>
<h2>
Error: GnuDIP Configuration or Interface Problem Caught In Common CGI Code
</h2>
An internal GnuDIP operation has failed, due to a configuration error, or
the failure of a system service required by GnuDIP.
<p>
Please report this problem to your administrator if it persists.
</center>
</body>
</html>
*);
  exit;  
}

########################################################################
# read POST data from input
########################################################################
sub read_post_data {
  my $str = '';
  my $str_len = 0;
  my $toread = $ENV{'CONTENT_LENGTH'};
  $toread = 0 if ! defined $toread;
  my $eof = '';
  while (!$eof and $toread > 0) {
    my $len = read(STDIN, $str, $toread, $str_len);
    if (!defined($len) || $len eq 0) {
      $eof = 1;
    } else {
      $str_len  = $str_len + $len;
      $toread = $toread - $len;
    }
  }
  # for debugging
  #print STDERR "POST data = $str\n";
  return $str;
}
  
########################################################################
# parse query string or post data
########################################################################
sub parse_query {
  my $str = shift;
  $str = '' if ! defined $str;

  my %parm;
  my @pairs = split(/\&/, $str);
  foreach my $pair (@pairs) {
    my $name;
    my $value;
    if ($pair =~ /^(.*?)=(.*)$/) {
      $name  = $1;
      $value = $2;
    } else {
      $name  = $pair;
      $value = '';
    }
    if (! defined $parm{$name}) {
      $parm{$name} = uri_unescape($value);
    } else {
      $parm{$name} = $parm{$name} . "\0" . uri_unescape($value);
    }
  }
  return \%parm;
}

########################################################################
# parse cookie string
########################################################################
sub parse_cookies {
  my $str = shift;
  $str = '' if ! defined $str;
  my %cookie;
  my @pairs = split(/\;/, $str);
  foreach my $pair (@pairs) {
    # trim leading or trailing white space
    $pair =~ s/\s*(.*?)\s*/$1/;
    my $name;
    my $value;
    if ($pair =~ /^(.*?)=(.*)$/) {
      $name  = $1;
      $value = $2;
    } else {
      $name  = $pair;
      $value = '';
    }
    if (! defined $cookie{$name}) {
      $cookie{$name} = uri_unescape($value);
    }
  }
  return \%cookie;
}

########################################################################
# URI escape a string
########################################################################
sub uri_escape
{
  my $text = shift;
  $text = '' if !defined($text);

  # map unsafe characters (RFC 2732)
  $text =~ s/([\;\/\?\:\@\=\&\<\>\"\#\%\{\}\|\\\^\~\[\]\`\+])/sprintf("%%%02X", ord($1))/eg;

  return $text;
}

########################################################################
# unescape URI escaped string
########################################################################
sub uri_unescape {
  my $text = shift;
  $text = '' if !defined($text);

  $text =~ tr/+/ /;
  $text =~ s/%([0-9a-fA-F]{2})/chr(hex($1))/eg;

  return $text;
}

########################################################################
# generate a "Set-Cookie" header
########################################################################
sub printcookie {
  my $name    = shift;
  my $value   = shift;
  my $expires = shift;
  print
    "Set-Cookie: $name=" . uri_escape($value) .
    "; domain=$thishost; path=/; expires=" . expires($expires) . "\n";
}

#######################################################################
# taken from CGI::Util
# - default for format changed to "cookie"
#######################################################################

# This internal routine creates date strings suitable for use in
# cookies and HTTP headers.  (They differ, unfortunately.)
# Thanks to Mark Fisher for this.
sub expires {
    my($time,$format) = @_;
    $format ||= 'cookie';

    my(@MON)=qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
    my(@WDAY) = qw/Sun Mon Tue Wed Thu Fri Sat/;

    # pass through preformatted dates for the sake of expire_calc()
    $time = expire_calc($time);
    return $time unless $time =~ /^\d+$/;

    # make HTTP/cookie date string from GMT'ed time
    # (cookies use '-' as date separator, HTTP uses ' ')
    my($sc) = ' ';
    $sc = '-' if $format eq "cookie";
    my($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime($time);
    $year += 1900;
    return sprintf("%s, %02d$sc%s$sc%04d %02d:%02d:%02d GMT",
                   $WDAY[$wday],$mday,$MON[$mon],$year,$hour,$min,$sec);
}

# This internal routine creates an expires time exactly some number of
# hours from the current time.  It incorporates modifications from 
# Mark Fisher.
sub expire_calc {
    my($time) = @_;
    my(%mult) = ('s'=>1,
                 'm'=>60,
                 'h'=>60*60,
                 'd'=>60*60*24,
                 'M'=>60*60*24*30,
                 'y'=>60*60*24*365);
    # format for time can be in any of the forms...
    # "now" -- expire immediately
    # "+180s" -- in 180 seconds
    # "+2m" -- in 2 minutes
    # "+12h" -- in 12 hours
    # "+1d"  -- in 1 day
    # "+3M"  -- in 3 months
    # "+2y"  -- in 2 years
    # "-3m"  -- 3 minutes ago(!)
    # If you don't supply one of these forms, we assume you are
    # specifying the date yourself
    my($offset);
    if (!$time || (lc($time) eq 'now')) {
        $offset = 0;
    } elsif ($time=~/^\d+/) {
        return $time;
    } elsif ($time=~/^([+-]?(?:\d+|\d*\.\d*))([mhdMy]?)/) {
        $offset = ($mult{$2} || 1)*$1;
    } else {
        return $time;
    }
    return (time+$offset);
}

#####################################################
# must return 1
#####################################################
1;

