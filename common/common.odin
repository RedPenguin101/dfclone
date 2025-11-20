package common

import "core:dynlib"
import "core:os"

/*************
 * Constants *
 *************/

// Defines the number of tiles that will be shown on the screen
COLS :: 100
ROWS :: 34

/**********
 * Basics *
 **********/

Color :: [4]f32

/************
 * Game API *
 ************/

GameUpdateFn :: proc(time_delta:f32, memory:rawptr, input:GameInput) -> bool
GameInitFn   :: proc(PlatformAPI) -> rawptr
GameReinitFn   :: proc(PlatformAPI)
GameDestroyFn :: proc(memory:rawptr)

GameAPI :: struct {
	update: GameUpdateFn,
	init: GameInitFn,
	reinit: GameReinitFn,
	destroy: GameDestroyFn,
	lib: dynlib.Library,
	write_time: os.File_Time,
}

/****************
 * Platform API *
 ****************/

PlatformPlotTileFn :: proc(v:[2]int, fg,bg:Color, glyph:DisplayGlyph)

PlatformAPI :: struct {
	plot_tile : PlatformPlotTileFn
}

DisplayGlyph :: enum {
	BLANK=16*2, EXCL, D_QUOTE, HASH, DOLLAR, PERCENT, AMP, QUOTE, PAREN_L, PAREN_R, AST, PLUS, COMMA, HYPHEN, PERIOD, SLASH_FWD,
	N_0, N_1, N_2, N_3, N_4, N_5, N_6, N_7, N_8, N_9, COLON, SEMICOLON, LT, EQ, GT, QMARK,
	AT, A, B, C, D, E, F, G, H, I, J, K, L, M, N, O,
	P, Q, R, S, T, U, V, W, X, Y, Z, BRACKET_L, SLASH_BACK, BRACKET_R, HAT, USCORE,
	BACKTICK, a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,
	p,q,r,s,t,u,v,w,x,y,z, CURLY_L, PIPE, CURLY_R, TILDE, BLANK_2,
	CDOT, FOURDOT, DIAMOND_HOLLOW, HAT2, TREE, ANKH, NOTE, CIRCLE_HOLLOW, ARROW_UP, CIRCLE_FILLED, FEMALE,  CIRCLE_FILLED2, BOX_PLOT_HOLLOW, BOX_PLOT_FILLED, BLANK_3, TRI_LEFT,
	ARROW_UP2, ARROW_DOWN, ARROW_LEFT, ARROW_RIGHT, DELTA, TRIANGLE_DOWN_HOLLOW, OMEGA, THETA, LAMBDA, SIG, DIAMOND_FILLED, CROSS, BLANK_4, BLANK_5, BLANK_6, BLANK_7,
}
/**************
 * Game Input *
 **************/

ButtonState :: struct {
	is_down: bool,
	was_down: bool,
	repeat: f32,
}

KeyboardKey :: enum {
	N_1, N_2, N_3, N_4, N_5, N_6, N_7, N_8, N_9, N_0,
	A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
	UP, DOWN, LEFT, RIGHT,
	CTRL,SHIFT,META,
}

KeyboardInput :: [KeyboardKey]ButtonState

MouseInput :: struct {
	position, previous_position:[2]f32,
	// denoted in screen space
	tile, previous_tile:[2]int,
	moved : bool,
	lmb : ButtonState,
	rmb : ButtonState,
	mmb : ButtonState,
	consecutive_clicks : int,
}

GameInput :: struct {
	mouse : MouseInput,
	keyboard:KeyboardInput,
}
