#!/bin/sh
#####################################################
# gdiprltiny.sh
#
# This is a sample back end tinydns reload shell 
# script. You at least need to adjust the file variable 
# to reflect your setup and needs. 
#
# The author of GnuDIP does not use tinydns, and
# this script came from thilo.bangert@gmx.net
#
# Thanks go out to the author of GnuDip for his help 
# to make tinydns work with GnuDIP. Thanks.
#
# See COPYING for licensing information.
#
# Written by:
#
#   Thilo Bangert
#   thilo.bangert@gmx.net
#
#####################################################

# point at your tinydns source file
file=/etc/tinydns/root/gnudip.data

# scan the database and create the source records
/usr/local/gnudip/sbin/gdiptinydns.pl -o $file

###
### from here on, you need to find a way, do update your data.cdb in /etc/tinydns/root
### here is how i did it, but your might want to do it differently!
###
### it is a good idea to do this from a different executeable and than run it from here
###

/etc/tinydns/root/build

#---
#this is my /etc/tinydns/root/build
# ! /bin/ bash

# place necessary records at the front
# the standard tinydns data file (ie. static records - not maintained by gnudip)
# Note: for every domain, that gnudip manages, there needs to be at least a . record in this file

#cat /etc/tinydns/root/real.data > /etc/tinydns/root/data
#cat <<EOF >> /etc/tinydns/root/data
##
##here the gnudip tinydns data file starts
##
#EOF
#cat /etc/tinydns/root/gnudip.data >> /etc/tinydns/root/data

# rebuild the tinydns server datafile
# !!! if this fails tinydns will be serving old data !!!
#cd /etc/tinydns/root
#make

# now you need to spread the new datafile to your "secondaries"
# from www.lifewithdjbdns.org
#
#/usr/local/bin/rsync -e /usr/bin/ssh -az /etc/tinydns/root/data $host:/etc/tinydns/root/data
#ssh $host \"cd /etc/tinydns/root; make\"

