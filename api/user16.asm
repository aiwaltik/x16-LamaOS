.puts:
    ; Caller DS:DX -> string. Saved caller DS is at [BP+2].
    mov ax, [bp + 2]
    mov es, ax
    mov si, dx
    call puts_es_si
    jmp .done

.getch:
    call getch
    ; Return char in AL by patching saved AX at [BP+16]
    mov ah, [bp + 17]
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
