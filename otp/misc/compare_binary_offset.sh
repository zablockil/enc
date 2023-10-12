#!/bin/bash
##########
#
# Compares the [binary] offset in 1, 2 or 3 files
#
# Usage:
# ./compare_binary_offset.sh [OFFSET_bytes] [FILE_1] [OPTIONAL_FILE_2] [OPTIONAL_FILE_3]
#	e.g.
#	./compare_binary_offset.sh 7 OTP_KEY.dat secret_message.doc
#
##########

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 [OFFSET_bytes] [FILE_1] [OPTIONAL_FILE_2] [OPTIONAL_FILE_3]"
  echo ""
  echo "  e.g."
  echo "  $0 7 OTP_KEY.dat secret_message.doc"
  exit 1
fi

one="$(echo "$1" | awk '{printf "%.0f", $0}')"
two="$2"
three="$3"
four="$4"

if [ "$one" -lt 0 ]; then
  echo ""
  echo "! ! !"
  echo "       [OFFSET_bytes] must be"
  echo "   greater than or equal to 0"
  echo "! ! !"
exit 1
fi

if [ -s "$two" ]; then
  size_two="$(stat -c%s "$two")"
else
  size_two="0"
fi

if [ -s "$three" ]; then
  size_three="$(stat -c%s "$three")"
else
  size_three="0"
fi

if [ -s "$four" ]; then
  size_four="$(stat -c%s "$four")"
else
  size_four="0"
fi

error_0_bytes () {
cat <<EOF

! ! !
         files must be larger
                 than 0 bytes
! ! !
EOF
}

if [ "$size_two" -eq 0 ]; then
  error_0_bytes
  exit 1
fi

if [ -n "$three" ] && [ "$size_three" -eq 0 ]; then
  error_0_bytes
  exit 1
fi

if [ -n "$four" ] && [ "$size_four" -eq 0 ]; then
  error_0_bytes
  exit 1
fi

max_offset_two="$((size_two - 1))"
max_offset_three="$((size_three - 1))"
max_offset_four="$((size_four - 1))"

if [ "$one" -gt "$max_offset_two" ] || [ -n "$three" ] && [ "$one" -gt "$max_offset_three" ] || [ -n "$four" ] && [ "$one" -gt "$max_offset_four" ]; then
  echo ""
  echo "! ! !"
  echo "      offset specified in the"
  echo "      argument does not exist"
  echo "          in one of the files"
  echo "! ! !"
  exit 1
fi

basename_file_processed_func () {
  basename "$file_processed"
  }

# max: -N 4, change $max_offset, "expand -t ..."
print_hex_offset_func () {
  od -An -vtx1 -w4 -N 1 -j "$one" "$file_processed" | awk 'NR==1 {sub(/[[:blank:]]/,"");print $0}'
  }

awk_hex2bin () {
cat <<EOF
BEGIN {
FS=""
a["f"]="1111"
a["e"]="1110"
a["d"]="1101"
a["c"]="1100"
a["b"]="1011"
a["a"]="1010"
a["9"]="1001"
a["8"]="1000"
a["7"]="0111"
a["6"]="0110"
a["5"]="0101"
a["4"]="0100"
a["3"]="0011"
a["2"]="0010"
a["1"]="0001"
a["0"]="0000"
}
{
for (i=1;i<=NF;i++) printf a[tolower(\$i)]" "
print ""
}
EOF
}
#echo "$(awk_hex2bin)"

print_binary_func () {
  echo "$print_hex_offset_var" | awk -f <(echo "$(awk_hex2bin)")
  }

print_row_func () {
  echo -e "$print_hex_offset_var\t$(print_binary_func)\t$(basename_file_processed_func)" | expand -t 11
  }

# print header
echo -e "\n\toffset\t$one\n\nhex\tbinary\tfilename\n---\t------\t--------" | expand -t 11

file_processed="$two"
print_hex_offset_var="$(print_hex_offset_func)"
print_row_func

if [ -n "$three" ]; then
  file_processed="$three"
  print_hex_offset_var="$(print_hex_offset_func)"
  print_row_func
fi

if [ -n "$four" ]; then
  file_processed="$four"
  print_hex_offset_var="$(print_hex_offset_func)"
  print_row_func
fi

# EOF
