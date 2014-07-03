########################################################################
# gdipmaint.pm
#
# These routines are common to the command line user maintenance
# utilities and the remote user maintenance daemon.
#
# See COPYING for licensing information.
#
########################################################################

# Perl modules
use strict;

# global variables
use vars qw($conf);

# GnuDIP common subroutines
use gdiplib;
use dbusers;
use dbprefs;

#####################################################
# add a user to the database
# return codes:
# 0 - success
# 1 - user already exists
# 2 - configuration problem
#####################################################
sub maintadd {
  my $maintinfo = shift;

  my $username = $$maintinfo{'username'};
  my $domain   = $$maintinfo{'domain'};
  my $password = $$maintinfo{'password'};
     $password = '' if !defined($password);
  my $email    = $$maintinfo{'email'};
     $email    = '' if !defined($email);

  # user already exists?
  my $userinfo = getuser($username, $domain);
  if ($userinfo) {
    writelog("User \"$username.$domain\" already exists");
    return 1;
  }

  # user name valid?
  if (!validdomcomp($username)) {
    writelog("User name \"$username\" is not a valid domain name component");
    return 2;
  }

  # E-mail valid?
  if ($email and !validemail($email)) {
    writelog("E-mail address \"$email\" has invalid syntax");
    return 2;
  }

  # domain exists?
  my  $dominfo = getdomain($domain);
  if (! $dominfo) {
    if (!validdomain($domain)) {
      writelog("Domain name \"$domain\" is not valid");
      return 2;
    }
    # add domain to database
    createdomain($domain, 'NO', 'NO');
  }

  # create the user
  $password = md5_hex($password) if $password;
  createuser(
    $username,
    $domain,
    $password,
    'USER',
    $email
    );

  writelog("Added user \"$username.$domain\"");
  return 0;
}

#####################################################
# modify a user in the database
# return codes:
# 0 - success
# 1 - user does not exist
# 2 - configuration problem
#####################################################
sub maintmod {
  my $maintinfo = shift;

  my $username  = $$maintinfo{'username'};
  my $domain    = $$maintinfo{'domain'};
  my $password  = $$maintinfo{'hashedpw'};
     $password  = md5_hex($$maintinfo{'password'})
       if defined $$maintinfo{'password'};
     $password  = '' if ! defined($password);
  my $email     = $$maintinfo{'email'};
     $email     = '' if !defined($email);
  my $allowwild = $$maintinfo{'allowwild'};
     $allowwild = '' if !defined($allowwild);
  my $allowmx   = $$maintinfo{'allowmx'};
     $allowmx   = '' if !defined($allowmx);
  my $removedns = $$maintinfo{'removedns'};
     $removedns = '' if !defined($removedns);

  # get preferences from the database?
  my $pref;
  $pref = getprefs() if $allowmx or $allowmx;

  # user exists?
  my $userinfo = getuser($username, $domain);
  if (! $userinfo) {
    writelog("User \"$username.$domain\" does not exist");
    return 1;
  }

  # save for DNS routine
  my %userhash = %$userinfo;
  my $oldinfo  = \%userhash;

  # E-mail valid?
  if ($email) {
    if (!validemail($email)) {
      writelog("E-mail address \"$email\" has invalid syntax");
      return 2;
    }
    $$userinfo{'email'} = $email;
  }

  # allowwild valid?
  if ($allowwild) {
    if ($$pref{'ALLOW_WILD'} ne 'USER') {
      writelog("Per user access to wild card is not enabled");
      return 2;
    }
    if ($allowwild ne 'YES' and $allowwild ne 'NO') {
      writelog("Allow wild card option must be \"YES\" or \"NO\"");
      return 2;
    }
    $$userinfo{'allowwild'} = $allowwild;
    if ($allowwild eq 'NO') {
      $$userinfo{'wildcard'} = 'NO';
    }
  }

  # allowmx valid?
  if ($allowmx) {
    if ($$pref{'ALLOW_MX'} ne 'USER') {
      writelog("Per user access to MX is not enabled");
      return 2;
    }
    if ($allowmx ne 'YES' and $allowmx ne 'NO') {
      writelog("Allow MX option must be \"YES\" or \"NO\"");
      return 2;
    }
    $$userinfo{'allowmx'} = $allowmx;
    if ($allowmx eq 'NO') {
      $$userinfo{'MXvalue'}  = '';
      $$userinfo{'MXbackup'} = 'NO';
    }
  }

  # password provided?
  $$userinfo{'password'} = $password  if defined $password;

  # remove all DNS information for user?
  if ($removedns) {
    if ($removedns ne 'YES') {
      writelog("Remove DNS must be \"YES\"");
      return 2;
    }
    $$userinfo{'currentip'} = '0.0.0.0';
    $$userinfo{'wildcard'} = 'NO';
    $$userinfo{'MXbackup'} = 'NO';
    $$userinfo{'MXvalue'}  = '';
  }

  # send updates to DNS server?
  needDNSupdate($oldinfo, $userinfo) if $$userinfo{'level'} ne 'ADMIN';

  # update database
  updateuser($userinfo);

  writelog("Updated user \"$username.$domain\"");
  return 0;
}

#####################################################
# delete a user from the database
# return codes:
# 0 - success
# 1 - user does not exist
# 2 - configuration problem
#####################################################
sub maintdel {
  my $maintinfo = shift;

  my $username = $$maintinfo{'username'};
  my $domain   = $$maintinfo{'domain'};

  # user exists?
  my $userinfo = getuser($username, $domain);
  if (! $userinfo) {
    writelog("User \"$username.$domain\" does not exist");
    return 1;
  }

  # send updates to DNS server?
  if (! callnsupdate(
      $$userinfo{'domain'},
      "update delete   $$userinfo{'username'}.$$userinfo{'domain'}.",
      "update delete *.$$userinfo{'username'}.$$userinfo{'domain'}.")) {
    writelog("Removal of \"$username.$domain\" from DNS failed");
    return 2;
  }

  # update database
  deleteuser($userinfo);

  writelog(
    "User \"$username.$domain\" has been deleted and removed from DNS"
    );
  return 0;
}

#####################################################
# get a user from the database
# return codes:
# 0 - success
# 1 - user does not exist
# 2 - configuration problem
#####################################################
sub maintget {
  my $maintinfo = shift;
  my $response  = shift;

  my $username = $$maintinfo{'username'};
  my $domain   = $$maintinfo{'domain'};

  # user exists?
  my $userinfo = getuser($username, $domain);
  if (! $userinfo) {
    writelog("User \"$username.$domain\" does not exist");
    return 1;
  }

  # "dump" it
  while (my ($param, $value) = each %$userinfo) {
    $value = '' if ! defined $value;
    $$response .= "$param = $value\n"
      if $param ne 'createdate'  and
         $param ne 'id'          and
         $param ne 'updated_secs';
  }

  writelog("Retrieved user \"$username.$domain\"");
  return 0;
}

#####################################################
# must return 1
#####################################################
1;

