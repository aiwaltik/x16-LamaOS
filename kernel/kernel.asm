[bits 16]
[org 0x0000]

KERNEL_SEG     equ 0x1000
PROG_SEG       equ 0x2000
BUF_SEG        equ 0x3000
USER_SEG       equ 0x4000

%include "lib/lama.inc"

start:
    cli
    mov ax, KERNEL_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    ; Save boot drive from DL
    mov [boot_drive], dl

    ; Init COM1
    mov dx, 0x3F9
    mov al, 0
    out dx, al
    mov dx, 0x3FB
    mov al, 0x80
    out dx, al
    mov dx, 0x3F8
    mov al, 1
    out dx, al
    mov dx, 0x3F9
    mov al, 0
    out dx, al
    mov dx, 0x3FB
    mov al, 0x03
    out dx, al
    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al
    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al

    ; Load BPB values from boot sector (LBA 0)
    mov ax, BUF_SEG
    mov es, ax
    xor bx, bx
    xor ax, ax               ; LBA 0
    mov cx, 1
    call read_sectors_lba

    ; Parse BPB from buffer at ES:0
    mov ax, [es:11]
    mov [bpb_bytes_per_sector], ax
    mov al, [es:13]
    mov [bpb_sectors_per_cluster], al
    mov ax, [es:14]
    mov [bpb_reserved_sectors], ax
    mov al, [es:16]
    mov [bpb_num_fats], al
    mov ax, [es:17]
    mov [bpb_root_entries], ax
    mov ax, [es:22]
    mov [bpb_sectors_per_fat], ax
    mov ax, [es:24]
    mov [bpb_sectors_per_track], ax
    mov ax, [es:26]
    mov [bpb_num_heads], ax

    call compute_fs_layout

    call install_sysint

    ; Make color 7 (BIOS default) bright white
    mov ax, 0x1010
    mov bx, 0x0007
    mov dh, 63
    mov ch, 63
    mov cl, 63
    int 0x10

    mov dx, msg_kernel
    call puts

    ; Exec SHELL.BIN to PROG_SEG
    mov dx, shell_name
    mov bx, PROG_SEG
    call load_83
    jc .shell_nf

    ; Jump to shell
    mov ax, PROG_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    jmp 0x2000:0x0000

.shell_nf:
    mov dx, msg_exec_nf
    call puts

halt:
    cli
    hlt
    jmp halt

; ----------------------------
; INT 60h handler
; ----------------------------
install_sysint:
    push ax
    push ds
    xor ax, ax
    mov ds, ax
    mov word [SYS_INT*4], sysint_handler
    mov word [SYS_INT*4+2], KERNEL_SEG
    pop ds
    pop ax
    ret

sysint_handler:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    mov bp, sp

    sti     ; Enable interrupts so BIOS keyboard works

    push ax
    mov ax, KERNEL_SEG
    mov ds, ax
    pop ax

    cmp ah, SYS_PUTS
    je .puts
    cmp ah, SYS_GETCH
    je .getch
    cmp ah, SYS_CLS
    je .cls
    cmp ah, SYS_PUTCHAR
    je .putchar
    cmp ah, SYS_GET_TIME
    je .get_time
    cmp ah, SYS_GET_DATE
    je .get_date
    cmp ah, SYS_SET_CURSOR
    je .set_cursor
    cmp ah, SYS_GET_CURSOR
    je .get_cursor
    cmp ah, SYS_SET_VIDEO_MODE
    je .set_video_mode
    cmp ah, SYS_DRAW_PIXEL
    je .draw_pixel
    cmp ah, SYS_GET_MEM_SIZE
    je .get_mem_size
    cmp ah, SYS_YIELD
    je .yield
    cmp ah, SYS_LS
    je .ls
    cmp ah, SYS_EXEC
    je .exec
    cmp ah, SYS_EXIT
    je .exit
    cmp ah, SYS_REBOOT
    je .reboot
    cmp ah, SYS_READ_FILE
    je .read_file
    cmp ah, SYS_WRITE_FILE
    je .write_file
    cmp ah, SYS_FILE_SIZE
    je .file_size
    cmp ah, SYS_GET_TICKS
    je .get_ticks
    cmp ah, SYS_PLAY_SOUND
    je .play_sound
    cmp ah, 0x19
    je .create_file
    cmp ah, 0x1A
    je .delete_file
    jmp .done

%include "api/user16.asm"
%include "api/kernel16.asm"
%include "api/gdi16.asm"

.done:
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

; ----------------------------
; Console helpers (BIOS)
; ----------------------------
puts:
    push si
    mov si, dx
    call puts_ds_si
    pop si
    ret

puts_ds_si:
    push ax
    push si
    mov ah, 0x0E
.l:
    lodsb
    test al, al
    jz .d
    call serial_write_char
    int 0x10
    jmp .l
.d:
    pop si
    pop ax
    ret

puts_es_si:
    push ax
    push ds
    push si
    mov ax, es
    mov ds, ax
    mov ah, 0x0E
.l2:
    lodsb
    test al, al
    jz .d2
    call serial_write_char
    int 0x10
    jmp .l2
.d2:
    pop si
    pop ds
    pop ax
    ret

getch:
.poll:
    mov dx, 0x3FD
    in al, dx
    test al, 1
    jz .check_kb
    mov dx, 0x3F8
    in al, dx
    ret
.check_kb:
    mov ah, 0x01
    int 0x16
    jz .poll
    xor ax, ax
    int 0x16
    ret

cls:
    push ax
    push bx
    push cx
    push dx
    mov ax, 0x0600
    mov bh, 0x0F
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    mov ah, 0x02
    xor bh, bh
    xor dx, dx
    int 0x10
    pop dx
    pop cx
    pop bx
    pop ax
    ret

newline:
    push ax
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    pop ax
    ret

; ----------------------------
; FAT12 helpers (root dir + file load)
; ----------------------------
compute_fs_layout:
    ; root_start = reserved + (num_fats * sectors_per_fat)
    mov al, [bpb_num_fats]
    xor ah, ah
    mul word [bpb_sectors_per_fat]
    add ax, [bpb_reserved_sectors]
    mov [root_start], ax

    ; root_size = ceil(root_entries*32 / bytes_per_sector)
    mov ax, 32
    mul word [bpb_root_entries]
    add ax, [bpb_bytes_per_sector]
    dec ax
    xor dx, dx
    div word [bpb_bytes_per_sector]
    mov [root_size], ax

    ; data_sector = root_start + root_size
    mov ax, [root_start]
    add ax, [root_size]
    mov [data_sector], ax
    ret

read_root:
    ; read root dir into BUF_SEG:0x2000
    push ax
    push bx
    push cx
    push es
    mov ax, BUF_SEG
    mov es, ax
    mov bx, 0x2000
    mov ax, [root_start]
    mov cx, [root_size]
    call read_sectors_lba
    pop es
    pop cx
    pop bx
    pop ax
    ret

read_fat:
    ; read FAT1 into BUF_SEG:0x0000
    push ax
    push bx
    push cx
    push es
    mov ax, BUF_SEG
    mov es, ax
    xor bx, bx
    mov ax, [bpb_reserved_sectors]
    mov cx, [bpb_sectors_per_fat]
    call read_sectors_lba
    pop es
    pop cx
    pop bx
    pop ax
    ret

list_root:
    call read_root
    call read_fat

    mov ax, KERNEL_SEG
    mov ds, ax
    mov word [file_count], 0
    mov word [total_size_low], 0
    mov word [total_size_high], 0
    mov byte [col_count], 0

    mov dx, msg_dir_header
    call puts

    mov cx, [bpb_root_entries]
    mov ax, BUF_SEG
    mov es, ax
    mov si, 0x2000
.next:
    mov al, [es:si]
    cmp al, 0x00
    je .done_ls
    cmp al, 0xE5
    je .skip
    mov al, [es:si+11]
    test al, 0x08
    jnz .skip
    
    push cx
    push si

    mov cx, 8
    xor bx, bx
.pn:
    mov al, [es:si+bx]
    inc bx
    call putchar
    loop .pn

    mov al, ' '
    call putchar

    mov cx, 3
.pe:
    mov al, [es:si+bx]
    inc bx
    call putchar
    loop .pe

    mov al, ' '
    call putchar
    call putchar

    mov al, [es:si+11]
    test al, 0x10
    jz .isfile

.isdir:
    push si
    mov si, msg_dir_tag
.dir_tag_loop:
    lodsb
    test al, al
    jz .dir_tag_done
    mov bl, 0x0B
    call putchar_color
    jmp .dir_tag_loop
.dir_tag_done:
    pop si
    jmp .enditem

.isfile:
    mov ax, [es:si+28]
    mov dx, [es:si+30]
    add [total_size_low], ax
    adc [total_size_high], dx
    inc word [file_count]

    call print_32_padded

.enditem:
    pop si
    pop cx

    mov al, ' '
    call putchar
    call putchar

    inc byte [col_count]
    cmp byte [col_count], 3
    jne .skip
    mov byte [col_count], 0
    mov dx, crlf
    call puts

.skip:
    add si, 32
    dec cx
    jnz .next

.done_ls:
    cmp byte [col_count], 0
    je .done_nl
    mov dx, crlf
    call puts
.done_nl:
    mov dx, crlf
    call puts

    mov ax, [file_count]
    xor dx, dx
    call print_32_left
    mov dx, msg_files
    call puts

    mov ax, [total_size_low]
    mov dx, [total_size_high]
    mov cx, 10
.shr_loop:
    shr dx, 1
    rcr ax, 1
    loop .shr_loop

    call print_32_left
    mov dx, msg_kb
    call puts
    
    mov dx, crlf
    call puts
    call puts

    call count_free_clusters
    shr ax, 1
    xor dx, dx
    call print_32_left
    mov dx, msg_kb_free
    call puts
    mov dx, crlf
    call puts
    mov dx, crlf
    call puts

    mov ax, KERNEL_SEG
    mov ds, ax
    ret

serial_write_char:
    push dx
    push ax
    mov ah, al
.wait_tx:
    mov dx, 0x3FD
    in al, dx
    test al, 0x20
    jz .wait_tx
    mov al, ah
    mov dx, 0x3F8
    out dx, al
    pop ax
    pop dx
    ret

putchar:
    push ax
    push bx
    push cx
    call serial_write_char
    
    cmp al, 0x20
    jb .skip_attr
    
    mov cl, al ; save char
    
    mov ah, 0x08
    mov bh, 0
    int 0x10
    
    test ah, 0xF0
    jnz .use_existing
    
    mov ah, 0x0F
.use_existing:
    mov bl, ah
    mov al, cl
    mov ah, 0x09
    push cx
    mov cx, 1
    int 0x10
    pop cx
    mov al, cl
    
.skip_attr:
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    
    pop cx
    pop bx
    pop ax
    ret

putchar_color:
    push ax
    push bx
    push cx
    push dx
    call serial_write_char
    mov ah, 0x03
    xor bh, bh
    int 0x10

    mov ah, 0x09
    mov cx, 1
    int 0x10

    inc dl
    cmp dl, 80
    jl .set_cur
    mov dl, 0
    inc dh
.set_cur:
    mov ah, 0x02
    xor bh, bh
    int 0x10

    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_32_padded:
    call print_32_left_count
    mov di, 8
    sub di, cx
.pad:
    test di, di
    jle .done_pad
    mov al, ' '
    call putchar
    dec di
    jmp .pad
.done_pad:
    ret

print_32_left:
    call print_32_left_count
    ret

print_32_left_count:
    mov cx, 0
.loop_p:
    mov bx, 10
    mov si, ax
    mov ax, dx
    xor dx, dx
    div bx
    mov di, ax
    mov ax, si
    div bx
    push dx
    mov dx, di
    inc cx
    mov bx, ax
    or bx, dx
    jnz .loop_p
    
    mov dx, cx
.print_digits:
    pop ax
    add al, '0'
    mov bl, 0x0B
    call putchar_color
    loop .print_digits
    mov cx, dx
    ret

count_free_clusters:
    mov cx, 2880 - 2
    mov bx, 2
    xor di, di
.loop_c:
    mov ax, bx
    call fat12_next
    cmp ax, 0x000
    jne .not_free
    inc di
.not_free:
    inc bx
    loop .loop_c
    mov ax, di
    ret

; load_83: DX -> 11-byte 8.3 name in kernel DS, BX -> target segment
load_83:
    call read_root
    call read_fat

    ; find entry
    mov cx, [bpb_root_entries]
    push ds
    mov ax, BUF_SEG
    mov ds, ax
    mov di, 0x2000
.s:
    cmp byte [di], 0x00
    je .nf
    cmp byte [di], 0xE5
    je .cont
    push cx
    push di
    mov si, di
    mov di, dx
    push ds
    mov ax, KERNEL_SEG
    mov es, ax
    mov cx, 11
    cld
    repe cmpsb
    pop ds
    pop di
    pop cx
    je .found
    jmp .cont2
.cont2:
    add di, 32
    loop .s
    jmp .nf
.cont:
    add di, 32
    loop .s
    jmp .nf

.found:
    ; DS=BUF_SEG, DI -> directory entry
    mov ax, [di + 0x1A]      ; first cluster
    pop ds                   ; RESTORE KERNEL DS BEFORE WRITING
    mov [cur_cluster], ax

    ; Load file clusters to BX:0
    mov es, bx
    xor bx, bx
.lc:
    mov ax, [cur_cluster]
    cmp ax, 0xFF8
    jae .done_load

    ; LBA = data_sector + (cluster-2)*spc
    mov ax, [cur_cluster]
    sub ax, 2
    xor cx, cx
    mov cl, [bpb_sectors_per_cluster]
    mul cx
    add ax, [data_sector]
    mov cx, 1
    call read_sectors_lba

    ; advance ES by 512 bytes
    mov ax, es
    add ax, 0x0020
    mov es, ax

    mov ax, [cur_cluster]
    call fat12_next
    mov [cur_cluster], ax
    jmp .lc

.done_load:
    clc
    ret

.nf:
    pop ds
    stc
    ret

; write_83_sector: DX -> 11-byte 8.3 name in kernel DS, ES:BX -> buffer, CX -> size
write_83_sector:
    push cx ; save size
    call read_root
    call read_fat

    mov cx, [bpb_root_entries]
    push ds
    mov ax, BUF_SEG
    mov ds, ax
    mov di, 0x2000
.ws:
    cmp byte [di], 0x00
    je .wnf
    cmp byte [di], 0xE5
    je .wcont
    push cx
    push di
    mov si, di
    mov di, dx
    push ds
    mov ax, KERNEL_SEG
    mov es, ax
    mov cx, 11
    cld
    repe cmpsb
    pop ds
    pop di
    pop cx
    je .wfound
    jmp .wcont2
.wcont2:
    add di, 32
    loop .ws
    jmp .wnf
.wcont:
    add di, 32
    loop .ws
    jmp .wnf

.wfound:
    mov ax, [di + 0x1A] ; cluster
    
    ; update size
    pop dx ; pop ds into dx (dx = KERNEL_SEG)
    pop cx ; restore size
    
    mov word [di + 28], cx
    mov word [di + 30], 0
    
    mov ds, dx ; restore KERNEL_SEG
    push es
    mov cx, BUF_SEG
    mov es, cx
    mov bx, 0x2000
    mov cx, [root_size]
    push ax
    mov ax, [root_start]
    call write_sectors_lba
    pop ax
    pop es
    jmp .w_calc_lba

.w_calc_lba:
    sub ax, 2
    xor cx, cx
    mov cl, [bpb_sectors_per_cluster]
    mul cx
    add ax, [data_sector]

    ; Restore ES and BX from caller
    mov es, [bp + 0]
    mov bx, [bp + 14]

    mov cx, 1
    call write_sectors_lba
    clc
    ret

.wnf:
    pop ds
    pop cx ; discard size
    stc
    ret

; get_file_size: DX -> 11-byte 8.3 name in kernel DS
; returns DX:AX size, CF set if not found
get_file_size:
    call read_root
    call read_fat

    mov cx, [bpb_root_entries]
    push ds
    mov ax, BUF_SEG
    mov ds, ax
    mov di, 0x2000
.fs_s:
    cmp byte [di], 0x00
    je .fs_nf
    cmp byte [di], 0xE5
    je .fs_cont
    push cx
    push di
    mov si, di
    mov di, dx
    push ds
    mov ax, KERNEL_SEG
    mov es, ax
    mov cx, 11
    cld
    repe cmpsb
    pop ds
    pop di
    pop cx
    je .fs_found
    jmp .fs_cont2
.fs_cont2:
    add di, 32
    loop .fs_s
    jmp .fs_nf
.fs_cont:
    add di, 32
    loop .fs_s
    jmp .fs_nf

.fs_found:
    mov ax, [di + 28] ; low 16 bits of size
    mov dx, [di + 30] ; high 16 bits of size
    pop ds
    clc
    ret
.fs_nf:
    pop ds
    stc
    ret

; FAT12 next cluster: AX=current -> AX=next (uses BUF_SEG FAT at 0)
fat12_next:
    push bx
    push dx
    push ds
    mov bx, ax
    mov ax, BUF_SEG
    mov ds, ax

    ; offset = cluster * 3 / 2
    mov ax, bx
    shl ax, 1
    add ax, bx
    shr ax, 1
    mov si, ax

    mov ax, [si]
    test bl, 1
    jz .even
    shr ax, 4
    jmp .done
.even:
    and ax, 0x0FFF
.done:
    pop ds
    pop dx
    pop bx
    ret

; FAT12 set cluster: AX=cluster, CX=value (uses BUF_SEG FAT at 0)
fat12_set:
    push bx
    push dx
    push ds
    mov bx, ax
    mov ax, BUF_SEG
    mov ds, ax

    ; offset = cluster * 3 / 2
    mov ax, bx
    shl ax, 1
    add ax, bx
    shr ax, 1
    mov si, ax

    mov dx, [si]
    test bl, 1
    jz .even_s
    ; odd: keep low 4 bits of DX, set high 12 bits to CX
    and dx, 0x000F
    mov ax, cx
    shl ax, 4
    or dx, ax
    jmp .done_s
.even_s:
    ; even: keep high 4 bits of DX, set low 12 bits to CX
    and dx, 0xF000
    and cx, 0x0FFF
    or dx, cx
.done_s:
    mov [si], dx
    pop ds
    pop dx
    pop bx
    ret

; create_file: DX -> 11-byte 8.3 name in kernel DS
; returns CF=1 on error
create_file:
    call read_root
    call read_fat

    ; 1. Check if exists
    mov cx, [bpb_root_entries]
    push ds
    mov ax, BUF_SEG
    mov ds, ax
    mov di, 0x2000
.cf_check:
    cmp byte [di], 0x00
    je .cf_not_exists
    cmp byte [di], 0xE5
    je .cf_cont
    push cx
    push di
    mov si, di
    mov di, dx
    push ds
    mov ax, KERNEL_SEG
    mov es, ax
    mov cx, 11
    cld
    repe cmpsb
    pop ds
    pop di
    pop cx
    je .cf_exists
.cf_cont:
    add di, 32
    loop .cf_check

.cf_not_exists:
    ; 2. Find empty root entry
    mov cx, [bpb_root_entries]
    mov di, 0x2000
.cf_find_root:
    cmp byte [di], 0x00
    je .cf_found_root
    cmp byte [di], 0xE5
    je .cf_found_root
    add di, 32
    loop .cf_find_root
    jmp .cf_err

.cf_found_root:
    push di ; save root entry offset

    ; 3. Find free FAT entry
    mov cx, 2880 - 2
    mov bx, 2
.cf_find_fat:
    mov ax, bx
    call fat12_next
    cmp ax, 0x000
    je .cf_found_fat
    inc bx
    loop .cf_find_fat
    pop di
    jmp .cf_err

.cf_found_fat:
    ; bx is the free cluster
    ; 4. Update FAT entry to 0xFFF
    mov ax, bx
    mov cx, 0xFFF
    call fat12_set

    ; 5. Update root dir entry
    pop di ; restore root entry offset
    ; copy name
    push ds
    mov ax, KERNEL_SEG
    mov ds, ax
    mov si, dx
    mov ax, BUF_SEG
    mov es, ax
    mov cx, 11
    cld
    push di
    rep movsb
    pop di
    pop ds
    ; set attr, etc
    mov byte [di+11], 0 ; attr
    mov word [di+26], bx ; cluster
    mov word [di+28], 0 ; size low
    mov word [di+30], 0 ; size high

    ; 6. Write FAT back
    pop ds ; restore KERNEL_SEG
    push es
    mov ax, BUF_SEG
    mov es, ax
    xor bx, bx
    mov ax, [bpb_reserved_sectors]
    mov cx, [bpb_sectors_per_fat]
    call write_sectors_lba

    ; 7. Write Root Dir back
    mov bx, 0x2000
    mov ax, [root_start]
    mov cx, [root_size]
    call write_sectors_lba
    pop es

    clc
    ret

.cf_exists:
.cf_err:
    pop ds
    stc
    ret

; delete_file: DX -> 11-byte 8.3 name in kernel DS
; returns CF=1 on error
delete_file:
    call read_root
    call read_fat

    mov cx, [bpb_root_entries]
    push ds
    mov ax, BUF_SEG
    mov ds, ax
    mov di, 0x2000
.df_check:
    cmp byte [di], 0x00
    je .df_nf
    cmp byte [di], 0xE5
    je .df_cont
    push cx
    push di
    mov si, di
    mov di, dx
    push ds
    mov ax, KERNEL_SEG
    mov es, ax
    mov cx, 11
    cld
    repe cmpsb
    pop ds
    pop di
    pop cx
    je .df_found
.df_cont:
    add di, 32
    loop .df_check
.df_nf:
    pop ds
    stc
    ret

.df_found:
    ; 1. Mark root entry as deleted
    mov byte [di], 0xE5
    ; 2. Free clusters
    mov bx, [di+26] ; starting cluster
.df_free_loop:
    cmp bx, 0x000
    je .df_done_free
    cmp bx, 0xFF8
    jae .df_done_free
    mov ax, bx
    call fat12_next
    push ax ; save next cluster
    mov ax, bx
    mov cx, 0x000
    call fat12_set
    pop bx
    jmp .df_free_loop
.df_done_free:
    ; 3. Write FAT back
    pop ds ; restore KERNEL_SEG
    push es
    mov ax, BUF_SEG
    mov es, ax
    xor bx, bx
    mov ax, [bpb_reserved_sectors]
    mov cx, [bpb_sectors_per_fat]
    call write_sectors_lba

    ; 4. Write Root Dir back
    mov bx, 0x2000
    mov ax, [root_start]
    mov cx, [root_size]
    call write_sectors_lba
    pop es

    clc
    ret

; ----------------------------
; Disk read (LBA -> CHS) using BIOS INT 13h
; Inputs: AX=LBA, CX=count, ES:BX=dest
; Uses boot_drive, bpb_sectors_per_track, bpb_num_heads
; ----------------------------
read_sectors_lba:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, ax         ; lba
    mov di, cx         ; count
.loop:
    mov ax, si
    xor dx, dx
    div word [bpb_sectors_per_track]
    inc dx
    mov cx, dx         ; sector (1-based)
    xor dx, dx
    div word [bpb_num_heads]
    mov dh, dl         ; head
    mov ch, al         ; cylinder low
    shl ah, 6
    or cl, ah

    mov dl, [boot_drive]
    mov ax, 0x0201
    int 0x13
    jc .err

    add bx, [bpb_bytes_per_sector]
    inc si
    dec di
    jnz .loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.err:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov dx, msg_disk
    call puts
    jmp $

write_sectors_lba:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, ax         ; lba
    mov di, cx         ; count
.loop_w:
    mov ax, si
    xor dx, dx
    div word [bpb_sectors_per_track]
    inc dx
    mov cx, dx         ; sector (1-based)
    xor dx, dx
    div word [bpb_num_heads]
    mov dh, dl         ; head
    mov ch, al         ; cylinder low
    shl ah, 6
    or cl, ah

    mov dl, [boot_drive]
    mov ax, 0x0301     ; WRITE
    int 0x13
    jc .err_w

    add bx, [bpb_bytes_per_sector]
    inc si
    dec di
    jnz .loop_w

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.err_w:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov dx, msg_disk
    call puts
    jmp $

; ----------------------------
; Data
; ----------------------------
boot_drive: db 0

bpb_bytes_per_sector: dw 512
bpb_sectors_per_cluster: db 1
bpb_reserved_sectors: dw 1
bpb_num_fats: db 2
bpb_root_entries: dw 224
bpb_sectors_per_fat: dw 9
bpb_sectors_per_track: dw 18
bpb_num_heads: dw 2

root_start: dw 0
root_size:  dw 0
data_sector: dw 0

cur_cluster: dw 0
prog_exit_flag: db 0

shell_name: db 'SHELL   BIN'
tmp_name:   times 11 db 0

line_buf:   times 32 db 0

msg_kernel:  db 'LamaOS kernel ready. Starting shell...',0
msg_run:     db 'Jumping to program...',0
msg_exec_nf: db 'Program not found',0
msg_disk:    db 'Disk read error',0
msg_dir_header db 0x0D, 0x0A, 'A:/', 0x0D, 0x0A, 0x0D, 0x0A, 0
msg_dir_tag    db '<DIR>   ', 0
msg_files      db ' files    ', 0
msg_kb         db ' KB', 0
msg_kb_free    db ' KB free', 0

file_count      dw 0
total_size_low  dw 0
total_size_high dw 0
col_count       db 0
crlf            db 0x0D, 0x0A, 0

