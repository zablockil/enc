#!/bin/bash
##########
#
# Creates a database of certificates in CSV format
# see: csv_database.png / csv_database.csv
#
# Usage:
# ./csv_database.sh
#
# https://www.openssl.org/docs/manmaster/man1/openssl-x509.html
#
##########

# Path to the certificate
path_cert="public_user/user.crt"

user_alias="user"


csv_NotAfter=$(date -d "$(openssl x509 -noout -enddate -in $path_cert | awk -F '=' '{print $NF}')" --rfc-3339=seconds)
csv_NotBefore=$(date -d "$(openssl x509 -noout -startdate -in $path_cert | awk -F '=' '{print $NF}')" --rfc-3339=seconds)
csv_Serial="$(openssl x509 -noout -serial -in $path_cert | awk -F '=' '{print $NF}')"
csv_keyUsage="$(openssl x509 -noout -ext keyUsage -nameopt oneline -in $path_cert | awk '/X509v3 Key Usage/ {getline;print gensub("^ +","","g",$0)}')"
csv_Subject=$(openssl x509 -noout -subject -nameopt oneline,-esc_2253 -in $path_cert | awk -F 'subject=' '{print $NF}')
csv_SubjectAlternativeName="$(openssl x509 -noout -ext subjectAltName -nameopt oneline -in $path_cert | awk '/X509v3 Subject Alternative Name/ {getline;print gensub("^ +","","g",$0)}')"
csv_subjectKeyIdentifier="$(openssl x509 -noout -ext subjectKeyIdentifier -in $path_cert | awk '/X509v3 Subject Key Identifier/ {getline;print gensub("^ +","","g",$0)}')"
csv_fingerprint_sha256="$(openssl x509 -noout -fingerprint -sha256 -in $path_cert | awk -F '=' '{print $NF}')"
csv_fingerprint_sha1="$(openssl x509 -noout -fingerprint -sha1 -in $path_cert | awk -F '=' '{print $NF}')"


# HEADER, write only once
# status for e.g.: V "Valid", R "Revoked", E "Expired"
echo "status;user alias;expiration date;not before;serial number;key usage;subject distinguished name;subject alternative name;subject key identifier;fingerprint sha256;fingerprint sha1;comment;" > "csv_database.csv"


echo "V;$user_alias;$csv_NotAfter;$csv_NotBefore;$csv_Serial;$csv_keyUsage;$csv_Subject;$csv_SubjectAlternativeName;$csv_subjectKeyIdentifier;$csv_fingerprint_sha256;$csv_fingerprint_sha1;;" >> "csv_database.csv"




# EOF
