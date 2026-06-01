[bits 16]
[org 0x0000]

%include "lib/lama.inc"

LEX_HEADER

_start:
    PRINTLN "Hello World!"
    retf