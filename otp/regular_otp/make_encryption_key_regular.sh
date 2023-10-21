#!/bin/bash
##########
#
# Creates a random encryption one-time key (OTP)
#
# Usage:
# ./make_encryption_key_regular.sh [bytes] [OTP_KEY]
#	e.g.
#	./make_encryption_key_regular.sh 1048576 OTP_KEY
#
# 1048576 bytes → 1    MiB
# 10485760      → 10   MiB
# 104857600     → 100  MiB
# 734003200     → 700  MiB (CD-R)
#
##########

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 [bytes] [OTP_KEY]"
  echo ""
  echo "  e.g."
  echo "  $0 1048576 OTP_KEY"
  exit 1
fi

one="$(echo "$1" | awk '{printf "%.0f", $0}')"
two="$2"

if [ ! -w "$(pwd)" ]; then
  echo ""
  echo "! ! !"
  echo "               you don't have"
  echo "            write permissions"
  echo "                        . . ."
  echo "  current working directory : $(pwd -P)"
  echo "! ! !"
  exit 1
fi

if [ "$one" -lt 1 ]; then
  echo ""
  echo "! ! !"
  echo "     [bytes] must be positive"
  echo "          and greater than 0."
  echo "! ! !"
  exit 1
fi

disk_space_func () {
  df -PB 1 . | tail -1 | awk '{print $4}'
  }

if [ "$(disk_space_func)" -lt "$one" ]; then
  echo ""
  echo "! ! !"
  echo "       not enough disk space!"
  echo "! ! !"
  exit 1
fi

shuf_10_50_mib () {
  echo "$(shuf -i 10485760-52428800 -n 1)"
  }

make_garbage_0 () {
  openssl rand "$(shuf_10_50_mib)" > /dev/null
  dd if=/dev/urandom bs="$(shuf_10_50_mib)" count=1 status=none > /dev/null
  }

# OpenSSL 1.0 and above
make_garbage_no1 () {
  make_garbage_0
  openssl rand "$(shuf_10_50_mib)" | openssl dgst -sha256 | awk -F '=[[:blank:]]' '{print $NF}' | cut -c1-32
  }
make_garbage_no2 () {
  make_garbage_0
  dd if=/dev/urandom bs="$(shuf_10_50_mib)" count=1 status=none | openssl dgst -sha256 | awk -F '=[[:blank:]]' '{print $NF}' | cut -c1-32
  }
make_garbage_no3 () {
  make_garbage_0
  openssl rand "$(shuf_10_50_mib)" | openssl dgst -sha512 | awk -F '=[[:blank:]]' '{print $NF}' | cut -c65-128
  }
make_garbage_no4 () {
  make_garbage_0
  dd if=/dev/urandom bs="$(shuf_10_50_mib)" count=1 status=none | openssl dgst -sha512 | awk -F '=[[:blank:]]' '{print $NF}' | cut -c65-128
  }

make_garbage_0

# you can use "-camellia-256-ctr" / "-aria-256-ctr"


# variant one
#openssl rand "$one" | openssl enc -aes-256-ctr -p -v -nosalt -K "$(make_garbage_no4)" -iv "$(make_garbage_no2)" -out "$two.dat"

# variant two
dd if=/dev/urandom bs="$one" count=1 | openssl enc -aes-256-ctr -p -v -nosalt -K "$(make_garbage_no3)" -iv "$(make_garbage_no1)" -out "$two.dat"

echo ""
echo "DONE."
date --rfc-3339=seconds

# EOF
