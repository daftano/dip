#####################################################
# dbusers_mysql.pm
#
# These routines handle the users "table" using
# MySQL.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;

# GnuDIP core database subroutines
use dbcore;

#############################################################
# get multiple users
#############################################################

# initialize for getuserseach - all users
sub getusers {
  return getuserwhere();
}

# initialize for getuserseach - by domain
sub getusersdomain {
  my $domain = shift;
  return getuserwhere(qq*
    where domain = "$domain"
    *);
}

# initialize for getuserseach - by age in days
sub getusersolder {
  my $days = shift;
  return getuserwhere("
    where
      domain != '' and
      to_days(updated) + $days <= to_days(curdate())
    ");
}

# initialize for getuserseach - matching pattern
sub getuserspattern {
  my $user_pattern = shift;
  my $sortby       = shift;
  my $order        = shift;

  $sortby = 'username' if !$sortby;
  $order  = 'asc'      if !$order;
  $order  = 'asc'      if $order ne 'desc';

  my $where = '';
  if ($user_pattern) {
    # change match characters to the ones mySQL uses
    $user_pattern =~ s/\*/\%/g;
    $user_pattern =~ s/\?/\_/g;
    $where = "where username LIKE \"$user_pattern\"";
  }

  return getuserwhere(qq*
    $where order by $sortby $order
    *);
}

# get next user
sub getuserseach {
  my $sth = shift;
  if (my $uinfo = $sth->fetchrow_hashref) {
    setusrdflt($uinfo);
    return $uinfo;
  }
  $sth->finish;  
  return undef;
}

#############################################################
# get user by name and domain
#   this retrieval must be case insensitive!!
#   for mySQL this is automatic
#############################################################
sub getuser {
  my $username = shift;
  my $domain = shift;
  my $sth = getuserwhere(qq*
    where
      username = "$username" and domain = "$domain"
    *);
  my $uinfo = $sth->fetchrow_hashref;
  $sth->finish;
  setusrdflt($uinfo) if $uinfo;
  return $uinfo;
}

#############################################################
# get user by id
#############################################################
sub getuserbyid {
  my $id = shift;
  my $sth = getuserwhere(qq*
    where
      id = "$id"
    *);
  my $uinfo = $sth->fetchrow_hashref;
  $sth->finish;
  setusrdflt($uinfo) if $uinfo;
  return $uinfo;
}

#############################################################
# create user
#############################################################
sub createuser {
  my $username = shift;
  my $domain   = shift;
  my $password = shift;
  my $level    = shift;
  my $email    = shift;

  # already exists?
  if (getuser($username, $domain)) {
    writelog(
      "createuser: user $username in domain $domain already exists\n");
    dberror();
  }

  my %user;
  my $uinfo = \%user;

  $$uinfo{'username'}   = $username;
  $$uinfo{'domain'}     = $domain;
  $$uinfo{'password'}   = $password;
  $$uinfo{'level'}      = $level;
  $$uinfo{'email'}      = $email;

  loaduser($uinfo);
  # get back from database with "id"
  return getuser($username, $domain);
}

#############################################################
# get user(s) where ...
#############################################################
sub getuserwhere {
  my $where = shift;
  $where = '' if !defined $where;

  my $sth = dbexecute(qq*
    select 
      id, username, domain, password, email,
      forwardurl, updated, level, currentip, autourlon,
      MXvalue, MXbackup, wildcard, allowwild, allowmx,
      UNIX_TIMESTAMP(updated) as updated_secs
    from users $where
    *);

  return $sth;
}

#############################################################
# load user
#############################################################
sub loaduser {
  my $uinfo = shift;

  return ''
    if getuser($$uinfo{'username'}, $$uinfo{'domain'});

  # ensure fields all initialised
  setusrdflt($uinfo);

  my $sth = dbexecute(qq*
    insert into users set
      username   = "$$uinfo{'username'}",
      domain     = "$$uinfo{'domain'}",
      password   = "$$uinfo{'password'}",
      email      = "$$uinfo{'email'}",
      createdate = NOW(),
      forwardurl = "$$uinfo{'forwardurl'}",
      updated    = FROM_UNIXTIME($$uinfo{'updated_secs'}),
      level      = "$$uinfo{'level'}",
      currentip  = "$$uinfo{'currentip'}",
      autourlon  = "$$uinfo{'autourlon'}",
      MXvalue    = "$$uinfo{'MXvalue'}",
      MXbackup   = "$$uinfo{'MXbackup'}",
      wildcard   = "$$uinfo{'wildcard'}",
      allowwild  = "$$uinfo{'allowwild'}",
      allowmx    = "$$uinfo{'allowmx'}"
    *);
  $sth->finish;
  return 1;
}

#############################################################
# update user
#############################################################
sub updateuser {
  my $uinfo = shift;
  my $sth = dbexecute(qq*
    update users set
      username   = "$$uinfo{'username'}",
      domain     = "$$uinfo{'domain'}",
      password   = "$$uinfo{'password'}",
      email      = "$$uinfo{'email'}",
      forwardurl = "$$uinfo{'forwardurl'}",
      updated    = NOW(),
      level      = "$$uinfo{'level'}",
      currentip  = "$$uinfo{'currentip'}",
      autourlon  = "$$uinfo{'autourlon'}",
      MXvalue    = "$$uinfo{'MXvalue'}",
      MXbackup   = "$$uinfo{'MXbackup'}",
      wildcard   = "$$uinfo{'wildcard'}",
      allowwild  = "$$uinfo{'allowwild'}",
      allowmx    = "$$uinfo{'allowmx'}"
    where
      id         = "$$uinfo{'id'}"
    *);
  $sth->finish;
}

#############################################################
# delete user
#############################################################
sub deleteuser {
  my $uinfo = shift;
  my $sth = dbexecute(qq*
    delete from users where id = "$$uinfo{'id'}"
    *);
  $sth->finish;
}

#############################################################
# ensure all user fields initialised
#############################################################
sub setusrdflt {
  my $uinfo = shift;
  $$uinfo{'username'}     = ''        if ! defined $$uinfo{'username'};
  $$uinfo{'password'}     = ''        if ! defined $$uinfo{'password'};
  $$uinfo{'domain'}       = ''        if ! defined $$uinfo{'domain'};
  $$uinfo{'email'}        = ''        if ! defined $$uinfo{'email'};
  $$uinfo{'forwardurl'}   = ''        if ! defined $$uinfo{'forwardurl'};
  $$uinfo{'updated_secs'} = time()    if ! defined $$uinfo{'updated_secs'};
  $$uinfo{'updated'}      = ''        if ! defined $$uinfo{'updated'};
  $$uinfo{'level'}        = 'USER'    if ! $$uinfo{'level'};
  $$uinfo{'currentip'}    = '0.0.0.0' if ! $$uinfo{'currentip'};
  $$uinfo{'autourlon'}    = ''        if ! defined $$uinfo{'autourlon'};
  $$uinfo{'MXvalue'}      = ''        if ! defined $$uinfo{'MXvalue'};
  $$uinfo{'wildcard'}     = 'NO'      if ! $$uinfo{'wildcard'};
  $$uinfo{'MXbackup'}     = 'NO'      if ! $$uinfo{'MXbackup'};
  $$uinfo{'allowwild'}    = 'NO'      if ! $$uinfo{'allowwild'};
  $$uinfo{'allowmx'}      = 'NO'      if ! $$uinfo{'allowmx'};
}

#####################################################
# must return 1
#####################################################
1;

