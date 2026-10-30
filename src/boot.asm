; Практическая работа №1: загрузчик операционной системы.
; FASM, 16-битный реальный режим. BIOS загружает первые 512 байт
; носителя по адресу 0000:7C00 и передаёт управление на них.

org 7C00h

        jmp     start

msg:    db 'boot sector is alive', 0

start:
        cli
        xor     ax, ax
        mov     ds, ax          ; ds = 0, строки и переменные лежат по 7Cxx
        mov     es, ax
        mov     ss, ax
        mov     sp, 7C00h       ; стек растёт вниз от начала загрузчика
        sti

        mov     ax, 0B800h      ; текстовый видеобуфер
        mov     es, ax
        mov     di, 2*(12*80 + 30)
        mov     si, msg
        mov     ah, 0Eh         ; жёлтый символ на чёрном фоне
.loop:
        lodsb
        test    al, al
        jz      .done
        stosw
        jmp     .loop

.done:
        jmp     $               ; останов

        db 510-($-$$) dup 0
        dw 0AA55h               ; признак загрузочного сектора
