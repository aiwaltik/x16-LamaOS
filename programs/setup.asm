[bits 16]
[org 0x0000]

%include "lib/lama.inc"

start:
    push cs
    pop ds
    push cs
    pop es

    mov ax, 0x0600
    mov bh, 0x3F
    xor cx, cx
    mov dx, 0x184F
    int 0x10

    mov ah, 0x02
    mov bh, 0
    xor dx, dx
    int 0x10

    mov dx, ui_text
    PUTS dx

    mov ah, 0x02
    mov bh, 0
    mov dh, 15
    mov dl, 26
    int 0x10

.input_loop:
    INPUT username_buf, 21
    test cx, cx
    jz .input_loop

    mov ah, 0x02
    mov bh, 0
    mov dh, 18
    mov dl, 26
    int 0x10
    PRINT "Saving configuration..."

    mov dx, file_user_cfg
    push cs
    pop es
    mov bx, sector_buf
    
    mov si, username_buf
    mov di, sector_buf
    xor cx, cx
.copy:
    lodsb
    stosb
    inc cx
    test al, al
    jnz .copy

    WRITE_FILE file_user_cfg, sector_buf, cx
    jc .write_error

    mov ax, 0x0600
    mov bh, 0x0F
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    
    mov ah, 0x02
    mov bh, 0
    xor dx, dx
    int 0x10

    retf

.write_error:
    mov ah, 0x02
    mov bh, 0
    mov dh, 16
    mov dl, 26
    int 0x10

    mov ah, 0x09
    mov al, ' '
    mov bh, 0
    mov bl, 0x3C ; cyan background, bright red text
    mov cx, 26
    int 0x10

    PRINT "Error writing to USER.CFG!"
.hang:
    jmp .hang

ui_text:
    db 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A, 0x0D, 0x0A
    db '                   ', 0xC9
    times 40 db 0xCD
    db 0xBB, 0x0D, 0x0A
    db '                   ', 0xBA, '              LamaOS Setup              ', 0xBA, 0x0D, 0x0A
    db '                   ', 0xCC
    times 40 db 0xCD
    db 0xB9, 0x0D, 0x0A
    db '                   ', 0xBA, '                                        ', 0xBA, 0x0D, 0x0A
    db '                   ', 0xBA, '    Welcome to LamaOS!                  ', 0xBA, 0x0D, 0x0A
    db '                   ', 0xBA, '    Please enter your new username:     ', 0xBA, 0x0D, 0x0A
    db '                   ', 0xBA, '                                        ', 0xBA, 0x0D, 0x0A
    db '                   ', 0xBA, '    >                                   ', 0xBA, 0x0D, 0x0A
    db '                   ', 0xBA, '                                        ', 0xBA, 0x0D, 0x0A
    db '                   ', 0xC8
    times 40 db 0xCD
    db 0xBC, 0

file_user_cfg db 'USER    CFG'

username_buf times 32 db 0
sector_buf times 512 db 0
