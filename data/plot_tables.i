; the high byte of buffer addresses for 128 rows of pixels
AddrMSBForY:
.byte >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0
.byte >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0, >DrawBuf+0
.byte >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1
.byte >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1, >DrawBuf+1
.byte >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2
.byte >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2, >DrawBuf+2
.byte >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3
.byte >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3, >DrawBuf+3
.byte >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4
.byte >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4, >DrawBuf+4
.byte >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5
.byte >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5, >DrawBuf+5
.byte >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6
.byte >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6, >DrawBuf+6
.byte >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7
.byte >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7, >DrawBuf+7

; the beginning low byte of buffer addresses for 128 rows of pixels
AddrLSBForY:
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $10, $30, $50, $70, $90, $b0, $d0, $f0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $10, $30, $50, $70, $90, $b0, $d0, $f0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $10, $30, $50, $70, $90, $b0, $d0, $f0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $10, $30, $50, $70, $90, $b0, $d0, $f0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $10, $30, $50, $70, $90, $b0, $d0, $f0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $10, $30, $50, $70, $90, $b0, $d0, $f0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $10, $30, $50, $70, $90, $b0, $d0, $f0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0, $10, $30, $50, $70, $90, $b0, $d0, $f0

; the offsets into the buffer for 128 columns of pixels
AddrLSBForX:
.byte $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
.byte $02, $02, $02, $02, $02, $02, $02, $02, $03, $03, $03, $03, $03, $03, $03, $03
.byte $04, $04, $04, $04, $04, $04, $04, $04, $05, $05, $05, $05, $05, $05, $05, $05
.byte $06, $06, $06, $06, $06, $06, $06, $06, $07, $07, $07, $07, $07, $07, $07, $07
.byte $08, $08, $08, $08, $08, $08, $08, $08, $09, $09, $09, $09, $09, $09, $09, $09
.byte $0a, $0a, $0a, $0a, $0a, $0a, $0a, $0a, $0b, $0b, $0b, $0b, $0b, $0b, $0b, $0b
.byte $0c, $0c, $0c, $0c, $0c, $0c, $0c, $0c, $0d, $0d, $0d, $0d, $0d, $0d, $0d, $0d
.byte $0e, $0e, $0e, $0e, $0e, $0e, $0e, $0e, $0f, $0f, $0f, $0f, $0f, $0f, $0f, $0f

.ifndef FILL_VECTORS

; the bits to OR for 128 columns of pixels (wireframe mode)
AddrBitForX:
.byte $80, $40, $20, $10, $08, $04, $02, $01, $80, $40, $20, $10, $08, $04, $02, $01
.byte $80, $40, $20, $10, $08, $04, $02, $01, $80, $40, $20, $10, $08, $04, $02, $01
.byte $80, $40, $20, $10, $08, $04, $02, $01, $80, $40, $20, $10, $08, $04, $02, $01
.byte $80, $40, $20, $10, $08, $04, $02, $01, $80, $40, $20, $10, $08, $04, $02, $01
.byte $80, $40, $20, $10, $08, $04, $02, $01, $80, $40, $20, $10, $08, $04, $02, $01
.byte $80, $40, $20, $10, $08, $04, $02, $01, $80, $40, $20, $10, $08, $04, $02, $01
.byte $80, $40, $20, $10, $08, $04, $02, $01, $80, $40, $20, $10, $08, $04, $02, $01
.byte $80, $40, $20, $10, $08, $04, $02, $01, $80, $40, $20, $10, $08, $04, $02, $01

.else

; the bits to OR for 128 columns of pixels (filling from left edge)
AddrLeftFillBitForX:
.byte $ff, $7f, $3f, $1f, $0f, $07, $03, $01, $ff, $7f, $3f, $1f, $0f, $07, $03, $01
.byte $ff, $7f, $3f, $1f, $0f, $07, $03, $01, $ff, $7f, $3f, $1f, $0f, $07, $03, $01
.byte $ff, $7f, $3f, $1f, $0f, $07, $03, $01, $ff, $7f, $3f, $1f, $0f, $07, $03, $01
.byte $ff, $7f, $3f, $1f, $0f, $07, $03, $01, $ff, $7f, $3f, $1f, $0f, $07, $03, $01
.byte $ff, $7f, $3f, $1f, $0f, $07, $03, $01, $ff, $7f, $3f, $1f, $0f, $07, $03, $01
.byte $ff, $7f, $3f, $1f, $0f, $07, $03, $01, $ff, $7f, $3f, $1f, $0f, $07, $03, $01
.byte $ff, $7f, $3f, $1f, $0f, $07, $03, $01, $ff, $7f, $3f, $1f, $0f, $07, $03, $01
.byte $ff, $7f, $3f, $1f, $0f, $07, $03, $01, $ff, $7f, $3f, $1f, $0f, $07, $03, $01

; the bits to OR for 128 columns of pixels (filling from right edge)
AddrRightFillBitForX:
.byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff
.byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff
.byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff
.byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff
.byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff
.byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff
.byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff
.byte $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff

.endif ; FILL_VECTORS
