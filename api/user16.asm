.puts:
    ; Caller DS:DX -> string. Saved caller DS is at [BP+2].
    mov ax, [bp + 2]
    mov es, ax
    mov si, dx
    call puts_es_si
    jmp .done

.getch:
    call getch
    ; Return char in AL and scan code in AH by patching saved AX at [BP+16]
    mov [bp + 16], ax
    jmp .done

.cls:
    call cls
    jmp .done

.putchar:
    mov ax, [bp + 16] ; saved AX (AH=0x04, AL=char)
    call putchar
    jmp .done

.set_cursor:
    mov dx, [bp + 10] ; saved DX (DH=row, DL=col)
    mov ah, 0x02
    xor bh, bh
    int 0x10
    jmp .done

.get_cursor:
    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov [bp + 10], dx ; saved DX
    jmp .done

.play_sound:
    mov bx, [bp + 14] ; saved BX
    test bx, bx
    jz .sound_off
    cmp bx, 19
    jae .sound_ok
    mov bx, 19
.sound_ok:
    ; frequency to divisor: 1193180 / freq
    mov ax, 0x34DD
    mov dx, 0x0012
    div bx
    mov bx, ax
    ; set PIT
    mov al, 0xB6
    out 0x43, al
    mov al, bl
    out 0x42, al
    mov al, bh
    out 0x42, al
    ; enable speaker
    in al, 0x61
    or al, 3
    out 0x61, al
    jmp .done
.sound_off:
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    jmp .done

.puts_color:
    mov ax, [bp + 2]
    mov es, ax
    mov si, dx
    mov bx, [bp + 14] ; saved BX (BL=color)
    call puts_color_es_si
    jmp .done

.putchar_color:
    mov ax, [bp + 16] ; saved AX (AL=char)
    mov bx, [bp + 14] ; saved BX (BL=color)
    call putchar_color
    jmp .done

.input:
    ; DS:DX -> buffer, CX -> max length
    mov ax, [bp + 2]
    mov es, ax
    mov di, [bp + 10] ; DX -> buffer start
    mov bx, [bp + 12] ; CX (max length)
    test bx, bx
    jz .input_done_empty
    dec bx            ; reserve 1 byte for null terminator
    
    mov ax, [bp + 16] ; saved AX (AL = initial length)
    xor ah, ah
    cmp ax, bx
    jbe .init_len_ok
    mov ax, bx
.init_len_ok:
    mov cx, ax        ; total length
    mov dx, ax        ; cursor position
.input_loop:
    push dx
    call getch
    pop dx
    cmp al, 0
    je .input_ext
    cmp al, 0x0D
    je .input_done
    cmp al, 0x0A
    je .input_done
    cmp al, 0x08
    je .input_bs
    cmp al, 0x7F
    je .input_ctrl_bs
    cmp al, 0x20
    jb .input_loop
    
    ; Insert AL
    cmp cx, bx
    jae .input_loop

    push ds
    push es
    pop ds
    push cx
    push si
    push di
    
    mov si, di
    add si, cx
    dec si
    
    mov di, si
    inc di
    
    sub cx, dx
    jz .insert_place
    
    std
    rep movsb
    cld

.insert_place:
    pop di
    pop si
    pop cx
    pop ds
    
    push bx
    mov bx, dx
    mov [es:di+bx], al
    pop bx
    
    inc cx
    
    push cx
    push dx
    push bx
.insert_print:
    mov bx, dx
    mov al, [es:di+bx]
    call putchar
    inc dx
    cmp dx, cx
    jb .insert_print
    
    pop bx
    pop dx
    pop cx
    
    push cx
    push dx
    sub cx, dx
    dec cx
    jz .insert_done
.insert_back:
    mov al, 0x08
    call putchar
    loop .insert_back
.insert_done:
    pop dx
    pop cx
    inc dx
    jmp .input_loop

.input_bs:
    call .do_backspace
    jmp .input_loop

.input_ctrl_bs:
    test dx, dx
    jz .input_loop
.cbs_skip_spaces:
    test dx, dx
    jz .input_loop
    push bx
    mov bx, dx
    dec bx
    mov al, [es:di+bx]
    pop bx
    cmp al, ' '
    jne .cbs_skip_word
    call .do_backspace
    jmp .cbs_skip_spaces
.cbs_skip_word:
    test dx, dx
    jz .input_loop
    push bx
    mov bx, dx
    dec bx
    mov al, [es:di+bx]
    pop bx
    cmp al, ' '
    je .input_loop
    call .do_backspace
    jmp .cbs_skip_word

.input_del:
    call .do_delete
    jmp .input_loop

.input_ctrl_del:
    cmp dx, cx
    jae .input_loop
.cdel_skip_word:
    cmp dx, cx
    jae .input_loop
    push bx
    mov bx, dx
    mov al, [es:di+bx]
    pop bx
    cmp al, ' '
    je .cdel_skip_spaces
    call .do_delete
    jmp .cdel_skip_word
.cdel_skip_spaces:
    cmp dx, cx
    jae .input_loop
    push bx
    mov bx, dx
    mov al, [es:di+bx]
    pop bx
    cmp al, ' '
    jne .input_loop
    call .do_delete
    jmp .cdel_skip_spaces

.do_backspace:
    test dx, dx
    jz .db_done
    
    mov al, 0x08
    call putchar
    dec dx
    
.do_delete:
    cmp dx, cx
    jae .db_done
    
    dec cx
    
    push ds
    push es
    pop ds
    push cx
    push si
    push di
    
    mov si, di
    add si, dx
    inc si
    
    mov di, di
    add di, dx
    
    sub cx, dx
    jz .db_place
    
    cld
    rep movsb

.db_place:
    pop di
    pop si
    pop cx
    pop ds
    
    push cx
    push dx
    push bx
    
    cmp dx, cx
    jae .db_print_space
    
.db_print:
    mov bx, dx
    mov al, [es:di+bx]
    call putchar
    inc dx
    cmp dx, cx
    jb .db_print

.db_print_space:
    mov al, 0x20
    call putchar
    
    pop bx
    pop dx
    pop cx
    
    push cx
    push dx
    sub cx, dx
    inc cx
.db_back:
    mov al, 0x08
    call putchar
    loop .db_back
    pop dx
    pop cx
.db_done:
    ret

.input_ext:
    cmp ah, 0x4B    ; Left arrow
    je .input_left
    cmp ah, 0x4D    ; Right arrow
    je .input_right
    cmp ah, 0x73    ; Ctrl + Left
    je .input_ctrl_left
    cmp ah, 0x74    ; Ctrl + Right
    je .input_ctrl_right
    cmp ah, 0x53    ; Delete
    je .input_del
    cmp ah, 0x93    ; Ctrl + Delete
    je .input_ctrl_del
    cmp ah, 0x48    ; Up arrow
    je .input_up
    cmp ah, 0x50    ; Down arrow
    je .input_down
    jmp .input_loop

.input_up:
    call .clear_input
    push bx
    mov bx, cx
    mov byte [es:di+bx], 0
    pop bx
    mov [bp + 12], cx ; return length in CX
    mov ax, 0x4800
    mov [bp + 16], ax
    jmp .done

.input_down:
    call .clear_input
    push bx
    mov bx, cx
    mov byte [es:di+bx], 0
    pop bx
    mov [bp + 12], cx ; return length in CX
    mov ax, 0x5000
    mov [bp + 16], ax
    jmp .done

.clear_input:
.ci_mv_end:
    cmp dx, cx
    je .ci_do_clear
    push bx
    mov bx, dx
    mov al, [es:di+bx]
    pop bx
    call putchar
    inc dx
    jmp .ci_mv_end
.ci_do_clear:
    test cx, cx
    jz .ci_cleared
.ci_clear_loop:
    mov al, 0x08
    call putchar
    mov al, 0x20
    call putchar
    mov al, 0x08
    call putchar
    loop .ci_clear_loop
.ci_cleared:
    ret

.input_left:
    test dx, dx
    jz .input_loop
    dec dx
    mov al, 0x08
    call putchar
    jmp .input_loop

.input_right:
    cmp dx, cx
    jae .input_loop
    push bx
    mov bx, dx
    mov al, [es:di+bx]
    pop bx
    call putchar
    inc dx
    jmp .input_loop

.input_ctrl_left:
    test dx, dx
    jz .input_loop

.cl_skip_spaces:
    test dx, dx
    jz .input_loop
    push bx
    mov bx, dx
    dec bx
    mov al, [es:di+bx]
    pop bx
    cmp al, ' '
    jne .cl_skip_word
    dec dx
    mov al, 0x08
    call putchar
    jmp .cl_skip_spaces

.cl_skip_word:
    test dx, dx
    jz .input_loop
    push bx
    mov bx, dx
    dec bx
    mov al, [es:di+bx]
    pop bx
    cmp al, ' '
    je .input_loop
    dec dx
    mov al, 0x08
    call putchar
    jmp .cl_skip_word

.input_ctrl_right:
    cmp dx, cx
    jae .input_loop

.cr_skip_word:
    cmp dx, cx
    jae .input_loop
    push bx
    mov bx, dx
    mov al, [es:di+bx]
    pop bx
    cmp al, ' '
    je .cr_skip_spaces
    call putchar
    inc dx
    jmp .cr_skip_word

.cr_skip_spaces:
    cmp dx, cx
    jae .input_loop
    push bx
    mov bx, dx
    mov al, [es:di+bx]
    pop bx
    cmp al, ' '
    jne .input_loop
    call putchar
    inc dx
    jmp .cr_skip_spaces

.input_done:
    push bx
    mov bx, cx
    mov al, 0
    mov [es:di+bx], al
    pop bx
    
    mov [bp + 12], cx ; return length in CX
    jmp .done

.input_done_empty:
    mov word [bp + 12], 0
    jmp .done

.menu:
    mov ax, [bp + 2]
    mov es, ax
    mov si, dx
    call run_menu
    mov [bp + 16], ax
    jmp .done

.kbhit:
    mov dx, 0x3FD
    in al, dx
    test al, 1
    jnz .kb_yes
    
    mov ah, 0x01
    int 0x16
    jnz .kb_yes
    
    mov ax, [bp + 16]
    mov al, 0
    mov [bp + 16], ax
    jmp .done

.kb_yes:
    mov ax, [bp + 16]
    mov al, 1
    mov [bp + 16], ax
    jmp .done
