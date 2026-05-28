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
    mov si, info6
    mov bl, 0x0F
    call puts_color
    int 0x12
    call print_num
    mov dx, kb_str
    mov ah, SYS_PUTS
    int SYS_INT
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT

    mov si, art7
    mov bl, 0x0E
    call puts_color
    mov si, info7
    mov bl, 0x0F
    call puts_color
    int 0x11
    test ax, 1
    jz .nofloppy
    mov cl, 6
    shr ax, cl
    and ax, 3
    inc ax
    call print_num
    jmp .done_floppy
.nofloppy:
    mov ax, 0
    call print_num
.done_floppy:
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

print_num:
    cmp ax, 0
    jne .convert
    mov byte [echo_ch], '0'
    mov dx, echo_ch
    mov ah, SYS_PUTS
    int SYS_INT
    ret
.convert:
    mov bx, 10
    xor cx, cx
.div_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div_loop
.print_loop:
    pop ax
    add al, '0'
    mov [echo_ch], al
    mov dx, echo_ch
    mov ah, SYS_PUTS
    int SYS_INT
    loop .print_loop
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
info6 db 'RAM: ', 0
info7 db 'Floppy drives: ', 0
kb_str db ' KB', 0

echo_ch db 0, 0
crlf db 0x0D, 0x0A, 0
