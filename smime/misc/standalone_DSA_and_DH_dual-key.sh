#!/bin/bash
# key scheme: C + S + E
# faketime "2023-01-01 12:00:00" ./standalone_DSA_and_DH_dual-key.sh
# OpenSSL 3 and above

test_commonName="Glenn Quagmire"
test_email="quagmire@example.com"

custom_days="$(($(($(date +%s -d "10 years") - $(date +%s)))/$((60*60*24))))"
user_usage_period_days="1185"
root_usage_period_days="${custom_days}"

user_alias="user"
friendly_name_pkcs12="${test_commonName}"

#
# CMS: rfc2630/rfc3369/rfc3370
# rfc3279, rfc6664#section-3
#

# sha1/sha224/sha256
default_md_cert_root="sha256"
default_md_cert_user_S="sha256"
default_md_cert_user_E="sha256"

# DSA (Digital Signature Algorithm)
# FIPS-186-4, rfc5754, rfc5758
#
# 1024/2048/3072
dsa_paramgen_bits_root="2048"
dsa_paramgen_bits_user_S="2048"
# 160/224/256
dsa_paramgen_q_bits_root="256"
dsa_paramgen_q_bits_user_S="256"
# sha1/sha224/sha256
dsa_paramgen_md_root="sha256"
dsa_paramgen_md_user_S="sha256"
# dsa_paramgen_q_bits = dsa_paramgen_md

# DH (Diffie-Hellman)
# rfc2631, rfc5114
#
# 1024/2048
dh_paramgen_prime_len_user_E="2048"
# 160/224/256
dh_paramgen_subprime_len_user_E="256"
# dh_1024_160 / dh_2048_224 / dh_2048_256


# -set_serial "0x$(custom_serial)"
custom_serial () {
	echo "$(shuf -i 1-7 -n 1)$(openssl rand -hex 20)" | cut -c1-16
}

# hex RootCA -set_serial "0x00"
# hex SubCA  -set_serial "0x01→0F"   max 15   (decimal 1→15)
# hex user   -set_serial "0x10→7F"   max 118  (decimal 16→127)
#      or
#        -set_serial "0x$(custom_serial)"

mkdir "public_${user_alias}"
mkdir "private"
mkdir "private/${user_alias}"

# ROOT/Issuer

mkdir "private/root"
openssl version -a > "private/root/openssl_version.txt"

openssl genpkey -genparam -algorithm DSA -pkeyopt dsa_paramgen_bits:${dsa_paramgen_bits_root} -pkeyopt dsa_paramgen_q_bits:${dsa_paramgen_q_bits_root} -pkeyopt dsa_paramgen_md:${dsa_paramgen_md_root} > "private/root/key_root_param.pem"
openssl genpkey -paramfile "private/root/key_root_param.pem" > "private/root/key_root.pem"
openssl pkey -text -noout -in "private/root/key_root.pem" > "private/root/key_root.pem.txt"
openssl pkey -pubout -outform DER -in "private/root/key_root.pem" -out "private/root/key_root_pub.der"

root_PublicKey_shake256xof32=$(openssl dgst -shake256 "private/root/key_root_pub.der" | awk -F '=[[:blank:]]' '{print $NF}')

cat <<- EOF > "private/root/config_root.cfg"
### BEGIN SMIME standalone dual-key [DSA+DH] ROOT x509v3_config

[ req ]

	distinguished_name = smime_root_dn
	x509_extensions = x509_smime_root_ext
	string_mask = utf8only
	utf8 = yes
	prompt = no

[ smime_root_dn ]

	commonName=😲 ${test_commonName}

[ x509_smime_root_ext ]

	basicConstraints = critical,CA:TRUE
	#basicConstraints = critical,CA:TRUE,pathlen:0
	keyUsage = critical,keyCertSign,cRLSign
	extendedKeyUsage = clientAuth,emailProtection
	#authorityKeyIdentifier = keyid:always
	#subjectKeyIdentifier = hash
		# ↖ standard rfc-sha1
	subjectKeyIdentifier = ${root_PublicKey_shake256xof32}
	#nsComment = ""

### END SMIME standalone dual-key [DSA+DH] ROOT x509v3_config
EOF

OPENSSL_CONF="private/root/config_root.cfg"

openssl req -new -x509 -days "${root_usage_period_days}" -"${default_md_cert_root}" -set_serial "0x$(custom_serial)" -config "${OPENSSL_CONF}" -key "private/root/key_root.pem" > "private/root/cert_root.crt"
{
	openssl x509 -purpose -text -noout -fingerprint -sha256 -in "private/root/cert_root.crt"
	openssl x509 -noout -fingerprint -sha1 -in "private/root/cert_root.crt"
} | awk '{ sub(/[ \t]+$/, ""); print }' > "private/root/cert_root.crt.txt"

# USER/Subscriber

openssl genpkey -genparam -algorithm DSA -pkeyopt dsa_paramgen_bits:${dsa_paramgen_bits_user_S} -pkeyopt dsa_paramgen_q_bits:${dsa_paramgen_q_bits_user_S} -pkeyopt dsa_paramgen_md:${dsa_paramgen_md_user_S} > "private/${user_alias}/key_user_S_param.pem"
openssl genpkey -paramfile "private/${user_alias}/key_user_S_param.pem" > "private/${user_alias}/key_user_S.pem"

openssl genpkey -genparam -algorithm DHX -pkeyopt dh_paramgen_prime_len:${dh_paramgen_prime_len_user_E} -pkeyopt dh_paramgen_subprime_len:${dh_paramgen_subprime_len_user_E} -pkeyopt dh_paramgen_type:1 > "private/${user_alias}/key_user_E_param.pem"
openssl genpkey -paramfile "private/${user_alias}/key_user_E_param.pem" > "private/${user_alias}/key_user_E.pem"

openssl pkey -text -noout -in "private/${user_alias}/key_user_S.pem" > "private/${user_alias}/key_user_S.pem.txt"
openssl pkey -text -noout -in "private/${user_alias}/key_user_E.pem" > "private/${user_alias}/key_user_E.pem.txt"

openssl pkey -pubout -outform DER -in "private/${user_alias}/key_user_S.pem" -out "private/${user_alias}/key_user_S_pub.der"
openssl pkey -pubout -outform DER -in "private/${user_alias}/key_user_E.pem" -out "private/${user_alias}/key_user_E_pub.der"

user_S_PublicKey_shake256xof32=$(openssl dgst -shake256 "private/${user_alias}/key_user_S_pub.der" | awk -F '=[[:blank:]]' '{print $NF}')
user_E_PublicKey_shake256xof32=$(openssl dgst -shake256 "private/${user_alias}/key_user_E_pub.der" | awk -F '=[[:blank:]]' '{print $NF}')

read -r -d '' MAIN_x509_extensions <<-'EOF'
	basicConstraints = critical,CA:FALSE
	authorityKeyIdentifier = keyid:always
	#subjectAltName = @subject_alt_name
	subjectAltName = critical,@subject_alt_name
		# ↖ NULL-DN cert
EOF

cat <<- EOF > "private/${user_alias}/config_user.cfg"
### BEGIN SMIME standalone dual-key [DSA+DH] USER x509v3_config

[ req ]

	distinguished_name = smime_user_dn
	#req_extensions =
	#x509_extensions =
	string_mask = utf8only
	utf8 = yes
	prompt = no

[ smime_user_dn ]

[ subject_alt_name ]

	email.0=${test_email}
	#email.1=
	#otherName.0 =1.3.6.1.5.5.7.8.9;FORMAT:UTF8,UTF8String:
	#otherName.1 =1.3.6.1.5.5.7.8.9;FORMAT:UTF8,UTF8String:

[ x509_smime_DSA_user_S_ext ]

	keyUsage = critical,digitalSignature
	extendedKeyUsage = clientAuth,emailProtection
	#subjectKeyIdentifier = hash
		# ↖ standard rfc-sha1
	subjectKeyIdentifier = ${user_S_PublicKey_shake256xof32}
#################################### ↓ TEMPLATE "MAIN_x509_extensions" ↓
${MAIN_x509_extensions}
#################################### ↑ TEMPLATE "MAIN_x509_extensions" ↑

[ x509_smime_DH_user_E_ext ]

	keyUsage = critical,keyAgreement
	extendedKeyUsage = emailProtection
	#subjectKeyIdentifier = hash
		# ↖ standard rfc-sha1
	subjectKeyIdentifier = ${user_E_PublicKey_shake256xof32}
#################################### ↓ TEMPLATE "MAIN_x509_extensions" ↓
${MAIN_x509_extensions}
#################################### ↑ TEMPLATE "MAIN_x509_extensions" ↑

### END SMIME standalone dual-key [DSA+DH] USER x509v3_config
EOF

OPENSSL_CONF="private/${user_alias}/config_user.cfg"

openssl req -new -config "${OPENSSL_CONF}" -subj "/" -key "private/${user_alias}/key_user_S.pem" > "private/${user_alias}/csr_user_S.csr"

openssl req -text -noout -verify -in "private/${user_alias}/csr_user_S.csr" > "private/${user_alias}/csr_user_S.csr.txt"

openssl x509 -req -days "${user_usage_period_days}" -"${default_md_cert_user_S}" -set_serial "0x$(custom_serial)" -in "private/${user_alias}/csr_user_S.csr" -CA "private/root/cert_root.crt" -CAkey "private/root/key_root.pem" -extfile "${OPENSSL_CONF}" -extensions x509_smime_DSA_user_S_ext > "private/${user_alias}/cert_user_S.crt"
openssl x509 -req -days "${user_usage_period_days}" -"${default_md_cert_user_E}" -set_serial "0x$(custom_serial)" -in "private/${user_alias}/csr_user_S.csr" -CA "private/root/cert_root.crt" -CAkey "private/root/key_root.pem" -force_pubkey "private/${user_alias}/key_user_E_pub.der" -keyform DER -extfile "${OPENSSL_CONF}" -extensions x509_smime_DH_user_E_ext > "private/${user_alias}/cert_user_E.crt"

{
	openssl x509 -purpose -text -noout -fingerprint -sha256 -in "private/${user_alias}/cert_user_S.crt"
	openssl x509 -noout -fingerprint -sha1 -in "private/${user_alias}/cert_user_S.crt"
} | awk '{ sub(/[ \t]+$/, ""); print }' > "private/${user_alias}/cert_user_S.crt.txt"
{
	openssl x509 -purpose -text -noout -fingerprint -sha256 -in "private/${user_alias}/cert_user_E.crt"
	openssl x509 -noout -fingerprint -sha1 -in "private/${user_alias}/cert_user_E.crt"
} | awk '{ sub(/[ \t]+$/, ""); print }' > "private/${user_alias}/cert_user_E.crt.txt"

openssl crl2pkcs7 -nocrl -certfile "private/root/cert_root.crt" -certfile "private/${user_alias}/cert_user_S.crt" -certfile "private/${user_alias}/cert_user_E.crt" > "public_${user_alias}/credential_public.p7b"

openssl x509 -in "private/root/cert_root.crt" > "public_${user_alias}/root.crt"
openssl x509 -in "private/${user_alias}/cert_user_S.crt" > "public_${user_alias}/user_S.crt"
openssl x509 -in "private/${user_alias}/cert_user_E.crt" > "public_${user_alias}/user_E.crt"

{
	openssl pkey -in "private/${user_alias}/key_user_S.pem"
	openssl x509 -in "private/${user_alias}/cert_user_S.crt"
	openssl x509 -in "private/root/cert_root.crt"
} > "private/${user_alias}/credential_private_unencrypted_S.pem"

{
	openssl pkey -in "private/${user_alias}/key_user_E.pem"
	openssl x509 -in "private/${user_alias}/cert_user_E.crt"
	openssl x509 -in "private/root/cert_root.crt"
} > "private/${user_alias}/credential_private_unencrypted_E.pem"

openssl rand -base64 15 > "private/${user_alias}/credential_private_password.txt"

openssl pkcs12 -export -certpbe AES-256-CBC -keypbe AES-256-CBC -macalg sha256 -name "${friendly_name_pkcs12}" -in "private/${user_alias}/credential_private_unencrypted_S.pem" -out "private/${user_alias}/credential_private_encrypted_S.p12" -passout file:"private/${user_alias}/credential_private_password.txt"

openssl pkcs12 -export -certpbe AES-256-CBC -keypbe AES-256-CBC -macalg sha256 -name "${friendly_name_pkcs12}" -in "private/${user_alias}/credential_private_unencrypted_E.pem" -out "private/${user_alias}/credential_private_encrypted_E.p12" -passout file:"private/${user_alias}/credential_private_password.txt"




# EOF
