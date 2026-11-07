ASM     := fasm
SRC     := src/boot.asm
SRC_MBR := src/mbr.asm
SRC_FNT := src/font16.asm
BUILD   := build
BOOTBIN := $(BUILD)/boot.bin
MBRBIN  := $(BUILD)/mbr.bin
FONTBIN := $(BUILD)/font16.bin
FLOPPY  := $(BUILD)/boot.img
DISK    := $(BUILD)/disk.img

.PHONY: all floppy mbr run run-hd shot clean

all: floppy mbr

$(BUILD):
	mkdir -p $(BUILD)

# загрузочный сектор: ровно 512 байт, иначе BIOS его не загрузит
$(BOOTBIN): $(SRC) | $(BUILD)
	$(ASM) $(SRC) $@
	@size=$$(stat -c%s $@); \
	if [ $$size -gt 512 ]; then \
		echo "boot sector is $$size bytes, max is 512" >&2; \
		rm -f $@; \
		exit 1; \
	fi

# шрифт: отдельный сектор, который загрузчик читает через int 13h
$(FONTBIN): $(SRC_FNT) | $(BUILD)
	$(ASM) $(SRC_FNT) $@
	@size=$$(stat -c%s $@); \
	if [ $$size -ne 512 ]; then \
		echo "font sector is $$size bytes, expected 512" >&2; \
		rm -f $@; \
		exit 1; \
	fi

# MBR: код в первых 446 байтах, таблицу разделов дописывает mkimage.py
$(MBRBIN): $(SRC_MBR) | $(BUILD)
	$(ASM) $(SRC_MBR) $@
	@size=$$(stat -c%s $@); \
	if [ $$size -ne 512 ]; then \
		echo "mbr is $$size bytes, expected 512" >&2; \
		rm -f $@; \
		exit 1; \
	fi

# образ дискеты 1.44 МБ: загрузчик + сектор шрифта + нули
$(FLOPPY): $(BOOTBIN) $(FONTBIN)
	cat $(BOOTBIN) $(FONTBIN) > $@
	truncate -s 1474560 $@

# образ жёсткого диска: MBR, раздел, в начале раздела загрузчик и шрифт
$(DISK): $(MBRBIN) $(BOOTBIN) $(FONTBIN) tools/mkimage.py
	./tools/mkimage.py $(MBRBIN) $(BOOTBIN) $(FONTBIN) $@

floppy: $(FLOPPY)

mbr: $(DISK)

run: $(FLOPPY)
	qemu-system-i386 -drive file=$(FLOPPY),format=raw,if=floppy -boot a -m 32

run-hd: $(DISK)
	qemu-system-i386 -drive file=$(DISK),format=raw,if=ide -boot c -m 32

# скриншоты экрана виртуальной машины (для отчёта)
shot: $(FLOPPY)
	./tools/screenshot.sh $(FLOPPY) screenshots/boot.png

clean:
	rm -rf $(BUILD)
