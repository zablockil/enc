#!/bin/bash
##########
#
# X.509 S/MIME Certificate Revocation List (CRL) Generation Script
#
# RSA / NIST (ECDSA/ECDH) / EDWARDS (Ed25519/Ed448 and X25519/X448)
#
# The script runs in two (2) passes:
#  1) creates an empty .crl file
#  2) adds an entry to the created .crl file with revocation of specified key
# If you are revoking a second certificate or a third certificate, etc.,
# comment out the relevant lines of code.
#
# Usage:
# · place the script next to the one from which you previously created
#   certificates (e.g. "standalone_NIST_single-key.sh"), edit the variable
#   "revoke_cert" (if you must) and run:
#
# ./revoke_certificate.sh
#
# · The finished .crl file will be located in:
#  "private/root/[serial].crl"
#
# support OpenSSL 1.1.1 and above
#
# https://www.openssl.org/docs/man1.1.1/man1/openssl-ca.html
# https://www.openssl.org/docs/man1.1.1/man1/openssl-crl.html
# https://github.com/openssl/openssl/blob/master/apps/openssl.cnf
# https://www.openssl.org/docs/manmaster/man5/x509v3_config.html
#
# https://github.com/cabforum/smime/blob/main/SBR.md#72-crl-profile
# https://datatracker.ietf.org/doc/html/rfc5280#section-5
#
##########


# Path to the certificate to be revoked
revoke_cert="public_user/user.crt"

# The CA private directory
ca_directory="private/root"

# sha256/sha384/sha512
default_md_crl="sha256"
# for Ed25519/Ed448 irrelevant

# "$dummy_crl_root" from "clean_RSA_single-key.sh"
ca_serial_number=$(openssl x509 -noout -serial -in $ca_directory/cert_root.crt | awk -F '=' '{print $NF}')




##########
# Creates empty CRL (no entry)
# After revoking the FIRST certificate, comment the following lines   ↓↓↓  ↓↓↓
##########

touch "$ca_directory/crl_index.txt"
echo "010000" > "$ca_directory/crl_number.txt"
# hex "010000"
# hex  010000→7FFFFF   max 8323072   (decimal 65536→8388607)
# hex "0100"
# hex  0100→7FFF       max 32512     (decimal 256→32767)
# hex "01"
# hex  01→7F           max 127       (decimal 1→127)

cat <<- EOF > "$ca_directory/config_ca_revocation.cfg"
### BEGIN SMIME CA minimal CRL x509v3_config

[ ca ]

	default_ca = root_revocation_list

[ root_revocation_list ]

	database = ./$ca_directory/crl_index.txt
	crlnumber = ./$ca_directory/crl_number.txt

	certificate = ./$ca_directory/cert_root.crt
	private_key = ./$ca_directory/key_root.pem

	default_crl_days = 30
	crl_extensions = CRL_extension
	default_md = $default_md_crl

[ CRL_extension ]

	authorityKeyIdentifier = keyid:always
	#authorityInfoAccess = @auth_info_access
	#issuingDistributionPoint = critical, @idp_section

[ auth_info_access ]

	caIssuers;URI.0=http://my1.ca/cert_root.der
	#caIssuers;URI.2=http://my2.ca/cert_root.der

[ idp_section ]

	fullname = URI:http://my1.ca/crl/$ca_serial_number.crl, URI:http://my2.ca/crl/$ca_serial_number.crl
	#onlysomereasons = keyCompromise, CACompromise

	#onlyuser = TRUE
	#onlyCA = TRUE
	#onlyAA = TRUE
	#indirectCRL = TRUE

### END SMIME CA minimal CRL x509v3_config
EOF

OPENSSL_CONF="$ca_directory/config_ca_revocation.cfg"

openssl ca -config "$OPENSSL_CONF" -gencrl -out "$ca_directory/$ca_serial_number.crl"

##########
# After revoking the FIRST certificate, comment the previous lines    ↑↑↑  ↑↑↑
##########




OPENSSL_CONF="$ca_directory/config_ca_revocation.cfg"

# crl_reason :
# unspecified/keyCompromise/CACompromise/affiliationChanged/superseded/
# cessationOfOperation/certificateHold/removeFromCRL
openssl ca -config "$OPENSSL_CONF" -crl_reason keyCompromise -revoke "$revoke_cert"

# Refresh the Certificate Revocation List
openssl ca -config "$OPENSSL_CONF" -gencrl -out "$ca_directory/$ca_serial_number.crl"

openssl crl -text -noout -in "$ca_directory/$ca_serial_number.crl" > "$ca_directory/$ca_serial_number.crl.txt"

echo ""
echo "DONE."
echo $(date --rfc-3339=seconds)


###
#
# Other steps:
#
# 1) publish the fresh CRL to the CA website (crlDistributionPoints)
# 2) refresh the .p7b file (offline) and send it to the recipients:
#	$ openssl crl2pkcs7 -in CRL.crl -certfile cert_root.crt \
#		-certfile NEW_cert_user.crt > credential_public.p7b
#
###
#
#
# EOF
