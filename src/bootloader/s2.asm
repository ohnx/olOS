; s2.asm - Stage 2 bootloader of olOS
; Should be the first file on a FAT32 partition
; Set up long mode environment for olOS

; we are loaded by stage 1 at 0x010000
; however, for now, just use org 0x0000
[org 0x0000]
; 16-bit real mode
[bits 16]

; assumes video mode already enabled
jmp s2_main

s2_main:
    ; set ds = cs
    push cs
    pop ds

    ; init message
    mov si, s2_hello    
    call s2_print

    ; goodnight.
    cli
    hlt

; output a null-terminated string to screen
; expects string offset location in si
; clobbers ah, al, and si
s2_print:
    ; load character from (ds:si) to al
    lodsb

    ; check if al = null (end of string)
    or al, al
    jz s2_print_done

    ; ah=0xe teletype output
    mov ah, 0xe

    ; interrupt BIOS video services
    int 0x10

    ; loop
    jmp s2_print

s2_print_done:
    ; done
    ret

; -----------------------------------------------
;; Strings
; -----------------------------------------------
s2_rodata:
s2_hello db "s2 init", 10, 13, 0
s2_err db "s2 fatal boot error", 10, 13, 0

; -----------------------------------------------
;; EOF
; -----------------------------------------------
s2_eof:
