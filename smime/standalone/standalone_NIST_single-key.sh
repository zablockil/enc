#!/bin/bash
# key scheme: C + SE [dual use]
# faketime "2023-01-01 12:00:00" ./standalone_NIST_single-key.sh
# OpenSSL 1.1.1 and above

test_commonName="Roxanne Redlight"
test_email="test@example.com"

custom_days="$(($(($(date +%s -d "10 years") - $(date +%s)))/$((60*60*24))))"
user_usage_period_days="1185"
root_usage_period_days="$custom_days"

user_alias="user"
friendly_name_pkcs12="$test_commonName"

# sha256/sha384/sha512
default_md_root="sha512"
default_md_user="sha384"
# prime256v1/secp384r1/secp521r1
ec_paramgen_curve_root="secp521r1"
ec_paramgen_curve_user="secp384r1"

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

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:$ec_paramgen_curve_root > "private/root/key_root.pem"
openssl pkey -text -noout -in "private/root/key_root.pem" > "private/root/key_root.pem.txt"
openssl pkey -pubout -outform DER -in "private/root/key_root.pem" -out "private/root/key_root_pub.der"

root_PublicKey_shake256xof32=$(openssl dgst -shake256 "private/root/key_root_pub.der" | awk -F '=[[:blank:]]' '{print $NF}')

cat <<- EOF > "private/root/config_root.cfg"
### BEGIN SMIME standalone single-key [NIST EC] ROOT x509v3_config

[ req ]

	distinguished_name = smime_root_dn
	x509_extensions = x509_smime_root_ext
	string_mask = utf8only
	utf8 = yes
	prompt = no

[ smime_root_dn ]

	commonName=💌 $test_commonName

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

### END SMIME standalone single-key [NIST EC] ROOT x509v3_config
EOF

OPENSSL_CONF="private/root/config_root.cfg"

openssl req -new -x509 -days "$root_usage_period_days" -"$default_md_root" -set_serial "0x$(custom_serial)" -config "$OPENSSL_CONF" -key "private/root/key_root.pem" > "private/root/cert_root.crt"
{
	openssl x509 -purpose -text -noout -fingerprint -sha256 -in "private/root/cert_root.crt"
	openssl x509 -noout -fingerprint -sha1 -in "private/root/cert_root.crt"
} > "private/root/cert_root.crt.txt"

# USER/Subscriber

openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:$ec_paramgen_curve_user > "private/$user_alias/key_user.pem"
openssl pkey -text -noout -in "private/$user_alias/key_user.pem" > "private/$user_alias/key_user.pem.txt"
openssl pkey -pubout -outform DER -in "private/$user_alias/key_user.pem" -out "private/$user_alias/key_user_pub.der"

user_PublicKey_shake256xof32=$(openssl dgst -shake256 "private/$user_alias/key_user_pub.der" | awk -F '=[[:blank:]]' '{print $NF}')

cat <<- EOF > "private/$user_alias/config_user.cfg"
### BEGIN SMIME standalone single-key [NIST EC] USER x509v3_config

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

[ x509_smime_nist_user_ext ]

	basicConstraints = critical,CA:FALSE
	keyUsage = critical,digitalSignature,keyAgreement
	extendedKeyUsage = clientAuth,emailProtection
	authorityKeyIdentifier = keyid:always
	#subjectKeyIdentifier = hash
		# ↖ standard rfc-sha1
	subjectKeyIdentifier = "$user_PublicKey_shake256xof32"
	#subjectAltName = @subject_alt_name
	subjectAltName = critical,@subject_alt_name
		# ↖ NULL-DN cert

### END SMIME standalone single-key [NIST EC] USER x509v3_config
EOF

OPENSSL_CONF="private/$user_alias/config_user.cfg"

openssl req -new -config "$OPENSSL_CONF" -subj "/" -key "private/$user_alias/key_user.pem" > "private/$user_alias/csr_user.csr"
openssl req -text -noout -verify -in "private/$user_alias/csr_user.csr" > "private/$user_alias/csr_user.csr.txt"

openssl x509 -req -days "$user_usage_period_days" -"$default_md_user" -set_serial "0x$(custom_serial)" -in "private/$user_alias/csr_user.csr" -CA "private/root/cert_root.crt" -CAkey "private/root/key_root.pem" -extfile "$OPENSSL_CONF" -extensions x509_smime_nist_user_ext > "private/$user_alias/cert_user.crt"

{
	openssl x509 -purpose -text -noout -fingerprint -sha256 -in "private/$user_alias/cert_user.crt"
	openssl x509 -noout -fingerprint -sha1 -in "private/$user_alias/cert_user.crt"
} > "private/$user_alias/cert_user.crt.txt"

openssl crl2pkcs7 -nocrl -certfile "private/root/cert_root.crt" -certfile "private/$user_alias/cert_user.crt" > "public_$user_alias/credential_public.p7b"

openssl x509 -in "private/root/cert_root.crt" > "public_$user_alias/root.crt"
openssl x509 -in "private/$user_alias/cert_user.crt" > "public_$user_alias/user.crt"

{
	openssl pkey -in "private/$user_alias/key_user.pem"
	openssl x509 -in "private/$user_alias/cert_user.crt"
	openssl x509 -in "private/root/cert_root.crt"
} > "private/$user_alias/credential_private_unencrypted.pem"

openssl rand -base64 15 > "private/$user_alias/credential_private_password.txt"

openssl pkcs12 -export -certpbe AES-256-CBC -keypbe AES-256-CBC -macalg sha256 -name "$friendly_name_pkcs12" -in "private/$user_alias/credential_private_unencrypted.pem" -out "private/$user_alias/credential_private_encrypted.p12" -passout file:"private/$user_alias/credential_private_password.txt"

#
# .   standalone_NIST_single-key.sh
# |
# +---private
# |   +---root
# |   |       cert_root.crt
# |   |       cert_root.crt.txt
# |   |       config_root.cfg
# |   |       key_root.pem
# |   |       key_root.pem.txt
# |   |       key_root_pub.der
# |   |       openssl_version.txt
# |   |
# |   \---user
# |           cert_user.crt
# |           cert_user.crt.txt
# |           config_user.cfg
# |           credential_private_encrypted.p12
# |           credential_private_password.txt
# |           credential_private_unencrypted.pem
# |           csr_user.csr
# |           csr_user.csr.txt
# |           key_user.pem
# |           key_user.pem.txt
# |           key_user_pub.der
# |
# \---public_user
#         credential_public.p7b
#         root.crt
#         user.crt
#
#
# EOF
