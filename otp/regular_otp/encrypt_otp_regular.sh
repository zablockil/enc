#!/bin/bash
##########
#
# Encrypts file using OTP
#
# Usage:
# ./encrypt_otp_regular.sh [OTP_KEY] [FILE] [COUNTER]
#	e.g.
#	./encrypt_otp_regular.sh OTP_KEY.dat secret_message.doc 0
#
##########

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 [OTP_KEY] [FILE] [COUNTER]"
  echo ""
  echo "  e.g."
  echo "  $0 OTP_KEY.dat secret_message.doc 0"
  exit 1
fi

one="$1"
two="$2"
three="$(echo "$3" | awk '{printf "%.0f", $0}')"

# test $1
if [ -s "${one}" ]; then
  size_KeyStream="$(stat -c%s "${one}")"
else
  size_KeyStream="0"
fi

if [ "${size_KeyStream}" -lt 1 ]; then
  echo ""
  echo "! ! !"
  echo "                     Where is"
  echo "            the one time pad?"
  echo "! ! !"
  exit 1
fi

# test $2
if [ -s "${two}" ]; then
  size_Plaintext="$(stat -c%s "${two}")"
else
  size_Plaintext="0"
fi

if [ "${size_Plaintext}" -lt 1 ]; then
  echo ""
  echo "! ! !"
  echo "                     Where is"
  echo "                  the secret?"
  echo "! ! !"
  exit 1
fi

# test $3
if [ "${three}" -lt 0 ]; then
  echo ""
  echo "! ! !"
  echo "            [COUNTER] must be"
  echo "   greater than or equal to 0"
  echo "! ! !"
  exit 1
fi

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

basename_one="$(basename "${one}")"
basename_two="$(basename "${two}")"

size_KeyStream_mib_approx="$(echo "${size_KeyStream}" | numfmt --to=iec-i --suffix=B)"
size_Plaintext_mib_approx="$(echo "${size_Plaintext}" | numfmt --to=iec-i --suffix=B)"

echo ""
echo "@ @ @"
echo "    encryption key filename : ${basename_one}"
echo "             input filename : ${basename_two}"
echo "                        . . ."
echo "   encryption key file size : ${size_KeyStream} (${size_KeyStream_mib_approx})"
echo "            OTP key pointer : ${three}"
echo "            input file size : ${size_Plaintext} (${size_Plaintext_mib_approx})"
echo "                              [bytes]"
echo "              PROCESSING FILE"
echo "                        . . ."

disk_space_func () {
  df -PB 1 . | tail -1 | awk '{print $4}'
  }

error_xor_func () {
cat <<-"EOF"
                        . . .
             cant create .dat
                  cipher file
                        . . .
          there is not enough
                  disk space!
                        . . .
           script TERMINATED!
! ! !
EOF
}

if [ "$(disk_space_func)" -lt "${size_Plaintext}" ]; then
  error_xor_func
  exit 1
fi

if ! (paste <(od -An -vtu1 -w1 -j 0 "${two}") <(od -An -vtu1 -w1 -j "${three}" "${one}") | LC_ALL=C awk 'NF!=2{exit}; {printf "%c", xor($1, $2)}' > "${basename_two}.dat"); then
  error_xor_func
  exit 1
fi

size_Ciphertext="$(stat -c%s "${basename_two}.dat")"
size_Ciphertext_mib_approx="$(echo "${size_Ciphertext}" | numfmt --to=iec-i --suffix=B)"

if [ "${size_Ciphertext}" -ne "${size_Plaintext}" ]; then
  echo "                        . . ."
  echo "             input and output"
  echo "      file sizes do not match"
  echo "                        . . ."
  echo "! ! !"
  #exit 1
fi

count_var="$((three + size_Ciphertext))"

KeyStream_free_space="$((size_KeyStream - count_var))"
KeyStream_free_space_mib_approx="$(echo "${KeyStream_free_space}" | numfmt --to=iec-i --suffix=B)"

echo "                        . . ."
echo "    cipher output file size : ${size_Ciphertext} (${size_Ciphertext_mib_approx})"
echo "       NEXT OTP key pointer : ${count_var}"
echo "            free space left : ${KeyStream_free_space} (${KeyStream_free_space_mib_approx})"
if [ "${KeyStream_free_space}" -lt 1048576 ]; then
  echo "                              it's time to create a new OTP key!"
fi
echo "@ @ @"

echo ""
echo "DONE."
date --rfc-3339=seconds

# EOF
