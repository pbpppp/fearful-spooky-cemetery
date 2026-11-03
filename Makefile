ASM     := fasm
SRC     := src/boot.asm
SRC_FNT := src/font16.asm
BUILD   := build
BOOTBIN := $(BUILD)/boot.bin
FONTBIN := $(BUILD)/font16.bin
FLOPPY  := $(BUILD)/boot.img

.PHONY: all floppy run shot clean

all: floppy

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

# образ дискеты 1.44 МБ: загрузчик + сектор шрифта + нули
$(FLOPPY): $(BOOTBIN) $(FONTBIN)
	cat $(BOOTBIN) $(FONTBIN) > $@
	truncate -s 1474560 $@

floppy: $(FLOPPY)

run: $(FLOPPY)
	qemu-system-i386 -drive file=$(FLOPPY),format=raw,if=floppy -boot a -m 32

# скриншот экрана виртуальной машины (для отчёта)
shot: $(FLOPPY)
	./tools/screenshot.sh $(FLOPPY) screenshots/boot.png

clean:
	rm -rf $(BUILD)
