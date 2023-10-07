### How to use this script

1. download a liveCD Linux distribution.
2. copy script to the ramdisk `/tmp` directory
3. `cd /tmp/otp/`
4. create a one-time key: `./make_encryption_key_regular.sh 1048576 OTP_KEY`
5. encrypt the file: `./encrypt_otp_regular.sh OTP_KEY.dat secret_message.doc 0`

· Encrypted file will be placed in the working directory (`$pwd`) and will be named filename`.der`.

· Decrypted file will be placed in the working directory (`$pwd`) and will be named filename`.decrypted`.

### Details of usage

#### Step no1 - creating a one-time key

We create a key with a size of 1 MiB and the name "OTP_KEY".

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./make_encryption_key_regular.sh 1048576 OTP_KEY

bufsize=8192
key=7294FE9BEC3C02D5C84B8E83788479A143FBC029B2288E4ACAF57057D5CB9E5B
iv =59DAE604EFF21E7F6A01C4E91A3E9C75
1+0 records in
1+0 records out
1048576 bytes (1.0 MB, 1.0 MiB) copied, 0.10655 s, 9.8 MB/s
bytes read   :  1048576
bytes written:  1048576

DONE.
2023-10-07 15:23:00+00:00
```

#### Step no2 - encrypt the file

We encrypt a file named "secret_message.doc" using the key "OTP_KEY.dat" and the position "0" (beginning of key file).

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./encrypt_otp_regular.sh OTP_KEY.dat secret_message.doc 0

@ @ @
    encryption key filename : OTP_KEY.dat
             input filename : secret_message.doc
                        . . .
   encryption key file size : 1048576 (1 MiB)
            OTP key pointer : 0
            input file size : 500 (0 MiB)
                              [bytes]
              PROCESSING FILE
                        . . .
                        . . .
    cipher output file size : 500 (0 MiB)
       NEXT OTP key pointer : 500
            free space left : 1048076 (0 MiB)
                              it's time to create a new OTP key!
@ @ @

DONE.
2023-10-07 15:26:22+00:00
```

Encrypted file is located in `pwd` with the name: "secret_message.doc.dat".

#### Step no3 - decrypt the file

We decrypt a file named "secret_message.doc.dat" using the key "OTP_KEY.dat" and the position "0".

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./decrypt_otp_regular.sh OTP_KEY.dat secret_message.doc.dat 0

@ @ @
    encryption key filename : OTP_KEY.dat
             input filename : secret_message.doc.dat
                        . . .
   encryption key file size : 1048576 (1 MiB)
            OTP key pointer : 0
            input file size : 500 (0 MiB)
                              [bytes]
              DECRYPTING FILE
                        . . .
                        . . .
           output file size : 500 (0 MiB)
@ @ @

DONE.
2023-10-07 15:29:11+00:00
```

Decrypted file is located in `pwd` with the name: "secret_message.doc.dat.decrypted".

### privacy concerns

* n/a

### security considerations

The script will not allow XOR of a file above the file size of "OTP_KEY.dat". This is a very important function responsible for otp security. Program: `paste <(od -An ...` will perform XOR on the entire file only if there is enough space in "OTP_KEY.dat"; if not, the file will be truncated. There is no way to change this behavior, such as using otp again from the beginning (repeating / looping the key). Example:

```
onetimepad file size : 1048576
file size : 100
OTP key pointer (counter) : 1048526
file after XOR: 50 [50 bytes missing]
```

### Script tested on

* OpenSSL 1.1.1l 24 Aug 2021 / GNU bash 5.1.12 / date (GNU coreutils) 9.0 / GNU Awk 5.1.1
