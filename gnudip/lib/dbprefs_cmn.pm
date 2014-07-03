#####################################################
# dbprefs_cmn.pm
#
# These routines handle the globalprefs and domains
# tables.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;

#####################################################
# return the list of preference names
#####################################################
sub prefscmnlist {
  return (
      'RESTRICTED_USERS', 'ADD_SELF', 'DELETE_SELF',
      'SEND_URL', 'REQUIRE_EMAIL', 'NO_ROBOTS',
      'ALLOW_CHANGE_PASS',
      'ALLOW_CHANGE_HOSTNAME', 'ALLOW_CHANGE_DOMAIN',
      'ALLOW_WILD', 'ALLOW_MX', 'ALLOW_AUTO_URL',
      'SHOW_DOMAINLIST', 'PAGE_TIMEOUT', 'SERVER_KEY'
      );
}

#############################################################
# set uninitialised fields to default value
#############################################################
sub prefscmndflt {
  my $pref = shift;
  prefscmndfltset($pref, 'RESTRICTED_USERS',      'www,ftp,mail,ns?,dyn');
  prefscmndfltset($pref, 'ADD_SELF',              'NO');
  prefscmndfltset($pref, 'SEND_URL',              'NO');
  prefscmndfltset($pref, 'DELETE_SELF',           'YES');
  prefscmndfltset($pref, 'REQUIRE_EMAIL',         'YES');
  prefscmndfltset($pref, 'NO_ROBOTS',             'NO');
  prefscmndfltset($pref, 'ALLOW_CHANGE_PASS',     'YES');
  prefscmndfltset($pref, 'ALLOW_CHANGE_HOSTNAME', 'NO');
  prefscmndfltset($pref, 'ALLOW_CHANGE_DOMAIN',   'NO');
  prefscmndfltset($pref, 'ALLOW_WILD',            'NO');
  prefscmndfltset($pref, 'ALLOW_MX',              'NO');
  prefscmndfltset($pref, 'ALLOW_AUTO_URL',        'NO');
  prefscmndfltset($pref, 'SHOW_DOMAINLIST',       'YES');
  prefscmndfltset($pref, 'PAGE_TIMEOUT',          '');
  prefscmndfltset($pref, 'SERVER_KEY',            '');

  # generate and save server key if needed
  if (!$$pref{'SERVER_KEY'}) {
    $$pref{'SERVER_KEY'} = randomsalt();
    updateprefs($pref);
    writelog("Generated server key");
  }
}
sub prefscmndfltset {
  my $pref  = shift;
  my $param = shift;
  my $value = shift;
  $$pref{$param} = $value if ! defined $$pref{$param};
}

#####################################################
# must return 1
#####################################################
1;

