; =============================================================================
; LamaOS Library - Graphics (graphics.inc)
; =============================================================================

; Graphics
SYS_SET_VIDEO_MODE equ 0x0C   ; AL=mode (0x03=text, 0x13=VGA)
SYS_DRAW_PIXEL     equ 0x0D   ; CX=x, DX=y, AL=color

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
