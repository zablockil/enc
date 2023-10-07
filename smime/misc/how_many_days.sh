#!/bin/bash
#
# date (GNU coreutils)
#
# Determines how many DAYS remain until the designated date
# copy the date from the file "cert_root.crt.txt" from the field "Not After"
#
# ----------
# EXAMPLE #1
# ----------
# validity_not_after="Jan  1 12:00:00 3023 GMT"
#               ↖ or "3023-01-01 12:00:00+00:00"
# days_left="$(($(($(date +%s -d "$validity_not_after") - $(date +%s)))/$((60*60*24))))"
# echo "$days_left"
# ----------
# $ ./how_many_days.sh
#
#
# ----------
# EXAMPLE #2
# ----------
# validity_not_after="Jan 19 03:14:07 2038 GMT"
#               ↖ or "2038-01-19 03:14:07+00:00"
# days_left="$(($(($(date +%s -d "$validity_not_after") - $(date +%s)))/$((60*60*24))))"
# echo "$days_left"
# ----------
# $ faketime "2000-01-01 03:14:07" ./how_many_days.sh
# 13898
#

validity_not_after="Jan  1 12:00:00 3023 GMT"
days_left="$(($(($(date +%s -d "$validity_not_after") - $(date +%s)))/$((60*60*24))))"
echo "$days_left"
