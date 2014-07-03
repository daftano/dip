#!/usr/bin/perl
#####################################################
# gdipdbcnv.pl
#
# This script generates mySQL statements needed
# complete the conversion of an earlier GnuDIP
# mySQL database.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;
use DBD::mysql;

# process command line
sub usage {
  print STDERR <<"EOQ";
usage: gdipdbcnv.pl gnudipdatabase gnudipserver gnudipuser gnudippass
EOQ
}
if (@ARGV ne 4) {
  usage();
  exit 1;
}
my $gnudipdatabase = $ARGV[0];
my $gnudipserver   = $ARGV[1];
my $gnudipuser     = $ARGV[2];
my $gnudippass     = $ARGV[3];

# use GnuDIP database
tpr(qq*
######################################
# use GnuDIP database

use $gnudipdatabase;

*);

# connect to mySQL
my $dbh = DBI->connect(
  "DBI:mysql:$gnudipdatabase:$gnudipserver", $gnudipuser, $gnudippass)
  || die "Could not connect to database\n";
my $sth;

# get preferences from the database
my $pref = getprefs($dbh);

# get list of domains
my @domains = ();
# pre 2.3 with domain in globalprefs?
if ($$pref{'GNUDIP_DOMAIN'}) {
  my %domain;
  $domain{'domain'}     = $$pref{'GNUDIP_DOMAIN'};
  $domain{'changepass'} = $$pref{'ALLOW_CHANGE_PASS'};
  $domain{'addself'}    = $$pref{'ADD_SELF'};
  push(@domains, (\%domain));
}
# get from domains table
$sth = $dbh->prepare(
  "select domain, changepass, addself from domains order by id"
  );
$sth->execute;
while (my $domain = $sth->fetchrow_hashref) {
  push(@domains, ($domain));
}
$sth->finish;

# need to fix pre 2.3 database with domain in globalprefs?
if ($$pref{'GNUDIP_DOMAIN'}) {
  tpr(qq*
######################################
# domains

delete from domains;
*);
  foreach my $domain (@domains) {
    tpr(qq*
insert into domains set
  domain     = '$$domain{'domain'}',
  changepass = '$$domain{'changepass'}',
  addself    = '$$domain{'addself'}'
*);
  }
  tpr(qq*

*);
}

# need to fix pre 2.2 database with global domain?
if ($$pref{'DOMAIN_TYPE'} and
    $$pref{'DOMAIN_TYPE'} eq 'GLOBAL' and
    $$pref{'GNUDIP_DOMAIN'}) {
  tpr(qq*
######################################
# users

*);

  # for each non-ADMIN user entry with an empty domain ...
  my $columns =
    'id, username, password, email, createdate, ' .
    'forwardurl, updated, currentip, autourlon, MXvalue, ' .
    'MXbackup, wildcard, allowwild, allowmx';
  $sth = $dbh->prepare(
    "select $columns from users where domain = '' and level <> 'ADMIN'");
  $sth->execute;
  while (my (
    $id, $username, $password, $email, $createdate, 
    $forwardurl, $updated, $currentip, $autourlon, $MXvalue,
    $MXbackup, $wildcard, $allowwild, $allowmx
    ) = $sth->fetchrow_array) {

    # the current row gets the "global" domain
    tpr(qq*
update user where id = '$id' set
  domain = '$$pref{'GNUDIP_DOMAIN'}';
*);

    # then generate another row for each additional domain
    foreach my $domain (@domains) {
      tpr(qq*
insert into users set
  username   = '$username',
  password   = '$password',
  domain     = '$$domain{'domain'}',
  email      = '$email',
  createdate = '$createdate',
  forwardurl = '$forwardurl',
  updated    = '$updated',
  level      = 'USER',
  currentip  = '$currentip',
  autourlon  = '$autourlon',
  MXvalue    = '$MXvalue',
  MXbackup   = '$MXbackup',
  wildcard   = '$wildcard',
  allowwild  = '$allowwild',
  allowmx    = '$allowmx';
*);
    }
  }
}

exit;

#####################################################
# subroutines
#####################################################

#####################################################
# get preferences from database
#####################################################
sub getprefs {
  my $dbh = shift;
  my %PREF;
  my $sth = $dbh->prepare("select param, value from globalprefs");
  $sth->execute;
  while (my ($param, $value) = $sth->fetchrow_array) {
    $PREF{$param} = $value;
  }
  $sth->finish;
  return \%PREF;
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

