[bits 16]
[org 0x0000]

%include "lib/lama.inc"

LEX_HEADER

_start:
    PRINT "File to edit: "
    INPUT filename_buf, 12
    PRINTLN

    mov si, filename_buf
    call to_83_name
    jc .bad_name

    ; Try to get file size
    FILE_SIZE name83
    jc .new_file
    ; File exists, check size
    cmp ax, 512
    ja .too_big
    mov [file_size], ax
    ; Read file
    READ_FILE name83, 0x5000
    jc .err_io
    jmp .editor_loop

.new_file:
    mov word [file_size], 0
    jmp .editor_loop

.too_big:
    PRINTLN "File too big (max 512 bytes)"
    retf

.err_io:
    PRINTLN "I/O Error"
    retf

.bad_name:
    PRINTLN "Invalid filename"
    retf

.editor_loop:
    call draw_screen

.wait_key:
    GETCH
    cmp al, 0x1B ; ESC
    je .open_menu
    cmp al, 0x7F ; Ctrl+Backspace
    je .ctrl_backspace
    cmp al, 0x08 ; Backspace
    je .do_backspace
    cmp al, 0x0D ; Enter
    je .do_enter
    cmp al, 0x09 ; Tab
    je .do_tab
    cmp al, 0x00 ; Extended key
    je .do_extended

    ; Normal char
    cmp al, 0x20
    jb .wait_key
    call insert_char
    jmp .editor_loop

.do_tab:
    mov al, ' '
    call insert_char
    call insert_char
    call insert_char
    call insert_char
    jmp .editor_loop

.open_menu:
    MENU main_menu
    cmp ax, 0
    je .do_save
    cmp ax, 1
    je .do_exit
    ; cancel or ESC
    jmp .editor_loop
    
.do_save:
    call save_file
    jmp .editor_loop
    
.do_exit:
    CLS
    retf

.do_enter:
    mov cx, [file_size]
    cmp cx, 510
    jae .wait_key
    mov al, 0x0D
    call insert_char
    mov al, 0x0A
    call insert_char
    jmp .editor_loop

.do_backspace:
    cmp word [cursor_idx], 0
    je .wait_key
    
    ; Check if previous char is 0x0A, then we should delete 0x0D as well
    push ds
    mov ax, 0x5000
    mov ds, ax
    mov bx, [cs:cursor_idx]
    dec bx
    mov al, [bx]
    pop ds
    cmp al, 0x0A
    je .do_backspace_crlf
    
    ; Delete 1 char
    call delete_char
    jmp .editor_loop

.do_backspace_crlf:
    call delete_char
    call delete_char
    jmp .editor_loop

.do_extended:
    cmp ah, 0x4B ; Left
    je .move_left
    cmp ah, 0x4D ; Right
    je .move_right
    cmp ah, 0x48 ; Up
    je .move_up
    cmp ah, 0x50 ; Down
    je .move_down
    cmp ah, 0x73 ; Ctrl+Left
    je .ctrl_left
    cmp ah, 0x74 ; Ctrl+Right
    je .ctrl_right
    cmp ah, 0x3C ; F2
    je .do_save
    cmp ah, 0x3D ; F3
    je .do_exit
    jmp .wait_key

.move_left:
    cmp word [cursor_idx], 0
    je .wait_key
    dec word [cursor_idx]
    
    ; Skip 0x0A if we hit it (move past CRLF)
    push ds
    mov ax, 0x5000
    mov ds, ax
    mov bx, [cs:cursor_idx]
    mov al, [bx]
    pop ds
    cmp al, 0x0A
    jne .editor_loop
    cmp word [cursor_idx], 0
    je .editor_loop
    dec word [cursor_idx]
    jmp .editor_loop

.move_right:
    mov ax, [file_size]
    cmp [cursor_idx], ax
    jae .wait_key
    inc word [cursor_idx]
    
    ; Skip 0x0D if we hit it (move past CRLF)
    push ds
    mov ax, 0x5000
    mov ds, ax
    mov bx, [cs:cursor_idx]
    dec bx
    mov al, [bx]
    pop ds
    cmp al, 0x0D
    jne .editor_loop
    mov ax, [file_size]
    cmp [cursor_idx], ax
    jae .editor_loop
    inc word [cursor_idx]
    jmp .editor_loop

.move_up:
    cmp byte [cursor_row], 1
    jbe .wait_key
    mov dh, [cursor_row]
    dec dh
    mov dl, [cursor_col]
    call find_idx_by_row_col
    mov [cursor_idx], ax
    jmp .editor_loop

.move_down:
    mov dh, [cursor_row]
    inc dh
    mov dl, [cursor_col]
    call find_idx_by_row_col
    mov [cursor_idx], ax
    jmp .editor_loop

.ctrl_left:
    cmp word [cursor_idx], 0
    je .wait_key
    push es
    mov ax, 0x5000
    mov es, ax
.cl_skip_spaces:
    cmp word [cursor_idx], 0
    je .cl_done
    mov bx, [cursor_idx]
    dec bx
    mov al, [es:bx]
    cmp al, ' '
    jne .cl_skip_word
    dec word [cursor_idx]
    jmp .cl_skip_spaces
.cl_skip_word:
    cmp word [cursor_idx], 0
    je .cl_done
    mov bx, [cursor_idx]
    dec bx
    mov al, [es:bx]
    cmp al, ' '
    je .cl_done
    cmp al, 0x0A
    je .cl_done
    cmp al, 0x0D
    je .cl_done
    dec word [cursor_idx]
    jmp .cl_skip_word
.cl_done:
    pop es
    jmp .editor_loop

.ctrl_right:
    mov ax, [file_size]
    cmp [cursor_idx], ax
    jae .wait_key
    push es
    mov dx, 0x5000
    mov es, dx
.cr_skip_word:
    mov ax, [file_size]
    cmp [cursor_idx], ax
    jae .cr_done
    mov bx, [cursor_idx]
    mov al, [es:bx]
    cmp al, ' '
    je .cr_skip_spaces
    cmp al, 0x0A
    je .cr_skip_spaces
    cmp al, 0x0D
    je .cr_skip_spaces
    inc word [cursor_idx]
    jmp .cr_skip_word
.cr_skip_spaces:
    mov ax, [file_size]
    cmp [cursor_idx], ax
    jae .cr_done
    mov bx, [cursor_idx]
    mov al, [es:bx]
    cmp al, ' '
    jne .cr_done
    inc word [cursor_idx]
    jmp .cr_skip_spaces
.cr_done:
    pop es
    jmp .editor_loop

.ctrl_backspace:
    cmp word [cursor_idx], 0
    je .wait_key
    push es
    mov ax, 0x5000
    mov es, ax
.cb_skip_spaces:
    cmp word [cursor_idx], 0
    je .cb_done
    mov bx, [cursor_idx]
    dec bx
    mov al, [es:bx]
    cmp al, ' '
    jne .cb_skip_word
    call delete_char
    jmp .cb_skip_spaces
.cb_skip_word:
    cmp word [cursor_idx], 0
    je .cb_done
    mov bx, [cursor_idx]
    dec bx
    mov al, [es:bx]
    cmp al, ' '
    je .cb_done
    cmp al, 0x0A
    je .cb_done
    cmp al, 0x0D
    je .cb_done
    call delete_char
    jmp .cb_skip_word
.cb_done:
    pop es
    jmp .editor_loop

find_idx_by_row_col:
    push ds
    push bx
    push cx
    push si
    mov ax, 0x5000
    mov ds, ax
    mov bx, 0
    
    mov ch, 1 ; current row
    mov cl, 0 ; current col
    mov word [cs:tmp_idx], 0
.find_loop:
    mov [cs:tmp_idx], bx
    
    cmp bx, [cs:file_size]
    je .ret_idx
    
    cmp ch, dh
    jne .not_target_row
    cmp cl, dl
    jae .ret_idx
.not_target_row:
    
    mov al, [bx]
    inc bx
    
    cmp al, 0x0D
    je .find_loop
    cmp al, 0x0A
    je .find_nl
    
    inc cl
    cmp cl, 80
    jne .find_loop
    mov cl, 0
    inc ch
    jmp .find_loop
.find_nl:
    cmp ch, dh
    je .ret_idx
    mov cl, 0
    inc ch
    jmp .find_loop
    
.ret_idx:
    mov ax, [cs:tmp_idx]
    pop si
    pop cx
    pop bx
    pop ds
    ret

save_file:
    CREATE_FILE name83
    
    push es
    mov ax, 0x5000
    mov es, ax
    mov bx, 0
    mov cx, [file_size]
    WRITE_FILE name83, bx, cx
    pop es
    ret

insert_char:
    mov cx, [file_size]
    cmp cx, 512
    jae .done
    
    push ds
    push es
    mov bx, 0x5000
    mov ds, bx
    mov es, bx
    
    mov cx, [cs:file_size]
    sub cx, [cs:cursor_idx]
    jz .no_shift
    
    mov si, [cs:file_size]
    dec si
    mov di, si
    inc di
    std
    rep movsb
    cld
.no_shift:
    mov bx, [cs:cursor_idx]
    mov [bx], al
    pop es
    pop ds
    
    inc word [file_size]
    inc word [cursor_idx]
.done:
    ret

delete_char:
    cmp word [cursor_idx], 0
    je .done
    
    push ds
    push es
    mov bx, 0x5000
    mov ds, bx
    mov es, bx
    
    mov di, [cs:cursor_idx]
    dec di
    mov si, di
    inc si
    
    mov cx, [cs:file_size]
    sub cx, [cs:cursor_idx]
    jz .no_shift_del
    
    cld
    rep movsb
.no_shift_del:
    pop es
    pop ds
    
    dec word [file_size]
    dec word [cursor_idx]
.done:
    ret

draw_screen:
    push es
    mov ax, 0xB800
    mov es, ax
    xor di, di
    
    ; Draw header
    mov si, header_text
    mov ah, 0x70
.hdr:
    mov al, [cs:si]
    test al, al
    jz .hdr_fill
    stosw
    inc si
    jmp .hdr
.hdr_fill:
    mov al, ' '
    mov cx, 80
    mov bx, di
    shr bx, 1
    sub cx, bx
    rep stosw
    
    ; Draw text
    push ds
    mov ax, 0x5000
    mov ds, ax
    mov si, 0
    mov cx, [cs:file_size]
    mov bx, 0
    
    mov dl, 0 ; col
    mov dh, 1 ; row
.print_loop:
    cmp bx, [cs:cursor_idx]
    jne .not_cursor
    mov [cs:cursor_row], dh
    mov [cs:cursor_col], dl
.not_cursor:
    cmp bx, cx
    je .done_print
    
    mov al, [bx]
    inc bx
    
    cmp al, 0x0D
    je .print_loop
    cmp al, 0x0A
    je .newline
    
    mov ah, 0x0F
    stosw
    inc dl
    cmp dl, 80
    jne .print_loop
    mov dl, 0
    inc dh
    jmp .print_loop
    
.newline:
    mov ah, 0x0F
    mov al, ' '
.nl_fill:
    cmp dl, 80
    je .nl_done
    stosw
    inc dl
    jmp .nl_fill
.nl_done:
    mov dl, 0
    inc dh
    jmp .print_loop
    
.done_print:
    cmp bx, [cs:cursor_idx]
    jne .skip_cursor_end
    mov [cs:cursor_row], dh
    mov [cs:cursor_col], dl
.skip_cursor_end:
    
.fill_screen:
    cmp dh, 25
    jae .done_fill
    mov ah, 0x0F
    mov al, ' '
.fill_line:
    cmp dl, 80
    je .fill_line_done
    stosw
    inc dl
    jmp .fill_line
.fill_line_done:
    mov dl, 0
    inc dh
    jmp .fill_screen
.done_fill:
    
    pop ds
    pop es
    
    mov dh, [cursor_row]
    mov dl, [cursor_col]
    SET_CURSOR dh, dl
    ret

to_83_name:
    push ax
    push bx
    push cx
    push di
    push es

    push ds
    pop es

    mov di, name83
    mov cx, 11
    mov al, ' '
    rep stosb

    mov di, name83
    xor bx, bx
.base:
    mov al, [si]
    cmp al, 0
    je .noext
    cmp al, '.'
    je .ext
    cmp al, ' '
    je .end
    call upcase
    cmp bx, 8
    jae .skipb
    mov [di], al
    inc di
    inc bx
.skipb:
    inc si
    jmp .base

.ext:
    inc si
    mov di, name83+8
    mov cx, 0
.extloop:
    mov al, [si]
    cmp al, 0
    je .ok
    cmp al, ' '
    je .ok
    call upcase
    cmp cx, 3
    jae .skipe
    mov [di], al
    inc di
    inc cx
.skipe:
    inc si
    jmp .extloop

.noext:
    mov byte [name83+8], 'T'
    mov byte [name83+9], 'X'
    mov byte [name83+10], 'T'
    jmp .ok

.end:
    jmp .noext

.ok:
    clc
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

upcase:
    cmp al, 'a'
    jb .r
    cmp al, 'z'
    ja .r
    sub al, 32
.r:
    ret

filename_buf times 16 db 0
name83 times 11 db 0
file_size dw 0
cursor_idx dw 0
cursor_row db 0
cursor_col db 0
tmp_idx dw 0

header_text db " LamaOS Editor | ESC: Menu | F2: Save | F3: Exit ", 0

main_menu:
    db 3
    dw m_save, m_exit, m_cancel
m_save db " Save ", 0
m_exit db " Exit ", 0
m_cancel db " Cancel ", 0
