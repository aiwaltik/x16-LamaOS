[bits 16]
[org 0x0000]

SYS_INT equ 0x60
SYS_PUTS equ 0x01
SYS_GETCH equ 0x02
SYS_CLS equ 0x03
SYS_WRITE_FILE equ 0x15

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
    mov ah, SYS_PUTS
    int SYS_INT

    mov ah, 0x02
    mov bh, 0
    mov dh, 15
    mov dl, 26
    int 0x10

    mov di, username_buf
    xor cx, cx
.loop:
    mov ah, SYS_GETCH
    int SYS_INT
    cmp al, 0x0D
    je .done
    cmp al, 0x0A
    je .done
    cmp al, 0x08
    je .bs
    cmp al, 0x20
    jb .loop
    cmp cx, 20
    jae .loop

    stosb
    inc cx
    mov [echo_ch], al
    mov dx, echo_ch
    mov ah, SYS_PUTS
    int SYS_INT
    jmp .loop
.bs:
    cmp cx, 0
    je .loop
    dec cx
    dec di
    mov byte [di], 0
    mov dx, bs_seq
    mov ah, SYS_PUTS
    int SYS_INT
    jmp .loop
.done:
    mov al, 0
    stosb

    mov ah, 0x02
    mov bh, 0
    mov dh, 18
    mov dl, 26
    int 0x10
    mov dx, msg_saving
    mov ah, SYS_PUTS
    int SYS_INT

    mov dx, file_user_cfg
    push cs
    pop es
    mov bx, sector_buf
    
    mov si, username_buf
    mov di, sector_buf
.copy:
    lodsb
    stosb
    test al, al
    jnz .copy

    mov ah, SYS_WRITE_FILE
    int SYS_INT
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
    mov dx, msg_err
    mov ah, SYS_PUTS
    int SYS_INT
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

msg_saving db 'Saving configuration...', 0
msg_err db 'Error writing to USER.CFG!', 0
bs_seq db 0x08, ' ', 0x08, 0
echo_ch db 0, 0
file_user_cfg db 'USER    CFG'

username_buf times 32 db 0
sector_buf times 512 db 0
