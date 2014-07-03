#####################################################
# gdipupdt.pm
#
# This file really is the GnuDIP update server CGI. The
# gdipupdt.cgi script just executes the gdipupdt subroutine.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;

# global variables
use vars qw($conf $server_key $gnudipdir);
use vars qw($remote_ip);
use vars qw($reqparm $logger);
use vars qw($bad_config);

# GnuDIP common subroutines
use gdiplib;
use gdipcgi_cmn;
use dbusers;

# variables global to this file
my ($pretty_query, $logprfx);

########################################################################
# the actual CGI
########################################################################
sub gdipupdt {

  pg_head()
    if $ENV{'REQUEST_METHOD'} and
       $ENV{'REQUEST_METHOD'} eq 'HEAD';

  # set configuration error handler for common subroutines
  $bad_config = \&bad_config_updt;

  # get preferences from config file
  if (! defined $conf or
      ! defined $$conf{'persistance'} or
      $$conf{'persistance'} ne 'YES') {
    $conf = getconf();
    if (! $conf) {
      print STDERR "GnuDIP IP Update CGI has exited - getconf returned nothing\n";
      dberror();
    }
  }

  # get "server key"
  if (! defined $server_key) {
    my $conffile = "$gnudipdir/etc/gnudip.conf";
    my @stat = stat($conffile);
    $server_key = "$stat[1].$stat[9]";
  }

  # logger command
  $logprfx = '';
  $logger = $$conf{'logger_updt'};
  if (! defined $logger) {
    $logprfx = 'HTTP Update: ';
    $logger = $$conf{'logger_cgi'};
  }

  # not called by HTTP server
  if (!$ENV{'REQUEST_METHOD'} or
      $ENV{'REQUEST_METHOD'} ne 'GET' and
      $ENV{'REQUEST_METHOD'} ne 'POST') {
    writelog( 'gdipupdt.cgi: REQUEST_METHOD environment variable is not set');
    print "REQUEST_METHOD environment variable is not set\n";
    writelog( 'gdipupdt.cgi: Not called by HTTP server');
    print "Not called by HTTP server\n";
    exit;
  }

  # IP address of connecting machine
  $remote_ip   = $ENV{'REMOTE_ADDR'};
  $remote_ip = '0.0.0.0' if !$remote_ip;

  # CGI request information
  if ($ENV{'REQUEST_METHOD'} eq 'POST') {
    $reqparm = parse_query(read_post_data());
  } else {
    $reqparm = parse_query($ENV{'QUERY_STRING'});
  }
  
  # log the HTTP request info to HTTP server log 
  # - for debugging
  #$logreq();

  # called as GET with no parms?
  gen_salt()
    if $ENV{'REQUEST_METHOD'} eq 'GET' and !$ENV{'QUERY_STRING'};

  # html for query string
  $pretty_query = qq*
<p>
<font size="+1"><b>Query String</b></font>
<p>
$ENV{'QUERY_STRING'}
*;

  # called as GET with all parms?
  do_updt()
    if $ENV{'REQUEST_METHOD'} eq 'GET' and
       defined $$reqparm{'salt'} and
       defined $$reqparm{'time'} and
       defined $$reqparm{'sign'} and
       defined $$reqparm{'domn'} and
       defined $$reqparm{'user'} and
       defined $$reqparm{'pass'} and
       defined $$reqparm{'reqc'};

  # bad HTTP request
  writelog($logprfx .
    "Invalid query string from $remote_ip");
  pg_updtsrv(tst(qq*
Error: Invalid query string
$pretty_query
*));
}

# generate salt response and exit
sub gen_salt {

  my $salt     = randomsalt();
  my $gentime  = time();
  my $checkval = md5_hex("$salt.$gentime.$server_key");

  pg_updtsrv(
    'Salt generated',
    'salt', $salt,
    'time', $gentime,
    'sign', $checkval
    );
}

sub do_updt {

  my $salt         = $$reqparm{'salt'};
  my $gentime      = $$reqparm{'time'};
  my $ip           = $remote_ip;
  my $clientuser   = $$reqparm{'user'};
  my $clientpass   = $$reqparm{'pass'};
  my $clientdomain = $$reqparm{'domn'};
  my $clientaction = $$reqparm{'reqc'};
  my $clientip     = $$reqparm{'addr'};

  # validate the signature
  my $checkval = md5_hex("$salt.$gentime.$server_key");
  if ($checkval ne $$reqparm{'sign'}) {
    writelog($logprfx .
      "Invalid signature for $clientuser.$clientdomain");
    respond(tst(qq*
Error: Invalid signature
$pretty_query
*),
      '1');
  }

  # seconds to wait for response to prompt
  my $timeout = $$conf{'timeout_updt'};
  if (! defined $timeout) {
    $timeout = 6 * $$conf{'timeout'};
  }

  # timed out?
  if (time() > $gentime + $timeout) {
    writelog($logprfx .
      "Salt value too old from $remote_ip: user $clientuser.$clientdomain");
    respond('Error: Salt value too old', '1');
  }

  # sensible request?
  if($clientaction ne '0' && $clientaction ne '1' && $clientaction ne '2') {
    writelog($logprfx .
      "Invalid client request code from $ip: user $clientuser.$clientdomain");
    respond(tst(qq*
Error: Invalid client request code
$pretty_query
*),
      '1');
  }

  # "dummy" request?
  if ($clientaction eq '2' and
      $$conf{'dummyuser'}  and
      $$conf{'dummydomn'}  and
      $$conf{'dummypswd'}) {
    # massage host template into valid Perl regular expression
    my $check = $$conf{'dummyuser'};
    $check =~ s/\*/\(\.\*\)/g;
    $check =~ s/\?/\(\.\)/g;
    # check for a match
    if ($clientuser   =~ /^$check\b/ and 
        $clientdomain eq $$conf{'dummydomn'} and 
        $clientpass   eq md5_hex(md5_hex($$conf{'dummypswd'}) . ".$salt")) {
      writelog(
        "Dummy request processed for user $clientuser from ip $ip");
      respond('Successful dummy request', '0', $ip);
    }
  }

  # retrieve user information
  my $userinfo = getuser($clientuser, $clientdomain);

  # bad login?
  if (!$userinfo                              or
      $clientuser   ne $$userinfo{'username'} or
      $clientdomain ne $$userinfo{'domain'}   or
      $clientpass   ne md5_hex("$$userinfo{'password'}.$salt")
      ) {
    writelog($logprfx .
      "Invalid login attempt from $ip: user $clientuser.$clientdomain");
    respond(tst(qq*
Error: Invalid login attempt
$pretty_query
*),
      '1');
  }

  # update request with 0.0.0.0 for address? convert to offline
  $clientaction = '1'
    if $clientaction eq '0' and
       defined($clientip)   and $clientip eq '0.0.0.0';

  # use IP address client connected from?
  $clientip = $ip if $clientaction eq '2';

  # client passed an IP address?
  if ($clientaction eq '0' and (!defined($clientip) or $clientip eq '')) {
    writelog($logprfx .
      "No IP address passed from $ip: user $clientuser.$clientdomain");
    respond(tst(qq*
Error: No IP address was passed for request type 0
$pretty_query
*),
      '1');
    exit;
  }

  # invalid IP address?
  if($clientaction ne '1' && !validip($clientip)) {
    writelog($logprfx .
      "Unserviceable IP address from $ip: user $clientuser.$clientdomain - IP: $clientip");
    respond(tst(qq*
Error: Unserviceable IP address - IP: $clientip
$pretty_query
*),
      '1');
    exit;
  }

  # TTL value
  my $TTL = 0;
  $TTL = $$conf{'TTL'} if $$conf{'TTL'};
  $TTL = $$conf{"TTL.$clientdomain"}
      if $$conf{"TTL.$clientdomain"};
  $TTL = $$conf{"TTL.$clientuser.$clientdomain"}
      if $$conf{"TTL.$clientuser.$clientdomain"};

  # a modify request?
  if ($clientaction eq '0' or $clientaction eq '2') {

    # IP address unchanged?
    if ($$userinfo{'currentip'} eq $clientip) {
      writelog($logprfx .
        "User $clientuser.$clientdomain remains at ip $clientip");
      updateuser($userinfo);

    # do the update
    } else {
      donsupdate($clientdomain,
        "update delete $clientuser.$clientdomain. A",
        "update add    $clientuser.$clientdomain. $TTL A $clientip");
      writelog($logprfx .
        "User $clientuser.$clientdomain successful update to ip $clientip");
      $$userinfo{'currentip'} = $clientip;
      updateuser($userinfo);
    }

    if ($clientaction eq '2') {
      respond('Successful update request', '0', $clientip);
    } else {
      respond('Successful update request', '0');
    }

  # an offline request
  } else {

    # IP address unchanged?
    if ($$userinfo{'currentip'} eq '0.0.0.0') {
      writelog($logprfx .
        "User $clientuser.$clientdomain remains removed");
      updateuser($userinfo);

    # do the update
    } else {
      donsupdate($clientdomain,
        "update delete $clientuser.$clientdomain. A");
      writelog($logprfx .
        "User $clientuser.$clientdomain successful remove from ip $$userinfo{'currentip'}");
      $$userinfo{'currentip'} = '0.0.0.0';
      updateuser($userinfo);
    }

    respond('Successful offline request', '2');
  }
}

#############################################################
# subroutines
#############################################################

# configuration error handler
sub bad_config_updt {
  pg_updtsrv('Error: GnuDIP Configuration or Interface Problem');
}

# print response page
sub respond {
  my $msg  = shift;
  my $retc = shift;
  my $addr = shift;
  pg_updtsrv($msg, 'retc', $retc, 'addr', $addr) if $addr;
  pg_updtsrv($msg, 'retc', $retc);
}

# generate page with optional buried meta tags
sub pg_updtsrv {
  my $msg = shift;
  my @meta = @_;
  tpr(qq*
Content-Type: text/html; charset=iso-8859-1

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd\">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<title>
GnuDIP Update Server
</title>
*);
  while (my $name = shift @meta) {
    my $content = shift @meta;
    tpr(qq*
<meta name="$name" content="$content">
*);
  }
  tpr(qq*
</head>
<body>
<center>
<h2>
GnuDIP Update Server
</h2>
$msg
</center>
</body>
</html>
*);
  exit;  
}

# generate header only
sub pg_head {
  tpr(qq*
Content-Type: text/html; charset=iso-8859-1

*);
  exit;  
}

#####################################################
# must return 1
#####################################################
1;

