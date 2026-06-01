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

.draw_rect:
    mov cx, [bp + 12] ; x
    mov dx, [bp + 10] ; y
    mov si, [bp + 8]  ; w
    mov di, [bp + 6]  ; h
    mov ax, [bp + 16] ; color

    push cx
    push si
.dr_top:
    test si, si
    jz .dr_top_done
    call .gdi_draw_pixel
    inc cx
    dec si
    jmp .dr_top
.dr_top_done:
    pop si
    pop cx

    push cx
    push dx
    push si
    add dx, di
    dec dx
.dr_bottom:
    test si, si
    jz .dr_bottom_done
    call .gdi_draw_pixel
    inc cx
    dec si
    jmp .dr_bottom
.dr_bottom_done:
    pop si
    pop dx
    pop cx

    push dx
    push di
.dr_left:
    test di, di
    jz .dr_left_done
    call .gdi_draw_pixel
    inc dx
    dec di
    jmp .dr_left
.dr_left_done:
    pop di
    pop dx

    push cx
    push dx
    push di
    add cx, si
    dec cx
.dr_right:
    test di, di
    jz .dr_right_done
    call .gdi_draw_pixel
    inc dx
    dec di
    jmp .dr_right
.dr_right_done:
    pop di
    pop dx
    pop cx

    jmp .done

.fill_rect:
    mov cx, [bp + 12] ; x
    mov dx, [bp + 10] ; y
    mov si, [bp + 8]  ; w
    mov di, [bp + 6]  ; h
    mov ax, [bp + 16] ; color

.fr_y_loop:
    test di, di
    jz .done
    
    push cx
    push si
.fr_x_loop:
    test si, si
    jz .fr_x_done
    call .gdi_draw_pixel
    inc cx
    dec si
    jmp .fr_x_loop
.fr_x_done:
    pop si
    pop cx
    
    inc dx
    dec di
    jmp .fr_y_loop

.draw_line:
    mov cx, [bp + 12] ; x0
    mov dx, [bp + 10] ; y0
    mov si, [bp + 8]  ; x1
    mov di, [bp + 6]  ; y1
    mov ax, [bp + 16] ; color
    call .gdi_draw_line
    jmp .done

.gdi_draw_pixel:
    push ax
    push bx
    push cx
    push dx
    mov ah, 0x0C
    xor bh, bh
    int 0x10
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.gdi_draw_line:
    push bp
    mov bp, sp
    sub sp, 12

    mov [bp-12], ax

    mov ax, si
    sub ax, cx
    jns .dx_pos
    neg ax
.dx_pos:
    mov [bp-2], ax

    mov word [bp-6], 1
    cmp cx, si
    jl .sx_pos
    mov word [bp-6], -1
.sx_pos:

    mov ax, di
    sub ax, dx
    jns .dy_pos
    neg ax
.dy_pos:
    mov [bp-4], ax

    mov word [bp-8], 1
    cmp dx, di
    jl .sy_pos
    mov word [bp-8], -1
.sy_pos:

    mov bx, [bp-2]
    sub bx, [bp-4]
    mov [bp-10], bx

.loop:
    mov al, byte [bp-12]
    call .gdi_draw_pixel

    cmp cx, si
    jne .not_done
    cmp dx, di
    jne .not_done
    jmp .done_line

.not_done:
    mov bx, [bp-10]
    shl bx, 1

    mov ax, [bp-4]
    neg ax
    cmp bx, ax
    jle .check_y
    
    mov ax, [bp-10]
    sub ax, [bp-4]
    mov [bp-10], ax
    
    mov ax, [bp-6]
    add cx, ax

.check_y:
    mov ax, [bp-2]
    cmp bx, ax
    jge .loop
    
    mov ax, [bp-10]
    add ax, [bp-2]
    mov [bp-10], ax
    
    mov ax, [bp-8]
    add dx, ax
    
    jmp .loop

.done_line:
    mov sp, bp
    pop bp
    ret
