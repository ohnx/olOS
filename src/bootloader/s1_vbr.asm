; s1_vbr.asm - Stage 1 bootloader of olOS (VBR)

; we are loaded by BIOS at 0x7C00, but we 
; copy ourselves to 0x7A00.
[org 0x7A00]
; 16-bit real mode
[bits 16]

start: jmp s1_startfake
nop

; -----------------------------------------------
;; Info
; -----------------------------------------------
; Should be placed on the first sector of a
; FAT32 partition. When booted from, it will load
; and jump to a specifically named file on the
; partition.

; -----------------------------------------------
;; filesystem table info for fat16, fat32 (this table is not written to disk)
; -----------------------------------------------
; see http://www.dewassoc.com/kbase/hard_drives/boot_sector.htm
; for more info
; sbs = fat16; fbs = fat32
fbs_OEM_Id:                 db "OHNX LOS"
fbs_BytesPerSector:         dw 512
fbs_SectorsPerCluster:      db 1
fbs_ReservedSectors:        dw 1
fbs_NumberOfFATs:           db 2
fbs_RootEntries:            dw 224
fbs_NumberOfSectors:        dw 2880
fbs_MediaDescriptor:        db 0xF0
fbs_SectorsPerFAT:          dw 9
fbs_SectorsPerHead:         dw 18
fbs_HeadsPerCylinder:       dw 2
fbs_HiddenSectors:          dd 0
fbs_BigNumberOfSectors:     dd 0
fbs_BigSectorsPerFAT:       dd 0
fbs_ExtFlags:               dw 0
fbs_FSVersion:              dw 0
fbs_RootDirectoryStart:     dd 0
fbs_FSInfoSector:           dw 1
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
s1_startfake:
    ; clear interrupts
    cli
    ; segments can be difficult to understand and
    ; with our use case they are unnecessary. so,
    ; set them to 0 and don't worry about a thing
    xor ax, ax
    ; stack segment
    mov ss, ax
    ; stack pointer
    mov sp, 0x7A00
    ; data segment
    mov ds, ax
    ; extra segment
    mov es, ax
    ; extra segment #2 (general-purpose)
    mov fs, ax

    ; keep a copy of dl in 0x500
    mov [fs:0x500], dl

; copy ourselves from 0x7C00 to 0x7A00 so that we
; can load other sectors to 0x7C00
s1_memcpy:
    ; source is si = 0x7C00
    mov si, 0x7C00
    ; destination is di = 0x7A00
    mov di, 0x7A00
    ; es and ds are already set to 0
    ; we are moving 512 bytes
    mov cx, 512
    ; we are moving upwards so direction flag = 0
    cld
    ; copy the bytes!
    rep movsb
    ; now, we can jump to the real start!
    jmp 0:s1_start


; real start!
s1_start:
    ; re-enable interrupts
    sti

    ; enable video mode
    call s1_enablevideo

    ; error message string and length
    mov si, s1_hello

    ; show message
    call s1_print

    ; halt cpu (should not reach here)
    cli
    hlt

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
;; Utility functions common across MBR and VBR
; -----------------------------------------------
; enable video mode
s1_enablevideo:
    ; store value of a
    push ax
    ; ah=0x0 set video mode
    mov ah, 0x0
    ; Text Mode 80x25 chars, 16 colors
    mov al, 0x3

    ; interrupt BIOS video services
    int 0x10

    ; restore value of a
    pop ax
    ret

; output a null-terminated string to screen
; expects string offset location in si
; clobbers ah, al, and si
s1_print:
    ; store values
    push ax
    push si
s1_print_loop:
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
    jmp s1_print_loop

s1_print_done:
    ; done, restore values and return
    pop si
    pop ax
    ret

; function to reset disks.
; assumes dl is set to disk to reset
s1_resetdisks:
    push ax
s1_resetdisks_loop:
    ; ah = 0 reset disk location
    mov ah, 0x0

    ; interrupt BIOS disk services
    int 0x13

    ; failed to reset disk
    jc s1_resetdisks_loop

    ; no error
    pop ax
    ret

; check if disk supports extended reads
s1_cde:
    push ax
    push bx
    push dx

    ; ah = 0x41 Extensions
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, 0x80

    ; check results
    int 0x13

    ; let CF be set if error occurred
    pop dx
    pop bx
    pop ax
    ret

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
