#!/bin/bash
# BIN 01010101, OCT 125, DEC 85, HEX 55

dd if=/dev/zero bs=10 count=1 | tr "\000" "\125" > "test_010.bin"
dd if=/dev/zero bs=20 count=1 | tr "\000" "\125" > "test_020.bin"
dd if=/dev/zero bs=50 count=1 | tr "\000" "\125" > "test_050.bin"
dd if=/dev/zero bs=100 count=1 | tr "\000" "\125" > "test_100.bin"
dd if=/dev/zero bs=200 count=1 | tr "\000" "\125" > "test_200.bin"
dd if=/dev/zero bs=500 count=1 | tr "\000" "\125" > "test_500.bin"
dd if=/dev/zero bs=1048575 count=1 | tr "\000" "\125" > "test_1048575.bin"
dd if=/dev/zero bs=1048576 count=1 | tr "\000" "\125" > "test_1048576.bin"
dd if=/dev/zero bs=1048577 count=1 | tr "\000" "\125" > "test_1048577.bin"
dd if=/dev/zero bs=1048576 count=2 | tr "\000" "\125" > "test_2097152.bin"

# EOF
