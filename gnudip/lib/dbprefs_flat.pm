#####################################################
# dbprefs_flat.pm
#
# These routines handle the globalprefs and domains
# "tables" using flat files.
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

#####################################################
# get preferences from file
#####################################################
sub getprefs {

  # allow persistance?
  return $dbprefs_pref 
    if $dbprefs_pref and
       $$conf{'persistance'} and
       $$conf{'persistance'} eq 'YES';

  # reference to globalprefs hash
  my %prefhash;
  $dbprefs_pref = \%prefhash;

  # file for globalprefs
  my $preffile = $$conf{'globalprefs_file'};
  $preffile = "$gnudipdir/run/database/globalprefs" if ! $preffile;

  # file exists?
  if (! -f $preffile) {
    # create it
    setprefdflt($dbprefs_pref);
    $prefhash{'DOMAINS'} = '';
    updateprefs($dbprefs_pref);
    return $dbprefs_pref;
  }

  # read it
  local *PREF;
  if (! open (PREF, "<$preffile")) {
    writelog("getprefs: cannot open $preffile: $!");
    dberror();
  }
  read(PREF, my $data, 5000);
  close PREF;

  # parse the globalprefs string
  foreach my $line (split(/\n/, $data)) {
    if ($line =~ /^(.*?)\#(.*)$/) {
      $line = $1;
    }    
    if ($line =~ /^\s*(\w[-\w|\.]*)\s*=\s*(.*?)\s*$/) {
      $prefhash{$1} = $2;
    }
  }

  # ensure initialised
  setprefdflt($dbprefs_pref);

  return $dbprefs_pref;
}

#####################################################
# update preferences in database
#####################################################
sub updateprefs {
  my $pref = shift;

  # construct globalprefs string
  my $data = '';
  foreach my $param (prefscmnlist()) {
    $data .= "$param = $$pref{$param}\n";
  }
  $data .= "DOMAINS = $$pref{'DOMAINS'}\n";
  foreach my $domain (split(/:/, $$pref{'DOMAINS'})) {
    $data .= "CHANGEPASS.$domain = " . $$pref{"CHANGEPASS.$domain"} . "\n";
    $data .= "ADDSELF.$domain = " . $$pref{"ADDSELF.$domain"} . "\n";
  }

  # file for globalprefs
  my $preffile = $$conf{'globalprefs_file'};
  $preffile = "$gnudipdir/run/database/globalprefs" if ! $preffile;

  # write over file
  local *PREF;
  if (! open (PREF, ">$preffile")) {
    writelog("updateprefs: cannot open $preffile: $!");
    dberror();
  }
  print PREF $data;
  close PREF;

  # restrict permissions
  chmod 0600, ($preffile);
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

  # has getprefs been called?
  getprefs() if ! defined $dbprefs_pref;

  my @domains;
  $dbprefs_domains = \@domains;

  # append each domain to list
  return $dbprefs_domains if ! defined $$dbprefs_pref{'DOMAINS'};
  $$dbprefs_pref{'DOMAINS'} =~ s/ //g;
  my $dnum = 0;
  foreach my $domain (split(/:/, $$dbprefs_pref{'DOMAINS'})) {
    # create result hash reference
    my %domhash;
    my $dinfo = \%domhash;
    $dnum++;
    $$dinfo{'id'}         = $dnum;
    $$dinfo{'domain'}     = $domain;
    $$dinfo{'changepass'} = $$dbprefs_pref{"CHANGEPASS.$domain"};
    $$dinfo{'addself'}    = $$dbprefs_pref{"ADDSELF.$domain"};
    setdomdflt($dinfo);
    push(@domains,($dinfo));
  }

  return $dbprefs_domains;
}

#####################################################
# get domain
#####################################################
sub getdomain {
  my $domain = shift;

  # has getprefs been called?
  getprefs() if ! defined $dbprefs_pref;

  # domain exists?
  return undef if ! defined $$dbprefs_pref{'DOMAINS'};
  $$dbprefs_pref{'DOMAINS'} =~ s/ //g;
  my $dnum = 0;
  my $cnt = 0;
  foreach my $dom (split(/:/, $$dbprefs_pref{'DOMAINS'})) {
    $cnt++;
    if (lc($dom) eq lc($domain)) {
      $dnum = $cnt;
      last;
    }
  }
  return undef if ! $dnum;

  # create result hash reference
  my %domhash;
  my $dinfo = \%domhash;
  $$dinfo{'id'}         = $dnum;
  $$dinfo{'domain'}     = $domain;
  $$dinfo{'changepass'} = $$dbprefs_pref{"CHANGEPASS.$domain"};
  $$dinfo{'addself'}    = $$dbprefs_pref{"ADDSELF.$domain"};
  setdomdflt($dinfo);

  return \%domhash;
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

  # already exists?
  if (getdomain($domain)) {
    writelog("createdomain: domain $domain already exists");
    dberror();
  }

  # add domain to list  
  $$dbprefs_pref{'DOMAINS'} =~ s/ //g;
  if ($$dbprefs_pref{'DOMAINS'}) {
    $$dbprefs_pref{'DOMAINS'} .= ":$domain";
  } else {
    $$dbprefs_pref{'DOMAINS'} = "$domain";
  }
  $$dbprefs_pref{"CHANGEPASS.$domain"} = $changepass;
  $$dbprefs_pref{"ADDSELF.$domain"}    = $addself;

  updateprefs($dbprefs_pref);

  # get back from database with "id"
  return getdomain($domain);
}

#############################################################
# update domain
#############################################################
sub updatedomain {
  my $dinfo = shift;

  # has getprefs been called?
  getprefs() if ! defined $dbprefs_pref;

  # domain exists?
  if (! $$dbprefs_pref{'DOMAINS'}) {
    writelog("updatedomain: domain number $$dinfo{'id'} does not exist - no domains");
    dberror();
  }
  $$dbprefs_pref{'DOMAINS'} =~ s/ //g;

  # scan domain list
  my $olddomain;
  my $domains;
  my $cnt = 0;
  foreach my $dom (split(/:/, $$dbprefs_pref{'DOMAINS'})) {
    $cnt++;
    if ($cnt eq $$dinfo{'id'}) {
      $olddomain = $dom;
      $dom = $$dinfo{'domain'};
    }
    if ($cnt eq 1) {
      $domains = $dom;
    } else {
      $domains .= ":$dom";
    }
  }

  # domain name changed?
  if ($olddomain ne $$dinfo{'domain'}) {
    $$dbprefs_pref{'DOMAINS'} = $domains;
    $$dbprefs_pref{"CHANGEPASS.$olddomain"} = undef;
    $$dbprefs_pref{"ADDSELF.$olddomain"}    = undef;
  }

  $$dbprefs_pref{"CHANGEPASS.$$dinfo{'domain'}"} = $$dinfo{'changepass'};
  $$dbprefs_pref{"ADDSELF.$$dinfo{'domain'}"}    = $$dinfo{'addself'};

  updateprefs($dbprefs_pref);
}

#############################################################
# delete domain
#############################################################
sub deletedomain {
  my $dinfo = shift;

  # has getprefs been called?
  getprefs() if ! defined $dbprefs_pref;

  # domain exists?
  if (! $$dbprefs_pref{'DOMAINS'}) {
    writelog("deletedomain: domain number $$dinfo{'id'} does not exist - no domains");
    dberror();
  }
  $$dbprefs_pref{'DOMAINS'} =~ s/ //g;

  # scan domain list
  my $olddomain;
  my $domains;
  my $cnt = 0;
  foreach my $dom (split(/:/, $$dbprefs_pref{'DOMAINS'})) {
    $cnt++;
    if ($cnt eq $$dinfo{'id'}) {
      $olddomain = $dom;
    } else {
      if ($cnt eq 1) {
        $domains = $dom;
      } else {
        $domains .= ":$dom";
      }
    }
  }

  # domain exists?
  if (! $olddomain) {
    writelog("deletedomain: domain number $$dinfo{'id'} does not exist");
    dberror();
  }

  $$dbprefs_pref{'DOMAINS'} = $domains;
  $$dbprefs_pref{"CHANGEPASS.$olddomain"} = undef;
  $$dbprefs_pref{"ADDSELF.$olddomain"}    = undef;

  updateprefs($dbprefs_pref);
}

#############################################################
# ensure all globalprefs fields initialised
#############################################################
sub setprefdflt {
  my $pref = shift;
  prefscmndflt($pref);
  $$pref{'DOMAINS'} = '' if ! defined $$pref{'DOMAINS'};
}

#####################################################
# must return 1
#####################################################
1;

