[bits 16]
[org 0x0000]

SYS_INT   equ 0x60
SYS_PUTS  equ 0x01
SYS_GETCH equ 0x02
SYS_CLS   equ 0x03
SYS_LS    equ 0x10
SYS_EXEC  equ 0x11
SYS_EXIT  equ 0x12
SYS_READ_FILE equ 0x14

CFG_SEG equ 0x5000

start:
    call load_user_cfg
    jc .run_setup

    push ds
    mov ax, CFG_SEG
    mov ds, ax
    mov al, [0]
    pop ds
    cmp al, 0
    je .run_setup
    cmp al, 0xFF
    je .run_setup
    cmp al, ' '
    je .run_setup

    jmp repl

.run_setup:
    mov dx, file_setup
    mov ah, SYS_EXEC
    int SYS_INT
    jc .err_setup
    
    ; Program loaded to 0x4000:0. Call it.
    push ds
    push es
    call far [user_prog_ptr]
    pop es
    pop ds
    
    jmp start

.err_setup:
    mov dx, err_setup_msg
    mov ah, SYS_PUTS
    int SYS_INT
    jmp repl

repl:
    call print_prompt

    call read_line

    cmp byte [cmd_buf], 0
    je repl

    mov si, cmd_buf
    mov di, cmd_ls
    call streq
    jc .do_ls

    mov si, cmd_buf
    mov di, cmd_dir
    call streq
    jc .do_dir

    mov si, cmd_buf
    mov di, cmd_cls
    call streq
    jc .do_cls

    mov si, cmd_buf
    mov di, cmd_help
    call streq
    jc .do_help

    mov si, cmd_buf
    mov di, cmd_time
    call streq
    jc .do_time

    mov si, cmd_buf
    call to_83_name
    jc .bad

    mov dx, name83
    mov ah, SYS_EXEC
    int SYS_INT
    jc .bad

    ; Program loaded to 0x4000:0. Call it.
    push ds
    push es
    call far [user_prog_ptr]
    pop es
    pop ds
    call load_user_cfg
    jmp repl

.do_ls:
    mov ah, SYS_LS
    int SYS_INT
    jmp repl

.do_dir:
    mov ah, SYS_LS
    int SYS_INT
    jmp repl

.do_cls:
    mov ah, SYS_CLS
    int SYS_INT
    jmp repl

.do_help:
    mov dx, help
    mov ah, SYS_PUTS
    int SYS_INT
    jmp repl

.do_time:
    mov ah, 0x02
    int 0x1A
    mov al, ch
    call print_bcd
    mov al, ':'
    mov ah, 0x0E
    int 0x10
    mov al, cl
    call print_bcd
    mov al, ':'
    mov ah, 0x0E
    int 0x10
    mov al, dh
    call print_bcd
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT
    jmp repl

.bad:
    mov dx, badcmd
    mov ah, SYS_PUTS
    int SYS_INT
    jmp repl

print_bcd:
    push ax
    mov ah, al
    shr al, 4
    add al, '0'
    push ax
    mov ah, 0x0E
    int 0x10
    pop ax
    pop ax
    and al, 0x0F
    add al, '0'
    mov ah, 0x0E
    int 0x10
    ret

; ----------------------------
; read_line: reads into cmd_buf (0-terminated), supports backspace
; ----------------------------
read_line:
    push es
    push ds
    pop es
    mov di, cmd_buf
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
    cmp cx, CMD_MAX-1
    jae .loop

    stosb
    inc cx
    ; echo char
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
    ; erase from screen: "\b \b"
    mov dx, bs_seq
    mov ah, SYS_PUTS
    int SYS_INT
    jmp .loop

.done:
    mov al, 0
    stosb
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT
    pop es
    ret

; ----------------------------
; streq: compare 0-term strings SI and DI, case-sensitive
; sets CF=1 if equal
; ----------------------------
streq:
    push ax
.c:
    mov al, [si]
    cmp al, [di]
    jne .ne
    cmp al, 0
    je .eq
    inc si
    inc di
    jmp .c
.eq:
    stc
    pop ax
    ret
.ne:
    clc
    pop ax
    ret

load_user_cfg:
    mov dx, file_user_cfg
    mov cx, CFG_SEG
    mov ah, SYS_READ_FILE
    int SYS_INT
    ret

; ----------------------------
; to_83_name: SI -> input command, outputs name83 (11 bytes)
; Accepts: "hello" or "hello.bin"
; If no ext, assumes BIN
; Uppercases, pads with spaces.
; CF=1 on error.
; ----------------------------
to_83_name:
    push ax
    push bx
    push cx
    push di
    push es

    push ds
    pop es

    mov di, name83
    mov cx, 11
    mov al, ' '
    rep stosb

    mov di, name83
    xor bx, bx       ; count base
.base:
    mov al, [si]
    cmp al, 0
    je .noext
    cmp al, '.'
    je .ext
    cmp al, ' '
    je .end
    call upcase
    cmp bx, 8
    jae .skipb
    mov [di], al
    inc di
    inc bx
.skipb:
    inc si
    jmp .base

.ext:
    inc si
    mov di, name83+8
    mov cx, 0
.extloop:
    mov al, [si]
    cmp al, 0
    je .ok
    cmp al, ' '
    je .ok
    call upcase
    cmp cx, 3
    jae .skipe
    mov [di], al
    inc di
    inc cx
.skipe:
    inc si
    jmp .extloop

.noext:
    mov byte [name83+8], 'B'
    mov byte [name83+9], 'I'
    mov byte [name83+10], 'N'
    jmp .ok

.end:
    jmp .noext

.ok:
    clc
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

upcase:
    cmp al, 'a'
    jb .r
    cmp al, 'z'
    ja .r
    sub al, 32
.r:
    ret

print_prompt:
    push es
    mov si, prompt_root
    mov bl, 0x0A
    call puts_color

    mov ax, CFG_SEG
    mov es, ax
    xor di, di
    mov ah, 0x03
    mov bh, 0
    int 0x10
.loop1:
    mov al, [es:di]
    cmp al, 0
    je .done1
    mov ah, 0x09
    mov bl, 0x0A
    mov cx, 1
    int 0x10
    inc dl
    cmp dl, 80
    jl .set1
    mov dl, 0
    inc dh
.set1:
    mov ah, 0x02
    int 0x10
    inc di
    jmp .loop1
.done1:

    mov si, prompt_tilde
    mov bl, 0x0B
    call puts_color

    mov si, prompt_colon
    mov bl, 0x0F
    call puts_color
    pop es
    ret

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

; ----------------------------
; Data
; ----------------------------
CMD_MAX equ 64
cmd_buf times CMD_MAX db 0

name83 times 11 db 0

banner db 'LamaOS shell. Type help',0x0D,0x0A,0
prompt_root db 'root@',0
prompt_tilde db '~',0
prompt_colon db ':',0
help   db 'Commands: ls, dir, cls, help, time, calc, fetch, setup, <prog>',0x0D,0x0A,0
badcmd db 'Bad command',0x0D,0x0A,0

cmd_ls   db 'ls',0
cmd_dir  db 'dir',0
cmd_cls  db 'cls',0
cmd_help db 'help',0
cmd_time db 'time',0
err_setup_msg db 'Error loading SETUP.BIN',0x0D,0x0A,0
file_user_cfg db 'USER    CFG',0
file_setup db 'SETUP   BIN',0

crlf db 0x0D,0x0A,0
bs_seq db 0x08,' ',0x08,0
echo_ch db 0,0

user_prog_ptr:
    dw 0x0000
    dw 0x4000

