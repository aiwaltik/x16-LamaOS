# LamaOS — build floppy image and run in QEMU (MSYS2 / Windows paths)

NASM  ?= nasm
DD    ?= C:/msys64/usr/bin/dd.exe
MKFS  ?= C:/msys64/usr/bin/mkfs.fat.exe
MCOPY ?= C:/msys64/mingw64/bin/mcopy.exe

QEMU  ?= "C:/Program Files/qemu/qemu-system-i386.exe"

OUT   := out
IMG   := $(OUT)/lamaos.img

BOOT_BIN   := $(OUT)/boot.bin
KERNEL_BIN := $(OUT)/KERNEL.BIN
SHELL_BIN  := $(OUT)/SHELL.LEX
HELLO_BIN  := $(OUT)/HELLO.LEX
CALC_BIN   := $(OUT)/CALC.LEX
SETUP_BIN  := $(OUT)/SETUP.LEX
FETCH_BIN  := $(OUT)/FETCH.LEX
EDIT_BIN   := $(OUT)/EDIT.LEX
USER_CFG   := $(OUT)/USER.CFG

.PHONY: all image run qemu clean

all: image

image: $(IMG)

run qemu: $(IMG)
	$(QEMU) -fda $(IMG) -m 32

ifeq ($(OS),Windows_NT)
MKOUT = @if not exist $(OUT) mkdir $(OUT)
KILL_QEMU = -taskkill /IM qemu-system-i386.exe /F >nul 2>nul
else
MKOUT = @mkdir -p $(OUT)
KILL_QEMU = -killall qemu-system-i386 >/dev/null 2>&1
endif

$(BOOT_BIN): boot/boot.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(KERNEL_BIN): kernel/kernel.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(SHELL_BIN): programs/shell.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(HELLO_BIN): programs/hello.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(CALC_BIN): programs/calc.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(SETUP_BIN): programs/setup.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(FETCH_BIN): programs/fetch.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(EDIT_BIN): programs/edit.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(USER_CFG):
	$(MKOUT)
	$(DD) if=/dev/zero of=$@ bs=512 count=1 status=none

$(IMG): $(BOOT_BIN) $(KERNEL_BIN) $(SHELL_BIN) $(HELLO_BIN) $(CALC_BIN) $(SETUP_BIN) $(FETCH_BIN) $(EDIT_BIN) $(USER_CFG)
	$(KILL_QEMU)
	$(DD) if=/dev/zero of=$(IMG) bs=512 count=2880 status=none
	$(MKFS) -F 12 -n "LAMAOS" $(IMG)
	$(DD) if=$(BOOT_BIN) of=$(IMG) bs=512 count=1 conv=notrunc status=none
	$(MCOPY) -i $(IMG) -o $(KERNEL_BIN) ::/KERNEL.BIN
	$(MCOPY) -i $(IMG) -o $(SHELL_BIN)  ::/SHELL.LEX
	$(MCOPY) -i $(IMG) -o $(HELLO_BIN)  ::/HELLO.LEX
	$(MCOPY) -i $(IMG) -o $(CALC_BIN)   ::/CALC.LEX
	$(MCOPY) -i $(IMG) -o $(SETUP_BIN)  ::/SETUP.LEX
	$(MCOPY) -i $(IMG) -o $(FETCH_BIN)  ::/FETCH.LEX
	$(MCOPY) -i $(IMG) -o $(EDIT_BIN)   ::/EDIT.LEX
	$(MCOPY) -i $(IMG) -o $(USER_CFG)   ::/USER.CFG

ifeq ($(OS),Windows_NT)
clean:
	$(KILL_QEMU)
	-if exist $(OUT) rmdir /s /q $(OUT)
else
clean:
	$(KILL_QEMU)
	rm -rf $(OUT)
endif
