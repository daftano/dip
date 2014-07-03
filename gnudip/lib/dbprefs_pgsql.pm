#####################################################
# dbprefs_pgsql.pm
#
# These routines handle the globalprefs and domains
# tables using PostgreSQL.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;

# global variables
use vars qw($conf);
use vars qw($dbprefs_pref $dbprefs_domains);

# common routines for preference handling
use dbprefs_cmn;

# GnuDIP core database subroutines
use dbcore;

#####################################################
# get preferences from database
#####################################################
sub getprefs {

  # allow persistance?
  return $dbprefs_pref 
    if $dbprefs_pref and
       $$conf{'persistance'} and
       $$conf{'persistance'} eq 'YES';

  my %prefhash;
  my $pref = \%prefhash;
  $dbprefs_pref = $pref;

  # read the table
  my $sth = dbexecute(qq*
    select param, value from globalprefs
    *);
  while (my ($param, $value) = $sth->fetchrow_array) {
    $param = '' if !defined($param);
    $value = '' if !defined($value);
    $$pref{$param} = $value;
  }
  $sth->finish;

  # ensure initialised
  setprefdflt($dbprefs_pref);

  return $pref;
}

#####################################################
# update preferences in database
#####################################################
sub updateprefs {
  my $pref = shift;
  dbexecute(qq*
    delete from globalprefs
    *);
  foreach my $param (prefscmnlist()) {
    dbexecute(qq*
      insert into globalprefs (
          param,
          value
         ) values (
          '$param',
          '$$pref{$param}'
         )
      *);
  }
}

#####################################################
# get all domains
#####################################################
sub getdomains {

  # mod_perl persistance?
  return $dbprefs_domains 
    if $dbprefs_domains and
       $$conf{'persistance'} and
       $$conf{'persistance'} eq 'YES';

  my $sth = dbexecute(qq*
    select id, domain, changepass, addself from domains
      order by id
    *);
  my @domains;
  while (my $dinfo = $sth->fetchrow_hashref) {
    setdomdflt($dinfo);
    push(@domains,($dinfo));
  }
  $sth->finish;

  $dbprefs_domains = \@domains;

  return $dbprefs_domains;
}

#####################################################
# get domain
#   this retrieval must be case insensitive!!
#   for SQL this is automatic
#####################################################
sub getdomain {
  my $domain = shift;
  my $sth = dbexecute(qq*
    select id, domain, changepass, addself from domains
      where domain = '$domain'
    *);
  my $dinfo = $sth->fetchrow_hashref;
  $sth->finish;
  setdomdflt($dinfo) if $dinfo;
  # enforce case sensitivity
  return undef
    if !$dinfo or
       $$dinfo{'domain'} ne $domain;
  return $dinfo;
}

#############################################################
# ensure all domain fields initialised
#############################################################
sub setdomdflt {
  my $dinfo = shift;
  $$dinfo{'domain'}     = '' if !defined($$dinfo{'domain'});
  $$dinfo{'changepass'} = '' if !defined($$dinfo{'changepass'});
  $$dinfo{'addself'}    = '' if !defined($$dinfo{'addself'});
}

#############################################################
# create domain
#############################################################
sub createdomain {
  my $domain     = shift;
  my $changepass = shift;
  my $addself    = shift;
  my $sth = dbexecute(qq*
    insert into domains (
        domain,
        changepass,
        addself
      ) values (
        '$domain',
        '$changepass',
        '$addself'
      )
    *);
  $sth->finish;
  # get back from database with "id"
  return getdomain($domain);
}

#############################################################
# update domain
#############################################################
sub updatedomain {
  my $dinfo = shift;
  my $sth = dbexecute(qq*
    update domains set
      domain     = '$$dinfo{'domain'}',
      changepass = '$$dinfo{'changepass'}',
      addself    = '$$dinfo{'addself'}'
    where
      id         =  $$dinfo{'id'}
    *);
  $sth->finish;
}

#############################################################
# delete domain
#############################################################
sub deletedomain {
  my $dinfo = shift;
  my $sth = dbexecute(qq*
    delete from domains where id = $$dinfo{'id'}
    *);
  $sth->finish;
}

#############################################################
# ensure all globalprefs fields initialised
#############################################################
sub setprefdflt {
  my $pref = shift;
  prefscmndflt($pref);
}

#####################################################
# must return 1
#####################################################
1;

