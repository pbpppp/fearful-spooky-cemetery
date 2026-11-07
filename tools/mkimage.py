#!/usr/bin/env python3
"""Собирает образ жёсткого диска с MBR.

На вход три готовых сектора:
  * MBR  - загрузочная запись, которая читает VBR и передаёт ему управление;
  * VBR  - загрузчик, лежит первым сектором первого раздела;
  * FONT - сектор шрифта, лежит сразу за загрузчиком (загрузчик читает его
           сам через int 13h по LBA 2049).
В MBR дописывается таблица разделов (байты 446..509): один раздел,
активный, тип 0Ch, начало - 2048-й сектор.

    ./tools/mkimage.py build/mbr.bin build/boot.bin build/font16.bin build/disk.img [МиБ]
"""

import struct
import sys

SRC_MBR, SRC_VBR, SRC_FONT, DST = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
SIZE_MIB = int(sys.argv[5]) if len(sys.argv) > 5 else 16

SECTOR = 512
START_LBA = 2048            # первый раздел начинается с 1 МиБ, как принято
SPT, HEADS = 63, 255        # геометрия для CHS-полей таблицы


def chs(lba):
    """Номер дорожки/головки/сектора для LBA (нужен старым BIOS)."""
    cyl = lba // (SPT * HEADS)
    head = (lba // SPT) % HEADS
    sect = lba % SPT + 1
    return bytes([head, (sect & 0x3F) | ((cyl >> 2) & 0xC0), cyl & 0xFF])


def read_sector(path):
    data = open(path, "rb").read()
    if len(data) != SECTOR:
        sys.exit(f"{path}: ожидался сектор 512 байт, получено {len(data)}")
    return data


def main():
    mbr = read_sector(SRC_MBR)
    vbr = read_sector(SRC_VBR)
    font = read_sector(SRC_FONT)
    if mbr[510:512] != b"\x55\xAA" or vbr[510:512] != b"\x55\xAA":
        sys.exit("в загрузочных секторах нет сигнатуры 55AA")

    total = SIZE_MIB * 1024 * 1024 // SECTOR
    last = total - 1

    # одна запись в таблице разделов: 16 байт
    entry = (
        b"\x80"                             # активный раздел
        + chs(START_LBA)                    # первый сектор
        + b"\x0c"                           # тип раздела
        + chs(last)                         # последний сектор
        + struct.pack("<II", START_LBA, total - START_LBA)
    )
    table = entry + bytes(48)               # остальные три записи пустые

    img = bytearray(SIZE_MIB * 1024 * 1024)
    img[0:SECTOR] = mbr[:446] + table + mbr[510:]
    img[START_LBA * SECTOR:(START_LBA + 1) * SECTOR] = vbr
    img[(START_LBA + 1) * SECTOR:(START_LBA + 2) * SECTOR] = font

    with open(DST, "wb") as f:
        f.write(img)

    print(f"{DST}: {SIZE_MIB} МиБ, раздел {START_LBA}..{last}, "
          f"MBR -> VBR по LBA {START_LBA}, шрифт по LBA {START_LBA + 1}")


if __name__ == "__main__":
    main()
