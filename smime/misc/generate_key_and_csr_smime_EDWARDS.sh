#!/bin/bash
##########
#
# X.509 S/MIME Key and CSR Generation Script
#
# Variant no. 2 :: EDWARDS (Ed25519/Ed448 and X25519/X448)
#
# Version: 2023.05.03
#
# Usage:
# ./generate_key_and_csr_smime_EDWARDS.sh
#
# · Baseline Requirements for S/MIME Certificates
#   https://github.com/cabforum/smime/blob/main/SBR.md
# · RFC 2986, RFC 2985, RFC 5967
#
# support OpenSSL 1.1.1 and above
#
# After sending this CSR, you should receive 2 (TWO) certificates from the CA
# with the following keyUsage:
#
#	· for Signing (ED25519/ED448):
#	keyUsage = critical, digitalSignature
#
#	· for Encrypting (X25519/X448):
#	keyUsage = critical, keyAgreement
#
# And, hopefully with our custom SKI hash, shake256.
#
##########


test_commonName="John Doe"
test_email="test@example.com"

user_alias="user"

# see: https://github.com/cabforum/smime/blob/main/SBR.md#615-key-sizes

# ED25519/ED448
sign_algorithm="ED25519"

# X25519/X448
encrypt_algorithm="X25519"



# YOUR CHOICE:

user_algo_sign="$sign_algorithm"
user_algo_encrypt="$encrypt_algorithm"



# let's go through this

mkdir "$user_alias"
mkdir "$user_alias/private"

openssl version -a > "$user_alias/private/openssl_version.txt"

openssl genpkey -algorithm $user_algo_sign > "$user_alias/private/key_user_S.pem"
openssl genpkey -algorithm $user_algo_encrypt > "$user_alias/private/key_user_E.pem"

openssl pkey -text -noout -in "$user_alias/private/key_user_S.pem" > "$user_alias/private/key_user_S.pem.txt"
openssl pkey -text -noout -in "$user_alias/private/key_user_E.pem" > "$user_alias/private/key_user_E.pem.txt"

openssl pkey -pubout -outform DER -in "$user_alias/private/key_user_S.pem" -out "$user_alias/private/key_user_pub_S.der"
openssl pkey -pubout -outform DER -in "$user_alias/private/key_user_E.pem" -out "$user_alias/private/key_user_pub_E.der"

user_S_PublicKey_shake256xof32=$(openssl dgst -c -shake256 "$user_alias/private/key_user_pub_S.der" | awk -F '=[[:blank:]]' '{print $NF}')
user_E_PublicKey_shake256xof32=$(openssl dgst -c -shake256 "$user_alias/private/key_user_pub_E.der" | awk -F '=[[:blank:]]' '{print $NF}')

# X25519 and X448 → -strparse 9
openssl pkey -pubout -outform DER -in "$user_alias/private/key_user_E.pem" | openssl asn1parse -inform DER -noout -strparse 9 -out "$user_alias/private/key_user_E_BITSTRING.der"
user_E_pub_strparse9=$(od -An -vtx1 "$user_alias/private/key_user_E_BITSTRING.der" | awk '{gsub(/[[:space:]]/,"");printf("%s",$0)}')

{
	echo "Requested SKI, 256-bit SHAKE-256 over SPKI."
	echo "-------------------------------------------"
	echo "Signing key:"
	echo "SKI: "$user_S_PublicKey_shake256xof32
	echo "--"
	echo "Encrypting key:"
	echo "pub: "$user_E_pub_strparse9
	echo "SKI: "$user_E_PublicKey_shake256xof32
} > "$user_alias/private/subjectKeyIdentifier.txt"

cat <<- EOF > "$user_alias/private/config_csr_user.cfg"
### BEGIN SMIME CSR USER EDWARDS x509v3_config

	oid_section = new_oids

[ new_oids ]

	#organizationIdentifier = 2.5.4.97

[ req ]

	distinguished_name = smime_user_dn
	req_extensions = req_smime_user_ext
	string_mask = utf8only
	utf8 = yes
	prompt = no

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
	subjectKeyIdentifier = "$user_S_PublicKey_shake256xof32"
	2.5.29.9=ASN1:SEQUENCE:custom_Request

# https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.8
# https://www.openssl.org/docs/man1.1.1/man3/ASN1_generate_nconf.html
# https://github.com/openssl/openssl/blob/master/crypto/objects/objects.txt
# https://stackoverflow.com/questions/67395119/specify-octetstring-as-hex-with-custom-asn1-object-in-openssl-config-file

[ custom_Request ]
	capabilityID.0 = SEQUENCE:signing_identifier
	capabilityID.1 = SEQUENCE:encrypting_identifier


[ signing_identifier ]
	capabilityID = OID:$user_algo_sign
	parameter.0 = SEQUENCE:sequence_ski_sign

[ sequence_ski_sign ]
	capabilityID = OID:2.5.29.14
	parameter = SEQUENCE:sequence_shake256_sign
[ sequence_shake256_sign ]
	capabilityID = OID:2.16.840.1.101.3.4.2.12
	parameter = FORMAT:HEX,OCTWRAP,OCTETSTRING:$user_S_PublicKey_shake256xof32


[ encrypting_identifier ]
	capabilityID = OID:$user_algo_encrypt
	parameter.0 = SEQUENCE:pubkeyinfo_encrypt
	parameter.1 = SEQUENCE:sequence_ski_encrypt

# CA will have to extract the public key E and substitute it with the public
# key S (-force_pubkey), and then sign the CSR made in this way.
# CA will have it easier: the key is "pasted" bit-exact into this structure.
# check: openssl asn1parse -dump -i -inform DER -in key_user_pub_E.der
#        openssl asn1parse -dump -i -in csr_user.csr
#        openssl asn1parse -dump -i -strparse xxx -in csr_user.csr
# extract pub_key from csr (example):
# openssl asn1parse -dump -strparse 208 -strparse 74 -noout -in csr_user.csr -out pub_key.der
[ pubkeyinfo_encrypt ]
	algorithm=SEQUENCE:algorithm_encrypt
	pubkey=FORMAT:HEX,BITSTRING:$user_E_pub_strparse9
[ algorithm_encrypt ]
	algorithm=OID:$user_algo_encrypt

[ sequence_ski_encrypt ]
	capabilityID = OID:2.5.29.14
	parameter = SEQUENCE:sequence_shake256_encrypt
[ sequence_shake256_encrypt ]
	capabilityID = OID:2.16.840.1.101.3.4.2.12
	parameter = FORMAT:HEX,OCTWRAP,OCTETSTRING:$user_E_PublicKey_shake256xof32


### END SMIME CSR USER EDWARDS x509v3_config
EOF

OPENSSL_CONF="$user_alias/private/config_csr_user.cfg"

openssl req -new -config "$user_alias/private/config_csr_user.cfg" -key "$user_alias/private/key_user_S.pem" > "$user_alias/csr_user.csr"
openssl req -text -noout -verify -in "$user_alias/csr_user.csr" > "$user_alias/csr_user.csr.txt"

echo "DONE."
echo $(date --rfc-3339=seconds)


###
#
# When you receive the desired certificates from CA
# 1) check that everything is OK:
#	$ openssl x509 -purpose -text -noout -sha256 -fingerprint -in "CERTIFICATE_S.crt" > "CERTIFICATE_S.crt.txt"
#	$ openssl x509 -purpose -text -noout -sha256 -fingerprint -in "CERTIFICATE_E.crt" > "CERTIFICATE_E.crt.txt"
# 2) create x2 a .p12 file, ready for import in email clients
#    (assuming that files are in ASCII base64 format):
#	$ cat "key_user_S.pem" > "credential_unencrypted_S.pem"
#	$ cat "CERTIFICATE_S.crt" >> "credential_unencrypted_S.pem"
#	$ cat "SubCA_etc.crt" >> "credential_unencrypted_S.pem"
#	$ cat "RootCA_etc.crt" >> "credential_unencrypted_S.pem"
#	$ openssl pkcs12 -export -certpbe AES-256-CBC -keypbe AES-256-CBC -macalg sha256 -name "friendly_name" \
#		-in "credential_unencrypted_S.pem" -out "CREDENTIAL_ENCRYPTED_S.p12"
# Repeat operation for the E key.
#
###
#
# .   generate_key_and_csr_smime_EDWARDS.sh
# |
# \---user
#     |   csr_user.csr
#     |   csr_user.csr.txt
#     |
#     \---private
#             config_csr_user.cfg
#             key_user_E.pem
#             key_user_E.pem.txt
#             key_user_E_BITSTRING.der
#             key_user_pub_E.der
#             key_user_pub_S.der
#             key_user_S.pem
#             key_user_S.pem.txt
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
# creates, for example (ED448/X448), the following ASN.1 structure:
#
#
# SEQUENCE {
#   OBJECT IDENTIFIER subjectDirectoryAttributes (2 5 29 9)
#   OCTET STRING, encapsulates {
#     SEQUENCE {
#       SEQUENCE {
#         OBJECT IDENTIFIER curveEd448 (1 3 101 113)
#         SEQUENCE {
#           OBJECT IDENTIFIER subjectKeyIdentifier (2 5 29 14)
#           SEQUENCE {
#             OBJECT IDENTIFIER shake256 (2 16 840 1 101 3 4 2 12)
#             OCTET STRING, encapsulates {
#               OCTET STRING
#                 A3 D7 AD 0C D3 20 A7 95 41 96 C7 CC 46 09 12 22
#                 58 9E 46 C9 B1 6A 4A 7B 6D 7C 9B 70 6D 27 1B 1C
#               }
#             }
#           }
#         }
#       SEQUENCE {
#         OBJECT IDENTIFIER curveX448 (1 3 101 111)
#         SEQUENCE {
#           SEQUENCE {
#             OBJECT IDENTIFIER curveX448 (1 3 101 111)
#             }
#           BIT STRING
#             E1 DA CA C3 E5 6A A6 41 1D C0 7C 5E 45 DB 78 C4
#             64 50 BB 7E F4 27 AF 47 C8 55 8D B7 9D 43 32 C7
#             4E 77 EB 9B DB B2 D3 9A AB E7 83 A5 80 65 45 CD
#             93 ED 8A 81 49 B1 AF CB
#           }
#         SEQUENCE {
#           OBJECT IDENTIFIER subjectKeyIdentifier (2 5 29 14)
#           SEQUENCE {
#             OBJECT IDENTIFIER shake256 (2 16 840 1 101 3 4 2 12)
#             OCTET STRING, encapsulates {
#               OCTET STRING
#                 D9 3B 63 2C 10 F3 6C 7A 6F A0 F5 D6 4D CB 1B 95
#                 09 42 8C A0 5D C2 E5 7F AC AF 89 0C A8 70 3D 40
#               }
#             }
#           }
#         }
#       }
#     }
#   }
#
#
# EOF
