package game

import c "../common"

GameInput :: c.GameInput
Renderer :: c.Renderer
RenderRequest :: c.RenderRequest
Color :: c.Color
Basis :: c.Basis

/******************
 * SEC: Constants *
 ******************/

NONE :: -1

/* Colors */

black := Color{0,0,0,1}
white := Color{1,1,1,1}
red   := Color{1,0,0,1}
green := Color{0,1,0,1}
blue  := Color{0,0,1,1}
pink  := Color{ 1, 109.0/255, 194.0/255, 1 }

/**************************
 * SEC: Gamestate structs *
 **************************/

Camera :: struct {
    center : V3i,
    dims   : V3i,
}

GameState :: struct {
    m:Map,
    cam:Camera,
}

GameMemory :: struct {
    game_state : GameState,
    initialized : bool,
    platform : c.PlatformApi
}

/**********************
 * Game API functions *
 **********************/

@(export)
game_state_init :: proc(platform_api:c.PlatformApi) -> rawptr {
    game_memory := new(GameMemory)
    game_memory.platform = platform_api
    return game_memory
}

/* SEC: GS Destroy */

@(export)
game_state_destroy :: proc(memory:^GameMemory) {
    destroy_map(&memory.game_state.m)
    free(memory)
}


@(export)
game_update :: proc(time_delta:f32, memory:^GameMemory, input:GameInput, r:^Renderer) {

    /*****************
     * SEC: MEM INIT *
     *****************/

    s := &memory.game_state

    if !memory.initialized {
        s.cam.center = {0,0,1}
        s.m = init_map({20, 20, 3})
        INIT_DUMMY_MAP(&s.m)
        memory.initialized = true
    }

    /**************
     * LOOP LOCAL *
     **************/

    m := &s.m

    /*********************
     * SEC: HANDLE INPUT *
     *********************/

    {
        pressed :: proc(b:c.ButtonState) -> bool {return b.is_down && !b.was_down}
        held :: proc(b:c.ButtonState) -> bool {return b.frames_down > 30}
        pressed_or_held :: proc(b:c.ButtonState) -> bool {return pressed(b) || held(b)}
    }

    /*******************
     * SEC: DRAW MAP *
     *******************/

    {
        z_level := s.cam.center.z

        for y in 0..<m.dim.y {
            for x in 0..<m.dim.x {
                tile := get_map_tile(m, {x,y,z_level})
                map_start :: 0.3
                tile_size :: 0.02
                x_s := map_start+f32(x)*tile_size
                y_s := map_start+f32(y)*tile_size
                if tile.content == .Filled {
                    c.queue_rect(r, {x_s, y_s, x_s+tile_size, y_s+tile_size}, pink)
                } else {
                    c.queue_rect(r, {x_s, y_s, x_s+tile_size, y_s+tile_size}, green)
                }
            }
        }
    }

    /********************
     * SEC: Entity Loop *
     ********************/

    /****************
     * SEC: Draw UI *
     ****************/
    {
    }
}
