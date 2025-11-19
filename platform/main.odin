package platform

import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import "core:os/os2"

import "core:mem"
import "core:dynlib"

import "vendor:sdl2/image"
import SDL "vendor:sdl2"

import "../common"

Color        :: common.Color
DisplayGlyph :: common.DisplayGlyph
COLS         :: common.COLS
ROWS         :: common.ROWS
KeyboardKey  :: common.KeyboardKey
GameInput    :: common.GameInput
GameAPI      :: common.GameAPI
PlatformAPI  :: common.PlatformAPI

/****************************
 * GLOBALS AND PLATFORM API *
 ****************************/

INIT_WIN_WIDTH  :: 1177
INIT_WIN_HEIGHT :: 736

LIB_NAME :: "game.dll"
LIB_LOCK_NAME :: "lock.tmp"

PlatformTile :: struct {
	fg,bg : Color,
	glyph : DisplayGlyph,
	needs_update : bool,
}

TILES : [COLS][ROWS]PlatformTile

WIN : ^SDL.Window

PNG : ^SDL.Surface
PNG_WIDTH       :: 2048
PNG_HEIGHT      :: 5568
PNG_TILE_HEIGHT :: 232
PNG_TILE_WIDTH  :: 128
PNG_TILE_COLS   :: 16
PNG_TILE_ROWS   :: 24

// see create_textures proc for why we have 4 textures
TEXTURE : [4]^SDL.Texture
TEX_SIZES : [4][2]i32

SDL_KEYMAP : map[SDL.Scancode]KeyboardKey
GAME_INPUT : GameInput

glyph_lookup :: proc(g:DisplayGlyph) -> int { return int(g) }

set_tile :: proc(v:[2]int, fg,bg:Color, glyph:DisplayGlyph) {
	TILES[v.x][v.y].fg = fg
	TILES[v.x][v.y].bg = bg
	TILES[v.x][v.y].glyph = glyph
	TILES[v.x][v.y].needs_update = true
}

setup_keymap :: proc() {
	sdl_a := int(SDL.SCANCODE_A)
	lib_a := int(KeyboardKey.A)
	for i in 0..<26 {
		sdl_key := SDL.Scancode(sdl_a+i)
		lib_key := KeyboardKey(lib_a+i)
		SDL_KEYMAP[sdl_key] = lib_key
	}
	sdl_1 := int(SDL.SCANCODE_1)
	lib_1 := int(KeyboardKey.N_1)
	for i in 0..<10 {
		sdl_key := SDL.Scancode(sdl_1+i)
		lib_key := KeyboardKey(lib_1+i)
		SDL_KEYMAP[sdl_key] = lib_key
	}

	SDL_KEYMAP[.UP] = .UP
	SDL_KEYMAP[.DOWN] = .DOWN
	SDL_KEYMAP[.LEFT] = .LEFT
	SDL_KEYMAP[.RIGHT] = .RIGHT

	SDL_KEYMAP[.LCTRL] = .CTRL
	SDL_KEYMAP[.RCTRL] = .CTRL
	SDL_KEYMAP[.LSHIFT] = .SHIFT
	SDL_KEYMAP[.RSHIFT] = .SHIFT
	SDL_KEYMAP[.LALT] = .META
	SDL_KEYMAP[.RALT] = .META
}

/*****************
 * SDL Functions *
 *****************/

sdl_get_seconds_elapsed :: proc(old, current:u64) -> f32 {
	return f32(current-old) / f32(SDL.GetPerformanceFrequency())
}

color_to_sdl :: proc(c:Color) -> [4]u8 {
	sdl_col : [4]u8
	for i in 0..<4 do sdl_col[i] = u8(255*c[i])
	return sdl_col
}

sdl_load_spritesheet :: proc() {
	image := image.Load("assets/tiles.png")
	if image == nil do panic("image load fail")
	PNG = SDL.ConvertSurfaceFormat(image, u32(SDL.PixelFormatEnum.ARGB8888), 0)
	if PNG == nil do panic("image convert fail")
}

downscale_tile :: proc(source:^SDL.Surface, source_tile_width, source_tile_height: int,
					   dest:^SDL.Surface, dest_tile_width, dest_tile_height: int,
					   tile_row, tile_col: int)
{
	source_pixels := cast([^]u32)source.pixels
	dest_pixels   := cast([^]u32)dest.pixels

	col_mapping := make([]int, source_tile_width, context.temp_allocator)
	row_mapping := make([]int, source_tile_height, context.temp_allocator)

	for col in 0..<source_tile_width  do col_mapping[col] = (col*dest_tile_width)/source_tile_width
	for row in 0..<source_tile_height do row_mapping[row] = (row*dest_tile_height)/source_tile_height

	counter        := make([]u64, dest_tile_width*dest_tile_height, context.temp_allocator)
	sum_of_squares := make([]u64, dest_tile_width*dest_tile_height, context.temp_allocator)

	for acc_row, src_row in row_mapping {
		src_row_idx := (tile_col*source_tile_width)+(tile_row*source_tile_height+src_row)*PNG_WIDTH
		acc_row_idx := (acc_row*dest_tile_width)
		for acc_col, src_col in col_mapping {
			src_idx := src_row_idx + src_col
			acc_idx := acc_row_idx + acc_col

			intensity := u64(source_pixels[src_idx] & 0xff)
			counter[acc_idx]        += 1
			sum_of_squares[acc_idx] += intensity*intensity
		}
	}

	dest_width := int(dest.w)
	for row in 0..<dest_tile_height {
		dst_row_idx := (tile_col*dest_tile_width) + (tile_row*dest_tile_height+row)*dest_width
		for col in 0..<dest_tile_width {
			dst_idx := dst_row_idx + col
			acc_idx := row*dest_tile_width + col

			count := counter[acc_idx]
			sos := sum_of_squares[acc_idx]
			avg := 0 if count == 0 else sos/count

			intensity := clamp(u32(math.round(math.sqrt(f64(avg)))), 0, 255)
			dest_pixels[dst_idx] = (intensity << 24) | 0xffffff
		}
	}
}

sdl_create_textures :: proc(r:^SDL.Renderer, output_width, output_height: int) {
	when ODIN_DEBUG {
		start_time := SDL.GetPerformanceCounter()
	}
	assert(r!=nil)
	if PNG == nil {
		return
	}
	pfmt := SDL.PixelFormatEnum.ARGB8888

    // The original image will be resized to 4 possible sizes:
    //  -  Textures[0]: tiles are   W   x   H   pixels
    //  -  Textures[1]: tiles are (W+1) x   H   pixels
    //  -  Textures[2]: tiles are   W   x (H+1) pixels
    //  -  Textures[3]: tiles are (W+1) x (H+1) pixels

	for i in 0..<4 {
		target_height := output_height/ROWS
		target_width  := output_width/COLS
		if i == 1 || i == 3 do target_width+=1
		if i == 2 || i == 3 do target_height+=1
		downscaled := SDL.CreateRGBSurfaceWithFormat(0, i32(target_width*16), i32(target_height*24), 32, u32(pfmt))

		for row in 0..<24 {
			for col in 0..<16 {
				downscale_tile(PNG, PNG_TILE_WIDTH, PNG_TILE_HEIGHT,
							   downscaled, target_width, target_height,
							   row, col)
			}
		}

		if TEXTURE[i] != nil do SDL.DestroyTexture(TEXTURE[i])
		TEXTURE[i] = SDL.CreateTextureFromSurface(r, downscaled)
		SDL.SetTextureBlendMode(TEXTURE[i], .BLEND)
		TEX_SIZES[i] = {i32(target_width), i32(target_height)}
		SDL.FreeSurface(downscaled)
	}

	when ODIN_DEBUG {
		duration := sdl_get_seconds_elapsed(start_time, SDL.GetPerformanceCounter())
		log.debugf("texture create took %.3f ms", duration*1000)
	}
}

sdl_render :: proc() {
	if WIN == nil  do return
	if TEXTURE[0] == nil do panic("tex 0 is nil")
	if TEXTURE[1] == nil do panic("tex 1 is nil")
	if TEXTURE[2] == nil do panic("tex 2 is nil")
	if TEXTURE[3] == nil do panic("tex 3 is nil")

	renderer := SDL.GetRenderer(WIN)

	if renderer == nil do panic("no renderer")

	output_width, output_height : i32
	if SDL.GetRendererOutputSize(renderer, &output_width, &output_height) < 0 do panic("couldn't get renderer size")
	if output_width == 0 || output_height == 0 do return

	SDL.SetRenderDrawColor(renderer, 0, 0, 0, 255)
	SDL.RenderClear(renderer)

	when ODIN_DEBUG {
		for x in 0..<COLS {
			col_width := (i32(x+1) * output_width / COLS) - (i32(x) * output_width / COLS);
			for y in 0..<ROWS {
				row_height := (i32(y+1) * output_height / ROWS) - (i32(y) * output_height / ROWS);

				found := false
				for i in 0..<4 {
					if TEX_SIZES[i] == {col_width, row_height} do found = true
				}
				if !found {
					fmt.println("Couldn't find texture for size", col_width, row_height)
					fmt.println("Sizes are ", TEX_SIZES)
					panic("")
				}
			}
		}
	}

	for step in -1..<4 {
		for x in 0..<COLS {
			col_width := (i32(x+1) * output_width / COLS) - (i32(x) * output_width / COLS);
			for y in 0..<ROWS {
				row_height := (i32(y+1) * output_height / ROWS) - (i32(y) * output_height / ROWS);

				dest : SDL.Rect
				dest.x = i32(x)*output_width / COLS
				dest.y = i32(y)*output_height / ROWS
				dest.w = col_width
				dest.h = row_height

				tile := &TILES[x][y]

				if step == -1 {
					bg := color_to_sdl(tile.bg)
					SDL.SetRenderDrawColor(renderer, bg.r, bg.g, bg.b, bg.a)
					SDL.RenderFillRect(renderer, &dest)
				} else if tile.glyph > .BLANK && TEX_SIZES[step] == {col_width, row_height}{
					idx := i32(glyph_lookup(tile.glyph))
					src : SDL.Rect
					src.w = col_width
					src.h = row_height
					src.x = col_width  * (idx % 16)
					src.y = row_height * (idx / 16)

					fg := color_to_sdl(tile.fg)
					SDL.SetTextureColorMod(TEXTURE[step], fg.r, fg.g, fg.b)
					SDL.RenderCopy(renderer, TEXTURE[step], &src, &dest)
				}
			}
		}
	}

	SDL.RenderPresent(renderer)
}

sdl_resize_window :: proc()
{
	r := SDL.GetRenderer(WIN)
	if r == nil do panic("No renderer on resize")
	width, height : i32
	SDL.GetRendererOutputSize(r, &width, &height)
	sdl_create_textures(r, int(width), int(height))
}

sdl_handle_event :: proc(event:SDL.Event) -> bool {
	should_quit := false
	#partial switch event.type {
		case .MOUSEMOTION: {
			GAME_INPUT.mouse.previous_position = GAME_INPUT.mouse.position
			GAME_INPUT.mouse.position = {f32(event.motion.x), f32(event.motion.y)}
			GAME_INPUT.mouse.moved = true
		}
		case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
			b := event.button.button
			if !(b==1 || b==3) do log.panicf("unrecognized mouse button %d", b)
			m := &GAME_INPUT.mouse
			btn := &m.lmb if b == 1 else &m.rmb
			btn.is_down = event.button.state == SDL.PRESSED
			m.consecutive_clicks = int(event.button.clicks)
		}
		case .KEYDOWN, .KEYUP: {
			keycode := SDL.Keycode(event.key.keysym.sym)
			mods := event.key.keysym.mod
			if mods & SDL.KMOD_ALT != {} && keycode == .F4 {
				should_quit = true
			}
			scancode := event.key.keysym.scancode
			if scancode in SDL_KEYMAP
			{
				key := &GAME_INPUT.keyboard[SDL_KEYMAP[scancode]]
				key.is_down = event.key.state == SDL.PRESSED
			}
		}
		case .QUIT: {
			log.debug("SDL_QUIT")
			should_quit = true
		}
		case .WINDOWEVENT: {
			#partial switch event.window.event {
				case .RESIZED: {
					log.debug("SDL_RESIZE", event.window.data1, event.window.data2)
					sdl_resize_window()
				}
				case .EXPOSED: {
					log.debug("SDL_EXPOSED")
				}
			}
		}
	}
	return should_quit
}

/********************
 * Game API and Lib *
 ********************/

load_game_library :: proc(api_version:int) -> GameAPI {
	lib_write_time, lwt_err := os.last_write_time_by_name(LIB_NAME)
	if lwt_err != nil {
		panic("Couldn't get last write time of file")
	}

	copy_err := os2.copy_file(fmt.tprintf("game_{0}.dll", api_version), LIB_NAME)
	assert(copy_err == nil)

	lib, lib_ok := dynlib.load_library(fmt.tprintf("game_{0}.dll", api_version))
	if !lib_ok do panic("dynload fail")

	api := GameAPI {
		update = cast(common.GameUpdateFn)(dynlib.symbol_address(lib, "game_update")),
		init = cast(common.GameInitFn)(dynlib.symbol_address(lib, "game_state_init")),
		reinit = cast(common.GameReinitFn)(dynlib.symbol_address(lib, "reinit")),
		destroy = cast(common.GameDestroyFn)(dynlib.symbol_address(lib, "game_state_destroy")),
		lib = lib,
		write_time = lib_write_time,
	}

	return api
}

main :: proc() {

	context.logger = log.create_console_logger()
	context.logger.lowest_level = .Warning
	defer log.destroy_console_logger(context.logger)

	when ODIN_DEBUG {
	/****************
	 * DEBUG logger *
	 ****************/
		context.logger.lowest_level = .Debug
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				for _, entry in track.allocation_map {
					fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
				}
			}
			if len(track.bad_free_array) > 0 {
				for entry in track.bad_free_array {
					fmt.eprintf("%v bad free at %v\n", entry.location, entry.memory)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	/*************
	 * SDL Setup *
	 *************/

	SDL.SetHint(SDL.HINT_WINDOWS_DISABLE_THREAD_NAMING, "1")
	if SDL.Init(SDL.InitFlags{.VIDEO}) < 0 do panic("Could not initialize window")
	sdl_load_spritesheet()

	flags := SDL.WindowFlags{ .RESIZABLE, .ALLOW_HIGHDPI, }
	WIN = SDL.CreateWindow("MY_ROGUELIKE",
						   SDL.WINDOWPOS_CENTERED, SDL.WINDOWPOS_CENTERED,
						   INIT_WIN_WIDTH, INIT_WIN_HEIGHT,
						   flags)
	if WIN == nil do panic("window create fail")
	r := SDL.CreateRenderer(WIN, -1, {})
	if r == nil do panic("render create fail")

	width, height : i32
	SDL.GetRendererOutputSize(r, &width, &height)
	sdl_create_textures(r, int(width), int(height))

	setup_keymap()
	defer delete(SDL_KEYMAP)

	/******************
	 * Game API Setup *
	 ******************/

	api_version := 0
	game_api := load_game_library(api_version)
	platform_api := PlatformAPI{ plot_tile = set_tile }
	game_memory := game_api.init(platform_api)
	lib_reload_timer := 0
	defer game_api.destroy(game_memory)
	defer dynlib.unload_library(game_api.lib)

	/*************
	 * Game Loop *
	 *************/

	running := true
	game_update_hz:f32 = 30.0 // 60FPS
	target_seconds_per_frame := 1.0 / game_update_hz
	last_counter := SDL.GetPerformanceCounter()
	frame_count := 0

	for running {
		/* fmt.println("starting frame", frame_count) */
		frame_count+=1
		when ODIN_DEBUG {
			// try library reload every 120 frames
			if lib_reload_timer > 2*60 && !os.is_file(LIB_LOCK_NAME) {
				new_lib_write_time, err := os.last_write_time_by_name(LIB_NAME)
				if err != nil {
					panic("Couldn't get new write time")
				}
				if new_lib_write_time > game_api.write_time {
					api_version += 1
					log.debug("Loading API version", api_version)
					game_api = load_game_library(api_version)
					game_api.reinit(platform_api)
				}
				lib_reload_timer = 0
			}
			lib_reload_timer += 1
		}

		event : SDL.Event
		for SDL.PollEvent(&event) {
			/* fmt.println("frame", frame_count, "polling") */
			running = !sdl_handle_event(event)
		}

		output_width, output_height : i32
		SDL.GetWindowSize(WIN, &output_width, &output_height)
		if GAME_INPUT.mouse.moved {
			tile_x := (int(GAME_INPUT.mouse.position.x) * COLS) / int(output_width)
			tile_y := (int(GAME_INPUT.mouse.position.y) * ROWS) / int(output_height)
			GAME_INPUT.mouse.previous_tile = GAME_INPUT.mouse.tile
			GAME_INPUT.mouse.tile = {tile_x, tile_y}
		}

		/* fmt.println("frame", frame_count, "game udpate start") */
		game_api.update(target_seconds_per_frame, game_memory, GAME_INPUT)
		/* fmt.println("frame", frame_count, "game udpate end") */

		button_reset :: proc(btn:^common.ButtonState, frame_time:f32) {
			if btn.is_down && btn.was_down {
				btn.repeat += frame_time
			} else if !btn.is_down && btn.was_down {
				btn.repeat = 0
			}
			btn.was_down = btn.is_down
		}

		for &btn in GAME_INPUT.keyboard {
			button_reset(&btn, target_seconds_per_frame)
		}
		button_reset(&GAME_INPUT.mouse.lmb, target_seconds_per_frame)
		button_reset(&GAME_INPUT.mouse.rmb, target_seconds_per_frame)
		GAME_INPUT.mouse.moved = false

		/* fmt.println("frame", frame_count, "render start") */
		sdl_render()
		/* fmt.println("frame", frame_count, "render end") */

		/* fmt.println("frame", frame_count, "sleep start") */
		// sleep until target frame time hit.
		/* local := 0 */
		if sdl_get_seconds_elapsed(last_counter, SDL.GetPerformanceCounter()) < target_seconds_per_frame
		{
			pc := SDL.GetPerformanceCounter()
			s_elapsed := sdl_get_seconds_elapsed(last_counter, pc)
			headroom := (target_seconds_per_frame - s_elapsed) * 1000
			time_to_sleep := int(headroom) - 2
			time_to_sleep = max(0, time_to_sleep)
			SDL.Delay(u32(time_to_sleep))

			new_elapsed := sdl_get_seconds_elapsed(last_counter, SDL.GetPerformanceCounter())
			if(new_elapsed >= target_seconds_per_frame) do log.panicf("sleep check fail %.6f", target_seconds_per_frame-new_elapsed)
			for (sdl_get_seconds_elapsed(last_counter, SDL.GetPerformanceCounter()) < target_seconds_per_frame)
			{
				/* fmt.println("\tlittle sleep", local) */
				/* local += 1 */
				// Waiting...
			}
		}
		/* fmt.println("frame", frame_count, "sleep end") */

		/* frame_time := sdl_get_seconds_elapsed(last_counter, SDL.GetPerformanceCounter()) */
		/* fmt.printfln("frame %d time %.3f", frame_count, frame_time*1000) */

		last_counter = SDL.GetPerformanceCounter()
		free_all(context.temp_allocator)
	}

	SDL.Quit()
}
