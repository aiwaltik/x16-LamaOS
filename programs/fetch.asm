[bits 16]
[org 0x0000]

SYS_INT  equ 0x60
SYS_PUTS equ 0x01
SYS_EXIT equ 0x12

start:
    push cs
    pop ds

    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov si, art1
    mov bl, 0x0E
    call puts_color
    mov si, info1
    mov bl, 0x0B
    call puts_color
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov si, art2
    mov bl, 0x0E
    call puts_color
    mov si, info2
    mov bl, 0x0F
    call puts_color
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov si, art3
    mov bl, 0x0E
    call puts_color
    mov si, info3
    mov bl, 0x0F
    call puts_color
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov si, art4
    mov bl, 0x0E
    call puts_color
    mov si, info4
    mov bl, 0x0F
    call puts_color
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov si, art5
    mov bl, 0x0E
    call puts_color
    mov si, info5
    mov bl, 0x0F
    call puts_color
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov si, art6
    mov bl, 0x0E
    call puts_color
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov si, art7
    mov bl, 0x0E
    call puts_color
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    retf

puts_color:
    mov ah, 0x03
    mov bh, 0
    int 0x10
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x09
    mov cx, 1
    int 0x10
    inc dl
    cmp dl, 80
    jl .set_cur
    mov dl, 0
    inc dh
.set_cur:
    mov ah, 0x02
    int 0x10
    jmp .loop
.done:
    ret

art1 db '       /)  /)     ', 0
art2 db '      ( o  o )    ', 0
art3 db '       \ -- /     ', 0
art4 db '      __\__/__    ', 0
art5 db '     /        \   ', 0
art6 db '    |          |  ', 0
art7 db '    |          |  ', 0

info1 db 'OS: LamaOS v1.0', 0
info2 db 'Kernel: 16-bit real mode', 0
info3 db 'Shell: LamaShell', 0
info4 db 'Arch: x86', 0
info5 db 'CPU: Generic x86', 0

crlf db 0x0D, 0x0A, 0
