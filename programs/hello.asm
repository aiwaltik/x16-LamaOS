[bits 16]
[org 0x0000]

SYS_INT  equ 0x60
SYS_PUTS equ 0x01
SYS_EXIT equ 0x12

start:
    push cs
    pop ds

    mov dx, msg
    mov ah, SYS_PUTS
    int SYS_INT

    retf

msg db 'Hello World!',0x0D,0x0A,0

