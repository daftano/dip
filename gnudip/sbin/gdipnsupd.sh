#!/bin/sh
#####################################################
# gdipnsupd.sh
#
# This is a sample script showing how to intercept the
# call GnuDIP makes to "nsupdate" in order to take
# additonal actions.
#
# Use this script as the value for the "nsupdate"
# parameter in "gnudip.conf". The actual nsupdate
# command should be passed as the arguments to this
# script. So the name of this script just gets inserted
# in front of the nsupdate command.
#
#####################################################

# the real nsupdate command
nsupdate="$*"

# process one line of input
function process_line() {
  logger -t gdipnsupd.sh "$REPLY"
  if [ "$2" == 'add' ] && [ "$5" == 'A' ]
  then
    oper=add
    name=$3
    addr=$6
  elif [ "$2" == 'delete' ] && [ "$4" == 'A' ]
  then
    oper=del
    name=$3
  fi
}

# read, scan and save each line
intext=
while read
do
  intext="$intext$REPLY\n"
  process_line $REPLY
done

# run nsupdate
echo -e "$intext" | command $nsupdate
retc=$?

# perform extra actions
if [ "$oper" == 'add' ]
then
  logger -t gdipnsupd.sh "IP address for $name (re)set to $addr"
elif [ "$oper" == 'del' ]
then
  logger -t gdipnsupd.sh "IP address for $name removed"
fi

exit $retc

