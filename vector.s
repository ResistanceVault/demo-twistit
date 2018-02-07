.include "global.i"

;-------------------------------------------------------------------------------
.segment "ZEROPAGE": zeropage

ObjectSinePos: .res 1
ObjectStayOnDelay: .res 2

ScrollTextIndex: .res 2 ; pointer into text
ScrollPhaseShift: .res 1 ; adjust sine when updating chars

; indexes into delta angle table
DeltaXPos: .res 1
DeltaYPos: .res 1
DeltaZPos: .res 1

;-------------------------------------------------------------------------------
.segment "LORAM"

ObjMoveXSine: .res 256
ObjMoveYSine: .res 256
TextMoveSine: .res 256

;-------------------------------------------------------------------------------
.segment "CODE"

TEXT_BUFFER = EXRAM ; TODO: change if we use part of EXRAM as a trig/mult table later

incbin VectorPartText, "data/introtext2.txt.lz4"

;-------------------------------------------------------------------------------
proc InitScrollSprites
	jsl ClearMainSprites

SPRITE_X_DIST = 8

	; set high X bit for sprite 32 so it can go off left edge of screen
	; (and sprites 0-31 form the rest)
	lda #%00000001
	sta OAM_high+8
	
	ldx #0
	lda #1 ; decrease 2 px every frame, x=$ff on wrap
:
	; init sprite X
	sta OAM_low,x
	inx
	clc
	adc #SPRITE_X_DIST
	pha
	; init sprite Y to 240 (will update during scroll)
	lda #240
	sta OAM_low,x
	inx
	; init sprite char #s
	lda #$20
	sta OAM_low,x
	inx
	; init sprite attributes (max priority, palette #4 (for color math), low tile num)
	lda #%00111000
	sta OAM_low,x
	inx
	pla
	cpx #33*4
	bcc :-
	
	; position off-screen sprite properly
	lda #$f8
	sta OAM_low+(32*4)
	
	rts
endproc

;-------------------------------------------------------------------------------
; called in vectorplot.s during NMI (after frame DMA)
proc UpdateScrollText
	RW_push set:a8i8
	; update Y sine curve (applies to scroller even when vector isn't on screen
	jsr UpdateYSine
	
	lda z:SFX_tick
	clc
	adc z:ScrollPhaseShift
	tay
	
	; move offscreen char (Y)
	dec OAM_low+4*32
	dec OAM_low+4*32
	
	; update remaining chars except for leftmost onscreen one (#1-32)
.repeat 31, i
	; update X position
	dec OAM_low+((31-i)*4)
	dec OAM_low+((31-i)*4)
	; update Y position
	lda TextMoveSine,y
	clc
	adc z:VectorY
	sta OAM_low+((31-i)*4)+1
	iny
	iny
.endrep

	; update leftmost char and see if we need to fetch a new char
	lda TextMoveSine,y
	clc
	adc z:VectorY
	sta OAM_low+1
	iny
	iny
	dec OAM_low
	dec OAM_low
	jpl end
	
	; move other chars
	lda OAM_low+2
	sta OAM_low+(32*4)+2
	phy
	memcpy OAM_low, OAM_low+4, 31*4
	ply
	; move new char and offscreen char over
	lda #$ff
	sta OAM_low+4*31
	sta OAM_low+4*32
	; update sine adjustment
	dey
	dey
	dec z:ScrollPhaseShift
	dec z:ScrollPhaseShift
	; get new char
	stz OAM_low+(31*4)+2
	bit z:PartStatus
	bvs end
	RW i16
	ldx z:ScrollTextIndex
	lda f:TEXT_BUFFER,x
	sta OAM_low+(31*4)+2
	bne :+
	lda #$40
	tsb z:PartStatus
:	inx
	stx z:ScrollTextIndex
	
end:
	RW_assume i8
	; move offscreen char (Y)
	lda TextMoveSine,y
	clc
	adc z:VectorY
	sta OAM_low+4*32+1
	
	RW_pull
	rts
endproc

;-------------------------------------------------------------------------------
proc VectorPartMain
	phb
	phk
	plb

	jsr VectorPartInit
	
	lda #$f0
	sta z:VectorX
	lda #$18
	sta z:VectorY

	stz z:ObjectSinePos
	ldx #0
	stx z:ObjectStayOnDelay
	
	; setup sine tables
	ldx #$1fe
	ldy #$ff
:
	RW a16
	lda SinTable,x
	asr
	asr
	RW a8
	clc
	adc #$40
	sta ObjMoveXSine,y
	lsr
	lsr
	adc #$38
	sta ObjMoveYSine,y
	dex
	dex
	dey
	bpl :-
	; sine table for scroller Y movement
	ldx #$1fe
	ldy #$7f
:
	RW a16
	lda SinTable,x
	asr
	asr
	asr
	RW a8
	clc
	adc #$40
	sta TextMoveSine,y
	sta TextMoveSine+$80,y
	dex
	dex
	dex
	dex
	dey
	bpl :-
	
	; decompress text and set up sprites
	LZ4_decompress VectorPartText, TEXT_BUFFER, x
	lda #0
	sta f:TEXT_BUFFER,x
	jsr InitScrollSprites
	
	ldx #0
	stx z:ScrollTextIndex
	stz z:ScrollPhaseShift
	
	lda #$10
	sta z:DeltaXPos
	lda #$20
	sta z:DeltaYPos
	lda #$80
	sta z:DeltaZPos
	
	lda #0
	jsr SetObj
	
	; set initial vblank task
	VBL_part VectorPartVBL
	VBL_task VBLTask_ObjIntro
	
loop:
:	lda z:BufferReady
	bne :- ; still waiting to DMA previous rendered frame
	
	; apply new rotation angles if we were finished rendering with the last ones
	jsr UpdateVertex

	jsr UpdateBuffer
	
	bit z:PartStatus
	bpl loop
		
	; eventually break out somehow to next part
	WAIT_vbl
	VBL_part_stop
	stz z:PartStatus
	plb
	rtl
endproc

;-------------------------------------------------------------------------------
DeltaAngleTable:
.include "data/deltasine.i"

;-------------------------------------------------------------------------------
proc UpdateYSine, a8i8
	ldx z:SFX_tick
	lda ObjMoveYSine,x
	sta z:VectorY
	rts
endproc

;-------------------------------------------------------------------------------
proc UpdateXSine, a8i8
	ldx z:ObjectSinePos
	lda ObjMoveXSine,x
	sta z:VectorX
	rts
endproc

;-------------------------------------------------------------------------------
proc UpdateDeltas
	; increase X at +1
	inc z:DeltaXPos
	; increase Y at +1.5
	lda z:SFX_tick
	lsr
	lda z:DeltaYPos
	adc #1
	sta z:DeltaYPos
	; decrease Z at -1
	dec z:DeltaZPos
	rts
endproc

;-------------------------------------------------------------------------------
proc SetObj
	pha
	RW_push set:i8
	ldx z:DeltaXPos
	lda DeltaAngleTable,x
	sta z:DeltaX
	ldx z:DeltaYPos
	lda DeltaAngleTable,x
	sta z:DeltaY
	ldx z:DeltaZPos
	lda DeltaAngleTable,x
	sta z:DeltaZ
	RW_pull
	lda #0
	xba
	pla
	sta z:CurrObj
	asl
	tax
	jmp (.loword(:+),x)

: .word obj0, obj1
	
obj0:
	; palette/window colors will be set during vblank based on angles
	
;	lda #$7f ; perform color math on all main screen layers, divide result
	lda #$3f ; perform color math on all main screen layers
	sta CGADSUB
	
	; disable glenz
	lda #$80
	trb z:DrawFlags
	rts
	
obj1: ; glenz
	;ldx #rgb((60>>4), (150>>4), (255>>4))
	; test
	ldx #rgb(10, 10, 10)
	stx z:PaletteColors
	;ldx #rgb((0), (100>>4), (180>>4))
	; test
	ldx #rgb(2, 2, 2)
	stx z:PaletteColors+2
	;ldx #rgb((150>>4), (215>>4), (255>>4))
	; test
	ldx #rgb(15, 15, 15)
	stx z:PaletteColors+4
	
	lda #$88 ; dark blue/green
	sta z:WindowColors
	lda #$63
	sta z:WindowColors+1
	
	lda #$3f ; perform color math on all main screen layers
	sta CGADSUB
	
	; enable glenz
	lda #$80
	tsb z:DrawFlags
	rts
	
endproc

;-------------------------------------------------------------------------------
proc VBLTask_ObjIntro
	jsr UpdateDeltas
	
	; move object until it's centered horizontally
	lda z:VectorX
	dec
	dec
	sta z:VectorX
	cmp #$40
	bcs end

	lda #$80
	sta z:ObjectSinePos
	ldx #60*15 ; how long to show the current object
	stx z:ObjectStayOnDelay
	VBL_task VBLTask_RunObj
end:
	rtl
endproc

;-------------------------------------------------------------------------------
proc VBLTask_RunObj
	RW_push set:a8i8
	jsr UpdateDeltas
	jsr UpdateXSine
	RW_pull
	
	lda z:SFX_tick
	lsr
	lda z:ObjectSinePos
	adc #1
	sta z:ObjectSinePos
	
	bit z:PartStatus
	bvs :+
	ldx z:ObjectStayOnDelay
	bne :++
	; if time is up, wait until object is back at beginning of sine table
	; (centered on screen moving right)
:	lda z:ObjectSinePos
	bne end
	
	VBL_task VBLTask_ObjOutro
	bra end

:	dex
	stx z:ObjectStayOnDelay
end:
	rtl
endproc

;-------------------------------------------------------------------------------
proc VBLTask_ObjOutro
	jsr UpdateDeltas
	
	; move object until it's off screen
	lda z:VectorX
	inc
	inc
	sta z:VectorX
	cmp #$f8
	bcc end
	
	lda #$f8
	sta z:VectorX

	; switch objects (unless scroller has ended)
	bit z:PartStatus
	bvs :+
	lda z:CurrObj
	eor #$01
	bra :++
:
	; last shape or end of scroller = quit
	lda #$80
	tsb PartStatus
	VBL_task_stop
	bra end
	
:	
	jsr SetObj
	
	VBL_task VBLTask_ObjIntro, 60*2
end:
	rtl
endproc
