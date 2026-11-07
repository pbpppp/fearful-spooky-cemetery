; Практическая работа №1: загрузчик операционной системы.
; FASM, 16-битный реальный режим. BIOS загружает первые 512 байт
; носителя по адресу 0000:7C00 и передаёт управление на них.
;
; Рисовать попиксельно в текстовом режиме нельзя, поэтому переходим
; в графический режим 13h: 320x200, 256 цветов, видеопамять A000:0000,
; один байт = один пиксель, смещение = y*320 + x.
;
; Шрифт (кириллицы в ROM BIOS нет) лежит отдельным сектором сразу за
; загрузочным: загрузчик читает его через int 13h в память по адресу
; 0500h и рисует буквы уже своими пикселями.

org 7C00h

        jmp     start

; строки в кодировке CP866; цифры записаны кодами из свободных ячеек
; таблицы шрифта (см. src/font16.asm)
;                        Н    Е    К    Р    А    С    О    В
name:   db 08Dh, 085h, 08Ah, 090h, 080h, 091h, 08Eh, 082h
        db 020h                                         ; пробел
        db 082h, 080h, 084h, 088h, 08Ch                 ; В А Д И М
        db 020h                                         ; пробел
        db 080h, 08Dh, 084h, 090h, 085h, 085h, 082h, 088h, 097h
        db 0                                            ; Н А Д Р Е Е В И Ч
name_len = $ - name - 1

;                        Н    М    Т    -    3    4    3    9    0    1
group:  db 08Dh, 08Ch, 092h, 096h, 087h, 089h, 087h, 095h, 081h, 083h
        db 0
group_len = $ - group - 1

start:
        cli
        xor     ax, ax
        mov     ds, ax          ; ds = 0, строки и переменные лежат по 7Cxx
        mov     es, ax
        mov     ss, ax
        mov     sp, 7C00h       ; стек растёт вниз от начала загрузчика
        sti
        cld

; читаем шрифт: он лежит следующим сектором. На дискете это LBA 1,
; у раздела - LBA 2049 (сам загрузчик занимает первый сектор раздела)
        mov     [bootdrv], dl
        mov     ax, 1
        test    dl, 80h         ; старший бит dl: 1 - жёсткий диск
        jz      .lba
        mov     ax, 2049
.lba:
        mov     [dap+8], ax
        mov     si, dap
        mov     dl, [bootdrv]
        mov     ah, 42h         ; расширенное чтение сектора по LBA
        int     13h
        jnc     .fontok
; на дискете не всякий BIOS умеет читать по LBA - пробуем по CHS
; (дорожка 0, головка 0, сектор 2)
        mov     ax, 0201h
        mov     cx, 2
        mov     dh, 0
        mov     bx, 500h
        mov     dl, [bootdrv]
        int     13h
        jc      .nofont
.fontok:

        mov     ax, 0013h       ; графический режим 320x200x256
        int     10h

        mov     ax, 0A000h
        mov     es, ax

; подложка под текст: одна синяя плашка на обе строки
        mov     al, 01h
        mov     dx, 66
        mov     bp, 36
        call    fill_plate

; текст: чуть выше центра экрана, жёлтым по синему.
; x = (320 - 8*длина)/2, длина известна при ассемблировании
        mov     si, name
        mov     cx, 160 - name_len*4
        mov     dx, 68
        mov     bl, 0Eh
        call    print_str

        mov     si, group
        mov     cx, 160 - group_len*4
        mov     dx, 86
        mov     bl, 0Eh
        call    print_str

; овал 120x56 в нижней половине экрана
        call    draw_oval

        xor     ah, ah          ; ждём нажатия клавиши
        int     16h
        int     19h             ; и перезагружаемся

.nofont:
        int     18h             ; шрифт не прочитался - загружаться нечем

; ------------------------------------------------------------------
; fill_plate: залить подложку под текст цветом al
;   dx = верхняя строка, bp = сколько строк, ширина 240 точек по центру
; ------------------------------------------------------------------
fill_plate:
        push    ax
        push    bx
        push    cx
        push    di
.row:
        imul    di, dx, 320
        add     di, 40          ; отступ слева
        mov     cx, 240
        push    ax
        rep     stosb
        pop     ax
        inc     dx
        dec     bp
        jnz     .row
        pop     di
        pop     cx
        pop     bx
        pop     ax
        ret

; ------------------------------------------------------------------
; plot_pixel: закрасить пиксель
;   cx = x (0..319), dx = y (0..199), al = цвет (0..255)
;   es должен указывать на A000h
; ------------------------------------------------------------------
plot_pixel:
        push    di
        imul    di, dx, 320     ; y*320 (386-я команда, в реальном режиме работает)
        add     di, cx
        mov     [es:di], al
        pop     di
        ret

; ------------------------------------------------------------------
; draw_oval: контур овала с центром (160,150), полуоси 60 и 28.
;   Алгоритм средней точки (Bresenham) для эллипса: идём от середины
;   фигуры наружу, на каждом шаге рисуем четыре симметричные точки.
;   Состояние: ebx = dx, ebp = dy, esi = err (32 бита - без них
;   погрешность не помещается).
; ------------------------------------------------------------------
draw_oval:
        mov     ebx, -1492736   ; dx = 4*(1-a)*b*b
        mov     ebp, 57600      ; dy = 4*a*a
        mov     esi, -1435136   ; err = dx+dy
.loop:
        mov     al, 0Ah         ; цвет контура
        mov     cx, [ov_x1]     ; (x1,y0)
        mov     dx, [ov_y0]
        call    plot_pixel
        mov     cx, [ov_x0]     ; (x0,y0)
        call    plot_pixel
        mov     dx, [ov_y1]     ; (x0,y1)
        call    plot_pixel
        mov     cx, [ov_x1]     ; (x1,y1)
        call    plot_pixel

        mov     eax, esi
        add     eax, eax        ; e2 = 2*err
        cmp     eax, ebx        ; пока круто - шагаем по x
        jl      .no_x
        inc     word [ov_x0]
        dec     word [ov_x1]
        add     ebx, 25088      ; dx += 8*b*b
        add     esi, ebx        ; err += dx
.no_x:
        cmp     eax, ebp        ; пока полого - шагаем по y
        jg      .no_y
        inc     word [ov_y0]
        dec     word [ov_y1]
        add     ebp, 115200     ; dy += 8*a*a
        add     esi, ebp        ; err += dy
.no_y:
        mov     ax, [ov_x0]
        cmp     ax, [ov_x1]
        jbe     .loop
        ret

ov_x0:  dw 100                 ; левая точка
ov_x1:  dw 220                 ; правая точка
ov_y0:  dw 150                 ; нижняя точка (старт - середина фигуры)
ov_y1:  dw 150                 ; верхняя точка

; ------------------------------------------------------------------
; print_str: вывести строку в точку (cx, dx)
;   si = строка (заканчивается нулём), cx = x, dx = y, bl = цвет
;   шрифт - 8x16, лежит по адресу 0500h (32 глифа по 16 байт)
; ------------------------------------------------------------------
print_str:
        push    ax
        push    di
        push    bp
.next:
        mov     al, [si]
        inc     si
        test    al, al
        jz      .done
        cmp     al, 20h         ; пробел: просто сдвигаемся
        jne     .glyph
        add     cx, 8
        jmp     .next
.glyph:
        sub     al, 80h         ; код CP866 -> номер глифа
        xor     ah, ah
        mov     di, ax          ; в таблице по 16 байт на глиф
        shl     di, 4
        add     di, 500h        ; сюда прочитан сектор шрифта
        mov     bp, 16          ; в знакоместе 16 строк
        push    dx              ; y знакоместа
.row:
        mov     ah, [di]        ; биты одной строки глифа
        inc     di
        push    cx
        push    bp
        mov     bp, 8           ; и 8 точек в строке
.bit:
        test    ah, 80h
        jz      .skip
        mov     al, bl          ; точка принадлежит букве
        call    plot_pixel
.skip:
        shl     ah, 1
        inc     cx
        dec     bp
        jnz     .bit
        pop     bp
        pop     cx
        inc     dx
        dec     bp
        jnz     .row
        pop     dx              ; к началу следующего знакоместа
        add     cx, 8           ; следующая буква правее
        jmp     .next
.done:
        pop     bp
        pop     di
        pop     ax
        ret

; номер загрузочного диска от BIOS
bootdrv: db 0

; ------------------------------------------------------------------
; dap: пакет для int 13h/42h - один сектор в 0000:0500
; ------------------------------------------------------------------
dap:    db 10h, 0               ; размер пакета
        dw 1                    ; сколько секторов
        dw 500h, 0              ; куда читать
        dq 1                    ; номер сектора (LBA), заполняется выше

        db 510-($-$$) dup 0
        dw 0AA55h               ; признак загрузочного сектора
