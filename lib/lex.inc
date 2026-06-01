; =============================================================================
; Lama Executable (LEX) Format
; =============================================================================

; Header structure (16 bytes):
; 0x00: Magic bytes 'L', 'X' (0x584C)
; 0x02: Version (db)
; 0x03: Reserved (db)
; 0x04: Entry point offset (dw)
; 0x06: BSS size in bytes (dw)
; 0x08: Stack size in bytes (dw)
; 0x0A: Reserved (6 bytes)

%macro LEX_HEADER 0
    db 'L', 'X'
    db 1
    db 0
    dw _start
    dw 0 ; bss size
    dw 0 ; stack size
    times 6 db 0
%endmacro
