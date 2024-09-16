;-----------------------------------------------
;MACROS
%define FRAMEBUFFER	alloc_data.addr
%define MAZEBUFFER	alloc_data.addr+12
%define	MOVE_UP	byte[scratchpad+2], "A"
%define	MOVE_DOWN	byte[scratchpad+2], "B"
%define	MOVE_LEFT	byte[scratchpad+2], "D"
%define	MOVE_RIGHT	byte[scratchpad+2], "C"
%define	RESET_MAZE	byte[scratchpad], "r"
%define	NEW_MAZE	byte[scratchpad], "n"

%define	INC_X	byte[scratchpad], "+"
%define	DEC_X	byte[scratchpad], "-"
%define	INC_Y	byte[scratchpad], "="
%define	DEC_Y	byte[scratchpad], "_"

%define	QUIT	byte[scratchpad], "q"
%define	MAX_ALLOC	100
%define	HEADER_LEN	3
%define	UNIT_LEN	26
%define	HALF_UNIT	11
%define	BLACK	"000"
%define	BLUE	"021"
%define	GREY	"246"
%define	RED	"196"
%define	WHITE	"231"

