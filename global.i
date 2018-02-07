.include "libSFX.i"
.feature force_range
.macpack longbranch

; from main.s

.globalzp VBLPart, VBLTask, VBLTaskDelay, VBLTaskNext
.globalzp PartStatus

.global VBL_Dummy, VBLTask_Wait
.global ClearMainSprites
.global OAM_low, OAM_high

.global SinTable

.macro VBL_part addr
	RW_push set:a8i16
	ldx #addr
	lda #^addr
	stx z:VBLPart
	sta z:VBLPart+2
	RW_pull
.endmac

.macro VBL_part_stop
	RW_push set:a8i16
	ldx #VBL_Dummy
	lda #^VBL_Dummy
	stx z:VBLPart
	sta z:VBLPart+2
	RW_pull
.endmac

.macro VBL_task addr, wait
	RW_push set:a8i16
	ldx #addr
	lda #^addr
	stx z:VBLTaskNext
	sta z:VBLTaskNext+2
		
	ldx #VBLTask_Wait
	lda #^VBLTask_Wait
	stx z:VBLTask
	sta z:VBLTask+2
	
	.ifnblank wait
		ldx #wait
	.else
		ldx #0
	.endif
	stx z:VBLTaskDelay
	
	RW_pull
.endmac

.macro VBL_task_stop
	RW_push set:a8i16
	ldx #VBL_Dummy
	lda #^VBL_Dummy
	stx z:VBLTask
	sta z:VBLTask+2
	RW_pull
.endmac

; from twist.s

.global TwistPartMain

; from vector.s

.global VectorPartMain
.global UpdateScrollText

; from vectorplot.s

.globalzp DrawFlags

.globalzp PaletteColors, WindowColors
.globalzp CurrObj

.globalzp VectorX, VectorY

 ; TODO: delete these ones
.globalzp AngleX, AngleY, AngleZ, DeltaFrames, PolyCount, LineList
.global GlenzLineList


.globalzp DeltaX, DeltaY, DeltaZ
.globalzp BufferReady

.global VectorPartInit, VectorPartVBL
.global ObjectTable

.global LoadObject, UpdateVertex, UpdateBuffer
