; s1_vbr.asm - Stage 1 bootloader of olOS
; Should be placed on the first sector on a partition.
; Loads and jumps to the first file on a FAT32 partition.

; we are loaded by BIOS or by s1_mbr at 0x7C00; set org = 0x7C00
; alternative method: set segment to 0x7C00
[org 0x7C00]
; 16-bit real mode
[bits 16]

start: jmp s1_start
nop

; -----------------------------------------------
;; filesystem table info for fat16, fat32 (this table is not written to disk)
; -----------------------------------------------
; see http://www.dewassoc.com/kbase/hard_drives/boot_sector.htm
; for more info
; sbs = fat16; fbs = fat32
sbs_OEM_Id:
fbs_OEM_Id:                 db "OHNX LOS"
sbs_BytesPerSector:
fbs_BytesPerSector:         dw 512
sbs_SectorsPerCluster:
fbs_SectorsPerCluster:      db 1
sbs_ReservedSectors:
fbs_ReservedSectors:        dw 1
sbs_NumberOfFATs:
fbs_NumberOfFATs:           db 2
sbs_RootEntries:
fbs_RootEntries:            dw 224
sbs_NumberOfSectors:
fbs_NumberOfSectors:        dw 2880
sbs_MediaDescriptor:
fbs_MediaDescriptor:        db 0xF0
sbs_SectorsPerFAT:
fbs_SectorsPerFAT:          dw 9
sbs_SectorsPerHead:
fbs_SectorsPerHead:         dw 18
sbs_HeadsPerCylinder:
fbs_HeadsPerCylinder:       dw 2
sbs_HiddenSectors:
fbs_HiddenSectors:          dd 0
sbs_BigNumberOfSectors:
fbs_BigNumberOfSectors:     dd 0
; this is where FAT16 and FAT32 begin to differ
; BigSectorsPerFAT is a dd = 8 bytes
fbs_BigSectorsPerFAT:
sbs_DriveNumber:            db 0
sbs_Unused:                 db 0
sbs_ExtBootSignature:       db 0
; sbs_SerialNumber is a dd = 8 bytes, but 3 into 8 bytes
sbs_SerialNumber:
times 5 db 0
; fbs_ExtFlags is a dw = 4 bytes, but 5 into 8 bytes
fbs_ExtFlags:
times 3 db 0
; sbs_VolumeLabel is 11 bytes, but 3 into 4 bytes
sbs_VolumeLabel:            db 0
; fbs_FSVersion is a dw = 4 bytes, 1 byte into 10 bytes
fbs_FSVersion:              dw 0
; fbs_RootDirectoryStart is a dd = 8 bytes, but 5 bytes into 10 bytes
fbs_RootDirectoryStart:
times 5 db 0
; sbs_FileSystem is 8 bytes, but 5 into 8 bytes
sbs_FileSystem:
times 3 db 0
; fbs_FSInfoSector is a dw = 4 bytes, 3 bytes into 8 bytes
fbs_FSInfoSector:           dw 1
; fbs_BackupBootSector is a dw = 4 bytes, but 7 bytes into 8 bytes
; luckily, at this point, fat16 is done and we don't care anymore.
fbs_BackupBootSector:       dw 6
; reserved area
times 13 db 0
fbs_DriveNumber:            db 0
fbs_ExtBootSignature:       db 0x29
fbs_VolumeID:               dd 0xDEADBEEF
fbs_VolumeLabel:            db "OHNX LIL OS"
fbs_FileSystemType:         db "FAT32   "

; -----------------------------------------------
;; Code
; -----------------------------------------------
s1_start:
    ; set up memory segments
    ; since we use org=0x7C00 the segment is 0.
    ; i.e. memory accesses are 0x0000:0x7C00+something
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; set up the stack to grow down from 0x7C00
    mov sp, 0x7C00

    ; enable video mode
    call s1_enablevideo

    ; reset disks
    ; error message string and length
    mov si, s1_hello

    ; show message
    call s1_print

    ; halt cpu (should not reach here)
    cli
    hlt

; enable video mode
; clobbers ah and al
s1_enablevideo:
    ; ah=0x0 set video mode
    mov ah, 0x0
    ; Text Mode 80x25 chars, 16 colors
    mov al, 0x3

    ; interrupt BIOS video services
    int 0x10
    ret

; output a null-terminated string to screen
; expects string offset location in si
; clobbers ah, al, and si
s1_print:
    ; load character from (ds:si) to al
    lodsb

    ; check if al = null (end of string)
    or al, al
    jz s1_print_done

    ; ah=0xe teletype output
    mov ah, 0xe

    ; interrupt BIOS video services
    int 0x10

    ; loop
    jmp s1_print

s1_print_done:
    ; done
    ret

; function to reset disks.
; assumes dl is set to the disk the os was loaded from
; clobbers ah
s1_resetdisks:
    ; ah = 0 reset disk location
    mov ah, 0x0

    ; interrupt BIOS disk services
    int 0x13

    ; failed to reset disk
    jmp s1_resetdisks

    ; no error
    ret

; Handle an error :(
s1_bootfail:
    ; store error code in stack
    push ax

    ; error message string and length
    mov si, s1_err

    ; show message
    call s1_print

    ; restore ax (for debugging purposes)
    pop ax

    ; halt cpu. good night.
    cli
    hlt

; -----------------------------------------------
;; Strings
; -----------------------------------------------
s1_rodata:
s1_hello db "s1 init!", 10, 13, 0
s1_err db "s1 fatal boot error", 10, 13, 0

; -----------------------------------------------
;; End of code + data, pad
; -----------------------------------------------
s1_pad:
; ensure file is not too big
%if ($ - $$) > 510
    %fatal "s1 vbr bootloader too big!"
%endif

; fill with zeroes
times 510 - ($ - $$) db 0

; magic bytes
dw 0xAA55

; -----------------------------------------------
;; EOF
; -----------------------------------------------
