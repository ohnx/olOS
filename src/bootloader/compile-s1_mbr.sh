#!/bin/bash
nasm -f bin s1_mbr.asm -o s1_mbr.bin

dd if=s1_mbr.bin of=disk_mbr.img bs=1 count=446 iflag=count_bytes conv=notrunc,noerror
dd if=s1_mbr.bin of=disk_mbr.img bs=1 skip=510 seek=510 count=2 iflag=skip_bytes,count_bytes oflag=seek_bytes conv=notrunc,noerror

