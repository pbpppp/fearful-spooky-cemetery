; Загрузочная запись MBR (первые 512 байт диска).
;
; Само приложение целиком занимает 512 байт и лежит загрузочным сектором
; первого раздела (VBR, LBA 2048).  В MBR его положить нельзя: байты
; 446..509 первого сектора заняты таблицей разделов, а у приложения там
; шрифт.  Поэтому MBR только читает VBR и передаёт ему управление -
; так и работает загрузка на реальных машинах.

org 7C00h

LOADED  = 7C00h         ; BIOS грузит MBR сюда
RELOC   = 600h          ; сюда переносим свой код (см. ниже)
VBR_LBA = 2048          ; начало первого раздела

        jmp     start
        nop

start:
        cli
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, LOADED
        sti
        cld

; VBR тоже грузится по адресу 7C00h, то есть прямо на этот код, поэтому
; сначала копируем себя пониже и продолжаем работу уже из копии.
        mov     si, LOADED
        mov     di, RELOC
        mov     cx, 256
        rep     movsw
        jmp     0:(low_start - LOADED + RELOC)

; --- дальше исполняется копия по адресу RELOC ---
low_start:
        mov     si, (dap - LOADED + RELOC)
        mov     ah, 42h         ; расширенное чтение (LBA)
        int     13h
        jc      fail
        jmp     0:LOADED        ; передаём управление VBR

fail:
        int     18h             ; загружаться не с чего

dap:                            ; disk address packet
        db 10h, 0
        dw 1                    ; один сектор
        dw LOADED, 0            ; куда читать
        dq VBR_LBA

        db 446-($-$$) dup 0     ; код и данные MBR: максимум 446 байт
        db 64 dup 0             ; таблица разделов (заполняет tools/mkimage.py)
        dw 0AA55h
