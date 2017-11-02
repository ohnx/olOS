DISKNAME=diskmbr.img

default:run

$(DISKNAME):
	dd if=/dev/zero of=$(DISKNAME) bs=1M count=256
	mkfs.vfat $(DISKNAME)
	printf 'n\np\n1\n\n\nt\nc\nw\n' | fdisk $(DISKNAME)

%.bin: %.asm
	nasm -f bin $< -o $@

.PHONY: stage1
stage1: s1.bin $(DISKNAME)
	dd if=$< of=$(DISKNAME) bs=1 skip=62 seek=62 count=384 iflag=skip_bytes,count_bytes oflag=seek_bytes conv=notrunc,noerror

stage2: s2.bin

.PHONY: bootloader
bootloader: stage1

.PHONY: clean
clean:
	rm -rf s1.bin s2.bin

run: bootloader
	qemu-system-x86_64 $(DISKNAME)

