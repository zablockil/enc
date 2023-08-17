#!/bin/bash
##########
#
# X.509 S/MIME Key and CSR Generation Script
#
# Variant no. 1 :: RSA (PKCS #1 v1.5) / NIST (ECDSA/ECDH)
#
# Version: 2023.05.03
#
# Usage:
# ./generate_key_and_csr_smime.sh
#
# · Baseline Requirements for S/MIME Certificates
#   https://github.com/cabforum/smime/blob/main/SBR.md
# · RFC 2986, RFC 2985, RFC 5967
#
# support OpenSSL 1.1.1 and above
#
# After sending this CSR, you should receive a certificate from the CA
# with the following keyUsage:
#
#	· RSA:
#	keyUsage = critical, digitalSignature, keyEncipherment
#		or, if you're requesting a certificate for only one purpose:
#	keyUsage = critical, digitalSignature    (signing only)
#		or
#	keyUsage = critical, keyEncipherment     (encryption only)
#
#	· NIST EC:
#	keyUsage = critical, digitalSignature, keyAgreement
#		or, if you're requesting a certificate for only one purpose:
#	keyUsage = critical, digitalSignature    (signing only)
#		or
#	keyUsage = critical, keyAgreement        (encryption only)
#
# And, hopefully with our custom SKI hash, shake256.
#
##########


test_commonName="John Doe"
test_email="test@example.com"

user_alias="user"

# see: https://github.com/cabforum/smime/blob/main/SBR.md#615-key-sizes


# 1.2.840.113549.1.1.1
RSA_algorithm_identifier="rsaEncryption"
RSA_2048="-algorithm RSA -pkeyopt rsa_keygen_bits:2048"
RSA_3072="-algorithm RSA -pkeyopt rsa_keygen_bits:3072"
RSA_4096="-algorithm RSA -pkeyopt rsa_keygen_bits:4096"

# 1.2.840.10045.2.1
NIST_algorithm_identifier="id-ecPublicKey"
NIST_P_256="-algorithm EC -pkeyopt ec_paramgen_curve:prime256v1"
NIST_P_384="-algorithm EC -pkeyopt ec_paramgen_curve:secp384r1"
NIST_P_521="-algorithm EC -pkeyopt ec_paramgen_curve:secp521r1"



# YOUR CHOICE:

# sha256/sha384/sha512
user_default_md="sha256"
user_algo="$RSA_algorithm_identifier"
user_key_size="$RSA_2048"



# let's go through this

mkdir "$user_alias"
mkdir "$user_alias/private"

openssl version -a > "$user_alias/private/openssl_version.txt"

openssl genpkey $user_key_size > "$user_alias/private/key_user.pem"
openssl pkey -text -noout -in "$user_alias/private/key_user.pem" > "$user_alias/private/key_user.pem.txt"
openssl pkey -pubout -outform DER -in "$user_alias/private/key_user.pem" -out "$user_alias/private/key_user_pub.der"
user_PublicKey_shake256xof32=$(openssl dgst -c -shake256 "$user_alias/private/key_user_pub.der" | awk -F '=[[:blank:]]' '{print $NF}')
{
	echo "Requested SKI, 256-bit SHAKE-256 over SPKI."
	echo "-------------------------------------------"
	echo $user_PublicKey_shake256xof32
} > "$user_alias/private/subjectKeyIdentifier.txt"

cat <<- EOF > "$user_alias/private/config_csr_user.cfg"
### BEGIN SMIME CSR USER x509v3_config

	oid_section = new_oids

[ new_oids ]

	#organizationIdentifier = 2.5.4.97

[ req ]

	distinguished_name = smime_user_dn
	req_extensions = req_smime_user_ext
	string_mask = utf8only
	utf8 = yes
	prompt = no
	default_md = $user_default_md

[ smime_user_dn ]
	# ↖ see: https://github.com/cabforum/smime/blob/main/SBR.md#71426-subject-dn-attributes-for-individual-validated-profile

	commonName=$test_commonName

	#givenName=
	#surname=
	#pseudonym=
	#serialNumber=
	#emailAddress=$test_email
	#title=
	#streetAddress=
	#localityName=
	#stateOrProvinceName=
	#postalCode=
	#countryName=
	#organizationName=
	#organizationalUnitName=
	#organizationIdentifier=

[ subject_alt_name ]

	email.0=$test_email
	#email.1=
	#email.2=
	#otherName.0 =1.3.6.1.5.5.7.8.9;FORMAT:UTF8,UTF8String:
	#otherName.1 =1.3.6.1.5.5.7.8.9;FORMAT:UTF8,UTF8String:
	#otherName.2 =1.3.6.1.5.5.7.8.9;FORMAT:UTF8,UTF8String:

[ req_smime_user_ext ]
	# ↖ you CAN also add the following fields:
	# basicConstraints, keyUsage, extendedKeyUsage
	# CA may reject them

	subjectAltName = @subject_alt_name
	subjectKeyIdentifier = "$user_PublicKey_shake256xof32"
	2.5.29.9=ASN1:SEQUENCE:custom_Request

# https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.8
# https://www.openssl.org/docs/man1.1.1/man3/ASN1_generate_nconf.html
# https://github.com/openssl/openssl/blob/master/crypto/objects/objects.txt

[ custom_Request ]
	capabilityID.0 = SEQUENCE:algorithm_identifier

[ algorithm_identifier ]
	capabilityID = OID:$user_algo
	parameter.0 = SEQUENCE:sequence_ski
[ sequence_ski ]
	capabilityID = OID:2.5.29.14
	parameter = SEQUENCE:sequence_shake256
[ sequence_shake256 ]
	capabilityID = OID:2.16.840.1.101.3.4.2.12
	parameter = FORMAT:HEX,OCTWRAP,OCTETSTRING:$user_PublicKey_shake256xof32


### END SMIME CSR USER x509v3_config
EOF

OPENSSL_CONF="$user_alias/private/config_csr_user.cfg"

openssl req -new -config "$user_alias/private/config_csr_user.cfg" -key "$user_alias/private/key_user.pem" > "$user_alias/csr_user.csr"
openssl req -text -noout -verify -in "$user_alias/csr_user.csr" > "$user_alias/csr_user.csr.txt"

echo "DONE."
echo $(date --rfc-3339=seconds)


###
#
# When you receive the desired certificate from CA
# 1) check that everything is OK:
#	$ openssl x509 -purpose -text -noout -sha256 -fingerprint -in "CERTIFICATE.crt" > "CERTIFICATE.crt.txt"
# 2) create a .p12 file, ready for import in email clients
#    (assuming that files are in ASCII base64 format):
#	$ cat "key_user.pem" > "credential_unencrypted.pem"
#	$ cat "CERTIFICATE.crt" >> "credential_unencrypted.pem"
#	$ cat "SubCA_etc.crt" >> "credential_unencrypted.pem"
#	$ cat "RootCA_etc.crt" >> "credential_unencrypted.pem"
#	$ openssl pkcs12 -export -certpbe AES-256-CBC -keypbe AES-256-CBC -macalg sha256 -name "friendly_name" \
#		-in "credential_unencrypted.pem" -out "CREDENTIAL_ENCRYPTED.p12"
#
###
#
# .   generate_key_and_csr_smime.sh
# |
# \---user
#     |   csr_user.csr
#     |   csr_user.csr.txt
#     |
#     \---private
#             config_csr_user.cfg
#             key_user.pem
#             key_user.pem.txt
#             key_user_pub.der
#             openssl_version.txt
#             subjectKeyIdentifier.txt
#
###
#
# (LOW-LEVEL) custom Request
#
###
#
# 2.5.29.9=ASN1:SEQUENCE:custom_Request
# creates, for example, the following ASN.1 structure:
#
# SEQUENCE {
#   OBJECT IDENTIFIER subjectDirectoryAttributes (2 5 29 9)
#   OCTET STRING, encapsulates {
#     SEQUENCE {
#       SEQUENCE {
#         OBJECT IDENTIFIER rsaEncryption (1 2 840 113549 1 1 1)
#         SEQUENCE {
#           OBJECT IDENTIFIER subjectKeyIdentifier (2 5 29 14)
#           SEQUENCE {
#             OBJECT IDENTIFIER shake256 (2 16 840 1 101 3 4 2 12)
#             OCTET STRING, encapsulates {
#               OCTET STRING
#                 B5 C3 1A 49 4E AD CD FF 11 0F 57 56 F0 CB 28 56
#                 BB 80 28 9B 30 18 1E F4 E3 39 A7 8B E1 FD 55 89
#               }
#             }
#           }
#         }
#       }
#     }
#   }
#
# If you want to exclude shake256 OID, replace the following code:
#
# [ sequence_ski ]
#	capabilityID = OID:2.5.29.14
#	parameter = SEQUENCE:sequence_shake256
# [ sequence_shake256 ]
#	capabilityID = OID:2.16.840.1.101.3.4.2.12
#	parameter = FORMAT:HEX,OCTWRAP,OCTETSTRING:$user_PublicKey_shake256xof32
#
# as follows:
#
# [ sequence_ski ]
#	capabilityID = OID:2.5.29.14
#	parameter = FORMAT:HEX,OCTWRAP,OCTETSTRING:$user_PublicKey_shake256xof32
#
#
# EOF
