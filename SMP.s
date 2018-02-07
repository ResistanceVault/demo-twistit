; libSFX S-CPU to S-SMP Communication
; David Lindecrantz <optiroc@gmail.com>
; Transfer and I/O routines by Shay Green <gblargg@gmail.com>

; neutered version by Revenant for 64k intro

.include "libSFX.i"
.segment "LIBSFX"

;-------------------------------------------------------------------------------
;Transfer and execute SPC700 binary (a8i16)
;       A:X = Source (bank:offset)
;         Y = Destination (offset in SMP RAM)
;  ZPAD+$03 = Length (word)
;  ZPAD+$05 = Execution offset (word)
SFX_SMP_exec:
        stx     ZPAD+$00                ;Set 24-bit offset
        sta     ZPAD+$02

        ;SMP handshake, set destination
		sty     SMPIO2          ;Set address
        ldy     #$bbaa          ;Wait for SPC
:       cpy     SMPIO0
        bne     :-

        lda     #$cc            ;Send acknowledgement
        sta     SMPIO1
        sta     SMPIO0
:       cmp     SMPIO0          ;Wait for acknowledgement
        bne     :-

        ldy     #$0000          ;Initialize index
        ldx     ZPAD+$03                ;Length

:       lda     [ZPAD],y                ;Upload bytes
        sta     SMPIO1
        tya                     ;Signal it's ready
        sta     SMPIO0
:       cmp     SMPIO0          ;Wait for acknowledgement
        bne     :-
        iny
        dex
        bne     :--

        ldy     ZPAD+$05                ;Execute
        sty     SMPIO2
        stz     SMPIO1
        lda     SMPIO0
        inc     a
        inc     a
        sta     SMPIO0

:       cmp     SMPIO0          ;Wait for acknowledgement
        bne     :-
        rtl
