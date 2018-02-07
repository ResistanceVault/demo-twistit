.include "global.i"

;-------------------------------------------------------------------------------
.segment "ZEROPAGE": zeropage

TextDrawPtr: .res 2
TextOAMPtr: .res 2
TextDrawWait: .res 2

TwistPos: .res 2

; control which scanlines each twister is actually visible on
; (for transtions)
Twist1MinY: .res 2
Twist1MaxY: .res 2

Twist2MinY: .res 2
Twist2MaxY: .res 2

;-------------------------------------------------------------------------------
.segment "LORAM"

; X+Y scroll HDMA tables for BG1 and BG2
TwistPosTable1: .res 224*4 ; 2 x bytes + 2 y bytes
TwistPosTable2: .res 224*4 ; 2 x bytes + 2 y bytes

; color math enable table for BG2 (controls bg2 blend switching)
TwistMapTable: .res 224

; palette HDMA tables
TwistColorTable1: .res 224*2
TwistColorTable2: .res 224*2
TwistColorTable3: .res 224*2
TwistColorTable4: .res 224*2

;-------------------------------------------------------------------------------
.segment "ROM0" ; putting here to save space in ROM1

incbin TwistTiles, "data/twist.png.tiles.lz4"
incbin TwistMap, "data/twist.png.map.lz4"

;-------------------------------------------------------------------------------
.segment "RODATA"

IntroText:
.include "data/introtext.i"

TwistPosPtrTable1:
.byte $80+127
.word .loword(TwistPosTable1)
.byte $80+97
.word .loword(TwistPosTable1+508)
.byte 0

TwistPosPtrTable2:
.byte $80+127
.word .loword(TwistPosTable2)
.byte $80+97
.word .loword(TwistPosTable2+508)
.byte 0

TwistMapPtrTable:
.byte $80+127
.word .loword(TwistMapTable)
.byte $80+97
.word .loword(TwistMapTable+127)
.byte 0

TwistColorClearTable:
.repeat 2
	.byte $ff
	.repeat 127
		.byte 4
	.endrepeat
.endrepeat
.byte 0

TwistColorPtrTable1:
.byte $80+127
.word .loword(TwistColorTable1)
.byte $80+97
.word .loword(TwistColorTable1+254)
.byte 0

TwistColorPtrTable2:
.byte $80+127
.word .loword(TwistColorTable2)
.byte $80+97
.word .loword(TwistColorTable2+254)
.byte 0

TwistColorPtrTable3:
.byte $80+127
.word .loword(TwistColorTable3)
.byte $80+97
.word .loword(TwistColorTable3+254)
.byte 0

TwistColorPtrTable4:
.byte $80+127
.word .loword(TwistColorTable4)
.byte $80+97
.word .loword(TwistColorTable4+254)
.byte 0

TwistSineTable:
.include "data/twistsine.i"

; color tables
.include "data/twistcolor.i"

;-------------------------------------------------------------------------------
.segment "CODE"

; VRAM addresses for twister texture
VRAM_TILEMAP       = $0000
VRAM_TILEMAP2      = $1000
VRAM_CHARSET       = $2000

;-------------------------------------------------------------------------------
proc InitTextSprites
	jsl ClearMainSprites

	; use all but the last four OAM slots for text
	; which gives us 28 chars per line, 9 lines per page

	LINE_SPACING = 16
	LETTER_SPACING = 10
	
	; sprite X coords
	ldx #0
	clc
	lda #28
:
	sta OAM_low,x
	sta OAM_low+(20*4),x
	sta OAM_low+(20*8),x
	sta OAM_low+(20*12),x
	sta OAM_low+(20*16),x
	sta OAM_low+(20*20),x
	adc #LETTER_SPACING
	inx
	inx
	inx
	inx
	cpx #20*4
	bcc :-
	
	; sprite Y coords
	ldx #0
	clc
:
	lda #48
	sta OAM_low+1,x
	adc #LINE_SPACING
	sta OAM_low+1+(20*4),x
	adc #LINE_SPACING
	sta OAM_low+1+(20*8),x
	adc #LINE_SPACING
	sta OAM_low+1+(20*12),x
	adc #LINE_SPACING
	sta OAM_low+1+(20*16),x
	adc #LINE_SPACING
	sta OAM_low+1+(20*20),x
	inx
	inx
	inx
	inx
	cpx #20*4
	bcc :-
	
	; sprite attributes (max priority, palette #0, low tile num)
	lda #%00110000
	ldx #0
:
	sta OAM_low+3,x
	sta OAM_low+3+(20*4),x
	sta OAM_low+3+(20*8),x
	sta OAM_low+3+(20*12),x
	sta OAM_low+3+(20*16),x
	sta OAM_low+3+(20*20),x
	inx
	inx
	inx
	inx
	cpx #20*4
	bcc :-
	
	rts
endproc

;-------------------------------------------------------------------------------
proc InitTwistGfx
	; load twister graphics
	LZ4_decompress TwistMap, EXRAM, y
	WAIT_vbl
	VRAM_memcpy VRAM_TILEMAP, EXRAM, y
	
	LZ4_decompress TwistTiles, EXRAM, y
	WAIT_vbl
	VRAM_memcpy VRAM_CHARSET, EXRAM, y
	
	rts
endproc

;-------------------------------------------------------------------------------
proc UpdateText
	ldx z:TextDrawWait
	beq :+
	dex
	stx z:TextDrawWait
	bra end
	
	; get next char
:
	ldx z:TextOAMPtr
	ldy z:TextDrawPtr
	
	lda IntroText,y
	bne :+
	
	; end of text - exit part
	VBL_task VBLTask_HideTwisters
	lda #$40
	tsb z:PartStatus
	
	bra end

:
	; otherwise set sprite char
	sta OAM_low+2,x
	iny
	sty z:TextDrawPtr
	inx
	inx
	inx
	inx
	stx z:TextOAMPtr
	cpx #(20*6*4)
	bcc end
	
	; end of page - wait a while
	ldx #0
	stx z:TextOAMPtr
	ldx IntroText,y
	stx z:TextDrawWait
	iny
	iny
	sty z:TextDrawPtr
	
end:
	rts
endproc
	
; -----------------------------------------------------
; vblank thread - manage DMA/HDMA, perform effect tasks
; -----------------------------------------------------

;-------------------------------------------------------------------------------
proc TwistPartVBL
	; make sure DB is correct (will apply to VBLTask too)
	phk
	plb

	; enable HDMA
	HDMA_set_absolute 0, 0, CGADD, TwistColorClearTable
	HDMA_set_indirect 1, 2, CGDATA, TwistColorPtrTable1, TwistColorTable1
	HDMA_set_indirect 2, 2, CGDATA, TwistColorPtrTable2, TwistColorTable2
	HDMA_set_indirect 3, 2, CGDATA, TwistColorPtrTable3, TwistColorTable3
	HDMA_set_indirect 4, 2, CGDATA, TwistColorPtrTable4, TwistColorTable4
	
	HDMA_set_indirect 5, 3, BG1HOFS, TwistPosPtrTable1, TwistPosTable1
	HDMA_set_indirect 6, 3, BG2HOFS, TwistPosPtrTable2, TwistPosTable2
	HDMA_set_indirect 7, 0, CGADSUB, TwistMapPtrTable, TwistMapTable
	
	RW a8
	lda #$ff
	sta HDMAEN
	
	bit z:PartStatus
	bvs :+
	jsr UpdateText
:	
	rtl
endproc

;-------------------------------------------------------------------------------
; vblank task 1 - fade screen in
proc VBLTask_FadeIn
	lda z:SFX_tick
	; increase brightness on every 2nd tick
	and #$01
	bne end
	
	lda z:SFX_inidisp
	and #$7f
	; fade in done?
	cmp #$0f
	beq :+
	inc
	sta z:SFX_inidisp
	rtl
	
:
	; next task
	; show first twister after a few seconds
	VBL_task VBLTask_ShowTwister1, 60*6
end:
	rtl
endproc

;-------------------------------------------------------------------------------
; vblank task 2 - introduce first twister
proc VBLTask_ShowTwister1
	ldx z:Twist1MinY
	dex
	dex
	stx z:Twist1MinY
	bne end
	
	; next task
	; show first twister after a few more seconds
	VBL_task VBLTask_ShowTwister2, 60*6
end:
	rtl
endproc

;-------------------------------------------------------------------------------
; vblank task 3 - introduce second twister

proc VBLTask_ShowTwister2
	ldx z:Twist2MinY
	dex
	dex
	stx z:Twist2MinY
	bne end
	
	; last task will be set once text ends
	VBL_task_stop
end:
	rtl
endproc

;-------------------------------------------------------------------------------
; final vblank task - remove twisters

proc VBLTask_HideTwisters
	ldx z:Twist1MinY
	inx
	inx
	stx z:Twist1MinY
	ldx z:Twist2MaxY
	dex
	dex
	stx z:Twist2MaxY
	bne end
	
	VBL_task_stop
	lda #$80 ; signal to exit part
	tsb z:PartStatus
end:
	rtl
endproc

; ----------------------------------------------
; main thread - do all init & run twister effect
; ----------------------------------------------

proc TwistPartMain
	phb
	phk
	plb

	VBL_part_stop
	
	jsr InitTwistGfx

	WAIT_vbl
	; BG1 is used for the main twister, BG2 is used for the translucent twister
	; and color math settings is switched to do 'in front/behind' effect
	
	; set up screen (mode 1, all 8x8 tiles)
	lda #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
	sta BGMODE
	
	; set up layer 1 + 2 tilemaps
	lda #bgsc(VRAM_TILEMAP, SC_SIZE_64X32)
	sta BG1SC
	
	lda #bgsc(VRAM_TILEMAP2, SC_SIZE_64X32)
	sta BG2SC
	
	; set up tileset for layers 1 + 2
	lda #bg12nba(VRAM_CHARSET, VRAM_CHARSET)
	sta BG12NBA

	; disable any previous HDMA stuff
	stz HDMAEN
	
	; enable layer 1, 3 and sprites on mainscreen
	lda #tm(ON, OFF, ON, OFF, ON)
	sta TM
	; enable layer and 2 on subscreen (for the blend)
	lda #tm(OFF, ON, OFF, OFF, OFF)
	sta TS
	
	; set up color math	
	lda #$00 ; color math on entire screen
	sta WOBJSEL
	lda #$02 ; enable sub screen BG/OBJ color math
	sta CGSWSEL
	
	lda #$e0
	sta COLDATA
	
	; clear Y-offset tables
	RW_push set:a16
	lda #$ffff
	ldx #0
:
	stz TwistPosTable1,x ; X
	stz TwistPosTable2,x ; X
	inx
	inx
	sta TwistPosTable1,x ; Y
	sta TwistPosTable2,x ; Y
	inx
	inx
	dec
	cpx #(224*4)
	bcc :-
	RW_pull
	
	; clear BG2 map table
	ldx #0
	lda #0
:
	sta TwistMapTable,x
	inx
	cpx #224
	bcc :-
	
	jsr InitTextSprites
	jsr TwistPosPrecalc
	
	; set initial vblank task
	VBL_part TwistPartVBL
	VBL_task VBLTask_FadeIn
	
	; set initial text delay
	ldx #60
	stx z:TextDrawWait
	; reset text
	ldx #0
	stx z:TextDrawPtr
	stx z:TextOAMPtr
	
	; set initial twist positions
	ldx #224
	stx z:Twist1MinY
	stx z:Twist1MaxY
	stx z:Twist2MinY
	stx z:Twist2MaxY
	
loop:
	WAIT_vbl
	jsr UpdateTwistPos1
	WAIT_vbl
	jsr UpdateTwistPos2
	
	bit z:PartStatus
	bpl loop
	
	WAIT_vbl
	; turn off twist graphics
	lda #tm(OFF, OFF, ON, OFF, ON)
	sta TM
	stz TS
	
	VBL_part_stop
	stz z:PartStatus
	plb
	rtl
endproc
	
;-------------------------------------------------------------------------------
; ----------------------------------
; calculate some twister sine tables
; ----------------------------------
	
TwistPosBase    = HIRAM
TwistPosBaseAdd = HIRAM+$1000

proc TwistPosPrecalc
	php
	RW a16i16
	
	ldx #0
:
	txa
	lsr
	pha
	asl
	pha
	asl
	clc
	adc 1,s
	adc 3,s
	ply
	ply
	and #$7fe
	tay
	lda TwistSineTable,y
	sta f:TwistPosBase,x
	
	inx
	inx
	cpx #$1000
	bcc :-
	
	ldx #0
:
	txa
	asl
	tay
	lda TwistSineTable,y
;	lsr
	clc
;	adc TwistSineTable,y
;	lsr
	lsr
	lsr
	sta f:TwistPosBaseAdd,x
	inx
	inx
	cpx #$400
	bcc :-
	
	plp
	rts
endproc

;-------------------------------------------------------------------------------
; -------------------------- 
; BG1 twister update routine
; --------------------------

cy   = ZPAD+0 ; decrements each line
cy2  = ZPAD+2 ; increments each line
sin1 = ZPAD+4
PhaseColor = ZPAD+6

proc UpdateTwistPos1
	php
	
	RW a16i16
	dec z:TwistPos
	stz z:cy
	stz z:cy2
	
	ldy #0
	
loop:
	; make sure we want to display this line right now
	ldx z:cy2
	cpx z:Twist1MinY
	bcc :+ ; less than min = don't show
	cpx z:Twist1MaxY
	bcc :++ ; less than max = do show
:	
	lda #$100
	sta TwistPosTable1,y
	sta TwistPosTable1+4,y
	jmp end
	
:
	; calc x for line
	; get base x value
	lda z:TwistPos
	asl
	and #$ffe
	tax
	lda f:TwistPosBase,x
	sta z:sin1
	
	; double sine with added y-term
	clc
	adc z:SFX_tick
	adc z:SFX_tick
	adc z:cy
	asl
	and #$3fe
	tax
	lda f:TwistPosBaseAdd,x
	lsr
	lsr
	sta TwistPosTable1,y
	sta TwistPosTable1+4,y

	; interpolate inbetween lines
	cpy #0
	beq :++
	pha
	adc TwistPosTable1-4,y
	cmp #$0100 ; was previous line offscreen?
	bcs :+
	lsr
	sta TwistPosTable1-4,y
:
	pla
:
	; calc y for line
	; get base twist value
	lda z:TwistPos
	clc
	adc z:sin1
	adc z:cy2
	adc z:cy2
	lsr
	lsr
	lsr
	clc
	adc z:sin1
	asl
	and #$7fe
	tax
	lda TwistSineTable,x
	
	; account for current scanline in scroll value
	pha
	clc
	adc z:cy
	
	sta TwistPosTable1+2,y
	dec
	sta TwistPosTable1+6,y
	
	; get color values
	pla
	and #$ff
	asl
	sta z:PhaseColor
	eor #$0100
	tax
	lda TwistColor1,x
	pha
	ldx z:PhaseColor
	lda TwistColor1,x
	pha
	; store color values to HDMA tables
	tya
	lsr
	tax
	pla
	sta TwistColorTable2,x
	sta TwistColorTable2+2,x
	pla
	sta TwistColorTable1,x
	sta TwistColorTable1+2,x
	
end:
	dec z:cy
	dec z:cy
	inc z:cy2
	inc z:cy2
	
	clc
	tya
	adc #8
	tay
	
	cpy #224*4
	jcc loop
	
	plp
	rts
endproc

;-------------------------------------------------------------------------------
; -------------------------- 
; BG2 twister update routine
; --------------------------

; table of distance/layer priority values
PRIO_TABLE_PHASE = 256
TwistPrioTest:
.repeat 512-PRIO_TABLE_PHASE
	.byte %00101100
.endrepeat
.repeat 512
	.byte %00101101
.endrepeat
.repeat PRIO_TABLE_PHASE
	.byte %00101100
.endrepeat

proc UpdateTwistPos2
	php
	
	RW a16i16
;	dec z:TwistPos
	stz z:cy
	stz z:cy2
	
	ldy #0

loop:
	; make sure we want to display this line right now
	ldx z:cy2
	cpx z:Twist2MinY
	bcc :+ ; less than min = don't show
	cpx z:Twist2MaxY
	bcc :++ ; less than max = do show
:	
	lda #$100
	sta TwistPosTable2,y
	sta TwistPosTable2+4,y
	jmp end
	
:
	; calc x for line
	; get base x value
	lda z:TwistPos
	asl
	and #$ffe
	tax
	lda f:TwistPosBase,x
	sta z:sin1
	
	; double sine with added y-term
	clc
	adc z:SFX_tick
	adc z:SFX_tick
	adc z:cy
	adc #$100 ; phase shift for #2
	asl
	and #$3fe
	tax
	
	; use the current sine position to determine layer visibility on this line
	phx
	lda TwistPrioTest,x
	ldx z:cy2
	sta TwistMapTable,x
	plx
	
	; and then update X position using same index
	lda f:TwistPosBaseAdd,x
;	lsr
	lsr
	sta TwistPosTable2,y
	sta TwistPosTable2+4,y

	; interpolate inbetween lines
	cpy #0
	beq :++
	pha
	adc TwistPosTable2-4,y
	cmp #$0100 ; was previous line offscreen?
	bcs :+
	lsr
	sta TwistPosTable2-4,y
:
	pla
:

	; calc y for line
	; get base twist value
	lda z:cy
	lsr
	lsr
	clc
	adc z:sin1
	asl
	and #$7fe
	tax
	lda TwistSineTable,x
	
	; account for current scanline in scroll value
	pha
	clc
	adc z:cy
	
	sta TwistPosTable2+2,y
	dec
	sta TwistPosTable2+6,y
	
	; get color values
	pla
	and #$ff
	asl
	sta z:PhaseColor
	eor #$0100
	tax
	lda TwistColor2,x
	pha
	ldx z:PhaseColor
	lda TwistColor2,x
	pha
	; store color values to HDMA tables
	tya
	lsr
	tax
	pla
	sta TwistColorTable4,x
	sta TwistColorTable4+2,x
	pla
	sta TwistColorTable3,x
	sta TwistColorTable3+2,x

end:
	dec z:cy
	dec z:cy
	inc z:cy2
	inc z:cy2
	
	clc
	tya
	adc #8
	tay
	
	cpy #224*4
	jcc loop
	
	plp
	rts
endproc
