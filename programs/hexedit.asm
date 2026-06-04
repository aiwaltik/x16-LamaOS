[bits 16]
[org 0x0000]

%include "lib/lama.inc"

LEX_HEADER

_start:
    PRINT "File to view/edit: "
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
    
    ; If size is 0, treat as 512
    test ax, ax
    jnz .set_size
    mov ax, 512
.set_size:
    mov [file_size], ax
    
    ; Read file to 0x5000
    READ_FILE name83, 0x5000
    jc .err_io
    
    ; Zero out the rest of the 512 bytes
    push es
    mov ax, 0x5000
    mov es, ax
    mov di, [file_size]
    mov cx, 512
    sub cx, di
    jz .skip_zero
    xor al, al
    rep stosb
.skip_zero:
    pop es
    jmp .editor_loop

.new_file:
    mov word [file_size], 512
    ; Zero out the 512 bytes
    push es
    mov ax, 0x5000
    mov es, ax
    xor di, di
    mov cx, 512
    xor al, al
    rep stosb
    pop es
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
    call update_hardware_cursor

.wait_key:
    GETCH
    cmp al, 0x1B ; ESC
    je .open_menu
    cmp al, 0x08 ; Backspace
    je .do_backspace
    cmp al, 0x00 ; Extended key
    je .do_extended

    ; Normal char - check if hex digit
    call char_to_nibble
    jc .wait_key
    
    call write_nibble
    
    ; Advance cursor
    mov ax, [file_size]
    shl ax, 1
    dec ax
    cmp [cursor_nibble], ax
    jae .editor_loop
    inc word [cursor_nibble]
    jmp .editor_loop

.do_backspace:
    mov ax, [cursor_nibble]
    test ax, ax
    jz .wait_key
    dec ax
    mov [cursor_nibble], ax
    jmp .editor_loop

.open_menu:
    MENU main_menu
    cmp ax, 0
    je .do_save
    cmp ax, 1
    je .do_exit
    ; Cancel
    jmp .editor_loop

.do_save:
    call save_file
    jmp .editor_loop

.do_exit:
    CLS
    retf

.do_extended:
    cmp ah, 0x4B ; Left
    je .move_left
    cmp ah, 0x4D ; Right
    je .move_right
    cmp ah, 0x48 ; Up
    je .move_up
    cmp ah, 0x50 ; Down
    je .move_down
    cmp ah, 0x49 ; Page Up
    je .move_pgup
    cmp ah, 0x51 ; Page Down
    je .move_pgdn
    cmp ah, 0x3C ; F2
    je .do_save
    cmp ah, 0x3D ; F3
    je .do_exit
    jmp .wait_key

.move_left:
    mov ax, [cursor_nibble]
    test ax, ax
    jz .wait_key
    dec ax
    mov [cursor_nibble], ax
    jmp .editor_loop

.move_right:
    mov ax, [file_size]
    shl ax, 1
    dec ax
    cmp [cursor_nibble], ax
    jae .wait_key
    inc word [cursor_nibble]
    jmp .editor_loop

.move_up:
    mov ax, [cursor_nibble]
    cmp ax, 32
    jb .wait_key
    sub ax, 32
    mov [cursor_nibble], ax
    jmp .editor_loop

.move_down:
    mov ax, [cursor_nibble]
    add ax, 32
    mov bx, [file_size]
    shl bx, 1
    cmp ax, bx
    jae .wait_key
    mov [cursor_nibble], ax
    jmp .editor_loop

.move_pgup:
    mov ax, [cursor_nibble]
    cmp ax, 512
    jb .wait_key
    sub ax, 512
    mov [cursor_nibble], ax
    jmp .editor_loop

.move_pgdn:
    mov ax, [cursor_nibble]
    add ax, 512
    mov bx, [file_size]
    shl bx, 1
    cmp ax, bx
    jae .wait_key
    mov [cursor_nibble], ax
    jmp .editor_loop

; -----------------------------------------------------------------------------
; UI Drawing and Helpers
; -----------------------------------------------------------------------------

draw_screen:
    push es
    mov ax, 0xB800
    mov es, ax
    xor di, di
    
    ; 1. Draw header at row 0 (cols 0..79)
    mov si, header_text
    mov ah, 0x1F ; White text on Blue background
.draw_hdr:
    lodsb
    test al, al
    jz .fill_hdr
    stosw
    jmp .draw_hdr
.fill_hdr:
    mov al, ' '
    mov cx, 80
    mov dx, di
    shr dx, 1
    sub cx, dx
    rep stosw
    
    ; Row 1: blank (black background)
    mov ax, 0x0020
    mov cx, 80
    rep stosw
    
    ; Row 2 to 17: 16 rows of hex data
    mov ax, [cursor_nibble]
    shr ax, 1 ; byte index
    and ax, 0x0100 ; if byte_index >= 256, ax = 0x100, else 0
    mov [page_start_byte], ax
    
    mov word [row_num], 0
.row_loop:
    cmp word [row_num], 16
    je .rows_done
    
    ; Calculate row start byte: page_start_byte + row_num * 16
    mov ax, [row_num]
    shl ax, 4 ; row_num * 16
    add ax, [page_start_byte]
    mov [row_start_byte], ax
    
    ; Check if row_start_byte >= file_size
    cmp ax, [file_size]
    jae .blank_row
    
    ; Draw Address Offset: e.g. "01F0: "
    mov dx, [row_start_byte]
    call draw_address_offset
    
    ; Draw 16 columns of hex
    mov word [col_num], 0
.col_loop:
    cmp word [col_num], 16
    je .col_done
    
    mov bx, [row_start_byte]
    add bx, [col_num]
    
    cmp bx, [file_size]
    jae .col_empty
    
    ; read byte
    push ds
    mov ax, 0x5000
    mov ds, ax
    mov al, [bx]
    pop ds
    
    ; color logic
    mov dx, [cursor_nibble]
    shr dx, 1
    cmp bx, dx
    je .highlight_byte
    
    test al, al
    jz .zero_byte
    
    mov ah, 0x0F ; bright white on black
    jmp .draw_hex_val
    
.zero_byte:
    mov ah, 0x08 ; dark gray on black
    jmp .draw_hex_val
    
.highlight_byte:
    mov ah, 0x30 ; black on light cyan
    
.draw_hex_val:
    mov dl, al
    shr al, 4
    call nibble_to_char
    stosw
    mov al, dl
    and al, 0x0F
    call nibble_to_char
    stosw
    jmp .col_space
    
.col_empty:
    mov ah, 0x07
    mov al, ' '
    stosw
    stosw
    
.col_space:
    cmp word [col_num], 15
    je .next_col
    mov ah, 0x07
    mov al, ' '
    stosw
    cmp word [col_num], 7
    jne .next_col
    stosw
    
.next_col:
    inc word [col_num]
    jmp .col_loop

.col_done:
    ; Draw " | " separator
    mov ah, 0x07
    mov al, ' '
    stosw
    mov al, '|'
    stosw
    mov al, ' '
    stosw
    
    ; Draw 16 ASCII characters
    mov word [col_num], 0
.ascii_loop:
    cmp word [col_num], 16
    je .ascii_done
    
    mov bx, [row_start_byte]
    add bx, [col_num]
    
    cmp bx, [file_size]
    jae .ascii_empty
    
    push ds
    mov ax, 0x5000
    mov ds, ax
    mov al, [bx]
    pop ds
    
    cmp al, 0x20
    jb .not_printable
    cmp al, 0x7E
    jbe .printable
.not_printable:
    mov al, '.'
.printable:
    ; color logic
    mov dx, [cursor_nibble]
    shr dx, 1
    cmp bx, dx
    je .highlight_ascii
    
    mov ah, 0x07 ; gray on black
    jmp .draw_ascii_char
    
.highlight_ascii:
    mov ah, 0x30 ; black on light cyan
    
.draw_ascii_char:
    stosw
    jmp .next_ascii
    
.ascii_empty:
    mov ah, 0x07
    mov al, ' '
    stosw
    
.next_ascii:
    inc word [col_num]
    jmp .ascii_loop
    
.ascii_done:
    ; Draw closing " |"
    mov ah, 0x07
    mov al, ' '
    stosw
    mov al, '|'
    stosw
    
    ; Pad the rest of the screen line with spaces (80 - 75 = 5 spaces)
    mov ax, 0x0720
    mov cx, 5
    rep stosw
    
    inc word [row_num]
    jmp .row_loop

.blank_row:
    mov ax, 0x0720
    mov cx, 80
    rep stosw
    inc word [row_num]
    jmp .row_loop

.rows_done:
    ; Row 18: blank
    mov ax, 0x0720
    mov cx, 80
    rep stosw
    
    ; Row 19: Info line
    mov di, 3040
    mov ax, 0x0720
    mov cx, 80
    rep stosw
    mov di, 3040
    
    mov si, info_offset
    call write_string_es_di
    
    mov ax, [cursor_nibble]
    shr ax, 1
    mov dx, ax
    call format_word_hex
    
    mov si, info_value
    call write_string_es_di
    
    mov bx, [cursor_nibble]
    shr bx, 1
    push ds
    mov ax, 0x5000
    mov ds, ax
    mov al, [bx]
    pop ds
    mov dl, al
    
    call format_byte_hex
    
    mov al, '('
    mov ah, 0x07
    stosw
    
    xor ax, ax
    mov al, dl
    call format_dec_word
    
    mov si, info_ascii
    call write_string_es_di
    
    mov al, dl
    cmp al, 0x20
    jb .info_dot
    cmp al, 0x7E
    jbe .info_print
.info_dot:
    mov al, '.'
.info_print:
    mov ah, 0x0B
    stosw
    
    mov al, "'"
    mov ah, 0x07
    stosw
    
    ; Row 20: blank
    mov di, 3200
    mov ax, 0x0720
    mov cx, 80
    rep stosw
    
    ; Row 21: Help Line 1
    mov di, 3360
    mov ax, 0x0720
    mov cx, 80
    rep stosw
    mov di, 3360
    mov si, help_line1
    call write_string_es_di
    
    ; Help Line 2
    mov di, 3520
    mov ax, 0x0720
    mov cx, 80
    rep stosw
    mov di, 3520
    mov si, help_line2
    call write_string_es_di
    
    ; Row 23, 24: blank
    mov di, 3680
    mov ax, 0x0720
    mov cx, 160
    rep stosw
    
    pop es
    ret

; -----------------------------------------------------------------------------
; Helpers
; -----------------------------------------------------------------------------

draw_address_offset:
    push ax
    push cx
    mov ah, 0x0B ; color: light cyan
    
    mov al, dh
    shr al, 4
    call nibble_to_char
    stosw
    
    mov al, dh
    and al, 0x0F
    call nibble_to_char
    stosw
    
    mov al, dl
    shr al, 4
    call nibble_to_char
    stosw
    
    mov al, dl
    and al, 0x0F
    call nibble_to_char
    stosw
    
    mov al, ':'
    stosw
    mov al, ' '
    stosw
    
    pop cx
    pop ax
    ret

nibble_to_char:
    and al, 0x0F
    cmp al, 10
    jb .digit
    add al, 'A' - 10
    ret
.digit:
    add al, '0'
    ret

char_to_nibble:
    cmp al, '0'
    jb .err
    cmp al, '9'
    jbe .digit
    cmp al, 'A'
    jb .err
    cmp al, 'F'
    jbe .upper
    cmp al, 'a'
    jb .err
    cmp al, 'f'
    jbe .lower
.err:
    stc
    ret
.digit:
    sub al, '0'
    clc
    ret
.upper:
    sub al, 'A' - 10
    clc
    ret
.lower:
    sub al, 'a' - 10
    clc
    ret

write_nibble:
    push ds
    push bx
    push cx
    mov cx, ax
    mov ax, 0x5000
    mov ds, ax
    mov bx, [cs:cursor_nibble]
    shr bx, 1
    mov al, [bx]
    test word [cs:cursor_nibble], 1
    jnz .low_nibble
    and al, 0x0F
    shl cl, 4
    or al, cl
    jmp .store
.low_nibble:
    and al, 0xF0
    and cl, 0x0F
    or al, cl
.store:
    mov [bx], al
    pop cx
    pop bx
    pop ds
    ret

update_hardware_cursor:
    mov ax, [cursor_nibble]
    shr ax, 1 ; byte_idx
    
    mov cl, al
    and cl, 15 ; col_in_row
    
    shr al, 4
    and al, 15 ; row_on_page
    add al, 2  ; cursor_row
    mov dh, al
    
    mov dl, 6 ; base column
    cmp cl, 8
    jb .no_extra_space
    inc dl
.no_extra_space:
    mov al, cl
    mov bl, 3
    mul bl
    add dl, al
    mov ax, [cursor_nibble]
    and ax, 1
    add dl, al
    
    SET_CURSOR dh, dl
    ret

write_string_es_di:
    push ax
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x07
    stosw
    jmp .loop
.done:
    pop ax
    ret

format_word_hex:
    push ax
    mov ah, 0x0B
    mov al, dh
    shr al, 4
    call nibble_to_char
    stosw
    mov al, dh
    and al, 0x0F
    call nibble_to_char
    stosw
    mov al, dl
    shr al, 4
    call nibble_to_char
    stosw
    mov al, dl
    and al, 0x0F
    call nibble_to_char
    stosw
    pop ax
    ret

format_byte_hex:
    push ax
    mov ah, 0x0B
    mov al, dl
    shr al, 4
    call nibble_to_char
    stosw
    mov al, dl
    and al, 0x0F
    call nibble_to_char
    stosw
    pop ax
    ret

format_dec_word:
    push ax
    push bx
    push cx
    push dx
    mov cx, 0
    mov bx, 10
.div_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div_loop
.print_digits:
    pop ax
    add al, '0'
    mov ah, 0x0B
    stosw
    loop .print_digits
    pop dx
    pop cx
    pop bx
    pop ax
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
    mov byte [name83+8], 'B'
    mov byte [name83+9], 'I'
    mov byte [name83+10], 'N'
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

; -----------------------------------------------------------------------------
; Data Section
; -----------------------------------------------------------------------------

filename_buf times 16 db 0
name83 times 11 db 0
file_size dw 0
cursor_nibble dw 0

row_num dw 0
col_num dw 0
row_start_byte dw 0
page_start_byte dw 0

header_text db " LamaOS Hex Editor | ESC: Menu | F2: Save | F3: Exit ", 0
info_offset db "  Offset: 0x", 0
info_value db " | Value: 0x", 0
info_ascii db ") | ASCII: '", 0
help_line1 db " Arrows: Move | PgUp/PgDn: Page | Hex Keys (0-9, A-F): Edit | Backspace: Back", 0
help_line2 db " F2: Save | ESC: Menu | F3: Exit", 0

main_menu:
    db 3
    dw m_save, m_exit, m_cancel
m_save db " Save ", 0
m_exit db " Exit ", 0
m_cancel db " Cancel ", 0
