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

# This script sends a TCP packet to nowhere and doesn't wait
# for a response. The packet should not leave your ISP's routers.
# It will get dropped. Try the address you choose with traceroute
# to be sure.

# Run this as infrequently as possible to keep your connection from
# dropping due to inactivity. The objective is to have minimal impact.

# set address
my $address;
# sample reserved addresses
# - see http://www.iana.org/assignments/ipv4-address-space
$address = '197.0.0.1';
#$address = '219.0.0.1';
#$address = '220.0.0.1';
#$address = '221.0.0.1';
#$address = '222.0.0.1';
#$address = '223.0.0.1';
# sample private addresses
# - see http://ietf.org/rfc/rfc1918.txt
#$address = '172.16.1.1';
#$address = '10.1.1.1';
#$address = '192.168.1.1';

# set port
my $port;
$port = 7; # "echo"

# Perl modules
use warnings;
use strict;
use Socket;

# do the connect in a child process
my $pid = fork;
if (!defined($pid)) {
  die "fork failed\n";
}
if ($pid eq 0) {
  # child - connect
  socket(PING, PF_INET, SOCK_STREAM, getprotobyname('tcp')) || die;
  connect(PING, sockaddr_in($port, inet_aton($address)));
  close PING;
}; 
# parent

#wait 1 second
my $secs = 1;
select(undef,  undef, undef, $secs);

# kill the child
kill(9, $pid);


__END__
:endofperl
