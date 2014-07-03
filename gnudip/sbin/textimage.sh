#!/bin/sh
#####################################################
# textimage.sh
#
# This sample/default shell script generates a JPEG
# image file containing a text string, preceded by
# HTTP headers.
#
# It uses the "convert" command from ImageMagick:
#   http://www.Imagemagick.org/
#
#####################################################

# string to generate
string=$1

# prefix to use for temporary file names
prefix=$2

# name for temporary image file
imgfile=$prefix.jpeg

# for debuging
#echo textimage.sh: string=$string imgfile=$imgfile 1>&2
#echo PATH=$PATH 1>&2

# generate the image file
convert \
  -geometry 190x30! -pointsize 24 -font helvetica \
  -draw "text 0,24 $string" xc:white $imgfile
retcode=$?

# nothing to STDOUT on failure
if [ $retcode != 0 ]; then
  logger -t textimage.sh "convert" command failed - see HTTP server log
  exit $retcode
fi

# output HTTP header and file
echo "Content-Type: image/jpeg"
echo
cat $imgfile

# remove temporary file
rm $imgfile

