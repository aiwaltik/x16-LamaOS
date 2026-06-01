; =============================================================================
; LamaOS Library - Graphics (graphics.inc)
; =============================================================================

; Graphics
SYS_SET_VIDEO_MODE equ 0x0C   ; AL=mode (0x03=text, 0x13=VGA)
SYS_DRAW_PIXEL     equ 0x0D   ; CX=x, DX=y, AL=color
SYS_DRAW_RECT      equ 0x1F   ; CX=x, DX=y, SI=w, DI=h, AL=color
SYS_FILL_RECT      equ 0x20   ; CX=x, DX=y, SI=w, DI=h, AL=color
SYS_DRAW_LINE      equ 0x21   ; CX=x1, DX=y1, SI=x2, DI=y2, AL=color
SYS_KBHIT          equ 0x22   ; returns AL=1 if key pressed, AL=0 if no key

; =============================================================================
; Macros for Graphics API
; =============================================================================

; Set video mode (e.g., 0x03 for text, 0x13 for VGA 320x200 256 colors)
%macro SET_VIDEO_MODE 1
    push ax
    mov al, %1
    mov ah, SYS_SET_VIDEO_MODE
    int SYS_INT
    pop ax
%endmacro

; Draw a pixel (x, y, color)
%macro DRAW_PIXEL 3
    push dx
    push cx
    push ax
    mov cx, %1
    mov dx, %2
    mov al, %3
    mov ah, SYS_DRAW_PIXEL
    int SYS_INT
    pop ax
    pop cx
    pop dx
%endmacro

; Draw a rectangle (x, y, w, h, color)
%macro DRAW_RECT 5
    push di
    push si
    push dx
    push cx
    push ax
    mov cx, %1
    mov dx, %2
    mov si, %3
    mov di, %4
    mov al, %5
    mov ah, SYS_DRAW_RECT
    int SYS_INT
    pop ax
    pop cx
    pop dx
    pop si
    pop di
%endmacro

; Fill a rectangle (x, y, w, h, color)
%macro FILL_RECT 5
    push di
    push si
    push dx
    push cx
    push ax
    mov cx, %1
    mov dx, %2
    mov si, %3
    mov di, %4
    mov al, %5
    mov ah, SYS_FILL_RECT
    int SYS_INT
    pop ax
    pop cx
    pop dx
    pop si
    pop di
%endmacro

; Draw a line (x1, y1, x2, y2, color)
; Draw a line (x1, y1, x2, y2, color)
%macro DRAW_LINE 5
    push di
    push si
    push dx
    push cx
    push ax
    mov cx, %1
    mov dx, %2
    mov si, %3
    mov di, %4
    mov al, %5
    mov ah, SYS_DRAW_LINE
    int SYS_INT
    pop ax
    pop cx
    pop dx
    pop si
    pop di
%endmacro

; Clear screen for VGA 320x200
%macro CLEAR_SCREEN_VGA 1
    FILL_RECT 0, 0, 320, 200, %1
%endmacro

; Check if key is pressed (non-blocking)
%macro KBHIT 0
    mov ah, SYS_KBHIT
    int SYS_INT
%endmacro

