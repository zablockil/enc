## Performance tests

The [script causes a heavy load](https://unix.stackexchange.com/questions/398481/xor-a-file-against-a-key/398556#398556) on the CPU (power consumption).

```shell
paste <(od -An -vtu1 -w1 -j 0 FILE) <(od -An -vtu1 -w1 -j COUNTER OTP) | LC_ALL=C awk 'NF!=2{exit}; {printf "%c", xor($1, $2)}' > OUT
```

It would be possible to replace this function with another one or use another external program if it had the option to offset the counter. For testing, 2 programs without this option were compared:

* [Murilo's simple-encryption](https://github.com/trusted-ws/simple-encryption)
* [Satō Katsura oh well C code](https://unix.stackexchange.com/questions/398481/xor-a-file-against-a-key/398497#398497)

If you know any OTP encryption program (easily compilable) with key offset selection function, please write, I will be happy to publish it here.

### test details

There will be 2 files to test: one created with the script `make_encryption_key_regular.sh`:

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./make_encryption_key_regular.sh 734003200 OTP_KEY_700MiB
bufsize=8192
key=A35E39B0453092DE57F8FAE297E3AA206039F0AF0E3DD3FA3084ED0701A705AA
iv =653DCC0FE1ABF8BD82554F4672DED7E3
1+0 records in
1+0 records out
734003200 bytes (734 MB, 700 MiB) copied, 4.90763 s, 150 MB/s
bytes read   : 734003200
bytes written: 734003200

DONE.
...
```

the other with the following command:

```shell
dd if=/dev/zero bs=734003200 count=1 | tr "\000" "\125" > "test_700MiB.bin"
```

We chose a size of 700 MiB. For testing, we will use the `time` program, which is used to measure the execution time of programs. We will conduct the tests in the RAM (`/tmp`).

#### we test our script

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ time ./encrypt_otp_regular.sh OTP_KEY_700MiB.dat test_700MiB.bin 0

@ @ @
    encryption key filename : OTP_KEY_700MiB.dat
             input filename : test_700MiB.bin
                        . . .
   encryption key file size : 734003200 (700 MiB)
            OTP key pointer : 0
            input file size : 734003200 (700 MiB)
                              [bytes]
              PROCESSING FILE
                        . . .
                        . . .
    cipher output file size : 734003200 (700 MiB)
       NEXT OTP key pointer : 734003200
            free space left : 0 (0 MiB)
                              it's time to create a new OTP key!
@ @ @

DONE.
...

real    447.07s
user    404.66s
sys     9.78s
cpu     92%
```

7.45 minutes

#### we test `simple-encryption`

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ time ./main test_700MiB.bin OTP_KEY_700MiB.dat encrypted

real    40.21s
user    39.51s
sys     0.69s
cpu     99%
```

#### we test `oh well C code`

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ time ./xor OTP_KEY_700MiB.dat <test_700MiB.bin >encrypted

real    2.82s
user    2.17s
sys     0.64s
cpu     99%
```
