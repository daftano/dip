#######################################################################
# htmlgen.pm
#
# These routines generate the HTML for the GnuDIP
# Web interface.
#
# See COPYING for licensing information.
#
#######################################################################

# Perl modules
use strict;

# global variables
use vars qw($conf);
use vars qw($pref $userinfo $remote_ip);
use vars qw($reqparm $thiscgi $thishost $thisurl);
use vars qw($htmlgen_header $htmlgen_trailer);

# GnuDIP common subroutines
use gdiplib;
use gdipcgi_cmn;
use gdipmailchk;

# variables global to this file
# - may be included in all pages
my ($title, $head, $headtxt, $topline, $trailerline, $bodytxt, $body, $bodyend, $html_dir);

#######################################################################
# initialise global variables
#######################################################################
sub htmlgen_init {

  # title
  $title      = "GnuDIP Web Interface";
  $headtxt    = tst(qq*
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<title>$title</title>*);
  $head       = tst(qq*
<head>
$headtxt
</head>*);

  # HTML to insert after <body>
  if (! defined $htmlgen_header or
      ! defined $$conf{'persistance'} or
      $$conf{'persistance'} ne 'YES') {
    my $headerfile = $$conf{'header_file'};
    $headerfile = '' if !defined($headerfile);
    $htmlgen_header = '';
    if ($headerfile and open(HEADER,"$headerfile")) {
      while (my $line = <HEADER>) {
        $htmlgen_header .= $line;
      };
    close HEADER;
    }
  }


  # HTML to insert before </body>
  if (! defined $htmlgen_trailer or
      ! defined $$conf{'persistance'} or
      $$conf{'persistance'} ne 'YES') {
    my $trailerfile = $$conf{'trailer_file'};
    $trailerfile = '' if !defined($trailerfile);
    $htmlgen_trailer = '';
    if ($trailerfile and open(TRAILER,"$trailerfile")) {
      while (my $line = <TRAILER>) {
        $htmlgen_trailer .= $line;
      };
    close TRAILER;
    }
  }

  # offset to HTML directory
  $html_dir = $$conf{'html_dir'};
  $html_dir = '../html' if !$html_dir;

  # stuff for top of each page
  $topline    = $htmlgen_header . tst(qq*
<center><table><tr>
  <td>
    <img align=middle src="$html_dir/gnudip.jpg" alt="GnuDIP Logo"
           border=0 height=60 width=113>
    </td>
  <td><table>
    <tr><td><center><h1>$title</h1></center></td></tr>
    <tr><td width="100%"><table width="100%" border=1><tr>
      <td><center>
        <a href="$html_dir/help.html" target=_blank>Help</a>
        </center></td>
      </tr></table></td></tr>
    </table></td>
</tr></table></center>*);

  # for starting and ending HTML body
  $bodytxt    = "body bgcolor=\"FFFFFF\"";
  $body       = "<$bodytxt>";
  $bodyend    = $htmlgen_trailer . '</body>';
}

#######################################################################
# login
#######################################################################
sub pg_login {
  header();
  tpr(qq*
<html>
<head>
$headtxt
<script type="text/javascript">
function sethidden() {
  document.forms["login"].localaddr.value="nojava";
  document.forms["login"].localaddr.value=document.IPdetect.getLocal();
  document.forms["login"].errormsg.value=document.IPdetect.getMsg();
}
</script>
</head>
<$bodytxt onload="sethidden()">
$topline
<center><h2>Login</h2></center>
<form action="$thiscgi" method="post" name="login">
<input type=hidden name="page" value="login">
<input name="localaddr" type=hidden value="nojavascript">
<input name="errormsg" type=hidden value="">
<center>
<table>
<tr>
  <td>Username/Hostname</td>
  <td><input type="text" name="username"></td>
</tr>
*);
  if ($$pref{'SHOW_DOMAINLIST'} eq 'YES') {
    html_domain('','domain');
  } else {
    tpr(qq*
<tr>
  <td>Domain</td>
  <td><input type="text" name="domain"></td></tr>
*);
  }
  tpr(qq*
<tr>
  <td>Password</td>
  <td><input type="password" name="password"></td>
</tr>
</table>
<table><tr>
<td>
<input type="submit" name="login"   value="Login">
</td>
*);
  if ($$pref{'SEND_URL'} eq 'YES') {
    if (!$$conf{'URL_sendURL'}) {
      tpr(qq*
<td>
<input type="submit" name="sendURL" value="Forgotten Password">
</td>
*);
    } else {
      tpr(qq*
<td>
<table border=1><tr><td>
<a href="$$conf{'URL_sendURL'}">Forgotten Password</a>
</td></tr></table>
</td>
*);
    }
  }
  if ($$pref{'ADD_SELF'} eq 'YES') {
    if (!$$conf{'URL_self_signup'}) {
      tpr(qq*
<td>
<input type="submit" name="self_signup" value="Self Register">
</td>
  *);
    } else {
      tpr(qq*
<td>
<table border=1><tr><td>
<a href="$$conf{'URL_self_signup'}">Self Register</a>
</td></tr></table>
</td>
*);
    }
  }
  tpr(qq*
</tr></table>
</center>
</form>
$htmlgen_trailer<applet codebase="$html_dir/" code="IPdetect.class" name="IPdetect"
        height=0 width=0>
</applet>
</body>
</html>
*);
  exit;
}

#######################################################################
# forgotten password
#######################################################################
sub pg_sendURL {
  # ensure initialized
  default_empty('sendURL_username');

  header();
  tpr(qq*
<html>
<head>
$headtxt
</head>
$body
$topline
<center><h2>Forgotten Password</h2>
<font color="red" size="+1">
Enter your username and domain
<br>
A Quick Login URL will be sent to the E-mail address on record
</font></center>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="sendURL">
<center>
<table>
<tr>
  <td>Username/Hostname</td>
  <td><input type="text" name="sendURL_username" value="$$reqparm{'sendURL_username'}"></td>
</tr>
*);
  if ($$pref{'SHOW_DOMAINLIST'} eq 'YES') {
    html_domain('','domain');
  } else {
    tpr(qq*
<tr>
  <td>Domain</td>
  <td><input type="text" name="domain"></td></tr>
*);
  }
  tpr(qq*
</table>
*);

  # ensure not a robot
  mchk_html();

  tpr(qq*
<br>
<input type="submit" name="do_sendURL" value="Send E-mail">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# Quick Login URL E-mail sent
#######################################################################
sub pg_sentURL {
  my $email = shift;

  pg_msg(qq*
Quick Login URL E-mail Sent
*,qq*
An E-mail has been sent to the E-mail address on record for this host,
containing a Quick Login URL (i.e., www address).<br>
When you receive the E-mail, connect to the URL in your browser to
login.
*);
}

#######################################################################
# self signup
#######################################################################
sub pg_self {
  pg_error("no_addself") if $$pref{'ADD_SELF'} ne 'YES';

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center><h2>Self Registration</h2></center>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="doself">
<center>
<table>
<tr><td>Username/Hostname</td>
    <td><input type="text" name="new_username"></td>
</tr>
*);

  tpr(qq*
<tr><td>Domain</td>
    <td>
    <select name="new_domain">
*);
  my $domains = getdomains();
  foreach my $domain (@$domains) {
    if ($$domain{'addself'} eq 'YES') {
      tpr(qq*
    <option value="$$domain{'domain'}">$$domain{'domain'}</option>
*);
    }
  }
  tpr(qq*
    </select>
    </td></tr>
*);

  tpr(qq*
<tr><td>E-Mail Address</td>
    <td><input type="text" name="new_email"></td>
</tr>
<tr><td>Password</td>
    <td><input type="password" name="new_password" value=""></td>
</tr>
<tr><td>Password Again</td>
    <td><input type="password" name="new_password1" value=""></td>
</tr>
</table>
</center>
*);

  # ensure not a robot
  mchk_html();

  tpr(qq*
<br>
<center><input type="submit" name="do_signup" value="Register">&nbsp;
        <input type="reset" value="Clear Form">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# self signup E-mail sent
#######################################################################
sub pg_selfemail {
  my $email = shift;

  pg_msg(qq*
Self Registration E-mail Sent
*,qq*
An E-mail has been sent to $email, containing a URL (i.e., www address).<br>
When you receive the E-mail, connect to the URL in your browser to
complete the self registration process.
*);
}

#######################################################################
# self signup done
#######################################################################
sub pg_didself {
  pg_msg(qq*
Registration Successful
*,qq*
Your registration was successful.<br>
Please return to the login page.
*);
}

#######################################################################
# E-mail update E-mail sent
#######################################################################
sub pg_newemail {
  my $email = shift;

  pg_msg(qq*
E-mail Update E-mail Sent
*,qq*
An E-mail has been sent to $email, containing a URL (i.e., www address).<br>
When you receive the E-mail, connect to the URL in your browser to
complete the E-mail address update process.
*);
}

#######################################################################
# E-mail update done
#######################################################################
sub pg_didemail {
  pg_msg(qq*
E-mail Address Update Successful
*,qq*
Your E-mail address update was successful.
*);
}

#######################################################################
# no forward URL set
#######################################################################
sub pg_noforwardurl {
  pg_msg(qq*
Auto Update Successful but Forward URL Not Set
*,qq*
Your username and password were verified and your hostname now points
to your new IP <i>$remote_ip</i>.
<p>
However you have not set a URL to forward to.
<br>
Please set a Forward URL in your GnuDIP settings.
*);
}

#######################################################################
# AutoURL test succeeded
#######################################################################
sub pg_goodautourl {
  pg_msg(qq*
AutoURL Test Succeeded
*,qq*
Your username and password were verified and your hostname
now points to your new IP <i>$remote_ip</i>.
<p>
Set this page as your default page and from now on it will
automatically forward you to your Forward URL under the
settings menu.
*);
}

#######################################################################
# user options
#######################################################################
sub pg_options {

  # ensure initialized
  default_empty('localaddr');
  default_empty('user_pattern');
  default_empty('errormsg');

  header();
  tpr(qq*
<html>
$head
$body
*);
  if ($$pref{'DELETE_SELF'} eq 'YES' and !$$conf{'URL_delthisuser'}) {
    tpr(qq*
<script type="text/javascript">
function test() {
  message=("Delete Current User?")
  if(confirm(message)) {
     return true
  } else {
    return false
  }     
}
</script>
*);
  }
  tpr(qq*
$topline
*);
  my $updateaddr = $remote_ip;
  if ($$userinfo{'level'} eq 'USER') {
    tpr(qq*
<center>
<font color="red" size="+1">
Hostname $$userinfo{'username'}.$$userinfo{'domain'}
  Currently Points to $$userinfo{'currentip'}
<br>
<i>(Updated at $$userinfo{'updated'})</i>
</font>
<p>
<font color="red" size="+1">
The computer that connected to GnuDIP has IP address $remote_ip
</font>
<p>
<font color="red" size="+1">
*);
    if  ($$reqparm{'localaddr'} eq 'nojavascript') {
      tpr(qq*
GnuDIP cannot determine if $remote_ip is the IP address of your
computer.
<br>
Javascript is not enabled in your browser.
*);
    } elsif ($$reqparm{'localaddr'} eq 'nojava') {
      tpr(qq*
GnuDIP cannot determine if $remote_ip is the IP address of your
computer.
<br>
Java is not enabled in your browser.
*);
    } elsif ($$reqparm{'localaddr'} eq 'javaerror') {
      writelog('Error occured in Java applet:');
      writelog("  message: $$reqparm{'errormsg'}");
      tpr(qq*
GnuDIP cannot determine if $remote_ip is the IP address of your
computer.
<br>
The Java applet for doing this has failed with the following message:
<blockquote>
$$reqparm{'errormsg'}
</blockquote>
*);
    } elsif (validdotquad($$reqparm{'localaddr'})) {
      $updateaddr = $$reqparm{'localaddr'};
      tpr(qq*
The computer your browser is running on has IP address $updateaddr
*);
    } elsif ($$reqparm{'localaddr'}) {
      writelog('Error occured in Java applet:');
      writelog("  invalid IP address: $$reqparm{'localaddr'}");
      tpr(qq*
GnuDIP cannot determine if $remote_ip is the IP address of your
computer.
<br>
The Java applet for doing this has failed. It returned an invalid IP
address.
*);
    } else {
      tpr(qq*
Browser based IP address detection was not done
*);
    }
    tpr(qq*
</font>
</center>
*);
  }
  tpr(qq*
<center><h2>User Options</h2></center>
*);
  if ($$reqparm{'updatehost'}) {
    tpr(qq*
<center><font size="+1"><b>
  Update done for $$userinfo{'username'}.$$userinfo{'domain'}
  </b></font></center>
  <p>
*);
  } elsif ($$reqparm{'offline'}) {
    tpr(qq*
<center><font size="+1"><b>
  Offline done for $$userinfo{'username'}.$$userinfo{'domain'}
  </b></font></center>
  <p>
*);
  }
  tpr(qq*
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="options">
*);
  html_user();
  $$reqparm{'updateaddr'} = $updateaddr if ! defined $$reqparm{'updateaddr'};
  tpr(qq*
<input type=hidden name="localaddr" value="$$reqparm{'localaddr'}">
<input type=hidden name="errormsg" value="$$reqparm{'errormsg'}">
<center>
<table>
*);
  if ($$userinfo{'level'} eq "USER") {
    tpr(qq*
<tr><td>Update <b>$$userinfo{'username'}.$$userinfo{'domain'}</b></td>
    <td><input type=submit name="updatehost" value="Go"></td>
    </tr>
<tr><td align="center">to</td>
    <td><input type=text name="updateaddr" value="$$reqparm{'updateaddr'}"></td>
    </tr>
<tr><td>Offline <b>$$userinfo{'username'}.$$userinfo{'domain'}</b></td>
    <td><input type=submit name="offline" value="Go"></td>
    </tr>
*);
  }
  tpr(qq*
<tr><td>Change Settings</td>
    <td><input type=submit name="changesettings" value="Go"></td>
    </tr>
*);
  if ($$userinfo{'level'} eq 'USER' and 
      $$pref{'REQUIRE_EMAIL'} eq 'YES') {
    tpr(qq*
<tr><td>Change E-mail Address</td>
    <td><input type=submit name="changemail" value="Go"></td>
    </tr>
*);
  }
  if ($$userinfo{'level'} eq 'USER' and 
      $$pref{'ALLOW_AUTO_URL'} eq 'YES') {
    tpr(qq*
<tr><td>Set Auto URL</td>
    <td><input type=submit name="setautourl" value="Go"></td>
    </tr>
*);
  }
  if ($$userinfo{'level'} eq 'ADMIN') {
    tpr(qq*
<tr><td>Add User</td>
    <td><input type=submit name="manageusers_adduser" value="Go"></td>
    </tr>
<tr><td>Manage Users</td>
    <td><input type=submit name="manageusers_main" value="Go"></td>
    </tr>
<tr><td>&nbsp;</td>
    <td>User Pattern:</td>
    <td><input type=text name="user_pattern"
               value="$$reqparm{'user_pattern'}"></td>
    </tr>
<tr><td>&nbsp;</td>
    <td>&nbsp;</td>
    <td><table>
      <tr><td>\*</td><td>-</td><td>zero or more characters</td></tr>
      <tr><td>?</td><td>-</td><td>one character</td></tr>
     </table></td>
<tr><td>Add Domain</td>
    <td><input type=submit name="managedomains_add" value="Go"></td>
    </tr>
<tr><td>Manage Domains</td>
    <td><input type=submit name="managedomains_main" value="Go"></td>
    </tr>
<tr><td>Administrative Settings</td>
    <td><input type=submit name="system_settings" value="Go"></td>
    </tr>
*);
  }
   
  if ($$pref{'DELETE_SELF'} eq 'YES') {
    tpr(qq*
<tr><td>&nbsp;</td></tr>
<tr><td>Delete Current User</td><td>
*);
    if (!$$conf{'URL_delthisuser'}) {
      tpr(qq*
  <input type=submit name="do_delthisuser" value="Delete"
               onclick="return test()">
*);
    } else {
      # sign the self delete information
      my $checkval  = md5_base64(
        $$userinfo{'username'} . '.' .
        $$userinfo{'domain'}   . '.' .
        $$pref{'SERVER_KEY'}
        );
      # the URL must have a question mark and any other
      # parameters already in it
      my $url  = $$conf{'URL_delthisuser'};
         $url .= 'user='     . $$userinfo{'username'};
         $url .= '&amp;domn=' . $$userinfo{'domain'};
         $url .= '&amp;sign=' . uri_escape($checkval);
      tpr(qq*
  <table border=1><tr><td>
  <a href="$url">Delete</a>
  </td></tr></table>
*);
    }
    tpr(qq*
  </td></tr>
*);
  }
  tpr(qq*
</table>
</center>
</form>
*);

  # button for setting Quick Login
  my $detect;
  my $quick = "$thisurl?";
  if ($updateaddr eq $$reqparm{'localaddr'}) {
    $quick .= 'login=ipdetect';
    $detect = 'yes';
  } else {
    $quick .= 'login=enc';
    $detect = 'no';
  }
  $quick .=
    "&amp;username=$$userinfo{'username'}" .
    "&amp;password=$$userinfo{'password'}";
  if ($$userinfo{'level'} eq 'USER') {
    $quick .= "&amp;domain=$$userinfo{'domain'}";
  }
  tpr(qq*
<form action="$quick" method="post">
<input type=hidden name="page" value="options">
*);
  html_user();
  tpr(qq*
<input type=hidden name="detect" value="$detect">
<input type=hidden name="quick" value="$quick">
<center>
<input type=submit name="setquick" value="Set Quick Login URL">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# user settings
#######################################################################
sub pg_usersettings {
  pg_cmn_edituser($userinfo);
}

#######################################################################
# current user deleted
#######################################################################
sub pg_usergone {
  pg_msg(qq*
Current User Deleted
*,qq*
The current user has been deleted.
<br>
Please go back to the previous Login page.
*);
}

#######################################################################
# set quick login
#######################################################################
sub pg_setquick {

  # "&" has to become "&amp;" in HTML
  my $quick = $$reqparm{'quick'};
  $quick =~ s/\&/\&amp;/g;

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center>
<h2>Set Quick Login URL</h2>
<h3>Create a new Favorite or Bookmark now</h3>
<p>
<h3>Or in Windows create a Shortcut<br>Right click on this link:</h3>
<p>
<table border=2><tr><td>
<a href="$quick">GnuDIP Quick Login</a>
</td></tr></table>
<p>
The Favorite, Bookmark or Shortcut will do Quick Login.
*);
  if ($$reqparm{'detect'} eq 'no') {
    tpr(q*
<p>
<font color=red>
This URL will not do IP address detection.
<br>
Either Javascript or Java is not enabled in your browser.
</font>
*);
  }
  tpr(qq*
</center>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# Quick Login IP detection
#######################################################################
sub pg_ipdetect {
  header();
  tpr(qq*
<html>
<head>
$headtxt
<script type="text/javascript">
function winload() {
  var newurl;
  newurl = "$thisurl?" +
    "login=enc&username=$$reqparm{'username'}&" +
    "domain=$$reqparm{'domain'}&password=$$reqparm{'password'}";
  newurl += "&localaddr=" + document.IPdetect.getLocal();
  if (document.IPdetect.getLocal() == "javaerror")
    newurl += "&errormsg=" + document.IPdetect.getMsg();
  window.location.replace(newurl);
}
</script>
</head>
<$bodytxt onload=\"winload()\">
<noscript>
<p>
<font color=red>
Javascript support is not enabled in this browser.
</font>
Javascript support is required for IP address detection.
</noscript>
<applet codebase="$html_dir/" code="IPdetect.class"
        name="IPdetect" height=0 width=0>
<p>
<font color=red>
Java support is not enabled in this browser.
</font>
Java support is required for IP address detection.
</applet>
</body>
</html>
*);
  exit;
}

#######################################################################
# add domain
#######################################################################
sub pg_adddomain {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center>
<h2>Add Domain</h2>
<font color="red">
New domains are added at the end of the list
</font>
<p>
<font color="red">
You may delete and re-add a domain
<br>
Updates using the client will not be affected
<br>
Web Tool users for that domain cannot login until the domain is re-added
</font>
</center>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="adddomain">
*);
  html_user();
  default_empty('adddomain_new_domain');
  default_empty('ALLOW_CHANGEPASS');
  default_empty('ADDSELF');
  my $check_pass = setcheck($$reqparm{'ALLOW_CHANGEPASS'});
  my $check_self = setcheck($$reqparm{'ADDSELF'});
  tpr(qq*
<center>
<table>
<tr><td>Domain Name</td>
   <td><input type="text" name="adddomain_new_domain" value="$$reqparm{'adddomain_new_domain'}"></td></tr>
<tr><td>Allow Password Changes</td>
    <td><input type="checkbox" name="ALLOW_CHANGEPASS" value="YES" $check_pass></td></tr>
<tr><td>Self Registration</td>
    <td><input type="checkbox" name="ADDSELF" value="YES" $check_self></td></tr>
</table>
<br>
<input type="submit" name="do_adddomain" value="Add Domain">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# manage domains
#######################################################################
sub pg_managedomains {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # get domains from database
  my $domains = getdomains();

  header();
  tpr(qq*
<html>
$head
$body
<script type="text/javascript">
function test() {
  message=("Delete Selected Domains?")
  if(confirm(message)) {
     return true
  } else {
    return false
  }     
}
</script>
$topline
<center><h2>Manage Domains</h2></center>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="managedomains">
*);
  html_user();
  tpr(qq*
<center>
<table border=1>
<tr>
  <th>Domain</th>
  <th>Allow Password Changes</th>
  <th>Allow Add Self</th>
  <th>Edit Domain</th>
  <th>Delete Domain</th></tr>
*);
  foreach my $dominfo (@$domains) {
    tpr(qq*
<tr align="center">
  <td>$$dominfo{'domain'}</td>
  <td>$$dominfo{'changepass'}</td>
  <td>$$dominfo{'addself'}</td>
  <td><input type=radio name="editdom" value="$$dominfo{'domain'}"></td>
  <td><input type=checkbox name="deldom" value="$$dominfo{'domain'}"></td></tr>
*);
  }
  tpr(qq*
</table>
<br>
<br>
<input type=submit name="managedomains_edit" value="Edit Selected Domain">
&nbsp;
<input type=submit name="do_deldomain" value="Delete Selected Domains"
                   onclick="return test()">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# edit domain
#######################################################################
sub pg_editdomain {
  my $dinfo = shift;

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # domain not passed but domain name available?
  if (!$dinfo and $$reqparm{'editdom'}) {
    $dinfo = getdomain($$reqparm{'editdom'});
    pg_error('bad_sel_domain') if !$dinfo;
  }

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center><h2>Edit Domain</font></h2></center>
*);

 # do we have a domain to edit?
 if (!$dinfo) {
   tpr(qq*
<center>
<h3>
No domain has been selected
<br>
Please go back and select a domain
</h3>
</center>
$bodyend
</html>
*);
    exit;
  }

  # reshowing this page?
  if ($$reqparm{'do_editdomain'}) {
    tpr(qq*
<center><font size="+1"><b>
  Previous changes saved
  </b></font></center>
  <p>
*);
  }

  my $cpcheck = setcheck($$dinfo{'changepass'});
  my $ascheck = setcheck($$dinfo{'addself'});
  tpr(qq*
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="editdomain">
*);
  html_user();
  tpr(qq*
<input type=hidden name="editdom" value="$$dinfo{'domain'}">
<center>
<table>
<tr><td>Domain</td>
    <td><input type="text" name="new_domain" value="$$dinfo{'domain'}"></td>
    </tr>
<tr><td>Allow Password Changes</td>
    <td><input type="checkbox" name="ALLOW_CHANGEPASS"
        value="YES"$cpcheck></td></tr>
<tr><td>Self Registration</td>
    <td><input type="checkbox" name="ADDSELF"
        value="YES"$ascheck></td></tr>
</table>
<br>
<input type="submit" name="do_editdomain" value="Save Changes">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# add user (by admin)
#######################################################################
sub pg_adduser {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center><h2>Add User</h2></center>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="adduser">
*);
  html_user();
  tpr(qq*
<center>
<table>
<tr><td>Username/Hostname</td>
    <td><input type="text" name="new_username"></td></tr>
*);
  html_domain();
  tpr(qq*
<tr><td>E-Mail Address</td>
    <td><input type="text" name="new_email"></td></tr>
<tr><td>Disable Password</td>
    <td><input type="checkbox" name="disable" value="YES"></td></tr>
<tr><td>New Password</td>
    <td><input type="password" name="new_password" value=""></td></tr>
<tr><td>New Password Again</td>
    <td><input type="password" name="new_password1" value=""></td></tr>
<tr><td>Admin</td>
    <td><input type="checkbox" name="user_level" value="ADMIN"></td></tr>
</table>
<br>
<input type="submit" name="do_adduser" value="Add User">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# manage users
#######################################################################
sub pg_manageusers {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # ensure initialized
  default_empty('orderby');
  default_empty('sortby');
  default_empty('user_pattern');

  # local title
  my $ltitle = 'Manage Users';
  $ltitle .= " - $$reqparm{'user_pattern'}"
    if $$reqparm{'user_pattern'};

  # the red up/down mark
  my $mark = '&lt;';
  $mark = '&gt;' if $$reqparm{'orderby'} eq 'desc';
  $mark = qq*<font size="+2" color="red">$mark</font>*;
  my $byip      = '';
  my $bydomain  = '';
  my $byupdated = '';
  my $bylevel   = '';
  my $byemail   = '';
  my $byuser    = '';
  if ($$reqparm{'manage_users_sortby_currentip'}) {
    $byip      = $mark;
  } elsif ($$reqparm{'manage_users_sortby_domain'}) {
    $bydomain  = $mark;
  } elsif ($$reqparm{'manage_users_sortby_updated'}) {
    $byupdated = $mark;
  } elsif ($$reqparm{'manage_users_sortby_level'}) {
    $bylevel   = $mark;
  } elsif ($$reqparm{'manage_users_sortby_email'}) {
    $byemail   = $mark;
  } else {
    $byuser    = $mark;
  }

  header();
  tpr(qq*
<html>
$head
$body
<script type="text/javascript">
function test() {
  message=("Delete Selected Users?")
  if(confirm(message)) {
     return true
  } else {
    return false
  }     
}
</script>
$topline
<center><h2>$ltitle</h2></center>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="manageusers">
*);
  html_user();
  tpr(qq*
<input type=hidden name="user_pattern" value="$$reqparm{'user_pattern'}">
<input type=hidden name="sortby" value=$$reqparm{'sortby'}>
<input type=hidden name="orderby" value=$$reqparm{'orderby'}>
<center>
<table border=1>
<tr align="center">
  <td><input type=submit name="manage_users_sortby_username"
       value="Sort">$byuser</td>
  <td><input type=submit name="manage_users_sortby_currentip"
       value="Sort">$byip</td>
  <td><input type=submit name="manage_users_sortby_email"
       value="Sort">$byemail</td>
  <td><input type=submit name="manage_users_sortby_domain"
       value="Sort">$bydomain</td>
  <td><input type=submit name="manage_users_sortby_updated"
       value="Sort">$byupdated</td>
  <td><input type=submit name="manage_users_sortby_level"
       value="Sort">$bylevel</td>
  <td>&nbsp;</td>
  <td>&nbsp;</td></tr>
<tr align="center">
  <th>Username</th>
  <th>Current IP</th>
  <th>E-Mail</th>
  <th>Domain</th>
  <th>Last Updated</th>
  <th>Level</th>
  <th>Edit User</th>
  <th>Delete User</th></tr>
*);

  # one row for each user
  my $sth =
   getuserspattern(
     $$reqparm{'user_pattern'},
     $$reqparm{'sortby'},
     $$reqparm{'orderby'}
     );
  while (my $uinfo = getuserseach($sth)) {
    $$uinfo{'email'}  = '&nbsp;' if !$$uinfo{'email'};
    $$uinfo{'domain'} = '&nbsp;' if !$$uinfo{'domain'};
    tpr(qq*
<tr align="center">
  <td>$$uinfo{'username'}</td>
  <td>$$uinfo{'currentip'}</td>
  <td>$$uinfo{'email'}</td>
  <td>$$uinfo{'domain'}</td>
  <td>$$uinfo{'updated'}</td>
  <td>$$uinfo{'level'}</td>
  <td><input type=radio name="edituser" value="$$uinfo{'id'}"></td>
  <td><input type=checkbox name="deluser" value="$$uinfo{'id'}"></td></tr>
*);
  }

  tpr(qq*
</table>
<br>
<br>
<input type=submit name="manageusers_edituser" value="Edit Selected User">
&nbsp;
<input type=submit name="do_deluser" value="Delete Selected Users"
   onclick="return test()">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# edit user
#######################################################################
sub pg_edituser {
  my $uinfo = shift;

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  # user not passed but one ID-ed?
  if (!$uinfo and $$reqparm{'edituser'}) {

    # user exists?
    $uinfo = getuserbyid($$reqparm{'edituser'});
    pg_error('bad_sel_user') if !$uinfo;
  }

  # show common page
  pg_cmn_edituser($uinfo);
}

########################################################################
# common user edit page
# - cases distinguished by:
#   $$reqparm{'do_edituser'} or $$reqparm{'manageusers_edituser'}
########################################################################
sub pg_cmn_edituser {
  my $uinfo = shift;

  # differences for each case
  my $ltitle = '';
  my $submit = '';
  my $page   = '';
  if ($$reqparm{'do_edituser'} or $$reqparm{'manageusers_edituser'}) {
    $ltitle = 'Edit User';
    $submit = 'do_edituser';
    $page   = 'edituser';
  } else {
    $ltitle = 'Current Settings';
    $submit = 'do_updatesettings';
    $page   = 'updatesettings';
  }

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center><h2>$ltitle</h2></center>
*);

 # do we have a user to edit?
 if (!$uinfo) {
   tpr(qq*
<center>
<h3>
No user has been selected
<br>
Please go back and select a user
</h3>
</center>
$bodyend
</html>
*);
    exit;
  }

  # reshowing this page?
  if ($$reqparm{'do_updatesettings'} or
      $$reqparm{'do_edituser'}) {
    tpr(qq*
<center><font size="+1"><b>
  Previous changes saved
  </b></font></center>
  <p>
*);
  }

  tpr(qq*
<center><font color="red">
  Note: Leave Password Fields Blank to Remain the Same
  </font></center>
<p>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="$page">
*);
  html_user();

  # save ID of user if not editing self
  if ($$reqparm{'edituser'}) {
    tpr(qq*
<input type=hidden name="edituser" value="$$reqparm{'edituser'}">
*);
  }

  tpr(qq*
<center>
<table>
<tr><td>Username/Hostname</td>
    <td><input type="text" name="new_username"
         value="$$uinfo{'username'}"></td>
</tr>
<tr><td>E-Mail Address</td><td>
*);
  if ($$userinfo{'level'} eq 'USER' and 
      $$pref{'REQUIRE_EMAIL'} eq 'YES') {
    tpr(qq*
<table border=1><tr><td>$$uinfo{'email'}</td></tr></table>
*);
  } else {
    tpr(qq*
<input type="text" name="new_email" value="$$uinfo{'email'}" size="40">
*);
  }
  tpr(qq*
</td></tr>
*);

  # user being edited not admin?
  if ($$uinfo{'level'} ne 'ADMIN') {

    # domain list
    html_domain($$uinfo{'domain'});

    # autoURL
    if ($$pref{'ALLOW_AUTO_URL'} eq 'YES') {
      tpr(qq*
<tr><td>Forward URL
    <font color="red">(Do not forget <b>http://</b>)</font></td>
    <td><input type="text" size=40 name="forwardurl"
         value="$$uinfo{'forwardurl'}"></td>
</tr>
*);
    }

    # not editing self?
    if ($$reqparm{'do_edituser'} or $$reqparm{'manageusers_edituser'}) {

      # wildcards user by user?
      if ($$pref{'ALLOW_WILD'} eq 'USER') {
        my $checked = setcheck($$uinfo{'allowwild'});
        tpr(qq*
<tr><td>Allow Wild Card</td>
    <td><input type="checkbox" name="allow_wildcard"
         value="YES" $checked></td></tr>
*);
      }

      # MX values user by user?
      if ($$pref{'ALLOW_MX'} eq 'USER') {
        my $checked = setcheck($$uinfo{'allowmx'});
        tpr(qq*
<tr><td>Allow Mail Exchanger</td>
    <td><input type="checkbox" name="allow_mx" value="YES"$checked></td></tr>
*);
      }

      my $currentip = $$uinfo{'currentip'};
      $currentip = '' if $currentip eq '0.0.0.0';
      tpr(qq*
<tr><td>IP Address</td>
    <td><input type="text" name="new_IPaddress" value="$currentip"></td>
</tr>
*);

    }

    # show wildcard option?
    if ($$pref{'ALLOW_WILD'} eq 'YES' or
        $$pref{'ALLOW_WILD'} eq 'USER' and $$uinfo{'allowwild'} eq 'YES') {
      my $checked = setcheck($$uinfo{'wildcard'});
      tpr(qq*
<tr><td>Wild Card</td>
    <td><input type="checkbox" name="wildcard" value="YES"$checked></td>
</tr>
*);
    }

    # show MX value option?
    if ($$pref{'ALLOW_MX'} eq 'YES' or
        $$pref{'ALLOW_MX'} eq 'USER' and $$uinfo{'allowmx'} eq 'YES') {
      my $checked = setcheck($$uinfo{'MXbackup'});
      tpr(qq*
<tr><td>Mail Exchanger</td>
    <td><input type="text" name="new_MXvalue"
         value="$$uinfo{'MXvalue'}" size=35></td>
</tr>
<tr><td>Backup Mail Exchanger</td>
    <td><input type="checkbox" name="MXbackup" value="YES"$checked></td>
</tr>
*);
    }
  }

  # not editing self?
  if ($$reqparm{'do_edituser'} or $$reqparm{'manageusers_edituser'}) {

    # show disable password option?
    if ($$uinfo{'password'} eq '') {
      tpr(qq*
<tr><td>&nbsp;</td>
    <td><b>Password is Disabled</b></td>
</tr>
*);
    } else {
      tpr(qq*
<tr><td>Disable Password</td>
    <td><input type="checkbox" name="disable" value="YES"></td>
</tr>
*);
    }
  }

  tpr(qq*
<tr><td>New Password</td>
    <td><input type="password" name="new_password" value=""></td>
</tr>
<tr><td>New Password Again</td>
    <td><input type="password" name="new_password1" value=""></td>
</tr>
</table>
</center>
<br>
<center><input type="submit" name="$submit" value="Save Changes"></center>
</form>
$bodyend
</html>
*);
  exit;
}

########################################################################
# need E-mail before proceeding
########################################################################
sub pg_needemail {

  # ensure initialized
  $$reqparm{'new_needemail'} = $$userinfo{'email'}
    if !defined $$reqparm{'new_needemail'};

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center><h2>E-mail Address Entry</h2></center>
<center><font color="red">
  You must provide a valid E-mail address.
  </font></center>
<p>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="needemail">
*);
  html_user();
  tpr(qq*
<center>
<table>
<tr><td>Username/Hostname</td>
  <td><table width="100%" border=1><tr><td>
    <b><font size="+1">$$userinfo{'username'}</font></b>
  </td></tr></table></td>
</tr>
<tr><td>Domain</td>
  <td><table width="100%" border=1><tr><td>
    <b><font size="+1">$$userinfo{'domain'}</font></b>
  </td></tr></table></td>
</tr>
<tr><td>E-Mail Address</td>
  <td><input type="text" name="new_needemail"
       value="$$reqparm{'new_needemail'}" size="40"></td>
</tr>
</table>
</center>
*);

  # ensure not a robot
  mchk_html();

  tpr(qq*
<br>
<center><input type="submit" name="do_needemail" value="Save Changes"></center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# system settings
#######################################################################
sub pg_syssettings {

  # must be admin
  pg_error('not_admin') if $$userinfo{'level'} ne 'ADMIN';

  my $ADD_SELF_check =
    setcheck($$pref{'ADD_SELF'});
  my $DELETE_SELF_check =
    setcheck($$pref{'DELETE_SELF'});
  my $SEND_URL_check =
    setcheck($$pref{'SEND_URL'});
  my $REQUIRE_EMAIL_check =
    setcheck($$pref{'REQUIRE_EMAIL'});
  my $NO_ROBOTS_check =
    setcheck($$pref{'NO_ROBOTS'});
  my $ALLOW_CHANGE_HOSTNAME_check =
    setcheck($$pref{'ALLOW_CHANGE_HOSTNAME'});
  my $ALLOW_CHANGE_DOMAIN_check =
    setcheck($$pref{'ALLOW_CHANGE_DOMAIN'});
  my $ALLOW_AUTO_URL_check =
    setcheck($$pref{'ALLOW_AUTO_URL'});
  my $ALLOW_WILD_check =
    setcheck($$pref{'ALLOW_WILD'});
  my $ALLOW_MX_check =
    setcheck($$pref{'ALLOW_MX'});
  my $SHOW_DOMAINLIST_check =
    setcheck($$pref{'SHOW_DOMAINLIST'});

  my $ALLOW_WILD_USER_check =
    $ALLOW_WILD_check;
  $ALLOW_WILD_USER_check = ' checked'
    if $$pref{'ALLOW_WILD'} eq 'USER';

  my $ALLOW_MX_USER_check =
    $ALLOW_MX_check;
  $ALLOW_MX_USER_check = ' checked'
    if $$pref{'ALLOW_MX'} eq 'USER';

  header();
  tpr(qq*
<html>
$head
$body
$topline
<br>
<center><h2>System Settings</h2></center>
*);
  if ($$reqparm{'save_settings'}) {
    tpr(qq*
<center><font size="+1"><b>
  Previous settings saved
  </b></font></center>
  <p>
*);
  }
  tpr(qq*
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="syssettings">
*);
  html_user();
  tpr(qq@
<br>
<center>
<table border=1>
<tr>
  <td>Allow self registration</td>
  <td align="center">
     <input type=checkbox name="ADD_SELF"
      value="YES" $ADD_SELF_check></td></tr>
<tr>
  <td>Allow self deletion</td>
  <td align="center">
     <input type=checkbox name="DELETE_SELF"
      value="YES" $DELETE_SELF_check></td></tr>
<tr>
  <td>Allow sending of quick login URL-s for forgotten passwords</td>
  <td align="center">
     <input type=checkbox name="SEND_URL"
      value="YES" $SEND_URL_check></td></tr>
<tr>
  <td>Require and validate E-mail addresses<br>
      <blockquote><i>
      This option requires that a user provide an E-mail address during
      self registration. Also, whenever a non-administrative user provides
      an E-mail address, they must use a URL sent to that E-mail
      address to complete the change.
      </i></blockquote></td>
  <td align ="center">
    <input type=checkbox name="REQUIRE_EMAIL"
     value="YES" $REQUIRE_EMAIL_check></td></tr>
<tr>
  <td>Check for robot before sending E-mail<br>
      <blockquote><i>
      This option requires that a user examine an image for a character
      string encoded in it and enter the string on any page that sends
      E-mail.
      </i></blockquote></td>
  <td align ="center">
    <input type=checkbox name="NO_ROBOTS"
     value="YES" $NO_ROBOTS_check></td></tr>
<tr>
  <td>Show domain list on login page<br>
      <blockquote><i>
      Users will have to enter their domain name into a text box
      during login unless this option is on.
      </i></blockquote></td>
  <td align="center">
     <input type=checkbox name="SHOW_DOMAINLIST"
      value="YES" $SHOW_DOMAINLIST_check></td></tr>
<tr>
  <td>Allow users to change their hostname/username</td>
  <td align="center">
    <input type=checkbox name="ALLOW_CHANGE_HOSTNAME"
     value="YES" $ALLOW_CHANGE_HOSTNAME_check></td></tr>
<tr>
  <td>Allow users to switch their domain</td>
  <td align="center">
     <input type=checkbox name="ALLOW_CHANGE_DOMAIN"
      value="YES" $ALLOW_CHANGE_DOMAIN_check></td></tr>
<tr>
  <td>Enable automatic login using "Auto URL"<br>
      <blockquote><i>
      This allows users to set the GnuDIP Auto URL as their browser's
      default page to update their IP address and be redirected to their
      specified "Forward URL".
      </i></blockquote></td>
  <td align ="center">
    <input type=checkbox name="ALLOW_AUTO_URL"
     value="YES" $ALLOW_AUTO_URL_check></td></tr>
<tr>
  <td>Allow all users to set a wildcard DNS RR entry
      <blockquote><i>
      The wildcard entry will match any full hostname ending
      in the users full hostname. So not just "user.gnudipdomain" will
      map to the current address but so will "www.user.gnudipdomain"
      and so on.
      </i></blockquote></td>
  <td align="center">
    <input type=checkbox name="ALLOW_WILD"
     value="YES" $ALLOW_WILD_check></td></tr>
<tr>
  <td>Allow enabled users to set a wildcard DNS RR entry</td>
  <td align="center">
    <input type=checkbox name="ALLOW_WILD_USER"
     value="YES" $ALLOW_WILD_USER_check></td></tr>
<tr>
  <td>Allow all users to set mail exchanger RR entries<br>
      <blockquote><i>
      This allows users to specify a (primary or backup) mail exchanger.
      </i></blockquote></td>
  <td align="center">
    <input type=checkbox name="ALLOW_MX"
     value="YES" $ALLOW_MX_check></td></tr>
<tr>
  <td>Allow enabled users to set mail exchanger RR entries</td>
  <td align="center">
    <input type=checkbox name="ALLOW_MX_USER"
     value="YES" $ALLOW_MX_USER_check></td></tr>
<tr>
  <td>Restricted usernames<br>
      <blockquote><i>
      This is a comma seperated list of usernames you do not want to
      be allowed as GnuDIP usernames.
      It can protect common hostnames from being used.
      An * can be used as a wild card to match a string of characters,
      and a ? can be used to match a single character.
      Common entries include www, ftp, ns?, mail*, etc...
      </i></blockquote></td>
  <td align="center">
    <input type=text name="RESTRICTED_USERS" size=25
     value="$$pref{'RESTRICTED_USERS'}"></td></tr>
<tr>
  <td>Page Timeout<br>
      <blockquote><i>
      If a number is provided here, browser pages will expire
      after that number of seconds.
      This will not apply to administrative users.
      A good value for this might be 1800 - 30 minutes.
      </i></blockquote></td>
  <td align="center">
    <input type=text name="PAGE_TIMEOUT" size=25
     value="$$pref{'PAGE_TIMEOUT'}"></td></tr>
<tr>
  <td>Server Signature Key<br>
      <blockquote><i>
      This value is generated automatically upon the first login to
      GnuDIP.
      It is used to "sign" the login information placed in each page.
      This signature is tested each time a page internal to GnuDIP is
      requested.
      </i></blockquote></td>
  <td align="center">
    <table border=1><tr><td align="center">
      $$pref{'SERVER_KEY'}
      </table></td></tr>
</table>
<br>
<input type=submit name="save_settings" value="Save Settings\">
</center>
</form>
$bodyend
</html>
@);
  exit;
}

########################################################################
# set auto URL
########################################################################
sub pg_setautourl {

  # generate cookies
  printcookie('gnudipuser',   $$userinfo{'username'}, '+1M');
  printcookie('gnudipdomain', $$userinfo{'domain'},   '+1M');
  printcookie('gnudippass',   $$userinfo{'password'}, '+1M');

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center>
<h2>Auto URL Cookie Set</h2>
Auto URL is a feature of GnuDIP that allows a user to set cookies in
their browser with their username, domain and (hashed) password.
<p>
When GnuDIP is contacted using the "Auto URL", it reads this information
from the cookies passed from the browser to GnuDIP. After verifying
this information it updates the hostname to point to the IP address
of the computer that connected to GnuDIP, and then "redirects" the
browser to the value the user has provided for "Forward URL". If
"Forward URL" is not set a mesage page will be displayed instead
of redirecting the browser.
<p>
<font color="red">
Note that the IP address of the computer that connects to GnuDIP is used.
Browser based IP address detection is not supported for Auto URL.
</font>
<p>
Now that the cookie has been set, you can test it by clicking the link below.
After it succesfully updates your hostname set that page as your
browsers default page.
</center>
<form action="$thisurl?action=getautourlinfo" method="post">
<input type=hidden name="page" value="setautourl">
*);
  html_user();
  tpr(qq*
<br>
<center>
<input type=submit name="testautourl"
       value="Click Here To Test AUTO URL Cookie">
</center>
</form>
<form action="$thiscgi" method="post">
<input type=hidden name="page" value="setautourl">
*);
  html_user();
  tpr(qq*
<br>
<center>
<input type="submit" name="removeautourl" value="Remove Auto URL">
</center>
</form>
$bodyend
</html>
*);
  exit;
}

#######################################################################
# display title and message
#######################################################################
sub pg_msg {
  my $msgtitle = shift;
  my $msg      = shift;

  # ensure initialized
  $msgtitle = '' if !defined($msgtitle);
  $msg      = '' if !defined($msg);

  # remove leading and trailing new lines
  $msgtitle =~ s /^\n//;
  $msgtitle =~ s /\n$//;
  $msg      =~ s /^\n//;
  $msg      =~ s /\n$//;

  header();
  tpr(qq*
<html>
$head
$body
$topline
<center>
<h2>$msgtitle</h2>
$msg
</center>
$bodyend
</html>
*);
  exit;
}      

#######################################################################
# display error message
#######################################################################
sub pg_error {
  my $error = shift;

  if ($error eq 'page_timeout') {
    pg_msg(qq*
Error: Browser Page Has Expired
*,qq*
The current GnuDIP page has expired.
<br>
Please go back to the login page.
*);

  } elsif ($error eq 'nouser') {
    pg_msg(qq*
Error: Unknown User
*,qq*
You entered a username/domain combination which was unknown.
<br>
Please go back and check for typos.
*);

  } elsif ($error eq 'bad_sel_user') {
    pg_msg(qq*
Error: Selected User Does Not Exist
*,qq*
Please go back and refresh the list.
*);

  } elsif ($error eq 'bad_edit_user') {
    pg_msg(qq*
Error: User Being Edited Does Not Exist
*,qq*
Please go back and refresh the list.
*);

  } elsif ($error eq 'bad_user_domain') {
    pg_msg(qq*
Error: Domain For User Being Edited Does Not Exist
*,qq*
Please either restore the domain, or delete the user.
Or use the "gdipdbfix.pl" script to remove all invalid users.
*);

  } elsif ($error eq 'bad_sel_domain') {
    pg_msg(qq*
Error: Selected Domain Does Not Exist
*,qq*
Please go back and refresh the list.
*);

  } elsif ($error eq 'bad_edit_domain') {
    pg_msg(qq*
Error: Domain Being Edited Does Not Exist
*,qq*
Please go back and refresh the list.
*);

  } elsif ($error eq 'bad_request') {
    pg_msg(qq*
Error: Invalid HTTP Request
*,qq*
The HTTP request was not valid.
*);

  } elsif ($error eq 'badpass') {
    pg_msg(qq*
Error: Invalid Password
*,qq*
The password you entered was invalid.
<br>
Please go back and check for typos.
*);

  } elsif ($error eq 'dispass') {
    pg_msg(qq*
Error: Password Disabled
*,qq*
The password for this user has been disabled.
*);

  } elsif ($error eq 'not_same') {
    pg_msg(qq*
Error: Password Error 
*,qq*
You must enter the same password twice.
<br>
Please go back and enter the same password twice.
*);

  } elsif ($error eq 'bad_username') {
    pg_msg(qq*
Error: Invalid User Name
*,qq*
You entered a user name which is not a valid domain name component.
<br>
Please go back and check this entry.
*);

  } elsif ($error eq 'user_exists') {
    pg_msg(qq*
Error: User Exists
*,qq*
Please go back and choose a username that is not already in use.
*);

  } elsif ($error eq 'no_username') {
    pg_msg(qq*
Error: No User Name
*,qq*
You did not provide a user name.
<br>
Please go back and choose a username.
*);

  } elsif ($error eq 'no_password') {
    pg_msg(qq*
Error: No Password
*,qq*
You did not provide a password.
<br>
Please go back and choose a password.
*);

  } elsif ($error eq 'no_email') {
    pg_msg(qq*
Error: No E-mail Address
*,qq*
You did not provide an E-mail address.
<br>
Please go back and enter a valid E-mail address.
*);

  } elsif ($error eq 'no_domain') {
    pg_msg(qq*
Error: No Domain Name
*,qq*
You did not provide a domain name.
<br>
Please go back and choose a username.
*);

  } elsif ($error eq 'domain_exists') {
    pg_msg(qq*
Error: Domain Exists
*,qq*
Please go back and choose a domain that is not already in use.
*);

  } elsif ($error eq 'no_cookie') {
    pg_msg(qq*
Error: Missing AutoURL Cookie
*,qq*
One or more Auto URL cookies were not sent.
<br>
Please go to the main menu and choose 'Set Auto URL'.
*);

  } elsif ($error eq 'no_autourl') {
    pg_msg(qq*
Error: Auto URL Not Allowed
*,qq*
This server has the Auto URL option turned off.
<br>
Any Auto URL cookie that may have been in your browser has been removed.
*);

  } elsif ($error eq 'bad_cookie') {
    pg_msg(qq*
Error: Invalid AutoURL Login
*,qq*
The cookies passed by your browser contained an invalid username and/or
password.
<br>
Perhaps you did not reset your cookie after you changed your password.
*);

  } elsif ($error eq 'no_changepass') {
    pg_msg(qq*
Error: Password Changes Not Allowed
*,qq*
Your administrator has chosen not to allow users to change their own password.
<br>
Please contact your administrator and ask them to change your password for you.
*);

  } elsif ($error eq 'not_admin') {
    pg_msg(qq*
Error: Not Administrator
*,qq*
You are not marked as an administrator.
<br>
Please log in again if you feel this is an error.
*);

  } elsif ($error eq 'restricted_user') {
    pg_msg(qq*
Error: Restricted Username
*,qq*
The username you have chosen has been marked as restricted.
<br>
Please contact your administrator if you feel this is an error.
*);

  } elsif ($error eq 'no_changehostname') {
    pg_msg(qq*
Error: Hostname changes not allowed
*,qq*
Your administrator has chosen not to allow users to change their hostnames.
<br>
Please contact your administrator if you feel this is an error.
*);

  } elsif ($error eq 'no_domain_change') {
    pg_msg(qq*
Error: Subdomain changes not allowed
*,qq*
Your administrator has chosen not to allow users to change their subdomain
names.
<br>
Please contact your administrator if you feel this is an error.
*);

  } elsif ($error eq 'no_dom_domain_change') {
    pg_msg(qq*
Error: Change to this subdomain not allowed
*,qq*
Your administrator has chosen not to allow users to change their subdomain
to this name.
<br>
Please contact your administrator if you feel this is an error.
*);

  } elsif ($error eq 'no_spaces') {
    pg_msg(qq*
Error: No Spaces or Blanks Allowed
*,qq*
You entered a string which contained spaces or was left blank.
<br>
Please go back and check your username.
*);

  } elsif ($error eq 'no_addself') {
    pg_msg(qq*
Error: Self registration not allowed
*,qq*
Your administrator has chosen not to allow self registration.
<br>
Please contact your administrator for an account.
*);

  } elsif ($error eq 'no_sendURL') {
    pg_msg(qq*
Error: Sending login URL not allowed
*,qq*
Your administrator has chosen not to allow mailing a login URL.
<br>
Please contact your administrator for a new password.
*);

  } elsif ($error eq 'no_delself') {
    pg_msg(qq*
Error: Self deletion not allowed
*,qq*
Your administrator has chosen not to allow self deletion.
*);

  } elsif ($error eq 'no_domaddself') {
    pg_msg(qq*
Error: Self registration for this domain not allowed
*,qq*
Your administrator has chosen not to allow self registration
for this domain.
*);

  } elsif ($error eq 'unknown_dom') {
    pg_msg(qq*
Error: Unknown Domain
*,qq*
An invalid domain name was specified.
*);

  } elsif ($error eq 'bad_domain') {
    pg_msg(qq*
Error: Invalid Domain Name Syntax
*,qq*
The domain name you entered has invalid syntax.
<br>
Please go back and check what you entered.
*);

  } elsif ($error eq 'bad_email') {
    pg_msg(qq*
Error: Invalid E-mail Address Syntax
*,qq*
The E-mail address you entered has invalid syntax.
<br>
Please go back and check what you entered.
*);

  } elsif ($error eq 'bad_MX_dom') {
    pg_msg(qq*
Error: Invalid Mail Exchanger Domain Name
*,qq*
The domain name you provided for a mail exchanger is not valid.
<br>
Please go back and check what you entered.
*);

  } elsif ($error eq 'bad_MX_IP') {
    pg_msg(qq*
Error: Invalid Mail Exchanger IP
*,qq*
The IP address you provided for a mail exchanger is not valid.
<br><b>Note:</b> This domain requires the <b>IP address</b> of the mail
exchanger.<br>
Please go back and check what you entered.
*);

  } elsif ($error eq 'bad_IP') {
    pg_msg(qq*
Error: Unservicable IP Address
*,qq*
The requested IP address is not one that this GnuDIP installation will serve.
*);

  } elsif ($error eq 'bad_IP_syntax') {
    pg_msg(qq*
Error: Invalid IP Address Syntax
*,qq*
The requested IP address does not have valid syntax.
*);

  } elsif ($error eq 'no_useremail') {
    pg_msg(qq*
Error: No E-mail Address on Record
*,qq*
There is no E-mail address on record for the user you selected.
<br>
A Quick Login URL canot be sent.
*);
   } elsif ($error eq 'config') {
    pg_msg(qq*
Error: GnuDIP Configuration or Interface Problem
*,qq*
An internal GnuDIP operation has failed, due to a configuration error, or
the failure of a system service required by GnuDIP.
<p>
Please report this problem to your administrator if it persists.
*);

 } else {
    pg_msg(qq*
Error: Internal Error
*,qq*
An internal error has occurred.
*);
  }
}      

#######################################################################
# subroutines
#######################################################################

# generate html for user information
sub html_user {

  # ensure people come through login page
  # sign the login information
  my $pagetime = time;
  my $checkval  =
    md5_hex(
      "$$userinfo{'username'}.".
      "$$userinfo{'domain'}." .
      "$$userinfo{'password'}." .
      "$$reqparm{'logonid'}." .
      "$pagetime." .
      $$pref{'SERVER_KEY'}
      );

  tpr(qq*
<input type=hidden name="username" value="$$userinfo{'username'}">
<input type=hidden name="domain"   value="$$userinfo{'domain'}">
<input type=hidden name="password" value="$$userinfo{'password'}">
<input type=hidden name="logonid"  value="$$reqparm{'logonid'}">
<input type=hidden name="pagetime" value="$pagetime">
<input type=hidden name="checkval" value="$checkval">
*);
}

# generate html for the domain list
# may specify the one at the top
sub html_domain {
  my $top   = shift;
  my $dname = shift;

  # default name for <select>
  $dname = 'new_domain' if !$dname;

  tpr(qq*
<tr><td>Domain</td>
    <td>
    <select name="$dname">
*);
  if ($top) {
    tpr(qq*
    <option value="$top">$top</option>
*);
  }
  my $domains = getdomains();
  foreach my $domain (@$domains) {
    if (!$top or $$domain{'domain'} ne $top) {
      tpr(qq*
    <option value="$$domain{'domain'}">$$domain{'domain'}</option>
*);
    }
  }
  tpr(qq*
    </select>
    </td></tr>
*);
}

# return ' checked' if the value is 'YES'
sub setcheck {
  my $value = shift;
  my $checked = '';
  $checked = ' checked'
    if $value and $value eq 'YES';
  return $checked;
}

# print content and document type
sub header {
  tpr(qq*
Content-Type: text/html; charset=iso-8859-1                                                        

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd\">
*);
}

#######################################################################
# must return 1
#######################################################################
1;

