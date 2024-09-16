%include	"macro.asm"
%include	"data.asm"	;file for data initialisations
section	.text
	%include	"math.asm"
	%include	"graphics.asm"
	global	_start
_start:
	%macro	random_state	0
		;----------------------------------------
		;OPEN /DEV/RANDOM FOR RANDOM DATA
		mov	rax, 2	;use sys_open
		mov	rdi, devrandom	;file for /dev/random 
		xor	rsi, rsi	;reset args here
		syscall
		;----------------------------------------
		;TRANSFER 256 BITS TO XOSHIRO256++ STATE
		mov	r13, rax	;save fd to r13
		xor	rax, rax	;now reset rax for sys_read
		mov	rdi, r13	;read from open file
		mov	rsi, scratchpad	;save data to scratchpad
		mov	rdx, 32	;and read 256 bits
		syscall
		mov	rax, 3	;now use sys_close
		mov	rdi, r13	;and close the open /dev/random file
		syscall
		vmovupd	ymm0, [scratchpad]	;now load the 256 bits into ymm0
		vmovupd	[random.s0], ymm0	;and then save the bits to state
		vmovupd	[random.state_old], ymm0	;and also old state for resets
	%endmacro
	random_state	;get random state
	;----------------------------------------
	;SET UP SIGNAL HANDLERS
	mov	rax, 13	;sys_rt_sigaction
	mov	rdi, 2	;signal type, 2 = SIGINT
	mov	rsi, handler_int	;struct to set handler to _int
	xor	rdx, rdx	;clear this register for something
	mov	r10, 8	;length of something not sure what
	syscall
	mov	rax, 13	;another sys_rt_sigaction
	mov	rdi, 11	;signal type, 11 = SIGSEGV
	mov	rsi, handler_seg	;_seg struct
	syscall
	;----------------------------------------
	;SET UP TERMINAL SETTINGS
	mov	rax, 16	;sys_ioctl
	mov	rdi, 1	;use stdout
	mov	rsi, 21505	;and command for TCGETS, get terminal info
	mov	rdx, term_io	;return it into this struct
	syscall
	and	dword[term_io.c_lflag], ~0b00000010	;clear canonical flag
	and	dword[term_io.c_lflag], ~0b00001000	;clear echo flag
	mov	rax, 16	;sys_ioctl
	mov	rdi, 1	;use stdout
	mov	rsi, 21506	;command for TCSETS, set terminal info
	mov	rdx, term_io	;modified struct to set it to
	syscall
	;----------------------------------------
	;GET AND CHECK TERMINAL SIZE
	mov	rax, 16	;sys_ioctl again
	mov	rdi, 1	;use stdout
	mov	rsi, 21523	;and this time its TIOCGWINSZ, get window size
	mov	rdx, term_size	;return to this truct
	syscall
	mov	ax, word[term_size.x]	;get terminal width into ax
	mov	word[term_size.dx], ax	;now save it to double res data
	shr	word[term_size.x], 1	;then half the normal res data
	jc	_odd	;if theres carry here, then the width is odd, quit
	mov	ax, word[term_size.y]	;now move in terminal height
	shl	ax, 1	;double it
	mov	word[term_size.dy], ax	;and save this in double res data
	movzx	rax, word[term_size.dx]	;load term x width
	imul	rax, UNIT_LEN	;multiply by unit size to get width of screen in bytes
	mov	qword[term_size.xb], rax	;now save as width in bytes
	;----------------------------------------
	;ALLOCATE AND INITIALISE FRAMEBUFFER
	movzx	rax, word[term_size.dx]	;rax is now original term width
	movzx	rbx, word[term_size.y]	;and rbx is original term height	
	imul	rax, rbx	;multiply them together to get total term cells
	imul	rax, UNIT_LEN	;now get data size of eventual framebuffer
	add	rax, HEADER_LEN	;add header length
	call	_alloc	;allocate that space
.change_size:
	;----------------------------------------
	;ALLOCATE SPACE FOR MAZE CREATION MAP
	movzx	rax, word[maze.height]	;move maze height into rax
	movzx	rbx, word[maze.width]	;and width into rbx
	imul	rax, rbx	;multiply them together to get space for maze map
	call	_alloc	;allocate this amount
	mov	ebx, dword[MAZEBUFFER+8]	;load length into here
	mov	byte[rax+rbx], 0b01000000	;and then insert this byte to signal EOF
	;----------------------------------------
	;CALCULATE AND STORE MAZE TOP-LEFT
	mov	ax, word[term_size.dx]	;load terminal width
	shr	ax, 1	;half it
	mov	bx, word[maze.width]	;load maze width
	inc	bx	;increase this to account for border
	sub	ax, bx	;then subtract this from width/2 (this is alr size/2)
	inc	ax	;increase this to account for border again
	mov	word[maze.left], ax	;then store as left amount
	mov	ax, word[term_size.dy]	;load terminal y now
	shr	ax, 1	;half again
	mov	bx, word[maze.height]	;load maze height
	inc	bx	;like before increase to account for border
	sub	ax, bx	;subtract from y/2
	inc	ax	;and increase again
	mov	word[maze.top], ax	;then store as top
.reset_maze:
	;----------------------------------------
	;CREATE SCREEN GRAPHICS AND RESET DATA
	call	_init_screen	;initialise framebuffer
	call	_draw_border	;draw the mazes border
	mov	dword[maze.worm_x], 0	;reset maze worm position
	mov	rsi, qword[MAZEBUFFER]	;load mazebuffer to clear
.reset_mazebuf:
	test	byte[rsi], 0b01000000	;test if current is end of buffer
	jnz	.finish_reset	;if yes then finish
	mov	byte[rsi], 0	;otherwise move in a zero byte
	inc	rsi	;and increase counter
	jmp	.reset_mazebuf	;then loop over
.finish_reset:
	call	_random_walk	;fill in maze with this
	;----------------------------------------
	;DRAW START AND FINISH BOXES
	movzx	r11, word[maze.left]	;load maze left
	movzx	r12, word[maze.top]	;and maze top
	mov	r14, ansi.red	;use a red pixel now
	call	_draw_pixel	;and draw the worm
	movzx	rax, word[maze.width]	;load maze width now
	shl	rax, 1	;half it
	lea	r11, [r11+rax-2]	;then add to pixel x with a 2
	movzx	rax, word[maze.height]	;load maze height
	shl	rax, 1	;half
	lea	r12, [r12+rax-2]	;and add to r12 with another 2
	mov	r14, ansi.blue	;use blue pixel
	call	_draw_pixel	;draw the finish box
.draw_loop:
	;----------------------------------------
	;PRINT FRAMEBUFFER AND ASK FOR INPUT
	mov	rax, 1	;use sys_write
	mov	rdi, 1	;write to stdout
	mov	rsi, qword[FRAMEBUFFER]	;write the framebuffer
	mov	edx, dword[FRAMEBUFFER+8]	;framebuffer size
	syscall
.ask_input:
	mov	qword[scratchpad], 0	;now clear previous scratchpad data
	xor	rax, rax	;use sys_read
	xor	rdi, rdi	;read from stdin
	mov	rsi, scratchpad	;write to scratchpad
	mov	rdx, 8	;and read 8 bytes
	syscall
	;----------------------------------------
	;HANDLE ARROW MOVING INPUTS
	cmp	MOVE_RIGHT	;check for right arrow key
	jz	.handle_right	;if yes go to right handler
	cmp	MOVE_LEFT	;do this for all of the arrow keys
	jz	.handle_left
	cmp	MOVE_DOWN
	jz	.handle_down
	cmp	MOVE_UP
	jz	.handle_up
	;----------------------------------------
	;CHECK OTHER KEYBINDS
	cmp	RESET_MAZE	;check if maze reset key pressed
	jz	.handle_reset	;if yes reset the maze
	cmp	NEW_MAZE	;check if asked for a new maze
	jz	.handle_new	;if yes handle new maze
	cmp	INC_X	;various maze resize macros
	jz	.handle_incx
	cmp	INC_Y
	jz	.handle_incy
	cmp	DEC_X
	jz	.handle_decx
	cmp	DEC_Y
	jz	.handle_decy
	cmp	QUIT	;check if asked to quit
	jz	_man	;if yes trigger manual kill
	jmp	.ask_input	;otherwise ask for input again

.handle_right:
	%macro	handle_worm	4
		;----------------------------------------
		;GET PIXEL IN DIRECTION OF LINE
		movzx	r11, word[maze.worm_x]	;load worm x
		movzx	r12, word[maze.worm_y]	;and worm y
		movzx	rax, word[maze.left]	;then load maze left
		add	r11, rax	;add to worm x
		movzx	rax, word[maze.top]	;and maze top
		add	r12, rax	;also add to worm y
		%1	%3	;then inc/dec x or y axis to get next pixel
		call	_get_pixel	;get pixel infront of line
		;----------------------------------------
		;MOVE PIXEL TO SCRATCHPAD AND TEST IF BLOCKED
		mov	ecx, dword[rax]	;move pixel colour here
		mov	dword[scratchpad], ecx	;save to scratchpad
		mov	byte[scratchpad+3], 0	;and erase 4th byte
		cmp	dword[scratchpad], BLACK	;then compare against wall
		jz	.ask_input	;if its a wall, block movement
		cmp	dword[scratchpad], BLUE	;if its the end
		jz	.ask_input	;also block
		;----------------------------------------
		;PROCESS MOVING FORWARD
		%1	word[maze.worm_%4]	;if movement, inc/dec worm x/y
		cmp	dword[scratchpad], WHITE	;check if its white
		jnz	%%red	;if no it must be red (old line)
		mov	r14, ansi.red	;then use red colour
		call	_draw_pixel	;to draw a new worm segment
		jmp	.draw_loop	;and loop over drawing
	%%red:
		;----------------------------------------
		;PROCESS MOVING BACK OVER LINE
		mov	r14, ansi.white	;load white colour to erase worm
		%2	%3	;now dec/inc x/y for worm erasure
		call	_draw_pixel	;then draw a pixel
		jmp	.draw_loop	;and loop over
	%endmacro
	handle_worm	inc, dec, r11, x	;now this macro is good isnt it
.handle_left:	handle_worm	dec, inc, r11, x
.handle_up:	handle_worm	dec, inc, r12, y
.handle_down:	handle_worm	inc, dec, r12, y
.handle_reset:
	;----------------------------------------
	;RESTORE XOSHIRO256++ STATE
	vmovupd	ymm0, [random.state_old]	;load old state
	vmovupd	[random.s0], ymm0	;and move into current
	jmp	.reset_maze	;then reset the maze
.handle_new:
	random_state	;load a new random state
	jmp	.reset_maze	;and reset
.handle_incx:
	;----------------------------------------
	;DEALLOCATE MAZEBUFFER FOR SIZE CHANGE
	%macro	mod_size	2
		mov	rax, 11	;sys_munmap
		mov	rdi, qword[MAZEBUFFER]	;this addr
		mov	esi, dword[MAZEBUFFER+8]	;and this length
		syscall	;unmap
		sub	dword[alloc_data.pointer], 12	;correct addr pointer	
		mov	dword[alloc_data.available], 0	;set available data to 0
		%1	%2	;then modify width/height
		jmp	.change_size	;and change size of maze
	%endmacro
	;----------------------------------------
	;CHECK IF NEW MAZE IS TOO BIG OR TOO SMALL
	mov	ax, word[term_size.x]	;move terminal size into ax
	sub	ax, 2	;sub 2 to account for border
	cmp	ax, word[maze.width]	;now compare against current width
	jz	.ask_input	;if equal then dont increase x
	mod_size	inc, word[maze.width]	;otherwise do
.handle_decx:
	cmp	word[maze.width], 2	;same thing but compares against min size
	jz	.ask_input	;if min size dont decrease more
	mod_size	dec, word[maze.width]	;then modify size
.handle_incy:
	mov	ax, word[term_size.y]	;same as above but for y coords
	sub	ax, 2
	cmp	ax, word[maze.height]	;so height instead of width and y not x
	jz	.ask_input
	mod_size	inc, word[maze.height]
.handle_decy:
	cmp	word[maze.height], 2
	jz	.ask_input
	mod_size	dec, word[maze.height]

_int:
	;----------------------------------------
	;PREPARE EXIT MESSAGES
	mov	r15, stat_int	;exit message as interrupt msg
	mov	r14, stat_int_len	;and length is defined in this macro
	call	_kill	;call to kill
_man:
	mov	r15, stat_man	;exit message as manual stop msg
	mov	r14, stat_man_len	;length again
	call	_kill	;call to kill
_odd:
	mov	r15, stat_odd	;exit message as odd term msg
	mov	r14, stat_odd_len	;length
	call	_kill	;call to kill
_seg:
	mov	r15, stat_seg	;exit message as segfault msg
	mov	r14, stat_seg_len	;and length is defined again here
_kill:
	;----------------------------------------
	;DE-ALLOCATE MEMORY
	mov	r8d, dword[alloc_data.pointer]	;save allocation pointer
	xor	rbx, rbx	;will be used as counter for allocations
.loop_dealloc:
	cmp	rbx, r8	;check if counter is equal to last allocation
	jz	.finish_dealloc	;if yes, then finished deallocating
	mov	rax, 11	;sys_munmap
	mov	rdi, qword[alloc_data.addr+rbx]	;unmap this addr
	mov	esi, dword[alloc_data.addr+rbx+8]	;with this length
	syscall
	add	rbx, 12	;go to next address length pair
	jmp	.loop_dealloc	;and loop over
.finish_dealloc:
	;----------------------------------------
	;CLEAN UP TERMINAL SETTINGS
	or	dword[term_io.c_lflag], 0b00000010	;set canonical flag
	or	dword[term_io.c_lflag], 0b00001000	;set echo flag
	mov	rax, 16	;sys_ioctl
	mov	rdi, 1	;use stdout
	mov	rsi, 21506	;command TCSETS, clean terminal settings
	mov	rdx, term_io	;clean settings structure
	syscall
	;----------------------------------------
	;PRINT EXIT MESSAGES
	mov	rax, 1	;sys_write
	mov	rdi, 1	;write to stdout
	mov	rsi, esc_erase	;use erase escape
	mov	rdx, 11	;and also include esc_home + esc_reset
	syscall
	mov	rax, 1	;now at home position, write again
	mov	rdi, 1	;again to stdout
	mov	rsi, r15	;this time print exit message
	mov	rdx, r14	;length also here
	syscall
	mov	rax, 60	;then exit normaly
	mov	rdi, 0	;with exit code 0
	syscall
