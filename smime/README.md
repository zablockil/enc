## X.509 S/MIME Key Generation Script
### self-signed S/MIME certificates

for e-mail testing purposes (or micro CA for Privately-Trusted S/MIME Certificates TOFU)

Script generates files in the "private" and "public_user" folders and uses its clean generated configuration (heredoc), max portability.

### Notes

The script was based on the findings of the *CA/Browser Forum* and [document](https://github.com/cabforum/smime/blob/main/SBR.md): *Baseline Requirements for the Issuance and Management of Publicly-Trusted S/MIME Certificates* Version 1.0.0. Rule of issuance for: *Individual-validated* - human being. Practices used by companies issuing such certificates were also followed.

[S/MIME Certs vicious cycle](https://news.ycombinator.com/item?id=19798453)

[If OpenSSL were a GUI](https://smallstep.com/blog/if-openssl-were-a-gui/)

### Usage

1. download a [liveCD Linux](https://distrowatch.com/search.php?category=Data+Rescue) distribution.
2. copy script to the ramdisk `/tmp/` directory
3. `cd /tmp/smime/`
4. edit script
5. run: `./standalone_RSA_single-key.sh`

* ready-to-use certificates will be in: `private/user/credential_private_encrypted.p12`
* a directory containing only public keys/certificates: `public_user`

1) extended scripts
* `./clean/clean_RSA_single-key.sh`
* `./clean/clean_RSA_dual-key.sh`
* `./clean/clean_RSA-PSS_single-key.sh`
* `./clean/clean_RSA-PSS_dual-key.sh`
* `./clean/clean_NIST_single-key.sh`
* `./clean/clean_NIST_dual-key.sh`
* `./clean/clean_EDWARDS_dual-key.sh`

2) standalone, lightweight certificates, similar in structure to gpg keys (C+SE, C+S+E), for individuals only
* `./standalone/standalone_RSA_single-key.sh`
* `./standalone/standalone_RSA_dual-key.sh`
* `./standalone/standalone_RSA-PSS_single-key.sh`
* `./standalone/standalone_RSA-PSS_dual-key.sh`
* `./standalone/standalone_NIST_single-key.sh`
* `./standalone/standalone_NIST_dual-key.sh`
* `./standalone/standalone_EDWARDS_dual-key.sh`

### Links ietf

* [Internet X.509 Public Key Infrastructure Certificate and CRL Profile](https://datatracker.ietf.org/doc/html/rfc5280)
* [S/MIME Example Keys and Certificates](https://datatracker.ietf.org/doc/html/rfc9216)
* [Guide for building an ECC pki](https://datatracker.ietf.org/doc/html/draft-moskowitz-ecdsa-pki-10)
* [Guide for building an EDDSA pki](https://datatracker.ietf.org/doc/html/draft-moskowitz-eddsa-pki-06)
* [S/MIME Version 4.0 Certificate Handling](https://datatracker.ietf.org/doc/html/rfc8550)
* [Guidance on End-to-End E-mail Security](https://datatracker.ietf.org/doc/html/draft-ietf-lamps-e2e-mail-guidance-11)
* [Limited Additional Mechanisms for PKIX and SMIME (lamps)](https://datatracker.ietf.org/wg/lamps/documents/)
* [Opportunistic Security: Some Protection Most of the Time](https://datatracker.ietf.org/doc/html/rfc7435)

### Types of certificates

| cryptosystem | key scheme | script | MUA application support[^1] |
| --- | --- | --- | --- |
| RSA (PKCS#1 v1.5) | **1**)Root (primary key, Certify) **2**)User (subkey, Sign, Encrypt) | `clean_RSA_single-key.sh` | *full* |
| [RSASSA-PSS](https://datatracker.ietf.org/doc/html/rfc8017#section-8) | **1**)Root (primary key, Certify) **2**)User (subkey, Sign, Encrypt) | `clean_RSA-PSS_single-key.sh` | *unknown* |
| [NIST EC](https://datatracker.ietf.org/doc/html/rfc3279#section-2.3.5)[^2] (ECDSA/ECDH) | **1**)Root (primary key, Certify) **2**)User (subkey, Sign, Encrypt) | `clean_NIST_single-key.sh` | *partial* |
| [Edwards-curve](https://datatracker.ietf.org/doc/html/rfc8410#section-5) (EdDSA/EdDH)[^3] | **1**)Root (primary key, Certify) **2**)User (subkey, Sign) **3**)User (subkey, Encrypt) | `clean_EDWARDS_dual-key.sh` | *none* |

[^1]: by 2023.

[^2]: see also: [RFC5480](https://datatracker.ietf.org/doc/html/rfc5480#section-3), [RFC8813](https://datatracker.ietf.org/doc/html/rfc8813)

[^3]: see also: [Security Considerations](https://datatracker.ietf.org/doc/html/rfc8410#section-12), [RFC9295](https://datatracker.ietf.org/doc/html/rfc9295#section-3)

| Certificate Type | 1) ROOT Certificate | 2) Subscriber Certificate |
| --- | --- | --- |
| Digest Algorithm | SHA256, SHA384, SHA512 | SHA256, SHA384, SHA512 |
| RSA Key Size | 3072, 4096 | 2048, 3072, 4096 |
| NIST ECC | P-384, P-521 | P-256, P-384, P-521 |

| Certificate Type | 1) ROOT Certificate | 2) Subscriber Certificate | 3) Subscriber Certificate |
| --- | --- | --- | --- |
| Edwards-curve | ED25519, ED448 | ED25519, ED448 | X25519, X448 |

### How to install certificates

- [iOS Mail App](https://www.dalesandro.net/using-self-signed-s-mime-certificates-in-ios-mail-app/)
- [Outlook](https://www.dalesandro.net/using-self-signed-s-mime-certificates-in-outlook/)
- [Thunderbird](https://www.dalesandro.net/using-self-signed-s-mime-certificates-in-thunderbird/)
- [Manual (German)](https://raw.githubusercontent.com/gunnarhaslinger/SMIME-OpenSSL-CA/master/Manual%20(German)%20-%20SMIME-CA%20Nutzungsanleitung%20und%20technische%20Infos.pdf)
- [Manual (Polish)](http://web.archive.org/web/20220627203414/https://www-arch.polsl.pl/pomoc/certyfikaty_osobiste/Strony/witamy.aspx)

### Script tested on

* OpenSSL 1.1.1l 24 Aug 2021 / GNU bash 5.1.12 / date (GNU coreutils) 9.0 / GNU Awk 5.1.1
* OpenSSL 3.0.7  1 Nov 2022 / GNU bash 5.2 / date (GNU coreutils) 9.1 / GNU Awk 5.1.0

[guiDumpASN-ng binary for Windows](https://web.archive.org/web/20160828215604/http://geminisecurity.com/wp-content/uploads/tools/GDA-ng-setup.exe)

> The majority of these certificates (64%) were created by devices or deployments where certificates are not verified, usually self-signed certificates, where X.509 is used as a data format to transfer for public keys.

https://eprint.iacr.org/2019/130.pdf

### Author

Leszek Zabłocki

leszek.zablocki@interia.com

Copyright: public domain / MIT
