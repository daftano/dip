########################################################################
# gdipcgi.pm
#
# This file really is the GnuDIP CGI. The gnudip.cgi script just
# executes the gdipcgi subroutine.
#
# See COPYING for licensing information.
#
########################################################################

# Perl modules
use strict;

# global variables
use vars qw($conf $gnudipdir);
use vars qw($pref $userinfo $dominfo $remote_ip);
use vars qw($reqparm $thiscgi $thishost $logger $thisurl);
use vars qw($bad_config);

# GnuDIP common subroutines
use gdiplib;
use gdipcgi_cmn;
use dbprefs;
use dbusers;
use doreq;
use htmlgen;
use gdipmailchk;

########################################################################
# NOTE
# Each pg_? routine generates a page and does an "exit".
# So they DO NOT RETURN.
########################################################################

########################################################################
# NOTE
# The do_? routines all call a pg_? routine.
# So they DO NOT RETURN.
########################################################################

########################################################################
# the actual CGI
########################################################################
sub gdipcgi {

  # called as HEAD?
  pg_head()
    if $ENV{'REQUEST_METHOD'} and
       $ENV{'REQUEST_METHOD'} eq 'HEAD';

  # set configuration error handler for common subroutines
  $bad_config = \&bad_config_cgi;

  # get preferences from config file
  if (! defined $conf or
      ! defined $$conf{'persistance'} or
      $$conf{'persistance'} ne 'YES') {
    $conf = getconf();
    if (! $conf) {
      print STDERR "GnuDIP CGI has exited - getconf returned nothing\n";
      htmlgen_init();
      dberror();
    }
  }

  # logger command
  $logger = $$conf{'logger_cgi'};

  # not called by HTTP server
  if (!$ENV{'REQUEST_METHOD'} or
      $ENV{'REQUEST_METHOD'} ne 'GET' and
      $ENV{'REQUEST_METHOD'} ne 'POST') {
    writelog( 'gdipcgi.pm: REQUEST_METHOD environment variable is not set');
    print "REQUEST_METHOD environment variable is not set\n";
    writelog( 'gdipcgi.pm: Not called by HTTP server');
    print "Not called by HTTP server\n";
    exit;
  }

  # no current user to start
  $userinfo  = undef;
  $dominfo   = undef;

  # IP address of connecting machine
  $remote_ip   = $ENV{'REMOTE_ADDR'};
  $remote_ip = '0.0.0.0' if !$remote_ip;

  # CGI request information
  if ($ENV{'REQUEST_METHOD'} eq 'POST') {
    $reqparm = parse_query(read_post_data());
  } else {
    $reqparm = parse_query($ENV{'QUERY_STRING'});
  }
  $thiscgi  = $ENV{'SCRIPT_NAME'};
  $thishost = $ENV{'HTTP_HOST'};
  if ($ENV{'HTTPS'}) {
    $thisurl = "https://$thishost$thiscgi";
  } else {
    $thisurl = "http://$thishost$thiscgi";
  }
  
  # for debugging
  # - details of HTTP request to server log 
  #logreq();

  # initialise HTML generation routines
  htmlgen_init();

  # get preferences from the database
  $pref = getprefs();

  #############################################################
  #  identify requests not needing user validation
  #############################################################

  # deal with GET requests
  if ($ENV{'REQUEST_METHOD'} eq 'GET') {

    # main login page
    pg_login() if !$ENV{'QUERY_STRING'};

    # ensure initialized
    default_empty('login');
    default_empty('action');

    # quick login
    do_login() if $$reqparm{'login'} eq 'enc';

    # IP detection before quick login
    pg_ipdetect() if $$reqparm{'login'} eq 'ipdetect';

    # self registration
    pg_self() if $$reqparm{'action'} eq 'signup';

    # do AutoURL
    do_autourl() if $$reqparm{'action'} eq 'getautourlinfo';

    # self registration after E-mail sent
    do_selfcreate() if $$reqparm{'selfcreate'};

    # E-mail update after E-mail sent
    do_newemail() if $$reqparm{'newemail'};

    # show image for robot check
    pg_mchk_img() if $$reqparm{'mailcheck'};

    # bad HTTP request
    pg_error('bad_request');
  }

  #############################################################
  #  only POST method from a GnuDIP page valid from here on
  #############################################################

  pg_error('bad_request') if $ENV{'REQUEST_METHOD'} ne 'POST';
  pg_error('bad_request') if !$$reqparm{'page'};

  # from login page?
  if ($$reqparm{'page'} eq 'login') {

    # forgotten password
    pg_sendURL() if $$reqparm{'sendURL'};

    # self register
    pg_self() if $$reqparm{'self_signup'};

    # default to login
    $$reqparm{'login'} = 'Login';
    do_login();
  }

  # from forgotten password page?
  if ($$reqparm{'page'} eq 'sendURL') {

    # default to sending URL
    do_sendURL();
  }

  # from self registration page?
  if ($$reqparm{'page'} eq 'doself') {

    # default to sign up
    do_self();
  }

  #############################################################
  #  user validation needed from here on
  #############################################################

  # these form fields are created by the html_user subroutine
  # in htmlgen.pl
  default_empty('username');
  default_empty('domain');
  default_empty('password');
  default_empty('logonid');
  default_empty('pagetime');
  default_empty('checkval');

  # ensure people come through login page
  # validate the signature
  my $checkval  =
    md5_hex(
      "$$reqparm{'username'}." .
      "$$reqparm{'domain'}." .
      "$$reqparm{'password'}." .
      "$$reqparm{'logonid'}." .
      "$$reqparm{'pagetime'}." .
      $$pref{'SERVER_KEY'}
      );
  if ($checkval ne $$reqparm{'checkval'}) {
    writelog(
      "Invalid signature for $$reqparm{'username'}.$$reqparm{'domain'}"
      );
    pg_error('bad_request');
  }

  # validate/retrieve the user
  $userinfo = getuser($$reqparm{'username'}, $$reqparm{'domain'});
  pg_error('nouser')
    if !$userinfo or $$userinfo{'username'} ne $$reqparm{'username'};
  pg_error('badpass') if $$userinfo{'password'} ne $$reqparm{'password'};

  # page expired?
  pg_error('page_timeout')
    if $$userinfo{'level'} ne 'ADMIN' and
       $$pref{'PAGE_TIMEOUT'}         and 
       $$reqparm{'pagetime'} + $$pref{'PAGE_TIMEOUT'} < time;

  # get information for user's domain
  if ($$reqparm{'domain'}) {
    $dominfo = getdomain($$reqparm{'domain'});
    pg_error('unknown_dom') if !$dominfo;
  }

  #############################################################
  #  identify requests needing user validation
  #############################################################

  # from E-mail needed page?
  if ($$reqparm{'page'} eq 'needemail') {

    # default to E-mail update E-mail
    do_needemail();
  }

  # from options page?
  if ($$reqparm{'page'} eq 'options') {

    #############################
    # common to ADMIN and USER
    #############################

    # user settings page
    pg_usersettings() if $$reqparm{'changesettings'};

    # change E-mail page
    pg_needemail() if $$reqparm{'changemail'};

    # set Quick Login URL page
    pg_setquick() if $$reqparm{'setquick'};

    # delete current user
    do_delthisuser() if $$reqparm{'do_delthisuser'};

    #############################
    # for USER
    #############################

    # update IP address
    do_updatehost() if $$reqparm{'updatehost'};

    # offline
    do_offline() if $$reqparm{'offline'};

    # user settings page
    pg_usersettings() if $$reqparm{'changesettings'};

    # set auto URL page
    pg_setautourl() if $$reqparm{'setautourl'};

    #############################
    # for ADMIN
    #############################

    # add user page
    pg_adduser() if $$reqparm{'manageusers_adduser'};

    # manage users page
    do_manageusers() if $$reqparm{'manageusers_main'};

    # add domain page
    pg_adddomain() if $$reqparm{'managedomains_add'};

    # manage domains page
    pg_managedomains() if $$reqparm{'managedomains_main'};

    # systems settings page
    pg_syssettings() if $$reqparm{'system_settings'};

    # no default - reshow
    pg_options();
  }

  # from user settings page?
  if ($$reqparm{'page'} eq 'updatesettings') {

    # default to update current user
    do_updatesettings();
  }

  # from set Auto URL page?
  if ($$reqparm{'page'} eq 'setautourl') {

    # test
    do_autourl() if $$reqparm{'testautourl'};

    # remove
    do_removeautourl() if $$reqparm{'removeautourl'};

    # no default - reshow
    pg_setautourl();
  }

  # from add user page?
  if ($$reqparm{'page'} eq 'adduser') {

    # default to add user
    do_adduser();
  }

  # from manage users page?
  if ($$reqparm{'page'} eq 'manageusers') {

    # edit user page
    pg_edituser() if $$reqparm{'manageusers_edituser'};

    # delete users
    do_deluser() if $$reqparm{'do_deluser'};

    # reorder page contents
    do_manageusers()
      if $$reqparm{'manage_users_sortby_username'}  or
         $$reqparm{'manage_users_sortby_currentip'} or
         $$reqparm{'manage_users_sortby_email'} or
         $$reqparm{'manage_users_sortby_domain'}    or
         $$reqparm{'manage_users_sortby_updated'}   or
         $$reqparm{'manage_users_sortby_level'}
         ;

    # no default - reshow
    pg_manageusers();
  }

  # from user edit (by admin) page?
  if ($$reqparm{'page'} eq 'edituser') {

    # default to update user
    $$reqparm{'do_edituser'} = 'Save Changes';
    do_edituser();
  }

  # from add domain page?
  if ($$reqparm{'page'} eq 'adddomain') {

    # default to add domain
    do_adddomain();
  }

  # from manage domains page?
  if ($$reqparm{'page'} eq 'managedomains') {

    # edit domain page
    pg_editdomain() if $$reqparm{'managedomains_edit'};

    # delete domains
    do_deldomain() if $$reqparm{'do_deldomain'};

    # no default - reshow
    pg_managedomains();
  }

  # from edit domain page?
  if ($$reqparm{'page'} eq 'editdomain') {

    # default to update domain
    do_editdomain();
  }

  # from system settings page?
  if ($$reqparm{'page'} eq 'syssettings') {

    # default to save system settings
    do_syssettings();
  }

  #############################################################
  # bad HTTP request
  #############################################################
  pg_error('bad_request');
}

#############################################################
# subroutines
#############################################################

# configuration error handler
sub bad_config_cgi {
  pg_error('config');
}

# initialise request parameters
sub default_NO {
  my $key = shift;
  $$reqparm{$key} = 'NO'
    if !defined($$reqparm{$key}) or
                $$reqparm{$key} ne 'YES';
}
sub default_empty {
  my $key = shift;
  $$reqparm{$key} = '' if !defined($$reqparm{$key});
}

# generate header only
sub pg_head {
  tpr(qq*
Content-Type: text/html; charset=iso-8859-1

*);
  exit;  
}

#####################################################
# must return 1
#####################################################
1;

