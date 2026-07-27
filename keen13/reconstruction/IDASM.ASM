; Reconstructed Commander Keen 1-3 Source Code
; Copyright (C) 2021-2025 K1n9_Duk3
;
; The code in this file is primarily based on:
;  Hovertank 3-D Source Code
;   Copyright (C) 1993-2014 Flat Rock Software
;  The Catacomb Source Code
;   Copyright (C) 1993-2014 Flat Rock Software
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

IDEAL
MODEL	SMALL,C

INCLUDE "BSSCHEAT.EQU"

;============================================================================
;
;                 Gamer's Edge Library, ASM section
;
;============================================================================



;============================================================================
;
;                      EGA Graphic routines
;
;============================================================================

SC_INDEX	=	03C4h
SC_RESET	=	0
SC_CLOCK	=	1
SC_MAPMASK	=	2
SC_CHARMAP	=	3
SC_MEMMODE	=	4

CRTC_INDEX	=	03D4h
CRTC_H_TOTAL	=	0
CRTC_H_DISPEND	=	1
CRTC_H_BLANK	=	2
CRTC_H_ENDBLANK	=	3
CRTC_H_RETRACE	=	4
CRTC_H_ENDRETRACE =	5
CRTC_V_TOTAL	=	6
CRTC_OVERFLOW	=	7
CRTC_ROWSCAN	=	8
CRTC_MAXSCANLINE =	9
CRTC_CURSORSTART =	10
CRTC_CURSOREND	=	11
CRTC_STARTHIGH	=	12
CRTC_STARTLOW	=	13
CRTC_CURSORHIGH	=	14
CRTC_CURSORLOW	=	15
CRTC_V_RETRACE	=	16
CRTC_V_ENDRETRACE =	17
CRTC_V_DISPEND	=	18
CRTC_OFFSET	=	19
CRTC_UNDERLINE	=	20
CRTC_V_BLANK	=	21
CRTC_V_ENDBLANK	=	22
CRTC_MODE	=	23
CRTC_LINECOMPARE =	24


GC_INDEX	=	03CEh
GC_SETRESET	=	0
GC_ENABLESETRESET =	1
GC_COLORCOMPARE	=	2
GC_DATAROTATE	=	3
GC_READMAP	=	4
GC_MODE		=	5
GC_MISCELLANEOUS =	6
GC_COLORDONTCARE =	7
GC_BITMASK	=	8

ATR_INDEX	=	03c0h
ATR_MODE	=	16
ATR_OVERSCAN	=	17
ATR_COLORPLANEENABLE =	18
ATR_PELPAN	=	19
ATR_COLORSELECT	=	20

STATUS_REGISTER_1     =	03DAh


SCREENWIDTH	equ	48

PORTTILESWIDE	equ	21
PORTTILESHIGH	equ	14
PORTTILECOUNT	=	(PORTTILESWIDE*PORTTILESHIGH)

MAXTILES	= 	700

;
; offsets into sprite/pictable
;
PICWIDTHOFS	equ	0
PICHEIGHTOFS	equ	2
PICPTROFS	equ	4


DATASEG

drawseg		dw	0
screenseg	dw	0
screenofs	dw	0
screenpan	dw	0
screenstart	dw	0
		dw	0	; unknown/unused
		
ifndef USELOOPS
animtable	dw	0
endif

PUBLIC	screenseg

EXTRN	pictable:WORD
EXTRN	spritetable:WORD
EXTRN	grsegs:WORD		; master location table for all graphics


LABEL EGAtileloc WORD	; only used in early builds WITHOUT unwound refresh code
	dw   604h,  606h,  608h,  60Ah,  60Ch,  60Eh,  610h
	dw   612h,  614h,  616h,  618h,  61Ah,  61Ch,  61Eh
	dw   620h,  622h,  624h,  626h,  628h,  62Ah,  62Ch
	dw   904h,  906h,  908h,  90Ah,  90Ch,  90Eh,  910h
	dw   912h,  914h,  916h,  918h,  91Ah,  91Ch,  91Eh
	dw   920h,  922h,  924h,  926h,  928h,  92Ah,  92Ch
	dw  0C04h, 0C06h, 0C08h, 0C0Ah, 0C0Ch, 0C0Eh, 0C10h
	dw  0C12h, 0C14h, 0C16h, 0C18h, 0C1Ah, 0C1Ch, 0C1Eh
	dw  0C20h, 0C22h, 0C24h, 0C26h, 0C28h, 0C2Ah, 0C2Ch
	dw  0F04h, 0F06h, 0F08h, 0F0Ah, 0F0Ch, 0F0Eh, 0F10h
	dw  0F12h, 0F14h, 0F16h, 0F18h, 0F1Ah, 0F1Ch, 0F1Eh
	dw  0F20h, 0F22h, 0F24h, 0F26h, 0F28h, 0F2Ah, 0F2Ch
	dw  1204h, 1206h, 1208h, 120Ah, 120Ch, 120Eh, 1210h
	dw  1212h, 1214h, 1216h, 1218h, 121Ah, 121Ch, 121Eh
	dw  1220h, 1222h, 1224h, 1226h, 1228h, 122Ah, 122Ch
	dw  1504h, 1506h, 1508h, 150Ah, 150Ch, 150Eh, 1510h
	dw  1512h, 1514h, 1516h, 1518h, 151Ah, 151Ch, 151Eh
	dw  1520h, 1522h, 1524h, 1526h, 1528h, 152Ah, 152Ch
	dw  1804h, 1806h, 1808h, 180Ah, 180Ch, 180Eh, 1810h
	dw  1812h, 1814h, 1816h, 1818h, 181Ah, 181Ch, 181Eh
	dw  1820h, 1822h, 1824h, 1826h, 1828h, 182Ah, 182Ch
	dw  1B04h, 1B06h, 1B08h, 1B0Ah, 1B0Ch, 1B0Eh, 1B10h
	dw  1B12h, 1B14h, 1B16h, 1B18h, 1B1Ah, 1B1Ch, 1B1Eh
	dw  1B20h, 1B22h, 1B24h, 1B26h, 1B28h, 1B2Ah, 1B2Ch
	dw  1E04h, 1E06h, 1E08h, 1E0Ah, 1E0Ch, 1E0Eh, 1E10h
	dw  1E12h, 1E14h, 1E16h, 1E18h, 1E1Ah, 1E1Ch, 1E1Eh
	dw  1E20h, 1E22h, 1E24h, 1E26h, 1E28h, 1E2Ah, 1E2Ch
	dw  2104h, 2106h, 2108h, 210Ah, 210Ch, 210Eh, 2110h
	dw  2112h, 2114h, 2116h, 2118h, 211Ah, 211Ch, 211Eh
	dw  2120h, 2122h, 2124h, 2126h, 2128h, 212Ah, 212Ch
	dw  2404h, 2406h, 2408h, 240Ah, 240Ch, 240Eh, 2410h
	dw  2412h, 2414h, 2416h, 2418h, 241Ah, 241Ch, 241Eh
	dw  2420h, 2422h, 2424h, 2426h, 2428h, 242Ah, 242Ch
	dw  2704h, 2706h, 2708h, 270Ah, 270Ch, 270Eh, 2710h
	dw  2712h, 2714h, 2716h, 2718h, 271Ah, 271Ch, 271Eh
	dw  2720h, 2722h, 2724h, 2726h, 2728h, 272Ah, 272Ch
	dw  2A04h, 2A06h, 2A08h, 2A0Ah, 2A0Ch, 2A0Eh, 2A10h
	dw  2A12h, 2A14h, 2A16h, 2A18h, 2A1Ah, 2A1Ch, 2A1Eh
	dw  2A20h, 2A22h, 2A24h, 2A26h, 2A28h, 2A2Ah, 2A2Ch
	dw  2D04h, 2D06h, 2D08h, 2D0Ah, 2D0Ch, 2D0Eh, 2D10h
	dw  2D12h, 2D14h, 2D16h, 2D18h, 2D1Ah, 2D1Ch, 2D1Eh
	dw  2D20h, 2D22h, 2D24h, 2D26h, 2D28h, 2D2Ah, 2D2Ch

LABEL ylookup WORD
	dw      0,   30h,   60h,   90h,  0C0h,  0F0h,  120h,  150h
	dw   180h,  1B0h,  1E0h,  210h,  240h,  270h,  2A0h,  2D0h
	dw   300h,  330h,  360h,  390h,  3C0h,  3F0h,  420h,  450h
	dw   480h,  4B0h,  4E0h,  510h,  540h,  570h,  5A0h,  5D0h
	dw   600h,  630h,  660h,  690h,  6C0h,  6F0h,  720h,  750h
	dw   780h,  7B0h,  7E0h,  810h,  840h,  870h,  8A0h,  8D0h
	dw   900h,  930h,  960h,  990h,  9C0h,  9F0h, 0A20h, 0A50h
	dw  0A80h, 0AB0h, 0AE0h, 0B10h, 0B40h, 0B70h, 0BA0h, 0BD0h
	dw  0C00h, 0C30h, 0C60h, 0C90h, 0CC0h, 0CF0h, 0D20h, 0D50h
	dw  0D80h, 0DB0h, 0DE0h, 0E10h, 0E40h, 0E70h, 0EA0h, 0ED0h
	dw  0F00h, 0F30h, 0F60h, 0F90h, 0FC0h, 0FF0h, 1020h, 1050h
	dw  1080h, 10B0h, 10E0h, 1110h, 1140h, 1170h, 11A0h, 11D0h
	dw  1200h, 1230h, 1260h, 1290h, 12C0h, 12F0h, 1320h, 1350h
	dw  1380h, 13B0h, 13E0h, 1410h, 1440h, 1470h, 14A0h, 14D0h
	dw  1500h, 1530h, 1560h, 1590h, 15C0h, 15F0h, 1620h, 1650h
	dw  1680h, 16B0h, 16E0h, 1710h, 1740h, 1770h, 17A0h, 17D0h
	dw  1800h, 1830h, 1860h, 1890h, 18C0h, 18F0h, 1920h, 1950h
	dw  1980h, 19B0h, 19E0h, 1A10h, 1A40h, 1A70h, 1AA0h, 1AD0h
	dw  1B00h, 1B30h, 1B60h, 1B90h, 1BC0h, 1BF0h, 1C20h, 1C50h
	dw  1C80h, 1CB0h, 1CE0h, 1D10h, 1D40h, 1D70h, 1DA0h, 1DD0h
	dw  1E00h, 1E30h, 1E60h, 1E90h, 1EC0h, 1EF0h, 1F20h, 1F50h
	dw  1F80h, 1FB0h, 1FE0h, 2010h, 2040h, 2070h, 20A0h, 20D0h
	dw  2100h, 2130h, 2160h, 2190h, 21C0h, 21F0h, 2220h, 2250h
	dw  2280h, 22B0h, 22E0h, 2310h, 2340h, 2370h, 23A0h, 23D0h
	dw  2400h, 2430h, 2460h, 2490h, 24C0h, 24F0h, 2520h, 2550h
	dw  2580h, 25B0h, 25E0h, 2610h, 2640h, 2670h, 26A0h, 26D0h
	dw  2700h, 2730h, 2760h, 2790h, 27C0h, 27F0h, 2820h, 2850h
	dw  2880h, 28B0h, 28E0h, 2910h, 2940h, 2970h, 29A0h, 29D0h
	dw  2A00h, 2A30h, 2A60h, 2A90h, 2AC0h, 2AF0h, 2B20h, 2B50h
	dw  2B80h, 2BB0h, 2BE0h, 2C10h, 2C40h, 2C70h, 2CA0h, 2CD0h
	dw  2D00h, 2D30h, 2D60h, 2D90h, 2DC0h, 2DF0h, 2E20h, 2E50h
	dw  2E80h, 2EB0h, 2EE0h, 2F10h, 2F40h, 2F70h, 2FA0h, 2FD0h
	dw  3000h, 3030h, 3060h, 3090h, 30C0h, 30F0h, 3120h, 3150h
PUBLIC ylookup

tile_anim0	dw MAXTILES dup(0)
tile_anim1	dw MAXTILES dup(0)
tile_anim2	dw MAXTILES dup(0)
tile_anim3	dw MAXTILES dup(0)

animtabletable	dw tile_anim0, tile_anim1, tile_anim2, tile_anim3

PUBLIC tile_anim0, tile_anim1, tile_anim2, tile_anim3, animtabletable

EXTRN oldtiles:WORD
EXTRN oldtiles2:WORD
EXTRN spritesshown:WORD
EXTRN tilesshown:WORD
EXTRN picsshown:WORD
EXTRN uservect:WORD
EXTRN originx:DWORD
EXTRN originy:DWORD
EXTRN mapplane:DWORD
EXTRN mapbwide:WORD
EXTRN mapwidthextra:WORD
EXTRN EGApage:WORD
;EXTRN timecount:DWORD
EXTRN cyclespeed:WORD

EXTRN charptr:DWORD
EXTRN tileptr:DWORD
EXTRN picptr:DWORD

draw_x   equ 0
draw_y   equ 2
draw_num equ 4
drawsize equ 6

EXTRN spritelist:WORD
EXTRN tilelist:WORD
EXTRN piclist:WORD
EXTRN egasprites:WORD


CODESEG

MACRO	WORDOUT
if 0
	out	dx,al
	inc	dx
	xchg	al,ah
	out	dx,al
	dec	dx
	xchg	al,ah
else
	out	dx, ax
endif
ENDM


;====================
;
; RF_ForceRefresh
; Forces refresh to redraw all tiles (both pages)
;
;====================

PROC	RF_ForceRefresh
	USES	DI
	PUBLIC	RF_ForceRefresh

	mov	cx, PORTTILECOUNT
	mov	ax, ds
	mov	es, ax
	mov	di, offset oldtiles
	mov	ax, -1
	rep stosw
	mov	cx, PORTTILECOUNT
	mov	di, offset oldtiles2
	rep stosw
	ret
ENDP


ifdef USELOOPS

;=======================================================================
;
;	ADAPTIVE TILE REFRESH ROUTINES
;
;=======================================================================

PROC	DrawTile16
	USES DI

	mov	di, [EGAtileloc+di]
	mov	es, [drawseg]
	mov	ds, [WORD tileptr+2]
	movsb
	movsb
REPT 15
	add	di, SCREENWIDTH-2
	movsb
	movsb
ENDM
	mov	ax, ss
	mov	ds, ax
	mov	es, [WORD mapplane+2]
	ret
ENDP


PROC	DrawPage0
	
@@yloop:
	mov	cx, PORTTILESWIDE
@@xloop:
	mov	si, [es:bx+di]
	shl	si, 1
	mov	si, [bp+si]
	cmp	si, [oldtiles2+di]
	je	@@next
	mov	[oldtiles2+di], si
	call	DrawTile16
@@next:
	add	di, 2
	loop	@@xloop
	add	bx, [mapwidthextra]
	mov	ax, [screenofs]
	add	ax, 2
	mov	[screenofs], ax
	cmp	ax, PORTTILESHIGH*2
	jne	@@yloop
	ret
ENDP
EVEN

PROC	DrawPage1
	
@@yloop:
	mov	cx, PORTTILESWIDE
@@xloop:
	mov	si, [es:bx+di]
	shl	si, 1
	mov	si, [bp+si]
	cmp	si, [oldtiles+di]
	je	@@next
	mov	[oldtiles+di], si
	call	DrawTile16
@@next:
	add	di, 2
	loop	@@xloop
	add	bx, [mapwidthextra]
	mov	ax, [screenofs]
	add	ax, 2
	mov	[screenofs], ax
	cmp	ax, PORTTILESHIGH*2
	jne	@@yloop
	ret
ENDP
EVEN

else	; ifdef USELOOPS

;=======================================================================
;
;	UNWOUND ADAPTIVE TILE REFRESH ROUTINES
;
;=======================================================================

; This code is too big to fit in the default code segment (SMALL model)
; so we need to put it in its own far code segment.
; (The PRIVATE part is what makes this its own far code segment.)

SEGMENT FARREFRESH PARA PRIVATE 'CODE'
ASSUME CS:FARREFRESH

PROC	DrawTile16 NEAR
PUBLIC	DrawTile16

	mov	es, [drawseg]
	mov	ds, [WORD tileptr+2]
	movsb
	movsb
REPT 15
	add	di, dx
	movsb
	movsb
ENDM
	mov	ax, ss
	mov	ds, ax
	mov	es, cx
	ret
ENDP

;-----------------------------------------------------------------------
;	MACROS FOR GENERATING THE REFRESH ROUTINES
;-----------------------------------------------------------------------

MACRO	MAKELAB NUM

@@lab&NUM:

ENDM

MACRO	MAKEJE NUM

	je	@@lab&NUM

ENDM

MACRO DRAWAPAGE OFFSETS
	_tileoff = 0
	_drawoff = 0
	mov	dx, SCREENWIDTH-2
	mov	cx, es

REPT PORTTILESHIGH
REPT PORTTILESWIDE
	mov	si, [es:bx+_tileoff]	; read tile number from map
	shl	si, 1			; convert to index
	mov	si, [bp+si]		; convert to tile image offset (also handles animation)
	cmp	si, [OFFSETS+_tileoff]	; same tile image as before?
MAKEJE %_tileoff
	mov	[OFFSETS+_tileoff], si
	mov	di, 604h + _drawoff
	call	DrawTile16
MAKELAB %_tileoff

	_tileoff = _tileoff + 2
	_drawoff = _drawoff + 2

ENDM	; end of the inner REPT

	add	bx, [mapwidthextra]
	_drawoff = _drawoff + 16*SCREENWIDTH - 2*PORTTILESWIDE

ENDM	; end of the outer REPT
ENDM	; end of the 'DRAWAPAGE' MACRO

;-----------------------------------------------------------------------
; This macro may look small at first glance, but the code it generates is
; absolutely massive. Unwinding the nested repeats results in 294 copies
; of the innermost code. Each DrawPage routine takes up 7347 bytes !
;-----------------------------------------------------------------------


PROC	DrawPage1 FAR
	DRAWAPAGE oldtiles
	ret
ENDP


PROC	DrawPage0 FAR
	DRAWAPAGE oldtiles2
	ret
ENDP

;=======================================================================
ENDS	; end of the 'FARREFRESH' segment
;=======================================================================

endif	; ifdef USELOOPS ... else ...

;============================================================================
CODESEG
;============================================================================

;====================
;
; VidRefresh
;
;====================

PROC	VidRefresh
	USES	SI, DI
	PUBLIC	VidRefresh

	call	VidInitDraw
	mov	ax, GC_MODE + 1*256
	mov	dx, GC_INDEX
	out	dx, ax
; Note:
; The code assumes that SC_MAPMASK is set to 15 (all planes).
; Might be better to set that here, too, just to be safe.

	cld
	xor	di, di
	mov	[screenofs], di		; screenofs is not used by the unwound refresh

	mov	ax, [WORD originy+1]
	shr	ax, 1
	shr	ax, 1
	shr	ax, 1
	shr	ax, 1
	mov	bx, [mapbwide]
	mul	bx
	mov	bx, ax
	mov	ax, [WORD originx+1]
	shr	ax, 1
	shr	ax, 1
	shr	ax, 1
	shr	ax, 1
	shl	ax, 1
	add	bx, ax
	add	bx, [WORD mapplane]
	mov	es, [WORD mapplane+2]	; ES:BX points to top-left tile in viewport

	mov	bp, [WORD timecount]
	mov	cl, [BYTE cyclespeed]
	shr	bp, cl
	and	bp, 6
	mov	bp, [animtabletable+bp]
ifndef USELOOPS
	mov	[animtable], bp
endif

;
; refresh background tiles
;
	mov	ax, [EGApage]
	or	ax, ax
	jnz	@@l1
	call	DrawPage0
	jmp	@@l2
@@l1:
	call	DrawPage1
@@l2:

	push	[screenseg]
	mov	ax, [drawseg]
	mov	[screenseg], ax

;
; draw sprites (if any)
;
	mov	cx, [spritesshown]
	jcxz	@@drawtiles
	xor	bp, bp
@@spriteloop:
	push	cx
	push	[spritelist + draw_num +bp]
	push	[spritelist + draw_y +bp]
	push	[spritelist + draw_x +bp]
	call	DrawSprite
	add	sp, 6
	pop	cx
	add	bp, drawsize
	loop	@@spriteloop

@@drawtiles:
;
; draw foreground tiles (if any)
;
	mov	cx, [tilesshown]
	jcxz	@@drawpics
	xor	bp, bp
@@tileloop:
	push	cx
	push	[tilelist + draw_num + bp]
	push	[tilelist + draw_y + bp]
	push	[tilelist + draw_x + bp]
	call	DrawTile
	add	sp, 6
	pop	cx
	add	bp, drawsize
	loop	@@tileloop

@@drawpics:
;
; draw pics (if any)
;
	mov	cx, [picsshown]
	jcxz	@@dohook
	xor	bp, bp
@@picloop:
	push	cx
	push	[WORD piclist + draw_num + bp]
	push	[WORD piclist + draw_y + bp]
	push	[WORD piclist + draw_x + bp]
	call	DrawPic
	add	sp, 6
	pop	cx
	add	bp, drawsize
	loop	@@picloop

@@dohook:
;
; run user refresh vector (if not NULL)
;
	pop	[screenseg]
	mov	cx, [uservect]
	jcxz	@@setscreen
	call	cx

@@setscreen:
; Note: This code is a bit buggy. Since the CRTC start address consists of two
; bytes that can't be written simultaneously, it is possible that the video
; card "latches" (i.e., "reads") the start address for the next refresh in
; between these two port writes, meaning it combines the high byte of the new
; address with the low byte of the old address, causing the video card to
; display the wrong memory region for one refresh. Since the start address
; gets "latched" at the beginning of the vertical retrace, the code should
; check the status register and wait for an active display signal (no vertical
; or horizontal retrace bits set) before writing the new CRTC start address.
; This code will definitely need to be modified if you want to add AdLib music,
; since the interrupt-driven music playback code could cause this code to
; "miss" the VBL before the panning register is updated. You will most likely
; need to have two different versions to handle the delay before/after setting
; the panning register correctly. Check out the "Foray in the Forest 2.0"
; source code for my recommended solution.

;
; set CRTC start
;
	mov	cx, [screenstart]
	mov	dx, CRTC_INDEX
	mov	al, CRTC_STARTHIGH
	out	dx, al
	inc	dx
	mov	al, ch
	out	dx, al
	dec	dx
	mov	al, CRTC_STARTLOW
	out	dx, al
	inc	dx
	mov	al, cl
	out	dx, al

ifdef OLDKEYBOARD

	mov	ax, 1
	push	ax
	call	WaitVBL
	pop	ax

else

@@wait1:
	mov	dx, STATUS_REGISTER_1
	in	al, dx
	test	al, 8
	jnz	@@wait1

;
; set CRTC start ... again (why?)
;
	mov	bx, [screenstart]
	mov	dx, CRTC_INDEX
	mov	al, CRTC_STARTHIGH
	out	dx, al
	inc	dx
	mov	al, bh
	out	dx, al
	dec	dx
	mov	al, CRTC_STARTLOW
	out	dx, al
	inc	dx
	mov	al, bl
	out	dx, al
@@wait2:
	mov	dx, STATUS_REGISTER_1
	in	al, dx
	test	al, 8
	jz	@@wait2
	
endif

	mov	dx, STATUS_REGISTER_1
	in	al, dx

;
; set horizontal panning
;
	mov	dx, ATR_INDEX
	mov	al, ATR_PELPAN or 20h
	out	dx, al
	mov	ax, [screenpan]
	out	dx, al

	ret
ENDP

;====================
;
; VidInitDraw
;
;====================

PROC	VidInitDraw
	PUBLIC	VidInitDraw

	mov	[screenstart], 4
	mov	ax, [WORD originx]
	test	ax, 800h	; scrolled more than 8 pixels to the right?
	jz	@@l1
	inc	[screenstart]
@@l1:
	mov	ax, [WORD originx+1]
	and	ax, 7
	mov	[screenpan], ax

	xor	[EGApage], 1
	test	[EGApage], 1
	jnz	@@page1
	mov	cx, 0A000h
	jmp	@@l2
@@page1:
	mov	cx, 0A300h
	add	[screenstart], 3000h
@@l2:
	mov	[drawseg], cx
	mov	ax, [WORD originy+1]
	and	ax, 15
	mov	bl, SCREENWIDTH
	mul	bl
	add	ax, SCREENWIDTH*32
	add	[screenstart], ax
	mov	ax, [screenstart]
	shr	ax, 1
	shr	ax, 1
	shr	ax, 1
	shr	ax, 1
	add	ax, 0A000h
	mov	[screenseg], ax
	ret
ENDP


CODESEG

picwidth	dw	0
picxcoord	dw	0
picheight	dw	0



;=======================================================================

;=============
;
; DrawChar (int xcoord, int ycoord, int charnum)
;
; xcoord in bytes, ycoord in pixels
;
;=============

PROC	DrawChar xcoord:WORD, ycoord:WORD, charnum:WORD
USES	SI,DI
PUBLIC	DrawChar

	mov	es,[screenseg]

	mov	di,[xcoord]
	mov	bx,[ycoord]
	shl	bx,1
	add	di,[ylookup+bx]	;screen destination

	cld

	cli
	mov	dx,GC_INDEX
	mov	ax,GC_MODE + 1*256
	out	dx,ax		;set write mode 1

	mov	si,[charnum]
	shl	si,1
	shl	si,1
	shl	si,1
	mov	bx,si	; useless!
	mov	cx,di	; useless!

	mov	ax,[WORD charptr+2] ; segment for all tile8s
	mov	ds,ax

;
; start drawing
;

REPT 8
	movsb
	add	di,SCREENWIDTH-1
ENDM

	sti

	mov	ax,ss
	mov	ds,ax		;restore turbo's data segment

	ret

ENDP

;=============
;
; DrawTile (int xcoord, int ycoord, int charnum)
;
; xcoord in bytes, ycoord in pixels
;
;=============

PROC	DrawTile xcoord:WORD, ycoord:WORD, tilenum:WORD
USES	SI,DI
PUBLIC	DrawTile

	mov	es,[screenseg]

	mov	di,[xcoord]
	mov	bx,[ycoord]
	shl	bx,1
	add	di,[ylookup+bx]	;screen destination
	mov	si,[tilenum]
	or	si,si
	js	@@masked
	
ifdef USELOOPS
REPT 5
	shl	si,1
ENDM
else
	shl	si,1
	add	si,[animtable]
	mov	si,[si]		; convert tile number to memory address (and handle animation)
endif

	mov	ax,[WORD tileptr+2]
	mov	ds,ax

	cld

	cli
	mov	dx,SC_INDEX
	mov	ax,SC_MAPMASK + 15*256	; write to all planes
	out	dx,ax
	mov	ax,GC_MODE + 1*256	; write mode 1
	mov	dx,GC_INDEX
	out	dx,ax
	sti
;
; start drawing
;
REPT 15
	movsb
	movsb
	add	di,SCREENWIDTH-2
ENDM
	movsb
	movsb

	mov	ax,ss
	mov	ds,ax		;restore turbo's data segment

	ret

@@masked:
	and	si,7fffh	; not really required (sign bit gets shifted out anyway)
REPT 5
	shl	si,1
ENDM
	; si is now the memory offset of the tile image (without animation)

	mov	ax,[WORD tileptr+2]
	mov	ds,ax

	mov	dx,GC_INDEX
	mov	ax,GC_MODE	; write mode 0
	out	dx, ax

;
; draw plane 0 (blue)
;
	mov	dx,GC_INDEX
	mov	ax,GC_READMAP + 0*256	; read from plane 0
	out	dx, ax
	mov	dx,SC_INDEX
	mov	ax,SC_MAPMASK + 1*256	; write to plane 0
	out	dx,ax
	push	si
	push	di
	mov	cx,16
@@blueloop:
	mov	ax,[es:di]
	mov	bx,[si+20h]
	mov	dx,[si]
	and	ax,bx
	xor	bx,-1		; 'not bx' would probably be faster
	and	dx,bx
	or	ax,dx
	stosw
	add	si,2
	add	di,SCREENWIDTH-2
	loop	@@blueloop
	pop	di
	pop	si
;
; draw plane 1 (green)
;
	mov	dx,GC_INDEX
	mov	ax,GC_READMAP + 1*256	; read from plane 1
	out	dx, ax
	mov	dx,SC_INDEX
	mov	ax,SC_MAPMASK + 2*256	; write to plane 1
	out	dx,ax
	push	si
	push	di
	mov	cx,16
@@greenloop:
	mov	ax,[es:di]
	mov	bx,[si+20h]
	mov	dx,[si]
	and	ax,bx
	xor	bx,-1		; 'not bx' would probably be faster
	and	dx,bx
	or	ax,dx
	stosw
	add	si,2
	add	di,SCREENWIDTH-2
	loop	@@greenloop
	pop	di
	pop	si
;
; draw plane 2 (red)
;
	mov	dx,GC_INDEX
	mov	ax,GC_READMAP + 2*256	; read from plane 2
	out	dx, ax
	mov	dx,SC_INDEX
	mov	ax,SC_MAPMASK + 4*256	; write to plane 2
	out	dx,ax
	push	si
	push	di
	mov	cx,16
@@redloop:
	mov	ax,[es:di]
	mov	bx,[si+20h]
	mov	dx,[si]
	and	ax,bx
	xor	bx,-1		; 'not bx' would probably be faster
	and	dx,bx
	or	ax,dx
	stosw
	add	si,2
	add	di,SCREENWIDTH-2
	loop	@@redloop
	pop	di
	pop	si
;
; draw plane 3 (intensity)
;
	mov	dx,GC_INDEX
	mov	ax,GC_READMAP + 3*256	; read from plane 3
	out	dx, ax
	mov	dx,SC_INDEX
	mov	ax,SC_MAPMASK + 8*256	; write to plane 3
	out	dx,ax
	push	si
	push	di
	mov	cx,16
@@intensityloop:
	mov	ax,[es:di]
	mov	bx,[si+20h]
	mov	dx,[si]
	and	ax,bx
	xor	bx,-1		; 'not bx' would probably be faster
	and	dx,bx
	or	ax,dx
	stosw
	add	si,2
	add	di,SCREENWIDTH-2
	loop	@@intensityloop
	pop	di
	pop	si

	mov	ax,GC_MODE + 1*256	; write mode 1
	mov	dx,GC_INDEX
	out	dx,ax
	mov	dx,SC_INDEX
	mov	al,SC_MAPMASK
	mov	ah,15			; write to all planes
	out	dx,ax

	sti
	mov	ax,ss
	mov	ds,ax		;restore turbo's data segment

	ret

ENDP

;=======================================================================

;============
;
; DrawPic (int xcoord, int ycoord, int picnum)
;
; xcoord in bytes, ycoord in pixels
;
;============

PROC	DrawPic xcoord:WORD, ycoord:WORD, picnum:WORD
USES	SI,DI
PUBLIC	DrawPic


	mov	si,[picnum]
	shl	si,1
	shl	si,1
	shl	si,1
	shl	si,1

	mov	es,[WORD pictable+2]
	mov	ax,[es:si+PICWIDTHOFS]
	mov	[cs:picwidth],ax
	mov	ax,[es:si+PICHEIGHTOFS]
	mov	[cs:picheight],ax
	mov	si,[es:si+PICPTROFS]
	mov	ax,[xcoord]
	mov	[cs:picxcoord],ax

	mov	es,[screenseg]

	cld

;
; start drawing
;

	cli
	mov	dx,SC_INDEX		;write to all planes
	mov	al,SC_MAPMASK
	out	dx,al
	mov	al,15
	inc	dx
	out	dx,al

	mov	dx,GC_INDEX		;set write mode 1
	mov	al,GC_MODE
	out	dx,al
	mov	al,1
	inc	dx
	out	dx,al
	sti

	mov	bx,[ycoord]
	shl	bx,1
	mov	cx,[WORD picptr+2]
	mov	ds,cx
@@lineloop:
	mov	di,[ss:ylookup+bx]
	add	bx,2
	add	di,[cs:picxcoord]
	mov	cx,[cs:picwidth]
	rep movsb
	dec	[cs:picheight]
	jnz	@@lineloop

	mov	ax,ss
	mov	ds,ax		;restore turbo's data segment

	ret

ENDP


;============
;
; DrawSprite (int xcoord, int ycoord, int spritenum)
;
; xcoord in bytes, ycoord in pixels
;
;============

DATASEG

EGAdraws	dw	0,EGAone,EGAtwo,EGAthree,EGAfour,EGAfive,EGAsix
ifndef BETA
		dw	EGAseven,EGAeight
endif

spriteroutine 	dw 	0

blockheight	dw	0
blocksource	dw	0
		dw	0	; unknown/unused
_zero		dw	0	; value stays constant
		dw	0	; unknown/unused
blockdest	dw	0
_three		dw	0	; is written to but never used for anything
		

CODESEG

PROC	DrawSprite xcoord:WORD, ycoord:WORD, spritenum:WORD
USES	SI,DI
PUBLIC	DrawSprite

	mov	ax,[xcoord]
	mov	bx,[ycoord]
	shl	bx,1
	add	ax,[ylookup+bx]
	mov	[blockdest],ax
	mov	bx,[spritenum]
	shl	bx,1
	shl	bx,1
	shl	bx,1
	shl	bx,1
	shl	bx,1
	mov	es,[WORD spritetable+2]
	mov	ax,[es:bx+PICHEIGHTOFS]
	mov	[blockheight],ax
	mov	ax,[es:bx+PICPTROFS]
	mov	[blocksource],ax
	mov	bx,[es:bx+PICWIDTHOFS]
	shl	bx,1
	mov	ax,[EGAdraws+bx]
	mov	[spriteroutine],ax
	mov	ax,3
	mov	[_three],ax
	mov	es,[screenseg]

	cld

	cli	; disable interrupts (sprite routine changes SS!)

	mov	dx,GC_INDEX
	mov	ax,GC_MODE	; write mode 0
	out	dx,ax

;
; draw plane 0
;
	mov	dx,GC_INDEX
	mov	ax,0*256+GC_READMAP
	WORDOUT
	mov	dx,SC_INDEX
	mov	ax,1*256+SC_MAPMASK
	WORDOUT
	mov	di,[blockdest]
	mov	cx,[blockheight]
	mov	si,[blocksource]
	mov	bp,[_zero]
	mov	ax,[egasprites+8]
	mov	ds,[egasprites]
	call	[ss: spriteroutine]		;draw the plane's data

;
; draw plane 1
;
	mov	dx,GC_INDEX
	mov	ax,1*256+GC_READMAP
	WORDOUT
	mov	dx,SC_INDEX
	mov	ax,2*256+SC_MAPMASK
	WORDOUT
	mov	di,[blockdest]
	mov	cx,[blockheight]
	mov	si,[blocksource]
	mov	bp,[_zero]
	mov	ax,[egasprites+8]
	mov	ds,[egasprites+2]
	call	[ss: spriteroutine]		;draw the plane's data


;
; draw plane 2
;
	mov	dx,GC_INDEX
	mov	ax,2*256+GC_READMAP
	WORDOUT
	mov	dx,SC_INDEX
	mov	ax,4*256+SC_MAPMASK
	WORDOUT
	mov	di,[blockdest]
	mov	cx,[blockheight]
	mov	si,[blocksource]
	mov	bp,[_zero]
	mov	ax,[egasprites+8]
	mov	ds,[egasprites+4]
	call	[ss: spriteroutine]		;draw the plane's data

;
; draw plane 3
;
	mov	dx,GC_INDEX
	mov	ax,3*256+GC_READMAP
	WORDOUT
	mov	dx,SC_INDEX
	mov	ax,8*256+SC_MAPMASK
	WORDOUT
	mov	di,[blockdest]
	mov	cx,[blockheight]
	mov	si,[blocksource]
	mov	bp,[_zero]
	mov	ax,[egasprites+8]
	mov	ds,[egasprites+6]
	call	[ss: spriteroutine]		;draw the plane's data

;
; drawing done
;
	mov	ax,1*256+GC_MODE		; write mode 1
	mov	dx,GC_INDEX
	WORDOUT
	mov	dx,SC_INDEX
	mov	al,SC_MAPMASK
	mov	ah,15
	WORDOUT

	sti	; enable interrupts

	ret

ENDP


;===========================================================================
;
; sprite routines
;
;===========================================================================

PROC	EGAone
	mov	ss,ax
@@lineloop:
	mov	al,[es:di]
	and	al,[ss:si]
	or	al,[si]
	stosb
	inc	si
	add	di,SCREENWIDTH-1
	loop	@@lineloop

	mov	ax,@Data
	mov	ds,ax
	mov	ss,ax
	ret
ENDP

;=================

PROC	EGAtwo
	mov	ss,ax
@@lineloop:
	mov	ax,[es:di]
	and	ax,[ss:si]
	or	ax,[si]
	stosw
	add	si,2
	add	di,SCREENWIDTH-2
	loop	@@lineloop

	mov	ax,@Data
	mov	ds,ax
	mov	ss,ax
	ret
ENDP

;=================

PROC	EGAthree
	mov	ss,ax
@@lineloop:
	mov	ax,[es:di]
	and	ax,[ss:si]
	or	ax,[si]
	stosw
	mov	al,[es:di]
	and	al,[ss:si+2]
	or	al,[si+2]
	stosb
	add	si,3
	add	di,SCREENWIDTH-3
	loop	@@lineloop

	mov	ax,@Data
	mov	ds,ax
	mov	ss,ax
	ret
ENDP

;=================

PROC	EGAfour
	mov	ss,ax
@@lineloop:
	mov	ax,[es:di]
	and	ax,[ss:si]
	or	ax,[si]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+2]
	or	ax,[si+2]
	stosw
	add	si,4
	add	di,SCREENWIDTH-4
	loop	@@lineloop

	mov	ax,@Data
	mov	ds,ax
	mov	ss,ax
	ret
ENDP

;=================

PROC	EGAfive
	mov	ss,ax
@@lineloop:
	mov	ax,[es:di]
	and	ax,[ss:si]
	or	ax,[si]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+2]
	or	ax,[si+2]
	stosw
	mov	al,[es:di]
	and	al,[ss:si+4]
	or	al,[si+4]
	stosb
	add	si,5
	add	di,SCREENWIDTH-5
	loop	@@lineloop

	mov	ax,@Data
	mov	ds,ax
	mov	ss,ax
	ret
ENDP

;=================

PROC	EGAsix
	mov	ss,ax
@@lineloop:
	mov	ax,[es:di]
	and	ax,[ss:si]
	or	ax,[si]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+2]
	or	ax,[si+2]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+4]
	or	ax,[si+4]
	stosw
	add	si,6
	add	di,SCREENWIDTH-6
	loop	@@lineloop

	mov	ax,@Data
	mov	ds,ax
	mov	ss,ax
	ret
ENDP

;=================

ifndef BETA

PROC	EGAseven
	mov	ss,ax
@@lineloop:
	mov	ax,[es:di]
	and	ax,[ss:si]
	or	ax,[si]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+2]
	or	ax,[si+2]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+4]
	or	ax,[si+4]
	stosw
	mov	al,[es:di]
	and	al,[ss:si+6]
	or	al,[si+6]
	stosb
	add	si,7
	add	di,SCREENWIDTH-7
	loop	@@lineloop

	mov	ax,@Data
	mov	ds,ax
	mov	ss,ax
	ret
ENDP

;=================

PROC	EGAeight
	mov	ss,ax
@@lineloop:
	mov	ax,[es:di]
	and	ax,[ss:si]
	or	ax,[si]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+2]
	or	ax,[si+2]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+4]
	or	ax,[si+4]
	stosw
	mov	ax,[es:di]
	and	ax,[ss:si+6]
	or	ax,[si+6]
	stosw
	add	si,8
	add	di,SCREENWIDTH-8
	loop	@@lineloop

	mov	ax,@Data
	mov	ds,ax
	mov	ss,ax
	ret
ENDP

endif	; ifndef BETA


ifndef OLDKEYBOARD

;=======================================================================
;
;                     KEYBOARD ROUTINES
;
;=======================================================================


DATASEG
EVEN

ifndef VER_130
passtobios dw	0
PUBLIC passtobios
endif
oldint9	dd	0
keydown	db	128 dup (0)
ifdef VER_130
lastkey db	0
PUBLIC lastkey
endif
NBKscan	dw	0
NBKascii dw	0

scanascii db	0,27,49,50,51,52,53,54,55,56,57,48,45,61,8,9,113 ;'q'
	db	119,101,114,116,121,117,105,111,112,91,93,13,0,97,115 ;'s'
	db	100,102,103,104,106,107,108,59,39,96,0,92,122,120,99 ;'c'
	db	118,98,110,109,44,46,47,0,42,0,32,0,0,0,0,0,0,0,0,0,0,0 ;f10
	db	0,0,1,1,1,45,1,1,1,43,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0 ;shift-f10
	db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ;ctl-home
	db	0,0,0,0,0,0,0,0,0,0,0,0,0

PUBLIC	keydown,NBKscan,NBKascii

CODESEG

;========
;
; StartupKbd
;
; Sets up the new INT 8 ISR and various internal pointers.
; Assumes that the calling program has pointer soundseg to something
; meaningful...
;
;========

PROC	StartupKbd
PUBLIC	StartupKbd

	mov	ax,3509h	;call bios to get int 9
	int	21h
	mov	[WORD oldint9],bx
	mov	ax,es
	mov	[WORD oldint9+2],ax

	push	ds

	push	cs
	pop	ds
	lea	dx,[Int9Isr]
	mov	ax,2509h	;call bios to set int 9
	int	21h

	pop	ds

	ret

ENDP



;========
;
; ShutdownKbd
;
;========

PROC	ShutdownKbd
PUBLIC	ShutdownKbd

	push	ds

	mov	dx,[WORD Oldint9]
	mov	ds,[WORD Oldint9+2]
	mov	ax,2509h	;call bios to set int 9
	int	21h

	mov	ax,40h 		;clear ctrl/alt/shift flags
	mov	ds,ax
	mov	ax,[17h]
	and	ax,1111110011110000b
	mov	[17h],ax

	pop	ds
	ret

ENDP


;========
;
; NoBiosKey
;
;========

PROC	NoBiosKey	parm:WORD
PUBLIC	NoBiosKey

ifdef VER_130

	xor	bh,bh
	mov	ax,[parm]
	or	ax,ax
	jnz     @@bioskey1
@@waitforkey:
	mov	bl,[BYTE lastkey]
	or	bl,bl
	jz	@@waitforkey
	mov	ah, bl
	mov	al,[scanascii+bx]
	or	al,al
	jz	@@waitforkey
	mov	[BYTE NBKascii], al
	mov	[BYTE NBKscan], ah
	mov	[BYTE lastkey], bh	; bh is always 0 here
	ret
@@bioskey1:
	mov	bl,[BYTE lastkey]
	mov	ah, bl
	mov	al,[scanascii+bx]
	mov	[BYTE NBKascii], al
	mov	[BYTE NBKscan], ah
	or	al,al
	jnz	@@ok
	xor	ah,ah		; just a modifier key
@@ok:
	ret

else

	xor	bh,bh
	mov	ax,[parm]
	or	ax,ax
	jnz     @@bioskey1
@@waitforkey:
	mov	bl,[BYTE NBKscan]
	or	bl,bl
	jns	@@waitforkey
	and	bl, 7fh
	mov	[BYTE NBKscan], bl
	mov	ah, bl
	mov	al,[scanascii+bx]
	or	al,al
	jz	@@waitforkey
	mov	[BYTE NBKascii], al
	ret
@@bioskey1:
	mov	bl,[BYTE NBKscan]
	test	bl, 80h
	jnz	@@l1
	mov	ax, 0
	ret
@@l1:
	and	bl,7fh
	mov	ah, bl
	mov	al,[scanascii+bx]
	mov	[BYTE NBKascii], al
	or	al,al
	jnz	@@ok
	xor	ah,ah		; just a modifier key
@@ok:
	ret

endif

ENDP



;========
;
; Int9ISR
; only called by interrupt $9!
;
;=========

PROC	Int9ISR FAR
PUBLIC	Int9ISR

ifdef VER_130

	push	ax
	push	bx
	push	ds
	mov	al,20h
	out	20h,al		;we got the interrupt here
	
	mov	ax,_DATA
	mov	ds,ax		;ds to this data segment

	xor	ah,ah
	in	al,60h		;get the key pressed
	or	al,al

	jns	@@keydown
;
; key released
;
	and	al,7fh
	mov	bx,ax
	mov	[keydown+BX],ah	;keydown[key] = false
	jmp	@@keydone

@@keydown:
	mov	[BYTE lastkey],al	;set after press, cleared after
	mov	bx,ax			;NoBiosKey gets it
	mov	al,1
	mov	[keydown+BX],al	;keydown[key] = true
@@keydone:

;
; BUG? This doesn't turn the "clear keyboard" bit of port 0x61 on and back off
; again, and it doesn't call the BIOS int 9 handler, which would most likely
; have taken care of that. This didn't cause any problems on my 386 and in
; DOSBox, but it might be a problem on original IBM PC and/or PC-XT systems.
;
	pop	ds
	pop	bx
	pop	ax

	iret

else

	push	ax
	push	bx
	push	ds
	mov	ax,_DATA
	mov	ds,ax		;ds to this data segment

	xor	ah,ah
	in	al,60h		;get the key pressed
	or	al,al

	jns	@@keydown
;
; key released
;
	and	al,7fh
	mov	bx,ax
	mov	[keydown+BX],ah	;keydown[key] = false
	jmp	@@keydone

@@keydown:
	mov	[BYTE NBKscan],al
	or	[BYTE NBKscan],80h	;high bit set after press, cleared
	mov	bx,ax			;after NoBiosKey gets it
	mov	al,1
	mov	[keydown+BX],al	;keydown[key] = true
@@keydone:
	test	[passtobios], 1
	jz	@@done
	pushf
	call	[oldint9]
	mov	ax, 40h
	mov	ds, ax
	mov	ax, [WORD 1Ah]
	mov	[WORD 1Ch], ax	;flush BIOS keyboard buffer
@@done:
	mov	al,20h
	out	20h,al		;we got the interrupt here
;
; BUG? Writing 20h to port 20h only needs to be done when the code has NOT
; run the old BIOS int 9 handler. The BIOS handler *should* have already done
; this and I am not sure if writing it a second time might cause problems.
; Also, it might be a problem that the "clear keyboard" bit isn't toggled here
; when oldint9 didn't get executed (see version 1.3 code above).
;

	pop	ds
	pop	bx
	pop	ax

	iret

endif

ENDP

endif	; ifndef OLDKEYBOARD

;============================================================================
;
;                           SOUND ROUTINES
;
;============================================================================

	DATASEG

;
;offsets into .SPK file at segment SPKRfile, offset 0
;
;sound records each take up 16 bytes, and start at $10, and continue to $3F0

snd_start	equ	0
snd_priority	equ	2
snd_samples	equ	3
snd_name	equ	4

LABEL	inttime WORD
timecount	dd	0,0	;fast timer tics since startup

SPKactive dw    0                   ;set non zero when started

SoundData	dd	0

soundmode	dw	1       ;0=nosound, 1=SPKR, 2= adlib...
OldInt8		dd	?	;StartupSPK saves here, Shutdown restores
Intcount	db	?	;counter for extraints, call OldInt8 at 0

SndPtr		dw	?	;Pointer to frequency of current sound
SndPriority	db	?	;current sound's priority

pausesndptr	dw	?
pausepriority	db	?
pauseintcount	db	?

dontplay	dw	0	;set to 1 to avoid all interrupt and timer stuff

int8hook	dw	0	;gets called every tic if not null

soundseg	dw	?

PUBLIC soundmode,dontplay,timecount,inttime,int8hook,soundseg,sndptr
PUBLIC SndPriority,SoundData

        CODESEG


;========
;
; StartupSound
;
; Sets up the new INT 8 ISR and various internal pointers.
; Assumes that the calling program has pointer soundseg to something
; meaningful...
;
;========

PROC StartupSound
	PUBLIC	StartupSound

	test	[dontplay],0ffffh
	je	@@dowork
	ret
@@dowork:
	test	[SPKactive],0FFFFh	;see if library is active
	jne	@@started		;library was allready started

@@start:
	call	NEAR PTR StopSound 	;make sure nothing is playing

	mov	ax,3508h	;call bios to get int 8
	int	21h
	mov	[WORD oldint8],bx
	mov	ax,es
	mov	[WORD oldint8+2],ax
	mov	ax, 8
	mov	[intcount], al

	push	ds

	push	cs
	pop	ds
	lea	dx,[UpdateSPKR]
	mov	ax,2508h	;call bios to set int 8
	int	21h

	pop	ds

	mov	bx,2000h
	cli
	mov	al,36h		;tell the timer chip we are going to
	out	43h,al		;change the speed of timer 0
	mov	al,0
	mov	al,bl
	out	40h,al		;low
	mov	al,bh
	out	40h,al		;high
	sti

	inc	[SPKactive]	;sound routines are now active

@@started:
	mov	ax,1
	mov	[soundmode],ax ;set soundmode to SPKR
	ret

ENDP


;========
;
; ShutdownSound
;
;========

PROC	ShutdownSound
	PUBLIC ShutdownSound

	test	[dontplay],0ffffh
	je	@@dowork
	ret
@@dowork:
	cli
	mov	al,36h		;tell the timer chip we are going to
	out	43h,al		;change the speed of timer 0
	mov	al,0		;system expects 0000 for rate
	out	40h,al		;low
	out	40h,al		;high
	sti

	mov	ax,[SPKactive]
	cmp	ax,0
	je	@@done		;sound library wasn't started...

	push	ds

	mov	dx,[WORD Oldint8]
	mov	ax,[WORD Oldint8+2]
	mov	ds,ax
	mov	ax,2508h	;call bios to set int 8
	int	21h

	pop	ds

	mov	[SPKactive],0	;sound routines are now inactive

	cli
	in	al,61h		;get peripheral (speaker) port value
	and	al,11111101b	;turn speaker off
	out	61h,al
	sti
@@done:
	ret

ENDP



;===========
;
; PlaySound (soundnum)
;
; If the sound's priority is >= the current priority, SoundPtr, SndPriority,
; and the timer speed are changed
;
; Hacked for sound blaster support!
;
;===========

PROC	PlaySound playnum:WORD
	USES	SI
	PUBLIC PlaySound

	test	[dontplay],-1	;for profiler
	je	@@dowork
	ret
@@dowork:
	mov	ax,[playnum]	;index into the sound headers

	mov	si,ax
	shl	si,1
	shl	si,1
	shl	si,1
	shl	si,1

	mov	ax,[WORD SoundData+2]
	mov	es,ax		;point es: to the spkr file

	mov	al,[es:si+snd_Priority]	;priority table (one byte each)
	cmp	al,[SndPriority]
	jb	@@playdone	;current sound has higher priority
	mov	[SndPriority],al
	mov	ax,[es:si+snd_Start]	;offset in .SPK file
	mov	[SndPtr],ax	;store it in the sound playing table


@@playdone:
	ret

ENDP


;======================================================================

;===========
;
; StopSound
;
;===========

PROC	StopSound
	PUBLIC	StopSound

	test	[dontplay],0ffffh
	je	@@dowork
	ret
@@dowork:
	xor	ax,ax		;set to 0
	mov	[SndPtr],ax
	mov	[SndPriority],al

	cli

	in	al,61h		;get peripheral (speaker) port value
	and	al,11111101b	;turn speaker off
	out	61h,al

	sti

	ret
ENDP

;======================================================================

;===========
;
; PauseSound
;
;===========

PROC	PauseSound
	PUBLIC	PauseSound

	test	[dontplay],0ffffh
	je	@@dowork
	ret
@@dowork:
	mov	ax,[SndPtr]	;save off the current values
	mov	[pausesndptr],ax
	mov	al,[SndPriority]
	mov	[pausepriority],al
	mov	al,[intcount]
	mov	[pauseintcount],al
	call	StopSound
	ret
ENDP

;======================================================================

;===========
;
; ContinueSound
;
;===========

PROC	ContinueSound
	PUBLIC	ContinueSound

	test	[dontplay],0ffffh
	je	@@dowork
	ret
@@dowork:
	mov	ax,[pausesndptr]
	mov	[SndPtr],ax	;restore the old values
	mov	al,[pausepriority]
	mov	[SndPriority],al
	mov	al,[pauseintcount]
	mov	[intcount],al

	ret
ENDP

;======================================================================

;========
;
; WaitendSound
; Just waits around until the current sound stops playing
;
;========

PROC	WaitEndSound
	PUBLIC WaitEndSound

	test	[dontplay],0ffffh
	je	@@dowork
	ret
@@dowork:
	pushf
	call FAR PTR UpdateSPKR	;in case a sound was just started and hasn't
				;been hit by an INT yet
@@wait:
	mov	ax,[sndptr]
	cmp	ax,0		;when the ptr is 0, nothing is on
	jne	@@wait

	ret

ENDP

;=========================================================================

;========
;
; UpdateSPKR
; only called by interrupt $8!
;
;=========

PROC	UpdateSPKR FAR
PUBLIC	UpdateSPKR

	push	ax
	push	bx
	push	cx
	push	si
	push	ds
	push	es

	mov	ax,@Data
	mov	ds,ax		;ds to this data segment

	mov	ax, [WORD SoundData+2]
	mov	es,ax		;es to sound file

	mov	al,20h
	out	20h,al		;we got the interrupt here

	add	[WORD timecount],1 ;inced once every VBL time
	adc	[WORD timecount+2],0

	dec	[intcount]	;see if it is time for a BIOS int 8...
	jnz	@@dosounds

	mov	al,8
	mov	[intcount],al	;reset interrupt counter

	pushf			;so the IRET from bios returns right
	call	[OldInt8]	;call the old BIOS timer routine

@@dosounds:
;
; play the speaker
;
	mov	si,[SndPtr]
	cmp	si,0
	je	@@nosound	;nothing playing

	mov	bx,[es:si]
	inc	[SndPtr]
	inc	[SndPtr]

	cmp	bx,0
	je	@@nosound	;a zero frequency is no sound, but don't stop

	cmp	bx,-1		;a -1 frequency is end of sound
	jne	@@playfreq

	call	StopSound
	jmp	@@doneplay

@@nosound:
	in	al,61h		;get peripheral (speaker) port value
	and	al,11111100b	;turn speaker off
	out	61h,al
	jmp	@@doneplay

@@playfreq:
	test	[soundmode],0FFh	;if soundon=0, don't play anything
	je	@@nosound

	mov	al,10110110b	;write to channel 2 (speaker) timer
	out	43h,al
	mov	al,bl
	out	42h,al		;low byte
	mov	al,bh
	out	42h,al		;high byte

	in	al,61h		;get peripheral (speaker) port value
	or	al,00000011b	;turn speaker on to timer
	out	61h,al

@@doneplay:

	pop	es
	pop	ds
	pop	si
	pop	cx
	pop	bx
	pop	ax

	iret


ENDP


;============================================================================
;
;                           RANDOM ROUTINES
;
;============================================================================

	DATASEG

rndindex	dw	?

rndtable db    0,   8, 109, 220, 222, 241, 149, 107,  75, 248, 254, 140,  16,  66
    db   74,  21, 211,  47,  80, 242, 154,  27, 205, 128, 161,  89,  77,  36
    db   95, 110,  85,  48, 212, 140, 211, 249,  22,  79, 200,  50,  28, 188
    db   52, 140, 202, 120,  68, 145,  62,  70, 184, 190,  91, 197, 152, 224
    db  149, 104,  25, 178, 252, 182, 202, 182, 141, 197,   4,  81, 181, 242
    db  145,  42,  39, 227, 156, 198, 225, 193, 219,  93, 122, 175, 249,   0
    db  175, 143,  70, 239,  46, 246, 163,  53, 163, 109, 168, 135,   2, 235
    db   25,  92,  20, 145, 138,  77,  69, 166,  78, 176, 173, 212, 166, 113
    db   94, 161,  41,  50, 239,  49, 111, 164,  70,  60,   2,  37, 171,  75
    db  136, 156,  11,  56,  42, 146, 138, 229,  73, 146,  77,  61,  98, 196
    db  135, 106,  63, 197, 195,  86,  96, 203, 113, 101, 170, 247, 181, 113
    db   80, 250, 108,   7, 255, 237, 129, 226,  79, 107, 112, 166, 103, 241
    db   24, 223, 239, 120, 198,  58,  60,  82, 128,   3, 184,  66, 143, 224
    db  145, 224,  81, 206, 163,  45,  63,  90, 168, 114,  59,  33, 159,  95
    db   28, 139, 123,  98, 125, 196,  15,  70, 194, 253,  54,  14, 109, 226
    db   71,  17, 161,  93, 186,  87, 244, 138,  20,  52, 123, 251,  26,  36
    db   17,  46,  52, 231, 232,  76,  31, 221,  84,  37, 216, 165, 212, 106
    db  197, 242,  98,  43,  39, 175, 254, 145, 190,  84, 118, 222, 187, 136
    db  120, 163, 236, 249


;
; Random # Generator vars
;
indexi		dw	?	;Rnd#Generator
indexj		dw	?
LastRnd		dw	?
RndArray	dw	17 dup (?)

baseRndArray	dw	1,1,2,3,5,8,13,21,54,75,129,204
   		dw	323,527,850,1377,2227

	CODESEG

;=================================================
;
; InitRnd (boolean randomize)
; if randomize is false, the counter is set to 0
;
;=================================================

PROC	InitRnd	randomize:word
	USES	SI,DI
	public	InitRnd

	mov	ax,ds
	mov	es,ax
	mov	di,offset RndArray
	mov	si,offset baseRndArray
	mov	cx,17
	cld
	rep	movsw		;set up the table (which is constantly changed)

	mov	[LastRnd],0
	mov	[indexi],17*2
	mov	[indexj],5*2

	mov	ax,[randomize]
	cmp	ax,0
	je	@@setit		;if randomize is true, really random

	mov	ah,2ch
	int	21h			;GetSystemTime

	mov	[RndArray+34-2],dx
	xor dx,cx				;init w/seconds values
	mov	[RndArray+10-2],dx

@@setit:
	mov	ax,0ffffh
	push	ax
	call	Rnd			;warm up generator!
	pop	ax

	ret

ENDP

;=================================================
;
; unsigned Random (unsigned maxval)
; Return a random # between 0-?
;
;=================================================

PROC	Rnd	maxval:WORD
	USES	SI
	public	Rnd

	mov	ax,[maxval]

	push	ax			;save max value
;
; create a mask to cut down on the # of SUBTRACTS!
;
	mov	dx,0ffffh		;full-mask
@@0:
	shl	ax,1
	jc	@@0a
	shr	dx,1
	jmp	@@0
@@0a:
	mov	bx,[indexi]		;this routine was converted from
	mov	si,[indexj]		;the Random macro on Merlin GS
	mov	ax,[RndArray-2+bx]
	adc	ax,[RndArray-2+si]
	mov	[RndArray-2+bx],ax
	add	ax,[LastRnd]
	mov	[LastRnd],ax
	dec	bx
	dec	bx
	jne	@@1
	mov	bx,17*2
@@1:
	dec	si
	dec	si
	jne	@@2
	mov	si,17*2
@@2:
	mov	[indexi],bx
	mov	[indexj],si
	pop	cx                      ;loop -- returns value in range
	and	ax,dx			;AND our mask!
@@3:
	cmp	ax,cx			;SUBTRACT to be within range
	jbe	@@4
	shr	ax,1
@@4:
	ret

ENDP



;=================================================
;
; InitRndT (boolean randomize)
; Init table based RND generator
; if randomize is false, the counter is set to 0
;
;=================================================

PROC	InitRndT randomize:word
	uses	si,di
	public	InitRndT

	mov	ax,[randomize]
	or	ax,ax
	jne	@@timeit		;if randomize is true, really random

	mov	dx,0			;set to a definate value
	jmp	@@setit

@@timeit:
	mov	ah,2ch
	int	21h			;GetSystemTime
	and	dx,0ffh

@@setit:
	mov	[rndindex],dx

	ret

ENDP

;=================================================
;
; int RandomT (void)
; Return a random # between 0-255
; Exit : AX = value
;
;=================================================
PROC	RndT
	public	RndT

	mov	bx,[rndindex]
	inc	bx
	and	bx,0ffh
	mov	[rndindex],bx
	mov	al,[rndtable+BX]
	xor	ah,ah

	ret

ENDP

;============================================================================
;
;                           MISC VIDEO ROUTINES
;
;============================================================================

;
; EGA registers
;
SCindex		equ	3C4h
SCmapmask	equ	2
GCindex		equ	3CEh
GCmode 		equ	5

STATUS_REGISTER_1     =	03dah

;========
;
; WaitVBL (int number)
;
;========

ifdef OLDKEYBOARD

PROC	WaitVBL number:WORD
	PUBLIC	WaitVBL

	mov	dx, STATUS_REGISTER_1
	mov	cx,[number]

@@waitvbl1:
	in	al,dx
	test	al,00001000b	;look for vbl
	jnz	@@waitvbl1

@@waitvbl2:
	in	al,dx
	test	al,00001000b	;look for vbl
	jz	@@waitvbl2

	loop	@@waitvbl1

	ret

ENDP

else

PROC	WaitVBL number:WORD
	USES	SI
	PUBLIC	WaitVBL

	mov	cx,[number]

ifdef VER_130
@@outerloop:
	mov	si, [WORD timecount]
endif

@@waitvbl1:
	mov	dx,STATUS_REGISTER_1
	in	al,dx
	test	al,00001000b	;look for vbl
	jnz	@@waitvbl1

ifdef VER_130
;
; set CRTC start
;
	mov	bx, [screenstart]
	mov	dx, CRTC_INDEX
	mov	al, CRTC_STARTHIGH
	out	dx, al
	inc	dx
	mov	al, bh
	out	dx, al
	dec	dx
	mov	al, CRTC_STARTLOW
	out	dx, al
	inc	dx
	mov	al, bl
	out	dx, al
endif

@@waitvbl2:
	mov	dx,STATUS_REGISTER_1
	in	al,dx
	test	al,00001000b	;look for vbl
	jz	@@waitvbl2

ifdef VER_130
@@waittime:
	mov	ax, [WORD timecount]
	sub	ax, si
	cmp	ax, 2
	jl	@@waittime
	
	loop	@@outerloop
else
	mov	bx, 100
@@bxloop:
	dec	bx
	jnz	@@bxloop

	loop	@@waitvbl1
endif

	ret

ENDP

endif


;=======================================================================

;====================
;
; EGAplane
; Sets read/write mode 0 and selects the given plane (0-3)
; for reading and writing
;
;====================

PROC	EGAplane plane:WORD
	PUBLIC	EGAplane

	cli
	mov	dx,GCindex
	mov	ax,GCmode
	out	dx,ax		;set read / write mode 0

	mov	dx,GCindex
	mov	al,4		;read map select
	mov	ah,[BYTE plane] ;read from this plane number
	out	dx,ax
	mov	dx,SCindex
	mov	al,SCmapmask
	mov	ah,1
	mov	cl,[BYTE plane]	;write to this plane only
	shl	ah,cl
	out	dx,ax
	sti
	ret

ENDP

;=======================================================================

;====================
;
; EGAlatch
; Sets write mode 1 with all planes selected
;
;====================

PROC	EGAlatch
	PUBLIC	EGAlatch

	cli
	mov	dx,GCindex
	mov	ax,1*256 + GCmode
	out	dx,ax		;set read 0 / write mode 1

	mov	dx,SCindex
	mov	ax,15*256 + SCmapmask	;write to all planes
	out	dx,ax
	sti
	ret
ENDP

;=======================================================================


	MASM
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;
; Name:	VideoID
;
; Function:	Detects the presence of various video subsystems
;
; int VideoID;
;
; Subsystem ID values:
; 	 0  = (none)
; 	 1  = MDA
; 	 2  = CGA
; 	 3  = EGA
; 	 4  = MCGA
; 	 5  = VGA
; 	80h = HGC
; 	81h = HGC+
; 	82h = Hercules InColor
;
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;
; Equates
;
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
VIDstruct	STRUC		; corresponds to C data structure

Video0Type	DB	?	; first subsystem type
Display0Type	DB	? 	; display attached to first subsystem

Video1Type	DB	?	; second subsystem type
Display1Type	DB	?	; display attached to second subsystem

VIDstruct	ENDS


Device0	EQU	word ptr Video0Type[di]
Device1	EQU	word ptr Video1Type[di]


MDA	EQU	1	; subsystem types
CGA	EQU	2
EGA	EQU	3
MCGA	EQU	4
VGA	EQU	5
HGC	EQU	80h
HGCPlus	EQU	81h
InColor	EQU	82h

MDADisplay	EQU	1	; display types
CGADisplay	EQU	2
EGAColorDisplay	EQU	3
PS2MonoDisplay	EQU	4
PS2ColorDisplay	EQU	5

TRUE	EQU	1
FALSE	EQU	0

;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออ
;
; Program
;
;อออออออออออออออออออออออออออออออออออออออออออออออออออออออออ

Results	VIDstruct <>	;results go here!

EGADisplays	DB	CGADisplay	; 0000b, 0001b	(EGA switch values)
	DB	EGAColorDisplay	; 0010b, 0011b
	DB	MDADisplay	; 0100b, 0101b
	DB	CGADisplay	; 0110b, 0111b
	DB	EGAColorDisplay	; 1000b, 1001b
	DB	MDADisplay	; 1010b, 1011b

DCCtable	DB	0,0	; translate table for INT 10h func 1Ah
	DB	MDA,MDADisplay
	DB	CGA,CGADisplay
	DB	0,0
	DB	EGA,EGAColorDisplay
	DB	EGA,MDADisplay
	DB	0,0
	DB	VGA,PS2MonoDisplay
	DB	VGA,PS2ColorDisplay
	DB	0,0
	DB	MCGA,EGAColorDisplay
	DB	MCGA,PS2MonoDisplay
	DB	MCGA,PS2ColorDisplay

TestSequence	DB	TRUE	; this list of flags and addresses
	DW	FindPS2	;  determines the order in which this
			;  program looks for the various
EGAflag	DB	?	;  subsystems
	DW	FindEGA

CGAflag	DB	?
	DW	FindCGA

Monoflag	DB	?
	DW	FindMono

NumberOfTests	EQU	($-TestSequence)/3


	PUBLIC	VideoID
VideoID	PROC	near

	push	bp	; preserve caller registers
	mov	bp,sp
	push	ds
	push	si
	push	di

	push	cs
	pop	ds
	ASSUME	DS:@Code

; initialize the data structure that will contain the results

	lea	di,Results	; DS:DI -> start of data structure

	mov	Device0,0	; zero these variables
	mov	Device1,0

; look for the various subsystems using the subroutines whose addresses are
; tabulated in TestSequence; each subroutine sets flags in TestSequence
; to indicate whether subsequent subroutines need to be called

	mov	byte ptr CGAflag,TRUE
	mov	byte ptr EGAflag,TRUE
	mov	byte ptr Monoflag,TRUE

	mov	cx,NumberOfTests
	mov	si,offset TestSequence

@@L01:	lodsb		; AL := flag
	test	al,al
	lodsw		; AX := subroutine address
	jz	@@L02	; skip subroutine if flag is false

	push	si
	push	cx
	call	ax	; call subroutine to detect subsystem
	pop	cx
	pop	si

@@L02:	loop	@@L01

; determine which subsystem is active

	call	FindActive

	mov	al,Results.Video0Type
	mov	ah,0	; was:  Results.Display0Type

	pop	di	; restore caller registers and return
	pop	si
	pop	ds
	mov	sp,bp
	pop	bp
	ret

VideoID	ENDP


;
; FindPS2
;
; This subroutine uses INT 10H function 1Ah to determine the video BIOS
; Display Combination Code (DCC) for each video subsystem present.
;

FindPS2	PROC	near

	mov	ax,1A00h
	int	10h	; call video BIOS for info

	cmp	al,1Ah
	jne	@@L13	; exit if function not supported (i.e.,
			;  no MCGA or VGA in system)

; convert BIOS DCCs into specific subsystems & displays

	mov	cx,bx
	xor	bh,bh	; BX := DCC for active subsystem

	or	ch,ch
	jz	@@L11	; jump if only one subsystem present

	mov	bl,ch	; BX := inactive DCC
	add	bx,bx
	mov	ax,[bx+offset DCCtable]

	mov	Device1,ax

	mov	bl,cl
	xor	bh,bh	; BX := active DCC

@@L11:	add	bx,bx
	mov	ax,[bx+offset DCCtable]

	mov	Device0,ax

; reset flags for subsystems that have been ruled out

	mov	byte ptr CGAflag,FALSE
	mov	byte ptr EGAflag,FALSE
	mov	byte ptr Monoflag,FALSE

	lea	bx,Video0Type[di]  ; if the BIOS reported an MDA ...
	cmp	byte ptr [bx],MDA
	je	@@L12

	lea	bx,Video1Type[di]
	cmp	byte ptr [bx],MDA
	jne	@@L13

@@L12:	mov	word ptr [bx],0    ; ... Hercules can't be ruled out
	mov	byte ptr Monoflag,TRUE

@@L13:	ret

FindPS2	ENDP


;
; FindEGA
;
; Look for an EGA.  This is done by making a call to an EGA BIOS function
;  which doesn't exist in the default (MDA, CGA) BIOS.

FindEGA	PROC	near	; Caller:	AH = flags
			; Returns:	AH = flags
			;		Video0Type and
			;		 Display0Type updated

	mov	bl,10h	; BL := 10h (return EGA info)
	mov	ah,12h	; AH := INT 10H function number
	int	10h	; call EGA BIOS for info
			; if EGA BIOS is present,
			;  BL <> 10H
			;  CL = switch setting
	cmp	bl,10h
	je	@@L22	; jump if EGA BIOS not present

	mov	al,cl
	shr	al,1	; AL := switches/2
	mov	bx,offset EGADisplays
	xlat		; determine display type from switches
	mov	ah,al	; AH := display type
	mov	al,EGA	; AL := subystem type
	call	FoundDevice

	cmp	ah,MDADisplay
	je	@@L21	; jump if EGA has a monochrome display

	mov	CGAflag,FALSE	; no CGA if EGA has color display
	jmp	short @@L22

@@L21:	mov	Monoflag,FALSE	; EGA has a mono display, so MDA and
			;  Hercules are ruled out
@@L22:	ret

FindEGA	ENDP

;
; FindCGA
;
; This is done by looking for the CGA's 6845 CRTC at I/O port 3D4H.
;
FindCGA	PROC	near	; Returns:	VIDstruct updated

	mov	dx,3D4h	; DX := CRTC address port
	call	Find6845
	jc	@@L31	; jump if not present

	mov	al,CGA
	mov	ah,CGADisplay
	call	FoundDevice

@@L31:	ret

FindCGA	ENDP

;
; FindMono
;
; This is done by looking for the MDA's 6845 CRTC at I/O port 3B4H.  If
; a 6845 is found, the subroutine distinguishes between an MDA
; and a Hercules adapter by monitoring bit 7 of the CRT Status byte.
; This bit changes on Hercules adapters but does not change on an MDA.
;
; The various Hercules adapters are identified by bits 4 through 6 of
; the CRT Status value:
;
; 000b = HGC
; 001b = HGC+
; 101b = InColor card
;

FindMono	PROC	near	; Returns:	VIDstruct updated

	mov	dx,3B4h	; DX := CRTC address port
	call	Find6845
	jc	@@L44	; jump if not present

	mov	dl,0BAh	; DX := 3BAh (status port)
	in	al,dx
	and	al,80h
	mov	ah,al	; AH := bit 7 (vertical sync on HGC)

	mov	cx,8000h	; do this 32768 times
@@L41:	in	al,dx
	and	al,80h	; isolate bit 7
	cmp	ah,al
	loope	@@L41	; wait for bit 7 to change
	jne	@@L42	; if bit 7 changed, it's a Hercules

	mov	al,MDA	; if bit 7 didn't change, it's an MDA
	mov	ah,MDADisplay
	call	FoundDevice
	jmp	short @@L44

@@L42:	in	al,dx
	mov	dl,al	; DL := value from status port
	and	dl,01110000b	; mask bits 4 thru 6

	mov	ah,MDADisplay	; assume it's a monochrome display

	mov	al,HGCPlus	; look for an HGC+
	cmp	dl,00010000b
	je	@@L43	; jump if it's an HGC+

	mov	al,HGC	; look for an InColor card or HGC
	cmp	dl,01010000b
	jne	@@L43	; jump if it's not an InColor card

	mov	al,InColor	; it's an InColor card
	mov	ah,EGAColorDisplay

@@L43:	call	FoundDevice

@@L44:	ret

FindMono	ENDP

;
; Find6845
;
; This routine detects the presence of the CRTC on a MDA, CGA or HGC.
; The technique is to write and read register 0Fh of the chip (cursor
; low).  If the same value is read as written, assume the chip is
; present at the specified port addr.
;

Find6845	PROC	near	; Caller:  DX = port addr
			; Returns: cf set if not present
	mov	al,0Fh
	out	dx,al	; select 6845 reg 0Fh (Cursor Low)
	inc	dx
	in	al,dx	; AL := current Cursor Low value
	mov	ah,al	; preserve in AH
	mov	al,66h	; AL := arbitrary value
	out	dx,al	; try to write to 6845

	mov	cx,100h
@@L51:	loop	@@L51	; wait for 6845 to respond

	in	al,dx
	xchg	ah,al	; AH := returned value
			; AL := original value
	out	dx,al	; restore original value

	cmp	ah,66h	; test whether 6845 responded
	je	@@L52	; jump if it did (cf is reset)

	stc		; set carry flag if no 6845 present

@@L52:	ret

Find6845	ENDP


;
; FindActive
;
; This subroutine stores the currently active device as Device0.  The
; current video mode determines which subsystem is active.
;

FindActive	PROC	near

	cmp	word ptr Device1,0
	je	@@L63	; exit if only one subsystem

	cmp	Video0Type[di],4	; exit if MCGA or VGA present
	jge	@@L63	;  (INT 10H function 1AH
	cmp	Video1Type[di],4	;  already did the work)
	jge	@@L63

	mov	ah,0Fh
	int	10h	; AL := current BIOS video mode

	and	al,7
	cmp	al,7	; jump if monochrome
	je	@@L61	;  (mode 7 or 0Fh)

	cmp	Display0Type[di],MDADisplay
	jne	@@L63	; exit if Display0 is color
	jmp	short @@L62

@@L61:	cmp	Display0Type[di],MDADisplay
	je	@@L63	; exit if Display0 is monochrome

@@L62:	mov	ax,Device0	; make Device0 currently active
	xchg	ax,Device1
	mov	Device0,ax

@@L63:	ret

FindActive	ENDP


;
; FoundDevice
;
; This routine updates the list of subsystems.
;

FoundDevice	PROC	near	; Caller:    AH = display #
			;	     AL = subsystem #
			; Destroys:  BX
	lea	bx,Video0Type[di]
	cmp	byte ptr [bx],0
	je	@@L71	; jump if 1st subsystem

	lea	bx,Video1Type[di]	; must be 2nd subsystem

@@L71:	mov	[bx],ax	; update list entry
	ret

FoundDevice	ENDP


;=======================================================================
;
;      RLE COMPRESSION ROUTINES ( from "The Catacomb" RLEASM.ASM )
;
;=======================================================================

	%NOLIST
	%TITLE	"RLE compression v0.00"
;==========================================================
; RLE compression in assemlby.
; Written by Lane Roath, Copyright (c) 1990 IFD & Softdisk
;
;----------------------------------------------------------
;
;09-Aug-90 0.00	Start coding, converting source C in Dr. Dobb's
;
;==========================================================

	IDEAL

	MODEL	small,C


;==========================================================

MinCnt	=	3-1	;min count for repeat
MaxCnt	=	127+MinCnt	;max count (128+ = non repeat string)

	DATASEG
	
padding		dd	?
		
handle		dw	?	;file i/o requirements are here!
flength1	dw	?
flength2	dw	?
buf1		dw	?
buf2		dw	?
foff1		dw	?
foff2		dw	?

; We store our memory allocation results here

RLESeg	dw	?	;RLE packed buf (src/dest)
SrcSeg	dw	?	;original source data

RLEIdx	dw	?	;indexes for read/write bufs
SRCIdx	dw	?

SrcLen	dw	2 dup (?)	;length of source & dest bufs
RLELen	dw	2 dup (?)

ByteCnt	dw	?	;# of sequential bytes
LastByte	db	?	;last byte found
DifCnt	dw	?	;# of different bytes

EndByte	dw	?

;==========================================================
;
	CODESEG
;
;==========================================================
;
;	Initialize our variables & buffers
;
;==========================================================

PROC	InitRLE		;internal

	mov	[ByteCnt],0
	mov	[DifCnt],1
	mov	[RLELen],0
	mov	[RLELen+2],0
	mov	SI,[SrcIdx]	;init Source Index (SrcIdx)
	mov	DI,[RLEIdx]	; & dest index (RLEIdx)

	ret
ENDP


;==========================================================
;
;	Output a compression string (repeated bytes)
;
;==========================================================


PROC	OutputRep

	push	SI
	push	ES	;save needed registers
	push	AX

	mov	ES,[RLESeg]	;get dest buffer seg
	mov	AX,[ByteCnt]
	sub	AL,2	;get byte count - 3 (already -1)
	stosb

	mov	AL,[LastByte]	; & output byte to repeat
	stosb

	mov	SI,[SrcIdx]
	inc	SI	;update source index (length + 1)
	add	SI,[ByteCnt]
	mov	[SrcIdx],SI	; & save for next output

	add	[RLELen],2	;update RLE length
	adc	[RLELen+2],0

	mov	[ByteCnt],0	;we output everything!

	pop	AX
	pop	ES	;restore registers

;	mov	BL,[ES:SI]
;	mov	[LastByte],BL	;this is 'last' byte!

	pop	SI

	ret

	ENDP

;==========================================================
;
;	Output a unique string with count byte preceeding
;
;==========================================================


PROC	OutputDif

	push	ES	;save important registers
	push	AX
	push	SI

	mov	ES,[RLESeg]	;get dest buffer seg
	mov	AX,[DifCnt]
	add	AL,7Fh	; & save byte count - 1 with hi bit set
	stosb

	mov	CX,[DifCnt]	;get # of bytes to copy

	mov	AX,CX	;# of bytes read (count is -1)
	inc	AX
	add	[RLELen],AX	;update RLE length
	adc	[RLELen+2],0

	mov	SI,[SrcIdx]	; & starting position in source
	push	DS
	mov	DS,[SrcSeg]	;set source seg
	REP	movsb
	pop	DS	; & copy the string

	mov	[DifCnt],0	;we output everything!

	mov	[SrcIdx],SI	;save for next output

	pop	SI
	pop	AX
	pop	ES	;restore registers

	ret

	ENDP

;==========================================================
;
;	EXPAND a RLE compressed file segment
;
;==========================================================


	PUBLIC	Expand
PROC	Expand

	call	InitRLE	;init our vars & buffers

	xchg	SI,DI	;swap SI and DI
	mov	DX,1
@@bank:
	mov	ES,[SrcSeg]	;point to source buffer
	xor	AH,AH
@@get:
	cmp	DI,0FFF0h	;don't bog us down!
	jb	@@ok

	mov	AX,DI
	shr	AX,1
	shr	AX,1	;offset / 16
	shr	AX,1
	shr	AX,1
	add	[SrcSeg],AX	; + seg reg = normalized ptr
;	and	DI,0Fh
	mov	DI,0

	mov	AX,SI
	shr	AX,1
	shr	AX,1	;offset / 16
	shr	AX,1
	shr	AX,1
	add	[RLESeg],AX	; + segment register = normalized ptr
	and	SI,0Fh
	jmp	SHORT @@bank
@@ok:
	sub	[SrcLen],DX	;subtract out # of chars
	sbb	[SrcLen+2],0
	jc	@@Done	;exit if we are done!
	xor	DX,DX
@@0:
	push	DS
	mov	DS,[RLESeg]	;point to RLE buffer
	lodsb		; & get code byte
	cmp	AL,80h
	jb	@@rpt	;repeat code?
	sub	AL,7Fh
	mov	CX,AX	; no- string length = code - $80 + 1
	mov	DX,AX

	REP	movsb	;copy string
	pop	DS
	jmp	SHORT @@get	; & do some more
@@rpt:
	add	AL,3	;# of bytes = code + 3
	mov	CX,AX
	mov	DX,AX
	lodsb		;get byte to repeat
	REP	stosb
	pop	DS	; & store that many bytes
	jmp	SHORT @@get
@@Done:
	ret

	ENDP

;==========================================================
;
;	COMPRESS data buffer using RLE
;
;==========================================================

	PUBLIC	Compress
PROC	Compress

	call	InitRLE	;init vars
@@bank:
	mov	ES,[SrcSeg]	;get first byte of data
	mov	AL,[ES:SI]

	mov	[LastByte],AL	; & set as last byte
@@get:
	cmp	SI,0FF00h	;don't bog us down!
	jb	@@ok

	jmp	@@Done	;send any patial strings!

	mov	AX,SI
	shr	AX,1
	shr	AX,1	;offset / 16
	shr	AX,1
	shr	AX,1
	add	[SrcSeg],AX	; + segment register = normalized
	and	SI,0Fh
	mov	[SrcIdx],0	;which is our new 'start'

	mov	AX,DI
	shr	AX,1
	shr	AX,1	;offset / 16
	shr	AX,1
	shr	AX,1
	add	[RLESeg],AX	; + segment register = normalized ptr
	and	DI,0Fh
	inc	[DifCnt]
	jmp	SHORT @@bank
@@ok:
	sub	[SrcLen],1	;subtract out # of chars
	sbb	[SrcLen+2],0
	jnc	@@0
	jmp	NEAR @@Done	;exit if we are done!
@@0:
	inc	SI	;get next byte
	mov	AL,[ES:SI]
	cmp	AL,[LastByte]
	jne	@@dif	;same as last byte?

	inc	[ByteCnt]	; yes- count it
	cmp	[ByteCnt],MinCnt
	jb	@@get

	cmp	[DifCnt],1	;ok, got a rep string...already have dif?
	jbe	@@same
	dec	[DifCnt]
	call	OutputDif	; yes- output that string first
@@same:
	mov	[DifCnt],0	;force even if not output!
	cmp	[ByteCnt],MaxCnt
	jb	@@get	;have we gotten too big?

	call	OutputRep	; yes, save string & continue

	cmp	AL,[ES:SI+1]	;another repeat?
	jne	@@gget
	cmp	AL,[ES:SI+2]
        jne	@@gget
	inc	SI	;need this for >127 byte strings!
@@gget:	jmp	NEAR @@get
;-------------------------------------------------------------
@@dif:
	mov	CX,[ByteCnt]	;any dups yet?
	jcxz	@@cnt

	cmp	CX,MinCnt	;repeats before now?
	jb	@@add

	call	OutputRep	; yes- save repeat bytes
	jmp	SHORT @@cnt
@@add:
	add	[DifCnt],CX	;add bad repeats to dif count
	mov	[ByteCnt],0	; & no more dupes!
@@cnt:
	inc	[DifCnt]	;count byte as different
	mov	[LastByte],AL

	cmp	[DifCnt],MaxCnt-MinCnt-1	;still in range?
	jb	@@goget

	call	OutputDif	; no- output string & continue

;	mov	AL,[ES:SI+1]
	cmp	AL,[ES:SI+1]
	jne	@@goget	;if repeat follows, specialize!
	cmp	AL,[ES:SI+2]
	jne	@@goget
	inc	SI	;why?
        inc	[DifCnt]
@@goget:
	jmp	NEAR @@get
;-------------------------------------------------------------
@@Done:
	mov	CX,[ByteCnt]	;any reps left?
	jcxz	@@1

	cmp	CX,MinCnt	; yes- enough to output?
	jb	@@2

	cmp	[DifCnt],1	; yes, any difs before these?
	jb	@@3

	call	OutputDif	; yes- output them
@@3:
	call	OutputRep	;output rep bytes
	jmp	SHORT @@4
@@2:
	add	[DifCnt],CX	;update dif count w/small rep
@@1:
	mov	CX,[DifCnt]	;anything to output?
	jcxz	@@4
	call	OutputDif	;output dif string
@@4:
	ret

	ENDP

;====================================================
;
;	C interface to compress file
;
;====================================================

	PUBLIC	RLECompress

PROC	RLECompress NEAR Source:DWORD,_Length:DWORD,Destination:DWORD

	mov	AX,[WORD Source]
	mov	[SrcIdx],AX
	mov	AX,[WORD Source+2]
	mov	[SrcSeg],AX	;set source buffer

	mov	AX,[WORD Destination]
	mov	[RLEIdx],AX
	mov	AX,[WORD Destination+2]
	mov	[RLESeg],AX	; & destination buffer

	mov	AX,[WORD _Length]
	mov	[SrcLen],AX	;save length
	mov	AX,[WORD _Length+2]
	mov	[SrcLen+2],AX
	
	; The Keen 1-3 code writes the length to the Destination buffer:
	push	es
	push	si
	mov	ax,[RLESeg]
	mov	es,ax
	mov	si,[RLEIdx]
	mov	ax,[WORD SrcLen]
	mov	[es:si],ax
	mov	ax,[WORD SrcLen+2]
	mov	[es:si+2],ax
	pop	si
	pop	es
	add	dx,4

	call	Compress	;do the compression

	mov	AX,[RLELen]	;return length of compressed file
	mov	DX,[RLELen+2]

	ret

	ENDP

;====================================================
;
;	C interface to expand file
;
;====================================================

	PUBLIC	RLEExpand

PROC	RLEExpand NEAR Source:DWORD,Destination:DWORD

	mov	AX,[WORD Source]
	mov	[RLEIdx],AX
	mov	AX,[WORD Source+2]
	mov	[RLESeg],AX	;set source buffer

	mov	AX,[WORD Destination]
	mov	[SrcIdx],AX
	mov	AX,[WORD Destination+2]
	mov	[SrcSeg],AX	; & destination buffer

	; The Keen 1-3 code reads the length from the source data:
	push	es
	push	si
	mov	ax,[RLESeg]
	mov	es,ax
	mov	si,[RLEIdx]
	mov	ax,[es:si]
	mov	[WORD SrcLen],ax
	mov	ax,[es:si+2]
	mov	[WORD SrcLen+2],ax
	pop	si
	pop	es
	add	[RLEIdx],4

	call	Expand	;do the expansion

	ret

	ENDP


END
