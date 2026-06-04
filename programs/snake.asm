[bits 16]
[org 0x0000]

%include "lib/lama.inc"

LEX_HEADER

_start:
    ; Set VGA mode
    SET_VIDEO_MODE 0x13
    
    ; init snake
    mov word [snake_len], 3
    mov word [snake_dir], 1 ; 0=up, 1=right, 2=down, 3=left
    
    mov word [snake_x], 10
    mov word [snake_y], 10
    mov word [snake_x+2], 9
    mov word [snake_y+2], 10
    mov word [snake_x+4], 8
    mov word [snake_y+4], 10

    call spawn_food

    ; clear screen
    CLEAR_SCREEN_VGA 0

.game_loop:
    ; check input
    KBHIT
    test al, al
    jz .no_key
    
    GETCH
    cmp al, 27 ; ESC
    je .exit
    
    ; check arrow keys (in AH)
    cmp ah, 0x48 ; Up
    jne .not_up
    cmp word [snake_dir], 2
    je .no_key
    mov word [snake_dir], 0
    jmp .no_key
.not_up:
    cmp ah, 0x4D ; Right
    jne .not_right
    cmp word [snake_dir], 3
    je .no_key
    mov word [snake_dir], 1
    jmp .no_key
.not_right:
    cmp ah, 0x50 ; Down
    jne .not_down
    cmp word [snake_dir], 0
    je .no_key
    mov word [snake_dir], 2
    jmp .no_key
.not_down:
    cmp ah, 0x4B ; Left
    jne .not_left
    cmp word [snake_dir], 1
    je .no_key
    mov word [snake_dir], 3
    jmp .no_key
.not_left:

.no_key:

    ; wait a bit
    call wait_ticks

    ; erase tail
    call erase_tail
    
    ; move snake body
    call move_body
    
    ; update head
    call move_head
    
    ; check boundaries
    call check_bounds
    test ax, ax
    jnz .game_over
    
    ; check self collision
    call check_self
    test ax, ax
    jnz .game_over
    
    ; check food
    call check_food
    
    ; draw snake
    call draw_snake
    
    ; draw food
    call draw_food

    jmp .game_loop

.game_over:
    ; restore text mode and exit
    SET_VIDEO_MODE 0x03
    CLS
    PUTS msg_game_over
    GETCH
    retf

.exit:
    SET_VIDEO_MODE 0x03
    CLS
    retf

wait_ticks:
    GET_TICKS
    mov bx, ax
.w:
    YIELD
    GET_TICKS
    sub ax, bx
    cmp ax, 1 ; 1 tick delay
    jl .w
    ret

spawn_food:
    ; simple PRNG based on ticks
    GET_TICKS
    mov bx, ax
    
    ; x = (ticks % 38) + 1
    mov ax, bx
    xor dx, dx
    mov cx, 38
    div cx
    inc dx
    mov [food_x], dx
    
    ; y = ((ticks/13) % 23) + 1
    mov ax, bx
    xor dx, dx
    mov cx, 13
    div cx
    xor dx, dx
    mov cx, 23
    div cx
    inc dx
    mov [food_y], dx
    ret

erase_tail:
    mov bx, [snake_len]
    dec bx
    shl bx, 1
    mov cx, [snake_x + bx]
    mov dx, [snake_y + bx]
    
    ; grid to screen
    shl cx, 3 ; *8
    shl dx, 3 ; *8
    
    FILL_RECT cx, dx, 8, 8, 0
    ret

move_body:
    mov bx, [snake_len]
    dec bx
    shl bx, 1
.ml:
    cmp bx, 0
    je .md
    mov ax, [snake_x + bx - 2]
    mov [snake_x + bx], ax
    mov ax, [snake_y + bx - 2]
    mov [snake_y + bx], ax
    sub bx, 2
    jmp .ml
.md:
    ret

move_head:
    mov ax, [snake_dir]
    cmp ax, 0
    je .m_up
    cmp ax, 1
    je .m_right
    cmp ax, 2
    je .m_down
    cmp ax, 3
    je .m_left
    ret
.m_up:
    dec word [snake_y]
    ret
.m_down:
    inc word [snake_y]
    ret
.m_left:
    dec word [snake_x]
    ret
.m_right:
    inc word [snake_x]
    ret

check_bounds:
    xor ax, ax
    mov bx, [snake_x]
    cmp bx, 0
    jl .out
    cmp bx, 39
    jg .out
    mov bx, [snake_y]
    cmp bx, 0
    jl .out
    cmp bx, 24
    jg .out
    ret
.out:
    mov ax, 1
    ret

check_self:
    xor ax, ax
    mov cx, [snake_x]
    mov dx, [snake_y]
    mov bx, 2
.csl:
    mov si, bx
    shr si, 1
    cmp si, [snake_len]
    jge .csd
    
    cmp cx, [snake_x + bx]
    jne .csn
    cmp dx, [snake_y + bx]
    jne .csn
    
    mov ax, 1
    ret
.csn:
    add bx, 2
    jmp .csl
.csd:
    ret

check_food:
    mov ax, [snake_x]
    cmp ax, [food_x]
    jne .cfd
    mov ax, [snake_y]
    cmp ax, [food_y]
    jne .cfd
    
    ; ate food!
    cmp word [snake_len], 100
    jge .skip_grow
    
    push bx
    mov bx, [snake_len]
    dec bx
    shl bx, 1
    
    mov ax, [snake_x + bx]
    mov [snake_x + bx + 2], ax
    mov ax, [snake_y + bx]
    mov [snake_y + bx + 2], ax
    pop bx
    
    inc word [snake_len]
.skip_grow:
    call spawn_food
.cfd:
    ret

draw_snake:
    mov bx, 0
.dsl:
    mov si, bx
    shr si, 1
    cmp si, [snake_len]
    jge .dsd
    
    mov cx, [snake_x + bx]
    mov dx, [snake_y + bx]
    
    ; color 10 = light green
    mov al, 10
    cmp bx, 0
    jne .dsnc
    mov al, 14 ; yellow for head
.dsnc:
    
    push ax
    shl cx, 3
    shl dx, 3
    
    ; AL is properly passed as parameter
    FILL_RECT cx, dx, 8, 8, al
    pop ax
    
    add bx, 2
    jmp .dsl
.dsd:
    ret

draw_food:
    mov cx, [food_x]
    mov dx, [food_y]
    shl cx, 3
    shl dx, 3
    FILL_RECT cx, dx, 8, 8, 12 ; light red
    ret

msg_game_over: db 'GAME OVER! Press any key...', 13, 10, 0

snake_len: dw 3
snake_dir: dw 1
food_x: dw 0
food_y: dw 0

snake_x: times 100 dw 0
snake_y: times 100 dw 0