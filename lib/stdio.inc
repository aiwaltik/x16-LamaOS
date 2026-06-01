; =============================================================================
; LamaOS Library - Standard I/O (stdio.inc)
; =============================================================================

; Text and Terminal
SYS_PUTS           equ 0x01   ; DS:DX -> 0-terminated string
SYS_GETCH          equ 0x02   ; returns AL
SYS_CLS            equ 0x03   ; clears screen
SYS_PUTCHAR        equ 0x04   ; AL -> char
SYS_SET_CURSOR     equ 0x07   ; DH=row, DL=col
SYS_GET_CURSOR     equ 0x08   ; returns DH=row, DL=col
SYS_PUTS_COLOR     equ 0x1B   ; DS:DX -> string, BL -> color
SYS_PUTCHAR_COLOR  equ 0x1C   ; AL -> char, BL -> color
SYS_INPUT          equ 0x1D   ; DS:DX -> buffer, CX -> max length

; Sound
SYS_PLAY_SOUND     equ 0x18   ; BX=frequency in Hz (0 to stop)

; =============================================================================
; Macros for Standard I/O API
; =============================================================================

; Print string from pointer
%macro PUTS 1
    push dx
    push ax
    mov dx, %1
    mov ah, SYS_PUTS
    int SYS_INT
    pop ax
    pop dx
%endmacro

; Print inline string literal
%macro PRINT 1-*
    jmp %%skip
%%str: db %1
    %rep %0 - 1
        %rotate 1
        db %1
    %endrep
    db 0
%%skip:
    push dx
    push ax
    mov dx, %%str
    mov ah, SYS_PUTS
    int SYS_INT
    pop ax
    pop dx
%endmacro

; Print inline string literal with newline
%macro PRINTLN 0-*
    jmp %%skip
%%str: 
    %if %0 > 0
        db %1
        %rep %0 - 1
            %rotate 1
            db %1
        %endrep
    %endif
    db 0x0D, 0x0A, 0
%%skip:
    push dx
    push ax
    mov dx, %%str
    mov ah, SYS_PUTS
    int SYS_INT
    pop ax
    pop dx
%endmacro

; Print a single character
%macro PUTCHAR 1
    push ax
    mov al, %1
    mov ah, SYS_PUTCHAR
    int SYS_INT
    pop ax
%endmacro

; Print string from pointer with color
%macro PUTS_COLOR 2
    push bx
    push dx
    push ax
    mov dx, %1
    mov bl, %2
    mov ah, SYS_PUTS_COLOR
    int SYS_INT
    pop ax
    pop dx
    pop bx
%endmacro

; Print inline string literal with color
%macro PRINT_COLOR 2-*
    jmp %%skip
%%str: db %2
    %rep %0 - 2
        %rotate 1
        db %2
    %endrep
    db 0
%%skip:
    push bx
    push dx
    push ax
    mov dx, %%str
    mov bl, %1
    mov ah, SYS_PUTS_COLOR
    int SYS_INT
    pop ax
    pop dx
    pop bx
%endmacro

; Print inline string literal with newline and color
%macro PRINTLN_COLOR 1-*
    jmp %%skip
%%str: 
    %if %0 > 1
        db %2
        %rep %0 - 2
            %rotate 1
            db %2
        %endrep
    %endif
    db 0x0D, 0x0A, 0
%%skip:
    push bx
    push dx
    push ax
    mov dx, %%str
    mov bl, %1
    mov ah, SYS_PUTS_COLOR
    int SYS_INT
    pop ax
    pop dx
    pop bx
%endmacro

; Print a single character with color
%macro PUTCHAR_COLOR 2
    push bx
    push ax
    mov al, %1
    mov bl, %2
    mov ah, SYS_PUTCHAR_COLOR
    int SYS_INT
    pop ax
    pop bx
%endmacro

; Read line from user into buffer (returns length in CX)
%macro INPUT 2
    push dx
    push ax
    mov dx, %1
    mov cx, %2
    mov ah, SYS_INPUT
    int SYS_INT
    pop ax
    pop dx
%endmacro

; Wait for keypress, returns ASCII in AL
%macro GETCH 0
    mov ah, SYS_GETCH
    int SYS_INT
%endmacro

; Clear the screen
%macro CLS 0
    push ax
    mov ah, SYS_CLS
    int SYS_INT
    pop ax
%endmacro

; Set cursor position (row, col)
%macro SET_CURSOR 2
    push dx
    push ax
    mov dh, %1
    mov dl, %2
    mov ah, SYS_SET_CURSOR
    int SYS_INT
    pop ax
    pop dx
%endmacro

; Get cursor position (returns DH=row, DL=col)
%macro GET_CURSOR 0
    mov ah, SYS_GET_CURSOR
    int SYS_INT
%endmacro

; Play sound (frequency in Hz, 0 to stop)
%macro PLAY_SOUND 1
    push bx
    push ax
    mov bx, %1
    mov ah, SYS_PLAY_SOUND
    int SYS_INT
    pop ax
    pop bx
%endmacro
