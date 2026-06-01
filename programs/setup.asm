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

    mov di, username_buf
    xor cx, cx
.loop:
    GETCH
    cmp al, 0x0D
    je .check_done
    cmp al, 0x0A
    je .check_done
    cmp al, 0x08
    je .bs
    cmp al, 0x20
    jb .loop
    cmp cx, 20
    jae .loop

    stosb
    inc cx
    PUTCHAR al
    jmp .loop
.check_done:
    cmp cx, 0
    je .loop
    jmp .done
.bs:
    cmp cx, 0
    je .loop
    dec cx
    dec di
    mov byte [di], 0
    PRINT 0x08, 0x20, 0x08
    jmp .loop
.done:
    mov al, 0
    stosb

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
    mov dl, 30
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
