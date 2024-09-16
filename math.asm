_alloc:
	cmp	eax, dword[alloc_data.available]	;check if more data needs allocated
	jbe	.no_alloc	;if no, then use empty allocated data
	;----------------------------------------
	;CALCULATE MINIMUM ALLOCATION SIZE
	push	rax	;save requested data size
	xor	rdx, rdx	;reset this, it screws divs
	mov	rbx, 4096	;divide rax by this page size
	idiv	rbx	;the actual divide on rax is here
	inc	rax	;increase so it doesnt allocate 0 bytes
	imul	rax, 4096	;multiply result by 4096 to get amount to allocate
	mov	dword[alloc_data.available], eax	;then save this amount here
	;----------------------------------------
	;ALLOCATE REQUESTED MEMORY
	mov	rsi, rax	;save page-multiple allocate size here
	mov	rax, 9	;sys_mmap
	xor	rdi, rdi	;let kernel choose start addr
	mov	rdx, 3	;PROT_READ or-ed with PROT_WRITE
	mov	r10, 0b00100010	;anonymous and private mapping
	mov	r8, -1	;ignored with anonymous
	xor	r9, r9	;this one too
	syscall
	;----------------------------------------
	;FIX ALLOC DATA STRUCTURE
	mov	ecx, dword[alloc_data.pointer]	;get pointer for new alloc here
	mov	qword[alloc_data.addr+rcx], rax	;save start addr to new slot
	add	dword[alloc_data.pointer], 12	;then increase the pointer
	lea	rbx, [rcx+8]	;save data length offset here
	mov	rcx, rax	;save start addr to rcx for later
	pop	rax	;get back requested data
	mov	dword[alloc_data.addr+rbx], eax	;move the length allocated here
	sub	dword[alloc_data.available], eax	;then subtract that from page-size allocated
	add	rax, rcx	;add the start addr to the requested
	mov	qword[alloc_data.current], rax	;then that is latest empty allocated data
	mov	rax, rcx	;move the start addr into rax for the return
	ret	;finished!
.no_alloc:
	;----------------------------------------
	;GIVE ADDR FROM PRE_ALLOCATED SPACE
	mov	ecx, dword[alloc_data.pointer]	;move pointer into rcx
	mov	dword[alloc_data.addr+rcx+8], eax	;move length into current iten
	sub	dword[alloc_data.available], eax	;and correct available
	mov	rax, qword[alloc_data.current]	;move current addr into rax
	mov	qword[alloc_data.addr+rcx], rax	;and save to addr items
	add	dword[alloc_data.pointer], 12	;then increase pointer
	ret	;and return

_random_walk:
	;----------------------------------------
	;INITIALISE USEFUL REGISTERS
	mov	r15, qword[FRAMEBUFFER]	;framebuffer always in r15
	mov	r14, ansi.white	;and draw corridors in white colour
	movzx	r9, word[maze.width]	;maze width in here
	movzx	r10, word[maze.height]	;and height in here
	%macro	get_point	0
		;----------------------------------------
		;GET RANDOM COORD
		call	_xoshiro256pp	;get random 64bit val
		xor	rdx, rdx	;clear rdx for a div
		idiv	r9	;then divide random by maze width (repeat clamp)
		mov	r11, rdx	;store remainder (modulo) in x pos
		call	_xoshiro256pp	;get another random number
		xor	rdx, rdx	;reset rdx again
		idiv	r10	;divide by maze height
		mov	r12, rdx	;and store modulo in y pos
	%endmacro
	;----------------------------------------
	;CREATE AND DRAW FIRST MAZE POINT
	get_point	;get a random point
	mov	rdi, r12	;then move the y position into rdi
	imul	rdi, r9	;multiply by maze width
	add	rdi, r11	;and add r11 (rdi is position in mazebuffer)
	add	rdi, qword[MAZEBUFFER]	;add on mazebuffer addr
	mov	byte[rdi], 0b10000000	;then move this byte (maze byte) into addr
	shl	r11, 1	;double r11
	shl	r12, 1	;and r12
	movzx	rax, word[maze.left]	;then move maze left into rax
	add	r11, rax	;add it to x position
	movzx	rax, word[maze.top]	;then load maze top also
	add	r12, rax	;and add that to y pos
	call	_draw_pixel	;draw the point generated
.new_line:
	;----------------------------------------
	;GET NEW POSITION TO DRAW MAZE FROM
	get_point	;get a new point
	mov	rsi, r12	;and as above save y pos to addr reg
	imul	rsi, r9	;multiply by maze width
	add	rsi, r11	;and add r11
	add	rsi, qword[MAZEBUFFER]	;then add mazebuffer addr to get point offset
	test	byte[rsi], 0b10000000	;check if point is already filled
	jnz	.new_line	;if it is then get another point
	push	r11	;otherwise push coords for later
	push	r12
	push	rsi	;and also push mazebuffer offset
	inc	r11	;increase coords so comparison against r10 and r9
	inc	r12	;can be made to prevent moving off the maze later
.seek_loop:
	cmp	byte[rsi], 0b10000000	;check if current position is in maze
	jz	.found_maze	;if yes then join line to maze
	;----------------------------------------
	;GET RANDOM DIRECTION AND DO RANDOM WALK
	call	_xoshiro256pp	;otherwise get a random value
	and	al, 0b00000011	;clear all bits but the last two
	cmp	al, 0b00000000	;check if random byte is 0
	jz	.seek_up	;if yes then seek upwards
	cmp	al, 0b00000001	;do this for all 4 directions
	jz	.seek_down
	cmp	al, 0b00000010
	jz	.seek_left
	jmp	.seek_right	;else (al=0b00000011), seek right

.seek_up:
	;----------------------------------------
	;LOG MOVEMENT DIRECTION
	%macro	seek_dir	6
		cmp	%1, %2	;check y/x against maze bounds (1 or dimensions)
		jz	.seek_loop	;if moving out of the maze, try again
		mov	byte[rsi], %3	;log direction in buffer for trace
		%4	rsi, %5	;modify rsi to match direction
		%6	%1	;dec/inc r12/r11 to update coords
		jmp	.seek_loop	;and loop over for another seek
	%endmacro
	seek_dir	r12, 1, 0b00000000, sub, r9, dec	;seek up
.seek_down:	seek_dir	r12, r10, 0b00000001, add, r9, inc	;seek down
.seek_left:	seek_dir	r11, 1, 0b00000010, sub, 1, dec	;seek left
.seek_right:	seek_dir	r11, r9, 0b00000011, add, 1, inc	;seek right
.found_maze:
	;----------------------------------------
	;GET FIRST POINT POSITION FOR TRACE
	pop	rsi	;get back initial seek position
	pop	r12	;and also the index in mazebuffer
	pop	r11
	shl	r11, 1	;double both x coord
	shl	r12, 1	;and y coord
	movzx	rax, word[maze.left]	;then load maze left
	add	r11, rax	;add to x pos
	movzx	rax, word[maze.top]	;load maze top
	add	r12, rax	;and add to y pos to get absolute point position
.loop_trace:
	;----------------------------------------
	;CHECK TRACE DIRECTIONS
	cmp	byte[rsi], 0b00000000	;check direction byte as this
	jz	.trace_up	;if yes then trace line upwards
	cmp	byte[rsi], 0b00000001	;if 1 trace down
	jz	.trace_down
	cmp	byte[rsi], 0b00000010	;if 2 trace left
	jz	.trace_left
	cmp	byte[rsi], 0b00000011	;and 3 trace right
	jz	.trace_right
	;----------------------------------------
	;CHECK IF ALL SQUARES ARE FILLED
	mov	rsi, qword[MAZEBUFFER]	;else (trace end) get mazebuffer start
.verify_done:
	test	byte[rsi], 0b01000000	;test current byte as EOF byte
	jnz	.finish	;if yes then finished entire maze (all bytes 128)
	test	byte[rsi], 0b10000000	;test if maze filled byte
	jz	.new_line	;if no then draw another line
	inc	rsi	;otherwise increase addr
	jmp	.verify_done	;and check next byte
.finish:
	ret	;done!!!
.trace_up:
	;----------------------------------------
	;TRACE LINE IN SPECIFIED DIRECTION
	%macro	draw_dir	4
		mov	byte[rsi], 0b10000000	;set byte as maze filled
		call	_draw_pixel	;then draw pixel in current position
		%1	%2	;dec/inc r12/r11
		call	_draw_pixel	;draw inbetween pixel
		%1	%2	;and then dec/inc r12/r11 again
		%3	rsi, %4	;modify rsi to match trace direction
		jmp	.loop_trace	;and trace next position
	%endmacro
	draw_dir	dec, r12, sub, r9	;trace up
.trace_down:	draw_dir	inc, r12, add, r9	;trace down
.trace_left:	draw_dir	dec, r11, sub, 1	;trace left
.trace_right:	draw_dir	inc, r11, add, 1	;trace right

_xoshiro256pp:
	;----------------------------------------
	;PROCESS RANDOM 64BIT VAL
	mov	rax, qword[random.s3]	;load state 3
	add	rax, qword[random.s0]	;and add to state 0
	rcl	rax, 23	;then bit rotate left 23 spaces
	add	rax, qword[random.s0]	;and add on s0 again
	;----------------------------------------
	;RANDOMISE STATE REGISTERS
	mov	rcx, qword[random.s1]	;save state 1 into rcx
	shl	rcx, 17	;and shift it 17 spaces left
	mov	rdx, qword[random.s0]	;load state 0
	xor	qword[random.s2], rdx	;and xor with state 2
	mov	rdx, qword[random.s1]	;load state 1
	xor	qword[random.s3], rdx	;and xor with state 3
	mov	rdx, qword[random.s2]	;load state 2
	xor	qword[random.s1], rdx	;and xor with state 1
	mov	rdx, qword[random.s3]	;load state 3
	xor	qword[random.s0], rdx	;and xor with state 0
	xor	qword[random.s2], rcx	;xor state 2 with state 1 shifted left
	rcl	qword[random.s3], 45	;and now rotate state 3 some amount
	ret
