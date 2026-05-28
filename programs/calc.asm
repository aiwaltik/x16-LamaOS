[bits 16]
[org 0x0000]

SYS_INT  equ 0x60
SYS_PUTS equ 0x01
SYS_GETCH equ 0x02
SYS_EXIT equ 0x12

start:
    push cs
    pop ds

    mov dx, calc_msg
    mov ah, SYS_PUTS
    int SYS_INT

    mov dx, prompt_expr
    mov ah, SYS_PUTS
    int SYS_INT
    call read_expr_line

    mov si, expr_buf
    call parse_uint
    jc .bad_expr
    mov [num1], ax

    call skip_spaces
    mov al, [si]
    cmp al, '+'
    je .op_ok
    cmp al, '-'
    je .op_ok
    cmp al, '*'
    je .op_ok
    cmp al, '/'
    je .op_ok
    jmp .bad_expr
.op_ok:
    mov [op_char], al
    inc si

    call parse_uint
    jc .bad_expr
    mov [num2], ax

    call skip_spaces
    cmp byte [si], 0
    jne .bad_expr

    mov al, [op_char]
    mov ax, [num1]
    cmp al, '+'
    je .do_add
    cmp al, '-'
    je .do_sub
    cmp al, '*'
    je .do_mul
    mov bx, [num2]
    cmp bx, 0
    je .div_zero
    xor dx, dx
    div bx
    jmp .print_res
.do_add:
    add ax, [num2]
    jmp .print_res
.do_sub:
    sub ax, [num2]
    jmp .print_res
.do_mul:
    mov bx, [num2]
    mul bx
    jmp .print_res
.div_zero:
    mov dx, div_zero_msg
    mov ah, SYS_PUTS
    int SYS_INT
    jmp .exit

.bad_expr:
    mov dx, bad_expr_msg
    mov ah, SYS_PUTS
    int SYS_INT
    jmp .exit

.print_res:
    mov [result], ax
    mov dx, result_msg
    mov ah, SYS_PUTS
    int SYS_INT
    mov ax, [result]
    call print_num

.exit:
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT
    retf

read_expr_line:
    mov di, expr_buf
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
    cmp cx, EXPR_MAX-1
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
    mov byte [di], 0
    mov dx, crlf
    mov ah, SYS_PUTS
    int SYS_INT
    ret

skip_spaces:
.loop_spaces:
    mov al, [si]
    cmp al, ' '
    jne .done_spaces
    inc si
    jmp .loop_spaces
.done_spaces:
    ret

parse_uint:
    call skip_spaces
    xor bx, bx
    xor cx, cx
.loop_digits:
    mov al, [si]
    cmp al, '0'
    jb .done_digits
    cmp al, '9'
    ja .done_digits
    sub al, '0'
    xor ah, ah
    push ax
    mov ax, bx
    mov dx, 0
    mov di, 10
    mul di
    pop di
    add ax, di
    mov bx, ax
    inc si
    inc cx
    jmp .loop_digits
.done_digits:
    cmp cx, 0
    je .parse_error
    mov ax, bx
    clc
    ret
.parse_error:
    stc
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

calc_msg db 'Calculator (+, -, *, /)',0x0D,0x0A,0
prompt_expr db 'Expr: ',0
result_msg db 'Result: ',0
bad_expr_msg db 'Invalid expression. Example: 100+100',0x0D,0x0A,0
div_zero_msg db 'Division by zero',0x0D,0x0A,0
crlf db 0x0D,0x0A,0
bs_seq db 0x08, ' ', 0x08, 0
echo_ch db 0, 0
op_char db 0
num1 dw 0
num2 dw 0
result dw 0
EXPR_MAX equ 64
expr_buf times EXPR_MAX db 0
