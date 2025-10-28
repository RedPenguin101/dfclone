package platform

import c "../common"
import "core:os"
import "core:os/os2"
import "core:strings"
import "core:dynlib"
import "core:mem"
import "core:log"
import "core:fmt"
import rl "vendor:raylib"

GameInput :: c.GameInput
ButtonState :: c.ButtonState
V2 :: c.V2
PlatformReadFileFn :: c.PlatformReadFileFn

/****************
 * File loading *
 ****************/

debug_read_entire_file :: proc(filename:string) -> []u8 {
    // Uses context allocator for now
    data, ok := os.read_entire_file_from_filename(filename)
    if !ok {
        panic("file read error")
    }
    return data
}

load_sprite :: proc(filepath:string, lines,frames_per_line:int) -> c.Texture {
    fp := strings.clone_to_cstring(filepath, context.temp_allocator)
    tex := rl.LoadTexture(fp)
    return c.Texture{
        id=uint(tex.id),
        width=int(tex.width),
        height=int(tex.height),
        mipmaps=int(tex.mipmaps),
        format=int(tex.format),
        frame_width=int(tex.width)/frames_per_line,
        frame_height=int(tex.height)/lines,
        sprites_per_row = frames_per_line,
        sprites_per_col = lines,
    }
}

load_texture :: proc(grid:[]c.Color, width, height:int) -> c.Texture {
    img := rl.GenImageColor(i32(width), i32(height), rl.BLACK)
    tex := rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)
    color_grid := make([]rl.Color, width*height)
    defer delete(color_grid)

    for i in 0..<height {
        for j in 0..<width {
            color_grid[(height-i-1)*width+j] = color_to_rl(grid[i*width+j])
        }
    }

    // TODO: handle platform fail here
    rl.UpdateTexture(tex, raw_data(color_grid))

    return c.Texture{
        id=uint(tex.id),
        width=int(tex.width),
        height=int(tex.height),
        mipmaps=int(tex.mipmaps),
        format=int(tex.format),
        frame_width=int(tex.width),
        frame_height=int(tex.height),
    }
}

unload_texture :: proc(t:c.Texture) {
    tex := rl.Texture2D{
        id=u32(t.id),
        width=i32(t.width),
        height=i32(t.height),
        mipmaps=i32(t.mipmaps),
        format=rl.PixelFormat(t.format)
    }
    rl.UnloadTexture(tex)
}

load_font :: proc(path:string) -> rawptr {
    path_c := strings.clone_to_cstring(path, context.temp_allocator)
    font_p := new(rl.Font)
    font_p^ = rl.LoadFontEx(path_c, 20, nil, 0)
    return rawptr(font_p)
}

/*******************
 * Library Loading *
 *******************/

GameAPI :: struct {
    update: proc(f32, rawptr, GameInput, ^c.Renderer) -> bool,
    init: proc(c.PlatformApi) -> rawptr,
    destroy: proc(rawptr),
    lib: dynlib.Library,
}

LIB_NAME :: "game.dll"
LIB_LOCK_NAME :: "lock.tmp"

load_game_library :: proc(api_version:int) -> GameAPI {
    lib, lib_ok := dynlib.load_library(fmt.tprintf("game_{0}.dll", api_version))
    if !lib_ok do panic("dynload fail")

    api := GameAPI {
        update = cast(proc(f32, rawptr, GameInput, ^c.Renderer)->bool)(dynlib.symbol_address(lib, "game_update")),
        init = cast(proc(c.PlatformApi)->rawptr)(dynlib.symbol_address(lib, "game_state_init")),
        destroy = cast(proc(rawptr))(dynlib.symbol_address(lib, "game_state_destroy")),
        lib = lib
    }

    return api
}

main :: proc() {

    /****************
     * DEBUG logger *
     ****************/

    context.logger = log.create_console_logger()
    context.logger.lowest_level = .Warning
    defer log.destroy_console_logger(context.logger)

    when ODIN_DEBUG {
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

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "TACTICAL")

    /******************
     * Game API Setup *
     ******************/

    lib_write_time, lwt_err := os.last_write_time_by_name(LIB_NAME)
    if lwt_err != nil {
        panic("Couldn't get last write time of file")
    }

    api_version := 0
    copy_err := os2.copy_file(fmt.tprintf("game_{0}.dll", api_version), LIB_NAME)
    assert(copy_err == nil)
    game_api := load_game_library(api_version)
    platform_api := c.PlatformApi{
        read_file = debug_read_entire_file,
        load_texture = load_texture,
        load_sprite = load_sprite,
        unload_texture = unload_texture,
        load_font = load_font,
    }

    game_memory := game_api.init(platform_api)
    defer game_api.destroy(game_memory)
    defer dynlib.unload_library(game_api.lib)
    // TODO: make reload based on timestamp of dll.
    reload_timer := 0

    running := true

    target_fps:f32 = 60
    target_frame_length := 1/target_fps

    input : GameInput

    renderer : c.Renderer

    screen_basis := c.Basis{
        origin={0,-SCREEN_HEIGHT},
        x={SCREEN_WIDTH, 0},
        y={0,-SCREEN_WIDTH},
    }

    menu_basis := c.Basis{
        origin={0,0},
        x={1, 0},
        y={0, 1},
    }

    renderer.bases[.screen] = screen_basis
    renderer.bases[.menus] = menu_basis

    defer delete(renderer.queue)

    rl.SetTargetFPS(i32(target_fps))
    refresh_hz := int(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
    defer rl.CloseWindow()

    rl.SetExitKey(.KEY_NULL)

    for running && !rl.WindowShouldClose() {

        if reload_timer > 2*refresh_hz && !os.is_file(LIB_LOCK_NAME) {
            new_lib_write_time, err := os.last_write_time_by_name(LIB_NAME)
            if err != nil {
                panic("Couldn't get new write time")
            }
            if new_lib_write_time > lib_write_time {
                api_version += 1
                dynlib.unload_library(game_api.lib)
                copy_err = os2.copy_file(fmt.tprintf("game_{0}.dll", api_version), LIB_NAME)
                assert(copy_err == nil)
                fmt.println("Loading API version", api_version)
                game_api = load_game_library(api_version)
                lib_write_time = new_lib_write_time
            }
            reload_timer = 0
        }
        reload_timer += 1

        /****************
         * update input *
         ****************/

        update_button_state :: proc(mb:^ButtonState, down:bool) {
            mb.was_down = mb.is_down
            mb.is_down = down
            if mb.was_down {
                if down {
                    mb.frames_down += 1
                } else {
                    mb.frames_down = 0
                }
            }
        }

        update_input_from_keyboard_key :: proc(b:^ButtonState, key:rl.KeyboardKey) {
            update_button_state(b, rl.IsKeyDown(key))
        }

        mp := rl.GetMousePosition()
        mp.x /= SCREEN_WIDTH
        mp.y /= -SCREEN_HEIGHT
        mp.y += 1
        mp.y *= 0.8
        input.mouse.position = mp

        lmb := rl.IsMouseButtonDown(rl.MouseButton.LEFT)
        rmb := rl.IsMouseButtonDown(rl.MouseButton.RIGHT)
        mmb := rl.IsMouseButtonDown(rl.MouseButton.MIDDLE)
        update_button_state(&input.mouse.lmb, lmb)
        update_button_state(&input.mouse.rmb, rmb)
        update_button_state(&input.mouse.mmb, mmb)

        /***************
         * update game *
         ***************/

        game_api.update(target_frame_length, game_memory, input, &renderer)

        /********
         * Draw *
         ********/

        DEBUG_DRAW :: false

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        for &item in renderer.queue {
            render(&item, renderer.bases[item.basis])
        }

        if DEBUG_DRAW {
            rl.DrawRectangle(SCREEN_WIDTH/2-3, 7, 80, 24, rl.BLACK)
            rl.DrawFPS(SCREEN_WIDTH/2,10)
        }

        rl.EndDrawing()
        clear(&renderer.queue)
    }
}
