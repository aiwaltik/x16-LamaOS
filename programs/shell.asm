[bits 16]
[org 0x0000]

%include "lib/lama.inc"

%macro PRINTLN_ERR 1-*
    jmp %%skip
%%str: db %1, 0x0D, 0x0A, 0
%%skip:
    PUTS_COLOR %%str, 0x0C
%endmacro

CFG_SEG equ 0x5000

LEX_HEADER

_start:
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

    CLS

    jmp repl

.run_setup:
    EXEC file_setup
    jc .err_setup
    
    ; Program loaded to 0x4000:0. Call it.
    call call_user_prog
    
    jmp _start

.err_setup:
    PRINTLN_ERR "Could not load SETUP.LEX"
    jmp repl

repl:
    call print_prompt

    call read_line

    cmp byte [cmd_buf], 0
    je repl

    call split_cmd

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
    mov di, cmd_date
    call streq
    jc .do_date

    mov si, cmd_buf
    mov di, cmd_echo
    call streq
    jc .do_echo

    mov si, cmd_buf
    mov di, cmd_touch
    call streq
    jc .do_touch

    mov si, cmd_buf
    mov di, cmd_rm
    call streq
    jc .do_rm

    mov si, cmd_buf
    mov di, cmd_cat
    call streq
    jc .do_cat

    mov si, cmd_buf
    mov di, cmd_write
    call streq
    jc .do_write

    mov si, cmd_buf
    call to_83_name
    jc .bad

    EXEC name83
    jc .bad

    ; Program loaded to 0x4000:0. Call it.
    call call_user_prog
    call load_user_cfg
    jmp repl

.do_ls:
    LS
    jmp repl

.do_dir:
    LS
    jmp repl

.do_cls:
    CLS
    jmp repl

.do_help:
    PRINTLN "Built-in commands:"
    PRINTLN "  help  - this text"
    PRINTLN "  ls    - list files"
    PRINTLN "  cls   - clear screen"
    PRINTLN "  time  - show time"
    PRINTLN "  date  - show date"
    PRINTLN "  echo  - print text"
    PRINTLN "  touch - create file"
    PRINTLN "  rm    - delete file"
    PRINTLN "  cat   - read file"
    PRINTLN "  write - write to file"
    PRINTLN "  <name>- run program"
    jmp repl

.do_time:
    GET_TIME
    mov al, ch
    call print_bcd
    PUTCHAR ':'
    mov al, cl
    call print_bcd
    PUTCHAR ':'
    mov al, dh
    call print_bcd
    PRINTLN
    jmp repl

.do_date:
    GET_DATE
    mov al, dl
    call print_bcd
    PUTCHAR '.'
    mov al, dh
    call print_bcd
    PUTCHAR '.'
    mov ax, cx
    call print_bcd_word
    PRINTLN
    jmp repl

.do_echo:
    mov dx, [arg_ptr]
    PUTS dx
    PRINTLN
    jmp repl

.do_touch:
    mov si, [arg_ptr]
    call to_83_name
    jc .bad_args
    CREATE_FILE name83
    jc .err_io
    jmp repl

.do_rm:
    mov si, [arg_ptr]
    call to_83_name
    jc .bad_args
    DELETE_FILE name83
    jc .err_io
    jmp repl

.do_cat:
    mov si, [arg_ptr]
    call to_83_name
    jc .bad_args
    FILE_SIZE name83
    jc .err_io
    ; DX:AX is size. We only support small files for now.
    cmp ax, 0
    je .cat_empty
    ; Read file to 0x6000
    READ_FILE name83, 0x6000
    jc .err_io
    ; Print it
    push ds
    mov bx, 0x6000
    mov ds, bx
    mov si, 0
    mov cx, ax
.cat_loop:
    lodsb
    cmp al, 0
    je .cat_done
    PUTCHAR al
    loop .cat_loop
.cat_done:
    pop ds
.cat_empty:
    PRINTLN
    jmp repl

.do_write:
    mov si, [arg_ptr]
    call to_83_name
    jc .bad_args
    ; Read line from user into sector_buf
    PRINT "Enter text: "
    call read_line_buf
    ; CX now contains the length of the string
    ; Write to file
    CREATE_FILE name83 ; ensure it exists
    WRITE_FILE name83, sector_buf, cx
    jc .err_io
    jmp repl

.bad_args:
    PRINTLN_ERR "Invalid arguments"
    jmp repl

.err_io:
    PRINTLN_ERR "I/O Error"
    jmp repl

.bad:
    PRINTLN_ERR "Bad command or file name"
    jmp repl

print_bcd_word:
    push ax
    mov al, ah
    call print_bcd
    pop ax
    call print_bcd
    ret

print_bcd:
    push ax
    mov ah, al
    shr al, 4
    add al, '0'
    PUTCHAR al
    pop ax
    and al, 0x0F
    add al, '0'
    PUTCHAR al
    ret

call_user_prog:
    push ds
    push es
    mov ax, 0x4000
    mov ds, ax
    mov es, ax
    
    mov word [cs:user_prog_ptr], 0x0000
    
    cmp word [0], 0x584C
    jne .do_call
    
    mov ax, [4]
    mov [cs:user_prog_ptr], ax
    
.do_call:
    call far [cs:user_prog_ptr]
    pop es
    pop ds
    ret

; ----------------------------
; read_line: reads into cmd_buf (0-terminated), supports backspace
; ----------------------------
read_line:
    INPUT cmd_buf, CMD_MAX
    PRINTLN
    ret

read_line_buf:
    INPUT sector_buf, 512
    PRINTLN
    ret

split_cmd:
    mov si, cmd_buf
.find_space:
    mov al, [si]
    cmp al, 0
    je .no_args
    cmp al, ' '
    je .found_space
    inc si
    jmp .find_space
.found_space:
    mov byte [si], 0
    inc si
.skip_spaces:
    mov al, [si]
    cmp al, ' '
    jne .set_arg
    inc si
    jmp .skip_spaces
.set_arg:
    mov [arg_ptr], si
    ret
.no_args:
    mov [arg_ptr], si
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
    READ_FILE file_user_cfg, CFG_SEG
    ret

; ----------------------------
; to_83_name: SI -> input command, outputs name83 (11 bytes)
; Accepts: "hello" or "hello.lex"
; If no ext, assumes LEX
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
    mov byte [name83+8], 'L'
    mov byte [name83+9], 'E'
    mov byte [name83+10], 'X'
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
    
    PUTS_COLOR prompt_root, 0x0A

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
    PUTCHAR_COLOR al, 0x0A
    inc di
    jmp .loop1
.done1:

    PUTS_COLOR prompt_tilde, 0x0B
    PUTS_COLOR prompt_colon, 0x0F
    
    pop es
    ret

; ----------------------------
; Data
; ----------------------------
CMD_MAX equ 64
cmd_buf times CMD_MAX db 0

name83 times 11 db 0

prompt_root db 'root@',0
prompt_tilde db '~',0
prompt_colon db ':',0
help   db 'Commands: ls, dir, cls, help, time, calc, fetch, setup, edit, <prog>',0x0D,0x0A,0
badcmd db 'Bad command',0x0D,0x0A,0

cmd_ls   db 'ls',0
cmd_dir  db 'dir',0
cmd_cls  db 'cls',0
cmd_help db 'help',0
cmd_time db 'time',0
cmd_date db 'date',0
cmd_echo db 'echo',0
cmd_touch db 'touch',0
cmd_rm   db 'rm',0
cmd_cat  db 'cat',0
cmd_write db 'write',0
file_user_cfg db 'USER    CFG',0
file_setup db 'SETUP   LEX',0

user_prog_ptr:
    dw 0x0000
    dw 0x4000

arg_ptr dw 0
sector_buf times 512 db 0

