_draw_border:
	;----------------------------------------
	;INITIALISE POSITION FOR BORDER TL
	mov	r15, qword[FRAMEBUFFER]	;draw pixels here ofc
	mov	r14, ansi.grey	;and draw in grey for the border
	movzx	r11, word[maze.left]	;load left
	movzx	r12, word[maze.top]	;and then top
	sub	r11, 2	;subtract 2 from both
	sub	r12, 2	;to get border start
	call	_draw_pixel	;draw border start
	mov	cx, word[maze.width]	;and now iterate over maze width
	;----------------------------------------
	;CREATE ROW IN DIRECTION
	%macro	create_row	2
		inc	cx	;increase iterate value for border
		shl	cx, 1	;and double to encompass walls and corridors
	%%loop:
		cmp	cx, 0	;check if iterator is 0 (finished row)
		jz	%%end	;if yes then go to end
		%1	%2	;otherwise inc/dec r11/r12
		call	_draw_pixel	;and then draw another pixel
		dec	cx	;decrease i
		jmp	%%loop	;and loop over
	%%end:
	%endmacro
	;----------------------------------------
	;DRAW ALL SIDES OF THE BORDER
	create_row	inc, r11	;create l-r horizontal row
	mov	cx, word[maze.height]	;load height now
	create_row	inc, r12	;create t-b vertical row
	mov	cx, word[maze.width]	;load width
	create_row	dec, r11	;create r-l horizontal row
	mov	cx, word[maze.height]	;load height
	create_row	dec, r12	;create b-t vertical row
	ret	;done

_draw_pixel:
	push	r11	;push some clobbered registers
	push	r12	;theyre important for other functions
	push	rcx
	;----------------------------------------
	;CONVERT COORDS TO MEMORY OFFSET
	imul	r11, UNIT_LEN	;multiply x by unit length to get offset
	xor	rcx, rcx	;xor rcx (used for odd rows)
	shr	r12, 1	;divide height by 2
	jnc	.even_row	;if no carry, row number is even
	mov	rcx, HALF_UNIT	;otherwise its odd so add half a height unit
.even_row:
	imul	r12, qword[term_size.xb]	;multiply the halved number row width
	add	r12, rcx	;then add the half unit, if row # is odd
	add	r11, r12	;add together memory offsets
	;----------------------------------------
	;WRITE COLOUR TO PIXEL
	mov	bx, word[r14]	;load first 2 bytes of colour here
	mov	word[r15+r11+HEADER_LEN+7], bx	;then write then
	mov	bl, byte[r14+2]	;then load last byte
	mov	byte[r15+r11+HEADER_LEN+9], bl	;write it here
	pop	rcx
	pop	r12	;pop back clobbered registers
	pop	r11
	ret	;done!

_get_pixel:
	push	r11	;slightly modified version of get_pixel
	push	r12	;addr calculation is the same
	;----------------------------------------
	;CONVERT COORDS TO MEMORY OFFSET
	imul	r11, UNIT_LEN	;multiply x by unit length to get offset
	xor	rcx, rcx	;xor rcx (used for odd rows)
	shr	r12, 1	;divide height by 2
	jnc	.even_row	;if no carry, row number is even
	mov	rcx, HALF_UNIT	;otherwise its odd so add half a height unit
.even_row:
	imul	r12, qword[term_size.xb]	;multiply the halved number row width
	add	r12, rcx	;then add the half unit, if row # is odd
	add	r11, r12	;add together memory offsets
	;----------------------------------------
	;RETURN PIXEL ADDR AND FINISH
	lea	rax, [r15+r11+HEADER_LEN+7]	;load pixel position into rax
	pop	r12	;pop back clobbered registers
	pop	r11
	ret	;done!

_init_screen:
	;----------------------------------------
	;GET FRAMEBUFFER START AND END ADDR
	mov	rdi, qword[FRAMEBUFFER]	;move in framebuffer addr
	mov	ecx, dword[FRAMEBUFFER+8]	;move in framebuffer length
	add	rcx, rdi	;now add together to get framebuffer end addr
	;----------------------------------------
	;WRITE FRAMEBUFFER HEADER AND LOAD ESCAPES
	mov	r8d, dword[esc_home]	;load the home escape into r8
	mov	dword[rdi], r8d	;write home escape to header area
	add	rdi, HEADER_LEN	;go to body section now
	mov	r8, qword[unit_template]	;load 8 bytes of unit template
	mov	r9, qword[unit_template+8]
	mov	r10, qword[unit_template+16]
	mov	r11w, word[unit_template+24]	;then remaining 2 bytes here
.loop_write:
	;----------------------------------------
	;LOOP WRITE UNITS INTO FRAMEBUFFER
	mov	qword[rdi], r8	;write these bytes to the framebuffer in order
	mov	qword[rdi+8], r9
	mov	qword[rdi+16], r10
	mov	word[rdi+24], r11w	;last 2 bytes, 24-26
	add	rdi, UNIT_LEN	;then increase rdi by one unit
	cmp	rdi, rcx	;check if at end addr
	jnz	.loop_write	;if no then write next unit
	ret	;otherwise, return

