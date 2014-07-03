#####################################################
# gdiplib.pm
#
# These are GnuDIP common subroutines.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;
use POSIX;
use Socket;
use Text::ParseWords;

# global variables
use vars qw($conf $gnudipdir);

# try for compiled MD5, otherwise use pure Perl
BEGIN {
  eval {
    require Digest::MD5;
    import  Digest::MD5 qw(md5_hex md5_base64)
  };
  if ($@) { # no Digest::MD5
    require Digest::Perl::MD5;
    import  Digest::Perl::MD5 qw(md5_hex md5_base64)
  }             
}

#####################################################
# make 10 character random salt
#####################################################
sub randomsalt {
  my @chars = ( 'A' .. 'Z', 'a' .. 'z', 0 .. 9);
  my $salt = '';
  for (my $charcount = 0; $charcount < 10; $charcount++) {
    $salt .= $chars[ rand @chars ];
  }
  return $salt;
}

#######################################################################
# strip leading blank line from string
#######################################################################
sub tst {
  my $str = shift;
  $str =~ s /^\n//;
  return $str;
}

#######################################################################
# print string with leading blank line removed
#######################################################################
sub tpr {
  print tst(shift);
}

#####################################################
# get parms from config file 
#####################################################
sub getconf {
  my $conffile = shift;
  $conffile = $gnudipdir . '/etc/gnudip.conf'
    if !defined $conffile;
  my %result;
  local *CONF;
  if (! open (CONF, "<$conffile")) {
    print STDERR "getconf: cannot open $conffile\n";
    print STDERR "getconf: $!\n";
    print STDERR 'getconf: effective user - ' . getpwuid($>) . "\n";
    my $grps = '';
    foreach my $gid ($)) {
      $grps .= ' ' .  getgrgid($gid);
    }
    print STDERR 'getconf: effective groups -' . $grps . "\n";
    return undef;
  }
  while (<CONF>) {
    my $line = $_;
    if ($line =~ /^(.*?)\#(.*)$/) {
      $line = $1;
    }    
    if ($line =~ /^\s*(\w[-\w|\.]*)\s*=\s*(.*?)\s*$/) {
      if ($result{$1}) {
        $result{$1} .= ' ' . $2;
      } else {
        $result{$1} = $2;
      }
    }
  }
  close CONF;
  return \%result;
}

#####################################################
# call logger command
#####################################################
sub calllogger {

  # how callcommand can display errors
  my $printerror = sub {
    my $line = shift;
    print STDERR $line . "\n";
    };

  # no non-zero return codes are OK
  return callcommand('', $printerror, @_);
}

#####################################################
# call BIND nsupdate command
# $conf should be a global variable
#####################################################
sub callnsupdate {
  my $domain = shift;
  if (!$domain) {
    writelog('callnsupdate: domain not passed');
    return '';
  }

  if (!$conf) {
    writelog('callnsupdate: $conf is not defined');
    return '';
  }
  if (!$conf) {
    writelog('callnsupdate: $$conf{\'nsupdate\'} is not defined');
    return '';
  }

  # BIND nsupdate command for our situation
  my $nsupdate = $$conf{'nsupdate'};
  $nsupdate = $$conf{"nsupdate.$domain"}
           if $$conf{"nsupdate.$domain"};

  # no non-zero return codes are OK
  return callcommand('', \&writelog, $nsupdate, @_, '');
}

#####################################################
# call sendmail command
# $conf should be a global variable
#####################################################
sub callsendmail {
  my $email = shift;
  if (!$email) {
    writelog('callsendmail: no email was passed');
    return '';
  }

  if (!$conf) {
    writelog('callnsupdate: $conf is not defined');
    return '';
  }
  if (!$conf) {
    writelog('callnsupdate: $$conf{\'sendmail\'} is not defined');
    return '';
  }

  # allow 67/EX_NOUSER return code from sendmail
  return callcommand('67', \&writelog, $$conf{'sendmail'}, $email);
}

#####################################################
# call a command that reads standard input
#####################################################
sub callcommand {

  # allowable return codes, seperated by spaces
  my @okcodes = split(/ /, shift);

  my $writelog = shift;
  if (!$writelog) {
    print STDERR 'callcommand: writelog subroutine not passed';
    return '';
  }

  my $command = shift;
  if (!$command) {
    &$writelog('callcommand: command line not passed');
    return '';
  }

  # collect remaining arguments as input text
  my @text;
  foreach my $line (@_) {
    if ($line =~ /\n/) {
      # split on new line
      push @text, (split(/\n/, $line));
    } else {
      push @text, ($line);
    }
  }

  # for trouble shooting
  #&$writelog($command);
  #foreach my $line (@text) {
  #  &$writelog($line);
  #}

  # (local) pipe for retrieving output from command
  local *RESPREAD;
  local *RESPWRITE;
  pipe(RESPREAD, RESPWRITE);

  # flush before fork
  select(STDERR);
  $| = 1;
  select(STDOUT);
  $| = 1;

  # writable open with a fork to run command
  local *COMMAND;
  my $pid = open(COMMAND, "|-");
  if (! defined $pid) {
    # fork failed
    # message to log
    &$writelog('callcommand: open failed');
    return '';
  }
  if ($pid eq 0) {
    # child
    # to placate "-T" - trust path
    my $path = $ENV{PATH};
    if ($path =~ /^(.*)$/) {
      $path = $1;
    }
    $ENV{PATH} = $path;
    # for FCGI.pm compatibility
    untie *STDOUT;
    untie *STDERR;
    # direct all output to response pipe
    open (STDOUT, ">&RESPWRITE") or
      &$writelog('callcommand: cannot redirect STDOUT');
    open (STDERR, ">&STDOUT") or
      &$writelog('callcommand: cannot redirect STDERR');
    # pass control to command
    my @words = shellwords($command);
    my $ok = exec {$words[0]} @words;
    if (! $ok) {
      # should not have come back!
      # flush all output
      close STDERR;
      close STDOUT;
      close RESPWRITE;
      # exit, bypassing Perl
      POSIX::_exit 255;
    }
  }
  # parent

  # feed each line of input text to command
  foreach my $line (@text) {
    print COMMAND "$line\n";
  }

  # close (and wait) for it
  my $close = close COMMAND;
  my $exitval = $? >> 8;
  close RESPWRITE;

  # for trouble shooting
  #&$writelog("callcommand: command = $command");
  #&$writelog("callcommand: close   = $close");
  #&$writelog("callcommand: exitval = $exitval");
  #print STDERR "callcommand: command = $command\n";
  #print STDERR "callcommand: close   = $close\n";
  #print STDERR "callcommand: exitval = $exitval\n";

  # command worked and returned zero?
  if ($close) {
    close RESPREAD;
    return 1;
  }

  # allowable return code?
  foreach my $okcode (@okcodes) {
    if ($exitval eq $okcode) {
      &$writelog("callcommand: ignored exit code $exitval from command");
      &$writelog("  command:  $command");
      close RESPREAD;
      return 1;
    }
  }

  # there was a problem
  if ($exitval ge 255) {
    &$writelog("callcommand: command invocation failed");
  } else {
    &$writelog("callcommand: command returned exit code: $exitval");
  }
  &$writelog("  command:  $command");
  # log the input text
  foreach my $line (@text) {
    &$writelog("  input:   $line");
  }
  # log the output from the command
  while (my $line = <RESPREAD>) {
    chomp($line);
    &$writelog("  output:  $line");
  }
  close RESPREAD;
  return '';
}

#####################################################
# check for remote address in service list
#####################################################
sub validip {

  # get IP address to check
  my $check_ip = shift;

  my $networks = $$conf{'networks'};

  # allow if no rules given
  return 1 if !defined($networks);

  # trim leading and trailing blanks
  if ($networks =~ /^\s*(.*?)\s*$/) {
    $networks = $1;
  }

  my $good_ip = 'no';
  my $bad_ip = 'no';

  # while more networks and no decision yet
  while ($networks ne '' && $good_ip eq 'no' && $bad_ip eq 'no') {

    # break off leading network
    $networks .= ' ';
    my $network;
    if ($networks =~ /^(.*?) (.*)$/) {
      $network = $1;
      $networks = $2;
    }

    # parse leading network 
    my $not = 'no';
    if ($network =~ /^\!(.*)$/) {
      $not = 'yes';
      $network = $1;
    }
    my $netmask = '255.255.255.255';
    if ($network =~ /^(.*?)\/(.*)$/) {
      $network = $1;
      $netmask = $2;
    }

    # do the check
    my $remote_ip_bin = inet_aton($check_ip);
    my $network_bin = inet_aton($network);
    my $netmask_bin = inet_aton($netmask);
    if ($network_bin && $netmask_bin) {
      if ($network_bin eq ($remote_ip_bin & $netmask_bin)) {
        if ($not eq 'yes') {
          $bad_ip = 'yes';
        } else {
          $good_ip = 'yes';
        }
      }
    }

    # trim leading and trailing blanks
    if ($networks =~ /^\s*(.*?)\s*$/) {
      $networks = $1;
    }
  }

  if ($good_ip eq 'yes') {
    return 1;
  } else {
    return '';
  }
}

#####################################################
# validate a domain name component
#####################################################
sub validdomcomp {
  my $str = shift;

  # alphanumerics, hyphens and dashes?
  if ($str =~ /^([A-Za-z0-9\-_]*)$/) {
    $str = $1;
  } else {
    $str = '';
  }

  return $str;
}

#####################################################
# validate a domain name
#####################################################
sub validdomain {
  my $str = shift;

  # remove any spaces from front and end
  if ($str =~ /^\s*(.*?)\s*$/) {
    $str = $1;
  }

  # remove any period from end
  while ($str =~ /^(.*)\.$/) {
    $str = $1;
  }

  # put period on end
  $str .= '.';

  # default result to pass back
  my $rslt = $str;

  # pull leading components off domain name until gone
  while ($str) {

    # split at first period
    my $sub;
    if ($str =~ /^(.*?)\.(.*)$/) {
      $sub = $1;
      $str = $2;
    }

    # vaild domain name component?
    validdomcomp($sub)
      or $rslt = $str = '';
  }

  return $rslt;
}

#####################################################
# validate an E-mail address
#####################################################
sub validemail {
  my $str = shift;

  # split at first "@"
  my $user = '';
  my $domain = '';
  if ($str =~ /^(.*?)@(.*)$/) {
    $user   = $1;
    $domain = $2;
  }

  # part after "@" valid domain?
  validdomain($domain) or return '';

  # part before "@" starts with letter?
  $user =~ /^([A-Za-z].*)$/ or return '';

  # valid
  return $str;
}

#####################################################
# validate a dot quad IP address
#####################################################
sub validdotquad {
  my $str = shift;

  # remove any spaces from front and end
  if ($str =~ /^\s*(.*?)\s*$/) {
    $str = $1;
  }

  # default result to pass back
  my $rslt = $str;

  # put period on end
  $str .= '.';

  # pull leading components off address until gone
  my $cnt = 0;
  while ($str) {

    # split at first period, or end of string
    my $sub;
    if ($str =~ /^(.*?)\.(.*)$/) {
      $sub = $1;
      $str = $2;
    }
    $cnt++;

    # one, two or three digits?
    next if $sub =~ /^[0-9]$/;
    next if $sub =~ /^[0-9][0-9]$/;
    next if $sub =~ /^[0-1][0-9][0-9]$/;
    next if $sub =~ /^2[0-4][0-9]$/;
    next if $sub =~ /^25[0-5]$/;

    # bad component
    $rslt = $str = '';
  }

  # 4 pieces?
  $rslt = $str = '' if $cnt ne 4;

  return $rslt;
}

#####################################################
# compare old and new user hash and do needed DNS
# changes
#####################################################
sub needDNSupdate {
  my $oldinfo = shift;
  my $newinfo = shift;

  # new and old domain names
  my $newdom = "$$newinfo{'username'}.$$newinfo{'domain'}";
  my $olddom = "$$oldinfo{'username'}.$$oldinfo{'domain'}";

  # TTL value
  my $TTL = 0;
  $TTL = $$conf{'TTL'} if $$conf{'TTL'};
  $TTL = $$conf{"TTL.$$newinfo{'domain'}"}
      if $$conf{"TTL.$$newinfo{'domain'}"};
  $TTL = $$conf{"TTL.$newdom"}
      if $$conf{"TTL.$newdom"};

  # collect nsupdate input an log messages;
  my @msg;
  my @oip;
  my @nip;
  my %ip;

  # subdomain name changed?
  if ($olddom ne $newdom) {

    # had an A record?
    if ($$oldinfo{'currentip'} ne '0.0.0.0') {
      push @oip, (
        "update delete $olddom. A");
      push @msg, ("Type A DNS record removed for user $olddom");
    }

    # needs an A record?
    if ($$newinfo{'currentip'} ne '0.0.0.0') {
      push @nip, (
        "update add $newdom. $TTL A $$oldinfo{'currentip'}");
      push @msg, ("Type A DNS record added for user $newdom");
    }

    # had a wildcard?
    if ($$oldinfo{'wildcard'} eq 'YES') {
      push @oip, (
        "update delete *.$olddom. CNAME");
      push @msg, ("Wildcard DNS record removed for user $olddom");
    }

    # needs a wildcard?
    if ($$newinfo{'wildcard'} eq 'YES') {
      push @nip, (
        "update add *.$newdom. $TTL CNAME $newdom.");
      push @msg, ("Wildcard DNS record added for user $newdom");
    }

    # had a primary MX?
    if ($$oldinfo{'MXvalue'}) {
      push @oip, (
        "update delete $olddom. MX 200 $$oldinfo{'MXvalue'}");
      push @msg, ("Primary MX DNS record removed for user $olddom");
    }

    # needs a primary MX?
    if ($$newinfo{'MXvalue'}) {
      push @nip, (
        "update add $newdom. $TTL MX 200 $$newinfo{'MXvalue'}");
      push @msg, ("Primary MX DNS record added for user $newdom");
    }

    # had a priority MX record?
    if ($$oldinfo{'MXbackup'} eq 'YES') {
      push @oip, (
        "update delete $olddom. MX 100 $olddom.");
      push @msg, ("Priority MX DNS record removed for user $olddom");
    }

    # needs a priority MX?
    if ($$newinfo{'MXbackup'} eq 'YES') {
        push @nip, (
          "update add $newdom. $TTL MX 100 $newdom.");
        push @msg, ("Priority MX DNS record added for user $newdom");
   }

  # subdomain has not changed
  } else {

    # add or delete an A record?
    if ($$oldinfo{'currentip'} ne $$newinfo{'currentip'}) {
      if ($$oldinfo{'currentip'} ne '0.0.0.0') {
        push @oip, (
          "update delete $olddom. A");
        push @msg, (
          "Type A DNS record for $$oldinfo{'currentip'} removed for user $olddom"
          );
      }
      if ($$newinfo{'currentip'} ne '0.0.0.0') {
        push @oip, (
          "update add $olddom. $TTL A $$newinfo{'currentip'}");
        push @msg, (
          "Type A DNS record for $$newinfo{'currentip'} added for user $olddom"
          );
      }
    }

    # add or delete wild card?
    if ($$oldinfo{'wildcard'} ne $$newinfo{'wildcard'}) {
      if ($$newinfo{'wildcard'} eq 'NO') {
        push @oip, (
          "update delete *.$olddom.");
        push @msg, ("Wildcard DNS record removed for user $olddom");
      } else {
        push @oip, (
          "update add *.$olddom. $TTL CNAME $olddom.");
        push @msg, ("Wildcard DNS record added for user $olddom");
      }
    }

    # add or delete a primary MX?
    if ($$newinfo{'MXvalue'} ne $$oldinfo{'MXvalue'}) {
      if ($$oldinfo{'MXvalue'}) {
        push @oip, (
          "update delete $olddom. MX 200 $$oldinfo{'MXvalue'}");
        push @msg, ("Primary MX DNS record for $$oldinfo{'MXvalue'} removed for user $olddom");
      }
      if ($$newinfo{'MXvalue'}) {
        push @oip, (
         "update add $olddom. $TTL MX 200 $$newinfo{'MXvalue'}");
        push @msg, ("Primary MX DNS record for $$newinfo{'MXvalue'} added for user $olddom");
      }
    }

    # add or delete an priority MX?
    if ($$newinfo{'MXbackup'} ne $$oldinfo{'MXbackup'}) {
      if ($$newinfo{'MXbackup'} eq 'NO') {
        push @oip, (
          "update delete $olddom. MX 100 $olddom.");
        push @msg, ("Priority MX DNS record removed for user $olddom");
      } else {
        push @oip, (
          "update add $olddom. $TTL MX 100 $olddom.");
        push @msg, ("Priority MX DNS record added for user $olddom");
      }
    }

  }

  # run nsupdate
  if ($$oldinfo{'domain'} eq $$newinfo{'domain'}) {
    push @oip, @nip if @nip;
    donsupdate($$oldinfo{'domain'}, @oip) if @oip;
  } else {
    donsupdate($$oldinfo{'domain'}, @oip) if @oip;
    donsupdate($$newinfo{'domain'}, @nip) if @nip;
  }

  writelog(@msg) if @msg;
}

#####################################################
# must return 1
#####################################################
1;

