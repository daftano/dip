#####################################################
# dbcore_mysql.pm
#
# These are the "core" routines for using a MySQL
# database.
#
# See COPYING for licensing information.
#
#####################################################

# Perl modules
use strict;
use DBD::mysql;

# global variables
use vars qw($conf $dbh $dbconnected);

$dbconnected = '';

#############################################################
# connect to database
#############################################################
sub dbconnect {

  # allow persistance?
  return
    if $dbh and
       $$conf{'persistance'} and
       $$conf{'persistance'} eq 'YES';

  # Name of GnuDIP (mySQL) database
  my $gnudipdatabase = $$conf{'gnudipdatabase'};

  # User name to connect to the database
  my $gnudipuser = $$conf{'gnudipuser'};

  # Password to connect to the database
  my $gnudippass = $$conf{'gnudippassword'};

  # Host where the database server resides
  my $gnudipserver = $$conf{'gnudipserver'};

  $gnudipdatabase = '' if !defined($gnudipdatabase);
  $gnudipuser     = '' if !defined($gnudipuser);
  $gnudippass     = '' if !defined($gnudippass);
  $gnudipserver   = '' if !defined($gnudipserver);

  # connect to database
  my $gnudipconn = "dbi:mysql:dbname=$gnudipdatabase";
  $gnudipconn = "dbi:mysql:dbname=$gnudipdatabase;host=$gnudipserver"
      if $gnudipserver;
  $dbh = DBI->connect(
    $gnudipconn,
    $gnudipuser,
    $gnudippass
    );
  if (!$dbh) {
    my $str = $DBI::errstr;
    writelog('Could not connect to MySQL database:');
    writelog("  message: $str");
    dberror();
  }
}

#############################################################
# execute an SQL statement and catch errors
#############################################################
sub dbexecute {
  my $statement = shift;

  if (! $dbconnected) {
    dbconnect();
    $dbconnected = 1;
  }

  my $sth = $dbh->prepare($statement);
  if (!$sth) {
    my $str = $DBI::errstr;
    writelog('Could not prepare SQL statement:');
    writelog("  statement: $statement");
    writelog("  message:   $str");
   dberror();
  }

  my $rc = $sth->execute;
  if (!$rc) {
    my $str = $DBI::errstr;
    writelog('Could not execute SQL statement:');
    writelog("  statement: $statement");
    writelog("  message:   $str");
    dberror();
  }

  return $sth;
}

#####################################################
# must return 1
#####################################################
1;

