[bits 16]
[org 0x0000]

%include "lib/lama.inc"

LEX_HEADER

_start:
    ; Set VGA mode 320x200 256-color
    SET_VIDEO_MODE 0x13
    
    ; Setup ES for fast VGA video memory access
    mov ax, 0xA000
    mov es, ax
    xor di, di

    mov word [y], 0
.y_loop:
    ; Check keyboard for early exit once per line
    KBHIT
    test al, al
    jz .no_key
    GETCH
    cmp al, 27 ; ESC
    je .exit
.no_key:

    ; Calculate c_im (imaginary part of C)
    ; c_im = y * 3 - 300
    mov ax, [y]
    mov bx, 3
    imul bx
    sub ax, 300
    mov [c_im], ax

    mov word [x], 0
.x_loop:
    ; Calculate c_re (real part of C)
    ; c_re = x * 5 / 2 - 550
    mov ax, [x]
    mov bx, 5
    imul bx
    shr ax, 1       ; divide by 2
    sub ax, 550
    mov [c_re], ax

    ; Initialize Z = 0
    mov word [Z_re], 0
    mov word [Z_im], 0
    mov word [iter], 0

.iter_loop:
    ; Z_re_sq = (Z_re * Z_re) >> 8
    mov ax, [Z_re]
    mov bx, ax
    imul bx
    mov al, ah
    mov ah, dl
    mov [Z_re_sq], ax

    ; Z_im_sq = (Z_im * Z_im) >> 8
    mov ax, [Z_im]
    mov bx, ax
    imul bx
    mov al, ah
    mov ah, dl
    mov [Z_im_sq], ax

    ; if (Z_re_sq + Z_im_sq > 1024) [4.0 in 8.8 fixed point]
    mov ax, [Z_re_sq]
    add ax, [Z_im_sq]
    cmp ax, 1024
    jg .escaped

    ; Z_new_im = ((Z_re * Z_im) >> 8) * 2 + c_im
    mov ax, [Z_re]
    mov bx, [Z_im]
    imul bx
    mov al, ah
    mov ah, dl
    shl ax, 1       ; multiply by 2
    add ax, [c_im]
    mov [Z_new_im], ax

    ; Z_re = Z_re_sq - Z_im_sq + c_re
    mov ax, [Z_re_sq]
    sub ax, [Z_im_sq]
    add ax, [c_re]
    mov [Z_re], ax

    ; Z_im = Z_new_im
    mov ax, [Z_new_im]
    mov [Z_im], ax

    inc word [iter]
    cmp word [iter], 64
    jl .iter_loop

.escaped:
    ; Color selection based on iteration count
    mov ax, [iter]
    cmp ax, 64
    je .black
    add al, 32      ; use color palette starting at 32
    jmp .draw
.black:
    mov al, 0       ; center of Mandelbrot is black
.draw:
    ; Write directly to video memory
    mov [es:di], al
    inc di

    inc word [x]
    cmp word [x], 320
    jl .x_loop

    inc word [y]
    cmp word [y], 200
    jl .y_loop

    ; Drawing complete, wait for keypress to exit
    GETCH

.exit:
    SET_VIDEO_MODE 0x03
    CLS
    retf

; Local Data
x: dw 0
y: dw 0
c_re: dw 0
c_im: dw 0
Z_re: dw 0
Z_im: dw 0
Z_re_sq: dw 0
Z_im_sq: dw 0
Z_new_im: dw 0
iter: dw 0