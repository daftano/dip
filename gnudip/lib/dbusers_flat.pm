#####################################################
# dbusers_flat.pm
#
# These routines handle the users "table" using flat
# files.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;
use POSIX qw(strftime);

#############################################################
# get multiple users
#############################################################

# initialise for getuserseach - all users
sub getusers {
  return getusersglob('*', '*');
}

# initialise for getuserseach - by domain
sub getusersdomain {
  my $domain = shift;
  return getusersglob('*', $domain);
}

# initialise for getuserseach - by age in days
sub getusersolder {
  my $days = shift;

  # directory for user files
  my $usersdir = $$conf{'users_dir'};
  $usersdir = "$gnudipdir/run/database/users" if ! $usersdir;

  # open directory
  local *USERSDIR;
  if (! opendir (USERSDIR, "$usersdir")) {
    writelog("getusersolder: cannot open $usersdir: $!");
    dberror();
  }

  # find files (users) old enough
  my @users;
  while (my $id = readdir USERSDIR) {
    next if $id eq '.' or $id eq '..';
    my $age = -M "$usersdir/$id";
    push @users, (getuserbyid($id)) if $age >= $days;
  }
  closedir USERSDIR;

  return \@users;
}

# initialise for getuserseach - matching pattern
sub getuserspattern {
  my $user_pattern = shift;
  my $sortby       = shift;
  my $order        = shift;
  $user_pattern = '*' if !$user_pattern;

  $sortby = 'username' if !$sortby;
  $order  = 'asc'      if !$order;
  $order  = 'asc'      if $order ne 'desc';

  my $baseusers = getusersglob($user_pattern, '*');

  # sort the users
  my @users = sort {
      if ($order eq 'asc') {
        return $$a{$sortby} cmp $$b{$sortby};
      } else {
        return $$b{$sortby} cmp $$a{$sortby};
      }
    } @$baseusers;

  return \@users;
}

# initialise for getuserseach routine
sub getusersglob {
  my $username = shift;
  my $domain   = shift;

  # massage template into valid Perl regular expression
  my $check = "$username.$domain";
  $check =~ s/\*/\(\.\*\)/g;
  $check =~ s/\?/\(\.\)/g;

  # directory for user files
  my $usersdir = $$conf{'users_dir'};
  $usersdir = "$gnudipdir/run/database/users" if ! $usersdir;

  # open directory
  local *USERSDIR;
  if (! opendir (USERSDIR, "$usersdir")) {
    writelog("getusersglob: cannot open $usersdir: $!");
    dberror();
  }

  # find files (users) that match
  my @users;
  while (my $id = readdir USERSDIR) {
    next if $id eq '.' or $id eq '..';
    if ($id =~ /^$check$/){
      push @users, (getuserbyid($id));
    }
  }
  closedir USERSDIR;

  return \@users;
}

# get next user
sub getuserseach {
  my $users = shift;
  my $user;
  $user = shift @$users if $users;
  return $user;
}

#############################################################
# get user
#   this retrieval must be case insensitive!!
#############################################################
sub getuser {
  my $username = shift;
  my $domain = shift;
  return getuserbyid(lc("$username.$domain"));
}

#############################################################
# get user by id
#############################################################
sub getuserbyid {
  my $id = shift;

  # directory for user files
  my $usersdir = $$conf{'users_dir'};
  $usersdir = "$gnudipdir/run/database/users" if ! $usersdir;

  # file for this user
  my $userfile = "$usersdir/$id";

  # file exists?
  if (! -f $userfile) {
    return undef;
  }

  # read the file
  local *USER;
  if (! open (USER, "<$userfile")) {
    writelog("getuserbyid: cannot open $userfile: $!");
    dberror();
  }
  read(USER, my $data, 5000);
  close USER;

  # reference to user hash
  my %user;
  my $uinfo = \%user;

  # parse the user string
  foreach my $line (split(/\n/, $data)) {
    if ($line =~ /^\s*(\w[-\w|\.]*)\s*=\s*(.*?)\s*$/) {
      $$uinfo{$1} = $2;
    }
  }

  # set id
  $$uinfo{'id'} = $id;

  # show update date in mySQL format
  $$uinfo{'updated'} = getdatetime($$uinfo{'updated_secs'});

  # ensure initialised
  setusrdflt($uinfo);

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
      "createuser: user $username in domain $domain already exists");
    dberror();
  }

  # initialise user hash
  my %user;
  my $uinfo = \%user;
  $$uinfo{'username'}   = $username;
  $$uinfo{'domain'}     = $domain;
  $$uinfo{'password'}   = $password;
  $$uinfo{'level'}      = $level;
  $$uinfo{'email'}      = $email;

  # load the user
  loaduser($uinfo);

  # get back from database with "id"
  return getuser($username, $domain);
}

#############################################################
# load user
#############################################################
sub loaduser {
  my $uinfo = shift;

  # already exists?
  return ''
    if getuser($$uinfo{'username'}, $$uinfo{'domain'});

  # create "id"
  $$uinfo{'id'} = lc("$$uinfo{'username'}.$$uinfo{'domain'}");

  # ensure fields all initialised
  setusrdflt($uinfo);

  # update
  updateuser($uinfo, $$uinfo{'updated_secs'});

  return 1;
}

#############################################################
# update user
#############################################################
sub updateuser {
  my $uinfo        = shift;
  my $updated_secs = shift;

  # change the time last updated?
  if (! $updated_secs) {
    $$uinfo{'updated_secs'} = time();
    # show update date in mySQL format
    $$uinfo{'updated'} = getdatetime($$uinfo{'updated_secs'});
  }

  # create "id"
  my $id = lc("$$uinfo{'username'}.$$uinfo{'domain'}");
  # trust it
  if ($id =~ /^(.*)$/) {
    $id = $1;
  }

  # id/file name will change?
  if ($id ne $$uinfo{'id'}) {
    deleteuser($uinfo);
    $$uinfo{'id'} = $id;
  }

  # construct user string
  my $data = '';
  $data .= "username = $$uinfo{'username'}\n";
  $data .= "password = $$uinfo{'password'}\n";
  $data .= "domain = $$uinfo{'domain'}\n";
  $data .= "email = $$uinfo{'email'}\n";
  $data .= "forwardurl = $$uinfo{'forwardurl'}\n";
  $data .= "updated_secs = $$uinfo{'updated_secs'}\n";
  $data .= 'updated = ' . getdatetime($$uinfo{'updated_secs'}) . "\n";
  $data .= "level = $$uinfo{'level'}\n";
  $data .= "currentip = $$uinfo{'currentip'}\n";
  $data .= "autourlon = $$uinfo{'autourlon'}\n";
  $data .= "MXvalue = $$uinfo{'MXvalue'}\n";
  $data .= "wildcard = $$uinfo{'wildcard'}\n";
  $data .= "MXbackup = $$uinfo{'MXbackup'}\n";
  $data .= "allowwild = $$uinfo{'allowwild'}\n";
  $data .= "allowmx = $$uinfo{'allowmx'}\n";

  # directory for user files
  my $usersdir = $$conf{'users_dir'};
  $usersdir = "$gnudipdir/run/database/users" if ! $usersdir;

  # file for this user
  my $userfile = "$usersdir/$id";

  # write over file
  local *USER;
  if (! open (USER, ">$userfile")) {
    writelog("updateuser: cannot open $userfile: $!");
    dberror();
  }
  print USER $data;
  close USER;

  # set access and update time?
  utime(
    $$uinfo{'updated_secs'},
    $$uinfo{'updated_secs'},
    $userfile)
      if $updated_secs;

  # restrict permissions
  chmod 0600, ($userfile);
}

#############################################################
# delete user
#############################################################
sub deleteuser {
  my $uinfo = shift;

  # directory for user files
  my $usersdir = $$conf{'users_dir'};
  $usersdir = "$gnudipdir/run/database/users" if ! $usersdir;

  # file for this user
  my $userfile = "$usersdir/$$uinfo{'id'}";

  # trust it
  if ($userfile =~ /^(.*)$/) {
    $userfile = $1;
  }

  # delete it
  if (! unlink $userfile) {
    writelog("deleteuser: could not delete $userfile: $!");
    dberror();   
  }
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
  $$uinfo{'updated'}      = getdatetime($$uinfo{'updated_secs'});
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
# convert time in seconds to mysql format
#####################################################
sub getdatetime {
  my $secs = shift;
  return strftime("%Y-%m-%d %H:%M:%S", localtime($secs));
}

#####################################################
# must return 1
#####################################################
1;

