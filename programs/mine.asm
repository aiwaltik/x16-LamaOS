[bits 16]
[org 0x0000]

%include "lib/lama.inc"

LEX_HEADER

%assign WordSize 2
%assign TextBuf.Seg 0xb800
%assign TextBuf.Width 40
%assign TextBuf.Height 25
%assign TextBuf.Size (TextBuf.Width * TextBuf.Height)
%define TextBuf.Index(y, x) ((y) * TextBuf.Width * 2 + (x) * 2)
%assign Dirs.Len 8

; --- SCANCODES ---
%assign Key.ScanCode.Space 0x39
%assign Key.ScanCode.Up 0x48
%assign Key.ScanCode.Down 0x50
%assign Key.ScanCode.Left 0x4b
%assign Key.ScanCode.Right 0x4d
%assign Key.ScanCode.Enter 0x1c
%assign Key.Ascii.RestartGame 'r'
%assign Key.Ascii.RestartGameUpper 'R'
%assign Key.Ascii.Esc 0x1b

%define VgaChar(color, ascii) (((color) << 8) | (ascii))

; --- COLORS ---
%assign Color.Veiled 0x00
%assign Color.Unveiled 0xf0
%assign Color.Cursor 0x77
%assign Color.Flag 0xcc
%assign Color.GameWinText 0x20
%assign Color.GameOverText 0xc0
%assign BombFreq 0b111

_start:
  CLS
  PUTS help_msg
  PUTS any_key_msg

  GETCH

  SET_VIDEO_MODE 0x01

  mov dx, 0x03DA
  in al, dx
  mov dx, 0x03C0
  mov al, 0x30
  out dx, al
  inc dx
  in al, dx
  and al, 0xF7
  dec dx
  out dx, al

  mov ah, 0x01
  mov cx, 0x2000
  int 0x10

RunGame:
  mov dx, TextBuf.Seg
  mov es, dx

ZeroTextBuf:
  xor di, di
  mov cx, TextBuf.Size
  mov ax, VgaChar(Color.Veiled, '0')
.Loop:
  stosw
  loop .Loop

PopulateTextBuf:
  mov bx, TextBuf.Height - 2

  GET_TICKS
  mov [seed], ax

.LoopY:
  mov cx, TextBuf.Width - 2

.LoopX:
  call GetTextBufIndex
  
  ; LCG: seed = seed * 25173 + 13849
  mov ax, [seed]
  mov dx, 25173
  mul dx
  add ax, 13849
  mov [seed], ax
  
  mov al, ah
  and al, BombFreq
  setz dl
  mov bp, Dirs.Len
  jnz .LoopDir
  mov byte [es:di], '*'
.LoopDir:
  push di
  movsx ax, byte [cs:Dirs - 1 + bp]
  add di, ax
  mov al, [es:di]
  cmp al, '*'
  je .LoopDirIsMine
  add [es:di], dl
.LoopDirIsMine:
  pop di
  dec bp
  jnz .LoopDir
  loop .LoopX
  dec bx
  jnz .LoopY

  mov bx, 0
  mov cx, 0

GameLoop:
  call GetTextBufIndex
  mov dx, [es:di]
  
  cmp dh, Color.Veiled
  je .SolidCursor
  cmp dh, Color.Flag
  je .FlagCursor
  
  mov ah, dh
  and ah, 0x0F
  or ah, 0x70
  mov al, dl
  jmp .SetCursor
  
.SolidCursor:
  mov ax, 0x7720
  jmp .SetCursor
  
.FlagCursor:
  mov ax, 0x7C46
  
.SetCursor:
  mov [es:di], ax

  GETCH
  
  mov [es:di], dx

  cmp al, Key.Ascii.Esc
  je ExitGame

DetectWin:
  xor si, si
  push ax
  push cx
  mov cx, TextBuf.Size
  xor di, di
.Loop:
  mov ax, [es:di]
  add di, 2
  cmp ah, Color.Veiled
  je .CheckMine
  cmp ah, Color.Flag
  jne .Continue
.CheckMine:
  cmp al, '*'
  jne .Break
.Continue:
  loop .Loop
  jmp GameWin
.Break:
  pop cx
  pop ax

CmpUp:
  cmp ah, Key.ScanCode.Up
  jne CmpDown
  dec bx
  jmp WrapCursor
CmpDown:
  cmp ah, Key.ScanCode.Down
  jne CmpLeft
  inc bx
  jmp WrapCursor
CmpLeft:
  cmp ah, Key.ScanCode.Left
  jne CmpRight
  dec cx
  jmp WrapCursor
CmpRight:
  cmp ah, Key.ScanCode.Right
  jne CmpEnter
  inc cx
  jmp WrapCursor
CmpEnter:
  cmp ah, Key.ScanCode.Enter
  jne CmpSpace
  call GetTextBufIndex
  mov al, [es:di + 1]
  cmp al, Color.Veiled
  je .SetFlag
  cmp al, Color.Flag
  je .ClearFlag
  jmp GameLoop
.SetFlag:
  mov byte [es:di + 1], Color.Flag
  jmp GameLoop
.ClearFlag:
  mov byte [es:di + 1], Color.Veiled
  jmp GameLoop
CmpSpace:
  cmp ah, Key.ScanCode.Space
  jne GameLoop

ClearCell:
  call GetTextBufIndex
  mov ax, [es:di]
  cmp ah, Color.Flag
  je GameLoop
  call UnveilCell
.CmpEmpty:
  cmp al, '0'
  jne .CmpMine
  call Flood
  jmp GameLoop
.CmpMine:
  cmp al, '*'
  jne GameLoop
  jmp GameOver

WrapCursor:
.Y:
  cmp bx, 0xFFFF
  jne .Y2
  mov bx, TextBuf.Height - 1
.Y2:
  cmp bx, TextBuf.Height
  jb .X
  xor bx, bx
.X:
  cmp cx, 0xFFFF
  jne .X2
  mov cx, TextBuf.Width - 1
.X2:
  cmp cx, TextBuf.Width
  jb SetCursorPos
  xor cx, cx
SetCursorPos:
  jmp GameLoop

GetTextBufIndex:
  push cx
  imul di, bx, TextBuf.Width * 2
  imul cx, cx, 2
  add di, cx
  pop cx
  ret

UnveilCell:
  mov dl, al
  xor dl, '0' ^ Color.Unveiled
  mov [es:di + 1], dl
  ret

Flood:
  cmp bx, TextBuf.Height
  jae .Ret
  cmp cx, TextBuf.Width
  jae .Ret
  call GetTextBufIndex
  mov ax, [es:di]
  cmp al, ' '
  je .Ret
  cmp al, '*'
  je .Ret
  call UnveilCell
  cmp al, '0'
  jne .Ret
  mov byte [es:di], ' '
  
  push bx
  push cx
  
  dec bx
  call Flood ; Up
  add bx, 2
  call Flood ; Down
  dec bx
  dec cx
  call Flood ; Left
  add cx, 2
  call Flood ; Right
  
  dec bx
  call Flood ; Up-Right
  add cx, -2
  call Flood ; Up-Left
  add bx, 2
  call Flood ; Down-Left
  add cx, 2
  call Flood ; Down-Right
  
  pop cx
  pop bx
.Ret:
  ret

Dirs:
  db TextBuf.Index(-1, -1)
  db TextBuf.Index(-1,  0)
  db TextBuf.Index(-1, +1)
  db TextBuf.Index( 0, +1)
  db TextBuf.Index(+1, +1)
  db TextBuf.Index(+1,  0)
  db TextBuf.Index(+1, -1)
  db TextBuf.Index( 0, -1)

GameWinStr:
  db 'YOU WIN!'
%assign GameWinStr.Len $ - GameWinStr

GameOverStr:
  db 'GAME OVER'
%assign GameOverStr.Len $ - GameOverStr

GameWin:
  mov cx, GameWinStr.Len
  mov si, GameWinStr
  mov ah, Color.GameWinText
  jmp GameEndHelper

GameOver:
  mov cx, GameOverStr.Len
  mov si, GameOverStr
  mov ah, Color.GameOverText

GameEndHelper:
  mov di, ((TextBuf.Height / 2) * TextBuf.Width * 2) + (TextBuf.Width / 2 - GameOverStr.Len / 2) * 2
.PrintLoop:
  lodsb
  stosw
  loop .PrintLoop

WaitRestart:
  GETCH
  cmp al, Key.Ascii.RestartGame
  je RunGame
  cmp al, Key.Ascii.RestartGameUpper
  je RunGame
  cmp al, Key.Ascii.Esc
  je ExitGame
  jmp WaitRestart

ExitGame:
  SET_VIDEO_MODE 0x03
  CLS
  retf

help_msg    db 0xC9, 51 dup(0xCD), 0xBB, 13, 10
            db 0xBA, '  PRos minesweeper                                 ', 0xBA, 13, 10
            db 0xC3, 51 dup(0xC4), 0xB4, 13, 10
            db 0xBA, '  ARROWS   - move the cursor                       ', 0xBA, 13, 10
            db 0xBA, '  SPACE    - open the cage on the field            ', 0xBA, 13, 10
            db 0xBA, '  ENTER    - place a flag                          ', 0xBA, 13, 10
            db 0xBA, '  R        - restart the game                      ', 0xBA, 13, 10
            db 0xC3, 51 dup(0xC4), 0xB4, 13, 10
            db 0xBA, '  Press ESC to quit                                ', 0xBA, 13, 10
            db 0xC0, 51 dup(0xCD), 0xBC, 13, 10, 0

any_key_msg db 'Press any key to start the game...', 13, 10, 0

seed dw 0