.set_video_mode:
    mov ax, [bp + 16] ; AL=mode
    mov ah, 0x00
    int 0x10
    jmp .done

.draw_pixel:
    mov cx, [bp + 12] ; CX=x
    mov dx, [bp + 10] ; DX=y
    mov ax, [bp + 16] ; AL=color
    mov ah, 0x0C
    xor bh, bh
    int 0x10
    jmp .done
