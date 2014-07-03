#!/bin/sh
#####################################################
# gdiprlbind.sh
#
# This is the sample back end BIND 8 domain reload
# shell script.
#
# It takes the domain name as an argument.
#
# See COPYING for licensing information.
#
#####################################################

# check that domain name was passed
if [ .$1 == . ]
then
  /bin/echo domain name was not passed
  exit 1;
fi

# get zone name
zone=$1

# point at your zone and version number files
zonefile=/var/named/zone-$zone
versionfile=/var/named/version-$zone

# increment version number
version=0
if [ -r $versionfile ]
then
  read version < $versionfile
  if [ $version == 99999999 ]
  then
    version=0
  else
    version=$((1 + $version))
  fi
fi
/bin/echo $version > $versionfile

# necessary records not maintained by GnuDIP
cat <<EOF > $zonefile
\$TTL 0	; 0 seconds
@     IN SOA macdonnell.ca. creighton.macdonnell.ca. (
             $version      ; serial
             3600   ; refresh (1 hour)
             1800   ; retry (30 minutes)
             604800 ; expire (1 week)
             0      ; TTL for NAK (0 seconds)
             )
      NS macdonnell.ca.
EOF

# scan the database and append the zone records
/usr/local/gnudip/sbin/gdipbind.pl -a $zonefile $zone

# reload the zone in question
/usr/sbin/ndc reload $zone

