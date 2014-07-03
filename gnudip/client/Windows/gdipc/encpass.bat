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
# encpass.pl
#
# This script takes a plain text password
# provided as an argument, encrypts it and
# prints it.
#
# See COPYING for licensing information
#
#####################################################

# PERL packages and options
use warnings;
use strict;
use FindBin;

# try for compiled MD5, otherwise use pure Perl
BEGIN {
  eval {
    require Digest::MD5;
    import Digest::MD5 'md5_hex'
  };
  if ($@) { # ups, no Digest::MD5
    # get path to our parent directory
    my $binpath = $FindBin::Bin;
    my $gnudipdir = '';
    if ($binpath =~ /(.*)\/.+?/) {
      $gnudipdir = $1;
    }
    require $gnudipdir . '/lib/Digest/Perl/MD5.pm';
    import Digest::Perl::MD5 'md5_hex'
  }             
}

# get program name
my $pgm = $0;
if ($pgm =~ /^.*\/(.+?)$/) {
  $pgm = $1;
}

sub usage {
  print STDOUT "usage: $pgm password\n";
  print STDERR "usage: Encrypt a plain text password.\n";
  exit;
}
if (@ARGV ne 1) {
  usage();
}

my $plainpass = shift;
my $encpass = md5_hex($plainpass);
print "$encpass\n";


__END__
:endofperl
