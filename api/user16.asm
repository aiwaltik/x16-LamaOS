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
    mov di, [bp + 10] ; DX
    mov bx, [bp + 12] ; CX (max length)
    test bx, bx
    jz .input_done_empty
    dec bx            ; reserve 1 byte for null terminator
    xor cx, cx        ; current length
.input_loop:
    call getch
    cmp al, 0x0D
    je .input_done
    cmp al, 0x0A
    je .input_done
    cmp al, 0x08
    je .input_bs
    cmp al, 0x20
    jb .input_loop
    cmp cx, bx
    jae .input_loop

    stosb
    inc cx
    call putchar
    jmp .input_loop

.input_bs:
    test cx, cx
    jz .input_loop
    dec cx
    dec di
    mov al, 0x08
    call putchar
    mov al, 0x20
    call putchar
    mov al, 0x08
    call putchar
    jmp .input_loop

.input_done:
    mov al, 0
    stosb
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
