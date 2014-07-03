########################################################################
# doreq.pm
#
# These routines handle HTTP requests that are not
# just to display a page.
#
# See COPYING for licensing information.
#
########################################################################

# Perl modules
use strict;
use Socket;

# global variables
use vars qw($conf);
use vars qw($pref $userinfo $dominfo $remote_ip);
use vars qw($reqparm $thiscgi $thishost);

# GnuDIP common subroutines
use gdiplib;
use gdipcgi_cmn;
use htmlgen;
use mailgen;
use gdipmailchk;

########################################################################
# NOTE
# Each pg_? routine generates a page and does an "exit".
# So they DO NOT RETURN.
########################################################################

########################################################################
# self registration
########################################################################
sub do_self {

  # check a valid domain is specified
  pg_error('no_domain') if !$$reqparm{'new_domain'};
  $dominfo = getdomain($$reqparm{'new_domain'});
  pg_error('unknown_dom') if !$dominfo;

  # this domain allows addself?
  pg_error('no_domaddself') if $$dominfo{'addself'} eq 'NO';

  # check syntax of new user name
  pg_error('no_username') if !$$reqparm{'new_username'};
  pg_error('bad_username') if !validdomcomp($$reqparm{'new_username'});

  # restricted user?
  chkrestrict($$reqparm{'new_username'});

  # check syntax of passwords
  pg_error('no_password') if !$$reqparm{'new_password'};
  pg_error('no_password') if !$$reqparm{'new_password1'};
  pg_error('not_same')
    if $$reqparm{'new_password'} ne $$reqparm{'new_password1'};

  # check already exists?
  $userinfo = getuser($$reqparm{'new_username'}, $$reqparm{'new_domain'});
  pg_error('user_exists') if $userinfo;

  # check for admin by same name
  $userinfo = getuser($$reqparm{'new_username'}, '');
  pg_error('restricted_user') if $userinfo;

  default_empty('new_email');

  # don't have to send E-mail?
  if ($$pref{'REQUIRE_EMAIL'} ne 'YES') {
    $userinfo = createuser(
       $$reqparm{'new_username'},
       $$reqparm{'new_domain'},
       md5_hex($$reqparm{'new_password'}),
       'USER',
       $$reqparm{'new_email'},
      );
    writelog(
      "User $$reqparm{'new_username'}.$$reqparm{'new_domain'} self registered"
      );
    pg_didself();
  }

  pg_error('no_email')  if $$reqparm{'new_email'} eq '';
  pg_error('bad_email') if !validemail($$reqparm{'new_email'});

  # check not a robot
  mchk_check();

  mail_self(
      $$reqparm{'new_username'},
      $$reqparm{'new_domain'},
      md5_hex($$reqparm{'new_password'}),
      $$reqparm{'new_email'},
      );

  pg_selfemail($$reqparm{'new_email'});
}    

########################################################################
# self registration after E-mail sent
########################################################################
sub do_selfcreate {

  # self registration allowed?
  pg_error('no_addself') if $$pref{'ADD_SELF'} ne 'YES';

  # split query string parameter on commas
  my ($username, $domain, $password, $email, $checkval) =
    split(/,/, $$reqparm{'selfcreate'});
  $username = '' if !defined($username);
  $domain   = '' if !defined($domain);
  $password = '' if !defined($password);
  $email    = '' if !defined($email);
  $checkval = '' if !defined($checkval);

  # validate the signature
  my $check = md5_base64(
    "$username.$domain.$password.$email.$$pref{'SERVER_KEY'}"
    );
  pg_error('bad_request') if $check ne $checkval;

  # check a valid domain is specified
  $dominfo = getdomain($domain);
  pg_error('unknown_dom') if !$dominfo;

  # this domain allows addself?
  pg_error('no_add_self') if $$dominfo{'addself'} eq 'NO';

  # restricted user?
  chkrestrict($username);

  # check already exists?
  $userinfo = getuser($username, $domain);
  pg_error('user_exists') if $userinfo;

  # check for admin by same name
  $userinfo = getuser($username, '');
  pg_error('restricted_user') if $userinfo;

  $userinfo = createuser(
     $username,
     $domain,
     $password,
     'USER',
     $email,
    );

  writelog(
    "User $username.$domain self registered"
    );

  pg_didself();
}    

########################################################################
#  do AutoURL
########################################################################
sub do_autourl {

  # retrieve any cookies passed to us
  my $cookie = parse_cookies($ENV{'HTTP_COOKIE'});

  # look for cookies we need here
  my $cookieuser   = $$cookie{'gnudipuser'};
  my $cookiedomain = $$cookie{'gnudipdomain'};
  my $cookiepass   = $$cookie{'gnudippass'};

  # did we get all cookies?
  pg_error('no_cookie')
    if !$cookieuser or
       !defined($cookiedomain) or
       !$cookiepass;

  # auto URL disabled?
  if ($$pref{'ALLOW_AUTO_URL'} ne 'YES') {
    writelog(
      "Auto URL attempt - user: $cookieuser - domain: $cookiedomain"
      );
    removecookies();
    pg_error("no_autourl");
  }

  # login
  $userinfo = getuser($cookieuser, $cookiedomain);
  pg_error('bad_cookie')
    if !$userinfo or $cookiepass ne $$userinfo{'password'};

  # need an E-mail adddress?
  if ($$pref{'REQUIRE_EMAIL'} eq 'YES'   and
      $$userinfo{'level'}     ne 'ADMIN' and
      $$userinfo{'email'}     eq '') {
    # generate a logon ID
    $$reqparm{'logonid'} = randomsalt();
    pg_needemail();
  } 

  # is the IP address an acceptable one?
  pg_error('bad_IP') if !validip($remote_ip);

  # TTL value
  my $TTL = 0;
  $TTL = $$conf{'TTL'} if $$conf{'TTL'};
  $TTL = $$conf{"TTL.$cookiedomain"}
      if $$conf{"TTL.$cookiedomain"};
  $TTL = $$conf{"TTL.$cookieuser.$cookiedomain"}
      if $$conf{"TTL.$cookieuser.$cookiedomain"};

  # IP address changed?
  if ($remote_ip ne $$userinfo{'currentip'}) {
    donsupdate ($cookiedomain,
      "update delete $cookieuser.$cookiedomain A",
      "update add    $cookieuser.$cookiedomain $TTL A $remote_ip"
      );
    writelog(
     "User $cookieuser.$cookiedomain successful update to ip $remote_ip (autourl)"
     );
  } else {
    writelog(
     "User $cookieuser.$cookiedomain remains at ip $remote_ip (autourl)"
     );
  }

  # update database
  $$userinfo{'currentip'} = $remote_ip;
  updateuser($userinfo);

  # this was test?
  pg_goodautourl() if $$reqparm{'testautourl'};

  # redirect?
  pg_noforwardurl() if !$$userinfo{'forwardurl'};
  print "Location: $$userinfo{'forwardurl'}\n\n";

  exit;
}

#######################################################################
# remove Auto URL
#######################################################################
sub do_removeautourl {

  # update user information
  $$userinfo{'autourlon'} = 'NO';
  updateuser($userinfo);

  # generate empty cookies
  removecookies();

  # message
  pg_msg(qq*
Auto URL Removal Successful
*,qq*
Any Auto URL cookies in your browser have been removed.
*);

  exit;
}

########################################################################
#  login
########################################################################
sub do_login {

  # entered necessary info?
  pg_error('no_username') if ! $$reqparm{'username'};
  pg_error('no_password') if ! $$reqparm{'password'};

  # try for an admin first, then normal user
  $userinfo = getuser($$reqparm{'username'}, '');
  if ($userinfo) {
    $$reqparm{'domain'} = '';
  } else {
    $userinfo =
      getuser($$reqparm{'username'}, $$reqparm{'domain'});
  }

  # user name matches with case sensitivity?
  pg_error('nouser')
    if !$userinfo or
       $$userinfo{'username'} ne $$reqparm{'username'};

  # password disabled?
  pg_error('dispass')
    if $$userinfo{'password'} eq '';

  # hash the password, if not already hashed, and check it
  if ($$reqparm{'login'} ne 'enc') {
    $$reqparm{'password'} = md5_hex($$reqparm{'password'});
  }
  pg_error('badpass')
    if $$userinfo{'password'} ne $$reqparm{'password'};

  # get information for user's domain
  if ($$reqparm{'domain'}) {
    $dominfo = getdomain($$reqparm{'domain'});
    pg_error('unknown_dom') if !$dominfo;
  }

  # generate a logon ID
  $$reqparm{'logonid'} = randomsalt();

  # need an E-mail address?
  if ($$pref{'REQUIRE_EMAIL'} eq 'YES'   and
      $$userinfo{'level'}     ne 'ADMIN' and
      $$userinfo{'email'}     eq '') {
    pg_needemail();
  } 

  pg_options();
}

########################################################################
#  send Quick login URL
########################################################################
sub do_sendURL {

  # sending quick login URL allowed?
  pg_error('no_sendURL') if $$pref{'SEND_URL'} ne 'YES';

  # entered necessary info?
  pg_error('no_username') if ! $$reqparm{'sendURL_username'};

  # try for an admin first, then normal user
  $userinfo = getuser($$reqparm{'sendURL_username'}, '');
  if ($userinfo) {
    $$reqparm{'domain'} = '';
  } else {
    $userinfo =
      getuser($$reqparm{'sendURL_username'}, $$reqparm{'domain'});
  }

  # user name matches with case sensitivity?
  pg_error('nouser')
    if !$userinfo or
       $$userinfo{'username'} ne $$reqparm{'sendURL_username'};

  # get information for user's domain
  if ($$reqparm{'domain'}) {
    $dominfo = getdomain($$reqparm{'domain'});
    pg_error('unknown_dom') if !$dominfo;
  }

  # password disabled?
  pg_error('dispass') if $$userinfo{'password'} eq '';

  # no E-mail address?
  pg_error('no_useremail') if $$userinfo{'email'} eq '';

  # check not a robot
  mchk_check();

  # send the E-mail
  mail_quick(
      $$userinfo{'username'},
      $$userinfo{'domain'},
      $$userinfo{'password'},
      $$userinfo{'email'},
      );

  # message
  pg_sentURL($$userinfo{'email'});
}

########################################################################
#  update IP address
########################################################################
sub do_updatehost {

  # valid syntax?
  pg_error('bad_IP_syntax') if !validdotquad($$reqparm{'updateaddr'});

  # is the IP address an acceptable one?
  pg_error('bad_IP') if !validip($$reqparm{'updateaddr'});

  # TTL value
  my $TTL = 0;
  $TTL = $$conf{'TTL'} if $$conf{'TTL'};
  $TTL = $$conf{"TTL.$$userinfo{'domain'}"}
      if $$conf{"TTL.$$userinfo{'domain'}"};
  $TTL = $$conf{"TTL.$$userinfo{'username'}.$$userinfo{'domain'}"}
      if $$conf{"TTL.$$userinfo{'username'}.$$userinfo{'domain'}"};

  # IP address changed?
  if ($$reqparm{'updateaddr'} ne $$userinfo{'currentip'}) {
    donsupdate ($$userinfo{'domain'},
      "update delete $$userinfo{'username'}.$$userinfo{'domain'}. A",
      "update add    $$userinfo{'username'}.$$userinfo{'domain'}. $TTL " .
         "A $$reqparm{'updateaddr'}"
      );
    writelog(
      "User $$userinfo{'username'}.$$userinfo{'domain'} " .
         "successful update to ip $$reqparm{'updateaddr'} (manual)");
  } else {
    writelog(
     "User $$userinfo{'username'}.$$userinfo{'domain'} " .
       "remains at ip $$userinfo{'currentip'} (manual)");
  }

  # update database
  $$userinfo{'currentip'} = $$reqparm{'updateaddr'};
  updateuser($userinfo);

  # reshow page
  pg_options();
}

########################################################################
#  offline
########################################################################
sub do_offline {

  # had an IP address?
  if ($$userinfo{'currentip'} ne '0.0.0.0') {
    donsupdate ($$reqparm{'domain'},
      "update delete $$userinfo{'username'}.$$userinfo{'domain'}. A"
      );
    writelog(
     "User $$userinfo{'username'}.$$userinfo{'domain'} " .
       "successful remove from ip $$userinfo{'currentip'} (manual)");
  } else {
    writelog(
     "User $$userinfo{'username'}.$$userinfo{'domain'} " .
       "remains removed (manual)")
  }

  # update database
  $$userinfo{'currentip'} = '0.0.0.0';
  updateuser($userinfo);

  # reshow page
  pg_options();
}

########################################################################
#  delete current user
########################################################################
sub do_delthisuser {

  # self deleteion allowed?
  pg_error('no_delself') if $$pref{'DELETE_SELF'} ne 'YES';

  # remove from DNS
  if ($$userinfo{'level'} eq 'USER') {
    # send update to DNS server
    donsupdate ($$userinfo{'domain'},
      "update delete   $$userinfo{'username'}.$$userinfo{'domain'}.",
      "update delete *.$$userinfo{'username'}.$$userinfo{'domain'}.");
    writelog(
      "User $$userinfo{'username'}.$$userinfo{'domain'} " .
        "complete remove from DNS (delete)");
  }

  # update database
  deleteuser($userinfo);

  writelog(
    "User $$userinfo{'username'}.$$userinfo{'domain'} deleted by self"
    );

  # message
  pg_usergone();
}      

########################################################################
#  update current user
########################################################################
sub do_updatesettings {
  do_cmn_edituser($userinfo, $dominfo);
}

########################################################################
#  save system settings
########################################################################
sub do_syssettings {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # ensure initialized
  default_NO('ADD_SELF');
  default_NO('DELETE_SELF');
  default_NO('SEND_URL');
  default_NO('REQUIRE_EMAIL');
  default_NO('NO_ROBOTS');
  default_NO('ALLOW_CHANGE_HOSTNAME');
  default_NO('ALLOW_CHANGE_DOMAIN');
  default_NO('ALLOW_AUTO_URL');
  default_NO('SHOW_DOMAINLIST');
  default_empty('PAGE_TIMEOUT');
  default_empty('RESTRICTED_USERS');
  default_NO('ALLOW_WILD');
  default_NO('ALLOW_WILD_USER');
  default_NO('ALLOW_MX');
  default_NO('ALLOW_MX_USER');

  # remove spaces
  $$reqparm{'RESTRICTED_USERS'} =~ s/ //g;

  # combine into one value
  $$reqparm{'ALLOW_WILD'} = 'USER'
    if $$reqparm{'ALLOW_WILD'}      eq 'NO' and
       $$reqparm{'ALLOW_WILD_USER'} eq 'YES';

  # combine into one value
  $$reqparm{'ALLOW_MX'} = 'USER'
    if $$reqparm{'ALLOW_MX'}      eq 'NO' and
       $$reqparm{'ALLOW_MX_USER'} eq 'YES';

  # update values in global variable
  setpref('ADD_SELF');
  setpref('DELETE_SELF');
  setpref('SEND_URL');
  setpref('REQUIRE_EMAIL');
  setpref('NO_ROBOTS');
  setpref('ALLOW_CHANGE_HOSTNAME');
  setpref('ALLOW_CHANGE_DOMAIN');
  setpref('ALLOW_AUTO_URL');
  setpref('RESTRICTED_USERS');
  setpref('ALLOW_WILD');
  setpref('ALLOW_MX');
  setpref('PAGE_TIMEOUT');
  setpref('SHOW_DOMAINLIST');

  # update database
  updateprefs($pref);

  # reshow page
  pg_syssettings();
}
sub setpref {
  my $key = shift;
  $$pref{$key} = $$reqparm{$key};
}

########################################################################
#  add domain
########################################################################
sub do_adddomain {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # check domain name
  pg_error('no_domain') if !$$reqparm{'adddomain_new_domain'};
  $$reqparm{'new_domain'} = validdomain($$reqparm{'adddomain_new_domain'});
  pg_error('bad_domain') if !$$reqparm{'new_domain'};

  # remove trailing period
  $$reqparm{'new_domain'} =~ s/\.$//;

  # already exists?
  my $dinfo = getdomain($$reqparm{'new_domain'});
  pg_error('domain_exists') if $dinfo;

  # ensure initialized
  default_NO('ALLOW_CHANGEPASS');
  default_NO('ADDSELF');

  # update database
  createdomain(
    $$reqparm{'new_domain'},
    $$reqparm{'ALLOW_CHANGEPASS'},
    $$reqparm{'ADDSELF'}
    );

  # show domain list
  pg_managedomains();
}

########################################################################
#  update domain
########################################################################
sub do_editdomain {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # check domain name
  pg_error('no_domain') if !$$reqparm{'new_domain'};

  # ensure initialized
  default_NO('ADDSELF');
  default_NO('ALLOW_CHANGEPASS');

  # get from database and update
  my $dinfo = getdomain($$reqparm{'editdom'});
  pg_error('bad_edit_domain') if !$dinfo;

  # update in variable
  $$dinfo{'domain'}     = $$reqparm{'new_domain'};
  $$dinfo{'changepass'} = $$reqparm{'ALLOW_CHANGEPASS'};
  $$dinfo{'addself'}    = $$reqparm{'ADDSELF'};

  # update database
  updatedomain($dinfo);

  # reshow page
  pg_editdomain($dinfo);
}

########################################################################
#  delete domains
########################################################################
sub do_deldomain {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # any domains to delete?
  pg_managedomains() if !$$reqparm{'deldom'};

  # delete selected domains
  foreach my $deldom (split(/\0/, $$reqparm{'deldom'})) {

    # get from database
    my $dinfo = getdomain($deldom);

    # delete from database
    deletedomain($dinfo) if $dinfo;
  }

  # show domain list
  pg_managedomains();
}

########################################################################
#  add user
########################################################################
sub do_adduser {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # ensure initialised
  $$reqparm{'disable'} = '' if ! defined $$reqparm{'disable'};

  # entered necessary data?
  pg_error('no_username') if !$$reqparm{'new_username'};
  if (!$$reqparm{'disable'}) {
    pg_error('no_password') if !$$reqparm{'new_password'};
    pg_error('no_password') if !$$reqparm{'new_password1'};
  }

  # check user name
  pg_error('bad_username') if !validdomcomp($$reqparm{'new_username'});

  # check password
  pg_error('not_same')
    if !$$reqparm{'disable'} and
       $$reqparm{'new_password'} ne $$reqparm{'new_password1'};

  # check already exists
  my $uinfo = getuser(
    $$reqparm{'new_username'}, $$reqparm{'new_domain'});
  pg_error('user_exists') if $uinfo;

  # check for admin by same name
  $uinfo = getuser($$reqparm{'new_username'}, '');
  pg_error('user_exists') if $uinfo;

  # check user level
  $$reqparm{'user_level'} = 'USER' if !$$reqparm{'user_level'};

  # ensure initialized
  default_empty('new_email');

  # no domain name for admin user
  $$reqparm{'new_domain'} = '' if $$reqparm{'user_level'} eq 'ADMIN';

  # update database
  my $password = '';
  $password = md5_hex($$reqparm{'new_password'})
    if ! $$reqparm{'disable'};
  createuser(
    $$reqparm{'new_username'},
    $$reqparm{'new_domain'},
    $password,
    $$reqparm{'user_level'},
    $$reqparm{'new_email'}
    );

  writelog(
    "User $$reqparm{'new_username'}.$$reqparm{'new_domain'} added by administrator"
    );

  # show user list with just the new user
  $$reqparm{'user_pattern'} = $$reqparm{'new_username'};
  pg_manageusers();
}

########################################################################
#  manage users
########################################################################
sub do_manageusers {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # ensure initialized
  default_empty('user_pattern');

  # remove white space from start and end of user pattern
  $$reqparm{'user_pattern'} =~ s/^\s+//;
  $$reqparm{'user_pattern'} =~ s/\s+$//;

  # figure out what key and what order to sort
  sub setby {
    my $sortby = shift;
    if ($$reqparm{'sortby'} ne $sortby) {
      $$reqparm{'orderby'} = 'asc';
    } elsif (!$$reqparm{'do_deluser'}) {
      if ($$reqparm{'orderby'} eq 'asc') {
        $$reqparm{'orderby'} = 'desc';
      } else {
        $$reqparm{'orderby'} = 'asc';
      }
    }
    $$reqparm{'sortby'} = $sortby;
  }
  default_empty('sortby');
  $$reqparm{'sortby'} = 'username' if !$$reqparm{'sortby'};
  default_empty('orderby');
  $$reqparm{'orderby'} = 'desc' if $$reqparm{'orderby'} ne 'asc';
  if ($$reqparm{'manage_users_sortby_currentip'}) {
    setby('currentip');
  } elsif ($$reqparm{'manage_users_sortby_domain'}) {
    setby('domain');
  } elsif ($$reqparm{'manage_users_sortby_updated'}) {
    setby('updated');
  } elsif ($$reqparm{'manage_users_sortby_level'}) {
    setby('level');
  } elsif ($$reqparm{'manage_users_sortby_email'}) {
    setby('email');
  } else {
    setby('username');
  }

  # (re)show page
  pg_manageusers();
}

########################################################################
#  edit user (by admin)
########################################################################
sub do_edituser {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # ensure initialized
  default_empty('edituser');

  # get from database
  my $uinfo = getuserbyid($$reqparm{'edituser'});
  pg_error('bad_edit_user') if !$uinfo;
  my $dinfo = getdomain($$uinfo{'domain'});

  # show common page user edit page
  do_cmn_edituser($uinfo, $dinfo);
}

########################################################################
# common user edit
# - cases distinguished by: $$reqparm{'do_edituser'}
########################################################################
sub do_cmn_edituser {
  my $uinfo = shift;
  my $dinfo = shift;

  # save for DNS routine
  my %userhash = %$uinfo;
  my $oldinfo  = \%userhash;

  # check for valid new domain
  my $domchange = '';
  $$reqparm{'new_domain'} = $$uinfo{'domain'}
    if !$$reqparm{'new_domain'};
  if ($$reqparm{'new_domain'} ne $$uinfo{'domain'}) {
    pg_error('no_domain_change')
      if !$$reqparm{'do_edituser'} and
          $$pref{'ALLOW_CHANGE_DOMAIN'} eq 'NO';
    $dinfo = getdomain($$reqparm{'new_domain'});
    pg_error('unknown_dom') if !$dinfo;
    pg_error('no_dom_domain_change')
      if !$$reqparm{'do_edituser'} and $$dinfo{'addself'} ne 'YES';
    $domchange = 1;
    $$uinfo{'domain'} = $$reqparm{'new_domain'};
  }

  # check for valid new user name
  pg_error('no_username') if !$$reqparm{'new_username'};
  my $userchange = '';
  if ($$reqparm{'new_username'} ne $$uinfo{'username'}) {
    pg_error('no_changehostname')
      if !$$reqparm{'do_edituser'} and
          $$pref{'ALLOW_CHANGE_HOSTNAME'} eq 'NO' and
          $$uinfo{'level'} eq 'USER';
    pg_error('bad_username') if !validdomcomp($$reqparm{'new_username'});
    # restricted user?
    chkrestrict($$reqparm{'new_username'});
    $$uinfo{'username'} = $$reqparm{'new_username'};
    $userchange = 1;
  } 

  # check for valid new password
  my $passchange = '';
  $$reqparm{'disable'} = '' if ! defined $$reqparm{'disable'};
  if ($$reqparm{'do_edituser'} and $$reqparm{'disable'}) {
    $$uinfo{'password'} = '';
    $passchange = 1;
  } elsif ($$reqparm{'new_password'} or $$reqparm{'new_password1'}) {
    pg_error('no_changepass')
      if !$$reqparm{'do_edituser'} and
          $$uinfo{'level'}        eq 'USER' and
          ( !$dinfo or $$dinfo{'changepass'} eq 'NO');
    pg_error('no_password') if !$$reqparm{'new_password'};
    pg_error('no_password') if !$$reqparm{'new_password1'};
    pg_error('not_same')
      if $$reqparm{'new_password'} ne $$reqparm{'new_password1'};
    $$uinfo{'password'} = md5_hex($$reqparm{'new_password'});
    $passchange = 1;
  }

  # new user/domain user already exists?
  if ($userchange or $domchange) {
    # check already exists?
    my $uinfo = getuser($$reqparm{'new_username'}, $$reqparm{'new_domain'});
    pg_error('user_exists') if $uinfo;
    # check for admin by same name
    $uinfo = getuser($$reqparm{'new_username'}, '');
    pg_error('restricted_user') if $uinfo;
  }

  # E-mail
  default_empty('new_email');
  if ($$userinfo{'level'} eq 'ADMIN' or
      $$reqparm{'do_edituser'}       or
      $$pref{'REQUIRE_EMAIL'} ne 'YES') {
    pg_error('bad_email')
      if $$reqparm{'new_email'} ne '' and
         $$reqparm{'new_email'} ne $$uinfo{'email'} and
         !validemail($$reqparm{'new_email'});
    $$uinfo{'email'} = $$reqparm{'new_email'};
  }

  # Forward URL
  default_empty('forwardurl');
  $$uinfo{'forwardurl'} = $$reqparm{'forwardurl'};

  # check/validate wildcard flag
  default_NO('wildcard');
  $$reqparm{'wildcard'} = 'NO'
    if $$pref{'ALLOW_WILD'} eq 'NO' or
       $$pref{'ALLOW_WILD'} eq 'USER' and
         $$uinfo{'allowwild'} eq 'NO';
  $$uinfo{'wildcard'} = $$reqparm{'wildcard'};

  # check/validate MX value
  default_empty('new_MXvalue');
  if ($$pref{'ALLOW_MX'} eq 'NO' or
      $$pref{'ALLOW_MX'} eq 'USER' and
      $$uinfo{'allowmx'} eq 'NO') {
    $$reqparm{'new_MXvalue'} = '';
  } elsif ($$reqparm{'new_MXvalue'} ne '') {
    my $tinydns = '';
    $tinydns = $$conf{'tinydns'} if defined $$conf{'tinydns'};
    $tinydns = $$conf{"tinydns.$$uinfo{'domain'}"}
      if defined $$conf{"tinydns.$$uinfo{'domain'}"};
    if ( $tinydns eq 'YES' ) {
      $$reqparm{'new_MXvalue'} = validdotquad($$reqparm{'new_MXvalue'});
      pg_error('bad_MX_IP') if !$$reqparm{'new_MXvalue'};
    } else {
      $$reqparm{'new_MXvalue'} = validdomain($$reqparm{'new_MXvalue'});
      pg_error('bad_MX_dom') if !$$reqparm{'new_MXvalue'};
    }
  }
  $$uinfo{'MXvalue'} = $$reqparm{'new_MXvalue'};

  # check/validate MX backup flag
  default_NO('MXbackup');
  $$reqparm{'MXbackup'} = 'NO'
    if $$pref{'ALLOW_MX'} eq 'NO' or
        $$pref{'ALLOW_MX'} eq 'USER' and
          $$uinfo{'allowmx'} eq 'NO';
  $$uinfo{'MXbackup'} = $$reqparm{'MXbackup'};

  # editing a user as admin?
  if ($$reqparm{'do_edituser'}) {

    # check IP address
    default_empty('new_IPaddress');
    my $currentip = $$uinfo{'currentip'};
    $currentip = '' if $currentip eq '0.0.0.0';
    if ($$reqparm{'new_IPaddress'} ne $currentip) {
      if ($$reqparm{'new_IPaddress'} eq '') {
        $$uinfo{'currentip'} = '0.0.0.0';
      } else {
        $$reqparm{'new_IPaddress'} = validdotquad($$reqparm{'new_IPaddress'});
        pg_error('bad_IP_syntax') if !$$reqparm{'new_IPaddress'};
        $$uinfo{'currentip'} = $$reqparm{'new_IPaddress'};
      }
    }

    # wildcards allowed user by user?
    if ($$pref{'ALLOW_WILD'} eq 'USER') {

      # check/validate allow wildcard flag
      default_NO('allow_wildcard');
      $$reqparm{'allow_wildcard'} = 'NO'
        if $$pref{'ALLOW_MX'} ne 'USER';
      $$uinfo{'allowwild'} = $$reqparm{'allow_wildcard'};
      $$uinfo{'wildcard'}  = 'NO' if $$uinfo{'allowwild'} eq 'NO';
    }

    # MX allowed user by user?
    if ($$pref{'ALLOW_WILD'} eq 'USER') {

      # check/validate allow MX flag
      default_NO('allow_mx');
      $$reqparm{'allow_mx'} = 'NO'
        if $$pref{'ALLOW_MX'} ne 'USER';
      $$uinfo{'allowmx'} = $$reqparm{'allow_mx'};
      if ($$uinfo{'allowmx'} eq 'NO') {
        $$uinfo{'MXvalue'}  = '';
        $$uinfo{'MXbackup'} = 'NO';
      }
    }
  }

  # send updates to DNS server?
  needDNSupdate($oldinfo, $uinfo) if $$uinfo{'level'} ne 'ADMIN';

  # update database
  updateuser($uinfo);

  # editing our self? update global variable
  if (!$$reqparm{'do_edituser'}) {
    $$reqparm{'username'} = $$userinfo{'username'};
    $$reqparm{'password'} = $$userinfo{'password'};
    $$reqparm{'domain'}   = $$userinfo{'domain'};
  }

  # reshow page
  pg_cmn_edituser($uinfo);
}

########################################################################
# E-mail address entry
########################################################################
sub do_needemail {

  # ensure initialized
  default_empty('new_needemail');

  # check E-mail address
  pg_error('no_email')  if $$reqparm{'new_needemail'}  eq '';
  pg_error('bad_email') if !validemail($$reqparm{'new_needemail'});


  # check not a robot
  mchk_check();

  # send the E-mail
  mail_newemail(
    $$userinfo{'username'},
    $$userinfo{'domain'},
    $$userinfo{'password'},
    $$reqparm{'new_needemail'},
    );

  # reshow page
  pg_newemail($$reqparm{'new_needemail'});
}

########################################################################
# E-mail update after E-mail sent
########################################################################
sub do_newemail {

  # split query string parameter on commas
  my ($username, $domain, $password, $email, $checkval) =
    split(/,/, $$reqparm{'newemail'});

  # ensure initialized
  $username = '' if !defined($username);
  $domain   = '' if !defined($domain);
  $password = '' if !defined($password);
  $email    = '' if !defined($email);
  $checkval = '' if !defined($checkval);

  # validate the signature
  my $check = md5_base64(
    "$username.$domain.$password.$email.$$pref{'SERVER_KEY'}"
    );
  pg_error('bad_request') if $check ne $checkval;

  # validate/retrieve the user
  my $uinfo = getuser($username, $domain);
  pg_error('nouser')
    if !$uinfo or $$uinfo{'username'} ne $username;
  pg_error('badpass') if $$uinfo{'password'} ne $password;

  # update the email
  $$uinfo{'email'} = $email;
  updateuser($uinfo);

  # message
  pg_didemail();
}    

########################################################################
#  delete users
########################################################################
sub do_deluser {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # any users to delete?
  pg_manageusers() if !$$reqparm{'deluser'};

  # delete selected users
  foreach my $deluser (split(/\0/, $$reqparm{'deluser'})) {

    # get from database
    my $uinfo = getuserbyid($deluser);
    if ($uinfo) {

      # not admin?
      if ($$uinfo{'level'} eq 'USER') {

        # domain still exists?
        my $dinfo = getdomain($$uinfo{'domain'});
        if ($dinfo) {

          # remove from DNS
          donsupdate ($$uinfo{'domain'},
            "update delete   $$uinfo{'username'}.$$uinfo{'domain'}.",
            "update delete *.$$uinfo{'username'}.$$uinfo{'domain'}.");
          writelog(
            "User $$uinfo{'username'}.$$uinfo{'domain'} complete remove from DNS (delete)");
        }
      }

      # update database
      deleteuser($uinfo);

      writelog(
        "User $$uinfo{'username'}.$$uinfo{'domain'} deleted by administrator"
        );
    }
  }

  # reshow page
  pg_manageusers();
}

########################################################################
# subroutines
########################################################################

# remove autoURL cookies
sub removecookies {
  printcookie('gnudipuser',   '', '-1s'); 
  printcookie('gnudipdomain', '', '-1s');
  printcookie('gnudippass',   '', '-1s');
}

# check for a restricted user
sub chkrestrict {
  my $username = shift;

  # split system parameter on commas and check each
  foreach my $check
      (split(/\,/, $$pref{'RESTRICTED_USERS'})) {

    # massage retricted user template into valid Perl regular expression
    $check =~ s/\*/\(\.\*\)/g;
    $check =~ s/\?/\(\.\)/g;

    # check for a match
    pg_error('restricted_user') if $username =~ /^$check\b/;
  } 
}

########################################################################
# must return 1
########################################################################
1;

