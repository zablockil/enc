#!/bin/bash
##########
#
# Creates a random encryption one-time key (OTP) and...
# two pairs of NIST EC asymmetric keys for each party
#
# Usage:
# ./make_encryption_keys_gcm.sh [bytes] [OTP_KEY] [RECIPIENT_1] [RECIPIENT_2]
#	e.g.
#	./make_encryption_keys_gcm.sh 1048576 OTP_KEY PERSON_A PERSON_B
#
# 1048576 bytes → 1    MiB
# 10485760      → 10   MiB
# 104857600     → 100  MiB
# 734003200     → 700  MiB (CD-R)
#
##########

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 [bytes] [OTP_KEY] [RECIPIENT_1] [RECIPIENT_2]"
  echo ""
  echo "  e.g."
  echo "  $0 1048576 OTP_KEY PERSON_A PERSON_B"
  exit 1
fi

one="$(echo "$1" | awk '{printf "%.0f", $0}')"
two="$2"
three="$3"
four="$4"

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

# test openssl version 3 (xoflen)
test_message () {
cat <<-"EOF"
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
  echo "                   you have : ${old_openssl}"
  echo "                        . . ."
  echo "                         bye!"
  echo "! ! !"
  exit 1
fi

if [ "${one}" -lt 1 ]; then
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

if [ "$(disk_space_func)" -lt "${one}" ]; then
  echo ""
  echo "! ! !"
  echo "       not enough disk space!"
  echo "! ! !"
  exit 1
fi

##########
#
# Public-key cryptography part
# 2 x NIST EC secp521r1 / sha512
# simple, self-signed key+cert
# see also: "standalone_NIST_single-key.sh"
#
# Private key = sign and decrypt
# Public key  = signature check and encrypt
#
##########

custom_days="$(($(($(date +%s -d "100 years") - $(date +%s)))/$((60*60*24))))"

custom_serial () {
  echo "$(shuf -i 1-7 -n 1)$(openssl rand -hex 20)" | cut -c1-16
  }

serial_alfanum5 () {
  echo "$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 5 ; echo '')"
  }

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:secp521r1 > "${three}.pem"
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:secp521r1 > "${four}.pem"

x509v3_config_standaloneCertificate () {
cat <<EOF
[ req ]

distinguished_name = smime_standalone_dn
x509_extensions = x509_smime_standalone_ext
string_mask = utf8only
utf8 = yes
prompt = no

[ smime_standalone_dn ]

commonName=$(serial_alfanum5)

[ x509_smime_standalone_ext ]

basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyAgreement
extendedKeyUsage = emailProtection
#subjectKeyIdentifier = hash
# ↖ standard rfc-sha1
subjectKeyIdentifier = ${PublicKey_shake256xof32}

EOF
}

PublicKey_shake256xof32="$(openssl pkey -pubout -outform DER -in "${three}.pem" | openssl dgst -shake256 -xoflen 32 | awk -F '=[[:blank:]]' '{print $NF}')"
openssl req -new -x509 -days "${custom_days}" -sha512 -set_serial "0x$(custom_serial)" -config <(echo "$(x509v3_config_standaloneCertificate)") -key "${three}.pem" > "${three}.crt"

PublicKey_shake256xof32="$(openssl pkey -pubout -outform DER -in "${four}.pem" | openssl dgst -shake256 -xoflen 32 | awk -F '=[[:blank:]]' '{print $NF}')"
openssl req -new -x509 -days "${custom_days}" -sha512 -set_serial "0x$(custom_serial)" -config <(echo "$(x509v3_config_standaloneCertificate)") -key "${four}.pem" > "${four}.crt"

cat "${three}.crt" >> "${three}.pem"
cat "${four}.crt" >> "${four}.pem"

##########
#
# One-time Pad part
#
##########

shuf_10_50_mib () {
  echo "$(shuf -i 10485760-52428800 -n 1)"
  }

make_garbage_0 () {
  openssl rand "$(shuf_10_50_mib)" > /dev/null
  dd if=/dev/urandom bs="$(shuf_10_50_mib)" count=1 status=none > /dev/null
  }

make_garbage_no5 () {
  make_garbage_0
  openssl rand "$(shuf_10_50_mib)" | openssl dgst -shake256 -xoflen 16 | awk -F '=[[:blank:]]' '{print $NF}'
  }
make_garbage_no6 () {
  make_garbage_0
  dd if=/dev/urandom bs="$(shuf_10_50_mib)" count=1 status=none | openssl dgst -shake256 -xoflen 16 | awk -F '=[[:blank:]]' '{print $NF}'
  }
make_garbage_no7 () {
  make_garbage_0
  openssl rand "$(shuf_10_50_mib)" | openssl dgst -shake256 -xoflen 32 | awk -F '=[[:blank:]]' '{print $NF}'
  }
make_garbage_no8 () {
  make_garbage_0
  dd if=/dev/urandom bs="$(shuf_10_50_mib)" count=1 status=none | openssl dgst -shake256 -xoflen 32 | awk -F '=[[:blank:]]' '{print $NF}'
  }

make_garbage_0

# you can use "-camellia-256-ctr" / "-aria-256-ctr"


# variant one
#openssl rand "${one}" | openssl enc -aes-256-ctr -p -v -nosalt -K "$(make_garbage_no8)" -iv "$(make_garbage_no6)" -out "${two}.dat"

# variant two
dd if=/dev/urandom bs="${one}" count=1 | openssl enc -aes-256-ctr -p -v -nosalt -K "$(make_garbage_no7)" -iv "$(make_garbage_no5)" -out "${two}.dat"

size_KeyStream="$(stat -c%s "${two}.dat")"
size_KeyStream_mib_approx="$(echo "${size_KeyStream}" | numfmt --to=iec-i --suffix=B)"

echo ""
echo "# # #"
echo "   encryption key file size : ${size_KeyStream} (${size_KeyStream_mib_approx})"
echo "                              [bytes]"
echo "# # #"

echo ""
echo "DONE."
date --rfc-3339=seconds

# EOF
