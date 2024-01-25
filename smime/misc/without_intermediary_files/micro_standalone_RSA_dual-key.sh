#!/bin/bash
# key scheme: C + S + E
# faketime "2024-01-01 12:00:00" ./micro_standalone_RSA_dual-key.sh
# OpenSSL 1.1.1 and above

test_commonName="Ronald Divest"
test_email="test@example.com"

custom_days="$(($(($(date +%s -d "10 years") - $(date +%s)))/$((60*60*24))))"
user_usage_period_days="1185"
root_usage_period_days="$custom_days"

user_alias="user"
friendly_name_pkcs12="$test_commonName"

# sha256/sha384/sha512
default_md_root="sha256"
default_md_user_S="sha256"
default_md_user_E="sha256"
# 2048/3072/4096
keygen_bits_root="3072"
keygen_bits_user_S="2048"
keygen_bits_user_E="2048"

# -set_serial "0x$(custom_serial)"
custom_serial () {
	echo "$(shuf -i 1-7 -n 1)$(openssl rand -hex 20)" | cut -c1-16
}

# hex RootCA -set_serial "0x00"
# hex SubCA  -set_serial "0x01→0F"   max 15   (decimal 1→15)
# hex user   -set_serial "0x10→7F"   max 118  (decimal 16→127)
#      or
#        -set_serial "0x$(custom_serial)"

mkdir "public_$user_alias"
mkdir "private"
mkdir "private/$user_alias"

# ROOT/Issuer

mkdir "private/root"
openssl version -a > "private/root/openssl_version.txt"

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:$keygen_bits_root > "private/root/key_root.pem"

root_PublicKey_shake256xof32="$(openssl pkey -pubout -outform DER -in "private/root/key_root.pem" | openssl dgst -shake256 | awk -F '=[[:blank:]]' '{print $NF}')"

x509v3_config_root () {
cat <<EOF
### BEGIN SMIME standalone dual-key [RSA] ROOT x509v3_config

[ req ]

	distinguished_name = smime_root_dn
	x509_extensions = x509_smime_root_ext
	string_mask = utf8only
	utf8 = yes
	prompt = no

[ smime_root_dn ]

	commonName=💰 $test_commonName

[ x509_smime_root_ext ]

	basicConstraints = critical,CA:TRUE
	#basicConstraints = critical,CA:TRUE,pathlen:0
	keyUsage = critical,keyCertSign,cRLSign
	extendedKeyUsage = clientAuth,emailProtection
	#authorityKeyIdentifier = keyid:always
	#subjectKeyIdentifier = hash
		# ↖ standard rfc-sha1
	subjectKeyIdentifier = "$root_PublicKey_shake256xof32"
	#nsComment = ""

### END SMIME standalone dual-key [RSA] ROOT x509v3_config
EOF
}
#echo "$(x509v3_config_root)"

openssl req -new -x509 -days "$root_usage_period_days" -"$default_md_root" -set_serial "0x$(custom_serial)" -config <(echo "$(x509v3_config_root)") -key "private/root/key_root.pem" > "private/root/cert_root.crt"

{
	openssl x509 -purpose -text -noout -fingerprint -sha256 -in "private/root/cert_root.crt"
	openssl x509 -noout -fingerprint -sha1 -in "private/root/cert_root.crt"
} | awk '{ sub(/[ \t]+$/, ""); print }' > "private/root/cert_root.crt.txt"

# USER/Subscriber

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:$keygen_bits_user_S > "private/$user_alias/key_user_S.pem"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:$keygen_bits_user_E > "private/$user_alias/key_user_E.pem"

user_S_PublicKey_shake256xof32="$(openssl pkey -pubout -outform DER -in "private/$user_alias/key_user_S.pem" | openssl dgst -shake256 | awk -F '=[[:blank:]]' '{print $NF}')"
user_E_PublicKey_shake256xof32="$(openssl pkey -pubout -outform DER -in "private/$user_alias/key_user_E.pem" | openssl dgst -shake256 | awk -F '=[[:blank:]]' '{print $NF}')"

read -r -d '' MAIN_x509_extensions <<-'EOF'
	basicConstraints = critical,CA:FALSE
	authorityKeyIdentifier = keyid:always
	#subjectAltName = @subject_alt_name
	subjectAltName = critical,@subject_alt_name
		# ↖ NULL-DN cert
EOF

x509v3_config_user () {
cat <<EOF
### BEGIN SMIME standalone dual-key [RSA] USER x509v3_config

[ req ]

	distinguished_name = smime_user_dn
	#req_extensions =
	#x509_extensions =
	string_mask = utf8only
	utf8 = yes
	prompt = no

[ smime_user_dn ]

[ subject_alt_name ]

	email.0=$test_email
	#email.1=
	#otherName.0 =1.3.6.1.5.5.7.8.9;FORMAT:UTF8,UTF8String:
	#otherName.1 =1.3.6.1.5.5.7.8.9;FORMAT:UTF8,UTF8String:

[ x509_smime_rsa_user_S_ext ]

	keyUsage = critical,digitalSignature
	extendedKeyUsage = clientAuth,emailProtection
	#subjectKeyIdentifier = hash
		# ↖ standard rfc-sha1
	subjectKeyIdentifier = "$user_S_PublicKey_shake256xof32"
#################################### ↓ TEMPLATE "MAIN_x509_extensions" ↓
$MAIN_x509_extensions
#################################### ↑ TEMPLATE "MAIN_x509_extensions" ↑

[ x509_smime_rsa_user_E_ext ]

	keyUsage = critical,keyEncipherment
	extendedKeyUsage = emailProtection
	#subjectKeyIdentifier = hash
		# ↖ standard rfc-sha1
	subjectKeyIdentifier = "$user_E_PublicKey_shake256xof32"
#################################### ↓ TEMPLATE "MAIN_x509_extensions" ↓
$MAIN_x509_extensions
#################################### ↑ TEMPLATE "MAIN_x509_extensions" ↑

### END SMIME standalone dual-key [RSA] USER x509v3_config
EOF
}
#echo "$(x509v3_config_user)"

csr_user_S () {
cat <<EOF
$(openssl req -new -config <(echo "$(x509v3_config_user)") -subj "/" -key "private/$user_alias/key_user_S.pem")
EOF
}
#echo "$(csr_user_S)"

csr_user_E () {
cat <<EOF
$(openssl req -new -config <(echo "$(x509v3_config_user)") -subj "/" -key "private/$user_alias/key_user_E.pem")
EOF
}
#echo "$(csr_user_E)"

openssl x509 -req -days "$user_usage_period_days" -"$default_md_user_S" -set_serial "0x$(custom_serial)" -in <(echo "$(csr_user_S)") -CA "private/root/cert_root.crt" -CAkey "private/root/key_root.pem" -extfile <(echo "$(x509v3_config_user)") -extensions x509_smime_rsa_user_S_ext > "private/$user_alias/cert_user_S.crt"
openssl x509 -req -days "$user_usage_period_days" -"$default_md_user_E" -set_serial "0x$(custom_serial)" -in <(echo "$(csr_user_E)") -CA "private/root/cert_root.crt" -CAkey "private/root/key_root.pem" -extfile <(echo "$(x509v3_config_user)") -extensions x509_smime_rsa_user_E_ext > "private/$user_alias/cert_user_E.crt"

{
	openssl x509 -purpose -text -noout -fingerprint -sha256 -in "private/$user_alias/cert_user_S.crt"
	openssl x509 -noout -fingerprint -sha1 -in "private/$user_alias/cert_user_S.crt"
} | awk '{ sub(/[ \t]+$/, ""); print }' > "private/$user_alias/cert_user_S.crt.txt"
{
	openssl x509 -purpose -text -noout -fingerprint -sha256 -in "private/$user_alias/cert_user_E.crt"
	openssl x509 -noout -fingerprint -sha1 -in "private/$user_alias/cert_user_E.crt"
} | awk '{ sub(/[ \t]+$/, ""); print }' > "private/$user_alias/cert_user_E.crt.txt"

openssl crl2pkcs7 -nocrl -certfile "private/root/cert_root.crt" -certfile "private/$user_alias/cert_user_S.crt" -certfile "private/$user_alias/cert_user_E.crt" > "public_$user_alias/credential_public.p7b"

openssl x509 -in "private/root/cert_root.crt" > "public_$user_alias/root.crt"
openssl x509 -in "private/$user_alias/cert_user_S.crt" > "public_$user_alias/user_S.crt"
openssl x509 -in "private/$user_alias/cert_user_E.crt" > "public_$user_alias/user_E.crt"

{
	openssl pkey -in "private/$user_alias/key_user_S.pem"
	openssl x509 -in "private/$user_alias/cert_user_S.crt"
	openssl x509 -in "private/root/cert_root.crt"
} > "private/$user_alias/credential_private_unencrypted_S.pem"

{
	openssl pkey -in "private/$user_alias/key_user_E.pem"
	openssl x509 -in "private/$user_alias/cert_user_E.crt"
	openssl x509 -in "private/root/cert_root.crt"
} > "private/$user_alias/credential_private_unencrypted_E.pem"

openssl rand -base64 15 > "private/$user_alias/credential_private_password.txt"

openssl pkcs12 -export -certpbe AES-256-CBC -keypbe AES-256-CBC -macalg sha256 -name "$friendly_name_pkcs12" -in "private/$user_alias/credential_private_unencrypted_S.pem" -out "private/$user_alias/credential_private_encrypted_S.p12" -passout file:"private/$user_alias/credential_private_password.txt"

openssl pkcs12 -export -certpbe AES-256-CBC -keypbe AES-256-CBC -macalg sha256 -name "$friendly_name_pkcs12" -in "private/$user_alias/credential_private_unencrypted_E.pem" -out "private/$user_alias/credential_private_encrypted_E.p12" -passout file:"private/$user_alias/credential_private_password.txt"

#
# .   micro_standalone_RSA_dual-key.sh
# |
# +---private
# |   +---root
# |   |       cert_root.crt
# |   |       cert_root.crt.txt
# |   |       key_root.pem
# |   |       openssl_version.txt
# |   |
# |   \---user
# |           cert_user_E.crt
# |           cert_user_E.crt.txt
# |           cert_user_S.crt
# |           cert_user_S.crt.txt
# |           credential_private_encrypted_E.p12
# |           credential_private_encrypted_S.p12
# |           credential_private_password.txt
# |           credential_private_unencrypted_E.pem
# |           credential_private_unencrypted_S.pem
# |           key_user_E.pem
# |           key_user_S.pem
# |
# \---public_user
#         credential_public.p7b
#         root.crt
#         user_E.crt
#         user_S.crt
#
#
# EOF
