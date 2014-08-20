; Jylia set fractal created by Arkady Antipin & Andrew Ryzhkov

.286
.287
.model	tiny
.code

Lim	EQU	0FFh	;40h
MaxX	EQU	359
MaxY	EQU	479

red	EQU	offset pall+765
gri	EQU	offset pall+766
blu	EQU	offset pall+767

	ORG	100h

go:

Sign	db	'AA&AR  '

;	push	cs
;	pop	ds		; DS = CS

; 286 Check
	PUSH	SP
	POP	AX
	CMP	SP,AX
	JE	CPU286Ok

	mov	ah,09h
	mov	dx,offset CPU286No
	int	21h
	
	jmp	Exit
	
CPU286Ok:

; 287 Check
	fninit
	mov	word ptr @opp,5A5Ah
	fnstsw	word ptr @opp
	mov	ax,word ptr @opp
	or	al,al
	je	CO287Ok

	mov	ah,09h
	mov	dx,offset CO287No
	int	21h
	
	jmp	Exit

CO287Ok:
	
; VGA Check
	mov	ax,1200h
	mov	bl,31h
	int	10h
	cmp	al,12h
	je	VGAOk

	mov	ah,09h
	mov	dx,offset VGANoExist
	int	21h
	
	jmp	Exit

VGAOk:

;InitDelay
	MOV	ax,0040h
	mov	es,ax
	MOV	DI,OFFSET (DWORD PTR 6CH)
	MOV	BL,ES:[DI]
id3:	CMP	BL,ES:[DI]
	JE	id3
	MOV	BL,ES:[DI]
	MOV	AX,-28
	CWD

id1:	SUB	AX,1
	SBB	DX,0
	JC	id2
	CMP	BL,ES:[DI]
	JE	id1
id2:

	NOT	AX
	NOT	DX
	MOV	CX,55
	DIV	CX
	MOV	DelayCnt,AX

; SetGraphMode VGAExt360x480-256
	MOV	AX,13H
	INT	10H

	mov	ax,0A000h
	MOV	ES,ax

	mov	si,offset VideoData

	mov	dx,3c4h
	outsw
	outsw

	xor	Ax,ax
	xor	DI,di
	MOV	CX,0A300H
	CLD				; Clear direction 
	REP	STOSB			; Rep zf=0+cx>0 Store al to es:[di] 

	MOV	DX,3C2H
	outsw

	MOV	DX,3D4H
	MOV	AL,11H
	OUT	DX,AL
	MOV	DX,3D5H
	IN	AL,DX
	AND	AL,7

	mov	dx,3d4h
	mov	ah,al
	mov	al,11h
	out	dx,ax

	mov	cx,17
	rep	outsw

;SetPalette
	mov	cl,0FFh
	
	mov	dx,3C8h

	mov	ah,63			; Red
	mov	bh,63			; Green
	mov	bl,63			; Blue

PalCyc:
	mov	al,cl
	out	dx,al
	inc	dx
	mov	al,ah
	out	dx,al
	mov	al,bh
	out	dx,al
	mov	al,bl
	out	dx,al

	dec	ah
	dec	bh
	dec	bl

	dec	dx	
	dec	cl
	jnz	PalCyc

; for dx:=MaxY downto 0 do
	mov	dx,MaxY
loopy:	

; for cx:=MaxX downto 0 do
	mov	cx,MaxX

loopx:	
	mov	word ptr @opp,cx
	fild	word ptr @opp	; x
	fidiv	word ptr @c80
	fisub	word ptr @c2
	
	mov	word ptr @opp,dx
	fild	word ptr @opp	; y, x/80-2
	fidiv	word ptr @c50	; y/50, x/80-2
	fisub	word ptr @c2	; x/50 - 2, x/80-2
	
	mov	bx,0
	
iter:				; y0,        x0
	fld	st(1)		; x0,        y0,   x0
	fld	st(0)		; x0,        x0,   y0,   x0
	fmul			; sqx0,      y0,   x0
	fld	st(1)		; y0,        sqx0, y0,   x0
	fld	st(0)		; y0,        y0,   sqx0, y0, x0
	fmul			; sqy0,      sqx0, y0,   x0
	fsub			; sq-sq,     y0,   x0
	fadd	dword ptr @cx	; cx+(sq-sq),y0,   x0
	fld	st(0)		; x1,        x1,   y0,   x0
	fld	st(0)		; x1,        x1,   x1,   y0, x0
	fmul			; sqx1,      x1,   y0,   x0

	fxch	st(2)		; y0,        x1,     sqx1,   x0
	fxch	st(1)		; x1,        y0,     sqx1,   x0
	fxch	st(3)		; x0,        y0,     sqx1,   x1

	fimul	word ptr @c2	; 2*x0,      y0,     sqx1,x1
	fmul			; 2*y0*x0,   sqx1,   x1
	fadd	dword ptr @cy	; cy+2*y0*x0,sqx1,   x1
	fxch	st(1)		; sqx1,      y1,     x1
	fld	st(1)		; y1,        sqx1,   y1,  x1
	fld	st(2)		; y1,        y1,     sqx1,y1,  x1
	fmul			; sqy1,      sqx1,   y1,  x1

	inc	bx
	fadd			; sqx1+sqy1, y1,        x1

	ficomp	word ptr @c4	; y1,        x1
	fstsw	ax
	sahf
	jnbe	excp

	cmp	bx,Lim
	je	excp		; if bx>Lim then goto excp

	jmp	iter

excp:

	fstp	st(0)		; clear FPU stack
	fstp	st(0)

; PutPixel(cx,dx,bl)
	;
	push	ax
	push	dx
	;
	mov ax,90
	mul dx			; AX <- (BytesPerRow * y) 
	mov	si,cx
	shr cx,2		; CX <- (X div 4) 
	add ax,cx		; AX <- (BytesPerRow * y)+(X div 4) 
	mov di,ax		; DI <- (BytesPerRow * y)+(X div 4) 
	;
	mov	cx,si
	and cl,3		; CL <- (X mod 4) 
	mov ah,1
	shl ah,cl		; AH <- (1 shl (X mod 4)) 
	;
	mov dx,3c4h
	mov al,2
	out dx,ax
	;
	mov es:[di],bl

	mov	cx,si
	pop	dx
	pop	ax

	dec	cx
	cmp	cx,0FFFFh
	jz	eloopx
	jmp	loopx
eloopx:

	dec	dx
	cmp	dx,0FFFFh
	jz	eloopy
	jmp	loopy

KeyPress:
; ReadKey
	xor	ax,ax
	int	16h

eloopy:

; Rotate Palette
	push	ds
	pop	es

	cld
	mov	cx,768
	mov	di,offset pall
	xor	ax,ax
	rep	stosb

; save palette
repa:
	cld
	mov	dx,03C8h
	xor	ax,ax
	out	dx,al
	inc	dx
	mov	si,offset pall
	mov	cx,768
	rep	outsb

; rotate palette
	cld
	mov	si,offset pall
	mov	di,si
	mov	cx,765
	mov	al,ds:[si]
	inc	si
	mov	bl,ds:[si]
	inc	si
	mov	dl,ds:[si]
	inc	si
	rep	movsb

	mov	ah,byte ptr red
	mov	al,byte ptr dred
	add	ah,al
	cmp	ah,34h
	jb	oka
	sub	ah,al
	neg	al
	mov	byte ptr dred,al
oka:	mov	byte ptr red,ah

	mov	ah,byte ptr blu
	mov	al,byte ptr dblu
	add	ah,al
	cmp	ah,40h
	jb	okb
	sub	ah,al
	neg	al
	mov	byte ptr dblu,al
okb:	mov	byte ptr blu,ah

	mov	ah,byte ptr gri
	mov	al,byte ptr dgri
	add	ah,al
	cmp	ah,25h
	jb	okc
	sub	ah,al
	neg	al
	mov	byte ptr dgri,al
okc:	mov	byte ptr gri,ah

	jmp	short Delay
return_from_Delay:

; if NOT KeyPressed then Goto Again
	push	ds
	xor	ax,ax
	mov	ds,ax
	mov	al,ds:[041Ah]
	cmp	al,ds:[041Ch]
	pop	ds
	je	repa

; ReadKey
	xor	ax,ax
	int	16h

; SetTextMode
	mov	ax,0003h
	int	10h

; Halt
Exit:
	mov	ax,4C00h
	int	21h

Delay:
	push	es

	MOV	CX,25			; Ms
	JCXZ	d2
	mov	ax,0040h
	MOV	ES,ax
	XOR	DI,DI
	MOV	BL,ES:[DI]
d1:	MOV	AX,DelayCnt
	XOR	DX,DX
	CALL	dDelayLoop
	LOOP	d1
d2:	jmp	short dDone

; Delay one timer tick or by CX iterations

dDelayLoop:

d3:	SUB	AX,1
	SBB	DX,0
	JC	d4
	CMP	BL,ES:[DI]
	JE	d3
d4:	retn
dDone:
	pop	es

	jmp	short return_from_Delay

DelayCnt dw	0000

@cx:	dd	 0.0
@cy:	dd	 0.7
;@cx:	dd	 0.3
;@cy:	dd	-0.5
;@cx:	dd	-1.139
;@cy:	dd	 0.238

@c80:	dw	MaxX/4
@c50:	dw	MaxY/4
@c4:	dw	4
@c2:	dw	2
dred:	db	1
dblu:	db	1
dgri:	db	1

		db	0Dh,0Ah
		db	'<< Jylia Set created by Arkady Antipin & Andrew Ryzhkov >>',0Dh,0Ah,'$'
CPU286No	db	'80286 or above required !',0Dh,0Ah,'$'
CO287No		db	'80287 or above required !',0Dh,0Ah,'$'
VGANoExist	db	'VGA or above required !',0Dh,0Ah,'$'

@opp:	dw	0

VideoData:	dw  0604h, 0F02h, 00E7h, 6B00H, 5901H, 5A02H, 8E03H, 5E04H, 8A05H
		dw  0D06H, 3E07H, 4009H,0EA10H,0DF12H, 2D13H, 0014h,0E715H, 0616h
		dw 0E317H,0AC11H
pall:

end	go

end
