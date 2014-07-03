########################################################################
# gdipmailchk.pm
#
# These routines are used by the GnuDIP web interface to prevent robots
# from having GnuDIP send E-mail.
#
# See COPYING for licensing information.
#
########################################################################

# Perl modules
use strict;

# global variables
use vars qw($conf $pref $reqparm $thiscgi);

# GnuDIP common subroutines
use gdiplib;
use gdipcgi_cmn;
use htmlgen;

########################################################################
# generate HTML for inclusion in a page
########################################################################
sub mchk_html {

  return if $$pref{'NO_ROBOTS'} and $$pref{'NO_ROBOTS'} eq 'NO';

  # generate random string and signature
  my $sign = nrb_write();
  return if ! $sign;

  # generate the HTML
  tpr(qq*
<input type="hidden" name="image_signature" value="$sign">
<p>
<center>
Text From Image Below: <input type="text" name="image_text">
<p>
<table border=1><tr><td>
<img align=middle
  src="$thiscgi?mailcheck=$sign"
  alt="No Robots Image"
  border=0 height=30 width=190
>
</td></tr></table>
</center>
<p>
*);
}

#######################################################################
# generate and return image
#######################################################################
sub pg_mchk_img {

  default_empty('mailcheck');

  # command to generate image
  my $imgcmd = $$conf{'no_robots_imgcmd'};
  $imgcmd = '/usr/local/gnudip/sbin/textimage.sh'
    if ! $imgcmd;

  # prefix for any temporary files
  my $prefix = nrb_filename($$reqparm{'mailcheck'});

  # retrieve string
  my $string = nrb_read($$reqparm{'mailcheck'});
  if (! $string) {
    pg_msg(qq*
Error: No E-mail Pending
*,qq*
There is no E-mail pending for this page.
*)
  }

  # readable fork to generate image
  my $pid = open(CMD, "-|");
  if (! defined $pid) {
    writelog('pg_mchk_img: open failed');
    bad_config();
  }
  if ($pid eq 0) {
    # child
    # to placate "-T" - trust path and arguments
    my $path = $ENV{PATH};
    if ($path =~ /^(.*)$/) {
      $path = $1;
    }
    $ENV{PATH} = $path;
    if ($imgcmd =~ /^(.*)$/) {
      $imgcmd = $1;
    }
    if ($string =~ /^(.*)$/) {
      $string = $1;
    }
    if ($prefix =~ /^(.*)$/) {
      $prefix = $1;
    }
    # for FCGI.pm compatibility
    untie *STDOUT;
    # pass control to command
    my $ok = exec {$imgcmd} $imgcmd, $string, $prefix;
    if (! $ok) {
      # should not have come back!
      # exit, bypassing Perl
      POSIX::_exit 255;
    }
  }
  # parent

  # retrieve output
  my $imagedata = '';
  while (my $moredata = <CMD>) {
    $imagedata .= $moredata;
  }

  # close it
  my $close = close CMD;
  my $sysmsg  = $!;
  my $exitval = $? >> 8;

  # no image data?
  if (! $imagedata) {
    writelog("pg_mchk_img: no image returned - $imgcmd $string $prefix");
    writelog("pg_mchk_img: close failed - $imgcmd $string $prefix - $sysmsg")
      if !$close and $sysmsg;
    writelog("pg_mchk_img: exit code $exitval - $imgcmd $string $prefix")
      if $exitval ne 0;
    bad_config();
  }

  # pump out the image
  print STDOUT $imagedata;

  exit;
}

########################################################################
# check response
########################################################################
sub mchk_check {

  return if $$pref{'NO_ROBOTS'} and $$pref{'NO_ROBOTS'} eq 'NO';

  default_empty('image_signature');
  default_empty('image_text');

  # have a signature?
  pg_error('bad_request') if ! $$reqparm{'image_signature'};

  # retrieve string
  my $string = nrb_read($$reqparm{'image_signature'});
  if (! $string) {
    pg_msg(qq*
Error: No E-mail Pending
*,qq*
There is no E-mail pending for this page.
*)
  }

  # check response
  if ($string ne $$reqparm{'image_text'}) {
    pg_msg(qq*
Error: Robot Test Failed
*,qq*
You did not correctly enter the character string contained in the image.
*);
  }

  # remove file
  unlink nrb_filename($$reqparm{'image_signature'});
}

########################################################################
# state management local routines
########################################################################

sub nrb_write {

  # generate random string and signature
  my @chars = ('a' .. 'z');
  my $string = '';
  for (my $charcount = 0; $charcount < 10; $charcount++) {
    $string .= $chars[ rand @chars ];
  }
  my $sign = md5_hex($string.$$pref{'SERVER_KEY'});

  # file name
  my $statefile = nrb_filename($sign);
  return '' if ! $statefile;

  # write over file
  local *STATE;
  if (! open (STATE, ">$statefile")) {
    writelog("mchk_html: cannot open $statefile: $!");
    return '';
  }
  print STATE $string;
  close STATE;

  # restrict permissions
  chmod 0600, ($statefile);

  return $sign;
}

sub nrb_read {
  my $sign = shift;
  return '' if ! $sign;

  # file name
  my $statefile = nrb_filename($sign);
  return '' if ! $statefile;

  # file exists?
  return '' if ! -f $statefile;

  # read it
  local *STATE;
  if (! open (STATE, "<$statefile")) {
    writelog("mchk_html: cannot open $statefile: $!");
    return '';
  }
  read(STATE, my $string, 100);
  close STATE;

  return $string;
}

sub nrb_filename {
  my $sign = shift;
  return '' if ! $sign;
  my $prefix = $$conf{'no_robots_prfx'};
  $prefix = '/tmp/gdipnrb_' if ! $prefix;
  return $prefix . $sign;
}

#####################################################
# must return 1
#####################################################
1;

