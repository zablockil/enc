#!/bin/bash
##########
#
# Encrypts file using OTP and then places it
# in an AES-GCM encrypted container (public key cryptography).
#
# Usage:
# ./encrypt_otp_gcm.sh [OTP_KEY] [FILE] [RECIPIENT_ECC_CERT]"
#	e.g.
#	./encrypt_otp_gcm.sh OTP_KEY.dat secret_message.doc RECIPIENT_2.crt
#
##########

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 [OTP_KEY] [FILE] [RECIPIENT_ECC_CERT]"
  echo ""
  echo "  e.g."
  echo "  $0 OTP_KEY.dat secret_message.doc RECIPIENT_2.crt"
  exit 1
fi

one="$1"
two="$2"
three="$3"

# 0 - OFF, 1 - ON
save_log_and_counter_in_otpkey_dir="1"
add_up_counter_from_log_history="1"
cleaning_up_temporary_files="1"
keep_dates_in_tar_archive="1"

# test openssl version 3 (xoflen)
test_message () {
cat <<EOF
Hello world!
EOF
}
if ! openssl dgst -shake256 -xoflen 1 -out /dev/null <(echo "$(test_message)"); then
  old_openssl="$(openssl version | awk '{print $1,$2}')"
  echo ""
  echo "! ! !"
  echo "      we need openssl version"
  echo "          at least 3 to work!"
  echo "                        . . ."
  echo "                   you have : $old_openssl"
  echo "                        . . ."
  echo "                         bye!"
  echo "! ! !"
  exit 1
fi
# test ECDH encryption /dev/null [test $3]
if ! openssl cms -encrypt -stream -binary -keyid -outform DER -recip "$three" -aes-256-gcm -aes256-wrap -keyopt ecdh_cofactor_mode:0 -keyopt ecdh_kdf_md:sha512 -in <(echo "$(test_message)") -out /dev/null; then
  echo ""
  echo "! ! !"
  echo "         something went wrong"
  echo "                        . . ."
  echo "        check public key file"
  echo "                        . . ."
  echo "                         bye!"
  echo "! ! !"
  exit 1
fi

certificate_first_16_subjectKeyIdentifier="$(openssl x509 -noout -ext subjectKeyIdentifier -in "$three" | awk 'NR==2 {gsub(/[:]/,"");print $1}' | cut -c1-16)"

##########
#
# One-time Pad part
#
##########

# test $2
if [ -s "$two" ]; then
  size_Plaintext="$(stat -c%s "$two")"
else
  size_Plaintext="0"
fi

if [ "$size_Plaintext" -lt 1 ]; then
  echo ""
  echo "! ! !"
  echo "                     Where is"
  echo "                  the secret?"
  echo "! ! !"
  exit 1
fi

# test $1
if [ -s "$one" ]; then
  size_KeyStream="$(stat -c%s "$one")"
else
  size_KeyStream="0"
fi

if [ "$size_KeyStream" -lt 1 ]; then
  echo ""
  echo "! ! !"
  echo "                     Where is"
  echo "            the one time pad?"
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

dirname_one="$(cd "$(dirname "$one")" || exit; pwd -P)"

basename_one="$(basename "$one")"
basename_two="$(basename "$two")"

# delete all horizontal or vertical whitespace
basename_one_clean="$(printf '%s' "$basename_one" | LC_ALL=POSIX tr -d '[:cntrl:][:space:]' | iconv -cs -f UTF-8 -t UTF-8 | cut -c1-236)"
basename_two_clean="$(printf '%s' "$basename_two" | LC_ALL=POSIX tr -d '[:cntrl:][:space:]' | iconv -cs -f UTF-8 -t UTF-8 | cut -c1-236)"

if [ "$save_log_and_counter_in_otpkey_dir" -eq 1 ] && [ -w "$dirname_one" ]; then
  dirname_counter_and_log="$dirname_one"
  echo ""
  echo "i i i"
  echo "      I will save the counter"
  echo "      and logs in a directory"
  echo "          with a one-time key"
  echo "                        . . ."
  echo "                OTP key dir : $dirname_counter_and_log"
  echo "                        . . ."
  echo "           counter filename : $basename_one_clean.counter"
  echo "               log filename : $basename_one_clean.log.csv"
  echo "i i i"
else
  dirname_counter_and_log="$(pwd -P)"
  echo ""
  echo "i i i"
  echo "     I can't save the counter"
  echo "      and logs in a directory"
  echo "          with a one-time key"
  echo "                        . . ."
  echo "         I'll save them here,"
  echo "  current working directory : $dirname_counter_and_log"
  echo "                        . . ."
  echo "           counter filename : $basename_one_clean.counter"
  echo "               log filename : $basename_one_clean.log.csv"
  echo "i i i"
fi

# script first-time usage:
filename_counter="$dirname_counter_and_log/$basename_one_clean.counter"
if [ ! -e "$filename_counter" ]; then
  touch "$filename_counter"
fi

filename_log="$dirname_counter_and_log/$basename_one_clean.log.csv"
if [ ! -e "$filename_log" ]; then
  touch "$filename_log"
fi

count_func () {
  awk '{s+=$1} END {printf "%.0f", s}' "$filename_counter"
  }
# count fast
count_var="$(count_func)"

# the general guidelines of being conservative in what you send
# and liberal in what you accept

if [ "$count_var" -lt 0 ]; then
  echo ""
  echo "! ! !"
  echo "    counter must be positive."
  echo "                        . . ."
  echo "           script TERMINATED!"
  echo "! ! !"
  exit 1
fi

size_KeyStream_mib_approx="$((size_KeyStream / 1048576))"
size_Plaintext_mib_approx="$((size_Plaintext / 1048576))"

sum_counter_and_Plaintext="$((count_var + size_Plaintext))"

if [ "$sum_counter_and_Plaintext" -gt "$size_KeyStream" ]; then
  KeyStream_missing_space="$((sum_counter_and_Plaintext - size_KeyStream))"
  KeyStream_missing_space_mib_approx="$((KeyStream_missing_space / 1048576))"
  echo ""
  echo "! ! !"
  echo "      not enough space on OTP"
  echo "                        . . ."
  echo "               I can't do it."
  echo "   Create a new one-time key!"
  echo "                        . . ."
  echo "   encryption key file size : $size_KeyStream ($size_KeyStream_mib_approx MiB)"
  echo "            OTP key pointer : $count_var"
  echo "            input file size : $size_Plaintext ($size_Plaintext_mib_approx MiB)"
  echo "              missing space : $KeyStream_missing_space ($KeyStream_missing_space_mib_approx MiB)"
  echo "                              [bytes]"
  echo "                        . . ."
  echo "           script TERMINATED!"
  echo "! ! !"
  exit 1
fi

if [ "$add_up_counter_from_log_history" -eq 1 ] && [ -s "$filename_log" ]; then
  # column 7 "G"
  max_detected_counter_from_log="$(awk -F ';' '{print $7}' "$filename_log" | sort -n | tail -1 | awk '{printf "%.0f", $1}')"
else
  max_detected_counter_from_log="0"
fi

if [ "$max_detected_counter_from_log" -gt 0 ] && [ "$max_detected_counter_from_log" -gt "$count_var" ]; then
  KeyStream_reused_space="$((max_detected_counter_from_log - count_var))"
  KeyStream_reused_space_mib_approx="$((KeyStream_reused_space / 1048576))"
  echo ""
  echo "-----------------------------"
  echo "------- W A R N I N G -------"
  echo "-----------------------------"
  echo ""
  echo "     It was detected that you"
  echo "           want to reuse part"
  echo "              of the OTP key."
  echo ""
  echo "            What's the point?"
  echo ""
  echo "       max detected counter : $max_detected_counter_from_log"
  echo "               your counter : $count_var"
  echo "                        . . ."
  echo "           OTP reused space : $KeyStream_reused_space ($KeyStream_reused_space_mib_approx MiB)"
  echo "                              [bytes]"
  echo "                        . . ."
  echo "               Check the logs"
  echo "          and consider fixing"
  echo "                  the counter"
  echo "           and re-encrypting."
  echo ""
  echo "-----------------------------"
  echo "------- W A R N I N G -------"
  echo "-----------------------------"
  #exit 1
fi

echo ""
echo "@ @ @"
echo "    encryption key filename : $basename_one"
echo "             input filename : $basename_two"
echo "                        . . ."
echo "   encryption key file size : $size_KeyStream ($size_KeyStream_mib_approx MiB)"
echo "            OTP key pointer : $count_var"
echo "            input file size : $size_Plaintext ($size_Plaintext_mib_approx MiB)"
echo "                              [bytes]"
echo "              PROCESSING FILE"
echo "                        . . ."

tmp_date_epoch_nanoseconds="$(date +%s%N)"
tmp_date_nanoseconds="$(echo "$tmp_date_epoch_nanoseconds" | awk '{print substr($1,length($1)-8)}')"
tmp_date_epoch="$(echo "$tmp_date_epoch_nanoseconds" | awk '{print substr($1,1,length($1)-9)}')"
tmp_date_mtime="$(date -d "@$tmp_date_epoch" "+%Y-%m-%d %H:%M:%S")"
tmp_date="$(date -d "@$tmp_date_epoch" "+%Y%m%d_%H%M%S")_$tmp_date_nanoseconds"

if [ ! -d "tmp" ]; then
  mkdir "tmp"
fi
mkdir "tmp/$tmp_date"

tmp_dir="tmp/$tmp_date"

disk_space_func () {
  df -PB 1 . | tail -1 | awk '{print $4}'
  }

error_xor_func () {
cat <<EOF
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

if [ "$(disk_space_func)" -lt "$size_Plaintext" ]; then
  error_xor_func
  exit 1
fi

if ! (paste <(od -An -vtu1 -w1 -j 0 "$two") <(od -An -vtu1 -w1 -j "$count_var" "$one") | LC_ALL=C awk 'NF!=2{exit}; {printf "%c", xor($1, $2)}' > "$tmp_dir/$basename_two_clean.dat"); then
  error_xor_func
  exit 1
fi

size_Ciphertext="$(stat -c%s "$tmp_dir/$basename_two_clean.dat")"
size_Ciphertext_mib_approx="$((size_Ciphertext / 1048576))"

if [ "$size_Ciphertext" -ne "$size_Plaintext" ]; then
  echo "                        . . ."
  echo "             input and output"
  echo "      file sizes do not match"
  echo "                        . . ."
  echo "           script TERMINATED!"
  echo "! ! !"
  exit 1
fi

basename_one_clean_for_csv="$(echo "$basename_one_clean" | awk '{gsub(/[;]/,"_"); print $0}')"
basename_two_clean_for_csv="$(echo "$basename_two_clean" | awk '{gsub(/[;]/,"_"); print $0}')"

filename_output="$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 10 ; echo '')"

# update log (.csv) 11 cells
echo "Encrypt;$basename_one_clean_for_csv.counter;$count_var;$basename_two_clean_for_csv;$size_Ciphertext;next counter:;$((count_var + size_Ciphertext));$certificate_first_16_subjectKeyIdentifier;$tmp_date;$tmp_date_mtime;$filename_output.der;" >> "$filename_log"

# update local counter
echo "$size_Ciphertext" >> "$filename_counter"

# count fast / refresh function
count_var="$(count_func)"

KeyStream_free_space="$((size_KeyStream - count_var))"
KeyStream_free_space_mib_approx="$((KeyStream_free_space / 1048576))"

echo "                        . . ."
echo "    cipher output file size : $size_Ciphertext ($size_Ciphertext_mib_approx MiB)"
echo "       NEXT OTP key pointer : $count_var"
echo "            free space left : $KeyStream_free_space ($KeyStream_free_space_mib_approx MiB)"
if [ "$KeyStream_free_space_mib_approx" -eq 0 ]; then
  echo "                              it's time to create a new OTP key!"
fi
echo "                        . . ."
echo "     counter and log UPDATED!"
echo "@ @ @"

##########
#
# AES-GCM (AEAD) part
#
##########

echo ""
echo "$ $ $"
echo "      ENCRYPTING FILE AES-GCM"
echo "      you use cert with SKI : $certificate_first_16_subjectKeyIdentifier..."
echo "                        . . ."

Ciphertext_shake256xof32_dgst="$(openssl dgst -shake256 "$tmp_dir/$basename_two_clean.dat" | awk -F '=[[:blank:]]' '{print $NF}')"

# internal counter in .tar, + dgst
internal_counter_tar="$((count_var - size_Ciphertext))"

echo "$internal_counter_tar" > "$tmp_dir/$Ciphertext_shake256xof32_dgst.shake256"

if [ "$keep_dates_in_tar_archive" -eq 1 ]; then
  tar_time="$tmp_date_mtime"
else
  tar_time="@0"
fi

error_tar_func () {
cat <<EOF
                        . . .
        cant create .tar file
                        . . .
          there is not enough
                  disk space!
                        . . .
           script TERMINATED!
! ! !
EOF
}

if [ "$(disk_space_func)" -lt "$size_Ciphertext" ]; then
  error_tar_func
  exit 1
fi

if ! (cd "$tmp_dir" && tar --owner=0 --group=0 --mode="a+r" --mtime="$tar_time" -b 1 --no-recursion --full-time -cf "tar.tar" "$basename_two_clean.dat" "$Ciphertext_shake256xof32_dgst.shake256"); then
  error_tar_func
  exit 1
fi

if [ "$cleaning_up_temporary_files" -eq 1 ]; then
  rm -f "$tmp_dir/$basename_two_clean.dat"
  rm -f "$tmp_dir/$Ciphertext_shake256xof32_dgst.shake256"
fi

if [ ! -d "ENCRYPTED" ]; then
  mkdir "ENCRYPTED"
fi
mkdir "ENCRYPTED/$tmp_date"

dir_ENCRYPTED="ENCRYPTED/$tmp_date"

size_tar="$(stat -c%s "$tmp_dir/tar.tar")"

error_aead_func () {
cat <<EOF
                        . . .
   cant create .der AEAD file
                        . . .
          there is not enough
                  disk space!
                        . . .
           script TERMINATED!
! ! !
EOF
}

if [ "$(disk_space_func)" -lt "$size_tar" ]; then
  error_aead_func
  exit 1
fi

if ! openssl cms -encrypt -stream -binary -keyid -outform DER -recip "$three" -aes-256-gcm -aes256-wrap -keyopt ecdh_cofactor_mode:0 -keyopt ecdh_kdf_md:sha512 -in "$tmp_dir/tar.tar" -out "$dir_ENCRYPTED/$filename_output.der"; then
  error_aead_func
  exit 1
fi
# print info:
# openssl cms -decrypt -inform DER -in FILE.der -cmsout -print

if [ "$cleaning_up_temporary_files" -eq 1 ]; then
  rm -f "$tmp_dir/tar.tar"
fi

size_Ciphertext_Aead="$(stat -c%s "$dir_ENCRYPTED/$filename_output.der")"
size_Ciphertext_Aead_mib_approx="$((size_Ciphertext_Aead / 1048576))"

Ciphertext_Aead_sha256_dgst="$(openssl dgst -sha256 "$dir_ENCRYPTED/$filename_output.der" | awk -F '=[[:blank:]]' '{print $NF}')"
echo "$Ciphertext_Aead_sha256_dgst *$filename_output.der" > "$dir_ENCRYPTED/$filename_output.der.sha256"

echo "                        . . ."
echo "             AEAD file size : $size_Ciphertext_Aead ($size_Ciphertext_Aead_mib_approx MiB)"
echo "                              [bytes]"
echo "           output directory : $(pwd -P)/$dir_ENCRYPTED"
echo "            output filename : $filename_output.der"
echo "                        . . ."
echo "                          OK!"
echo "$ $ $"

if [ "$cleaning_up_temporary_files" -eq 1 ]; then
  rm -d "$tmp_dir"
  rm -d "tmp"
fi

echo ""
echo "DONE."
date --rfc-3339=seconds

# EOF
