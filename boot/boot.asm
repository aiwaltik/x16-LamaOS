[bits 16]
[org 0x7C00]

; FAT12 BPB
jmp short start
nop

bpb_oem:                db 'MYOS    '
bpb_bytes_per_sector:   dw 512
bpb_sectors_per_cluster:db 1
bpb_reserved_sectors:   dw 1
bpb_num_fats:           db 2
bpb_root_entries:       dw 224
bpb_total_sectors:      dw 2880
bpb_media_descriptor:   db 0xF0
bpb_sectors_per_fat:    dw 9
bpb_sectors_per_track:  dw 18
bpb_num_heads:          dw 2
bpb_hidden_sectors:     dd 0
bpb_large_sectors:      dd 0

; Extended BPB
ebs_drive_number:       db 0
ebs_reserved:           db 0
ebs_signature:          db 0x29
ebs_volume_id:          dd 0x12345678
ebs_volume_label:       db 'MYOS       '
ebs_filesystem:         db 'FAT12   '

; Bootloader
start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    ; temporary stack
    mov sp, 0x7C00
    mov [ebs_drive_number], dl

    mov si, msg_loading
    call print_string

    mov al, [bpb_num_fats]
    xor ah, ah
    mul word [bpb_sectors_per_fat]
    add ax, [bpb_reserved_sectors]
    mov [root_start], ax

    mov ax, 32
    mul word [bpb_root_entries]
    add ax, [bpb_bytes_per_sector]
    dec ax
    xor dx, dx
    div word [bpb_bytes_per_sector]
    mov [root_size], ax

    mov bx, 0x7E00
    mov ax, [root_start]
    mov cx, [root_size]
    call read_sectors

    mov cx, [bpb_root_entries]
    mov di, 0x7E00
.search_loop:
    push cx
    mov cx, 11
    mov si, kernel_name
    push di
    repe cmpsb
    pop di
    je .found_file
    pop cx
    add di, 32
    loop .search_loop

    mov si, msg_not_found
    call print_string
    jmp $

.found_file:
    pop cx
    mov ax, [di + 0x1A]
    mov [cluster], ax

    mov ax, [bpb_reserved_sectors]
    mov bx, 0x2000
    mov es, bx
    xor bx, bx
    mov cx, [bpb_sectors_per_fat]
    call read_sectors

    mov ax, [root_start]
    add ax, [root_size]
    mov [data_sector], ax

    mov ax, 0x1000  
    mov es, ax
    xor bx, bx
.load_cluster:
    ; LBA = data_sector + (cluster - 2) * sectors_per_cluster
    mov ax, [cluster]
    sub ax, 2
    xor cx, cx
    mov cl, [bpb_sectors_per_cluster]
    mul cx
    add ax, [data_sector]
    mov cx, 1
    call read_sectors

    mov ax, es
    add ax, 0x0020
    mov es, ax

    mov ax, [cluster]
    call get_next_cluster
    mov [cluster], ax
    cmp ax, 0xFF8
    jb .load_cluster

    mov si, msg_success
    call print_string
    
    ; Pass the boot drive to the kernel in DL
    mov dl, [ebs_drive_number]
    
    jmp 0x1000:0x0000

read_sectors:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, ax          ; LBA
    mov di, cx          ; count
.read_loop:
    mov ax, si
    xor dx, dx
    div word [bpb_sectors_per_track]
    inc dx
    mov cx, dx          ; sector
    xor dx, dx
    div word [bpb_num_heads]
    mov dh, dl          ; head
    mov ch, al          ; cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah           ; sector + upper bits of cylinder

    mov dl, [ebs_drive_number]
    mov ax, 0x0201
    int 0x13
    jc .disk_error

    add bx, [bpb_bytes_per_sector]
    inc si
    dec di
    jnz .read_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.disk_error:
    mov si, msg_disk_error
    call print_string
    jmp $

get_next_cluster:
    push bx
    push cx
    push dx
    push si
    push ds

    push ax
    mov bx, 0x2000
    mov ds, bx
    pop bx              ; bx = current cluster

    mov ax, bx
    shl ax, 1
    add ax, bx
    shr ax, 1
    mov si, ax

    mov ax, [si]

    test bl, 1
    jz .even
.odd:
    shr ax, 4
    jmp .done
.even:
    and ax, 0x0FFF
.done:
    pop ds
    pop si
    pop dx
    pop cx
    pop bx
    ret

print_string:
    push ax
    push si
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

msg_loading:        db 'Loading OS...', 0x0D, 0x0A, 0
msg_not_found:      db 'Kernel not found!', 0x0D, 0x0A, 0
msg_disk_error:     db 'Disk error!', 0x0D, 0x0A, 0
msg_success:        db 'Kernel loaded, jumping...', 0x0D, 0x0A, 0
kernel_name:        db 'KERNEL  BIN'

root_start:         dw 0
root_size:          dw 0
data_sector:        dw 0
cluster:            dw 0

times 510-($-$$) db 0
dw 0xAA55