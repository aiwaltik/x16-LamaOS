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
USER_CFG   := $(OUT)/USER.CFG

# programs/*.asm -> out/<name>.LEX (add a new .asm file — no Makefile edits)
PROG_SRCS := $(sort $(wildcard programs/*.asm))
PROG_BINS := $(patsubst programs/%.asm,$(OUT)/%.LEX,$(PROG_SRCS))

.PHONY: all image run qemu clean

all: image

image: $(IMG)

run qemu: $(IMG)
	$(QEMU) -fda $(IMG) -m 32

ifeq ($(OS),Windows_NT)
MKOUT = @if not exist $(OUT) mkdir $(OUT)
KILL_QEMU = -cmd /c "if exist $(OUT)\lamaos.img (ren $(OUT)\lamaos.img lamaos.img 2>nul || taskkill /IM qemu-system-i386.exe /F >nul 2>nul)"
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

$(OUT)/%.LEX: programs/%.asm
	$(MKOUT)
	$(NASM) $< -f bin -o $@

$(USER_CFG):
	$(MKOUT)
	$(DD) if=/dev/zero of=$@ bs=512 count=1 status=none

define COPY_PROGS_TO_IMG
$(foreach bin,$(PROG_BINS),
	$(MCOPY) -i $(IMG) -o $(bin) ::/$(notdir $(bin))
)
endef

$(IMG): $(BOOT_BIN) $(KERNEL_BIN) $(PROG_BINS) $(USER_CFG)
	$(KILL_QEMU)
	$(DD) if=/dev/zero of=$(IMG) bs=512 count=2880 status=none
	$(MKFS) -F 12 -n "LAMAOS" $(IMG)
	$(DD) if=$(BOOT_BIN) of=$(IMG) bs=512 count=1 conv=notrunc status=none
	$(MCOPY) -i $(IMG) -o $(KERNEL_BIN) ::/KERNEL.BIN
	$(COPY_PROGS_TO_IMG)
	$(MCOPY) -i $(IMG) -o $(USER_CFG) ::/USER.CFG

ifeq ($(OS),Windows_NT)
clean:
	$(KILL_QEMU)
	-if exist $(OUT) rmdir /s /q $(OUT)
else
clean:
	$(KILL_QEMU)
	rm -rf $(OUT)
endif
