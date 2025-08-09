## One-time pad (binary XOR) bash script

Uses OpenSSL and generally available Linux tools (GNU coreutils, awk)

<img src="logo.jpg?raw=true" alt="logo" width="300" height="300"/>

#### Plaintext ⊕ KeyStream ⇒ Ciphertext = Ciphertext ⊕ KeyStream ⇒ Plaintext

### Preliminary reading to understand the concept (1917 technology):

* [The Vernam Cipher](https://www.cryptomuseum.com/crypto/vernam.htm)
* [The unbreakable code](https://www.cryptomuseum.com/crypto/otp/index.htm)
* [One time pads](https://en.wikibooks.org/wiki/Cryptography/One_time_pads)
* [The complete guide to secure communications](https://www.ciphermachinesandcryptology.com/papers/one_time_pad.pdf)
* [Spies and Numbers](https://www.ciphermachinesandcryptology.com/papers/spies_and_numbers.pdf)
* [Is One-time Pad History?](https://www.ciphermachinesandcryptology.com/papers/is_one_time_pad_history.pdf)
* [One-time Pad Crypto Shield - Luka Matić](https://web.archive.org/web/20230830124255/https://www.docdroid.net/file/view/iU5GwIS/document-pdf.pdf?e=1693402937&s=2d0e45df8e9d2dbd21c78006a5220eef)
* [The Americans TV Series](https://www.imdb.com/find/?q=The%20Americans%202013)

> "There is no such thing as a secure personal computer."

### XOR (Exclusive OR) = ⊕

```
1 ⊕ 1 = 0
1 ⊕ 0 = 1
0 ⊕ 1 = 1
0 ⊕ 0 = 0
```

again:

```
+-----------+-----------+----------+
|  input 1  |  input 2  |  output  |
+-----------+-----------+----------+
|     0     |     0     |     0    |
|     0     |     1     |     1    |
|     1     |     0     |     1    |
|     1     |     1     |     0    |
+-----------+-----------+----------+
```

### purpose of the script

* cryptography students
* hobbyists
* intelligence/counterintelligence services
* spies
* traders of Persian second-hand carpets

### 2 types of script

1. `regular_otp/encrypt_otp_regular.sh` vanilla OTP technique.
2. `aead_otp/encrypt_otp_gcm.sh` additionally packs the encrypted file into an AEAD, AES-GCM container (uses asymmetric key encryption). The true power and glory of cryptography.

| script type | counter management | reliability | quantum computer resistance |
| --- | --- | --- | --- |
| `encrypt_otp_regular.sh` | manual | absolute | 100% |
| `encrypt_otp_gcm.sh` | automatic | absolute | 100% |

### Windows10 msys2

<img src="msys2_a_jakze.png?raw=true" alt="msys2" width="300" height="225"/>

### Author

Leszek Zabłocki

deputy head of technicians at the Ministry of Peace

leszek.zablocki@interia.com

Copyright: public domain / MIT

The encryption methods and training materials presented here are also used by the civil rights departments of the Ministry of Love. We do everything for the comfort and security of our citizens.

We broadcast messages from [this facility](https://sluzbyiobywatel.pl/odkrywam-luke-bezpieczenstwa-w-obiekcie-sww) (yes, an unauthorized person got there recently).

<sub><sup>Cyt cyt</sup></sub>
