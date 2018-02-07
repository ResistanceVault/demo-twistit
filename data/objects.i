ObjectTable:
.word TestCube
.word TestKiscube
EndObjectTable:

; -----------------------------------------------------------------------------
TestCube:
; points
.byte 8
.byte -32, -32, 32 ; front top left
.byte -32, 32, 32 ; front bottom left
.byte 32, -32, 32 ; front top right
.byte 32, 32, 32 ; front bottom right
.byte -32, -32, -32 ; back top left
.byte -32, 32, -32 ; back bottom left
.byte 32, -32, -32 ; back top right
.byte 32, 32, -32 ; back bottom right

; polys connecting points, winding counterclockwise
; first byte of the poly is the bitplane number:
; $80 - bitplane 0, $40 - bitplane 1, $00 - neither (uses window instead)
; (note: in glenz mode it's either zero or nonzero and the bitplane is determined
;  by which direction the poly is facing)
; number of polys
.byte 6
; front face
.byte $00, 0, 1, 3, 2, 0, -1
; top face
.byte $40, 0, 2, 6, 4, 0, -1
; left face
.byte $80, 0, 4, 5, 1, 0, -1
; back face
.byte $00, 4, 6, 7, 5, 4, -1
; bottom face
.byte $40, 1, 5, 7, 3, 1, -1
; right face
.byte $80, 2, 3, 7, 6, 2, -1

; -----------------------------------------------------------------------------
TestKiscube:
; points
.byte 14
.byte -28, -28, 28 ; 0 front top left
.byte -28, 28, 28 ; 1 front bottom left
.byte 28, -28, 28 ; 2 front top right
.byte 28, 28, 28 ; 3 front bottom right
.byte -28, -28, -28 ; 4 back top left
.byte -28, 28, -28 ; 5 back bottom left
.byte 28, -28, -28 ; 6 back top right
.byte 28, 28, -28 ; 7 back bottom right
.byte 0, 0, 48 ; 8 front center
.byte 0, 0, -48 ; 9 back center
.byte 0, -48, 0 ; 10 top center
.byte 0, 48, 0 ; 11 bottom center
.byte -48, 0, 0 ; 12 left center
.byte 48, 0, 0 ; 13 right center

; number of polys
.byte 12
; front face
GlenzLineList:
;.byte $00, 8, 2, 0, 8, -1
.byte $80, 8, 3, 2, 8, -1
;.byte $00, 8, 1, 3, 8, -1
.byte $80, 8, 0, 1, 8, -1
; top face
.byte $80, 10, 6, 4, 10, -1
;.byte $00, 10, 2, 6, 10, -1
.byte $80, 10, 0, 2, 10, -1
;.byte $00, 10, 4, 0, 10, -1
; left face
.byte $80, 12, 0, 4, 12, -1
;.byte $00, 12, 1, 0, 12, -1
.byte $80, 12, 5, 1, 12, -1
;.byte $00, 12, 4, 5, 12, -1
; back face
;.byte $00, 9, 4, 6, 9, -1
.byte $80, 9, 5, 4, 9, -1
;.byte $00, 9, 7, 5, 9, -1
.byte $80, 9, 6, 7, 9, -1
; bottom face
.byte $80, 11, 3, 1, 11, -1
;.byte $00, 11, 7, 3, 11, -1
.byte $80, 11, 5, 7, 11, -1
;.byte $00, 11, 1, 5, 11, -1
; right face
.byte $80, 13, 6, 2, 13, -1
;.byte $00, 13, 7, 6, 13, -1
.byte $80, 13, 3, 7, 13, -1
;.byte $00, 13, 2, 3, 13, -1
