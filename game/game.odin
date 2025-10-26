package game

import c "../common"
import "core:fmt"

DBG :: fmt.println

GameInput :: c.GameInput
Renderer :: c.Renderer
RenderRequest :: c.RenderRequest
Color :: c.Color
Basis :: c.Basis
V3i :: c.V3i
V2 :: c.V2
V2i :: c.V2i
Rect :: c.Rect

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

stone_grey := Color{0.6,0.6,0.6,1}
tree_brown := Color{0.7608, 0.4431, 0.1294, 1}

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
    ui:UI,
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

fill_tile_with_circle :: proc(r:^Renderer, pos:V3i, color:Color) {
    x_s := map_start+(f32(pos.x)+0.5)*tile_size
    y_s := map_start+(f32(pos.y)+0.5)*tile_size
    c.queue_circle(r, {x_s, y_s}, tile_size/2, color)
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
    tear_down_ui(&memory.game_state.ui)
    delete(memory.game_state.e)
    delete(E_FREE_STACK)
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
        add_entity(&s.e, .Null, {0,0,0})
        add_entity(&s.e, .Dwarf, {5, 10, 1})
        add_entity(&s.e, .Tree, {4, 4, 1})
        add_order(&s.oq, .Null, {})
        setup_ui(&s.ui)
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
            // TODO: Do this properly
            SCREEN_WIDTH :: 800
            SCREEN_HEIGHT :: 640

            mouse_in_px_space := input.mouse.position
            mouse_in_px_space.y /= 0.8
            mouse_in_px_space.y -= 1.0
            mouse_in_px_space.y *= -SCREEN_HEIGHT
            mouse_in_px_space.x *= SCREEN_WIDTH

            ui_captured := handle_ui_click(&s.ui, mouse_in_px_space)

            if !ui_captured {
                tile := get_map_tile(m, s.hovered_tile)
                switch s.ui.selected_action {
                case .None: {}
                case .Mine: {
                    if tile.content == .Filled {
                        tile.order_idx = add_order(&s.oq, .Mine, s.hovered_tile)
                    }
                }
                case .CutTrees: {
                    es := get_entities_at_pos(&s.e, s.hovered_tile)
                    for e_i in es {
                        if s.e[e_i].type == .Tree {
                            add_order(&s.oq, .CutTree, s.hovered_tile, e_i)
                        }
                    }
                }
                }
            }
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
                    color = stone_grey
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
        super_type := super_types[e.type]
        if super_type == .Creature {
            if e.current_order_idx== 0 {
                i, o := get_unassigned_order(&s.oq)
                if i > 0 {
                    e.current_order_idx = i
                    o.status = .Assigned
                }
            }

            e.action_ticker -= time_delta
            if e.action_ticker < 0 {
                if e.current_order_idx > 0 {
                    o := s.oq.orders[e.current_order_idx]
                    target_pos := o.pos
                    if !are_adjacent(e.pos, target_pos) {
                        dx := 0 if e.pos.x == target_pos.x else 1 if e.pos.x < target_pos.x else -1
                        dy := 0 if e.pos.y == target_pos.y else 1 if e.pos.y < target_pos.y else -1
                        e.pos += {dx,dy,0}
                    } else {
                        if o.type == .Mine {
                            // TODO: Encapsulate order completion
                            mine_tile(m, target_pos)
                            complete_order(&s.oq, e.current_order_idx)
                            e.current_order_idx = 0
                            get_map_tile(m, target_pos).order_idx = 0
                            add_entity(&s.e, .Stone, target_pos)
                        } else if o.type == .CutTree {
                            tree := &s.e[o.target_entity_idx]
                            assert(tree.type == .Tree)
                            tree.deconstruction_percentage += 0.2
                            if tree.deconstruction_percentage > 1 {
                                complete_order(&s.oq, e.current_order_idx)
                                e.current_order_idx = 0
                                get_map_tile(m, target_pos).order_idx = 0
                                deconstruct_entity(&s.e, o.target_entity_idx)
                            }
                        }
                    }
                }
                e.action_ticker += ENTITY_ACTION_FREQ
            }
        }

        /* SEC: Entity Render */
        if e.pos.z == s.cam.center.z {
            switch e.type {
            case .Null: {}
            case .Dwarf: {
                fill_tile_with_color(r, e.pos, blue)
            }
            case .Tree: {
                fill_tile_with_color(r, e.pos, tree_brown)
            }
            case .Stone: {
                fill_tile_with_circle(r, e.pos, stone_grey)
            }
            case .Wood: {
                fill_tile_with_circle(r, e.pos, tree_brown)
            }
            }
        }
    }

    /****************
     * SEC: Draw UI *
     ****************/
    {
        /* Draw mouse hover */
        fill_tile_with_color(r, s.hovered_tile, red)
        r.current_basis = .ui
        render_ui(r, s.ui)
        r.current_basis = .screen
    }


    /*******************
     * SEC: Draw Debug *
     *******************/
    if true {
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
            e:= s.e[es[0]]
            dbg(r, fmt.tprintf("%v %v, %v", e.type, e.pos, e.current_order_idx), &idx)
        }

        oix := get_map_tile(m, s.hovered_tile).order_idx
        if oix > 0 && len(s.oq.orders) > oix {
            dbg(r, fmt.tprintf("Order: %v", s.oq.orders[oix]), &idx)
        }

        dbg(r, fmt.tprintf("Selected action: %v", s.ui.selected_action), &idx)
    }
}
