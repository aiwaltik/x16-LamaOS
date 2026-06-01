[bits 16]
[org 0x0000]

%include "lib/lama.inc"

LEX_HEADER

_start:
    PRINTLN "LamaOS Calculator"

    PRINT "Expression (e.g. 2 + 2): "
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

    mov bl, [op_char]
    mov ax, [num1]
    cmp bl, '+'
    je .do_add
    cmp bl, '-'
    je .do_sub
    cmp bl, '*'
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
    PRINTLN "Error: Division by zero"
    jmp .exit

.bad_expr:
    PRINTLN "Error: Invalid expression"
    jmp .exit

.print_res:
    mov [result], ax
    PRINT "Result: "
    mov ax, [result]
    call print_num

.exit:
    PRINTLN
    retf

read_expr_line:
    push es
    push ds
    pop es
    mov di, expr_buf
    xor cx, cx
.loop:
    GETCH
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
    PUTCHAR al
    jmp .loop
.bs:
    cmp cx, 0
    je .loop
    dec cx
    dec di
    mov byte [di], 0
    PRINT 0x08, 0x20, 0x08
    jmp .loop
.done:
    mov byte [di], 0
    PRINTLN
    pop es
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
    PUTCHAR '0'
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
    PUTCHAR al
    loop .print_loop
    ret

op_char db 0
num1 dw 0
num2 dw 0
result dw 0
EXPR_MAX equ 64
expr_buf times EXPR_MAX db 0
