#!/bin/bash
# Hellenic Technologies
# inspired by Servebolt optimizer version
# Version 1.0, July 2021
#
#Set the homedir here
HOMEDIR="/home/master/applications/dev_novamix/public_html/wp-content/uploads/2019/"
# Compress all non-compressed .jpg and .png images
cd $HOMEDIR
nice -n 19 find . -iname '*.jpg' -print0 | xargs -0 jpegoptim --max=85 --all-progressive --strip-all --preserve --totals --force
nice -n 19 find . -iname '*.jpeg' -print0 | xargs -0 jpegoptim --max=85 --all-progressive --strip-all --preserve --totals --force
nice -n 19 find . -iname '*.png' -print0 | xargs -0 optipng -o7 -preserve
echo "JPG/PNG Compression complete"