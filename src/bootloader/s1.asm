; s1.asm - Stage 1 bootloader of olOS
; Should be placed on the first 512b of a MBR disk.
; Loads and jumps to the first file on a FAT32 disk.

; we are loaded by BIOS at 0x7C00
[org 0x7C00]
; 16-bit real mode
[bits 16]

start: jmp s1_start

; filesystem table info
bpbBytesPerSector:          DW 512
bpbSectorsPerCluster:       DB 1
bpbReservedSectors:         DW 1
bpbNumberOfFATs:            DB 2
bpbRootEntries:             DW 224
bpbTotalSectors:            DW 2880
bpbMedia:                   DB 0xF0
bpbSectorsPerFAT:           DW 9
bpbSectorsPerTrack:         DW 18
bpbHeadsPerCylinder:        DW 2
bpbHiddenSectors:           DD 0
bpbTotalSectorsBig:         DD 0
bsDriveNumber:              DB 0
bsUnused:                   DB 0
bsExtBootSignature:         DB 0x29
bsSerialNumber:             DD 0xa0a1a2a3
bsVolumeLabel:              DB "OHNX LIL OS"
bsFileSystem:               DB "FAT16   "

s1_start:
    ; set up memory segments
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
;; EOF
; -----------------------------------------------
s1_eof:
; ensure file is not too big
%if ($ - $$) > 446
    %fatal "s1 bootloader too big!"
%endif

; fill with zeroes
times 510 - ($ - $$) db 0

; the partition table goes here
dw 0xAA55
