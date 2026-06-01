; =============================================================================
; LamaOS Library - System (system.inc)
; =============================================================================

SYS_INT            equ 0x60

; Time and Date
SYS_GET_TIME       equ 0x05   ; returns CH=hour, CL=min, DH=sec
SYS_GET_DATE       equ 0x06   ; returns CX=year, DH=month, DL=day
SYS_GET_TICKS      equ 0x17   ; returns DX:AX ticks

; System and Hardware
SYS_GET_MEM_SIZE   equ 0x0E   ; returns AX=memory in KB
SYS_YIELD          equ 0x0F   ; wait for interrupt (hlt)
SYS_REBOOT         equ 0x13   ; reboot system

; Filesystem and Execution
SYS_LS             equ 0x10   ; list root dir
SYS_EXEC           equ 0x11   ; DS:DX -> 8.3 name
SYS_EXIT           equ 0x12   ; return to shell
SYS_READ_FILE      equ 0x14   ; DS:DX -> 8.3 name, CX -> segment
SYS_WRITE_FILE     equ 0x15   ; DS:DX -> 8.3 name, ES:BX -> buffer (1 sector)
SYS_FILE_SIZE      equ 0x16   ; DS:DX -> 8.3 name, returns DX:AX size
SYS_CREATE_FILE    equ 0x19   ; DS:DX -> 8.3 name
SYS_DELETE_FILE    equ 0x1A   ; DS:DX -> 8.3 name

; =============================================================================
; Macros for System API
; =============================================================================

; Exit program and return to shell
%macro EXIT 0
    mov ah, SYS_EXIT
    int SYS_INT
%endmacro

; Yield CPU
%macro YIELD 0
    mov ah, SYS_YIELD
    int SYS_INT
%endmacro

; Reboot the system
%macro REBOOT 0
    mov ah, SYS_REBOOT
    int SYS_INT
%endmacro

; Get Time (returns CH=hour, CL=min, DH=sec)
%macro GET_TIME 0
    mov ah, SYS_GET_TIME
    int SYS_INT
%endmacro

; Get Date (returns CX=year, DH=month, DL=day)
%macro GET_DATE 0
    mov ah, SYS_GET_DATE
    int SYS_INT
%endmacro

; Get System Ticks (returns DX:AX)
%macro GET_TICKS 0
    mov ah, SYS_GET_TICKS
    int SYS_INT
%endmacro

; Get Memory Size in KB (returns AX)
%macro GET_MEM_SIZE 0
    mov ah, SYS_GET_MEM_SIZE
    int SYS_INT
%endmacro

; List files in root directory
%macro LS 0
    push ax
    mov ah, SYS_LS
    int SYS_INT
    pop ax
%endmacro

; Execute a program from file
%macro EXEC 1
    push dx
    push ax
    mov dx, %1
    mov ah, SYS_EXEC
    int SYS_INT
    pop ax
    pop dx
%endmacro

; Read file to segment
%macro READ_FILE 2
    push cx
    push dx
    push ax
    mov dx, %1
    mov cx, %2
    mov ah, SYS_READ_FILE
    int SYS_INT
    pop ax
    pop dx
    pop cx
%endmacro

; Write file from buffer (name, buffer, size)
%macro WRITE_FILE 3
    push cx
    push bx
    push dx
    push ax
    mov dx, %1
    mov bx, %2
    mov cx, %3
    mov ah, SYS_WRITE_FILE
    int SYS_INT
    pop ax
    pop dx
    pop bx
    pop cx
%endmacro

; Get file size (returns DX:AX)
%macro FILE_SIZE 1
    mov dx, %1
    mov ah, SYS_FILE_SIZE
    int SYS_INT
%endmacro

; Create file
%macro CREATE_FILE 1
    mov dx, %1
    mov ah, SYS_CREATE_FILE
    int SYS_INT
%endmacro

; Delete file
%macro DELETE_FILE 1
    mov dx, %1
    mov ah, SYS_DELETE_FILE
    int SYS_INT
%endmacro
