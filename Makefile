ASM     := fasm
SRC     := src/boot.asm
BUILD   := build
BOOTBIN := $(BUILD)/boot.bin
FLOPPY  := $(BUILD)/boot.img

.PHONY: all floppy run shot clean

all: floppy

$(BUILD):
	mkdir -p $(BUILD)

# загрузочный сектор: ровно 512 байт, иначе BIOS его не загрузит
$(BOOTBIN): $(SRC) $(wildcard src/*.inc) | $(BUILD)
	$(ASM) $(SRC) $@
	@size=$$(stat -c%s $@); \
	if [ $$size -gt 512 ]; then \
		echo "boot sector is $$size bytes, max is 512" >&2; \
		rm -f $@; \
		exit 1; \
	fi

# образ дискеты 1.44 МБ: сектор + нули
$(FLOPPY): $(BOOTBIN)
	cp $(BOOTBIN) $@
	truncate -s 1474560 $@

floppy: $(FLOPPY)

run: $(FLOPPY)
	qemu-system-i386 -drive file=$(FLOPPY),format=raw,if=floppy -boot a -m 32

# скриншот экрана виртуальной машины (для отчёта)
shot: $(FLOPPY)
	./tools/screenshot.sh $(FLOPPY) screenshots/boot.png

clean:
	rm -rf $(BUILD)
