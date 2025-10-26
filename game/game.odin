package game

import c "../common"
import "core:fmt"

GameInput :: c.GameInput
Renderer :: c.Renderer
RenderRequest :: c.RenderRequest
Color :: c.Color
Basis :: c.Basis
V3i :: c.V3i
V2 :: c.V2

/******************
 * SEC: Constants *
 ******************/

NONE :: -1
map_start :: 0.3
tile_size :: 0.02

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
    e:[dynamic]Entity,
    oq:OrderQueue,

    cam:Camera,
    hovered_tile:V3i,
}

GameMemory :: struct {
    game_state : GameState,
    initialized : bool,
    platform : c.PlatformApi
}

/******************
 * Render Helpers *
 ******************/

fill_tile_with_color :: proc(r:^Renderer, pos:V3i, color:Color) {
    x_s := map_start+f32(pos.x)*tile_size
    y_s := map_start+f32(pos.y)*tile_size
    c.queue_rect(r, {x_s, y_s, x_s+tile_size, y_s+tile_size}, color)
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
    destroy_order_queue(&memory.game_state.oq)
    delete(memory.game_state.e)
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
        add_entity(&s.e, .Creature, {5, 10, 1})
        add_order(&s.oq, .Null, {})
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

        s.hovered_tile = v2_to_v3i((input.mouse.position-{map_start, map_start})/tile_size, s.cam.center.z)

        if pressed(input.mouse.lmb) {
            tile := get_map_tile(m, s.hovered_tile)
            tile.order_idx = add_order(&s.oq, .Mine, s.hovered_tile)
        }
    }

    /*******************
     * SEC: DRAW MAP *
     *******************/

    {
        z_level := s.cam.center.z

        for y in 0..<m.dim.y {
            for x in 0..<m.dim.x {
                tile := get_map_tile(m, {x,y,z_level})
                color:Color
                if tile.order_idx > 0 {
                    color = black
                } else if tile.content == .Filled {
                    color = pink
                } else {
                    color = green
                }
                fill_tile_with_color(r, {x,y,z_level}, color)
            }
        }
    }

    /********************
     * SEC: Entity Loop *
     ********************/

    for &e in s.e {
        if e.current_order == nil {
            o := get_unassigned_order(&s.oq)
            if o != nil {
                e.current_order = o
                o.status = .Assigned
            }
        }

        /* SEC: Entity Render */
        if e.pos.z == s.cam.center.z {
            fill_tile_with_color(r, e.pos, blue)
        }
    }

    /****************
     * SEC: Draw UI *
     ****************/
    {
        /* Draw mouse hover */
        fill_tile_with_color(r, s.hovered_tile, red)
    }


    /*******************
     * SEC: Draw Debug *
     *******************/
    {
        idx :f32= 0.0
        dbg :: proc(r:^Renderer, text:string, idx:^f32) {
            TEXT_HEIGHT :: 0.03
            TEXT_START :: 0.28
            c.queue_text(r, text, {0.02, TEXT_START-(idx^*TEXT_HEIGHT)}, white)
            idx^+=1
        }
        c.queue_rect(r, {0,0,1, 0.3}, blue)
        dbg(r, fmt.tprintf("Hov Tile: %d", s.hovered_tile), &idx)
        dbg(r, fmt.tprintf("OQ Len: %v", len(s.oq.orders)), &idx)

        es := get_entities_at_pos(&s.e, s.hovered_tile)

        if len(es) > 0 {
            e := es[0]
            dbg(r, fmt.tprintf("%v %v, %v", e.type, e.pos, e.current_order), &idx)
        }

        oix := get_map_tile(m, s.hovered_tile).order_idx
        if oix > 0 {
            dbg(r, fmt.tprintf("Order: %v", s.oq.orders[oix]), &idx)
        }
    }
}
