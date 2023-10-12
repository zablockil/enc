## Accuracy tests

### pre-test details

We will use 3 files for pre-testing. We will create them as follows:

```shell
echo "0123456789ab" > "a.txt"
echo "cdefghijklmn" > "b.txt"
echo "OPQRSTUVWXYZ" > "c.txt"
```

Now we will scan each file separately with the program `hexdump`, which will show their contents (canonical hex+ASCII display):

```shell
$ hexdump -Cv a.txt
00000000  30 31 32 33 34 35 36 37  38 39 61 62 0a           |0123456789ab.|
0000000d

$ hexdump -Cv b.txt
00000000  63 64 65 66 67 68 69 6a  6b 6c 6d 6e 0a           |cdefghijklmn.|
0000000d

$ hexdump -Cv c.txt
00000000  4f 50 51 52 53 54 55 56  57 58 59 5a 0a           |OPQRSTUVWXYZ.|
0000000d
```

`compare_binary_offset.sh` compares 1 to 3 files in the selected offeset (bytes) and displays the results in 3 columns. Let's see how it looks in our pre-test:

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./compare_binary_offset.sh 7 a.txt b.txt c.txt

           offset     7

hex        binary     filename
---        ------     --------
37         0011 0111  a.txt
6a         0110 1010  b.txt
56         0101 0110  c.txt
```

### test details

Now we will create: a one-time key, a test message and perform XOR calculations on these files. Finally, we will compare the bits in these 3 files.

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./make_encryption_key_regular.sh 64 OTP_KEY
1+0 records in
1+0 records out
64 bytes copied, 0.000184729 s, 346 kB/s
bufsize=8192
key=5DF355889BC0AD6956AC08585AB274775588176F54A7300038FC2BFD67DE18C4
iv =F00CBF1FF8B1D53F5C318AEF757199D5
bytes read   :       64
bytes written:       64

DONE.
...
```

```shell
$ dd if=/dev/zero bs=64 count=1 | tr "\000" "\125" > "test_64.bin"
```

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./encrypt_otp_regular.sh OTP_KEY.dat test_64.bin 0

@ @ @
    encryption key filename : OTP_KEY.dat
             input filename : test_64.bin
                        . . .
   encryption key file size : 64 (0 MiB)
            OTP key pointer : 0
            input file size : 64 (0 MiB)
                              [bytes]
              PROCESSING FILE
                        . . .
                        . . .
    cipher output file size : 64 (0 MiB)
       NEXT OTP key pointer : 64
            free space left : 0 (0 MiB)
                              it's time to create a new OTP key!
@ @ @

DONE.
```

Let's now check, one by one, the contents of these files:

```shell
$ hexdump -Cv OTP_KEY.dat
00000000  01 3a 74 46 28 f9 c8 4b  d8 96 54 ad 4c 5c 8a f7  |.:tF(..K..T.L\..|
00000010  3e 95 8a 6a 7d eb 51 7a  b2 d7 7d 6e a8 96 92 52  |>..j}.Qz..}n...R|
00000020  65 5c 14 8b e5 ee df aa  31 dc 9b 18 f7 68 8a 1f  |e\......1....h..|
00000030  83 52 3c a6 1e a5 7a 10  12 a7 fb a7 0d 4c 62 62  |.R<...z......Lbb|
00000040

$ hexdump -Cv test_64.bin
00000000  55 55 55 55 55 55 55 55  55 55 55 55 55 55 55 55  |UUUUUUUUUUUUUUUU|
00000010  55 55 55 55 55 55 55 55  55 55 55 55 55 55 55 55  |UUUUUUUUUUUUUUUU|
00000020  55 55 55 55 55 55 55 55  55 55 55 55 55 55 55 55  |UUUUUUUUUUUUUUUU|
00000030  55 55 55 55 55 55 55 55  55 55 55 55 55 55 55 55  |UUUUUUUUUUUUUUUU|
00000040

$ hexdump -Cv test_64.bin.dat
00000000  54 6f 21 13 7d ac 9d 1e  8d c3 01 f8 19 09 df a2  |To!.}...........|
00000010  6b c0 df 3f 28 be 04 2f  e7 82 28 3b fd c3 c7 07  |k..?(../..(;....|
00000020  30 09 41 de b0 bb 8a ff  64 89 ce 4d a2 3d df 4a  |0.A.....d..M.=.J|
00000030  d6 07 69 f3 4b f0 2f 45  47 f2 ae f2 58 19 37 37  |..i.K./EG...X.77|
00000040
```

Let's now display the specified offset in these 3 files using `compare_binary_offset.sh` script:

```
┌──(kali㉿kali)-[/tmp/kali]
└─$ ./compare_binary_offset.sh 23 OTP_KEY.dat test_64.bin test_64.bin.dat

           offset     23

hex        binary     filename
---        ------     --------
7a         0111 1010  OTP_KEY.dat
55         0101 0101  test_64.bin
2f         0010 1111  test_64.bin.dat
```
