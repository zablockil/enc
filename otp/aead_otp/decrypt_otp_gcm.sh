#!/bin/bash
##########
#
# Decrypts OTP + AEAD file.
# see: encrypt_otp_gcm.sh
#
# Usage:
# ./decrypt_otp_gcm.sh [OTP_KEY] [ENCRYPTED_FILE] [MY_PRIVATE_ECC_KEY]
#	e.g.
#	./decrypt_otp_gcm.sh OTP_KEY.dat secret_message.der MY_KEY.pem
#
##########

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 [OTP_KEY] [ENCRYPTED_FILE] [MY_PRIVATE_ECC_KEY]"
  echo ""
  echo "  e.g."
  echo "  $0 OTP_KEY.dat secret_message.der MY_KEY.pem"
  exit 1
fi

one="$1"
two="$2"
three="$3"

# 0 - OFF, 1 - ON
save_log_and_counter_in_otpkey_dir="1"
cleaning_up_temporary_files="1"
add_up_counter_from_log_history="1"
overwrite_counter_from_sender_if_higher="1"

COL_NORM="$(tput sgr0)"                  # \033(B\033[m
COL_RED1="$(tput setaf 7 setab 1)"       # \033[37;41m
COL_RED2="$(tput setaf 7 setab 1 bold)"  # \033[37;41;1m
COL_GREEN="$(tput setaf 0 setab 2)"      # \033[30;42m
COL_YELLOW="$(tput setaf 0 setab 3)"     # \033[30;43m
COL_BLUE="$(tput setaf 7 setab 4)"       # \033[37;44m

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

# checking for damages
# test [$3 & $2]
if ! openssl cms -decrypt -stream -binary -inform DER -inkey "$three" -in "$two" -out /dev/null; then
  echo ""
  echo "! ! !"
  echo "         something went wrong"
  echo "                        . . ."
  echo "       you're using the wrong"
  echo "      private key or the AEAD"
  echo "    file is missing/corrupted"
  echo "                        . . ."
  echo "           script TERMINATED!"
  echo "! ! !"
  exit 1
fi

certificate_first_16_subjectKeyIdentifier="$(openssl cms -decrypt -inform DER -in "$two" -cmsout -print | head -50 | awk '/subjectKeyIdentifier/ {getline;gensub("^ +","","g");gsub(/0000[[:blank:]]-/,"");gsub(/[-]/,"");gsub(/[[:blank:]]/,"");print ($1)}' | cut -c1-16)"

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

##########
#
# AES-GCM (AEAD) part
#
##########

echo ""
echo "${COL_GREEN}$ $ $""${COL_NORM}"
echo "      DECRYPTING FILE AES-GCM"
echo "                        . . ."
echo "             message intended"
echo "         for a key with SKI : $certificate_first_16_subjectKeyIdentifier..."
echo "                        . . ."

size_Ciphertext_Aead="$(stat -c%s "$two")"
size_Ciphertext_Aead_mib_approx="$(echo "$size_Ciphertext_Aead" | numfmt --to=iec-i)"

echo "             input filename : $basename_two"
echo "            input file size : $size_Ciphertext_Aead ($size_Ciphertext_Aead_mib_approx)"
echo "                              [bytes]"
echo "                        . . ."

tmp_date_epoch_nanoseconds="$(date +%s%N)"
tmp_date_nanoseconds="$(echo "$tmp_date_epoch_nanoseconds" | awk '{print substr($1,length($1)-8)}')"
tmp_date_epoch="$(echo "$tmp_date_epoch_nanoseconds" | awk '{print substr($1,1,length($1)-9)}')"
tmp_date="$(date -d "@$tmp_date_epoch" "+%Y%m%d_%H%M%S")_$tmp_date_nanoseconds"

if [ ! -d "tmp" ]; then
  mkdir "tmp"
fi
mkdir "tmp/$tmp_date"

tmp_dir="tmp/$tmp_date"

disk_space_func () {
  df -PB 1 . | tail -1 | awk '{print $4}'
  }

error_aead_func () {
cat <<EOF
                        . . .
  cant decrypt .der AEAD file
                        . . .
          there is not enough
                  disk space!
                        . . .
           script TERMINATED!
! ! !
EOF
}

if [ "$(disk_space_func)" -lt "$size_Ciphertext_Aead" ]; then
  error_aead_func
  exit 1
fi

if ! openssl cms -decrypt -stream -binary -inform DER -inkey "$three" -in "$two" -out "$tmp_dir/tar_$tmp_date_nanoseconds.tar"; then
  error_aead_func
  exit 1
fi

size_tar="$(stat -c%s "$tmp_dir/tar_$tmp_date_nanoseconds.tar")"

if [ "$(disk_space_func)" -lt "$size_tar" ]; then
  echo "                        . . ."
  echo "       cant extract .tar file"
  echo "                        . . ."
  echo "          there is not enough"
  echo "                  disk space!"
  echo "                        . . ."
  echo "           script TERMINATED!"
  echo "! ! !"
  exit 1
fi

if ! (cd "$tmp_dir" && tar --touch -xf "tar_$tmp_date_nanoseconds.tar"); then
  echo "                        . . ."
  echo "            broken .tar file!"
  echo "                        . . ."
  echo "           script TERMINATED!"
  echo "! ! !"
  exit 1
fi

tar --full-time -tvf "$tmp_dir/tar_$tmp_date_nanoseconds.tar" > "$tmp_dir/tar_list_files_$tmp_date_nanoseconds.txt"

tar_list_files="$tmp_dir/tar_list_files_$tmp_date_nanoseconds.txt"

tar_time="$(awk 'NR==1 {print $4,$5}' "$tar_list_files")"
tar_Ciphertext_filename="$(awk 'NR==1 {print $6}' "$tar_list_files")"
tar_Plaintext_filename="$(awk 'NR==1 {print substr($6,1,length($6)-4)}' "$tar_list_files")"
tar_Ciphertext_shake256xof32_dgst="$(awk 'NR==2 {print substr($6,1,length($6)-9)}' "$tar_list_files")"

Ciphertext_shake256xof32_dgst="$(openssl dgst -shake256 "$tmp_dir/$tar_Ciphertext_filename" | awk -F '=[[:blank:]]' '{print $NF}')"

echo "                        . . ."
echo "            secret filename : $tar_Plaintext_filename"
echo " message encrypted that day : $tar_time"
echo ""

error_compromised_func () {
cat <<EOF
                        . . .
                              message has been compromised!
                        . . .
  perform decryption manually
                        . . .
           script TERMINATED!
! ! !
EOF
}

if [ "$tar_Ciphertext_shake256xof32_dgst" = "$Ciphertext_shake256xof32_dgst" ]; then
  echo "                        . . ."
  echo "          SHAKE256 checksum : ok"
else
  echo "                        . . ."
  echo "          SHAKE256 checksum : NOT ok!"
  error_compromised_func
  exit 1
fi

if [ "$cleaning_up_temporary_files" -eq 1 ]; then
  rm -f "$tmp_dir/tar_$tmp_date_nanoseconds.tar"
  rm -f "$tar_list_files"
fi

echo "                        . . ."
echo "              so far so good!"
echo "${COL_GREEN}$ $ $""${COL_NORM}"

##########
#
# One-time Pad part
#
##########

count_local_func () {
  awk '{s+=$1} END {printf "%.0f", s}' "$filename_counter"
  }

count_sender_func () {
  awk '{s+=$1} END {printf "%.0f", s}' "$tmp_dir/$tar_Ciphertext_shake256xof32_dgst.shake256"
  }

# count fast
count_local_var="$(count_local_func)"
count_sender_var="$(count_sender_func)"

if [ "$add_up_counter_from_log_history" -eq 1 ] && [ -s "$filename_log" ]; then
  # column 7 "G"
  max_detected_counter_from_log="$(awk -F ';' '{print $7}' "$filename_log" | sort -n | tail -1 | awk '{printf "%.0f", $1}')"
else
  max_detected_counter_from_log="0"
fi

if [ "$max_detected_counter_from_log" -gt 0 ] && [ "$max_detected_counter_from_log" -gt "$count_sender_var" ]; then
  KeyStream_reused_space="$((max_detected_counter_from_log - count_sender_var))"
  KeyStream_reused_space_mib_approx="$(echo "$KeyStream_reused_space" | numfmt --to=iec-i)"
  echo "${COL_RED2}"
  echo "-----------------------------"
  echo "------- W A R N I N G -------"
  echo "-----------------------------"
  echo "${COL_NORM}${COL_RED1}"
  echo "     It was detected that you"
  echo "         decrypt files out of"
  echo "    the order of receipt from"
  echo "       the sender or you have"
  echo "  already encoded the message"
  echo "        into part of the key."
  echo ""
  echo "       max detected counter : $max_detected_counter_from_log"
  echo "             sender counter : $count_sender_var"
  echo "                        . . ."
  echo "           OTP reused space : $KeyStream_reused_space ($KeyStream_reused_space_mib_approx)"
  echo "                              [bytes]"
  echo "                        . . ."
  echo "               Check the logs"
  echo "          and consider making"
  echo "            separate OTP keys"
  echo "              for each party."
  echo ""
  echo "${COL_RED2}-----------------------------"
  echo "------- W A R N I N G -------"
  echo "-----------------------------${COL_NORM}"
fi

size_Ciphertext="$(stat -c%s "$tmp_dir/$tar_Ciphertext_filename")"
size_Ciphertext_mib_approx="$(echo "$size_Ciphertext" | numfmt --to=iec-i)"

echo ""
echo "${COL_BLUE}@ @ @${COL_NORM}"
echo "    encryption key filename : $basename_one"
echo "             input filename : $tar_Ciphertext_filename"
echo "                        . . ."
echo "   encryption key file size : $size_KeyStream"
echo "  key pointer (from sender) : $count_sender_var"
echo "           secret file size : $size_Ciphertext ($size_Ciphertext_mib_approx)"
echo "                              [bytes]"
echo "              DECRYPTING FILE"
echo "                        . . ."

if [ ! -d "DECRYPTED" ]; then
  mkdir "DECRYPTED"
fi
mkdir "DECRYPTED/$tmp_date"

dir_DECRYPTED="DECRYPTED/$tmp_date"

error_xor_func () {
cat <<EOF
                        . . .
            cant decrypt .dat
                  cipher file
                        . . .
          there is not enough
                  disk space!
                        . . .
           script TERMINATED!
! ! !
EOF
}

if [ "$(disk_space_func)" -lt "$size_Ciphertext" ]; then
  error_xor_func
  exit 1
fi

if ! (paste <(od -An -vtu1 -w1 -j 0 "$tmp_dir/$tar_Ciphertext_filename") <(od -An -vtu1 -w1 -j "$count_sender_var" "$one") | LC_ALL=C awk 'NF!=2{exit}; {printf "%c", xor($1, $2)}' > "$dir_DECRYPTED/$tar_Plaintext_filename"); then
  error_xor_func
  exit 1
fi

size_Plaintext="$(stat -c%s "$dir_DECRYPTED/$tar_Plaintext_filename")"

if [ "$size_Ciphertext" -ne "$size_Plaintext" ]; then
  echo "                        . . ."
  echo "             input and output"
  echo "      file sizes do not match"
  echo "                        . . ."
  echo "           script TERMINATED!"
  echo "! ! !"
  exit 1
fi

counter_local_update="$count_local_var"
counter_sender_update="$((count_sender_var + size_Ciphertext))"

# let's make sure that the next time we encrypt, we use the highest counter
# [synchronisation of key pointers]

if [ "$overwrite_counter_from_sender_if_higher" -eq 1 ] && [ "$counter_local_update" -lt "$counter_sender_update" ]; then
  echo "$counter_sender_update" > "$filename_counter"
  echo "                        . . ."
  echo "              counter updated"
else
  echo "                        . . ."
  echo "          counter NOT updated"
fi

basename_one_clean_for_csv="$(echo "$basename_one_clean" | awk '{gsub(/[;]/,"_"); print $0}')"
basename_two_clean_for_csv="$(echo "$basename_two_clean" | awk '{gsub(/[;]/,"_"); print $0}')"
tar_Plaintext_filename_clean_for_csv="$(echo "$tar_Plaintext_filename" | awk '{gsub(/[;]/,"_"); print $0}')"

# update log (.csv) 11 cells
echo "Decrypt;$basename_one_clean_for_csv.counter;$count_sender_var;$basename_two_clean_for_csv;$size_Ciphertext;next counter:;$counter_sender_update;$certificate_first_16_subjectKeyIdentifier;$tmp_date;$tar_time;$tar_Plaintext_filename_clean_for_csv;" >> "$filename_log"

echo "                        . . ."
echo "           output directory : $(pwd -P)/$dir_DECRYPTED"
echo "            output filename : $tar_Plaintext_filename"
echo "                        . . ."
echo "                       enjoy!"
echo "${COL_BLUE}@ @ @${COL_NORM}"

if [ "$cleaning_up_temporary_files" -eq 1 ]; then
  rm -f "$tmp_dir/$tar_Ciphertext_filename"
  rm -f "$tmp_dir/$tar_Ciphertext_shake256xof32_dgst.shake256"
  rm -d "$tmp_dir"
  rm -d "tmp"
fi

echo ""
echo "${COL_YELLOW}DONE.${COL_NORM}"
printf "\007"
date --rfc-3339=seconds

# EOF
