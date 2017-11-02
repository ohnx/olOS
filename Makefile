QEMU=qemu-system-x86_64

SRCS=nothing
SRCC=nothing

bin/diskmbr.img:
	@mkdir -p bin/
	dd if=/dev/zero of=bin/diskmbr.img bs=1M count=256


runmbr: bin/diskmbr.img
	$(QEMU) -drive format=raw,file=bin/diskmbr.img

run: runmbr

