; s1_mbr.asm - Stage 1 bootloader of olOS (MBR)

; we are loaded by BIOS at 0x7C00, but we 
; copy ourselves to 0x7A00.
[org 0x7A00]
; 16-bit real mode
[bits 16]

; -----------------------------------------------
;; Info
; -----------------------------------------------
; Should be placed on boot sector of a MBR disk.
; Finds the first active (0x80) parition on boot
; disk, loads the first sector to 0x7C00, and
; jumps to it.
;
; This file is not particularly optimized since
; it doesn't have to do much in 512 bytes.

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

    ; keep a copy of dl in 0x500
    mov [ds:0x500], dl

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

    ; keep track of the parition we're reading
    ; I lied. We actually use segments here!
    xor ax, ax

s1_checkpart:
    ; extra segment gs
    mov gs, ax

    ; store the value of flag in dh
    mov dh, [gs:p1_bi]
    ; check if the active indicator flag is set
    cmp dh, 0x80

    ; save ax since later operations may clobber
    push ax

    ; not set, skip to next partition
    jne s1_checkpart_next

    ; it is set! attempt boot from here! :D
    mov si, s1_tryboot
    call s1_print
    jmp s1_bootpart

    ; s1_bootpart may realize there is no boot
    ; signature on a parition, and jump back to
    ; s1_checkpart_next

s1_checkpart_next:
    pop ax
    ; increment ax and make sure there are still
    ; paritions to read
    inc ax
    cmp ax, 0x4

    ; not the last partition yet
    jne s1_checkpart

    ; last parition, fall through to error :(

s1_disp_nopart:
    ; display error message
    mov si, s1_nopart
    call s1_print

    ; go to error
    jmp s1_goodbye

s1_diskread_err:
    ; display error message
    mov si, sl_readd
    call s1_print

    ; go to error
    jmp s1_goodbye

; boot a partition
; assumes ds and es are set to correct offset
; to get data from partition table
s1_bootpart:
    ; reset disk
    call s1_resetdisks

    ; check disk extension support
    call s1_cde
    jc s1_diskread_err

    ; read 512 bytes (1 sector) from disk
    ; we will form the packet at address 0x600
    ; packet size = 16 bytes
    mov byte [ds:0x600], 0x10
    ; reserved
    mov byte [ds:0x601], 0x00
    ; number of blocks to transfer
    mov word [ds:0x602], 0x01
    ; address of transfer buffer (offset)
    mov word [ds:0x604], 0x7C00 
    ; address of transfer buffer (segment)
    mov word [ds:0x606], 0x00
    ; lower 32-bits of 48-bit starting LBA
    mov ax, [gs:p1_sseclbal]
    mov word [ds:0x608], ax
    mov ax, [gs:p1_sseclbah]
    mov word [ds:0x610], ax
    ; high 32-bits of 48-bit starting LBA
    mov dword [ds:0x60c], 0x00

    ; set ds:si to disk address packet in memory
    ; ds is already 0x0
    ; we formed the packet at 0x600
    mov si, 0x600
    ; set ah = 0x42 extended read
    mov ah, 0x42
    ; set drive number
    mov dl, [ds:0x500]

    ; read the bytes
    int 0x13

    ; check if it read successfully
    jc s1_diskread_err

    ; check if there is a boot disk signature
    ; 0xAA55 = 0x55 0xAA
    mov ax, [ds:0x7dfe]
    cmp ax, 0xAA55
    jne s1_bootpart_mistake

    ; all good! clean up a few things to be nice
    xor ax, ax
    mov gs, ax

    ; restore dl
    mov dl, [ds:0x500]

    ; ... and jump!
    jmp 0:0x7c00

s1_bootpart_mistake:
    ; boot partition marked as active but no
    ; signature was found
    ; print message
    mov si, s1_badpart
    call s1_print

    ; jump to next partition
    jmp s1_checkpart_next

; if anything falls through to here, halt.
s1_goodbye:
    ; display error message
    mov si, s1_err

    ; show message
    call s1_print

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
s1_tryboot db "Attempting boot from partition..."
db 10, 13, 0
s1_badpart db "No magic flag on partition."
db 10, 13, 0
s1_nopart db "No bootable partition found!"
db 10, 13, 0
sl_readd db "Disk read error!", 10, 13, 0
s1_err db "Fatal boot error!", 10, 13, 0

; -----------------------------------------------
;; End of code + data; pad now
; -----------------------------------------------
s1_pad:
; ensure file is not too big
%if ($ - $$) > 446
    %fatal "s1 mbr bootloader too big!"
%endif

; fill with zeroes
times 446 - ($ - $$) db 0

; -----------------------------------------------
;; Partition table (not written to disk)
; -----------------------------------------------

; partition 1
; boot indicator
p1_bi:                      db 0
; start in head/sector/cylinder
p1_shead:                   db 0
p1_ssec:                    db 0
p1_scyl:                    db 0
; system id (parition type)
p1_sysid:                   db 0
; end in head/sector/cylinder
p1_ehead:                   db 0
p1_esec:                    db 0
p1_ecyl:                    db 0
; start in sectors (logical block addressing)
p1_sseclba:
p1_sseclbal:                dw 0
p1_sseclbah:                dw 0
; total # of sectors (logical block addressing)
p1_tseclba:                 dd 0

; paritions 2, 3, and 4 will be addressed
; using an offset
dd 0, 0, 0, 0
dd 0, 0, 0, 0
dd 0, 0, 0, 0

; magic bytes
dw 0xAA55

; -----------------------------------------------
;; EOF
; -----------------------------------------------
