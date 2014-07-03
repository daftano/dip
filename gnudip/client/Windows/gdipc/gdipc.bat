@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S "%0" %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!/usr/bin/perl
#line 15
#####################################################
# gdipc.pl
#
# This is the GnuDIP command line client.
#
# See COPYING for licensing information
#
# Derived from GnuDIP 2.1.2 written by:
#
#   Mike Machado
#
#####################################################

# locate ourselves
use FindBin;
use lib "$FindBin::Bin/lib";

# PERL packages and options
use warnings;
use strict;
use Socket;
use Getopt::Std;
use English;
use Win32;
use Win32::Process;
use Digest::MD5 qw(md5_hex);

# suffix for config file
my $cfgsuff = '.txt';

# get program name
my $pgm = $0;
if ($pgm =~ /^.*\/(.+?)$/) {
  $pgm = $1;
}

# process command line
sub usage {
  print STDOUT <<EOQ;
usage: $pgm \\
usage:   { -h | -v | -i [ -r] | [ -f configfile ] [ -c | -r | \\
usage:       [ -o outfile | -a appendfile | -l logfile ] \\
usage:       [ -g sendport:recvport ] [ -d repeatseconds] \\
usage:       [ -w waitseconds] [ -q "addressquerycommand" ] ] \\
usage:       [ -x "addresschangedcommand" ] }
usage: With no arguments, update server if address changed or time
usage: expired.
usage: -h: Print this usage message.
usage: -v: Show version information.
usage: -i: Prompt and read standard input rather than a configuration
usage:     file.
usage: -f: Specify a particular configuration file.
usage:     This will otherwise be .GnuDIP2$cfgsuff in the directory
usage:     specified by the HOME environment variable, or gdipc.conf$cfgsuff
usage:     in the directory of the binary if HOME is not set.
usage: -c: Specify contents to write to configuration file.
usage: -r: Send an offline request to the server to remove your DNS hostname.
usage: -d: Run as a daemon. Perform client action immediately and then every
usage:     "repeatseconds" seconds.
usage: -o: Specify log file to overwrite on each run with output from script.
usage: -a: Specify log file to append on each run with all output from script.
usage: -l: Specify log file for daemon mode. Overwrite on first run, then
usage:     append.
usage: -w: Timeout in seconds when waiting for address validation packet.
usage:     Defaults to 1 second. Decimal point and fraction (e.g. "0.5") is
usage:     allowed.
usage: -g: Client is behind a gateway. Request GnuDIP server to register
usage:     address it sees connection from, and pass it back in response.
usage:     Specify port to send address validation packet to and port gateway
usage:     will forward it to.
usage: -q: Command to invoke to determine IP address to report to GnuDIP
usage:     server. Command must write address to standard output. When used
usage:     with -g, address is sent to server.
usage: -x: Command to invoke if address changed. This command can be used to
usage:     to take any actions required when the address changes. All
usage:     validated addresses are passed as arguments.
EOQ
  exit;
}
use vars qw($opt_h $opt_v $opt_f $opt_i $opt_c $opt_r $opt_x);
use vars qw($opt_a $opt_o $opt_l $opt_g $opt_d $opt_w $opt_q);
if (!getopts('hvicrf:o:a:l:g:d:w:x:q:')) {
  usage();
}
if (@ARGV ne 0) {
  usage();
}

# redirect output?
my $logfile;
if ($opt_d and $opt_l) {
  $logfile = $opt_l;
  close STDOUT;
  open(STDOUT, ">$logfile");
  close STDERR;
  open(STDERR, ">&STDOUT");
  # auto flush all output
  select(STDERR);
  $| = 1;
  select(STDOUT);
  $| = 1;
} elsif ($opt_a) {
  $logfile = $opt_a;
  close STDOUT;
  open(STDOUT, ">>$logfile");
  close STDERR;
  open(STDERR, ">&STDOUT");
  # auto flush all output
  select(STDERR);
  $| = 1;
  select(STDOUT);
  $| = 1;
} elsif ($opt_o) {
  $logfile = $opt_o;
  close STDOUT;
  open(STDOUT, ">$logfile");
  close STDERR;
  open(STDERR, ">&STDOUT");
  # auto flush all output
  select(STDERR);
  $| = 1;
  select(STDOUT);
  $| = 1;
}

# asking for help?
if ($opt_h) {
  usage();
}

# asking for version?
if ($opt_v) {
  print "This is $pgm: Version 2.3\n";
  exit;
}

# default port for address validation
my $sendport;
my $recvport = 0;

# behind gateway?
if ($opt_g) {
  if ($opt_g =~ /^([0-9]*)\:([0-9]*)$/) {
    $sendport = $1;
    $recvport = $2;
  } else {
    print "Invalid send/receive port specification for -g option\n";
    usage();
  }
}

# timeout interval
$opt_w = 1 if ! $opt_w;

#interactive mode?
if ($opt_i) {
  interactive();
  exit;
}

# get config file name
my $configfile = '';
if ($opt_f) {
  $configfile = $opt_f;
} elsif($ENV{'HOME'}) {
  $configfile = $ENV{'HOME'} . '/.GnuDIP2' . $cfgsuff;
} else {
  # get path to our parent directory
  my $binpath = $FindBin::Bin;
  $configfile = $binpath . '/gdipc.conf' . $cfgsuff;
}
if ($configfile =~ /(.*)/) {
  $configfile = $1;
}

# setting preferences?
if ($opt_c) {
  setprefs();
  exit;
}

# variable for address returned by -q
my $queryaddress;

# hash of addresses already checked for validity
my %chkaddr;

# flag to indicate address(es) changed
my $addrchange;

# setting offline or not daemon mode?
if ($opt_r or ! defined $opt_d or ! $opt_d) {
  # do one run
  one_run();
  exit;
}

# daemon mode

# milliseconds to wait
my $wait = 1000 * $opt_d;

# path to perl executable
my $path = $EXECUTABLE_NAME;

# construct command line
my $command  = $path . ' ' . $PROGRAM_NAME;
$command .= " -f \"$opt_f\"" if $opt_f;
$command .= " -o \"$opt_o\"" if $opt_o;
$command .= " -a \"$opt_a\"" if $opt_a;
$command .= " -a \"$opt_l\"" if $opt_l;
$command .= " -w \"$opt_w\"" if $opt_w;
$command .= " -f \"$opt_f\"" if $opt_f;
$command .= " -g \"$opt_g\"" if $opt_g;
$command .= " -q \"$opt_q\"" if $opt_q;
$command .= " -x \"$opt_x\"" if $opt_x;

# for trouble shooting
#print "Windows daemon mode\n";
#print "path:    $path\n";
#print "command: $command\n";

# repeat forever ...
while (1) {

  # variable for process object
  my $process;

  # spawn command
  if (! Win32::Process::Create(
      $process, $path, $command, 0, NORMAL_PRIORITY_CLASS, '.')) {
    print "Error creating process ...\n";
    print Win32::FormatMessage(Win32::GetLastError());
    exit;
  }

  # wait before spawning again
  Win32::Sleep($wait);

  # kill previous interation if still running
  $process->Kill(255);
}

#####################################################
# subroutines
#####################################################

# perform one run of the client action
sub one_run {

  # print heading
  my $now_string = localtime;
  print "====  $pgm running:  $now_string  ====\n";
  print "Configuration file name: $configfile\n";

  # any old query result expired
  undef $queryaddress;

  # open configuration file
  if (!open(CONFIG,"$configfile")) {
    print "You must first set up your preferences with \"$pgm -c\"\n";
    exit 1;
  }

  # what server action?
  my $serveraction;
  if ($opt_g and !$opt_q) {
    # update asking for IP address
    $serveraction = '2';
  } elsif ($opt_r) {
    # offline request
    $serveraction = '1';
  } else {
    # update passing IP address
    $serveraction = '0';
  }

  # no addresses validated yet
  %chkaddr = ();

  # no addresses have changed
  $addrchange = '';

  # check address and update address at servers
  while (my $line = <CONFIG>) {
    chomp($line);
    next if !$line;
    my ($username, $domain, $serverip, $password, $cachefile, $mintime, $maxtime)
      = split(/;/, $line);
    if (!$username or !$domain or !$serverip or !$password or
        !$cachefile or ! defined $mintime or $mintime eq '' or
        ! defined $maxtime or $maxtime eq '') {
      print "Ignoring bad line found in configuration file:\n==> $line\n";
      next;
    }
    sendlogin(
      $username, $password, $domain, $serverip, $serveraction,
      $cachefile, $mintime, $maxtime);
  }

  close(CONFIG);

  # need to run address change script?
  if ($opt_x and $addrchange) {
    my $cmd = $opt_x;
    foreach my $addr (keys %chkaddr) {
      $cmd .= " $addr" if $chkaddr{$addr};
    }
    # flush before command
    select(STDERR);
    $| = 1;
    select(STDOUT);
    $| = 1;
    #$cmd =~ s/\\/\\\\/g;
    #system(shellwords($cmd));
    system($cmd);
  }
}

# do interactive mode
sub interactive {

  print "Using Interactive Mode\n";

  print "Username: ";
  chomp(my $username = <STDIN>);

  print "Domain: ";
  chomp(my $domain = <STDIN>);

  print "Connect by direct TCP (d) or web server (w) [d]: ";
  chomp(my $srvtype = <STDIN>);
  $srvtype = 'd'
    if !($srvtype eq 'd' or $srvtype eq 'w');

  print "GnuDIP Server - host[:port]: ";
  chomp(my $serverip = <STDIN>);

  my $url;
  if ($srvtype eq 'w') {
    print "Server URL [/gnudip/cgi-bin/gdipupdt.cgi]: ";
    chomp(my $url = <STDIN>);
    $url = '/gnudip/cgi-bin/gdipupdt.cgi' if !$url;
    $serverip = "http://$serverip$url";
  }

  print "Password: ";
  chomp(my $password = <STDIN>);
  $password = md5_hex($password);

  # what server action?
  my $serveraction;
  if ($opt_g and !$opt_q) {
    # update asking for IP address
    $serveraction = '2';
  } elsif ($opt_r) {
    # offline request
    $serveraction = '1';
  } else {
    # update passing IP address
    $serveraction = '0';
  }

  # update address at server
  sendlogin($username, $password, $domain, $serverip, $serveraction);
}

# set preferences
sub setprefs {

  print "Using Update Configuration Mode\n";
  print "Configuration file name: $configfile\n";

  print "Username: ";
  chomp(my $username = <STDIN>);

  print "Domain: ";
  chomp(my $domain = <STDIN>);

  print "Connect by direct TCP (d) or web server (w) [d]: ";
  chomp(my $srvtype = <STDIN>);
  $srvtype = 'd'
    if !($srvtype eq 'd' or $srvtype eq 'w');

  print "GnuDIP Server - host[:port]: ";
  chomp(my $serverip = <STDIN>);

  my $url;
  if ($srvtype eq 'w') {
    print "Server URL [/gnudip/cgi-bin/gdipupdt.cgi]: ";
    chomp(my $url = <STDIN>);
    $url = '/gnudip/cgi-bin/gdipupdt.cgi' if !$url;
    $serverip = "http://$serverip$url";
  }

  print "Password: ";
  chomp(my $password = <STDIN>);
  $password = md5_hex($password);

  my $cachefile = '';
  if ($configfile =~ /^(.*)\/(.+?)$/) {
    my $cachedir  = $1;
    my $cachename = $2;
    if ($cachename =~ /^(.+?)\..*$/) {
      $cachename = $1;
    }
    $cachefile = "$cachedir/$cachename.cache.$username.$domain" . $cfgsuff;
  }
  print "Cache File [$cachefile]: ";
  chomp(my $newcache = <STDIN>);
  $cachefile = $newcache if $newcache ne '';
  # trust $cachefile
  if ($cachefile =~ /(.*)/) {
    $cachefile = $1;
  }

  my $mintime = '0';
  print "Minimum Seconds Between Updates [$mintime]: ";
  chomp(my $newmin = <STDIN>);
  $mintime = $newmin if $newmin ne '';

  my $maxtime = '2073600';
  print "Maximum Seconds Between Updates [$maxtime]: ";
  chomp(my $newmax = <STDIN>);
  $maxtime = $newmax if $newmax ne '';

  # update configuration file
  my @oldconfig = ();
  if (open(CONFIG, "$configfile")) {
    while (my $line = <CONFIG>) {
      chomp($line);
      next if !$line;
      push @oldconfig, ($line);
    }
    close(CONFIG);
  }
  open(CONFIG, ">$configfile") or
    die "Could not create configuration file $configfile: $!\n";
  foreach my $line (@oldconfig) {
    my ($oldusername, $olddomain) = split(/;/, $line);
    if ($oldusername ne $username || $olddomain ne $domain) {
      print CONFIG "$line\n";
    }
  }
  print CONFIG
    "$username;$domain;$serverip;$password;$cachefile;$mintime;$maxtime\n";
  close(CONFIG);
  chmod 0600, $configfile;

  # initialise cache file
  open(CACHE, ">$cachefile") or
    die "Could not create cache file $cachefile: $!\n";
  print CACHE "0.0.0.0;0\n";
  close(CACHE);
  chmod 0600, $cachefile;
}

# check address and connect to server to send update
sub sendlogin {
  my $username = shift;
  my $password = shift;
  my $domain = shift;
  my $serverip = shift;
  my $serveraction = shift;
  my $cachefile = shift;
  my $mintime = shift;
  my $maxtime = shift;

  # trust $serverip
  if ($serverip =~ /(.*)/) {
    $serverip = $1;
  }

  # last three arguments passed?
  my $cacheip   = '0.0.0.0';
  my $cachetime = '0';
  if (! $cachefile) {
    $mintime = 0;
    $maxtime = 0;
  } else {

    # trust $cachefile
    if ($cachefile =~ /(.*)/) {
      $cachefile = $1;
    }

    print "Cache file name: $cachefile\n";

    # read cache
    if (open(CACHE, "$cachefile")) {
      my $line = <CACHE>;
      if ($line) {
        chomp($line);
        ($cacheip, $cachetime) = split(/;/,$line);
      }
      close(CACHE);
    }
  }

  # requesting offline, but already offline?
  if (!$opt_i and $serveraction eq '1' and $cacheip eq '0.0.0.0') {
    print "No update done for $username.$domain - already offline\n";
    return;
  }

  # use query command to get address?
  callquery()
    if $serveraction eq '0' and $opt_q and !$queryaddress;

  # current time
  my $timenow = time;

  # update wanted but not needed?
  if (($serveraction eq '0' or $serveraction eq '2') and
      $cacheip ne '0.0.0.0') {

    # maximum time not exceeded?
    if ($timenow < ($cachetime + $maxtime)) {

      # address still valid?
      if (checkaddress($cacheip)) {
        print "No update done for $username.$domain - $cacheip still valid\n";
        return;
      }

      # not enough time gone by?
      if ($timenow < ($cachetime + $mintime)) {
        print "No update from $cacheip done for $username.$domain - too soon\n";
        return;
      }
    }
  }

  # get server type, address, port and URL
  my $srvtype = 'd';
  my ($serverhost, $serverport, $url);
  if ($serverip =~ /^http:\/\/(.*?)(\/.*)$/) {
    # web server
    $srvtype = 'w';
    $serverip = $1;
    $url = $2;
    ($serverhost, $serverport) = split(/:/, $serverip . ':80');
  } else {
    # direct TCP connection
    ($serverhost, $serverport) = split(/:/, $serverip . ':3495');
  }

  # start the update
  print "Attempting update at $serverhost ...\n";
  my $inet_addr = gethostbyname($serverhost);
  if (!$inet_addr) {
    print "Could not do DNS lookup for $serverhost\n";
    return;
  }
  my $paddr = sockaddr_in($serverport, $inet_addr);

  # connect to server
  socket(SERVER, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
  if (!connect(SERVER, $paddr)) {
    print "Could not connect to $serverhost:$serverport\n";
    return;
  }

  # set autoflush on
  select(SERVER);
  $| = 1;
  select(STDOUT);

  # retrieve the salt (et al)
  my $salt;
  my $gentime;
  my $checkval;

  # HTTP headers
  my $httphdrs = "HTTP/1.0\r
User-Agent: GnuDIP/2.3.5\r
Pragma: no-cache\r
Host: $serverhost:$serverport\r
\r
";

  # direct TCP connection
  if ($srvtype eq 'd') {
    $salt = <SERVER>;
    $salt = '' if ! defined $salt;
    chomp($salt);

  # web server
  } else {
    #print "GET $url $httphdrs";
    print SERVER "GET $url $httphdrs";
    my %resp = ();
    while (my $line = <SERVER>) {
      $line = '' if ! defined $line;
      chomp($line);
      #print "$line\n";
      if ($line =~ /^<meta name=\"(.*)\" content=\"(.*)\">$/) {
        $resp{$1} = $2;
      }
    }
    close SERVER;
    $salt     = $resp{'salt'};
    $gentime  = $resp{'time'};
    $checkval = $resp{'sign'};

    # reconnect
    socket(SERVER, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
    if (!connect(SERVER, $paddr)) {
      print "Could not reconnect to $serverhost:$serverport\n";
      return;
    }
    select(SERVER);
    $| = 1;
    select(STDOUT);
  }

  # got a salt?
  if (!$salt) {
    print "Server did not send salt for $username.$domain\n";
    close SERVER;
    return;
  }

  # get our IP address
  my $ip;

  # have address from query?
  if ($queryaddress) {
    $ip = $queryaddress;

  # get IP address of our end of connection
  } else {
    my $client_addr = getsockname(SERVER);
    if (!$client_addr) {
      print "Could not get our IP address for $username.$domain\n";
      close(SERVER);
      return;
    }
    my ($port, $packed_ip) = sockaddr_in($client_addr);
    $ip = inet_ntoa($packed_ip);
  }

  # salt and digest password
  $password = md5_hex("$password.$salt");

  # send update to server and retrieve response
  my $response   = '';
  my $receivedip = '';

  # direct TCP connection
  if ($srvtype eq 'd') {
    my $updmsg = "$username:$password:$domain:$serveraction";
    $updmsg   .= ":$ip" if $serveraction eq '0';
    print SERVER "$updmsg\n";
    $response = <SERVER>;
    close SERVER;
    $response = '' if ! defined $response;
    chomp($response);
    if ($response =~ /^(.*):(.*)$/) {
      $response   = $1;
      $ip         = $2;
      $receivedip = 1;
    }

  # web server
  } else {
    my $updmsg =
      "salt=$salt&time=$gentime&sign=$checkval&user=$username&" .
      "pass=$password&domn=$domain&reqc=$serveraction";
    $updmsg .= "&addr=$ip" if $serveraction eq '0';
    #print "GET $url?$updmsg $httphdrs";
    print SERVER "GET $url?$updmsg $httphdrs";
    my %resp = ();
    while (my $line = <SERVER>) {
      $line = '' if ! defined $line;
      chomp($line);
      #print "$line\n";
      if ($line =~ /^<meta name=\"(.*)\" content=\"(.*)\">$/) {
        $resp{$1} = $2;
      }
    }
    close SERVER;
    $response = $resp{'retc'} if defined $resp{'retc'};
    if (defined $resp{'addr'}) {
      $ip          = $resp{'addr'};
      $receivedip = 1;
    }
  }

  # got a response?
  if ($response eq '') {
    print "Server did not respond to login attempt for $username.$domain\n";
    return;
  }

  # check response
  if ($response eq '0') {
    if ($serveraction eq '2' and !$receivedip) {
      print "Server did not send IP address for $username.$domain\n";
    } else {
      if ($cachefile) {
        if (!open(CACHE, ">$cachefile")) {
          print "Could not write cache file $cachefile: $!\n";
        } else {
          print CACHE "$ip;$timenow\n";
          close(CACHE);
          # address changed?
          $addrchange = 1 if $cacheip ne $ip;
          # good address (was not tested if past max time))
          $chkaddr{$ip} = 1;
        }
        print "Update to address $ip from $cacheip successful for $username.$domain\n";
      } else {
        print "Update to address $ip successful for $username.$domain\n";
      }
    }
  } elsif ($response eq '1') {
    print "Invalid login attempt for $username.$domain\n";
  } elsif ($response eq '2') {
    if ($cachefile) {
      if (!open(CACHE, ">$cachefile")) {
        print "Could not write cache file $cachefile: $!\n";
      } else {
        print CACHE "0.0.0.0;$timenow\n";
        close(CACHE);
        # address changed?
        $addrchange = 1 if $cacheip ne '0.0.0.0';
      }
    }
    print "Offline request successful for $username.$domain\n";
  } else {
    print "Server sent invalid response to login attempt for $username.$domain\n";
  }
}

# check whether an address is valid
# - sends random data to the address
# - if it receives it back the address is good
sub checkaddress {

  # get parameter
  my $testip = shift;
  return '' if ! defined $testip;

  # trust $testip
  if ($testip =~ /(.*)/) {
    $testip = $1;
  }

  # already checked this address?
  return $chkaddr{$testip} if defined $chkaddr{$testip};

  # assume bad address
  $chkaddr{$testip} = '';

  # have address from query?
  if ($queryaddress) {

    # address the same?
    if ($testip ne $queryaddress) {
      print "Address returned by \"-q\" does not match cached address\n";
      return '';
    }

    # good address
    $chkaddr{$testip} = 1;
    return 1;
  }

  # generate a test value
  my $testdata = randomsalt();

  # print a trace to STDERR?
  my $trace = '';
  #$trace = 1;

  # bind socket for receive
  socket(RECEIVE, PF_INET, SOCK_DGRAM, getprotobyname('udp'))
    || die "socket for RECEIVE failed in checkaddress: $!\n";
  setsockopt(RECEIVE, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))
    || die "setsockopt failed in checkaddress: $!\n";
  bind(RECEIVE, sockaddr_in($recvport, INADDR_ANY))
    || die "bind failed in checkaddress: $!\n";

  # random port being used to receive? (no gateway?)
  ($sendport) = sockaddr_in(getsockname(RECEIVE)) if $recvport eq 0;

  # send packet
  socket(SEND, PF_INET, SOCK_DGRAM, getprotobyname('udp'))
    || die "socket for SEND failed in checkaddress: $!\n";
  if (! send(SEND, $testdata, 0, sockaddr_in($sendport, inet_aton($testip)))) {
    close SEND;
    close RECEIVE;
    # not a good address
    print "Address validation failed for $testip - send failed: $!\n";
    return '';
  }
  print STDERR "sent data: $testdata\n" if $trace;
  close SEND;

  # wait for packet, with a timeout
  my $sin = '';
  vec($sin, fileno(RECEIVE), 1) = 1;
  if (! select($sin, undef, undef, $opt_w)) {
    print STDERR "select failed\n" if $trace;
    close RECEIVE;
    # not a good address
    print "Address validation failed for $testip - UDP packet timed out\n";
    return '';
  }

  # receive it
  print STDERR "select succeeded\n" if $trace;
  recv(RECEIVE, my $check, 20, 0)
    || die "receive failed in checkaddress: $!\n";
  close RECEIVE;
  print STDERR "received data: $check\n" if $trace;

  # data matches?
  if ($check ne $testdata) {
    print "Address validation failed for $testip - data not matched\n";
    return '';
  }

  # good address
  $chkaddr{$testip} = 1;
  return 1;
}

# call query command to get address
sub callquery {

  # flush before command
  select(STDERR);
  $| = 1;
  select(STDOUT);
  $| = 1;

  # call the command
  $queryaddress = `$opt_q`;
  my $retcode = $?;
  $retcode = $retcode >> 8;

  # command succeeded?
  if (! defined $queryaddress) {
    print "Query command failed - no ouput retrieved\n";
    exit 1;
  } elsif ($retcode != 0) {
    print "Query command returned non-zero status: $retcode\n";
    exit 1;
  }
  chomp($queryaddress);
  if (!$queryaddress) {
    print "Query command returned empty address\n";
    exit 1;
  }

  print "Query command returned address $queryaddress\n";
}

# make 10 character random string
sub randomsalt {
  my @chars = ( 'A' .. 'Z', 'a' .. 'z', 0 .. 9);
  my $str = '';
  for (my $charcount = 0; $charcount < 10; $charcount++) {
    $str .= $chars[ rand @chars ];
  }
  return $str;
}


__END__
:endofperl
