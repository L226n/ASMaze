section	.data
	;-----------------------------------------------
	;BUFFERS
	scratchpad:	times 10	dd	0
	;-----------------------------------------------
	;MULTI-LINE STRUCTS
	alloc_data:
		.addr	times MAX_ALLOC	dd	0, 0, 0 
		.pointer	dd	0
		.available	dd	0
		.current	dq	0
	ansi:
		.white	db	WHITE
		.black	db	BLACK
		.grey	db	GREY
		.red	db	RED
		.blue	db	BLUE
	handler_int:
		dq	_int
		dd	0x04000000
	handler_seg:
		dq	_seg
		dd	0x04000000
	random:
		.s0	dq	4
		.s1	dq	0
		.s2	dq	0
		.s3	dq	0
		.state_old:
			dq	0, 0, 0, 0
	term_io:
		.c_iflag	dd	0
		.c_oflag	dd	0
		.c_cflag	dd	0
		.c_lflag	dd	0
		.c_line	db	0
		.c_cc	db	0
	term_size:
		.y	dw	0
		.x	dw	0
		.dy	dw	0
		.dx	dw	0
		.xb	dq	0
		.guard	dq	0, 0
	unit_template:
		db	27, "[48;5;000m"
		db	27, "[38;5;000m"
		dd	"▄"
	maze:
		.width	dw	5
		.height	dw	4
		.left	dw	0
		.top	dw	0
		.worm_x	dw	0
		.worm_y	dw	0
	;-----------------------------------------------
	;STRING CONSTANTS
	devrandom	db	"/dev/random", 0
	stat_int:	db	"Program recieved signal 2 (SIGINT)", 10
	stat_int_len	equ	$ - stat_int
	stat_man:	db	"Program stopped manually", 10
	stat_man_len	equ	$ - stat_man
	stat_odd:	db	"Program requires even terminal width", 10
	stat_odd_len	equ	$ - stat_odd
	stat_seg:	db	"Program recieved signal 11 (SIGSEGV)", 10
	stat_seg_len	equ	$ - stat_seg
	;-----------------------------------------------
	;USEFUL ESCAPES
	esc_erase:	db	27, "[2J"
	esc_home:	db	27, "[H"
	esc_reset:	db	27, "[0m"

