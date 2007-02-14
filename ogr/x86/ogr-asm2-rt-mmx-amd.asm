;
; Assembly core for OGR, MMX version for AMD CPU's.
; See "ogr-asm2-rt-mmx.asm" for Changelog/History of original file.
;
; Origial version created by Roman Trunov (proxyma@tula.net)
; AMD-specific optimizations by Christian Ehrlicher <Ch.Ehrlicher@gmx.de>
;
; This core differs from original MMX code mostly by order of some
; instructions. Some instructions are replaced to their equivalents.
;
; AMD CPUs works better if similar MMX instructions are scheduled close
; to each other, but Intel chip have a penalty in this case.
;
;
; 2007-02-03: (RT) More effecient registers assignment and math optimization
;                  in inner loop. Less commands, 2% faster.
;             (CE) More AMD-specific instruction reorders.
;

cpu	586

%ifdef __OMF__ ; Watcom and Borland compilers/linkers
	[SECTION _DATA USE32 ALIGN=16 CLASS=DATA]
%else
	[SECTION .data]
%endif

;
; Define OGR_DEBUG to 0 or 1 to get single core for debugging and
; nice listing. 1 - with_time_constraints, 0 - without them.
;
;%define OGR_DEBUG 0
;%define OGR_DEBUG 1

%define STUB_MAX 10

;
; Better keep local copy of this table due to differences in naming
; of external symbols (even cdecl) in different compilers.
;
_OGR:	dd   0,   1,   3,   6,  11,  17,  25,  34,  44,  55	; /*  1 */
	dd  72,  85, 106, 127, 151, 177, 199, 216, 246, 283	; /* 11 */
	dd 333, 356, 372, 425, 480, 492, 553, 585, 623		; /* 21 */
;
; Address of found_one can be kept on stack (as extra parameter to ogr_cycle)
; but both cases are Ok and this one is simpler.
;
_found_one_cdecl_ptr:
	dd   0

%ifdef __OMF__ ; Borland and Watcom compilers/linkers
	[SECTION _TEXT FLAT USE32 align=16 CLASS=CODE]
%else
	[SECTION .text]
%endif

global	_ogr_watcom_rt1_mmx64_amd_asm, ogr_watcom_rt1_mmx64_amd_asm

	%define	sizeof_level 50h		; sizeof(level)
	%define	lev_list0  00H			; fields in level
	%define lev_list1  08H
	%define	lev_list2  10H
	%define	lev_dist0  18H
	%define	lev_dist1  20H
	%define	lev_dist2  28H
	%define	lev_comp0  30H
	%define	lev_comp1  38H
	%define	lev_comp2  40H
	%define lev_mark   48H
	%define lev_limit  4cH

	%define ostate_node_offset  0980H
;
; Registers assigned:
;
; esi = comp0 (32 bit)
; mm0 = comp1
; mm1 = comp2
; mm2 = list0 (32 bit) in lower part, newbit in high part
; mm3 = list1
; mm4 = list2
;
; mm5-mm7 are used for calculations
;
%ifdef OGR_DEBUG
	%define with_time_constraints OGR_DEBUG
%else
	%macro ogr_cycle_macro 0
%endif
ogr_cycle_:
	push	ecx
	push	esi
	push	edi
	push	ebp
	sub	esp,38H
	add	ecx,3
	mov	dword [esp+1cH],ecx	; ogr_choose_dat+3
	mov	dword [esp+0cH],edx	; pnodes
	mov	edx,[edx]
	mov	dword [esp+2cH],edx	; *pnodes
	mov	dword [esp+18H],eax	; oState
	mov	edx,dword [eax+1cH]
	inc	edx
	mov	dword [esp+24H],edx	; int depth = oState->depth + 1;
	imul	edx,sizeof_level
	lea	ebp,[eax+edx+20H]	; lev = &oState->Levels[depth]
%if with_time_constraints
	mov	edx,dword [eax+ostate_node_offset]
	add	dword [esp+2cH],edx	; *pnodes += oState->node_offset;
	mov	dword [esp+14H],edx	; nodes = oState->node_offset;
	xor	edx,edx
	mov	dword [esp+30H],edx	; int checkpoint = 0;
	mov	dword [eax+ostate_node_offset],edx	; oState->node_offset = 0;
	; int checkpoint_depth = (1+STUB_MAX) - oState->startdepth;
	mov	edx,(1+STUB_MAX)
	sub	edx,dword [eax+18H]
	mov	dword [esp+34H],edx
%else
 	and	dword [esp+14H],0	; int nodes = 0;
%endif
	mov	ecx,dword [eax+10H]
	imul	ecx,sizeof_level
	lea	ebx,[eax+ecx+20H]
	mov	dword [esp+4],ebx	; levHalfDepth = &oState->Levels[oState->half_depth]
	mov	edx,dword [eax]
	mov	dword [esp+10H],edx	; maxlength  = oState->max;
	mov	edx,dword [eax+8]
	mov	ecx,dword [esp+24H]
	sub	edx,ecx
	mov	dword [esp+20H],edx	; remdepth   = oState->maxdepthm1 - depth;
	mov	edx,dword [eax+10H]
	mov	ebx,dword [eax+18H]
	sub	edx,ebx
	mov	dword [esp],edx		; halfdepth  = oState->half_depth - oState->startdepth;
	mov	edx,dword [eax+14H]
	sub	edx,ebx
	mov	dword [esp+8],edx	; halfdepth2 = oState->half_depth2 - oState->startdepth;
	sub	ecx,ebx
	mov	dword [esp+24H],ecx	; depth -= oState->startdepth;

; stack allocation ([SP+##h]):
;	00H	halfdepth
;	04H	levHalfDepth
;	08H	halfdepth2
;	0CH	pnodes
;	10H	maxlength
;	14H	nodes
;	18H	oState
;	1CH	offsetof(level->comp) == [ebp+40] => KILLED => Now ogr_choose_dat+3
;	20H	remdepth
;	24H	depth
;	28H	limit => KILLED.
;	2cH	mark => KILLED. Now contains *pnodes for fast compare.
;	30H	checkpoint
;	34H	checkpoint_depth

	mov	ebx,dword [ebp+lev_mark]	;   int mark = lev->mark;

	;    #define SETUP_TOP_STATE(lev)            \
	;      U comp1, comp2;                       \
	;      U list0, list1, list2;                \
	;      U dist1, dist2;                       \
	;      u32 comp0 = (u32) lev->comp[0];       \
	;      u32 dist0 = (u32) lev->dist[0];       \
	;      comp1 = lev->comp[1];                 \
	;      comp2 = lev->comp[2];                 \
	;      list0 = lev->list[0] | ((U)1 << 32);  \
	;      list1 = lev->list[1];                 \
	;      list2 = lev->list[2];                 \
	;      dist1 = lev->dist[1];                 \
	;      dist2 = lev->dist[2];

	xor	eax,eax
	inc     eax
	movd	mm7,eax			; special constant H=0000 L=0001

	movd	mm2,[ebp+lev_list0]		; (u32) lev->list[0]...
	movq	mm3,[ebp+lev_list1]		;	lev->list[1]
	movq	mm4,[ebp+lev_list2]		;	lev->list[2]
	mov	edi,dword [ebp+lev_dist0]	; (u32) dist0
	mov	esi,dword [ebp+lev_comp0]	; (u32) lev->comp[0]
	movq	mm0,[ebp+lev_comp1]		;	lev->comp[1]
	movq	mm1,[ebp+lev_comp2]		;	lev->comp[2]
	punpckldq mm2,mm7			;	  ... | 1 << 32

	jmp	.outerloop

;
; !!! Don't spend too much time optimizing code above this point.
; !!! It's executed only once.
;
%if ($-$$) <> 95h
;	%error	"Assembly of jumps and constant must be optimized, add -O5 to NASM options"
%endif

	align	16
.checklimit:
	; we enter here with:
	; 	eax = depth
	;	edx = limit
	; we must return back to store_limit with:
	;	edx = limit
	; Don't forget to store limit when leaving globally!
	;      if (depth <= halfdepth) {
	cmp	eax,dword [esp]
	jg	.L$56
%if with_time_constraints
%else
	;        if (nodes >= *pnodes) {
	mov	eax,dword [esp+14H]	; nodes
	cmp	eax,dword [esp+2cH]	; *pnodes
	jge	.L$54
%endif
	;        limit = maxlength - OGR[remdepth];
	mov	eax,dword [esp+20H]	; remdepth
	mov	edx,dword [esp+10H]	; maxlength
	mov	edi,dword [_OGR+eax*4]
	sub	edx,edi			; limit (new)
	;        if (limit > oState->half_length)
	mov	edi,dword [esp+18H]	; oState
	mov	eax,dword [edi+0cH]	; oState->half_length
	cmp	edx,eax
	jle	.store_limit
	;          limit = oState->half_length;
	mov	edx,eax
	jmp	.store_limit

	align	16
.L$56:
	;      else if (limit >= maxlength - levHalfDepth->mark) {
	mov	eax,dword [esp+10H]	; maxlength
	mov	edi,dword [esp+4]	; levHalfDepth
	sub	eax,dword [edi+lev_mark]; levHalfDepth->mark
	cmp	eax,edx
	jg	.store_limit
	;        limit = maxlength - levHalfDepth->mark - 1;
	lea	edx,[eax-1]
	jmp	.store_limit

%if with_time_constraints
%else
.L$54:
	;          retval = CORE_S_CONTINUE;
	;          break;
	xor     eax,eax
	inc     eax
	jmp	.L$53_exit
%endif

	align	16
.outerloop:
					; edi must be loaded with dist0
	;    limit = maxlength - choose(dist0 >> ttmDISTBITS, remdepth);
	shr	edi,14H			; dist0
	imul	edi,0cH
	mov	edx,dword [esp+20H]	; remdepth
	add	edi,dword [esp+1cH]	; ogr_choose_dat+3
	movzx	eax,byte  [edi+edx]	; mov al,byte [_ogr_choose_dat+edi+edx+3]
	mov	edx,dword [esp+10H]	; maxlength
	sub	edx,eax
	;    if (depth <= halfdepth2) {
	mov	eax,dword [esp+24H]	; depth
	cmp	eax,dword [esp+8]	; halfdepth2
	jle	.checklimit
.store_limit:
	; limit (save on stack) => KILLED
	;    lev->limit = limit;
	; two commands below must use DWORD operand offset to align next label.
	; funny but it improves only MMX core on my PII-Celeron...
	mov	dword [dword ebp+lev_limit],edx
	;    nodes++;
	inc	dword [dword esp+14H]

	align 16

.stay:   ; Most important internal loop
	;
	; entry: ebx = mark   (keep and update!)
	;	 esi = comp0  (reloaded immediately after shift)
	;	 ebp = level
	;	 ecx =
	;	 edi will be dist0  (reloaded later, don't care)
	; usable: eax, edx, ecx, edi
	; usable with care: esi
	;
	;    if (comp0 < 0xfffffffe) {
	cmp	esi,0fffffffeH
	jnb	.L$57_
	;      int s = LOOKUP_FIRSTBLANK( comp0 );
	not	esi
	mov	ecx,20H
	bsr	edx,esi
	sub	ecx,edx			; s
	;      if ((mark += s) > limit) goto up;   /* no spaces left */
	add	ebx,ecx
	cmp	ebx,dword [ebp+lev_limit]	; limit (==lev->limit)
	jg	.up
	;      COMP_LEFT_LIST_RIGHT(lev, s);

	;    #define COMP_LEFT_LIST_RIGHT(lev, s) {  \
	;      U temp1, temp2;                       \
	;      register int ss = 64 - (s);           \
	;      temp2 = list0 << ss;                  \
	;      list0 = list0 >> (s);                 \
	;      temp1 = list1 << ss;                  \
	;      list1 = (list1 >> (s)) | temp2;       \
	;      temp2 = comp1 >> ss;                  \
	;      list2 = (list2 >> (s)) | temp1;       \
	;      temp1 = comp2 >> ss;                  \
	;      comp0 = (u32) ((comp0 << (s)) | temp2);       \
	;      comp1 = (comp1 << (s)) | temp1;       \
	;      comp2 = (comp2 << (s));               \

        ; mm0 = comp1
        ; mm1 = comp2
        ; mm2 = list0 (32 bit) in lower part, newbit in high part
        ; mm3 = list1
        ; mm4 = list2
	; 1. mm4 = (mm4 >> (mm6)) | ( mm3 << mm7 )
	; 2. mm3 = (mm3 >> (mm6)) | ( mm2 << mm7 )
	; 3. mm2 =  mm2 >> (mm6);
        ; 4. esi = comp0 = (u32) ((edx << (ecx)) | mm0 >> eax)
	; 5. mm0   = (mm0 << (mm6)) |        mm1 >> mm7;
	; 6. mm1   = (mm1 << (mm6))
	;    }

					; ecx=s, edx=bsr, esi = not comp0
	not	esi			; recover comp0
	add	edx,32			; ss = (64-s) = 64-(32-bsr) = 32+bsr
	movd	mm6,ecx			; mm6 = s
        movd	mm7,edx			; mm7 = ss


;       1               2               3               4               5               6
	movq	mm5,mm3
	psrlq	mm4,mm6
	psllq	mm5,mm7
			psrlq   mm3,mm6
	por	mm4,mm5
			movq    mm5,mm2
					psrlq   mm2,mm6
			psllq   mm5,mm7
			por     mm3,mm5
							movq	mm5,mm0
						    	punpckhdq mm5,mm5
									psllq	mm0,mm6
						    	movd	eax,mm5
						    	shld	esi,eax,cl
									movq	mm5,mm1
											psllq	mm1,mm6
									psrlq	mm5,mm7
									por	mm0,mm5

.L$58:
					; comp0 must be in esi
	;    lev->mark = mark;
	;    if (remdepth == 0) {                  /* New ruler ? (last mark placed) */
	cmp	dword [esp+20H],0		; remdepth
	mov	dword [ebp+lev_mark],ebx	; lev->mark
	je	.L$61
	;    PUSH_LEVEL_UPDATE_STATE(lev);         /* Go deeper */

	;    #define PUSH_LEVEL_UPDATE_STATE(lev)    \
	;      lev->list[0] = list0; dist0 |= list0; \
	;      lev->list[1] = list1; dist1 |= list1; \
	;      lev->list[2] = list2; dist2 |= list2; \
	;      lev->comp[0] = comp0; comp0 |= dist0; \
	;      lev->comp[1] = comp1; comp1 |= dist1; \
	;      lev->comp[2] = comp2; comp2 |= dist2; \
	;      list0 |= ((U)1 << 32);
	;
	; Since dist is not cached, it will be updated in memory similar
	; to "low-register" code:
	;
	; lev2->dist[n] = lev->dist[n] | lev->list[n];
	;
	; Note! new comp0, dist0 must be loaded to esi, edi

	movd	edi,mm2				; list0

		movq	mm7,[ebp+lev_dist1]		; lev->dist[1]
		movq	mm6,[ebp+lev_dist2]		; lev->dist[2]

	movd	[ebp+lev_list0],mm2		; lev->list[0] = list0
	movq	[ebp+lev_list1],mm3		; lev->list[1] = list1
	movq	[ebp+lev_list2],mm4		; lev->list[2] = list2

		por	mm7,mm3				; dist1 |= list1
	mov	[ebp+lev_comp0],esi		; lev->comp[0] = comp0
		por	mm6,mm4				; dist2 |= list2
	movq	[ebp+lev_comp1],mm0		; lev->comp[1] = comp1
	movq	[ebp+lev_comp2],mm1		; lev->comp[2] = comp2

		or	edi,[ebp+lev_dist0]		; dist0 |= list0
		mov	[ebp+sizeof_level+lev_dist0],edi ; lev2->dist0 = dist0
		or	esi,edi				; comp0 |= dist0

		movq	[ebp+sizeof_level+lev_dist1],mm7 ; lev2->dist1 = dist1
	xor	eax,eax
		por	mm0,mm7				; comp1 |= dist1
	inc     eax
		movq	[ebp+sizeof_level+lev_dist2],mm6 ; lev2->dist2 = dist2
	movd	mm7,eax

		por	mm1,mm6				; comp2 |= dist2

	punpckldq mm2,mm7			; list0 |= ((U)1 << 32);

	;    remdepth--;
	dec	dword [esp+20H]
	;    lev++;
	add	ebp,sizeof_level
	;    depth++;
	inc	dword [esp+24H]
	;    continue;

; When core processed at least given number of nodes (or a little more)
; it must return to main client for rescheduling. It's required for
; timeslicing in non-preemptive OS'es.
; The trick is that there is no difference where to check count of nodes
; we've processed, in the beginning or in the end of loop. +/- 1 iteration
; of the core means nothing for client's scheduler.
; Checking node count here help us do not break perfectly aligned
; command sequence from "outerloop" to "stay".

%if with_time_constraints
	;      if (depth <= checkpoint_depth)
	;        checkpoint = nodes;
	mov	edx,dword [esp+24H]	; depth cached above
	mov	eax,dword [esp+14H]	; nodes
	cmp	edx,dword [esp+34H]	; checkpoint_depth
	jg	.L$01
	mov	dword [esp+30H],eax
; Unaligned L$01 gives huge slowdown. Alas, NASM cannot correctly
; expand current address in macro. Please check listing!
	align 16
.L$01:
	;      if (nodes >= *pnodes) {
	cmp	eax,dword [esp+2cH]	; *pnodes
	jl	.outerloop
	;        oState->node_offset = nodes - checkpoint;
	sub	eax,dword [esp+30H]	; nodes - checkpoint
	mov	edx,dword [esp+18H]	; oState
	mov	dword [edx+ostate_node_offset],eax
	;        nodes = checkpoint;
	mov	eax,dword [esp+30H]
	mov	dword [esp+14H],eax
	;	 retval = CORE_S_CONTINUE;
	xor	eax,eax
	inc     eax
	jmp	.L$53_exit
%else
	jmp	.outerloop
%endif

	align	16

	;    else {  /* s >= 32 */
	;      if ((mark += 32) > limit) goto up;
.L$57_:
	add	ebx,20H
	cmp	ebx,dword [ebp+lev_limit]	; limit (==lev->limit)
	jg	.up

	cmp	esi,0ffffffffH

	; small optimize. in both cases (esi == -1 and not) we perform
	; COMP_LEFT_LIST_RIGHT_32, then just jump to different labels.

	;    #define COMP_LEFT_LIST_RIGHT_32(lev)      \
	;      list2 = (list2 >> 32) | (list1 << 32);  \
	;      list1 = (list1 >> 32) | (list0 << 32);  \
	;      list0 >>= 32;                           \
	;      comp0 = (u32) (comp1 >> 32);            \
	;      comp1 = (comp1 << 32) | (comp2 >> 32);  \
	;      comp2 <<= 32;

	; Column 1
	;  mm2  mm3  mm4     mm2  mm3  mm4
        ;           6789 =>           6767
	;      2345 6767 =>      2345 4567
	;      2345 4567 =>      2323 4567
	; NN01 2323 4567 => NN01 0123 4567
	; NN01 0123 4567 => ZZNN 0123 4567
	
	; Column 2
	; comp1 [0123] => mm6 (copy)
	; [0123] => [0101]
	; comp0 => reloaded to esi

	; Column 3
	;  mm0  mm1  mm7
	; 0123 4567 ----        start
	; 2300 4567 ----
	; 2300 4567 4567
	; 2300 4567 0045
	; 2345 4567 ----
	; 2345 67ZZ ----

	punpckhdq mm4,mm4
	punpckldq mm4,mm3
			movq	  mm6,mm0
	punpckhdq mm3,mm3
			punpckhdq mm6,mm6
	punpckldq mm3,mm2		
					psllq	  mm0,32
	punpckhdq mm2,mm7		
			movd	  esi,mm6
					movq	  mm7,mm1
					psrlq	  mm7,32
					psllq	  mm1,32
					por	  mm0,mm7

	; Good that MMX do not set ALU flags

	jne	.L$58	; esi != -1
	jmp	.stay	; esi == -1

	align	16
.up:
	;    lev--;
	sub	ebp,sizeof_level

	;    #define POP_LEVEL(lev)    \
	;      list0 = lev->list[0];   \
	;      list1 = lev->list[1];   \
	;      list2 = lev->list[2];   \
	;      dist0 &= ~list0;        \
	;      dist1 &= ~list1;        \
	;      dist2 &= ~list2;        \
	;      comp0 = (u32) lev->comp[0];   \
	;      comp1 = lev->comp[1];   \
	;      comp2 = lev->comp[2];

	movd	mm2,[ebp+lev_list0]		; (u32) lev->list[0], newbit = 0
	movq	mm3,[ebp+lev_list1]		;	lev->list[1]
	movq	mm4,[ebp+lev_list2]		;	lev->list[2]
	mov	esi,dword [ebp+lev_comp0]	; (u32) lev->comp[0]
	movq	mm0,[ebp+lev_comp1]		;	lev->comp[1]
	movq	mm1,[ebp+lev_comp2]		;	lev->comp[2]
	; dist not loaded because it's not cached

	;    limit = lev->limit; KILLED
	;    mark = lev->mark;
	mov	ebx,dword [ebp+lev_mark]
	;    remdepth++;
	inc	dword [esp+20H]
	;    depth--;
	;    if (depth <= 0) {
	dec	dword [esp+24H]
	jg	.stay
	xor	eax,eax
.L$53_exit:
	;
	; esi must be loaded with comp0!
	;
	;    #define SAVE_FINAL_STATE(lev)   \
	;      lev->list[0] = list0;         \
	;      lev->list[1] = list1;         \
	;      lev->list[2] = list2;         \
	;      lev->dist[0] = dist0;         \
	;      lev->dist[1] = dist1;         \
	;      lev->dist[2] = dist2;         \
	;      lev->comp[0] = comp0;         \
	;      lev->comp[1] = comp1;         \
	;      lev->comp[2] = comp2;

	movd	[ebp+lev_list0],mm2		; lev->list[0]
	movq	[ebp+lev_list1],mm3
	movq	[ebp+lev_list2],mm4
	mov	[ebp+lev_comp0],esi		; lev->comp[0] = comp0
	movq	[ebp+lev_comp1],mm0		; lev->comp[1]
	movq	[ebp+lev_comp2],mm1

	mov	dword [ebp+lev_mark],ebx	; mark
	mov	edx,dword [esp+24H]
	dec	edx
	mov	ecx,dword [esp+18H]
	add	edx,dword [ecx+18H]
	mov	dword [ecx+1cH],edx
	mov	edx,dword [esp+14H]
	mov	ecx,dword [esp+0cH]
	mov	dword [ecx],edx
	add	esp,38H
	pop	ebp
	pop	edi
	pop	esi
	pop	ecx
	emms
	ret

.L$61:
	mov	eax,dword [esp+18H]
	push	ebx			; preserve regs clobbered by cdecl
	push	ecx
	push	edx
	push	eax			; parameter
	call	[_found_one_cdecl_ptr]
	add	esp, 4
	pop	edx
	pop	ecx
	pop	ebx			; restore clobbered regs
	cmp	eax,1
	jne	.L$53_exit
	jmp	.stay
%ifndef OGR_DEBUG
	%endmacro
%endif

%ifndef OGR_DEBUG
	%define ogr_cycle_		ogr_cycle_with_tc
	%define with_time_constraints	1
	ogr_cycle_macro

	align	16
	%define ogr_cycle_		ogr_cycle_no_tc
	%define with_time_constraints	0
	ogr_cycle_macro
%endif

_ogr_watcom_rt1_mmx64_amd_asm:
ogr_watcom_rt1_mmx64_amd_asm:
	push	ebx
	mov	eax, [esp+24]		; found_one cdecl procedure
	mov	[_found_one_cdecl_ptr], eax
	mov	eax, [esp+8]		; state
	mov	edx, [esp+12]		; pnodes
;	mov	ebx, [esp+16]		; with_time_constraints (ignored inside cycle)
	mov	ecx, [esp+20]		; address of ogr_choose_dat table
%ifdef OGR_DEBUG
 	call	ogr_cycle_
%else
	mov	ebx, ogr_cycle_no_tc
	cmp	dword [esp+16], 0
	je	.f
	mov	ebx, ogr_cycle_with_tc
.f:	call	ebx
%endif
	pop	ebx
	ret
