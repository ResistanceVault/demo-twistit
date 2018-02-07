.include "global.i"

;-------------------------------------------------------------------------------
.segment "ZEROPAGE": zeropage

; "main" VBL thread for current part
VBLPartJML: .res 1
VBLPart:    .res 3

; sub-tasks for current thread
VBLTaskJML: .res 1
VBLTask:    .res 3
VBLTaskDelay: .res 2
VBLTaskNext: .res 3

; music -> logo sync info
LastSyncPoint: .res 1
NextSyncPal: .res 2

; status bits for current part to determine to change parts or not
PartStatus: .res 1

;-------------------------------------------------------------------------------
.segment "LORAM"

OAM_low:  .res 512
OAM_high: .res 32

LogoPalettes: .res 16*2*4

;-------------------------------------------------------------------------------
.segment "RODATA"

SinTable: .include "data/sintable.i"

incbin LogoTiles, "data/snes_rse_logo.png.tiles.lz4"
incbin LogoPal,   "data/snes_rse_logo.png.palette", 0, 16*2

incbin FontTiles, "data/font_fra.png.tiles.lz4"
incbin FontPal,   "data/font_fra.png.palette", 0, 16*2

incbin BGTiles, "data/snes-bg.png.tiles.lz4"

;-------------------------------------------------------------------------------
.segment "ROM0"

; stuffing some here to save space
incbin BGMap, "data/snes-bg.png.map.lz4"
incbin BGPal, "data/snes-bg.png.palette", 0, 4*2

incbin Music, "data/music.bin"

;-------------------------------------------------------------------------------
;.segment "CODE"
.segment "LIBSFX"
; maybe keep this in bank 1 since there's enough free space there
; and it gives us more room for continuous data in the actual demo parts

; test data for bg3
VRAM_BGCHARSET     = $8000
VRAM_BGTILEMAP     = $a000

; use OAM tiles 000-0FF for text and 100+ for logo
VRAM_FONTCHARSET  = $c000
VRAM_LOGOCHARSET  = $e000

;-------------------------------------------------------------------------------
proc VBL
	stz HDMAEN

	jsr DoSpriteDMA

	; logo palette DMA
	ldx z:NextSyncPal
	beq :+
	CGRAM_memcpy $90, hi:x, 16*2
:
	phb
	; vblank-critical proc for current part
	jsl VBLPartJML

	; misc. frame subtask for current part
	jsl VBLTaskJML
	plb
	
	; check sync point in music
	lda APUIO2
	bit #$20 ; playing?
	beq :+
	and #$0f
	cmp z:LastSyncPoint
	beq :+ ; no change
	sta z:LastSyncPoint
	ldx #LogoPalettes+(16*6)
	stx z:NextSyncPal
	bra end
:
	; update logo palette every other frame
	lda z:SFX_tick
	and #1
	beq end
	
	RW a16
	lda z:NextSyncPal
	beq :+
	sec
	sbc #16*2
	cmp #LogoPalettes
	bcs :+
	; at end of palette shift cycle
	lda #0
:
	sta z:NextSyncPal
	RW a8
	
end:
	rtl
endproc

;-------------------------------------------------------------------------------
proc DoSpriteDMA
	stz MDMAEN

	ldx #0
	stx OAMADDL
	
	; use DMA channel 5 instead of 7 so we don't interrupt
	; WRAM_memset, which uses channels 6+7 and potentially during frame
	; since ch.5 may be used for HDMA also, just write HDMAEN in vblank parts
	lda #%00000010
	sta DMAP5
	
	lda #<OAMDATA
	sta BBAD5
	
	ldx #OAM_low
	stx A1T5L
	lda #^OAM_low
	sta A1B5
	
	ldx #(512+32)
	stx DAS5L
	
	lda #$20
	sta MDMAEN
	
	rts
endproc

;-------------------------------------------------------------------------------
; dummy vblank task
proc VBL_Dummy
	rtl
endproc

;-------------------------------------------------------------------------------
; pause between tasks
proc VBLTask_Wait
	ldx z:VBLTaskDelay
	bne end
	
	; start next task
	ldx z:VBLTaskNext
	lda z:VBLTaskNext+2
	stx z:VBLTask
	sta z:VBLTask+2
	
	ldx #VBL_Dummy
	lda #^VBL_Dummy
	stx z:VBLTaskNext
	sta z:VBLTaskNext+2
	
	jml VBLTaskJML
end:
	dex
	stx z:VBLTaskDelay
	rtl
endproc

;-------------------------------------------------------------------------------
proc Main

	jsr InitMainGfx
	
	; set up layer 3 (background)
	lda #bgsc(VRAM_BGTILEMAP, SC_SIZE_32X32)
	sta BG3SC
	; set up tileset for layer 3
	lda #bg12nba(VRAM_BGCHARSET, 0)
	sta BG34NBA
	
	; set up sprite addresses and size (8x8 for text, 64x64 for logo)
	lda #objsel(VRAM_FONTCHARSET, OBJ_8x8_64x64, $1000)
	sta OBJSEL
	
	; turn screen off, vblank task will fade in
	lda #inidisp(OFF, 0)
	sta SFX_inidisp
	
	jsr InitLogoSprites
	
	; init additional vblank trampolines
	lda #$5c
	sta z:VBLPartJML
	sta z:VBLTaskJML
	ldx #VBL_Dummy
	stx z:VBLPart
	stx z:VBLTask
	lda #^VBL_Dummy
	sta z:VBLPart+2
	sta z:VBLTask+2
	
	jsr StartMusic
	
	VBL_set VBL
	VBL_on
	
:
	; reload BG palette since the vector objects will have overwritten it
	WAIT_vbl
	CGRAM_memcpy 0, BGPal, sizeof_BGPal
	; put in mode0 bg3 range also
	CGRAM_memcpy $40, BGPal, sizeof_BGPal

	jsl TwistPartMain
	jsr PartTrans1
	jsl VectorPartMain
	jsr PartTrans2
	
	; loop to beginning of intro afterward
	bra :-
endproc

; interpolate BG/logo pos over 60 frames
LogoPosTable:
.byte 156, 155, 155, 155, 154, 153, 152, 151, 150, 148, 146, 145, 142, 140, 138, 135, 132, 129
.byte 126, 123, 119, 116, 112, 108, 103, 99, 94, 90, 85, 80, 74, 69, 65, 60, 56, 51, 47, 43, 40
.byte 36, 33, 30, 27, 24, 21, 19, 17, 14, 13, 11, 9, 8, 7, 6, 5, 4, 4, 4, 4, 4
BGPosTable:
.byte 32, 31, 31, 31, 31, 31, 31, 31, 30, 30, 30, 29, 29, 28, 28, 27, 27, 26, 25, 25, 24, 23, 22
.byte 21, 21, 20, 19, 18, 17, 16, 14, 13, 12, 11, 10, 10, 9, 8, 7, 6, 6, 5, 4, 4, 3, 3, 2, 2, 1
.byte 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0

;-------------------------------------------------------------------------------
; transition twist->vector (move logo up, background down)
proc PartTrans1
	jsl ClearMainSprites

	ldx #0
:
	WAIT_vbl
	lda BGPosTable,x
	sta BG3VOFS
	stz BG3VOFS
	
	lda LogoPosTable,x
	; update logo sprites Y position
	sta OAM_low+496+1
	sta OAM_low+496+5
	sta OAM_low+496+9
	sta OAM_low+496+13

	inx
	cpx #60
	bcc :-
	
	rts
endproc

;-------------------------------------------------------------------------------
; transition vector->twist (move logo down, background up)
proc PartTrans2
	jsl ClearMainSprites

	ldx #59
:
	WAIT_vbl
	lda BGPosTable,x
	sta BG3VOFS
	stz BG3VOFS
	
	lda LogoPosTable,x
	; update logo sprites Y position
	sta OAM_low+496+1
	sta OAM_low+496+5
	sta OAM_low+496+9
	sta OAM_low+496+13
	
	dex
	bpl :-
	
	rts
endproc

;-------------------------------------------------------------------------------
proc InitMainGfx
TileMapTemp = HIRAM

	; load font graphics
	LZ4_decompress FontTiles, EXRAM, y
	VRAM_memcpy VRAM_FONTCHARSET, EXRAM, y
	; use sprite pal #0 for text font
	CGRAM_memcpy 128, FontPal, sizeof_FontPal
	; put in sprite pal #4 too if we want to do any color math on sprites
	CGRAM_memcpy 128+(16*4), FontPal, sizeof_FontPal

	; load logo graphics
	LZ4_decompress LogoTiles, EXRAM, y
	VRAM_memcpy VRAM_LOGOCHARSET, EXRAM, y
	; use sprite pal #1 for logo
	CGRAM_memcpy 128+16, LogoPal, sizeof_LogoPal
	
	; init logo palette fade (for last 14) colors
	RW_push set:a16
	ldx #15*2
:
	lda f:LogoPal,x
	sta LogoPalettes,x
	ora #rgb(1,1,1)
	sta LogoPalettes+(16*2),x
	ora #rgb(2,2,2)
	sta LogoPalettes+(16*4),x
	ora #rgb(4,4,4)
	sta LogoPalettes+(16*6),x
	
	dex
	dex
	bpl :-
	; last 2 colors are constant
	lda f:LogoPal
	sta LogoPalettes
	sta LogoPalettes+(16*2)
	sta LogoPalettes+(16*4)
	sta LogoPalettes+(16*6)
	lda f:LogoPal+2
	sta LogoPalettes+2
	sta LogoPalettes+(16*2)+2
	sta LogoPalettes+(16*4)+2
	sta LogoPalettes+(16*6)+2
	RW_pull
	
	; load background
	LZ4_decompress BGMap, EXRAM, y
	VRAM_memcpy VRAM_BGTILEMAP, EXRAM, y
	
	LZ4_decompress BGTiles, EXRAM, y
	VRAM_memcpy VRAM_BGCHARSET, EXRAM, y
	
	; init bg scroll
	lda BGPosTable
	sta BG3VOFS
	stz BG3VOFS
	
	rts
endproc

;-------------------------------------------------------------------------------
proc StartMusic
SNESMOD_PLAY = $03
	LZ4_decompress Music, EXRAM
	SMP_exec $0200, EXRAM, $fdc0, $0400
	
	lda #SNESMOD_PLAY
	sta APUIO0
	stz APUIO3 ; play first (only) tune
	lda APUIO1
	inc
	sta APUIO1	
:	cmp APUIO1 ; ack
	bne :-
	
	rts
endproc

;-------------------------------------------------------------------------------
proc ClearMainSprites
	lda #%00000000
	ldx #30
:
	sta OAM_high,x
	dex
	bpl :-
	
	ldx #0
	lda #240
:
	sta OAM_low+1,x
	inx
	inx
	inx
	inx
	cpx #124*4
	bcc :-

	rtl
endproc

;-------------------------------------------------------------------------------
proc InitLogoSprites
	; use the last four OAM slots (as 64x64 sprites) for the logo
	lda #%10101010
	sta OAM_high+31
	
	; sprite X coords
	stz OAM_low+496
	lda #64
	sta OAM_low+496+4
	lda #128
	sta OAM_low+496+8
	lda #192
	sta OAM_low+496+12
	
	; sprite Y coords
	lda LogoPosTable
	sta OAM_low+496+1
	sta OAM_low+496+5
	sta OAM_low+496+9
	sta OAM_low+496+13
	
	; sprite tile numbers
	lda #$00
	sta OAM_low+496+2
	lda #$08
	sta OAM_low+496+6
	lda #$80
	sta OAM_low+496+10
	lda #$88
	sta OAM_low+496+14
	
	; sprite attributes (max priority, palette #1, high tile num)
	lda #%00110011
	sta OAM_low+496+3
	sta OAM_low+496+7
	sta OAM_low+496+11
	sta OAM_low+496+15

	rts
endproc
