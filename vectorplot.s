.include "global.i"

MaxPoints = 14 ; number of points on the kiscube (most complex mesh i feel like attempting...)
MaxLines = 18 ; half the number of edges on the kiscube, in wireframe mode the rest (or more) will get culled

FILL_VECTORS = 1 ; 0 for wireframe mode
FILL_GLENZ = 1 ; 0 for shaded vectors if FILL_VECTORS = 1

;-------------------------------------------------------------------------------
.segment "ZEROPAGE": zeropage

; bit 7 - use glenz mode
; bit 6 - use slower (DMA-safe) polygon fill
DrawFlags: .res 1

CurrObj: .res 1

VertexX: .res MaxPoints
VertexY: .res MaxPoints
VertexZ: .res MaxPoints

AngleX: .res 1
AngleY: .res 1
AngleZ: .res 1

DeltaX: .res 1
DeltaY: .res 1
DeltaZ: .res 1
DeltaFrames: .res 1

VertexCount: .res 1

BufferReady: .res 1

PolyCount: .res 1
LineList: .res 2

PaletteColors: .res 6
WindowColors: .res 2

Plane1Normal: .res 1
Plane2Normal: .res 1
WindowNormal: .res 1

; for bresenham
; this probably belongs in zpad or something
; (but for this 2 part intro we probably have enough zeropage space anyway)
LineX1: .res 1
LineX2: .res 1
LineY1: .res 1
LineY2: .res 1
LineDX: .res 1
LineDY: .res 1
Line2DX: .res 1
Line2DY: .res 1
LineError: .res 1
LineAddError: .res 1
LineAddY: .res 1
LineSteep: .res 1

DrawPtr: .res 3 ; for points in wireframe mode or left edges in fill mode
DrawPtr2: .res 3 ; for right edges in fill mode

; position of vector object (top left corner)
VectorX: .res 1
VectorY: .res 2

; vector fill routines (changed based on drawflags)
FillSpan: .res 2
SkipSpan: .res 2

;-------------------------------------------------------------------------------
.segment "LORAM"

.if FILL_VECTORS = 1
	; assumes 128x128 render area
	SpansStart: .res 128
	SpansEnd: .res 128
	
	.struct SpansTable
		StartLineCount .byte
		StartLineValue .byte
		LineCount .byte
		LineValue .res 128
		EndLineCount .byte
	.endstruct
	
	SpansWindowStart: .res 128
	SpansWindowEnd: .res 128
	
	SpansUseWindowStart: .res 128
	SpansUseWindowEnd: .res 128
	
	SpansWindowStartTable: .tag SpansTable
	SpansWindowEndTable: .tag SpansTable
	
.else
	NumLinesDrawn: .res 2
	DrawnLines: .res (MaxLines*2)
.endif 

;-------------------------------------------------------------------------------
.segment "HIRAM"

DrawBuf: .res $1000

;-------------------------------------------------------------------------------
.segment "RODATA"

.include "data/plot_tables.i"
.include "data/objects.i"

;-------------------------------------------------------------------------------
.segment "CODE"

.include "bresenham.i"

; ----------------------------------------------------------------------------
; main code section
; ----------------------------------------------------------------------------

; VRAM addresses for vector draw buffer
VRAM_TILEMAP       = $0000
VRAM_CHARSET       = $2000

PolyFillByte: .byte $ff

;-------------------------------------------------------------------------------
proc VectorPartInit

	WAIT_vbl
	; temp. disable all layers except ones we want
	; put BG + sprites on main screen
	lda #tm(OFF, OFF, ON, OFF, ON)
	sta TM
	stz TS
	
	; disable any previous HDMA stuff
	stz HDMAEN
	
	; fix initial window position
	stz WH1
	
	; set up screen (mode 0, all 8x8 tiles)
	lda #bgmode(BG_MODE_0, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
	sta BGMODE
	
	; set up layer 1
	lda #bgsc(VRAM_TILEMAP, SC_SIZE_64X32)
	sta BG1SC
	lda #bg12nba(VRAM_CHARSET, VRAM_CHARSET)
	sta BG12NBA

	; set up vector pixel buffer
	WAIT_vbl
	VRAM_memset VRAM_CHARSET, $1000
	
	WRAM_memset EXRAM, $1000, 0
	
	RW a16
	lda #$0000 ; tiles $000 +, palette 0
	ldx #0
:
	.repeat 16
		sta f:EXRAM,x
		inc
		inx
		inx
	.endrep
	tay
	txa
	clc
	adc #$20
	tax
	tya
	cpx #$400
	bcc :-
	RW a8
	
	WAIT_vbl
	VRAM_memcpy VRAM_TILEMAP, EXRAM, $1000
	
	stz CurrObj
	stz VectorX
	stz VectorY
	
	lda #$7e
	sta z:DrawPtr+2
	sta z:DrawPtr2+2

.if ::FILL_VECTORS = 1
	; set up DMA channel 4 for polygon filling later
	; (5,6,7 used for sprite DMA and memcpy/memset)
	lda #$08 ; constant address, write 1 byte to 1 register
	sta DMAP4
	lda #<WMDATA ; write to WRAM
	sta BBAD4
	ldx #PolyFillByte
	lda #^PolyFillByte
	stx A1T4L
	sta A1B4
	stz DAS4H ; always writing less than 256 bytes per line
	
	; set up line count values in window tables
	lda #$00
	sta SpansWindowStartTable+SpansTable::StartLineCount
	sta SpansWindowEndTable+SpansTable::StartLineCount
	lda #$ff
	sta SpansWindowStartTable+SpansTable::LineCount
	sta SpansWindowEndTable+SpansTable::LineCount
	sta SpansWindowStartTable+SpansTable::StartLineValue
	lda #$00
	sta SpansWindowEndTable+SpansTable::StartLineValue
	sta SpansWindowStartTable+SpansTable::EndLineCount
	sta SpansWindowEndTable+SpansTable::EndLineCount
	
	; clear window span info
	ldx #$7f
	lda #$ff
:	sta SpansUseWindowStart,x
	sta SpansUseWindowEnd,x
	dex
	bpl :-
	
	; set up HDMA channels 0-1 for window/subscreen filling
	HDMA_set_absolute 0, 0, WH0, SpansWindowStartTable
	HDMA_set_absolute 1, 0, WH1, SpansWindowEndTable
	
	WAIT_vbl
	lda #$20 ; color math inside window 1
	sta WOBJSEL
	lda #$12 ; math inside windows only, include BG+OBJ
	sta CGSWSEL
	; CGADSUB set during shape selection
.endif ; FILL_VECTORS
	
	; determine whether or not to use the slower polygon fill routine
	; (DMA safe for ver.1 CPU)
	ldx #fill_fast
	stx z:FillSpan
	
	stz z:DrawFlags
	lda RDNMI
	and #$0f
	cmp #$01
	bne :+
	lda #$40
	tsb z:DrawFlags
	
	ldx #fill_safe
	stx z:FillSpan
:
	
	stz z:BufferReady
	stz z:DeltaFrames
	
	lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
	sta SFX_inidisp
		
	WAIT_vbl
	; put BG + sprites on main screen
	lda #tm(OFF, OFF, ON, OFF, ON)
	sta TM
	; put vector buffer on sub screen
	lda #tm(ON, OFF, OFF, OFF, OFF)
	sta TS

	rts
endproc

;-------------------------------------------------------------------------------
proc VectorPartVBL
	; make sure DB is correct (will apply to VBLTask too)
	phk
	plb
	
.if ::FILL_VECTORS = 1
	; update HDMA start line
	lda z:VectorY
	dec
	sta SpansWindowStartTable+SpansTable::StartLineCount
	sta SpansWindowEndTable+SpansTable::StartLineCount
	
	; enable channel 0+1 HDMA
	lda #$03
	sta HDMAEN
.endif
	
	; go ahead and re-enable screen here in case later stuff runs long
	; (there should still be enough time for the buffer DMA)
	lda SFX_inidisp
	sta INIDISP
		
	lda #1
	sta CGADD
	lda z:PaletteColors
	sta CGDATA
	lda z:PaletteColors+1
	sta CGDATA
	lda z:PaletteColors+2
	sta CGDATA
	lda z:PaletteColors+3
	sta CGDATA
	lda z:PaletteColors+4
	sta CGDATA
	lda z:PaletteColors+5
	sta CGDATA
	
	lda #$E0
	sta COLDATA
	lda z:WindowColors
	sta COLDATA
	lda z:WindowColors+1
	sta COLDATA
	
	; update buffer
;	inc z:RenderTime
	lda z:BufferReady
	jeq endcopy
	
	; send both bitplanes as odd/even bytes
	; (Using the address remapping)
	
	.macro CopyBitplane num
		.if num = 0
			lda #$04 ; low bytes, 8-bit address rotation
			sta VMAINC
			
			lda #<VMDATAL
			sta BBAD7
			
			ldx #.loword(DrawBuf)
			stx A1T7L
		.else
			lda #$84 ; high bytes, 8-bit address rotation
			sta VMAINC
			
			lda #<VMDATAH
			sta BBAD7
			
			ldx #.loword(DrawBuf) + $0800
			stx A1T7L
		.endif
		
		ldx #(VRAM_CHARSET >> 1)
		stx VMADDL
		
		lda #^DrawBuf
		sta A1B7
		
		stz DMAP7
		
		ldx #$0800
		stx DAS7L
		
		lda #$80
		sta MDMAEN
	.endmac
	
	CopyBitplane 0
	CopyBitplane 1
	
.if ::FILL_VECTORS = 1
	memcpy SpansUseWindowStart, SpansWindowStart, 256
		
	; for normal filled vectors, update colors based on the normals
	; (the shading will lag the actual rendering by 1 frame)
	bit z:DrawFlags
	bmi endcopy
	jsr UpdateShades
.endif

endcopy:
	; update vector position
	jsr UpdateVectorPos
	jsr UpdateScrollText
	
	inc z:DeltaFrames
	stz z:BufferReady
	
	rtl
endproc

;-------------------------------------------------------------------------------
; ------------------------------------------------------
; Update the vector object's position on screen 
; (both the background layer and the window)
; ------------------------------------------------------
proc UpdateVectorPos
	break
	RW a16
	lda z:VectorX
	and #$ff
	neg
	RW a8
	sta BG1HOFS
	xba
	sta BG1HOFS
	lda z:VectorY
	neg
	sta BG1VOFS
	stz BG1VOFS

.if ::FILL_VECTORS = 1
	; update HDMA table
	ldx #$7e
	clc
tabloop:
	stz SpansWindowEndTable+SpansTable::LineValue,x
	lda SpansUseWindowStart,x
	bmi :+
	add z:VectorX
	bcc :+
	; span start was offscreen
	dex
	bpl tabloop
	
:	sta SpansWindowStartTable+SpansTable::LineValue,x
	lda SpansUseWindowEnd,x
	add z:VectorX
	bcc :+
	; span end was offscreen
	lda #$ff
:	sta SpansWindowEndTable+SpansTable::LineValue,x
	dex
	bpl tabloop
.endif

	rts
endproc

;-------------------------------------------------------------------------------
; ------------------------------------------------------
; For shaded vectors, update the palette based on 3 normal values
; ------------------------------------------------------
PlaneShadeTable:
.repeat 32, i
	.word rgb((i*2/3), (i*2/3), (i*2/3))
.endrep

WindowShadeTable:
.repeat 32, i
	.byte $E0 | (i*2/3)
.endrep

proc UpdateShades
	; plane 1 color
	RW_push set:a16
	lda z:Plane1Normal
	and #$00ff
	cmp #$20
	bcc :+
	lda #$1f
:	asl
	tax
	lda PlaneShadeTable,x
	sta PaletteColors
	; plane 2 color
	lda z:Plane2Normal
	and #$00ff
	cmp #$20
	bcc :+
	lda #$1f
:	asl
	tax
	lda PlaneShadeTable,x
	sta PaletteColors+2
	sta PaletteColors+4
	; window color
	RW a8i8
	lda z:WindowNormal
	cmp #$20
	bcc :+
	lda #$1f
:	;lsr
	tax
	lda WindowShadeTable,x
	sta z:WindowColors
	sta z:WindowColors+1
	RW_pull
	rts
endproc

;-------------------------------------------------------------------------------
; ------------------------------------------------------
; Refresh object vertex coordinates before transforming again
; ------------------------------------------------------
proc LoadObject

	RW a16
	lda   z:CurrObj
	and   #$ff
	asl
	tax
	lda   ObjectTable,x
	tax
	
	RW a8
	; get number of points
	lda   a:0,x
	sta   z:VertexCount
	inx
	ldy   #0
	
:
	lda   a:0,x
	sta   VertexX,y
	inx
	lda   a:0,x
	sta   VertexY,y
	inx
	lda   a:0,x
	sta   VertexZ,y
	inx
	iny
	tya
	cmp   z:VertexCount
	bne   :-
	
	lda   a:0,x
	sta   z:PolyCount
	inx
	stx   z:LineList
	
	rts
endproc

;-------------------------------------------------------------------------------
; ------------------------------------------------------
; Perform matrix transformation of vertices after reloading
; ------------------------------------------------------
proc UpdateVertex

CurrSine   = ZPAD
CurrCosine = ZPAD+2
MultTemp1  = ZPAD+4
MultTemp2  = ZPAD+6
DeltaTemp = ZPAD+8

	php
;	WAIT_vbl ; test...
	
	jsr LoadObject
	
	lda z:DeltaFrames
	beq nodelta
	stz z:DeltaFrames
	sta z:DeltaTemp
:	
	lda z:DeltaX
	clc
	adc z:AngleX
	sta z:AngleX
	lda z:DeltaY
	clc
	adc z:AngleY
	sta z:AngleY
	lda z:DeltaZ
	clc
	adc z:AngleZ
	sta z:AngleZ
	dec z:DeltaTemp
	bne :-
nodelta:

	RW a16i16
	
	; get/set a vertex
	; op = lda/sta
	; tb = X/Y/Z
.macro Vertex op, tb
	.if .xmatch({tb}, {X})
		op z:VertexX,x
	.elseif .xmatch({tb}, {Y})
		op z:VertexY,x
	.elseif .xmatch({tb}, {Z})
		op z:VertexZ,x
	.else
		.error "expected 'X', 'Y' or 'Z'"
	.endif
.endmac
	
	; multiplies a vertex X/Y/Z coord by sin/cos, returns in A
	; tb = X/Y/Z
	; sintb = sin/cos
.macro VertexMult tb, sintb
	.if .xmatch({sintb}, {sin})
		lda z:CurrSine
	.elseif .xmatch({sintb}, {cos})
		lda z:CurrCosine
	.else
		.error "expected 'sin' or 'cos'"
	.endif
	RW  a8
	sta WRMPYM7A
	xba
	sta WRMPYM7A
	Vertex lda, tb
	sta WRMPYM7B
	RW  a16
	lda MPYL
.endmac
	
	; perform VertexMult twice and add/subtract the results
	; op = add or sub
.macro VertexTrans tb1, sin1, op, tb2, sin2
	VertexMult tb2, sin2
	sta z:MultTemp1
	VertexMult tb1, sin1
	op  z:MultTemp1
.endmac
	
	; transform on two axes
	; dest = X/Y/Z
.macro VertexTrans2 dest1, tb1, sin1, op1, tb2, sin2, dest2, tb3, sin3, op2, tb4, sin4
	VertexTrans tb1, sin1, op1, tb2, sin2
	sta z:MultTemp2
	
	VertexTrans tb3, sin3, op2, tb4, sin4
	
	RW a8
	xba
	Vertex sta, dest2
	lda z:MultTemp2+1
	Vertex sta, dest1
.endmac	
	
	; ------------------------------------------------------
	; transform on X axis here (changes Y and Z coordinates)
	; ------------------------------------------------------
	lda   z:AngleX
	asl
	pha
	and   #$1ff
	tax
	lda   SinTable,x
	sta   z:CurrSine
	pla
	clc
	adc   #$80
	and   #$1ff
	tax
	lda   SinTable,x
	sta   z:CurrCosine
	
	lda   z:VertexCount
	dec
	and   #$1f
	tax
	
TransXLoop:
	           ; Y = Y'cos(tx) - Z'sin(tx)
	                                    ; Z = Y'sin(tx) + Z'cos(tx)
	VertexTrans2 Y,  Y,cos,  sub,Z,sin,   Z,  Y,sin,  add,Z,cos
	
	RW a16
	dex
	jpl   TransXLoop
	
	; ------------------------------------------------------
	; transform on Y axis here (changes X and Z coordinates)
	; ------------------------------------------------------
	lda   z:AngleY
	asl
	pha
	and   #$1ff
	tax
	lda   SinTable,x
	sta   z:CurrSine
	pla
	clc
	adc   #$80
	and   #$1ff
	tax
	lda   SinTable,x
	sta   z:CurrCosine
	
	lda   z:VertexCount
	dec
	and   #$1f
	tax
	
TransYLoop:
	           ; X = X'cos(ty) + Z'sin(ty)
	                                    ; Z = Z'cos(tx) - X'sin(tx)
	VertexTrans2 X,  X,cos,  add,Z,sin,   Z,  Z,cos,  sub,X,sin
	
	RW a16
	dex
	jpl   TransYLoop

	; ------------------------------------------------------
	; transform on Z axis here (changes X and Y coordinates)
	; ------------------------------------------------------
	lda   z:AngleZ
	asl
	pha
	and   #$1ff
	tax
	lda   SinTable,x
	sta   z:CurrSine
	pla
	clc
	adc   #$80
	and   #$1ff
	tax
	lda   SinTable,x
	sta   z:CurrCosine
	
	lda   z:VertexCount
	dec
	and   #$1f
	tax
	
TransZLoop:
	           ; X = X'cos(tz) - Y'sin(tz)
	                                    ; Y = Y'cos(tz) + X'sin(tz)
	VertexTrans2 X,  X,cos,  sub,Y,sin,   Y,  Y,cos,  add,X,sin
	
	RW a16
	dex
	jpl   TransZLoop

endtrans:
; translate to buffer coords (0..127)
	RW a8i8
	lda   z:VertexCount
	dec
	and   #$1f
	tax
:
	lda   z:VertexX,x
	clc
	adc   #64
	sta   z:VertexX,x
	lda   z:VertexY,x
	clc
	adc   #64
	sta   z:VertexY,x
	dex
	bpl :-

	plp
	rts
endproc

;-------------------------------------------------------------------------------
; ------------------------------------------------------
; fill pixel buffer based on Vertex status
;
; basic process:
; - for every polygon...
;   - calc angle of normal to determine visibility
;   - if visible, then for every line in the poly... (assuming fill mode)
;     - follow line to update left+right edges of poly on each scanline
;     - update left+right edges of entire mesh color window on each scanline
;     - if poly is to be drawn on either bitplane, fill it on each scanline it's visible on
;
;     for wireframe mode, line tracing just plots single pixels instead of filling spans
; ------------------------------------------------------
proc UpdateBuffer

; temp X/Y of 3 points for face culling
CullPointX = ZPAD
CullPointY = ZPAD+3

; bits 6+7 determine which bitplane to draw a poly to
; (currently assuming we only draw to one bitplane at a time
; unless it's a poly that doesn't draw at all and just updates the color window)
FillBitplane = ZPAD+6
CurrentNormal = ZPAD+7

	php
	
	; clear buffer now
	bit z:DrawFlags
	bvs :+
	; faster CPU2 version
	WRAM_memset DrawBuf, $1000, 0
.if ::FILL_VECTORS = 1
	WRAM_memset SpansWindowStart, 127, $ff
	WRAM_memset SpansWindowEnd, 127, 0
.endif
	; begin drawing face
	bra :++

:	; slower CPU1-safe version
	ldx #DrawBuf
	memset hi:x, $1000, 0
.if ::FILL_VECTORS = 1
	ldx #SpansWindowStart
	memset hi:x, 127, $ff
	ldx #SpansWindowEnd
	memset hi:x, 127, 0
.endif
:

.if ::FILL_VECTORS = 1
	; set fill calls based on drawflags
	ldx #skip_normal
	bit z:DrawFlags
	bpl :+
	ldx #skip_glenz
:	stx z:SkipSpan
.endif
	
	RW a8i8
.ifndef ::FILL_VECTORS
	stz NumLinesDrawn
	stz NumLinesDrawn+1
.endif
	stz z:FillBitplane

;-------------------------------------------------------------------------------
; ------------------------------------------------------
; Loop over all polys in the object and render visible ones
; ------------------------------------------------------
drawpoly:
.if ::FILL_VECTORS = 1
	ldy #0
	lda (LineList),y
.endif
	
	RW_push set:a16
	inc z:LineList
	RW_pull
	
.if ::FILL_VECTORS = 1
	bit z:DrawFlags
	bpl :+
	; in glenz mode the bitplane is determined by the facing direction
	ora #0
	jeq skipface
	
	lda #$80
:	
	sta FillBitplane
.endif

	; perform culling here based on the first 3 bytes at linelist
	ldy #0
	lda (LineList),y
	tax
	lda z:VertexX,X
	sta z:CullPointX
	lda z:VertexY,X
	sta z:CullPointY
	iny
	lda (LineList),y
	tax
	lda z:VertexX,X
	sta z:CullPointX+1
	lda z:VertexY,X
	sta z:CullPointY+1
	iny
	lda (LineList),y
	tax
	lda z:VertexX,X
	sta z:CullPointX+2
	lda z:VertexY,X
	sta z:CullPointY+2
	
	; (v1.y - v0.y) * (v2.x - v1.x) - (v1.x - v0.x) * (v2.y - v1.y)
	RW i16
	lda z:CullPointY+1
	sec
	sbc z:CullPointY
	sta WRMPYM7A
	; sign extend subtraction result
	lda #$00
	bcs :+
	lda #$ff
:
	sta WRMPYM7A
	lda z:CullPointX+2
	sec
	sbc z:CullPointX+1
	sta WRMPYM7B
	ldx MPYL
	stx z:CurrentNormal
	
	lda z:CullPointX+1
	sec
	sbc z:CullPointX
	sta WRMPYM7A
	; sign extend subtraction result
	lda #$00
	bcs :+
	lda #$ff
:
	sta WRMPYM7A
	lda z:CullPointY+2
	sec
	sbc z:CullPointY+1
	sta WRMPYM7B
	
	cpx MPYL
	bpl :+
	; this poly is currenly facing backwards
	bit z:DrawFlags
	; regular fill mode: don't show at all
	jpl skipface
	; glenz mode: just use the other bitplane
	lda #$40
	sta z:FillBitplane
:
	lda z:CurrentNormal+1
	sec
	sbc MPYM
	sta z:CurrentNormal+1

.if ::FILL_VECTORS = 1
	; clear span point info
	bit z:DrawFlags
	bvs :+
	; faster CPU2 version
	WRAM_memset SpansStart, 128, $ff
	WRAM_memset SpansEnd, 128, 0

	bra :++
:	; slower CPU1-safe version
	ldx #SpansStart
	memset hi:x, 128, $ff
	ldx #SpansEnd
	memset hi:x, 127, 0
:
.endif ; FILL_VECTORS
	
	; begin drawing face
	bra drawline
	
	; face is hidden - skip to next one
	RW_assume a8i8
skipface:
	RW i16
	ldy #0
:
	lda (LineList),y
	bmi :+
	iny
	bra :-
:
	iny
	RW a16
	tya
	clc
	adc z:LineList
	sta z:LineList
	
	; any more polys?
nextpoly:
	RW_forced a8i8
	dec z:PolyCount
	jne drawpoly
	
	; we are finished rendering this frame
	lda #1
	sta z:BufferReady
	plp
	rts
	
;-------------------------------------------------------------------------------	
; --------------------------------------------------
; Loop over all lines in current poly and update span boundaries
; --------------------------------------------------
drawline:
	; get next two points
	RW_forced a16i16
	lda (LineList)
	inc z:LineList
	
	; second point is negative = end of poly was reached
	ora #0
	bpl @draw
	inc z:LineList
.if ::FILL_VECTORS = 1
	asl z:CurrentNormal
	RW a8i8
	lda z:CurrentNormal+1
	bit z:FillBitplane
	bpl @plane2
		sta z:Plane1Normal
		; fill spans on bitplane 0
		lda #$00
		jsr FillSpans
		bra nextpoly
				
@plane2:
	bvc :+
		sta z:Plane2Normal
		; fill spans on bitplane 1
		lda #$08
		jsr FillSpans
		bra nextpoly
:	

	sta z:WindowNormal
.endif
	bra nextpoly

; --------------------------------------------------
; Trace the current line and plot pixels (for wireframe) or update spans
; --------------------------------------------------
@draw:
	RW_assume a16i16
.ifndef ::FILL_VECTORS
	; If doing wireframes instead of filled vectors, check for duplicate lines
		; see if we've drawn this line already
		ldx #0
	:
		cpx NumLinesDrawn
		beq :+
		cmp DrawnLines,x
		beq drawline ; already drawn; skip to next line
		inx
		inx
		bra :-
		
		; we haven't drawn it yet - mark it drawn for next time
	:
		sta DrawnLines,x
		inx
		inx
		xba
		sta DrawnLines,x
		inx
		inx
		stx NumLinesDrawn

.endif ; FILL_VECTORS

	; get the transformed point coords
	RW a8i8
	tax
	ldy z:VertexY,x
	sty z:LineY1
	ldy z:VertexX,x
	sty z:LineX1
	xba
	tax
	ldy z:VertexY,x
	sty z:LineY2
	ldy z:VertexX,x
	sty z:LineX2
	; normalize the line so that x2 > x1 always
	; (reduces # of line calculation cases from 8 to 4)
	cpy z:LineX1
	bcs :+
	; carry clear = x2 is smaller, so swap points
	RW_push set:a16
	lda z:LineX1
	xba
	sta z:LineX1
	lda z:LineY1
	xba
	sta z:LineY1
	RW_pull
:

	; calculate dx, 2dx and 2dy
	lda z:LineX2
	sec
	sbc z:LineX1
	sta z:LineDX
	asl
	sta z:Line2DX

	lda z:LineY2
	sec
	sbc z:LineY1
	; normalize DY, set increment amount
	ldx #1
	bcs :+
	neg
	ldx #-1
:	stx z:LineAddY
	sta z:LineDY
	asl
	sta z:Line2DY
	; see if line is "steep" (dy > dx) or normal
	cmp z:Line2DX
	jcs DrawLineSteep

; The code that follows is just 4 different versions of Bresenham's algorithm
; for speed, a macro is used to generate different code for each octant
; (but only for x >= 0)
; see 'bresenham.i' for the actual implementation

; --------------------------------------------------
; Draw a non-steep line (dx > dy)
; --------------------------------------------------
DrawLineNotSteep:
	; x is increasing
	; check if secondary axis (Y) is increasing or decreasing
	bit z:LineAddY
	jmi DrawLineNotSteep_x_up_y_down

	; x and y are increasing
	BresenhamPlot 0, iny
	
DrawLineNotSteep_x_up_y_down:
	; x is increasing, y is decreasing
	BresenhamPlot 0, dey
	
; --------------------------------------------------
; Draw a steep line (dy > dx)
; --------------------------------------------------
DrawLineSteep:
	; check if primary axis (Y) is increasing or decreasing
	bit z:LineAddY
	jmi DrawLineSteep_y_down

	; y and x are increasing
	BresenhamPlot 1, iny
	
DrawLineSteep_y_down:
	; y is decreasing, x is increasing
	BresenhamPlot 1, dey
	
endproc

; --------------------------------------------------
; End of Bresenham line drawing code
; --------------------------------------------------

;-------------------------------------------------------------------------------
.if ::FILL_VECTORS = 1

; --------------------------------------------------
; Fill spans on a bitplane using LUTs / WRAM port
; A = offset into buffer for bitplane ($00 = bpl 0, $08 = bpl 1)
; --------------------------------------------------
; not using proc for this so we can access some of the symbols here
RW_push
RW_assume a8i8
FillSpans:

FillBytes    = ZPAD   ; fill in bytes for left/right edges
BitplaneAddr = ZPAD+2 ; offset into draw buffer for current bitplane

	sta z:BitplaneAddr

	stz WMADDH
	
	ldy #$7f
nextspan:
	ldx SpansStart,y
	bpl :+
	jmp (SkipSpan)
:
	clc
	lda AddrMSBForY,y
	adc z:BitplaneAddr
	sta z:DrawPtr+1
	sta z:DrawPtr2+1
	sta WMADDM
	
	; get fill pattern and pointer to left edge tile
	lda AddrLSBForY,y
	adc AddrLSBForX,x
	sta z:DrawPtr
	inc
	sta WMADDL
	lda AddrLeftFillBitForX,x
	sta z:FillBytes
	; get fill pattern and pointer to right edge tile
	ldx SpansEnd,y	
	lda AddrLSBForY,y
	adc AddrLSBForX,x
	sta z:DrawPtr2
	lda AddrRightFillBitForX,x
	sta z:FillBytes+1
	
	sec
	lda z:DrawPtr2
	sbc z:DrawPtr
	bne :+
	
	; both edges in same tile: AND each together before ORing
	lda z:FillBytes
	and z:FillBytes+1	
	ora [DrawPtr]
	sta [DrawPtr]
	jmp (SkipSpan)

:
	; x = the number of tiles between start and end + 1
	tax
	
	; both edges in different tiles: just OR each
	lda [DrawPtr]
	ora z:FillBytes
	sta [DrawPtr]
	
	lda [DrawPtr2]
	ora z:FillBytes+1
	sta [DrawPtr2]

	; use either the DMA version or the slow version
	dex
	bne :+
	jmp (SkipSpan) ; span fully drawn already
:	jmp (FillSpan)
	
fill_fast:
	stx DAS4L
	lda #$10
	sta MDMAEN
	jmp (SkipSpan)

fill_safe: ; slow non-DMA version, safe for v1 CPU	
	phd
	pea $2100
	pld
	
	txa
	asl
	tax
	lda #$ff
	jmp (.loword(:+), x)
: 
.word @fill0
.word @fill1, @fill2, @fill3, @fill4
.word @fill5, @fill6, @fill7, @fill8
.word @fill9, @fill10, @fill11, @fill12
.word @fill13, @fill14, @fill15, @fill16

@fill16: sta z:<WMDATA
@fill15: sta z:<WMDATA
@fill14: sta z:<WMDATA
@fill13: sta z:<WMDATA
@fill12: sta z:<WMDATA
@fill11: sta z:<WMDATA
@fill10: sta z:<WMDATA
@fill9:  sta z:<WMDATA
@fill8:  sta z:<WMDATA
@fill7:  sta z:<WMDATA
@fill6:  sta z:<WMDATA
@fill5:  sta z:<WMDATA
@fill4:  sta z:<WMDATA
@fill3:  sta z:<WMDATA
@fill2:  sta z:<WMDATA
@fill1:  sta z:<WMDATA
@fill0:	; this case shouldn't actually be reached
	pld
	jmp (SkipSpan)

skip_glenz:
	dey ; glenz mode currently renders only every other line on bitplanes for speed
skip_normal:
	dey
	jpl nextspan
	rts

RW_pull ; end FillSpans

.endif ; FILL_VECTORS

