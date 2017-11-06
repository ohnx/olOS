DISKNAME=diskmbr.img

default:run

$(DISKNAME):
	dd if=/dev/zero of=$(DISKNAME) bs=1M count=256
	sudo mkfs.msdos -F 32 $(DISKNAME)

%.bin: %.asm
	nasm -f bin $< -o $@

.PHONY: stage1
stage1: s1_vbr.bin $(DISKNAME)
	dd if=$< of=$(DISKNAME) bs=1 count=2 iflag=count_bytes conv=notrunc,noerror
	dd if=$< of=$(DISKNAME) bs=1 skip=90 seek=90 count=422 iflag=skip_bytes,count_bytes oflag=seek_bytes conv=notrunc,noerror

stage2: s2.bin

.PHONY: bootloader
bootloader: stage1

.PHONY: clean
clean:
	rm -rf s1_vbr.bin s2.bin

run: bootloader
	qemu-system-x86_64 -drive format=raw,file=$(DISKNAME)

