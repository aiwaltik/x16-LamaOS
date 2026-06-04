.get_time:
    mov ah, 0x02
    int 0x1A
    mov [bp + 12], cx ; saved CX
    mov [bp + 10], dx ; saved DX
    jmp .done

.get_date:
    mov ah, 0x04
    int 0x1A
    mov [bp + 12], cx ; saved CX
    mov [bp + 10], dx ; saved DX
    jmp .done

.get_mem_size:
    int 0x12
    mov [bp + 16], ax ; return in AX
    jmp .done

.yield:
    hlt
    jmp .done

.ls:
    call list_root
    jmp .done

.exec:
    ; caller DS:DX -> 8.3 name
    push ds
    push es
    mov ax, KERNEL_SEG
    mov es, ax
    mov di, tmp_name
    mov cx, 11
    mov ds, [bp + 2]   ; caller DS
    mov si, dx
    cld
    rep movsb          ; DS:SI -> ES:DI
    pop es
    pop ds

    mov dx, tmp_name
    mov bx, USER_SEG
    call load_83
    jc .exec_fail

    ; clear CF in saved flags at [bp+22]
    mov ax, [bp + 22]
    and ax, 0xFFFE
    mov [bp + 22], ax
    jmp .done

.exec_fail:
    ; set CF in saved flags
    mov ax, [bp + 22]
    or ax, 0x0001
    mov [bp + 22], ax
    jmp .done

.read_file:
    ; DS:DX -> 8.3 name, CX -> target segment
    push ds
    push es
    mov ax, KERNEL_SEG
    mov es, ax
    mov di, tmp_name
    mov cx, 11
    mov ds, [bp + 2]
    mov si, dx
    cld
    rep movsb
    pop es
    pop ds

    mov dx, tmp_name
    mov bx, [bp + 12]  ; CX
    call load_83
    jc .read_fail
    mov ax, [bp + 22]
    and ax, 0xFFFE
    mov [bp + 22], ax
    jmp .done
.read_fail:
    mov ax, [bp + 22]
    or ax, 0x0001
    mov [bp + 22], ax
    jmp .done

.write_file:
    ; DS:DX -> 8.3 name, ES:BX -> buffer (1 sector), CX -> size
    push ds
    push es
    mov ax, KERNEL_SEG
    mov es, ax
    mov di, tmp_name
    mov cx, 11
    mov ds, [bp + 2]
    mov si, dx
    cld
    rep movsb
    pop es
    pop ds

    mov dx, tmp_name
    mov es, [bp + 0]   ; saved ES
    mov bx, [bp + 14]  ; saved BX
    mov cx, [bp + 12]  ; saved CX
    call write_83_sector
    jc .write_fail
    mov ax, [bp + 22]
    and ax, 0xFFFE
    mov [bp + 22], ax
    jmp .done
.write_fail:
    mov ax, [bp + 22]
    or ax, 0x0001
    mov [bp + 22], ax
    jmp .done

.reboot:
    ; far jump to reset vector
    jmp 0xFFFF:0x0000

.shutdown:
    ; Try APM shutdown
    mov ax, 0x5301
    xor bx, bx
    int 0x15
    
    mov ax, 0x530E
    xor bx, bx
    mov cx, 0x0102
    int 0x15
    
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15

    ; If APM fails, try emulator-specific I/O ports
    mov ax, 0x2000
    mov dx, 0x604
    out dx, ax
    
    mov ax, 0x2000
    mov dx, 0xB004
    out dx, ax
    
.halt:
    cli
    hlt
    jmp .halt

.file_size:
    ; DS:DX -> 8.3 name
    push ds
    push es
    mov ax, KERNEL_SEG
    mov es, ax
    mov di, tmp_name
    mov cx, 11
    mov ds, [bp + 2]
    mov si, [bp + 10] ; saved DX
    cld
    rep movsb
    pop es
    pop ds

    mov dx, tmp_name
    call get_file_size
    jc .fsize_fail
    ; returns DX:AX size
    mov [bp + 10], dx ; saved DX
    mov [bp + 16], ax ; saved AX
    mov ax, [bp + 22]
    and ax, 0xFFFE
    mov [bp + 22], ax
    jmp .done
.fsize_fail:
    mov ax, [bp + 22]
    or ax, 0x0001
    mov [bp + 22], ax
    jmp .done

.create_file:
    push ds
    push es
    mov ax, KERNEL_SEG
    mov es, ax
    mov di, tmp_name
    mov cx, 11
    mov ds, [bp + 2]
    mov si, dx
    cld
    rep movsb
    pop es
    pop ds

    mov dx, tmp_name
    call create_file
    jc .cf_fail_api
    mov ax, [bp + 22]
    and ax, 0xFFFE
    mov [bp + 22], ax
    jmp .done
.cf_fail_api:
    mov ax, [bp + 22]
    or ax, 0x0001
    mov [bp + 22], ax
    jmp .done

.delete_file:
    push ds
    push es
    mov ax, KERNEL_SEG
    mov es, ax
    mov di, tmp_name
    mov cx, 11
    mov ds, [bp + 2]
    mov si, dx
    cld
    rep movsb
    pop es
    pop ds

    mov dx, tmp_name
    call delete_file
    jc .df_fail_api
    mov ax, [bp + 22]
    and ax, 0xFFFE
    mov [bp + 22], ax
    jmp .done
.df_fail_api:
    mov ax, [bp + 22]
    or ax, 0x0001
    mov [bp + 22], ax
    jmp .done

.get_ticks:
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov ax, [0x006C]
    mov dx, [0x006E]
    pop ds
    mov [bp + 16], ax ; low
    mov [bp + 10], dx ; high
    jmp .done

.exit:
    ; Deprecated, do nothing
    jmp .done
