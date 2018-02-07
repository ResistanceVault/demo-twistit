.macro BresenhamPlotSpan
	; filled vectors - just get span info here
	; update pixel spans for filling in edge tiles
	txa
	cmp SpansStart,y
	bcs :+
	sta SpansStart,y
	cmp SpansWindowStart,y
	bcs :+
	sta SpansWindowStart,y
:
	cmp SpansEnd,y
	bcc :+
	sta SpansEnd,y
	cmp SpansWindowEnd,y
	bcc :+
	sta SpansWindowEnd,y
:
	
.endmac

.macro BresenhamPlotPixel
	; wireframe vectors - draw single point
;	bmi @nextline
	lda AddrMSBForY,y
	sta DrawPtr+1
	lda AddrLSBForY,y
;	bmi @nextline
	clc
	adc AddrLSBForX,x
	sta DrawPtr
	lda [DrawPtr]
	ora AddrBitForX,x
	sta [DrawPtr]
.endmac

; -------------------------------------------------------------------

.macro BresenhamPlot steep, dir_y

; set up error accumulation
.if steep
	lda z:Line2DX
	sec
	sbc z:LineDY
	sta z:LineError
	sec
	sbc z:LineDY
	sta z:LineAddError
.else
	lda z:Line2DY
	sec
	sbc z:LineDX
	sta z:LineError
	sec
	sbc z:LineDX
	sta z:LineAddError
.endif
	ldx z:LineX1
	ldy z:LineY1

; loop - plot single pixels (or fill edge tiles) along the line
@plotpixels:
	.if ::FILL_VECTORS <> 1
		BresenhamPlotPixel
	.endif
	
	; update delta
	lda z:LineError
	bmi @no_overflow
	; error overflow
	clc
	adc z:LineAddError
	sta z:LineError

	; update secondary axis
.if steep
	inx
.else
.if ::FILL_VECTORS = 1
	BresenhamPlotSpan
.endif
	dir_y
.endif
	bra @nextpixel

	; no error overflow
@no_overflow:
	clc
	; update error based on secondary axis
.if steep
	adc z:Line2DX
.else
	adc z:Line2DY
.endif
	sta z:LineError

	; update primary axis
@nextpixel:
.if steep
	; steep lines update spans when Y changes
.if ::FILL_VECTORS = 1
	BresenhamPlotSpan
.endif
	dir_y
	dec z:LineDY
.else
	inx
	dec z:LineDX
.endif
	; move to next point
	bpl @plotpixels

; at the end, roll non-steep lines back one and update once more
.if ::FILL_VECTORS = 1
.if .not steep
	dex
	BresenhamPlotSpan
.endif
.endif	

	jmp drawline
.endmac