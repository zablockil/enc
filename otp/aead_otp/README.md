### How to use this script

1. download a liveCD Linux distribution.
2. copy script to the ramdisk `/tmp` directory
3. `cd /tmp/otp/`
4. create a one-time key: `./make_encryption_keys_gcm.sh 1048576 OTP_KEY PERSON_A PERSON_B`
5. encrypt the file: `./encrypt_otp_gcm.sh secret_message.doc RECIPIENT_2.crt`

· Encrypted file will be placed in the working directory (`$pwd/ENCRYPTED/...`) and will be named rand`.der`.
· Decrypted file will be placed in the working directory (`$pwd/DECRYPTED/...`) and will be named as they were named by the sender.
· The counter and log will be saved where the one-time key file is located.

### Details of usage

#### Step no1 - creating a one-time key

We create a key with a size of 1 MiB and the name "OTP_KEY" and 2 asymmetric keys intended for individuals: `MACIEK` and `BARTEK`.

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./make_encryption_keys_gcm.sh 1048576 OTP_KEY BARTEK MACIEK
bufsize=8192
key=629DAFB27CC951B9ADC36A14E7F58C58FE54D9700F16A104A57518C3B06D8820
iv =8B2FF794518B0F4983762926607BF249
1+0 records in
1+0 records out
1048576 bytes (1.0 MB, 1.0 MiB) copied, 0.11531 s, 9.1 MB/s
bytes read   :  1048576
bytes written:  1048576

# # #
   encryption key file size : 1048576 (1 MiB)
                              [bytes]
# # #

DONE.
2023-10-07 15:34:07+00:00
```

These files are for a great personality with name `BARTEK`:
```
BARTEK.pem   (private key)
MACIEK.crt   (public key)
OTP_KEY.dat  (one-time key)
```

On the other hand, these files are intended for an equally noble personality named `MACIEK`:
```
MACIEK.pem   (private key)
BARTEK.crt   (public key)
OTP_KEY.dat  (one-time key)
```

They have their own computers and their own directories and intend to exchange secret messages. We don't go into whether these are messages with political content, personal content (e.g. `BARTEK` complains about his wife Grażyna and envies `MACIEK` that he has such a wonderful wife Bożena), or any other content. We deal with technical stuff.

#### Step no2 - encrypt the file (`BARTEK` → `MACIEK`)

`BARTEK` encrypts a file named "secret_message.doc" using the key "OTP_KEY.dat" and automatic key position to `MACIEK`.

```
┌──(kali㉿kali)-[/tmp/BARTEK]
└─$ ./encrypt_otp_gcm.sh OTP_KEY.dat secret_message.doc MACIEK.crt

i i i
      I will save the counter
      and logs in a directory
          with a one-time key
                        . . .
                OTP key dir : /tmp/BARTEK
                        . . .
           counter filename : OTP_KEY.dat.counter
               log filename : OTP_KEY.dat.log.csv
i i i

@ @ @
    encryption key filename : OTP_KEY.dat
             input filename : secret_message.doc
                        . . .
   encryption key file size : 1048576 (1 MiB)
            OTP key pointer : 0
            input file size : 200 (0 MiB)
                              [bytes]
              PROCESSING FILE
                        . . .
                        . . .
    cipher output file size : 200 (0 MiB)
       NEXT OTP key pointer : 200
            free space left : 1048376 (0 MiB)
                              it's time to create a new OTP key!
                        . . .
     counter and log UPDATED!
@ @ @

$ $ $
      ENCRYPTING FILE AES-GCM
      you use cert with SKI : 824DDE8FAC615B78...
                        . . .
                        . . .
             AEAD file size : 3443 (0 MiB)
                              [bytes]
           output directory : /tmp/BARTEK/ENCRYPTED/20231007_153753_317319649
            output filename : 3tC0Lx8664.der
                        . . .
                          OK!
$ $ $

DONE.
2023-10-07 15:37:53+00:00
```

Encrypted file is located in `pwd/ENCRYPTED/...` with the name: "3tC0Lx8664.der". Now `BARTEK` is passing this message to `MACIEK`. He can use the Internet, but is considering transmission via Morse signal (over old telegraph wires).

#### Step no3 - decrypt the file (`MACIEK`)

`MACIEK` received the message from `BARTEK` and saved it on his computer. He decrypt a file named "3tC0Lx8664.der" using the key "OTP_KEY.dat" and automatic key position.

```
┌──(kali㉿kali)-[/tmp/MACIEK]
└─$ ./decrypt_otp_gcm.sh OTP_KEY.dat 3tC0Lx8664.der MACIEK.pem

i i i
      I will save the counter
      and logs in a directory
          with a one-time key
                        . . .
                OTP key dir : /tmp/MACIEK
                        . . .
           counter filename : OTP_KEY.dat.counter
               log filename : OTP_KEY.dat.log.csv
i i i

$ $ $
      DECRYPTING FILE AES-GCM
                        . . .
             message intended
         for a key with SKI : 824dde8fac615b78...
                        . . .
             input filename : 3tC0Lx8664.der
            input file size : 3443 (0 MiB)
                              [bytes]
                        . . .
                        . . .
            secret filename : secret_message.doc
  message encrypted that day: 2023-10-07 15:37:53
                        . . .
          SHAKE256 checksum : ok
                        . . .
              so far so good!
$ $ $

@ @ @
    encryption key filename : OTP_KEY.dat
             input filename : secret_message.doc.dat
                        . . .
   encryption key file size : 1048576
  key pointer (from sender) : 0
           secret file size : 200 (0 MiB)
                              [bytes]
              DECRYPTING FILE
                        . . .
                        . . .
              counter updated
                        . . .
           output directory : /tmp/MACIEK/DECRYPTED/20231007_154053_077649315
            output filename : secret_message.doc
                        . . .
                       enjoy!
@ @ @

DONE.
2023-10-07 15:40:53+00:00
```

Decrypted file is located in `pwd/DECRYPTED/...` with the name: "secret_message.doc".

`MACIEK` was very moved after reading the message. He decided to respond to the encrypted message.

#### Step no4 - encrypt the file (`MACIEK` → `BARTEK`)

`MACIEK` encrypts a file named "secret_message.delux" using the key "OTP_KEY.dat" and automatic key position to `BARTEK`.

```
┌──(kali㉿kali)-[/tmp/MACIEK]
└─$ ./encrypt_otp_gcm.sh OTP_KEY.dat secret_message.delux BARTEK.crt

i i i
      I will save the counter
      and logs in a directory
          with a one-time key
                        . . .
                OTP key dir : /tmp/MACIEK
                        . . .
           counter filename : OTP_KEY.dat.counter
               log filename : OTP_KEY.dat.log.csv
i i i

@ @ @
    encryption key filename : OTP_KEY.dat
             input filename : secret_message.delux
                        . . .
   encryption key file size : 1048576 (1 MiB)
            OTP key pointer : 200
            input file size : 200 (0 MiB)
                              [bytes]
              PROCESSING FILE
                        . . .
                        . . .
    cipher output file size : 200 (0 MiB)
       NEXT OTP key pointer : 400
            free space left : 1048176 (0 MiB)
                              it's time to create a new OTP key!
                        . . .
     counter and log UPDATED!
@ @ @

$ $ $
      ENCRYPTING FILE AES-GCM
      you use cert with SKI : BB2C419078DA5FDB...
                        . . .
                        . . .
             AEAD file size : 3443 (0 MiB)
                              [bytes]
           output directory : /tmp/MACIEK/ENCRYPTED/20231007_154833_413345741
            output filename : IS3lTzlTmt.der
                        . . .
                          OK!
$ $ $

DONE.
2023-10-07 15:48:33+00:00
```

Encrypted file is located in `pwd/ENCRYPTED/...` with the name: "IS3lTzlTmt.der". Now `MACIEK` is passing this message to `BARTEK`. He can use the Internet, but his wife offered to transcribe it to paper (base64) and send it by traditional mail to `BARTEK` (what a wonderful wife).

#### Step no...

### counter & log

For example, `OTP_KEY.dat.counter` contains the position of the counter (or history). Based on this file, the position of the otp key for ENCRYPTION is determined.

Let's check what the `OTP_KEY.dat.log.csv` file contains based on the last example in the `MACIEK` folder:

```
┌──(kali㉿kali)-[/tmp/MACIEK]
└─$ cat OTP_KEY.dat.log.csv
Decrypt;OTP_KEY.dat.counter;0;3tC0Lx8664.der;200;next counter:;200;824dde8fac615b78;20231007_154053_077649315;2023-10-07 15:37:53;secret_message.doc;
Encrypt;OTP_KEY.dat.counter;200;secret_message.delux;200;next counter:;400;BB2C419078DA5FDB;20231007_154833_413345741;2023-10-07 15:48:33;IS3lTzlTmt.der;
```

### privacy concerns

IF the NIST EC asymmetric key is compromised, a third party can find out:
* about the filename
* about the date of encryption of messages
* can forge a counter and complicate decryption

However, it cannot decrypt a secret encrypted using OTP.

### security considerations

* Entrust secrets to people you can rely on and who understand what you write to them (so that you do not have to repeat the transmission).
* Have as few secrets as possible (this especially applies to your private life).
* If the situation around you has forced you to plot, keep your head on a swivel.

For security personnel: no stipulation.

### Script tested on

* OpenSSL 3.0.7  1 Nov 2022 / GNU bash 5.2 / date (GNU coreutils) 9.1 / GNU Awk 5.1.0
