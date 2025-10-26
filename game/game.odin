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

GameState :: struct {
}

GameMemory :: struct {
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
    free(memory)
}


@(export)
game_update :: proc(time_delta:f32, memory:^GameMemory, input:GameInput, r:^Renderer) {
    /**************
     * LOOP LOCAL *
     **************/

    /*****************
     * SEC: MEM INIT *
     *****************/

    if !memory.initialized {
        memory.initialized = true
    }


    /*********************
     * SEC: HANDLE INPUT *
     *********************/

    {
        pressed :: proc(b:c.ButtonState) -> bool {return b.is_down && !b.was_down}
        held :: proc(b:c.ButtonState) -> bool {return b.frames_down > 30}
        pressed_or_held :: proc(b:c.ButtonState) -> bool {return pressed(b) || held(b)}
    }

    /*******************
     * SEC: background *
     *******************/

    /********************
     * SEC: Entity Loop *
     ********************/

    /****************
     * SEC: Draw UI *
     ****************/
    {
        c.queue_text(r, "Hello, sailor!", {0.5, 0.5}, pink)
    }
}
